# PROBE: dead-fill / impossible-search sweep.
#   P1 (TN_TIES KQ.N shape): a combo gated `<State> EXISTS` whose search becomes IMPOSSIBLE when
#       no State is typed -- because nothing else takes the fill.
#   P2 (MD_METERS v2.3 shape): any `X NOT_EXISTS` gate where filling that combo's set[] PLUS X
#       makes NOTHING fire -- officer types legitimate fields, no query is sent.
# Reuses the canonical routing walk (tools/_sim_helpers.ps1 Get-FiringKeyRef). Does not reimplement it.
param([string[]]$Providers, [string]$Path, [switch]$Quiet)
$ErrorActionPreference='Stop'
$repo = 'C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON'
. "$repo\tools\_sim_helpers.ps1"
. "$repo\tools\_resolve_provider_json.ps1"

function Get-FormPrefills($cfg) {
    # hidden/visible controls carrying an initialValue are ALWAYS present -- must be in formData.
    $pf = @{}
    if (-not $cfg.layout) { return $pf }
    foreach ($vp in $cfg.layout.PSObject.Properties) {
        foreach ($np in $vp.Value.PSObject.Properties) {
            $n = $np.Value
            if ($n.props -and $n.props.fieldId -and "$($n.props.initialValue)" -ne '') {
                $pf[[string]$n.props.fieldId] = [string]$n.props.initialValue
            }
        }
    }
    return $pf
}

function Get-Stateish($f) { return ($f -match '(?i)^(registration)?state(dh)?\d*$') }

$rows = @()
$provDirs = if ($Path) { @((Get-Item $Path).Directory) }
            elseif ($Providers) { $Providers | ForEach-Object { Get-Item "$repo\providers\$_" } }
            else { Get-ChildItem "$repo\providers" -Directory | Where-Object { Test-Path (Join-Path $_.FullName "scripts") } }

$examined = 0; $combosSeen = 0; $fillsRun = 0
foreach ($pd in $provDirs) {
    $p = $pd.Name
    $json = if ($Path) { $Path } else { Get-ProviderRootJson -ProvDir $pd.FullName -Provider $pd.Name }
    if (-not $json -or -not (Test-Path $json)) { "  [SKIP] $p -- no active JSON"; continue }
    $j = Get-Content $json -Raw | ConvertFrom-Json
    $examined++

    # entity -> QIDMs (in bundle/array order); entity -> merged form prefills
    $byEnt = @{}; $prefByEnt = @{}
    foreach ($b in $j.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.targetEntity -and $b.provider -ne 'RMS') {
            if (-not $byEnt[$c.targetEntity]) { $byEnt[$c.targetEntity] = @() }
            $byEnt[$c.targetEntity] += $c
        }
        if ($c.type -eq 'QUERYINPUTFORM' -and $c.targetEntity) {
            $prefByEnt[$c.targetEntity] = Get-FormPrefills $c
        }
    } }

    foreach ($ent in $byEnt.Keys) {
        $qidms = $byEnt[$ent]
        $pref  = if ($prefByEnt[$ent]) { $prefByEnt[$ent] } else { @{} }
        # every field named in a NOT_EXISTS condition on this entity = a candidate extra fill
        $notExistsFields = @()
        foreach ($q in $qidms) { foreach ($c in $q.combinations) {
            foreach ($cond in (Get-ComboConditions $c)) {
                if ("$($cond.operator)" -match '(?i)NOT_EXISTS') { $notExistsFields += @($cond.field) }
            }
        } }
        $notExistsFields = $notExistsFields | Where-Object { $_ } | Select-Object -Unique

        foreach ($q in $qidms) {
          foreach ($c in $q.combinations) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $set = @($c.requirements.set | Where-Object { $_ })
            if ($set.Count -eq 0) { continue }
            $combosSeen++
            $conds = Get-ComboConditions $c

            # ---- base fill: exactly this combo's set[] (+ form prefills) ----
            $base = @{}; foreach ($k in $pref.Keys) { $base[$k] = $pref[$k] }
            foreach ($f in $set) { $base[$f] = 'X' }

            # ---- P1: gated `State EXISTS` -> is the SAME search reachable with NO state? ----
            foreach ($cond in $conds) {
                foreach ($cf in @($cond.field)) {
                    if (-not (Get-Stateish $cf)) { continue }
                    $op = "$($cond.operator)"
                    $f2 = @{}; foreach ($k in $base.Keys) { $f2[$k] = $base[$k] }
                    if ($op -match '(?i)^EXISTS') {
                        $f2.Remove($cf) | Out-Null            # officer types no state
                        $label = "in-state (no $cf)"
                    } else {
                        $f2[$cf] = 'VA'                        # officer types a state
                        $label = "out-of-state (+$cf)"
                    }
                    $fillsRun++
                    $fired = Get-FiringKeyRef $qidms $f2
                    if (-not $fired) {
                        $rows += [pscustomobject]@{ Provider=$p; Class='P1 STATE-GATE'; Entity=$ent
                          Query=$q.query; KeyRef=$kr; Detail="$label -> NOTHING FIRES  [set: $($set -join '+')]" }
                    }
                }
            }

            # ---- P2: this combo's set[] PLUS one more legitimate field -> dead? ----
            foreach ($x in $notExistsFields) {
                if ($set -contains $x) { continue }
                if ($base.ContainsKey($x)) { continue }        # already prefilled: not an officer choice
                $f2 = @{}; foreach ($k in $base.Keys) { $f2[$k] = $base[$k] }
                $f2[$x] = 'X'
                $fillsRun++
                if (-not (Get-FiringKeyRef $qidms $f2)) {
                    $rows += [pscustomobject]@{ Provider=$p; Class='P2 DEAD-FILL'; Entity=$ent
                      Query=$q.query; KeyRef=$kr; Detail="set[$($set -join '+')] + $x -> NOTHING FIRES" }
                }
            }
          }
        }
    }
}

"";"  DEAD-FILL / IMPOSSIBLE-SEARCH SWEEP"
"  EXAMINED: $examined provider(s) / $combosSeen combo(s) / $fillsRun simulated fill(s)"
"  ------------------------------------------------------------"
if ($fillsRun -eq 0) { "  [NO-VERDICT] zero fills simulated -- the probe compared NOTHING"; exit 2 }
if ($rows.Count -eq 0) { "  [PASS] no dead fill and no impossible state-gated search found"; exit 0 }
$rows = $rows | Sort-Object Provider,Entity,KeyRef,Class | Group-Object Provider,Entity,KeyRef,{ ($_.Detail -replace "^[^[]*","") } | ForEach-Object { $_.Group[0] }
$provCount = @($rows | Group-Object Provider).Count
$rows | Group-Object Provider | Sort-Object Name | ForEach-Object {
    "  ### $($_.Name)  ($($_.Group.Count))"
    $_.Group | ForEach-Object { "      [$($_.Class)] $($_.Entity)/$($_.Query) $($_.KeyRef): $($_.Detail)" }
}
"  ------------------------------------------------------------"
"  TOTAL: $($rows.Count) finding(s) across $provCount provider(s)"
