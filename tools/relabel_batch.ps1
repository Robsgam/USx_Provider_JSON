<#
  relabel_batch.ps1 -- content-based batch relabeler (pipeline stage before import).

  Browser-side label pairing is unreliable whenever tests share identifier values and
  differ only in optional fields (CA 2026-07-02: whole batch scrambled twice; NJ Firearm:
  labels rotated within the family). Record CONTENT (dex-log formState) is ground truth.

  For each record, find the plan test whose fills it satisfies:
    - every planned fill present in formState with a tolerant value match
      (exact, display-startsWith-code, GA->Georgia, M->Male)
    - no extra non-default formState field that is fillable within the same query family
      (family fillables = union of fill fieldIds across plan tests of that query;
       defaults = fields carrying the identical value in EVERY record of that messageType)
  Ambiguity between content-identical tests (e.g. a base combo vs an any-field test whose
  value equals the form default) is harmless -- the wire is identical.

  Relabels IN PLACE (rewrites the batch file) and reports corrections. Records that match
  no plan test keep their browser label and are reported (import will still process them).

  Usage: .\tools\relabel_batch.ps1 -BatchPath <file> [-PlanPath <file>]
         (PlanPath auto-resolved from the records' provider + version when omitted)
#>
param(
    [Parameter(Mandatory)][string]$BatchPath,
    [string]$PlanPath
)

$records = Get-Content $BatchPath -Raw | ConvertFrom-Json
if (-not $records -or -not @($records).Count) { Write-Host "[relabel] empty batch -- nothing to do"; exit 0 }
$records = @($records)

# Resolve the plan from the first labeled record's provider.
if (-not $PlanPath) {
    $prov = ($records | Where-Object { $_.provider } | Select-Object -First 1).provider
    if (-not $prov) { Write-Host "[relabel] no provider in records; skipping relabel"; exit 0 }
    $provDir = Join-Path (Join-Path $PSScriptRoot '..\providers') $prov
    $PlanPath = Get-ChildItem (Join-Path $provDir 'logs') -Filter "${prov}_TEST_PLAN_v*.json" -ErrorAction SilentlyContinue |
                Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
    if (-not $PlanPath) { Write-Host "[relabel] no TEST_PLAN for $prov; skipping relabel"; exit 0 }
}
$plan = Get-Content $PlanPath -Raw | ConvertFrom-Json

function Test-ValueMatch($fillVal, $display) {
    $f = "$fillVal".ToUpper(); $d = "$display".ToUpper()
    if ($d -eq $f) { return $true }
    if ($f -eq 'GA' -and $d -eq 'GEORGIA') { return $true }
    if ($f -eq 'M' -and $d -eq 'MALE') { return $true }
    if ($d.StartsWith($f)) { return $true }
    if ($f.StartsWith('CNST_') -and $d -eq $f.Substring(5)) { return $true }
    return $false
}

# Family fillables: query -> set of fieldIds any plan test fills for that query.
$familyFillable = @{}
foreach ($t in $plan.tests) {
    if (-not $familyFillable.ContainsKey($t.query)) { $familyFillable[$t.query] = @{} }
    foreach ($f in @($t.fills)) { if ($f) { $familyFillable[$t.query][$f.fieldId.ToUpper()] = $true } }
}

# Dynamic defaults: per messageType, fields present with the IDENTICAL value in every record.
$byMt = $records | Where-Object { $_.formState } | Group-Object messageType
$defaultsByMt = @{}
foreach ($g in $byMt) {
    $states = @($g.Group | ForEach-Object { try { $_.formState | ConvertFrom-Json } catch { $null } } | Where-Object { $_ })
    if (-not $states.Count) { continue }
    $d = @{}
    foreach ($p in $states[0].PSObject.Properties) {
        $v = "$($p.Value)"
        if (($states | Where-Object { "$($_.PSObject.Properties[$p.Name].Value)" -eq $v }).Count -eq $states.Count) { $d[$p.Name.ToUpper()] = $true }
    }
    $defaultsByMt[$g.Name] = $d
}

function Test-RecordMatchesTest($rec, $t) {
    if ($rec.messageType -ne $t.query) { return $false }
    $fs = $null; try { $fs = $rec.formState | ConvertFrom-Json } catch { return $false }
    if (-not $fs) { return $false }
    $fills = @($t.fills) | Where-Object { $_ }
    foreach ($fill in $fills) {
        $p = $fs.PSObject.Properties[$fill.fieldId]
        if (-not $p -or -not (Test-ValueMatch $fill.value $p.Value)) { return $false }
    }
    $plannedNames = @($fills | ForEach-Object { $_.fieldId.ToUpper() })
    $fam = $familyFillable[$t.query]; if (-not $fam) { $fam = @{} }
    $def = $defaultsByMt[$rec.messageType]; if (-not $def) { $def = @{} }
    foreach ($p in $fs.PSObject.Properties) {
        $n = $p.Name.ToUpper()
        if ("$($p.Value)".Trim() -eq '') { continue }
        if ($plannedNames -contains $n) { continue }
        if (-not $fam.ContainsKey($n)) { continue }   # not a fillable field in this family -> form default noise
        if ($def.ContainsKey($n)) { continue }        # identical in every record of this messageType -> default
        return $false                                  # a DIFFERENT test's optional rode along -> wrong test
    }
    return $true
}

function Get-Label($t) {
    if ($t.kind -eq 'guardrail') { return "$($t.expectedKeyRef)_guardrail" }
    if ($t.kind -eq 'any')       { return "$($t.comboKeyRef)_any" }
    if ($t.kind -eq 'any-field') { return "$($t.comboKeyRef)_af_$($t.anyField)" }
    return $t.comboKeyRef
}

$usedRec = @{}
$corrections = 0; $unmatchedTests = @(); $assigned = @{}
foreach ($t in $plan.tests) {
    $foundIdx = -1
    for ($i = $records.Count - 1; $i -ge 0; $i--) {   # newest last
        if ($usedRec[$i]) { continue }
        if (Test-RecordMatchesTest $records[$i] $t) { $foundIdx = $i; break }
    }
    if ($foundIdx -lt 0) { continue }   # test not in this batch (per-entity downloads are normal)
    $usedRec[$foundIdx] = $true
    $assigned[$foundIdx] = $t
}
for ($i = 0; $i -lt $records.Count; $i++) {
    if (-not $assigned.ContainsKey($i)) { continue }
    $t = $assigned[$i]; $r = $records[$i]
    $old = "$($r.combo)$(if ($r.anyField) { '_af_' + $r.anyField })$(if ($r.kind -eq 'any') { '_any' })$(if ($r.kind -eq 'guardrail') { '_guardrail' })"
    $new = Get-Label $t
    if ($old -ne $new) {
        $corrections++
        Write-Host "[relabel] $old -> $new (content match)" -ForegroundColor Yellow
    }
    $r.entity = $t.entity; $r.query = $t.query; $r.combo = $t.comboKeyRef
    $r | Add-Member -NotePropertyName expectedKeyRef -NotePropertyValue $t.expectedKeyRef -Force
    $r | Add-Member -NotePropertyName kind -NotePropertyValue $t.kind -Force
    $r | Add-Member -NotePropertyName anyField -NotePropertyValue $t.anyField -Force
    $r | Add-Member -NotePropertyName underFilled -NotePropertyValue $false -Force
}
$unassigned = @(0..($records.Count - 1) | Where-Object { -not $assigned.ContainsKey($_) })
if ($unassigned.Count) {
    Write-Host "[relabel] $($unassigned.Count) record(s) matched no plan test (keep browser label):" -ForegroundColor DarkYellow
    foreach ($i in $unassigned) { Write-Host "  $($records[$i].messageType) $($records[$i].combo) $($records[$i].formState)" }
}
$records | ConvertTo-Json -Depth 8 | Set-Content $BatchPath -Encoding utf8
Write-Host "[relabel] done: $($records.Count) record(s), $corrections label correction(s), $($unassigned.Count) unmatched." -ForegroundColor Green
