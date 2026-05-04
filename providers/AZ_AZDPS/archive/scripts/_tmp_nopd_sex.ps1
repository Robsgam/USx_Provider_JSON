$nopd = Get-Content 'C:\Users\RobSgambellone\.local\bin\Source jsons\NOPD.json' -Raw | ConvertFrom-Json

$entities = $nopd.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$personQif = $entities.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' -and $_.targetEntity -eq 'Person' }

Write-Host "=== NOPD ENTITIES Person QIF -- all nodes with Sex/Race/sex/race in any prop ==="
$layout = $personQif.layout.default
foreach ($key in $layout.PSObject.Properties.Name) {
    $node = $layout.$key
    if ($node.props) {
        $p = $node.props
        $pJson = $p | ConvertTo-Json -Compress
        if ($pJson -match 'ex|ace') {
            Write-Host ("  node=" + $key + " " + $pJson)
        }
    }
}

Write-Host ""
Write-Host "=== NOPD ENTITIES Person QIF -- ALL node props ==="
foreach ($key in $layout.PSObject.Properties.Name) {
    $node = $layout.$key
    if ($node.props) {
        $p = $node.props
        if ($p.fieldId) {
            Write-Host ("  node=" + $key + " fieldId=" + $p.fieldId + " attrTypeId=" + $p.attributeTypeId + " codeTypeCat=" + $p.codeTypeCategory + " codeTypeSrc=" + $p.codeTypeSource + " initialValue=" + $p.initialValue + " hidden=" + $node.hidden)
        }
    }
}
