$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$oos = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_OOS' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $oos.layout.$variant.CARD_OOS_OLN.props.title = 'Either...OOS by OLN'
    $oos.layout.$variant.CARD_OOS_NAM.props.title = 'Or...OOS by NAM\DOB'
    Write-Host "${variant}: titles updated"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
