# change11_oos_select_first.ps1
# Adds "Select First" shared card to ENTITY_Person_OOS and consolidates State fieldId.
#
# ENTITY FORM changes (all 3 layout variants):
#   NEW CARD_SELECT_FIRST  -- positioned above CARD_OOS_OLN and CARD_OOS_NAM
#     SELECT_FIRST_ROW1 [6,6]:
#       ImageIndicator_Input  (FormSelect, YES_NO_UNKNOWN/NIBRS, initialValue=Y)
#       State_Input           (FormSelect, RegistrationState, STATE, no default)
#
#   CARD_OOS_OLN  -- State (RegistrationState) removed
#     OOS_OLN_ROW1 now [12]: OLN_OOS_Input only
#
#   CARD_OOS_NAM  -- RegistrationStateOOS removed
#     OOS_NAM_ROW3 (State_Name_Input) removed entirely
#
# MAPPING changes:
#   FL_FCIC_DriverLicenseQuery  DQName:           RegistrationStateOOS → RegistrationState in requirements.set
#   FL_FCIC_DriverHistoryQuery  KQNameOOS:        RegistrationStateOOS → RegistrationState in requirements.set
#
# Both DL and DH query attributes already map RegistrationState → targetField='State',
# so the transmitted message is identical — only the triggering fieldId changes.

$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$eb  = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb  = $data.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
$cfg = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }
$dlq = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
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

# ─────────────────────────────────────────────────────────────────────────────
# ENTITY FORM PATCH  (applied to each layout variant)
# ─────────────────────────────────────────────────────────────────────────────

function PatchOOSLayout($layout) {

    # 1. Insert CARD_SELECT_FIRST before CARD_OOS_OLN in ROOT_PAGE.nodes
    $pageNodes = [System.Collections.Generic.List[string]]($layout.ROOT_PAGE.nodes)
    $idx = $pageNodes.IndexOf('CARD_OOS_OLN')
    $pageNodes.Insert($idx, 'CARD_SELECT_FIRST')
    $layout.ROOT_PAGE.nodes = $pageNodes.ToArray()

    # Add CARD_SELECT_FIRST → SELECT_FIRST_ROW1 → ImageIndicator_Input + State_Input
    $layout | Add-Member -NotePropertyName 'CARD_SELECT_FIRST' -NotePropertyValue (
        N 'Card' 'Card' @{ title = 'Select First' } $true $false @('SELECT_FIRST_ROW1') 'ROOT_PAGE'
    ) -Force
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
        N 'FormSelect' 'Select' ([ordered]@{
            fieldId       = 'RegistrationState'
            label         = 'State'
            attributeTypeId = 'STATE'
        }) $false $false @() 'SELECT_FIRST_ROW1'
    ) -Force

    # 2. CARD_OOS_OLN — remove State_DL_Input; OLN takes full width
    $layout.OOS_OLN_ROW1.nodes = @('OLN_OOS_Input')
    $layout.OOS_OLN_ROW1.props.templateColumns = @('12')
    $layout.PSObject.Properties.Remove('State_DL_Input')

    # 3. CARD_OOS_NAM — remove OOS_NAM_ROW3 (RegistrationStateOOS)
    $layout.CARD_OOS_NAM.nodes = @('OOS_NAM_ROW1','OOS_NAM_ROW2')
    $layout.PSObject.Properties.Remove('OOS_NAM_ROW3')
    $layout.PSObject.Properties.Remove('State_Name_Input')
}

PatchOOSLayout $cfg.layout.default
PatchOOSLayout $cfg.layout.CAD_DISPATCH
PatchOOSLayout $cfg.layout.FIRST_RESPONDER

# ─────────────────────────────────────────────────────────────────────────────
# MAPPING PATCH 1 — DriverLicenseQuery DQName
# ─────────────────────────────────────────────────────────────────────────────

$dqName = $dlq.combinations | Where-Object { $_.keyReference -eq 'DQName' }
$dqName.requirements.set = $dqName.requirements.set |
    ForEach-Object { if ($_ -eq 'RegistrationStateOOS') { 'RegistrationState' } else { $_ } }

# ─────────────────────────────────────────────────────────────────────────────
# MAPPING PATCH 2 — DriverHistoryQuery KQNameOOS
# ─────────────────────────────────────────────────────────────────────────────

$kqNameOOS = $dhq.combinations | Where-Object { $_.keyReference -eq 'KQNameOOS' }
$kqNameOOS.requirements.set = $kqNameOOS.requirements.set |
    ForEach-Object { if ($_ -eq 'RegistrationStateOOS') { 'RegistrationState' } else { $_ } }

# ─────────────────────────────────────────────────────────────────────────────
# SAVE
# ─────────────────────────────────────────────────────────────────────────────

$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# ─────────────────────────────────────────────────────────────────────────────
# VERIFY
# ─────────────────────────────────────────────────────────────────────────────

$v2    = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2   = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb2   = $v2.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
$oos2  = $eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }
$dlq2  = $fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
$dhq2  = $fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

Write-Host ''
Write-Host '=== ENTITY_Person_OOS ==='
Write-Host 'ROOT_PAGE.nodes (default):           ' ($oos2.layout.default.ROOT_PAGE.nodes -join ', ')
Write-Host 'CARD_SELECT_FIRST title:             ' $oos2.layout.default.CARD_SELECT_FIRST.props.title
Write-Host 'SELECT_FIRST_ROW1 nodes:             ' ($oos2.layout.default.SELECT_FIRST_ROW1.nodes -join ', ')
Write-Host 'ImageIndicator initialValue:         ' $oos2.layout.default.ImageIndicator_Input.props.initialValue
Write-Host 'State_Input fieldId:                 ' $oos2.layout.default.State_Input.props.fieldId
Write-Host 'CARD_OOS_OLN OOS_OLN_ROW1 nodes:    ' ($oos2.layout.default.OOS_OLN_ROW1.nodes -join ', ')
Write-Host 'CARD_OOS_OLN OOS_OLN_ROW1 cols:     ' ($oos2.layout.default.OOS_OLN_ROW1.props.templateColumns -join ', ')
Write-Host 'CARD_OOS_NAM nodes:                  ' ($oos2.layout.default.CARD_OOS_NAM.nodes -join ', ')
Write-Host 'State_DL_Input removed:              ' (-not $oos2.layout.default.PSObject.Properties['State_DL_Input'])
Write-Host 'State_Name_Input removed:            ' (-not $oos2.layout.default.PSObject.Properties['State_Name_Input'])
Write-Host 'ROOT_PAGE.nodes (CAD_DISPATCH):      ' ($oos2.layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', ')
Write-Host ''
Write-Host '=== MAPPING — DQName requirements.set ==='
$dqN2 = $dlq2.combinations | Where-Object { $_.keyReference -eq 'DQName' }
Write-Host ($dqN2.requirements.set -join ', ')
Write-Host ''
Write-Host '=== MAPPING — KQNameOOS requirements.set ==='
$kqN2 = $dhq2.combinations | Where-Object { $_.keyReference -eq 'KQNameOOS' }
Write-Host ($kqN2.requirements.set -join ', ')
