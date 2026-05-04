<#
  build_report.ps1 -- Generate layout + query reports for a provider JSON
  Runs validator, renderer, query simulator, and picklist scanner.
  Auto-detects build path from JSON name:
    *_MC*.json -> docs/mc/
    *_BASE*.json (or other) -> docs/base/
  Override with -DocsDir.

  With -Release: also copies the JSON + all reports to release/ as a
  finalized snapshot. Use this when a BASE or MC_BASE JSON is confirmed.

  Usage: .\build_report.ps1 -Path <provider.json>
         .\build_report.ps1 -Path <provider.json> -Release
         .\build_report.ps1 -Path <provider.json> -DocsDir <output-dir>
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$DocsDir,
    [switch]$Release
)

$ErrorActionPreference = "Stop"
$toolDir = $PSScriptRoot

$resolved = Resolve-Path $Path
$jsonDir = Split-Path $resolved -Parent
$jsonName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
$jsonFile = Split-Path $resolved -Leaf

if (-not $DocsDir) {
    $docsRoot = Join-Path $jsonDir "docs"
    if ($jsonName -match '_MC') {
        $DocsDir = Join-Path $docsRoot "mc"
    } else {
        $DocsDir = Join-Path $docsRoot "base"
    }
}
if (-not (Test-Path $DocsDir)) {
    New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

$stepCount = if ($Release) { 6 } else { 5 }

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Build Report -- $jsonName" -ForegroundColor Cyan
Write-Host "  Generated: $timestamp" -ForegroundColor Cyan
if ($Release) {
    Write-Host "  Mode: RELEASE (will bundle to release/)" -ForegroundColor Magenta
}
Write-Host "================================================================" -ForegroundColor Cyan

$header = @"
================================================================
  Build Report: $jsonName
  Source: $jsonFile
  Generated: $timestamp
================================================================

"@

# --- 1. Validator ---
Write-Host ""
Write-Host "  [1/$stepCount] Running validator..." -ForegroundColor Yellow
$validatorPath = Join-Path $toolDir "connectcic-validator\validate.ps1"
$validatorOut = & powershell -ExecutionPolicy Bypass -File $validatorPath -Path $resolved 2>&1 | Out-String
$validatorFile = Join-Path $DocsDir "VALIDATOR_REPORT_$jsonName.txt"
($header + "VALIDATOR RESULTS`n================`n`n" + $validatorOut) | Out-File -FilePath $validatorFile -Encoding utf8
Write-Host "  [1/$stepCount] Saved: $validatorFile" -ForegroundColor Green

# --- 2. Layout Renderer ---
Write-Host ""
Write-Host "  [2/$stepCount] Running layout renderer..." -ForegroundColor Yellow
$rendererPath = Join-Path $toolDir "render_layout.ps1"
$layoutOut = & powershell -ExecutionPolicy Bypass -File $rendererPath -Path $resolved -Summary 2>&1 | Out-String
$layoutDetail = & powershell -ExecutionPolicy Bypass -File $rendererPath -Path $resolved -Variant default 2>&1 | Out-String
$layoutFile = Join-Path $DocsDir "LAYOUT_REPORT_$jsonName.txt"
($header + "LAYOUT SUMMARY`n==============`n`n" + $layoutOut + "`n`nLAYOUT DETAIL`n=============`n`n" + $layoutDetail) | Out-File -FilePath $layoutFile -Encoding utf8
Write-Host "  [2/$stepCount] Saved: $layoutFile" -ForegroundColor Green

# --- 3. Query Simulator ---
Write-Host ""
Write-Host "  [3/$stepCount] Running query simulator..." -ForegroundColor Yellow
$queryPath = Join-Path $toolDir "test_commsys.ps1"
$queryOut = & powershell -ExecutionPolicy Bypass -File $queryPath -Path $resolved 2>&1 | Out-String
$queryFile = Join-Path $DocsDir "QUERY_REPORT_$jsonName.txt"
($header + "QUERY SIMULATION`n================`n`n" + $queryOut) | Out-File -FilePath $queryFile -Encoding utf8
Write-Host "  [3/$stepCount] Saved: $queryFile" -ForegroundColor Green

# --- 4. Picklist Scanner ---
Write-Host ""
Write-Host "  [4/$stepCount] Running picklist scanner..." -ForegroundColor Yellow
$picklistPath = Join-Path $toolDir "report_picklists.ps1"
$picklistFile = Join-Path $DocsDir "PICKLIST_REPORT_$jsonName.txt"
& powershell -ExecutionPolicy Bypass -File $picklistPath -Path $resolved -OutFile $picklistFile 2>&1 | Out-Null
Write-Host "  [4/$stepCount] Saved: $picklistFile" -ForegroundColor Green

# --- 5. HTML Layout Render ---
Write-Host ""
Write-Host "  [5/$stepCount] Rendering HTML layout..." -ForegroundColor Yellow
$htmlRendererPath = Join-Path $toolDir "render_html.ps1"
$htmlFile = Join-Path $DocsDir "LAYOUT_$jsonName.html"
& powershell -ExecutionPolicy Bypass -File $htmlRendererPath -Path $resolved -OutFile $htmlFile 2>&1 | Out-Null
Write-Host "  [5/$stepCount] Saved: $htmlFile" -ForegroundColor Green

# --- 6. Release Bundle (optional) ---
if ($Release) {
    Write-Host ""
    Write-Host "  [6/$stepCount] Building release bundle..." -ForegroundColor Yellow

    $releaseDir = Join-Path $jsonDir "release"
    if (-not (Test-Path $releaseDir)) {
        New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    }

    Copy-Item $resolved (Join-Path $releaseDir $jsonFile) -Force
    Copy-Item $validatorFile (Join-Path $releaseDir "VALIDATOR_REPORT_$jsonName.txt") -Force
    Copy-Item $layoutFile (Join-Path $releaseDir "LAYOUT_REPORT_$jsonName.txt") -Force
    Copy-Item $queryFile (Join-Path $releaseDir "QUERY_REPORT_$jsonName.txt") -Force
    Copy-Item $picklistFile (Join-Path $releaseDir "PICKLIST_REPORT_$jsonName.txt") -Force
    Copy-Item $htmlFile (Join-Path $releaseDir "LAYOUT_$jsonName.html") -Force

    $releaseCount = (Get-ChildItem $releaseDir -File).Count
    Write-Host "  [6/$stepCount] Release bundle: $releaseDir ($releaseCount files)" -ForegroundColor Green
}

# --- Summary ---
$fires = ([regex]::Matches($queryOut, '\[FIRES\]')).Count
$skips = ([regex]::Matches($queryOut, '\[SKIP\]')).Count
$pass = ([regex]::Matches($validatorOut, '\[PASS\]')).Count
$fail = ([regex]::Matches($validatorOut, '\[FAIL\]')).Count
$warn = ([regex]::Matches($validatorOut, '\[WARN\]')).Count

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  REPORT COMPLETE" -ForegroundColor Green
Write-Host "  Validator: $pass PASS / $fail FAIL / $warn WARN" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "  Queries:   $fires FIRE / $skips SKIP" -ForegroundColor $(if ($fires -gt 0) { "Green" } else { "Yellow" })
Write-Host "  Reports:   $DocsDir" -ForegroundColor Gray
if ($Release) {
    Write-Host "  Release:   $(Join-Path $jsonDir 'release')" -ForegroundColor Magenta
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
