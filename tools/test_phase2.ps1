<#
  test_phase2.ps1 -- PHASE 2: TEST. Pre-flight before a sweep, then validate after each ingest.

  Rob 2026-07-31, after having to force the spec-plan check himself: "this gap I had to force you to
  close needs to be wired in when I say test."

  So the spec-plan-vs-JSON-plan comparison is STEP 1 here and it BLOCKS. It is not advisory and it is
  not something anyone has to remember. The reason it matters:

    emit_test_plan.ps1       derives tests from the BUILT JSON -> a MIRROR. No combo, no test, no
                             failure. This is what audit_log_content (6c) validates against.
    emit_test_plan_spec.ps1  derives tests from DEVDOC + METADATA -> an INDEPENDENT statement of what
                             the provider is SUPPOSED to do.

  The DELTA between them is the whole point. A JSON plan that is LARGER than the spec plan is not
  reassuring -- it usually means the spec parser could not read the devdoc, so the independent check
  silently covers nothing. That is exactly what happened on NJ_NJCJIS: the JSON plan had 35 tests
  across five entities while the spec plan had 7, all Vehicle, because NJ's devdoc uses a MULTI-LINE
  "Possible Combinations" layout the parser only handles INLINE. NJ's enforce 2p read [PASS] over
  nine unparsed blocks. Nobody would have known if Rob had not asked.

  RULES THIS ENCODES:
    * spec plan must cover EVERY entity the JSON plan covers -- a missing entity means the devdoc for
      it was not parsed, and 2p/2q PASS on that provider is UNPROVEN, not clean.
    * a sweep may still proceed on the JSON plan (that is what validated TX's 89 and NY's 64), but the
      shortfall is REPORTED, never silent.

  Usage:
    .\test_phase2.ps1 -Provider NJ_NJCJIS              # pre-flight before sweeping
    .\test_phase2.ps1 -Provider NJ_NJCJIS -PostIngest  # after a capture batch is ingested
#>

param(
    [Parameter(Mandatory=$true)][string]$Provider,
    [switch]$PostIngest,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')

$lines = @(); $block = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; Write-Host $s -ForegroundColor $c }
function Run-Tool([string]$n, [string[]]$a) {
    $p = Join-Path $toolDir $n
    if (-not (Test-Path $p)) { return "TOOL MISSING: $n" }
    return (& powershell -ExecutionPolicy Bypass -File $p @a 2>&1 | Out-String)
}

$provDir  = Join-Path $repoRoot "providers\$Provider"
$jsonPath = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $jsonPath) { Write-Host "  [FAIL] no active JSON for $Provider" -ForegroundColor Red; exit 1 }
$ver = ''
$m = [regex]::Match((Split-Path $jsonPath -Leaf), '_v([0-9]+\.[0-9]+)\.json$'); if ($m.Success) { $ver = $m.Groups[1].Value }

Out-Line ''
Out-Line ('=' * 84)
Out-Line "  PHASE 2 -- TEST.  $Provider v$ver"
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Out-Line ('=' * 84)

# ── 1. SPEC PLAN vs JSON PLAN -- the check Rob had to force. BLOCKS. ──────────────────
Out-Line ''
Out-Line '  [1] SPEC-vs-JSON plan coverage  (independent statement vs JSON mirror)' 'Cyan'
Run-Tool 'emit_test_plan_spec.ps1' @('-Provider', $Provider) | Out-Null
$spF = @(Get-ChildItem (Join-Path $provDir 'logs') -Filter "*TEST_PLAN_SPEC_v$ver.json" -File -ErrorAction SilentlyContinue) | Select-Object -First 1
$jpF = @(Get-ChildItem (Join-Path $provDir 'logs') -Filter "${Provider}_TEST_PLAN_v$ver.json" -File -ErrorAction SilentlyContinue) | Select-Object -First 1
if (-not $jpF) { Out-Line '      [FAIL] no JSON-derived TEST_PLAN -- the sweep has nothing to validate against' 'Red'; $block += 'no JSON test plan' }
else {
    $jt = @((Get-Content $jpF.FullName -Raw | ConvertFrom-Json).tests)
    $jEnt = @($jt | ForEach-Object { $_.entity } | Sort-Object -Unique)
    if (-not $spF) {
        Out-Line "      [FAIL] no SPEC-derived plan produced -- the independent check covers NOTHING" 'Red'
        $block += 'spec plan absent: devdoc could not be parsed at all'
    } else {
        $st = @((Get-Content $spF.FullName -Raw | ConvertFrom-Json).tests)
        $sEnt = @($st | ForEach-Object { $_.entity } | Sort-Object -Unique)
        $missEnt = @($jEnt | Where-Object { $sEnt -notcontains $_ })
        Out-Line ("      JSON plan: {0} tests / {1} entities   SPEC plan: {2} tests / {3} entities" -f $jt.Count,$jEnt.Count,$st.Count,$sEnt.Count)
        if ($missEnt.Count) {
            Out-Line "      [FAIL] SPEC plan covers NO tests for: $($missEnt -join ', ')" 'Red'
            Out-Line "             The devdoc for those entities was NOT PARSED, so enforce 2p/2q PASS on this" 'Yellow'
            Out-Line "             provider is UNPROVEN for them -- not clean. NJ_NJCJIS is the known case: its" 'Yellow'
            Out-Line "             devdoc uses a MULTI-LINE 'Possible Combinations' layout the parser reads only" 'Yellow'
            Out-Line "             INLINE, so 9 of 11 blocks were invisible. See ENGINEERING_STANDARD." 'Yellow'
            $block += "spec plan misses entities: $($missEnt -join ',') -- 2p/2q unproven there"
        } else { Out-Line '      [PASS] spec plan covers every entity the JSON plan does' 'Green' }
    }
}

# ── 2. package alignment + plan health ───────────────────────────────────────────────
Out-Line ''
Out-Line '  [2] package alignment + plan health' 'Cyan'
$tv = (Get-Content (Join-Path $provDir 'logs\.test_version') -ErrorAction SilentlyContinue)
Out-Line ("      .test_version={0}  activeJSON=v{1}  {2}" -f $tv,$ver,$(if ("$tv" -eq $ver) { 'aligned' } else { 'MISALIGNED' })) $(if ("$tv" -eq $ver) { 'Green' } else { 'Red' })
if ("$tv" -ne $ver) { $block += "test package v$tv != JSON v$ver -- run reset_test_package" }
if ($jpF) {
    $jt2 = @((Get-Content $jpF.FullName -Raw | ConvertFrom-Json).tests)
    $bad = @($jt2 | Where-Object { "$($_.expectedKeyRef)" -match 'NO-FIRE|UNREACHABLE' })
    Out-Line ("      {0} plan tests, {1} that cannot fire" -f $jt2.Count,$bad.Count) $(if ($bad.Count) { 'Red' } else { 'Green' })
    if ($bad.Count) { $block += "$($bad.Count) plan test(s) cannot fire -- a blank result would be ambiguous" }
}

# ── 3. environment (only matters pre-sweep) ──────────────────────────────────────────
if (-not $PostIngest) {
    Out-Line ''
    Out-Line '  [3] environment' 'Cyan'
    $dl = @(Get-ChildItem "$env:USERPROFILE\Downloads" -Filter 'usx_captured*' -File -ErrorAction SilentlyContinue)
    Out-Line ("      stranded captures: {0}" -f $dl.Count) $(if ($dl.Count) { 'Yellow' } else { 'Green' })
    foreach ($f in $dl) { Out-Line "        $($f.Name) ($($f.Length)b) -- inspect before ingesting; a capture from a superseded version must be DISCARDED" 'Yellow' }
    $self = @($PID, (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId)
    $w = @(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'watch_captures\.ps1' -and $self -notcontains $_.ProcessId })
    Out-Line ("      stray watchers: {0}{1}" -f $w.Count,$(if ($w.Count) { ' -- CONCURRENT WATCHERS DEADLOCK, kill first' } else { '' })) $(if ($w.Count) { 'Red' } else { 'Green' })
    if ($w.Count) { $block += 'stray watch_captures process -- kill before ingesting' }
}

# ── 4. the FOUR log gates (post-ingest) ──────────────────────────────────────────────
if ($PostIngest) {
    Out-Line ''
    Out-Line '  [4] the FOUR log gates -- two is not enough (FL and TX both passed 6c+6d while' 'Cyan'
    Out-Line '      carrying mis-attributed logs and uncaptured plan tests)' 'Cyan'
    $g1 = Run-Tool 'audit_log_content.ps1'  @('-Provider', $Provider)
    $g2 = Run-Tool 'audit_log_metadata.ps1' @('-Provider', $Provider)
    $g3 = Run-Tool 'audit_log_combo_attribution.ps1' @('-Path', $jsonPath)
    foreach ($p in @(@('6c log-content',$g1), @('6d log-metadata',$g2), @('2i attribution',$g3))) {
        $ok = $p[1] -notmatch '\bFAIL\b'
        $sum = @($p[1] -split "`n" | Where-Object { $_ -match 'PASS:|FAIL:|PASS\]|FAIL\]' } | Select-Object -Last 1)
        Out-Line ("      {0,-18} {1}" -f $p[0], $(if ($sum) { $sum[0].Trim() } else { 'no verdict line' })) $(if ($ok) { 'Green' } else { 'Red' })
        if (-not $ok) { $block += "$($p[0]) FAILED" }
    }
    $ts = Run-Tool 'report_test_status.ps1' @('-Provider', $Provider)
    $v = @($ts -split "`n" | Where-Object { $_ -match '=>' } | Select-Object -First 1)
    Out-Line ("      plan completeness  {0}" -f $(if ($v) { $v[0].Trim() } else { '?' })) $(if ("$v" -match 'ALL-PASS') { 'Green' } else { 'Yellow' })
    if ("$v" -match 'PARTIAL') { $block += 'PARTIAL -- plan tests still owed; ALL-PASS requires zero owed' }
}

Out-Line ''
Out-Line ('-' * 84)
if ($block.Count) {
    Out-Line "  PHASE 2 BLOCKED -- $($block.Count) item(s):" 'Red'
    $i=0; foreach ($b in $block) { $i++; Out-Line "    $i. $b" 'Yellow' }
} else {
    Out-Line $(if ($PostIngest) { '  PHASE 2 VALIDATED -- all four log gates green, plan complete.' } else { '  PHASE 2 PRE-FLIGHT CLEAR -- sweep away.' }) 'Green'
}
Out-Line ('-' * 84)
if ($OutFile) { $lines | Out-File -FilePath $OutFile -Encoding utf8 }
exit 0
