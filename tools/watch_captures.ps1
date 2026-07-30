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
  startup, sweep for pre-existing matches. The largest-only rule applies ONLY to cumulative
  `usx_captured_batch*` files (later fetches are supersets of earlier ones) -- keep the largest,
  discard smaller batches. Individual ULID-named popup captures are DISTINCT combos, NOT
  duplicates, so import EACH (import_captured_tests dedupes by transactionId). Empty files
  (content '[]') are skipped entirely -- a stale empty batch_labeled.json must never displace or
  dedupe-out real individual captures (this discarded good popup captures before the 2026-07-09 fix).
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
    # Picklist scope downloads route to import_picklists (tenant option dumps, not test records).
    if ($label -like 'usx_picklists_*') {
        Write-Host "[WATCH] picklist scope capture: $label" -ForegroundColor Cyan
        $summary = $null
        try {
            $out = & (Join-Path $PSScriptRoot 'import_picklists.ps1') -Path $path *>&1
            $out | ForEach-Object { Write-Host $_ }
            $summary = ($out | Where-Object { "$_" -match 'all validations|FAIL / ' } | Select-Object -Last 1)
        } catch { Write-Host "[WATCH] import_picklists errored: $_" -ForegroundColor Red }
        Remove-Item $path -Force -ErrorAction SilentlyContinue
        if (-not $summary) { $summary = 'picklists merged (no summary line)' }
        return "PICKLISTS: $summary"
    }
    Write-Host "[WATCH] importing $label..." -ForegroundColor Yellow
    # Content-based relabel pass: browser label pairing is unreliable when tests share
    # identifiers and differ only in optional fields; formState content is ground truth.
    try { & (Join-Path $PSScriptRoot 'relabel_batch.ps1') -BatchPath $path *>&1 | ForEach-Object { Write-Host $_ } } catch { Write-Host "[WATCH] relabel errored (importing as-is): $_" -ForegroundColor DarkYellow }
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
    # KEEP CLAUDE.md's tenant-test cell CURRENT AUTOMATICALLY. Importing logs changes log-truth,
    # which changes that cell -- and enforce CHECK 3j gates it. TWICE on 2026-07-30 a completed
    # sweep left the cell reading "NEVER 0/5" while log-truth said ALL-PASS, blocking enforce until
    # someone remembered to re-run the sync by hand. A step that must be remembered is a step that
    # gets skipped, so the ingest now does it (Rob: "keep these things in line... nothing stale").
    # Idempotent -- sync_provider_table only writes when a cell actually differs.
    try { & (Join-Path $PSScriptRoot 'sync_provider_table.ps1') *>&1 |
            Where-Object { $_ -match '\(updated\)' } |
            ForEach-Object { Write-Host "[WATCH] CLAUDE.md synced: $($_.Trim())" -ForegroundColor Cyan } }
    catch {
        # DO NOT reduce this to a generic "errored" line. It used to say
        # "sync_provider_table errored (non-fatal)" on EVERY ingest while the tool was in fact
        # working and correctly updating CLAUDE.md -- the child ran under this script's
        # $ErrorActionPreference='Stop' and its own terminating `exit 0` tripped the catch.
        # A warning that fires on every single run is how a REAL warning gets ignored: the same
        # failure class as an inert gate. Report the actual cause, or say nothing.
        $msg = "$($_.Exception.Message)"
        if ($msg -match 'exit|terminated') {
            Write-Host "[WATCH] CLAUDE.md sync completed (child exit signal, not an error)" -ForegroundColor DarkGray
        } else {
            Write-Host "[WATCH] sync_provider_table FAILED -- CLAUDE.md may be stale: $msg" -ForegroundColor DarkYellow
        }
    }
    Remove-Item $path -Force -ErrorAction SilentlyContinue
    return $summary
}

# Startup catch-up sweep -- see header comment. Only runs if files already exist; harmless
# (no-op) on a clean start.
$preExisting = @(Get-ChildItem -Path $downloads -Filter 'usx_*.json' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '*.unmatched*' })
# NOTE: exclude relabel's own audit sidecars ('<file>.unmatched.json') -- they still start with
# 'usx_' so they match the watch filter, and re-sweeping one re-drops it (0 new) AND spawns a
# deeper '.unmatched.unmatched.json' each pass (self-perpetuating chain, TX v4.8 run 2026-07-27).
# Picklist scope files are per-entity and ALL get imported; the largest-only rule applies
# only to accumulated capture batches.
$prePicklists = @($preExisting | Where-Object { $_.Name -like 'usx_picklists_*' })
foreach ($pl in $prePicklists) {
    Write-Host "[WATCH] startup sweep: picklist capture $($pl.Name)" -ForegroundColor Magenta
    $s = Import-CaptureFile $pl.FullName $pl.Name
    if ($Once -and $s) { Write-Host "[WATCH-ONCE] INGESTED $($pl.Name) -- $("$s".Trim())" -ForegroundColor Green; exit 0 }
}
$preExisting = @($preExisting | Where-Object { $_.Name -notlike 'usx_picklists_*' })
# Drop empty capture files (content '[]' ~= 2-4 bytes) -- a click-capture/Fetch that grabbed
# nothing. They hold no records and must NEVER displace or dedupe-out real captures (an empty
# batch_labeled.json was discarding good individual popup captures as its "duplicates").
foreach ($e in @($preExisting | Where-Object { $_.Length -le 4 })) {
    Remove-Item $e.FullName -Force -ErrorAction SilentlyContinue
    Write-Host "[WATCH] skipped empty capture: $($e.Name) ($($e.Length) bytes)" -ForegroundColor DarkYellow
}
$preExisting = @($preExisting | Where-Object { $_.Length -gt 4 })
if ($preExisting.Count -gt 0) {
    Write-Host "[WATCH] startup sweep: found $($preExisting.Count) non-empty capture file(s) in Downloads." -ForegroundColor Magenta
    # Import EVERY non-empty capture. Previously we kept only the largest usx_captured_batch*
    # file, assuming batches are CUMULATIVE re-fetches (each bulk fetch re-downloads the whole
    # accumulated set). That silently discarded real captures whenever the user grabs DISTINCT
    # per-entity / per-page batches of differing size (NJ full retest 2026-07-21: 5 distinct
    # entity batches -> 4 would have been discarded, keeping only the 11-record Vehicle set).
    # import_captured_tests dedups by transactionId, so re-importing a true cumulative superset
    # collapses harmlessly -- importing all is strictly safe and never loses a distinct batch.
    $toImport = @($preExisting)
    $sweepSummary = $null
    foreach ($f in $toImport) {
        Write-Host "[WATCH] importing: $($f.Name) ($($f.Length) bytes)" -ForegroundColor Magenta
        $s = Import-CaptureFile $f.FullName $f.Name
        if ($s) { $sweepSummary = $s }
    }
    Write-Host "[WATCH] startup sweep complete.`n" -ForegroundColor Magenta
    if ($Once -and $sweepSummary) {
        Write-Host "[WATCH-ONCE] INGESTED $($toImport.Count) file(s) -- last: $("$sweepSummary".Trim())" -ForegroundColor Green
        exit 0
    }
}

# ── MAIN LOOP -- POLLING (robust; replaced FileSystemWatcher 2026-07-27) ──────────────
# FileSystemWatcher only raises events for files created AFTER it starts, can miss fast
# create->rename drops and the extension's service-worker-bridge downloads, and never fires
# for a file that lands in the gap between a -Once exit and the next relaunch -- so a capture
# was silently skipped (NY Article miss, 2026-07-27; Rob: "set the polling time to something
# more robust or pick up the renamed files"). Polling re-scans Downloads on a fixed interval,
# so detection is timing-independent: it catches every capture the startup sweep would, and
# picks up already-downloaded / renamed files regardless of when or how they appeared.
# Imported files are archived out of Downloads by import_captured_tests, so each is handled once.
$pollSec = 3
while ($true) {
    Start-Sleep -Seconds $pollSec
    # Match the startup-sweep filters exactly: exclude relabel's '.unmatched' audit sidecars
    # (re-importing one yields 0 new + spawns a deeper .unmatched chain, TX v4.8). Oldest-first
    # so a burst of captures ingests in arrival order.
    $files = @(Get-ChildItem -Path $downloads -Filter 'usx_*.json' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.unmatched*' } | Sort-Object LastWriteTime)
    if ($files.Count -eq 0) { continue }
    # Drop empty ('[]' ~2-4 bytes) captures so a stale empty file doesn't re-trip every poll.
    foreach ($e in @($files | Where-Object { $_.Length -le 4 })) {
        Remove-Item $e.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "[WATCH] skipped empty capture: $($e.Name) ($($e.Length) bytes)" -ForegroundColor DarkYellow
    }
    foreach ($f in @($files | Where-Object { $_.Length -gt 4 })) {
        Write-Host "[WATCH] $($f.Name) detected -- waiting for Chrome to finish writing..." -ForegroundColor Yellow
        $summary = Import-CaptureFile $f.FullName $f.Name
        Write-Host "[WATCH] done. Ready for next fetch.`n" -ForegroundColor Green
        if ($Once -and $summary) {
            Write-Host "[WATCH-ONCE] INGESTED $($f.Name) -- $("$summary".Trim())" -ForegroundColor Green
            exit 0
        }
    }
}
