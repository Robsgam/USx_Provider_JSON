# build_hi_hcjdc_ofml.ps1  -- HI_HCJDC_OFML v1.0 BASE
# Builds HI_HCJDC_OFML_BASE.json from source\HI_HCJDC_OFML.xml + HIDLE.json.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_hi_hcjdc_ofml.ps1
#
# INPUTS:
#   source\HI_HCJDC_OFML.xml  -- XML metadata (System HCJDC_OFML v9) [AUTHORITATIVE]
#   source\HI_HCJDC_OFML.pdf  -- CommSys devdoc (Basic Queries + CCH + Expanded) [CROSS-CHECK]
#   source\HIDLE.json          -- RMS structural template + hand-built HI reference
#
# SCOPE: Basic Queries only (6 transactions from PDF/XML):
#   ArticleSingleQuery, BoatQuery, DriverHistoryQuery, DriverLicenseQuery, GunQuery, VehicleRegistrationQuery
#   CCH queries (AQ/FQ/IQ/QH/QR/ZR), SecuritiesStolenQuery (QS), WantedPersonQuery (QW standalone)
#   are NOT in scope for Phase 1. The QW combo inside DriverLicenseQuery IS included (per XML metadata).
#
# XML METADATA NOTES:
#   18 MessageKeys: AQ, BQ, DQ, FQ, IQ, KQ, M55L, M55S, QA, QB, QG, QH, QR, QS, QV, QW, RQ, ZR
#   BoatQuery uses <Choice> elements -- split into separate combos per primary field
#   DriverLicenseQuery has a QW (Wanted Person) combo alongside DQ combos -- included per source authority
#   VehicleRegistrationQuery has 6 combos: M55L/M55S (in-state), RQ (out-state), QV (stolen)
#   State2-5 fields on DL/VehicleReg: NOT implementable (platform has no multi-state mechanism). Excluded.
#
# DUPLICATE keyRef INVENTORY (LIMITATION #21):
#   BoatQuery:               BQ (Boat Reg) + QB (Stolen Boat) -> BQ (Reg), QB (Hull)
#   DriverHistoryQuery:      KQ x2           -> KQN (OLN), KQ (Name)
#   DriverLicenseQuery:      DQ x2 + QW     -> DQN (OLN), DQ (Name), QW (distinct)
#   VehicleRegistrationQuery: RQ x2 + QV x2 + M55L + M55S -> M55L, M55S, RQ, QVP, QVV, RQV (6 distinct)
#   GunQuery:                QG              -> QG (no duplicate)
#   ArticleSingleQuery:      QA              -> QA (no duplicate)
#
# PDF vs XML DISCREPANCIES:
#   BoatQuery:   XML uses <Choice>, PDF shows 2 simple combos -- functionally equivalent after split
#   DL:          XML has QW combo (Wanted Person), PDF Basic Queries does NOT show it -- metadata wins
#   VehicleReg:  XML has QV combos (Stolen Vehicle), PDF has them in Expanded section -- metadata wins
#   VehicleReg:  PDF shows 4 combos, XML has 6 -- extra 2 are QV stolen combos
#   State2-5:    PDF says "submit up to 5 states" on DL/VehicleReg -- not implementable, excluded
#   DH:          XML has State in any[], PDF does not mention State -- metadata wins (include State)
#
# HIDLE.json COMPARISON (hand-built reference):
#   HIDLE uses old split-entity In/Out model (OOS fieldIds). We use Phase 1 NCIC state pattern.
#   HIDLE drops QV stolen combos and QW wanted person combo. We include them per metadata.
#   HIDLE GunMake size=10 matches XML. VehicleMakeCode size=4 is wrong (XML=20). We use 20.
#   HIDLE Name format: "First Last Middle Suffix" (4 components, space separators). We follow same format.
#   HIDLE queryLabels: "NCIC", "DMV", "Driver License", "Driver History". We use standard labels.
#   HIDLE DL/DH: queriesToDeselect bidirectional. We replicate this pattern.
#
# STATE HANDLING (Phase 1 NCIC pattern):
#   Single visible Sel 'RegistrationState' (attributeTypeId=STATE, initialValue=HI)
#   CommSys State attr: sourceField=RegistrationState, codeTypeProvider=NCIC
#   RMS: useAttributeId=true + AttributeArrayWrapperRuleHandler (HIDLE default)
#   Note: NCIC pattern unconfirmed for HI -- test ST-1 on first import.
#
# SEX HANDLING (NIBRS reverse-lookup):
#   Form: Sel 'SexCode' attributeTypeId=SEX + codeTypeProvider=NIBRS
#   CommSys: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
#   RMS: HIDLE default (useAttributeId=true, NO AttributeArrayWrapperRuleHandler)
#
# DATE FORMAT: MMddyyyy (matching HIDLE)
# NAME FORMAT: "First Last Middle Suffix" with space separators (matching HIDLE)

param(
    [string]$Version = "1.0",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\HI_HCJDC_OFML_BASE.json"
$VEROUT   = "$PHASEDIR\HI_HCJDC_OFML_v${Version}_${DATE}.json"

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
# BUNDLE 1: HI_HCJDC_OFML PROVIDER
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
    description                = 'Authentication configuration for HI HCJDC OFML'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'HI_HCJDC_OFML'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'HI_HCJDC_OFML'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'HI_HCJDC_OFML_Results'
$results.description = 'Results mapping for HI HCJDC OFML'
$results.provider    = 'HI_HCJDC_OFML'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'HI_HCJDC_OFML_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'HI_HCJDC_OFML'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: 6 combos across 3 message keys (M55L, M55S, RQ, QV)
#   M55L: In-state plate (VehicleTypeCode + Plate)
#   M55S: In-state VIN (VehicleTypeCode + VIN)
#   RQ:   Out-state plate (Plate + PlateType + PlateYear), Out-state VIN (VIN)
#   QV:   Stolen plate (Plate + State), Stolen VIN (VIN + MakeCode)
# State2-5 excluded (not implementable). Single RegistrationState (NCIC).
# Combo ordering: M55 (in-state) > RQ-Plate (out-state) > QV (stolen) > RQ-VIN (fallback)
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 20; sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleTypeCode';              size = 1;  sourceField = @('VehicleTypeCode');              targetField = 'VehicleTypeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('VehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # M55L: In-state plate (VehicleTypeCode + Plate)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleTypeCode','LicensePlateNumber'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'M55L'
            state                 = 'In'
        }
        # M55S: In-state VIN (VehicleTypeCode + VIN)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleTypeCode','VehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'M55S'
            state                 = 'In'
        }
        # RQ: Out-state plate (Plate + PlateType + PlateYear). State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'Out'
        }
        # QVV: Stolen VIN (VIN + MakeCode). ImageIndicator optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','VehicleMakeCode'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QVV'
            state                 = 'In/Out'
        }
        # QVP: Stolen plate (Plate + State)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QVP'
            state                 = 'In/Out'
        }
        # RQV: Out-state VIN fallback (VIN only). State/MakeCode/Year optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQV'
            state                 = 'Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- M55L/M55S (in-state), RQ (out-state), QV (stolen). 6 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: 3 combos -- DQ (OLN), DQ (Name+Sex+DOB), QW (Name+DOB wanted person)
#   State2-5 excluded. Single RegistrationState (NCIC).
#   QW fires when Name+DOB present but SexCode absent (less restrictive than DQ Name).
#   autoSelect=true, queriesToDeselect=DriverHistoryQuery
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30; sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQN: OLN path (most specific -- fires when OLN present). State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        # DQ: Name path (fires when SexCode + DOB + Name present). State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # QW: Wanted Person (fires when Name+DOB present, SexCode absent). SexCode optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'QW'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQN (OLN), DQ (Name+Sex+DOB), QW (Wanted Person on Name+DOB).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverHistoryQuery')
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery
# XML: 2 combos -- KQ (OLN), KQ (Name+Sex+DOB)
#   Duplicate keyRef KQ -> invented KQN (OLN), KQ (Name)
#   Has Attention and PurposeCode fields (not in DL)
#   autoSelect=false, queriesToDeselect=DriverLicenseQuery
# =====================================================================
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention';  size = 30; sourceField = @('Attention');  targetField = 'Attention' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30; sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('PurposeCode');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQN: OLN path. Attention/PurposeCode/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQN'
            state                 = 'In/Out'
        }
        # KQ: Name path. Attention/PurposeCode/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQN (OLN), KQ (Name+Sex+DOB). Attention + PurposeCode optional.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $false
    queriesToDeselect = @('DriverLicenseQuery')
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery
# XML: 1 combo (QG). GunMake maxLength=10 (not 23 like NJ). GunSerialNumber=20.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('GunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 10; sourceField = @('GunMake');                   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                  size = 20; sourceField = @('GunModel');                  targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('GunSerialNumber');           targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # Caliber/Make/Model/RSH optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @() }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. GunMake maxLength=10 (HI-specific).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML: 1 combo (QA). Same structure as NJ but with RelatedSearchHitIndicator.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('ArticleSerialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('ArticleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # RSH optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML: BQ (Choice[Hull/Reg], any=[State]) + QB (Choice(max2)[Reg/Hull], any=[RelatedSearchHitIndicator])
# Merged into 2 combos: one per primary field, both optional fields in any[]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ: Boat Registration. RSH/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @() }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        # QB: Stolen Boat. RSH/State optional (Any inside Set).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @() }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Reg), QB (Stolen/Hull). Merged from XML Choice elements.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for HI_HCJDC_OFML v${Version}"
    name           = 'HI_HCJDC_OFML'
    type           = 'BUNDLE'
    provider       = 'HI_HCJDC_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# =====================================================================

# Vehicle -- 1 card (Phase 1)
# Serves VehicleRegistrationQuery (M55L/M55S/RQ/QV) -- all 6 combos
# VehicleTypeCode: 1=Auto, 2=Motorcycle, 3=Truck, 5=Trailer, 6=Moped (in-state only)
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'HI' } 'ROW_VEH_1' }
                @{ id = 'VehicleTypeCode_Input';      node = Inp 'VehicleTypeCode' 'Type Code' '1' 'ROW_VEH_1' @{ initialValue = '1' } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = '2026' } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_4' }
                @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear' 'Vehicle Year' '4' 'ROW_VEH_4' }
                @{ id = 'ImageIndicator_Input';  node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- M55L/M55S (in-state), RQ (out-state), QV (stolen) on single card.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 1 card
# Serves BOTH DriverLicenseQuery (DQN/DQ/QW) and DriverHistoryQuery (KQN/KQ)
# DL/DH share fields. DH adds Attention + PurposeCode.
# autoSelect on DL, queriesToDeselect bidirectional.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'HI' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'Attention_Input';    node = Inp 'Attention'    'Attention'    '30' 'ROW_PER_4' }
                @{ id = 'PurposeCode_Input';  node = Sel 'PurposeCode' 'Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_PER_4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DQN/DQ/QW) and DH (KQN/KQ) on single card. autoSelect+queriesToDeselect.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card (QG)
# GunMake maxLength=10 (HI-specific, not 23 like NJ)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'GunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'GunModel_Input';                  node = Inp 'GunModel' 'Model' '20' 'ROW_GUN_2' }
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Sel 'RelatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- 1 card (QA)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'NCIC ARTICLE QUERY'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input';       node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';           node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6'); fields = @(
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Sel 'RelatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- 1 card
# BoatQuery: BQ (Reg) + BQN (Hull). State + RelatedSearchHitIndicator optional.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'RegistrationNumber_Input';        node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'HI' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';          node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Sel 'RelatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (Reg) and BQN (Hull).'
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
# BUNDLE 3: RMS (from HIDLE, with HI patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add RegistrationState to licensePlateIn combination any[]
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# Patch 3: add RegistrationState to RMS Person QIDM
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

# Patch 6: RMS CLEANUP -- remove unused HIDLE fields
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
$OUTREADABLE = "$DIR\HI_HCJDC_OFML_BASE_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built HI_HCJDC_OFML_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE (use NJ validator adapted for HI)
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

# -- Git commit --
Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."
