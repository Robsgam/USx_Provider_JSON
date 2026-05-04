$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$rms = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'RMS Person Search query') { $rms = $_ }
        }
    }
}

# ─── 1. Add DH-specific attributes ───────────────────────────────────────────
$newAttrs = @(
    [PSCustomObject]@{ name='firstNameDH';    size=60; sourceField=@('NameFirstDH');            targetField='firstName' },
    [PSCustomObject]@{ name='lastNameDH';     size=60; sourceField=@('NameLastDH');             targetField='lastName' },
    [PSCustomObject]@{ name='licenseNumberDH';size=60; sourceField=@('OperatorLicenseNumberDH');targetField='dlNumber' },
    [PSCustomObject]@{ name='dateOfBirthDH';        sourceField=@('BirthDateDH');              targetField='dateOfBirth' },
    [PSCustomObject]@{ name='sexDH'; sourceField=@('SexCodeDH'); targetField='sexAttrId'; useAttributeId=$true }
)

$rms.attributes = @($rms.attributes) + $newAttrs
Write-Host "Added DH attributes to RMS Person Search query"

# ─── 2. Add DH-specific combinations ─────────────────────────────────────────
$newCombos = @(
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('OperatorLicenseNumberDH','NameFirstDH','NameLastDH')
            any = @('RaceCode','SexCodeDH')
        }
        keyReference = 'firstNameLastNameDriversLicenseNumberDH'
    },
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('NameFirstDH','NameLastDH','BirthDateDH')
            any = @('RaceCode','SexCodeDH')
        }
        keyReference = 'firstNameLastNameDateOfBirthDH'
    },
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('NameFirstDH','NameLastDH')
            any = @('RaceCode','SexCodeDH')
        }
        keyReference = 'firstNameLastNameDH'
    },
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('OperatorLicenseNumberDH')
            any = @('RaceCode','SexCodeDH')
        }
        keyReference = 'driversLicenseNumberDH'
    }
)

$rms.combinations = @($rms.combinations) + $newCombos
Write-Host "Added DH combinations to RMS Person Search query"

# ─── 3. Write back ────────────────────────────────────────────────────────────
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
