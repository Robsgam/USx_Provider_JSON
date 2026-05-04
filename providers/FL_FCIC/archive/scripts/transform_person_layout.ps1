<#
  transform_person_layout.ps1
  Transforms Person QIF from 2-card to 6-card layout.

  6-card design:
    Card 1 "Search Options"               : State, ImageIndicator
    Card 2 "DL / Wanted -- by OLN"        : OperatorLicenseNumber
    Card 3 "DL / Wanted -- by Name/DOB"   : First, Last, MI, Suffix, DOB, Sex
    Card 4 "Driver History -- by OLN"      : OperatorLicenseNumberDH
    Card 5 "Driver History -- by Name/DOB" : FirstDH, LastDH, MIDH, SuffixDH, DOBDH, SexDH
    Card 6 "Driver History -- Required"    : PurposeCode, Attention
#>

$ErrorActionPreference = "Stop"

$path = Join-Path $PSScriptRoot "FL_FCIC_v2.2_test.json"
$raw = [System.IO.File]::ReadAllText((Resolve-Path $path), [System.Text.UTF8Encoding]::new($false))

# ── Shared field blocks (reused across all 3 variants) ──

$FIELDS_CARD_OPTIONS = @'
    "CARD_OPTIONS": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": { "title": "Search Options" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROW_OPT1"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "ROW_OPT1": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["6", "6"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["RegistrationState_Input", "ImageIndicator_Input"],
      "linkedNodes": {},
      "parent": "CARD_OPTIONS"
    },
    "RegistrationState_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "RegistrationState", "label": "State", "attributeTypeId": "STATE" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_OPT1"
    },
    "ImageIndicator_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "ImageIndicator", "label": "Image Indicator", "initialValue": "Y", "codeTypeSource": "NIBRS", "codeTypeCategory": "YES_NO_UNKNOWN" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_OPT1"
    },
'@

$FIELDS_CARD_DL_OLN = @'
    "CARD_DL_OLN": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": { "title": "DL / Wanted Person \u2014 by OLN" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROW_DL_OLN"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "ROW_DL_OLN": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["12"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["OperatorLicenseNumber_Input"],
      "linkedNodes": {},
      "parent": "CARD_DL_OLN"
    },
    "OperatorLicenseNumber_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "OperatorLicenseNumber", "label": "OLN", "maxLength": "20" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_OLN"
    },
'@

$FIELDS_CARD_DL_NAME = @'
    "CARD_DL_NAME": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": { "title": "DL / Wanted Person \u2014 by Name/DOB" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROW_DL_NAME1", "ROW_DL_NAME2"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "ROW_DL_NAME1": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["6", "6"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["NameFirst_Input", "NameLast_Input"],
      "linkedNodes": {},
      "parent": "CARD_DL_NAME"
    },
    "NameFirst_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameFirst", "label": "First Name" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_NAME1"
    },
    "NameLast_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameLast", "label": "Last Name" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_NAME1"
    },
    "ROW_DL_NAME2": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["3", "3", "3", "3"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["NameMiddle_Input", "NameSuffix_Input", "BirthDate_Input", "SexCode_Input"],
      "linkedNodes": {},
      "parent": "CARD_DL_NAME"
    },
    "NameMiddle_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameMiddle", "label": "M.I." },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_NAME2"
    },
    "NameSuffix_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameSuffix", "label": "Suffix" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_NAME2"
    },
    "BirthDate_Input": {
      "type": { "resolvedName": "FormDate" },
      "displayName": "Date",
      "props": { "fieldId": "BirthDate", "label": "Date of Birth" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_NAME2"
    },
    "SexCode_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "SexCode", "label": "Sex", "attributeTypeId": "SEX", "codeTypeProvider": "NIBRS" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DL_NAME2"
    },
'@

$FIELDS_CARD_DH_OLN = @'
    "CARD_DH_OLN": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": { "title": "Driver History \u2014 by OLN" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROW_DH_OLN"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "ROW_DH_OLN": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["12"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["OperatorLicenseNumberDH_Input"],
      "linkedNodes": {},
      "parent": "CARD_DH_OLN"
    },
    "OperatorLicenseNumberDH_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "OperatorLicenseNumberDH", "label": "OLN", "maxLength": "20" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_OLN"
    },
'@

$FIELDS_CARD_DH_NAME = @'
    "CARD_DH_NAME": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": { "title": "Driver History \u2014 by Name/DOB" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROW_DH_NAME1", "ROW_DH_NAME2"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "ROW_DH_NAME1": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["6", "6"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["NameFirstDH_Input", "NameLastDH_Input"],
      "linkedNodes": {},
      "parent": "CARD_DH_NAME"
    },
    "NameFirstDH_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameFirstDH", "label": "First Name" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_NAME1"
    },
    "NameLastDH_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameLastDH", "label": "Last Name" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_NAME1"
    },
    "ROW_DH_NAME2": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["3", "3", "3", "3"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["NameMiddleDH_Input", "NameSuffixDH_Input", "BirthDateDH_Input", "SexCodeDH_Input"],
      "linkedNodes": {},
      "parent": "CARD_DH_NAME"
    },
    "NameMiddleDH_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameMiddleDH", "label": "M.I." },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_NAME2"
    },
    "NameSuffixDH_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "NameSuffixDH", "label": "Suffix" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_NAME2"
    },
    "BirthDateDH_Input": {
      "type": { "resolvedName": "FormDate" },
      "displayName": "Date",
      "props": { "fieldId": "BirthDateDH", "label": "Date of Birth" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_NAME2"
    },
    "SexCodeDH_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "SexCodeDH", "label": "Sex", "attributeTypeId": "SEX", "codeTypeProvider": "NIBRS" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_NAME2"
    },
'@

$FIELDS_CARD_DH_OPTIONS = @'
    "CARD_DH_OPTIONS": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": { "title": "Driver History \u2014 Required" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROW_DH_REQ"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "ROW_DH_REQ": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["6", "6"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["PurposeCode_Input", "Attention_Input"],
      "linkedNodes": {},
      "parent": "CARD_DH_OPTIONS"
    },
    "PurposeCode_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "PurposeCode", "label": "Purpose Code", "maxLength": "1" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_REQ"
    },
    "Attention_Input": {
      "type": { "resolvedName": "FormInput" },
      "displayName": "Input",
      "props": { "fieldId": "Attention", "label": "Attention", "maxLength": "30" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "ROW_DH_REQ"
    }
'@

# ── CONTEXT_INFO_CARD blocks ──

$CONTEXT_CAD = @'
    "CONTEXT_INFO_CARD": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": {},
      "isCanvas": true,
      "hidden": false,
      "nodes": ["CONTEXT_ROW1"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "CONTEXT_ROW1": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["6", "6"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["CadUnit_Input", "CadEvent_Input"],
      "linkedNodes": {},
      "parent": "CONTEXT_INFO_CARD"
    },
    "CadUnit_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "CAD_UNIT_SELECT_VALUE", "label": "Requesting Unit", "attributeTypeId": "CAD_UNIT_SELECT_VALUE" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "CONTEXT_ROW1"
    },
    "CadEvent_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "CAD_EVENT_SELECT_VALUE", "label": "Event", "attributeTypeId": "CAD_EVENT_SELECT_VALUE", "performSearchAhead": true },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "CONTEXT_ROW1"
    },
'@

$CONTEXT_FR = @'
    "CONTEXT_INFO_CARD": {
      "type": { "resolvedName": "Card" },
      "displayName": "Card",
      "props": {},
      "isCanvas": true,
      "hidden": false,
      "nodes": ["CONTEXT_ROW1", "CONTEXT_ROW2"],
      "linkedNodes": {},
      "parent": "ROOT_PAGE"
    },
    "CONTEXT_ROW1": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["6", "6"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["CadUnit_Input", "CadEvent_Input"],
      "linkedNodes": {},
      "parent": "CONTEXT_INFO_CARD"
    },
    "CadUnit_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "CAD_UNIT_SELECT_VALUE", "label": "Requesting Unit", "attributeTypeId": "CAD_UNIT_SELECT_VALUE" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "CONTEXT_ROW1"
    },
    "CadEvent_Input": {
      "type": { "resolvedName": "FormSelect" },
      "displayName": "Select",
      "props": { "fieldId": "CAD_EVENT_SELECT_VALUE", "label": "Event", "attributeTypeId": "CAD_EVENT_SELECT_VALUE", "performSearchAhead": true },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "CONTEXT_ROW1"
    },
    "CONTEXT_ROW2": {
      "type": { "resolvedName": "Row" },
      "displayName": "Row",
      "props": { "templateColumns": ["12"] },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["LinkToEvent_Input"],
      "linkedNodes": {},
      "parent": "CONTEXT_INFO_CARD"
    },
    "LinkToEvent_Input": {
      "type": { "resolvedName": "FormCheckbox" },
      "displayName": "Checkbox",
      "props": { "fieldId": "LINK_TO_EVENT", "label": "Link to Event" },
      "isCanvas": false,
      "hidden": false,
      "nodes": [],
      "linkedNodes": {},
      "parent": "CONTEXT_ROW2"
    },
'@

# ── Scaffold builders ──

$pageChildrenDefault = '"CARD_OPTIONS", "CARD_DL_OLN", "CARD_DL_NAME", "CARD_DH_OLN", "CARD_DH_NAME", "CARD_DH_OPTIONS"'
$pageChildrenCAD     = '"CONTEXT_INFO_CARD", "CARD_OPTIONS", "CARD_DL_OLN", "CARD_DL_NAME", "CARD_DH_OLN", "CARD_DH_NAME", "CARD_DH_OPTIONS"'

function Build-Scaffold {
    param([string]$PageChildren)
    return @"
    "ROOT": {
      "type": { "resolvedName": "Root" },
      "displayName": "Root",
      "props": {},
      "isCanvas": false,
      "hidden": false,
      "nodes": ["FORM_ROOT"],
      "linkedNodes": {},
      "parent": null
    },
    "FORM_ROOT": {
      "type": { "resolvedName": "Form" },
      "displayName": "Form",
      "props": { "hidePageItems": true, "layout": "page" },
      "isCanvas": true,
      "hidden": false,
      "nodes": ["ROOT_PAGE"],
      "linkedNodes": {},
      "parent": "ROOT"
    },
    "ROOT_PAGE": {
      "type": { "resolvedName": "Page" },
      "displayName": "Page",
      "props": { "title": "Page 1" },
      "isCanvas": true,
      "hidden": false,
      "nodes": [$PageChildren],
      "linkedNodes": {},
      "parent": "FORM_ROOT"
    },
"@
}

# ── Assemble complete layout variants ──

$allCards = @($FIELDS_CARD_OPTIONS, $FIELDS_CARD_DL_OLN, $FIELDS_CARD_DL_NAME, $FIELDS_CARD_DH_OLN, $FIELDS_CARD_DH_NAME, $FIELDS_CARD_DH_OPTIONS) -join "`n"

$defaultScaffold = Build-Scaffold $pageChildrenDefault
$cadScaffold = Build-Scaffold $pageChildrenCAD
$frScaffold = Build-Scaffold $pageChildrenCAD

$defaultLayout = "            `"default`": {`n$defaultScaffold`n$allCards`n            }"
$cadLayout = "            `"CAD_DISPATCH`": {`n$cadScaffold`n$CONTEXT_CAD`n$allCards`n            }"
$frLayout = "            `"FIRST_RESPONDER`": {`n$frScaffold`n$CONTEXT_FR`n$allCards`n            }"

$fullLayout = "          `"layout`": {`n$defaultLayout,`n$cadLayout,`n$frLayout`n          }"

# ── Find and replace the layout block in raw JSON ──

$lines = $raw -split "`n"

$layoutStart = -1
$inPersonQif = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '"name":\s*"ENTITY_Person"') {
        $inPersonQif = $true
    }
    if ($inPersonQif -and $lines[$i] -match '^\s*"layout":\s*\{') {
        $layoutStart = $i
        break
    }
}

if ($layoutStart -lt 0) {
    Write-Host "ERROR: Could not find Person QIF layout block" -ForegroundColor Red
    exit 1
}

# Find matching closing brace (the one that closes "layout": { ... })
$braceDepth = 0
$layoutEnd = -1
$startedCounting = $false

for ($i = $layoutStart; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq '{') {
            $braceDepth++
            $startedCounting = $true
        }
        elseif ($ch -eq '}') {
            $braceDepth--
            if ($startedCounting -and $braceDepth -eq 0) {
                $layoutEnd = $i
                break
            }
        }
    }
    if ($layoutEnd -ge 0) { break }
}

if ($layoutEnd -lt 0) {
    Write-Host "ERROR: Could not find end of layout block" -ForegroundColor Red
    exit 1
}

Write-Host "Layout block found: lines $($layoutStart+1) to $($layoutEnd+1) ($($layoutEnd - $layoutStart + 1) lines)" -ForegroundColor Cyan

# Replace
$before = $lines[0..($layoutStart - 1)]
$after = $lines[($layoutEnd + 1)..($lines.Count - 1)]

$newContent = ($before -join "`n") + "`n" + $fullLayout + "`n" + ($after -join "`n")

# Write back
[System.IO.File]::WriteAllText($path, $newContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Person QIF transformed to 6-card layout:" -ForegroundColor Green
Write-Host "  Card 1: Search Options (State, Image)" -ForegroundColor Gray
Write-Host "  Card 2: DL / Wanted -- by OLN" -ForegroundColor Gray
Write-Host "  Card 3: DL / Wanted -- by Name/DOB (First, Last, MI, Suffix, DOB, Sex)" -ForegroundColor Gray
Write-Host "  Card 4: Driver History -- by OLN" -ForegroundColor Gray
Write-Host "  Card 5: Driver History -- by Name/DOB" -ForegroundColor Gray
Write-Host "  Card 6: Driver History -- Required (PurposeCode, Attention)" -ForegroundColor Gray
Write-Host ""
Write-Host "  3 variants: default, CAD_DISPATCH (+Unit/Event), FIRST_RESPONDER (+Unit/Event/LinkToEvent)" -ForegroundColor Gray
