# NJ_NJCJIS v2.0 -- Multi-card layout promotion (Phase 2)
# Reads v1.7 BASE JSON, replaces single-card layouts with multi-card for Vehicle, Person, Boat.
# QIDMs are unchanged. Layout only.

param(
    [string]$BasePath = "$PSScriptRoot\..\NJ_NJCJIS_BASE.json",
    [string]$OutputPath = "$PSScriptRoot\..\NJ_NJCJIS_v2.0.json"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $BasePath)) {
    Write-Error "Base JSON not found: $BasePath"
    return
}

Write-Host "Reading base JSON: $BasePath" -ForegroundColor Cyan
$json = Get-Content $BasePath -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

# --- Helper: build a Craft.js node ---
function New-Node {
    param(
        [string]$ResolvedName,
        [string]$DisplayName,
        [hashtable]$Props = @{},
        [bool]$IsCanvas = $false,
        [bool]$Hidden = $false,
        [string[]]$Nodes = @(),
        [string]$Parent = $null
    )
    $node = [ordered]@{
        type = [ordered]@{ resolvedName = $ResolvedName }
        displayName = $DisplayName
        props = $Props
        isCanvas = $IsCanvas
        hidden = $Hidden
        nodes = $Nodes
        linkedNodes = [ordered]@{}
    }
    if ($Parent) { $node.parent = $Parent }
    return $node
}

# --- Helper: build scaffold (ROOT/FORM_ROOT/ROOT_PAGE) ---
function New-Scaffold {
    param([string[]]$PageChildren)
    $scaffold = [ordered]@{
        ROOT      = (New-Node -ResolvedName 'Root' -DisplayName 'Root' -Nodes @('FORM_ROOT'))
        FORM_ROOT = (New-Node -ResolvedName 'Form' -DisplayName 'Form' -Props ([ordered]@{hidePageItems=$true; layout='page'}) -IsCanvas $true -Nodes @('ROOT_PAGE') -Parent 'ROOT')
        ROOT_PAGE = (New-Node -ResolvedName 'Page' -DisplayName 'Page' -Props ([ordered]@{title='Page 1'}) -IsCanvas $true -Nodes $PageChildren -Parent 'FORM_ROOT')
    }
    return $scaffold
}

# --- Helper: build CAD scaffold (adds CONTEXT_INFO_CARD) ---
function New-CadScaffold {
    param([string[]]$PageChildren)
    $allChildren = @('CONTEXT_INFO_CARD') + $PageChildren
    $scaffold = New-Scaffold -PageChildren $allChildren
    $scaffold['CONTEXT_INFO_CARD'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{}) -IsCanvas $true -Nodes @('ROW_0') -Parent 'ROOT_PAGE')
    $scaffold['ROW_0'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','6')}) -IsCanvas $true -Nodes @('CadUnit_Input','CadEvent_Input') -Parent 'CONTEXT_INFO_CARD')
    $scaffold['CadUnit_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='CAD_UNIT_SELECT_VALUE'; label='Unit'; attributeTypeId='CAD_UNIT_SELECT_VALUE'}) -Parent 'ROW_0')
    $scaffold['CadEvent_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='CAD_EVENT_SELECT_VALUE'; label='Event'; attributeTypeId='CAD_EVENT_SELECT_VALUE'}) -Parent 'ROW_0')
    return $scaffold
}

# --- Helper: build FIRST_RESPONDER scaffold (CAD + LinkToEvent) ---
function New-FrScaffold {
    param([string[]]$PageChildren)
    $allChildren = @('CONTEXT_INFO_CARD') + $PageChildren
    $scaffold = New-Scaffold -PageChildren $allChildren
    $scaffold['CONTEXT_INFO_CARD'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{}) -IsCanvas $true -Nodes @('ROW_0','ROW_0_FR') -Parent 'ROOT_PAGE')
    $scaffold['ROW_0'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','6')}) -IsCanvas $true -Nodes @('CadUnit_Input','CadEvent_Input') -Parent 'CONTEXT_INFO_CARD')
    $scaffold['CadUnit_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='CAD_UNIT_SELECT_VALUE'; label='Unit'; attributeTypeId='CAD_UNIT_SELECT_VALUE'}) -Parent 'ROW_0')
    $scaffold['CadEvent_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='CAD_EVENT_SELECT_VALUE'; label='Event'; attributeTypeId='CAD_EVENT_SELECT_VALUE'}) -Parent 'ROW_0')
    $scaffold['ROW_0_FR'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('12')}) -IsCanvas $true -Nodes @('LinkToEvent_Input') -Parent 'CONTEXT_INFO_CARD')
    $scaffold['LinkToEvent_Input'] = (New-Node -ResolvedName 'FormCheckbox' -DisplayName 'Checkbox' -Props ([ordered]@{fieldId='LINK_CURRENT_ASSIGNED_EVENT'; label='Link to Current Assigned Event'}) -Parent 'ROW_0_FR')
    return $scaffold
}

# =====================================================================
# VEHICLE MULTI-CARD: PLATE card + VIN card
# =====================================================================
function Build-VehicleLayout {
    param([string]$Variant = 'default')

    $pageChildren = @('CARD_VEH_PLATE', 'CARD_VEH_VIN')
    switch ($Variant) {
        'default'          { $layout = New-Scaffold -PageChildren $pageChildren }
        'CAD_DISPATCH'     { $layout = New-CadScaffold -PageChildren $pageChildren }
        'FIRST_RESPONDER'  { $layout = New-FrScaffold -PageChildren $pageChildren }
    }

    # CARD: PLATE
    $layout['CARD_VEH_PLATE'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='VEHICLE SEARCH - PLATE'}) -IsCanvas $true -Nodes @('ROW_VEH_P1','ROW_VEH_P2') -Parent 'ROOT_PAGE')
    $layout['ROW_VEH_P1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','3','3')}) -IsCanvas $true -Nodes @('LicensePlateNumberIn_Input','RegistrationState_Input','LicensePlateTypeCode_Input') -Parent 'CARD_VEH_PLATE')
    $layout['LicensePlateNumberIn_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='LicensePlateNumberIn'; label='Plate Number'; maxLength='10'}) -Parent 'ROW_VEH_P1')
    $layout['RegistrationState_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='RegistrationState'; label='State'; attributeTypeId='STATE'; initialValue='NJ'}) -Parent 'ROW_VEH_P1')
    $layout['LicensePlateTypeCode_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='LicensePlateTypeCode'; label='Plate Type'; codeTypeCategory='NCIC_LICENSE_PLATE_TYPE'; codeTypeSource='NCIC'}) -Parent 'ROW_VEH_P1')
    $layout['ROW_VEH_P2'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('12')}) -IsCanvas $true -Nodes @('LicensePlateYear_Input') -Parent 'CARD_VEH_PLATE')
    $layout['LicensePlateYear_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='LicensePlateYear'; label='Plate Year'; maxLength='4'}) -Parent 'ROW_VEH_P2')

    # CARD: VIN
    $layout['CARD_VEH_VIN'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='VEHICLE SEARCH - VIN'}) -IsCanvas $true -Nodes @('ROW_VEH_V1') -Parent 'ROOT_PAGE')
    $layout['ROW_VEH_V1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('8','4')}) -IsCanvas $true -Nodes @('VehicleIdentificationNumber_Input','RegistrationState_VIN_Input') -Parent 'CARD_VEH_VIN')
    $layout['VehicleIdentificationNumber_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='VehicleIdentificationNumber'; label='VIN'; maxLength='20'}) -Parent 'ROW_VEH_V1')
    $layout['RegistrationState_VIN_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='RegistrationState'; label='State'; attributeTypeId='STATE'; initialValue='NJ'}) -Parent 'ROW_VEH_V1')

    return $layout
}

# =====================================================================
# PERSON MULTI-CARD: OLN card + NAME card
# =====================================================================
function Build-PersonLayout {
    param([string]$Variant = 'default')

    $pageChildren = @('CARD_PER_OLN', 'CARD_PER_NAME')
    switch ($Variant) {
        'default'          { $layout = New-Scaffold -PageChildren $pageChildren }
        'CAD_DISPATCH'     { $layout = New-CadScaffold -PageChildren $pageChildren }
        'FIRST_RESPONDER'  { $layout = New-FrScaffold -PageChildren $pageChildren }
    }

    # CARD: OLN
    $layout['CARD_PER_OLN'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='DRIVER LICENSE - LICENSE NUMBER'}) -IsCanvas $true -Nodes @('ROW_PER_O1') -Parent 'ROOT_PAGE')
    $layout['ROW_PER_O1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','3','3')}) -IsCanvas $true -Nodes @('OperatorLicenseNumber_Input','RegistrationState_Input','ImageIndicator_Input') -Parent 'CARD_PER_OLN')
    $layout['OperatorLicenseNumber_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='OperatorLicenseNumber'; label='License Number'; maxLength='20'}) -Parent 'ROW_PER_O1')
    $layout['RegistrationState_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='RegistrationState'; label='State'; attributeTypeId='STATE'; initialValue='NJ'}) -Parent 'ROW_PER_O1')
    $layout['ImageIndicator_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='ImageIndicator'; label='Image'; initialValue='Y'; codeTypeSource='NIBRS'; codeTypeCategory='YES_NO_UNKNOWN'}) -Parent 'ROW_PER_O1')

    # CARD: NAME
    $layout['CARD_PER_NAME'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='DRIVER LICENSE - NAME'}) -IsCanvas $true -Nodes @('ROW_PER_N1','ROW_PER_N2') -Parent 'ROOT_PAGE')
    $layout['ROW_PER_N1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','6')}) -IsCanvas $true -Nodes @('NameFirst_Input','NameLast_Input') -Parent 'CARD_PER_NAME')
    $layout['NameFirst_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='NameFirst'; label='First Name'; maxLength='30'}) -Parent 'ROW_PER_N1')
    $layout['NameLast_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='NameLast'; label='Last Name'; maxLength='30'}) -Parent 'ROW_PER_N1')
    $layout['ROW_PER_N2'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','6')}) -IsCanvas $true -Nodes @('BirthDate_Input','SexCode_Input') -Parent 'CARD_PER_NAME')
    $layout['BirthDate_Input'] = (New-Node -ResolvedName 'FormDate' -DisplayName 'Date' -Props ([ordered]@{fieldId='BirthDate'; label='Date of Birth'}) -Parent 'ROW_PER_N2')
    $layout['SexCode_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='SexCode'; label='Sex'; attributeTypeId='SEX'; codeTypeProvider='NIBRS'}) -Parent 'ROW_PER_N2')

    return $layout
}

# =====================================================================
# BOAT MULTI-CARD: REG card + HULL card
# =====================================================================
function Build-BoatLayout {
    param([string]$Variant = 'default')

    $pageChildren = @('CARD_BOAT_REG', 'CARD_BOAT_HULL')
    switch ($Variant) {
        'default'          { $layout = New-Scaffold -PageChildren $pageChildren }
        'CAD_DISPATCH'     { $layout = New-CadScaffold -PageChildren $pageChildren }
        'FIRST_RESPONDER'  { $layout = New-FrScaffold -PageChildren $pageChildren }
    }

    # CARD: Registration
    $layout['CARD_BOAT_REG'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='BOAT SEARCH - REGISTRATION'}) -IsCanvas $true -Nodes @('ROW_BOAT_R1') -Parent 'ROOT_PAGE')
    $layout['ROW_BOAT_R1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('8','4')}) -IsCanvas $true -Nodes @('RegistrationNumber_Input','RegistrationState_Input') -Parent 'CARD_BOAT_REG')
    $layout['RegistrationNumber_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='RegistrationNumber'; label='Registration Number'; maxLength='8'}) -Parent 'ROW_BOAT_R1')
    $layout['RegistrationState_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='RegistrationState'; label='State'; attributeTypeId='STATE'; initialValue='NJ'}) -Parent 'ROW_BOAT_R1')

    # CARD: Hull
    $layout['CARD_BOAT_HULL'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='BOAT SEARCH - HULL'}) -IsCanvas $true -Nodes @('ROW_BOAT_H1') -Parent 'ROOT_PAGE')
    $layout['ROW_BOAT_H1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('12')}) -IsCanvas $true -Nodes @('BoatHullIdNumber_Input') -Parent 'CARD_BOAT_HULL')
    $layout['BoatHullIdNumber_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='BoatHullIdNumber'; label='Hull ID Number'; maxLength='20'}) -Parent 'ROW_BOAT_H1')

    return $layout
}

# =====================================================================
# APPLY LAYOUTS
# =====================================================================

$entities = $data.bundles[1].configurations
Write-Host "Found $($entities.Count) QIFs in ENTITIES bundle" -ForegroundColor Cyan

foreach ($qif in $entities) {
    $entity = $qif.targetEntity
    switch ($entity) {
        'Vehicle' {
            Write-Host "  Vehicle: replacing with 2-card layout (PLATE + VIN)" -ForegroundColor Green
            $qif.description = "Vehicle queries -- multi-card: PLATE (RQ) and VIN (RQN) cards. RegistrationState (NCIC) on both cards."
            $qif.layout = [ordered]@{
                default         = (Build-VehicleLayout -Variant 'default')
                CAD_DISPATCH    = (Build-VehicleLayout -Variant 'CAD_DISPATCH')
                FIRST_RESPONDER = (Build-VehicleLayout -Variant 'FIRST_RESPONDER')
            }
        }
        'Person' {
            Write-Host "  Person: replacing with 2-card layout (OLN + NAME)" -ForegroundColor Green
            $qif.description = "Person queries -- multi-card: LICENSE NUMBER (DQN) and NAME (DQ) cards. State + Image on OLN card cross to Name card."
            $qif.layout = [ordered]@{
                default         = (Build-PersonLayout -Variant 'default')
                CAD_DISPATCH    = (Build-PersonLayout -Variant 'CAD_DISPATCH')
                FIRST_RESPONDER = (Build-PersonLayout -Variant 'FIRST_RESPONDER')
            }
        }
        'Boat' {
            Write-Host "  Boat: replacing with 2-card layout (REG + HULL)" -ForegroundColor Green
            $qif.description = "Boat queries -- multi-card: REGISTRATION (BQ) and HULL (BQN) cards. State on Reg card."
            $qif.layout = [ordered]@{
                default         = (Build-BoatLayout -Variant 'default')
                CAD_DISPATCH    = (Build-BoatLayout -Variant 'CAD_DISPATCH')
                FIRST_RESPONDER = (Build-BoatLayout -Variant 'FIRST_RESPONDER')
            }
        }
        default {
            Write-Host "  ${entity}: keeping single-card layout" -ForegroundColor DarkGray
        }
    }
}

# Update provider bundle description
$data.bundles[0].description = "Provider configuration for NJ_NJCJIS v2.0"

# =====================================================================
# SERIALIZE AND FIX PS 5.1 ISSUES
# =====================================================================

Write-Host "`nSerializing JSON..." -ForegroundColor Cyan
$output = $data | ConvertTo-Json -Depth 30

# Fix PS 5.1 single-element array unwrapping
# Pattern: "nodes":  "FORM_ROOT" -> "nodes":  ["FORM_ROOT"]
$output = [regex]::Replace($output, '"nodes":\s+"([^"]+)"', '"nodes":  ["$1"]')

# Fix: "templateColumns":  "12" -> "templateColumns":  ["12"]
$output = [regex]::Replace($output, '"templateColumns":\s+"(\d+)"', '"templateColumns":  ["$1"]')

# Fix: "sourceField":  "xxx" -> "sourceField":  ["xxx"]
$output = [regex]::Replace($output, '"sourceField":\s+"([^"]+)"', '"sourceField":  ["$1"]')

# Fix: "set":  "xxx" -> "set":  ["xxx"]
$output = [regex]::Replace($output, '"set":\s+"([^"]+)"', '"set":  ["$1"]')

# Fix: "any":  "xxx" -> "any":  ["xxx"]  (but NOT empty any)
$output = [regex]::Replace($output, '"any":\s+"([^"]+)"', '"any":  ["$1"]')

# Fix: "arguments":  "xxx" -> "arguments":  ["xxx"]
$output = [regex]::Replace($output, '"arguments":\s+"([^"]+)"', '"arguments":  ["$1"]')

# Write output
$output | Out-File $OutputPath -Encoding UTF8
Write-Host "`nSaved: $OutputPath" -ForegroundColor Green

# Count nodes per entity for verification
$parsed = $output | ConvertFrom-Json
$entitiesBundle = $parsed.bundles[1]
foreach ($qif in $entitiesBundle.configurations) {
    $defLayout = $qif.layout.default
    $props = $defLayout.PSObject.Properties
    $nodeCount = $props.Count
    $cards = @($props | Where-Object { $_.Value.type.resolvedName -eq 'Card' }).Count
    $fields = @($props | Where-Object { $_.Value.type.resolvedName -match 'Form(Input|Select|Date|Checkbox)' }).Count
    Write-Host "  $($qif.targetEntity): $nodeCount nodes, $cards cards, $fields fields" -ForegroundColor Cyan
}

Write-Host "`nDone. Run validate.ps1 to verify." -ForegroundColor Green
