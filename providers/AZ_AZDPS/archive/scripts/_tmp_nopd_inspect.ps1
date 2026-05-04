$nopd = Get-Content 'C:\Users\RobSgambellone\.local\bin\Source jsons\NOPD.json' -Raw | ConvertFrom-Json
$entities = $nopd.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$personQifs = @($entities.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' -and $_.targetEntity -eq 'Person' })
Write-Host ("Person QIF count: " + $personQifs.Count)
foreach ($pq in $personQifs) {
    Write-Host ("=== " + $pq.name + " provider=" + $pq.provider + " ===")
    $layout = $pq.layout.default
    foreach ($prop in $layout.PSObject.Properties) {
        $node = $prop.Value
        if ($node -and $node.props -and $node.props.fieldId) {
            Write-Host ("  " + $prop.Name + " fid=" + $node.props.fieldId + " hidden=" + $node.hidden + " type=" + $node.type.resolvedName)
            Write-Host ("    props: " + ($node.props | ConvertTo-Json -Depth 2 -Compress))
        }
    }
}

Write-Host ""
Write-Host "=== NOPD LA_LEMS Person QIDM State attribute ==="
$la = $nopd.bundles | Where-Object { $_.name -eq 'LA_LEMS' }
$personQidms = @($la.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Person' })
foreach ($q in $personQidms) {
    Write-Host ("QIDM: " + $q.name)
    foreach ($attr in $q.attributes) {
        if ($attr.name -match 'State|Registration|Attention') {
            Write-Host ("  attr: name=" + $attr.name + " sourceField=" + ($attr.sourceField -join ',') + " targetField=" + $attr.targetField)
        }
    }
}
