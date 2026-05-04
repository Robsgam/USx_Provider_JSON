$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$oos = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $row = $oos.layout.$variant.SELECT_FIRST_ROW1
    $row.nodes = @('State_Input','ImageIndicator_Input')
    $oos.layout.$variant.State_Input.parent       = 'SELECT_FIRST_ROW1'
    $oos.layout.$variant.ImageIndicator_Input.parent = 'SELECT_FIRST_ROW1'
    Write-Host "${variant}: SELECT_FIRST_ROW1 -> State_Input | ImageIndicator_Input"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
