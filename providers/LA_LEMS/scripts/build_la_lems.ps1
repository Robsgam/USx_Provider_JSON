# build_LA_LEMS.ps1  -- LA_LEMS v2.1 BASE
# Builds LA_LEMS_BASE.json from source\LA_LEMS.xml + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_LA_LEMS.ps1
#
# INPUTS:
#   source\LA_LEMS.xml      -- XML metadata (System LEMS v18) [AUTHORITATIVE]
#   source\LA_LEMS_OFML.pdf -- CommSys devdoc [CROSS-CHECK]
#   source\HIDLE.json       -- RMS structural template
#
# SCOPE: Basic Queries (6 transactions from XML metadata):
#   VehicleRegistrationQuery, DriverLicenseQuery, DriverHistoryQuery,
#   GunQuery, ArticleSingleQuery, BoatQuery
#
# XML METADATA NOTES:
#   Provider internal name: LA_LEMS (System LEMS v18, 84 transactions, 87 message keys)
#   VehicleRegistrationQuery: 2 combos keyRef=RQS (duplicate -> invented keyRefs)
#     State in SET for both combos (LA requires state for vehicle queries)
#     No VehicleMakeCode/VehicleYear in vehicle metadata
#   DriverLicenseQuery: 5 metadata combos -- DP, QWDN, QWA, DQ(Name), DQ(OLN)
#     ImageIndicator in set[] for DP (routing toggle: photo vs no-photo)
#     RaceCode in set[] for QWDN (LA-specific, unlike most states)
#     DQ Name UNREACHABLE (same set as QWA, later in metadata order) -- dropped
#     4 combos implemented: DP, DQ, QWDN, QWA
#   DriverHistoryQuery: 2 combos keyRef=KQ (duplicate -> invented keyRefs)
#     PurposeCode in set[] for both combos (per metadata)
#   GunQuery: 1 combo (QG). GunMake maxLen=3 (LA-specific). GunTypeCode(3) added.
#   ArticleSingleQuery: 1 combo. ArticleTypeCode in any[] (not set[], per metadata).
#   BoatQuery: 2 combos BQ (Nlets registration) + QB (NCIC stolen).
#     RegistrationNumber maxLength=8. State routing on BQ (set[] for Nlets).
#
# ATTENTION PATTERN (AP #27 compliant):
#   ALL 6 QIDMs use CommsysGetLastNameFirstNameInitialRuleHandler on Attention attribute.
#   No Attention FormInput -- handler reads officer session. Attention NOT in any[] (handler-only).
#
# NAME FORMAT: "Last,First Middle Suffix" (NCIC standard comma separator)
# DATE FORMAT: MMddyyyy
# State2-5 fields: NOT implementable (platform constraint). Excluded.
#
# DUPLICATE keyRef INVENTORY (LIMITATION #21):
#   VehicleRegistrationQuery: RQS x2 -> RQSLicensePlateNumber, RQSVehicleIdentificationNumber
#   DriverHistoryQuery:       KQ x2  -> KQOperatorLicenseNumber, KQName
#   DriverLicenseQuery:       DP, DQ, QWDN, QWA (all distinct)
#   GunQuery:                 QG (no duplicate)
#   ArticleSingleQuery:       QA (no duplicate)
#   BoatQuery:                BQ, QB (distinct)

param(
    [string]$Version = "2.1",
    [string]$Phase   = "base"
)

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\LA_LEMS_BASE.json"
$VEROUT   = "$PHASEDIR\LA_LEMS_v${Version}_${DATE}.json"

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
# BUNDLE 1: LA_LEMS PROVIDER
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');     targetField = 'ORI' }
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
    description                = 'Authentication configuration for LA LETTS OFML'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'LA_LEMS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'LA_LEMS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'LA_LEMS_Results'
$results.description = 'Results mapping for LA LETTS OFML'
$results.provider    = 'LA_LEMS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'LA_LEMS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'LA_LEMS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery -- 2 combos
# XML: 2 combos both keyRef=RQS. State in set[] for both.
# No VehicleMakeCode/VehicleYear in LA vehicle metadata.
# State initialValue='LA' is safe (no separate in-state vs OOS keyRefs).
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 17; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @('LicensePlateTypeCode','LicensePlateYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQSLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQSVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQS (Plate/VIN). State in set[] per metadata. 2 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- 4 combos
# XML: 5 combos -- DP, QWDN, QWA, DQ(Name UNREACHABLE), DQ(OLN)
# DQ Name dropped (identical set[] to QWA, later in order -> unreachable)
# ImageIndicator in DP set[] = photo routing toggle (no default on form)
# RaceCode in QWDN set[] = LA-specific (most states have Race in any[])
# autoSelect=true, NO queriesToDeselect (shared form, LIMITATION #26)
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';       size = 1;  sourceField = @('ImageIndicator');       targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 17; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';              size = 1;  sourceField = @('RaceCode');              targetField = 'RaceCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DP: Photo DL -- fires when OLN + ImageIndicator both present
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','ImageIndicator'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DP'
            state                 = 'In/Out'
        }
        # DQ: DL by OLN (no photo) -- fires when only OLN present, ImageIndicator blank
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator','RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # QWDN: Name+DOB+Race+Sex -- most specific name path (LA requires Race)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst','RaceCode'); any = @('ImageIndicator','RegistrationState','NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWDN'
            state                 = 'In/Out'
        }
        # QWA: Name+DOB+Sex (no Race) -- less specific name path
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('ImageIndicator','RaceCode','RegistrationState','NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DP (photo OLN), DQ (OLN), QWDN (Name+Race), QWA (Name). DQ Name UNREACHABLE dropped. 4 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- 2 combos
# XML: 2 combos both keyRef=KQ -> invented keyRefs
# PurposeCode in set[] per metadata (routing gate with FormSelect default='C')
# Attention: handler-populated on all combos
# autoSelect=false (officer manually selects DH)
# NO queriesToDeselect (shared form, LIMITATION #26)
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',',' ',' ') }
            size = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('PurposeCode');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ OLN: fires when OLN + PurposeCode present (PurposeCode default='C')
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','PurposeCode'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
        # KQ Name: fires when Name+DOB+Sex+PurposeCode present
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst','PurposeCode'); any = @('RegistrationState','NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ (OLN/Name). PurposeCode in set[] per metadata. Attention handler-populated.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $false
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery -- 1 combo
# GunMake maxLen=3 (LA-specific, NOT 23 like TX or 10 like HI)
# GunTypeCode(3) added (was missing from old build per SQVR)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'GunMake';         size = 3;  sourceField = @('GunMake');         targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';     size = 3;  sourceField = @('GunTypeCode');     targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('GunMake','GunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. GunMake maxLength=3 (LA-specific). GunTypeCode added.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- 1 combo
# ArticleTypeCode in any[] per metadata (not set[] like most states)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber'); any = @('ArticleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA. ArticleTypeCode in any[] per metadata.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- 2 combos
# BQ: Nlets registration -- State in set[] (required for Nlets routing)
# QB: NCIC stolen -- State in any[] (optional)
# RegistrationNumber maxLength=8
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size = 30; sourceField = @('Attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ: Nlets registration -- State required for routing
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'Out'
        }
        # QB: NCIC stolen boat -- by Hull ID
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Nlets Reg, State required) + QB (NCIC Stolen Hull). 2 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'LA_LEMS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'LA_LEMS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for LA_LEMS v${Version}"
    name           = 'LA_LEMS'
    type           = 'BUNDLE'
    provider       = 'LA_LEMS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# =====================================================================

# Vehicle -- 1 card
# Serves VehicleRegistrationQuery (RQS Plate/VIN). State required.
# PlateType=PC, PlateYear=2026, State='LA' (safe -- no separate In/Out keyRefs)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('8','4'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'LA' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '17' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery. State required per metadata.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 1 card
# Serves DriverLicenseQuery (DP/DQ/QWDN/QWA) and DriverHistoryQuery (KQ)
# DL/DH share fields (no DH-suffix -- shared field pool, LIMITATION #25)
# No ImageIndicator default (routing toggle for DP vs DQ)
# PurposeCode default='C' (DH routing gate per metadata)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'LA' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
                @{ id = 'RaceCode_Input';  node = Sel 'RaceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_4' }
                @{ id = 'PurposeCode_Input';    node = Sel 'PurposeCode' 'Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE'; initialValue = 'C' } 'ROW_PER_4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DP/DQ/QWDN/QWA) and DH (KQ) on single card. No ImageIndicator default (DP routing).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card (QG)
# GunMake maxLength=3 (LA-specific)
# GunTypeCode added (was missing from old build)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6'); fields = @(
                @{ id = 'GunTypeCode_Input'; node = Sel 'GunTypeCode' 'Firearm Type' @{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG. GunMake maxLen=3, GunTypeCode added.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- 1 card (QA)
# ArticleTypeCode in any[] per metadata (not set[])
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA. ArticleTypeCode optional (any[]).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- 1 card
# BQ (Reg+State) + QB (Hull). State routing.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'LA' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (Nlets Reg) + QB (NCIC Stolen Hull). State routing.'
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
# BUNDLE 3: RMS (from HIDLE, with standard patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add RegistrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# Patch 3: add RegistrationState to RMS Person QIDM
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('RegistrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'RegistrationState'
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

$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'RaceCode' })
}

# Patch 7: RMS autoSelect=true on all RMS QIDMs
foreach ($rmsCfg in $rmsBundle.configurations) {
    if ($rmsCfg.type -eq 'QUERYINPUTDATAMAPPING') { $rmsCfg | Add-Member -NotePropertyName autoSelect -NotePropertyValue $true -Force }
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

# Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)
$json = $json -replace 'LicensePlateNumberIn', 'licensePlateNumber'
$jsonReadable = $jsonReadable -replace 'LicensePlateNumberIn', 'licensePlateNumber'

$OUTREADABLE = "$DIR\LA_LEMS_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built LA_LEMS_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
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

Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."
