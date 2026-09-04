<#
  doctor.ps1 -- One-shot repo health dashboard.

  Composes existing tools into a single snapshot so you don't run 4 things by hand:
    1. Provider scorecard (score_all.ps1 -Quick: parses existing VALIDATOR_REPORTs)
    2. Poisoned-array sweep across all provider root JSONs (validate.ps1 G-31)
    3. Git working-tree status (uncommitted changes)
    4. Reverse-propagation status (audit_reverse_propagation.ps1: pending-rebuild flags)
    5. A one-line health verdict

  Read-only. Does NOT modify, build, or commit anything.

  Usage: .\doctor.ps1
         .\doctor.ps1 -SkipPoison   # faster; skip the per-JSON validate sweep
         .\doctor.ps1 -OutFile health.txt
#>
param(
    [switch]$SkipPoison,
    [string]$OutFile
)
$ErrorActionPreference = "Stop"
$tool = $PSScriptRoot
$repo = (Resolve-Path "$tool\..").Path
$providers = Join-Path $repo "providers"
$lines = @()
function Emit($s) { Write-Host $s; $script:lines += $s }

Emit ""
Emit "================================================================"
Emit "  REPO DOCTOR -- health snapshot"
Emit "  $repo"
Emit "================================================================"

# --- 1. Scorecard (reuse score_all -Quick) -------------------------------------
Emit ""
Emit "--- PROVIDER SCORECARD (score_all -Quick) ---"
try {
    $sc = & "$tool\score_all.ps1" -Quick *>&1 | Out-String
    Emit $sc.TrimEnd()
} catch {
    Emit "  [WARN] score_all.ps1 -Quick failed: $($_.Exception.Message)"
}

# --- 1b. USx-tenant-test status from ACTUAL log RESULT lines -------------------------
# report_test_status.ps1 reads real logs/<Entity>/*.txt RESULT lines (NOT the drift-prone
# .test_state.json status field or SQVR markers) -- the ground-truth "tested & passing?" view.
Emit ""
Emit "--- USx-TENANT-TEST STATUS (report_test_status.ps1 -- actual log RESULT lines) ---"
try {
    $ts = & "$tool\report_test_status.ps1" *>&1 | Out-String
    # Show the SUMMARY roll-up (ALL-PASS / NEVER-TESTED / NOT-TRACKED), not the full per-entity dump.
    $inSummary = $false
    foreach ($l in ($ts.TrimEnd() -split "`n")) {
        if ($l -match '^SUMMARY') { $inSummary = $true; Emit $l; continue }
        if ($inSummary) { Emit $l }
    }
} catch {
    Emit "  [WARN] report_test_status.ps1 failed: $($_.Exception.Message)"
}

# --- 2. Poisoned-array sweep (validate G-31) -----------------------------------
if (-not $SkipPoison) {
    Emit ""
    Emit "--- POISONED-ARRAY SWEEP (value-comparison conditions; validate.ps1 G-31) ---"
    $poison = @()
    Get-ChildItem $providers -Directory | ForEach-Object {
        $prov = $_.Name
        Get-ChildItem "$($_.FullName)\*.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $out = & "$tool\validate.ps1" -Path $_.FullName *>&1 | Out-String
            $n = ([regex]::Matches($out, "has POISONED-ARRAY condition")).Count
            if ($n -gt 0) { $poison += [PSCustomObject]@{ Provider = $prov; File = $_.Name; Combos = $n } }
        }
    }
    if ($poison) {
        ($poison | Sort-Object -Descending Combos | Format-Table -AutoSize | Out-String).TrimEnd() -split "`n" | ForEach-Object { Emit $_ }
        Emit "  (poisoned != broken: benign if matched combos share a field signature; see LIMITATION #37)"
    } else {
        Emit "  NONE -- no value-comparison conditions in any root JSON."
    }
} else {
    Emit ""
    Emit "--- POISONED-ARRAY SWEEP: skipped (-SkipPoison) ---"
}

# --- 3. Git status -------------------------------------------------------------
Emit ""
Emit "--- GIT STATUS ---"
try {
    Push-Location $repo
    $st = git status --short 2>&1
    Pop-Location
    if ($st) { ($st | ForEach-Object { Emit "  $_" }) } else { Emit "  clean working tree" }
} catch { Emit "  [WARN] git status failed" }

# --- 4. Reverse-propagation status (pending rebuilds from shared fixes) ---------
Emit ""
Emit "--- REVERSE-PROPAGATION (pending-rebuild flags; audit_reverse_propagation.ps1) ---"
try {
    $rp = & "$tool\audit_reverse_propagation.ps1" *>&1 | Out-String
    # Show just the pending/ledger/gap body, not the tool's own banner.
    ($rp.TrimEnd() -split "`n") | Where-Object { $_ -notmatch '^=+$' -and $_ -notmatch 'REVERSE-PROPAGATION STATUS' } | ForEach-Object { Emit $_ }
} catch {
    Emit "  [WARN] audit_reverse_propagation.ps1 failed: $($_.Exception.Message)"
}

Emit ""
Emit "--- BASE<->VARIANT SYNC (variant base-6 drift; audit_variant_sync.ps1) ---"
try {
    $vs = & "$tool\audit_variant_sync.ps1" *>&1 | Out-String
    ($vs.TrimEnd() -split "`n") | Where-Object { $_ -notmatch '^=+$' -and $_ -notmatch 'BASE<->VARIANT SYNC AUDIT' } | ForEach-Object { Emit $_ }
} catch {
    Emit "  [WARN] audit_variant_sync.ps1 failed: $($_.Exception.Message)"
}

Emit ""
Emit "--- DATA-MINED TRANSACTIONS (DM2 = mined tags we cannot receive; audit_data_mined.ps1) ---"
# Added 2026-08-24. build_phase1 step 5b covers a provider AT BUILD TIME; this is the portfolio view,
# so a DM2 on a provider nobody is rebuilding is still visible. Only the summary is echoed -- the DM1
# per-combination annotations belong next to the build's own MISSING list, not in a dashboard.
try {
    # NOT -Quiet: that switch suppresses Write-Host, so a piped capture gets NOTHING and this block
    # printed an empty section on its first run. Documented trap, and I walked into it anyway.
    $dm = & "$tool\audit_data_mined.ps1" -All *>&1 | Out-String
    $picked = @(($dm.TrimEnd() -split "`n") | Where-Object { $_ -match 'EXAMINED:|DM2 \(|\[PASS\]|\[NO-VERDICT\]|DM2 WARN' })
    if ($picked.Count) { $picked | ForEach-Object { Emit $_.TrimEnd() } }
    else { Emit '  [WARN] audit_data_mined produced no summary line -- treat as UNCHECKED, not clean' }
} catch {
    Emit "  [WARN] audit_data_mined.ps1 failed: $($_.Exception.Message)"
}

Emit ""
Emit "--- TENANT PICKLIST SCOPE (owed captures / owed re-scopes; audit_picklist_scope.ps1) ---"
# ADDED 2026-08-21. enforce runs this tool ONE PROVIDER AT A TIME, so a standing owed capture is
# invisible unless someone happens to enforce that provider -- and AZ_AZDPS had owed 4 dropdown
# categories (Firearm/Article/Person never scoped) while every board read green. A gate nobody
# sweeps is indistinguishable from one that does not exist.
try {
    $pk = & "$tool\audit_picklist_scope.ps1" -All -Quiet *>&1 | Out-String
    ($pk.TrimEnd() -split "`n") | Where-Object { $_.Trim() -ne '' } | ForEach-Object { Emit $_ }
} catch {
    Emit "  [WARN] audit_picklist_scope.ps1 failed: $($_.Exception.Message)"
}

Emit ""
Emit "--- PS 5.1 PARSE GATE (tools must parse on the engine that runs them; audit_ps51_parse.ps1) ---"
try {
    # MUST be invoked as `powershell` (5.1), never pwsh: PS7's grammar accepts constructs 5.1
    # rejects, so running this under 7 would report clean while a tool is a hard parse failure.
    # The script itself refuses to give a clean verdict off 5.1, but pin the engine here too.
    $pp = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_ps51_parse.ps1" *>&1 | Out-String
    ($pp.TrimEnd() -split "`n") | Where-Object { $_ -notmatch '^=+$' -and $_ -notmatch 'PS 5.1 PARSE GATE --' } | ForEach-Object { Emit $_ }
} catch {
    Emit "  [WARN] audit_ps51_parse.ps1 failed: $($_.Exception.Message)"
}

# --- 6. Repo-scope advisories that nothing else ran ------------------------------
# These three were ORPHANS: real gates, kept current, referenced by no orchestrator -- so their
# findings only ever surfaced when someone ran them by hand. They are advisory or repo-scope
# (not per-provider blocking), so doctor is the right home: visible on every health check,
# blocking nothing. A gate that nothing runs is not a gate.
Emit ""
# A finished provider's ARTIFACT SET is its deliverable -- the officer guide a department reads, the
# SQVR a tester reads. audit_structure checks each provider against a template IN ISOLATION and
# reported ALL CLEAN on all six tenant-complete providers while their sets genuinely differed;
# audit_cross_provider is cross-provider but only compares JSON content. So nothing measured this
# until 2026-08-10, when it found CA_CLETS carrying a CAD_GUIDE from a tool archived 2026-07-24.
Emit ""
Emit "--- PROVIDER UNIFORMITY (do the FINISHED providers carry the same artifact set; audit_provider_uniformity.ps1) ---"
try {
    # NOT -Quiet: doctor greps the console lines, and -Quiet renders the section EMPTY, which reads
    # exactly like clean (the mistake already made once on registry currency, two sections below).
    $pu = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_provider_uniformity.ps1" *>&1 | Out-String
    ($pu -split "`n" | Where-Object { $_ -match 'COMPARED:|\[FAIL\]|Scope:' } | Select-Object -First 12) |
        ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] audit_provider_uniformity.ps1 failed: $($_.Exception.Message)" }

Emit ""
Emit "--- SUPPRESSION SCOPE (registry rows silencing more than they adjudicate; audit_suppression_scope.ps1) ---"
try {
    $ss = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_suppression_scope.ps1" *>&1 | Out-String
    ($ss -split "`n" | Where-Object { $_ -match 'TOTAL:|OVER-BROAD|^\s+[A-Z][A-Z_]+\s+\d+\s+[1-9]' } | Select-Object -First 12) |
        ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] audit_suppression_scope.ps1 failed: $($_.Exception.Message)" }

# The companion question to suppression SCOPE: a row can be perfectly scoped, silence nothing, and
# still describe a condition that was fixed away. That is how FL_FCIC's NEEDS-RULING row survived
# four days past the commit that closed it and got a version bump approved. Denominator matters here:
# only ~29% of registry rows are checkable this way, so read a 0 as "none PROVABLY stale".
Emit ""
Emit "--- REGISTRY CURRENCY (does each accepted-divergence row still describe the JSON; audit_registry_currency.ps1) ---"
try {
    # NOT -Quiet: that suppresses the console lines this grep reads, so the section rendered EMPTY --
    # a MUTE gate, which reads exactly like a clean one. Caught on the first doctor run after wiring.
    $rc = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_registry_currency.ps1" -All *>&1 | Out-String
    ($rc -split "`n" | Where-Object { $_ -match 'TOTALS:|STALE\]|providers with stale' } | Select-Object -First 12) |
        ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] audit_registry_currency.ps1 failed: $($_.Exception.Message)" }

# Same family as registry currency: a RECORD contradicting its ARTIFACT. Here the record is the
# BUILD_NOTES entry and the artifact is the emitted JSON.
# ⚠️ CORRECTED 2026-09-04. This comment used to read "Baseline 2026-08-03 is 14 FAIL of 14
# comparable -- deliberately NOT in enforce until those are repaired, so watch it here." BOTH
# halves are now false: all 14 were repaired at their own rebuilds (re-measured 2026-08-24 at
# 20 checked / 0 GENERIC / 0 FAIL), and the gate IS in enforce as PHASE 2u, BLOCKING
# (enforce.ps1:1015). It lands at zero, which is why wiring it was safe.
# This matters beyond tidiness: it is the comment someone reads when judging whether doctor can
# safely be given an exit code, and it argued for a permanent red section that no longer exists.
Emit ""
Emit "--- BUILD_NOTES FIDELITY (a generic entry hiding a real change; audit_buildnotes_fidelity.ps1) ---"
try {
    $bf = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_buildnotes_fidelity.ps1" -All *>&1 | Out-String
    ($bf -split "`n" | Where-Object { $_ -match 'TOTALS:|FAIL /|GENERIC entry but' } | Select-Object -First 14) |
        ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] audit_buildnotes_fidelity.ps1 failed: $($_.Exception.Message)" }

Emit ""
Emit "--- TOOL PORTABILITY (every shared gate must reach a verdict on every provider; audit_tool_portability.ps1) ---"
try {
    $tp = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_tool_portability.ps1" *>&1 | Out-String
    ($tp -split "`n" | Where-Object { $_ -match 'RESULT:|NO-VERDICT' } | Select-Object -First 10) |
        ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] audit_tool_portability.ps1 failed: $($_.Exception.Message)" }

Emit ""
Emit "--- ARTIFACT PROVENANCE (is this evidence, or something shaped like it; audit_artifact_provenance.ps1) ---"
try {
    $ap = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_artifact_provenance.ps1" *>&1 | Out-String
    ($ap -split "`r?`n") | Where-Object { $_ -match 'EXAMINED|F frozen|\[FAIL\]|\[PASS\]|NO-VERDICT' } | ForEach-Object { Emit ("  " + $_.Trim()) }
} catch { Emit "  [WARN] audit_artifact_provenance.ps1 failed: $($_.Exception.Message)" }
Emit ""

Emit "--- MISSION STATUS (the 95% metric, computed; report_mission_status.ps1) ---"
try {
    $ms = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\report_mission_status.ps1" *>&1 | Out-String
    ($ms -split "`r?`n") | Where-Object { $_ -match 'LIFECYCLE-COMPLETE|BLOCKED BY STAGE|^\s{4}\w+\s+\d+ provider|NO-VERDICT' } | ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] report_mission_status.ps1 failed: $($_.Exception.Message)" }
Emit ""
Emit "--- PROVIDER LINKAGE (a build justified by another provider's authority; audit_provider_linkage.ps1) ---"
try {
    $pl = & powershell -NoProfile -ExecutionPolicy Bypass -File "$tool\audit_provider_linkage.ps1" *>&1 | Out-String
    ($pl -split "`n" | Where-Object { $_ -match 'RESULT:|cross-provider reference' } | Select-Object -First 12) |
        ForEach-Object { Emit ("  " + $_.TrimEnd()) }
} catch { Emit "  [WARN] audit_provider_linkage.ps1 failed: $($_.Exception.Message)" }

# --- 5. Verdict ----------------------------------------------------------------
Emit ""
Emit "================================================================"
$fails = ([regex]::Matches(($lines -join "`n"), "\d+F\b")).Count
Emit "  Review the scorecard for any non-zero FAIL/WARN, the poisoned sweep for"
Emit "  exposure to fix at each provider's rebuild, and git for uncommitted work."
Emit "  For the authoritative gate, run: enforce.ps1 -Provider <NAME>"
Emit "================================================================"

if ($OutFile) {
    $lines -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8
    Write-Host "`n  Saved: $OutFile" -ForegroundColor Green
}
