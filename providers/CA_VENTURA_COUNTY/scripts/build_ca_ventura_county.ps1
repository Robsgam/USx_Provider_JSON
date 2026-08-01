# build_ca_ventura_county.ps1  -- CA_VENTURA_COUNTY (galvanized v2.0, single-JSON native PascalCase)
# MC variant: PascalCase fieldIds, no Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combos (IN.VP, IG.QGH, NLTS.BQ.N).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# KEY DIFFERENCE FROM CA_CLETS MC:
#   DriverHistoryQuery has in-state combos (IN.B2, ID.B2) in addition to NLTS.KQ OOS.
#   DH has Attention (CommsysGetLastNameFirstNameInitialRuleHandler) + PurposeCode attrs.
#   Article has ArticleCategory field.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_ventura_county_mc.ps1

$ErrorActionPreference = "Stop"
$Version  = '2.2'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$OUT      = "$DIR\CA_VENTURA_COUNTY_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }


. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# keyRef INVENTORY (LIMITATION #21 -- unique keyRefs per QIDM; Ventura regional CLETS + cross-entity
# combos, identifier-priority guardrails + OOS RegistrationState EXISTS/NOT_EXISTS routing gates
# (v2.0: converted legacy poisoned NOT_EQUALS='CA' conditions to existence-only EXISTS)):
#   VehicleRegistrationQuery : NLTS.RQ.P/RQ.V (OOS), IA.QV/IA.QVK, IN.VP (owner name)
#   DriverLicenseQuery       : NLTS.DQ (OOS), IN.L1 (name), ID.L1 (OLN)
#   DriverHistoryQuery       : NLTS.KQ.N/KQ.O (OOS, DH-suffix), IN.B2/ID.B2 (in-state); Attention auto-handler
#   GunQuery                 : IG.QGB (serial), IG.QGH (name)
#   ArticleSingleQuery       : IP.QA.S/QA.O
#   BoatQuery                : NLTS.BQ.N/BQ.H/BQ.R (OOS), IA.QB.H/QB.R

# =====================================================================
# BUNDLE 1: CA_VENTURA_COUNTY PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_VENTURA_COUNTY'

$results = Build-ProviderQrdm -ProviderName 'CA_VENTURA_COUNTY'

$qmf = Build-Qmf -ProviderName 'CA_VENTURA_COUNTY'

# VehicleRegistrationQuery -- PascalCase + cross-entity (Name for IN.VP combo)
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 35; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS Plate (5 set -- most specific, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState')
                any        = @('VehicleMakeCode','vehicleYear')
                defaults   = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'NLTS.RQ.P'
            state                 = 'In/Out'
        }
        # OOS VIN (3 set, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','VehicleIdentificationNumber','RegistrationState')
                any        = @('VehicleMakeCode','vehicleYear')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');   operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'NLTS.RQ.V'
            state                 = 'In/Out'
        }
        # Name search (3 set -- cross-entity)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','NameLast','NameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.VP'
            state                 = 'In/Out'
        }
        # In-state Plate (2 set -- plate before VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','LicensePlateNumber'); any = @('RegistrationState','LicensePlateTypeCode','LicensePlateYear','VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IA.QV'
            state                 = 'In/Out'
        }
        # In-state VIN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','VehicleIdentificationNumber'); any = @('VehicleMakeCode','RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IA.QVK'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- NLTS.RQ.P (OOS plate), NLTS.RQ.V (OOS VIN), IN.VP (name), IA.QV (plate), IA.QVK (VIN). Most-specific first. MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_VENTURA_COUNTY_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_VENTURA_COUNTY'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# DriverLicenseQuery -- PascalCase, autoSelect + queriesToDeselect DH
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
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        # ── v2.2: IR.QVC support. Read from the RAW XML <Requirements> per <Combination> (the
        # sanctioned raw-metadata exception -- METADATA_REFERENCE.txt FLATTENS Choice branches and
        # cannot answer mandatory-vs-optional per variant). Ventura's IR.QVC has FOUR variants:
        #   {Name}  Set{ CaRequestPurposeCode, Set{Name,SexCode}, Choice{BirthDate|Age},
        #                Any{AddressCounty,Height,RaceCode} }   <- Choice INSIDE Set = one REQUIRED
        #   {OperatorLicenseNumber} Set{ purpose, OLN, Any{CriminalIdNumber,SocialSecurityNumber} }
        #   {CriminalIdNumber}      Set{ purpose, CII, Any{OLN,SocialSecurityNumber} }
        #   {SocialSecurityNumber}  Set{ purpose, SSN, Any{CriminalIdNumber,OLN} }
        # These are devdoc DriverLicenseQuery #3/#4 (Age / BirthDate + Name + SexCode), #5 (CII)
        # and #7 (SSN) -- all previously UNBUILT with a mandatory field wired nowhere.
        # Optionals come from METADATA's <Any> (AddressCounty, Height, RaceCode), NOT from the
        # devdoc prose, which also lists APPSRequestIndicator -- metadata is field-authority.
        [PSCustomObject]@{ name = 'Age';                  size = 2;  sourceField = @('age');                  targetField = 'Age' }
        [PSCustomObject]@{ name = 'CriminalIdNumber';     size = 11; sourceField = @('criminalIdNumber');     targetField = 'CriminalIdNumber' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber'; size = 9;  sourceField = @('socialSecurityNumber'); targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'AddressCounty';        size = 3;  sourceField = @('addressCounty');        targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'Height';               size = 3;  sourceField = @('height');               targetField = 'Height' }
        [PSCustomObject]@{ name = 'RaceCode';             size = 1;  sourceField = @('raceCode');             targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        # ── IR.QVC{Name} -- SPLIT into one combination per <Choice> branch (set[] has no OR).
        # BirthDate branch first, then Age: devdoc lists #3 (Age) before #4 (BirthDate), BUT neither
        # set[] is a subset of the other, so if an officer supplies both the FIRST listed here wins.
        # Ordered BirthDate-first deliberately: a date of birth is a stronger identifier than an age,
        # so when both are present the more precise query should go out.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','NameLast','NameFirst','SexCode','BirthDate')
                any        = @('addressCounty','height','raceCode')
                defaults   = @([PSCustomObject]@{ field = 'caRequestPurposeCode'; value = 'C' })
                # OLN beats Name (identifier priority). No State gate: devdoc #3/#4 are (In/Out),
                # and NLTS.DQ requires OLN, so a State-present name search cannot collide with it.
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC.NB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','NameLast','NameFirst','SexCode','age')
                any        = @('addressCounty','height','raceCode')
                defaults   = @([PSCustomObject]@{ field = 'caRequestPurposeCode'; value = 'C' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC.NA'
            state                 = 'In/Out'
        }
        # Name combo first (3 set, Name before OLN at same count)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','NameLast','NameFirst'); any = @('BirthDate','SexCode','RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
        # OOS OLN (3 set, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','OperatorLicenseNumber','RegistrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        # ── IR.QVC{CriminalIdNumber} (devdoc #5) and IR.QVC{SocialSecurityNumber} (devdoc #7).
        # 2 set[] each, so they sit AFTER the 3-set Name/OOS combos and BEFORE the 2-set ID.L1.
        # Each carries the other two identifiers in any[] exactly as its metadata <Any> permits.
        # Gated OLN NOT_EXISTS so an OLN-bearing fill still routes to the OLN paths (identifier
        # priority), which is also what keeps them from stealing ID.L1's fills.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','criminalIdNumber')
                any        = @('socialSecurityNumber')
                defaults   = @([PSCustomObject]@{ field = 'caRequestPurposeCode'; value = 'C' })
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'CriminalIdNumber'
            keyReference          = 'IR.QVC.C'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','socialSecurityNumber')
                any        = @('criminalIdNumber')
                defaults   = @([PSCustomObject]@{ field = 'caRequestPurposeCode'; value = 'C' })
                # NO 'criminalIdNumber NOT_EXISTS' gate here. I added one for belt-and-braces
                # mutual exclusion and verify_build correctly rejected it: gating a field NOT_EXISTS
                # while ALSO listing it in any[] is dead config -- it can never serialize, and it
                # poisons the test conductor. The two are XOR, never companions.
                # Ordering already gives CII precedence (IR.QVC.C is listed above this), and
                # metadata's IR.QVC{SocialSecurityNumber} <Any> explicitly permits CriminalIdNumber
                # to ride along, so keeping it in any[] is what the metadata asks for.
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'IR.QVC.S'
            state                 = 'In/Out'
        }
        # In-state OLN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','OperatorLicenseNumber')
                # v2.2: CII/SSN ride along per metadata IR.QVC{OperatorLicenseNumber}'s <Any>, so an
                # OLN search that also carries them TRANSMITS them instead of dropping them silently.
                any = @('RegistrationState','criminalIdNumber','socialSecurityNumber')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- IR.QVC.NB/.NA (Name+Sex+DOB|Age, Choice split), IN.L1 (Name), NLTS.DQ (OOS OLN), IR.QVC.C (CII), IR.QVC.S (SSN), ID.L1 (OLN). autoSelect+queriesToDeselect DH.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# DriverHistoryQuery -- PascalCase, DH-suffix fieldIds (AP #14 pattern)
# DH-suffix fields: OperatorLicenseNumberDH, NameLastDH, NameFirstDH, BirthDateDH, SexCodeDH, CaRequestPurposeCodeDH
# Attention: auto-handler via dedicated hidden 'attention' feeder field (initialValue='X'), included
# in every DH combo any[] + defaults[] Attention=X so the handler output serializes (AZ_AZDPS pattern).
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCodeDH'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific (5 DH set + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCodeDH','BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH'); any = @('attention','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');       operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.KQ.N'
            state                 = 'In/Out'
        }
        # In-state Name (3 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCodeDH','NameLastDH','NameFirstDH'); any = @('attention','BirthDateDH')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');       operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.B2'
            state                 = 'In/Out'
        }
        # OOS OLN (2 DH set + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCodeDH','OperatorLicenseNumberDH'); any = @('attention','RegistrationState')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (2 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCodeDH','OperatorLicenseNumberDH'); any = @('attention')
                defaults = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.B2'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- DH-suffix fields. NLTS.KQ.N (Name OOS), IN.B2 (Name in-state), NLTS.KQ.O (OLN OOS), ID.B2 (OLN in-state). autoSelect+queriesToDeselect DL.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# GunQuery -- PascalCase + cross-entity (Name for IG.QGH combo)
$gunQuery = [PSCustomObject]@{
    attributes = @(
        # Age + BirthDate added v2.1. The devdoc GunQuery COMBINATIONS are:
        #   1. (In/Out) GunSerialNumber, [GunCaliber, GunMake, GunTypeCode]
        #   2. (in/Out) Name, Age
        #   3. (In/Out) Name, BirthDate
        # #2 and #3 are UNBRACKETED -> Age / BirthDate are MANDATORY on a gun-by-name search, and
        # the field row confirms it (M/C/O = C for both). Metadata agrees: IG.QGH{Name} puts
        # Choice[Age|BirthDate] INSIDE <Set>, so exactly one is required. v2.0 built neither, which
        # made every gun-by-name request satisfy NO metadata variant -- wire-invalid.
        [PSCustomObject]@{ name = 'Age'; size = 2; sourceField = @('age'); targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('GunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
    )
    combinations = @(
        # Name search -- SPLIT v2.1 into one combination per <Choice> branch. set[] has no OR, so a
        # Choice-inside-<Set> cannot be expressed in a single combination; it must become one combo
        # per branch (QIDM_REFERENCE Sec 1b, LIMITATION #21 synthetic keyRef). Mirrors the same fix
        # already shipped on CA_CLETS v2.23 (IG.QGH.A/.B) and CA_eSUN v2.1.
        # Order follows the devdoc listing: #2 Name,Age precedes #3 Name,BirthDate. Neither set[] is
        # a subset of the other, so if an officer fills BOTH, .A wins -- which is the devdoc order.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('caRequestPurposeCode','NameLast','NameFirst','age'); any = @()
                defaults = @([PSCustomObject]@{ field = 'caRequestPurposeCode'; value = 'C' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IG.QGH.A'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('caRequestPurposeCode','NameLast','NameFirst','BirthDate'); any = @()
                defaults = @([PSCustomObject]@{ field = 'caRequestPurposeCode'; value = 'C' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'IG.QGH.B'
            state                 = 'In/Out'
        }
        # Serial search (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('GunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'IG.QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- IG.QGH (name) + IG.QGB (serial). Most-specific first. MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
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
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleCategory','ArticleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'IP.QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('articleBrand','articleCategory','ArticleTypeCode') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IP.QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- IP.QA (serial, OAN). CA property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase + cross-entity (Name+DOB for NLTS.BQ.N)
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('BoatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('RegistrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific (5 set, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','NameLast','NameFirst','BirthDate','RegistrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.BQ.N'
            state                 = 'In/Out'
        }
        # OOS hull (3 set, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','BoatHullIdNumber','RegistrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'NLTS.BQ.H'
            state                 = 'In/Out'
        }
        # OOS reg (3 set, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','RegistrationNumber','RegistrationState')
                any        = @()
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'NLTS.BQ.R'
            state                 = 'In/Out'
        }
        # In-state hull (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'IA.QB.H'
            state                 = 'In/Out'
        }
        # In-state OAN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IA.QB.O'
            state                 = 'In/Out'
        }
        # In-state reg (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('caRequestPurposeCode','RegistrationNumber'); any = @('RegistrationState')
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IA.QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- NLTS.BQ OOS (name, hull, reg) + IA.QB (hull, OAN, reg). Most-specific first. MC cross-entity.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# ─── v2.2: purposeCode COMBO DEFAULT on every combination that requires it ────────────────────
# EVERY Ventura combination carries CaRequestPurposeCode in set[], because the provider requires it
# on every transaction -- but 21 of 27 combos had no defaults[] entry for it, and the form control is
# a visible Inp with NO initialValue. Two consequences, both real:
#   1. A devdoc-legal fill sends NOTHING. audit_devdoc_optionals reported 5 FAILs of the form
#      "ArticleSingleQuery #1 (mandatory only) -> NO COMBO FIRES. A devdoc-legal fill sends no
#      query." -- purposeCode is not a devdoc field, so a devdoc-faithful fill omits it and no
#      combination can match. The Article combos are otherwise CORRECT: metadata IP.QA is
#      Set{purpose, ArticleSerialNumber, Any{ArticleBrand, ArticleCategory, ArticleTypeCode}}, so
#      Brand/Category/Type really are optional (the devdoc prose reads Brand as mandatory, but
#      METADATA IS FIELD-AUTHORITY and the devdoc is query-authority -- KB rule B4).
#   2. CAD ignores form initialValue entirely, so a combo default is the ONLY way a CAD-dispatched
#      query carries it (audit_cad CHECK 6 / "CAD defaults required").
# Done as a build-time normalization rather than 21 hand edits: one rule, impossible to apply
# inconsistently, and it self-documents WHY. This is NOT a post-build JSON patch -- it runs while
# the objects are still being constructed, which is what the no-patches rule requires.
foreach ($q in @($vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)) {
    foreach ($cm in @($q.combinations)) {
        $needs = @($cm.requirements.set | Where-Object { "$_" -match 'PurposeCode' })
        if (-not $needs.Count) { continue }
        $existing = @($cm.requirements.defaults | Where-Object { $_ -and "$($_.field)" -match 'PurposeCode' })
        if ($existing.Count) { continue }
        $newDefault = [PSCustomObject]@{ field = [string]$needs[0]; value = 'C' }
        if ($cm.requirements.PSObject.Properties.Name -contains 'defaults' -and $cm.requirements.defaults) {
            $cm.requirements.defaults = @(@($cm.requirements.defaults) + $newDefault)
        } else {
            $cm.requirements | Add-Member -MemberType NoteProperty -Name 'defaults' -Value @($newDefault) -Force
        }
    }
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_VENTURA_COUNTY v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'CA_VENTURA_COUNTY'
    type           = 'BUNDLE'
    provider       = 'CA_VENTURA_COUNTY'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE SEARCH + VIN SEARCH + NAME SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  3 cards (OPTIONS + SERIAL SEARCH + NAME SEARCH)
# Article:  3 cards (OPTIONS + SERIAL SEARCH + OAN SEARCH)
# Boat:     5 cards (OPTIONS + HULL + REGISTRATION + OAN + NAME SEARCH)
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
# NAME SEARCH: First + Last (cross-entity IN.VP)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_OPT_1' @{ initialValue = 'C' } }
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
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make (optional)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year (optional)' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_NAME'
        title = 'NAME SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_VEH_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_VEH_NAME_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + Purpose) + PLATE (IA.QV/NLTS.RQ.P) + VIN (IA.QVK/NLTS.RQ.V) + NAME (IN.VP cross-entity)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 5 cards (MC) -- DL fields + DH-suffix fields (AP #14)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared, DL only)
# DL OLN SEARCH: OperatorLicenseNumber
# DL NAME SEARCH: First + Last + DOB + Sex
# DH OLN SEARCH: OperatorLicenseNumberDH + CaRequestPurposeCodeDH
# DH NAME SEARCH: NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'DL - OLN SEARCH'
        rows  = @(
            # 'OLN' is the CANONICAL label on every provider (DEX-1284, BUILD_RULES Sec 11), applied
            # on each provider's own revisit turn -- this is Ventura's. Was 'License Number'.
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_OLN_1' }
            )}
            # v2.2: CII / SSN searches (devdoc #5 / #7, metadata IR.QVC{CriminalIdNumber} and
            # {SocialSecurityNumber}). They live on the OLN card because metadata lets all three
            # ride together -- whichever is present decides which combo fires.
            @{ id = 'ROW_PER_OLN_2'; cols = @('6','6'); fields = @(
                @{ id = 'CriminalIdNumber_Input';     node = Inp 'criminalIdNumber'     'CII Number' '11' 'ROW_PER_OLN_2' }
                @{ id = 'SocialSecurityNumber_Input'; node = Inp 'socialSecurityNumber' 'SSN'        '9'  'ROW_PER_OLN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'DL - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            # 'Sex' is no longer optional-only: metadata IR.QVC{Name} makes SexCode MANDATORY
            # alongside Name plus one of BirthDate|Age, so the '(optional)' qualifier was wrong as of
            # v2.2. It remains optional for the looser IN.L1 name catchall, so the bare label is the
            # honest one (lean-label convention -- the card title carries the query path).
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                                          'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_NAME_2' }
            )}
            # v2.2: Age is the OTHER branch of metadata's Choice{BirthDate|Age} -- one of the two is
            # REQUIRED for IR.QVC. No initialValue on Age or BirthDate: both are set[] routing fields
            # and a prefill on either would permanently hide the other branch (BUILD_RULES 24).
            @{ id = 'ROW_PER_NAME_3'; cols = @('6','6'); fields = @(
                @{ id = 'Age_Input';      node = Inp 'age'      'Age' '2'                                                                  'ROW_PER_NAME_3' }
                # attributeTypeId='RACE' PLUS codeTypeProvider='NIBRS' -- the dual-consumer pattern
                # (RMS Person Search stores the attribute ID, CommSys needs the RaceCode code string).
                # codeTypeCategory='NIBRS_RACE' alone fails AP #11 twice: the DL attr's
                # codeTypeProvider reverse-lookup cannot resolve a bare code string, and RMS's
                # useAttributeId=true race attr would store a code instead of an ID. Mirrors
                # CA_CLETS v2.23, which is tenant-verified ALL-PASS with this exact wiring.
                # LABEL-OVERRIDE: raceCode -- bare per DEX-1284 lean pass (any[] optional refinement)
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_3' }
            )}
            @{ id = 'ROW_PER_NAME_4'; cols = @('6','6'); fields = @(
                @{ id = 'Height_Input';        node = Inp 'height'        'Height (optional)'         '3'  'ROW_PER_NAME_4' }
                @{ id = 'AddressCounty_Input'; node = Inp 'addressCounty' 'County Code (optional)'    '3'  'ROW_PER_NAME_4' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_OLN'
        title = 'DH - OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_OLN_1' }
                @{ id = 'CaRequestPurposeCodeDH_Input';  node = Inp 'caRequestPurposeCodeDH'  'Purpose Code (DH)'   '1'  'ROW_PER_DH_OLN_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH_OLN_2'; cols = @('12'); fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_DH_OLN_2' @{ initialValue = 'X' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH_NAME'
        title = 'DH - NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH_NAME_1' }
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_NAME_1' }
            )}
            @{ id = 'ROW_PER_DH_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth (DH)'                                                          'ROW_PER_DH_NAME_2' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex (DH)'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_DH_NAME_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Purpose) + DL OLN/NAME + DH OLN/NAME (DH-suffix fields). 5 cards.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 3 cards (MC)
# OPTIONS: CaRequestPurposeCode (shared by serial + name combos)
# SERIAL SEARCH: Serial + Make + Caliber + Type (IG.QGB)
# NAME SEARCH: First + Last (cross-entity IG.QGH)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_GUN_OPT_1'; cols = @('4'); fields = @(
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_GUN_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_SERIAL_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_1' }
            )}
            @{ id = 'ROW_GUN_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';  node = Sel 'GunCaliber'  'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type (optional)'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
            )}
        )
    }
    @{
        id    = 'CARD_GUN_NAME'
        title = 'NAME SEARCH (Gun by Owner)'
        rows  = @(
            @{ id = 'ROW_GUN_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_GUN_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_GUN_NAME_1' }
            )}
            # v2.1: the devdoc requires Age OR BirthDate on a gun-by-name search (both unbracketed
            # in combinations #2/#3), so these are NOT optional -- one of them must be filled for
            # IG.QGH.A / .B to fire. No initialValue on either: they are set[] routing fields, and a
            # prefill on a routing field permanently hides the other branch (BUILD_RULES 24).
            @{ id = 'ROW_GUN_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_GUN_NAME_2' }
                @{ id = 'Age_Input';       node = Inp 'age'       'Age' '2'       'ROW_GUN_NAME_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: OPTIONS (Purpose) + SERIAL (IG.QGB) + NAME (IG.QGH cross-entity)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 3 cards (MC)
# OPTIONS: CaRequestPurposeCode (shared by serial + OAN combos)
# SERIAL SEARCH: Serial + ArticleType + Brand + Category (IP.QA.S)
# OAN SEARCH: OwnerAppliedNumber (IP.QA.O)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_ART_OPT_1'; cols = @('4'); fields = @(
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_ART_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_SERIAL_1'; cols = @('12'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_ART_SERIAL_1' }
            )}
            @{ id = 'ROW_ART_SERIAL_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type (optional)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_SERIAL_2' }
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand (optional)'        '6'                                                                     'ROW_ART_SERIAL_2' }
                @{ id = 'ArticleCategory_Input'; node = Inp 'articleCategory' 'Category (optional)'     '1'                                                                     'ROW_ART_SERIAL_2' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_OAN'
        title = 'OAN SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_OAN_1'; cols = @('12'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_OAN_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: OPTIONS (Purpose) + SERIAL (IP.QA.S) + OAN (IP.QA.O)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 5 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# HULL SEARCH: BoatHullIdNumber (IA.QB.H / NLTS.BQ.H)
# REGISTRATION SEARCH: RegistrationNumber (IA.QB.R / NLTS.BQ.R)
# OAN SEARCH: OwnerAppliedNumber (IA.QB.O)
# NAME SEARCH: First + Last + DOB (cross-entity NLTS.BQ.N)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_OPT_1' @{ initialValue = 'C' } }
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
    @{
        id    = 'CARD_BOA_OAN'
        title = 'OAN SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_OAN_1'; cols = @('12'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_OAN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_NAME'
        title = 'NAME SEARCH (Boat by Owner)'
        rows  = @(
            @{ id = 'ROW_BOA_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_BOA_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_BOA_NAME_1' }
            )}
            @{ id = 'ROW_BOA_NAME_2'; cols = @('12'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt 'BirthDate' 'Date of Birth' 'ROW_BOA_NAME_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Purpose) + HULL (IA.QB.H/NLTS.BQ.H) + REG (IA.QB.R/NLTS.BQ.R) + OAN (IA.QB.O) + NAME (NLTS.BQ.N cross-entity)'
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
    -Label "Built CA_VENTURA_COUNTY v${Version}" `
    -Version $Version