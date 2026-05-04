$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$inState = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Vehicle_InState' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $inState.layout.$variant.CARD_INSTATE_PLATE.props.title = 'Either...IN STATE by PLATE'
    $inState.layout.$variant.CARD_INSTATE_VIN.props.title   = 'Or...IN STATE by VIN'
    $inState.layout.$variant.CARD_INSTATE_DECAL.props.title = 'Or...IN STATE by DECAL'
    $inState.layout.$variant.CARD_INSTATE_TITLE.props.title = 'Or...IN STATE by TITLE'
    Write-Host "${variant}: titles updated"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
