<#
  reset_test_package.ps1 -- Restart the live test package when a provider JSON is rebuilt.

  PRINCIPLE: A JSON rebuild (version bump) invalidates prior live test logs -- combo
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
    $json = Join-Path $provDir "$Provider.json"
    if (Test-Path $json) {
        $jText = Get-Content $json -Raw
        if ($jText -match "$Provider v([0-9]+\.[0-9]+)") { $version = $Matches[1] }
    }
}
if (-not $version) {
    Write-Host "  [ERROR] Could not determine version for $Provider" -ForegroundColor Red
    exit 1
}

# ── Compare against the recorded test version ─────────────────────────────────
$stateFile = Join-Path $testsDir ".test_version"
$recorded  = if (Test-Path $stateFile) { ((Get-Content $stateFile -Raw) -replace "^﻿", '').Trim() } else { $null }

if ($recorded -eq $version -and -not $Force) {
    Say "  ALIGNED: test package already at v$version (no restart needed)" "Green"
    exit 0
}

# ── RESET ─────────────────────────────────────────────────────────────────────
if (-not (Test-Path $testsDir)) { New-Item -ItemType Directory -Path $testsDir | Out-Null }

# 1. Archive prior live/sim logs
$logs = Get-ChildItem $testsDir -File -Filter "*.txt" -ErrorAction SilentlyContinue
$archived = 0
if ($logs) {
    $archiveDir = Join-Path $testsDir "_archive_pre_v$version"
    if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
    foreach ($f in $logs) {
        $dest = Join-Path $archiveDir $f.Name
        # Truncate dest filename if it would exceed MAX_PATH (260) -- long-named logs
        # hit this when the archive subdir adds ~22 chars.
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

# 2. Reset SQVR combo markers to [PENDING]
$sqvrReset = 0
$sqvrPath = Join-Path $docsDir "${Provider}_SQVR.txt"
if (Test-Path $sqvrPath) {
    $sqvr = Get-Content $sqvrPath -Raw
    $sqvrReset += ([regex]::Matches($sqvr, '\[CONFIRMED\]')).Count
    $sqvrReset += ([regex]::Matches($sqvr, '\[FAILED[^\]]*\]')).Count
    $sqvr = $sqvr -replace '\[CONFIRMED\]', '[PENDING]'
    $sqvr = $sqvr -replace '\[FAILED[^\]]*\]', '[PENDING]'
    Set-Content -Path $sqvrPath -Value $sqvr -NoNewline -Encoding UTF8
}

# 3. Clear STATUS "LIVE TEST RESULTS" data rows
$statusCleared = 0
$statusPath = Join-Path $docsDir "${Provider}_STATUS.txt"
if (Test-Path $statusPath) {
    $lines = Get-Content $statusPath
    $out = New-Object System.Collections.Generic.List[string]
    $inLive = $false
    $placeholderAdded = $false
    foreach ($line in $lines) {
        if ($line -match 'LIVE TEST RESULTS') { $inLive = $true; $out.Add($line); continue }
        if ($inLive) {
            # dated data row -> drop
            if ($line -match '^\s+---\s+\d{4}-\d{2}-\d{2}') { $statusCleared++; continue }
            # existing placeholder -> drop (will re-add once)
            if ($line -match '^\s*\(none yet') { continue }
            # column-dashes header line: keep, then add fresh placeholder after it
            if ($line -match '^\s+---\s+-{3,}') {
                $out.Add($line)
                $out.Add("  (none yet -- v$version live testing restarted from Test 1; prior logs archived to tests/_archive_pre_v$version/)")
                $placeholderAdded = $true
                continue
            }
            # blank line or next section ends the LIVE TEST block
            if ($line -match '^\s*$' -or $line -match '^[A-Z]') { $inLive = $false }
        }
        $out.Add($line)
    }
    Set-Content -Path $statusPath -Value $out -Encoding UTF8
}

# 4. Stamp the new test version (UTF-8 no BOM so the comparison stays reliable)
[System.IO.File]::WriteAllText($stateFile, $version, (New-Object System.Text.UTF8Encoding($false)))

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

$matrixPath = Join-Path $docsDir "${Provider}_TEST_MATRIX.txt"
$oldMatrixCount = Get-MatrixCount $matrixPath

# Locate the active JSON: single-JSON <PROVIDER>.json, then legacy _MC / _BASE.
$activeJson = Join-Path $provDir "$Provider.json"
if (-not (Test-Path $activeJson)) {
    $alt = Get-ChildItem $provDir -Filter "*_MC.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $alt) { $alt = Get-ChildItem $provDir -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($alt) { $activeJson = $alt.FullName }
}

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

Say ""
Say "  RESET: $Provider test package restarted for v$version" "Yellow"
Say "    - archived $archived prior log(s) -> tests/_archive_pre_v$version/" "Gray"
Say "    - reset $sqvrReset SQVR marker(s) -> [PENDING]" "Gray"
Say "    - cleared $statusCleared STATUS live-test row(s)" "Gray"
Say "    - stamped tests/.test_version = v$version" "Gray"
if ($matrixRegenerated) {
    Say "    - regenerated docs/${Provider}_TEST_MATRIX.txt" "Gray"
    if ($matrixDelta) {
        Say "    [WARN] TEST_MATRIX combo count changed ($matrixDelta) -- combos added/removed this rebuild" "Yellow"
    }
} else {
    Say "    [WARN] could not regenerate TEST_MATRIX (no active JSON found at $activeJson)" "Yellow"
}
Say "  Re-run the full test matrix from Test 1 (see docs/${Provider}_TEST_MATRIX.txt)" "Gray"
exit 0
