# bump_version.ps1
# Archives the current AZ_AZDPS.json before running a rebuild.
# Usage: powershell.exe -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Version "1.2" -Phase "02_person"
# Then edit build_az_azdps.ps1 and re-run it with the new version.

param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Phase = ""
)

$DATE    = (Get-Date -Format 'yyyy-MM-dd')
$DIR     = "C:\Users\RobSgambellone\.local\bin\AZ_AZDPS"
$CURRENT = "$DIR\AZ_AZDPS.json"

if ($Phase) {
    $ARCHIVE = "$DIR\phases\$Phase"
} else {
    $ARCHIVE = "$DIR\archive"
}

New-Item -ItemType Directory -Force -Path $ARCHIVE | Out-Null

if (Test-Path $CURRENT) {
    $dest = "$ARCHIVE\AZ_AZDPS_v${Version}_${DATE}.json"
    Copy-Item $CURRENT $dest
    Write-Host "Archived current -> $dest"
} else {
    Write-Host "No existing AZ_AZDPS.json to archive."
}

Write-Host ""
Write-Host "Now run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps.ps1 -Version '$Version' -Phase '$Phase'"
Write-Host ""
Write-Host "After rebuilding, fill in the CHANGED/REASON stub in docs\AZ_AZDPS_BUILD_NOTES.txt."
