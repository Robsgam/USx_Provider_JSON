# ===========================================================================
#  probe_pull_verdict.ps1 -- LAW 2 FOR THE CONFIG-PULL VERDICT
#
#  WHAT IT ANSWERS: does the panel actually REFUSE to show success when a
#  config pull produced nothing?
#
#  WHY IT EXISTS. Until 2026-09-16 both pull buttons coloured themselves
#  `o.configsFailed ? red : green`, and `configsFailed` incremented ONLY when
#  the downloader threw SYNCHRONOUSLY -- which happens in exactly one case,
#  `__usxLib` absent, i.e. the extension was never loaded at all. Meanwhile
#  `onFull` (where both counters live) is invoked ONLY for a tenant that
#  actually yielded a config blob, so a tenant that produced NOTHING --
#  NO-SAFE-CONTROL / CLICKED-BUT-NO-JSON / ERROR -- moved neither counter.
#
#  Net effect: a sweep of N tenants where every single one failed to export
#  rendered
#        "OK 0 config(s) saved, 0 failed"     IN GREEN, WITH A TICK
#  and the probe's own `saveFailed > 0` warning never fired. That is
#  ENGINEERING_STANDARD 4.3 exactly -- "found nothing" and "never looked"
#  printing the same line -- except the line claimed success.
#
#  !! IT TESTS THE SHIPPED SOURCE, NOT A COPY. The three functions are
#  EXTRACTED from automation/extension/ui.js by name and evaluated as-is. A
#  re-implementation here would pass forever while ui.js rotted, which is the
#  failure this repo has already paid for more than once. If the extraction
#  finds nothing it FAILS rather than reporting a vacuous pass.
#
#  !! THE CONTROL RUNS EVERY TIME. Case GREEN-CLEAN must come back GREEN. A
#  verdict function that returns red unconditionally would "catch" every bad
#  case and be useless; without a positive control this probe could not tell
#  the difference.
#
#  Engine: headless Edge/Chrome, the same mechanism audit_extension_syntax.ps1
#  uses (ENGINEERING_STANDARD 4.4 -- do not re-implement an existing harness).
# ===========================================================================
[CmdletBinding()]
param([string]$OutFile, [switch]$Quiet)

$ErrorActionPreference = 'Stop'
# TWO levels up: this probe lives in tools\_probes\, not tools\.
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$uiJs = Join-Path $repo 'automation\extension\ui.js'

$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s) { $lines.Add($s) | Out-Null; if (-not $Quiet) { Write-Host $s } }
function Done([int]$code) {
    if ($OutFile) {
        [System.IO.File]::WriteAllText($OutFile, (($lines -join "`r`n") + "`r`n"),
            (New-Object System.Text.UTF8Encoding($false)))
    }
    exit $code
}

Emit '===================================================================================='
Emit '  CONFIG-PULL VERDICT -- can the panel report a failed pull as a failure?'
Emit '===================================================================================='

if (-not (Test-Path $uiJs)) { Emit "  [FAIL] ui.js not found at $uiJs"; Done 1 }
$src = [System.IO.File]::ReadAllText($uiJs)

# Pull the three functions out of ui.js by name. Brace-counting from the signature, because the
# file is one big IIFE and there is no module boundary to import across.
function Get-JsFunction([string]$text, [string]$name) {
    $sig = 'function ' + $name + '('
    $i = $text.IndexOf($sig)
    if ($i -lt 0) { return $null }
    $b = $text.IndexOf('{', $i)
    if ($b -lt 0) { return $null }
    $depth = 0
    for ($j = $b; $j -lt $text.Length; $j++) {
        $c = $text[$j]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { return $text.Substring($i, $j - $i + 1) } }
    }
    return $null
}

$needed = @('pullAccounting', 'pullVerdictColour', 'pullVerdictText')
$extracted = @{}
foreach ($n in $needed) {
    $f = Get-JsFunction $src $n
    if (-not $f) { Emit "  [FAIL] could not extract function '$n' from ui.js -- nothing was tested."; Done 1 }
    $extracted[$n] = $f
    Emit ("  extracted {0} ({1} chars)" -f $n, $f.Length)
}

# Both call sites must actually USE the helpers, or the helpers are dead code and this probe
# proves nothing about what the operator sees. The old inline expression must be GONE.
$callSites = ([regex]::Matches($src, 'pullVerdictColour\(')).Count
if ($callSites -lt 2) {
    Emit ("  [FAIL] pullVerdictColour is called {0} time(s); both pull buttons must use it." -f $callSites)
    Done 1
}
# A `//`-COMMENTED LINE IS NOT A FINDING -- strip comments before looking for the old defect.
# The first run of this probe FAILED on its own explanatory comment in ui.js, which quotes the
# very expression it is checking for. That is the exact trap SESSION_STATE already records, hit
# again here, so it is handled rather than worked around by rewording the comment.
$codeOnly = [regex]::Replace($src, '/\*[\s\S]*?\*/', '')
$codeOnly = (($codeOnly -split "`n") | ForEach-Object { ($_ -replace '^\s*//.*$', '') }) -join "`n"
if ($codeOnly -match 'configsFailed\s*\?\s*') {
    Emit '  [FAIL] ui.js still colours a pull from `configsFailed ? ...` -- the defect is back.'
    Done 1
}
Emit ("  call sites: {0}  |  no residual ``configsFailed ? ...`` colouring in CODE" -f $callSites)

$browser = $null
foreach ($c in @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")) {
    if ($c -and (Test-Path $c)) { $browser = $c; break }
}
if (-not $browser) { Emit '  [FAIL] no Edge/Chrome found -- this probe did NOT run. That is not a pass.'; Done 1 }

# ---- the cases -------------------------------------------------------------------------------
# `want` is the REQUIRED colour: f77 red / fa0 amber / 7c7 green.
$cases = @'
var CASES = [
  // THE DEFECT ITSELF: 10 tenants attempted, every one produced nothing. Old code: GREEN TICK.
  { name: 'ZERO-PULLED-ALL-FAILED', want: '#f77', o: {
      configsAttempted: 10, configsHandedOff: 0, configsNoBlob: 10, configsSaveThrew: 0,
      configsSaveErrors: 0, configsSaved: 0, configsFailed: 10,
      results: mk(10, 'CLICKED-BUT-NO-JSON') } },

  // Same shape, reached via ERROR rather than a silent no-JSON.
  { name: 'ZERO-PULLED-ALL-ERROR', want: '#f77', o: {
      configsAttempted: 4, configsHandedOff: 0, configsNoBlob: 4,
      results: mk(4, 'ERROR') } },

  // OLD PROBE BUILD: neither new counter present. Must still be derived, never read as clean.
  { name: 'ZERO-PULLED-LEGACY-FIELDS-ONLY', want: '#f77', o: {
      configsSaved: 0, configsFailed: 0, results: mk(6, 'NO-SAFE-CONTROL') } },

  // PARTIAL: some landed, some yielded nothing. Not a success, not a total failure.
  { name: 'PARTIAL-SOME-NO-BLOB', want: '#fa0', o: {
      configsAttempted: 10, configsHandedOff: 7, configsNoBlob: 3,
      results: mk(7, 'VERSION-READ').concat(mk(3, 'CLICKED-BUT-NO-JSON')) } },

  // PARTIAL via a save error on an otherwise complete run.
  { name: 'PARTIAL-SAVE-ERROR', want: '#fa0', o: {
      configsAttempted: 5, configsHandedOff: 5, configsNoBlob: 0, configsSaveErrors: 1,
      results: mk(5, 'VERSION-READ') } },

  // THE POSITIVE CONTROL. Without this, a function that always returns red would "pass".
  { name: 'GREEN-CLEAN', want: '#7c7', o: {
      configsAttempted: 8, configsHandedOff: 8, configsNoBlob: 0, configsSaveThrew: 0,
      configsSaveErrors: 0, results: mk(8, 'VERSION-READ') } },

  // Exported but no version string is still a PULLED config -- it must not count as no-blob.
  { name: 'GREEN-EXPORTED-NO-VERSION', want: '#7c7', o: {
      configsAttempted: 3, configsHandedOff: 3, configsNoBlob: 0,
      results: mk(3, 'EXPORTED-BUT-NO-VERSION-STRING') } },

  // Nothing was requested: no tenants, no claim either way. Must not be red.
  { name: 'GREEN-EMPTY-REQUEST', want: '#7c7', o: {
      configsAttempted: 0, configsHandedOff: 0, configsNoBlob: 0, results: [] } }
];
function mk(n, verdict) { var a = []; for (var i = 0; i < n; i++) { a.push({ verdict: verdict }); } return a; }
'@

# Sweeps abandoned siblings first; the `finally` below is pre-empted by a kill.
. "$repo\tools\_temp_scratch.ps1"
$work = New-UsxScratch 'usx_pullverdict_' -Quiet:$Quiet
try {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html><title>PENDING</title><body><pre id="out"></pre><script>')
    foreach ($n in $needed) { [void]$sb.AppendLine($extracted[$n]) }
    [void]$sb.AppendLine($cases)
    [void]$sb.AppendLine(@'
var res = [];
for (var i = 0; i < CASES.length; i++) {
  var c = CASES[i], col, txt;
  try { col = pullVerdictColour(c.o); txt = pullVerdictText(c.o, 0, 0, 0); }
  catch (e) { res.push('THREW|' + c.name + '|' + c.want + '||' + (e && e.message ? e.message : String(e))); continue; }
  res.push((col === c.want ? 'PASS' : 'FAIL') + '|' + c.name + '|' + c.want + '|' + col + '|' + txt);
}
document.getElementById('out').textContent = 'RESULTS_BEGIN\n' + res.join('\n') + '\nRESULTS_END';
document.title = 'DONE';
'@)
    [void]$sb.AppendLine('</script></body>')
    $html = Join-Path $work 'check.html'
    [System.IO.File]::WriteAllText($html, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

    # Start-Process with a REDIRECTED FILE, never pipeline capture: Edge detaches when spawned
    # from powershell.exe and `& $browser` returns zero characters. Stderr is redirected too --
    # Edge always writes noise there, and an un-redirected stream turns into a terminating error
    # in any orchestrator that captures with `*>&1` under $ErrorActionPreference='Stop'.
    $stdout = Join-Path $work 'dom.txt'
    $stderr = Join-Path $work 'err.txt'
    $bargs = @('--headless=new', '--disable-gpu', '--no-sandbox', '--virtual-time-budget=8000',
               ('--user-data-dir=' + (Join-Path $work 'ud')), '--dump-dom',
               ('file:///' + $html.Replace([char]92, [char]47)))
    Start-Process -FilePath $browser -ArgumentList $bargs -Wait -NoNewWindow `
                  -RedirectStandardOutput $stdout -RedirectStandardError $stderr | Out-Null

    if (-not (Test-Path $stdout)) { Emit '  [FAIL] the engine wrote no output -- probe did not run.'; Done 1 }
    $dom = [System.IO.File]::ReadAllText($stdout)
    if ($dom -notmatch 'RESULTS_BEGIN') { Emit '  [FAIL] no results block -- probe did not run.'; Done 1 }
    $body = (($dom -split 'RESULTS_BEGIN')[1] -split 'RESULTS_END')[0]
    $rows = @($body -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^(PASS|FAIL|THREW)\|' })

    if ($rows.Count -eq 0) { Emit '  [FAIL] 0 cases evaluated -- not a pass.'; Done 1 }

    Emit ''
    Emit ('  {0,-32} {1,-7} {2,-7} {3}' -f 'case', 'want', 'got', 'rendered text')
    $bad = 0
    foreach ($r in $rows) {
        $p = $r -split '\|', 5
        if ($p[0] -ne 'PASS') { $bad++ }
        $mark = if ($p[0] -eq 'PASS') { ' ' } else { '!' }
        Emit ('{0} {1,-32} {2,-7} {3,-7} {4}' -f $mark, $p[1], $p[2], $p[3], $p[4])
    }

    Emit ''
    Emit ('  {0} case(s) evaluated / {1} wrong' -f $rows.Count, $bad)
    if ($bad -gt 0) {
        Emit '  [FAIL] the pull verdict does not classify every case correctly.'
        Done 1
    }
    # Guard the guard: if the positive control were missing, an always-red function would pass.
    # ⚠️ `if ($rows -notmatch '...')` is WRONG and was the first version of this line. On an ARRAY
    # PowerShell's -match/-notmatch FILTER rather than test, so it returned the 7 non-matching rows
    # -- a non-empty array, i.e. TRUTHY -- and the guard fired on a run where the control had
    # passed. It must be a count of the rows that DO match, and it must require PASS not merely
    # presence: a GREEN-CLEAN row that FAILED would still satisfy "the control ran".
    $ctl = @($rows | Where-Object { $_ -like 'PASS|GREEN-CLEAN|*' })
    if ($ctl.Count -ne 1) {
        Emit '  [FAIL] the GREEN-CLEAN positive control did not run and PASS. Without it, a verdict'
        Emit '         function that returned red unconditionally would score 100%.'
        Done 1
    }
    Emit '  [PASS] a pull that produced nothing reads RED, a partial reads AMBER, and a clean'
    Emit '         run still reads GREEN -- proven on the functions shipped in ui.js.'
    Done 0
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
