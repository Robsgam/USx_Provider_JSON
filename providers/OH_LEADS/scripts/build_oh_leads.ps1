# build_oh_leads.ps1  -- OH_LEADS v1.x BASE
# Builds OH_LEADS_BASE.json from source\OH_LEADS.xml metadata + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_oh_leads.ps1 -Version X.X -Phase base
#
# INPUTS:
#   source\OH_LEADS.xml   -- XML metadata [AUTHORITATIVE]
#   source\OH_LEADS.pdf   -- CommSys devdoc [CROSS-CHECK]
#   source\HIDLE.json     -- RMS structural template
#
# METADATA SUMMARY (OH_LEADS v1):
#   ArticleSingleQuery    -- 2 combos in XML, duplicate keyRef QA -> QA.S (serial), QA.N (NCIC#)
#   BoatQuery             -- 4 combos in XML, duplicate keyRefs BQ/QB -> BQ.R, BQ.H, QB.R, QB.H
#   DriverHistoryQuery    -- 3 combos, duplicate keyRef KQ -> KQ.O (OLN), KQ.N (Name) + BMVIMS
#   DriverLicenseQuery    -- 7 combos in XML, collapsed to 4: DL (in-state OLN), DQ.O (OOS OLN), DN (in-state Name), DQ.N (OOS Name)
#                            BMVIMS(OLN), BMVIMS(SSN), QWA(Name) -- deferred (not basic queries)
#   GunQuery              -- 1 combo (QG serial)
#   VehicleRegistrationQuery -- 9 combos: ATDP, RP, RQ.P, QV.P, RV, RQ.V, QV.V, RS, RN
#
# OH_LEADS-SPECIFIC:
#   NO CaRequestPurposeCode  -- Ohio, not California.
#   Date format: MMddyyyy    -- DL/DH BirthDate max=8.
#   No State initialValue    -- LIMITATION #30: separate in-state (DL/RP/RV) vs OOS (DQ/RQ) keyRefs.
#   Sex: NIBRS pattern (attributeTypeId='SEX', codeTypeProvider='NIBRS')
#   State: NCIC pattern (attributeTypeId='STATE', codeTypeProvider='NCIC')
#   ImageIndicator in: ArticleSingleQuery, BoatQuery, DriverLicenseQuery (Y default)
#   RelatedHitSearchIndicator in: Article, Boat, Gun (Y-only flag, FormInput maxLength=1)
#   Name: composite FormatStringRuleHandler
#   DL+DH co-fire: DH uses DH-suffix fieldIds, autoSelect=true
#   VehReg has owner search combos (RS=SSN, RN=Name) -- person fields on Vehicle entity
#   DealerPlateType field for ATDP combo
#   PlateType=PC (default), PlateYear=2026
#   Attention on DH: CommsysGetLastNameFirstNameInitialRuleHandler
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 23 combos):
#   ArticleSingleQuery         QA.S (Serial), QA.N (NCIC#)
#   BoatQuery                  BQ.R (Reg in-state), BQ.H (Hull in-state), QB.R (Reg NCIC), QB.H (Hull NCIC)
#   DriverHistoryQuery         KQ.O (OLN), KQ.N (Name), BMVIMS (BMV IMS)
#   DriverLicenseQuery         DL (in-state OLN), DQ.O (OOS OLN), DN (in-state Name), DQ.N (OOS Name)
#   GunQuery                   QG (Serial)
#   VehicleRegistrationQuery   ATDP (Dealer), RP (in-state Plate), RQ.P (OOS Plate), QV.P (NCIC Plate),
#                              RV (in-state VIN), RQ.V (OOS VIN), QV.V (NCIC VIN), RS (SSN), RN (Name)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- Plate + VIN + State + PlateType + PlateYear + VehMake + VehYear + DealerPlateType + Name + SSN + County
#   Person   -- OLN + Name + DOB + Sex + State + ImageIndicator
#   Firearm  -- Serial + Make + Caliber + RelatedHitSearchIndicator
#   Article  -- Serial + ArticleType + NCICNumber + ImageIndicator + RelatedHitSearchIndicator
#   Boat     -- Hull + Reg# + State + ImageIndicator + RelatedHitSearchIndicator
#
# PERSON (2 QIDMs co-fire by design):
#   DL + DH share Person entity/form.
#   Both have autoSelect=true. Officer can uncheck to disable specific queries.
#   DH uses DH-suffix fieldIds: operatorLicenseNumberDH, nameFirstDH, nameLastDH, birthDateDH, sexCodeDH

param(
    [string]$Version = "1.0",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\OH_LEADS_BASE.json"
$OUTREAD  = "$DIR\OH_LEADS_BASE_READABLE.json"
$VEROUT   = "$PHASEDIR\OH_LEADS_v${Version}_${DATE}.json"

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
# BUNDLE 1: OH_LEADS PROVIDER
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
# 1d. VehicleRegistrationQuery
# XML: 9 combos: ATDP, RP, RQ(plate), QV(plate), RV, RS, RN, RQ(VIN), QV(VIN)
# Duplicate keyRefs: RQ -> RQ.P, RQ.V; QV -> QV.P, QV.V
# Owner combos: RS (SSN), RN (Name) -- person fields on Vehicle entity.
# DealerPlateType for ATDP combo.
# LIMITATION #30: No State initialValue -- in-state (RP/RV) vs OOS (RQ) routing.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'AddressCounty';               size = 4;  sourceField = @('addressCounty');               targetField = 'AddressCounty' }
        [PSCustomObject]@{ name = 'DealerPlateType';             size = 1;  sourceField = @('dealerPlateType');              targetField = 'DealerPlateType' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('ownerLastName','ownerFirstName'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';        size = 9;  sourceField = @('ownerSocialSecurityNumber');    targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # Most-specific first (LIMITATION #3: first matching combo fires)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode','dealerPlateType'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ATDP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationState','licensePlateNumber','licensePlateTypeCode','licensePlateYear'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateTypeCode'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RP'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('registrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber','vehicleMakeCode','vehicleYear'); any = @('registrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ownerSocialSecurityNumber'); any = @() }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'RS'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ownerLastName','ownerFirstName'); any = @('addressCounty') }
            primaryFieldReference = 'Name'
            keyReference          = 'RN'
            state                 = 'In/Out'
        }
    )
    description        = 'VehicleRegistrationQuery -- ATDP (dealer), RP (plate), RQ.P (OOS plate), QV.P (NCIC plate), RV (VIN), RQ.V (OOS VIN), QV.V (NCIC VIN), RS (SSN), RN (Name).'
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
# 1e. DriverLicenseQuery
# XML: 7 combos. Build 4 basic: DL (in-state OLN), DQ.O (OOS OLN),
#   DN (in-state Name), DQ.N (OOS Name).
# Duplicate keyRef DQ -> DQ.O, DQ.N. QWA and BMVIMS deferred.
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
        # Most-specific first: DQ.O requires State + OLN, DQ.N requires State + Name + DOB + Sex
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('imageIndicator','registrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCode','birthDate','nameLast','nameFirst'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst'); any = @('birthDate') }
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
# 1f. DriverHistoryQuery
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
            sourceField = @('nameLastDH','nameFirstDH')
            targetField = 'Attention'
        }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size = 8; sourceField = @('birthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLastDH','nameFirstDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('operatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('purposeCodeDH'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'ReasonCode'; size = 30; sourceField = @('reasonCodeDH'); targetField = 'ReasonCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('sexCodeDH'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ.O: OLN search (most common)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('nameLastDH','nameFirstDH','purposeCodeDH','registrationStateDH') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ.O'
            state                 = 'In/Out'
        }
        # KQ.N: Name search
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('sexCodeDH','birthDateDH','nameLastDH','nameFirstDH'); any = @('purposeCodeDH','registrationStateDH') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # BMVIMS: BMV IMS image lookup by OLN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH'); any = @('nameLastDH','nameFirstDH','reasonCodeDH') }
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
# 1g. GunQuery
# XML: 1 combo (QG serial).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                  size = 4;  sourceField = @('gunCaliber');            targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                     size = 23; sourceField = @('firearmMake');           targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';             size = 20; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';   size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('firearmMake','gunCaliber','relatedHitSearchIndicator') }
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
# 1h. ArticleSingleQuery
# XML: 2 combos, BOTH keyRef=QA. Invented: QA.S (serial), QA.N (NCIC#).
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('serialNumber');                 targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('articleTypeCode');              targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicatorArticle');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 9;  sourceField = @('ncicNumber');                   targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicatorArticle'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('articleTypeCode','serialNumber'); any = @('imageIndicatorArticle','relatedHitSearchIndicatorArticle') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA.S'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ncicNumber'); any = @('imageIndicatorArticle','relatedHitSearchIndicatorArticle') }
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
# 1i. BoatQuery
# XML: 4 combos, duplicate keyRefs BQ(x2), QB(x2).
# Invented: BQ.R (reg in-state), BQ.H (hull in-state), QB.R (reg NCIC), QB.H (hull NCIC).
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('boatHullIdNumber');               targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicatorBoat');             targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('registrationNumber');             targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicatorBoat'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('registrationStateBoat'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ.R: in-state registration lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('registrationStateBoat') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ.R'
            state                 = 'In/Out'
        }
        # BQ.H: in-state hull lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('registrationStateBoat') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQ.H'
            state                 = 'In/Out'
        }
        # QB.R: NCIC registration lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('boatHullIdNumber','imageIndicatorBoat','relatedHitSearchIndicatorBoat') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
        # QB.H: NCIC hull lookup
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('imageIndicatorBoat','relatedHitSearchIndicatorBoat') }
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
    description    = "Provider configuration for OH_LEADS v${Version}"
    name           = 'OH_LEADS'
    type           = 'BUNDLE'
    provider       = 'OH_LEADS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# No State initialValue on any form (LIMITATION #30).
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery: plate, VIN, dealer plate, owner name/SSN, county.
# State: NO initialValue (LIMITATION #30 -- in-state RP/RV vs OOS RQ routing)
# PlateType: initialValue=PC. PlateYear: initialValue=2026.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateNumber_Input';   node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';    node = Sel 'registrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'licensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'licensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = '2026' } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'vehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
                @{ id = 'dealerPlateType_Input';             node = Inp 'dealerPlateType' 'Dealer Plate Type' '1' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('6','6'); fields = @(
                @{ id = 'vehicleMakeCode_Input'; node = Inp 'vehicleMakeCode' 'Vehicle Make' '4' 'ROW_VEH_4' }
                @{ id = 'vehicleYear_Input';     node = Inp 'vehicleYear'     'Vehicle Year' '4' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_5'; cols = @('6','6'); fields = @(
                @{ id = 'ownerFirstName_Input'; node = Inp 'ownerFirstName' 'Owner First Name' '30' 'ROW_VEH_5' }
                @{ id = 'ownerLastName_Input';  node = Inp 'ownerLastName'  'Owner Last Name'  '30' 'ROW_VEH_5' }
            )}
            @{ id = 'ROW_VEH_6'; cols = @('6','6'); fields = @(
                @{ id = 'ownerSocialSecurityNumber_Input'; node = Inp 'ownerSocialSecurityNumber' 'Owner SSN' '9' 'ROW_VEH_6' }
                @{ id = 'addressCounty_Input';             node = Inp 'addressCounty' 'County Code' '4' 'ROW_VEH_6' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (ATDP/RP/RQ/QV plate + RV/RQ.V/QV.V VIN + RS SSN + RN Name).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# Serves 2 QIDMs: DL + DH (co-fire).
# DH uses DH-suffix fieldIds. Both visible on same card.
# State: NO initialValue (LIMITATION #30 -- DL vs DQ / KQ routing)
# ImageIndicator: in DL only, Y default.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State (leave blank for OH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('12'); fields = @(
                @{ id = 'imageIndicator_Input'; node = Sel 'imageIndicator' 'Image Indicator' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_4' }
            )}
            # DH-suffix hidden fields -- mirror DL fields for DH QIDM
            @{ id = 'ROW_PER_DH1'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = InpH 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH1' }
                @{ id = 'registrationStateDH_Input';     node = SelH 'registrationStateDH' 'State (DH)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DH1' }
            )}
            @{ id = 'ROW_PER_DH2'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'nameFirstDH_Input'; node = InpH 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH2' }
                @{ id = 'nameLastDH_Input';  node = InpH 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH2' }
            )}
            @{ id = 'ROW_PER_DH3'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)' 'ROW_PER_DH3' }
                @{ id = 'sexCodeDH_Input';   node = SelH 'sexCodeDH'   'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH3' }
            )}
            @{ id = 'ROW_PER_DH4'; cols = @('6','6'); hidden = $true; fields = @(
                @{ id = 'purposeCodeDH_Input'; node = InpH 'purposeCodeDH' 'Purpose Code (DH)' '1' 'ROW_PER_DH4' }
                @{ id = 'reasonCodeDH_Input';  node = InpH 'reasonCodeDH'  'Reason Code (DH)'  '30' 'ROW_PER_DH4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DL/DQ.O/DN/DQ.N) + DH (KQ.O/KQ.N/BMVIMS). DH-suffix fieldIds.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG serial only)
# =====================================================================
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'firearmMake_Input';  node = Sel 'firearmMake'  'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'gunCaliber_Input';                  node = Sel 'gunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'relatedHitSearchIndicator_Input';   node = Inp 'relatedHitSearchIndicator' 'Related Hit Search' '1' 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial). No GunTypeCode in OH metadata.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleTypeCode: codeTypeSource=NCIC (OH, not CA_CLETS).
# NCICNumber: for QA.N combo.
# ImageIndicator + RelatedHitSearchIndicator in any[].
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Input';       node = Inp 'serialNumber'       'Serial Number'  '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode'    'Article Type'   @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ncicNumber_Input';                       node = Inp 'ncicNumber'                       'NCIC Number'          '9' 'ROW_ART_2' }
                @{ id = 'imageIndicatorArticle_Input';            node = Sel 'imageIndicatorArticle'             'Image Indicator'      @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
            @{ id = 'ROW_ART_3'; cols = @('12'); fields = @(
                @{ id = 'relatedHitSearchIndicatorArticle_Input'; node = Inp 'relatedHitSearchIndicatorArticle'  'Related Hit Search'   '1' 'ROW_ART_3' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA.S (serial+type), QA.N (NCIC#). Property inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card (BQ hull/reg, QB hull/reg)
# State: NO initialValue (LIMITATION #30).
# ImageIndicator + RelatedHitSearchIndicator in QB combos.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'boatHullIdNumber_Input';    node = Inp 'boatHullIdNumber'   'Hull ID Number'       '20' 'ROW_BOA_1' }
                @{ id = 'registrationNumber_Input';  node = Inp 'registrationNumber' 'Registration Number'  '8'  'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'registrationStateBoat_Input';           node = Sel 'registrationStateBoat'            'State (leave blank for OH)'  @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                @{ id = 'imageIndicatorBoat_Input';              node = Sel 'imageIndicatorBoat'               'Image Indicator'     @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_3'; cols = @('12'); fields = @(
                @{ id = 'relatedHitSearchIndicatorBoat_Input';   node = Inp 'relatedHitSearchIndicatorBoat'    'Related Hit Search'  '1'  'ROW_BOA_3' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ.R/BQ.H (in-state), QB.R/QB.H (NCIC). State for in-state routing.'
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
    description    = 'Entity form configurations for OH_LEADS'
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
# BUNDLE 3: RMS (from HIDLE, with OH_LEADS patches)
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
    bundles = @($entitiesBundle, $ohBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built OH_LEADS_BASE.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
