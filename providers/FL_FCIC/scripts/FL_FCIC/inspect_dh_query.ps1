$json = Get-Content 'D:\JSON BACKUP\FL_FCIC.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$fb = $json.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
$dhq = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }
$dhq | ConvertTo-Json -Depth 10
