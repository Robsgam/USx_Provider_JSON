<#
  set_tier.ps1 -- choose the active USx Tenant Testing tier for a provider.

  Two tiers (see knowledge-base/TESTING_REQUIREMENTS.txt):
    Preliminary -- render per entity + EVERY combo fired with required (set[]) fields
                   only + a negative per entity. Proves all routing paths cheaply.
    Final       -- Preliminary PLUS each combo's optional (any[]) field permutations +
                   guardrail/priority tests + deselect tests. The full FL_FCIC standard.

  The active tier drives:
    - which matrix to run (docs/<P>_TEST_MATRIX_PRELIMINARY.txt vs _TEST_MATRIX.txt),
    - what post_test.ps1 stamps into each log,
    - what block_entity.ps1 requires before it will block an entity.

  Writes tests/.test_tier. Default tier when the file is absent is 'Final'.

  Usage:
    .\set_tier.ps1 -Provider NJ_NJCJIS -Tier Preliminary
    .\set_tier.ps1 -Provider NJ_NJCJIS -Tier Final
    .\set_tier.ps1 -Provider NJ_NJCJIS            # report current tier only
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [ValidateSet('Preliminary','Final')][string]$Tier
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$testsDir = Join-Path $provDir "tests"

. "$toolDir\_test_provenance.ps1"

if (-not (Test-Path $provDir)) { Write-Host "  [ERROR] Provider not found: $Provider" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $testsDir)) { New-Item -ItemType Directory -Path $testsDir | Out-Null }

$tierFile = Join-Path $testsDir ".test_tier"
$current = Get-ActiveTier $provDir

if (-not $Tier) {
    Write-Host "  $Provider active tier: $current" -ForegroundColor Cyan
    exit 0
}

[System.IO.File]::WriteAllText($tierFile, $Tier, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  $Provider tier: $current -> $Tier" -ForegroundColor Green
$matrix = if ($Tier -eq 'Preliminary') { "docs/${Provider}_TEST_MATRIX_PRELIMINARY.txt" } else { "docs/${Provider}_TEST_MATRIX.txt" }
Write-Host "    Run: $matrix" -ForegroundColor Gray
Write-Host "    Logs from post_test.ps1 will stamp Tier: $Tier; block_entity enforces this tier's coverage." -ForegroundColor Gray
exit 0
