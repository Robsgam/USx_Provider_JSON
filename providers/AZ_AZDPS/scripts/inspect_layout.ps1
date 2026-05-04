$data = Get-Content "$PSScriptRoot\..\AZ_AZDPS_BASE.json" -Raw | ConvertFrom-Json
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
Write-Host "=== All node keys in default layout ==="
($layout | Get-Member -MemberType NoteProperty).Name
