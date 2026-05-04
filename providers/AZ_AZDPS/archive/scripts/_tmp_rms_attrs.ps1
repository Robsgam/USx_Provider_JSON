$az = Get-Content 'C:\Users\RobSgambellone\.local\bin\AZ_AZDPS\AZ_AZDPS.json' -Raw | ConvertFrom-Json
$rms = $az.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsPersonQidm = $rms.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Person' }

Write-Host "=== RMS Person QIDM ALL attributes ==="
foreach ($attr in $rmsPersonQidm.attributes) {
    $attrJson = $attr | ConvertTo-Json -Compress
    Write-Host ("  " + $attrJson)
}
Write-Host ""
Write-Host "=== RMS Person QIDM combinations ==="
$rmsPersonQidm.combinations | ConvertTo-Json -Depth 5
