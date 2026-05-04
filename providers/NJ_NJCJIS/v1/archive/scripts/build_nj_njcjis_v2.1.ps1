# NJ_NJCJIS v2.1 -- Split Entity Person (Phase 3)
# Reads v2.0 multi-card JSON, splits Person into Person-NJ + Person-OOS.
# Vehicle, Firearm, Article, Boat unchanged from v2.0.
# QIDM unchanged -- both Person QIFs target the same 'Person' entity.

param(
    [string]$BasePath = "$PSScriptRoot\..\NJ_NJCJIS_v2.0.json",
    [string]$OutputPath = "$PSScriptRoot\..\NJ_NJCJIS_v2.1.json"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $BasePath)) {
    Write-Error "Base JSON not found: $BasePath"
    return
}

Write-Host "Reading v2.0 JSON: $BasePath" -ForegroundColor Cyan
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

function New-Scaffold {
    param([string[]]$PageChildren)
    $scaffold = [ordered]@{
        ROOT      = (New-Node -ResolvedName 'Root' -DisplayName 'Root' -Nodes @('FORM_ROOT'))
        FORM_ROOT = (New-Node -ResolvedName 'Form' -DisplayName 'Form' -Props ([ordered]@{hidePageItems=$true; layout='page'}) -IsCanvas $true -Nodes @('ROOT_PAGE') -Parent 'ROOT')
        ROOT_PAGE = (New-Node -ResolvedName 'Page' -DisplayName 'Page' -Props ([ordered]@{title='Page 1'}) -IsCanvas $true -Nodes $PageChildren -Parent 'FORM_ROOT')
    }
    return $scaffold
}

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
# PERSON-NJ: OLN + Name cards, hidden RegistrationState (initialValue=NJ)
# State is visible but defaults to NJ via NCIC pattern (same as v2.0)
# =====================================================================
function Build-PersonNJLayout {
    param([string]$Variant = 'default')

    $pageChildren = @('CARD_PER_OLN', 'CARD_PER_NAME')
    switch ($Variant) {
        'default'          { $layout = New-Scaffold -PageChildren $pageChildren }
        'CAD_DISPATCH'     { $layout = New-CadScaffold -PageChildren $pageChildren }
        'FIRST_RESPONDER'  { $layout = New-FrScaffold -PageChildren $pageChildren }
    }

    # CARD: OLN (NJ)
    $layout['CARD_PER_OLN'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='DRIVER LICENSE - LICENSE NUMBER'}) -IsCanvas $true -Nodes @('ROW_PER_O1') -Parent 'ROOT_PAGE')
    $layout['ROW_PER_O1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','3','3')}) -IsCanvas $true -Nodes @('OperatorLicenseNumber_Input','RegistrationState_Input','ImageIndicator_Input') -Parent 'CARD_PER_OLN')
    $layout['OperatorLicenseNumber_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='OperatorLicenseNumber'; label='License Number'; maxLength='20'}) -Parent 'ROW_PER_O1')
    $layout['RegistrationState_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='RegistrationState'; label='State'; attributeTypeId='STATE'; initialValue='NJ'}) -Parent 'ROW_PER_O1')
    $layout['ImageIndicator_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='ImageIndicator'; label='Image'; initialValue='Y'; codeTypeSource='NIBRS'; codeTypeCategory='YES_NO_UNKNOWN'}) -Parent 'ROW_PER_O1')

    # CARD: NAME (NJ)
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
# PERSON-OOS: OLN + Name cards, visible RegistrationState (no initialValue)
# Operator selects state from full dropdown. No initialValue default.
# =====================================================================
function Build-PersonOOSLayout {
    param([string]$Variant = 'default')

    $pageChildren = @('CARD_PER_OLN_OOS', 'CARD_PER_NAME_OOS')
    switch ($Variant) {
        'default'          { $layout = New-Scaffold -PageChildren $pageChildren }
        'CAD_DISPATCH'     { $layout = New-CadScaffold -PageChildren $pageChildren }
        'FIRST_RESPONDER'  { $layout = New-FrScaffold -PageChildren $pageChildren }
    }

    # CARD: OLN (OOS)
    $layout['CARD_PER_OLN_OOS'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='DRIVER LICENSE OOS - LICENSE NUMBER'}) -IsCanvas $true -Nodes @('ROW_PER_OOS_O1') -Parent 'ROOT_PAGE')
    $layout['ROW_PER_OOS_O1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('5','3','2','2')}) -IsCanvas $true -Nodes @('OperatorLicenseNumber_OOS_Input','RegistrationState_OOS_Input','ImageIndicator_OOS_Input') -Parent 'CARD_PER_OLN_OOS')
    $layout['OperatorLicenseNumber_OOS_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='OperatorLicenseNumber'; label='License Number'; maxLength='20'}) -Parent 'ROW_PER_OOS_O1')
    $layout['RegistrationState_OOS_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='RegistrationState'; label='State'; attributeTypeId='STATE'}) -Parent 'ROW_PER_OOS_O1')
    $layout['ImageIndicator_OOS_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='ImageIndicator'; label='Image'; initialValue='Y'; codeTypeSource='NIBRS'; codeTypeCategory='YES_NO_UNKNOWN'}) -Parent 'ROW_PER_OOS_O1')

    # CARD: NAME (OOS)
    $layout['CARD_PER_NAME_OOS'] = (New-Node -ResolvedName 'Card' -DisplayName 'Card' -Props ([ordered]@{title='DRIVER LICENSE OOS - NAME'}) -IsCanvas $true -Nodes @('ROW_PER_OOS_N1','ROW_PER_OOS_N2') -Parent 'ROOT_PAGE')
    $layout['ROW_PER_OOS_N1'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','6')}) -IsCanvas $true -Nodes @('NameFirst_OOS_Input','NameLast_OOS_Input') -Parent 'CARD_PER_NAME_OOS')
    $layout['NameFirst_OOS_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='NameFirst'; label='First Name'; maxLength='30'}) -Parent 'ROW_PER_OOS_N1')
    $layout['NameLast_OOS_Input'] = (New-Node -ResolvedName 'FormInput' -DisplayName 'Input' -Props ([ordered]@{fieldId='NameLast'; label='Last Name'; maxLength='30'}) -Parent 'ROW_PER_OOS_N1')
    $layout['ROW_PER_OOS_N2'] = (New-Node -ResolvedName 'Row' -DisplayName 'Row' -Props ([ordered]@{templateColumns=@('6','6')}) -IsCanvas $true -Nodes @('BirthDate_OOS_Input','SexCode_OOS_Input') -Parent 'CARD_PER_NAME_OOS')
    $layout['BirthDate_OOS_Input'] = (New-Node -ResolvedName 'FormDate' -DisplayName 'Date' -Props ([ordered]@{fieldId='BirthDate'; label='Date of Birth'}) -Parent 'ROW_PER_OOS_N2')
    $layout['SexCode_OOS_Input'] = (New-Node -ResolvedName 'FormSelect' -DisplayName 'Select' -Props ([ordered]@{fieldId='SexCode'; label='Sex'; attributeTypeId='SEX'; codeTypeProvider='NIBRS'}) -Parent 'ROW_PER_OOS_N2')

    return $layout
}

# =====================================================================
# BUILD PERSON QIFs
# =====================================================================

$personNJ = [ordered]@{
    description  = "Person NJ -- multi-card: OLN + Name. State defaults to NJ (NCIC pattern)."
    label        = "Person - NJ"
    layout       = [ordered]@{
        default         = (Build-PersonNJLayout -Variant 'default')
        CAD_DISPATCH    = (Build-PersonNJLayout -Variant 'CAD_DISPATCH')
        FIRST_RESPONDER = (Build-PersonNJLayout -Variant 'FIRST_RESPONDER')
    }
    name         = "ENTITY_Person_NJ"
    type         = "QUERYINPUTFORM"
    targetEntity = "Person"
    provider     = "MARK43"
}

$personOOS = [ordered]@{
    description  = "Person OOS -- multi-card: OLN + Name. State is visible, no default."
    label        = "Person - Out of State"
    layout       = [ordered]@{
        default         = (Build-PersonOOSLayout -Variant 'default')
        CAD_DISPATCH    = (Build-PersonOOSLayout -Variant 'CAD_DISPATCH')
        FIRST_RESPONDER = (Build-PersonOOSLayout -Variant 'FIRST_RESPONDER')
    }
    name         = "ENTITY_Person_OOS"
    type         = "QUERYINPUTFORM"
    targetEntity = "Person"
    provider     = "MARK43"
}

# =====================================================================
# REPLACE PERSON QIF WITH TWO QIFs
# =====================================================================

$entities = $data.bundles[1].configurations
$newConfigs = @()
foreach ($qif in $entities) {
    if ($qif.targetEntity -eq 'Person') {
        Write-Host "  Replacing single Person QIF with Person-NJ + Person-OOS" -ForegroundColor Green
        $newConfigs += $personNJ
        $newConfigs += $personOOS
    } else {
        $newConfigs += $qif
    }
}
$data.bundles[1].configurations = $newConfigs
Write-Host "  ENTITIES bundle now has $($newConfigs.Count) QIFs" -ForegroundColor Cyan

# Update bundle description
$data.bundles[0].description = "Provider configuration for NJ_NJCJIS v2.1"

# =====================================================================
# SERIALIZE AND FIX PS 5.1 ISSUES
# =====================================================================

Write-Host "`nSerializing JSON..." -ForegroundColor Cyan
$output = $data | ConvertTo-Json -Depth 30

# Fix PS 5.1 single-element array unwrapping
$output = [regex]::Replace($output, '"nodes":\s+"([^"]+)"', '"nodes":  ["$1"]')
$output = [regex]::Replace($output, '"templateColumns":\s+"(\d+)"', '"templateColumns":  ["$1"]')
$output = [regex]::Replace($output, '"sourceField":\s+"([^"]+)"', '"sourceField":  ["$1"]')
$output = [regex]::Replace($output, '"set":\s+"([^"]+)"', '"set":  ["$1"]')
$output = [regex]::Replace($output, '"any":\s+"([^"]+)"', '"any":  ["$1"]')
$output = [regex]::Replace($output, '"arguments":\s+"([^"]+)"', '"arguments":  ["$1"]')

# Write without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutputPath, $output, $utf8NoBom)
Write-Host "`nSaved: $OutputPath" -ForegroundColor Green

# Verify
$parsed = $output | ConvertFrom-Json
$entitiesBundle = $parsed.bundles[1]
Write-Host "`nQIF Summary:" -ForegroundColor Cyan
foreach ($qif in $entitiesBundle.configurations) {
    $defLayout = $qif.layout.default
    $props = $defLayout.PSObject.Properties
    $cards = @($props | Where-Object { $_.Value.type.resolvedName -eq 'Card' }).Count
    $fields = @($props | Where-Object { $_.Value.type.resolvedName -match 'Form(Input|Select|Date|Checkbox)' }).Count
    Write-Host "  $($qif.name) [$($qif.targetEntity)]: $cards cards, $fields fields" -ForegroundColor Cyan
}

Write-Host "`nDone. Run validate.ps1 to verify." -ForegroundColor Green
