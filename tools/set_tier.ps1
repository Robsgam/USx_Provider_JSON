<#
  set_tier.ps1 -- DEPRECATED 2026-07-01.

  Testing tiers were removed. There is no longer a "Preliminary" subset -- testing is a
  single all-or-nothing "Full" pass (render per entity + EVERY combo + each combo's optional
  any[] permutations + guardrail/priority + deselect + a negative per entity; the full
  FL_FCIC standard).

  This script is retained only so existing references don't break. It ignores any -Tier
  argument, stamps logs/.test_tier = 'Full' (legacy: tests/.test_tier), and reports.
  block_entity.ps1 always enforces full-pass coverage; post_test.ps1 stamps Tier: Full.
  Get-ActiveTier (_test_provenance.ps1) always returns 'Full' unconditionally -- this file
  is not actually read by anything; kept only for back-compat reporting.

  Usage:
    .\set_tier.ps1 -Provider NJ_NJCJIS          # stamp/report (Full)
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [string]$Tier   # ignored (tiers removed); accepted for back-compat
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$logsRoot = Join-Path $provDir "logs"

if (-not (Test-Path $provDir)) { Write-Host "  [ERROR] Provider not found: $Provider" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $logsRoot)) { New-Item -ItemType Directory -Path $logsRoot | Out-Null }

if ($Tier -and $Tier -notmatch '^(?i)full') {
    Write-Host "  [DEPRECATED] Tiers removed 2026-07-01 -- '-Tier $Tier' ignored; testing is a single Full pass." -ForegroundColor Yellow
}

$tierFile = Join-Path $logsRoot ".test_tier"
[System.IO.File]::WriteAllText($tierFile, 'Full', (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  $Provider tier: Full (all-or-nothing; tiers removed)" -ForegroundColor Green
Write-Host "    Run: docs/${Provider}_TEST_MATRIX.txt" -ForegroundColor Gray
Write-Host "    Logs from post_test.ps1 stamp Tier: Full; block_entity enforces full-pass coverage." -ForegroundColor Gray
exit 0
