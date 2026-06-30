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
    [switch]$Commit,
    [switch]$KeepSource   # copy (not move) the source capture when archiving
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

# Combo inference for captures that carry no combo (e.g. recovered existing dex-log entries):
# the firing combo is the one whose ENTIRE set[] appears as elements in the request XML; the
# most-specific (most set fields) wins. Lets us recover arbitrary tenant queries.
. "$toolDir\_resolve_provider_json.ps1"
$script:jsonCache = @{}
function Get-ProviderJsonCached($provider) {
    if ($script:jsonCache.ContainsKey($provider)) { return $script:jsonCache[$provider] }
    $pd = Join-Path $repoRoot "providers\$provider"
    $jp = Get-ProviderRootJson -ProvDir $pd -Provider $provider
    $o = $null; if ($jp) { try { $o = Get-Content $jp -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
    $script:jsonCache[$provider] = $o; return $o
}
function Infer-ComboFromXml($provider, $query, $xml) {
    $o = Get-ProviderJsonCached $provider; if (-not $o) { return $null }
    $qidm = $null
    foreach ($b in $o.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.handlerFunction -eq 'CommsysTransactionRequestHandler' -and $c.query -eq $query) { $qidm = $c; break }
    } if ($qidm) { break } }
    if (-not $qidm) { return $null }
    $present = @{}; foreach ($mt in [regex]::Matches($xml, '<(\w+)>')) { $present[$mt.Groups[1].Value.ToLower()] = $true }
    $best = $null; $bestScore = -1
    foreach ($c in $qidm.combinations) {
        $set = @($c.requirements.set); if (-not $set) { continue }
        $allPresent = $true; $score = 0
        foreach ($s in $set) {
            $elem = $s
            $attr = $qidm.attributes | Where-Object { $_.name -ieq $s -or (@($_.sourceField) -contains $s) } | Select-Object -First 1
            if ($attr) { $elem = $attr.name }
            if ($present.ContainsKey($elem.ToLower()) -or $present.ContainsKey($s.ToLower())) { $score++ } else { $allPresent = $false }
        }
        if ($allPresent -and $score -gt $bestScore) { $best = $c; $bestScore = $score }
    }
    if ($best) { if ($best.keyReference) { return $best.keyReference } else { return $best.keyRef } }
    return $null
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
        $combo = $r.combo
        if (-not $combo -and $r.requestXml -and $r.query) {
            $combo = Infer-ComboFromXml $r.provider $r.query $r.requestXml
            if ($combo) { Write-Host "  [infer] combo=$combo (from XML)" -ForegroundColor DarkCyan }
        }
        if (-not ($r.provider -and $entity -and $r.query -and $combo -and $r.requestXml)) {
            Write-Host "  [SKIP] record missing provider/entity/query/combo/requestXml (query=$($r.query) combo=$combo)" -ForegroundColor DarkYellow
            $skipped++; continue
        }

        # PASS when the query that actually fired (messageType in the XML) matches intent.
        $fired = $r.messageType
        $result = if ($fired -and ($fired -eq $r.query)) { 'PASS' } else { 'FAIL' }
        # Unique combo label per test kind so any-field tests don't overwrite the base combo log.
        $comboLabel = $combo
        if ($r.kind -eq 'any-field' -and $r.anyField) { $comboLabel = "${combo}_af_$($r.anyField)" }
        elseif ($r.kind -eq 'any') { $comboLabel = "${combo}_any" }
        $note = "Automated capture (txId $($r.transactionId)). kind=$($r.kind); anyField=$($r.anyField); expectedKeyRef=$($r.expectedKeyRef); firedMessageType=$fired."
        $desc = "$comboLabel (auto)"

        $ptArgs = @{
            Provider = $r.provider; Entity = $entity; Query = $r.query
            Combo = $comboLabel; Result = $result; Description = $desc
            XmlRequest = $r.requestXml; Notes = $note; NoCommit = $true
        }
        if ($r.formState) { $ptArgs['FormState'] = $r.formState }
        if ($r.tier)      { $ptArgs['Tier'] = $r.tier }

        $color = if ($result -eq 'PASS') { 'Green' } else { 'Red' }
        Write-Host "  -> $($r.provider)/$entity $($r.query) $combo => $result" -ForegroundColor $color
        & (Join-Path $toolDir 'post_test.ps1') @ptArgs | Out-Null
        if ($result -eq 'PASS') { $imported++ } else { $failed++ }
    }

    # Archive the raw capture into the repo (timestamped) for traceability; clears Downloads.
    $arch = Join-Path $repoRoot 'automation\captures'
    if (-not (Test-Path $arch)) { New-Item -ItemType Directory -Path $arch -Force | Out-Null }
    $dest = Join-Path $arch ((Get-Date -Format 'yyyy-MM-dd_HHmmss') + '_' + $file.Name)
    if ($KeepSource) { Copy-Item $file.FullName $dest -Force } else { Move-Item $file.FullName $dest -Force }
    Write-Host "  archived -> automation/captures/$(Split-Path $dest -Leaf)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Imported: $imported PASS / $failed FAIL / $skipped skipped" -ForegroundColor Cyan

if ($Commit -and ($imported + $failed) -gt 0) {
    Push-Location $repoRoot
    try {
        & git add -- providers automation/captures 2>&1 | Out-Null
        & git commit -m "Import automated USx Tenant Testing captures ($imported PASS / $failed FAIL)`n`nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>" 2>&1 | Out-Null
        & git push 2>&1 | Out-Null
        Write-Host "  Git: committed + pushed" -ForegroundColor Gray
    } catch { Write-Host "  [WARN] git step failed: $_" -ForegroundColor Yellow } finally { Pop-Location }
}
exit 0
