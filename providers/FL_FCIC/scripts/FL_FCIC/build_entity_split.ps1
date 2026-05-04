$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$eb = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb = $data.bundles | Where-Object { $_.name -eq 'FL_FCIC' }

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: Undo Change 4 entity side
#   Remove ENTITY_PersonInState and ENTITY_PersonOOS
#   Keep the 4-mapping split from Change 4 — we'll just rename targetEntity values
# ─────────────────────────────────────────────────────────────────────────────
$removeNames = @('ENTITY_PersonInState','ENTITY_PersonOOS','ENTITY_FL_DL','ENTITY_OOS_DL','ENTITY_FL_DH','ENTITY_OOS_DH')
$cfgList = [System.Collections.Generic.List[object]]::new()
$eb.configurations | Where-Object { $_.name -notin $removeNames } | ForEach-Object { $cfgList.Add($_) }
$eb.configurations = $cfgList.ToArray()

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: Rename targetEntity on the 4 FL_FCIC driver mappings
# ─────────────────────────────────────────────────────────────────────────────
$dlI = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseInState' }
$dlO = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
$dhI = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryInState' }
$dhO = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

$dlI.targetEntity = 'FL Driver License'
$dlO.targetEntity = 'OOS Driver License'
$dhI.targetEntity = 'FL Driver History'
$dhO.targetEntity = 'OOS Driver History'

# ─────────────────────────────────────────────────────────────────────────────
# Layout node builder helpers
# ─────────────────────────────────────────────────────────────────────────────
function Node-Root() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'Root' }
        displayName = 'Root'
        props = [PSCustomObject]@{}
        isCanvas = $true
        hidden = $false
        nodes = [string[]]@('FORM_ROOT')
        parent = $null
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-FormRoot() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'Form' }
        displayName = 'Form'
        props = [PSCustomObject]@{ hidePageItems = $true; layout = 'page' }
        isCanvas = $true
        hidden = $false
        nodes = [string[]]@('ROOT_PAGE')
        parent = 'ROOT'
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-RootPage([string[]]$cards) {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'Page' }
        displayName = 'Page'
        props = [PSCustomObject]@{ title = 'Page 1' }
        isCanvas = $true
        hidden = $false
        nodes = $cards
        parent = 'FORM_ROOT'
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-Card($title, [string[]]$rows, $parent) {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'Card' }
        displayName = 'Card'
        props = [PSCustomObject]@{ title = $title }
        isCanvas = $true
        hidden = $false
        nodes = $rows
        parent = $parent
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-Row([string[]]$cols, [string[]]$inputs, $parent) {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'Row' }
        displayName = 'Row'
        props = [PSCustomObject]@{ templateColumns = $cols }
        isCanvas = $true
        hidden = $false
        nodes = $inputs
        parent = $parent
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-Input($fieldId, $label, $maxLength, $parent) {
    $p = [PSCustomObject]@{ fieldId = $fieldId; label = $label }
    if ($maxLength) { $p | Add-Member -NotePropertyName 'maxLength' -NotePropertyValue "$maxLength" }
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'FormInput' }
        displayName = 'Input'
        props = $p
        isCanvas = $false
        hidden = $false
        nodes = [string[]]@()
        parent = $parent
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-Date($fieldId, $label, $parent) {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'FormDate' }
        displayName = 'Date'
        props = [PSCustomObject]@{ fieldId = $fieldId; label = $label }
        isCanvas = $false
        hidden = $false
        nodes = [string[]]@()
        parent = $parent
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-Select($fieldId, $label, $attrTypeId, $parent) {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'FormSelect' }
        displayName = 'Select'
        props = [PSCustomObject]@{ fieldId = $fieldId; label = $label; attributeTypeId = $attrTypeId }
        isCanvas = $false
        hidden = $false
        nodes = [string[]]@()
        parent = $parent
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-CtxCard() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'ContextInfoCard' }
        displayName = 'ContextInfoCard'
        props = [PSCustomObject]@{}
        isCanvas = $true
        hidden = $false
        nodes = [string[]]@('ROW_0')
        parent = 'ROOT_PAGE'
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-CtxRow() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'Row' }
        displayName = 'Row'
        props = [PSCustomObject]@{ templateColumns = [string[]]@('6','6') }
        isCanvas = $true
        hidden = $false
        nodes = [string[]]@('CadUnit_Input','CadEvent_Input')
        parent = 'CONTEXT_INFO_CARD'
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-CtxUnit() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'FormInput' }
        displayName = 'Input'
        props = [PSCustomObject]@{ fieldId = 'CadUnit'; label = 'CAD Unit' }
        isCanvas = $false
        hidden = $false
        nodes = [string[]]@()
        parent = 'ROW_0'
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-CtxEvent() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'FormInput' }
        displayName = 'Input'
        props = [PSCustomObject]@{ fieldId = 'CadEvent'; label = 'CAD Event' }
        isCanvas = $false
        hidden = $false
        nodes = [string[]]@()
        parent = 'ROW_0'
        linkedNodes = [PSCustomObject]@{}
    }
}
function Node-LinkEvent() {
    return [PSCustomObject]@{
        type = [PSCustomObject]@{ resolvedName = 'FormCheckbox' }
        displayName = 'Checkbox'
        props = [PSCustomObject]@{ fieldId = 'LinkToEvent'; label = 'Link to Event' }
        isCanvas = $false
        hidden = $false
        nodes = [string[]]@()
        parent = 'ROOT_PAGE'
        linkedNodes = [PSCustomObject]@{}
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: add context info nodes to a layout object (CAD/FR)
# ─────────────────────────────────────────────────────────────────────────────
function Add-CtxNodes($lo, $includeLinkToEvent) {
    $lo | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue (Node-CtxCard) -Force
    $lo | Add-Member -NotePropertyName 'ROW_0'             -NotePropertyValue (Node-CtxRow)  -Force
    $lo | Add-Member -NotePropertyName 'CadUnit_Input'     -NotePropertyValue (Node-CtxUnit) -Force
    $lo | Add-Member -NotePropertyName 'CadEvent_Input'    -NotePropertyValue (Node-CtxEvent)-Force
    if ($includeLinkToEvent) {
        $lo | Add-Member -NotePropertyName 'LinkToEvent_Input' -NotePropertyValue (Node-LinkEvent) -Force
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Helper: build a 3-variant layout from a "build-default-layout" function
# ─────────────────────────────────────────────────────────────────────────────
function Build-Layout($buildFn) {
    $layout = [PSCustomObject]@{}

    # .Invoke() wraps the return value in Object[] — use [0] to unwrap
    $def = $buildFn.Invoke($false, $null)[0]
    $layout | Add-Member -NotePropertyName 'default' -NotePropertyValue $def

    $cad = $buildFn.Invoke($true, $false)[0]
    $layout | Add-Member -NotePropertyName 'CAD_DISPATCH' -NotePropertyValue $cad

    $fr = $buildFn.Invoke($true, $true)[0]
    $layout | Add-Member -NotePropertyName 'FIRST_RESPONDER' -NotePropertyValue $fr

    return $layout
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTITY: FL Driver License  (targetEntity = 'FL Driver License')
# Mapping: FL_FCIC_DriverLicenseInState
# Combos:  FDQName (Name+DOB+Sex), FDQOperatorLicenseNumber (OLN),
#          QWName  (Name+DOB+Sex), QWOperatorLicenseNumber  (Name+OLN)
# ─────────────────────────────────────────────────────────────────────────────
$buildFLDL = {
    param($hasCtx, $hasLink)
    $lo = [PSCustomObject]@{}
    $lo | Add-Member -NotePropertyName 'ROOT'       -NotePropertyValue (Node-Root)
    $lo | Add-Member -NotePropertyName 'FORM_ROOT'  -NotePropertyValue (Node-FormRoot)

    $cards = [System.Collections.Generic.List[string]]::new()
    if ($hasCtx) { $cards.Add('CONTEXT_INFO_CARD') }
    $cards.Add('CARD_FLDL_NAME'); $cards.Add('CARD_FLDL_OLN')
    $lo | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (Node-RootPage $cards.ToArray())

    if ($hasCtx) { Add-CtxNodes $lo $hasLink }

    # Card: FL DHSMV by NAME
    $lo | Add-Member -NotePropertyName 'CARD_FLDL_NAME' -NotePropertyValue (Node-Card 'FL DHSMV by NAME' @('FLDL_NAME_ROW1','FLDL_NAME_ROW2') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'FLDL_NAME_ROW1' -NotePropertyValue (Node-Row @('3','3','3','3') @('FLDL_NameFirst','FLDL_NameLast','FLDL_NameMiddle','FLDL_NameSuffix') 'CARD_FLDL_NAME')
    $lo | Add-Member -NotePropertyName 'FLDL_NameFirst'  -NotePropertyValue (Node-Input  'NameFirst'  'First Name'   $null         'FLDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDL_NameLast'   -NotePropertyValue (Node-Input  'NameLast'   'Last Name'    $null         'FLDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDL_NameMiddle' -NotePropertyValue (Node-Input  'NameMiddle' 'Middle Name'  $null         'FLDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDL_NameSuffix' -NotePropertyValue (Node-Input  'NameSuffix' 'Suffix'       $null         'FLDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDL_NAME_ROW2' -NotePropertyValue (Node-Row @('6','6') @('FLDL_BirthDate','FLDL_SexCode') 'CARD_FLDL_NAME')
    $lo | Add-Member -NotePropertyName 'FLDL_BirthDate' -NotePropertyValue (Node-Date   'BirthDate'  'Date of Birth'               'FLDL_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'FLDL_SexCode'   -NotePropertyValue (Node-Select 'SexCode'    'Sex'  'SEX'                  'FLDL_NAME_ROW2')

    # Card: FL DHSMV by OLN
    $lo | Add-Member -NotePropertyName 'CARD_FLDL_OLN'  -NotePropertyValue (Node-Card 'FL DHSMV by OLN' @('FLDL_OLN_ROW1') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'FLDL_OLN_ROW1'  -NotePropertyValue (Node-Row @('12') @('FLDL_OLN') 'CARD_FLDL_OLN')
    $lo | Add-Member -NotePropertyName 'FLDL_OLN'       -NotePropertyValue (Node-Input 'OperatorLicenseNumber' 'Operator License #' 20 'FLDL_OLN_ROW1')

    return $lo
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTITY: OOS Driver License  (targetEntity = 'OOS Driver License')
# Mapping: FL_FCIC_DriverLicenseQuery
# Combos:  DQName (Name+DOB+Sex+StateOOS), DQOperatorLicenseNumber (OLN+State)
# ─────────────────────────────────────────────────────────────────────────────
$buildOOSDL = {
    param($hasCtx, $hasLink)
    $lo = [PSCustomObject]@{}
    $lo | Add-Member -NotePropertyName 'ROOT'      -NotePropertyValue (Node-Root)
    $lo | Add-Member -NotePropertyName 'FORM_ROOT' -NotePropertyValue (Node-FormRoot)

    $cards = [System.Collections.Generic.List[string]]::new()
    if ($hasCtx) { $cards.Add('CONTEXT_INFO_CARD') }
    $cards.Add('CARD_OOSDL_NAME'); $cards.Add('CARD_OOSDL_OLN')
    $lo | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (Node-RootPage $cards.ToArray())

    if ($hasCtx) { Add-CtxNodes $lo $hasLink }

    # Card: OOS by NAME
    $lo | Add-Member -NotePropertyName 'CARD_OOSDL_NAME' -NotePropertyValue (Node-Card 'OOS by NAME' @('OOSDL_NAME_ROW1','OOSDL_NAME_ROW2','OOSDL_NAME_ROW3') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'OOSDL_NAME_ROW1' -NotePropertyValue (Node-Row @('3','3','3','3') @('OOSDL_NameFirst','OOSDL_NameLast','OOSDL_NameMiddle','OOSDL_NameSuffix') 'CARD_OOSDL_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDL_NameFirst'  -NotePropertyValue (Node-Input  'NameFirstOOS'  'First Name'  $null 'OOSDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDL_NameLast'   -NotePropertyValue (Node-Input  'NameLastOOS'   'Last Name'   $null 'OOSDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDL_NameMiddle' -NotePropertyValue (Node-Input  'NameMiddleOOS' 'Middle Name' $null 'OOSDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDL_NameSuffix' -NotePropertyValue (Node-Input  'NameSuffixOOS' 'Suffix'      $null 'OOSDL_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDL_NAME_ROW2' -NotePropertyValue (Node-Row @('6','6') @('OOSDL_BirthDate','OOSDL_SexCode') 'CARD_OOSDL_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDL_BirthDate' -NotePropertyValue (Node-Date   'BirthDateOOS' 'Date of Birth' 'OOSDL_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'OOSDL_SexCode'   -NotePropertyValue (Node-Select 'SexCodeOOS'   'Sex' 'SEX'     'OOSDL_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'OOSDL_NAME_ROW3' -NotePropertyValue (Node-Row @('12') @('OOSDL_RegState') 'CARD_OOSDL_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDL_RegState'  -NotePropertyValue (Node-Select 'RegistrationStateOOS' 'State (required)' 'STATE' 'OOSDL_NAME_ROW3')

    # Card: OOS by OLN
    $lo | Add-Member -NotePropertyName 'CARD_OOSDL_OLN'  -NotePropertyValue (Node-Card 'OOS by OLN' @('OOSDL_OLN_ROW1') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'OOSDL_OLN_ROW1'  -NotePropertyValue (Node-Row @('6','6') @('OOSDL_OLN','OOSDL_OLN_State') 'CARD_OOSDL_OLN')
    $lo | Add-Member -NotePropertyName 'OOSDL_OLN'       -NotePropertyValue (Node-Input  'OperatorLicenseNumberOOS' 'Operator License #' 20 'OOSDL_OLN_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDL_OLN_State' -NotePropertyValue (Node-Select 'RegistrationState' 'State (required)' 'STATE' 'OOSDL_OLN_ROW1')

    return $lo
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTITY: FL Driver History  (targetEntity = 'FL Driver History')
# Mapping: FL_FCIC_DriverHistoryInState
# Combos:  KQName (Name+DOB+Sex+Attention+Purpose), KQOperatorLicenseNumber (OLN+Attention+Purpose)
# ─────────────────────────────────────────────────────────────────────────────
$buildFLDH = {
    param($hasCtx, $hasLink)
    $lo = [PSCustomObject]@{}
    $lo | Add-Member -NotePropertyName 'ROOT'      -NotePropertyValue (Node-Root)
    $lo | Add-Member -NotePropertyName 'FORM_ROOT' -NotePropertyValue (Node-FormRoot)

    $cards = [System.Collections.Generic.List[string]]::new()
    if ($hasCtx) { $cards.Add('CONTEXT_INFO_CARD') }
    $cards.Add('CARD_FLDH_NAME'); $cards.Add('CARD_FLDH_OLN')
    $lo | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (Node-RootPage $cards.ToArray())

    if ($hasCtx) { Add-CtxNodes $lo $hasLink }

    # Card: FL DH by NAME
    $lo | Add-Member -NotePropertyName 'CARD_FLDH_NAME' -NotePropertyValue (Node-Card 'FL DH by NAME' @('FLDH_NAME_ROW1','FLDH_NAME_ROW2','FLDH_NAME_ROW3') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'FLDH_NAME_ROW1' -NotePropertyValue (Node-Row @('3','3','3','3') @('FLDH_NameFirst','FLDH_NameLast','FLDH_NameMiddle','FLDH_NameSuffix') 'CARD_FLDH_NAME')
    $lo | Add-Member -NotePropertyName 'FLDH_NameFirst'  -NotePropertyValue (Node-Input  'NameFirst'  'First Name'   $null 'FLDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDH_NameLast'   -NotePropertyValue (Node-Input  'NameLast'   'Last Name'    $null 'FLDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDH_NameMiddle' -NotePropertyValue (Node-Input  'NameMiddle' 'Middle Name'  $null 'FLDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDH_NameSuffix' -NotePropertyValue (Node-Input  'NameSuffix' 'Suffix'       $null 'FLDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDH_NAME_ROW2' -NotePropertyValue (Node-Row @('6','6') @('FLDH_BirthDate','FLDH_SexCode') 'CARD_FLDH_NAME')
    $lo | Add-Member -NotePropertyName 'FLDH_BirthDate' -NotePropertyValue (Node-Date   'BirthDate' 'Date of Birth' 'FLDH_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'FLDH_SexCode'   -NotePropertyValue (Node-Select 'SexCode'   'Sex'  'SEX'    'FLDH_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'FLDH_NAME_ROW3' -NotePropertyValue (Node-Row @('6','6') @('FLDH_AttentionName','FLDH_PurposeCodeName') 'CARD_FLDH_NAME')
    $lo | Add-Member -NotePropertyName 'FLDH_AttentionName'   -NotePropertyValue (Node-Input 'AttentionName'   'Attention'    30 'FLDH_NAME_ROW3')
    $lo | Add-Member -NotePropertyName 'FLDH_PurposeCodeName' -NotePropertyValue (Node-Input 'PurposeCodeName' 'Purpose Code' 1  'FLDH_NAME_ROW3')

    # Card: FL DH by OLN
    $lo | Add-Member -NotePropertyName 'CARD_FLDH_OLN'  -NotePropertyValue (Node-Card 'FL DH by OLN' @('FLDH_OLN_ROW1','FLDH_OLN_ROW2') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'FLDH_OLN_ROW1'  -NotePropertyValue (Node-Row @('12') @('FLDH_OLN') 'CARD_FLDH_OLN')
    $lo | Add-Member -NotePropertyName 'FLDH_OLN'       -NotePropertyValue (Node-Input 'OperatorLicenseNumber' 'Operator License #' 20 'FLDH_OLN_ROW1')
    $lo | Add-Member -NotePropertyName 'FLDH_OLN_ROW2'  -NotePropertyValue (Node-Row @('6','6') @('FLDH_AttentionDL','FLDH_PurposeCodeDL') 'CARD_FLDH_OLN')
    $lo | Add-Member -NotePropertyName 'FLDH_AttentionDL'   -NotePropertyValue (Node-Input 'AttentionDL'   'Attention'    30 'FLDH_OLN_ROW2')
    $lo | Add-Member -NotePropertyName 'FLDH_PurposeCodeDL' -NotePropertyValue (Node-Input 'PurposeCodeDL' 'Purpose Code' 1  'FLDH_OLN_ROW2')

    return $lo
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTITY: OOS Driver History  (targetEntity = 'OOS Driver History')
# Mapping: FL_FCIC_DriverHistoryQuery
# Combos:  KQNameOOS (OOS Name+DOB+Sex+StateOOS+AttentionOOS+PurposeOOS),
#          KQOperatorLicenseNumberOOS (OLN+State+Attention+PurposeCode)
# ─────────────────────────────────────────────────────────────────────────────
$buildOOSDH = {
    param($hasCtx, $hasLink)
    $lo = [PSCustomObject]@{}
    $lo | Add-Member -NotePropertyName 'ROOT'      -NotePropertyValue (Node-Root)
    $lo | Add-Member -NotePropertyName 'FORM_ROOT' -NotePropertyValue (Node-FormRoot)

    $cards = [System.Collections.Generic.List[string]]::new()
    if ($hasCtx) { $cards.Add('CONTEXT_INFO_CARD') }
    $cards.Add('CARD_OOSDH_NAME'); $cards.Add('CARD_OOSDH_OLN')
    $lo | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (Node-RootPage $cards.ToArray())

    if ($hasCtx) { Add-CtxNodes $lo $hasLink }

    # Card: OOS DH by NAME
    $lo | Add-Member -NotePropertyName 'CARD_OOSDH_NAME' -NotePropertyValue (Node-Card 'OOS DH by NAME' @('OOSDH_NAME_ROW1','OOSDH_NAME_ROW2','OOSDH_NAME_ROW3','OOSDH_NAME_ROW4') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'OOSDH_NAME_ROW1' -NotePropertyValue (Node-Row @('3','3','3','3') @('OOSDH_NameFirst','OOSDH_NameLast','OOSDH_NameMiddle','OOSDH_NameSuffix') 'CARD_OOSDH_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDH_NameFirst'  -NotePropertyValue (Node-Input  'NameFirstOOS'  'First Name'  $null 'OOSDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDH_NameLast'   -NotePropertyValue (Node-Input  'NameLastOOS'   'Last Name'   $null 'OOSDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDH_NameMiddle' -NotePropertyValue (Node-Input  'NameMiddleOOS' 'Middle Name' $null 'OOSDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDH_NameSuffix' -NotePropertyValue (Node-Input  'NameSuffixOOS' 'Suffix'      $null 'OOSDH_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDH_NAME_ROW2' -NotePropertyValue (Node-Row @('6','6') @('OOSDH_BirthDate','OOSDH_SexCode') 'CARD_OOSDH_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDH_BirthDate' -NotePropertyValue (Node-Date   'BirthDateOOS' 'Date of Birth' 'OOSDH_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'OOSDH_SexCode'   -NotePropertyValue (Node-Select 'SexCodeOOS'   'Sex'  'SEX'    'OOSDH_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'OOSDH_NAME_ROW3' -NotePropertyValue (Node-Row @('12') @('OOSDH_RegState') 'CARD_OOSDH_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDH_RegState'  -NotePropertyValue (Node-Select 'RegistrationStateOOS' 'State (required)' 'STATE' 'OOSDH_NAME_ROW3')
    $lo | Add-Member -NotePropertyName 'OOSDH_NAME_ROW4' -NotePropertyValue (Node-Row @('6','6') @('OOSDH_AttentionOOS','OOSDH_PurposeCodeOOS') 'CARD_OOSDH_NAME')
    $lo | Add-Member -NotePropertyName 'OOSDH_AttentionOOS'   -NotePropertyValue (Node-Input 'AttentionOOS'   'Attention'    30 'OOSDH_NAME_ROW4')
    $lo | Add-Member -NotePropertyName 'OOSDH_PurposeCodeOOS' -NotePropertyValue (Node-Input 'PurposeCodeOOS' 'Purpose Code' 1  'OOSDH_NAME_ROW4')

    # Card: OOS DH by OLN
    $lo | Add-Member -NotePropertyName 'CARD_OOSDH_OLN'  -NotePropertyValue (Node-Card 'OOS DH by OLN' @('OOSDH_OLN_ROW1','OOSDH_OLN_ROW2','OOSDH_OLN_ROW3') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'OOSDH_OLN_ROW1'  -NotePropertyValue (Node-Row @('6','6') @('OOSDH_OLN','OOSDH_OLN_State') 'CARD_OOSDH_OLN')
    $lo | Add-Member -NotePropertyName 'OOSDH_OLN'       -NotePropertyValue (Node-Input  'OperatorLicenseNumberOOS' 'Operator License #' 20 'OOSDH_OLN_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDH_OLN_State' -NotePropertyValue (Node-Select 'RegistrationState' 'State (required)' 'STATE' 'OOSDH_OLN_ROW1')
    $lo | Add-Member -NotePropertyName 'OOSDH_OLN_ROW2'  -NotePropertyValue (Node-Row @('6','6') @('OOSDH_Attention','OOSDH_PurposeCode') 'CARD_OOSDH_OLN')
    $lo | Add-Member -NotePropertyName 'OOSDH_Attention'   -NotePropertyValue (Node-Input 'Attention'   'Attention'    30 'OOSDH_OLN_ROW2')
    $lo | Add-Member -NotePropertyName 'OOSDH_PurposeCode' -NotePropertyValue (Node-Input 'PurposeCode' 'Purpose Code' 1  'OOSDH_OLN_ROW2')

    return $lo
}

# ─────────────────────────────────────────────────────────────────────────────
# Build the 4 entity configurations
# ─────────────────────────────────────────────────────────────────────────────
$entityFLDL = [PSCustomObject]@{
    name         = 'ENTITY_FL_DL'
    type         = 'QUERYINPUTFORM'
    description  = 'FL DHSMV Driver License query form'
    label        = 'FL Driver License'
    targetEntity = 'FL Driver License'
    layout       = (Build-Layout $buildFLDL)
}
$entityOOSDL = [PSCustomObject]@{
    name         = 'ENTITY_OOS_DL'
    type         = 'QUERYINPUTFORM'
    description  = 'Nlets Out-of-State Driver License query form'
    label        = 'OOS Driver License'
    targetEntity = 'OOS Driver License'
    layout       = (Build-Layout $buildOOSDL)
}
$entityFLDH = [PSCustomObject]@{
    name         = 'ENTITY_FL_DH'
    type         = 'QUERYINPUTFORM'
    description  = 'FL Driver History query form'
    label        = 'FL Driver History'
    targetEntity = 'FL Driver History'
    layout       = (Build-Layout $buildFLDH)
}
$entityOOSDH = [PSCustomObject]@{
    name         = 'ENTITY_OOS_DH'
    type         = 'QUERYINPUTFORM'
    description  = 'OOS Driver History query form'
    label        = 'OOS Driver History'
    targetEntity = 'OOS Driver History'
    layout       = (Build-Layout $buildOOSDH)
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: Insert all 4 entities into ENTITIES bundle
# Insert before ENTITY_Vehicle to group driver forms at the front
# ─────────────────────────────────────────────────────────────────────────────
$newCfgList = [System.Collections.Generic.List[object]]::new()
$newCfgList.Add($entityFLDL)
$newCfgList.Add($entityOOSDL)
$newCfgList.Add($entityFLDH)
$newCfgList.Add($entityOOSDH)
$eb.configurations | ForEach-Object { $newCfgList.Add($_) }
$eb.configurations = $newCfgList.ToArray()

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: Update entity order
#   Replace 'Person (In State)' and 'Person (Out of State)' with the 4 new entities
#   (or replace 'Person' if somehow we're back to that state)
# ─────────────────────────────────────────────────────────────────────────────
$newEntities   = @('FL Driver License','OOS Driver License','FL Driver History','OOS Driver History')
$removeEntities = @('Person','Person (In State)','Person (Out of State)')

foreach ($v in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $cur = [System.Collections.Generic.List[string]]::new()
    $inserted = $false
    $eb.order.PSObject.Properties[$v].Value | ForEach-Object {
        if ($_ -in $removeEntities) {
            if (-not $inserted) {
                $newEntities | ForEach-Object { $cur.Add($_) }
                $inserted = $true
            }
        } else {
            $cur.Add($_)
        }
    }
    # If no Person-type entity was found in the order, prepend the new ones
    if (-not $inserted) {
        $newEntityList = [System.Collections.Generic.List[string]]::new()
        $newEntities | ForEach-Object { $newEntityList.Add($_) }
        $cur.ToArray() | ForEach-Object { $newEntityList.Add($_) }
        $cur = $newEntityList
    }
    $eb.order.PSObject.Properties[$v].Value = $cur.ToArray()
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: Save
# ─────────────────────────────────────────────────────────────────────────────
$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# ─────────────────────────────────────────────────────────────────────────────
# Verify
# ─────────────────────────────────────────────────────────────────────────────
$v2  = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2 = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb2 = $v2.bundles | Where-Object { $_.name -eq 'FL_FCIC' }

Write-Host ''
Write-Host 'ENTITIES configs:' ($eb2.configurations.name -join ', ')
Write-Host 'FL_FCIC configs:' $fb2.configurations.Count
Write-Host 'Order default:' ($eb2.order.default -join ', ')
Write-Host 'Order CAD:' ($eb2.order.CAD_DISPATCH -join ', ')
Write-Host ''
$newNames = @('ENTITY_FL_DL','ENTITY_OOS_DL','ENTITY_FL_DH','ENTITY_OOS_DH')
foreach ($n in $newNames) {
    $cfg = $eb2.configurations | Where-Object { $_.name -eq $n }
    Write-Host "$n  targetEntity='$($cfg.targetEntity)'  defaultNodes:" ($cfg.layout.default.PSObject.Properties.Name -join ',')
}
Write-Host ''
$drvNames = @('FL_FCIC_DriverLicenseInState','FL_FCIC_DriverLicenseQuery','FL_FCIC_DriverHistoryInState','FL_FCIC_DriverHistoryQuery')
foreach ($n in $drvNames) {
    $cfg = $fb2.configurations | Where-Object { $_.name -eq $n }
    Write-Host "$n  targetEntity='$($cfg.targetEntity)'  combos:" ($cfg.combinations.keyReference -join ',')
}
