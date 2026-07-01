<#
  watch_captures.ps1 -- start once per test session.
  Watches Downloads for usx_captured_batch_labeled*.json dropped by __usxBulkFetch
  and auto-runs import_captured_tests.ps1 on each new file.

  Usage:
    .\tools\watch_captures.ps1            # auto-import + commit
    .\tools\watch_captures.ps1 -NoCommit  # import only, no git commit
#>
param([switch]$NoCommit)

$downloads    = [System.IO.Path]::Combine($env:USERPROFILE, 'Downloads')
$importScript = Join-Path $PSScriptRoot 'import_captured_tests.ps1'

Write-Host "[WATCH] Monitoring $downloads for usx_captured_batch_labeled*.json" -ForegroundColor Cyan
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

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path             = $downloads
$watcher.Filter           = 'usx_captured_batch_labeled*.json'
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
    if (-not (Wait-FileReady $path)) {
        Write-Host "[WATCH] $($ev.Name) never became readable (still locked or vanished) -- skipping." -ForegroundColor DarkYellow
        continue
    }
    Write-Host "[WATCH] importing..." -ForegroundColor Yellow
    try {
        if ($NoCommit) { & $importScript -Path $path -NoCommit }
        else           { & $importScript -Path $path -Commit }
    } catch {
        Write-Host "[WATCH] import errored (watcher stays up): $_" -ForegroundColor Red
    }
    # import_captured_tests.ps1 archives (moves) the file into automation/captures; this is a
    # harmless no-op if it's already gone.
    Remove-Item $path -Force -ErrorAction SilentlyContinue
    Write-Host "[WATCH] done. Ready for next fetch.`n" -ForegroundColor Green
}
