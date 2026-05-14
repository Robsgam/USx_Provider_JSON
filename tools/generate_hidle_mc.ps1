<#
  generate_hidle_mc.ps1 — Creates templates/HIDLE_MC.json from templates/HIDLE.json
  MC-ready RMS template: camelCase sourceFields, registrationState, autoSelect, no LicensePlateNumberIn.
  Run whenever HIDLE.json changes.
#>
param(
    [string]$HidlePath = "$PSScriptRoot\..\templates\HIDLE.json",
    [string]$OutPath   = "$PSScriptRoot\..\templates\HIDLE_MC.json"
)

$ErrorActionPreference = 'Stop'

$hidle = Get-Content $HidlePath -Raw | ConvertFrom-Json

$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm    = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }

# ── camelCase rename map for all HIDLE sourceField/combo values ──
$renames = @{
    'NameFirst'='nameFirst'; 'NameLast'='nameLast'; 'NameMiddle'='nameMiddle'; 'NameSuffix'='nameSuffix'
    'BirthDate'='birthDate'; 'SexCode'='sexCode'; 'OperatorLicenseNumber'='operatorLicenseNumber'
    'VehicleYear'='vehicleYear'; 'VehicleIdentificationNumber'='vehicleIdentificationNumber'
    'VehicleMakeCode'='vehicleMakeCode'; 'RegistrationState'='registrationState'
    'LicensePlateNumber'='licensePlateNumber'; 'LicensePlateTypeCode'='licensePlateTypeCode'
    'ImageIndicator'='imageIndicator'; 'DecalNumber'='decalNumber'
    'LicensePlateNumberIn'='licensePlateNumber'
}

# ── Apply camelCase renames to ALL RMS configurations (QIDMs, QRDM, Results) ──
foreach ($cfg in $rmsBundle.configurations) {
    if ($cfg.attributes) {
        foreach ($attr in $cfg.attributes) {
            if ($attr.name -and $renames.ContainsKey($attr.name)) { $attr.name = $renames[$attr.name] }
            if ($attr.sourceField) {
                $sf = @($attr.sourceField)
                for ($i = 0; $i -lt $sf.Count; $i++) {
                    if ($renames.ContainsKey($sf[$i])) { $sf[$i] = $renames[$sf[$i]] }
                }
                $attr.sourceField = $sf
            }
        }
    }
    if ($cfg.combinations) {
        foreach ($combo in $cfg.combinations) {
            if ($combo.primaryFieldReference -and $renames.ContainsKey($combo.primaryFieldReference)) {
                $combo.primaryFieldReference = $renames[$combo.primaryFieldReference]
            }
            if ($combo.requirements.set) {
                $combo.requirements.set = @($combo.requirements.set | ForEach-Object {
                    if ($renames.ContainsKey($_)) { $renames[$_] } else { $_ }
                })
            }
            if ($combo.requirements.any) {
                $combo.requirements.any = @($combo.requirements.any | ForEach-Object {
                    if ($renames.ContainsKey($_)) { $renames[$_] } else { $_ }
                })
            }
        }
    }
}

# ── registrationState in Vehicle licensePlateIn combo any[] ──
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
if ($plateInCombo -and ($plateInCombo.requirements.any -notcontains 'registrationState')) {
    $plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'registrationState'
}

# ── registrationState attribute + combo any[] in Person QIDM ──
$hasRegState = $rmsPersonQidm.attributes | Where-Object { $_.name -eq 'registrationState' }
if (-not $hasRegState) {
    $rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
        name           = 'registrationState'
        sourceField    = @('registrationState')
        targetField    = 'registrationStateAttrId'
        useAttributeId = $true
    }
}
foreach ($combo in $rmsPersonQidm.combinations) {
    if ($combo.requirements.any -notcontains 'registrationState') {
        $combo.requirements.any = @($combo.requirements.any) + 'registrationState'
    }
}

# ── autoSelect=true on both QIDMs ──
$rmsVehQidm    | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
$rmsPersonQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force

# ── Serialize and do final string-level rename for fieldId in layout nodes ──
$json = $hidle | ConvertTo-Json -Depth 100
$json = $json -replace '"LicensePlateNumberIn"', '"licensePlateNumber"'

[System.IO.File]::WriteAllText($OutPath, $json, [System.Text.UTF8Encoding]::new($false))

# ── Verify no LicensePlateNumberIn remains ──
$remaining = ([regex]::Matches($json, 'LicensePlateNumberIn')).Count
if ($remaining -gt 0) {
    Write-Warning "$remaining occurrences of LicensePlateNumberIn remain!"
}

Write-Host "Generated: $OutPath"
Write-Host "  Vehicle QIDM: $($rmsVehQidm.attributes.Count) attrs, $($rmsVehQidm.combinations.Count) combos, autoSelect=$($rmsVehQidm.autoSelect)"
Write-Host "  Person QIDM:  $($rmsPersonQidm.attributes.Count) attrs, $($rmsPersonQidm.combinations.Count) combos, autoSelect=$($rmsPersonQidm.autoSelect)"
