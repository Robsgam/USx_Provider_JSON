# build_fl_fcic.ps1
# Builds FL_FCIC_BASE.json from FL_FCIC.xml (field authority) + HIDLE.json (template).
# Run: powershell.exe -ExecutionPolicy Bypass -File build_fl_fcic.ps1

param([string]$Version = "1.4")

$DATE    = (Get-Date -Format 'yyyy-MM-dd')
$DIR     = "C:\Users\Gordon Hallof\FL_FCIC"
$ARCHIVE = "$DIR\archive"
$OUT     = "$DIR\FL_FCIC_BASE.json"
$VEROUT  = "$ARCHIVE\FL_FCIC_BASE_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $ARCHIVE | Out-Null

$hidle = Get-Content "$DIR\HIDLE.json" -Raw | ConvertFrom-Json

# =====================================================================
# HELPERS
# =====================================================================
function N($type, $display, $props, $isCanvas, $hidden, $nodes, $parent) {
    # Use List<string> so ConvertTo-Json always emits a proper JSON array,
    # even for single-element or empty arrays.
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
    # ROOT node has no parent property (matches CA_ESUN / HIDLE reference format)
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

function BuildLayout($rowDefs, $rootCardRowIds) {
    $l = [ordered]@{}
    $l['ROOT']      = N 'Root'  'Root' @{} $false $false @('FORM_ROOT') ''
    $l['FORM_ROOT'] = N 'Form'  'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page'  'Page' @{ title = 'Page 1' } $true $false @('ROOT_CARD') 'FORM_ROOT'
    $l['ROOT_CARD'] = N 'Card'  'Card' @{} $true $false ([array]$rootCardRowIds) 'ROOT_PAGE'
    foreach ($rDef in $rowDefs) {
        $childIds = @($rDef.fields | ForEach-Object { $_.id })
        $l[$rDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rDef.cols } $true $false $childIds 'ROOT_CARD'
        foreach ($f in $rDef.fields) {
            $l[$f.id] = $f.node
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

function MakeLayouts($rowDefs, $rootCardRowIds) {
    $def = BuildLayout $rowDefs $rootCardRowIds
    $cad = AddCadNodes $def
    $fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    return [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
}

# =====================================================================
# BUNDLE 1: FL_FCIC PROVIDER
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');        targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');    targetField = 'Mnemonic' }
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
    description                = 'Authentication configuration for FL FCIC'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'FL_FCIC'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'FL_FCIC'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HI_HCJDC_Results, name/provider changed
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'FL_FCIC_Results'
$results.description = 'Results mapping for FL FCIC'
$results.provider    = 'FL_FCIC'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'FL_FCIC_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'FL_FCIC'
}

# 1d. GunQuery (QG)
# FL XML fields: GunMake(23), GunSerialNumber(11), NCICNumber(10), ProcessControlNumber(10)
#                ImageIndicator, RelatedHitSearchIndicator, Requestor
# NO GunCaliber in FL spec.
# Combinations: QG+SerialNumber, QG+NCICNumber, QG+ProcessControl -- all QG, each needs own mapping

# 1d-i. QG+SerialNumber
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunMake';         size = 23; sourceField = @('GunMake');       targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber'; size = 11; sourceField = @('SerialNumber');   targetField = 'GunSerialNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SerialNumber'); any = @('GunMake') }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (serial number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Firearm'
}

# 1d-ii. QG+NCICNumber
$gunNCICQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'GunMake';    size = 23; sourceField = @('GunMake');    targetField = 'GunMake' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('GunMake') }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (NCIC number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_GunNCICQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Firearm'
}

# 1d-iii. QG+ProcessControlNumber
$gunPCNQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ProcessControlNumber'; size = 10; sourceField = @('ProcessControlNumber'); targetField = 'ProcessControlNumber' }
        [PSCustomObject]@{ name = 'GunMake';              size = 23; sourceField = @('GunMake');              targetField = 'GunMake' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ProcessControlNumber'); any = @('GunMake') }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (process control number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_GunProcessControlQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Firearm'
}

# 1e. VehicleRegistrationQuery -- split into one mapping per keyReference
# Platform requires unique keyReference within each QUERYINPUTDATAMAPPING.
# FL XML uses FRQ, QV, and RQ keys. FRQ is FL-only; QV=NCIC stolen vehicle; RQ=Nlets out-of-state.
# Each mapping may contain multiple DIFFERENT keyReferences; same key twice in one mapping = error.
# Split strategy: Plate mapping (FRQ+QV+RQ), VIN mapping (FRQ+QV+RQ), Decal mapping (FRQ only),
#                 TitleLien mapping (FRQ only) -- 4 total vehicle mappings.

# 1e-i. Plate: FRQ+Plate (FL), QV+Plate (NCIC stolen), RQ+Plate (Nlets out-of-state)
$vehQueryPlate = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber';   size = 10; sourceField = @('LicensePlateNumber');   targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode'; size = 2;  sourceField = @('LicensePlateTypeCode'); targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';     size = 4;  sourceField = @('LicensePlateYear');     targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';      size = 24; sourceField = @('VehicleMakeCode');      targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';          size = 4;  sourceField = @('VehicleYear');          targetField = 'VehicleYear' }
        [PSCustomObject]@{ name = 'State';                size = 2;  sourceField = @('RegistrationState');    targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('LicensePlateTypeCode','LicensePlateYear') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'FRQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # QV = NCIC Stolen Vehicle Query (plate)
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'QV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # RQ = Nlets Vehicle Registration Query (out-of-state plate -- requires State, PlateType, PlateYear)
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (plate: FRQ/QV/RQ) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'DMV'
    targetEntity    = 'Vehicle'
}

# 1e-ii. VIN: FRQ+VIN (FL), QV+VIN (NCIC stolen), RQ+VIN (Nlets out-of-state)
$vehQueryVIN = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 24; sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('VehicleYear');                 targetField = 'VehicleYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('RegistrationState');           targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @() }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'FRQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # QV = NCIC Stolen Vehicle Query (VIN)
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber'); any = @('VehicleMakeCode') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'QV'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # RQ = Nlets Vehicle Registration Query (out-of-state VIN -- requires State)
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('VehicleMakeCode','VehicleYear') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (VIN: FRQ/QV/RQ) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_VehicleVINQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'DMV'
    targetEntity    = 'Vehicle'
}

# 1e-iii. FRQ+Decal: DecalNumber+LicensePlateYear both req (FL-specific DMVR decal lookup)
$vehQueryDecal = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DecalNumber';      size = 10; sourceField = @('DecalNumber');      targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'LicensePlateYear'; size = 4;  sourceField = @('LicensePlateYear'); targetField = 'LicensePlateYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('DecalNumber','LicensePlateYear'); any = @() }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FRQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (decal) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_VehicleDecalQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'DMV'
    targetEntity    = 'Vehicle'
}

# 1f. DriverLicenseQuery
# FL XML combinations: FDQ+Name, FDQ+OLN, QW+Name, QW+OLN, DQ+Name, DQ+OLN
# FDQ = FL DHSMV; QW = NCIC Wanted Person / FCIC; DQ = Nlets out-of-state DL query
# Constraint: unique keyReference per mapping.
# Split: OLN mapping (FDQ+OLN, DQ+OLN, QW+OLN -- 3 different keys)
#        Name mapping (FDQ+Name, QW+Name, DQ+Name -- 3 different keys)

# 1f-i. OLN mapping: FDQ+OLN (DHSMV), DQ+OLN (Nlets+State), QW+OLN (NCIC+Name+OLN)
$dlQueryOLN = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(' ',' ',' ') }
            size        = 80
            sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix')
            targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State' }
        [PSCustomObject]@{ name = 'Image';            sourceField = @('ImageIndicator');    targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            # FDQ+OLN: DHSMV by OLN; no State required
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'FDQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # DQ+OLN: Nlets out-of-state DL query by OLN; State required
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # QW+OLN: NCIC Wanted Person cross-check; requires both Name and OLN
            requirements          = [PSCustomObject]@{ set = @('NameLast','NameFirst','OperatorLicenseNumber'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'QW'
            state                 = 'In/Out'
        }
    )
    description        = 'Mapping for DriverLicenseQuery (OLN: FDQ/DQ/QW) in FL FCIC'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'FL_FCIC_DriverLicenseOLN'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = [string[]]@('DriverHistoryQuery')
    provider           = 'FL_FCIC'
    providerType       = 'Commsys'
    query              = 'DriverLicenseQuery'
    queryLabel         = 'Driver License'
    targetEntity       = 'Person'
}

# 1f-ii. Name mapping: FDQ+Name (DHSMV), QW+Name (FCIC/Nlets), DQ+Name (Nlets+State)
$dlQueryName = [PSCustomObject]@{
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
            size        = 80
            sourceField = @('NameFirst','NameLast','NameMiddle','NameSuffix')
            targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode'; size = 1;  sourceField = @('SexCode');         targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';   size = 2;  sourceField = @('RegistrationState'); targetField = 'State' }
        [PSCustomObject]@{ name = 'Image';               sourceField = @('ImageIndicator');   targetField = 'ImageIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            # FDQ+Name: DHSMV by name; BirthDate+Name+SexCode req
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'FDQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # QW+Name: FCIC/Nlets by name; BirthDate+Name req; OLN opt
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst'); any = @('OperatorLicenseNumber') }
            primaryFieldReference = 'Name'
            keyReference          = 'QW'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # DQ+Name: Nlets out-of-state DL by name; BirthDate+Name+SexCode+State all req
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode','RegistrationState'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description        = 'Mapping for DriverLicenseQuery (Name: FDQ/QW/DQ) in FL FCIC'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'FL_FCIC_DriverLicenseQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = [string[]]@('DriverHistoryQuery')
    provider           = 'FL_FCIC'
    providerType       = 'Commsys'
    query              = 'DriverLicenseQuery'
    queryLabel         = 'Driver License'
    targetEntity       = 'Person'
}

# 1g. DriverHistoryQuery (KQ) -- FL-specific, no NJ equivalent
# Both combinations use KQ -- split into one mapping per primary key.

# 1g-i. KQ+Name: BirthDate+Name+SexCode+State all req; Attention+PurposeCode opt
$dhQueryName = [PSCustomObject]@{
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
        [PSCustomObject]@{ name = 'SexCode';     size = 1;  sourceField = @('SexCode');           targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';        size = 2;  sourceField = @('RegistrationState'); targetField = 'State' }
        [PSCustomObject]@{ name = 'Attention';    size = 30; sourceField = @('Attention');         targetField = 'Attention' }
        [PSCustomObject]@{ name = 'PurposeCode';  size = 1;  sourceField = @('PurposeCode');       targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'Requestor';    size = 30; sourceField = @('Attention');         targetField = 'Requestor' }
    )
    combinations = @(
        [PSCustomObject]@{
            # KQ fires only when ALL set fields populated -- PurposeCode+Attention in set
            # so the combination indicator lights only when both fields are provided
            requirements          = [PSCustomObject]@{ set = @('BirthDate','NameLast','NameFirst','SexCode','RegistrationState','PurposeCode','Attention'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
    )
    description        = 'Mapping for DriverHistoryQuery (Name) in FL FCIC'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'FL_FCIC_DriverHistoryQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $false
    queriesToDeselect  = [string[]]@('DriverLicenseQuery')
    provider           = 'FL_FCIC'
    providerType       = 'Commsys'
    query              = 'DriverHistoryQuery'
    queryLabel         = 'Driver History'
    targetEntity       = 'Person'
}

# 1g-ii. KQ+OLN: OperatorLicenseNumber+State+PurposeCode+Attention all required
$dhQueryOLN = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationState');     targetField = 'State' }
        [PSCustomObject]@{ name = 'Attention';             size = 30; sourceField = @('Attention');             targetField = 'Attention' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('PurposeCode');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'Requestor';             size = 30; sourceField = @('Attention');             targetField = 'Requestor' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationState','PurposeCode','Attention'); any = @() }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
    )
    description        = 'Mapping for DriverHistoryQuery (OLN) in FL FCIC'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'FL_FCIC_DriverHistoryOLN'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $false
    queriesToDeselect  = [string[]]@('DriverLicenseQuery')
    provider           = 'FL_FCIC'
    providerType       = 'Commsys'
    query              = 'DriverHistoryQuery'
    queryLabel         = 'Driver History'
    targetEntity       = 'Person'
}

# 1h. BoatQuery
# FL XML combinations: FBQ+Hull, FBQ+Decal, FBQ+Reg, FBQ+TitleLien,
#                      QB+Hull, QB+CoastGuard, QB+NCICNumber, QB+ProcessControl
# FBQ = FL FCIC Boat Query; QB = NCIC Stolen Boat Query
# Split: Reg mapping (FBQ only), Hull mapping (FBQ+QB), Decal mapping (FBQ only),
#        TitleLien mapping (FBQ only), CoastGuard mapping (QB only),
#        NCICNumber mapping (QB only), ProcessControl mapping (QB only)

# 1h-i. FBQ+RegNumber: RegistrationNumber req
$boatQueryReg = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';   size = 62; sourceField = @('BoatHullIdNumber');  targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'State';              size = 2;  sourceField = @('RegistrationState'); targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('RegistrationNumber'); any = @('BoatHullIdNumber','RegistrationState') }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'FBQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (registration: FBQ) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'FCIC'
    targetEntity    = 'Boat'
}

# 1h-ii. FBQ+HullId and QB+HullId: two different keys in one mapping (maxLength=62 per FL XML)
$boatQueryHull = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';  size = 62; sourceField = @('BoatHullIdNumber');  targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'State';              size = 2;  sourceField = @('RegistrationState'); targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            # FBQ+Hull: FL FCIC Boat by Hull ID
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationNumber','RegistrationState') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'FBQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # QB+Hull: NCIC Stolen Boat by Hull ID
            requirements          = [PSCustomObject]@{ set = @('BoatHullIdNumber'); any = @('RegistrationNumber') }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (hull ID: FBQ/QB) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatHullQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'FCIC'
    targetEntity    = 'Boat'
}

# 1h-iii. FBQ+Decal: DecalNumber req (FL boat decal lookup)
$boatQueryDecal = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DecalNumber';      size = 20; sourceField = @('DecalNumber');      targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'BoatHullIdNumber'; size = 62; sourceField = @('BoatHullIdNumber');  targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber'; size = 8; sourceField = @('RegistrationNumber'); targetField = 'RegistrationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('DecalNumber'); any = @('BoatHullIdNumber','RegistrationNumber') }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FBQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (decal: FBQ) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatDecalQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'FCIC'
    targetEntity    = 'Boat'
}

# 1h-iv. FBQ+TitleLien: TitleLienInformation req (FL title lien lookup)
$boatQueryTitleLien = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'TitleLienInformation'; size = 10; sourceField = @('TitleLienInformation'); targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';     size = 62; sourceField = @('BoatHullIdNumber');      targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';   size = 8;  sourceField = @('RegistrationNumber');    targetField = 'RegistrationNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('TitleLienInformation'); any = @('BoatHullIdNumber','RegistrationNumber') }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FBQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (title lien: FBQ) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatTitleLienQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'FCIC'
    targetEntity    = 'Boat'
}

# 1h-v. QB+CoastGuard: CoastGuardDocumentNumber req (NCIC stolen boat by USCG doc number)
$boatQueryCoastGuard = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'CoastGuardDocumentNumber'; size = 8; sourceField = @('CoastGuardDocumentNumber'); targetField = 'CoastGuardDocumentNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('CoastGuardDocumentNumber'); any = @() }
            primaryFieldReference = 'CoastGuardDocumentNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (Coast Guard doc: QB) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatCoastGuardQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Boat'
}

# 1h-vi. QB+NCICNumber: NCICNumber req (NCIC stolen boat by NCIC record number)
$boatQueryNCIC = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @() }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (NCIC number: QB) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatNCICQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Boat'
}

# 1h-vii. QB+ProcessControl: ProcessControlNumber req (FCIC process control number)
$boatQueryPCN = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ProcessControlNumber'; size = 10; sourceField = @('ProcessControlNumber'); targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ProcessControlNumber'); any = @() }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (process control: QB) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_BoatProcessControlQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Boat'
}

# 1i. ArticleSingleQuery (QA)
# FL XML fields: ArticleSerialNumber(20), ArticleTypeCode(7), NCICNumber(10),
#                OwnerAppliedNumber(20), ProcessControlNumber(10),
#                ImageIndicator, RelatedHitSearchIndicator, Requestor
# Combinations: QA+SerialNumber, QA+OwnerAppliedNumber, QA+NCICNumber, QA+ProcessControl
# All QA -- each needs its own mapping (duplicate key constraint)

# 1i-i. QA+SerialNumber (serial + type both required)
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
    description     = 'Mapping for ArticleSingleQuery (serial number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Article'
}

# 1i-ii. QA+OwnerAppliedNumber (owner-applied number + type both required)
$artOwnerQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'OwnerAppliedNumber'; size = 20; sourceField = @('OwnerAppliedNumber'); targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';    size = 7;  sourceField = @('ArticleTypeCode');    targetField = 'ArticleTypeCode' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OwnerAppliedNumber','ArticleTypeCode'); any = @() }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (owner-applied number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_ArticleOwnerQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Article'
}

# 1i-iii. QA+NCICNumber
$artNCICQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'NCICNumber'; size = 10; sourceField = @('NCICNumber'); targetField = 'NCICNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @() }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (NCIC number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_ArticleNCICQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Article'
}

# 1i-iv. QA+ProcessControlNumber
$artPCNQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ProcessControlNumber'; size = 10; sourceField = @('ProcessControlNumber'); targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ProcessControlNumber'); any = @() }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (process control number) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_ArticleProcessControlQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'NCIC'
    targetEntity    = 'Article'
}

# 1e-iv. FRQ+TitleLien: TitleLienInformation req (FL title lien vehicle lookup)
$vehQueryTitleLien = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'TitleLienInformation'; size = 8; sourceField = @('TitleLienInformation'); targetField = 'TitleLienInformation' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('TitleLienInformation'); any = @() }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FRQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (title lien: FRQ) in FL FCIC'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'FL_FCIC_VehicleTitleLienQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'FL_FCIC'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'DMV'
    targetEntity    = 'Vehicle'
}

$fcicBundle = [PSCustomObject]@{
    configurations = @(
        $auth, $results, $qmf,
        $gunQuery, $gunNCICQuery, $gunPCNQuery,
        $vehQueryPlate, $vehQueryVIN, $vehQueryDecal, $vehQueryTitleLien,
        $dlQueryOLN, $dlQueryName,
        $dhQueryName, $dhQueryOLN,
        $boatQueryReg, $boatQueryHull, $boatQueryDecal, $boatQueryTitleLien,
        $boatQueryCoastGuard, $boatQueryNCIC, $boatQueryPCN,
        $artQuery, $artOwnerQuery, $artNCICQuery, $artPCNQuery
    )
    description    = "Provider configuration for FL_FCIC v${Version}"
    name           = 'FL_FCIC'
    type           = 'BUNDLE'
    provider       = 'FL_FCIC'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# =====================================================================

# Vehicle: Plate+PlateType / PlateYear+Decal / VIN / Make+Year / State+TitleLien
# ROW_5 RegistrationState added for RQ (Nlets out-of-state) and QV (NCIC stolen vehicle) queries.
# TitleLienInformation added for FRQ+TitleLien query.
$vehLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber'  'Plate Number' '10' 'ROW_1' }
        @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'LicensePlateYear_Input'; node = Inp 'LicensePlateYear' 'Plate Year'    '4'  'ROW_2' }
        @{ id = 'DecalNumber_Input';      node = Inp 'DecalNumber'      'Decal Number'  '10' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('12'); fields = @(
        @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_3' }
    )}
    @{ id = 'ROW_4'; cols = @('6','6'); fields = @(
        @{ id = 'VehicleMakeCode_Input'; node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_4' }
        @{ id = 'VehicleYear_Input';     node = Inp 'VehicleYear' 'Vehicle Year' '4' 'ROW_4' @{ initialValue = '2026' } }
    )}
    @{ id = 'ROW_5'; cols = @('6','6'); fields = @(
        @{ id = 'RegistrationState_Input';   node = Sel 'RegistrationState' 'State (for out-of-state)' @{ attributeTypeId = 'STATE' } 'ROW_5' }
        @{ id = 'TitleLienInformation_Input'; node = Inp 'TitleLienInformation' 'Title Lien Info' '8' 'ROW_5' }
    )}
) @('ROW_1','ROW_2','ROW_3','ROW_4','ROW_5')

$vehicleForm = [PSCustomObject]@{
    description  = 'Input query layout for vehicle entity'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person: OLN+LicenseState / First+Last / Middle+Suffix+DOB+Sex / PurposeCode+Attention
# LicenseState required for KQ (DriverHistoryQuery) and DQ (Nlets out-of-state DL)
# ROW_4: PurposeCode+Attention -- required by DriverHistoryQuery (KQ) per FL FCIC spec
$perLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_1' }
        @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'License State' @{ attributeTypeId = 'STATE'; initialValue = 'FL' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '' 'ROW_2' }
        @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('3','3','3','3'); fields = @(
        @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'M.I.'         '' 'ROW_3' }
        @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix'       '' 'ROW_3' }
        @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'   'ROW_3' }
        @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX' } 'ROW_3' }
    )}
    @{ id = 'ROW_4'; cols = @('6','6'); fields = @(
        @{ id = 'PurposeCode_Input'; node = Inp 'PurposeCode' 'Purpose Code' '1'  'ROW_4' }
        @{ id = 'Attention_Input';   node = Inp 'Attention'   'Attention'    '30' 'ROW_4' }
    )}
) @('ROW_1','ROW_2','ROW_3','ROW_4')

$personForm = [PSCustomObject]@{
    description  = 'Input query layout for person entity'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm: SerialNumber+Make / NCICNumber+ProcessControlNumber
# FL note: FL GunQuery XML has no GunCaliber field -- Caliber row omitted
# ROW_2 added for NCICNumber (QG+NCIC) and ProcessControlNumber (QG+PCN)
$faLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'SerialNumber_Input'; node = Inp 'SerialNumber' 'Serial Number' '11' 'ROW_1' }
        @{ id = 'GunMake_Input';      node = Inp 'GunMake'      'Make'          '23' 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('6','6'); fields = @(
        @{ id = 'NCICNumber_Input';           node = Inp 'NCICNumber'           'NCIC Number'    '10' 'ROW_2' }
        @{ id = 'ProcessControlNumber_Input'; node = Inp 'ProcessControlNumber' 'Process Control #' '10' 'ROW_2' }
    )}
) @('ROW_1','ROW_2')

$firearmsForm = [PSCustomObject]@{
    description  = 'Input query layout for firearm entity'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article: SerialNumber+ArticleType / OwnerAppliedNumber / NCICNumber+ProcessControlNumber
# ROW_2: OwnerAppliedNumber (QA+Owner requires ArticleTypeCode + OwnerAppliedNumber)
# ROW_3: NCICNumber (QA+NCIC) and ProcessControlNumber (QA+PCN)
$artLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'SerialNumber_Input';    node = Inp 'SerialNumber'    'Serial Number' '20' 'ROW_1' }
        @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('12'); fields = @(
        @{ id = 'OwnerAppliedNumber_Input'; node = Inp 'OwnerAppliedNumber' 'Owner Applied Number' '20' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('6','6'); fields = @(
        @{ id = 'NCICNumber_Input';           node = Inp 'NCICNumber'           'NCIC Number'       '10' 'ROW_3' }
        @{ id = 'ProcessControlNumber_Input'; node = Inp 'ProcessControlNumber' 'Process Control #' '10' 'ROW_3' }
    )}
) @('ROW_1','ROW_2','ROW_3')

$articleForm = [PSCustomObject]@{
    description  = 'Input query layout for article entity'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat: RegNumber+State / HullId / CoastGuardDocNum+NCICNumber / TitleLien+Decal / ProcessControl
# ROW_1-2: FL FCIC FBQ primary fields; ROW_3-5: NCIC QB fields + additional FBQ fields
$boaLayout = MakeLayouts @(
    @{ id = 'ROW_1'; cols = @('6','6'); fields = @(
        @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8'  'ROW_1' }
        @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState'  'State'               @{ attributeTypeId = 'STATE'; initialValue = 'FL' } 'ROW_1' }
    )}
    @{ id = 'ROW_2'; cols = @('12'); fields = @(
        @{ id = 'BoatHullIdNumber_Input'; node = Inp 'BoatHullIdNumber' 'Hull ID Number' '62' 'ROW_2' }
    )}
    @{ id = 'ROW_3'; cols = @('6','6'); fields = @(
        @{ id = 'CoastGuardDocumentNumber_Input'; node = Inp 'CoastGuardDocumentNumber' 'Coast Guard Doc #' '8'  'ROW_3' }
        @{ id = 'NCICNumber_Input';               node = Inp 'NCICNumber'               'NCIC Number'       '10' 'ROW_3' }
    )}
    @{ id = 'ROW_4'; cols = @('6','6'); fields = @(
        @{ id = 'TitleLienInformation_Input'; node = Inp 'TitleLienInformation' 'Title Lien Info' '10' 'ROW_4' }
        @{ id = 'DecalNumber_Input';          node = Inp 'DecalNumber'          'Decal Number'    '20' 'ROW_4' }
    )}
    @{ id = 'ROW_5'; cols = @('12'); fields = @(
        @{ id = 'ProcessControlNumber_Input'; node = Inp 'ProcessControlNumber' 'Process Control Number' '10' 'ROW_5' }
    )}
) @('ROW_1','ROW_2','ROW_3','ROW_4','ROW_5')

$boatForm = [PSCustomObject]@{
    description  = 'Input query layout for boat entity'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)
    description    = 'Entity form configurations (shared across providers)'
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
# BUNDLE 3: RMS (extracted unchanged from HIDLE)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($fcicBundle, $entitiesBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100
$json | Set-Content $OUT    -Encoding UTF8
$json | Set-Content $VEROUT -Encoding UTF8

Write-Host "Built FL_FCIC_BASE.json v${Version}"
Write-Host "  -> $OUT"
Write-Host "  -> $VEROUT"
