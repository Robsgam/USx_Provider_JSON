<#
  _divergence_rules.ps1 -- ONE definition of what an ACCEPTED_DIVERGENCES rule NAME means.

  WHY SHARED: the rule vocabulary is the whole basis for scoping a suppression, and the moment two
  tools classify 'promoted-to-any' differently they disagree about which gates a recorded decision
  silences -- silently, because a suppression leaves no trace. audit_metadata (the enforcer) and
  audit_suppression_scope (the measurer) MUST agree or the measurement is fiction.

  CLASSES
    to-set      the decision is about placing a field INTO a combo's set[]   (promoted-to-set)
    to-any      the decision is about a field sitting in any[]               (promoted-to-any,
                                                                             demoted-to-any, added-to-any)
    existence   the decision is that a COMBINATION is not built / not reachable
                (not-built, devdoc-combo-unbuilt, metadata-shadow-autofired, dead-combo-*,
                 dropped-combo, shadow-unbuilt-*, missing-primary-combo)
    other       adjudications that license no field-placement or existence check on their own
                (devdoc-optional-unreachable, built-as, prefilled-mandatory-autopopulated,
                 precondition-adjudicated-satisfied)

  A check may only be silenced by a row whose class matches what that check actually tests.
  'other' licenses NOTHING by design: those rows record a judgement about officer-facing behaviour
  or a precondition, not about where a field sits or whether a combo exists. If one of them turns
  out to need to suppress a specific check, give it a properly-named rule instead of widening this.
#>

function Get-DivergenceRuleClass([string]$rule) {
    $r = "$rule".Trim().ToLower()
    if ($r -eq 'promoted-to-set') { return 'to-set' }
    if ($r -in @('promoted-to-any', 'demoted-to-any', 'added-to-any')) { return 'to-any' }
    if ($r -match 'not-built|unbuilt|shadow|dead-combo|dropped-combo|missing-primary-combo') { return 'existence' }
    return 'other'
}

# Per-provider OPT-IN. Direction-aware suppression is NARROWER than legacy behaviour, so switching
# it on can turn a green provider RED -- a real finding stops being silenced. That is a release
# decision, one provider at a time (Rob 2026-07-30), never a portfolio sweep. A provider opts in by
# putting this line in its <P>_ACCEPTED_DIVERGENCES.txt:
#     # SUPPRESSION-SCOPE: direction-aware
# Marker lives with the data it governs, same convention as the '# BASE-SYNC:' variant marker.
function Test-DirectionAwareOptIn([string]$registryPath) {
    if (-not $registryPath -or -not (Test-Path $registryPath)) { return $false }
    foreach ($ln in (Get-Content $registryPath)) {
        if ($ln -match '(?i)^\s*#\s*SUPPRESSION-SCOPE:\s*direction-aware') { return $true }
    }
    return $false
}
