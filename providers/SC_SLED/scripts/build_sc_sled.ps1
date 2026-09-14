<#
.SYNOPSIS
  Build SC_SLED JSON (single versioned output, multi-card-capable from the start).
.DESCRIPTION
  Generates SC_SLED_v<X.Y>.json in the provider root.
  One build script -> one JSON (no BASE/MC split). PascalCase USx CAD fields.
  Run tools/pipeline.ps1 -Provider SC_SLED after this script (build + report + enforce).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File providers/SC_SLED/scripts/build_sc_sled.ps1
#>

$ErrorActionPreference = 'Stop'
$scriptDir  = Split-Path $MyInvocation.MyCommand.Path -Parent
$providerDir = Split-Path $scriptDir -Parent
$repoRoot   = Split-Path (Split-Path $providerDir -Parent) -Parent

# --- Shared modules (dot-source) ---
. (Join-Path $repoRoot 'tools\_build_layout_helpers.ps1')
. (Join-Path $repoRoot 'tools\_build_rms_bundle.ps1')
. (Join-Path $repoRoot 'tools\_build_provider_helpers.ps1')

# Provider identity
$providerName = 'SC_SLED'
$providerLower = 'sc_sled'
$Version = '1.0'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building $providerName v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# TODO: Read XML metadata (docs/reference/SC_SLED_METADATA_REFERENCE.txt) to determine:
#   - Supported queries (devdoc 'Basic Queries Supported' is scope authority)
#   - Available fields per query, combination requirements (set/any), keyReferences

# TODO: Build ENTITIES bundle first (QIFs; multi-card-capable). ENTITIES MUST be bundle #1.
# TODO: Build PROVIDER bundle (Build-Auth / Build-Qmf / Build-ProviderQrdm + QIDMs).
# TODO: Build RMS bundle:  $rmsBundle = Build-RmsBundle -PascalCaseUsxFields   # + -KeepSsn / -SkipRace as needed

# --- Output (versioned filename carries the version; NEVER add a top-level ersion field) ---
$OUT = Join-Path $providerDir "${providerName}_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }   # audit_reproducible hook

# Write-ProviderJson -BundleObject $bundle -OutPath $OUT -Label "$providerName v$Version"

Write-Host ""
Write-Host "  [TODO] Build script is a stub -- implement entity definitions and QIDM configs" -ForegroundColor Yellow
Write-Host ""
