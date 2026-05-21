<#
  build_report.ps1 -- Generate layout + query reports for a provider JSON
  Runs validator, renderer, query simulator, and picklist scanner.
  Steps 1-9 run in PARALLEL (all read-only on JSON, independent outputs).
  Step 10 (test conductor) runs after step 9 completes.

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

# --- PRE. Build Script Lint (fast, runs before parallel batch) ---
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

        $yearHits = Select-String -Path $script.FullName -Pattern "initialValue\s*=\s*['""]?(20(?:2[4-9]|[3-9]\d))['""]?" | Where-Object { $_.Line -notmatch '\$currentYear' -and $_.Line -notmatch '^\s*#' }
        foreach ($hit in $yearHits) {
            $scriptWarns += "  [WARN] Line $($hit.LineNumber): Hardcoded PlateYear '$($hit.Matches[0].Groups[1].Value)' -- [FIX] Use `$currentYear instead"
            $lintWarnCount++
        }

        $bannedHits = Select-String -Path $script.FullName -Pattern "LicensePlateNumberIn" | Where-Object { $_.Line -notmatch '-replace' -and $_.Line -notmatch '^\s*#' -and $_.Line -notmatch 'Patch\s*8' -and $_.Line -notmatch "'\s*=" }
        foreach ($hit in $bannedHits) {
            $scriptWarns += "  [WARN] Line $($hit.LineNumber): LicensePlateNumberIn (banned) -- [FIX] Use licensePlateNumber"
            $lintWarnCount++
        }

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

# ══════════════════════════════════════════════════════════════════════════════
#  PARALLEL STEPS 1-9
# ══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  Launching steps 1-9 in parallel..." -ForegroundColor Yellow

$resolvedStr = $resolved.ToString()
$providerBase = $jsonName -replace '_(BASE|MC)$', ''
$matrixFileName = "${providerBase}_TEST_MATRIX.txt"
$matrixFile = Join-Path (Join-Path $jsonDir "docs") $matrixFileName
$cadVariant = if ($jsonName -match '_BASE') { 'BASE' } else { 'MC' }

$validatorFile = Join-Path $DocsDir "VALIDATOR_REPORT_$jsonName.txt"
$layoutFile    = Join-Path $DocsDir "LAYOUT_REPORT_$jsonName.txt"
$queryFile     = Join-Path $DocsDir "QUERY_REPORT_$jsonName.txt"
$picklistFile  = Join-Path $DocsDir "PICKLIST_REPORT_$jsonName.txt"
$htmlFile      = Join-Path $DocsDir "LAYOUT_$jsonName.html"
$verifyFile    = Join-Path $DocsDir "VERIFY_REPORT_$jsonName.txt"
$metadataFile  = Join-Path $DocsDir "METADATA_AUDIT_$jsonName.txt"
$cadFile       = Join-Path $DocsDir "CAD_AUDIT_$jsonName.txt"

$validatorPath   = Join-Path $toolDir "validate.ps1"
$rendererPath    = Join-Path $toolDir "render_layout.ps1"
$queryPath       = Join-Path $toolDir "test_commsys.ps1"
$picklistPath    = Join-Path $toolDir "report_picklists.ps1"
$htmlRendererPath = Join-Path $toolDir "render_html.ps1"
$verifyPath      = Join-Path $toolDir "verify_build.ps1"
$metadataPath    = Join-Path $toolDir "audit_metadata.ps1"
$cadPath         = Join-Path $toolDir "audit_cad.ps1"
$testMatrixPath  = Join-Path $toolDir "generate_test_matrix.ps1"

$jobs = @{}

# Step 1: Validator
$jobs[1] = Start-Job -ScriptBlock {
    param($tool, $json)
    & powershell -ExecutionPolicy Bypass -File $tool -Path $json 2>&1 | Out-String
} -ArgumentList $validatorPath, $resolvedStr

# Step 2: Layout Renderer (summary + detail in one job)
$jobs[2] = Start-Job -ScriptBlock {
    param($tool, $json)
    $summary = & powershell -ExecutionPolicy Bypass -File $tool -Path $json -Summary 2>&1 | Out-String
    $detail  = & powershell -ExecutionPolicy Bypass -File $tool -Path $json -Variant default 2>&1 | Out-String
    "$summary`n`nLAYOUT DETAIL`n=============`n`n$detail"
} -ArgumentList $rendererPath, $resolvedStr

# Step 3: Query Simulator
$jobs[3] = Start-Job -ScriptBlock {
    param($tool, $json)
    & powershell -ExecutionPolicy Bypass -File $tool -Path $json 2>&1 | Out-String
} -ArgumentList $queryPath, $resolvedStr

# Step 4: Picklist Scanner
$jobs[4] = Start-Job -ScriptBlock {
    param($tool, $json, $outFile)
    & powershell -ExecutionPolicy Bypass -File $tool -Path $json -OutFile $outFile 2>&1 | Out-String
    "SAVED"
} -ArgumentList $picklistPath, $resolvedStr, $picklistFile

# Step 5: HTML Layout Render
$jobs[5] = Start-Job -ScriptBlock {
    param($tool, $json, $outFile)
    & powershell -ExecutionPolicy Bypass -File $tool -Path $json -OutFile $outFile 2>&1 | Out-String
    "SAVED"
} -ArgumentList $htmlRendererPath, $resolvedStr, $htmlFile

# Step 6: Post-Build Verification
$jobs[6] = Start-Job -ScriptBlock {
    param($tool, $json)
    & powershell -ExecutionPolicy Bypass -File $tool -Path $json 2>&1 | Out-String
} -ArgumentList $verifyPath, $resolvedStr

# Step 7: Metadata Audit
if (Test-Path $metadataPath) {
    $jobs[7] = Start-Job -ScriptBlock {
        param($tool, $json)
        & powershell -ExecutionPolicy Bypass -File $tool -Path $json 2>&1 | Out-String
    } -ArgumentList $metadataPath, $resolvedStr
}

# Step 8: CAD Audit
if (Test-Path $cadPath) {
    $jobs[8] = Start-Job -ScriptBlock {
        param($tool, $json, $variant)
        & powershell -ExecutionPolicy Bypass -File $tool -Path $json -Variant $variant 2>&1 | Out-String
    } -ArgumentList $cadPath, $resolvedStr, $cadVariant
}

# Step 9: Test Matrix
if (Test-Path $testMatrixPath) {
    $jobs[9] = Start-Job -ScriptBlock {
        param($tool, $json, $outFile)
        & powershell -ExecutionPolicy Bypass -File $tool -Path $json -OutFile $outFile 2>&1 | Out-String
    } -ArgumentList $testMatrixPath, $resolvedStr, $matrixFile
}

# Wait for all jobs to complete (5 minute timeout)
$allJobs = $jobs.Values | Where-Object { $_ }
$allJobs | Wait-Job -Timeout 300 | Out-Null

# ══════════════════════════════════════════════════════════════════════════════
#  COLLECT RESULTS (in step order for deterministic output)
# ══════════════════════════════════════════════════════════════════════════════

$outputs = @{}
$verifyFails = 0

foreach ($step in (1..9)) {
    if (-not $jobs[$step]) { continue }
    $job = $jobs[$step]
    if ($job.State -eq 'Failed') {
        $outputs[$step] = "[ERROR] Step $step job failed: $($job.ChildJobs[0].JobStateInfo.Reason)"
    } else {
        $outputs[$step] = Receive-Job $job
    }
    Remove-Job $job -Force
}

# --- Step 1: Validator ---
Write-Host ""
$validatorOut = $outputs[1]
($header + "VALIDATOR RESULTS`n================`n`n" + $validatorOut) | Out-File -FilePath $validatorFile -Encoding utf8
Write-Host "  [1/$stepCount] Saved: $validatorFile" -ForegroundColor Green

# --- Step 2: Layout ---
Write-Host ""
$layoutOut = $outputs[2]
($header + "LAYOUT SUMMARY`n==============`n`n" + $layoutOut) | Out-File -FilePath $layoutFile -Encoding utf8
Write-Host "  [2/$stepCount] Saved: $layoutFile" -ForegroundColor Green

# --- Step 3: Query Simulator ---
Write-Host ""
$queryOut = $outputs[3]
($header + "QUERY SIMULATION`n================`n`n" + $queryOut) | Out-File -FilePath $queryFile -Encoding utf8
Write-Host "  [3/$stepCount] Saved: $queryFile" -ForegroundColor Green

# --- Step 4: Picklist ---
Write-Host ""
Write-Host "  [4/$stepCount] Saved: $picklistFile" -ForegroundColor Green

# --- Step 5: HTML ---
Write-Host ""
Write-Host "  [5/$stepCount] Saved: $htmlFile" -ForegroundColor Green

# --- Step 6: Verify ---
Write-Host ""
$verifyOut = $outputs[6]
($header + "POST-BUILD VERIFICATION`n=======================`n`n" + $verifyOut) | Out-File -FilePath $verifyFile -Encoding utf8
$verifyFails = ([regex]::Matches($verifyOut, '\[FAIL\]')).Count
if ($verifyFails -gt 0) {
    Write-Host "  [6/$stepCount] VERIFICATION FAILED ($verifyFails failures) -- see $verifyFile" -ForegroundColor Red
} else {
    Write-Host "  [6/$stepCount] Saved: $verifyFile" -ForegroundColor Green
}

# --- Step 7: Metadata Audit ---
Write-Host ""
if ($outputs[7]) {
    $metadataOut = $outputs[7]
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

# --- Step 8: CAD Audit ---
Write-Host ""
if ($outputs[8]) {
    $cadOut = $outputs[8]
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

# --- Step 9: Test Matrix ---
Write-Host ""
if ($outputs[9]) {
    $matrixOut = $outputs[9]
    if ($matrixOut -match '(\d+)/(\d+) combos') {
        $matCov = $Matches[0]
        Write-Host "  [9/$stepCount] Saved: $matrixFile ($matCov)" -ForegroundColor Green
    } else {
        Write-Host "  [9/$stepCount] Saved: $matrixFile" -ForegroundColor Green
    }
} else {
    Write-Host "  [9/$stepCount] SKIPPED (generate_test_matrix.ps1 not found)" -ForegroundColor Gray
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 10: Test Conductor (sequential -- depends on step 9 output)
# ══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  [10/$stepCount] Running test conductor..." -ForegroundColor Yellow
$testConductorPath = Join-Path $toolDir "run_test_matrix.ps1"
if ((Test-Path $testConductorPath) -and (Test-Path $matrixFile)) {
    $conductorOut = & powershell -ExecutionPolicy Bypass -File $testConductorPath -Path $resolvedStr -Matrix $matrixFile 2>&1 | Out-String
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
