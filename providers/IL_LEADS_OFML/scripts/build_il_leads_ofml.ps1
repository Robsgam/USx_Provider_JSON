# build_il_leads_ofml.ps1  -- IL_LEADS_OFML v1.x BASE (5 basic queries)
# Builds IL_LEADS_OFML_BASE.json from source\IL_LEADS_OFML.xml (metadata v8) + KB specs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_il_leads_ofml.ps1 [-Version X.X]
#
# INPUTS:
#   source\IL_LEADS_OFML.xml   -- XML metadata [AUTHORITATIVE]
#   source\IL_LEADS_OFML.pdf   -- CommSys devdoc [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# BASIC QUERIES ONLY (5 queries, 9 combinations):
#   ArticleSingleQuery v4        -- 1 combo: QA serial+type (OAN in any[])
#   BoatQuery v4                  -- 2 combos: BQ hull, BQ reg (State in metadata set[] but devdoc has as M)
#   DriverLicenseQuery v2         -- 2 combos: Z2 Name+DOB, Z2 OLN
#   GunQuery v2                   -- 1 combo: QG serial
#   VehicleRegistrationQuery v2   -- 3 combos: Z5 plate(in-state), Z2 plate(OOS), Z2 VIN(OOS)
#
# REMOVED (14 non-basic queries):
#   WMPIWantedPersonQuery, WMPIMissingPersonQuery, WMPIUnidentifiedPersonQuery
#   CCHCriminalHistoryQHQuery, CCHCriminalHistoryQR1Query, CCHCriminalHistoryQRQuery
#   DriverLicenseByNameQuery, FirearmsOwnersIdQuery, IlLeadsDriverAbstractQuery
#   IlLeadsHandicapPlacardQuery, IlLeadsLeadsTypeQuery, IlLeadsSoundExQuery
#   IlLeadsVehicleTitleQuery, IlLeadsWantedQWXQuery
#
# IL-SPECIFIC:
#   No CaRequestPurposeCode
#   No DriverHistoryQuery (not in IL metadata)
#   ImageIndicator present in Boat, DL, Gun, VehicleReg
#   Date format: MMddyyyy (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','MMddyyyy'])
#   Composite Name: FormatStringRuleHandler (LastName, FirstName format)
#   State initialValue=IL -- DL/VehReg have separate in-state vs OOS keyRefs (Z5 vs Z2),
#     BUT devdoc shows (In) for in-state and (Out) for OOS on DL/VehReg. State=IL defaults
#     to in-state combos. Officers can change State for OOS. Safe to set.
#   ArticleTypeCode: codeTypeSource='NCIC' (devdoc references NCIC codes)
#
# ENTITIES (5 QUERYINPUTFORM -- "Other" entity removed):
#   Vehicle  -- Plate+VIN+State+PlateType+PlateYear+VehMake+VehYear+ImageIndicator
#   Person   -- OLN+Name(First/Last/Middle/Suffix)+DOB+Sex+State+Race+ImageIndicator
#   Firearm  -- Serial+Make+Caliber
#   Article  -- Serial+OAN+ArticleType
#   Boat     -- Reg#+Hull+State+ImageIndicator

param(
    [string]$Version = "1.1",
    [string]$Phase   = "base"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\IL_LEADS_OFML_BASE.json"
$OUTREAD  = "$DIR\IL_LEADS_OFML_BASE_READABLE.json"
$VEROUT   = "$PHASEDIR\IL_LEADS_OFML_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"

# =====================================================================
# BUNDLE 1: IL_LEADS_OFML PROVIDER
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
        [PSCustomObject]@{ name = 'CDCName'; size = 10; sourceField = @('CDCName'); targetField = 'CDCName' }
    )
    combinations = @(
        [PSCustomObject]@{
            keyReference = 'AUTH'
            requirements = [PSCustomObject]@{ set = @('ORI','mnemonic'); any = @('dexStateUserId','CDCName') }
        }
    )
    description                = 'Authentication configuration for IL LEADS OFML'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'IL_LEADS_OFML'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'IL_LEADS_OFML'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING 
$results = Build-CommsysQrdm -ProviderName 'IL_LEADS_OFML'
$results.name        = 'IL_LEADS_OFML_Results'
$results.description = 'Results mapping for IL LEADS OFML'
$results.provider    = 'IL_LEADS_OFML'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'IL_LEADS_OFML_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'IL_LEADS_OFML'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML v2: 3 combos: Z5 plate (in-state), Z2 plate (OOS with State), Z2 VIN (OOS with State)
# Devdoc: (In) plate, (In) VIN, (In/Out) plate+state+type+year, (Out) VIN+State, (Out) plate+type+year+State
# State initialValue=IL: safe for Z5 in-state; officer clears State for OOS Z2
# ImageIndicator in metadata any[]
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('imageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';   size = 1;  sourceField = @('relatedHitSearchIndicator');   targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS plate (most specific -- requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator','licensePlateTypeCode','licensePlateYear','relatedHitSearchIndicator','registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'Z2.P'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('imageIndicator','relatedHitSearchIndicator','vehicleMakeCode','vehicleYear','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'Z2.V'
            state                 = 'In/Out'
        }
        # In-state plate (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator','licensePlateTypeCode','licensePlateYear','relatedHitSearchIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'Z5'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- Z5 (in-state plate), Z2 (OOS plate/VIN).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'IL_LEADS_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'IL_LEADS_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML v2: 2 combos: Z2 Name+DOB (in-state), Z2 OLN
# Devdoc: (In) Name+DOB + optional ImageIndicator/RelatedHitSearch/SexCode
#          (In) OLN + optional ImageIndicator/RelatedHitSearch
#          (Out) variants add State
# Name is composite (type=Name in metadata)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 10; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name+DOB (in-state)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('imageIndicator','operatorLicenseNumber','relatedHitSearchIndicator','sexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'Z2.N'
            state                 = 'In/Out'
        }
        # OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','relatedHitSearchIndicator','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'Z2.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- Z2 (Name+DOB, OLN). IL DMV driver license query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery
# XML v2: 1 combo: QG serial
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';              size = 4;  sourceField = @('gunCaliber');              targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                 size = 3;  sourceField = @('firearmMake');             targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';         size = 20; sourceField = @('serialNumber');            targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';          size = 1;  sourceField = @('imageIndicator');          targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1; sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake','imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). IL NCIC firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery
# XML v4: 1 combo: QA serial+type (OAN in any[])
# ArticleTypeCode: codeTypeSource='NCIC'
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @('ownerAppliedNumber') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial+type). IL article inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery
# XML v4: 2 combos: BQ hull, BQ reg
# Devdoc: (In/Out) Hull+State, (In/Out) Reg+State
# State is Mandatory per devdoc, in metadata set[] via ImageIndicator etc in any[]
# ImageIndicator in any[]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('boatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 20; sourceField = @('registrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator','relatedHitSearchIndicator','registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('imageIndicator','relatedHitSearchIndicator','registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (hull, reg). IL boat inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'IL_LEADS_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'IL_LEADS_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# Build the provider bundle with 5 basic QIDMs only
$ilBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery,
        $dlQuery,
        $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for IL_LEADS_OFML v${Version} (5 basic queries)"
    name           = 'IL_LEADS_OFML'
    type           = 'BUNDLE'
    provider       = 'IL_LEADS_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity
# "Other" entity removed (was IlLeadsLeadsTypeQuery only)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery only (Title/Handicap queries removed)
# State initialValue=IL (safe -- all combos use State in any[] not set[])
# PlateType=PC, PlateYear=2026, ImageIndicator=N (vehicle standard)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'IL' } 'ROW_VEH_1' }
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
                @{ id = 'vehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'relatedHitSearchIndicator_Input'; node = InpH 'relatedHitSearchIndicator' 'Related Hit Search' '1' 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (5 basic queries build).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# Serves DriverLicenseQuery only (all other Person QIDMs removed)
# State initialValue=IL
# ImageIndicator=Y (person standard)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'IL' } 'ROW_PER_1' }
                @{ id = 'imageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'relatedHitSearchIndicator_Input'; node = InpH 'relatedHitSearchIndicator' 'Related Hit Search' '1' 'ROW_PER_4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DriverLicenseQuery (5 basic queries build).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG serial only)
# =====================================================================
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'imageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('12'); fields = @(
                @{ id = 'gunCaliber_Input'; node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'relatedHitSearchIndicator_Input'; node = InpH 'relatedHitSearchIndicator' 'Related Hit Search' '1' 'ROW_GUN_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial). NCIC firearm query.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleTypeCode: codeTypeSource='NCIC'
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'        '20' 'ROW_ART_1' }
                @{ id = 'ownerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';    node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial+type). IL article inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# State initialValue=IL
# ImageIndicator=Y
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number' '20' 'ROW_BOA_1' }
                @{ id = 'boatHullIdNumber_Input';    node = Inp 'boatHullIdNumber'   'Hull ID Number'      '20' 'ROW_BOA_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState'  'State' @{ attributeTypeId = 'STATE'; initialValue = 'IL' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_2' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Related Hit Search' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (hull, reg). IL boat inquiry.'
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
    description    = 'Entity form configurations for IL_LEADS_OFML (5 basic queries)'
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
    bundles = @($entitiesBundle, $ilBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built IL_LEADS_OFML_BASE.json v${Version} (5 basic queries)"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT