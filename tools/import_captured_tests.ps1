<#
  import_captured_tests.ps1 -- ingest browser-captured test records into post_test.ps1.

  The automation extension (automation/extension/) downloads usx_captured_*.json files,
  each an array of records:
    { provider, entity, query, combo, tier, expectedKeyRef, messageType,
      transactionId, requestXml, formState, capturedAt }

  This script feeds each record to post_test.ps1 -- which stamps JSON Version + Entity
  Fingerprint + Tier and writes the log. Result is computed: PASS when the fired query
  (messageType in the captured XML) matches the intended query, else FAIL.

  Usage:
    .\import_captured_tests.ps1                       # newest usx_captured_*.json in ~/Downloads
    .\import_captured_tests.ps1 -Path C:\path\file.json
    .\import_captured_tests.ps1 -Path C:\dir          # all usx_captured_*.json in a dir
    .\import_captured_tests.ps1 -Commit               # commit+push after importing
#>

param(
    [string]$Path,
    [switch]$Commit
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path

# query -> entity fallback (records from the driver already carry entity).
$QueryEntity = @{
    'VehicleRegistrationQuery' = 'Vehicle'; 'VehicleStolenQuery' = 'Vehicle'
    'DriverLicenseQuery' = 'Person'; 'DriverHistoryQuery' = 'Person'
    'GunQuery' = 'Firearm'; 'ArticleSingleQuery' = 'Article'; 'BoatQuery' = 'Boat'
}

# --- Resolve input files ---
if (-not $Path) { $Path = Join-Path $env:USERPROFILE 'Downloads' }
$files = @()
if (Test-Path $Path -PathType Container) {
    $files = Get-ChildItem $Path -Filter 'usx_captured_*.json' -File | Sort-Object LastWriteTime
    if (-not $files) { Write-Host "  [ERROR] No usx_captured_*.json in $Path" -ForegroundColor Red; exit 1 }
} elseif (Test-Path $Path -PathType Leaf) {
    $files = @(Get-Item $Path)
} else {
    Write-Host "  [ERROR] Path not found: $Path" -ForegroundColor Red; exit 1
}

Write-Host ""
Write-Host "  Importing captured tests from $($files.Count) file(s)" -ForegroundColor Cyan

$imported = 0; $failed = 0; $skipped = 0
foreach ($file in $files) {
    $records = @()
    try { $records = @(Get-Content $file.FullName -Raw | ConvertFrom-Json) } catch { Write-Host "  [SKIP] bad JSON: $($file.Name)" -ForegroundColor DarkYellow; $skipped++; continue }

    foreach ($r in $records) {
        $entity = $r.entity; if (-not $entity -and $r.query -and $QueryEntity.ContainsKey($r.query)) { $entity = $QueryEntity[$r.query] }
        if (-not ($r.provider -and $entity -and $r.query -and $r.combo -and $r.requestXml)) {
            Write-Host "  [SKIP] record missing provider/entity/query/combo/requestXml (combo=$($r.combo))" -ForegroundColor DarkYellow
            $skipped++; continue
        }

        # PASS when the query that actually fired (messageType in the XML) matches intent.
        $fired = $r.messageType
        $result = if ($fired -and ($fired -eq $r.query)) { 'PASS' } else { 'FAIL' }
        $note = "Automated capture (txId $($r.transactionId)). expectedKeyRef=$($r.expectedKeyRef); firedMessageType=$fired."
        $desc = "$($r.combo) (auto)"

        $ptArgs = @(
            '-Provider', $r.provider, '-Entity', $entity, '-Query', $r.query,
            '-Combo', $r.combo, '-Result', $result, '-Description', $desc,
            '-XmlRequest', $r.requestXml, '-Notes', $note, '-NoCommit'
        )
        if ($r.formState) { $ptArgs += @('-FormState', $r.formState) }
        if ($r.tier)      { $ptArgs += @('-Tier', $r.tier) }

        $color = if ($result -eq 'PASS') { 'Green' } else { 'Red' }
        Write-Host "  -> $($r.provider)/$entity $($r.query) $($r.combo) => $result" -ForegroundColor $color
        & (Join-Path $toolDir 'post_test.ps1') @ptArgs | Out-Null
        if ($result -eq 'PASS') { $imported++ } else { $failed++ }
    }
}

Write-Host ""
Write-Host "  Imported: $imported PASS / $failed FAIL / $skipped skipped" -ForegroundColor Cyan

if ($Commit -and ($imported + $failed) -gt 0) {
    Push-Location $repoRoot
    try {
        & git add -- providers 2>&1 | Out-Null
        & git commit -m "Import automated USx Tenant Testing captures ($imported PASS / $failed FAIL)`n`nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" 2>&1 | Out-Null
        & git push 2>&1 | Out-Null
        Write-Host "  Git: committed + pushed" -ForegroundColor Gray
    } catch { Write-Host "  [WARN] git step failed: $_" -ForegroundColor Yellow } finally { Pop-Location }
}
exit 0
