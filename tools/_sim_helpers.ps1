<#
  _sim_helpers.ps1 -- Canonical CommSys combo-firing predicates SHARED by
  test_commsys.ps1 (the per-form simulator) and run_test_matrix.ps1 (the matrix
  conductor). Both dot-source this file so the two simulators CANNOT diverge on
  condition logic -- the divergence that previously let test_commsys model an
  inert attribute-name condition as "firing" while the platform treated it as
  silently inert (finding H; HI v3.2/v3.4).

  CONDITION MODEL (live-proven HI v3.4 T5, 2026-06-22; KB "conditions[].field =
  sourceField"): conditions[].field is evaluated against FORM-STATE KEYS -- the
  form fieldId, which equals the QIDM attribute's sourceField -- NEVER the
  attribute NAME. A condition whose field matches only an attribute name (with a
  different sourceField) is SILENTLY INERT on the live platform; this core models
  that faithfully so both simulators surface such bugs instead of masking them.

  audit_simulator_parity.ps1 asserts both scripts use this module and carry no
  competing inline predicate.
#>

# Flatten a combo's conditions from both possible locations (combo-level [FL style]
# and requirements-level [NY/CA style]).
function Get-ComboConditions($combo) {
    $conds = @()
    if ($combo.conditions) { $conds += @($combo.conditions) }
    if ($combo.requirements -and $combo.requirements.conditions) { $conds += @($combo.requirements.conditions) }
    return $conds
}

# Evaluate server-side conditions (AND logic). Returns:
#   @{ ok=$bool; failures=@(<"field OP [value=...]">); poisoned=$bool; poisonDesc=$str }
# POISONED-ARRAY RULE (live-proven FL v4.9 T-A/T-B, 2026-06-12; QIDM_REFERENCE
# Sec 2a): a conditions array containing ANY value-comparison operator
# (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) is disabled IN ITS ENTIRETY -- including
# co-resident EXISTS/NOT_EXISTS -- so the combo behaves as unconditioned (ok=true).
function Test-ComboConditionsCore($conds, $formData) {
    $r = @{ ok = $true; failures = @(); poisoned = $false; poisonDesc = '' }
    $conds = @($conds)
    if ($conds.Count -eq 0) { return $r }

    $valueOps  = @('EQUALS','NOT_EQUALS','IN','NOT_IN','REGEX')
    $poisoners = @($conds | Where-Object { "$($_.operator)".ToUpperInvariant() -in $valueOps })
    if ($poisoners.Count -gt 0) {
        $r.poisoned   = $true
        $r.poisonDesc = ($poisoners | ForEach-Object {
            "$(@($_.field) -join '+') $("$($_.operator)".ToUpperInvariant()) $(@($_.value) -join ',')"
        }) -join '; '
        return $r   # entire array inert -> combo unconditioned -> fires
    }

    foreach ($cond in $conds) {
        $op = "$($cond.operator)".ToUpperInvariant()
        if ($op -eq 'EXCLUSIVE') { continue }   # UI-only; always passes server-side
        # @() preserves arrays and wraps scalars (avoids char-indexing a single-element array)
        foreach ($f in @($cond.field)) {
            # Skip null/blank field refs (malformed or empty condition entry -- no constraint).
            if ([string]::IsNullOrWhiteSpace([string]$f)) { continue }
            # FORM-STATE KEY lookup ONLY -- no attribute-name indirection (see header).
            $val = if ($formData -and $formData.ContainsKey($f)) { $formData[$f] } else { $null }
            $present = -not [string]::IsNullOrWhiteSpace("$val")
            $pass = switch ($op) {
                'EXISTS'     { $present }
                'NOT_EXISTS' { -not $present }
                default      { $true }
            }
            if (-not $pass) {
                $r.ok = $false
                $shown = if ($present) { "'$val'" } else { '(blank)' }
                $r.failures += "$f $op [value=$shown]"
            }
        }
    }
    return $r
}
