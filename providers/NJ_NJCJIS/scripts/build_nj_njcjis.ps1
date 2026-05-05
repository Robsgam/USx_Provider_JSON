# build_nj_njcjis.ps1  -- NJ_NJCJIS v2.x BASE
# Builds NJ_NJCJIS_BASE.json from source\NJ_NJCJIS.xml (2026-04-28 metadata) + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_njcjis.ps1 -Version X.X -Phase 01_standup
#
# INPUTS:
#   source\NJ_NJCJIS.xml  -- XML metadata (2026-04-28) -- 6 transactions, 10 combos [AUTHORITATIVE]
#   source\NJ_NJCJIS.pdf  -- CommSys devdoc (Basic Queries + WMPI) [CROSS-CHECK, Basic Queries only]
#   source\HIDLE.json     -- RMS structural template
#
# METADATA CHANGES (v2 vs v1):
#   New transaction: VehicleStolenQuery (3 combos: NCICNumber, Plate, VIN)
#   New fields: RandomRequest (mandatory on VehicleReg), GunModel, ImageIndicator (all transactions)
#   Removed: State from BoatQuery
#   Changed: RegistrationNumber maxLength 8->20, State/PlateType to set[] on VehicleReg
#   All keyRefs have duplicates in XML -- invented distinct keyRefs per LIMITATION #21
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 10 combos):
#   VehicleRegistrationQuery   RQ (Plate) + RQN (VIN) -- RandomRequest mandatory in set[]
#   VehicleStolenQuery         QVN (NCIC#) + QVP (Plate) + QVV (VIN) -- new transaction
#   DriverLicenseQuery         DQN (OLN) + DQ (Name)
#   GunQuery                   QG -- adds GunModel + ImageIndicator
#   ArticleSingleQuery         QA -- adds ImageIndicator
#   BoatQuery                  QB (Reg) + QBN (Hull) -- State removed, ImageIndicator added
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- VehicleReg + VehicleStolen fields on single card
#   Person   -- OLN + Name + DOB + Sex + State + ImageIndicator
#   Firearm  -- Serial + Make + Caliber + Model + ImageIndicator
#   Article  -- Serial + TypeCode + ImageIndicator
#   Boat     -- Reg + Hull + ImageIndicator (no State in v2)
#
# DUAL VEHICLE QIDM:
#   VehicleRegistrationQuery and VehicleStolenQuery both target Vehicle entity.
#   Different query values = separate QIDMs, no LIMITATION #2 conflict.
#   Both co-fire when shared fields (Plate, VIN) are populated.
#   RandomRequest in set[] gates VehicleReg: empty RandomRequest = only VehicleStolen fires.
#   Default RandomRequest='N' ensures VehicleReg fires on standard plate/VIN queries.
#
# STATE HANDLING (NCIC pattern, confirmed NJ v1.0):
#   Single visible Sel 'RegistrationState' (attributeTypeId=STATE, initialValue=NJ)
#   CommSys State attr: sourceField=RegistrationState, codeTypeProvider=NCIC
#   RMS: useAttributeId=true + AttributeArrayWrapperRuleHandler (HIDLE default)
#
# SEX HANDLING (confirmed NJ v1.0):
#   Form: Sel 'SexCode' attributeTypeId=SEX + codeTypeProvider=NIBRS
#   CommSys: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
#   RMS: HIDLE default useAttributeId=true, NO AttributeArrayWrapperRuleHandler

param(
    [string]$Version = "2.0",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NJ_NJCJIS_BASE.json"
$VEROUT   = "$PHASEDIR\NJ_NJCJIS_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS
# =====================================================================
function N($type, $display, $props, $isCanvas, $hidden, $nodes, $parent) {
    $nodeList = [System.Collections.Generic.List[string]]::new()
    if ($nodes) { foreach ($n in @($nodes)) { $nodeList.Add([string]$n) } }
    $obj = [ordered]@{
        type        = [PSCustomObject]@{ resolvedName = $type }
        displayName = $display
        props       = [PSCustomObject]$props
        isCanvas    = [bool]$isCanvas
        hidden      = [bool]$hidden
        nodes       = $nodeList
        linkedNodes = [PSCustomObject]@{}
    }
    if ($parent -ne '') { $obj['parent'] = "$parent" }
    [PSCustomObject]$obj
}

function Inp($fid, $lbl, $maxLen, $parentId, $extra = @{}) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    if ($maxLen) { $p['maxLength'] = $maxLen }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormInput' 'Input' $p $false $false @() $parentId
}

function Sel($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $false @() $parentId
}

function SelH($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormSelect' 'Select' $p $false $true @() $parentId
}

function Dt($fid, $lbl, $parentId) {
    N 'FormDate' 'Date' @{ fieldId = $fid; label = $lbl } $false $false @() $parentId
}

function BuildMultiCardLayout($cardDefs) {
    $l = [ordered]@{}
    $cardIds = @($cardDefs | ForEach-Object { $_.id })
    $l['ROOT']      = N 'Root' 'Root' @{} $false $false @('FORM_ROOT') ''
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false $cardIds 'FORM_ROOT'
    foreach ($cardDef in $cardDefs) {
        $rowIds    = @($cardDef.rows | ForEach-Object { $_.id })
        $cardProps = if ($cardDef.title) { @{ title = $cardDef.title } } else { @{} }
        $l[$cardDef.id] = N 'Card' 'Card' $cardProps $true $false $rowIds 'ROOT_PAGE'
        foreach ($rowDef in $cardDef.rows) {
            $fieldIds  = @($rowDef.fields | ForEach-Object { $_.id })
            $rowHidden = if ($rowDef['hidden']) { $true } else { $false }
            $l[$rowDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rowDef.cols } $true $rowHidden $fieldIds $cardDef.id
            foreach ($f in $rowDef.fields) { $l[$f.id] = $f.node }
        }
    }
    return [PSCustomObject]$l
}

function AddCadNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (N 'Card' 'Card' @{} $true $false @('ROW_0') 'ROOT_PAGE') -Force
    $clone | Add-Member -NotePropertyName 'ROW_0'             -NotePropertyValue (N 'Row'  'Row'  @{ templateColumns = @('6','6') } $true $false @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD') -Force
    $clone | Add-Member -NotePropertyName 'CadUnit_Input'     -NotePropertyValue (Sel 'CAD_UNIT_SELECT_VALUE'  'Requesting Unit' @{ attributeTypeId = 'CAD_UNIT_SELECT_VALUE' } 'ROW_0') -Force
    $clone | Add-Member -NotePropertyName 'CadEvent_Input'    -NotePropertyValue (Sel 'CAD_EVENT_SELECT_VALUE' 'Event' @{ attributeTypeId = 'CAD_EVENT_SELECT_VALUE'; performSearchAhead = $true } 'ROW_0') -Force
    return $clone
}

function AddFrNodes($layout) {
    $clone = $layout | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $pageNodes = [System.Collections.Generic.List[string]]($clone.ROOT_PAGE.nodes)
    $pageNodes.Insert(0, 'CONTEXT_INFO_CARD')
    $clone.ROOT_PAGE.nodes = $pageNodes.ToArray()
    $clone | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (N 'Card' 'Card' @{} $true $false @('LinkToEvent_Input') 'ROOT_PAGE') -Force
    $clone | Add-Member -NotePropertyName 'LinkToEvent_Input' -NotePropertyValue (N 'FormCheckbox' 'Checkbox' @{ fieldId = 'LINK_CURRENT_ASSIGNED_EVENT'; label = ' '; checkboxLabel = 'Link to the current assigned event' } $false $false @() 'CONTEXT_INFO_CARD') -Force
    return $clone
}

function MakeLayouts($cardDefs) {
    $def = BuildMultiCardLayout $cardDefs
    $cad = AddCadNodes $def
    $fr  = AddFrNodes $def
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1: NJ_NJCJIS PROVIDER
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
    description                = 'Authentication configuration for NJ NJCJIS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NJ_NJCJIS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NJ_NJCJIS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'NJ_NJCJIS_Results'
$results.description = 'Results mapping for NJ NJCJIS'
$results.provider    = 'NJ_NJCJIS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NJ_NJCJIS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NJ_NJCJIS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML (2026-04-28): VehicleRegistrationQuery v1
#   4 combos in XML (RAND x2, FULL x2) -- identical set[] per primary field.
#   Collapse to 2 effective combos: RQ (plate), RQN (VIN).
#   RandomRequest mandatory in set[] (Y=random check, N=full request).
#   State mandatory in set[] (was any[] in old XML).
#   LicensePlateTypeCode mandatory in set[] for plate combo.
#   ImageIndicator new, in any[].
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'RandomRequest';                size = 1;  sourceField = @('randomRequest');                targetField = 'RandomRequest' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','randomRequest','registrationState','licensePlateTypeCode'); any = @('imageIndicator','licensePlateYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','randomRequest','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQ (plate), RQN (VIN). RandomRequest mandatory.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. VehicleStolenQuery -- NEW TRANSACTION
# XML (2026-04-28): VehicleStolenQuery v1
#   3 combos all keyRef QV in XML -> invented QVN/QVP/QVV (LIMITATION #21)
#   Targets Vehicle entity (same as VehicleReg) -- different query = separate QIDM, no conflict.
#   Co-fires with VehicleReg when shared fields (Plate, VIN) populated.
# =====================================================================
$vehStolenQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('imageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'NCICNumber';                   size = 10; sourceField = @('ncicNumber');                   targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QVN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('imageIndicator','registrationState','vehicleIdentificationNumber','vehicleMakeCode') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('imageIndicator','vehicleMakeCode') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVV'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleStolenQuery -- QVN (NCIC#), QVP (plate), QVV (VIN). New in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_VehicleStolenQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'VehicleStolenQuery'
    queryLabel      = 'Vehicle Stolen'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1f. DriverLicenseQuery
# XML (2026-04-28): DriverLicenseQuery v1
#   2 combos: FULL/FULL in XML -> invented DQ (Name), DQN (OLN)
#   Fields unchanged from v1. ImageIndicator already in v1.
#   any[] order changed (cosmetic): now ImageIndicator, SexCode, State
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('imageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size        = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('imageIndicator','sexCode','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQN (OLN), DQ (Name+DOB). autoSelect routes by field presence.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery
# XML (2026-04-28): GunQuery v1, keyRef QG
#   set[GunSerialNumber], any[GunCaliber, GunMake, GunModel, ImageIndicator]
#   NEW: GunModel (size 20), ImageIndicator (size 1)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');       targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('firearmMake');      targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';        size = 20; sourceField = @('gunModel');         targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('serialNumber');     targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';  size = 1;  sourceField = @('imageIndicator');   targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake','gunModel','imageIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. Adds GunModel + ImageIndicator in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML (2026-04-28): ArticleSingleQuery v1, keyRef QA
#   set[ArticleSerialNumber, ArticleTypeCode], any[ImageIndicator]
#   NEW: ImageIndicator (size 1)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');    targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('articleTypeCode'); targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';      size = 1;  sourceField = @('imageIndicator');  targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber','articleTypeCode'); any = @('imageIndicator') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA. Adds ImageIndicator in v2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML (2026-04-28): BoatQuery v1
#   2 combos: QB/QB in XML -> invented QB (Reg), QBN (Hull)
#   State REMOVED entirely (was in v1 any[])
#   RegistrationNumber maxLength now 20 (was 8)
#   ImageIndicator new, in any[]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('imageIndicator');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 20; sourceField = @('registrationNumber');  targetField = 'RegistrationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBN'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- QB (Reg), QBN (Hull). State removed in v2. RegNum maxLength 20.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $vehStolenQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NJ_NJCJIS v${Version}"
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card (Phase 1)
# Serves BOTH VehicleRegistrationQuery and VehicleStolenQuery.
# VehicleReg fields: Plate, State, PlateType, PlateYear, RandomRequest, VIN, ImageIndicator
# VehicleStolen adds: NCICNumber, VehicleMakeCode
# RandomRequest: Y=random check (NJ A-134-97), N=full request. Default N.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_VEH_1' }
                @{ id = 'randomRequest_Input';        node = Sel 'randomRequest' 'Random' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = '2026' } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'ncicNumber_Input';         node = Inp 'ncicNumber' 'NCIC Number' '10' 'ROW_VEH_4' }
                @{ id = 'vehicleMakeCode_Input';    node = Sel 'vehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6'); fields = @(
                @{ id = 'imageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleReg (RQ/RQN) + VehicleStolen (QVN/QVP/QVV) on single card.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# PERSON SEARCH: OLN + RegistrationState + Image + Name + DOB + Sex
# DQN fires when OLN present. DQ fires when Name+DOB present (autoSelect).
# Unchanged from v1 except ImageIndicator now explicitly in new XML.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('8','2','2'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_PER_1' }
                @{ id = 'imageIndicator_Input';        node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                    'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- OLN (DQN) and Name+DOB (DQ) on single card.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG)
# XML: set[GunSerialNumber], any[GunCaliber, GunMake, GunModel, ImageIndicator]
# NEW in v2: GunModel + ImageIndicator
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';    node = Inp 'serialNumber'  'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';     node = Sel 'firearmMake'   'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'gunCaliber_Input';      node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_2' }
                @{ id = 'gunModel_Input';        node = Inp 'gunModel'   'Model'   '20' 'ROW_GUN_2' }
                @{ id = 'imageIndicator_Input';  node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG. Adds GunModel + ImageIndicator in v2.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA)
# XML: set[ArticleSerialNumber, ArticleTypeCode], any[ImageIndicator]
# NEW in v2: ImageIndicator
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';    node = Inp 'serialNumber'    'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6'); fields = @(
                @{ id = 'imageIndicator_Input'; node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA. Adds ImageIndicator in v2.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# BOAT SEARCH: Reg Number + Hull ID + ImageIndicator
# State REMOVED in v2 metadata. RegistrationNumber maxLength now 20.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number' '20' 'ROW_BOA_1' }
                @{ id = 'imageIndicator_Input';      node = Sel 'imageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                @{ id = 'boatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- QB (Reg) and QBN (Hull). No State in v2.'
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
# BUNDLE 3: RMS (from HIDLE, with NJ patches)
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

# Person: remove dead attrs (SSN + OOS) + dead combos (SSN + OOS)
$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# Patch 7: RMS autoSelect=true (RMS fires alongside CommSys automatically)
$rmsVehQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
$rmsPersonQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force

# Patch 8: CAD field name alignment -- rename HIDLE RMS sourceField + combo refs to camelCase
# HIDLE uses PascalCase fieldIds. CAD sends camelCase. sourceField must match QIF fieldIds.
# Run AFTER all other patches so Patch 1/3/6 filters work on original HIDLE names.
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
    bundles = @($entitiesBundle, $njBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
$OUTREADABLE = "$DIR\NJ_NJCJIS_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built NJ_NJCJIS_BASE.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREADABLE (readable)"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
powershell.exe -ExecutionPolicy Bypass -File "$DIR\scripts\validate_nj_njcjis.ps1" -JsonFile $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green

# =====================================================================
# UPDATE DOCS
# =====================================================================
$STATUS_FILE = "$DIR\docs\NJ_NJCJIS_STATUS.txt"
$NOTES_FILE  = "$DIR\docs\NJ_NJCJIS_BUILD_NOTES.txt"

$statusEntry = @"

  v${Version}  $DATE  build_nj_njcjis.ps1
    Output : $OUT
    Archive: $VEROUT
"@
$statusContent = Get-Content $STATUS_FILE -Raw -Encoding UTF8
$marker = "BUILD LOG  (newest first)"
$idx = $statusContent.IndexOf($marker)
if ($idx -ge 0) {
    $insertAt = $idx + $marker.Length
    $newContent = $statusContent.Substring(0, $insertAt) + $statusEntry + $statusContent.Substring($insertAt)
    Set-Content $STATUS_FILE $newContent -Encoding UTF8
} else {
    Add-Content $STATUS_FILE $statusEntry -Encoding UTF8
}

$notesEntry = @"

v${Version}  $DATE  [describe change here]
  CHANGED
    -
  REASON
    -
"@
$notesContent = Get-Content $NOTES_FILE -Raw -Encoding UTF8
$marker = "VERSION HISTORY  (newest first)"
$idx = $notesContent.IndexOf($marker)
if ($idx -ge 0) {
    $insertAt = $idx + $marker.Length
    $newContent = $notesContent.Substring(0, $insertAt) + $notesEntry + $notesContent.Substring($insertAt)
    Set-Content $NOTES_FILE $newContent -Encoding UTF8
} else {
    Add-Content $NOTES_FILE $notesEntry -Encoding UTF8
}

Write-Host ""
Write-Host "STATUS.txt and BUILD_NOTES.txt updated."

# -- Git commit --
Write-Host ""
Write-Host "Committing to GitHub..."
Push-Location $DIR
git add "NJ_NJCJIS_BASE.json" `
        "phases\$Phase\NJ_NJCJIS_v${Version}_${DATE}.json" `
        "docs\NJ_NJCJIS_STATUS.txt" `
        "docs\NJ_NJCJIS_BUILD_NOTES.txt"
git commit -m "Build v$Version ($Phase $DATE)"
Pop-Location
Write-Host "Committed."
