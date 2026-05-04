# change10_instate_imgind.ps1
# Adds "Image Indicator Choice" card to ENTITY_Person_InState.
# The card sits above CARD_INSTATE_OLN and CARD_INSTATE_NAM on ROOT_PAGE,
# making the ImageIndicator field shared / always visible for both sub-cards.
#
# ImageIndicator field:
#   fieldId         = ImageIndicator
#   type            = FormSelect (dropdown)
#   codeTypeCategory = YES_NO_UNKNOWN (NIBRS: Y / N / Unknown)
#   codeTypeSource  = NIBRS
#   initialValue    = Y  (default per FDQ XML spec)
#
# FDQ XML reference: ImageIndicator is Alphabetic maxLength=1,
#   "Shall be Y or N. If blank, default value shall be N. Used on inquiry only."
#   Listed in requirements.any for both FDQName and FDQOperatorLicenseNumber.

$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json
$eb   = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$cfg  = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person_InState' }

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
# PATCH  — insert CARD_IMGIND before CARD_INSTATE_OLN in ROOT_PAGE.nodes
#          and add the three new nodes to the layout object
# ─────────────────────────────────────────────────────────────────────────────

function AddImgIndCard($layout) {
    # Insert CARD_IMGIND immediately before CARD_INSTATE_OLN
    $pageNodes = [System.Collections.Generic.List[string]]($layout.ROOT_PAGE.nodes)
    $idx = $pageNodes.IndexOf('CARD_INSTATE_OLN')
    $pageNodes.Insert($idx, 'CARD_IMGIND')
    $layout.ROOT_PAGE.nodes = $pageNodes.ToArray()

    # CARD_IMGIND — titled card containing one row
    $layout | Add-Member -NotePropertyName 'CARD_IMGIND' -NotePropertyValue (
        N 'Card' 'Card' @{ title = 'Image Indicator Choice' } $true $false @('IMGIND_ROW1') 'ROOT_PAGE'
    ) -Force

    # IMGIND_ROW1 — single column, half-width (6/12)
    $layout | Add-Member -NotePropertyName 'IMGIND_ROW1' -NotePropertyValue (
        N 'Row' 'Row' @{ templateColumns = @('6') } $true $false @('ImageIndicator_Input') 'CARD_IMGIND'
    ) -Force

    # ImageIndicator_Input — Y/N/Unknown dropdown, default Y
    $layout | Add-Member -NotePropertyName 'ImageIndicator_Input' -NotePropertyValue (
        N 'FormSelect' 'Select' ([ordered]@{
            fieldId          = 'ImageIndicator'
            label            = 'Image Indicator'
            initialValue     = 'Y'
            codeTypeSource   = 'NIBRS'
            codeTypeCategory = 'YES_NO_UNKNOWN'
        }) $false $false @() 'IMGIND_ROW1'
    ) -Force
}

# Apply to all three layout variants
AddImgIndCard $cfg.layout.default
AddImgIndCard $cfg.layout.CAD_DISPATCH
AddImgIndCard $cfg.layout.FIRST_RESPONDER

# ─────────────────────────────────────────────────────────────────────────────
# SAVE
# ─────────────────────────────────────────────────────────────────────────────

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
Write-Host 'CARD_IMGIND title:              ' $inState2.layout.default.CARD_IMGIND.props.title
Write-Host 'CARD_IMGIND nodes:              ' ($inState2.layout.default.CARD_IMGIND.nodes -join ', ')
Write-Host 'ImageIndicator fieldId:         ' $inState2.layout.default.ImageIndicator_Input.props.fieldId
Write-Host 'ImageIndicator initialValue:    ' $inState2.layout.default.ImageIndicator_Input.props.initialValue
Write-Host 'ImageIndicator codeTypeCategory:' $inState2.layout.default.ImageIndicator_Input.props.codeTypeCategory
Write-Host ''
Write-Host 'ROOT_PAGE.nodes (CAD_DISPATCH): ' ($inState2.layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', ')
Write-Host ''
Write-Host 'All default nodes:              ' ($inState2.layout.default.PSObject.Properties.Name -join ', ')
