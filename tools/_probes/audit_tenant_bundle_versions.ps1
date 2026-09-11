<#
  audit_tenant_bundle_versions.ps1 -- PER-BUNDLE VERSIONS, because a tenant does not have "a"
  version. It has up to THREE, and they drift independently.

  WHY THIS EXISTS. Rob, 2026-09-11, on the AZ_AZDPS anomaly:
    "az example. explain the issue. i don't understand where the disconnect is. ... we aree
     using this process to audit everything and we canfigure out how to address it once we
     have a full and clear picture otherwise it will happen again and again"

  THE DISCONNECT, MEASURED. Our version string is stamped into the DESCRIPTION of up to three
  bundles, and the repo build stamps all three with the SAME current version:
      ENTITIES   "Provider configuration for <P> vX.Y -- entity forms"   (or a generic string)
      <PROVIDER> "Provider configuration for <P> vX.Y"                   <-- AUTHORITATIVE
      RMS        "Provider configuration for <P> vX.Y -- RMS bundle"     (or a generic string)
  So when a TENANT shows different versions in different bundles, those bundles were imported
  AT DIFFERENT TIMES. An import can replace SOME bundles and leave others behind.

  WHAT THAT BROKE IN MY OWN TOOLING. `ingest_tenant_versions.ps1` read the FIRST
  "Provider configuration for <P> vX.Y" match in document order and called it "the" version.
  Document order is ENTITIES first. Consequences, all three observed on 2026-09-11:
    usx-hi-hcjdc-ofml   ENTITIES v4.19 / PROVIDER v4.20  -> reported BEHIND. It is CURRENT.
    usx-az-azdps        PROVIDER v3.12 / RMS v3.4        -> reported "mixed versions". It is
                                                            current; the RMS stamp is stale.
    practice-bertanzini ENTITIES v4.9  / PROVIDER v4.8   -> reported CLEAN, because the stale
                                                            ENTITIES stamp happened to MATCH
                                                            the ledger. The provider config is
                                                            actually a version BEHIND. This is
                                                            the dangerous direction.
  A first-match read is wrong in BOTH directions and its errors are silent.

  WHY A MISMATCHED PAIR IS NOT COSMETIC. Per CLAUDE.md the ENTITIES bundle owns the
  QUERYINPUTFORM (the officer's form) and the PROVIDER bundle owns the QIDMs (what reaches the
  wire). A tenant running ENTITIES from one version and QIDMs from another is running a
  form/QIDM pair that was never built or tested together -- which is precisely the defect class
  `audit_wiring_closure` BLOCKS in the repo. That gate cannot see a tenant. Same for a stale RMS
  bundle: CLAUDE.md records an entire class of RMS-only regressions (a QRDM code-source
  mismatch yielding "Mock results processed") that only the RMS side reveals.

  !! WHAT IT REFUSES TO DO
   1. It does NOT print a single "version" per tenant. That field is the bug.
   2. A generic description ("Entity form configurations", "Provider configuration for RMS")
      is reported as NOT-STAMPED, never as agreeing. Absence of a stamp is not a match.
   3. 0 configs FAILS rather than printing an empty clean table.

  Usage:  .\tools\_probes\audit_tenant_bundle_versions.ps1 [-OutFile <report>]
#>

param([string]$Dir, [string]$OutFile)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$src = if ($Dir) { $Dir } else { Join-Path $repoRoot '_versions\tenant_exports' }

$lines = @()
function Say([string]$s) { $script:lines += $s; Write-Host $s }

$rx = [regex]'Provider configuration for ([A-Za-z0-9_]+) v([0-9]+\.[0-9]+)'

$files = @(Get-ChildItem $src -Filter '*.json' -File -ErrorAction SilentlyContinue)
Say ''
Say '===================================================================================='
Say '  PER-BUNDLE VERSIONS ON EVERY TENANT -- a tenant has up to THREE, not one'
Say '===================================================================================='
Say ("  source: {0}   configs: {1}" -f $src, $files.Count)
if ($files.Count -eq 0) {
    Say '  [FAIL] no configs. Run ingest_tenant_configs.ps1 first. 0 examined = says NOTHING.'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

# repo current version per provider, for the "behind" column
$repoVer = @{}
foreach ($d in Get-ChildItem (Join-Path $repoRoot 'providers') -Directory) {
    $j = @(Get-ChildItem $d.FullName -Filter "$($d.Name)_v*.json" -File -ErrorAction SilentlyContinue)
    if ($j.Count -eq 1 -and $j[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$d.Name] = $Matches[1] }
}

$rows = @()
foreach ($f in $files) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    $bundles = @($o.departmentBundle.bundles)
    if ($bundles.Count -eq 0) { continue }

    $ent = $null; $prov = $null; $rms = $null; $provName = $null
    foreach ($b in $bundles) {
        $m = $rx.Match([string]$b.description)
        $v = $null
        if ($m.Success) { $v = $m.Groups[2].Value }
        switch ("$($b.name)") {
            'ENTITIES' { $ent = $v }
            'RMS'      { $rms = $v }
            default    { $prov = $v; $provName = "$($b.name)" }
        }
    }
    $rows += [pscustomobject]@{
        Tenant   = ($f.BaseName -replace '_\d+$','')
        Provider = $provName
        Entities = $ent
        Prov     = $prov
        Rms      = $rms
        Repo     = $(if ($provName -and $repoVer.ContainsKey($provName)) { $repoVer[$provName] } else { $null })
        Bundles  = $bundles.Count
    }
}

$stamped = @($rows | Where-Object { $_.Prov })
Say ("  tenants with a stamped PROVIDER bundle (ours): {0} of {1}" -f $stamped.Count, $rows.Count)

# ---- the disagreements ------------------------------------------------------------
$dis = @($stamped | Where-Object {
    ($_.Entities -and $_.Entities -ne $_.Prov) -or ($_.Rms -and $_.Rms -ne $_.Prov)
})

Say ''
Say '  ---- BUNDLES IMPORTED AT DIFFERENT TIMES (the actual finding) -------------------'
Say ('  {0,-26} {1,-20} {2,-9} {3,-9} {4,-9} {5}' -f 'tenant','provider','ENTITIES','PROVIDER','RMS','repo')
Say ('  ' + ('-' * 96))
if ($dis.Count -eq 0) { Say '  none -- every stamped bundle agrees with its provider bundle.' }
foreach ($r in ($dis | Sort-Object Tenant)) {
    $e = if ($r.Entities) { 'v' + $r.Entities } else { '(none)' }
    $p = if ($r.Prov)     { 'v' + $r.Prov }     else { '(none)' }
    $s = if ($r.Rms)      { 'v' + $r.Rms }      else { '(none)' }
    $q = if ($r.Repo)     { 'v' + $r.Repo }     else { '--' }
    Say ('  {0,-26} {1,-20} {2,-9} {3,-9} {4,-9} {5}' -f $r.Tenant, $r.Provider, $e, $p, $s, $q)
}

Say ''
Say ("  DISAGREEING {0} of {1} stamped tenants" -f $dis.Count, $stamped.Count)

# ---- what a FIRST-MATCH read would have said, vs the truth ------------------------
Say ''
Say '  ---- WHERE A FIRST-MATCH READ LIES (document order puts ENTITIES first) ---------'
$lied = 0
foreach ($r in ($stamped | Sort-Object Tenant)) {
    $first = if ($r.Entities) { $r.Entities } else { $r.Prov }
    if ($first -ne $r.Prov) {
        $lied++
        $dir = if ([version]$first -gt [version]$r.Prov) { 'OVERSTATES' } else { 'UNDERSTATES' }
        Say ('  {0,-26} first-match read v{1,-7} but the PROVIDER bundle is v{2,-7} -- {3}' -f $r.Tenant, $first, $r.Prov, $dir)
    }
}
if ($lied -eq 0) { Say '  none.' }
Say ("  => {0} tenant(s) where our reported version was NOT the provider bundle version." -f $lied)

# ---- behind repo, judged on the PROVIDER bundle only -----------------------------
Say ''
Say '  ---- BEHIND REPO, judged on the PROVIDER bundle (the authoritative one) ---------'
$behind = @($stamped | Where-Object { $_.Repo -and $_.Prov -ne $_.Repo })
if ($behind.Count -eq 0) { Say '  none.' }
foreach ($r in ($behind | Sort-Object Provider, Tenant)) {
    Say ('  {0,-26} {1,-20} tenant v{2,-8} repo v{3}' -f $r.Tenant, $r.Provider, $r.Prov, $r.Repo)
}

Say ''
Say '  NOTE: a generic description ("Entity form configurations" / "Provider configuration for'
Say '        RMS") is NOT-STAMPED and shown as (none). Absence of a stamp is not agreement --'
Say '        those bundles carry no version evidence either way.'
Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
exit 0
