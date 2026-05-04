# new_test_log.ps1
# Creates a pre-formatted test log stub for a TX_TLETS live test run.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File scripts\new_test_log.ps1 `
#     -TestNum T1 -QueryType VehicleRegistration -Combination RVEH `
#     -Description "TX Plate" -Version 1.0 -Phase 01_standup [-Form "Vehicle"]
#
# Output: phases\[Phase]\logs\[DATE]_[QueryType]_[TestNum]_[Combination]_v[Version].txt

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
$DIR       = "C:\Users\Gordon Hallof\TX_TLETS"
$LOGDIR    = "$DIR\phases\$Phase\logs"
$FILENAME  = "${DATE}_${QueryType}_${TestNum}_${Combination}_v${Version}.txt"
$OUTPATH   = "$LOGDIR\$FILENAME"

New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

$FORM_LINE = if ($Form) { $Form } else { "[FORM -- e.g., Vehicle / Person / Firearm]" }
$TITLE     = "TX_TLETS -- ${QueryType}Query Phase Log"
$TITLE_LINE = "=" * $TITLE.Length

$CONTENT = @"
$TITLE
$TITLE_LINE
Date    : $DATE
Version : v$Version
Phase   : $Phase
Tester  : [TESTER NAME]
Scope   : $TestNum -- ${QueryType}Query, $Combination, $Description

================================================================================
$TestNum -- ${QueryType}Query, $Combination, $Description
================================================================================

Form    : $FORM_LINE
Fill    : [FILL -- field=VALUE | field=VALUE | field=blank]
Fires   : $Combination  (set=[[SET_FIELDS]])

Fields sent (CommSys XML):
  [FieldName]              [VALUE]    SENT  ([sourceField note])
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
Write-Host "  4. Fill in Form, Fill, Fires, field tables, RESULT, Notes."
Write-Host "  5. Update phases\$Phase\PHASE_NOTES.txt -- add log entry and result."
Write-Host "  6. Update docs\TX_TLETS_STATUS.txt -- TEST LOG and TEST MATRIX."
Write-Host ""
