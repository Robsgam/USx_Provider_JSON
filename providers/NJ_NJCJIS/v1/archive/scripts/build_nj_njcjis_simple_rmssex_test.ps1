# build_nj_njcjis_simple_rmssex_test.ps1
#
# TEST VARIANT -- Simple variant WITH sex sent to RMS
#
# BASELINE: NJ_NJCJIS_simple.json (v1.0-simple, confirmed 2026-04-17)
# Current configuration: sex REMOVED from RMS Person QIDM (Patch 3).
# This test adds it back using the standard HIDLE pattern:
#   { name:"sex", sourceField:["SexCode"], targetField:"sexAttrId", useAttributeId:true }
#
# HYPOTHESIS: RMS receives sexAttrId:"M" (string NIBRS code).
# QUESTION:   Does RMS error? Return filtered results? Return unfiltered results?
#
# OUTPUT: NJ_NJCJIS_simple_rmssex.json
# =====================================================================

$DIR  = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$BASE = "$DIR\NJ_NJCJIS_simple.json"
$OUT  = "$DIR\NJ_NJCJIS_simple_rmssex.json"

Write-Host ""
Write-Host "========================================"
Write-Host " NJ_NJCJIS Simple Variant -- RMS Sex Test"
Write-Host " Add sexAttrId back to RMS Person QIDM"
Write-Host " Standard HIDLE pattern: useAttributeId=True, no code type refs"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path $BASE)) {
    Write-Host "ERROR: Base file not found: $BASE" -ForegroundColor Red
    exit 1
}

$d = Get-Content $BASE -Raw | ConvertFrom-Json

# =====================================================================
# Find RMS Person QIDM
# =====================================================================
$rmsBundle     = $d.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object {
    $_.targetEntity -eq 'Person' -and $_.type -eq 'QUERYINPUTDATAMAPPING'
}

if (-not $rmsPersonQidm) {
    Write-Host "ERROR: RMS Person QIDM not found" -ForegroundColor Red
    exit 1
}

# =====================================================================
# Add sex attribute -- standard HIDLE pattern
# =====================================================================
$sexAttr = [PSCustomObject]@{
    name           = 'sex'
    sourceField    = @('SexCode')
    targetField    = 'sexAttrId'
    useAttributeId = $true
}

$attrList = [System.Collections.Generic.List[object]]($rmsPersonQidm.attributes)
$attrList.Add($sexAttr)
$rmsPersonQidm.attributes = $attrList.ToArray()

Write-Host "Added RMS Person QIDM sex attribute:" -ForegroundColor Cyan
Write-Host "  name=sex  sourceField=[SexCode]  targetField=sexAttrId  useAttributeId=True"
Write-Host "  (no codeTypeCategory / codeTypeSource -- raw NIBRS code will flow)"
Write-Host ""

# =====================================================================
# Add SexCode to combination any[] so sex participates in routing
# =====================================================================
$combosUpdated = 0
foreach ($combo in $rmsPersonQidm.combinations) {
    $anyList = [System.Collections.Generic.List[string]]($combo.requirements.any)
    if (-not $anyList.Contains('SexCode')) {
        $anyList.Add('SexCode')
        $combo.requirements.any = $anyList.ToArray()
        $combosUpdated++
    }
}

Write-Host "Updated $combosUpdated combination(s) -- SexCode added to any[]" -ForegroundColor Cyan
Write-Host ""

($d | ConvertTo-Json -Depth 100) | Set-Content $OUT -Encoding UTF8

Write-Host "Output: $OUT" -ForegroundColor Green
Write-Host ""
Write-Host "========================================"
Write-Host " TEST INSTRUCTIONS"
Write-Host "========================================"
Write-Host ""
Write-Host "Import NJ_NJCJIS_simple_rmssex.json"
Write-Host "Person query -- Name + DOB + Sex (select Male)"
Write-Host ""
Write-Host "STEP 1 -- CommSys XML <SexCode>:"
Write-Host "  'M'            -> correct (form unchanged)                    [EXPECTED]"
Write-Host ""
Write-Host "STEP 2 -- RMS elastic sexAttrId:"
Write-Host "  sexAttrId:'M'  -> string NIBRS code sent; watch RMS response  [EXPECTED]"
Write-Host "  absent         -> combination not firing                      [UNEXPECTED]"
Write-Host ""
Write-Host "STEP 3 -- RMS response:"
Write-Host "  Results returned   -> RMS accepts string 'M'; may or may not filter"
Write-Host "  No results         -> RMS filters on 'M' but finds no match (probably not working)"
Write-Host "  400 / error        -> RMS rejects string value for sexAttrId"
Write-Host ""
Write-Host "If RMS returns results: compare count with/without sex to determine if filtering."
Write-Host ""
