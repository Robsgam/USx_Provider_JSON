# build_fl_fcic_mc.ps1 -- FL_FCIC MC (multi-card)
# Builds FL_FCIC_MC.json from source\FL_FCIC.xml metadata + HIDLE.json.
# QIDMs identical to BASE. Layout-only changes: Person has 3 cards (Options, DL, DH).
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_fl_fcic_mc.ps1 -Version 3.0-mc
#
# INPUTS:
#   source\FL_FCIC.xml   -- XML metadata (FCIC v94, 170+ message keys) [AUTHORITATIVE]
#   source\FL_FCIC.pdf   -- CommSys devdoc (6 basic queries) [CROSS-CHECK]
#   source\HIDLE.json    -- RMS structural template
#
# QUERYINPUTDATAMAPPING (CommSys -- 8 QIDMs, 33 combos):
#   VehicleRegistrationQuery   FRQ (plate/VIN/Decal/Title) + RQ (plate+state/VIN+state) = 6 combos
#   VehicleStolenQuery         QV (plate/VIN) = 2 combos
#   DriverLicenseQuery         FDQ (OLN/Name) + DQ (OLN+state/Name+state) = 4 combos, autoSelect=true
#   WantedPersonQuery          QW (OLN/Name) = 2 combos
#   DriverHistoryQuery         KQ (OLN/Name) = 2 combos, DH-suffix fields
#   GunQuery                   QG (serial/NCIC/PCN) = 3 combos
#   ArticleSingleQuery         QA (serial/OAN/NCIC/PCN) = 4 combos
#   BoatQuery                  FBQ (hull/reg/decal/title) + QB (CG/NCIC/PCN/hull/reg) + BQ (name/hull/reg) = 12 combos
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- plate + VIN + make + year + decal + title
#   Person   -- DL card (OLN/Name/DOB/Sex) + DH card (OLN/Name/DOB/Sex, DH-suffix)
#   Firearm  -- serial + make + NCIC# + PCN
#   Article  -- serial + type + OAN + NCIC# + PCN
#   Boat     -- reg + hull + state + decal + title + CG# + NCIC# + PCN + name + DOB
#
# FL-SPECIFIC PATTERNS:
#   Date format: yyyyMMdd (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','yyyyMMdd'])
#   Name format: FormatStringRuleHandler arguments=[','] (Last,First -- no space)
#   Attention:   CommsysGetLastNameFirstNameInitialRuleHandler (handler-only, no form field)
#   DH-suffix:   OperatorLicenseNumberDH, NameLastDH, etc. (isolates DH from DL fields)
#   State:       No initialValue (LIMITATION #30 -- FL has in-state vs OOS keyRefs)

param(
    [string]$Version = "3.5",
    [string]$HidlePath = "$PSScriptRoot\..\source\HIDLE.json"
)

$ErrorActionPreference = 'Stop'
$provider = 'FL_FCIC'
$outPath  = "$PSScriptRoot\..\FL_FCIC_MC.json"

$currentYear = [string](Get-Date).Year
$hidle = Get-Content $HidlePath -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS (NJ pattern: PSCustomObject + @() arrays + deep-copy layouts)
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
            $l[$rowDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rowDef.cols } $true $false $fieldIds $cardDef.id
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
# BUNDLE 1: FL_FCIC PROVIDER
# =====================================================================

# --- AUTHENTICATION ---
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
    description                = "Authentication configuration for $provider"
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = $provider
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = $provider
    providerType               = 'Commsys'
    signInRequired             = $false
}

# --- QUERYRESULTDATAMAPPING (clone from HIDLE) ---
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = "${provider}_Results"
$results.description = "Results mapping for $provider"
$results.provider    = $provider

# --- QUERYMESSAGEFORMAT ---
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = "${provider}_QueryMessageFormat"
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = $provider
}

# =====================================================================
# 8 COMMSYS QIDMs
# =====================================================================

# --- 1. VehicleRegistrationQuery (FRQ + RQ) -- 6 combos ---
# XML: FRQ (plate/VIN/Decal/TitleLien) + RQ (plate+state/VIN+state)
# FRQ = FCIC-only (no NCIC/Nlets), RQ = with state routing
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DecalNumber';                  size = 10; sourceField = @('DecalNumber');                  targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';         size = 8;  sourceField = @('TitleLienInformation');         targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('VehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('VehicleMakeCode','VehicleYear','ImageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('DecalNumber','LicensePlateYear'); any = @('ImageIndicator') }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FRQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('LicensePlateYear','ImageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'FRQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'FRQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('TitleLienInformation'); any = @('ImageIndicator') }
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
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('ImageIndicator','RegistrationState','VehicleMakeCode') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator','VehicleMakeCode') }
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
            name = 'BirthDate'; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 80; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @('ImageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'FDQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator') }
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

# --- 4. WantedPersonQuery (QW) -- 2 combos ---
# XML: QW by OLN+Name, QW by Name+DOB (NCIC wanted person check)
$wpQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NameLast','NameFirst','OperatorLicenseNumber'); any = @('ImageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'QWOperatorLicenseNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('OperatorLicenseNumber','ImageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWName'
            state                 = 'In/Out'
        }
    )
    description     = 'WantedPersonQuery -- QW by OLN+Name, QW by Name+DOB. NCIC wanted person.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_WantedPersonQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'WantedPersonQuery'
    queryLabel      = 'Wanted Person'
    targetEntity    = 'Person'
}

# --- 5. DriverHistoryQuery (KQ) -- 2 combos, DH-suffix fields ---
# XML: KQ by OLN+State+Purpose, KQ by Name+DOB+Sex+State+Purpose
# DH-suffix fields isolate from DL field pool (AP #14)
# Attention: handler-only (CommsysGetLastNameFirstNameInitialRuleHandler), NOT in combo requirements
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        }
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('PurposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH','RegistrationState','PurposeCodeDH'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH','RegistrationState','PurposeCodeDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ by OLN, KQ by Name. DH-suffix fields. Attention handler-only.'
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
        [PSCustomObject]@{ name = 'GunMake';               size = 23; sourceField = @('GunMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';       size = 11; sourceField = @('GunSerialNumber');       targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('NCICNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('ProcessControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('GunMake','ImageIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGGunSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('GunMake','ImageIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QGNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ProcessControlNumber'); any = @('GunMake','ImageIndicator') }
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
        [PSCustomObject]@{ name = 'ArticleSerialNumber';   size = 20; sourceField = @('ArticleSerialNumber');   targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';       size = 7;  sourceField = @('ArticleTypeCode');       targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('NCICNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('OwnerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('ProcessControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QAArticleSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleTypeCode','OwnerAppliedNumber'); any = @('ImageIndicator') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QAOwnerAppliedNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QANCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ProcessControlNumber'); any = @('ImageIndicator') }
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
            name = 'BirthDate'; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 62; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CoastGuardDocumentNumber';  size = 8;  sourceField = @('CoastGuardDocumentNumber');  targetField = 'CoastGuardDocumentNumber' }
        [PSCustomObject]@{ name = 'DecalNumber';               size = 20; sourceField = @('DecalNumber');               targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 60; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('NCICNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';      size = 10; sourceField = @('ProcessControlNumber');      targetField = 'ProcessControlNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';      size = 10; sourceField = @('TitleLienInformation');      targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        # BQ combos (state-routed Nlets OOS)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','RegistrationState'); any = @('BoatHullIdNumber','RegistrationNumber','ImageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'BQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber','RegistrationState'); any = @('RegistrationNumber','ImageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber','RegistrationState'); any = @('BoatHullIdNumber','ImageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQRegistrationNumber'
            state                 = 'In/Out'
        }
        # QB+Hull/QB+Reg (NCIC stolen -- RelatedHitSearchIndicator in set[] routes here)
        # MUST be before FBQ+Hull/FBQ+Reg: more-specific set[] fires first when flag is filled
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber','RelatedHitSearchIndicator'); any = @('ImageIndicator','RegistrationNumber') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber','RelatedHitSearchIndicator'); any = @('ImageIndicator','BoatHullIdNumber') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QBRegistrationNumber'
            state                 = 'In/Out'
        }
        # FBQ combos (FCIC registration -- no RelatedHitSearchIndicator, fires when flag is blank)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('DecalNumber','RegistrationNumber','TitleLienInformation','ImageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'FBQBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('BoatHullIdNumber','DecalNumber','TitleLienInformation','ImageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'FBQRegistrationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('DecalNumber'); any = @('BoatHullIdNumber','RegistrationNumber','TitleLienInformation','ImageIndicator') }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FBQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('TitleLienInformation'); any = @('BoatHullIdNumber','DecalNumber','RegistrationNumber','ImageIndicator') }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FBQTitleLienInformation'
            state                 = 'In/Out'
        }
        # QB combos with unique set[] fields (already reachable, no routing issue)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('CoastGuardDocumentNumber'); any = @('ImageIndicator','RelatedHitSearchIndicator') }
            primaryFieldReference = 'CoastGuardDocumentNumber'
            keyReference          = 'QBCoastGuardDocumentNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator','RelatedHitSearchIndicator') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QBNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ProcessControlNumber'); any = @('ImageIndicator','RelatedHitSearchIndicator') }
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
    configurations = @($auth, $results, $qmf, $vehRegQuery, $vehStolenQuery, $dlQuery, $wpQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
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
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
                @{ id = 'VehicleYear_Input';           node = Inp 'VehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
                @{ id = 'VehicleMakeCode_Input';              node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'DecalNumber_Input';          node = Inp 'DecalNumber' 'Decal Number' '10' 'ROW_VEH_4' }
                @{ id = 'TitleLienInformation_Input'; node = Inp 'TitleLienInformation' 'Title/Lien Info' '8' 'ROW_VEH_4' }
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

# --- Person (DL card + DH card, DH-suffix fields) ---
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_OPTIONS'
        title = 'Search Options'
        rows  = @(
            @{ id = 'ROW_OPT'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_OPT' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_OPT' }
            )}
        )
    }
    @{
        id    = 'CARD_DL'
        title = 'Driver License'
        rows  = @(
            @{ id = 'ROW_DL1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_DL1' }
            )}
            @{ id = 'ROW_DL2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_DL2' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_DL2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_DL2' }
            )}
            @{ id = 'ROW_DL3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_DL3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DL3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix' '10' 'ROW_DL3' }
            )}
        )
    }
    @{
        id    = 'CARD_DH'
        title = 'Driver History'
        rows  = @(
            @{ id = 'ROW_DH1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN (DH)' '20' 'ROW_DH1' }
                @{ id = 'PurposeCodeDH_Input';            node = Inp 'PurposeCodeDH' 'Purpose Code' '1' 'ROW_DH1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_DH2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_DH2' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '30' 'ROW_DH2' }
            )}
            @{ id = 'ROW_DH3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'DOB (DH)' 'ROW_DH3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DH3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DQ/FDQ/QW) + DH (KQ) on separate cards. DH-suffix fields.'
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
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake' 'Gun Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';         node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'ProcessControlNumber_Input'; node = Inp 'ProcessControlNumber' 'PCN' '10' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';      node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
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
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'OwnerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_2' }
                @{ id = 'ImageIndicator_Input';     node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
            )}
            @{ id = 'ROW_ART_3'; cols = @('6','6'); fields = @(
                @{ id = 'NCICNumber_Input';          node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_ART_3' }
                @{ id = 'ProcessControlNumber_Input'; node = Inp 'ProcessControlNumber' 'PCN' '10' 'ROW_ART_3' }
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
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '62' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'DecalNumber_Input';              node = Inp 'DecalNumber' 'Decal Number' '20' 'ROW_BOA_2' }
                @{ id = 'TitleLienInformation_Input';     node = Inp 'TitleLienInformation' 'Title/Lien Info' '10' 'ROW_BOA_2' }
                @{ id = 'CoastGuardDocumentNumber_Input'; node = Inp 'CoastGuardDocumentNumber' 'Coast Guard Doc #' '8' 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NCICNumber_Input';               node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_BOA_3' }
                @{ id = 'ProcessControlNumber_Input';      node = Inp 'ProcessControlNumber' 'PCN' '10' 'ROW_BOA_3' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_3' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'RelatedHitSearchIndicator' 'Stolen Search (Y)' '1' 'ROW_BOA_3' }
            )}
            @{ id = 'ROW_BOA_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name (BQ)' '30' 'ROW_BOA_4' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name (BQ)' '30' 'ROW_BOA_4' }
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'DOB (BQ)' 'ROW_BOA_4' }
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

$entitiesBundle = [PSCustomObject]@{
    configurations = @($personForm, $vehicleForm, $firearmsForm, $articleForm, $boatForm)
    description    = "Query forms for $provider v$Version"
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Person','Vehicle','Firearm','Article','Boat')
        CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
        FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE + Patches 1, 3, 6, 7)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm    = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }

# Patch 1: add RegistrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# Patch 3: add registrationState attr to RMS Person QIDM
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('RegistrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'RegistrationState'
}

# Patch 6: remove dead HIDLE fields (OOS + Owner + SSN)
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehQidm.attributes   = @($rmsVehQidm.attributes   | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object { $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName') })
foreach ($combo in $rmsVehQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
$rmsPersonQidm.attributes   = @($rmsPersonQidm.attributes   | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# Patch 7: RMS Vehicle autoSelect=true
$rmsVehQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
# RMS Person already has autoSelect from HIDLE
$rmsPersonQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force

# =====================================================================
# FINAL ASSEMBLY + WRITE
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

# Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)
$json = $json -replace 'LicensePlateNumberIn', 'licensePlateNumber'
$jsonReadable = $jsonReadable -replace 'LicensePlateNumberIn', 'licensePlateNumber'

$outPathReadable = "$PSScriptRoot\..\FL_FCIC_MC_READABLE.json"
[System.IO.File]::WriteAllText($outPath,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($outPathReadable, $jsonReadable, [System.Text.UTF8Encoding]::new($false))

Write-Host "Built $outPath (v$Version) -- no BOM"
Write-Host "  -> $outPath"
Write-Host "  -> $outPathReadable"
Write-Host "  ENTITIES: 5 QIFs (Person, Vehicle, Firearm, Article, Boat)"
Write-Host "  ${provider}: AUTH + QRDM + QMF + 8 CommSys QIDMs (33 combos)"
Write-Host "  RMS: Patched (1+3+6+7)"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $outPath
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green
