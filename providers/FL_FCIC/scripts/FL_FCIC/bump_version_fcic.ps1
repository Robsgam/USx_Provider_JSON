# bump_version_fcic.ps1
# Archives the current FL_FCIC.json to phases/ before applying a new change.
# Usage: powershell.exe -ExecutionPolicy Bypass -File bump_version_fcic.ps1 -Version "2.1"
# After archiving, apply your change script, then update VERSIONS.txt with what changed.

param([Parameter(Mandatory)][string]$Version)

$DATE   = (Get-Date -Format 'yyyy-MM-dd')
$DIR    = "C:\Users\Gordon Hallof\FL_FCIC"
$PHASES = "$DIR\phases"
$CURRENT = "$DIR\FL_FCIC.json"

New-Item -ItemType Directory -Force -Path $PHASES | Out-Null

if (Test-Path $CURRENT) {
    $dest = "$PHASES\FL_FCIC_v${Version}_${DATE}.json"
    Copy-Item $CURRENT $dest
    Write-Host "Archived current FL_FCIC.json -> $dest"
} else {
    Write-Host "No existing FL_FCIC.json to archive."
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Apply your change script"
Write-Host "  2. Update VERSIONS.txt with what changed in v$Version"
Write-Host "  3. git add / commit / push"
