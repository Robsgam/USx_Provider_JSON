<#
  block_entity.ps1 -- "Block out" a validated entity so a later rebuild for a
  DIFFERENT entity does not wipe its USx Tenant Testing results.

  An entity may be blocked only when every combo marker in its SQVR section(s)
  is [CONFIRMED] (no [PENDING]/[FAILED]) -- unless -Force. Blocking records the
  entity's current structural fingerprint + the global version in
  tests/.test_state.json with status='blocked'. reset_test_package.ps1 then
  PRESERVES it across rebuilds as long as its fingerprint is unchanged; if the
  entity's QIF/QIDM structure drifts, reset re-opens it and enforce.ps1 FAILs
  the stale block.

  Usage:
    .\block_entity.ps1 -Provider HI_HCJDC_OFML -Entity Person
    .\block_entity.ps1 -Provider HI_HCJDC_OFML -Entity Vehicle -Force   # block despite PENDING markers
    .\block_entity.ps1 -Provider HI_HCJDC_OFML -Entity Person -NoCommit
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Entity,
    [switch]$Force,
    [switch]$NoCommit
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$testsDir = Join-Path $provDir "tests"
$docsDir  = Join-Path $provDir "docs"

if (-not (Test-Path $provDir)) { Write-Host "  [ERROR] Provider not found: $Provider" -ForegroundColor Red; exit 1 }

$stateJsonPath = Join-Path $testsDir ".test_state.json"
if (-not (Test-Path $stateJsonPath)) {
    Write-Host "  [ERROR] No tests/.test_state.json -- build the provider first (pipeline runs reset_test_package which seeds it)." -ForegroundColor Red
    exit 1
}

# Locate active JSON for the fingerprint.
$activeJson = Join-Path $provDir "$Provider.json"
if (-not (Test-Path $activeJson)) {
    $alt = Get-ChildItem $provDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^${Provider}_v[\d.]+\.json$" } | Select-Object -First 1
    if (-not $alt) { $alt = Get-ChildItem $provDir -Filter "*_MC.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $alt) { $alt = Get-ChildItem $provDir -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($alt) { $activeJson = $alt.FullName }
}
if (-not (Test-Path $activeJson)) { Write-Host "  [ERROR] No active JSON for $Provider" -ForegroundColor Red; exit 1 }

. "$toolDir\get_entity_fingerprints.ps1"
. "$toolDir\_combo_match.ps1"
. "$toolDir\_test_provenance.ps1"
$fp = Get-EntityFingerprints -Path $activeJson
if (-not $fp.Contains($Entity)) {
    Write-Host "  [ERROR] Entity '$Entity' not found in $Provider. Known: $($fp.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

# ── Gate: all SQVR markers for this entity must be [CONFIRMED] (unless -Force) ──
$sqvrPath = Join-Path $docsDir "${Provider}_SQVR.txt"
$pending = 0; $failed = 0
if (Test-Path $sqvrPath) {
    $curEntity = $null
    foreach ($line in (Get-Content $sqvrPath)) {
        if ($line -match '--\s+([A-Za-z]+)\s+Entity') { $curEntity = $Matches[1] }
        elseif ($line -match '^(RMS BUNDLE|SUMMARY)\s*$') { $curEntity = $null }
        if ($curEntity -eq $Entity) {
            $pending += ([regex]::Matches($line, '\[PENDING\]')).Count
            $failed  += ([regex]::Matches($line, '\[FAILED[^\]]*\]')).Count
        }
    }
}
if (($pending -gt 0 -or $failed -gt 0) -and -not $Force) {
    Write-Host "  [BLOCKED] '$Entity' has $pending [PENDING] + $failed [FAILED] SQVR marker(s) -- validate all combos first, or pass -Force." -ForegroundColor Red
    exit 1
}

# ── Evidence gate: every combo of this entity must have a VALID current-version XML
#    backing log (provenance), and -- at Final tier -- an any[] log per combo with
#    optional fields plus a render and a negative log. This is what makes a "blocked"
#    entity mean "evidenced": a hand-edited SQVR or a stale pre-rebuild log can no
#    longer lock an entity (the NJ v4.7 failure mode). Override with -Force.
$buildVer   = Get-BuildVersionForProvider $provDir
$activeTier = Get-ActiveTier $provDir
$entityFp   = $fp[$Entity]
$testLogs   = @()
if (Test-Path $testsDir) { $testLogs = @(Get-ChildItem $testsDir -Filter "*.txt" -File) }

$json = Get-Content $activeJson -Raw -Encoding UTF8 | ConvertFrom-Json
$entityCombos = @()
foreach ($q in (Get-CommSysQidms $json)) {
    if ($q.targetEntity -ne $Entity) { continue }
    $entityCombos += Get-ComboInfo $q
}

$evidenceGaps = @()
foreach ($c in $entityCombos) {
    $matched = @($testLogs | Where-Object { Match-TestLogToCombo $_.Name $c $Provider })
    $valid = $false; $reason = "no matching test log"
    foreach ($log in $matched) {
        $pr = Test-LogProvenance $log.FullName $buildVer $entityFp
        if ($pr.Valid) { $valid = $true; break }
        else { $reason = ($pr.Reasons -join '; ') }
    }
    if (-not $valid) {
        $evidenceGaps += "$($c.KeyReference) ($(Get-ComboShortLabel $c)): $reason"
    }
    elseif ($activeTier -eq 'Final' -and @($c.Any).Count -gt 0) {
        # Final tier: optional any[] fields must be exercised -> a valid any[] log.
        $anyLog = $matched | Where-Object {
            ($_.Name -match '(?i)any') -and (Test-LogProvenance $_.FullName $buildVer $entityFp).Valid
        } | Select-Object -First 1
        if (-not $anyLog) {
            $evidenceGaps += "$($c.KeyReference) ($(Get-ComboShortLabel $c)): Final tier requires an any[] test log (optional fields untested)"
        }
    }
}

if ($activeTier -eq 'Final') {
    $entEsc = [regex]::Escape($Entity)
    $renderOk = @($testLogs | Where-Object { $_.Name -match "(?i)${entEsc}.*render" -and (Test-LogProvenance $_.FullName $buildVer $entityFp).Valid }).Count -gt 0
    if (-not $renderOk) { $evidenceGaps += "Final tier requires a render test log for $Entity" }
    $negOk = @($testLogs | Where-Object { $_.Name -match "(?i)${entEsc}.*negative" -and (Test-LogProvenance $_.FullName $buildVer $entityFp).Valid }).Count -gt 0
    if (-not $negOk) { $evidenceGaps += "Final tier requires a negative test log for $Entity" }
}

if ($evidenceGaps.Count -gt 0 -and -not $Force) {
    Write-Host "  [BLOCKED] '$Entity' lacks valid current-version evidence (tier: $activeTier, build v$buildVer, fingerprint $($entityFp.Substring(0,12))):" -ForegroundColor Red
    foreach ($g in ($evidenceGaps | Select-Object -First 20)) { Write-Host "      x $g" -ForegroundColor DarkYellow }
    Write-Host "    Run the missing tests via post_test.ps1 (logs auto-stamp version+fingerprint), or pass -Force." -ForegroundColor Red
    exit 1
}

# ── Update state: mark entity blocked with current fingerprint + global version ─
$state = Get-Content $stateJsonPath -Raw | ConvertFrom-Json
$global = $state.global
$entities = [ordered]@{}
foreach ($p in $state.entities.PSObject.Properties) {
    $entities[$p.Name] = [ordered]@{ version = $p.Value.version; fingerprint = $p.Value.fingerprint; status = $p.Value.status }
}
if (-not $entities.Contains($Entity)) {
    $entities[$Entity] = [ordered]@{ version = $global; fingerprint = $fp[$Entity]; status = 'open' }
}
$entities[$Entity].version     = $global
$entities[$Entity].fingerprint = $fp[$Entity]
$entities[$Entity].status      = 'blocked'

$stateObj = [ordered]@{ global = $global; entities = $entities }
[System.IO.File]::WriteAllText($stateJsonPath, ([pscustomobject]$stateObj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))

$forceNote = if ($Force -and ($pending -gt 0 -or $failed -gt 0)) { " (-Force: $pending pending / $failed failed marker(s) overridden)" } else { "" }
Write-Host "  [BLOCKED OUT] $Provider / $Entity @ v$global -- fingerprint $($fp[$Entity].Substring(0,12))...$forceNote" -ForegroundColor Green
Write-Host "    A rebuild that does not change $Entity will preserve its CONFIRMED tests; a structural change re-opens it." -ForegroundColor Gray

# ── Commit ─────────────────────────────────────────────────────────────────────
if (-not $NoCommit) {
    Push-Location $repoRoot
    try {
        & git add -- "$stateJsonPath" "$sqvrPath" 2>&1 | Out-Null
        $msg = "Block out $Provider/$Entity @ v$global (entity test results locked)`n`nfingerprint $($fp[$Entity])`n`nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
        & git commit -m $msg 2>&1 | Out-Null
        & git push 2>&1 | Out-Null
        Write-Host "    Git: committed + pushed" -ForegroundColor Gray
    } catch {
        Write-Host "    [WARN] git step failed: $_" -ForegroundColor Yellow
    } finally { Pop-Location }
}
exit 0
