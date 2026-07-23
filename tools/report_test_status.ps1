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
    [string]$ProvidersDir,
    [string]$OutFile
)

if (-not $ProvidersDir) { $ProvidersDir = Join-Path $PSScriptRoot "..\providers" }
. (Join-Path $PSScriptRoot "_test_status_lib.ps1")   # shared classifier (single source of truth)

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
    $ts   = Get-ProviderTestState -ProvDir $pd.FullName -Name $name
    $ver  = $ts.Version

    if ($ts.State -eq 'NOT-TRACKED') {
        Emit ""
        $verShow = if ($ver) { $ver } else { '?' }
        Emit ("{0,-22} v{1,-6} NOT ON LIVE-TEST TRACK (no logs package / legacy build)" -f $name, $verShow)
        $summary.Add([pscustomobject]@{ Provider=$name; Version=$ver; State='NOT-TRACKED' })
        continue
    }

    Emit ""
    Emit ("{0,-22} current v{1}" -f $name, $ver)

    foreach ($e in $Entities) {
        $pe = $ts.PerEntity[$e]
        if ($pe.Count -eq 0) {
            Emit ("    {0,-9} 0 logs @ v{1}   <-- NOT TESTED at current version" -f $e, $ver)
            continue
        }
        $flag = if ($pe.Fail -gt 0) { '  <-- FAIL' } elseif ($pe.Pend -gt 0 -or $pe.Unk -gt 0) { '  <-- incomplete' } else { '' }
        Emit ("    {0,-9} {1,3} logs -> PASS={2} FAIL={3} PENDING={4} UNKNOWN={5}{6}" -f $e,$pe.Count,$pe.Pass,$pe.Fail,$pe.Pend,$pe.Unk,$flag)
    }

    Emit ("    => {0}: {1}/{2} entities tested, PASS={3} FAIL={4} PENDING={5} UNKNOWN={6}" -f `
          $ts.State, $ts.EntitiesTested, $Entities.Count, $ts.Pass, $ts.Fail, $ts.Pending, $ts.Unknown)
    $summary.Add([pscustomobject]@{ Provider=$name; Version=$ver; State=$ts.State })
}

Emit ""
Emit ("=" * 78)
Emit "SUMMARY"
foreach ($grp in ($summary | Group-Object State | Sort-Object Name)) {
    Emit ("  {0,-13} {1}" -f $grp.Name, (($grp.Group | ForEach-Object { $vv = if ($_.Version) { $_.Version } else { '?' }; "$($_.Provider) v$vv" }) -join ', '))
}

$out = $lines -join "`n"
Write-Output $out
if ($OutFile) { $out | Out-File -FilePath $OutFile -Encoding utf8; Write-Output "`n(written to $OutFile)" }
