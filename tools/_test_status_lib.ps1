# ─────────────────────────────────────────────────────────────────────────────
#  _test_status_lib.ps1 -- shared portfolio status primitives (dot-sourced)
#
#  Single source of truth for per-provider status classification. Both
#  report_test_status.ps1 (narrative view) and portfolio_status.ps1 (table view)
#  consume these functions so the two never drift.
#
#  Exports:
#    Get-ProviderTestState -ProvDir <dir> -Name <provider>
#        USx-tenant-test state from ACTUAL log RESULT: lines (NOT .test_state.json).
#        Returns: Version, State (ALL-PASS/PARTIAL/NEVER-TESTED/HAS-FAIL/NOT-TRACKED),
#                 Pass, Fail, Pending, Unknown, EntitiesTested, EntitiesMissing,
#                 PerEntity (ordered hashtable entity -> @{Count,Pass,Fail,Pend,Unk}).
#    Get-ProviderValidatorScore -ProvDir <dir> -Name <provider>
#        Parses the newest VALIDATOR_REPORT_*.txt for RESULTS: -> Pass/Fail/Warn/Lim
#        (or nulls if no report found).
#    Get-ProviderMethodology -ProvDir <dir> -Name <provider>
#        'GALV' (single versioned root JSON) or 'LEGACY' (has _MC/_BASE root sibling).
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Get-Command Get-ProviderRootJson -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot "_resolve_provider_json.ps1")
}

$script:TS_Entities = @('Vehicle','Person','Firearm','Article','Boat')

function Get-ProviderTestState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProvDir, [Parameter(Mandatory)][string]$Name)

    $rootJson = Get-ProviderRootJson -ProvDir $ProvDir -Provider $Name
    $logsDir  = Join-Path $ProvDir "logs"

    $ver = $null
    if ($rootJson -and ([IO.Path]::GetFileName($rootJson)) -match '_v([\d.]+)\.json$') { $ver = $Matches[1] }
    if (-not $ver) {
        $tv = Join-Path $logsDir ".test_version"
        if (Test-Path $tv) { $ver = (Get-Content $tv -Raw).Trim() }
    }
    # Legacy providers carry no version in the filename or logs/ -- read the bundle
    # description ("Provider configuration for <NAME> v<X.Y> ...") from the root JSON.
    if (-not $ver -and $rootJson -and (Test-Path $rootJson)) {
        $raw = Get-Content $rootJson -Raw
        if ($raw -match 'configuration for [^"]*?\bv([\d]+\.[\d]+)') { $ver = $Matches[1] }
    }

    $perEntity = [ordered]@{}
    if (-not (Test-Path $logsDir) -or -not $ver) {
        return [pscustomobject]@{
            Provider=$Name; Version=$ver; State='NOT-TRACKED'
            Pass=0; Fail=0; Pending=0; Unknown=0; EntitiesTested=0; EntitiesMissing=$script:TS_Entities.Count
            PerEntity=$perEntity
        }
    }

    $provPass=0;$provFail=0;$provPend=0;$provUnk=0;$entTested=0;$entMissing=0
    foreach ($e in $script:TS_Entities) {
        $eDir  = Join-Path $logsDir $e
        $files = @()
        if (Test-Path $eDir) {
            $files = @(Get-ChildItem $eDir -File -Filter "${Name}_v${ver}_*.txt" -ErrorAction SilentlyContinue)
        }
        if ($files.Count -eq 0) {
            $perEntity[$e] = @{ Count=0; Pass=0; Fail=0; Pend=0; Unk=0 }
            $entMissing++
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
        $entTested++
        $provPass+=$p; $provFail+=$f; $provPend+=$pend; $provUnk+=$u
        $perEntity[$e] = @{ Count=$files.Count; Pass=$p; Fail=$f; Pend=$pend; Unk=$u }
    }

    $state = if ($provFail -gt 0) { 'HAS-FAIL' }
             elseif ($entMissing -eq $script:TS_Entities.Count) { 'NEVER-TESTED' }
             elseif ($entMissing -gt 0 -or $provPend -gt 0 -or $provUnk -gt 0) { 'PARTIAL' }
             else { 'ALL-PASS' }

    [pscustomobject]@{
        Provider=$Name; Version=$ver; State=$state
        Pass=$provPass; Fail=$provFail; Pending=$provPend; Unknown=$provUnk
        EntitiesTested=$entTested; EntitiesMissing=$entMissing; PerEntity=$perEntity
    }
}

function Get-ProviderValidatorScore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProvDir, [Parameter(Mandatory)][string]$Name)

    $docs = Join-Path $ProvDir "docs"
    $rpt  = $null
    if (Test-Path $docs) {
        $rpt = Get-ChildItem $docs -Recurse -File -Filter "VALIDATOR_REPORT_*.txt" -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $rpt) {
        return [pscustomobject]@{ Pass=$null; Fail=$null; Warn=$null; Lim=$null; Source=$null }
    }
    $txt = Get-Content $rpt.FullName -Raw
    $p=$f=$w=$l=$null
    if ($txt -match 'RESULTS:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL(?:\s*/\s*(\d+)\s*WARN)?(?:\s*/\s*(\d+)\s*LIMITATION)?') {
        $p=[int]$Matches[1]; $f=[int]$Matches[2]
        $w = if ($Matches[3] -ne $null -and $Matches[3] -ne '') { [int]$Matches[3] } else { 0 }
        $l = if ($Matches[4] -ne $null -and $Matches[4] -ne '') { [int]$Matches[4] } else { 0 }
    }
    [pscustomobject]@{ Pass=$p; Fail=$f; Warn=$w; Lim=$l; Source=$rpt.Name }
}

function Get-ProviderMethodology {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProvDir, [Parameter(Mandatory)][string]$Name)
    $hasMC   = Test-Path (Join-Path $ProvDir "${Name}_MC.json")
    $hasBASE = Test-Path (Join-Path $ProvDir "${Name}_BASE.json")
    if ($hasMC -or $hasBASE) { 'LEGACY' } else { 'GALV' }
}
