<#
  backfill_log_stamps.ps1 -- one-time migration: stamp pre-existing test logs with
  the provenance header (JSON Version + Entity Fingerprint + Tier) that post_test.ps1
  now writes automatically.

  WHY: the provenance gate (audit_test_coverage.ps1 -Gate) only counts a log as
  backing a [CONFIRMED] combo when the log is STAMPED with the current build version
  and the entity's current fingerprint. Logs written before stamping existed are
  unstamped and therefore invalid -- which is correct for STALE logs, but it also
  flags logs that were genuinely run against the CURRENT shipped JSON (FL_FCIC v7.1,
  CA_CLETS v2.11). This tool stamps those genuine logs so the gate recognises them.

  SAFETY / OPERATOR RESPONSIBILITY:
    * Run this ONLY for a provider whose existing logs were really run against the
      CURRENTLY shipped JSON. Do NOT run it for a provider whose logs predate a
      rebuild (e.g. NJ_NJCJIS, whose 2026-06-25 logs predate v4.7) -- those must be
      re-tested, not blessed. The tool cannot tell a genuine log from a stale one;
      that judgement is yours, which is why it is per-provider and dry-run by default.
    * It stamps the CURRENT build version + each entity's CURRENT fingerprint.
    * It NEVER overwrites an existing stamp (idempotent) and skips logs whose entity
      no longer exists in the JSON.

  Usage:
    .\backfill_log_stamps.ps1 -Provider FL_FCIC               # DRY RUN (default): report only
    .\backfill_log_stamps.ps1 -Provider FL_FCIC -Apply        # write the stamps
    .\backfill_log_stamps.ps1 -Provider CA_CLETS -Apply -Tier Final
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [string]$Tier,   # tiers removed 2026-07-01; defaults to 'Full' via Get-ActiveTier
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
# Archived 2026-07-06 (past its one-time-migration window); moved from tools/ to
# tools/_archive/, one directory deeper -- toolDir below points at the real tools/
# so the dot-sourced shared modules and repoRoot resolution still work unchanged.
$toolDir  = (Resolve-Path "$PSScriptRoot\..").Path
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$testsDir = Join-Path $provDir "tests"
$logsRoot = Join-Path $provDir "logs"

. "$toolDir\_resolve_provider_json.ps1"
. "$toolDir\get_entity_fingerprints.ps1"
. "$toolDir\_test_provenance.ps1"

if (-not (Test-Path $provDir)) { Write-Host "  [ERROR] Provider not found: $Provider" -ForegroundColor Red; exit 1 }

# Current standard (2026-07-01): providers/<PROVIDER>/logs/<Entity>/*.txt -- entity is the
# folder name, no filename parsing needed. Legacy fallback: flat providers/<PROVIDER>/tests/*.txt
# (entity parsed from the filename prefix).
$entityLogDirs = @()
if (Test-Path $logsRoot) {
    $entityLogDirs = @(Get-ChildItem $logsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '_archive_pre_v*' })
}
$usingNewLogStructure = $entityLogDirs.Count -gt 0
if (-not $usingNewLogStructure -and -not (Test-Path $testsDir)) {
    Write-Host "  [ERROR] No logs/<Entity>/ dirs and no tests/ dir for $Provider" -ForegroundColor Red; exit 1
}

$buildVer = Get-BuildVersionForProvider $provDir
if (-not $buildVer) { Write-Host "  [ERROR] Could not resolve build version for $Provider" -ForegroundColor Red; exit 1 }
if (-not $Tier) { $Tier = Get-ActiveTier $provDir }

$activeJson = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $activeJson) { Write-Host "  [ERROR] No active JSON for $Provider" -ForegroundColor Red; exit 1 }
$fp = Get-EntityFingerprints -Path $activeJson
$entities = @($fp.Keys | Sort-Object { -$_.Length })   # longest-first so 'Vehicle' matches before any prefix

if ($usingNewLogStructure) {
    $logs = @()
    foreach ($ed in $entityLogDirs) {
        foreach ($f in (Get-ChildItem $ed.FullName -Filter "*.txt" -File -ErrorAction SilentlyContinue)) {
            $logs += [PSCustomObject]@{ FullName = $f.FullName; Name = $f.Name; Entity = $ed.Name }
        }
    }
    Write-Host ""
    Write-Host "  Backfill stamps: $Provider  (build v$buildVer, tier $Tier)  [$(if ($Apply){'APPLY'}else{'DRY RUN'})]" -ForegroundColor Cyan
    Write-Host "  $($logs.Count) log(s) in logs/<Entity>/" -ForegroundColor Gray
} else {
    $logs = @(Get-ChildItem $testsDir -Filter "*.txt" -File -ErrorAction SilentlyContinue)
    Write-Host ""
    Write-Host "  Backfill stamps: $Provider  (build v$buildVer, tier $Tier)  [$(if ($Apply){'APPLY'}else{'DRY RUN'})]" -ForegroundColor Cyan
    Write-Host "  $($logs.Count) log(s) in tests/" -ForegroundColor Gray
}

$stamped = 0; $already = 0; $skipped = 0
foreach ($log in $logs) {
    $name = $log.Name
    if ($usingNewLogStructure) {
        $ent = $log.Entity
    } else {
        # Resolve entity from filename: strip the provider prefix, take the leading entity token.
        $rest = $name -replace "^$([regex]::Escape($Provider))_", ''
        $ent = $null
        foreach ($e in $entities) { if ($rest -match "^$([regex]::Escape($e))(_|$)") { $ent = $e; break } }
    }
    if (-not $ent) { Write-Host "    SKIP (no entity match): $name" -ForegroundColor DarkGray; $skipped++; continue }

    $existing = Get-LogStamp $log.FullName
    if ($existing.Version) { $already++; continue }   # idempotent: already stamped

    $entFp = $fp[$ent]
    $stamp = "JSON Version: $buildVer`nEntity Fingerprint: $entFp`nTier: $Tier"

    if ($Apply) {
        $text = [System.IO.File]::ReadAllText($log.FullName)
        # Insert the stamp lines right after the header "Result: ..." line.
        $newText = [regex]::Replace($text, '(?m)^(Result:.*)$', "`$1`n$stamp", 1)
        if ($newText -eq $text) {
            # No header "Result:" line -- prepend stamp at top as a fallback.
            $newText = "$stamp`n$text"
        }
        [System.IO.File]::WriteAllText($log.FullName, $newText, (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Host "    STAMP $ent v$buildVer  $name" -ForegroundColor Green
    $stamped++
}

Write-Host ""
Write-Host "  Result: $stamped to stamp, $already already stamped, $skipped skipped" -ForegroundColor Cyan
if (-not $Apply -and $stamped -gt 0) {
    Write-Host "  DRY RUN -- re-run with -Apply to write the stamps." -ForegroundColor Yellow
}
exit 0
