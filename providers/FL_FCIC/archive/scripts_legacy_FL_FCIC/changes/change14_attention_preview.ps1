$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# Find ENTITY_Person_DH at bundles[0].configurations[2]
$dh = $j.bundles[0].configurations[2]
if ($dh.name -ne 'ENTITY_Person_DH') {
    Write-Error "Expected ENTITY_Person_DH at bundles[0].configurations[2], got: $($dh.name)"
    exit 1
}

# Patch Attention_Input in all three layout variants
foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $node = $dh.layout.$variant.Attention_Input
    if ($node) {
        $node.props | Add-Member -NotePropertyName 'performSearchAhead' -NotePropertyValue $true -Force
        Write-Host "Patched $variant Attention_Input"
    } else {
        Write-Warning "Attention_Input not found in $variant layout"
    }
}

# Write back
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done: performSearchAhead=true added to Attention_Input in ENTITY_Person_DH"
