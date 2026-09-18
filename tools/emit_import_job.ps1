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
  Now the decision is a FILE. This tool generates it, Rob reads it, and a PANEL BUTTON
  (DEPLOY -> RUN THE JOB FOR THIS TENANT) executes only what it says. That also makes the deploy
  auditable: the job records what was INTENDED and verify_tenant_import records what HAPPENED.

  It was a CONSOLE command for about ten minutes, and that broke a standing rule --
      Rob: "__usxJob()  i will not run commands in the console."
  The job file was the right answer to "too clunky"; shipping its runner as a function name to type
  was the wrong delivery. GUI ONLY: translate a mechanism into a control, never an instruction.

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

# ── A SUCCESSFUL IMPORT INVALIDATES THE NEXT JOB, AND NOTHING NOTICED ───────────────────────────
# `expectBundlesNow` is the pre-flight's whole assertion: "the tenant is still in the state this
# job was cut against". For a tenant whose Export JSON returns nothing, it comes from the
# hand-maintained tenant_map row -- which only moves when a human is asked for a fresh reading.
# So the record goes stale THE MOMENT AN IMPORT SUCCEEDS, and the very next job asserts a state
# that our own deploy just replaced. usx-sc-sled was refused THREE TIMES in one hour on 2026-09-18
# and the third refusal was pure self-harm: an 18:28 deploy of v1.15 returned CLICKED with
# guardsFailed [] and a read-back byte match, and the v1.16 job re-cut minutes later still
# described the 18:20 pre-import state. Rob: "still sloppy". He was right; a re-cut that cannot see
# the deploy it follows is not automation, it is a stale file with a timestamp.
#
# THE DEPLOY RECORD IS EVIDENCE, NOT INFERENCE, and that distinction is the whole reason this is
# allowed where guessing is not (see the REFUSAL below, and _whyThisRowNeededTwoCorrections in
# tenant_map.json -- I guessed that row twice and was wrong twice). The record is a timestamped
# artifact written BY the write path, naming the payload's bundles, the modal's target deptId, and
# a normalized-vs-read-back byte comparison. Combined with the measured, twice-demonstrated fact
# that AN IMPORT REPLACES THE BUNDLE SET, a CLICKED record with no failed guards tells us what the
# tenant carries now with better provenance than a hand-typed row.
# It is still NOT proof of landing -- "A CLICKED verdict is not proof", and only
# verify_tenant_import can settle that -- which is why this sets an EXPECTATION for a guard that
# re-checks the live page, and never a claim of what is installed.
#
# REFUSES to use a record that is: not CLICKED, dryRun, carrying failed guards, aimed at a
# different deptId than its filename, or OLDER than the tenant_map reading. Older matters most --
# a human reading always wins over an earlier deploy, because the reading is the live page.
function Get-LatestDeployState {
    param([string]$DeptIdArg, [datetime]$NotBefore)
    $dl = Join-Path $env:USERPROFILE 'Downloads'
    if (-not (Test-Path $dl)) { return $null }
    $files = @(Get-ChildItem $dl -Filter ("usx_deploy_{0}_*.json" -f $DeptIdArg) -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending)
    foreach ($f in $files) {
        try { $o = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
        if ("$($o.verdict)" -ne 'CLICKED') { continue }
        if ($o.dryRun) { continue }
        if (@($o.guardsFailed | Where-Object { $_ }).Count -gt 0) { continue }
        if ("$($o.modalTargetShown)" -and "$($o.modalTargetShown)" -ne "$DeptIdArg") { continue }
        $b = @($o.payloadBundles | Where-Object { $_ })
        if (-not $b.Count) { continue }
        if ($NotBefore -and $f.LastWriteTime.ToUniversalTime() -le $NotBefore) { return $null }
        return [pscustomobject]@{
            Bundles  = $b
            Provider = "$($o.payloadProvider)"
            Version  = "$($o.payloadVersion)"
            At       = $f.LastWriteTime.ToUniversalTime().ToString('s') + 'Z'
            File     = $f.Name
        }
    }
    return $null
}

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
        # THE SECOND LEGITIMATE PRE-STATE: our own previous install of this same provider. The
        # guard must not refuse an upgrade just because the recorded state predates the install it
        # is upgrading. See deploy_probe.bundlePreflight -- it takes this ONLY when the recorded
        # expectation fails and the page matches this set EXACTLY, and it prints which it took.
        acceptBundlesAlso = @($repoHash.Keys | Where-Object { $_ -like ('{0}|*' -f $pn) } |
                               ForEach-Object { $_.Split('|')[1] } | Select-Object -Unique | Sort-Object)
        willChange       = $changed
        done             = $false
    }
}

# ---- A TENANT WITH NOTHING INSTALLED IS INVISIBLE ABOVE, AND IT IS THE OBVIOUS IMPORT ----------
# The loop above walks _versions\tenant_exports -- the pulled CONFIGS -- so a tenant carrying no
# provider bundle at all has no file to iterate and cannot become a target. That is the fourth
# consumer of one root cause: tenant_map.json is read by 8 tools and written by none, so the 4
# usx-* tenants with nothing installed were missing from the pull job, from 3 reports, and from
# here. And here it bites hardest: an EMPTY tenant is the one that most obviously needs an import.
#
# Only an EXPLICIT -DeptId reaches this path. Never -All and never -Provider: sweeping empty
# tenants into a batch is how a first-ever deploy happens by accident.
#
# THE PROVIDER COMES FROM THE RECORD, NOT FROM AN INSTALL -- there is no install to read. That is
# `Resolve-TenantIntent`, the same module serve_plans' /target uses, so the job file and /target
# cannot disagree (deploy_probe refuses on exactly that disagreement).
if ($DeptId -and -not $All -and -not $Provider) {
    . "$PSScriptRoot\_tenant_intent.ps1"
    $seen = @($targets | ForEach-Object { $_.deptId })
    foreach ($id in $wanted) {
        if ($seen -contains $id) { continue }
        $onDisk = @($files | Where-Object { ($_.BaseName -replace '^.*_(\d+)$', '$1') -eq $id })
        if ($onDisk.Count -gt 0) { continue }   # it HAS a config; the loop above already judged it

        $it = Resolve-TenantIntent -DeptId $id
        if (-not $it.provider) { $skipped += ('{0} -- {1}' -f $id, $it.error); continue }
        if (-not $repoVer.ContainsKey($it.provider)) { $skipped += ('{0} -- no repo build for {1}' -f $id, $it.provider); continue }

        # !! "NO CONFIG FILE" IS NOT THE SAME AS "NO CONFIG INSTALLED", and conflating them would
        # emit a job the pre-flight guard MUST refuse. usx-sc-sled is the case: after the v1.0
        # import it carries 3 bundles (measured off the live bundle table and recorded on its
        # tenant_map row), but its Export JSON yields nothing (CLICKED-BUT-NO-JSON), so there is
        # still no config on disk to diff. Marking it expectEmpty would assert a tenant state that
        # is now FALSE -- and bundlePreflight would correctly refuse, because SC_SLED is on the
        # page. The guard would be right and the job would be wrong.
        # So: when the RECORD says bundles are installed, plan on the NAMES we measured and say
        # plainly that content comparison was unavailable. Names are weaker evidence than a hash
        # and the job admits it rather than implying a diff happened.
        $recorded = @($it.installedBundles | Where-Object { $_ })

        # !! REFUSE TO BUILD A PRE-FLIGHT EXPECTATION OUT OF A *DERIVED* RECORD.
        # The pre-flight's entire purpose is "confirm the tenant is still in the state the job was
        # cut against". If the recorded bundle list was never MEASURED -- only inferred from what we
        # believe an earlier import did -- then the job asserts a tenant state nobody has read, and
        # `bundlePreflight` will refuse against reality. That is the guard doing its job while the
        # job file is the thing at fault, which is a confusing and expensive way to fail.
        #
        # This happened TWICE on usx-sc-sled on 2026-09-16 and the second time is what earned this
        # refusal. Its Export JSON returns nothing (CLICKED-BUT-NO-JSON), so the only reading of
        # that tenant is the LIVE BUNDLE TABLE via extension button 1 -- and after each probe import
        # I updated the row by INFERENCE instead of asking for one. Rob got
        # "PRE-FLIGHT: the tenant no longer carries [ENTITY_PROBE]" and a dialog that never opened.
        # A row whose `_bundlesMeasured` note says DERIVED is not evidence. Ask for the reading.
        $measuredNote = ''
        $rowRaw = @((Get-Content (Join-Path $PSScriptRoot 'config\tenant_map.json') -Raw |
                     ConvertFrom-Json).tenants | Where-Object { "$($_.deptId)" -eq $id })
        if ($rowRaw.Count -eq 1 -and ($rowRaw[0].PSObject.Properties.Name -contains '_bundlesMeasured')) {
            $measuredNote = "$($rowRaw[0]._bundlesMeasured)"
        }
        # A DEPLOY THAT HAPPENED AFTER THE READING SUPERSEDES THE READING. The note's leading
        # timestamp is the reading's own claim of when it was taken; parse it as UTC (a bare cast
        # yields unspecified-kind and compares wrong against a local file time -- that bug once made
        # a staleness guard unable to fire at all). No parsable timestamp = no override, because
        # "newer than the reading" is unanswerable and a guess here is what caused the refusals.
        $readingAt = $null
        if ($measuredNote -match '^\s*(\d{4}-\d{2}-\d{2}T[0-9:]+Z)') {
            try {
                $readingAt = [datetime]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture,
                    ([Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal))
            } catch { $readingAt = $null }
        }
        if ($readingAt) {
            $dep = Get-LatestDeployState -DeptIdArg $id -NotBefore $readingAt
            if ($dep) {
                Say ('  [note] {0}: a deploy SUCCEEDED after the last reading -- {1} v{2} -> [{3}] at {4}. Using that as the pre-flight expectation instead of the {5} tenant_map row (an import REPLACES the bundle set). Record: {6}' -f `
                        $id, $dep.Provider, $dep.Version, ($dep.Bundles -join ', '), $dep.At, $Matches[1], $dep.File)
                $recorded     = @($dep.Bundles)
                $measuredNote = ('{0} -- from deploy record {1} (CLICKED, no guards failed), newer than the last live reading' -f $dep.At, $dep.File)
            }
        }
        if ($recorded.Count -gt 0 -and $measuredNote -match 'DERIVED') {
            $skipped += ('{0} -- installed bundles are DERIVED, not measured. A pre-flight expectation built from an inference will be refused against the real tenant. Re-read it first: open the tenant configuration page and press extension button 1, then update the tenant_map row from that capture.' -f $id)
            continue
        }

        if ($recorded.Count -gt 0) {
            $allB = @($repoHash.Keys | Where-Object { $_ -like ('{0}|*' -f $it.provider) } |
                      ForEach-Object { $_.Split('|')[1] } | Select-Object -Unique)
            $st2 = if ($status.ContainsKey($id)) { $status[$id] } else { "$($it.status)" }
            $sd2 = if ($subOf.ContainsKey($id))  { $subOf[$id]  } else { "$($it.subdomain)" }
            $targets += [ordered]@{
                deptId           = $id
                subdomain        = $sd2
                url              = 'https://{0}.mark43.com/rms/api/support/admin/departments/configurations/{1}' -f $sd2, $id
                provider         = $it.provider
                providerSource   = $it.source
                toVersion        = $repoVer[$it.provider]
                fromVersion      = $null
                fromVersionWhy   = 'UNKNOWN -- the tenant Export JSON returns no config for this tenant, so no version string or content hash could be read. The installed bundle NAMES below come from the live bundle table (tenant_map row), not from an export.'
                notOurBuild      = $false
                tenantStatus     = $st2
                liveConfirmed    = $false
                expectBundlesNow = $recorded
                # See the note on the other target shape: re-importing over our own prior install
                # is the normal upgrade path and must not read as an unexpected tenant change.
                acceptBundlesAlso = @($allB | Sort-Object)
                expectEmpty      = $false
                contentCompared  = $false
                willChange       = $allB
                done             = $false
            }
            Say ('  [note] {0} ({1}) has NO exported config but the record shows [{2}] installed -- planning on NAMES, content NOT compared' -f $sd2, $id, ($recorded -join ', '))
            continue
        }

        # Everything the repo build carries is NEW here, because the tenant carries nothing.
        $allBundles = @($repoHash.Keys | Where-Object { $_ -like ('{0}|*' -f $it.provider) } |
                        ForEach-Object { $_.Split('|')[1] } | Select-Object -Unique)
        $st = if ($status.ContainsKey($id)) { $status[$id] } else { "$($it.status)" }
        $sd = if ($subOf.ContainsKey($id))  { $subOf[$id]  } else { "$($it.subdomain)" }

        $targets += [ordered]@{
            deptId           = $id
            subdomain        = $sd
            url              = 'https://{0}.mark43.com/rms/api/support/admin/departments/configurations/{1}' -f $sd, $id
            provider         = $it.provider
            providerSource   = $it.source          # 'usx-subdomain' or 'explicit-map' -- never an install
            toVersion        = $repoVer[$it.provider]
            fromVersion      = $null
            notOurBuild      = $false              # nothing is installed, so nothing foreign is installed
            tenantStatus     = $st
            liveConfirmed    = $false
            expectBundlesNow = @()
            # ⚠️ expectBundlesNow=[] MAKES THE PRE-FLIGHT VACUOUS ON ITS OWN. bundlePreflight
            # collects `table td, table th`, so an empty tenant still yields HEADER cells: the
            # not-loaded check passes, the missing-bundle check compares an empty list to an empty
            # list, and the guard returns OK while asserting NOTHING. These two fields convert that
            # into a real assertion -- the page must contain none of our provider names.
            expectEmpty          = $true
            expectNoBundlesNamed = @($repoVer.Keys | Sort-Object)
            emptyTenant      = $true
            # EVERY bundle of the repo build is new here. This was COMPUTED and then never assigned
            # in the first cut, so the job told the operator "changes:" and listed nothing -- on the
            # one import where the answer is "all of them".
            willChange       = $allBundles
            done             = $false
        }
        Say ('  [note] {0} ({1}) carries NO config -- target built from the RECORD ({2} via {3}), every bundle is new' -f $sd, $id, $it.provider, $it.source)
    }
}

if ($targets.Count -eq 0) {
    Say '  [FAIL] the job would be EMPTY -- nothing matched, or everything matched is already current.'
    foreach ($s in ($skipped | Select-Object -First 12)) { Say ('     skipped: {0}' -f $s) }
    # !! NAME THE ONE CAUSE THE MESSAGE ABOVE ACTIVELY MISDESCRIBES.
    # The empty-tenant path is deliberately gated on `-DeptId AND NOT -All AND NOT -Provider`
    # (sweeping configless tenants into a batch is how a first-ever deploy happens by accident).
    # So `-DeptId <id> -Provider <NAME>` for a tenant with no config on disk DISABLES that branch
    # and lands here -- and "nothing matched, or everything matched is already current" is then
    # false in both halves: something matched, and it is not current. Cost 2026-09-16: a cut of the
    # SC_SLED v1.7 job read as "already current" on a tenant three versions behind. The guard is
    # right; only the diagnosis was missing. ENGINEERING_STANDARD 4.3 is about telling "found
    # nothing" from "never looked" -- this is the third case, "was not allowed to look".
    if ($wanted.Count -gt 0 -and ($Provider -or $All)) {
        $noCfg = @($wanted | Where-Object { $id2 = $_
            @($files | Where-Object { ($_.BaseName -replace '^.*_(\d+)$', '$1') -eq $id2 }).Count -eq 0 })
        if ($noCfg.Count -gt 0) {
            Say ('         CAUSE: {0} has no config on disk, and the configless-tenant path is DISABLED by -Provider/-All' -f ($noCfg -join ', '))
            Say '         Re-run with -DeptId ALONE. The provider then comes from the record (Resolve-TenantIntent),'
            Say '         which is the same authority serve_plans /target uses -- so the job and /target cannot disagree.'
        }
    }
    Say '         "nothing to do" and "the tool found nothing" must not look the same, so this FAILs.'
    exit 1
}

$live   = @($targets | Where-Object { $_.tenantStatus -match 'LIVE' })
$jobId  = 'job-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$commit = (& git -C $repoRoot rev-parse --short HEAD 2>$null)

$job = [ordered]@{
    _what  = 'AN IMPORT JOB -- the reviewed artifact that authorises these imports. Generated by tools\emit_import_job.ps1; executed from the DEPLOY section of the USx panel (button: RUN THE JOB FOR THIS TENANT).'
    _how   = @(
        'Start tools\serve_plans.ps1 -- it serves this file at GET /job.',
        'Open a target url below. In the USx panel, DEPLOY section, press RUN THE JOB FOR THIS TENANT.',
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
         # "NOT-OURS" means a FOREIGN build is installed. Two other states exist and both were
         # mislabelled as foreign until 2026-09-16: nothing installed at all, and OURS-but-unreadable
         # (the tenant's Export JSON returns no config, so no version string can be read).
         $(if ($t.fromVersion) { 'v' + $t.fromVersion }
           elseif ($t.emptyTenant) { '(nothing)' }
           # $t is an [ordered] hashtable (OrderedDictionary), NOT a PSCustomObject -- use
           # .Contains(), because .PSObject.Properties.Name lists the DICTIONARY's own members
           # (Keys, Count, ...) and never the job fields, so the test silently never matched.
           elseif ($t.Contains('contentCompared') -and -not $t['contentCompared']) { '(unreadable)' }
           else { 'NOT-OURS' }),
         ('v' + $t.toVersion), ($t.willChange -join ', '))
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
Say '  REVIEW IT, then open each target url and press RUN THE JOB FOR THIS TENANT in the USx panel.'
Say '===================================================================================='
