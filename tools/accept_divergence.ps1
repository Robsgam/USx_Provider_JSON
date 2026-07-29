<#
  accept_divergence.ps1 -- Append a reasoned entry to a provider's accepted-divergence registry.

  audit_metadata.ps1 reads this registry (CHECK 4 / 4d / 5). Any entry recorded here is treated
  as [NOTE] instead of [FAIL] so intentional, tested divergences do not block the build gate.
  CHECK 5 (Primary Field Coverage) honors it too (added 2026-06-23): a documented deferred
  primary-combo gap (e.g. MD_METERS GunQuery|ZGUN|GunMake) recorded here becomes a [NOTE].

  Registry path: providers/<Provider>/docs/<Provider>_ACCEPTED_DIVERGENCES.txt
  The parser keys on the FIRST THREE pipe-delimited fields (query|keyRef|field), lowercased.
  Lines starting with # are comments and are ignored by the parser.

  Usage:
    .\accept_divergence.ps1 -Provider NJ_NJCJIS -Query DriverLicenseQuery -KeyRef DLN -Field State `
        -Rule demoted-to-any -Reason "State is OOS-only; in-state combo omits it by design"
    .\accept_divergence.ps1 -Provider FL_FCIC -Query DriverHistoryQuery -KeyRef KH -Field SexCode `
        -Rule approved-skip -Reason "SexCode not in metadata for KH combo; devdoc confirmed" `
        -TestLog providers/FL_FCIC/tests/T12_DH_KH_PASS.txt
#>

param(
    [Parameter(Mandatory=$true)][string]$Provider,
    [Parameter(Mandatory=$true)][string]$Query,
    [Parameter(Mandatory=$true)][string]$KeyRef,
    [Parameter(Mandatory=$true)][string]$Field,
    [Parameter(Mandatory=$true)][string]$Rule,
    [Parameter(Mandatory=$true)][string]$Reason,
    [string]$TestLog,
    [string]$Date
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_resolve_docs_path.ps1")
$repoRoot  = Split-Path $PSScriptRoot -Parent
$provDir   = Join-Path $repoRoot ("providers\{0}" -f $Provider)
$docsDir   = Join-Path $provDir "docs"
# ACCEPTED_DIVERGENCES is a 'tracking' category doc; the resolver returns docs/tracking/ for
# migrated providers and falls back to flat docs/ for legacy ones (matches audit_metadata's read).
$registry  = Get-DocsPath $provDir 'tracking' ("{0}_ACCEPTED_DIVERGENCES.txt" -f $Provider)

# -- Guard: docs/ must exist --
if (-not (Test-Path $docsDir)) {
    Write-Host "  [ERROR] docs directory not found: $docsDir" -ForegroundColor Red
    Write-Host "          Create the provider first with new_provider.ps1, or verify -Provider spelling." -ForegroundColor Yellow
    exit 1
}

# -- Date --
if (-not $Date) { $Date = Get-Date -Format "yyyy-MM-dd" }

# -- Source column --
$source = if ($TestLog) { "test-log:$TestLog" } else { "metadata-vs-devdoc" }

# -- Create file with header if it doesn't exist --
if (-not (Test-Path $registry)) {
    $headerLines = @(
        "# $Provider ACCEPTED METADATA DIVERGENCES",
        "# Read by tools/audit_metadata.ps1 (CHECK 4 / 4d). Each non-comment line records a",
        "# set/any divergence that is intentional and correct, so the gate treats it as [NOTE] not [FAIL].",
        "# Format (pipe-delimited): query | keyRef | field | rule | reason | source | date",
        "#",
        ""
    )
    Set-Content -Path $registry -Value $headerLines -Encoding utf8
    Write-Host "  Created: $registry" -ForegroundColor Gray
}

# -- Idempotency check: first three fields, case-insensitive --
$key = "$($Query.ToLower())|$($KeyRef.ToLower())|$($Field.ToLower())"
$existing = Get-Content $registry | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }

# A well-formed record is 7 pipe-delimited fields = exactly 6 pipes. More than that
# means two records were merged onto one line (see the trailing-newline note below).
# Line-based parsers -- this one and audit_metadata's -- only ever see the first, so
# surface it. Count pipes, NOT "a date followed by text": reason prose legitimately
# contains dates (FL_FCIC/HI_HCJDC_OFML both do), and that heuristic cries wolf.
foreach ($line in $existing) {
    if (([regex]::Matches($line, '\|')).Count -gt 6) {
        Write-Host "  [WARN] Merged records on one line -- the trailing record is invisible to audit_metadata. Split it:" -ForegroundColor Red
        Write-Host "         $line" -ForegroundColor Gray
    }
}

foreach ($line in $existing) {
    $parts = $line -split '\|'
    if ($parts.Count -ge 3) {
        $lineKey = "$($parts[0].Trim().ToLower())|$($parts[1].Trim().ToLower())|$($parts[2].Trim().ToLower())"
        if ($lineKey -eq $key) {
            Write-Host "  [SKIP] Entry already exists (query=$Query keyRef=$KeyRef field=$Field):" -ForegroundColor Yellow
            Write-Host "         $line" -ForegroundColor Gray
            exit 0
        }
    }
}

# -- Append the new entry --
# Add-Content appends directly onto the last line when the file has no trailing
# newline, merging two records into one physical line. audit_metadata parses this
# registry line-by-line, so the second record silently disappears from the gate
# (found 2026-07-29 in FL_FCIC/HI_HCJDC_OFML/TX_TLETS -- 4 lost records, incl. the
# TX RSDWW shadow-unbuilt-REVISIT note). Guarantee the newline before appending.
$raw = [System.IO.File]::ReadAllText($registry)
if ($raw.Length -gt 0 -and -not ($raw -match '\r?\n$')) {
    $nl = if ($raw -match '\r\n') { "`r`n" } else { "`n" }
    [System.IO.File]::AppendAllText($registry, $nl)
    Write-Host "  [FIX] Registry had no trailing newline -- added before append" -ForegroundColor Yellow
}

# The registry is pipe-delimited, so a raw '|' inside any field shifts every column
# after it (TX_TLETS_CCH had "Choice{SSN|Misc}" in a reason, pushing source/date to
# parts[6]/[7]). Substitute before writing rather than corrupting the record.
foreach ($n in 'Query','KeyRef','Field','Rule','Reason') {
    $v = (Get-Variable $n).Value
    if ($v -match '\|') {
        Write-Host "  [FIX] '|' in -$n replaced with '/' (pipe is the field delimiter)" -ForegroundColor Yellow
        Set-Variable $n -Value ($v -replace '\s*\|\s*', ' / ')
    }
}

$entry = "$Query | $KeyRef | $Field | $Rule | $Reason | $source | $Date"
Add-Content -Path $registry -Value $entry -Encoding utf8

Write-Host "  [OK] Appended to $registry" -ForegroundColor Green
Write-Host "       $entry" -ForegroundColor Cyan
