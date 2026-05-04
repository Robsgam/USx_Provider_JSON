$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# --- 1. Remove entityForms from both mappings (not a valid platform property) ---
$dhq = $null; $dlq = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_DriverHistoryQuery') { $dhq = $_ }
            if ($_.name -eq 'FL_FCIC_DriverLicenseQuery')  { $dlq = $_ }
        }
    }
}

# Remove entityForms property
$dhqProps = $dhq.PSObject.Properties | Where-Object { $_.Name -ne 'entityForms' }
$dlqProps = $dlq.PSObject.Properties | Where-Object { $_.Name -ne 'entityForms' }
$newDhq = [PSCustomObject]@{}
$dhqProps | ForEach-Object { $newDhq | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value }
$newDlq = [PSCustomObject]@{}
$dlqProps | ForEach-Object { $newDlq | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value }

# Replace in bundle
$bundle = $j.bundles | Where-Object { $_.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' } }
$idx = [System.Collections.Generic.List[object]]::new()
$bundle.configurations | ForEach-Object { $idx.Add($_) }
for ($i = 0; $i -lt $idx.Count; $i++) {
    if ($idx[$i].name -eq 'FL_FCIC_DriverHistoryQuery') { $idx[$i] = $newDhq }
    if ($idx[$i].name -eq 'FL_FCIC_DriverLicenseQuery')  { $idx[$i] = $newDlq }
}
$bundle.configurations = $idx.ToArray()

# Re-fetch after replacement
$dhq = $bundle.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }
$dlq = $bundle.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
Write-Host "entityForms removed from both mappings"

# --- 2. Change FL_FCIC_DriverHistoryQuery targetEntity to 'PersonDH' ---
$dhq.targetEntity = 'PersonDH'
Write-Host "FL_FCIC_DriverHistoryQuery targetEntity -> PersonDH"

# --- 3. Change ENTITY_Person_DH targetEntity to 'PersonDH' ---
$dh = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }
$dh.targetEntity = 'PersonDH'
Write-Host "ENTITY_Person_DH targetEntity -> PersonDH"

# --- 4. Verify DL targetEntity stays 'Person' ---
Write-Host "FL_FCIC_DriverLicenseQuery targetEntity: $($dlq.targetEntity)"

# Write back
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
