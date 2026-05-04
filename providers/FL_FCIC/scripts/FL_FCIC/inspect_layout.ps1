# inspect_layout.ps1
# Quick inspection of FL_FCIC_BASE.json layout nodes for debugging.
# Run: powershell.exe -ExecutionPolicy Bypass -File inspect_layout.ps1

$data = Get-Content 'C:\Users\Gordon Hallof\FL_FCIC\FL_FCIC_BASE.json' -Raw | ConvertFrom-Json
$entities = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$veh = $entities.configurations | Where-Object { $_.label -eq 'Vehicle' }
$layout = $veh.layout.default

Write-Host "=== ROOT_PAGE.nodes ==="
$layout.ROOT_PAGE.nodes | ConvertTo-Json

Write-Host "=== ROOT_CARD ==="
$layout.ROOT_CARD | ConvertTo-Json -Depth 3

Write-Host "=== ROW_1 ==="
$layout.ROW_1 | ConvertTo-Json -Depth 3

Write-Host "=== LicensePlateNumber_Input ==="
$layout.LicensePlateNumber_Input | ConvertTo-Json -Depth 3

Write-Host ""
Write-Host "=== All node keys in Vehicle default layout ==="
($layout | Get-Member -MemberType NoteProperty).Name

Write-Host ""
Write-Host "=== FL_FCIC bundle configuration names ==="
$fcic = $data.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
$fcic.configurations | ForEach-Object { Write-Host "  $($_.type.PadRight(35)) $($_.name)" }
