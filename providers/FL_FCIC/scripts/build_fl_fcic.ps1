# build_fl_fcic.ps1 -- FL_FCIC BASE
# Builds FL_FCIC_BASE.json from source\FL_FCIC.xml metadata + KB specs.
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_fl_fcic.ps1 -Version 3.0
#
# INPUTS:
#   source\FL_FCIC.xml   -- XML metadata (FCIC v94, 170+ message keys) [AUTHORITATIVE]
#   source\FL_FCIC.pdf   -- CommSys devdoc (6 basic queries) [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
#
# QUERYINPUTDATAMAPPING (CommSys -- 7 QIDMs, 33 combos):
#   VehicleRegistrationQuery   FRQ (plate/VIN/Decal/Title) + RQ (plate+state/VIN+state) = 6 combos
#   VehicleStolenQuery         QV (plate/VIN) = 2 combos
#   DriverLicenseQuery         FDQ (OLN/Name) + DQ (OLN+state/Name+state) = 4 combos, autoSelect=true
#   WantedPersonQuery          REMOVED -- CommSys auto-sends QW
#   DriverHistoryQuery         KQ (OLN/Name) = 2 combos, DH-suffix fields
#   GunQuery                   QG (serial/NCIC/PCN) = 3 combos
#   ArticleSingleQuery         QA (serial/OAN/NCIC/PCN) = 4 combos
#   BoatQuery                  FBQ (hull/reg/decal/title) + QB (CG/NCIC/PCN/hull/reg) + BQ (name/hull/reg) = 12 combos
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- plate + VIN + make + year + decal + title
#   Person   -- single card: DL fields + DH-suffix fields (Phase 1 BASE layout)
#   Firearm  -- serial + make + NCIC# + PCN
#   Article  -- serial + type + OAN + NCIC# + PCN
#   Boat     -- reg + hull + state + decal + title + CG# + NCIC# + PCN + name + DOB
#
# FL-SPECIFIC PATTERNS:
#   Date format: yyyyMMdd (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','yyyyMMdd'])
#   Name format: FormatStringRuleHandler arguments=[','] (Last,First -- no space)
#   Attention:   Visible FormInput (attentionDH) on DH card/section
#   DH-suffix:   OperatorLicenseNumberDH, NameLastDH, etc. (isolates DH from DL fields)
#   State:       No initialValue (LIMITATION #30 -- FL has in-state vs OOS keyRefs)

param(
    [string]$Version = "4.2"
)

$ErrorActionPreference = 'Stop'
$provider = 'FL_FCIC'
$outPath  = "$PSScriptRoot\..\FL_FCIC_BASE.json"

$currentYear = [string](Get-Date).Year
. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: FL_FCIC PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'FL_FCIC'
$results = Build-ProviderQrdm -ProviderName 'FL_FCIC'
$qmf = Build-Qmf -ProviderName 'FL_FCIC'

# =====================================================================
# 8 COMMSYS QIDMs
# =====================================================================

# --- 1. VehicleRegistrationQuery (FRQ + RQ) -- 6 combos ---
# XML: FRQ (plate/VIN/Decal/TitleLien) + RQ (plate+state/VIN+state)
# FRQ = FCIC-only (no NCIC/Nlets), RQ = with state routing
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DecalNumber';                  size = 10; sourceField = @('decalNumber');                  targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('licensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';         size = 8;  sourceField = @('titleLienInformation');         targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('decalNumber','licensePlateYear'); any = @('imageIndicator') }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FRQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('licensePlateYear','vehicleMakeCode','vehicleYear','imageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'FRQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear','imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'FRQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('titleLienInformation'); any = @('imageIndicator') }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FRQTitleLienInformation'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQ (plate+state, VIN+state), FRQ (plate, VIN, Decal, Title). 6 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_VehicleRegistrationQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# --- 2. VehicleStolenQuery (QV) -- 2 combos ---
# XML: QV by plate, QV by VIN (NCIC stolen vehicle check)
$vehStolenQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('licensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator','registrationState','vehicleMakeCode') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('imageIndicator','registrationState','vehicleMakeCode') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleStolenQuery -- QV by plate, QV by VIN. NCIC stolen vehicle check.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_VehicleStolenQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'VehicleStolenQuery'
    queryLabel      = 'Vehicle Stolen'
    targetEntity    = 'Vehicle'
}

# --- 3. DriverLicenseQuery (FDQ + DQ) -- 4 combos, autoSelect ---
# XML: FDQ by OLN, FDQ by Name+DOB+Sex (FCIC), DQ by OLN+State, DQ by Name+DOB+Sex+State (NCIC/Nlets)
# Priority: OLN combos before Name combos (operational priority)
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 80; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','sexCode','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','sexCode'); any = @('imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'FDQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'FDQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (OLN+state, Name+state), FDQ (OLN, Name). autoSelect=true.'
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

# --- 4. WantedPersonQuery (QW) -- REMOVED ---
# CommSys auto-sends QW; no QIDM needed in JSON.

# --- 5. DriverHistoryQuery (KQ) -- 2 combos, DH-suffix fields ---
# XML: KQ by OLN+State+Purpose, KQ by Name+DOB+Sex+State+Purpose
# DH-suffix fields isolate from DL field pool (AP #14)
# Attention: visible FormInput (attentionDH), in any[] on both combos
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attentionDH'); targetField = 'Attention' }
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDateDH','nameLastDH','nameFirstDH','sexCodeDH','registrationStateDH'); any = @('purposeCodeDH','attentionDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH','registrationStateDH'); any = @('purposeCodeDH','attentionDH') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ by OLN, KQ by Name. DH-suffix fields. Attention visible.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverHistoryQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# --- 6. GunQuery (QG) -- 3 combos ---
# XML: QG by serial, QG by NCIC#, QG by PCN
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunMake';               size = 23; sourceField = @('gunMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';       size = 11; sourceField = @('gunSerialNumber');       targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('ncicNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('processControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('gunSerialNumber'); any = @('gunMake','imageIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGGunSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('gunMake','imageIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QGNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('gunMake','imageIndicator') }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QGProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG by serial, NCIC#, PCN.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# --- 7. ArticleSingleQuery (QA) -- 4 combos ---
# XML: QA by serial+type, QA by OAN+type, QA by NCIC#, QA by PCN
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';   size = 20; sourceField = @('articleSerialNumber');   targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';       size = 7;  sourceField = @('articleTypeCode');       targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('ncicNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('processControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleSerialNumber','articleTypeCode'); any = @('imageIndicator') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QAArticleSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleTypeCode','ownerAppliedNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QAOwnerAppliedNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QANCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QAProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA by serial+type, OAN+type, NCIC#, PCN.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# --- 8. BoatQuery (FBQ + QB + BQ) -- 12 combos ---
# XML: FBQ (hull/reg/decal/title), QB (CG/NCIC/PCN/hull/reg), BQ (name+DOB/hull+state/reg+state)
# RelatedHitSearchIndicator routes QB+Hull/QB+Reg vs FBQ: officer types Y to get NCIC stolen
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 62; sourceField = @('boatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CoastGuardDocumentNumber';  size = 8;  sourceField = @('coastGuardDocumentNumber');  targetField = 'CoastGuardDocumentNumber' }
        [PSCustomObject]@{ name = 'DecalNumber';               size = 10; sourceField = @('decalNumber');               targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 60; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('ncicNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';      size = 10; sourceField = @('processControlNumber');      targetField = 'ProcessControlNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('registrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';      size = 8;  sourceField = @('titleLienInformation');      targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        # BQ combos (state-routed Nlets OOS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','registrationState'); any = @('boatHullIdNumber','registrationNumber','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'BQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber','registrationState'); any = @('registrationNumber','imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber','registrationState'); any = @('boatHullIdNumber','imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQRegistrationNumber'
            state                 = 'In/Out'
        }
        # QB+Hull/QB+Reg (NCIC stolen -- RelatedHitSearchIndicator in set[] routes here)
        # MUST be before FBQ+Hull/FBQ+Reg: more-specific set[] fires first when flag is filled
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber','relatedHitSearchIndicator'); any = @('imageIndicator','registrationNumber') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber','relatedHitSearchIndicator'); any = @('imageIndicator','boatHullIdNumber') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QBRegistrationNumber'
            state                 = 'In/Out'
        }
        # FBQ combos (FCIC registration -- no RelatedHitSearchIndicator, fires when flag is blank)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('decalNumber','registrationNumber','titleLienInformation','imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'FBQBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','decalNumber','titleLienInformation','imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'FBQRegistrationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('decalNumber'); any = @('boatHullIdNumber','registrationNumber','titleLienInformation','imageIndicator') }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FBQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('titleLienInformation'); any = @('boatHullIdNumber','decalNumber','registrationNumber','imageIndicator') }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FBQTitleLienInformation'
            state                 = 'In/Out'
        }
        # QB combos with unique set[] fields (already reachable, no routing issue)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('coastGuardDocumentNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'CoastGuardDocumentNumber'
            keyReference          = 'QBCoastGuardDocumentNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QBNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('imageIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QBProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (name/hull/reg+state), FBQ (hull/reg/decal/title), QB (CG/hull/reg/NCIC/PCN). 12 combos. RelatedHitSearchIndicator routes QB+Hull/QB+Reg vs FBQ.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$providerBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $vehStolenQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for $provider v$Version"
    name           = $provider
    type           = 'BUNDLE'
    provider       = $provider
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QUERYINPUTFORM)
# =====================================================================

# --- Vehicle (serves VehicleRegistrationQuery + VehicleStolenQuery) ---
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'licensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'imageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
                @{ id = 'vehicleYear_Input';           node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
                @{ id = 'vehicleMakeCode_Input';              node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'decalNumber_Input';          node = Inp 'decalNumber' 'Decal Number' '10' 'ROW_VEH_4' }
                @{ id = 'titleLienInformation_Input'; node = Inp 'titleLienInformation' 'Title/Lien Info' '8' 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleReg (RQ/FRQ) + VehicleStolen (QV) on single card.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# --- Person (single card, Phase 1 BASE -- all DL + DH-suffix fields) ---
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'OLN' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'imageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix' '10' 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','3','3'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_PER_4' }
                @{ id = 'registrationStateDH_Input';     node = Sel 'registrationStateDH' 'State (DH)' @{ attributeTypeId = 'STATE'; initialValue = 'FL' } 'ROW_PER_4' }
                @{ id = 'purposeCodeDH_Input';            node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'nameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_5' }
                @{ id = 'nameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_6' }
                @{ id = 'sexCodeDH_Input';   node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('12'); fields = @(
                @{ id = 'attentionDH_Input'; node = Inp 'attentionDH' 'Attention (DH)' '30' 'ROW_PER_7' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DQ/FDQ) + DH (KQ) on single card. DH-suffix fields. QW auto-sent by CommSys.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# --- Firearm ---
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'gunSerialNumber_Input'; node = Inp 'gunSerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';         node = Sel 'gunMake' 'Gun Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'ncicNumber_Input';         node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'processControlNumber_Input'; node = Inp 'processControlNumber' 'PCN' '10' 'ROW_GUN_2' }
                @{ id = 'imageIndicator_Input';      node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG by serial, NCIC#, PCN.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# --- Article ---
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'articleSerialNumber_Input'; node = Inp 'articleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ownerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_2' }
                @{ id = 'imageIndicator_Input';     node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
            )}
            @{ id = 'ROW_ART_3'; cols = @('6','6'); fields = @(
                @{ id = 'ncicNumber_Input';          node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_ART_3' }
                @{ id = 'processControlNumber_Input'; node = Inp 'processControlNumber' 'PCN' '10' 'ROW_ART_3' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA by serial+type, OAN+type, NCIC#, PCN.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# --- Boat (includes Name/DOB fields for BQ combos) ---
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber' 'Hull ID Number' '62' 'ROW_BOA_1' }
                @{ id = 'registrationState_Input';  node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'decalNumber_Input';              node = Inp 'decalNumber' 'Decal Number' '10' 'ROW_BOA_2' }
                @{ id = 'titleLienInformation_Input';     node = Inp 'titleLienInformation' 'Title/Lien Info' '8' 'ROW_BOA_2' }
                @{ id = 'coastGuardDocumentNumber_Input'; node = Inp 'coastGuardDocumentNumber' 'Coast Guard Doc #' '8' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'ncicNumber_Input';               node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_BOA_3' }
                @{ id = 'processControlNumber_Input';      node = Inp 'processControlNumber' 'PCN' '10' 'ROW_BOA_3' }
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_3' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Stolen Search (Y)' '1' 'ROW_BOA_3' }
            )}
            @{ id = 'ROW_BOA_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name (BQ)' '30' 'ROW_BOA_4' }
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name (BQ)' '30' 'ROW_BOA_4' }
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'DOB (BQ)' 'ROW_BOA_4' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (name/hull/reg+state), FBQ (hull/reg/decal/title), QB (CG/NCIC/PCN/hull/reg). Stolen Search=Y routes hull/reg to QB.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($personForm, $vehicleForm, $firearmsForm, $articleForm, $boatForm) `
    -DefaultOrder @('Person','Vehicle','Firearm','Article','Boat')

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# =====================================================================
$rmsBundle = Build-RmsBundle
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

Write-ProviderJson -BundleObject $output -OutPath $outPath `
    -Label "Built FL_FCIC v${Version}"