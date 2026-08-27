<#
  audit_devdoc_optionals.ps1 -- every devdoc combination x EVERY SUBSET of its optionals.

  WHY THIS EXISTS (Rob 2026-07-30: "look at the devdoc combination with optionals and account
  for every combination with every combination of optionals. that was a long standing directive
  and i no longer trust you to do it right and recall saved conclusions."):
    Every existing gate checks a combination's MANDATORY fields. None has ever checked what
    happens when the officer also fills the [bracketed] OPTIONAL fields the devdoc lists -- and
    an optional field can do two things that are invisible to a mandatory-only check:

      1. NO-FIRE / RE-ROUTE. Adding an optional can change WHICH combo wins first-match, or the
         mandatory-only fill can match NOTHING at all because our set[] demands a field the
         devdoc calls optional. Example this tool was written to catch: devdoc Vehicle #1 is
         "(InState) LicensePlateNumber, LicensePlateYear, [FinancialResponsibilityType]" -- FRT
         OPTIONAL -- but the built REG combo has FRT in set[]. Plate+Year with FRT omitted is a
         devdoc-legal fill that matches no combo.
      2. DROPPED OPTIONAL. The officer types a devdoc-legal optional, it is not in the winning
         combo's set[]/any[] (nor any co-matching combo's, so the LIMITATION #1 union pool does
         not carry it either), and it is silently not transmitted. The query still succeeds, just
         narrower than the officer asked for -- the worst kind of defect because nothing errors.

  THE UNION POOL IS DELIBERATE AND CORRECT -- DO NOT "FIX" IT INTO A PER-COMBO CHECK.
  Read this before concluding the "[NOTE] ... re-routes X -> Y (discriminator)" line masks a
  dropped optional. It cannot: the DROPPED check runs FIRST and `continue`s, so the re-route NOTE
  is only ever reached when nothing was dropped.
  I got this wrong on 2026-08-12 and reported a gate hole that does not exist. The mutation that
  fooled me removed `Requestor` from ONE combination (FL_FCIC BoatQuery FBQ{TitleLienInformation})
  and the gate stayed silent -- which I read as blindness. It was a CORRECT SURVIVOR: the fill also
  matched QB{BoatHullIdNumber}, which still carried Requestor, so the field was never dropped.
  That is not a modelling convenience -- it is what the platform actually does. LIMITATION #40
  (LIVE-PROVEN 2026-08-12, 38/38 FL Boat logs, 0 mispredicted): THE WIRE IS A UNION ACROSS EVERY
  MATCHING COMBINATION, not the firing combination's field list. A per-combo check here would
  report drops that demonstrably do not occur.
  PROOF THE GATE STILL BITES (LAW 2, run 2026-08-12): strip `Requestor` from EVERY Boat combination
  -- 12 lists, 0 combos left carrying it -- and the same fills that were silent now FAIL, including
  `+[Requestor,TitleLienInformation] -> fires FBQTitleLienInformation`. Clean build: 0 FAIL /
  30 NOTE. Catalogued permanently as `fl-drop-optional-everywhere` in audit_gate_efficacy so this
  behaviour cannot regress unnoticed and the question does not get re-litigated a third time.

    Both classes are invisible to: validate, verify_build, audit_metadata, audit_combo_reachability
    (walks built combos, not devdoc fills), audit_devdoc_combinations (mandatory wiring only), and
    the test plan (generated from the JSON, and it does not enumerate optional powersets).

  METHOD
    Devdoc items come from audit_devdoc_combinations.ps1 -Explain -- deliberately REUSING that
    already-validated parser instead of writing a second one. Four separate parser bugs in this
    toolchain came from re-implementing a parse that already existed; do not add a third copy.
    Routing is evaluated with tools\_sim_helpers.ps1 (Get-FiringKeyRef / Test-ComboMatches), the
    same canonical predicate test_commsys and run_test_matrix use, so this cannot disagree with
    the simulator.

    For each devdoc item, for each of the 2^k subsets of its optionals:
      formData = mandatory fields + that subset (composite Name expands to NameLast+NameFirst;
      DH-/CCH-suffixed fieldIds are matched by canonical name), plus the form's own initialValues
      because a prefill is always present on a real submission.
      -> which combo fires (first match, query-scoped)
      -> transmitted = union of set[]+any[] over ALL co-matching combos (LIMITATION #1 pool)
      -> any filled field not in that union is a DROPPED OPTIONAL

  VERDICTS
    [FAIL] NO-FIRE  -- a devdoc-legal fill matches no combo. Officer types a documented
                       combination and no query goes out.
    [FAIL] DROPPED  -- a devdoc-legal optional is filled but cannot be transmitted by any
                       matching combo.
    [NOTE] RE-ROUTE -- adding an optional changes which keyRef fires. Often correct and
                       intentional (that is what a discriminator IS), so it is reported for
                       human eyes, with the before/after keyRefs.

  Suppress a reviewed FAIL in docs/tracking/<P>_ACCEPTED_DIVERGENCES.txt with rule
  `devdoc-optional-unreachable` (query | keyRef-or-item | field | rule | reason | source | date).

  Usage: .\audit_devdoc_optionals.ps1 -Path providers\TX_TLETS\TX_TLETS_v4.17.json [-Verbose2] [-OutFile <p>]
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [switch]$Verbose2,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir "_sim_helpers.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s, $c) { $lines.Add($s); if ($c) { Write-Host $s -ForegroundColor $c } else { Write-Host $s } }

$jsonPath = (Resolve-Path $Path).Path
$provDir  = Split-Path $jsonPath -Parent
$provName = Split-Path $provDir -Leaf

Emit "" $null
Emit "================================================================" 'Cyan'
Emit "  DEVDOC OPTIONALS x ROUTING -- $provName" 'Cyan'
Emit "  every devdoc combination against EVERY subset of its optionals" 'Cyan'
Emit "================================================================" 'Cyan'

# ── devdoc items, from the already-validated parser ────────────────────────────────────
$ddTool = Join-Path $toolDir "audit_devdoc_combinations.ps1"
if (-not (Test-Path $ddTool)) { Emit "  [FAIL] audit_devdoc_combinations.ps1 not found -- cannot source devdoc items" 'Red'; exit 1 }
$ddRaw = & powershell -ExecutionPolicy Bypass -File $ddTool -Path $jsonPath -Explain 2>&1 | Out-String

$items = @()
foreach ($ln in ($ddRaw -split "`n")) {
    $m = [regex]::Match($ln, 'devdoc\s+(\S+)\s+#(\d+):\s*mand=\[([^\]]*)\]\s*opt=\[([^\]]*)\]')
    if (-not $m.Success) { continue }
    $items += [pscustomobject]@{
        Query = $m.Groups[1].Value
        Num   = [int]$m.Groups[2].Value
        Mand  = @($m.Groups[3].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Opt   = @($m.Groups[4].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
}
if (-not $items.Count) {
    Emit "  [FAIL] parsed 0 devdoc items from audit_devdoc_combinations -Explain -- do NOT read this as 'all clear'" 'Red'
    if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
    exit 1
}
Emit "  devdoc items parsed: $($items.Count)" $null

# ── the built side ────────────────────────────────────────────────────────────────────
$j = Get-Content $jsonPath -Raw | ConvertFrom-Json
$qidms = @{}      # query -> qidm object
$prefill = @{}    # entity -> @{fieldId=value}   (a prefill is present on every real submission)
foreach ($b in $j.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.combinations -and $c.name -notmatch '^RMS' -and $c.name -notmatch 'Results$') {
            $q = $c.name -replace "^$([regex]::Escape($provName))_",''
            if ($q -match 'Query$') { $qidms[$q] = $c }
        }
        if ($c.type -eq 'QUERYINPUTFORM' -and $c.layout.'default') {
            $ent = "$($c.targetEntity)"
            if (-not $prefill.ContainsKey($ent)) { $prefill[$ent] = @{} }
            $lay = $c.layout.'default'
            foreach ($nid in $lay.PSObject.Properties.Name) {
                $p = $lay.$nid.props
                if ($p -and $p.fieldId -and $null -ne $p.initialValue -and "$($p.initialValue)".Trim() -ne '') {
                    $prefill[$ent]["$($p.fieldId)"] = "$($p.initialValue)"
                }
            }
        }
    }
}

function Canon([string]$t) {
    $k = ($t -replace '[^A-Za-z0-9]','').ToLower()
    ($k -replace 'dh$','') -replace 'cch$',''
}
# devdoc name -> the actual built ref(s) for THIS qidm. Composite Name expands.
$expand = @{ 'name' = @('namelast','namefirst'); 'state' = @('registrationstate','state')
             'gunserialnumber' = @('serialnumber','gunserialnumber')
             'articleserialnumber' = @('articleserialnumber','serialnumber')
             'gunmake' = @('gunmake','firearmmake'); 'badgenumber' = @('dexstateuserid','badgenumber') }

function Resolve-Refs($qidm, [string]$devTok) {
    $refs = @()
    foreach ($cm in $qidm.combinations) {
        foreach ($f in @($cm.requirements.set)) { if ($f) { $refs += "$f" } }
        foreach ($f in @($cm.requirements.any)) { if ($f) { $refs += "$f" } }
    }
    foreach ($a in $qidm.attributes) {
        if ($a.sourceField -is [System.Array]) { foreach ($s in $a.sourceField) { if ($s) { $refs += "$s" } } }
        elseif ($a.sourceField) { $refs += "$($a.sourceField)" }
    }
    $refs = @($refs | Select-Object -Unique)
    $c = Canon $devTok
    $want = if ($expand.ContainsKey($c)) { @($expand[$c]) } else { @($c) }
    $hit = @()
    foreach ($w in $want) { foreach ($r in $refs) { if ((Canon $r) -eq $w) { $hit += $r } } }
    return ,@($hit | Select-Object -Unique)
}

# ── walk every item x every optional subset ───────────────────────────────────────────
$accepted = @()      # rule 'devdoc-optional-unreachable' -- honoured by BOTH branches
$acceptedExist = @() # EXISTENCE-class rules -- honoured ONLY by the NO-COMBO-FIRES branch
. (Join-Path $PSScriptRoot '_divergence_rules.ps1')
$accPath = Join-Path $provDir "docs\tracking\${provName}_ACCEPTED_DIVERGENCES.txt"
if (Test-Path $accPath) {
    foreach ($l in (Get-Content $accPath)) {
        if ($l -match '^\s*#' -or -not $l.Trim()) { continue }
        $p = $l -split '\|'
        if ($p.Count -lt 4) { continue }
        $rule = $p[3].Trim()
        $row  = [pscustomobject]@{ Query = $p[0].Trim(); Field = $p[2].Trim().ToLower(); Rule = $rule }
        if ($p.Count -ge 5 -and $rule -eq 'devdoc-optional-unreachable') { $accepted += $row }
        elseif ((Get-DivergenceRuleClass $rule) -eq 'existence')        { $acceptedExist += $row }
    }
}
function Test-Accepted([string]$q, [string[]]$fields) {
    foreach ($a in $accepted) {
        if ($a.Query -ne $q) { continue }
        foreach ($f in $fields) { if ((Canon $f) -eq (Canon $a.Field)) { return $true } }
    }
    return $false
}
# EXISTENCE-class acceptance, deliberately scoped to the NO-COMBO-FIRES branch ONLY.
#
# WHY IT EXISTS: 2p (audit_devdoc_combinations) hardcodes rule 'devdoc-combo-unbuilt' and 2q
# hardcoded 'devdoc-optional-unreachable', and NEITHER consulted _divergence_rules.ps1 -- the shared
# vocabulary that exists precisely so tools agree about what a recorded decision silences. So one
# adjudicated "this devdoc combination cannot be built" could not be written in a single way both
# gates honoured: IL_LEADS_OFML's Article-#2 row satisfied 2p and was INERT here, leaving a permanent
# [FAIL] on a decision that was correctly made, reasoned and recorded on 2026-08-02.
#
# WHY IT IS *NOT* HONOURED BY THE DROPPED-OPTIONAL BRANCH -- measured 2026-08-07, and the naive
# version of this change was ABANDONED because of it. Test-Accepted matches a row against ANY field
# of the devdoc item, so an existence row is far too coarse for the routing branch: LA_LEMS carries
# 'BoatQuery | BQ | BoatHullIdNumber | not-built', and its live 2q finding is the DROPPED OPTIONAL
# "BoatQuery #1 +[State] -> fires QB but optional(s) State ... silently not transmitted". Honouring
# existence rows there would have matched on BoatHullIdNumber and silenced a REAL, currently-PARKED
# finding that Rob has explicitly said must not be silenced. A combination being unbuilt says nothing
# about whether a DIFFERENT, built combination drops an optional.
#
# The distinction is exact and already structural in this file: `-not $fired` is an EXISTENCE
# question ("does any combination serve this fill?"), which an existence row legitimately answers;
# the else-branch is a ROUTING question ("does the winner carry this field?"), which it does not.
function Test-AcceptedExistence([string]$q, [string[]]$fields) {
    foreach ($a in $acceptedExist) {
        if ($a.Query -ne $q) { continue }
        foreach ($f in $fields) { if ((Canon $f) -eq (Canon $a.Field)) { return $true } }
    }
    return $false
}

$fails = 0; $notes = 0; $combos = 0; $skipped = 0; $script:mandChecked = 0
foreach ($it in ($items | Sort-Object Query, Num)) {
    if (-not $qidms.ContainsKey($it.Query)) { continue }
    $qidm = $qidms[$it.Query]
    $ent  = "$($qidm.targetEntity)"

    # resolve mandatory; if any is unwired this item is already reported by 2p -- skip cleanly
    # NOTE: "wired nowhere" belongs to 2p. "wired SOMEWHERE but not on the combination that fires
    # for this devdoc item" belonged to NOBODY until 2026-08-27 -- see the MANDATORY NOT TRANSMITTED
    # check further down. $mandResolved keeps the per-token refs that check needs; $mandRefs stays
    # a flat list so the fill-building code below is untouched.
    $mandRefs = @(); $unwired = @(); $mandResolved = @()
    foreach ($t in $it.Mand) {
        $r = Resolve-Refs $qidm $t
        if (-not $r.Count) { $unwired += $t } else { $mandRefs += $r; $mandResolved += [pscustomobject]@{ Tok = $t; Refs = $r } }
    }
    if ($unwired.Count) {
        Emit "  [SKIP] $($it.Query) #$($it.Num) -- mandatory $($unwired -join ', ') wired nowhere (audit_devdoc_combinations / PHASE 2p owns this)" 'DarkGray'
        $skipped++
        continue
    }

    $optResolved = @()
    foreach ($t in $it.Opt) {
        $r = Resolve-Refs $qidm $t
        if ($r.Count) { $optResolved += [pscustomobject]@{ Tok = $t; Refs = $r } }
    }

    $k = $optResolved.Count
    $baseKey = $null
    for ($mask = 0; $mask -lt [Math]::Pow(2,$k); $mask++) {
        $fd = @{}
        foreach ($kv in $prefill[$ent].GetEnumerator()) { $fd[$kv.Key] = $kv.Value }   # prefills always present
        foreach ($r in $mandRefs) { $fd[$r] = 'X' }
        $usedToks = @()
        for ($i = 0; $i -lt $k; $i++) {
            if ($mask -band [Math]::Pow(2,$i)) {
                foreach ($r in $optResolved[$i].Refs) { $fd[$r] = 'X' }
                $usedToks += $optResolved[$i].Tok
            }
        }
        $combos++
        $fired = Get-FiringKeyRef @($qidm) $fd
        if ($mask -eq 0) { $baseKey = $fired }

        $label = "$($it.Query) #$($it.Num)" + $(if ($usedToks.Count) { " +[$($usedToks -join ',')]" } else { " (mandatory only)" })

        if (-not $fired) {
            if (Test-Accepted $it.Query (@($it.Mand) + $usedToks)) {
                Emit "  [NOTE] $label -> NO COMBO FIRES (accepted divergence)" 'Yellow'; $notes++
            } elseif (Test-AcceptedExistence $it.Query (@($it.Mand) + $usedToks)) {
                Emit "  [NOTE] $label -> NO COMBO FIRES (accepted divergence: existence-class registry row -- this devdoc combination is recorded as unbuildable)" 'Yellow'; $notes++
            } else {
                Emit "  [FAIL] $label -> NO COMBO FIRES. A devdoc-legal fill sends no query." 'Red'
                Emit "         filled: $((($fd.Keys | Sort-Object) -join ', '))" 'DarkGray'
                $fails++
            }
            continue
        }

        # union pool = set[]+any[] over ALL co-matching combos (LIMITATION #1)
        $filled = Get-SimFilledRefs $qidm $fd
        $pool = @()
        foreach ($cm in $qidm.combinations) {
            if (Test-ComboMatches $cm $filled $fd) {
                foreach ($f in @($cm.requirements.set)) { if ($f) { $pool += "$f" } }
                foreach ($f in @($cm.requirements.any)) { if ($f) { $pool += "$f" } }
            }
        }
        $poolC = @($pool | ForEach-Object { Canon $_ } | Select-Object -Unique)

        # ---- MANDATORY NOT TRANSMITTED (added 2026-08-27) --------------------------------------
        # THE HOLE THIS CLOSES, and why it sat open: the pool above is exactly what reaches the wire,
        # and until now ONLY the filled OPTIONALS were checked against it. The devdoc-MANDATORY
        # fields were used to build the fill and fire the combo, then never verified to be carried
        # by the combo that fired. Two neighbouring gates each assume the other has it:
        #   * audit_devdoc_combinations (2p) asks whether a mandatory field is wired SOMEWHERE in the
        #     query -- satisfied by ANY sibling combo -- and the [SKIP] above defers to it by name.
        #   * this gate tracked optionals only.
        # So "wired on a sibling, missing from the one that fires" was invisible to both.
        # PROVEN, not theorised (LAW 2, OR_LEDS 2026-08-27): OR devdoc VehicleRegistrationQuery #4 is
        # "(Out) VehicleIdentificationNumber, State [VehicleMakeCode, VehicleYear]" -- State is
        # MANDATORY -- and it rides in RQ.V's any[]. Removing it there leaves it wired on RQ.PO/RQ.P,
        # so an out-of-state VIN query silently stops sending the destination state. Mutation test:
        # SURVIVED all 7 gates that reached a verdict, byte-identical output on both arms.
        # WHY THIS IS NOT audit_requirement_fidelity's job: that gate compares against the METADATA
        # alternative, and OR's metadata has State in <Any> on RQ{VIN} -- optional, so a request
        # without it is perfectly VALID. Nothing is metadata-wrong here. What breaks is LAW 1: the
        # officer can no longer perform a devdoc-listed search. Different authority, different gate.
        # *** ONLY WHEN THE FILL HAS NOT RE-ROUTED. This guard is the whole check. ***
        # Without it the first sweep produced 31 findings on 11 providers -- and the ones I read were
        # all the SAME false positive: an IDENTIFIER-PRIORITY GUARDRAIL doing its job. devdoc
        # BoatQuery "#3 mand=[RegistrationNumber] opt=[BoatHullIdNumber,...]" fills reg + hull, the
        # Hull>Reg guardrail correctly routes to the HULL combo, and that combo legitimately does not
        # carry RegistrationNumber -- an adjudication several providers already carry as an accepted
        # divergence (e.g. OR_LEDS "BoatQuery | BQ.H | RegistrationNumber"). Once the fill re-routes,
        # the officer is performing a DIFFERENT devdoc search, so this item's mandatory field is not
        # owed on the wire. The existing "[NOTE] re-routes X -> Y (discriminator)" line below is the
        # correct verdict for that case and already covers it.
        # Net effect of the guard, measured across all 20: 31 findings -> the re-route class removed.
        $reRouted = ($baseKey -and $fired -ne $baseKey)
        $mandDropped = @()
        if (-not $reRouted) {
            foreach ($mr in $mandResolved) {
                $anyIn = $false
                foreach ($r in $mr.Refs) { if ($poolC -contains (Canon $r)) { $anyIn = $true; break } }
                if (-not $anyIn) { $mandDropped += $mr.Tok }
            }
            $script:mandChecked += $mandResolved.Count
        }
        if ($mandDropped.Count) {
            if (Test-Accepted $it.Query $mandDropped) {
                Emit "  [NOTE] $label -> fires $fired; MANDATORY $($mandDropped -join ', ') not transmitted (accepted)" 'Yellow'; $notes++
            } else {
                Emit "  [FAIL] $label -> fires $fired but devdoc-MANDATORY $($mandDropped -join ', ') are in NO matching combo's set[]/any[] -- the officer cannot perform this search" 'Red'
                Emit "         wired elsewhere in this query, just not on the combo that fires here -- audit_devdoc_combinations (2p) is satisfied by that and cannot see this" 'DarkGray'
                $fails++
            }
            continue
        }

        $dropped = @()
        for ($i = 0; $i -lt $k; $i++) {
            if ($mask -band [Math]::Pow(2,$i)) {
                $anyIn = $false
                foreach ($r in $optResolved[$i].Refs) { if ($poolC -contains (Canon $r)) { $anyIn = $true; break } }
                if (-not $anyIn) { $dropped += $optResolved[$i].Tok }
            }
        }
        if ($dropped.Count) {
            if (Test-Accepted $it.Query $dropped) {
                Emit "  [NOTE] $label -> fires $fired; optional(s) $($dropped -join ', ') not transmitted (accepted)" 'Yellow'; $notes++
            } else {
                Emit "  [FAIL] $label -> fires $fired but optional(s) $($dropped -join ', ') are in NO matching combo's set[]/any[] -- silently not transmitted" 'Red'
                $fails++
            }
            continue
        }
        if ($mask -ne 0 -and $baseKey -and $fired -ne $baseKey) {
            Emit "  [NOTE] $label -> re-routes $baseKey -> $fired (discriminator; confirm intended)" 'Yellow'
            $notes++
            continue
        }
        if ($Verbose2) { Emit "  [ok]   $label -> $fired" 'DarkGray' }
    }
}

Emit "" $null
Emit "----------------------------------------------------------------" 'Cyan'
Emit "  fills evaluated: $combos   (devdoc items: $($items.Count), skipped-unwired: $skipped)" $null
Emit "  mandatory-field transmission checks: $script:mandChecked   (0 here means this run proved NOTHING about that class)" $(if ($script:mandChecked -eq 0) { "Yellow" } else { $null })
Emit "  RESULT: $fails FAIL / $notes NOTE" $(if ($fails) { 'Red' } else { 'Green' })
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
exit $(if ($fails) { 1 } else { 0 })
