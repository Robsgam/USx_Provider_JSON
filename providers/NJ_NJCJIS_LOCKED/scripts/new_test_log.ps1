# new_test_log.ps1
# Creates a pre-formatted test log stub for a NJ_NJCJIS live test run.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File scripts\new_test_log.ps1 `
#     -QueryType VEH -Combination RQ -Description "plate only" -Version 3.23 -Phase 03_vehicle
#
# Output: phases\[Phase]\logs\[DATE]_[QueryType]_[Combination]_[Description]_v[Version].txt
#
# After creating the stub:
#   1. Run the test in the browser with developer tools open (F12 -> Network tab).
#   2. Paste the raw XML request into the RAW XML REQUEST section.
#   3. Fill in REQUEST SUMMARY, FIELD ANALYSIS, and ANALYSIS sections.
#   4. Update phases\[Phase]\PHASE_NOTES.txt with the log filename and result.

param(
    [Parameter(Mandatory)][string]$QueryType,
    [Parameter(Mandatory)][string]$Combination,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Phase
)

$DATE      = (Get-Date -Format 'yyyy-MM-dd')
$DIR       = (Resolve-Path "$PSScriptRoot\..").Path
$LOGDIR    = "$DIR\phases\$Phase\logs"
$DESC_SAFE = $Description -replace '[\\/:*?"<>| ]', '_'
$FILENAME  = "${DATE}_${QueryType}_${Combination}_${DESC_SAFE}_v${Version}.txt"
$OUTPATH   = "$LOGDIR\$FILENAME"

New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

$CONTENT = @"
NJ_NJCJIS -- Query Log
======================
Date      : $DATE
JSON ver  : v$Version
Query type: [FULL QUERY TYPE -- e.g., VehicleRegistrationQuery ($Combination -- $Description)]
Test      : [FILL -- what was entered, what defaults were active]

================================================================================
REQUEST SUMMARY
================================================================================

  Route       : MK43RS -> ConnectCic
  Transaction : [TRANSACTION ID FROM XML]
  MessageType : [MessageType from XML]

  Fields in request:
    [FieldName]   [VALUE]
    [FieldName]   [VALUE]

================================================================================
FIELD ANALYSIS
================================================================================

  Combination fired: $Combination ([reason -- which set[] fields were present])

  Field                        Sent    Note
  ---------------------------  ----    ------------------------------------------------
  [FieldName]                  YES     [value]
  [FieldName]                  NO      [reason -- not filled / blank FormInput not sent]

================================================================================
ANALYSIS
================================================================================

  [PASS/FAIL] -- [reason]
    [supporting detail]

================================================================================
RAW XML REQUEST
================================================================================

[PASTE RAW XML FROM BROWSER DEV TOOLS -- F12 > Network > select request > Payload/Request]
"@

$CONTENT | Set-Content -Path $OUTPATH -Encoding UTF8

Write-Host ""
Write-Host "Created: $OUTPATH"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run the test in the browser (F12 open before submitting)."
Write-Host "  2. Paste raw XML into RAW XML REQUEST."
Write-Host "  3. Fill in REQUEST SUMMARY, FIELD ANALYSIS, and ANALYSIS sections."
Write-Host "  4. Update phases\$Phase\PHASE_NOTES.txt -- add log entry and result."
Write-Host ""
