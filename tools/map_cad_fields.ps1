<#
  map_cad_fields.ps1 -- CAD Field Mapping & Patch 8 Rename Generator
  Compares CAD integration field names against provider JSON fieldIds
  and generates the Patch 8 rename map automatically.

  Prevents manual casing mistakes (e.g. LicensePlateNumberIn -> camelCase
  instead of PascalCase in NJ MC Patch 8).

  Usage:
    .\map_cad_fields.ps1 -Path <provider.json> -CadFields "licensePlateNumber,registrationState,..."
    .\map_cad_fields.ps1 -Path <provider.json> -CadFields cad_fields.txt
    .\map_cad_fields.ps1 -Path <provider.json> -CadFields cad_fields.txt -GeneratePatch
    .\map_cad_fields.ps1 -Path <provider.json> -CadFields cad_fields.txt -OutFile report.txt
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [string]$CadFields,
    [string]$OutFile,
    [switch]$GeneratePatch
)

$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-Status($msg, $color) { Write-Host $msg -ForegroundColor $color }
function Write-Match($msg)    { Write-Host "  [MATCH]         $msg" -ForegroundColor Green }
function Write-Mismatch($msg) { Write-Host "  [CASE_MISMATCH] $msg" -ForegroundColor Yellow }
function Write-NoMatch($msg)  { Write-Host "  [NO_MATCH]      $msg" -ForegroundColor Red }
function Write-Extra($msg)    { Write-Host "  [EXTRA]         $msg" -ForegroundColor DarkGray }

# ── Validate input ───────────────────────────────────────────────────────────
if (-not (Test-Path $Path)) {
    Write-Host "  [FAIL] File not found: $Path" -ForegroundColor Red
    exit 1
}

# ── Parse CAD fields: file path or comma-separated string ────────────────────
$cadFieldList = @()
if (Test-Path $CadFields -ErrorAction SilentlyContinue) {
    $cadFieldList = @(Get-Content $CadFields | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    Write-Status "  Loaded $($cadFieldList.Count) CAD fields from file: $CadFields" Gray
} else {
    $cadFieldList = @($CadFields -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-Status "  Parsed $($cadFieldList.Count) CAD fields from parameter" Gray
}

if ($cadFieldList.Count -eq 0) {
    Write-Host "  [FAIL] No CAD fields provided. Supply comma-separated names or a file path." -ForegroundColor Red
    exit 1
}

# ── Load JSON ────────────────────────────────────────────────────────────────
$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json
$jsonName = [System.IO.Path]::GetFileNameWithoutExtension($Path)

# ── Extract all QIF fieldIds (from layout nodes) ────────────────────────────
$formFieldIds = [System.Collections.Generic.HashSet[string]]::new()
$fieldIdByEntity = @{}

$formTypes = @('FormInput','FormSelect','FormDate','FormCheckbox')

foreach ($bundle in $json.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        $entity = $cfg.targetEntity
        if (-not $fieldIdByEntity.ContainsKey($entity)) {
            $fieldIdByEntity[$entity] = [System.Collections.Generic.HashSet[string]]::new()
        }

        # Scan all three layout variants
        $variants = @('default','CAD_DISPATCH','FIRST_RESPONDER')
        foreach ($variant in $variants) {
            $layoutObj = $null
            try { $layoutObj = $cfg.layout.PSObject.Properties[$variant].Value } catch { continue }
            if (-not $layoutObj) { continue }

            foreach ($prop in $layoutObj.PSObject.Properties) {
                $node = $prop.Value
                if (-not $node) { continue }
                $resolved = $null
                try { $resolved = $node.type.resolvedName } catch { continue }
                if ($resolved -notin $formTypes) { continue }

                $fid = $null
                try { $fid = $node.props.fieldId } catch { }
                if ($fid) {
                    [void]$formFieldIds.Add($fid)
                    [void]$fieldIdByEntity[$entity].Add($fid)
                }
            }
        }
    }
}

# ── Extract all QIDM sourceField values ─────────────────────────────────────
$qidmSourceFields = [System.Collections.Generic.HashSet[string]]::new()
$rmsSourceFields  = [System.Collections.Generic.HashSet[string]]::new()

foreach ($bundle in $json.bundles) {
    $isRms = ($bundle.provider -eq 'RMS' -or $bundle.name -eq 'RMS')
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if (-not $cfg.attributes) { continue }

        foreach ($attr in $cfg.attributes) {
            if (-not $attr.sourceField) { continue }
            foreach ($sf in $attr.sourceField) {
                if ($isRms) {
                    [void]$rmsSourceFields.Add($sf)
                } else {
                    [void]$qidmSourceFields.Add($sf)
                }
            }
        }
    }
}

# ── Build master set of all JSON field names ────────────────────────────────
$allJsonFields = [System.Collections.Generic.HashSet[string]]::new()
foreach ($f in $formFieldIds)     { [void]$allJsonFields.Add($f) }
foreach ($f in $qidmSourceFields) { [void]$allJsonFields.Add($f) }
foreach ($f in $rmsSourceFields)  { [void]$allJsonFields.Add($f) }

# ── Detect variant: camelCase (BASE) vs PascalCase (MC) ─────────────────────
$camelCount = 0
$pascalCount = 0
foreach ($f in $formFieldIds) {
    if ($f.Length -eq 0) { continue }
    # Skip known all-lowercase or special fields (e.g. dexStateUserId)
    if ($f[0] -cmatch '[a-z]') { $camelCount++ }
    elseif ($f[0] -cmatch '[A-Z]') { $pascalCount++ }
}
$detectedVariant = if ($camelCount -gt $pascalCount) { "BASE (camelCase)" } else { "MC (PascalCase)" }

# ── Build case-insensitive lookup: lowercase -> actual field name ────────────
$jsonFieldLookup = @{}
foreach ($f in $allJsonFields) {
    $key = $f.ToLower()
    if (-not $jsonFieldLookup.ContainsKey($key)) {
        $jsonFieldLookup[$key] = $f
    }
}

# ── Compare CAD fields against JSON fields ──────────────────────────────────
$results = @()
$matchedJsonFields = [System.Collections.Generic.HashSet[string]]::new()

foreach ($cadField in $cadFieldList) {
    $cadLower = $cadField.ToLower()
    $status = ""
    $jsonField = ""
    $note = ""

    if ($jsonFieldLookup.ContainsKey($cadLower)) {
        $jsonField = $jsonFieldLookup[$cadLower]
        [void]$matchedJsonFields.Add($jsonField)

        if ($cadField -ceq $jsonField) {
            $status = "MATCH"
            $note = "Exact match"
        } else {
            $status = "CASE_MISMATCH"
            $note = "Rename needed: $jsonField -> $cadField"
        }
    } else {
        $status = "NO_MATCH"
        $jsonField = "--"
        $note = "CAD field not found in JSON"
    }

    $results += [PSCustomObject]@{
        CadField  = $cadField
        JsonField = $jsonField
        Status    = $status
        Note      = $note
    }
}

# ── Find EXTRA fields (in JSON but not in CAD list) ─────────────────────────
$extraFields = @()
foreach ($jf in $allJsonFields) {
    if (-not $matchedJsonFields.Contains($jf)) {
        $cadMatch = $cadFieldList | Where-Object { $_.ToLower() -eq $jf.ToLower() }
        if (-not $cadMatch) {
            $extraFields += $jf
        }
    }
}

# ── Counts ───────────────────────────────────────────────────────────────────
$matchCount    = @($results | Where-Object { $_.Status -eq 'MATCH' }).Count
$mismatchCount = @($results | Where-Object { $_.Status -eq 'CASE_MISMATCH' }).Count
$noMatchCount  = @($results | Where-Object { $_.Status -eq 'NO_MATCH' }).Count
$extraCount    = $extraFields.Count

# ── Build rename map ─────────────────────────────────────────────────────────
$renameEntries = @()
foreach ($r in ($results | Where-Object { $_.Status -eq 'CASE_MISMATCH' })) {
    $renameEntries += [PSCustomObject]@{
        From = $r.JsonField
        To   = $r.CadField
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT
# ══════════════════════════════════════════════════════════════════════════════
$outputLines = @()

$outputLines += ""
$outputLines += "=" * 70
$outputLines += "  CAD FIELD MAPPING REPORT: $jsonName"
$outputLines += "  Source: $(Split-Path $Path -Leaf)"
$outputLines += "  Detected variant: $detectedVariant"
$outputLines += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$outputLines += "=" * 70
$outputLines += ""
$outputLines += "  QIF fieldIds:        $($formFieldIds.Count)"
$outputLines += "  QIDM sourceFields:   $($qidmSourceFields.Count)"
$outputLines += "  RMS sourceFields:    $($rmsSourceFields.Count)"
$outputLines += "  Unique JSON fields:  $($allJsonFields.Count)"
$outputLines += "  CAD fields provided: $($cadFieldList.Count)"
$outputLines += ""

# ── Per-entity breakdown ────────────────────────────────────────────────────
$outputLines += "--- QIF Fields by Entity ---"
foreach ($entity in ($fieldIdByEntity.Keys | Sort-Object)) {
    $fields = @($fieldIdByEntity[$entity]) | Sort-Object
    $outputLines += "  $entity ($($fields.Count)): $($fields -join ', ')"
}
$outputLines += ""

# ── Results table ────────────────────────────────────────────────────────────
$outputLines += "--- Field Comparison ---"
$outputLines += ""

# Column widths
$cadW  = [Math]::Max(10, ($cadFieldList | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum + 2)
$jsonW = [Math]::Max(10, ($allJsonFields | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum + 2)
$statW = 16

$header = "  {0,-$cadW} {1,-$jsonW} {2,-$statW} {3}" -f "CAD Field", "JSON Field", "Status", "Note"
$sep    = "  " + ("-" * ($cadW + $jsonW + $statW + 30))
$outputLines += $header
$outputLines += $sep

foreach ($r in $results) {
    $line = "  {0,-$cadW} {1,-$jsonW} {2,-$statW} {3}" -f $r.CadField, $r.JsonField, $r.Status, $r.Note
    $outputLines += $line
}

# Extra fields
if ($extraFields.Count -gt 0) {
    $outputLines += ""
    $outputLines += "--- Extra JSON Fields (not in CAD list) ---"
    foreach ($ef in ($extraFields | Sort-Object)) {
        $location = @()
        if ($formFieldIds.Contains($ef))     { $location += "QIF" }
        if ($qidmSourceFields.Contains($ef)) { $location += "QIDM" }
        if ($rmsSourceFields.Contains($ef))  { $location += "RMS" }
        $outputLines += "  {0,-$jsonW} [{1}]" -f $ef, ($location -join ', ')
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
$outputLines += ""
$outputLines += "--- Summary ---"
$outputLines += "  MATCH:          $matchCount"
$outputLines += "  CASE_MISMATCH:  $mismatchCount (rename needed)"
$outputLines += "  NO_MATCH:       $noMatchCount (CAD field not in JSON)"
$outputLines += "  EXTRA:          $extraCount (JSON field not in CAD list)"
$outputLines += ""

if ($mismatchCount -eq 0 -and $noMatchCount -eq 0) {
    $outputLines += "  Result: ALL CAD FIELDS MATCH -- no Patch 8 rename needed"
} elseif ($mismatchCount -gt 0) {
    $outputLines += "  Result: $mismatchCount field(s) need casing rename in Patch 8"
}
$outputLines += ""

# ── Patch 8 rename map ──────────────────────────────────────────────────────
if ($GeneratePatch -or $renameEntries.Count -gt 0) {
    $outputLines += "--- Patch 8 Rename Map ---"
    $outputLines += ""
    if ($renameEntries.Count -eq 0) {
        $outputLines += "  # No renames needed -- all fields match exactly"
    } else {
        $outputLines += '  $cadRenames = @{'

        # Align the arrows for readability
        $maxFrom = ($renameEntries | ForEach-Object { $_.From.Length } | Measure-Object -Maximum).Maximum
        foreach ($entry in ($renameEntries | Sort-Object { $_.From })) {
            $padding = ' ' * ($maxFrom - $entry.From.Length)
            $outputLines += "      '$($entry.From)'$padding = '$($entry.To)'"
        }

        $outputLines += '  }'
        $outputLines += ""
        $outputLines += "  # Apply in build script:"
        $outputLines += '  # foreach ($old in $cadRenames.Keys) {'
        $outputLines += '  #     $newName = $cadRenames[$old]'
        $outputLines += '  #     $jsonText = $jsonText -creplace [regex]::Escape($old), $newName'
        $outputLines += '  # }'
    }
    $outputLines += ""
}

# ── Console output with colors ───────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  CAD FIELD MAPPING REPORT: $jsonName" -ForegroundColor Cyan
Write-Host "  Detected variant: $detectedVariant" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "  QIF fieldIds:        $($formFieldIds.Count)" -ForegroundColor Gray
Write-Host "  QIDM sourceFields:   $($qidmSourceFields.Count)" -ForegroundColor Gray
Write-Host "  RMS sourceFields:    $($rmsSourceFields.Count)" -ForegroundColor Gray
Write-Host "  Unique JSON fields:  $($allJsonFields.Count)" -ForegroundColor Gray
Write-Host "  CAD fields provided: $($cadFieldList.Count)" -ForegroundColor Gray
Write-Host ""

# Colored result rows
foreach ($r in $results) {
    switch ($r.Status) {
        'MATCH'         { Write-Match    "$($r.CadField) = $($r.JsonField)" }
        'CASE_MISMATCH' { Write-Mismatch "$($r.CadField) != $($r.JsonField) -- $($r.Note)" }
        'NO_MATCH'      { Write-NoMatch  "$($r.CadField) -- not in JSON" }
    }
}

if ($extraFields.Count -gt 0) {
    Write-Host ""
    Write-Host "  Extra JSON fields ($extraCount not in CAD list):" -ForegroundColor DarkGray
    foreach ($ef in ($extraFields | Sort-Object)) {
        Write-Extra $ef
    }
}

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Cyan
Write-Host "  MATCH:          $matchCount" -ForegroundColor Green
if ($mismatchCount -gt 0) {
    Write-Host "  CASE_MISMATCH:  $mismatchCount (rename needed)" -ForegroundColor Yellow
} else {
    Write-Host "  CASE_MISMATCH:  0" -ForegroundColor Green
}
if ($noMatchCount -gt 0) {
    Write-Host "  NO_MATCH:       $noMatchCount (CAD field not in JSON)" -ForegroundColor Red
} else {
    Write-Host "  NO_MATCH:       0" -ForegroundColor Green
}
Write-Host "  EXTRA:          $extraCount (JSON field not in CAD list)" -ForegroundColor DarkGray

if ($mismatchCount -gt 0 -and ($GeneratePatch -or $true)) {
    Write-Host ""
    Write-Host "--- Patch 8 Rename Map ---" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  $cadRenames = @{' -ForegroundColor White

    $maxFrom = ($renameEntries | ForEach-Object { $_.From.Length } | Measure-Object -Maximum).Maximum
    foreach ($entry in ($renameEntries | Sort-Object { $_.From })) {
        $padding = ' ' * ($maxFrom - $entry.From.Length)
        Write-Host "      '$($entry.From)'$padding = '$($entry.To)'" -ForegroundColor White
    }

    Write-Host '  }' -ForegroundColor White
}

Write-Host ""

# ── File output ──────────────────────────────────────────────────────────────
if ($OutFile) {
    $outputLines | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "  Report saved to: $OutFile" -ForegroundColor Green
}
