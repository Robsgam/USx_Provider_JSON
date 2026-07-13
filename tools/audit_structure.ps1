<#
  audit_structure.ps1 -- Validate provider folder structure against canonical rules
  Checks: folder naming, required dirs/files, report completeness, freshness,
  JSON internal provider name, source materials, phase archives, release bundle.

  Usage: .\audit_structure.ps1
         .\audit_structure.ps1 -Path providers\NJ_NJCJIS
         .\audit_structure.ps1 -OutFile structure_report.txt
#>

param(
    [string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Shared active-JSON resolver (handles versioned <PROVIDER>_v<X.Y>.json names)
. "$PSScriptRoot\_resolve_provider_json.ps1"

# ── Output helpers ────────────────────────────────────────────────────────────

# Buffer for file output (captures everything if -OutFile is used)
$script:outputBuffer = [System.Collections.Generic.List[string]]::new()

function Out-Line {
    param([string]$Text = '', [string]$Color = 'White')
    if ($OutFile) {
        $script:outputBuffer.Add($Text)
    }
    Write-Host $Text -ForegroundColor $Color
}

function Write-Pass($msg) {
    Out-Line "  [PASS] $msg" 'Green'
    $script:totalPass++
    $script:provPass++
}

function Write-Fail($msg) {
    Out-Line "  [FAIL] $msg" 'Red'
    $script:totalFail++
    $script:provFail++
}

function Write-Warn($msg) {
    Out-Line "  [WARN] $msg" 'Yellow'
    $script:totalWarn++
    $script:provWarn++
}

function Write-Info($msg) {
    Out-Line "  [INFO] $msg" 'Gray'
}

function Write-Skip($msg) {
    Out-Line "  [SKIP] $msg" 'DarkGray'
}

# ── Global counters ──────────────────────────────────────────────────────────

$script:totalPass = 0
$script:totalFail = 0
$script:totalWarn = 0
$script:cleanProviders = [System.Collections.Generic.List[string]]::new()
$script:issueProviders = [System.Collections.Generic.List[string]]::new()

# ── Skip list ────────────────────────────────────────────────────────────────

$skipProviders = @('CA_CONTRA_COSTA')

# ── Resolve provider list ────────────────────────────────────────────────────

$providersDir = Join-Path $repoRoot 'providers'

if ($Path) {
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Host "ERROR: Path not found: $Path" -ForegroundColor Red
        exit 1
    }
    $providerFolders = @(Get-Item $resolved.Path)
} else {
    $providerFolders = @(Get-ChildItem $providersDir -Directory | Sort-Object Name)
}

# ── Report file prefixes (the always-run build_report outputs) ───────────────
# LAYOUT_REPORT/QUERY_REPORT/PICKLIST_REPORT dropped 2026-07-06 -- build_report.ps1 demoted
# their generators to the opt-in -IncludeExtended bundle (matching audit_repo.ps1 Category 10),
# so a default build no longer produces them; requiring them here would just be noise.

$reportTextPrefixes = @('VALIDATOR_REPORT', 'VERIFY_REPORT')
# HTML is LAYOUT_<provider>_<variant>.html

# ══════════════════════════════════════════════════════════════════════════════
# MAIN AUDIT LOOP
# ══════════════════════════════════════════════════════════════════════════════

foreach ($provFolder in $providerFolders) {
    $provName = $provFolder.Name
    $provRoot = $provFolder.FullName
    $provLower = $provName.ToLower()

    # Skip flagged providers
    if ($provName -in $skipProviders) {
        Out-Line ""
        Out-Line "========================================" 'DarkGray'
        Out-Line " SKIPPED: $provName (flagged -- no build)" 'DarkGray'
        Out-Line "========================================" 'DarkGray'
        continue
    }

    # Per-provider counters
    $script:provPass = 0
    $script:provFail = 0
    $script:provWarn = 0

    Out-Line ""
    Out-Line "========================================" 'Cyan'
    Out-Line " STRUCTURE AUDIT: $provName" 'Cyan'
    Out-Line "========================================" 'Cyan'

    # ── CHECK 1: Folder Naming ────────────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 1: Folder Naming ---" 'Yellow'

    $sourceDir = Join-Path $provRoot 'source'
    $xmlFiles = @()
    if (Test-Path $sourceDir) {
        $xmlFiles = @(Get-ChildItem $sourceDir -Filter '*.xml' -File |
            Where-Object { $_.Name -notmatch '\.old\.xml$' })
    }

    if ($xmlFiles.Count -eq 0) {
        Write-Skip "No XML found in source/ -- cannot verify folder naming"
    } else {
        $primaryXml = $xmlFiles | Where-Object {
            [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -ieq $provName
        } | Select-Object -First 1

        if (-not $primaryXml) {
            $primaryXml = $xmlFiles | Select-Object -First 1
        }

        $xmlBaseName = [System.IO.Path]::GetFileNameWithoutExtension($primaryXml.Name)
        if ($xmlBaseName -ieq $provName) {
            Write-Pass "Folder '$provName' matches XML '$($primaryXml.Name)'"
        } else {
            Write-Fail "Folder '$provName' does NOT match XML '$($primaryXml.Name)' (expected '$xmlBaseName')"
        }
    }

    # ── CHECK 2: Required Directories ─────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 2: Required Directories ---" 'Yellow'

    # Current canonical structure requires only docs/, scripts/, source/. The legacy dirs
    # (docs/base, docs/mc, phases/*, release) are retired under the single-JSON + pipeline-v2
    # methodology, so requiring them would penalize correctly-migrated providers.
    $requiredDirs = @('docs', 'scripts', 'source')

    foreach ($rd in $requiredDirs) {
        $dirPath = Join-Path $provRoot ($rd -replace '/', '\')
        if (Test-Path $dirPath) {
            Write-Pass "$rd/"
        } else {
            Write-Fail "$rd/ -- directory missing"
        }
    }

    # Test-log location: logs/<Entity>/ (pipeline v2, current) or tests/ (legacy). One required.
    $logsDir  = Join-Path $provRoot 'logs'
    $testsDir = Join-Path $provRoot 'tests'
    if (Test-Path $logsDir) {
        Write-Pass "logs/ (pipeline-v2 test package)"
        if (Test-Path $testsDir) {
            Write-Warn "tests/ still present alongside logs/ -- legacy folder should be removed (pipeline v2 eliminated tests/)"
        }
    } elseif (Test-Path $testsDir) {
        Write-Info "tests/ (legacy test package -- migrates to logs/<Entity>/ on next rebuild)"
    } else {
        Write-Fail "no test-log directory (expected logs/ or tests/)"
    }

    # ── CHECK 3: Required Files -- JSON ───────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 3: Required Files -- JSON ---" 'Yellow'

    # Active root JSON: bare <PROVIDER>.json, versioned <PROVIDER>_v<X.Y>.json
    # (current standard), or legacy _MC/_BASE. Exactly one should be present.
    $baseJson = Join-Path $provRoot "${provName}_BASE.json"
    $mcJson = Join-Path $provRoot "${provName}_MC.json"
    $activeJson = Get-ProviderRootJson -ProvDir $provRoot -Provider $provName

    if ($activeJson) {
        Write-Pass "root JSON present: $(Split-Path $activeJson -Leaf)"
    } else {
        Write-Fail "no provider JSON in root (expected ${provName}_v<X.Y>.json or ${provName}.json)"
    }

    # Legacy split-build note (informational; converts to single versioned JSON on rebuild)
    if ((Test-Path $baseJson) -and (Test-Path $mcJson)) {
        Write-Info "${provName} -- legacy _BASE + _MC pair in root (convert to single versioned JSON on rebuild)"
    }

    # Check for mis-named JSON files (root JSONs that don't start with the folder name)
    $rootJsonFiles = @(Get-ChildItem $provRoot -Filter '*.json' -File |
        Where-Object { $_.Name -match '_(BASE|MC)\.json$' -or $_.Name -match '_v[\d.]+\.json$' })
    foreach ($jf in $rootJsonFiles) {
        if ($jf.Name -notmatch "^${provName}_") {
            Write-Fail "JSON file '$($jf.Name)' does not match folder name '$provName'"
        }
    }

    # ── CHECK 4: Required Files -- Scripts ────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 4: Required Files -- Scripts ---" 'Yellow'

    $scriptsDir = Join-Path $provRoot 'scripts'
    $baseBuild = Join-Path $scriptsDir "build_${provLower}.ps1"
    $mcBuild = Join-Path $scriptsDir "build_${provLower}_mc.ps1"

    if (Test-Path $baseBuild) {
        Write-Pass "scripts/build_${provLower}.ps1 exists"
    } else {
        Write-Fail "scripts/build_${provLower}.ps1 missing"
    }

    # Single-script model is current; a separate _mc build script is legacy, not required.
    if (Test-Path $mcBuild) {
        Write-Info "scripts/build_${provLower}_mc.ps1 present (legacy MC split -- single-script build is current)"
    }

    # Check for non-standard script names (v2, v3, test variants)
    if (Test-Path $scriptsDir) {
        $nonStandard = @(Get-ChildItem $scriptsDir -Filter 'build_*.ps1' -File |
            Where-Object {
                $_.Name -ne "build_${provLower}.ps1" -and
                $_.Name -ne "build_${provLower}_mc.ps1" -and
                $_.Name -match 'build_'
            })
        foreach ($ns in $nonStandard) {
            Write-Warn "Non-standard build script: scripts/$($ns.Name)"
        }
    }

    # ── CHECK 5: Required Files -- Docs ───────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 5: Required Files -- Docs ---" 'Yellow'

    $docsDir = Join-Path $provRoot 'docs'

    $requiredDocFiles = @(
        @{ Name = "${provName}_STATUS.txt";       Label = "STATUS.txt" },
        @{ Name = "${provName}_BUILD_NOTES.txt";  Label = "BUILD_NOTES.txt" },
        @{ Name = "${provName}_SQVR.txt";         Label = "SQVR.txt" },
        @{ Name = "JSON_INVENTORY.md";            Label = "JSON_INVENTORY.md" }
    )

    # These tracking docs live under docs/tracking/ (migrated) or flat docs/ (legacy).
    # Read-only check of both locations -- do NOT use Find-DocsPath here (it creates dirs).
    foreach ($df in $requiredDocFiles) {
        $catPath  = Join-Path (Join-Path $docsDir 'tracking') $df.Name
        $flatPath = Join-Path $docsDir $df.Name
        if ((Test-Path $catPath) -or (Test-Path $flatPath)) {
            Write-Pass "docs/$($df.Name) exists"
        } else {
            Write-Fail "docs/(tracking/)$($df.Name) missing"
        }
    }

    # ── CHECK 6: Report Files ─────────────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 6: Report Files ---" 'Yellow'

    $baseDocsDir = Join-Path $docsDir 'base'
    $mcDocsDir = Join-Path $docsDir 'mc'
    $reportsDir = Join-Path $docsDir 'reports'

    if (Test-Path $reportsDir) {
        # Migrated 4-category layout: build_report.ps1 always-run outputs land in docs/reports/.
        $repFiles = @(Get-ChildItem $reportsDir -File | ForEach-Object { $_.Name })
        $missingReports = @()
        foreach ($rp in $reportTextPrefixes) {
            if (-not ($repFiles | Where-Object { $_ -match "^${rp}_${provName}" })) { $missingReports += $rp }
        }
        if ($missingReports.Count -gt 0) {
            Write-Fail "docs/reports/ missing: $($missingReports -join ', ')"
        } else {
            Write-Pass "docs/reports/ has VALIDATOR + VERIFY reports"
        }
    } elseif (Test-Path $baseDocsDir) {
        # Legacy BASE reports in docs/base/
        $baseDocFiles = @(Get-ChildItem $baseDocsDir -File | ForEach-Object { $_.Name })

        $missingBaseReports = @()
        foreach ($rp in $reportTextPrefixes) {
            $match = $baseDocFiles | Where-Object { $_ -match "^${rp}_${provName}" }
            if (-not $match) { $missingBaseReports += $rp }
        }
        # HTML layout
        $htmlMatch = $baseDocFiles | Where-Object { $_ -match "^LAYOUT_${provName}_BASE\.html$" }
        if (-not $htmlMatch) { $missingBaseReports += 'LAYOUT_HTML' }

        if ($missingBaseReports.Count -gt 0) {
            Write-Fail "docs/base/ missing reports: $($missingBaseReports -join ', ')"
        } else {
            Write-Pass "docs/base/ has all 6 report files"
        }
    } else {
        Write-Info "no docs/reports/ or docs/base/ -- skipping report check"
    }

    # MC reports in docs/mc/ (legacy split only)
    if (Test-Path $mcDocsDir) {
        $mcDocFiles = @(Get-ChildItem $mcDocsDir -File |
            Where-Object { $_.Name -ne '.gitkeep' } |
            ForEach-Object { $_.Name })

        if ($mcDocFiles.Count -eq 0) {
            Write-Warn "docs/mc/ is empty (no MC reports yet)"
        } else {
            $missingMcReports = @()
            foreach ($rp in $reportTextPrefixes) {
                $match = $mcDocFiles | Where-Object { $_ -match "^${rp}_${provName}" }
                if (-not $match) { $missingMcReports += $rp }
            }
            $htmlMatch = $mcDocFiles | Where-Object { $_ -match "^LAYOUT_${provName}_MC\.html$" }
            if (-not $htmlMatch) { $missingMcReports += 'LAYOUT_HTML' }

            if ($missingMcReports.Count -gt 0) {
                Write-Warn "docs/mc/ missing reports: $($missingMcReports -join ', ')"
            } else {
                Write-Pass "docs/mc/ has all 6 report files"
            }
        }
    } else {
        Write-Info "docs/mc/ does not exist -- skipping MC report check"
    }

    # ── CHECK 7: Report Freshness ─────────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 7: Report Freshness ---" 'Yellow'

    # BASE JSON vs docs/base/ reports
    if ((Test-Path $baseJson) -and (Test-Path $baseDocsDir)) {
        $baseJsonTime = (Get-Item $baseJson).LastWriteTime
        $staleBase = @()
        $baseReportFiles = @(Get-ChildItem $baseDocsDir -File |
            Where-Object { $_.Name -ne '.gitkeep' })
        foreach ($rf in $baseReportFiles) {
            if ($rf.LastWriteTime -lt $baseJsonTime) {
                $staleBase += $rf.Name
            }
        }
        if ($staleBase.Count -gt 0) {
            Write-Warn "docs/base/ has $($staleBase.Count) stale report(s) older than BASE JSON: $($staleBase -join ', ')"
        } else {
            Write-Pass "docs/base/ reports are fresh (newer than BASE JSON)"
        }
    } else {
        Write-Info "Cannot check BASE freshness -- JSON or docs/base/ missing"
    }

    # MC JSON vs docs/mc/ reports
    if ((Test-Path $mcJson) -and (Test-Path $mcDocsDir)) {
        $mcJsonTime = (Get-Item $mcJson).LastWriteTime
        $staleMc = @()
        $mcReportFiles = @(Get-ChildItem $mcDocsDir -File |
            Where-Object { $_.Name -ne '.gitkeep' })
        foreach ($rf in $mcReportFiles) {
            if ($rf.LastWriteTime -lt $mcJsonTime) {
                $staleMc += $rf.Name
            }
        }
        if ($staleMc.Count -gt 0) {
            Write-Warn "docs/mc/ has $($staleMc.Count) stale report(s) older than MC JSON: $($staleMc -join ', ')"
        } else {
            Write-Pass "docs/mc/ reports are fresh (newer than MC JSON)"
        }
    } elseif (Test-Path $mcJson) {
        Write-Info "Cannot check MC freshness -- docs/mc/ missing"
    }

    # ── CHECK 8: JSON Internal Provider Name ──────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 8: JSON Internal Provider Name ---" 'Yellow'

    # Check the active root JSON (resolved in CHECK 3), plus any legacy BASE/MC siblings still present.
    $jsonFilesToCheck = @()
    if ($activeJson) { $jsonFilesToCheck += $activeJson }
    if ((Test-Path $baseJson) -and ($baseJson -ne $activeJson)) { $jsonFilesToCheck += $baseJson }
    if ((Test-Path $mcJson)   -and ($mcJson   -ne $activeJson)) { $jsonFilesToCheck += $mcJson }

    foreach ($jf in $jsonFilesToCheck) {
        $jfName = Split-Path $jf -Leaf
        try {
            $parsed = [System.IO.File]::ReadAllText($jf) | ConvertFrom-Json
            if ($parsed.bundles -and $parsed.bundles.Count -ge 2) {
                $provBundle = $parsed.bundles[1]
                $bundleName = $provBundle.name
                $bundleProvider = $provBundle.provider

                $nameOk = $bundleName -ceq $provName
                $provOk = $bundleProvider -ceq $provName

                if ($nameOk -and $provOk) {
                    Write-Pass "$jfName -- bundle[1].name='$bundleName', provider='$bundleProvider' match folder"
                } else {
                    $details = @()
                    if (-not $nameOk) { $details += "name='$bundleName' (expected '$provName')" }
                    if (-not $provOk) { $details += "provider='$bundleProvider' (expected '$provName')" }
                    Write-Fail "$jfName -- provider bundle mismatch: $($details -join '; ')"
                }
            } else {
                Write-Fail "$jfName -- JSON has fewer than 2 bundles"
            }
        } catch {
            Write-Fail "$jfName -- JSON parse error: $($_.Exception.Message)"
        }
    }

    if ($jsonFilesToCheck.Count -eq 0) {
        Write-Info "No JSON files found to check internal provider name"
    }

    # ── CHECK 9: Source Materials ─────────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 9: Source Materials ---" 'Yellow'

    # Metadata XML
    $sourceXml = Join-Path $sourceDir "${provName}.xml"
    # Case-insensitive check (some providers have .XML)
    $xmlExists = $false
    if (Test-Path $sourceDir) {
        $xmlMatch = Get-ChildItem $sourceDir -File | Where-Object {
            $_.Name -ieq "${provName}.xml"
        }
        if ($xmlMatch) { $xmlExists = $true }
    }

    if ($xmlExists) {
        Write-Pass "source/${provName}.xml exists"
    } else {
        Write-Fail "source/${provName}.xml missing (metadata XML)"
    }

    # Devdoc PDF (either <PROVIDER>.pdf or <PROVIDER>_OFML.pdf)
    $pdfExists = $false
    if (Test-Path $sourceDir) {
        $pdfMatch = Get-ChildItem $sourceDir -File -Filter '*.pdf' | Where-Object {
            $_.Name -imatch "^${provName}"
        }
        if ($pdfMatch) { $pdfExists = $true }
    }

    if ($pdfExists) {
        Write-Pass "source/${provName}*.pdf exists (devdoc)"
    } else {
        Write-Warn "source/${provName}*.pdf missing (devdoc PDF)"
    }

    # ── CHECK 10: Phase Archives ──────────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 10: Phase Archives ---" 'Yellow'

    $phasesBaseDir = Join-Path $provRoot 'phases\base'
    $phasesMcDir = Join-Path $provRoot 'phases\mc'

    if (Test-Path $phasesBaseDir) {
        $baseSnapshots = @(Get-ChildItem $phasesBaseDir -File -Filter '*.json')
        if ($baseSnapshots.Count -gt 0) {
            Write-Pass "phases/base/ has $($baseSnapshots.Count) snapshot(s)"
        } else {
            Write-Warn "phases/base/ is empty (no JSON snapshots)"
        }
    } else {
        Write-Info "phases/base/ does not exist"
    }

    if (Test-Path $phasesMcDir) {
        $mcSnapshots = @(Get-ChildItem $phasesMcDir -File -Filter '*.json')
        if ($mcSnapshots.Count -gt 0) {
            Write-Pass "phases/mc/ has $($mcSnapshots.Count) snapshot(s)"
        } else {
            Write-Warn "phases/mc/ is empty (no JSON snapshots)"
        }
    } else {
        Write-Info "phases/mc/ does not exist"
    }

    # ── CHECK 11: Release Bundle ──────────────────────────────────────────────

    Out-Line ""
    Out-Line "--- CHECK 11: Release Bundle ---" 'Yellow'

    $releaseDir = Join-Path $provRoot 'release'
    if (Test-Path $releaseDir) {
        $releaseFiles = @(Get-ChildItem $releaseDir -File |
            Where-Object { $_.Name -ne '.gitkeep' })

        if ($releaseFiles.Count -eq 0) {
            Write-Warn "release/ is empty (no release bundle yet)"
        } else {
            # Should contain: MC JSON + 5 text reports + 1 HTML = 7 files
            $releaseJsons = @($releaseFiles | Where-Object { $_.Name -match '\.json$' })
            $releaseReports = @($releaseFiles | Where-Object { $_.Name -match '\.(txt|html)$' })

            if ($releaseJsons.Count -eq 0) {
                Write-Warn "release/ has no JSON file"
            } else {
                Write-Pass "release/ has $($releaseJsons.Count) JSON file(s): $($releaseJsons.Name -join ', ')"
            }

            # Check for all text report prefixes (+ LAYOUT_HTML, checked separately below)
            $missingRelease = @()
            foreach ($rp in $reportTextPrefixes) {
                $match = $releaseFiles | Where-Object { $_.Name -match "^${rp}_" }
                if (-not $match) { $missingRelease += $rp }
            }
            $htmlRelease = $releaseFiles | Where-Object { $_.Name -match '\.html$' }
            if (-not $htmlRelease) { $missingRelease += 'LAYOUT_HTML' }

            if ($missingRelease.Count -gt 0) {
                Write-Warn "release/ missing: $($missingRelease -join ', ')"
            } else {
                Write-Pass "release/ has all 6 report files"
            }
        }
    } else {
        Write-Info "release/ does not exist"
    }

    # ── Provider Summary ──────────────────────────────────────────────────────

    Out-Line ""
    if ($script:provFail -eq 0 -and $script:provWarn -eq 0) {
        Out-Line "  >> ${provName}: CLEAN ($($script:provPass)P / 0F / 0W)" 'Green'
        $script:cleanProviders.Add($provName)
    } else {
        $summary = "${provName}: $($script:provPass)P / $($script:provFail)F / $($script:provWarn)W"
        if ($script:provFail -gt 0) {
            Out-Line "  >> $summary" 'Red'
        } else {
            Out-Line "  >> $summary" 'Yellow'
        }
        $script:issueProviders.Add($provName)
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

$checkedCount = $script:cleanProviders.Count + $script:issueProviders.Count

Out-Line ""
Out-Line "========================================" 'Cyan'
Out-Line " STRUCTURE AUDIT SUMMARY" 'Cyan'
Out-Line "========================================" 'Cyan'
Out-Line ""
Out-Line "Providers checked: $checkedCount"
Out-Line "  CLEAN: $($script:cleanProviders.Count)"

if ($script:issueProviders.Count -gt 0) {
    Out-Line "  ISSUES: $($script:issueProviders.Count) ($($script:issueProviders -join ', '))" 'Yellow'
} else {
    Out-Line "  ISSUES: 0" 'Green'
}

Out-Line ""
Out-Line "Total: $($script:totalPass) PASS / $($script:totalFail) FAIL / $($script:totalWarn) WARN"

if ($script:totalFail -gt 0) {
    Out-Line "" 'Red'
    Out-Line "RESULT: ISSUES FOUND" 'Red'
} else {
    Out-Line "" 'Green'
    Out-Line "RESULT: ALL CLEAN" 'Green'
}

Out-Line "========================================" 'Cyan'
Out-Line ""

# ── Write to file if requested ────────────────────────────────────────────────

if ($OutFile) {
    $script:outputBuffer | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "Report saved to: $OutFile" -ForegroundColor Green
}
