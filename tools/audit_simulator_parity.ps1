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

Emit ""
Emit "RESULTS: $pass PASS / $fail FAIL / 0 WARN"

if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
}

if ($fail -gt 0) { exit 1 } else { exit 0 }
