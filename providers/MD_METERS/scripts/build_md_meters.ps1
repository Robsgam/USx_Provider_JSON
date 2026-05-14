# build_md_meters.ps1  -- MD_METERS v1.x BASE
# Builds MD_METERS_BASE.json from source\MD_METERS.xml (2026-05-06 metadata) + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_md_meters.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\MD_METERS.xml       -- XML metadata (2026-05-06) [AUTHORITATIVE]
#   source\MD_METERS_DEVDOC.txt -- CommSys devdoc [CROSS-CHECK]
#   source\HIDLE.json          -- RMS structural template
#
# METADATA SUMMARY (MD_METERS v6/v7/v6/v3/v3/v4):
#   VehicleRegistrationQuery v6  -- 4 combos (ZVEH x2, ZLRG x2), collapsed to 4 w/ invented keyRefs
#   DriverLicenseQuery v7        -- 5 combos (ZWAR x2, ZDRV, ZLDR x2), collapsed to 4
#   DriverHistoryQuery v6        -- 2 combos (ZDRV x2), invented DH keyRefs
#   GunQuery v3                  -- 1 combo (ZGUN), all mandatory fields
#   ArticleSingleQuery v3        -- 1 combo (ZART), all mandatory fields
#   BoatQuery v4                 -- 2 combos (ZBOA x2), invented keyRefs
#
# MD-SPECIFIC:
#   No CaRequestPurposeCode -- not a CA system.
#   ImageIndicator present  -- on Vehicle, DL, DH, Boat (in any[]).
#   No VehicleStolenQuery   -- not in metadata.
#   No RandomRequest        -- not in metadata.
#   State: no initialValue (clean routing -- add back after live testing if needed).
#   Date format: MMddyyyy   -- size=8, standard NCIC format.
#   Name: composite Last,First via FormatStringRuleHandler.
#   RaceCode in DL          -- use NIBRS_RACE/NIBRS (not attributeTypeId).
#   GunQuery: all 3 fields mandatory (set[]).
#   DL+DH co-fire on Person entity (standard).
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 14 combos):
#   VehicleRegistrationQuery   ZVEH.P (Plate), ZVEH.V (VIN), ZLRG.P (Plate+PlateType+Year), ZLRG.V (VIN+State)
#   DriverLicenseQuery         ZLDR.O (OLN+[State]), ZLDR.N (Name+DOB+Sex+[State]), ZWAR.N (Name+Sex+Race+DOB), ZWAR.O (Name+Sex+Race+OLN+ExpYear)
#   DriverHistoryQuery         ZDRV.O (OLN), ZDRV.N (Name+DOB+Sex)
#   GunQuery                   ZGUN (Serial+Make+Caliber)
#   ArticleSingleQuery         ZART (Serial+ArticleType)
#   BoatQuery                  ZBOA.H (Hull), ZBOA.R (Reg)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle    -- Plate + VIN + State + PlateType + PlateYear + VehMake + ImageIndicator
#   Person     -- OLN + Name + DOB + Sex + Race + State + ImageIndicator
#   Firearm    -- Serial + Make + Caliber
#   Article    -- Serial + ArticleType (ArticleSingleQuery only)
#   Boat       -- Hull + Reg + ImageIndicator
#
# PERSON (2 QIDMs with DH-suffix + queriesToDeselect):
#   DL + DH share Person entity/form.
#   DH-suffix fieldIds isolate DH from DL field pool (AP #14).
#   queriesToDeselect on each QIDM for mutual deselect.
#   Both have autoSelect=true. Officer can uncheck to disable specific queries.

param(
    [string]$Version = "1.3",
    [string]$Phase   = "base"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\MD_METERS_BASE.json"
$OUTREAD  = "$DIR\MD_METERS_BASE_READABLE.json"
$VEROUT   = "$PHASEDIR\MD_METERS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS
# =====================================================================
# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: MD_METERS PROVIDER
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');      targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic'); targetField = 'Mnemonic' }
        [PSCustomObject]@{
            description = 'dexUserStateid from RMS profile'
            name        = 'UserName'
            rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
            sourceField = @('dexStateUserId')
            targetField = 'UserName'
        }
    )
    combinations = @(
        [PSCustomObject]@{
            keyReference = 'AUTH'
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for MD METERS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'MD_METERS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'MD_METERS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'MD_METERS_Results'
$results.description = 'Results mapping for MD METERS'
$results.provider    = 'MD_METERS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'MD_METERS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'MD_METERS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML v6: 4 combos (ZVEH x2, ZLRG x2) -- all keyRefs duplicated
# Invented distinct keyRefs: ZVEH.V, ZVEH.P, ZLRG.P, ZLRG.V
# Devdoc combos:
#   1. (In) VIN + [VehicleMakeCode]
#   2. (In/Out) VIN + [State]
#   3. (In) LicensePlateNumber
#   4. (In/Out) LicensePlateNumber + LicensePlateTypeCode + LicensePlateYear + [State]
# ImageIndicator in any[] on all combos.
# State initialValue='MD' is SAFE (no separate in-state vs OOS keyRefs).
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('imageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 24; sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        # Most specific first: Plate+PlateType+PlateYear+[State] (ZLRG plate)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ZLRG.P'
            state                 = 'In/Out'
        }
        # VIN+[State] (ZLRG VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ZLRG.V'
            state                 = 'In/Out'
        }
        # VIN+[VehicleMakeCode] (ZVEH VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ZVEH.V'
            state                 = 'In/Out'
        }
        # Plate only (ZVEH plate) -- least specific, fallback
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ZVEH.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ZVEH (plate/VIN), ZLRG (plate+type+year, VIN+state). MD registration query.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'MD_METERS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'MD_METERS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML v7: 5 combos (ZWAR x2, ZDRV x1, ZLDR x2) -- keyRefs duplicated
# Devdoc combos (4):
#   1. (In) Name+SexCode+RaceCode+BirthDate+[State]
#   2. (In) Name+SexCode+RaceCode+OLN+OperatorLicenseExpirationYear+[State]
#   3. (Out) Name+SexCode+BirthDate+[State]
#   4. (In/Out) OLN+[State]
#
# ZWAR combos (Name+Race+Sex+DOB, Name+Race+Sex+OLN+ExpYear): warrant-related
#   Combo 2 requires OperatorLicenseExpirationYear -- include in BASE as optional any[] field.
# ZDRV combo (OLN+[YearsPastViolationsWanted]): driving record by OLN
# ZLDR combos (Name+DOB+Sex+[State], OLN+[State]): standard DL lookup
#
# Collapsed to 4 combos with invented keyRefs:
#   ZWAR.N: Name+Sex+Race+DOB+[State,ImageIndicator]
#   ZWAR.O: Name+Sex+Race+OLN+[operatorLicenseExpirationYear,State,ImageIndicator]
#   ZLDR.O: OLN+[State,ImageIndicator,yearsPastViolationsWanted]
#   ZLDR.N: Name+DOB+Sex+[State,ImageIndicator]
#
# RaceCode: codeTypeCategory=NIBRS_RACE, codeTypeSource=NIBRS (per CLAUDE.md AP #3)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';                size = 1;  sourceField = @('imageIndicator');                targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseExpirationYear'; size = 4;  sourceField = @('operatorLicenseExpirationYear'); targetField = 'OperatorLicenseExpirationYear' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';         size = 20; sourceField = @('operatorLicenseNumber');         targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                      size = 1;  sourceField = @('raceCode');                      targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode';                       size = 1;  sourceField = @('sexCode');                       targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'YearsPastViolationsWanted';     size = 2;  sourceField = @('yearsPastViolationsWanted');     targetField = 'YearsPastViolationsWanted' }
    )
    combinations = @(
        # ZWAR.N: Warrant name search -- Name+Sex+Race+DOB+[State,ImageIndicator] (5 set, most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','raceCode','sexCode'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'ZWAR.N'
            state                 = 'In/Out'
        }
        # ZWAR.O: Warrant OLN search -- Name+Sex+Race+OLN+[ExpYear,State,ImageIndicator] (5 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','operatorLicenseNumber','raceCode','sexCode'); any = @('operatorLicenseExpirationYear','registrationState','imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZWAR.O'
            state                 = 'In/Out'
        }
        # ZLDR.N: DL by Name+DOB+Sex+[State,ImageIndicator] (4 set, Name before OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','sexCode'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'ZLDR.N'
            state                 = 'In/Out'
        }
        # ZLDR.O: DL by OLN+[State,ImageIndicator,YearsPastViolationsWanted] (1 set, least specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState','imageIndicator','yearsPastViolationsWanted') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZLDR.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- ZWAR (warrant name/OLN), ZLDR (Name/OLN). MD license query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# 1f. DriverHistoryQuery
# XML v6: 2 combos (ZDRV x2) -- duplicate keyRef
# Invented distinct keyRefs: ZDRV.O (OLN), ZDRV.N (Name+DOB+Sex)
# Devdoc: (In) only -- no OOS combos for DH
# DH-suffix fieldIds isolate from DL field pool (AP #14)
# queriesToDeselect + DH-suffix = mutual deselect without deadlock
# SexCode required for Name combo (in set[] per metadata)
# Combo ordering: Name before OLN (operational priority)
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        # ZDRV.N: DH by Name+DOB+Sex+[ImageIndicator] -- Name before OLN (operational priority)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'ZDRV.N'
            state                 = 'In'
        }
        # ZDRV.O: DH by OLN+[ImageIndicator]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'ZDRV.O'
            state                 = 'In'
        }
    )
    description     = 'DriverHistoryQuery -- ZDRV (Name+DOB+Sex, OLN). DH-suffix fields. In-state only.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1g. GunQuery
# XML v3: 1 combo (ZGUN) -- all mandatory
# set: GunCaliber, GunMake, GunSerialNumber
# GunMake size=23 (larger than NJ/CA 3-char NCIC code -- MD may accept free text)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');   targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('firearmMake');  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunCaliber','firearmMake','serialNumber'); any = @() }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'ZGUN'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- ZGUN (serial+make+caliber). All fields mandatory.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML v3: 1 combo (ZART) -- both fields mandatory
# set: ArticleTypeCode, ArticleSerialNumber
# ArticleTypeCode: size=7 -- devdoc says nothing about code source.
# Use codeTypeSource='NCIC' for non-CA providers (NCIC article type codes).
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
            keyReference          = 'ZART'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- ZART (serial+type). MD property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML v4: 2 combos (ZBOA x2) -- duplicate keyRef
# Invented distinct keyRefs: ZBOA.H (hull), ZBOA.R (reg)
# ImageIndicator in any[] on both combos
# No State field in BoatQuery (not in metadata)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';  size = 20; sourceField = @('boatHullIdNumber');  targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';    size = 1;  sourceField = @('imageIndicator');    targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8; sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
    )
    combinations = @(
        # ZBOA.H: Hull + [Reg, ImageIndicator]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationNumber','imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ZBOA.H'
            state                 = 'In/Out'
        }
        # ZBOA.R: Reg + [Hull, ImageIndicator]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ZBOA.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- ZBOA (hull, reg). MD boat inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'MD_METERS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'MD_METERS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$mdBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for MD_METERS v${Version}"
    name           = 'MD_METERS'
    type           = 'BUNDLE'
    provider       = 'MD_METERS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# No CaRequestPurposeCode (not a CA system).
# State: no initialValue on Vehicle and Person (officer selects explicitly).
# ImageIndicator: Vehicle (N default), Person (Y for photos), Boat (N default).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery fields. ImageIndicator in metadata.
# State: no initialValue (officer selects explicitly -- add back after live testing if needed)
# PlateType: initialValue='PC', PlateYear: initialValue='2026'
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'imageIndicator_Input';       node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '24' 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (ZVEH/ZLRG). Plate and VIN search paths.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# Serves 2 QIDMs: DL + DH (co-fire with DH-suffix + queriesToDeselect).
# State: no initialValue (ZLDR combos have State in any[], officer selects explicitly)
# RaceCode: codeTypeCategory=NIBRS_RACE, codeTypeSource=NIBRS
# ImageIndicator: initialValue='Y' (for person photo requests)
# DH-suffix fields: operatorLicenseNumberDH, nameLastDH, nameFirstDH, birthDateDH, sexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'imageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_3' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' }    'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseExpirationYear_Input'; node = Inp 'operatorLicenseExpirationYear' 'License Expiration Year' '4' 'ROW_PER_4' }
                @{ id = 'yearsPastViolationsWanted_Input';     node = Inp 'yearsPastViolationsWanted'     'Years Past Violations'  '2' 'ROW_PER_4' }
            )}
            # DH-suffix fields (Driver History -- isolated from DL field pool per AP #14)
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_PER_5' }
                @{ id = 'sexCodeDH_Input';               node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'nameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_6' }
                @{ id = 'nameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('6'); fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_7' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (ZWAR/ZLDR) + DH (ZDRV). Co-fire on OLN.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (ZGUN -- all mandatory)
# GunMake: size=23 (MD accepts longer make codes, but use NCIC dropdown)
# No ImageIndicator in GunQuery metadata.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'gunCaliber_Input';   node = Sel 'gunCaliber'   'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- ZGUN (serial+make+caliber). All fields mandatory.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleSingleQuery only (ZART). Serial + ArticleType.
# ArticleTypeCode: codeTypeSource='NCIC' for non-CA providers
# =====================================================================
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode'    'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'articleBrand_Input';        node = Inp 'articleBrand' 'Brand' '6' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- ArticleSingleQuery (ZART). Serial + type.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# BoatQuery fields: Hull, Reg, ImageIndicator
# No State field in BoatQuery metadata.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_1' }
                @{ id = 'registrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number'  '8'  'ROW_BOA_1' }
                @{ id = 'imageIndicator_Input';     node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- ZBOA (hull, reg). ImageIndicator in any[].'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @(
        $vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm
    )
    description    = 'Entity form configurations for MD_METERS'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Vehicle','Person','Firearm','Article','Boat')
        CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
        FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE, with MD patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add registrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'registrationState'

# Patch 3: add registrationState to RMS Person QIDM
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('registrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'registrationState'
}

# =====================================================================
# Patch 6: RMS CLEANUP -- remove unused HIDLE fields
# =====================================================================

# Vehicle: remove dead attrs + combos + clean any[]
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehQidm.attributes = @($rmsVehQidm.attributes | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object {
    $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName')
})
foreach ($combo in $rmsVehQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

# Person: remove dead attrs (SSN + OOS + race) + dead combos (SSN + OOS)
# Race: form uses codeTypeCategory='NIBRS_RACE' (stores string code), but RMS race attr
# has useAttributeId=true -- incompatible per AP #11. Remove RMS race attr + combo refs.
$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})
# Clean race refs from remaining combo any[]/set[]
foreach ($combo in $rmsPersonQidm.combinations) {
    if ($combo.requirements.set) {
        $combo.requirements.set = @($combo.requirements.set | Where-Object { $_ -ne 'RaceCode' -and $_ -ne 'raceCode' })
    }
    if ($combo.requirements.any) {
        $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'RaceCode' -and $_ -ne 'raceCode' })
    }
}

# Patch 7: RMS autoSelect=true
$rmsVehQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
$rmsPersonQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force

# Patch 8: CAD field name alignment -- rename HIDLE RMS sourceField + combo refs to camelCase
$cadRenames = @{
    'LicensePlateNumberIn'        = 'licensePlateNumber'
    'LicensePlateNumberOut'       = 'licensePlateNumberOut'
    'VehicleIdentificationNumber' = 'vehicleIdentificationNumber'
    'VehicleMakeCode'             = 'vehicleMakeCode'
    'VehicleModelCode'            = 'vehicleModelCode'
    'VehicleYear'                 = 'vehicleYear'
    'RegistrationState'           = 'registrationState'
    'RegistrationStateOut'        = 'registrationStateOut'
    'OwnerFirstName'              = 'ownerFirstName'
    'OwnerLastName'               = 'ownerLastName'
    'OperatorLicenseNumber'       = 'operatorLicenseNumber'
    'NameFirst'                   = 'nameFirst'
    'NameLast'                    = 'nameLast'
    'NameMiddle'                  = 'nameMiddle'
    'NameSuffix'                  = 'nameSuffix'
    'BirthDate'                   = 'birthDate'
    'SexCode'                     = 'sexCode'
    'RaceCode'                    = 'raceCode'
    'ImageIndicator'              = 'imageIndicator'
}
foreach ($cfg in $rmsBundle.configurations) {
    if (-not $cfg.attributes) { continue }
    foreach ($attr in $cfg.attributes) {
        if ($attr.name -and $cadRenames.ContainsKey($attr.name)) {
            $attr.name = $cadRenames[$attr.name]
        }
        if ($attr.sourceField) {
            $attr.sourceField = @($attr.sourceField | ForEach-Object {
                if ($cadRenames.ContainsKey($_)) { $cadRenames[$_] } else { $_ }
            })
        }
    }
    if (-not $cfg.combinations) { continue }
    foreach ($combo in $cfg.combinations) {
        if ($combo.primaryFieldReference -and $cadRenames.ContainsKey($combo.primaryFieldReference)) {
            $combo.primaryFieldReference = $cadRenames[$combo.primaryFieldReference]
        }
        if ($combo.requirements.set) {
            $combo.requirements.set = @($combo.requirements.set | ForEach-Object {
                if ($cadRenames.ContainsKey($_)) { $cadRenames[$_] } else { $_ }
            })
        }
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | ForEach-Object {
                if ($cadRenames.ContainsKey($_)) { $cadRenames[$_] } else { $_ }
            })
        }
    }
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $mdBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built MD_METERS_BASE.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT