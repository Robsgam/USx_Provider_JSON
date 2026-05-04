# new_test_log.ps1
# Creates a pre-formatted test log stub for an AZ_AZDPS live test run.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File scripts\new_test_log.ps1 `
#     -TestNum T1 -QueryType VehicleRegistration -Combination RVEH `
#     -Description "NJ Plate+State" -Version 1.0 -Phase 03_vehicle [-Form "Vehicle"]
#
# Output: phases\[Phase]\logs\[DATE]_[QueryType]_[TestNum]_[Combination]_v[Version].txt
#
# After creating the stub:
#   1. Run the test in the browser with developer tools open (F12 -> Network tab).
#   2. Paste the raw XML request into the RAW XML REQUEST section.
#   3. Paste the raw RMS JSON into the RAW RMS REQUEST section.
#   4. Fill in Form, Fill, Fires set[], field-sent tables, and RESULT.
#   5. Update phases\[Phase]\PHASE_NOTES.txt with the log filename and result.
#   6. Update docs\AZ_AZDPS_STATUS.txt TEST LOG and TEST MATRIX sections.

param(
    [Parameter(Mandatory)][string]$TestNum,
    [Parameter(Mandatory)][string]$QueryType,
    [Parameter(Mandatory)][string]$Combination,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Phase,
    [string]$Form = ""
)

$DATE      = (Get-Date -Format 'yyyy-MM-dd')
$DIR       = "C:\Users\RobSgambellone\.local\bin\AZ_AZDPS"
$LOGDIR    = "$DIR\phases\$Phase\logs"
$DESC_SAFE = $Description -replace '[\\/:*?"<>| ]', '_'
$FILENAME  = "${DATE}_${QueryType}_${TestNum}_${Combination}_v${Version}.txt"
$OUTPATH   = "$LOGDIR\$FILENAME"

New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

$FORM_LINE = if ($Form) { $Form } else { "[FORM -- e.g., Vehicle / Person / Firearm]" }

$TITLE      = "AZ_AZDPS -- ${QueryType}Query Phase Log"
$TITLE_LINE = "=" * $TITLE.Length

$CONTENT = @"
$TITLE
$TITLE_LINE
Date    : $DATE
Version : v$Version
Phase   : $Phase
Tester  : Rob Sgambellone
Scope   : $TestNum -- ${QueryType}Query, $Combination, $Description

================================================================================
$TestNum -- ${QueryType}Query, $Combination, $Description
================================================================================

Form    : $FORM_LINE
Fill    : [FILL -- field=VALUE | field=VALUE | field=blank]
Fires   : $Combination  (set=[[SET_FIELDS -- fields whose presence triggered this combination]])

Fields sent (CommSys XML):
  [FieldName]              [VALUE]    SENT  ([sourceField note])
  [FieldName]              (blank)    NOT SENT
  [FieldName]              (blank)    NOT SENT

Fields sent (RMS):
  [fieldName]   [VALUE]    SENT  ([note])

Result  : No Returns (expected -- test value)
RESULT  : [PASS / FAIL]

Notes:
  -

RAW XML REQUEST:
[PASTE RAW XML FROM BROWSER DEV TOOLS -- F12 > Network > select request > Payload/Request]

RAW RMS REQUEST:
[PASTE RAW RMS JSON FROM BROWSER DEV TOOLS]
"@

$CONTENT | Set-Content -Path $OUTPATH -Encoding UTF8

Write-Host ""
Write-Host "Created: $OUTPATH"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run the test in the browser (F12 open before submitting)."
Write-Host "  2. Paste raw XML into RAW XML REQUEST."
Write-Host "  3. Paste raw RMS JSON into RAW RMS REQUEST."
Write-Host "  4. Fill in Form, Fill, Fires set[], field tables, RESULT, Notes."
Write-Host "  5. Update phases\$Phase\PHASE_NOTES.txt -- add log entry and result."
Write-Host "  6. Update docs\AZ_AZDPS_STATUS.txt -- TEST LOG and TEST MATRIX."
Write-Host ""
