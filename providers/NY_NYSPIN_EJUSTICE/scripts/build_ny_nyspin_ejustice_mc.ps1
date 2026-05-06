# build_ny_nyspin_ejustice_mc.ps1
# Builds NY_NYSPIN_EJUSTICE_MC.json -- Multi-Card variant (Phase 2).
# QIDMs identical to BASE. Only QIF layouts change.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ny_nyspin_ejustice_mc.ps1 -Version X.X -Phase mc
#
# INPUTS:
#   source\NY_NYSPIN_EJUSTICE.XML     -- XML metadata (field names, sizes, combinations, keyRefs) [AUTHORITATIVE]
#   source\New York (NYSPIN_XML).pdf  -- CommSys devdoc (Basic Queries Supported) [CROSS-CHECK]
#   source\HIDLE.json                 -- RMS structural template (RMS bundle, QUERYRESULTDATAMAPPING)
#
# MC LAYOUT (5 QIFs, multi-card where applicable):
#   Vehicle:  3 cards -- OPTIONS (State) + PLATE SEARCH + VIN SEARCH
#   Person:   3 cards -- OPTIONS (State, Image) + OLN SEARCH + NAME SEARCH
#   Firearm:  1 card  -- unchanged from BASE
#   Article:  1 card  -- unchanged from BASE
#   Boat:     3 cards -- OPTIONS (State) + REGISTRATION + HULL
#
# QIDMs (6, 13 combos -- identical to BASE):
#   VehicleRegistrationQuery             RVIN, RVEH, RCAR
#   DriverLicenseQuery                   DLIC, DLICN
#   DriverHistoryQuery                   DALL, DALH
#   GunQuery                             GINQ
#   ArticleSingleQuery                   AINQ
#   BoatQuery                            BVEH, BVIN, RVEH, RCAR
#
# STATE: NCIC pattern CONFIRMED on NY (no initialValue -- blank default)
#   initialValue='NY' was tested 2026-04-24 and reverted. Setting a default
#   causes OOS combos (RVIN/BVEH/BVIN) to fire instead of in-state combos
#   (RCAR/boat-RVEH/boat-RCAR), changing the documented query type.
#   Decision: keep blank, use card title hint instead. See LIMITATION #30.
# SEX: Full 3-layer NIBRS pattern CONFIRMED
# DL+DH co-fire: CONFIRMED (DGRP removed in BASE)

param(
    [string]$Version = "1.0",
    [string]$Phase   = "mc"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NY_NYSPIN_EJUSTICE_MC.json"
$VEROUT   = "$PHASEDIR\NY_NYSPIN_EJUSTICE_MC_v${Version}_${DATE}.json"

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

function InpH($fid, $lbl, $extra, $parentId) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
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

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
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
        [PSCustomObject]@{ name = 'LicensePlateNumber';        size = 10; sourceField = @('LicensePlateNumber');        targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('VehicleYear');                 targetField = 'VehicleYear' }
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('ImageIndicator','VehicleMakeCode','VehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','RegistrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator') }
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
# autoSelect=true: co-fires with DH on both OLN and Name input
# SexCode: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
# State: codeTypeProvider=NCIC (reverse-lookup attr ID -> 2-letter code)
# Name: 4-field FormatStringRuleHandler -> "LAST, FIRST MIDDLE SUFFIX"
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator','RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DLIC'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @('ImageIndicator','RegistrationState','NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'DLICN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery -- DLIC (OLN), DLICN (Name+DOB+Sex)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery (was 1g)
# XML: DriverHistoryQuery v3
#   DALL (OLN): Choice(set[OLN], set[OLN,PurposeCode,Requestor,State])
#               any[ImageIndicator, NyNyspinTransactionName]
#               -> Flatten: set[OLN], any[ImageIndicator, State]
#   DALL (Name): Choice(set[DOB,Name,Sex], set[DOB,Name,PurposeCode,Requestor,Sex,State])
#                any[ImageIndicator, NyNyspinTransactionName]
#                -> Flatten: set[DOB,NameLast,NameFirst,SexCode], any[Image, State, Middle, Suffix]
# Duplicate DALL keyRef -> invent DALH for Name path (confirmed NY v1.19)
# PurposeCode, Requestor, NyNyspinTransactionName: not needed for basic queries.
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 10; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 35; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator','RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @('ImageIndicator','RegistrationState','NameMiddle','NameSuffix') }
            primaryFieldReference = 'Name'
            keyReference          = 'DALH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery -- DALL (OLN), DALH (Name+DOB+Sex)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
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
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('GunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('GunMake');          targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber');  targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';  size = 1;  sourceField = @('ImageIndicator');   targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('ImageIndicator','GunMake','GunCaliber') }
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
# ImageIndicator: on form. RelatedHitSearchIndicator: not on form (Phase 1).
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown).
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';      size = 1;  sourceField = @('ImageIndicator');      targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator') }
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
# ImageIndicator: on Boat OPTIONS card.
# Order: BVEH > BVIN > RVEH > RCAR (most-specific first)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('ImageIndicator');      targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 10; sourceField = @('RegistrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BVIN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('ImageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicator') }
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
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Boat:     3 cards (OPTIONS + REGISTRATION + HULL)
# Firearm:  1 card (unchanged from BASE)
# Article:  1 card (unchanged from BASE)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState, ImageIndicator)
# live on a separate card to avoid duplicate fieldId across cards (= ISE).
# NCIC state pattern: visible RegistrationState, NO initialValue (blank default -- confirmed NY).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards (MC)
# OPTIONS: RegistrationState (shared by RVIN + RVEH combos)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN + VehicleMake + VehicleYear
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for NY queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_VEH_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
            )}
            @{ id = 'ROW_VEH_PLATE_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_PLATE_2' @{ initialValue = '2026' } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear' 'Vehicle Year' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State) + PLATE SEARCH (RVEH) + VIN SEARCH (RVIN/RCAR)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC)
# OPTIONS: RegistrationState + ImageIndicator (shared by DLIC/DLICN/DALL/DALH)
# OLN SEARCH: OperatorLicenseNumber
# NAME SEARCH: Last + First + Middle + Suffix + DOB + Sex
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for NY queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '35' 'ROW_PER_NAME_1' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '35' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '35' 'ROW_PER_NAME_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '10' 'ROW_PER_NAME_2' }
            )}
            @{ id = 'ROW_PER_NAME_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                                    'ROW_PER_NAME_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Image) + OLN SEARCH (DLIC/DALL) + NAME SEARCH (DLICN/DALH)'
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
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake'         'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','4'); fields = @(
                @{ id = 'GunCaliber_Input';     node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_GUN_2' }
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
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_ART_2' }
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
# Boat -- 3 cards (MC)
# OPTIONS: RegistrationState (shared by BVEH + BVIN)
# REGISTRATION: RegistrationNumber
# HULL: BoatHullIdNumber
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for NY queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image' @{ codeTypeSource = 'NCIC'; codeTypeCategory = 'YES_NO_UNKNOWN'; initialValue = 'N' } 'ROW_BOA_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '10' 'ROW_BOA_REG_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State) + REGISTRATION (BVEH/RVEH) + HULL (BVIN/RCAR)'
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
    description    = 'Entity form configurations -- MC variant (5 QIFs, multi-card)'
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
# BUNDLE 3: RMS (from HIDLE, with NY patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add RegistrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# Patch 3: add registrationState attr to RMS Person QIDM + RegistrationState to all person combo any[]
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name          = 'registrationState'
    sourceField   = @('RegistrationState')
    targetField   = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'RegistrationState'
}

# =====================================================================
# RMS CLEANUP: Remove unused HIDLE fields (no matching form fieldId)
# HIDLE is a universal template. Remove dead weight for this provider:
#   Vehicle: OOS dual-field plate (LicensePlateNumberOut, RegistrationStateOut),
#            Owner search (OwnerFirstName, OwnerLastName)
#   Person:  SSN (socialSecurityNumber),
#            All OOS-suffixed attrs and combos (no OOS fieldIds on form)
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

# Patch 7: RMS autoSelect on both QIDMs
$rmsVehQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
$rmsPersonQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force

# Person: remove dead attrs (SSN + OOS) + dead combos (SSN + OOS)
$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $nyBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100

# Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)
$json = $json -replace 'LicensePlateNumberIn', 'licensePlateNumber'
$jsonReadable = $jsonReadable -replace 'LicensePlateNumberIn', 'licensePlateNumber'

$OUTREADABLE = "$DIR\NY_NYSPIN_EJUSTICE_MC_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built NY_NYSPIN_EJUSTICE_MC.json v${Version}"
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
