<#
  import_render_snapshot.ps1 -- file a downloaded render snapshot into the provider's logs.

  Consumes usx_render_<PROVIDER>_<Entity>.json (produced automatically by __usxCaptureRender,
  which __usxRunPlan calls as step 0 of every entity run) and writes it to:

      providers/<PROVIDER>/logs/_render/<Entity>_v<X.Y>.json

  Version-stamped from the provider's ACTIVE root JSON, not from the capture: the snapshot
  proves what rendered, and which build that was is a repo fact, not something the browser
  should be trusted to assert. A rebuild therefore never inherits the prior version's render
  proof -- audit_render_fidelity.ps1 looks for the current version and reports OWED otherwise.

  Routed here by watch_captures.ps1 (usx_render_* -> this script), the same way
  usx_picklists_* routes to import_picklists.ps1. Rob 2026-07-29: "we built the extension and
  watcher tools to automate this" -- so nothing here should ever need a hand-typed step.

  Archives the download out of Downloads on success so each file is handled exactly once.

  Usage:
    .\import_render_snapshot.ps1 -Path "$env:USERPROFILE\Downloads\usx_render_TX_TLETS_Vehicle.json"
#>

param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$KeepDownload
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_resolve_provider_json.ps1"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

if (-not (Test-Path $Path)) {
    Write-Host "  [FAIL] render snapshot not found: $Path" -ForegroundColor Red
    exit 1
}

$raw = Get-Content $Path -Raw
if (-not $raw -or $raw.Trim() -in @('', '[]', '{}')) {
    Write-Host "  [INFO] empty render snapshot -- ignored: $(Split-Path $Path -Leaf)" -ForegroundColor DarkGray
    exit 0
}

try { $snap = $raw | ConvertFrom-Json } catch {
    Write-Host "  [FAIL] render snapshot is not valid JSON: $Path" -ForegroundColor Red
    exit 1
}

# Provider + entity come from the payload; fall back to the filename
# (usx_render_<PROVIDER>_<Entity>.json) when the payload is missing them.
$prov = "$($snap.provider)"
$ent  = "$($snap.entity)"
if (-not $prov -or -not $ent) {
    if ((Split-Path $Path -Leaf) -match '^usx_render_(.+)_([A-Za-z]+)\.json$') {
        if (-not $prov) { $prov = $Matches[1] }
        if (-not $ent)  { $ent  = $Matches[2] }
    }
}
if (-not $prov -or -not $ent) {
    Write-Host "  [FAIL] cannot determine provider/entity for $(Split-Path $Path -Leaf)" -ForegroundColor Red
    exit 1
}

$provDir = Join-Path $repoRoot "providers\$prov"
if (-not (Test-Path $provDir)) {
    Write-Host "  [FAIL] unknown provider '$prov' (no providers\$prov) -- snapshot left in Downloads" -ForegroundColor Red
    exit 1
}

# Version from the ACTIVE root JSON (see header: repo is authority, not the browser).
$rootJson = Get-ProviderRootJson -ProvDir $provDir -Provider $prov
$version = $null
if ($rootJson -and ([IO.Path]::GetFileName($rootJson)) -match '_v([\d.]+)\.json$') { $version = $Matches[1] }
if (-not $version) {
    Write-Host "  [FAIL] cannot resolve $prov's active JSON version -- snapshot left in Downloads" -ForegroundColor Red
    exit 1
}

$destDir = Join-Path $provDir "logs\_render"
if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
$dest = Join-Path $destDir "${ent}_v${version}.json"

$fieldCount = 0
if ($snap.cards) {
    foreach ($c in $snap.cards) { foreach ($r in @($c.rows)) { $fieldCount += @($r.fields).Count } }
}

$existed = Test-Path $dest
[System.IO.File]::WriteAllText($dest, ($snap | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
$verb = if ($existed) { 'replaced' } else { 'filed' }
Write-Host "  [PASS] $prov $ent render snapshot $verb -> logs\_render\${ent}_v${version}.json ($fieldCount field(s))" -ForegroundColor Green

# Surface the label-strategy tally. The label DOM shape has never been recon'd, so this is the
# evidence that says whether the render gate can be trusted for this form -- it must not sit
# unread inside a JSON file.
if ($snap.labelStrategyTally) {
    $tally = @($snap.labelStrategyTally.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '  '
    Write-Host "         label strategies: $tally" -ForegroundColor DarkGray
    $none = $snap.labelStrategyTally.PSObject.Properties['none']
    if ($none -and [int]$none.Value -gt 0) {
        Write-Host "  [WARN] $($none.Value) field(s) resolved NO label -- the render gate cannot judge those fields; the label markup needs a look" -ForegroundColor Yellow
    }
    $susp = $snap.labelStrategyTally.PSObject.Properties['placeholder (SUSPECT)']
    if ($susp -and [int]$susp.Value -gt 0) {
        Write-Host "  [WARN] $($susp.Value) field(s) fell through to placeholder, which this platform does not render -- suspect" -ForegroundColor Yellow
    }
}

if (-not $KeepDownload) {
    $archive = Join-Path $repoRoot "automation\captures"
    if (-not (Test-Path $archive)) { New-Item -ItemType Directory -Path $archive -Force | Out-Null }
    $stamp = (Get-Item $Path).LastWriteTime.ToString('yyyyMMdd_HHmmss')
    Move-Item $Path (Join-Path $archive "$stamp`_$(Split-Path $Path -Leaf)") -Force
}

exit 0
