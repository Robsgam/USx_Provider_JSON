param(
    [string]$InputPath = "$PSScriptRoot\FL_FCIC_v2.2_test.json",
    [string]$OutputPath = "$PSScriptRoot\FL_FCIC_v2.3_split.json"
)

Write-Host "FL_FCIC v2.3 Split Entity Person"
Write-Host "================================="
Write-Host "Input: $InputPath"

$data = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entities = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$personIdx = -1
for ($i = 0; $i -lt $entities.configurations.Count; $i++) {
    if ($entities.configurations[$i].label -eq 'Person') { $personIdx = $i; break }
}
if ($personIdx -lt 0) { Write-Error "Person QIF not found"; exit 1 }
$person = $entities.configurations[$personIdx]
Write-Host "Found Person QIF at index $personIdx"

function New-Node($type, $displayName, $props, $parent, $nodes, $isCanvas) {
    $n = [ordered]@{
        type        = [ordered]@{ resolvedName = $type }
        displayName = $displayName
        props       = $props
        isCanvas    = [bool]$isCanvas
        hidden      = $false
        nodes       = @($nodes)
        linkedNodes = [ordered]@{}
    }
    if ($parent) { $n.parent = $parent } else { $n.parent = $null }
    return $n
}

function New-Scaffold($cardIds) {
    $layout = [ordered]@{}
    $layout['ROOT'] = New-Node 'Root' 'Root' ([ordered]@{}) $null @('FORM_ROOT') $false
    $layout['FORM_ROOT'] = New-Node 'Form' 'Form' ([ordered]@{ hidePageItems = $true; layout = 'page' }) 'ROOT' @('ROOT_PAGE') $true
    $layout['ROOT_PAGE'] = New-Node 'Page' 'Page' ([ordered]@{ title = 'Page 1' }) 'FORM_ROOT' $cardIds $true
    return $layout
}

function Add-Card($layout, $cardId, $title, $rowIds) {
    $layout[$cardId] = New-Node 'Card' 'Card' ([ordered]@{ title = $title }) 'ROOT_PAGE' $rowIds $true
}

function Add-Row($layout, $rowId, $cardId, $columns, $fieldIds) {
    $cols = @($columns | ForEach-Object { "$_" })
    $layout[$rowId] = New-Node 'Row' 'Row' ([ordered]@{ templateColumns = $cols }) $cardId $fieldIds $true
}

function Add-Input($layout, $nodeId, $rowId, $fieldId, $label, $maxLen) {
    $props = [ordered]@{ fieldId = $fieldId; label = $label }
    if ($maxLen) { $props.maxLength = "$maxLen" }
    $layout[$nodeId] = New-Node 'FormInput' 'Input' $props $rowId @() $false
}

function Add-Select($layout, $nodeId, $rowId, $fieldId, $label, $extraProps) {
    $props = [ordered]@{ fieldId = $fieldId; label = $label }
    if ($extraProps) { foreach ($k in $extraProps.Keys) { $props[$k] = $extraProps[$k] } }
    $layout[$nodeId] = New-Node 'FormSelect' 'Select' $props $rowId @() $false
}

function Add-Date($layout, $nodeId, $rowId, $fieldId, $label) {
    $props = [ordered]@{ fieldId = $fieldId; label = $label }
    $layout[$nodeId] = New-Node 'FormDate' 'Date' $props $rowId @() $false
}

# ============================================================
# QIF 1: Person - FL (In-State)
# ============================================================
function Build-PersonFL {
    $cards = @('CARD_FL_IMG','CARD_FL_OLN','CARD_FL_NAME')
    $layout = New-Scaffold $cards

    # Card 1: Image only (no State needed for FL in-state)
    Add-Card $layout 'CARD_FL_IMG' 'Search Options' @('ROW_FL_IMG')
    Add-Row $layout 'ROW_FL_IMG' 'CARD_FL_IMG' @(6) @('FL_ImageIndicator_Input')
    Add-Select $layout 'FL_ImageIndicator_Input' 'ROW_FL_IMG' 'ImageIndicator' 'Image Indicator' ([ordered]@{ initialValue = 'Y'; codeTypeSource = 'NIBRS'; codeTypeCategory = 'YES_NO_UNKNOWN' })

    # Card 2: OLN
    Add-Card $layout 'CARD_FL_OLN' 'Either...by License Number' @('ROW_FL_OLN')
    Add-Row $layout 'ROW_FL_OLN' 'CARD_FL_OLN' @(12) @('FL_OLN_Input')
    Add-Input $layout 'FL_OLN_Input' 'ROW_FL_OLN' 'OperatorLicenseNumber' 'OLN' '20'

    # Card 3: Name + DOB + Sex
    Add-Card $layout 'CARD_FL_NAME' 'Or...by Name' @('ROW_FL_NAME1','ROW_FL_NAME2')
    Add-Row $layout 'ROW_FL_NAME1' 'CARD_FL_NAME' @(6,6) @('FL_NameFirst_Input','FL_NameLast_Input')
    Add-Input $layout 'FL_NameFirst_Input' 'ROW_FL_NAME1' 'NameFirst' 'First Name' $null
    Add-Input $layout 'FL_NameLast_Input' 'ROW_FL_NAME1' 'NameLast' 'Last Name' $null

    Add-Row $layout 'ROW_FL_NAME2' 'CARD_FL_NAME' @(3,3,3,3) @('FL_NameMiddle_Input','FL_NameSuffix_Input','FL_BirthDate_Input','FL_SexCode_Input')
    Add-Input $layout 'FL_NameMiddle_Input' 'ROW_FL_NAME2' 'NameMiddle' 'M.I.' $null
    Add-Input $layout 'FL_NameSuffix_Input' 'ROW_FL_NAME2' 'NameSuffix' 'Suffix' $null
    Add-Date $layout 'FL_BirthDate_Input' 'ROW_FL_NAME2' 'BirthDate' 'Date of Birth'
    Add-Select $layout 'FL_SexCode_Input' 'ROW_FL_NAME2' 'SexCode' 'Sex' ([ordered]@{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' })

    return $layout
}

# ============================================================
# QIF 2: Person - Out of State
# ============================================================
function Build-PersonOOS {
    $cards = @('CARD_OOS_OPT','CARD_OOS_OLN','CARD_OOS_NAME')
    $layout = New-Scaffold $cards

    # Card 1: State (required for OOS) + Image
    Add-Card $layout 'CARD_OOS_OPT' 'Search Options' @('ROW_OOS_OPT')
    Add-Row $layout 'ROW_OOS_OPT' 'CARD_OOS_OPT' @(6,6) @('OOS_RegistrationState_Input','OOS_ImageIndicator_Input')
    Add-Select $layout 'OOS_RegistrationState_Input' 'ROW_OOS_OPT' 'RegistrationState' 'State' ([ordered]@{ attributeTypeId = 'STATE'; codeTypeProvider = 'NCIC' })
    Add-Select $layout 'OOS_ImageIndicator_Input' 'ROW_OOS_OPT' 'ImageIndicator' 'Image Indicator' ([ordered]@{ initialValue = 'Y'; codeTypeSource = 'NIBRS'; codeTypeCategory = 'YES_NO_UNKNOWN' })

    # Card 2: OLN
    Add-Card $layout 'CARD_OOS_OLN' 'Either...by License Number' @('ROW_OOS_OLN')
    Add-Row $layout 'ROW_OOS_OLN' 'CARD_OOS_OLN' @(12) @('OOS_OLN_Input')
    Add-Input $layout 'OOS_OLN_Input' 'ROW_OOS_OLN' 'OperatorLicenseNumber' 'OLN' '20'

    # Card 3: Name + DOB + Sex
    Add-Card $layout 'CARD_OOS_NAME' 'Or...by Name' @('ROW_OOS_NAME1','ROW_OOS_NAME2')
    Add-Row $layout 'ROW_OOS_NAME1' 'CARD_OOS_NAME' @(6,6) @('OOS_NameFirst_Input','OOS_NameLast_Input')
    Add-Input $layout 'OOS_NameFirst_Input' 'ROW_OOS_NAME1' 'NameFirst' 'First Name' $null
    Add-Input $layout 'OOS_NameLast_Input' 'ROW_OOS_NAME1' 'NameLast' 'Last Name' $null

    Add-Row $layout 'ROW_OOS_NAME2' 'CARD_OOS_NAME' @(3,3,3,3) @('OOS_NameMiddle_Input','OOS_NameSuffix_Input','OOS_BirthDate_Input','OOS_SexCode_Input')
    Add-Input $layout 'OOS_NameMiddle_Input' 'ROW_OOS_NAME2' 'NameMiddle' 'M.I.' $null
    Add-Input $layout 'OOS_NameSuffix_Input' 'ROW_OOS_NAME2' 'NameSuffix' 'Suffix' $null
    Add-Date $layout 'OOS_BirthDate_Input' 'ROW_OOS_NAME2' 'BirthDate' 'Date of Birth'
    Add-Select $layout 'OOS_SexCode_Input' 'ROW_OOS_NAME2' 'SexCode' 'Sex' ([ordered]@{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' })

    return $layout
}

# ============================================================
# QIF 3: Person - Driver History
# ============================================================
function Build-PersonDH {
    $cards = @('CARD_DH_REQ','CARD_DH_OLN2','CARD_DH_NAM')
    $layout = New-Scaffold $cards

    # Card 1: State (FL default) + Purpose + Attention + Image
    Add-Card $layout 'CARD_DH_REQ' 'Driver History Options' @('ROW_DH_REQ1','ROW_DH_REQ2')
    Add-Row $layout 'ROW_DH_REQ1' 'CARD_DH_REQ' @(6,6) @('DH_RegistrationState_Input','DH_ImageIndicator_Input')
    Add-Select $layout 'DH_RegistrationState_Input' 'ROW_DH_REQ1' 'RegistrationState' 'State' ([ordered]@{ attributeTypeId = 'STATE'; codeTypeProvider = 'NCIC'; initialValue = 'FL' })
    Add-Select $layout 'DH_ImageIndicator_Input' 'ROW_DH_REQ1' 'ImageIndicator' 'Image Indicator' ([ordered]@{ initialValue = 'Y'; codeTypeSource = 'NIBRS'; codeTypeCategory = 'YES_NO_UNKNOWN' })

    Add-Row $layout 'ROW_DH_REQ2' 'CARD_DH_REQ' @(6,6) @('DH_PurposeCode_Input','DH_Attention_Input')
    Add-Input $layout 'DH_PurposeCode_Input' 'ROW_DH_REQ2' 'PurposeCode' 'Purpose Code' '1'
    Add-Input $layout 'DH_Attention_Input' 'ROW_DH_REQ2' 'Attention' 'Attention' '30'

    # Card 2: DH OLN
    Add-Card $layout 'CARD_DH_OLN2' 'Either...by License Number' @('ROW_DH_OLN2')
    Add-Row $layout 'ROW_DH_OLN2' 'CARD_DH_OLN2' @(12) @('DH_OLN_Input')
    Add-Input $layout 'DH_OLN_Input' 'ROW_DH_OLN2' 'OperatorLicenseNumberDH' 'OLN' '20'

    # Card 3: DH Name + DOB + Sex
    Add-Card $layout 'CARD_DH_NAM' 'Or...by Name' @('ROW_DH_NAM1','ROW_DH_NAM2')
    Add-Row $layout 'ROW_DH_NAM1' 'CARD_DH_NAM' @(6,6) @('DH_NameFirst_Input','DH_NameLast_Input')
    Add-Input $layout 'DH_NameFirst_Input' 'ROW_DH_NAM1' 'NameFirstDH' 'First Name' $null
    Add-Input $layout 'DH_NameLast_Input' 'ROW_DH_NAM1' 'NameLastDH' 'Last Name' $null

    Add-Row $layout 'ROW_DH_NAM2' 'CARD_DH_NAM' @(3,3,3,3) @('DH_NameMiddle_Input','DH_NameSuffix_Input','DH_BirthDate_Input','DH_SexCode_Input')
    Add-Input $layout 'DH_NameMiddle_Input' 'ROW_DH_NAM2' 'NameMiddleDH' 'M.I.' $null
    Add-Input $layout 'DH_NameSuffix_Input' 'ROW_DH_NAM2' 'NameSuffixDH' 'Suffix' $null
    Add-Date $layout 'DH_BirthDate_Input' 'ROW_DH_NAM2' 'BirthDateDH' 'Date of Birth'
    Add-Select $layout 'DH_SexCode_Input' 'ROW_DH_NAM2' 'SexCodeDH' 'Sex' ([ordered]@{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' })

    return $layout
}

# Build all 3 layouts
$layoutFL  = Build-PersonFL
$layoutOOS = Build-PersonOOS
$layoutDH  = Build-PersonDH

# Create QIF configs
function New-QIF($name, $label, $layout) {
    return [ordered]@{
        description   = ''
        label         = $label
        layout        = [ordered]@{ default = $layout }
        name          = $name
        targetEntity  = 'Person'
        type          = 'QUERYINPUTFORM'
    }
}

$qifFL  = New-QIF 'ENTITY_Person_FL'  'Person - FL'             $layoutFL
$qifOOS = New-QIF 'ENTITY_Person_OOS' 'Person - Out of State'   $layoutOOS
$qifDH  = New-QIF 'ENTITY_Person_DH'  'Person - Driver History'  $layoutDH

# Replace Person QIF with 3 new ones
$newConfigs = @()
for ($i = 0; $i -lt $entities.configurations.Count; $i++) {
    if ($i -eq $personIdx) {
        $newConfigs += $qifFL
        $newConfigs += $qifOOS
        $newConfigs += $qifDH
    } else {
        $newConfigs += $entities.configurations[$i]
    }
}
$entities.configurations = $newConfigs

# Update ENTITIES order (Person appears in all 3 variants)
Write-Host "Updating ENTITIES order..."
# Person entity stays as 'Person' in order (platform groups by targetEntity)

# Serialize
Write-Host "Serializing..."
$json = $data | ConvertTo-Json -Depth 100 -Compress:$false

# PS 5.1 post-processing fixes
# Fix single-element arrays unwrapped to strings
$json = $json -replace '"nodes":\s*"([^"]+)"', '"nodes": ["$1"]'
# Fix templateColumns
$json = $json -replace '"templateColumns":\s*"([^"]+)"', '"templateColumns": ["$1"]'
# Fix empty nodes arrays serialized as null
$json = $json -replace '"nodes":\s*null', '"nodes": []'

# Write without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

$size = (Get-Item $OutputPath).Length
Write-Host ""
Write-Host "Output: $OutputPath ($size bytes)"
Write-Host "Done."
