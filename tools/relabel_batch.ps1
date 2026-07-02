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
    if ($_.formState) { try { $fs = $_.formState | ConvertFrom-Json } catch {} }
    # pscustomobject, NOT hashtable: PS 5.1 Group-Object can't resolve hashtable properties.
    [pscustomobject]@{ messageType = $_.messageType; fs = $fs }
})
$defaultsByMt = Build-CmDefaults $snapshots

$usedRec = @{}
$assigned = @{}
foreach ($t in $plan.tests) {
    $fd = if ($plan.formDefaults) { $plan.formDefaults.PSObject.Properties[$t.entity].Value } else { $null }
    $foundIdx = -1
    for ($i = $records.Count - 1; $i -ge 0; $i--) {   # newest last
        if ($usedRec[$i]) { continue }
        if (Test-CmSnapshotMatchesTest $snapshots[$i].fs $records[$i].messageType $t $familyFillable $defaultsByMt $fd) { $foundIdx = $i; break }
    }
    if ($foundIdx -lt 0) { continue }   # test not in this batch (per-entity downloads are normal)
    $usedRec[$foundIdx] = $true
    $assigned[$foundIdx] = $t
}

$corrections = 0
for ($i = 0; $i -lt $records.Count; $i++) {
    if (-not $assigned.ContainsKey($i)) { continue }
    $t = $assigned[$i]; $r = $records[$i]
    $old = "$($r.combo)$(if ($r.anyField) { '_af_' + $r.anyField })$(if ($r.kind -eq 'any') { '_any' })$(if ($r.kind -eq 'guardrail') { '_guardrail' })"
    $new = Get-CmPlanLabel $t
    if ($old -ne $new) {
        $corrections++
        Write-Host "[relabel] $old -> $new (content match)" -ForegroundColor Yellow
    }
    $r.entity = $t.entity; $r.query = $t.query; $r.combo = $t.comboKeyRef
    $r | Add-Member -NotePropertyName expectedKeyRef -NotePropertyValue $t.expectedKeyRef -Force
    $r | Add-Member -NotePropertyName kind -NotePropertyValue $t.kind -Force
    $r | Add-Member -NotePropertyName anyField -NotePropertyValue $t.anyField -Force
    $r | Add-Member -NotePropertyName underFilled -NotePropertyValue $false -Force
    $r | Add-Member -NotePropertyName contentMatched -NotePropertyValue $true -Force
}
$unassigned = @(0..($records.Count - 1) | Where-Object { -not $assigned.ContainsKey($_) })
if ($unassigned.Count) {
    $action = if ($KeepUnmatched) { 'kept (browser label)' } else { 'DROPPED (unreliable browser label; a stale morning row re-created a retired log on 2026-07-02)' }
    Write-Host "[relabel] $($unassigned.Count) record(s) matched no plan test -- ${action}:" -ForegroundColor DarkYellow
    foreach ($i in $unassigned) { Write-Host "  $($records[$i].messageType) $($records[$i].combo) $($records[$i].formState)" }
}
$outRecords = if ($KeepUnmatched) { $records } else { @(0..($records.Count - 1) | Where-Object { $assigned.ContainsKey($_) } | ForEach-Object { $records[$_] }) }
$outRecords | ConvertTo-Json -Depth 8 | Set-Content $BatchPath -Encoding utf8
Write-Host "[relabel] done: $(@($outRecords).Count) record(s) written, $corrections label correction(s), $($unassigned.Count) unmatched." -ForegroundColor Green
