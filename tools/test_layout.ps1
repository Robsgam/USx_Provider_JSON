<#
  test_layout.ps1 -- QIF Layout Renderer & Validator
  Reads a provider JSON, validates Craft.js node tree integrity,
  and generates an HTML preview of all entity form layouts.

  Usage: .\test_layout.ps1 -Path <provider.json> [-Entity <name>]
  Output: <provider>_layout_preview.html (opens in browser)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$Entity
)

$ErrorActionPreference = "Stop"

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json

# ── Collect QIFs ──
$qifs = @()
foreach ($bundle in $json.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -eq "QUERYINPUTFORM") {
            if (-not $Entity -or $cfg.targetEntity -eq $Entity) {
                $qifs += $cfg
            }
        }
    }
}

if ($qifs.Count -eq 0) {
    Write-Host "No QIFs found." -ForegroundColor Red
    exit 1
}

# ── Validate node tree ──
function Test-NodeTree($layoutName, $nodes) {
    $errors = @()
    $nodeKeys = @($nodes | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)

    foreach ($key in $nodeKeys) {
        $node = $nodes.$key

        # Check parent reference
        if ($null -ne $node.parent -and $node.parent -ne "") {
            $parentKey = $node.parent
            if ($nodeKeys -notcontains $parentKey) {
                $errors += "Node '$key' references parent '$parentKey' which does not exist"
            }
            else {
                $parentNode = $nodes.$parentKey
                $childList = @()
                if ($parentNode.nodes) { $childList = @($parentNode.nodes) }
                if ($childList -notcontains $key) {
                    $errors += "Node '$key' claims parent '$parentKey' but parent.nodes does not contain '$key'"
                }
            }
        }

        # Check children exist
        if ($node.nodes) {
            foreach ($childKey in $node.nodes) {
                if ($nodeKeys -notcontains $childKey) {
                    $errors += "Node '$key'.nodes references '$childKey' which does not exist"
                }
            }
        }

        # Check type exists
        if (-not $node.type -or -not $node.type.resolvedName) {
            $errors += "Node '$key' missing type.resolvedName"
        }
    }

    # Check ROOT exists
    if ($nodeKeys -notcontains "ROOT") {
        $errors += "Missing ROOT node"
    }

    # Check for orphans (nodes not reachable from ROOT)
    $visited = @{}
    $queue = [System.Collections.Queue]::new()
    if ($nodeKeys -contains "ROOT") {
        $queue.Enqueue("ROOT")
        while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            if ($visited.ContainsKey($cur)) { continue }
            $visited[$cur] = $true
            $n = $nodes.$cur
            if ($n.nodes) {
                foreach ($c in $n.nodes) { $queue.Enqueue($c) }
            }
            # Also follow linkedNodes
            if ($n.linkedNodes) {
                $lnKeys = @($n.linkedNodes | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
                foreach ($lk in $lnKeys) {
                    $queue.Enqueue($n.linkedNodes.$lk)
                }
            }
        }
    }
    $orphans = @($nodeKeys | Where-Object { -not $visited.ContainsKey($_) })
    foreach ($o in $orphans) {
        $errors += "Orphan node '$o' not reachable from ROOT"
    }

    return $errors
}

# ── Render node to HTML ──
function Render-Node($key, $nodes, $depth) {
    $node = $nodes.$key
    if (-not $node) { return "<div class='error'>Missing node: $key</div>" }

    $type = "unknown"
    if ($node.type -and $node.type.resolvedName) { $type = $node.type.resolvedName }

    $html = ""

    switch ($type) {
        "Root" {
            foreach ($child in $node.nodes) {
                $html += Render-Node $child $nodes ($depth + 1)
            }
        }
        "Form" {
            foreach ($child in $node.nodes) {
                $html += Render-Node $child $nodes ($depth + 1)
            }
        }
        "Page" {
            $title = ""
            if ($node.props -and $node.props.title) { $title = $node.props.title }
            $html += "<div class='page'>"
            if ($title) { $html += "<div class='page-title'>$title</div>" }
            foreach ($child in $node.nodes) {
                $html += Render-Node $child $nodes ($depth + 1)
            }
            $html += "</div>"
        }
        "Card" {
            $title = ""
            if ($node.props -and $node.props.title) { $title = $node.props.title }
            $html += "<div class='card'>"
            if ($title) { $html += "<div class='card-title'>$title</div>" }
            else { $html += "<div class='card-title-auto'>$key</div>" }
            foreach ($child in $node.nodes) {
                $html += Render-Node $child $nodes ($depth + 1)
            }
            $html += "</div>"
        }
        "Row" {
            $cols = @()
            if ($node.props -and $node.props.templateColumns) {
                $tc = $node.props.templateColumns
                if ($tc -is [System.Array]) { $cols = @($tc) }
                elseif ($tc -is [string]) { $cols = @($tc -split '\s+') }
                else { $cols = @($tc) }
            }
            $gridCols = ($cols | ForEach-Object { "${_}fr" }) -join " "
            if (-not $gridCols) { $gridCols = "1fr" }
            $html += "<div class='row' style='grid-template-columns: $gridCols;'>"
            foreach ($child in $node.nodes) {
                $html += "<div class='col'>"
                $html += Render-Node $child $nodes ($depth + 1)
                $html += "</div>"
            }
            $html += "</div>"
        }
        "FormInput" {
            $label = ""
            $fieldId = ""
            $maxLen = ""
            if ($node.props) {
                if ($node.props.label) { $label = $node.props.label }
                if ($node.props.fieldId) { $fieldId = $node.props.fieldId }
                if ($node.props.maxLength) { $maxLen = " max=$($node.props.maxLength)" }
            }
            $html += "<div class='field input-field'>"
            $html += "<label>$label</label>"
            $html += "<input type='text' placeholder='$fieldId$maxLen' disabled />"
            $html += "<span class='field-id'>$fieldId</span>"
            $html += "</div>"
        }
        "FormSelect" {
            $label = ""
            $fieldId = ""
            $attrType = ""
            $codeType = ""
            if ($node.props) {
                if ($node.props.label) { $label = $node.props.label }
                if ($node.props.fieldId) { $fieldId = $node.props.fieldId }
                if ($node.props.attributeTypeId) { $attrType = $node.props.attributeTypeId }
                if ($node.props.codeTypeCategory) { $codeType = $node.props.codeTypeCategory }
            }
            $badge = ""
            if ($attrType) { $badge = "<span class='badge attr'>attrType=$attrType</span>" }
            elseif ($codeType) { $badge = "<span class='badge code'>codeType=$codeType</span>" }
            $html += "<div class='field select-field'>"
            $html += "<label>$label $badge</label>"
            $html += "<select disabled><option>$fieldId</option></select>"
            $html += "<span class='field-id'>$fieldId</span>"
            $html += "</div>"
        }
        "FormDate" {
            $label = ""
            $fieldId = ""
            if ($node.props) {
                if ($node.props.label) { $label = $node.props.label }
                if ($node.props.fieldId) { $fieldId = $node.props.fieldId }
            }
            $html += "<div class='field date-field'>"
            $html += "<label>$label</label>"
            $html += "<input type='date' disabled />"
            $html += "<span class='field-id'>$fieldId</span>"
            $html += "</div>"
        }
        default {
            $html += "<div class='unknown-node'>[$type] $key"
            if ($node.nodes) {
                foreach ($child in $node.nodes) {
                    $html += Render-Node $child $nodes ($depth + 1)
                }
            }
            $html += "</div>"
        }
    }

    return $html
}

# ── Build HTML ──
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
$htmlParts = @()

$htmlParts += @"
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Layout Preview: $fileName</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, 'Segoe UI', sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }
  h1 { color: #e94560; margin-bottom: 20px; font-size: 18px; }
  h2 { color: #0f3460; background: #e94560; padding: 8px 16px; margin: 20px 0 10px; border-radius: 4px; font-size: 14px; }
  h3 { color: #ccc; margin: 10px 0 5px; font-size: 13px; border-bottom: 1px solid #333; padding-bottom: 4px; }
  .entity-section { margin-bottom: 30px; }
  .layout-group { display: flex; gap: 20px; flex-wrap: wrap; margin-bottom: 20px; }
  .layout-panel { flex: 1; min-width: 400px; background: #16213e; border: 1px solid #0f3460; border-radius: 8px; padding: 12px; }
  .layout-label { font-size: 11px; color: #e94560; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
  .page { margin: 4px 0; }
  .page-title { font-size: 10px; color: #666; margin-bottom: 4px; }
  .card { background: #1a1a3e; border: 1px solid #0f3460; border-radius: 6px; padding: 10px; margin-bottom: 8px; }
  .card-title { font-size: 12px; font-weight: bold; color: #e94560; margin-bottom: 8px; border-bottom: 1px solid #333; padding-bottom: 4px; }
  .card-title-auto { font-size: 10px; color: #555; margin-bottom: 6px; }
  .row { display: grid; gap: 8px; margin-bottom: 6px; }
  .col { min-width: 0; }
  .field { padding: 4px; }
  .field label { display: block; font-size: 11px; color: #aaa; margin-bottom: 2px; }
  .field input, .field select { width: 100%; padding: 4px 6px; font-size: 12px; border: 1px solid #333; border-radius: 3px; background: #0a0a1a; color: #888; }
  .field-id { font-size: 9px; color: #555; display: block; margin-top: 1px; }
  .input-field input { border-left: 3px solid #3498db; }
  .select-field select { border-left: 3px solid #e67e22; }
  .date-field input { border-left: 3px solid #2ecc71; }
  .badge { font-size: 9px; padding: 1px 4px; border-radius: 2px; margin-left: 4px; }
  .badge.attr { background: #0f3460; color: #3498db; }
  .badge.code { background: #4a1942; color: #e67e22; }
  .error { color: #e74c3c; font-size: 11px; padding: 4px; background: #2c0b0e; border-radius: 3px; margin: 2px 0; }
  .validation { margin: 10px 0; padding: 8px; border-radius: 4px; font-size: 11px; }
  .validation.pass { background: #0b2c0b; color: #2ecc71; border: 1px solid #1a5c1a; }
  .validation.fail { background: #2c0b0e; color: #e74c3c; border: 1px solid #5c1a1a; }
  .unknown-node { color: #e67e22; font-size: 11px; padding: 2px; border: 1px dashed #e67e22; margin: 2px; }
  .stats { font-size: 11px; color: #888; margin: 4px 0; }
  .legend { display: flex; gap: 16px; margin: 10px 0; font-size: 11px; }
  .legend span { display: flex; align-items: center; gap: 4px; }
  .legend .swatch { width: 12px; height: 12px; border-radius: 2px; }
</style>
</head><body>
<h1>Layout Preview: $fileName</h1>
<div class="legend">
  <span><div class="swatch" style="background:#3498db"></div> Input (FormInput)</span>
  <span><div class="swatch" style="background:#e67e22"></div> Select (FormSelect)</span>
  <span><div class="swatch" style="background:#2ecc71"></div> Date (FormDate)</span>
</div>
"@

$totalErrors = 0

foreach ($qif in $qifs) {
    $entityName = $qif.targetEntity
    $qifName = $qif.name

    $htmlParts += "<div class='entity-section'>"
    $htmlParts += "<h2>$qifName [$entityName]</h2>"

    # Get layout variants
    $layoutKeys = @($qif.layout | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)

    $htmlParts += "<div class='layout-group'>"

    foreach ($lk in $layoutKeys) {
        $layout = $qif.layout.$lk
        $nodeKeys = @($layout | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)

        # Validate
        $errors = Test-NodeTree "$qifName/$lk" $layout

        # Count field types
        $inputs = 0; $selects = 0; $dates = 0
        foreach ($nk in $nodeKeys) {
            $n = $layout.$nk
            if ($n.type -and $n.type.resolvedName) {
                switch ($n.type.resolvedName) {
                    "FormInput"  { $inputs++ }
                    "FormSelect" { $selects++ }
                    "FormDate"   { $dates++ }
                }
            }
        }

        # Count cards
        $cards = 0
        foreach ($nk in $nodeKeys) {
            $n = $layout.$nk
            if ($n.type -and $n.type.resolvedName -eq "Card") { $cards++ }
        }

        $htmlParts += "<div class='layout-panel'>"
        $htmlParts += "<div class='layout-label'>$lk</div>"
        $htmlParts += "<div class='stats'>$($nodeKeys.Count) nodes | $cards cards | $inputs inputs, $selects selects, $dates dates</div>"

        if ($errors.Count -gt 0) {
            $totalErrors += $errors.Count
            foreach ($e in $errors) {
                $htmlParts += "<div class='validation fail'>FAIL: $e</div>"
            }
        }
        else {
            $htmlParts += "<div class='validation pass'>Tree OK - all parent/child refs valid, no orphans</div>"
        }

        # Render
        $htmlParts += (Render-Node "ROOT" $layout 0)
        $htmlParts += "</div>"
    }

    $htmlParts += "</div></div>"
}

$htmlParts += "</body></html>"

# ── Write HTML ──
$outHtml = Join-Path (Split-Path $Path) "${fileName}_layout_preview.html"
$htmlContent = $htmlParts -join "`n"
[System.IO.File]::WriteAllText($outHtml, $htmlContent, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Layout Preview Generator" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  File: $(Split-Path $Path -Leaf)" -ForegroundColor Gray
Write-Host "  QIFs: $($qifs.Count)" -ForegroundColor Gray

foreach ($qif in $qifs) {
    $layoutKeys = @($qif.layout | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
    Write-Host "  $($qif.name) [$($qif.targetEntity)]: $($layoutKeys.Count) layouts ($($layoutKeys -join ', '))" -ForegroundColor Gray
}

if ($totalErrors -gt 0) {
    Write-Host ""
    Write-Host "  ERRORS: $totalErrors tree integrity issues found!" -ForegroundColor Red
}
else {
    Write-Host ""
    Write-Host "  All node trees valid." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Output: $outHtml" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan

# Open in browser
Start-Process $outHtml
