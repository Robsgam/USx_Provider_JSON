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
    [switch]$Release,
    [switch]$Force
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

$stepCount = if ($Release) { 9 } else { 8 }

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

# --- PRE. Build Script Lint ---
Write-Host ""
Write-Host "  [PRE] Checking build scripts..." -ForegroundColor Yellow
$scriptsDir = Join-Path $jsonDir "scripts"
$lintWarnings = @()
$lintWarnCount = 0
if (Test-Path $scriptsDir) {
    $buildScripts = Get-ChildItem -Path $scriptsDir -Filter "build_*.ps1" -File
    if ($buildScripts.Count -eq 0) {
        $lintWarnings += "[INFO] No build_*.ps1 scripts found in $scriptsDir"
    }
    foreach ($script in $buildScripts) {
        $scriptName = $script.Name
        $scriptWarns = @()

        # Hardcoded PlateYear (4-digit year literal, not $currentYear)
        $yearHits = Select-String -Path $script.FullName -Pattern "initialValue\s*=\s*['""]?(20(?:2[4-9]|[3-9]\d))['""]?" | Where-Object { $_.Line -notmatch '\$currentYear' -and $_.Line -notmatch '^\s*#' }
        foreach ($hit in $yearHits) {
            $scriptWarns += "  [WARN] Line $($hit.LineNumber): Hardcoded PlateYear '$($hit.Matches[0].Groups[1].Value)' -- [FIX] Use `$currentYear instead"
            $lintWarnCount++
        }

        # LicensePlateNumberIn (banned -- not in Patch 8 rename context)
        $bannedHits = Select-String -Path $script.FullName -Pattern "LicensePlateNumberIn" | Where-Object { $_.Line -notmatch '-replace' -and $_.Line -notmatch '^\s*#' -and $_.Line -notmatch 'Patch\s*8' }
        foreach ($hit in $bannedHits) {
            $scriptWarns += "  [WARN] Line $($hit.LineNumber): LicensePlateNumberIn (banned) -- [FIX] Use licensePlateNumber"
            $lintWarnCount++
        }

        # AP #23: autoSelect as string instead of boolean
        $ap23Hits = Select-String -Path $script.FullName -Pattern "autoSelect\s*=\s*['""](?:true|false)['""]" | Where-Object { $_.Line -notmatch '^\s*#' }
        foreach ($hit in $ap23Hits) {
            $scriptWarns += "  [WARN] Line $($hit.LineNumber): autoSelect as string (AP #23) -- [FIX] Use `$true/`$false (boolean)"
            $lintWarnCount++
        }

        if ($scriptWarns.Count -gt 0) {
            $lintWarnings += "${scriptName}: $($scriptWarns.Count) warning(s)"
            $lintWarnings += $scriptWarns
        } else {
            $lintWarnings += "${scriptName}: CLEAN"
        }
    }
} else {
    $lintWarnings += "[INFO] No scripts/ directory found at $scriptsDir"
}
$lintFile = Join-Path $DocsDir "LINT_REPORT_$jsonName.txt"
$lintBody = ($lintWarnings -join "`n")
($header + "BUILD SCRIPT LINT`n=================`n`n" + $lintBody + "`n") | Out-File -FilePath $lintFile -Encoding utf8
if ($lintWarnCount -gt 0) {
    Write-Host "  [PRE] $lintWarnCount warning(s) found -- see $lintFile" -ForegroundColor Red
} else {
    Write-Host "  [PRE] CLEAN -- $lintFile" -ForegroundColor Green
}

# --- 1. Validator ---
Write-Host ""
Write-Host "  [1/$stepCount] Running validator..." -ForegroundColor Yellow
$validatorPath = Join-Path $toolDir "validate.ps1"
$validatorArgs = @('-ExecutionPolicy','Bypass','-File',$validatorPath,'-Path',$resolved)
if ($Force) { $validatorArgs += '-Force' }
$validatorOut = & powershell @validatorArgs 2>&1 | Out-String
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

# --- 6. Post-Build Verification ---
Write-Host ""
Write-Host "  [6/$stepCount] Running post-build verification..." -ForegroundColor Yellow
$verifyPath = Join-Path $toolDir "verify_build.ps1"
$verifyOut = & powershell -ExecutionPolicy Bypass -File $verifyPath -Path $resolved 2>&1 | Out-String
$verifyFile = Join-Path $DocsDir "VERIFY_REPORT_$jsonName.txt"
($header + "POST-BUILD VERIFICATION`n=======================`n`n" + $verifyOut) | Out-File -FilePath $verifyFile -Encoding utf8
$verifyFails = ([regex]::Matches($verifyOut, '\[FAIL\]')).Count
if ($verifyFails -gt 0) {
    Write-Host "  [6/$stepCount] VERIFICATION FAILED ($verifyFails failures) -- see $verifyFile" -ForegroundColor Red
} else {
    Write-Host "  [6/$stepCount] Saved: $verifyFile" -ForegroundColor Green
}

# --- 7. Metadata Audit (XML vs JSON) ---
Write-Host ""
Write-Host "  [7/$stepCount] Running metadata audit..." -ForegroundColor Yellow
$metadataPath = Join-Path $toolDir "audit_metadata.ps1"
$metadataFile = Join-Path $DocsDir "METADATA_AUDIT_$jsonName.txt"
if (Test-Path $metadataPath) {
    $metadataOut = & powershell -ExecutionPolicy Bypass -File $metadataPath -Path $resolved 2>&1 | Out-String
    ($header + "METADATA AUDIT`n==============`n`n" + $metadataOut) | Out-File -FilePath $metadataFile -Encoding utf8
    $metadataFails = ([regex]::Matches($metadataOut, '\[FAIL\]')).Count
    if ($metadataFails -gt 0) {
        Write-Host "  [7/$stepCount] METADATA AUDIT: $metadataFails issues -- see $metadataFile" -ForegroundColor Yellow
    } else {
        Write-Host "  [7/$stepCount] Saved: $metadataFile" -ForegroundColor Green
    }
} else {
    Write-Host "  [7/$stepCount] SKIPPED (audit_metadata.ps1 not found)" -ForegroundColor Gray
}

# --- 8. CAD Audit ---
Write-Host ""
Write-Host "  [8/$stepCount] Running CAD audit..." -ForegroundColor Yellow
$cadPath = Join-Path $toolDir "audit_cad.ps1"
$cadFile = Join-Path $DocsDir "CAD_AUDIT_$jsonName.txt"
if (Test-Path $cadPath) {
    $cadVariant = if ($jsonName -match '_MC') { 'MC' } else { 'BASE' }
    $cadOut = & powershell -ExecutionPolicy Bypass -File $cadPath -Path $resolved -Variant $cadVariant 2>&1 | Out-String
    ($header + "CAD AUDIT`n=========`n`n" + $cadOut) | Out-File -FilePath $cadFile -Encoding utf8
    $cadFails = ([regex]::Matches($cadOut, '\[FAIL\]')).Count
    if ($cadFails -gt 0) {
        Write-Host "  [8/$stepCount] CAD AUDIT: $cadFails issues -- see $cadFile" -ForegroundColor Yellow
    } else {
        Write-Host "  [8/$stepCount] Saved: $cadFile" -ForegroundColor Green
    }
} else {
    Write-Host "  [8/$stepCount] SKIPPED (audit_cad.ps1 not found)" -ForegroundColor Gray
}

# --- 9. Release Bundle (optional) ---
if ($Release) {
    Write-Host ""
    Write-Host "  [9/$stepCount] Building release bundle..." -ForegroundColor Yellow

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
    Copy-Item $verifyFile (Join-Path $releaseDir "VERIFY_REPORT_$jsonName.txt") -Force
    if (Test-Path $metadataFile) {
        Copy-Item $metadataFile (Join-Path $releaseDir "METADATA_AUDIT_$jsonName.txt") -Force
    }
    if (Test-Path $cadFile) {
        Copy-Item $cadFile (Join-Path $releaseDir "CAD_AUDIT_$jsonName.txt") -Force
    }
    if (Test-Path $lintFile) {
        Copy-Item $lintFile (Join-Path $releaseDir "LINT_REPORT_$jsonName.txt") -Force
    }

    $releaseCount = (Get-ChildItem $releaseDir -File).Count
    Write-Host "  [9/$stepCount] Release bundle: $releaseDir ($releaseCount files)" -ForegroundColor Green
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
Write-Host "  Lint:      $(if ($lintWarnCount -gt 0) { "$lintWarnCount WARN" } else { "CLEAN" })" -ForegroundColor $(if ($lintWarnCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Validator: $pass PASS / $fail FAIL / $warn WARN" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "  Verify:    $(if ($verifyFails -gt 0) { "$verifyFails FAIL" } else { "CLEAN" })" -ForegroundColor $(if ($verifyFails -gt 0) { "Red" } else { "Green" })
Write-Host "  Queries:   $fires FIRE / $skips SKIP" -ForegroundColor $(if ($fires -gt 0) { "Green" } else { "Yellow" })
Write-Host "  Reports:   $DocsDir" -ForegroundColor Gray
if ($Release) {
    Write-Host "  Release:   $(Join-Path $jsonDir 'release')" -ForegroundColor Magenta
}
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
