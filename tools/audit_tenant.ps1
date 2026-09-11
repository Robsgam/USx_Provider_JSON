<#
  audit_tenant.ps1 -- ONE TENANT, EVERYTHING WE KNOW, ON DEMAND.

  WHY THIS EXISTS. Rob, 2026-09-11: "moving forward we need to figure out how to extract 'new'
  tenants on a regular basis and be able to audit the tenants on demand". The roster diff
  covers the first half; this is the second. Everything needed already existed -- in five
  different files, which is the same as not existing when someone asks "what is on Newark?".

  WHAT IT ASSEMBLES (and it CONSULTS, never re-derives):
    tools\config\tenant_roster.json     identity: subdomain, status, firstSeen/lastSeen
    tools\config\tenant_map.json        the LEDGER correlation: ledgerName + claimed version
    _versions\tenant_exports\*.json     the pulled configuration (the BEFORE for any import)
    _versions\bundle_hash_index.json    content provenance -- which BUILD each bundle IS
    providers\<P>\<P>_v*.json           the repo's current version
  Accepts a SUBDOMAIN or a deptId, because a human knows one and the data is keyed on the other.

  !! WHAT IT REFUSES TO CONFLATE -- every one of these has produced a wrong answer here:
   1. "NEVER PULLED" IS NOT "NO PROVIDER". A tenant with no config on disk has not been shown
      to be empty; it has not been looked at. It prints the exact command to fix that.
   2. A LABEL IS NOT A VERSION. The version rides in up to THREE bundle descriptions and
      imports are PER-BUNDLE, so it reports label AND content side by side, per bundle, and
      never collapses them into one "tenant version" -- that single field is the bug that made
      usx-hi-hcjdc-ofml read BEHIND when it is CURRENT and practice-bertanzini read CLEAN when
      its provider bundle is a version older than the ledger claims.
   3. NO VERSION STRING MEANS NOT OUR BUILD -- positive evidence, not missing data.
   4. AN UNRESOLVED TENANT IS NOT A CLEAN ONE. If the roster does not know the deptId, it says
      so and stops rather than reporting an empty dossier as a healthy one.

  Usage:
    .\tools\audit_tenant.ps1 -Tenant newarkpd-foundation
    .\tools\audit_tenant.ps1 -Tenant 69509789559
    .\tools\audit_tenant.ps1 -Tenant usx-az-azdps -OutFile providers\AUDIT_usx-az-azdps.txt
#>

param(
    [Parameter(Mandatory)][string]$Tenant,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

$rosterPath = Join-Path $PSScriptRoot 'config\tenant_roster.json'
$mapPath    = Join-Path $PSScriptRoot 'config\tenant_map.json'
$cachePath  = Join-Path $repoRoot '_versions\bundle_hash_index.json'
$exportDir  = Join-Path $repoRoot '_versions\tenant_exports'

Say ''
Say '===================================================================================='
Say ("  TENANT DOSSIER -- {0}" -f $Tenant)
Say '===================================================================================='

# ---------------------------------------------------------------- identity
$ident = $null; $sources = @()
if (Test-Path $rosterPath) {
    $roster = Get-Content $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $sources += ("roster ({0} tenants)" -f @($roster.tenants).Count)
    $ident = @($roster.tenants | Where-Object { "$($_.deptId)" -eq $Tenant -or "$($_.subdomain)" -eq $Tenant })[0]
} else {
    Say '  [WARN] no tenant_roster.json -- identity/status unavailable. Run ingest_tenant_roster.ps1 -Update.'
}
if (-not $ident) {
    Say ''
    Say ("  [FAIL] '{0}' matches no deptId or subdomain in the roster." -f $Tenant)
    Say '         An unresolved tenant is NOT a clean one -- refusing to print an empty dossier.'
    Say '         If the platform has changed, refresh the roster: extension button 2, then'
    Say '         tools\ingest_tenant_roster.ps1 -Update'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}
$deptId = "$($ident.deptId)"
$sub    = "$($ident.subdomain)"

Say ''
Say '  IDENTITY'
Say ("    subdomain     : {0}" -f $sub)
Say ("    deptId        : {0}    <- the only stable key; subdomains get renamed" -f $deptId)
Say ("    status        : {0}" -f $ident.status)
Say ("    first seen    : {0}" -f $ident.firstSeen)
Say ("    last seen     : {0}" -f $ident.lastSeen)
if ($ident.cadSubdomain) { Say ("    CAD subdomain : {0}" -f $ident.cadSubdomain) }

# ---------------------------------------------------------------- what our records claim
Say ''
Say '  OUR RECORDS'
if (Test-Path $mapPath) {
    $map = Get-Content $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $sources += ("tenant_map ({0} tenants)" -f @($map.tenants).Count)
    $m = @($map.tenants | Where-Object { "$($_.deptId)" -eq $deptId })[0]
    if (-not $m) {
        Say '    NOT IN tenant_map.json -- this tenant is not correlated to any ledger row.'
    } else {
        $ln = if ($m.ledgerName) { "$($m.ledgerName)" } else { '(no ledger row)' }
        Say ("    ledger name   : {0}" -f $ln)
        Say ("    class         : {0}" -f $m.class)
        if ($m.ledgerVersion) {
            if ("$($m.ledgerVersion)" -eq 'NOT-OURS') { Say '    ledger claims : NOT OURS (hand-built)' }
            else { Say ("    ledger claims : v{0}" -f $m.ledgerVersion) }
        } else { Say '    ledger claims : (no version recorded)' }
    }
} else { Say '    [WARN] tenant_map.json missing -- ledger correlation unavailable.' }

# ---------------------------------------------------------------- the deployed config
Say ''
Say '  WHAT IS DEPLOYED'
$cfgFile = @(Get-ChildItem $exportDir -Filter ("*_" + $deptId + ".json") -File -ErrorAction SilentlyContinue)[0]
if (-not $cfgFile) {
    # REFUSAL 1: never pulled is not empty.
    Say '    *** NEVER PULLED -- no configuration on disk for this deptId. ***'
    Say '    This does NOT mean the tenant has no provider installed; it means nobody looked.'
    Say '    To pull it: extension button "6b. PULL THE CONFIGS", with ONLY this dept id in the box:'
    Say ("        {0}" -f $deptId)
    Say '    then: tools\ingest_tenant_configs.ps1'
    Say '===================================================================================='
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 0
}
Say ("    config file   : {0}  ({1:N0} bytes)" -f $cfgFile.Name, $cfgFile.Length)
$cfg = Get-Content $cfgFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
$bundles = Get-BundleList $cfg
Say ("    bundles       : {0}" -f $bundles.Count)

# provenance index
$byHash = @{}
if (Test-Path $cachePath) {
    $cache = Get-Content $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $n = 0
    foreach ($p in $cache.PSObject.Properties) {
        $a = $p.Value; $n++
        foreach ($b in @($a.bundles)) {
            $tag = "$($a.provider) v$($a.version)"
            if (-not $byHash.ContainsKey($b.hash)) { $byHash[$b.hash] = @() }
            $byHash[$b.hash] += $tag
        }
    }
    $sources += ("bundle hash index ({0} builds)" -f $n)
} else {
    Say '    [WARN] no bundle_hash_index.json -- content provenance unavailable.'
    Say '           Build it: tools\audit_tenant_provenance.ps1 -Rebuild'
}

Say ''
Say ('    {0,-20} {1,-26} {2}' -f 'BUNDLE', 'LABEL SAYS', 'CONTENT IS')
Say ('    ' + ('-' * 92))
$provName = $null; $provLabelVer = $null; $provContent = @()
foreach ($b in $bundles) {
    $lbl = Get-BundleLabelVersion $b
    $lblTxt = if ($lbl) { $lbl.Tag } else { '(not stamped)' }
    $h = Get-BundleContentHash $b
    $hits = @()
    if ($byHash.ContainsKey($h)) { $hits = @($byHash[$h] | Sort-Object -Unique) }
    $cTxt = if ($hits.Count -eq 0) { 'NO KNOWN BUILD' }
            elseif ($hits.Count -le 3) { $hits -join ', ' }
            else { ($hits[0..2] -join ', ') + (' (+{0} more)' -f ($hits.Count - 3)) }
    Say ('    {0,-20} {1,-26} {2}' -f $b.name, $lblTxt, $cTxt)
    if ("$($b.name)" -ne 'ENTITIES' -and "$($b.name)" -ne 'RMS') {
        $provName = "$($b.name)"
        if ($lbl) { $provLabelVer = $lbl.Version }
        $provContent = $hits
    }
}

# ---------------------------------------------------------------- verdict
Say ''
Say '  VERDICT'
if (-not $provLabelVer) {
    # REFUSAL 3
    Say '    NOT OUR BUILD. The provider bundle carries no "Provider configuration for <P> vX.Y"'
    Say '    description. Every build we produce carries one, so its ABSENCE is positive evidence'
    Say '    -- this is how Lafayette was confirmed as the hand-built engineering JSON.'
} else {
    $repoVer = $null
    if ($provName) {
        $j = @(Get-ChildItem (Join-Path $repoRoot ("providers\" + $provName)) -Filter ($provName + "_v*.json") -File -ErrorAction SilentlyContinue)
        if ($j.Count -eq 1 -and $j[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer = $Matches[1] }
    }
    Say ("    provider      : {0}" -f $provName)
    Say ("    installed     : v{0}   (from the PROVIDER bundle description, not the first match)" -f $provLabelVer)
    if ($repoVer) {
        Say ("    repo current  : v{0}" -f $repoVer)
        if ($repoVer -eq $provLabelVer) { Say '    => CURRENT. Nothing owed.' }
        else { Say ("    => BEHIND by design or by omission -- repo has v{0}. An import would move it." -f $repoVer) }
    } else {
        Say '    repo current  : (no single versioned root JSON resolved)'
    }
    if ($provContent.Count -eq 0) {
        Say '    !! CONTENT MATCHES NO BUILD IN OUR HISTORY. The label claims one of ours but the'
        Say '       bytes are not any version we ever produced -- hand-modified, or a provider'
        Say '       that only exists in the pre-versioned era (try audit_tenant_provenance'
        Say '       -Providers <P> -IncludeLegacy before treating this as a defect).'
    } elseif ($provContent -notcontains ($provName + ' v' + $provLabelVer)) {
        Say '    !! LABEL AND CONTENT DISAGREE -- the bundle says one version and IS another.'
    }
}

Say ''
Say ("  consulted: {0}" -f ($sources -join ' | '))
Say '  (a label is never reported as a version; content provenance is the authority.)'
Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
