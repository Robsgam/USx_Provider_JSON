<#
  lock_provider.ps1 -- Lock or unlock a provider folder
  Renames folder to/from _LOCKED suffix, updates STATUS.txt lock line,
  and updates all references in CLAUDE.md, KB, and tools.

  Usage:
    .\lock_provider.ps1 -Provider NJ_NJCJIS -Action Lock
    .\lock_provider.ps1 -Provider NJ_NJCJIS -Action Unlock
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider,
    [Parameter(Mandatory=$true)]
    [ValidateSet('Lock','Unlock')]
    [string]$Action
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
        [System.IO.File]::WriteAllText($statusFile.FullName, $content)
        Write-Host "  [UPDATE] Removed LOCKED line from $($statusFile.Name)" -ForegroundColor Cyan
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

$targetFolder = if ($Action -eq 'Lock') { $dstFolder } else { $dstFolder }
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
