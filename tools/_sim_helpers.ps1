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
# ── CANONICAL "WHICH COMBO FIRES" (added 2026-07-29) ─────────────────────────────
# Five tools had grown their own copy of this walk (test_commsys, run_test_matrix,
# emit_test_plan, audit_combo_reachability, audit_log_combo_attribution) while only the
# CONDITIONS predicate below was shared -- so audit_simulator_parity could report "parity"
# while the set[]-satisfaction halves disagreed. Two cases were already being dropped by
# the newest copies: attribute-name -> sourceField resolution, and the empty-set[]-with-
# any[] rule (a combo with no set[] requires at least ONE any[] field filled, e.g. CCH AR)
# -- without it such a combo reads as always-matching and hijacks first-match.
# Any tool answering "which combo fires" MUST call Get-FiringKeyRef, never re-walk it.

# Which of a QIDM's refs are satisfied by this form fill? Resolves BOTH directions:
# the raw sourceField key the officer typed into, and the attribute NAME it feeds --
# set[]/any[] entries appear as either across the portfolio.
function Get-SimFilledRefs($qidm, $formData) {
    $filled = @()
    foreach ($attr in $qidm.attributes) {
        $sfs = @()
        if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
        elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
        $has = $false
        foreach ($sf in $sfs) { if ($formData.ContainsKey($sf) -and $formData[$sf]) { $filled += $sf; $has = $true } }
        if ($has) { $filled += $attr.name }
    }
    # A fill key that is not modelled as an attribute sourceField still counts as present
    # (combo set[]/any[] may name a form fieldId directly).
    foreach ($k in $formData.Keys) { if ($formData[$k]) { $filled += $k } }
    return ($filled | Select-Object -Unique)
}

# Does this ONE combo match the fill? (set[] all present; if set[] is empty, at least one
# any[] present; conditions pass). Returns $true/$false.
function Test-ComboMatches($combo, $filled, $formData) {
    # Filter nulls: @($null) is a 1-element array in PowerShell, not empty.
    $set = @($combo.requirements.set | Where-Object { $_ })
    $any = @($combo.requirements.any | Where-Object { $_ })
    foreach ($f in $set) { if ($filled -notcontains $f) { return $false } }
    if ($set.Count -eq 0 -and $any.Count -gt 0) {
        $anyOk = $false
        foreach ($f in $any) { if ($filled -contains $f) { $anyOk = $true; break } }
        if (-not $anyOk) { return $false }
    }
    return (Test-ComboConditionsCore (Get-ComboConditions $combo) $formData).ok
}

# FIRST matching combination across the given QIDMs, in array order = what the platform
# fires. Returns the keyRef, or $null if nothing matches.
function Get-FiringKeyRef($entQidms, $formData) {
    foreach ($q in $entQidms) {
        $filled = Get-SimFilledRefs $q $formData
        foreach ($c in $q.combinations) {
            if (Test-ComboMatches $c $filled $formData) {
                if ($c.keyReference) { return $c.keyReference } else { return $c.keyRef }
            }
        }
    }
    return $null
}

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
