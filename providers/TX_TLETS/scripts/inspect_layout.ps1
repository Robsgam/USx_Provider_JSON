# inspect_layout.ps1
# Quick layout inspection tool for TX_TLETS.json
# Dumps layout node structure for a given entity form to help debug rendering issues.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File scripts\inspect_layout.ps1
#   powershell.exe -ExecutionPolicy Bypass -File scripts\inspect_layout.ps1 -EntityLabel "Vehicle"
#   powershell.exe -ExecutionPolicy Bypass -File scripts\inspect_layout.ps1 -EntityLabel "Person" -LayoutVariant CAD_DISPATCH

param(
    [string]$EntityLabel   = "Vehicle",
    [string]$LayoutVariant = "default",
    [string]$JsonFile      = "$PSScriptRoot\..\TX_TLETS.json"
)

if (-not (Test-Path $JsonFile)) {
    Write-Host "ERROR: File not found: $JsonFile" -ForegroundColor Red
    exit 1
}

$data     = Get-Content $JsonFile -Raw | ConvertFrom-Json
$entities = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }

if (-not $entities) {
    Write-Host "ERROR: ENTITIES bundle not found in JSON." -ForegroundColor Red
    exit 1
}

$form = $entities.configurations | Where-Object { $_.label -eq $EntityLabel }

if (-not $form) {
    $available = $entities.configurations | ForEach-Object { $_.label }
    Write-Host "ERROR: Entity '$EntityLabel' not found." -ForegroundColor Red
    Write-Host "Available: $($available -join ', ')"
    exit 1
}

$layout = $form.layout.$LayoutVariant

if (-not $layout) {
    Write-Host "ERROR: Layout variant '$LayoutVariant' not found on '$EntityLabel'." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== $EntityLabel / $LayoutVariant ===" -ForegroundColor White
Write-Host ""

Write-Host "ROOT_PAGE.nodes (cards):" -ForegroundColor Cyan
$layout.ROOT_PAGE.nodes | ForEach-Object { Write-Host "  $_" }
Write-Host ""

foreach ($cardId in $layout.ROOT_PAGE.nodes) {
    $card = $layout.$cardId
    if (-not $card) { continue }
    $title  = if ($card.props.title)  { " -- '$($card.props.title)'" }  else { "" }
    $hidden = if ($card.hidden)       { " [HIDDEN]" }                   else { "" }
    Write-Host "$cardId$title$hidden" -ForegroundColor Yellow

    foreach ($rowId in $card.nodes) {
        $row = $layout.$rowId
        if (-not $row) { continue }
        $cols    = if ($row.props.templateColumns) { "cols=($($row.props.templateColumns -join ','))" } else { "" }
        $hidden2 = if ($row.hidden) { " [HIDDEN]" } else { "" }
        Write-Host "  $rowId  $cols$hidden2" -ForegroundColor DarkYellow

        foreach ($fieldId in $row.nodes) {
            $field = $layout.$fieldId
            if (-not $field) { continue }
            $fid     = $field.props.fieldId
            $lbl     = $field.props.label
            $typ     = $field.type.resolvedName
            $hiddenF = if ($field.hidden) { " [HIDDEN]" } else { "" }
            $extra   = @()
            if ($field.props.attributeTypeId)  { $extra += "attrId=$($field.props.attributeTypeId)" }
            if ($field.props.codeTypeCategory) { $extra += "cat=$($field.props.codeTypeCategory)" }
            if ($field.props.codeTypeSource)   { $extra += "src=$($field.props.codeTypeSource)" }
            if ($field.props.initialValue)     { $extra += "init='$($field.props.initialValue)'" }
            if ($field.props.maxLength)        { $extra += "max=$($field.props.maxLength)" }
            $extraStr = if ($extra.Count -gt 0) { "  [$($extra -join ', ')]" } else { "" }
            Write-Host "    $fieldId  $typ  fid='$fid'  lbl='$lbl'$hiddenF$extraStr"
        }
    }
    Write-Host ""
}

Write-Host "=== All node keys in layout ===" -ForegroundColor Cyan
($layout | Get-Member -MemberType NoteProperty).Name | Sort-Object
