# build_ny_nyspin_ejustice.ps1
# Builds NY_NYSPIN_EJUSTICE_BASE.json from source\NY_NYSPIN_EJUSTICE.XML (field authority) + KB specs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ny_nyspin_ejustice.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\NY_NYSPIN_EJUSTICE.XML     -- XML metadata (field names, sizes, combinations, keyRefs) [AUTHORITATIVE]
#   source\New York (NYSPIN_XML).pdf  -- CommSys devdoc (Basic Queries Supported) [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs) (RMS bundle, QUERYRESULTDATAMAPPING)
#
# BASIC QUERIES SUPPORTED (7 transactions, per devdoc):
#   VehicleRegistrationQuery             RVEH (plate), RVIN (VIN+state OOS), RCAR (VIN NY DMV)
#   BoatQuery                            BVEH (reg+state OOS), BVIN (hull+state OOS), RVEH (reg NY), RCAR (hull NY)
#   DriverLicenseQuery                   DLIC (OLN), DLICN (Name+DOB+Sex -- invented keyRef)
#   DriverHistoryQuery                   DALL (OLN), DALH (Name+DOB+Sex -- invented keyRef)
#   GunQuery                             GINQ
#   ArticleSingleQuery                   AINQ
#
# NOT INCLUDED (not in devdoc "Basic Queries Supported"):
#   WantedPersonQuery (WINQ), MissingPersonQuery (MINQ), NyNyspinBoatBINQQuery (BINQ),
#   NyNyspinBoatRegistrationNameQuery, NyNyspinVehicleRegistrationNameQuery, CBICanada*,
#   NyNyspinNicbAllFilesQuery, WMPIProtectionOrderQuery, all Entry/Cancel/Clear transactions
#
# ENTITIES (5 QUERYINPUTFORM -- single card each, Phase 1):
#   Vehicle, Person, Firearm, Article, Boat
#
# STATE: NCIC pattern (UNCONFIRMED on NY -- test ST-1 on first import)
#   Visible Sel 'RegistrationState' (attributeTypeId=STATE, NO initialValue)
#   CommSys attr: codeTypeProvider=NCIC (reverse-lookup attr ID -> 2-letter code)
#   RMS: KB standard (useAttributeId=true + AttributeArrayWrapperRuleHandler on Vehicle)
#   Fallback: dual-field (SelH for RMS + InpH for XML) if NCIC fails
#
# SEX: Full 3-layer pattern
#   Form: attributeTypeId=SEX + codeTypeProvider=NIBRS
#   QIDM: codeTypeProvider=NIBRS (reverse-lookup)
#   RMS: KB standard (useAttributeId=true, NO ArrayWrapper)
#
# NAME: 4-field (Last, First, Middle, Suffix)
#   FormatStringRuleHandler args=[', ',' ',' '] -> "LAST, FIRST MIDDLE SUFFIX"
#
# COMBO PRIORITY (most set[] fields first per LIMITATION #3):
#   Vehicle: RVIN (VIN+State) > RVEH (Plate) > RCAR (VIN only)
#   DL: DLICN (Name+DOB+Sex, 4 set) > DLIC (OLN, 1 set)
#   DH: DALH (Name+DOB+Sex, 4 set) > DALL (OLN, 1 set)
#   Boat: BVEH (Reg+State) > BVIN (Hull+State) > RVEH (Reg) > RCAR (Hull)
#
# DL+DH ISOLATION (AP #14 / LIMITATION #24-25):
#   DH QIDM uses DH-suffix fieldIds (operatorLicenseNumberDH, nameLastDH, etc.)
#   DL QIDM: autoSelect=true, queriesToDeselect=@('DriverHistoryQuery')
#   DH QIDM: autoSelect=true, queriesToDeselect=@('DriverLicenseQuery')
#   Person QIF has both regular DL fields AND separate DH-suffix fields.

param(
    [string]$Version = "1.5",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NY_NYSPIN_EJUSTICE_BASE.json"
$VEROUT   = "$PHASEDIR\NY_NYSPIN_EJUSTICE_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: NY_NYSPIN_EJUSTICE PROVIDER
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');       targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');   targetField = 'Mnemonic' }
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
    description                = 'Authentication configuration for NY NYSPIN EJUSTICE'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NY_NYSPIN_EJUSTICE'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NY_NYSPIN_EJUSTICE'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING 
$results = Build-CommsysQrdm -ProviderName 'NY_NYSPIN_EJUSTICE'
$results.name        = 'NY_NYSPIN_EJUSTICE_Results'
$results.description = 'Results mapping for NY NYSPIN EJUSTICE'
$results.provider    = 'NY_NYSPIN_EJUSTICE'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NY_NYSPIN_EJUSTICE_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NY_NYSPIN_EJUSTICE'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: VehicleRegistrationQuery v1
#   RVEH: Choice(set[Plate,any[PlateType]], set[Plate,PlateType,PlateYear,State]), any[Image]
#         -> Flatten: set[LicensePlateNumber], any[PlateType, PlateYear, State]
#   RCAR: set[VIN], any[Image]
#   RVIN: set[VIN, State], any[Image, VehicleMakeCode, VehicleYear]
# Order: RVIN (most specific) > RVEH > RCAR (least specific)
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';        size = 10; sourceField = @('licensePlateNumber');        targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('imageIndicator');              targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','registrationState'); any = @('imageIndicator','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator','licensePlateTypeCode','licensePlateYear','registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery -- RVIN (VIN+State OOS), RVEH (plate), RCAR (VIN NY DMV)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: DriverLicenseQuery v2
#   DLIC (OLN): set[OLN], any[ImageIndicator, State]
#   DLIC (Name): set[BirthDate, Name, SexCode], any[ImageIndicator, State]
# Duplicate DLIC keyRef -> invent DLICN for Name path (LIMITATION #21)
# NyNyspinDriverLicenseNameQuery (DGRP) REMOVED -- devdoc combos 1-4 all
# under DriverLicenseQuery; DGRP created duplicate checkbox. Name searches
# handled by DLICN instead. DGRP can be re-added as separate QIDM if needed.
# autoSelect=true + queriesToDeselect=DriverHistoryQuery (AP #14 / LIM #24-25)
# SexCode: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
# State: codeTypeProvider=NCIC (reverse-lookup attr ID -> 2-letter code)
# Name: 4-field FormatStringRuleHandler -> "LAST, FIRST MIDDLE SUFFIX"
# Combo order: DLICN (4 set) before DLIC (1 set) per LIMITATION #3
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('nameLast','nameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','sexCode'); any = @('imageIndicator','registrationState','nameMiddle','nameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'DLICN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DLIC'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery -- DLICN (Name+DOB+Sex), DLIC (OLN). queriesToDeselect=DH.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# 1f. DriverHistoryQuery (was 1g)
# XML: DriverHistoryQuery v3
#   DALL (OLN): Choice(set[OLN], set[OLN,PurposeCode,Requestor,State])
#               any[ImageIndicator, NyNyspinTransactionName]
#               -> Flatten: set[OLN-DH], any[ImageIndicator, State]
#   DALL (Name): Choice(set[DOB,Name,Sex], set[DOB,Name,PurposeCode,Requestor,Sex,State])
#                any[ImageIndicator, NyNyspinTransactionName]
#                -> Flatten: set[DOB-DH,NameLast-DH,NameFirst-DH,SexCode-DH], any[Image, State, Middle-DH, Suffix-DH]
# Duplicate DALL keyRef -> invent DALH for Name path (confirmed NY v1.19)
# PurposeCode, Requestor, NyNyspinTransactionName: not needed for basic queries.
# DH-suffix fieldIds isolate DH from DL field pool (AP #14 / LIM #24-25)
# queriesToDeselect=DriverLicenseQuery -- mutual deselect with DL QIDM
# Combo order: DALH (4 set) before DALL (1 set) per LIMITATION #3
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('nameLastDH','nameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDateDH','nameLastDH','nameFirstDH','sexCodeDH'); any = @('imageIndicator','registrationState','nameMiddleDH','nameSuffixDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'DALH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('imageIndicator','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALL'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery -- DALH (Name+DOB+Sex), DALL (OLN). DH-suffix fields. queriesToDeselect=DL.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1h. GunQuery
# XML: GunQuery v1, keyRef GINQ
#   set[GunSerialNumber], any[GunCaliber, GunMake, RelatedHitSearchIndicator]
# RelatedHitSearchIndicator: not on form (Phase 1). Skipped.
# GunMake/GunCaliber: NCIC codeTypeSource (confirmed working).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('gunMake');          targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('gunSerialNumber');  targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';  size = 1;  sourceField = @('imageIndicator');   targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunMake','gunCaliber','imageIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'GINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery in NY NYSPIN EJUSTICE'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1i. ArticleSingleQuery
# XML: ArticleSingleQuery v1, keyRef AINQ
#   set[ArticleSerialNumber, ArticleTypeCode], any[ImageIndicator, RelatedHitSearchIndicator]
# ImageIndicator, RelatedHitSearchIndicator: not on Article form (Phase 1).
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown).
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('articleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';      size = 1;  sourceField = @('imageIndicator');      targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @('imageIndicator') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'AINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery in NY NYSPIN EJUSTICE'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1j. BoatQuery
# XML: BoatQuery v2
#   RVEH: set[RegistrationNumber], any[ImageIndicator]              -- NY reg
#   RCAR: set[BoatHullIdNumber], any[ImageIndicator]                -- NY hull
#   BVEH: set[RegistrationNumber, State], any[ImageIndicator]       -- OOS reg
#   BVIN: set[BoatHullIdNumber, State], any[ImageIndicator]         -- OOS hull
# ImageIndicator: not on Boat form (Phase 1).
# Order: BVEH > BVIN > RVEH > RCAR (most-specific first)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 10; sourceField = @('registrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery -- BVEH/BVIN (OOS), RVEH/RCAR (NY)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$nyBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NY_NYSPIN_EJUSTICE v${Version}"
    name           = 'NY_NYSPIN_EJUSTICE'
    type           = 'BUNDLE'
    provider       = 'NY_NYSPIN_EJUSTICE'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity. All fields on one card.
# NCIC state pattern: visible RegistrationState, no initialValue (blank default).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VEHICLE SEARCH: Plate + State + PlateType + PlateYear + VehicleYear + VIN + VehicleMake
# RVIN fires when VIN+State present. RVEH fires when Plate present. RCAR when VIN alone.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('8','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
                @{ id = 'VehicleYear_Input';          node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('8','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
                @{ id = 'VehicleMakeCode_Input';             node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('4'); fields = @(
                @{ id = 'ImageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate (RVEH), VIN+State OOS (RVIN), VIN NY DMV (RCAR). NCIC state pattern.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# PERSON SEARCH: DL fields + DH-suffix fields on single card
# DL fields: OLN + State + Image + Last + First + Middle + Suffix + DOB + Sex
# DH fields: OLN(DH) + Last(DH) + First(DH) + Middle(DH) + Suffix(DH) + DOB(DH) + Sex(DH)
# 2 QIDMs target this form (DL, DH). queriesToDeselect + DH-suffix isolate them.
# SexCode: attributeTypeId=SEX + codeTypeProvider=NIBRS (3-layer pattern)
# RegistrationState: attributeTypeId=STATE (NCIC pattern, no initialValue)
# ImageIndicator: FormSelect YES_NO_UNKNOWN, default Y (officer wants photo)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('8','2','2'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'registrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'ImageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '35' 'ROW_PER_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '35' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '35' 'ROW_PER_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '10' 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                    'ROW_PER_4' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (Driver History)' '20' 'ROW_PER_5' }
                @{ id = 'NameLastDH_Input';              node = Inp 'nameLastDH'  'Last Name (DH)'  '35' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'nameFirstDH'  'First Name (DH)' '35' 'ROW_PER_6' }
                @{ id = 'NameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH)' '35' 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('6','6'); fields = @(
                @{ id = 'NameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)' '10' 'ROW_PER_7' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'birthDateDH'  'DOB (DH)'         'ROW_PER_7' }
            )}
            @{ id = 'ROW_PER_8'; cols = @('6'); fields = @(
                @{ id = 'SexCodeDH_Input'; node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_8' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DLIC/DLICN) + DH (DALL/DALH) on shared card. DH-suffix fields. NCIC state, NIBRS sex.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (GINQ)
# XML: set[GunSerialNumber], any[GunMake, GunCaliber]
# GunMake/GunCaliber: NCIC code type source.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'gunMake'         'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','4'); fields = @(
                @{ id = 'GunCaliber_Input';     node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- serial + optional make/caliber'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (AINQ)
# XML: set[ArticleSerialNumber, ArticleTypeCode]
# ArticleTypeCode: CA_CLETS (NCIC gives empty dropdown)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'ImageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- serial + type code'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# BOAT SEARCH: RegNumber + Hull ID + State
# BVEH/BVIN (OOS with state), RVEH/RCAR (NY without state)
# RegistrationState: attributeTypeId=STATE (NCIC pattern, no initialValue)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '10' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'registrationState' 'State (leave blank for NY)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                @{ id = 'ImageIndicator_Input';   node = Sel 'imageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- Reg (BVEH/RVEH) and Hull (BVIN/RCAR). NCIC state for OOS.'
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
    description    = 'Entity form configurations (shared across providers)'
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
# BUNDLE 3: RMS (from KB specs)
# =====================================================================
$rmsBundle = Build-RmsBundle
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $nyBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

$OUTREADABLE = "$DIR\NY_NYSPIN_EJUSTICE_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built NY_NYSPIN_EJUSTICE_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green