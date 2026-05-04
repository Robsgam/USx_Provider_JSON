$path = 'D:\JSON BACKUP\FL_FCIC.json'
$json = Get-Content $path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$eb   = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$fb   = $data.bundles | Where-Object { $_.name -eq 'FL_FCIC' }

$person = $eb.configurations | Where-Object { $_.name -eq 'ENTITY_Person' }
$dlQ    = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }
$dhQ    = $fb.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }

# ─── Helper: deep-clone a single node ────────────────────────────────────────
function Clone-Node($src) {
    return $src | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

# ─── Helper: build skeleton layout from an existing layout variant ─────────
function Clone-Skeleton($src) {
    $skel = [PSCustomObject]@{}
    foreach ($key in @('ROOT','FORM_ROOT','ROOT_PAGE')) {
        $skel | Add-Member -NotePropertyName $key -NotePropertyValue (Clone-Node $src.$key)
    }
    return $skel
}

# ─── Helper: copy named nodes from src layout to dst layout ──────────────────
function Copy-Nodes($src, $dst, [string[]]$nodeIds) {
    foreach ($id in $nodeIds) {
        if ($src.PSObject.Properties[$id]) {
            $dst | Add-Member -NotePropertyName $id -NotePropertyValue (Clone-Node $src.$id) -Force
        }
    }
}

# ─── Helper: remove named nodes from a layout ────────────────────────────────
function Remove-Nodes($layout, [string[]]$removeIds) {
    foreach ($id in $removeIds) {
        if ($layout.PSObject.Properties[$id]) {
            $layout.PSObject.Properties.Remove($id)
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Node ID groups
# ─────────────────────────────────────────────────────────────────────────────
$instateNodes = @(
    'CARD_INSTATE_NAME','INSTATE_NAME_ROW1','NameFirst_In','NameLast_In',
    'NameMiddle_In','NameSuffix_In','INSTATE_NAME_ROW2','BirthDate_In','SexCode_In',
    'INSTATE_NAME_ROW3','Attention_In','PurposeCode_In',
    'CARD_INSTATE_DL','INSTATE_DL_ROW1','OLN_In','INSTATE_DL_ROW2',
    'Attention_DL_In','PurposeCode_DL_In'
)
$contextNodes = @('CONTEXT_INFO_CARD','ROW_0','CadUnit_Input','CadEvent_Input')
$frExtraNodes = @('LinkToEvent_Input')

# ─────────────────────────────────────────────────────────────────────────────
# Build ENTITY_PersonInState layout
# ─────────────────────────────────────────────────────────────────────────────
$piLayout = [PSCustomObject]@{}

# default
$defPI = Clone-Skeleton $person.layout.default
Copy-Nodes $person.layout.default $defPI $instateNodes
$defPI.ROOT_PAGE.nodes = [string[]]@('CARD_INSTATE_NAME','CARD_INSTATE_DL')
$piLayout | Add-Member -NotePropertyName 'default' -NotePropertyValue $defPI

# CAD_DISPATCH
$cadPI = Clone-Skeleton $person.layout.CAD_DISPATCH
Copy-Nodes $person.layout.CAD_DISPATCH $cadPI $instateNodes
Copy-Nodes $person.layout.CAD_DISPATCH $cadPI $contextNodes
$cadPI.ROOT_PAGE.nodes = [string[]]@('CONTEXT_INFO_CARD','CARD_INSTATE_NAME','CARD_INSTATE_DL')
$piLayout | Add-Member -NotePropertyName 'CAD_DISPATCH' -NotePropertyValue $cadPI

# FIRST_RESPONDER
$frPI = Clone-Skeleton $person.layout.FIRST_RESPONDER
Copy-Nodes $person.layout.FIRST_RESPONDER $frPI $instateNodes
Copy-Nodes $person.layout.FIRST_RESPONDER $frPI $contextNodes
Copy-Nodes $person.layout.FIRST_RESPONDER $frPI $frExtraNodes
$frPI.ROOT_PAGE.nodes = [string[]]@('CONTEXT_INFO_CARD','CARD_INSTATE_NAME','CARD_INSTATE_DL')
$piLayout | Add-Member -NotePropertyName 'FIRST_RESPONDER' -NotePropertyValue $frPI

$entityPersonInState = [PSCustomObject]@{
    name         = 'ENTITY_PersonInState'
    type         = 'QUERYINPUTFORM'
    description  = 'Input query layout for in-state person entity'
    label        = 'Person (In State)'
    targetEntity = 'Person (In State)'
    layout       = $piLayout
}

# ─────────────────────────────────────────────────────────────────────────────
# Modify ENTITY_Person → ENTITY_PersonOOS (strip InState nodes)
# ─────────────────────────────────────────────────────────────────────────────
foreach ($v in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $lo = $person.layout.PSObject.Properties[$v].Value
    Remove-Nodes $lo $instateNodes
    $newNodes = [System.Collections.Generic.List[string]]::new()
    if ($lo.PSObject.Properties['CONTEXT_INFO_CARD']) { $newNodes.Add('CONTEXT_INFO_CARD') }
    $newNodes.Add('CARD_OUTSTATE_NAME')
    $newNodes.Add('CARD_OUTSTATE_DL')
    $lo.ROOT_PAGE.nodes = $newNodes.ToArray()
}
$person.name         = 'ENTITY_PersonOOS'
$person.label        = 'Person (Out of State)'
$person.targetEntity = 'Person (Out of State)'
$person.description  = 'Input query layout for out-of-state person entity'

# Insert ENTITY_PersonInState before ENTITY_PersonOOS in ENTITIES bundle
$cfgList = [System.Collections.Generic.List[object]]::new()
$eb.configurations | ForEach-Object {
    if ($_.name -eq 'ENTITY_PersonOOS') { $cfgList.Add($entityPersonInState) }
    $cfgList.Add($_)
}
$eb.configurations = $cfgList.ToArray()

# ─────────────────────────────────────────────────────────────────────────────
# Split FL_FCIC_DriverLicenseQuery
# InState: FDQName, FDQOperatorLicenseNumber, QWName, QWOperatorLicenseNumber
# OOS:     DQName, DQOperatorLicenseNumber
# ─────────────────────────────────────────────────────────────────────────────
$dlInstateKeys = @('FDQName','FDQOperatorLicenseNumber','QWName','QWOperatorLicenseNumber')
$dlInStateCombos = @($dlQ.combinations | Where-Object { $_.keyReference -in $dlInstateKeys })
$dlOOSCombos     = @($dlQ.combinations | Where-Object { $_.keyReference -notin $dlInstateKeys })

# Attribute names that are InState-only (no OOS suffix)
$dlInstateOnlyAttrNames = @('BirthDate','Name','OperatorLicenseNumber','SexCode')
$dlInStateAttrs = @($dlQ.attributes | Where-Object { $_.name -notin @('NameOOS','BirthDateOOS','SexCodeOOS','RegistrationStateOOS','OperatorLicenseNumberOOS','AttentionOOS','PurposeCodeOOS','OperatorLicenseStateCode','Attention','PurposeCode') })
$dlOOSAttrs     = @($dlQ.attributes | Where-Object { $_.name -notin $dlInstateOnlyAttrNames })

$dlInStateMapping = [PSCustomObject]@{
    name              = 'FL_FCIC_DriverLicenseInState'
    type              = 'QUERYINPUTDATAMAPPING'
    description       = 'Configuration for FL FCIC In-State Driver License Query'
    handlerFunction   = 'CommsysTransactionRequestHandler'
    autoSelect        = $true
    provider          = 'FL_FCIC'
    providerType      = 'Commsys'
    query             = 'DriverLicenseQuery'
    queriesToDeselect = [string[]]@('DriverHistoryQuery')
    targetEntity      = 'Person (In State)'
    attributes        = $dlInStateAttrs
    combinations      = $dlInStateCombos
    queryLabel        = 'Driver License'
}

$dlQ.targetEntity      = 'Person (Out of State)'
$dlQ.queriesToDeselect = [string[]]@()
$dlQ.combinations      = $dlOOSCombos
$dlQ.attributes        = $dlOOSAttrs

# ─────────────────────────────────────────────────────────────────────────────
# Split FL_FCIC_DriverHistoryQuery
# InState: KQName, KQOperatorLicenseNumber
# OOS:     KQOperatorLicenseNumberOOS, KQNameOOS
# ─────────────────────────────────────────────────────────────────────────────
$dhInstateKeys   = @('KQName','KQOperatorLicenseNumber')
$dhInStateCombos = @($dhQ.combinations | Where-Object { $_.keyReference -in $dhInstateKeys })
$dhOOSCombos     = @($dhQ.combinations | Where-Object { $_.keyReference -notin $dhInstateKeys })

$dhInstateOnlyAttrNames = @('BirthDate','Name','OperatorLicenseNumber','SexCode','AttentionName','AttentionDL','PurposeCodeName','PurposeCodeDL')
$dhInStateAttrs = @($dhQ.attributes | Where-Object { $_.name -notin @('OperatorLicenseNumberOOS','NameOOS','BirthDateOOS','SexCodeOOS','RegistrationStateOOS','AttentionOOS','PurposeCodeOOS') })
$dhOOSAttrs     = @($dhQ.attributes | Where-Object { $_.name -notin $dhInstateOnlyAttrNames })

$dhInStateMapping = [PSCustomObject]@{
    name              = 'FL_FCIC_DriverHistoryInState'
    type              = 'QUERYINPUTDATAMAPPING'
    description       = 'Configuration for FL FCIC In-State Driver History Query'
    handlerFunction   = 'CommsysTransactionRequestHandler'
    autoSelect        = $false
    provider          = 'FL_FCIC'
    providerType      = 'Commsys'
    query             = 'DriverHistoryQuery'
    queriesToDeselect = [string[]]@('DriverLicenseQuery')
    targetEntity      = 'Person (In State)'
    attributes        = $dhInStateAttrs
    combinations      = $dhInStateCombos
    queryLabel        = 'Driver History'
}

$dhQ.targetEntity      = 'Person (Out of State)'
$dhQ.autoSelect        = $false
$dhQ.queriesToDeselect = [string[]]@()
$dhQ.combinations      = $dhOOSCombos
$dhQ.attributes        = $dhOOSAttrs

# Insert InState mappings before their OOS counterparts in FL_FCIC bundle
$fcicCfgs = [System.Collections.Generic.List[object]]::new()
$fb.configurations | ForEach-Object {
    if ($_.name -eq 'FL_FCIC_DriverLicenseQuery') { $fcicCfgs.Add($dlInStateMapping) }
    if ($_.name -eq 'FL_FCIC_DriverHistoryQuery')  { $fcicCfgs.Add($dhInStateMapping) }
    $fcicCfgs.Add($_)
}
$fb.configurations = $fcicCfgs.ToArray()

# ─────────────────────────────────────────────────────────────────────────────
# Update entity order: Person → Person (In State), Person (Out of State)
# ─────────────────────────────────────────────────────────────────────────────
foreach ($v in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $cur = [System.Collections.Generic.List[string]]::new()
    $eb.order.PSObject.Properties[$v].Value | ForEach-Object {
        if ($_ -eq 'Person') {
            $cur.Add('Person (In State)')
            $cur.Add('Person (Out of State)')
        } else {
            $cur.Add($_)
        }
    }
    $eb.order.PSObject.Properties[$v].Value = $cur.ToArray()
}

# ─────────────────────────────────────────────────────────────────────────────
# Save
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
Write-Host 'FL_FCIC config count:' $fb2.configurations.Count
Write-Host 'Order default:' ($eb2.order.default -join ', ')
Write-Host 'Order CAD_DISPATCH:' ($eb2.order.CAD_DISPATCH -join ', ')
Write-Host ''
Write-Host 'PersonInState default nodes:' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_PersonInState' }).layout.default.ROOT_PAGE.nodes -join ', '
Write-Host 'PersonOOS default nodes:' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_PersonOOS' }).layout.default.ROOT_PAGE.nodes -join ', '
Write-Host 'PersonInState CAD nodes:' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_PersonInState' }).layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', '
Write-Host 'PersonOOS CAD nodes:' ($eb2.configurations | Where-Object { $_.name -eq 'ENTITY_PersonOOS' }).layout.CAD_DISPATCH.ROOT_PAGE.nodes -join ', '
Write-Host ''
Write-Host 'DL InState targetEntity:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseInState' }).targetEntity
Write-Host 'DL OOS targetEntity:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }).targetEntity
Write-Host 'DH InState targetEntity:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryInState' }).targetEntity
Write-Host 'DH OOS targetEntity:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }).targetEntity
Write-Host 'DL InState combos:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseInState' }).combinations.keyReference -join ', '
Write-Host 'DL OOS combos:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverLicenseQuery' }).combinations.keyReference -join ', '
Write-Host 'DH InState combos:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryInState' }).combinations.keyReference -join ', '
Write-Host 'DH OOS combos:' ($fb2.configurations | Where-Object { $_.name -eq 'FL_FCIC_DriverHistoryQuery' }).combinations.keyReference -join ', '
