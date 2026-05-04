# bump_version.ps1
# Archives the current FL_FCIC_BASE.json before running a rebuild.
# Usage: powershell.exe -ExecutionPolicy Bypass -File bump_version.ps1 -Version "1.1"
# Then edit build_fl_fcic.ps1 if needed and re-run it with the new version.

param([Parameter(Mandatory)][string]$Version)

$DATE    = (Get-Date -Format 'yyyy-MM-dd')
$DIR     = "C:\Users\Gordon Hallof\FL_FCIC"
$ARCHIVE = "$DIR\archive"
$CURRENT = "$DIR\FL_FCIC_BASE.json"

New-Item -ItemType Directory -Force -Path $ARCHIVE | Out-Null

if (Test-Path $CURRENT) {
    $dest = "$ARCHIVE\FL_FCIC_BASE_v${Version}_${DATE}.json"
    Copy-Item $CURRENT $dest
    Write-Host "Archived current -> $dest"
} else {
    Write-Host "No existing FL_FCIC_BASE.json to archive."
}

Write-Host "Now run: powershell.exe -ExecutionPolicy Bypass -File build_fl_fcic.ps1 -Version '$Version'"
Write-Host ""
Write-Host "After rebuilding, update VERSIONS.txt with what changed in v$Version."
