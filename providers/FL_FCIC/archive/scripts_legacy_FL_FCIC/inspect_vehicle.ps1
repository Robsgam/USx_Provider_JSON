$json = Get-Content 'D:\JSON BACKUP\FL_FCIC.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$eb = $json.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$v = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Vehicle' }
$v.layout.default | ConvertTo-Json -Depth 20
