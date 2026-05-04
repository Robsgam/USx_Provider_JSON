# change8_instate_subcards.ps1
# Rebuilds ENTITY_Person_InState with two titled sub-cards (FL_FCIC native pattern).
# Sub-cards go directly under ROOT_PAGE (no ROOT_CARD wrapper), matching Vehicle/Firearm/etc.
#
# CARD_INSTATE_OLN  -- "IN State by OLN"
#   Fields: OperatorLicenseNumber
#
# CARD_INSTATE_NAM  -- "IN State by NAM\DOB"
#   Fields: NameFirst, NameLast, NameMiddle, NameSuffix, BirthDate, SexCode
#
# Removed: RegistrationState, AttentionName, PurposeCodeName, AttentionDL, PurposeCodeDL
# (Driver History for In State is not possible from this form)

$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json
$eb   = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
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

# ─────────────────────────────────────────────────────────────────────────────
# BUILD LAYOUT  (FL_FCIC pattern: ROOT_PAGE → [CARD_1, CARD_2, ...])
# ─────────────────────────────────────────────────────────────────────────────

function BuildInStateLayout {
    $l = [ordered]@{}

    $l['ROOT']      = N 'Root' 'Root' @{} $true  $false @('FORM_ROOT') $null
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false @('CARD_INSTATE_OLN','CARD_INSTATE_NAM') 'FORM_ROOT'

    # ── Sub-card 1: IN State by OLN ─────────────────────────────────────────
    $l['CARD_INSTATE_OLN'] = N 'Card' 'Card' @{ title = 'IN State by OLN' } $true $false @('INSTATE_OLN_ROW1') 'ROOT_PAGE'
    $l['INSTATE_OLN_ROW1'] = N 'Row'  'Row'  @{ templateColumns = @('12') } $true $false @('OLN_Input') 'CARD_INSTATE_OLN'
    $l['OLN_Input']        = Inp 'OperatorLicenseNumber' 'License Number' '20' 'INSTATE_OLN_ROW1'

    # ── Sub-card 2: IN State by NAM\DOB ─────────────────────────────────────
    $l['CARD_INSTATE_NAM'] = N 'Card' 'Card' @{ title = 'IN State by NAM\DOB' } $true $false @('INSTATE_NAM_ROW1','INSTATE_NAM_ROW2') 'ROOT_PAGE'
    $l['INSTATE_NAM_ROW1'] = N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('NameFirst_Input','NameLast_Input') 'CARD_INSTATE_NAM'
    $l['NameFirst_Input']  = Inp 'NameFirst' 'First Name'  '30' 'INSTATE_NAM_ROW1'
    $l['NameLast_Input']   = Inp 'NameLast'  'Last Name'   '30' 'INSTATE_NAM_ROW1'
    $l['INSTATE_NAM_ROW2'] = N 'Row'  'Row'  @{ templateColumns = @('3','3','3','3') } $true $false @('NameMiddle_Input','NameSuffix_Input','BirthDate_Input','SexCode_Input') 'CARD_INSTATE_NAM'
    $l['NameMiddle_Input'] = Inp 'NameMiddle' 'Middle Name' '30' 'INSTATE_NAM_ROW2'
    $l['NameSuffix_Input'] = Inp 'NameSuffix' 'Suffix'      '4'  'INSTATE_NAM_ROW2'
    $l['BirthDate_Input']  = Dt  'BirthDate' 'Date of Birth' 'INSTATE_NAM_ROW2'
    $l['SexCode_Input']    = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX' } 'INSTATE_NAM_ROW2'

    [PSCustomObject]$l
}

function AddCadNodes($layout) {
    $clone     = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
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

$def = BuildInStateLayout
$cad = AddCadNodes $def
$fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json

$newLayout = [PSCustomObject]@{
    default         = $def
    CAD_DISPATCH    = $cad
    FIRST_RESPONDER = $fr
}

# ─────────────────────────────────────────────────────────────────────────────
# PATCH ENTITY_Person_InState
# ─────────────────────────────────────────────────────────────────────────────

$cfg = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person_InState' }
$cfg.layout = $newLayout

$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# ─────────────────────────────────────────────────────────────────────────────
# VERIFY
# ─────────────────────────────────────────────────────────────────────────────

$v2       = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2      = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$inState2 = $eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_InState' }

Write-Host ''
Write-Host 'ROOT_PAGE.nodes (default):      ' ($inState2.layout.default.ROOT_PAGE.nodes -join ', ')
Write-Host 'CARD_INSTATE_OLN title:         ' $inState2.layout.default.CARD_INSTATE_OLN.props.title
Write-Host 'CARD_INSTATE_OLN nodes:         ' ($inState2.layout.default.CARD_INSTATE_OLN.nodes -join ', ')
Write-Host 'CARD_INSTATE_NAM title:         ' $inState2.layout.default.CARD_INSTATE_NAM.props.title
Write-Host 'CARD_INSTATE_NAM nodes:         ' ($inState2.layout.default.CARD_INSTATE_NAM.nodes -join ', ')
Write-Host ''
Write-Host 'ROOT_PAGE.nodes (CAD_DISPATCH): ' ($inState2.layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', ')
Write-Host ''
Write-Host 'All default nodes:              ' ($inState2.layout.default.PSObject.Properties.Name -join ', ')
