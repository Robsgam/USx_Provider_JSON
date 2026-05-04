# test_vehicle_make_codetype.ps1
# One-off test JSON: VehicleMakeCode using codeTypeCategory/codeTypeSource
# instead of attributeTypeId/codeTypeProvider on the form.
#
# PURPOSE: Test whether codeTypeCategory='NCIC_FIREARM_MAKE' + codeTypeSource='NCIC'
#          populates the dropdown with vehicle makes AND passes through to CommSys XML.
#
# FORM FIELD CHANGE (test):
#   OLD: FormSelect { attributeTypeId='VEHICLE_MAKE', codeTypeProvider='NCIC' }  -> stores attribute ID
#   NEW: FormSelect { codeTypeCategory='NCIC_FIREARM_MAKE', codeTypeSource='NCIC' } -> stores NCIC code string
#
# QIDM CHANGE (test):
#   OLD: codeTypeProvider='NCIC' on VehicleMakeCode attribute (reverse-lookup)
#   NEW: no codeTypeProvider needed (value is already the NCIC code string)
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\test_vehicle_make_codetype.ps1

$DIR = "C:\Users\RobSgambellone\.local\bin\NY_NYSPIN_EJUSTICE"
$OUT = "$DIR\TEST_VEHICLE_MAKE_CODETYPE.json"

$hidle = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS (minimal)
# =====================================================================
function N($type, $display, $props, $isCanvas, $hidden, $nodes, $parent) {
    $nodeList = [System.Collections.Generic.List[string]]::new()
    if ($nodes) { foreach ($n in @($nodes)) { $nodeList.Add([string]$n) } }
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

function Inp($fid, $lbl, $maxLen, $parentId) {
    N 'FormInput' 'Input' @{ fieldId = $fid; label = $lbl; maxLength = $maxLen } $false $false @() $parentId
}

function Sel($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $false @() $parentId
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

function AddFrNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (N 'Card' 'Card' @{} $true $false @('LinkToEvent_Input') 'ROOT_PAGE') -Force
    $clone | Add-Member -NotePropertyName 'LinkToEvent_Input' -NotePropertyValue (N 'FormCheckbox' 'Checkbox' @{ fieldId = 'LINK_CURRENT_ASSIGNED_EVENT'; label = ' '; checkboxLabel = 'Link to the current assigned event' } $false $false @() 'CONTEXT_INFO_CARD') -Force
    return $clone
}

# =====================================================================
# BUNDLE 1: PROVIDER (auth + results + QMF + Vehicle QIDM only)
# =====================================================================

$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');       targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');   targetField = 'Mnemonic' }
        [PSCustomObject]@{
            description = 'dexUserStateid from RMS profile'
            name        = 'UserName'
            rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
            sourceField = @('dexStateUserId')
            targetField = 'UserName'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for NY NYSPIN EJUSTICE'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NY_NYSPIN_EJUSTICE'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NY_NYSPIN_EJUSTICE'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'NY_NYSPIN_EJUSTICE_Results'
$results.description = 'Results mapping for NY NYSPIN EJUSTICE'
$results.provider    = 'NY_NYSPIN_EJUSTICE'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NY_NYSPIN_EJUSTICE_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NY_NYSPIN_EJUSTICE'
}

# VehicleRegistrationQuery -- RVIN only (VIN + State + Make + Year)
# KEY CHANGE: VehicleMakeCode attribute has NO codeTypeProvider
#   (value from form is already the NCIC code string, no reverse-lookup needed)
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('VehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('VehicleMakeCode','VehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
    )
    description     = 'TEST: VehicleMakeCode with codeTypeCategory instead of attributeTypeId'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

$nyBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehQuery)
    description    = 'TEST: Vehicle Make codeType pattern'
    name           = 'NY_NYSPIN_EJUSTICE'
    type           = 'BUNDLE'
    provider       = 'NY_NYSPIN_EJUSTICE'
    providerType   = 'Commsys'
}

# =====================================================================
# BUNDLE 2: ENTITIES (Vehicle only -- single card, minimal)
# =====================================================================

# KEY CHANGE: VehicleMakeCode uses codeTypeCategory/codeTypeSource
#   instead of attributeTypeId/codeTypeProvider
$vehLayoutDef = [ordered]@{}
$vehLayoutDef['ROOT']      = N 'Root' 'Root' @{} $false $false @('FORM_ROOT') ''
$vehLayoutDef['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
$vehLayoutDef['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false @('ROOT_CARD') 'FORM_ROOT'
$vehLayoutDef['ROOT_CARD'] = N 'Card' 'Card' @{ title = 'TEST - Vehicle Make codeType' } $true $false @('ROW_1','ROW_2','ROW_3') 'ROOT_PAGE'
$vehLayoutDef['ROW_1']     = N 'Row' 'Row' @{ templateColumns = @('6','6') } $true $false @('VIN_Input','State_Input') 'ROOT_CARD'
$vehLayoutDef['VIN_Input']   = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_1'
$vehLayoutDef['State_Input'] = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_1'
$vehLayoutDef['ROW_2']     = N 'Row' 'Row' @{ templateColumns = @('6','6') } $true $false @('Make_Input','Year_Input') 'ROOT_CARD'
$vehLayoutDef['Make_Input']  = Sel 'VehicleMakeCode' 'Vehicle Make (codeType test)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_2'
$vehLayoutDef['Year_Input']  = Inp 'VehicleYear' 'Vehicle Year' '4' 'ROW_2'
$vehLayoutDef['ROW_3']     = N 'Row' 'Row' @{ templateColumns = @('6','6') } $true $false @('MakeOld_Input','MakeLabel') 'ROOT_CARD'
$vehLayoutDef['MakeOld_Input'] = Sel 'VehicleMakeCodeOld' 'Vehicle Make (OLD attributeType)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_3'
$vehLayoutDef['MakeLabel']     = Inp 'VehicleMakeLabel' 'Compare dropdowns above' '1' 'ROW_3'

$defLayout = [PSCustomObject]$vehLayoutDef
$cadLayout = AddCadNodes $defLayout
$frLayout  = AddFrNodes $defLayout

$vehLayout = [PSCustomObject]@{
    default         = $defLayout
    CAD_DISPATCH    = $cadLayout
    FIRST_RESPONDER = $frLayout
}

$vehicleForm = [PSCustomObject]@{
    description  = 'TEST: Vehicle Make codeType comparison -- two dropdowns side by side'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm)
    description    = 'TEST entity forms -- Vehicle only'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Vehicle')
        CAD_DISPATCH    = @('Vehicle')
        FIRST_RESPONDER = @('Vehicle')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE, minimal)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $nyBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "TEST JSON built: $OUT"
Write-Host ""
Write-Host "WHAT TO TEST:"
Write-Host "  1. Import TEST_VEHICLE_MAKE_CODETYPE.json"
Write-Host "  2. Check the 'Vehicle Make (codeType test)' dropdown -- does it show vehicle makes?"
Write-Host "  3. Check the 'Vehicle Make (OLD attributeType)' dropdown -- compare contents"
Write-Host "  4. Select a make from the codeType dropdown, fill VIN+State, submit"
Write-Host "  5. Check CommSys XML -- does <VehicleMakeCode> appear with the NCIC code?"
Write-Host ""
Write-Host "FORM DIFFERENCE:"
Write-Host "  codeType test:    codeTypeCategory='NCIC_FIREARM_MAKE' + codeTypeSource='NCIC'"
Write-Host "  OLD attributeType: attributeTypeId='VEHICLE_MAKE' + codeTypeProvider='NCIC'"
