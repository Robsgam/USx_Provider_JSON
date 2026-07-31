<#
  build_phase1.ps1 -- PHASE 1: BUILD. One command, hands-off, ends in a SHORTCOMINGS report.

  Rob 2026-07-31: "you need to build the entire process around 3 functions -- when I say rebuild or
  build, when I say test, and when I save finalize it. The first step is what needs hardening and it
  needs to be hands off for me."

    PHASE 1  BUILD     <- this script. Metadata + devdoc drive every decision. Ends with a
                          SHORTCOMINGS report and an INTERPRETATION section so the judgement calls
                          are pre-chewed (the FL field-removal and the NJ/TX query-removal calls are
                          the model: the tool lays out the evidence and the option set, Rob rules).
    PHASE 2  TEST      manual render check, tenant log capture + ingest, build-log iteration,
                          third-party testing updates. Not this script.
    PHASE 3  FINALIZE  a store for COMPLETED JSONs. Deliberately unspecified -- we have not been
                          there yet and inventing it now would be guesswork.

  WHAT PHASE 1 MUST PROVE (Rob's list, in his order):
    1. every devdoc combination is accounted for                     -> audit_devdoc_combinations
    2. every OPTIONAL field combination is accounted for             -> audit_devdoc_optionals
    3. queries are PRIORITISED the way the devdoc lists them         -> DEVDOC-ORDER, below (NEW)
    4. shadow queries are identified and CANNOT fire ahead of a
       higher-order / more-required-field combination                -> SHADOW-RANK, below (NEW)
    5. requirement fidelity, reachability, and gate efficacy         -> existing gates
    6. shortcomings reported at the end, with interpretation         -> SHORTCOMINGS section

  CHECKS 3 AND 4 DID NOT EXIST BEFORE THIS. They are the generalisation of the single most expensive
  lesson of 2026-07-29..31: TX shipped with QV/QW subset-shadows ordered ahead of the real
  combinations, which stole fills from them; the fix was ruled by hand three separate times and
  regressed twice because nothing gated the ORDER. A subset combination placed before a superset
  combination is a defect even when both are "built" and every other gate is green.

  Usage:
    .\build_phase1.ps1 -Provider CA_CLETS            # audit only, no build
    .\build_phase1.ps1 -Provider CA_CLETS -Rebuild   # build first, then audit
    .\build_phase1.ps1 -All
#>

param(
    [string]$Provider,
    [switch]$All,
    [switch]$Rebuild,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; Write-Host $s -ForegroundColor $c }

$targets = @()
if ($All) { $targets = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Select-Object -ExpandProperty Name | Sort-Object) }
elseif ($Provider) { $targets = @($Provider) }
else { Write-Host "  Pass -Provider <NAME> or -All" -ForegroundColor Red; exit 1 }

Out-Line ''
Out-Line ('=' * 84)
Out-Line '  PHASE 1 -- BUILD.  metadata + devdoc drive every decision.'
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Out-Line ('=' * 84)

$grandShort = @()

foreach ($pn in $targets) {
    $provDir = Join-Path $repoRoot "providers\$pn"
    if (-not (Test-Path $provDir)) { Out-Line "  [SKIP] $pn -- no such provider" 'Yellow'; continue }

    Out-Line ''
    Out-Line "########## $pn ##########" 'Cyan'
    $short = @()   # this provider's shortcomings

    # ── 0. BUILD (opt-in) ─────────────────────────────────────────────────────────────
    if ($Rebuild) {
        Out-Line '  [0] rebuild via pipeline...' 'DarkGray'
        $po = & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir 'pipeline.ps1') -Provider $pn 2>&1 | Out-String
        if ($po -match 'PIPELINE FAILED') {
            $fl = @($po -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | Select-Object -First 3)
            Out-Line "      [FAIL] pipeline failed" 'Red'
            $fl | ForEach-Object { Out-Line "        $($_.Trim())" 'Red' }
            $short += "PIPELINE FAILED -- build did not complete; everything below is stale"
        } else { Out-Line '      pipeline complete' 'Green' }
    }

    $jsonPath = Get-ProviderRootJson -ProvDir $provDir -Provider $pn
    if (-not $jsonPath) { Out-Line '  [FAIL] no active JSON' 'Red'; continue }
    Out-Line "  json: $(Split-Path $jsonPath -Leaf)"

    # ── helper: run a gate, return its output ─────────────────────────────────────────
    function Run-Tool([string]$name, [string[]]$argl) {
        $p = Join-Path $toolDir $name
        if (-not (Test-Path $p)) { return "TOOL MISSING: $name" }
        return (& powershell -ExecutionPolicy Bypass -File $p @argl 2>&1 | Out-String)
    }

    # ── 1. devdoc combination coverage ────────────────────────────────────────────────
    $o = Run-Tool 'audit_devdoc_combinations.ps1' @('-Path', $jsonPath)
    $n = @($o -split "`n" | Where-Object { $_ -match "\[FAIL\].*$([regex]::Escape($pn))|\[FAIL\] $([regex]::Escape($pn))" })
    $nAll = @($o -split "`n" | Where-Object { $_ -match '\[FAIL\]' -and $_ -match [regex]::Escape($pn) })
    Out-Line ("  [1] devdoc combinations        {0}" -f $(if ($nAll.Count) { "$($nAll.Count) UNBUILT" } else { 'all accounted for' })) $(if ($nAll.Count) { 'Red' } else { 'Green' })
    foreach ($l in ($nAll | Select-Object -First 4)) { Out-Line "        $($l.Trim())" 'Red'; $short += "DEVDOC COMBO UNBUILT: $($l.Trim())" }

    # ── 2. devdoc optionals x routing ─────────────────────────────────────────────────
    $o2 = Run-Tool 'audit_devdoc_optionals.ps1' @('-Path', $jsonPath)
    $f2 = @($o2 -split "`n" | Where-Object { $_ -match '\[FAIL\]' })
    Out-Line ("  [2] devdoc optional subsets    {0}" -f $(if ($f2.Count) { "$($f2.Count) FAIL" } else { 'all route and transmit' })) $(if ($f2.Count) { 'Red' } else { 'Green' })
    foreach ($l in ($f2 | Select-Object -First 4)) { Out-Line "        $($l.Trim())" 'Red'; $short += "OPTIONAL SUBSET: $($l.Trim())" }

    # ── 3. DEVDOC-ORDER + 4. SHADOW-RANK  (NEW -- neither existed before) ─────────────
    # Rob: "queries are prioritised the way they are listed in devdoc" and "shadow queries need to
    # be identified and not allowed to fire for higher order / more required fields".
    # The platform fires the FIRST matching combination, so ORDER IS SEMANTICS. A combination whose
    # set[] is a strict SUBSET of a later one always steals that later one's fills -- which is
    # exactly what TX's QV/QW did, and it cost three hand-rulings and two regressions because no
    # gate looked at order.
    $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $rank = 0; $rankBad = @()
    foreach ($b in $json.bundles) {
        foreach ($c in $b.configurations) {
            if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ("$($c.provider)" -eq 'RMS' -or "$($c.name)" -match '^RMS ') { continue }
            $cms = @($c.combinations)
            for ($i = 0; $i -lt $cms.Count; $i++) {
                $a = $cms[$i]
                $aSet = @($a.requirements.set | ForEach-Object { "$_".ToLower() })
                $aCond = @($a.requirements.conditions).Count
                for ($j = $i + 1; $j -lt $cms.Count; $j++) {
                    $bb = $cms[$j]
                    $bSet = @($bb.requirements.set | ForEach-Object { "$_".ToLower() })
                    if (-not $aSet.Count -or -not $bSet.Count) { continue }
                    # A (earlier) is a STRICT SUBSET of B (later) -> A always matches when B does.
                    $isSubset = $true
                    foreach ($w in $aSet) { if ($bSet -notcontains $w) { $isSubset = $false; break } }
                    if (-not $isSubset -or $aSet.Count -ge $bSet.Count) { continue }
                    # A condition on A can legitimately keep them apart; flag only when A is ungated.
                    if ($aCond -gt 0) { continue }
                    $rankBad += "$($c.name -replace '.*_','')/$($a.keyReference) [pos $($i+1)] set[$($aSet -join ',')] is an UNGATED SUBSET of $($bb.keyReference) [pos $($j+1)] set[$($bSet -join ',')] -- the earlier one steals every fill"
                }
            }
            $rank += $cms.Count
        }
    }
    Out-Line ("  [3] combo priority / order     {0}" -f $(if ($rankBad.Count) { "$($rankBad.Count) SUBSET-AHEAD-OF-SUPERSET" } else { "$rank combos, most-specific-first respected" })) $(if ($rankBad.Count) { 'Red' } else { 'Green' })
    foreach ($l in ($rankBad | Select-Object -First 4)) { Out-Line "        $l" 'Red'; $short += "PRIORITY/SHADOW-RANK: $l" }

    # ── 5. fidelity / reachability / trace ────────────────────────────────────────────
    $o5 = Run-Tool 'audit_requirement_fidelity.ps1' @('-Provider', $pn)
    $m5 = [regex]::Match($o5, 'TOTALS:\s*(\d+) branch.*?/\s*(\d+) UNDER-REQUIRED\s*/\s*(\d+) OVER-PERMITTED')
    if ($m5.Success) {
        $u = [int]$m5.Groups[2].Value; $ov = [int]$m5.Groups[3].Value
        Out-Line ("  [4] requirement fidelity       {0} branches, {1} under / {2} over" -f $m5.Groups[1].Value,$u,$ov) $(if ($u+$ov) { 'Yellow' } else { 'Green' })
        if ($u+$ov) { $short += "FIDELITY: $u UNDER-REQUIRED / $ov OVER-PERMITTED (tools\audit_requirement_fidelity.ps1 -Provider $pn)" }
    }
    $o6 = Run-Tool 'audit_query_trace.ps1' @('-Provider', $pn)
    $m6 = [regex]::Match($o6, 'TOTALS:\s*(\d+) built\s*/\s*(\d+) PREFILL-DEAD.*?/\s*(\d+) SHADOW\s*/\s*(\d+) MISSING')
    if ($m6.Success) {
        $pd = [int]$m6.Groups[2].Value; $sh = [int]$m6.Groups[3].Value; $ms = [int]$m6.Groups[4].Value
        Out-Line ("  [5] query trace                {0} built, {1} prefill-dead, {2} shadow, {3} missing" -f $m6.Groups[1].Value,$pd,$sh,$ms) $(if ($pd) { 'Red' } elseif ($sh+$ms) { 'Yellow' } else { 'Green' })
        if ($pd) { $short += "PREFILL-DEAD x$pd -- our own default hides a real metadata combination (highest severity: officer capability)" }
        if ($sh) { $short += "SHADOW x$sh -- identical set[]; only one can ever fire" }
        if ($ms) { $short += "MISSING x$ms -- adjudicate against the devdoc Basic list" }
    }

    # ── 6. gate efficacy: can the gates fail at all? ──────────────────────────────────
    $o7 = Run-Tool 'audit_gate_efficacy.ps1' @('-Provider', $pn)
    $m7 = [regex]::Match($o7, 'KILLED (\d+) / (\d+)\s+SURVIVED (\d+)')
    if ($m7.Success) {
        $sv = [int]$m7.Groups[3].Value
        Out-Line ("  [6] gate efficacy              {0}/{1} killed, {2} survived" -f $m7.Groups[1].Value,$m7.Groups[2].Value,$sv) $(if ($sv) { 'Yellow' } else { 'Green' })
        if ($sv) { $short += "GATE EFFICACY: $sv mutation(s) SURVIVED -- those gates' PASS proves nothing for that defect class" }
    } else { $short += "GATE EFFICACY: no mutation map for $pn -- its green gates are UNPROVEN" }

    # ── 7. enforce ────────────────────────────────────────────────────────────────────
    $o8 = Run-Tool 'enforce.ps1' @('-Provider', $pn, '-SkipGit')
    $m8 = [regex]::Match($o8, '(ENFORCED|BLOCKED):\s*(\d+) PASS / (\d+) FAIL / (\d+) WARN')
    if ($m8.Success) {
        Out-Line ("  [7] enforce                    {0}: {1} PASS / {2} FAIL / {3} WARN" -f $m8.Groups[1].Value,$m8.Groups[2].Value,$m8.Groups[3].Value,$m8.Groups[4].Value) $(if ($m8.Groups[1].Value -eq 'ENFORCED') { 'Green' } else { 'Red' })
        if ($m8.Groups[1].Value -ne 'ENFORCED') { $short += "ENFORCE BLOCKED: $($m8.Groups[3].Value) FAIL / $($m8.Groups[4].Value) WARN" }
    }

    # ── SHORTCOMINGS + INTERPRETATION ────────────────────────────────────────────────
    Out-Line ''
    if (-not $short.Count) {
        Out-Line "  PHASE 1 CLEAN -- $pn has no shortcomings. Ready for PHASE 2 (TEST)." 'Green'
    } else {
        Out-Line "  SHORTCOMINGS -- $pn  ($($short.Count))" 'Red'
        $k = 0; foreach ($s in $short) { $k++; Out-Line "    $k. $s" 'Yellow' }
        Out-Line ''
        Out-Line '  HOW TO INTERPRET THESE -- the decision tree, in severity order:' 'Cyan'
        Out-Line '    PREFILL-DEAD is the worst: an officer cannot reach a real query path. But check THREE'
        Out-Line '      things before removing any default -- (a) do we even BUILD that combination, (b) is it'
        Out-Line '      devdoc-Basic, (c) is it subset-shadowed regardless of the prefill. HI looked like 2'
        Out-Line '      prefill-dead and was 2 registered QV shadows; CA looked like 12 and all 12 were already'
        Out-Line '      adjudicated. Removing a mandatory-everywhere prefill (CA purposeCode) breaks CAD.'
        Out-Line '    PRIORITY/SHADOW-RANK: an UNGATED SUBSET ordered before a superset steals every fill.'
        Out-Line '      Fix by ORDER (most-specific first) or by giving the earlier combo a discriminating'
        Out-Line '      existence condition. Never by deleting the superset -- that is what cost TX its two'
        Out-Line '      out-of-state paths at v4.13.'
        Out-Line '    NO COMBO FIRES on a devdoc-legal fill: the officer types a legal combination and NOTHING'
        Out-Line '      is sent. Either build the path, or record why it cannot exist (metadata is field'
        Out-Line '      authority and may require more than the devdoc shows).'
        Out-Line '    OPTIONAL SUBSET dropped: officer input silently discarded. If the devdoc lists the field'
        Out-Line '      as optional, ride it in any[] (never DROP a devdoc optional). If it does not, the field'
        Out-Line '      is an over-send and comes out -- FL v7.14 vs HI M55S went OPPOSITE ways on exactly this'
        Out-Line '      test, so run it per provider.'
        Out-Line '    FIDELITY under/over: fix the JSON when out of spec; register with reasoning when it is a'
        Out-Line '      decision. A registry entry must use a rule name the gate honours, or it is inert.'
        Out-Line '    GATE EFFICACY survivors: that gate cannot fail on that defect class, so its PASS is not'
        Out-Line '      evidence. Fix the gate or the mutation before trusting the green.'
        $grandShort += "$pn : $($short.Count) shortcoming(s)"
    }
}

Out-Line ''
Out-Line ('-' * 84)
if ($grandShort.Count) { Out-Line "  PHASE 1 INCOMPLETE:"; $grandShort | ForEach-Object { Out-Line "    $_" 'Yellow' } }
else { Out-Line '  PHASE 1 CLEAN for every provider audited -- proceed to PHASE 2 (TEST).' 'Green' }
Out-Line ('-' * 84)

if ($OutFile) { $lines | Out-File -FilePath $OutFile -Encoding utf8; Write-Host "  -> $OutFile" -ForegroundColor DarkGray }
exit 0
