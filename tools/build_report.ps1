<#
  build_report.ps1 -- Generate layout + query reports for a provider JSON
  Runs validator, renderer, query simulator, and picklist scanner.
  Auto-detects build path from JSON name:
    <PROVIDER>.json -> docs/
    *_MC*.json -> docs/mc/ (legacy)
    *_BASE*.json -> docs/base/ (legacy)
  Override with -DocsDir.

  Usage: .\build_report.ps1 -Path <provider.json>
         .\build_report.ps1 -Path <provider.json> -DocsDir <output-dir>
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$DocsDir
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
    } elseif ($jsonName -match '_BASE') {
        $DocsDir = Join-Path $docsRoot "base"
    } else {
        $DocsDir = $docsRoot
    }
}
if (-not (Test-Path $DocsDir)) {
    New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

$stepCount = 10

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Build Report -- $jsonName" -ForegroundColor Cyan
Write-Host "  Generated: $timestamp" -ForegroundColor Cyan
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
        $bannedHits = Select-String -Path $script.FullName -Pattern "LicensePlateNumberIn" | Where-Object { $_.Line -notmatch '-replace' -and $_.Line -notmatch '^\s*#' -and $_.Line -notmatch 'Patch\s*8' -and $_.Line -notmatch "'\s*=" }
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
    $cadVariant = if ($jsonName -match '_BASE') { 'BASE' } else { 'MC' }
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

# --- 9. Test Matrix ---
Write-Host ""
Write-Host "  [9/$stepCount] Generating test matrix..." -ForegroundColor Yellow
$testMatrixPath = Join-Path $toolDir "generate_test_matrix.ps1"
if (Test-Path $testMatrixPath) {
    $providerBase = $jsonName -replace '_(BASE|MC)$', ''
    $matrixFileName = "${providerBase}_TEST_MATRIX.txt"
    $matrixFile = Join-Path (Join-Path $jsonDir "docs") $matrixFileName
    $matrixOut = & powershell -ExecutionPolicy Bypass -File $testMatrixPath -Path $resolved -OutFile $matrixFile 2>&1 | Out-String
    if ($matrixOut -match '(\d+)/(\d+) combos') {
        $matCov = $Matches[0]
        Write-Host "  [9/$stepCount] Saved: $matrixFile ($matCov)" -ForegroundColor Green
    } else {
        Write-Host "  [9/$stepCount] Saved: $matrixFile" -ForegroundColor Green
    }
} else {
    Write-Host "  [9/$stepCount] SKIPPED (generate_test_matrix.ps1 not found)" -ForegroundColor Gray
}

# --- 10. Test Conductor (automated test validation) ---
Write-Host ""
Write-Host "  [10/$stepCount] Running test conductor..." -ForegroundColor Yellow
$testConductorPath = Join-Path $toolDir "run_test_matrix.ps1"
if ((Test-Path $testConductorPath) -and (Test-Path $matrixFile)) {
    $conductorOut = & powershell -ExecutionPolicy Bypass -File $testConductorPath -Path $resolved -Matrix $matrixFile 2>&1 | Out-String
    $conductorFile = Join-Path $DocsDir "TEST_VALIDATION_$jsonName.txt"
    ($header + "TEST CONDUCTOR RESULTS`n=====================`n`n" + $conductorOut) | Out-File -FilePath $conductorFile -Encoding utf8
    if ($conductorOut -match '(\d+)/(\d+) PASS, (\d+) FAIL') {
        $tcPass = $Matches[1]; $tcTotal = $Matches[2]; $tcFail = $Matches[3]
        if ([int]$tcFail -gt 0) {
            Write-Host "  [10/$stepCount] TEST CONDUCTOR: $tcPass/$tcTotal PASS, $tcFail FAIL -- see $conductorFile" -ForegroundColor Red
        } else {
            Write-Host "  [10/$stepCount] Saved: $conductorFile ($tcPass/$tcTotal PASS)" -ForegroundColor Green
        }
    } else {
        Write-Host "  [10/$stepCount] Saved: $conductorFile" -ForegroundColor Green
    }
} else {
    Write-Host "  [10/$stepCount] SKIPPED (run_test_matrix.ps1 or matrix not found)" -ForegroundColor Gray
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
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
