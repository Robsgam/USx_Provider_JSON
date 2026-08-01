# build_tn_ties.ps1  -- TN_TIES (galvanized v2.0, single-JSON native PascalCase)
# Consolidated legacy BASE+MC -> one versioned JSON. Native PascalCase USx CAD fieldIds
# (Build-RmsBundle -KeepSsn -PascalCaseUsxFields). Phase 2 multi-card. DriverHistoryQuery
# uses DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) on separate VISIBLE
# DH cards + queriesToDeselect. Existence-only OOS/routing gates + identifier-priority
# guardrails. CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# TN-SPECIFIC:
#   NO CaRequestPurposeCode -- Tennessee, not California.
#   -KeepSsn: RMS person + DL SocialSecurityNumber (DQ06). NOT -SkipRace: raceCode feeds
#     RMS person search + DL QWA any[]. socialSecurityNumber/raceCode form fieldIds stay
#     as the RMS bundle emits them (SocialSecurityNumber PascalCase, raceCode camelCase).
#   DriverHistoryQuery has Attention (Mandatory, CommsysGetLastNameFirstNameInitialRuleHandler)
#     + PurposeCode (Mandatory) on the KQ (OOS) combos. Attention uses the eSUN/AZ auto-handler
#     feeder pattern: hidden InpH 'attention' initialValue='X' on a DH card, 'attention' in each
#     KQ any[], defaults Attention='X' -- so the handler output serializes. purposeCodeDH is a
#     visible officer-entered field (Rule 3-exempt).
#   ImageIndicator present on DriverLicenseQuery (Person=Y). NOT on Vehicle/Boat.
#   State: no initialValue (LIMITATION #30). RQ (Nlets/OOS, State EXISTS) vs QV/QWA/DQ01
#     (NCIC/no-state, State NOT_EXISTS) + Boat BB (Nlets, State EXISTS) vs QB (NCIC).
#     Label "State (leave blank for TN)".
#   Date format: yyyyMMdd (size=8, Date fields via CommsysParseDateRuleHandler).
#   Name: composite Last,First via FormatStringRuleHandler.
#   VehicleMakeCode: FormSelect VEHICLE_MAKE dropdown (hard gate -- never FormInput).
#   ArticleTypeCode dropdown: codeTypeSource='CA_CLETS' (NCIC gives empty dropdown).
#   Specialty Vehicle searches: Dealer (RQ05/QV.D), Handicap (RQ06), Temp (RQ07).
#
# DROPPED (form-identical shadows -- server routes by keyRef, form input is identical so only
#   one can ever fire; OCATS/MD precedent -- documented in TN_TIES_ACCEPTED_DIVERGENCES.txt):
#   Vehicle: RQ01/RV01 (== QV.P no-state plate), RQ03/RV03 (== QV.V no-state VIN), RV (== RQ.P OOS plate)
#   DL:      DQ02 (== QWA no-state Name+DOB+Sex)
#   28 metadata combos -> 22 built.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tn_ties.ps1

$ErrorActionPreference = "Stop"
$Version     = '2.1'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\TN_TIES_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; TN_TIES 6 basic queries, DH-suffix,
# existence-only OOS routing gates + identifier-priority guardrails; 22 combos):
#   VehicleRegistrationQuery : RQ.P (OOS plate), RQ.V (OOS VIN), QV.V (NCIC VIN), QV.P (NCIC plate),
#                              RQ05 (OOS dealer), QV.D (NCIC dealer), RQ06 (handicap), RQ07 (temp)
#   DriverLicenseQuery       : DQ.N (OOS Name), DQ.O (OOS OLN), QWA (NCIC Name), DQ01 (no-state OLN), DQ06 (SSN)
#   DriverHistoryQuery       : KQ.N (OOS Name+DOB+Sex), KQ.O (OOS OLN), DQ05 (no-state OLN) -- DH-suffix
#   GunQuery                 : QG (serial + optional caliber/make)
#   ArticleSingleQuery       : QA (serial+type)
#   BoatQuery                : BB.H (Nlets hull), QB.H (NCIC hull), BB.R (Nlets reg), QB.R (NCIC reg)

# =====================================================================
# BUNDLE 1: TN_TIES PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'TN_TIES'

$results = Build-ProviderQrdm -ProviderName 'TN_TIES'

$qmf = Build-Qmf -ProviderName 'TN_TIES'

# =====================================================================
# VehicleRegistrationQuery -- RQ (Nlets/OOS, State EXISTS), QV (NCIC, State NOT_EXISTS),
# + specialty (Dealer RQ05/QV.D, Handicap RQ06, Temp RQ07). Plate>VIN guardrail
# (VIN combos: LicensePlateNumber NOT_EXISTS).
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DealerLicensePlateNumber';    size = 10; sourceField = @('DealerLicensePlateNumber');    targetField = 'DealerLicensePlateNumber' }
        [PSCustomObject]@{ name = 'HandicapPlacardNumber';       size = 10; sourceField = @('HandicapPlacardNumber');       targetField = 'HandicapPlacardNumber' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator';        size = 1;  sourceField = @('InquiryTypeIndicator');        targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TemporaryLicensePlateNumber'; size = 10; sourceField = @('TemporaryLicensePlateNumber'); targetField = 'TemporaryLicensePlateNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # RQ.P -- OOS plate (Nlets), plate+type+year+state, fires when State present
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateYear','LicensePlateTypeCode','RegistrationState'); any = @('InquiryTypeIndicator')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # RQ.V -- OOS VIN (Nlets). Plate>VIN + fires when State present
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationState','VehicleIdentificationNumber'); any = @('InquiryTypeIndicator','VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # QV.V -- NCIC VIN (no state). Plate>VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('InquiryTypeIndicator','VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        # QV.P -- NCIC plate (no state, plate-only catch-all)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('InquiryTypeIndicator','LicensePlateTypeCode')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        # RQ05 -- OOS dealer plate (Nlets)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('DealerLicensePlateNumber'); any = @('InquiryTypeIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'RQ05'
            state                 = 'In/Out'
        }
        # QV.D -- NCIC dealer plate (no state)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('DealerLicensePlateNumber'); any = @('InquiryTypeIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'QV.D'
            state                 = 'In/Out'
        }
        # RQ06 -- Handicap placard (unique field, always reachable)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('HandicapPlacardNumber'); any = @() }
            primaryFieldReference = 'HandicapPlacardNumber'
            keyReference          = 'RQ06'
            state                 = 'In/Out'
        }
        # RQ07 -- Temporary plate (unique field, always reachable)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('TemporaryLicensePlateNumber'); any = @() }
            primaryFieldReference = 'TemporaryLicensePlateNumber'
            keyReference          = 'RQ07'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ.P/RQ.V (OOS Nlets), QV.V/QV.P (NCIC), RQ05/QV.D (dealer), RQ06 (handicap), RQ07 (temp). State-existence routing + Plate>VIN guardrail.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'TN_TIES_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'TN_TIES'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# DriverLicenseQuery -- DQ.N/DQ.O (OOS, State EXISTS), QWA/DQ01/DQ06 (no-state, State NOT_EXISTS).
# OLN>Name guardrail (Name combos: OperatorLicenseNumber NOT_EXISTS). ImageIndicator default Y
# on the no-state combos that carry it in any[].
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('ExpandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator';      size = 1;  sourceField = @('InquiryTypeIndicator');      targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';     size = 20; sourceField = @('OperatorLicenseNumber');     targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('raceCode');                  targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('SexCode');                   targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';      size = 20; sourceField = @('SocialSecurityNumber');      targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ.N -- OOS Name+DOB+Sex+State (most specific). OLN>Name
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode','RegistrationState'); any = @('InquiryTypeIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # DQ.O -- OOS OLN+State
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber','RegistrationState'); any = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        # QWA -- NCIC Name+DOB+Sex (no state). OLN>Name
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode'); any = @('ExpandedNameSearchCode','ImageIndicator','InquiryTypeIndicator','raceCode','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In/Out'
        }
        # DQ01 -- no-state OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('ExpandedNameSearchCode','ImageIndicator','InquiryTypeIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ01'
            state                 = 'In/Out'
        }
        # DQ06 -- SSN (no-state, unique field)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SocialSecurityNumber'); any = @('ExpandedNameSearchCode','ImageIndicator','InquiryTypeIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'DQ06'
            state                 = 'In/Out'
        }
    )
    description       = 'DriverLicenseQuery -- DQ.N/DQ.O (OOS), QWA (NCIC Name), DQ01 (OLN), DQ06 (SSN). State-existence routing + OLN>Name guardrail.'
    handlerFunction   = 'CommsysTransactionRequestHandler'
    name              = 'TN_TIES_DriverLicenseQuery'
    type              = 'QUERYINPUTDATAMAPPING'
    autoSelect        = $true
    queriesToDeselect = @('DriverHistoryQuery')
    provider          = 'TN_TIES'
    providerType      = 'Commsys'
    query             = 'DriverLicenseQuery'
    queryLabel        = 'Driver License'
    targetEntity      = 'Person'
}

# =====================================================================
# DriverHistoryQuery -- KQ.N/KQ.O (OOS Nlets, State EXISTS, Attention+PurposeCode mandatory),
# DQ05 (no-state OLN, State NOT_EXISTS). DH-suffix fieldIds isolate from DL pool (AP #14).
# OLN>Name guardrail (KQ.N: OperatorLicenseNumberDH NOT_EXISTS). Attention auto-handler feeder
# (eSUN/AZ pattern): hidden 'attention' initialValue='X' -> defaults Attention='X'.
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
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
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.N -- Name+DOB+Sex+PurposeCode, IN **and** OUT of state (Attention auto). OLN>Name
        # v2.1: the `RegistrationState EXISTS` gate was REMOVED from this combination.
        #   Metadata KQ{Name} = Set[Attention, Name, BirthDate, SexCode, PurposeCode] Any[State]
        #   -- State is OPTIONAL there, so ONE combination serves both in-state and out-of-state with
        #   State riding in any[]. Requiring State to EXIST made a documented IN-STATE driver-history
        #   name search IMPOSSIBLE: devdoc DriverHistoryQuery #1's mandatory set is exactly
        #   Attention+BirthDate+Name+PurposeCode+SexCode with State BRACKETED, and that fill matched
        #   NOTHING -- audit_devdoc_optionals reported "#1 (mandatory only) -> NO COMBO FIRES. A
        #   devdoc-legal fill sends no query" while "#1 +[State] -> KQ.N" was fine. There is no other
        #   name-based DH combination to fall through to (KQ.O and DQ05 are both OLN-keyed), so an
        #   officer could not run an in-state DH-by-name search at all.
        #   THE IN/OUT SPLIT IS NOT ABANDONED -- it stays on the OLN pair (KQ.O gated State EXISTS,
        #   DQ05 gated NOT_EXISTS), because the metadata genuinely FORKS there:
        #   KQ{OperatorLicenseNumber} carries Attention+PurposeCode while DQ05 is bare
        #   OperatorLicenseNumber. A State gate belongs where the metadata forks BY state, never on a
        #   variant that merely permits State as an optional.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH','purposeCodeDH'); any = @('attention','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ.O -- OOS OLN+PurposeCode (Attention auto)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH','purposeCodeDH'); any = @('attention','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # DQ05 -- no-state OLN (in-state, no Attention/PurposeCode)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH'); any = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ05'
            state                 = 'In/Out'
        }
    )
    description       = 'DriverHistoryQuery -- KQ.N (Name+DOB+Sex OOS), KQ.O (OLN OOS), DQ05 (OLN no-state). DH-suffix fields, Attention auto-filled, PurposeCode officer-entered. OLN>Name guardrail.'
    handlerFunction   = 'CommsysTransactionRequestHandler'
    name              = 'TN_TIES_DriverHistoryQuery'
    type              = 'QUERYINPUTDATAMAPPING'
    autoSelect        = $true
    queriesToDeselect = @('DriverLicenseQuery')
    provider          = 'TN_TIES'
    providerType      = 'Commsys'
    query             = 'DriverHistoryQuery'
    queryLabel        = 'Driver History'
    targetEntity      = 'Person'
}

# =====================================================================
# GunQuery -- QG (serial required; caliber/make optional any[]).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');   targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 3;  sourceField = @('firearmMake');  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial; caliber/make optional). NCIC firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TN_TIES'
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
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');    targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). NCIC article query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# BoatQuery -- BB (Nlets, State EXISTS), QB (NCIC, State NOT_EXISTS). Hull>Reg guardrail
# (reg combos: BoatHullIdNumber NOT_EXISTS).
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';    size = 20; sourceField = @('BoatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator'; size = 1; sourceField = @('InquiryTypeIndicator'); targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';  size = 8;  sourceField = @('RegistrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BB.H -- Nlets hull (State present)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('InquiryTypeIndicator','RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BB.H'
            state                 = 'In/Out'
        }
        # QB.H -- NCIC hull (no state)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('InquiryTypeIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
        # BB.R -- Nlets reg (State present). Hull>Reg
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('InquiryTypeIndicator','RegistrationState')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BB.R'
            state                 = 'In/Out'
        }
        # QB.R -- NCIC reg (no state). Hull>Reg
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('InquiryTypeIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BB.H/BB.R (Nlets, State), QB.H/QB.R (NCIC). State-existence routing + Hull>Reg guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$tnBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for TN_TIES v${Version} -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 22 combos, DH-suffix, existence-only routing gates + identifier-priority guardrails"
    name           = 'TN_TIES'
    type           = 'BUNDLE'
    provider       = 'TN_TIES'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- 5 QIFs, multi-card layouts
#
# Vehicle:  4 cards (OPTIONS + PLATE SEARCH + VIN SEARCH + SPECIALTY SEARCH)
# Person:   5 cards (OPTIONS + DL-OLN + DL-NAME + DH-OLN + DH-NAME) -- DH-suffix visible cards
# Firearm:  1 card  (QG)
# Article:  1 card  (QA)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REG SEARCH)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'InquiryTypeIndicator_Input'; node = Inp 'InquiryTypeIndicator' 'Inquiry Type (1/2/3, optional)' '1' 'ROW_VEH_OPT_1' }
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
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year (optional)' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SPEC'
        title = 'SPECIALTY SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_SPEC_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'DealerLicensePlateNumber_Input';    node = Inp 'DealerLicensePlateNumber'    'Dealer Plate'     '10' 'ROW_VEH_SPEC_1' }
                @{ id = 'HandicapPlacardNumber_Input';       node = Inp 'HandicapPlacardNumber'       'Handicap Placard' '10' 'ROW_VEH_SPEC_1' }
                @{ id = 'TemporaryLicensePlateNumber_Input'; node = Inp 'TemporaryLicensePlateNumber' 'Temp Plate'       '10' 'ROW_VEH_SPEC_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- OPTIONS (State + InquiryType) + PLATE (RQ.P/QV.P) + VIN (RQ.V/QV.V) + SPECIALTY (RQ05/QV.D/RQ06/RQ07)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 5 cards (DL + DH with DH-suffix visible cards)
# OPTIONS: State + Image + Race + InquiryType + ExpandedNameSearch + RelatedHit (shared DL fields)
# DL-OLN:  OperatorLicenseNumber + SocialSecurityNumber
# DL-NAME: NameFirst + NameLast + BirthDate + SexCode
# DH-OLN:  OperatorLicenseNumberDH + PurposeCode (+ hidden attention feeder)
# DH-NAME: NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (Y/N)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
                @{ id = 'RaceCode_Input';          node = Sel 'raceCode' 'Race (optional)' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_OPT_1' }
            )}
            @{ id = 'ROW_PER_OPT_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'InquiryTypeIndicator_Input';      node = Inp 'InquiryTypeIndicator'      'Inquiry Type (1/2/3, optional)' '1' 'ROW_PER_OPT_2' }
                @{ id = 'ExpandedNameSearchCode_Input';    node = Inp 'ExpandedNameSearchCode'    'Expanded Name Search (optional)' '1' 'ROW_PER_OPT_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit Search (optional)'   '1' 'ROW_PER_OPT_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'DRIVER LICENSE - OLN / SSN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
                @{ id = 'SocialSecurityNumber_Input';  node = Inp 'SocialSecurityNumber'  'SSN'            '20' 'ROW_PER_OLN_1' }
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
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DRIVER HISTORY - OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number' '20' 'ROW_PER_DH_OLN_1' }
                @{ id = 'PurposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (required for out-of-state)' '1' 'ROW_PER_DH_OLN_1' }
            )}
            @{ id = 'ROW_PER_DH_OLN_2'; cols = @('6'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_DH_OLN_2' @{ initialValue = 'X' } }
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
    description  = 'Person queries -- OPTIONS + DL-OLN/SSN (DQ.O/DQ01/DQ06) + DL-NAME (DQ.N/QWA) + DH-OLN (KQ.O/DQ05) + DH-NAME (KQ.N). DH-suffix visible cards; Attention auto-fed.'
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
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('12'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'FirearmMake_Input'; node = Sel 'firearmMake' 'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial; caliber/make optional). Single card.'
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
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_1' }
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
# Boat -- 3 cards
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'InquiryTypeIndicator_Input'; node = Inp 'InquiryTypeIndicator' 'Inquiry Type (1/2/3, optional)' '1' 'ROW_BOA_OPT_1' }
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
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- OPTIONS (State + InquiryType) + HULL (BB.H/QB.H) + REG (BB.R/QB.R)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs -- PascalCase USx form-fed refs, -KeepSsn; race kept)
# =====================================================================
$rmsBundle = Build-RmsBundle -KeepSsn -PascalCaseUsxFields

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $tnBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built TN_TIES v${Version}" `
    -Version $Version
