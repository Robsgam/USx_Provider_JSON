<#
  build_v2.1_test.ps1 — Text-based builder (no ConvertTo-Json roundtrip)
  Reads FL_FCIC_v2.1_CLEAN.json, replaces Person QIF layout with 2-card BASE pattern,
  adds NCICNumber + ProcessControlNumber to Firearm QIF, outputs FL_FCIC_v2.1_layout_test.json
#>

$srcPath  = Join-Path $PSScriptRoot "FL_FCIC_v2.1_CLEAN.json"
$outPath  = Join-Path $PSScriptRoot "FL_FCIC_v2.1_layout_test.json"

$raw = [System.IO.File]::ReadAllText($srcPath, [System.Text.UTF8Encoding]::new($false))

# ── HELPER: build a Craft.js node as compact JSON text ──
function N($indent, $props) {
    $lines = @()
    $pad = " " * $indent
    foreach ($kv in $props) {
        $k = $kv[0]; $v = $kv[1]
        if ($v -is [bool])   { $lines += "$pad`"$k`": $(if($v){'true'}else{'false'})" }
        elseif ($v -is [array] -and $v.Count -eq 0) { $lines += "$pad`"$k`": []" }
        elseif ($v -is [array]) {
            $items = ($v | ForEach-Object { "`"$_`"" }) -join ", "
            $lines += "$pad`"$k`": [$items]"
        }
        elseif ($v -eq '{}') { $lines += "$pad`"$k`": {}" }
        elseif ($v -eq 'null') { $lines += "$pad`"$k`": null" }
        elseif ($v.StartsWith('{')) { $lines += "$pad`"$k`": $v" }
        else { $lines += "$pad`"$k`": `"$v`"" }
    }
    return ($lines -join ",`n")
}

function MakeNode($indent, $type, $display, $propsJson, $isCanvas, $hidden, $nodes, $parent) {
    $pad = " " * $indent
    $parts = @()
    $parts += "$pad`"type`": { `"resolvedName`": `"$type`" }"
    $parts += "$pad`"displayName`": `"$display`""
    $parts += "$pad`"props`": $propsJson"
    $parts += "$pad`"isCanvas`": $(if($isCanvas){'true'}else{'false'})"
    $parts += "$pad`"hidden`": $(if($hidden){'true'}else{'false'})"
    if ($nodes.Count -eq 0) {
        $parts += "$pad`"nodes`": []"
    } else {
        $items = ($nodes | ForEach-Object { "`"$_`"" }) -join ", "
        $parts += "$pad`"nodes`": [$items]"
    }
    $parts += "$pad`"linkedNodes`": {}"
    if ($parent -eq 'null') { $parts += "$pad`"parent`": null" }
    elseif ($parent) { $parts += "$pad`"parent`": `"$parent`"" }
    return ($parts -join ",`n")
}

function BuildPersonLayout($includeCAD) {
    $i = 6  # base indent for node properties
    $nodes = [ordered]@{}

    # Structural
    $nodes["ROOT"] = MakeNode $i "Root" "Root" "{}" $false $false @("FORM_ROOT") "null"
    $nodes["FORM_ROOT"] = MakeNode $i "Form" "Form" '{ "hidePageItems": true, "layout": "page" }' $true $false @("ROOT_PAGE") "ROOT"

    $cards = @()
    if ($includeCAD) { $cards += "CONTEXT_INFO_CARD" }
    $cards += @("CARD_DL", "CARD_DH")
    $nodes["ROOT_PAGE"] = MakeNode $i "Page" "Page" '{ "title": "Page 1" }' $true $false $cards "FORM_ROOT"

    # CAD card
    if ($includeCAD) {
        $nodes["CONTEXT_INFO_CARD"] = MakeNode $i "Card" "Card" "{}" $true $false @("CONTEXT_ROW1") "ROOT_PAGE"
        $nodes["CONTEXT_ROW1"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("CadUnit_Input", "CadEvent_Input") "CONTEXT_INFO_CARD"
        $nodes["CadUnit_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "CAD_UNIT_SELECT_VALUE", "label": "Requesting Unit", "attributeTypeId": "CAD_UNIT_SELECT_VALUE" }' $false $false @() "CONTEXT_ROW1"
        $nodes["CadEvent_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "CAD_EVENT_SELECT_VALUE", "label": "Event", "attributeTypeId": "CAD_EVENT_SELECT_VALUE", "performSearchAhead": true }' $false $false @() "CONTEXT_ROW1"
    }

    # CARD_DL — Driver License (BASE pattern: OLN+State / First+Last / Mid+Suf+DOB+Sex / Image)
    $nodes["CARD_DL"] = MakeNode $i "Card" "Card" "{}" $true $false @("ROW_1","ROW_2","ROW_3","ROW_4") "ROOT_PAGE"
    $nodes["ROW_1"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("OperatorLicenseNumber_Input","RegistrationState_Input") "CARD_DL"
    $nodes["OperatorLicenseNumber_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "OperatorLicenseNumber", "label": "OLN", "maxLength": "20" }' $false $false @() "ROW_1"
    $nodes["RegistrationState_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "RegistrationState", "label": "State", "attributeTypeId": "STATE" }' $false $false @() "ROW_1"
    $nodes["ROW_2"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("NameFirst_Input","NameLast_Input") "CARD_DL"
    $nodes["NameFirst_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameFirst", "label": "First Name" }' $false $false @() "ROW_2"
    $nodes["NameLast_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameLast", "label": "Last Name" }' $false $false @() "ROW_2"
    $nodes["ROW_3"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["3", "3", "3", "3"] }' $true $false @("NameMiddle_Input","NameSuffix_Input","BirthDate_Input","SexCode_Input") "CARD_DL"
    $nodes["NameMiddle_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameMiddle", "label": "M.I." }' $false $false @() "ROW_3"
    $nodes["NameSuffix_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameSuffix", "label": "Suffix" }' $false $false @() "ROW_3"
    $nodes["BirthDate_Input"] = MakeNode $i "FormDate" "Date" '{ "fieldId": "BirthDate", "label": "Date of Birth" }' $false $false @() "ROW_3"
    $nodes["SexCode_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "SexCode", "label": "Sex", "attributeTypeId": "SEX", "codeTypeProvider": "NIBRS" }' $false $false @() "ROW_3"
    $nodes["ROW_4"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6"] }' $true $false @("ImageIndicator_Input") "CARD_DL"
    $nodes["ImageIndicator_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "ImageIndicator", "label": "Image Indicator", "initialValue": "Y", "codeTypeSource": "NIBRS", "codeTypeCategory": "YES_NO_UNKNOWN" }' $false $false @() "ROW_4"

    # CARD_DH — Driver History (same row pattern, DH-suffix fields)
    $nodes["CARD_DH"] = MakeNode $i "Card" "Card" "{}" $true $false @("ROW_5","ROW_6","ROW_7","ROW_8") "ROOT_PAGE"
    $nodes["ROW_5"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["12"] }' $true $false @("OperatorLicenseNumberDH_Input") "CARD_DH"
    $nodes["OperatorLicenseNumberDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "OperatorLicenseNumberDH", "label": "OLN", "maxLength": "20" }' $false $false @() "ROW_5"
    $nodes["ROW_6"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("NameFirstDH_Input","NameLastDH_Input") "CARD_DH"
    $nodes["NameFirstDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameFirstDH", "label": "First Name" }' $false $false @() "ROW_6"
    $nodes["NameLastDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameLastDH", "label": "Last Name" }' $false $false @() "ROW_6"
    $nodes["ROW_7"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["3", "3", "3", "3"] }' $true $false @("NameMiddleDH_Input","NameSuffixDH_Input","BirthDateDH_Input","SexCodeDH_Input") "CARD_DH"
    $nodes["NameMiddleDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameMiddleDH", "label": "M.I." }' $false $false @() "ROW_7"
    $nodes["NameSuffixDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameSuffixDH", "label": "Suffix" }' $false $false @() "ROW_7"
    $nodes["BirthDateDH_Input"] = MakeNode $i "FormDate" "Date" '{ "fieldId": "BirthDateDH", "label": "Date of Birth" }' $false $false @() "ROW_7"
    $nodes["SexCodeDH_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "SexCodeDH", "label": "Sex", "attributeTypeId": "SEX", "codeTypeProvider": "NIBRS" }' $false $false @() "ROW_7"
    $nodes["ROW_8"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("PurposeCode_Input","Attention_Input") "CARD_DH"
    $nodes["PurposeCode_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "PurposeCode", "label": "Purpose Code", "maxLength": "1" }' $false $false @() "ROW_8"
    $nodes["Attention_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "Attention", "label": "Attention", "maxLength": "30" }' $false $false @() "ROW_8"

    # Assemble
    $nodeTexts = @()
    foreach ($k in $nodes.Keys) {
        $nodeTexts += "    `"$k`": {`n$($nodes[$k])`n    }"
    }
    return ($nodeTexts -join ",`n")
}

# ── BUILD PERSON LAYOUTS ──
$defaultLayout   = BuildPersonLayout -includeCAD $false
$cadLayout       = BuildPersonLayout -includeCAD $true
$frLayout        = BuildPersonLayout -includeCAD $true

$personLayoutBlock = @"
            "default": {
$defaultLayout
            },
            "CAD_DISPATCH": {
$cadLayout
            },
            "FIRST_RESPONDER": {
$frLayout
            }
"@

# ── REPLACE PERSON QIF LAYOUT in source text ──
# Find the Person layout block: starts after "layout": { on the ENTITY_Person config
# and ends before the next configuration block

# Strategy: find "ENTITY_Person" config, then its "layout": { marker, then replace everything
# between "layout": { ... } that closes the layout

$personMarker = '"name": "ENTITY_Person"'
$personIdx = $raw.IndexOf($personMarker)
$layoutStart = $raw.IndexOf('"layout": {', $personIdx)
$layoutContentStart = $layoutStart + '"layout": {'.Length

# Find the matching closing brace for the layout object
$depth = 1; $pos = $layoutContentStart
while ($depth -gt 0 -and $pos -lt $raw.Length) {
    $ch = $raw[$pos]
    if ($ch -eq '{') { $depth++ }
    elseif ($ch -eq '}') { $depth-- }
    # Skip strings
    if ($ch -eq '"') {
        $pos++
        while ($pos -lt $raw.Length -and $raw[$pos] -ne '"') {
            if ($raw[$pos] -eq '\') { $pos++ }  # skip escaped char
            $pos++
        }
    }
    $pos++
}
$layoutEndPos = $pos - 1  # position of the closing }

# Replace layout content
$before = $raw.Substring(0, $layoutContentStart)
$after  = $raw.Substring($layoutEndPos)
$result = $before + "`n" + $personLayoutBlock + "`n          " + $after

# ── ADD NCICNumber + ProcessControlNumber TO FIREARM QIF ──
# For each Firearm layout, add ROW_2 to ROOT_CARD.nodes and add the new node definitions

# New Firearm row + inputs (matches existing style)
$firearmNewNodes = @'
"ROW_2": {
  "type": {
    "resolvedName": "Row"
  },
  "displayName": "Row",
  "props": {
    "templateColumns": ["6", "6"]
  },
  "isCanvas": true,
  "hidden": false,
  "nodes": [
    "NCICNumber_Input",
    "ProcessControlNumber_Input"
  ],
  "parent": "ROOT_CARD",
  "linkedNodes": {}
},
"NCICNumber_Input": {
  "type": {
    "resolvedName": "FormInput"
  },
  "displayName": "Input",
  "props": {
    "fieldId": "NCICNumber",
    "label": "NCIC Number",
    "maxLength": "10"
  },
  "isCanvas": false,
  "hidden": false,
  "nodes": [],
  "parent": "ROW_2",
  "linkedNodes": {}
},
"ProcessControlNumber_Input": {
  "type": {
    "resolvedName": "FormInput"
  },
  "displayName": "Input",
  "props": {
    "fieldId": "ProcessControlNumber",
    "label": "Process Control #",
    "maxLength": "10"
  },
  "isCanvas": false,
  "hidden": false,
  "nodes": [],
  "parent": "ROW_2",
  "linkedNodes": {}
},
'@

# In each Firearm layout, ROOT_CARD.nodes has ["ROW_1", "ROW_4"]
# Change to ["ROW_1", "ROW_2", "ROW_4"] and insert new nodes before ROW_4

# Fix all occurrences within the Firearm section
# First, add ROW_2 to ROOT_CARD.nodes (Firearm only — find within ENTITY_Firearm section)
$fwMarker = '"name": "ENTITY_Firearm"'
$fwStart = $result.IndexOf($fwMarker)
$fwEnd = $result.IndexOf('"name": "ENTITY_Article"', $fwStart)
$fwSection = $result.Substring($fwStart, $fwEnd - $fwStart)

# Replace ROOT_CARD nodes to include ROW_2
$fwFixed = $fwSection.Replace(
    '"ROW_1",' + [char]10 + '    "ROW_4"',
    '"ROW_1",' + [char]10 + '    "ROW_2",' + [char]10 + '    "ROW_4"'
)

# Insert new nodes before each "ROW_4" definition (there are 3 — one per layout)
# We insert before the "ROW_4": { pattern
$fwFixed = $fwFixed.Replace(
    '"ROW_4": {' + [char]10 + '  "type": {' + [char]10 + '    "resolvedName": "Row"',
    $firearmNewNodes + '"ROW_4": {' + [char]10 + '  "type": {' + [char]10 + '    "resolvedName": "Row"'
)

$result = $result.Substring(0, $fwStart) + $fwFixed + $result.Substring($fwEnd)

# ── WRITE OUTPUT ──
[System.IO.File]::WriteAllText($outPath, $result, [System.Text.UTF8Encoding]::new($false))

$sz = (Get-Item $outPath).Length
Write-Host "Written: $outPath ($sz bytes)"
Write-Host "Source was: $((Get-Item $srcPath).Length) bytes"
