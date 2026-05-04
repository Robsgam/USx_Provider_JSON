$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# Helper: create a layout node
function N($resolvedName,$displayName,$props,$isCanvas,$hidden,$nodes,$parent) {
    [PSCustomObject]@{
        type        = [PSCustomObject]@{ resolvedName = $resolvedName }
        displayName = $displayName
        props       = $props
        isCanvas    = $isCanvas
        hidden      = $hidden
        nodes       = $nodes
        linkedNodes = [PSCustomObject]@{}
        parent      = $parent
    }
}

# Helper: build CONTEXT_INFO_CARD block for CAD_DISPATCH
function AddCadNodes($l) {
    $l | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{}) $true $false @('ROW_0') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'ROW_0' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD') -Force
    $l | Add-Member -NotePropertyName 'CadUnit_Input' -NotePropertyValue (
        N 'FormSelect' 'Select' ([PSCustomObject]@{ attributeTypeId='CAD_UNIT_SELECT_VALUE'; fieldId='CAD_UNIT_SELECT_VALUE'; label='Requesting Unit' }) $false $false @() 'ROW_0') -Force
    $l | Add-Member -NotePropertyName 'CadEvent_Input' -NotePropertyValue (
        N 'FormSelect' 'Select' ([PSCustomObject]@{ attributeTypeId='CAD_EVENT_SELECT_VALUE'; fieldId='CAD_EVENT_SELECT_VALUE'; label='Event'; performSearchAhead=$true }) $false $false @() 'ROW_0') -Force
}

# Helper: build CONTEXT_INFO_CARD block for FIRST_RESPONDER (adds LinkToEvent)
function AddFrNodes($l) {
    $l | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{}) $true $false @('ROW_0','LinkToEvent_Input') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'ROW_0' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD') -Force
    $l | Add-Member -NotePropertyName 'CadUnit_Input' -NotePropertyValue (
        N 'FormSelect' 'Select' ([PSCustomObject]@{ attributeTypeId='CAD_UNIT_SELECT_VALUE'; fieldId='CAD_UNIT_SELECT_VALUE'; label='Requesting Unit' }) $false $false @() 'ROW_0') -Force
    $l | Add-Member -NotePropertyName 'CadEvent_Input' -NotePropertyValue (
        N 'FormSelect' 'Select' ([PSCustomObject]@{ attributeTypeId='CAD_EVENT_SELECT_VALUE'; fieldId='CAD_EVENT_SELECT_VALUE'; label='Event'; performSearchAhead=$true }) $false $false @() 'ROW_0') -Force
    $l | Add-Member -NotePropertyName 'LinkToEvent_Input' -NotePropertyValue (
        N 'FormCheckbox' 'Checkbox' ([PSCustomObject]@{ fieldId='LinkToEvent'; label='Link to Event'; checkboxLabel='Link to Event' }) $false $false @() 'CONTEXT_INFO_CARD') -Force
}

# ─── Build ENTITY_Vehicle_InState ─────────────────────────────────────────────
function BuildInStateLayout($includeCad, $includeFr) {
    $l = [PSCustomObject]@{}
    $l | Add-Member -NotePropertyName 'ROOT'      -NotePropertyValue (N 'Root' 'Root' ([PSCustomObject]@{}) $true $false @('FORM_ROOT') $null) -Force
    $l | Add-Member -NotePropertyName 'FORM_ROOT' -NotePropertyValue (N 'Form' 'Form' ([PSCustomObject]@{ hidePageItems=$true; layout='page' }) $true $false @('ROOT_PAGE') 'ROOT') -Force

    $rootPageNodes = if ($includeCad -or $includeFr) {
        @('CONTEXT_INFO_CARD','CARD_INSTATE_PLATE','CARD_INSTATE_VIN','CARD_INSTATE_DECAL','CARD_INSTATE_TITLE')
    } else {
        @('CARD_INSTATE_PLATE','CARD_INSTATE_VIN','CARD_INSTATE_DECAL','CARD_INSTATE_TITLE')
    }

    $l | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (
        N 'Page' 'Page' ([PSCustomObject]@{ title='Page 1' }) $true $false $rootPageNodes 'FORM_ROOT') -Force

    # IN STATE by PLATE
    $l | Add-Member -NotePropertyName 'CARD_INSTATE_PLATE' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{ title='IN STATE by PLATE' }) $true $false @('INSTATE_PLATE_ROW1') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'INSTATE_PLATE_ROW1' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('LP_InStatePlate','LPYear_InStatePlate') 'CARD_INSTATE_PLATE') -Force
    $l | Add-Member -NotePropertyName 'LP_InStatePlate' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='LicensePlateNumberIn'; label='License Plate #' }) $false $false @() 'INSTATE_PLATE_ROW1') -Force
    $l | Add-Member -NotePropertyName 'LPYear_InStatePlate' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='LicensePlateYearIn'; label='Plate Year' }) $false $false @() 'INSTATE_PLATE_ROW1') -Force

    # IN STATE by VIN
    $l | Add-Member -NotePropertyName 'CARD_INSTATE_VIN' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{ title='IN STATE by VIN' }) $true $false @('INSTATE_VIN_ROW1') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'INSTATE_VIN_ROW1' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('9','3') }) $true $false @('VIN_InStateVin','VINSeq_InStateVin') 'CARD_INSTATE_VIN') -Force
    $l | Add-Member -NotePropertyName 'VIN_InStateVin' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='VehicleIdentificationNumberIn'; label='VIN' }) $false $false @() 'INSTATE_VIN_ROW1') -Force
    $l | Add-Member -NotePropertyName 'VINSeq_InStateVin' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='VINSequenceNumber'; label='VIN Seq #' }) $false $false @() 'INSTATE_VIN_ROW1') -Force

    # IN STATE by DECAL
    $l | Add-Member -NotePropertyName 'CARD_INSTATE_DECAL' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{ title='IN STATE by DECAL' }) $true $false @('INSTATE_DECAL_ROW1') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'INSTATE_DECAL_ROW1' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('Decal_InStateDecal','LPYear_InStateDecal') 'CARD_INSTATE_DECAL') -Force
    $l | Add-Member -NotePropertyName 'Decal_InStateDecal' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='DecalNumber'; label='Decal Number' }) $false $false @() 'INSTATE_DECAL_ROW1') -Force
    $l | Add-Member -NotePropertyName 'LPYear_InStateDecal' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='LicensePlateYearDecal'; label='Plate Year' }) $false $false @() 'INSTATE_DECAL_ROW1') -Force

    # IN STATE by TITLE
    $l | Add-Member -NotePropertyName 'CARD_INSTATE_TITLE' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{ title='IN STATE by TITLE' }) $true $false @('INSTATE_TITLE_ROW1') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'INSTATE_TITLE_ROW1' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('12') }) $true $false @('Title_InStateTitle') 'CARD_INSTATE_TITLE') -Force
    $l | Add-Member -NotePropertyName 'Title_InStateTitle' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='TitleLienInformation'; label='Title Lien Information' }) $false $false @() 'INSTATE_TITLE_ROW1') -Force

    if ($includeCad)  { AddCadNodes $l }
    if ($includeFr)   { AddFrNodes  $l }
    return $l
}

# ─── Build ENTITY_Vehicle_OOS ─────────────────────────────────────────────────
function BuildOOSLayout($includeCad, $includeFr) {
    $l = [PSCustomObject]@{}
    $l | Add-Member -NotePropertyName 'ROOT'      -NotePropertyValue (N 'Root' 'Root' ([PSCustomObject]@{}) $true $false @('FORM_ROOT') $null) -Force
    $l | Add-Member -NotePropertyName 'FORM_ROOT' -NotePropertyValue (N 'Form' 'Form' ([PSCustomObject]@{ hidePageItems=$true; layout='page' }) $true $false @('ROOT_PAGE') 'ROOT') -Force

    $rootPageNodes = if ($includeCad -or $includeFr) {
        @('CONTEXT_INFO_CARD','CARD_OUTSTATE_PLATE','CARD_OUTSTATE_VIN')
    } else {
        @('CARD_OUTSTATE_PLATE','CARD_OUTSTATE_VIN')
    }

    $l | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (
        N 'Page' 'Page' ([PSCustomObject]@{ title='Page 1' }) $true $false $rootPageNodes 'FORM_ROOT') -Force

    # OUT OF STATE by PLATE
    $l | Add-Member -NotePropertyName 'CARD_OUTSTATE_PLATE' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{ title='OUT OF STATE by PLATE' }) $true $false @('OUTSTATE_PLATE_ROW1','OUTSTATE_PLATE_ROW2') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'OUTSTATE_PLATE_ROW1' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('LP_OutStatePlate','State_OutStatePlate') 'CARD_OUTSTATE_PLATE') -Force
    $l | Add-Member -NotePropertyName 'LP_OutStatePlate' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='LicensePlateNumberOut'; label='License Plate #' }) $false $false @() 'OUTSTATE_PLATE_ROW1') -Force
    $l | Add-Member -NotePropertyName 'State_OutStatePlate' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='RegistrationStateOut'; label='State'; attributeTypeId='STATE' }) $false $false @() 'OUTSTATE_PLATE_ROW1') -Force
    $l | Add-Member -NotePropertyName 'OUTSTATE_PLATE_ROW2' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('LPType_OutStatePlate','LPYear_OutStatePlate') 'CARD_OUTSTATE_PLATE') -Force
    $l | Add-Member -NotePropertyName 'LPType_OutStatePlate' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='LicensePlateTypeCode'; label='Plate Type' }) $false $false @() 'OUTSTATE_PLATE_ROW2') -Force
    $l | Add-Member -NotePropertyName 'LPYear_OutStatePlate' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='LicensePlateYearOut'; label='Plate Year' }) $false $false @() 'OUTSTATE_PLATE_ROW2') -Force

    # OUT OF STATE by VIN
    $l | Add-Member -NotePropertyName 'CARD_OUTSTATE_VIN' -NotePropertyValue (
        N 'Card' 'Card' ([PSCustomObject]@{ title='OUT OF STATE by VIN' }) $true $false @('OUTSTATE_VIN_ROW1','OUTSTATE_VIN_ROW2') 'ROOT_PAGE') -Force
    $l | Add-Member -NotePropertyName 'OUTSTATE_VIN_ROW1' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('9','3') }) $true $false @('VIN_OutStateVin','State_OutStateVin') 'CARD_OUTSTATE_VIN') -Force
    $l | Add-Member -NotePropertyName 'VIN_OutStateVin' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='VehicleIdentificationNumberOut'; label='VIN' }) $false $false @() 'OUTSTATE_VIN_ROW1') -Force
    $l | Add-Member -NotePropertyName 'State_OutStateVin' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='RegistrationState'; label='State'; attributeTypeId='STATE' }) $false $false @() 'OUTSTATE_VIN_ROW1') -Force
    $l | Add-Member -NotePropertyName 'OUTSTATE_VIN_ROW2' -NotePropertyValue (
        N 'Row' 'Row' ([PSCustomObject]@{ templateColumns=@('6','6') }) $true $false @('Make_OutStateVin','Year_OutStateVin') 'CARD_OUTSTATE_VIN') -Force
    $l | Add-Member -NotePropertyName 'Make_OutStateVin' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='VehicleMakeCode'; label='Make' }) $false $false @() 'OUTSTATE_VIN_ROW2') -Force
    $l | Add-Member -NotePropertyName 'Year_OutStateVin' -NotePropertyValue (
        N 'FormInput' 'Input' ([PSCustomObject]@{ fieldId='VehicleYear'; label='Vehicle Year' }) $false $false @() 'OUTSTATE_VIN_ROW2') -Force

    if ($includeCad)  { AddCadNodes $l }
    if ($includeFr)   { AddFrNodes  $l }
    return $l
}

# ─── Build entity configs ─────────────────────────────────────────────────────
$vehicleInState = [PSCustomObject]@{
    name        = 'ENTITY_Vehicle_InState'
    type        = 'QUERYINPUTFORM'
    description = 'Vehicle entity form -- FL in state (PLATE, VIN, DECAL, TITLE)'
    label       = 'Vehicle (In State)'
    targetEntity= 'Vehicle'
    layout      = [PSCustomObject]@{
        default        = BuildInStateLayout $false $false
        CAD_DISPATCH   = BuildInStateLayout $true  $false
        FIRST_RESPONDER= BuildInStateLayout $false $true
    }
}

$vehicleOOS = [PSCustomObject]@{
    name        = 'ENTITY_Vehicle_OOS'
    type        = 'QUERYINPUTFORM'
    description = 'Vehicle entity form -- FL out of state (PLATE, VIN)'
    label       = 'Vehicle (Out of State)'
    targetEntity= 'Vehicle'
    layout      = [PSCustomObject]@{
        default        = BuildOOSLayout $false $false
        CAD_DISPATCH   = BuildOOSLayout $true  $false
        FIRST_RESPONDER= BuildOOSLayout $false $true
    }
}

# ─── Replace ENTITY_Vehicle with InState + OOS in bundle ─────────────────────
$bundle = $j.bundles[0]
$newCfgs = [System.Collections.Generic.List[object]]::new()
foreach ($c in $bundle.configurations) {
    if ($c.name -eq 'ENTITY_Vehicle') {
        $newCfgs.Add($vehicleInState)
        $newCfgs.Add($vehicleOOS)
        Write-Host "Replaced ENTITY_Vehicle with ENTITY_Vehicle_InState + ENTITY_Vehicle_OOS"
    } else {
        $newCfgs.Add($c)
    }
}
$bundle.configurations = $newCfgs.ToArray()

# ─── Write back ───────────────────────────────────────────────────────────────
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
