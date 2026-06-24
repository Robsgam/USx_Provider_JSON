<#
  render_test_sheet.ps1 -- Printable tester reference sheet for a provider.

  Per entity: RENDER test, per-combo fill tables + expected wire, any[] supplement, negative.
  Output: HTML + optional PDF via Edge headless.

  Usage:
    .\render_test_sheet.ps1 -Path <provider.json> -OutFile <sheet.html> [-PdfFile <sheet.pdf>]
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$OutFile,
    [string]$PdfFile
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path $Path).Path
$data     = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$provider = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '(?i)_(BASE|MC)$',''
$genDate  = Get-Date -Format 'yyyy-MM-dd'

$entBundle  = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' } | Select-Object -First 1
$provBundle = $data.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' } | Select-Object -First 1
if (-not $entBundle) { Write-Error "No ENTITIES bundle"; exit 1 }

$version = 'unknown'
if ($provBundle.description -match 'v(\d+\.\d+)') { $version = $Matches[1] }

function Esc([string]$s) { if (-not $s) { return '' }; ([string]$s) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' }

# ── Field card extractor (mirrors generate_test_matrix) ──
function Get-CardFields($layout) {
    $cards = [ordered]@{}
    if (-not $layout) { return $cards }
    $orderedKeys = if ($layout.ROOT_PAGE -and $layout.ROOT_PAGE.nodes) { $layout.ROOT_PAGE.nodes } else { ($layout | Get-Member -MemberType NoteProperty).Name }
    foreach ($m in $orderedKeys) {
        if (-not $layout.$m) { continue }
        $node = $layout.$m
        if ($node.type.resolvedName -eq 'Card') {
            $title = if ($node.props.title) { $node.props.title } elseif ($node.props.label) { $node.props.label } else { $m }
            $fields = @()
            if ($node.nodes) {
                foreach ($rowId in $node.nodes) {
                    $row = $layout.$rowId
                    if (-not $row) { continue }
                    $rowFields = @()
                    if ($row.nodes) {
                        foreach ($fid in $row.nodes) {
                            $fn = $layout.$fid
                            if (-not $fn) { continue }
                            $fieldId = if ($fn.props.fieldId) { $fn.props.fieldId } else { $fid }
                            $type = switch ($fn.type.resolvedName) {
                                'FormSelect'    { 'dropdown' }
                                'FormInput'     { 'text' }
                                'FormDate'      { 'date' }
                                'FormDateInput' { 'date' }
                                'CheckboxInput' { 'checkbox' }
                                default         { $fn.type.resolvedName }
                            }
                            $rowFields += [PSCustomObject]@{
                                fieldId  = $fieldId
                                label    = if ($fn.props.label) { $fn.props.label } else { $fieldId }
                                type     = $type
                                default_ = $fn.props.initialValue
                                hidden   = ($fn.props.hidden -eq $true)
                            }
                        }
                    }
                    $fields += [PSCustomObject]@{ fields = $rowFields }
                }
            }
            $cards[$m] = [PSCustomObject]@{ title = $title; rows = $fields }
        }
    }
    return $cards
}

# ── Standard test values ──
function Get-TestValue([string]$fid) {
    switch -Regex ($fid) {
        '(?i)licensePlateNumber$'           { return 'TEST123' }
        '(?i)vehicleIdentificationNumber$'  { return '1HGCM82633A123456' }
        '(?i)operatorLicenseNumber'         { return 'D999888777' }
        '(?i)nameLast'                      { return 'DOE' }
        '(?i)nameFirst'                     { return 'JOHN' }
        '(?i)nameMiddle'                    { return '' }
        '(?i)birthDate'                     { return '01/15/1990' }
        '(?i)sexCode'                       { return 'M' }
        '(?i)gunSerialNumber'               { return 'GUN12345' }
        '(?i)gunMake'                       { return 'SMTH' }
        '(?i)gunCaliber'                    { return '9MM' }
        '(?i)gunModel'                      { return 'MODEL1' }
        '(?i)articleSerialNumber'           { return 'ART99999' }
        '(?i)articleTypeCode'               { return 'BBICYCL' }
        '(?i)boatHullIdNumber'              { return 'FL1234AB56H7' }
        '(?i)registrationNumber$'           { return 'FL1234AB' }
        '(?i)ncicNumber'                    { return 'X123456789' }
        '(?i)imageIndicator'                { return 'N' }
        '(?i)randomRequest'                 { return 'N' }
        default                             { return 'TEST' }
    }
}

# ── QIDM / entity wiring ──
$qidms = @($provBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.handlerFunction -eq 'CommsysTransactionRequestHandler' })
$qifs  = @($entBundle.configurations  | Where-Object { $_.type -eq 'QUERYINPUTFORM' })

$entityMap = @{}
foreach ($qif in $qifs) {
    $ent = $qif.targetEntity
    $names = @()
    if ($qif.queryInputDataMapping -is [array]) { $names = $qif.queryInputDataMapping } elseif ($qif.queryInputDataMapping) { $names = @($qif.queryInputDataMapping) }
    foreach ($n in $names) { $entityMap[$n] = $ent }
}
foreach ($q in $qidms) { if ($q.targetEntity -and -not $entityMap.ContainsKey($q.name)) { $entityMap[$q.name] = $q.targetEntity } }

# ── Resolve combo set[] attrs → form fieldIds ──
function Get-SetFieldIds($combo, $qidm, $allFields) {
    $setNames = @(); if ($combo.requirements -and $combo.requirements.set) { $setNames = @($combo.requirements.set) }
    $ids = @()
    foreach ($sf in $setNames) {
        $match = $allFields | Where-Object { $_.fieldId -eq $sf } | Select-Object -First 1
        if ($match) { $ids += $match.fieldId; continue }
        foreach ($attr in $qidm.attributes) {
            if ($attr.name -eq $sf) {
                $sfs = @(); if ($attr.sourceField -is [array]) { $sfs = $attr.sourceField } elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($s in $sfs) {
                    $fm = $allFields | Where-Object { $_.fieldId -eq $s } | Select-Object -First 1
                    if ($fm) { $ids += $fm.fieldId; break }
                }; break
            }
        }
    }
    return $ids
}

# ── Detect NOT_EXISTS guardrail: which field must be absent for this combo to fire ──
function Get-GuardrailField($combo) {
    foreach ($cond in @($combo.conditions)) {
        if ($cond.operator -eq 'NOT_EXISTS' -or $cond.operator -eq 'NOT_IN') {
            $sf = if ($cond.field) { $cond.field } elseif ($cond.sourceField) { $cond.sourceField } else { $null }
            if ($sf) { return $sf }
        }
    }
    return $null
}

# ── Build entity order ──
$entityOrder = @($qifs | Sort-Object {
    switch ($_.targetEntity) { 'Vehicle' { 0 } 'Person' { 1 } 'Boat' { 2 } 'Firearm' { 3 } 'Article' { 4 } default { 5 } }
} | ForEach-Object { $_.targetEntity } | Select-Object -Unique)

# ════════════════════════════════════════════════════════════════════
#  HTML GENERATION
# ════════════════════════════════════════════════════════════════════

$css = @'
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: Arial, sans-serif; font-size: 11px; color: #111; background: #fff; padding: 16px; }
h1 { font-size: 15px; border-bottom: 2px solid #333; padding-bottom: 6px; margin-bottom: 14px; }
.entity { page-break-after: always; margin-bottom: 30px; }
.entity:last-child { page-break-after: auto; }
h2 { font-size: 13px; background: #333; color: #fff; padding: 5px 8px; margin-bottom: 10px; letter-spacing: 1px; text-transform: uppercase; }
.test { border: 1px solid #ccc; border-radius: 3px; margin-bottom: 10px; overflow: hidden; }
.test-header { background: #f0f0f0; padding: 5px 8px; font-weight: bold; font-size: 11.5px; display: flex; gap: 12px; align-items: baseline; }
.test-type { background: #555; color: #fff; padding: 1px 6px; border-radius: 2px; font-size: 10px; letter-spacing: .5px; }
.test-type.render { background: #2c7; }
.test-type.combo  { background: #27a; }
.test-type.any    { background: #a72; }
.test-type.neg    { background: #a33; }
.test-body { padding: 8px 10px; }
table.fill { border-collapse: collapse; width: 100%; margin-bottom: 6px; }
table.fill th { background: #eee; font-weight: bold; text-align: left; padding: 3px 6px; border: 1px solid #ccc; }
table.fill td { padding: 3px 6px; border: 1px solid #ddd; vertical-align: top; }
table.fill td.val { font-family: monospace; font-size: 11px; color: #005; }
table.fill td.note { font-style: italic; color: #555; font-size: 10px; }
.expected { background: #f8f8f8; border: 1px solid #ddd; border-radius: 2px; padding: 5px 8px; margin-top: 4px; line-height: 1.6; }
.expected .label { font-weight: bold; }
.expected code { background: #e8e8e8; padding: 1px 4px; border-radius: 2px; font-size: 10.5px; }
.must-not { color: #a00; }
.sub { color: #555; font-size: 10px; margin-top: 2px; }
.render-cards { display: flex; flex-wrap: wrap; gap: 8px; }
.card { border: 1px solid #ccc; padding: 6px 8px; border-radius: 3px; min-width: 160px; flex: 1; }
.card-title { font-weight: bold; font-size: 10.5px; border-bottom: 1px solid #ddd; margin-bottom: 4px; padding-bottom: 2px; text-transform: uppercase; letter-spacing: .5px; color: #333; }
.card-field { padding: 1px 0; font-size: 10.5px; }
.card-field .default { color: #060; font-family: monospace; font-size: 10px; }
.card-field .type { color: #888; font-size: 10px; }
@media print { body { padding: 8px; } .entity { page-break-after: always; } }
'@

$sb = [System.Text.StringBuilder]::new()
[void]$sb.Append("<!DOCTYPE html><html><head><meta charset='utf-8'><title>$provider Test Sheet</title><style>$css</style></head><body>")
[void]$sb.Append("<h1>$provider &mdash; Test Reference Sheet &nbsp;<span style='font-weight:normal;font-size:12px;'>v$version &bull; $genDate</span></h1>")

$testNum = 0

foreach ($entity in $entityOrder) {
    $qif = $qifs | Where-Object { $_.targetEntity -eq $entity } | Select-Object -First 1
    if (-not $qif) { continue }
    $cards    = Get-CardFields $qif.layout.default
    $allFields = @(); foreach ($c in $cards.Values) { foreach ($r in $c.rows) { foreach ($f in $r.fields) { $allFields += $f } } }
    $entQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })

    [void]$sb.Append("<div class='entity'>")
    [void]$sb.Append("<h2>$entity</h2>")

    # ── RENDER test ──
    $testNum++
    [void]$sb.Append("<div class='test'>")
    [void]$sb.Append("<div class='test-header'><span class='test-type render'>RENDER</span><span>T$testNum &mdash; $entity render: verify cards, fields, defaults</span></div>")
    [void]$sb.Append("<div class='test-body'><div class='render-cards'>")
    foreach ($card in $cards.Values) {
        [void]$sb.Append("<div class='card'><div class='card-title'>$(Esc $card.title)</div>")
        foreach ($row in $card.rows) {
            foreach ($f in $row.fields) {
                if ($f.hidden) { continue }
                $dv = if ($f.default_) { " <span class='default'>= $(Esc $f.default_)</span>" } else { "" }
                $tp = "<span class='type'>($($f.type))</span>"
                [void]$sb.Append("<div class='card-field'>$(Esc $f.label)$dv $tp</div>")
            }
        }
        [void]$sb.Append("</div>")
    }
    [void]$sb.Append("</div></div></div>")

    # ── Combo tests ──
    foreach ($qidm in $entQidms) {
        $sortedCombos = @($qidm.combinations | Sort-Object {
            $kr = if ($_.keyReference) { $_.keyReference } else { $_.keyRef }
            $setNames = @(); if ($_.requirements -and $_.requirements.set) { $setNames = @($_.requirements.set) }
            $setNames.Count
        } -Descending)

        foreach ($combo in $sortedCombos) {
            $kr = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
            $testNum++
            $setIds    = Get-SetFieldIds $combo $qidm $allFields
            $guardFid  = Get-GuardrailField $combo
            $anyNames  = @(); if ($combo.requirements -and $combo.requirements.any) { $anyNames = @($combo.requirements.any) }
            $anyFields = @($allFields | Where-Object { $anyNames -contains $_.fieldId })

            [void]$sb.Append("<div class='test'>")
            [void]$sb.Append("<div class='test-header'><span class='test-type combo'>COMBO</span><span>T$testNum &mdash; $(Esc $qidm.query) &mdash; keyRef: <code>$kr</code></span></div>")
            [void]$sb.Append("<div class='test-body'>")

            # Fill table
            [void]$sb.Append("<table class='fill'><tr><th>Field</th><th>Value</th><th>Note</th></tr>")
            foreach ($fid in $setIds) {
                $f    = $allFields | Where-Object { $_.fieldId -eq $fid } | Select-Object -First 1
                $lbl  = if ($f -and $f.label) { $f.label } else { $fid }
                $val  = Get-TestValue $fid
                $note = 'required (set[])'
                [void]$sb.Append("<tr><td>$(Esc $lbl)</td><td class='val'>$(Esc $val)</td><td class='note'>$note</td></tr>")
            }
            # If guardrail: also show the winning field (the one that must NOT be absent)
            if ($guardFid) {
                $gf    = $allFields | Where-Object { $_.fieldId -eq $guardFid } | Select-Object -First 1
                $glbl  = if ($gf -and $gf.label) { $gf.label } else { $guardFid }
                $gval  = Get-TestValue $guardFid
                [void]$sb.Append("<tr style='background:#fff8e0'><td>$(Esc $glbl) <em>(guardrail)</em></td><td class='val'>$(Esc $gval)</td><td class='note'>fill to prove NOT_EXISTS fires; this combo fires ONLY when absent</td></tr>")
            }
            [void]$sb.Append("</table>")

            # Expected
            $mustHave  = ($setIds | ForEach-Object { "<code>$_</code>" }) -join ', '
            $mustNot   = if ($guardFid) { "<span class='must-not'><strong>MUST NOT have:</strong> <code>$guardFid</code></span>" } else { '' }
            [void]$sb.Append("<div class='expected'>")
            [void]$sb.Append("<span class='label'>Expected query:</span> $(Esc $qidm.query) &nbsp;|&nbsp; <span class='label'>keyRef:</span> <code>$(Esc $kr)</code><br>")
            if ($mustHave) { [void]$sb.Append("<span class='label'>Wire must have:</span> $mustHave<br>") }
            if ($mustNot)  { [void]$sb.Append("$mustNot<br>") }
            [void]$sb.Append("</div></div></div>")
        }

        # ── any[] supplement: add optional fields to first combo ──
        $firstCombo = $sortedCombos | Select-Object -First 1
        if ($firstCombo) {
            $anyNames2 = @(); if ($firstCombo.requirements -and $firstCombo.requirements.any) { $anyNames2 = @($firstCombo.requirements.any) }
            $anyFields2 = @($allFields | Where-Object { $anyNames2 -contains $_.fieldId -and -not $_.hidden })
            if ($anyFields2.Count -gt 0) {
                $testNum++
                $kr2 = if ($firstCombo.keyReference) { $firstCombo.keyReference } else { $firstCombo.keyRef }
                $setIds2 = Get-SetFieldIds $firstCombo $qidm $allFields
                [void]$sb.Append("<div class='test'>")
                [void]$sb.Append("<div class='test-header'><span class='test-type any'>ANY[]</span><span>T$testNum &mdash; $(Esc $qidm.query) + optional fields (keyRef <code>$kr2</code>)</span></div>")
                [void]$sb.Append("<div class='test-body'>")
                [void]$sb.Append("<table class='fill'><tr><th>Field</th><th>Value</th><th>Note</th></tr>")
                foreach ($fid in $setIds2) {
                    $f   = $allFields | Where-Object { $_.fieldId -eq $fid } | Select-Object -First 1
                    $lbl = if ($f -and $f.label) { $f.label } else { $fid }
                    $val = Get-TestValue $fid
                    [void]$sb.Append("<tr><td>$(Esc $lbl)</td><td class='val'>$(Esc $val)</td><td class='note'>required</td></tr>")
                }
                foreach ($f in $anyFields2) {
                    $val = if ($f.default_) { $f.default_ } else { Get-TestValue $f.fieldId }
                    [void]$sb.Append("<tr style='background:#f0f8ff'><td>$(Esc $f.label)</td><td class='val'>$(Esc $val)</td><td class='note'>optional &mdash; verify it serializes</td></tr>")
                }
                [void]$sb.Append("</table>")
                $anyCheck = ($anyFields2 | ForEach-Object { "<code>$($_.fieldId)</code>" }) -join ', '
                [void]$sb.Append("<div class='expected'><span class='label'>Verify in wire:</span> $anyCheck all present</div>")
                [void]$sb.Append("</div></div>")
            }
        }
    }

    # ── Negative test (autoSelect entities only) ──
    $hasAutoSelect = ($entQidms | Where-Object { $_.autoSelect -eq $true }).Count -gt 0
    if ($hasAutoSelect) {
        $testNum++
        [void]$sb.Append("<div class='test'>")
        [void]$sb.Append("<div class='test-header'><span class='test-type neg'>NEGATIVE</span><span>T$testNum &mdash; Empty $entity form &mdash; no Send button</span></div>")
        [void]$sb.Append("<div class='test-body'><div class='expected'>Clear all fields. Verify: Send button does <strong>not</strong> appear (no set[] field filled).</div></div></div>")
    }

    [void]$sb.Append("</div>") # /entity
}

[void]$sb.Append("</body></html>")

# Write HTML
$dir = [System.IO.Path]::GetDirectoryName((Resolve-Path $OutFile -ErrorAction SilentlyContinue).Path ?? $OutFile)
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$sb.ToString() | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "  [test-sheet] HTML: $OutFile" -ForegroundColor Green

# Print to PDF via Edge
if ($PdfFile) {
    $edge = @('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe','C:\Program Files\Microsoft\Edge\Application\msedge.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($edge) {
        $absHtml = (Resolve-Path $OutFile).Path
        $absPdf  = [System.IO.Path]::GetFullPath($PdfFile)
        $fileUri = 'file:///' + ($absHtml -replace '\\','/')
        Start-Process -FilePath $edge -ArgumentList @("--headless","--disable-gpu","--print-to-pdf=`"$absPdf`"","--no-margins","$fileUri") -Wait -WindowStyle Hidden 2>$null
        if (Test-Path $absPdf) { Write-Host "  [test-sheet] PDF:  $absPdf" -ForegroundColor Green }
        else { Write-Host "  [test-sheet] PDF not produced (Edge headless advisory)" -ForegroundColor Yellow }
    } else {
        Write-Host "  [test-sheet] Edge not found -- HTML only" -ForegroundColor Yellow
    }
}
