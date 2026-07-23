# ─────────────────────────────────────────────────────────────────────────────
#  portfolio_status.ps1 -- THE canonical one-screen portfolio status table.
#
#  One command, one fixed-column table. This is the single authoritative view of
#  "where is every provider" -- version, methodology, validator score, and
#  live-test state -- assembled from the real sources (active root JSON filename,
#  newest VALIDATOR_REPORT, and actual log RESULT lines), never hand-typed.
#
#  All classification logic lives in tools/_test_status_lib.ps1 (shared with
#  report_test_status.ps1) so the table view and the narrative view cannot drift.
#
#  Columns:
#    Provider | Ver | Meth | Validator (P/F/W/LIM) | Live-test (state tested/5 (#logs))
#  Footer: totals + git state (branch, ahead-of-main, unpushed, uncommitted).
#
#  Usage:
#    tools/portfolio_status.ps1                 # whole portfolio
#    tools/portfolio_status.ps1 -Provider FL_FCIC
#    tools/portfolio_status.ps1 -OutFile status.txt
# ─────────────────────────────────────────────────────────────────────────────
[CmdletBinding()]
param(
    [string]$Provider,
    [string]$ProvidersDir,
    [string]$OutFile
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $ProvidersDir) { $ProvidersDir = Join-Path $repoRoot "providers" }
. (Join-Path $PSScriptRoot "_test_status_lib.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s){ $lines.Add($s) | Out-Null }

$provDirs = Get-ChildItem $ProvidersDir -Directory -ErrorAction Stop |
    Where-Object { -not $Provider -or $_.Name -eq $Provider } | Sort-Object Name

$rows = New-Object System.Collections.Generic.List[object]
foreach ($pd in $provDirs) {
    $name  = $pd.Name
    $ts    = Get-ProviderTestState      -ProvDir $pd.FullName -Name $name
    $score = Get-ProviderValidatorScore -ProvDir $pd.FullName -Name $name
    $meth  = Get-ProviderMethodology    -ProvDir $pd.FullName -Name $name

    $scoreStr = if ($null -ne $score.Pass) {
        "{0}P/{1}F/{2}W/{3}L" -f $score.Pass, $score.Fail, $score.Warn, $score.Lim
    } else { "(no report)" }

    $totalLogs = $ts.Pass + $ts.Fail + $ts.Pending + $ts.Unknown
    $liveStr = switch ($ts.State) {
        'NOT-TRACKED'  { "not on track" }
        'NEVER-TESTED' { "NEVER 0/5" }
        default        { "{0} {1}/5 ({2})" -f $ts.State, $ts.EntitiesTested, $totalLogs }
    }

    $rows.Add([pscustomobject]@{
        Provider=$name; Ver=("v" + ($(if($ts.Version){$ts.Version}else{'?'}))); Meth=$meth
        Score=$scoreStr; Live=$liveStr
        _fail=$score.Fail; _warn=$score.Warn; _lim=$score.Lim; _state=$ts.State; _logs=$totalLogs
    })
}

$fmt = "{0,-22} {1,-7} {2,-6} {3,-16} {4}"
Emit ("=" * 84)
Emit "  USx PROVIDER PORTFOLIO STATUS"
Emit ("  source: active root JSON + newest VALIDATOR_REPORT + log RESULT lines (log-truth)")
Emit ("=" * 84)
Emit ($fmt -f "Provider","Ver","Meth","Validator","Live-test (state tested/5 (#logs))")
Emit ("-" * 84)
foreach ($r in $rows) { Emit ($fmt -f $r.Provider, $r.Ver, $r.Meth, $r.Score, $r.Live) }
Emit ("-" * 84)

# ---- totals ----
$galv    = @($rows | Where-Object { $_.Meth -eq 'GALV' }).Count
$legacy  = @($rows | Where-Object { $_.Meth -eq 'LEGACY' }).Count
$fails   = @($rows | Where-Object { $_._fail -gt 0 }).Count
$warns   = ($rows | Measure-Object -Property _warn -Sum).Sum
$allpass = @($rows | Where-Object { $_._state -eq 'ALL-PASS' })
$never   = @($rows | Where-Object { $_._state -eq 'NEVER-TESTED' })
$partial = @($rows | Where-Object { $_._state -eq 'PARTIAL' })
$hasfail = @($rows | Where-Object { $_._state -eq 'HAS-FAIL' })
$untrack = @($rows | Where-Object { $_._state -eq 'NOT-TRACKED' })
$liveLogs = ($allpass + $partial | Measure-Object -Property _logs -Sum).Sum

Emit ("  Providers: {0}  ({1} GALV / {2} LEGACY)   Validator FAILs: {3}   total WARNs: {4}" -f `
      $rows.Count, $galv, $legacy, $fails, ([int]$warns))
Emit ("  Live-test: {0} ALL-PASS, {1} PARTIAL, {2} HAS-FAIL, {3} NEVER-TESTED, {4} NOT-TRACKED  ({5} logs)" -f `
      $allpass.Count, $partial.Count, $hasfail.Count, $never.Count, $untrack.Count, ([int]$liveLogs))
if ($allpass.Count) { Emit ("    ALL-PASS:     " + (($allpass | ForEach-Object { "$($_.Provider) $($_.Ver)" }) -join ', ')) }
if ($never.Count)   { Emit ("    NEVER-TESTED: " + (($never   | ForEach-Object { "$($_.Provider) $($_.Ver)" }) -join ', ')) }
if ($untrack.Count) { Emit ("    NOT-TRACKED:  " + (($untrack | ForEach-Object { "$($_.Provider) $($_.Ver)" }) -join ', ')) }

# ---- git footer ----
Push-Location $repoRoot
try {
    $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
    $uncommitted = @(git status --porcelain 2>$null).Count
    $aheadMain = (git rev-list --count main..HEAD 2>$null)
    $unpushed  = (git rev-list --count '@{u}..HEAD' 2>$null)
    if (-not $aheadMain) { $aheadMain = '?' }
    if ($unpushed -eq $null -or $unpushed -eq '') { $unpushed = 'no upstream' }
    Emit ("-" * 84)
    Emit ("  Git: branch '{0}'  |  ahead of main: {1}  |  unpushed to upstream: {2}  |  uncommitted: {3}" -f `
          $branch, $aheadMain, $unpushed, $uncommitted)
} finally { Pop-Location }
Emit ("=" * 84)

$out = $lines -join "`n"
Write-Output $out
if ($OutFile) { $out | Out-File -FilePath $OutFile -Encoding utf8; Write-Output "`n(written to $OutFile)" }
