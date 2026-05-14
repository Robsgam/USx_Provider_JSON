# build_or_leds_mc.ps1  -- OR_LEDS v1.x MC
# MC variant: PascalCase fieldIds, multi-card layout.
# Phase 2 multi-card. No cross-entity combos. No DriverHistoryQuery.
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# OR-SPECIFIC:
#   NO CaRequestPurposeCode     -- Oregon, not California.
#   NO DriverHistoryQuery        -- not in metadata or devdoc.
#   ImageIndicator: in DL metadata (Y/blank field), default Y.
#   Date format: yyyyMMdd (size=8 in metadata).
#   LIMITATION #30: No State initialValue (In vs Out routing).
#   State: NCIC pattern (codeTypeProvider='NCIC').
#   Sex: NIBRS pattern (codeTypeProvider='NIBRS').
#   PlateType: PC, PlateYear: 2026.
#   RelatedHitSearchIndicator: Y-only flag (FormInput maxLength=1).
#
# METADATA SUMMARY (OR_LEDS -- 5 basic queries, 8 combos):
#   ArticleSingleQuery       v4  -- 1 combo: QA (Serial+ArticleType)
#   BoatQuery                v3  -- 2 combos: BQ (Reg), BQ (Hull) -- same keyRef, invented BQ.R/BQ.H
#   DriverLicenseQuery       v3  -- 2 combos: DQ (Name+DOB+Sex), DQ (OLN) -- same keyRef, invented DQ.N/DQ.O
#   GunQuery                 v3  -- 1 combo: QG (Serial)
#   VehicleRegistrationQuery v3  -- 2 combos: RQ (Plate), RQ (VIN) -- same keyRef, invented RQ.P/RQ.V
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_or_leds_mc.ps1

param(
    [string]$Version = '1.3',
    [string]$Phase   = "mc"
)

$ErrorActionPreference = "Stop"

$DATE        = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\OR_LEDS_MC.json"
$OUTREAD  = "$DIR\OR_LEDS_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\OR_LEDS_MC_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

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
# BUNDLE 1: OR_LEDS PROVIDER (PascalCase sourceField / combo refs)
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
            requirements = [PSCustomObject]@{ set = @('ORI','mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for OR LEDS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'OR_LEDS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'OR_LEDS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-CommsysQrdm -ProviderName 'OR_LEDS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'OR_LEDS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'OR_LEDS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase sourceField + combo refs
# Devdoc: In plate, In VIN, Out plate+State, Out VIN+State
# LIMITATION #30: No State initialValue (In vs Out routing)
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
        # OOS plate (most specific -- requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.PO'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.VO'
            state                 = 'In/Out'
        }
        # In-state VIN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state plate (least specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear','registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- RQ (In plate/VIN, Out plate+State/VIN+State). MC PascalCase.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'OR_LEDS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'OR_LEDS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase sourceField + combo refs
# Devdoc: In Name+DOB+[Sex], In OLN, Out Name+DOB+State+[Sex,Img], Out OLN+State+[Img]
# LIMITATION #30: No State initialValue (In vs Out routing)
# ImageIndicator: in metadata (any[])
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
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
        # OOS Name (4 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst','registrationState'); any = @('sexCode','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.NO'
            state                 = 'In/Out'
        }
        # In-state Name (3 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('birthDate','nameLast','nameFirst'); any = @('sexCode','registrationState','imageIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # OOS OLN (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @('imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.OO'
            state                 = 'In/Out'
        }
        # In-state OLN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('registrationState','imageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (In OLN/Name, Out OLN+State/Name+State). ImageIndicator supported. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery -- QG (serial), any[GunMake, GunCaliber] -- PascalCase
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';          size = 23; sourceField = @('gunMake');         targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';  size = 11; sourceField = @('serialNumber');    targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','gunMake') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). NCIC firearm query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery -- QA (Serial+ArticleType) -- PascalCase
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
    description     = 'ArticleSingleQuery -- QA (serial+type). NCIC article query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery -- BQ (Reg), BQ (Hull) -- PascalCase
# State in any[] for both combos
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('boatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('registrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Reg, Hull). NCIC boat query. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OR_LEDS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OR_LEDS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# Provider bundle assembly (5 basic QIDMs only)
# =====================================================================
$providerBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery
    )
    description    = "Provider configuration for OR_LEDS v${Version} MC -- 5 QIDMs (VehReg + DL + Gun + Article + Boat)"
    name           = 'OR_LEDS'
    type           = 'BUNDLE'
    provider       = 'OR_LEDS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  3 cards (OPTIONS + PLATE SEARCH + VIN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH)
# Firearm:  1 card  (single combo -- QG serial)
# Article:  1 card  (single combo -- QA serial+type)
# Boat:     3 cards (OPTIONS + REGISTRATION SEARCH + HULL SEARCH)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState)
# live on a separate card to avoid duplicate fieldId across cards (= ISE).
# NCIC state pattern: visible RegistrationState, NO initialValue
# (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 3 cards (MC)
# OPTIONS: RegistrationState (shared by all combos, LIMITATION #30)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN + VehicleMake + VehicleYear
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for OR queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_PLATE_1'; cols = @('12'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_PLATE_1' }
            )}
            @{ id = 'ROW_VEH_PLATE_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_PLATE_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_PLATE_2' @{ initialValue = $currentYear } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_VIN_1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State) + PLATE (RQ.P/RQ.PO) + VIN (RQ.V/RQ.VO)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC)
# OPTIONS: RegistrationState + ImageIndicator + RelatedHitSearchIndicator
# OLN SEARCH: OperatorLicenseNumber
# NAME SEARCH: First + Last + Middle + Suffix + DOB + Sex + Race
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for OR queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'registrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'imageIndicator'          'Image (Y)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_PER_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '30' 'ROW_PER_NAME_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'      '5'  'ROW_PER_NAME_2' }
            )}
            @{ id = 'ROW_PER_NAME_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_NAME_3' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_3' }
                @{ id = 'RaceCode_Input';  node = Sel 'RaceCode'  'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_NAME_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Image + RelatedHit) + OLN (DQ.O/DQ.OO) + NAME (DQ.N/DQ.NO)'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (single combo QG)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '23' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';      node = Sel 'gunMake'      'Make'           @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- single card (QG serial)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (single combo QA)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '23' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- single card (QA serial+type)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 3 cards (MC)
# OPTIONS: RegistrationState (shared by both combos)
# REGISTRATION SEARCH: RegistrationNumber (BQ.R)
# HULL SEARCH: BoatHullIdNumber (BQ.H)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for OR queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State (leave blank for OR)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_REG_1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8' 'ROW_BOA_REG_1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_HULL_1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'boatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_HULL_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State) + REG (BQ.R) + HULL (BQ.H)'
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
    description    = 'Entity form configurations for OR_LEDS MC'
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
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built OR_LEDS_MC.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
