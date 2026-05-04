$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# ─── 1. Rename fieldIds in ENTITY_Person_DH layout (all 3 variants) ───────────
$dh = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Person_DH' }

$fieldMap = @{
    'OperatorLicenseNumber' = 'OperatorLicenseNumberDH'
    'NameFirst'             = 'NameFirstDH'
    'NameLast'              = 'NameLastDH'
    'NameMiddle'            = 'NameMiddleDH'
    'NameSuffix'            = 'NameSuffixDH'
    'BirthDate'             = 'BirthDateDH'
    'SexCode'               = 'SexCodeDH'
}

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $nodes = $dh.layout.$variant
    $nodes.PSObject.Properties | ForEach-Object {
        $node = $_.Value
        if ($node.props -and $node.props.fieldId -and $fieldMap.ContainsKey($node.props.fieldId)) {
            $old = $node.props.fieldId
            $node.props.fieldId = $fieldMap[$old]
        }
    }
    Write-Host "Layout $variant fieldIds renamed"
}

# ─── 2. Update FL_FCIC_DriverHistoryQuery attributes ──────────────────────────
$dhq = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_DriverHistoryQuery') { $dhq = $_ }
        }
    }
}

foreach ($attr in $dhq.attributes) {
    switch ($attr.name) {
        'OperatorLicenseNumber' {
            $attr.sourceField = @('OperatorLicenseNumberDH')
        }
        'BirthDate' {
            $attr.sourceField = @('BirthDateDH')
        }
        'SexCode' {
            $attr.sourceField = @('SexCodeDH')
        }
        'Name' {
            $attr.sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH')
        }
    }
}
Write-Host "DHQ attributes updated"

# ─── 3. Replace combinations ──────────────────────────────────────────────────
$dhq.combinations = @(
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('RegistrationState','PurposeCode','Attention','OperatorLicenseNumberDH')
            any = @('ImageIndicator')
        }
        primaryFieldReference = 'OperatorLicenseNumber'
        keyReference          = 'KQOperatorLicenseNumber'
        state                 = 'In/Out'
    },
    [PSCustomObject]@{
        requirements = [PSCustomObject]@{
            set = @('RegistrationState','PurposeCode','Attention','NameFirstDH','NameLastDH','BirthDateDH','SexCodeDH')
            any = @('ImageIndicator')
        }
        primaryFieldReference = 'Name'
        keyReference          = 'KQName'
        state                 = 'In/Out'
    }
)
Write-Host "DHQ combinations updated"

# ─── 4. Write back ────────────────────────────────────────────────────────────
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
