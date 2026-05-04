# build_nj_display_test.ps1
# Tests whether InpH 'RegistrationState' initialValue='NJ' (plain text, no
# attributeTypeId) is sufficient for RMS to trigger plate AND VIN searches
# without a fatal error.
#
# If PASS on both: drop the dual-field approach, simplify NJ forms back to
# a single hidden InpH -- display shows 'NJ' instead of internal attribute ID.
#
# If VIN fatals: InpH approach does not work for VIN; keep dual-field (v3.13).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_display_test.ps1

$DIR = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$OUT = "$DIR\archive\NJ_NJCJIS_nj_display_test.json"

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

function BuildLayout($cardDefs) {
    $l = [ordered]@{}
    $cardIds = @($cardDefs | ForEach-Object { $_.id })
    $l['ROOT']      = N 'Root' 'Root' @{} $false $false @('FORM_ROOT') ''
    $l['FORM_ROOT'] = N 'Form' 'Form' @{ hidePageItems = $true; layout = 'page' } $true $false @('ROOT_PAGE') 'ROOT'
    $l['ROOT_PAGE'] = N 'Page' 'Page' @{ title = 'Page 1' } $true $false $cardIds 'FORM_ROOT'
    foreach ($cardDef in $cardDefs) {
        $rowIds = @($cardDef.rows | ForEach-Object { $_.id })
        $l[$cardDef.id] = N 'Card' 'Card' @{ title = $cardDef.title } $true $false $rowIds 'ROOT_PAGE'
        foreach ($rowDef in $cardDef.rows) {
            $fieldIds = @($rowDef.fields | ForEach-Object { $_.id })
            $l[$rowDef.id] = N 'Row' 'Row' @{ templateColumns = [array]$rowDef.cols } $true $false $fieldIds $cardDef.id
            foreach ($f in $rowDef.fields) { $l[$f.id] = $f.node }
        }
    }
    [PSCustomObject]$l
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

function MakeLayout($cardDefs) {
    $def = BuildLayout $cardDefs
    $cad = AddCadNodes $def
    $fr  = $cad | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    [PSCustomObject]@{ default = $def; CAD_DISPATCH = $cad; FIRST_RESPONDER = $fr }
}

# =====================================================================
# SHARED CONFIGS
# =====================================================================
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');      targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic'); targetField = 'Mnemonic' }
        [PSCustomObject]@{
            name        = 'UserName'
            rule        = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }
            sourceField = @('dexStateUserId')
            targetField = 'UserName'
        }
    )
    combinations = @(
        [PSCustomObject]@{ requirements = [PSCustomObject]@{ set = @('ORI','Mnemonic'); any = @('dexStateUserId') } }
    )
    description                = 'Auth for NJ NJCJIS display test'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'NJ_NJCJIS'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'NJ_NJCJIS'
    providerType               = 'Commsys'
    signInRequired             = $false
}

$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results   = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'NJ_NJCJIS_Results'
$results.description = 'Results mapping for NJ NJCJIS'
$results.provider    = 'NJ_NJCJIS'

$qmf = [PSCustomObject]@{
    description          = 'Query format for NJ NJCJIS display test'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'NJ_NJCJIS_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'NJ_NJCJIS'
}

# =====================================================================
# QUERYINPUTDATAMAPPING
# Single hidden InpH 'RegistrationState' initialValue='NJ'.
# No attributeTypeId. Testing whether RMS recognises fieldId alone.
# =====================================================================
$vehicleQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumberIn';        size = 10; sourceField = @('LicensePlateNumberIn');        targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';              size = 1;  sourceField = @('ImageIndicator');              targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('RegistrationState');           targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumberIn','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'LicensePlateNumberIn'
            keyReference          = 'RQ_NJ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('ImageIndicator') }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQN_NJ'
            state                 = 'In/Out'
        }
    )
    description     = 'NJ display test -- InpH RegistrationState, no attributeTypeId'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'NJ_NJCJIS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'NJ_NJCJIS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# FORM -- Vehicle NJ
# Single hidden InpH 'RegistrationState' initialValue='NJ'.
# No SelH, no dual-field. If this works, v3.13 dual-field can be removed.
# =====================================================================
$vehNjLayout = MakeLayout @(
    @{
        id    = 'CARD_VEH_NJ'
        title = 'Vehicle Query - NJ (InpH state, no attrTypeId)'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('10','2'); fields = @(
                @{ id = 'LicensePlateNumberIn_Input'; node = Inp 'LicensePlateNumberIn' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'ImageIndicator_Input';       node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('12'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_STATE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'RegistrationState_Input'; node = InpH 'RegistrationState' 'State' @{ initialValue = 'NJ' } 'ROW_VEH_STATE' }
            )}
        )
    }
)
$vehNjForm = [PSCustomObject]@{
    description  = 'NJ display test -- single InpH state field, no attributeTypeId'
    label        = 'Vehicle - NJ'
    layout       = $vehNjLayout
    name         = 'ENTITY_Vehicle_NJ'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# =====================================================================
# BUNDLES
# =====================================================================
$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehicleQuery)
    description    = 'NJ NJCJIS provider bundle (NJ display test)'
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($vehNjForm)
    description    = 'NJ display test -- single Vehicle NJ tab'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    provider       = 'MARK43'
    order          = [PSCustomObject]@{
        default         = @('Vehicle')
        CAD_DISPATCH    = @('Vehicle')
        FIRST_RESPONDER = @('Vehicle')
    }
}

$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }

$json = [PSCustomObject]@{ bundles = @($njBundle, $entitiesBundle, $rmsBundle) }
$json | ConvertTo-Json -Depth 30 | Out-File -FilePath $OUT -Encoding UTF8

Write-Host "Built NJ_NJCJIS_nj_display_test.json"
Write-Host "  -> $OUT"

# ── Auto-commit and push to GitHub ────────────────────────────────────────
Push-Location $DIR
git add "archive\NJ_NJCJIS_nj_display_test.json"
git commit -m "Build nj_display_test"
Pop-Location
