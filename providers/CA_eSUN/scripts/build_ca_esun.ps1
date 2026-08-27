# build_ca_esun.ps1  -- CA_eSUN (galvanized v2.0, single-JSON native PascalCase)
# v2.3 (2026-08-17, CA-FAMILY HEADER FIX): added <Authentication>/<DeviceId> via Build-Auth
#   -IncludeDeviceId. CA devdoc: the agency-assigned CLETS Terminal Identifier belongs in that
#   header field, required wherever CLETS mnemonic pooling is used (else ConnectCIC falls back to
#   the server IP). Found because CA_CLETS was FAILING AT MARIPOSA (LIVE) without it; Rob ruled it
#   required on ALL SIX CA providers. Rides in AUTH any[], never set[] (pooling-only per devdoc).
#   No form control needed -- DeviceId is in validate.ps1's $systemSourceFields with ORI/Mnemonic.
# Consolidated legacy BASE+MC -> one versioned JSON. Native PascalCase USx CAD fieldIds
# (Build-RmsBundle -PascalCaseUsxFields). Phase 2 multi-card. Cross-entity combos (VP.N/VP.D, QGH).
# DH uses DH-suffix fieldIds (OperatorLicenseNumberDH, NameFirstDH, etc.) + queriesToDeselect.
# OOS RegistrationState EXISTS/NOT_EXISTS routing gates + identifier-priority guardrails.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_esun.ps1

$ErrorActionPreference = "Stop"
$Version  = '2.6'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\CA_eSUN_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; eSUN regional CLETS + cross-entity
# combos, OOS RegistrationState EXISTS/NOT_EXISTS routing gates + identifier-priority guardrails):
#   VehicleRegistrationQuery : RQ.P/RQ.V (OOS), QV.P/QV.V (in-state), VP.N/VP.D (owner name, cross-entity)
#   DriverLicenseQuery       : DQ.N/DQ.O (OOS), L1.N/L1.O (in-state)
#   DriverHistoryQuery       : KQ.N/KQ.O (OOS, DH-suffix), L1.N.DH/L1.O.DH (in-state); Attention auto-handler
#   GunQuery                 : QGB (serial), QGH (name, cross-entity)
#   ArticleSingleQuery       : QA (serial)
#   BoatQuery                : BQ.H (hull), BQ.R (reg)

# =====================================================================
# BUNDLE 1: CA_eSUN PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_eSUN' -IncludeDeviceId

$results = Build-ProviderQrdm -ProviderName 'CA_eSUN'

$qmf = Build-Qmf -ProviderName 'CA_eSUN'

# ArticleSingleQuery -- PascalCase
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial). Property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
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
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('RegistrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','RegistrationNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.H (hull), BQ.R (reg). 6 XML combos collapsed to 2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# DriverLicenseQuery -- PascalCase
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
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
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','SexCode','BirthDate','NameLast','NameFirst'); any = @('RegistrationState','NameMiddle','NameSuffix')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');      operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # SYNTHETIC keyRef 'QW.N' -- LIMITATION #21/#36 split of metadata keyRef 'QW', which
        # carries both {Name} and {OperatorLicenseNumber}; only the Name branch is built here.
        # Metadata QW{Name} = Set[CaRequestPurposeCode, BirthDate, Name, Any[Age, SexCode]] --
        # BirthDate is MANDATORY here. Built v2.4 to give the in-state name+DOB search its own
        # combination (SexCode rides in any[]; Age has no control).
        # NOTE v2.5: L1{Name} DOES define BirthDate -- Set[PurposeCode, Name, Any[Choice[Age|BirthDate]]],
        # a Choice inside <Any> so both are OPTIONAL -- so BirthDate stays in L1.N's any[] too.
        # Ordered AHEAD of L1.N -- L1.N's set[] is a strict subset, so first-match would
        # otherwise take every fill and leave this path dead on arrival.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','BirthDate','NameLast','NameFirst'); any = @('SexCode','NameMiddle','NameSuffix')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');      operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QW.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','NameLast','NameFirst'); any = @('BirthDate','NameMiddle','NameSuffix')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');      operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','OperatorLicenseNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','OperatorLicenseNumber'); any = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.N/L1.O + QW.N (in-state), DQ.N/DQ.O (OOS).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# DriverHistoryQuery -- PascalCase + DH-suffix fieldIds
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
            size = 10; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','NameLastDH','NameFirstDH','SexCodeDH','BirthDateDH'); any = @('attention','RegistrationState','NameMiddleDH','NameSuffixDH')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                # v2.6: `RegistrationState EXISTS` REMOVED. Metadata KQ{Name} =
                #   Set[CaRequestPurposeCode, Name, SexCode, BirthDate] Any[Attention, PurposeCode, State]
                # -- State is an OPTIONAL there, not a fork. Gating on it made KQ.N reachable only out
                # of state, so devdoc DriverHistoryQuery #3 "(mand) BirthDate, Name, SexCode
                # [opt Attention, PurposeCode, State]" filled without a State fell through to L1.N.DH
                # (set[purposeCode, Name]) and the officer's BIRTHDATE AND SEX CODE were silently
                # discarded. Same anti-pattern as TN_TIES KQ.N, NM RQ.P v2.7, OCATS DQ.N v2.8,
                # MD ZLRG.P v2.3. KQ.N is a strict superset of L1.N.DH and ordered first, so
                # specificity routes the pair: Name+DOB+Sex -> KQ.N, name-only -> L1.N.DH.
                # L1.N.DH KEEPS its NOT_EXISTS gate -- metadata L1{Name} has an EMPTY <Any>, so it
                # defines no State, and without the gate a Name+State fill would match it and drop
                # the State silently, which is this same defect one combination over.
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','NameLastDH','NameFirstDH'); any = @('attention','NameMiddleDH','NameSuffixDH')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');        operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N.DH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','OperatorLicenseNumberDH'); any = @('attention','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','OperatorLicenseNumberDH'); any = @('attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O.DH'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- L1.N.DH/L1.O.DH (in-state), KQ.N/KQ.O (OOS). DH-suffix fieldIds for co-fire.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# GunQuery -- PascalCase (QGB serial + QGH name cross-entity)
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age';                  size = 2;  sourceField = @('GunAge');                targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('GunBirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 14; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('GunNameLast','GunNameFirst','GunNameMiddle','GunNameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # QGH SPLIT into one combo per discriminator (v2.1). Clears [FLAG:GUN-NAME-CHOICE-IN-SET].
        # Was set[caRequestPurposeCode,GunNameLast,GunNameFirst] any[GunBirthDate,GunAge], which
        # satisfies NO metadata variant: CA_eSUN's OWN metadata puts Choice[Age|BirthDate] INSIDE
        # <Set> on the QGH{Name} combination, which makes exactly one of them MANDATORY. So a
        # Name-only gun-owner query was accepted by the form and SENT as a request the metadata calls
        # invalid. Gate 6d catches that; 6c and 2i cannot, because content and attribution cannot see
        # a MISSING REQUIREMENT (CA_CLETS shipped a committed PASS log doing exactly this).
        # The devdoc agrees and is unambiguous: GunQuery "1. (In/Out) Age, Name" and
        # "2. (In/Out) BirthDate, Name" carry NO square brackets, and brackets are precisely how this
        # devdoc marks an optional (cf. #3 "GunSerialNumber, [GunCaliber, GunMake, GunTypeCode, ...]").
        # set[] has no OR, so one combination per branch is the only correct build.
        # Order: devdoc #1 is Age, #2 is BirthDate. The two set[]s are disjoint peers that specificity
        # cannot separate, so the devdoc listing order is the tiebreaker (audit_devdoc_order verifies).
        # See QIDM_REFERENCE.txt SECTION 1b. Precedent: CA_CLETS v2.23 (wire-proven: .A carried Age=35
        # with no DOB, .B carried DOB=19900115 with no Age), CA_CONTRA_COSTA v2.2.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','GunNameLast','GunNameFirst','GunAge'); any = @('GunNameMiddle','GunNameSuffix')
                conditions = @([PSCustomObject]@{ field = @('serialNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QGH.A'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','GunNameLast','GunNameFirst','GunBirthDate'); any = @('GunNameMiddle','GunNameSuffix')
                # GunAge NOT_EXISTS makes the two branches mutually exclusive and is what encodes the
                # devdoc tiebreaker in the JSON: Age filled -> QGH.A (devdoc #1) fires and this combo
                # defers; DOB only -> QGH.A cannot match and this fires; BOTH filled -> QGH.A wins,
                # which is correct because devdoc #1 (Age, Name) precedes #2 (BirthDate, Name).
                # Without it, verify_build CHECK 14 correctly flags QGH.B as shadowed by QGH.A on the
                # minimal-set[] payload -- both carry the same serialNumber NOT_EXISTS gate, so the
                # check has nothing to distinguish them. Same shape as NJ_NJCJIS Boat, where QB
                # carries 'BoatHullIdNumber NOT_EXISTS' so a hull fill defers to QBN (devdoc #1).
                # CA_CLETS/CA_CONTRA_COSTA did not need this only because their split combos carry no
                # conditions at all, so CHECK 14 never examined them.
                conditions = @(
                    [PSCustomObject]@{ field = @('serialNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('GunAge');       operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'QGH.B'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode','RelatedSearchHitIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial), QGH (name). MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# VehicleRegistrationQuery -- PascalCase (QV plate/VIN + RQ OOS + VP owner search)
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCity';           size = 13; sourceField = @('AddressCity');           targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'AddressStreetNumber';   size = 3;  sourceField = @('AddressStreetNumber');   targetField = 'AddressStreetNumber' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('VehBirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') }
            size = 30; sourceField = @('VehNameLast','VehNameFirst','VehNameMiddle','VehNameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # v2.6: RegistrationState DEMOTED set[] -> any[] and its EXISTS gate REMOVED.
                # Metadata RQ{LicensePlateNumber} = Set[CaRequestPurposeCode, LicensePlateNumber,
                # LicensePlateTypeCode, LicensePlateYear] Any[State] -- State is OPTIONAL, so
                # promoting it into set[] and gating on it made devdoc #8 "(mand) LicensePlateNumber,
                # LicensePlateTypeCode, LicensePlateYear [opt State]" unreachable in-state; the fill
                # fell through to QV.P (set[purposeCode, plate]) and the plate type and year were
                # silently discarded. The REAL discriminator is type+year, which is exactly what
                # separates RQ{plate} from 4{plate} from QV{plate} -- hence the form prefills are
                # removed (see the Vehicle card) so all three stay reachable by specificity.
                # defaults[] KEPT for CAD, which ignores form initialValue and does not route on it.
                set = @('caRequestPurposeCode','LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('RegistrationState','VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','VehNameLast','VehNameFirst','VehBirthDate'); any = @('AddressCity','AddressStreetNumber','VehNameMiddle','VehNameSuffix')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('VehicleIdentificationNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'BirthDate'
            keyReference          = 'VP.D'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','VehicleIdentificationNumber','RegistrationState'); any = @('VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','VehNameLast','VehNameFirst'); any = @('AddressCity','AddressStreetNumber','VehNameMiddle','VehNameSuffix')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('VehicleIdentificationNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'VP.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','VehicleIdentificationNumber'); any = @('VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        # 4 -- plate + plate type. BUILT NEW at v2.6, and it is the missing variant devdoc #2 names.
        # metadata 4{LicensePlateNumber} = Set[CaRequestPurposeCode, LicensePlateNumber,
        # LicensePlateTypeCode] with an EMPTY <Any>. devdoc "#2 (mand) LicensePlateNumber,
        # LicensePlateTypeCode" had NO built counterpart, so that fill fell through to QV.P and the
        # plate type was silently discarded. Per Rob's 2026-08-18 directive, build every metadata
        # variant of an in-scope query rather than registering it as a skip.
        # Ordered BETWEEN RQ.P (4 set[] fields) and QV.P (2): most-specific-first, so
        # plate+type+year -> RQ.P, plate+type -> 4, plate -> QV.P. This ordering only works because
        # the type/year prefills are gone; with them, RQ.P would match every plate fill and BOTH
        # this combo and QV.P would be dead on arrival (BUILD_RULES 24).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','LicensePlateNumber','LicensePlateTypeCode'); any = @()
                # No defaults[]: this variant's <Any> is empty, so a CAD default would be inert
                # (wiring class E), the same reasoning already recorded on QV.P below.
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = '4'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','LicensePlateNumber'); any = @('VehicleMakeCode','vehicleYear')
                # NO defaults[] here: metadata QV{LicensePlateNumber} has an EMPTY <Any>, so
                # LicensePlateTypeCode/LicensePlateYear are not defined on this branch. The CAD
                # defaults were removed with them in v2.4 -- they were inert (wiring class E).
                # v2.6: the `RegistrationState NOT_EXISTS` gate is KEPT. Metadata QV{plate} does not
                # define State, so without it a plate+State fill would match here and drop the State
                # silently. RQ.P and 4 are strict supersets ordered ahead, so this stays reachable as
                # the plate-only search (devdoc #1) rather than stealing their fills.
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- QV.P/QV.V (in-state), RQ.P/RQ.V (OOS), VP.N/VP.D (owner search).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_eSUN_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_eSUN'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# ─── v2.2: caRequestPurposeCode COMBO DEFAULT on every combination ────────────────────────────
# THIS PROVIDER'S OWN DEVDOC, "Transaction Requirements" (lines 19-31):
#   "Beginning July 21, 2021 CLETS requires a Purpose Code field to be supplied with every CLETS
#    transaction ... Any transaction which does not supply a valid Purpose Code value will be
#    REJECTED BY CLETS. ConnectCIC does not default the value of field; it must be provided by the
#    partner implementation as a user selectable field ... mandatory for all transactions."
#   Allowed values: C = Criminal Justice, I = Immigration Enforcement,
#                   U = Investigate Violations of Title 8 s1325 USC.
# It is a TRANSACTION-ENVELOPE requirement, not a per-query search field -- which is exactly why the
# devdoc's per-query "Possible Combinations" lists never mention it, and why all 20 built combos carry
# it in set[] while no devdoc-faithful fill contains it.
#
# WHY A COMBO DEFAULT IS REQUIRED INDEPENDENTLY OF ANY GATE: CAD does not apply form initialValues
# (BUILD_RULES 12), so a CAD-dispatched query would omit the field entirely and CLETS would REJECT the
# whole transaction. 0 of 20 combos had a default before this. That is a live defect on the CAD path.
#
# 'C' (Criminal Justice) is the value, and the risk is asymmetric: blank = guaranteed CLETS rejection,
# whereas C can never silently become an immigration-enforcement purpose. The field stays a visible,
# editable Inp on every card, so it remains "user selectable" as the devdoc requires -- pre-selected,
# not locked.
# Prefilling it is LOAD-BEARING, not a BUILD_RULES 24 violation: it is mandatory in EVERY combination,
# so satisfying it equally for all of them cannot shadow one path over another.
foreach ($q in @($artQuery, $boatQuery, $dlQuery, $dhQuery, $gunQuery, $vehRegQuery)) {
    foreach ($cm in @($q.combinations)) {
        $needs = @($cm.requirements.set | Where-Object { "$_" -match 'urposeCode' })
        if (-not $needs.Count) { continue }
        $existing = @($cm.requirements.defaults | Where-Object { $_ -and "$($_.field)" -match 'urposeCode' })
        if ($existing.Count) { continue }
        $newDefault = [PSCustomObject]@{ field = [string]$needs[0]; value = 'C' }
        if ($cm.requirements.PSObject.Properties.Name -contains 'defaults' -and $cm.requirements.defaults) {
            $cm.requirements.defaults = @(@($cm.requirements.defaults) + $newDefault)
        } else {
            $cm.requirements | Add-Member -MemberType NoteProperty -Name 'defaults' -Value @($newDefault) -Force
        }
    }
}

$esunBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $artQuery, $boatQuery, $dlQuery, $dhQuery, $gunQuery, $vehRegQuery)
    description    = "Provider configuration for CA_eSUN v${Version} -- 6 QIDMs, cross-entity (VP, QGH), DH-suffix, OOS EXISTS/NOT_EXISTS gates + identifier-priority guardrails"
    name           = 'CA_eSUN'
    type           = 'BUNDLE'
    provider       = 'CA_eSUN'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE + VIN + OWNER SEARCH)
# Person:   3 cards (OPTIONS + OLN + NAME) with DH-suffix hidden fields
# Firearm:  3 cards (OPTIONS + SERIAL + NAME SEARCH)
# Article:  1 card (serial only -- 1 combo)
# Boat:     3 cards (OPTIONS + HULL + REGISTRATION)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards (MC)
# OPTIONS: State + PurposeCode
# PLATE: LicensePlateNumber, PlateType, PlateYear
# VIN: VIN, VehicleMake, VehicleYear
# OWNER: VehNameFirst, VehNameLast, VehBirthDate, AddressCity, AddressStreetNumber
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# Vehicle -- 1 card (v2.4, collapsed from 4: OPTIONS/PLATE/VIN/OWNER)
# LABEL-OVERRIDE: LicensePlateTypeCode -- prefilled 'PC', bare label per BUILD_RULES 11
# LABEL-OVERRIDE: LicensePlateYear -- prefilled current year, bare label per BUILD_RULES 11
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
# LABEL-OVERRIDE: NameMiddle -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameSuffix -- bare "Suffix", DEX-1284 lean pass (any[] optional, DL pool)
# LABEL-OVERRIDE: NameMiddleDH -- bare "Middle Name", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix", DEX-1284 lean pass (any[] optional, DH pool)
# LABEL-OVERRIDE: VehNameMiddle -- bare "Owner Middle Name", DEX-1284 lean pass (any[], VP pool)
# LABEL-OVERRIDE: VehNameSuffix -- bare "Owner Suffix", DEX-1284 lean pass (any[], VP pool)
# LABEL-OVERRIDE: GunNameMiddle -- bare "Owner Middle Name", DEX-1284 lean pass (any[], QGH pool)
# LABEL-OVERRIDE: GunNameSuffix -- bare "Owner Suffix", DEX-1284 lean pass (any[], QGH pool)
# LABEL-OVERRIDE: RelatedSearchHitIndicator -- canonical bare "Stolen Check" per BUILD_RULES 11
# LABEL-OVERRIDE: attention -- hidden gate-feeder, the label is dead text the officer never sees
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH BY PLATE, VIN, OR OWNER'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'} 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '30' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'VehNameFirst_Input';  node = Inp 'VehNameFirst'  'Owner First Name'  '30' 'ROW_VEH_3' }
                @{ id = 'VehNameLast_Input';   node = Inp 'VehNameLast'   'Owner Last Name'   '30' 'ROW_VEH_3' }
                @{ id = 'VehNameMiddle_Input'; node = Inp 'VehNameMiddle' 'Owner Middle Name' '30' 'ROW_VEH_3' }
                @{ id = 'VehNameSuffix_Input'; node = Inp 'VehNameSuffix' 'Owner Suffix'      '5'  'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehBirthDate_Input';        node = Dt  'VehBirthDate'        'Owner Date of Birth' 'ROW_VEH_4' }
                @{ id = 'AddressCity_Input';         node = Inp 'AddressCity'         'City (optional)' '13' 'ROW_VEH_4' }
                @{ id = 'AddressStreetNumber_Input'; node = Inp 'AddressStreetNumber' 'Street Number (optional)' '3'  'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_5' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_5' @{ initialValue = 'C' } }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card: Plate (QV.P/RQ.P) + VIN (QV.V/RQ.V) + Owner (VP.D/VP.N cross-entity). Blank State routes the in-state CA keyRef.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 2 cards (v2.4, collapsed from 5)
# The DL card carries State + Purpose Code as SHARED CONTEXT: both are read by the
# DH combinations too (one form, one field pool -- cards are visual grouping only),
# so a second RegistrationStateDH control would make the officer type the same
# jurisdiction twice for the same person. Deliberate; see BUILD_NOTES v2.4.
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, OR NAME'
        rows  = @(
            @{ id = 'ROW_PER_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_1' }
            )}
            @{ id = 'ROW_PER_DL_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_DL_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '5'  'ROW_PER_DL_2' }
            )}
            @{ id = 'ROW_PER_DL_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input';            node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';              node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_DL_3' @{ initialValue = 'C' } }
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
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'X' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards: DL (L1.O/L1.N in-state, DQ.O/DQ.N OOS) + DH (L1.O.DH/L1.N.DH in-state, KQ.O/KQ.N OOS). DH-suffix fieldIds isolate the DH pool.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (v2.4, collapsed from 3). Serial (QGB) + Owner name (QGH.A/QGH.B).
# Metadata Choice makes Age|BirthDate MANDATORY on the name path -- there is no
# name-only firearm search, which is why the qualifier row sits below the name row.
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL, OR OWNER NAME'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '14' 'ROW_GUN_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'gunCaliber'   'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunTypeCode_Input';               node = Sel 'gunTypeCode' 'Type (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Inp 'RelatedSearchHitIndicator' 'Stolen Check' '1' 'ROW_GUN_2' }
                @{ id = 'CaRequestPurposeCode_Input';      node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_2' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'GunNameFirst_Input';  node = Inp 'GunNameFirst'  'Owner First Name'  '30' 'ROW_GUN_3' }
                @{ id = 'GunNameLast_Input';   node = Inp 'GunNameLast'   'Owner Last Name'   '30' 'ROW_GUN_3' }
                @{ id = 'GunNameMiddle_Input'; node = Inp 'GunNameMiddle' 'Owner Middle Name' '30' 'ROW_GUN_3' }
                @{ id = 'GunNameSuffix_Input'; node = Inp 'GunNameSuffix' 'Owner Suffix'      '5'  'ROW_GUN_3' }
            )}
            @{ id = 'ROW_GUN_4'; cols = @('6','6'); fields = @(
                @{ id = 'GunBirthDate_Input'; node = Dt  'GunBirthDate' 'Owner Date of Birth' 'ROW_GUN_4' }
                @{ id = 'GunAge_Input';       node = Inp 'GunAge'       'Owner Age' '2' 'ROW_GUN_4' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm queries -- 1 card: Serial (QGB) + Owner name (QGH.A age / QGH.B birthdate, cross-entity).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA serial)
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'SerialNumber_Input';         node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';      node = Sel 'articleTypeCode' 'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand (optional)'    '6' 'ROW_ART_2' }
                @{ id = 'ArticleCategory_Input'; node = Inp 'articleCategory' 'Category (optional)' '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- 1 card: QA (serial).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (v2.4, collapsed from 3). Hull (BQ.H) leads Registration (BQ.R).
# LABEL-OVERRIDE: caRequestPurposeCode -- prefilled 'C', bare label per BUILD_RULES 11
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY HULL, OR REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';     node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input';   node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_1' @{ initialValue = 'C' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card: Hull (BQ.H) + Registration (BQ.R).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs — PascalCase USx form-fed refs, RegistrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $esunBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built CA_eSUN v${Version}" `
    -Version $Version