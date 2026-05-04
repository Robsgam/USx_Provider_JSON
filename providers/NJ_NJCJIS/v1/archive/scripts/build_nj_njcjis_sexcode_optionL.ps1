# build_nj_njcjis_sexcode_optionL.ps1
#
# TEST VARIANT -- NJ NJCJIS SexCode Option L
#
# WHY THIS IS DIFFERENT FROM PREVIOUS OPTIONS:
#   All prior NJ sex tests (A-K) used codeTypeCategory=NIBRS_SEX on the form, so the
#   value resolved to "M" (NIBRS string). useAttributeId=True on RMS QIDM had nothing
#   to work with -- "M" is not a resolvable attribute ID.
#
#   Option B used attributeTypeId=SEX on the form (value = numeric attribute ID) but
#   also added elasticPayloadTargetField=sexAttrId -- that bypassed the RMS QIDM
#   entirely. The RMS QIDM had no sex attribute with useAttributeId=True, so
#   sexAttrId was absent from the elastic payload.
#
# THE HIDLE MECHANISM (confirmed working 2026-04-17):
#   1. Form: attributeTypeId=SEX + codeTypeProvider=NIBRS
#      -> dropdown shows M/F/U (codeTypeProvider controls display only)
#      -> value resolved = numeric attribute ID (69509891711 / 69509894381 / 69509886562)
#   2. CommSys QIDM SexCode: codeTypeProvider=NIBRS
#      -> input is numeric attribute ID -> converts back to "M"/"F"/"U"
#      -> <SexCode>M</SexCode>  [CORRECT]
#   3. RMS QIDM sex: useAttributeId=True (no extras)
#      -> input is numeric attribute ID -> passes through directly
#      -> sexAttrId:69509891711  [CORRECT]
#
# OPTION L = exact HIDLE pattern applied to NJ simple variant.
#   NO elasticPayloadTargetField. NO codeTypeCategory/codeTypeSource on form.
#   Clean three-layer chain.
#
# OUTPUT: NJ_NJCJIS_SexCode_OptionL.json
# =====================================================================

$DIR   = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$BASE  = "$DIR\NJ_NJCJIS_simple.json"
$OUTL  = "$DIR\NJ_NJCJIS_SexCode_OptionL.json"

Write-Host ""
Write-Host "========================================"
Write-Host " NJ_NJCJIS SexCode Option L -- HIDLE Pattern"
Write-Host " attributeTypeId=SEX on form + codeTypeProvider=NIBRS on CommSys QIDM"
Write-Host " + useAttributeId=True on RMS QIDM"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path $BASE)) {
    Write-Host "ERROR: Base file not found: $BASE" -ForegroundColor Red
    exit 1
}

$d = Get-Content $BASE -Raw | ConvertFrom-Json

# =====================================================================
# CHANGE 1 -- Form SexCode fields: attributeTypeId=SEX + codeTypeProvider=NIBRS
#   Replace existing codeTypeCategory/codeTypeSource with attributeTypeId pattern.
#   Applies to all layouts in all QIFs.
# =====================================================================
$formFieldsUpdated = 0
$entitiesBundle = $d.bundles | Where-Object { $_.name -eq 'ENTITIES' }

foreach ($cfg in $entitiesBundle.configurations) {
    if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
    foreach ($layoutKey in $cfg.layout.PSObject.Properties.Name) {
        $layout = $cfg.layout.$layoutKey
        foreach ($prop in $layout.PSObject.Properties) {
            $node = $prop.Value
            if ($node -and $node.props -and $node.props.fieldId -eq 'SexCode') {
                # Remove codeTypeCategory, codeTypeSource; add attributeTypeId, codeTypeProvider
                $props = $node.props
                $props.PSObject.Properties.Remove('codeTypeCategory')
                $props.PSObject.Properties.Remove('codeTypeSource')
                # Remove elasticPayloadTargetField if present from prior tests
                $props.PSObject.Properties.Remove('elasticPayloadTargetField')
                $props | Add-Member -MemberType NoteProperty -Name 'attributeTypeId'   -Value 'SEX'   -Force
                $props | Add-Member -MemberType NoteProperty -Name 'codeTypeProvider'  -Value 'NIBRS' -Force
                $formFieldsUpdated++
            }
        }
    }
}

Write-Host "Change 1 -- Form SexCode fields updated: $formFieldsUpdated" -ForegroundColor Cyan
Write-Host "  Before: codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS"
Write-Host "  After:  attributeTypeId=SEX, codeTypeProvider=NIBRS"
Write-Host "  Effect: form value = numeric attribute ID; dropdown still shows M/F/U"
Write-Host ""

# =====================================================================
# CHANGE 2 -- CommSys QIDM SexCode: verify codeTypeProvider=NIBRS present (no change needed)
# =====================================================================
$commsysVerified = 0
foreach ($bundle in $d.bundles) {
    if ($bundle.name -in @('ENTITIES','RMS')) { continue }
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'SexCode' -and $attr.codeTypeProvider -eq 'NIBRS') {
                $commsysVerified++
            }
        }
    }
}

Write-Host "Change 2 -- CommSys QIDM SexCode: UNCHANGED ($commsysVerified attribute(s) confirmed codeTypeProvider=NIBRS)" -ForegroundColor Cyan
Write-Host "  codeTypeProvider=NIBRS converts incoming attribute ID -> NIBRS code for XML"
Write-Host "  Input: 69509891711  Output: <SexCode>M</SexCode>"
Write-Host ""

# =====================================================================
# CHANGE 3 -- RMS QIDM sex: add standard useAttributeId=True attribute (HIDLE pattern)
#   NO codeTypeCategory, NO codeTypeSource, NO rule handler -- pure HIDLE
# =====================================================================
$rmsBundle     = $d.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object {
    $_.targetEntity -eq 'Person' -and $_.type -eq 'QUERYINPUTDATAMAPPING'
}

if (-not $rmsPersonQidm) {
    Write-Host "ERROR: RMS Person QIDM not found" -ForegroundColor Red
    exit 1
}

$sexAttr = [PSCustomObject]@{
    name           = 'sex'
    sourceField    = @('SexCode')
    targetField    = 'sexAttrId'
    useAttributeId = $true
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

Write-Host "Change 3 -- RMS QIDM sex attribute added (HIDLE pattern):" -ForegroundColor Cyan
Write-Host "  sourceField=[SexCode] -> targetField=sexAttrId"
Write-Host "  useAttributeId=True  (no extras -- exact HIDLE)"
Write-Host "  Combinations updated: $combosUpdated"
Write-Host ""

($d | ConvertTo-Json -Depth 100) | Set-Content $OUTL -Encoding UTF8
Write-Host "Output: $OUTL" -ForegroundColor Green
Write-Host ""
Write-Host "========================================"
Write-Host " TEST INSTRUCTIONS"
Write-Host "========================================"
Write-Host ""
Write-Host "Import NJ_NJCJIS_SexCode_OptionL.json"
Write-Host "Person query -- Name + DOB + Sex (select Male, then try Female)"
Write-Host ""
Write-Host "STEP 1 -- Dropdown:"
Write-Host "  Shows Male / Female / Unknown cleanly?  [EXPECTED -- codeTypeProvider=NIBRS]"
Write-Host "  Shows numeric IDs?                      [UNEXPECTED]"
Write-Host ""
Write-Host "STEP 2 -- CommSys XML <SexCode>:"
Write-Host "  'M' or 'F'      -> codeTypeProvider=NIBRS converted attribute ID  [SUCCESS]"
Write-Host "  69509891711     -> CommSys QIDM did not convert                   [FAIL]"
Write-Host ""
Write-Host "STEP 3 -- RMS elastic sexAttrId:"
Write-Host "  69509891711     -> useAttributeId=True passed attribute ID         [SUCCESS]"
Write-Host "  'M'             -> form still sending NIBRS string (form unchanged?)[FAIL]"
Write-Host "  absent          -> combination not firing                          [FAIL]"
Write-Host ""
Write-Host "TARGET: CommSys 'M'/'F' AND RMS 69509891711/69509894381 simultaneously."
Write-Host "This is the exact HIDLE pattern -- if HIDLE works, this should work."
Write-Host ""
