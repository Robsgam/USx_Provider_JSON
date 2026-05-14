# build_tn_ties_mc.ps1  -- TN_TIES v1.2 MC (6 basic queries, multi-card)
# MC variant: PascalCase fieldIds, no full Patch 8 (CAD rename).
# Phase 2 multi-card. No cross-entity combos (no VP/QGH/BQ.N in metadata).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# TN-SPECIFIC:
#   NO CaRequestPurposeCode (Tennessee, not California).
#   DriverHistoryQuery has PurposeCode (Mandatory) + Attention (Mandatory) fields.
#   ImageIndicator present in DL metadata.
#   LIMITATION #30: No State initialValue -- in-state vs OOS keyRef routing.
#   28 combos total -- the most of any provider.
#
# METADATA SUMMARY -- 6 BASIC QUERIES (28 combos):
#   VehicleRegistrationQuery v22  -- 13 combos: RQ01, RV01, RQ03, RV03, RQ06, RQ05, RQ07, RV, RQ.P, RQ.V, QV.V, QV.P, QV.D
#   DriverLicenseQuery v15        -- 6 combos: DQ01, DQ02, DQ06, DQ.N, DQ.O, QWA
#   DriverHistoryQuery v9         -- 3 combos: KQ.N, KQ.O, DQ05
#   GunQuery v6                   -- 1 combo: QG
#   ArticleSingleQuery v6         -- 1 combo: QA
#   BoatQuery v12                 -- 4 combos: BB.H, BB.R, QB.H, QB.R
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tn_ties_mc.ps1

$ErrorActionPreference = "Stop"
$Version = '1.4'
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\mc"
$OUT      = "$DIR\TN_TIES_MC.json"
$OUTREAD  = "$DIR\TN_TIES_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\TN_TIES_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\..\..\templates\HIDLE_MC.json" -Raw | ConvertFrom-Json

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
# BUNDLE 2: TN_TIES PROVIDER (PascalCase sourceField / combo refs)
# =====================================================================

# 2a. AUTHENTICATION
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
    description                = 'Authentication configuration for TN TIES'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'TN_TIES'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'TN_TIES'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 2b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'TN_TIES_Results'
$results.description = 'Results mapping for TN TIES'
$results.provider    = 'TN_TIES'

# 2c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'TN_TIES_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'TN_TIES'
}

# =====================================================================
# 2d. VehicleRegistrationQuery -- PascalCase (13 combos)
# XML v22: In-state (RQ01/RV01 plate, RQ03/RV03 VIN), Specialty (RQ05 Dealer,
# RQ06 Handicap, RQ07 Temp), OOS (RV/RQ plate+type+year+state, RQ VIN+state),
# NCIC (QV VIN, QV plate, QV dealer).
# LIMITATION #30: No State initialValue -- in-state vs OOS routing.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DealerLicensePlateNumber';     size = 10; sourceField = @('DealerLicensePlateNumber');     targetField = 'DealerLicensePlateNumber' }
        [PSCustomObject]@{ name = 'HandicapPlacardNumber';        size = 10; sourceField = @('HandicapPlacardNumber');        targetField = 'HandicapPlacardNumber' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator';         size = 1;  sourceField = @('InquiryTypeIndicator');         targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                        size = 2;  sourceField = @('registrationState');            targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TemporaryLicensePlateNumber';  size = 10; sourceField = @('TemporaryLicensePlateNumber');  targetField = 'TemporaryLicensePlateNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 4;  sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS Plate (most specific -- requires State+PlateType+PlateYear)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode','registrationState'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode','registrationState'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationState','vehicleIdentificationNumber'); any = @('InquiryTypeIndicator','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state Plate (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ01'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RV01'
            state                 = 'In/Out'
        }
        # In-state VIN (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ03'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RV03'
            state                 = 'In/Out'
        }
        # Specialty searches
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('HandicapPlacardNumber'); any = @() }
            primaryFieldReference = 'HandicapPlacardNumber'
            keyReference          = 'RQ06'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('DealerLicensePlateNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'RQ05'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('TemporaryLicensePlateNumber'); any = @() }
            primaryFieldReference = 'TemporaryLicensePlateNumber'
            keyReference          = 'RQ07'
            state                 = 'In/Out'
        }
        # NCIC queries (QV)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('InquiryTypeIndicator','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('InquiryTypeIndicator','licensePlateTypeCode') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('DealerLicensePlateNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'QV.D'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQ01/RV01 (IS plate), RQ03/RV03 (IS VIN), RV/RQ (OOS), QV (NCIC), RQ05/06/07 (specialty). MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 2e. DriverLicenseQuery -- PascalCase (6 combos)
# DQ01 (IS OLN), DQ02 (IS Name+DOB+Sex), DQ06 (IS SSN),
# DQ.N (OOS Name), DQ.O (OOS OLN), QWA (NCIC Name).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('ExpandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator';      size = 1;  sourceField = @('InquiryTypeIndicator');      targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';     size = 20; sourceField = @('operatorLicenseNumber');     targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('RaceCode');                  targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('sexCode');                   targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';      size = 20; sourceField = @('SocialSecurityNumber');      targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                     size = 2;  sourceField = @('registrationState');         targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name+DOB+Sex+State (5 set -- most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode','registrationState'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # NCIC Name (QWA -- 4 set, broadest name search with expanded search options)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode'); any = @('ExpandedNameSearchCode','imageIndicator','InquiryTypeIndicator','RaceCode','relatedHitSearchIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In/Out'
        }
        # In-state Name+DOB+Sex (4 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ02'
            state                 = 'In/Out'
        }
        # OOS OLN+State (2 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        # In-state OLN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('ExpandedNameSearchCode','imageIndicator','InquiryTypeIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ01'
            state                 = 'In/Out'
        }
        # In-state SSN (1 set)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SocialSecurityNumber'); any = @('ExpandedNameSearchCode','imageIndicator','InquiryTypeIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'DQ06'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ01 (IS OLN), DQ02 (IS Name), DQ06 (IS SSN), DQ.N/DQ.O (OOS), QWA (NCIC). MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('DriverHistoryQuery')
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 2f. DriverHistoryQuery -- PascalCase (3 combos)
# KQ.N (Name+DOB+Sex OOS), KQ.O (OLN OOS), DQ05 (IS OLN).
# PurposeCode (Mandatory) + Attention (Mandatory) on KQ combos.
# DH-suffix fieldIds for isolation from DL.
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            size = 30
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            sourceField = @('nameLast','nameFirst')
            targetField = 'Attention'
        }
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
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('registrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ Name+DOB+Sex (OOS via Nlets -- Attention+PurposeCode mandatory)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLastDH','nameFirstDH','birthDateDH','sexCodeDH','purposeCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ OLN (OOS via Nlets -- Attention+PurposeCode mandatory)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH','purposeCodeDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # DQ05 In-state OLN (no Attention/PurposeCode)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ05'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ.N (Name+DOB+Sex OOS), KQ.O (OLN OOS), DQ05 (IS OLN). Attention auto-filled. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('DriverLicenseQuery')
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 2g. GunQuery -- PascalCase (1 combo: QG)
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('gunCaliber');   targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';          size = 3;  sourceField = @('firearmMake');  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';  size = 20; sourceField = @('serialNumber'); targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('gunCaliber','firearmMake') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). Optional caliber and make. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 2h. ArticleSingleQuery -- PascalCase (1 combo: QA)
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
    description     = 'ArticleSingleQuery -- QA (serial + type). NCIC article inquiry. MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 2i. BoatQuery -- PascalCase (4 combos: BB.H, BB.R, QB.H, QB.R)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';    size = 20; sourceField = @('boatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator'; size = 1; sourceField = @('InquiryTypeIndicator'); targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';  size = 8;  sourceField = @('registrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State';               size = 2;  sourceField = @('registrationState');   targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BB In-state with optional State
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('InquiryTypeIndicator','registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('InquiryTypeIndicator','registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BB.R'
            state                 = 'In/Out'
        }
        # QB NCIC (no State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('InquiryTypeIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BB.H/BB.R (IS hull/reg + State), QB.H/QB.R (NCIC hull/reg). MC PascalCase.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# BUNDLE 1: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  4 cards (OPTIONS + PLATE + VIN + SPECIALTY)
# Person:   3 cards (OPTIONS + OLN + NAME) with DH hidden rows
# Firearm:  1 card (single combo QG)
# Article:  1 card (single combo QA)
# Boat:     3 cards (OPTIONS + HULL + REGISTRATION)
#
# No cross-entity combos for TN (no VP/QGH/BQ.N).
# Shared OPTIONS card: fields used by multiple combos.
# NCIC state pattern: visible RegistrationState, NO initialValue (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 4 cards (MC)
# OPTIONS: RegistrationState + InquiryTypeIndicator + PlateType + PlateYear (shared by many combos)
# PLATE SEARCH: LicensePlateNumber
# VIN SEARCH: VIN + VehicleMake + VehicleYear
# SPECIALTY SEARCH: DealerPlate + HandicapPlacard + TempPlate
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for TN queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';   node = Sel 'registrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
                @{ id = 'InquiryTypeIndicator_Input'; node = Inp 'InquiryTypeIndicator' 'Inquiry Type (1/2/3)' '1' 'ROW_VEH_OPT_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_OPT_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_OPT_2'; cols = @('6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_OPT_2' }
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
    @{
        id    = 'CARD_VEH_SPEC'
        title = 'SPECIALTY SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_SPEC_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'DealerLicensePlateNumber_Input';    node = Inp 'DealerLicensePlateNumber'    'Dealer Plate'     '10' 'ROW_VEH_SPEC_1' }
                @{ id = 'HandicapPlacardNumber_Input';       node = Inp 'HandicapPlacardNumber'       'Handicap Placard' '10' 'ROW_VEH_SPEC_1' }
                @{ id = 'TemporaryLicensePlateNumber_Input'; node = Inp 'TemporaryLicensePlateNumber' 'Temp Plate'       '10' 'ROW_VEH_SPEC_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State + InquiryType + PlateType + PlateYear) + PLATE (RQ01/RV01/RV/RQ.P/QV.P) + VIN (RQ03/RV03/RQ.V/QV.V) + SPECIALTY (RQ05/RQ06/RQ07/QV.D)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC) with DH hidden rows on OLN and NAME cards
# OPTIONS: RegistrationState + ImageIndicator + Race + InquiryType + ExpandedNameSearch + RelatedHit
# OLN SEARCH: OperatorLicenseNumber + SSN + DH hidden (OperatorLicenseNumberDH + PurposeCode)
# NAME SEARCH: NameFirst + NameLast + BirthDate + SexCode + DH hidden (NameFirstDH + NameLastDH + BirthDateDH + SexCodeDH)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for TN queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'registrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'imageIndicator' 'Image (Y/N)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
                @{ id = 'RaceCode_Input';          node = Sel 'RaceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_OPT_1' }
            )}
            @{ id = 'ROW_PER_OPT_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'InquiryTypeIndicator_Input';      node = Inp 'InquiryTypeIndicator'      'Inquiry Type (1/2/3)' '1' 'ROW_PER_OPT_2' }
                @{ id = 'ExpandedNameSearchCode_Input';    node = Inp 'ExpandedNameSearchCode'    'Exp Name Search'      '1' 'ROW_PER_OPT_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit'          '1' 'ROW_PER_OPT_2' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'OLN SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_OLN_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_OLN_1' }
                @{ id = 'SocialSecurityNumber_Input';  node = Inp 'SocialSecurityNumber'  'SSN'            '20' 'ROW_PER_OLN_1' }
            )}
            # DH hidden row on OLN card
            @{ id = 'ROW_PER_OLN_DH'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = InpH 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_OLN_DH' }
                @{ id = 'PurposeCodeDH_Input';           node = InpH 'PurposeCodeDH'           'Purpose Code (DH)'   '1'  'ROW_PER_OLN_DH' }
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
                @{ id = 'BirthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                       'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }        'ROW_PER_NAME_2' }
            )}
            # DH hidden rows on NAME card
            @{ id = 'ROW_PER_NAME_DH1'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'NameFirstDH_Input'; node = InpH 'NameFirstDH' 'First Name (DH)' '30' 'ROW_PER_NAME_DH1' }
                @{ id = 'NameLastDH_Input';  node = InpH 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_NAME_DH1' }
            )}
            @{ id = 'ROW_PER_NAME_DH2'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)'                                                           'ROW_PER_NAME_DH2' }
                @{ id = 'SexCodeDH_Input';   node = SelH 'SexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }  'ROW_PER_NAME_DH2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Image + Race + InquiryType) + OLN (DQ01/DQ.O/DQ06 + DH OLN hidden) + NAME (DQ02/DQ.N/QWA + DH Name hidden)'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (single combo QG, no cross-entity)
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('12'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'FirearmMake_Input'; node = Sel 'firearmMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'GunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: single card QG (serial). Optional make and caliber.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (single combo QA, no cross-entity)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';   node = Inp 'serialNumber'   'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: single card QA (serial + type). NCIC article inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 3 cards (MC)
# OPTIONS: RegistrationState + InquiryTypeIndicator (shared by BB/QB combos)
# HULL SEARCH: BoatHullIdNumber (BB.H / QB.H)
# REGISTRATION SEARCH: RegistrationNumber (BB.R / QB.R)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for TN queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';    node = Sel 'registrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'InquiryTypeIndicator_Input'; node = Inp 'InquiryTypeIndicator' 'Inquiry Type (1/2/3)' '1' 'ROW_BOA_OPT_1' }
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
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + InquiryType) + HULL (BB.H/QB.H) + REG (BB.R/QB.R)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations for TN_TIES MC'
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
# BUNDLE 2: TN_TIES PROVIDER
# =====================================================================
$tnBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for TN_TIES v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'TN_TIES'
    type           = 'BUNDLE'
    provider       = 'TN_TIES'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE_MC -- camelCase, registrationState, autoSelect pre-configured)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm    = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }

# RMS cleanup: remove unused HIDLE fields
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehQidm.attributes   = @($rmsVehQidm.attributes   | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object { $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName') })
foreach ($combo in $rmsVehQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
$rmsPersonQidm.attributes   = @($rmsPersonQidm.attributes   | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $tnBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built TN_TIES_MC.json v${Version}" -ForegroundColor Green
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

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
