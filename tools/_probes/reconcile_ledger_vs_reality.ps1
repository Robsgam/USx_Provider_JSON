<#
  reconcile_ledger_vs_reality.ps1 -- WHAT OUR RECORDS SAY vs WHAT THE PLATFORM ACTUALLY HAS

  WHY THIS EXISTS. Rob, 2026-09-10, and again on 2026-09-11 after I had buried the answer
  under process detail:
    "i need a list of all deployed providers with one column that shows what our records
     show and the other column with everything we discovvered today"
  He asked twice. A question asked twice is a tool, not a paragraph.

  THREE INPUTS, ALL DERIVED -- nothing in this file is hand-transcribed:
    1. tools/config/tenant_map.json    the subdomain <-> deptId <-> ledgerName/ledgerVersion join
                                       (deptId is the ONLY stable key; subdomains get renamed and
                                        the ledger uses prose names -- "HDLE LIVE" is `hawaii-dle`)
    2. the newest usx_admin_versions_*.json   the MEASURED version, read from each tenant's own
                                       Export JSON (our version rides in the bundle description)
    3. providers/<P>/logs/<P>_v*.txt   the log-derived version for our own usx-* fleet tenants,
                                       which is what IMPORT_LEDGER section A means by "installed"

  !! WHAT IT REFUSES TO CONFLATE:
   1. "NO RECORD" is a FINDING, not a blank. A tenant running our build with no ledger row is
      the whole point of the exercise.
   2. ABSENCE OF OUR VERSION STRING IS EVIDENCE. Every build we produce carries
      "Provider configuration for <P> vX.Y" in the bundle description. A tenant whose export
      has no such string is running a config WE DID NOT BUILD -- reported NOT-OUR-BUILD, which
      is how Lafayette was confirmed as the hand-built engineering JSON.
   3. A PLATFORM COUNTER IS NOT A VERSION. The bundle table's Version column is a platform
      counter (eSUN reads 590/48/70 at v3.3). Never printed here as a version.
   4. 0 INPUTS FAILS. "found nothing" and "never looked" are different verdicts (ENG STD 4.3),
      so it prints its denominators and exits 1 rather than emitting an empty clean-looking table.

  Usage:
    .\tools\_probes\reconcile_ledger_vs_reality.ps1
    .\tools\_probes\reconcile_ledger_vs_reality.ps1 -OutFile providers\LEDGER_VS_REALITY.txt
#>

param(
    [string]$VersionsDir,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$lines = @()
function Say([string]$s) { $script:lines += $s; Write-Host $s }

# Which provider does a `usx-*` fleet tenant EXIST FOR? Rob 2026-09-10: "the tenant naming
# conventions are not intuative". `usx-nm-nmlets` is NM_NMLETS_OFML and `usx-la-lems` is LA_LEMS,
# so an equality test fails on both -- match on the normalized prefix in EITHER direction, and
# REFUSE to answer when two providers match rather than picking one (the alphabetical-glob
# failure that made a gate read the wrong metadata file and report green).
function Resolve-FleetProvider([string]$subdomain, $providerNames) {
    $tok = ($subdomain -replace '^usx-?', '') -replace '-', '_'
    if (-not $tok) { return $null }
    $tok = $tok.ToUpperInvariant()
    $hits = @($providerNames | Where-Object { $_ -eq $tok })
    if ($hits.Count -eq 1) { return $hits[0] }
    $hits = @($providerNames | Where-Object { $_.StartsWith($tok) -or $tok.StartsWith($_) })
    if ($hits.Count -eq 1) { return $hits[0] }
    return $null        # 0 = unknown, 2+ = ambiguous. Both are reported, never guessed.
}

# ---------------------------------------------------------------- input 1: the join
$mapPath = Join-Path $repoRoot 'tools\config\tenant_map.json'
if (-not (Test-Path $mapPath)) {
    Say '  [FAIL] tools/config/tenant_map.json missing -- every tenant would read as unrecorded.'
    exit 1
}
$map = Get-Content $mapPath -Raw | ConvertFrom-Json
$tenants = @($map.tenants)

# ---------------------------------------------------------------- input 2: measured versions
$srcDir = if ($VersionsDir) { $VersionsDir } else { Join-Path $env:USERPROFILE 'Downloads' }
$vfiles = @(Get-ChildItem $srcDir -Filter 'usx_admin_versions_*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime)
$measured = @{}
foreach ($f in $vfiles) {
    $o = Get-Content $f.FullName -Raw | ConvertFrom-Json
    foreach ($r in @($o.results)) { $measured["$($r.deptId)"] = $r }   # last write wins
}

# ---------------------------------------------------------------- input 3: repo + log-derived
$repoVer = @{}; $logVer = @{}
foreach ($d in Get-ChildItem (Join-Path $repoRoot 'providers') -Directory) {
    $p = $d.Name
    $j = @(Get-ChildItem $d.FullName -Filter "$p`_v*.json" -File -ErrorAction SilentlyContinue)
    if ($j.Count -eq 1 -and $j[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$p] = $Matches[1] }
    $logDir = Join-Path $d.FullName 'logs'
    if (Test-Path $logDir) {
        $vs = @(Get-ChildItem $logDir -Recurse -Filter "$p`_v*.txt" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '_archive' } |
                ForEach-Object { if ($_.Name -match '_v([0-9]+\.[0-9]+)_') { $Matches[1] } } |
                Sort-Object -Unique)
        if ($vs.Count -gt 0) { $logVer[$p] = ($vs -join ',') }
    }
}

Say ''
Say '===================================================================================='
Say '  OUR RECORDS  vs  WHAT IS ACTUALLY DEPLOYED'
Say '===================================================================================='
Say ("  tenants in the join: {0}   version files read: {1}   tenants measured: {2}   providers in repo: {3}" -f `
     $tenants.Count, $vfiles.Count, $measured.Count, $repoVer.Count)

if ($tenants.Count -eq 0 -or $measured.Count -eq 0) {
    Say '  [FAIL] a denominator is zero -- this run says NOTHING. Refusing to print a clean table.'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

# ================================================================ PER-TENANT
Say ''
Say '  ---- PER TENANT -------------------------------------------------------------------'
Say ('  {0,-30} {1,-34} {2,-26} {3}' -f 'TENANT', 'OUR RECORDS SAY', 'REALITY (measured)', 'VERDICT')
Say ('  ' + ('-' * 128))

$nRecorded = 0; $nUnrecorded = 0; $agree = 0; $drift = 0; $notOurs = 0; $behind = 0
$rows = @()
foreach ($t in ($tenants | Sort-Object { $_.subdomain })) {
    $id = "$($t.deptId)"
    $m  = $measured[$id]

    # --- OUR RECORDS column
    $isFleet = ($t.class -eq 'usx-fleet')
    if ($t.ledgerName) {
        $rec = "$($t.ledgerName)"
        if ($t.ledgerVersion -eq 'NOT-OURS') { $recVer = '(not ours)' }
        elseif ($t.ledgerVersion)            { $recVer = 'v' + $t.ledgerVersion }
        else                                 { $recVer = '(no version)' }
        $nRecorded++
    } elseif ($isFleet) {
        # ⚠️ DO NOT look up logs by the MEASURED provider. usx-fl-fcic exports a CA_eSUN bundle
        # with no version string, so the measured provider is $null and the lookup silently
        # returned "(no logs)" for a provider holding 104 committed logs -- a FALSE statement in
        # the column headed "our records say". A fleet tenant's OWED provider comes from which
        # tenant it IS, never from what happens to be installed on it today.
        $prov = Resolve-FleetProvider $t.subdomain $repoVer.Keys
        $rec  = if ($prov) { "Section A: $prov" } else { 'Section A (provider UNMATCHED)' }
        if     (-not $prov)                 { $recVer = '(cannot name provider)' }
        elseif ($logVer.ContainsKey($prov)) { $recVer = 'v' + $logVer[$prov] + ' logged' }
        else                                { $recVer = 'NEVER TESTED (0 logs)' }
        $nRecorded++
    } else {
        $rec = '*** NO RECORD ***'; $recVer = '--'
        $nUnrecorded++
    }

    # --- REALITY column
    if (-not $m) { $realV = '(not swept)'; $realP = '-' ; $verdict = 'UNMEASURED' }
    elseif ($m.verdict -eq 'VERSION-READ') { $realP = $m.provider; $realV = 'v' + $m.version; $verdict = '' }
    elseif ($m.verdict -eq 'EXPORTED-BUT-NO-VERSION-STRING') { $realP = '-'; $realV = 'no version string'; $verdict = 'NOT OUR BUILD' }
    else { $realP = '-'; $realV = $m.verdict; $verdict = 'UNRESOLVED' }

    # --- VERDICT
    if ($verdict -eq '') {
        $bits = @()
        if ($t.ledgerVersion -and $t.ledgerVersion -ne 'NOT-OURS') {
            if ($m.version -eq $t.ledgerVersion) { $bits += 'ledger OK' } else { $bits += ('LEDGER SAYS v' + $t.ledgerVersion); $drift++ }
        } elseif ($isFleet) {
            if ($logVer.ContainsKey($m.provider) -and $logVer[$m.provider] -ne $m.version) {
                $bits += ('LOGS CLAIM v' + $logVer[$m.provider]); $drift++
            } else { $bits += 'logs OK' }
        } else { $bits += 'UNRECORDED INSTALL' }
        if ($repoVer.ContainsKey($m.provider)) {
            if ($repoVer[$m.provider] -eq $m.version) { $bits += 'repo current' } else { $bits += 'behind repo v' + $repoVer[$m.provider]; $behind++ }
        }
        $verdict = ($bits -join ' / ')
        if ($verdict -eq 'ledger OK / repo current' -or $verdict -eq 'logs OK / repo current') { $agree++ }
    } elseif ($verdict -eq 'NOT OUR BUILD') {
        $notOurs++
        if ($t.ledgerVersion -eq 'NOT-OURS') { $verdict = 'CONFIRMS ledger: not ours' }
        elseif (-not $t.ledgerName -and -not $isFleet) { $verdict = 'not ours, and unrecorded' }
    }

    Say ('  {0,-30} {1,-34} {2,-26} {3}' -f $t.subdomain, ($rec + ' ' + $recVer), ($realP + ' ' + $realV), $verdict)
    $rows += [pscustomobject]@{ Sub=$t.subdomain; Prov=$(if($m){$m.provider}else{$null}); Ver=$(if($m){$m.version}else{$null}); Recorded=($t.ledgerName -or $isFleet) }
}

Say ''
Say ("  RECORDED {0} | *** UNRECORDED {1} *** | fully agreeing {2} | DRIFT {3} | behind repo {4} | not our build {5}" -f `
     $nRecorded, $nUnrecorded, $agree, $drift, $behind, $notOurs)

# ================================================================ PER-PROVIDER
Say ''
Say '  ---- PER PROVIDER: how many installs we recorded vs how many exist ---------------'
Say ('  {0,-22} {1,-8} {2,-28} {3}' -f 'PROVIDER', 'REPO', 'OUR RECORDS (n + versions)', 'REALITY (n + versions)')
Say ('  ' + ('-' * 110))

$provs = @($rows | Where-Object { $_.Prov } | Select-Object -ExpandProperty Prov | Sort-Object -Unique)
foreach ($p in $provs) {
    $mine  = @($rows | Where-Object { $_.Prov -eq $p })
    $recN  = @($mine | Where-Object { $_.Recorded }).Count
    $allN  = $mine.Count
    $vers  = (@($mine | Select-Object -ExpandProperty Ver | Sort-Object -Unique) | ForEach-Object { 'v' + $_ }) -join ' '
    $rv    = if ($repoVer.ContainsKey($p)) { 'v' + $repoVer[$p] } else { '--' }
    $flag  = if ($allN -gt $recN) { ('  <== +' + ($allN - $recN) + ' NOT RECORDED') } else { '' }
    Say ('  {0,-22} {1,-8} {2,-28} {3}{4}' -f $p, $rv, ("$recN tenant(s)"), ("$allN tenant(s): $vers"), $flag)
}

$noVer = @($tenants | Where-Object { $measured["$($_.deptId)"] -and $measured["$($_.deptId)"].verdict -eq 'EXPORTED-BUT-NO-VERSION-STRING' })
Say ''
Say ("  Plus {0} tenant(s) carrying a provider bundle with NO version string = NOT OUR BUILD." -f $noVer.Count)
Say '  Those are counted in neither column above, because they are not deployments of ours.'

if (@($map._unlocated).Count -gt 0) {
    Say ''
    Say '  ---- THE REVERSE GAP: ledger rows matching NO tenant on this host ---------------'
    foreach ($u in @($map._unlocated)) { Say ("    {0,-34} {1,-20} {2}" -f $u.ledgerName, $u.provider, $u.claimed) }
}

Say ''
Say '  NOTE: no platform counter appears above. The bundle table Version column is a platform'
Say '        counter, not our version; our version rides in the bundle description.'
Say '===================================================================================='
Say ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII; Write-Host "saved: $OutFile" }
exit 0
