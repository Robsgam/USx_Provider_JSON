<#
  score_all.ps1 -- Provider Scorecard Generator
  Runs the validator across all providers and produces a summary table
  showing PASS/FAIL/WARN/LIMITATION counts, sorted by WARN count (worst first).

  Usage: .\score_all.ps1
         .\score_all.ps1 -OutFile scorecard.txt
         .\score_all.ps1 -Quick          # Parse existing report files instead of re-running validator

  Flags:
    -OutFile  <path>   Save scorecard to file (in addition to console output)
    -Quick             Skip live validator run; parse existing VALIDATOR_REPORT_*.txt files
#>

param(
    [string]$OutFile,
    [switch]$Quick
)

$ErrorActionPreference = "Stop"
$toolDir = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$providersDir = Join-Path $repoRoot "providers"

if (-not (Test-Path $providersDir)) {
    Write-Host "  [ERROR] Providers directory not found: $providersDir" -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

# ── Output helpers ────────────────────────────────────────────────────────────
$script:outputLines = @()

function Out([string]$msg) {
    $script:outputLines += $msg
    Write-Host $msg
}

function OutColor([string]$msg, [string]$color) {
    $script:outputLines += $msg
    Write-Host $msg -ForegroundColor $color
}

# ── Parse validator output for counts ─────────────────────────────────────────
function Parse-ValidatorOutput([string]$text) {
    $pass = 0; $fail = 0; $warn = 0; $limit = 0

    # Try to find the summary line first (most reliable)
    if ($text -match 'RESULTS:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN') {
        $pass = [int]$Matches[1]
        $fail = [int]$Matches[2]
        $warn = [int]$Matches[3]
        if ($text -match 'RESULTS:.*?/\s*(\d+)\s*LIMITATION') {
            $limit = [int]$Matches[1]
        }
    } else {
        # Fallback: count individual lines
        $lines = $text -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^\s*\[PASS\]')       { $pass++ }
            if ($line -match '^\s*\[FAIL\]')       { $fail++ }
            if ($line -match '^\s*\[WARN\]')       { $warn++ }
            if ($line -match '^\s*\[LIMITATION\]')  { $limit++ }
        }
    }

    return @{ Pass = $pass; Fail = $fail; Warn = $warn; Limit = $limit }
}

# ── Discover providers ────────────────────────────────────────────────────────
$providerDirs = Get-ChildItem $providersDir -Directory | Sort-Object Name
$results = @()

foreach ($dir in $providerDirs) {
    $folderName = $dir.Name
    $providerName = $folderName

    # Find BASE JSON
    $baseJson = Get-ChildItem $dir.FullName -Filter "*_BASE.json" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    # Find MC JSON
    $mcJson = Get-ChildItem $dir.FullName -Filter "*_MC.json" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '_MC_BASE' } |
        Select-Object -First 1
    if (-not $mcJson) {
        $mcJson = Get-ChildItem $dir.FullName -Filter "*_MC_BASE.json" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }

    $baseScore = $null
    $mcScore = $null

    # ── BASE ──────────────────────────────────────────────────────────────────
    if ($baseJson) {
        if ($Quick) {
            # Parse existing report file
            $reportPattern = Join-Path $dir.FullName "docs\base\VALIDATOR_REPORT_*_BASE.txt"
            $reportFile = Get-ChildItem $reportPattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($reportFile) {
                $reportText = Get-Content $reportFile.FullName -Raw -Encoding UTF8
                $baseScore = Parse-ValidatorOutput $reportText
            } else {
                Write-Host "  [SKIP] $providerName BASE: no report file found (run without -Quick)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  Running validator: $($baseJson.Name)..." -ForegroundColor DarkGray -NoNewline
            $validatorPath = Join-Path $toolDir "validate.ps1"
            $validatorOut = & powershell -ExecutionPolicy Bypass -File $validatorPath -Path $baseJson.FullName -Force 2>&1 | Out-String
            $baseScore = Parse-ValidatorOutput $validatorOut
            Write-Host " done" -ForegroundColor DarkGray
        }
    }

    # ── MC ────────────────────────────────────────────────────────────────────
    if ($mcJson) {
        if ($Quick) {
            $reportPattern = Join-Path $dir.FullName "docs\mc\VALIDATOR_REPORT_*_MC.txt"
            $reportFile = Get-ChildItem $reportPattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($reportFile) {
                $reportText = Get-Content $reportFile.FullName -Raw -Encoding UTF8
                $mcScore = Parse-ValidatorOutput $reportText
            } else {
                Write-Host "  [SKIP] $providerName MC: no report file found (run without -Quick)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  Running validator: $($mcJson.Name)..." -ForegroundColor DarkGray -NoNewline
            $validatorPath = Join-Path $toolDir "validate.ps1"
            $validatorOut = & powershell -ExecutionPolicy Bypass -File $validatorPath -Path $mcJson.FullName -Force 2>&1 | Out-String
            $mcScore = Parse-ValidatorOutput $validatorOut
            Write-Host " done" -ForegroundColor DarkGray
        }
    }

    $results += [PSCustomObject]@{
        Provider   = $providerName
        Folder     = $folderName
        HasBase    = [bool]$baseJson
        HasMC      = [bool]$mcJson
        BaseScore  = $baseScore
        McScore    = $mcScore
    }
}

# ── Format score string ──────────────────────────────────────────────────────
function Format-Score($score) {
    if (-not $score) { return "--" }
    $s = "$($score.Pass)P/$($score.Fail)F/$($score.Warn)W/$($score.Limit)LIM"
    return $s
}

# ── Sort by WARN count descending (worst first) ──────────────────────────────
# Combined WARN = BASE warn + MC warn. Providers with no JSONs go last.
$results = $results | Sort-Object -Property @{
    Expression = {
        $totalWarn = 0
        if ($_.BaseScore) { $totalWarn += $_.BaseScore.Warn }
        if ($_.McScore) { $totalWarn += $_.McScore.Warn }
        if (-not $_.HasBase -and -not $_.HasMC) { return -1 }
        return $totalWarn
    }
    Descending = $true
}

# ── Render table ──────────────────────────────────────────────────────────────
$colProvider = 26
$colBase = 22
$colMc = 22
$colRebuild = 14

Out ""
OutColor ("=" * 90) "Cyan"
OutColor "  Provider Scorecard -- $timestamp" "Cyan"
if ($Quick) { OutColor "  Mode: QUICK (parsed existing report files)" "DarkYellow" }
OutColor ("=" * 90) "Cyan"
Out ""

$header = "  {0,-$colProvider} {1,-$colBase} {2,-$colMc} {3}" -f "Provider", "BASE", "MC", "Rebuild"
OutColor $header "White"
$divider = "  {0,-$colProvider} {1,-$colBase} {2,-$colMc} {3}" -f ("-" * ($colProvider - 1)), ("-" * ($colBase - 1)), ("-" * ($colMc - 1)), ("-" * ($colRebuild - 1))
OutColor $divider "DarkGray"

$totalProviders = $results.Count
$totalNeedRebuild = 0
$totalWarns = 0
$totalFails = 0

foreach ($r in $results) {
    $baseStr = Format-Score $r.BaseScore
    $mcStr = Format-Score $r.McScore

    # Calculate rebuild flag
    $baseWarns = if ($r.BaseScore) { $r.BaseScore.Warn } else { 0 }
    $mcWarns = if ($r.McScore) { $r.McScore.Warn } else { 0 }
    $baseFails = if ($r.BaseScore) { $r.BaseScore.Fail } else { 0 }
    $mcFails = if ($r.McScore) { $r.McScore.Fail } else { 0 }
    $combinedWarns = $baseWarns + $mcWarns
    $combinedFails = $baseFails + $mcFails

    $totalWarns += $combinedWarns
    $totalFails += $combinedFails

    if (-not $r.HasBase -and -not $r.HasMC) {
        $rebuildStr = "N/A"
    } elseif ($combinedWarns -gt 0 -or $combinedFails -gt 0) {
        $rebuildStr = "YES"
        $totalNeedRebuild++
    } else {
        $rebuildStr = "NO"
    }

    $line = "  {0,-$colProvider} {1,-$colBase} {2,-$colMc} {3}" -f $r.Provider, $baseStr, $mcStr, $rebuildStr

    # Color based on severity
    if ($combinedFails -gt 0) {
        OutColor $line "Red"
    } elseif ($combinedWarns -gt 0) {
        OutColor $line "Yellow"
    } elseif (-not $r.HasBase -and -not $r.HasMC) {
        OutColor $line "DarkGray"
    } else {
        OutColor $line "Green"
    }
}

Out ""
OutColor ("=" * 90) "Cyan"
$summaryLine = "  TOTAL: $totalProviders providers | $totalNeedRebuild need rebuild | $totalWarns total WARNs | $totalFails total FAILs"
if ($totalFails -gt 0) {
    OutColor $summaryLine "Red"
} elseif ($totalWarns -gt 0) {
    OutColor $summaryLine "Yellow"
} else {
    OutColor $summaryLine "Green"
}
OutColor ("=" * 90) "Cyan"
Out ""

# ── Save to file ──────────────────────────────────────────────────────────────
if ($OutFile) {
    $script:outputLines | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "  Saved: $OutFile" -ForegroundColor Green
}
