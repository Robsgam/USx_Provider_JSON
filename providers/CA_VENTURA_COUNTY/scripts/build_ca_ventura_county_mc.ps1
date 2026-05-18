# build_ca_ventura_county_mc.ps1  -- CA_VENTURA_COUNTY v1.4 MC
# MC variant: PascalCase fieldIds, no Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combos (IN.VP, IG.QGH, NLTS.BQ.N).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# KEY DIFFERENCE FROM CA_CLETS MC:
#   DriverHistoryQuery has in-state combos (IN.B2, ID.B2) in addition to NLTS.KQ OOS.
#   DH has Attention (CommsysGetLastNameFirstNameInitialRuleHandler) + PurposeCode attrs.
#   Article has ArticleCategory field.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_ventura_county_mc.ps1

$ErrorActionPreference = "Stop"
$Version  = '1.4'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\mc"
$OUT      = "$DIR\CA_VENTURA_COUNTY_MC.json"
$VEROUT   = "$PHASEDIR\CA_VENTURA_COUNTY_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_VENTURA_COUNTY PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_VENTURA_COUNTY'

$results = Build-ProviderQrdm -ProviderName 'CA_VENTURA_COUNTY'

$qmf = Build-Qmf -ProviderName 'CA_VENTURA_COUNTY'

# VehicleRegistrationQuery -- PascalCase + cross-entity (Name for IN.VP combo)
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 35; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS Plate (5 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'NLTS.RQ.P'
            state                 = 'In/Out'
        }
        # OOS VIN (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'NLTS.RQ.V'
            state                 = 'In/Out'
        }
        # Name search (3 set -- cross-entity)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.VP'
            state                 = 'In/Out'
        }
        # In-state Plate (2 set -- plate before VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber'); any = @('registrationState','licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IA.QV'
            state                 = 'In/Out'
        }
        # In-state VIN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IA.QVK'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- NLTS.RQ.P (OOS plate), NLTS.RQ.V (OOS VIN), IN.VP (name), IA.QV (plate), IA.QVK (VIN). Most-specific first. MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_VENTURA_COUNTY_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_VENTURA_COUNTY'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# DriverLicenseQuery -- PascalCase, autoSelect + queriesToDeselect DH
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name combo first (3 set, Name before OLN at same count)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @('birthDate','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
        # OOS OLN (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber','registrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        # In-state OLN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- IN.L1 (Name), NLTS.DQ (OOS OLN), ID.L1 (OLN). autoSelect+queriesToDeselect DH.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# DriverHistoryQuery -- PascalCase, DH-suffix fieldIds (AP #14 pattern)
# DH-suffix fields: OperatorLicenseNumberDH, NameLastDH, NameFirstDH, BirthDateDH, SexCodeDH, CaRequestPurposeCodeDH
# Attention: handler-only, uses DH-suffix names, NOT in combo requirements.
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCodeDH'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific (5 DH set + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.KQ.N'
            state                 = 'In/Out'
        }
        # In-state Name (3 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','nameLastDH','nameFirstDH'); any = @('birthDateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.B2'
            state                 = 'In/Out'
        }
        # OOS OLN (2 DH set + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (2 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.B2'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- DH-suffix fields. NLTS.KQ.N (Name OOS), IN.B2 (Name in-state), NLTS.KQ.O (OLN OOS), ID.B2 (OLN in-state). autoSelect+queriesToDeselect DL.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# GunQuery -- PascalCase + cross-entity (Name for IG.QGH combo)
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
    )
    combinations = @(
        # Name search (3 set -- more specific, cross-entity)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IG.QGH'
            state                 = 'In/Out'
        }
        # Serial search (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'IG.QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- IG.QGH (name) + IG.QGB (serial). Most-specific first. MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# ArticleSingleQuery -- PascalCase
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'IP.QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IP.QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- IP.QA (serial, OAN). CA property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase + cross-entity (Name+DOB for NLTS.BQ.N)
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific (5 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','birthDate','registrationState'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.BQ.N'
            state                 = 'In/Out'
        }
        # OOS hull (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber','registrationState'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'NLTS.BQ.H'
            state                 = 'In/Out'
        }
        # OOS reg (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber','registrationState'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'NLTS.BQ.R'
            state                 = 'In/Out'
        }
        # In-state hull (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'IA.QB.H'
            state                 = 'In/Out'
        }
        # In-state OAN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('registrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IA.QB.O'
            state                 = 'In/Out'
        }
        # In-state reg (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IA.QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- NLTS.BQ OOS (name, hull, reg) + IA.QB (hull, OAN, reg). Most-specific first. MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_VENTURA_COUNTY v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'CA_VENTURA_COUNTY'
    type           = 'BUNDLE'
    provider       = 'CA_VENTURA_COUNTY'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE SEARCH + VIN SEARCH + NAME SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  3 cards (OPTIONS + SERIAL SEARCH + NAME SEARCH)
# Article:  3 cards (OPTIONS + SERIAL SEARCH + OAN SEARCH)
# Boat:     5 cards (OPTIONS + HULL + REGISTRATION + OAN + NAME SEARCH)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState,
# CaRequestPurposeCode) live on a separate card to avoid duplicate fieldId
# across cards (= ISE). NCIC state pattern: visible RegistrationState,
# NO initialValue (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN + VehicleMake + VehicleYear
# NAME SEARCH: First + Last (cross-entity IN.VP)
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
        id    = 'CARD_VEH_NAME'
        title = 'NAME SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_VEH_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_VEH_NAME_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + Purpose) + PLATE (IA.QV/NLTS.RQ.P) + VIN (IA.QVK/NLTS.RQ.V) + NAME (IN.VP cross-entity)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 5 cards (MC) -- DL fields + DH-suffix fields (AP #14)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared, DL only)
# DL OLN SEARCH: OperatorLicenseNumber
# DL NAME SEARCH: First + Last + DOB + Sex
# DH OLN SEARCH: OperatorLicenseNumberDH + CaRequestPurposeCodeDH
# DH NAME SEARCH: NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH
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
        title = 'DL - OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'DL - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DH - OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_OLN_1' }
                @{ id = 'CaRequestPurposeCodeDH_Input';  node = Inp 'caRequestPurposeCodeDH'  'Purpose Code (DH)'   '1'  'ROW_PER_DH_OLN_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_NAME'
        title = 'DH - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH_NAME_1' }
                @{ id = 'NameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_NAME_1' }
            )}
            @{ id = 'ROW_PER_DH_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'Date of Birth (DH)'                                                          'ROW_PER_DH_NAME_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_DH_NAME_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Purpose) + DL OLN/NAME + DH OLN/NAME (DH-suffix fields). 5 cards.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 3 cards (MC)
# OPTIONS: CaRequestPurposeCode (shared by serial + name combos)
# SERIAL SEARCH: Serial + Make + Caliber + Type (IG.QGB)
# NAME SEARCH: First + Last (cross-entity IG.QGH)
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
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_SERIAL_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_1' }
            )}
            @{ id = 'ROW_GUN_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
            )}
        )
    }
    @{
        id    = 'CARD_GUN_NAME'
        title = 'NAME SEARCH (Gun by Owner)'
        rows  = @(
            @{ id = 'ROW_GUN_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_GUN_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_GUN_NAME_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: OPTIONS (Purpose) + SERIAL (IG.QGB) + NAME (IG.QGH cross-entity)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 3 cards (MC)
# OPTIONS: CaRequestPurposeCode (shared by serial + OAN combos)
# SERIAL SEARCH: Serial + ArticleType + Brand + Category (IP.QA.S)
# OAN SEARCH: OwnerAppliedNumber (IP.QA.O)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_ART_OPT_1'; cols = @('4'); fields = @(
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_ART_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_SERIAL_1'; cols = @('12'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_ART_SERIAL_1' }
            )}
            @{ id = 'ROW_ART_SERIAL_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_SERIAL_2' }
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand'        '6'                                                                     'ROW_ART_SERIAL_2' }
                @{ id = 'ArticleCategory_Input'; node = Inp 'articleCategory' 'Category'     '1'                                                                     'ROW_ART_SERIAL_2' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_OAN'
        title = 'OAN SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_OAN_1'; cols = @('12'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_OAN_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: OPTIONS (Purpose) + SERIAL (IP.QA.S) + OAN (IP.QA.O)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 5 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# HULL SEARCH: BoatHullIdNumber (IA.QB.H / NLTS.BQ.H)
# REGISTRATION SEARCH: RegistrationNumber (IA.QB.R / NLTS.BQ.R)
# OAN SEARCH: OwnerAppliedNumber (IA.QB.O)
# NAME SEARCH: First + Last + DOB (cross-entity NLTS.BQ.N)
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
    @{
        id    = 'CARD_BOA_OAN'
        title = 'OAN SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_OAN_1'; cols = @('12'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_OAN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_NAME'
        title = 'NAME SEARCH (Boat by Owner)'
        rows  = @(
            @{ id = 'ROW_BOA_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_BOA_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_BOA_NAME_1' }
            )}
            @{ id = 'ROW_BOA_NAME_2'; cols = @('12'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt 'birthDate' 'Date of Birth' 'ROW_BOA_NAME_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Purpose) + HULL (IA.QB.H/NLTS.BQ.H) + REG (IA.QB.R/NLTS.BQ.R) + OAN (IA.QB.O) + NAME (NLTS.BQ.N cross-entity)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $caBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built CA_VENTURA_COUNTY v${Version}"