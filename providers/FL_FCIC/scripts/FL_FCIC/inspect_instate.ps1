$json = Get-Content 'D:\JSON BACKUP\FL_FCIC.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$eb = $json.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$inState = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person_InState' }
$inState.layout.default | ConvertTo-Json -Depth 20
