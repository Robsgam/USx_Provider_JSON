$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$dhq = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_DriverHistoryQuery') { $dhq = $_ }
        }
    }
}

# Check if ImageIndicator attribute already exists
$existing = $dhq.attributes | Where-Object { $_.name -eq 'ImageIndicator' }
if ($existing) {
    Write-Host "ImageIndicator attribute already present"
} else {
    $imgAttr = [PSCustomObject]@{
        name        = 'ImageIndicator'
        size        = 1
        sourceField = @('ImageIndicator')
        targetField = 'ImageIndicator'
    }
    $dhq.attributes = @($dhq.attributes) + $imgAttr
    Write-Host "Added ImageIndicator attribute to FL_FCIC_DriverHistoryQuery"
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
