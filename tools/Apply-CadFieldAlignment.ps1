<#
.SYNOPSIS
    CAD field alignment for MC build scripts.
    Renames PascalCase fieldIds to camelCase for CAD auto-populate compatibility.

.DESCRIPTION
    MC build scripts use PascalCase fieldIds. CAD dispatch sends camelCase.
    This function renames sourceField values, combo set[]/any[] values, and QIF
    fieldIds to camelCase. Does NOT touch: name, targetField, primaryFieldReference,
    keyReference (these are XML-facing and must stay PascalCase).

    Standard renames cover all known CAD fields. Provider-specific renames can be
    passed via -ProviderRenames for fields unique to a provider's CAD integration.

.PARAMETER QidmList
    Array of QIDM PSCustomObjects (CommSys QIDMs to rename sourceFields/combos).

.PARAMETER FormList
    Array of QIF form PSCustomObjects (to rename fieldIds in layout nodes).

.PARAMETER RmsBundle
    RMS bundle PSCustomObject (to rename sourceFields/combos in RMS QIDMs).

.PARAMETER ProviderRenames
    Optional hashtable of provider-specific PascalCase -> camelCase renames.
    Merged with standard renames. Provider values override standard if keys collide.

.EXAMPLE
    . "$PSScriptRoot/../../tools/Apply-CadFieldAlignment.ps1"
    Apply-CadFieldAlignment -QidmList @($vehRegQuery, $dlQuery) -FormList @($vehicleForm, $personForm) -RmsBundle $rmsBundle
#>
function Apply-CadFieldAlignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [array]$QidmList,
        [Parameter(Mandatory)] [array]$FormList,
        [Parameter(Mandatory)] $RmsBundle,
        [hashtable]$ProviderRenames = @{}
    )

    # Standard CAD field renames — covers all fields CAD currently sends
    $standardRenames = @{
        # Vehicle
        'LicensePlateNumber'        = 'licensePlateNumber'
        'LicensePlateTypeCode'      = 'licensePlateTypeCode'
        'LicensePlateYear'          = 'licensePlateYear'
        'VehicleIdentificationNumber' = 'vehicleIdentificationNumber'
        'VehicleMakeCode'           = 'vehicleMakeCode'
        'VehicleYear'               = 'vehicleYear'
        'LicensePlateColorCode'     = 'licensePlateColorCode'
        # Person
        'OperatorLicenseNumber'     = 'operatorLicenseNumber'
        'NameFirst'                 = 'nameFirst'
        'NameLast'                  = 'nameLast'
        'NameMiddle'                = 'nameMiddle'
        'NameSuffix'                = 'nameSuffix'
        'BirthDate'                 = 'birthDate'
        'SexCode'                   = 'sexCode'
        'RaceCode'                  = 'raceCode'
        'Attention'                 = 'attention'
        'PurposeCode'               = 'purposeCode'
        'SocialSecurityNumber'      = 'socialSecurityNumber'
        'RelatedHitSearchIndicator' = 'relatedHitSearchIndicator'
        'Age'                       = 'age'
        'Height'                    = 'height'
        'HairColor'                 = 'hairColor'
        # Firearm
        'SerialNumber'              = 'serialNumber'
        'FirearmMake'               = 'firearmMake'
        'GunCaliber'                = 'gunCaliber'
        'GunModel'                  = 'gunModel'
        'GunTypeCode'               = 'gunTypeCode'
        'GunSerialNumber'           = 'gunSerialNumber'
        'GunMake'                   = 'gunMake'
        # Article
        'ArticleTypeCode'           = 'articleTypeCode'
        'ArticleSerialNumber'       = 'articleSerialNumber'
        'ArticleBrand'              = 'articleBrand'
        'ArticleCategory'           = 'articleCategory'
        'OwnerAppliedNumber'        = 'ownerAppliedNumber'
        # Boat
        'BoatHullIdNumber'          = 'boatHullIdNumber'
        'RegistrationNumber'        = 'registrationNumber'
        'CoastGuardDocumentNumber'  = 'coastGuardDocumentNumber'
        'DecalNumber'               = 'decalNumber'
        'TitleLienInformation'      = 'titleLienInformation'
        # Shared
        'RegistrationState'         = 'registrationState'
        'ImageIndicator'            = 'imageIndicator'
        'NCICNumber'                = 'ncicNumber'
        'ProcessControlNumber'      = 'processControlNumber'
    }

    # Merge provider-specific renames (provider overrides standard)
    $renames = $standardRenames.Clone()
    foreach ($k in $ProviderRenames.Keys) {
        $renames[$k] = $ProviderRenames[$k]
    }

    # Helper: rename values in an array using the rename map (always returns array)
    $renameArray = {
        param($arr)
        $result = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $arr) {
            if ($renames.ContainsKey($item)) { $result.Add($renames[$item]) } else { $result.Add($item) }
        }
        return [string[]]$result.ToArray()
    }

    # 1. Rename in CommSys QIDMs (sourceField + combo set[]/any[])
    foreach ($qidm in $QidmList) {
        if (-not $qidm) { continue }
        foreach ($attr in $qidm.attributes) {
            if ($attr.sourceField) {
                $attr.sourceField = [array](& $renameArray $attr.sourceField)
            }
        }
        foreach ($combo in $qidm.combinations) {
            if ($combo.requirements.set) {
                $combo.requirements.set = [array](& $renameArray $combo.requirements.set)
            }
            if ($combo.requirements.any) {
                $combo.requirements.any = [array](& $renameArray $combo.requirements.any)
            }
        }
    }

    # 2. Rename in QIF layout nodes (fieldId property)
    foreach ($form in $FormList) {
        if (-not $form) { continue }
        $layoutJson = $form.layout | ConvertTo-Json -Depth 30
        foreach ($k in $renames.Keys) {
            $layoutJson = $layoutJson -replace "`"fieldId`":\s*`"$k`"", "`"fieldId`": `"$($renames[$k])`""
        }
        $form.layout = $layoutJson | ConvertFrom-Json
    }

    # 3. Rename in RMS QIDMs (sourceField + combo set[]/any[])
    foreach ($cfg in $RmsBundle.configurations) {
        if (-not $cfg.attributes) { continue }
        foreach ($attr in $cfg.attributes) {
            if ($attr.sourceField) {
                $attr.sourceField = [array](& $renameArray $attr.sourceField)
            }
        }
        if (-not $cfg.combinations) { continue }
        foreach ($combo in $cfg.combinations) {
            if ($combo.requirements.set) {
                $combo.requirements.set = [array](& $renameArray $combo.requirements.set)
            }
            if ($combo.requirements.any) {
                $combo.requirements.any = [array](& $renameArray $combo.requirements.any)
            }
        }
    }
}
