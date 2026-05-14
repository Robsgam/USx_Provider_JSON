# build_ca_contra_costa_mc.ps1  -- CA_CONTRA_COSTA MC (multi-card)
# MC variant: camelCase fieldIds for CAD auto-populate. HIDLE_MC.json (no patches).
# Person-only provider. Both QIDMs co-fire (PersonQuery + WarrantQuery).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ca_contra_costa_mc.ps1
#
# INPUTS:
#   source\CA_CONTRA_COSTA.xml            -- XML metadata (v5/v4) [AUTHORITATIVE]
#   source\CA_CONTRA_COSTA.pdf            -- CommSys devdoc [CROSS-CHECK]
#   templates\HIDLE_MC.json               -- RMS template (camelCase, registrationState, autoSelect)
#
# QUERYINPUTDATAMAPPING (CommSys -- 2 configs, 6 combos):
#   CaContraCostaJawsPersonQuery   DQ (OOS Name+DOB+Sex+State), DNQ (OOS Name+State),
#                                   INL1 (Name+addr/age/dob), IR.QVC (Name+sex/race),
#                                   IW.N (catch-all Name)
#   CaContraCostaJawsWarrantQuery  IW.N (Name+DOB)
#
# ENTITIES (1 QUERYINPUTFORM):
#   Person -- Name + DOB + Sex + Race + Age + State + Address + AddressCity +
#             RequestingAgencyId(visible) + CaPurpose(hidden)
#
# CA-SPECIFIC:
#   CaRequestPurposeCode -- hidden InpH initialValue='C' (AB 1747).
#   RequestingAgencyId -- visible FormInput (agency-specific JAWS code).
#   Date format: yyyyMMdd (CommsysParseDateRuleHandler).
#   Name format: 'Last, First' (FormatStringRuleHandler).
#   No Vehicle/Firearm/Article/Boat entities.
#   No ImageIndicator, no VehicleStolenQuery, no RandomRequest.

param(
    [string]$Version = "1.0",
    [string]$Phase   = "mc"
)

$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$PHASEDIR = "$DIR\phases\$Phase"
$OUT      = "$DIR\CA_CONTRA_COSTA_MC.json"
$OUTREAD  = "$DIR\CA_CONTRA_COSTA_MC_READABLE.json"
$VEROUT   = "$PHASEDIR\CA_CONTRA_COSTA_MC_v${Version}_${DATE}.json"

New-Item -ItemType Directory -Force -Path $PHASEDIR | Out-Null

$hidle = Get-Content "$DIR\..\..\templates\HIDLE_MC.json" -Raw | ConvertFrom-Json

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

function InpH($fid, $lbl, $maxLen, $parentId, $extra = @{}) {
    $p = [ordered]@{ fieldId = $fid; label = $lbl }
    if ($maxLen) { $p['maxLength'] = $maxLen }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    N 'FormInput' 'Input' $p $false $true @() $parentId
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
# BUNDLE 1: CA_CONTRA_COSTA PROVIDER (camelCase sourceField / combo refs)
# =====================================================================

# 1a. AUTHENTICATION
$auth = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ORI';      size = 12; sourceField = @('ORI');     targetField = 'ORI' }
        [PSCustomObject]@{ name = 'Mnemonic'; size = 25; sourceField = @('mnemonic'); targetField = 'Mnemonic' }
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
    description                = 'Authentication configuration for CA Contra Costa County JAWS'
    handlerFunction            = 'CommsysOriAuthenticationHandler'
    name                       = 'CA_CONTRA_COSTA'
    type                       = 'AUTHENTICATION'
    deviceRegistrationOptional = $false
    provider                   = 'CA_CONTRA_COSTA'
    providerType               = 'Commsys'
    signInRequired             = $false
}

# 1b. QUERYRESULTDATAMAPPING -- cloned from HIDLE_MC
$hiResults = $hidle.bundles[0].configurations | Where-Object { $_.type -eq 'QUERYRESULTDATAMAPPING' }
$results = $hiResults | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$results.name        = 'CA_CONTRA_COSTA_Results'
$results.description = 'Results mapping for CA Contra Costa County JAWS'
$results.provider    = 'CA_CONTRA_COSTA'

# 1c. QUERYMESSAGEFORMAT
$qmf = [PSCustomObject]@{
    description          = 'Configuration for Query format'
    handlerFunction      = 'CommsysWsiOutgoingMessageHandler'
    name                 = 'CA_CONTRA_COSTA_QueryMessageFormat'
    type                 = 'QUERYMESSAGEFORMAT'
    authenticationParent = 'LawEnforcementTransaction'
    payloadParent        = 'LawEnforcementTransaction'
    provider             = 'CA_CONTRA_COSTA'
}

# =====================================================================
# 1d. CaContraCostaJawsPersonQuery
# XML v4: 5 combos (IR.QVC, IW.N, INL1, DQ, DNQ)
# Combo ordering: most specific first (DQ > DNQ > INL1 > IR.QVC > IW.N)
# =====================================================================
$personQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'Address';     size = 3;  sourceField = @('address');     targetField = 'Address' }
        [PSCustomObject]@{ name = 'AddressCity'; size = 13; sourceField = @('addressCity'); targetField = 'AddressCity' }
        [PSCustomObject]@{ name = 'Age';         size = 2;  sourceField = @('age');         targetField = 'Age' }
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{ name = 'CaRequestPurposeCode'; size = 1;  sourceField = @('caRequestPurposeCode'); targetField = 'CaRequestPurposeCode' }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RaceCode'; size = 1; sourceField = @('raceCode'); targetField = 'RaceCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'RequestingAgencyId'; size = 2; sourceField = @('requestingAgencyId'); targetField = 'RequestingAgencyId' }
        [PSCustomObject]@{ name = 'SexCode';  size = 1; sourceField = @('sexCode');  targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';    size = 2; sourceField = @('registrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','birthDate','sexCode','registrationState','requestingAgencyId'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','registrationState','requestingAgencyId'); any = @('age','addressCity','sexCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'DNQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','requestingAgencyId'); any = @('address','addressCity','birthDate','age') }
            primaryFieldReference = 'Name'
            keyReference          = 'INL1'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('caRequestPurposeCode','nameLast','nameFirst','requestingAgencyId'); any = @('sexCode','raceCode') }
            primaryFieldReference = 'Name'
            keyReference          = 'IR.QVC'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','requestingAgencyId'); any = @('birthDate') }
            primaryFieldReference = 'Name'
            keyReference          = 'IW.N'
            state                 = 'In/Out'
        }
    )
    description     = 'CaContraCostaJawsPersonQuery -- DQ (OOS Name+DOB+Sex+State), DNQ (OOS Name+State), INL1 (Name+addr/age/dob), IR.QVC (Name+sex/race), IW.N (catch-all).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CONTRA_COSTA_CaContraCostaJawsPersonQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CONTRA_COSTA'
    providerType    = 'Commsys'
    query           = 'CaContraCostaJawsPersonQuery'
    queryLabel      = 'JAWS Person'
    targetEntity    = 'Person'
}

# =====================================================================
# 1e. CaContraCostaJawsWarrantQuery
# XML v3: 1 combo (IW.N). Co-fires with PersonQuery on Name+DOB.
# =====================================================================
$warrantQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size = 8; sourceField = @('birthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
            size = 30; sourceField = @('nameLast','nameFirst'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'RequestingAgencyId'; size = 2; sourceField = @('requestingAgencyId'); targetField = 'RequestingAgencyId' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('nameLast','nameFirst','birthDate','requestingAgencyId'); any = @() }
            primaryFieldReference = 'Name'
            keyReference          = 'IW.N'
            state                 = 'In/Out'
        }
    )
    description     = 'CaContraCostaJawsWarrantQuery -- IW.N (Name+DOB). Contra Costa warrant search.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'CA_CONTRA_COSTA_CaContraCostaJawsWarrantQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'CA_CONTRA_COSTA'
    providerType    = 'Commsys'
    query           = 'CaContraCostaJawsWarrantQuery'
    queryLabel      = 'JAWS Warrant'
    targetEntity    = 'Person'
}

$ccBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $personQuery, $warrantQuery)
    description    = "Provider configuration for CA_CONTRA_COSTA v${Version}"
    name           = 'CA_CONTRA_COSTA'
    type           = 'BUNDLE'
    provider       = 'CA_CONTRA_COSTA'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 1 form: Person only. MC layout: 2 cards (Name Search + Options).
# =====================================================================

$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_NAME'
        title = 'NAME SEARCH'
        rows  = @(
            @{ id = 'ROW_NAME_1'; cols = @('6','6'); fields = @(
                @{ id = 'nameFirst_Input'; node = Inp 'nameFirst' 'First Name' '30' 'ROW_NAME_1' }
                @{ id = 'nameLast_Input';  node = Inp 'nameLast'  'Last Name'  '30' 'ROW_NAME_1' }
            )}
            @{ id = 'ROW_NAME_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'birthDate' 'Date of Birth'                                                           'ROW_NAME_2' }
                @{ id = 'sexCode_Input';   node = Sel 'sexCode'   'Sex'  @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }            'ROW_NAME_2' }
                @{ id = 'raceCode_Input';  node = Sel 'raceCode'  'Race' @{ codeTypeCategory = 'NIBRS_RACE'; codeTypeSource = 'NIBRS' }      'ROW_NAME_2' }
            )}
            @{ id = 'ROW_NAME_3'; cols = @('6','6'); fields = @(
                @{ id = 'age_Input';       node = Inp 'age'       'Age' '2' 'ROW_NAME_3' }
                @{ id = 'address_Input';   node = Inp 'address'   'Address Code' '3' 'ROW_NAME_3' }
            )}
        )
    }
    @{
        id    = 'CARD_OPTIONS'
        title = 'SEARCH OPTIONS'
        rows  = @(
            @{ id = 'ROW_OPT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'registrationState_Input';   node = Sel 'registrationState' 'State' @{ attributeTypeId = 'STATE' } 'ROW_OPT_1' }
                @{ id = 'addressCity_Input';          node = Inp 'addressCity' 'City' '13' 'ROW_OPT_1' }
                @{ id = 'requestingAgencyId_Input';   node = Inp 'requestingAgencyId' 'Agency ID' '2' 'ROW_OPT_1' }
            )}
            @{ id = 'ROW_OPT_2'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'caRequestPurposeCode_Input'; node = InpH 'caRequestPurposeCode' 'Purpose Code' '1' 'ROW_OPT_2' @{ initialValue = 'C' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- CaContraCostaJawsPersonQuery + CaContraCostaJawsWarrantQuery (co-fire).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

$entitiesBundle = [PSCustomObject]@{
    configurations = @($personForm)
    description    = 'Entity form configurations for CA_CONTRA_COSTA -- MC variant'
    name           = 'ENTITIES'
    type           = 'BUNDLE'
    order          = [PSCustomObject]@{
        default         = @('Person')
        CAD_DISPATCH    = @('Person')
        FIRST_RESPONDER = @('Person')
    }
    provider       = 'MARK43'
}

# =====================================================================
# BUNDLE 3: RMS (from HIDLE_MC -- camelCase, registrationState, autoSelect pre-configured)
# =====================================================================
$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq 'RMS' }
$rmsVehQidm    = $rmsBundle.configurations | Where-Object { $_.name -eq 'RMS Vehicle search query' }
$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq 'Person' }

# RMS cleanup: remove unused HIDLE fields
$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
$rmsVehQidm.attributes   = @($rmsVehQidm.attributes   | Where-Object { $_.name -notin $deadVehAttrs })
$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object { $_.keyReference -notin @('licensePlateOutAndState','OwnerFirstAndLastName') })
foreach ($combo in $rmsVehQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })
}

$deadPerAttrs = @('socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race')
$rmsPersonQidm.attributes   = @($rmsPersonQidm.attributes   | Where-Object { $_.name -notin $deadPerAttrs })
$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {
    $_.keyReference -notin @('firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS',
        'firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
})
foreach ($combo in $rmsPersonQidm.combinations) {
    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne 'RaceCode' })
}

# =====================================================================
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $ccBundle, $rmsBundle)
}

$json = $output | ConvertTo-Json -Depth 100 -Compress
$jsonReadable = $output | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($OUT,     $json,         [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($OUTREAD, $jsonReadable,  [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($VEROUT,  $json,         [System.Text.UTF8Encoding]::new($false))

Write-Host "Built CA_CONTRA_COSTA_MC.json v${Version}"
Write-Host "  -> $OUT (minified)"
Write-Host "  -> $OUTREAD (readable)"
Write-Host "  -> $VEROUT (phase archive)"

$validatorPath = Join-Path (Resolve-Path "$PSScriptRoot\..\..\..\tools").Path "validate.ps1"
powershell.exe -ExecutionPolicy Bypass -File $validatorPath -Path $OUT
