# build_tn_ties.ps1  -- TN_TIES v1.x BASE (6 basic queries)
# Builds TN_TIES_BASE.json from source\TN_TIES.xml (metadata v31) + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_tn_ties.ps1
#
# INPUTS:
#   source\TN_TIES.xml       -- XML metadata (12 transactions, 49 combos) [AUTHORITATIVE]
#   source\TN_TIES_DEVDOC.txt -- CommSys devdoc [CROSS-CHECK]
#   source\HIDLE.json         -- RMS structural template
#
# METADATA SUMMARY -- 6 BASIC QUERIES (28 combos):
#   VehicleRegistrationQuery v22  -- 13 combos: RQ01, RV01, RQ03, RV03, RQ06, RQ05, RQ07, RV, RQ.P, RQ.V, QV.V, QV.P, QV.D
#   DriverLicenseQuery v15        -- 6 combos: DQ01, DQ02, DQ06, DQ.N, DQ.O, QWA
#   DriverHistoryQuery v9         -- 3 combos: KQ.N, KQ.O, DQ05
#   GunQuery v6                   -- 1 combo: QG
#   ArticleSingleQuery v6         -- 1 combo: QA
#   BoatQuery v12                 -- 4 combos: BB.H, BB.R, QB.H, QB.R
#
# REMOVED (6 non-basic queries):
#   AOSHazardousMaterialsQuery v5 -- 1 combo: MQ
#   ProtectionOrderQuery v9       -- 4 combos: QPO.N, QPO.LP, QPO.VIN, QPO.NIC
#   SexOffenderQuery v6           -- 1 combo: QXS
#   TnTiesBoatQuery v11           -- 4 combos: BB.R2, BB.H2, BB.NM, QWA
#   TnTiesDriverLicenseQuery v16  -- 10 combos: DQ04, DQ02, DQ01, DQ06, DNQ, DQ.N2, DQ.O2, QWA.D, QWA.S, QWA.O
#   WMPIWantedPersonQuery v2      -- 1 combo: QWA
#
# TN-SPECIFIC:
#   NO CaRequestPurposeCode (Tennessee, not California).
#   DriverHistoryQuery has PurposeCode (Mandatory) + Attention (Mandatory) fields.
#   ImageIndicator present in DL metadata.
#
# STATE HANDLING:
#   LIMITATION #30 applies: TN has separate in-state vs OOS keyRefs (RQ01 vs RQ, DQ01 vs DQ, etc.)
#   Do NOT set initialValue on State fields. Officer selects state to route query.
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 configs, 28 combos):
#   VehicleRegistrationQuery       RQ01 (IS Plate), RV01 (IS Plate), RQ03 (IS VIN), RV03 (IS VIN),
#                                  RQ06 (Handicap), RQ05 (Dealer), RQ07 (Temp), RV (OOS Plate),
#                                  RQ.P (OOS Plate), RQ.V (OOS VIN), QV.V (NCIC VIN), QV.P (NCIC Plate), QV.D (NCIC Dealer)
#   DriverLicenseQuery             DQ01 (IS OLN), DQ02 (IS Name), DQ06 (IS SSN), DQ.N (OOS Name), DQ.O (OOS OLN), QWA (NCIC Name)
#   DriverHistoryQuery             KQ.N (Name+DOB+Sex), KQ.O (OLN), DQ05 (IS OLN)
#   GunQuery                       QG (Serial)
#   ArticleSingleQuery             QA (Serial+Type)
#   BoatQuery                      BB.H (IS Hull), BB.R (IS Reg), QB.H (NCIC Hull), QB.R (NCIC Reg)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- PlateNumber + VIN + State + PlateType + PlateYear + Make + Year
#               + DealerPlate + HandicapPlacard + TempPlate + InquiryType
#   Person   -- OLN + Name + DOB + Sex + State + SSN + ImageIndicator + Race + InquiryType
#               + DH fields: Attention, PurposeCode, OperatorLicenseNumberDH, NameDH, etc.
#   Firearm  -- Serial + Make + Caliber
#   Article  -- Serial + TypeCode
#   Boat     -- Reg + Hull + State + InquiryType
#
# PERSON CO-FIRE (2 QIDMs share Person entity):
#   DL + DH co-fire by design (standard police workflow).
#   DH uses DH-suffix fieldIds to isolate from DL.
#
# DATE FORMAT: yyyyMMdd (TN metadata: Date type, size 8)
# NAME FORMAT: Composite (FormatStringRuleHandler with ', ' separator -- Last,First)

$ErrorActionPreference = "Stop"
$Version = '1.1'
$DIR     = (Resolve-Path "$PSScriptRoot\..").Path
$OUT     = "$DIR\TN_TIES_BASE.json"
$OUTREAD = "$DIR\TN_TIES_BASE_READABLE.json"
$VEROUT  = "$DIR\phases\base\TN_TIES_v${Version}_$(Get-Date -Format 'yyyy-MM-dd').json"
$hidle   = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

New-Item -ItemType Directory -Force -Path (Split-Path $VEROUT) | Out-Null

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

function BuildLayout($cardDefs) {
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
    $def = BuildLayout $cardDefs
    $cad = AddCadNodes $def
    $fr  = AddFrNodes $def
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1 (in output order = ENTITIES): Built after provider QIDMs
# BUNDLE 2: TN_TIES PROVIDER
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
# 2d. VehicleRegistrationQuery
# XML v22: 13 combos. In-state (RQ01/RV01 plate, RQ03/RV03 VIN), Specialty (RQ05 Dealer,
# RQ06 Handicap, RQ07 Temp), OOS (RV/RQ plate+type+year+state, RQ VIN+state),
# NCIC (QV VIN, QV plate, QV dealer).
# LIMITATION #30: No State initialValue -- in-state (RQ01/RV01/RQ03/RV03) vs OOS (RQ/RV) routing.
# Duplicate keyRefs: RQ x2 (plate vs VIN) -> RQ.P/RQ.V; QV x3 (VIN/plate/dealer) -> QV.V/QV.P/QV.D
# InquiryTypeIndicator: 1=Reg only, 2=Hot files only, 3=Both (default)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DealerLicensePlateNumber';     size = 10; sourceField = @('dealerLicensePlateNumber');     targetField = 'DealerLicensePlateNumber' }
        [PSCustomObject]@{ name = 'HandicapPlacardNumber';        size = 10; sourceField = @('handicapPlacardNumber');        targetField = 'HandicapPlacardNumber' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator';         size = 1;  sourceField = @('inquiryTypeIndicator');         targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';           size = 10; sourceField = @('licensePlateNumber');           targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('licensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('licensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                        size = 2;  sourceField = @('registrationState');            targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TemporaryLicensePlateNumber';  size = 10; sourceField = @('temporaryLicensePlateNumber');  targetField = 'TemporaryLicensePlateNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('vehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 4;  sourceField = @('vehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # OOS Plate (most specific -- requires State+PlateType+PlateYear)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode','registrationState'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber','licensePlateYear','licensePlateTypeCode','registrationState'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ.P'
            state                 = 'In/Out'
        }
        # OOS VIN (requires State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationState','vehicleIdentificationNumber'); any = @('inquiryTypeIndicator','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ.V'
            state                 = 'In/Out'
        }
        # In-state Plate (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ01'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RV01'
            state                 = 'In/Out'
        }
        # In-state VIN (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ03'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RV03'
            state                 = 'In/Out'
        }
        # Specialty searches
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('handicapPlacardNumber'); any = @() }
            primaryFieldReference = 'HandicapPlacardNumber'
            keyReference          = 'RQ06'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('dealerLicensePlateNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'RQ05'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('temporaryLicensePlateNumber'); any = @() }
            primaryFieldReference = 'TemporaryLicensePlateNumber'
            keyReference          = 'RQ07'
            state                 = 'In/Out'
        }
        # NCIC queries (QV)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleIdentificationNumber'); any = @('inquiryTypeIndicator','vehicleMakeCode','vehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV.V'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('licensePlateNumber'); any = @('inquiryTypeIndicator','licensePlateTypeCode') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV.P'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('dealerLicensePlateNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'DealerLicensePlateNumber'
            keyReference          = 'QV.D'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- RQ01/RV01 (IS plate), RQ03/RV03 (IS VIN), RV/RQ (OOS), QV (NCIC), RQ05/06/07 (specialty).'
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
# 2e. DriverLicenseQuery
# XML v15: 6 combos. DQ01 (IS OLN), DQ02 (IS Name+DOB+Sex), DQ06 (IS SSN),
# DQ (OOS Name+DOB+Sex+State), DQ (OOS OLN+State), QWA (NCIC Name+DOB+Sex).
# Duplicate keyRefs: DQ x2 -> DQ.N/DQ.O
# ImageIndicator in any[] on several combos.
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('expandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('imageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator';      size = 1;  sourceField = @('inquiryTypeIndicator');      targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';     size = 20; sourceField = @('operatorLicenseNumber');     targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('raceCode');                  targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('sexCode');                   targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';      size = 20; sourceField = @('socialSecurityNumber');      targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                     size = 2;  sourceField = @('registrationState');         targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # OOS Name+DOB+Sex+State (most specific)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode','registrationState'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ.N'
            state                 = 'In/Out'
        }
        # OOS OLN+State
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber','registrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ.O'
            state                 = 'In/Out'
        }
        # NCIC Name (QWA -- broadest name search with expanded search options)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode'); any = @('expandedNameSearchCode','imageIndicator','inquiryTypeIndicator','raceCode','relatedHitSearchIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'QWA'
            state                 = 'In/Out'
        }
        # In-state OLN (no State required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumber'); any = @('expandedNameSearchCode','imageIndicator','inquiryTypeIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ01'
            state                 = 'In/Out'
        }
        # In-state Name+DOB+Sex
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','sexCode'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ02'
            state                 = 'In/Out'
        }
        # In-state SSN
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('socialSecurityNumber'); any = @('expandedNameSearchCode','imageIndicator','inquiryTypeIndicator','relatedHitSearchIndicator') }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'DQ06'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ01 (IS OLN), DQ02 (IS Name), DQ06 (IS SSN), DQ.N/DQ.O (OOS), QWA (NCIC).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 2f. DriverHistoryQuery
# XML v9: 3 combos. KQ (Name+DOB+Sex, OLN -- both Nlets OOS), DQ05 (IS OLN).
# PurposeCode (Mandatory) + Attention (Mandatory) on Name+OLN combos.
# DH-suffix fieldIds for isolation from DL.
# Duplicate keyRefs: KQ x2 -> KQ.N/KQ.O
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
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('sexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('registrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ Name+DOB+Sex (OOS via Nlets -- Attention+PurposeCode mandatory)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLastDH','nameFirstDH','birthDateDH','sexCodeDH','purposeCode'); any = @('registrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ.N'
            state                 = 'In/Out'
        }
        # KQ OLN (OOS via Nlets -- Attention+PurposeCode mandatory)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('operatorLicenseNumberDH','purposeCode'); any = @('registrationState') }
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
    description     = 'DriverHistoryQuery -- KQ.N (Name+DOB+Sex OOS), KQ.O (OLN OOS), DQ05 (IS OLN). Attention auto-filled.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'TN_TIES_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'TN_TIES'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 2g. GunQuery
# XML v6: 1 combo QG (serial, optional caliber+make).
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
    description     = 'GunQuery -- QG (serial). Optional caliber and make.'
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
# 2h. ArticleSingleQuery
# XML v6: 1 combo QA (serial mandatory, type conditional).
# ArticleTypeCode: try codeTypeSource='NCIC' (not CA provider)
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
    description     = 'ArticleSingleQuery -- QA (serial + type). NCIC article inquiry.'
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
# 2i. BoatQuery
# XML v12: 4 combos. BB (IS Hull/Reg + State optional), QB (NCIC Hull/Reg, no State).
# Duplicate keyRefs: BB x2 -> BB.H/BB.R; QB x2 -> QB.H/QB.R
# InquiryTypeIndicator in any[].
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';    size = 20; sourceField = @('boatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'InquiryTypeIndicator'; size = 1; sourceField = @('inquiryTypeIndicator'); targetField = 'InquiryTypeIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber';  size = 8;  sourceField = @('registrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State';               size = 2;  sourceField = @('registrationState');   targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BB In-state with optional State
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('inquiryTypeIndicator','registrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('inquiryTypeIndicator','registrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BB.R'
            state                 = 'In/Out'
        }
        # QB NCIC (no State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('boatHullIdNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB.H'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('registrationNumber'); any = @('inquiryTypeIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QB.R'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BB.H/BB.R (IS hull/reg + State), QB.H/QB.R (NCIC hull/reg).'
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
# BUNDLE 1: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1 BASE: single card per entity.
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VehicleRegistrationQuery fields. Specialty plates + InquiryType.
# State: NO initialValue (LIMITATION #30 -- RQ01/RV01 vs RQ/RV routing)
# PlateType: PC default. PlateYear: 2026.
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'licensePlateNumber_Input';  node = Inp 'licensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'registrationState_Input';   node = Sel 'registrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
                @{ id = 'inquiryTypeIndicator_Veh';  node = Inp 'inquiryTypeIndicator' 'Inquiry Type (1/2/3)' '1' 'ROW_VEH_1' }
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
            @{ id = 'ROW_VEH_5'; cols = @('4','4','4'); fields = @(
                @{ id = 'dealerLicensePlateNumber_Input';    node = Inp 'dealerLicensePlateNumber'    'Dealer Plate'    '10' 'ROW_VEH_5' }
                @{ id = 'handicapPlacardNumber_Input';       node = Inp 'handicapPlacardNumber'       'Handicap Placard' '10' 'ROW_VEH_5' }
                @{ id = 'temporaryLicensePlateNumber_Input'; node = Inp 'temporaryLicensePlateNumber' 'Temp Plate'      '10' 'ROW_VEH_5' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- VehicleRegistrationQuery (IS plate/VIN, OOS, NCIC, specialty).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# Serves 2 QIDMs: DL + DH (basic queries only).
# State: NO initialValue (LIMITATION #30).
# ImageIndicator: Y for person (DL metadata).
# DH uses DH-suffix fieldIds for isolation.
# REMOVED: TnTiesDL address fields, ProtectionOrder/SexOffender/WMPI fields.
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'operatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'registrationState_Input';     node = Sel 'registrationState' 'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'socialSecurityNumber_Input';  node = Inp 'socialSecurityNumber' 'SSN' '20' 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_PER_2' }
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                       'ROW_PER_3' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }        'ROW_PER_3' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' }       'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'imageIndicator_Input';            node = Sel 'imageIndicator' 'Image (Y/N)' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_4' }
                @{ id = 'expandedNameSearchCode_Input';    node = Inp 'expandedNameSearchCode'    'Exp Name Search' '1' 'ROW_PER_4' }
                @{ id = 'relatedHitSearchIndicator_Input'; node = Inp 'relatedHitSearchIndicator' 'Related Hit'     '1' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('6'); fields = @(
                @{ id = 'inquiryTypeIndicator_Per';        node = Inp 'inquiryTypeIndicator' 'Inquiry Type (1/2/3)' '1' 'ROW_PER_5' }
            )}
            # DH-specific fields
            @{ id = 'ROW_PER_DH1'; cols = @('6','6'); fields = @(
                @{ id = 'operatorLicenseNumberDH_Input'; node = Inp 'operatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_DH1' }
                @{ id = 'purposeCode_Input';             node = Inp 'purposeCode'             'Purpose Code (DH)'   '1' 'ROW_PER_DH1' }
            )}
            @{ id = 'ROW_PER_DH2'; cols = @('4','4','4'); fields = @(
                @{ id = 'nameLastDH_Input';  node = Inp 'nameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_DH2' }
                @{ id = 'nameFirstDH_Input'; node = Inp 'nameFirstDH' 'First Name (DH)' '30' 'ROW_PER_DH2' }
                @{ id = 'birthDateDH_Input'; node = Dt  'birthDateDH' 'DOB (DH)'            'ROW_PER_DH2' }
            )}
            @{ id = 'ROW_PER_DH3'; cols = @('6'); fields = @(
                @{ id = 'sexCodeDH_Input'; node = Sel 'sexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL + DH (basic queries only).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG serial only)
# No ImageIndicator in GunQuery metadata.
# =====================================================================
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('12'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'firearmMake_Input'; node = Sel 'firearmMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunCaliber_Input';  node = Sel 'gunCaliber'  'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG (serial). Optional make and caliber.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card
# ArticleSingleQuery fields only (UnitedNationsNumber removed -- AOS only).
# ArticleTypeCode: codeTypeSource='CA_CLETS' (NCIC gives empty dropdown)
# =====================================================================
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'serialNumber_Art_Input';   node = Inp 'serialNumber'   'Serial Number'  '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';     node = Sel 'articleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA (serial+type). NCIC article inquiry.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# BoatQuery fields only (TnTiesBoat Name+DOB owner search removed).
# State: NO initialValue.
# =====================================================================
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationNumber_Input'; node = Inp 'registrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'boatHullIdNumber_Input';   node = Inp 'boatHullIdNumber'   'Hull ID Number'      '20' 'ROW_BOA_1' }
                @{ id = 'registrationState_Boa';    node = Sel 'registrationState'  'State (leave blank for TN)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6'); fields = @(
                @{ id = 'inquiryTypeIndicator_Boa'; node = Inp 'inquiryTypeIndicator' 'Inquiry Type (1/2/3)' '1' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat query -- BoatQuery (hull/reg). IS + NCIC.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

# =====================================================================
# ASSEMBLE BUNDLES
# =====================================================================

$entityConfigs = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
$providerConfigs = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)

$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
if (-not $rmsBundle) {
    $rmsBundle = $hidle.bundles | Where-Object { $_.name -notin @('TN_TIES','ENTITIES') } | Select-Object -First 1
}

$final = [PSCustomObject]@{
    bundles = @(
        [PSCustomObject]@{
            name           = 'ENTITIES'
            type           = 'BUNDLE'
            description    = 'Entity form configurations for TN_TIES'
            order          = [PSCustomObject]@{
                default         = @('Vehicle','Person','Firearm','Article','Boat')
                CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
                FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
            }
            configurations = $entityConfigs
            provider       = 'MARK43'
        }
        [PSCustomObject]@{
            name           = 'TN_TIES'
            type           = 'BUNDLE'
            description    = "Provider configuration for TN_TIES v${Version}"
            configurations = $providerConfigs
            provider       = 'TN_TIES'
        }
        $rmsBundle
    )
}

# =====================================================================
# RMS PATCHES (Patch 1, 3, 6, 7, 8 -- standard for all providers)
# =====================================================================

$rmsBundleRef = $final.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
$rmsVehicleQidm = $rmsBundleRef.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Vehicle' } | Select-Object -First 1
$rmsPersonQidm  = $rmsBundleRef.configurations | Where-Object { $_.query -eq 'Person' } | Select-Object -First 1

# Patch 1: add RegistrationState to RMS Vehicle licensePlateIn combination any[]
# NOTE: RMS HIDLE uses PascalCase attribute names (RegistrationState, not registrationState)
$plateInCombo = $rmsVehicleQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
if ($plateInCombo) {
    $plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'
}

# Patch 3: add RegistrationState attr to RMS Person QIDM + to all person combo any[]
# NOTE: RMS HIDLE uses PascalCase. The sourceField points to the form fieldId (camelCase registrationState).
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'RegistrationState'
    sourceField    = @('registrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'registrationState'
}

# Patch 6: RMS CLEANUP -- remove unused HIDLE fields
# Vehicle: remove OOS dual-field plate + Owner search (no form fields for these)
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehicleQidm.attributes = @($rmsVehicleQidm.attributes | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehicleQidm.combinations = @($rmsVehicleQidm.combinations | Where-Object {
    $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName')
})
foreach ($combo in $rmsVehicleQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

# Person: remove OOS-suffixed attrs + combos (TN uses DH-suffix, not OOS-suffix)
# Keep socialSecurityNumber (TN uses SSN on DL)
$deadPerAttrs = @('firstNameOOS','lastNameOOS','dateOfBirthOOS','licenseNumberOOS','sexOOS')
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS',
        'firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})

# Patch 7: RMS autoSelect=true on all RMS QIDMs
foreach ($cfg in $rmsBundleRef.configurations) {
    if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
        $cfg | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
    }
}

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
    'SocialSecurityNumber'        = 'socialSecurityNumber'
}
foreach ($cfg in $rmsBundleRef.configurations) {
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
# OUTPUT
# =====================================================================
$json = $final | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $final | ConvertTo-Json -Depth 100

[System.IO.File]::WriteAllText($OUT,     $json,         (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         (New-Object System.Text.UTF8Encoding $false))

Write-Host "Built TN_TIES_BASE.json v${Version}" -ForegroundColor Green
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
