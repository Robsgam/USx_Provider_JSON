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

# --- 1b. Live-test status from ACTUAL log RESULT lines -------------------------
# report_test_status.ps1 reads real logs/<Entity>/*.txt RESULT lines (NOT the drift-prone
# .test_state.json status field or SQVR markers) -- the ground-truth "tested & passing?" view.
Emit ""
Emit "--- LIVE-TEST STATUS (report_test_status.ps1 -- actual log RESULT lines) ---"
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
