<#
  render_html.ps1 -- Generate a self-contained HTML layout report for a provider JSON
  Shows QIF layouts with cards/rows/fields, QIDM attributes + combinations, and RMS QIDMs.
  Fields are color-coded by type with full attribute/codeType descriptors.

  Usage: .\render_html.ps1 -Path <provider.json> -OutFile <output.html>
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$OutFile
)

$ErrorActionPreference = "Stop"

$resolved = Resolve-Path $Path
$jsonName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
$jsonFile = Split-Path $resolved -Leaf
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

$data = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$entities = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$providerBundle = $data.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' }
$rmsBundle = $data.bundles | Where-Object { $_.name -eq 'RMS' }

if (-not $entities) { Write-Error "No ENTITIES bundle found"; exit 1 }

$qifs = $entities.configurations

function Esc($s) { if ($s) { [System.Web.HttpUtility]::HtmlEncode($s) } else { '' } }

function Get-FieldTypeClass($type) {
    switch -Wildcard ($type) {
        'SelectInput'        { 'field-dropdown' }
        'FormSelect'         { 'field-dropdown' }
        'SelectHistoryInput' { 'field-dropdown' }
        'TextInput'          { 'field-text' }
        'FormInput'          { 'field-text' }
        'FormDateInput'      { 'field-date' }
        'CheckboxInput'      { 'field-check' }
        'HiddenInput'        { 'field-hidden' }
        default              { 'field-other' }
    }
}

function Get-FieldTypeName($type) {
    switch -Wildcard ($type) {
        'SelectInput'        { 'Dropdown' }
        'FormSelect'         { 'Dropdown' }
        'SelectHistoryInput' { 'Dropdown + History' }
        'TextInput'          { 'Text Input' }
        'FormInput'          { 'Text Input' }
        'FormDateInput'      { 'Date Input' }
        'CheckboxInput'      { 'Checkbox' }
        'HiddenInput'        { 'Hidden' }
        default              { $type }
    }
}

function Build-FieldHtml($node) {
    $p = $node.props
    $type = $node.type.resolvedName
    $cls = Get-FieldTypeClass $type
    $typeName = Get-FieldTypeName $type
    $fieldId = if ($p.fieldId) { $p.fieldId } else { 'unknown' }
    $label = if ($p.label) { $p.label } else { $fieldId }

    $tags = @()
    if ($p.attributeTypeId) {
        $tags += "<span class='tag tag-attr'>attributeTypeId=$(Esc $p.attributeTypeId)</span>"
    }
    if ($p.codeTypeCategory) {
        $tags += "<span class='tag tag-code'>codeTypeCategory=$(Esc $p.codeTypeCategory)</span>"
    }
    if ($p.codeTypeSource) {
        $tags += "<span class='tag tag-code'>codeTypeSource=$(Esc $p.codeTypeSource)</span>"
    }
    if ($p.codeTypeProvider) {
        $tags += "<span class='tag tag-prov'>codeTypeProvider=$(Esc $p.codeTypeProvider)</span>"
    }
    if ($p.maxLength) {
        $tags += "<span class='tag tag-meta'>maxLength=$(Esc $p.maxLength)</span>"
    }
    if ($p.initialValue) {
        $tags += "<span class='tag tag-default'>default=$(Esc $p.initialValue)</span>"
    }
    if ($p.hidden -eq $true) {
        $tags += "<span class='tag tag-warn'>HIDDEN</span>"
    }
    if ($p.autoSelect -eq $true) {
        $tags += "<span class='tag tag-meta'>autoSelect</span>"
    }

    $tagHtml = if ($tags.Count -gt 0) { "<div class='field-tags'>$($tags -join ' ')</div>" } else { '' }

    return @"
<div class='field $cls'>
  <div class='field-header'>
    <span class='field-id'>$(Esc $fieldId)</span>
    <span class='field-type'>$typeName</span>
  </div>
  $tagHtml
</div>
"@
}

function Build-NodeHtml($layout, $nodeId) {
    $node = $layout.$nodeId
    if (-not $node) { return '' }
    $type = $node.type.resolvedName

    $childHtml = ''
    if ($node.nodes) {
        foreach ($child in $node.nodes) {
            $childHtml += Build-NodeHtml $layout $child
        }
    }

    switch ($type) {
        'Card' {
            $label = if ($node.props.label) { $node.props.label } else { $nodeId }
            return "<div class='card'><div class='card-header'>$(Esc $label)</div><div class='card-body'>$childHtml</div></div>"
        }
        { $_ -in 'Row','CadRow','FrRow' } {
            $cols = if ($node.props.templateColumns) { $node.props.templateColumns -join ', ' } else { '' }
            $colLabel = if ($cols) { "<span class='row-cols'>columns: $cols</span>" } else { '' }
            return "<div class='row-container'>${colLabel}${childHtml}</div>"
        }
        { $_ -in 'RootPage','FormRoot','Container' } {
            return $childHtml
        }
        default {
            return Build-FieldHtml $node
        }
    }
}

function Build-LayoutHtml($layout) {
    $members = ($layout | Get-Member -MemberType NoteProperty).Name
    $root = $members | Where-Object { $_ -eq 'ROOT' }
    if (-not $root) { $root = $members[0] }

    $rootNode = $layout.$root
    $formRoot = if ($rootNode.nodes) { $rootNode.nodes[0] } else { $null }
    if ($formRoot -and $layout.$formRoot) {
        $pageNode = $layout.$formRoot
        if ($pageNode.nodes) {
            $rootPage = $pageNode.nodes[0]
            if ($rootPage -and $layout.$rootPage -and $layout.$rootPage.nodes) {
                $html = ''
                foreach ($cardId in $layout.$rootPage.nodes) {
                    $html += Build-NodeHtml $layout $cardId
                }
                return $html
            }
        }
    }
    return Build-NodeHtml $layout $root
}

# --- Build QIDM HTML ---
function Build-QidmHtml($provBundle, $qidmName) {
    if (-not $provBundle) { return '' }
    $qidm = $provBundle.configurations | Where-Object { $_.name -eq $qidmName }
    if (-not $qidm) { return '' }

    $html = "<div class='qidm'><div class='qidm-header'>QIDM: $(Esc $qidmName)</div>"

    if ($qidm.attributes) {
        $html += "<table class='qidm-table'><thead><tr><th>Source Field</th><th>Target Field</th><th>Properties</th></tr></thead><tbody>"
        foreach ($a in $qidm.attributes) {
            $props = @()
            if ($a.useAttributeId -eq $true) { $props += "<span class='tag tag-attr'>useAttributeId</span>" }
            if ($a.codeTypeProvider) { $props += "<span class='tag tag-prov'>codeTypeProvider=$(Esc $a.codeTypeProvider)</span>" }
            if ($a.rule -and $a.rule.function) {
                $rhName = Esc $a.rule.function
                $rhArgs = ''
                if ($a.rule.arguments) {
                    $rhArgs = ($a.rule.arguments | ForEach-Object { Esc "$_" }) -join ', '
                    $rhArgs = " ($rhArgs)"
                }
                $props += "<span class='tag tag-rule'>$rhName$rhArgs</span>"
            }
            if ($a.fallbackRule -and $a.fallbackRule.function) {
                $fbName = Esc $a.fallbackRule.function
                $fbArgs = ''
                if ($a.fallbackRule.arguments) {
                    $fbArgs = ($a.fallbackRule.arguments | ForEach-Object { Esc "$_" }) -join ', '
                    $fbArgs = " ($fbArgs)"
                }
                $props += "<span class='tag tag-rule'>fallback: $fbName$fbArgs</span>"
            }
            $propStr = if ($props.Count -gt 0) { $props -join ' ' } else { '-' }
            $srcField = if ($a.sourceField -is [array]) { ($a.sourceField -join ', ') } else { "$($a.sourceField)" }
            $html += "<tr><td class='mono'>$(Esc $srcField)</td><td class='mono'>$(Esc $a.targetField)</td><td>$propStr</td></tr>"
        }
        $html += "</tbody></table>"
    }

    if ($qidm.combinations) {
        $html += "<div class='combo-header'>Combinations (priority order):</div><div class='combo-list'>"
        $idx = 1
        foreach ($c in $qidm.combinations) {
            $kr = if ($c.keyReference) { $c.keyReference } else { '(none)' }
            $setFields = if ($c.requirements.set) { ($c.requirements.set | ForEach-Object { "<span class='combo-field combo-set'>$(Esc $_)</span>" }) -join ' ' } else { '<em>none</em>' }
            $anyFields = if ($c.requirements.any) { ($c.requirements.any | ForEach-Object { "<span class='combo-field combo-any'>$(Esc $_)</span>" }) -join ' ' } else { '<em>none</em>' }
            $html += "<div class='combo'><span class='combo-idx'>#$idx</span> <strong>$(Esc $kr)</strong><div class='combo-detail'>set (required): $setFields</div><div class='combo-detail'>any (optional): $anyFields</div></div>"
            $idx++
        }
        $html += "</div>"
    }

    $html += "</div>"
    return $html
}

function Build-RmsHtml($rmsBundle) {
    if (-not $rmsBundle) { return '' }
    $rmsQidms = $rmsBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' }
    if (-not $rmsQidms -or $rmsQidms.Count -eq 0) { return '' }

    $html = "<div class='entity-section'><h2>RMS QIDMs</h2>"
    foreach ($rq in $rmsQidms) {
        $html += "<div class='qidm'><div class='qidm-header'>$(Esc $rq.name)</div>"
        if ($rq.attributes) {
            $html += "<table class='qidm-table'><thead><tr><th>Source Field</th><th>Target Field</th><th>Properties</th></tr></thead><tbody>"
            foreach ($a in $rq.attributes) {
                $props = @()
                if ($a.useAttributeId -eq $true) { $props += "<span class='tag tag-attr'>useAttributeId</span>" }
                if ($a.rule -and $a.rule.function) {
                    $rhName = Esc $a.rule.function
                    $rhArgs = ''
                    if ($a.rule.arguments) {
                        $rhArgs = ($a.rule.arguments | ForEach-Object { Esc "$_" }) -join ', '
                        $rhArgs = " ($rhArgs)"
                    }
                    $props += "<span class='tag tag-rule'>$rhName$rhArgs</span>"
                }
                if ($a.fallbackRule -and $a.fallbackRule.function) {
                    $fbName = Esc $a.fallbackRule.function
                    $fbArgs = ''
                    if ($a.fallbackRule.arguments) {
                        $fbArgs = ($a.fallbackRule.arguments | ForEach-Object { Esc "$_" }) -join ', '
                        $fbArgs = " ($fbArgs)"
                    }
                    $props += "<span class='tag tag-rule'>fallback: $fbName$fbArgs</span>"
                }
                $propStr = if ($props.Count -gt 0) { $props -join ' ' } else { '-' }
                $srcField = if ($a.sourceField -is [array]) { ($a.sourceField -join ', ') } else { "$($a.sourceField)" }
                $html += "<tr><td class='mono'>$(Esc $srcField)</td><td class='mono'>$(Esc $a.targetField)</td><td>$propStr</td></tr>"
            }
            $html += "</tbody></table>"
        }
        $html += "</div>"
    }
    $html += "</div>"
    return $html
}

# --- Assemble page ---
$entitySections = ''

foreach ($qif in $qifs) {
    $entity = $qif.targetEntity

    $cards = 0; $fields = 0
    $layout = $qif.layout.default
    if ($layout) {
        $members = ($layout | Get-Member -MemberType NoteProperty).Name
        foreach ($m in $members) {
            $n = $layout.$m
            if ($n.type.resolvedName -eq 'Card') { $cards++ }
            if ($n.type.resolvedName -match 'Input$|Select$') { $fields++ }
        }
    }

    $entitySections += "<div class='entity-section'>"
    $entitySections += "<h2>$(Esc $entity) <span class='entity-meta'>$cards card(s), $fields field(s)</span></h2>"

    if ($layout) {
        $entitySections += "<h3>Form Layout</h3>"
        $entitySections += Build-LayoutHtml $layout
    }

    if ($providerBundle) {
        $entityQidms = @($providerBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.targetEntity -eq $entity })
        foreach ($eq in $entityQidms) {
            $entitySections += Build-QidmHtml $providerBundle $eq.name
        }
    }

    $entitySections += "</div>"
}

$entitySections += Build-RmsHtml $rmsBundle

# --- Rule Handler Summary (all 4 property paths) ---
$allHandlers = @{}

foreach ($bundle in $data.bundles) {
    $bName = $bundle.name

    # Path 4: ParallelQuery.function (top-level on bundle)
    if ($bundle.ParallelQuery -and $bundle.ParallelQuery.function) {
        $fn = $bundle.ParallelQuery.function
        $entry = [PSCustomObject]@{ Bundle = $bName; Config = '(bundle)'; ConfigType = 'ParallelQuery'; TargetField = '-'; RuleType = 'ParallelQuery'; Arguments = '' }
        if (-not $allHandlers.ContainsKey($fn)) { $allHandlers[$fn] = @() }
        $allHandlers[$fn] += $entry
    }

    foreach ($cfg in $bundle.configurations) {
        $cName = $cfg.name
        $cType = if ($cfg.type) { $cfg.type } else { '(unknown)' }

        # Path 3: handlerFunction (top-level on config)
        if ($cfg.handlerFunction) {
            $fn = $cfg.handlerFunction
            $entry = [PSCustomObject]@{ Bundle = $bName; Config = $cName; ConfigType = $cType; TargetField = '-'; RuleType = 'handlerFunction'; Arguments = '' }
            if (-not $allHandlers.ContainsKey($fn)) { $allHandlers[$fn] = @() }
            $allHandlers[$fn] += $entry
        }

        # Paths 1 & 2: rule.function and fallbackRule.function (on attributes)
        if ($cfg.attributes) {
            foreach ($a in $cfg.attributes) {
                foreach ($ruleProp in @('rule','fallbackRule')) {
                    if ($a.$ruleProp -and $a.$ruleProp.function) {
                        $fn = $a.$ruleProp.function
                        $target = if ($a.targetField) { $a.targetField } else { '(unknown)' }
                        $argParts = @()
                        if ($a.$ruleProp.arguments) {
                            foreach ($arg in $a.$ruleProp.arguments) {
                                if ($arg -is [array] -or $arg -is [System.Collections.IEnumerable] -and $arg -isnot [string]) {
                                    $argParts += ($arg | ForEach-Object { "$_" }) -join '/'
                                } else { $argParts += "$arg" }
                            }
                        }
                        $args = $argParts -join ', '
                        $entry = [PSCustomObject]@{
                            Bundle = $bName; Config = $cName; ConfigType = $cType; TargetField = $target
                            RuleType = if ($ruleProp -eq 'fallbackRule') { 'fallback' } else { 'rule' }
                            Arguments = $args
                        }
                        if (-not $allHandlers.ContainsKey($fn)) { $allHandlers[$fn] = @() }
                        $allHandlers[$fn] += $entry
                    }
                }
            }
        }
    }
}

if ($allHandlers.Count -gt 0) {
    $rhHtml = "<div class='entity-section'><h2>Handler Summary</h2>"
    $rhHtml += "<p style='font-size:13px;color:#555;margin-bottom:12px;'>All handlers found across 4 property paths: <code>handlerFunction</code>, <code>rule.function</code>, <code>fallbackRule.function</code>, <code>ParallelQuery.function</code></p>"
    $rhHtml += "<table class='qidm-table'><thead><tr><th>Handler</th><th>Path</th><th>Bundle</th><th>Config</th><th>Config Type</th><th>Target Field</th><th>Arguments</th></tr></thead><tbody>"
    foreach ($fn in ($allHandlers.Keys | Sort-Object)) {
        $entries = $allHandlers[$fn]
        $first = $true
        foreach ($e in $entries) {
            $fnCell = if ($first) { "<td class='mono' rowspan='$($entries.Count)'><span class='tag tag-rule'>$(Esc $fn)</span></td>" } else { '' }
            $rhHtml += "<tr>$fnCell<td class='mono'>$(Esc $e.RuleType)</td><td class='mono'>$(Esc $e.Bundle)</td><td class='mono'>$(Esc $e.Config)</td><td class='mono'>$(Esc $e.ConfigType)</td><td class='mono'>$(Esc $e.TargetField)</td><td class='mono'>$(Esc $e.Arguments)</td></tr>"
            $first = $false
        }
    }
    $rhHtml += "</tbody></table>"
    $totalUsages = ($allHandlers.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    $rhHtml += "<div style='margin-top:12px;font-size:13px;color:#555;'><strong>$($allHandlers.Count)</strong> unique handlers, <strong>$totalUsages</strong> total usages</div>"
    $rhHtml += "</div>"
    $entitySections += $rhHtml
}

# --- Summary stats ---
$qidms = @()
if ($providerBundle) {
    $qidms = @($providerBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' })
}
$totalCombos = 0
foreach ($q in $qidms) { if ($q.combinations) { $totalCombos += $q.combinations.Count } }

$summaryHtml = @"
<div class='summary-grid'>
  <div class='summary-item'><div class='summary-num'>$($qifs.Count)</div><div class='summary-label'>QIFs (Entities)</div></div>
  <div class='summary-item'><div class='summary-num'>$($qidms.Count)</div><div class='summary-label'>CommSys QIDMs</div></div>
  <div class='summary-item'><div class='summary-num'>$totalCombos</div><div class='summary-label'>Query Combinations</div></div>
</div>
"@

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$jsonName - Layout Report</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; line-height: 1.5; padding: 20px; }
  .container { max-width: 960px; margin: 0 auto; }
  .header { background: #1a1a2e; color: #fff; padding: 24px 32px; border-radius: 8px 8px 0 0; }
  .header h1 { font-size: 22px; font-weight: 600; }
  .header .meta { color: #aaa; font-size: 13px; margin-top: 6px; }
  .content { background: #fff; padding: 24px 32px; border-radius: 0 0 8px 8px; border: 1px solid #ddd; border-top: none; }
  .summary-grid { display: flex; gap: 16px; margin-bottom: 28px; }
  .summary-item { flex: 1; background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 6px; padding: 16px; text-align: center; }
  .summary-num { font-size: 28px; font-weight: 700; color: #1a1a2e; }
  .summary-label { font-size: 12px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; }
  .entity-section { margin-bottom: 32px; border-bottom: 2px solid #eee; padding-bottom: 24px; }
  .entity-section:last-child { border-bottom: none; }
  h2 { font-size: 18px; color: #1a1a2e; margin-bottom: 16px; border-left: 4px solid #4361ee; padding-left: 12px; }
  h2 .entity-meta { font-size: 13px; color: #888; font-weight: 400; }
  h3 { font-size: 14px; color: #555; margin: 12px 0 8px; text-transform: uppercase; letter-spacing: 0.5px; }
  .card { background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 6px; margin-bottom: 12px; overflow: hidden; }
  .card-header { background: #e9ecef; padding: 8px 14px; font-weight: 600; font-size: 13px; color: #495057; border-bottom: 1px solid #dee2e6; }
  .card-body { padding: 10px 14px; }
  .row-container { margin-bottom: 6px; }
  .row-cols { display: block; font-size: 11px; color: #999; margin-bottom: 2px; }
  .field { padding: 8px 12px; margin: 4px 0; border-radius: 4px; border-left: 3px solid #ccc; background: #fff; }
  .field-header { display: flex; justify-content: space-between; align-items: center; }
  .field-id { font-family: 'Consolas', 'Monaco', monospace; font-weight: 600; font-size: 13px; }
  .field-type { font-size: 11px; padding: 2px 8px; border-radius: 10px; background: #eee; color: #555; }
  .field-tags { margin-top: 4px; display: flex; flex-wrap: wrap; gap: 4px; }
  .tag { font-size: 11px; padding: 1px 6px; border-radius: 3px; font-family: 'Consolas', 'Monaco', monospace; }
  .tag-attr { background: #dbeafe; color: #1e40af; }
  .tag-code { background: #fef3c7; color: #92400e; }
  .tag-prov { background: #d1fae5; color: #065f46; }
  .tag-default { background: #ede9fe; color: #5b21b6; }
  .tag-meta { background: #f3f4f6; color: #4b5563; }
  .tag-warn { background: #fee2e2; color: #991b1b; }
  .tag-rule { background: #fff7ed; color: #9a3412; border: 1px solid #fdba74; }
  .field-dropdown { border-left-color: #4361ee; }
  .field-text { border-left-color: #10b981; }
  .field-date { border-left-color: #f59e0b; }
  .field-check { border-left-color: #8b5cf6; }
  .field-hidden { border-left-color: #ef4444; opacity: 0.7; }
  .field-other { border-left-color: #6b7280; }
  .qidm { background: #fafafa; border: 1px solid #e5e7eb; border-radius: 6px; margin: 12px 0; padding: 14px; }
  .qidm-header { font-weight: 600; font-size: 14px; color: #1a1a2e; margin-bottom: 10px; }
  .qidm-table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 12px; }
  .qidm-table th { background: #f3f4f6; text-align: left; padding: 6px 10px; border-bottom: 2px solid #d1d5db; font-size: 12px; text-transform: uppercase; letter-spacing: 0.3px; color: #6b7280; }
  .qidm-table td { padding: 5px 10px; border-bottom: 1px solid #e5e7eb; }
  .mono { font-family: 'Consolas', 'Monaco', monospace; font-size: 12px; }
  .combo-header { font-weight: 600; font-size: 13px; margin: 8px 0 6px; color: #374151; }
  .combo-list { }
  .combo { background: #fff; border: 1px solid #e5e7eb; border-radius: 4px; padding: 8px 12px; margin-bottom: 6px; }
  .combo-idx { display: inline-block; background: #4361ee; color: #fff; font-size: 11px; font-weight: 700; width: 22px; height: 22px; line-height: 22px; text-align: center; border-radius: 50%; margin-right: 6px; }
  .combo-detail { font-size: 12px; color: #555; margin-top: 4px; margin-left: 28px; }
  .combo-field { display: inline-block; font-family: 'Consolas', monospace; font-size: 11px; padding: 1px 6px; border-radius: 3px; margin: 1px 2px; }
  .combo-set { background: #dbeafe; color: #1e40af; }
  .combo-any { background: #f3f4f6; color: #4b5563; }
  .legend { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 20px; padding: 12px 16px; background: #f8f9fa; border-radius: 6px; border: 1px solid #e0e0e0; }
  .legend-item { display: flex; align-items: center; gap: 6px; font-size: 12px; color: #555; }
  .legend-swatch { width: 14px; height: 14px; border-radius: 3px; border-left: 3px solid; }
  .footer { text-align: center; font-size: 11px; color: #999; margin-top: 20px; padding-top: 12px; border-top: 1px solid #eee; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>$jsonName</h1>
    <div class="meta">Source: $jsonFile | Generated: $timestamp</div>
  </div>
  <div class="content">
    $summaryHtml
    <div class="legend">
      <div class="legend-item"><div class="legend-swatch" style="border-left-color:#4361ee; background:#f0f4ff;"></div> Dropdown</div>
      <div class="legend-item"><div class="legend-swatch" style="border-left-color:#10b981; background:#f0fdf4;"></div> Text</div>
      <div class="legend-item"><div class="legend-swatch" style="border-left-color:#f59e0b; background:#fffbeb;"></div> Date</div>
      <div class="legend-item"><div class="legend-swatch" style="border-left-color:#8b5cf6; background:#f5f3ff;"></div> Checkbox</div>
      <div class="legend-item"><div class="legend-swatch" style="border-left-color:#ef4444; background:#fef2f2;"></div> Hidden</div>
      <div class="legend-item"><span class="tag tag-attr">attributeTypeId</span></div>
      <div class="legend-item"><span class="tag tag-code">codeType</span></div>
      <div class="legend-item"><span class="tag tag-prov">codeTypeProvider</span></div>
      <div class="legend-item"><span class="tag tag-default">default</span></div>
      <div class="legend-item"><span class="tag tag-rule">ruleHandler</span></div>
    </div>
    $entitySections
  </div>
  <div class="footer">ConnectCIC Layout Report - Generated by render_html.ps1</div>
</div>
</body>
</html>
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutFile, $html, $utf8NoBom)
Write-Host "HTML report saved: $OutFile"
