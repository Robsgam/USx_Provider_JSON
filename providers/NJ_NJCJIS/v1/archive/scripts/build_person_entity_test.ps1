# build_person_entity_test.ps1
# Builds a test JSON with two separate Person QUERYINPUTFORM entities:
#   "Person (In-State)"     -- State defaults to NJ; operator rarely changes it
#   "Person (Out-of-State)" -- State has no default; operator must fill it
# Output: NJ_NJCJIS_person_entity_test.json
# Purpose: Test whether the platform renders two Person tabs in the top nav.

$OUT = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS\NJ_NJCJIS_person_entity_test.json"

# =====================================================================
# HELPERS (same as main build script)
# =====================================================================
function N($type, $display, $props, $isCanvas, $hidden, $nodeList, $parent) {
    $obj = [ordered]@{
        type        = [PSCustomObject]@{ resolvedName = $type }
        displayName = $display
        props       = [PSCustomObject]$props
        isCanvas    = [bool]$isCanvas
        hidden      = [bool]$hidden
        nodes       = $nodeList
        linkedNodes = [PSCustomObject]@{}
    }
    if ($parent -ne '') { $obj['parent'] = "$parent" }
    [PSCustomObject]$obj
}

function Inp($fid, $lbl, $maxLen, $parentId, $extra = @{}) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    if ($maxLen) { $p['maxLength'] = $maxLen }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormInput' 'Input' $p $false $false @() $parentId
}

function Sel($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $false @() $parentId
}

function Dt($fid, $lbl, $parentId) {
    N 'FormDate' 'Date' @{ fieldId = $fid; label = $lbl } $false $false @() $parentId
}

function BuildLayout($rowDefs, $rootCardRowIds) {
    $l = [ordered]@{}
    $l['ROOT']      = N 'Root' 'Root' @{} $false $false @('FORM_ROOT') ''
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false @('ROOT_CARD') 'FORM_ROOT'
    $l['ROOT_CARD'] = N 'Card' 'Card' @{} $true $false ([array]$rootCardRowIds) 'ROOT_PAGE'
    foreach ($rDef in $rowDefs) {
        $childIds = @($rDef.fields | ForEach-Object { $_.id })
        $l[$rDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rDef.cols } $true $false $childIds 'ROOT_CARD'
        foreach ($f in $rDef.fields) { $l[$f.id] = $f.node }
    }
    return [PSCustomObject]$l
}

function AddCadNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (N 'Card' 'Card' @{} $true $false @('ROW_0') 'ROOT_PAGE') -Force
    $clone | Add-Member -NotePropertyName 'ROW_0'             -NotePropertyValue (N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD') -Force
    $clone | Add-Member -NotePropertyName 'CadUnit_Input'     -NotePropertyValue (Sel 'CAD_UNIT_SELECT_VALUE'  'Requesting Unit' @{ attributeTypeId = 'CAD_UNIT_SELECT_VALUE' } 'ROW_0') -Force
    $clone | Add-Member -NotePropertyName 'CadEvent_Input'    -NotePropertyValue (Sel 'CAD_EVENT_SELECT_VALUE' 'Event' @{ attributeTypeId = 'CAD_EVENT_SELECT_VALUE'; performSearchAhead = $true } 'ROW_0') -Force
    return $clone
}

function MakeLayouts($rowDefs, $rootCardRowIds) {
    $def = BuildLayout $rowDefs $rootCardRowIds
    $cad = AddCadNodes $def
    $fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# FORM 1 -- Person (In-State)
# State defaults to NJ. Operator leaves it unless doing an unusual query.
# ROW_1 cols (6,4,2): OLN | State (NJ default) | Image
# ROW_2 cols (6,6):   First Name | Last Name
# ROW_3 cols (6,6):   DOB | Sex
# =====================================================================
$inStateLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','4','2'); fields = @(
        @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_1' }
        @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_2' }
        @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('6','6'); fields = @(
        @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_3' }
        @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ codeTypeCategory = 'SEX'; codeTypeSource = 'NIBRS' } 'ROW_3' }
    )}
) @('ROW_1','ROW_2','ROW_3')

$personFormInState = [PSCustomObject]@{
    description  = 'Person entity form -- in-state (State defaults to NJ)'
    label        = 'Person (In-State)'
    layout       = $inStateLayout
    name         = 'ENTITY_Person_InState'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# =====================================================================
# FORM 2 -- Person (Out-of-State)
# State has no default -- operator must select the out-of-state value.
# ROW_1 cols (5,5,2): OLN | State (no default) | Image
# ROW_2 cols (6,6):   First Name | Last Name
# ROW_3 cols (6,6):   DOB | Sex
# =====================================================================
$outOfStateLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('5','5','2'); fields = @(
        @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_1' }
        @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_2' }
        @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('6','6'); fields = @(
        @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_3' }
        @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ codeTypeCategory = 'SEX'; codeTypeSource = 'NIBRS' } 'ROW_3' }
    )}
) @('ROW_1','ROW_2','ROW_3')

$personFormOutOfState = [PSCustomObject]@{
    description  = 'Person entity form -- out-of-state (operator must select State)'
    label        = 'Person (Out-of-State)'
    layout       = $outOfStateLayout
    name         = 'ENTITY_Person_OutOfState'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# =====================================================================
# BUNDLE
# =====================================================================
$entitiesBundle = [PSCustomObject]@{
    configurations = @($personFormInState, $personFormOutOfState)
    description    = 'Person entity split test -- in-state vs out-of-state tabs'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    provider       = 'MARK43'
}

$output = [PSCustomObject]@{
    bundles = @($entitiesBundle)
}

$output | ConvertTo-Json -Depth 100 | Set-Content $OUT -Encoding UTF8
Write-Host "Built: $OUT"
Write-Host "  Person (In-State)     -- ENTITY_Person_InState    -- State defaults NJ"
Write-Host "  Person (Out-of-State) -- ENTITY_Person_OutOfState -- State no default"
