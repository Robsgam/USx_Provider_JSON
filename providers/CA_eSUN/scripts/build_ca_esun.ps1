# build_ca_esun.ps1  -- CA_eSUN v1.x BASE
# Builds CA_eSUN_BASE.json from source\CA_eSUN.xml metadata + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_esun.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\CA_eSUN.xml   -- XML metadata [AUTHORITATIVE]
#   source\HIDLE.json    -- RMS structural template
#
# METADATA SUMMARY (CA_eSUN -- 6 basic queries, 20 combos in XML):
#   ArticleSingleQuery        -- 1 combo (QA serial)
#   BoatQuery                 -- 6 combos in XML, collapsed to 2 (BQ.R reg, BQ.H hull)
#   DriverHistoryQuery        -- 4 combos: L1.N/L1.O in-state + KQ.N/KQ.O OOS
#   DriverLicenseQuery        -- 4 combos: L1.N/L1.O in-state + DQ.N/DQ.O OOS
#   GunQuery                  -- 2 combos (QGB serial, QGH name)
#   VehicleRegistrationQuery  -- 8 combos in XML, collapsed to 6 (QV.P/QV.V, RQ.P/RQ.V, VP.N/VP.D)
#
# CA_eSUN-SPECIFIC:
#   CaRequestPurposeCode -- required in set[] on EVERY combo. Visible Inp initialValue='C' (Criminal Justice).
#   No ImageIndicator    -- not in eSUN metadata.
#   No State initialValue -- LIMITATION #30: DL L1 vs DQ routing by State presence.
#   Date format: MIXED! DL/DH BirthDate max=10 (yyyy-MM-dd), Gun BirthDate max=8 (MMddyyyy).
#   Name format: 'Name' composite, max 30 chars (Last, First) -- FormatStringRuleHandler.
#   Attention: CommsysGetLastNameFirstNameInitialRuleHandler (DH only, auto-filled).
#   PurposeCode: hidden field sourced from caRequestPurposeCode (DH only).
#   DL+DH co-fire on shared Person form. DH uses DH-suffix fieldIds.
#   GunQuery QGH: gun-by-name (Name + BirthDate|Age). Cross-entity fields on Firearm entity.
#   VehicleRegistrationQuery VP: owner search (Name/BirthDate on Vehicle entity).
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 17 combos built):
#   ArticleSingleQuery         QA (Serial)
#   BoatQuery                  BQ.R (Reg), BQ.H (Hull)
#   DriverHistoryQuery         L1.N (Name in-state), L1.O (OLN in-state), KQ.N (Name OOS), KQ.O (OLN OOS)
#   DriverLicenseQuery         L1.N (Name in-state), L1.O (OLN in-state), DQ.N (Name OOS), DQ.O (OLN OOS)
#   GunQuery                   QGB (Serial), QGH (Name)
#   VehicleRegistrationQuery   QV.P (Plate), QV.V (VIN), RQ.P (OOS Plate), RQ.V (OOS VIN), VP.N (Owner Name), VP.D (Owner DOB)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- Plate + VIN + State + PlateType + PlateYear + VehMake + VehYear + Name + DOB + AddressCity + AddressStreetNum + CaPurpose(visible)
#   Person   -- OLN + Name + DOB + Sex + State + CaPurpose(visible)
#   Firearm  -- Serial + Make + Caliber + Type + Name + DOB + Age + RelatedSearchHitIndicator + CaPurpose(visible)
#   Article  -- Serial + ArticleType + ArticleBrand + ArticleCategory + CaPurpose(visible)
#   Boat     -- Hull + Reg# + State + CaPurpose(visible)
#
# PERSON (2 QIDMs co-fire by design):
#   DL + DH share Person entity/form.
#   DH uses DH-suffix fieldIds: operatorLicenseNumberDH, nameFirstDH, nameLastDH, birthDateDH, sexCodeDH.
#   Both have autoSelect=true + queriesToDeselect.

param(
    [string]$Version = "1.2",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_eSUN_BASE.json"
$OUTREAD  = "$DIR\CA_eSUN_BASE_READABLE.json"
$VEROUT   = "$PHASEDIR\CA_eSUN_v${Version}_${DATE}.json"

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

function DtH($fid, $lbl, $parentId) {
    N 'FormDate' 'Date' @{ fieldId = $fid; label = $lbl } $false $true @() $parentId
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
# BUNDLE 1: CA_eSUN PROVIDER
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
    description                = 'Authentication configuration for CA_eSUN'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'CA_eSUN'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'CA_eSUN'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'CA_eSUN_Results'
$results.description = 'Results mapping for CA_eSUN'
$results.provider    = 'CA_eSUN'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'CA_eSUN_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'CA_eSUN'
}

# =====================================================================
# 1d. ArticleSingleQuery
# XML: 1 combo (QA serial).
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown).
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleBrand';        size = 6;  sourceField = @('articleBrand');        targetField = 'ArticleBrand' }
        [PSCustomObject]@{ name = 'ArticleCategory';     size = 1;  sourceField = @('articleCategory');     targetField = 'ArticleCategory' }
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('serialNumber');        targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 6;  sourceField = @('articleTypeCode');     targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('articleBrand','articleCategory','articleTypeCode') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA (serial). Property inquiry.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1e. BoatQuery
# XML: 6 combos (BQ x2, 4B, 4V, QB x2) -- all duplicates by field content.
# BQ has any=[State], others have set-only. BQ covers all.
# Collapsed to 2: BQ.R (reg), BQ.H (hull). Invented keyRefs (AP #5).
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';      size = 20; sourceField = @('boatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';  size = 1;  sourceField = @('caRequestPurposeCode');  targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'RegistrationNumber';    size = 8;  sourceField = @('registrationNumber');    targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','boatHullIdNumber'); any = @('registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','registrationNumber'); any = @('registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ.H (hull), BQ.R (reg). 6 XML combos collapsed to 2.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# 1f. DriverLicenseQuery
# XML: 4 combos (L1 x2, DQ x2). Duplicate keyRef L1 and DQ.
# Invented: L1.N (Name in-state), L1.O (OLN in-state), DQ.N (Name OOS), DQ.O (OLN OOS).
# BirthDate max=10 -> yyyy-MM-dd format.
# SexCode: codeTypeProvider='NIBRS'.
# State: codeTypeProvider='NCIC'. No initialValue (LIMITATION #30).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('birthDate'); targetField = 'BirthDate'
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
        # DQ.N (OOS Name) -- most specific first (4 set fields)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','sexCode','birthDate','nameLast','nameFirst'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # DQ.O (OOS OLN) -- State in any[] distinguishes from L1.O
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        # L1.N (in-state Name)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst'); any = @('birthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        # L1.O (in-state OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- L1.N/L1.O (in-state), DQ.N/DQ.O (OOS).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverHistoryQuery')
}

# =====================================================================
# 1g. DriverHistoryQuery
# XML: 4 combos (L1 x2, KQ x2). Duplicate keyRef L1 and KQ.
# Invented: L1.N (Name in-state), L1.O (OLN in-state), KQ.N (Name OOS), KQ.O (OLN OOS).
# DH uses DH-suffix fieldIds for co-fire with DL.
# BirthDate max=10 -> yyyy-MM-dd format.
# Attention: CommsysGetLastNameFirstNameInitialRuleHandler (auto-filled, no form field).
# PurposeCode: hidden, sourced from caRequestPurposeCode.
# KQ.N: set=[CaPurpose, Name, SexCode, BirthDate], any=[Attention, PurposeCode, State]
# KQ.O: set=[CaPurpose, OLN], any=[Attention, PurposeCode, State]
# L1.N: set=[CaPurpose, Name]
# L1.O: set=[CaPurpose, OLN]
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler'; arguments = @() }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('caRequestPurposeCode'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.N (OOS Name) -- most specific first (4 set fields + 3 any)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLastDH','nameFirstDH','sexCodeDH','birthDateDH'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ.O (OOS OLN) -- any=[State] distinguishes from L1.O
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumberDH'); any = @('registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # L1.N (in-state Name)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLastDH','nameFirstDH'); any = @('birthDateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'L1.N'
            state                 = 'In/Out'
        }
        # L1.O (in-state OLN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','operatorLicenseNumberDH'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'L1.O'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- L1.N/L1.O (in-state), KQ.N/KQ.O (OOS). DH-suffix fieldIds for co-fire.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# =====================================================================
# 1h. GunQuery
# XML: 2 combos (QGB serial, QGH name).
# QGB: set=[CaPurpose, GunSerialNumber], any=[GunCaliber, GunMake, GunTypeCode, RelatedSearchHitIndicator]
# QGH: set=[CaPurpose, Name], choice=[BirthDate OR Age]
# QGH has cross-entity fields (Name, BirthDate, Age on Firearm form).
# GunSerialNumber max=14 (eSUN, not 20 like SLO).
# BirthDate max=8 -> MMddyyyy format for GunQuery.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age';                  size = 2;  sourceField = @('gunAge');                targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('gunBirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'GunCaliber';           size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 3;  sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';      size = 14; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunTypeCode';          size = 2;  sourceField = @('gunTypeCode');           targetField = 'GunTypeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('gunNameLast','gunNameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','serialNumber'); any = @('gunCaliber','firearmMake','gunTypeCode','relatedSearchHitIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','gunNameLast','gunNameFirst'); any = @('gunBirthDate','gunAge') }
            primaryFieldReference = 'Name'
            keyReference          = 'QGH'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QGB (serial), QGH (name). Firearm query with name-based search.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_eSUN_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'CA_eSUN'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1i. VehicleRegistrationQuery
# XML: 8 combos (QV x2, 4+4V, RQ x2, VP x2). Duplicate keyRefs QV, RQ, VP.
# Collapsed to 6: QV.P (plate), QV.V (VIN), RQ.P (OOS plate), RQ.V (OOS VIN),
#   VP.N (owner name), VP.D (owner DOB).
# 4 combo (plate+type): COVERED by QV.P (CommSys routes by LicensePlateTypeCode value).
# 4V combo (VIN): COVERED by QV.V.
# VP combos have cross-entity fields (Name, BirthDate, AddressCity, AddressStreetNumber on Vehicle form).
# VehicleIdentificationNumber max=30 (per eSUN metadata).
# BirthDate max=10 for VP -> yyyy-MM-dd.
# LIMITATION #30: No State initialValue (in-state QV vs OOS RQ routing).
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCity';           size = 13; sourceField = @('addressCity');           targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'AddressStreetNumber';   size = 3;  sourceField = @('addressStreetNumber');   targetField = 'AddressStreetNumber' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 10; sourceField = @('vehBirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode';       size = 1;  sourceField = @('caRequestPurposeCode');       targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('vehNameLast','vehNameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 30; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        # RQ.P (OOS Plate) -- most specific first (5 set + State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber','licensePlateTypeCode','licensePlateYear','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # RQ.V (OOS VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber','registrationState'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # VP.D (Owner DOB) -- 3 set fields
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehNameLast','vehNameFirst','vehBirthDate'); any = @('addressCity','addressStreetNumber') }
            primaryFieldReference = 'BirthDate'
            keyReference          = 'VP.D'
            state                 = 'In/Out'
        }
        # VP.N (Owner Name) -- 2 set + any
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehNameLast','vehNameFirst'); any = @('addressCity','addressStreetNumber') }
            primaryFieldReference = 'Name'
            keyReference          = 'VP.N'
            state                 = 'In/Out'
        }
        # QV.V (in-state VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','vehicleIdentificationNumber'); any = @('vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        # QV.P (in-state Plate) -- least specific
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','licensePlateNumber'); any = @('licensePlateTypeCode','licensePlateYear','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- QV.P/QV.V (in-state), RQ.P/RQ.V (OOS), VP.N/VP.D (owner search).'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'CA_eSUN_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'CA_eSUN'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

$esunBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $artQuery, $boatQuery, $dlQuery, $dhQuery, $gunQuery, $vehRegQuery)
    description    = "Provider configuration for CA_eSUN v${Version}"
    name           = 'CA_eSUN'
    type           = 'BUNDLE'
    provider       = 'CA_eSUN'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# CaRequestPurposeCode: visible Inp initialValue='C' on every form.
# No State initialValue on any form (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery fields. No ImageIndicator (not in eSUN metadata).
# State: NO initialValue (LIMITATION #30 -- in-state QV vs OOS RQ)
# PlateType: initialValue='PC', PlateYear: initialValue='2026'
# VIN size=30 (per metadata).
# VP combos: Name, BirthDate, AddressCity, AddressStreetNumber on Vehicle entity.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_VEH_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = '2026' } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '30' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6','6'); fields = @(
                @{ id = 'vehNameFirst_Input'; node = Inp 'vehNameFirst' 'Owner First Name' '30' 'ROW_VEH_5' }
                @{ id = 'vehNameLast_Input';  node = Inp 'vehNameLast'  'Owner Last Name'  '30' 'ROW_VEH_5' }
            )}
            @{ id = 'ROW_VEH_6'; cols = @('4','4','4'); fields = @(
                @{ id = 'vehBirthDate_Input';        node = Dt  'vehBirthDate'        'Owner DOB'            'ROW_VEH_6' }
                @{ id = 'addressCity_Input';          node = Inp 'addressCity'          'City'          '13'  'ROW_VEH_6' }
                @{ id = 'addressStreetNumber_Input';  node = Inp 'addressStreetNumber'  'Street Number' '3'   'ROW_VEH_6' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (QV plate/VIN + RQ OOS + VP owner search).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# Serves 2 QIDMs: DL + DH (co-fire with DH-suffix fieldIds).
# State: NO initialValue (LIMITATION #30 -- L1 vs DQ routing)
# DH fields: operatorLicenseNumberDH, nameFirstDH, nameLastDH, birthDateDH, sexCodeDH
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_PER_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                          'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }           'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_DH_1'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = InpH 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH_1' }
            )}
            @{ id = 'ROW_PER_DH_2'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'nameFirstDH_Input'; node = InpH 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH_2' }
                @{ id = 'nameLastDH_Input';  node = InpH 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH_2' }
            )}
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'birthDateDH_Input'; node = DtH  'birthDateDH' 'Date of Birth (DH)' 'ROW_PER_DH_3' }
                @{ id = 'sexCodeDH_Input';   node = SelH 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (L1.N/L1.O/DQ.N/DQ.O) + DH (L1.N/L1.O/KQ.N/KQ.O). DH-suffix fieldIds for co-fire.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card
# QGB serial + QGH name-based search.
# QGH has cross-entity fields: Name, BirthDate, Age on Firearm entity.
# Gun BirthDate max=8 (MMddyyyy).
# RelatedSearchHitIndicator: hidden, not user-editable.
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '14' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_GUN_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunTypeCode_Input'; node = Sel 'gunTypeCode' 'Type'    @{ codeTypeCategory = 'NCIC_FIREARM_TYPE';    codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('6','6'); fields = @(
                @{ id = 'gunNameFirst_Input'; node = Inp 'gunNameFirst' 'First Name' '30' 'ROW_GUN_3' }
                @{ id = 'gunNameLast_Input';  node = Inp 'gunNameLast'  'Last Name'  '30' 'ROW_GUN_3' }
            )}
            @{ id = 'ROW_GUN_4'; cols = @('6','6'); fields = @(
                @{ id = 'gunBirthDate_Input'; node = Dt  'gunBirthDate' 'Date of Birth' 'ROW_GUN_4' }
                @{ id = 'gunAge_Input';       node = Inp 'gunAge'       'Age'       '2' 'ROW_GUN_4' }
            )}
            @{ id = 'ROW_GUN_5'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'relatedSearchHitIndicator_Input'; node = InpH 'relatedSearchHitIndicator' 'Related Search Hit' '1' 'ROW_GUN_5' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QGB (serial), QGH (name). Historical+NCIC firearm inquiry.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA serial only)
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC gives empty dropdown).
# ArticleCategory: text input (1 char).
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'  '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode'    'Article Type'   @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_ART_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'articleBrand_Input';        node = Inp 'articleBrand'       'Brand'          '6' 'ROW_ART_2' }
                @{ id = 'articleCategory_Input';     node = Inp 'articleCategory'    'Category'       '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial). Property inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (BQ.H hull, BQ.R reg)
# State: NO initialValue (for OOS routing).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState'  'State (leave blank for CA)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
                @{ id = 'caRequestPurposeCode_Input'; node = Inp 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_BOA_1' @{ initialValue = 'C' } }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number' '20' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ.H (hull), BQ.R (reg). State for OOS.'
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
    description    = 'Entity form configurations for CA_eSUN'
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
# BUNDLE 3: RMS (from HIDLE, with CA_eSUN patches)
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
    bundles = @($entitiesBundle, $esunBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built CA_eSUN_BASE.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
