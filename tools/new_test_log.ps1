# new_test_log.ps1
# Shared ConnectCIC test log generator -- works for any provider.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File tools\new_test_log.ps1 `
#     -Provider NJ_NJCJIS -Variant BASE -Version 2.0 `
#     -Entity Vehicle -Combo RQ -Description "plate only"
#
# Output: <ProviderDir>\tests\<DATE>_<Entity>_<Combo>_<Description>_v<Version>.txt
#
# After creating the stub:
#   1. Run the test in the browser with developer tools open (F12 -> Network tab).
#   2. Paste the raw XML request into the RAW XML REQUEST section.
#   3. Fill in REQUEST SUMMARY, FIELD ANALYSIS, and RESULT sections.
#   4. Commit and push immediately after filling in the log.

param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][ValidateSet('BASE','MC')][string]$Variant,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Entity,
    [Parameter(Mandatory)][string]$Combo,
    [Parameter(Mandatory)][string]$Description,
    [string]$ProviderDir
)

if (-not $ProviderDir) {
    $repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
    $knownPaths = @{
        'NJ_NJCJIS'           = "$repoRoot\providers\NJ_NJCJIS"
        'NY_NYSPIN_EJUSTICE'  = "$repoRoot\providers\NY_NYSPIN_EJUSTICE"
        'HI_HCJDC_OFML'       = "$repoRoot\providers\HI_HCJDC_OFML"
        'AZ_AZDPS'            = "$repoRoot\providers\AZ_AZDPS"
        'FL_FCIC'             = "$repoRoot\providers\FL_FCIC"
        'TX_TLETS'            = "$repoRoot\providers\TX_TLETS"
        'LA_LETTS_OFML'       = "$repoRoot\providers\LA_LETTS_OFML"
    }
    if ($knownPaths.ContainsKey($Provider)) {
        $ProviderDir = $knownPaths[$Provider]
    } else {
        Write-Error "Unknown provider '$Provider'. Pass -ProviderDir explicitly."
        exit 1
    }
}

$DATE      = (Get-Date -Format 'yyyy-MM-dd')
$LOGDIR    = "$ProviderDir\tests"
$DESC_SAFE = $Description -replace '[\\/:*?"<>| ]', '_'
$FILENAME  = "${DATE}_${Entity}_${Combo}_${DESC_SAFE}_v${Version}.txt"
$OUTPATH   = "$LOGDIR\$FILENAME"

New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

$JSON_FILE = "${Provider}_${Variant}.json"

$CONTENT = @"
$Provider $Variant v$Version -- Test Log
============================================================
Date       : $DATE
JSON       : $JSON_FILE
Entity     : $Entity
Combo      : $Combo ($Description)
Test type  : [T1/T2/T3/T4/T5 -- see BUILD_CHECKLIST standard test sequence]

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
