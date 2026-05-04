# build_nj_njcjis_sections.ps1
# Variant of NJ_NJCJIS.json: one card per query combination per entity, each card
# opens with a header row that names the query and lists required fields.
# In-state (NJ default) and out-of-state (no default) are separate cards for
# Vehicle plate, Person OLN, and Boat registration.
#
# Card layout:
#
#   Vehicle
#     CARD_PLATE_NJ  -- In-State Plate Query (RQ)       State defaults NJ
#     CARD_PLATE_OOS -- Out-of-State Plate Query (RQ)   State blank
#     CARD_VIN       -- VIN Query (RQN)                 State defaults NJ
#
#   Person
#     CARD_OLN_NJ    -- In-State OLN Query (DQN)        State defaults NJ
#     CARD_OLN_OOS   -- Out-of-State OLN Query (DQN)    State blank
#     CARD_NAME      -- Name / DOB Query (DQ)           State optional
#
#   Firearm
#     CARD_GUN       -- Gun Query (QG)
#
#   Article
#     CARD_ART       -- Article Query (QA)
#
#   Boat
#     CARD_REG_NJ    -- In-State Registration Query (BQ)  State defaults NJ
#     CARD_REG_OOS   -- Out-of-State Registration Query   State blank
#     CARD_HULL      -- Hull ID Query (BQN)               State defaults NJ
#
# Section names are placed in each Card's title prop so they render as a card
# header with no blank input field beneath them. ALL CAPS is used for the query
# name since the platform renders card title text literally (no HTML support).
#
# Provider bundle is identical to build_nj_njcjis.ps1 v1.3.
#
# Run: powershell.exe -ExecutionPolicy Bypass -File build_nj_njcjis_sections.ps1

$DATE = (Get-Date -Format 'yyyy-MM-dd')
$DIR  = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$OUT  = "$DIR\NJ_NJCJIS_sections.json"

$hidle = Get-Content "C:\Users\RobSgambellone\.local\bin\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS  (identical to build_nj_njcjis.ps1)
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

# =====================================================================
# SPLIT-LAYOUT HELPERS
# =====================================================================
# BuildSplitLayout reads an optional 'title' key from each card definition
# and places it in the Card's props. No header rows are used.
function BuildSplitLayout($cardDefs) {
    $l = [ordered]@{}

    $cardIdList = [System.Collections.Generic.List[string]]::new()
    foreach ($cd in $cardDefs) { $cardIdList.Add($cd.id) }

    $l['ROOT']      = N 'Root' 'Root' @{} $false $false @('FORM_ROOT') ''
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false $cardIdList.ToArray() 'FORM_ROOT'

    foreach ($cd in $cardDefs) {
        $rowIdList = [System.Collections.Generic.List[string]]::new()
        foreach ($rd in $cd.rowDefs) { $rowIdList.Add($rd.id) }
        $cardProps = if ($cd.title) { @{ title = $cd.title } } else { @{} }
        $l[$cd.id] = N 'Card' 'Card' $cardProps $true $false $rowIdList.ToArray() 'ROOT_PAGE'

        foreach ($rd in $cd.rowDefs) {
            $fieldIdList = [System.Collections.Generic.List[string]]::new()
            foreach ($f in $rd.fields) { $fieldIdList.Add($f.id) }
            $l[$rd.id] = N 'Row' 'Row' @{ templateColumns = [array]$rd.cols } $true $false $fieldIdList.ToArray() $cd.id
            foreach ($f in $rd.fields) {
                $l[$f.id] = $f.node
            }
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

function MakeSplitLayouts($cardDefs) {
    $def = BuildSplitLayout $cardDefs
    $cad = AddCadNodes $def
    $fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1: NJ_NJCJIS PROVIDER  (identical to build_nj_njcjis.ps1 v1.3)
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
    description                = 'Authentication configuration for NJ NJCJIS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NJ_NJCJIS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NJ_NJCJIS'
    providerType               = 'Commsys'
    signInRequired             = $false
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
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('RegistrationState');           targetField = 'State' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('LicensePlateTypeCode','LicensePlateYear','RegistrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery in NJ NJCJIS'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'DMV'
    targetEntity    = 'Vehicle'
}

$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8
            sourceField = @('BirthDate')
            targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 30
            sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix')
            targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';  size = 1;  sourceField = @('SexCode');           targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';    size = 2;  sourceField = @('RegistrationState');  targetField = 'State' }
        [PSCustomObject]@{ name = 'Image';               sourceField = @('ImageIndicator');    targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('SexCode','RegistrationState') }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery in NJ NJCJIS'
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

$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 20; sourceField = @('BoatHullIdNumber');   targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8;  sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State';              size = 2;  sourceField = @('RegistrationState');  targetField = 'State' }
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
    description    = 'Provider configuration for NJ_NJCJIS (sections variant)'
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

# =====================================================================
# BUNDLE 2: ENTITIES -- SECTION CARD LAYOUT
# =====================================================================
#
# Each card opens with a header row (Hdr) that labels the query type and
# lists required / optional fields so the user knows what each card is for.
# Separate cards exist for in-state (NJ default) and out-of-state queries
# on Vehicle plate, Person OLN, and Boat registration.

# -----------------------------------------------------------------------
# Vehicle
#   CARD_PLATE_NJ  (RQ in-state)    -- Plate Number required; NJ default
#   CARD_PLATE_OOS (RQ out-of-state) -- Plate Number required; State required
#   CARD_VIN       (RQN)            -- VIN required; State optional
# -----------------------------------------------------------------------
$vehLayout = MakeSplitLayouts @(
    @{
        id    = 'CARD_PLATE_NJ'
        title = 'IN-STATE PLATE QUERY (RQ)  |  Required: Plate Number'
        rowDefs = @(
            @{ id = 'ROW_PN1'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateNumber_PN_Input';      node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_PN1' }
                @{ id = 'RegistrationState_PN_Input';       node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_PN1' }
            )}
            @{ id = 'ROW_PN2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_PN_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (opt)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_PN2' }
                @{ id = 'LicensePlateYear_PN_Input';     node = Inp 'LicensePlateYear' 'Plate Year (opt)' '4' 'ROW_PN2' }
            )}
        )
    }
    @{
        id    = 'CARD_PLATE_OOS'
        title = 'OUT-OF-STATE PLATE QUERY (RQ)  |  Required: Plate Number + State'
        rowDefs = @(
            @{ id = 'ROW_PO1'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateNumber_PO_Input'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_PO1' }
                @{ id = 'RegistrationState_PO_Input';  node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_PO1' }
            )}
            @{ id = 'ROW_PO2'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateTypeCode_PO_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (opt)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_PO2' }
                @{ id = 'LicensePlateYear_PO_Input';     node = Inp 'LicensePlateYear' 'Plate Year (opt)' '4' 'ROW_PO2' }
            )}
        )
    }
    @{
        id    = 'CARD_VIN'
        title = 'VIN QUERY (RQN)  |  Required: VIN  |  Optional: State'
        rowDefs = @(
            @{ id = 'ROW_V1'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_V1' }
                @{ id = 'RegistrationState_VIN_Input';       node = Sel 'RegistrationState' 'State (opt)' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_V1' }
            )}
            @{ id = 'ROW_V2'; cols = @('6','6'); fields = @(
                @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Make (opt)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_V2' }
                @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear' 'Year (opt)' '4' 'ROW_V2' @{ initialValue = '2026' } }
            )}
        )
    }
)

$vehicleForm = [PSCustomObject]@{
    description  = 'Input query layout for vehicle entity (section cards)'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# -----------------------------------------------------------------------
# Person
#   CARD_OLN_NJ   (DQN in-state)    -- OLN required; NJ default
#   CARD_OLN_OOS  (DQN out-of-state) -- OLN required; State required
#   CARD_NAME     (DQ)              -- Last + First + DOB required; rest optional
# -----------------------------------------------------------------------
$perLayout = MakeSplitLayouts @(
    @{
        id    = 'CARD_OLN_NJ'
        title = 'IN-STATE OLN QUERY (DQN)  |  Required: OLN'
        rowDefs = @(
            @{ id = 'ROW_ON1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_NJ_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_ON1' }
                @{ id = 'RegistrationState_OLN_NJ_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_ON1' }
            )}
        )
    }
    @{
        id    = 'CARD_OLN_OOS'
        title = 'OUT-OF-STATE OLN QUERY (DQN)  |  Required: OLN + State'
        rowDefs = @(
            @{ id = 'ROW_OO1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_OOS_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_OO1' }
                @{ id = 'RegistrationState_OLN_OOS_Input'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_OO1' }
            )}
        )
    }
    @{
        id    = 'CARD_NAME'
        title = 'NAME / DOB QUERY (DQ)  |  Required: Last + First + DOB  |  Optional: MI, Suffix, Sex, State'
        rowDefs = @(
            @{ id = 'ROW_N1'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '' 'ROW_N1' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '' 'ROW_N1' }
            )}
            @{ id = 'ROW_N2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'M.I. (opt)'    '' 'ROW_N2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix (opt)'  '' 'ROW_N2' }
                @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'    'ROW_N2' }
                @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex (opt)' @{ attributeTypeId = 'SEX' } 'ROW_N2' }
            )}
            @{ id = 'ROW_N3'; cols = @('6'); fields = @(
                @{ id = 'RegistrationState_Name_Input'; node = Sel 'RegistrationState' 'State (opt)' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_N3' }
            )}
        )
    }
)

$personForm = [PSCustomObject]@{
    description  = 'Input query layout for person entity (section cards)'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# -----------------------------------------------------------------------
# Firearm  (single combination QG)
#   CARD_GUN -- SerialNumber required; Make and Caliber optional
# -----------------------------------------------------------------------
$faLayout = MakeSplitLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'GUN QUERY (QG)  |  Required: Serial Number  |  Optional: Make, Caliber'
        rowDefs = @(
            @{ id = 'ROW_G1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'SerialNumber' 'Serial Number' '11' 'ROW_G1' }
                @{ id = 'GunMake_Input';      node = Inp 'GunMake'      'Make (opt)'    '23' 'ROW_G1' }
            )}
            @{ id = 'ROW_G2'; cols = @('6'); fields = @(
                @{ id = 'GunCaliber_Input'; node = Inp 'GunCaliber' 'Caliber (opt)' '4' 'ROW_G2' }
            )}
        )
    }
)

$firearmsForm = [PSCustomObject]@{
    description  = 'Input query layout for firearm entity (section cards)'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# -----------------------------------------------------------------------
# Article  (single combination QA)
#   CARD_ART -- SerialNumber AND ArticleTypeCode both required
# -----------------------------------------------------------------------
$artLayout = MakeSplitLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE QUERY (QA)  |  Required: Serial Number + Article Type'
        rowDefs = @(
            @{ id = 'ROW_A1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input';    node = Inp 'SerialNumber'    'Serial Number'  '20' 'ROW_A1' }
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_A1' }
            )}
        )
    }
)

$articleForm = [PSCustomObject]@{
    description  = 'Input query layout for article entity (section cards)'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# -----------------------------------------------------------------------
# Boat
#   CARD_REG_NJ   (BQ in-state)    -- RegistrationNumber required; NJ default
#   CARD_REG_OOS  (BQ out-of-state) -- RegistrationNumber required; State required
#   CARD_HULL     (BQN)            -- HullIdNumber required; State optional
# -----------------------------------------------------------------------
$boaLayout = MakeSplitLayouts @(
    @{
        id    = 'CARD_REG_NJ'
        title = 'IN-STATE REGISTRATION QUERY (BQ)  |  Required: Reg Number'
        rowDefs = @(
            @{ id = 'ROW_RN1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationNumber_NJ_Input';     node = Inp 'RegistrationNumber' 'Reg Number' '8' 'ROW_RN1' }
                @{ id = 'RegistrationState_Reg_NJ_Input';  node = Sel 'RegistrationState'  'State' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_RN1' }
            )}
        )
    }
    @{
        id    = 'CARD_REG_OOS'
        title = 'OUT-OF-STATE REGISTRATION QUERY (BQ)  |  Required: Reg Number + State'
        rowDefs = @(
            @{ id = 'ROW_RO1'; cols = @('6','6'); fields = @(
                @{ id = 'RegistrationNumber_OOS_Input';    node = Inp 'RegistrationNumber' 'Reg Number' '8' 'ROW_RO1' }
                @{ id = 'RegistrationState_Reg_OOS_Input'; node = Sel 'RegistrationState'  'State' @{ attributeTypeId = 'STATE' } 'ROW_RO1' }
            )}
        )
    }
    @{
        id    = 'CARD_HULL'
        title = 'HULL ID QUERY (BQN)  |  Required: Hull ID Number  |  Optional: State'
        rowDefs = @(
            @{ id = 'ROW_H1'; cols = @('6','6'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';       node = Inp 'BoatHullIdNumber'  'Hull ID Number' '20' 'ROW_H1' }
                @{ id = 'RegistrationState_Hull_Input'; node = Sel 'RegistrationState' 'State (opt)' @{ attributeTypeId = 'STATE'; initialValue = 'NJ' } 'ROW_H1' }
            )}
        )
    }
)

$boatForm = [PSCustomObject]@{
    description  = 'Input query layout for boat entity (section cards)'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations -- section card layout (one card per query path with labeled headers)'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Person','Vehicle','Firearm','Article','Boat')
        CAD_DISPATCH    = @('Vehicle','Person','Firearm','Article','Boat')
        FIRST_RESPONDER = @('Vehicle','Person','Firearm','Article','Boat')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (unchanged from HIDLE)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($njBundle, $entitiesBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100
$json | Set-Content $OUT -Encoding UTF8

Write-Host "Built NJ_NJCJIS_sections.json"
Write-Host "  -> $OUT"

# =====================================================================
# UPDATE STATUS.TXT AND BUILD_NOTES.TXT
# =====================================================================
$STATUS_FILE = "$DIR\NJ_NJCJIS_STATUS.txt"
$NOTES_FILE  = "$DIR\NJ_NJCJIS_BUILD_NOTES.txt"

# Append build log entry to STATUS.txt
$statusEntry = @"

  sections  $DATE  build_nj_njcjis_sections.ps1
    Output : $OUT
"@
Add-Content $STATUS_FILE $statusEntry -Encoding UTF8

# Append version stub to BUILD_NOTES.txt (fill in CHANGED/REASON manually)
$notesEntry = @"

sections  $DATE  [describe change here]
  CHANGED
    -
  REASON
    -
"@
Add-Content $NOTES_FILE $notesEntry -Encoding UTF8

Write-Host ""
Write-Host "STATUS.txt   -- build log entry appended"
Write-Host "BUILD_NOTES.txt -- version stub appended (fill in CHANGED/REASON)"
Write-Host ""
Write-Host "Section cards per entity:"
Write-Host "  Vehicle  -> CARD_PLATE_NJ  (RQ in-state)       Plate Number req, State=NJ"
Write-Host "           -> CARD_PLATE_OOS (RQ out-of-state)   Plate Number + State req"
Write-Host "           -> CARD_VIN       (RQN)               VIN req"
Write-Host "  Person   -> CARD_OLN_NJ   (DQN in-state)      OLN req, State=NJ"
Write-Host "           -> CARD_OLN_OOS  (DQN out-of-state)  OLN + State req"
Write-Host "           -> CARD_NAME     (DQ)                Last+First+DOB req"
Write-Host "  Firearm  -> CARD_GUN      (QG)                Serial Number req"
Write-Host "  Article  -> CARD_ART      (QA)                Serial Number + Article Type req"
Write-Host "  Boat     -> CARD_REG_NJ   (BQ in-state)       Reg Number req, State=NJ"
Write-Host "           -> CARD_REG_OOS  (BQ out-of-state)   Reg Number + State req"
Write-Host "           -> CARD_HULL     (BQN)               Hull ID req"
