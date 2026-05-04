# build_az_azdps.ps1
# PHASE 1 -- single entity, single card per QIF.
# Builds AZ_AZDPS.json from source\AZ_AZDPS.xml (field authority)
# + HIDLE.json (structural template / RMS bundle).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps.ps1 -Version 1.0 -Phase 01_standup
#
# Source authority: source\AZ_AZDPS.xml (field names, sizes, combinations, keyRefs)
# Structural template: source\HIDLE.json (RMS bundle, Results mapping)
# Pattern reference: NY_NYSPIN_EJUSTICE scripts\build_ny_nyspin_ejustice.ps1
#
# QUERYINPUTDATAMAPPING (CommSys -- 8 QIDMs):
#   VehicleRegistrationQuery         ACVR (Plate+Badge), ACVRV (VIN+Badge -- invented; XML has 2x ACVR)
#   AzAzdpsDriverLicenseQuery        DQ (OLN), DQN (Name -- inv), DQSS (SSN -- inv), ACWL (Badge+Name)
#   DriverHistoryQuery               KQ (OLN+State), KQH (Name+State -- invented; XML has 2x KQ)
#   GunQuery                         ACQG (Badge+Serial)
#   ArticleSingleQuery               ACQA (Badge+Type+Serial)
#   BoatQuery                        ACQB (Reg+Badge), ACQBH (Hull+Badge -- inv), BQ (Reg), BQH (Hull -- inv)
#   WMPIWantedPersonInquiry          ACQW (Name+DOB+Sex+Race), ACQWN (NCICNumber -- inv; XML has 11x ACQW)
#   WMPIMissingPersonInquiry         ACQM (Name+descriptors), ACQMN (NCICNumber -- inv; XML has 2x ACQM)
#
# ENTITIES (5 QUERYINPUTFORM -- Phase 1: single card each):
#   Vehicle  -- VEHICLE SEARCH (Plate, VIN, State, Make, Year -- Badge auto-populated via dexStateUserId)
#   Person   -- PERSON SEARCH (DL: OLN+SSN+Name | DH: OLN+Name DH-suffix | Wanted+Missing -- Badge auto)
#   Firearm  -- FIREARM SEARCH (Serial+Make+Model+Caliber -- Badge auto-populated via dexStateUserId)
#   Article  -- ARTICLE SEARCH (TypeCode+Serial -- Badge auto-populated via dexStateUserId)
#   Boat     -- BOAT SEARCH (Reg+Hull+State -- Badge auto-populated via dexStateUserId)
#
# dexStateUserId: hidden InpH on each form. Platform auto-populates from officer RMS profile
#   via CommsysGetDexStateUserIdRuleHandler (already in AUTHENTICATION config).
#   QIDM BadgeNumber attribute sourceField = 'dexStateUserId'. Combination set/any refs updated.
#
# INVENTED keyRefs (duplicate keyRef fix -- provider routes by XML field content, not keyRef):
#   ACVRV = VIN path of VehicleRegistrationQuery  (XML has ACVR for both Plate and VIN)
#   DQN   = Name path of AzAzdpsDriverLicenseQuery (XML has DQ for OLN/Name/SSN)
#   DQSS  = SSN path of AzAzdpsDriverLicenseQuery
#   KQH   = Name path of DriverHistoryQuery        (XML has KQ for both OLN and Name)
#   ACQBH = Hull+Badge path of BoatQuery           (XML has ACQB for both Reg and Hull)
#   BQH   = Hull path of BoatQuery                 (XML has BQ for both Reg and Hull)
#   ACQWN = NCICNumber path of WMPIWantedPersonInquiry  (XML has ACQW x11+)
#   ACQMN = NCICNumber path of WMPIMissingPersonInquiry (XML has ACQM x2)
#
# STATE HANDLING (NCIC confirmed for AZ):
#   Vehicle/Boat: visible RegistrationState (attributeTypeId=STATE, initialValue=AZ)
#     -> NCIC codeTypeProvider in QIDM converts attr ID to 2-letter code for CommSys XML.
#     -> useAttributeId=True in RMS QIDM passes attr ID for RMS elastic query (Patches 1+3).
#   DH hidden state: InpH fieldId='StateDH', initialValue='AZ' (plain text, no NCIC needed).
#     State is mandatory in KQ/KQH set[]. Always AZ for this provider. DH-suffix isolation.
#   Person DL: same RegistrationState dropdown (attributeTypeId=STATE, initialValue=AZ).
#
# SEX HANDLING (NIBRS confirmed for AZ -- reverse-lookup works on AZ instance):
#   Form: Sel attributeTypeId=SEX, codeTypeProvider=NIBRS (stores attr ID; NIBRS -> M/F/U)
#   CommSys QIDM: codeTypeProvider=NIBRS converts attr ID to M/F/U in outbound XML.
#   RMS QIDM: useAttributeId=True passes attr ID directly (sex filtering works).
#   DH: same pattern but fieldId=SexCodeDH (DH-suffix isolation).
#
# DH-SUFFIX FIELDIDS (LIMITATION #26 isolation from DL field pool):
#   DH fields: OperatorLicenseNumberDH, NameLastDH, NameFirstDH, NameMiddleDH, NameSuffixDH,
#              BirthDateDH, SexCodeDH, StateDH (hidden)
#   DL QIDMs (DQ, DQN, DQSS, ACWL) never reference DH-suffix sourceFields.
#   DH QIDM (KQ, KQH) never references DL (bare) sourceFields.
#
# RMS PATCHES (applied after clone from HIDLE):
#   PATCH 1: LicensePlateYear removed from RMS Vehicle QIDM any[] (no elastic mapping)
#   PATCH 2: autoSelect=true applied to all RMS QIDMs
#   NO sex/race removal (AZ NIBRS confirmed -- keep sex/race in RMS QIDM)

param(
    [string]$Version = "1.0",
    [string]$Phase   = "01_standup"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = "C:\Users\RobSgambellone\.local\bin\AZ_AZDPS"
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\AZ_AZDPS.json"
$VEROUT   = "$PHASEDIR\AZ_AZDPS_v${Version}_${DATE}.json"

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
    $fr  = AddFrNodes  $def
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1: AZ_AZDPS PROVIDER
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
    description                = 'Authentication configuration for AZ AZDPS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'AZ_AZDPS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'AZ_AZDPS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'AZ_AZDPS_Results'
$results.description = 'Results mapping for AZ AZDPS'
$results.provider    = 'AZ_AZDPS'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'AZ_AZDPS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'AZ_AZDPS'
}

# =====================================================================
# 1d. VehicleRegistrationQuery -- single QIDM, 2 combinations
# XML: keyRef ACVR for BOTH plate and VIN paths (duplicate).
# ACVR  = Plate+Badge: set[BadgeNumber, LicensePlateNumber]
# ACVRV = VIN+Badge:   set[BadgeNumber, VehicleIdentificationNumber]  <- invented keyRef
# Provider routes by XML field content (Plate vs VIN present), not keyRef value.
# State: RegistrationState (attributeTypeId=STATE, initialValue=AZ, NCIC confirmed).
#   codeTypeProvider=NCIC in QIDM attr converts attr ID to 2-letter code for CommSys XML.
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';       size = 10; sourceField = @('LicensePlateNumber');       targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';     size = 2;  sourceField = @('LicensePlateTypeCode');     targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';         size = 4;  sourceField = @('LicensePlateYear');         targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                    size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';          size = 4;  sourceField = @('VehicleMakeCode');          targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';              size = 4;  sourceField = @('VehicleYear');              targetField = 'VehicleYear' }
    )
    combinations = @(
        # ACVR: Plate + Badge (most specific for plate path)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','LicensePlateNumber')
                any = @('LicensePlateYear','LicensePlateTypeCode','RegistrationState','VehicleIdentificationNumber','VehicleMakeCode','VehicleYear')
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ACVR'
            state                 = 'In/Out'
        }
        # ACVRV: VIN + Badge (invented keyRef -- XML has ACVR for both)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','VehicleIdentificationNumber')
                any = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState','VehicleMakeCode','VehicleYear')
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ACVRV'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (ACVR Plate + ACVRV VIN -- invented) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. AzAzdpsDriverLicenseQuery -- single QIDM, 4 combinations
# XML: AzAzdpsDriverLicenseQuery v3 -- all 3 DQ paths share keyRef DQ (duplicate).
#   DQ  (OLN):  set[OperatorLicenseNumber], any[State]
#   DQN (Name): set[Name, SexCode, BirthDate], any[State]     <- invented keyRef
#   DQSS (SSN): set[SocialSecurityNumber]                     <- invented keyRef
#   ACWL (Badge+Name): set[BadgeNumber, BirthDate, Name, SexCode], any[OLN, State]
# autoSelect=true: single QIDM for all DL paths (no LIMITATION #2 risk).
# Sex: codeTypeProvider=NIBRS (AZ NIBRS confirmed -- attr ID -> M/F/U in CommSys XML).
# Date: yyyyMMdd (AZ format -- NOT MMddyyyy like NJ).
# Name: FormatStringRuleHandler(',' ' ' ' ') -> "Last, First Middle Suffix".
# DH-suffix: DL sourceFields are bare (NameLast not NameLastDH) -- no cross-fire with DH QIDM.
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';           size = 4;  sourceField = @('dexStateUserId');        targetField = 'BadgeNumber' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'SocialSecurityNumber';  size = 9;  sourceField = @('SocialSecurityNumber');  targetField = 'SocialSecurityNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationState');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ: OLN path
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('OperatorLicenseNumber')
                any = @('dexStateUserId','BirthDate','NameFirst','NameLast','NameMiddle','NameSuffix','RegistrationState','SexCode','SocialSecurityNumber')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # DQN: Name path (invented -- XML has DQ for all three paths)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','SexCode','BirthDate')
                any = @('dexStateUserId','NameMiddle','NameSuffix','OperatorLicenseNumber','RegistrationState','SocialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        # DQSS: SSN path (invented)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('SocialSecurityNumber')
                any = @('dexStateUserId','BirthDate','NameFirst','NameLast','NameMiddle','NameSuffix','OperatorLicenseNumber','RegistrationState','SexCode')
            }
            primaryFieldReference = 'SocialSecurityNumber'
            keyReference          = 'DQSS'
            state                 = 'In/Out'
        }
        # ACWL: Badge + Name (MVD/ACIC path -- most specific; Badge in set[])
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','BirthDate','NameLast','NameFirst','SexCode')
                any = @('NameMiddle','NameSuffix','OperatorLicenseNumber','RegistrationState','SocialSecurityNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACWL'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for AzAzdpsDriverLicenseQuery (DQ OLN + DQN Name + DQSS SSN + ACWL Badge) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_AzAzdpsDriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'AzAzdpsDriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- single QIDM, 2 combinations
# XML: DriverHistoryQuery v3 -- both OLN and Name paths use keyRef KQ (duplicate).
# KQ  (OLN):  set[State, OperatorLicenseNumber], any[PurposeCode, Attention]
# KQH (Name): set[State, Name, BirthDate, SexCode], any[PurposeCode, Attention]  <- invented
# Provider routes by XML field content (OLN vs Name present), not keyRef.
# DALL+DALH pattern (confirmed NY v1.19): invented keyRef passes import, provider ignores it.
#
# DH-suffix isolation: all DH sourceFields use -DH suffix (never conflicts with DL fieldIds).
# StateDH: hidden InpH with initialValue='AZ' (plain text -- no NCIC conversion needed).
#   State is mandatory in DH set[] and always AZ for this provider.
# Sex: codeTypeProvider=NIBRS (AZ confirmed; same as DL).
# Date: yyyyMMdd (AZ format).
# Name: FormatStringRuleHandler(',' ' ' ' ') -> "Last, First Middle Suffix" (DH-suffix source fields).
# =====================================================================
$dhistQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention';             size = 30; sourceField = @('Attention');               targetField = 'Attention' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('PurposeCode');             targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('StateDH');                 targetField = 'State' }
    )
    combinations = @(
        # KQ: OLN path (State mandatory in set[] -- always AZ via hidden StateDH)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('StateDH','OperatorLicenseNumberDH')
                any = @('Attention','BirthDateDH','NameFirstDH','NameLastDH','NameMiddleDH','NameSuffixDH','PurposeCode','SexCodeDH')
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
        # KQH: Name path (invented keyRef -- XML has KQ for both paths)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('StateDH','NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH')
                any = @('Attention','NameMiddleDH','NameSuffixDH','OperatorLicenseNumberDH','PurposeCode')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery (KQ OLN + KQH Name -- invented; DALL+DALH pattern) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery (ACQG)
# XML: GunQuery v3, keyRef ACQG
# set[BadgeNumber, GunSerialNumber], any[GunMake, GunModel, GunCaliber, RelatedHitSearchIndicator]
# GunMake/GunModel/GunCaliber: free-text FormInput (no confirmed AZ code list in XML).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'GunCaliber';               size = 4;  sourceField = @('GunCaliber');               targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                  size = 4;  sourceField = @('GunMake');                  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                 size = 11; sourceField = @('GunModel');                 targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';          size = 11; sourceField = @('GunSerialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','GunSerialNumber')
                any = @('GunCaliber','GunMake','GunModel','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'ACQG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (ACQG) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery (ACQA)
# XML: ArticleSingleQuery v2, keyRef ACQA
# set[BadgeNumber, ArticleTypeCode, ArticleSerialNumber], any[RelatedHitSearchIndicator]
# ArticleTypeCode: codeTypeCategory=NCIC_ARTICLE_TYPE, codeTypeSource=CA_CLETS
#   (AP #7: NCIC_ARTICLE_TYPE lives under CA_CLETS source, not NCIC -- confirmed NJ/NY)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';      size = 11; sourceField = @('ArticleSerialNumber');      targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';          size = 7;  sourceField = @('ArticleTypeCode');          targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','ArticleTypeCode','ArticleSerialNumber')
                any = @('RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'ArticleTypeCode'
            keyReference          = 'ACQA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (ACQA) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- single QIDM, 4 combinations
# XML: BoatQuery v3 -- ACQB and BQ each have 2 paths (duplicate keyRefs).
#   ACQB (Reg+Badge):  set[BadgeNumber, RegistrationNumber]
#   ACQBH (Hull+Badge): set[BadgeNumber, BoatHullIdNumber]         <- invented keyRef
#   BQ (Reg):          set[RegistrationNumber]
#   BQH (Hull):        set[BoatHullIdNumber]                       <- invented keyRef
# ACQB/ACQBH require BadgeNumber (ACIC access).
# BQ/BQH do not require BadgeNumber (MVD access -- officer may not have badge in field).
# Combination ordering: most specific (Badge required) first.
# State: RegistrationState (attributeTypeId=STATE, initialValue=AZ, NCIC confirmed).
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber';              size = 4;  sourceField = @('dexStateUserId');           targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';         size = 20; sourceField = @('BoatHullIdNumber');         targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';       size = 8;  sourceField = @('RegistrationNumber');       targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State';                    size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # ACQB: Reg + Badge (ACIC -- Badge required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','RegistrationNumber')
                any = @('BoatHullIdNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ACQB'
            state                 = 'In/Out'
        }
        # ACQBH: Hull + Badge (ACIC -- invented keyRef)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','BoatHullIdNumber')
                any = @('RegistrationNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ACQBH'
            state                 = 'In/Out'
        }
        # BQ: Reg only (MVD -- no Badge required)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('RegistrationNumber')
                any = @('dexStateUserId','BoatHullIdNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        # BQH: Hull only (MVD -- invented keyRef)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('BoatHullIdNumber')
                any = @('dexStateUserId','RegistrationNumber','RegistrationState','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (ACQB+ACQBH Badge, BQ+BQH no-Badge) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# =====================================================================
# 1j. WMPIWantedPersonInquiry -- single QIDM, 2 combinations
# XML: 11+ ACQW combinations (all duplicate keyRef).
# Phase 1: implement 2 most practical paths:
#   ACQW  = Name+DOB+Sex+Race (primary -- set[NameLast,NameFirst,BirthDate,SexCode,RaceCode])
#   ACQWN = NCICNumber (quick lookup -- invented keyRef)
# Remaining paths (FBINumber, SSN, OLN, VIN, Plate, CaseNumber) deferred to Phase 2.
# Shares NameLast/NameFirst/NameMiddle/NameSuffix/BirthDate/SexCode fieldIds with DL QIDM.
# Cross-fire prevention: RaceCode is in ACQW set[] but NOT in DL Name (DQN) set[].
#   -> If operator does not fill RaceCode, ACQW will not fire during DL name searches.
# =====================================================================
$wantedQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'ExpandedBirthDateSearchCode'; size = 1; sourceField = @('ExpandedBirthDateSearchCode'); targetField = 'ExpandedBirthDateSearchCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';    size = 1;  sourceField = @('ExpandedNameSearchCode');    targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('NCICNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                  size = 1;  sourceField = @('RaceCode');                  targetField = 'RaceCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('RelatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                   size = 1;  sourceField = @('SexCode');                   targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
    )
    combinations = @(
        # ACQW: Name + DOB + Sex + Race (primary path)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NameLast','NameFirst','BirthDate','SexCode','RaceCode')
                any = @('ExpandedBirthDateSearchCode','ExpandedNameSearchCode','NameMiddle','NameSuffix','NCICNumber','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQW'
            state                 = 'In/Out'
        }
        # ACQWN: NCICNumber quick lookup (invented -- XML has ACQW for all paths)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NCICNumber')
                any = @('BirthDate','ExpandedBirthDateSearchCode','ExpandedNameSearchCode','NameFirst','NameLast','NameMiddle','NameSuffix','RaceCode','RelatedHitSearchIndicator','SexCode')
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'ACQWN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for WMPIWantedPersonInquiry (ACQW Name+DOB+Sex+Race + ACQWN NCIC) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_WMPIWantedPersonInquiry'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'WMPIWantedPersonInquiry'
    queryLabel      = 'Wanted Person'
    targetEntity    = 'Person'
}

# =====================================================================
# 1k. WMPIMissingPersonInquiry -- single QIDM, 2 combinations
# XML: WMPIMissingPersonInquiry v1 -- 2 ACQM combinations (duplicate keyRef).
#   ACQM #1: set[Age,SexCode,RaceCode,Height,Weight,EyeColorCode,HairColorCode,Name]
#            any[FormORI, ExpandedNameSearchCode, AreaCode]
#   ACQM #2: set[NCICNumber], any[FormORI, RelatedHitSearchIndicator]
# DESIGN: ACQM (Name+descriptors) + ACQMN (NCICNumber -- invented keyRef)
# Cross-fire prevention: Age is in ACQM set[] but absent from all DL/DH/Wanted set[].
#   -> ACQM fires ONLY when Age is filled. No cross-contamination risk.
# Note: Missing uses Age (not BirthDate) -- different from Wanted/DL.
# =====================================================================
$missingQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Age';                      size = 2;  sourceField = @('Age');                      targetField = 'Age' }
        [PSCustomObject]@{ name = 'AreaCode';                 size = 3;  sourceField = @('AreaCode');                 targetField = 'AreaCode' }
        [PSCustomObject]@{ name = 'ExpandedNameSearchCode';   size = 1;  sourceField = @('ExpandedNameSearchCode');   targetField = 'ExpandedNameSearchCode' }
        [PSCustomObject]@{ name = 'EyeColorCode';             size = 3;  sourceField = @('EyeColorCode');             targetField = 'EyeColorCode' }
        [PSCustomObject]@{ name = 'FormORI';                  size = 9;  sourceField = @('FormORI');                  targetField = 'FormORI' }
        [PSCustomObject]@{ name = 'HairColorCode';            size = 3;  sourceField = @('HairColorCode');            targetField = 'HairColorCode' }
        [PSCustomObject]@{ name = 'Height';                   size = 3;  sourceField = @('Height');                   targetField = 'Height' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','NameMiddle','NameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'NCICNumber';               size = 10; sourceField = @('NCICNumber');               targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'RaceCode';                 size = 1;  sourceField = @('RaceCode');                 targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('RelatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'SexCode';                  size = 1;  sourceField = @('SexCode');                  targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'Weight';                   size = 3;  sourceField = @('Weight');                   targetField = 'Weight' }
    )
    combinations = @(
        # ACQM: Name + physical descriptors (Age in set[] prevents cross-fire with DL/Wanted)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('Age','SexCode','RaceCode','Height','Weight','EyeColorCode','HairColorCode','NameLast','NameFirst')
                any = @('AreaCode','ExpandedNameSearchCode','FormORI','NameMiddle','NameSuffix','NCICNumber','RelatedHitSearchIndicator')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACQM'
            state                 = 'In/Out'
        }
        # ACQMN: NCICNumber quick lookup (invented -- XML has ACQM for both paths)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('NCICNumber')
                any = @('Age','AreaCode','ExpandedNameSearchCode','EyeColorCode','FormORI','HairColorCode','Height','NameFirst','NameLast','NameMiddle','NameSuffix','RaceCode','RelatedHitSearchIndicator','SexCode','Weight')
            }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'ACQMN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for WMPIMissingPersonInquiry (ACQM Name+descriptors + ACQMN NCIC) in AZ AZDPS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_WMPIMissingPersonInquiry'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'WMPIMissingPersonInquiry'
    queryLabel      = 'Missing Person'
    targetEntity    = 'Person'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# Phase 1: single entity, single card per form. No multi-card. No split entity.
# All query paths for an entity are on one card -- confirms all QIDMs before Phase 2 UX work.
# =====================================================================

# ------------------------------------------------------------------
# VEHICLE -- 1 card (VEHICLE SEARCH)
# Plate+Badge (ACVR) and VIN+Badge (ACVRV) on same card.
# RegistrationState: attributeTypeId=STATE, initialValue=AZ (NCIC confirmed).
#   -> QIDM codeTypeProvider=NCIC converts attr ID to 2-letter code for CommSys.
#   -> RMS useAttributeId=True passes attr ID for elastic state filter (Patch 1).
# ------------------------------------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','6'); fields = @(
                @{ id = 'LicPlate_Input';  node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'State_Veh_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Veh'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_VEH_BADGE' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'PlateType_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'PlateYear_Input'; node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' }
                @{ id = 'VIN_Input';       node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'Make_Veh_Input'; node = Sel 'VehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_3' }
                @{ id = 'Year_Veh_Input'; node = Inp 'VehicleYear' 'Year' '4' 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate+Badge (ACVR) and VIN+Badge (ACVRV) on single card. Phase 1.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'AZ_AZDPS_VehicleForm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# PERSON -- 1 card (PERSON SEARCH)
# Phase 1 single-card includes ALL person query fields:
#   DL OLN:     OperatorLicenseNumber + RegistrationState -> DQ fires
#   DL Name:    NameLast/First/Middle/Suffix + BirthDate + SexCode -> DQN fires
#   DL SSN:     SocialSecurityNumber -> DQSS fires
#   DL Badge:   BadgeNumber + Name + BirthDate + SexCode -> ACWL fires
#   DH OLN:     OperatorLicenseNumberDH + StateDH(hidden='AZ') -> KQ fires [DH-suffix]
#   DH Name:    NameLastDH/FirstDH/MiddleDH/SuffixDH + BirthDateDH + SexCodeDH -> KQH fires
#   Wanted:     NameLast/First + BirthDate + SexCode + RaceCode -> ACQW fires
#   Wanted NCIC: NCICNumber -> ACQWN fires
#   Missing:    NameLast/First + Age + Sex + Race + physical -> ACQM fires
#   Missing NCIC: NCICNumber -> ACQMN fires
#
# Cross-fire prevention:
#   DL vs Wanted: RaceCode in ACQW set[] (DQN has no RaceCode) -- fill Race only for Wanted.
#   DL vs Missing: Age in ACQM set[] (unique to Missing) -- fill Age only for Missing.
#   DL vs DH: DH-suffix fieldIds ensure DL QIDMs never co-fire DH and vice versa.
#
# StateDH: hidden InpH initialValue='AZ' (mandatory in DH set[]; always AZ for this provider).
# RegistrationState: visible, attributeTypeId=STATE, initialValue=AZ (for DL and RMS Patch 3).
# ------------------------------------------------------------------
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER'
        title = 'PERSON SEARCH'
        rows  = @(
            # -- Driver License: OLN / SSN --
            @{ id = 'ROW_PER_1'; cols = @('6','6'); fields = @(
                @{ id = 'OLN_Per_Input';   node = Inp 'OperatorLicenseNumber' 'License Number (DL)' '20' 'ROW_PER_1' }
                @{ id = 'SSN_Per_Input';   node = Inp 'SocialSecurityNumber' 'SSN' '9' 'ROW_PER_1' }
            )}
            @{ id = 'ROW_PER_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Per'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_PER_BADGE' }
            )}
            @{ id = 'ROW_PER_1B'; cols = @('6','6'); fields = @(
                @{ id = 'State_Per_Input'; node = Sel 'RegistrationState' 'State (DL)' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_PER_1B' }
            )}
            # -- Driver License: Name path --
            @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '20' 'ROW_PER_2' }
            )}
            @{ id = 'ROW_PER_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'M.I.'         '20' 'ROW_PER_3' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'        '4' 'ROW_PER_3' }
                @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'     'ROW_PER_3' }
                @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            # -- Driver History: OLN path (DH-suffix fieldIds) --
            @{ id = 'ROW_PER_4'; cols = @('8','4'); fields = @(
                @{ id = 'OLN_DH_Input';    node = Inp 'OperatorLicenseNumberDH' 'License Number (DH)' '20' 'ROW_PER_4' }
                @{ id = 'Purpose_DH_Input';node = Inp 'PurposeCode' 'Purpose Code' '1' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_4B'; cols = @('12'); fields = @(
                @{ id = 'Attention_DH_Input'; node = Inp 'Attention' 'Attention (DH)' '30' 'ROW_PER_4B' }
            )}
            # -- Driver History: Name path (DH-suffix fieldIds) --
            @{ id = 'ROW_PER_5'; cols = @('6','6'); fields = @(
                @{ id = 'NameLastDH_Input';  node = Inp 'NameLastDH'  'Last Name (DH)'  '30' 'ROW_PER_5' }
                @{ id = 'NameFirstDH_Input'; node = Inp 'NameFirstDH' 'First Name (DH)' '20' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'M.I. (DH)'    '20' 'ROW_PER_6' }
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix (DH)'   '4' 'ROW_PER_6' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'BirthDateDH'  'DOB (DH)'          'ROW_PER_6' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'SexCodeDH' 'Sex (DH)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_6' }
            )}
            # -- Wanted / Missing: NCIC Number (shared -- ACQWN and ACQMN) --
            @{ id = 'ROW_PER_7'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCIC_Input';    node = Inp 'NCICNumber'             'NCIC Number'        '10' 'ROW_PER_7' }
                @{ id = 'RaceCode_Input';node = Sel 'RaceCode' 'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' } 'ROW_PER_7' }
                @{ id = 'RelHit_Input';  node = Inp 'RelatedHitSearchIndicator' 'Related Hit'     '1'  'ROW_PER_7' }
            )}
            # -- Missing Person: physical descriptors (Age triggers ACQM, not present in Wanted/DL) --
            @{ id = 'ROW_PER_8'; cols = @('2','2','2','3','3'); fields = @(
                @{ id = 'Age_Input';    node = Inp 'Age'    'Age'    '2' 'ROW_PER_8' }
                @{ id = 'Height_Input'; node = Inp 'Height' 'Height' '3' 'ROW_PER_8' }
                @{ id = 'Weight_Input'; node = Inp 'Weight' 'Weight' '3' 'ROW_PER_8' }
                @{ id = 'Eye_Input';    node = Sel 'EyeColorCode'  'Eye Color'  @{ codeTypeCategory = 'NCIC_EYE_COLOR';  codeTypeSource = 'NCIC' } 'ROW_PER_8' }
                @{ id = 'Hair_Input';   node = Sel 'HairColorCode' 'Hair Color' @{ codeTypeCategory = 'NCIC_HAIR_COLOR'; codeTypeSource = 'NCIC' } 'ROW_PER_8' }
            )}
            @{ id = 'ROW_PER_9'; cols = @('4','4','4'); fields = @(
                @{ id = 'ExpandName_Input'; node = Inp 'ExpandedNameSearchCode'      'Exp Name Search' '1' 'ROW_PER_9' }
                @{ id = 'ExpandDOB_Input';  node = Inp 'ExpandedBirthDateSearchCode' 'Exp DOB Search'  '1' 'ROW_PER_9' }
                @{ id = 'AreaCode_Input';   node = Inp 'AreaCode'                    'Area Code'       '3' 'ROW_PER_9' }
            )}
            @{ id = 'ROW_PER_10'; cols = @('6','6'); fields = @(
                @{ id = 'FormORI_Input'; node = Inp 'FormORI' 'Form ORI' '9' 'ROW_PER_10' }
            )}
            # -- Hidden: StateDH (always 'AZ' -- mandatory in KQ/KQH set[]) --
            @{ id = 'ROW_PER_STATE_DH'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'StateDH_Input'; node = InpH 'StateDH' 'State (DH)' @{ initialValue = 'AZ' } 'ROW_PER_STATE_DH' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (DQ/DQN/DQSS/ACWL) + DH (KQ/KQH DH-suffix) + Wanted (ACQW/ACQWN) + Missing (ACQM/ACQMN) on single card. Phase 1.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'AZ_AZDPS_PersonForm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# FIREARM -- 1 card (FIREARM SEARCH)
# BadgeNumber and GunSerialNumber required (ACQG).
# GunMake/GunModel/GunCaliber: free-text (no confirmed AZ code list in XML).
# ------------------------------------------------------------------
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_FA'
        title = 'FIREARM SEARCH'
        rows  = @(
            @{ id = 'ROW_FA_1'; cols = @('12'); fields = @(
                @{ id = 'Serial_FA_Input'; node = Inp 'GunSerialNumber' 'Serial Number' '11' 'ROW_FA_1' }
            )}
            @{ id = 'ROW_FA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_FA'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_FA_BADGE' }
            )}
            @{ id = 'ROW_FA_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'Make_FA_Input';   node = Inp 'GunMake'    'Make'    '4'  'ROW_FA_2' }
                @{ id = 'Model_FA_Input';  node = Inp 'GunModel'   'Model'   '11' 'ROW_FA_2' }
                @{ id = 'Cal_FA_Input';    node = Inp 'GunCaliber' 'Caliber' '4'  'ROW_FA_2' }
            )}
            @{ id = 'ROW_FA_3'; cols = @('4'); fields = @(
                @{ id = 'RelHit_FA_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_FA_3' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm queries -- ACQG (Badge+Serial required). Phase 1.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'AZ_AZDPS_FirearmForm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# ARTICLE -- 1 card (ARTICLE SEARCH)
# BadgeNumber, ArticleTypeCode, ArticleSerialNumber all required (ACQA).
# ArticleTypeCode: NCIC_ARTICLE_TYPE under CA_CLETS source (AP #7 -- confirmed NJ/NY).
# ------------------------------------------------------------------
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('5','7'); fields = @(
                @{ id = 'Type_ART_Input';   node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'Serial_ART_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '11' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_ART'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_ART_BADGE' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('4'); fields = @(
                @{ id = 'RelHit_ART_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y)' '1' 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article queries -- ACQA (Badge+TypeCode+Serial required). Phase 1.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'AZ_AZDPS_ArticleForm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# BOAT -- 1 card (BOAT SEARCH)
# ACQB/ACQBH: BadgeNumber required (ACIC).
# BQ/BQH: BadgeNumber optional (MVD -- no badge needed in field).
# RegistrationState: attributeTypeId=STATE, initialValue=AZ (NCIC confirmed).
# ------------------------------------------------------------------
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('8','4'); fields = @(
                @{ id = 'Reg_BOA_Input';   node = Inp 'RegistrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'State_BOA_Input'; node = Sel 'RegistrationState'  'State' @{ attributeTypeId = 'STATE'; initialValue = 'AZ' } 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_BOA'; node = InpH 'dexStateUserId' 'Badge (auto)' @{} 'ROW_BOA_BADGE' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('8','4'); fields = @(
                @{ id = 'Hull_BOA_Input';   node = Inp 'BoatHullIdNumber'          'Hull ID Number'  '20' 'ROW_BOA_2' }
                @{ id = 'RelHit_BOA_Input'; node = Inp 'RelatedHitSearchIndicator' 'Related Hit (Y)'  '1' 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- ACQB+ACQBH (Badge required) and BQ+BQH (no Badge) on single card. Phase 1.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'AZ_AZDPS_BoatForm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

# =====================================================================
# BUNDLE 3: RMS -- cloned from HIDLE.json
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
if (-not $rmsBundle) {
    $rmsBundle = $hidle.bundles | Where-Object { $_.name -notin @('NY_NYSPIN_EJUSTICE','ENTITIES') } | Select-Object -First 1
}

# =====================================================================
# ASSEMBLE FINAL JSON
# type='BUNDLE' required on both provider and ENTITIES bundle objects.
# ENTITIES order must be nested object {default/CAD_DISPATCH/FIRST_RESPONDER}, not flat array.
# =====================================================================

$providerConfigs = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhistQuery, $gunQuery, $artQuery, $boatQuery, $wantedQuery, $missingQuery)
$entityConfigs   = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

$final = [PSCustomObject]@{
    bundles = @(
        [PSCustomObject]@{
            name           = 'AZ_AZDPS'
            type           = 'BUNDLE'
            configurations = $providerConfigs
        }
        [PSCustomObject]@{
            name           = 'ENTITIES'
            type           = 'BUNDLE'
            order          = [PSCustomObject]@{
                default         = @('Vehicle','Person','Firearm','Article','Boat')
                CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
                FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
            }
            configurations = $entityConfigs
            provider       = 'MARK43'
        }
        $rmsBundle
    )
}

# =====================================================================
# RMS PATCHES
# AZ NIBRS confirmed: keep sex/race in RMS (DO NOT remove -- unlike FL/NY).
# =====================================================================

# PATCH 1: RMS Vehicle QIDM -- remove LicensePlateYear from combination any[]
# LicensePlateYear has no RMS elastic mapping -- causes import warning if left in.
$rmsVehicleQidm = $final.bundles | Where-Object { $_.name -eq 'RMS' } |
    ForEach-Object { $_.configurations } |
    Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq 'Vehicle' } |
    Select-Object -First 1
if ($rmsVehicleQidm) {
    foreach ($combo in $rmsVehicleQidm.combinations) {
        if ($combo.requirements.any) {
            $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'LicensePlateYear' })
        }
    }
    Write-Host "  [PATCH 1] RMS Vehicle: LicensePlateYear removed from combination any[]." -ForegroundColor Cyan
}

# PATCH 2: RMS QIDMs -- autoSelect=true (HIDLE may have it absent or false)
$rmsBundleRef = $final.bundles | Where-Object { $_.name -eq 'RMS' } | Select-Object -First 1
foreach ($cfg in $rmsBundleRef.configurations) {
    if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') {
        $cfg | Add-Member -NotePropertyName 'autoSelect' -NotePropertyValue $true -Force
    }
}
Write-Host "  [PATCH 2] RMS QIDMs: autoSelect=true applied." -ForegroundColor Cyan

# =====================================================================
# OUTPUT
# =====================================================================
$json = $final | ConvertTo-Json -Depth 100
$json | Out-File -FilePath $OUT    -Encoding UTF8
$json | Out-File -FilePath $VEROUT -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " AZ_AZDPS v${Version} build complete"      -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host " Output:  $OUT"
Write-Host " Archive: $VEROUT"
Write-Host ""

# =====================================================================
# VALIDATOR
# =====================================================================
$validatorPath = "$DIR\scripts\validate_az_azdps.ps1"
if (Test-Path $validatorPath) {
    Write-Host "Running validator..." -ForegroundColor Yellow
    & powershell.exe -ExecutionPolicy Bypass -File $validatorPath -JsonPath $OUT
} else {
    Write-Host "Validator not found at $validatorPath -- skipping." -ForegroundColor Yellow
    Write-Host "Run validator manually before import." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next: Import AZ_AZDPS.json into ConnectCIC and run post-import checklist." -ForegroundColor Yellow
Write-Host "      See docs\AZ_AZDPS_STATUS.txt for checklist." -ForegroundColor Yellow
