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
#     ImageIndicator (Y) on every entity that defines it (v2.5). QWA deferred (non-basic); ImageQuery REMOVED v2.6 by directive.
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
$Version     = '2.9'
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('OwnerLastName','OwnerFirstName','OwnerMiddleName','OwnerNameSuffix'); targetField = 'Name'
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
                # v2.2: RegistrationState PROMOTED from any[] to set[]. Metadata RQ{LicensePlateNumber}
                # is Set[State, LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear] with NO
                # <Any> at all -- State is MANDATORY. Behaviour is unchanged, because the
                # `RegistrationState EXISTS` condition below already made it impossible for this combo
                # to fire without a state; the promotion just states the requirement where the platform
                # reads it instead of relying on a condition to imply it, and it clears the
                # audit_requirement_fidelity UNDER-REQUIRED finding ("State (built any[])").
                # The EXISTS condition is KEPT: it is what routes an in-state plate to RP instead, and
                # removing it would let this OOS combo win in-state fills.
                set = @('RegistrationState','LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @()
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
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
    description     = 'DriverLicenseQuery -- DQ.O/DL (OLN), DQ.N/DN (Name). OLN>Name + State In/Out gates. ImageIndicator (Y) on DQ.O.'
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
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
                defaults = @([PSCustomObject]@{ field = 'purposeCodeDH'; value = 'C' })
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
                defaults = @([PSCustomObject]@{ field = 'purposeCodeDH'; value = 'C' })
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
# ImageQuery -- REMOVED at v2.6 BY DIRECTIVE. Rob 2026-08-18: "the image query needs to go
# away  be sure to remove it before we start".
#
# It was BUILT at v2.4 (also his call: audit_supported_queries CHECK 0 had reported it as a
# devdoc-Basic query that was neither built nor documented as a skip). That reasoning is not
# withdrawn -- it is SUPERSEDED. This is now an APPROVED SKIP with named authority, which is
# exactly what CHECK 0 asks for; the same disposition FL_FCIC carries for ITS ImageQuery
# ("ImageQuery = user-approved scope" in its registry, "APPROVED SKIP" in its BUILD_NOTES).
#
# WHAT IT WAS: one combination, keyReference BMVIMS, primaryFieldReference OperatorLicenseNumber,
# Set[OperatorLicenseNumber] and nothing else, autoSelect=$false so it rendered as a named opt-in
# checkbox ("Driver Photo") rather than co-firing on every OLN entry.
#
# NOTHING ELSE HAS TO COME OUT, and that is a property of how it was built, not luck: it carried
# NO form controls of its own (it reused the Driver License card OLN), NO queriesToDeselect wiring
# in either direction, and no card of its own. So this removal cannot orphan a control or strand a
# deselect reference. The OLN control stays -- DriverLicenseQuery DQ.O needs it.
#
# IN-BAND DRIVER IMAGES ARE UNAFFECTED. ImageIndicator still rides in DQ.O any[] at Y, so a
# licence check still asks for the photo in the DriverLicenseQuery itself. What goes away is the
# SEPARATE standalone photo transaction, not the image capability.
#
# SIDE EFFECT WORTH KNOWING: BMVIMS is no longer a BUILT keyRef anywhere on OH_LEADS. That
# dissolves the registry conflict recorded in v2.5 BUILD_NOTES -- the row
# "DriverHistoryQuery | BMVIMS | dropped-combo" was tripping audit_requirement_fidelity's
# OVER-SUPPRESSION NOTE precisely BECAUSE BMVIMS named a combo we built here. With ImageQuery
# gone there is no built BMVIMS to over-suppress. Do not "restore" ImageQuery to satisfy a gate.
# =====================================================================

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
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('firearmMake','gunCaliber','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' }) }
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
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        # QA.N -- NCIC# (serial>NCIC guardrail)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NCICNumber'); any = @('ImageIndicator','relatedHitSearchIndicator')
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
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
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
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
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'relatedHitSearchIndicator'; value = 'Y' })
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
#
# v2.3 DEX-1284 LEAN-LABEL PASS. The four tags below declare labels deliberately left BARE, which
# downgrades verify_build CHECK 15 from WARN to INFO (the documented mechanism -- IL_LEADS_OFML
# carries 16 of them). Stripping the helper WITHOUT the tag is what produced 4 fresh WARNs on the
# first v2.3 build; the label and the tag are one change, not two.
# LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284, canonical on FL/HI/IL/NY/TX (any[] optional)
# LABEL-OVERRIDE: firearmMake -- bare "Make" per DEX-1284 lean pass (any[] optional gun qualifier)
# LABEL-OVERRIDE: gunCaliber -- bare "Caliber" per DEX-1284 lean pass (any[] optional gun qualifier)
# LABEL-OVERRIDE: AddressCounty -- bare "County Code" per DEX-1284 lean pass (any[] optional owner-search qualifier)
# ------------------------------------------------------------------
# v2.4 CARD COLLAPSE 6 -> 1, matching the portfolio (every other provider runs one Vehicle card).
# The old six cards (OPTIONS / PLATE / DEALER PLATE / VIN / NAME / SSN) split ONE entity's search
# paths across six boxes and none of their titles said which query each path fires -- OH was the only
# provider of nine with 0 path-carrying titles. Routing is unchanged: not one set[], any[], condition
# or default moved. The card TITLE now carries the paths, which is what lets the field labels go bare
# (the "(with State, optional)" / "(with Plate Number + Type)" hints below were doing the title's job).
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = "VEHICLE SEARCH BY PLATE, `nDEALER PLATE, VIN, OWNER NAME OR OWNER SSN `n(leave State blank for OH; fill it for an out-of-state Nlets query)"
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'OwnerFirstName_Input';  node = Inp 'OwnerFirstName'  'First Name'  '30' 'ROW_VEH_3' }
                @{ id = 'OwnerLastName_Input';   node = Inp 'OwnerLastName'   'Last Name'   '30' 'ROW_VEH_3' }
                @{ id = 'OwnerMiddleName_Input'; node = Inp 'OwnerMiddleName' 'Middle Name' '30' 'ROW_VEH_3' }
                @{ id = 'OwnerNameSuffix_Input'; node = Inp 'OwnerNameSuffix' 'Suffix'      '5'  'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'OwnerSocialSecurityNumber_Input'; node = Inp 'OwnerSocialSecurityNumber' 'SSN' '9' 'ROW_VEH_4' }
                @{ id = 'AddressCounty_Input';     node = Inp 'AddressCounty' 'County Code' '4' 'ROW_VEH_4' }
                @{ id = 'DealerPlateType_Input';   node = Inp 'DealerPlateType' 'Dealer Plate Type' '1' 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- ONE card (v2.4, collapsed from 6): plate RP/RQ.P, dealer ATDP, VIN RV/RQ.V, owner name RN, owner SSN RS; State routes in-state vs Nlets'
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
# v2.4 CARD COLLAPSE 5 -> 2 (Driver License + Driver History), the portfolio Person shape used by
# HI_HCJDC_OFML, NY_NYSPIN_EJUSTICE, TX_TLETS and AZ_AZDPS. The old OPTIONS card held State and
# NCIC Image detached from the searches they qualify; the DL and DH paths each had their own box.
# DH keeps its OWN card because the DH-suffix fieldIds are a separate field pool -- that is the
# isolation mechanism, not a layout accident, so the two cards must NOT merge.
# At v2.4 this card also served ImageQuery off the same OperatorLicenseNumber control; ImageQuery
# was REMOVED at v2.6 by directive, and because it never had a control of its own the card is
# unchanged by that removal (see the ImageQuery removal record above).
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = "DRIVER LICENSE SEARCH BY OLN, `nOR BY NAME (add DOB + SEX for an out-of-state search) `n(leave State blank for OH)"
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_1' }
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '5'  'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = "DRIVER HISTORY SEARCH BY OLN, `nOR BY NAME + DOB + SEX `n(own field pool -- filling these does not affect the Driver License card)"
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name'  '30' 'ROW_PER_DH_1' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name' '30' 'ROW_PER_DH_1' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'   '30' 'ROW_PER_DH_1' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix'      '5'  'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_2' }
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth' 'ROW_PER_DH_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_2' }
                @{ id = 'PurposeCodeDH_Input'; node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DH_2' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_DH_ATTN' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- TWO cards (collapsed from 5 at v2.4): Driver License (DQ.O/DL OLN, DQ.N/DN name) and Driver History (KQ.O OLN, KQ.N name) on its own DH-suffix field pool'
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
        title = "FIREARM SEARCH BY SERIAL NUMBER `n(Make, Caliber and Stolen Check are optional refinements)"
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
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
        title = "ARTICLE SEARCH BY SERIAL NUMBER + TYPE, `nOR BY NCIC NUMBER"
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input'; node = Inp 'NCICNumber' 'NCIC Number' '9' 'ROW_ART_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
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
# v2.4 CARD COLLAPSE 3 -> 1. Hull and Registration were separate boxes with an OPTIONS card holding
# the three qualifiers that apply to BOTH. Hull beats Registration on co-entry (BQ.R/QB.R carry
# BoatHullIdNumber NOT_EXISTS) -- the title now says so, which is where an identifier-priority hint
# belongs. Routing untouched.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = "BOAT SEARCH BY HULL ID, `nOR BY REGISTRATION NUMBER (Hull wins if both are entered) `n(leave State blank for OH)"
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- ONE card (v2.4, collapsed from 3): hull BQ.H/QB.H, registration BQ.R/QB.R, State routes in-state vs Nlets'
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
