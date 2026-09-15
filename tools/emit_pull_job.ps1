<#
  emit_pull_job.ps1 -- WRITE THE PULL JOB FILE: which tenants to re-export, and WHY each one.

  Rob, 2026-09-15, after pasting a 68-id list into the panel by hand:
      "in an earlier session i asked you to create the job files in json form so i would not have to
       do all this manual stuff i would simply point the extension to the job file  can we
       incorpoartae that and begin to clean up and rename these buttons   i watn somthing m ore
       usable"

  THIS IS THE READ-SIDE TWIN OF emit_import_job.ps1, and deliberately the same shape: a tool writes
  a reviewable FILE, serve_plans serves it, and ONE panel button executes only what it says. The
  write side proved the pattern (IMPORT_JOB.json -> GET /job -> RUN THE JOB FOR THIS TENANT); this
  removes the last hand-assembly step on the read side.

  WHAT IT REPLACES. The dept-id list was being computed AT THE KEYBOARD every time -- join the
  config inventory against the roster, add the never-pulled tenants, drop the deactivated ones,
  paste 800 characters into a textarea and hope it did not truncate. That is three joins and a
  transcription, and the transcription is the part that silently loses a tenant.

  THE REASON FIELD IS THE POINT, not decoration. A pull of 65 tenants answers three different
  questions at once and they have OPPOSITE success conditions:
    * 'baseline'     -- we hold a config for this tenant. UNCHANGED is the good outcome (no drift).
    * 'never-pulled' -- we have no config at all. ANY content is new information.
    * 'new-tenant'   -- appeared since the last roster baseline. May carry nothing of ours.
  Without the reason, "64 unchanged, 1 new file" reads as a partial failure instead of as exactly
  the expected result.

  ==== THREE TRAPS, ALL OF WHICH SHIPPED BEFORE BEING MEASURED ====

  (1) SCOPING THE DEFAULT SET TO THE CONFIG INVENTORY OMITS THE ONE TENANT YOU MOST WANT.
      The inventory is what we have ALREADY PULLED, so a tenant that has never been pulled is by
      definition absent from it -- and 'never pulled' is exactly the interesting case.
      dallastx-foundation (67985044065, imported by hand 2026-09-14) was missing from the first
      draft's default job for precisely this reason. The authority for "tenants we care about" is
      tools\config\tenant_map.json (the canonical subdomain <-> deptId <-> ledger join), NOT the
      inventory. Default set = tenant_map UNION inventory.

  (2) `firstSeen` CANNOT DETECT A NEW TENANT, and driving off it returns either everything or
      nothing. The roster was bootstrapped on 2026-09-11, so all 1,785 rows carry the SAME
      firstSeen; and if the baseline is -Update'd before the job is cut (the normal order), a
      firstSeen > capturedAt test matches zero rows. There is no reliable date signal available
      yet. So new tenants are passed in EXPLICITLY via -Include, which is what
      ingest_tenant_roster.ps1 already prints a ready-to-paste list for. An automatic detector that
      silently returns nothing is worse than an explicit parameter.

  (3) tenant_map.json IS NOT MAINTAINED BY ANY TOOL, so it cannot be the sole definition of "ours".
      Eight tools read it; ZERO write it. Its own `generated` field says 2026-09-10 and its source
      was the full census -- which enumerated tenants that HAD A PROVIDER BUNDLE. A provider tenant
      with NOTHING INSTALLED was therefore never in it, and that hid FOUR of our twenty usx-*
      tenants from every job this tool cut (usx-sc-sled, usx-ca-contra-costa,
      usx-ca-san-louis-obispo, usx-ca-ventura-county). An EMPTY provider tenant is the most
      important kind to notice: it means nothing is deployed there. Fixed by ALSO deriving the fleet
      from the roster by SUBDOMAIN -- a `usx-*` subdomain is ours by construction, the same authority
      serve_plans' /target already uses -- so a new provider tenant is in scope the moment it
      appears in the roster, with no file to hand-maintain.

  FIVE REFUSALS, each one earned:
    * AN EMPTY JOB FAILS rather than being written. ENGINEERING_STANDARD 4.3 -- "found nothing" and
      "never looked" must not print the same line, and a 0-tenant job the panel happily accepts is
      the vacuous pass in artifact form.
    * A MISSING ROSTER FAILS LOUDLY. Without it there is no status field, so 'active' would
      degrade to 'everything we happen to have', the opposite of what was asked for.
    * DEACTIVATED TENANTS ARE EXCLUDED WITH A RECORDED REASON, never dropped quietly. They appear
      in 'skipped' so the denominator is auditable.
    * tenant_scope.json EXCLUSIONS ARE HONOURED via the shared _tenant_scope.ps1 module -- NOT
      re-implemented here. A filtered report that does not say what it filtered is how a finding
      disappears (that module's own header).
    * A STALE ROSTER IS RECORDED, NOT SILENTLY USED. rosterCapturedAt + rosterAgeDays ride in the
      job so the panel can say "refresh the list first" rather than pulling a list that cannot
      contain a tenant created yesterday. Hiding the refresh control is what makes this necessary.

  IT DOES NOT DECIDE WHAT IS INSTALLED. This job says only which tenants to EXPORT. What each one
  carries is answered afterwards by ingest_tenant_configs.ps1 (content hash) and
  audit_tenant_provenance.ps1 (which historical build that hash is). Keeping those separate is why
  a pull can be re-run safely: it asserts nothing.

  Usage:
    tools\emit_pull_job.ps1                                    # our tenants: baseline + never-pulled
    tools\emit_pull_job.ps1 -Include 73174645235,73059802433   # plus new ones from the roster diff
    tools\emit_pull_job.ps1 -DeptId 67985044065                # just these
    tools\emit_pull_job.ps1 -BaselineOnly                      # pure drift check
    tools\emit_pull_job.ps1 -MaxAgeDays 3                      # FAIL if the roster is older
#>
param(
    [string[]]$DeptId,
    [string[]]$Include,
    [switch]$BaselineOnly,
    [int]$MaxAgeDays = 0,
    [string]$RosterPath,
    [string]$OutFile,
    [switch]$Quiet
)

# ?? PLAIN ARRAYS, NOT System.Collections.Generic.List[object] -- MEASURED 2026-09-15.
# `@($list)` on a List[object] throws `ArgumentException: Argument types do not match` on this
# engine, and it throws for an EMPTY list too, so the loop body never runs. The first draft used
# Lists, and the resulting crash inside Split-TenantsByScope exited 1 while writing no file --
# which is indistinguishable from the refusal guards working correctly. That is the exact shape
# LAW 2 warns about: a crash impersonating a gate. Arrays here are also idiomatic for the repo
# and the sets are <100 rows, so += costs nothing.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_tenant_scope.ps1"

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }
function Fail([string]$s) { Write-Host "  [FAIL] $s" -ForegroundColor Red; exit 1 }

# Accept 'a,b c' in any arg position -- powershell -File stringifies array args (usx-tooling 4).
function Split-Ids($vals) {
    $out = @()
    foreach ($v in @($vals)) { foreach ($one in ("$v" -split '[,\s]+')) { if ($one -match '^\d+$') { $out += $one } } }
    return ,$out
}

if ($RosterPath) { $rosterPath = $RosterPath } else { $rosterPath = Join-Path $PSScriptRoot 'config\tenant_roster.json' }
$mapPath    = Join-Path $PSScriptRoot 'config\tenant_map.json'
$invPath    = Join-Path $repoRoot 'providers\TENANT_CONFIG_INVENTORY.json'
$jobPath    = if ($OutFile) { $OutFile } else { Join-Path $repoRoot 'providers\PULL_JOB.json' }

Say ''
Say '===================================================================================='
Say '  EMIT PULL JOB -- which tenants to re-export, and why each one'
Say '===================================================================================='

# -- the roster is the ONLY authority for status; without it 'active' is meaningless ----
if (-not (Test-Path $rosterPath)) {
    Fail "no tools\config\tenant_roster.json -- refresh the tenant list and run ingest_tenant_roster.ps1 -Update first"
}
$roster = Get-Content $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rosterRows = @($roster.tenants)
if ($rosterRows.Count -eq 0) { Fail 'tenant_roster.json parsed but holds 0 tenants -- refusing to cut a job from an empty roster' }

$byId = @{}
foreach ($t in $rosterRows) { $byId["$($t.deptId)"] = $t }

# ?? PARSE AS UTC AND COMPARE IN UTC. capturedAt carries a 'Z' (the browser writes an ISO UTC
# stamp), but a bare [datetime] cast yields an unspecified-kind value that then gets compared
# against LOCAL Get-Date -- so on an EDT machine a roster captured minutes ago reads as
# "-0.1 days old". That is not cosmetic: a negative or understated age means -MaxAgeDays can
# NEVER fire, i.e. a guard that cannot fail (LAW 2). Measured on the first real run.
$capturedAt = $null
try {
    $capturedAt = [datetime]::Parse($roster.capturedAt, [System.Globalization.CultureInfo]::InvariantCulture,
        ([System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal))
} catch { }
$ageDays = $null
if ($capturedAt) { $ageDays = [math]::Round(([datetime]::UtcNow - $capturedAt).TotalDays, 1) }

$capStr = 'UNKNOWN'
if ($capturedAt) { $capStr = $capturedAt.ToString('yyyy-MM-dd HH:mm') + 'Z' }
$ageStr = ''
if ($null -ne $ageDays) { $ageStr = " ($ageDays days old)" }
Say ("  roster     : {0} tenants, captured {1}{2}" -f $rosterRows.Count, $capStr, $ageStr)

if ($MaxAgeDays -gt 0 -and $null -ne $ageDays -and $ageDays -gt $MaxAgeDays) {
    Fail ("roster baseline is {0} days old (-MaxAgeDays {1}) -- refresh the tenant list first, or a tenant created since cannot be in the job" -f $ageDays, $MaxAgeDays)
}

# -- what we already hold a config for (the drift-check set) ---------------------------
$haveIds = @()
if (Test-Path $invPath) {
    $inv = Get-Content $invPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $haveIds = @($inv.PSObject.Properties | ForEach-Object { $_.Value } |
                 Where-Object { $_.deptId } | ForEach-Object { "$($_.deptId)" })
}
Say ("  inventory  : {0} tenant(s) with a config already on disk" -f $haveIds.Count)

# -- OUR tenants. See trap (1): the inventory cannot answer this. --
# TWO SOURCES, and the second exists because the first CANNOT be complete.
#
# ?? TRAP (3), MEASURED 2026-09-15: tenant_map.json IS NOT MAINTAINED BY ANY TOOL. Eight tools read
# it; zero write it. It was produced once (its own `generated` field says 2026-09-10, source
# "extension full census") from tenants that HAD A PROVIDER BUNDLE -- so a provider tenant with
# NOTHING INSTALLED was never in it. That silently hid FOUR of our own twenty usx-* tenants
# (usx-sc-sled, usx-ca-contra-costa, usx-ca-san-louis-obispo, usx-ca-ventura-county) from every job
# this tool cut, and an EMPTY provider tenant is the most important kind to notice: it means nothing
# is deployed there. Relying on a hand-built file to enumerate our own fleet is the defect.
#
# So the fleet is ALSO derived from the roster by SUBDOMAIN. A `usx-*` subdomain is ours BY
# CONSTRUCTION -- the same reasoning serve_plans' /target/<deptId> already uses, where
# `usx-subdomain` is an authority source ranked beside the explicit map. This cannot rot: a new
# provider tenant is in scope the moment it appears in the roster.
$ourIds = @()
if (Test-Path $mapPath) {
    $map = Get-Content $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $ourIds = @(@($map.tenants) | Where-Object { $_.deptId } | ForEach-Object { "$($_.deptId)" })
}
Say ("  tenant_map : {0} tenant(s) recorded (NOT tool-maintained -- see trap 3)" -f $ourIds.Count)

$fleetIds = @($rosterRows | Where-Object { "$($_.subdomain)" -like 'usx-*' } | ForEach-Object { "$($_.deptId)" })
$fleetNew = @($fleetIds | Where-Object { $ourIds -notcontains $_ })
Say ("  usx-* fleet: {0} tenant(s) by subdomain ({1} of them absent from tenant_map)" -f $fleetIds.Count, $fleetNew.Count)
foreach ($id in $fleetNew) {
    $t2 = $byId[$id]
    Say ("     + {0} ({1}) -- ours by subdomain, missing from the map" -f $(if ($t2) { "$($t2.subdomain)" } else { '?' }), $id)
}
$ourIds = @($ourIds + $fleetIds | Select-Object -Unique)

# -- assemble candidates, each carrying its reason -------------------------------------
$script:cand = @()
$seen = @{}
function Add-Cand([string]$id, [string]$why) {
    if ($seen.ContainsKey($id)) { return }
    $seen[$id] = $true
    $t = $byId[$id]
    $sub = '(not in roster)'; $st = 'NOT-IN-ROSTER'
    if ($t) { $sub = "$($t.subdomain)"; $st = "$($t.status)" }
    $script:cand += [pscustomobject]@{ deptId = $id; subdomain = $sub; status = $st; why = $why }
}
function Reason-For([string]$id) {
    if ($haveIds -contains $id) { return 'baseline' }
    return 'never-pulled'
}

$explicit = Split-Ids $DeptId
if ($explicit.Count -gt 0) {
    foreach ($id in $explicit) { Add-Cand $id (Reason-For $id) }
}
else {
    foreach ($id in $haveIds) { Add-Cand $id 'baseline' }
    if (-not $BaselineOnly) {
        foreach ($id in $ourIds) { Add-Cand $id (Reason-For $id) }
    }
}
foreach ($id in (Split-Ids $Include)) { Add-Cand $id 'new-tenant' }

$cand = $script:cand
if (@($cand).Count -eq 0) { Fail 'no candidate tenants -- nothing to pull. Refusing to write an empty job (ENGINEERING_STANDARD 4.3)' }

# -- refusals: absent from roster, deactivated, out of scope ---------------------------
$skipped = @()
$keep    = @()
foreach ($c in $cand) {
    if ($c.status -eq 'NOT-IN-ROSTER') {
        $skipped += [pscustomobject]@{ deptId=$c.deptId; subdomain=$c.subdomain; reason='not present in the roster baseline -- refresh the tenant list' }; continue
    }
    if ($c.status -match 'DEACTIVATED') {
        $skipped += [pscustomobject]@{ deptId=$c.deptId; subdomain=$c.subdomain; reason='DEACTIVATED on the platform' }; continue
    }
    $keep += $c
}

# tenant_scope.json exclusions -- via the SHARED module, never re-implemented here.
# ?? Excluded rows are WRAPPERS: @{ Row = <the row>; Exclusion = <the scope entry> }. Reading
# $e.deptId directly yields $null and prints a blank subdomain -- the first draft did exactly that.
$split = Split-TenantsByScope $keep 'deptId'
foreach ($e in @($split.Excluded)) {
    $why = 'no reason recorded'
    if ($e.Exclusion -and $e.Exclusion.reason) { $why = "$($e.Exclusion.reason)" }
    $skipped += [pscustomobject]@{
        deptId    = "$($e.Row.deptId)"
        subdomain = "$($e.Row.subdomain)"
        reason    = ('tenant_scope.json exclusion: ' + $why)
    }
}
$final = @($split.InScope)

if ($final.Count -eq 0) { Fail ("every candidate was excluded ({0} skipped) -- refusing to write a 0-tenant job" -f @($skipped).Count) }

# -- write ----------------------------------------------------------------------------
$repoCommit = ''
try { $repoCommit = "$(& git -C $repoRoot rev-parse --short HEAD 2>$null)".Trim() } catch { }

$byWhy = [ordered]@{}
foreach ($f in ($final | Sort-Object why)) {
    if (-not $byWhy.Contains($f.why)) { $byWhy[$f.why] = 0 }
    $byWhy[$f.why] = $byWhy[$f.why] + 1
}

$rosterCap = $null
if ($capturedAt) { $rosterCap = $capturedAt.ToString('o') }

$job = [ordered]@{
    '_what'  = 'A PULL JOB -- which tenant configurations to re-export, and WHY each one. Generated by tools\emit_pull_job.ps1; executed from the USx panel (button: RUN THE JOB). Read-only: it clicks Export JSON, never Import.'
    '_how'   = @(
        'Start tools\serve_plans.ps1 -- it serves this file at GET /pulljob.',
        'Open any admin configurations page. In the USx panel, press RUN THE JOB.',
        'Afterwards: tools\ingest_tenant_configs.ps1 (content hash), then tools\audit_tenant_provenance.ps1 to identify which build each bundle is.'
    )
    '_rules' = @(
        "The 'why' field sets the success condition: baseline UNCHANGED is the good outcome; never-pulled and new-tenant are EXPECTED to produce new content.",
        'READ-ONLY. This job authorises exports only. An import is a different job file (IMPORT_JOB.json) and a different button.',
        'A 0-tenant job is never written -- "nothing to do" and "the tool found nothing" must not look the same.',
        'Deactivated, out-of-scope and unknown tenants are listed in "skipped" WITH A REASON, so the denominator is auditable.',
        'rosterAgeDays is recorded because a list older than a tenant cannot contain it. Refresh the tenant list if it is stale.',
        'New tenants are passed in explicitly (-Include). firstSeen cannot detect them: the roster was bootstrapped in one pass, so every row shares a firstSeen.'
    )
    jobId            = ('pulljob-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    createdAt        = (Get-Date).ToString('o')
    repoCommit       = $repoCommit
    host             = "$($roster.host)"
    rosterCapturedAt = $rosterCap
    rosterAgeDays    = $ageDays
    rosterTenants    = $rosterRows.Count
    tenantCount      = $final.Count
    reasonCounts     = $byWhy
    estMinutes       = [math]::Round($final.Count * 25 / 60)
    estMB            = [math]::Round($final.Count * 0.25)
    deptIds          = @($final | ForEach-Object { $_.deptId })
    tenants          = @($final | ForEach-Object { [ordered]@{ deptId=$_.deptId; subdomain=$_.subdomain; status=$_.status; why=$_.why } })
    skippedCount     = @($skipped).Count
    skipped          = @($skipped | ForEach-Object { [ordered]@{ deptId=$_.deptId; subdomain=$_.subdomain; reason=$_.reason } })
}

$json = $job | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($jobPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Say ''
Say ("  TENANTS TO PULL: {0}   est {1} min / {2} MB" -f $final.Count, $job.estMinutes, $job.estMB)
foreach ($k in $byWhy.Keys) { Say ("    {0,-14} {1}" -f $k, $byWhy[$k]) }
if (@($skipped).Count -gt 0) {
    Say ("  SKIPPED {0} (denominator, not silence):" -f @($skipped).Count)
    foreach ($s in $skipped) { Say ("    {0,-32} {1}" -f $s.subdomain, $s.reason) }
}
Say ''
Say ("  written: {0}" -f $jobPath)
Say '  Review it, then press RUN THE JOB in the USx panel.'
Say '===================================================================================='
Say ''
exit 0
