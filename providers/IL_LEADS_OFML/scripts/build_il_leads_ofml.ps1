# build_il_leads_ofml.ps1  -- IL_LEADS_OFML (galvanized v2.0, single-JSON native PascalCase)
# MC variant: PascalCase fieldIds, multi-card layout, no Patch 8 (CAD rename).
# Phase 2 multi-card. No cross-entity combos. No DriverHistoryQuery.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# IL-SPECIFIC:
#   No CaRequestPurposeCode
#   No DriverHistoryQuery (not in IL metadata)
#   ImageIndicator: Vehicle=N, Person=Y, Firearm=Y, Boat=Y
#   Date format: MMddyyyy (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','MMddyyyy'])
#   State initialValue=IL (safe for this provider)
#   CDCName in AUTH
#   RelatedHitSearchIndicator hidden on most entities
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_il_leads_ofml_mc.ps1 [-Version X.X]

$ErrorActionPreference = "Stop"
$Version     = '2.0'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\IL_LEADS_OFML_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; IL LEADS, 5 basic queries, no DH,
# OOS RegistrationState EXISTS/NOT_EXISTS routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : Z2.P (OOS plate), Z2.V (OOS VIN), Z5 (in-state plate)
#   DriverLicenseQuery       : Z2.N (Name+DOB), Z2.O (OLN)
#   GunQuery                 : QG (serial)
#   ArticleSingleQuery       : QA (serial+type)
#   BoatQuery                : BQ.H (hull), BQ.R (reg)

# =====================================================================
# BUNDLE 1: IL_LEADS_OFML PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'IL_LEADS_OFML' `
    -ExtraAttributes @([PSCustomObject]@{ name='CDCName'; size=10; sourceField=@('CDCName'); targetField='CDCName' }) `
    -ExtraAny @('CDCName')

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'IL_LEADS_OFML'

$qmf = Build-Qmf -ProviderName 'IL_LEADS_OFML'

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase
# XML v2: 3 combos: Z2 plate (OOS), Z2 VIN (OOS), Z5 plate (in-state)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';   size = 1;  sourceField = @('relatedHitSearchIndicator');   targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS plate (most specific -- requires State in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'Z2.P'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','VehicleMakeCode','vehicleYear','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'Z2.V'
            state                 = 'In/Out'
        }
        # In-state plate (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'Z5'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- Z5 (in-state plate), Z2 (OOS plate/VIN). MC PascalCase.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'IL_LEADS_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'IL_LEADS_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase
# XML v2: 2 combos: Z2 Name+DOB, Z2 OLN
# No DH in IL metadata
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name+DOB
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BirthDate','NameLast','NameFirst'); any = @('ImageIndicator','relatedHitSearchIndicator','SexCode')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'Z2.N'
            state                 = 'In/Out'
        }
        # OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'Z2.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- Z2 (Name+DOB, OLN). IL DMV driver license query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery -- PascalCase
# XML v2: 1 combo: QG serial
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                   size = 4;  sourceField = @('gunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                      size = 3;  sourceField = @('firearmMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';              size = 20; sourceField = @('serialNumber');              targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';    size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('serialNumber'); any = @('gunCaliber','firearmMake','ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). IL NCIC firearm query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery -- PascalCase
# XML v4: 1 combo: QA serial+type (OAN in any[])
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');    targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber'); targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @('ownerAppliedNumber') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). IL article inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery -- PascalCase
# XML v4: 2 combos: BQ hull, BQ reg
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 20; sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (hull, reg). IL boat inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# Build the provider bundle with 5 basic QIDMs
$ilBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery,
        $dlQuery,
        $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for IL_LEADS_OFML v${Version} MC (5 basic queries)"
    name           = 'IL_LEADS_OFML'
    type           = 'BUNDLE'
    provider       = 'IL_LEADS_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  1 card  (FIREARM SEARCH -- serial + make + caliber + image)
# Article:  1 card  (ARTICLE SEARCH -- serial + OAN + type)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REGISTRATION SEARCH)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState,
# ImageIndicator, etc.) live on a separate card to avoid duplicate fieldId
# across cards (= ISE).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards (MC)
# OPTIONS: RegistrationState + LicensePlateTypeCode + LicensePlateYear + ImageIndicator
# PLATE SEARCH: LicensePlateNumber
# VIN SEARCH: VehicleIdentificationNumber + VehicleMakeCode + VehicleYear
# Hidden: RelatedHitSearchIndicator
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for IL)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (optional)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_OPT_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (optional)' '4' 'ROW_VEH_OPT_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_OPT_2'; cols = @('4'); fields = @(
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_OPT_2' }
            )}
            @{ id = 'ROW_VEH_OPT_H'; cols = @('4'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (Y for NCIC stolen check)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_VEH_OPT_H' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + PlateType + PlateYear + Image) + PLATE (Z5/Z2.P) + VIN (Z2.V)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC)
# OPTIONS: RegistrationState + SexCode + ImageIndicator + RaceCode
# OLN SEARCH: OperatorLicenseNumber
# NAME SEARCH: NameFirst + NameLast + BirthDate
# Hidden: RelatedHitSearchIndicator
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for IL)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'SexCode_Input';           node = Sel 'SexCode'           'Sex (optional)'   @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator'    'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
            @{ id = 'ROW_PER_OPT_2'; cols = @('4'); fields = @(
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_OPT_2' }
            )}
            @{ id = 'ROW_PER_OPT_H'; cols = @('4'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (Y for NCIC stolen check)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_PER_OPT_H' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('12'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt 'BirthDate' 'Date of Birth' 'ROW_PER_NAME_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Sex + Image + Race) + OLN (Z2.O) + NAME (Z2.N)'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (MC)
# Single card: SerialNumber + FirearmMake + GunCaliber + ImageIndicator
# Hidden: RelatedHitSearchIndicator
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';     node = Sel 'firearmMake'    'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'ImageIndicator_Input';  node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('12'); fields = @(
                @{ id = 'GunCaliber_Input'; node = Sel 'gunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_H'; cols = @('4'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (Y for NCIC stolen check)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_GUN_H' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: FIREARM SEARCH (QG serial). 1 card with hidden RelatedHitSearch.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (MC)
# Single card: SerialNumber + OwnerAppliedNumber + ArticleTypeCode
# No ImageIndicator, no RelatedHitSearchIndicator (not in Article QIDM)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'        '20' 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number (optional)' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';    node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: ARTICLE SEARCH (QA serial+type). 1 card.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 3 cards (MC)
# OPTIONS: RegistrationState + ImageIndicator + RelatedHitSearchIndicator
# HULL SEARCH: BoatHullIdNumber
# REGISTRATION SEARCH: RegistrationNumber
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for IL)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_OPT_1' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search (Y for NCIC stolen check)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_BOA_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '20' 'ROW_BOA_REG_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Image + RelatedHitSearch) + HULL (BQ.H) + REG (BQ.R)'
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
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ilBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built IL_LEADS_OFML v${Version}" `
    -Version $Version