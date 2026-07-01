<#
  reset_test_package.ps1 -- Restart the USx Tenant Testing package when a provider JSON is rebuilt.

  PRINCIPLE: A JSON rebuild (version bump) invalidates prior USx Tenant Testing logs -- combo
  routing, set[]/any[], conditions, or defaults may have changed. Logs from a prior
  version no longer line up with the shipped JSON. On every version change we restart
  testing from Test 1 so all logs match the current JSON.

  What it does (provider-agnostic):
    1. Reads the current version from the build script ($Version = "X.Y").
    2. Compares to tests/.test_version (the version the current logs belong to).
    3. If unchanged (and not -Force): no-op, prints "ALIGNED".
    4. If changed: archives all tests/*.txt -> tests/_archive_pre_v<version>/,
       resets every SQVR combo marker ([CONFIRMED]/[FAILED] -> [PENDING]),
       clears the STATUS "LIVE TEST RESULTS" rows, stamps tests/.test_version.

  Called automatically by pipeline.ps1 after a successful build; can also be run manually.

  Usage:
    .\reset_test_package.ps1 -Provider NY_NYSPIN_EJUSTICE
    .\reset_test_package.ps1 -Provider NY_NYSPIN_EJUSTICE -Force   # reset even if version unchanged
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [switch]$Force,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$testsDir = Join-Path $provDir "tests"
$docsDir  = Join-Path $provDir "docs"

# Shared active-JSON resolver (handles versioned <PROVIDER>_v<X.Y>.json names)
. "$toolDir\_resolve_provider_json.ps1"
# STATUS/SQVR = "tracking"; TEST_MATRIX = "reports" (2026-07-01 docs/ reorg pilot) --
# resolves to docs/<category>/ for a migrated provider (NJ_NJCJIS), flat docs/ otherwise.
. "$toolDir\_resolve_docs_path.ps1"
$trackingDir = Get-DocsCategoryDir $provDir 'tracking'
$reportsDirForMatrix = Get-DocsCategoryDir $provDir 'reports'

function Say($msg, $color = "White") { if (-not $Quiet) { Write-Host $msg -ForegroundColor $color } }

if (-not (Test-Path $provDir)) {
    Write-Host "  [ERROR] Provider not found: $Provider" -ForegroundColor Red
    exit 1
}

# ── Determine current version from the build script ───────────────────────────
$buildScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' } | Select-Object -First 1

$version = $null
if ($buildScript) {
    $bsText = Get-Content $buildScript.FullName -Raw
    if ($bsText -match '\$Version\s*=\s*"([0-9]+\.[0-9]+)"') { $version = $Matches[1] }
}
if (-not $version) {
    # Fallback: read version from the JSON bundle description
    $json = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
    if ($json -and (Test-Path $json)) {
        $jText = Get-Content $json -Raw
        if ($jText -match "$Provider v([0-9]+\.[0-9]+)") { $version = $Matches[1] }
    }
}
if (-not $version) {
    Write-Host "  [ERROR] Could not determine version for $Provider" -ForegroundColor Red
    exit 1
}

# ── Locate active JSON (needed for per-entity fingerprints) ───────────────────
$activeJson = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $activeJson) { $activeJson = Join-Path $provDir "$Provider.json" }

# ── Per-entity fingerprints + state (entity-aware "block out") ────────────────
# A "blocked" entity whose fingerprint is unchanged is PRESERVED across a rebuild;
# every other entity (open, or blocked-but-changed, or all under -Force) is RESET.
. "$toolDir\get_entity_fingerprints.ps1"
$currentFp = @{}
if (Test-Path $activeJson) {
    try { $currentFp = Get-EntityFingerprints -Path $activeJson } catch { $currentFp = @{} }
}

$stateFile     = Join-Path $testsDir ".test_version"      # legacy scalar (kept = global)
$stateJsonPath = Join-Path $testsDir ".test_state.json"   # authority

$priorEntities = @{}
if (Test-Path $stateJsonPath) {
    try {
        $ps = Get-Content $stateJsonPath -Raw | ConvertFrom-Json
        if ($ps.entities) { foreach ($p in $ps.entities.PSObject.Properties) { $priorEntities[$p.Name] = $p.Value } }
    } catch { $priorEntities = @{} }
}

$entityList = @($currentFp.Keys | Sort-Object)
$resetEntities    = New-Object System.Collections.Generic.List[string]
$preserveEntities = New-Object System.Collections.Generic.List[string]
foreach ($ent in $entityList) {
    $prior     = $priorEntities[$ent]
    $isBlocked = $prior -and $prior.status -eq 'blocked'
    $unchanged = $prior -and ($prior.fingerprint -eq $currentFp[$ent])
    if (-not $Force -and $isBlocked -and $unchanged) { $preserveEntities.Add($ent) }
    else { $resetEntities.Add($ent) }
}
$fullReset = ($preserveEntities.Count -eq 0)

# Build + persist the new state (do this even on the no-op path so global stays current).
function Write-TestState {
    $newEntities = [ordered]@{}
    foreach ($ent in $entityList) {
        if ($preserveEntities -contains $ent) {
            $newEntities[$ent] = [ordered]@{ version = $priorEntities[$ent].version; fingerprint = $currentFp[$ent]; status = 'blocked' }
        } else {
            $newEntities[$ent] = [ordered]@{ version = $version; fingerprint = $currentFp[$ent]; status = 'open' }
        }
    }
    $stateObj = [ordered]@{ global = $version; entities = $newEntities }
    [System.IO.File]::WriteAllText($stateJsonPath, ([pscustomobject]$stateObj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($stateFile, $version, (New-Object System.Text.UTF8Encoding($false)))
}

if ($resetEntities.Count -eq 0 -and -not $Force) {
    Write-TestState
    $pv = if ($preserveEntities.Count) { " (preserved: $($preserveEntities -join ', '))" } else { "" }
    Say "  ALIGNED: test package already at v$version$pv (no restart needed)" "Green"
    exit 0
}

# ── RESET (scoped to $resetEntities; full-file behavior when $fullReset) ───────
if (-not (Test-Path $testsDir)) { New-Item -ItemType Directory -Path $testsDir | Out-Null }

function Test-EntityInResetSet([string]$name) {
    foreach ($e in $resetEntities) { if ($name -match "(?i)(^|_)$([regex]::Escape($e))(_|$)") { return $true } }
    return $false
}

# 1. Archive prior live/sim logs (only reset-entity logs unless full reset)
$logs = Get-ChildItem $testsDir -File -Filter "*.txt" -ErrorAction SilentlyContinue
$archived = 0
if ($logs) {
    $archiveDir = Join-Path $testsDir "_archive_pre_v$version"
    foreach ($f in $logs) {
        if (-not $fullReset -and -not (Test-EntityInResetSet $f.BaseName)) { continue }
        if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
        $dest = Join-Path $archiveDir $f.Name
        # Truncate dest filename if it would exceed MAX_PATH (260).
        if ($dest.Length -gt 255) {
            $destDir  = [System.IO.Path]::GetDirectoryName($dest)
            $ext      = [System.IO.Path]::GetExtension($f.Name)
            $stem     = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            $maxStem  = 255 - $destDir.Length - 1 - $ext.Length
            if ($maxStem -lt 8) { $maxStem = 8 }
            $dest = Join-Path $destDir ($stem.Substring(0, [Math]::Min($stem.Length, $maxStem)) + $ext)
        }
        Move-Item $f.FullName $dest -Force
        $archived++
    }
}

# 1b. Archive the per-query wire-evidence files (providers/<PROVIDER>/logs/<Entity>/*.txt) the
#     same way -- added alongside the test logs above (2026-07-01 capture-pipeline standard) but
#     reset never knew about them, so they were being silently orphaned (left behind pointing at
#     an archived/deleted test log) instead of following their paired .txt into the archive.
#     Entity is the FOLDER name here (filenames are <Provider>_v<Version>_<Combo>.txt, no entity
#     in the name), so scope by folder rather than by filename pattern like the tests/ archive.
$snippetsArchived = 0
$logsRoot = Join-Path $provDir 'logs'
if (Test-Path $logsRoot) {
    $entityDirs = Get-ChildItem $logsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '_archive_pre_v*' }
    foreach ($ed in $entityDirs) {
        if (-not $fullReset -and -not ($resetEntities -contains $ed.Name)) { continue }
        $snippetFiles = Get-ChildItem $ed.FullName -File -ErrorAction SilentlyContinue
        if (-not $snippetFiles) { continue }
        $snippetArchiveDir = Join-Path $ed.FullName "_archive_pre_v$version"
        foreach ($f in $snippetFiles) {
            if (-not (Test-Path $snippetArchiveDir)) { New-Item -ItemType Directory -Path $snippetArchiveDir | Out-Null }
            Move-Item $f.FullName (Join-Path $snippetArchiveDir $f.Name) -Force
            $snippetsArchived++
        }
    }
}

# Helper: insert provisional-label banner after the first two lines (title + underline)
# of a doc file. Idempotent -- no second copy if already present.
$provisionalBanner = "LABELS PROVISIONAL -- refine wording during manual form use; not a graded test case."
function Add-ProvisionalBanner([string]$filePath) {
    if (-not (Test-Path $filePath)) { return }
    $lines = Get-Content $filePath -Encoding UTF8
    if ($lines | Where-Object { $_ -eq $provisionalBanner }) { return }
    $insertAt = [Math]::Min(2, $lines.Count)
    $newLines  = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $insertAt; $i++) { $newLines.Add($lines[$i]) }
    $newLines.Add($provisionalBanner)
    for ($i = $insertAt; $i -lt $lines.Count; $i++) { $newLines.Add($lines[$i]) }
    Set-Content -Path $filePath -Value $newLines -Encoding UTF8
}

# 2. Reset SQVR combo markers to [PENDING].
#    Full reset -> blanket replace (original behavior). Partial -> only markers in
#    sections for reset entities (SQVR section headers carry "-- <Entity> Entity";
#    cross-cutting sections like RMS BUNDLE/SUMMARY reset whenever anything resets).
$sqvrReset = 0
$sqvrPath = Join-Path $trackingDir "${Provider}_SQVR.txt"
if (Test-Path $sqvrPath) {
    if ($fullReset) {
        $sqvr = Get-Content $sqvrPath -Raw
        $sqvrReset += ([regex]::Matches($sqvr, '\[CONFIRMED\]')).Count
        $sqvrReset += ([regex]::Matches($sqvr, '\[FAILED[^\]]*\]')).Count
        $sqvr = $sqvr -replace '\[CONFIRMED\]', '[PENDING]'
        $sqvr = $sqvr -replace '\[FAILED[^\]]*\]', '[PENDING]'
        Set-Content -Path $sqvrPath -Value $sqvr -NoNewline -Encoding UTF8
    } else {
        $lines = Get-Content $sqvrPath
        $curEntity = $null          # $null = cross-cutting (reset when anything resets)
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($line in $lines) {
            if ($line -match '--\s+([A-Za-z]+)\s+Entity') { $curEntity = $Matches[1] }
            elseif ($line -match '^(RMS BUNDLE|SUMMARY)\s*$') { $curEntity = $null }
            $thisResets = ($null -eq $curEntity) -or ($resetEntities -contains $curEntity)
            if ($thisResets -and ($line -match '\[CONFIRMED\]' -or $line -match '\[FAILED[^\]]*\]')) {
                $sqvrReset += ([regex]::Matches($line, '\[CONFIRMED\]')).Count
                $sqvrReset += ([regex]::Matches($line, '\[FAILED[^\]]*\]')).Count
                $line = $line -replace '\[CONFIRMED\]', '[PENDING]' -replace '\[FAILED[^\]]*\]', '[PENDING]'
            }
            $out.Add($line)
        }
        Set-Content -Path $sqvrPath -Value $out -Encoding UTF8
    }
}
Add-ProvisionalBanner $sqvrPath

# 3. Clear STATUS "LIVE TEST RESULTS" data rows (Entity is column 3 of each row).
$statusCleared = 0
$statusPath = Join-Path $trackingDir "${Provider}_STATUS.txt"
if (Test-Path $statusPath) {
    $lines = Get-Content $statusPath -Encoding UTF8
    $out = New-Object System.Collections.Generic.List[string]
    $inLive = $false
    foreach ($line in $lines) {
        if ($line -match 'LIVE TEST RESULTS') { $inLive = $true; $out.Add($line); continue }
        if ($inLive) {
            # dated data row -> drop only if its Entity is in the reset set (or full reset)
            if ($line -match '^\s+---\s+\d{4}-\d{2}-\d{2}\s+(\S+)') {
                $rowEntity = $Matches[1]
                if ($fullReset -or ($resetEntities -contains $rowEntity)) { $statusCleared++; continue }
                $out.Add($line); continue
            }
            if ($line -match '^\s*\(none yet') { continue }
            if ($line -match '^\s+---\s+-{3,}') {
                $out.Add($line)
                $out.Add("  (none yet -- v$version USx Tenant Testing restarted from Test 1; prior logs archived to tests/_archive_pre_v$version/)")
                continue
            }
            if ($line -match '^\s*$' -or $line -match '^[A-Z]') { $inLive = $false }
        }
        $out.Add($line)
    }
    Set-Content -Path $statusPath -Value $out -Encoding UTF8
}
Add-ProvisionalBanner $statusPath

# 4. Stamp the new test state (.test_state.json authority + legacy .test_version scalar)
Write-TestState

# 5. Regenerate TEST_MATRIX so it never goes stale against the rebuilt JSON.
#    A combo add/remove between versions otherwise leaves the matrix claiming the old
#    count -- which audit_test_coverage -Gate flags as INCONSISTENT (matrix != JSON).
function Get-MatrixCount($matrixPath) {
    if (-not (Test-Path $matrixPath)) { return $null }
    $t = [System.IO.File]::ReadAllText($matrixPath)
    if ($t -match 'COMBO COVERAGE\s*\(\s*\d+\s*/\s*(\d+)\s*\)') { return [int]$Matches[1] }
    if ($t -match 'QIDM SUMMARY\s*\(\s*\d+\s*QIDMs?,\s*(\d+)\s*combos?\)') { return [int]$Matches[1] }
    return $null
}

$matrixPath = Join-Path $reportsDirForMatrix "${Provider}_TEST_MATRIX.txt"
$oldMatrixCount = Get-MatrixCount $matrixPath

# Locate the active JSON via the shared resolver (versioned <PROVIDER>_v<X.Y>.json -> bare
# -> _MC -> _BASE). Matches the resolution used at the top of this script (line ~70).
$activeJson = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $activeJson) { $activeJson = Join-Path $provDir "$Provider.json" }

$matrixRegenerated = $false
$matrixDelta = $null
if (Test-Path $activeJson) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "generate_test_matrix.ps1") -Path $activeJson -OutFile $matrixPath 2>&1 | Out-Null
    if (Test-Path $matrixPath) {
        $matrixRegenerated = $true
        $newMatrixCount = Get-MatrixCount $matrixPath
        if ($null -ne $oldMatrixCount -and $null -ne $newMatrixCount -and $oldMatrixCount -ne $newMatrixCount) {
            $matrixDelta = "$oldMatrixCount -> $newMatrixCount"
        }
    }
}

# 6. Version-stamped TEST_PLAN.json (logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json, root of the logs/
#    self-contained evidence package): archive any stale-version copy (rebuild changed the
#    version, so its plan no longer matches) and regenerate the current one so the driver never
#    runs against a stale plan.
$planRegenerated = $false
if (-not (Test-Path $logsRoot)) { New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null }
$oldPlans = @(Get-ChildItem $logsRoot -Filter "${Provider}_TEST_PLAN_v*.json" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "${Provider}_TEST_PLAN_v${version}.json" })
if ($oldPlans.Count -gt 0) {
    $planArchiveDir = Join-Path $logsRoot "_archive_pre_v$version"
    if (-not (Test-Path $planArchiveDir)) { New-Item -ItemType Directory -Path $planArchiveDir | Out-Null }
    foreach ($p in $oldPlans) { Move-Item $p.FullName (Join-Path $planArchiveDir $p.Name) -Force }
}
if (Test-Path $activeJson) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "emit_test_plan.ps1") -Path $activeJson 2>&1 | Out-Null
    $planRegenerated = Test-Path (Join-Path $logsRoot "${Provider}_TEST_PLAN_v${version}.json")
}

Say ""
$scope = if ($fullReset) { "all entities" } else { "entities: $($resetEntities -join ', ')" }
Say "  RESET: $Provider test package restarted for v$version -- $scope" "Yellow"
if ($preserveEntities.Count) {
    Say "    - PRESERVED (blocked, unchanged): $($preserveEntities -join ', ')" "Green"
}
Say "    - archived $archived prior log(s) -> tests/_archive_pre_v$version/" "Gray"
if ($snippetsArchived -gt 0) {
    Say "    - archived $snippetsArchived per-query wire-evidence file(s) -> logs/<Entity>/_archive_pre_v$version/" "Gray"
}
Say "    - reset $sqvrReset SQVR marker(s) -> [PENDING]" "Gray"
Say "    - cleared $statusCleared STATUS USx-Tenant-Testing row(s)" "Gray"
Say "    - stamped tests/.test_state.json + .test_version = v$version" "Gray"
if ($matrixRegenerated) {
    Say "    - regenerated ${Provider}_TEST_MATRIX.txt" "Gray"
    if ($matrixDelta) {
        Say "    [WARN] TEST_MATRIX combo count changed ($matrixDelta) -- combos added/removed this rebuild" "Yellow"
    }
} else {
    Say "    [WARN] could not regenerate TEST_MATRIX (no active JSON found at $activeJson)" "Yellow"
}
if ($oldPlans.Count -gt 0) {
    Say "    - archived $($oldPlans.Count) stale-version TEST_PLAN file(s) -> logs/_archive_pre_v$version/" "Gray"
}
if ($planRegenerated) {
    Say "    - regenerated logs/${Provider}_TEST_PLAN_v${version}.json" "Gray"
} else {
    Say "    [WARN] could not regenerate TEST_PLAN (no active JSON found at $activeJson)" "Yellow"
}
Say "  Re-run the full test matrix from Test 1 (see ${Provider}_TEST_MATRIX.txt)" "Gray"
exit 0
