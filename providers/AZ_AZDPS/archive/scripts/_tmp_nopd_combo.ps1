$nopd = Get-Content 'C:\Users\RobSgambellone\.local\bin\Source jsons\NOPD.json' -Raw | ConvertFrom-Json
$la = $nopd.bundles | Where-Object { $_.name -eq 'LA_LEMS' }
$personQidms = @($la.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Person' })
$q = $personQidms[0]
Write-Host ("=== NOPD " + $q.name + " combinations (raw JSON) ===")
$q.combinations | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "=== AZ QIDM Person combinations (raw JSON) ==="
$az = Get-Content 'C:\Users\RobSgambellone\.local\bin\AZ_AZDPS\AZ_AZDPS.json' -Raw | ConvertFrom-Json
$azBundle = $az.bundles | Where-Object { $_.name -eq 'AZ_AZDPS' }
$azPerson = $azBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Person' }
$azPerson.combinations | ConvertTo-Json -Depth 10
