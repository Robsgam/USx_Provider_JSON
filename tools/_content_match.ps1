<#
  _content_match.ps1 -- shared content-matching core, dot-sourced by relabel_batch.ps1 and
  audit_log_content.ps1. A record/log's form snapshot (dex-log formState / saved QUERY STRING)
  is the ground truth for WHICH plan test produced it; labels are not.

  Matching rule (per plan test):
    - every planned fill present with a tolerant value match
      (exact, display-startsWith-code, GA->Georgia, M->Male, CNST_ prefix)
    - no extra non-default snapshot field that is FILLABLE within the same query family
      (family fillables = union of fill fieldIds across the plan's tests for that query;
       defaults = fields carrying the identical value in EVERY snapshot of that messageType)
#>

# FULL 50-state + DC map (fixed 2026-08-06). The table had only the 9 states the six
# tenant-tested providers' home/OOS-toggle fills happened to use (GA/NJ/HI/CA/FL/TX/NY/AZ/LA) --
# grown one entry at a time as a provider needed it, never built out completely. TX_TLETS's
# RegistrationState OOS-toggle tests (DQName/CPLName/DQOLN, fill value 'AK') fell into the gap:
# dex-log's own "Query String" cell -- which the extension faithfully copies, this is NOT an
# extension bug -- renders the SELECT's display label ("Alaska"), never the wire code, and
# Test-CmValueMatch had no AK->ALASKA entry to resolve it. The wire itself was already correct
# (<State>AK</State>, confirmed from the preserved capture) -- only the relabeler's ability to
# ATTRIBUTE the capture back to its plan test was broken, for any of the 41 unlisted states.
# Any future OOS/random toggle picking one of those 41 hits the identical failure, so the fix is
# the complete table, not one more entry.
$script:CmStateNames = @{
    'AL'='ALABAMA'; 'AK'='ALASKA'; 'AZ'='ARIZONA'; 'AR'='ARKANSAS'; 'CA'='CALIFORNIA'
    'CO'='COLORADO'; 'CT'='CONNECTICUT'; 'DE'='DELAWARE'; 'DC'='DISTRICT OF COLUMBIA'
    'FL'='FLORIDA'; 'GA'='GEORGIA'; 'HI'='HAWAII'; 'ID'='IDAHO'; 'IL'='ILLINOIS'
    'IN'='INDIANA'; 'IA'='IOWA'; 'KS'='KANSAS'; 'KY'='KENTUCKY'; 'LA'='LOUISIANA'
    'ME'='MAINE'; 'MD'='MARYLAND'; 'MA'='MASSACHUSETTS'; 'MI'='MICHIGAN'; 'MN'='MINNESOTA'
    'MS'='MISSISSIPPI'; 'MO'='MISSOURI'; 'MT'='MONTANA'; 'NE'='NEBRASKA'; 'NV'='NEVADA'
    'NH'='NEW HAMPSHIRE'; 'NJ'='NEW JERSEY'; 'NM'='NEW MEXICO'; 'NY'='NEW YORK'
    'NC'='NORTH CAROLINA'; 'ND'='NORTH DAKOTA'; 'OH'='OHIO'; 'OK'='OKLAHOMA'; 'OR'='OREGON'
    'PA'='PENNSYLVANIA'; 'RI'='RHODE ISLAND'; 'SC'='SOUTH CAROLINA'; 'SD'='SOUTH DAKOTA'
    'TN'='TENNESSEE'; 'TX'='TEXAS'; 'UT'='UTAH'; 'VT'='VERMONT'; 'VA'='VIRGINIA'
    'WA'='WASHINGTON'; 'WV'='WEST VIRGINIA'; 'WI'='WISCONSIN'; 'WY'='WYOMING'
}
function Test-CmValueMatch($fillVal, $display) {
    $f = "$fillVal".ToUpper(); $d = "$display".ToUpper()
    if ($d -eq $f) { return $true }
    if ($script:CmStateNames[$f] -eq $d) { return $true }
    if ($f -eq 'M' -and $d -eq 'MALE') { return $true }
    if ($d.StartsWith($f)) { return $true }
    if ($f.StartsWith('CNST_') -and $d -eq $f.Substring(5)) { return $true }
    return $false
}

# Canonical log/record label for a plan test (matches post_test log naming).
function Get-CmPlanLabel($t) {
    if ($t.kind -eq 'guardrail') {
        # guardrailLoser only set when >1 loser combo resolves to this SAME winner (see
        # emit_test_plan.ps1) -- otherwise omitted so existing filenames stay stable.
        if ($t.guardrailLoser) { return "$($t.expectedKeyRef)_guardrail_vs_$($t.guardrailLoser)" }
        return "$($t.expectedKeyRef)_guardrail"
    }
    # NOTE ON REROUTED TESTS (reroutedFrom, set by emit_test_plan.ps1 when a test's own fill makes
    # an earlier combo win first-match): their LABEL DELIBERATELY STAYS comboKeyRef-based.
    # I briefly renamed them "<winner>_af_<field>_over_<unreachable>" on 2026-07-29 so a filename
    # could not assert a combo that never ran. That was WRONG for two reasons, both proven the same
    # day by an FL_FCIC Boat run:
    #   1. The IMPORT path names a log from comboKeyRef/kind/anyField, not from this function, so a
    #      renamed test could NEVER receive a log -- it just showed as permanently owed. It created
    #      7 phantom "missing tests" on FL_FCIC and nearly sent Rob to re-run them.
    #   2. Five of those seven had BYTE-IDENTICAL fills to tests that already had logs (e.g. n=76
    #      Hull+decal == n=71 Hull+decal). A rerouted test with the same fill as another test IS
    #      the same submission -- the platform cannot distinguish them, so it can never be
    #      separately evidenced and must not be counted as separate coverage.
    # The reroute information is still recorded where it is actually useful: expectedKeyRef (the
    # combo that really fires) and reroutedFrom (the one it cannot reach) in the PLAN, plus
    # audit_log_combo_attribution.ps1, which replays the recorded fill and needs no filename help.
    if ($t.kind -eq 'any')       { return "$($t.comboKeyRef)_any" }
    if ($t.kind -eq 'any-field') { return "$($t.comboKeyRef)_af_$($t.anyField)" }
    return $t.comboKeyRef
}

# query -> hashset of fillable fieldIds (upper) across the plan's tests for that query.
function Build-CmFamilyFillable($plan) {
    $fam = @{}
    foreach ($t in $plan.tests) {
        if (-not $fam.ContainsKey($t.query)) { $fam[$t.query] = @{} }
        # ConvertTo-Json can serialize a genuinely-empty PowerShell array as JSON `{}` (not
        # `[]`) when every field in a combo's set[] is unmapped in the value resolver -- that
        # round-trips through ConvertFrom-Json as a truthy, property-less object, not $null.
        foreach ($f in @($t.fills)) { if ($f -and $f.fieldId) { $fam[$t.query][$f.fieldId.ToUpper()] = $true } }
    }
    return $fam
}

# snapshots: list of @{ messageType = <string>; fs = <psobject form snapshot> }.
# Returns messageType -> @{ FIELDID(upper) = dominantValue }. A field is a DEFAULT when one
# value dominates (>=60% of snapshots carrying the field, min 2) -- strict all-identical broke
# on home-state defaults (RegistrationState = 'New Jersey' in 10/11 Vehicle logs; the OOS
# any-test carries GA). An extra field is ignorable only when its value EQUALS the default.
function Build-CmDefaults($snapshots) {
    $out = @{}
    foreach ($g in ($snapshots | Where-Object { $_.fs } | Group-Object messageType)) {
        $states = @($g.Group | ForEach-Object { $_.fs })
        if (-not $states.Count) { continue }
        $d = @{}
        $fieldNames = @($states | ForEach-Object { $_.PSObject.Properties.Name } | Sort-Object -Unique)
        # IDENTIFIERS are never defaults: in a small batch the shared identifier value
        # (every Boat row carries the same hull number) crosses the dominance threshold and
        # a hull-content row then passes as a Registration test -- 2 Boat logs mislabeled
        # AND the content audit blinded the same way (2026-07-02, caught by the XML gate).
        $idRe = '(?i)(Number$|^operatorLicense|^nameLast|Serial|Hull|^registrationNumber)'
        $fieldNames = @($fieldNames | Where-Object { $_ -notmatch $idRe })
        foreach ($n in $fieldNames) {
            $vals = @($states | ForEach-Object { $p = $_.PSObject.Properties[$n]; if ($p) { "$($p.Value)" } } | Where-Object { $_ -ne $null })
            if ($vals.Count -lt 2) { if ($states.Count -eq 1 -and $vals.Count -eq 1) { $d[$n.ToUpper()] = $vals[0] }; continue }
            $top = $vals | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
            if ($top.Count / $vals.Count -ge 0.6) { $d[$n.ToUpper()] = $top.Name }
        }
        $out[$g.Name] = $d
    }
    return $out
}

# Does form snapshot $fs (psobject) satisfy plan test $t?
# $formDefaults: authoritative QIF initialValues for the test's entity (plan.formDefaults,
# emitted by emit_test_plan) -- @{fieldId=initialValue}. An extra field carrying its form
# default is noise, not a different test's optional. Dynamic dominant-value defaults
# ($defaultsByMt) remain the fallback for fields with no declared initialValue (e.g. the
# platform's home-state prefill on RegistrationState).
function Test-CmSnapshotMatchesTest($fs, [string]$messageType, $t, $familyFillable, $defaultsByMt, $formDefaults = $null) {
    if ($messageType -and $messageType -ne $t.query) { return $false }
    if (-not $fs) { return $false }
    $fills = @($t.fills) | Where-Object { $_ -and $_.fieldId }
    foreach ($fill in $fills) {
        $p = $fs.PSObject.Properties[$fill.fieldId]
        if (-not $p -or -not (Test-CmValueMatch $fill.value $p.Value)) { return $false }
    }
    $plannedNames = @($fills | ForEach-Object { $_.fieldId.ToUpper() })
    $fam = $familyFillable[$t.query]; if (-not $fam) { $fam = @{} }
    $def = $null; if ($messageType) { $def = $defaultsByMt[$messageType] }; if (-not $def) { $def = @{} }
    $fd = @{}
    if ($formDefaults) { foreach ($p in $formDefaults.PSObject.Properties) { $fd[$p.Name.ToUpper()] = $p.Value } }
    foreach ($p in $fs.PSObject.Properties) {
        $n = $p.Name.ToUpper()
        if ("$($p.Value)".Trim() -eq '') { continue }
        if ($plannedNames -contains $n) { continue }
        if (-not $fam.ContainsKey($n)) { continue }
        if ($fd.ContainsKey($n) -and (Test-CmValueMatch $fd[$n] $p.Value)) { continue }   # QIF initialValue
        if ($def.ContainsKey($n) -and "$($p.Value)" -eq $def[$n]) { continue }             # dominant-value fallback
        return $false
    }
    return $true
}
