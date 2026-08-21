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

# ─────────────────────────────────────────────────────────────────────────────
#  TEST PARK -- a provider with NO TEST EXPECTATION, by operator directive.
#
#  Why this is a MARKER and not prose. TX_TLETS_CCH is a proof of concept: it
#  exists to prove the base<->variant PARALLEL BUILD works, not to be swept
#  (Rob 2026-08-21: "tx cch was a proof of concept and has no need at all yet so
#  it need to be parked in terms of testing expectations. It is really about the
#  parallel build ability"). Recorded only in prose, that directive is guaranteed
#  to be lost: report_sweep_ledger would keep printing "183 TEST(S) STILL OWED",
#  report_import_owed would keep listing an import, and every status report would
#  re-raise it until someone re-explained. The ImageIndicator/MD_METERS line in
#  CLAUDE.md is exactly that failure already in the repo.
#
#  DELIBERATELY DOES NOT CHANGE `State`. Ten tools call Get-ProviderTestState and
#  scope on ALL-PASS / NEVER-TESTED; inventing a sixth state would silently alter
#  every one of them. Parking is ADDITIVE -- `Parked` / `ParkReason` -- and only
#  the tools where it changes the ANSWER consume it.
#
#  Requires a STRUCTURED line, `PARKED: <reason>`, in
#  docs/tracking/TEST_PARKED.txt. An empty or accidental file parks nothing --
#  same discipline as `# BASE-SYNC:` and `POSTED:` (audit_lifecycle stage 5,
#  where `-match "v$ver"` over a whole file was a check that could not fail).
#
#  A park NEVER hides a failure: HAS-FAIL is reported regardless, because a
#  parked provider holding failing logs is a real finding, not a quiet state.
# ─────────────────────────────────────────────────────────────────────────────
function Get-ProviderTestPark {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProvDir)

    $marker = Join-Path $ProvDir "docs\tracking\TEST_PARKED.txt"
    if (-not (Test-Path $marker)) {
        return [pscustomobject]@{ Parked = $false; Reason = $null }
    }
    $raw = Get-Content $marker -Raw
    if ($raw -match '(?m)^\s*PARKED:\s*(\S.*?)\s*$') {
        return [pscustomobject]@{ Parked = $true; Reason = $Matches[1] }
    }
    # File present but no structured line -- announce it rather than park silently.
    Write-Warning "TEST_PARKED.txt present in $ProvDir but has no 'PARKED: <reason>' line -- NOT parked"
    return [pscustomobject]@{ Parked = $false; Reason = $null }
}

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

    $park = Get-ProviderTestPark -ProvDir $ProvDir
    $perEntity = [ordered]@{}
    if (-not (Test-Path $logsDir) -or -not $ver) {
        return [pscustomobject]@{
            Provider=$Name; Version=$ver; State='NOT-TRACKED'
            Pass=0; Fail=0; Pending=0; Unknown=0; EntitiesTested=0; EntitiesMissing=$script:TS_Entities.Count
            PerEntity=$perEntity
            Parked=$park.Parked; ParkReason=$park.Reason
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

    # ── PLAN COVERAGE (added 2026-07-29) ──────────────────────────────────────────
    # Counting logs and their RESULT lines answers "did what we ran pass?", NOT "did we run
    # everything?". Without comparing against the TEST PLAN, a provider reads ALL-PASS while
    # plan tests were never captured -- FL_FCIC reported "ALL-PASS 5/5, PASS=111" with 7 Boat
    # tests missing, and TX_TLETS reported ALL-PASS while QGNCICNumber (the Firearm-by-NCIC
    # BASE combo test) had never been captured at all, hidden behind its own _af_/_any
    # variants. That is the same class as the log-attribution gap: an assertion nothing checks.
    # Owed plan tests now force PARTIAL. enforce PHASE 6 tolerates INCOMPLETE-consistent, so
    # this tells the truth WITHOUT blocking the pipeline on work that is simply still owed.
    $owed = 0
    $planFile = $null
    if (Test-Path $logsDir) {
        $planFile = Get-ChildItem $logsDir -File -Filter "*_TEST_PLAN_v${ver}.json" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
    }
    if ($planFile) {
        $lblFn = Join-Path $PSScriptRoot '_content_match.ps1'
        if (Test-Path $lblFn) { . $lblFn }
        try {
            $plan = Get-Content $planFile.FullName -Raw | ConvertFrom-Json
            foreach ($e in $script:TS_Entities) {
                $wanted = @($plan.tests | Where-Object { "$($_.entity)" -eq $e })
                if ($wanted.Count -eq 0) { continue }
                $eDir2 = Join-Path $logsDir $e
                $have = @()
                if (Test-Path $eDir2) {
                    $have = @(Get-ChildItem $eDir2 -File -Filter "${Name}_v${ver}_*.txt" -ErrorAction SilentlyContinue |
                              ForEach-Object { $_.BaseName -replace "^$([regex]::Escape($Name))_v$([regex]::Escape($ver))_", '' })
                }
                $miss = 0
                foreach ($t in $wanted) {
                    $lbl = if (Get-Command Get-CmPlanLabel -ErrorAction SilentlyContinue) { Get-CmPlanLabel $t } else { "$($t.comboKeyRef)" }
                    if ($have -notcontains $lbl) { $miss++ }
                }
                if ($miss -gt 0) {
                    $owed += $miss
                    if ($perEntity.Contains($e)) { $perEntity[$e].Owed = $miss }
                }
            }
        } catch { $owed = 0 }   # unreadable plan must not corrupt the verdict
    }

    $state = if ($provFail -gt 0) { 'HAS-FAIL' }
             elseif ($entMissing -eq $script:TS_Entities.Count) { 'NEVER-TESTED' }
             elseif ($entMissing -gt 0 -or $provPend -gt 0 -or $provUnk -gt 0 -or $owed -gt 0) { 'PARTIAL' }
             else { 'ALL-PASS' }

    [pscustomobject]@{
        Provider=$Name; Version=$ver; State=$state
        Pass=$provPass; Fail=$provFail; Pending=$provPend; Unknown=$provUnk
        EntitiesTested=$entTested; EntitiesMissing=$entMissing; PerEntity=$perEntity
        OwedPlanTests=$owed
        Parked=$park.Parked; ParkReason=$park.Reason
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
