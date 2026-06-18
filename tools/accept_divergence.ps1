<#
  accept_divergence.ps1 -- Append a reasoned entry to a provider's accepted-divergence registry.

  audit_metadata.ps1 reads this registry (CHECK 4 / 4d). Any entry recorded here is treated
  as [NOTE] instead of [FAIL] so intentional, tested divergences do not block the build gate.

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

$repoRoot  = Split-Path $PSScriptRoot -Parent
$docsDir   = Join-Path $repoRoot ("providers\{0}\docs" -f $Provider)
$registry  = Join-Path $docsDir ("{0}_ACCEPTED_DIVERGENCES.txt" -f $Provider)

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
$entry = "$Query | $KeyRef | $Field | $Rule | $Reason | $source | $Date"
Add-Content -Path $registry -Value $entry -Encoding utf8

Write-Host "  [OK] Appended to $registry" -ForegroundColor Green
Write-Host "       $entry" -ForegroundColor Cyan
