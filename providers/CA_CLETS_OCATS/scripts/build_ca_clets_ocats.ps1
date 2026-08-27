# build_ca_clets_ocats.ps1  -- CA_CLETS_OCATS (galvanized v2.0, single-JSON native PascalCase)
# v2.4 (2026-08-17, CA-FAMILY HEADER FIX): added <Authentication>/<DeviceId> via Build-Auth
#   -IncludeDeviceId. CA devdoc: the agency-assigned CLETS Terminal Identifier belongs in that
#   header field, required wherever CLETS mnemonic pooling is used (else ConnectCIC falls back to
#   the server IP). Found because CA_CLETS was FAILING AT MARIPOSA (LIVE) without it; Rob ruled it
#   required on ALL SIX CA providers. Rides in AUTH any[], never set[] (pooling-only per devdoc).
#   No form control needed -- DeviceId is in validate.ps1's $systemSourceFields with ORI/Mnemonic.
# MC variant: PascalCase fieldIds, no Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combos (VP name on Vehicle).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_clets_ocats_mc.ps1

$ErrorActionPreference = "Stop"
$Version     = '2.8'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\CA_CLETS_OCATS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }


. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; OCATS regional short keyRefs +
# identifier-priority guardrails + OOS RegistrationState EXISTS/NOT_EXISTS routing gates):
#   VehicleRegistrationQuery : RQ.P, RQ.V, VP (owner name), 4V, 4   (Plate>VIN guardrail on RQ.V/4V)
#   DriverLicenseQuery       : DQ.N, DQ.O, L1.N, L1.O               (OLN>Name guardrail on DQ.N/L1.N)
#   ArticleSingleQuery       : QA.S (serial), QA.O (OAN)
#   BoatQuery                : BQ.H, BQ.R, 4V.B, QB.O, 4B  (Hull>Reg guardrail on BQ.R/4B; dropped stolen QB.H/QB.R dups)

# =====================================================================
# BUNDLE 1: CA_CLETS_OCATS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CLETS_OCATS' -IncludeDeviceId

$results = Build-ProviderQrdm -ProviderName 'CA_CLETS_OCATS'

$qmf = Build-Qmf -ProviderName 'CA_CLETS_OCATS'

# VehicleRegistrationQuery -- PascalCase + cross-entity (Name for VP combo)
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'BusinessIndicator';           size = 1;  sourceField = @('businessIndicator');           targetField = 'BusinessIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 35; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
        # ── v2.1: AWVEHQ support (devdoc VehicleRegistrationQuery #2). Sizes from this XML's own
        # <Field maxLength>, READ INSIDE Transaction=VehicleRegistrationQuery (v2.3 correction -- the
        # original read was transaction-blind and got Authorization wrong; see its note below):
        # UserId 2, ExactSearchIndicator 1, Authorization 1, PageNumber 2,
        # LicensePlateStateCode 2. All five are metadata-defined for this transaction, and the devdoc
        # lists the latter four as optionals on #2 -- so they are carried rather than dropped, or a
        # devdoc-legal fill would silently fail to transmit them.
        [PSCustomObject]@{ name = 'UserId';                size = 2; sourceField = @('userId');                targetField = 'UserId' }
        [PSCustomObject]@{ name = 'ExactSearchIndicator';  size = 1; sourceField = @('exactSearchIndicator');  targetField = 'ExactSearchIndicator' }
        # size 1, NOT 2 (fixed v2.3). Authorization is defined EIGHT times in this XML: maxLength 2
        # under the seven OcatsWarrantQuery* transactions, and maxLength 1 under
        # VehicleRegistrationQuery -- which is the transaction this AWVEHQ combination belongs to.
        # v2.1 took the size from OcatsWarrantQueryAWVEHQ, a DIFFERENT transaction that merely shares
        # the keyRef name, and audit_metadata had been warning "QIF maxLength 2 > XML maxLength 1 --
        # server may reject" ever since. The comment right above even flags that keyRef collision for
        # the COMBO lookup; the FIELD SIZE was then read from the wrong side of it. A keyRef is not a
        # variant, and that applies to field definitions exactly as it does to requirements.
        [PSCustomObject]@{ name = 'Authorization';         size = 1; sourceField = @('authorization');         targetField = 'Authorization' }
        [PSCustomObject]@{ name = 'PageNumber';            size = 2; sourceField = @('pageNumber');            targetField = 'PageNumber' }
        # LicensePlateStateCode is a DIFFERENT metadata field from State, but the officer input is the
        # same one -- so it reuses the existing RegistrationState control rather than adding a second
        # state dropdown. Two attributes may share a sourceField; only the targetField differs.
        [PSCustomObject]@{ name = 'LicensePlateStateCode'; size = 2; sourceField = @('RegistrationState');     targetField = 'LicensePlateStateCode'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # ── AWVEHQ (v2.1) -- devdoc "Basic Query Transactions" VehicleRegistrationQuery #2:
        #      "2. (In) LicensePlateNumber, UserId, [Authorization, ExactSearchIndicator, ...]"
        #    metadata (Transaction=VehicleRegistrationQuery, keyRef AWVEHQ):
        #      Set[CaRequestPurposeCode, LicensePlateNumber, UserId]
        #      Any[ExactSearchIndicator, Authorization, PageNumber, LicensePlateStateCode,
        #          VehicleYear, VehicleMakeCode]
        #    UserId was wired nowhere in this query, so this documented path could not run.
        #    Same BUILD_RULES 13 trap as OCNAMQ: keyRef AWVEHQ ALSO exists under
        #    Transaction=OcatsWarrantQueryAWVEHQ (not built). Scoped by (query, keyRef).
        #    Ordered FIRST -- 3 set[] fields, and the plate-only combos below are strict subsets of
        #    it, so an ungated subset ahead of it would steal every UserId fill.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','LicensePlateNumber','userId')
                any = @('exactSearchIndicator','authorization','pageNumber','RegistrationState','vehicleYear','VehicleMakeCode')
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'AWVEHQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','LicensePlateNumber','LicensePlateYear','RegistrationState'); any = @('LicensePlateTypeCode','VehicleMakeCode','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','VehicleIdentificationNumber','RegistrationState'); any = @('VehicleMakeCode','vehicleYear'); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # VC -- metadata Set[CaRequestPurposeCode, Name, BusinessIndicator]. Ordered AHEAD of VP because
            # VP's set[] is a strict SUBSET, so first-match would starve VC of every fill (usx-build Step 3).
            # BusinessIndicator is NOT prefilled ON PURPOSE: it is the only discriminator between VC and VP,
            # and a prefill would make VC always match and kill the plain owner-name search (BUILD_RULES 24).
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','NameLast','NameFirst','businessIndicator'); any = @('NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'VC'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','NameLast','NameFirst'); any = @('NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'VP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','VehicleIdentificationNumber'); any = @(); conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = '4V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # 4K -- metadata Set[CaRequestPurposeCode, LicensePlateNumber, LicensePlateTypeCode]. Ordered ahead
            # of 4, whose set[] is a strict subset. REACHABLE ONLY BECAUSE the LicensePlateTypeCode form
            # prefill was removed at v2.6: with 'PC' prefilled, 4K's set collapsed to [Plate] and collided
            # EXACTLY with 4, which no ordering can separate (BUILD_RULES 24 / the AZ DQPN case). CAD still
            # gets PC from defaults[] here and on RQ.P -- combo defaults[] do not affect ROUTING.
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','LicensePlateNumber','LicensePlateTypeCode'); any = @(); defaults = @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = '4K'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # 4 any[] is EMPTY to match metadata: its <Any> defines NOTHING. The five optionals it used to
            # carry (State, PlateType, PlateYear, VehicleMake, VehicleYear) are defined by OTHER variants
            # (RQ, QV, AWVEHQ) and were reported as OVER-PERMITTED on this branch.
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','LicensePlateNumber'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = '4'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- 4 (plate), 4V (VIN), RQ (OOS plate/VIN), VP (name). MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_CLETS_OCATS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_CLETS_OCATS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# DriverLicenseQuery -- PascalCase
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        # v2.1: UserId, for the OCNAMQ combination below. maxLength 2 per this XML's own
        # <Field maxLength> -- it is a short OCATS terminal/user code, NOT a person's name or login.
        [PSCustomObject]@{ name = 'UserId'; size = 2; sourceField = @('userId'); targetField = 'UserId' }
    )
    combinations = @(
        # ── OCNAMQ (v2.1) -- devdoc "Basic Query Transactions" DriverLicenseQuery #1:
        #      "1. (In) BirthDate, Name, SexCode, UserId"   -- all four UNBRACKETED = MANDATORY
        #    metadata (Transaction=DriverLicenseQuery, keyRef OCNAMQ):
        #      Set[CaRequestPurposeCode, UserId, SexCode, BirthDate, Name]  -- no <Any> at all
        #    Both authorities agree exactly, so this is a straight build. It was UNBUILT: UserId was
        #    wired nowhere in this query, so a documented in-state OCATS name search could not run.
        #
        #    SCOPE NOTE, because this looked out-of-scope at first glance: this devdoc uses the
        #    heading "Basic Query Transactions:" rather than "Basic Queries Supported", and UserId
        #    ALSO appears on ~20 OCATS-specific transactions (warrants / juvenile / LARS) that are
        #    deliberately not built. The deciding fact is that the SAME keyRef exists under TWO
        #    different <Transaction> parents -- OCNAMQ under DriverLicenseQuery (Basic, this one) and
        #    OCNAMQ under OcatsWarrantQueryOCNAMQ (not built). Resolving it by bare keyRef would have
        #    mapped this to the warrant query and dismissed a real Basic gap: BUILD_RULES 13, key a
        #    combo lookup by (query, keyRef), never by keyRef alone.
        #
        #    Ordered FIRST: 6 set[] fields make it the most specific combination in this QIDM, and it
        #    is gated OLN NOT_EXISTS for identifier priority. DQ.N (also 6) requires State while this
        #    requires UserId, so the two are disjoint rather than competing.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','userId','SexCode','BirthDate','NameLast','NameFirst')
                any        = @('NameMiddle','NameSuffix')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'OCNAMQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # v2.8: RegistrationState DEMOTED set[] -> any[] and its EXISTS gate REMOVED.
            # Metadata DQ{Name} = Set[CaRequestPurposeCode, Name, BirthDate, SexCode] Any[State] --
            # State is OPTIONAL there. Promoting it into set[] made this combination reachable ONLY
            # out of state, so devdoc #4 "(mand) BirthDate, Name, SexCode [opt State]" filled without
            # a State fell through to L1.N (set=[purposeCode, Name], any=[BirthDate, ...]) and the
            # officer's SexCode was SILENTLY DISCARDED -- L1.N carries BirthDate in any[] but not
            # SexCode. Same anti-pattern as TN_TIES KQ.N and NM_NMLETS_OFML RQ.P: never gate on a
            # field the metadata merely permits.
            # L1.N KEEPS its `RegistrationState NOT_EXISTS` gate deliberately: metadata L1{Name}
            # does not define State at all, so without that gate a Name+State fill would match L1.N
            # and drop the State silently. DQ.N is a strict superset of L1.N and is ordered first, so
            # Name+DOB+Sex now reaches DQ.N while a name-only search still reaches L1.N.
            # SCOPE: DQ.N only. DQ.O keeps RegistrationState in set[] because it is the ONLY
            # discriminator against L1.O -- both are set[purposeCode, OperatorLicenseNumber] and
            # demoting it would collapse them into an exact collision that ordering cannot separate.
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','NameLast','NameFirst','BirthDate','SexCode'); any = @('RegistrationState','NameMiddle','NameSuffix'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','OperatorLicenseNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','NameLast','NameFirst'); any = @('BirthDate','NameMiddle','NameSuffix'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','OperatorLicenseNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.O (OLN), L1.N (Name), DQ.O (OOS OLN), DQ.N (OOS Name).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# GunQuery -- PascalCase. No QGH (gun by name) in OCATS metadata.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('GunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('GunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial). OCATS firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# ArticleSingleQuery -- PascalCase
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 11; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','ArticleTypeCode','articleCategory') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('articleBrand','ArticleTypeCode','articleCategory') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial, OAN). OCATS property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('BoatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('RegistrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','BoatHullIdNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','RegistrationNumber','RegistrationState'); any = @(); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }) }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = '4V.B'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QB.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','RegistrationNumber'); any = @(); conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }, [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = '4B'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- 4B (reg), 4V.B (hull), BQ.H/BQ.R (OOS), QB.O (OAN). v2.0: dropped stolen QB.H/QB.R (form-identical to 4V.B/4B; server routes by keyRef -- CA_CLETS IV.4* precedent).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# ─── v2.2: caRequestPurposeCode COMBO DEFAULT on every combination ────────────────────────────
# THIS PROVIDER'S OWN DEVDOC, "Transaction Requirements": CLETS requires a Purpose Code on EVERY
# transaction, and "Any transaction which does not supply a valid Purpose Code value will be
# REJECTED by CLETS. ConnectCIC does not default the value of field; it must be provided by the
# partner implementation as a user selectable field."
# It is a TRANSACTION-ENVELOPE requirement, not a per-query search field -- which is why the devdoc's
# per-query "Possible Combinations" lists never mention it, why all 19 built combos carry it in set[],
# and why a devdoc-faithful fill matched NOTHING (build_phase1 reported ArticleSingleQuery #1 as
# "NO COMBO FIRES" on all four of its optional subsets -- one missing envelope field, four findings).
# WHY THE COMBO DEFAULT IS REQUIRED INDEPENDENTLY OF ANY GATE: CAD does not apply form initialValues
# (BUILD_RULES 12), so a CAD-dispatched query omitted the field entirely and CLETS would REJECT the
# whole transaction. 0 of 19 combos had a default. That is a live defect on the CAD path.
# 'C' = Criminal Justice. The risk is asymmetric: blank is a guaranteed CLETS rejection, whereas C can
# never silently become an immigration-enforcement purpose. The control stays a VISIBLE, EDITABLE Inp
# on all five cards, so it remains "user selectable" exactly as the devdoc requires -- pre-selected,
# not locked. Prefilling is LOAD-BEARING, not a BUILD_RULES 24 violation: it is mandatory in EVERY
# combination, so satisfying it equally for all of them cannot shadow one path over another.
# Same shape fixed on CA_eSUN v2.2, but decided here from THIS provider's own devdoc.
foreach ($q in @($vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)) {
    foreach ($cm in @($q.combinations)) {
        $needs = @($cm.requirements.set | Where-Object { "$_" -match 'urposeCode' })
        if (-not $needs.Count) { continue }
        $existing = @($cm.requirements.defaults | Where-Object { $_ -and "$($_.field)" -match 'urposeCode' })
        if ($existing.Count) { continue }
        $nd = [PSCustomObject]@{ field = [string]$needs[0]; value = 'C' }
        if ($cm.requirements.PSObject.Properties.Name -contains 'defaults' -and $cm.requirements.defaults) {
            $cm.requirements.defaults = @(@($cm.requirements.defaults) + $nd)
        } else {
            $cm.requirements | Add-Member -MemberType NoteProperty -Name 'defaults' -Value @($nd) -Force
        }
    }
}
$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_CLETS_OCATS v${Version} MC -- 5 QIDMs (VehReg + DL + Gun + Article + Boat), no DH"
    name           = 'CA_CLETS_OCATS'
    type           = 'BUNDLE'
    provider       = 'CA_CLETS_OCATS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE SEARCH + VIN SEARCH + NAME SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH) -- DL only, no DH
# Firearm:  2 cards (OPTIONS + SERIAL SEARCH) -- no NAME card (no QGH)
# Article:  3 cards (OPTIONS + SERIAL SEARCH + OAN SEARCH)
# Boat:     5 cards (OPTIONS + HULL + REGISTRATION + OAN + STOLEN)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState,
# CaRequestPurposeCode) live on a separate card to avoid duplicate fieldId
# across cards (= ISE). NCIC state pattern: visible RegistrationState,
# NO initialValue (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN + VehicleMake + VehicleYear
# NAME SEARCH: First + Last (cross-entity VP)
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# Vehicle -- 1 card (v2.7, collapsed from 4: OPTIONS/PLATE/VIN/NAME)
# CRITICAL, do not "restore" these: LicensePlateTypeCode carries NO initialValue and
# businessIndicator carries NO initialValue. Both are ROUTING DISCRIMINATORS -- PlateType is
# what separates built 4K from 4, businessIndicator is what separates VC from VP -- and a
# prefill on either makes it always-present and kills the plainer sibling (BUILD_RULES 24).
# LABEL-OVERRIDE: LicensePlateYear -- prefilled current year, bare-ish label per BUILD_RULES 11
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# LABEL-OVERRIDE: NameMiddle -- bare "Middle Name", DEX-1284 lean pass (any[] optional)
# LABEL-OVERRIDE: NameSuffix -- bare "Suffix", DEX-1284 lean pass (any[] optional)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH BY PLATE, VIN, OR OWNER NAME'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (optional)' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '30' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_VEH_3' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_VEH_3' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_VEH_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '5'  'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'BusinessIndicator_Input';    node = Sel 'businessIndicator' 'Business Owner' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_VEH_4' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_4' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_4' @{ initialValue = 'C' } }
                @{ id = 'UserId_Input';               node = Inp 'userId' 'OCATS User ID' '2' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('4','4','4'); fields = @(
                @{ id = 'Authorization_Input';        node = Inp 'authorization'        'Authorization (optional)' '1' 'ROW_VEH_5' }
                @{ id = 'ExactSearchIndicator_Input'; node = Inp 'exactSearchIndicator' 'Exact Search (optional)'  '1' 'ROW_VEH_5' }
                @{ id = 'PageNumber_Input';           node = Inp 'pageNumber'           'Page (optional)'          '2' 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card: Plate (4/4K) + VIN (4V) + Owner name (VP/VC). Blank State routes the in-state CA keyRef.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card (v2.7, collapsed from 3). OCATS builds no DriverHistoryQuery,
# so Person is legitimately ONE card, not the usual DL + DH pair.
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'DRIVER LICENSE SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '5'  'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'BirthDate_Input';            node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'SexCode_Input';              node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_3' @{ initialValue = 'C' } }
                @{ id = 'UserId_Input';               node = Inp 'userId' 'OCATS User ID' '2' 'ROW_PER_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 1 card: OLN + Name (incl. the OCATS OCNAMQ name search). No DriverHistoryQuery on OCATS, so no DH card.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (v2.7, collapsed from 2: OPTIONS/SERIAL)
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'GunCaliber'   'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunTypeCode_Input';          node = Sel 'gunTypeCode' 'Type (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_2' @{ initialValue = 'C' } }
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
# Article -- 1 card (v2.7, collapsed from 3: OPTIONS/SERIAL/OAN)
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL, OR OWNER APPLIED NUMBER'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';       node = Inp 'serialNumber'       'Serial Number' '11' 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'ArticleTypeCode_Input';      node = Sel 'ArticleTypeCode' 'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS_OCATS' } 'ROW_ART_2' }
                @{ id = 'ArticleBrand_Input';         node = Inp 'articleBrand'    'Brand (optional)' '6' 'ROW_ART_2' }
                @{ id = 'ArticleCategory_Input';      node = Inp 'articleCategory' 'Article Category (optional)' '1' 'ROW_ART_2' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_2' @{ initialValue = 'C' } }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article queries -- 1 card: Serial + Owner Applied Number.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (v2.7, collapsed from 4: OPTIONS/HULL/REGISTRATION/OAN)
# Hull leads Registration leads OAN -- identifier priority.
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY HULL, REGISTRATION, OR OWNER APPLIED NUMBER'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_2' @{ initialValue = 'C' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card: Hull + Registration + Owner Applied Number.'
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
    bundles = @($entitiesBundle, $caBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built CA_CLETS_OCATS v${Version}" `
    -Version $Version
