<#
  audit_guide_completeness.ps1 -- IS EVERY BUILT COMBINATION ACCOUNTED FOR ON THE OFFICER GUIDE?

  Rob, 2026-09-04: "are the officer guides fully correct? do we have all combo accounted for and
  any explcit form field helpers incldued on the guide like leave blank for XX in teh state
  context."

  WHY THIS IS NOT ANSWERABLE BY EYE, AND WHY A ROW COUNT WILL NOT DO IT EITHER. The guide emits
  ONE OR TWO rows per combination (two when State is optional and ungated -- the in-state and
  out-of-state split), so rows > combos is normal and tells you nothing about whether a
  combination was DROPPED. Worse, render_officer_guide.ps1 contains a silent skip:

      if ($reqParts.Count -eq 0 -and $optParts.Count -eq 0) { continue }

  A combination whose every field is HIDDEN produces no row and no warning -- it simply is not on
  the sheet a department reads. That is the same shape as every other defect this repo catalogues:
  absence that looks exactly like correctness.

  So this predicts the row count from the JSON using the renderer's OWN rules, and reports any
  combination that contributes zero rows, by name.

  CLASSES
    DROPPED    the combination emits no row -- every field hidden, or otherwise skipped
    SPLIT      emits two rows (in-state + out-of-state). Expected; counted so the arithmetic closes.
    PLAIN      emits one row.
  A provider is COMPLETE when DROPPED = 0 and predicted rows == rows actually in the HTML.
#>
param([string[]]$Providers, [switch]$Quiet)

. "$PSScriptRoot\..\_probe.ps1"

$scope = if ($Providers) { $Providers } else { Get-ProbeProviders }
Assert-ProbeNonZero $scope.Count 'providers in scope'

$repo = Get-ProbeRepoRoot
$totCombos = 0; $totPredicted = 0; $totDropped = 0; $totSplit = 0; $mismatch = @(); $dropped = @()

foreach ($p in $scope) {
    $guide = Join-Path $repo "providers\$p\docs\deliverables\OFFICER_GUIDE_$p.html"
    if (-not (Test-Path $guide)) { Write-Output ("  {0,-24} NO GUIDE" -f $p); continue }

    $combos = Get-ProbeCombos -Provider $p
    $predicted = 0; $split = 0; $drop = 0

    foreach ($r in $combos) {
        $totCombos++
        $ent = "$($r.Entity)"
        # hidden fields never render -- same rule the renderer applies
        $nodes = @(Get-ProbeFormNodes -Provider $p -Entity $ent)
        $hidden = @{}
        foreach ($n in $nodes) {
            $fid = "$($n.props.fieldId)"
            if ($fid -and $n.hidden) { $hidden[$fid.ToLower()] = $true }
        }
        $visSet = @($r.Set | Where-Object { -not $hidden[("$_").ToLower()] })
        $visAny = @($r.Any | Where-Object { -not $hidden[("$_").ToLower()] })

        # condition-required fields are promoted into Required, so they count as visible content
        $condReq = @()
        foreach ($c in $r.Conditions) {
            $op = "$($c.operator)".ToUpperInvariant()
            if ($op -eq 'EXISTS' -or $op -eq 'IN') {
                foreach ($f in @($c.field)) { if ($f -and -not $hidden[("$f").ToLower()]) { $condReq += "$f" } }
            }
        }
        if ($visSet.Count -eq 0 -and $visAny.Count -eq 0 -and $condReq.Count -eq 0) {
            $drop++; $totDropped++
            $dropped += [pscustomobject]@{ Provider=$p; Entity=$ent; KeyRef=$r.KeyRef; Query=$r.Query }
            continue
        }

        # does it split? State optional, ungated, and not a stolen-check row
        $stateFld = @($r.Any | Where-Object { "$_" -match '(?i)^(registration)?state' }) | Select-Object -First 1
        $stateGated = @($r.Conditions | Where-Object { (@($_.field) -join ',') -match '(?i)^(registration)?state' }).Count -gt 0
        $isStolen = @($r.Set | Where-Object { "$_" -match '(?i)relatedHit|stolen' }).Count -gt 0
        if ($stateFld -and -not $stateGated -and -not $isStolen) { $predicted += 2; $split++; $totSplit++ }
        else { $predicted += 1 }
    }

    $html = Get-Content $guide -Raw
    $actual = ([regex]::Matches($html, "<td class='sb'>")).Count
    $totPredicted += $predicted
    $flag = ''
    if ($actual -ne $predicted) { $flag = "  <-- MISMATCH"; $mismatch += "$p (predicted $predicted, guide $actual)" }
    if (-not $Quiet) {
        Write-Output ("  {0,-24} combos={1,-4} split={2,-3} dropped={3,-3} predicted-rows={4,-4} guide-rows={5,-4}{6}" -f `
            $p, $combos.Count, $split, $drop, $predicted, $actual, $flag)
    }
}

Assert-ProbeNonZero $totCombos 'built combinations compared'

Write-Output ''
Write-Output ("  TOTALS: {0} combos / {1} split / {2} DROPPED / {3} predicted rows" -f $totCombos, $totSplit, $totDropped, $totPredicted)
if ($dropped.Count -gt 0) {
    Write-Output '  [DROPPED] these combinations produce NO ROW on the officer guide:'
    foreach ($d in $dropped) { Write-Output ("     {0,-24} {1,-9} {2} ({3})" -f $d.Provider, $d.Entity, $d.KeyRef, $d.Query) }
}
if ($mismatch.Count -gt 0) {
    Write-Output '  [MISMATCH] predicted row count != guide row count:'
    foreach ($m in $mismatch) { Write-Output "     $m" }
} else {
    Write-Output '  [OK] every provider: predicted rows == guide rows'
}
