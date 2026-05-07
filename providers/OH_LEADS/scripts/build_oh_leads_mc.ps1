# build_oh_leads_mc.ps1  -- OH_LEADS v1.x MC
# MC variant: PascalCase fieldIds, no full Patch 8 (CAD rename).
# Phase 2 multi-card. Cross-entity combo: RN (vehicle by owner name).
# CAD_DISPATCH + FIRST_RESPONDER context cards.
#
# OH_LEADS-SPECIFIC:
#   NO CaRequestPurposeCode  -- Ohio, not California.
#   Date format: MMddyyyy    -- DL/DH BirthDate max=8.
#   No State initialValue    -- LIMITATION #30: separate in-state vs OOS keyRefs.
#   ImageIndicator in: ArticleSingleQuery, BoatQuery, DriverLicenseQuery (Y default)
#   RelatedHitSearchIndicator in: Article, Boat, Gun (Y-only flag)
#   DL+DH co-fire: DH uses DH-suffix fieldIds, autoSelect=true
#   VehReg has owner search combos (RS=SSN, RN=Name) -- person fields on Vehicle entity
#   DealerPlateType field for ATDP combo
#   23 combos total (same as BASE -- no new cross-entity combos added)
#
# CROSS-ENTITY:
#   VehicleRegistrationQuery RN: Vehicle by owner name (OwnerLastName, OwnerFirstName, AddressCounty).
#   GunQuery: NO name combos (QG serial only).
#   BoatQuery: NO name combos (BQ/QB hull/reg only).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_oh_leads_mc.ps1

$ErrorActionPreference = "Stop"
$Version  = '1.0'
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\mc"
$OUT      = "$DIR\OH_LEADS_MC.json"
$OUTREAD  = "$DIR\OH_LEADS_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\OH_LEADS_MC_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"

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
# BUNDLE 1: OH_LEADS PROVIDER (PascalCase sourceField / combo refs)
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
    description                = 'Authentication configuration for OH_LEADS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'OH_LEADS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'OH_LEADS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'OH_LEADS_Results'
$results.description = 'Results mapping for OH_LEADS'
$results.provider    = 'OH_LEADS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'OH_LEADS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'OH_LEADS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery -- PascalCase + cross-entity RN (owner name)
# XML: 9 combos: ATDP, RP, RQ(plate), QV(plate), RV, RS, RN, RQ(VIN), QV(VIN)
# Duplicate keyRefs: RQ -> RQ.P, RQ.V; QV -> QV.P, QV.V
# Owner combos: RS (SSN), RN (Name) -- person fields on Vehicle entity.
# DealerPlateType for ATDP combo.
# LIMITATION #30: No State initialValue -- in-state (RP/RV) vs OOS (RQ) routing.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';               size = 4;  sourceField = @('AddressCounty');               targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'DealerPlateType';             size = 1;  sourceField = @('DealerPlateType');              targetField = 'DealerPlateType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('OwnerLastName','OwnerFirstName'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';        size = 9;  sourceField = @('OwnerSocialSecurityNumber');    targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('VehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # Most-specific first (LIMITATION #3: first matching combo fires)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','DealerPlateType'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ATDP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationState','LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','VehicleMakeCode','VehicleYear'); any = @('RegistrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OwnerSocialSecurityNumber'); any = @() }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'RS'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OwnerLastName','OwnerFirstName'); any = @('AddressCounty') }
            primaryFieldReference = 'Name'
            keyReference          = 'RN'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ATDP (dealer), RP (plate), RQ.P (OOS plate), QV.P (NCIC plate), RV (VIN), RQ.V (OOS VIN), QV.V (NCIC VIN), RS (SSN), RN (Name). MC cross-entity.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'OH_LEADS_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'OH_LEADS'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- PascalCase
# XML: 7 combos. Build 4 basic: DL (in-state OLN), DQ.O (OOS OLN),
#   DN (in-state Name), DQ.N (OOS Name).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator'; size = 1; sourceField = @('ImageIndicator'); targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # Most-specific first: DQ.O requires State + OLN, DQ.N requires State + Name + DOB + Sex
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator','RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('RegistrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('BirthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'DN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DL (in-state OLN), DQ.O (OOS OLN), DN (in-state Name), DQ.N (OOS Name).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- PascalCase (DH-suffix fieldIds)
# XML: 3 combos: KQ(OLN), KQ(Name), BMVIMS(OLN).
# Duplicate keyRef KQ -> KQ.O, KQ.N.
# DH uses DH-suffix fieldIds to avoid deadlock with DL co-fire.
# Attention: CommsysGetLastNameFirstNameInitialRuleHandler (auto-fill).
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'Attention'
            rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size        = 30
            sourceField = @('NameLastDH','NameFirstDH')
            targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('PurposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 30; sourceField = @('ReasonCodeDH'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.O: OLN search (most common)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('NameLastDH','NameFirstDH','PurposeCodeDH','RegistrationStateDH') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # KQ.N: Name search
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCodeDH','BirthDateDH','NameLastDH','NameFirstDH'); any = @('PurposeCodeDH','RegistrationStateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # BMVIMS: BMV IMS image lookup by OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = @('NameLastDH','NameFirstDH','ReasonCodeDH') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'BMVIMS'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ.O (OLN), KQ.N (Name), BMVIMS (BMV IMS). DH-suffix fieldIds.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# Add queriesToDeselect on DL QIDM too
$dlQuery | Add-Member -NotePropertyName 'queriesToDeselect' -NotePropertyValue @('DriverHistoryQuery') -Force

# =====================================================================
# 1g. GunQuery -- PascalCase
# XML: 1 combo (QG serial). No name combos.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                  size = 4;  sourceField = @('GunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                     size = 23; sourceField = @('FirearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';             size = 20; sourceField = @('SerialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';   size = 1;  sourceField = @('RelatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SerialNumber'); any = @('FirearmMake','GunCaliber','RelatedHitSearchIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG (serial). Firearm query.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- PascalCase
# XML: 2 combos, BOTH keyRef=QA. Invented: QA.S (serial), QA.N (NCIC#).
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('SerialNumber');                 targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('ArticleTypeCode');              targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicatorArticle');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 9;  sourceField = @('NCICNumber');                   targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicatorArticle'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleTypeCode','SerialNumber'); any = @('ImageIndicatorArticle','RelatedHitSearchIndicatorArticle') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicatorArticle','RelatedHitSearchIndicatorArticle') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QA.N'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.S (serial+type), QA.N (NCIC#). Property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- PascalCase
# XML: 4 combos, duplicate keyRefs BQ(x2), QB(x2).
# Invented: BQ.R (reg in-state), BQ.H (hull in-state), QB.R (reg NCIC), QB.H (hull NCIC).
# No name combos in OH BoatQuery.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');               targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicatorBoat');             targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');             targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicatorBoat'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationStateBoat'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ.R: in-state registration lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('RegistrationStateBoat') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        # BQ.H: in-state hull lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationStateBoat') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        # QB.R: NCIC registration lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('BoatHullIdNumber','ImageIndicatorBoat','RelatedHitSearchIndicatorBoat') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
        # QB.H: NCIC hull lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('ImageIndicatorBoat','RelatedHitSearchIndicatorBoat') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.R/BQ.H (in-state reg/hull), QB.R/QB.H (NCIC reg/hull).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'OH_LEADS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'OH_LEADS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$ohBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for OH_LEADS v${Version} MC -- 6 QIDMs (VehReg + DL + DH + Gun + Article + Boat), 2 Person QIDMs"
    name           = 'OH_LEADS'
    type           = 'BUNDLE'
    provider       = 'OH_LEADS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (5 QIFs, multi-card layouts)
#
# Vehicle:  6 cards (OPTIONS + PLATE + DEALER PLATE + VIN + NAME SEARCH + SSN SEARCH)
# Person:   3 cards (OPTIONS + OLN SEARCH + NAME SEARCH) + DH hidden rows
# Firearm:  1 card  (SERIAL SEARCH -- no name combos, no shared options)
# Article:  2 cards (SERIAL SEARCH + NCIC# SEARCH)
# Boat:     2 cards (OPTIONS + HULL/REG SEARCH)
#
# Shared OPTIONS card: fields used by multiple combos (RegistrationState)
# live on a separate card to avoid duplicate fieldId across cards (= ISE).
# NCIC state pattern: visible RegistrationState, NO initialValue (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 6 cards (MC)
# OPTIONS: RegistrationState (shared by plate+VIN combos, not needed by name/SSN/ATDP)
# PLATE SEARCH: Plate + PlateType + PlateYear (RP, RQ.P, QV.P)
# DEALER PLATE: DealerPlateType (ATDP -- requires plate+type from PLATE card)
# VIN SEARCH: VIN + VehicleMake + VehicleYear (RV, RQ.V, QV.V)
# NAME SEARCH: OwnerFirst + OwnerLast + County (RN cross-entity)
# SSN SEARCH: OwnerSSN (RS)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS - Leave blank for OH queries'
        rows  = @(
            @{ id = 'ROW_VEH_OPT_1'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_OPT_1' }
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
        id    = 'CARD_VEH_DEALER'
        title = 'DEALER PLATE'
        rows  = @(
            @{ id = 'ROW_VEH_DEALER_1'; cols = @('6'); fields = @(
                @{ id = 'DealerPlateType_Input'; node = Inp 'DealerPlateType' 'Dealer Plate Type' '1' 'ROW_VEH_DEALER_1' }
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
                @{ id = 'VehicleMakeCode_Input'; node = Inp 'VehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_VIN_2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear'     'Vehicle Year' '4' 'ROW_VEH_VIN_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_NAME'
        title = 'NAME SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'OwnerFirstName_Input'; node = Inp 'OwnerFirstName' 'Owner First Name' '30' 'ROW_VEH_NAME_1' }
                @{ id = 'OwnerLastName_Input';  node = Inp 'OwnerLastName'  'Owner Last Name'  '30' 'ROW_VEH_NAME_1' }
            )}
            @{ id = 'ROW_VEH_NAME_2'; cols = @('6'); fields = @(
                @{ id = 'AddressCounty_Input'; node = Inp 'AddressCounty' 'County Code' '4' 'ROW_VEH_NAME_2' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_SSN'
        title = 'SSN SEARCH (Vehicle by Owner)'
        rows  = @(
            @{ id = 'ROW_VEH_SSN_1'; cols = @('6'); fields = @(
                @{ id = 'OwnerSocialSecurityNumber_Input'; node = Inp 'OwnerSocialSecurityNumber' 'Owner SSN' '9' 'ROW_VEH_SSN_1' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS (State) + PLATE (RP/RQ.P/QV.P) + DEALER (ATDP) + VIN (RV/RQ.V/QV.V) + NAME (RN cross-entity) + SSN (RS)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 3 cards (MC) + DH hidden rows
# OPTIONS: RegistrationState + ImageIndicator (shared by DL + DH)
# OLN SEARCH: OperatorLicenseNumber (DL, DQ.O, KQ.O, BMVIMS)
# NAME SEARCH: First + Last + DOB + Sex (DN, DQ.N, KQ.N)
# DH hidden fields: DH-suffix fieldIds on hidden rows in NAME/OLN cards
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS - Leave blank for OH queries'
        rows  = @(
            @{ id = 'ROW_PER_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_OPT_1' }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image Indicator' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_OPT_1' }
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
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_NAME_1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_NAME_1' }
            )}
            @{ id = 'ROW_PER_NAME_2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                                          'ROW_PER_NAME_2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_NAME_2' }
            )}
        )
    }
    # DH-suffix hidden fields -- mirror DL fields for DH QIDM
    @{
        id    = 'CARD_PER_DH'
        rows  = @(
            @{ id = 'ROW_PER_DH1'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = InpH 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH1' }
                @{ id = 'RegistrationStateDH_Input';     node = SelH 'RegistrationStateDH' 'State (DH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DH1' }
            )}
            @{ id = 'ROW_PER_DH2'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'NameFirstDH_Input'; node = InpH 'NameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH2' }
                @{ id = 'NameLastDH_Input';  node = InpH 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH2' }
            )}
            @{ id = 'ROW_PER_DH3'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'DOB (DH)' 'ROW_PER_DH3' }
                @{ id = 'SexCodeDH_Input';   node = SelH 'SexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH3' }
            )}
            @{ id = 'ROW_PER_DH4'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'PurposeCodeDH_Input'; node = InpH 'PurposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_DH4' }
                @{ id = 'ReasonCodeDH_Input';  node = InpH 'ReasonCodeDH'  'Reason Code (DH)'  '30' 'ROW_PER_DH4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS (State + Image) + OLN (DL/DQ.O/KQ.O/BMVIMS) + NAME (DN/DQ.N/KQ.N). DH-suffix fieldIds.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (MC)
# QG serial only. No name combos, no shared options needed.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'SerialNumber' 'Serial Number' '20' 'ROW_GUN_SERIAL_1' }
                @{ id = 'FirearmMake_Input';  node = Sel 'FirearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_1' }
            )}
            @{ id = 'ROW_GUN_SERIAL_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_SERIAL_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit Search' '1' 'ROW_GUN_SERIAL_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- MC: SERIAL (QG). No GunTypeCode in OH metadata.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 2 cards (MC)
# SERIAL SEARCH: Serial + ArticleType + ImageIndicator + RelatedHitSearchIndicator (QA.S)
# NCIC# SEARCH: NCICNumber + ImageIndicator + RelatedHitSearchIndicator (QA.N)
# Note: ImageIndicator and RelatedHitSearchIndicator are in any[] for both combos.
# They use entity-specific suffixed fieldIds to avoid ISE with other entities.
# Since both combos share these any[] fields, they go on both cards.
# But duplicate fieldId across cards = ISE. So use OPTIONS card for shared fields.
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_ART_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'ImageIndicatorArticle_Input';            node = Sel 'ImageIndicatorArticle'            'Image Indicator'    @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_OPT_1' }
                @{ id = 'RelatedHitSearchIndicatorArticle_Input'; node = Inp 'RelatedHitSearchIndicatorArticle' 'Related Hit Search' '1' 'ROW_ART_OPT_1' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_SERIAL'
        title = 'SERIAL SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_SERIAL_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'SerialNumber'    'Serial Number' '20' 'ROW_ART_SERIAL_1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type'  @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_ART_SERIAL_1' }
            )}
        )
    }
    @{
        id    = 'CARD_ART_NCIC'
        title = 'NCIC# SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_NCIC_1'; cols = @('12'); fields = @(
                @{ id = 'NCICNumber_Input'; node = Inp 'NCICNumber' 'NCIC Number' '9' 'ROW_ART_NCIC_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- MC: OPTIONS (Image + RelatedHit) + SERIAL (QA.S) + NCIC# (QA.N)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 2 cards (MC)
# OPTIONS: RegistrationStateBoat + ImageIndicatorBoat + RelatedHitSearchIndicatorBoat
#          (shared by BQ + QB combos)
# HULL/REG SEARCH: HullId + RegNumber (BQ.R, BQ.H, QB.R, QB.H)
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS - Leave blank for OH queries'
        rows  = @(
            @{ id = 'ROW_BOA_OPT_1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationStateBoat_Input';           node = Sel 'RegistrationStateBoat'            'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_OPT_1' }
                @{ id = 'ImageIndicatorBoat_Input';              node = Sel 'ImageIndicatorBoat'               'Image Indicator'    @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_OPT_1' }
            )}
            @{ id = 'ROW_BOA_OPT_2'; cols = @('6'); fields = @(
                @{ id = 'RelatedHitSearchIndicatorBoat_Input';   node = Inp 'RelatedHitSearchIndicatorBoat'    'Related Hit Search' '1' 'ROW_BOA_OPT_2' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'HULL / REGISTRATION SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_SEARCH_1'; cols = @('6','6'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_SEARCH_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number'  '8'  'ROW_BOA_SEARCH_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS (State + Image + RelatedHit) + HULL/REG (BQ.R/BQ.H/QB.R/QB.H)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations for OH_LEADS MC'
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
# BUNDLE 3: RMS (from HIDLE -- NO full Patch 8, keeps PascalCase)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add RegistrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# Patch 3: add RegistrationState to RMS Person QIDM
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'RegistrationState'
    sourceField    = @('RegistrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'RegistrationState'
}

# Patch 6: RMS CLEANUP
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

# Patch 7: RMS autoSelect=true
$rmsVehQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
$rmsPersonQidm | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force

# Patch 8 (partial): rename banned LicensePlateNumberIn -> LicensePlateNumber
foreach ($cfg in $rmsBundle.configurations) {
    if (-not $cfg.attributes) { continue }
    foreach ($attr in $cfg.attributes) {
        if ($attr.name -eq 'LicensePlateNumberIn') { $attr.name = 'LicensePlateNumber' }
        if ($attr.sourceField) {
            $attr.sourceField = @($attr.sourceField | ForEach-Object {
                if ($_ -eq 'LicensePlateNumberIn') { 'LicensePlateNumber' } else { $_ }
            })
        }
    }
    if (-not $cfg.combinations) { continue }
    foreach ($combo in $cfg.combinations) {
        if ($combo.primaryFieldReference -eq 'LicensePlateNumberIn') { $combo.primaryFieldReference = 'LicensePlateNumber' }
        if ($combo.requirements.set) {
            $combo.requirements.set = @($combo.requirements.set | ForEach-Object {
                if ($_ -eq 'LicensePlateNumberIn') { 'LicensePlateNumber' } else { $_ }
            })
        }
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | ForEach-Object {
                if ($_ -eq 'LicensePlateNumberIn') { 'LicensePlateNumber' } else { $_ }
            })
        }
    }
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ohBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built OH_LEADS_MC.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
