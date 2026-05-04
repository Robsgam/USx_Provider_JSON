$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$inState = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Vehicle_InState' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    foreach ($nodeKey in @('LPYear_InStatePlate','LPYear_InStateDecal')) {
        $inState.layout.$variant.$nodeKey.props | Add-Member -NotePropertyName 'clearable' -NotePropertyValue $true -Force
    }
    Write-Host "${variant}: clearable=true set on LPYear_InStatePlate + LPYear_InStateDecal"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
