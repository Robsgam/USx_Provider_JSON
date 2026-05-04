# build_ny_nyspin_ejustice.ps1
# PHASE 1 -- single entity, single card per QIF.
# Builds NY_NYSPIN_EJUSTICE.json from source\NY_NYSPIN_EJUSTICE.XML (field authority)
# + HIDLE.json (structural template / RMS bundle).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ny_nyspin_ejustice.ps1 -Version 1.0 -Phase 01_standup
#
# Source authority: source\NY_NYSPIN_EJUSTICE.XML (field names, sizes, combinations, keyRefs)
# Structural template: source\HIDLE.json (RMS bundle, Results mapping)
#
# QUERYINPUTDATAMAPPING (CommSys -- 7 QIDMs):
#   VehicleRegistrationQuery   RVEH (plate), RVIN (VIN+state OOS), RCAR (VIN only NY)
#   BoatQuery                  BVEH (reg+state OOS), BVIN (hull+state OOS), RVEH (reg NY), RCAR (hull NY)
#   DriverLicenseQuery         DLIC (OLN)
#   NyNyspinDriverLicenseNameQuery  DGRP (Name+DOB)
#   DriverHistoryQuery         DALL (OLN DH), DALH (Name DH -- invented keyRef, distinct from DALL)
#   GunQuery                   GINQ
#   ArticleSingleQuery         AINQ
#
# WINQ / MINQ: EXCLUDED.  WantedPersonQuery and MissingPersonQuery appear as MessageKeys
# in the XML but have NO Transaction definition.  No MetaData = no QIDM = not buildable.
# Document in LIMITATIONS.txt; revisit if vendor adds Transaction XML.
#
# ENTITIES (5 QUERYINPUTFORM -- Phase 1: single card each):
#   Vehicle  -- VEHICLE SEARCH (Plate + State + PlateType + Year + VIN + Make + Year + Image)
#   Person   -- PERSON SEARCH (DL: OLN+State+Image+Name+DOB+Sex | DH: OLNdh+Namedh+DOBdh+Sexdh + extras)
#   Firearm  -- FIREARM SEARCH (Serial + Make + Caliber + RelatedHit)
#   Article  -- ARTICLE SEARCH (Serial + TypeCode + Image + RelatedHit)
#   Boat     -- BOAT SEARCH (RegNum + Hull + State)
#
# STATE HANDLING (Phase 1 -- dual-field pattern; NCIC unconfirmed on NY instance):
#   Visible Sel 'State' codeTypeCategory=NJ_NIBRS_STATE, codeTypeSource=NJ_NIBRS, NO initialValue
#     Blank by default = NY queries (RVEH plate, RCAR VIN). Operator selects state for OOS.
#     Sends 2-letter code to CommSys XML (plain text -- no reverse-lookup needed).
#   Hidden SelH 'RegistrationState' attributeTypeId=STATE, initialValue=NY
#     Stores platform attr ID for NY. Feeds RMS via useAttributeId=true (Patches 1 + 3).
#   NOTE: Test NCIC pattern on first import (see FORM_ARCHITECTURE.txt Section 3a).
#     If <State>NY</State> in CommSys plate query -> NCIC confirmed -> simplify to one field (Phase 2+).
#
# SEX HANDLING (Phase 1 -- NIBRS_SEX CommSys-only; NIBRS reverse-lookup unconfirmed on NY instance):
#   Form: Sel 'SexCode' codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS
#     Stores text M/F/U directly (no reverse-lookup required).
#   CommSys QIDM SexCode: NO codeTypeProvider (plain text M/F/U passes through).
#   RMS Person QIDM: sex attribute removed entirely (see Patch below).
#   CONFIRM on live test: CommSys <SexCode>M</SexCode> present = pattern working.
#
# DH-SUFFIX FIELDIDS (structural isolation from DL field pool):
#   DH fields: OperatorLicenseNumberDH, NameFirstDH, NameLastDH, NameMiddleDH, NameSuffixDH,
#              BirthDateDH, SexCodeDH
#   DL QIDM (DLIC, DGRP) sourceFields never reference DH-suffix fieldIds.
#   DH QIDM (DALL, DALH) sourceFields never reference bare DL fieldIds.
#   This ensures DL queries do not co-fire DriverHistoryQuery.
#
# DALL + DALH: single DriverHistoryQuery QIDM, two combinations (v1.19 confirmed pattern).
#   MetaData defines both OLN and Name paths under keyRef=DALL.
#   Platform rejects duplicate keyRefs in one QIDM -- invented DALH for the Name path.
#   Provider routes by XML field content (not keyRef). Confirmed NY v1.19.
#
# RMS PATCH 1: RegistrationState added to RMS Vehicle licensePlateIn any[]
#   Without: plate search fires but RMS elastic query has no state filter.
# RMS PATCH 3: registrationStateAttrId attr added to RMS Person QIDM
#   Without: person searches fire without state filter in RMS elastic query.
#   Pattern: singular registrationStateAttrId (string, no ArrayWrapper) -- confirmed NJ v1.2.
# RMS SEX REMOVED: sex attr removed from RMS Person QIDM (NIBRS reverse-lookup fails on NY instance).
#   Confirmed pattern: FL_FCIC. Revisit when/if NY instance confirms NIBRS reverse-lookup.

param(
    [string]$Version = "1.0",
    [string]$Phase   = "01_standup"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = "C:\Users\RobSgambellone\.local\bin\NY_NYSPIN_EJUSTICE"
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NY_NYSPIN_EJUSTICE.json"
$VEROUT   = "$PHASEDIR\NY_NYSPIN_EJUSTICE_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR        | Out-Null
New-Item -ItemType Directory -Force -Path "$PHASEDIR\logs" | Out-Null

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
    $fr  = AddFrNodes  $def
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
            requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') }
        }
    )
    description                = 'Authentication configuration for NY NYSPIN eJustice'
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
$results.description = 'Results mapping for NY NYSPIN eJustice'
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
# 1d. VehicleRegistrationQuery -- single QIDM, 3 combinations
# XML: keyRef RVEH (plate), RVIN (VIN + state OOS/NCIC), RCAR (VIN NY-DMV, no state)
#
# State 'State' fieldId: visible blank-default dropdown (NJ_NIBRS_STATE/NJ_NIBRS).
#   Blank = no <State> in XML -> RVEH plate / RCAR VIN (NY DMV) paths.
#   Populated = <State>XX</State> in XML -> RVIN also fires (VIN+State = OOS/NCIC).
#
# Combination ordering (LIMITATION #3): most specific first.
#   RVEH (plate) | RVIN (VIN+State -- more specific) | RCAR (VIN only -- least specific)
#
# LicensePlateNumberIn fieldId -> triggers RMS licensePlateIn combo (Patch 1 adds RegistrationState).
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumberIn');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('State');                       targetField = 'State' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('VehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # RVEH: plate search (NY or OOS -- state optional)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumberIn'); any = @('State','LicensePlateTypeCode','LicensePlateYear','ImageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RVEH'
            state                 = 'In/Out'
        }
        # RVIN: VIN + state (OOS/NCIC search -- more specific than RCAR; must precede RCAR)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','State'); any = @('VehicleMakeCode','VehicleYear','ImageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RVIN'
            state                 = 'In/Out'
        }
        # RCAR: VIN only (NY DMV -- fires when state blank)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('VehicleMakeCode','VehicleYear','ImageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RCAR'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (plate RVEH, OOS VIN RVIN, NY VIN RCAR) -- Phase 1'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. BoatQuery -- single QIDM, 4 combinations
# XML: BVEH (reg+state OOS), BVIN (hull+state OOS), RVEH (reg NY), RCAR (hull NY)
# Same blank-default 'State' field: blank = NY (RVEH/RCAR), populated = OOS (BVEH/BVIN)
# Combination ordering: OOS (with state in set[]) first -- more specific.
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('ImageIndicator');     targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 10; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State';              size = 2;  sourceField = @('State');              targetField = 'State' }
    )
    combinations = @(
        # OOS combinations first (most specific -- require State in set[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber','State'); any = @('ImageIndicator') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BVEH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber','State'); any = @('ImageIndicator') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BVIN'
            state                 = 'In/Out'
        }
        # NY combinations (no state required)
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
    description     = 'Mapping for BoatQuery (OOS: BVEH+BVIN; NY: RVEH+RCAR) -- Phase 1'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# 1f. DriverLicenseQuery -- OLN path only (DLIC)
# XML: DriverLicenseQuery v1, keyRef DLIC
#   set[OperatorLicenseNumber], any[ImageIndicator, State]
#
# Name/DOB path uses a separate transaction (NyNyspinDriverLicenseNameQuery / DGRP below).
# Different query value = different (targetEntity, query) pair = no LIMITATION #2 risk.
#
# State 'State': blank = no <State> in XML (NY default), populated = OOS state.
# =====================================================================
$dlQueryOLN = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('State');                 targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('ImageIndicator','State') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DLIC'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery (OLN path -- DLIC) in NY NYSPIN eJustice -- Phase 1'
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
# 1g. NyNyspinDriverLicenseNameQuery -- Name/DOB path (DGRP)
# XML: NyNyspinDriverLicenseNameQuery (separate transaction from DriverLicenseQuery)
#   set[Name (NameLast + NameFirst)], any[BirthDate, NameMiddle, NameSuffix, SexCode]
#
# Name assembled via FormatStringRuleHandler (4 source fields, 3 separator args).
# SexCode: no codeTypeProvider -- form uses codeTypeCategory=NIBRS_SEX (text M/F/U passthrough).
#   NIBRS reverse-lookup unconfirmed on NY instance; remove codeTypeProvider until confirmed.
# =====================================================================
$dlQueryName = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 35; sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NameLast','NameFirst'); any = @('BirthDate','NameMiddle','NameSuffix','SexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'DGRP'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for NyNyspinDriverLicenseNameQuery (Name/DOB path -- DGRP) in NY NYSPIN eJustice -- Phase 1'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_NyNyspinDriverLicenseNameQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'NyNyspinDriverLicenseNameQuery'
    queryLabel      = 'Driver License (Name)'
    targetEntity    = 'Person'
}

# =====================================================================
# 1h. DriverHistoryQuery -- single QIDM, two combinations (v1.19 confirmed pattern)
# XML: both OLN and Name paths listed under keyRef=DALL.
#   Platform rejects duplicate keyRefs in one QIDM -> invent DALH for Name path.
#   Provider routes by XML field content, not keyRef. Confirmed v1.19.
#
# DALL (OLN):  set[OperatorLicenseNumberDH]
# DALH (Name): set[NameLastDH, NameFirstDH]   <- invented keyRef; passes import
#
# DH-suffix fieldIds provide structural isolation from DL field pool.
# DL QIDMs (DLIC, DGRP) never reference DH-suffix sourceFields.
# SexCodeDH: no codeTypeProvider (same NIBRS_SEX CommSys-only pattern as SexCode).
# =====================================================================
$dhistQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ImageIndicator';          size = 1;  sourceField = @('ImageIndicator');          targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 35; sourceField = @('NameFirstDH','NameLastDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NyNyspinTransactionName'; size = 4;  sourceField = @('NyNyspinTransactionName'); targetField = 'NyNyspinTransactionName' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber';   size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';             size = 1;  sourceField = @('PurposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'Requestor';               size = 35; sourceField = @('Requestor');               targetField = 'Requestor' }
        [PSCustomObject]@{ name = 'SexCode';                 size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode' }
        [PSCustomObject]@{ name = 'State';                   size = 2;  sourceField = @('State');                   targetField = 'State' }
    )
    combinations = @(
        # DALL: OLN path (most specific -- must precede DALH)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumberDH')
                any = @('BirthDateDH','ImageIndicator','NameFirstDH','NameLastDH','NameMiddleDH','NameSuffixDH','NyNyspinTransactionName','PurposeCode','Requestor','SexCodeDH','State')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DALL'
            state                 = 'In/Out'
        }
        # DALH: Name path (invented keyRef -- distinct from DALL; import passes)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLastDH','NameFirstDH')
                any = @('BirthDateDH','ImageIndicator','NameMiddleDH','NameSuffixDH','NyNyspinTransactionName','OperatorLicenseNumberDH','PurposeCode','Requestor','SexCodeDH','State')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DALH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery (DALL OLN + DALH Name -- single QIDM) in NY NYSPIN eJustice -- Phase 1'
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
# 1i. GunQuery (GINQ)
# XML: GunQuery v1, keyRef GINQ
#   set[GunSerialNumber], any[GunCaliber, GunMake, RelatedHitSearchIndicator]
# GunMake + GunCaliber: FormInput on form (no confirmed NY code list for these fields).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('GunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 23; sourceField = @('GunMake');                   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('GunSerialNumber');           targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @('GunCaliber','GunMake','RelatedHitSearchIndicator') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'GINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (GINQ) in NY NYSPIN eJustice -- Phase 1'
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
# 1j. ArticleSingleQuery (AINQ)
# XML: ArticleSingleQuery v1, keyRef AINQ
#   set[ArticleSerialNumber, ArticleTypeCode], any[ImageIndicator, RelatedHitSearchIndicator]
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC_ARTICLE_TYPE confirmed under CA_CLETS -- NJ + NY tests)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('ArticleSerialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('ArticleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator','RelatedHitSearchIndicator') }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'AINQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (AINQ) in NY NYSPIN eJustice -- Phase 1'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NY_NYSPIN_EJUSTICE_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NY_NYSPIN_EJUSTICE'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

$nyBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQueryOLN, $dlQueryName, $dhistQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for NY_NYSPIN_EJUSTICE v${Version} (Phase 1)"
    name           = 'NY_NYSPIN_EJUSTICE'
    type           = 'BUNDLE'
    provider       = 'NY_NYSPIN_EJUSTICE'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# Phase 1: single entity, single card per form. No multi-card. No split entity.
# All query paths for an entity are on one card -- confirms all QIDMs before Phase 2 UX work.
# =====================================================================

# ------------------------------------------------------------------
# VEHICLE -- 1 card (VEHICLE SEARCH)
# Plate + State(blank-default) + PlateType + Year + VIN + Make + Year + Image
# State 'State': blank = NY (RVEH/RCAR), populated = OOS (RVIN also fires)
# Hidden SelH 'RegistrationState': stores NY attr ID for RMS Patch 1 (licensePlateIn any[])
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('8','4'); fields = @(
                @{ id = 'LicensePlateNumberIn_Input'; node = Inp 'LicensePlateNumberIn' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'State_Veh_Input';            node = Sel 'State' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('5','5','2'); fields = @(
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' }
                @{ id = 'ImageIndicator_Veh_Input';   node = Inp 'ImageIndicator' 'Image' '1' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('8','4'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_4' }
                @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear' 'Year' '4' 'ROW_VEH_4' }
            )}
            @{ id = 'ROW_VEH_STATE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'RegistrationState_Veh_Input'; node = SelH 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NY' } 'ROW_VEH_STATE' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate (RVEH), OOS VIN (RVIN), NY VIN (RCAR) on single card. Phase 1.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# PERSON -- 1 card (PERSON SEARCH)
# Phase 1 single-card includes ALL person query fields:
#   DL OLN:  OperatorLicenseNumber + State + ImageIndicator -> DLIC fires
#   DL Name: NameFirst/Last/Middle/Suffix + BirthDate + SexCode -> DGRP fires
#   DH OLN:  OperatorLicenseNumberDH -> DALL fires (DH-suffix = isolated from DL)
#   DH Name: NameFirstDH/LastDH/MiddleDH/SuffixDH + BirthDateDH + SexCodeDH -> DALH fires
#   DH extras: NyNyspinTransactionName + PurposeCode + Requestor (DALL optional)
#
# SexCode / SexCodeDH: Sel with codeTypeCategory=NIBRS_SEX, codeTypeSource=NIBRS.
#   Stores text M/F/U directly. CommSys QIDM SexCode has no codeTypeProvider (no reverse-lookup).
#   NIBRS reverse-lookup unconfirmed on NY instance -- CommSys-only sex pattern (same as FL).
#
# Hidden SelH 'RegistrationState': stores NY attr ID for RMS Patch 3 (Person registrationStateAttrId).
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            # -- Driver License: OLN path --
            @{ id = 'ROW_PER_1'; cols = @('8','2','2'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_1' }
                @{ id = 'State_Per_Input';             node = Sel 'State' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_PER_1' }
                @{ id = 'ImageIndicator_Per_Input';    node = Inp 'ImageIndicator' 'Image' '1' 'ROW_PER_1' }
            )}
            # -- Driver License: Name path --
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '20' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'M.I.'         '20' 'ROW_PER_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'        '4' 'ROW_PER_3' }
                @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'     'ROW_PER_3' }
                @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ codeTypeCategory = 'NIBRS_SEX'; codeTypeSource = 'NIBRS' } 'ROW_PER_3' }
            )}
            # -- Driver History: OLN path (DH-suffix fieldIds) --
            @{ id = 'ROW_PER_4'; cols = @('8','4'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_4' }
                @{ id = 'NyNyspinTransactionName_Input'; node = Inp 'NyNyspinTransactionName' 'Transaction Name'    '4'  'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('4','4','4'); fields = @(
                @{ id = 'PurposeCode_Input'; node = Inp 'PurposeCode' 'Purpose Code' '1'  'ROW_PER_5' }
                @{ id = 'Requestor_Input';   node = Inp 'Requestor'   'Requestor'    '35' 'ROW_PER_5' }
                @{ id = 'ImageIndicatorDH_Input'; node = Inp 'ImageIndicator' 'Image (DH)' '1' 'ROW_PER_5' }
            )}
            # -- Driver History: Name path (DH-suffix fieldIds) --
            @{ id = 'ROW_PER_6'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '20' 'ROW_PER_6' }
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_6' }
            )}
            @{ id = 'ROW_PER_7'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'M.I. (DH)'    '20' 'ROW_PER_7' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix (DH)'   '4' 'ROW_PER_7' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'BirthDateDH'  'DOB (DH)'          'ROW_PER_7' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'SexCodeDH' 'Sex (DH)' @{ codeTypeCategory = 'NIBRS_SEX'; codeTypeSource = 'NIBRS' } 'ROW_PER_7' }
            )}
            # -- Hidden: RegistrationState for RMS (Patch 3) --
            @{ id = 'ROW_PER_STATE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'RegistrationState_Per_Input'; node = SelH 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NY' } 'ROW_PER_STATE' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL OLN (DLIC) + DL Name (DGRP) + DH OLN (DALL) + DH Name (DALH) on single card. Phase 1.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# FIREARM -- 1 card (FIREARM SEARCH)
# GunSerialNumber required. GunMake + GunCaliber: FormInput (no confirmed NY code list).
# RelatedHitSearchIndicator: FormInput (Y or blank).
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('12'); fields = @(
                @{ id = 'GunSerialNumber_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('6','6'); fields = @(
                @{ id = 'GunMake_Input';    node = Inp 'GunMake'    'Make'    '23' 'ROW_GUN_2' }
                @{ id = 'GunCaliber_Input'; node = Inp 'GunCaliber' 'Caliber'  '4' 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_3'; cols = @('12'); fields = @(
                @{ id = 'RelatedHitSearchIndicator_Gun_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y or blank)' '1' 'ROW_GUN_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm queries -- GINQ (serial required). Phase 1.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# ARTICLE -- 1 card (ARTICLE SEARCH)
# ArticleSerialNumber + ArticleTypeCode both required.
# ImageIndicator + RelatedHitSearchIndicator optional (FormInput, Y or blank).
# ArticleTypeCode: codeTypeSource=CA_CLETS (NCIC_ARTICLE_TYPE confirmed under CA_CLETS)
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ImageIndicator_Art_Input';        node = Inp 'ImageIndicator'            'Image (Y or blank)'      '1' 'ROW_ART_2' }
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y or blank)' '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article queries -- AINQ (serial + type required). Phase 1.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# BOAT -- 1 card (BOAT SEARCH)
# RegistrationNumber / BoatHullIdNumber + State (blank-default).
# Blank state = NY (RVEH/RCAR). Populated = OOS (BVEH/BVIN).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '10' 'ROW_BOA_1' }
                @{ id = 'State_Boa_Input';          node = Sel 'State' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('10','2'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                @{ id = 'ImageIndicator_Boa_Input'; node = Inp 'ImageIndicator' 'Image' '1' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- OOS (BVEH+BVIN) and NY (RVEH+RCAR) on single card. Phase 1.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations (Phase 1 -- single card per entity)'
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

# PATCH 1 -- Vehicle: add RegistrationState to licensePlateIn combination any[]
# Hidden SelH 'RegistrationState' (attributeTypeId=STATE, initialValue=NY) stores NY attr ID.
# RMS receives registrationStateAttrIds:[attr_id] for plate searches (same Patch 1 as NJ).
$rmsVehQidm   = $rmsBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Vehicle' } | Select-Object -First 1
$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

# RMS SEX REMOVED -- NY instance: NIBRS reverse-lookup unconfirmed.
# Remove sex attribute from RMS Person QIDM entirely (CommSys-only sex pattern -- same as FL).
# HIDLE has two sex attrs: 'sex' (sourceField=SexCode) and 'sexOOS' (sourceField=SexCodeOOS).
# Both removed. Combination any[] references to both 'SexCode' and 'SexCodeOOS' also removed.
# Leaving a combination reference without a matching attribute causes import error.
# REVISIT: if live test confirms NIBRS reverse-lookup works on NY -> restore sex attr + useAttributeId.
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.targetField -ne 'sexAttrId' })
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'SexCode' -and $_ -ne 'SexCodeOOS' })
    $combo.requirements.set = @($combo.requirements.set | Where-Object { $_ -ne 'SexCode' -and $_ -ne 'SexCodeOOS' })
}

# PATCH 3 -- Person: add registrationStateAttrId to RMS Person QIDM
# Hidden SelH 'RegistrationState' (attributeTypeId=STATE, initialValue=NY) stores NY attr ID.
# Adds registrationStateAttrId to all person combination any[] so state is sent on every person search.
# Target: registrationStateAttrId (singular string, no AttributeArrayWrapperRuleHandler -- same as NJ v1.2).
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes) + [PSCustomObject]@{
    name           = 'registrationState'
    sourceField    = @('RegistrationState')
    targetField    = 'registrationStateAttrId'
    useAttributeId = $true
}
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any) + 'RegistrationState'
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($nyBundle, $entitiesBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100
$json | Set-Content $OUT    -Encoding UTF8
$json | Set-Content $VEROUT -Encoding UTF8

Write-Host "Built NY_NYSPIN_EJUSTICE.json v${Version} (Phase 1)"
Write-Host "  -> $OUT"
Write-Host "  -> $VEROUT"

# =====================================================================
# VALIDATE
# =====================================================================
Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
powershell.exe -ExecutionPolicy Bypass -File "$DIR\scripts\validate_ny_nyspin_ejustice.ps1" -JsonFile $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD ABORTED -- validator found errors. Fix and re-run." -ForegroundColor Red
    Write-Host "Docs and git were NOT updated." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green

# =====================================================================
# UPDATE DOCS
# =====================================================================
$STATUS_FILE = "$DIR\docs\NY_NYSPIN_EJUSTICE_STATUS.txt"
$NOTES_FILE  = "$DIR\docs\NY_NYSPIN_EJUSTICE_BUILD_NOTES.txt"

$statusEntry = @"

  v${Version}  $DATE  build_ny_nyspin_ejustice.ps1
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
$marker2 = "VERSION HISTORY  (newest first)"
$idx2 = $notesContent.IndexOf($marker2)
if ($idx2 -ge 0) {
    $insertAt2 = $idx2 + $marker2.Length
    $newContent2 = $notesContent.Substring(0, $insertAt2) + $notesEntry + $notesContent.Substring($insertAt2)
    Set-Content $NOTES_FILE $newContent2 -Encoding UTF8
} else {
    Add-Content $NOTES_FILE $notesEntry -Encoding UTF8
}

Write-Host ""
Write-Host "STATUS.txt and BUILD_NOTES.txt updated."

# -- Git commit -------------------------------------------------------
Write-Host ""
Write-Host "Committing to GitHub..."
Push-Location $DIR
git add "NY_NYSPIN_EJUSTICE.json" `
        "phases\$Phase\NY_NYSPIN_EJUSTICE_v${Version}_${DATE}.json" `
        "docs\NY_NYSPIN_EJUSTICE_STATUS.txt" `
        "docs\NY_NYSPIN_EJUSTICE_BUILD_NOTES.txt"
git commit -m "Build v$Version ($Phase $DATE) -- Phase 1 single-card reboot"
Pop-Location
Write-Host "Committed."
