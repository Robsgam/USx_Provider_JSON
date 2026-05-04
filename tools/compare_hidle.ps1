# compare_hidle.ps1
# Compares a new HIDLE.json against the current one used by NY and NJ.
# Reports structural differences, added/removed attrs, changed combos,
# and flags impact on NY_NYSPIN_EJUSTICE and NJ_NJCJIS builds.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File compare_hidle.ps1 -NewHidle <path-to-new-HIDLE.json>
#
# The current HIDLE is read from NJ_NJCJIS/source/HIDLE.json (identical to NY copy).

param(
    [Parameter(Mandatory=$true)]
    [string]$NewHidle
)

$currentPath = (Resolve-Path "$PSScriptRoot\..\templates\HIDLE.json").Path

if (-not (Test-Path $NewHidle))  { Write-Host "ERROR: $NewHidle not found"; exit 1 }
if (-not (Test-Path $currentPath)) { Write-Host "ERROR: $currentPath not found"; exit 1 }

$cur = Get-Content $currentPath -Raw | ConvertFrom-Json
$new = Get-Content $NewHidle -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "========================================"
Write-Host " HIDLE.json COMPARISON"
Write-Host "========================================"
Write-Host " Current: $currentPath"
Write-Host " New:     $NewHidle"
Write-Host ""

# --- Bundle-level comparison ---
Write-Host "--- BUNDLE STRUCTURE ---"
Write-Host "Current bundles: $($cur.bundles.Count)"
Write-Host "New bundles:     $($new.bundles.Count)"
foreach ($b in $new.bundles) {
    $match = $cur.bundles | Where-Object { $_.name -eq $b.name }
    if ($match) {
        $curCount = $match.configurations.Count
        $newCount = $b.configurations.Count
        $status = if ($curCount -eq $newCount) { "SAME" } else { "CHANGED ($curCount -> $newCount)" }
        Write-Host "  Bundle '$($b.name)': configs $status"
    } else {
        Write-Host "  Bundle '$($b.name)': NEW (not in current)"
    }
}
foreach ($b in $cur.bundles) {
    $match = $new.bundles | Where-Object { $_.name -eq $b.name }
    if (-not $match) {
        Write-Host "  Bundle '$($b.name)': REMOVED (in current, not in new)"
    }
}
Write-Host ""

# --- QRDM comparison (consumed by build scripts) ---
Write-Host "--- QUERYRESULTDATAMAPPING (bundles[0]) ---"
$curQrdm = $cur.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$newQrdm = $new.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }

if ($curQrdm -and $newQrdm) {
    Write-Host "Current attrs: $($curQrdm.attributes.Count)  New attrs: $($newQrdm.attributes.Count)"
    Write-Host "Current combos: $($curQrdm.combinations.Count)  New combos: $($newQrdm.combinations.Count)"

    $curAttrNames = @($curQrdm.attributes | ForEach-Object { $_.name })
    $newAttrNames = @($newQrdm.attributes | ForEach-Object { $_.name })
    $added = $newAttrNames | Where-Object { $_ -notin $curAttrNames }
    $removed = $curAttrNames | Where-Object { $_ -notin $newAttrNames }
    if ($added)   { Write-Host "  ADDED attrs:   $($added -join ', ')" }
    if ($removed) { Write-Host "  REMOVED attrs: $($removed -join ', ')" }
    if (-not $added -and -not $removed) { Write-Host "  Attr names: IDENTICAL" }

    foreach ($newAttr in $newQrdm.attributes) {
        $curAttr = $curQrdm.attributes | Where-Object { $_.name -eq $newAttr.name }
        if ($curAttr) {
            $curTf = $curAttr.targetField
            $newTf = $newAttr.targetField
            $curCat = $curAttr.codeTypeCategory
            $newCat = $newAttr.codeTypeCategory
            $curSrc = $curAttr.codeTypeSource
            $newSrc = $newAttr.codeTypeSource
            $diffs = @()
            if ($curTf -ne $newTf) { $diffs += "targetField: $curTf -> $newTf" }
            if ($curCat -ne $newCat) { $diffs += "codeTypeCategory: $curCat -> $newCat" }
            if ($curSrc -ne $newSrc) { $diffs += "codeTypeSource: $curSrc -> $newSrc" }
            if ($diffs.Count -gt 0) {
                Write-Host "  CHANGED: $($newAttr.name) -- $($diffs -join '; ')"
            }
        }
    }
} else {
    Write-Host "  WARNING: QRDM not found in one or both files"
}
Write-Host ""

# --- RMS Bundle comparison ---
Write-Host "--- RMS BUNDLE ---"
$curRms = $cur.bundles | Where-Object { $_.name -eq 'RMS' }
$newRms = $new.bundles | Where-Object { $_.name -eq 'RMS' }

if ($curRms -and $newRms) {
    foreach ($configType in @('Vehicle','Person')) {
        $queryName = if ($configType -eq 'Vehicle') { 'Vehicle' } else { 'Person' }
        $curQidm = $curRms.configurations | Where-Object { $_.query -eq $queryName }
        $newQidm = $newRms.configurations | Where-Object { $_.query -eq $queryName }

        if ($curQidm -and $newQidm) {
            Write-Host ""
            Write-Host "  RMS $configType QIDM:"
            Write-Host "    Current attrs: $($curQidm.attributes.Count)  New attrs: $($newQidm.attributes.Count)"
            Write-Host "    Current combos: $($curQidm.combinations.Count)  New combos: $($newQidm.combinations.Count)"

            $curNames = @($curQidm.attributes | ForEach-Object { $_.name })
            $newNames = @($newQidm.attributes | ForEach-Object { $_.name })
            $added = $newNames | Where-Object { $_ -notin $curNames }
            $removed = $curNames | Where-Object { $_ -notin $newNames }
            if ($added)   { Write-Host "    ADDED attrs:   $($added -join ', ')" }
            if ($removed) { Write-Host "    REMOVED attrs: $($removed -join ', ')" }
            if (-not $added -and -not $removed) { Write-Host "    Attr names: IDENTICAL" }

            foreach ($newAttr in $newQidm.attributes) {
                $curAttr = $curQidm.attributes | Where-Object { $_.name -eq $newAttr.name }
                if ($curAttr) {
                    $diffs = @()
                    if ("$($curAttr.targetField)" -ne "$($newAttr.targetField)") { $diffs += "targetField: $($curAttr.targetField) -> $($newAttr.targetField)" }
                    if ("$($curAttr.useAttributeId)" -ne "$($newAttr.useAttributeId)") { $diffs += "useAttributeId: $($curAttr.useAttributeId) -> $($newAttr.useAttributeId)" }
                    if ($diffs.Count -gt 0) {
                        Write-Host "    CHANGED: $($newAttr.name) -- $($diffs -join '; ')"
                    }
                }
            }

            $curKeyRefs = @($curQidm.combinations | ForEach-Object { $_.keyReference })
            $newKeyRefs = @($newQidm.combinations | ForEach-Object { $_.keyReference })
            $addedCombos = $newKeyRefs | Where-Object { $_ -notin $curKeyRefs }
            $removedCombos = $curKeyRefs | Where-Object { $_ -notin $newKeyRefs }
            if ($addedCombos)   { Write-Host "    ADDED combos:   $($addedCombos -join ', ')" }
            if ($removedCombos) { Write-Host "    REMOVED combos: $($removedCombos -join ', ')" }

            foreach ($newCombo in $newQidm.combinations) {
                $curCombo = $curQidm.combinations | Where-Object { $_.keyReference -eq $newCombo.keyReference }
                if ($curCombo) {
                    $curSet = ($curCombo.requirements.set | Sort-Object) -join ','
                    $newSet = ($newCombo.requirements.set | Sort-Object) -join ','
                    $curAny = ($curCombo.requirements.any | Sort-Object) -join ','
                    $newAny = ($newCombo.requirements.any | Sort-Object) -join ','
                    $diffs = @()
                    if ($curSet -ne $newSet) { $diffs += "set: [$curSet] -> [$newSet]" }
                    if ($curAny -ne $newAny) { $diffs += "any: [$curAny] -> [$newAny]" }
                    if ($diffs.Count -gt 0) {
                        Write-Host "    CHANGED combo '$($newCombo.keyReference)': $($diffs -join '; ')"
                    }
                }
            }
        }
    }

    # RMS Auth and QMF
    $curAuth = $curRms.configurations | Where-Object { $_.type -eq 'AUTHENTICATION' }
    $newAuth = $newRms.configurations | Where-Object { $_.type -eq 'AUTHENTICATION' }
    if ($curAuth -and $newAuth) {
        $curAuthJson = $curAuth | ConvertTo-Json -Depth 10 -Compress
        $newAuthJson = $newAuth | ConvertTo-Json -Depth 10 -Compress
        $authStatus = if ($curAuthJson -eq $newAuthJson) { "IDENTICAL" } else { "CHANGED" }
        Write-Host ""
        Write-Host "  RMS Auth: $authStatus"
    }

    $curQmf = $curRms.configurations | Where-Object { $_.type -eq 'QUERYMESSAGEFORMAT' }
    $newQmf = $newRms.configurations | Where-Object { $_.type -eq 'QUERYMESSAGEFORMAT' }
    if ($curQmf -and $newQmf) {
        $curQmfJson = $curQmf | ConvertTo-Json -Depth 10 -Compress
        $newQmfJson = $newQmf | ConvertTo-Json -Depth 10 -Compress
        $qmfStatus = if ($curQmfJson -eq $newQmfJson) { "IDENTICAL" } else { "CHANGED" }
        Write-Host "  RMS QMF: $qmfStatus"
    }
} else {
    Write-Host "  WARNING: RMS bundle not found in one or both files"
}

Write-Host ""
Write-Host "--- IMPACT ASSESSMENT ---"
Write-Host ""
Write-Host "Build scripts consume TWO things from HIDLE:"
Write-Host "  1. QUERYRESULTDATAMAPPING (cloned, renamed to provider-specific)"
Write-Host "  2. RMS bundle (cloned, then Patches 1/3/6 applied)"
Write-Host ""
Write-Host "If QRDM changed: rebuild both NY and NJ (result mappings updated)"
Write-Host "If RMS Vehicle changed: rebuild both (patches may need adjustment)"
Write-Host "If RMS Person changed: rebuild both (patches may need adjustment)"
Write-Host "If only ENTITIES/CommSys QIDMs changed: no impact (build scripts ignore these)"
Write-Host ""
Write-Host "NEXT STEPS:"
Write-Host "  1. Review changes above"
Write-Host "  2. Copy new HIDLE to NJ_NJCJIS/source/ and NY_NYSPIN_EJUSTICE/source/"
Write-Host "  3. Rebuild: build_nj_njcjis.ps1 + build_nj_njcjis_mc.ps1"
Write-Host "  4. Rebuild: build_ny_nyspin_ejustice.ps1 + build_ny_nyspin_ejustice_mc.ps1"
Write-Host "  5. Diff new outputs against current JSONs"
Write-Host "  6. Re-run validator on all 4 JSONs"
Write-Host "  7. If RMS attrs/combos changed: may need to re-test on instance"
Write-Host ""
Write-Host "========================================"
Write-Host " COMPARISON COMPLETE"
Write-Host "========================================"
