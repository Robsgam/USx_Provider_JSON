# build_fl_fcic_entity_split.ps1
# Replaces the single ENTITY_Person with two forms, both targetEntity='Person'.
# Follows the NJ_NJCJIS_entity_split_test.json / build_person_entity_test.ps1 pattern:
#   - Multiple QUERYINPUTFORMs sharing the same targetEntity
#   - label (not targetEntity) becomes the tab display name
#   - Single ROOT_CARD per form; no sub-cards
#   - No mapping changes needed — fieldId routing handles tab separation naturally
#
# Person (In State)    -- InState fieldIds (NameFirst, BirthDate, OperatorLicenseNumber, etc.)
#                         FDQ / QW / KQ combinations light here
# Person (Out of State) -- OOS fieldIds (NameFirstOOS, BirthDateOOS, OperatorLicenseNumberOOS, etc.)
#                          DQ / KQ*OOS combinations light here

$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$eb = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS  (mirroring NJ build_person_entity_test.ps1 conventions)
# ─────────────────────────────────────────────────────────────────────────────

# N: generic node builder — parent omitted when empty string (matches NJ ROOT pattern)
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

# BuildLayout: builds a single default layout variant
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
    [PSCustomObject]$l
}

# AddCadNodes: clone a default layout and insert CONTEXT_INFO_CARD for CAD_DISPATCH
function AddCadNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (
        N 'Card' 'Card' @{} $true $false @('ROW_0') 'ROOT_PAGE'
    ) -Force
    $clone | Add-Member -NotePropertyName 'ROW_0' -NotePropertyValue (
        N 'Row' 'Row' @{ templateColumns = @('6','6') } $true $false @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD'
    ) -Force
    $clone | Add-Member -NotePropertyName 'CadUnit_Input' -NotePropertyValue (
        Sel 'CAD_UNIT_SELECT_VALUE' 'Requesting Unit' @{ attributeTypeId = 'CAD_UNIT_SELECT_VALUE' } 'ROW_0'
    ) -Force
    $clone | Add-Member -NotePropertyName 'CadEvent_Input' -NotePropertyValue (
        Sel 'CAD_EVENT_SELECT_VALUE' 'Event' @{ attributeTypeId = 'CAD_EVENT_SELECT_VALUE'; performSearchAhead = $true } 'ROW_0'
    ) -Force
    $clone
}

# MakeLayouts: build all three variants
function MakeLayouts($rowDefs, $rootCardRowIds) {
    $def = BuildLayout $rowDefs $rootCardRowIds
    $cad = AddCadNodes $def
    $fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# FORM 1 — Person (In State)
# Covers: FDQ (FL DHSMV DL) + QW (NCIC Wanted) + KQ (FL Driver History)
# Fields use base fieldIds — InState combinations fire here, OOS combos cannot.
#
# ROW_1 [6,6]:       OperatorLicenseNumber | RegistrationState (FL default)
# ROW_2 [6,6]:       First Name | Last Name
# ROW_3 [6,6,6,6]:   Middle Name | Suffix | DOB | Sex
# ROW_4 [6,6]:       Attention (req for Driver History - Name)  |  Purpose Code
# ROW_5 [6,6]:       Attention (req for Driver History - OLN)   |  Purpose Code
# ─────────────────────────────────────────────────────────────────────────────
$inStateLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'OLN_Input';   node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_1' }
        @{ id = 'State_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'FL' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_2' }
        @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('3','3','3','3'); fields = @(
        @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_3' }
        @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '4'  'ROW_3' }
        @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'    'ROW_3' }
        @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX' } 'ROW_3' }
    )}
    @{ id = 'ROW_4'; cols = @('6','6'); fields = @(
        @{ id = 'AttentionName_Input';   node = Inp 'AttentionName'   'Attention (DH by Name)'    '30' 'ROW_4' }
        @{ id = 'PurposeCodeName_Input'; node = Inp 'PurposeCodeName' 'Purpose Code (DH by Name)' '1'  'ROW_4' }
    )}
    @{ id = 'ROW_5'; cols = @('6','6'); fields = @(
        @{ id = 'AttentionDL_Input';   node = Inp 'AttentionDL'   'Attention (DH by OLN)'    '30' 'ROW_5' }
        @{ id = 'PurposeCodeDL_Input'; node = Inp 'PurposeCodeDL' 'Purpose Code (DH by OLN)' '1'  'ROW_5' }
    )}
) @('ROW_1','ROW_2','ROW_3','ROW_4','ROW_5')

$personFormInState = [PSCustomObject]@{
    name         = 'ENTITY_Person_InState'
    type         = 'QUERYINPUTFORM'
    description  = 'Person entity form -- in-state (FL DHSMV + NCIC Wanted + FL Driver History)'
    label        = 'Person (In State)'
    targetEntity = 'Person'
    layout       = $inStateLayout
}

# ─────────────────────────────────────────────────────────────────────────────
# FORM 2 — Person (Out of State)
# Covers: DQ (Nlets OOS DL) + KQ*OOS (FL OOS Driver History)
# Fields use OOS fieldIds — OOS combinations fire here, InState combos cannot.
#
# ROW_1 [6,6]:       OLN (OOS) | State (no default, for DQOperatorLicenseNumber)
# ROW_2 [6,6]:       First Name (OOS) | Last Name (OOS)
# ROW_3 [3,3,3,3]:   Middle (OOS) | Suffix (OOS) | DOB (OOS) | Sex (OOS)
# ROW_4 [12]:        State OOS (for DQName + KQ*OOS Name -- RegistrationStateOOS)
# ROW_5 [6,6]:       Attention (OOS Name DH) | Purpose Code (OOS Name DH)
# ROW_6 [6,6]:       Attention (OOS OLN DH, base fieldId) | Purpose Code (OOS OLN DH, base fieldId)
# ─────────────────────────────────────────────────────────────────────────────
$outOfStateLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'OLN_OOS_Input';   node = Inp 'OperatorLicenseNumberOOS' 'License Number' '20' 'ROW_1' }
        @{ id = 'State_DL_Input';  node = Sel 'RegistrationState' 'State (OLN search)' @{ attributeTypeId = 'STATE' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'NameFirst_OOS_Input'; node = Inp 'NameFirstOOS' 'First Name' '30' 'ROW_2' }
        @{ id = 'NameLast_OOS_Input';  node = Inp 'NameLastOOS'  'Last Name'  '30' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('3','3','3','3'); fields = @(
        @{ id = 'NameMiddle_OOS_Input'; node = Inp 'NameMiddleOOS' 'Middle Name' '30' 'ROW_3' }
        @{ id = 'NameSuffix_OOS_Input'; node = Inp 'NameSuffixOOS' 'Suffix'      '4'  'ROW_3' }
        @{ id = 'BirthDate_OOS_Input';  node = Dt  'BirthDateOOS'  'Date of Birth'    'ROW_3' }
        @{ id = 'SexCode_OOS_Input';    node = Sel 'SexCodeOOS' 'Sex' @{ attributeTypeId = 'SEX' } 'ROW_3' }
    )}
    @{ id = 'ROW_4'; cols = @('12'); fields = @(
        @{ id = 'State_Name_Input'; node = Sel 'RegistrationStateOOS' 'State (Name search, required)' @{ attributeTypeId = 'STATE' } 'ROW_4' }
    )}
    @{ id = 'ROW_5'; cols = @('6','6'); fields = @(
        @{ id = 'Attention_OOS_Input';    node = Inp 'AttentionOOS'   'Attention (DH by Name)'    '30' 'ROW_5' }
        @{ id = 'PurposeCode_OOS_Input';  node = Inp 'PurposeCodeOOS' 'Purpose Code (DH by Name)' '1'  'ROW_5' }
    )}
    @{ id = 'ROW_6'; cols = @('6','6'); fields = @(
        @{ id = 'Attention_Input';    node = Inp 'Attention'   'Attention (DH by OLN)'    '30' 'ROW_6' }
        @{ id = 'PurposeCode_Input';  node = Inp 'PurposeCode' 'Purpose Code (DH by OLN)' '1'  'ROW_6' }
    )}
) @('ROW_1','ROW_2','ROW_3','ROW_4','ROW_5','ROW_6')

$personFormOutOfState = [PSCustomObject]@{
    name         = 'ENTITY_Person_OOS'
    type         = 'QUERYINPUTFORM'
    description  = 'Person entity form -- out-of-state (Nlets DL + OOS Driver History)'
    label        = 'Person (Out of State)'
    targetEntity = 'Person'
    layout       = $outOfStateLayout
}

# ─────────────────────────────────────────────────────────────────────────────
# Replace ENTITY_Person in the ENTITIES bundle
# ─────────────────────────────────────────────────────────────────────────────
$newCfgs = [System.Collections.Generic.List[object]]::new()
$eb.configurations | ForEach-Object {
    if ($_.name -eq 'ENTITY_Person') {
        $newCfgs.Add($personFormInState)
        $newCfgs.Add($personFormOutOfState)
    } else {
        $newCfgs.Add($_)
    }
}
$eb.configurations = $newCfgs.ToArray()

# order stays as-is ('Person' covers both new forms since both have targetEntity='Person')

# ─────────────────────────────────────────────────────────────────────────────
# Save
# ─────────────────────────────────────────────────────────────────────────────
$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# ─────────────────────────────────────────────────────────────────────────────
# Verify
# ─────────────────────────────────────────────────────────────────────────────
$v2  = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2 = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb2 = $v2.bundles | Where-Object { $_.name -eq 'FL_FCIC' }

Write-Host ''
Write-Host 'ENTITIES configs:' ($eb2.configurations | ForEach-Object { "$($_.name) [targetEntity=$($_.targetEntity)]" })
Write-Host 'FL_FCIC mapping targetEntities (driver):'
$fb2.configurations | Where-Object { $_.query -match 'Driver' } | ForEach-Object {
    Write-Host "  $($_.name): targetEntity='$($_.targetEntity)'  combos: $(($_.combinations.keyReference) -join ',')"
}
Write-Host 'Order default:' ($eb2.order.default -join ', ')
Write-Host ''
Write-Host 'InState form default nodes:' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_InState' }).layout.default.PSObject.Properties.Name -join ', '
Write-Host 'OOS form default nodes:' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }).layout.default.PSObject.Properties.Name -join ', '
