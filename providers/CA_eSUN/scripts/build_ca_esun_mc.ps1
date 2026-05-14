# build_ca_esun_mc.ps1  -- CA_eSUN v1.3 MC
# MC variant: PascalCase fieldIds, no Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combos (VP.N/VP.D, QGH) already in BASE.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
# DH uses DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) + queriesToDeselect.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_esun_mc.ps1

$ErrorActionPreference = "Stop"
$Version  = '1.5'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\mc"
$OUT      = "$DIR\CA_eSUN_MC.json"
$OUTREAD  = "$DIR\CA_eSUN_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\CA_eSUN_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS
# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_eSUN PROVIDER (PascalCase sourceField / combo refs)
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
    description                = 'Authentication configuration for CA_eSUN'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'CA_eSUN'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'CA_eSUN'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$results = Build-CommsysQrdm -ProviderName 'CA_eSUN'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'CA_eSUN_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'CA_eSUN'
}

# ArticleSingleQuery -- PascalCase
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial). Property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.H (hull), BQ.R (reg). 6 XML combos collapsed to 2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# DriverLicenseQuery -- PascalCase
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','sexCode','birthDate','nameLast','nameFirst'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @('birthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.N/L1.O (in-state), DQ.N/DQ.O (OOS).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# DriverHistoryQuery -- PascalCase + DH-suffix fieldIds
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLastDH','nameFirstDH','sexCodeDH','birthDateDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLastDH','nameFirstDH'); any = @('birthDateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N.DH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O.DH'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- L1.N.DH/L1.O.DH (in-state), KQ.N/KQ.O (OOS). DH-suffix fieldIds for co-fire.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# GunQuery -- PascalCase (QGB serial + QGH name cross-entity)
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age';                  size = 2;  sourceField = @('GunAge');                targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('GunBirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 14; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('GunNameLast','GunNameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','GunNameLast','GunNameFirst'); any = @('GunBirthDate','GunAge') }
            primaryFieldReference = 'Name'
            keyReference          = 'QGH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode','RelatedSearchHitIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial), QGH (name). MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# VehicleRegistrationQuery -- PascalCase (QV plate/VIN + RQ OOS + VP owner search)
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCity';           size = 13; sourceField = @('AddressCity');           targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'AddressStreetNumber';   size = 3;  sourceField = @('AddressStreetNumber');   targetField = 'AddressStreetNumber' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('VehBirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('VehNameLast','VehNameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','VehNameLast','VehNameFirst','VehBirthDate'); any = @('AddressCity','AddressStreetNumber') }
            primaryFieldReference = 'BirthDate'
            keyReference          = 'VP.D'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','VehNameLast','VehNameFirst'); any = @('AddressCity','AddressStreetNumber') }
            primaryFieldReference = 'Name'
            keyReference          = 'VP.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber'); any = @('licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- QV.P/QV.V (in-state), RQ.P/RQ.V (OOS), VP.N/VP.D (owner search). MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_eSUN_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_eSUN'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

$esunBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $artQuery, $boatQuery, $dlQuery, $dhQuery, $gunQuery, $vehRegQuery)
    description    = "Provider configuration for CA_eSUN v${Version} MC -- 6 QIDMs, cross-entity (VP, QGH), DH-suffix"
    name           = 'CA_eSUN'
    type           = 'BUNDLE'
    provider       = 'CA_eSUN'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE + VIN + OWNER SEARCH)
# Person:   3 cards (OPTIONS + OLN + NAME) with DH-suffix hidden fields
# Firearm:  3 cards (OPTIONS + SERIAL + NAME SEARCH)
# Article:  1 card (serial only -- 1 combo)
# Boat:     3 cards (OPTIONS + HULL + REGISTRATION)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards (MC)
# OPTIONS: State + PurposeCode
# PLATE: LicensePlateNumber, PlateType, PlateYear
# VIN: VIN, VehicleMake, VehicleYear
# OWNER: VehNameFirst, VehNameLast, VehBirthDate, AddressCity, AddressStreetNumber
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
            )}
            @{ id = 'ROW_VEH_PLATE_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_PLATE_2' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_OWNER'
        title = 'OWNER SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_OWNER_1'; cols = @('6','6'); fields = @(
                @{ id = 'VehNameFirst_Input'; node = Inp 'VehNameFirst' 'Owner First Name' '30' 'ROW_VEH_OWNER_1' }
                @{ id = 'VehNameLast_Input';  node = Inp 'VehNameLast'  'Owner Last Name'  '30' 'ROW_VEH_OWNER_1' }
            )}
            @{ id = 'ROW_VEH_OWNER_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehBirthDate_Input';       node = Dt  'VehBirthDate'       'Owner DOB'            'ROW_VEH_OWNER_2' }
                @{ id = 'AddressCity_Input';         node = Inp 'AddressCity'         'City'          '13'  'ROW_VEH_OWNER_2' }
                @{ id = 'AddressStreetNumber_Input'; node = Inp 'AddressStreetNumber' 'Street Number' '3'   'ROW_VEH_OWNER_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + Purpose) + PLATE (QV.P/RQ.P) + VIN (QV.V/RQ.V) + OWNER (VP.N/VP.D cross-entity)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC) with DH-suffix hidden fields
# OPTIONS: State + PurposeCode
# OLN SEARCH: OperatorLicenseNumber + hidden OperatorLicenseNumberDH
# NAME SEARCH: NameFirst/Last + DOB + Sex + hidden DH equivalents
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
            @{ id = 'ROW_PER_OLN_DH'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = InpH 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_OLN_DH' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_NAME_2' }
            )}
            @{ id = 'ROW_PER_NAME_DH_1'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'NameFirstDH_Input'; node = InpH 'NameFirstDH' 'First Name (DH)' '30' 'ROW_PER_NAME_DH_1' }
                @{ id = 'NameLastDH_Input';  node = InpH 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_NAME_DH_1' }
            )}
            @{ id = 'ROW_PER_NAME_DH_2'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'BirthDateDH_Input'; node = DtH  'BirthDateDH' 'Date of Birth (DH)' 'ROW_PER_NAME_DH_2' }
                @{ id = 'SexCodeDH_Input';   node = SelH 'SexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_DH_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Purpose) + OLN (L1.O/DQ.O/KQ.O) + NAME (L1.N/DQ.N/KQ.N). DH-suffix for co-fire.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 3 cards (MC)
# OPTIONS: PurposeCode
# SERIAL: SerialNumber + Make + Caliber + Type + RelatedSearchHitIndicator(hidden)
# NAME: GunNameFirst/Last + GunBirthDate + GunAge (cross-entity QGH)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_GUN_OPT_1'; cols = @('4'); fields = @(
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_GUN_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '14' 'ROW_GUN_SERIAL_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_1' }
            )}
            @{ id = 'ROW_GUN_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
            )}
            @{ id = 'ROW_GUN_SERIAL_3'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'RelatedSearchHitIndicator_Input'; node = InpH 'RelatedSearchHitIndicator' 'Related Search Hit' '1' 'ROW_GUN_SERIAL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_GUN_NAME'
        title = 'NAME SEARCH (Gun by Person)'
        rows  = @(
            @{ id = 'ROW_GUN_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunNameFirst_Input'; node = Inp 'GunNameFirst' 'First Name' '30' 'ROW_GUN_NAME_1' }
                @{ id = 'GunNameLast_Input';  node = Inp 'GunNameLast'  'Last Name'  '30' 'ROW_GUN_NAME_1' }
            )}
            @{ id = 'ROW_GUN_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunBirthDate_Input'; node = Dt  'GunBirthDate' 'Date of Birth' 'ROW_GUN_NAME_2' }
                @{ id = 'GunAge_Input';       node = Inp 'GunAge'       'Age'       '2' 'ROW_GUN_NAME_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: OPTIONS (Purpose) + SERIAL (QGB) + NAME (QGH cross-entity)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA serial only -- single combo, no multi-card needed)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','4'); fields = @(
                @{ id = 'SerialNumber_Input';          node = Inp 'serialNumber'          'Serial Number'  '20' 'ROW_ART_1' }
                @{ id = 'CaRequestPurposeCode_Input';  node = Inp 'caRequestPurposeCode'  'Purpose Code'   '1'  'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand'        '6'                                                                     'ROW_ART_2' }
                @{ id = 'ArticleCategory_Input'; node = Inp 'articleCategory' 'Category'     '1'                                                                     'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial). Single combo, single card.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 3 cards (MC)
# OPTIONS: State + PurposeCode
# HULL: BoatHullIdNumber (BQ.H)
# REGISTRATION: RegistrationNumber (BQ.R)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Purpose) + HULL (BQ.H) + REG (BQ.R)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations for CA_eSUN MC'
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
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $esunBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built CA_eSUN_MC.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT