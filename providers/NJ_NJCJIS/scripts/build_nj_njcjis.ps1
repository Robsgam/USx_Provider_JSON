# build_nj_njcjis.ps1  -- NJ_NJCJIS canonical build (single JSON, multi-card)
# =====================================================================
# CANONICAL MAINLINE BUILD. Produces providers/NJ_NJCJIS/NJ_NJCJIS.json.
# Design (promoted to mainline 2026-06-17, v4.0):
#   1. VehicleStolenQuery (QV) NOT built -- USER-APPROVED SKIP of the 3 metadata
#      QV combos. NJCJIS runs the QV stolen check automatically state-side with
#      registration queries; its response tags are still data-mined via the QRDM.
#      Vehicle layout therefore omits ncicNumber + vehicleMakeCode (stolen-only).
#   2. VehicleRegistrationQuery = 2 combos (RQ plate, RQN VIN). RandomRequest is
#      user-controlled in any[] (form default N); the inert poisoned-array
#      RandomRequest=Y conditions + synthetic RQ_RAND/RQN_RAND combos were removed
#      (behavior-preserving; QIDM_REFERENCE Sec 2a; cf. FL v5.0).
#   3. RMS handler arguments are populated by the fixed _R helper in
#      tools/_build_rms_bundle.ps1 (the $args reserved-name collision that dropped
#      them was repaired 2026-06-17; matches the HIDLE engineering baseline).
#   4. USx CAD-integration field names are recased to PascalCase at the end of the
#      build (see PASCALCASE RECASE block); Mark43/RMS internal keys stay camelCase.
# =====================================================================
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_njcjis.ps1

param(
    [string]$Version = "4.0"
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

# QUERYRESULTDATAMAPPING (from KB specs) -- kept intact (QV response tags still
# data-mined if the state auto-runs QV with registration queries)
$results = Build-ProviderQrdm -ProviderName 'NJ_NJCJIS'

$qmf = Build-Qmf -ProviderName 'NJ_NJCJIS'

# =====================================================================
# 1d. VehicleRegistrationQuery
#     autoSelect=true, NO queriesToDeselect.
#     Defaulted fields in any[] per LIMITATION #31.
#     2 combos: RQ (plate), RQN (VIN). RandomRequest is user-controlled (any[],
#     form default N) and routed server-side by its value -- it does NOT need
#     separate combos. The earlier synthetic RQ_RAND/RQN_RAND combos used
#     value-comparison conditions (RandomRequest EQUALS Y) which the platform
#     treats as INERT (poisoned-array, QIDM_REFERENCE Sec 2a): the conditions
#     were disabled, so those combos already fired unconditioned and duplicated
#     RQ/RQN. Removed (behavior-preserving). Cf. FL v5.0 poisoned-array cleanup.
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
    description        = 'VehicleRegistrationQuery -- 2 combos: RQ (plate), RQN (VIN). RandomRequest user-controlled in any[] (form default N), default N in defaults[] for CAD. Poisoned-array RandomRequest=Y conditions removed (inert; QIDM_REFERENCE Sec 2a) and synthetic RQ_RAND/RQN_RAND combos collapsed -- behavior-preserving since conditions were already disabled.'
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
# 1e. VehicleStolenQuery -- BRANCH DELTA: REMOVED ENTIRELY.
#     QVN/QVP/QVV (metadata keyRef 'QV', 3 combos) are a USER-APPROVED SKIP in
#     this variant (2026-06-10): premise is the state runs QV automatically
#     with registration queries. No JSON-side stolen query, no Stolen checkbox.
# =====================================================================

# =====================================================================
# 1f. DriverLicenseQuery -- UNCHANGED from mainline
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DQ' for both combos (Name+DOB and OLN); synthetic label 'DQN'
# (N=OLN path) invented for platform routing only. NOT a real NJCJIS transaction code.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
# =====================================================================
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
# 1g. GunQuery -- UNCHANGED from mainline
# =====================================================================
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
# 1h. ArticleSingleQuery -- UNCHANGED from mainline
# =====================================================================
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
# 1i. BoatQuery -- UNCHANGED from mainline
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QB' for both combos (Reg# and Hull ID); synthetic label 'QBN'
# (N=Hull path) invented for platform routing only. NOT a real NJCJIS transaction code.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
# =====================================================================
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

# BRANCH DELTA: $vehStolenQuery omitted from configurations
$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NJ_NJCJIS v${Version} MC"
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (multi-card layouts)
# BRANCH DELTA -- Vehicle: 3 cards, VIN card = VIN only (ncicNumber and
# vehicleMakeCode removed -- both served ONLY the deleted stolen query)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
# OPTIONS: State+Random+Image (shared routing fields for all combos)
# PLATE SEARCH: Plate+PlateType+PlateYear
# VIN SEARCH: VIN only (BRANCH DELTA)
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
            @{ id = 'ROW_VEH_V1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_V1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- RANDOM-REMOVED branch: OPTIONS + PLATE + VIN cards. VehicleStolenQuery eliminated; ncicNumber/vehicleMakeCode removed (stolen-only fields).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- UNCHANGED: 3 cards: OPTIONS, LICENSE NUMBER, NAME SEARCH
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
            @{ id = 'ROW_PER_N1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                    'ROW_PER_N2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N2' }
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
# Firearm -- UNCHANGED: 1 card
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
# Article -- UNCHANGED: 1 card
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
# Boat -- UNCHANGED: 1 card
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
# Unchanged: RMS Vehicle uses licensePlateNumber/VIN/registrationState only.
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $njBundle, $rmsBundle)
}

# =====================================================================
# PASCALCASE RECASE -- USx CAD-integration field names only
# =====================================================================
# Recase ONLY the 22 USx form-field tokens (the names CAD/OnScene populate)
# to PascalCase, across all 3 bundles. Mark43/RMS internal keys (firstName,
# vinNumber, dlNumber, *AttrDetail.id, nameAttributes, ...), NJCJIS response
# field names, keyReference labels, targetFields and attribute names are left
# exactly as-is. This reproduces the casing pattern in Cringer's reference JSON
# (USx fields = PascalCase; Mark43 plumbing = camelCase). The earlier
# build_nj_njcjis_pascal.ps1 post-transform is folded in here so the build is a
# single reproducible step. See knowledge-base + project notes on PascalCase.
$usxRenames = @{
    'licensePlateNumber'          = 'LicensePlateNumber'
    'licensePlateTypeCode'        = 'LicensePlateTypeCode'
    'licensePlateYear'            = 'LicensePlateYear'
    'randomRequest'               = 'RandomRequest'
    'registrationState'           = 'RegistrationState'
    'imageIndicator'              = 'ImageIndicator'
    'vehicleIdentificationNumber' = 'VehicleIdentificationNumber'
    'ncicNumber'                  = 'NCICNumber'
    'vehicleMakeCode'             = 'VehicleMakeCode'
    'nameFirst'                   = 'NameFirst'
    'nameLast'                    = 'NameLast'
    'birthDate'                   = 'BirthDate'
    'sexCode'                     = 'SexCode'
    'operatorLicenseNumber'       = 'OperatorLicenseNumber'
    'gunSerialNumber'             = 'GunSerialNumber'
    'gunMake'                     = 'GunMake'
    'gunCaliber'                  = 'GunCaliber'
    'gunModel'                    = 'GunModel'
    'articleSerialNumber'         = 'ArticleSerialNumber'
    'articleTypeCode'             = 'ArticleTypeCode'
    'registrationNumber'          = 'RegistrationNumber'
    'boatHullIdNumber'            = 'BoatHullIdNumber'
}
function Convert-UsxCasing($node, $parentProp) {
    if ($null -eq $node) { return $null }
    if ($node -is [string]) {
        if ($parentProp -eq 'keyReference') { return $node }   # platform-internal labels
        if ($usxRenames.ContainsKey($node) -and $usxRenames[$node] -cne $node) { return $usxRenames[$node] }
        return $node
    }
    if ($node -is [array]) {
        return ,@($node | ForEach-Object { Convert-UsxCasing $_ $parentProp })
    }
    if ($node -is [PSCustomObject]) {
        foreach ($p in $node.PSObject.Properties) { $p.Value = Convert-UsxCasing $p.Value $p.Name }
        return $node
    }
    return $node
}
$output = Convert-UsxCasing $output $null

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built NJ_NJCJIS v${Version} (VehStolenRemoved mainline, PascalCase USx fields, restored RMS args)"

Write-Host ""
Write-Host "Build complete -- NJ_NJCJIS v${Version}: VehStolenRemoved + PascalCase USx fields + restored RMS handler args."
