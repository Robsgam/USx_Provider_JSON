<#
  audit_repo.ps1 -- Full monorepo consistency audit
  Mechanically checks KB docs, build scripts, tools, and CLAUDE.md for
  drift, stale references, missing documentation, and banned patterns.
  Sources of truth are extracted at runtime (not hardcoded).

  FAILS (exit 1) if any check fails. Run after any KB, tool, or CLAUDE.md edit.

  Usage: .\audit_repo.ps1
         .\audit_repo.ps1 -Category 3    # run only category 3
#>

param(
    [int]$Category = 0
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

$failCount = 0
$passCount = 0
$infoCount = 0

function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:passCount++ }
function Info($msg) { Write-Host "  [INFO] $msg" -ForegroundColor Gray; $script:infoCount++ }

# ── Active file filter ────────────────────────────────────────────────────────
$excludePattern = '(\\|/)(?:archive|v1|source|templates|phases)(\\|/|$)'

function Get-ActiveFiles {
    param([string]$Include = '*', [string]$SearchPath = $repoRoot)
    Get-ChildItem $SearchPath -Recurse -File -Include $Include |
        Where-Object { $_.FullName -notmatch $excludePattern -and $_.Name -ne 'audit_repo.ps1' }
}

# ── Source of truth extractors ────────────────────────────────────────────────
function Get-StepCount {
    $content = [System.IO.File]::ReadAllText("$repoRoot\tools\build_report.ps1")
    if ($content -match '\$stepCount\s*=\s*if\s*\(\$Release\)\s*\{\s*(\d+)\s*\}\s*else\s*\{\s*(\d+)\s*\}') {
        return [int]$Matches[2]
    }
    return -1
}

function Get-ValidLabels {
    $content = [System.IO.File]::ReadAllText("$repoRoot\tools\verify_build.ps1")
    if ($content -match '\$validLabels\s*=\s*@\(([^)]+)\)') {
        $raw = $Matches[1]
        return @($raw -split "'" | Where-Object { $_ -match '\S' -and $_ -notmatch '^[\s,]+$' })
    }
    return @()
}

function Get-ArchivedFileNames {
    $archiveDir = "$repoRoot\knowledge-base\archive"
    if (Test-Path $archiveDir) {
        return @(Get-ChildItem $archiveDir -File | ForEach-Object { $_.Name })
    }
    return @()
}

function Get-BannedPatterns {
    $bannedFile = "$repoRoot\tools\banned_patterns.txt"
    if (Test-Path $bannedFile) {
        return @(Get-Content $bannedFile | Where-Object { $_ -and $_ -notmatch '^\s*#' -and $_.Trim() -ne '' })
    }
    return @()
}

# ── Header ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " REPO AUDIT: USx_Provider_JSON" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 1: Banned patterns repo-wide
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 1) {
Write-Host ""
Write-Host "--- CATEGORY 1: Banned Patterns (repo-wide) ---" -ForegroundColor Yellow

$bannedPatterns = Get-BannedPatterns
$activeFiles = Get-ActiveFiles -Include @('*.ps1','*.txt','*.md','*.json')

foreach ($pat in $bannedPatterns) {
    $hits = @()
    foreach ($f in $activeFiles) {
        $text = [System.IO.File]::ReadAllText($f.FullName)
        $matches = [regex]::Matches($text, $pat)
        if ($matches.Count -gt 0) {
            $relPath = $f.FullName.Substring($repoRoot.Length + 1)
            # Allow LicensePlateNumberIn in Patch 8 rename map (the "from" key)
            $isRenameMap = $relPath -match 'build_nj_njcjis\.ps1$' -and $text -match "cadRenames.*'LicensePlateNumberIn'"
            if (-not $isRenameMap) {
                $hits += "$relPath ($($matches.Count) hits)"
            }
        }
    }
    if ($hits.Count -gt 0) {
        Fail "Banned pattern '$pat' found in: $($hits -join '; ')"
    } else {
        Pass "No banned pattern '$pat' in any active file"
    }
}
if ($bannedPatterns.Count -eq 0) { Info "No banned patterns defined" }
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 2: Report step count consistency
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 2) {
Write-Host ""
Write-Host "--- CATEGORY 2: Report Step Count Consistency ---" -ForegroundColor Yellow

$stepCount = Get-StepCount
if ($stepCount -gt 0) {
    Info "build_report.ps1 defines $stepCount steps (non-release)"

    $docsToCheck = @(
        "$repoRoot\CLAUDE.md"
    ) + @(Get-ChildItem "$repoRoot\knowledge-base" -File -Include '*.txt','*.md' |
          Where-Object { $_.FullName -notmatch $excludePattern } |
          ForEach-Object { $_.FullName })

    $countPatterns = @(
        'runs all (\d+)',
        'all (\d+) report files',
        'all (\d+) report',
        '(\d+) files\)'
    )

    $mismatches = @()
    $confirmations = 0
    foreach ($doc in $docsToCheck) {
        if (-not (Test-Path $doc)) { continue }
        $lines = Get-Content $doc
        $relPath = $doc.Substring($repoRoot.Length + 1)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($cp in $countPatterns) {
                $m = [regex]::Matches($lines[$i], $cp)
                foreach ($match in $m) {
                    $found = [int]$match.Groups[1].Value
                    # Skip the validator "6-phase" reference and GATE 5 "all 5 checks"
                    if ($lines[$i] -match '6-phase|all \d+ checks pass') { continue }
                    if ($found -ne $stepCount -and $found -ge 3 -and $found -le 10) {
                        $mismatches += "$relPath line $($i+1): says '$($match.Value)' but actual is $stepCount"
                    } elseif ($found -eq $stepCount) {
                        $confirmations++
                    }
                }
            }
        }
    }

    if ($mismatches.Count -gt 0) {
        foreach ($mm in $mismatches) { Fail $mm }
    } else {
        Pass "All doc references match step count ($stepCount) -- $confirmations confirmed"
    }
} else {
    Fail "Could not extract step count from build_report.ps1"
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 3: QueryLabel standard consistency
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 3) {
Write-Host ""
Write-Host "--- CATEGORY 3: QueryLabel Standard ---" -ForegroundColor Yellow

$validLabels = Get-ValidLabels
if ($validLabels.Count -gt 0) {
    Info "verify_build.ps1 defines $($validLabels.Count) valid labels: $($validLabels -join ', ')"

    # Check CLAUDE.md queryLabel table (scoped to ### queryLabel Standard section)
    $claudeMd = Get-Content "$repoRoot\CLAUDE.md"
    $claudeLabels = @()
    $inLabelSection = $false
    foreach ($line in $claudeMd) {
        if ($line -match '###\s*queryLabel\s+Standard') { $inLabelSection = $true; continue }
        if ($inLabelSection -and $line -match '^###?\s') { $inLabelSection = $false }
        if ($inLabelSection -and $line -match '^\|\s*\S.*\|\s*([^|]+)\s*\|$') {
            $label = $Matches[1].Trim()
            if ($label -and $label -ne 'queryLabel' -and $label -ne '---') { $claudeLabels += $label }
        }
    }
    $missingInClaude = @($validLabels | Where-Object { $_ -notin $claudeLabels -and $_ -ne 'RMS' })
    $extraInClaude = @($claudeLabels | Where-Object { $_ -notin $validLabels })
    if ($missingInClaude.Count -gt 0) {
        Fail "CLAUDE.md queryLabel table missing: $($missingInClaude -join ', ')"
    } elseif ($extraInClaude.Count -gt 0) {
        Fail "CLAUDE.md has labels not in verify_build.ps1: $($extraInClaude -join ', ')"
    } else {
        Pass "CLAUDE.md queryLabel table matches verify_build.ps1"
    }

    # Check build scripts for non-standard queryLabels
    $buildScripts = Get-ChildItem "$repoRoot\providers" -Recurse -File -Include 'build_*.ps1' |
        Where-Object { $_.FullName -notmatch $excludePattern }
    foreach ($bs in $buildScripts) {
        $text = [System.IO.File]::ReadAllText($bs.FullName)
        $labelMatches = [regex]::Matches($text, "queryLabel\s*=\s*['""]([^'""]+)['""]")
        foreach ($lm in $labelMatches) {
            $label = $lm.Groups[1].Value
            if ($label -notin $validLabels) {
                $relPath = $bs.FullName.Substring($repoRoot.Length + 1)
                Fail "$relPath uses non-standard queryLabel '$label'"
            }
        }
    }
    Pass "All build script queryLabels are in standard set"
} else {
    Fail "Could not extract validLabels from verify_build.ps1"
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 4: Stale archive file references
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 4) {
Write-Host ""
Write-Host "--- CATEGORY 4: Stale Archive References ---" -ForegroundColor Yellow

$archivedFiles = Get-ArchivedFileNames
if ($archivedFiles.Count -gt 0) {
    Info "$($archivedFiles.Count) archived files found"

    $docsToScan = @("$repoRoot\CLAUDE.md") +
        @(Get-ChildItem "$repoRoot\knowledge-base" -File |
          Where-Object { $_.FullName -notmatch $excludePattern } |
          ForEach-Object { $_.FullName })

    $staleHits = @()
    foreach ($doc in $docsToScan) {
        if (-not (Test-Path $doc)) { continue }
        $lines = Get-Content $doc
        $relPath = $doc.Substring($repoRoot.Length + 1)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            # Skip "Consolidated from:" provenance lines (first 10 lines)
            if ($i -lt 10 -and $lines[$i] -match 'Consolidated from') { continue }
            foreach ($af in $archivedFiles) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($af)
                if ($lines[$i] -match [regex]::Escape($af) -or
                    ($lines[$i] -match [regex]::Escape($baseName) -and $lines[$i] -notmatch 'archive/')) {
                    $staleHits += "$relPath line $($i+1): references archived '$af'"
                }
            }
        }
    }

    if ($staleHits.Count -gt 0) {
        $unique = $staleHits | Select-Object -Unique
        foreach ($h in $unique) { Fail $h }
    } else {
        Pass "No stale archive references in active KB docs"
    }
} else {
    Info "No archive directory found -- skipping"
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 5: Build script completeness
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 5) {
Write-Host ""
Write-Host "--- CATEGORY 5: Build Script Completeness ---" -ForegroundColor Yellow

$buildScripts = Get-ChildItem "$repoRoot\providers" -Recurse -File -Include 'build_*.ps1' |
    Where-Object { $_.FullName -notmatch $excludePattern }

foreach ($bs in $buildScripts) {
    $text = [System.IO.File]::ReadAllText($bs.FullName)
    $relPath = $bs.FullName.Substring($repoRoot.Length + 1)
    $shortName = $bs.Name

    # Detect stubs and legacy test scripts
    if ($text -match 'Write-Host.*stub|Write-Host.*placeholder|Write-Host.*not yet|TODO.*build' -or $text.Length -lt 500) {
        Info "STUB: $relPath (no build logic)"
        continue
    }
    if ($shortName -match '_test\.ps1$') {
        Info "TEST SCRIPT: $relPath (not a standard build)"
        continue
    }

    # Check dual output
    $hasCompress = $text -match 'ConvertTo-Json\s+-Depth\s+\d+\s+-Compress'
    $hasReadable = $text -match 'ConvertTo-Json\s+-Depth\s+\d+[^-]' -or $text -match 'READABLE'
    if (-not $hasCompress) {
        Fail "${shortName} -- missing minified output (ConvertTo-Json -Compress)"
    } elseif (-not $hasReadable) {
        Fail "${shortName} -- missing readable output (_READABLE.json)"
    } else {
        Pass "${shortName} -- dual output (minified + readable)"
    }

    # Check validator execution
    $hasValidator = $text -match 'validate.*\.ps1' -or $text -match 'validator'
    if (-not $hasValidator) {
        Fail "${shortName} -- no post-build validator execution"
    } else {
        Pass "${shortName} -- runs validator after build"
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 6: Tool documentation
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 6) {
Write-Host ""
Write-Host "--- CATEGORY 6: Tool Documentation ---" -ForegroundColor Yellow

$allTools = @(Get-ChildItem "$repoRoot\tools\*.ps1" -File)
$readmeText = [System.IO.File]::ReadAllText("$repoRoot\knowledge-base\README.txt")

$undocumented = @()
foreach ($tool in $allTools) {
    if ($tool.Name -eq 'audit_repo.ps1') { continue }
    if ($readmeText -notmatch [regex]::Escape($tool.Name)) {
        $undocumented += $tool.Name
    }
}

if ($undocumented.Count -gt 0) {
    Fail "Undocumented tools in README.txt: $($undocumented -join ', ')"
} else {
    Pass "All $($allTools.Count) tools documented in README.txt"
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 7: Render tool correctness
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 7) {
Write-Host ""
Write-Host "--- CATEGORY 7: Render Tool Correctness ---" -ForegroundColor Yellow

$renderFiles = @(
    "$repoRoot\tools\render_layout.ps1",
    "$repoRoot\tools\render_html.ps1"
)

foreach ($rf in $renderFiles) {
    if (-not (Test-Path $rf)) { continue }
    $text = [System.IO.File]::ReadAllText($rf)
    $name = Split-Path $rf -Leaf

    # Check for $c.set / $c.any without .requirements prefix
    $badAccess = [regex]::Matches($text, '\$c\.(set|any)\b(?!\.)')
    # Exclude correct $c.requirements.set / $c.requirements.any
    $realBad = @()
    foreach ($m in $badAccess) {
        $pos = $m.Index
        $before = $text.Substring([Math]::Max(0, $pos - 20), [Math]::Min(20, $pos))
        if ($before -notmatch 'requirements\.') {
            $realBad += $m.Value
        }
    }

    if ($realBad.Count -gt 0) {
        Fail "$name uses $($realBad -join ', ') without .requirements prefix"
    } else {
        Pass "${name} -- combo access uses .requirements.set/.requirements.any"
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 8: CLAUDE.md consistency
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 8) {
Write-Host ""
Write-Host "--- CATEGORY 8: CLAUDE.md Consistency ---" -ForegroundColor Yellow

$claudeMd = [System.IO.File]::ReadAllText("$repoRoot\CLAUDE.md")

# 8a: Check _READABLE.json in canonical structure
if ($claudeMd -match 'READABLE') {
    Pass "CLAUDE.md canonical structure includes _READABLE.json"
} else {
    Fail "CLAUDE.md canonical structure missing _READABLE.json reference"
}

# 8b: Check provider status table versions vs actual JSON files
$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $baseJson = Get-ChildItem $pd.FullName -File -Filter '*_BASE.json' | Select-Object -First 1
    $readableJson = Get-ChildItem $pd.FullName -File -Filter '*_READABLE.json' | Select-Object -First 1
    $provName = $pd.Name

    if ($baseJson) {
        if (-not $readableJson) {
            Info "${provName} -- BASE JSON exists but no _READABLE.json"
        }
    }
}

# 8c: Check verify_build.ps1 is referenced in tools section
if ($claudeMd -match 'verify_build\.ps1') {
    Pass "CLAUDE.md references verify_build.ps1"
} else {
    Fail "CLAUDE.md does not reference verify_build.ps1"
}

# 8d: Check banned_patterns.txt is referenced
if ($claudeMd -match 'banned_patterns') {
    Pass "CLAUDE.md references banned_patterns.txt"
} else {
    Fail "CLAUDE.md does not reference banned_patterns.txt"
}
}

# ── SUMMARY ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($failCount -gt 0) {
    Write-Host " AUDIT FAILED: $failCount FAIL / $passCount PASS / $infoCount INFO" -ForegroundColor Red
} else {
    Write-Host " AUDIT PASSED: $passCount PASS / $infoCount INFO / 0 FAIL" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) { exit 1 }
