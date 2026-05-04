# change9_oos_subcards.ps1
# Rebuilds ENTITY_Person_OOS with two titled sub-cards (FL_FCIC native pattern).
# Sub-cards go directly under ROOT_PAGE, matching Change 8 / Vehicle/Firearm/etc.
#
# CARD_OOS_OLN  -- "OOS by OLN"
#   Fields: OperatorLicenseNumberOOS | RegistrationState (State, OLN search)
#
# CARD_OOS_NAM  -- "OOS by NAM\DOB"
#   Fields: NameFirstOOS | NameLastOOS
#           NameMiddleOOS | NameSuffixOOS | BirthDateOOS | SexCodeOOS
#           RegistrationStateOOS (State, Name search, required)
#
# Removed: AttentionOOS, PurposeCodeOOS, Attention, PurposeCode (ROW_5 and ROW_6)

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
# BUILD LAYOUT  (FL_FCIC pattern: ROOT_PAGE → [CARD_OOS_OLN, CARD_OOS_NAM])
# ─────────────────────────────────────────────────────────────────────────────

function BuildOOSLayout {
    $l = [ordered]@{}

    $l['ROOT']      = N 'Root' 'Root' @{} $true  $false @('FORM_ROOT') $null
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false @('CARD_OOS_OLN','CARD_OOS_NAM') 'FORM_ROOT'

    # ── Sub-card 1: OOS by OLN ───────────────────────────────────────────────
    $l['CARD_OOS_OLN']     = N 'Card' 'Card' @{ title = 'OOS by OLN' } $true $false @('OOS_OLN_ROW1') 'ROOT_PAGE'
    $l['OOS_OLN_ROW1']     = N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('OLN_OOS_Input','State_DL_Input') 'CARD_OOS_OLN'
    $l['OLN_OOS_Input']    = Inp 'OperatorLicenseNumberOOS' 'License Number' '20' 'OOS_OLN_ROW1'
    $l['State_DL_Input']   = Sel 'RegistrationState' 'State (OLN search)' @{ attributeTypeId = 'STATE' } 'OOS_OLN_ROW1'

    # ── Sub-card 2: OOS by NAM\DOB ───────────────────────────────────────────
    $l['CARD_OOS_NAM']      = N 'Card' 'Card' @{ title = 'OOS by NAM\DOB' } $true $false @('OOS_NAM_ROW1','OOS_NAM_ROW2','OOS_NAM_ROW3') 'ROOT_PAGE'
    $l['OOS_NAM_ROW1']      = N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('NameFirst_OOS_Input','NameLast_OOS_Input') 'CARD_OOS_NAM'
    $l['NameFirst_OOS_Input'] = Inp 'NameFirstOOS' 'First Name' '30' 'OOS_NAM_ROW1'
    $l['NameLast_OOS_Input']  = Inp 'NameLastOOS'  'Last Name'  '30' 'OOS_NAM_ROW1'
    $l['OOS_NAM_ROW2']      = N 'Row'  'Row'  @{ templateColumns = @('3','3','3','3') } $true $false @('NameMiddle_OOS_Input','NameSuffix_OOS_Input','BirthDate_OOS_Input','SexCode_OOS_Input') 'CARD_OOS_NAM'
    $l['NameMiddle_OOS_Input'] = Inp 'NameMiddleOOS' 'Middle Name' '30' 'OOS_NAM_ROW2'
    $l['NameSuffix_OOS_Input'] = Inp 'NameSuffixOOS' 'Suffix'      '4'  'OOS_NAM_ROW2'
    $l['BirthDate_OOS_Input']  = Dt  'BirthDateOOS' 'Date of Birth' 'OOS_NAM_ROW2'
    $l['SexCode_OOS_Input']    = Sel 'SexCodeOOS' 'Sex' @{ attributeTypeId = 'SEX' } 'OOS_NAM_ROW2'
    $l['OOS_NAM_ROW3']         = N 'Row' 'Row' @{ templateColumns = @('12') } $true $false @('State_Name_Input') 'CARD_OOS_NAM'
    $l['State_Name_Input']     = Sel 'RegistrationStateOOS' 'State (Name search, required)' @{ attributeTypeId = 'STATE' } 'OOS_NAM_ROW3'

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

$def = BuildOOSLayout
$cad = AddCadNodes $def
$fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json

$newLayout = [PSCustomObject]@{
    default         = $def
    CAD_DISPATCH    = $cad
    FIRST_RESPONDER = $fr
}

# ─────────────────────────────────────────────────────────────────────────────
# PATCH ENTITY_Person_OOS
# ─────────────────────────────────────────────────────────────────────────────

$cfg = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }
$cfg.layout = $newLayout

$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# ─────────────────────────────────────────────────────────────────────────────
# VERIFY
# ─────────────────────────────────────────────────────────────────────────────

$v2    = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2   = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$oos2  = $eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }

Write-Host ''
Write-Host 'ROOT_PAGE.nodes (default):      ' ($oos2.layout.default.ROOT_PAGE.nodes -join ', ')
Write-Host 'CARD_OOS_OLN title:             ' $oos2.layout.default.CARD_OOS_OLN.props.title
Write-Host 'CARD_OOS_OLN nodes:             ' ($oos2.layout.default.CARD_OOS_OLN.nodes -join ', ')
Write-Host 'CARD_OOS_NAM title:             ' $oos2.layout.default.CARD_OOS_NAM.props.title
Write-Host 'CARD_OOS_NAM nodes:             ' ($oos2.layout.default.CARD_OOS_NAM.nodes -join ', ')
Write-Host ''
Write-Host 'ROOT_PAGE.nodes (CAD_DISPATCH): ' ($oos2.layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', ')
Write-Host ''
Write-Host 'All default nodes:              ' ($oos2.layout.default.PSObject.Properties.Name -join ', ')
