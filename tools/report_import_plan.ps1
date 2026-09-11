<#
  report_import_plan.ps1 -- WHAT WOULD AN IMPORT ACTUALLY CHANGE? Read-only, content-based.

  WHY THIS EXISTS. Rob, 2026-09-11: "then we need to have you generate json import plan either
  mass or single  i will drive that moving forward adn then have it automated at the sinlge
  click." This is step 4 of the roadmap and it is DELIBERATELY READ-ONLY: it names the work,
  it does not do it. Step 5 (the write path) is a separate decision -- `Import JSON` is on the
  extension's DESTRUCTIVE denylist by design.

  !! IT PLANS ON CONTENT, NOT ON LABELS, AND THAT CHANGES THE ANSWER. Our version rides in the
  DESCRIPTION of up to three bundles and imports are PER-BUNDLE, so a tenant routinely carries a
  stale label over current content. Measured 2026-09-11: planning off labels would have queued
  FOUR tenants that need nothing --
      usx-hi-hcjdc-ofml   label v4.19  content == repo v4.20   (ENTITIES label read first)
      usx-ny-nyspin-ejustice label v4.24  content == repo v4.26   (both bundles identical)
      ny-nycapss-foundation  label v4.24  content == repo v4.26
      usx-or-leds         label v2.5   content == repo v2.6
  Importing into those would be a no-op that archives a test package and burns a re-test cycle.
  So NOTHING lands in the queue unless its CONTENT differs from the repo build.

  !! AND THE COMPARISON NORMALIZES WHAT THE PLATFORM ADDS. It re-serializes on export, emitting
  "conditions":null / "defaults":null where our build omits the property. A raw byte compare
  reports a difference on every tenant, including ones that are perfectly current. All hashing
  goes through _bundle_identity.ps1 for exactly that reason -- and any future import-VERIFY step
  must use the same module or it will report failure on a successful import.

  !! SCOPE IS HONOURED AND PRINTED. Rob: "amyblair and onscene as well as a bunch of the others
  will be excluded at some point ... or only account for them seperatlye". Excluded tenants are
  reported in their OWN section with the reason, never dropped, and every count prints its
  denominator. A filtered plan that does not say what it filtered is how a tenant stops being
  anyone's problem without a decision.

  !! WHAT IT REFUSES TO DO
   1. It does NOT import, and contains no write path.
   2. It does NOT queue a tenant whose config is NOT OUR BUILD. Overwriting a config we did not
      author is a different decision from updating one we did, and needs a human.
   3. It does NOT queue on a label difference alone (see above).
   4. 0 tenant configs FAILS -- an empty plan must not read as "nothing to do".

  Usage:
    .\tools\report_import_plan.ps1
    .\tools\report_import_plan.ps1 -Provider HI_HCJDC_OFML
    .\tools\report_import_plan.ps1 -OutFile providers\IMPORT_PLAN.txt
#>

param(
    [string]$Provider,
    [string]$TenantDir,
    [switch]$IncludeDeactivated,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"
. "$PSScriptRoot\_tenant_scope.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

$tenantDir  = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
$rosterPath = Join-Path $PSScriptRoot 'config\tenant_roster.json'
$mapPath    = Join-Path $PSScriptRoot 'config\tenant_map.json'

Say ''
Say '===================================================================================='
Say '  IMPORT PLAN -- READ-ONLY. What an import would actually change, judged by CONTENT.'
Say '===================================================================================='

# ---------------------------------------------------------------- repo side
$repoVer = @{}; $repoHash = @{}
foreach ($d in Get-ChildItem (Join-Path $repoRoot 'providers') -Directory) {
    $j = @(Get-ChildItem $d.FullName -Filter "$($d.Name)_v*.json" -File -ErrorAction SilentlyContinue)
    if ($j.Count -ne 1) { continue }
    if ($j[0].Name -notmatch '_v([0-9]+\.[0-9]+)\.json$') { continue }
    $repoVer[$d.Name] = $Matches[1]
    $o = Get-Content $j[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($b in (Get-BundleList $o)) { $repoHash["$($d.Name)|$($b.name)"] = (Get-BundleContentHash $b) }
}
Say ("  repo builds resolved: {0} provider(s), {1} bundle hash(es)" -f $repoVer.Count, $repoHash.Count)

# ---------------------------------------------------------------- roster (status) + ledger
$status = @{}
if (Test-Path $rosterPath) {
    $r = Get-Content $rosterPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($t in @($r.tenants)) { $status["$($t.deptId)"] = "$($t.status)" }
}
$ledger = @{}
if (Test-Path $mapPath) {
    $m = Get-Content $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($t in @($m.tenants)) { $ledger["$($t.deptId)"] = $t }
}

# ---------------------------------------------------------------- tenant side
$files = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
Say ("  tenant configs on disk: {0}" -f $files.Count)
if ($files.Count -eq 0) {
    Say '  [FAIL] no tenant configs -- an EMPTY plan must not read as "nothing to do".'
    Say '         Pull them first: extension button 6b, then tools\ingest_tenant_configs.ps1'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 1
}

$rows = @()
foreach ($f in $files) {
    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    $bl = Get-BundleList $o
    if ($bl.Count -eq 0) { continue }
    $pb = @($bl | Where-Object { "$($_.name)" -ne 'ENTITIES' -and "$($_.name)" -ne 'RMS' })[0]
    if (-not $pb) { continue }
    $deptId = ($f.BaseName -replace '^.*_(\d+)$', '$1')
    $sub    = ($f.BaseName -replace '_\d+$', '')
    $lbl    = Get-BundleLabelVersion $pb
    $pn     = "$($pb.name)"

    # REFUSAL 2: a config we did not build is not ours to overwrite.
    if (-not $lbl) {
        $rows += [pscustomobject]@{ Sub=$sub; DeptId=$deptId; Provider=$pn; Label=$null
                                    RepoVer=$null; Verdict='NOT-OUR-BUILD'; Changed=@() }
        continue
    }
    if ($Provider -and $pn -ne $Provider) { continue }
    if (-not $repoVer.ContainsKey($pn)) {
        $rows += [pscustomobject]@{ Sub=$sub; DeptId=$deptId; Provider=$pn; Label=$lbl.Version
                                    RepoVer=$null; Verdict='NO-REPO-BUILD'; Changed=@() }
        continue
    }

    # Which bundles would actually change? Per-bundle, because imports are per-bundle.
    $changed = @()
    foreach ($b in $bl) {
        $k = "$pn|$($b.name)"
        if (-not $repoHash.ContainsKey($k)) { $changed += ("{0} (no repo counterpart)" -f $b.name); continue }
        if ((Get-BundleContentHash $b) -ne $repoHash[$k]) { $changed += "$($b.name)" }
    }
    $verdict = if ($changed.Count -eq 0) { 'CURRENT' } else { 'IMPORT WOULD CHANGE' }
    $rows += [pscustomobject]@{ Sub=$sub; DeptId=$deptId; Provider=$pn; Label=$lbl.Version
                                RepoVer=$repoVer[$pn]; Verdict=$verdict; Changed=$changed }
}

# deactivated filter (Rob: "we can filter out deavtivated tenants")
$deact = @()
if (-not $IncludeDeactivated) {
    $deact = @($rows | Where-Object { $status.ContainsKey($_.DeptId) -and $status[$_.DeptId] -match 'DEACTIVATED' })
    if ($deact.Count -gt 0) { $rows = @($rows | Where-Object { $deact -notcontains $_ }) }
}

# scope partition
$split   = Split-TenantsByScope $rows 'DeptId'
$inScope = @($split.InScope)
$exRows  = @($split.Excluded)

$queue   = @($inScope | Where-Object { $_.Verdict -eq 'IMPORT WOULD CHANGE' })
$current = @($inScope | Where-Object { $_.Verdict -eq 'CURRENT' })
$notOurs = @($inScope | Where-Object { $_.Verdict -eq 'NOT-OUR-BUILD' })
$noRepo  = @($inScope | Where-Object { $_.Verdict -eq 'NO-REPO-BUILD' })

Say ''
Say ("  CURRENT {0} | *** IMPORT QUEUE {1} *** | not our build {2} | no repo build {3}" -f `
     $current.Count, $queue.Count, $notOurs.Count, $noRepo.Count)
if ($deact.Count -gt 0) { Say ("  (+{0} DEACTIVATED filtered out; -IncludeDeactivated to see them)" -f $deact.Count) }

# ---------------------------------------------------------------- the queue
Say ''
Say '  ---- THE QUEUE: content differs from the repo build ------------------------------'
if ($queue.Count -eq 0) {
    Say '  EMPTY -- every in-scope tenant running one of our builds is content-identical to the'
    Say '  repo. Note this is NOT the same as "every label matches": labels go stale on a'
    Say '  bundle whose content did not change between versions.'
} else {
    Say ('  {0,-28} {1,-20} {2,-8} {3,-8} {4}' -f 'TENANT','PROVIDER','LABEL','TARGET','BUNDLES THAT WOULD CHANGE')
    Say ('  ' + ('-' * 108))
    foreach ($q in ($queue | Sort-Object Provider, Sub)) {
        $st = if ($status.ContainsKey($q.DeptId) -and $status[$q.DeptId] -match 'LIVE') { '  [LIVE]' } else { '' }
        Say ('  {0,-28} {1,-20} v{2,-7} v{3,-7} {4}{5}' -f $q.Sub, $q.Provider, $q.Label, $q.RepoVer, ($q.Changed -join ', '), $st)
        $l = $ledger[$q.DeptId]
        if ($l -and $l.ledgerName) { Say ("       ledger: {0}{1}" -f $l.ledgerName, $(if ($l.ledgerVersion) { " claims v$($l.ledgerVersion)" } else { '' })) }
    }
    Say ''
    Say '  ACCEPTANCE TEST for each row, once an import is actually performed:'
    Say '    1. re-export the tenant (button 6b with only that deptId) and re-ingest;'
    Say '    2. the PROVIDER bundle description must then read "v<TARGET>"; and'
    Say '    3. its CONTENT HASH must equal the repo build (_bundle_identity.ps1).'
    Say '  Step 3 is the one that matters: step 2 alone passes on a label-only change, and a'
    Say '  RAW byte compare FAILS on a correct import because the platform re-serializes.'
}

# ---------------------------------------------------------------- everything else, accounted for
if ($notOurs.Count -gt 0) {
    Say ''
    Say '  ---- NOT OUR BUILD -- deliberately NOT queued ------------------------------------'
    Say '  No "Provider configuration for <P> vX.Y" description, and content matching no build'
    Say '  of ours. Overwriting a config we did not author is a DIFFERENT decision from updating'
    Say '  one we did, so these need a human, not a queue entry.'
    foreach ($n in ($notOurs | Sort-Object Sub)) { Say ('     {0,-28} bundle {1}' -f $n.Sub, $n.Provider) }
}
if ($noRepo.Count -gt 0) {
    Say ''
    Say '  ---- LABELLED AS OURS BUT NO CURRENT REPO BUILD ----------------------------------'
    foreach ($n in ($noRepo | Sort-Object Sub)) { Say ('     {0,-28} {1} v{2}' -f $n.Sub, $n.Provider, $n.Label) }
    Say '  (e.g. a pre-rename provider name -- usx-la-lems carries LA_LETTS_OFML, retired.)'
}

Say ''
foreach ($l in (Get-ScopeFooterLines $inScope.Count $exRows)) { Say $l }

Say ''
Say '  READ-ONLY: this tool names the work and contains no import path. `Import JSON` is on the'
Say '  extension DESTRUCTIVE denylist by design; automating it is a separate decision (step 5).'
Say '===================================================================================='
Say ''
if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
exit 0
