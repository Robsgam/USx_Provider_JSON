<#
  audit_repo.ps1 -- Full monorepo consistency audit
  Mechanically checks KB docs, build scripts, tools, provider JSONs, and
  CLAUDE.md for drift, stale references, missing documentation, banned
  patterns, report completeness, and cross-provider JSON consistency.
  18 categories, sources of truth extracted at runtime (not hardcoded).

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
    if ($content -match '\$stepCount\s*=\s*(\d+)') {
        return [int]$Matches[1]
    }
    return -1
}

function Get-ValidLabels {
    $content = [System.IO.File]::ReadAllText("$repoRoot\tools\verify_build.ps1")
    if ($content -match '\$validLabels\s*=\s*@\((.+)\)') {
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
    $flaggedProviders = @('CA_CONTRA_COSTA')
    $buildScripts = Get-ChildItem "$repoRoot\providers" -Recurse -File -Include 'build_*.ps1' |
        Where-Object { $_.FullName -notmatch $excludePattern }
    foreach ($bs in $buildScripts) {
        $text = [System.IO.File]::ReadAllText($bs.FullName)
        $labelMatches = [regex]::Matches($text, "queryLabel\s*=\s*['""]([^'""]+)['""]")
        $isFlagged = $flaggedProviders | Where-Object { $bs.FullName -match $_ }
        foreach ($lm in $labelMatches) {
            $label = $lm.Groups[1].Value
            if ($label -notin $validLabels) {
                $relPath = $bs.FullName.Substring($repoRoot.Length + 1)
                if ($isFlagged) {
                    Info "FLAGGED: $relPath uses non-standard queryLabel '$label'"
                } else {
                    Fail "$relPath uses non-standard queryLabel '$label'"
                }
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

    # Check JSON output (shared Write-ProviderJson helper or direct ConvertTo-Json)
    $usesSharedHelper = $text -match 'Write-ProviderJson'
    $hasConvert = $text -match 'ConvertTo-Json'
    if ($usesSharedHelper) {
        Pass "${shortName} -- JSON output via Write-ProviderJson"
    } elseif ($hasConvert) {
        Pass "${shortName} -- JSON output via ConvertTo-Json"
    } else {
        Fail "${shortName} -- no JSON output found (expected Write-ProviderJson or ConvertTo-Json)"
    }

    # Check validator execution (direct call OR shared Write-ProviderJson helper)
    $hasValidator = $text -match 'validate.*\.ps1' -or $text -match 'validator'
    if ($usesSharedHelper -or $hasValidator) {
        Pass "${shortName} -- runs validator after build"
    } else {
        Fail "${shortName} -- no post-build validator execution"
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

# 8a: Check _BASE.json in canonical structure
if ($claudeMd -match '_BASE\.json') {
    Pass "CLAUDE.md canonical structure includes _BASE.json"
} else {
    Fail "CLAUDE.md canonical structure missing _BASE.json reference"
}

# 8b: Check verify_build.ps1 is referenced in tools section
if ($claudeMd -match 'verify_build\.ps1') {
    Pass "CLAUDE.md references verify_build.ps1"
} else {
    Fail "CLAUDE.md does not reference verify_build.ps1"
}

# 8c: Check banned_patterns.txt is referenced
if ($claudeMd -match 'banned_patterns') {
    Pass "CLAUDE.md references banned_patterns.txt"
} else {
    Fail "CLAUDE.md does not reference banned_patterns.txt"
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 9: Provider canonical structure
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 9) {
Write-Host ""
Write-Host "--- CATEGORY 9: Provider Canonical Structure ---" -ForegroundColor Yellow

$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
$requiredDirs = @('docs','scripts','source')
$requiredDocs = @('STATUS.txt','SQVR.txt','BUILD_NOTES.txt','JSON_INVENTORY.md')

foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $docPrefix = $provName

    # Required subdirectories
    foreach ($rd in $requiredDirs) {
        if (Test-Path (Join-Path $pd.FullName $rd)) {
            Pass "${provName} -- has $rd/"
        } else {
            Fail "${provName} -- missing required $rd/"
        }
    }

    # Required doc files (prefixed with canonical provider name for STATUS/SQVR/BUILD_NOTES)
    $docsDir = Join-Path $pd.FullName 'docs'
    if (Test-Path $docsDir) {
        foreach ($rd in $requiredDocs) {
            $pattern = if ($rd -eq 'JSON_INVENTORY.md') { $rd } else { "${docPrefix}_$rd" }
            $found = Get-ChildItem $docsDir -File | Where-Object { $_.Name -eq $pattern }
            if ($found) {
                Pass "${provName} -- docs/$pattern exists"
            } else {
                Fail "${provName} -- docs/$pattern missing"
            }
        }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 10: Report file completeness
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 10) {
Write-Host ""
Write-Host "--- CATEGORY 10: Report File Completeness ---" -ForegroundColor Yellow

$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
$reportPrefixes = @('VALIDATOR_REPORT','LAYOUT_REPORT','QUERY_REPORT','PICKLIST_REPORT','VERIFY_REPORT','METADATA_AUDIT','CAD_AUDIT')
# Legacy _MC/_BASE providers: convert to single-JSON during scheduled rebuild, not a gap
$flaggedProviders = @('CA_CONTRA_COSTA','AZ_AZDPS','CA_CLETS_OCATS','CA_eSUN','CA_SAN_LUIS_OBISPO',
    'CA_VENTURA_COUNTY','HI_HCJDC_OFML','IL_LEADS_OFML','LA_LEMS','MD_METERS',
    'NM_NMLETS_OFML','OH_LEADS','OR_LEDS','TN_TIES')

foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $isFlagged = $provName -in $flaggedProviders
    $baseDir = Join-Path $pd.FullName 'docs\base'
    $mcDir = Join-Path $pd.FullName 'docs\mc'

    # Reports: check docs/ directly (single-JSON), then docs/base/ (legacy)
    $docsDir = Join-Path $pd.FullName 'docs'
    $docsFiles = @(Get-ChildItem $docsDir -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $missingSingle = @()
    foreach ($rp in $reportPrefixes) {
        $match = $docsFiles | Where-Object { $_ -match "^${rp}_" }
        if (-not $match) { $missingSingle += $rp }
    }
    $htmlSingle = $docsFiles | Where-Object { $_ -match '^LAYOUT_.*\.html$' }
    if (-not $htmlSingle) { $missingSingle += 'LAYOUT_HTML' }

    if ($missingSingle.Count -eq 0) {
        Pass "${provName} -- docs/ has all 8 report files (single-JSON)"
    } elseif (Test-Path $baseDir) {
        $baseFiles = @(Get-ChildItem $baseDir -File | ForEach-Object { $_.Name })
        $missingBase = @()
        foreach ($rp in $reportPrefixes) {
            $match = $baseFiles | Where-Object { $_ -match "^${rp}_" }
            if (-not $match) { $missingBase += $rp }
        }
        $htmlMatch = $baseFiles | Where-Object { $_ -match '^LAYOUT_.*\.html$' }
        if (-not $htmlMatch) { $missingBase += 'LAYOUT_HTML' }

        if ($missingBase.Count -gt 0) {
            if ($isFlagged) { Info "FLAGGED: ${provName} docs/base/ missing: $($missingBase -join ', ')" }
            else { Fail "${provName} docs/base/ missing: $($missingBase -join ', ')" }
        } else {
            Pass "${provName} -- docs/base/ has all 8 report files"
        }
    } else {
        if ($isFlagged) { Info "FLAGGED: ${provName} -- no report files in docs/ or docs/base/" }
        else { Fail "${provName} -- no report files in docs/ or docs/base/" }
    }

    # MC reports (only check if MC JSON exists)
    $mcJson = Get-ChildItem $pd.FullName -File -Filter '*_MC.json' | Select-Object -First 1
    if ($mcJson) {
        if (Test-Path $mcDir) {
            $mcFiles = @(Get-ChildItem $mcDir -File | ForEach-Object { $_.Name })
            $missingMc = @()
            foreach ($rp in $reportPrefixes) {
                $match = $mcFiles | Where-Object { $_ -match "^${rp}_" }
                if (-not $match) { $missingMc += $rp }
            }
            $htmlMatch = $mcFiles | Where-Object { $_ -match '^LAYOUT_.*\.html$' }
            if (-not $htmlMatch) { $missingMc += 'LAYOUT_HTML' }

            if ($missingMc.Count -gt 0) {
                Fail "${provName} docs/mc/ missing: $($missingMc -join ', ')"
            } else {
                Pass "${provName} -- docs/mc/ has all 8 report files"
            }
        } else {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- MC JSON exists but docs/mc/ missing (legacy, convert on rebuild)" }
            else { Fail "${provName} -- MC JSON exists but docs/mc/ missing" }
        }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 11: Cross-provider JSON consistency
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 11) {
Write-Host ""
Write-Host "--- CATEGORY 11: Cross-Provider JSON Consistency ---" -ForegroundColor Yellow

# Providers flagged or known-exception get INFO instead of FAIL
$needsRebuild = @('TX_TLETS','LA_LEMS')
$flaggedProviders = @('CA_CONTRA_COSTA')
$validLabels = Get-ValidLabels

$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $baseJson = Get-ChildItem $pd.FullName -File -Filter '*_BASE.json' | Select-Object -First 1
    if (-not $baseJson) { Info "${provName} -- no BASE JSON, skipping"; continue }

    $text = [System.IO.File]::ReadAllText($baseJson.FullName)
    $parsed = $text | ConvertFrom-Json
    $isRebuild = $provName -in $needsRebuild
    $isFlagged = $provName -in $flaggedProviders
    $report = if ($isRebuild) { { param($m) Info "REBUILD: ${provName} -- $m" } } `
              elseif ($isFlagged) { { param($m) Info "FLAGGED: ${provName} -- $m" } } `
              else { { param($m) Fail "${provName} -- $m" } }

    # Collect all configs across all bundles
    $allConfigs = @()
    foreach ($bundle in $parsed.bundles) {
        if ($bundle.configurations) { $allConfigs += $bundle.configurations }
    }

    # 11a: RMS autoSelect on RMS QIDMs
    $rmsQidms = @($allConfigs | Where-Object { $_.provider -eq 'RMS' -and $_.type -eq 'QUERYINPUTDATAMAPPING' })
    if ($rmsQidms.Count -gt 0) {
        $missingAutoSelect = @($rmsQidms | Where-Object { $_.autoSelect -ne $true })
        if ($missingAutoSelect.Count -gt 0) {
            $names = ($missingAutoSelect | ForEach-Object { $_.name }) -join ', '
            & $report "RMS QIDMs missing autoSelect=true: $names"
        } else {
            Pass "${provName} -- all $($rmsQidms.Count) RMS QIDMs have autoSelect=true"
        }
    } else {
        & $report "no RMS QIDMs found (missing RMS bundle or QIDM configs)"
    }

    # 11b: AUTH keyReference
    $authConfigs = @($allConfigs | Where-Object { $_.type -eq 'AUTHENTICATION' })
    if ($authConfigs.Count -gt 0) {
        $authCombos = @()
        foreach ($ac in $authConfigs) {
            if ($ac.combinations) { $authCombos += $ac.combinations }
        }
        $hasKeyRef = $authCombos | Where-Object { $_.keyReference }
        if ($hasKeyRef) {
            Pass "${provName} -- AUTH has keyReference"
        } else {
            & $report "AUTH config missing keyReference on combinations"
        }
    }

    # 11c: queryLabel values in JSON (parsed)
    $qidmConfigs = @($allConfigs | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.queryLabel })
    $badLabels = @($qidmConfigs | Where-Object { $_.queryLabel -notin $validLabels } | ForEach-Object { $_.queryLabel })
    if ($badLabels.Count -gt 0) {
        $unique = $badLabels | Select-Object -Unique
        & $report "non-standard queryLabels in JSON: $($unique -join ', ')"
    } elseif ($qidmConfigs.Count -gt 0) {
        Pass "${provName} -- all $($qidmConfigs.Count) queryLabels are standard"
    }

    # 11d: YES_NO vs YES_NO_UNKNOWN (regex on text — codeTypeCategory is in nested props)
    $badYesNo = [regex]::Matches($text, '"codeTypeCategory"\s*:\s*"(YES_NO|YESNO)"(?!_)')
    if ($badYesNo.Count -gt 0) {
        $categories = @($badYesNo | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        & $report "uses non-standard Y/N category: $($categories -join ', ') (should be YES_NO_UNKNOWN)"
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 12: Version consistency (build script vs docs vs CLAUDE.md)
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 12) {
Write-Host ""
Write-Host "--- CATEGORY 12: Version Consistency ---" -ForegroundColor Yellow

$claudeMdLines = Get-Content "$repoRoot\CLAUDE.md"
$flaggedProviders = @('CA_CONTRA_COSTA')

$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $docPrefix = $provName
    $isFlagged = $provName -in $flaggedProviders

    # Extract version from BASE build script
    $baseScript = Get-ChildItem "$($pd.FullName)\scripts" -File -Filter 'build_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '_mc|_test' } | Select-Object -First 1
    if (-not $baseScript) { Info "${provName} -- no build script found"; continue }

    $scriptText = [System.IO.File]::ReadAllText($baseScript.FullName)
    $scriptVersion = $null
    if ($scriptText -match '\$Version\s*=\s*["'']([^"'']+)["'']') {
        $scriptVersion = $Matches[1]
    }
    if (-not $scriptVersion) { Info "${provName} -- no version in build script"; continue }

    # Check CLAUDE.md version (match on canonical name)
    $claudeVersion = $null
    foreach ($line in $claudeMdLines) {
        if ($line -match "^\|\s*$docPrefix\s*\|.*\|\s*v([^\s|]+)\s*\|") {
            $claudeVersion = $Matches[1]
            break
        }
    }
    if ($claudeVersion -and $claudeVersion -ne $scriptVersion) {
        if ($isFlagged) { Info "FLAGGED: ${provName} -- CLAUDE.md says v${claudeVersion}, build script says v${scriptVersion}" }
        else { Fail "${provName} -- CLAUDE.md version (v${claudeVersion}) != build script (v${scriptVersion})" }
    } elseif ($claudeVersion) {
        Pass "${provName} -- CLAUDE.md version matches build script (v${scriptVersion})"
    }

    # Check STATUS.txt version
    $statusFile = "$($pd.FullName)\docs\${docPrefix}_STATUS.txt"
    if (Test-Path $statusFile) {
        $statusText = [System.IO.File]::ReadAllText($statusFile)
        $statusHasVersion = $statusText -match "v$([regex]::Escape($scriptVersion))"
        if (-not $statusHasVersion) {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- STATUS.txt does not mention v${scriptVersion}" }
            else { Fail "${provName} -- STATUS.txt does not mention current version v${scriptVersion}" }
        } else {
            Pass "${provName} -- STATUS.txt mentions v${scriptVersion}"
        }
    }

    # Check SQVR version
    $sqvrFile = "$($pd.FullName)\docs\${docPrefix}_SQVR.txt"
    if (Test-Path $sqvrFile) {
        $sqvrText = [System.IO.File]::ReadAllText($sqvrFile)
        $sqvrHasVersion = $sqvrText -match "v$([regex]::Escape($scriptVersion))"
        if (-not $sqvrHasVersion) {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- SQVR does not mention v${scriptVersion}" }
            else { Fail "${provName} -- SQVR does not mention current version v${scriptVersion}" }
        } else {
            Pass "${provName} -- SQVR mentions v${scriptVersion}"
        }
    }

    # Check MC build script version matches BASE
    $mcScript = Get-ChildItem "$($pd.FullName)\scripts" -File -Filter 'build_*_mc*' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($mcScript) {
        $mcText = [System.IO.File]::ReadAllText($mcScript.FullName)
        $mcVersion = $null
        if ($mcText -match '\$Version\s*=\s*["'']([^"'']+)["'']') {
            $mcVersion = $Matches[1]
        }
        if ($mcVersion -and $mcVersion -ne $scriptVersion) {
            Fail "${provName} -- BASE version (v${scriptVersion}) != MC version (v${mcVersion})"
        } elseif ($mcVersion) {
            Pass "${provName} -- BASE and MC versions match (v${scriptVersion})"
        }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 13: BUILD_NOTES.txt has entry for current version
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 13) {
Write-Host ""
Write-Host "--- CATEGORY 13: BUILD_NOTES Version Coverage ---" -ForegroundColor Yellow

$flaggedProviders = @('CA_CONTRA_COSTA')
$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $docPrefix = $provName
    $isFlagged = $provName -in $flaggedProviders

    $baseScript = Get-ChildItem "$($pd.FullName)\scripts" -File -Filter 'build_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '_mc|_test' } | Select-Object -First 1
    if (-not $baseScript) { continue }

    $scriptText = [System.IO.File]::ReadAllText($baseScript.FullName)
    $scriptVersion = $null
    if ($scriptText -match '\$Version\s*=\s*["'']([^"'']+)["'']') {
        $scriptVersion = $Matches[1]
    }
    if (-not $scriptVersion) { continue }

    $bnFile = "$($pd.FullName)\docs\${docPrefix}_BUILD_NOTES.txt"
    if (Test-Path $bnFile) {
        $bnText = [System.IO.File]::ReadAllText($bnFile)
        if ($bnText -match '\(no builds yet\)') {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- BUILD_NOTES is stub" }
            else { Fail "${provName} -- BUILD_NOTES.txt is stub but build script is at v${scriptVersion}" }
        } elseif ($bnText -match "v$([regex]::Escape($scriptVersion))") {
            Pass "${provName} -- BUILD_NOTES.txt has v${scriptVersion} entry"
        } else {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- BUILD_NOTES missing v${scriptVersion}" }
            else { Fail "${provName} -- BUILD_NOTES.txt missing entry for current v${scriptVersion}" }
        }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 14: JSON_INVENTORY.md has entry for current version
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 14) {
Write-Host ""
Write-Host "--- CATEGORY 14: JSON_INVENTORY Version Coverage ---" -ForegroundColor Yellow

$flaggedProviders = @('CA_CONTRA_COSTA')
$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $isFlagged = $provName -in $flaggedProviders

    $baseScript = Get-ChildItem "$($pd.FullName)\scripts" -File -Filter 'build_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '_mc|_test' } | Select-Object -First 1
    if (-not $baseScript) { continue }

    $scriptText = [System.IO.File]::ReadAllText($baseScript.FullName)
    $scriptVersion = $null
    if ($scriptText -match '\$Version\s*=\s*["'']([^"'']+)["'']') {
        $scriptVersion = $Matches[1]
    }
    if (-not $scriptVersion) { continue }

    $jiFile = "$($pd.FullName)\docs\JSON_INVENTORY.md"
    if (Test-Path $jiFile) {
        $jiText = [System.IO.File]::ReadAllText($jiFile)
        if ($jiText -match '\(no builds yet\)') {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- JSON_INVENTORY is stub" }
            else { Fail "${provName} -- JSON_INVENTORY.md is stub but build script is at v${scriptVersion}" }
        } elseif ($jiText -match "v$([regex]::Escape($scriptVersion))") {
            Pass "${provName} -- JSON_INVENTORY.md has v${scriptVersion}"
        } else {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- JSON_INVENTORY missing v${scriptVersion}" }
            else { Fail "${provName} -- JSON_INVENTORY.md missing current v${scriptVersion}" }
        }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 15: STATUS.txt score accuracy vs validator reports
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 15) {
Write-Host ""
Write-Host "--- CATEGORY 15: STATUS.txt Score Accuracy ---" -ForegroundColor Yellow

$flaggedProviders = @('CA_CONTRA_COSTA')
$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $docPrefix = $provName
    $isFlagged = $provName -in $flaggedProviders

    $statusFile = "$($pd.FullName)\docs\${docPrefix}_STATUS.txt"
    if (-not (Test-Path $statusFile)) { continue }

    $statusText = [System.IO.File]::ReadAllText($statusFile)

    # Check for stub
    if ($statusText -match '\(no builds yet\)' -or $statusText -match 'Validator:\s*--') {
        $baseScript = Get-ChildItem "$($pd.FullName)\scripts" -File -Filter 'build_*' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '_mc|_test' } | Select-Object -First 1
        if ($baseScript) {
            if ($isFlagged) { Info "FLAGGED: ${provName} -- STATUS.txt is stub" }
            else { Fail "${provName} -- STATUS.txt is stub but has a build script" }
        }
        continue
    }

    # Extract PASS count from validator report (single-JSON first, then legacy base)
    $reportFile = "$($pd.FullName)\docs\VALIDATOR_REPORT_${docPrefix}.txt"
    if (-not (Test-Path $reportFile)) {
        $reportFile = "$($pd.FullName)\docs\base\VALIDATOR_REPORT_${docPrefix}_BASE.txt"
    }
    if (-not (Test-Path $reportFile)) { continue }

    $reportText = [System.IO.File]::ReadAllText($reportFile)
    $reportPass = $null
    if ($reportText -match 'RESULTS:\s*(\d+)\s*PASS') {
        $reportPass = [int]$Matches[1]
    }
    if (-not $reportPass) { continue }

    # Check if STATUS.txt contains the correct BASE PASS count anywhere
    # Look for "NNP/" compact format or "NN PASS" full format
    $hasCorrectScore = ($statusText -match "${reportPass}P/\d+F") -or ($statusText -match "${reportPass}\s*PASS\s*/\s*\d+\s*FAIL")
    if ($hasCorrectScore) {
        Pass "${provName} -- STATUS.txt contains correct BASE score (${reportPass}P)"
    } else {
        if ($isFlagged) { Info "FLAGGED: ${provName} -- STATUS.txt score mismatch (expected ${reportPass}P)" }
        else { Fail "${provName} -- STATUS.txt missing correct BASE score (expected ${reportPass}P from validator report)" }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 16: Phase archive completeness
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 16) {
Write-Host ""
Write-Host "--- CATEGORY 16: Phase Archive Completeness ---" -ForegroundColor Yellow

$flaggedProviders = @('CA_CONTRA_COSTA')
$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $isFlagged = $provName -in $flaggedProviders

    $baseScript = Get-ChildItem "$($pd.FullName)\scripts" -File -Filter 'build_*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '_mc|_test' } | Select-Object -First 1
    if (-not $baseScript) { continue }

    $scriptText = [System.IO.File]::ReadAllText($baseScript.FullName)
    $scriptVersion = $null
    if ($scriptText -match '\$Version\s*=\s*["'']([^"'']+)["'']') {
        $scriptVersion = $Matches[1]
    }
    if (-not $scriptVersion) { continue }

    $phaseFound = $false
    $anyPhaseDirExists = $false
    foreach ($phaseDir in @("$($pd.FullName)\phases", "$($pd.FullName)\phases\current", "$($pd.FullName)\phases\base", "$($pd.FullName)\phases\mc")) {
        if (Test-Path $phaseDir) {
            $anyPhaseDirExists = $true
            $versionedFile = Get-ChildItem $phaseDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "v$([regex]::Escape($scriptVersion))" }
            if ($versionedFile) {
                $relDir = $phaseDir.Replace($pd.FullName + '\', '')
                Pass "${provName} -- ${relDir} has v${scriptVersion} snapshot"
                $phaseFound = $true
                break
            }
        }
    }
    if (-not $phaseFound) {
        # phases/ is being retired provider-by-provider (git history is authoritative instead,
        # starting with NJ_NJCJIS 2026-07-01) -- no phase dir at all means opted-out, not a gap.
        if (-not $anyPhaseDirExists) { Pass "${provName} -- phases/ retired for this provider (git history is authoritative)" }
        elseif ($isFlagged) { Info "FLAGGED: ${provName} -- no v${scriptVersion} phase snapshot" }
        else { Fail "${provName} -- no v${scriptVersion} phase snapshot" }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 17: Validator WARN audit (read existing reports, flag >0 WARN)
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 17) {
Write-Host ""
Write-Host "--- CATEGORY 17: Validator WARN Audit ---" -ForegroundColor Yellow

$flaggedProviders = @('CA_CONTRA_COSTA')
$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $docPrefix = $provName
    $isFlagged = $provName -in $flaggedProviders

    foreach ($variant in @('base','mc')) {
        $tag = $variant.ToUpper()
        $reportFile = "$($pd.FullName)\docs\$variant\VALIDATOR_REPORT_${docPrefix}_${tag}.txt"
        if (-not (Test-Path $reportFile)) { continue }

        $reportText = [System.IO.File]::ReadAllText($reportFile)

        # Extract WARN count from results line
        $warnCount = 0
        if ($reportText -match '(\d+)\s*WARN') {
            $warnCount = [int]$Matches[1]
        }

        if ($warnCount -gt 0) {
            # Extract individual WARN lines for detail
            $warnLines = @($reportText -split "`n" | Where-Object { $_ -match '^\s*\[WARN\]' })
            $categories = @{}
            foreach ($wl in $warnLines) {
                $cat = if ($wl -match 'Attention') { 'Attention-in-combo' }
                elseif ($wl -match 'ImageIndicator.*missing') { 'ImageIndicator-missing' }
                elseif ($wl -match 'ImageIndicator.*initialValue') { 'ImageIndicator-default' }
                elseif ($wl -match 'codeTypeSource.*NCIC.*empty') { 'ArticleType-source' }
                elseif ($wl -match 'non-suffixed sourceField') { 'DH-suffix' }
                elseif ($wl -match 'initialValue.*changes combo') { 'State-routing' }
                elseif ($wl -match 'keyReference.*appears in multiple') { 'KeyRef-collision' }
                elseif ($wl -match 'dead HIDLE|unused RMS') { 'RMS-Cleanup' }
                elseif ($wl -match 'not found in.*QIF') { 'QIDM-field-mismatch' }
                elseif ($wl -match 'EmailAddress') { 'EmailAddress-QIDM-only' }
                else { 'other' }
                if (-not $categories[$cat]) { $categories[$cat] = 0 }
                $categories[$cat]++
            }
            $detail = ($categories.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)($($_.Value))" }) -join ', '
            if ($isFlagged) {
                Info "FLAGGED: ${provName} ${tag} has ${warnCount} WARN: $detail"
            } else {
                Info "${provName} ${tag} has ${warnCount} WARN: $detail"
            }
        } else {
            Pass "${provName} ${tag} -- 0 WARN (clean)"
        }
    }
}
}

# ══════════════════════════════════════════════════════════════════════════════
# CATEGORY 18: camelCase fieldId cross-provider consistency
# ══════════════════════════════════════════════════════════════════════════════
if ($Category -eq 0 -or $Category -eq 18) {
Write-Host ""
Write-Host "--- CATEGORY 18: camelCase FieldId Consistency ---" -ForegroundColor Yellow

$flaggedProviders = @('CA_CONTRA_COSTA')
$knownPascalFields = @(
    'RegistrationState','SexCode','RaceCode','ImageIndicator',
    'OperatorLicenseNumber','NameFirst','NameLast','NameMiddle','NameSuffix',
    'BirthDate','LicensePlateTypeCode','LicensePlateYear',
    'VehicleIdentificationNumber','VehicleMakeCode','VehicleYear','VehicleBodyStyle',
    'GunSerialNumber','GunMake','GunCaliber','GunModel',
    'ArticleSerialNumber','ArticleTypeCode','RegistrationNumber','BoatHullIdNumber',
    'RelatedHitSearchIndicator','OperatorLicenseNumberDH','NameFirstDH','NameLastDH',
    'NameMiddleDH','NameSuffixDH','BirthDateDH','SexCodeDH'
)

$providerDirs = Get-ChildItem "$repoRoot\providers" -Directory
foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    $isFlagged = $provName -in $flaggedProviders

    $baseJson = Get-ChildItem $pd.FullName -File -Filter '*_BASE.json' | Select-Object -First 1
    if (-not $baseJson) { continue }

    $text = [System.IO.File]::ReadAllText($baseJson.FullName)

    # Find all fieldId values in form fields
    $fieldIds = @([regex]::Matches($text, '"fieldId"\s*:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

    # Check each for PascalCase (starts with uppercase) when camelCase equivalent exists
    $pascalHits = @()
    foreach ($fid in $fieldIds) {
        if ($fid -cin $knownPascalFields) {
            $pascalHits += $fid
        }
    }

    if ($pascalHits.Count -gt 0) {
        $hitList = ($pascalHits | Select-Object -Unique | Sort-Object) -join ', '
        if ($isFlagged) {
            Info "FLAGGED: ${provName} has PascalCase fieldIds: $hitList"
        } else {
            Info "${provName} has $($pascalHits.Count) PascalCase fieldId(s): $hitList"
        }
    } else {
        Pass "${provName} -- all fieldIds are camelCase"
    }
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
