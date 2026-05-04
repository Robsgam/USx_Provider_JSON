<#
  build_v2.2_test.ps1 — Complete FL_FCIC v2.2 build
  Reads FL_FCIC_v2.1_CLEAN.json and applies:
    1. Person QIF: 2-card BASE layout (from build_v2.1_test.ps1)
    2. Firearm QIF: +NCICNumber +ProcessControlNumber
    3. Vehicle QIF: merge InState+OOS → single Vehicle (eliminates duplicate targetFields)
    4. Vehicle QIDM: unified attrs + combos (CommSys + RMS)
  Output: FL_FCIC_v2.2_test.json
#>

$srcPath = Join-Path $PSScriptRoot "FL_FCIC_v2.1_CLEAN.json"
$outPath = Join-Path $PSScriptRoot "FL_FCIC_v2.2_test.json"
$raw = [System.IO.File]::ReadAllText($srcPath, [System.Text.UTF8Encoding]::new($false))

# ═══════════════════════════════════════════════════════════
# HELPER: MakeNode — builds a Craft.js node as JSON text
# ═══════════════════════════════════════════════════════════
function MakeNode($indent, $type, $display, $propsJson, $isCanvas, $hidden, $nodes, $parent) {
    $pad = " " * $indent
    $parts = @()
    $parts += "$pad`"type`": { `"resolvedName`": `"$type`" }"
    $parts += "$pad`"displayName`": `"$display`""
    $parts += "$pad`"props`": $propsJson"
    $parts += "$pad`"isCanvas`": $(if($isCanvas){'true'}else{'false'})"
    $parts += "$pad`"hidden`": $(if($hidden){'true'}else{'false'})"
    if ($nodes.Count -eq 0) { $parts += "$pad`"nodes`": []" }
    else { $items = ($nodes | ForEach-Object { "`"$_`"" }) -join ", "; $parts += "$pad`"nodes`": [$items]" }
    $parts += "$pad`"linkedNodes`": {}"
    if ($parent -eq 'null') { $parts += "$pad`"parent`": null" }
    elseif ($parent) { $parts += "$pad`"parent`": `"$parent`"" }
    return ($parts -join ",`n")
}

function AssembleLayout($nodes) {
    $texts = @()
    foreach ($k in $nodes.Keys) { $texts += "    `"$k`": {`n$($nodes[$k])`n    }" }
    return ($texts -join ",`n")
}

# ═══════════════════════════════════════════════════════════
# PERSON LAYOUT BUILDER (2-card BASE pattern)
# ═══════════════════════════════════════════════════════════
function BuildPersonLayout($includeCAD) {
    $i = 6; $n = [ordered]@{}
    $n["ROOT"] = MakeNode $i "Root" "Root" "{}" $false $false @("FORM_ROOT") "null"
    $n["FORM_ROOT"] = MakeNode $i "Form" "Form" '{ "hidePageItems": true, "layout": "page" }' $true $false @("ROOT_PAGE") "ROOT"
    $cards = @(); if ($includeCAD) { $cards += "CONTEXT_INFO_CARD" }; $cards += @("CARD_DL","CARD_DH")
    $n["ROOT_PAGE"] = MakeNode $i "Page" "Page" '{ "title": "Page 1" }' $true $false $cards "FORM_ROOT"
    if ($includeCAD) {
        $n["CONTEXT_INFO_CARD"] = MakeNode $i "Card" "Card" "{}" $true $false @("CONTEXT_ROW1") "ROOT_PAGE"
        $n["CONTEXT_ROW1"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("CadUnit_Input","CadEvent_Input") "CONTEXT_INFO_CARD"
        $n["CadUnit_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "CAD_UNIT_SELECT_VALUE", "label": "Requesting Unit", "attributeTypeId": "CAD_UNIT_SELECT_VALUE" }' $false $false @() "CONTEXT_ROW1"
        $n["CadEvent_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "CAD_EVENT_SELECT_VALUE", "label": "Event", "attributeTypeId": "CAD_EVENT_SELECT_VALUE", "performSearchAhead": true }' $false $false @() "CONTEXT_ROW1"
    }
    $n["CARD_DL"] = MakeNode $i "Card" "Card" "{}" $true $false @("ROW_1","ROW_2","ROW_3","ROW_4") "ROOT_PAGE"
    $n["ROW_1"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("OperatorLicenseNumber_Input","RegistrationState_Input") "CARD_DL"
    $n["OperatorLicenseNumber_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "OperatorLicenseNumber", "label": "OLN", "maxLength": "20" }' $false $false @() "ROW_1"
    $n["RegistrationState_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "RegistrationState", "label": "State", "attributeTypeId": "STATE" }' $false $false @() "ROW_1"
    $n["ROW_2"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("NameFirst_Input","NameLast_Input") "CARD_DL"
    $n["NameFirst_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameFirst", "label": "First Name" }' $false $false @() "ROW_2"
    $n["NameLast_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameLast", "label": "Last Name" }' $false $false @() "ROW_2"
    $n["ROW_3"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["3", "3", "3", "3"] }' $true $false @("NameMiddle_Input","NameSuffix_Input","BirthDate_Input","SexCode_Input") "CARD_DL"
    $n["NameMiddle_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameMiddle", "label": "M.I." }' $false $false @() "ROW_3"
    $n["NameSuffix_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameSuffix", "label": "Suffix" }' $false $false @() "ROW_3"
    $n["BirthDate_Input"] = MakeNode $i "FormDate" "Date" '{ "fieldId": "BirthDate", "label": "Date of Birth" }' $false $false @() "ROW_3"
    $n["SexCode_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "SexCode", "label": "Sex", "attributeTypeId": "SEX", "codeTypeProvider": "NIBRS" }' $false $false @() "ROW_3"
    $n["ROW_4"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6"] }' $true $false @("ImageIndicator_Input") "CARD_DL"
    $n["ImageIndicator_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "ImageIndicator", "label": "Image Indicator", "initialValue": "Y", "codeTypeSource": "NIBRS", "codeTypeCategory": "YES_NO_UNKNOWN" }' $false $false @() "ROW_4"
    $n["CARD_DH"] = MakeNode $i "Card" "Card" "{}" $true $false @("ROW_5","ROW_6","ROW_7","ROW_8") "ROOT_PAGE"
    $n["ROW_5"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["12"] }' $true $false @("OperatorLicenseNumberDH_Input") "CARD_DH"
    $n["OperatorLicenseNumberDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "OperatorLicenseNumberDH", "label": "OLN", "maxLength": "20" }' $false $false @() "ROW_5"
    $n["ROW_6"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("NameFirstDH_Input","NameLastDH_Input") "CARD_DH"
    $n["NameFirstDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameFirstDH", "label": "First Name" }' $false $false @() "ROW_6"
    $n["NameLastDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameLastDH", "label": "Last Name" }' $false $false @() "ROW_6"
    $n["ROW_7"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["3", "3", "3", "3"] }' $true $false @("NameMiddleDH_Input","NameSuffixDH_Input","BirthDateDH_Input","SexCodeDH_Input") "CARD_DH"
    $n["NameMiddleDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameMiddleDH", "label": "M.I." }' $false $false @() "ROW_7"
    $n["NameSuffixDH_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "NameSuffixDH", "label": "Suffix" }' $false $false @() "ROW_7"
    $n["BirthDateDH_Input"] = MakeNode $i "FormDate" "Date" '{ "fieldId": "BirthDateDH", "label": "Date of Birth" }' $false $false @() "ROW_7"
    $n["SexCodeDH_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "SexCodeDH", "label": "Sex", "attributeTypeId": "SEX", "codeTypeProvider": "NIBRS" }' $false $false @() "ROW_7"
    $n["ROW_8"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("PurposeCode_Input","Attention_Input") "CARD_DH"
    $n["PurposeCode_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "PurposeCode", "label": "Purpose Code", "maxLength": "1" }' $false $false @() "ROW_8"
    $n["Attention_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "Attention", "label": "Attention", "maxLength": "30" }' $false $false @() "ROW_8"
    return (AssembleLayout $n)
}

# ═══════════════════════════════════════════════════════════
# VEHICLE LAYOUT BUILDER (merged single QIF)
# ═══════════════════════════════════════════════════════════
function BuildVehicleLayout($includeCAD, $includeLinkToEvent) {
    $i = 6; $n = [ordered]@{}
    $n["ROOT"] = MakeNode $i "Root" "Root" "{}" $false $false @("FORM_ROOT") "null"
    $n["FORM_ROOT"] = MakeNode $i "Form" "Form" '{ "hidePageItems": true, "layout": "page" }' $true $false @("ROOT_PAGE") "ROOT"
    $cards = @(); if ($includeCAD) { $cards += "CONTEXT_INFO_CARD" }; $cards += "ROOT_CARD"
    $n["ROOT_PAGE"] = MakeNode $i "Page" "Page" '{ "title": "Page 1" }' $true $false $cards "FORM_ROOT"
    if ($includeCAD) {
        $cadNodes = @("CONTEXT_ROW1")
        if ($includeLinkToEvent) { $cadNodes += "CONTEXT_ROW2" }
        $n["CONTEXT_INFO_CARD"] = MakeNode $i "Card" "Card" "{}" $true $false $cadNodes "ROOT_PAGE"
        $n["CONTEXT_ROW1"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("CadUnit_Input","CadEvent_Input") "CONTEXT_INFO_CARD"
        $n["CadUnit_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "CAD_UNIT_SELECT_VALUE", "label": "Requesting Unit", "attributeTypeId": "CAD_UNIT_SELECT_VALUE" }' $false $false @() "CONTEXT_ROW1"
        $n["CadEvent_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "CAD_EVENT_SELECT_VALUE", "label": "Event", "attributeTypeId": "CAD_EVENT_SELECT_VALUE", "performSearchAhead": true }' $false $false @() "CONTEXT_ROW1"
        if ($includeLinkToEvent) {
            $n["CONTEXT_ROW2"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6"] }' $true $false @("LinkToEvent_Input") "CONTEXT_INFO_CARD"
            $n["LinkToEvent_Input"] = MakeNode $i "FormCheckbox" "Checkbox" '{ "fieldId": "LinkToEvent", "label": "Link to Event", "checkboxLabel": "Link to Event" }' $false $false @() "CONTEXT_ROW2"
        }
    }
    # Single Vehicle card — BASE pattern
    $n["ROOT_CARD"] = MakeNode $i "Card" "Card" "{}" $true $false @("ROW_1","ROW_2","ROW_3","ROW_4") "ROOT_PAGE"
    # ROW_1: Plate + State
    $n["ROW_1"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("LicensePlateNumber_Input","RegistrationState_Input") "ROOT_CARD"
    $n["LicensePlateNumber_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "LicensePlateNumber", "label": "License Plate #" }' $false $false @() "ROW_1"
    $n["RegistrationState_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "RegistrationState", "label": "State", "attributeTypeId": "STATE" }' $false $false @() "ROW_1"
    # ROW_2: VIN + Decal
    $n["ROW_2"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["6", "6"] }' $true $false @("VehicleIdentificationNumber_Input","DecalNumber_Input") "ROOT_CARD"
    $n["VehicleIdentificationNumber_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "VehicleIdentificationNumber", "label": "VIN", "maxLength": "20" }' $false $false @() "ROW_2"
    $n["DecalNumber_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "DecalNumber", "label": "Decal Number", "maxLength": "10" }' $false $false @() "ROW_2"
    # ROW_3: PlateYear + PlateType + TitleLien + VINSeq
    $n["ROW_3"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["3", "3", "3", "3"] }' $true $false @("LicensePlateYear_Input","LicensePlateTypeCode_Input","TitleLienInformation_Input","VINSequenceNumber_Input") "ROOT_CARD"
    $n["LicensePlateYear_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "LicensePlateYear", "label": "Plate Year", "maxLength": "4" }' $false $false @() "ROW_3"
    $n["LicensePlateTypeCode_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "LicensePlateTypeCode", "label": "Plate Type", "maxLength": "2" }' $false $false @() "ROW_3"
    $n["TitleLienInformation_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "TitleLienInformation", "label": "Title Lien", "maxLength": "8" }' $false $false @() "ROW_3"
    $n["VINSequenceNumber_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "VINSequenceNumber", "label": "VIN Seq #", "maxLength": "2" }' $false $false @() "ROW_3"
    # ROW_4: Make + Year + Image + RelatedHit
    $n["ROW_4"] = MakeNode $i "Row" "Row" '{ "templateColumns": ["3", "3", "3", "3"] }' $true $false @("VehicleMakeCode_Input","VehicleYear_Input","ImageIndicator_Input","RelatedHitSearchIndicator_Input") "ROOT_CARD"
    $n["VehicleMakeCode_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "VehicleMakeCode", "label": "Make", "maxLength": "24" }' $false $false @() "ROW_4"
    $n["VehicleYear_Input"] = MakeNode $i "FormInput" "Input" '{ "fieldId": "VehicleYear", "label": "Vehicle Year", "maxLength": "4" }' $false $false @() "ROW_4"
    $n["ImageIndicator_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "ImageIndicator", "label": "Image", "codeTypeCategory": "YES_NO_UNKNOWN", "codeTypeSource": "NIBRS", "initialValue": "Y" }' $false $false @() "ROW_4"
    $n["RelatedHitSearchIndicator_Input"] = MakeNode $i "FormSelect" "Select" '{ "fieldId": "RelatedHitSearchIndicator", "label": "Related Hit", "codeTypeCategory": "YES_NO_UNKNOWN", "codeTypeSource": "NIBRS" }' $false $false @() "ROW_4"
    return (AssembleLayout $n)
}

# ═══════════════════════════════════════════════════════════
# 1) REPLACE PERSON QIF LAYOUT
# ═══════════════════════════════════════════════════════════
$pDefault = BuildPersonLayout $false
$pCAD     = BuildPersonLayout $true
$pFR      = BuildPersonLayout $true
$personBlock = "            `"default`": {`n$pDefault`n            },`n            `"CAD_DISPATCH`": {`n$pCAD`n            },`n            `"FIRST_RESPONDER`": {`n$pFR`n            }"

$pMark = '"name": "ENTITY_Person"'
$pIdx  = $raw.IndexOf($pMark)
$pLay  = $raw.IndexOf('"layout": {', $pIdx) + '"layout": {'.Length
$depth = 1; $pos = $pLay
while ($depth -gt 0) { $ch = $raw[$pos]; if ($ch -eq '{'){$depth++} elseif ($ch -eq '}'){$depth--}; if ($ch -eq '"'){ $pos++; while ($raw[$pos] -ne '"'){ if ($raw[$pos] -eq '\'){ $pos++ }; $pos++ } }; $pos++ }
$pEnd = $pos - 1
$raw = $raw.Substring(0, $pLay) + "`n" + $personBlock + "`n          " + $raw.Substring($pEnd)

# ═══════════════════════════════════════════════════════════
# 2) REPLACE 2 VEHICLE QIFs WITH 1 MERGED VEHICLE QIF
# ═══════════════════════════════════════════════════════════
$vDefault = BuildVehicleLayout $false $false
$vCAD     = BuildVehicleLayout $true $false
$vFR      = BuildVehicleLayout $true $true

$vehicleQIF = @"
{
  "name": "ENTITY_Vehicle",
  "type": "QUERYINPUTFORM",
  "description": "Vehicle entity form -- merged (FL in-state + OOS)",
  "label": "Vehicle",
  "targetEntity": "Vehicle",
  "layout": {
    "default": {
$vDefault
    },
    "CAD_DISPATCH": {
$vCAD
    },
    "FIRST_RESPONDER": {
$vFR
    }
  }
}
"@

# Find Vehicle_InState start and Firearm start (Vehicle_OOS is between them)
$viMark = '"name": "ENTITY_Vehicle_InState"'
$viIdx  = $raw.IndexOf($viMark)
# Walk back to the opening { of this config object
$viStart = $raw.LastIndexOf('{', $viIdx)

$fwMark = '"name": "ENTITY_Firearm"'
$fwIdx  = $raw.IndexOf($fwMark)
$fwStart = $raw.LastIndexOf('{', $fwIdx)

# The text from viStart to fwStart is: { Vehicle_InState }, { Vehicle_OOS },
# We replace with: { merged Vehicle },
$raw = $raw.Substring(0, $viStart) + $vehicleQIF + ",`n        " + $raw.Substring($fwStart)

# ═══════════════════════════════════════════════════════════
# 3) ADD FIREARM NCICNumber + ProcessControlNumber
# ═══════════════════════════════════════════════════════════
$firearmNewNodes = @'
"ROW_2": {
  "type": { "resolvedName": "Row" },
  "displayName": "Row",
  "props": { "templateColumns": ["6", "6"] },
  "isCanvas": true,
  "hidden": false,
  "nodes": ["NCICNumber_Input", "ProcessControlNumber_Input"],
  "parent": "ROOT_CARD",
  "linkedNodes": {}
},
"NCICNumber_Input": {
  "type": { "resolvedName": "FormInput" },
  "displayName": "Input",
  "props": { "fieldId": "NCICNumber", "label": "NCIC Number", "maxLength": "10" },
  "isCanvas": false,
  "hidden": false,
  "nodes": [],
  "parent": "ROW_2",
  "linkedNodes": {}
},
"ProcessControlNumber_Input": {
  "type": { "resolvedName": "FormInput" },
  "displayName": "Input",
  "props": { "fieldId": "ProcessControlNumber", "label": "Process Control #", "maxLength": "10" },
  "isCanvas": false,
  "hidden": false,
  "nodes": [],
  "parent": "ROW_2",
  "linkedNodes": {}
},
'@

$fwMark2 = '"name": "ENTITY_Firearm"'
$fwIdx2 = $raw.IndexOf($fwMark2)
$fwEnd2 = $raw.IndexOf('"name": "ENTITY_Article"', $fwIdx2)
$fwSection = $raw.Substring($fwIdx2, $fwEnd2 - $fwIdx2)

$fwFixed = $fwSection.Replace(
    "`"ROW_1`",`n    `"ROW_4`"",
    "`"ROW_1`",`n    `"ROW_2`",`n    `"ROW_4`""
)
$fwFixed = $fwFixed.Replace(
    "`"ROW_4`": {`n  `"type`": {`n    `"resolvedName`": `"Row`"",
    $firearmNewNodes + "`"ROW_4`": {`n  `"type`": {`n    `"resolvedName`": `"Row`""
)
$raw = $raw.Substring(0, $fwIdx2) + $fwFixed + $raw.Substring($fwEnd2)

# ═══════════════════════════════════════════════════════════
# 4) REPLACE COMMSYS VEHICLE QIDM (unified attrs + combos)
# ═══════════════════════════════════════════════════════════
$vehicleQIDM = @'
{
      "name": "FL_FCIC_VehicleRegistrationQuery",
      "type": "QUERYINPUTDATAMAPPING",
      "description": "Configuration for FL FCIC Vehicle Registration Query",
      "handlerFunction": "CommsysTransactionRequestHandler",
      "provider": "FL_FCIC",
      "providerType": "Commsys",
      "query": "VehicleRegistrationQuery",
      "queryLabel": "Vehicle Registration",
      "targetEntity": "Vehicle",
      "autoSelect": true,
      "attributes": [
        {
          "name": "DecalNumber",
          "size": 10,
          "sourceField": ["DecalNumber"],
          "targetField": "DecalNumber"
        },
        {
          "name": "ImageIndicator",
          "size": 1,
          "sourceField": ["ImageIndicator"],
          "targetField": "ImageIndicator"
        },
        {
          "name": "LicensePlateNumber",
          "size": 10,
          "sourceField": ["LicensePlateNumber"],
          "targetField": "LicensePlateNumber"
        },
        {
          "name": "LicensePlateTypeCode",
          "size": 2,
          "sourceField": ["LicensePlateTypeCode"],
          "targetField": "LicensePlateTypeCode"
        },
        {
          "name": "LicensePlateYear",
          "size": 4,
          "sourceField": ["LicensePlateYear"],
          "targetField": "LicensePlateYear"
        },
        {
          "name": "VehicleIdentificationNumber",
          "size": 20,
          "sourceField": ["VehicleIdentificationNumber"],
          "targetField": "VehicleIdentificationNumber"
        },
        {
          "name": "VINSequenceNumber",
          "size": 2,
          "sourceField": ["VINSequenceNumber"],
          "targetField": "VINSequenceNumber"
        },
        {
          "name": "TitleLienInformation",
          "size": 8,
          "sourceField": ["TitleLienInformation"],
          "targetField": "TitleLienInformation"
        },
        {
          "name": "VehicleMakeCode",
          "size": 24,
          "sourceField": ["VehicleMakeCode"],
          "targetField": "VehicleMakeCode"
        },
        {
          "name": "VehicleYear",
          "size": 4,
          "sourceField": ["VehicleYear"],
          "targetField": "VehicleYear",
          "rule": {
            "function": "ParseCommsysVehicleYearRuleHandler",
            "arguments": []
          }
        },
        {
          "name": "RelatedHitSearchIndicator",
          "size": 1,
          "sourceField": ["RelatedHitSearchIndicator"],
          "targetField": "RelatedHitSearchIndicator"
        },
        {
          "name": "State",
          "size": 2,
          "sourceField": ["RegistrationState"],
          "targetField": "State"
        },
        {
          "name": "OriginatingAgencyORI",
          "size": 18,
          "sourceField": ["ORI"],
          "targetField": "OriginatingAgencyORI"
        },
        {
          "name": "Requestor",
          "size": 30,
          "sourceField": ["Requestor"],
          "targetField": "Requestor",
          "rule": {
            "function": "CommsysGetLastNameFirstNameInitialRuleHandler"
          }
        }
      ],
      "combinations": [
        {
          "requirements": {
            "set": ["DecalNumber", "LicensePlateYear"],
            "any": ["Requestor", "ImageIndicator"]
          },
          "primaryFieldReference": "DecalNumber",
          "keyReference": "FRQDecalNumber",
          "state": "In"
        },
        {
          "requirements": {
            "set": ["LicensePlateNumber", "LicensePlateYear"],
            "any": ["Requestor", "ImageIndicator"]
          },
          "primaryFieldReference": "LicensePlateNumber",
          "keyReference": "FRQLicensePlateNumber",
          "state": "In"
        },
        {
          "requirements": {
            "set": ["TitleLienInformation"],
            "any": ["Requestor", "ImageIndicator"]
          },
          "primaryFieldReference": "TitleLienInformation",
          "keyReference": "FRQTitleLienInformation",
          "state": "In"
        },
        {
          "requirements": {
            "set": ["VehicleIdentificationNumber"],
            "any": ["Requestor", "VINSequenceNumber", "ImageIndicator"]
          },
          "primaryFieldReference": "VehicleIdentificationNumber",
          "keyReference": "FRQVehicleIdentificationNumber",
          "state": "In"
        },
        {
          "requirements": {
            "set": ["LicensePlateNumber", "LicensePlateYear", "RegistrationState", "LicensePlateTypeCode"],
            "any": ["ImageIndicator", "RelatedHitSearchIndicator", "Requestor"]
          },
          "primaryFieldReference": "LicensePlateNumber",
          "keyReference": "QVLicensePlateNumber",
          "state": "In/Out"
        },
        {
          "requirements": {
            "set": ["VehicleIdentificationNumber", "RegistrationState"],
            "any": ["ImageIndicator", "RelatedHitSearchIndicator", "Requestor", "VehicleMakeCode"]
          },
          "primaryFieldReference": "VehicleIdentificationNumber",
          "keyReference": "QVVehicleIdentificationNumber",
          "state": "In/Out"
        },
        {
          "requirements": {
            "set": ["LicensePlateNumber", "LicensePlateTypeCode", "LicensePlateYear", "RegistrationState"],
            "any": ["Requestor", "ImageIndicator"]
          },
          "primaryFieldReference": "LicensePlateNumber",
          "keyReference": "RQLicensePlateNumber",
          "state": "In/Out"
        },
        {
          "requirements": {
            "set": ["VehicleIdentificationNumber", "RegistrationState"],
            "any": ["Requestor", "VehicleMakeCode", "VehicleYear", "ImageIndicator"]
          },
          "primaryFieldReference": "VehicleIdentificationNumber",
          "keyReference": "RQVehicleIdentificationNumber",
          "state": "In/Out"
        }
      ]
    }
'@

# Find and replace the CommSys Vehicle QIDM
$vqMark = '"name": "FL_FCIC_VehicleRegistrationQuery"'
$vqIdx = $raw.IndexOf($vqMark)
$vqStart = $raw.LastIndexOf('{', $vqIdx)
# Find closing: walk braces
$depth = 0; $pos = $vqStart
do { $ch = $raw[$pos]; if($ch -eq '{'){$depth++} elseif($ch -eq '}'){$depth--}; if($ch -eq '"'){$pos++;while($raw[$pos] -ne '"'){if($raw[$pos] -eq '\'){$pos++};$pos++}}; $pos++ } while ($depth -gt 0)
$vqEnd = $pos
$raw = $raw.Substring(0, $vqStart) + $vehicleQIDM + $raw.Substring($vqEnd)

# ═══════════════════════════════════════════════════════════
# 5) REPLACE RMS VEHICLE QIDM (unified, no duplicates)
# ═══════════════════════════════════════════════════════════
$rmsVehicleQIDM = @'
{
        "name": "RMS Vehicle search query",
        "type": "QUERYINPUTDATAMAPPING",
        "description": "Configuration for handling elastic query with various attributes.",
        "handlerFunction": "RmsRestPayloadHandler",
        "provider": "MARK43 RMS",
        "query": "Vehicle",
        "queryLabel": "RMS",
        "targetEntity": "Vehicle",
        "attributes": [
          {
            "name": "yearOfManufacture",
            "size": 60,
            "sourceField": ["VehicleYear"],
            "targetField": "vehicle.yearOfManufacture"
          },
          {
            "name": "VehicleIdentificationNumber",
            "sourceField": ["VehicleIdentificationNumber"],
            "targetField": "vehicle.vinNumber"
          },
          {
            "name": "makeNcicCode",
            "sourceField": ["VehicleMakeCode"],
            "targetField": "vehicle.makeNcicCode"
          },
          {
            "name": "LicensePlateNumber",
            "sourceField": ["LicensePlateNumber"],
            "targetField": "vehicle.tag"
          },
          {
            "name": "RegistrationState",
            "sourceField": ["RegistrationState"],
            "targetField": "vehicle.registrationStateAttrIds",
            "rule": {
              "function": "AttributeArrayWrapperRuleHandler"
            },
            "useAttributeId": true
          }
        ],
        "combinations": [
          {
            "requirements": {
              "set": ["VehicleIdentificationNumber"],
              "any": ["VehicleYear", "VehicleMakeCode", "LicensePlateNumber", "RegistrationState"]
            },
            "keyReference": "vehicleIdentificationNumber"
          },
          {
            "requirements": {
              "set": ["LicensePlateNumber"],
              "any": ["VehicleYear", "VehicleMakeCode", "RegistrationState"]
            },
            "keyReference": "licensePlateNumber"
          }
        ]
      }
'@

$rvMark = '"name": "RMS Vehicle search query"'
$rvIdx = $raw.IndexOf($rvMark)
$rvStart = $raw.LastIndexOf('{', $rvIdx)
$depth = 0; $pos = $rvStart
do { $ch = $raw[$pos]; if($ch -eq '{'){$depth++} elseif($ch -eq '}'){$depth--}; if($ch -eq '"'){$pos++;while($raw[$pos] -ne '"'){if($raw[$pos] -eq '\'){$pos++};$pos++}}; $pos++ } while ($depth -gt 0)
$rvEnd = $pos
$raw = $raw.Substring(0, $rvStart) + $rmsVehicleQIDM + $raw.Substring($rvEnd)

# ═══════════════════════════════════════════════════════════
# WRITE OUTPUT
# ═══════════════════════════════════════════════════════════
[System.IO.File]::WriteAllText($outPath, $raw, [System.Text.UTF8Encoding]::new($false))
$sz = (Get-Item $outPath).Length
Write-Host "Written: $outPath ($sz bytes)"
Write-Host "Source:  $((Get-Item $srcPath).Length) bytes"
