<#
  render_cad_guide.ps1 -- CAD Auto-Dispatch Query Reference

  Generates an HTML/PDF reference showing which provider queries CAD can automatically
  trigger (via form auto-populate) vs those that require officer input.

  A query is CAD-triggerable when every required field in its set[] is supplied by either:
    (a) the CAD auto-populate field list (cad_field_mapping.json), or
    (b) a combo defaults[] entry.

  Usage:
    .\render_cad_guide.ps1 -Path <provider.json> -OutFile <guide.html> [-PdfFile <guide.pdf>]

  PDF is best-effort via Edge headless. If Edge is not found, HTML is still produced.
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$OutFile,
    [string]$PdfFile
)

$ErrorActionPreference = 'Stop'

$toolsDir     = Split-Path $PSCommandPath -Parent
$cadFieldPath = Join-Path $toolsDir 'config\cad_field_mapping.json'
if (-not (Test-Path $cadFieldPath)) { Write-Error "CAD field mapping not found: $cadFieldPath"; exit 1 }
$cadConfig = Get-Content $cadFieldPath -Raw -Encoding UTF8 | ConvertFrom-Json

$resolved     = (Resolve-Path $Path).Path
$data         = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$providerName = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '_v[\d.]+$','' -replace '(?i)_(BASE|MC)$',''
$genDate      = Get-Date -Format 'yyyy-MM-dd'

# ── Helpers ───────────────────────────────────────────────────────────────────
function Esc($s) {
    if ($null -eq $s) { return '' }
    return ([string]$s) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}
function Prettify([string]$tok) {
    if (-not $tok) { return '' }
    $t = $tok -creplace '([a-z0-9])([A-Z])','$1 $2'
    return ((Get-Culture).TextInfo.ToTitleCase($t.ToLower()))
}

# ── Label lookup: scan all bundle QIF layoutVariants ─────────────────────────
$labelOf = @{}; $hiddenOf = @{}
foreach ($bundle in $data.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        $layouts = @()
        if ($cfg.layoutVariants)                                   { $layouts = @($cfg.layoutVariants) }
        elseif ($cfg.layout -and $cfg.layout.default)              { $layouts = @($cfg.layout.default) }
        foreach ($lv in $layouts) {
            $nodes = if ($lv.PSObject.Properties.Name -contains 'nodes') { $lv.nodes } else { $null }
            if (-not $nodes) { continue }
            foreach ($prop in $nodes.PSObject.Properties) {
                $node = $prop.Value
                if (-not $node -or -not $node.props) { continue }
                $fid = $null; try { $fid = $node.props.fieldId } catch { }
                if (-not $fid) { continue }
                $k = ([string]$fid).ToLower()
                if (-not $labelOf.ContainsKey($k) -and $node.props.label) {
                    $lbl = $node.props.label -replace '\([^)]*\)','' -replace '\s*[-–—].*$',''
                    $labelOf[$k] = ($lbl -replace '\s{2,}',' ').Trim()
                }
                $hid = $false; try { if ($node.props.hidden) { $hid = $true } } catch { }
                if ($hid) { $hiddenOf[$k] = $true }
            }
        }
    }
}
function FieldLabel([string]$tok) {
    $k = $tok.ToLower()
    if ($labelOf.ContainsKey($k) -and $labelOf[$k]) { return $labelOf[$k] }
    return (Prettify $tok)
}
function IsHidden([string]$tok) { return $hiddenOf.ContainsKey($tok.ToLower()) }

# ── CAD field check (case-insensitive camelCase or PascalCase match) ──────────
function Test-IsCadField([string]$field, $cadList) {
    foreach ($cf in $cadList) {
        if ($cf -ieq $field) { return $true }
        $pascal = $cf[0].ToString().ToUpper() + $cf.Substring(1)
        if ($pascal -eq $field) { return $true }
    }
    return $false
}

# ── Collect CommSys QIDMs ─────────────────────────────────────────────────────
$commSysQidms = @()
foreach ($bundle in $data.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
            $commSysQidms += $cfg
        }
    }
}

# ── Entity display order ──────────────────────────────────────────────────────
$order = @()
$entBundle = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' } | Select-Object -First 1
try { if ($entBundle.order.default) { $order = @($entBundle.order.default) } } catch { }
if (-not $order -or $order.Count -eq 0) {
    foreach ($q in $commSysQidms) {
        if ($q.targetEntity -and ($order -notcontains $q.targetEntity)) { $order += [string]$q.targetEntity }
    }
}

# ── Per-entity analysis and HTML ──────────────────────────────────────────────
$summaryData    = [System.Collections.Generic.List[object]]::new()
$entitySections = [System.Text.StringBuilder]::new()
$globalNotCovered = @{}  # fieldId -> entities that needed it but CAD doesn't provide

foreach ($ent in $order) {
    $entQidms = $commSysQidms | Where-Object { [string]$_.targetEntity -eq $ent }
    if (-not $entQidms) { continue }
    $cadList = @(); if ($cadConfig.$ent) { $cadList = @($cadConfig.$ent) }

    $trigRows    = [System.Text.StringBuilder]::new()
    $officerRows = [System.Text.StringBuilder]::new()
    $trigCount = 0; $officerCount = 0

    foreach ($qidm in $entQidms) {
        foreach ($combo in $qidm.combinations) {
            $kr       = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
            $setFields = @(); if ($combo.requirements -and $combo.requirements.set) { $setFields = @($combo.requirements.set) }
            $anyFields = @(); if ($combo.requirements -and $combo.requirements.any) { $anyFields = @($combo.requirements.any) }
            $defaults  = @(); if ($combo.defaults) { $defaults = @($combo.defaults) }

            # Classify each visible set[] field
            $cadSet = @(); $defSet = @(); $missingSet = @()
            foreach ($f in $setFields) {
                if (IsHidden $f) { continue }
                if (Test-IsCadField $f $cadList)                                      { $cadSet     += $f }
                elseif ($defaults | Where-Object { $_.field -eq $f } | Select-Object -First 1) { $defSet  += $f }
                else                                                                   { $missingSet += $f }
            }

            if ($missingSet.Count -gt 0) {
                # Officer-only combo
                $officerCount++
                foreach ($f in $missingSet) {
                    if (-not $globalNotCovered.ContainsKey($f)) { $globalNotCovered[$f] = @() }
                    if ($globalNotCovered[$f] -notcontains $ent) { $globalNotCovered[$f] += $ent }
                }
                $missingHtml = ($missingSet | ForEach-Object { "<span class='miss'>$(Esc (FieldLabel $_))</span>" }) -join ', '
                $qname = if ($qidm.queryLabel) { [string]$qidm.queryLabel } else { Prettify ([string]$qidm.query -replace 'Query$','') }
                [void]$officerRows.AppendLine("<tr><td class='kr'>$(Esc $kr)</td><td>$missingHtml</td><td class='qn'>$(Esc $qname)</td></tr>")
            } else {
                # CAD-triggerable combo
                $trigCount++
                $cadHtml = if ($cadSet.Count  -gt 0) { ($cadSet  | ForEach-Object { Esc (FieldLabel $_) }) -join ', '                                  } else { '&mdash;' }
                $defHtml = if ($defSet.Count  -gt 0) { ($defSet  | ForEach-Object { "<span class='defv'>$(Esc (FieldLabel $_))</span>" }) -join ', ' } else { '&mdash;' }
                $optParts = @()
                foreach ($f in $anyFields) {
                    if (IsHidden $f) { continue }
                    if (Test-IsCadField $f $cadList) { $optParts += "<span class='cad-opt'>$(Esc (FieldLabel $f))</span>" }
                    else                             { $optParts += Esc (FieldLabel $f) }
                }
                $optHtml = if ($optParts.Count -gt 0) { $optParts -join ', ' } else { '&mdash;' }
                [void]$trigRows.AppendLine("<tr><td class='kr'>$(Esc $kr)</td><td class='cc'>$cadHtml</td><td class='dc'>$defHtml</td><td class='oc'>$optHtml</td></tr>")
            }
        }
    }

    $summaryData.Add([PSCustomObject]@{ Entity=$ent; Trig=$trigCount; Officer=$officerCount })

    [void]$entitySections.AppendLine("<section class='entity'><h2>$(Esc $ent)</h2>")
    if ($trigCount -gt 0) {
        [void]$entitySections.AppendLine("<table class='ct'><caption>CAD auto-triggered &mdash; $trigCount combo$(if($trigCount -ne 1){'s'})</caption>")
        [void]$entitySections.AppendLine("<thead><tr><th class='kr'>Combo</th><th class='cc'>CAD provides</th><th class='dc'>Defaulted</th><th class='oc'>Officer can add</th></tr></thead>")
        [void]$entitySections.AppendLine("<tbody>$($trigRows.ToString())</tbody></table>")
    } else {
        [void]$entitySections.AppendLine("<p class='notrg'>No combos CAD-triggerable for this entity &mdash; all require officer input.</p>")
    }
    if ($officerCount -gt 0) {
        [void]$entitySections.AppendLine("<table class='ot'><caption>Requires officer input &mdash; $officerCount combo$(if($officerCount -ne 1){'s'})</caption>")
        [void]$entitySections.AppendLine("<thead><tr><th class='kr'>Combo</th><th>Missing from CAD</th><th class='qn'>Query</th></tr></thead>")
        [void]$entitySections.AppendLine("<tbody>$($officerRows.ToString())</tbody></table>")
    }
    [void]$entitySections.AppendLine("</section>")
}

# ── Summary table ─────────────────────────────────────────────────────────────
$summaryHtml = [System.Text.StringBuilder]::new()
[void]$summaryHtml.AppendLine("<table class='sum'><thead><tr><th>Entity</th><th>CAD-triggerable</th><th>Officer input required</th></tr></thead><tbody>")
$totalTrig = 0; $totalOfficer = 0
foreach ($row in $summaryData) {
    $cls = if ($row.Trig -eq 0) { 'zero' } elseif ($row.Officer -eq 0) { 'full' } else { 'part' }
    [void]$summaryHtml.AppendLine("<tr class='$cls'><td>$(Esc $row.Entity)</td><td>$($row.Trig)</td><td>$($row.Officer)</td></tr>")
    $totalTrig    += $row.Trig
    $totalOfficer += $row.Officer
}
[void]$summaryHtml.AppendLine("<tr class='tot'><td><b>Total</b></td><td><b>$totalTrig</b></td><td><b>$totalOfficer</b></td></tr></tbody></table>")

# ── Insights ──────────────────────────────────────────────────────────────────
$insights = [System.Collections.Generic.List[string]]::new()

# Cross-entity name field coverage
$nameEntities = @()
foreach ($ent in $order) {
    $cadList = @(); if ($cadConfig.$ent) { $cadList = @($cadConfig.$ent) }
    if (($cadList | Where-Object { $_ -eq 'nameFirst' -or $_ -eq 'nameLast' }).Count -ge 2) { $nameEntities += $ent }
}
if ($nameEntities.Count -gt 1) {
    $insights.Add("&#8680; <b>Name queries fire across multiple entities.</b> CAD sends nameFirst/nameLast for: $($nameEntities -join ', '). A subject name on a CAD incident auto-triggers queries on all these entities simultaneously.")
}

# Zero-CAD entities + why
foreach ($row in ($summaryData | Where-Object { $_.Trig -eq 0 })) {
    $ent = $row.Entity
    $fields = ($globalNotCovered.Keys | Where-Object { $globalNotCovered[$_] -contains $ent } | Sort-Object) -join ', '
    $insights.Add("&#8680; <b>$(Esc $ent): always officer-initiated.</b> CAD does not provide the required fields: <code>$fields</code>. These may use form-specific naming (e.g. DH-suffix fieldIds) or represent data not part of standard CAD dispatch events.")
}

# Fields absent from CAD that block combos
$keyAbsent = $globalNotCovered.Keys | Where-Object {
    $_ -notmatch '(?i)(DH|purposeCode[^$])' -and $_ -notin @('purposeCode') -and $globalNotCovered[$_].Count -ge 1
} | Sort-Object
foreach ($f in $keyAbsent) {
    $ents = $globalNotCovered[$f] -join ', '
    $insights.Add("&#8680; <b><code>$(Esc $f)</code> not in CAD field list</b> for entity: $ents. Combos requiring this field will never auto-trigger from CAD.")
}

$insightsHtml = ''
if ($insights.Count -gt 0) {
    $items = ($insights | ForEach-Object { "<li>$_</li>" }) -join "`n"
    $insightsHtml = "<section class='ins'><h2>Integration Insights</h2><ul>$items</ul></section>"
}

# ── CSS + HTML ────────────────────────────────────────────────────────────────
$css = @"
@page { size: portrait; margin: 0.6cm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', Arial, sans-serif; color:#1a1a1a; font-size: 8.5pt; line-height:1.3; margin:0; padding:4px 8px; }
h1 { font-size:15pt; margin:0 0 2px; }
.sub { color:#444; font-size:8pt; margin:0 0 8px; }
table.sum { width:100%; border-collapse:collapse; margin:0 0 10px; font-size:8.5pt; }
table.sum th { background:#1f3b57; color:#fff; padding:3px 8px; text-align:left; }
table.sum td { border:1px solid #cdd8e3; padding:2px 8px; }
tr.full td:nth-child(2) { color:#155724; font-weight:600; }
tr.zero td:nth-child(2) { color:#999; }
tr.zero td:nth-child(3) { color:#7a1f1f; font-weight:600; }
tr.part td:nth-child(2) { color:#155724; }
tr.part td:nth-child(3) { color:#856404; }
tr.tot td { border-top:2px solid #1f3b57; background:#f4f7fb; }
section.entity { margin:0 0 8px; page-break-inside:avoid; }
h2 { font-size:10.5pt; background:#1f3b57; color:#fff; padding:3px 7px; border-radius:3px; margin:7px 0 3px; }
table.ct, table.ot { width:100%; border-collapse:collapse; margin:0 0 4px; table-layout:fixed; }
table.ct caption, table.ot caption { caption-side:top; text-align:left; font-weight:600; font-size:8.5pt; padding:1px 0 2px; }
table.ct caption { color:#155724; }
table.ot caption { color:#856404; }
table.ct th, table.ct td, table.ot th, table.ot td { border:1px solid #cdd8e3; padding:2px 5px; text-align:left; vertical-align:top; overflow-wrap:break-word; font-size:8pt; }
table.ct thead th, table.ot thead th { background:#eef3f8; font-weight:700; }
th.kr, td.kr { width:16%; font-weight:600; font-family:monospace; font-size:7.5pt; }
th.cc, td.cc { width:28%; color:#1a3a6c; font-weight:500; }
th.dc, td.dc { width:18%; }
th.oc, td.oc { width:38%; color:#3a5a3a; }
th.qn, td.qn { width:38%; color:#555; font-style:italic; }
.defv { color:#6c4f00; font-style:italic; }
.cad-opt { color:#1a3a6c; }
.miss { color:#7a1f1f; font-weight:600; }
.notrg { color:#856404; font-size:8pt; padding:3px 0; margin:0 0 4px; }
section.ins { margin:8px 0 0; page-break-before:auto; }
section.ins h2 { background:#2d4a1f; }
section.ins ul { margin:4px 0; padding-left:16px; }
section.ins li { margin:3px 0; font-size:8pt; }
code { font-family:monospace; font-size:8pt; background:#f0f0f0; padding:0 2px; border-radius:2px; }
footer { margin-top:8px; border-top:1px solid #ccc; padding-top:4px; color:#777; font-size:7.5pt; }
"@

$html = @"
<!DOCTYPE html><html><head><meta charset='utf-8'>
<title>$(Esc $providerName) - CAD Auto-Dispatch Reference</title>
<style>$css</style></head><body>
<h1>$(Esc $providerName) &mdash; CAD Auto-Dispatch Reference</h1>
<p class='sub'>Shows which queries fire automatically when CAD sends incident data vs those requiring officer input. <b style='color:#1a3a6c'>Blue</b> = CAD provides. <span style='color:#6c4f00;font-style:italic'>Italic</span> = defaulted. <span style='color:#3a5a3a'>Green</span> = officer can add. <span style='color:#7a1f1f;font-weight:600'>Red</span> = officer must enter (blocks CAD auto-trigger).</p>
$($summaryHtml.ToString())
$($entitySections.ToString())
$insightsHtml
<footer>$(Esc $providerName) &middot; Generated $genDate &middot; CAD field source: cad_field_mapping.json &middot; Draft reference only.</footer>
</body></html>
"@

$html | Out-File -FilePath $OutFile -Encoding utf8NoBOM
Write-Host "CAD guide HTML: $OutFile" -ForegroundColor Green

if ($PdfFile) {
    $edge = $null
    foreach ($cand in @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )) { if ($cand -and (Test-Path $cand)) { $edge = $cand; break } }
    if (-not $edge) {
        Write-Host "[NOTE] Edge/Chrome not found -- PDF skipped; open HTML and Print > Save as PDF." -ForegroundColor Yellow
    } else {
        $htmlFull = (Resolve-Path $OutFile).Path
        $pdfFull  = [System.IO.Path]::GetFullPath($PdfFile)
        $uri      = 'file:///' + ($htmlFull -replace '\\','/')
        & $edge --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=3000 "--print-to-pdf=$pdfFull" $uri 2>$null
        Start-Sleep -Milliseconds 3000
        if (Test-Path $pdfFull) { Write-Host "CAD guide PDF:  $pdfFull" -ForegroundColor Green }
        else { Write-Host "[NOTE] PDF conversion did not produce a file; HTML is available." -ForegroundColor Yellow }
    }
}
