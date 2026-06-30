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

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path             = $downloads
$watcher.Filter           = 'usx_captured_batch_labeled*.json'
$watcher.NotifyFilter     = [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

while ($true) {
    $ev = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::Created, 30000)
    if ($ev.TimedOut) { continue }
    $path = Join-Path $downloads $ev.Name
    Write-Host "[WATCH] $($ev.Name) detected -- waiting for Chrome to finish..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 900   # Chrome holds the file briefly while writing
    Write-Host "[WATCH] importing..." -ForegroundColor Yellow
    if ($NoCommit) {
        & $importScript -Path $path -NoCommit
    } else {
        & $importScript -Path $path -Commit
    }
    Write-Host "[WATCH] done. Ready for next fetch.`n" -ForegroundColor Green
}
