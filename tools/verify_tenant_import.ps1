<#
  verify_tenant_import.ps1 -- DID THE IMPORT ACTUALLY LAND? Proof, per bundle, from hashes.

  WHY THIS EXISTS. Rob, 2026-09-11: "so maybe a skill that imports and runs the export o check
  what the actual cversion is with proof", and earlier: "the idea is for the tool to eventually
  execute the imports, then run an export, then compare the 2 to confirm the json update takes
  place."

  THIS IS THE VERIFY HALF, AND IT IS DELIBERATELY SEPARATE FROM ANY WRITE PATH. It works
  identically whether the import was performed BY HAND in the tenant UI or by a future
  deployment tool -- which is the point: the verification must be trustworthy BEFORE anything
  automates the write. If this cannot prove a manual import landed, it certainly cannot verify
  an automated one.

  THE THREE THINGS IT COMPARES, per bundle:
      BEFORE   the archived pre-import config   (_versions\tenant_exports\_before\)
      AFTER    the freshly pulled config        (_versions\tenant_exports\)
      REPO     the build we intended to install (providers\<P>\<P>_v*.json)

  !! WHY A LABEL CHECK IS NOT ENOUGH, AND WHY A BYTE COMPARE IS WORSE.
   - The version rides in a bundle DESCRIPTION, and imports are PER-BUNDLE. A tenant can end up
     with a NEW description over UNCHANGED content, or the reverse. Measured 2026-09-11: four
     tenants carried stale labels over content identical to the repo. So "the description now
     says v7.24" does NOT prove the config changed.
   - A RAW byte compare fails on a CORRECT import, because the platform re-serializes on export
     (emitting "conditions":null where our build omits the property). So equality is the wrong
     test too.
   Both are avoided by hashing through _bundle_identity.ps1: description excluded, platform
   nulls normalized.

  !! FOUR REFUSALS, each of which would otherwise report a false success:
   1. NO BEFORE -> it CANNOT prove anything changed. Says so; does not fall back to "AFTER
      matches REPO, therefore the import worked" -- a tenant already at the target version
      would pass that with no import having occurred at all.
   2. AFTER == BEFORE -> THE IMPORT DID NOT LAND, regardless of what any label says. This is
      the failure a label check misses completely.
   3. LABEL MOVED BUT CONTENT DID NOT -> reported as FAILURE, not success.
   4. NO AFTER -> nothing was pulled; it is not a verdict about the tenant.

  Usage:
    .\tools\verify_tenant_import.ps1 -Tenant usx-fl-fcic
    .\tools\verify_tenant_import.ps1 -Tenant 69510828830 -ExpectedProvider FL_FCIC
#>

param(
    [Parameter(Mandatory)][string]$Tenant,
    [string]$ExpectedProvider,
    [string]$ExpectedVersion,
    # -TenantDir points the BEFORE/AFTER lookup at a REPLICA. It exists so this tool's own
    # failure modes can be exercised without writing fixtures into the real export directory --
    # usx-tooling Step 5c: mutating the live artifact to prove a check works leaves footprints
    # and a crash window. A verifier whose failure paths were never exercised is a verifier
    # whose PASS means nothing.
    [string]$TenantDir,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

$exportDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
$beforeDir = Join-Path $exportDir '_before'
$rosterPath = Join-Path $PSScriptRoot 'config\tenant_roster.json'

Say ''
Say '===================================================================================='
Say ("  IMPORT VERIFICATION -- {0}" -f $Tenant)
Say '===================================================================================='

# resolve the tenant to a deptId (a human types a subdomain; the files are keyed on deptId)
$deptId = $null; $sub = $null
if ($Tenant -match '^\d+$') { $deptId = $Tenant }
if (Test-Path $rosterPath) {
    $r = Get-Content $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $hit = @($r.tenants | Where-Object { "$($_.deptId)" -eq $Tenant -or "$($_.subdomain)" -eq $Tenant })[0]
    if ($hit) { $deptId = "$($hit.deptId)"; $sub = "$($hit.subdomain)" }
}
if (-not $deptId) {
    Say ("  [FAIL] cannot resolve '{0}' to a deptId. Refresh the roster (button 2 then" -f $Tenant)
    Say '         ingest_tenant_roster.ps1 -Update) or pass the numeric deptId directly.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
Say ("  tenant: {0}   deptId: {1}" -f $(if ($sub) { $sub } else { '(subdomain unknown)' }), $deptId)

# AFTER = the current pull
$afterFile = @(Get-ChildItem $exportDir -Filter ("*_" + $deptId + ".json") -File -ErrorAction SilentlyContinue)[0]
if (-not $afterFile) {
    Say '  [FAIL] no CURRENT config on disk (the AFTER). Nothing was pulled for this tenant.'
    Say ("         Pull it: extension button 6b with only {0} in the box, then ingest_tenant_configs.ps1" -f $deptId)
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
# BEFORE = the newest archived pre-import config for this deptId
$beforeFile = @(Get-ChildItem $beforeDir -Filter ("*_" + $deptId + "_*.json") -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime | Select-Object -Last 1)[0]

Say ("  AFTER  : {0}  ({1:N0} bytes, {2:yyyy-MM-dd HH:mm})" -f $afterFile.Name, $afterFile.Length, $afterFile.LastWriteTime)
if ($beforeFile) {
    Say ("  BEFORE : {0}  ({1:N0} bytes, {2:yyyy-MM-dd HH:mm})" -f $beforeFile.Name, $beforeFile.Length, $beforeFile.LastWriteTime)
} else {
    Say '  BEFORE : *** NONE ARCHIVED ***'
}

function Get-BundleMap([string]$path) {
    $o = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $m = [ordered]@{}
    foreach ($b in (Get-BundleList $o)) {
        $lbl = Get-BundleLabelVersion $b
        $m["$($b.name)"] = [pscustomobject]@{
            Hash  = (Get-BundleContentHash $b)
            Label = $(if ($lbl) { $lbl.Tag } else { '(not stamped)' })
        }
    }
    return $m
}

$after  = Get-BundleMap $afterFile.FullName
$before = if ($beforeFile) { Get-BundleMap $beforeFile.FullName } else { $null }

# which provider are we verifying?
$prov = $ExpectedProvider
if (-not $prov) {
    $prov = @($after.Keys | Where-Object { $_ -ne 'ENTITIES' -and $_ -ne 'RMS' })[0]
}
if (-not $prov) {
    Say '  [FAIL] the AFTER config carries no provider bundle (only ENTITIES/RMS) -- nothing to verify.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
$repoJson = @(Get-ChildItem (Join-Path $repoRoot ("providers\" + $prov)) -Filter ($prov + "_v*.json") -File -ErrorAction SilentlyContinue)
if ($repoJson.Count -ne 1) {
    Say ("  [FAIL] cannot resolve a single repo build for {0} -- found {1}." -f $prov, $repoJson.Count)
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
$repoVer = if ($repoJson[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $Matches[1] } else { '?' }
if ($ExpectedVersion -and $ExpectedVersion -ne $repoVer) {
    Say ("  [WARN] -ExpectedVersion v{0} does not match the repo root build v{1}." -f $ExpectedVersion, $repoVer)
    Say '         Verifying against the REPO BUILD, since that is what an import installs.'
}
$repo = Get-BundleMap $repoJson[0].FullName
Say ("  REPO   : {0}  (target v{1})" -f $repoJson[0].Name, $repoVer)

# ---------------------------------------------------------------- the proof table
Say ''
Say '  ---- PROOF, per bundle (canonical hash; description excluded, platform nulls normalized)'
Say ('  {0,-20} {1,-14} {2,-14} {3,-14} {4}' -f 'BUNDLE','BEFORE','AFTER','REPO TARGET','')
Say ('  ' + ('-' * 96))
$names = @(@($after.Keys) + @($repo.Keys) + @(if ($before) { $before.Keys } else { @() }) | Sort-Object -Unique)
$changedBundles = @(); $matchRepo = @(); $mismatch = @()
foreach ($n in $names) {
    $b = if ($before -and $before.Contains($n)) { $before[$n].Hash.Substring(0,12) } else { '(absent)' }
    $a = if ($after.Contains($n))  { $after[$n].Hash.Substring(0,12) }  else { '(absent)' }
    $r = if ($repo.Contains($n))   { $repo[$n].Hash.Substring(0,12) }   else { '(absent)' }
    $flags = @()
    if ($before -and $before.Contains($n) -and $after.Contains($n) -and $before[$n].Hash -ne $after[$n].Hash) { $flags += 'CHANGED'; $changedBundles += $n }
    elseif ($before -and -not $before.Contains($n) -and $after.Contains($n)) { $flags += 'ADDED'; $changedBundles += $n }
    if ($after.Contains($n) -and $repo.Contains($n)) {
        if ($after[$n].Hash -eq $repo[$n].Hash) { $flags += '== REPO'; $matchRepo += $n } else { $flags += 'DIFFERS FROM REPO'; $mismatch += $n }
    }
    Say ('  {0,-20} {1,-14} {2,-14} {3,-14} {4}' -f $n, $b, $a, $r, ($flags -join ' / '))
}
Say ''
Say '  ---- LABELS (reported, never used as the verdict) --------------------------------'
foreach ($n in $names) {
    $bl = if ($before -and $before.Contains($n)) { $before[$n].Label } else { '(absent)' }
    $al = if ($after.Contains($n)) { $after[$n].Label } else { '(absent)' }
    Say ('  {0,-20} before: {1,-28} after: {2}' -f $n, $bl, $al)
}

# ---------------------------------------------------------------- verdict
Say ''
Say '  ---- VERDICT ---------------------------------------------------------------------'
$fail = $false
if (-not $before) {
    # REFUSAL 1
    Say '  UNPROVEN -- no BEFORE was archived, so NOTHING here can show a change occurred.'
    Say '  Do NOT read "AFTER == REPO" as success: a tenant already at the target version would'
    Say '  satisfy that with no import having happened at all. The archive is written by'
    Say '  ingest_tenant_configs.ps1 when a re-pull differs from the stored config, so a BEFORE'
    Say '  exists only if this tenant was pulled BOTH before and after the import.'
    if ($after.Contains($prov) -and $repo.Contains($prov)) {
        $same = $after[$prov].Hash -eq $repo[$prov].Hash
        Say ("  For information only: the {0} bundle currently {1} the repo v{2} build." -f $prov, $(if ($same) { 'MATCHES' } else { 'does NOT match' }), $repoVer)
    }
    $fail = $true
} elseif ($changedBundles.Count -eq 0) {
    # REFUSAL 2 -- the one a label check misses
    Say '  *** THE IMPORT DID NOT LAND. *** Every bundle is byte-identical to the BEFORE.'
    Say '  Nothing on this tenant changed, whatever any description now says.'
    $fail = $true
} else {
    Say ("  bundles that CHANGED: {0}" -f ($changedBundles -join ', '))
    if ($mismatch.Count -eq 0 -and $after.Contains($prov) -and $repo.Contains($prov)) {
        Say ("  PASS -- the config changed AND every comparable bundle now matches the repo v{0} build." -f $repoVer)
        Say '  That is the acceptance test: a real change, landing on the intended build.'
    } else {
        Say ("  FAIL -- the config changed but these bundles do NOT match the repo build: {0}" -f ($mismatch -join ', '))
        Say '  A changed-but-wrong config is worse than an unchanged one: it looks like success.'
        $fail = $true
    }
    # REFUSAL 3
    $labelMovedOnly = @($names | Where-Object {
        $before -and $before.Contains($_) -and $after.Contains($_) -and
        $before[$_].Hash -eq $after[$_].Hash -and $before[$_].Label -ne $after[$_].Label })
    if ($labelMovedOnly.Count -gt 0) {
        Say ("  !! LABEL-ONLY CHANGE on: {0} -- the description moved, the content did not." -f ($labelMovedOnly -join ', '))
        Say '     Counted as a FAILURE for those bundles, not a success.'
        $fail = $true
    }
}

Say ''
Say '  The verdict rests on CONTENT HASHES, not on any version string. A label check alone'
Say '  passes on a label-only change; a raw byte compare FAILS on a correct import because the'
Say '  platform re-serializes. Both traps are avoided by _bundle_identity.ps1.'
Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
if ($fail) { exit 1 } else { exit 0 }
