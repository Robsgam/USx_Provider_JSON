<#
  enforce.ps1 -- Mandatory post-build enforcement gate
  DESCRIBED IN: CLAUDE.md (tools table + Workflow section), README.txt (line ~327)
  Single command that runs ALL verification. Nothing is done until this passes.

  5 phases:
    1. Build freshness    -- reports exist and are newer than JSONs
    2. Validator scores   -- 0 FAIL / 0 WARN on every provider
    3. Doc version sync   -- build script version matches 6 doc locations
       (CLAUDE.md, STATUS, SQVR, JSON_INVENTORY, BUILD_NOTES + date checksum, REBUILD_TRACKER)
    4. Cross-provider     -- field types, defaults, code types consistent
    5. Repo integrity     -- audit_repo.ps1 passes, git status clean

  Usage:
    .\enforce.ps1                     # full check on all providers
    .\enforce.ps1 -Provider HI_HCJDC_OFML   # single provider (still runs cross-provider)
    .\enforce.ps1 -SkipGit            # skip git status check (for mid-work runs)
    .\enforce.ps1 -Rebuild            # auto-rebuild stale providers before checking
    .\enforce.ps1 -Reproducible       # also re-run each build twice to scratch and
                                      #   confirm committed JSON == fresh build (heavy; opt-in)
    .\enforce.ps1 -OutFile report.txt # save full output to file

  Exit code 0 = ENFORCED (all gates pass). Exit code 1 = BLOCKED (fix before declaring done).
#>

param(
    [string]$Provider,
    [switch]$SkipGit,
    [switch]$Rebuild,
    [switch]$Reproducible,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir   = $PSScriptRoot
$repoRoot  = (Resolve-Path "$toolDir\..").Path
$provDir   = Join-Path $repoRoot "providers"
$claudeMd  = Join-Path $repoRoot "CLAUDE.md"
$tracker   = Join-Path $repoRoot "REBUILD_TRACKER.md"

# docs/ reorg pilot (2026-07-01, NJ_NJCJIS first) -- Find-DocsPath checks the new category
# folder first, falls back to flat docs/ (every provider that hasn't migrated yet).
. "$toolDir\_resolve_docs_path.ps1"
. "$toolDir\_resolve_provider_json.ps1"

# ── Output + counters ────────────────────────────────────────────────────────
$script:outputLines = @()
$script:failCount   = 0
$script:warnCount   = 0
$script:passCount   = 0
$script:infoCount   = 0
$script:fixedCount  = 0

function Out($msg) {
    $script:outputLines += $msg
    Write-Host $msg
}

function Fail($msg) {
    $script:outputLines += "  [FAIL] $msg"
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $script:failCount++
}

function Warn($msg) {
    $script:outputLines += "  [WARN] $msg"
    Write-Host "  [WARN] $msg" -ForegroundColor Yellow
    $script:warnCount++
}

function Pass($msg) {
    $script:outputLines += "  [PASS] $msg"
    Write-Host "  [PASS] $msg" -ForegroundColor Green
    $script:passCount++
}

function Info($msg) {
    $script:outputLines += "  [INFO] $msg"
    Write-Host "  [INFO] $msg" -ForegroundColor Gray
    $script:infoCount++
}

function Fixed($msg) {
    $script:outputLines += "  [FIXED] $msg"
    Write-Host "  [FIXED] $msg" -ForegroundColor Magenta
    $script:fixedCount++
}

function SectionHeader($title) {
    $line = "=" * 60
    Out ""
    Out $line
    Out "  $title"
    Out $line
}

# ── Provider discovery ────────────────────────────────────────────────────────
function Get-ProviderList {
    $dirs = Get-ChildItem $provDir -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName "scripts"))
    }
    if ($Provider) {
        $dirs = $dirs | Where-Object { $_.Name -eq $Provider }
        if ($dirs.Count -eq 0) {
            Write-Error "Provider not found: $Provider"
            exit 1
        }
    }
    return $dirs
}

function Get-ScriptVersion($provPath) {
    # Single script model: find the build script (not _mc, not _old)
    $scripts = Get-ChildItem (Join-Path $provPath "scripts") -Filter "build_*" -File |
        Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' }
    # Legacy fallback: _mc script for providers not yet migrated
    if ($scripts.Count -eq 0) {
        $scripts = Get-ChildItem (Join-Path $provPath "scripts") -Filter "build_*_mc*" -File
    }
    if ($scripts.Count -eq 0) { return $null }
    $text = [System.IO.File]::ReadAllText($scripts[0].FullName)
    if ($text -match '\$Version\s*=\s*["'']([^"'']+)["'']') {
        return $Matches[1]
    }
    return $null
}

# ── Parse validator report ────────────────────────────────────────────────────
function Parse-Report($path) {
    if (-not (Test-Path $path)) { return $null }
    $text = [System.IO.File]::ReadAllText($path)
    if ($text -match 'RESULTS:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN') {
        return @{
            Pass = [int]$Matches[1]
            Fail = [int]$Matches[2]
            Warn = [int]$Matches[3]
        }
    }
    return $null
}

# ── Build-manifest trust chain (Workstream 0; closes findings A/B/C) ──
# Phase 1 loads each provider's BUILD_MANIFEST and verifies its sourceSha256 ==
# the live JSON hash (auto-rerunning build_report on mismatch). Verified manifests
# are stashed here so Phase 2/2b/2c can confirm each report it scores is the exact
# file build_report produced from the current JSON, and carries real checks.
$script:Manifests = @{}

# Returns @{ok=$bool; reason=$str}. ok only when the report exists, its live SHA
# matches the manifest entry recorded at build time, and checksRun > 0.
function Test-ReportTrusted($provName, $reportPath) {
    $man = $script:Manifests[$provName]
    if (-not $man)                  { return @{ ok=$false; reason='no verified build manifest' } }
    if (-not (Test-Path $reportPath)) { return @{ ok=$false; reason='report file missing' } }
    $leaf  = Split-Path $reportPath -Leaf
    $entry = $man.reports.$leaf
    if (-not $entry)                { return @{ ok=$false; reason="'$leaf' not in manifest" } }
    $liveSha = (Get-FileHash -Path $reportPath -Algorithm SHA256).Hash
    if ($liveSha -ne $entry.sha256) { return @{ ok=$false; reason='report SHA != manifest (edited/stale) -- Recovery: run build_report.ps1 -Path <provider>.json' } }
    if ([int]$entry.checksRun -le 0){ return @{ ok=$false; reason='report contentless (0 checks)' } }
    return @{ ok=$true; reason='' }
}

# ══════════════════════════════════════════════════════════════════════════════
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Out ""
Out ("=" * 60)
Out "  ENFORCE -- Mandatory Verification Gate"
Out "  $timestamp"
if ($Provider) { Out "  Scope: $Provider" }
else           { Out "  Scope: ALL providers" }
Out ("=" * 60)

$providers = Get-ProviderList
$claudeText = [System.IO.File]::ReadAllText($claudeMd)

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1: Build Freshness
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 1: Build Freshness"

foreach ($pd in $providers) {
    $provName = $pd.Name
    $docPrefix = $provName

    # ── Pending-updates gate (blocks testing when a rebuild is required) ──
    $pendingFile = Find-DocsPath $pd.FullName 'tracking' "PENDING_UPDATES.txt"
    if (Test-Path $pendingFile) {
        $pendingLines = Get-Content $pendingFile | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') }
        if ($pendingLines) {
            Fail "$provName -- PENDING_UPDATES.txt has unresolved items (rebuild before testing):"
            foreach ($ln in $pendingLines) { Out "      $ln" }
        }
    }

    # Find JSON: new naming (<PROVIDER>.json or <PROVIDER>_vX.Y.json) or legacy (_BASE/_MC)
    $provJson = Get-ChildItem $pd.FullName -Filter "${docPrefix}.json" -File -ErrorAction SilentlyContinue
    if (-not $provJson) {
        $provJsonVer = @(Get-ChildItem $pd.FullName -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^${docPrefix}_v[\d.]+\.json$" })
        if ($provJsonVer.Count -gt 1) { Fail "$provName -- multiple versioned JSONs in root (keep only one)" }
        $provJson = $provJsonVer | Select-Object -First 1
    }
    $baseJson = Get-ChildItem $pd.FullName -Filter "${docPrefix}_BASE.json" -File -ErrorAction SilentlyContinue
    $mcJson   = Get-ChildItem $pd.FullName -Filter "${docPrefix}_MC.json" -File -ErrorAction SilentlyContinue

    # ONE JSON IN ROOT (legacy _BASE/_MC providers exempt -- convert on scheduled rebuild)
    $legacyProviders = @('AZ_AZDPS','CA_CLETS_OCATS','CA_eSUN','CA_SAN_LUIS_OBISPO',
        'CA_VENTURA_COUNTY','HI_HCJDC_OFML','IL_LEADS_OFML','LA_LEMS','MD_METERS',
        'NM_NMLETS_OFML','OH_LEADS','OR_LEDS','TN_TIES')
    $jsonCount = @($provJson, $baseJson, $mcJson | Where-Object { $_ }).Count
    if ($jsonCount -gt 1) {
        if ($provName -in $legacyProviders) {
            Info "$provName -- multiple JSONs in root (legacy, convert on rebuild)"
        } else {
            Fail "$provName -- multiple JSONs in root (one-JSON-in-root rule)"
        }
    }
    if ($jsonCount -eq 0) {
        Info "$provName -- no JSON found in root"
        continue
    }

    # Pick the active JSON
    $activeJson = if ($provJson) { $provJson } elseif ($mcJson) { $mcJson } else { $baseJson }

    # Check reports -- try docs/reports/ (migrated) or flat docs/ (not yet migrated), then
    # docs/mc/ or docs/base/ (legacy BASE/MC variant, unrelated to the reorg)
    $docsDir = Join-Path $pd.FullName "docs"
    $validatorReport = Find-DocsPath $pd.FullName 'reports' "VALIDATOR_REPORT_${docPrefix}.txt"
    if (-not (Test-Path $validatorReport)) {
        $validatorReport = Join-Path $docsDir "mc\VALIDATOR_REPORT_${docPrefix}_MC.txt"
    }
    if (-not (Test-Path $validatorReport)) {
        $validatorReport = Join-Path $docsDir "base\VALIDATOR_REPORT_${docPrefix}_BASE.txt"
    }

    # ── Build-manifest hash gate (replaces gameable LastWriteTime check) ──
    # Trust a provider's reports only when its BUILD_MANIFEST records a sourceSha256
    # equal to the live JSON hash. On mismatch/missing, auto-rerun build_report once
    # and re-read (Workstream 0.1/0.2). A SHA match guarantees the reports describe
    # the JSON on disk -- timestamps can't be gamed and re-touching can't fake it.
    $manifestFile = Find-DocsPath $pd.FullName 'tracking' "BUILD_MANIFEST_${docPrefix}.json"
    if (-not (Test-Path $manifestFile)) { $manifestFile = Join-Path $docsDir "mc\BUILD_MANIFEST_${docPrefix}_MC.json" }
    if (-not (Test-Path $manifestFile)) { $manifestFile = Join-Path $docsDir "base\BUILD_MANIFEST_${docPrefix}_BASE.json" }

    $liveSha = (Get-FileHash -Path $activeJson.FullName -Algorithm SHA256).Hash
    $curFp = Get-ReportToolFingerprint $toolDir   # invalidate reports when a report-tool changed, not just the JSON (audit C3)
    $man = $null
    if (Test-Path $manifestFile) {
        try { $man = Get-Content $manifestFile -Raw | ConvertFrom-Json } catch { $man = $null }
    }
    if (-not ($man -and $man.sourceSha256 -eq $liveSha -and $man.toolFingerprint -eq $curFp)) {
        Out "  $provName -- build manifest stale/missing (JSON or report-tool changed); regenerating reports..."
        & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $activeJson.FullName 2>&1 | Out-Null
        $man = $null
        if (Test-Path $manifestFile) {
            try { $man = Get-Content $manifestFile -Raw | ConvertFrom-Json } catch { $man = $null }
        }
    }
    if ($man -and $man.sourceSha256 -eq $liveSha -and $man.toolFingerprint -eq $curFp) {
        $script:Manifests[$provName] = $man
        Pass "$provName -- reports match live JSON + current report-tools (SHA $($liveSha.Substring(0,12))...)"
    } else {
        Fail "$provName -- build manifest missing or != live JSON after rebuild (reports NOT trustworthy)"
    }

    # Check phase archive exists for current version. `phases/` is being retired provider-by-
    # provider (git history is authoritative instead, starting with NJ_NJCJIS 2026-07-01) -- if
    # NONE of the phase dirs exist at all, treat that as an opted-out provider and skip rather
    # than FAIL; if the dir exists but is just missing this version's snapshot, that's still a
    # real gap (someone forgot to archive this rebuild).
    $version = Get-ScriptVersion $pd.FullName
    if ($version) {
        # Check phases/ (new), phases/current/ (single-JSON), then phases/base/ and phases/mc/ (legacy)
        $phaseDirsChecked = @("phases", "phases\current", "phases\base", "phases\mc")
        $anyPhaseDirExists = $false
        $phaseFile = $null
        foreach ($phaseDir in $phaseDirsChecked) {
            $pDir = Join-Path $pd.FullName $phaseDir
            if (Test-Path $pDir) {
                $anyPhaseDirExists = $true
                $phaseFile = Get-ChildItem $pDir -Filter "${docPrefix}*v${version}*.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($phaseFile) { break }
            }
        }
        if ($phaseFile) {
            Pass "$provName -- phase archive exists for v${version}"
        } elseif (-not $anyPhaseDirExists) {
            Pass "$provName -- phases/ retired for this provider (git history is authoritative)"
        } else {
            Fail "$provName -- no phase archive for v${version}"
        }
    }

    # TEST_MATRIX freshness -- only for new-model providers (<PROVIDER>.json + build script)
    # If the matrix predates the JSON, the test instructions are stale relative to the
    # shipped JSON (a version bump changes combos; matrix must be regenerated via build_report).
    if ($version -and $provJson) {
        $testMatrixFile = Find-DocsPath $pd.FullName 'reports' "${docPrefix}_TEST_MATRIX.txt"
        if (Test-Path $testMatrixFile) {
            $matrixTime = (Get-Item $testMatrixFile).LastWriteTime
            $jsonTime   = $provJson.LastWriteTime
            $graceSec   = 300  # 5-min grace: pipeline generates matrix after JSON; allow pipeline to finish
            if (($jsonTime - $matrixTime).TotalSeconds -gt $graceSec) {
                Fail "$provName -- TEST_MATRIX predates JSON by $([int]($jsonTime - $matrixTime).TotalMinutes)m (regenerate via build_report)"
            } else {
                Pass "$provName -- TEST_MATRIX fresh"
            }
        } else {
            Fail "$provName -- TEST_MATRIX missing (generate via build_report)"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2: Validator Scores
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2: Validator Scores"

foreach ($pd in $providers) {
    $provName = $pd.Name
    $docPrefix = $provName

    foreach ($variant in @('', 'MC', 'BASE')) {
        if ($variant -eq '') {
            $reportPath = Find-DocsPath $pd.FullName 'reports' "VALIDATOR_REPORT_${docPrefix}.txt"
        } elseif ($variant -eq 'MC') {
            $reportPath = Join-Path $pd.FullName "docs\mc\VALIDATOR_REPORT_${docPrefix}_MC.txt"
        } else {
            $reportPath = Join-Path $pd.FullName "docs\base\VALIDATOR_REPORT_${docPrefix}_BASE.txt"
        }

        if (-not (Test-Path $reportPath)) { continue }

        $label = if ($variant) { "$provName ($variant)" } else { $provName }
        $trust = Test-ReportTrusted $provName $reportPath
        if (-not $trust.ok) {
            Fail "$label -- validator report not trusted: $($trust.reason)"
            break
        }
        $result = Parse-Report $reportPath
        if (-not $result) {
            Fail "$label -- cannot parse validator report"
            continue
        }

        if ($result.Fail -gt 0) {
            Fail "$label -- $($result.Pass)P/$($result.Fail)F/$($result.Warn)W"
        } elseif ($result.Warn -gt 0) {
            Warn "$label -- $($result.Pass)P/0F/$($result.Warn)W (WARNs remain)"
        } else {
            Pass "$label -- $($result.Pass)P/0F/0W"
        }
        break  # found a valid report, skip remaining variants
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2b: Metadata Divergence Gate
#  Blocks on unexplained set/any divergences and defaulted-field-in-set[] (see
#  audit_metadata CHECK 4 / 4d). Principled (defaulted->any) and registry-accepted
#  divergences are [NOTE], not [FAIL]. Reads the report regenerated by build_report.
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2b: Metadata Divergence Gate"

foreach ($pd in $providers) {
    $provName = $pd.Name
    $mdReport = Find-DocsPath $pd.FullName 'reports' "METADATA_AUDIT_${provName}.txt"
    if (-not (Test-Path $mdReport)) {
        $mdReportMc = Join-Path $pd.FullName "docs\mc\METADATA_AUDIT_${provName}_MC.txt"
        if (Test-Path $mdReportMc) { $mdReport = $mdReportMc }
        else { Info "$provName -- no metadata audit report (run build_report)"; continue }
    }
    $trust = Test-ReportTrusted $provName $mdReport
    if (-not $trust.ok) {
        Fail "$provName -- metadata audit not trusted: $($trust.reason)"
        continue
    }
    $mdText  = [System.IO.File]::ReadAllText($mdReport)
    $mdFails = ([regex]::Matches($mdText, '\[FAIL\]')).Count
    if ($mdFails -gt 0) {
        Fail "$provName -- $mdFails metadata divergence FAIL(s) -- fix build or record in ${provName}_ACCEPTED_DIVERGENCES.txt (see METADATA_AUDIT)"
    } else {
        Pass "$provName -- metadata divergences clean"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2c: Structural Verification + CAD Gates
#  Reads the VERIFY_REPORT (verify_build CHECKs 1-14) and CAD_AUDIT (audit_cad)
#  reports regenerated by build_report. Previously these tools ran in build_report
#  but their FAIL/WARN never gated the "clean" verdict -- a provider could be
#  "enforce clean" while verify_build/audit_cad had real FAILs (the identifier-
#  priority guardrail gap, Attention/vehicleTypeCode CAD-default gaps, gate-xor-
#  companion contradictions). FAIL blocks; WARN surfaces. (Wired 2026-06-23.)
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2c: Structural Verification + CAD Gates"

foreach ($pd in $providers) {
    $provName = $pd.Name
    foreach ($spec in @(
        @{ label = 'verify_build'; base = "VERIFY_REPORT_${provName}.txt" },
        @{ label = 'audit_cad';    base = "CAD_AUDIT_${provName}.txt" }
    )) {
        $rpt = Find-DocsPath $pd.FullName 'reports' $spec.base
        if (-not (Test-Path $rpt)) {
            $rptMc = Join-Path $pd.FullName ("docs\mc\" + ($spec.base -replace '\.txt$','_MC.txt'))
            if (Test-Path $rptMc) { $rpt = $rptMc }
            else { Info "$provName -- no $($spec.label) report (run build_report)"; continue }
        }
        $trust = Test-ReportTrusted $provName $rpt
        if (-not $trust.ok) {
            Fail "$provName $($spec.label) -- report not trusted: $($trust.reason)"
            continue
        }
        $txt   = [System.IO.File]::ReadAllText($rpt)
        $fails = ([regex]::Matches($txt, '\[FAIL\]')).Count
        $warns = ([regex]::Matches($txt, '\[WARN\]')).Count
        if ($fails -gt 0) {
            Fail "$provName $($spec.label) -- $fails FAIL / $warns WARN (see docs\$($spec.base))"
        } elseif ($warns -gt 0) {
            Warn "$provName $($spec.label) -- $warns WARN (see docs\$($spec.base))"
        } else {
            Pass "$provName $($spec.label) -- clean"
        }
    }

    # Canonical folder structure (live audit_structure.ps1). Provider-SCOPED gate: a structure
    # FAIL blocks only when enforcing that specific provider (-Provider); on a bare portfolio-wide
    # run it downgrades to WARN so out-of-scope legacy stubs (e.g. TX_TLETS_CCH) don't block the
    # whole portfolio. Run live -- audit_structure reads the folder tree, not a cached report.
    $structOut = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_structure.ps1" -Path $pd.FullName 2>&1 | Out-String
    $sFail = ([regex]::Matches($structOut, '\[FAIL\]')).Count
    $sWarn = ([regex]::Matches($structOut, '\[WARN\]')).Count
    if ($sFail -gt 0) {
        if ($Provider) {
            Fail "$provName structure -- $sFail FAIL / $sWarn WARN (audit_structure)"
        } else {
            Warn "$provName structure -- $sFail FAIL / $sWarn WARN (run 'enforce -Provider $provName' to gate)"
        }
        $structOut -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object { Out "       $($_.Trim())" }
    } elseif ($sWarn -gt 0) {
        Warn "$provName structure -- $sWarn WARN (audit_structure)"
    } else {
        Pass "$provName structure -- clean"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2d: Simulator Parity (tool integrity, provider-agnostic)
#  Guards that test_commsys.ps1 and run_test_matrix.ps1 still share one canonical
#  condition predicate (_sim_helpers.ps1) and have not drifted back to the
#  attribute-name-first model that masked the HI v3.2 inert-condition bug (finding
#  H). Run live -- it audits the tools, not a cached report.
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2d: Simulator Parity"
$parityTool = Join-Path $toolDir "audit_simulator_parity.ps1"
if (Test-Path $parityTool) {
    $parityOut = & powershell -ExecutionPolicy Bypass -File $parityTool 2>&1 | Out-String
    $pm = [regex]::Match($parityOut, 'RESULTS:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL')
    $parityFail = if ($pm.Success) { [int]$pm.Groups[2].Value } else { 1 }
    if ($parityFail -gt 0) {
        Fail "simulator parity -- $parityFail FAIL (test_commsys/run_test_matrix drifted; run audit_simulator_parity.ps1)"
    } else {
        Pass "simulator parity -- test_commsys and run_test_matrix share canonical predicate"
    }
} else {
    Fail "simulator parity -- audit_simulator_parity.ps1 not found"
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2e: Supported-Query (Devdoc) Gate
#  Reads the SUPPORTED_QUERY_AUDIT report (audit_supported_queries.ps1) -- the only
#  check that confirms a combo is a provider-SUPPORTED query, not just internally
#  consistent (finding F). FAILs only when the extract is CONFIRMED (signed off vs
#  devdoc) and a combo is unsupported; PROVISIONAL extracts surface as INFO.
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2e: Supported-Query (Devdoc) Gate"
foreach ($pd in $providers) {
    $provName = $pd.Name
    $docPrefix = $provName
    $sqReport = Find-DocsPath $pd.FullName 'reports' "SUPPORTED_QUERY_AUDIT_${docPrefix}.txt"
    if (-not (Test-Path $sqReport)) {
        $sqReportMc = Join-Path $pd.FullName "docs\mc\SUPPORTED_QUERY_AUDIT_${docPrefix}_MC.txt"
        if (Test-Path $sqReportMc) { $sqReport = $sqReportMc }
        else { Info "$provName -- no supported-query audit (run build_report)"; continue }
    }
    $trust = Test-ReportTrusted $provName $sqReport
    if (-not $trust.ok) {
        Fail "$provName -- supported-query audit not trusted: $($trust.reason)"
        continue
    }
    $sqText  = [System.IO.File]::ReadAllText($sqReport)
    $sqFails = ([regex]::Matches($sqText, '\[FAIL\]')).Count
    $isProvisional = ($sqText -match '(?m)^Extract STATUS:\s*PROVISIONAL')
    if ($sqFails -gt 0) {
        Fail "$provName -- $sqFails unsupported combo(s) vs devdoc (see SUPPORTED_QUERY_AUDIT)"
    } elseif ($isProvisional) {
        Info "$provName -- supported-query extract PROVISIONAL (confirm vs devdoc, then set STATUS: CONFIRMED to gate)"
    } else {
        Pass "$provName -- all combos devdoc-supported (CONFIRMED)"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2f: Build Reproducibility (-Reproducible, OR auto-on for a single -Provider run)
#  Re-runs each provider's build script twice into scratch and compares vs the committed
#  JSON (audit_reproducible.ps1). Confirms committed == fresh build. Heavy (a real build
#  per provider), so a FULL-portfolio enforce keeps it opt-in (-Reproducible); a single
#  -Provider run is cheap (2 builds) and runs it automatically -- closing the gap where the
#  reproducibility gospel was verified only on explicit opt-in (audit C1 finding 2026-07-24).
#  Non-determinism = FAIL; deterministic-but-stale commit = WARN (rebuild that provider).
# ══════════════════════════════════════════════════════════════════════════════
if ($Reproducible -or $Provider) {
    SectionHeader "PHASE 2f: Build Reproducibility"
    $reproTool = Join-Path $toolDir "audit_reproducible.ps1"
    if (-not (Test-Path $reproTool)) {
        Fail "audit_reproducible.ps1 not found"
    } else {
        foreach ($pd in $providers) {
            $provName = $pd.Name
            $rjson = Get-ChildItem $pd.FullName -Filter "${provName}.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $rjson) {
                $rjson = @(Get-ChildItem $pd.FullName -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "^${provName}_v[\d.]+\.json$" }) | Select-Object -First 1
            }
            if (-not $rjson) { Info "$provName -- no <PROVIDER>.json (legacy); reproducibility skipped"; continue }
            if (-not (Test-Path (Join-Path $pd.FullName 'scripts'))) { Info "$provName -- no scripts/; reproducibility skipped"; continue }
            $rout = & powershell -ExecutionPolicy Bypass -File $reproTool -Path $rjson.FullName 2>&1 | Out-String
            $rm = [regex]::Match($rout, 'RESULTS:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN')
            $rfail = if ($rm.Success) { [int]$rm.Groups[2].Value } else { 1 }
            $rwarn = if ($rm.Success) { [int]$rm.Groups[3].Value } else { 0 }
            if ($rfail -gt 0)      { Fail "$provName -- build NON-DETERMINISTIC or build failed (see audit_reproducible)" }
            elseif ($rwarn -gt 0)  { Warn "$provName -- committed JSON STALE vs fresh build (rebuild needed)" }
            else                   { Pass "$provName -- committed JSON == fresh build (reproducible & current)" }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2g: Base<->Variant Lockstep (audit_variant_sync.ps1)
#  A variant (build script declares `# BASE-SYNC: <BASE> vX.Y`) must not fall behind its
#  base's current version. This real-teeth check previously ran ONLY in doctor.ps1, which no
#  mandatory path invokes -- so a base bump could silently leave a variant stale (TX_TLETS_CCH
#  once fell ~4 versions behind). Wired into enforce 2026-07-24 (audit C1 finding).
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2g: Base<->Variant Lockstep"
$vsTool = Join-Path $toolDir "audit_variant_sync.ps1"
if (-not (Test-Path $vsTool)) {
    Info "audit_variant_sync.ps1 not found -- lockstep check skipped"
} else {
    $vsOut = & powershell -ExecutionPolicy Bypass -File $vsTool 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Fail "Base<->variant lockstep: a variant's BASE-SYNC marker is behind its base (run audit_variant_sync.ps1)"
        $vsOut -split "`n" | Where-Object { $_ -match 'FAIL|behind|drift|re-sync|BASE-SYNC' } | Select-Object -First 6 | ForEach-Object { Out "       $($_.Trim())" }
    } else {
        Pass "Base<->variant lockstep: all declared variants synced to their base"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2h: Combo Reachability (dead-combo gate, audit_combo_reachability.ps1)
#  The platform fires the FIRST matching combination, so a combo is DEAD if one
#  ordered before it matches whenever it does. The silent case is a sibling whose
#  extra set[] fields are all form-prefilled (initialValue) -- it always wins, and
#  nothing else catches it: the combo validates, counts toward coverage, and can
#  carry a PASS log, because the wire XML has no keyRef so a log named for the dead
#  combo is indistinguishable from one where its shadower fired.
#  Run live -- this reads the JSON, not a cached report. Registered dead-combo
#  divergences report [NOTE] and do not block.
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2h: Combo Reachability"
$reachTool = Join-Path $toolDir "audit_combo_reachability.ps1"
if (-not (Test-Path $reachTool)) {
    Info "audit_combo_reachability.ps1 not found -- dead-combo check skipped"
} else {
    foreach ($pd in $providers) {
        $provName = $pd.Name
        $reachJson = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $provName
        if (-not $reachJson) { Info "$provName -- no root JSON, reachability skipped"; continue }
        $reachOut = & powershell -ExecutionPolicy Bypass -File $reachTool -Path $reachJson 2>&1 | Out-String
        $rm = [regex]::Match($reachOut, '\[FAIL\]\s*(\d+)\s*dead combination')
        if ($rm.Success) {
            Fail "$provName -- $($rm.Groups[1].Value) DEAD combo(s): unreachable under first-match ordering (run audit_combo_reachability.ps1)"
            $reachOut -split "`n" | Where-Object { $_ -match 'DEAD COMBO|never fires' } |
                Select-Object -First 8 | ForEach-Object { Out "       $($_.Trim())" }
        } else {
            $noteCount = ([regex]::Matches($reachOut, '\[NOTE\] DEAD COMBO')).Count
            $sfx = if ($noteCount -gt 0) { " ($noteCount accepted dead-combo divergence(s))" } else { "" }
            Pass "$provName -- all combos reachable$sfx"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2i: Log Combo Attribution (audit_log_combo_attribution.ps1)
#  Does each saved log's NAMED combo match what actually fired? The wire XML carries no
#  keyRef, so this was previously unverifiable and a green test package could overstate
#  coverage -- 17 logs of 417 were filed under combos that never ran (found 2026-07-29).
#  Replays each log's recorded QUERY STRING; routing is existence-based so field presence
#  decides the winner. Stale logs on registered dead-combo divergences report [NOTE].
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2i: Log Combo Attribution"
$attrTool = Join-Path $toolDir "audit_log_combo_attribution.ps1"
if (-not (Test-Path $attrTool)) {
    Info "audit_log_combo_attribution.ps1 not found -- attribution check skipped"
} else {
    foreach ($pd in $providers) {
        $provName = $pd.Name
        $attrJson = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $provName
        if (-not $attrJson) { continue }
        $attrOut = & powershell -ExecutionPolicy Bypass -File $attrTool -Path $attrJson 2>&1 | Out-String
        $am = [regex]::Match($attrOut, '\[FAIL\]\s*(\d+)\s*misattributed')
        if ($am.Success) {
            Fail "$provName -- $($am.Groups[1].Value) log(s) filed under a combo that did NOT fire (run audit_log_combo_attribution.ps1)"
            $attrOut -split "`n" | Where-Object { $_ -match 'MISATTRIBUTED|NO COMBO FIRES|AMBIGUOUS' } |
                Select-Object -First 8 | ForEach-Object { Out "       $($_.Trim())" }
        } else {
            $vm = [regex]::Match($attrOut, '\[PASS\]\s*(\d+)\s*log')
            $cnt = if ($vm.Success) { $vm.Groups[1].Value } else { '0' }
            $stale = ([regex]::Matches($attrOut, '\[NOTE\] STALE LOG')).Count
            $sfx = if ($stale -gt 0) { " ($stale stale on registered dead combos)" } else { "" }
            if ([int]$cnt -eq 0) { Info "$provName -- no logs to attribute" }
            else { Pass "$provName -- $cnt log(s) attributed correctly$sfx" }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2j: SQVR Integrity (audit_sqvr_integrity.ps1)
#  The SQVR is hand-maintained prose asserting which combos exist and how many. Nothing
#  verified it, so it rotted on every combo add/remove -- and it is the document a tester
#  reads to decide what to test, so rot converts straight into wasted tenant-test time.
#  Caught 2026-07-29: TX_TLETS listed the QV combos removed at v4.9 + "21 combos (7 Vehicle)";
#  AZ_AZDPS still had the v3.3-deleted WMPI combos as [PENDING] work + "8 QIDMs / 18 combos".
#  Blocks explicitly marked DORMANT / REMOVED / NOT BUILT / OUT OF SCOPE report [NOTE].
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2j: SQVR Integrity"
$sqvrTool = Join-Path $toolDir "audit_sqvr_integrity.ps1"
if (-not (Test-Path $sqvrTool)) {
    Info "audit_sqvr_integrity.ps1 not found -- SQVR integrity check skipped"
} else {
    foreach ($pd in $providers) {
        $provName = $pd.Name
        $sqJson = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $provName
        if (-not $sqJson) { continue }
        $sqOut = & powershell -ExecutionPolicy Bypass -File $sqvrTool -Path $sqJson 2>&1 | Out-String
        $sm = [regex]::Match($sqOut, '\[FAIL\]\s*(\d+)\s*stale SQVR')
        if ($sm.Success) {
            Fail "$provName -- $($sm.Groups[1].Value) stale SQVR assertion(s) (run audit_sqvr_integrity.ps1)"
            $sqOut -split "`n" | Where-Object { $_ -match 'STALE:|stated |Architecture line|SQVR says' } |
                Select-Object -First 6 | ForEach-Object { Out "       $($_.Trim())" }
        } elseif ($sqOut -match '\[INFO\] no SQVR file') {
            Info "$provName -- no SQVR file"
        } else {
            $nn = ([regex]::Matches($sqOut, '\[NOTE\]')).Count
            $s2 = if ($nn -gt 0) { " ($nn documented-unbuilt note(s))" } else { "" }
            Pass "$provName -- SQVR consistent with the JSON$s2"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2k: Rendered Form Review (audit_form_review.ps1) -- ADVISORY, never blocks
#  Every other gate proves the REQUEST is correct. None proves the FORM is usable. Through
#  2026-07 every label/title/layout defect was caught by a human opening the rendered form --
#  a card titled "NCIC FIREARM QUERY" among "SEARCH BY" siblings, "Sex (optional)" beside
#  "Date of Birth (required with Name)", fields wrapping mid-row. No tool flagged any of them.
#  This records WHICH BUILD a human actually reviewed. Advisory because a review is a human
#  act that must not be manufacturable to satisfy a gate.
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2k: Rendered Form Review (advisory)"
$fbTool = Join-Path $toolDir "audit_form_review.ps1"
if (-not (Test-Path $fbTool)) {
    Info "audit_form_review.ps1 not found -- form-review check skipped"
} else {
    foreach ($pd in $providers) {
        $provName = $pd.Name
        $fbJson = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $provName
        if (-not $fbJson) { continue }
        $fbOut = & powershell -ExecutionPolicy Bypass -File $fbTool -Path $fbJson 2>&1 | Out-String
        if ($fbOut -match '\[PASS\]\s*(v[\d.]+) reviewed') {
            Pass "$provName -- rendered form reviewed at $($Matches[1])"
        } else {
            $why = if ($fbOut -match 'no form-review record') { 'never reviewed' }
                   elseif ($fbOut -match 'no review recorded at') { 'not reviewed at current build' }
                   elseif ($fbOut -match 'CHANGES-REQUESTED') { 'CHANGES-REQUESTED outstanding' }
                   else { 'no review on record' }
            Info "$provName -- $why (advisory; tools\audit_form_review.ps1 -Record)"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2l: Session State (audit_session_state.ps1)
#  SESSION_STATE.md is injected into every new session by the SessionStart hook, so its whole
#  value is being TRUSTED on restart -- which makes a stale one worse than none. Its predecessor
#  (a memory file, not in git, appended to instead of replaced) drifted badly enough to cost ~an
#  hour of re-prompting per restart on 2026-07-29. Committed AND verified, so it cannot rot the
#  same way. Provider-agnostic: runs once, not per provider.
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 2l: Session State"
$ssTool = Join-Path $toolDir "audit_session_state.ps1"
if (-not (Test-Path $ssTool)) {
    Info "audit_session_state.ps1 not found -- session-state check skipped"
} else {
    $ssOut = & powershell -ExecutionPolicy Bypass -File $ssTool 2>&1 | Out-String
    $sm = [regex]::Match($ssOut, '\[FAIL\]\s*(\d+)\s*stale claim')
    if ($sm.Success -or $ssOut -match '\[FAIL\] SESSION_STATE\.md is MISSING') {
        Fail "SESSION_STATE.md is stale or missing -- the next session will pick up wrong (run audit_session_state.ps1)"
        $ssOut -split "`n" | Where-Object { $_ -match '^\s*\[FAIL\]' } | Select-Object -First 6 | ForEach-Object { Out "       $($_.Trim())" }
    } else {
        Pass "SESSION_STATE.md consistent with the repo (pick-up point is trustworthy)"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 3: Documentation Version Sync
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 3: Doc Version Sync"

foreach ($pd in $providers) {
    $provName = $pd.Name
    $docPrefix = $provName
    $version = Get-ScriptVersion $pd.FullName
    if (-not $version) { Info "$provName -- no version in build script"; continue }

    # Check 3a: CLAUDE.md
    $escapedName = [regex]::Escape($provName)
    if ($claudeText -match "\|\s*${escapedName}\s*\|[^|]*\|\s*v([^\s|]+)") {
        $claudeVer = $Matches[1]
        if ($claudeVer -eq $version) {
            Pass "$provName -- CLAUDE.md v${claudeVer}"
        } else {
            Fail "$provName -- CLAUDE.md says v${claudeVer}, build script says v${version}"
        }
    } else {
        Warn "$provName -- not found in CLAUDE.md provider table"
    }

    # Check 3c: STATUS.txt
    $statusFile = Find-DocsPath $pd.FullName 'tracking' "${docPrefix}_STATUS.txt"
    if (Test-Path $statusFile) {
        $statusText = [System.IO.File]::ReadAllText($statusFile)
        if ($statusText -match "v$([regex]::Escape($version))") {
            Pass "$provName -- STATUS.txt has v${version}"
        } else {
            Fail "$provName -- STATUS.txt missing v${version}"
        }
    } else {
        Fail "$provName -- STATUS.txt not found"
    }

    # Check 3d: SQVR.txt
    $sqvrFile = Find-DocsPath $pd.FullName 'tracking' "${docPrefix}_SQVR.txt"
    if (Test-Path $sqvrFile) {
        $sqvrText = [System.IO.File]::ReadAllText($sqvrFile)
        if ($sqvrText -match "v$([regex]::Escape($version))") {
            Pass "$provName -- SQVR.txt has v${version}"
        } else {
            Fail "$provName -- SQVR.txt missing v${version}"
        }
    } else {
        Fail "$provName -- SQVR.txt not found"
    }

    # Check 3e: JSON_INVENTORY.md
    $invFile = Find-DocsPath $pd.FullName 'tracking' "JSON_INVENTORY.md"
    if (Test-Path $invFile) {
        $invText = [System.IO.File]::ReadAllText($invFile)
        if ($invText -match "v$([regex]::Escape($version))") {
            Pass "$provName -- JSON_INVENTORY.md has v${version}"
        } else {
            Fail "$provName -- JSON_INVENTORY.md missing v${version}"
        }
    } else {
        Fail "$provName -- JSON_INVENTORY.md not found"
    }

    # Check 3f: BUILD_NOTES.txt
    $notesFile = Find-DocsPath $pd.FullName 'tracking' "${docPrefix}_BUILD_NOTES.txt"
    if (Test-Path $notesFile) {
        $notesText = [System.IO.File]::ReadAllText($notesFile)
        if ($notesText -match "v$([regex]::Escape($version))") {
            Pass "$provName -- BUILD_NOTES.txt has v${version}"
        } else {
            Fail "$provName -- BUILD_NOTES.txt missing v${version}"
        }
        # Check 3f2: BUILD_NOTES entries must not be blank stubs
        $vEsc = [regex]::Escape($version)
        if ($notesText -match "(?ms)v${vEsc}.*?CHANGED\s*\r?\n\s*-\s*\r?\n\s*REASON") {
            Fail "$provName -- BUILD_NOTES.txt v${version} has blank CHANGED/REASON (fill in what changed)"
        }
        if ($notesText -match '\[describe change here\]') {
            Fail "$provName -- BUILD_NOTES.txt has placeholder text '[describe change here]'"
        }
        # Check 3f3: BUILD_NOTES date checksum -- proves pipeline ran completely
        $jsonFile = Join-Path $pd.FullName "${provName}.json"
        if (-not (Test-Path $jsonFile)) {
            $jsonFile = Get-ChildItem $pd.FullName -Filter "*.json" -File | Select-Object -First 1 -ExpandProperty FullName
        }
        if ($jsonFile -and (Test-Path $jsonFile)) {
            $jsonDate = (Get-Item $jsonFile).LastWriteTime.ToString('yyyy-MM-dd')
            $notesDate = $null
            $vEscDate = [regex]::Escape($version)
            if ($notesText -match "(?m)^v${vEscDate}\s+(\d{4}-\d{2}-\d{2})") {
                $notesDate = $Matches[1]
            } elseif ($notesText -match "(?m)^v${vEscDate}\s+\((\d{4}-\d{2}-\d{2})\)") {
                $notesDate = $Matches[1]
            }
            if ($notesDate) {
                if ($notesDate -eq $jsonDate) {
                    Pass "$provName -- BUILD_NOTES date matches JSON ($jsonDate)"
                } else {
                    Fail "$provName -- BUILD_NOTES date ($notesDate) != JSON date ($jsonDate) -- pipeline incomplete"
                }
            } else {
                Warn "$provName -- BUILD_NOTES v${version} has no parseable date for checksum"
            }
        }
    } else {
        Fail "$provName -- BUILD_NOTES.txt not found"
    }

    # Check 3g: REBUILD_TRACKER.md version
    if (Test-Path $tracker) {
        $trackerText = [System.IO.File]::ReadAllText($tracker)
        if ($trackerText -match "v$([regex]::Escape($version))") {
            Pass "$provName -- REBUILD_TRACKER.md has v${version}"
        } else {
            Warn "$provName -- REBUILD_TRACKER.md missing v${version}"
        }
    }

    # Check 3g2: per-provider changelog (auto-generated from BUILD_NOTES).
    # Adopted per-provider on next build -- if the file exists it must be current;
    # if absent it's an Info (provider hasn't been rebuilt under the new pipeline yet).
    $clProvFile = Find-DocsPath $pd.FullName 'tracking' "CHANGELOG_${docPrefix}.md"
    if (Test-Path $clProvFile) {
        $clProvText = [System.IO.File]::ReadAllText($clProvFile)
        if ($clProvText -match "v$([regex]::Escape($version))") {
            Pass "$provName -- CHANGELOG_${docPrefix}.md has v${version}"
        } else {
            Fail "$provName -- CHANGELOG_${docPrefix}.md missing v${version} (run build_report/generate_changelog)"
        }
    } else {
        Info "$provName -- CHANGELOG_${docPrefix}.md not present (adopts on next build)"
    }

    # Check 3g3: repo-root CHANGELOG.md -- if the provider has a section, its Current
    # line must reflect the current version. Providers without a section are skipped
    # (the repo CHANGELOG is curated; sections are not auto-created).
    $repoChangelog = Join-Path $repoRoot "CHANGELOG.md"
    if (Test-Path $repoChangelog) {
        $repoClText = [System.IO.File]::ReadAllText($repoChangelog)
        $provEscCl = [regex]::Escape($provName)
        $secMatch = [regex]::Match($repoClText, "(?ms)^##\s+${provEscCl}\b.*?(?=^##\s|\z)")
        if ($secMatch.Success) {
            $curMatch = [regex]::Match($secMatch.Value, '(?m)^Current:\s*\*\*v([\d.]+)\*\*')
            if ($curMatch.Success) {
                if ($curMatch.Groups[1].Value -eq $version) {
                    Pass "$provName -- CHANGELOG.md Current = v${version}"
                } else {
                    Fail "$provName -- CHANGELOG.md Current = v$($curMatch.Groups[1].Value), expected v${version}"
                }
            } else {
                Info "$provName -- CHANGELOG.md section has no parseable 'Current: **vX.Y**' line (skipped)"
            }
        } else {
            Info "$provName -- no '## $provName' section in CHANGELOG.md (skipped)"
        }
    }

    # Check 3h: test package aligned to current version (rebuild restarts testing).
    # Entity-aware when .test_state.json exists: a 'blocked' entity is OK only
    # while its structural fingerprint matches the built JSON -- a drift means the
    # entity changed but kept its CONFIRMED status (stale block) and FAILS. Falls back
    # to the legacy scalar .test_version check for providers that haven't adopted state.
    # tests/ folder eliminated 2026-07-01 -- state now lives at logs/ root; legacy
    # fallback to tests/ for providers not yet migrated.
    $testStateFile = Join-Path $pd.FullName "logs\.test_state.json"
    if (-not (Test-Path $testStateFile)) { $testStateFile = Join-Path $pd.FullName "tests\.test_state.json" }
    $testVerFile   = Join-Path $pd.FullName "logs\.test_version"
    if (-not (Test-Path $testVerFile)) { $testVerFile = Join-Path $pd.FullName "tests\.test_version" }
    if (Test-Path $testStateFile) {
        $activeJson = Join-Path $pd.FullName "$provName.json"
        if (-not (Test-Path $activeJson)) {
            $altJ = Get-ChildItem $pd.FullName -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^${provName}_v[\d.]+\.json$" } | Select-Object -First 1
            if (-not $altJ) { $altJ = Get-ChildItem $pd.FullName -Filter "*_MC.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if (-not $altJ) { $altJ = Get-ChildItem $pd.FullName -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if ($altJ) { $activeJson = $altJ.FullName }
        }
        . "$PSScriptRoot\get_entity_fingerprints.ps1"
        $curFp = @{}
        try { if (Test-Path $activeJson) { $curFp = Get-EntityFingerprints -Path $activeJson } } catch {}
        $st = Get-Content $testStateFile -Raw | ConvertFrom-Json
        $driftFail = 0; $openMisaligned = 0; $blockedOk = 0
        foreach ($p in $st.entities.PSObject.Properties) {
            $ent = $p.Name; $info = $p.Value
            if ($info.status -eq 'blocked') {
                if ($curFp.Contains($ent) -and $curFp[$ent] -eq $info.fingerprint) { $blockedOk++ }
                else { Fail "$provName -- blocked entity '$ent' fingerprint drifted from build (v${version}); re-validate + re-block (block_entity.ps1) or it is silently stale"; $driftFail++ }
                if ($info.forced) { Warn "$provName -- blocked entity '$ent' was -Force-blocked (evidence-free lock: SQVR/XML gate overridden); re-validate with real logs to clear" }
            } else {
                if ($info.version -ne $st.global) { $openMisaligned++ }
            }
        }
        if ($st.global -ne $version) {
            Warn "$provName -- .test_state.json global (v$($st.global)) != build v${version}; rebuild bypassed reset -- run reset_test_package.ps1 -Provider $provName"
        } elseif ($openMisaligned -gt 0) {
            Warn "$provName -- $openMisaligned open entity(ies) not aligned to v${version}; run reset_test_package.ps1 -Provider $provName"
        } elseif ($driftFail -eq 0) {
            $bk = if ($blockedOk) { " ($blockedOk blocked entity(ies) verified)" } else { "" }
            Pass "$provName -- test package aligned to v${version}$bk"
        }
    } elseif (Test-Path $testVerFile) {
        $testVer = ((Get-Content $testVerFile -Raw) -replace "^﻿", '').Trim()
        if ($testVer -eq $version) {
            Pass "$provName -- test package aligned to v${version}"
        } else {
            Warn "$provName -- .test_version (v${testVer}) != build v${version}; rebuild bypassed reset -- run reset_test_package.ps1 -Provider $provName"
        }
    }

    # Check 3i: JSON-embedded version matches build script default (version-lag trap).
    # A JSON built with a -Version override while the script default lagged ships the
    # correct artifact but mis-stamps every doc (Get-ScriptVersion reads the default).
    # FL_FCIC v5.1 hit this 2026-06-15 (4 enforce FAILs). Fix = bump the script default.
    # Use the canonical resolver (bare -> versioned -> _MC -> _BASE), NOT a naive first-JSON
    # glob -- a stray non-provider JSON in root (e.g. a legacy plan file predating the
    # logs/ TEST_PLAN convention) sorts before the versioned name and gets picked instead,
    # producing a false "no parseable embedded version" WARN (FL_FCIC, 2026-07-02).
    $jsonFile3i = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $provName
    if ($jsonFile3i -and (Test-Path $jsonFile3i)) {
        $jsonText3i = [System.IO.File]::ReadAllText($jsonFile3i)
        if ($jsonText3i -match '"description":\s*"Provider configuration for [^"]*?\bv([0-9]+\.[0-9]+)') {
            $embeddedVer = $Matches[1]
            if ($embeddedVer -eq $version) {
                Pass "$provName -- JSON embedded version v${embeddedVer} matches build script"
            } else {
                Fail "$provName -- JSON embedded v${embeddedVer} != build script default v${version} (version-lag trap: bump the build script default -Version)"
            }
        } else {
            Warn "$provName -- JSON provider-bundle description has no parseable embedded version"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASES 4+5: Cross-Provider + Repo Integrity (parallel)
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 4+5: Cross-Provider + Repo Integrity (parallel)"

Out "  Launching audits in parallel..."

$crossJob = Start-Job -ScriptBlock {
    param($t, $p)
    & powershell -ExecutionPolicy Bypass -File "$t\audit_cross_provider.ps1" -Path $p 2>&1 | Out-String
} -ArgumentList $toolDir, $provDir

$repoJob = Start-Job -ScriptBlock {
    param($t)
    & powershell -ExecutionPolicy Bypass -File "$t\audit_repo.ps1" 2>&1 | Out-String
} -ArgumentList $toolDir

$crossJob, $repoJob | Wait-Job -Timeout 300 | Out-Null

# Phase 4: Cross-provider results
$crossOutput = Receive-Job $crossJob
Remove-Job $crossJob -Force

Out ""
Out "  -- Cross-Provider Consistency --"

if ($crossOutput -match '(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN') {
    $xPass = [int]$Matches[1]
    $xFail = [int]$Matches[2]
    $xWarn = [int]$Matches[3]

    if ($xFail -gt 0) {
        Fail "Cross-provider: ${xPass}P/${xFail}F/${xWarn}W -- FAILURES DETECTED"
        $crossOutput -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
            $line = $_.Trim()
            Out "       $line"
        }
    } elseif ($xWarn -gt 0) {
        Warn "Cross-provider: ${xPass}P/0F/${xWarn}W"
    } else {
        Pass "Cross-provider: ${xPass}P/0F/0W"
    }
} else {
    Fail "Cross-provider audit -- could not parse output"
}

# Phase 5a: Repo audit results
$repoOutput = Receive-Job $repoJob
Remove-Job $repoJob -Force

Out ""
Out "  -- Repo Integrity --"

if ($repoOutput -match 'AUDIT\s+PASSED:\s*(\d+)\s*PASS') {
    $rPass = [int]$Matches[1]
    Pass "Repo audit: PASSED (${rPass} checks)"
} elseif ($repoOutput -match '(\d+)\s*FAIL\s*/\s*(\d+)\s*PASS') {
    $rFail = [int]$Matches[1]
    $rPass = [int]$Matches[2]
    Fail "Repo audit: ${rFail} FAIL / ${rPass} PASS"
    $repoOutput -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
        $line = $_.Trim()
        Out "       $line"
    }
} elseif ($repoOutput -match 'AUDIT\s+FAILED:\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*PASS') {
    $rFail = [int]$Matches[1]
    $rPass = [int]$Matches[2]
    Fail "Repo audit: ${rFail} FAIL / ${rPass} PASS"
    $repoOutput -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object {
        $line = $_.Trim()
        Out "       $line"
    }
} else {
    Warn "Repo audit -- could not parse output"
}

# 5b: Git status
if (-not $SkipGit) {
    $gitStatus = git -C $repoRoot status --porcelain 2>&1
    if ($gitStatus) {
        $changedCount = ($gitStatus | Measure-Object).Count
        Fail "Git: $changedCount uncommitted change(s)"
        $gitStatus | Select-Object -First 10 | ForEach-Object {
            Out "       $_"
        }
        if ($changedCount -gt 10) { Out "       ... and $($changedCount - 10) more" }
    } else {
        Pass "Git: working tree clean"
    }

    # Check if local is ahead of remote
    $ahead = git -C $repoRoot rev-list --count "@{u}..HEAD" 2>$null
    if ($ahead -and [int]$ahead -gt 0) {
        Fail "Git: $ahead commit(s) not pushed"
    } elseif ($ahead -eq '0') {
        Pass "Git: up to date with remote"
    }
} else {
    Info "Git checks skipped (-SkipGit)"
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 6: Iterate-Phase Gate + Hypothesis Quarantine
# ══════════════════════════════════════════════════════════════════════════════
# The build phase (Phases 1-5) is hard-gated. Phase 6 closes the test->change->iterate
# phase: a provider can no longer carry stale [CONFIRMED] markers, missing XML, or a stale
# TEST_MATRIX and still read as "done". And no KB/simulator "live-proven" claim may exist
# without a committed test log behind it. Both are BLOCKING on a real contradiction.
SectionHeader "PHASE 6: Iterate-Phase Gate + Claims"

# 6a: Hypothesis quarantine -- every live-proven KB/simulator claim must cite an existing log.
$claimsOut = & powershell -ExecutionPolicy Bypass -File "$toolDir\verify_claims.ps1" 2>&1 | Out-String
$claimsExit = $LASTEXITCODE
if ($claimsExit -eq 0) {
    Pass "Hypothesis quarantine: all live-proven claims cite committed test logs"
} else {
    Fail "Hypothesis quarantine: unbacked/stale 'live-proven' claim(s) found"
    $claimsOut -split "`n" | Where-Object { $_ -match '\[FAIL\]' } | ForEach-Object { Out "       $($_.Trim())" }
}

# 6b: Iterate-phase gate -- CLOSED / INCOMPLETE-consistent / INCONSISTENT per provider.
# Scope to the single provider when -Provider was given, else all providers.
$gateArgs = @("-ExecutionPolicy", "Bypass", "-File", "$toolDir\audit_test_coverage.ps1", "-Gate")
if ($Provider) {
    $provJsonForGate = Join-Path (Join-Path $provDir $Provider) "$Provider.json"
    if (-not (Test-Path $provJsonForGate)) {
        $altGate = Get-ChildItem (Join-Path $provDir $Provider) -Filter "*_MC.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $altGate) { $altGate = Get-ChildItem (Join-Path $provDir $Provider) -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($altGate) { $provJsonForGate = $altGate.FullName }
    }
    if (Test-Path $provJsonForGate) { $gateArgs += @("-Path", $provJsonForGate) }
}
$gateOut  = & powershell @gateArgs 2>&1 | Out-String
$gateExit = $LASTEXITCODE

# Parse the verdict-summary block: lines are "  <Provider>   <VERDICT>" (2-space indent,
# provider token, verdict). Exclude the per-provider "GATE VERDICT:" detail and headers.
$badProviders = @()
foreach ($l in ($gateOut -split "`n")) {
    if ($l -match '^\s{2}(\S+)\s+INCONSISTENT\s*$') {
        $name = $Matches[1]
        if ($name -notmatch 'GATE|VERDICT') {
            $badProviders += $name
            Out "       [verdict] $name INCONSISTENT"
        }
    }
}
if ($gateExit -eq 0) {
    Pass "Iterate-phase gate: no INCONSISTENT providers (CLOSED or INCOMPLETE-consistent)"
} else {
    Fail "Iterate-phase gate: INCONSISTENT provider(s) -- $($badProviders -join ', ')"
}

# 6c: Log-content integrity -- every saved test log's QUERY STRING must satisfy its plan
# test's FULL fill-set, and guardrail logs must show winner-only XML (audit_log_content.ps1;
# added 2026-07-02 after identifier-only auditing passed label-rotated logs). Runs for every
# in-scope provider ($providers is the single provider when -Provider was given, else all);
# providers without a TEST_PLAN pass by absence.
$logContentFailed = $false
foreach ($pd in $providers) {
    $logAuditOut = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_log_content.ps1" -Provider $pd.Name -Quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        $logContentFailed = $true
        Fail "Log-content integrity ($($pd.Name)): saved logs do not match their plan tests"
        $logAuditOut -split "`n" | Where-Object { $_ -match 'FAIL|STALE|MISMATCH|GUARDRAIL' } | Select-Object -First 8 | ForEach-Object { Out "       $($_.Trim())" }
    }
}
if (-not $logContentFailed) { Pass "Log-content integrity: in-scope logs match their plan tests -- VERIFIED where logs exist; providers with no TEST_PLAN pass BY ABSENCE (not verified). Per-provider test coverage: portfolio_status.ps1 / report_test_status.ps1" }

# 6d: Log-metadata integrity -- every saved test log's COMMSYS wire XML validated DIRECTLY against
# the metadata: each wire field is a metadata-defined field for that query, and the present field-set
# satisfies a real metadata combination (audit_log_metadata.ps1). This is the direct proof (vs the
# transitive metadata<->JSON + JSON<->plan chain) that the CommSys query is 100% metadata-correct.
# Providers without current-version logs or metadata XML pass by absence. Runs for every
# in-scope provider ($providers = single provider when -Provider given, else all).
$logMetaFailed = $false
foreach ($pd in $providers) {
    $metaAuditOut = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_log_metadata.ps1" -Provider $pd.Name -Quiet 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        $logMetaFailed = $true
        Fail "Log-metadata integrity ($($pd.Name)): saved logs do not match the metadata"
        $metaAuditOut -split "`n" | Where-Object { $_ -match 'FAIL|MISMATCH|not defined|satisfies no|not well-formed' } | Select-Object -First 8 | ForEach-Object { Out "       $($_.Trim())" }
    }
}
if (-not $logMetaFailed) { Pass "Log-metadata integrity: in-scope logs are metadata-correct -- VERIFIED where current-version logs exist; providers with none pass BY ABSENCE (not verified). Per-provider coverage: portfolio_status.ps1" }

# ══════════════════════════════════════════════════════════════════════════════
#  ADVISORY: picklist-scope reminders -- NON-BLOCKING. A [NOTE] is not a PASS/FAIL/WARN and
#  does not affect the verdict or exit code. Reminds when a provider still owes its one-time
#  tenant picklist capture, or a build introduced a new code category the capture doesn't cover.
# ══════════════════════════════════════════════════════════════════════════════
$pickNotes = @()
foreach ($pd in $providers) {
    $jsonPick = Get-ProviderRootJson -ProvDir $pd.FullName -Provider $pd.Name
    if (-not $jsonPick) { continue }
    $n = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_picklist_scope.ps1" -Path $jsonPick 2>&1 | Where-Object { $_ -match '^\[NOTE\]' }
    if ($n) { $pickNotes += $n }
}
if ($pickNotes.Count -gt 0) {
    Out ""
    Out "  PICKLIST SCOPE (advisory -- does not affect the verdict):"
    $pickNotes | ForEach-Object { Out "    $($_.ToString().Trim())" }
}

# ══════════════════════════════════════════════════════════════════════════════
#  VERDICT
# ══════════════════════════════════════════════════════════════════════════════
Out ""
Out ("=" * 60)

if ($script:failCount -eq 0 -and $script:warnCount -eq 0) {
    Out "  ENFORCED: $($script:passCount) PASS / 0 FAIL / 0 WARN"
    Out "  All gates clear. Work is verified."
    if ($script:fixedCount -gt 0) {
        Out "  ($($script:fixedCount) issues auto-fixed with -Rebuild)"
    }
    Out ("=" * 60)
} elseif ($script:failCount -eq 0) {
    Out "  PASSED WITH WARNINGS: $($script:passCount) PASS / 0 FAIL / $($script:warnCount) WARN"
    Out "  No blockers, but warnings should be addressed."
    Out ("=" * 60)
} else {
    Out "  BLOCKED: $($script:passCount) PASS / $($script:failCount) FAIL / $($script:warnCount) WARN"
    Out ""
    Out "  Fix ALL failures before declaring work done."
    Out "  Do NOT commit, push, or report completion while BLOCKED."
    Out ("=" * 60)
}

# ── Save output ──────────────────────────────────────────────────────────────
if ($OutFile) {
    $script:outputLines | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "`n  Saved to: $OutFile" -ForegroundColor Gray
}

if ($script:failCount -gt 0) { exit 1 }
exit 0
