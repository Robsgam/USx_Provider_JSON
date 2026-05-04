# build_oos_rms_test.ps1
# OOS state field test -- HI pattern vs current approach.
#
# QUESTION: does attributeTypeId=STATE without useAttributeId in the CommSys QIDM
#           send the 2-letter state code ("PA") or the numeric attribute ID to CommSys?
#           HI uses this exact pattern and is a deployed provider. If it sends "PA",
#           we can use one field for both CommSys and RMS (no dual-field needed for OOS).
#
# Tab A -- HI PATTERN (attributeTypeId=STATE, fieldId=RegistrationStateOut)
#   CommSys QIDM maps RegistrationStateOut -> State  (NO useAttributeId)
#   RMS QIDM maps    RegistrationStateOut -> vehicle.registrationStateAttrIds (useAttributeId=True)
#   PASS if: CommSys <State>PA</State>  AND  RMS registrationStateAttrIds present
#   FAIL if: CommSys <State>69509884952</State>  (attribute ID -- not usable)
#
# Tab B -- CURRENT APPROACH (codeTypeCategory=NJ_NIBRS_STATE, fieldId=RegistrationStateOOS)
#   CommSys QIDM maps RegistrationStateOOS -> State  (NO useAttributeId)
#   RMS QIDM: cannot map (code value incompatible with useAttributeId)
#   Control tab -- confirms CommSys gets "PA" from codeTypeCategory (known good)
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_oos_rms_test.ps1

$DATE = (Get-Date -Format 'yyyy-MM-dd')
$DIR  = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$OUT  = "$DIR\archive\NJ_NJCJIS_oos_rms_test.json"

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
    [PSCustomObject]@{
        default         = $def
        CAD_DISPATCH    = $cad
        FIRST_RESPONDER = $fr
    }
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
$results   = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
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

# =====================================================================
# QUERYINPUTDATAMAPPING
#
# Tab A (HI pattern): RegistrationStateOut (attributeTypeId=STATE)
#   StateOut mapped WITHOUT useAttributeId -- HI does this, test if CommSys gets "PA"
#
# Tab B (control): RegistrationStateOOS (codeTypeCategory)
#   Known good -- CommSys gets "PA" for certain
# =====================================================================
$vehicleQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber'; size = 10; sourceField = @('LicensePlateNumber'); targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';     size = 1;  sourceField = @('ImageIndicator');     targetField = 'ImageIndicator' }
        # Tab A -- HI pattern: attributeTypeId=STATE, no useAttributeId
        [PSCustomObject]@{ name = 'StateOut'; size = 2; sourceField = @('RegistrationStateOut'); targetField = 'State' }
        # Tab B -- current: codeTypeCategory, no useAttributeId
        [PSCustomObject]@{ name = 'StateOOS'; size = 2; sourceField = @('RegistrationStateOOS'); targetField = 'State' }
    )
    combinations = @(
        # Tab A
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationStateOut'); any = @('ImageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ_A'
            state                 = 'In/Out'
        }
        # Tab B
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationStateOOS'); any = @('ImageIndicator') }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ_B'
            state                 = 'In/Out'
        }
    )
    description     = 'OOS state HI-pattern test -- VehicleRegistrationQuery'
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
# TAB A -- HI PATTERN
# fieldId=RegistrationStateOut, attributeTypeId=STATE (visible dropdown)
# This is how HI ENTITY_Vehicle handles OOS state.
# Check CommSys XML: <State>PA</State> = PASS, attribute ID = FAIL
# Check RMS: registrationStateAttrIds present = PASS (RMS QIDM already has this mapping)
# =====================================================================
$tabALayout = MakeLayout @(
    @{
        id    = 'CARD_TA'
        title = 'HI Pattern -- attributeTypeId=STATE (check if CommSys gets PA)'
        rows  = @(
            @{ id = 'ROW_TA_1'; cols = @('5','5','2'); fields = @(
                @{ id = 'LicensePlateNumber_TA';   node = Inp 'LicensePlateNumber'   'Plate Number' '10' 'ROW_TA_1' }
                @{ id = 'RegistrationStateOut_TA'; node = Sel 'RegistrationStateOut' 'State' @{ attributeTypeId = 'STATE' } 'ROW_TA_1' }
                @{ id = 'ImageIndicator_TA';        node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_TA_1' }
            )}
        )
    }
)
$tabAForm = [PSCustomObject]@{
    description  = 'HI pattern -- attributeTypeId=STATE, no useAttributeId in QIDM'
    label        = 'A - HI Pattern'
    layout       = $tabALayout
    name         = 'OOS_TEST_HI_Pattern'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# =====================================================================
# TAB B -- CURRENT APPROACH (control)
# fieldId=RegistrationStateOOS, codeTypeCategory=NJ_NIBRS_STATE
# Known: CommSys gets "PA". RMS does not get state (documented limitation).
# =====================================================================
$tabBLayout = MakeLayout @(
    @{
        id    = 'CARD_TB'
        title = 'Current Approach -- codeTypeCategory (control, CommSys gets PA)'
        rows  = @(
            @{ id = 'ROW_TB_1'; cols = @('5','5','2'); fields = @(
                @{ id = 'LicensePlateNumber_TB';    node = Inp 'LicensePlateNumber'    'Plate Number' '10' 'ROW_TB_1' }
                @{ id = 'RegistrationStateOOS_TB';  node = Sel 'RegistrationStateOOS'  'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_TB_1' }
                @{ id = 'ImageIndicator_TB';         node = Sel 'ImageIndicator' 'Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NIBRS'; initialValue = 'N' } 'ROW_TB_1' }
            )}
        )
    }
)
$tabBForm = [PSCustomObject]@{
    description  = 'Control -- codeTypeCategory, CommSys gets 2-letter code (known good)'
    label        = 'B - Current'
    layout       = $tabBLayout
    name         = 'OOS_TEST_Current'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# =====================================================================
# BUNDLES + RMS (unpatched -- keep RegistrationStateOut in licensePlateOutAndState
# so we can confirm whether RMS fires with state on Tab A)
# =====================================================================
$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehicleQuery)
    description    = 'NJ NJCJIS provider bundle (OOS HI-pattern test)'
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($tabAForm, $tabBForm)
    description    = 'OOS state field HI-pattern test -- 2 tabs'
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

$json = [PSCustomObject]@{
    bundles = @($njBundle, $entitiesBundle, $rmsBundle)
}

$json | ConvertTo-Json -Depth 30 | Out-File -FilePath $OUT -Encoding UTF8
Write-Host "Built NJ_NJCJIS_oos_rms_test.json"
Write-Host "  -> $OUT"
Write-Host ""
Write-Host "TEST PROCEDURE:"
Write-Host "  Tab A (HI Pattern): Fill Plate=PAPLATE, select State=PA, submit"
Write-Host "    CommSys XML: <State>PA</State>       --> PASS (HI pattern works)"
Write-Host "    CommSys XML: <State>69509884952</State> --> FAIL (attribute ID sent)"
Write-Host "    RMS elastic: registrationStateAttrIds present --> BONUS PASS"
Write-Host ""
Write-Host "  Tab B (Control): Fill Plate=PAPLATE, select State=PA, submit"
Write-Host "    CommSys XML: <State>PA</State> --> expected (confirms control is working)"

# ── Auto-commit and push to GitHub ────────────────────────────────────────
Push-Location $DIR
git add "archive\NJ_NJCJIS_oos_rms_test.json"
git commit -m "Build oos_rms_test (HI pattern investigation)"
Pop-Location
