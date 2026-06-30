<#
  pipeline.ps1 -- Complete build-to-verify pipeline for one or more providers
  ONE command. Runs EVERYTHING. No manual steps.

  Single-provider steps:
    1. Build JSON (run build script)
    2. Build report (10 tools, steps 1-9 parallel + test conductor)
    3. Extract metadata reference
    4. Sync CLAUDE.md provider table
    5. Sync version docs (STATUS, SQVR, JSON_INVENTORY, REBUILD_TRACKER)
    6. Cross-provider audit (ALL providers, not just this one)
    7. Repo audit (full monorepo)
    8. Enforce (final gate)

  Batch mode deduplicates global audits: per-provider work (steps 1-3),
  then ONE sync pass, ONE cross-provider audit, ONE repo audit, ONE enforce.

  If any step FAILs, pipeline stops (single mode) or skips that provider (batch mode).

  Usage:
    .\pipeline.ps1 -Provider HI_HCJDC_OFML          # single provider
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipBuild   # reports + audit only
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipEnforce # stop before enforce
    .\pipeline.ps1 -Provider HI_HCJDC_OFML -DeferAudit  # skip steps 6-7 (mid-work)
    .\pipeline.ps1 -Providers TX_TLETS,HI_HCJDC_OFML    # batch: named providers
    .\pipeline.ps1 -All                                   # batch: all active providers
    .\pipeline.ps1 -All -SkipBuild                        # batch: reports only
#>

param(
    [string]$Provider,
    [string[]]$Providers,
    [switch]$All,
    [switch]$SkipBuild,
    [switch]$SkipEnforce,
    [switch]$DeferAudit
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provRoot = Join-Path $repoRoot "providers"

# Shared active-JSON resolver (handles versioned <PROVIDER>_v<X.Y>.json names)
. "$toolDir\_resolve_provider_json.ps1"

# ── Validate params ──────────────────────────────────────────────────────────
$modeCount = 0
if ($Provider)  { $modeCount++ }
if ($Providers) { $modeCount++ }
if ($All)       { $modeCount++ }
if ($modeCount -ne 1) {
    Write-Host "  [ERROR] Specify exactly one of: -Provider, -Providers, or -All" -ForegroundColor Red
    exit 1
}

# ── Build provider list ─────────────────────────────────────────────────────
if ($All) {
    $providerList = Get-ChildItem $provRoot -Directory |
        Where-Object { $_.Name -ne 'CA_CONTRA_COSTA' } |
        ForEach-Object { $_.Name } | Sort-Object
} elseif ($Providers) {
    $providerList = $Providers
} else {
    $providerList = @($Provider)
}

$batchMode = $providerList.Count -gt 1

# ── Helpers ──────────────────────────────────────────────────────────────────
function StepPass($msg)  { Write-Host "  [PASS] $msg" -ForegroundColor Green }
function StepFail($msg)  { Write-Host "  [FAIL] $msg" -ForegroundColor Red }

function Find-ProviderFiles($provName) {
    $provDir = Join-Path $provRoot $provName
    if (-not (Test-Path $provDir)) { return $null }

    $buildScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' } | Select-Object -First 1
    if (-not $buildScript) {
        $buildScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*_mc*" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    $provJson = Get-ProviderRootJson -ProvDir $provDir -Provider $provName
    if (-not $provJson) { $provJson = Join-Path $provDir "${provName}.json" }  # fall back to expected name for messaging

    $xmlFile = Get-ChildItem (Join-Path $provDir "source") -Filter "*.xml" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'HIDLE' } | Select-Object -First 1

    return @{
        Dir = $provDir
        BuildScript = $buildScript
        Json = $provJson
        Xml = $xmlFile
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  SINGLE-PROVIDER MODE (original behavior, unchanged)
# ══════════════════════════════════════════════════════════════════════════════

if (-not $batchMode) {
    $provName = $providerList[0]
    $files = Find-ProviderFiles $provName
    if (-not $files) {
        Write-Host "  [ERROR] Provider not found: $provName" -ForegroundColor Red
        exit 1
    }

    $script:stepNum = 0
    $stepTotal = 8
    if ($SkipBuild)   { $stepTotal-- }
    if ($SkipEnforce) { $stepTotal-- }
    if ($DeferAudit)  { $stepTotal -= 2 }
    $script:failedStep = $null

    function Step($desc) {
        $script:stepNum++
        Write-Host ""
        Write-Host "  [$($script:stepNum)/$stepTotal] $desc" -ForegroundColor Cyan
        Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Magenta
    Write-Host "  PIPELINE -- $provName" -ForegroundColor Magenta
    Write-Host "  $timestamp" -ForegroundColor Magenta
    Write-Host "  Steps: $stepTotal" -ForegroundColor Magenta
    Write-Host ("=" * 60) -ForegroundColor Magenta

    :pipeline do {

    # Step 1: Build JSON
    if (-not $SkipBuild) {
        Step "Build JSON"
        if (-not $files.BuildScript) {
            StepFail "No build script found in scripts/"
            $script:failedStep = "Build"
        } else {
            $output = & powershell -ExecutionPolicy Bypass -File $files.BuildScript.FullName 2>&1 | Out-String
            if ($output -match '0 FAIL') {
                StepPass "Built successfully"
                $resolvedJson = Get-ProviderRootJson -ProvDir $files.Dir -Provider $provName
                if ($resolvedJson) { $files.Json = $resolvedJson }

                # Rebuild restarts testing: a version bump invalidates prior live logs.
                # Archive them + reset SQVR/STATUS so all logs line up with the new JSON.
                $resetOut = & powershell -ExecutionPolicy Bypass -File "$toolDir\reset_test_package.ps1" -Provider $provName 2>&1 | Out-String
                if ($resetOut -match 'RESET:') {
                    Write-Host "  [TESTS] Version changed -- USx Tenant Testing package restarted from Test 1:" -ForegroundColor Yellow
                    $resetOut -split "`n" | Where-Object { $_ -match '^\s+- ' } | ForEach-Object { Write-Host "       $($_.Trim())" -ForegroundColor DarkYellow }
                } elseif ($resetOut -match 'ALIGNED:') {
                    Write-Host "  [TESTS] Test package already aligned to current version" -ForegroundColor DarkGray
                }
            } else {
                StepFail "Build had failures"
                Write-Host $output
                $script:failedStep = "Build"
            }
        }
        if ($script:failedStep) { break pipeline }
    }

    # Step 2: Build report
    Step "Build report"
    if (Test-Path $files.Json) {
        $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $files.Json 2>&1 | Out-String
        if ($output -match '0 FAIL') {
            StepPass "Report complete"
        } else {
            StepFail "Report had issues"
            Write-Host $output
            $script:failedStep = "Report"
        }
    } else {
        StepFail "JSON not found: $($files.Json)"
        $script:failedStep = "Report"
    }
    if ($script:failedStep) { break pipeline }

    # Step 3: Extract metadata reference
    Step "Extract metadata reference"
    if ($files.Xml -and (Test-Path $files.Json)) {
        $metaOut = Join-Path $files.Dir "docs\${provName}_METADATA_REFERENCE.txt"
        & powershell -ExecutionPolicy Bypass -File "$toolDir\extract_metadata_reference.ps1" `
            -XmlPath $files.Xml.FullName -Path $files.Json -OutFile $metaOut 2>&1 | Out-Null
        if (Test-Path $metaOut) {
            StepPass "METADATA_REFERENCE.txt updated"
        } else {
            StepFail "METADATA_REFERENCE.txt not created"
        }
    } else {
        Write-Host "  [INFO] No XML metadata found -- skipping extraction" -ForegroundColor Gray
    }

    # Step 4: Sync CLAUDE.md
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

    # Step 5: Sync version docs
    Step "Sync version docs (STATUS, SQVR, JSON_INVENTORY, REBUILD_TRACKER)"
    $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\sync_version_docs.ps1" -Provider $provName 2>&1 | Out-String
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

    # Step 6: Cross-provider audit
    if (-not $DeferAudit) {
        Step "Cross-provider audit (ALL providers)"
        $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_cross_provider.ps1" `
            -Path $provRoot 2>&1 | Out-String

        if ($output -match '(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL') {
            $xFail = [int]$Matches[2]
            if ($xFail -gt 0) {
                StepFail "Cross-provider: $xFail FAIL(s)"
                $output -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
                    Write-Host "       $($_.Trim())" -ForegroundColor Red
                }
                $script:failedStep = "Cross-provider"
            } else {
                StepPass "Cross-provider: 0 FAIL"
            }
        } else {
            StepFail "Cross-provider audit output unparseable"
            $script:failedStep = "Cross-provider"
        }
        if ($script:failedStep) { break pipeline }

        # Step 7: Repo audit
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
            $script:failedStep = "Repo audit"
        } else {
            StepFail "Repo audit output unparseable"
            $script:failedStep = "Repo audit"
        }
        if ($script:failedStep) { break pipeline }
    }

    # Step 8: Enforce
    if (-not $SkipEnforce) {
        Step "Enforce (final gate)"
        $enforceResult = & powershell -ExecutionPolicy Bypass -File "$toolDir\enforce.ps1" -Provider $provName -SkipGit 2>&1 | Out-String

        if ($enforceResult -match 'ENFORCED') {
            StepPass "ENFORCED -- all gates clear"
        } elseif ($enforceResult -match 'PASSED WITH WARNINGS') {
            Write-Host "  [WARN] Passed with warnings" -ForegroundColor Yellow
        } else {
            StepFail "enforce.ps1 BLOCKED"
            $enforceResult -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
                Write-Host "       $($_.Trim())" -ForegroundColor Red
            }
            $script:failedStep = "Enforce"
        }
    }

    } while ($false)

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $(if ($script:failedStep) { "Red" } else { "Green" })
    if ($script:failedStep) {
        Write-Host "  PIPELINE FAILED at step $($script:stepNum): $($script:failedStep)" -ForegroundColor Red
        Write-Host "  Fix the failure and re-run." -ForegroundColor Red
    } else {
        Write-Host "  PIPELINE COMPLETE -- $provName" -ForegroundColor Green
        Write-Host "  All $stepTotal steps passed. Ready to commit." -ForegroundColor Green
    }
    Write-Host ("=" * 60) -ForegroundColor $(if ($script:failedStep) { "Red" } else { "Green" })

    if ($script:failedStep) { exit 1 }
    exit 0
}

# ══════════════════════════════════════════════════════════════════════════════
#  BATCH MODE
# ══════════════════════════════════════════════════════════════════════════════

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$totalProviders = $providerList.Count

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Magenta
Write-Host "  BATCH PIPELINE -- $totalProviders providers" -ForegroundColor Magenta
Write-Host "  $timestamp" -ForegroundColor Magenta
Write-Host "  Providers: $($providerList -join ', ')" -ForegroundColor Magenta
Write-Host ("=" * 60) -ForegroundColor Magenta

$results = @{}

# ── Phase A: Per-provider work (steps 1-3) ──────────────────────────────────

$provNum = 0
foreach ($provName in $providerList) {
    $provNum++
    Write-Host ""
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
    Write-Host "  [Provider $provNum/$totalProviders] $provName" -ForegroundColor Cyan
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray

    $files = Find-ProviderFiles $provName
    if (-not $files) {
        StepFail "Provider directory not found"
        $results[$provName] = @{ Status = 'FAIL'; Step = 'Discovery'; Message = 'Directory not found' }
        continue
    }

    $provFailed = $null

    # Step 1: Build
    if (-not $SkipBuild) {
        if (-not $files.BuildScript) {
            StepFail "No build script"
            $provFailed = 'Build'
        } else {
            $output = & powershell -ExecutionPolicy Bypass -File $files.BuildScript.FullName 2>&1 | Out-String
            if ($output -match '0 FAIL') {
                StepPass "Built"
                $resolvedJson = Get-ProviderRootJson -ProvDir $files.Dir -Provider $provName
                if ($resolvedJson) { $files.Json = $resolvedJson }

                # Rebuild restarts testing (see reset_test_package.ps1)
                $resetOut = & powershell -ExecutionPolicy Bypass -File "$toolDir\reset_test_package.ps1" -Provider $provName 2>&1 | Out-String
                if ($resetOut -match 'RESET:') {
                    Write-Host "  [TESTS] $provName version changed -- test package restarted from Test 1" -ForegroundColor Yellow
                }
            } else {
                StepFail "Build failed"
                $provFailed = 'Build'
            }
        }
    }

    # Step 2: Build report
    if (-not $provFailed) {
        if (Test-Path $files.Json) {
            $output = & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $files.Json 2>&1 | Out-String
            if ($output -match '0 FAIL') {
                StepPass "Report complete"
            } else {
                StepFail "Report had issues"
                $provFailed = 'Report'
            }
        } else {
            StepFail "JSON not found"
            $provFailed = 'Report'
        }
    }

    # Step 3: Extract metadata
    if (-not $provFailed -and $files.Xml -and (Test-Path $files.Json)) {
        $metaOut = Join-Path $files.Dir "docs\${provName}_METADATA_REFERENCE.txt"
        & powershell -ExecutionPolicy Bypass -File "$toolDir\extract_metadata_reference.ps1" `
            -XmlPath $files.Xml.FullName -Path $files.Json -OutFile $metaOut 2>&1 | Out-Null
        if (Test-Path $metaOut) {
            StepPass "Metadata extracted"
        }
    }

    if ($provFailed) {
        $results[$provName] = @{ Status = 'FAIL'; Step = $provFailed }
    } else {
        $results[$provName] = @{ Status = 'PASS' }
    }
}

$passedProviders = @($results.Keys | Where-Object { $results[$_].Status -eq 'PASS' })
$failedProviders = @($results.Keys | Where-Object { $results[$_].Status -eq 'FAIL' })

# ── Phase B: Sync (ONE time) ────────────────────────────────────────────────

Write-Host ""
Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
Write-Host "  [BATCH] Sync pass" -ForegroundColor Cyan
Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray

& powershell -ExecutionPolicy Bypass -File "$toolDir\sync_provider_table.ps1" 2>&1 | Out-Null
StepPass "CLAUDE.md synced"

foreach ($provName in $passedProviders) {
    & powershell -ExecutionPolicy Bypass -File "$toolDir\sync_version_docs.ps1" -Provider $provName 2>&1 | Out-Null
}
StepPass "Version docs synced ($($passedProviders.Count) providers)"

# ── Phase C: Global audits (ONE time) ───────────────────────────────────────

$batchFailed = $false

if (-not $DeferAudit) {
    Write-Host ""
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
    Write-Host "  [BATCH] Global audits" -ForegroundColor Cyan
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray

    $crossOutput = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_cross_provider.ps1" `
        -Path $provRoot 2>&1 | Out-String

    if ($crossOutput -match '(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL') {
        $xFail = [int]$Matches[2]
        if ($xFail -gt 0) {
            StepFail "Cross-provider: $xFail FAIL(s)"
            $batchFailed = $true
        } else {
            StepPass "Cross-provider: 0 FAIL"
        }
    } else {
        StepFail "Cross-provider: unparseable"
        $batchFailed = $true
    }

    $repoOutput = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_repo.ps1" 2>&1 | Out-String
    if ($repoOutput -match 'AUDIT\s+PASSED') {
        StepPass "Repo audit passed"
    } elseif ($repoOutput -match '(\d+)\s*FAIL') {
        $rFail = [int]$Matches[1]
        StepFail "Repo audit: $rFail FAIL(s)"
        $batchFailed = $true
    } else {
        StepFail "Repo audit: unparseable"
        $batchFailed = $true
    }
}

# ── Phase D: Enforce (ONE time) ─────────────────────────────────────────────

if (-not $SkipEnforce -and -not $batchFailed) {
    Write-Host ""
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray
    Write-Host "  [BATCH] Enforce" -ForegroundColor Cyan
    Write-Host ("  " + "-" * 56) -ForegroundColor DarkGray

    $enforceResult = & powershell -ExecutionPolicy Bypass -File "$toolDir\enforce.ps1" -SkipGit 2>&1 | Out-String
    if ($enforceResult -match 'ENFORCED') {
        StepPass "ENFORCED -- all gates clear"
    } else {
        StepFail "enforce.ps1 BLOCKED"
        $batchFailed = $true
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────

$anyFailure = ($failedProviders.Count -gt 0) -or $batchFailed

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor $(if ($anyFailure) { "Red" } else { "Green" })
Write-Host "  BATCH PIPELINE $(if ($anyFailure) { 'INCOMPLETE' } else { 'COMPLETE' })" -ForegroundColor $(if ($anyFailure) { "Red" } else { "Green" })
Write-Host "  Providers: $totalProviders attempted, $($passedProviders.Count) passed, $($failedProviders.Count) failed" -ForegroundColor White

foreach ($provName in $failedProviders) {
    $r = $results[$provName]
    Write-Host "    FAILED: $provName (step: $($r.Step))" -ForegroundColor Red
}

if ($DeferAudit) {
    Write-Host "  Audits: DEFERRED (run enforce.ps1 separately)" -ForegroundColor Yellow
} elseif ($batchFailed) {
    Write-Host "  Global audits: FAILED" -ForegroundColor Red
} else {
    Write-Host "  Global audits: PASS" -ForegroundColor Green
}

Write-Host ("=" * 60) -ForegroundColor $(if ($anyFailure) { "Red" } else { "Green" })

if ($anyFailure) { exit 1 }
exit 0
