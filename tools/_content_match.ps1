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

$script:CmStateNames = @{
    'GA'='GEORGIA'; 'NJ'='NEW JERSEY'; 'HI'='HAWAII'; 'CA'='CALIFORNIA'; 'FL'='FLORIDA'
    'TX'='TEXAS'; 'NY'='NEW YORK'; 'AZ'='ARIZONA'; 'LA'='LOUISIANA'
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
