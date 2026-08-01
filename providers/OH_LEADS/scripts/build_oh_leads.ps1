# build_oh_leads.ps1  -- OH_LEADS (galvanized v2.0, single-JSON native PascalCase)
# Consolidated legacy BASE+MC -> one versioned JSON. Native PascalCase USx CAD fieldIds
# (Build-RmsBundle -PascalCaseUsxFields). Phase 2 multi-card. DriverHistoryQuery uses
# DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) on separate VISIBLE DH
# cards + queriesToDeselect. Existence-only OOS/routing gates + identifier-priority guardrails.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# OH-SPECIFIC:
#   No CaRequestPurposeCode -- Ohio, not California.
#   Date format: MMddyyyy (size=8, Date fields via CommsysParseDateRuleHandler).
#   Name: composite Last,First via FormatStringRuleHandler.
#   State: no initialValue (LIMITATION #30). RegistrationState EXISTS/NOT_EXISTS routes
#     OOS (RQ Nlets / DQ) vs in-state (RP/RV / DL/DN) AND Boat BQ(Nlets)/QB(NCIC).
#   VehicleRegistrationQuery -- 9 metadata combos collapsed to 7 built:
#     ATDP (dealer), RP (in-state plate), RQ.P (OOS plate), RV (in-state VIN), RQ.V (OOS VIN),
#     RS (owner SSN), RN (owner Name). The 2 duplicate-keyRef NCIC national shadows QV.P
#     ("(Out) LicensePlateNumber,State") and QV.V ("(Out) VehicleIdentificationNumber") are
#     DROPPED -- they are form-identical to RQ.P (OOS plate) and RV/RQ.V (VIN) under
#     existence-only gating (only RegistrationState distinguishes In/Out, already consumed).
#     Documented in docs/OH_LEADS_ACCEPTED_DIVERGENCES.txt (TN/OCATS/CA_CLETS drop precedent).
#     Owner search (RN/RS) is cross-entity (person fields on Vehicle) + lowest priority
#     (Plate>VIN>SSN>Name). DealerPlateType routes ATDP.
#   DriverLicenseQuery -- 4 built (DQ.O/DL OLN, DQ.N/DN Name); OLN>Name + State In/Out gates.
#     ImageIndicator (Y) only on DQ.O (metadata-faithful). QWA + 2 BMVIMS deferred (non-basic).
#   DriverHistoryQuery -- KQ.N (Name+DOB+Sex), KQ.O (OLN). DH-suffix. BMVIMS(OLN) dropped
#     (form-identical OLN shadow of KQ.O; devdoc folds it into the KQ OLN combo's optional
#     ReasonCode). Attention auto-handler (CommsysGetLastNameFirstNameInitialRuleHandler) via
#     eSUN hidden 'attention' feeder + defaults[] so the handler output serializes.
#   GunQuery -- QG (serial; caliber/make/relatedHit optional). No NCICNumber (not in metadata).
#   ArticleSingleQuery -- QA.S (serial+type), QA.N (NCIC#). serial>NCIC guardrail.
#   BoatQuery -- BQ.H/BQ.R (Nlets, State), QB.H/QB.R (NCIC, Image/RelatedHit). State-existence
#     routing + Hull>Reg guardrail. No NCICNumber (not in metadata).
#   VehicleMakeCode: FormSelect VEHICLE_MAKE dropdown (hard gate -- never FormInput).
#   RelatedHitSearchIndicator: visible camelCase FormSelect (YES_NO_UNKNOWN) on Gun/Article/Boat.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_oh_leads.ps1

$ErrorActionPreference = "Stop"
$Version     = '2.1'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\OH_LEADS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; OH_LEADS 6 basic queries,
# DH-suffix, existence-only routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : ATDP (dealer plate), RQ.P (OOS plate), RP (in-state plate), RQ.V (OOS VIN), RV (in-state VIN), RS (owner SSN), RN (owner Name)
#   DriverLicenseQuery       : DQ.O (OOS OLN), DL (in-state OLN), DQ.N (OOS Name+DOB+Sex), DN (in-state Name)
#   DriverHistoryQuery       : KQ.N (Name+DOB+Sex), KQ.O (OLN) -- DH-suffix fieldIds, Attention auto-handler
#   GunQuery                 : QG (serial; caliber/make/relatedHit optional)
#   ArticleSingleQuery       : QA.S (serial+type), QA.N (NCIC#)
#   BoatQuery                : BQ.H (Nlets hull+state), QB.H (NCIC hull), BQ.R (Nlets reg+state), QB.R (NCIC reg)

# =====================================================================
# BUNDLE 1: OH_LEADS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'OH_LEADS'

$results = Build-ProviderQrdm -ProviderName 'OH_LEADS'

$qmf = Build-Qmf -ProviderName 'OH_LEADS'

# =====================================================================
# VehicleRegistrationQuery -- 7 combos (see header). Plate>VIN>SSN>Name identifier priority;
# RegistrationState EXISTS/NOT_EXISTS = OOS/in-state; DealerPlateType routes ATDP.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';               size = 4;  sourceField = @('AddressCounty');               targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'DealerPlateType';             size = 1;  sourceField = @('DealerPlateType');              targetField = 'DealerPlateType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('OwnerLastName','OwnerFirstName'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';        size = 9;  sourceField = @('OwnerSocialSecurityNumber');    targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # ATDP -- dealer plate (most specific: DealerPlateType present)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateTypeCode','DealerPlateType'); any = @()
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' })
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('DealerPlateType');    operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ATDP'
            state                 = 'In'
        }
        # RQ.P -- OOS plate (Nlets; State present, no dealer)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('DealerPlateType');    operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'Out'
        }
        # RP -- in-state plate (Ohio BMV; no State, no dealer)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('LicensePlateNumber','LicensePlateTypeCode'); any = @()
                defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' })
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('DealerPlateType');    operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RP'
            state                 = 'In'
        }
        # RQ.V -- OOS VIN (Nlets; VIN+make+year+state). Plate>VIN guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber','VehicleMakeCode','vehicleYear'); any = @('RegistrationState')
                conditions = @(
                    [PSCustomObject]@{ field = @('VehicleIdentificationNumber'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('LicensePlateNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');           operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'Out'
        }
        # RV -- in-state VIN (Ohio BMV; no State). Plate>VIN guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('VehicleIdentificationNumber'); any = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('VehicleIdentificationNumber'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('LicensePlateNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');           operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RV'
            state                 = 'In'
        }
        # RS -- owner by SSN (cross-entity; lower than plate/VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OwnerSocialSecurityNumber'); any = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('OwnerSocialSecurityNumber');   operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('LicensePlateNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('VehicleIdentificationNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'RS'
            state                 = 'In/Out'
        }
        # RN -- owner by Name (cross-entity; lowest priority)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OwnerLastName','OwnerFirstName'); any = @('AddressCounty')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('VehicleIdentificationNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OwnerSocialSecurityNumber');   operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'RN'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ATDP (dealer), RP/RQ.P (in-state/OOS plate), RV/RQ.V (in-state/OOS VIN), RS (owner SSN), RN (owner Name). State-existence routing + Plate>VIN>SSN>Name guardrails. QV.P/QV.V NCIC shadows dropped (ACCEPTED_DIVERGENCES).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'OH_LEADS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'OH_LEADS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# DriverLicenseQuery -- DQ.O/DL (OLN), DQ.N/DN (Name). OLN>Name + State In/Out gates.
# ImageIndicator (Y) only on DQ.O (metadata-faithful).
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ.O -- OOS OLN (State present; ImageIndicator optional)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @('ImageIndicator','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'Out'
        }
        # DL -- in-state OLN (no State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber'); any = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DL'
            state                 = 'In'
        }
        # DQ.N -- OOS Name+DOB+Sex (State present). OLN>Name guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode'); any = @('RegistrationState')
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'Out'
        }
        # QWA -- in-state Name + BirthDate. ADDED v2.1.
        # Devdoc DriverLicenseQuery #1 is "Name, [BirthDate]" -- BirthDate is a LEGAL OPTIONAL on a name
        # search -- but metadata DN{Name} is Set[Name] with NO <Any> AT ALL, so DN cannot carry a date of
        # birth. Metadata does define the variant that can, under the SAME DriverLicenseQuery transaction:
        #     QWA{Name} = Set[BirthDate, Name]
        # and it was NOT BUILT, so a Name+DOB search fell through to DN and the officer's DOB was
        # SILENTLY NOT TRANSMITTED -- the query still ran, just broader than asked for. Caught by
        # audit_devdoc_optionals: "#1 +[BirthDate] -> fires DN but optional(s) BirthDate are in NO
        # matching combo's set[]/any[]".
        # ORDER IS LOAD-BEARING: DN's set[] is a strict SUBSET of this one, so QWA must precede DN or DN
        # keeps winning and this path is dead on arrival.
        # Gated exactly like DN (in-state, OLN>Name guardrail). QWA{Name} defines no State, so a
        # State-bearing name search still routes to DQ.N, the variant that does define it.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate'); any = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In'
        }
        # DN -- in-state Name (no State). OLN>Name guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst'); any = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');     operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DN'
            state                 = 'In'
        }
    )
    description     = 'DriverLicenseQuery -- DQ.O/DL (OLN), DQ.N/DN (Name). OLN>Name + State In/Out gates. ImageIndicator (Y) only on DQ.O.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# DriverHistoryQuery -- KQ.N (Name+DOB+Sex), KQ.O (OLN). DH-suffix fieldIds isolate from
# DL field pool (AP #14). OLN>Name guardrail (KQ.N: OperatorLicenseNumberDH NOT_EXISTS).
# Attention auto-handler via hidden 'attention' feeder + defaults[] (eSUN pattern).
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
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.N: Name+DOB+Sex (Name before OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH'); any = @('purposeCodeDH','RegistrationState','attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ.O: OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH'); any = @('purposeCodeDH','RegistrationState','attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ.N (Name+DOB+Sex), KQ.O (OLN). DH-suffix fields. OLN>Name guardrail. Attention auto-handler. BMVIMS OLN shadow dropped.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# GunQuery -- QG (serial required; caliber/make/relatedHit optional any[]).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('gunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 23; sourceField = @('firearmMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('serialNumber');              targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('firearmMake','gunCaliber','relatedHitSearchIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial; caliber/make/relatedHit optional). NCIC firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# ArticleSingleQuery -- QA.S (serial+type), QA.N (NCIC#). serial>NCIC guardrail.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('serialNumber');              targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('articleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 9;  sourceField = @('NCICNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        # QA.S -- serial+type
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('articleTypeCode','serialNumber'); any = @('ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        # QA.N -- NCIC# (serial>NCIC guardrail)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NCICNumber'); any = @('ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
                conditions = @([PSCustomObject]@{ field = @('serialNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QA.N'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.S (serial+type), QA.N (NCIC#). serial>NCIC guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# BoatQuery -- BQ.H/BQ.R (Nlets, State), QB.H/QB.R (NCIC, Image/RelatedHit).
# State-existence routing + Hull>Reg guardrail. (metadata: BQ any=State; QB any=Image/RelatedHit)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
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
        # QB.H -- NCIC hull (no State; Image/RelatedHit)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber'); any = @('ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
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
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        # QB.R -- NCIC reg (no State; Image/RelatedHit). Hull>Reg guardrail
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber'); any = @('ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
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
    description     = 'BoatQuery -- BQ.H/BQ.R (Nlets, State), QB.H/QB.R (NCIC). State-existence routing + Hull>Reg guardrail.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$ohBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for OH_LEADS v${Version} -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), DH-suffix, existence-only routing gates + identifier-priority guardrails"
    name           = 'OH_LEADS'
    type           = 'BUNDLE'
    provider       = 'OH_LEADS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- 5 QIFs, multi-card layouts
#
# Vehicle:  6 cards (OPTIONS + PLATE + DEALER PLATE + VIN + NAME SEARCH + SSN SEARCH)
# Person:   5 cards (OPTIONS + DL-OLN + DL-NAME + DH-OLN + DH-NAME) -- DH-suffix visible cards
# Firearm:  1 card  (QG)
# Article:  1 card  (QA.S/QA.N)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REG SEARCH)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 6 cards
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
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
        id    = 'CARD_VEH_DEALER'
        title = 'DEALER PLATE'
        rows  = @(
            @{ id = 'ROW_VEH_DEALER_1'; cols = @('6'); fields = @(
                @{ id = 'DealerPlateType_Input'; node = Inp 'DealerPlateType' 'Dealer Plate Type (with Plate Number + Type)' '1' 'ROW_VEH_DEALER_1' }
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
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (with State, optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year (with State, optional)' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_NAME'
        title = 'NAME SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'OwnerFirstName_Input'; node = Inp 'OwnerFirstName' 'Owner First Name' '30' 'ROW_VEH_NAME_1' }
                @{ id = 'OwnerLastName_Input';  node = Inp 'OwnerLastName'  'Owner Last Name'  '30' 'ROW_VEH_NAME_1' }
            )}
            @{ id = 'ROW_VEH_NAME_2'; cols = @('6'); fields = @(
                @{ id = 'AddressCounty_Input'; node = Inp 'AddressCounty' 'County Code (optional)' '4' 'ROW_VEH_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SSN'
        title = 'SSN SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_SSN_1'; cols = @('6'); fields = @(
                @{ id = 'OwnerSocialSecurityNumber_Input'; node = Inp 'OwnerSocialSecurityNumber' 'Owner SSN' '9' 'ROW_VEH_SSN_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- OPTIONS (State) + PLATE (RP/RQ.P) + DEALER (ATDP) + VIN (RV/RQ.V) + NAME (RN) + SSN (RS)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 5 cards (DL + DH with DH-suffix visible cards)
# OPTIONS: State + Image (Image feeds DQ.O only)
# DL-OLN: OperatorLicenseNumber
# DL-NAME: NameFirst + NameLast + BirthDate + SexCode
# DH-OLN: OperatorLicenseNumberDH + PurposeCode + hidden Attention feeder
# DH-NAME: NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (out-of-state OLN, optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'DRIVER LICENSE - OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
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
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (out-of-state)' 'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex (out-of-state)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DRIVER HISTORY - OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number' '20' 'ROW_PER_DH_OLN_1' }
                @{ id = 'PurposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (optional)' '1' 'ROW_PER_DH_OLN_1' }
            )}
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' } }
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
    description  = 'Person queries -- OPTIONS + DL-OLN (DQ.O/DL) + DL-NAME (DQ.N/DN) + DH-OLN (KQ.O) + DH-NAME (KQ.N). DH-suffix visible cards.'
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
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Y for NCIC stolen-gun check (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial; caliber/make/relatedHit optional). Single card.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA.S serial+type / QA.N NCIC#)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number (with Article Type)' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('12'); fields = @(
                @{ id = 'NCICNumber_Input'; node = Inp 'NCICNumber' 'NCIC Number' '9' 'ROW_ART_2' }
            )}
            @{ id = 'ROW_ART_3'; cols = @('6','6'); fields = @(
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_3' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Y for NCIC stolen-article check (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_ART_3' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA.S (serial+type), QA.N (NCIC#). Single card.'
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
            @{ id = 'ROW_BOA_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image (in-state blank, optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_OPT_1' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Y for NCIC stolen-boat check (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_BOA_OPT_1' }
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
    description  = 'Boat queries -- OPTIONS (State + Image + RelatedHit) + HULL (BQ.H/QB.H) + REG (BQ.R/QB.R)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs -- PascalCase USx form-fed refs)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ohBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built OH_LEADS v${Version}" `
    -Version $Version
