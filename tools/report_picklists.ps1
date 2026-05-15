# report_picklists.ps1
# Scans a ConnectCIC provider JSON and reports all dropdown/picklist fields
# and their code type configuration (codeTypeCategory/codeTypeSource,
# attributeTypeId/codeTypeProvider) from both QIF layouts and QRDM inbound mappings.
#
# Usage: .\report_picklists.ps1 -Path <provider.json> [-OutFile <path>]

param(
    [Parameter(Mandatory)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Path)) { Write-Error "File not found: $Path"; return }

$json = Get-Content $Path -Raw -Encoding UTF8
$data = $json | ConvertFrom-Json

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
$lines = @()
$lines += "=" * 70
$lines += "  PICKLIST / DROPDOWN REPORT: $fileName"
$lines += "  Source: $(Split-Path $Path -Leaf)"
$lines += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$lines += "=" * 70
$lines += ""

# --- SECTION 1: QIF FORM DROPDOWNS ---
$lines += "SECTION 1: QIF FORM DROPDOWNS (FormSelect fields)"
$lines += "-" * 50
$lines += ""

$formFields = @()

foreach ($bundle in $data.bundles) {
    foreach ($config in $bundle.configurations) {
        if ($config.type -ne "QUERYINPUTFORM") { continue }
        $entity = $config.targetEntity
        $qifName = $config.name

        # Only scan default variant (all variants have same fields)
        $layoutObj = $null
        try { $layoutObj = $config.layout.default } catch { }
        if (-not $layoutObj) {
            try { $layoutObj = $config.layout.PSObject.Properties['default'].Value } catch { continue }
        }
        if (-not $layoutObj) { continue }

        # Iterate all nodes in the flat layout object
        foreach ($prop in $layoutObj.PSObject.Properties) {
            $node = $prop.Value
            if (-not $node) { continue }
            $resolved = $null
            try { $resolved = $node.type.resolvedName } catch { continue }
            if ($resolved -ne "FormSelect") { continue }

            $p = $node.props
            if (-not $p) { continue }
            $fieldId = $null
            try { $fieldId = $p.fieldId } catch { }
            if (-not $fieldId) { continue }

            $ctCat = ""; $ctSrc = ""; $atId = ""; $ctProv = ""; $lbl = ""; $init = ""
            try { $ctCat  = $p.codeTypeCategory } catch { }
            try { $ctSrc  = $p.codeTypeSource   } catch { }
            try { $atId   = $p.attributeTypeId   } catch { }
            try { $ctProv = $p.codeTypeProvider  } catch { }
            try { $lbl    = $p.label             } catch { }
            try { $init   = $p.initialValue      } catch { }

            $rec = [ordered]@{
                Entity           = $entity
                FieldId          = $fieldId
                Label            = if ($lbl) { $lbl } else { "" }
                CodeTypeCategory = if ($ctCat)  { $ctCat }  else { "" }
                CodeTypeSource   = if ($ctSrc)  { $ctSrc }  else { "" }
                AttributeTypeId  = if ($atId)   { $atId }   else { "" }
                CodeTypeProvider = if ($ctProv)  { $ctProv } else { "" }
                InitialValue     = if ($init)   { $init }   else { "" }
            }

            $existing = $formFields | Where-Object { $_.Entity -eq $entity -and $_.FieldId -eq $fieldId }
            if (-not $existing) { $formFields += $rec }
        }
    }
}

$grouped = $formFields | Group-Object { $_.Entity }
foreach ($g in ($grouped | Sort-Object Name)) {
    $lines += "  Entity: $($g.Name)"
    foreach ($f in ($g.Group | Sort-Object { $_.FieldId })) {
        $configStr = ""
        if ($f.AttributeTypeId) {
            $configStr = "attributeTypeId=$($f.AttributeTypeId)"
            if ($f.CodeTypeProvider) { $configStr += ", codeTypeProvider=$($f.CodeTypeProvider)" }
        }
        if ($f.CodeTypeCategory) {
            if ($configStr) { $configStr += " | " }
            $configStr += "codeTypeCategory=$($f.CodeTypeCategory), codeTypeSource=$($f.CodeTypeSource)"
        }
        if (-not $configStr) { $configStr = "(no code type config)" }

        $labelStr = if ($f.Label) { " [$($f.Label)]" } else { "" }
        $initStr = if ($f.InitialValue) { " (default=$($f.InitialValue))" } else { "" }

        $lines += "    $($f.FieldId)$labelStr$initStr"
        $lines += "      Config: $configStr"
    }
    $lines += ""
}

if ($formFields.Count -eq 0) {
    $lines += "  (no FormSelect fields found)"
    $lines += ""
}

# --- SECTION 2: QRDM INBOUND CODE TYPES ---
$lines += "SECTION 2: QRDM INBOUND TRANSLATION CODE TYPES"
$lines += "-" * 50
$lines += ""

$qrdmFields = @()

foreach ($bundle in $data.bundles) {
    foreach ($config in $bundle.configurations) {
        $isQrdm = $false
        try { $isQrdm = ($config.type -eq "QUERYRESULTDATAMAPPING") } catch { }
        # Also check provider bundle configs that have codeType on attributes
        if (-not $config.attributes) { continue }

        $configName = if ($config.name) { $config.name } else { "unknown" }
        $configType = if ($config.type) { $config.type } else { "unknown" }

        foreach ($attr in $config.attributes) {
            $hasCt = $false
            $ctSrc = ""; $ctCat = ""; $attrType = ""; $ctProv = ""
            try { $ctSrc = $attr.codeTypeSource } catch { }
            try { $ctCat = $attr.codeTypeCategory } catch { }
            try { $attrType = $attr.attributeType } catch { }
            try { $ctProv = $attr.codeTypeProvider } catch { }

            if ($ctSrc -or $ctCat -or $attrType -or $ctProv) { $hasCt = $true }
            if (-not $hasCt) { continue }

            $rec = [ordered]@{
                ConfigName       = $configName
                ConfigType       = $configType
                AttrName         = if ($attr.name) { $attr.name } else { "" }
                TargetField      = if ($attr.targetField) { $attr.targetField } else { "" }
                CodeTypeCategory = if ($ctCat) { $ctCat } else { "" }
                CodeTypeSource   = if ($ctSrc) { $ctSrc } else { "" }
                AttributeType    = if ($attrType) { $attrType } else { "" }
                CodeTypeProvider = if ($ctProv) { $ctProv } else { "" }
            }
            $qrdmFields += $rec
        }
    }
}

$qrdmGrouped = $qrdmFields | Group-Object { $_.ConfigType }
foreach ($g in ($qrdmGrouped | Sort-Object Name)) {
    $lines += "  Config Type: $($g.Name)"
    $byConfig = $g.Group | Group-Object { $_.ConfigName }
    foreach ($c in $byConfig) {
        $lines += "    Config: $($c.Name)"
        foreach ($a in $c.Group) {
            $configStr = ""
            if ($a.AttributeType) { $configStr += "attributeType=$($a.AttributeType)" }
            if ($a.CodeTypeProvider) {
                if ($configStr) { $configStr += ", " }
                $configStr += "codeTypeProvider=$($a.CodeTypeProvider)"
            }
            if ($a.CodeTypeCategory) {
                if ($configStr) { $configStr += " | " }
                $configStr += "codeTypeCategory=$($a.CodeTypeCategory), codeTypeSource=$($a.CodeTypeSource)"
            }
            if ($a.CodeTypeSource -and -not $a.CodeTypeCategory) {
                if ($configStr) { $configStr += " | " }
                $configStr += "codeTypeSource=$($a.CodeTypeSource)"
            }
            $lines += "      $($a.AttrName) -> $($a.TargetField)"
            $lines += "        $configStr"
        }
    }
    $lines += ""
}

if ($qrdmFields.Count -eq 0) {
    $lines += "  (no code type attributes found)"
    $lines += ""
}

# --- SECTION 3: QIDM OUTBOUND CODE TYPES ---
$lines += "SECTION 3: QIDM OUTBOUND CODE TYPES (codeTypeProvider on QIDM attrs)"
$lines += "-" * 50
$lines += ""

$qidmCt = @()

foreach ($bundle in $data.bundles) {
    foreach ($config in $bundle.configurations) {
        if ($config.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $config.attributes) { continue }

        foreach ($attr in $config.attributes) {
            $ctProv = ""
            try { $ctProv = $attr.codeTypeProvider } catch { }
            if (-not $ctProv) { continue }

            $lines += "  QIDM: $($config.name)"
            $lines += "    $($attr.name) -> targetField=$($attr.targetField), codeTypeProvider=$ctProv"
            $lines += ""
        }
    }
}

# --- SUMMARY ---
$lines += "=" * 70
$lines += "  SUMMARY"
$lines += "=" * 70

$lines += "  Form dropdowns: $($formFields.Count)"
$lines += "  QRDM code type attrs: $($qrdmFields.Count)"
$lines += ""

# Output
$report = $lines -join "`n"
Write-Host $report

if ($OutFile) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, $report, $utf8NoBom)
    Write-Host "`nSaved to: $OutFile" -ForegroundColor Green
}
