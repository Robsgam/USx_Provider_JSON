$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$eb = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb = $data.bundles | Where-Object { $_.name -eq 'FL_FCIC' }

# Grab InState mappings before removing them
$dlI = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseInState' }
$dhI = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryInState' }
$dlO = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
$dhO = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

# ─────────────────────────────────────────────────────────────────────────────
# Node builder helpers (same as build_entity_split.ps1)
# ─────────────────────────────────────────────────────────────────────────────
function Node-Root() {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='Root'}; displayName='Root'; props=[PSCustomObject]@{}; isCanvas=$true; hidden=$false; nodes=[string[]]@('FORM_ROOT'); parent=$null; linkedNodes=[PSCustomObject]@{} }
}
function Node-FormRoot() {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='Form'}; displayName='Form'; props=[PSCustomObject]@{hidePageItems=$true;layout='page'}; isCanvas=$true; hidden=$false; nodes=[string[]]@('ROOT_PAGE'); parent='ROOT'; linkedNodes=[PSCustomObject]@{} }
}
function Node-RootPage([string[]]$cards) {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='Page'}; displayName='Page'; props=[PSCustomObject]@{title='Page 1'}; isCanvas=$true; hidden=$false; nodes=$cards; parent='FORM_ROOT'; linkedNodes=[PSCustomObject]@{} }
}
function Node-Card($title,[string[]]$rows,$parent) {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='Card'}; displayName='Card'; props=[PSCustomObject]@{title=$title}; isCanvas=$true; hidden=$false; nodes=$rows; parent=$parent; linkedNodes=[PSCustomObject]@{} }
}
function Node-Row([string[]]$cols,[string[]]$inputs,$parent) {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='Row'}; displayName='Row'; props=[PSCustomObject]@{templateColumns=$cols}; isCanvas=$true; hidden=$false; nodes=$inputs; parent=$parent; linkedNodes=[PSCustomObject]@{} }
}
function Node-Input($fieldId,$label,$maxLength,$parent) {
    $p=[PSCustomObject]@{fieldId=$fieldId;label=$label}
    if($maxLength){$p|Add-Member -NotePropertyName 'maxLength' -NotePropertyValue "$maxLength"}
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='FormInput'}; displayName='Input'; props=$p; isCanvas=$false; hidden=$false; nodes=[string[]]@(); parent=$parent; linkedNodes=[PSCustomObject]@{} }
}
function Node-Date($fieldId,$label,$parent) {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='FormDate'}; displayName='Date'; props=[PSCustomObject]@{fieldId=$fieldId;label=$label}; isCanvas=$false; hidden=$false; nodes=[string[]]@(); parent=$parent; linkedNodes=[PSCustomObject]@{} }
}
function Node-Select($fieldId,$label,$attrTypeId,$parent) {
    [PSCustomObject]@{ type=[PSCustomObject]@{resolvedName='FormSelect'}; displayName='Select'; props=[PSCustomObject]@{fieldId=$fieldId;label=$label;attributeTypeId=$attrTypeId}; isCanvas=$false; hidden=$false; nodes=[string[]]@(); parent=$parent; linkedNodes=[PSCustomObject]@{} }
}

# ─────────────────────────────────────────────────────────────────────────────
# Build ENTITY_Person layout — all four cards, original _In / _OOS node IDs
# ─────────────────────────────────────────────────────────────────────────────
function Build-PersonLayout($hasCtx, $hasLink) {
    $lo = [PSCustomObject]@{}
    $lo | Add-Member -NotePropertyName 'ROOT'      -NotePropertyValue (Node-Root)
    $lo | Add-Member -NotePropertyName 'FORM_ROOT' -NotePropertyValue (Node-FormRoot)

    $cards = [System.Collections.Generic.List[string]]::new()
    $cards.Add('CARD_INSTATE_NAME'); $cards.Add('CARD_INSTATE_DL')
    if ($hasCtx) { $cards.Add('CONTEXT_INFO_CARD') }
    $cards.Add('CARD_OUTSTATE_NAME'); $cards.Add('CARD_OUTSTATE_DL')
    $lo | Add-Member -NotePropertyName 'ROOT_PAGE' -NotePropertyValue (Node-RootPage $cards.ToArray())

    # CONTEXT_INFO_CARD
    if ($hasCtx) {
        $lo | Add-Member -NotePropertyName 'CONTEXT_INFO_CARD' -NotePropertyValue ([PSCustomObject]@{
            type=[PSCustomObject]@{resolvedName='ContextInfoCard'}; displayName='ContextInfoCard'
            props=[PSCustomObject]@{}; isCanvas=$true; hidden=$false
            nodes=[string[]]@('ROW_0'); parent='ROOT_PAGE'; linkedNodes=[PSCustomObject]@{}
        })
        $lo | Add-Member -NotePropertyName 'ROW_0' -NotePropertyValue (Node-Row @('6','6') @('CadUnit_Input','CadEvent_Input') 'CONTEXT_INFO_CARD')
        $lo | Add-Member -NotePropertyName 'CadUnit_Input'  -NotePropertyValue (Node-Input 'CadUnit'  'CAD Unit'  $null 'ROW_0')
        $lo | Add-Member -NotePropertyName 'CadEvent_Input' -NotePropertyValue (Node-Input 'CadEvent' 'CAD Event' $null 'ROW_0')
        if ($hasLink) {
            $lo | Add-Member -NotePropertyName 'LinkToEvent_Input' -NotePropertyValue ([PSCustomObject]@{
                type=[PSCustomObject]@{resolvedName='FormCheckbox'}; displayName='Checkbox'
                props=[PSCustomObject]@{fieldId='LinkToEvent';label='Link to Event'}
                isCanvas=$false; hidden=$false; nodes=[string[]]@(); parent='ROOT_PAGE'; linkedNodes=[PSCustomObject]@{}
            })
        }
    }

    # CARD_INSTATE_NAME
    $lo | Add-Member -NotePropertyName 'CARD_INSTATE_NAME' -NotePropertyValue (Node-Card 'IN STATE by NAME' @('INSTATE_NAME_ROW1','INSTATE_NAME_ROW2','INSTATE_NAME_ROW3') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'INSTATE_NAME_ROW1' -NotePropertyValue (Node-Row @('3','3','3','3') @('NameFirst_In','NameLast_In','NameMiddle_In','NameSuffix_In') 'CARD_INSTATE_NAME')
    $lo | Add-Member -NotePropertyName 'NameFirst_In'  -NotePropertyValue (Node-Input  'NameFirst'  'First Name'  $null 'INSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'NameLast_In'   -NotePropertyValue (Node-Input  'NameLast'   'Last Name'   $null 'INSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'NameMiddle_In' -NotePropertyValue (Node-Input  'NameMiddle' 'Middle Name' $null 'INSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'NameSuffix_In' -NotePropertyValue (Node-Input  'NameSuffix' 'Suffix'      $null 'INSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'INSTATE_NAME_ROW2' -NotePropertyValue (Node-Row @('6','6') @('BirthDate_In','SexCode_In') 'CARD_INSTATE_NAME')
    $lo | Add-Member -NotePropertyName 'BirthDate_In'  -NotePropertyValue (Node-Date   'BirthDate' 'Date of Birth' 'INSTATE_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'SexCode_In'    -NotePropertyValue (Node-Select 'SexCode'   'Sex'  'SEX'   'INSTATE_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'INSTATE_NAME_ROW3' -NotePropertyValue (Node-Row @('6','6') @('Attention_In','PurposeCode_In') 'CARD_INSTATE_NAME')
    $lo | Add-Member -NotePropertyName 'Attention_In'    -NotePropertyValue (Node-Input 'AttentionName'   'Attention - Req for Driver History Only'    30 'INSTATE_NAME_ROW3')
    $lo | Add-Member -NotePropertyName 'PurposeCode_In'  -NotePropertyValue (Node-Input 'PurposeCodeName' 'Purpose Code - Req for Driver History Only' 1  'INSTATE_NAME_ROW3')

    # CARD_INSTATE_DL
    $lo | Add-Member -NotePropertyName 'CARD_INSTATE_DL'  -NotePropertyValue (Node-Card 'IN STATE by DRIVER LICENSE' @('INSTATE_DL_ROW1','INSTATE_DL_ROW2') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'INSTATE_DL_ROW1'  -NotePropertyValue (Node-Row @('12') @('OLN_In') 'CARD_INSTATE_DL')
    $lo | Add-Member -NotePropertyName 'OLN_In'            -NotePropertyValue (Node-Input 'OperatorLicenseNumber' 'Operator License #' 20 'INSTATE_DL_ROW1')
    $lo | Add-Member -NotePropertyName 'INSTATE_DL_ROW2'  -NotePropertyValue (Node-Row @('6','6') @('Attention_DL_In','PurposeCode_DL_In') 'CARD_INSTATE_DL')
    $lo | Add-Member -NotePropertyName 'Attention_DL_In'   -NotePropertyValue (Node-Input 'AttentionDL'   'Attention - Req for Driver History Only'    30 'INSTATE_DL_ROW2')
    $lo | Add-Member -NotePropertyName 'PurposeCode_DL_In' -NotePropertyValue (Node-Input 'PurposeCodeDL' 'Purpose Code - Req for Driver History Only' 1  'INSTATE_DL_ROW2')

    # CARD_OUTSTATE_NAME
    $lo | Add-Member -NotePropertyName 'CARD_OUTSTATE_NAME' -NotePropertyValue (Node-Card 'OUT OF STATE by NAME' @('OUTSTATE_NAME_ROW1','OUTSTATE_NAME_ROW2','OUTSTATE_NAME_ROW3') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'OUTSTATE_NAME_ROW1' -NotePropertyValue (Node-Row @('3','3','3','3') @('NameFirst_OOS','NameLast_OOS','NameMiddle_OOS','NameSuffix_OOS') 'CARD_OUTSTATE_NAME')
    $lo | Add-Member -NotePropertyName 'NameFirst_OOS'  -NotePropertyValue (Node-Input  'NameFirstOOS'  'First Name'  $null 'OUTSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'NameLast_OOS'   -NotePropertyValue (Node-Input  'NameLastOOS'   'Last Name'   $null 'OUTSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'NameMiddle_OOS' -NotePropertyValue (Node-Input  'NameMiddleOOS' 'Middle Name' $null 'OUTSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'NameSuffix_OOS' -NotePropertyValue (Node-Input  'NameSuffixOOS' 'Suffix'      $null 'OUTSTATE_NAME_ROW1')
    $lo | Add-Member -NotePropertyName 'OUTSTATE_NAME_ROW2' -NotePropertyValue (Node-Row @('6','6') @('BirthDate_OOS','SexCode_OOS') 'CARD_OUTSTATE_NAME')
    $lo | Add-Member -NotePropertyName 'BirthDate_OOS'  -NotePropertyValue (Node-Date   'BirthDateOOS' 'Date of Birth' 'OUTSTATE_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'SexCode_OOS'    -NotePropertyValue (Node-Select 'SexCodeOOS'   'Sex'  'SEX'    'OUTSTATE_NAME_ROW2')
    $lo | Add-Member -NotePropertyName 'OUTSTATE_NAME_ROW3' -NotePropertyValue (Node-Row @('12') @('RegState_OOS') 'CARD_OUTSTATE_NAME')
    $lo | Add-Member -NotePropertyName 'RegState_OOS'   -NotePropertyValue (Node-Select 'RegistrationStateOOS' 'State' 'STATE' 'OUTSTATE_NAME_ROW3')

    # CARD_OUTSTATE_DL
    $lo | Add-Member -NotePropertyName 'CARD_OUTSTATE_DL'  -NotePropertyValue (Node-Card 'OUT OF STATE by DRIVER LICENSE' @('OUTSTATE_DL_ROW1','OUTSTATE_DL_ROW2') 'ROOT_PAGE')
    $lo | Add-Member -NotePropertyName 'OUTSTATE_DL_ROW1'  -NotePropertyValue (Node-Row @('3','3','3','3') @('OLN_OOS','RegState_DL_OOS','Attention_OOS','PurposeCode_OOS') 'CARD_OUTSTATE_DL')
    $lo | Add-Member -NotePropertyName 'OLN_OOS'           -NotePropertyValue (Node-Input  'OperatorLicenseNumberOOS' 'Operator License #'                          20 'OUTSTATE_DL_ROW1')
    $lo | Add-Member -NotePropertyName 'RegState_DL_OOS'   -NotePropertyValue (Node-Select 'RegistrationState'        'State'                              'STATE'     'OUTSTATE_DL_ROW1')
    $lo | Add-Member -NotePropertyName 'Attention_OOS'     -NotePropertyValue (Node-Input  'AttentionOOS'   'Attention - Req for Driver History Only'     30          'OUTSTATE_DL_ROW1')
    $lo | Add-Member -NotePropertyName 'PurposeCode_OOS'   -NotePropertyValue (Node-Input  'PurposeCodeOOS' 'Purpose Code - Req for Driver History Only'  1           'OUTSTATE_DL_ROW1')
    $lo | Add-Member -NotePropertyName 'OUTSTATE_DL_ROW2'  -NotePropertyValue (Node-Row @('6','6') @('Attention_DL_OOS','PurposeCode_DL_OOS') 'CARD_OUTSTATE_DL')
    $lo | Add-Member -NotePropertyName 'Attention_DL_OOS'   -NotePropertyValue (Node-Input 'Attention'   'Attention - Req for Driver History Only'     30 'OUTSTATE_DL_ROW2')
    $lo | Add-Member -NotePropertyName 'PurposeCode_DL_OOS' -NotePropertyValue (Node-Input 'PurposeCode' 'Purpose Code - Req for Driver History Only'  1  'OUTSTATE_DL_ROW2')

    return $lo
}

$personLayout = [PSCustomObject]@{}
$personLayout | Add-Member -NotePropertyName 'default'         -NotePropertyValue (Build-PersonLayout $false $null)
$personLayout | Add-Member -NotePropertyName 'CAD_DISPATCH'    -NotePropertyValue (Build-PersonLayout $true  $false)
$personLayout | Add-Member -NotePropertyName 'FIRST_RESPONDER' -NotePropertyValue (Build-PersonLayout $true  $true)

$entityPerson = [PSCustomObject]@{
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    description  = 'Input query layout for person entity'
    label        = 'Person'
    targetEntity = 'Person'
    layout       = $personLayout
}

# ─────────────────────────────────────────────────────────────────────────────
# Rebuild ENTITIES bundle: drop all 4 split entities, add ENTITY_Person back
# ─────────────────────────────────────────────────────────────────────────────
$removeEntities = @('ENTITY_FL_DL','ENTITY_OOS_DL','ENTITY_FL_DH','ENTITY_OOS_DH','ENTITY_PersonInState','ENTITY_PersonOOS')
$newCfgs = [System.Collections.Generic.List[object]]::new()
$newCfgs.Add($entityPerson)
$eb.configurations | Where-Object { $_.name -notin $removeEntities } | ForEach-Object { $newCfgs.Add($_) }
$eb.configurations = $newCfgs.ToArray()

# ─────────────────────────────────────────────────────────────────────────────
# Merge InState DL combos + attrs back into DL OOS query, restore to Person
# ─────────────────────────────────────────────────────────────────────────────
$dlO.targetEntity      = 'Person'
$dlO.combinations      = @($dlI.combinations) + @($dlO.combinations)
$existingAttrNames     = $dlO.attributes | ForEach-Object { $_.name }
$dlI.attributes | Where-Object { $_.name -notin $existingAttrNames } | ForEach-Object {
    $dlO.attributes = @($dlO.attributes) + @($_)
}
$dlO.queriesToDeselect = [string[]]@('DriverHistoryQuery')

# ─────────────────────────────────────────────────────────────────────────────
# Merge InState DH combos + attrs back into DH OOS query, restore to Person
# ─────────────────────────────────────────────────────────────────────────────
$dhO.targetEntity      = 'Person'
$dhO.autoSelect        = $false
$dhO.combinations      = @($dhI.combinations) + @($dhO.combinations)
$existingAttrNames     = $dhO.attributes | ForEach-Object { $_.name }
$dhI.attributes | Where-Object { $_.name -notin $existingAttrNames } | ForEach-Object {
    $dhO.attributes = @($dhO.attributes) + @($_)
}
$dhO.queriesToDeselect = [string[]]@('DriverLicenseQuery')

# ─────────────────────────────────────────────────────────────────────────────
# Remove InState DL and DH mappings from FL_FCIC bundle
# ─────────────────────────────────────────────────────────────────────────────
$fcicCfgs = [System.Collections.Generic.List[object]]::new()
$fb.configurations | Where-Object { $_.name -notin @('FL_FCIC_DriverLicenseInState','FL_FCIC_DriverHistoryInState') } | ForEach-Object { $fcicCfgs.Add($_) }
$fb.configurations = $fcicCfgs.ToArray()

# ─────────────────────────────────────────────────────────────────────────────
# Restore entity order
# ─────────────────────────────────────────────────────────────────────────────
$driverEntities  = @('FL Driver License','OOS Driver License','FL Driver History','OOS Driver History','Person (In State)','Person (Out of State)')
$orders = @{
    'default'         = @('Person','Vehicle','Firearm','Article','Boat')
    'CAD_DISPATCH'    = @('Vehicle','Person','Firearm','Article','Boat')
    'FIRST_RESPONDER' = @('Vehicle','Person','Firearm','Article','Boat')
}
foreach ($v in $orders.Keys) {
    $eb.order.PSObject.Properties[$v].Value = [string[]]$orders[$v]
}

# ─────────────────────────────────────────────────────────────────────────────
# Save
# ─────────────────────────────────────────────────────────────────────────────
$out = $data | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($path, $out, [System.Text.Encoding]::UTF8)
Write-Host 'Saved.'

# Verify
$v2  = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
$eb2 = $v2.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb2 = $v2.bundles | Where-Object { $_.name -eq 'FL_FCIC' }
Write-Host 'ENTITIES:' ($eb2.configurations.name -join ', ')
Write-Host 'FL_FCIC configs:' $fb2.configurations.Count
Write-Host 'Order default:' ($eb2.order.default -join ', ')
Write-Host 'DL combos:' (($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }).combinations.keyReference -join ', ')
Write-Host 'DH combos:' (($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }).combinations.keyReference -join ', ')
Write-Host 'Person nodes (default):' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_Person' }).layout.default.ROOT_PAGE.nodes -join ', '
