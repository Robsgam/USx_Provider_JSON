<#
  ingest_tenant_scan.ps1 -- WHICH TENANTS HAVE A PROVIDER JSON WE DO NOT KNOW ABOUT?

  WHY THIS EXISTS (Rob, 2026-09-10, restating the goal after I had narrowed it twice):
    "the goal is to uncover any json imports that we do not know about"
  Not verifying the 11 tenants the ledger already names -- FINDING THE ONES IT DOES NOT.

  INPUT: the chunk files written by the extension's full census (⑦ / runFullScan),
  `usx_admin_scan_<from>-<to>_*.json`. Each holds one department per row with the bundle
  table read from a hidden iframe (a fetch returns it EMPTY -- see TENANT_INVENTORY.md).

  WHAT IT CLASSIFIES. A tenant carrying a bundle that is neither ENTITIES nor RMS has a
  PROVIDER JSON installed. Every such tenant is then one of:
    KNOWN-FLEET     subdomain starts `usx-`         -- our own provider test tenants
    KNOWN-LEDGER    deptId is in IMPORT_LEDGER section B
    *** UNKNOWN ***  everything else                -- THE ANSWER TO ROB'S QUESTION
  and separately, any bundle NAME that is not one of our 20 providers is called out, because
  an unrecognised provider name is its own finding.

  !! THREE THINGS IT REFUSES TO CONFLATE, each of which has already caused a wrong answer
  today:
   1. UNRESOLVED IS NOT EMPTY. A configuration page that did not fill within the iframe wait
      budget has NOT been shown to lack a provider. Counted and reported separately; a run
      with unresolved rows CANNOT support "these are all the imports".
   2. A MISSING CHUNK IS NOT AN EMPTY RANGE. The census writes one file per index range; if
      a range is absent the tool says which offsets are missing rather than reporting on a
      partial fleet as though it were the fleet.
   3. NO VERSION IS CLAIMED HERE. This phase reads the bundle TABLE, whose Version column is
      a platform counter, not ours. Versions come from ingest_tenant_export.ps1 (the Export
      JSON control). Do not read a counter as a version.

  Usage:
    .\tools\ingest_tenant_scan.ps1                 # all chunk files in Downloads
    .\tools\ingest_tenant_scan.ps1 -Path <dir>
    .\tools\ingest_tenant_scan.ps1 -OutFile providers\TENANT_SCAN_REPORT.txt
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

# Our 20 provider names, derived from the repo rather than typed, plus the pre-rename name
# that is genuinely live on a tenant (usx-la-lems carries LA_LETTS_OFML).
$ourProviders = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Select-Object -ExpandProperty Name)
$legacyNames  = @('LA_LETTS_OFML')
$knownNames   = @($ourProviders + $legacyNames)

# IMPORT_LEDGER section B, located in the 1785-row index on 2026-09-10. Kept as data with a
# provenance note; re-derive by searching a fresh index rather than trusting this list blind.
$ledgerIds = @{
  '68055618928' = 'Newark Foundation'
  '65003603844' = 'Bert Anzini USx test tenant'
  '68086125887' = 'Miami Springs Foundation'
  '67633161477' = 'North Miami Foundation'
  '69669966842' = 'Homestead Foundation'
  '69189298576' = 'Balcones Heights TX Foundation'
  '54721427755' = 'HDLE Foundation'
  '55074106416' = 'Mariposa Foundation'
  '57528255873' = 'Mariposa LIVE'
  '66323459475' = 'Aurora Foundation'
  '20032392972' = 'Lafayette Parish (hand-built, not ours)'
}

$srcDir = if ($Path) { $Path } else { Join-Path $env:USERPROFILE 'Downloads' }
$files = @(Get-ChildItem $srcDir -Filter 'usx_admin_scan_*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)

Say ''
Say '===================================================================================='
Say '  TENANT CENSUS -> PROVIDER JSONS WE DO NOT KNOW ABOUT'
Say '===================================================================================='

if ($files.Count -eq 0) {
    Say "  [FAIL] no usx_admin_scan_*.json in $srcDir"
    Say '         0 chunks examined -- this run says NOTHING about any tenant.'
    Say '         Run the panel census first; it writes one file per chunk.'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

$rows = @(); $ranges = @(); $indexTotal = 0
foreach ($f in $files) {
    $o = Get-Content $f.FullName -Raw | ConvertFrom-Json
    if ($o.indexTotal) { $indexTotal = [int]$o.indexTotal }
    $ranges += [pscustomobject]@{ From = [int]$o.range.from; To = [int]$o.range.to; File = $f.Name; Count = @($o.results).Count }
    foreach ($r in @($o.results)) { $rows += $r }
}

Say ("  chunk files: {0}   rows: {1}   index total reported by the census: {2}" -f $files.Count, $rows.Count, $indexTotal)

# -- COVERAGE FIRST. A partial census cannot answer "these are all the imports". --
$covered = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($rg in $ranges) { for ($i = $rg.From; $i -le $rg.To; $i++) { [void]$covered.Add($i) } }
$missing = @()
if ($indexTotal -gt 0) { for ($i = 0; $i -lt $indexTotal; $i++) { if (-not $covered.Contains($i)) { $missing += $i } } }
if ($missing.Count -gt 0) {
    # Report as compact ranges, not 1500 integers.
    $mr = @(); $start = $missing[0]; $prev = $missing[0]
    for ($i = 1; $i -lt $missing.Count; $i++) {
        if ($missing[$i] -ne $prev + 1) { $mr += "$start-$prev"; $start = $missing[$i] }
        $prev = $missing[$i]
    }
    $mr += "$start-$prev"
    Say ("  !! INCOMPLETE CENSUS -- {0} index offset(s) NOT covered: {1}" -f $missing.Count, ($mr -join ', '))
    Say '     Re-run the census with `from` set to a missing offset. Findings below are still'
    Say '     valid for what WAS scanned, but this run cannot support "that is all of them".'
} elseif ($indexTotal -gt 0) {
    Say ("  OK COMPLETE: all {0} index offsets covered." -f $indexTotal)
}

$unresolved = @($rows | Where-Object { $_.verdict -eq 'NO-ROWS-WITHIN-BUDGET' })
$errored    = @($rows | Where-Object { $_.verdict -eq 'ERROR' })
$withProv   = @($rows | Where-Object { @($_.providerBundles).Count -gt 0 })

Say ''
Say ("  scanned {0} | with a provider bundle {1} | no provider {2} | UNRESOLVED {3} | errored {4}" -f `
     $rows.Count, $withProv.Count, ($rows.Count - $withProv.Count - $unresolved.Count - $errored.Count), $unresolved.Count, $errored.Count)
if ($unresolved.Count -gt 0) {
    Say '  !! UNRESOLVED IS NOT "NO PROVIDER" -- those pages did not fill in time and are UNKNOWN.'
}

# -- THE ANSWER --
$unknown = @(); $knownFleet = 0; $knownLedger = 0
foreach ($r in $withProv) {
    $sub = "$($r.subdomain)"
    if ($sub -like 'usx-*' -or $sub -eq 'usx') { $knownFleet++; continue }
    if ($ledgerIds.ContainsKey("$($r.deptId)")) { $knownLedger++; continue }
    $unknown += $r
}

Say ''
Say ("  KNOWN-FLEET (usx-*): {0}    KNOWN-LEDGER (section B): {1}    *** UNKNOWN: {2} ***" -f $knownFleet, $knownLedger, $unknown.Count)
Say ''
if ($unknown.Count -eq 0) {
    Say '  RESULT: no provider JSON found on any tenant outside our records.'
} else {
    Say '  RESULT: PROVIDER JSONS ON TENANTS WE HAVE NO RECORD OF ------------------------'
    Say ('    {0,-36} {1,-14} {2,-22} {3}' -f 'subdomain', 'deptId', 'status', 'provider bundle(s)')
    foreach ($u in ($unknown | Sort-Object subdomain)) {
        $b = (@($u.providerBundles) | ForEach-Object { $_.name + '/' + $_.platformCounter }) -join '  '
        Say ('    {0,-36} {1,-14} {2,-22} {3}' -f $u.subdomain, $u.deptId, $u.status, $b)
    }
}

# Unrecognised provider NAMES are a separate finding from unrecognised tenants.
$allNames = @()
foreach ($r in $withProv) { foreach ($b in @($r.providerBundles)) { $allNames += $b.name } }
$strangers = @($allNames | Sort-Object -Unique | Where-Object { $knownNames -notcontains $_ })
Say ''
if ($strangers.Count -eq 0) {
    Say ("  Every provider bundle name seen is one of ours ({0} distinct)." -f (@($allNames | Sort-Object -Unique)).Count)
} else {
    Say '  !! BUNDLE NAMES THAT ARE NOT OURS (an unrecognised provider is its own finding):'
    foreach ($s in $strangers) {
        $who = @($withProv | Where-Object { @($_.providerBundles).name -contains $s } | Select-Object -ExpandProperty subdomain) -join ', '
        Say ("     {0,-24} on: {1}" -f $s, $who)
    }
}

Say ''
Say '  NOTE: no version is claimed here -- this phase reads the bundle TABLE, whose Version'
Say '        column is a PLATFORM COUNTER. For real versions run ingest_tenant_export.ps1.'
Say '===================================================================================='
Say ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
