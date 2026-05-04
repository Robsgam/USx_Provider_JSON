# bump_version.ps1
# Archives the current NJ_NJCJIS.json before running a rebuild.
# Usage: powershell.exe -ExecutionPolicy Bypass -File bump_version.ps1 -Version "1.1"
# Then edit build_nj_njcjis.ps1 and re-run it with the new version.

param([Parameter(Mandatory)][string]$Version)

$DATE    = (Get-Date -Format 'yyyy-MM-dd')
$DIR     = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$ARCHIVE = "$DIR\archive"
$CURRENT = "$DIR\NJ_NJCJIS.json"

New-Item -ItemType Directory -Force -Path $ARCHIVE | Out-Null

if (Test-Path $CURRENT) {
    $dest = "$ARCHIVE\NJ_NJCJIS_v${Version}_${DATE}.json"
    Copy-Item $CURRENT $dest
    Write-Host "Archived current -> $dest"
} else {
    Write-Host "No existing NJ_NJCJIS.json to archive."
}

Write-Host "Now run: powershell.exe -ExecutionPolicy Bypass -File build_nj_njcjis.ps1 -Version '$Version'"
Write-Host ""
Write-Host "After rebuilding, update VERSIONS.txt with what changed in v$Version."
