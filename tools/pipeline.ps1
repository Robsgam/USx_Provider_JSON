<#
  pipeline.ps1 -- Complete build-to-verify pipeline for one provider
  ONE command. Runs EVERYTHING. No manual steps.

  Steps:
    1. Build BASE JSON (run build script)
    2. Build MC JSON (run MC build script)
    3. Build report on BASE (8 tools)
    4. Build report on MC (8 tools)
    5. Extract metadata reference
    6. Sync CLAUDE.md provider table
    7. Cross-provider audit (ALL providers, not just this one)
    8. Repo audit (full monorepo)
    9. Enforce (final gate)

  If any step FAILs, pipeline stops and reports exactly what broke.

  Usage:
    .\pipeline.ps1 -Provider HI_HCJDC_OFML
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -BaseOnly    # skip MC
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipBuild   # reports + audit only (JSON already built)
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipEnforce # stop before enforce (mid-work)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider,
    [switch]$BaseOnly,
    [switch]$SkipBuild,
    [switch]$SkipEnforce
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"

if (-not (Test-Path $provDir)) {
    Write-Host "  [ERROR] Provider not found: $provDir" -ForegroundColor Red
    exit 1
}

$docPrefix = $Provider -replace '_(LOCKED|BLOCKED)$', ''

# ── Helpers ───────────────────────────────────────────────────────────────────
$script:stepNum = 0
$script:totalSteps = 9
if ($BaseOnly)    { $script:totalSteps-- }
if ($SkipBuild)   { $script:totalSteps -= $(if ($BaseOnly) { 1 } else { 2 }) }
if ($SkipEnforce) { $script:totalSteps-- }

$script:failedStep = $null

function Step($desc) {
    $script:stepNum++
    Write-Host ""
    Write-Host "  [$($script:stepNum)/$($script:totalSteps)] $desc" -ForegroundColor Cyan
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
}

function StepFail($msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $script:failedStep = $msg
}

function StepPass($msg) {
    Write-Host "  [PASS] $msg" -ForegroundColor Green
}

# ── Discover scripts and files ────────────────────────────────────────────────
$baseScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*" -File |
    Where-Object { $_.Name -notmatch '_mc' } | Select-Object -First 1

$mcScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*_mc*" -File |
    Select-Object -First 1

$baseJson = Join-Path $provDir "${docPrefix}_BASE.json"
$mcJson   = Join-Path $provDir "${docPrefix}_MC.json"

$xmlFile = Get-ChildItem (Join-Path $provDir "source") -Filter "*.xml" -File |
    Where-Object { $_.Name -notmatch 'HIDLE' } | Select-Object -First 1

# ══════════════════════════════════════════════════════════════════════════════
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Magenta
Write-Host "  PIPELINE -- $Provider" -ForegroundColor Magenta
Write-Host "  $timestamp" -ForegroundColor Magenta
Write-Host "  Steps: $($script:totalSteps)" -ForegroundColor Magenta
Write-Host ("=" * 60) -ForegroundColor Magenta

# All steps run inside a labeled loop so we can break to summary on failure
:pipeline do {

# ── STEP 1: Build BASE ───────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Step "Build BASE JSON"
    if (-not $baseScript) {
        StepFail "No BASE build script found in scripts/"
    } else {
        $output = & powershell -ExecutionPolicy Bypass -File $baseScript.FullName 2>&1 | Out-String
        if ($output -match '0 FAIL') {
            StepPass "BASE built successfully"
        } else {
            StepFail "BASE build had failures"
            Write-Host $output
        }
    }
    if ($script:failedStep) { break pipeline }
}

# ── STEP 2: Build MC ─────────────────────────────────────────────────────────
if (-not $SkipBuild -and -not $BaseOnly) {
    Step "Build MC JSON"
    if (-not $mcScript) {
        StepFail "No MC build script found in scripts/"
    } else {
        $output = & powershell -ExecutionPolicy Bypass -File $mcScript.FullName 2>&1 | Out-String
        if ($output -match '0 FAIL') {
            StepPass "MC built successfully"
        } else {
            StepFail "MC build had failures"
            Write-Host $output
        }
    }
    if ($script:failedStep) { break pipeline }
}

# ── STEP 3: Build report BASE ────────────────────────────────────────────────
Step "Build report (BASE)"
if (Test-Path $baseJson) {
    $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $baseJson 2>&1 | Out-String
    if ($output -match '0 FAIL') {
        StepPass "BASE report complete"
    } else {
        StepFail "BASE report had issues"
        Write-Host $output
    }
} else {
    StepFail "BASE JSON not found: $baseJson"
}
if ($script:failedStep) { break pipeline }

# ── STEP 4: Build report MC ──────────────────────────────────────────────────
if (-not $BaseOnly) {
    Step "Build report (MC)"
    if (Test-Path $mcJson) {
        $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $mcJson 2>&1 | Out-String
        if ($output -match '0 FAIL') {
            StepPass "MC report complete"
        } else {
            StepFail "MC report had issues"
            Write-Host $output
        }
    } else {
        StepFail "MC JSON not found: $mcJson"
    }
    if ($script:failedStep) { break pipeline }
}

# ── STEP 5: Extract metadata reference ────────────────────────────────────────
Step "Extract metadata reference"
if ($xmlFile -and (Test-Path $baseJson)) {
    $metaOut = Join-Path $provDir "docs\${docPrefix}_METADATA_REFERENCE.txt"
    & powershell -ExecutionPolicy Bypass -File "$toolDir\extract_metadata_reference.ps1" `
        -XmlPath $xmlFile.FullName -Path $baseJson -OutFile $metaOut 2>&1 | Out-Null
    if (Test-Path $metaOut) {
        StepPass "METADATA_REFERENCE.txt updated"
    } else {
        StepFail "METADATA_REFERENCE.txt not created"
    }
} else {
    Write-Host "  [INFO] No XML metadata found -- skipping extraction" -ForegroundColor Gray
}

# ── STEP 6: Sync CLAUDE.md ───────────────────────────────────────────────────
Step "Sync CLAUDE.md provider table"
$output = & powershell -ExecutionPolicy Bypass -File "$toolDir\sync_provider_table.ps1" 2>&1 | Out-String
if ($output -match 'Updated (\d+)') {
    $count = $Matches[1]
    if ([int]$count -gt 0) {
        StepPass "CLAUDE.md updated ($count providers)"
    } else {
        StepPass "CLAUDE.md already current"
    }
} else {
    StepPass "sync_provider_table ran"
}

# ── STEP 7: Cross-provider audit ─────────────────────────────────────────────
Step "Cross-provider audit (ALL providers)"
$output = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_cross_provider.ps1" `
    -Path (Join-Path $repoRoot "providers") 2>&1 | Out-String

if ($output -match '(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL') {
    $xFail = [int]$Matches[2]
    if ($xFail -gt 0) {
        StepFail "Cross-provider: $xFail FAIL(s)"
        $output -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
            Write-Host "       $($_.Trim())" -ForegroundColor Red
        }
    } else {
        StepPass "Cross-provider: 0 FAIL"
    }
} else {
    StepFail "Cross-provider audit output unparseable"
}
if ($script:failedStep) { break pipeline }

# ── STEP 8: Repo audit ───────────────────────────────────────────────────────
Step "Repo audit (full monorepo)"
$output = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_repo.ps1" 2>&1 | Out-String

if ($output -match 'AUDIT\s+PASSED') {
    StepPass "Repo audit passed"
} elseif ($output -match '(\d+)\s*FAIL') {
    $rFail = [int]$Matches[1]
    StepFail "Repo audit: $rFail FAIL(s)"
    $output -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
        Write-Host "       $($_.Trim())" -ForegroundColor Red
    }
} else {
    StepFail "Repo audit output unparseable"
}
if ($script:failedStep) { break pipeline }

# ── STEP 9: Enforce ──────────────────────────────────────────────────────────
if (-not $SkipEnforce) {
    Step "Enforce (final gate)"
    $enforceResult = & powershell -ExecutionPolicy Bypass -File "$toolDir\enforce.ps1" -Provider $Provider -SkipGit 2>&1 | Out-String

    if ($enforceResult -match 'ENFORCED') {
        StepPass "ENFORCED -- all gates clear"
    } elseif ($enforceResult -match 'PASSED WITH WARNINGS') {
        Write-Host "  [WARN] Passed with warnings" -ForegroundColor Yellow
    } else {
        StepFail "enforce.ps1 BLOCKED"
        $enforceResult -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
            Write-Host "       $($_.Trim())" -ForegroundColor Red
        }
    }
}

} while ($false)

# ── Summary (always runs) ────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor $(if ($script:failedStep) { "Red" } else { "Green" })
if ($script:failedStep) {
    Write-Host "  PIPELINE FAILED at step $($script:stepNum): $($script:failedStep)" -ForegroundColor Red
    Write-Host "  Fix the failure and re-run." -ForegroundColor Red
} else {
    Write-Host "  PIPELINE COMPLETE -- $Provider" -ForegroundColor Green
    Write-Host "  All $($script:totalSteps) steps passed. Ready to commit." -ForegroundColor Green
}
Write-Host ("=" * 60) -ForegroundColor $(if ($script:failedStep) { "Red" } else { "Green" })

if ($script:failedStep) { exit 1 }
exit 0
