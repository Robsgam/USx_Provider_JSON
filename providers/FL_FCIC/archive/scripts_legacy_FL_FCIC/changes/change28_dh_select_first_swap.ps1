$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$dh = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $dh.layout.$variant.SELECT_FIRST_ROW1.nodes = @('State_Input','ImageIndicator_Input')
    Write-Host "${variant}: SELECT_FIRST_ROW1 -> State_Input | ImageIndicator_Input"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
