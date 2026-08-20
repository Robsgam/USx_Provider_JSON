# build_nm_nmlets_ofml.ps1  -- NM_NMLETS_OFML (galvanized v2.0, single-JSON native PascalCase)
# Consolidated legacy BASE+MC -> one versioned JSON. Native PascalCase USx CAD fieldIds
# (Build-RmsBundle -PascalCaseUsxFields). Phase 2 multi-card. DriverHistoryQuery uses
# DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) on separate VISIBLE DH
# cards + queriesToDeselect. Existence-only OOS/routing gates + identifier-priority guardrails.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# NM-SPECIFIC:
#   No CaRequestPurposeCode -- not a CA system.
#   Attention: DL ONLY, and this line was STALE until v2.3 -- it used to read "DROPPED entirely
#     ... NM has none", which is FALSE and cost a wrong edit during the v2.3 collapse (I moved the
#     hidden feeder to the DH card on the strength of it). The truth: DriverLicenseQuery DOES carry
#     an Attention attribute with CommsysGetLastNameFirstNameInitialRuleHandler, in the any[] of
#     BOTH DL.NAME and DL.OLN, fed by a hidden control on the DRIVER LICENSE card.
#     DriverHistoryQuery genuinely has none -- that half of the old note was right.
#   ImageIndicator present on DriverLicenseQuery ONLY (Person=Y). NOT on Vehicle/Boat/DH
#     (not in their metadata).
#   State: no initialValue (LIMITATION #30). Vehicle RQ(Nlets)/QV(NCIC) AND Boat BQ(Nlets)/
#     QB(NCIC) both routed by RegistrationState EXISTS/NOT_EXISTS (Nlets registration needs a
#     destination state; NCIC is national/stateless). Label "State (leave blank for NM)".
#   Date format: MMddyyyy (size=8, Date fields via CommsysParseDateRuleHandler).
#   Name: composite Last,First,Middle,Suffix via FormatStringRuleHandler (AP #15: arguments = 3
#     separators for 4 sourceFields). Middle+Suffix added v2.3 -- audit_name_components had 4 C1
#     NO-CONTROL findings, metadata defines them on both DL and DH and the officer could not enter them.
#   GunModel IS a USx 22-token -> PascalCase form fieldId 'GunModel'. serialNumber/firearmMake/
#     gunCaliber stay camelCase (per galvanization casing rule).
#   RaceCode: camelCase form field (raceCode) on the DRIVER LICENSE card feeding RMS person search
#     (NM is NOT -SkipRace). DH keeps its own raceCodeDH + purposeCodeDH optional any[] fields.
#   ArticleTypeCode dropdown: codeTypeSource='CA_CLETS' (NCIC gives empty dropdown, AP #-code-type).
#   VehicleMakeCode: FormSelect VEHICLE_MAKE dropdown (hard gate -- never FormInput).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nm_nmlets_ofml.ps1
$ErrorActionPreference = "Stop"
$Version     = '2.5'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\NM_NMLETS_OFML_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; NM_NMLETS_OFML 6 basic queries,
# DH-suffix, existence-only routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : RQ.P (Nlets plate+type+year), RQ.V (Nlets VIN+make+year), QV.V (NCIC VIN+make), QV.P (NCIC plate)
#   DriverLicenseQuery       : DL.NAME (Name+DOB+Sex), DL.OLN (OLN)
#   DriverHistoryQuery       : KQ.N (Name+DOB+Sex), KQ.O (OLN) -- DH-suffix fieldIds
#   GunQuery                 : QG (serial + optional caliber/make/model)
#   ArticleSingleQuery       : QA (serial+type)
#   BoatQuery                : BQ.H (Nlets hull+state), QB.H (NCIC hull), BQ.R (Nlets reg+state), QB.R (NCIC reg)

# =====================================================================
# BUNDLE 1: NM_NMLETS_OFML PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'NM_NMLETS_OFML'

$results = Build-ProviderQrdm -ProviderName 'NM_NMLETS_OFML'

$qmf = Build-Qmf -ProviderName 'NM_NMLETS_OFML'

# =====================================================================
# VehicleRegistrationQuery -- RQ (Nlets), QV (NCIC). Plate>VIN guardrail (VIN combos:
# LicensePlateNumber NOT_EXISTS). RQ vs QV routed by RegistrationState EXISTS/NOT_EXISTS
# (Nlets registration needs a destination state; NCIC is national).
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # RQ.P -- Nlets plate (plate+type+year), fires when State present
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # RQ.V -- Nlets VIN (VIN+make+year). Plate>VIN + fires when State present
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber','VehicleMakeCode','vehicleYear'); any = @('RegistrationState')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');   operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # QV.V -- NCIC VIN (VIN+make). Plate>VIN + no State
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber','VehicleMakeCode'); any = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');   operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        # QV.P -- NCIC plate (plate only), fires when State absent
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ.P/RQ.V (Nlets), QV.V/QV.P (NCIC). State-existence routing + Plate>VIN guardrail.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'NM_NMLETS_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'NM_NMLETS_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# DriverLicenseQuery -- DL.NAME (Name+DOB+Sex), DL.OLN (OLN). OLN>Name guardrail
# (DL.NAME: OperatorLicenseNumber NOT_EXISTS). ImageIndicator optional (default Y).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCode'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        # ATTENTION -- the ONE standing visible-first exception (BUILD_RULES, directive 2026-06-22):
        # auto-populated by the handler, NO visible control, scoped ONLY to a query whose metadata
        # lists Attention. NM's DriverLicenseQuery metadata puts it INSIDE <Set>, so it is mandatory
        # here; it rides in any[] because the handler supplies it at send time and a set[] membership
        # would demand a form value that never exists, making both DL combos unsatisfiable.
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        }
    )
    combinations = @(
        # DL.NAME: Name+DOB+Sex (more specific -- Name before OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode','purposeCode'); any = @('RegistrationState','ImageIndicator','Attention','NameMiddle','NameSuffix')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'purposeCode'; value = 'C' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DL.NAME'
            state                 = 'In/Out'
        }
        # DL.OLN: OLN (less specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber','purposeCode'); any = @('RegistrationState','ImageIndicator','Attention')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'purposeCode'; value = 'C' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DL.OLN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DL.NAME (Name+DOB+Sex), DL.OLN (OLN). OLN>Name guardrail. ImageIndicator default Y.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# DriverHistoryQuery -- KQ.N (Name+DOB+Sex), KQ.O (OLN). DH-suffix fieldIds isolate from
# DL field pool (AP #14). OLN>Name guardrail (KQ.N: OperatorLicenseNumberDH NOT_EXISTS).
# PurposeCode + RaceCode kept as optional any[] (DH-suffix). No Attention (no handler -> dropped).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCodeDH'); targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.N: Name+DOB+Sex (Name before OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH'); any = @('purposeCodeDH','raceCodeDH','RegistrationState','NameMiddleDH','NameSuffixDH')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ.O: OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH'); any = @('purposeCodeDH','RegistrationState')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ.N (Name+DOB+Sex), KQ.O (OLN). DH-suffix fields. OLN>Name guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# GunQuery -- QG (serial required; caliber/make/model optional any[]). GunModel PascalCase (token).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');   targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 3;  sourceField = @('firearmMake');  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';        size = 11; sourceField = @('GunModel');     targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake','GunModel') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial; caliber/make/model optional). NCIC firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# ArticleSingleQuery -- QA (serial+type, both mandatory)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','articleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). NCIC article query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# BoatQuery -- BQ (Nlets, w/ State), QB (NCIC, no State). Hull>Reg guardrail (reg combos:
# BoatHullIdNumber NOT_EXISTS). QB vs BQ routed by RegistrationState EXISTS/NOT_EXISTS.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ.H -- Nlets hull (State present)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        # QB.H -- NCIC hull (no State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
        # BQ.R -- Nlets reg (State present). Hull>Reg guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('RegistrationState')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');   operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        # QB.R -- NCIC reg (no State). Hull>Reg guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');   operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.H/BQ.R (Nlets, State), QB.H/QB.R (NCIC). State-existence routing + Hull>Reg guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$nmBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NM_NMLETS_OFML v${Version} -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), DH-suffix, existence-only routing gates + identifier-priority guardrails"
    name           = 'NM_NMLETS_OFML'
    type           = 'BUNDLE'
    provider       = 'NM_NMLETS_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- 5 QIFs, multi-card layouts
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   5 cards (OPTIONS + DL-OLN + DL-NAME + DH-OLN + DH-NAME) -- DH-suffix visible cards
# Firearm:  1 card  (QG)
# Article:  1 card  (QA)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REG SEARCH)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card (COLLAPSED at v2.3 from 3: OPTIONS + PLATE SEARCH + VIN SEARCH)
#   audit_layout_flow L4: one card per entity, title enumerates the query paths.
#   The three cards said nothing the title cannot: OPTIONS held a single shared control
#   (State), and PLATE/VIN are the two identifier paths, which now lead their own rows.
#   L5 also fixed here -- Plate (maxLen 10) and VIN (20) each had a full 12-col row to
#   themselves and could not use the width.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = "VEHICLE SEARCH BY PLATE, `nOR BY VIN"
        rows  = @(
            # State is the 2nd field on the TOP line by operator directive (Rob 2026-08-20: "move state
            # to top line 2nd feild"), and it earns the position: on NM it is the ROUTING field for BOTH
            # vehicle paths -- RegistrationState EXISTS -> Nlets (RQ.P/RQ.V), NOT_EXISTS -> NCIC
            # (QV.P/QV.V). The officer's very first decision on this card is which network to hit, so
            # burying it on a third row under the identifiers had it backwards.
            @{ id = 'ROW_VEH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for NM)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 collapsed card: plate (RQ.P/QV.P) + VIN (RQ.V/QV.V), State routes Nlets-vs-NCIC'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# The four name components become any[]-only at v2.5 -- that IS the fix (they were composed into
# their Name attribute but in no combination pool, so an officer's middle name went nowhere), and it
# is also what makes CHECK 15 Rule 3 start asking for an "(optional)" qualifier the lean-label
# convention forbids. ONE TAG PER LINE, fieldId first, ' -- ' on the SAME line: verify_build matches
# '#\s*LABEL-OVERRIDE:\s*(\S+)\s*--\s*(.+?)$' per line, and a multi-field line registers NOTHING.
# LABEL-OVERRIDE: NameMiddle -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameSuffix -- bare "Suffix", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameMiddleDH -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: raceCodeDH -- bare "Race" per the DEX-1284 lean pass (any[] optional DH qualifier).
#   verify_build CHECK 15 asks for "(optional)" or a context hint on an any[]-only field. The lean-label
#   convention (BUILD_RULES Section 11 / usx-cosmetic Step 3b) strips "(optional)" suffixes portfolio-wide
#   and lets the CARD TITLE carry the query paths instead, so the WARN is the convention working as
#   designed, not a defect. Same override OH_LEADS records for firearmMake / gunCaliber / AddressCounty.
#   NOTE the asymmetry, which is correct and not an oversight: the DL-side raceCode does NOT warn,
#   because it is RMS-only and sits in no combination any[] -- CHECK 15's rule is scoped to any[]-only
#   fields, so only the DH twin trips it.
# Person -- 2 cards (COLLAPSED at v2.3 from 5: OPTIONS + DL-OLN + DL-NAME + DH-OLN + DH-NAME).
#   Person is the ONE entity legitimately at TWO cards: the DH-suffix fieldIds are a separate
#   field pool and that separation IS the isolation mechanism (usx-cosmetic L4).
# OPTIONS: State + Image + Race (Race feeds RMS person search; NM is NOT -SkipRace)
# DL-OLN: OperatorLicenseNumber
# DL-NAME: NameFirst + NameLast + BirthDate + SexCode
# DH-OLN: OperatorLicenseNumberDH + PurposeCode
# DH-NAME: NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH + RaceCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = "DRIVER LICENSE SEARCH BY OLN, `nOR BY NAME"
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NM)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DL_1' }
            )}
            # All four name components in ONE row, First then Last (usx-cosmetic L8). The WIRE stays
            # LAST-first via the composite FormatStringRuleHandler -- form order and sourceField order
            # are independent. Middle + Suffix ADDED at v2.3: audit_name_components reported 4 C1
            # NO-CONTROL findings (Middle and Suffix on BOTH DriverLicenseQuery and DriverHistoryQuery)
            # -- the metadata defines them and the officer could not enter them.
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '10' 'ROW_PER_DL_2' }
            )}
            # Race is the 3rd line, immediately AFTER Sex, by operator directive (Rob 2026-08-20:
            # "for person ... move race to 3rd line after sex"). This SUPERSEDES the v2.3 placement
            # that parked it alone on a 4th row -- see the L9 override recorded in BUILD_NOTES.
            @{ id = 'ROW_PER_DL_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
                @{ id = 'RaceCode_Input';  node = Sel 'raceCode'  'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
                @{ id = 'PurposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_DL_3' @{ initialValue = 'C' } }
            )}
            # HIDDEN Attention feeder, LAST row on THIS card (L3). It belongs to the DRIVER LICENSE pool,
            # not DH: Attention is an attribute of DriverLicenseQuery only, carried in the any[] of BOTH
            # DL.NAME and DL.OLN and populated by CommsysGetLastNameFirstNameInitialRuleHandler
            # (see ~line 167). DriverHistoryQuery has no Attention attribute at all (~line 210).
            # I initially moved this row to the DH card during the v2.3 collapse and wrote that the
            # handler fed the DH query -- BOTH WRONG, and the provider's own QIDM refuted it in one grep.
            # The handler populates the VALUE, but the attribute's sourceField still needs a control to
            # bind to -- without one, audit_wiring_closure reports class C UNFILLABLE REQ and validate.ps1
            # reports 'unresolvable any[] fields'. NO prefill and NO combo default: any[] membership alone
            # feeds the handler (HI_HCJDC_OFML proved a prefill was never the gate-feeder). Hidden is the
            # ONE standing visible-first exception.
            @{ id = 'ROW_PER_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Input'; node = InpH 'Attention' 'Attention (auto)' '30' 'ROW_PER_ATTN' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = "DRIVER HISTORY SEARCH BY OLN, `nOR BY NAME + DOB + SEX"
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name'  '30' 'ROW_PER_DH_1' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'Middle Name' '30' 'ROW_PER_DH_1' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'   '30' 'ROW_PER_DH_1' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix'      '10' 'ROW_PER_DH_1' }
            )}
            # Race on the 2ND line, immediately AFTER Sex, by operator directive (Rob 2026-08-20:
            # "on dh 2nd line after sex"). Purpose Code moves to the 3rd row to make room -- it is an
            # optional any[] qualifier on both DH combos, so it is the right thing to displace.
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_2' }
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth' 'ROW_PER_DH_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_2' }
                @{ id = 'RaceCodeDH_Input';  node = Sel 'raceCodeDH'  'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_2' }
            )}
            # raceCodeDH keeps attributeTypeId='RACE'+codeTypeProvider='NIBRS' (matching the DL raceCode
            # field) so it produces the attribute ID the DH RaceCode attr's codeTypeProvider
            # reverse-lookup needs -- it was a codeTypeCategory code-string, which the reverse-lookup
            # could not resolve (AP #11 CommSys direction, caught by the validate check added
            # 2026-07-24). Moved up to row 2 at v2.4; this row now carries the displaced Purpose Code.
            # NO Attention row on this card -- DH has no Attention attribute at all (see line ~210).
            @{ id = 'ROW_PER_DH_3'; cols = @('6'); fields = @(
                @{ id = 'PurposeCodeDH_Input'; node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DH_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 collapsed cards: DRIVER LICENSE (DL.OLN/DL.NAME) + DRIVER HISTORY (KQ.O/KQ.N). DH-suffix fieldIds are the isolation mechanism.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input'; node = Sel 'gunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'GunModel_Input';   node = Inp 'GunModel'   'Model (optional)'   '11' 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial; caliber/make/model optional). Single card.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL NUMBER + TYPE'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial+type). Single card.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (COLLAPSED at v2.3 from 3: OPTIONS + HULL SEARCH + REGISTRATION SEARCH)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = "BOAT SEARCH BY HULL ID, `nOR BY REGISTRATION NUMBER"
        rows  = @(
            # Hull and Registration are ALTERNATIVE IDENTIFIERS, not an identifier plus a qualifier
            # (BQ.H has hull in set[], BQ.R has reg in set[]), so two identifiers side by side on one
            # row is correct -- usx-cosmetic Step 3. Also clears the two L5 WASTED-WIDTH findings:
            # both had a full 12-col row at maxLen 20 and 8.
            # State on the TOP line, 2nd field -- the same operator directive applied to Vehicle, carried
            # here for uniformity because it is the SAME routing field on this entity too
            # (RegistrationState EXISTS -> Nlets BQ.H/BQ.R, NOT_EXISTS -> NCIC QB.H/QB.R).
            # NOTE, and flag it if this is not what was wanted: the directive named "state to top line
            # 2nd field" without naming a card. Applying it here puts State BETWEEN the two alternative
            # identifiers (Hull in BQ.H's set[], Registration in BQ.R's set[]), which usx-cosmetic would
            # otherwise keep adjacent so they read as "either one". Operator placement wins over that
            # guidance; swapping to [Hull, Registration, State] is a one-line change if preferred.
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for NM)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 collapsed card: hull (BQ.H/QB.H) + registration (BQ.R/QB.R), State routes Nlets-vs-NCIC'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs -- PascalCase USx form-fed refs; race kept for RMS person)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $nmBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built NM_NMLETS_OFML v${Version}" `
    -Version $Version
