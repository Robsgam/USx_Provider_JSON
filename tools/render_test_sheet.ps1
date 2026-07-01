<#
  render_test_sheet.ps1 -- Compact printable test reference sheet.

  Reads T-numbers and descriptions from TEST_MATRIX.txt (authoritative numbering),
  enriches set[] fill data from the provider JSON, and outputs a single compact
  HTML table suitable for printing on 1-2 landscape pages.

  Usage:
    .\render_test_sheet.ps1 -Path <provider.json> [-MatrixPath <TEST_MATRIX.txt>] -OutFile <sheet.html> [-PdfFile <sheet.pdf>]
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$MatrixPath,
    [Parameter(Mandatory=$true)][string]$OutFile,
    [string]$PdfFile
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path $Path).Path
$data     = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$provider = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$','' -replace '(?i)_(BASE|MC)$',''
$genDate  = Get-Date -Format 'yyyy-MM-dd'

# Auto-locate matrix -- "reports" category (2026-07-01 docs/ reorg pilot)
if (-not $MatrixPath) {
    $provDir    = Split-Path $resolved -Parent
    . (Join-Path $PSScriptRoot '_resolve_docs_path.ps1')
    $MatrixPath = Find-DocsPath $provDir 'reports' "${provider}_TEST_MATRIX.txt"
}
if (-not (Test-Path $MatrixPath)) { Write-Error "TEST_MATRIX.txt not found: $MatrixPath"; exit 1 }

$entBundle  = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' } | Select-Object -First 1
$provBundle = $data.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' } | Select-Object -First 1
if (-not $entBundle) { Write-Error "No ENTITIES bundle"; exit 1 }

$version = if ($data.version) { $data.version } else { 'unknown' }
if ($version -eq 'unknown' -and $provBundle.description -match 'v(\d+\.\d+)') { $version = $Matches[1] }

function Esc([string]$s) {
    if (-not $s) { return '' }
    ([string]$s) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

# ── Build keyRef -> combo lookup from provider QIDMs ──
$qidms = @($provBundle.configurations | Where-Object {
    $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.handlerFunction -eq 'CommsysTransactionRequestHandler'
})
$comboByKeyRef = @{}
foreach ($q in $qidms) {
    foreach ($c in @($q.combinations)) {
        $kr = if ($c.keyReference) { $c.keyReference } elseif ($c.keyRef) { $c.keyRef } else { '' }
        if ($kr) { $comboByKeyRef[$kr] = [PSCustomObject]@{ combo=$c; qidm=$q } }
    }
}

# ── Standard test values ──
function Get-TestValue([string]$fid) {
    switch -Regex ($fid) {
        '(?i)licensePlateNumber$'           { return 'ABC1234' }
        '(?i)vehicleIdentificationNumber$'  { return '1HGCM82633A123456' }
        '(?i)operatorLicenseNumberDH'       { return 'D999888777' }
        '(?i)operatorLicenseNumber'         { return 'D999888777' }
        '(?i)nameLastDH'                    { return 'DOE' }
        '(?i)nameLast'                      { return 'DOE' }
        '(?i)nameFirstDH'                   { return 'JOHN' }
        '(?i)nameFirst'                     { return 'JOHN' }
        '(?i)birthDateDH'                   { return '01/15/1990' }
        '(?i)birthDate'                     { return '01/15/1990' }
        '(?i)sexCodeDH'                     { return 'M' }
        '(?i)sexCode'                       { return 'M' }
        '(?i)registrationState'             { return 'TX' }
        '(?i)gunSerialNumber'               { return 'GUN12345' }
        '(?i)articleSerialNumber'           { return 'ART99999' }
        '(?i)articleTypeCode'               { return 'BBICYCL' }
        '(?i)boatHullIdNumber'              { return 'FL1234AB56H7' }
        '(?i)registrationNumber$'           { return 'FL1234AB' }
        '(?i)ncicNumber'                    { return 'X123456789' }
        '(?i)stickerNumber'                 { return 'STK1234' }
        '(?i)imageIndicator'                { return 'Y' }
        '(?i)relatedHit'                    { return 'Y' }
        '(?i)emailAddress'                  { return 'officer@agency.gov' }
        '(?i)purposeCode'                   { return 'C' }
        default                             { return 'TEST' }
    }
}

# ── Resolve QIDM attribute name to its form fieldId ──
function Resolve-SourceField([string]$attrName, $qidm) {
    foreach ($attr in @($qidm.attributes)) {
        if ($attr.name -ne $attrName) { continue }
        $sfs = if ($attr.sourceField -is [array]) { $attr.sourceField } elseif ($attr.sourceField) { @($attr.sourceField) } else { @() }
        if ($sfs.Count -gt 0) { return $sfs[0] }
    }
    return $attrName
}

# ── Build fill HTML for a keyRef (set[] fields + guardrail notes) ──
function Get-ComboFillHtml([string]$keyRef) {
    $entry = $comboByKeyRef[$keyRef]
    if (-not $entry) { return "<i>?$keyRef</i>" }
    $combo = $entry.combo; $qidm = $entry.qidm
    $setNames = @(); if ($combo.requirements.set) { $setNames = @($combo.requirements.set) }

    $mustBlank = @()
    if ($combo.requirements.conditions) {
        foreach ($cond in @($combo.requirements.conditions)) {
            if ($cond.operator -eq 'NOT_EXISTS') {
                $sf = if ($cond.field -is [array]) { $cond.field[0] } else { $cond.field }
                $mustBlank += Resolve-SourceField $sf $qidm
            }
        }
    }

    $parts = @()
    foreach ($sn in $setNames) {
        $fid = Resolve-SourceField $sn $qidm
        $val = Get-TestValue $fid
        $parts += "<b>${fid}=${val}</b>"
    }
    $html = $parts -join ' '
    if ($mustBlank.Count -gt 0) {
        $html += " <span style='color:#c00'>[leave blank: $($mustBlank -join ', ')]</span>"
    }
    return $html
}

# ── Parse TEST_MATRIX.txt into ordered test records ──
$matrixLines = Get-Content $MatrixPath
$tests = [System.Collections.Generic.List[PSCustomObject]]::new()

$i = 0
while ($i -lt $matrixLines.Count) {
    $line = $matrixLines[$i]
    # Match test lines: " NN  Entity  action ... ["
    if ($line -match '^\s{0,2}(\d{1,3})\s{2,}(\w+)\s{2,}(.+?)\s*\[') {
        $tNum    = [int]$Matches[1]
        $tEntity = $Matches[2].Trim()
        $rawAct  = $Matches[3].Trim()

        # Collect continuation lines (12+ leading spaces)
        $contLines    = [System.Collections.Generic.List[string]]::new()
        $expectedLine = ''
        $j = $i + 1
        while ($j -lt $matrixLines.Count -and $matrixLines[$j] -match '^\s{12,}') {
            $cl = $matrixLines[$j].Trim()
            $contLines.Add($cl)
            if ($cl -match '^Expected:') { $expectedLine = $cl }
            $j++
        }

        # Determine type
        $type       = 'COMBO'
        $keyRef     = ''
        $anyNote    = ''
        $comboLabel = ($rawAct -split '\s+')[0]

        if ($rawAct -match '^Render form') {
            $type = 'RENDER'
        } elseif ($rawAct -match '^Empty form') {
            $type = 'NEGATIVE'
        } elseif ($rawAct -match '^Deselect') {
            $type = 'DESELECT'
        } elseif ($expectedLine -match 'any\[\] fields present') {
            $type = 'ANY'
            # "COMBO             + field1, field2"  (2+ spaces before +)
            if ($rawAct -match '^(\S+)\s{2,}\+\s+(.+)$') {
                $comboLabel = $Matches[1]
                $anyNote    = $Matches[2]
            } else {
                $anyNote = $rawAct -replace '^[^\+]+\+\s*',''
            }
        } else {
            if ($expectedLine -match '\(([A-Za-z0-9_]+)\)') { $keyRef = $Matches[1] }
        }

        # Render description: build from continuation lines
        $renderDesc = ''
        if ($type -eq 'RENDER' -and $contLines.Count -gt 0) {
            $renderDesc = ($contLines | ForEach-Object { Esc $_ }) -join '<br>'
        }

        $tests.Add([PSCustomObject]@{
            num        = $tNum
            entity     = $tEntity
            action     = $rawAct
            comboLabel = $comboLabel
            type       = $type
            keyRef     = $keyRef
            anyNote    = $anyNote
            renderDesc = $renderDesc
        })
    }
    $i++
}

# Second pass: resolve keyRef for ANY tests via matching prior COMBO test
foreach ($t in ($tests | Where-Object { $_.type -eq 'ANY' -and -not $_.keyRef })) {
    $prior = $tests | Where-Object {
        $_.type -eq 'COMBO' -and $_.keyRef -and
        $_.comboLabel -eq $t.comboLabel -and $_.entity -eq $t.entity
    } | Select-Object -Last 1
    if ($prior) { $t.keyRef = $prior.keyRef }
}

# ── CSS ──
$css = @'
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:Arial,Helvetica,sans-serif;font-size:8pt;color:#000;background:#fff;padding:5mm}
h1{font-size:9pt;font-weight:bold;border-bottom:2px solid #000;margin-bottom:4px;padding-bottom:2px}
table{width:100%;border-collapse:collapse;table-layout:fixed}
colgroup col:nth-child(1){width:26px}
colgroup col:nth-child(2){width:52px}
colgroup col:nth-child(3){width:80px}
colgroup col:nth-child(4){width:auto}
colgroup col:nth-child(5){width:18px}
th{background:#111;color:#fff;font-size:7.5pt;padding:2px 4px;text-align:left;white-space:nowrap}
td{border:1px solid #bbb;padding:2px 4px;vertical-align:top;word-wrap:break-word;line-height:1.3}
tr.render td{background:#f2f2f2}
tr.negative td,tr.deselect td{background:#fffbe6}
tr.any td{background:#f0f8ff}
tr.phase td{background:#333;color:#fff;font-weight:bold;font-size:7pt;padding:2px 4px;letter-spacing:.4px}
.kr{font-size:6.5pt;color:#888;display:block}
@media print{
  @page{size:letter landscape;margin:8mm}
  body{padding:0;font-size:7.5pt}
  h1{font-size:8pt}
  tr{page-break-inside:avoid}
}
'@

# ── HTML generation ──
$sb = [System.Text.StringBuilder]::new()
[void]$sb.Append("<!DOCTYPE html><html><head><meta charset='utf-8'>")
[void]$sb.Append("<title>$(Esc $provider) Test Sheet v$(Esc $version)</title>")
[void]$sb.Append("<style>$css</style></head><body>")
[void]$sb.Append("<h1>$(Esc $provider) &mdash; Test Sheet &mdash; v$(Esc $version) &mdash; $genDate &mdash; $($tests.Count) tests</h1>")
[void]$sb.Append("<table><colgroup><col><col><col><col><col></colgroup>")
[void]$sb.Append("<thead><tr><th>T#</th><th>Entity</th><th>Combo / Action</th><th>Fill / Verify</th><th>&#10003;</th></tr></thead><tbody>")

# Group rows by ENTITY. The matrix is already entity-grouped (render -> combos ->
# any[] -> deselect/routing -> negative per entity), and $tests preserves that order,
# so the printed sheet matches the written test process exactly: one entity at a time.
$entityTestCounts = @{}
foreach ($et in $tests) {
    if (-not $entityTestCounts.ContainsKey($et.entity)) { $entityTestCounts[$et.entity] = 0 }
    $entityTestCounts[$et.entity]++
}
$lastEntity = ''
$entSecNum  = 0

foreach ($t in $tests) {
    if ($t.entity -ne $lastEntity) {
        $entSecNum++
        $cnt = $entityTestCounts[$t.entity]
        $entName = Esc ($t.entity.ToUpper())
        [void]$sb.Append("<tr class='phase'><td colspan='5'>ENTITY $entSecNum &mdash; $entName ($cnt tests: render &rarr; combos &rarr; any[] &rarr; negative)</td></tr>")
        $lastEntity = $t.entity
    }

    $rowClass = switch ($t.type) {
        'RENDER'   { 'render'   }
        'NEGATIVE' { 'negative' }
        'DESELECT' { 'deselect' }
        'ANY'      { 'any'      }
        default    { ''         }
    }

    # Fill column
    $fillHtml = ''
    switch ($t.type) {
        'RENDER' {
            $fillHtml = if ($t.renderDesc) { $t.renderDesc } else { '&mdash;' }
        }
        'COMBO' {
            if ($t.keyRef) {
                $fillHtml  = Get-ComboFillHtml $t.keyRef
                $fillHtml += "<span class='kr'>&#8594; $($t.keyRef)</span>"
            } else {
                $fillHtml = Esc $t.action
            }
        }
        'ANY' {
            if ($t.keyRef) {
                $baseFill  = Get-ComboFillHtml $t.keyRef
                $fillHtml  = "Fire: $baseFill"
                $fillHtml += " &thinsp;+&thinsp; add: <b>$(Esc $t.anyNote)</b>"
                $fillHtml += "<span class='kr'>&#8594; $($t.keyRef)</span>"
            } else {
                $fillHtml = "Add: <b>$(Esc $t.anyNote)</b>"
            }
        }
        'DESELECT' {
            $fillHtml = "Fill fields for <b>both</b> queries. Submit. Verify DH fires and DL is deselected."
        }
        'NEGATIVE' {
            $fillHtml = "Clear all fields. Verify <b>no Send button</b> appears."
        }
    }

    # Action column: abbreviated
    $actionHtml = switch ($t.type) {
        'RENDER'   { 'Render form' }
        'NEGATIVE' { 'Empty form' }
        'DESELECT' { Esc ($t.action -replace '^Deselect:\s*','') }
        'ANY'      { "$(Esc $t.comboLabel) <span style='color:#777'>+&nbsp;any[]</span>" }
        default    { Esc $t.comboLabel }
    }

    [void]$sb.Append("<tr class='$rowClass'>")
    [void]$sb.Append("<td style='text-align:center'><b>$($t.num)</b></td>")
    [void]$sb.Append("<td>$(Esc $t.entity)</td>")
    [void]$sb.Append("<td>$actionHtml</td>")
    [void]$sb.Append("<td>$fillHtml</td>")
    [void]$sb.Append("<td style='text-align:center;font-size:13pt'>&#9744;</td>")
    [void]$sb.Append("</tr>")
}

[void]$sb.Append("</tbody></table></body></html>")

$dir = Split-Path $OutFile -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "  [test-sheet] HTML: $OutFile" -ForegroundColor Green

if ($PdfFile) {
    $edge = @(
        'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($edge) {
        $absHtml = (Resolve-Path $OutFile).Path
        $absPdf  = [System.IO.Path]::GetFullPath($PdfFile)
        $fileUri = 'file:///' + ($absHtml -replace '\\','/')
        Start-Process -FilePath $edge -ArgumentList @(
            '--headless','--disable-gpu',
            "--print-to-pdf=`"$absPdf`"",'--no-margins',
            "$fileUri"
        ) -Wait -WindowStyle Hidden 2>$null
        if (Test-Path $absPdf) { Write-Host "  [test-sheet] PDF:  $absPdf" -ForegroundColor Green }
        else { Write-Host "  [test-sheet] PDF not produced (Edge headless)" -ForegroundColor Yellow }
    } else {
        Write-Host "  [test-sheet] Edge not found -- HTML only" -ForegroundColor Yellow
    }
}
