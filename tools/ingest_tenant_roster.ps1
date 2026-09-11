<#
  ingest_tenant_roster.ps1 -- WHAT CHANGED ON THE PLATFORM SINCE LAST TIME? New tenants,
  renames, and status changes, from ONE page load.

  WHY THIS EXISTS. Rob, 2026-09-11, describing the standing process behind the one-time scan:
    "the intial scan and inventory will be a one time thing. moving forward we need to figure
     out how to extract 'new' tenants on a regular basis and be able to audit the tenants on
     demand"

  WHY IT DIFFS THE INDEX AND NOT THE CENSUS. The full census visits all 1,785 configuration
  pages and takes 20-25 minutes. The DEPARTMENT INDEX is a SINGLE page load and already carries
  deptId / subdomain / analyticsAlias / status / cadSubdomain / ssoConnectionId for every
  tenant. So a recurring audit is: pull the index (1 load) -> diff -> census ONLY what changed.
  That is the difference between a monthly job measured in seconds and one measured in hours.

  !! deptId IS THE JOIN KEY, AND THIS TOOL EXISTS BECAUSE SUBDOMAINS MOVE. Rob, 2026-09-10:
  "the tenant naming conventions are not intuative so we will need to keep them correlated when
  possible." A subdomain change on an EXISTING deptId is a RENAME, not a new tenant -- and
  reporting it as new would manufacture a discovery, which is exactly how a LIVE production
  tenant (`hawaii-dle`) was once reported as an unknown find.

  !! WHAT IT REFUSES TO CONFLATE -- each of these would produce a false alarm:
   1. A BOOTSTRAP IS NOT 1,785 DISCOVERIES. With no baseline, every tenant is "new". The tool
      says BOOTSTRAP explicitly, writes the roster, and reports NO findings.
   2. A RENAME IS NOT A NEW TENANT (same deptId, different subdomain).
   3. A MISSING ROW IS NOT A DELETED TENANT. A short index means a truncated capture, so if the
      row count drops by more than -MaxShrinkPct it REFUSES to report departures at all rather
      than claim hundreds of tenants vanished.
   4. A READ-ONLY RUN DOES NOT MOVE THE BASELINE. Updating requires -Update, so a diff can be
      inspected before it is absorbed and the same change cannot silently stop being reported.

  OUTPUT: the roster lives at tools\config\tenant_roster.json (COMMITTED -- metadata only, no
  configuration content) plus a paste-ready dept-id list of what to sweep next.

  Usage:
    .\tools\ingest_tenant_roster.ps1                 # diff only, report, change nothing
    .\tools\ingest_tenant_roster.ps1 -Update         # absorb the diff into the baseline
    .\tools\ingest_tenant_roster.ps1 -Path <file>
#>

param(
    [string]$Path,
    [switch]$Update,
    [int]$MaxShrinkPct = 10,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot   = Split-Path -Parent $PSScriptRoot
$rosterPath = Join-Path $PSScriptRoot 'config\tenant_roster.json'

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

Say ''
Say '===================================================================================='
Say '  TENANT ROSTER DIFF -- what changed on the platform since the last baseline'
Say '===================================================================================='

# ---------------------------------------------------------------- the new index
$src = if ($Path) { $Path } else {
    $f = @(Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads') -Filter 'usx_admin_departments_*.json' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime | Select-Object -Last 1)
    if ($f.Count -gt 0) { $f[0].FullName } else { $null }
}
if (-not $src -or -not (Test-Path $src)) {
    Say '  [FAIL] no usx_admin_departments_*.json found.'
    Say '         0 rows examined -- this run says NOTHING about the platform.'
    Say '         Run extension button "2. List all tenants + department ids" first (ONE page load).'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

$idx = Get-Content $src -Raw | ConvertFrom-Json
$rows = @($idx.deptIds)
Say ("  index file : {0}" -f (Split-Path -Leaf $src))
Say ("  captured   : {0}   host: {1}" -f $idx.capturedAt, $idx.host)
Say ("  rows       : {0}" -f $rows.Count)
if ($rows.Count -eq 0) {
    Say '  [FAIL] the index parsed but carries 0 departments -- refusing to diff against nothing.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

$now = @{}
foreach ($r in $rows) {
    $id = "$($r.deptId)"
    if (-not $id) { continue }
    $now[$id] = [ordered]@{
        deptId = $id; subdomain = "$($r.subdomain)"; status = "$($r.status)"
        analyticsAlias = "$($r.analyticsAlias)"; cadSubdomain = "$($r.cadSubdomain)"
    }
}
Say ("  distinct deptIds: {0}" -f $now.Count)

# ---------------------------------------------------------------- the baseline
$bootstrap = -not (Test-Path $rosterPath)
$base = @{}; $baseMeta = $null
if (-not $bootstrap) {
    $rj = Get-Content $rosterPath -Raw | ConvertFrom-Json
    $baseMeta = $rj
    foreach ($t in @($rj.tenants)) { $base["$($t.deptId)"] = $t }
    Say ("  baseline   : {0} tenant(s), captured {1}" -f $base.Count, $rj.capturedAt)
}

if ($bootstrap) {
    Say ''
    Say '  *** BOOTSTRAP -- there is no baseline yet. ***'
    Say '  Every tenant would read as "new", which would be 1,785 discoveries and ZERO of them'
    Say '  real. No findings are reported on a bootstrap run, by design.'
    if (-not $Update) {
        Say '  Re-run with -Update to write the first baseline.'
        if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
        exit 0
    }
}

# ---------------------------------------------------------------- the diff
$newT = @(); $renamed = @(); $statusChanged = @(); $gone = @()
if (-not $bootstrap) {
    foreach ($id in $now.Keys) {
        if (-not $base.ContainsKey($id)) { $newT += $now[$id]; continue }
        $b = $base[$id]
        if ("$($b.subdomain)" -ne $now[$id].subdomain) {
            $renamed += [pscustomobject]@{ deptId = $id; From = "$($b.subdomain)"; To = $now[$id].subdomain }
        }
        if ("$($b.status)" -ne $now[$id].status) {
            $statusChanged += [pscustomobject]@{ deptId = $id; Sub = $now[$id].subdomain; From = "$($b.status)"; To = $now[$id].status }
        }
    }
    foreach ($id in $base.Keys) { if (-not $now.ContainsKey($id)) { $gone += $base[$id] } }

    # REFUSAL 3: a short index is a truncated capture, not a mass deletion.
    $shrink = 0
    if ($base.Count -gt 0) { $shrink = [math]::Round(100.0 * ($base.Count - $now.Count) / $base.Count, 1) }
    if ($shrink -gt $MaxShrinkPct) {
        Say ''
        Say ("  !! INDEX SHRANK {0}% ({1} -> {2}). That is beyond -MaxShrinkPct {3}." -f $shrink, $base.Count, $now.Count, $MaxShrinkPct)
        Say '     A truncated capture and a mass deletion look IDENTICAL here, so DEPARTURES ARE'
        Say '     NOT REPORTED for this run. New tenants, renames and status changes below are'
        Say '     still valid -- they are evidence of presence, which truncation cannot fake.'
        $gone = @()
    }
}

Say ''
Say ("  NEW {0} | RENAMED {1} | STATUS CHANGED {2} | NO LONGER LISTED {3}" -f `
     $newT.Count, $renamed.Count, $statusChanged.Count, $gone.Count)

if ($newT.Count -gt 0) {
    Say ''
    Say '  ---- NEW TENANTS (never seen before) --------------------------------------------'
    Say ('  {0,-16} {1,-34} {2}' -f 'deptId', 'subdomain', 'status')
    foreach ($t in ($newT | Sort-Object { $_.subdomain })) {
        Say ('  {0,-16} {1,-34} {2}' -f $t.deptId, $t.subdomain, $t.status)
    }
    # Deactivated tenants cannot serve queries; Rob: "we can filter out deavtivated tenants".
    $sweep = @($newT | Where-Object { $_.status -notmatch 'DEACTIVATED' })
    Say ''
    Say ("  PASTE THIS to census the {0} new non-deactivated tenant(s):" -f $sweep.Count)
    if ($sweep.Count -eq 0) { Say '    (none -- every new tenant is DEACTIVATED)' }
    else { Say ('    ' + ((@($sweep | ForEach-Object { $_.deptId })) -join ',')) }
}

if ($renamed.Count -gt 0) {
    Say ''
    Say '  ---- RENAMED (same deptId -- NOT a new tenant) ----------------------------------'
    foreach ($r in $renamed) { Say ('  {0,-16} {1}  ->  {2}' -f $r.deptId, $r.From, $r.To) }
    Say '  Anything keyed on SUBDOMAIN is now stale for these; deptId is the stable key.'
}

if ($statusChanged.Count -gt 0) {
    Say ''
    Say '  ---- STATUS CHANGED -------------------------------------------------------------'
    foreach ($s in ($statusChanged | Sort-Object Sub)) {
        $flag = ''
        if ($s.To -match 'LIVE' -and $s.From -notmatch 'LIVE') { $flag = '   <== WENT LIVE' }
        Say ('  {0,-30} {1}  ->  {2}{3}' -f $s.Sub, $s.From, $s.To, $flag)
    }
}

if ($gone.Count -gt 0) {
    Say ''
    Say '  ---- NO LONGER LISTED -----------------------------------------------------------'
    foreach ($g in ($gone | Sort-Object { $_.subdomain })) { Say ('  {0,-16} {1,-34} was {2}' -f $g.deptId, $g.subdomain, $g.status) }
}

# ---------------------------------------------------------------- write
if ($Update) {
    $firstSeen = @{}
    if (-not $bootstrap) { foreach ($t in @($baseMeta.tenants)) { $firstSeen["$($t.deptId)"] = "$($t.firstSeen)" } }
    $stamp = (Get-Date).ToString('s')
    $out = @()
    foreach ($id in ($now.Keys | Sort-Object)) {
        $t = $now[$id]
        $fs = if ($firstSeen.ContainsKey($id) -and $firstSeen[$id]) { $firstSeen[$id] } else { $stamp }
        $out += [pscustomobject]@{
            deptId = $t.deptId; subdomain = $t.subdomain; status = $t.status
            analyticsAlias = $t.analyticsAlias; cadSubdomain = $t.cadSubdomain
            firstSeen = $fs; lastSeen = $stamp
        }
    }
    $doc = [ordered]@{
        _what  = 'Baseline roster of every department on the platform. Diffed to find NEW tenants.'
        _rules = @(
            'METADATA ONLY -- never any configuration content.',
            'deptId is the join key. A subdomain change on an existing deptId is a RENAME, not a new tenant.',
            'A bootstrap run reports NO findings: with no baseline every tenant reads as new.',
            'A read-only run does not move this baseline; -Update does.'
        )
        capturedAt = "$($idx.capturedAt)"
        host       = "$($idx.host)"
        updated    = $stamp
        source     = 'tools/ingest_tenant_roster.ps1 <- extension button 2 (department index)'
        counts     = [ordered]@{ tenants = $out.Count }
        tenants    = $out
    }
    ($doc | ConvertTo-Json -Depth 6) | Set-Content -Path $rosterPath -Encoding UTF8
    Say ''
    Say ("  baseline UPDATED: tools\config\tenant_roster.json ({0} tenants)" -f $out.Count)
} else {
    Say ''
    Say '  baseline NOT changed (read-only run). Re-run with -Update to absorb this diff.'
}

Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
