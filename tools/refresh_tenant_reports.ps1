<#
  refresh_tenant_reports.ps1 -- REGENERATE THE DERIVED TENANT REPORTS, AND SAY WHICH ONES CANNOT BE.

  Rob, 2026-09-12: "i am looking at the reports in the privers folder and they are not updated with
  current info  please reveiw adn address."

  He was right, and the content was wrong rather than merely old: IMPORT_PLAN, TENANT_PROVENANCE,
  LEDGER_VS_REALITY and TENANT_BUNDLE_VERSIONS all still described usx-fl-fcic as carrying a CA_eSUN
  bundle and "NOT OUR BUILD" -- hours after an import had moved it to FL_FCIC v7.24 and the change
  had been proven by content hash.

  WHY IT HAPPENED, which matters more than the staleness: each report is produced by its own tool,
  written with its own -OutFile, at whatever moment someone happened to run it. Nothing owned the
  SET. A report that is regenerated only when somebody remembers is a report that will be stale
  exactly when a decision is being made from it -- and these are the documents Rob is deciding
  scope and ledger entries from.

  ⚠️ TWO CLASSES, AND CONFLATING THEM IS THE FAILURE THIS TOOL EXISTS TO PREVENT:

    DERIVABLE LOCALLY -- everything computed from _versions\tenant_exports\ + the repo. These are
      regenerated here, every time, no questions asked.

    CAPTURE-BACKED -- reports whose INPUT is a browser capture (census chunks, versions sweep,
      config pull). These are regenerated IF those capture files are still in Downloads, and only
      reported as needing an operator pull WHEN THEY ARE NOT. That is decided by looking, not by a
      hardcoded list: the first cut declared all three un-refreshable and reported them STALE while
      every input was sitting on disk. Telling the operator to go and do something he does not need
      to do is the same class of wrong as leaving a report quietly stale.

  ⚠️ IT DOES NOT TOUCH IMPORT_LEDGER.md (hand-authored) or TENANT_INVENTORY.md (a narrative Rob and
  I wrote, not a tool output). LEDGER_PATCH.md is a PROPOSAL about the ledger and is regenerated.

  Usage:
    tools\refresh_tenant_reports.ps1            # regenerate + report
    tools\refresh_tenant_reports.ps1 -CheckOnly # report staleness only, change nothing
#>
param(
    [switch]$CheckOnly,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$provDir  = Join-Path $repoRoot 'providers'
$expDir   = Join-Path $repoRoot '_versions\tenant_exports'

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

Say '===================================================================================='
Say '  REFRESH TENANT REPORTS -- regenerate what is derivable, name what is not'
Say '===================================================================================='

if (-not (Test-Path $expDir)) {
    Say ('  [FAIL] no tenant exports at {0} -- there is nothing to derive from.' -f $expDir)
    Say '         Pull them first: extension button 6b, then tools\ingest_tenant_configs.ps1'
    exit 1
}

# The freshest tenant export is the DATA CLOCK: any derived report older than it is describing a
# state that no longer exists. Measured, not assumed -- this is what made the staleness visible.
$exports = @(Get-ChildItem $expDir -Filter '*.json' -File -ErrorAction SilentlyContinue)
if ($exports.Count -eq 0) { Say '  [FAIL] no tenant configs on disk.'; exit 1 }
$dataClock = ($exports | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
Say ('  data clock: newest tenant export {0:yyyy-MM-dd HH:mm} ({1} configs on disk)' -f $dataClock, $exports.Count)
Say ''

# ---- DERIVABLE LOCALLY --------------------------------------------------------------------------
$derivable = @(
    @{ Name = 'IMPORT_PLAN.txt';           Script = 'report_import_plan.ps1';       Args = @('-OutFile', (Join-Path $provDir 'IMPORT_PLAN.txt'), '-Quiet') }
    @{ Name = 'TENANT_PROVENANCE.txt';     Script = 'audit_tenant_provenance.ps1';  Args = @('-OutFile', (Join-Path $provDir 'TENANT_PROVENANCE.txt'), '-Quiet') }
    @{ Name = 'LEDGER_PATCH.md';           Script = 'propose_ledger_patch.ps1';     Args = @('-OutFile', (Join-Path $provDir 'LEDGER_PATCH.md'), '-Quiet') }
    @{ Name = 'TENANT_GROUPS.html/.pdf';   Script = 'report_tenant_groups.ps1';     Args = @('-OutFile', (Join-Path $provDir 'TENANT_GROUPS.html'), '-PdfFile', (Join-Path $provDir 'TENANT_GROUPS.pdf'), '-Quiet') }
    @{ Name = 'NOTOURS_REUSE.txt';         Script = 'report_notours_reuse.ps1';     Args = @('-OutFile', (Join-Path $provDir 'NOTOURS_REUSE.txt'), '-Quiet') }
    @{ Name = 'LEDGER_VS_REALITY.txt';     Script = '_probes\reconcile_ledger_vs_reality.ps1';   Args = @('-OutFile', (Join-Path $provDir 'LEDGER_VS_REALITY.txt')) }
    @{ Name = 'TENANT_BUNDLE_VERSIONS.txt';Script = '_probes\audit_tenant_bundle_versions.ps1';  Args = @('-OutFile', (Join-Path $provDir 'TENANT_BUNDLE_VERSIONS.txt')) }
)

# ---- CAPTURE-BACKED: derivable ONLY while the operator's capture files still exist ---------------
#
# ⚠️ DECIDED BY MEASUREMENT, NOT BY A HARDCODED LIST. The first cut declared these three
# "needs a fresh browser pull" unconditionally and reported all three STALE -- while all of their
# input captures were sitting in Downloads and every one of them could have been regenerated on the
# spot. A tool that tells the operator to go and do something he does not need to do is the same
# class of wrong as one that stays quietly stale; both hand him a false picture of what is owed.
#
# So: if the input files are THERE, regenerate. If they are GONE, say which button produces them.
# This also states the real dependency honestly -- these reports describe a CAPTURE, so once the
# capture is deleted they cannot be rebuilt from anything in the repo.
$downloads = [System.IO.Path]::Combine($env:USERPROFILE, 'Downloads')
$captureBacked = @(
    @{ Name = 'TENANT_SCAN_REPORT.txt';    Script = 'ingest_tenant_scan.ps1';     Glob = 'usx_admin_scan_*.json'
       How = 'extension button 7 (full census)' }
    @{ Name = 'TENANT_VERSION_REPORT.txt'; Script = 'ingest_tenant_versions.ps1'; Glob = 'usx_admin_versions_*.json'
       How = 'extension button 6 (versions sweep)' }
    @{ Name = 'TENANT_CONFIG_REPORT.txt';  Script = 'ingest_tenant_configs.ps1';  Glob = 'usx_tenant_config_*.json'
       How = 'extension button 6b (pull the configs)' }
)
$browser = @()      # populated below with whatever genuinely cannot be rebuilt
foreach ($c in $captureBacked) {
    $have = @(Get-ChildItem $downloads -Filter $c.Glob -File -ErrorAction SilentlyContinue)
    if ($have.Count -gt 0) {
        $derivable += @{ Name = $c.Name; Script = $c.Script
                         Args = @('-OutFile', (Join-Path $provDir $c.Name), '-Quiet')
                         Note = ('from {0} capture file(s) on disk' -f $have.Count) }
    } else {
        $browser += @{ Name = $c.Name; How = ('{0} -- no {1} in Downloads, so it CANNOT be rebuilt from the repo' -f $c.How, $c.Glob) }
    }
}

$fails = 0
if (-not $CheckOnly) {
    Say '  ---- REGENERATING (derived from local data) ------------------------------------'
    foreach ($r in $derivable) {
        $script = Join-Path $PSScriptRoot $r.Script
        if (-not (Test-Path $script)) { Say ('  [FAIL] {0} -- generator missing: {1}' -f $r.Name, $r.Script); $fails++; continue }
        # ⚠️ NEVER verify a produced file with Test-Path -- a leftover satisfies it. Compare the
        # WRITE TIME against a mark taken before the run. This is the same guard that caught a
        # stale officer-guide PDF shipping under a green success line.
        $target = ($r.Args | Where-Object { $_ -like '*providers*' } | Select-Object -First 1)
        $before = if ($target -and (Test-Path $target)) { (Get-Item $target).LastWriteTimeUtc } else { [datetime]::MinValue }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $script @($r.Args) *> $null
        $rc = $LASTEXITCODE
        $after = if ($target -and (Test-Path $target)) { (Get-Item $target).LastWriteTimeUtc } else { [datetime]::MinValue }
        if ($after -gt $before) {
            Say ("  [ok]   {0,-28} rewritten{1}" -f $r.Name, $(if ($r.ContainsKey("Note")) { "  (" + $r.Note + ")" } else { "" }))
        } else {
            Say ('  [FAIL] {0,-28} NOT rewritten (generator exit {1}) -- a leftover file would look current' -f $r.Name, $rc)
            $fails++
        }
    }
    Say ''
}

Say '  ---- STALENESS vs the data clock -----------------------------------------------'
$stale = 0
foreach ($r in ($derivable + $browser)) {
    $nm = ($r.Name -split '/')[0]
    $p = Join-Path $provDir $nm
    if (-not (Test-Path $p)) { Say ('  [MISSING] {0,-28} has never been produced' -f $nm); $stale++; continue }
    $age = (Get-Item $p).LastWriteTime
    if ($age -lt $dataClock) {
        $how = if ($r.ContainsKey('How')) { $r.How } else { 'run this tool without -CheckOnly' }
        Say ('  [STALE]   {0,-28} {1:yyyy-MM-dd HH:mm}  -- older than the data. Refresh: {2}' -f $nm, $age, $how)
        $stale++
    } else {
        Say ('  [current] {0,-28} {1:yyyy-MM-dd HH:mm}' -f $nm, $age)
    }
}

Say ''
Say '  ---- NOT REFRESHED BY THIS TOOL, ON PURPOSE ------------------------------------'
Say '  IMPORT_LEDGER.md      hand-authored by Rob. Its rows are adjudications, not data.'
Say '                        Deltas are proposed in LEDGER_PATCH.md and applied by him.'
Say '  TENANT_INVENTORY.md   a narrative written with Rob, not a tool output.'
Say '  VERIFY_<tenant>.txt   produced per import by verify_tenant_import.ps1, not standing.'
Say ''

if ($fails -gt 0) {
    Say ('  [FAIL] {0} report(s) did not regenerate. A report that failed to rewrite still LOOKS current.' -f $fails)
    exit 1
}
if ($stale -gt 0) {
    Say ('  [WARN] {0} report(s) older than the data -- the browser-dependent ones need an operator pull.' -f $stale)
    Say '         That is reported rather than hidden: a document nobody can refresh must not look current.'
    exit 0
}
Say '  [PASS] every derived report is at least as new as the data it describes.'
exit 0
