$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$oos = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Vehicle_OOS' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $oos.layout.$variant.CARD_OUTSTATE_PLATE.props.title = 'Either...OUT OF STATE by PLATE'
    $oos.layout.$variant.CARD_OUTSTATE_VIN.props.title   = 'Or...OUT OF STATE by VIN'
    Write-Host "${variant}: titles updated"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
