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
body{font-family:monospace;font-size:11px;color:#000;background:#fff;padding:12px;max-width:900px}
h1{font-size:12px;font-weight:bold;border-bottom:1px solid #000;margin-bottom:10px;padding-bottom:2px}
h2{font-size:11px;font-weight:bold;border-top:2px solid #000;border-bottom:1px solid #000;padding:2px 0;margin:14px 0 4px}
.t{border-bottom:1px dashed #ccc;padding:3px 0 5px;margin-bottom:2px}
.th{font-weight:bold}
.fill{margin:2px 0 2px 8px}
.fill span.k{display:inline-block;min-width:220px}
.fill span.v{font-weight:bold}
.fill span.g{font-style:italic}
.exp{margin:2px 0 0 8px}
.absent{text-decoration:underline}
@media print{body{padding:4px}.t{page-break-inside:avoid}h2{page-break-before:always}h2:first-of-type{page-break-before:auto}}
'@

$sb = [System.Text.StringBuilder]::new()
[void]$sb.Append("<!DOCTYPE html><html><head><meta charset='utf-8'><title>$provider Test Sheet</title><style>$css</style></head><body>")
[void]$sb.Append("<h1>$provider &mdash; Test Sheet &mdash; v$version &mdash; $genDate</h1>")

$testNum = 0

foreach ($entity in $entityOrder) {
    $qif = $qifs | Where-Object { $_.targetEntity -eq $entity } | Select-Object -First 1
    if (-not $qif) { continue }
    $cards     = Get-CardFields $qif.layout.default
    $allFields = @(); foreach ($c in $cards.Values) { foreach ($r in $c.rows) { foreach ($f in $r.fields) { $allFields += $f } } }
    $entQidms  = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })

    [void]$sb.Append("<h2>$entity</h2>")

    # ── RENDER ──
    $testNum++
    [void]$sb.Append("<div class='t'>")
    [void]$sb.Append("<div class='th'>T$testNum &mdash; RENDER</div>")
    foreach ($card in $cards.Values) {
        $flist = @()
        foreach ($row in $card.rows) {
            foreach ($f in $row.fields) {
                if ($f.hidden) { continue }
                $dv = if ($f.default_) { "=$(Esc $f.default_)" } else { '' }
                $flist += "$(Esc $f.label)$dv"
            }
        }
        [void]$sb.Append("<div class='fill'><span class='k'>[$(Esc $card.title)]</span> $($flist -join ' | ')</div>")
    }
    [void]$sb.Append("</div>")

    # ── Combos ──
    foreach ($qidm in $entQidms) {
        $sortedCombos = @($qidm.combinations | Sort-Object {
            $setNames = @(); if ($_.requirements -and $_.requirements.set) { $setNames = @($_.requirements.set) }
            $setNames.Count
        } -Descending)

        foreach ($combo in $sortedCombos) {
            $kr       = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
            $setIds   = Get-SetFieldIds $combo $qidm $allFields
            $guardFid = Get-GuardrailField $combo
            $testNum++

            [void]$sb.Append("<div class='t'>")
            $guardNote = if ($guardFid) { " &mdash; GUARDRAIL: $guardFid NOT_EXISTS" } else { '' }
            [void]$sb.Append("<div class='th'>T$testNum &mdash; $(Esc $qidm.query) &mdash; keyRef=$kr$guardNote</div>")

            # Fill lines
            foreach ($fid in $setIds) {
                $f   = $allFields | Where-Object { $_.fieldId -eq $fid } | Select-Object -First 1
                $lbl = if ($f -and $f.label) { $f.label } else { $fid }
                $val = Get-TestValue $fid
                [void]$sb.Append("<div class='fill'><span class='k'>$(Esc $lbl) ($fid)</span> <span class='v'>$(Esc $val)</span> [set]</div>")
            }
            if ($guardFid) {
                $gf   = $allFields | Where-Object { $_.fieldId -eq $guardFid } | Select-Object -First 1
                $glbl = if ($gf -and $gf.label) { $gf.label } else { $guardFid }
                $gval = Get-TestValue $guardFid
                [void]$sb.Append("<div class='fill'><span class='k g'>$(Esc $glbl) ($guardFid)</span> <span class='v'>$(Esc $gval)</span> [guardrail &mdash; fill to trigger; must be ABSENT in wire]</div>")
            }

            # Expected line
            $mustHave = $setIds -join ', '
            $mustNot  = if ($guardFid) { " | ABSENT: $guardFid" } else { '' }
            [void]$sb.Append("<div class='exp'>Expected: $(Esc $qidm.query) | keyRef=$kr | wire: $mustHave$mustNot</div>")
            [void]$sb.Append("</div>")
        }

        # ── any[] supplement ──
        $firstCombo = $sortedCombos | Select-Object -First 1
        if ($firstCombo) {
            $anyNames2  = @(); if ($firstCombo.requirements -and $firstCombo.requirements.any) { $anyNames2 = @($firstCombo.requirements.any) }
            $anyFields2 = @($allFields | Where-Object { $anyNames2 -contains $_.fieldId -and -not $_.hidden })
            if ($anyFields2.Count -gt 0) {
                $kr2     = if ($firstCombo.keyReference) { $firstCombo.keyReference } else { $firstCombo.keyRef }
                $setIds2 = Get-SetFieldIds $firstCombo $qidm $allFields
                $testNum++
                [void]$sb.Append("<div class='t'>")
                [void]$sb.Append("<div class='th'>T$testNum &mdash; $(Esc $qidm.query) + any[] &mdash; keyRef=$kr2</div>")
                foreach ($fid in $setIds2) {
                    $f   = $allFields | Where-Object { $_.fieldId -eq $fid } | Select-Object -First 1
                    $lbl = if ($f -and $f.label) { $f.label } else { $fid }
                    $val = Get-TestValue $fid
                    [void]$sb.Append("<div class='fill'><span class='k'>$(Esc $lbl) ($fid)</span> <span class='v'>$(Esc $val)</span> [set]</div>")
                }
                foreach ($f in $anyFields2) {
                    $val = if ($f.default_) { $f.default_ } else { Get-TestValue $f.fieldId }
                    [void]$sb.Append("<div class='fill'><span class='k'>$(Esc $f.label) ($($f.fieldId))</span> <span class='v'>$(Esc $val)</span> [any &mdash; verify serializes]</div>")
                }
                $anyCheck = ($anyFields2 | ForEach-Object { $_.fieldId }) -join ', '
                [void]$sb.Append("<div class='exp'>Verify in wire: $anyCheck</div>")
                [void]$sb.Append("</div>")
            }
        }
    }

    # ── Negative ──
    $hasAutoSelect = ($entQidms | Where-Object { $_.autoSelect -eq $true }).Count -gt 0
    if ($hasAutoSelect) {
        $testNum++
        [void]$sb.Append("<div class='t'>")
        [void]$sb.Append("<div class='th'>T$testNum &mdash; NEGATIVE &mdash; $entity empty form</div>")
        [void]$sb.Append("<div class='exp'>Clear all fields. No Send button.</div>")
        [void]$sb.Append("</div>")
    }
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
