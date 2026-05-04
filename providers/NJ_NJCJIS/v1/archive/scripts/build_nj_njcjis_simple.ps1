# build_nj_njcjis_simple.ps1
#
# SIMPLE VARIANT -- Non-split entity, non-multi-card
#
# Based on MC variant: non-split (one QIF per entity type, NJ+OOS combined).
# Further simplified: every QIF has exactly ONE card.
#
# CHANGES vs MC:
#   Person:  MC has 2 cards (OLN + Name). Simple has 1 card with all fields.
#   Boat:    MC has 2 cards (Registration + Hull). Simple has 1 card with all fields.
#   Vehicle, Firearm, Article: already single-card in MC -- unchanged.
#
# QIDMs: IDENTICAL to MC variant. Combinations route by field presence.
#   Person DQN fires when OLN populated; DQ fires when Name+DOB populated.
#   Boat BQ fires when RegistrationNumber populated; BQN fires when HullId populated.
#
# OUTPUT: NJ_NJCJIS_simple.json
# =====================================================================

param(
    [string]$Version = "1.0-simple",
    [string]$Phase   = "simple_variant"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\NJ_NJCJIS_simple.json"
$VEROUT   = "$PHASEDIR\NJ_NJCJIS_simple_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\source\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS (identical to MC)
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
            $fieldIds = @($rowDef.fields | ForEach-Object { $_.id })
            $l[$rowDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rowDef.cols } $true $false $fieldIds $cardDef.id
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
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = AddCadNodes $def
        FIRST_RESPONDER = AddFrNodes  $def
    }
}

# =====================================================================
# BUNDLE 1: NJ_NJCJIS PROVIDER (identical to MC)
# =====================================================================
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');         targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');     targetField = 'Mnemonic' }
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
    description               = 'Authentication configuration for NJ NJCJIS'
    handlerFunction           = 'CommsysOriAuthenticationHandler'
    name                      = 'NJ_NJCJIS'
    type                      = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                  = 'NJ_NJCJIS'
    providerType              = 'Commsys'
    signInRequired            = $false
}

$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'NJ_NJCJIS_Results'
$results.description = 'Results mapping for NJ NJCJIS'
$results.provider    = 'NJ_NJCJIS'

$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NJ_NJCJIS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NJ_NJCJIS'
}

$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('GunMake');      targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('SerialNumber'); targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'GunCaliber';      size = 4;  sourceField = @('GunCaliber');   targetField = 'GunCaliber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SerialNumber'); any = @('GunMake','GunCaliber') }
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
    queryLabel      = 'NCIC'
    targetEntity    = 'Firearm'
}

$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumberIn';        size = 10; sourceField = @('LicensePlateNumberIn');        targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'RandomRequest';               size = 5;  sourceField = @('RandomRequest');               targetField = 'RandomRequest' }
        [PSCustomObject]@{ name = 'StateOOS';                    size = 2;  sourceField = @('RegistrationStateOOS');        targetField = 'State' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumberIn','RegistrationStateOOS'); any = @('ImageIndicator','LicensePlateTypeCode','LicensePlateYear','RandomRequest') }
            primaryFieldReference = 'LicensePlateNumberIn'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationStateOOS'); any = @('ImageIndicator','RandomRequest') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery in NJ NJCJIS (simple variant)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle'
    targetEntity    = 'Vehicle'
}

$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ') }
            size        = 30; sourceField = @('NameFirst','NameLast'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'SexCode';  size = 1; sourceField = @('SexCode');              targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'StateOOS'; size = 2; sourceField = @('RegistrationStateOOS'); targetField = 'State' }
        [PSCustomObject]@{ name = 'Image';    size = 1; sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationStateOOS'); any = @('ImageIndicator') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('SexCode','ImageIndicator','RegistrationStateOOS') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery in NJ NJCJIS (simple variant)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Person'
    targetEntity    = 'Person'
}

$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');    targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber');  targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'StateOOS';           size = 2;  sourceField = @('RegistrationStateOOS'); targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('RegistrationStateOOS') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationStateOOS') }
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
    queryLabel      = 'NCIC'
    targetEntity    = 'Boat'
}

$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber'; size = 20; sourceField = @('SerialNumber');    targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';     size = 7;  sourceField = @('ArticleTypeCode'); targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SerialNumber','ArticleTypeCode'); any = @() }
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
    queryLabel      = 'NCIC'
    targetEntity    = 'Article'
}

$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $gunQuery, $vehQuery, $dlQuery, $boatQuery, $artQuery)
    description    = "Provider configuration for NJ_NJCJIS simple variant v${Version}"
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- SIMPLE VARIANT (5 QIFs, 1 card each)
# =====================================================================

# ------------------------------------------------------------------
# Vehicle (1 card -- identical to MC)
# ------------------------------------------------------------------
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- Plate and VIN (visible State, initialValue=NJ)'
    label        = 'Vehicle'
    layout       = MakeLayouts @(
        @{
            id    = 'CARD_VEH'
            title = 'Vehicle Query'
            rows  = @(
                @{ id = 'ROW_VEH_1'; cols = @('5','5','2'); fields = @(
                    @{ id = 'LicensePlateNumberIn_Input'; node = Inp 'LicensePlateNumberIn' 'Plate Number' '10' 'ROW_VEH_1' }
                    @{ id = 'RegistrationStateOOS_Input'; node = Sel 'RegistrationStateOOS' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS'; initialValue = 'NJ' } 'ROW_VEH_1' }
                    @{ id = 'ImageIndicator_Input';       node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_VEH_1' }
                )}
                @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                    @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_2' }
                    @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_2' }
                )}
                @{ id = 'ROW_VEH_3'; cols = @('9','3'); fields = @(
                    @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_3' }
                    @{ id = 'RandomRequest_Input'; node = Sel 'RandomRequest' 'Random' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS' } 'ROW_VEH_3' }
                )}
            )
        }
    )
    name         = 'ENTITY_Vehicle_Simple'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ------------------------------------------------------------------
# Person (1 card -- SIMPLE CHANGE vs MC)
# All Person fields on one card. OLN path and Name path share the card.
# State visible (initialValue=NJ) -- used by both OLN and Name paths.
# QIDM DQN fires on OLN; DQ fires on Name+DOB. No change to combinations.
# ------------------------------------------------------------------
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- OLN and Name search on single card (visible State, initialValue=NJ)'
    label        = 'Person'
    layout       = MakeLayouts @(
        @{
            id    = 'CARD_PER'
            title = 'Person Query'
            rows  = @(
                @{ id = 'ROW_PER_1'; cols = @('5','5','2'); fields = @(
                    @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'License Number' '20' 'ROW_PER_1' }
                    @{ id = 'RegistrationStateOOS_Input';  node = Sel 'RegistrationStateOOS' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS'; initialValue = 'NJ' } 'ROW_PER_1' }
                    @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'Y' } 'ROW_PER_1' }
                )}
                @{ id = 'ROW_PER_2'; cols = @('6','6'); fields = @(
                    @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_2' }
                    @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_2' }
                )}
                @{ id = 'ROW_PER_3'; cols = @('6','6'); fields = @(
                    @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth'                                                                          'ROW_PER_3' }
                    @{ id = 'SexCode_Input';   node = Sel 'SexCode'   'Sex' @{ codeTypeCategory = 'NIBRS_SEX'; codeTypeSource = 'NIBRS' } 'ROW_PER_3' }
                )}
            )
        }
    )
    name         = 'ENTITY_Person_Simple'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ------------------------------------------------------------------
# Firearm (1 card -- identical to MC)
# ------------------------------------------------------------------
$firearmsForm = [PSCustomObject]@{
    description  = 'Input query layout for firearm entity'
    label        = 'Firearm'
    layout       = MakeLayouts @(
        @{
            id    = 'CARD_GUN'
            title = 'NCIC Firearm Query'
            rows  = @(
                @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                    @{ id = 'SerialNumber_Input'; node = Inp 'SerialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                    @{ id = 'GunMake_Input';      node = Inp 'GunMake'      'Make'          '23' 'ROW_GUN_1' }
                )}
                @{ id = 'ROW_GUN_2'; cols = @('6'); fields = @(
                    @{ id = 'GunCaliber_Input'; node = Inp 'GunCaliber' 'Caliber' '4' 'ROW_GUN_2' }
                )}
            )
        }
    )
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ------------------------------------------------------------------
# Article (1 card -- identical to MC)
# ------------------------------------------------------------------
$articleForm = [PSCustomObject]@{
    description  = 'Input query layout for article entity'
    label        = 'Article'
    layout       = MakeLayouts @(
        @{
            id    = 'CARD_ART'
            title = 'NCIC Article Query'
            rows  = @(
                @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                    @{ id = 'SerialNumber_Input';    node = Inp 'SerialNumber'    'Serial Number' '20' 'ROW_ART_1' }
                    @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                )}
            )
        }
    )
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ------------------------------------------------------------------
# Boat (1 card -- SIMPLE CHANGE vs MC)
# MC has 2 cards (Registration + Hull). Simple merges into 1 card.
# Registration Number and State on row 1; Hull ID on row 2.
# QIDM BQ fires on RegistrationNumber; BQN fires on HullId. No change.
# ------------------------------------------------------------------
$boatForm = [PSCustomObject]@{
    description  = 'Input query layout for boat entity'
    label        = 'Boat'
    layout       = MakeLayouts @(
        @{
            id    = 'CARD_BOA'
            title = 'Boat Query'
            rows  = @(
                @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                    @{ id = 'RegistrationNumber_Input';   node = Inp 'RegistrationNumber'   'Registration Number' '8'  'ROW_BOA_1' }
                    @{ id = 'RegistrationStateOOS_Input'; node = Sel 'RegistrationStateOOS' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS'; initialValue = 'NJ' } 'ROW_BOA_1' }
                )}
                @{ id = 'ROW_BOA_2'; cols = @('12'); fields = @(
                    @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_2' }
                )}
            )
        }
    )
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations -- simple variant (5 QIFs, 1 card each)'
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
# BUNDLE 3: RMS (identical patches to MC)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }

$rmsVehQidm   = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }
$plateInCombo = $rmsVehQidm.combinations  | Where-Object { $_.keyReference -eq 'licensePlateIn' }
$plateInCombo.requirements.any = @($plateInCombo.requirements.any) + 'RegistrationState'

$plateOutCombo = $rmsVehQidm.combinations | Where-Object { $_.keyReference -eq 'licensePlateOutAndState' }
$plateOutCombo.requirements.set = @('LicensePlateNumberOut')

$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Person search query' }
$rmsPersonQidm.attributes = @($rmsPersonQidm.attributes | Where-Object { $_.targetField -ne 'sexAttrId' })
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'SexCode' -and $_ -ne 'SexCodeOOS' })
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{ bundles = @($njBundle, $entitiesBundle, $rmsBundle) }
$json   = $output | ConvertTo-Json -Depth 100
$json | Set-Content $OUT    -Encoding UTF8
$json | Set-Content $VEROUT -Encoding UTF8

Write-Host "Built NJ_NJCJIS_simple.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $VEROUT"

Write-Host ""
Write-Host "Running structural validation..." -ForegroundColor Cyan
powershell.exe -ExecutionPolicy Bypass -File "$DIR\scripts\validate_nj_njcjis.ps1" -JsonFile $OUT
if ($LASTEXITCODE -ne 0) {
    Write-Host "BUILD ABORTED -- validator found errors." -ForegroundColor Red
    exit 1
}
Write-Host "Validation passed." -ForegroundColor Green
Write-Host ""
Write-Host "SIMPLE VARIANT vs MC:" -ForegroundColor Cyan
Write-Host "  QIF count: 5 (same)" -ForegroundColor Yellow
Write-Host "  Person: 1 card (OLN + Name merged) vs 2 cards in MC" -ForegroundColor Yellow
Write-Host "  Boat:   1 card (Reg + Hull merged) vs 2 cards in MC" -ForegroundColor Yellow
Write-Host "  QIDMs:  identical to MC" -ForegroundColor Yellow
Write-Host "  Routing: DQN fires on OLN entry; DQ fires on Name+DOB entry" -ForegroundColor Yellow
