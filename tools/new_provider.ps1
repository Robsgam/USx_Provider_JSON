<#
.SYNOPSIS
  Scaffold a new provider with canonical folder structure, build script stubs, and registrations.
.PARAMETER XmlPath
  Path to the provider's metadata XML file. Folder name is derived from this filename.
.PARAMETER PdfPath
  (Optional) Path to the provider's devdoc PDF file.
.PARAMETER Force
  Overwrite existing provider folder if it exists.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/new_provider.ps1 -XmlPath "C:\source\MD_METERS.xml"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$XmlPath,

    [string]$PdfPath,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent)

# --- STEP 0: Derive provider name from XML filename ---
if (-not (Test-Path $XmlPath)) {
    Write-Host "  [FAIL] XML file not found: $XmlPath" -ForegroundColor Red
    exit 1
}
$xmlFile = Get-Item $XmlPath
$providerName = $xmlFile.BaseName
$providerLower = $providerName.ToLower()
$providerDir = Join-Path $repoRoot "providers\$providerName"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " NEW PROVIDER: $providerName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  XML source:    $($xmlFile.Name)"
Write-Host "  Folder:        providers\$providerName\"
Write-Host "  Script prefix: build_$providerLower"
Write-Host ""

# --- STEP 1: Check for existing folder ---
if (Test-Path $providerDir) {
    if (-not $Force) {
        Write-Host "  [FAIL] Provider folder already exists: $providerDir" -ForegroundColor Red
        Write-Host "         Use -Force to overwrite." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [WARN] Overwriting existing folder (Force)" -ForegroundColor Yellow
}

# --- STEP 2: Create canonical directory structure ---
$dirs = @(
    $providerDir,
    "$providerDir\docs",
    "$providerDir\docs\base",
    "$providerDir\docs\mc",
    "$providerDir\scripts",
    "$providerDir\source",
    "$providerDir\tests",
    "$providerDir\phases",
    "$providerDir\phases\base",
    "$providerDir\phases\mc",
    "$providerDir\release"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Host "  [PASS] Created canonical directory structure" -ForegroundColor Green

# --- STEP 3: Copy source materials ---
Copy-Item $XmlPath "$providerDir\source\$($xmlFile.Name)" -Force
Write-Host "  [PASS] Copied XML metadata to source/" -ForegroundColor Green

if ($PdfPath -and (Test-Path $PdfPath)) {
    $pdfFile = Get-Item $PdfPath
    Copy-Item $PdfPath "$providerDir\source\$($pdfFile.Name)" -Force
    Write-Host "  [PASS] Copied devdoc PDF to source/" -ForegroundColor Green
} else {
    Write-Host "  [INFO] No PDF provided (add manually to source/ later)" -ForegroundColor Gray
}

$hidleSrc = Join-Path $repoRoot "templates\HIDLE.json"
if (Test-Path $hidleSrc) {
    Copy-Item $hidleSrc "$providerDir\source\HIDLE.json" -Force
    Write-Host "  [PASS] Copied HIDLE.json template to source/" -ForegroundColor Green
} else {
    Write-Host "  [WARN] HIDLE.json not found at templates/HIDLE.json" -ForegroundColor Yellow
}

# --- STEP 4: Create .gitkeep in tests/ ---
"" | Set-Content "$providerDir\tests\.gitkeep" -NoNewline

# --- STEP 5: Create STATUS.txt stub ---
$statusContent = @"
================================================================
  STATUS: $providerName
  Version: v1.0
  Updated: $(Get-Date -Format 'yyyy-MM-dd')
================================================================

CURRENT STATE
=============
  Phase: 1 (STANDUP)
  BASE: Not built
  MC: Not built
  Import: Not attempted

TEST MATRIX
===========
  Entity              Query                    Combo       Result    Date
  ------------------  -----------------------  ----------  --------  ----------
  (no tests yet)

NOTES
=====
  Provider scaffolded on $(Get-Date -Format 'yyyy-MM-dd').
  XML source: $($xmlFile.Name)
"@
$statusContent | Set-Content "$providerDir\docs\${providerName}_STATUS.txt"
Write-Host "  [PASS] Created STATUS.txt stub" -ForegroundColor Green

# --- STEP 6: Create BUILD_NOTES.txt stub ---
$buildNotesContent = @"
================================================================
  BUILD NOTES: $providerName
  Created: $(Get-Date -Format 'yyyy-MM-dd')
================================================================

v1.0 ($(Get-Date -Format 'yyyy-MM-dd'))
  CHANGED: Initial standup
  REASON:  New provider onboarding
"@
$buildNotesContent | Set-Content "$providerDir\docs\${providerName}_BUILD_NOTES.txt"
Write-Host "  [PASS] Created BUILD_NOTES.txt stub" -ForegroundColor Green

# --- STEP 7: Create JSON_INVENTORY.md stub ---
$inventoryContent = @"
# JSON Inventory: $providerName

| Version | File | Date | Notes |
|---|---|---|---|
| (no builds yet) | | | |
"@
$inventoryContent | Set-Content "$providerDir\docs\JSON_INVENTORY.md"
Write-Host "  [PASS] Created JSON_INVENTORY.md stub" -ForegroundColor Green

# --- STEP 8: Run extract_queries.ps1 to create SQVR ---
$extractScript = Join-Path $repoRoot "tools\extract_queries.ps1"
$sqvrPath = "$providerDir\docs\${providerName}_SQVR.txt"
if (Test-Path $extractScript) {
    try {
        & powershell -ExecutionPolicy Bypass -File $extractScript `
            -XmlPath "$providerDir\source\$($xmlFile.Name)" `
            -OutFile $sqvrPath 2>$null
        if (Test-Path $sqvrPath) {
            Write-Host "  [PASS] Generated SQVR from XML metadata" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] extract_queries.ps1 ran but no SQVR output" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [WARN] extract_queries.ps1 failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $sqvrStub = @"
================================================================
  SUPPORTED QUERY VALIDATION REPORT: $providerName
  Generated: $(Get-Date -Format 'yyyy-MM-dd')
================================================================

(Run extract_queries.ps1 manually to populate)
"@
        $sqvrStub | Set-Content $sqvrPath
    }
} else {
    Write-Host "  [WARN] extract_queries.ps1 not found, creating SQVR stub" -ForegroundColor Yellow
    $sqvrStub = @"
================================================================
  SUPPORTED QUERY VALIDATION REPORT: $providerName
  Generated: $(Get-Date -Format 'yyyy-MM-dd')
================================================================

(Run extract_queries.ps1 to populate from XML)
"@
    $sqvrStub | Set-Content $sqvrPath
}

# --- STEP 9: Create BASE build script stub ---
$baseScriptContent = @"
<#
.SYNOPSIS
  Build $providerName BASE JSON (Phase 1 single-card layout).
.DESCRIPTION
  Generates ${providerName}_BASE.json and ${providerName}_BASE_READABLE.json.
  Run build_report.ps1 after this script.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File providers/$providerName/scripts/build_$providerLower.ps1
#>

`$ErrorActionPreference = 'Stop'
`$scriptDir  = Split-Path `$MyInvocation.MyCommand.Path -Parent
`$providerDir = Split-Path `$scriptDir -Parent
`$repoRoot   = Split-Path (Split-Path `$providerDir -Parent) -Parent

# Provider identity
`$providerName = '$providerName'
`$providerLower = '$providerLower'
`$version = 'v1.0'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building `$providerName BASE `$version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# TODO: Read XML metadata to determine:
#   - Supported queries (MessageKey elements)
#   - Available fields per query
#   - Combination requirements (set/any)
#   - KeyReferences

# TODO: Build ENTITIES bundle (QIFs with single-card layout)
# TODO: Build PROVIDER bundle (AUTH, QMF, QRDM, QIDMs)
# TODO: Build RMS bundle (clone HIDLE, apply Patches 1,3,6,7,8)

# --- Output ---
`$outMin  = Join-Path `$providerDir "`${providerName}_BASE.json"
`$outRead = Join-Path `$providerDir "`${providerName}_BASE_READABLE.json"

# `$json | Set-Content `$outMin -Encoding UTF8
# `$json | ConvertTo-Json -Depth 100 | Set-Content `$outRead -Encoding UTF8

Write-Host ""
Write-Host "  [TODO] Build script is a stub -- implement entity definitions and QIDM configs" -ForegroundColor Yellow
Write-Host ""

# --- Validation ---
# `$validator = Join-Path `$repoRoot "tools\validate.ps1"
# & powershell -ExecutionPolicy Bypass -File `$validator -Path `$outMin
"@
$baseScriptContent | Set-Content "$providerDir\scripts\build_$providerLower.ps1"
Write-Host "  [PASS] Created BASE build script stub" -ForegroundColor Green

# --- STEP 10: Create MC build script stub ---
$mcScriptContent = @"
<#
.SYNOPSIS
  Build $providerName MC JSON (Phase 2 multi-card layout).
.DESCRIPTION
  Generates ${providerName}_MC.json and ${providerName}_MC_READABLE.json.
  MC uses PascalCase fieldIds, multi-card layout, CAD_DISPATCH/FIRST_RESPONDER context cards.
  Run build_report.ps1 after this script.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File providers/$providerName/scripts/build_${providerLower}_mc.ps1
#>

`$ErrorActionPreference = 'Stop'
`$scriptDir  = Split-Path `$MyInvocation.MyCommand.Path -Parent
`$providerDir = Split-Path `$scriptDir -Parent
`$repoRoot   = Split-Path (Split-Path `$providerDir -Parent) -Parent

# Provider identity
`$providerName = '$providerName'
`$providerLower = '$providerLower'
`$version = 'v1.0'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building `$providerName MC `$version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# MC differences from BASE:
#   - PascalCase fieldIds (no Patch 8 rename except LicensePlateNumberIn)
#   - Multi-card layout (one card per search path)
#   - CAD_DISPATCH and FIRST_RESPONDER context cards (CONTEXT_INFO_CARD)
#   - Cross-entity combos where metadata supports them

# TODO: Implement MC build (share QIDM logic with BASE, swap layout)

# --- Output ---
`$outMin  = Join-Path `$providerDir "`${providerName}_MC.json"
`$outRead = Join-Path `$providerDir "`${providerName}_MC_READABLE.json"

Write-Host ""
Write-Host "  [TODO] MC build script is a stub -- implement multi-card layout" -ForegroundColor Yellow
Write-Host ""
"@
$mcScriptContent | Set-Content "$providerDir\scripts\build_${providerLower}_mc.ps1"
Write-Host "  [PASS] Created MC build script stub" -ForegroundColor Green

# --- STEP 11: Update tools/new_test_log.ps1 knownPaths ---
$testLogScript = Join-Path $repoRoot "tools\new_test_log.ps1"
if (Test-Path $testLogScript) {
    $content = Get-Content $testLogScript -Raw
    if ($content -notmatch [regex]::Escape($providerName)) {
        Write-Host "  [INFO] Add '$providerName' to tools/new_test_log.ps1 knownPaths manually" -ForegroundColor Gray
    } else {
        Write-Host "  [PASS] Provider already in new_test_log.ps1" -ForegroundColor Green
    }
}

# --- STEP 12: Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " SCAFFOLD COMPLETE: $providerName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Created:" -ForegroundColor White
Write-Host "    providers/$providerName/"
Write-Host "      docs/ (STATUS, BUILD_NOTES, SQVR, JSON_INVENTORY)"
Write-Host "      docs/base/ docs/mc/"
Write-Host "      scripts/build_$providerLower.ps1 (BASE stub)"
Write-Host "      scripts/build_${providerLower}_mc.ps1 (MC stub)"
Write-Host "      source/ ($($xmlFile.Name), HIDLE.json$(if($PdfPath){', PDF'}))"
Write-Host "      tests/ phases/base/ phases/mc/ release/"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Read devdoc 'Basic Queries Supported' section"
Write-Host "    2. Implement build_$providerLower.ps1 (Phase 1 single-card)"
Write-Host "    3. Run build_report.ps1 (GATE 1)"
Write-Host "    4. Add provider to CLAUDE.md provider table"
Write-Host "    5. git add + commit + push"
Write-Host ""
