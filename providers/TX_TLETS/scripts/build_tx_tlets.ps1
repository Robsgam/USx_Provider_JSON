# build_tx_tlets.ps1  -- TX_TLETS v2.5 BASE
# Builds TX_TLETS_BASE.json from source\TX_TLETS.xml + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tx_tlets.ps1
#
# INPUTS:
#   source\TX_TLETS.xml   -- XML metadata (System TLETS v30) [AUTHORITATIVE]
#   source\TX_TLETS.pdf   -- CommSys devdoc [CROSS-CHECK]
#   source\HIDLE.json     -- RMS structural template
#
# SCOPE: Basic Queries (7 transactions from XML metadata):
#   VehicleInsuranceRegistrationQuery, VehicleStolenQuery,
#   DriverLicenseQuery, DriverHistoryQuery,
#   GunQuery, ArticleSingleQuery, BoatQuery
#
#   TX-specific queries NOT in scope for BASE:
#     TxDriverMultiQuery (CPL combos), TxRSDWMultiQuery (RSDWW combos),
#     WantedPersonQuery (standalone), ProtectiveOrderQuery,
#     SexOffenderQuery, CCH queries, WMPE/WMPI queries
#
# XML METADATA NOTES:
#   VehicleInsuranceRegistrationQuery: 7 combos (RQ x2, QV x2, DPSI, REG, VIN)
#     TX-specific fields: StickerNumber, FinancialResponsibilityType, RegionId
#     No ImageIndicator on this transaction (metadata-authoritative)
#   DriverLicenseQuery: 3 combos (DQ Name, QW Name, DQ OLN)
#     TX-specific fields: EmailAddress (pending handler), ReasonCode,
#     ExpandedBirthDateSearchCode, RegionId
#     autoSelect=true, queriesToDeselect=DriverHistoryQuery
#   DriverHistoryQuery: 2 combos (KQ Name, KQ OLN) -- DH-suffix fields
#     Attention: CommsysGetLastNameFirstNameInitialRuleHandler (handler-only)
#     DH-suffix: operatorLicenseNumberDH, nameLastDH, nameFirstDH,
#       nameMiddleDH, nameSuffixDH, birthDateDH, sexCodeDH, purposeCodeDH, reasonCodeDH
#     autoSelect=true, queriesToDeselect=DriverLicenseQuery
#   GunQuery: 1 metadata combo split to 2 (Serial / NCIC). GunMake maxLen=23.
#   ArticleSingleQuery: 1 metadata combo split to 2 (Serial+Type / NCIC)
#   BoatQuery: 3 metadata QB combos + 2 BQ combos added for Nlets State routing
#     RegistrationNumber maxLength=11
#
# COMBO ROUTING:
#   Vehicle: PlateType=PC, PlateYear=2026 defaults (safe: State is combo discriminator, not PlateType/Year)
#   Boat: BQ requires State in set[] (Nlets), QB does not (NCIC)
#
# NAME FORMAT: "Last,First Middle Suffix" (NCIC standard comma separator)
# DATE FORMAT: MMddyyyy

param(
    [string]$Version = "2.5",
    [string]$Phase   = "base"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR         = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\TX_TLETS_BASE.json"
$VEROUT   = "$PHASEDIR\TX_TLETS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS
# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: TX_TLETS PROVIDER
# =====================================================================

$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');     targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic'); targetField = 'Mnemonic' }
        [PSCustomObject]@{
            description = 'dexUserStateid from RMS profile'
            name        = 'UserName'
            rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
            sourceField = @('dexStateUserId')
            targetField = 'UserName'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            keyReference = 'AUTH'
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for TX TLETS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'TX_TLETS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'TX_TLETS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'TX_TLETS_Results'
$results.description = 'Results mapping for TX TLETS'
$results.provider    = 'TX_TLETS'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'TX_TLETS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'TX_TLETS'
}

# =====================================================================
# VehicleInsuranceRegistrationQuery -- 7 combos
# No ImageIndicator (not in TX vehicle metadata)
# No PlateType/PlateYear defaults (combo routing)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'FinancialResponsibilityType'; size = 1;  sourceField = @('financialResponsibilityType'); targetField = 'FinancialResponsibilityType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RegionId';                    size = 4;  sourceField = @('regionId');                    targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'StickerNumber';               size = 10; sourceField = @('stickerNumber');               targetField = 'StickerNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','financialResponsibilityType'); any = @('registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'REGLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode'); any = @('registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','financialResponsibilityType'); any = @('registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'VINVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('stickerNumber'); any = @('registrationState') }
            primaryFieldReference = 'StickerNumber'
            keyReference          = 'DPSIStickerNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('regionId','registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('registrationState','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('regionId') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleInsuranceRegistrationQuery -- RQ/QV/REG/DPSI/VIN. 7 combos.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'TX_TLETS_VehicleInsuranceRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('VehicleStolenQuery')
    provider           = 'TX_TLETS'
    providerType       = 'Commsys'
    query              = 'VehicleInsuranceRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# VehicleStolenQuery -- 2 combos (QV plate, QV VIN)
# Metadata keyRef QV for both -> invented QV.P / QV.V (LIMITATION #21)
# Mutual exclusion with VehicleInsuranceRegistrationQuery via queriesToDeselect
# autoSelect=false -- officer manually checks to run stolen query
# =====================================================================
$vehStolenQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'RegionId';                    size = 4;  sourceField = @('regionId');                    targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('regionId','registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('regionId') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleStolenQuery -- QV.P (plate), QV.V (VIN). NCIC stolen vehicle check.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'TX_TLETS_VehicleStolenQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $false
    queriesToDeselect  = @('VehicleInsuranceRegistrationQuery')
    provider           = 'TX_TLETS'
    providerType       = 'Commsys'
    query              = 'VehicleStolenQuery'
    queryLabel         = 'Vehicle Stolen'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# DriverLicenseQuery -- 3 combos (DQ Name, QW Name, DQ OLN)
# EmailAddress: pending handler from eng (no form field)
# autoSelect=true, queriesToDeselect=DriverHistoryQuery
# Combo order: most set[] first (Name 4 > Name 3 > OLN 1)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'EmailAddress';                size = 80; sourceField = @('emailAddress');                targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1;  sourceField = @('expandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('imageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }
            size = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';              size = 1;  sourceField = @('raceCode');              targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'ReasonCode';            size = 1;  sourceField = @('reasonCode');            targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'RegionId';              size = 4;  sourceField = @('regionId');              targetField = 'RegionId' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('imageIndicator','nameMiddle','nameSuffix','reasonCode','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('expandedBirthDateSearchCode','nameMiddle','nameSuffix','raceCode','regionId','sexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','reasonCode','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (Name/OLN), QW (Wanted Person). autoSelect+queriesToDeselect. EmailAddress pending handler.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TX_TLETS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverHistoryQuery')
    provider        = 'TX_TLETS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# DriverHistoryQuery -- 2 combos (KQ Name, KQ OLN) -- DH-suffix fields
# Duplicate keyRef KQ -> invented KQOperatorLicenseNumber / KQName
# Attention: handler-populated (CommsysGetLastNameFirstNameInitialRuleHandler), NOT in combo requirements
# EmailAddress: pending handler (QIDM-only, no form field, no DH-suffix)
# autoSelect=true, queriesToDeselect=DriverLicenseQuery
# DH-suffix fields isolate from DL field pool (AP #14)
# Combo order: most set[] first (Name 4 > OLN 1)
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'EmailAddress';   size = 80; sourceField = @('emailAddress');   targetField = 'EmailAddress' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1;  sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode';            size = 1;  sourceField = @('reasonCodeDH');            targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('imageIndicator','nameMiddleDH','nameSuffixDH','purposeCodeDH','reasonCodeDH','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('imageIndicator','purposeCodeDH','reasonCodeDH','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ (Name/OLN). DH-suffix fields. Attention handler-only.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TX_TLETS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverLicenseQuery')
    provider        = 'TX_TLETS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# GunQuery -- 2 combos (Serial, NCIC). GunMake maxLength=23.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('gunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 23; sourceField = @('gunMake');                   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('gunSerialNumber');           targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunCaliber','gunMake','imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGGunSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QGNCICNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (Serial/NCIC). GunMake maxLength=23.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TX_TLETS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TX_TLETS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# ArticleSingleQuery -- 2 combos (Serial+Type, NCIC)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('articleSerialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('articleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QAArticleSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QANCICNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (Serial+Type / NCIC).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TX_TLETS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TX_TLETS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# BoatQuery -- 5 combos (BQ x2 Nlets + QB x3 NCIC)
# BQ requires State in set[] (Nlets routing), QB does not
# RegistrationNumber maxLength=11
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('boatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 11; sourceField = @('registrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQRegistrationNumber'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber','registrationState'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQBoatHullIdNumber'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QBRegistrationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QBNCICNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Nlets, State required) + QB (NCIC). 5 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TX_TLETS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TX_TLETS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $vehStolenQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for TX_TLETS v$Version"
    name           = 'TX_TLETS'
    type           = 'BUNDLE'
    provider       = 'TX_TLETS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# =====================================================================

$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'licensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';  node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'regionId_Input';           node = Inp 'regionId' 'Region ID' '4' 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6','6'); fields = @(
                @{ id = 'stickerNumber_Input';               node = Inp 'stickerNumber' 'Sticker Number' '10' 'ROW_VEH_5' }
                @{ id = 'financialResponsibilityType_Input'; node = Inp 'financialResponsibilityType' 'Financial Resp Type' '1' 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleInsuranceRegistrationQuery + VehicleStolenQuery. TX-specific fields.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'imageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
                @{ id = 'raceCode_Input';              node = Sel 'raceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('8','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_2' }
                @{ id = 'reasonCode_Input';            node = Inp 'reasonCode' 'Reason Code' '1' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameLast_Input';   node = Inp 'nameLast'   'Last Name'   '30' 'ROW_PER_3' }
                @{ id = 'nameFirst_Input';  node = Inp 'nameFirst'  'First Name'  '30' 'ROW_PER_3' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_3' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '30' 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_4' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_4' }
                @{ id = 'expandedBirthDateSearchCode_Input'; node = Inp 'expandedBirthDateSearchCode' 'Expanded DOB Search' '1' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'regionId_Input'; node = Inp 'regionId' 'Region ID' '4' 'ROW_PER_5' }
                @{ id = 'purposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code (DL)' '1' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_6' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameLastDH_Input';   node = Inp 'nameLastDH'   'Last Name (DH)'   '30' 'ROW_PER_7' }
                @{ id = 'nameFirstDH_Input';  node = Inp 'nameFirstDH'  'First Name (DH)'  '30' 'ROW_PER_7' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH)' '30' 'ROW_PER_7' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)'      '30' 'ROW_PER_7' }
            )}
            @{ id = 'ROW_PER_8'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_8' }
                @{ id = 'sexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_8' }
                @{ id = 'reasonCodeDH_Input'; node = Inp 'reasonCodeDH' 'Reason Code (DH)' '1' 'ROW_PER_8' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DQ/QW) + DH (KQ) on single card. DH-suffix fields isolate DH from DL.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'gunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';         node = Sel 'gunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'gunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'ncicNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('6'); fields = @(
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (Serial/NCIC).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'articleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ncicNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_ART_2' }
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (Serial+Type / NCIC).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'registrationNumber_Input';        node = Inp 'registrationNumber' 'Registration Number' '11' 'ROW_BOA_1' }
                @{ id = 'registrationState_Input';         node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'boatHullIdNumber_Input';          node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                @{ id = 'ncicNumber_Input';                node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('6','6'); fields = @(
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_3' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_3' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (Nlets) + QB (NCIC). State routing.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @(
        $vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm
    )
    description    = 'Entity form configurations'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Vehicle','Person','Firearm','Article','Boat')
        CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
        FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE, with standard patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add registrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'registrationState'

# Patch 3: add registrationState to RMS Person QIDM
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('registrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'registrationState'
}

# Patch 6: RMS CLEANUP
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehQidm.attributes = @($rmsVehQidm.attributes | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object {
    $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName')
})
foreach ($combo in $rmsVehQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'RaceCode' })
}

# Patch 7: RMS autoSelect=true on all RMS QIDMs
foreach ($rmsCfg in $rmsBundle.configurations) {
    if ($rmsCfg.type -eq 'QUERYINPUTDATAMAPPING') { $rmsCfg | Add-Member -NotePropertyName autoSelect -NotePropertyValue $true -Force }
}

# Patch 8: CAD field name alignment -- rename HIDLE RMS sourceField + combo refs to camelCase
# HIDLE uses PascalCase fieldIds. CAD sends camelCase. sourceField must match QIF fieldIds.
# Run AFTER all other patches so Patch 1/3/6 filters work on original HIDLE names.
$cadRenames = @{
    'LicensePlateNumberIn'        = 'licensePlateNumber'
    'LicensePlateNumberOut'       = 'licensePlateNumberOut'
    'VehicleIdentificationNumber' = 'vehicleIdentificationNumber'
    'VehicleMakeCode'             = 'vehicleMakeCode'
    'VehicleModelCode'            = 'vehicleModelCode'
    'VehicleYear'                 = 'vehicleYear'
    'RegistrationState'           = 'registrationState'
    'RegistrationStateOut'        = 'registrationStateOut'
    'OwnerFirstName'              = 'ownerFirstName'
    'OwnerLastName'               = 'ownerLastName'
    'OperatorLicenseNumber'       = 'operatorLicenseNumber'
    'NameFirst'                   = 'nameFirst'
    'NameLast'                    = 'nameLast'
    'NameMiddle'                  = 'nameMiddle'
    'NameSuffix'                  = 'nameSuffix'
    'BirthDate'                   = 'birthDate'
    'SexCode'                     = 'sexCode'
    'RaceCode'                    = 'raceCode'
    'ImageIndicator'              = 'imageIndicator'
}
foreach ($cfg in $rmsBundle.configurations) {
    if (-not $cfg.attributes) { continue }
    foreach ($attr in $cfg.attributes) {
        if ($attr.name -and $cadRenames.ContainsKey($attr.name)) {
            $attr.name = $cadRenames[$attr.name]
        }
        if ($attr.sourceField) {
            $attr.sourceField = @($attr.sourceField | ForEach-Object {
                if ($cadRenames.ContainsKey($_)) { $cadRenames[$_] } else { $_ }
            })
        }
    }
    if (-not $cfg.combinations) { continue }
    foreach ($combo in $cfg.combinations) {
        if ($combo.primaryFieldReference -and $cadRenames.ContainsKey($combo.primaryFieldReference)) {
            $combo.primaryFieldReference = $cadRenames[$combo.primaryFieldReference]
        }
        if ($combo.requirements.set) {
            $combo.requirements.set = @($combo.requirements.set | ForEach-Object {
                if ($cadRenames.ContainsKey($_)) { $cadRenames[$_] } else { $_ }
            })
        }
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | ForEach-Object {
                if ($cadRenames.ContainsKey($_)) { $cadRenames[$_] } else { $_ }
            })
        }
    }
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

$OUTREADABLE = "$DIR\TX_TLETS_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built TX_TLETS_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host ""
    Write-Host "Running structural validation..." -ForegroundColor Cyan
    powershell.exe -ExecutionPolicy Bypass -File $VALIDATOR -Path $OUT
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."