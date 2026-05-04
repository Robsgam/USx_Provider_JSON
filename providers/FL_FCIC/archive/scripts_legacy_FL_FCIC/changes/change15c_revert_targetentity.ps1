$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# Revert ENTITY_Person_DH targetEntity back to Person
$dh = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }
$dh.targetEntity = 'Person'
Write-Host "ENTITY_Person_DH targetEntity -> Person"

# Revert FL_FCIC_DriverHistoryQuery targetEntity back to Person
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_DriverHistoryQuery') {
                $_.targetEntity = 'Person'
                Write-Host "FL_FCIC_DriverHistoryQuery targetEntity -> Person"
            }
        }
    }
}

$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done. Person (Driver History) tab restored."
