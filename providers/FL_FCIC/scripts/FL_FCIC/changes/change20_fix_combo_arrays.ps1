$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$vrq = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_VehicleRegistrationQuery') { $vrq = $_ }
        }
    }
}

# Ensure requirements.set and requirements.any are always arrays
foreach ($combo in $vrq.combinations) {
    if ($combo.requirements.set -is [string]) {
        $combo.requirements.set = @($combo.requirements.set)
        Write-Host "Fixed set array for: $($combo.keyReference)"
    }
    if ($combo.requirements.any -is [string]) {
        $combo.requirements.any = @($combo.requirements.any)
        Write-Host "Fixed any array for: $($combo.keyReference)"
    }
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
