$nopd = Get-Content 'C:\Users\RobSgambellone\.local\bin\Source jsons\NOPD.json' -Raw | ConvertFrom-Json
$az   = Get-Content 'C:\Users\RobSgambellone\.local\bin\AZ_AZDPS\AZ_AZDPS.json'    -Raw | ConvertFrom-Json

Write-Host "=== NOPD bundle names and top-level props ==="
foreach ($b in $nopd.bundles) {
    Write-Host ("  name=" + $b.name + " type=" + $b.type + " provider=" + $b.provider + " codeTypeProvider=" + $b.codeTypeProvider)
}

Write-Host ""
Write-Host "=== AZ bundle names and top-level props ==="
foreach ($b in $az.bundles) {
    Write-Host ("  name=" + $b.name + " type=" + $b.type + " provider=" + $b.provider + " codeTypeProvider=" + $b.codeTypeProvider)
}

Write-Host ""
Write-Host "=== NOPD ENTITIES bundle top-level properties ==="
$nopdEntities = $nopd.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$nopdEntities.PSObject.Properties | Where-Object { $_.Name -ne 'configurations' } | ForEach-Object {
    Write-Host ("  " + $_.Name + " = " + ($_.Value | ConvertTo-Json -Depth 3 -Compress))
}

Write-Host ""
Write-Host "=== NOPD LA_LEMS bundle top-level properties ==="
$nopdLa = $nopd.bundles | Where-Object { $_.name -eq 'LA_LEMS' }
$nopdLa.PSObject.Properties | Where-Object { $_.Name -ne 'configurations' } | ForEach-Object {
    Write-Host ("  " + $_.Name + " = " + ($_.Value | ConvertTo-Json -Depth 3 -Compress))
}

Write-Host ""
Write-Host "=== NOPD Person QIF top-level properties ==="
$nopdEntities2 = $nopd.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$nopdPersonQif = $nopdEntities2.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' -and $_.targetEntity -eq 'Person' }
foreach ($qif in @($nopdPersonQif)) {
    $qif.PSObject.Properties | Where-Object { $_.Name -ne 'layout' } | ForEach-Object {
        Write-Host ("  " + $_.Name + " = " + $_.Value)
    }
}
