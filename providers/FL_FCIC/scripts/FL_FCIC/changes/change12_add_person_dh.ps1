# change12_add_person_dh.ps1
# Adds ENTITY_Person_DH (Person (Driver History)) to the ENTITIES bundle.
# Inserted after ENTITY_Person_OOS, before ENTITY_Vehicle.
# targetEntity = 'Person' (same as InState and OOS — no registration needed).
#
# Covers FL in-state Driver History combinations:
#   KQOperatorLicenseNumber  -- OLN + AttentionDL + PurposeCodeDL
#   KQName                   -- Name/DOB/Sex + AttentionName + PurposeCodeName
#
# Layout uses FL_FCIC native sub-card pattern (ROOT_PAGE → titled Cards).
#
# CARD_DH_OLN  "DH by OLN"
#   DH_OLN_ROW1 [12]:   OperatorLicenseNumber
#   DH_OLN_ROW2 [6,6]:  AttentionDL | PurposeCodeDL
#
# CARD_DH_NAM  "DH by NAM"
#   DH_NAM_ROW1 [6,6]:      NameFirst | NameLast
#   DH_NAM_ROW2 [3,3,3,3]:  NameMiddle | NameSuffix | BirthDate | SexCode
#   DH_NAM_ROW3 [6,6]:      AttentionName | PurposeCodeName

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
# BUILD LAYOUT
# ─────────────────────────────────────────────────────────────────────────────

function BuildDHLayout {
    $l = [ordered]@{}

    $l['ROOT']      = N 'Root' 'Root' @{} $true  $false @('FORM_ROOT') $null
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false @('CARD_DH_OLN','CARD_DH_NAM') 'FORM_ROOT'

    # ── Sub-card 1: DH by OLN (KQOperatorLicenseNumber) ─────────────────────
    $l['CARD_DH_OLN']         = N 'Card' 'Card' @{ title = 'DH by OLN' } $true $false @('DH_OLN_ROW1','DH_OLN_ROW2') 'ROOT_PAGE'
    $l['DH_OLN_ROW1']         = N 'Row'  'Row'  @{ templateColumns = @('12') } $true $false @('OLN_Input') 'CARD_DH_OLN'
    $l['OLN_Input']           = Inp 'OperatorLicenseNumber' 'License Number' '20' 'DH_OLN_ROW1'
    $l['DH_OLN_ROW2']         = N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('AttentionDL_Input','PurposeCodeDL_Input') 'CARD_DH_OLN'
    $l['AttentionDL_Input']   = Inp 'AttentionDL'   'Attention'     '30' 'DH_OLN_ROW2'
    $l['PurposeCodeDL_Input'] = Inp 'PurposeCodeDL' 'Purpose Code'  '1'  'DH_OLN_ROW2'

    # ── Sub-card 2: DH by NAM (KQName) ──────────────────────────────────────
    $l['CARD_DH_NAM']           = N 'Card' 'Card' @{ title = 'DH by NAM' } $true $false @('DH_NAM_ROW1','DH_NAM_ROW2','DH_NAM_ROW3') 'ROOT_PAGE'
    $l['DH_NAM_ROW1']           = N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('NameFirst_Input','NameLast_Input') 'CARD_DH_NAM'
    $l['NameFirst_Input']       = Inp 'NameFirst' 'First Name'  '30' 'DH_NAM_ROW1'
    $l['NameLast_Input']        = Inp 'NameLast'  'Last Name'   '30' 'DH_NAM_ROW1'
    $l['DH_NAM_ROW2']           = N 'Row'  'Row'  @{ templateColumns = @('3','3','3','3') } $true $false @('NameMiddle_Input','NameSuffix_Input','BirthDate_Input','SexCode_Input') 'CARD_DH_NAM'
    $l['NameMiddle_Input']      = Inp 'NameMiddle' 'Middle Name' '30' 'DH_NAM_ROW2'
    $l['NameSuffix_Input']      = Inp 'NameSuffix' 'Suffix'      '4'  'DH_NAM_ROW2'
    $l['BirthDate_Input']       = Dt  'BirthDate' 'Date of Birth' 'DH_NAM_ROW2'
    $l['SexCode_Input']         = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX' } 'DH_NAM_ROW2'
    $l['DH_NAM_ROW3']           = N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('AttentionName_Input','PurposeCodeName_Input') 'CARD_DH_NAM'
    $l['AttentionName_Input']   = Inp 'AttentionName'   'Attention'    '30' 'DH_NAM_ROW3'
    $l['PurposeCodeName_Input'] = Inp 'PurposeCodeName' 'Purpose Code' '1'  'DH_NAM_ROW3'

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

$def = BuildDHLayout
$cad = AddCadNodes $def
$fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json

$personFormDH = [PSCustomObject]@{
    name         = 'ENTITY_Person_DH'
    type         = 'QUERYINPUTFORM'
    description  = 'Person entity form -- FL driver history (KQName + KQOperatorLicenseNumber)'
    label        = 'Person (Driver History)'
    targetEntity = 'Person'
    layout       = [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# INSERT after ENTITY_Person_OOS
# ─────────────────────────────────────────────────────────────────────────────

$newCfgs = [System.Collections.Generic.List[object]]::new()
foreach ($c in $eb.configurations) {
    $newCfgs.Add($c)
    if ($c.name -eq 'ENTITY_Person_OOS') { $newCfgs.Add($personFormDH) }
}
$eb.configurations = $newCfgs.ToArray()

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
$dh2  = $eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }

Write-Host ''
Write-Host 'ENTITIES configs:' ($eb2.configurations | ForEach-Object { $_.name } | ForEach-Object { "  $_" })
Write-Host ''
Write-Host 'ENTITY_Person_DH label:                 ' $dh2.label
Write-Host 'ENTITY_Person_DH targetEntity:          ' $dh2.targetEntity
Write-Host 'ROOT_PAGE.nodes (default):              ' ($dh2.layout.default.ROOT_PAGE.nodes -join ', ')
Write-Host 'CARD_DH_OLN title:                      ' $dh2.layout.default.CARD_DH_OLN.props.title
Write-Host 'CARD_DH_OLN nodes:                      ' ($dh2.layout.default.CARD_DH_OLN.nodes -join ', ')
Write-Host 'CARD_DH_NAM title:                      ' $dh2.layout.default.CARD_DH_NAM.props.title
Write-Host 'CARD_DH_NAM nodes:                      ' ($dh2.layout.default.CARD_DH_NAM.nodes -join ', ')
Write-Host 'ROOT_PAGE.nodes (CAD_DISPATCH):         ' ($dh2.layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', ')
Write-Host ''
Write-Host 'All default nodes:' ($dh2.layout.default.PSObject.Properties.Name -join ', ')
