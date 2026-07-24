# build_la_lems.ps1  -- LA_LEMS (galvanized v3.0, single-JSON native PascalCase)
# Consolidated legacy BASE+MC -> one versioned JSON. Native PascalCase USx CAD fieldIds
# (Build-RmsBundle -SkipRace -PascalCaseUsxFields). Phase 2 multi-card. DriverHistoryQuery
# uses DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) on separate VISIBLE
# DH cards + queriesToDeselect. OOS RegistrationState handling + identifier-priority guardrails.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# LA-SPECIFIC:
#   Attention auto-handler (AP #27): CommsysGetLastNameFirstNameInitialRuleHandler on
#     VehReg/DL/Gun/Article/Boat (metadata carries Attention in those any[]). Converted from
#     the legacy handler-only (non-serializing) form to the AZ/eSUN hidden-feeder pattern --
#     a hidden 'attention' field (initialValue='X') per form + 'attention' in each combo any[]
#     + defaults[] Attention='X' so the handler output serializes. 'attention' is the ONLY
#     allowed hidden field. DriverHistoryQuery metadata has NO Attention field -> DH carries no
#     Attention attribute/feeder (dropped from legacy, which orphaned it).
#   DP/DQ routing toggle (DriverLicenseQuery): DP = photo DL (set OLN+ImageIndicator),
#     DQ = plain DL by OLN (set OLN, ImageIndicator NOT_EXISTS). ImageIndicator form defaults to 'Y'
#     (photo/DP is the default path); officer clears the Image dropdown to reach DQ (plain DL)
#     (blank) -- it is the toggle: Image=Y -> DP (photo), Image blank -> DQ. Existence-only,
#     poisoned-array-free, mutually exclusive, both reachable.
#   Vehicle State REQUIRED (in set[] for both RQS combos per metadata) -- no in/out keyRef
#     split, so State stays in set[], no initialValue. Person/Boat State is any[]-optional
#     (blank=in-state LA, filled=OOS). LABEL-OVERRIDE on RegistrationState (required-in-set,
#     not a leave-blank toggle on Vehicle).
#   RaceCode: camelCase form field (raceCode) feeding CommSys DL QWDN only (RMS is -SkipRace);
#     dropdown NIBRS_RACE/NIBRS. QWDN requires raceCode (warrant name+race); QWA has raceCode
#     NOT_EXISTS to isolate it from QWDN (MD ZWAR/ZLDR precedent).
#   Gun: single QG combo. GunSerialNumber sourceField 'serialNumber' (CAD populates camelCase
#     serialNumber -- Firearm CAD fix, matches NJ/FL/HI/TX/MD). GunMake maxLen=3 (LA-specific),
#     GunTypeCode maxLen=3. Name composite dropped to First+Last (galvanized convention).
#   Date format: yyyyMMdd (metadata: 8 numeric CCYYMMDD).
#
# ACCEPTED DIVERGENCES (see docs/LA_LEMS_ACCEPTED_DIVERGENCES.txt):
#   Boat: 4 metadata combos (QB/BQ x Hull/Reg) collapsed to 2 (QB=Hull, BQ=Reg) -- the other
#     two are form-identical shadows (same set[], different keyRef; server routes by keyRef).
#   DriverLicense: 6 metadata combos collapsed to 4 -- QWDN-OLN (shadow of DQ-OLN) and DQ-Name
#     (shadow of QWA) dropped (form-identical, same set[]).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_la_lems.ps1

$ErrorActionPreference = "Stop"
$Version     = '3.0'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\LA_LEMS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# LABEL-OVERRIDE: RegistrationState -- REQUIRED in set[] for LA vehicle queries (metadata),
#   any[]-optional OOS on Person/Boat; no in/out keyRef split so no 'leave blank' toggle on Vehicle.

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; LA_LEMS 6 basic queries, DH-suffix,
# identifier-priority guardrails, Attention auto-handler feeder):
#   VehicleRegistrationQuery : RQSLicensePlateNumber (plate), RQSVehicleIdentificationNumber (VIN, Plate>VIN)
#   DriverLicenseQuery       : QWDN (warrant name+race), QWA (warrant name), DP (photo OLN), DQ (OLN); OLN>Name
#   DriverHistoryQuery       : KQName (Name+DOB+Sex+Purpose), KQOperatorLicenseNumber (OLN+Purpose); DH-suffix, OLN>Name
#   GunQuery                 : QG (serial)
#   ArticleSingleQuery       : QA (serial)
#   BoatQuery                : QB (hull), BQ (reg, Hull>Reg)

# =====================================================================
# BUNDLE 1: LA_LEMS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'LA_LEMS'

$results = Build-ProviderQrdm -ProviderName 'LA_LEMS'

$qmf = Build-Qmf -ProviderName 'LA_LEMS'

# =====================================================================
# VehicleRegistrationQuery -- RQS Plate / RQS VIN. State REQUIRED in set[] (metadata, no split).
# Plate>VIN guardrail (VIN combo: LicensePlateNumber NOT_EXISTS). Attention feeder.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 17; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        # RQS Plate -- Plate+Type+Year+State (State required, Type/Year defaulted)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState'); any = @('attention')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'Attention';            value = 'X' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQSLicensePlateNumber'
            state                 = 'In/Out'
        }
        # RQS VIN -- VIN+State (Plate>VIN guardrail: LicensePlateNumber NOT_EXISTS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber','RegistrationState'); any = @('attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQSVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQS Plate / RQS VIN. State required in set[] (metadata). Plate>VIN guardrail. Attention feeder.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# DriverLicenseQuery -- QWDN (warrant name+race), QWA (warrant name), DP (photo OLN), DQ (OLN).
# OLN>Name guardrail (QWDN/QWA: OperatorLicenseNumber NOT_EXISTS).
# QWDN vs QWA isolation: QWDN requires raceCode (set); QWA has raceCode NOT_EXISTS.
# DP vs DQ toggle: DP set[OLN,Image]; DQ set[OLN] + ImageIndicator NOT_EXISTS. ImageIndicator form
# defaults to 'Y' (DP/photo default); officer clears the Image dropdown to reach DQ.
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';       size = 1;  sourceField = @('ImageIndicator');       targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 17; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';              size = 1;  sourceField = @('raceCode');              targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # QWDN -- warrant Name+DOB+Sex+Race (5 set, most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SexCode','BirthDate','NameLast','NameFirst','raceCode'); any = @('RegistrationState','attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @(
                    [PSCustomObject]@{ field = @('raceCode');              operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QWDN'
            state                 = 'In/Out'
        }
        # QWA -- warrant Name+DOB+Sex (4 set; raceCode NOT_EXISTS -> distinguishes from QWDN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('raceCode');              operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In/Out'
        }
        # DP -- photo DL (OLN+ImageIndicator both set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber','ImageIndicator'); any = @('RegistrationState','attention')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                    [PSCustomObject]@{ field = 'Attention';      value = 'X' }
                )
                conditions = @([PSCustomObject]@{ field = @('ImageIndicator'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DP'
            state                 = 'In/Out'
        }
        # DQ -- DL by OLN (no photo; ImageIndicator NOT_EXISTS -> distinguishes from DP)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('RegistrationState','attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('ImageIndicator'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- QWDN (name+race), QWA (name), DP (photo OLN), DQ (OLN). OLN>Name + raceCode isolation guardrails; DP/DQ ImageIndicator toggle. autoSelect + queriesToDeselect.'
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

# =====================================================================
# DriverHistoryQuery -- KQName (Name+DOB+Sex+Purpose), KQOperatorLicenseNumber (OLN+Purpose).
# DH-suffix fieldIds isolate from DL field pool (AP #14). PurposeCode required in set[] (default C).
# NO Attention (not in DH metadata). OLN>Name guardrail (KQName: OperatorLicenseNumberDH NOT_EXISTS).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ Name -- Name+DOB+Sex+PurposeCode (5 set, most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SexCodeDH','BirthDateDH','NameLastDH','NameFirstDH','purposeCodeDH'); any = @('RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'In/Out'
        }
        # KQ OLN -- OLN+PurposeCode
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH','purposeCodeDH'); any = @('RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQName (name+DOB+sex+purpose), KQOperatorLicenseNumber (OLN+purpose). DH-suffix fields, PurposeCode default C, OLN>Name guardrail. No Attention (not in metadata).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# GunQuery -- QG (serial). GunSerialNumber sourceField 'serialNumber' (Firearm CAD fix).
# GunMake maxLen=3 (LA-specific), GunTypeCode maxLen=3. Attention feeder.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'GunMake';         size = 3;  sourceField = @('firearmMake');   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber');  targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';     size = 3;  sourceField = @('gunTypeCode');   targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('serialNumber'); any = @('attention','firearmMake','gunTypeCode')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). GunMake maxLen=3, GunTypeCode maxLen=3. serialNumber sourceField (CAD fix). Attention feeder.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# ArticleSingleQuery -- QA (serial). ArticleTypeCode in any[]. Attention feeder.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');     targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');  targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('serialNumber'); any = @('attention','articleTypeCode')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial). ArticleTypeCode optional (any[]). Attention feeder.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# BoatQuery -- QB (hull, NCIC stolen), BQ (reg, Nlets). Hull>Reg guardrail.
# 4 metadata combos collapsed to 2 (QB=Hull, BQ=Reg; other two are form-identical shadows).
# QB carries Attention (metadata), BQ carries State (metadata).
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # QB -- Hull (NCIC stolen). Attention feeder.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
        # BQ -- Reg (Nlets). Hull>Reg guardrail: BoatHullIdNumber NOT_EXISTS. State in any[].
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- QB (hull, NCIC stolen), BQ (reg, Nlets). Hull>Reg guardrail. 4 metadata combos -> 2 (shadows dropped).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$laBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for LA_LEMS v${Version} -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), DH-suffix, Attention auto-handler feeder, DP/DQ toggle, identifier-priority guardrails"
    name           = 'LA_LEMS'
    type           = 'BUNDLE'
    provider       = 'LA_LEMS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- 5 QIFs, multi-card layouts
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   5 cards (OPTIONS + DL-OLN + DL-NAME + DH-OLN + DH-NAME) -- DH-suffix visible cards
# Firearm:  1 card  (QG)
# Article:  1 card  (QA)
# Boat:     2 cards (HULL SEARCH + REGISTRATION SEARCH)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards. State REQUIRED (in set[]).
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (required)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
            )}
            @{ id = 'ROW_VEH_OPT_HID'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Veh_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_VEH_OPT_HID' @{ initialValue = 'X' } }
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
            @{ id = 'ROW_VEH_PLATE_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_PLATE_2' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '17' 'ROW_VEH_VIN_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- OPTIONS (State required) + PLATE (RQS) + VIN (RQS, Plate>VIN)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 5 cards (DL + DH with DH-suffix visible cards)
# OPTIONS: State + Image (DP/DQ toggle) + hidden attention feeder
# DL-OLN: OperatorLicenseNumber
# DL-NAME: NameFirst + NameLast + BirthDate + SexCode + raceCode
# DH-OLN: OperatorLicenseNumberDH + PurposeCode
# DH-NAME: NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for LA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (Y for photo; clear for no-photo DL)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
            @{ id = 'ROW_PER_OPT_HID'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Per_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_OPT_HID' @{ initialValue = 'X' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'DRIVER LICENSE - LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '17' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'DRIVER LICENSE - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_2' }
                @{ id = 'RaceCode_Input';  node = Sel 'raceCode'  'Race (warrant search)' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DRIVER HISTORY - LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_DH_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number' '20' 'ROW_PER_DH_OLN_1' }
                @{ id = 'PurposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DH_OLN_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_NAME'
        title = 'DRIVER HISTORY - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name' '30' 'ROW_PER_DH_NAME_1' }
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name'  '30' 'ROW_PER_DH_NAME_1' }
            )}
            @{ id = 'ROW_PER_DH_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth' 'ROW_PER_DH_NAME_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_NAME_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- OPTIONS (State + Image toggle) + DL-OLN (DP/DQ) + DL-NAME (QWDN/QWA) + DH-OLN (KQ OLN) + DH-NAME (KQ Name). DH-suffix visible cards.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG). serialNumber + firearmMake + gunTypeCode + hidden attention.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunTypeCode_Input';  node = Sel 'gunTypeCode'  'Firearm Type (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_HID'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Gun_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_GUN_HID' @{ initialValue = 'X' } }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial). Make/Type optional. Attention feeder.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA). serialNumber + articleTypeCode + hidden attention.
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_HID'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Art_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_ART_HID' @{ initialValue = 'X' } }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial). ArticleType optional. Attention feeder.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 2 cards (HULL + REGISTRATION). State on REG card (any[], leave blank for LA).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
            @{ id = 'ROW_BOA_HID'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Boa_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_BOA_HID' @{ initialValue = 'X' } }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('8','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for LA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_REG_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- HULL (QB, NCIC stolen) + REGISTRATION (BQ, Nlets, Hull>Reg)'
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
    bundles = @($entitiesBundle, $laBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built LA_LEMS v${Version}" `
    -Version $Version
