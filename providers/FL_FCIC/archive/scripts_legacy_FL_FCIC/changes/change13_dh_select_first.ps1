# change13_dh_select_first.ps1
# Adds "Select First" shared card to ENTITY_Person_DH and consolidates
# Attention/PurposeCode fieldIds to base variants.
#
# ENTITY FORM changes (all 3 layout variants):
#   NEW CARD_SELECT_FIRST  -- positioned above CARD_DH_OLN and CARD_DH_NAM
#     SELECT_FIRST_ROW1 [6,6]:  ImageIndicator_Input  |  State_Input
#     SELECT_FIRST_ROW2 [6,6]:  PurposeCode_Input     |  Attention_Input
#       ImageIndicator : FormSelect, YES_NO_UNKNOWN/NIBRS, initialValue=Y
#       State          : FormSelect, RegistrationState, STATE, initialValue=FL
#       PurposeCode    : FormInput,  fieldId=PurposeCode,  maxLength=1
#       Attention      : FormInput,  fieldId=Attention,    maxLength=30
#
#   CARD_DH_OLN  -- AttentionDL + PurposeCodeDL removed (now in shared card)
#     DH_OLN_ROW2 removed; CARD_DH_OLN.nodes = [DH_OLN_ROW1]
#
#   CARD_DH_NAM  -- AttentionName + PurposeCodeName removed (now in shared card)
#     DH_NAM_ROW3 removed; CARD_DH_NAM.nodes = [DH_NAM_ROW1, DH_NAM_ROW2]
#
# MAPPING changes (FL_FCIC_DriverHistoryQuery):
#   KQName requirements.set:
#     AttentionName → Attention
#     PurposeCodeName → PurposeCode
#   KQOperatorLicenseNumber requirements.set:
#     AttentionDL → Attention
#     PurposeCodeDL → PurposeCode
#   Attention attribute:
#     Add rule CommsysGetLastNameFirstNameInitialRuleHandler
#     (auto-populates query Attention value with signed-in user's LName, FInitial)

$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$eb  = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb  = $data.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
$cfg = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }
$dhq = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

# ─────────────────────────────────────────────────────────────────────────────
# HELPER
# ─────────────────────────────────────────────────────────────────────────────

function N($type, $display, $props, $isCanvas, $hidden, $nodeList, $parent) {
    [PSCustomObject][ordered]@{
        type        = [PSCustomObject]@{ resolvedName = $type }
        displayName = $display
        props       = [PSCustomObject]$props
        isCanvas    = [bool]$isCanvas
        hidden      = [bool]$hidden
        nodes       = $nodeList
        linkedNodes = [PSCustomObject]@{}
        parent      = $parent
    }
}

function Sel($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $false @() $parentId
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTITY FORM PATCH
# ─────────────────────────────────────────────────────────────────────────────

function PatchDHLayout($layout) {

    # 1. Insert CARD_SELECT_FIRST before CARD_DH_OLN
    $pageNodes = [System.Collections.Generic.List[string]]($layout.ROOT_PAGE.nodes)
    $idx = $pageNodes.IndexOf('CARD_DH_OLN')
    $pageNodes.Insert($idx, 'CARD_SELECT_FIRST')
    $layout.ROOT_PAGE.nodes = $pageNodes.ToArray()

    # CARD_SELECT_FIRST
    $layout | Add-Member -NotePropertyName 'CARD_SELECT_FIRST' -NotePropertyValue (
        N 'Card' 'Card' @{ title = 'Select First' } $true $false @('SELECT_FIRST_ROW1','SELECT_FIRST_ROW2') 'ROOT_PAGE'
    ) -Force

    # Row 1: ImageIndicator | State
    $layout | Add-Member -NotePropertyName 'SELECT_FIRST_ROW1' -NotePropertyValue (
        N 'Row' 'Row' @{ templateColumns = @('6','6') } $true $false @('ImageIndicator_Input','State_Input') 'CARD_SELECT_FIRST'
    ) -Force
    $layout | Add-Member -NotePropertyName 'ImageIndicator_Input' -NotePropertyValue (
        N 'FormSelect' 'Select' ([ordered]@{
            fieldId          = 'ImageIndicator'
            label            = 'Image Indicator'
            initialValue     = 'Y'
            codeTypeSource   = 'NIBRS'
            codeTypeCategory = 'YES_NO_UNKNOWN'
        }) $false $false @() 'SELECT_FIRST_ROW1'
    ) -Force
    $layout | Add-Member -NotePropertyName 'State_Input' -NotePropertyValue (
        Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'FL' } 'SELECT_FIRST_ROW1'
    ) -Force

    # Row 2: PurposeCode | Attention
    $layout | Add-Member -NotePropertyName 'SELECT_FIRST_ROW2' -NotePropertyValue (
        N 'Row' 'Row' @{ templateColumns = @('6','6') } $true $false @('PurposeCode_Input','Attention_Input') 'CARD_SELECT_FIRST'
    ) -Force
    $layout | Add-Member -NotePropertyName 'PurposeCode_Input' -NotePropertyValue (
        N 'FormInput' 'Input' ([ordered]@{
            fieldId   = 'PurposeCode'
            label     = 'Purpose Code'
            maxLength = '1'
        }) $false $false @() 'SELECT_FIRST_ROW2'
    ) -Force
    $layout | Add-Member -NotePropertyName 'Attention_Input' -NotePropertyValue (
        N 'FormInput' 'Input' ([ordered]@{
            fieldId   = 'Attention'
            label     = 'Attention'
            maxLength = '30'
        }) $false $false @() 'SELECT_FIRST_ROW2'
    ) -Force

    # 2. CARD_DH_OLN — remove DH_OLN_ROW2 (AttentionDL + PurposeCodeDL)
    $layout.CARD_DH_OLN.nodes = @('DH_OLN_ROW1')
    $layout.PSObject.Properties.Remove('DH_OLN_ROW2')
    $layout.PSObject.Properties.Remove('AttentionDL_Input')
    $layout.PSObject.Properties.Remove('PurposeCodeDL_Input')

    # 3. CARD_DH_NAM — remove DH_NAM_ROW3 (AttentionName + PurposeCodeName)
    $layout.CARD_DH_NAM.nodes = @('DH_NAM_ROW1','DH_NAM_ROW2')
    $layout.PSObject.Properties.Remove('DH_NAM_ROW3')
    $layout.PSObject.Properties.Remove('AttentionName_Input')
    $layout.PSObject.Properties.Remove('PurposeCodeName_Input')
}

PatchDHLayout $cfg.layout.default
PatchDHLayout $cfg.layout.CAD_DISPATCH
PatchDHLayout $cfg.layout.FIRST_RESPONDER

# ─────────────────────────────────────────────────────────────────────────────
# MAPPING PATCH — combination requirements
# ─────────────────────────────────────────────────────────────────────────────

# KQName: AttentionName → Attention, PurposeCodeName → PurposeCode
$kqName = $dhq.combinations | Where-Object { $_.keyReference -eq 'KQName' }
$kqName.requirements.set = $kqName.requirements.set | ForEach-Object {
    switch ($_) {
        'AttentionName'   { 'Attention' }
        'PurposeCodeName' { 'PurposeCode' }
        default           { $_ }
    }
}

# KQOperatorLicenseNumber: AttentionDL → Attention, PurposeCodeDL → PurposeCode
$kqOLN = $dhq.combinations | Where-Object { $_.keyReference -eq 'KQOperatorLicenseNumber' }
$kqOLN.requirements.set = $kqOLN.requirements.set | ForEach-Object {
    switch ($_) {
        'AttentionDL'   { 'Attention' }
        'PurposeCodeDL' { 'PurposeCode' }
        default         { $_ }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# MAPPING PATCH — add CommsysGetLastNameFirstNameInitialRuleHandler to Attention
# ─────────────────────────────────────────────────────────────────────────────

$attnAttr = $dhq.attributes | Where-Object { $_.name -eq 'Attention' }
$attnAttr | Add-Member -NotePropertyName 'rule' -NotePropertyValue (
    [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
) -Force

# ─────────────────────────────────────────────────────────────────────────────
# SAVE
# ─────────────────────────────────────────────────────────────────────────────

$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# ─────────────────────────────────────────────────────────────────────────────
# VERIFY
# ─────────────────────────────────────────────────────────────────────────────

$v2   = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2  = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb2  = $v2.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
$dh2  = $eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }
$dhq2 = $fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

Write-Host ''
Write-Host '=== ENTITY_Person_DH ==='
Write-Host 'ROOT_PAGE.nodes (default):          ' ($dh2.layout.default.ROOT_PAGE.nodes -join ', ')
Write-Host 'CARD_SELECT_FIRST nodes:            ' ($dh2.layout.default.CARD_SELECT_FIRST.nodes -join ', ')
Write-Host 'SELECT_FIRST_ROW1 nodes:            ' ($dh2.layout.default.SELECT_FIRST_ROW1.nodes -join ', ')
Write-Host 'SELECT_FIRST_ROW2 nodes:            ' ($dh2.layout.default.SELECT_FIRST_ROW2.nodes -join ', ')
Write-Host 'ImageIndicator initialValue:        ' $dh2.layout.default.ImageIndicator_Input.props.initialValue
Write-Host 'State initialValue:                 ' $dh2.layout.default.State_Input.props.initialValue
Write-Host 'PurposeCode fieldId:                ' $dh2.layout.default.PurposeCode_Input.props.fieldId
Write-Host 'Attention fieldId:                  ' $dh2.layout.default.Attention_Input.props.fieldId
Write-Host 'CARD_DH_OLN nodes:                  ' ($dh2.layout.default.CARD_DH_OLN.nodes -join ', ')
Write-Host 'CARD_DH_NAM nodes:                  ' ($dh2.layout.default.CARD_DH_NAM.nodes -join ', ')
Write-Host 'ROOT_PAGE.nodes (CAD_DISPATCH):     ' ($dh2.layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', ')
Write-Host ''
Write-Host '=== DriverHistoryQuery — KQName requirements.set ==='
Write-Host ($dhq2.combinations | Where-Object { $_.keyReference -eq 'KQName' }).requirements.set -join ', '
Write-Host ''
Write-Host '=== DriverHistoryQuery — KQOperatorLicenseNumber requirements.set ==='
Write-Host ($dhq2.combinations | Where-Object { $_.keyReference -eq 'KQOperatorLicenseNumber' }).requirements.set -join ', '
Write-Host ''
Write-Host '=== DriverHistoryQuery — Attention attribute ==='
$dhq2.attributes | Where-Object { $_.name -eq 'Attention' } | ConvertTo-Json -Depth 5
