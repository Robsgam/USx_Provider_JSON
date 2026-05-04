$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# --- FL_FCIC_DriverHistoryQuery ---
$dhqBundle = $j.bundles | Where-Object {
    $_.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }
}
$dhq = $dhqBundle.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

# Restrict Driver History to ENTITY_Person_DH only
$dhq | Add-Member -NotePropertyName 'entityForms' -NotePropertyValue @('ENTITY_Person_DH') -Force

# Replace combinations: DH by OLN and DH by NAM only
# State fieldId in ENTITY_Person_DH is 'RegistrationState'
$dhq.combinations = @(
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('RegistrationState','PurposeCode','Attention','OperatorLicenseNumber')
            any = @('ImageIndicator')
        }
        primaryFieldReference = 'OperatorLicenseNumber'
        keyReference          = 'KQOperatorLicenseNumber'
        state                 = 'In/Out'
    },
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('RegistrationState','PurposeCode','Attention','NameFirst','NameLast','BirthDate','SexCode')
            any = @('ImageIndicator')
        }
        primaryFieldReference = 'Name'
        keyReference          = 'KQName'
        state                 = 'In/Out'
    }
)

Write-Host "FL_FCIC_DriverHistoryQuery: entityForms set, combinations replaced (2 combos)"

# --- FL_FCIC_DriverLicenseQuery ---
$dlqBundle = $j.bundles | Where-Object {
    $_.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
}
$dlq = $dlqBundle.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }

# Restrict Driver License to InState and OOS only (not DH)
$dlq | Add-Member -NotePropertyName 'entityForms' -NotePropertyValue @('ENTITY_Person_InState','ENTITY_Person_OOS') -Force

Write-Host "FL_FCIC_DriverLicenseQuery: entityForms set (InState + OOS only)"

# Write back
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
