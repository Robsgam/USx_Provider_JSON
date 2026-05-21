<#
  pipeline.ps1 -- Complete build-to-verify pipeline for one provider
  ONE command. Runs EVERYTHING. No manual steps.

  Steps:
    1. Build JSON (run build script)
    2. Build report (10 tools + test matrix + test conductor)
    3. Extract metadata reference
    4. Sync CLAUDE.md provider table
    5. Sync version docs (STATUS, SQVR, JSON_INVENTORY, REBUILD_TRACKER)
    6. Cross-provider audit (ALL providers, not just this one)
    7. Repo audit (full monorepo)
    8. Enforce (final gate)

  If any step FAILs, pipeline stops and reports exactly what broke.

  Usage:
    .\pipeline.ps1 -Provider HI_HCJDC_OFML
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipBuild   # reports + audit only (JSON already built)
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipEnforce # stop before enforce (mid-work)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider,
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

$docPrefix = $Provider

# ── Helpers ───────────────────────────────────────────────────────────────────
$script:stepNum = 0
$script:totalSteps = 8
if ($SkipBuild)   { $script:totalSteps-- }
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
# Single build script per provider (no BASE/MC split)
# Legacy: also check for _mc suffix for providers not yet migrated
$buildScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*" -File |
    Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' } | Select-Object -First 1
if (-not $buildScript) {
    $buildScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*_mc*" -File |
        Select-Object -First 1
}

# JSON: check for <PROVIDER>.json first, then legacy _MC.json / _BASE.json
$provJson = Join-Path $provDir "${docPrefix}.json"
if (-not (Test-Path $provJson)) {
    $provJson = Join-Path $provDir "${docPrefix}_MC.json"
}
if (-not (Test-Path $provJson)) {
    $provJson = Join-Path $provDir "${docPrefix}_BASE.json"
}

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

# ── STEP 1: Build JSON ───────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Step "Build JSON"
    if (-not $buildScript) {
        StepFail "No build script found in scripts/"
    } else {
        $output = & powershell -ExecutionPolicy Bypass -File $buildScript.FullName 2>&1 | Out-String
        if ($output -match '0 FAIL') {
            StepPass "Built successfully"
            # Re-discover JSON after build (name may have changed)
            $provJson = Join-Path $provDir "${docPrefix}.json"
            if (-not (Test-Path $provJson)) { $provJson = Join-Path $provDir "${docPrefix}_MC.json" }
            if (-not (Test-Path $provJson)) { $provJson = Join-Path $provDir "${docPrefix}_BASE.json" }
        } else {
            StepFail "Build had failures"
            Write-Host $output
        }
    }
    if ($script:failedStep) { break pipeline }
}

# ── STEP 2: Build report ────────────────────────────────────────────────────
Step "Build report"
if (Test-Path $provJson) {
    $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $provJson 2>&1 | Out-String
    if ($output -match '0 FAIL') {
        StepPass "Report complete"
    } else {
        StepFail "Report had issues"
        Write-Host $output
    }
} else {
    StepFail "JSON not found: $provJson"
}
if ($script:failedStep) { break pipeline }

# ── STEP 3: Extract metadata reference ────────────────────────────────────────
Step "Extract metadata reference"
if ($xmlFile -and (Test-Path $provJson)) {
    $metaOut = Join-Path $provDir "docs\${docPrefix}_METADATA_REFERENCE.txt"
    & powershell -ExecutionPolicy Bypass -File "$toolDir\extract_metadata_reference.ps1" `
        -XmlPath $xmlFile.FullName -Path $provJson -OutFile $metaOut 2>&1 | Out-Null
    if (Test-Path $metaOut) {
        StepPass "METADATA_REFERENCE.txt updated"
    } else {
        StepFail "METADATA_REFERENCE.txt not created"
    }
} else {
    Write-Host "  [INFO] No XML metadata found -- skipping extraction" -ForegroundColor Gray
}

# ── STEP 4: Sync CLAUDE.md ───────────────────────────────────────────────────
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

# ── STEP 5: Sync version docs ────────────────────────────────────────────────
Step "Sync version docs (STATUS, SQVR, JSON_INVENTORY, REBUILD_TRACKER)"
$output = & powershell -ExecutionPolicy Bypass -File "$toolDir\sync_version_docs.ps1" -Provider $Provider 2>&1 | Out-String
if ($output -match '(\d+) updated') {
    $count = [int]$Matches[1]
    if ($count -gt 0) {
        StepPass "Version docs: $count files updated"
    } else {
        StepPass "Version docs already current"
    }
} else {
    StepPass "sync_version_docs ran"
}

# ── STEP 6: Cross-provider audit ─────────────────────────────────────────────
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

# ── STEP 7: Repo audit ───────────────────────────────────────────────────────
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

# ── STEP 8: Enforce ──────────────────────────────────────────────────────────
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
