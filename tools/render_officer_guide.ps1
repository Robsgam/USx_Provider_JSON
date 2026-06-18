<#
  render_officer_guide.ps1 -- Officer-facing printable quick-reference for a provider.

  Lists every supported query and, for each way to search, which fields are REQUIRED vs OPTIONAL,
  in plain English. NO internal jargon (no keyRefs, QIDM, set/any). Assumes zero system knowledge.

  Transform of existing data only: CommSys QIDM combos (set[]=required, any[]=optional) + queryLabel
  (officer name) + the QIF field labels (human wording) + defaulted-field detection (pre-filled).

  Usage:
    .\render_officer_guide.ps1 -Path <provider.json> -OutFile <guide.html> [-PdfFile <guide.pdf>]

  PDF is best-effort via Edge headless (--print-to-pdf). If Edge is not found, HTML is still produced.
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$OutFile,
    [string]$PdfFile
)

$ErrorActionPreference = 'Stop'

$resolved = (Resolve-Path $Path).Path
$data = Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
$providerName = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '(?i)_(BASE|MC)$',''
$genDate = Get-Date -Format 'yyyy-MM-dd'

$entitiesBundle = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' } | Select-Object -First 1
$providerBundle = $data.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' } | Select-Object -First 1
if (-not $entitiesBundle) { Write-Error "No ENTITIES bundle"; exit 1 }

function Esc($s) {
    if ($null -eq $s) { return '' }
    return ([string]$s) -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}
# Strip the trailing "(...)" hint from a label so the structure carries required/optional, not the text.
function CleanName([string]$lbl) {
    if (-not $lbl) { return '' }
    $s = $lbl -replace '\([^)]*\)',''        # drop any (...) hint groups, anywhere
    $s = $s -replace '\s*[-–—].*$',''         # drop a trailing " - hint" clause
    return (($s -replace '\s{2,}',' ').Trim())
}
# Prettify a camelCase/PascalCase token: 'operatorLicenseNumber' -> 'Operator License Number'
function Prettify([string]$tok) {
    if (-not $tok) { return '' }
    $t = $tok -creplace '([a-z0-9])([A-Z])','$1 $2'
    return ((Get-Culture).TextInfo.ToTitleCase($t.ToLower()))
}

# --- fieldId -> label, fieldId -> default value, hidden set (from ENTITIES QIFs, default variant) ---
$labelOf = @{}; $valueOf = @{}; $hiddenOf = @{}
foreach ($cfg in $entitiesBundle.configurations) {
    if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
    $lv = $null; try { $lv = $cfg.layout.default } catch { }
    if (-not $lv) { continue }
    foreach ($prop in $lv.PSObject.Properties) {
        $node = $prop.Value
        if (-not $node -or -not $node.props) { continue }
        $fid = $null; try { $fid = $node.props.fieldId } catch { }
        if (-not $fid) { continue }
        $k = ([string]$fid).ToLower()
        if (-not $labelOf.ContainsKey($k)) { $labelOf[$k] = [string]$node.props.label }
        $iv = $null; try { $iv = $node.props.initialValue } catch { }
        if ($null -ne $iv -and "$iv".Trim() -ne '') { $valueOf[$k] = [string]$iv }
        $hid = $false; try { if ($node.props.hidden) { $hid = $true } } catch { }
        if ($hid) { $hiddenOf[$k] = $true }
    }
}

# --- CommSys QIDMs (skip RMS) ---
$qidms = @()
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') { $qidms += $cfg }
    }
}

# attribute name -> sourceField list (per query) and combo defaults -> value
function Get-AttrMap($qidm) {
    $m = @{}
    foreach ($a in @($qidm.attributes)) { if ($a.name) { $m[[string]$a.name] = @($a.sourceField) } }
    return $m
}

# Resolve a field token (sourceField/fieldId) to a clean human name
function FieldName([string]$tok) {
    $k = $tok.ToLower()
    if ($labelOf.ContainsKey($k) -and $labelOf[$k]) { return (CleanName $labelOf[$k]) }
    return (Prettify $tok)
}
function DefaultValue([string]$tok) {
    $k = $tok.ToLower()
    if ($valueOf.ContainsKey($k)) { return $valueOf[$k] }
    return $null
}
function IsHidden([string]$tok) { return $hiddenOf.ContainsKey($tok.ToLower()) }

# Friendly "search by" name for a combo's primaryFieldReference
function PrimaryName($qidm, [string]$primary) {
    if (-not $primary) { return 'any field' }
    $am = Get-AttrMap $qidm
    if ($am.ContainsKey($primary)) {
        $sf = @($am[$primary])
        if ($sf.Count -gt 1 -or $primary -match 'Name') { return 'Name' }
        if ($sf.Count -eq 1) { return (FieldName ([string]$sf[0])) }
    }
    if ($primary -match 'Name') { return 'Name' }
    return (Prettify $primary)
}

# --- entity order ---
$order = @()
try { if ($entitiesBundle.order.default) { $order = @($entitiesBundle.order.default) } } catch { }
if (-not $order -or $order.Count -eq 0) {
    foreach ($q in $qidms) { if ($q.targetEntity -and ($order -notcontains $q.targetEntity)) { $order += [string]$q.targetEntity } }
}

# --- build per-entity sections ---
$sb = [System.Text.StringBuilder]::new()
$firstEntity = $true
foreach ($ent in $order) {
    $entQidms = $qidms | Where-Object { [string]$_.targetEntity -eq $ent }
    if (-not $entQidms) { continue }
    $pb = if ($firstEntity) { '' } else { ' style="page-break-before:always"' }
    $firstEntity = $false
    [void]$sb.AppendLine("<section class='entity'$pb><h2>$(Esc $ent)</h2>")

    foreach ($q in $entQidms) {
        $qlabel = if ($q.queryLabel) { [string]$q.queryLabel } else { (Prettify (([string]$q.query) -replace 'Query$','')) }
        [void]$sb.AppendLine("<div class='query'><h3>$(Esc $qlabel)</h3>")

        # multiple combos may share a primary -> add an in/out/stolen hint to distinguish
        $combos = @($q.combinations)
        $primaryCounts = @{}
        foreach ($c in $combos) { $p = [string]$c.primaryFieldReference; if ($p) { $primaryCounts[$p] = 1 + ([int]$primaryCounts[$p]) } }

        foreach ($c in $combos) {
            $primary = [string]$c.primaryFieldReference
            $hint = ''
            $setFields = @(); if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
            $anyFields = @(); if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }
            # Officer-facing path name: a name-based set reads as "Search by Name" (a SexCode/DOB
            # primaryFieldReference is a metadata routing quirk, not how an officer thinks).
            $hasName = ($setFields | Where-Object { $_ -match '(?i)name' }).Count -gt 0
            if ($hasName) { $pname = 'Name' } else { $pname = PrimaryName $q $primary }
            $isStolen = ($setFields | Where-Object { $_ -match '(?i)relatedHit|stolen' }).Count -gt 0
            if ($isStolen) { $hint = ' (stolen / wanted check)' }
            elseif ($primaryCounts[$primary] -gt 1) {
                if ($c.state -eq 'Out') { $hint = ' (out-of-state)' } elseif ($c.state -eq 'In') { $hint = ' (in-state)' }
            }

            # required (set) and optional (any) -> human lines, skipping hidden
            $reqParts = @()
            foreach ($f in $setFields) {
                $fs = [string]$f; if (IsHidden $fs) { continue }
                $nm = FieldName $fs; $dv = DefaultValue $fs
                if ($dv) { $reqParts += "$nm <span class='pre'>(pre-filled: $(Esc $dv) — change if needed)</span>" }
                else { $reqParts += (Esc $nm) }
            }
            $optParts = @()
            foreach ($f in $anyFields) {
                $fs = [string]$f; if (IsHidden $fs) { continue }
                $nm = FieldName $fs; $dv = DefaultValue $fs
                if ($dv) { $optParts += "$(Esc $nm) <span class='pre'>(pre-filled: $(Esc $dv))</span>" }
                else { $optParts += (Esc $nm) }
            }
            if ($reqParts.Count -eq 0 -and $optParts.Count -eq 0) { continue }

            [void]$sb.AppendLine("<div class='path'><div class='pathname'>Search by $(Esc $pname)$(Esc $hint)</div>")
            if ($reqParts.Count -gt 0) { [void]$sb.AppendLine("<div class='req'><span class='lbl'>Must enter:</span> $($reqParts -join ', ')</div>") }
            if ($optParts.Count -gt 0) { [void]$sb.AppendLine("<div class='opt'><span class='lbl'>You can also add:</span> $($optParts -join ', ')</div>") }
            [void]$sb.AppendLine("</div>")
        }
        [void]$sb.AppendLine("</div>")
    }
    [void]$sb.AppendLine("</section>")
}

$css = @"
@page { margin: 2cm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', Arial, sans-serif; color:#1a1a1a; font-size: 12pt; line-height:1.4; max-width: 820px; margin: 0 auto; padding: 16px; }
h1 { font-size: 20pt; margin: 0 0 4px; }
.howto { color:#444; font-size: 11pt; margin: 0 0 18px; }
h2 { font-size: 16pt; background:#1f3b57; color:#fff; padding:6px 10px; border-radius:4px; margin: 18px 0 10px; }
h3 { font-size: 13.5pt; color:#1f3b57; margin: 14px 0 6px; border-bottom:2px solid #cdd8e3; padding-bottom:2px; }
.path { margin: 0 0 8px 6px; padding:6px 10px; border-left:3px solid #4a7ba6; background:#f5f8fb; border-radius:0 4px 4px 0; }
.pathname { font-weight:600; margin-bottom:2px; }
.req .lbl { color:#7a1f1f; font-weight:600; }
.opt .lbl { color:#3a5a3a; font-weight:600; }
.opt { color:#333; }
.pre { color:#666; font-style:italic; font-size: 10.5pt; }
footer { margin-top:24px; border-top:1px solid #ccc; padding-top:6px; color:#777; font-size:10pt; }
"@

$html = @"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>$(Esc $providerName) — Officer Query Guide</title>
<style>$css</style></head><body>
<h1>$(Esc $providerName) — Query Guide</h1>
<p class='howto'>Pick the entity, choose how you want to search, then fill the fields marked <b>Must enter</b>. Pre-filled fields are set for you — change them only if needed.</p>
$($sb.ToString())
<footer>$(Esc $providerName) &middot; Generated $genDate &middot; Reference only — supported search paths and field requirements.</footer>
</body></html>
"@

$html | Out-File -FilePath $OutFile -Encoding utf8NoBOM
Write-Host "Officer guide HTML: $OutFile" -ForegroundColor Green

if ($PdfFile) {
    $edge = $null
    foreach ($cand in @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )) { if ($cand -and (Test-Path $cand)) { $edge = $cand; break } }
    if (-not $edge) {
        Write-Host "[NOTE] Edge/Chrome not found -- PDF skipped; HTML produced (open it and Print > Save as PDF)." -ForegroundColor Yellow
    } else {
        $htmlFull = (Resolve-Path $OutFile).Path
        $pdfFull  = [System.IO.Path]::GetFullPath($PdfFile)
        $uri = 'file:///' + ($htmlFull -replace '\\','/')
        & $edge --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=3000 "--print-to-pdf=$pdfFull" $uri 2>$null
        Start-Sleep -Milliseconds 1200
        if (Test-Path $pdfFull) { Write-Host "Officer guide PDF: $pdfFull" -ForegroundColor Green }
        else { Write-Host "[NOTE] PDF conversion did not produce a file; HTML is available (open it and Print > Save as PDF)." -ForegroundColor Yellow }
    }
}
