# build_ca_clets_ocats_mc.ps1  -- CA_CLETS_OCATS v1.x MC
# MC variant: PascalCase fieldIds, no Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combos (VP name on Vehicle).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_clets_ocats_mc.ps1

$ErrorActionPreference = "Stop"
$Version  = '1.2'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\mc"
$OUT      = "$DIR\CA_CLETS_OCATS_MC.json"
$OUTREAD  = "$DIR\CA_CLETS_OCATS_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\CA_CLETS_OCATS_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"

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
# BUNDLE 1: CA_CLETS_OCATS PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

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
    description                = 'Authentication configuration for CA CLETS OCATS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'CA_CLETS_OCATS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'CA_CLETS_OCATS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$results = Build-CommsysQrdm -ProviderName 'CA_CLETS_OCATS'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'CA_CLETS_OCATS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'CA_CLETS_OCATS'
}

# VehicleRegistrationQuery -- PascalCase + cross-entity (Name for VP combo)
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 35; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber','registrationState'); any = @('licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'VP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = '4V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber'); any = @('registrationState','licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = '4'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- 4 (plate), 4V (VIN), RQ (OOS plate/VIN), VP (name). MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_CLETS_OCATS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_CLETS_OCATS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# DriverLicenseQuery -- PascalCase
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
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
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','birthDate','sexCode','registrationState'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber','registrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @('birthDate','registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.O (OLN), L1.N (Name), DQ.O (OOS OLN), DQ.N (OOS Name).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# GunQuery -- PascalCase. No QGH (gun by name) in OCATS metadata.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial). OCATS firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# ArticleSingleQuery -- PascalCase
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';  size = 20; sourceField = @('ownerAppliedNumber');  targetField = 'OwnerAppliedNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('articleBrand','articleTypeCode') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QA.O'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial, OAN). OCATS property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# BoatQuery -- PascalCase
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber','registrationState'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber','registrationState'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = '4V.B'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','ownerAppliedNumber'); any = @('registrationState') }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QB.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = '4B'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- 4B (reg), 4V.B (hull), BQ (OOS hull/reg), QB (stolen hull/reg/OAN). OCATS boat inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CLETS_OCATS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_CLETS_OCATS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$caBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for CA_CLETS_OCATS v${Version} MC -- 5 QIDMs (VehReg + DL + Gun + Article + Boat), no DH"
    name           = 'CA_CLETS_OCATS'
    type           = 'BUNDLE'
    provider       = 'CA_CLETS_OCATS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE SEARCH + VIN SEARCH + NAME SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH) -- DL only, no DH
# Firearm:  2 cards (OPTIONS + SERIAL SEARCH) -- no NAME card (no QGH)
# Article:  3 cards (OPTIONS + SERIAL SEARCH + OAN SEARCH)
# Boat:     5 cards (OPTIONS + HULL + REGISTRATION + OAN + STOLEN)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState,
# CaRequestPurposeCode) live on a separate card to avoid duplicate fieldId
# across cards (= ISE). NCIC state pattern: visible RegistrationState,
# NO initialValue (blank default -- LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# PLATE SEARCH: Plate + PlateType + PlateYear
# VIN SEARCH: VIN + VehicleMake + VehicleYear
# NAME SEARCH: First + Last (cross-entity VP)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_OPT_1' @{ initialValue = 'C' } }
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
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_VIN_1' }
            )}
            @{ id = 'ROW_VEH_VIN_2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_NAME'
        title = 'NAME SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_VEH_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_VEH_NAME_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + Purpose) + PLATE (4/RQ.P) + VIN (4V/RQ.V) + NAME (VP cross-entity)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by DL)
# OLN SEARCH: OperatorLicenseNumber
# NAME SEARCH: First + Last + DOB + Sex (DL L1.N + DQ.N)
# No DH co-fire -- OCATS has no KQ MessageKeys.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_OPT_1' @{ initialValue = 'C' } }
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
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_NAME_2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Purpose) + OLN (L1.O/DQ.O) + NAME (L1.N/DQ.N). No DH co-fire.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 2 cards (MC)
# OPTIONS: CaRequestPurposeCode (shared)
# SERIAL SEARCH: Serial + Make + Caliber + Type (QGB)
# No NAME card -- OCATS has no QGH (gun by name)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_GUN_OPT_1'; cols = @('4'); fields = @(
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_GUN_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_SERIAL_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_1' }
            )}
            @{ id = 'ROW_GUN_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
                @{ id = 'GunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: OPTIONS (Purpose) + SERIAL (QGB). No NAME card (no QGH in OCATS).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 3 cards (MC)
# OPTIONS: CaRequestPurposeCode (shared by serial + OAN combos)
# SERIAL SEARCH: Serial + ArticleType + Brand (QA.S)
# OAN SEARCH: OwnerAppliedNumber (QA.O)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_ART_OPT_1'; cols = @('4'); fields = @(
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_OPT_1' @{ initialValue = 'C' } }
            )}
        )
    }
    @{
        id    = 'CARD_ART_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_SERIAL_1'; cols = @('12'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_ART_SERIAL_1' }
            )}
            @{ id = 'ROW_ART_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS_OCATS' } 'ROW_ART_SERIAL_2' }
                @{ id = 'ArticleBrand_Input';    node = Inp 'articleBrand'    'Brand'        '6'                                                                            'ROW_ART_SERIAL_2' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_OAN'
        title = 'OAN SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_OAN_1'; cols = @('12'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_OAN_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: OPTIONS (Purpose) + SERIAL (QA.S) + OAN (QA.O)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 5 cards (MC)
# OPTIONS: RegistrationState + CaRequestPurposeCode (shared by all combos)
# HULL SEARCH: BoatHullIdNumber (4V.B / BQ.H / QB.H)
# REGISTRATION SEARCH: RegistrationNumber (4B / BQ.R / QB.R)
# OAN SEARCH: OwnerAppliedNumber (QB.O)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for CA queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','4'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'CaRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_OPT_1' @{ initialValue = 'C' } }
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
        id    = 'CARD_BOA_OAN'
        title = 'OAN SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_OAN_1'; cols = @('12'); fields = @(
                @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_BOA_OAN_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Purpose) + HULL (4V.B/BQ.H/QB.H) + REG (4B/BQ.R/QB.R) + OAN (QB.O)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations for CA_CLETS_OCATS MC'
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
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle
# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $caBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built CA_CLETS_OCATS_MC.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
