# build_ca_ventura_county.ps1  -- CA_VENTURA_COUNTY v1.4 BASE
# Builds CA_VENTURA_COUNTY_BASE.json from source\CA_VENTURA_COUNTY.xml metadata + KB specs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_ventura_county.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\CA_VENTURA_COUNTY.xml   -- XML metadata [AUTHORITATIVE]
#   source\CA_VENTURA_COUNTY.pdf   -- CommSys devdoc [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# METADATA SUMMARY (CA_VENTURA_COUNTY -- same 6 queries as CA_CLETS):
#   VehicleRegistrationQuery  -- 20 combos in XML, collapsed to 4 (IA.QV, IA.QVK, NLTS.RQ plate/VIN)
#   DriverLicenseQuery        -- 8 combos in XML, collapsed to 3 (ID.L1, IN.L1, NLTS.DQ)
#   DriverHistoryQuery        -- 4 combos, BUILD ALL (IN.B2 Name, ID.B2 OLN, NLTS.KQ.N Name OOS, NLTS.KQ.O OLN OOS)
#   GunQuery                  -- 2 combos in XML, 1 used (IG.QGB serial; IG.QGH name skipped -- cross-entity)
#   ArticleSingleQuery        -- 2 combos (IP.QA.S serial, IP.QA.O OAN)
#   BoatQuery                 -- 7 combos in XML, collapsed to 5 (IA.QB hull/OAN/reg + NLTS.BQ hull/reg OOS)
#
# CA-SPECIFIC:
#   CaRequestPurposeCode -- required in set[] on EVERY combo. Visible Inp initialValue='C' (Criminal Justice).
#   No ImageIndicator    -- not in CA metadata (unlike NJ v2).
#   No VehicleStolenQuery -- CA combines stolen+reg in VehicleRegistrationQuery.
#   No RandomRequest     -- not in CA metadata.
#   No State initialValue -- LIMITATION #30: separate in-state (IA.*) vs OOS (NLTS.*) keyRefs.
#
# KEY DIFFERENCE FROM CA_CLETS:
#   DriverHistoryQuery has in-state combos (IN.B2, ID.B2) in addition to NLTS.KQ OOS.
#   CA_CLETS had OOS-only DH (NLTS.KQ). Ventura has 4 combos total.
#   DH also has Attention (CommsysGetLastNameFirstNameInitialRuleHandler) and PurposeCode fields.
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 20 combos):
#   VehicleRegistrationQuery   IA.QV (Plate), IA.QVK (VIN), NLTS.RQ.P (OOS Plate), NLTS.RQ.V (OOS VIN)
#   DriverLicenseQuery         ID.L1 (OLN), IN.L1 (Name), NLTS.DQ (OOS OLN)
#   DriverHistoryQuery         IN.B2 (Name in-state), ID.B2 (OLN in-state), NLTS.KQ.N (Name OOS), NLTS.KQ.O (OLN OOS)
#   GunQuery                   IG.QGB (Serial)
#   ArticleSingleQuery         IP.QA.S (Serial), IP.QA.O (OAN)
#   BoatQuery                  IA.QB.H (Hull), IA.QB.O (OAN), IA.QB.R (Reg), NLTS.BQ.H (OOS Hull), NLTS.BQ.R (OOS Reg)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- Plate + VIN + State + PlateType + PlateYear + VehMake + VehYear + CaPurpose(visible)
#   Person   -- OLN + Name + DOB + Sex + State + CaPurpose(visible)
#   Firearm  -- Serial + Make + Caliber + Type + CaPurpose(visible)
#   Article  -- Serial + OAN + ArticleType + ArticleBrand + ArticleCategory + CaPurpose(visible)
#   Boat     -- Reg# + Hull + OAN + State + CaPurpose(visible)
#
# PERSON (2 QIDMs co-fire with DH-suffix isolation):
#   DL + DH share Person entity/form.
#   Both have autoSelect=true + queriesToDeselect (AP #14 pattern).
#   DH-suffix fieldIds: operatorLicenseNumberDH, nameLastDH, nameFirstDH, birthDateDH, sexCodeDH, caRequestPurposeCodeDH.
#   DH QIDM sourceField/combo refs use DH-suffix names.

param(
    [string]$Version = "1.4",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_VENTURA_COUNTY_BASE.json"
$VEROUT   = "$PHASEDIR\CA_VENTURA_COUNTY_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_VENTURA_COUNTY PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_VENTURA_COUNTY'

$results = Build-ProviderQrdm -ProviderName 'CA_VENTURA_COUNTY'

$qmf = Build-Qmf -ProviderName 'CA_VENTURA_COUNTY'

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: 20 combos (IA.QV, IA.QVK, IV.4*, NLTS.RQ, IN.VP)
# Collapsed to 4: in-state plate/VIN + OOS plate/VIN
# IV.4* DMV plate-type combos: COVERED by IA.QV (CommSys routes by LicensePlateTypeCode value)
# IN.VP name query: NOT IMPLEMENTABLE (cross-entity -- person name on vehicle form)
# LIMITATION #30: No State initialValue -- in-state vs OOS routing by State presence
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState')
                any        = @('vehicleMakeCode','vehicleYear')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'NLTS.RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','vehicleIdentificationNumber','registrationState')
                any        = @('vehicleMakeCode','vehicleYear')
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'NLTS.RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'IA.QVK'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber'); any = @('registrationState','licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'IA.QV'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- IA.QV (plate), IA.QVK (VIN), NLTS.RQ (OOS plate/VIN).'
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

# =====================================================================
# 1e. DriverLicenseQuery
# XML: 8 combos (IN.L1, ID.L1, IR.QVC x4, NLTS.DQ x2)
# Collapsed to 3: in-state OLN (ID.L1), in-state Name (IN.L1), OOS OLN (NLTS.DQ)
# IR.QVC (Supervised Release) deferred to Phase 2
# NLTS.DQ Name combo (set=[CaPurpose] only) skipped -- too broad
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name combo first (3 set, Name before OLN at same count)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @('birthDate','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.L1'
            state                 = 'In/Out'
        }
        # OOS OLN (3 set -- OLN + State + Purpose, NOT CA condition)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('caRequestPurposeCode','operatorLicenseNumber','registrationState')
                any        = @()
                conditions = @([PSCustomObject]@{ field = @('State'); operator = 'NOT_EQUALS'; value = @('CA') })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.DQ'
            state                 = 'In/Out'
        }
        # In-state OLN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.L1'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- IN.L1 (Name), NLTS.DQ (OOS OLN), ID.L1 (OLN). autoSelect+queriesToDeselect DH.'
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

# =====================================================================
# 1f. DriverHistoryQuery -- DH-suffix fieldIds (AP #14 pattern)
# XML: 4 combos -- KEY DIFFERENCE from CA_CLETS
# CA_CLETS had OOS-only (NLTS.KQ). Ventura has in-state DH (IN.B2, ID.B2) + OOS (NLTS.KQ).
# DH-suffix fields isolate from DL field pool:
#   operatorLicenseNumberDH, nameLastDH, nameFirstDH, birthDateDH, sexCodeDH, caRequestPurposeCodeDH
# Attention: handler-only (CommsysGetLastNameFirstNameInitialRuleHandler), uses DH-suffix names, NOT in combo requirements.
# PurposeCode: sourced from caRequestPurposeCodeDH.
# Combo ordering: most set[] first (Name before OLN within each group).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCodeDH'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific first (5 DH set fields + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'NLTS.KQ.N'
            state                 = 'In/Out'
        }
        # In-state Name (IN.B2): 3 DH set fields
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','nameLastDH','nameFirstDH'); any = @('birthDateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'IN.B2'
            state                 = 'In/Out'
        }
        # OOS OLN -- 2 DH set fields + State in any
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'NLTS.KQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (ID.B2): 2 DH set fields only
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCodeDH','operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ID.B2'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- DH-suffix fields. IN.B2 (Name in-state), ID.B2 (OLN in-state), NLTS.KQ (Name/OLN OOS). autoSelect+queriesToDeselect DL.'
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

# =====================================================================
# 1g. GunQuery
# XML: 2 combos (IG.QGB serial, IG.QGH name)
# Serial only (IG.QGB). IG.QGH (gun by name): NOT IMPLEMENTABLE (cross-entity -- person fields on firearm form).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'IG.QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- IG.QGB (serial). CA NCIC+historical firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML: 2 combos both keyRef IP.QA -> invented IP.QA.S / IP.QA.O
# Serial and OAN are separate search paths
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown)
# ArticleCategory: size=1, in any[] on both combos
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'IP.QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
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

# =====================================================================
# 1i. BoatQuery
# XML: 7 combos (IA.QB x3, IV.4B, NLTS.BQ x3)
# 5 built: hull (IA.QB.H), OAN (IA.QB.O), reg (IA.QB.R), OOS hull (NLTS.BQ.H), OOS reg (NLTS.BQ.R)
# IV.4B (DMV vessels): COVERED by IA.QB (same fields, CommSys routes by content)
# NLTS.BQ Name: NOT IMPLEMENTABLE in BASE (cross-entity -- person name on boat form). MC only.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS hull (3 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber','registrationState'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'NLTS.BQ.H'
            state                 = 'In/Out'
        }
        # OOS reg (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber','registrationState'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'NLTS.BQ.R'
            state                 = 'In/Out'
        }
        # In-state hull (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'IA.QB.H'
            state                 = 'In/Out'
        }
        # In-state OAN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('registrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'IA.QB.O'
            state                 = 'In/Out'
        }
        # In-state reg (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'IA.QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- NLTS.BQ OOS (hull, reg) + IA.QB (hull, OAN, reg). Most-specific first.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_VENTURA_COUNTY_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_VENTURA_COUNTY'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_VENTURA_COUNTY v${Version}"
    name           = 'CA_VENTURA_COUNTY'
    type           = 'BUNDLE'
    provider       = 'CA_VENTURA_COUNTY'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# CaRequestPurposeCode: visible Inp initialValue='C' on every form.
# No State initialValue on any form (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery fields. No ImageIndicator (not in CA metadata).
# State: NO initialValue (LIMITATION #30 -- in-state IA.QV vs OOS NLTS.RQ)
# PlateType: initialValue='PC', PlateYear: initialValue=$currentYear (dynamic)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (IA.QV/IA.QVK + NLTS.RQ OOS).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 2 cards (DL fields + DH-suffix fields)
# Serves 2 QIDMs: DL + DH with DH-suffix isolation (AP #14).
# State: shared (NO initialValue -- LIMITATION #30)
# DH fields: operatorLicenseNumberDH, nameLastDH, nameFirstDH, birthDateDH, sexCodeDH, caRequestPurposeCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'DRIVER LICENSE SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_DH_1'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_1' }
                @{ id = 'caRequestPurposeCodeDH_Input';  node = Inp 'caRequestPurposeCodeDH'  'Purpose Code (DH)'   '1'  'ROW_PER_DH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH_2' }
                @{ id = 'nameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'Date of Birth (DH)'                                                          'ROW_PER_DH_3' }
                @{ id = 'sexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_DH_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (ID.L1/IN.L1/NLTS.DQ) + DH (IN.B2/ID.B2/NLTS.KQ). DH-suffix fields for isolation.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (IG.QGB serial only)
# No ImageIndicator (not in CA metadata).
# Name-based gun query (IG.QGH) deferred -- cross-entity, not implementable.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- IG.QGB (serial). Historical+NCIC.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown per CLAUDE.md)
# ArticleCategory: size=1 input field
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'        '20' 'ROW_ART_1' }
                @{ id = 'ownerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'articleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'articleBrand_Input';    node = Inp 'articleBrand'    'Brand'        '6'                                                                     'ROW_ART_2' }
                @{ id = 'articleCategory_Input'; node = Inp 'articleCategory' 'Category'     '1'                                                                     'ROW_ART_2' }
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
# Boat -- 1 card
# State: NO initialValue (for OOS routing)
# All 5 combos built (3 in-state + 2 OOS).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState'  'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_2' }
                @{ id = 'ownerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- IA.QB (hull, OAN, reg) + NLTS.BQ OOS (hull, reg). State for OOS.'
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
    -Label "Built CA_VENTURA_COUNTY v${Version}" `
    -Version $Version