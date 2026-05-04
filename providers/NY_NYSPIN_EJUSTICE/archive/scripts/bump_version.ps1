# bump_version.ps1
# Archives the current NY_NYSPIN_EJUSTICE.json before running a rebuild.
# Usage: powershell.exe -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Version "1.2" -Phase "03_updated_sources"
# Then edit build_ny_nyspin_ejustice.ps1 and re-run it with the new version.

param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Phase = ""
)

$DATE    = (Get-Date -Format 'yyyy-MM-dd')
$DIR     = "C:\Users\RobSgambellone\.local\bin\NY_NYSPIN_EJUSTICE"
$CURRENT = "$DIR\NY_NYSPIN_EJUSTICE.json"

if ($Phase) {
    $ARCHIVE = "$DIR\phases\$Phase"
} else {
    $ARCHIVE = "$DIR\archive"
}

New-Item -ItemType Directory -Force -Path $ARCHIVE | Out-Null

if (Test-Path $CURRENT) {
    $dest = "$ARCHIVE\NY_NYSPIN_EJUSTICE_v${Version}_${DATE}.json"
    Copy-Item $CURRENT $dest
    Write-Host "Archived current -> $dest"
} else {
    Write-Host "No existing NY_NYSPIN_EJUSTICE.json to archive."
}

Write-Host ""
Write-Host "Now run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_ny_nyspin_ejustice.ps1 -Version '$Version' -Phase '$Phase'"
Write-Host ""
Write-Host "After rebuilding, fill in the CHANGED/REASON stub in docs\NY_NYSPIN_EJUSTICE_BUILD_NOTES.txt."
