# build_ca_san_luis_obispo.ps1  -- CA_SAN_LUIS_OBISPO (galvanized v2.0)
# v2.4 (2026-08-17, CA-FAMILY HEADER FIX): added <Authentication>/<DeviceId> via Build-Auth
#   -IncludeDeviceId. CA devdoc: the agency-assigned CLETS Terminal Identifier belongs in that
#   header field, required wherever CLETS mnemonic pooling is used (else ConnectCIC falls back to
#   the server IP). Found because CA_CLETS was FAILING AT MARIPOSA (LIVE) without it; Rob ruled it
#   required on ALL SIX CA providers. Rides in AUTH any[], never set[] (pooling-only per devdoc).
#   No form control needed -- DeviceId is in validate.ps1's $systemSourceFields with ORI/Mnemonic.
# Single-JSON PascalCase build (consolidated from the legacy BASE+MC dual scripts 2026-07-23).
# Native PascalCase USx CAD fieldIds (was camelCase MC); Build-RmsBundle -PascalCaseUsxFields.
# Multi-card. NO cross-entity combos (SLO has no VP/QGH/BQ.N in metadata).
# CAD_DISPATCH + FIRST_RESPONDER context cards. phases/ retired (git history is authoritative).
#
# KEY DIFFERENCE FROM CA_CLETS MC / CA_VENTURA_COUNTY MC:
#   CaRequestPurposeCode    -- added to DH QIDM PurposeCode attr. Visible Inp initialValue='C'.
#   Regional message switch -- NOT a direct CLETS interface.
#   No ImageIndicator -- not in SLO metadata.
#   Shorter keyRefs than CLETS (QV not IA.QV, BQ not IA.QB, etc.)
#   DriverHistoryQuery has in-state combos (B2.N, B2.O) in addition to KQ OOS.
#   DL and DH use DH-suffix fieldIds for isolation (AP #14 pattern).
#   No State initialValue -- LIMITATION #30: separate in-state vs OOS keyRefs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_san_luis_obispo_mc.ps1

param(
    [string]$Version = '2.5'
)

$ErrorActionPreference = "Stop"
$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\CA_SAN_LUIS_OBISPO_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- ConnectCIC requires unique keyRefs per QIDM; SLO uses regional
# short keyRefs, most-specific-first, with identifier-priority guardrails NOT_EXISTS conditions):
#   VehicleRegistrationQuery : RQ.P, RQ.V, QV.P, QV.V   (Plate>VIN guardrail on RQ.V/QV.V)
#   DriverLicenseQuery       : L1.N, DQ.O, L1.O          (OLN>Name guardrail on L1.N)
#   DriverHistoryQuery       : KQ.N, B2.N, KQ.O, B2.O    (DH-suffix; OLN>Name guardrail on KQ.N/B2.N)
#   BoatQuery                : BQ (hull), QB (reg)       (Hull>Reg guardrail on QB)

# =====================================================================
# BUNDLE 1: CA_SAN_LUIS_OBISPO PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_SAN_LUIS_OBISPO' -IncludeDeviceId

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'CA_SAN_LUIS_OBISPO'

$qmf = Build-Qmf -ProviderName 'CA_SAN_LUIS_OBISPO'

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase, NO cross-entity
# 4 combos: RQ.P (OOS plate), RQ.V (OOS VIN), QV.V (VIN in-state), QV.P (plate in-state)
# NO CaRequestPurposeCode.
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
        # OOS Plate (4 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState'); any = @('VehicleMakeCode','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # OOS VIN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationState','VehicleIdentificationNumber'); any = @('VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state Plate (1 set -- plate before VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('LicensePlateTypeCode','LicensePlateYear'); defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        # In-state VIN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ.P (OOS plate), RQ.V (OOS VIN), QV.P (plate), QV.V (VIN). Most-specific first, plate before VIN. MC PascalCase.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_SAN_LUIS_OBISPO_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_SAN_LUIS_OBISPO'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase, autoSelect + queriesToDeselect DH
# 3 combos: L1.N (Name), DQ.O (OOS OLN), L1.O (OLN in-state)
# NO CaRequestPurposeCode.
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 17; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # ── v2.2: DQ.N + QVC.N ADDED. Two metadata name-branches had NO built combination at all, so
        # every name search fell through to L1.N -- whose set[] is just Name -- and anything more the
        # officer typed was SILENTLY NOT TRANSMITTED. From this provider's own metadata:
        #     DQ{Name}  = Set[BirthDate, Name, SexCode, State]   <- State MANDATORY here
        #     QVC{Name} = Set[Name, BirthDate, SexCode]          <- no <Any> at all
        #     L1{Name}  = Set[Name] Any[BirthDate]               <- SexCode NOT permitted
        # audit_devdoc_optionals caught the symptom ("DriverLicenseQuery #3 +[State] -> fires L1.N but
        # optional(s) State are in NO matching combo's set[]/any[]") and audit_requirement_fidelity
        # caught the cause independently ("built 'L1.N' UNDER-REQUIRED vs DQ: SexCode (built any[]);
        # State (ABSENT)"). Two gates, one defect, arrived at from different directions.
        # ORDER IS LOAD-BEARING: L1.N's set[] is a strict SUBSET of both new combos, so if it stayed
        # first it would keep stealing every fill and the new paths would be dead on arrival.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode','RegistrationState'); any = @('NameMiddle','NameSuffix')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode'); any = @('NameMiddle','NameSuffix')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QVC.N'
            state                 = 'In/Out'
        }
        # Name catchall (2 set) -- devdoc DriverLicenseQuery #1 "Name, [BirthDate]".
        # v2.2: SexCode REMOVED from any[]. Metadata L1{Name} is Set[Name] Any[BirthDate] and does not
        # define SexCode at all, so carrying it here was OVER-PERMITTING. A name search that includes
        # Sex now routes to QVC.N / DQ.N, which are the variants that actually define it.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('BirthDate','NameMiddle','NameSuffix'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        # OOS OLN (2 set -- OLN + State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.N (Name), DQ.O (OOS OLN), L1.O (OLN). autoSelect+queriesToDeselect DH. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_SAN_LUIS_OBISPO_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_SAN_LUIS_OBISPO'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# 1f. DriverHistoryQuery -- PascalCase, DH-suffix fieldIds (AP #14 pattern)
# DH-suffix fields: OperatorLicenseNumberDH, NameLastDH, NameFirstDH, BirthDateDH, SexCodeDH, CaRequestPurposeCodeDH
# PurposeCode: sourced from CaRequestPurposeCodeDH.
# Combo ordering: most set[] first (Name before OLN within each group).
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCodeDH'); targetField = 'PurposeCode' }
        # v2.3: Attention -- metadata defines it in <Any> on ALL FOUR DriverHistoryQuery variants
        # (KQ{Name}, KQ{OLN}, B2{Name}, B2{OLN}) and the devdoc lists it on #3/#4. It was wired
        # nowhere. On the approved automated-identity-field standard, so handler + hidden feeder
        # rather than an officer-typed control. DH-suffixed sourceField to stay out of the DL pool.
        # size 30 from this XML's own <Field maxLength>, read inside DriverHistoryQuery.
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('attentionDH'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
        }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific (4 DH set + State in any)
        [PSCustomObject]@{
            # RegistrationState MUST be in any[]: it is the OOS routing gate, but a gate
            # does not serialize. Without it the union pool (LIMITATION #1) was
            # BirthDate+Name+SexCode only, so the out-of-state DH-by-Name query went out
            # with NO destination State. Fixed 2026-07-29. Gate-XOR: the in-state twin
            # (B2.N) deliberately omits it.
            requirements          = [PSCustomObject]@{ set = @('NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH'); any = @('RegistrationState','caRequestPurposeCodeDH','attentionDH','NameMiddleDH','NameSuffixDH'); defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # In-state Name (3 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDateDH','NameLastDH','NameFirstDH'); any = @('SexCodeDH','caRequestPurposeCodeDH','attentionDH','NameMiddleDH','NameSuffixDH'); defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'B2.N'
            state                 = 'In/Out'
        }
        # OOS OLN (1 DH set + State in any)
        # KQ.O/B2.O were BOTH ungated with an identical set[OperatorLicenseNumberDH], so
        # KQ.O (ordered first) always won and B2.O could never fire -- a dead combo. The
        # sibling Name pair above was already gated this way; the OLN pair was missed.
        # Same fix CA_VENTURA_COUNTY received (NLTS.KQ.O EXISTS / ID.B2 NOT_EXISTS).
        # Existence-only, so poisoned-array-safe. Found 2026-07-29 by
        # audit_combo_reachability.ps1.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('RegistrationState','caRequestPurposeCodeDH','attentionDH'); defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (1 DH set) -- gate-XOR: State is the discriminator, so it is NOT in any[]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('caRequestPurposeCodeDH','attentionDH'); defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' }, [PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'B2.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- DH-suffix fields. KQ.N (Name OOS), B2.N (Name in-state), KQ.O (OLN OOS), B2.O (OLN in-state). autoSelect+queriesToDeselect DL. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_SAN_LUIS_OBISPO_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_SAN_LUIS_OBISPO'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1g. GunQuery -- PascalCase, NO cross-entity
# 1 combo: QGB (serial). No name search for SLO.
# NO CaRequestPurposeCode.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('GunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('GunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial). Firearm query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_SAN_LUIS_OBISPO_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_SAN_LUIS_OBISPO'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- PascalCase
# 1 combo: QA (serial).
# NO CaRequestPurposeCode.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('articleBrand','articleCategory','ArticleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial). Property inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_SAN_LUIS_OBISPO_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_SAN_LUIS_OBISPO'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- PascalCase, NO cross-entity
# 2 combos: BQ (hull), QB (reg).
# NO CaRequestPurposeCode.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('BoatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('RegistrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('RegistrationState'); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (hull), QB (reg). Boat inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_SAN_LUIS_OBISPO_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_SAN_LUIS_OBISPO'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$sloBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_SAN_LUIS_OBISPO v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'CA_SAN_LUIS_OBISPO'
    type           = 'BUNDLE'
    provider       = 'CA_SAN_LUIS_OBISPO'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  1 card  (SERIAL SEARCH -- single combo, no OPTIONS needed)
# Article:  1 card  (SERIAL SEARCH -- single combo, no OPTIONS needed)
# Boat:     3 cards (OPTIONS + HULL SEARCH + REGISTRATION SEARCH)
#
# NO CaRequestPurposeCode on any form (field does not exist for SLO).
# NO cross-entity combos (no Name cards on Vehicle/Firearm/Boat).
# No State initialValue (LIMITATION #30 -- in-state vs OOS routing).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards (MC)
# OPTIONS: RegistrationState + LicensePlateTypeCode + LicensePlateYear
# PLATE SEARCH: LicensePlateNumber (QV.P / RQ.P)
# VIN SEARCH: VehicleIdentificationNumber + VehicleMakeCode + VehicleYear (QV.V / RQ.V)
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# Vehicle -- 1 card (v2.5, collapsed from 3: OPTIONS/PLATE/VIN)
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
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card: Plate + VIN. Blank State routes the in-state CA keyRef.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 2 cards (v2.5, collapsed from 5)
# The DL card carries State as SHARED CONTEXT; the DH combinations read it too (one form,
# one field pool -- cards are visual grouping only). The DH pool has its own purpose code.
# The "(DH)" label suffixes are dropped -- the card title says DRIVER HISTORY. The fieldIds
# keep their DH suffix, which is what isolates the pool.
# NOTE the deliberate maxLen asymmetry: the DL control caps OLN at 17 and the DH control at
# 20, because each transaction caps it differently in this provider's own metadata.
# LABEL-OVERRIDE: caRequestPurposeCodeDH -- prefilled 'C', bare label per BUILD_RULES 11
# LABEL-OVERRIDE: NameMiddle -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameSuffix -- bare "Suffix", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameMiddleDH -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: attentionDH -- hidden gate-feeder, the label is dead text the officer never sees
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '17' 'ROW_PER_DL_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '5'  'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (optional)' 'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex (optional)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_1' }
                @{ id = 'CaRequestPurposeCodeDH_Input';  node = Inp 'caRequestPurposeCodeDH'  'Purpose Code' '1' 'ROW_PER_DH_1' @{ initialValue = 'C' } }
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
                @{ id = 'AttentionDH_Input'; node = InpH 'attentionDH' 'Attention' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards: DL (OLN or name, in and out of state) + DH. DH-suffix fieldIds isolate the DH pool.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'GunCaliber'   'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunTypeCode_Input';  node = Sel 'gunTypeCode'  'Type (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- 1 card: serial, with optional make/caliber/type.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand (optional)'    '6' 'ROW_ART_2' }
                @{ id = 'ArticleCategory_Input'; node = Inp 'articleCategory' 'Category (optional)' '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- 1 card: serial, with optional type/brand/category.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (v2.5, collapsed from 3). Hull leads Registration (identifier priority).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY HULL, OR REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card: Hull + Registration. Blank State routes the in-state CA keyRef.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $sloBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built CA_SAN_LUIS_OBISPO v${Version} (galvanized: single-JSON, native PascalCase USx fields)" `
    -Version $Version