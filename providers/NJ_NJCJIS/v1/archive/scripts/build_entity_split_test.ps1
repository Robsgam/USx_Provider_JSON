# build_entity_split_test.ps1
# Builds a test JSON with all query paths as separate QUERYINPUTFORM entity tabs.
# Each distinct query path becomes its own tab in the platform top nav.
#
# Tabs generated:
#   Person (OLN - In State)          -- OLN, State(NJ), Image
#   Person (OLN - Out of State)      -- OLN, State(blank), Image
#   Person (Name)                    -- First, Last, DOB, Sex, State(NJ), Image
#   Vehicle (Plate - In State)       -- Plate, State(NJ), Image, PlateType, PlateYear, Random
#   Vehicle (Plate - Out of State)   -- Plate, State(blank), Image, PlateType, PlateYear, Random
#   Vehicle (VIN)                    -- VIN, State, Image, Random
#   Firearm                          -- Serial, Make, Caliber
#   Article                          -- Serial, ArticleType
#   Boat (Reg - In State)            -- RegNumber, State(NJ)
#   Boat (Reg - Out of State)        -- RegNumber, State(blank)
#   Boat (Hull ID)                   -- HullId, State

$OUT = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS\NJ_NJCJIS_entity_split_test.json"

# =====================================================================
# HELPERS
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
    return [PSCustomObject]@{ default = $def; CAD_DISPATCH = $cad; FIRST_RESPONDER = $fr }
}
function MakeForm($name, $label, $desc, $entity, $rowDefs, $rowIds) {
    [PSCustomObject]@{
        description  = $desc
        label        = $label
        layout       = (MakeLayouts $rowDefs $rowIds)
        name         = $name
        type         = 'QUERYINPUTFORM'
        targetEntity = $entity
    }
}

# Shared dropdown definitions
$stateNJ    = @{ attributeTypeId = 'STATE'; initialValue = 'NJ' }
$stateBlank = @{ attributeTypeId = 'STATE' }
$imageY     = @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' }
$imageN     = @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' }
$sex        = @{ codeTypeCategory = 'SEX'; codeTypeSource = 'NIBRS' }
$artType    = @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' }
$platetype  = @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' }

# =====================================================================
# PERSON FORMS
# =====================================================================

# Person (OLN - In State): OLN required; State defaults NJ; Image
$pe_oln_in = MakeForm 'ENTITY_Person_OLN_InState' 'Person (OLN - In State)' `
    'OLN query -- in-state (State defaults to NJ)' 'Person' @(
    @{ id = 'ROW_1'; cols = @('7','3','2'); fields = @(
        @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' $stateNJ 'ROW_1' }
        @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' $imageY 'ROW_1' }
    )}
) @('ROW_1')

# Person (OLN - Out of State): OLN + State required; State blank; Image
$pe_oln_out = MakeForm 'ENTITY_Person_OLN_OutOfState' 'Person (OLN - Out of State)' `
    'OLN query -- out-of-state (operator must select State)' 'Person' @(
    @{ id = 'ROW_1'; cols = @('5','5','2'); fields = @(
        @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' $stateBlank 'ROW_1' }
        @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' $imageY 'ROW_1' }
    )}
) @('ROW_1')

# Person (Name): Name + DOB required; Sex, State, Image optional
$pe_name = MakeForm 'ENTITY_Person_Name' 'Person (Name)' `
    'Name/DOB query -- in-state or out-of-state (State optional)' 'Person' @(
    @{ id = 'ROW_1'; cols = @('5','5','2'); fields = @(
        @{ id = 'NameFirst_Input';         node = Inp 'NameFirst'         'First Name' '30' 'ROW_1' }
        @{ id = 'NameLast_Input';          node = Inp 'NameLast'          'Last Name'  '30' 'ROW_1' }
        @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' $stateNJ 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','4','2'); fields = @(
        @{ id = 'BirthDate_Input';      node = Dt  'BirthDate'      'Date of Birth' 'ROW_2' }
        @{ id = 'SexCode_Input';        node = Sel 'SexCode'        'Sex'   $sex    'ROW_2' }
        @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'Image' $imageY 'ROW_2' }
    )}
) @('ROW_1','ROW_2')

# =====================================================================
# VEHICLE FORMS
# =====================================================================

# Vehicle (Plate - In State): Plate required; State defaults NJ; Image N; PlateType, PlateYear, Random optional
$ve_plate_in = MakeForm 'ENTITY_Vehicle_Plate_InState' 'Vehicle (Plate - In State)' `
    'Plate query -- in-state (State defaults to NJ)' 'Vehicle' @(
    @{ id = 'ROW_1'; cols = @('5','5','2'); fields = @(
        @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_1' }
        @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState'  'State' $stateNJ 'ROW_1' }
        @{ id = 'ImageIndicator_Input';     node = Sel 'ImageIndicator'     'Image' $imageN  'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('4','4','4'); fields = @(
        @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' $platetype 'ROW_2' }
        @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear'     'Plate Year' '4'        'ROW_2' }
        @{ id = 'RandomRequest_Input';        node = Inp 'RandomRequest'        'Random'     '5'        'ROW_2' }
    )}
) @('ROW_1','ROW_2')

# Vehicle (Plate - Out of State): Plate + State required; State blank; Image N; optionals
$ve_plate_out = MakeForm 'ENTITY_Vehicle_Plate_OutOfState' 'Vehicle (Plate - Out of State)' `
    'Plate query -- out-of-state (operator must select State)' 'Vehicle' @(
    @{ id = 'ROW_1'; cols = @('5','5','2'); fields = @(
        @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_1' }
        @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState'  'State' $stateBlank 'ROW_1' }
        @{ id = 'ImageIndicator_Input';     node = Sel 'ImageIndicator'     'Image' $imageN     'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('4','4','4'); fields = @(
        @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' $platetype 'ROW_2' }
        @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear'     'Plate Year' '4'        'ROW_2' }
        @{ id = 'RandomRequest_Input';        node = Inp 'RandomRequest'        'Random'     '5'        'ROW_2' }
    )}
) @('ROW_1','ROW_2')

# Vehicle (VIN): VIN + State required; Image N; Random optional
$ve_vin = MakeForm 'ENTITY_Vehicle_VIN' 'Vehicle (VIN)' `
    'VIN query -- in-state or out-of-state (State required)' 'Vehicle' @(
    @{ id = 'ROW_1'; cols = @('7','3','2'); fields = @(
        @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN'   '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input';           node = Sel 'RegistrationState' 'State' $stateNJ 'ROW_1' }
        @{ id = 'ImageIndicator_Input';              node = Sel 'ImageIndicator'    'Image' $imageN  'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('4'); fields = @(
        @{ id = 'RandomRequest_Input'; node = Inp 'RandomRequest' 'Random' '5' 'ROW_2' }
    )}
) @('ROW_1','ROW_2')

# =====================================================================
# FIREARM FORM  (single path)
# =====================================================================
$fa = MakeForm 'ENTITY_Firearm' 'Firearm' `
    'Gun query -- serial number required; make and caliber optional' 'Firearm' @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'SerialNumber_Input'; node = Inp 'SerialNumber' 'Serial Number' '11' 'ROW_1' }
        @{ id = 'GunMake_Input';      node = Inp 'GunMake'      'Make'          '23' 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6'); fields = @(
        @{ id = 'GunCaliber_Input'; node = Inp 'GunCaliber' 'Caliber' '4' 'ROW_2' }
    )}
) @('ROW_1','ROW_2')

# =====================================================================
# ARTICLE FORM  (single path)
# =====================================================================
$art = MakeForm 'ENTITY_Article' 'Article' `
    'Article query -- serial number and article type both required' 'Article' @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'SerialNumber_Input';    node = Inp 'SerialNumber'    'Serial Number' '20' 'ROW_1' }
        @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type'  $artType 'ROW_1' }
    )}
) @('ROW_1')

# =====================================================================
# BOAT FORMS
# =====================================================================

# Boat (Reg - In State): RegNumber required; State defaults NJ
$bo_reg_in = MakeForm 'ENTITY_Boat_Reg_InState' 'Boat (Reg - In State)' `
    'Boat registration query -- in-state (State defaults to NJ)' 'Boat' @(
    @{ id = 'ROW_1'; cols = @('8','4'); fields = @(
        @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Reg Number' '8' 'ROW_1' }
        @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState'  'State' $stateNJ 'ROW_1' }
    )}
) @('ROW_1')

# Boat (Reg - Out of State): RegNumber required; State blank
$bo_reg_out = MakeForm 'ENTITY_Boat_Reg_OutOfState' 'Boat (Reg - Out of State)' `
    'Boat registration query -- out-of-state (operator must select State)' 'Boat' @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Reg Number' '8' 'ROW_1' }
        @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState'  'State' $stateBlank 'ROW_1' }
    )}
) @('ROW_1')

# Boat (Hull ID): HullId required; State optional
$bo_hull = MakeForm 'ENTITY_Boat_Hull' 'Boat (Hull ID)' `
    'Boat hull ID query -- State optional' 'Boat' @(
    @{ id = 'ROW_1'; cols = @('7','5'); fields = @(
        @{ id = 'BoatHullIdNumber_Input';  node = Inp 'BoatHullIdNumber'  'Hull ID Number' '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' $stateBlank  'ROW_1' }
    )}
) @('ROW_1')

# =====================================================================
# BUNDLE + OUTPUT
# =====================================================================
$entitiesBundle = [PSCustomObject]@{
    configurations = @(
        $pe_oln_in, $pe_oln_out, $pe_name,
        $ve_plate_in, $ve_plate_out, $ve_vin,
        $fa,
        $art,
        $bo_reg_in, $bo_reg_out, $bo_hull
    )
    description    = 'Entity split test -- one tab per query path'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    provider       = 'MARK43'
}

$output = [PSCustomObject]@{ bundles = @($entitiesBundle) }
$output | ConvertTo-Json -Depth 100 | Set-Content $OUT -Encoding UTF8

Write-Host "Built: $OUT"
Write-Host ""
Write-Host "  Person tabs (3):"
Write-Host "    Person (OLN - In State)        -- OLN, State(NJ), Image"
Write-Host "    Person (OLN - Out of State)    -- OLN, State(blank), Image"
Write-Host "    Person (Name)                  -- First, Last, State, DOB, Sex, Image"
Write-Host ""
Write-Host "  Vehicle tabs (3):"
Write-Host "    Vehicle (Plate - In State)     -- Plate, State(NJ), Image, PlateType, PlateYear, Random"
Write-Host "    Vehicle (Plate - Out of State) -- Plate, State(blank), Image, PlateType, PlateYear, Random"
Write-Host "    Vehicle (VIN)                  -- VIN, State(NJ), Image, Random"
Write-Host ""
Write-Host "  Firearm tab (1):  Serial, Make, Caliber"
Write-Host "  Article tab (1):  Serial, ArticleType"
Write-Host ""
Write-Host "  Boat tabs (3):"
Write-Host "    Boat (Reg - In State)          -- RegNumber, State(NJ)"
Write-Host "    Boat (Reg - Out of State)      -- RegNumber, State(blank)"
Write-Host "    Boat (Hull ID)                 -- HullId, State(blank)"
