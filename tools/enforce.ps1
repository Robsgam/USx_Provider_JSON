<#
  enforce.ps1 -- Mandatory post-build enforcement gate
  Single command that runs ALL verification. Nothing is done until this passes.

  5 phases:
    1. Build freshness    -- reports exist and are newer than JSONs
    2. Validator scores   -- 0 FAIL / 0 WARN on every provider
    3. Doc version sync   -- build script version matches all 7 doc locations
    4. Cross-provider     -- field types, defaults, code types consistent
    5. Repo integrity     -- audit_repo.ps1 passes, git status clean

  Usage:
    .\enforce.ps1                     # full check on all providers
    .\enforce.ps1 -Provider HI_HCJDC_OFML   # single provider (still runs cross-provider)
    .\enforce.ps1 -SkipGit            # skip git status check (for mid-work runs)
    .\enforce.ps1 -Rebuild            # auto-rebuild stale providers before checking
    .\enforce.ps1 -OutFile report.txt # save full output to file

  Exit code 0 = ENFORCED (all gates pass). Exit code 1 = BLOCKED (fix before declaring done).
#>

param(
    [string]$Provider,
    [switch]$SkipGit,
    [switch]$Rebuild,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir   = $PSScriptRoot
$repoRoot  = (Resolve-Path "$toolDir\..").Path
$provDir   = Join-Path $repoRoot "providers"
$claudeMd  = Join-Path $repoRoot "CLAUDE.md"
$tracker   = Join-Path $repoRoot "REBUILD_TRACKER.md"

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
        $_.Name -ne 'CA_CONTRA_COSTA' -and
        $_.Name -ne 'CA_CONTRA_COSTA' -and
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

    # Find JSON: new naming (<PROVIDER>.json) or legacy (_BASE/_MC)
    $provJson = Get-ChildItem $pd.FullName -Filter "${docPrefix}.json" -File -ErrorAction SilentlyContinue
    $baseJson = Get-ChildItem $pd.FullName -Filter "${docPrefix}_BASE.json" -File -ErrorAction SilentlyContinue
    $mcJson   = Get-ChildItem $pd.FullName -Filter "${docPrefix}_MC.json" -File -ErrorAction SilentlyContinue

    # ONE JSON IN ROOT
    $jsonCount = @($provJson, $baseJson, $mcJson | Where-Object { $_ }).Count
    if ($jsonCount -gt 1) {
        Fail "$provName -- multiple JSONs in root (one-JSON-in-root rule)"
    }
    if ($jsonCount -eq 0) {
        Info "$provName -- no JSON found in root"
        continue
    }

    # Pick the active JSON
    $activeJson = if ($provJson) { $provJson } elseif ($mcJson) { $mcJson } else { $baseJson }

    # Check reports -- try docs/ first (new), then docs/mc/ or docs/base/ (legacy)
    $docsDir = Join-Path $pd.FullName "docs"
    $validatorReport = Join-Path $docsDir "VALIDATOR_REPORT_${docPrefix}.txt"
    if (-not (Test-Path $validatorReport)) {
        $validatorReport = Join-Path $docsDir "mc\VALIDATOR_REPORT_${docPrefix}_MC.txt"
    }
    if (-not (Test-Path $validatorReport)) {
        $validatorReport = Join-Path $docsDir "base\VALIDATOR_REPORT_${docPrefix}_BASE.txt"
    }

    if (Test-Path $validatorReport) {
        $jsonTime = $activeJson.LastWriteTime
        $reportTime = (Get-Item $validatorReport).LastWriteTime
        if ($reportTime -lt $jsonTime) {
            if ($Rebuild) {
                Out "  Rebuilding reports for $provName..."
                & powershell -ExecutionPolicy Bypass -File "$toolDir\build_report.ps1" -Path $activeJson.FullName 2>&1 | Out-Null
                Fixed "$provName -- reports rebuilt (were stale)"
            } else {
                Fail "$provName -- reports STALE (JSON: $($jsonTime.ToString('HH:mm')), reports: $($reportTime.ToString('HH:mm')))"
            }
        } else {
            Pass "$provName -- reports fresh"
        }
    } else {
        Fail "$provName -- no validator report found"
    }

    # Check phase archive exists for current version
    $version = Get-ScriptVersion $pd.FullName
    if ($version) {
        # Check phases/ (new), then phases/base/ and phases/mc/ (legacy)
        $phaseFile = $null
        foreach ($phaseDir in @("phases", "phases\base", "phases\mc")) {
            $pDir = Join-Path $pd.FullName $phaseDir
            if (Test-Path $pDir) {
                $phaseFile = Get-ChildItem $pDir -Filter "${docPrefix}*v${version}*.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($phaseFile) { break }
            }
        }
        if ($phaseFile) {
            Pass "$provName -- phase archive exists for v${version}"
        } else {
            Fail "$provName -- no phase archive for v${version}"
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
            $reportPath = Join-Path $pd.FullName "docs\VALIDATOR_REPORT_${docPrefix}.txt"
        } elseif ($variant -eq 'MC') {
            $reportPath = Join-Path $pd.FullName "docs\mc\VALIDATOR_REPORT_${docPrefix}_MC.txt"
        } else {
            $reportPath = Join-Path $pd.FullName "docs\base\VALIDATOR_REPORT_${docPrefix}_BASE.txt"
        }

        if (-not (Test-Path $reportPath)) { continue }

        $label = if ($variant) { "$provName ($variant)" } else { $provName }
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
    $statusFile = Join-Path $pd.FullName "docs\${docPrefix}_STATUS.txt"
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
    $sqvrFile = Join-Path $pd.FullName "docs\${docPrefix}_SQVR.txt"
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
    $invFile = Join-Path $pd.FullName "docs\JSON_INVENTORY.md"
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
    $notesFile = Join-Path $pd.FullName "docs\${docPrefix}_BUILD_NOTES.txt"
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
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4: Cross-Provider Consistency
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 4: Cross-Provider Consistency"

Out "  Running audit_cross_provider.ps1..."
$crossOutput = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_cross_provider.ps1" -Path $provDir 2>&1 | Out-String

if ($crossOutput -match '(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN') {
    $xPass = [int]$Matches[1]
    $xFail = [int]$Matches[2]
    $xWarn = [int]$Matches[3]

    if ($xFail -gt 0) {
        Fail "Cross-provider: ${xPass}P/${xFail}F/${xWarn}W -- FAILURES DETECTED"
        # Extract specific FAIL lines
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

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5: Repo Integrity
# ══════════════════════════════════════════════════════════════════════════════
SectionHeader "PHASE 5: Repo Integrity"

# 5a: audit_repo.ps1
Out "  Running audit_repo.ps1..."
$repoOutput = & powershell -ExecutionPolicy Bypass -File "$toolDir\audit_repo.ps1" 2>&1 | Out-String

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
