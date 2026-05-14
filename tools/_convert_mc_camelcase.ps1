<#
  _convert_mc_camelcase.ps1 — One-time conversion: PascalCase fieldIds → camelCase
  Targets ONLY sourceField arrays, combo set[]/any[] arrays, and layout Inp/Sel/Dt fieldIds.
  Preserves: name, targetField, primaryFieldReference, keyReference (XML-facing).
  Also removes Apply-CadFieldAlignment.ps1 call and fixes RMS patch strings.
  Usage: powershell -File _convert_mc_camelcase.ps1 -Path <build_script.ps1>
#>
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = 'Stop'
$content = Get-Content $Path -Raw

$renames = @{
    'OperatorLicenseNumberDH' = 'operatorLicenseNumberDH'
    'RegistrationStateDH'     = 'registrationStateDH'
    'NameLastDH'              = 'nameLastDH'
    'NameFirstDH'             = 'nameFirstDH'
    'BirthDateDH'             = 'birthDateDH'
    'SexCodeDH'               = 'sexCodeDH'
    'PurposeCodeDH'           = 'purposeCodeDH'
    'AttentionDH'             = 'attentionDH'
    'LicensePlateNumber'      = 'licensePlateNumber'
    'LicensePlateTypeCode'    = 'licensePlateTypeCode'
    'LicensePlateYear'        = 'licensePlateYear'
    'VehicleIdentificationNumber' = 'vehicleIdentificationNumber'
    'VehicleMakeCode'         = 'vehicleMakeCode'
    'VehicleYear'             = 'vehicleYear'
    'DecalNumber'             = 'decalNumber'
    'TitleLienInformation'    = 'titleLienInformation'
    'ImageIndicator'          = 'imageIndicator'
    'RegistrationState'       = 'registrationState'
    'OperatorLicenseNumber'   = 'operatorLicenseNumber'
    'NameFirst'               = 'nameFirst'
    'NameLast'                = 'nameLast'
    'NameMiddle'              = 'nameMiddle'
    'NameSuffix'              = 'nameSuffix'
    'BirthDate'               = 'birthDate'
    'SexCode'                 = 'sexCode'
    'Attention'               = 'attention'
    'PurposeCode'             = 'purposeCode'
    'RelatedHitSearchIndicator' = 'relatedHitSearchIndicator'
    'GunSerialNumber'         = 'gunSerialNumber'
    'GunMake'                 = 'gunMake'
    'NCICNumber'              = 'ncicNumber'
    'ProcessControlNumber'    = 'processControlNumber'
    'ArticleSerialNumber'     = 'articleSerialNumber'
    'ArticleTypeCode'         = 'articleTypeCode'
    'OwnerAppliedNumber'      = 'ownerAppliedNumber'
    'BoatHullIdNumber'        = 'boatHullIdNumber'
    'RegistrationNumber'      = 'registrationNumber'
    'CoastGuardDocumentNumber' = 'coastGuardDocumentNumber'
    'GunCaliber'              = 'gunCaliber'
    'GunModel'                = 'gunModel'
    'GunTypeCode'             = 'gunTypeCode'
    'SerialNumber'            = 'serialNumber'
    'FirearmMake'             = 'firearmMake'
    'ArticleBrand'            = 'articleBrand'
    'ArticleCategory'         = 'articleCategory'
    'CaRequestPurposeCode'    = 'caRequestPurposeCode'
    'CaRequestPurposeCodeDH'  = 'caRequestPurposeCodeDH'
    'RandomRequest'           = 'randomRequest'
    'VehicleTypeCode'         = 'vehicleTypeCode'
    'EmailAddress'            = 'emailAddress'
}

function RenameInArray([string]$inner) {
    foreach ($k in $renames.Keys) {
        $inner = $inner.Replace("'$k'", "'$($renames[$k])'")
    }
    return $inner
}

# 1. sourceField = @(...)
$content = [regex]::Replace($content, "sourceField\s*=\s*@\(([^)]+)\)", {
    param([System.Text.RegularExpressions.Match]$m)
    $inner = RenameInArray $m.Groups[1].Value
    "sourceField = @($inner)"
})

# 2. combo set = @(...) and any = @(...) — skip auth ORI
$content = [regex]::Replace($content, "((?:set|any)\s*=\s*@\()([^)]+)(\))", {
    param([System.Text.RegularExpressions.Match]$m)
    if ($m.Value -match "'ORI'") { return $m.Value }
    $prefix = $m.Groups[1].Value
    $inner  = RenameInArray $m.Groups[2].Value
    "$prefix$inner$($m.Groups[3].Value)"
})

# 3. Inp/Sel/Dt layout fieldIds — replace ONLY the fieldId argument, keep function name
$content = [regex]::Replace($content, "((?:Inp|Sel|Dt)\s+)'(\w+)'", {
    param([System.Text.RegularExpressions.Match]$m)
    $funcAndSpace = $m.Groups[1].Value
    $fid = $m.Groups[2].Value
    if ($renames.ContainsKey($fid)) {
        "${funcAndSpace}'$($renames[$fid])'"
    } else {
        $m.Value
    }
})

# 4. RMS patch: + 'RegistrationState' → + 'registrationState'
$content = $content.Replace("+ 'RegistrationState'", "+ 'registrationState'")

# 5. Remove Apply-CadFieldAlignment block
$lines = $content -split "`r?`n"
$skip = $false
$cleaned = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '# CAD Field Alignment:') { $skip = $true }
    if ($skip) {
        if ($lines[$i] -match '-RmsBundle') { $skip = $false; continue }
        continue
    }
    $cleaned.Add($lines[$i])
}
$content = $cleaned -join "`r`n"

[System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Converted: $Path"
