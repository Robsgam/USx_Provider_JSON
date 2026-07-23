<#
  sync_provider_table.ps1 -- Auto-update CLAUDE.md provider status table from live validator scores
  Reads each provider's VALIDATOR_REPORT files (BASE and MC), parses the RESULTS summary line,
  and updates the score portion of the Status column in the CLAUDE.md Provider Status table.

  Preserves all other table content: Version, Path, Notable patterns, and any flags
  after the score (NEW, test results, descriptive text).

  Usage: .\sync_provider_table.ps1
         .\sync_provider_table.ps1 -DryRun
         .\sync_provider_table.ps1 -OutFile .\CLAUDE_updated.md
#>

param(
    [switch]$DryRun,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$claudeMd = Join-Path $repoRoot "CLAUDE.md"

if (-not (Test-Path $claudeMd)) {
    Write-Host "  [ERROR] CLAUDE.md not found at $claudeMd" -ForegroundColor Red
    exit 1
}

# ── Helpers ──

function Parse-ValidatorResults {
    <#
      Reads a validator report file and returns the score string (e.g. "69P/0F/0W/1LIM")
      or $null if no RESULTS line found.
    #>
    param([string]$ReportPath)

    if (-not (Test-Path $ReportPath)) { return $null }

    $content = Get-Content $ReportPath -Raw -Encoding UTF8
    # Match: RESULTS: 69 PASS / 0 FAIL / 0 WARN / 1 LIMITATION
    # Some reports omit the LIMITATION count (e.g., "59 PASS / 0 FAIL / 7 WARN")
    if ($content -match 'RESULTS:\s+(\d+)\s+PASS\s*/\s*(\d+)\s+FAIL\s*/\s*(\d+)\s+WARN\s*/\s*(\d+)\s+LIMITATION') {
        return "$($Matches[1])P/$($Matches[2])F/$($Matches[3])W/$($Matches[4])LIM"
    }
    elseif ($content -match 'RESULTS:\s+(\d+)\s+PASS\s*/\s*(\d+)\s+FAIL\s*/\s*(\d+)\s+WARN') {
        return "$($Matches[1])P/$($Matches[2])F/$($Matches[3])W/0LIM"
    }
    return $null
}

function Find-ValidatorReport {
    <#
      Finds the validator report file for a provider folder and variant.
        base/mc -> legacy dual-JSON report in docs\<variant>\VALIDATOR_REPORT_*_<VARIANT>.txt
        single  -> galvanized single-JSON report VALIDATOR_REPORT_<PROVIDER>.txt anywhere under
                   docs\ (flat or 4-category reports\), EXCLUDING the _BASE/_MC-suffixed variants.
      Returns the path or $null.
    #>
    param([string]$ProviderDir, [string]$Variant)

    if ($Variant -eq 'single') {
        $docsRoot = Join-Path $ProviderDir "docs"
        if (-not (Test-Path $docsRoot)) { return $null }
        $reports = Get-ChildItem $docsRoot -Recurse -File -Filter "VALIDATOR_REPORT_*.txt" -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -notmatch '_(BASE|MC)\.txt$' }
        if (-not $reports -or $reports.Count -eq 0) { return $null }
        return ($reports | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }

    $docsDir = Join-Path $ProviderDir "docs\$Variant"
    if (-not (Test-Path $docsDir)) { return $null }

    $reports = Get-ChildItem $docsDir -Filter "VALIDATOR_REPORT_*_$($Variant.ToUpper()).txt" -File -ErrorAction SilentlyContinue
    if ($reports.Count -eq 0) { return $null }

    # Return the most recently modified one
    return ($reports | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

# ── Score pattern regexes ──

# Single score: 69P/0F/0W/1LIM
$scoreRx = '\d+P/\d+F/\d+W/\d+LIM'
# Dual score: 64P/0F/0W/5LIM (BASE) 68P/0F/0W/7LIM (MC)
$dualScoreRx = "$scoreRx \(BASE\) $scoreRx \(MC\)"

# ── Read CLAUDE.md ──

$lines = [System.IO.File]::ReadAllLines($claudeMd)

# Find the Provider Status table boundaries
$tableStart = -1
$tableEnd = -1
$headerLineIdx = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^## Provider Status') {
        $tableStart = $i
    }
    elseif ($tableStart -ge 0 -and $tableEnd -lt 0) {
        # Find the header row (starts with | Provider)
        if ($lines[$i] -match '^\|\s*Provider\s*\|') {
            $headerLineIdx = $i
        }
        # Find the end: next ## heading after we've entered the table
        if ($lines[$i] -match '^## ' -and $i -gt $tableStart) {
            $tableEnd = $i
            break
        }
    }
}

if ($tableStart -lt 0 -or $headerLineIdx -lt 0) {
    Write-Host "  [ERROR] Could not find Provider Status table in CLAUDE.md" -ForegroundColor Red
    exit 1
}

if ($tableEnd -lt 0) { $tableEnd = $lines.Count }

# ── Banner ──

$today = Get-Date -Format "yyyy-MM-dd"
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "    Sync Provider Table -- $today" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""

# ── Process each table row ──

$updateCount = 0
$totalProviders = 0
$changes = @()

# Data rows start after the separator row (headerLineIdx + 1 = separator, headerLineIdx + 2 = first data row)
# Actually: headerLineIdx = header, headerLineIdx+1 = separator (|---|---|...), headerLineIdx+2.. = data
for ($i = ($headerLineIdx + 2); $i -lt $tableEnd; $i++) {
    $line = $lines[$i]

    # Skip non-table lines
    if ($line -notmatch '^\|') { continue }

    # Split the table row into columns
    # | Provider | Path | Version | Status | Notable patterns |
    $cols = $line -split '\|'
    # cols[0] = "" (before first |), cols[1] = Provider, cols[2] = Path, cols[3] = Version, cols[4] = Status, cols[5] = Notable patterns, cols[6] = "" (after last |)
    if ($cols.Count -lt 6) { continue }

    $providerName = $cols[1].Trim()
    $pathCol = $cols[2].Trim()
    $statusCol = $cols[4].Trim()

    if (-not $providerName -or $providerName -match '^-+$') { continue }

    $totalProviders++

    # Extract folder name from path column (e.g., "providers/NJ_NJCJIS/" -> "NJ_NJCJIS")
    $folderName = $null
    if ($pathCol -match 'providers/([^/]+)/?') {
        $folderName = $Matches[1]
    }

    if (-not $folderName) {
        Write-Host "  $($providerName):".PadRight(25) -NoNewline -ForegroundColor White
        Write-Host "skipped (no folder in Path column)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (no folder)" }
        continue
    }

    $providerDir = Join-Path $repoRoot "providers\$folderName"
    if (-not (Test-Path $providerDir)) {
        Write-Host "  $($providerName):".PadRight(25) -NoNewline -ForegroundColor White
        Write-Host "skipped (folder not found: $folderName)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (folder missing)" }
        continue
    }

    # ── Find and parse validator reports ──

    $baseReport = Find-ValidatorReport -ProviderDir $providerDir -Variant "base"
    $mcReport = Find-ValidatorReport -ProviderDir $providerDir -Variant "mc"

    $baseScore = if ($baseReport) { Parse-ValidatorResults -ReportPath $baseReport } else { $null }
    $mcScore = if ($mcReport) { Parse-ValidatorResults -ReportPath $mcReport } else { $null }

    # Galvanized single-JSON providers: report is VALIDATOR_REPORT_<PROVIDER>.txt (no BASE/MC suffix)
    $singleReport = Find-ValidatorReport -ProviderDir $providerDir -Variant "single"
    $singleScore  = if ($singleReport) { Parse-ValidatorResults -ReportPath $singleReport } else { $null }

    if (-not $baseScore -and -not $mcScore -and -not $singleScore) {
        Write-Host "  $($providerName):".PadRight(25) -NoNewline -ForegroundColor White
        Write-Host "skipped (no validator reports)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (no reports)" }
        continue
    }

    # ── Determine if this is a dual-score or single-score row ──

    $oldStatus = $statusCol
    $newStatus = $statusCol

    $isDualRow = ($statusCol -match "$scoreRx \(BASE\)") -or ($statusCol -match "$scoreRx \(MC\)")

    if ($isDualRow -and $baseScore -and $mcScore) {
        # Replace dual score: oldBaseScore (BASE) oldMcScore (MC) -> newBaseScore (BASE) newMcScore (MC)
        $newStatus = $statusCol -replace "$scoreRx (\(BASE\)) $scoreRx (\(MC\))", "$baseScore `$1 $mcScore `$2"
    }
    elseif ($isDualRow -and $baseScore) {
        # Only BASE report available -- update just the BASE score
        $newStatus = $statusCol -replace "($scoreRx)( \(BASE\))", "$baseScore`$2"
    }
    elseif ($isDualRow -and $mcScore) {
        # Only MC report available -- update just the MC score
        $newStatus = $statusCol -replace "($scoreRx)( \(MC\))", "$mcScore`$2"
    }
    elseif (-not $isDualRow -and ($singleScore -or $baseScore)) {
        # Single score row (galvanized single-JSON, or a legacy single-report provider):
        # replace the FIRST score occurrence only (the leading P/F/W/LIM), so we don't touch
        # any score-shaped text later in the rich narrative cell.
        $useScore = if ($singleScore) { $singleScore } else { $baseScore }
        $newStatus = [regex]::Replace($statusCol, $scoreRx, $useScore, 1)
    }

    # ── Report changes ──

    if ($newStatus -ne $oldStatus) {
        # Extract just the score portions for display
        $oldScoreDisplay = ""
        $newScoreDisplay = ""

        if ($isDualRow) {
            [void]($oldStatus -match "($scoreRx) \(BASE\) ($scoreRx) \(MC\)")
            $oldScoreDisplay = "$($Matches[1]) (BASE) $($Matches[2]) (MC)"
            [void]($newStatus -match "($scoreRx) \(BASE\) ($scoreRx) \(MC\)")
            $newScoreDisplay = "$($Matches[1]) (BASE) $($Matches[2]) (MC)"
        }
        else {
            [void]($oldStatus -match "($scoreRx)")
            $oldScoreDisplay = $Matches[1]
            [void]($newStatus -match "($scoreRx)")
            $newScoreDisplay = $Matches[1]
        }

        Write-Host "  $($providerName):".PadRight(25) -NoNewline -ForegroundColor White
        Write-Host "$oldScoreDisplay -> $newScoreDisplay" -NoNewline -ForegroundColor Green
        Write-Host "  (updated)" -ForegroundColor Green

        # Rebuild the line with updated status column, preserving column widths
        $cols[4] = " $newStatus "
        $lines[$i] = ($cols -join '|')

        $updateCount++
        $changes += @{ Provider = $providerName; Result = "updated"; Old = $oldScoreDisplay; New = $newScoreDisplay }
    }
    else {
        Write-Host "  $($providerName):".PadRight(25) -NoNewline -ForegroundColor White
        Write-Host "no change" -ForegroundColor DarkGray

        $changes += @{ Provider = $providerName; Result = "no change" }
    }
}

# ── Update the "updated" date in the section header ──

for ($i = $tableStart; $i -le $tableStart + 2; $i++) {
    if ($lines[$i] -match '^## Provider Status') {
        $lines[$i] = "## Provider Status (updated $today)"
    }
}

# ── Write output ──

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "    DRY RUN: $updateCount of $totalProviders providers would be updated" -ForegroundColor Yellow
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
}
else {
    $targetFile = if ($OutFile) { $OutFile } else { $claudeMd }
    [System.IO.File]::WriteAllLines($targetFile, $lines)

    Write-Host "    Updated $updateCount of $totalProviders providers in $(Split-Path $targetFile -Leaf)" -ForegroundColor Green
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
}
