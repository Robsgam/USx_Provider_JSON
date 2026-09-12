<#
  report_notours_reuse.ps1 -- OF THE CONFIGS WE DID NOT BUILD, WHICH ARE COPIES AND WHICH ARE ONE-OFFS?

  Rob, 2026-09-12: "for all the json you found that are 'not our builds' can you narrow down if any
  are being resued and which ones are unique."

  WHY IT MATTERS. A not-ours config that appears on ONE tenant is a one-off somebody hand-built.
  The same config on TWELVE tenants is a de-facto product: whoever maintains it is maintaining a
  fleet, and a defect in it is twelve defects. The support exposure is completely different, and the
  count of tenants does not tell you which you are looking at.

  ⚠️ IT COMPARES ON TWO AXES, BECAUSE ONE IS MISLEADING ON ITS OWN:

    WHOLE CONFIG -- the strictest: byte-identical after canonicalisation. Two tenants here are
      running the same file.
    PROVIDER BUNDLE ONLY -- the useful one. Two tenants can differ in ENTITIES or RMS (different
      forms, different RMS wiring) while running the IDENTICAL provider bundle, which is the part
      that talks to the state system. Grouping only on the whole config would report those as
      unrelated one-offs and understate the reuse.

  ⚠️ HASHES GO THROUGH _bundle_identity.ps1 -- description excluded, platform-added nulls
  normalised. A raw byte compare is not usable here for the same reason it is not usable for import
  verification: the platform re-serializes on export, so two exports of the same config differ.

  ⚠️ "NOT OURS" IS MEASURED, NOT ASSUMED. It means the provider bundle carries no
  "Provider configuration for <P> vX.Y" description. Absence of that stamp is EVIDENCE -- it is how
  Lafayette was confirmed hand-built by engineering -- not a gap in our records.

  Usage:
    tools\report_notours_reuse.ps1
    tools\report_notours_reuse.ps1 -OutFile providers\NOTOURS_REUSE.txt
#>
param(
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

Say '===================================================================================='
Say '  NOT-OUR-BUILD CONFIGS -- reused across tenants, or one-off?'
Say '===================================================================================='

$tenantDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
if (-not (Test-Path $tenantDir)) { Say ('  [FAIL] no tenant exports at {0}' -f $tenantDir); exit 1 }

$files = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
if ($files.Count -eq 0) { Say '  [FAIL] no tenant configs on disk -- nothing measured, so nothing may be claimed.'; exit 1 }

$rows = @(); $ours = 0; $skipped = 0
foreach ($f in $files) {
    $dept = ($f.BaseName -replace '^.*_(\d+)$', '$1')
    if ($dept -notmatch '^\d+$') { $skipped++; continue }   # a -replace that does not match returns its INPUT
    $sub = ($f.BaseName -replace '_\d+$', '')
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $skipped++; continue }
    $bl = Get-BundleList $o
    if ($bl.Count -eq 0) { $skipped++; continue }

    $pb = @($bl | Where-Object { ('{0}' -f $_.name) -ne 'ENTITIES' -and ('{0}' -f $_.name) -ne 'RMS' })[0]
    if (-not $pb) { $skipped++; continue }
    if (Get-BundleLabelVersion $pb) { $ours++; continue }      # stamped = ours, not this report's subject

    # Whole config, canonicalised; and the provider bundle alone.
    $whole = Get-Sha256Hex (ConvertTo-Canonical (Remove-NullProperties $o))
    $prov  = Get-BundleContentHash $pb

    $rows += [pscustomobject]@{
        Sub = $sub; Dept = $dept; Bundle = ('{0}' -f $pb.name)
        Bundles = (@($bl | ForEach-Object { '{0}' -f $_.name }) -join '+')
        Whole = $whole; Prov = $prov; Bytes = (Get-Item $f.FullName).Length
    }
}

Say ('  {0} config(s) on disk | {1} OURS (stamped, not analysed here) | {2} NOT OURS | {3} skipped' -f
     $files.Count, $ours, $rows.Count, $skipped)
if ($rows.Count -eq 0) { Say '  [FAIL] no not-our-build configs found -- refusing to report an empty analysis as a result.'; exit 1 }
Say ''

# ---- AXIS 1: whole config -----------------------------------------------------------------------
$wholeGroups = @($rows | Group-Object Whole | Sort-Object Count -Descending)
$wholeShared = @($wholeGroups | Where-Object { $_.Count -gt 1 })
$wholeUnique = @($wholeGroups | Where-Object { $_.Count -eq 1 })

Say '  ---- AXIS 1: IDENTICAL WHOLE CONFIG (same file, canonicalised) -----------------'
Say ('  {0} distinct config(s) across {1} tenants -- {2} reused, {3} one-off' -f
     $wholeGroups.Count, $rows.Count, $wholeShared.Count, $wholeUnique.Count)
Say ''
foreach ($g in $wholeShared) {
    $b = $g.Group[0]
    Say ('  x{0}  {1}  [{2}]  {3:N0} bytes' -f $g.Count, $g.Name.Substring(0,12), $b.Bundles, $b.Bytes)
    foreach ($m in ($g.Group | Sort-Object Sub)) { Say ('        {0}  (dept {1})' -f $m.Sub, $m.Dept) }
    Say ''
}

# ---- AXIS 2: provider bundle only ---------------------------------------------------------------
# The one that matters for support: the provider bundle is what talks to the state system, and two
# tenants can run it identically while differing in ENTITIES/RMS.
$provGroups = @($rows | Group-Object Prov | Sort-Object Count -Descending)
$provShared = @($provGroups | Where-Object { $_.Count -gt 1 })
$provUnique = @($provGroups | Where-Object { $_.Count -eq 1 })

Say '  ---- AXIS 2: IDENTICAL PROVIDER BUNDLE (the part that talks to the state) ------'
Say ('  {0} distinct provider bundle(s) across {1} tenants -- {2} reused, {3} unique' -f
     $provGroups.Count, $rows.Count, $provShared.Count, $provUnique.Count)
Say ''
foreach ($g in $provShared) {
    $b = $g.Group[0]
    $wholes = @($g.Group | Select-Object -ExpandProperty Whole | Sort-Object -Unique).Count
    $note = if ($wholes -eq 1) { 'whole config identical too' } else { ('{0} different whole configs -- same provider bundle, different ENTITIES/RMS' -f $wholes) }
    Say ('  x{0}  bundle {1}  content {2}  ({3})' -f $g.Count, $b.Bundle, $g.Name.Substring(0,12), $note)
    foreach ($m in ($g.Group | Sort-Object Sub)) { Say ('        {0,-34} {1}' -f $m.Sub, $m.Bundles) }
    Say ''
}

Say '  ---- ONE-OFFS: a provider bundle on exactly ONE tenant -------------------------'
Say '  Each of these is a configuration that exists nowhere else we have looked.'
Say ''
foreach ($g in ($provUnique | Sort-Object { $_.Group[0].Bundle }, { $_.Group[0].Sub })) {
    $m = $g.Group[0]
    Say ('  {0,-34} {1,-18} {2,-22} {3:N0} bytes' -f $m.Sub, $m.Bundle, $m.Bundles, $m.Bytes)
}
Say ''

Say '  ---- WHAT THIS DOES AND DOES NOT SAY -------------------------------------------'
Say '  IT SAYS: which of these configurations are the SAME configuration, by content.'
Say '  IT DOES NOT SAY who authored any of them, nor that a reused config is maintained'
Say '  centrally -- identical content is equally consistent with one file copied by hand'
Say '  to many tenants, which is exactly the support exposure worth knowing about.'
Say '  Absence of our version stamp is EVIDENCE these are not our builds, not a gap.'
Say '===================================================================================='

if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII; Write-Host ('  written: {0}' -f $OutFile) -ForegroundColor Cyan }
exit 0
