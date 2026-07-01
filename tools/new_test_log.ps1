# new_test_log.ps1
# Shared ConnectCIC test log generator -- works for any provider.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File tools\new_test_log.ps1 `
#     -Provider NJ_NJCJIS -Variant BASE -Version 2.0 `
#     -Entity Vehicle -Combo RQ -Description "plate only"
#
# Output (current standard, 2026-07-01 -- tests/ folder eliminated): a provider that has
# migrated to logs/<Entity>/ (any entity folder already exists) gets
#   <ProviderDir>\logs\<Entity>\<Provider>_v<Version>_<Combo>.txt
# A provider not yet migrated (legacy) gets the old flat-tests/ stub:
#   <ProviderDir>\tests\<DATE>_<Entity>_<Combo>_<Description>_v<Version>.txt
#
# After creating the stub:
#   1. Run the test in the browser with developer tools open (F12 -> Network tab).
#   2. Paste the raw XML request into the RAW XML REQUEST section.
#   3. Fill in REQUEST SUMMARY, FIELD ANALYSIS, and RESULT sections.
#   4. Commit and push immediately after filling in the log.

param(
    [Parameter(Mandatory)][string]$Provider,
    [ValidateSet('BASE','MC','')][string]$Variant = '',   # legacy split builds only; omit for single-JSON
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Entity,
    [Parameter(Mandatory)][string]$Combo,
    [Parameter(Mandatory)][string]$Description,
    [string]$Expected,
    [string]$ProviderDir
)

if (-not $ProviderDir) {
    $repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
    $ProviderDir = "$repoRoot\providers\$Provider"
    if (-not (Test-Path $ProviderDir)) {
        Write-Error "Provider directory not found: $ProviderDir. Pass -ProviderDir explicitly."
        exit 1
    }
}

$DATE      = (Get-Date -Format 'yyyy-MM-dd')
$DESC_SAFE = $Description -replace '[\\/:*?"<>| ]', '_'

# Migrated provider (any logs/<Entity>/ dir already exists) -> new standard naming/location.
# Legacy provider -> old flat tests/ stub, unchanged.
$logsRoot = "$ProviderDir\logs"
$isMigrated = (Test-Path $logsRoot) -and
    @(Get-ChildItem $logsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '_archive_pre_v*' }).Count -gt 0

if ($isMigrated) {
    $LOGDIR   = "$logsRoot\$Entity"
    $FILENAME = "${Provider}_v${Version}_${Combo}.txt"
} else {
    $LOGDIR   = "$ProviderDir\tests"
    $FILENAME = "${DATE}_${Entity}_${Combo}_${DESC_SAFE}_v${Version}.txt"
}
$OUTPATH = "$LOGDIR\$FILENAME"

New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

# Resolve the JSON filename for the log header. Single-JSON (versioned) is the standard;
# -Variant is only for legacy _BASE/_MC split builds.
if ($Variant) {
    $JSON_FILE = "${Provider}_${Variant}.json"
} else {
    . "$PSScriptRoot\_resolve_provider_json.ps1"
    $resolved  = Get-ProviderRootJson -ProvDir $ProviderDir -Provider $Provider
    $JSON_FILE = if ($resolved) { Split-Path $resolved -Leaf } else { "${Provider}.json" }
}

if ($Expected) {
    $EXPECTED_BODY = $Expected
} else {
    $EXPECTED_BODY = @'
  [Compact card presented to the user before this test -- TESTING_REQUIREMENTS.txt Sec 13b]
  Query        : [Query that should fire, e.g. GunQuery]
  keyReference : [expected keyRef, e.g. QGGunSerialNumber]
  XML elements : [elements that MUST appear, e.g. GunSerialNumber (+ImageIndicator=N)]
  MUST NOT have: [elements that must be ABSENT, e.g. NCICNumber, ProcessControlNumber]
  Co-fire      : [expected co-fire query or NONE]
'@
}

$VARLABEL = if ($Variant) { " $Variant" } else { "" }
$CONTENT = @"
$Provider$VARLABEL v$Version -- Test Log
============================================================
Date       : $DATE
JSON       : $JSON_FILE
Entity     : $Entity
Combo      : $Combo ($Description)
Test type  : [T1/T2/T3/T4/T5 -- see BUILD_CHECKLIST standard test sequence]

================================================================================
EXPECTED OUTCOME (what was presented BEFORE the test -- visual + XML)
================================================================================

$EXPECTED_BODY

================================================================================
FORM STATE (what was on the form when submitted)
================================================================================

  Field                     Value              Source
  ------------------------  -----------------  --------------------------------
  [FieldName]               [value]            [typed / default / hidden]

================================================================================
REQUEST SUMMARY
================================================================================

  Route       : MK43RS -> ConnectCic
  Transaction : [TRANSACTION ID FROM XML]
  MessageType : [MessageType from XML]
  keyReference: $Combo

  Fields sent in XML request:
    Element              Value
    -------------------  -------------------
    [FieldName]          [VALUE]

================================================================================
FIELD ANALYSIS
================================================================================

  Combination fired: $Combo
  Reason: [which set[] fields were populated]

  QIDM attribute       Sent?  Value           Note
  -------------------  -----  --------------  --------------------------------
  [attrName]           YES    [value]         [mapped from fieldId X]
  [attrName]           NO     --              [sourceField empty]

================================================================================
RMS CO-FIRE (if applicable)
================================================================================

  RMS combo fired: [combo name or NONE]
  RMS request fields: [list or N/A]

================================================================================
RESULT
================================================================================

  [PASS / FAIL]

  Reason: [one line -- what confirmed PASS, or what broke for FAIL]
  Detail: [optional -- any surprising behavior, limitation confirmed, etc.]

================================================================================
DISCREPANCY / TROUBLESHOOTING (only if observed != EXPECTED OUTCOME)
================================================================================

  Observed vs expected: [the delta -- e.g. "extra NCICNumber in XML pool"]
  Likely cause        : [e.g. over-send / combo-order / set[] unmet / missing default]
  Action taken        : [STOP + capture + report; fix applied; escalated; etc.]
  (Per Sec 13b discrepancy protocol: on mismatch STOP, capture XML, report -- do NOT mark PASS.)

================================================================================
RAW XML REQUEST (from browser F12 > Network > select request > Payload)
================================================================================

[PASTE RAW XML HERE]

================================================================================
RAW RMS REQUEST (if applicable -- from browser F12 > Network > RMS request)
================================================================================

[PASTE RAW RMS JSON HERE OR DELETE THIS SECTION]
"@

$CONTENT | Set-Content -Path $OUTPATH -Encoding UTF8

Write-Host ""
Write-Host "Created: $OUTPATH" -ForegroundColor Green
Write-Host ""
Write-Host "MANDATORY next steps (do not skip):" -ForegroundColor Yellow
Write-Host "  1. Run the test in the browser (F12 open BEFORE submitting)."
Write-Host "  2. Paste raw XML into RAW XML REQUEST section."
Write-Host "  3. Fill in FORM STATE, REQUEST SUMMARY, FIELD ANALYSIS, and RESULT."
Write-Host "  4. git add + git commit + git push IMMEDIATELY."
Write-Host "  5. Do NOT proceed to the next test until this log is committed."
Write-Host ""
