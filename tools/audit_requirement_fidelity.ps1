<#
  audit_requirement_fidelity.ps1 -- does each BUILT combination require EXACTLY what its metadata
  branch requires? Mandatory-vs-optional fidelity, per combination, both directions.

  WHY THIS EXISTS (found 2026-07-30 on NY_NYSPIN_EJUSTICE, round 4 of an attack sweep)
    Every existing gate answers a DIFFERENT question, and none of them answers this one:
      audit_metadata            -- is the FIELD metadata-defined for this query?      (membership)
      audit_query_trace         -- does a built combo EXIST for each metadata combo?  (existence)
      audit_combo_reachability  -- can the form actually REACH each built combo?      (reachability)
      audit_log_metadata (6d)   -- does a captured wire request satisfy SOME combo?   (satisfaction)
    A combination can pass all four while being built LOOSER than the spec. NY's RVEHOUT is the
    proof case: metadata's out-of-state plate branch requires
        LicensePlateNumber + LicensePlateTypeCode + LicensePlateYear + State   (all mandatory)
    and we built
        set[LicensePlateNumber, RegistrationState]  any[ImageIndicator, PlateTypeCode, PlateYear]
    Two metadata-MANDATORY fields demoted to optional. The combo exists, is reachable, every field
    is metadata-defined, and a Plate+State-only wire request satisfies our own set[] -- so all four
    gates go green while the officer sends NY a request the spec says is incomplete.

    6d cannot catch it BY CONSTRUCTION: it validates the log against the combination as WE built it.
    A gate that reads its expectation from the artifact under test cannot detect that the artifact is
    wrong -- the same closed-loop failure that let the test plan be generated FROM the JSON.
    This tool reads the expectation from the XML only.

  THE OTHER HALF OF WHY -- and the first version of this comment got it WRONG, so read the
  correction, not the headline. I claimed four gates were "Choice-blind" on the basis of
  `grep Choice <file>` returning nothing. That test cannot tell "handled elsewhere" from "not
  handled", which is the same un-failable-check disease this tool exists to fight. What was
  actually true, after checking:
    audit_query_trace            -- genuinely broken on nested Choice/Set. Fixed 2026-07-30.
    audit_log_metadata (6d)      -- NOT blind. It delegates to _metadata_parse.ps1, which DID
                                    recurse Choice/Set... but two PowerShell array-unwrap traps
                                    shredded a 4-field branch into 4 single-field alternatives, so
                                    6d could not fail on any nested-Choice combination. Fixed
                                    2026-07-30; that fix immediately exposed a real CA_CLETS defect
                                    (IG.QGH shipped purposeCode+Name with neither Age nor BirthDate,
                                    satisfying no metadata alternative -- as a PASS log).
    audit_devdoc_combinations / audit_devdoc_optionals / emit_test_plan_spec
                                 -- DEVDOC-driven. They never consume XML Choice. Nothing to fix.
  So one tool was blind, one was degraded, three were irrelevant -- and TX_TLETS's ALL-PASS was NOT
  signed off by a Choice-blind 6d, contrary to what I first reported. TX re-verified 89/89 against
  real requirement sets afterwards. 13 of 18 providers use the nested shape (TX has 60), so validate
  any metadata-parser change against BOTH TX (flat Choice/Field) and NY (nested Choice/Set).
  Read the existing parsers before writing a new one (ENGINEERING_STANDARD LAW 4) -- this file
  shipped a duplicate Choice walk for one afternoon and got the grammar wrong twice over.

  VERDICTS
    UNDER-REQUIRED  metadata says MANDATORY, we built it optional or absent  -> can send an
                    incomplete request. This is the defect class that motivated the tool.
    OVER-PERMITTED  we allow a field the metadata branch does not define at all -> can send a field
                    the branch rejects (LIMITATION #1 family, per-branch scope).
    Both are [WARN], never [FAIL]: a build may legitimately tighten or split a branch, and only Rob
    rules on combination semantics. A WARN that names the exact field is what he needs to rule.

  MATCHING is keyRef-first, signature-second. Synthetic keyRefs are legal and common (NY implements
  the RVEH out-of-state branch as RVEHOUT; BUILD_RULES 13 + LIMITATION #21), so an unmatched
  metadata alternative falls back to the built combo with the highest field overlap WITHIN THE SAME
  QUERY. Never across queries: RVEH/RVIN/RNAM each appear in MULTIPLE NY transactions with
  completely different requirement sets, and RNAM appears TWICE inside one transaction.

  Usage: .\audit_requirement_fidelity.ps1 [-Provider <NAME>] [-OutFile <path>]
#>

param([string]$Provider, [string]$Path, [string]$OutFile)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_resolve_provider_xml.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; Write-Host $s -ForegroundColor $c }

# ── field-name canonicalisation ───────────────────────────────────────────────────────
# Built fieldIds diverge from metadata field references in three systematic ways:
#   case/punctuation (vehicleYear vs VehicleYear), DH/CCH isolation suffixes
#   (purposeCodeDH vs PurposeCode), and deliberate renames (RegistrationState vs State).
# Anything NOT in one of those three classes is a real difference and must survive canonicalisation.
$alias = @{
    'state'                  = 'registrationstate'
    'licenseplatenumberout'  = 'licenseplatenumber'
    'articleserialnumber'    = 'serialnumber'
    'gunserialnumber'        = 'serialnumber'   # every provider builds the metadata GunSerialNumber as serialNumber
    'carequestpurposecode'   = 'purposecode'
}
function Canon([string]$t) {
    $k = ($t -replace '[^A-Za-z0-9]', '').ToLower()
    # suffix-strip only -- a bare 'birthdate' must not lose characters, only 'birthdatedh' may.
    if ($k.Length -gt 2 -and $k.EndsWith('dh'))  { $k = $k.Substring(0, $k.Length - 2) }
    if ($k.Length -gt 3 -and $k.EndsWith('cch')) { $k = $k.Substring(0, $k.Length - 3) }
    if ($alias.ContainsKey($k)) { $k = $alias[$k] }
    return $k
}
# 'Name' is a metadata COMPOSITE that the form decomposes into Last/First/Middle/Suffix via
# FormatStringRuleHandler. Treat it as satisfied by any component, else every name-based combination
# on every provider reports a false UNDER-REQUIRED.
# BIDIRECTIONAL, and the first draft was not: it expanded only want=='name', so metadata 'Name' vs
# built 'nameMiddle' failed and every name-based combination on every provider reported a false
# OVER-PERMITTED (12 of the first run's 39 findings).
$nameParts = @('namelast', 'namefirst', 'namemiddle', 'namesuffix', 'name')
function Test-Has([string[]]$pool, [string]$want) {
    if ($pool -contains $want) { return $true }
    if ($nameParts -contains $want) { foreach ($p in $nameParts) { if ($pool -contains $p) { return $true } } }
    return $false
}
# FORM-ONLY fields: platform/form-supplied, not part of any provider combination's field list, so
# their presence in a built any[] is EXPECTED and never an over-permit. audit_metadata.ps1 has
# carried this same whitelist for months -- reused rather than reinvented (LAW 4). Applied to
# OVER-PERMITTED only; a form-only field can still be legitimately metadata-mandatory somewhere.
$formOnly = @('imageindicator', 'registrationstate', 'attention', 'purposecode', 'requestor',
              'emailaddress', 'reasoncode', 'relatedhitsearchindicator', 'randomrequest',
              'dexstateuserid', 'messagekey', 'messagecontinuekeycode')
# IDENTIFIER fields -- the thing the officer is actually searching BY. These must dominate the
# metadata-alternative -> built-combo pairing: a plate alternative must never be matched to a VIN
# combo just because both happen to share State and ImageIndicator. Getting this wrong is what
# reported NJ's FULL{plate} against RANDFULLN (the VIN combo) as UNDER-REQUIRED on fields the VIN
# combo has no business carrying. Everything not on this list is a qualifier, not a search path.
$identifierFields = @('licenseplatenumber', 'vehicleidentificationnumber', 'operatorlicensenumber',
                      'serialnumber', 'boathullidnumber', 'registrationnumber', 'ncicnumber',
                      'decalnumber', 'stickernumber', 'processcontrolnumber', 'titlelieninformation',
                      'coastguarddocumentnumber', 'criminalidnumber', 'socialsecuritynumber',
                      'stateidnumber', 'owner appliednumber', 'ownerappliednumber', 'namelast', 'name')

# ── metadata: expand each Combination into one entry per Choice alternative ────────────
# REQUIRED SETS COME FROM THE SHARED PARSER, not a local copy. The first version of this file
# hand-rolled its own <Choice> walk -- in a tool whose header lectures about LAW 4 -- and got the
# grammar WRONG in two ways the shared one gets right: it never recursed past one nesting level,
# and it folded a bare <Choice><Field> into the OPTIONAL pool when that field is actually an
# ALTERNATIVE (TX GunQuery/QG: 'serial(+caliber/make) OR NCICNumber'). Get-MetaAltSets does the
# full recursive cross-product. Using it means a future grammar fix lands in ONE place, and it is
# the same requirement source gate 6d uses -- so this gate and 6d can no longer disagree about
# what the spec says, which was the whole point.
. (Join-Path $PSScriptRoot '_metadata_parse.ps1')

function Get-MetaAlternatives([string]$xmlPath) {
    $tx  = Get-MetadataTransactions -XmlPath $xmlPath
    # Get-MetaAltSets deliberately DROPS <Any> (optional fields cannot constrain a required set),
    # but OVER-PERMITTED needs to know what the combination legitimately allows. Collect the
    # optional pool separately, as the UNION of every <Any> at any depth inside the combination,
    # keyed by transaction+keyRef. Union rather than per-branch: a slightly WIDER optional pool can
    # only suppress an over-permit finding, never invent one, and over-permit is advisory. Keying by
    # keyRef also merges duplicate-keyRef occurrences, which is the same conservative direction.
    $x = [xml](Get-Content $xmlPath -Raw)
    $anyPool = @{}
    foreach ($t in $x.SelectNodes('//*[local-name()="Transaction"]')) {
        $tn = "$($t.GetAttribute('name'))"; if (-not $tn) { continue }
        foreach ($cb in $t.SelectNodes('.//*[local-name()="Combination"]')) {
            $k = "$tn|$($cb.GetAttribute('keyReference'))"
            if (-not $anyPool.ContainsKey($k)) { $anyPool[$k] = @() }
            foreach ($f in $cb.SelectNodes('.//*[local-name()="Any"]/*[local-name()="Field"]')) {
                $r = "$($f.GetAttribute('reference'))"; if ($r) { $anyPool[$k] += $r }
            }
        }
    }
    $out = @()
    foreach ($qname in @($tx.Keys | Sort-Object)) {
        foreach ($c in $tx[$qname].combos) {
            $kr    = "$($c.keyReference)"
            $sets  = @($c.requiredSets)
            $total = $sets.Count
            $pool  = @()
            if ($anyPool.ContainsKey("$qname|$kr")) { $pool = @($anyPool["$qname|$kr"] | Sort-Object -Unique) }
            $i = 0
            foreach ($rs in $sets) {
                $i++
                $out += [pscustomobject]@{ Query = $qname; KeyRef = $kr
                                           Alt = $(if ($total -gt 1) { $i } else { 0 }); AltTotal = $total
                                           Set = @(@($rs) | Where-Object { $_ }); Any = $pool }
            }
        }
    }
    # UNIQUE INDEX per alternative. Keying the assignment map on query|keyRef|alt collided
    # whenever a transaction declares the SAME keyRef twice (NY RNAM, TX QB/RQ, FL FRQ x7): all
    # duplicates carry alt=0, so several metadata entries read back the SAME built combo and each
    # reported the other's fields as UNDER-REQUIRED. Index, never a natural key.
    for ($i = 0; $i -lt $out.Count; $i++) { $out[$i] | Add-Member -NotePropertyName Idx -NotePropertyValue $i -Force }
    return $out
}

# ── main ──────────────────────────────────────────────────────────────────────────────
Out-Line ''
Out-Line ('=' * 80)
Out-Line '  REQUIREMENT FIDELITY -- built mandatory/optional vs metadata, per Choice branch'
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Out-Line ('=' * 80)

# -Path audits ONE json plus its sibling source/ -- the layout audit_gate_efficacy.ps1 builds for a
# mutation replica. Without it this gate could not be mutation-tested at all, i.e. there was no
# proof it could FAIL, which is precisely LAW 2 and precisely what this tool was written to police.
# A replica has no docs/, so no divergence registry loads and findings are unsuppressed -- correct
# for mutation testing, where detection is measured as an INCREASE over the same-mode baseline.
if ($Path) {
    if (-not (Test-Path $Path)) { Out-Line "  [FAIL] -Path not found: $Path" 'Red'; exit 1 }
    $pn = [System.IO.Path]::GetFileNameWithoutExtension($Path) -replace '_v[0-9]+\.[0-9]+$', ''
    $dirs = @([pscustomobject]@{ FullName = (Split-Path $Path -Parent); Name = $pn })
} else {
    $dirs = Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name
    if ($Provider) { $dirs = @($dirs | Where-Object { $_.Name -eq $Provider }) }
    if (-not $dirs) { Out-Line "  [FAIL] provider '$Provider' not found" 'Red'; exit 1 }
}

$totUnder = 0; $totOver = 0; $totMatched = 0; $totUnmatched = 0

foreach ($d in $dirs) {
    $jp = if ($Path) { $Path } else { Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name }
    if (-not $jp) { continue }
    # Shared resolver. Was two hand-rolled globs: exact-name first (correct), then a bare
    # alphabetical fallback that WOULD have guessed on any provider carrying a second XML.
    $xmlResolved = Get-ProviderMetadataXml -Provider $d.Name -ProvDir $d.FullName
    $xml = if ($xmlResolved) { Get-Item $xmlResolved } else { $null }
    if (-not $xml) { Out-Line "`n=== $($d.Name) ===" 'Cyan'; Out-Line '  [FAIL] no metadata XML in source/ -- cannot verify fidelity' 'Red'; $totUnmatched++; continue }

    # ── ACCEPTED-DIVERGENCE REGISTRY ──────────────────────────────────────────────────
    # Without this the gate cries wolf on decisions ALREADY adjudicated and recorded, which is how
    # a gate teaches people to ignore it. TX_TLETS is the case: all 9 of its first-run findings are
    # registered -- regionId/VehicleMakeCode/VehicleYear ride in any[] under `promoted-to-any`
    # (Rob standing rule: never DROP a devdoc-optional combination field), and the UNDER-REQUIRED
    # ones are spillover from QV/QW, which are deliberately unbuilt platform-auto-fired shadows.
    # A deliberately-unbuilt metadata alternative must be SKIPPED, not force-matched to a sibling:
    # force-matching is what reported CPL against DQOLN and QV against RQ{VIN}.
    # Same convention as audit_combo_reachability / audit_log_combo_attribution: registered =>
    # [NOTE], never [WARN], so a genuinely NEW fidelity defect still stands out.
    $unbuiltRows = @(); $promoted = @{}; $demoted = @{}
    $dvf = @(Get-ChildItem (Join-Path $d.FullName 'docs') -Recurse -Filter '*ACCEPTED_DIVERGENCES*' -File -ErrorAction SilentlyContinue) | Select-Object -First 1
    if ($dvf) {
        foreach ($ln in (Get-Content $dvf.FullName)) {
            $p = $ln -split '\|'
            if ($p.Count -lt 4) { continue }
            $q = $p[0].Trim(); $k = $p[1].Trim(); $fd = $p[2].Trim(); $rule = $p[3].Trim()
            # The registry keyRef column holds the BUILT combo name (QVLicensePlateNumber) or a
            # devdoc pointer ("(devdoc #3)"), while a METADATA keyRef is bare (QV, QW). Exact
            # matching therefore suppressed nothing on TX. Bridge it three ways, deliberately
            # generous -- registered-unbuilt only ever downgrades WARN to NOTE, and the NOTE count
            # is printed so over-suppression stays visible:
            #   exact | registry keyRef PREFIXED by the metadata keyRef (QV -> QVLicensePlateNumber)
            #   | the row TEXT names the metadata keyRef on a word boundary (the QW row is filed
            #     under "(devdoc #3)" and says "metadata keyRef QW" in its reason).
            if ($rule -match '(?i)shadow|unbuilt|not-built|dropped-combo|dead-combo' -and $rule -notmatch '(?i)restored') {   # 'not-built' does NOT contain 'unbuilt' (hyphenated), so FL's QW|*|not-built and QV|*|not-built rows were silently INERT. 'RESTORED' excluded because a restored combo IS built -- including it cost TX 2 branches of coverage.
                $unbuiltRows += [pscustomobject]@{ Query = $q; KeyRef = $k; Rule = $rule; Text = $ln }
            }
            if ($rule -match '(?i)promoted-to-any')     { $promoted["$q|$k|$(Canon $fd)"] = $rule }
            # UNDER-REQUIRED had NO registry path at all -- a DELIBERATE demotion of a
            # metadata-mandatory field into any[] could never be recorded, so NJ's documented
            # RANDFULL/RANDFULLN merge kept being re-reported as 7 findings forever. 'demoted-to-any'
            # is the to-any-class rule that says: we know metadata calls this mandatory, we ride it in
            # any[] on purpose, and here is why.
            if ($rule -match '(?i)demoted-to-any')      { $demoted["$q|$k|$(Canon $fd)"] = $rule }
        }
    }

    function Test-RegisteredUnbuilt([string]$q, [string]$kr, [string[]]$altSet) {
        if (-not $kr) { return $false }
        foreach ($r in $script:unbuiltRows) {
            if ($r.Query -ne $q -and $r.Query -ne '*') { continue }
            if ($r.KeyRef -eq $kr) { return $true }
            # PREFIX BRIDGE, NARROWED. The registry names a BUILT combo (FRQTitleLienInformation)
            # while a METADATA keyRef is bare (FRQ), so a prefix hit is needed to connect them. But a
            # bare prefix hit says "the whole FRQ FAMILY is unbuilt" when the row actually retires ONE
            # combination -- and FL_FCIC has exactly that row, so all FOUR FRQ metadata alternatives
            # were silently skipped and never compared. That is why the fl-fidelity-demote-mandatory
            # mutation SURVIVED: LicensePlateYear could be demoted out of FRQDecalNumber's set[] and
            # this gate had nothing to say, because FRQ{Decal} was not being examined at all.
            # A prefix hit must therefore also IDENTIFY the branch: the registry keyRef's suffix past
            # the metadata keyRef (here 'TitleLienInformation') has to name one of THIS alternative's
            # set[] fields. FRQ{TitleLien} matches and stays suppressed; FRQ{Decal}, FRQ{Plate} and
            # FRQ{VIN} no longer do. An empty suffix is the exact-match case handled above.
            if ($r.KeyRef.StartsWith($kr)) {
                $suffix = $r.KeyRef.Substring($kr.Length).Trim()
                if (-not $suffix) { return $true }
                $sc = Canon $suffix
                foreach ($sf in @($altSet)) { if ((Canon $sf) -eq $sc) { return $true } }
                # named a sibling branch, not this one -- do NOT suppress
            }
            # An EXPLICIT phrase only -- never a bare word-boundary hit on the reason prose.
            # Bare \bKR\b over-suppressed a REAL combination: the QV shadow row explains QV is
            # "an ungated SUBSET of REG (Plate+Year+FRT)", so metadata REG matched the QV row and
            # the whole REG branch was skipped as registered-unbuilt. TX then read 0 UNDER-REQUIRED
            # partly because REG was not being checked at all, and audit_gate_efficacy caught it as
            # a SURVIVED mutation -- the harness was right and this suppression was wrong.
            # A registry row that means "metadata keyRef X is unbuilt" must SAY so.
            if ($r.Text -match "(?i)metadata\s+keyRef\s+$([regex]::Escape($kr))\b") { return $true }
        }
        return $false
    }
    $script:unbuiltRows = $unbuiltRows

    $meta = Get-MetaAlternatives $xml.FullName
    $raw  = Get-Content $jp -Raw | ConvertFrom-Json

    # built combos, grouped by the query the QIDM targets
    $built = @{}
    foreach ($b in $raw.bundles) {
        foreach ($c in $b.configurations) {
            if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ("$($c.provider)" -eq 'RMS' -or "$($c.name)" -match '^RMS ') { continue }
            $q = "$($c.name)" -replace "^$([regex]::Escape($d.Name))_", ''
            if (-not $built.ContainsKey($q)) { $built[$q] = @() }
            foreach ($cm in $c.combinations) {
                $built[$q] += [pscustomobject]@{ KeyRef = "$($cm.keyReference)"
                                                 Set = @($cm.requirements.set    | Where-Object { $_ })
                                                 Any = @($cm.requirements.any    | Where-Object { $_ }) }
            }
        }
    }

    # SELF-CHECK: an UNBUILT-class registry row whose KeyRef names a combo that IS BUILT silently
    # suppresses that combo's whole comparison via Test-RegisteredUnbuilt (exact or prefix match
    # against the metadata keyRef). That is how coverage quietly drops while the finding count stays
    # at zero -- indistinguishable from a clean run unless you watch BRANCHES-COMPARED.
    # Live-caught TWICE: FL_FCIC's 'FRQTitleLienInformation | not-built' row muted all four FRQ
    # branches (27 compared while 3 were dark), and on 2026-07-31 a 'VehicleRegistrationQuery |
    # IA.QV | devdoc-combo-unbuilt' row added by hand dropped CA_CLETS from 27 branches to 26 --
    # IA.QV is built and working; only the devdoc ITEM was unbuilt. An unbuilt-class row must name
    # the unbuilt thing (e.g. '(devdoc #1)'), never a live combo.
    $allBuiltKrs = @{}
    foreach ($qk in $built.Keys) { foreach ($cmb in $built[$qk]) { if ($cmb.KeyRef) { $allBuiltKrs["$($cmb.KeyRef)"] = $qk } } }
    foreach ($rr in $unbuiltRows) {
        if ($rr.KeyRef -and $allBuiltKrs.ContainsKey($rr.KeyRef)) {
            Out-Line ("  [NOTE] REGISTRY OVER-SUPPRESSION RISK: unbuilt-class row '$($rr.Query) | $($rr.KeyRef) | $($rr.Rule)' names a combo that IS BUILT (in $($allBuiltKrs[$rr.KeyRef])). That row suppresses this combo's comparison entirely -- point the keyRef at the unbuilt devdoc item instead (e.g. '(devdoc #N)') and re-check BRANCHES-COMPARED.") 'Yellow'
        }
    }

    Out-Line "`n=== $($d.Name)  ($(Split-Path $jp -Leaf)) ===" 'Cyan'
    $pUnder = 0; $pOver = 0; $pMatched = 0; $pNote = 0

    # ── ONE-TO-ONE ASSIGNMENT, per query ──────────────────────────────────────────────
    # The first draft matched each metadata alternative INDEPENDENTLY, so several alternatives
    # collapsed onto the SAME built combo and every unmatched alternative reported its whole set[]
    # as UNDER-REQUIRED/ABSENT. That produced NY's bogus "DLIC UNDER-REQUIRED BirthDate, Name,
    # SexCode" and both providers' bogus "GunSerialNumber ABSENT": those transactions declare the
    # SAME keyRef twice with different sets (NY's RNAM appears twice in one transaction), so the
    # name-based alternative was scored against the OLN-based built combo.
    # Greedy, most-specific-first: each built combo can win at most one alternative. An alternative
    # left unassigned is a genuine coverage question -- and it belongs to audit_query_trace (2p),
    # not here, so it is skipped rather than reported as a fidelity defect.
    $assign = @{}
    foreach ($q in @($meta | ForEach-Object { $_.Query } | Sort-Object -Unique)) {
        if (-not $built.ContainsKey($q)) { continue }
        $used  = @{}
        $alts  = @($meta | Where-Object { $_.Query -eq $q -and -not (Test-RegisteredUnbuilt $_.Query $_.KeyRef @($_.Set)) } | Sort-Object { -(@($_.Set).Count) })
        foreach ($m in $alts) {
            $mS = @($m.Set | ForEach-Object { Canon $_ }); $mA = @($m.Any | ForEach-Object { Canon $_ })
            $best = $null; $bestScore = -999; $bestKey = $null
            $ci = -1
            # N:1 IS LEGAL, and forcing 1:1 was the bug. When metadata alternatives OUTNUMBER built
            # combos, sharing is REQUIRED: NJ has 4 alternatives (RAND/FULL x plate/VIN) against 2
            # built combos, so RAND{plate} AND FULL{plate} both belong to RANDFULL. Forcing 1:1 left
            # two alternatives to pair with whatever was left -- FULL{plate} landed on RANDFULLN, the
            # VIN combo, which legitimately has no plate fields, and was reported as UNDER-REQUIRED.
            # The original 1:1 was added for FL's FRQ collapse, but that was MIS-PAIRING, not
            # sharing. The real fix is scoring: an IDENTIFIER field must dominate, so a plate
            # alternative can never pair to a VIN combo. Identifier agreement is what makes a pairing
            # meaningful -- everything else is a qualifier.
            foreach ($cd in @($built[$q])) {
                $ci++
                $cS = @($cd.Set | ForEach-Object { Canon $_ })
                $score = 0
                foreach ($w in $mS) {
                    $isId = $identifierFields -contains $w
                    if (Test-Has $cS $w) { $score += $(if ($isId) { 12 } else { 3 }) }
                    else                 { $score -= $(if ($isId) { 12 } else { 1 }) }
                }
                foreach ($w in $cS) {
                    if ((Test-Has $mS $w) -or (Test-Has $mA $w)) { continue }
                    $score -= $(if ($identifierFields -contains $w) { 12 } else { 2 })
                }
                # Built keyRefs follow 'metadata keyRef + identifier suffix' across the whole
                # portfolio (QB -> QBBoatHullIdNumber, FRQ -> FRQLicensePlateNumber, RAND -> RANDFULL).
                # Without a PREFIX bonus, metadata QB{hull} and built FBQBoatHullIdNumber tie with
                # QBBoatHullIdNumber on the identifier alone and array order decides -- which paired
                # FL's QB alternatives to the FBQ family and invented 4 over-permits.
                if ($cd.KeyRef -eq $m.KeyRef) { $score += 10 }
                elseif ($cd.KeyRef -like "$($m.KeyRef)*") { $score += 8 }
                if ($score -gt $bestScore) { $bestScore = $score; $best = $cd; $bestKey = $ci }
            }
            if ($best -ne $null) { $assign["$($m.Idx)"] = $best }
        }
    }

    # ── SHARED-COMBO UNION: one built combo may legitimately serve SEVERAL Choice alternatives ──
    # Exposed by CA_CLETS 2026-07-31 and invisible on TX/NY/NJ/FL, none of which has this shape.
    # Metadata offers a Choice of BirthDate OR Age; ONE built combo (IR.QVC.N, IG.QGH) serves both
    # branches by carrying one in set[] and riding the other in any[] -- which is exactly right.
    # Evaluating each alternative IN ISOLATION made every such pair report the OTHER branch's field
    # as foreign, in perfectly mirrored pairs:
    #     alt1 UNDER-REQUIRED BirthDate + OVER-PERMITTED age
    #     alt2 UNDER-REQUIRED Age       + OVER-PERMITTED BirthDate
    # Both directions cannot be true at once -- a mirrored pair is the signature of an isolation
    # artifact, not a defect. So when several alternatives share a built combo, that combo's
    # legitimate field pool is the UNION of their set[]+any[], and a field is only UNDER-REQUIRED if
    # NO sharing alternative can satisfy it.
    $shared = @{}
    foreach ($mm in $meta) {
        $bb = $assign["$($mm.Idx)"]
        if (-not $bb) { continue }
        $sk = "$($mm.Query)|$($bb.KeyRef)"
        if (-not $shared.ContainsKey($sk)) { $shared[$sk] = @{ Set = @(); Any = @(); N = 0 } }
        $shared[$sk].N++
        $shared[$sk].Set += @($mm.Set | ForEach-Object { Canon $_ })
        $shared[$sk].Any += @($mm.Any | ForEach-Object { Canon $_ })
    }

    foreach ($m in $meta) {
        if (-not $built.ContainsKey($m.Query)) { continue }   # query not built: 2p/2e own that
        if (Test-RegisteredUnbuilt $m.Query $m.KeyRef @($m.Set)) { $pNote++; continue }
        $b0 = $assign["$($m.Idx)"]
        if (-not $b0) { continue }
        $shKey  = "$($m.Query)|$($b0.KeyRef)"
        $shN    = if ($shared.ContainsKey($shKey)) { $shared[$shKey].N } else { 1 }
        $shPool = if ($shared.ContainsKey($shKey)) { @($shared[$shKey].Set) + @($shared[$shKey].Any) } else { @() }
        # ANY-ONLY pool: the fields some sharing alternative treats as OPTIONAL. The UNDER-REQUIRED
        # skip must key on THIS, not on "the combo is shared" -- otherwise a shared combo excuses ANY
        # mandatory field being demoted to any[], which is a real defect. Measured 2026-07-31: the
        # nj-fidelity-demote-mandatory mutation flipped KILLED -> SURVIVED because demoting
        # LicensePlateNumber into any[] satisfied the too-broad rule, even though EVERY NJ alternative
        # requires the plate. The BirthDate/Age case this was built for is different: there one branch
        # genuinely lists the field as optional.
        $shAny = if ($shared.ContainsKey($shKey)) { @($shared[$shKey].Any) } else { @() }
        $mSetC = @($m.Set | ForEach-Object { Canon $_ })
        $mAnyC = @($m.Any | ForEach-Object { Canon $_ })
        $pMatched++

        $bSetC = @($b0.Set | ForEach-Object { Canon $_ })
        $bAnyC = @($b0.Any | ForEach-Object { Canon $_ })
        $tag = if ($m.AltTotal -gt 1) { "$($m.KeyRef)[alt$($m.Alt)/$($m.AltTotal)]" } else { $m.KeyRef }

        # UNDER-REQUIRED: metadata-mandatory, built optional or absent
        $under = @()
        for ($i = 0; $i -lt $mSetC.Count; $i++) {
            $w = $mSetC[$i]
            if (Test-Has $bSetC $w) { continue }
            if ($shN -gt 1 -and (Test-Has $bAnyC $w) -and (Test-Has $shAny $w)) { $pNote++; continue }   # shared combo AND some sibling branch genuinely lists this field as OPTIONAL -> riding it in any[] serves both. Requiring $shAny is what keeps this from excusing a real demotion.
            # A DELIBERATE demotion, recorded with rule 'demoted-to-any', is a decision -- not an
            # omission. Before this, UNDER-REQUIRED had NO registry path at all, so NJ's documented
            # RANDFULL/RANDFULLN merge (metadata RAND and FULL are byte-identical, so building both
            # would guarantee a dead combo) was re-reported as 7 findings on every single run with no
            # way to ever close them. OVER-PERMITTED always had $promoted; this is its counterpart.
            if ($demoted.ContainsKey("$($m.Query)|$($b0.KeyRef)|$w") -and (Test-Has $bAnyC $w)) { $pNote++; continue }   # the registered decision is "it RIDES IN any[]" -- if the field is absent from any[] TOO it is not the situation that was granted, and must still report. Without this guard the entry also excused a strictly WORSE state (field transmittable nowhere), which is what let nj-drop-metadata-mandatory survive.
            $where = if (Test-Has $bAnyC $w) { 'built any[]' } else { 'ABSENT' }
            $under += "$($m.Set[$i]) ($where)"
        }
        # OVER-PERMITTED: built any[] member the branch does not define at all
        $over = @()
        for ($i = 0; $i -lt $bAnyC.Count; $i++) {
            $w = $bAnyC[$i]
            if ((Test-Has $mSetC $w) -or (Test-Has $mAnyC $w)) { continue }
            if ($formOnly -contains $w) { continue }
            if ($shN -gt 1 -and ($shPool -contains $w)) { $pNote++; continue }   # shared combo: another Choice branch served by this same combo DOES define the field
            if ($promoted.ContainsKey("$($m.Query)|$($b0.KeyRef)|$w")) { $pNote++; continue }
            $over += "$($b0.Any[$i])"
        }

        if ($under.Count) {
            Out-Line "  [WARN] $($m.Query) / $tag -> built '$($b0.KeyRef)' UNDER-REQUIRED: $($under -join '; ')" 'Yellow'
            $pUnder += $under.Count
        }
        if ($over.Count) {
            Out-Line "  [WARN] $($m.Query) / $tag -> built '$($b0.KeyRef)' OVER-PERMITTED: $($over -join '; ')" 'Yellow'
            $pOver += $over.Count
        }
    }

    $noteTxt = if ($pNote) { " [$pNote registered divergence(s) -> NOTE]" } else { '' }
    if (-not $pUnder -and -not $pOver) { Out-Line "  [PASS] $pMatched matched branch(es), 0 UNDER-REQUIRED / 0 OVER-PERMITTED$noteTxt" 'Green' }
    else { Out-Line "  ---- $pMatched matched branch(es): $pUnder UNDER-REQUIRED, $pOver OVER-PERMITTED$noteTxt" 'Yellow' }
    $totUnder += $pUnder; $totOver += $pOver; $totMatched += $pMatched
}

Out-Line ''
Out-Line ('-' * 80)
Out-Line "  TOTALS: $totMatched branch(es) compared / $totUnder UNDER-REQUIRED / $totOver OVER-PERMITTED"
Out-Line '  UNDER-REQUIRED = we can send an INCOMPLETE request the metadata calls invalid.'
Out-Line '  OVER-PERMITTED = we can send a field this branch does not define.'
Out-Line '  Advisory: only Rob rules on combination semantics. Never auto-tighten a set[] --'
Out-Line '  a mandatory field that the form PREFILLS becomes an always-true discriminator and'
Out-Line '  silently kills every sibling combination ordered after it (BUILD_RULES 24).'
Out-Line ('-' * 80)

if ($OutFile) {
    $lines | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "  -> $OutFile" -ForegroundColor DarkGray
}
exit 0
