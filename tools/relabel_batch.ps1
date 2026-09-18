<#
  relabel_batch.ps1 -- content-based batch relabeler (pipeline stage before import).

  Browser-side label pairing is unreliable whenever tests share identifier values and
  differ only in optional fields (CA 2026-07-02: whole batch scrambled twice; NJ Firearm:
  labels rotated within the family). Record CONTENT (dex-log formState) is ground truth.
  Matching logic shared with audit_log_content.ps1 via _content_match.ps1.

  With the deterministic positional pass-1 in capture.js (2026-07-02), a clean run should
  need ZERO corrections here -- any correction is a process error for the zero-error gate.

  Relabels IN PLACE (rewrites the batch file) and reports corrections. Records that match
  no plan test keep their browser label and are reported (import will still process them).

  Usage: .\tools\relabel_batch.ps1 -BatchPath <file> [-PlanPath <file>]
         (PlanPath auto-resolved from the records' provider + version when omitted)
#>
param(
    [Parameter(Mandatory)][string]$BatchPath,
    [string]$PlanPath,
    [switch]$KeepUnmatched   # forensics only; default DROPS records matching no plan test
)

. (Join-Path $PSScriptRoot '_content_match.ps1')

$records = Get-Content $BatchPath -Raw | ConvertFrom-Json
if (-not $records -or -not @($records).Count) { Write-Host "[relabel] empty batch -- nothing to do"; exit 0 }
$records = @($records)

# Picklist scope downloads route elsewhere; guard anyway.
if ($records[0].PSObject.Properties['options'] -or ($records[0].PSObject.Properties['fields'] -and -not $records[0].PSObject.Properties['requestXml'])) {
    Write-Host "[relabel] not a test batch (picklist scope?) -- skipping relabel"; exit 0
}

if (-not $PlanPath) {
    $prov = ($records | Where-Object { $_.provider } | Select-Object -First 1).provider
    if (-not $prov) { Write-Host "[relabel] no provider in records; skipping relabel"; exit 0 }
    $provDir = Join-Path (Join-Path $PSScriptRoot '..\providers') $prov
    $PlanPath = Get-ChildItem (Join-Path $provDir 'logs') -Filter "${prov}_TEST_PLAN_v*.json" -ErrorAction SilentlyContinue |
                Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
    if (-not $PlanPath) { Write-Host "[relabel] no TEST_PLAN for $prov; skipping relabel"; exit 0 }
}
$plan = Get-Content $PlanPath -Raw | ConvertFrom-Json

$familyFillable = Build-CmFamilyFillable $plan
$snapshots = @($records | ForEach-Object {
    $fs = $null
    # formState is a JSON string on labeled records but an OBJECT on unlabeled-path records
    # (bulk fetch attaches parsedRawQuery directly) -- piping an object to ConvertFrom-Json
    # throws, which silently unmatched 7 otherwise-recognizable stale rows (2026-07-02).
    if ($_.formState -is [string]) { try { $fs = $_.formState | ConvertFrom-Json } catch {} }
    elseif ($_.formState) { $fs = $_.formState }
    # pscustomobject, NOT hashtable: PS 5.1 Group-Object can't resolve hashtable properties.
    [pscustomobject]@{ messageType = $_.messageType; fs = $fs }
})
# When the plan carries authoritative QIF formDefaults, dynamic dominance guessing is OFF:
# it mis-classified vehicleYear residue as a "default" and let T6/T7 rows pass as T4/T5
# (2026-07-02). Dynamic defaults remain only as a fallback for legacy plans without them.
$defaultsByMt = if ($plan.formDefaults) { @{} } else { Build-CmDefaults $snapshots }

# Three-tier assignment.
# Tier 0 -- LABEL STABILITY: a record whose EXISTING label content-matches keeps it. Some
#   test pairs are content-identical on purpose (an any-field's value equals the form
#   default, e.g. ImageIndicator=N), so any content-only assignment between them is
#   arbitrary -- the relabeler was "correcting" correct browser labels forever
#   (19 phantom corrections, 2026-07-02). Real contradictions still get relabeled below.
# Tier 1 -- EXACT content matches (no ignored extras) claim records next.
# Tier 2 -- content match with defaults tolerated.
function Test-CmExact($fs, $mt, $t, $fam) { Test-CmSnapshotMatchesTest $fs $mt $t $fam @{} $null }
function Get-CmRecordLabel($r) {
    if ($r.kind -eq 'guardrail') {
        if ($r.guardrailLoser) { return "$($r.expectedKeyRef)_guardrail_vs_$($r.guardrailLoser)" }
        return "$($r.expectedKeyRef)_guardrail"
    }
    if ($r.kind -eq 'value-strip') { return "$($r.combo)_strip_$($r.strippedField)" }
    return "$($r.combo)$(if ($r.anyField) { '_af_' + $r.anyField })$(if ($r.kind -eq 'any') { '_any' })"
}
$usedRec = @{}
$assigned = @{}
foreach ($tier in 0, 1, 2) {
    foreach ($t in $plan.tests) {
        if (@($assigned.Values | Where-Object { $_ -eq $t }).Count) { continue }
        $fd = if ($plan.formDefaults) { $plan.formDefaults.PSObject.Properties[$t.entity].Value } else { $null }
        $tLabel = Get-CmPlanLabel $t
        $foundIdx = -1
        for ($i = $records.Count - 1; $i -ge 0; $i--) {   # newest last
            if ($usedRec[$i]) { continue }
            $hit = switch ($tier) {
                0 { (Get-CmRecordLabel $records[$i]) -eq $tLabel -and (Test-CmSnapshotMatchesTest $snapshots[$i].fs $records[$i].messageType $t $familyFillable $defaultsByMt $fd) }
                1 { Test-CmExact $snapshots[$i].fs $records[$i].messageType $t $familyFillable }
                2 { Test-CmSnapshotMatchesTest $snapshots[$i].fs $records[$i].messageType $t $familyFillable $defaultsByMt $fd }
            }
            if ($hit) { $foundIdx = $i; break }
        }
        if ($foundIdx -lt 0) { continue }
        $usedRec[$foundIdx] = $true
        $assigned[$foundIdx] = $t
    }
}

# ── TIER 3: CO-FIRE SIBLINGS (added 2026-09-18) ────────────────────────────────────────────
# The loop above assigns AT MOST ONE record per test -- correct for a normal submit, and the
# reason a co-firing one loses rows. A single fill can send several transactions, and every row
# after the first had no test left to claim it, so it fell through to "unmatched" and was
# DROPPED. That is not a labelling nicety: each of those rows is the only wire evidence that its
# query fired. Measured 2026-09-18 -- 30 rows across two files, and relabel matched 0 of them,
# CORRECTLY, because nothing had told it those rows were expected.
# `alsoFires` (emit_test_plan) now names them per test, simulated with the same canonical firing
# walk that produces expectedKeyRef, so this pass has an authority to match against rather than
# a heuristic. It only ever looks at records the first three tiers left UNUSED, so it cannot
# steal a row from a real test, and it requires BOTH the sibling's messageType AND the parent
# test's exact fill-set -- the same content check, narrowed rather than loosened.
$assignedCf = @{}
foreach ($t in $plan.tests) {
    foreach ($af in @($t.alsoFires)) {
        if (-not $af -or -not $af.query) { continue }
        $fdc = if ($plan.formDefaults) { $plan.formDefaults.PSObject.Properties[$t.entity].Value } else { $null }
        for ($i = $records.Count - 1; $i -ge 0; $i--) {
            if ($usedRec[$i]) { continue }
            if ("$($records[$i].messageType)" -ne "$($af.query)") { continue }
            if (-not (Test-CmSnapshotMatchesTest $snapshots[$i].fs $records[$i].messageType $t $familyFillable $defaultsByMt $fdc -ExpectQuery "$($af.query)")) { continue }
            $usedRec[$i] = $true
            $assignedCf[$i] = [pscustomobject]@{ Test = $t; Af = $af }
            break
        }
    }
}
if ($assignedCf.Keys.Count) {
    Write-Host "[relabel] $($assignedCf.Keys.Count) CO-FIRE sibling row(s) matched -- extra transactions their submit also sent, kept as evidence instead of dropped" -ForegroundColor Cyan
}

$corrections = 0
for ($i = 0; $i -lt $records.Count; $i++) {
    if ($assignedCf.ContainsKey($i)) {
        # A sibling is labelled from its OWN query/keyRef, not the parent's -- the log must say
        # which transaction this wire row IS. coFireOf carries the parent so import_captured_tests
        # can suffix the filename and stop a sibling clobbering a same-keyRef test's own log.
        $cf = $assignedCf[$i]; $r = $records[$i]
        $r.entity = $cf.Test.entity; $r.query = "$($cf.Af.query)"; $r.combo = "$($cf.Af.keyRef)"
        $r | Add-Member -NotePropertyName expectedKeyRef -NotePropertyValue "$($cf.Af.keyRef)" -Force
        $r | Add-Member -NotePropertyName kind           -NotePropertyValue 'co-fire' -Force
        $r | Add-Member -NotePropertyName coFireOf       -NotePropertyValue $cf.Test.n -Force
        $r | Add-Member -NotePropertyName anyField       -NotePropertyValue $null -Force
        $r | Add-Member -NotePropertyName guardrailLoser -NotePropertyValue $null -Force
        $r | Add-Member -NotePropertyName strippedField  -NotePropertyValue $null -Force
        $r | Add-Member -NotePropertyName strippedValue  -NotePropertyValue $null -Force
        if (-not $r.PSObject.Properties['underFilled']) {
            $r | Add-Member -NotePropertyName underFilled -NotePropertyValue $false -Force
        }
        $r | Add-Member -NotePropertyName contentMatched -NotePropertyValue $true -Force
        continue
    }
    if (-not $assigned.ContainsKey($i)) { continue }
    $t = $assigned[$i]; $r = $records[$i]
    # guardrail records have combo=null by design -- reconstruct their old label from
    # expectedKeyRef, else a correctly-paired guardrail reads as a bogus "correction".
    $old = Get-CmRecordLabel $r
    $new = Get-CmPlanLabel $t
    if ($old -ne $new) {
        $corrections++
        Write-Host "[relabel] $old -> $new (content match)" -ForegroundColor Yellow
    }
    $r.entity = $t.entity; $r.query = $t.query; $r.combo = $t.comboKeyRef
    $r | Add-Member -NotePropertyName expectedKeyRef -NotePropertyValue $t.expectedKeyRef -Force
    $r | Add-Member -NotePropertyName kind -NotePropertyValue $t.kind -Force
    $r | Add-Member -NotePropertyName anyField -NotePropertyValue $t.anyField -Force
    $r | Add-Member -NotePropertyName guardrailLoser -NotePropertyValue $t.guardrailLoser -Force
    $r | Add-Member -NotePropertyName strippedField -NotePropertyValue $t.strippedField -Force
    $r | Add-Member -NotePropertyName strippedValue -NotePropertyValue $t.strippedValue -Force
    # underFilled is an OBSERVATION FROM THE BROWSER, not a plan fact -- unlike every other property
    # set in this block, which is resolved FROM the matched plan test $t and so must be forced.
    # driver.js:211 records `underFilled: !filled` when a form field failed to fill; capture.js:398
    # carries it through; import_captured_tests.ps1:239/265 stamps "UNDER-FILLED" into the log NOTES
    # and warns. This line used to force $false unconditionally, and watch_captures.ps1:83 relabels
    # 100% of automated imports -- so the signal was destroyed before its only consumer ran, and
    # those two lines were dead code on every automated capture ever taken. Default when ABSENT only.
    if (-not $r.PSObject.Properties['underFilled']) {
        $r | Add-Member -NotePropertyName underFilled -NotePropertyValue $false -Force
    }
    $r | Add-Member -NotePropertyName contentMatched -NotePropertyValue $true -Force
}
# A co-fire sibling IS assigned -- to its parent test via $assignedCf -- so it must not be
# counted here or it would be reported unmatched AND written to the drop sidecar while also
# being imported. Omitting this was the first draft's bug and it would have looked like the
# fix had failed.
$unassigned = @(0..($records.Count - 1) | Where-Object { -not $assigned.ContainsKey($_) -and -not $assignedCf.ContainsKey($_) })
if ($unassigned.Count) {
    $action = if ($KeepUnmatched) { 'kept (browser label)' } else { 'DROPPED from import (unreliable browser label -- a stale row can re-create a retired log, 2026-07-02)' }
    $lvl = if ($KeepUnmatched) { 'DarkYellow' } else { 'Yellow' }
    Write-Host "[relabel] WARN: $($unassigned.Count) capture(s) matched NO plan test -- ${action}:" -ForegroundColor $lvl
    foreach ($i in $unassigned) { Write-Host "  $($records[$i].messageType) $($records[$i].combo) $($records[$i].formState)" }
    if (-not $KeepUnmatched) {
        # Never silently lose a dropped capture: preserve the unmatched records to a sidecar for
        # audit (an off-plan fill, or a genuine anomaly whose input matched no plan test, lands here
        # instead of vanishing). Import still ignores them -- the anti-stale-row protection stays.
        $sidecar = "$BatchPath.unmatched.json"
        ConvertTo-Json -InputObject @($unassigned | ForEach-Object { $records[$_] }) -Depth 8 | Set-Content $sidecar -Encoding utf8
        Write-Host "[relabel] unmatched capture(s) preserved for audit -> $sidecar" -ForegroundColor DarkYellow
    }
}
# Co-fire siblings must SURVIVE to the written batch -- they are the whole point of the pass.
# Filtering on $assigned alone would relabel them correctly and then throw them away, which is
# indistinguishable from the bug being fixed.
$outRecords = if ($KeepUnmatched) { $records } else { @(0..($records.Count - 1) | Where-Object { $assigned.ContainsKey($_) -or $assignedCf.ContainsKey($_) } | ForEach-Object { $records[$_] }) }
# -InputObject keeps an empty set as literal "[]" -- piping @() emits NOTHING, so the file
# was never truncated and the import processed the dropped records anyway (2026-07-02).
ConvertTo-Json -InputObject @($outRecords) -Depth 8 | Set-Content $BatchPath -Encoding utf8
Write-Host "[relabel] done: $(@($outRecords).Count) record(s) written, $corrections label correction(s), $($unassigned.Count) unmatched." -ForegroundColor Green
