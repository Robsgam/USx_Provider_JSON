# build_ca_clets.ps1  -- CA_CLETS v2.x BASE
# Builds CA_CLETS_BASE.json from source\CA_CLETS.xml (2026-04-01 metadata) + KB specs.
# Single card per entity. ALL metadata search paths covered (20 combos).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_clets.ps1
#
# INPUTS:
#   source\CA_CLETS.xml   -- XML metadata (2026-04-01) [AUTHORITATIVE]
#   source\CA_CLETS.pdf   -- CommSys devdoc [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# METADATA SUMMARY (CA_CLETS v59/v36/v22/v21/v20/v35):
#   VehicleRegistrationQuery v59  -- 19 combos in XML, collapsed to 5 (IA.QV, IA.QVK, NLTS.RQ plate/VIN, IN.VP name)
#   DriverLicenseQuery v36        -- 8 combos in XML, collapsed to 3 (ID.L1, IN.L1, NLTS.DQ)
#   DriverHistoryQuery v22        -- 2 combos (NLTS.KQ Name, NLTS.KQ OLN)
#   GunQuery v21                  -- 2 combos (IG.QGH name, IG.QGB serial)
#   ArticleSingleQuery v20        -- 2 combos (IP.QA serial, IP.QA OAN)
#   BoatQuery v35                 -- 7 combos in XML, collapsed to 6 (NLTS.BQ name/hull/reg OOS + IA.QB hull/OAN/reg)
#
# CA-SPECIFIC:
#   CaRequestPurposeCode -- required in set[] on EVERY combo. fieldId='purposeCode'. Visible Inp initialValue='C'.
#   No ImageIndicator    -- not in CA metadata.
#   No VehicleStolenQuery -- CA combines stolen+reg in VehicleRegistrationQuery.
#   No RandomRequest     -- not in CA metadata.
#   No State initialValue -- LIMITATION #30: separate in-state (IA.*) vs OOS (NLTS.*) keyRefs.
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 20 combos):
#   VehicleRegistrationQuery   NLTS.RQ.P (OOS Plate), NLTS.RQ.V (OOS VIN), IN.VP (Name), IA.QVK (VIN), IA.QV (Plate)
#   DriverLicenseQuery         IN.L1 (Name), NLTS.DQ (OOS OLN), ID.L1 (OLN)
#   DriverHistoryQuery         NLTS.KQ.N (Name+DOB+Sex), NLTS.KQ.O (OLN)
#   GunQuery                   IG.QGH (Name), IG.QGB (Serial)
#   ArticleSingleQuery         IP.QA.S (Serial), IP.QA.O (OAN)
#   BoatQuery                  NLTS.BQ.N (Name+DOB OOS), NLTS.BQ.H (Hull OOS), NLTS.BQ.R (Reg OOS), IA.QB.H (Hull), IA.QB.O (OAN), IA.QB.R (Reg)
#
# ENTITIES (5 QUERYINPUTFORM -- single card per entity):
#   Vehicle  -- Plate + VIN + State + PlateType + PlateYear + VehMake + VehYear + Name + CaPurpose
#   Person   -- OLN + Name + DOB + Sex + State + CaPurpose + DH-suffix fields
#   Firearm  -- Serial + Make + Caliber + Type + Name + CaPurpose
#   Article  -- Serial + OAN + ArticleType + ArticleBrand + CaPurpose
#   Boat     -- Reg# + Hull + OAN + State + Name + DOB + CaPurpose
#
# PERSON (2 QIDMs co-fire by design):
#   DL + DH share Person entity/form.
#   DL: autoSelect=true, NO queriesToDeselect (default query).
#   DH: autoSelect=true, queriesToDeselect=DL (one-directional).
#   DH-suffix fieldIds isolate DH from DL field pool.

param(
    [string]$Version = "2.1",
    [string]$Phase   = "base"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_CLETS_BASE.json"
$VEROUT   = "$PHASEDIR\CA_CLETS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_CLETS PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_CLETS'

$results = Build-ProviderQrdm -ProviderName 'CA_CLETS'

$qmf = Build-Qmf -ProviderName 'CA_CLETS'

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML v59: 19 combos (IA.QV, IA.QVK, IV.4*, NLTS.RQ, IN.VP)
# Collapsed to 5: in-state plate/VIN + OOS plate/VIN + name (IN.VP)
# IV.4* DMV plate-type combos: COVERED by IA.QV (CommSys routes by LicensePlateTypeCode value)
# LIMITATION #30: No State initialValue -- in-state vs OOS routing by State presence
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('purposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 35; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'NLTS.RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'NLTS.RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.VP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IA.QVK'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('purposeCode','licensePlateNumber')
                any      = @('registrationState','licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IA.QV'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- NLTS.RQ (OOS plate/VIN), IN.VP (name), IA.QV (plate), IA.QVK (VIN). 5 combos.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_CLETS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_CLETS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML v36: 8 combos (IN.L1, ID.L1, IR.QVC x4, NLTS.DQ x2)
# Collapsed to 3: in-state OLN (ID.L1), in-state Name (IN.L1), OOS OLN (NLTS.DQ)
# IR.QVC (Supervised Release) now a separate QIDM (CAISupervisedReleaseQuery, 5th Person co-fire)
# NLTS.DQ Name combo (set=[CaPurpose] only) skipped -- too broad
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @('birthDate','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','operatorLicenseNumber','registrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- IN.L1 (Name), NLTS.DQ (OOS OLN), ID.L1 (OLN). Name-first ordering.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CLETS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery
# XML v22: 2 combos (NLTS.KQ Name, NLTS.KQ OLN) -- both Nlets
# CA has no in-state DH; all DH goes through Nlets
# DH-suffix fieldIds isolate from DL field pool (AP #14 / LIMITATION #24-25)
# PurposeCode: DH attr maps from purposeCodeDH (DH-suffix form field)
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCodeDH'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCodeDH','birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.KQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCodeDH','operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- NLTS.KQ (Name+DOB+Sex), NLTS.KQ (OLN). DH-suffix fields. All via Nlets.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CLETS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1g. GunQuery
# XML v21: 2 combos (IG.QGH name, IG.QGB serial)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IG.QGH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'IG.QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- IG.QGH (name), IG.QGB (serial). 2 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML v20: 2 combos both keyRef IP.QA -> invented IP.QA.S / IP.QA.O
# Serial and OAN are separate search paths
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('purposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','serialNumber'); any = @('articleBrand','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'IP.QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','ownerAppliedNumber'); any = @('articleBrand','articleTypeCode') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IP.QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- IP.QA (serial, OAN). CA property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML v35: 7 combos (IA.QB x3, IV.4B, NLTS.BQ x3)
# 6 built: NLTS.BQ.N (name OOS), NLTS.BQ.H/R (hull/reg OOS), IA.QB.H/O/R (hull/OAN/reg)
# IV.4B (DMV vessels): COVERED by IA.QB (same fields, CommSys routes by content)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('purposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','nameLast','nameFirst','birthDate','registrationState'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.BQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','boatHullIdNumber','registrationState'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'NLTS.BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','registrationNumber','registrationState'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'NLTS.BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'IA.QB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','ownerAppliedNumber'); any = @('registrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IA.QB.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('purposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IA.QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- NLTS.BQ.N (name OOS), NLTS.BQ (hull/reg OOS), IA.QB (hull/OAN/reg). 6 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_CLETS v${Version} -- 6 QIDMs, 20 combos, all metadata search paths covered"
    name           = 'CA_CLETS'
    type           = 'BUNDLE'
    provider       = 'CA_CLETS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# CaRequestPurposeCode: hidden InpH initialValue='C' on every form.
# No State initialValue on any form (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card (10 fields)
# VehicleRegistrationQuery: Plate, VIN, Name (IN.VP cross-entity)
# State: NO initialValue (LIMITATION #30)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'purposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_VEH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name (Owner)' '30' 'ROW_VEH_5' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name (Owner)'  '30' 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (IA.QV/IA.QVK + NLTS.RQ OOS + IN.VP name). 5 combos.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# Serves 2 QIDMs: DL + DH (co-fire with queriesToDeselect + DH-suffix).
# State: NO initialValue (LIMITATION #30 -- ID.L1 vs NLTS.DQ routing)
# DH-suffix fields: operatorLicenseNumberDH, purposeCodeDH,
#   nameLastDH, nameFirstDH, birthDateDH, sexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'purposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_PER_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_PER_4' }
                @{ id = 'purposeCodeDH_Input';  node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_4' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'nameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_5' }
                @{ id = 'nameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)'                                                              'ROW_PER_6' }
                @{ id = 'sexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }      'ROW_PER_6' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (IN.L1/NLTS.DQ/ID.L1) + DH (NLTS.KQ). DH-suffix fields.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (7 fields)
# GunQuery: Serial (IG.QGB) + Name (IG.QGH cross-entity)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'purposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_GUN_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name (Owner)' '30' 'ROW_GUN_3' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name (Owner)'  '30' 'ROW_GUN_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- IG.QGH (name), IG.QGB (serial). 2 combos.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown per CLAUDE.md)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'        '20' 'ROW_ART_1' }
                @{ id = 'ownerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
                @{ id = 'purposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'articleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'articleBrand_Input';    node = Inp 'articleBrand'    'Brand'        '6'                                                                     'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- IP.QA (serial, OAN). CA property inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (8 fields)
# BoatQuery: Hull/Reg/OAN (IA.QB) + OOS hull/reg (NLTS.BQ) + Name+DOB (NLTS.BQ.N cross-entity)
# State: NO initialValue (LIMITATION #30)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState'  'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
                @{ id = 'purposeCode_Input'; node = Inp 'purposeCode' 'Purpose Code' '1' 'ROW_BOA_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_2' }
                @{ id = 'ownerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name (Owner)' '30' 'ROW_BOA_3' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name (Owner)'  '30' 'ROW_BOA_3' }
            )}
            @{ id = 'ROW_BOA_4'; cols = @('6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt 'birthDate' 'Date of Birth (Owner)' 'ROW_BOA_4' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- NLTS.BQ.N (name OOS), NLTS.BQ (hull/reg OOS), IA.QB (hull/OAN/reg). 6 combos.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# =====================================================================
$rmsBundle = Build-RmsBundle
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $caBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built CA_CLETS v${Version}"