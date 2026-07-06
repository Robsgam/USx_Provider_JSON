<#
  build_report.ps1 -- Generate layout + query reports for a provider JSON
  Runs validator, renderer, query simulator, and picklist scanner.
  Steps 1-9 run in PARALLEL (all read-only on JSON, independent outputs).
  Step 10 (test conductor) runs after step 9 completes.

  Auto-detects build path from JSON name:
    <PROVIDER>.json -> docs/{tracking,reports,reference,deliverables}/ (2026-07-01 reorg
      pilot -- see _resolve_docs_path.ps1; falls back to flat docs/ for any provider that
      hasn't migrated yet, which is every provider except NJ_NJCJIS today)
    *_MC*.json -> docs/mc/ (legacy, unaffected by the reorg)
    *_BASE*.json -> docs/base/ (legacy, unaffected by the reorg)
  Override with -DocsDir (forces ALL categories to one flat directory, bypassing the reorg).

  Usage: .\build_report.ps1 -Path <provider.json>
         .\build_report.ps1 -Path <provider.json> -DocsDir <output-dir>
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$DocsDir,
    # Opt-in: also run the 5 advisory/on-demand report generators that enforce.ps1 never
    # reads back (LINT_REPORT, RESPONSE_SIMULATION, LABEL_REVIEW, OFFICER_GUIDE, TEST_VALIDATION).
    # Demoted from the automatic run 2026-07-06 (waste-reduction pass) -- they cost build time
    # on every build/rebuild but nothing gates on their output. Run standalone any time via the
    # underlying tool directly, or pass this switch to regenerate all 5 in one build_report run.
    [switch]$IncludeExtended
)

$ErrorActionPreference = "Stop"
$toolDir = $PSScriptRoot

$resolved = Resolve-Path $Path
$jsonDir = Split-Path $resolved -Parent
$jsonName = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$', ''
$jsonFile = Split-Path $resolved -Leaf

$docsDirWasExplicit = $PSBoundParameters.ContainsKey('DocsDir')
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

# Category dirs (2026-07-01 docs/ reorg pilot, NJ_NJCJIS first -- see _resolve_docs_path.ps1).
# Only participates for the modern flat-docs/ single-JSON path with no explicit -DocsDir
# override; legacy MC/BASE variants and any override keep everything collapsed into
# $DocsDir, unchanged. Get-DocsCategoryDir itself falls back to flat docs/ for any
# provider that hasn't migrated (all 20 except NJ today), so this is a no-op for them.
$isModernSingleJson = ($jsonName -notmatch '_MC' -and $jsonName -notmatch '_BASE')
if ($docsDirWasExplicit -or -not $isModernSingleJson) {
    $TrackingDir = $DocsDir; $ReportsDir = $DocsDir; $ReferenceDir = $DocsDir; $DeliverablesDir = $DocsDir
} else {
    . (Join-Path $toolDir '_resolve_docs_path.ps1')
    $TrackingDir     = Get-DocsCategoryDir $jsonDir 'tracking'
    $ReportsDir      = Get-DocsCategoryDir $jsonDir 'reports'
    $ReferenceDir    = Get-DocsCategoryDir $jsonDir 'reference'
    $DeliverablesDir = Get-DocsCategoryDir $jsonDir 'deliverables'
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

$stepCount = 15

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

# --- PRE. Build Script Lint (delegates to lint_build_scripts.ps1 -- single source of truth,
#     broader checks than the old inline set). Run as a CHILD PROCESS: lint_build_scripts ends
#     in exit 0/1, which would terminate this script if called with & in-session.
#     Advisory only -- nothing in enforce.ps1 reads LINT_REPORT -- so it's opt-in (-IncludeExtended).
#     Run tools/lint_build_scripts.ps1 directly any time for an on-demand check. ---
$lintWarnCount = 0
$lintFailCount = 0
if ($IncludeExtended) {
    Write-Host ""
    Write-Host "  [PRE] Checking build scripts..." -ForegroundColor Yellow
    $scriptsDir = Join-Path $jsonDir "scripts"
    $lintFile = Join-Path $ReportsDir "LINT_REPORT_$jsonName.txt"
    if (Test-Path $scriptsDir) {
        $linter = Join-Path $PSScriptRoot "lint_build_scripts.ps1"
        $lintOut = powershell.exe -ExecutionPolicy Bypass -File $linter -Path $scriptsDir -OutFile $lintFile 2>&1 | Out-String
        $m = [regex]::Match($lintOut, '(\d+)\s+warnings\s*\|\s*(\d+)\s+failures')
        $lintWarnCount = if ($m.Success) { [int]$m.Groups[1].Value } else { 0 }
        $lintFailCount = if ($m.Success) { [int]$m.Groups[2].Value } else { 0 }
        if ($lintWarnCount -gt 0 -or $lintFailCount -gt 0) {
            Write-Host "  [PRE] $lintWarnCount warning(s), $lintFailCount failure(s) -- see $lintFile" -ForegroundColor Red
        } else {
            Write-Host "  [PRE] CLEAN -- $lintFile" -ForegroundColor Green
        }
    } else {
        ($header + "BUILD SCRIPT LINT`n=================`n`nNo scripts/ directory found at $scriptsDir`n") | Out-File -FilePath $lintFile -Encoding utf8
        Write-Host "  [PRE] No scripts/ directory -- $lintFile" -ForegroundColor Gray
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PARALLEL STEPS 1-9
# ══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  Launching steps 1-9 in parallel..." -ForegroundColor Yellow

$resolvedStr = $resolved.ToString()
$providerBase = $jsonName -replace '_(BASE|MC)$', ''
$matrixFileName = "${providerBase}_TEST_MATRIX.txt"
$matrixFile = Join-Path $ReportsDir $matrixFileName
$cadVariant = if ($jsonName -match '_BASE') { 'BASE' } else { 'MC' }

# Auto-detect casing convention so verify_build's camelCase check (CHECK 5) actually
# runs for camelCase providers instead of being silently skipped (finding I). PascalCase
# USx-native providers (NJ/FL/HI/TX) are Pascal BY DESIGN -- enabling -CamelCase there
# would FAIL every field (false positive on known-good), so we only pass it when the
# entity fieldIds are predominantly lowercase-first (a camelCase provider).
$useCamelCase = $false
try {
    $detectJson = Get-Content $resolvedStr -Raw -Encoding UTF8 | ConvertFrom-Json
    $entCfgs = ($detectJson.bundles | Where-Object { $_.name -eq 'ENTITIES' }).configurations |
        Where-Object { $_.type -eq 'QUERYINPUTFORM' }
    $fids = @()
    foreach ($qif in $entCfgs) {
        $lay = $qif.layout.default
        if (-not $lay) { continue }
        foreach ($np in ($lay | Get-Member -MemberType NoteProperty)) {
            $node = $lay.($np.Name)
            if ($node.type.resolvedName -in @('FormInput','FormSelect','FormDate','FormDateInput') -and $node.props.fieldId) {
                $fids += [string]$node.props.fieldId
            }
        }
    }
    $fids = $fids | Where-Object { $_ } | Select-Object -Unique
    if ($fids.Count -gt 0) {
        $lower = @($fids | Where-Object { $_ -cmatch '^[a-z]' }).Count
        if (($lower / [double]$fids.Count) -ge 0.6) { $useCamelCase = $true }
    }
} catch { $useCamelCase = $false }
Write-Host "  Casing convention: $(if ($useCamelCase) { 'camelCase (CHECK 5 enabled)' } else { 'PascalCase (CHECK 5 N/A)' })" -ForegroundColor Gray

$validatorFile  = Join-Path $ReportsDir "VALIDATOR_REPORT_$jsonName.txt"
$respSimFile    = Join-Path $ReportsDir "RESPONSE_SIMULATION_$jsonName.txt"
$layoutFile    = Join-Path $ReportsDir "LAYOUT_REPORT_$jsonName.txt"
$queryFile     = Join-Path $ReportsDir "QUERY_REPORT_$jsonName.txt"
$picklistFile  = Join-Path $ReportsDir "PICKLIST_REPORT_$jsonName.txt"
$htmlFile      = Join-Path $ReportsDir "LAYOUT_$jsonName.html"
$verifyFile    = Join-Path $ReportsDir "VERIFY_REPORT_$jsonName.txt"
$metadataFile  = Join-Path $ReportsDir "METADATA_AUDIT_$jsonName.txt"
$cadFile       = Join-Path $ReportsDir "CAD_AUDIT_$jsonName.txt"

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

# Step 6: Post-Build Verification (pass -CamelCase only for camelCase providers)
$jobs[6] = Start-Job -ScriptBlock {
    param($tool, $json, $camel)
    if ($camel) { & powershell -ExecutionPolicy Bypass -File $tool -Path $json -CamelCase 2>&1 | Out-String }
    else        { & powershell -ExecutionPolicy Bypass -File $tool -Path $json 2>&1 | Out-String }
} -ArgumentList $verifyPath, $resolvedStr, $useCamelCase

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

# Step 9: Test Matrix -- single all-or-nothing full pass (tiers removed 2026-07-01)
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
$verifyWarns = ([regex]::Matches($verifyOut, '\[WARN\]')).Count
if ($verifyFails -gt 0) {
    Write-Host "  [6/$stepCount] VERIFICATION FAILED ($verifyFails failures, $verifyWarns warnings) -- see $verifyFile" -ForegroundColor Red
} elseif ($verifyWarns -gt 0) {
    Write-Host "  [6/$stepCount] VERIFICATION WARNINGS ($verifyWarns) -- see $verifyFile" -ForegroundColor Yellow
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
#  Advisory only -- TEST_VALIDATION is not read by enforce.ps1 (TEST_MATRIX freshness, the
#  gated artifact, comes from step 9 above, unaffected). Opt-in via -IncludeExtended; run
#  tools/run_test_matrix.ps1 directly any time for an on-demand check.
# ══════════════════════════════════════════════════════════════════════════════

if ($IncludeExtended) {
Write-Host ""
Write-Host "  [10/$stepCount] Running test conductor..." -ForegroundColor Yellow
$testConductorPath = Join-Path $toolDir "run_test_matrix.ps1"
if ((Test-Path $testConductorPath) -and (Test-Path $matrixFile)) {
    $conductorOut = & powershell -ExecutionPolicy Bypass -File $testConductorPath -Path $resolvedStr -Matrix $matrixFile 2>&1 | Out-String
    $conductorFile = Join-Path $ReportsDir "TEST_VALIDATION_$jsonName.txt"
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
} else {
    Write-Host ""
    Write-Host "  [10/$stepCount] SKIPPED (advisory; pass -IncludeExtended to run)" -ForegroundColor Gray
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 11: Response Simulator (sequential -- QRDM inbound path + missing-field test)
#  Advisory only -- not read by enforce.ps1. Opt-in via -IncludeExtended; run
#  tools/simulate_response.ps1 directly any time for an on-demand check.
# ══════════════════════════════════════════════════════════════════════════════

$mapped = 0; $missing = 0; $unmapped = 0; $respSimRan = $false
if ($IncludeExtended) {
$respSimRan = $true
Write-Host ""
Write-Host "  [11/$stepCount] Running response simulator..." -ForegroundColor Yellow
$respSimPath = Join-Path $toolDir "simulate_response.ps1"
if (Test-Path $respSimPath) {
    $respSimOut = & powershell -ExecutionPolicy Bypass -File $respSimPath -Path $resolvedStr -RunEdgeCases 2>&1 | Out-String
    ($header + "RESPONSE SIMULATION`n==================`n`n" + $respSimOut) | Out-File -FilePath $respSimFile -Encoding utf8
    $mapped   = ([regex]::Matches($respSimOut, '\[MAPPED\]')).Count
    $missing  = ([regex]::Matches($respSimOut, '\[MISSING\]')).Count
    $unmapped = ([regex]::Matches($respSimOut, '\[UNMAPPED\]')).Count
    Write-Host "  [11/$stepCount] Saved: $respSimFile  (MAPPED=$mapped  MISSING=$missing  UNMAPPED=$unmapped)" -ForegroundColor Green
} else {
    Write-Host "  [11/$stepCount] SKIPPED (simulate_response.ps1 not found)" -ForegroundColor Gray
}
} else {
    Write-Host ""
    Write-Host "  [11/$stepCount] SKIPPED (advisory; pass -IncludeExtended to run)" -ForegroundColor Gray
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 12: Label Review (sequential -- advisory, does not fail the build)
#  Opt-in via -IncludeExtended; run tools/suggest_field_labels.ps1 directly any time.
# ══════════════════════════════════════════════════════════════════════════════

if ($IncludeExtended) {
Write-Host ""
Write-Host "  [12/$stepCount] Running label review..." -ForegroundColor Yellow
$labelReviewPath = Join-Path $toolDir "suggest_field_labels.ps1"
$labelReviewFile  = Join-Path $ReportsDir "LABEL_REVIEW_$jsonName.txt"
if (Test-Path $labelReviewPath) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $labelReviewPath -Path $resolvedStr -OutFile $labelReviewFile 2>&1 | Out-Null
    Write-Host "  [12/$stepCount] Saved: $labelReviewFile" -ForegroundColor Green
} else {
    Write-Host "  [12/$stepCount] SKIPPED (suggest_field_labels.ps1 not found)" -ForegroundColor Gray
}
} else {
    Write-Host ""
    Write-Host "  [12/$stepCount] SKIPPED (advisory; pass -IncludeExtended to run)" -ForegroundColor Gray
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 13: Officer Query Guide -- advisory deliverable, not read by enforce.ps1.
#  Opt-in via -IncludeExtended; run tools/render_officer_guide.ps1 directly any time.
# ══════════════════════════════════════════════════════════════════════════════

if ($IncludeExtended) {
Write-Host ""
Write-Host "  [13/$stepCount] Generating officer query guide..." -ForegroundColor Yellow
$officerGuidePath = Join-Path $toolDir "render_officer_guide.ps1"
$officerHtml = Join-Path $DeliverablesDir "OFFICER_GUIDE_$jsonName.html"
$officerPdf  = Join-Path $DeliverablesDir "OFFICER_GUIDE_$jsonName.pdf"
if (Test-Path $officerGuidePath) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $officerGuidePath -Path $resolvedStr -OutFile $officerHtml -PdfFile $officerPdf 2>&1 | Out-Null
    if (Test-Path $officerHtml) { Write-Host "  [13/$stepCount] Saved: $officerHtml" -ForegroundColor Green }
    else { Write-Host "  [13/$stepCount] Officer guide not produced (advisory)" -ForegroundColor Gray }
} else {
    Write-Host "  [13/$stepCount] SKIPPED (render_officer_guide.ps1 not found)" -ForegroundColor Gray
}
} else {
    Write-Host ""
    Write-Host "  [13/$stepCount] SKIPPED (advisory; pass -IncludeExtended to run)" -ForegroundColor Gray
}

# --- Summary ---
$fires = ([regex]::Matches($queryOut, '\[FIRES')).Count
$skips = ([regex]::Matches($queryOut, '\[SKIP\]')).Count
$pass = ([regex]::Matches($validatorOut, '\[PASS\]')).Count
$fail = ([regex]::Matches($validatorOut, '\[FAIL\]')).Count
$warn = ([regex]::Matches($validatorOut, '\[WARN\]')).Count

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  REPORT COMPLETE" -ForegroundColor Green
Write-Host "  Lint:      $(if ($lintWarnCount -gt 0) { "$lintWarnCount WARN" } else { "CLEAN" })" -ForegroundColor $(if ($lintWarnCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Validator: $pass PASS / $fail FAIL / $warn WARN" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "  Verify:    $(if ($verifyFails -gt 0) { "$verifyFails FAIL / $verifyWarns WARN" } elseif ($verifyWarns -gt 0) { "0 FAIL / $verifyWarns WARN" } else { "CLEAN" })" -ForegroundColor $(if ($verifyFails -gt 0) { "Red" } elseif ($verifyWarns -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Queries:   $fires FIRE / $skips SKIP" -ForegroundColor $(if ($fires -gt 0) { "Green" } else { "Yellow" })
Write-Host "  RespSim:   $(if ($respSimRan) { "MAPPED=$mapped  MISSING=$missing  UNMAPPED=$unmapped  (RESPONSE_SIMULATION_$jsonName.txt)" } else { "SKIPPED (advisory; pass -IncludeExtended to run)" })" -ForegroundColor $(if ($unmapped -gt 0) { "Red" } elseif ($missing -gt 0) { "Cyan" } else { "Green" })
Write-Host "  Reports:   $ReportsDir" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 14: Supported-query (devdoc) audit ──
Write-Host ""
Write-Host "  [14/$stepCount] Supported-query (devdoc) audit..." -ForegroundColor Yellow
$supportedQAPath = Join-Path $toolDir "audit_supported_queries.ps1"
$supportedQAFile = Join-Path $ReportsDir "SUPPORTED_QUERY_AUDIT_$jsonName.txt"
if (Test-Path $supportedQAPath) {
    & powershell -ExecutionPolicy Bypass -File $supportedQAPath -Path $resolvedStr -OutFile $supportedQAFile 2>&1 | Out-Null
    if (Test-Path $supportedQAFile) { Write-Host "  [14/$stepCount] Saved: $supportedQAFile" -ForegroundColor Green }
} else {
    Write-Host "  [14/$stepCount] SKIPPED (audit_supported_queries.ps1 not found)" -ForegroundColor Gray
}

# ── Step 15: Per-provider changelog (Markdown from BUILD_NOTES) ──
Write-Host ""
Write-Host "  [15/$stepCount] Generating changelog..." -ForegroundColor Yellow
$changelogToolPath = Join-Path $toolDir "generate_changelog.ps1"
$changelogFile = Join-Path $TrackingDir "CHANGELOG_$jsonName.md"
if (Test-Path $changelogToolPath) {
    & powershell -ExecutionPolicy Bypass -File $changelogToolPath -Path $resolvedStr -OutFile $changelogFile 2>&1 | Out-Null
    if (Test-Path $changelogFile) { Write-Host "  [15/$stepCount] Saved: $changelogFile" -ForegroundColor Green }
    else { Write-Host "  [15/$stepCount] Changelog not produced (advisory)" -ForegroundColor Gray }
} else {
    Write-Host "  [15/$stepCount] SKIPPED (generate_changelog.ps1 not found)" -ForegroundColor Gray
}

# ══════════════════════════════════════════════════════════════════════════════
#  BUILD MANIFEST -- tamper-evident integrity record consumed by enforce.ps1.
#  Records the SHA-256 of the JSON this run evaluated, plus the SHA-256 and live
#  check-count of every report enforce trusts. enforce recomputes these hashes
#  and refuses to score any report that does not match the current JSON (stale or
#  hand-edited reports FAIL instead of passing). See plan Workstream 0 (A/B/C).
# ══════════════════════════════════════════════════════════════════════════════
function Get-ReportCheckCount($path) {
    if (-not (Test-Path $path)) { return 0 }
    $t = [System.IO.File]::ReadAllText($path)
    # Count any real result marker; >0 distinguishes a report that ran from an
    # empty/contentless one. INFO included so a template-only / all-INFO report
    # (e.g. a provisional supported-query audit) is not mistaken for contentless.
    return ([regex]::Matches($t, '\[(PASS|FAIL|WARN|INFO)\]')).Count
}
$gatedReports = @($validatorFile, $verifyFile, $metadataFile, $cadFile, $supportedQAFile)
$reportEntries = [ordered]@{}
foreach ($rf in $gatedReports) {
    if (-not (Test-Path $rf)) { continue }
    $leaf = Split-Path $rf -Leaf
    $reportEntries[$leaf] = [ordered]@{
        sha256    = (Get-FileHash -Path $rf -Algorithm SHA256).Hash
        checksRun = (Get-ReportCheckCount $rf)
    }
}
$manifest = [ordered]@{
    sourceFile   = $jsonFile
    sourceSha256 = (Get-FileHash -Path $resolvedStr -Algorithm SHA256).Hash
    generatedAt  = $timestamp
    toolDir      = $toolDir
    reports      = $reportEntries
}
$manifestFile = Join-Path $TrackingDir "BUILD_MANIFEST_$jsonName.json"
[System.IO.File]::WriteAllText($manifestFile, ($manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
Write-Host "  [manifest] $manifestFile (source SHA $($manifest.sourceSha256.Substring(0,12))...)" -ForegroundColor Gray
Write-Host ""

# ══════════════════════════════════════════════════════════════════════════════
#  ORPHANED-REPORT PRUNE -- keep this docs folder clean.
#  build_report owns a fixed set of report prefixes. When a provider drops a JSON
#  variant (e.g. NJ's VehStolenRemoved/Separate branches, or a legacy _BASE/_MC),
#  the reports for that variant linger forever because nothing deletes them.
#  Canonical-diff: any build-owned report (or *_TEST_MATRIX.txt) for THIS provider
#  base whose name is NOT one this build would produce is an orphan -> remove it.
#  The expected set is derived deterministically from $jsonName (NOT from which
#  tools happened to run), so a transiently-skipped tool never deletes a good file.
#  Scans $ReportsDir + $DeliverablesDir + $TrackingDir (collapse to $DocsDir for an
#  unmigrated/legacy provider or explicit -DocsDir override -- unchanged behavior there;
#  for a migrated provider these are 3 distinct category folders). Legacy docs/base|mc
#  subfolders are never touched here.
#  Manual docs (TEST_PLAN_*, *_FIELD_CASING_REVIEW.md, *_SUPPORTED_QUERIES.txt,
#  FIRST_RESPONDER_*) don't match an owned prefix and are left alone.
# ══════════════════════════════════════════════════════════════════════════════
$ownedPrefixes = @(
    'RESPONSE_SIMULATION','SUPPORTED_QUERY_AUDIT','VALIDATOR_REPORT','LAYOUT_REPORT',
    'QUERY_REPORT','PICKLIST_REPORT','VERIFY_REPORT','METADATA_AUDIT','TEST_VALIDATION',
    'LABEL_REVIEW','BUILD_MANIFEST','OFFICER_GUIDE','LINT_REPORT','TEST_SHEET',
    'CAD_AUDIT','CHANGELOG','LAYOUT'
)
$canonicalLeaves = @(
    "LINT_REPORT_$jsonName.txt","VALIDATOR_REPORT_$jsonName.txt","RESPONSE_SIMULATION_$jsonName.txt",
    "LAYOUT_REPORT_$jsonName.txt","QUERY_REPORT_$jsonName.txt","PICKLIST_REPORT_$jsonName.txt",
    "LAYOUT_$jsonName.html","VERIFY_REPORT_$jsonName.txt","METADATA_AUDIT_$jsonName.txt",
    "CAD_AUDIT_$jsonName.txt","TEST_VALIDATION_$jsonName.txt","LABEL_REVIEW_$jsonName.txt",
    "OFFICER_GUIDE_$jsonName.html","OFFICER_GUIDE_$jsonName.pdf",
    "SUPPORTED_QUERY_AUDIT_$jsonName.txt","CHANGELOG_$jsonName.md",
    "BUILD_MANIFEST_$jsonName.json","${jsonName}_TEST_MATRIX.txt"
)
$baseEsc    = [regex]::Escape($jsonName)
$ownedRe    = '^(?:' + ($ownedPrefixes -join '|') + ')_' + $baseEsc + '(?:_.+)?\.(?:txt|html|pdf|json|md)$'
$matrixRe   = '^' + $baseEsc + '_.+_TEST_MATRIX\.txt$'
$prunedCount = 0
$pruneScanDirs = @($ReportsDir, $DeliverablesDir, $TrackingDir) | Select-Object -Unique
foreach ($scanDir in $pruneScanDirs) {
    Get-ChildItem $scanDir -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -match $ownedRe -or $_.Name -match $matrixRe) -and ($canonicalLeaves -notcontains $_.Name)
        } |
        ForEach-Object {
            Write-Host "  [cleanup] removing orphaned report: $($_.Name)" -ForegroundColor DarkYellow
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            $prunedCount++
        }
}
if ($prunedCount -gt 0) { Write-Host "  [cleanup] pruned $prunedCount orphaned report file(s)" -ForegroundColor Yellow }
Write-Host ""
