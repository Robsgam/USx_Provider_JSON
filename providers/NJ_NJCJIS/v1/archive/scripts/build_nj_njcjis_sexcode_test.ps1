# build_nj_njcjis_sexcode_test.ps1
#
# TEST VARIANT -- NJ NJCJIS SexCode Option K
#
# OPTION J RESULT (2026-04-17):
#   Form codeTypeCategory=NIBRS_SEX/NCIC resolves to numeric attribute ID on form.
#   CommSys XML: <SexCode>69509891711</SexCode> -- FAIL (codeTypeProvider=NIBRS did not convert)
#   RMS elastic: sexAttrId:"69509891711" (string) -- value correct; RMS no fatal error
#   Dropdown: shows numeric code first -- ugly UX
#
# HYPOTHESIS (Option K):
#   Form stays on standard NIBRS_SEX/NIBRS (M/F/U -- correct CommSys, good UX).
#   RMS QIDM sex attribute adds codeTypeCategory=NIBRS_SEX + codeTypeSource=NCIC.
#   If engineering wired useAttributeId=True + code type refs at QIDM attribute level:
#     Input "M" -> look up RMS_SEX entry by NIBRS code -> return attribute ID 69509891711
#     RMS elastic: sexAttrId:69509891711 (integer)  [SUCCESS]
#     CommSys XML: <SexCode>M</SexCode>              [SUCCESS -- form unchanged]
#
# CHANGES:
#   CHANGE 1 -- Form fields: codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS (standard/unchanged)
#   CHANGE 2 -- CommSys QIDM SexCode: no change (codeTypeProvider=NIBRS, no rule)
#   CHANGE 3 -- RMS QIDM sex attribute: useAttributeId=True
#               + codeTypeCategory=NIBRS_SEX, codeTypeSource=NCIC on the QIDM attribute
#
# OUTPUT: NJ_NJCJIS_SexCode_OptionK.json
# =====================================================================

$DIR  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BASE = "$DIR\NJ_NJCJIS.json"
$OUTK = "$DIR\NJ_NJCJIS_SexCode_OptionK.json"

Write-Host ""
Write-Host "========================================"
Write-Host " NJ_NJCJIS SexCode Test Build -- Option K"
Write-Host " NIBRS_SEX/NIBRS form + codeTypeCategory on RMS QIDM attribute"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path $BASE)) {
    Write-Host "ERROR: Base file not found: $BASE" -ForegroundColor Red
    exit 1
}

$dK = Get-Content $BASE -Raw | ConvertFrom-Json

# =====================================================================
# CHANGE 1 -- Form fields: standard NIBRS_SEX/NIBRS (production config -- no change needed)
#   Production NJ_NJCJIS.json already has codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS.
#   Verify the fields are present and correct; report count only.
# =====================================================================
$entitiesBundle = $dK.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$formFieldsFound = 0

foreach ($config in $entitiesBundle.configurations) {
    if ($config.type -ne 'QUERYINPUTFORM') { continue }
    foreach ($layoutKey in @('default', 'CAD_DISPATCH', 'FIRST_RESPONDER')) {
        $layout = $config.layout.$layoutKey
        if (-not $layout) { continue }
        foreach ($prop in $layout.PSObject.Properties) {
            $node = $prop.Value
            if ($node -and $node.props -and $node.props.fieldId -eq 'SexCode') {
                $formFieldsFound++
            }
        }
    }
}

Write-Host "Change 1 -- Form fields: UNCHANGED ($formFieldsFound node(s))" -ForegroundColor Cyan
Write-Host "  codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS (production standard)"
Write-Host "  Form resolves to NIBRS code: M / F / U"
Write-Host ""

# =====================================================================
# CHANGE 2 -- CommSys QIDM SexCode: no change
# =====================================================================
$commsysSexFound = 0
foreach ($bundle in $dK.bundles) {
    if ($bundle.name -in @('ENTITIES', 'RMS')) { continue }
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($attr in $cfg.attributes) {
            if ($attr.name -eq 'SexCode' -and $attr.targetField -eq 'SexCode') {
                $commsysSexFound++
            }
        }
    }
}

Write-Host "Change 2 -- CommSys QIDM SexCode: UNCHANGED ($commsysSexFound attribute(s))" -ForegroundColor Cyan
Write-Host "  codeTypeProvider=NIBRS (existing) -- form sends M/F/U -> <SexCode>M</SexCode>"
Write-Host ""

# =====================================================================
# CHANGE 3 -- RMS QIDM sex: useAttributeId=True + codeTypeCategory + codeTypeSource
#   The code type refs on the QIDM attribute are the new element.
#   Hypothesis: QIDM-layer lookup "M" -> RMS_SEX entry -> 69509891711
# =====================================================================
$rmsBundle     = $dK.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object {
    $_.targetEntity -eq 'Person' -and $_.type -eq 'QUERYINPUTDATAMAPPING'
}

if (-not $rmsPersonQidm) {
    Write-Host "ERROR: RMS Person QIDM not found" -ForegroundColor Red
    exit 1
}

$sexAttr = [PSCustomObject]@{
    name             = 'sex'
    sourceField      = @('SexCode')
    targetField      = 'sexAttrId'
    useAttributeId   = $true
    codeTypeCategory = 'NIBRS_SEX'
    codeTypeSource   = 'NCIC'
}
$attrList = [System.Collections.Generic.List[object]]($rmsPersonQidm.attributes)
$attrList.Add($sexAttr)
$rmsPersonQidm.attributes = $attrList.ToArray()

$combosUpdated = 0
foreach ($combo in $rmsPersonQidm.combinations) {
    $anyList = [System.Collections.Generic.List[string]]($combo.requirements.any)
    if (-not $anyList.Contains('SexCode')) {
        $anyList.Add('SexCode')
        $combo.requirements.any = $anyList.ToArray()
        $combosUpdated++
    }
}

Write-Host "Change 3 -- RMS QIDM sex attribute:" -ForegroundColor Cyan
Write-Host "  sourceField=[SexCode] -> targetField=sexAttrId"
Write-Host "  useAttributeId=True"
Write-Host "  codeTypeCategory=NIBRS_SEX, codeTypeSource=NCIC  <- NEW"
Write-Host "  Combinations updated: $combosUpdated"
Write-Host ""

($dK | ConvertTo-Json -Depth 100) | Set-Content $OUTK -Encoding UTF8
Write-Host "Output: $OUTK" -ForegroundColor Green
Write-Host ""
Write-Host "========================================"
Write-Host " TEST INSTRUCTIONS"
Write-Host "========================================"
Write-Host ""
Write-Host "Import NJ_NJCJIS_SexCode_OptionK.json"
Write-Host "Person NJ -- Name + DOB + Sex (select Male, then Female)"
Write-Host ""
Write-Host "STEP 1 -- Dropdown:"
Write-Host "  Should show Male/Female/Unknown cleanly (NIBRS_SEX/NIBRS -- same as production)"
Write-Host ""
Write-Host "STEP 2 -- CommSys XML <SexCode>:"
Write-Host "  'M' or 'F'       -> correct (form unchanged, same as production)   [EXPECTED]"
Write-Host "  numeric ID       -> form not using NIBRS_SEX/NIBRS                 [UNEXPECTED]"
Write-Host ""
Write-Host "STEP 3 -- RMS elastic sexAttrId:"
Write-Host "  69509891711      -> QIDM-layer lookup M->attribute ID worked        [SUCCESS]"
Write-Host "  'M' or 'F'       -> codeTypeCategory on QIDM attr had no effect     [FAIL]"
Write-Host "  absent           -> attribute not added or combination not firing   [FAIL]"
Write-Host "  400 / error      -> useAttributeId=True still passes NIBRS code     [FAIL]"
Write-Host ""
Write-Host "TARGET: CommSys 'M'/'F' AND RMS 69509891711/69509894381 simultaneously."
Write-Host ""
Write-Host "If RMS still gets 'M': codeTypeCategory on QIDM attribute does not trigger lookup."
Write-Host "  Next step: ask engineering to confirm how RMS_SEX code type is meant to be"
Write-Host "  referenced from a QIDM attribute to perform the NIBRS->attribute ID conversion."
Write-Host ""
