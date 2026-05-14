# build_hi_hcjdc_ofml.ps1  -- HI_HCJDC_OFML v1.4 BASE
# Builds HI_HCJDC_OFML_BASE.json from source\HI_HCJDC_OFML.xml + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_hi_hcjdc_ofml.ps1
#
# INPUTS:
#   source\HI_HCJDC_OFML.xml  -- XML metadata (System HCJDC_OFML v9) [AUTHORITATIVE]
#   source\HI_HCJDC_OFML.pdf  -- CommSys devdoc (Basic Queries + CCH + Expanded) [CROSS-CHECK]
#   source\HIDLE.json          -- RMS structural template + hand-built HI reference
#
# SCOPE: Basic Queries only (6 transactions from PDF/XML):
#   ArticleSingleQuery, BoatQuery, DriverHistoryQuery, DriverLicenseQuery, GunQuery, VehicleRegistrationQuery
#   CCH queries (AQ/FQ/IQ/QH/QR/ZR), SecuritiesStolenQuery (QS), WantedPersonQuery (QW standalone)
#   are NOT in scope for Phase 1. The QW combo inside DriverLicenseQuery IS included (per XML metadata).
#
# XML METADATA NOTES:
#   18 MessageKeys: AQ, BQ, DQ, FQ, IQ, KQ, M55L, M55S, QA, QB, QG, QH, QR, QS, QV, QW, RQ, ZR
#   BoatQuery uses <Choice> elements -- split into separate combos per primary field
#   DriverLicenseQuery has a QW (Wanted Person) combo alongside DQ combos -- included per source authority
#   VehicleRegistrationQuery has 6 combos: M55L/M55S (in-state), RQ (out-state), QV (stolen)
#   State2-5 fields on DL/VehicleReg: NOT implementable (platform has no multi-state mechanism). Excluded.
#
# DUPLICATE keyRef INVENTORY (LIMITATION #21):
#   BoatQuery:               BQ (Boat Reg) + QB (Stolen Boat) -> BQ (Reg), QB (Hull)
#   DriverHistoryQuery:      KQ x2           -> KQN (OLN), KQ (Name)
#   DriverLicenseQuery:      DQ x2 + QW     -> DQN (OLN), DQ (Name), QW (distinct)
#   VehicleRegistrationQuery: RQ x2 + QV x2 + M55L + M55S -> M55L, M55S, RQ, QVP, QVV, RQV (6 distinct)
#   GunQuery:                QG              -> QG (no duplicate)
#   ArticleSingleQuery:      QA              -> QA (no duplicate)
#
# PDF vs XML DISCREPANCIES:
#   BoatQuery:   XML uses <Choice>, PDF shows 2 simple combos -- functionally equivalent after split
#   DL:          XML has QW combo (Wanted Person), PDF Basic Queries does NOT show it -- metadata wins
#   VehicleReg:  XML has QV combos (Stolen Vehicle), PDF has them in Expanded section -- metadata wins
#   VehicleReg:  PDF shows 4 combos, XML has 6 -- extra 2 are QV stolen combos
#   State2-5:    PDF says "submit up to 5 states" on DL/VehicleReg -- not implementable, excluded
#   DH:          XML has State in any[], PDF does not mention State -- metadata wins (include State)
#
# HIDLE.json COMPARISON (hand-built reference):
#   HIDLE uses old split-entity In/Out model (OOS fieldIds). We use Phase 1 NCIC state pattern.
#   HIDLE drops QV stolen combos and QW wanted person combo. We include them per metadata.
#   HIDLE GunMake size=10 matches XML. VehicleMakeCode size=4 is wrong (XML=20). We use 20.
#   HIDLE Name format: "First Last Middle Suffix" (4 components, space separators). We follow same format.
#   HIDLE queryLabels: "NCIC", "DMV", "Driver License", "Driver History". We use standard labels.
#   HIDLE DL/DH: queriesToDeselect bidirectional. We replicate + add DH-suffix fieldIds (AP #14).
#
# STATE HANDLING (Phase 1 NCIC pattern):
#   Single visible Sel 'RegistrationState' (attributeTypeId=STATE, initialValue=HI)
#   CommSys State attr: sourceField=RegistrationState, codeTypeProvider=NCIC
#   RMS: useAttributeId=true + AttributeArrayWrapperRuleHandler (HIDLE default)
#   Note: NCIC pattern unconfirmed for HI -- test ST-1 on first import.
#
# SEX HANDLING (NIBRS reverse-lookup):
#   Form: Sel 'SexCode' attributeTypeId=SEX + codeTypeProvider=NIBRS
#   CommSys: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
#   RMS: HIDLE default (useAttributeId=true, NO AttributeArrayWrapperRuleHandler)
#
# DATE FORMAT: MMddyyyy (matching HIDLE)
# NAME FORMAT: "First Last Middle Suffix" with space separators (matching HIDLE)

param(
    [string]$Version = "1.6",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\HI_HCJDC_OFML_BASE.json"
$VEROUT   = "$PHASEDIR\HI_HCJDC_OFML_v${Version}_${DATE}.json"

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
# BUNDLE 1: HI_HCJDC_OFML PROVIDER
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
    description                = 'Authentication configuration for HI HCJDC OFML'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'HI_HCJDC_OFML'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'HI_HCJDC_OFML'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'HI_HCJDC_OFML_Results'
$results.description = 'Results mapping for HI HCJDC OFML'
$results.provider    = 'HI_HCJDC_OFML'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'HI_HCJDC_OFML_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'HI_HCJDC_OFML'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: 6 combos across 3 message keys (M55L, M55S, RQ, QV)
#   M55L: In-state plate (VehicleTypeCode + Plate)
#   M55S: In-state VIN (VehicleTypeCode + VIN)
#   RQ:   Out-state plate (Plate + PlateType + PlateYear), Out-state VIN (VIN)
#   QV:   Stolen plate (Plate + State), Stolen VIN (VIN + MakeCode)
# State2-5 excluded (not implementable). Single RegistrationState (NCIC).
# Combo ordering: M55 (in-state) > RQ-Plate (out-state) > QV (stolen) > RQ-VIN (fallback)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('licensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 20; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleTypeCode';              size = 1;  sourceField = @('vehicleTypeCode');              targetField = 'VehicleTypeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # RQ: Out-state plate (Plate + PlateType + PlateYear) -- 3 set[], plate
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear'); any = @('imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'Out'
        }
        # M55L: In-state plate (VehicleTypeCode + Plate) -- 2 set[], plate
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','licensePlateNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'M55L'
            state                 = 'In'
        }
        # QVP: Stolen plate (Plate + State) -- 2 set[], plate
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVP'
            state                 = 'In/Out'
        }
        # M55S: In-state VIN (VehicleTypeCode + VIN) -- 2 set[], VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','vehicleIdentificationNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'M55S'
            state                 = 'In'
        }
        # QVV: Stolen VIN (VIN + MakeCode) -- 2 set[], VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','vehicleMakeCode'); any = @('imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVV'
            state                 = 'In/Out'
        }
        # RQV: Out-state VIN fallback (VIN only) -- 1 set[], VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQV'
            state                 = 'Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ/M55L/QVP (plate) > M55S/QVV/RQV (VIN). 6 combos, most set[] first.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'HI_HCJDC_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('VehicleStolenQuery')
    provider           = 'HI_HCJDC_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1d2. VehicleStolenQuery
# XML: 2 combos (QV plate, QV VIN) -- separate transaction from VehicleRegistrationQuery
#   keyRef QV x2 -> invented QV.P (plate), QV.V (VIN) (LIMITATION #21)
#   Targets Vehicle entity (same as VehReg) -- different query = separate QIDM, no conflict.
#   Mutual exclusion via queriesToDeselect -- officer manually checks to run stolen query.
# =====================================================================
$vehStolenQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 20; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        # QV.P: Stolen plate (Plate + State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        # QV.V: Stolen VIN (VIN + MakeCode/ImageIndicator)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleStolenQuery -- QV.P (plate), QV.V (VIN). NCIC stolen vehicle check.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'HI_HCJDC_OFML_VehicleStolenQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $false
    queriesToDeselect  = @('VehicleRegistrationQuery')
    provider           = 'HI_HCJDC_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleStolenQuery'
    queryLabel         = 'Vehicle Stolen'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: 3 combos -- DQ (OLN), DQ (Name+Sex+DOB), QW (Name+DOB wanted person)
#   State2-5 excluded. Single RegistrationState (NCIC).
#   QW fires when Name+DOB present but SexCode absent (less restrictive than DQ Name).
#   autoSelect=true, queriesToDeselect=DriverHistoryQuery
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30; sourceField = @('nameFirst','nameLast','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ: Name path -- 4 set[], most specific
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # QW: Wanted Person -- 3 set[]
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'QW'
            state                 = 'In/Out'
        }
        # DQN: OLN path -- 1 set[], least specific
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (Name+Sex+DOB), QW (Wanted Person), DQN (OLN). Most set[] first.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverHistoryQuery')
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery
# XML: 2 combos -- KQ (OLN), KQ (Name+Sex+DOB)
#   Duplicate keyRef KQ -> invented KQN (OLN), KQ (Name)
#   Has Attention and PurposeCode fields (not in DL)
#   DH-suffix fieldIds isolate from DL field pool (AP #14)
#   Attention: handler-only (CommsysGetLastNameFirstNameInitialRuleHandler), NOT in combo requirements
#   autoSelect=$true, queriesToDeselect=DriverLicenseQuery
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30; sourceField = @('nameFirstDH','nameLastDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ: Name path -- 4 set[], most specific. DH-suffix fieldIds.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
        # KQN: OLN path -- 1 set[]. DH-suffix fieldId.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ (Name), KQN (OLN). DH-suffix fields. Attention handler-only.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverLicenseQuery')
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery
# XML: 1 combo (QG). GunMake maxLength=10 (not 23 like NJ). GunSerialNumber=20.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('gunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 10; sourceField = @('gunMake');                   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                  size = 20; sourceField = @('gunModel');                  targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('gunSerialNumber');           targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # Caliber/Make/Model/RSH optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @() }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. GunMake maxLength=10 (HI-specific).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML: 1 combo (QA). Same structure as NJ but with RelatedSearchHitIndicator.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('articleSerialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('articleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # RSH optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML: BQ (Choice[Hull/Reg], any=[State]) + QB (Choice(max2)[Reg/Hull], any=[RelatedSearchHitIndicator])
# Merged into 2 combos: one per primary field, both optional fields in any[]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('boatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('registrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ: Boat Registration. RSH/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        # QB: Stolen Boat. RSH/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Reg), QB (Stolen/Hull). Merged from XML Choice elements.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $vehStolenQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for HI_HCJDC_OFML v${Version}"
    name           = 'HI_HCJDC_OFML'
    type           = 'BUNDLE'
    provider       = 'HI_HCJDC_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# =====================================================================

# Vehicle -- 1 card (Phase 1)
# Serves VehicleRegistrationQuery (M55L/M55S/RQ/QV) -- all 6 combos
# VehicleTypeCode: 1=Auto, 2=Motorcycle, 3=Truck, 5=Trailer, 6=Moped (in-state only)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'licensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'vehicleTypeCode_Input';      node = Inp 'vehicleTypeCode' 'Type Code' '1' 'ROW_VEH_1' @{ initialValue = '1' } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_4' }
                @{ id = 'imageIndicator_Input';  node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehReg (M55L/M55S/RQ/QV) + VehStolen (QV.P/QV.V) on single card.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 1 card
# Serves BOTH DriverLicenseQuery (DQN/DQ/QW) and DriverHistoryQuery (KQN/KQ)
# DL/DH share fields. DH adds Attention + PurposeCode.
# autoSelect on DL, queriesToDeselect bidirectional.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('8','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameFirst_Input';  node = Inp 'nameFirst'  'First Name'  '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';   node = Inp 'nameLast'   'Last Name'   '30' 'ROW_PER_2' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_2' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (Driver History)' '20' 'ROW_PER_4' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_4' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_5'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'nameFirstDH_Input';  node = Inp 'nameFirstDH'  'First Name (DH)'  '30' 'ROW_PER_5' }
                @{ id = 'nameLastDH_Input';   node = Inp 'nameLastDH'   'Last Name (DH)'   '30' 'ROW_PER_5' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'Middle Name (DH)' '30' 'ROW_PER_5' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix (DH)'      '30' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'Date of Birth (DH)' 'ROW_PER_6' }
                @{ id = 'sexCodeDH_Input';   node = Sel 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_6' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DQ/QW/DQN) and DH (KQ/KQN) on single card. DH-suffix fields + queriesToDeselect.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card (QG)
# GunMake maxLength=10 (HI-specific, not 23 like NJ)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'gunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';         node = Sel 'gunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'gunCaliber_Input';                node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunModel_Input';                  node = Inp 'gunModel' 'Model' '20' 'ROW_GUN_2' }
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- 1 card (QA)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'articleSerialNumber_Input';       node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';           node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6'); fields = @(
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- 1 card
# BoatQuery: BQ (Reg) + BQN (Hull). State + RelatedSearchHitIndicator optional.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'registrationNumber_Input';        node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'registrationState_Input';         node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'boatHullIdNumber_Input';          node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (Reg) and BQN (Hull).'
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
    description    = 'Entity form configurations'
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
# BUNDLE 3: RMS (from HIDLE, with HI patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add registrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'registrationState'

# Patch 3: add registrationState to RMS Person QIDM
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name          = 'registrationState'
    sourceField   = @('registrationState')
    targetField   = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'registrationState'
}

# Patch 6: RMS CLEANUP -- remove unused HIDLE fields
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehQidm.attributes = @($rmsVehQidm.attributes | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object {
    $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName')
})
foreach ($combo in $rmsVehQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# Patch 7: RMS autoSelect=true on all RMS QIDMs
foreach ($rmsCfg in $rmsBundle.configurations) {
    if ($rmsCfg.type -eq 'QUERYINPUTDATAMAPPING') { $rmsCfg | Add-Member -NotePropertyName autoSelect -NotePropertyValue $true -Force }
}

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
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

$OUTREADABLE = "$DIR\HI_HCJDC_OFML_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built HI_HCJDC_OFML_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE (use NJ validator adapted for HI)
# =====================================================================
$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host ""
    Write-Host "Running structural validation..." -ForegroundColor Cyan
    powershell.exe -ExecutionPolicy Bypass -File $VALIDATOR -Path $OUT
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

# -- Git commit --
Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."