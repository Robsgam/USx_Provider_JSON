$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$dh = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $dh.layout.$variant.CARD_DH_OLN.props.title = 'Either...DRIVER HISTORY by OLN'
    $dh.layout.$variant.CARD_DH_NAM.props.title = 'Or...DRIVER HISTORY by NAM\DOB'
    Write-Host "${variant}: titles updated"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
