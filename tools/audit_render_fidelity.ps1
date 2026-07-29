<#
  audit_render_fidelity.ps1 -- RENDER GATE, classified by LABELS and FIELD ORDER.

  Compares each entity's CAPTURED rendered form (DOM snapshot from the live tenant) against
  the EXPECTED manifest derived from the provider JSON, and FAILs on any label mismatch,
  missing/extra field, visual reorder, or card-title drift.

  WHY THIS EXISTS (Rob's directive 2026-07-29: "render should be classified with the labels
  and field ordering"):
    Render was the only gate with no machine check. audit_form_review.ps1 records only THAT a
    human looked at a build, never WHAT they saw -- so every label/title/ordering defect in
    2026-07 was caught by eye, and "render PASSED" was an assertion nothing verified.
    JSON-side checks cannot substitute: the retired Convert-UsxCasing recase collapsed Craft.js
    `nodes` lists and forms silently rendered as tab names only while every validator passed.
    Only a JSON-vs-DOM comparison catches that class.

  EVIDENCE CHANNEL -- deliberately NOT the wire-XML test plan. A render test has no CommSys
  request at all, so it cannot ride the fill->submit->scrape-dex-log->infer-combo pipeline that
  import_captured_tests.ps1 implements. Forcing it in would also hit the phantom-owed trap
  documented in _content_match.ps1 (the import path names logs from comboKeyRef/kind/anyField,
  so a test the importer can't name reads as permanently owed -- 7 phantom FL_FCIC tests,
  2026-07-29). Render therefore lives in its own per-entity snapshot file:

      providers/<PROVIDER>/logs/_render/<Entity>_v<X.Y>.json     (produced by __usxCaptureRender)

  Version-stamped, so a rebuild does not silently inherit the prior version's render proof.

  Usage:
    .\audit_render_fidelity.ps1 -Path providers\TX_TLETS\TX_TLETS_v4.13.json
    .\audit_render_fidelity.ps1 -Path <json> -OutFile <report.txt>
#>

param(
    [Parameter(Mandatory)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_render_manifest.ps1"

$lines = New-Object System.Collections.Generic.List[string]
function Out-Line($s) { $lines.Add($s); Write-Host $s }
function Out-Pass($s) { $lines.Add("  [PASS] $s"); Write-Host "  [PASS] $s" -ForegroundColor Green }
function Out-Fail($s) { $lines.Add("  [FAIL] $s"); Write-Host "  [FAIL] $s" -ForegroundColor Red }
function Out-Info($s) { $lines.Add("  [INFO] $s"); Write-Host "  [INFO] $s" -ForegroundColor DarkGray }

$jsonPath = (Resolve-Path $Path).Path
$provDir  = Split-Path $jsonPath -Parent
$provName = Split-Path $provDir -Leaf

$version = 'unknown'
if ((Split-Path $jsonPath -Leaf) -match 'v(\d+\.\d+)\.json$') { $version = $Matches[1] }

$json = [System.IO.File]::ReadAllText($jsonPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json

# ENTITIES bundle = the QIFs (provider MARK43). Entities are whatever the JSON actually defines.
$qifs = @()
foreach ($b in $json.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTFORM' -or ($c.layout -and $c.targetEntity)) { $qifs += $c }
    }
}
$qifs = @($qifs | Where-Object { $_.targetEntity })

Out-Line ""
Out-Line "============================================================"
Out-Line "  RENDER FIDELITY -- $provName v$version"
Out-Line "  labels + field ORDER, JSON (expected) vs rendered DOM (actual)"
Out-Line "============================================================"

$renderDir = Join-Path $provDir "logs\_render"
$failCount = 0; $passCount = 0; $missingCount = 0

foreach ($qif in ($qifs | Sort-Object { "$($_.targetEntity)" })) {
    $ent = "$($qif.targetEntity)"
    $expected = Get-QifRenderManifest -Qif $qif -Variant 'default'

    if (-not $expected) {
        Out-Fail "$ent -- no 'default' layout variant in the JSON (cannot derive expected render)"
        $failCount++
        continue
    }

    $expFields = @(Get-RmFlatFields $expected)
    $snapPath = Join-Path $renderDir "${ent}_v${version}.json"

    if (-not (Test-Path $snapPath)) {
        # Not a FAIL on its own -- it is owed work, reported as such. enforce decides whether
        # a missing render snapshot blocks (it does, for a provider being declared DONE).
        Out-Info "$ent -- no render snapshot at logs\_render\${ent}_v${version}.json ($($expFields.Count) visible field(s) expected) -- OWED"
        $missingCount++
        continue
    }

    $actual = Get-Content $snapPath -Raw | ConvertFrom-Json
    if (-not $actual.cards) {
        Out-Fail "$ent -- render snapshot present but has no 'cards' array (malformed capture)"
        $failCount++
        continue
    }

    $findings = @(Compare-RenderManifest -Expected $expected -Actual $actual)
    if ($findings.Count -eq 0) {
        Out-Pass "$ent -- rendered form matches the JSON ($($expFields.Count) field(s), labels + order verified)"
        $passCount++
    } else {
        Out-Fail "$ent -- $($findings.Count) render divergence(s):"
        foreach ($f in $findings) {
            $lines.Add("           [$($f.Kind)] $($f.FieldId): $($f.Message)")
            Write-Host "           [$($f.Kind)] $($f.FieldId): $($f.Message)" -ForegroundColor Yellow
        }
        $failCount++
    }
}

Out-Line ""
Out-Line "------------------------------------------------------------"
$verdict = if ($failCount -gt 0) { "FAIL" } else { "PASS" }
Out-Line "  RESULTS: $passCount verified / $failCount divergent / $missingCount owed (no snapshot)  -> $verdict"
Out-Line "------------------------------------------------------------"
if ($missingCount -gt 0) {
    Out-Line "  Capture the owed snapshots: render the entity form in the tenant, then run"
    Out-Line "    __usxCaptureRender('<Entity>')"
    Out-Line "  in the console and move the download into logs\_render\."
}
Out-Line ""

if ($OutFile) {
    [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Report: $OutFile" -ForegroundColor DarkGray
}

if ($failCount -gt 0) { exit 1 }
exit 0
