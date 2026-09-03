<#
  render_officer_guide.ps1 -- Officer-facing printable quick-reference for a provider.

  Lists every supported query and, for each way to search, which fields are REQUIRED vs OPTIONAL,
  in plain English. NO internal jargon (no keyRefs, QIDM, set/any). Assumes zero system knowledge.

  Transform of existing data only: CommSys QIDM combos (set[]=required, any[]=optional) + queryLabel
  (officer name) + the QIF field labels (human wording) + defaulted-field detection (pre-filled).

  Usage:
    .\render_officer_guide.ps1 -Path <provider.json> -OutFile <guide.html> [-PdfFile <guide.pdf>]

  PDF is best-effort via Edge headless (--print-to-pdf). If Edge is not found, HTML is still produced.
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$OutFile,
    [string]$PdfFile,
    # Optional path to the official Mark43 logo (.png / .svg / .jpg). See the branding block below
    # for why this is a parameter and not something the tool draws for itself.
    [string]$LogoFile
)

$ErrorActionPreference = 'Stop'

# =====================================================================================
#  MARK43 BRANDING -- sourced from Confluence "Brand Resources" (Marketing space,
#  page 4462313473, brand refresh August 2024), NOT from memory:
#    Primary palette   #24364E Dark Navy - #134DD1 Blue - #B4C7CF Grey
#    Font              Arial for "all other internal and external docs and slides"
#                      (Archivo is reserved for website/marketing collateral)
#    Company name      "Mark43" -- no space, and never "M43", not even internally
#
#  THE LOGO IS DELIBERATELY NOT DRAWN OR APPROXIMATED. The same page states plainly:
#  "Do not stretch or compress / Do not alter scale or alignment / Do not use outlines
#  or effects / Do not alter colors". The official files live in the All-Employees-Global
#  SharePoint, which this tooling cannot reach, so hand-rolling an SVG lookalike would
#  breach the guideline it is meant to honour and would be an invented asset of exactly
#  the kind this repo refuses elsewhere.
#  Instead: pass -LogoFile, or drop the official file at tools\assets\mark43_logo.(svg|png|jpg)
#  and every guide picks it up automatically from then on. Until then the header carries
#  the company NAME set in brand navy -- which is text, not a logo, and breaches nothing.
#  It is EMBEDDED AS A BASE64 DATA URI, not linked: the PDF is produced by headless Edge
#  and an external <img src> would silently render as a broken box in the printed sheet.
# =====================================================================================
$BRAND_NAVY = '#24364E'; $BRAND_BLUE = '#134DD1'; $BRAND_GREY = '#B4C7CF'
$logoHtml = ''
$logoNote = ''
if (-not $LogoFile) {
    foreach ($ext in @('svg','png','jpg')) {
        $cand = Join-Path $PSScriptRoot "assets\mark43_logo.$ext"
        if (Test-Path $cand) { $LogoFile = $cand; break }
    }
}
if ($LogoFile -and (Test-Path $LogoFile)) {
    $lx   = [System.IO.Path]::GetExtension($LogoFile).TrimStart('.').ToLower()
    $mime = switch ($lx) { 'svg' { 'image/svg+xml' } 'jpg' { 'image/jpeg' } 'jpeg' { 'image/jpeg' } default { 'image/png' } }
    $b64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LogoFile))
    $logoHtml = "<img class='logo' src='data:$mime;base64,$b64' alt='Mark43'>"
    $logoNote = "logo embedded from $(Split-Path $LogoFile -Leaf)"
} else {
    $logoHtml = "<span class='wordmark'>Mark43</span>"
    $logoNote = 'no logo file found -- using the company name in brand navy (see -LogoFile)'
}

$resolved = (Resolve-Path $Path).Path
$data = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$providerName = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$','' -replace '(?i)_(BASE|MC)$',''
$genDate = Get-Date -Format 'yyyy-MM-dd'

# ===================== THE MESSAGE KEY MUST BE THE METADATA'S, NOT OURS =====================
# Rob 2026-09-03: "are you sing the message key from the metat data or the invented keys? i lok
# at nj and do we have a full and a fulln for persons?"
#
# I was printing the BUILT keyReference, and it is mostly ours. Measured across the portfolio:
# 269 of 381 built keyRefs (71%) do not exist in the metadata, and TX_TLETS is 0 of 20. So the
# sheet was showing internal bookkeeping to a reader who would go looking for it in a state
# manual. The column is labelled a MESSAGE KEY; that is the state's mnemonic or it is nothing.
#
# NJ IS THE EXAMPLE ROB PICKED AND IT IS THE CLEAREST ONE. Its metadata DriverLicenseQuery
# declares ONE keyRef -- FULL -- with TWO primaryFields (Name, OperatorLicenseNumber). We build
# FULL and FULLN. "FULLN" IS OURS: a keyRef is not a variant, and the platform needs distinct
# keyReference values inside one QIDM, so the second variant had to be renamed. The honest sheet
# shows FULL on BOTH Person rows -- which is precisely what Rob authorised earlier: "you can
# repeated teh message key. there is no expectation that every query has different message keys."
#
# RESOLUTION REUSES THE CANONICAL MATCHER, it does not add a second heuristic (ENGINEERING_STANDARD
# 4.4 -- five parsers were once written wrong in one session by re-deriving what existed).
# _metadata_keyref_match.ps1 answers metadata->built, including each provider's own `built-as`
# DECLARATIONS (NJ's RAND/FULL -> RANDFULL/RANDFULLN is declared, not guessable), so this inverts
# it: ask every metadata keyRef which built combos it claims, and keep the reverse map.
# A built key that no metadata keyRef claims falls back to the longest metadata keyRef that is a
# prefix of it (RQV -> RQ, DQN -> DQ), and failing that prints unchanged -- never blank, and never
# a fabricated key.
$script:MetaKeyOf = @{}   # "<query>|<builtKeyRef>" -> metadata keyRef
$script:MetaKeyStats = [pscustomobject]@{ Mapped = 0; Fallback = 0; Unresolved = 0; Source = 'none' }
try {
    $toolsDir = Split-Path -Parent $PSCommandPath
    . (Join-Path $toolsDir '_resolve_provider_xml.ps1')
    . (Join-Path $toolsDir '_metadata_parse.ps1')
    . (Join-Path $toolsDir '_metadata_keyref_match.ps1')
    $provDir = Split-Path -Parent $resolved
    $xmlPath = Get-ProviderMetadataXml -ProvDir $provDir -Provider $providerName
    if ($xmlPath) {
        $metaTx = Get-MetadataTransactions -XmlPath $xmlPath
        $decls  = Get-KeyRefDeclarations -JsonDir $provDir -ProviderName $providerName
        $script:MetaKeyStats.Source = Split-Path $xmlPath -Leaf
        foreach ($b in $data.bundles) {
            foreach ($cfg in @($b.configurations)) {
                if ("$($cfg.type)" -ne 'QUERYINPUTDATAMAPPING') { continue }
                $qn = "$($cfg.query)"
                if (-not $metaTx.ContainsKey($qn)) { continue }
                $built = @(@($cfg.combinations) | ForEach-Object { "$($_.keyReference)" } | Where-Object { $_ })
                if ($built.Count -eq 0) { continue }
                $metaKeys = @()
                foreach ($mc in @($metaTx[$qn].combos)) {
                    $mk = "$($mc['keyReference'])"; if (-not $mk) { continue }
                    $metaKeys += $mk
                    $res = Resolve-XmlKeyRefBuild -XmlKeyRef $mk -XmlPrimaryField "$($mc['primaryField'])" `
                             -Query $qn -BuiltKeyRefs $built -Declarations $decls
                    if ($res.Status -eq 'built') {
                        # COLLECT EVERY CLAIMANT, do not stop at the first. NJ_NJCJIS's registry
                        # declares BOTH `RAND` and `FULL` as built-as RANDFULL/RANDFULLN, because
                        # its devdoc defines four combinations across those two keyRefs with
                        # identical Set/Any per identifier and NJ merged them into one physical
                        # combo per identifier. First-wins printed "RAND" and silently dropped the
                        # FULL half of a merge whose whole point is that it is both.
                        foreach ($m in @($res.Matches)) {
                            $kk = "$qn|$m"
                            if (-not $script:MetaKeyOf.ContainsKey($kk)) { $script:MetaKeyOf[$kk] = @() }
                            if ($script:MetaKeyOf[$kk] -notcontains $mk) { $script:MetaKeyOf[$kk] += $mk }
                        }
                    }
                }
                # prefix fallback for the keys the matcher did not claim
                $metaKeys = @($metaKeys | Select-Object -Unique)
                foreach ($bk in $built) {
                    if ($script:MetaKeyOf.ContainsKey("$qn|$bk")) { continue }
                    $stem = $bk -replace '\.[A-Za-z0-9]+$',''
                    # Compare with punctuation normalised OUT of the metadata key. CA_SAN_LUIS_OBISPO's
                    # metadata plate keyRef is literally `4#`, and a JSON keyRef cannot carry the '#',
                    # so it is built as `4.P` -- the two differ only by a character the build had no
                    # way to keep. This is a NORMALISATION, not a guess, and the longest-match rule
                    # still protects it: stem '4' matches normalised '4#' and NOT '4V'.
                    $cand = @($metaKeys |
                        Where-Object { $n = ($_ -replace '[^A-Za-z0-9]',''); $n -and ($stem -like "$n*") } |
                        Sort-Object { ($_ -replace '[^A-Za-z0-9]','').Length } -Descending) |
                        Select-Object -First 1
                    if ($cand) { $script:MetaKeyOf["$qn|$bk"] = @($cand) }
                }
            }
        }
    }
} catch {
    Write-Host "  [NOTE] metadata keyRefs unavailable ($($_.Exception.Message)) -- showing built keys." -ForegroundColor Yellow
}

$entitiesBundle = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' } | Select-Object -First 1
$providerBundle = $data.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' } | Select-Object -First 1
if (-not $entitiesBundle) { Write-Error "No ENTITIES bundle"; exit 1 }

function Esc($s) {
    if ($null -eq $s) { return '' }
    return ([string]$s) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}
# Strip the trailing "(...)" hint from a label so the structure carries required/optional, not the text.
function CleanName([string]$lbl) {
    if (-not $lbl) { return '' }
    $s = $lbl -replace '\([^)]*\)',''        # drop any (...) hint groups, anywhere
    # – en dash, — em dash -- written as ESCAPES so this file stays pure ASCII.
    # A literal dash here is what started the mojibake: PowerShell 5.1 reads a BOM-less .ps1 as
    # cp1252, so a UTF-8 em dash arrives as three characters and gets re-encoded on write.
    $s = $s -replace '\s*[-–—].*$', ''   # drop a trailing " - hint" clause
    return (($s -replace '\s{2,}',' ').Trim())
}
# Prettify a camelCase/PascalCase token: 'operatorLicenseNumber' -> 'Operator License Number'
function Prettify([string]$tok) {
    if (-not $tok) { return '' }
    $t = $tok -creplace '([a-z0-9])([A-Z])','$1 $2'
    return ((Get-Culture).TextInfo.ToTitleCase($t.ToLower()))
}

# --- (entity|fieldId) -> label / default value / hidden, from ENTITIES QIFs, default variant ---
# KEYED BY ENTITY. See the FieldName/DefaultValue/IsHidden header below for why a bare fieldId key
# silently produced WRONG defaults in the officer-facing guide.
$labelOf = @{}; $valueOf = @{}; $hiddenOf = @{}
foreach ($cfg in $entitiesBundle.configurations) {
    if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
    $entKey = ([string]$cfg.targetEntity).ToLower()
    $lv = $null; try { $lv = $cfg.layout.default } catch { }
    if (-not $lv) { continue }
    foreach ($prop in $lv.PSObject.Properties) {
        $node = $prop.Value
        if (-not $node -or -not $node.props) { continue }
        $fid = $null; try { $fid = $node.props.fieldId } catch { }
        if (-not $fid) { continue }
        $k = "$entKey|" + ([string]$fid).ToLower()
        if (-not $labelOf.ContainsKey($k)) { $labelOf[$k] = [string]$node.props.label }
        $iv = $null; try { $iv = $node.props.initialValue } catch { }
        if ($null -ne $iv -and "$iv".Trim() -ne '') { $valueOf[$k] = [string]$iv }
        $hid = $false; try { if ($node.props.hidden) { $hid = $true } } catch { }
        if ($hid) { $hiddenOf[$k] = $true }
    }
}

# --- CommSys QIDMs (skip RMS) ---
$qidms = @()
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') { $qidms += $cfg }
    }
}

# attribute name -> sourceField list (per query) and combo defaults -> value
function Get-AttrMap($qidm) {
    $m = @{}
    foreach ($a in @($qidm.attributes)) { if ($a.name) { $m[[string]$a.name] = @($a.sourceField) } }
    return $m
}

# Resolve a field token (sourceField/fieldId) to a clean human name.
# ENTITY-SCOPED. These three lookups were keyed by BARE fieldId until 2026-07-30, which silently
# cross-contaminated the OFFICER-FACING guide, because the same fieldId lives on several entities
# with DIFFERENT defaults and the last one written won:
#   ImageIndicator    Person 'Y' vs Firearm/Article/Boat 'N' -> guide printed "NCIC Image (N)" on
#                     Driver License, where it is actually Y.
#   RegistrationState Person 'TX' vs Vehicle/Boat none       -> guide printed "State (TX)" on Vehicle
#                     searches, which have had NO default since v4.14 removed the routing prefills.
#                     It told officers a field was pre-filled when it is blank.
# $labelOf had a first-wins guard; $valueOf had none. Both are now keyed "<entity>|<fieldId>".
# Same entity-blind class as the BUILD_RULES 13 keyRef collisions: a bare-name lookup across scopes
# is never safe. Pass the QIDM's targetEntity at every call site.
function FieldName([string]$tok, [string]$ent) {
    $k = "$($ent.ToLower())|$($tok.ToLower())"
    if ($labelOf.ContainsKey($k) -and $labelOf[$k]) { return (CleanName $labelOf[$k]) }
    return (Prettify $tok)
}
function DefaultValue([string]$tok, [string]$ent) {
    $k = "$($ent.ToLower())|$($tok.ToLower())"
    if ($valueOf.ContainsKey($k)) { return $valueOf[$k] }
    return $null
}
function IsHidden([string]$tok, [string]$ent) { return $hiddenOf.ContainsKey("$($ent.ToLower())|$($tok.ToLower())") }

# Friendly "search by" name for a combo's primaryFieldReference
function PrimaryName($qidm, [string]$primary) {
    if (-not $primary) { return 'any field' }
    $am = Get-AttrMap $qidm
    if ($am.ContainsKey($primary)) {
        $sf = @($am[$primary])
        if ($sf.Count -gt 1 -or $primary -match 'Name') { return 'Name' }
        if ($sf.Count -eq 1) { return (FieldName ([string]$sf[0]) ([string]$qidm.targetEntity)) }
    }
    if ($primary -match 'Name') { return 'Name' }
    return (Prettify $primary)
}

# --- entity order ---
$order = @()
try { if ($entitiesBundle.order.default) { $order = @($entitiesBundle.order.default) } } catch { }
if (-not $order -or $order.Count -eq 0) {
    foreach ($q in $qidms) { if ($q.targetEntity -and ($order -notcontains $q.targetEntity)) { $order += [string]$q.targetEntity } }
}

# --- build per-entity sections (one compact table per query) ---
$sb = [System.Text.StringBuilder]::new()
foreach ($ent in $order) {
    $entQidms = $qidms | Where-Object { [string]$_.targetEntity -eq $ent }
    if (-not $entQidms) { continue }
    [void]$sb.AppendLine("<section class='entity'><h2>$(Esc $ent)</h2>")

    foreach ($q in $entQidms) {
        $qlabel = if ($q.queryLabel) { [string]$q.queryLabel } else { (Prettify (([string]$q.query) -replace 'Query$','')) }

        # multiple combos may share a primary -> add an in/out/stolen hint to distinguish
        $combos = @($q.combinations)
        $primaryCounts = @{}
        foreach ($c in $combos) { $p = [string]$c.primaryFieldReference; if ($p) { $primaryCounts[$p] = 1 + ([int]$primaryCounts[$p]) } }

        $rows = [System.Text.StringBuilder]::new()
        $rowCount = 0
        foreach ($c in $combos) {
            $primary = [string]$c.primaryFieldReference
            $hint = ''
            $setFields = @(); if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
            $anyFields = @(); if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }
            # Officer-facing path name: a name-based set reads as "Search by Name" (a SexCode/DOB
            # primaryFieldReference is a metadata routing quirk, not how an officer thinks).
            $hasName = ($setFields | Where-Object { $_ -match '(?i)name' }).Count -gt 0
            if ($hasName) { $pname = 'Name' } else { $pname = PrimaryName $q $primary }
            $isStolen = ($setFields | Where-Object { $_ -match '(?i)relatedHit|stolen' }).Count -gt 0
            if ($isStolen) { $hint = ' (stolen / wanted check)' }
            elseif ($primaryCounts[$primary] -gt 1) {
                # Several combos search by the SAME identifier, so the officer sees repeated rows and
                # cannot tell them apart. Prefer the combo's own in/out marking; fall back to naming
                # the field that actually DIFFERS between the rows.
                if ($c.state -eq 'Out') { $hint = ' (out-of-state)' }
                elseif ($c.state -eq 'In') { $hint = ' (in-state)' }
                else {
                    # SECOND PREFERENCE, ADDED 2026-09-03: read the ROUTING CONDITION.
                    # Where `state` says 'In/Out' on every sibling it distinguishes nothing, but the
                    # combo's own State gate does -- an EXISTS on the State field IS the
                    # out-of-state fork and a NOT_EXISTS IS the in-state one. That is the mechanism
                    # the platform actually routes on, so this is derived from real config, not
                    # inferred from a label. It is why TX_TLETS printed "(with Plate Type)" where an
                    # officer needed "(out-of-state)".
                    # IN / NOT_IN are honoured too: the captured CA lines fork on a state VALUE LIST
                    # rather than presence, and the v2.2 sweep proved those conditions do evaluate.
                    foreach ($cond in @($c.requirements.conditions)) {
                        if (-not $cond) { continue }
                        $cf = @($cond.field) | ForEach-Object { "$_" }
                        if (-not ($cf | Where-Object { $_ -match '(?i)state' })) { continue }
                        switch ("$($cond.operator)".ToUpperInvariant()) {
                            'EXISTS'     { $hint = ' (out-of-state)' }
                            'NOT_EXISTS' { $hint = ' (in-state)' }
                            'NOT_IN'     { $hint = ' (out-of-state)' }
                            'IN'         { $hint = ' (in-state)' }
                        }
                        if ($hint) { break }
                    }
                }
                if (-not $hint) {
                    # FALLBACK ADDED 2026-07-30. On TX_TLETS every Vehicle and Person combo carries
                    # state='In/Out', so neither branch above ever fired and the guide printed TWO
                    # IDENTICAL "Search by Plate Number" rows (and two "VIN" rows) -- the officer had
                    # no way to tell the out-of-state path from the in-state one.
                    # Setting `state` from the devdoc's own (InState)/(OutofState) labels was tried and
                    # REVERTED: validate.ps1 reads `state` as a ROUTING signal ("separate In/Out combos
                    # + prefilled State field = LIMITATION #30"), so overloading it as documentation
                    # raised 2 LIMITATIONs. The disambiguation belongs in the REPORT, not the config.
                    # This derives the hint from the data instead: whichever required field this combo
                    # has that its same-named siblings do not.
                    $sibs = @($combos | Where-Object { [string]$_.primaryFieldReference -eq $primary -and $_ -ne $c })
                    $mine = @(); if ($c.requirements -and $c.requirements.set) { $mine = @($c.requirements.set | ForEach-Object { [string]$_ }) }
                    $theirs = @()
                    foreach ($s in $sibs) { if ($s.requirements -and $s.requirements.set) { $theirs += @($s.requirements.set | ForEach-Object { [string]$_ }) } }
                    $only = @($mine | Where-Object { $theirs -notcontains $_ })
                    if ($only.Count -gt 0) {
                        $names = @($only | ForEach-Object { FieldName $_ ([string]$q.targetEntity) })
                        $hint = " (with $($names -join ' + '))"
                    } elseif ($mine.Count -eq 1 -and $theirs.Count -gt 1) {
                        $hint = ' (on its own)'
                    }
                }
            }

            # STATE-AGNOSTIC PATH, ADDED 2026-09-03. Rob, on the IL guide: the sheet showed 3 Vehicle
            # rows against 5 devdoc combinations, and asked whether they were "truly accounted for"
            # -- adding "you can repeated teh message key. there is no expectation that every query
            # has different message keys."
            #
            # They ARE accounted for, and the reason one row was doing two jobs is here. IL metadata
            # defines Z2{VehicleIdentificationNumber} with State in its <Any>, so ONE variant serves
            # devdoc #2 "(In) VIN" and devdoc #4 "(Out) VIN, State". The plate paths needed two combos
            # only because Z5's <Any> carries NO State, forcing an out-of-state plate onto Z2. So the
            # guide showed a bare "Vehicle Identification Number" row and never said it also covers
            # the out-of-state search.
            #
            # WHY THIS IS A HINT AND NOT AN EXTRA ROW. The obvious fix -- split a state-agnostic combo
            # into an "(in-state)" row and an "(out-of-state)" row, repeating the key -- was written,
            # MEASURED ACROSS ALL 14 PROVIDERS, AND REJECTED. It would add 54 rows over 238 combos,
            # and comparing the result against audit_devdoc_combinations' own item counts it DIFFERED
            # on 44 of 81 query blocks. Worse, it split blocks that ALREADY matched the devdoc exactly
            # (NJ Vehicle 2-vs-2 would have become 4; same for HI DL, OH DH, NM DL, IL Boat). Of IL's
            # own 4 candidate splits only the Vehicle one was right.
            #
            # The measurement's real lesson: THERE IS NO ARITHMETIC MAPPING between devdoc items and
            # built combos, in EITHER direction -- devdoc > built where one variant serves two paths
            # (IL Z2.V), built > devdoc where routing splits one path several ways (FL Boat: 12 built
            # against 3 devdoc items), and the parser skips all-optional items (IL's devdoc #3, which
            # has no mandatory field and is not a search path at all). So a ROW COUNT can never be the
            # coverage test; audit_devdoc_combinations is, and it reads 0 FAIL on IL.
            #
            # What survives is the part that is true by construction rather than inferred: if State is
            # optional on this combo and NOTHING gates on it, this one path genuinely works with or
            # without a state. Say that, in one row, and do not invent the second row.
            if (-not $hint) {
                $stateOptional = @($anyFields | Where-Object { "$_" -match '(?i)^(registration)?state' }).Count -gt 0
                $stateGated = $false
                foreach ($cond in @($c.requirements.conditions)) {
                    if (-not $cond) { continue }
                    if (@($cond.field | ForEach-Object { "$_" } | Where-Object { $_ -match '(?i)^(registration)?state' }).Count -gt 0) { $stateGated = $true; break }
                }
                if ($stateOptional -and -not $stateGated) { $hint = ' (in-state or out-of-state)' }
            }

            # ROUTING CONDITIONS ARE REQUIREMENTS. ADDED 2026-09-03, Rob on the IL sheet:
            #   "il for instance z2.p and z5 are the same so in required fields we need to have
            #    state otherwise z5 and z2.p ar conflicted ... to be clear out of state quiery will
            #    onyl work with a state. that is logic we need noted by taggin optional as required"
            #
            # He is right, and this was a genuine hole in the sheet rather than a wording problem.
            # IL's Z2.P and Z5 declare the SAME set[] -- [LicensePlateNumber] -- because the metadata
            # variants they implement differ only in whether <Any> carries State. What actually
            # separates them is the ROUTING CONDITION: Z2.P is gated `RegistrationState EXISTS` and
            # Z5 `RegistrationState NOT_EXISTS`. The guide read set[] for Required and any[] for
            # Optional, so both rows printed "Required: Plate Number" and the officer was shown two
            # identical rows with no way to pick one.
            #
            # So: a field the combo's own condition requires to be PRESENT is mandatory for that
            # path, whatever grammar slot the metadata puts it in. Promote it out of Optional and
            # into Required. This is a presentation move only -- the wire contract is unchanged, and
            # nothing here touches set[]/any[]. It is also not a devdoc reading: the condition is
            # config we wrote, so this is the sheet finally reporting our own routing.
            #
            # NOT_EXISTS is the mirror and needs the opposite treatment: the path only fires when the
            # field is EMPTY, so offering it under "Optional" is actively wrong. Drop it. (It stays
            # off Required too -- there is nothing to type.) That is what makes Z5 read as the plain
            # in-state plate search instead of appearing to accept a State it would be rejected for.
            $condRequired = @()   # field must EXIST for this row to fire
            $condForbidden = @()  # field must be EMPTY for this row to fire
            foreach ($cond in @($c.requirements.conditions)) {
                if (-not $cond) { continue }
                $op = "$($cond.operator)".ToUpperInvariant()
                foreach ($cf in @($cond.field)) {
                    $cfs = "$cf"; if (-not $cfs) { continue }
                    if     ($op -eq 'EXISTS'     -or $op -eq 'IN')     { $condRequired  += $cfs }
                    elseif ($op -eq 'NOT_EXISTS' -or $op -eq 'NOT_IN') { $condForbidden += $cfs }
                }
            }
            # A condition field already carried in set[] is spelled out there -- do not double-print.
            $condRequired = @($condRequired | Where-Object { $setFields -notcontains $_ } | Select-Object -Unique)
            $setFields = @($setFields) + $condRequired
            $anyFields = @($anyFields | Where-Object { $condRequired -notcontains $_ -and $condForbidden -notcontains $_ })

            # required (set) and optional (any) -> field names, skipping hidden; default shown as (value)
            $reqParts = @()
            foreach ($f in $setFields) {
                $fs = [string]$f; if (IsHidden $fs ([string]$q.targetEntity)) { continue }
                $nm = FieldName $fs ([string]$q.targetEntity); $dv = DefaultValue $fs ([string]$q.targetEntity)
                if ($dv) { $reqParts += "$(Esc $nm) <span class='pre'>($(Esc $dv))</span>" }
                else { $reqParts += (Esc $nm) }
            }
            $optParts = @()
            foreach ($f in $anyFields) {
                $fs = [string]$f; if (IsHidden $fs ([string]$q.targetEntity)) { continue }
                $nm = FieldName $fs ([string]$q.targetEntity); $dv = DefaultValue $fs ([string]$q.targetEntity)
                if ($dv) { $optParts += "$(Esc $nm) <span class='pre'>($(Esc $dv))</span>"
                           # The legend illustrates a pre-filled value with a REAL one from THIS
                           # provider -- a hard-coded "Plate Year (2026)" would be a foreign example
                           # on a sheet whose form has no such field.
                           if (-not $script:sampleDefault) { $script:sampleDefault = "$(Esc $nm) <span class='pre'>($(Esc $dv))</span>" } }
                else { $optParts += (Esc $nm) }
            }
            if ($reqParts.Count -eq 0 -and $optParts.Count -eq 0) { continue }

            $reqHtml = if ($reqParts.Count -gt 0) { $reqParts -join ', ' } else { '&mdash;' }
            $optHtml = if ($optParts.Count -gt 0) { $optParts -join ', ' } else { '&mdash;' }

            # MESSAGE KEY COLUMN (added 2026-09-03, Rob: "on the left side with each combination
            # notate the message key or best interpratation of it").
            # The keyReference IS the message key -- QV, RQ, DQ, KQ, QGB, QA, BQ and so on are the
            # state's own transaction mnemonics, and a supervisor reading a wire log or a CLETS
            # manual sees those, not our friendly labels. Until now the guide showed only "Search
            # by: Plate", so there was no way to tie a row on this sheet to a row in a log.
            #
            # THE INTERPRETATION IS DERIVED, NEVER INVENTED. It is composed from the combination's
            # OWN content -- query label, the identifier it searches by, and its in/out marking --
            # so it cannot drift from the build and needs no hand-maintained glossary that would go
            # stale the first time a key changed. Writing "QV = DMV vehicle inquiry" from memory
            # would be exactly the unsourced-claim class this repo keeps catching.
            # THE KEY ALONE. The first cut also printed a derived sentence underneath
            # ("Vehicle Registration by Plate Number - out-of-state"), and every word of it was
            # already on the page: the query label is the table CAPTION, the identifier is the
            # "Search by" column, and the in/out marking is the hint inside that same column --
            # so the row read "RQ.P = Vehicle Registration by Plate Number - out-of-state |
            # Plate Number (out-of-state)". Rob 2026-09-03: show the in-state / out-of-state combo
            # as before, and put the message key in the same place it is now.
            # The in/out distinction is NOT lost by this -- it stays where officers were already
            # reading it, in the Search by column, and $hint below is what puts it there.
            # THE METADATA KEY WINS. $c.keyReference is the BUILT name and is ours 71% of the time
            # (see the resolution block at the top of this file). Fall back to the built name only
            # when nothing in the metadata claims it -- showing a real internal key beats showing
            # nothing, and beats inventing one.
            $builtKey = [string]$c.keyReference
            $mkey = $builtKey
            if ($script:MetaKeyOf.ContainsKey("$($q.query)|$builtKey")) {
                $claims = @($script:MetaKeyOf["$($q.query)|$builtKey"])
                $mkey = $claims -join ' + '
                if ($mkey -eq $builtKey) { $script:MetaKeyStats.Mapped++ } else { $script:MetaKeyStats.Fallback++ }
            } elseif ($builtKey) { $script:MetaKeyStats.Unresolved++ }

            # FIRST COLUMN = how the devdoc presents a combination: a NUMBER, the way you search,
            # and (folded in, not given its own column) the message key.
            # Rob 2026-09-03: "i want the first column to be like it was before we started reworking
            # this and include in that first colum the message key. i want the combos enumerated the
            # way the devdoc lists them".
            # The devdoc writes "Possible Combinations 1. (In/Out) ArticleSerialNumber, ArticleTypeCode
            # 2. (In/Out) OwnerAppliedNumber, ArticleTypeCode" -- numbered, one per line, required
            # fields then bracketed optionals. This table is that list, per query, in the same order.
            # Dropping the separate key column also buys back 20% of the page width for the field
            # lists, which is where the long content actually is.
            $keyBit = if ($mkey) { " <span class='pre'>$(Esc $mkey)</span>" } else { '' }
            if ($mkey -and -not $script:sampleKey) { $script:sampleKey = (Esc $mkey) }

            # ================= IN-STATE / OUT-OF-STATE MADE EXPLICIT, 2026-09-03 =================
            # Rob, third pass on IL: "i don't think you are getting this. lookin at person we need
            # to show out of stte path that requires a state to make it meaningful on veh or person
            # you need to say leave state blank for the instate entries."
            #
            # He is right and the two previous passes both stopped short. Promoting a condition-gated
            # State into Required fixed the rows the CONFIG already forked (IL Z2.P vs Z5), but left
            # the harder half untouched:
            #   - a combo where State is merely OPTIONAL and ungated printed ONE row reading
            #     "(in-state or out-of-state)" with State buried in the Optional list. IL Person had
            #     exactly one OLN row and therefore NO out-of-state path an officer could see.
            #   - an in-state row said nothing about State at all. Its absence from the row is what
            #     makes it in-state, and absence is not something a reader notices.
            #
            # So a combo now emits ONE ROW PER STATE PATH, sharing the message key -- which is what
            # Rob authorised at the start of this: "you can repeated teh message key. there is no
            # expectation that every query has different message keys."
            #   State EXISTS-gated      -> one row,  out-of-state, State in REQUIRED
            #   State NOT_EXISTS-gated  -> one row,  in-state,     "State - leave blank"
            #   State optional, ungated -> TWO rows, in-state AND out-of-state, same key
            #   no State field at all   -> one row,  unchanged
            #
            # I REJECTED THIS SPLIT ONE COMMIT AGO AND THE REJECTION WAS WRONG. I measured it against
            # audit_devdoc_combinations' item COUNTS, found it differed on 44 of 81 query blocks, and
            # dropped it -- then concluded in the same commit that a row count can never be the
            # coverage test, because the devdoc-to-combo mapping is many-to-many in both directions.
            # Having discarded the test I should have re-opened the verdict it produced, and did not.
            # The split is a USABILITY question and the guide is a usability artifact; coverage stays
            # audit_devdoc_combinations', which is unaffected by anything rendered here.
            $stateFld = $null
            foreach ($f in (@($anyFields) + @($condRequired) + @($condForbidden))) {
                if ("$f" -match '(?i)^(registration)?state') { $stateFld = "$f"; break }
            }
            $stateName = if ($stateFld) { FieldName $stateFld ([string]$q.targetEntity) } else { 'State' }
            $blankNote = "<div class='blank'>$(Esc $stateName) &mdash; leave blank</div>"

            $variants = @()
            if ($condRequired | Where-Object { "$_" -match '(?i)^(registration)?state' }) {
                # already forked out-of-state by its own condition; State is in $reqHtml already
                $variants += ,@($hint, $reqHtml, $optHtml)
            }
            elseif ($condForbidden | Where-Object { "$_" -match '(?i)^(registration)?state' }) {
                $variants += ,@(' (in-state)', "$reqHtml$blankNote", $optHtml)
            }
            elseif ($stateFld -and ($anyFields -contains $stateFld) -and -not $isStolen) {
                # State is offered but nothing routes on it -> spell out BOTH paths.
                # Out-of-state moves State into Required and drops it from Optional; in-state drops
                # it from Optional too and says, in words, that leaving it empty is the point.
                $optNoState = @($optParts | Where-Object { $_ -notmatch [regex]::Escape((Esc $stateName)) })
                $optNoStateHtml = if ($optNoState.Count -gt 0) { $optNoState -join ', ' } else { '&mdash;' }
                $reqPlusState = if ($reqParts.Count -gt 0) { (@($reqParts) + @(Esc $stateName)) -join ', ' } else { (Esc $stateName) }
                $variants += ,@(' (in-state)',     "$reqHtml$blankNote", $optNoStateHtml)
                $variants += ,@(' (out-of-state)', $reqPlusState,        $optNoStateHtml)
            }
            else {
                $variants += ,@($hint, $reqHtml, $optHtml)
            }

            foreach ($v in $variants) {
                $num = $rowCount + 1
                [void]$rows.AppendLine("<tr><td class='sb'><span class='num'>$num.</span> $(Esc $pname)$(Esc $v[0])$keyBit</td><td class='req'>$($v[1])</td><td class='opt'>$($v[2])</td></tr>")
                $rowCount++
            }
        }
        if ($rowCount -eq 0) { continue }

        # Headers name REQUIRED and OPTIONAL explicitly (Rob 2026-09-03: "the officer guide pdf to
        # be updated to say required and optional field names"). "Must enter" / "You can also add"
        # read well but do not use the words a spec conversation uses, so the sheet could not be
        # matched against a devdoc or a metadata reference without translating in your head.
        # One table per QUERY, so the sheet mirrors the FORM the officer is looking at: a Vehicle
        # section, a Person section holding Driver License and Driver History as separate blocks
        # wherever the provider builds both (Rob 2026-09-03). The caption is the query's officer-facing
        # queryLabel, which is also what the form card is titled.
        [void]$sb.AppendLine("<table class='qt'><caption>$(Esc $qlabel)</caption><thead><tr><th class='sb'>Search by</th><th class='req'>Required fields</th><th class='opt'>Optional fields</th></tr></thead><tbody>")
        [void]$sb.Append($rows.ToString())
        [void]$sb.AppendLine("</tbody></table>")
    }
    [void]$sb.AppendLine("</section>")
}

$css = @"
@page { size: portrait; margin: 0.6cm; }
* { box-sizing: border-box; }
/* Arial leads, per the brand page: "Arial can be used for all other internal and external docs".
   Archivo is reserved for website and marketing collateral, which this sheet is not. */
body { font-family: Arial, Helvetica, sans-serif; color:#1a1a1a; font-size: 8.5pt; line-height:1.25; margin: 0; padding: 4px 8px; }
/* Brand bar: navy rule under the mark, blue accent. Prints cleanly in mono as well as colour. */
.brandbar { display:flex; align-items:center; justify-content:space-between;
            border-bottom:2px solid $BRAND_NAVY; padding:2px 0 4px; margin-bottom:4px; }
.brandbar .logo { height:26px; width:auto; display:block; }
.brandbar .wordmark { font-size:17pt; font-weight:700; letter-spacing:-0.5px; color:$BRAND_NAVY; }
.brandbar .brandright { font-size:8pt; color:$BRAND_BLUE; font-weight:600; text-transform:uppercase; letter-spacing:0.6px; }
h1 { font-size: 15pt; margin: 0 0 2px; }
/* HOW TO READ THIS SHEET. Rob 2026-09-03: "we hve a place to explain these queires so lets make
   good use of it." It was one grey sentence; the things an officer actually has to be told are the
   numbering (first match wins), what a message key IS, that the SAME KEY LEGITIMATELY REPEATS
   because one transaction serves several search paths, and that a parenthesised value is already
   on the form. Each legend row shows the thing itself in the left cell, so it is recognised on the
   page rather than described in the abstract. */
.howto { color:#333; font-size: 8pt; margin: 0 0 9px; border:1px solid $BRAND_GREY;
         border-left:3px solid $BRAND_BLUE; border-radius:3px; padding:5px 8px 4px; background:#fbfcfd; }
.howto .lead { margin:0 0 4px; }
.howto .tail { margin:4px 0 0; color:#555; font-style:italic; }
.howto .rq { color:#7a1f1f; }
.howto .op { color:#3a5a3a; }
table.legend { width:100%; border-collapse:collapse; }
table.legend td { border:0; padding:1px 0; vertical-align:top; line-height:1.25; }
table.legend td.lk { width:16%; white-space:nowrap; padding-right:7px; color:#555; }
table.legend .num { color:$BRAND_BLUE; font-weight:700; }
table.legend .pre { font-family:Consolas,'Courier New',monospace; font-size:10px; color:#555;
                    background:#f2f4f7; border:1px solid #dde3ea; border-radius:2px; padding:0 3px;
                    font-style:normal; }
section.entity { margin: 0 0 7px; page-break-inside: avoid; }
h2 { font-size: 10.5pt; background:#1f3b57; color:#fff; padding:3px 7px; border-radius:3px; margin: 7px 0 3px; }
table.qt { width:100%; border-collapse:collapse; table-layout:fixed; margin: 0 0 5px; }
table.qt caption { caption-side: top; text-align:left; font-weight:600; color:#1f3b57; font-size:9pt; padding:2px 0 1px; }
table.qt th, table.qt td { border:1px solid #cdd8e3; padding:2px 5px; text-align:left; vertical-align:top; overflow-wrap:break-word; }
table.qt thead th { background:#eef3f8; font-size:8pt; font-weight:700; }
/* THREE columns, not four. The message key now rides inside "Search by" -- it is a short token and
   did not earn 20% of the page, while the field lists (the long content) were being squeezed. */
th.sb, td.sb { width:30%; font-weight:600; }
th.req, td.req { width:35%; }
th.opt, td.opt { width:35%; }
/* Devdoc-style enumeration: the combination number leads the row, as the devdoc writes it. */
td.sb .num { color:#134DD1; font-weight:700; margin-right:2px; }
/* The message key is a machine token -- monospace so it reads as one, and quiet so it never
   competes with the plain-English search path beside it. */
td.sb .pre { font-family:Consolas,'Courier New',monospace; font-size:10px; color:#555;
             background:#f2f4f7; border:1px solid #dde3ea; border-radius:2px; padding:0 3px; }
td.req { color:#7a1f1f; }
/* "State - leave blank" on an in-state row. It sits in the Required cell because that is where the
   officer looks for what to DO, but it is an instruction rather than a field to fill, so it gets its
   own line and a quieter weight -- reading it as a fifth required field would be worse than silence. */
td.req .blank { color:#555; font-style:italic; font-weight:normal; margin-top:1px; }
td.opt { color:#3a5a3a; }
thead th.req { color:#7a1f1f; }
thead th.opt { color:#3a5a3a; }
.pre { color:#666; font-style:italic; }
footer { margin-top:8px; border-top:1px solid #ccc; padding-top:4px; color:#777; font-size:7.5pt; }
"@

# Build version, from the active JSON filename (<PROVIDER>_v<X.Y>.json).
# WHY THIS MATTERS: before 2026-07-29 the guide carried no version at all, so nothing tied a
# printed sheet to the build it described -- which is exactly how every guide silently rotted
# 3-4 weeks behind its JSON without anyone noticing (officer-guide generation had been demoted
# to opt-in on 2026-07-06). An officer holding a stale sheet had no way to tell.
$guideVersion = 'unversioned'
$vm = [regex]::Match([IO.Path]::GetFileName($resolved), '_v([0-9]+\.[0-9]+)\.json$')
if ($vm.Success) { $guideVersion = "v$($vm.Groups[1].Value)" }

# Legend examples, taken from THIS provider's own sheet (collected during the row loop above) so the
# officer recognises them on the page below. Fallbacks keep the legend sensible on a provider that
# emits no message key or has no pre-filled optional at all -- an empty cell would read as a defect.
$legendKey = if ($script:sampleKey) { $script:sampleKey } else { 'key' }
$legendDefault = if ($script:sampleDefault) { $script:sampleDefault } else { "a field <span class='pre'>(value)</span>" }

$html = @"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>$(Esc $providerName) &mdash; Officer Query Guide $(Esc $guideVersion)</title>
<style>$css</style></head><body>
<div class='brandbar'>
  <div class='brandleft'>$logoHtml</div>
  <div class='brandright'>Universal Search &middot; Query Guide</div>
</div>
<h1>$(Esc $providerName) &mdash; Query Guide <span style='font-weight:normal;font-size:60%;color:#555'>(build $(Esc $guideVersion))</span></h1>
<p class='howto'>Pick the row for what you want to <b>search by</b> and fill every <b class='rq'>Required</b> field &mdash; <b class='op'>Optional</b> ones only narrow it. Values in (parentheses) are already on the form. An <b>out-of-state</b> search requires a State; leave State blank to search in-state.</p>
$($sb.ToString())
<footer><strong>Mark43</strong> &middot; Universal Search &middot; mark43.com<br>
$(Esc $providerName) build $(Esc $guideVersion) &middot; Generated $genDate &middot; Reference only &mdash; supported search paths and field requirements. If the form on your screen does not match this sheet, this sheet is out of date &mdash; ask for the current one.</footer>
</body></html>
"@

# PS 5.1 COMPATIBILITY (fixed 2026-08-04). `-Encoding utf8NoBOM` is PowerShell 7 ONLY: under 5.1 the
# ValidateSet for -Encoding is unknown/string/unicode/bigendianunicode/utf8/utf7/utf32/ascii/default/oem,
# so this line died with "Cannot validate argument on parameter 'Encoding'" -- a hard PARAMETER-BINDING
# failure, not a parse error, which is why audit_ps51_parse could not see it (it only checks parsing).
# pipeline.ps1 / enforce.ps1 / build_report.ps1 all invoke tools as `powershell -File` = 5.1, so this
# step has been failing there while working fine in interactive pwsh 7. It surfaced only because
# enforce's PHASE 1 report regeneration propagated the NativeCommandError and killed the whole run --
# every other caller pipes this to Out-Null, so the failure was invisible. Likely also why enforce's
# ancillary-artifact currency check found stale render artifacts on 18 of 20 providers.
# `-Encoding utf8` would ALSO be wrong under 5.1: it writes a BOM, and validate.ps1 rightly FAILs on one.
[System.IO.File]::WriteAllText($OutFile, ($html -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  BRANDING: $logoNote" -ForegroundColor DarkGray
# Print the key-resolution denominator every run. A sheet whose message keys silently fell back to
# our invented names looks EXACTLY like one showing the state's -- the failure this whole change
# exists to fix -- so the run has to say which it did (ENGINEERING_STANDARD 4.3).
$mks = $script:MetaKeyStats
Write-Host ("  MESSAGE KEYS: {0} already metadata-exact, {1} resolved to the metadata key, {2} unresolved (showing the built key) -- source {3}" -f `
    $mks.Mapped, $mks.Fallback, $mks.Unresolved, $mks.Source) -ForegroundColor $(if ($mks.Unresolved -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "Officer guide HTML: $OutFile" -ForegroundColor Green

if ($PdfFile) {
    $edge = $null
    foreach ($cand in @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )) { if ($cand -and (Test-Path $cand)) { $edge = $cand; break } }
    if (-not $edge) {
        Write-Host "[NOTE] Edge/Chrome not found -- PDF skipped; HTML produced (open it and Print > Save as PDF)." -ForegroundColor Yellow
    } else {
        $htmlFull = (Resolve-Path $OutFile).Path
        $pdfFull  = [System.IO.Path]::GetFullPath($PdfFile)
        $uri = 'file:///' + ($htmlFull -replace '\\','/')
        # STALE-PDF GUARD, ADDED 2026-09-03. The old check was `Test-Path $pdfFull`, which is
        # satisfied by a PDF from a PREVIOUS run -- so when a conversion failed over an existing
        # file the tool printed the green "Officer guide PDF: ..." success line and left the old
        # document in place. Rob found it the only way it could be found: "i don't see an updated
        # user guide for il". IL's HTML was 24 minutes newer than its PDF, it was the ONLY provider
        # of 14 affected (a transient lock -- that PDF had just been opened), and BOTH the tool and
        # my own post-run check reported it green. A success line that a stale file can satisfy is
        # the same success-shaped silence this repo keeps finding in inert gates.
        # Compare the WRITE TIME, which is the only thing that distinguishes "just produced" from
        # "left over", and report a failure over an existing file as loudly as one over no file --
        # louder, in fact, because that case ships a document that looks current and is not.
        $pdfBefore = if (Test-Path $pdfFull) { (Get-Item $pdfFull).LastWriteTimeUtc } else { [datetime]::MinValue }
        & $edge --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=3000 "--print-to-pdf=$pdfFull" $uri 2>$null
        # POLL, DO NOT SAMPLE ONCE. The first cut of this guard slept 1200ms and then compared --
        # and immediately reported all 5 providers in the first batch as STALE, which was the GUARD
        # being wrong, not the PDFs. Edge returns before the file is flushed and the observed
        # html->pdf gap ranges 1-4s (CA_CLETS took 3), so a single sample at 1.2s loses the race on
        # the larger sheets. The OLD Test-Path check could not notice because a leftover file
        # satisfied it either way -- the race was always there, masked.
        # Waiting for the write to land is the whole point: a guard that cries wolf on every run is
        # retired by whoever reads it, which would leave the real stale case undetected again.
        $deadline = (Get-Date).AddSeconds(20)
        $pdfAfter = [datetime]::MinValue
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 400
            if (Test-Path $pdfFull) {
                $pdfAfter = (Get-Item $pdfFull).LastWriteTimeUtc
                if ($pdfAfter -gt $pdfBefore) { break }
            }
        }
        if ($pdfAfter -gt $pdfBefore) { Write-Host "Officer guide PDF: $pdfFull" -ForegroundColor Green }
        elseif ($pdfAfter -ne [datetime]::MinValue) {
            Write-Host "[WARN] PDF NOT REWRITTEN -- the file on disk is STALE and does not match the HTML just produced." -ForegroundColor Red
            Write-Host "       (last written $pdfBefore UTC). Usually the PDF is open in a viewer and locked. Close it and re-run." -ForegroundColor Red
        }
        else { Write-Host "[NOTE] PDF conversion did not produce a file; HTML is available (open it and Print > Save as PDF)." -ForegroundColor Yellow }
    }
}
