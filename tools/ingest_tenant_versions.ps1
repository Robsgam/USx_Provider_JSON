<#
  ingest_tenant_versions.ps1 -- WHAT VERSION IS ON EVERY TENANT, AND DOES IT MATCH WHAT WE SAY?

  WHY THIS EXISTS. Rob's original ask, 2026-09-10, in full:
    "my goal was for you to scan the entire departments page and visitn each configuration page
     to 1 determimn if it has a usx provider installed and download to compare what version for
     cross checking"
  I delivered the first half (ingest_tenant_scan.ps1 -- presence) and then offered to export a
  HANDFUL. Rob: "i thought you were supposed to export every json you find." He was right; the
  download-and-compare was the goal from the start. This tool is the second half.

  INPUT: the extension's export sweep files, `usx_admin_versions_*.json` (button 6), which click
  each tenant's own **Export JSON** control in a hidden iframe and read our version out of the
  exported bundle description ("Provider configuration for <P> v<X.Y>").

  THREE-WAY COMPARISON, which is the whole point:
      MEASURED   what the tenant's own export says
      LEDGER     what IMPORT_LEDGER section B claims (via tools/config/tenant_map.json)
      REPO       the current versioned root JSON for that provider
  Each row gets a verdict naming WHICH pair disagrees. A drift between MEASURED and LEDGER is a
  record defect; between MEASURED and REPO it is an import that is simply behind.

  !! WHAT IT REFUSES TO DO -- each of these has already produced a wrong answer:
   1. A NON-`VERSION-READ` ROW IS NOT "NO CONFIG". `NO-SAFE-CONTROL` / `CLICKED-BUT-NO-JSON` /
      `ERROR` mean UNRESOLVED. Counted separately, never folded into agreement.
   2. ABSENCE OF OUR VERSION STRING IS EVIDENCE, NOT A GAP. Every build we produce carries
      "Provider configuration for <P> vX.Y" in the bundle description (the convention exists
      because the platform rejects a top-level `version` field). A tenant that exports a bundle
      with NO such string is running a config we did not build -- that is how Lafayette was
      confirmed as the hand-built engineering JSON. Reported as NOT-OUR-BUILD, not as a failure.
   3. THE PLATFORM COUNTER IS NOT A VERSION. It is carried for corroboration only (7 tenants
      confirmed "same claimed version -> same counter" on 2026-09-10; Newark was the lone
      contradiction and was independently wrong). Never printed as a version.
   4. 0 FILES FAILS. "Found nothing" and "never looked" are different verdicts.

  PARTIALS: button 6 saves every 3 tenants, so several files hold overlapping results. Rows are
  keyed by deptId and the LAST-WRITTEN file wins -- otherwise an early partial would outvote the
  finished run.

  Usage:
    .\tools\ingest_tenant_versions.ps1
    .\tools\ingest_tenant_versions.ps1 -Path <dir> -OutFile providers\TENANT_VERSION_REPORT.txt
#>

param(
    [string]$Path,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

# --- the correlation map owns subdomain <-> deptId <-> ledger name/version (see its own header)
$mapPath = Join-Path $PSScriptRoot 'config\tenant_map.json'
if (-not (Test-Path $mapPath)) {
    Say '  [FAIL] tools/config/tenant_map.json is MISSING -- no tenant could be named or compared.'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}
$map = Get-Content $mapPath -Raw | ConvertFrom-Json
$byId = @{}
foreach ($t in @($map.tenants)) { $byId["$($t.deptId)"] = $t }

# --- repo current version per provider, read from the versioned root JSON filename
$repoVer = @{}
foreach ($d in Get-ChildItem (Join-Path $repoRoot 'providers') -Directory) {
    $j = @(Get-ChildItem $d.FullName -Filter "$($d.Name)_v*.json" -File -ErrorAction SilentlyContinue)
    if ($j.Count -eq 1 -and $j[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$d.Name] = $Matches[1] }
}

$srcDir = if ($Path) { $Path } else { Join-Path $env:USERPROFILE 'Downloads' }
$files = @(Get-ChildItem $srcDir -Filter 'usx_admin_versions_*.json' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime)

Say ''
Say '===================================================================================='
Say '  TENANT VERSION CROSS-CHECK -- measured vs ledger vs repo'
Say '===================================================================================='

if ($files.Count -eq 0) {
    Say "  [FAIL] no usx_admin_versions_*.json in $srcDir"
    Say '         0 files examined -- this run says NOTHING about any tenant version.'
    Say '         Run the panel export sweep first; it saves every 3 tenants.'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

# LAST WRITE WINS per deptId -- partials overlap by design.
$rows = @{}
foreach ($f in $files) {
    $o = Get-Content $f.FullName -Raw | ConvertFrom-Json
    foreach ($r in @($o.results)) { $rows["$($r.deptId)"] = $r }
}
$all = @($rows.Values)
Say ("  files: {0}   distinct tenants: {1}   repo versions known for {2} provider(s)" -f `
     $files.Count, $all.Count, $repoVer.Count)

$read      = @($all | Where-Object { $_.verdict -eq 'VERSION-READ' })
$notOurs   = @($all | Where-Object { $_.verdict -eq 'EXPORTED-BUT-NO-VERSION-STRING' })
$unres     = @($all | Where-Object { $_.verdict -notin @('VERSION-READ','EXPORTED-BUT-NO-VERSION-STRING') })

Say ''
Say ("  VERSION READ {0} | NOT-OUR-BUILD (exported, no version string) {1} | UNRESOLVED {2}" -f `
     $read.Count, $notOurs.Count, $unres.Count)
if ($unres.Count -gt 0) {
    Say '  !! UNRESOLVED IS NOT AGREEMENT -- those tenants were not measured at all.'
}

# ---------------------------------------------------------------- the table
Say ''
Say ('  {0,-32} {1,-20} {2,-9} {3,-9} {4,-9} {5}' -f 'tenant','provider','MEASURED','LEDGER','REPO','verdict')
Say ('  ' + ('-' * 122))

$agree = 0; $ledgerDrift = 0; $behindRepo = 0; $noRecord = 0
foreach ($r in ($all | Sort-Object { $_.subdomain })) {
    $t    = $byId["$($r.deptId)"]
    $name = if ($r.subdomain) { $r.subdomain } elseif ($t) { $t.subdomain } else { 'dept ' + $r.deptId }
    $prov = if ($r.provider) { $r.provider } else { '-' }
    $meas = if ($r.version) { 'v' + $r.version } else { '-' }
    $led  = if ($t -and $t.ledgerVersion) { if ($t.ledgerVersion -eq 'NOT-OURS') { '(not ours)' } else { 'v' + $t.ledgerVersion } } else { '--' }
    $rep  = if ($r.provider -and $repoVer.ContainsKey($r.provider)) { 'v' + $repoVer[$r.provider] } else { '--' }

    $verdict = ''
    if ($r.verdict -eq 'EXPORTED-BUT-NO-VERSION-STRING') {
        # See refusal #2 -- absence of our convention is positive evidence.
        if ($t -and $t.ledgerVersion -eq 'NOT-OURS') { $verdict = 'CONFIRMS ledger: not our build'; $agree++ }
        else { $verdict = 'NOT OUR BUILD (no version string)' }
    }
    elseif ($r.verdict -ne 'VERSION-READ') {
        $verdict = 'UNRESOLVED -- ' + $r.verdict
    }
    else {
        $vs = @()
        if ($t -and $t.ledgerVersion -and $t.ledgerVersion -ne 'NOT-OURS') {
            if ($r.version -eq $t.ledgerVersion) { $vs += 'ledger OK' }
            else { $vs += ('*** LEDGER SAYS v' + $t.ledgerVersion + ' ***'); $ledgerDrift++ }
        } else { $vs += 'NO LEDGER ROW'; $noRecord++ }
        if ($rep -ne '--') {
            if (('v' + $r.version) -eq $rep) { $vs += 'repo OK' }
            else { $vs += 'behind repo'; $behindRepo++ }
        }
        if ($vs -notcontains 'NO LEDGER ROW' -and $vs -join ',' -eq 'ledger OK,repo OK') { $agree++ }
        $verdict = ($vs -join ' / ')
    }
    Say ('  {0,-32} {1,-20} {2,-9} {3,-9} {4,-9} {5}' -f $name, $prov, $meas, $led, $rep, $verdict)
}

Say ''
Say ("  fully agreeing {0} | LEDGER DRIFT {1} | behind repo {2} | measured but NO ledger row {3}" -f `
     $agree, $ledgerDrift, $behindRepo, $noRecord)
Say ''
Say '  A "behind repo" row is not automatically a defect -- a Foundation tenant is expected to'
Say '  lag until someone imports. A LEDGER DRIFT row is: the record and the tenant disagree.'
Say '  No platform counter is printed here; it is corroboration, never a version.'
Say '===================================================================================='
Say ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
