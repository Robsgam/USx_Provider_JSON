# build_nj_njcjis_sexcode_optionS.ps1
#
# TEST VARIANT -- NJ NJCJIS SexCode Option S (NOPD pattern)
#
# RATIONALE:
#   Options L-R all used attributeTypeId=SEX + codeTypeProvider=NIBRS on the form.
#   For HIDLE (HI_HCJDC), that combination stores the display label "Male"/"Female".
#   For NJ_NJCJIS, the same combination stores the numeric attribute ID (69509894381).
#   Result: CommSys receives the attribute ID instead of the NIBRS code -- FAIL.
#
#   NOPD (LA_LEMS) uses attributeTypeId=SEX alone (NO codeTypeProvider on the form).
#   CommSys QIDM SexCode has size:1 and no codeTypeProvider -- a plain passthrough.
#   RMS QIDM: useAttributeId=True.
#   This implies: attributeTypeId=SEX alone stores the raw NIBRS code "M"/"F"/"U".
#   CommSys receives "M"/"F" directly (size:1 fits). RMS useAttributeId=True converts
#   "M" -> 69509891711. Both paths correct simultaneously.
#
# OPTION S = NOPD pattern applied to NJ:
#   Form:         attributeTypeId=SEX only -- NO codeTypeProvider
#   CommSys QIDM: codeTypeProvider=NIBRS unchanged (already present in production)
#   RMS QIDM:     { name:"sex", sourceField:["SexCode"], targetField:"sexAttrId",
#                   useAttributeId:true }
#
# KEY DIFFERENCE FROM OPTION L:
#   Option L: form has attributeTypeId=SEX + codeTypeProvider=NIBRS
#   Option S: form has attributeTypeId=SEX only (codeTypeProvider removed from form)
#
# OUTPUT: NJ_NJCJIS_SexCode_OptionS.json
# =====================================================================

$DIR   = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$BASE  = "$DIR\NJ_NJCJIS_simple.json"
$OUTS  = "$DIR\NJ_NJCJIS_SexCode_OptionS.json"

Write-Host ""
Write-Host "========================================"
Write-Host " NJ_NJCJIS SexCode Option S -- NOPD Pattern"
Write-Host " attributeTypeId=SEX only on form (no codeTypeProvider)"
Write-Host " CommSys QIDM codeTypeProvider=NIBRS unchanged"
Write-Host " RMS QIDM useAttributeId=True"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path $BASE)) {
    Write-Host "ERROR: Base file not found: $BASE" -ForegroundColor Red
    exit 1
}

$d = Get-Content $BASE -Raw | ConvertFrom-Json

# =====================================================================
# CHANGE 1 -- Form SexCode fields: attributeTypeId=SEX only
#   Remove codeTypeCategory, codeTypeSource, codeTypeProvider (if present)
#   Add attributeTypeId=SEX -- NO codeTypeProvider on the form node
#   NOPD: attributeTypeId alone stores raw NIBRS code "M"/"F"/"U"
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
                $props = $node.props
                # Remove all code type refs from form
                $props.PSObject.Properties.Remove('codeTypeCategory')
                $props.PSObject.Properties.Remove('codeTypeSource')
                $props.PSObject.Properties.Remove('codeTypeProvider')
                # Remove elasticPayloadTargetField if present from prior tests
                $props.PSObject.Properties.Remove('elasticPayloadTargetField')
                # Add attributeTypeId=SEX only (NOPD pattern -- no codeTypeProvider)
                $props | Add-Member -MemberType NoteProperty -Name 'attributeTypeId' -Value 'SEX' -Force
                $formFieldsUpdated++
            }
        }
    }
}

Write-Host "Change 1 -- Form SexCode fields updated: $formFieldsUpdated" -ForegroundColor Cyan
Write-Host "  Before: codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS"
Write-Host "  After:  attributeTypeId=SEX only (no codeTypeProvider -- NOPD pattern)"
Write-Host "  Hypothesis: form stores raw NIBRS code 'M'/'F'/'U'"
Write-Host ""

# =====================================================================
# CHANGE 2 -- CommSys QIDM SexCode: verify codeTypeProvider=NIBRS present (no change)
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
Write-Host "  codeTypeProvider=NIBRS on CommSys QIDM handles code -> XML conversion if needed"
Write-Host "  If form stores 'M'/'F', CommSys passes through directly -> <SexCode>M</SexCode>"
Write-Host ""

# =====================================================================
# CHANGE 3 -- RMS QIDM sex: add useAttributeId=True (same as Options L-R)
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

Write-Host "Change 3 -- RMS QIDM sex attribute added:" -ForegroundColor Cyan
Write-Host "  sourceField=[SexCode] -> targetField=sexAttrId"
Write-Host "  useAttributeId=True"
Write-Host "  Combinations updated: $combosUpdated"
Write-Host ""

($d | ConvertTo-Json -Depth 100) | Set-Content $OUTS -Encoding UTF8
Write-Host "Output: $OUTS" -ForegroundColor Green
Write-Host ""
Write-Host "========================================"
Write-Host " TEST INSTRUCTIONS"
Write-Host "========================================"
Write-Host ""
Write-Host "Import NJ_NJCJIS_SexCode_OptionS.json"
Write-Host "Person query -- Name + DOB + Sex"
Write-Host ""
Write-Host "STEP 1 -- Dropdown:"
Write-Host "  Shows M / F / U or Male/Female/Unknown?  [EXPECTED -- attributeTypeId=SEX]"
Write-Host "  Shows numeric IDs?                        [UNEXPECTED]"
Write-Host ""
Write-Host "STEP 2 -- CommSys XML <SexCode>:"
Write-Host "  'M' or 'F'      -> form stored NIBRS code, CommSys passed through  [SUCCESS]"
Write-Host "  'Male'/'Female' -> form stored label, CommSys converted             [SUCCESS]"
Write-Host "  69509891711     -> form stored attribute ID, no conversion          [FAIL]"
Write-Host ""
Write-Host "STEP 3 -- RMS elastic sexAttrId:"
Write-Host "  69509891711     -> useAttributeId=True converted NIBRS code         [SUCCESS]"
Write-Host "  'M'             -> useAttributeId=True not converting               [FAIL]"
Write-Host "  absent          -> combination not firing                           [FAIL]"
Write-Host ""
Write-Host "TARGET: CommSys 'M'/'F' AND RMS 69509891711/69509894381 simultaneously."
Write-Host ""
Write-Host "Test Male first, then Female -- confirm both work."
Write-Host ""
