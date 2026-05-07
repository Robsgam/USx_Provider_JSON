<#
  stamp_entity_stats.ps1 -- Stamp per-entity validation stats onto card titles
  in the provider JSON so they're visible in the ConnectCIC UI during testing.

  -Inject: Runs validator, parses per-entity results, patches card titles.
           "VEHICLE SEARCH" -> "VEHICLE SEARCH - 9P/0F/0W/0L"

  -Strip:  Removes the stats suffix from all card titles.
           "VEHICLE SEARCH - 9P/0F/0W/0L" -> "VEHICLE SEARCH"

  Rebuilding from the build script also produces clean titles (no strip needed).

  Usage:
    .\stamp_entity_stats.ps1 -Path providers/CA_CLETS/CA_CLETS_BASE.json -Inject
    .\stamp_entity_stats.ps1 -Path providers/CA_CLETS/CA_CLETS_BASE.json -Strip
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [switch]$Inject,
    [switch]$Strip
)

$ErrorActionPreference = 'Stop'
$toolDir = $PSScriptRoot

if (-not $Inject -and -not $Strip) {
    Write-Host "  [FAIL] Specify -Inject or -Strip" -ForegroundColor Red
    exit 1
}

$resolved = Resolve-Path $Path
$jsonName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
$statsPattern = '\s*-\s*\d+P/\d+F/\d+W/\d+L$'

# ── STRIP MODE ──────────────────────────────────────────────────────────────
if ($Strip) {
    Write-Host ""
    Write-Host "  Stripping stats from card titles in $jsonName..." -ForegroundColor Yellow

    $raw = Get-Content $resolved -Raw
    $changed = $false

    $json = $raw | ConvertFrom-Json
    foreach ($cfg in $json.bundles[0].configurations) {
        foreach ($variantKey in @($cfg.layout.PSObject.Properties.Name)) {
            $layout = $cfg.layout.$variantKey
            foreach ($prop in $layout.PSObject.Properties) {
                $node = $prop.Value
                if ($node.type.resolvedName -eq 'Card' -and $node.props.title -and $node.props.title -match $statsPattern) {
                    $node.props.title = $node.props.title -replace $statsPattern, ''
                    $changed = $true
                }
            }
        }
    }

    if ($changed) {
        $json | ConvertTo-Json -Depth 100 -Compress | Set-Content $resolved -Encoding UTF8
        $readablePath = ($resolved -replace '\.json$', '_READABLE.json')
        $json | ConvertTo-Json -Depth 100 | Set-Content $readablePath -Encoding UTF8
        Write-Host "  [PASS] Stats stripped from card titles" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] No stats found to strip" -ForegroundColor Gray
    }
    Write-Host ""
    exit 0
}

# ── INJECT MODE ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Stamp Entity Stats: $jsonName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Step 1: Run validator ---
Write-Host ""
Write-Host "  Running validator..." -ForegroundColor Yellow
$validatorPath = Join-Path $toolDir "validate.ps1"
$validatorOut = & powershell -ExecutionPolicy Bypass -File $validatorPath -Path $resolved 2>&1 | Out-String
$lines = $validatorOut -split "`n" | ForEach-Object { $_.Trim() }

# --- Step 2: Map QIDM names to entities ---
$queryEntityMap = @{}
foreach ($line in $lines) {
    if ($line -match "QIDM\s+'([^']+)'\s+->\s+(\w+)") {
        $qidmName = $Matches[1]
        $entity   = $Matches[2]
        if (-not $queryEntityMap.ContainsKey($qidmName)) {
            $queryEntityMap[$qidmName] = $entity
        }
    }
}

# --- Step 3: Parse and tally per entity ---
$entities = @('Vehicle', 'Person', 'Firearm', 'Article', 'Boat')
$entityStats = @{}
foreach ($e in $entities) { $entityStats[$e] = @{ pass = 0; fail = 0; warn = 0; limitation = 0 } }
$globalStats = @{ pass = 0; fail = 0; warn = 0; limitation = 0 }

foreach ($line in $lines) {
    $level = $null
    if     ($line -match '^\[PASS\]')       { $level = 'pass' }
    elseif ($line -match '^\[FAIL\]')       { $level = 'fail' }
    elseif ($line -match '^\[WARN\]')       { $level = 'warn' }
    elseif ($line -match '^\[LIMITATION\]') { $level = 'limitation' }
    if (-not $level) { continue }

    $entity = $null

    if     ($line -match "QIF\s+'ENTITY_(\w+)'")               { $entity = $Matches[1] }
    elseif ($line -match "QIDM\s+'([^']+)'\s+->\s+(\w+)")      { $entity = $Matches[2] }
    elseif ($line -match "QIDM\s+'([^']+)'" -and $queryEntityMap.ContainsKey($Matches[1])) {
        $entity = $queryEntityMap[$Matches[1]]
    }
    elseif ($line -match 'RMS\s+(Person|Vehicle|Firearm|Article|Boat)\s+QIDM') { $entity = $Matches[1] }
    elseif ($line -match '^\[(PASS|FAIL|WARN|LIMITATION)\]\s+(Person|Vehicle|Firearm|Article|Boat)\s*[:\s]') { $entity = $Matches[2] }
    elseif ($line -match 'PlateType|PlateYear')                 { $entity = 'Vehicle' }

    if ($entity -and $entityStats.ContainsKey($entity)) {
        $entityStats[$entity][$level]++
    } else {
        $globalStats[$level]++
    }
}

# --- Step 4: Display summary ---
Write-Host ""
foreach ($e in $entities) {
    $s = $entityStats[$e]
    $tag = "$($s.pass)P/$($s.fail)F/$($s.warn)W/$($s.limitation)L"
    $color = if ($s.fail -gt 0) { 'Red' } elseif ($s.warn -gt 0) { 'Yellow' } else { 'Green' }
    Write-Host "  $e : $tag" -ForegroundColor $color
}
$g = $globalStats
Write-Host "  Global : $($g.pass)P/$($g.fail)F/$($g.warn)W/$($g.limitation)L" -ForegroundColor Gray

# --- Step 5: Patch card titles ---
Write-Host ""
Write-Host "  Patching card titles..." -ForegroundColor Yellow

$json = Get-Content $resolved -Raw | ConvertFrom-Json
$patchCount = 0

foreach ($cfg in $json.bundles[0].configurations) {
    $entity = $cfg.targetEntity
    if (-not $entityStats.ContainsKey($entity)) { continue }
    $s = $entityStats[$entity]
    $statsTag = "$($s.pass)P/$($s.fail)F/$($s.warn)W/$($s.limitation)L"

    foreach ($variantKey in @($cfg.layout.PSObject.Properties.Name)) {
        $layout = $cfg.layout.$variantKey
        foreach ($prop in $layout.PSObject.Properties) {
            $node = $prop.Value
            if ($node.type.resolvedName -ne 'Card') { continue }
            if ($prop.Name -eq 'CONTEXT_INFO_CARD') { continue }
            if (-not $node.props.title) { continue }

            $cleanTitle = $node.props.title -replace $statsPattern, ''
            $node.props.title = "$cleanTitle - $statsTag"
            $patchCount++
        }
    }
}

# --- Step 6: Write back ---
$json | ConvertTo-Json -Depth 100 -Compress | Set-Content $resolved -Encoding UTF8

$readablePath = ($resolved -replace '\.json$', '_READABLE.json')
$json | ConvertTo-Json -Depth 100 | Set-Content $readablePath -Encoding UTF8

Write-Host "  [PASS] Patched $patchCount card titles across $($entities.Count) entities" -ForegroundColor Green
Write-Host "  Written: $($resolved | Split-Path -Leaf)" -ForegroundColor Green
Write-Host "  Written: $($readablePath | Split-Path -Leaf)" -ForegroundColor Green
Write-Host ""
Write-Host "  To remove: rebuild from build script, or run:" -ForegroundColor Gray
Write-Host "    .\stamp_entity_stats.ps1 -Path $Path -Strip" -ForegroundColor Gray
Write-Host ""
