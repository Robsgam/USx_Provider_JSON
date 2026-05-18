<#
  stage_provider.ps1 -- Retroactive staging for already-locked providers

  NOTE: lock_provider.ps1 now handles staging automatically on lock/unlock.
  This script is for providers that were locked before that change, or to
  re-stage if something got out of sync.

  For each locked provider:
    - Keeps only the foundation-testing variant (BASE or MC) in the provider root
    - Moves the other variant into phases/ archive
    - Moves the active JSON into deployed/ inside the provider folder

  Usage:
    .\stage_provider.ps1                          # Stage all locked providers
    .\stage_provider.ps1 -Provider FL_FCIC        # Stage one provider
    .\stage_provider.ps1 -Provider FL_FCIC -Undo  # Restore both variants to root
#>

param(
    [string]$Provider,
    [switch]$Undo
)

$ErrorActionPreference = "Stop"
$repoRoot     = (Resolve-Path "$PSScriptRoot\..").Path
$providersDir = Join-Path $repoRoot "providers"

# --- VARIANT CONFIG ---
# Which variant goes to foundation testing for each provider.
# MC = multi-card (newer UI), BASE = legacy single-card.
$variantMap = @{
    'FL_FCIC'      = 'MC'
    'NJ_NJCJIS'    = 'BASE'
    'CA_CLETS'     = 'BASE'
}

function Get-ProviderBaseName($folderName) {
    $folderName -replace '_(LOCKED|BLOCKED)$', ''
}

function Stage-Provider($folder) {
    $folderName = Split-Path $folder -Leaf
    $baseName   = Get-ProviderBaseName $folderName
    $isLocked   = $folderName -match '_LOCKED$'

    if (-not $isLocked) {
        Write-Host "  [SKIP] $folderName -- not locked" -ForegroundColor DarkGray
        return
    }

    $activeVariant = $variantMap[$baseName]
    if (-not $activeVariant) {
        Write-Host "  [SKIP] $baseName -- no variant configured in `$variantMap. Add it to stage." -ForegroundColor Yellow
        return
    }

    $archiveVariant = if ($activeVariant -eq 'MC') { 'BASE' } else { 'MC' }
    $deployedDir    = Join-Path $folder "deployed"
    $undeployedDir  = Join-Path $folder "undeployed"

    if (-not (Test-Path $deployedDir))   { New-Item -ItemType Directory $deployedDir   -Force | Out-Null }
    if (-not (Test-Path $undeployedDir)) { New-Item -ItemType Directory $undeployedDir -Force | Out-Null }

    Write-Host "  --- $baseName (keep $activeVariant, archive $archiveVariant) ---" -ForegroundColor Cyan

    # Archive the non-active variant to phases/
    $archiveJsons = Get-ChildItem $folder -Filter "*_${archiveVariant}*.json" -File
    if ($archiveJsons.Count -gt 0) {
        $phaseSub = if ($archiveVariant -eq 'MC') { 'mc' } else { 'base' }
        $archiveDir = Join-Path $folder "phases\$phaseSub"
        if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory $archiveDir -Force | Out-Null }

        foreach ($j in $archiveJsons) {
            $dest = Join-Path $archiveDir $j.Name
            if (Test-Path $dest) {
                Write-Host "    [EXISTS] phases\$phaseSub\$($j.Name) -- already archived" -ForegroundColor DarkGray
            } else {
                Copy-Item $j.FullName $dest
                Write-Host "    [ARCHIVE] $($j.Name) -> phases\$phaseSub\" -ForegroundColor Yellow
            }
            Remove-Item $j.FullName
            Write-Host "    [REMOVE] $($j.Name) from root" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [OK] No $archiveVariant JSONs in root (already clean)" -ForegroundColor Green
    }

    # Move active variant JSONs into deployed/ inside this provider folder
    $activeJsons = Get-ChildItem $folder -Filter "*_${activeVariant}*.json" -File
    if ($activeJsons.Count -gt 0) {
        foreach ($j in $activeJsons) {
            $dest = Join-Path $deployedDir $j.Name
            Move-Item $j.FullName $dest -Force
            Write-Host "    [DEPLOY] $($j.Name) -> deployed\" -ForegroundColor Green
        }
    } else {
        Write-Host "    [OK] Active JSONs already in deployed/" -ForegroundColor Green
    }

    # Show final state
    $rootJsons    = Get-ChildItem $folder -Filter "*.json" -File -ErrorAction SilentlyContinue
    $depJsons     = Get-ChildItem $deployedDir -Filter "*.json" -File -ErrorAction SilentlyContinue
    if ($rootJsons.Count -eq 0) {
        Write-Host "    [ROOT] clean -- no JSONs" -ForegroundColor Green
    } else {
        Write-Host "    [ROOT] $($rootJsons.Name -join ', ')" -ForegroundColor White
    }
    Write-Host "    [deployed/] $($depJsons.Name -join ', ')" -ForegroundColor Green
}

function Undo-Provider($folder) {
    $folderName = Split-Path $folder -Leaf
    $baseName   = Get-ProviderBaseName $folderName

    $activeVariant  = $variantMap[$baseName]
    if (-not $activeVariant) { return }
    $archiveVariant = if ($activeVariant -eq 'MC') { 'BASE' } else { 'MC' }
    $phaseSub       = if ($archiveVariant -eq 'MC') { 'mc' } else { 'base' }
    $deployedDir    = Join-Path $folder "deployed"

    Write-Host "  --- $baseName (restoring all variants to root) ---" -ForegroundColor Cyan

    # Restore active variant from deployed/ back to root
    if (Test-Path $deployedDir) {
        $depJsons = Get-ChildItem $deployedDir -Filter "*.json" -File
        foreach ($j in $depJsons) {
            $dst = Join-Path $folder $j.Name
            if (-not (Test-Path $dst)) {
                Move-Item $j.FullName $dst
                Write-Host "    [RESTORE] deployed\$($j.Name) -> root" -ForegroundColor Green
            }
        }
        $remaining = Get-ChildItem $deployedDir -File -ErrorAction SilentlyContinue
        if (-not $remaining) { Remove-Item $deployedDir -Force }
    }

    # Restore archived variant from phases/ back to root
    $archiveDir  = Join-Path $folder "phases\$phaseSub"
    $rootPattern = "${baseName}_${archiveVariant}"
    $restoreFile = "${rootPattern}.json"
    $src = Join-Path $archiveDir $restoreFile
    $dst = Join-Path $folder $restoreFile
    if ((Test-Path $src) -and -not (Test-Path $dst)) {
        Copy-Item $src $dst
        Write-Host "    [RESTORE] phases\$phaseSub\$restoreFile -> root" -ForegroundColor Green
    }

    # Clean up empty undeployed/
    $undeployedDir = Join-Path $folder "undeployed"
    if ((Test-Path $undeployedDir) -and -not (Get-ChildItem $undeployedDir -File -ErrorAction SilentlyContinue)) {
        Remove-Item $undeployedDir -Force
    }
}

# --- MAIN ---
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  stage_provider.ps1 -- JSON deployment staging" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

$lockedFolders = Get-ChildItem $providersDir -Directory | Where-Object { $_.Name -match '_LOCKED$' }

if ($Provider) {
    $match = $lockedFolders | Where-Object { $_.Name -match "^${Provider}(_LOCKED)?$" }
    if (-not $match) {
        Write-Host "  [ERROR] No locked folder found for $Provider" -ForegroundColor Red
        exit 1
    }
    $lockedFolders = @($match)
}

foreach ($f in $lockedFolders) {
    if ($Undo) {
        Undo-Provider $f.FullName
    } else {
        Stage-Provider $f.FullName
    }
}

Write-Host ""
