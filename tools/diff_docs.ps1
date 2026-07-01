<#
  diff_docs.ps1 -- Document Diff Tool for ConnectCIC KB
  Compares a new/updated engineering doc or devdoc against current KB files.
  Extracts structured elements (fields, handlers, queries, keyRefs, operators,
  properties, limitations) and reports what is NEW, REMOVED, or CONFIRMED.

  Usage:
    .\diff_docs.ps1 -NewDoc <path>
    .\diff_docs.ps1 -NewDoc <path> -KbFile knowledge-base/RULE_HANDLERS.txt
    .\diff_docs.ps1 -NewDoc <path> -Provider CA_CLETS -OutFile diff_report.txt
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$NewDoc,
    [string]$KbFile,
    [string]$OutFile,
    [string]$Provider
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$kbDir = Join-Path $repoRoot "knowledge-base"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-New($msg)       { Write-Host "  [NEW]       $msg" -ForegroundColor Green }
function Write-Removed($msg)   { Write-Host "  [REMOVED]   $msg" -ForegroundColor Red }
function Write-Confirmed($msg) { Write-Host "  [CONFIRMED] $msg" -ForegroundColor DarkGray }
function Write-Section($msg)   { Write-Host "`n--- $msg ---" -ForegroundColor Yellow }
function Write-Header($msg)    { Write-Host "`n$msg" -ForegroundColor Cyan }

function New-StringSet {
    # Returns a hashtable used as a set (keys = values, value = $true)
    return @{}
}

function Add-ToSet([hashtable]$set, [string]$value) {
    if (-not $set.ContainsKey($value)) { $set[$value] = $true }
}

function Test-InSet([hashtable]$set, [string]$value) {
    return $set.ContainsKey($value)
}

function Get-SetItems([hashtable]$set) {
    return @($set.Keys | Sort-Object)
}

function Get-SetCount([hashtable]$set) {
    return $set.Count
}

# ── Validate inputs ──────────────────────────────────────────────────────────

if (-not (Test-Path $NewDoc)) {
    Write-Host "  [FAIL] File not found: $NewDoc" -ForegroundColor Red
    exit 1
}

$newDocResolved = Resolve-Path $NewDoc
$newDocName = Split-Path $newDocResolved -Leaf
$newDocText = [System.IO.File]::ReadAllText("$newDocResolved", [System.Text.Encoding]::UTF8)

if ($KbFile -and -not (Test-Path $KbFile)) {
    Write-Host "  [FAIL] KB file not found: $KbFile" -ForegroundColor Red
    exit 1
}

# ── Element extraction functions ─────────────────────────────────────────────

function Extract-Elements([string]$text) {
    <#
      Extracts structured tokens from a document:
        - Fields: camelCase, PascalCase, UPPER_CASE identifiers that look like field names
        - Handlers: *RuleHandler, *Handler patterns
        - Queries: *Query patterns
        - KeyRefs: keyRef/keyReference values
        - Operators: EQUALS, NOT_EQUALS, IN, NOT_IN, etc.
        - Properties: sourceField, targetField, autoSelect, etc.
        - Limitations: LIMITATION #N, AP #N
    #>
    $result = @{
        Fields      = New-StringSet
        Handlers    = New-StringSet
        Queries     = New-StringSet
        KeyRefs     = New-StringSet
        Operators   = New-StringSet
        Properties  = New-StringSet
        Limitations = New-StringSet
    }

    # --- Handlers: *RuleHandler or *Handler patterns ---
    $handlerMatches = [regex]::Matches($text, '\b([A-Z][a-zA-Z0-9]*(?:RuleHandler|Handler))\b')
    foreach ($m in $handlerMatches) {
        Add-ToSet $result.Handlers $m.Groups[1].Value
    }

    # --- Queries: *Query patterns ---
    $queryMatches = [regex]::Matches($text, '\b([A-Z][a-zA-Z0-9]*Query)\b')
    foreach ($m in $queryMatches) {
        Add-ToSet $result.Queries $m.Groups[1].Value
    }

    # --- KeyRefs: quoted strings after keyRef/keyReference, or known keyRef patterns ---
    $keyRefMatches = [regex]::Matches($text, "(?:keyRef(?:erence)?|keyReference)\s*[:=]\s*[`"']?([A-Za-z0-9_.]+)")
    foreach ($m in $keyRefMatches) {
        Add-ToSet $result.KeyRefs $m.Groups[1].Value
    }
    # Also catch standalone keyRef-like tokens (short uppercase with dots, e.g. IN.VP, IG.QGH)
    $standaloneKeyRef = [regex]::Matches($text, '(?:^|\s|[,;|])([A-Z]{2,6}(?:\.[A-Z]{1,6}){1,3})(?:\s|[,;|]|$)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($m in $standaloneKeyRef) {
        $val = $m.Groups[1].Value
        if ($val -match '^\d+$') { continue }
        if ($val.Length -le 1) { continue }
        Add-ToSet $result.KeyRefs $val
    }

    # --- Operators ---
    $operatorPatterns = @(
        'EQUALS', 'NOT_EQUALS', 'IN', 'NOT_IN', 'STARTS_WITH',
        'ENDS_WITH', 'CONTAINS', 'NOT_CONTAINS', 'GREATER_THAN',
        'LESS_THAN', 'GREATER_THAN_OR_EQUALS', 'LESS_THAN_OR_EQUALS',
        'IS_NULL', 'IS_NOT_NULL', 'BETWEEN', 'LIKE', 'NOT_LIKE'
    )
    foreach ($op in $operatorPatterns) {
        if ($text -match "\b$op\b") {
            Add-ToSet $result.Operators $op
        }
    }

    # --- Properties: known ConnectCIC JSON properties ---
    $propertyPatterns = @(
        'sourceField', 'targetField', 'autoSelect', 'codeTypeProvider',
        'codeTypeCategory', 'codeTypeSource', 'attributeTypeId',
        'useAttributeId', 'initialValue', 'queriesToDeselect',
        'primaryFieldReference', 'keyReference', 'keyRef',
        'handlerFunction', 'targetEntity', 'queryLabel',
        'maxLength', 'fieldId', 'templateColumns', 'hidden',
        'fallbackRule', 'returnAllPages', 'freeText', 'operator',
        'size', 'ImageIndicator', 'RandomRequest'
    )
    foreach ($prop in $propertyPatterns) {
        if ([regex]::IsMatch($text, "\b$prop\b")) {
            Add-ToSet $result.Properties $prop
        }
    }

    # --- Limitations: LIMITATION #N, AP #N ---
    $limMatches = [regex]::Matches($text, '\b(LIMITATION\s*#\d+)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($m in $limMatches) {
        $normalized = ($m.Groups[1].Value.ToUpper()) -replace '\s+', ' '
        Add-ToSet $result.Limitations $normalized
    }
    $apMatches = [regex]::Matches($text, '\b(AP\s*#\d+)\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($m in $apMatches) {
        $normalized = ($m.Groups[1].Value.ToUpper()) -replace '\s+', ' '
        Add-ToSet $result.Limitations $normalized
    }

    # --- Fields: PascalCase and camelCase identifiers that look like field names ---
    # Exclude: already-captured handlers, queries, operators, properties, common English/PS words.
    $fieldMatches = [regex]::Matches($text, '\b([A-Z][a-z]+(?:[A-Z][a-z0-9]*)+)\b')
    foreach ($m in $fieldMatches) {
        $val = $m.Groups[1].Value
        if (Test-InSet $result.Handlers $val) { continue }
        if (Test-InSet $result.Queries $val) { continue }
        if (Test-InSet $result.Properties $val) { continue }
        if ($val -match '^(FormSelect|FormInput|FormDate|FormCheckbox|ConvertFrom|ConvertTo|PowerShell|ForEach|Boolean|Integer|String|Object|Parameter|Mandatory|ValidateSet|SilentlyContinue|ErrorAction|ForegroundColor|BackgroundColor|WriteHost|GetContent|SetContent|SplitPath|JoinPath|TestPath|ResolvePath|GetChildItem|NewItem|RemoveItem|GetDate|StartsWith|EndsWith|Contains|HashSet|ArrayList|OrderedDictionary|StringBuilder|RegularExpressions|RegexOptions)$') { continue }
        Add-ToSet $result.Fields $val
    }
    # camelCase fields (e.g., licensePlateNumber, sexAttrId)
    $camelMatches = [regex]::Matches($text, '\b([a-z][a-z0-9]*(?:[A-Z][a-z0-9]*)+)\b')
    foreach ($m in $camelMatches) {
        $val = $m.Groups[1].Value
        if (Test-InSet $result.Properties $val) { continue }
        if ($val -match '^(autoSelect|sourceField|targetField|codeTypeProvider|codeTypeCategory|codeTypeSource|attributeTypeId|useAttributeId|initialValue|queriesToDeselect|primaryFieldReference|keyReference|keyRef|handlerFunction|targetEntity|queryLabel|maxLength|fieldId|templateColumns|fallbackRule|returnAllPages|freeText|resolvedName|hidePageItems)$') { continue }
        Add-ToSet $result.Fields $val
    }
    # UPPER_CASE fields (e.g., NIBRS_SEX, NCIC_LICENSE_PLATE_TYPE)
    $upperMatches = [regex]::Matches($text, '\b([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\b')
    foreach ($m in $upperMatches) {
        $val = $m.Groups[1].Value
        if (Test-InSet $result.Operators $val) { continue }
        if ($val -match '^(ERROR_ACTION|FOREGROUND_COLOR|WRITE_HOST|SPLIT_PATH)$') { continue }
        Add-ToSet $result.Fields $val
    }

    return $result
}

function Compare-Sets([hashtable]$setA, [hashtable]$setB) {
    <# Returns: @{ New = items in A not in B; Removed = items in B not in A; Confirmed = items in both } #>
    $new       = @()
    $removed   = @()
    $confirmed = @()

    foreach ($item in $setA.Keys) {
        if ($setB.ContainsKey($item)) { $confirmed += $item }
        else { $new += $item }
    }
    foreach ($item in $setB.Keys) {
        if (-not $setA.ContainsKey($item)) { $removed += $item }
    }

    $new       = @($new | Sort-Object)
    $removed   = @($removed | Sort-Object)
    $confirmed = @($confirmed | Sort-Object)

    return @{ New = $new; Removed = $removed; Confirmed = $confirmed }
}

# ── Determine KB files to compare against ────────────────────────────────────

$kbFiles = @()
if ($KbFile) {
    $kbFiles += (Resolve-Path $KbFile).Path
} else {
    # Scan all KB files
    $kbCandidates = Get-ChildItem $kbDir -Filter "*.txt" -File | Where-Object { $_.Name -ne 'README.txt' }
    foreach ($f in $kbCandidates) {
        $kbFiles += $f.FullName
    }
}

# ── Also load provider-specific files if -Provider given ─────────────────────

$providerMetadata = $null
$providerBuildScript = $null
$providerDir = $null

if ($Provider) {
    # Find provider directory
    $providerBase = Join-Path $repoRoot "providers"
    $candidates = Get-ChildItem $providerBase -Directory | Where-Object { $_.Name -like "*$Provider*" }
    if ($candidates.Count -eq 1) {
        $providerDir = $candidates[0].FullName
    } elseif ($candidates.Count -gt 1) {
        $exact = $candidates | Where-Object { $_.Name -eq $Provider }
        if ($exact) { $providerDir = $exact.FullName }
        else { $providerDir = $candidates[0].FullName }
    }

    if ($providerDir) {
        # Metadata reference -- "reference" category (2026-07-01 docs/ reorg pilot); resolves
        # to docs/reference/ for a migrated provider, flat docs/ otherwise.
        . (Join-Path $PSScriptRoot '_resolve_docs_path.ps1')
        $docsDir = Get-DocsCategoryDir $providerDir 'reference'
        if (Test-Path $docsDir) {
            $metaFiles = Get-ChildItem $docsDir -Filter "*METADATA_REFERENCE*" -File -ErrorAction SilentlyContinue
            if ($metaFiles) {
                $providerMetadata = $metaFiles[0].FullName
                $kbFiles += $providerMetadata
            }
        }
        # Build script(s)
        $scriptsDir = Join-Path $providerDir "scripts"
        if (Test-Path $scriptsDir) {
            $buildFiles = Get-ChildItem $scriptsDir -Filter "build_*.ps1" -File -ErrorAction SilentlyContinue
            if ($buildFiles) {
                # Prefer non-mc build script
                $baseBuild = $buildFiles | Where-Object { $_.Name -notmatch '_mc\.ps1$' } | Select-Object -First 1
                if ($baseBuild) { $providerBuildScript = $baseBuild.FullName }
                else { $providerBuildScript = $buildFiles[0].FullName }
            }
        }
    } else {
        Write-Host "  [WARN] Provider directory not found for '$Provider'" -ForegroundColor Yellow
    }
}

# ── Extract elements from new document ───────────────────────────────────────

Write-Header "========================================================"
Write-Header " DOCUMENT DIFF REPORT"
Write-Header "========================================================"
Write-Host ""
Write-Host "  New document:  $newDocName" -ForegroundColor White
Write-Host "  KB targets:    $($kbFiles.Count) file(s)" -ForegroundColor White
if ($Provider)  { Write-Host "  Provider:      $Provider" -ForegroundColor White }
if ($providerDir) { Write-Host "  Provider dir:  $(Split-Path $providerDir -Leaf)" -ForegroundColor White }
Write-Host "  Generated:     $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor White

$newElements = Extract-Elements $newDocText

Write-Host ""
Write-Host "  Elements extracted from new document:" -ForegroundColor Gray
Write-Host "    Fields:      $(Get-SetCount $newElements.Fields)" -ForegroundColor Gray
Write-Host "    Handlers:    $(Get-SetCount $newElements.Handlers)" -ForegroundColor Gray
Write-Host "    Queries:     $(Get-SetCount $newElements.Queries)" -ForegroundColor Gray
Write-Host "    KeyRefs:     $(Get-SetCount $newElements.KeyRefs)" -ForegroundColor Gray
Write-Host "    Operators:   $(Get-SetCount $newElements.Operators)" -ForegroundColor Gray
Write-Host "    Properties:  $(Get-SetCount $newElements.Properties)" -ForegroundColor Gray
Write-Host "    Limitations: $(Get-SetCount $newElements.Limitations)" -ForegroundColor Gray

# ── Extract elements from all KB files (combined) ────────────────────────────

$kbCombinedText = ""
$kbPerFile = @{}

foreach ($kf in $kbFiles) {
    $kfName = Split-Path $kf -Leaf
    $kfText = [System.IO.File]::ReadAllText($kf, [System.Text.Encoding]::UTF8)
    $kbCombinedText += "`n" + $kfText
    $kbPerFile[$kfName] = Extract-Elements $kfText
}

$kbElements = Extract-Elements $kbCombinedText

Write-Host ""
Write-Host "  Elements extracted from KB ($($kbFiles.Count) files combined):" -ForegroundColor Gray
Write-Host "    Fields:      $(Get-SetCount $kbElements.Fields)" -ForegroundColor Gray
Write-Host "    Handlers:    $(Get-SetCount $kbElements.Handlers)" -ForegroundColor Gray
Write-Host "    Queries:     $(Get-SetCount $kbElements.Queries)" -ForegroundColor Gray
Write-Host "    KeyRefs:     $(Get-SetCount $kbElements.KeyRefs)" -ForegroundColor Gray
Write-Host "    Operators:   $(Get-SetCount $kbElements.Operators)" -ForegroundColor Gray
Write-Host "    Properties:  $(Get-SetCount $kbElements.Properties)" -ForegroundColor Gray
Write-Host "    Limitations: $(Get-SetCount $kbElements.Limitations)" -ForegroundColor Gray

# ── Compare each element type ────────────────────────────────────────────────

$totalNew = 0
$totalRemoved = 0
$totalConfirmed = 0

$reportLines = @()
$reportLines += "========================================================"
$reportLines += " DOCUMENT DIFF REPORT"
$reportLines += "========================================================"
$reportLines += ""
$reportLines += "  New document:  $newDocName"
$reportLines += "  KB targets:    $($kbFiles.Count) file(s)"
if ($Provider) { $reportLines += "  Provider:      $Provider" }
$reportLines += "  Generated:     $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$reportLines += ""

$categories = @(
    @{ Name = 'HANDLERS';    NewSet = $newElements.Handlers;    KbSet = $kbElements.Handlers }
    @{ Name = 'QUERIES';     NewSet = $newElements.Queries;     KbSet = $kbElements.Queries }
    @{ Name = 'FIELDS';      NewSet = $newElements.Fields;      KbSet = $kbElements.Fields }
    @{ Name = 'KEY REFS';    NewSet = $newElements.KeyRefs;     KbSet = $kbElements.KeyRefs }
    @{ Name = 'OPERATORS';   NewSet = $newElements.Operators;   KbSet = $kbElements.Operators }
    @{ Name = 'PROPERTIES';  NewSet = $newElements.Properties;  KbSet = $kbElements.Properties }
    @{ Name = 'LIMITATIONS'; NewSet = $newElements.Limitations; KbSet = $kbElements.Limitations }
)

$actionItems = @()

foreach ($cat in $categories) {
    $cmp = Compare-Sets $cat.NewSet $cat.KbSet
    $totalNew       += $cmp.New.Count
    $totalRemoved   += $cmp.Removed.Count
    $totalConfirmed += $cmp.Confirmed.Count

    Write-Section "$($cat.Name)  (new: $($cmp.New.Count) | removed: $($cmp.Removed.Count) | confirmed: $($cmp.Confirmed.Count))"
    $reportLines += ""
    $reportLines += "--- $($cat.Name) ---"
    $reportLines += "    new: $($cmp.New.Count) | removed: $($cmp.Removed.Count) | confirmed: $($cmp.Confirmed.Count)"

    if ($cmp.New.Count -gt 0) {
        foreach ($item in $cmp.New) {
            Write-New $item
            $reportLines += "  [NEW]       $item"
        }

        # Suggest which KB file to add new items to
        $suggestedFile = switch ($cat.Name) {
            'HANDLERS'    { 'RULE_HANDLERS.txt' }
            'QUERIES'     { 'QIDM_REFERENCE.txt' }
            'FIELDS'      { 'FIELD_REFERENCE.txt' }
            'KEY REFS'    { 'QIDM_REFERENCE.txt' }
            'OPERATORS'   { 'PLATFORM_CONSTRAINTS.txt' }
            'PROPERTIES'  { 'BUILD_RULES.txt' }
            'LIMITATIONS' { 'PLATFORM_CONSTRAINTS.txt' }
            default       { 'BUILD_RULES.txt' }
        }
        $actionItems += "  $($cmp.New.Count) new $($cat.Name.ToLower()) -> consider adding to $suggestedFile"
    }
    if ($cmp.Removed.Count -gt 0) {
        foreach ($item in $cmp.Removed) {
            Write-Removed $item
            $reportLines += "  [REMOVED]   $item"
        }
    }
    if ($cmp.Confirmed.Count -gt 0 -and $cmp.Confirmed.Count -le 30) {
        foreach ($item in $cmp.Confirmed) {
            Write-Confirmed $item
            $reportLines += "  [CONFIRMED] $item"
        }
    } elseif ($cmp.Confirmed.Count -gt 30) {
        Write-Host "  [CONFIRMED] $($cmp.Confirmed.Count) items (list suppressed)" -ForegroundColor DarkGray
        $reportLines += "  [CONFIRMED] $($cmp.Confirmed.Count) items (list suppressed)"
    }
}

# ── Per-KB-file relevance breakdown ──────────────────────────────────────────

Write-Section "PER-FILE RELEVANCE"
$reportLines += ""
$reportLines += "--- PER-FILE RELEVANCE ---"

foreach ($kfName in ($kbPerFile.Keys | Sort-Object)) {
    $kfElements = $kbPerFile[$kfName]
    $overlapCount = 0

    # Count overlaps across all categories
    foreach ($cat in $categories) {
        $catNewSet = $cat.NewSet
        $kfSet = switch ($cat.Name) {
            'HANDLERS'    { $kfElements.Handlers }
            'QUERIES'     { $kfElements.Queries }
            'FIELDS'      { $kfElements.Fields }
            'KEY REFS'    { $kfElements.KeyRefs }
            'OPERATORS'   { $kfElements.Operators }
            'PROPERTIES'  { $kfElements.Properties }
            'LIMITATIONS' { $kfElements.Limitations }
        }
        foreach ($item in $catNewSet.Keys) {
            if ($kfSet.ContainsKey($item)) { $overlapCount++ }
        }
    }

    $totalInDoc = 0
    foreach ($cat in $categories) { $totalInDoc += $cat.NewSet.Count }

    $pct = if ($totalInDoc -gt 0) { [math]::Round(($overlapCount / $totalInDoc) * 100, 0) } else { 0 }
    $msg = "  $kfName : $overlapCount overlapping elements ($pct% of new doc)"
    $color = 'Gray'
    if ($pct -ge 50) { $color = 'Green' }
    elseif ($pct -ge 20) { $color = 'Yellow' }
    Write-Host $msg -ForegroundColor $color
    $reportLines += $msg
}

# ── Provider build script analysis (if -Provider given) ──────────────────────

if ($providerBuildScript) {
    Write-Section "PROVIDER BUILD SCRIPT ANALYSIS"
    $reportLines += ""
    $reportLines += "--- PROVIDER BUILD SCRIPT ANALYSIS ---"

    $scriptText = [System.IO.File]::ReadAllText($providerBuildScript, [System.Text.Encoding]::UTF8)
    $scriptName = Split-Path $providerBuildScript -Leaf

    Write-Host "  Build script: $scriptName" -ForegroundColor White
    $reportLines += "  Build script: $scriptName"

    # Extract combos from build script (keyReference patterns)
    $comboMatches = [regex]::Matches($scriptText, "(?:keyReference|keyRef)\s*[:=]\s*[`"']([^`"']+)")
    $scriptCombos = @{}
    foreach ($m in $comboMatches) { $scriptCombos[$m.Groups[1].Value] = $true }

    # Extract field names from build script (fieldId patterns)
    $fieldIdMatches = [regex]::Matches($scriptText, "fieldId\s*[:=]\s*[`"']([^`"']+)")
    $scriptFields = @{}
    foreach ($m in $fieldIdMatches) { $scriptFields[$m.Groups[1].Value] = $true }

    # Compare combos: new doc vs build script
    $newDocKeyRefs = $newElements.KeyRefs
    $comboNew = @()
    foreach ($c in $newDocKeyRefs.Keys) {
        if (-not $scriptCombos.ContainsKey($c)) { $comboNew += $c }
    }
    $comboMissing = @()
    foreach ($c in $scriptCombos.Keys) {
        if (-not $newDocKeyRefs.ContainsKey($c)) { $comboMissing += $c }
    }

    Write-Host "  Combos in build script: $($scriptCombos.Count)" -ForegroundColor Gray
    Write-Host "  KeyRefs in new doc:     $($newDocKeyRefs.Count)" -ForegroundColor Gray
    $reportLines += "  Combos in build script: $($scriptCombos.Count)"
    $reportLines += "  KeyRefs in new doc:     $($newDocKeyRefs.Count)"

    if ($comboNew.Count -gt 0) {
        Write-Host "  New keyRefs not in build script:" -ForegroundColor Green
        $reportLines += "  New keyRefs not in build script:"
        foreach ($c in ($comboNew | Sort-Object)) {
            Write-New "combo: $c"
            $reportLines += "    [NEW] $c"
        }
        $actionItems += "  $($comboNew.Count) new keyRef(s) may require build script update"
    }
    if ($comboMissing.Count -gt 0) {
        Write-Host "  Build script keyRefs not in new doc:" -ForegroundColor Red
        $reportLines += "  Build script keyRefs not in new doc:"
        foreach ($c in ($comboMissing | Sort-Object)) {
            Write-Removed "combo: $c"
            $reportLines += "    [REMOVED] $c"
        }
    }

    # Compare fields: new doc vs build script
    $fieldNew = @()
    foreach ($f in $newElements.Fields.Keys) {
        if (-not $scriptFields.ContainsKey($f)) { $fieldNew += $f }
    }
    # Only report if there are a reasonable number (avoid noise)
    if ($fieldNew.Count -gt 0 -and $fieldNew.Count -le 50) {
        Write-Host "  Fields in new doc not in build script fieldIds ($($fieldNew.Count)):" -ForegroundColor Gray
        $reportLines += "  Fields in new doc not in build script fieldIds ($($fieldNew.Count)):"
        $shown = 0
        foreach ($f in ($fieldNew | Sort-Object)) {
            if ($shown -ge 20) {
                Write-Host "  ... and $($fieldNew.Count - 20) more" -ForegroundColor DarkGray
                $reportLines += "    ... and $($fieldNew.Count - 20) more"
                break
            }
            Write-Host "    $f" -ForegroundColor DarkGray
            $reportLines += "    $f"
            $shown++
        }
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────

Write-Header "========================================================"
Write-Header " SUMMARY"
Write-Header "========================================================"
Write-Host ""

$summaryLine = "  NEW: $totalNew  |  REMOVED: $totalRemoved  |  CONFIRMED: $totalConfirmed"
$reportLines += ""
$reportLines += "========================================================"
$reportLines += " SUMMARY"
$reportLines += "========================================================"
$reportLines += ""
$reportLines += $summaryLine

if ($totalNew -gt 0) {
    Write-Host $summaryLine -ForegroundColor Green
} elseif ($totalRemoved -gt 0) {
    Write-Host $summaryLine -ForegroundColor Yellow
} else {
    Write-Host $summaryLine -ForegroundColor Cyan
}

# ── Action Items ─────────────────────────────────────────────────────────────

if ($actionItems.Count -gt 0) {
    Write-Host ""
    Write-Host "  ACTION ITEMS:" -ForegroundColor Yellow
    $reportLines += ""
    $reportLines += "  ACTION ITEMS:"
    foreach ($ai in $actionItems) {
        Write-Host $ai -ForegroundColor Yellow
        $reportLines += $ai
    }
}

Write-Host ""

# ── Save to file if -OutFile given ───────────────────────────────────────────

if ($OutFile) {
    $reportLines | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "  Report saved to: $OutFile" -ForegroundColor Green
}

# ── Return summary object for pipeline use ───────────────────────────────────

[PSCustomObject]@{
    NewCount       = $totalNew
    RemovedCount   = $totalRemoved
    ConfirmedCount = $totalConfirmed
    ActionItems    = $actionItems.Count
}
