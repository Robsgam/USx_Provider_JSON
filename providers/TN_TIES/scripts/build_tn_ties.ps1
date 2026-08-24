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
#   Specialty Vehicle searches: Dealer (RQ05, ONE ungated combo as of v2.4), Handicap (RQ06), Temp (RQ07).
#
# DROPPED (form-identical shadows -- server routes by keyRef, form input is identical so only
#   one can ever fire; OCATS/MD precedent -- documented in TN_TIES_ACCEPTED_DIVERGENCES.txt):
#   Vehicle: RV01 (== RQ01 in-state plate), RV03 (== RQ03 in-state VIN), RV (== RQ.P OOS plate),
#            QV{plate}/QV{VIN}/QV{dealer} (mined NCIC twins, identical set[] -- see v2.4 note below)
#   DL:      DQ02 (== QWA no-state Name+DOB+Sex)
#   28 metadata combos -> 22 built.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tn_ties.ps1

$ErrorActionPreference = "Stop"
$Version     = '2.5'
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
#   VehicleRegistrationQuery : RQ.P (OOS plate), RQ.V (OOS VIN), RQ03 (in-state VIN), RQ01 (in-state
#                              plate), RQ05 (dealer, ungated at v2.4), RQ06 (handicap), RQ07 (temp)
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
# + specialty (Dealer RQ05 ungated, Handicap RQ06, Temp RQ07). Plate>VIN guardrail
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
        # RQ03 -- in-state VIN (blank State = TN), devdoc #3. Plate>VIN.
        # RENAMED from QV.V at v2.4: QV is a DATA-MINED transaction (devdoc line 9), so naming an
        # OUTGOING combo after it read as "we send this to NCIC" -- which is not a thing a keyRef can
        # do, since the keyRef never reaches the wire. Zero wire impact; the name now matches the
        # metadata variant this combo implements.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @('InquiryTypeIndicator','VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ03'
            state                 = 'In/Out'
        }
        # RQ01 -- in-state plate (blank State = TN), devdoc #1 "(In) LicensePlateNumber".
        # RENAMED from QV.P at v2.4 -- same reason as RQ03 above. THIS is the combo whose name caused
        # a note in FOUR places claiming in-state TN plate searches "reach NCIC not TIES/DMV".
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber'); any = @('InquiryTypeIndicator','LicensePlateTypeCode')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ01'
            state                 = 'In/Out'
        }
        # RQ05 -- dealer plate. ONE combo, UNGATED, as of v2.4.
        #
        # v2.3 built TWO dealer combos -- RQ05 gated `RegistrationState EXISTS` and QV.D gated
        # NOT_EXISTS -- and the v2.3 comment justified the split like this: "optionals cannot
        # discriminate, so the State gate is the only thing keeping it reachable; the officer's
        # State selects the DESTINATION rather than riding the request."
        #
        # *** THAT JUSTIFICATION WAS WRONG, and it is the SAME misconception that produced the
        # "unbuilt RQ01" note closed on 2026-08-24: THE KEYREF NEVER REACHES THE WIRE. *** A request
        # carries <MessageType>VehicleRegistrationQuery</MessageType> plus the FIELDS -- nothing
        # else. State is in NEITHER combo's set[] NOR any[], so it is never transmitted by either,
        # and the two combos emitted BYTE-IDENTICAL requests. The officer's State choice selected
        # which keyRef got RECORDED, not where the query went. Two names, one query.
        #
        # Cost of leaving it: a guaranteed audit_log_inflation attack-A clone group in every sweep
        # (identical wire), and double the dealer tests for zero extra coverage.
        # Devdoc agrees with the collapse: combination 4 is "(In) DealerLicensePlateNumber,
        # [InquiryTypeIndicator]" and there is NO (Out) dealer entry -- so an out-of-state dealer
        # path was never a devdoc path to serve. Ungated is also what RQ06/RQ07 already do, and for
        # exactly the same reason (both are (In)-only devdoc entries on a unique field).
        # State stays OUT of any[]: no dealer variant defines it, so adding it would OVER-PERMIT.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('DealerLicensePlateNumber'); any = @('InquiryTypeIndicator')
            }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'RQ05'
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
    description        = 'VehicleRegistrationQuery -- RQ.P/RQ.V (OOS Nlets), RQ03/RQ01 (in-state), RQ05 (dealer), RQ06 (handicap), RQ07 (temp). State-existence routing + Plate>VIN guardrail.'
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
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
                set = @('NameLast','NameFirst','BirthDate','SexCode','RegistrationState'); any = @('InquiryTypeIndicator','NameMiddle','NameSuffix')
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
                set = @('NameLast','NameFirst','BirthDate','SexCode'); any = @('ExpandedNameSearchCode','ImageIndicator','InquiryTypeIndicator','raceCode','relatedHitSearchIndicator','NameMiddle','NameSuffix')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
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
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
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
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
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
                set = @('NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH','purposeCodeDH'); any = @('attention','RegistrationState','NameMiddleDH','NameSuffixDH')
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

# =====================================================================
# CAD DEFAULT TWINS (v2.5) -- BUILD_RULES 12: CAD IGNORES the form initialValue, so a form-only
# prefill leaves every CAD-originated query still sending nothing. Each prefill therefore needs a
# matching combo defaults[] entry on EVERY combination that carries the field.
#
# Done as a loop rather than 15 hand-edits for two reasons: it cannot miss a combination, and it
# stays correct if one is added later -- a hand-maintained list of 13 keyRefs is exactly the kind of
# thing that silently falls behind the array it describes.
#
# ONLY fields that are in any[] and in NO set[] may be defaulted this way. That is not a style
# preference, it is BUILD_RULES 24: a prefill on a set[] field is always-present, which collapses
# that combo onto a plainer sibling and can kill it. Measured before writing this:
# InquiryTypeIndicator sits in the any[] of all 13 carrying combos and in no set[], so it is safe.
# purposeCodeDH is the counter-example -- it IS in KQ.N/KQ.O set[], and prefilling it would have
# collapsed KQ.O onto DQ05 (set[OperatorLicenseNumberDH] alone) and killed the in-state DH-by-OLN
# path. Rob's ruling 2026-08-24: give it the CAD default WITHOUT a form initialValue, so routing is
# untouched and DQ05 survives. The assertion below enforces that distinction instead of trusting it.
#
# MATCH-FIELD vs DEFAULT-FIELD ARE DIFFERENT NAMESPACES and conflating them makes this loop a no-op.
# set[]/any[] hold FORM fieldIds (sourceFields); defaults[].field holds the QIDM ATTRIBUTE name. They
# happen to be identical for InquiryTypeIndicator, which is exactly why the bug would have hidden --
# it only shows on the DH-suffixed field, where set[] says `purposeCodeDH` and the attribute is
# `PurposeCode`. Matching on the attribute name there would find nothing, touch zero combinations,
# and the count assertion below is what would have caught it.
function Add-ComboDefault($qidm, [string]$field, [string]$value, [string]$matchField, [switch]$AllowInSet) {
    if (-not $matchField) { $matchField = $field }
    $touched = 0
    foreach ($c in @($qidm.combinations)) {
        $inAny = (@($c.requirements.any) -contains $matchField)
        $inSet = (@($c.requirements.set) -contains $matchField)
        if ($inSet -and -not $AllowInSet) {
            throw "Add-ComboDefault: '$field' is in set[] of $($c.keyReference) -- defaulting it would make it always-present (BUILD_RULES 24). Pass -AllowInSet only when the CAD default carries NO matching form initialValue."
        }
        if (-not $inAny -and -not $inSet) { continue }
        $existing = @($c.requirements.defaults | Where-Object { $_ -and $_.field })
        if ($existing.field -contains $field) { continue }
        $c.requirements | Add-Member -NotePropertyName defaults -NotePropertyValue @() -Force:$false -ErrorAction SilentlyContinue
        $c.requirements.defaults = @($existing) + @([PSCustomObject]@{ field = $field; value = $value })
        $touched++
    }
    Write-Host "  [cad-default] $field=$value -> $touched combination(s) on $($qidm.query)"
    return $touched
}

$cadDefaultTotal = 0
foreach ($q in @($vehRegQuery, $dlQuery, $boatQuery)) {
    $cadDefaultTotal += Add-ComboDefault $q 'InquiryTypeIndicator' '3'
}
# purposeCodeDH: CAD default ONLY -- no form initialValue. -AllowInSet is the explicit acknowledgement
# that this field is in set[] and that the safety rule is being waived DELIBERATELY, which is only
# sound because there is no form prefill to make it always-present.
$cadDefaultTotal += Add-ComboDefault $dhQuery 'PurposeCode' 'C' -matchField 'purposeCodeDH' -AllowInSet
if ($cadDefaultTotal -lt 15) { throw "CAD default twins: expected at least 15 combination(s) touched, got $cadDefaultTotal -- a combination lost its field or the loop stopped matching." }

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
# ------------------------------------------------------------------
# Vehicle -- 1 card (v2.3, collapsed from 4: OPTIONS/PLATE/VIN/SPECIALTY)
# LABEL-OVERRIDE: LicensePlateTypeCode -- prefilled 'PC', bare label per BUILD_RULES 11
# LABEL-OVERRIDE: LicensePlateYear -- prefilled current year, bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH BY PLATE, VIN, DEALER, HANDICAP, OR TEMP PLATE'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            # ROWS 2 AND 3 SWAPPED at v2.5 (Rob's cosmetic directive): the three SPECIALTY PLATE
            # identifiers now sit immediately under the plate row, so all four plate-family searches
            # read together, and the VIN group drops below them. Plate Number stays on row 1 with
            # Plate Type + Plate Year because RQ.P (the out-of-state plate combo) REQUIRES all three
            # -- splitting them would separate a combo's own mandatory fields across rows.
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'DealerLicensePlateNumber_Input';    node = Inp 'DealerLicensePlateNumber'    'Dealer Plate'     '10' 'ROW_VEH_2' }
                @{ id = 'HandicapPlacardNumber_Input';       node = Inp 'HandicapPlacardNumber'       'Handicap Placard' '10' 'ROW_VEH_2' }
                @{ id = 'TemporaryLicensePlateNumber_Input'; node = Inp 'TemporaryLicensePlateNumber' 'Temp Plate'       '10' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','3','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_3' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year (optional)' '4' 'ROW_VEH_3' }
            )}
            # Inquiry Type: bare label + initialValue '3' at v2.5. SAFE to prefill and that was
            # MEASURED, not assumed -- InquiryTypeIndicator is in the any[] of all 13 carrying combos
            # and in NO set[], so it cannot shadow anything (BUILD_RULES 24 only bites on set[]
            # fields). '3' is the devdoc default ("3-Registration and hotfiles check (default)"), so
            # the form now states what the provider already does. Helper text "(1/2/3, optional)"
            # removed on every card: a prefilled control takes a BARE label, and the values it listed
            # are no longer something the officer has to supply. Paired with a combo defaults[] twin
            # on each carrying combo -- CAD ignores form initialValue (BUILD_RULES 12).
            # LABEL-OVERRIDE: InquiryTypeIndicator -- bare "Inquiry Type" by Rob's directive 2026-08-24
            #   ("remove the helper text for inquiry type on all cards", "make the default 3"). CHECK 15
            #   asks for an "(optional)" qualifier on an any[]-only field; that rule and the PREFILLED
            #   BARE-LABEL rule point opposite ways here, and the prefill rule wins: the field now
            #   carries initialValue '3', so "(optional)" would describe a control the officer never has
            #   to touch, and "(1/2/3)" would list values the form already supplies. Applies to all
            #   three cards that carry this control (Vehicle, Person DL, Boat).
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_4' }
                @{ id = 'InquiryTypeIndicator_Input'; node = Inp 'InquiryTypeIndicator' 'Inquiry Type' '1' 'ROW_VEH_4' @{ initialValue = '3' } }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card: Plate (RQ.P/RQ01) + VIN (RQ.V/RQ03) + specialty (RQ05 dealer, RQ06 handicap, RQ07 temp). State-existence routing + Plate>VIN guardrail.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 2 cards (v2.3, collapsed from 5)
# The DL card carries State + NCIC Image + Race + Inquiry Type + Expanded Name Search +
# Stolen Check as SHARED CONTEXT; the DH combinations read State too (one form, one field
# pool -- cards are visual grouping only).
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284, canonical on FL/HI/IL/NY/OH/TX (any[] optional)
# LABEL-OVERRIDE: NameMiddle -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameSuffix -- bare "Suffix", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameMiddleDH -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: attention -- hidden gate-feeder, the label is dead text the officer never sees
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, SSN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'SocialSecurityNumber_Input';  node = Inp 'SocialSecurityNumber'  'SSN' '20' 'ROW_PER_DL_1' }
            )}
            # ROW ORDER CHANGED at v2.5 (Rob's cosmetic directive): the shared-context row moves up to
            # position 2, names to 3, DOB group to 4. Context first means the officer sets State /
            # image / stolen / inquiry once, then picks a search path below it -- and it matches the
            # uniform target's intent of grouping shared context with the primary identifier rather
            # than burying it under the path-specific rows.
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DL_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DL_2' }
                @{ id = 'InquiryTypeIndicator_Input';      node = Inp 'InquiryTypeIndicator' 'Inquiry Type' '1' 'ROW_PER_DL_2' @{ initialValue = '3' } }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL_3' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL_3' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_DL_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '5'  'ROW_PER_DL_3' }
            )}
            # Expanded Name Search JOINS the DOB row at v2.5 instead of sitting alone on a [6] row
            # below, so the DL card is four rows instead of five. Widths tighten 4/4/4 -> 3/3/3/3 to
            # make room; the row still sums to 12 (L6) and the child count still matches (validate).
            # Its "(optional)" is dropped per the directive.
            @{ id = 'ROW_PER_DL_4'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_DL_4' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_4' }
                @{ id = 'RaceCode_Input';  node = Sel 'raceCode' 'Race (optional)' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_4' }
                # LABEL-OVERRIDE: ExpandedNameSearchCode -- bare "Expanded Name Search" by Rob's
                #   directive 2026-08-24 ("remover the options on that"), moved onto the DOB row in the
                #   same pass. It is genuinely an any[]-only optional, so CHECK 15's request for an
                #   "(optional)" qualifier is CORRECT SIGNAL and is being overruled deliberately, not
                #   silenced by accident: the card title already enumerates the search paths, and the
                #   lean-label convention keeps qualifiers out of the label. Recorded here so the WARN
                #   downgrades to INFO instead of being re-litigated at the next pass.
                @{ id = 'ExpandedNameSearchCode_Input'; node = Inp 'ExpandedNameSearchCode' 'Expanded Name Search' '1' 'ROW_PER_DL_4' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_1' }
                @{ id = 'PurposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (required for out-of-state)' '1' 'ROW_PER_DH_1' }
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
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards: DL (OLN/SSN + name, in and out of state) + DH (KQ.O/KQ.N). DH-suffix fieldIds isolate the DH pool.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG: serial mandatory, make/caliber optional)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake' 'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'gunCaliber'  'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- 1 card: QG (serial, with optional make/caliber).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA: serial + type)
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
    description  = 'Article query -- 1 card: QA (serial + type).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (v2.3, collapsed from 3). Hull leads Registration (identifier priority).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY HULL, OR REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';     node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input';   node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
                @{ id = 'InquiryTypeIndicator_Input'; node = Inp 'InquiryTypeIndicator' 'Inquiry Type' '1' 'ROW_BOA_1' @{ initialValue = '3' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card: Hull + Registration, State-existence routing.'
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
