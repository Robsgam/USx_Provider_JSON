# build_ny_nyspin_ejustice_skilltest.ps1 -- NY_NYSPIN_EJUSTICE_SKILLTEST
# v1.0: Initial standup. Independent skill-test rebuild of the NY NYSPIN eJustice
# provider, scoped strictly to the devdoc's literal "Basic Queries Supported"
# section (6 queries). See build script header comments + BUILD_NOTES for the
# full rationale on scope and design decisions.
#
# SCOPE DECISION (judgment call -- see BUILD_NOTES / final report):
#   devdoc has a literal heading "Basic Queries Supported:" listing EXACTLY 6
#   queries: ArticleSingleQuery, BoatQuery, DriverHistoryQuery, DriverLicenseQuery,
#   GunQuery, VehicleRegistrationQuery. Canadian Basic Inquiries (CBI), Wanted
#   Missing Person Inquiries (WMP-I), and "Expanded Transactions Supported" (incl.
#   NyNyspinDriverLicenseNameQuery/DGRP, NyNyspinBoatBINQQuery,
#   NyNyspinBoatRegistrationNameQuery, NyNyspinVehicleRegistrationNameQuery,
#   NyNyspinNicbAllFilesQuery) are SEPARATE, later sections in the devdoc -- not
#   under "Basic Queries Supported". Per knowledge-base/README.txt SOURCE
#   AUTHORITY RULES ("DevDoc 'Basic Queries Supported' is the ONLY authority...
#   Metadata existence alone does NOT authorize building a query"), these 10
#   additional metadata transactions are OUT OF SCOPE for this build.
#
# METADATA VS DEVDOC DISCREPANCIES (MetaData wins per README.txt):
#   - DriverLicenseQuery: devdoc prose describes 4 Possible-Combinations rows
#     (2 In + 2 Out), but the metadata XML <Requirements> puts State inside
#     <Any> (not a <Choice>) for BOTH combos -- i.e. only 2 real combos exist,
#     each with State merely optional. LIMITATION #36 decision-rule case (A):
#     one combo, State in any[], do NOT invent a separate OOS combo.
#   - DriverHistoryQuery and VehicleRegistrationQuery (plate path) DO use a
#     <Choice> of two <Set>s (case B): the shorter in-state Set + the longer
#     OOS Set (adds PurposeCode/Requestor/State for DH; PlateType/PlateYear/
#     State for Vehicle plate). Each Choice was split into two built combos
#     (verified directly against the raw XML -- tools/extract_queries.ps1's
#     SQVR view silently drops the nested <Choice>, showing an empty set[] for
#     the affected combos; do not trust that view for Choice-bearing combos).
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 QIDMs, 16 combos):
#   VehicleRegistrationQuery  RVEH + RCAR + RVEHOUT + RVIN = 4 combos (Choice split on plate)
#   DriverLicenseQuery        DLIC + DLICN = 2 combos (metadata: State in any[], no Choice)
#   DriverHistoryQuery        DALH + DALL + DALHOUT + DALLOUT = 4 combos (Choice split on both paths), DH-suffix fields
#   GunQuery                  GINQ = 1 combo
#   ArticleSingleQuery        AINQ = 1 combo
#   BoatQuery                 RVEH + RCAR + BVEH + BVIN = 4 combos (flat, no Choice)
#
# COMBO ORDERING: devdoc "Possible Combinations" listing order in every QIDM
# (BUILD_RULES.txt Section 11 "DEVDOC-ORDER COMBOS + ROUTING CONDITIONS"),
# with existence-only routing conditions layered on so first-match evaluation
# stays correct (in-state combos gated RegistrationState NOT_EXISTS so they
# don't shadow the OOS combos that follow them in devdoc order).
#
# IDENTIFIER-PRIORITY GUARDRAILS (BUILD_RULES.txt): Plate>VIN (Vehicle),
# OLN>Name (Person DL + DH, DH keyed on the DH-suffixed OLN sourceField),
# Hull>Reg (Boat). Existence-only NOT_EXISTS conditions only (poisoned-array
# rule -- never a value-comparison operator).
#
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata reuses keyRef 'RVEH'/'RCAR' across BoatQuery and VehicleRegistrationQuery
# (disambiguated by targetEntity, not by keyRef) and reuses 'DALL' across the OLN
# and Name paths of DriverHistoryQuery. Synthetic labels DALH (Name path),
# DALLOUT/DALHOUT (OOS variants), RVEHOUT (OOS plate variant) are invented
# ConnectCIC-internal routing labels -- NOT real NYSPIN transaction codes.
# See PLATFORM_CONSTRAINTS.txt LIMITATION #21/#36 -- synthetic keyRef naming.
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_ny_nyspin_ejustice_skilltest.ps1 -Version 1.0

param(
    [string]$Version = "1.0"
)

$ErrorActionPreference = "Stop"
$provider = 'NY_NYSPIN_EJUSTICE_SKILLTEST'
$currentYear = [string](Get-Date).Year
$outPath  = "$PSScriptRoot\..\NY_NYSPIN_EJUSTICE_SKILLTEST_v${Version}.json"
$DATE     = (Get-Date -Format 'yyyy-MM-dd')

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 2: NY_NYSPIN_EJUSTICE_SKILLTEST PROVIDER
# (PascalCase for the 22 canonical USx CAD fields; camelCase for
#  provider-specific / Mark43-internal fields -- CLAUDE.md Field Config Rules)
# =====================================================================

$auth = Build-Auth -ProviderName $provider

$results = Build-ProviderQrdm -ProviderName $provider

$qmf = Build-Qmf -ProviderName $provider

# --- 1. VehicleRegistrationQuery -- 4 combos ---
# Metadata: RVEH has a <Choice> (in-state plate Set vs OOS plate+type+year+state Set).
# RCAR (VIN in-state) and RVIN (VIN+State OOS) are flat, real metadata keyRefs.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# RVEHOUT is a synthetic keyRef -- metadata's RVEH Choice extended-Set (OOS plate)
# has no keyRef of its own; RVEHOUT satisfies LIMITATION #36 case (B): dedicated OOS
# combo, State (the non-defaulted discriminator) in set[], LicensePlateTypeCode/
# LicensePlateYear (defaulted, LIMITATION #31) stay in any[] with combo defaults[].
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber'; size = 10; sourceField = @('LicensePlateNumber'); targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode'; size = 2; sourceField = @('LicensePlateTypeCode'); targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear'; size = 4; sourceField = @('LicensePlateYear'); targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode'; size = 4; sourceField = @('VehicleMakeCode'); targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear'; size = 4; sourceField = @('vehicleYear'); targetField = 'VehicleYear' }
    )
    combinations = @(
        # --- RVEH: in-state plate (Choice minimal Set). Devdoc combo #1. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('LicensePlateNumber')
                any        = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator';       value = 'N' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        # --- RCAR: in-state VIN. Devdoc combo #2. Plate>VIN + State-tier guardrails. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('VehicleIdentificationNumber')
                any        = @('ImageIndicator')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
        # --- RVEHOUT: OOS plate (Choice extended Set). Devdoc combo #3. Synthetic keyRef. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set      = @('LicensePlateNumber','RegistrationState')
                any      = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator';       value = 'N' }
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEHOUT'
            state                 = 'In/Out'
        }
        # --- RVIN: OOS VIN. Devdoc combo #4. Plate>VIN guardrail. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('VehicleIdentificationNumber','RegistrationState')
                any        = @('ImageIndicator','VehicleMakeCode','vehicleYear')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- 4 combos: RVEH (in-state plate), RCAR (in-state VIN), RVEHOUT (OOS plate, synthetic keyRef, Choice-split), RVIN (OOS VIN). Devdoc-order combo array + RegistrationState NOT_EXISTS on in-state combos + Plate>VIN guardrail (LicensePlateNumber NOT_EXISTS on RCAR/RVIN).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_VehicleRegistrationQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# --- 2. DriverLicenseQuery -- 2 combos ---
# Metadata: State lives in <Any> for BOTH combos (no <Choice>) -- LIMITATION #36
# decision-rule case (A). One combo per primary, State stays in any[]. Do NOT
# invent an OOS combo (would contradict the metadata's own field-authority).
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DLIC' for both combos; DLICN (Name path) is the synthetic
# label per the standard NY naming convention (DLIC -> DLICN).
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size = 35; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- DLIC: OLN path. DL-priority pattern: OLN first (higher-priority identifier). ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set      = @('OperatorLicenseNumber')
                any      = @('ImageIndicator','RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DLIC'
            state                 = 'In/Out'
        }
        # --- DLICN: Name+DOB+Sex path. OLN>Name guardrail (OperatorLicenseNumber NOT_EXISTS). ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('BirthDate','NameLast','NameFirst','SexCode')
                any        = @('ImageIndicator','RegistrationState','nameMiddle','nameSuffix')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DLICN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- 2 combos: DLIC (OLN), DLICN (Name+DOB+Sex, synthetic keyRef, OLN>Name guardrail). Metadata has State in any[] for both (no OOS Choice) -- LIMITATION #36 case A, single combo per primary is correct.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverLicenseQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# --- 3. DriverHistoryQuery -- 4 combos, DH-suffix fields ---
# Metadata: BOTH combos (OLN-primary, Name-primary) use a <Choice> of two <Set>s --
# LIMITATION #36 case (B). Each Choice is split into an in-state combo (minimal Set)
# and a synthetic OOS combo (extended Set, State/PurposeCode/Requestor required).
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'DALL' for BOTH the OLN-primary and Name-primary combos (and
# doesn't distinguish In/Out at all). DALH (Name path), DALLOUT (OOS OLN), DALHOUT
# (OOS Name) are ALL synthetic labels -- NOT real NYSPIN transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
#
# DH-suffix fieldIds isolate this QIDM's identity fields from DriverLicenseQuery's
# (AP #14 / LIMITATION #25). RegistrationState + ImageIndicator are DELIBERATELY
# NOT DH-suffixed -- they are the shared "Search Options" card fields (routing
# toggles, not identity fields) used by both DriverLicenseQuery and
# DriverHistoryQuery combos; a routing/optional-any[] field shared across combo
# families is the standard OPTIONS-card pattern (BUILD_RULES.txt Section 11), not
# a collision risk (only IDENTITY fields need DH-suffix isolation).
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 10; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size = 35; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NyNyspinTransactionName'; size = 4; sourceField = @('nyNyspinTransactionNameDH'); targetField = 'NyNyspinTransactionName' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'Requestor'; size = 35; sourceField = @('requestorDH'); targetField = 'Requestor' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- DALH: in-state Name+DOB+Sex (Choice minimal Set). Devdoc combo #1. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH')
                any        = @('ImageIndicator','nyNyspinTransactionNameDH','nameMiddleDH','nameSuffixDH')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH');     operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DALH'
            state                 = 'In/Out'
        }
        # --- DALL: in-state OLN (Choice minimal Set). Devdoc combo #2. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('OperatorLicenseNumberDH')
                any        = @('ImageIndicator','nyNyspinTransactionNameDH')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALL'
            state                 = 'In/Out'
        }
        # --- DALHOUT: OOS Name+DOB+Sex (Choice extended Set). Devdoc combo #3. Synthetic keyRef. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH','purposeCodeDH','requestorDH','RegistrationState')
                any        = @('ImageIndicator','nyNyspinTransactionNameDH','nameMiddleDH','nameSuffixDH')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                    [PSCustomObject]@{ field = 'PurposeCode';    value = 'C' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DALHOUT'
            state                 = 'In/Out'
        }
        # --- DALLOUT: OOS OLN (Choice extended Set). Devdoc combo #4. Synthetic keyRef. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set      = @('OperatorLicenseNumberDH','purposeCodeDH','requestorDH','RegistrationState')
                any      = @('ImageIndicator','nyNyspinTransactionNameDH')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }
                    [PSCustomObject]@{ field = 'PurposeCode';    value = 'C' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALLOUT'
            state                 = 'In/Out'
        }
    )
    description       = 'DriverHistoryQuery -- 4 combos: DALH (in-state Name), DALL (in-state OLN), DALHOUT (OOS Name, synthetic), DALLOUT (OOS OLN, synthetic). Metadata Choice-set on both paths (LIMITATION #36 case B). DH-suffix identity fields; RegistrationState/ImageIndicator shared with DriverLicenseQuery via the Options card. autoSelect=false -- officer opts in (AP #23 / FL_FCIC confirmed pattern: only one autoSelect=true QIDM per shared Person form).'
    handlerFunction   = 'CommsysTransactionRequestHandler'
    name              = "${provider}_DriverHistoryQuery"
    type              = 'QUERYINPUTDATAMAPPING'
    autoSelect        = $false
    provider          = $provider
    providerType      = 'Commsys'
    query             = 'DriverHistoryQuery'
    queryLabel        = 'Driver History'
    targetEntity      = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# --- 4. GunQuery -- 1 combo ---
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber'; size = 4; sourceField = @('GunCaliber'); targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake'; size = 23; sourceField = @('GunMake'); targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set = @('GunSerialNumber')
                any = @('GunCaliber','GunMake','relatedHitSearchIndicator')
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'GINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- 1 combo: GINQ (serial number, + optional caliber/make/stolen-search). No ImageIndicator field in metadata for this transaction.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# --- 5. ArticleSingleQuery -- 1 combo ---
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode'; size = 7; sourceField = @('ArticleTypeCode'); targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set      = @('ArticleSerialNumber','ArticleTypeCode')
                any      = @('ImageIndicator','relatedHitSearchIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'AINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- 1 combo: AINQ (serial + type, + optional image/stolen-search).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# --- 6. BoatQuery -- 4 combos ---
# Metadata: flat (no Choice) -- RVEH/RCAR (in-state reg/hull) + BVEH/BVIN (OOS
# reg/hull) are all real, distinct metadata keyRefs. RVEH/RCAR keyRefs are also
# used by VehicleRegistrationQuery -- disambiguated by targetEntity (LIMITATION #2
# scope is (targetEntity, query), not keyRef alone; confirmed pattern, see
# QIDM_REFERENCE.txt Section 6).
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber'; size = 20; sourceField = @('BoatHullIdNumber'); targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 10; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # --- RVEH: in-state registration. Devdoc combo #1. Hull>Reg + State-tier guardrails. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('RegistrationNumber')
                any        = @('ImageIndicator')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');   operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        # --- RCAR: in-state hull. Devdoc combo #2. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('BoatHullIdNumber')
                any        = @('ImageIndicator')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
        # --- BVEH: OOS registration. Devdoc combo #3. Hull>Reg guardrail. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set        = @('RegistrationNumber','RegistrationState')
                any        = @('ImageIndicator')
                defaults   = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BVEH'
            state                 = 'In/Out'
        }
        # --- BVIN: OOS hull. Devdoc combo #4. ---
        [PSCustomObject]@{
            requirements = [PSCustomObject]@{
                set      = @('BoatHullIdNumber','RegistrationState')
                any      = @('ImageIndicator')
                defaults = @(
                    [PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BVIN'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- 4 combos: RVEH (in-state reg), RCAR (in-state hull), BVEH (OOS reg), BVIN (OOS hull). Devdoc-order combo array + RegistrationState NOT_EXISTS on in-state combos + Hull>Reg guardrail (BoatHullIdNumber NOT_EXISTS on RVEH/BVEH).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$nyBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for ${provider} v${Version} -- 6 QIDMs, 16 combos, scoped to devdoc Basic Queries Supported (6 of 16 metadata query transactions)"
    name           = $provider
    type           = 'BUNDLE'
    provider       = $provider
}

# =====================================================================
# BUNDLE 1: ENTITIES (5 QIFs, single QIF per entity, multi-card layout)
#
# Vehicle:  2 cards (Search Options + VEHICLE SEARCH)
# Person:   3 cards (Search Options + DRIVER LICENSE SEARCH + DRIVER HISTORY SEARCH)
# Firearm:  1 card  (FIREARM SEARCH -- single required-field-set entity)
# Article:  1 card  (ARTICLE SEARCH -- single required-field-set entity)
# Boat:     2 cards (Search Options + BOAT SEARCH)
#
# Shared "Search Options" card: RegistrationState (NCIC pattern, blank = in-state,
# LIMITATION #30 -- NY has separate in-state/OOS keyRefs, so NO initialValue) +
# ImageIndicator (shared any[] field across all combos for that entity).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 2 cards
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SEARCH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number (or search by VIN)' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (out-of-state plates)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (out-of-state plates)' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN (Plate wins if both entered)' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Search Options (State + Image) + VEHICLE SEARCH (Plate/VIN/Make/Year).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number (or search by Name + Sex + DOB)' '20' 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'            '15' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'             '15' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name (optional)' '10' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix (optional)'      '5'  'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (required with Name)' 'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex (required with Name)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH) - or Name + DOB + Sex' '20' 'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name (DH)'            '15' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name (DH)'             '15' 'ROW_PER_DH_2' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH, optional)'  '10' 'ROW_PER_DH_2' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH, optional)'       '5'  'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth (DH) - required with Name' 'ROW_PER_DH_3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex (DH) - required with Name' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_3' }
            )}
            @{ id = 'ROW_PER_DH_4'; cols = @('3','6','3'); fields = @(
                @{ id = 'PurposeCodeDH_Input'; node = Inp 'purposeCodeDH' 'Purpose Code (DH) - required for out-of-state (C/F/E/D/J/S)' '1' 'ROW_PER_DH_4' @{ initialValue = 'C' } }
                @{ id = 'RequestorDH_Input';   node = Inp 'requestorDH'   'Requestor (DH) - required for out-of-state' '35' 'ROW_PER_DH_4' }
                @{ id = 'NyNyspinTransactionNameDH_Input'; node = Inp 'nyNyspinTransactionNameDH' 'Transaction Name (DH, optional) - defaults to DALL' '4' 'ROW_PER_DH_4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- Search Options (State + Image, shared by DL and DH) + DRIVER LICENSE SEARCH (OLN/Name/DOB/Sex) + DRIVER HISTORY SEARCH (DH-suffix fields; PurposeCode/Requestor required for out-of-state).'
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
        id    = 'CARD_GUN_SEARCH'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';    node = Sel 'GunMake'    'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input'; node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Stolen Search (Y = stolen only, optional)' '1' 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- single card (Serial/Make/Caliber/Stolen Search).'
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
        id    = 'CARD_ART_SEARCH'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'ImageIndicator_Input';      node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Stolen Search (Y = stolen only, optional)' '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- single card (Serial/Type/Image/Stolen Search).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 2 cards
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image (optional)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber'   'Hull ID (or Registration Number; Hull wins if both)' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number (or Hull ID)' '10' 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- Search Options (State + Image) + BOAT SEARCH (Hull/Registration).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# -SkipRace: no RaceCode field in any of the 6 in-scope queries (RaceCode only
#   appears in WMPI/CBI, both out of scope) -- would otherwise be a dead/orphan
#   RMS attribute with no matching form field (AP #27 cleanup).
# -PascalCaseUsxFields: Vehicle/Person DL card fieldIds are PascalCase for the
#   22 canonical USx CAD tokens (VehicleIdentificationNumber, LicensePlateNumber,
#   RegistrationState, NameFirst, NameLast, OperatorLicenseNumber, BirthDate,
#   SexCode) -- RMS must read the same casing to wire correctly.
# No -KeepSsn: no SocialSecurityNumber field in any of the 6 in-scope queries.
# RMS has no mapping to the DH-suffixed fields (OperatorLicenseNumberDH, etc.) --
# expected/correct (LIMITATION #34: DH-suffix fields are browser-only; RMS QUERY
# is "Not captured" for DH by design, same as every other provider in the portfolio).
# =====================================================================
$rmsBundle = Build-RmsBundle -SkipRace -PascalCaseUsxFields

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $nyBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $outPath `
    -Label "Built ${provider} v${Version}" `
    -Version $Version
