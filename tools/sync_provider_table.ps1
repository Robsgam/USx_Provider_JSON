<#
  sync_provider_table.ps1 -- Auto-update the CLAUDE.md Provider Status table from derived truth.

  Syncs three columns per row: Version, Validator (P/F/W[/LIM]), and Tenant test.
  All three are DERIVED via tools\_test_status_lib.ps1 -- the same primitives
  portfolio_status.ps1 and report_test_status.ps1 use -- so the CLAUDE.md table can
  never disagree with the canonical status table.

  Preserves everything else in the row: Path, Notable patterns, History link.

  WHY IT DERIVES INSTEAD OF PARSING ITS OWN REPORTS (2026-07-29):
    This tool used to carry a private copy of the validator-report parser plus its own
    score regex, `\d+P/\d+F/\d+W/\d+LIM`, which REQUIRED a trailing "/<n>LIM" segment in
    the table cell. When the CLAUDE.md table was rebuilt without that segment (cells became
    "76P/0F/0W"), the regex stopped matching every row, the replace became a no-op, and the
    tool reported "no change" for all 20 providers -- while the table silently rotted (TX_TLETS
    kept 78P after v4.13 removed 2 checks; NY/FL/CA kept stale tenant-test verdicts).
    A sync tool that cannot detect drift in the column it exists to sync is worse than no tool,
    because its green output is read as proof. Two lessons, both encoded below:
      1. Derive from the shared library; never re-implement a parser a lib already owns.
      2. Accept the score cell with OR without the LIM segment, and render LIM only when > 0.
    enforce.ps1 PHASE 3 now also verifies these cells (CHECK 3j), so a future format change
    fails loudly instead of going quiet.

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

. (Join-Path $toolDir "_test_status_lib.ps1")
. (Join-Path $toolDir "_claude_table_cells.ps1")

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

# ── Locate the columns we own, BY HEADER NAME (never by fixed index) ──
# The table has been re-shaped before (a Tenant-test column was inserted, shifting every
# index after it). Resolving by header name means a future re-shape cannot silently point
# this tool at the wrong cell.

$hdrCols = $lines[$headerLineIdx] -split '\|'
$colIdx = @{}
for ($c = 0; $c -lt $hdrCols.Count; $c++) {
    switch -Regex ($hdrCols[$c].Trim()) {
        '^Provider$'    { $colIdx['Provider']  = $c }
        '^Path$'        { $colIdx['Path']      = $c }
        '^Version$'     { $colIdx['Version']   = $c }
        '^Validator$'   { $colIdx['Validator'] = $c }
        '^Tenant test$' { $colIdx['Tenant']    = $c }
    }
}

foreach ($req in @('Provider','Path','Version','Validator','Tenant')) {
    if (-not $colIdx.ContainsKey($req)) {
        Write-Host "  [ERROR] Provider Status table is missing the '$req' column -- header reads:" -ForegroundColor Red
        Write-Host "          $($lines[$headerLineIdx])" -ForegroundColor DarkGray
        exit 1
    }
}

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

for ($i = ($headerLineIdx + 2); $i -lt $tableEnd; $i++) {
    $line = $lines[$i]

    if ($line -notmatch '^\|') { continue }

    $cols = $line -split '\|'
    if ($cols.Count -le $colIdx['Tenant']) { continue }

    $providerName = $cols[$colIdx['Provider']].Trim()
    $pathCol      = $cols[$colIdx['Path']].Trim()

    if (-not $providerName -or $providerName -match '^-+$') { continue }

    $totalProviders++
    $label = "  $($providerName):".PadRight(25)

    # Extract folder name from path column (e.g., "providers/NJ_NJCJIS/" -> "NJ_NJCJIS")
    $folderName = $null
    if ($pathCol -match 'providers/([^/]+)/?') { $folderName = $Matches[1] }

    if (-not $folderName) {
        Write-Host $label -NoNewline -ForegroundColor White
        Write-Host "skipped (no folder in Path column)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (no folder)" }
        continue
    }

    $providerDir = Join-Path $repoRoot "providers\$folderName"
    if (-not (Test-Path $providerDir)) {
        Write-Host $label -NoNewline -ForegroundColor White
        Write-Host "skipped (folder not found: $folderName)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (folder missing)" }
        continue
    }

    # Legacy dual-JSON rows carry "(BASE)"/"(MC)" scores. The shared library has no
    # BASE/MC notion, so refuse the row loudly rather than mangling it into a single score.
    if ($cols[$colIdx['Validator']] -match '\((BASE|MC)\)') {
        Write-Host $label -NoNewline -ForegroundColor White
        Write-Host "skipped (legacy dual BASE/MC score -- sync by hand)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (dual score)" }
        continue
    }

    # ── Derive all three cells from the shared library ──

    $score = Get-ProviderValidatorScore -ProvDir $providerDir -Name $folderName
    $state = Get-ProviderTestState      -ProvDir $providerDir -Name $folderName

    if ($null -eq $score.Pass) {
        Write-Host $label -NoNewline -ForegroundColor White
        Write-Host "skipped (no validator report)" -ForegroundColor Yellow
        $changes += @{ Provider = $providerName; Result = "skipped (no reports)" }
        continue
    }

    $newCells = @{
        Version   = Format-ClaudeVersionCell   -State $state
        Validator = Format-ClaudeValidatorCell -Score $score
        Tenant    = Format-ClaudeTenantCell    -State $state
    }

    # ── Apply, preserving the single leading/trailing space convention ──

    $rowDiffs = @()
    foreach ($key in @('Version','Validator','Tenant')) {
        $new = $newCells[$key]
        if (-not $new) { continue }                       # not derivable -- leave the cell alone
        $old = $cols[$colIdx[$key]].Trim()
        if ($old -eq $new) { continue }
        $rowDiffs += "$key`: $old -> $new"
        $cols[$colIdx[$key]] = " $new "
    }

    if ($rowDiffs.Count -gt 0) {
        Write-Host $label -NoNewline -ForegroundColor White
        Write-Host ($rowDiffs -join "  |  ") -NoNewline -ForegroundColor Green
        Write-Host "  (updated)" -ForegroundColor Green

        $lines[$i] = ($cols -join '|')
        $updateCount++
        $changes += @{ Provider = $providerName; Result = "updated"; Diffs = ($rowDiffs -join "; ") }
    }
    else {
        Write-Host $label -NoNewline -ForegroundColor White
        Write-Host "no change" -ForegroundColor DarkGray
        $changes += @{ Provider = $providerName; Result = "no change" }
    }
}

# ── Update the "updated" date in the section header ──

if ($updateCount -gt 0) {
    for ($i = $tableStart; $i -lt [Math]::Min($tableStart + 3, $lines.Count); $i++) {
        if ($lines[$i] -match '^## Provider Status') {
            $lines[$i] = "## Provider Status (updated $today)"
            break
        }
    }
}

# ── Write output ──

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "    DRY RUN: $updateCount of $totalProviders providers would be updated" -ForegroundColor Yellow
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

$target = if ($OutFile) { $OutFile } else { $claudeMd }

if ($updateCount -gt 0 -or $OutFile) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($target, $lines, $utf8NoBom)
    Write-Host "    Updated $updateCount of $totalProviders providers -> $target" -ForegroundColor Green
}
else {
    Write-Host "    All $totalProviders providers already in sync -- no write needed" -ForegroundColor Green
}

Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""
exit 0
