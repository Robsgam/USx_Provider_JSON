<#
  watch_captures.ps1 -- start once per test session.
  Watches Downloads for usx_captured_*.json (batch_labeled or ULID-named individual
  captures) and auto-runs import_captured_tests.ps1 on each new file.

  Usage:
    .\tools\watch_captures.ps1            # auto-import + commit
    .\tools\watch_captures.ps1 -NoCommit  # import only, no git commit

  STARTUP CATCH-UP: .NET's FileSystemWatcher only notifies about files created AFTER it
  starts -- it does NOT scan for files already sitting in Downloads. Live-confirmed
  (2026-07-01): a ~30min gap where a prior watcher instance was killed left 11 stale
  usx_captured_batch_labeled*.json files piled up (each __usxBulkFetch re-downloads the
  FULL accumulated capture set, and Chrome appends " (N)" rather than overwrite an existing
  same-named file) -- a freshly started watcher would never have picked any of them up. On
  startup, sweep for pre-existing matches: import only the LARGEST (byte size is a safe proxy
  for "most complete accumulated snapshot" since later fetches are supersets of earlier ones),
  discard the rest as redundant duplicates.
#>
param([switch]$NoCommit, [switch]$Once)
# -Once: exit after the first successful import. Run the watcher as a supervised background
# task: each exit notifies the supervisor (Claude console), which reports the ingest summary
# and relaunches. This is how ingestion acknowledgments surface in the console.

$downloads    = [System.IO.Path]::Combine($env:USERPROFILE, 'Downloads')
$importScript = Join-Path $PSScriptRoot 'import_captured_tests.ps1'

Write-Host "[WATCH] Monitoring $downloads for usx_captured_*.json" -ForegroundColor Cyan
Write-Host "[WATCH] Ctrl+C to stop.`n" -ForegroundColor Cyan

# Wait until a freshly-dropped file is fully written and unlocked. Chrome writes to a
# .crdownload temp then renames, and briefly holds a write lock -- a fixed sleep can race it.
# Poll until we can open it for read AND its size is stable, up to ~8s. Returns $false if it
# never settles (still locked, or vanished).
function Wait-FileReady($p) {
    for ($i = 0; $i -lt 16; $i++) {
        if (-not (Test-Path $p)) { Start-Sleep -Milliseconds 500; continue }
        try {
            $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            $len = $fs.Length; $fs.Close()
            Start-Sleep -Milliseconds 300
            if ((Test-Path $p) -and ((Get-Item $p).Length -eq $len) -and $len -gt 0) { return $true }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    return $false
}

# Import one capture file (shared by the startup sweep and the live watch loop below).
# Returns the "Imported: N PASS / N FAIL" summary line (or $null).
function Import-CaptureFile($path, $label) {
    if (-not (Wait-FileReady $path)) {
        Write-Host "[WATCH] $label never became readable (still locked or vanished) -- skipping." -ForegroundColor DarkYellow
        return $null
    }
    Write-Host "[WATCH] importing $label..." -ForegroundColor Yellow
    $summary = $null
    try {
        # *>&1 merges the information stream: import_captured_tests.ps1 reports via Write-Host,
        # which plain capture misses -- the summary was always null and -Once never exited.
        $out = if ($NoCommit) { & $importScript -Path $path -NoCommit *>&1 } else { & $importScript -Path $path -Commit *>&1 }
        $out | ForEach-Object { Write-Host $_ }
        $summary = ($out | Where-Object { "$_" -match 'Imported:' } | Select-Object -Last 1)
    } catch {
        Write-Host "[WATCH] import errored (watcher stays up): $_" -ForegroundColor Red
        return $null
    }
    # import_captured_tests.ps1 archives (moves) the file into automation/captures; this is a
    # harmless no-op if it's already gone.
    Remove-Item $path -Force -ErrorAction SilentlyContinue
    return $summary
}

# Startup catch-up sweep -- see header comment. Only runs if files already exist; harmless
# (no-op) on a clean start.
$preExisting = @(Get-ChildItem -Path $downloads -Filter 'usx_captured_*.json' -File -ErrorAction SilentlyContinue)
if ($preExisting.Count -gt 0) {
    Write-Host "[WATCH] startup sweep: found $($preExisting.Count) pre-existing capture file(s) in Downloads." -ForegroundColor Magenta
    $newest = $preExisting | Sort-Object Length -Descending | Select-Object -First 1
    Write-Host "[WATCH] importing largest/most-complete: $($newest.Name) ($($newest.Length) bytes)" -ForegroundColor Magenta
    $sweepSummary = Import-CaptureFile $newest.FullName $newest.Name
    $discard = $preExisting | Where-Object { $_.FullName -ne $newest.FullName }
    foreach ($d in $discard) {
        Remove-Item $d.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "[WATCH] discarded redundant duplicate: $($d.Name) ($($d.Length) bytes)" -ForegroundColor DarkYellow
    }
    Write-Host "[WATCH] startup sweep complete.`n" -ForegroundColor Magenta
    if ($Once -and $sweepSummary) {
        Write-Host "[WATCH-ONCE] INGESTED $($newest.Name) -- $($sweepSummary.Trim())" -ForegroundColor Green
        exit 0
    }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path             = $downloads
$watcher.Filter           = 'usx_captured_*.json'
$watcher.NotifyFilter     = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite
$watcher.EnableRaisingEvents = $true

$recent = @{}   # name -> last-handled ticks, to dedupe the Created+Renamed double-fire
while ($true) {
    $ev = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::Created -bor [System.IO.WatcherChangeTypes]::Renamed, 30000)
    if ($ev.TimedOut) { continue }
    $path = Join-Path $downloads $ev.Name

    # Dedup: Chrome fires Created then Renamed for one download; ignore a repeat within 10s.
    $now = [DateTime]::UtcNow.Ticks
    if ($recent.ContainsKey($ev.Name) -and (($now - $recent[$ev.Name]) -lt [TimeSpan]::FromSeconds(10).Ticks)) { continue }
    $recent[$ev.Name] = $now

    Write-Host "[WATCH] $($ev.Name) detected -- waiting for Chrome to finish writing..." -ForegroundColor Yellow
    $summary = Import-CaptureFile $path $ev.Name
    Write-Host "[WATCH] done. Ready for next fetch.`n" -ForegroundColor Green
    if ($Once -and $summary) {
        Write-Host "[WATCH-ONCE] INGESTED $($ev.Name) -- $($summary.Trim())" -ForegroundColor Green
        exit 0
    }
}
