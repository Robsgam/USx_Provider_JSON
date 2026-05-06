# build_hi_hcjdc_ofml_mc.ps1  -- HI_HCJDC_OFML v1.0-mc MC VARIANT
# Multi-card layout. QIDMs identical to BASE. Layout-only changes.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_hi_hcjdc_ofml_mc.ps1
#
# MC LAYOUT (5 QIFs, multi-card where applicable):
#   Vehicle: 3 cards (OPTIONS, PLATE SEARCH, VIN SEARCH)
#   Person:  3 cards (OPTIONS, LICENSE NUMBER, NAME SEARCH)
#   Firearm: 1 card
#   Article: 1 card
#   Boat:    3 cards (OPTIONS, REGISTRATION, HULL)

param(
    [string]$Version = "1.0",
    [string]$Phase   = "mc"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\HI_HCJDC_OFML_MC.json"
$VEROUT   = "$PHASEDIR\HI_HCJDC_OFML_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS (identical to BASE)
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
# BUNDLE 1: HI_HCJDC_OFML PROVIDER (identical to BASE -- QIDMs don't change)
# =====================================================================

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

$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'HI_HCJDC_OFML_Results'
$results.description = 'Results mapping for HI HCJDC OFML'
$results.provider    = 'HI_HCJDC_OFML'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'HI_HCJDC_OFML_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'HI_HCJDC_OFML'
}

# VehicleRegistrationQuery QIDM (identical to BASE)
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
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleTypeCode','LicensePlateNumber'); any = @('ImageIndicator') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'M55L'; state = 'In' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleTypeCode','VehicleIdentificationNumber'); any = @('ImageIndicator') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'M55S'; state = 'In' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('ImageIndicator') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'RQ'; state = 'Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','VehicleMakeCode'); any = @('ImageIndicator') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'QVV'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @('ImageIndicator') }; primaryFieldReference = 'LicensePlateNumber'; keyReference = 'QVP'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('ImageIndicator') }; primaryFieldReference = 'VehicleIdentificationNumber'; keyReference = 'RQV'; state = 'Out' }
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

# DriverLicenseQuery QIDM (identical to BASE)
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }; size = 30; sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @() }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'DQN'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @() }; primaryFieldReference = 'Name'; keyReference = 'DQ'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @() }; primaryFieldReference = 'Name'; keyReference = 'QW'; state = 'In/Out' }
    )
    description     = 'DriverLicenseQuery -- DQN (OLN), DQ (Name+Sex+DOB), QW (Wanted Person).'
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

# DriverHistoryQuery QIDM (identical to BASE)
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention' }
        [PSCustomObject]@{ name = 'BirthDate'; rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate' }
        [PSCustomObject]@{ name = 'Name'; rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }; size = 30; sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix'); targetField = 'Name' }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode'; size = 1; sourceField = @('PurposeCode'); targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1; sourceField = @('SexCode'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @() }; primaryFieldReference = 'OperatorLicenseNumber'; keyReference = 'KQN'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @() }; primaryFieldReference = 'Name'; keyReference = 'KQ'; state = 'In/Out' }
    )
    description     = 'DriverHistoryQuery -- KQN (OLN), KQ (Name+Sex+DOB).'
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

# GunQuery QIDM (identical to BASE)
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber'; size = 4; sourceField = @('GunCaliber'); targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake'; size = 10; sourceField = @('GunMake'); targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel'; size = 20; sourceField = @('GunModel'); targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 20; sourceField = @('GunSerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('GunSerialNumber'); any = @() }; primaryFieldReference = 'GunSerialNumber'; keyReference = 'QG'; state = 'In/Out' }
    )
    description     = 'GunQuery -- QG.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# ArticleSingleQuery QIDM (identical to BASE)
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('ArticleSerialNumber'); targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode'; size = 7; sourceField = @('ArticleTypeCode'); targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @() }; primaryFieldReference = 'ArticleSerialNumber'; keyReference = 'QA'; state = 'In/Out' }
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

# BoatQuery QIDM (identical to BASE)
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber'; size = 20; sourceField = @('BoatHullIdNumber'); targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1; sourceField = @('RelatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @() }; primaryFieldReference = 'RegistrationNumber'; keyReference = 'BQ'; state = 'In/Out' }
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @() }; primaryFieldReference = 'BoatHullIdNumber'; keyReference = 'QB'; state = 'In/Out' }
    )
    description     = 'BoatQuery -- BQ (Reg), QB (Stolen/Hull).'
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
    description    = "Provider configuration for HI_HCJDC_OFML v${Version} MC"
    name           = 'HI_HCJDC_OFML'
    type           = 'BUNDLE'
    provider       = 'HI_HCJDC_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- MC VARIANT (multi-card layouts)
# =====================================================================

# Vehicle -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_VEH_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'HI' } 'ROW_VEH_O1' }
                @{ id = 'VehicleTypeCode_Input';   node = Inp 'VehicleTypeCode' 'Type Code' '1' 'ROW_VEH_O1' @{ initialValue = '1' } }
                @{ id = 'ImageIndicator_Input';    node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_PLATE'
        title = 'PLATE SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_P1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_P1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_P1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_P1' @{ initialValue = '2026' } }
            )}
        )
    }
    @{
        id    = 'CARD_VEH_VIN'
        title = 'VIN SEARCH'
        rows  = @(
            @{ id = 'ROW_VEH_V1'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_V1' }
            )}
            @{ id = 'ROW_VEH_V2'; cols = @('4','4'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_V2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear' 'Vehicle Year' '4' 'ROW_VEH_V2' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- MC: OPTIONS + PLATE + VIN cards.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 3 cards: OPTIONS, LICENSE NUMBER, NAME SEARCH
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_PER_O1'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'HI' } 'ROW_PER_O1' }
                @{ id = 'Attention_Input';         node = Inp 'Attention'    'Attention'    '30' 'ROW_PER_O1' }
                @{ id = 'PurposeCode_Input';       node = Sel 'PurposeCode' 'Purpose Code' @{ attributeTypeId = 'DEX_INQUIRY_PURPOSE_CODE' } 'ROW_PER_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_OLN'
        title = 'LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_PER_L1'; cols = @('12'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_L1' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_PER_N1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_N1' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_N1' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_N1' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'      '30' 'ROW_PER_N1' }
            )}
            @{ id = 'ROW_PER_N2'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_N2' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_N2' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- MC: OPTIONS + LICENSE NUMBER + NAME SEARCH cards.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card (same as BASE)
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
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Sel 'RelatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
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

# Article -- 1 card (same as BASE)
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
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Sel 'RelatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
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

# Boat -- 3 cards: OPTIONS, REGISTRATION, HULL
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_OPT'
        title = 'OPTIONS'
        rows  = @(
            @{ id = 'ROW_BOA_O1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'HI' } 'ROW_BOA_O1' }
                @{ id = 'RelatedSearchHitIndicator_Input'; node = Sel 'RelatedSearchHitIndicator' 'Search Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_O1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_REG'
        title = 'REGISTRATION'
        rows  = @(
            @{ id = 'ROW_BOA_R1'; cols = @('12'); fields = @(
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_R1' }
            )}
        )
    }
    @{
        id    = 'CARD_BOA_HULL'
        title = 'HULL'
        rows  = @(
            @{ id = 'ROW_BOA_H1'; cols = @('12'); fields = @(
                @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_H1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- MC: OPTIONS + REGISTRATION + HULL cards.'
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
    description    = 'Entity form configurations -- MC variant (5 QIFs, multi-card)'
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
# BUNDLE 3: RMS (identical to BASE)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }

$plateInCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

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

# Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)
$json = $json -replace 'LicensePlateNumberIn', 'licensePlateNumber'
$jsonReadable = $jsonReadable -replace 'LicensePlateNumberIn', 'licensePlateNumber'

$OUTREADABLE = "$DIR\HI_HCJDC_OFML_MC_READABLE.json"
[System.IO.File]::WriteAllText($OUT,         $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREADABLE, $jsonReadable, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,      $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built HI_HCJDC_OFML_MC.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $OUTREADABLE"
Write-Host "  -> $VEROUT"

$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host ""
    Write-Host "Running structural validation..." -ForegroundColor Cyan
    powershell.exe -ExecutionPolicy Bypass -File $VALIDATOR -Path $OUT
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."
