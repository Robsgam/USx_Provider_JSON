# build_md_meters.ps1  -- MD_METERS (galvanized v2.0, single-JSON native PascalCase)
# Consolidated legacy BASE+MC -> one versioned JSON. Native PascalCase USx CAD fieldIds
# (Build-RmsBundle -SkipRace -PascalCaseUsxFields). Phase 2 multi-card. DriverHistoryQuery
# uses DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) on separate VISIBLE
# DH cards + queriesToDeselect. OOS RegistrationState EXISTS/NOT_EXISTS routing gates +
# identifier-priority guardrails. CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# MD-SPECIFIC:
#   No CaRequestPurposeCode -- not a CA system.
#   No Attention attribute in DH metadata -- so no hidden attention feeder (MD has ZERO hidden fields).
#   ImageIndicator present  -- Vehicle=N, Person(DL/DH)=Y, Boat=N.
#   No cross-entity combos. No VehicleStolenQuery / RandomRequest in metadata.
#   State: no initialValue (LIMITATION #30, clean In/Out routing).
#   Date format: MMddyyyy (size=8, standard NCIC).
#   Name: composite Last,First via FormatStringRuleHandler.
#   RaceCode: camelCase form field (raceCode) feeding CommSys DL only (RMS is -SkipRace);
#             dropdown NIBRS_RACE/NIBRS. YearsPastViolationsWanted dropped (only fed the
#             unbuilt ZDRV DL combo -- orphaned-field removal, per TX precedent).
#   Gun: single ZGUN combo, all 3 fields mandatory (Serial+Make+Caliber). GunSerialNumber
#        sourceField 'serialNumber' (CAD populates camelCase serialNumber).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_md_meters.ps1

$ErrorActionPreference = "Stop"
$Version     = '2.2'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\MD_METERS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; MD METERS 6 basic queries, DH-suffix,
# OOS RegistrationState EXISTS/NOT_EXISTS routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : ZLRG.P (OOS plate), ZVEH.P (in-state plate), ZLRG.V (OOS VIN), ZVEH.V (in-state VIN)
#   DriverLicenseQuery       : ZWAR.O/ZWAR.N (warrant OLN/Name), ZLDR.N/ZLDR.O (DL Name/OLN)
#   DriverHistoryQuery       : ZDRV.N (Name+DOB+Sex), ZDRV.O (OLN) -- in-state only, DH-suffix
#   GunQuery                 : ZGUN (serial+make+caliber, all mandatory)
#   ArticleSingleQuery       : ZART (serial+type)
#   BoatQuery                : ZBOA.H (hull), ZBOA.R (reg)

# =====================================================================
# BUNDLE 1: MD_METERS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'MD_METERS'

$results = Build-ProviderQrdm -ProviderName 'MD_METERS'

$qmf = Build-Qmf -ProviderName 'MD_METERS'

# =====================================================================
# VehicleRegistrationQuery -- ZLRG (OOS plate/VIN, State in any[]), ZVEH (in-state plate/VIN)
# Plate>VIN guardrail (VIN combos: LicensePlateNumber NOT_EXISTS).
# OOS gate: ZLRG = RegistrationState EXISTS, ZVEH = RegistrationState NOT_EXISTS.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 24; sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        # ZLRG.P -- OOS plate (Plate+Type+Year set, State in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('RegistrationState','ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }, [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ZLRG.P'
            state                 = 'In/Out'
        }
        # ZLRG.V -- OOS VIN (State in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('RegistrationState','ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ZLRG.V'
            state                 = 'In/Out'
        }
        # ZVEH.V -- in-state VIN (VehicleMakeCode in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('VehicleMakeCode','ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ZVEH.V'
            state                 = 'In/Out'
        }
        # ZVEH.P -- in-state plate (plate only, fallback)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ZVEH.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ZLRG.P/ZLRG.V (OOS), ZVEH.P/ZVEH.V (in-state). OOS EXISTS/NOT_EXISTS + Plate>VIN guardrail.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'MD_METERS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'MD_METERS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# DriverLicenseQuery -- ZWAR (warrant OLN/Name, RaceCode required), ZLDR (DL Name/OLN)
# OLN>Name guardrail (Name combos: OperatorLicenseNumber NOT_EXISTS).
# ZWAR vs ZLDR isolation: warrant requires RaceCode (RaceCode NOT_EXISTS on ZLDR combos).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';                size = 1;  sourceField = @('ImageIndicator');                targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseExpirationYear'; size = 4;  sourceField = @('OperatorLicenseExpirationYear'); targetField = 'OperatorLicenseExpirationYear' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';         size = 20; sourceField = @('OperatorLicenseNumber');         targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                      size = 1;  sourceField = @('raceCode');                      targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode';                       size = 1;  sourceField = @('SexCode');                       targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # ZWAR.O -- warrant OLN search (Name+ExpYear+OLN+Race+Sex set, most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','OperatorLicenseExpirationYear','OperatorLicenseNumber','raceCode','SexCode'); any = @('RegistrationState','ImageIndicator','NameMiddle','NameSuffix')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('raceCode'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZWAR.O'
            state                 = 'In/Out'
        }
        # ZWAR.N -- warrant Name search (DOB+Name+Race+Sex set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BirthDate','NameLast','NameFirst','raceCode','SexCode'); any = @('ImageIndicator','NameMiddle','NameSuffix')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @(
                    [PSCustomObject]@{ field = @('raceCode');              operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ZWAR.N'
            state                 = 'In/Out'
        }
        # ZLDR.N -- DL by Name+DOB+Sex (no Race -> distinguishes from ZWAR.N)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @('RegistrationState','ImageIndicator','NameMiddle','NameSuffix')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('raceCode');              operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ZLDR.N'
            state                 = 'In/Out'
        }
        # ZLDR.O -- DL by OLN (no Race -> distinguishes from ZWAR.O)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('RegistrationState','ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('raceCode'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZLDR.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- ZWAR.O/ZWAR.N (warrant), ZLDR.N/ZLDR.O (DL). OLN>Name + RaceCode isolation guardrails.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# DriverHistoryQuery -- ZDRV.N (Name+DOB+Sex), ZDRV.O (OLN). In-state only.
# DH-suffix fieldIds isolate from DL field pool (AP #14). No Attention (not in metadata).
# OLN>Name guardrail (ZDRV.N: OperatorLicenseNumberDH NOT_EXISTS).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');           targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        # ZDRV.N -- DH by Name+DOB+Sex (Name before OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH'); any = @('ImageIndicator','NameMiddleDH','NameSuffixDH')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ZDRV.N'
            state                 = 'In'
        }
        # ZDRV.O -- DH by OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH'); any = @('ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZDRV.O'
            state                 = 'In'
        }
    )
    description     = 'DriverHistoryQuery -- ZDRV.N (Name+DOB+Sex), ZDRV.O (OLN). DH-suffix fields, in-state only. OLN>Name guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# GunQuery -- ZGUN (serial+make+caliber, all mandatory)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');   targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('firearmMake');  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunCaliber','firearmMake','serialNumber'); any = @() }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'ZGUN'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- ZGUN (serial+make+caliber). All fields mandatory.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# ArticleSingleQuery -- ZART (serial+type, both mandatory)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');    targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'ZART'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- ZART (serial+type).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# BoatQuery -- ZBOA.H (hull), ZBOA.R (reg). No State field in metadata.
# Hull>Reg guardrail (ZBOA.R: BoatHullIdNumber NOT_EXISTS).
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('ImageIndicator');     targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
    )
    combinations = @(
        # ZBOA.H -- Hull (Reg in any[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('RegistrationNumber','ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ZBOA.H'
            state                 = 'In/Out'
        }
        # ZBOA.R -- Reg (Hull>Reg guardrail: BoatHullIdNumber NOT_EXISTS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('ImageIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ZBOA.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- ZBOA.H (hull), ZBOA.R (reg). Hull>Reg guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$mdBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for MD_METERS v${Version} -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), DH-suffix, OOS EXISTS/NOT_EXISTS gates + identifier-priority guardrails"
    name           = 'MD_METERS'
    type           = 'BUNDLE'
    provider       = 'MD_METERS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- 5 QIFs, multi-card layouts
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   5 cards (OPTIONS + DL-OLN + DL-NAME + DH-OLN + DH-NAME) -- DH-suffix visible cards
# Firearm:  1 card  (ZGUN -- single combo, all mandatory)
# Article:  1 card  (ZART -- single combo)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REG SEARCH)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card (v2.2, collapsed from 3: OPTIONS/PLATE/VIN)
# LABEL-OVERRIDE: LicensePlateTypeCode -- prefilled 'PC', bare label per BUILD_RULES 11
# LABEL-OVERRIDE: LicensePlateYear -- prefilled current year, bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH BY PLATE, OR VIN'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for MD)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_3' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card: Plate (ZLRG.P/ZVEH.P) + VIN (ZLRG.V/ZVEH.V). Blank State routes the in-state MD keyRef.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 2 cards (v2.2, collapsed from 5)
# The DL card carries State + NCIC Image as SHARED CONTEXT; the DH combinations read
# ImageIndicator too (one form, one field pool -- cards are visual grouping only).
# LABEL-OVERRIDE: NameMiddle -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameSuffix -- bare "Suffix", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameMiddleDH -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix", DEX-1284 lean pass (any[] optional, DH pool)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input';         node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'OperatorLicenseExpirationYear_Input'; node = Inp 'OperatorLicenseExpirationYear' 'License Expiration Year (warrant search)' '4' 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '5'  'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
                @{ id = 'RaceCode_Input';  node = Sel 'raceCode' 'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
            @{ id = 'ROW_PER_DL_4'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for MD)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_4' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DL_4' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name'  '30' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'   '30' 'ROW_PER_DH_2' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'Middle Name' '30' 'ROW_PER_DH_2' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix'      '5'  'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth' 'ROW_PER_DH_3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards: DL (ZWAR.O/ZLDR.O OLN, ZWAR.N/ZLDR.N name) + DH (ZDRV.O/ZDRV.N). DH-suffix fieldIds isolate the DH pool.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (ZGUN: serial + make + caliber, all three MANDATORY)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL, MAKE AND CALIBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'gunCaliber'   'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- 1 card: ZGUN (serial + make + caliber, all mandatory).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (ZART: serial + type)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL AND TYPE'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- 1 card: ZART (serial + type).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (v2.2, collapsed from 3). Hull (ZBOA.H) leads Registration (ZBOA.R).
# MD BoatQuery metadata defines NO State field, so there is no State control here.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY HULL, OR REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'ImageIndicator_Input';     node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card: Hull (ZBOA.H) + Registration (ZBOA.R).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — PascalCase USx form-fed refs, -SkipRace)
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $mdBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built MD_METERS v${Version}" `
    -Version $Version
