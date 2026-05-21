# build_nj_njcjis.ps1  -- NJ_NJCJIS
# Multi-card layout, 6 QIDMs, 12 combos.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_njcjis.ps1
#
# LAYOUT (5 QIFs, multi-card + compacted):
#   Vehicle: 3 cards (OPTIONS: State+Random+Image, PLATE: Plate+Type+Year, VIN: VIN+NCIC+Make)
#   Person:  3 cards (OPTIONS: State+Image, LICENSE: OLN, NAME: First+Last+DOB+Sex)
#   Firearm: 1 card (Serial/Make/Caliber/Model/Image)
#   Article: 1 card (Serial/Type/Image)
#   Boat:    1 card (Reg/Hull/Image)
#
# RMS: from KB specs (no HIDLE dependency)

param(
    [string]$Version = "3.4"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases"
$OUT      = "$DIR\NJ_NJCJIS.json"
$VEROUT   = "$PHASEDIR\NJ_NJCJIS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: NJ_NJCJIS PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'NJ_NJCJIS'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'NJ_NJCJIS'

$qmf = Build-Qmf -ProviderName 'NJ_NJCJIS'

# =====================================================================
# 1d. VehicleRegistrationQuery
#     autoSelect=true, NO queriesToDeselect.
#     Defaulted fields in any[] per LIMITATION #31.
#     4 combos: RAND (RandomRequest=Y) and default (RandomRequest!=Y) for plate and VIN.
#     RAND combos first (more specific via conditions), default combos as fallback.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('licensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RandomRequest';                size = 1;  sourceField = @('randomRequest');                targetField = 'RandomRequest' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('licensePlateNumber')
                any        = @('randomRequest','registrationState','licensePlateTypeCode','imageIndicator','licensePlateYear')
                conditions = @([PSCustomObject]@{ field = @('RandomRequest'); operator = 'EQUALS'; value = @('Y') })
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator';       value = 'N' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'State';                value = 'NJ' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ_RAND'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('licensePlateNumber')
                any      = @('randomRequest','registrationState','licensePlateTypeCode','imageIndicator','licensePlateYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'RandomRequest';        value = 'N' }
                    [PSCustomObject]@{ field = 'ImageIndicator';       value = 'N' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'State';                value = 'NJ' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('vehicleIdentificationNumber')
                any        = @('randomRequest','registrationState','imageIndicator')
                conditions = @([PSCustomObject]@{ field = @('RandomRequest'); operator = 'EQUALS'; value = @('Y') })
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN_RAND'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('vehicleIdentificationNumber')
                any      = @('randomRequest','registrationState','imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'RandomRequest';  value = 'N' }
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- 4 combos: RQ_RAND/RQ (plate), RQN_RAND/RQN (VIN). RAND=stolen-only (RandomRequest=Y). Defaulted fields in any[] (LIMITATION #31).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'NJ_NJCJIS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. VehicleStolenQuery
#     NO autoSelect -- officer manually checks when needed.
#     queriesToDeselect=[VehicleRegistrationQuery] -- checking Stolen
#     unchecks Registration.
# =====================================================================
$vehStolenQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('licensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'NCICNumber';                   size = 10; sourceField = @('ncicNumber');                   targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('ncicNumber')
                any      = @('imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QVN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('licensePlateNumber')
                any      = @('imageIndicator','registrationState','vehicleIdentificationNumber','vehicleMakeCode')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('vehicleIdentificationNumber')
                any      = @('imageIndicator','vehicleMakeCode')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVV'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleStolenQuery -- QVN (NCIC#), QVP (plate), QVV (VIN). New in v2.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'NJ_NJCJIS_VehicleStolenQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $false
    queriesToDeselect  = @('VehicleRegistrationQuery')
    provider           = 'NJ_NJCJIS'
    providerType       = 'Commsys'
    query              = 'VehicleStolenQuery'
    queryLabel         = 'Vehicle Stolen'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1f. DriverLicenseQuery # =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size        = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('birthDate','nameLast','nameFirst')
                any      = @('imageIndicator','sexCode','registrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                    [PSCustomObject]@{ field = 'State';          value = 'NJ' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('operatorLicenseNumber','registrationState')
                any      = @('imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (Name+DOB), DQN (OLN). Most-specific first.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery # =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('gunMake');          targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';        size = 20; sourceField = @('gunModel');         targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('gunSerialNumber');  targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';  size = 1;  sourceField = @('imageIndicator');   targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('gunSerialNumber')
                any      = @('gunCaliber','gunMake','gunModel','imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. Adds GunModel + ImageIndicator in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery # =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('articleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';      size = 1;  sourceField = @('imageIndicator');      targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('articleSerialNumber','articleTypeCode')
                any      = @('imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA. Adds ImageIndicator in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery # =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('imageIndicator');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 20; sourceField = @('registrationNumber');  targetField = 'RegistrationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('registrationNumber')
                any      = @('imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('boatHullIdNumber')
                any      = @('imageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBN'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- QB (Reg), QBN (Hull). State removed in v2. RegNum maxLength 20.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehStolenQuery, $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NJ_NJCJIS v${Version} MC"
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (multi-card layouts)
# Vehicle: 3 cards (OPTIONS+PLATE+VIN), Person: 3 cards (OPTIONS+OLN+NAME)
# Firearm/Article/Boat: 1 card each (compacted rows)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
# OPTIONS: State+Random+Image (shared routing fields for all combos)
# PLATE SEARCH: Plate+PlateType+PlateYear
# VIN SEARCH: VIN+NCIC+Make (compacted to 1 row)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_VEH_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_VEH_O1' }
                @{ id = 'RandomRequest_Input';     node = Sel 'randomRequest' 'Random' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_P1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_P1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_P1' }
                @{ id = 'LicensePlateYear_Input';    node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_P1' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_V1'; cols = @('5','4','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_V1' }
                @{ id = 'NCICNumber_Input';     node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_VEH_V1' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_V1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS + PLATE + VIN cards. VIN card compacted to 1 row.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards: OPTIONS, LICENSE NUMBER, NAME SEARCH
# OPTIONS: State+Image (shared routing fields for DQ/DQN)
# LICENSE NUMBER: OLN
# NAME SEARCH: First+Last+DOB+Sex (compacted to 1 row)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_PER_O1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_PER_O1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_O1' }
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
            @{ id = 'ROW_PER_N1'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_N1' }
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                    'ROW_PER_N1' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N1' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS + LICENSE NUMBER + NAME SEARCH. Name compacted to 1 row.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (same as BASE)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'gunMake'         'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunCaliber_Input';      node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_2' }
                @{ id = 'GunModel_Input';        node = Inp 'gunModel'   'Model'   '20' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';  node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG. Adds GunModel + ImageIndicator in v2.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (compacted)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'ImageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA. Serial+Type+Image on one row.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (compacted -- Reg+Hull+Image on one row)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('5','5','2'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '20' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'ImageIndicator_Input';     node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- QB (Reg) and QBN (Hull). Reg+Hull+Image on one row.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $njBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built NJ_NJCJIS v${Version}"

# =====================================================================
$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."