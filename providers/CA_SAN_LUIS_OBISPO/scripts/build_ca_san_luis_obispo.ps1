# build_ca_san_luis_obispo.ps1  -- CA_SAN_LUIS_OBISPO v1.3 BASE
# Builds CA_SAN_LUIS_OBISPO_BASE.json from source\CA_SAN_LUIS_OBISPO.xml metadata + KB specs.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_san_luis_obispo.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\CA_SAN_LUIS_OBISPO.xml   -- XML metadata [AUTHORITATIVE]
#   source\CA_SAN_LUIS_OBISPO.pdf   -- CommSys devdoc [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# METADATA SUMMARY (CA_SAN_LUIS_OBISPO v1):
#   VehicleRegistrationQuery  -- 6 combos in XML, collapsed to 4 (QV plate/VIN, RQ plate/VIN OOS)
#   DriverLicenseQuery        -- 6 combos in XML, collapsed to 3 (L1.O, L1.N, DQ.O)
#   DriverHistoryQuery        -- 4 combos, BUILD ALL (B2.N, B2.O in-state + KQ.N, KQ.O OOS)
#   GunQuery                  -- 1 combo (QGB serial)
#   ArticleSingleQuery        -- 1 combo (QA serial)
#   BoatQuery                 -- 2 combos (BQ hull, QB reg)
#
# CA_SAN_LUIS_OBISPO-SPECIFIC:
#   CaRequestPurposeCode     -- added to DH QIDM PurposeCode attr. Visible Inp initialValue='C'.
#   Regional message switch   -- NOT a direct CLETS interface.
#   No ImageIndicator         -- not in SLO metadata.
#   No State initialValue     -- LIMITATION #30: separate in-state vs OOS keyRefs.
#   Date format: yyyyMMdd     -- DL BirthDate max=10, DH BirthDate max=8.
#   Name format: 'Name' composite, max 30 chars (Last, First) -- FormatStringRuleHandler.
#   Shorter keyRefs than CLETS (QV not IA.QV, etc.)
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 14 combos):
#   VehicleRegistrationQuery   QV.P (Plate), QV.V (VIN), RQ.P (OOS Plate), RQ.V (OOS VIN)
#   DriverLicenseQuery         L1.O (OLN), L1.N (Name), DQ.O (OOS OLN)
#   DriverHistoryQuery         B2.N (Name in-state), B2.O (OLN in-state), KQ.N (Name OOS), KQ.O (OLN OOS)
#   GunQuery                   QGB (Serial)
#   ArticleSingleQuery         QA (Serial)
#   BoatQuery                  BQ (Hull), QB (Reg)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- Plate + VIN + State + PlateType + PlateYear + VehMake + VehYear
#   Person   -- OLN + Name + DOB + Sex + State
#   Firearm  -- Serial + Make + Caliber + Type
#   Article  -- Serial + ArticleType + ArticleBrand + ArticleCategory
#   Boat     -- Hull + Reg# + State
#
# PERSON (2 QIDMs co-fire with DH-suffix isolation):
#   DL + DH share Person entity/form.
#   Both have autoSelect=true + queriesToDeselect (AP #14 pattern).
#   DH-suffix fieldIds: operatorLicenseNumberDH, nameLastDH, nameFirstDH, birthDateDH, sexCodeDH, caRequestPurposeCodeDH.
#   DH QIDM sourceField/combo refs use DH-suffix names.

param(
    [string]$Version = '1.3',
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_SAN_LUIS_OBISPO_BASE.json"
$VEROUT   = "$PHASEDIR\CA_SAN_LUIS_OBISPO_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: CA_SAN_LUIS_OBISPO PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'CA_SAN_LUIS_OBISPO'

$results = Build-ProviderQrdm -ProviderName 'CA_SAN_LUIS_OBISPO'

$qmf = Build-Qmf -ProviderName 'CA_SAN_LUIS_OBISPO'

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: 6 combos, collapsed to 4: QV.P (plate in-state), QV.V (VIN in-state),
#   RQ.P (plate OOS), RQ.V (VIN OOS). 4# and 4V combos COVERED by QV.
# NO CaRequestPurposeCode -- not in SLO metadata.
# LIMITATION #30: No State initialValue -- in-state vs OOS routing by State presence.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS Plate (4 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # OOS VIN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationState','vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state Plate (1 set -- plate before VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('licensePlateTypeCode','licensePlateYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        # In-state VIN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ.P (OOS plate), RQ.V (OOS VIN), QV.P (plate), QV.V (VIN). Most-specific first, plate before VIN.'
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
# 1e. DriverLicenseQuery
# XML: 6 combos, collapsed to 3: L1.O (OLN in-state), L1.N (Name in-state),
#   DQ.O (OLN OOS). QVC combos deferred to Phase 2 (supervised release).
# NO CaRequestPurposeCode.
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 17; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Name combo first (2 set, Name before OLN at same count)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst'); any = @('birthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        # OOS OLN (2 set -- OLN + State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.N (Name), DQ.O (OOS OLN), L1.O (OLN). autoSelect+queriesToDeselect DH.'
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
# 1f. DriverHistoryQuery -- DH-suffix fieldIds (AP #14 pattern)
# XML: 4 combos, BUILD ALL:
# DH-suffix fields isolate from DL field pool:
#   operatorLicenseNumberDH, nameLastDH, nameFirstDH, birthDateDH, sexCodeDH, caRequestPurposeCodeDH
# PurposeCode: sourced from caRequestPurposeCodeDH.
# Combo ordering: most set[] first (Name before OLN within each group).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name -- most specific (4 DH set + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLastDH','nameFirstDH','birthDateDH','sexCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # In-state Name (3 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDateDH','nameLastDH','nameFirstDH'); any = @('sexCodeDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'B2.N'
            state                 = 'In/Out'
        }
        # OOS OLN (1 DH set + State in any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (1 DH set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'B2.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- DH-suffix fields. KQ.N (Name OOS), B2.N (Name in-state), KQ.O (OLN OOS), B2.O (OLN in-state). autoSelect+queriesToDeselect DL.'
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
# 1g. GunQuery
# XML: 1 combo (QGB serial).
# NO CaRequestPurposeCode.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial). Firearm query.'
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
# 1h. ArticleSingleQuery
# XML: 1 combo (QA serial). Devdoc has 2 but metadata only 1.
# ArticleTypeCode: codeTypeSource=CA_CLETS (for all CA CLETS-based systems).
# ArticleCategory: additional field from SLO metadata.
# NO CaRequestPurposeCode.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial). Property inquiry.'
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
# 1i. BoatQuery
# XML: 2 combos: BQ (hull), QB (reg). Both support OOS via registrationState.
# NO CaRequestPurposeCode.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (hull), QB (reg). Boat inquiry.'
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
    description    = "Provider configuration for CA_SAN_LUIS_OBISPO v${Version}"
    name           = 'CA_SAN_LUIS_OBISPO'
    type           = 'BUNDLE'
    provider       = 'CA_SAN_LUIS_OBISPO'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# NO CaRequestPurposeCode on any form (field does not exist for SLO).
# No State initialValue on any form (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery fields. No ImageIndicator (not in SLO metadata).
# State: NO initialValue (LIMITATION #30 -- in-state QV vs OOS RQ)
# PlateType: initialValue=PC. PlateYear: initialValue=2026.
# VIN size=20 (per metadata, not 30 like CLETS).
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
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
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (QV plate/VIN + RQ OOS plate/VIN).'
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
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumber_Input';  node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';      node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
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
    description  = 'Person queries -- DL (L1.O/L1.N/DQ.O) + DH (B2.N/B2.O/KQ.N/KQ.O). DH-suffix fields for isolation.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QGB serial only)
# No ImageIndicator (not in SLO metadata).
# NO CaRequestPurposeCode.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QGB (serial).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA serial only)
# ArticleTypeCode: codeTypeSource=CA_CLETS (for all CA CLETS-based systems).
# ArticleCategory: text input (1 char).
# NO CaRequestPurposeCode.
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'  '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode'    'Article Type'   @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'articleBrand_Input';        node = Inp 'articleBrand'       'Brand'          '6' 'ROW_ART_2' }
                @{ id = 'articleCategory_Input';     node = Inp 'articleCategory'    'Category'       '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial). Property inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (BQ hull, QB reg)
# State: NO initialValue (LIMITATION #30).
# NO CaRequestPurposeCode.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'boatHullIdNumber_Input';    node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_1' }
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number'  '8'  'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                @{ id = 'registrationState_Input';   node = Sel 'registrationState'  'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (hull), QB (reg). State for OOS.'
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
    bundles = @($entitiesBundle, $sloBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $OUT -PhasePath $VEROUT `
    -Label "Built CA_SAN_LUIS_OBISPO v${Version}"