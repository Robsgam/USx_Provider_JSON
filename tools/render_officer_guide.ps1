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
            $mkey = [string]$c.keyReference

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
            $num = $rowCount + 1
            $keyBit = if ($mkey) { " <span class='pre'>$(Esc $mkey)</span>" } else { '' }
            if ($mkey -and -not $script:sampleKey) { $script:sampleKey = (Esc $mkey) }
            [void]$rows.AppendLine("<tr><td class='sb'><span class='num'>$num.</span> $(Esc $pname)$(Esc $hint)$keyBit</td><td class='req'>$reqHtml</td><td class='opt'>$optHtml</td></tr>")
            $rowCount++
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
        & $edge --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=3000 "--print-to-pdf=$pdfFull" $uri 2>$null
        Start-Sleep -Milliseconds 1200
        if (Test-Path $pdfFull) { Write-Host "Officer guide PDF: $pdfFull" -ForegroundColor Green }
        else { Write-Host "[NOTE] PDF conversion did not produce a file; HTML is available (open it and Print > Save as PDF)." -ForegroundColor Yellow }
    }
}
