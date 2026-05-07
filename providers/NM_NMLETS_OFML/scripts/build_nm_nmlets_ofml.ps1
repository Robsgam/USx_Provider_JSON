# build_nm_nmlets_ofml.ps1  -- NM_NMLETS_OFML v1.x BASE
# Builds NM_NMLETS_OFML_BASE.json from source\NM_NMLETS_OFML.xml (metadata v20) + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nm_nmlets_ofml.ps1 [-Version X.X]
#
# INPUTS:
#   source\NM_NMLETS_OFML.xml   -- XML metadata [AUTHORITATIVE]
#   source\NM_NMLETS_OFML.pdf   -- CommSys devdoc [CROSS-CHECK]
#   source\HIDLE.json            -- RMS structural template
#
# METADATA SUMMARY (NM_NMLETS_OFML -- 6 basic queries, 14 combinations):
#   VehicleRegistrationQuery v6  -- 4 combos: QV plate, RQ plate+type+year, QV VIN, RQ VIN
#   DriverLicenseQuery v5        -- 2 combos: Name+DOB+Sex, OLN
#   DriverHistoryQuery v3        -- 2 combos: KQ Name+DOB+Sex, KQ OLN
#   GunQuery v4                  -- 1 combo: QG serial
#   ArticleSingleQuery v3        -- 1 combo: QA serial+type
#   BoatQuery v4                 -- 4 combos: QB hull, BQ hull+state, QB reg, BQ reg+state
#
# NM-SPECIFIC:
#   No CaRequestPurposeCode
#   ImageIndicator present (DL) -- Y/N
#   Date format: MMddyyyy (8-char BirthDate fields)
#   Composite Name: FormatStringRuleHandler
#   State initialValue=NM is SAFE (all combos In/Out, no in-state vs OOS split)
#   ArticleTypeCode: codeTypeSource='NCIC' (not CA_CLETS)
#   GunModel present in NM metadata (size 11)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- Plate+VIN+State+PlateType+PlateYear+VehMake+VehYear
#   Person   -- OLN+Name+DOB+Sex+State+Race+SSN+ImageIndicator (serves DL+DH)
#   Firearm  -- Serial+Make+Caliber+Model
#   Article  -- Serial+ArticleType
#   Boat     -- Reg#+Hull+State

param(
    [string]$Version = "1.0",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NM_NMLETS_OFML_BASE.json"
$OUTREAD  = "$DIR\NM_NMLETS_OFML_BASE_READABLE.json"
$VEROUT   = "$PHASEDIR\NM_NMLETS_OFML_v${Version}_${DATE}.json"

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

function InpH($fid, $lbl, $maxLen, $parentId, $extra = @{}) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    if ($maxLen) { $p['maxLength'] = $maxLen }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormInput' 'Input' $p $false $true @() $parentId
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
# BUNDLE 1: NM_NMLETS_OFML PROVIDER
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
    description                = 'Authentication configuration for NM NMLETS OFML'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NM_NMLETS_OFML'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NM_NMLETS_OFML'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'NM_NMLETS_OFML_Results'
$results.description = 'Results mapping for NM NMLETS OFML'
$results.provider    = 'NM_NMLETS_OFML'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NM_NMLETS_OFML_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NM_NMLETS_OFML'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# Devdoc: 2 paths -- Plate (LPN+PlateType+PlateYear+[State]) and VIN ([State,VehMake,VehYear])
# Metadata: 4 combos -- QV plate, RQ plate+type+year, QV VIN+Make, RQ VIN+Make+Year
# QV = NCIC query (no state required), RQ = Nlets (requires state+plate type+year)
# State initialValue=NM is safe (no separate in-state vs OOS keyRefs)
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
        # Most specific first: RQ plate (requires State+PlateType+PlateYear)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear'); any = @('registrationState','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # RQ VIN (requires State+VehMake+VehYear)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','vehicleMakeCode','vehicleYear'); any = @('registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # QV VIN (NCIC, less specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','vehicleMakeCode'); any = @('registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        # QV plate (NCIC fallback, least specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('registrationState','licensePlateTypeCode','licensePlateYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- QV (NCIC plate/VIN), RQ (Nlets plate/VIN).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'NM_NMLETS_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'NM_NMLETS_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# Devdoc: 2 combos -- Name+DOB+Sex+[State], OLN+[State]
# Metadata v5: 1 combo (QUERY keyRef, set=[PurposeCode,Attention], any=[State,ImageIndicator])
# Metadata QUERY is a collapsed routing combo -- devdoc is authoritative
# DL+DH co-fire on Person form (standard police workflow)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('imageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DL.OLN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DL.NAME'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- OLN + Name+DOB+Sex. ImageIndicator optional.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery
# Metadata v3: 2 combos (KQ Name+DOB+Sex, KQ OLN)
# DL+DH co-fire on Person form
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('attention'); targetField = 'Attention' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCode'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCode'); targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode'); any = @('attention','operatorLicenseNumber','purposeCode','raceCode','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('attention','purposeCode','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ Name+DOB+Sex, KQ OLN. All via Nlets.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery
# Metadata v4: 1 combo (QG serial, with optional caliber/make/model)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');       targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';          size = 3;  sourceField = @('firearmMake');      targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';         size = 11; sourceField = @('gunModel');         targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';  size = 11; sourceField = @('serialNumber');     targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake','gunModel') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG serial. NCIC firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# Metadata v3: 1 combo (QA serial+type)
# ArticleTypeCode: codeTypeSource='NCIC' (NM is not CA_CLETS)
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
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA serial+type. NCIC article query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# Metadata v4: 4 combos -- QB hull (NCIC), BQ hull+state (Nlets), QB reg (NCIC), BQ reg+state (Nlets)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ hull+state (Nlets, more specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        # BQ reg+state (Nlets, more specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        # QB hull (NCIC fallback)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
        # QB reg (NCIC fallback)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- QB (NCIC hull/reg), BQ (Nlets hull/reg+state).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NM_NMLETS_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NM_NMLETS_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# PROVIDER BUNDLE (6 basic queries only)
# =====================================================================
$nmBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for NM_NMLETS_OFML v${Version}"
    name           = 'NM_NMLETS_OFML'
    type           = 'BUNDLE'
    provider       = 'NM_NMLETS_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# State initialValue=NM -- SAFE (all combos In/Out, no in-state vs OOS split)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery fields.
# =====================================================================
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateNumber_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NM' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = '2026' } }
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
    description  = 'Vehicle queries -- VehicleRegistrationQuery (QV/RQ plate+VIN).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card (Phase 1)
# Serves DL + DH QIDMs only (6 basic queries, no WMPI/CCH)
# Fields: OLN, Name, DOB, Sex, State, Race, SSN, ImageIndicator
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NM' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'raceCode_Input';           node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_4' }
                @{ id = 'socialSecurityNumber_Input'; node = Inp 'socialSecurityNumber' 'SSN' '9' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'imageIndicator_Input'; node = Sel 'imageIndicator' 'Image Indicator' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_5' }
                @{ id = 'purposeCode_Input';    node = Inp 'purposeCode'    'Purpose Code'    '1' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'attention_Input'; node = InpH 'attention' 'Attention' '30' 'ROW_PER_6' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL+DH (2 QIDMs co-fire). Phase 1 single card.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG serial)
# GunModel present in NM metadata (size 11), added to form
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input'; node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunModel_Input';   node = Inp 'gunModel'   'Model'   '11' 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG serial. NCIC firearm query.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleTypeCode: codeTypeSource='NCIC' (not CA_CLETS)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA serial+type. NCIC article query.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# State initialValue=NM -- safe for NM
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'      '20' 'ROW_BOA_1' }
                @{ id = 'registrationState_Input';  node = Sel 'registrationState'  'State' @{ attributeTypeId = 'STATE'; initialValue = 'NM' } 'ROW_BOA_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- QB (NCIC hull/reg), BQ (Nlets hull/reg+state).'
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
    description    = 'Entity form configurations for NM_NMLETS_OFML'
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
# BUNDLE 3: RMS (from HIDLE, with NM patches)
# Patches: 1 (Vehicle plate+state), 3 (Person state), 6 (cleanup), 7 (autoSelect), 8 (camelCase)
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

# Person: remove dead attrs (SSN + OOS) + dead combos (SSN + OOS)
$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

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
    bundles = @($entitiesBundle, $nmBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built NM_NMLETS_OFML_BASE.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

# Run validator
$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
