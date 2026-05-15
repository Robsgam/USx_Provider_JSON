<#
  lock_provider.ps1 -- Lock or unlock a provider folder
  Renames folder to/from _LOCKED suffix, updates STATUS.txt lock line,
  and updates all references in CLAUDE.md, KB, and tools.

  Pre-lock validation (hard gates):
    1. BASE and MC JSON files must both exist
    2. BASE and MC versions must match
    3. Both must validate clean (0 FAIL in reports)
  Use -Force to override (prints warning but proceeds).

  Usage:
    .\lock_provider.ps1 -Provider NJ_NJCJIS -Action Lock
    .\lock_provider.ps1 -Provider NJ_NJCJIS -Action Unlock
    .\lock_provider.ps1 -Provider NJ_NJCJIS -Action Lock -Force
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider,
    [Parameter(Mandatory=$true)]
    [ValidateSet('Lock','Unlock')]
    [string]$Action,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

$lockedName   = "${Provider}_LOCKED"
$unlockedName = $Provider -replace '_LOCKED$', ''

if ($Action -eq 'Lock') {
    $srcFolder = Join-Path $repoRoot "providers\$unlockedName"
    $dstFolder = Join-Path $repoRoot "providers\$lockedName"
    $oldRef    = "providers/$unlockedName"
    $newRef    = "providers/$lockedName"
    $oldRefBs  = "providers\$unlockedName"
    $newRefBs  = "providers\$lockedName"

    if (-not (Test-Path $srcFolder)) {
        if (Test-Path $dstFolder) {
            Write-Host "  Already locked: $lockedName" -ForegroundColor Yellow
            exit 0
        }
        Write-Host "  [ERROR] Provider folder not found: $srcFolder" -ForegroundColor Red
        exit 1
    }

    # --- PRE-LOCK VALIDATION ---
    $preLockFail = $false
    Write-Host "  --- Pre-lock validation ---" -ForegroundColor Cyan

    # Gate 1: BASE and MC JSON files must exist
    $baseJson = Get-ChildItem $srcFolder -Filter "*_BASE.json" -File | Where-Object { $_.Name -notmatch 'READABLE' } | Select-Object -First 1
    $mcJson   = Get-ChildItem $srcFolder -Filter "*_MC.json"   -File | Where-Object { $_.Name -notmatch 'READABLE' } | Select-Object -First 1

    if (-not $baseJson) {
        Write-Host "  [FAIL] No BASE JSON found in $srcFolder" -ForegroundColor Red
        $preLockFail = $true
    }
    if (-not $mcJson) {
        Write-Host "  [FAIL] No MC JSON found in $srcFolder" -ForegroundColor Red
        $preLockFail = $true
    }

    # Gate 2: Version parity (extract from provider bundle description)
    if ($baseJson -and $mcJson) {
        $baseData = Get-Content $baseJson.FullName -Raw | ConvertFrom-Json
        $mcData   = Get-Content $mcJson.FullName   -Raw | ConvertFrom-Json

        $baseBundleDesc = ($baseData.bundles | Where-Object { $_.provider -notin @('MARK43','RMS') } | Select-Object -First 1).description
        $mcBundleDesc   = ($mcData.bundles   | Where-Object { $_.provider -notin @('MARK43','RMS') } | Select-Object -First 1).description

        $baseVer = if ($baseBundleDesc -match 'v([\d.]+)') { $Matches[1] } else { 'unknown' }
        $mcVer   = if ($mcBundleDesc   -match 'v([\d.]+)') { $Matches[1] } else { 'unknown' }

        if ($baseVer -ne $mcVer) {
            Write-Host "  [FAIL] Version mismatch: BASE v$baseVer != MC v$mcVer" -ForegroundColor Red
            $preLockFail = $true
        } else {
            Write-Host "  [PASS] Version parity: v$baseVer" -ForegroundColor Green
        }
    }

    # Gate 3: Validator reports exist and show 0 FAIL
    $docsDir = Join-Path $srcFolder "docs"
    foreach ($variant in @('base','mc')) {
        $reportDir = Join-Path $docsDir $variant
        $valReport = Join-Path $reportDir "VALIDATOR_REPORT_${unlockedName}_$($variant.ToUpper()).txt"
        if (Test-Path $valReport) {
            $valContent = Get-Content $valReport -Raw
            if ($valContent -match '(\d+)\s*FAIL' -and [int]$Matches[1] -gt 0) {
                Write-Host "  [FAIL] $($variant.ToUpper()) validator has $($Matches[1]) FAIL(s)" -ForegroundColor Red
                $preLockFail = $true
            } else {
                Write-Host "  [PASS] $($variant.ToUpper()) validator: 0 FAIL" -ForegroundColor Green
            }
        } else {
            Write-Host "  [FAIL] $($variant.ToUpper()) validator report not found: $valReport" -ForegroundColor Red
            $preLockFail = $true
        }
    }

    if ($preLockFail) {
        if ($Force) {
            Write-Host ""
            Write-Host "  [OVERRIDE] -Force specified. Locking despite failures." -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "  [BLOCKED] Pre-lock validation failed. Fix issues or use -Force to override." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  [PASS] All pre-lock checks passed" -ForegroundColor Green
    }
    Write-Host ""

    $statusFile = Get-ChildItem (Join-Path $srcFolder "docs") -Filter "*STATUS*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($statusFile) {
        $content = Get-Content $statusFile.FullName -Raw
        if ($content -notmatch 'LOCKED') {
            $content = $content -replace '(Last updated: \d{4}-\d{2}-\d{2})', "`$1`n`n  *** JSON LOCKED -- $unlockedName is frozen. Do not modify unless explicitly instructed. ***"
            [System.IO.File]::WriteAllText($statusFile.FullName, $content)
            Write-Host "  [UPDATE] Added LOCKED line to $($statusFile.Name)" -ForegroundColor Cyan
        }
    }

    Write-Host "  [RENAME] $unlockedName -> $lockedName" -ForegroundColor Green
    Rename-Item $srcFolder $dstFolder
}
else {
    $srcFolder = Join-Path $repoRoot "providers\$lockedName"
    $dstFolder = Join-Path $repoRoot "providers\$unlockedName"
    $oldRef    = "providers/$lockedName"
    $newRef    = "providers/$unlockedName"
    $oldRefBs  = "providers\$lockedName"
    $newRefBs  = "providers\$unlockedName"

    if (-not (Test-Path $srcFolder)) {
        if (Test-Path $dstFolder) {
            Write-Host "  Already unlocked: $unlockedName" -ForegroundColor Yellow
            exit 0
        }
        Write-Host "  [ERROR] Provider folder not found: $srcFolder" -ForegroundColor Red
        exit 1
    }

    $statusFile = Get-ChildItem (Join-Path $srcFolder "docs") -Filter "*STATUS*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($statusFile) {
        $content = Get-Content $statusFile.FullName -Raw
        $content = $content -replace '(?m)^\s*\*{3}.*LOCKED.*\*{3}\s*\r?\n', ''
        $content = $content -replace '\s*LOCKED', ''
        [System.IO.File]::WriteAllText($statusFile.FullName, $content)
        Write-Host "  [UPDATE] Removed all LOCKED references from $($statusFile.Name)" -ForegroundColor Cyan
    }

    Write-Host "  [RENAME] $lockedName -> $unlockedName" -ForegroundColor Green
    Rename-Item $srcFolder $dstFolder
}

$filesToUpdate = @(
    (Join-Path $repoRoot "CLAUDE.md")
    (Join-Path $repoRoot "knowledge-base\README.txt")
    (Join-Path $repoRoot "knowledge-base\FIELD_REFERENCE.txt")
    (Join-Path $repoRoot "tools\new_test_log.ps1")
    (Join-Path $repoRoot "tools\audit_cad.ps1")
)

$updatedCount = 0
foreach ($f in $filesToUpdate) {
    if (-not (Test-Path $f)) { continue }
    $text = [System.IO.File]::ReadAllText($f)
    if ($text -match [regex]::Escape($oldRef) -or $text -match [regex]::Escape($oldRefBs)) {
        $text = $text -replace [regex]::Escape($oldRef), $newRef
        $text = $text -replace [regex]::Escape($oldRefBs), $newRefBs
        [System.IO.File]::WriteAllText($f, $text)
        Write-Host "  [UPDATE] $(Split-Path $f -Leaf)" -ForegroundColor Cyan
        $updatedCount++
    }
}

$targetFolder = $dstFolder
$statusInTarget = Get-ChildItem (Join-Path $targetFolder "docs") -Filter "*STATUS*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($statusInTarget) {
    $text = [System.IO.File]::ReadAllText($statusInTarget.FullName)
    if ($text -match [regex]::Escape($oldRef)) {
        $text = $text -replace [regex]::Escape($oldRef), $newRef
        [System.IO.File]::WriteAllText($statusInTarget.FullName, $text)
        Write-Host "  [UPDATE] $($statusInTarget.Name) paths" -ForegroundColor Cyan
        $updatedCount++
    }
}

Write-Host ""
Write-Host "  ==============================" -ForegroundColor Cyan
Write-Host "  $Action complete: $Provider" -ForegroundColor Green
Write-Host "  Folder: providers\$(if ($Action -eq 'Lock') { $lockedName } else { $unlockedName })" -ForegroundColor White
Write-Host "  Files updated: $updatedCount" -ForegroundColor White
Write-Host "  ==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next: git add -A && git commit && git push" -ForegroundColor DarkGray
Write-Host ""
