# bump_version.ps1
# Archives the current LA_LETTS_OFML_BASE.json before running a rebuild.
# Usage: powershell.exe -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Version "1.1" -Phase "01_standup"
# Then edit build_la_letts_ofml.ps1 and re-run it with the new version.

param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Phase = ""
)

$DATE    = (Get-Date -Format 'yyyy-MM-dd')
$DIR     = "C:\Users\Gordon Hallof\LA_LETTS_OFML"
$CURRENT = "$DIR\LA_LETTS_OFML_BASE.json"

if ($Phase) {
    $ARCHIVE = "$DIR\phases\$Phase"
} else {
    $ARCHIVE = "$DIR\archive"
}

New-Item -ItemType Directory -Force -Path $ARCHIVE | Out-Null

if (Test-Path $CURRENT) {
    $dest = "$ARCHIVE\LA_LETTS_OFML_v${Version}_${DATE}.json"
    Copy-Item $CURRENT $dest
    Write-Host "Archived current -> $dest"
} else {
    Write-Host "No existing LA_LETTS_OFML_BASE.json to archive."
}

Write-Host ""
Write-Host "Now run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_la_letts_ofml.ps1 -Version '$Version' -Phase '$Phase'"
Write-Host ""
Write-Host "After rebuilding, fill in the CHANGED/REASON stub in archive\docs\LA_LETTS_OFML_BUILD_NOTES.txt."
