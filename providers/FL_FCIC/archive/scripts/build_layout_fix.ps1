<#
  build_layout_fix.ps1
  Replaces Person QIF layouts in FL_FCIC_v2.1_CLEAN.json with clean BASE-quality Craft.js nodes.
  Output: FL_FCIC_v2.1_layout_test.json
#>

$srcPath = Join-Path $PSScriptRoot "FL_FCIC_v2.1_CLEAN.json"
$outPath = Join-Path $PSScriptRoot "FL_FCIC_v2.1_layout_test.json"

$raw = [System.IO.File]::ReadAllText($srcPath, [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json

# --- Helper functions ---
function New-Node($type, $displayName, $props, $isCanvas, $hidden, $nodes, $parent) {
    $n = [ordered]@{
        type = [ordered]@{ resolvedName = $type }
        displayName = $displayName
        props = $props
        isCanvas = $isCanvas
        hidden = $hidden
        nodes = $nodes
        linkedNodes = [ordered]@{}
    }
    if ($null -ne $parent) { $n.parent = $parent }
    return $n
}

function New-Row($name, $cols, $children, $parent) {
    return @($name, (New-Node "Row" "Row" ([ordered]@{ templateColumns = $cols }) $true $false $children $parent))
}

function New-Input($name, $fieldId, $label, $maxLen, $parent) {
    $p = [ordered]@{ fieldId = $fieldId; label = $label }
    if ($maxLen) { $p.maxLength = $maxLen }
    return @($name, (New-Node "FormInput" "Input" $p $false $false @() $parent))
}

function New-Select($name, $fieldId, $label, $extraProps, $parent) {
    $p = [ordered]@{ fieldId = $fieldId; label = $label }
    foreach ($k in $extraProps.Keys) { $p[$k] = $extraProps[$k] }
    return @($name, (New-Node "FormSelect" "Select" $p $false $false @() $parent))
}

function New-Date($name, $fieldId, $label, $parent) {
    $p = [ordered]@{ fieldId = $fieldId; label = $label }
    return @($name, (New-Node "FormDate" "Date" $p $false $false @() $parent))
}

function New-Card($name, $title, $rowNames, $parent) {
    $p = [ordered]@{}
    if ($title) { $p.title = $title }
    return @($name, (New-Node "Card" "Card" $p $true $false $rowNames $parent))
}

# --- Build a complete Person layout (2-card BASE pattern) ---
function Build-PersonLayout($includeCAD) {
    $layout = [ordered]@{}

    # Structural nodes
    $layout.ROOT = (New-Node "Root" "Root" ([ordered]@{}) $false $false @("FORM_ROOT") $null)

    $layout.FORM_ROOT = (New-Node "Form" "Form" ([ordered]@{
        hidePageItems = $true
        layout = "page"
    }) $true $false @("ROOT_PAGE") "ROOT")

    $pageCards = @()
    if ($includeCAD) { $pageCards += "CONTEXT_INFO_CARD" }
    $pageCards += @("CARD_DL","CARD_DH")

    $layout.ROOT_PAGE = (New-Node "Page" "Page" ([ordered]@{ title = "Page 1" }) $true $false $pageCards "FORM_ROOT")

    # --- CAD card (only for CAD_DISPATCH / FIRST_RESPONDER) ---
    if ($includeCAD) {
        $r = New-Card "CONTEXT_INFO_CARD" $null @("CONTEXT_ROW1") "ROOT_PAGE"; $layout[$r[0]] = $r[1]
        $r = New-Row "CONTEXT_ROW1" @("6","6") @("CadUnit_Input","CadEvent_Input") "CONTEXT_INFO_CARD"; $layout[$r[0]] = $r[1]
        $r = New-Select "CadUnit_Input" "CAD_UNIT_SELECT_VALUE" "Requesting Unit" ([ordered]@{ attributeTypeId = "CAD_UNIT_SELECT_VALUE" }) "CONTEXT_ROW1"; $layout[$r[0]] = $r[1]
        $r = New-Select "CadEvent_Input" "CAD_EVENT_SELECT_VALUE" "Event" ([ordered]@{ attributeTypeId = "CAD_EVENT_SELECT_VALUE"; performSearchAhead = $true }) "CONTEXT_ROW1"; $layout[$r[0]] = $r[1]
    }

    # --- CARD 1: Driver License (mirrors BASE ROOT_CARD pattern) ---
    $r = New-Card "CARD_DL" $null @("ROW_1","ROW_2","ROW_3","ROW_4") "ROOT_PAGE"; $layout[$r[0]] = $r[1]

    # ROW_1: OLN + State (BASE pattern)
    $r = New-Row "ROW_1" @("6","6") @("OperatorLicenseNumber_Input","RegistrationState_Input") "CARD_DL"; $layout[$r[0]] = $r[1]
    $r = New-Input "OperatorLicenseNumber_Input" "OperatorLicenseNumber" "OLN" "20" "ROW_1"; $layout[$r[0]] = $r[1]
    $r = New-Select "RegistrationState_Input" "RegistrationState" "State" ([ordered]@{ attributeTypeId = "STATE" }) "ROW_1"; $layout[$r[0]] = $r[1]

    # ROW_2: First + Last (BASE pattern)
    $r = New-Row "ROW_2" @("6","6") @("NameFirst_Input","NameLast_Input") "CARD_DL"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameFirst_Input" "NameFirst" "First Name" $null "ROW_2"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameLast_Input" "NameLast" "Last Name" $null "ROW_2"; $layout[$r[0]] = $r[1]

    # ROW_3: Middle + Suffix + DOB + Sex (BASE pattern)
    $r = New-Row "ROW_3" @("3","3","3","3") @("NameMiddle_Input","NameSuffix_Input","BirthDate_Input","SexCode_Input") "CARD_DL"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameMiddle_Input" "NameMiddle" "M.I." $null "ROW_3"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameSuffix_Input" "NameSuffix" "Suffix" $null "ROW_3"; $layout[$r[0]] = $r[1]
    $r = New-Date "BirthDate_Input" "BirthDate" "Date of Birth" "ROW_3"; $layout[$r[0]] = $r[1]
    $r = New-Select "SexCode_Input" "SexCode" "Sex" ([ordered]@{ attributeTypeId = "SEX"; codeTypeProvider = "NIBRS" }) "ROW_3"; $layout[$r[0]] = $r[1]

    # ROW_4: ImageIndicator (FL-specific, not in BASE)
    $r = New-Row "ROW_4" @("6","6") @("ImageIndicator_Input") "CARD_DL"; $layout[$r[0]] = $r[1]
    $r = New-Select "ImageIndicator_Input" "ImageIndicator" "Image Indicator" ([ordered]@{
        initialValue = "Y"
        codeTypeSource = "NIBRS"
        codeTypeCategory = "YES_NO_UNKNOWN"
    }) "ROW_4"; $layout[$r[0]] = $r[1]

    # --- CARD 2: Driver History (same BASE row pattern, DH-suffix fields) ---
    $r = New-Card "CARD_DH" $null @("ROW_5","ROW_6","ROW_7","ROW_8") "ROOT_PAGE"; $layout[$r[0]] = $r[1]

    # ROW_5: DH OLN
    $r = New-Row "ROW_5" @("12") @("OperatorLicenseNumberDH_Input") "CARD_DH"; $layout[$r[0]] = $r[1]
    $r = New-Input "OperatorLicenseNumberDH_Input" "OperatorLicenseNumberDH" "OLN" "20" "ROW_5"; $layout[$r[0]] = $r[1]

    # ROW_6: DH First + Last
    $r = New-Row "ROW_6" @("6","6") @("NameFirstDH_Input","NameLastDH_Input") "CARD_DH"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameFirstDH_Input" "NameFirstDH" "First Name" $null "ROW_6"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameLastDH_Input" "NameLastDH" "Last Name" $null "ROW_6"; $layout[$r[0]] = $r[1]

    # ROW_7: DH Middle + Suffix + DOB + Sex
    $r = New-Row "ROW_7" @("3","3","3","3") @("NameMiddleDH_Input","NameSuffixDH_Input","BirthDateDH_Input","SexCodeDH_Input") "CARD_DH"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameMiddleDH_Input" "NameMiddleDH" "M.I." $null "ROW_7"; $layout[$r[0]] = $r[1]
    $r = New-Input "NameSuffixDH_Input" "NameSuffixDH" "Suffix" $null "ROW_7"; $layout[$r[0]] = $r[1]
    $r = New-Date "BirthDateDH_Input" "BirthDateDH" "Date of Birth" "ROW_7"; $layout[$r[0]] = $r[1]
    $r = New-Select "SexCodeDH_Input" "SexCodeDH" "Sex" ([ordered]@{ attributeTypeId = "SEX"; codeTypeProvider = "NIBRS" }) "ROW_7"; $layout[$r[0]] = $r[1]

    # ROW_8: PurposeCode + Attention (BASE ROW_4 pattern)
    $r = New-Row "ROW_8" @("6","6") @("PurposeCode_Input","Attention_Input") "CARD_DH"; $layout[$r[0]] = $r[1]
    $r = New-Input "PurposeCode_Input" "PurposeCode" "Purpose Code" "1" "ROW_8"; $layout[$r[0]] = $r[1]
    $r = New-Input "Attention_Input" "Attention" "Attention" "30" "ROW_8"; $layout[$r[0]] = $r[1]

    return $layout
}

# --- Build all three layouts ---
$defaultLayout = Build-PersonLayout -includeCAD $false
$cadLayout = Build-PersonLayout -includeCAD $true
$frLayout = Build-PersonLayout -includeCAD $true

$newFormLayouts = [ordered]@{
    default = $defaultLayout
    CAD_DISPATCH = $cadLayout
    FIRST_RESPONDER = $frLayout
}

# --- Find and replace Person QIF layout ---
$entities = $json.bundles | Where-Object { $_.name -eq "ENTITIES" }
$personConfig = $entities.configurations | Where-Object { $_.name -eq "ENTITY_Person" }

# Replace the layout property
$personConfig.layout = $null
$personConfig | Add-Member -MemberType NoteProperty -Name "layout" -Value $newFormLayouts -Force

# --- Serialize ---
$outJson = $json | ConvertTo-Json -Depth 30 -Compress:$false

# Fix PowerShell 5.1 quirks: empty arrays serialized as empty value
$outJson = $outJson -replace '"nodes":\s*""', '"nodes": []'

# Write without BOM
[System.IO.File]::WriteAllText($outPath, $outJson, [System.Text.UTF8Encoding]::new($false))

Write-Host "Written to: $outPath"
Write-Host "Person QIF default: $($defaultLayout.Keys.Count) nodes"
Write-Host "Person QIF CAD_DISPATCH: $($cadLayout.Keys.Count) nodes"
