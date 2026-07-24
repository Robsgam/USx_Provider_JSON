<#
.SYNOPSIS
  Scaffold a new provider with canonical folder structure, a single-JSON build script stub, and registrations.
.DESCRIPTION
  Emits the current single-JSON model: one build script -> one versioned <PROVIDER>_v<X.Y>.json,
  4-category docs/ (tracking/reports/reference/deliverables), logs/ as the only test-log location.
  No BASE/MC split, no phases/, no tests/ (all retired repo-wide).
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
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

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

# --- STEP 2: Create canonical directory structure (4-category docs + logs, single-JSON) ---
$dirs = @(
    $providerDir,
    "$providerDir\docs",
    "$providerDir\docs\tracking",
    "$providerDir\docs\reports",
    "$providerDir\docs\reference",
    "$providerDir\docs\deliverables",
    "$providerDir\logs",
    "$providerDir\scripts",
    "$providerDir\source"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}
Write-Host "  [PASS] Created canonical directory structure (4-category docs + logs)" -ForegroundColor Green

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

Write-Host "  [INFO] RMS bundle built from KB specs via _build_rms_bundle.ps1 (no HIDLE.json needed)" -ForegroundColor Cyan

# --- STEP 4: Create .gitkeep in logs/ ---
"" | Set-Content "$providerDir\logs\.gitkeep" -NoNewline

# --- STEP 5: Create STATUS.txt stub (docs/tracking/) ---
$statusContent = @"
================================================================
  STATUS: $providerName
  Version: v1.0
  Updated: $(Get-Date -Format 'yyyy-MM-dd')
================================================================

CURRENT STATE
=============
  Phase: 1 (STANDUP)
  JSON: Not built (${providerName}_v1.0.json)
  Import: Not attempted
  USx tenant test: Not started

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
$statusContent | Set-Content "$providerDir\docs\tracking\${providerName}_STATUS.txt"
Write-Host "  [PASS] Created STATUS.txt stub (docs/tracking/)" -ForegroundColor Green

# --- STEP 6: Create BUILD_NOTES.txt stub (docs/tracking/) ---
$buildNotesContent = @"
================================================================
  BUILD NOTES: $providerName
  Created: $(Get-Date -Format 'yyyy-MM-dd')
================================================================

v1.0 ($(Get-Date -Format 'yyyy-MM-dd'))
  CHANGED: Initial standup
  REASON:  New provider onboarding
"@
$buildNotesContent | Set-Content "$providerDir\docs\tracking\${providerName}_BUILD_NOTES.txt"
Write-Host "  [PASS] Created BUILD_NOTES.txt stub (docs/tracking/)" -ForegroundColor Green

# --- STEP 7: Create JSON_INVENTORY.md stub (docs/tracking/) ---
$inventoryContent = @"
# JSON Inventory: $providerName

| Version | File | Date | Notes |
|---|---|---|---|
| (no builds yet) | | | |
"@
$inventoryContent | Set-Content "$providerDir\docs\tracking\JSON_INVENTORY.md"
Write-Host "  [PASS] Created JSON_INVENTORY.md stub (docs/tracking/)" -ForegroundColor Green

# --- STEP 8: Run extract_queries.ps1 to create SQVR (docs/tracking/) ---
$extractScript = Join-Path $repoRoot "tools\extract_queries.ps1"
$sqvrPath = "$providerDir\docs\tracking\${providerName}_SQVR.txt"
if (Test-Path $extractScript) {
    try {
        & powershell -ExecutionPolicy Bypass -File $extractScript `
            -XmlPath "$providerDir\source\$($xmlFile.Name)" `
            -OutFile $sqvrPath 2>$null
        if (Test-Path $sqvrPath) {
            Write-Host "  [PASS] Generated SQVR from XML metadata (docs/tracking/)" -ForegroundColor Green
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

# --- STEP 9: Create single-JSON build script stub ---
$buildScriptContent = @"
<#
.SYNOPSIS
  Build $providerName JSON (single versioned output, multi-card-capable from the start).
.DESCRIPTION
  Generates ${providerName}_v<X.Y>.json in the provider root.
  One build script -> one JSON (no BASE/MC split). PascalCase USx CAD fields.
  Run tools/pipeline.ps1 -Provider $providerName after this script (build + report + enforce).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File providers/$providerName/scripts/build_$providerLower.ps1
#>

`$ErrorActionPreference = 'Stop'
`$scriptDir  = Split-Path `$MyInvocation.MyCommand.Path -Parent
`$providerDir = Split-Path `$scriptDir -Parent
`$repoRoot   = Split-Path (Split-Path `$providerDir -Parent) -Parent

# --- Shared modules (dot-source) ---
. (Join-Path `$repoRoot 'tools\_build_layout_helpers.ps1')
. (Join-Path `$repoRoot 'tools\_build_rms_bundle.ps1')
. (Join-Path `$repoRoot 'tools\_build_provider_helpers.ps1')

# Provider identity
`$providerName = '$providerName'
`$providerLower = '$providerLower'
`$Version = '1.0'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building `$providerName v`$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# TODO: Read XML metadata (docs/reference/${providerName}_METADATA_REFERENCE.txt) to determine:
#   - Supported queries (devdoc 'Basic Queries Supported' is scope authority)
#   - Available fields per query, combination requirements (set/any), keyReferences

# TODO: Build ENTITIES bundle first (QIFs; multi-card-capable). ENTITIES MUST be bundle #1.
# TODO: Build PROVIDER bundle (Build-Auth / Build-Qmf / Build-ProviderQrdm + QIDMs).
# TODO: Build RMS bundle:  `$rmsBundle = Build-RmsBundle -PascalCaseUsxFields   # + -KeepSsn / -SkipRace as needed

# --- Output (versioned filename carries the version; NEVER add a top-level `version` field) ---
`$OUT = Join-Path `$providerDir "`${providerName}_v`${Version}.json"
if (`$env:REPRO_OUTPATH) { `$OUT = `$env:REPRO_OUTPATH }   # audit_reproducible hook

# Write-ProviderJson -BundleObject `$bundle -OutPath `$OUT -Label "`$providerName v`$Version"

Write-Host ""
Write-Host "  [TODO] Build script is a stub -- implement entity definitions and QIDM configs" -ForegroundColor Yellow
Write-Host ""
"@
$buildScriptContent | Set-Content "$providerDir\scripts\build_$providerLower.ps1"
Write-Host "  [PASS] Created single-JSON build script stub" -ForegroundColor Green

# --- STEP 10: Update tools/new_test_log.ps1 knownPaths ---
$testLogScript = Join-Path $repoRoot "tools\new_test_log.ps1"
if (Test-Path $testLogScript) {
    $content = Get-Content $testLogScript -Raw
    if ($content -notmatch [regex]::Escape($providerName)) {
        Write-Host "  [INFO] Add '$providerName' to tools/new_test_log.ps1 knownPaths manually" -ForegroundColor Gray
    } else {
        Write-Host "  [PASS] Provider already in new_test_log.ps1" -ForegroundColor Green
    }
}

# --- STEP 11: Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " SCAFFOLD COMPLETE: $providerName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Created:" -ForegroundColor White
Write-Host "    providers/$providerName/"
Write-Host "      docs/tracking/ (STATUS, BUILD_NOTES, SQVR, JSON_INVENTORY)"
Write-Host "      docs/reports/ docs/reference/ docs/deliverables/"
Write-Host "      scripts/build_$providerLower.ps1 (single-JSON stub)"
Write-Host "      source/ ($($xmlFile.Name)$(if($PdfPath){', PDF'}))"
Write-Host "      logs/"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Read devdoc 'Basic Queries Supported' section"
Write-Host "    2. Implement build_$providerLower.ps1 (QIDM-first, multi-card-capable)"
Write-Host "    3. Run tools/pipeline.ps1 -Provider $providerName (build + report + enforce, GATE 1)"
Write-Host "    4. Add provider to CLAUDE.md provider table"
Write-Host "    5. git add + commit + push"
Write-Host ""
