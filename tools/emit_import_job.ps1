<#
  emit_import_job.ps1 -- WRITE THE IMPORT JOB FILE: the reviewed artifact that authorises imports.

  Rob, 2026-09-11, after driving the first automated import by hand:
      "this is still too clunky  i want the import process to be run by a json you create  kinda of
       like a import job file.  then i runi t via the console  it updates based on what we discused
       here."

  WHAT CHANGES. Before this, the operator assembled the decision AT THE KEYBOARD -- open a tenant,
  read a panel, judge a dry run, press a red button. The decision and the execution were the same
  act, which is the shape that makes a mistake unreviewable: nothing to check BEFOREHAND and nothing
  to diff AFTERWARDS.

  Now the decision is a FILE. This tool generates it, Rob reads it, and the console command executes
  only what it says. That also makes the deploy auditable: the job records what was INTENDED and
  verify_tenant_import records what HAPPENED.

  IT PLANS ON CONTENT, NOT LABELS -- the same rule as report_import_plan and the same reason: four
  tenants carry stale DESCRIPTIONS over current CONTENT, so a label-driven job would queue no-op
  imports that each archive a test package and burn a re-test cycle. A target is queued only when a
  bundle HASH differs from the repo build.

  THREE REFUSALS, all earned earlier the same day:
    * NOT-OUR-BUILD is never queued silently. Overwriting a config we did not author is a different
      decision; -Force is required and is recorded IN the job, so the override is visible to whoever
      reads it rather than living in someone's shell history.
    * An EMPTY job FAILs rather than being written. "Nothing to do" and "the tool found nothing"
      must not look the same.
    * The job records the CURRENT bundle set per target (expectBundlesNow). The browser re-checks it
      against the live page before writing and refuses the row if the tenant changed since the job
      was cut -- this is what stops us overwriting somebody else's concurrent change.

  Usage:
    tools\emit_import_job.ps1 -DeptId 69510828830
    tools\emit_import_job.ps1 -Provider FL_FCIC
    tools\emit_import_job.ps1 -All
    tools\emit_import_job.ps1 -DeptId 69510828830 -DryRunOnly
#>
param(
    [string[]]$DeptId,
    [string]$Provider,
    [switch]$All,
    [switch]$DryRunOnly,
    [switch]$Force,
    [string]$TenantDir,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

Say '===================================================================================='
Say '  EMIT IMPORT JOB -- the reviewed artifact that authorises an import'
Say '===================================================================================='

if (-not ($DeptId -or $Provider -or $All)) {
    Say '  [FAIL] name what to import: -DeptId <id[,id]> | -Provider <NAME> | -All'
    Say '         There is no default. A job whose scope nobody chose is not a reviewed artifact.'
    exit 1
}

$tenantDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
if (-not (Test-Path $tenantDir)) {
    Say ('  [FAIL] no tenant exports at {0}' -f $tenantDir)
    Say '         Pull them first: extension button 6b, then tools\ingest_tenant_configs.ps1'
    exit 1
}

# ---- repo side: current build + per-bundle content hashes --------------------------------------
$repoVer = @{}; $repoHash = @{}
foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory)) {
    $cands = @(Get-ChildItem $d.FullName -Filter ('{0}_v*.json' -f $d.Name) -File -ErrorAction SilentlyContinue)
    if ($cands.Count -ne 1) { continue }
    $o = $null
    try { $o = Get-Content $cands[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ($cands[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$d.Name] = $Matches[1] }
    foreach ($b in (Get-BundleList $o)) { $repoHash[('{0}|{1}' -f $d.Name, $b.name)] = (Get-BundleContentHash $b) }
}
if ($repoVer.Count -eq 0) {
    Say '  [FAIL] no versioned root JSON found in providers\ -- refusing to emit a job against an empty repo.'
    exit 1
}
Say ('  repo builds indexed: {0} provider(s)' -f $repoVer.Count)

# ---- roster: subdomain + status, keyed on deptId -----------------------------------------------
$rosterPath = Join-Path $repoRoot 'tools\config\tenant_roster.json'
$status = @{}; $subOf = @{}
if (Test-Path $rosterPath) {
    $r = Get-Content $rosterPath -Raw | ConvertFrom-Json
    foreach ($t in $r.tenants) { $status[('{0}' -f $t.deptId)] = ('{0}' -f $t.status); $subOf[('{0}' -f $t.deptId)] = ('{0}' -f $t.subdomain) }
}

# ---- tenant side -------------------------------------------------------------------------------
$files = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
if ($files.Count -eq 0) {
    Say '  [FAIL] no tenant configs on disk -- an EMPTY job must not read as "nothing to do".'
    exit 1
}

$wanted = @()
if ($DeptId) { $wanted = @($DeptId | ForEach-Object { ('{0}' -f $_).Trim() } | Where-Object { $_ }) }

$targets = @(); $skipped = @()
foreach ($f in $files) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    $bl = Get-BundleList $o
    if ($bl.Count -eq 0) { continue }

    $dept = ($f.BaseName -replace '^.*_(\d+)$', '$1')
    $sub  = ($f.BaseName -replace '_\d+$', '')
    if ($wanted.Count -gt 0 -and $wanted -notcontains $dept) { continue }

    $pb = @($bl | Where-Object { ('{0}' -f $_.name) -ne 'ENTITIES' -and ('{0}' -f $_.name) -ne 'RMS' })[0]
    if (-not $pb) { $skipped += ('{0} -- no provider bundle' -f $sub); continue }
    $pn  = ('{0}' -f $pb.name)
    $lbl = Get-BundleLabelVersion $pb

    if ($Provider -and $pn -ne $Provider) { continue }

    if ((-not $lbl) -and (-not $Force)) {
        $skipped += ('{0} -- NOT-OUR-BUILD ({1} carries no version stamp); -Force to override' -f $sub, $pn)
        continue
    }
    if (-not $repoVer.ContainsKey($pn)) { $skipped += ('{0} -- no repo build for {1}' -f $sub, $pn); continue }

    $have = @($bl | ForEach-Object { '{0}' -f $_.name })
    $changed = @()
    foreach ($b in $bl) {
        $k = '{0}|{1}' -f $pn, $b.name
        if (-not $repoHash.ContainsKey($k)) { $changed += ('{0}' -f $b.name); continue }
        if ((Get-BundleContentHash $b) -ne $repoHash[$k]) { $changed += ('{0}' -f $b.name) }
    }
    # Bundles the repo build carries that the tenant does not -- an import ADDS these.
    foreach ($k in $repoHash.Keys) {
        if ($k -notlike ('{0}|*' -f $pn)) { continue }
        $bn = $k.Split('|')[1]
        if ($have -notcontains $bn) { $changed += $bn }
    }
    $changed = @($changed | Select-Object -Unique)

    if ($changed.Count -eq 0 -and (-not $Force)) {
        $skipped += ('{0} -- already CURRENT by content' -f $sub)
        continue
    }

    $st = if ($status.ContainsKey($dept)) { $status[$dept] } else { 'UNKNOWN' }
    $subdomain = if ($subOf.ContainsKey($dept)) { $subOf[$dept] } else { $sub }

    $targets += [ordered]@{
        deptId           = $dept
        subdomain        = $subdomain
        url              = 'https://{0}.mark43.com/rms/api/support/admin/departments/configurations/{1}' -f $subdomain, $dept
        provider         = $pn
        toVersion        = $repoVer[$pn]
        fromVersion      = $(if ($lbl) { $lbl.Version } else { $null })
        notOurBuild      = (-not $lbl)
        tenantStatus     = $st
        liveConfirmed    = $false
        expectBundlesNow = $have
        willChange       = $changed
        done             = $false
    }
}

if ($targets.Count -eq 0) {
    Say '  [FAIL] the job would be EMPTY -- nothing matched, or everything matched is already current.'
    foreach ($s in ($skipped | Select-Object -First 12)) { Say ('     skipped: {0}' -f $s) }
    Say '         "nothing to do" and "the tool found nothing" must not look the same, so this FAILs.'
    exit 1
}

$live   = @($targets | Where-Object { $_.tenantStatus -match 'LIVE' })
$jobId  = 'job-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$commit = (& git -C $repoRoot rev-parse --short HEAD 2>$null)

$job = [ordered]@{
    _what  = 'AN IMPORT JOB -- the reviewed artifact that authorises these imports. Generated by tools\emit_import_job.ps1; executed by __usxJob() in the tenant console.'
    _how   = @(
        'Start tools\serve_plans.ps1 -- it serves this file at GET /job.',
        'Open a target url below, open the browser console, and run:   __usxJob()',
        'It imports ONLY the target matching that page, then prints the next url.',
        'Afterwards: extension button 6b for those deptIds, then tools\ingest_tenant_configs.ps1 and tools\verify_tenant_import.ps1.'
    )
    _rules = @(
        'CONTENT, not labels: a target is here because a bundle HASH differs from the repo build, never because a description looks old.',
        'AN IMPORT REPLACES THE BUNDLE SET -- it removes any bundle the payload does not contain. Proven on usx-fl-fcic, whose CA_eSUN bundle was removed by the FL_FCIC import.',
        'expectBundlesNow is re-checked against the live page before writing; if the tenant changed since this job was cut the row is REFUSED, not overwritten.',
        'A CLICKED verdict is not proof. verify_tenant_import.ps1 is.'
    )
    jobId       = $jobId
    createdAt   = (Get-Date).ToString('o')
    repoCommit  = ('{0}' -f $commit)
    dryRunOnly  = [bool]$DryRunOnly
    forced      = [bool]$Force
    targetCount = $targets.Count
    targets     = $targets
}

$outPath = if ($OutFile) { $OutFile } else { Join-Path $repoRoot 'providers\IMPORT_JOB.json' }
$json = $job | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($outPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Say ''
Say ('  JOB {0}   {1} target(s){2}' -f $jobId, $targets.Count, $(if ($DryRunOnly) { '   [DRY RUN ONLY -- this job can never write]' } else { '' }))
Say ''
Say '  TENANT                         DEPT           FROM        -> TO          CHANGES'
Say '  ----------------------------------------------------------------------------------------'
foreach ($t in $targets) {
    Say ('  {0,-30} {1,-14} {2,-11} -> {3,-11} {4}' -f $t.subdomain, $t.deptId,
         $(if ($t.fromVersion) { 'v' + $t.fromVersion } else { 'NOT-OURS' }), ('v' + $t.toVersion), ($t.willChange -join ', '))
}
if ($live.Count -gt 0) {
    Say ''
    Say ('  [!] {0} LIVE tenant(s) in this job. Each needs liveConfirmed:true set BY HAND in the file.' -f $live.Count)
    foreach ($l in $live) { Say ('      {0} ({1})' -f $l.subdomain, $l.tenantStatus) }
}
if ($skipped.Count -gt 0) {
    Say ''
    Say ('  not queued: {0}' -f $skipped.Count)
    foreach ($s in ($skipped | Select-Object -First 10)) { Say ('     {0}' -f $s) }
    if ($skipped.Count -gt 10) { Say ('     ... and {0} more' -f ($skipped.Count - 10)) }
}
Say ''
Say ('  written: {0}' -f $outPath)
Say '  REVIEW IT, then run __usxJob() in each target page console.'
Say '===================================================================================='
