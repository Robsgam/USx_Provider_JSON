# build_LA_LEMS_mc.ps1  -- LA_LEMS v2.3 MC
# Multi-card layout. QIDMs use PascalCase (no Patch 8).
# v2.3: DH-suffix fieldIds, queriesToDeselect, combo reorder (most set[] first, Name before OLN)
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_LA_LEMS_mc.ps1
#
# MC Card Grouping:
#   Vehicle: OPTIONS (State, PlateType, PlateYear) + PLATE SEARCH (Plate) + VIN SEARCH (VIN)
#   Person:  OPTIONS (State, ImageIndicator, PurposeCodeDH) + LICENSE NUMBER (OLN) + NAME SEARCH (Name, DOB, Sex, Race) + DH LICENSE (OLN DH) + DH NAME SEARCH (NameDH, DOBDH, SexDH)
#   Firearm: same as BASE (single card -- GunSerial, GunMake, GunTypeCode)
#   Article: same as BASE (single card -- ArticleSerial, ArticleType)
#   Boat:    REGISTRATION (RegNumber, State) + HULL (HullID)

param(
    [string]$Version = "2.5",
    [string]$Phase   = "mc"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\LA_LEMS_MC.json"
$VEROUT   = "$PHASEDIR\LA_LEMS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: LA_LEMS PROVIDER (QIDMs identical to BASE)
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
    description                = 'Authentication configuration for LA LETTS OFML'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'LA_LEMS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'LA_LEMS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$results = Build-CommsysQrdm -ProviderName 'LA_LEMS'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'LA_LEMS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'LA_LEMS'
}

# QIDMs identical to BASE -- copied verbatim
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 17; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','registrationState'); any = @('licensePlateTypeCode','licensePlateYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQSLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','registrationState'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQSVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQS (Plate/VIN). State in set[] per metadata. 2 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';       size = 1;  sourceField = @('imageIndicator');       targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }
            size = 30; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 17; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';              size = 1;  sourceField = @('RaceCode');              targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # QWDN: Name+DOB+Race+Sex (5 set[] -- most specific first)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst','RaceCode'); any = @('imageIndicator','registrationState','nameMiddle','nameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWDN'
            state                 = 'In/Out'
        }
        # QWA: Name+DOB+Sex (4 set[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('imageIndicator','RaceCode','registrationState','nameMiddle','nameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In/Out'
        }
        # DP: Photo DL (2 set[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','imageIndicator'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DP'
            state                 = 'In/Out'
        }
        # DQ: DL by OLN (1 set[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- QWDN (Name+Race), QWA (Name), DP (photo OLN), DQ (OLN). 4 combos. autoSelect + queriesToDeselect.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('attention'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        }
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
        }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('nameLastDH','nameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ Name: Name+DOB+Sex+PurposeCode (5 set[] -- most specific first)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH','purposeCodeDH'); any = @('registrationState','NameMiddleDH','NameSuffixDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'In/Out'
        }
        # KQ OLN: OLN + PurposeCode (2 set[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH','purposeCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ (Name/OLN). DH-suffix fields. PurposeCode in set[]. Attention handler-only.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $false
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'GunMake';         size = 3;  sourceField = @('gunMake');         targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('gunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';     size = 3;  sourceField = @('gunTypeCode');     targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. GunMake maxLength=3 (LA-specific). GunTypeCode added.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('articleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleSerialNumber'); any = @('articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA. ArticleTypeCode in any[] per metadata.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Nlets Reg, State required) + QB (NCIC Stolen Hull). 2 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for LA_LEMS v${Version} MC"
    name           = 'LA_LEMS'
    type           = 'BUNDLE'
    provider       = 'LA_LEMS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC MULTI-CARD LAYOUTS
# =====================================================================

# Vehicle -- 3 cards: OPTIONS + PLATE SEARCH + VIN SEARCH
# State in set[] for both combos, no initialValue (officer selects explicitly)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';   node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_O1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_O1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_O1' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_P1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_P1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_V1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '17' 'ROW_VEH_V1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS + PLATE SEARCH + VIN SEARCH.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 5 cards: OPTIONS + LICENSE NUMBER + NAME SEARCH + DH LICENSE + DH NAME SEARCH
# DH-suffix fields isolate DH from DL field pool (AP #14, LIMITATION #24-25)
# No ImageIndicator default (DP/DQ routing toggle)
# PurposeCodeDH default='C' (DH routing gate per metadata)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_O1' }
                @{ id = 'PurposeCodeDH_Input';     node = Sel 'purposeCodeDH' 'Purpose Code (DH)' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE'; initialValue = 'C' } 'ROW_PER_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_L1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_L1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_N1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'nameFirst'  'First Name'  '30' 'ROW_PER_N1' }
                @{ id = 'NameLast_Input';   node = Inp 'nameLast'   'Last Name'   '30' 'ROW_PER_N1' }
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N2'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_N2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N2' }
                @{ id = 'RaceCode_Input';  node = Sel 'RaceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_N2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DRIVER HISTORY - LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_DL1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_PER_DL1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_NAME'
        title = 'DRIVER HISTORY - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DN1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'nameFirstDH'  'First Name (DH)'  '30' 'ROW_PER_DN1' }
                @{ id = 'NameLastDH_Input';   node = Inp 'nameLastDH'   'Last Name (DH)'   '30' 'ROW_PER_DN1' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'Middle Name (DH)' '30' 'ROW_PER_DN1' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix (DH)'      '30' 'ROW_PER_DN1' }
            )}
            @{ id = 'ROW_PER_DN2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_DN2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DN2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS + LICENSE + NAME + DH LICENSE + DH NAME. DH-suffix fields (AP #14).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- same as BASE (single card)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'gunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6'); fields = @(
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Firearm Type' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG. GunMake maxLen=3, GunTypeCode added.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- same as BASE (single card)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA. ArticleTypeCode optional (any[]).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- 2 cards: REGISTRATION (RegNumber + State) + HULL (HullID)
# Only 3 fields total -- no ImageIndicator/RelatedHitSearch on LA boat
# BQ combo requires RegNumber+State (set[]). QB requires only HullID.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_R1'; cols = @('8','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_R1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_R1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_H1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_H1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: REGISTRATION + HULL SEARCH.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations -- MC variant (5 QIFs, multi-card)'
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
$rmsBundle = Build-RmsBundle -SkipRace
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{ bundles = @($entitiesBundle, $provBundle, $rmsBundle) }

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
$OUTREADABLE = "$DIR\LA_LEMS_MC_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built LA_LEMS_MC.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
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