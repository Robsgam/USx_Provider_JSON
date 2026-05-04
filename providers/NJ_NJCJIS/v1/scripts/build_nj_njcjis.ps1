# build_nj_njcjis.ps1
# Builds NJ_NJCJIS_BASE.json from source\NJ_NJCJIS.xml (field authority) + HIDLE.json (RMS template).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_njcjis.ps1 -Version X.X -Phase 01_standup
#
# INPUTS:
#   source\NJ_NJCJIS.xml  -- XML metadata (field names, sizes, combinations, keyRefs) [AUTHORITATIVE]
#   source\NJ_NJCJIS.pdf  -- CommSys devdoc (Basic Queries Supported, field M/C/O, combo specs) [CROSS-CHECK]
#   source\HIDLE.json     -- RMS structural template (RMS bundle, QUERYRESULTDATAMAPPING)
#
# BUILD PROCESS:
#   1. XML metadata defines fields, sizes, combo set[]/any[] -- this is the ConnectCIC contract
#   2. PDF devdoc cross-check: verify field coverage, flag PDF-vs-XML deltas (see docs\DEVDOC_CROSSCHECK_*.txt)
#   3. Build QIDMs + QIFs from XML definitions, apply code type mappings + rule handlers
#   4. Clone RMS bundle from HIDLE, apply NJ-specific patches
#   5. Assemble bundles (ENTITIES first), write UTF-8 no-BOM, validate
#
# DEVDOC CROSS-CHECK (source\NJ_NJCJIS.pdf):
#   Run once per devdoc version. Compare PDF "Basic Queries Supported" against XML metadata.
#   XML is authoritative for QIDM construction. PDF documents CommSys protocol expectations.
#   Report: docs\DEVDOC_CROSSCHECK_NJ_NJCJIS_BASE.txt
#   Key finding: PDF marks State as required on Vehicle RQ/RQN and DL DQN, but XML marks it Any.
#   Mitigation: initialValue=NJ ensures State always populated. set[] backport recommended.
#
# QUERYINPUTDATAMAPPING (CommSys -- 5 configs):
#   VehicleRegistrationQuery   RQ (Plate) + RQN (VIN)
#   DriverLicenseQuery         DQN (OLN) + DQ (Name)
#   GunQuery                   QG
#   ArticleSingleQuery         QA
#   BoatQuery                  BQ (Reg) + BQN (Hull)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- 1 card: VEHICLE SEARCH (Plate + RegistrationState + TypeCode + Year + VIN)
#   Person   -- 1 card: PERSON SEARCH (OLN + RegistrationState + Image + Name + DOB + Sex)
#   Firearm  -- 1 card: NCIC FIREARM QUERY (Serial + Make + Caliber)
#   Article  -- 1 card: NCIC ARTICLE QUERY (Serial + TypeCode)
#   Boat     -- 1 card: BOAT SEARCH (Reg + Hull + RegistrationState)
#
# STATE HANDLING (v1.7 -- NCIC pattern, confirmed working NJ + OOS 2026-04-20):
#   Single visible Sel 'RegistrationState' (attributeTypeId=STATE, initialValue=NJ)
#     Stores platform attribute ID internally; shows state names in dropdown.
#   CommSys State attr: sourceField=RegistrationState, codeTypeProvider=NCIC
#     NCIC reverse-lookup converts attr ID -> 2-letter state code for outbound XML.
#     CONFIRMED: CommSys receives <State>NJ</State> for NJ, <State>PA</State> for PA.
#   RMS RegistrationState: useAttributeId=true + AttributeArrayWrapperRuleHandler (from HIDLE)
#     Sends registrationStateAttrIds:[attr_id] dynamically for any operator-selected state.
#     CONFIRMED: NJ attr ID 69509884952 for NJ, PA attr ID 69509887513 for PA.
#   One field handles CommSys + RMS simultaneously. No hidden field. No initialValue hardcode.
#   CommSys combination any[]: 'RegistrationState' (form fieldId, not attribute name)
#
# DEAD ENDS (do not retry):
#   Option 1 -- attributeTypeId=STATE + codeTypeProvider=NJ_NIBRS on visible field:
#     RMS correct, CommSys gets no State element. NJ_NIBRS reverse-lookup not supported on NJ.
#   Option 2 -- LicensePlateNumberOut + Patch 2 split:
#     CommSys correct, RMS has no state filter for OOS plate.
#   Option 3 -- Dual visible state fields (State + RegistrationState both visible):
#     Technically functional but UX unacceptable (operator sets state twice). Rejected.
#
# RMS Patch 1: adds RegistrationState to RMS Vehicle licensePlateIn any[] for plate searches
# RMS Patch 3: adds registrationStateAttrId attr to RMS Person QIDM + RegistrationState to all person combination any[]
#
# SEX HANDLING (confirmed working -- NJ v1.0 2026-04-17 16:16 test):
#   Form: Sel 'SexCode' attributeTypeId=SEX + codeTypeProvider=NIBRS
#         Stores numeric attribute ID (e.g. 69509891711 for Male)
#   CommSys QIDM SexCode: codeTypeProvider=NIBRS (reverse-lookup: attr ID -> M/F/U)
#         CommSys receives <SexCode>M</SexCode> (correct)
#   RMS sex: from HIDLE -- useAttributeId=true, NO AttributeArrayWrapperRuleHandler
#         RMS receives sexAttrId:"69509891711" (string -- correct)
#   DO NOT add AttributeArrayWrapperRuleHandler to RMS sex (breaks RMS -- sexAttrId:[69509891711] array error)
#   DO NOT use codeTypeCategory=NIBRS_SEX on form (useAttributeId=true with string -> array wrapping)

param(
    [string]$Version = "1.0",
    [string]$Phase   = "base"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NJ_NJCJIS_BASE.json"
$VEROUT   = "$PHASEDIR\NJ_NJCJIS_v${Version}_${DATE}.json"

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
# BUNDLE 1: NJ_NJCJIS PROVIDER
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
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for NJ NJCJIS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NJ_NJCJIS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NJ_NJCJIS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'NJ_NJCJIS_Results'
$results.description = 'Results mapping for NJ NJCJIS'
$results.provider    = 'NJ_NJCJIS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NJ_NJCJIS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NJ_NJCJIS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: VehicleRegistrationQuery v1
#   RQ:  set[LicensePlateNumberIn, RegistrationState], any[LicensePlateTypeCode, LicensePlateYear]
#   RQN: set[VehicleIdentificationNumber, RegistrationState]
# Option C (2026-04-22): State moved to set[] per PDF (State is M/required).
# XML has State in Any, but PDF says State is mandatory. set[] is defensive.
#
# LicensePlateNumberIn fieldId -> triggers RMS licensePlateIn combination (Patch 1)
# RegistrationState (attributeTypeId=STATE, NCIC) -> CommSys + RMS state (confirmed NJ + OOS)
# PDF-only fields (ImageIndicator, RandomRequest) -- NOT in XML metadata; excluded per build rule.
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumberIn';        size = 10; sourceField = @('LicensePlateNumberIn');        targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumberIn','RegistrationState'); any = @('LicensePlateTypeCode','LicensePlateYear') }
            primaryFieldReference = 'LicensePlateNumberIn'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery in NJ NJCJIS -- RQ (plate), RQN (VIN)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: DriverLicenseQuery v1
#   DQN: set[OperatorLicenseNumber, RegistrationState], any[ImageIndicator]
#   DQ:  set[BirthDate, Name], any[SexCode, ImageIndicator, RegistrationState]
# Option C (2026-04-22): State moved to set[] on DQN per PDF (State required for OLN path).
# DQ stays any[] — PDF and XML both show State optional on name path.
# autoSelect=true: single QIDM, DQN fires when OLN present, DQ fires on Name+DOB.
# SexCode: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U for CommSys XML).
# State: codeTypeProvider=NCIC (reverse-lookup attr ID -> 2-letter code for CommSys XML).
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size        = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQN: OLN path (fires when OLN present)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        # DQ: Name path (fires when Name+DOB present, OLN absent)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('SexCode','ImageIndicator','RegistrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery (OLN path DQN + Name path DQ) in NJ NJCJIS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. GunQuery
# XML: GunQuery v1, keyRef QG
#   set[GunSerialNumber], any[GunMake, GunCaliber]
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('GunCaliber');      targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('GunMake');          targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('GunSerialNumber');  targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('GunMake','GunCaliber') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery in NJ NJCJIS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1g. ArticleSingleQuery
# XML: ArticleSingleQuery v1, keyRef QA
#   set[ArticleSerialNumber, ArticleTypeCode]
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC_ARTICLE_TYPE confirmed under CA_CLETS -- NJ/NY tests)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('ArticleTypeCode');     targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @() }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery in NJ NJCJIS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1h. BoatQuery
# XML: BoatQuery v1
#   BQ:  set[RegistrationNumber], any[State]
#   BQN: set[BoatHullIdNumber], any[State]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery in NJ NJCJIS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NJ_NJCJIS v${Version}"
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# No NJ/OOS entity split -- single form per entity.
# State visible with initialValue=NJ. Operator updates for OOS queries.
# =====================================================================

# ------------------------------------------------------------------
# Vehicle -- 1 card
# VEHICLE SEARCH: Plate + RegistrationState + TypeCode + Year + VIN
#   -> Plate (LicensePlateNumberIn) triggers RMS licensePlateIn (Patch 1: RegistrationState in any[])
#   -> VIN (VehicleIdentificationNumber) triggers RMS vehicleIdentificationNumber
#   -> RegistrationState (attributeTypeId=STATE): single field for CommSys (NCIC) + RMS (attr ID)
#      CONFIRMED: NJ + OOS both working (ST2-1 NJ, ST2-2 PA, 2026-04-20)
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('8','4'); fields = @(
                @{ id = 'LicensePlateNumberIn_Input'; node = Inp 'LicensePlateNumberIn' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'RegistrationState_Input';    node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' @{ initialValue = '2026' } }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate (RQ) and VIN (RQN) on single card. RegistrationState (NCIC) handles CommSys + RMS for NJ and OOS.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person -- 1 card
# PERSON SEARCH: OLN + RegistrationState + Image + Name + DOB + Sex
# DQN fires when OLN present. DQ fires when Name+DOB present, OLN absent (autoSelect).
# SexCode: attributeTypeId=SEX + codeTypeProvider=NIBRS (CONFIRMED WORKING v1.0 2026-04-17 16:16)
# RegistrationState: attributeTypeId=STATE + codeTypeProvider=NCIC (CommSys + RMS, NJ + OOS)
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_1'; cols = @('8','2','2'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_PER_1' }
                @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                                    'ROW_PER_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- OLN (DQN) and Name+DOB (DQ) on single card. RegistrationState (NCIC) handles CommSys + RMS for NJ and OOS.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm -- 1 card (QG)
# XML: set[GunSerialNumber], any[GunMake, GunCaliber]
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'NCIC FIREARM QUERY'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';         node = Sel 'GunMake'         'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6'); fields = @(
                @{ id = 'GunCaliber_Input'; node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NJ_NIBRS' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Input query layout for firearm entity'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article -- 1 card (QA)
# XML: set[ArticleSerialNumber, ArticleTypeCode]
# ------------------------------------------------------------------
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
    description  = 'Input query layout for article entity'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat -- 1 card
# BOAT SEARCH: Reg Number + Hull ID + RegistrationState
# BQ fires when RegistrationNumber present. BQN fires when BoatHullIdNumber present.
# RegistrationState (attributeTypeId=STATE, NCIC): CommSys + RMS, NJ and OOS.
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- Registration (BQ) and Hull ID (BQN) on single card. RegistrationState (NCIC) handles CommSys + RMS.'
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
    description    = 'Entity form configurations (shared across providers)'
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
# BUNDLE 3: RMS (from HIDLE, with NJ patches)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

# Patch 1: add RegistrationState to licensePlateIn combination any[]
# RegistrationState is the visible form field (attributeTypeId=STATE, NCIC pattern).
# Without this patch, plate searches omit state from the RMS elastic query entirely.
# With this patch: operator-selected state attr ID is included in RMS for plate searches.
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# Patch 2 REMOVED: LicensePlateNumberOut + licensePlateOutAndState approach is a dead end.
# CommSys got correct OOS state but RMS had no state. Do not retry.

# RMS Person sex: HIDLE has useAttributeId=true, NO AttributeArrayWrapperRuleHandler.
# Form attributeTypeId=SEX stores numeric attr ID -> useAttributeId=true passes it as string sexAttrId.
# CONFIRMED WORKING: NJ v1.0 2026-04-17 16:16 test -- sexAttrId:"69509891711" (string, not array).
# DO NOT add AttributeArrayWrapperRuleHandler -- it wraps result in array -> RMS 400 error.

# Patch 3: add RegistrationState to RMS Person QIDM
# RegistrationState is the visible form field (NCIC pattern). Dynamic attr ID stored internally.
# Adds registrationStateAttrId to all person combinations any[] so state is sent on every person search.
# Target field: registrationStateAttrId (singular, useAttributeId=true, no ArrayWrapper).
# Pattern mirrors sexAttrId: sexAttrDetail.id -> sexAttrId / registrationStateAttrDetail.id -> registrationStateAttrId.
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
    bundles = @($entitiesBundle, $njBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,    $json, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "Built NJ_NJCJIS_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
powershell.exe -ExecutionPolicy Bypass -File "$DIR\scripts\validate_nj_njcjis.ps1" -JsonFile $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green

# =====================================================================
# UPDATE DOCS
# =====================================================================
$STATUS_FILE = "$DIR\docs\NJ_NJCJIS_STATUS.txt"
$NOTES_FILE  = "$DIR\docs\NJ_NJCJIS_BUILD_NOTES.txt"

$statusEntry = @"

  v${Version}  $DATE  build_nj_njcjis.ps1
    Output : $OUT
    Archive: $VEROUT
"@
$statusContent = Get-Content $STATUS_FILE -Raw -Encoding UTF8
$marker = "BUILD LOG  (newest first)"
$idx = $statusContent.IndexOf($marker)
if ($idx -ge 0) {
    $insertAt = $idx + $marker.Length
    $newContent = $statusContent.Substring(0, $insertAt) + $statusEntry + $statusContent.Substring($insertAt)
    Set-Content $STATUS_FILE $newContent -Encoding UTF8
} else {
    Add-Content $STATUS_FILE $statusEntry -Encoding UTF8
}

$notesEntry = @"

v${Version}  $DATE  [describe change here]
  CHANGED
    -
  REASON
    -
"@
$notesContent = Get-Content $NOTES_FILE -Raw -Encoding UTF8
$marker = "VERSION HISTORY  (newest first)"
$idx = $notesContent.IndexOf($marker)
if ($idx -ge 0) {
    $insertAt = $idx + $marker.Length
    $newContent = $notesContent.Substring(0, $insertAt) + $notesEntry + $notesContent.Substring($insertAt)
    Set-Content $NOTES_FILE $newContent -Encoding UTF8
} else {
    Add-Content $NOTES_FILE $notesEntry -Encoding UTF8
}

Write-Host ""
Write-Host "STATUS.txt and BUILD_NOTES.txt updated."

# ── Git commit ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "Committing to GitHub..."
Push-Location $DIR
git add "NJ_NJCJIS_BASE.json" `
        "phases\$Phase\NJ_NJCJIS_v${Version}_${DATE}.json" `
        "docs\NJ_NJCJIS_STATUS.txt" `
        "docs\NJ_NJCJIS_BUILD_NOTES.txt"
git commit -m "Build v$Version ($Phase $DATE)"
Pop-Location
Write-Host "Committed."
