# build_state_test.ps1
# Focused test: 3 State field variants in QUERYINPUTFORM.
# Tab 1 -- FormSelect + attributeTypeId='STATE'       (baseline, known to send internal ID)
# Tab 2 -- FormSelect + codeTypeCategory='NJ_NIBRS_STATE' (candidate fix)
# Tab 3 -- FormInput  + maxLength=2                   (confirmed working text input)
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_state_test.ps1

$DATE = (Get-Date -Format 'yyyy-MM-dd')
$DIR  = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$OUT  = "$DIR\archive\NJ_NJCJIS_state_test.json"

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
# SHARED CONFIGS (AUTH / QMF / RESULTS)
# =====================================================================
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');       targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic');  targetField = 'Mnemonic' }
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

$hiResults   = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results     = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
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
# QUERYINPUTDATAMAPPING -- minimal VehicleRegistrationQuery
# Just Plate + State so all 3 tabs can fire RQ
# =====================================================================
$vehicleQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'LicensePlateNumber'; size = 10; sourceField = @('LicensePlateNumber'); targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'State';              size = 2;  sourceField = @('RegistrationState');  targetField = 'State' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','RegistrationState'); any = @() }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'In/Out'
        }
    )
    description  = 'State field test -- VehicleRegistrationQuery'
    name         = 'VehicleRegistrationQuery'
    provider     = 'NJ_NJCJIS'
    queryLabel   = 'Vehicle'
    type         = 'QUERYINPUTDATAMAPPING'
}

# =====================================================================
# TAB 1 -- FormSelect + attributeTypeId='STATE'
# Baseline: known to send internal option ID instead of 2-letter code
# =====================================================================
$tab1Layout = MakeLayout @(
    @{
        id    = 'CARD_T1'
        title = 'attributeTypeId (baseline)'
        rows  = @(
            @{ id = 'ROW_T1_1'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateNumber_T1'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_T1_1' }
                @{ id = 'RegistrationState_T1'; node = Sel 'RegistrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_T1_1' }
            )}
        )
    }
)
$tab1Form = [PSCustomObject]@{
    description  = 'State test -- attributeTypeId=STATE (baseline, known to send internal ID)'
    label        = 'State - Attr Type'
    layout       = $tab1Layout
    name         = 'STATE_TEST_AttrType'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# =====================================================================
# TAB 2 -- FormSelect + codeTypeCategory='NJ_NIBRS_STATE'
# Candidate fix: codeTypeCategory-based selects send code values for
# other fields (Image, PlateType). Testing if a state category exists.
# =====================================================================
$tab2Layout = MakeLayout @(
    @{
        id    = 'CARD_T2'
        title = 'codeTypeCategory (candidate)'
        rows  = @(
            @{ id = 'ROW_T2_1'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateNumber_T2'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_T2_1' }
                @{ id = 'RegistrationState_T2'; node = Sel 'RegistrationState' 'State' @{ codeTypeCategory = 'NJ_NIBRS_STATE'; codeTypeSource = 'NJ_NIBRS' } 'ROW_T2_1' }
            )}
        )
    }
)
$tab2Form = [PSCustomObject]@{
    description  = 'State test -- codeTypeCategory=NJ_NIBRS_STATE (candidate fix)'
    label        = 'State - Code Cat'
    layout       = $tab2Layout
    name         = 'STATE_TEST_CodeCat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# =====================================================================
# TAB 3 -- FormInput maxLength=2
# Confirmed working: sends plain text, operator types 2-letter code
# =====================================================================
$tab3Layout = MakeLayout @(
    @{
        id    = 'CARD_T3'
        title = 'FormInput (text -- confirmed working)'
        rows  = @(
            @{ id = 'ROW_T3_1'; cols = @('6','6'); fields = @(
                @{ id = 'LicensePlateNumber_T3'; node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_T3_1' }
                @{ id = 'RegistrationState_T3'; node = Inp 'RegistrationState' 'State' '2' 'ROW_T3_1' }
            )}
        )
    }
)
$tab3Form = [PSCustomObject]@{
    description  = 'State test -- FormInput maxLength=2 (confirmed working)'
    label        = 'State - Text Input'
    layout       = $tab3Layout
    name         = 'STATE_TEST_TextInput'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# =====================================================================
# BUNDLES + FINAL JSON
# =====================================================================
$njBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehicleQuery)
    description    = 'NJ NJCJIS provider bundle (state test)'
    name           = 'NJ_NJCJIS'
    type           = 'BUNDLE'
    provider       = 'NJ_NJCJIS'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($tab1Form, $tab2Form, $tab3Form)
    description    = 'State field dropdown test -- 3 variants'
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
Write-Host "Built NJ_NJCJIS_state_test.json"
Write-Host "  -> $OUT"
Write-Host ""
Write-Host "TABS:"
Write-Host "  Tab 1 -- State - Attr Type  : FormSelect + attributeTypeId='STATE'     (baseline)"
Write-Host "  Tab 2 -- State - Code Cat   : FormSelect + codeTypeCategory='NJ_NIBRS_STATE'  (candidate)"
Write-Host "  Tab 3 -- State - Text Input : FormInput  + maxLength=2                 (confirmed working)"
Write-Host ""
Write-Host "TEST:"
Write-Host "  Fill Plate Number + select/type State=PA on each tab and submit."
Write-Host "  Check XML request -- State should be 'PA', not an internal ID.

# ── Auto-commit and push to GitHub ────────────────────────────────────────
Push-Location $DIR
git add "archive\NJ_NJCJIS_state_test.json"
git commit -m "Build state_test"
Pop-Location"
