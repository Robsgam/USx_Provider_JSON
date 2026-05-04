$az = Get-Content 'C:\Users\RobSgambellone\.local\bin\AZ_AZDPS\AZ_AZDPS.json' -Raw | ConvertFrom-Json

Write-Host "=== ALL QIDMs in AZ_AZDPS.json ==="
foreach ($bundle in $az.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
            Write-Host ("  bundle=" + $bundle.name + " name=" + $cfg.name + " targetEntity=" + $cfg.targetEntity + " query=" + $cfg.query + " autoSelect=" + $cfg.autoSelect)
        }
    }
}

Write-Host ""
Write-Host "=== AZ_AZDPS Person QIDM attributes (names only) ==="
$azBundle = $az.bundles | Where-Object { $_.name -eq 'AZ_AZDPS' }
$azPerson = $azBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Person' }
foreach ($attr in $azPerson.attributes) {
    Write-Host ("  name=" + $attr.name + " sourceField=" + ($attr.sourceField -join ','))
}
Write-Host ""
Write-Host "=== AZ_AZDPS Auth config provider ==="
$azAuth = $azBundle.configurations | Where-Object { $_.type -eq 'AUTHENTICATION' }
Write-Host ("  name=" + $azAuth.name + " provider=" + $azAuth.provider)

Write-Host ""
Write-Host "=== ENTITIES bundle order property ==="
$entities = $az.bundles | Where-Object { $_.name -eq 'ENTITIES' }
Write-Host ($entities.order | ConvertTo-Json -Depth 3 -Compress)
