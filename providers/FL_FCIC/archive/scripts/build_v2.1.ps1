# FL_FCIC v2.1 Build Script
# Transforms FL_FCIC.json -> FL_FCIC_v2.1_test.json
# - Merges 3 Person QIFs into 1
# - Fixes DLQ/DHQ QIDMs (remove OOS duplicates, add codeTypeProvider)
#
# Strategy: Parse with .NET JavaScriptSerializer, but serialize back using
# a custom recursive serializer to avoid PS PSObject wrapping issues.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web.Extensions

$inputPath  = "C:/Users/RobSgambellone/.local/bin/FL_FCIC/FL_FCIC.json"
$outputPath = "C:/Users/RobSgambellone/.local/bin/FL_FCIC/FL_FCIC_v2.1_test.json"

Write-Host "=== FL_FCIC v2.1 Build Script ===" -ForegroundColor Cyan
Write-Host ""

# ── Add C# helper class for clean serialization ─────────────────
Add-Type -TypeDefinition @"
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

public class CleanJsonSerializer
{
    private StringBuilder sb;

    public string Serialize(object obj)
    {
        sb = new StringBuilder();
        WriteValue(obj);
        return sb.ToString();
    }

    private void WriteValue(object obj)
    {
        if (obj == null)
        {
            sb.Append("null");
        }
        else if (obj is string)
        {
            WriteString((string)obj);
        }
        else if (obj is bool)
        {
            sb.Append((bool)obj ? "true" : "false");
        }
        else if (obj is int || obj is long || obj is double || obj is float || obj is decimal)
        {
            sb.Append(obj.ToString());
        }
        else if (obj is IDictionary)
        {
            WriteDictionary((IDictionary)obj);
        }
        else if (obj is IList)
        {
            WriteArray((IList)obj);
        }
        else if (obj is Array)
        {
            WriteArray((Array)obj);
        }
        else
        {
            // Fallback: convert to string
            WriteString(obj.ToString());
        }
    }

    private void WriteString(string s)
    {
        sb.Append('"');
        foreach (char c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default:
                    if (c < ' ')
                        sb.AppendFormat("\\u{0:x4}", (int)c);
                    else
                        sb.Append(c);
                    break;
            }
        }
        sb.Append('"');
    }

    private void WriteDictionary(IDictionary dict)
    {
        sb.Append('{');
        bool first = true;
        foreach (DictionaryEntry entry in dict)
        {
            if (!first) sb.Append(',');
            first = false;
            WriteString(entry.Key.ToString());
            sb.Append(':');
            WriteValue(entry.Value);
        }
        sb.Append('}');
    }

    private void WriteArray(IList arr)
    {
        sb.Append('[');
        for (int i = 0; i < arr.Count; i++)
        {
            if (i > 0) sb.Append(',');
            WriteValue(arr[i]);
        }
        sb.Append(']');
    }

    private void WriteArray(Array arr)
    {
        sb.Append('[');
        for (int i = 0; i < arr.Length; i++)
        {
            if (i > 0) sb.Append(',');
            WriteValue(arr.GetValue(i));
        }
        sb.Append(']');
    }

    public static string Format(string json)
    {
        var result = new StringBuilder();
        int indent = 0;
        bool inString = false;
        bool escaped = false;

        for (int i = 0; i < json.Length; i++)
        {
            char c = json[i];

            if (escaped)
            {
                result.Append(c);
                escaped = false;
                continue;
            }

            if (c == '\\' && inString)
            {
                result.Append(c);
                escaped = true;
                continue;
            }

            if (c == '"')
            {
                inString = !inString;
                result.Append(c);
                continue;
            }

            if (inString)
            {
                result.Append(c);
                continue;
            }

            switch (c)
            {
                case '{':
                case '[':
                    sb_PeekEmpty(result, json, i, c, ref indent);
                    break;
                case '}':
                case ']':
                    indent--;
                    if (indent < 0) indent = 0;
                    result.Append('\n');
                    result.Append(' ', indent * 2);
                    result.Append(c);
                    break;
                case ',':
                    result.Append(c);
                    result.Append('\n');
                    result.Append(' ', indent * 2);
                    break;
                case ':':
                    result.Append(": ");
                    break;
                default:
                    if (!Char.IsWhiteSpace(c))
                        result.Append(c);
                    break;
            }
        }

        return result.ToString();
    }

    private static void sb_PeekEmpty(StringBuilder result, string json, int i, char c, ref int indent)
    {
        result.Append(c);
        // Check if next non-ws char closes the bracket
        int peek = i + 1;
        while (peek < json.Length && (json[peek] == ' ' || json[peek] == '\t')) peek++;
        char closer = (c == '{') ? '}' : ']';
        if (peek < json.Length && json[peek] == closer)
        {
            // Don't indent empty objects/arrays
        }
        else
        {
            indent++;
            result.Append('\n');
            result.Append(' ', indent * 2);
        }
    }
}
"@

# ── 1. LOAD ──────────────────────────────────────────────────────
Write-Host "[1/5] Loading FL_FCIC.json..." -ForegroundColor Yellow
$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$serializer.MaxJsonLength = [Int32]::MaxValue
$raw = [System.IO.File]::ReadAllText($inputPath)
$j = $serializer.DeserializeObject($raw)
Write-Host "  Loaded. Bundles: $($j['bundles'].Count)"

# Helper: get config by name from a config array
function Get-Config($configs, $name) {
    foreach ($c in $configs) { if ($c['name'] -eq $name) { return $c } }
    return $null
}

# ── 2. BUILD MERGED PERSON QIF ──────────────────────────────────
Write-Host ""
Write-Host "[2/5] Building merged ENTITY_Person QIF..." -ForegroundColor Yellow

# Helper to create a CraftJS node as a clean .NET Dictionary
function New-Node($resolvedName, $displayName, $props, $isCanvas, $hidden, $nodeIds, $parent) {
    $node = New-Object 'System.Collections.Generic.Dictionary[string,object]'

    $typeDict = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    $typeDict.Add("resolvedName", $resolvedName)
    $node.Add("type", $typeDict)

    $node.Add("displayName", $displayName)
    $node.Add("props", $props)
    $node.Add("isCanvas", $isCanvas)
    $node.Add("hidden", $hidden)

    # nodes array
    $nodeArr = New-Object 'System.Collections.Generic.List[object]'
    foreach ($n in $nodeIds) { $nodeArr.Add($n) }
    $node.Add("nodes", $nodeArr)

    $linkedNodes = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    $node.Add("linkedNodes", $linkedNodes)

    if ($null -eq $parent) { $node.Add("parent", $null) }
    else { $node.Add("parent", [string]$parent) }

    return $node
}

function New-Props {
    return New-Object 'System.Collections.Generic.Dictionary[string,object]'
}

# Build a single layout variant for the merged Person form
function Build-MergedPersonLayout($addCADCard) {
    $layout = New-Object 'System.Collections.Generic.Dictionary[string,object]'

    # ROOT
    $p = New-Props
    $layout.Add("ROOT", (New-Node "Root" "Root" $p $true $false @("FORM_ROOT") $null))

    # FORM_ROOT
    $p = New-Props
    $p.Add("hidePageItems", $true)
    $p.Add("layout", "page")
    $layout.Add("FORM_ROOT", (New-Node "Form" "Form" $p $true $false @("ROOT_PAGE") "ROOT"))

    # ROOT_PAGE
    $p = New-Props
    $p.Add("title", "Page 1")
    $pageNodes = @("CARD_OPTIONS","CARD_DL_OLN","CARD_DL_NAM","CARD_DH_OLN","CARD_DH_NAM","CARD_DH_OPTS")
    if ($addCADCard) {
        $pageNodes = @("CONTEXT_INFO_CARD") + $pageNodes
    }
    $layout.Add("ROOT_PAGE", (New-Node "Page" "Page" $p $true $false $pageNodes "FORM_ROOT"))

    # ── CARD 1: Search Options (State + ImageIndicator) ──
    $p = New-Props; $p.Add("title", "Search Options")
    $layout.Add("CARD_OPTIONS", (New-Node "Card" "Card" $p $true $false @("OPTIONS_ROW1") "ROOT_PAGE"))

    $p = New-Props; $p.Add("templateColumns", "6 6")
    $layout.Add("OPTIONS_ROW1", (New-Node "Row" "Row" $p $true $false @("State_Input","ImageIndicator_Input") "CARD_OPTIONS"))

    $p = New-Props
    $p.Add("fieldId", "RegistrationState")
    $p.Add("label", "State")
    $p.Add("codeTypeSource", "NCIC")
    $p.Add("codeTypeCategory", "NCIC_STATE")
    $layout.Add("State_Input", (New-Node "FormSelect" "FormSelect" $p $false $false @() "OPTIONS_ROW1"))

    $p = New-Props
    $p.Add("fieldId", "ImageIndicator")
    $p.Add("label", "Image Indicator")
    $p.Add("initialValue", "Y")
    $p.Add("codeTypeSource", "NIBRS")
    $p.Add("codeTypeCategory", "YES_NO_UNKNOWN")
    $layout.Add("ImageIndicator_Input", (New-Node "FormSelect" "FormSelect" $p $false $false @() "OPTIONS_ROW1"))

    # ── CARD 2: Either...by OLN ──
    $p = New-Props; $p.Add("title", "Either...by OLN")
    $layout.Add("CARD_DL_OLN", (New-Node "Card" "Card" $p $true $false @("DL_OLN_ROW1") "ROOT_PAGE"))

    $p = New-Props; $p.Add("templateColumns", "12")
    $layout.Add("DL_OLN_ROW1", (New-Node "Row" "Row" $p $true $false @("OLN_Input") "CARD_DL_OLN"))

    $p = New-Props
    $p.Add("fieldId", "OperatorLicenseNumber")
    $p.Add("label", "License Number")
    $p.Add("maxLength", [int]20)
    $layout.Add("OLN_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DL_OLN_ROW1"))

    # ── CARD 3: Or...by NAM/DOB ──
    $p = New-Props; $p.Add("title", "Or...by NAM/DOB")
    $layout.Add("CARD_DL_NAM", (New-Node "Card" "Card" $p $true $false @("DL_NAM_ROW1","DL_NAM_ROW2") "ROOT_PAGE"))

    $p = New-Props; $p.Add("templateColumns", "6 6")
    $layout.Add("DL_NAM_ROW1", (New-Node "Row" "Row" $p $true $false @("NameFirst_Input","NameLast_Input") "CARD_DL_NAM"))

    $p = New-Props; $p.Add("fieldId", "NameFirst"); $p.Add("label", "First Name"); $p.Add("maxLength", [int]30)
    $layout.Add("NameFirst_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DL_NAM_ROW1"))

    $p = New-Props; $p.Add("fieldId", "NameLast"); $p.Add("label", "Last Name"); $p.Add("maxLength", [int]30)
    $layout.Add("NameLast_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DL_NAM_ROW1"))

    $p = New-Props; $p.Add("templateColumns", "3 3 3 3")
    $layout.Add("DL_NAM_ROW2", (New-Node "Row" "Row" $p $true $false @("NameMiddle_Input","NameSuffix_Input","BirthDate_Input","SexCode_Input") "CARD_DL_NAM"))

    $p = New-Props; $p.Add("fieldId", "NameMiddle"); $p.Add("label", "Middle Name"); $p.Add("maxLength", [int]30)
    $layout.Add("NameMiddle_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DL_NAM_ROW2"))

    $p = New-Props; $p.Add("fieldId", "NameSuffix"); $p.Add("label", "Suffix"); $p.Add("maxLength", [int]4)
    $layout.Add("NameSuffix_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DL_NAM_ROW2"))

    $p = New-Props; $p.Add("fieldId", "BirthDate"); $p.Add("label", "Date of Birth")
    $layout.Add("BirthDate_Input", (New-Node "FormDate" "FormDate" $p $false $false @() "DL_NAM_ROW2"))

    $p = New-Props
    $p.Add("fieldId", "SexCode")
    $p.Add("label", "Sex")
    $p.Add("codeTypeSource", "NIBRS")
    $p.Add("codeTypeCategory", "NIBRS_SEX")
    $layout.Add("SexCode_Input", (New-Node "FormSelect" "FormSelect" $p $false $false @() "DL_NAM_ROW2"))

    # ── CARD 4: DH - by OLN ──
    $p = New-Props; $p.Add("title", "DH - by OLN")
    $layout.Add("CARD_DH_OLN", (New-Node "Card" "Card" $p $true $false @("DH_OLN_ROW1") "ROOT_PAGE"))

    $p = New-Props; $p.Add("templateColumns", "12")
    $layout.Add("DH_OLN_ROW1", (New-Node "Row" "Row" $p $true $false @("OLN_DH_Input") "CARD_DH_OLN"))

    $p = New-Props
    $p.Add("fieldId", "OperatorLicenseNumberDH")
    $p.Add("label", "DH License Number")
    $p.Add("maxLength", [int]20)
    $layout.Add("OLN_DH_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_OLN_ROW1"))

    # ── CARD 5: DH - by NAM/DOB ──
    $p = New-Props; $p.Add("title", "DH - by NAM/DOB")
    $layout.Add("CARD_DH_NAM", (New-Node "Card" "Card" $p $true $false @("DH_NAM_ROW1","DH_NAM_ROW2") "ROOT_PAGE"))

    $p = New-Props; $p.Add("templateColumns", "6 6")
    $layout.Add("DH_NAM_ROW1", (New-Node "Row" "Row" $p $true $false @("NameFirstDH_Input","NameLastDH_Input") "CARD_DH_NAM"))

    $p = New-Props; $p.Add("fieldId", "NameFirstDH"); $p.Add("label", "First Name"); $p.Add("maxLength", [int]30)
    $layout.Add("NameFirstDH_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_NAM_ROW1"))

    $p = New-Props; $p.Add("fieldId", "NameLastDH"); $p.Add("label", "Last Name"); $p.Add("maxLength", [int]30)
    $layout.Add("NameLastDH_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_NAM_ROW1"))

    $p = New-Props; $p.Add("templateColumns", "3 3 3 3")
    $layout.Add("DH_NAM_ROW2", (New-Node "Row" "Row" $p $true $false @("NameMiddleDH_Input","NameSuffixDH_Input","BirthDateDH_Input","SexCodeDH_Input") "CARD_DH_NAM"))

    $p = New-Props; $p.Add("fieldId", "NameMiddleDH"); $p.Add("label", "Middle Name"); $p.Add("maxLength", [int]30)
    $layout.Add("NameMiddleDH_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_NAM_ROW2"))

    $p = New-Props; $p.Add("fieldId", "NameSuffixDH"); $p.Add("label", "Suffix"); $p.Add("maxLength", [int]4)
    $layout.Add("NameSuffixDH_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_NAM_ROW2"))

    $p = New-Props; $p.Add("fieldId", "BirthDateDH"); $p.Add("label", "Date of Birth")
    $layout.Add("BirthDateDH_Input", (New-Node "FormDate" "FormDate" $p $false $false @() "DH_NAM_ROW2"))

    $p = New-Props
    $p.Add("fieldId", "SexCodeDH")
    $p.Add("label", "DH Sex")
    $p.Add("codeTypeSource", "NIBRS")
    $p.Add("codeTypeCategory", "NIBRS_SEX")
    $layout.Add("SexCodeDH_Input", (New-Node "FormSelect" "FormSelect" $p $false $false @() "DH_NAM_ROW2"))

    # ── CARD 6: DH Options (PurposeCode + Attention) ──
    $p = New-Props; $p.Add("title", "DH Options")
    $layout.Add("CARD_DH_OPTS", (New-Node "Card" "Card" $p $true $false @("DH_OPTS_ROW1") "ROOT_PAGE"))

    $p = New-Props; $p.Add("templateColumns", "6 6")
    $layout.Add("DH_OPTS_ROW1", (New-Node "Row" "Row" $p $true $false @("PurposeCode_Input","Attention_Input") "CARD_DH_OPTS"))

    $p = New-Props; $p.Add("fieldId", "PurposeCode"); $p.Add("label", "Purpose Code"); $p.Add("maxLength", [int]1)
    $layout.Add("PurposeCode_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_OPTS_ROW1"))

    $p = New-Props; $p.Add("fieldId", "Attention"); $p.Add("label", "Attention"); $p.Add("maxLength", [int]30)
    $layout.Add("Attention_Input", (New-Node "FormInput" "FormInput" $p $false $false @() "DH_OPTS_ROW1"))

    # ── CAD context card (only for CAD/FR variants) ──
    if ($addCADCard) {
        $p = New-Props
        $layout.Add("CONTEXT_INFO_CARD", (New-Node "Card" "Card" $p $true $false @("ROW_0") "ROOT_PAGE"))

        $p = New-Props; $p.Add("templateColumns", "6 6")
        $layout.Add("ROW_0", (New-Node "Row" "Row" $p $true $false @("CadUnit_Input","CadEvent_Input") "CONTEXT_INFO_CARD"))

        $p = New-Props
        $p.Add("fieldId", "CAD_UNIT_SELECT_VALUE")
        $p.Add("label", "Requesting Unit")
        $p.Add("attributeTypeId", "CAD_UNIT_SELECT_VALUE")
        $layout.Add("CadUnit_Input", (New-Node "FormSelect" "FormSelect" $p $false $false @() "ROW_0"))

        $p = New-Props
        $p.Add("fieldId", "CAD_EVENT_SELECT_VALUE")
        $p.Add("label", "Event")
        $p.Add("attributeTypeId", "CAD_EVENT_SELECT_VALUE")
        $p.Add("performSearchAhead", $true)
        $layout.Add("CadEvent_Input", (New-Node "FormSelect" "FormSelect" $p $false $false @() "ROW_0"))
    }

    return $layout
}

# Build the merged config
$mergedPerson = New-Object 'System.Collections.Generic.Dictionary[string,object]'
$mergedPerson.Add("name", "ENTITY_Person")
$mergedPerson.Add("type", "QUERYINPUTFORM")
$mergedPerson.Add("description", "Person entity form -- merged (DL In-State/OOS + Driver History)")
$mergedPerson.Add("label", "Person")
$mergedPerson.Add("targetEntity", "Person")

$mergedLayout = New-Object 'System.Collections.Generic.Dictionary[string,object]'
$mergedLayout.Add("default", (Build-MergedPersonLayout $false))
$mergedLayout.Add("CAD_DISPATCH", (Build-MergedPersonLayout $true))
$mergedLayout.Add("FIRST_RESPONDER", (Build-MergedPersonLayout $true))
$mergedPerson.Add("layout", $mergedLayout)

Write-Host "  Built merged ENTITY_Person with 3 layout variants"
Write-Host "    default nodes: $($mergedLayout['default'].Count)"
Write-Host "    CAD nodes: $($mergedLayout['CAD_DISPATCH'].Count)"

# ── 3. UPDATE ENTITIES BUNDLE ───────────────────────────────────
Write-Host ""
Write-Host "[3/5] Updating ENTITIES bundle..." -ForegroundColor Yellow

$entities = $j['bundles'][0]
$oldConfigs = [System.Collections.ArrayList]@($entities['configurations'])
$newConfigs = New-Object 'System.Collections.Generic.List[object]'

# Add merged Person first
$newConfigs.Add($mergedPerson) | Out-Null

# Keep non-Person configs in original order
$removedNames = @("ENTITY_Person_InState","ENTITY_Person_OOS","ENTITY_Person_DH")
foreach ($c in $oldConfigs) {
    if ($c['name'] -notin $removedNames) {
        $newConfigs.Add($c) | Out-Null
    }
}

$entities['configurations'] = $newConfigs.ToArray()
Write-Host "  ENTITIES configs: $($newConfigs.Count) (was $($oldConfigs.Count))"
Write-Host "  Removed: $($removedNames -join ', ')"
Write-Host "  Added: ENTITY_Person"

# ── 4. FIX DLQ QIDM ────────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Fixing FL_FCIC_DriverLicenseQuery QIDM..." -ForegroundColor Yellow

$fcic = $j['bundles'][1]
$dlq = Get-Config $fcic['configurations'] "FL_FCIC_DriverLicenseQuery"

# Remove OOS-suffixed attributes
$oosAttrNames = @("SexCodeOOS","NameOOS","BirthDateOOS","OperatorLicenseNumberOOS","RegistrationStateOOS","AttentionOOS","PurposeCodeOOS")
$newAttrs = New-Object 'System.Collections.Generic.List[object]'
$removedCount = 0
foreach ($attr in $dlq['attributes']) {
    if ($attr['name'] -in $oosAttrNames) {
        $removedCount++
        Write-Host "  Removed attr: $($attr['name'])"
    } else {
        # Add codeTypeProvider to SexCode and State
        if ($attr['name'] -eq "SexCode") {
            $attr["codeTypeProvider"] = "NIBRS"
            Write-Host "  SexCode: codeTypeProvider=NIBRS (confirmed/kept)"
        }
        if ($attr['name'] -eq "State") {
            $sf = $attr['sourceField']
            $hasSF = $false
            if ($sf -is [System.Collections.IList]) {
                foreach ($s in $sf) { if ($s -eq "RegistrationState") { $hasSF = $true } }
            }
            if ($hasSF) {
                $attr["codeTypeProvider"] = "NCIC"
                Write-Host "  State: added codeTypeProvider=NCIC"
            }
        }
        $newAttrs.Add($attr) | Out-Null
    }
}
$dlq['attributes'] = $newAttrs.ToArray()
Write-Host "  Removed $removedCount OOS attributes, kept $($newAttrs.Count)"

# Update DLQ combinations: replace OOS field references with non-OOS equivalents
# Build entirely new combo objects to avoid PS/.NET dictionary assignment issues
$newDlqCombos = New-Object 'System.Collections.Generic.List[object]'
foreach ($combo in $dlq['combinations']) {
    $reqs = $combo['requirements']
    $setFields = $reqs['set']
    $anyFields = $reqs['any']

    # Check if this combo references OOS fields
    $hasOOS = $false
    foreach ($f in $setFields) { if ($f -match "OOS") { $hasOOS = $true; break } }
    if (-not $hasOOS) {
        foreach ($f in $anyFields) { if ($f -match "OOS") { $hasOOS = $true; break } }
    }

    if ($hasOOS) {
        # Map OOS fields to non-OOS equivalents
        $mappedSet = New-Object 'System.Collections.Generic.List[object]'
        foreach ($f in $setFields) {
            switch -Regex ($f) {
                "^BirthDateOOS$"             { $mappedSet.Add("BirthDate") | Out-Null }
                "^NameFirstOOS$"             { $mappedSet.Add("NameFirst") | Out-Null }
                "^NameLastOOS$"              { $mappedSet.Add("NameLast") | Out-Null }
                "^SexCodeOOS$"               { $mappedSet.Add("SexCode") | Out-Null }
                "^OperatorLicenseNumberOOS$" { $mappedSet.Add("OperatorLicenseNumber") | Out-Null }
                default                      { $mappedSet.Add($f) | Out-Null }
            }
        }
        $mappedAny = New-Object 'System.Collections.Generic.List[object]'
        foreach ($f in $anyFields) {
            switch -Regex ($f) {
                "^NameMiddleOOS$"  { $mappedAny.Add("NameMiddle") | Out-Null }
                "^NameSuffixOOS$"  { $mappedAny.Add("NameSuffix") | Out-Null }
                default {
                    if ($f -match "OOS$") {
                        $mapped = $f -replace "OOS$", ""
                        $mappedAny.Add($mapped) | Out-Null
                    } else {
                        $mappedAny.Add($f) | Out-Null
                    }
                }
            }
        }

        # Build brand new combo dict
        $newCombo = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        $newReqs = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        $newReqs.Add("set", $mappedSet.ToArray())
        $newReqs.Add("any", $mappedAny.ToArray())
        $newCombo.Add("requirements", $newReqs)

        $pfr = $combo['primaryFieldReference']
        if ($pfr -match "OOS$") { $pfr = $pfr -replace "OOS$", "" }
        $newCombo.Add("primaryFieldReference", $pfr)
        $newCombo.Add("keyReference", $combo['keyReference'])
        $newCombo.Add("state", $combo['state'])

        $newDlqCombos.Add($newCombo) | Out-Null
        Write-Host "  Rebuilt combo '$($combo['keyReference'])': mapped OOS->non-OOS fields"
    } else {
        $newDlqCombos.Add($combo) | Out-Null
    }
}
$dlq['combinations'] = $newDlqCombos.ToArray()
Write-Host "  DLQ: $($newDlqCombos.Count) combinations"

# ── 5. FIX DHQ QIDM ────────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Fixing FL_FCIC_DriverHistoryQuery QIDM..." -ForegroundColor Yellow

$dhq = Get-Config $fcic['configurations'] "FL_FCIC_DriverHistoryQuery"

# Remove OOS-suffixed attributes
$oosAttrNamesDHQ = @("OperatorLicenseNumberOOS","NameOOS","BirthDateOOS","SexCodeOOS","RegistrationStateOOS","AttentionOOS","PurposeCodeOOS")
$newAttrsDHQ = New-Object 'System.Collections.Generic.List[object]'
$removedCountDHQ = 0
foreach ($attr in $dhq['attributes']) {
    if ($attr['name'] -in $oosAttrNamesDHQ) {
        $removedCountDHQ++
        Write-Host "  Removed attr: $($attr['name'])"
    } else {
        # Ensure codeTypeProvider
        if ($attr['name'] -eq "SexCode") {
            if (-not $attr.ContainsKey("codeTypeProvider")) {
                $attr["codeTypeProvider"] = "NIBRS"
            }
            Write-Host "  SexCode (DH): codeTypeProvider=$($attr['codeTypeProvider'])"
        }
        if ($attr['name'] -eq "State") {
            $sf = $attr['sourceField']
            $hasSF = $false
            if ($sf -is [System.Collections.IList]) {
                foreach ($s in $sf) { if ($s -eq "RegistrationState") { $hasSF = $true } }
            }
            if ($hasSF) {
                $attr["codeTypeProvider"] = "NCIC"
                Write-Host "  State: added codeTypeProvider=NCIC"
            }
        }
        $newAttrsDHQ.Add($attr) | Out-Null
    }
}
$dhq['attributes'] = $newAttrsDHQ.ToArray()
Write-Host "  Removed $removedCountDHQ OOS attributes, kept $($newAttrsDHQ.Count)"

# DHQ combinations: already reference DH-suffixed fields
Write-Host "  DHQ combinations: $($dhq['combinations'].Count) (unchanged - already use DH fields)"

# ── SERIALIZE AND SAVE ──────────────────────────────────────────
Write-Host ""
Write-Host "Serializing and saving..." -ForegroundColor Yellow

$cleanSerializer = New-Object CleanJsonSerializer
$output = $cleanSerializer.Serialize($j)

# Pretty-print
$formatted = [CleanJsonSerializer]::Format($output)
[System.IO.File]::WriteAllText($outputPath, $formatted, [System.Text.Encoding]::UTF8)
$fileSize = (Get-Item $outputPath).Length
Write-Host "  Saved to: $outputPath"
Write-Host "  File size: $([Math]::Round($fileSize/1024, 1)) KB"

# ── VALIDATION ──────────────────────────────────────────────────
Write-Host ""
Write-Host "=== VALIDATION ===" -ForegroundColor Cyan

$errors = @()

# Re-parse to validate
$reread = [System.IO.File]::ReadAllText($outputPath)
try {
    $v = $serializer.DeserializeObject($reread)
    Write-Host "[PASS] JSON is valid" -ForegroundColor Green
} catch {
    $errors += "JSON PARSE ERROR: $_"
    Write-Host "[FAIL] JSON parse error: $_" -ForegroundColor Red
}

# Validate bundles
$vEntities = $v['bundles'][0]
$vFcic = $v['bundles'][1]
$vRms = $v['bundles'][2]

Write-Host ""
Write-Host "Bundle counts:"
Write-Host "  ENTITIES: $($vEntities['configurations'].Count) configs"
Write-Host "  FL_FCIC:  $($vFcic['configurations'].Count) configs"
Write-Host "  RMS:      $($vRms['configurations'].Count) configs"

# Check ENTITY_Person exists
$vPerson = Get-Config $vEntities['configurations'] "ENTITY_Person"
if ($vPerson) {
    Write-Host "[PASS] ENTITY_Person exists" -ForegroundColor Green
    Write-Host "  targetEntity: $($vPerson['targetEntity'])"
    Write-Host "  layout variants: $($vPerson['layout'].Keys -join ', ')"

    foreach ($variant in @("default","CAD_DISPATCH","FIRST_RESPONDER")) {
        $lay = $vPerson['layout'][$variant]
        if ($lay) {
            Write-Host "  [$variant] node count: $($lay.Count)" -ForegroundColor Gray
        } else {
            $errors += "Missing layout variant: $variant"
            Write-Host "[FAIL] Missing layout variant: $variant" -ForegroundColor Red
        }
    }
} else {
    $errors += "ENTITY_Person not found"
    Write-Host "[FAIL] ENTITY_Person not found" -ForegroundColor Red
}

# Check old Person forms are gone
foreach ($oldName in @("ENTITY_Person_InState","ENTITY_Person_OOS","ENTITY_Person_DH")) {
    $old = Get-Config $vEntities['configurations'] $oldName
    if ($old) {
        $errors += "$oldName still exists"
        Write-Host "[FAIL] $oldName still exists" -ForegroundColor Red
    } else {
        Write-Host "[PASS] $oldName removed" -ForegroundColor Green
    }
}

# DLQ validation
$vDlq = Get-Config $vFcic['configurations'] "FL_FCIC_DriverLicenseQuery"
Write-Host ""
Write-Host "DLQ validation:"

$dlqTargetFields = @{}
$dlqDupErrors = 0
foreach ($attr in $vDlq['attributes']) {
    $tf = $attr['targetField']
    $name = $attr['name']
    if ($name -match "OOS$") {
        $errors += "DLQ still has OOS attr: $name"
        Write-Host "[FAIL] OOS attr still present: $name" -ForegroundColor Red
    }
    if ($dlqTargetFields.ContainsKey($tf)) {
        $dlqDupErrors++
        $errors += "DLQ duplicate targetField: $tf (attrs: $($dlqTargetFields[$tf]) and $name)"
        Write-Host "[FAIL] Duplicate targetField '$tf': $($dlqTargetFields[$tf]) vs $name" -ForegroundColor Red
    } else {
        $dlqTargetFields[$tf] = $name
    }
}
if ($dlqDupErrors -eq 0) {
    Write-Host "[PASS] No duplicate targetFields in DLQ ($($vDlq['attributes'].Count) attrs)" -ForegroundColor Green
} else {
    Write-Host "[INFO] DLQ has $dlqDupErrors duplicate targetField(s)" -ForegroundColor Yellow
}

# Check codeTypeProvider on DLQ
foreach ($attr in $vDlq['attributes']) {
    if ($attr['name'] -eq "SexCode") {
        if ($attr['codeTypeProvider'] -eq "NIBRS") {
            Write-Host "[PASS] DLQ SexCode has codeTypeProvider=NIBRS" -ForegroundColor Green
        } else {
            $errors += "DLQ SexCode missing codeTypeProvider=NIBRS"
            Write-Host "[FAIL] DLQ SexCode codeTypeProvider=$($attr['codeTypeProvider'])" -ForegroundColor Red
        }
    }
    if ($attr['name'] -eq "State") {
        if ($attr['codeTypeProvider'] -eq "NCIC") {
            Write-Host "[PASS] DLQ State has codeTypeProvider=NCIC" -ForegroundColor Green
        } else {
            $errors += "DLQ State missing codeTypeProvider=NCIC"
            Write-Host "[FAIL] DLQ State codeTypeProvider=$($attr['codeTypeProvider'])" -ForegroundColor Red
        }
    }
}

# Check DLQ combos have no OOS field refs
$dlqComboOOS = 0
foreach ($combo in $vDlq['combinations']) {
    $kr = $combo['keyReference']
    foreach ($f in $combo['requirements']['set']) {
        if ($f -match "OOS") {
            $dlqComboOOS++
            $errors += "DLQ combo '$kr' set has OOS field: $f"
            Write-Host "[FAIL] DLQ combo '$kr' set has OOS field: $f" -ForegroundColor Red
        }
    }
    foreach ($f in $combo['requirements']['any']) {
        if ($f -match "OOS") {
            $dlqComboOOS++
            $errors += "DLQ combo '$kr' any has OOS field: $f"
            Write-Host "[FAIL] DLQ combo '$kr' any has OOS field: $f" -ForegroundColor Red
        }
    }
}
if ($dlqComboOOS -eq 0) {
    Write-Host "[PASS] DLQ combos: no OOS field references" -ForegroundColor Green
}

# DHQ validation
$vDhq = Get-Config $vFcic['configurations'] "FL_FCIC_DriverHistoryQuery"
Write-Host ""
Write-Host "DHQ validation:"

# DHQ allows combo-multiplexed duplicates for Attention and PurposeCode (by design)
$dhqAllowedDupTargets = @("Attention","PurposeCode")
$dhqTargetFields = @{}
$dhqDupErrors = 0
$dhqDupWarnings = 0
foreach ($attr in $vDhq['attributes']) {
    $tf = $attr['targetField']
    $name = $attr['name']
    if ($name -match "OOS$") {
        $errors += "DHQ still has OOS attr: $name"
        Write-Host "[FAIL] OOS attr still present: $name" -ForegroundColor Red
    }
    if ($dhqTargetFields.ContainsKey($tf)) {
        if ($tf -in $dhqAllowedDupTargets) {
            $dhqDupWarnings++
            Write-Host "[WARN] DHQ expected combo-multiplexed duplicate targetField '$tf': $($dhqTargetFields[$tf]) vs $name (by design)" -ForegroundColor Yellow
        } else {
            $dhqDupErrors++
            $errors += "DHQ unexpected duplicate targetField: $tf (attrs: $($dhqTargetFields[$tf]) and $name)"
            Write-Host "[FAIL] Unexpected duplicate targetField '$tf': $($dhqTargetFields[$tf]) vs $name" -ForegroundColor Red
        }
    } else {
        $dhqTargetFields[$tf] = $name
    }
}
if ($dhqDupErrors -eq 0) {
    Write-Host "[PASS] No unexpected duplicate targetFields in DHQ ($($vDhq['attributes'].Count) attrs, $dhqDupWarnings expected dups)" -ForegroundColor Green
} else {
    Write-Host "[FAIL] DHQ has $dhqDupErrors unexpected duplicate targetField(s)" -ForegroundColor Red
}

# Check codeTypeProvider on DHQ
foreach ($attr in $vDhq['attributes']) {
    if ($attr['name'] -eq "SexCode") {
        if ($attr['codeTypeProvider'] -eq "NIBRS") {
            Write-Host "[PASS] DHQ SexCode has codeTypeProvider=NIBRS" -ForegroundColor Green
        } else {
            $errors += "DHQ SexCode missing codeTypeProvider=NIBRS"
            Write-Host "[FAIL] DHQ SexCode codeTypeProvider=$($attr['codeTypeProvider'])" -ForegroundColor Red
        }
    }
    if ($attr['name'] -eq "State") {
        if ($attr['codeTypeProvider'] -eq "NCIC") {
            Write-Host "[PASS] DHQ State has codeTypeProvider=NCIC" -ForegroundColor Green
        } else {
            $errors += "DHQ State missing codeTypeProvider=NCIC"
            Write-Host "[FAIL] DHQ State codeTypeProvider=$($attr['codeTypeProvider'])" -ForegroundColor Red
        }
    }
}

# Verify other ENTITY configs are unchanged
Write-Host ""
Write-Host "Unchanged configs check:"
foreach ($name in @("ENTITY_Vehicle_InState","ENTITY_Vehicle_OOS","ENTITY_Firearm","ENTITY_Article","ENTITY_Boat")) {
    $vc = Get-Config $vEntities['configurations'] $name
    if ($vc) { Write-Host "[PASS] $name present" -ForegroundColor Green }
    else { $errors += "$name missing"; Write-Host "[FAIL] $name missing" -ForegroundColor Red }
}

# RMS bundle unchanged
if ($vRms['configurations'].Count -eq 6) {
    Write-Host "[PASS] RMS bundle: 6 configs (unchanged)" -ForegroundColor Green
} else {
    $errors += "RMS bundle config count changed to $($vRms['configurations'].Count)"
    Write-Host "[FAIL] RMS bundle: $($vRms['configurations'].Count) configs (expected 6)" -ForegroundColor Red
}

# List DLQ attributes for review
Write-Host ""
Write-Host "=== DLQ Final Attributes ===" -ForegroundColor Gray
foreach ($attr in $vDlq['attributes']) {
    $extra = ""
    if ($attr.ContainsKey('codeTypeProvider')) { $extra = " codeTypeProvider=$($attr['codeTypeProvider'])" }
    Write-Host "  $($attr['name']): sourceField=$($attr['sourceField'] -join ',') -> targetField=$($attr['targetField'])$extra"
}

Write-Host ""
Write-Host "=== DHQ Final Attributes ===" -ForegroundColor Gray
foreach ($attr in $vDhq['attributes']) {
    $extra = ""
    if ($attr.ContainsKey('codeTypeProvider')) { $extra = " codeTypeProvider=$($attr['codeTypeProvider'])" }
    Write-Host "  $($attr['name']): sourceField=$($attr['sourceField'] -join ',') -> targetField=$($attr['targetField'])$extra"
}

Write-Host ""
Write-Host "=== DLQ Final Combinations ===" -ForegroundColor Gray
foreach ($combo in $vDlq['combinations']) {
    Write-Host "  $($combo['keyReference']): set=[$($combo['requirements']['set'] -join ',')] any=[$($combo['requirements']['any'] -join ',')]"
}

Write-Host ""
Write-Host "=== DHQ Final Combinations ===" -ForegroundColor Gray
foreach ($combo in $vDhq['combinations']) {
    Write-Host "  $($combo['keyReference']): set=[$($combo['requirements']['set'] -join ',')] any=[$($combo['requirements']['any'] -join ',')]"
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "ALL VALIDATIONS PASSED" -ForegroundColor Green
} else {
    Write-Host "$($errors.Count) ERRORS:" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  - $e" -ForegroundColor Red }
}
Write-Host ""
Write-Host "Output: $outputPath"
