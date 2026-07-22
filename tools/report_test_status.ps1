# ─────────────────────────────────────────────────────────────────────────────
#  report_test_status.ps1 -- portfolio live-test status from ACTUAL log data
#
#  Answers "which providers/entities are live-tested at their CURRENT version,
#  and did they PASS" by reading the RESULT: lines of the real test-log files
#  under logs/<Entity>/<PROVIDER>_v<version>_*.txt. It DELIBERATELY does NOT read
#  logs/.test_state.json -- that file's `status` field (open/blocked) is
#  block-lock bookkeeping, drifts out of sync, and says NOTHING about whether a
#  test actually ran. Ground truth = the log files themselves.
#
#  Version per provider is taken from the active root JSON filename
#  (<PROVIDER>_v<X.Y>.json) via the shared resolver, falling back to
#  logs/.test_version. Legacy _MC/_BASE providers with no logs/ package are
#  reported as "not on live-test track".
#
#  Usage:
#    tools/report_test_status.ps1                 # whole portfolio
#    tools/report_test_status.ps1 -Provider FL_FCIC
#    tools/report_test_status.ps1 -OutFile status.txt
# ─────────────────────────────────────────────────────────────────────────────
[CmdletBinding()]
param(
    [string]$Provider,
    [string]$ProvidersDir = (Join-Path $PSScriptRoot "..\providers"),
    [string]$OutFile
)

. (Join-Path $PSScriptRoot "_resolve_provider_json.ps1")

$Entities = @('Vehicle','Person','Firearm','Article','Boat')
$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s){ $lines.Add($s) | Out-Null }

$provDirs = Get-ChildItem $ProvidersDir -Directory -ErrorAction Stop |
    Where-Object { -not $Provider -or $_.Name -eq $Provider } | Sort-Object Name

Emit "PORTFOLIO LIVE-TEST STATUS  (source: actual log RESULT lines, NOT .test_state.json)"
Emit ("=" * 78)

$summary = New-Object System.Collections.Generic.List[object]

foreach ($pd in $provDirs) {
    $name = $pd.Name
    $rootJson = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $name
    $logsDir = Join-Path $pd.FullName "logs"

    # Resolve current version: root JSON filename _v(X.Y), else logs/.test_version
    $ver = $null
    if ($rootJson -and ([IO.Path]::GetFileName($rootJson)) -match '_v([\d.]+)\.json$') { $ver = $Matches[1] }
    if (-not $ver) {
        $tv = Join-Path $logsDir ".test_version"
        if (Test-Path $tv) { $ver = (Get-Content $tv -Raw).Trim() }
    }

    if (-not (Test-Path $logsDir) -or -not $ver) {
        Emit ""
        Emit ("{0,-22} v{1,-6} NOT ON LIVE-TEST TRACK (no logs package / legacy build)" -f $name, ($ver ?? '?'))
        $summary.Add([pscustomobject]@{ Provider=$name; Version=$ver; State='NOT-TRACKED' })
        continue
    }

    Emit ""
    Emit ("{0,-22} current v{1}" -f $name, $ver)

    $provPass=0; $provFail=0; $provPend=0; $provUnk=0; $entitiesTested=0; $entitiesMissing=0
    foreach ($e in $Entities) {
        $eDir = Join-Path $logsDir $e
        $files = @()
        if (Test-Path $eDir) {
            $files = @(Get-ChildItem $eDir -File -Filter "${name}_v${ver}_*.txt" -ErrorAction SilentlyContinue)
        }
        if ($files.Count -eq 0) {
            Emit ("    {0,-9} 0 logs @ v{1}   <-- NOT TESTED at current version" -f $e, $ver)
            $entitiesMissing++
            continue
        }
        $p=0;$f=0;$pend=0;$u=0
        foreach ($file in $files) {
            $txt = Get-Content $file.FullName -Raw
            if     ($txt -match '(?im)^\s*RESULT:\s*.*FAIL')    { $f++ }
            elseif ($txt -match '(?im)^\s*RESULT:\s*.*PENDING') { $pend++ }
            elseif ($txt -match '(?im)^\s*RESULT:\s*.*PASS')    { $p++ }
            else   { $u++ }
        }
        $entitiesTested++
        $provPass+=$p; $provFail+=$f; $provPend+=$pend; $provUnk+=$u
        $flag = if ($f -gt 0) { '  <-- FAIL' } elseif ($pend -gt 0 -or $u -gt 0) { '  <-- incomplete' } else { '' }
        Emit ("    {0,-9} {1,3} logs -> PASS={2} FAIL={3} PENDING={4} UNKNOWN={5}{6}" -f $e,$files.Count,$p,$f,$pend,$u,$flag)
    }

    $state = if ($provFail -gt 0) { 'HAS-FAIL' }
             elseif ($entitiesMissing -eq $Entities.Count) { 'NEVER-TESTED' }
             elseif ($entitiesMissing -gt 0 -or $provPend -gt 0 -or $provUnk -gt 0) { 'PARTIAL' }
             else { 'ALL-PASS' }
    Emit ("    => {0}: {1}/{2} entities tested, PASS={3} FAIL={4} PENDING={5} UNKNOWN={6}" -f `
          $state, $entitiesTested, $Entities.Count, $provPass, $provFail, $provPend, $provUnk)
    $summary.Add([pscustomobject]@{ Provider=$name; Version=$ver; State=$state })
}

Emit ""
Emit ("=" * 78)
Emit "SUMMARY"
foreach ($grp in ($summary | Group-Object State | Sort-Object Name)) {
    Emit ("  {0,-13} {1}" -f $grp.Name, (($grp.Group | ForEach-Object { "$($_.Provider) v$($_.Version ?? '?')" }) -join ', '))
}

$out = $lines -join "`n"
Write-Output $out
if ($OutFile) { $out | Out-File -FilePath $OutFile -Encoding utf8; Write-Output "`n(written to $OutFile)" }
