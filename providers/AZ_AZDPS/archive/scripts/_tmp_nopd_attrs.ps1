$nopd = Get-Content 'C:\Users\RobSgambellone\.local\bin\Source jsons\NOPD.json' -Raw | ConvertFrom-Json
$la = $nopd.bundles | Where-Object { $_.name -eq 'LA_LEMS' }
$personQidms = @($la.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Person' })
$q = $personQidms[0]
Write-Host ("=== NOPD " + $q.name + " ALL attributes ===")
foreach ($attr in $q.attributes) {
    Write-Host ("  name=" + $attr.name + " size=" + $attr.size + " sourceField=" + ($attr.sourceField -join ',') + " targetField=" + $attr.targetField + " rule=" + $attr.rule.function)
}
