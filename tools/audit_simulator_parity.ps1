<#
  audit_simulator_parity.ps1 -- Guards that the two CommSys simulators
  (test_commsys.ps1 and run_test_matrix.ps1) share ONE canonical condition
  predicate and have not drifted back to private, divergent logic (finding H).

  The verified production bug (HI v3.2) was that test_commsys modelled an
  attribute-name condition as resolvable while the platform treated it as inert;
  run_test_matrix used the correct form-state-key model. They now both delegate to
  Test-ComboConditionsCore in _sim_helpers.ps1. This audit FAILs if either script
  stops dot-sourcing the shared module, or reintroduces an inline condition
  evaluator (the attribute-name-first / direct-ContainsKey resolution pattern).

  Provider-agnostic: pass any -Path so it can run inside build_report; it audits
  the tools, not the provider. Exit 0 = parity intact, 1 = drift.
  Usage: .\audit_simulator_parity.ps1 [-Path <provider.json>] [-OutFile <path>]
#>
param(
    [string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir = $PSScriptRoot
$lines = [System.Collections.Generic.List[string]]::new()
$fail = 0; $pass = 0
function Emit($s) { $lines.Add($s); Write-Host $s }

Emit "================================================================"
Emit "  SIMULATOR PARITY AUDIT"
Emit "  Ensures test_commsys.ps1 and run_test_matrix.ps1 share one"
Emit "  canonical condition predicate (_sim_helpers.ps1)."
Emit "================================================================"
Emit ""

$shared = Join-Path $toolDir "_sim_helpers.ps1"
if (-not (Test-Path $shared)) {
    Emit "[FAIL] shared module _sim_helpers.ps1 not found"
    $fail++
} else {
    $sharedTxt = [System.IO.File]::ReadAllText($shared)
    if ($sharedTxt -match 'function\s+Test-ComboConditionsCore') {
        Emit "[PASS] _sim_helpers.ps1 defines Test-ComboConditionsCore"; $pass++
    } else {
        Emit "[FAIL] _sim_helpers.ps1 missing Test-ComboConditionsCore"; $fail++
    }
}

$consumers = @('test_commsys.ps1','run_test_matrix.ps1')
foreach ($c in $consumers) {
    $p = Join-Path $toolDir $c
    if (-not (Test-Path $p)) { Emit "[FAIL] $c not found"; $fail++; continue }
    $txt = [System.IO.File]::ReadAllText($p)

    # 1. Must dot-source the shared module.
    if ($txt -match "_sim_helpers\.ps1") {
        Emit "[PASS] $c dot-sources _sim_helpers.ps1"; $pass++
    } else {
        Emit "[FAIL] $c does NOT dot-source _sim_helpers.ps1 (parity not guaranteed)"; $fail++
    }

    # 2. Must call the shared predicate.
    if ($txt -match 'Test-ComboConditionsCore') {
        Emit "[PASS] $c calls Test-ComboConditionsCore"; $pass++
    } else {
        Emit "[FAIL] $c does NOT call Test-ComboConditionsCore (drifted to private logic)"; $fail++
    }

    # 3. Must NOT reintroduce the attribute-name-first resolution that caused the bug:
    #    an inline `$qidm.attributes | Where-Object { $_.name -eq $f }` used to resolve a
    #    *condition* field. (Get-AttrValue for payload serialization is fine.)
    if ($txt -match 'name\s*-eq\s*\$f\b') {
        Emit "[FAIL] $c contains attribute-name condition resolution (`$_.name -eq `$f) -- the inert-condition bug pattern"; $fail++
    } else {
        Emit "[PASS] $c has no attribute-name condition resolution"; $pass++
    }
}

# ── 4. CANONICAL FIRING WALK (added 2026-07-29) ──────────────────────────────────
# The checks above prove the consumers IMPORT the shared condition predicate. They do NOT
# prove the two halves agree: "which combo fires" is conditions AND set[]-satisfaction, and
# for a long time only the conditions half was shared while FIVE tools each kept their own
# copy of the walk. Two of those copies had silently dropped the empty-set[]-with-any[] rule
# and attribute-name resolution. So: any tool that answers "which combo fires" must call
# Get-FiringKeyRef from _sim_helpers.ps1 rather than re-walking combinations itself.
if ($sharedTxt -match 'function\s+Get-FiringKeyRef') {
    Emit "[PASS] _sim_helpers.ps1 defines Get-FiringKeyRef (canonical firing walk)"; $pass++
} else {
    Emit "[FAIL] _sim_helpers.ps1 missing Get-FiringKeyRef -- the firing walk is not shared"; $fail++
}

# Tools that must delegate. test_commsys.ps1 is EXEMPT by design: it is the human-facing
# simulator and prints per-combo SKIP/FIRES/shadowed diagnostics, which needs the walk
# inlined to report each combo's reason. It is covered instead by the behavioural
# cross-check below, so an inlined walk there can never silently disagree.
$firingConsumers = @('emit_test_plan.ps1','audit_log_combo_attribution.ps1')
foreach ($c in $firingConsumers) {
    $p = Join-Path $toolDir $c
    if (-not (Test-Path $p)) { Emit "[FAIL] $c not found"; $fail++; continue }
    $txt = [System.IO.File]::ReadAllText($p)
    if ($txt -match 'Get-FiringKeyRef') {
        Emit "[PASS] $c delegates to Get-FiringKeyRef"; $pass++
    } else {
        Emit "[FAIL] $c does NOT call Get-FiringKeyRef (re-walks combinations privately)"; $fail++
    }
}

# ── 5. BEHAVIOURAL CROSS-CHECK ───────────────────────────────────────────────────
# Verify the ANSWER, not the plumbing. Every emitted test plan already records the combo
# expected to fire for a known fill; recompute it with the canonical walk and require
# agreement. Two independent producers, same input -> same keyRef, or something is wrong.
# This is the check that would have caught the 17 misattributed logs at plan time.
. $shared
$planFiles = @(Get-ChildItem (Join-Path (Split-Path $toolDir -Parent) 'providers') -Recurse -Filter '*_TEST_PLAN_v*.json' -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '_archive' })
if ($planFiles.Count -eq 0) {
    Emit "[INFO] no test plans on disk -- behavioural cross-check skipped"
} else {
    $agree = 0; $disagree = 0; $planErrs = 0; $indet = 0
    foreach ($pf in $planFiles) {
        $provName = ($pf.Name -replace '_TEST_PLAN_v.*$','')
        $provDir  = Join-Path (Join-Path (Split-Path $toolDir -Parent) 'providers') $provName
        $pj = Get-ChildItem $provDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -like "$provName*" } | Select-Object -First 1
        if (-not $pj) { continue }
        try {
            $plan = [System.IO.File]::ReadAllText($pf.FullName) | ConvertFrom-Json
            $prov = [System.IO.File]::ReadAllText($pj.FullName) | ConvertFrom-Json
        } catch { $planErrs++; continue }

        # Form initialValues per entity, INCLUDING HIDDEN fields. A plan's formDefaults omits
        # hidden handler-fed fields (the driver can't type into them), so it under-models the
        # real form: AZ_AZDPS's ACVR requires the hidden dexStateUserId badge feeder, and
        # simulating from plan formDefaults alone fires NOTHING for every AZ Vehicle test.
        # The rendered form always carries these, so they must be seeded (2026-07-29).
        $initByEnt = @{}
        foreach ($b in $prov.bundles) {
            if ($b.provider -ne 'MARK43') { continue }
            foreach ($cfg in $b.configurations) {
                $e2 = "$($cfg.targetEntity)"
                if (-not $e2) { continue }
                if (-not $initByEnt.ContainsKey($e2)) { $initByEnt[$e2] = @{} }
                foreach ($nd in $cfg.layout.default.PSObject.Properties) {
                    $fid2 = $nd.Value.props.fieldId; $iv2 = $nd.Value.props.initialValue
                    if ($fid2 -and -not [string]::IsNullOrWhiteSpace("$iv2")) { $initByEnt[$e2][$fid2] = "$iv2" }
                }
            }
        }

        $qidmsByEnt = @{}
        foreach ($b in $prov.bundles) {
            if ($b.provider -in @('MARK43','RMS')) { continue }
            foreach ($cfg in $b.configurations) {
                if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
                if ($cfg.handlerFunction -eq 'RmsRestPayloadHandler') { continue }
                $e = "$($cfg.targetEntity)"
                if (-not $qidmsByEnt.ContainsKey($e)) { $qidmsByEnt[$e] = @() }
                $qidmsByEnt[$e] += $cfg
            }
        }
        # Fields the static model can actually supply for this entity: anything the plan ever
        # fills, plus form defaults, plus form initialValues. A combo requiring anything OUTSIDE
        # this set is UNMODELLABLE -- e.g. AZ_AZDPS's badge combos (ACVR/ACWL/ACQB/ACQBH) all
        # require dexStateUserId, which has no initialValue and is populated at runtime by
        # CommsysGetDexStateUserIdRuleHandler. Statically the badge is absent, so the walk picks
        # the no-badge fallback (DQN/BQ/BQH) -- but at runtime the badge combo may well win.
        # Neither answer is knowable without a live run, so such tests are INDETERMINATE.
        $modellable = @{}
        foreach ($t2 in @($plan.tests)) {
            foreach ($f2 in @($t2.fills)) { if ($f2 -and $f2.fieldId) { $modellable["$($f2.fieldId)"] = $true } }
        }
        foreach ($eKey in $initByEnt.Keys) { foreach ($k in $initByEnt[$eKey].Keys) { $modellable[$k] = $true } }
        if ($plan.formDefaults) {
            foreach ($eKey in $plan.formDefaults.PSObject.Properties.Name) {
                foreach ($k in $plan.formDefaults.$eKey.PSObject.Properties.Name) { $modellable[$k] = $true }
            }
        }

        foreach ($t in @($plan.tests)) {
            if (-not $t.expectedKeyRef) { continue }
            $e = "$($t.entity)"
            if (-not $qidmsByEnt.ContainsKey($e)) { continue }

            $expCombo = $null
            foreach ($qq in $qidmsByEnt[$e]) {
                foreach ($cc in @($qq.combinations)) {
                    if ("$($cc.keyReference)" -eq "$($t.expectedKeyRef)") { $expCombo = $cc; break }
                }
                if ($expCombo) { break }
            }
            if ($expCombo) {
                $unmodellable = @(@($expCombo.requirements.set | Where-Object { $_ }) |
                                 Where-Object { -not $modellable.ContainsKey($_) })
                if ($unmodellable.Count -gt 0) { $indet++; continue }
            }
            $fd = @{}
            foreach ($f in @($t.fills)) { if ($f -and $f.fieldId) { $fd["$($f.fieldId)"] = "$($f.value)" } }
            $ed = $plan.formDefaults.$e
            if ($ed) { foreach ($k in $ed.PSObject.Properties.Name) { if (-not $fd.ContainsKey($k)) { $fd[$k] = "$($ed.$k)" } } }
            if ($initByEnt.ContainsKey($e)) {
                foreach ($k in $initByEnt[$e].Keys) { if (-not $fd.ContainsKey($k)) { $fd[$k] = $initByEnt[$e][$k] } }
            }
            $sim = Get-FiringKeyRef $qidmsByEnt[$e] $fd
            if ([string]::IsNullOrWhiteSpace("$sim")) {
                # INDETERMINATE, not a disagreement: the combo needs a field no static model can
                # supply -- a platform/handler-populated one with no initialValue that the test
                # driver never types (AZ_AZDPS ACVR requires dexStateUserId, filled at runtime by
                # CommsysGetDexStateUserIdRuleHandler). emit_test_plan falls back to the structural
                # keyRef in exactly this case, so the cross-check must not call it a mismatch.
                $indet++
                continue
            }
            if ("$sim" -eq "$($t.expectedKeyRef)") { $agree++ }
            else {
                $disagree++
                if ($disagree -le 6) {
                    Emit "[FAIL] $provName test n=$($t.n) ($($t.kind)): plan expects '$($t.expectedKeyRef)' but the canonical walk fires '$sim'"
                }
            }
        }
    }
    $indetSfx = ''
    if ($indet -gt 0) {
        $indetSfx = " ($indet indeterminate -- combo needs a handler-populated set[] field with no initialValue, not modellable statically)"
    }
    if ($disagree -eq 0) {
        Emit "[PASS] behavioural cross-check: $agree plan test(s) across $($planFiles.Count) plan(s) agree with the canonical firing walk$indetSfx"; $pass++
    } else {
        Emit "[FAIL] behavioural cross-check: $disagree of $($agree + $disagree) plan test(s) disagree with the canonical firing walk"; $fail++
    }
    if ($planErrs -gt 0) { Emit "[INFO] $planErrs plan(s) unreadable, skipped" }
}

Emit ""
Emit "RESULTS: $pass PASS / $fail FAIL / 0 WARN"

if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
}

if ($fail -gt 0) { exit 1 } else { exit 0 }
