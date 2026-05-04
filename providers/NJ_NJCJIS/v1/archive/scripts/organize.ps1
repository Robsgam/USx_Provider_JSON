$root = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"

New-Item -ItemType Directory -Force -Path "$root\scripts" | Out-Null
New-Item -ItemType Directory -Force -Path "$root\docs"    | Out-Null

Get-ChildItem "$root\*.ps1" | Where-Object { $_.Name -ne 'organize.ps1' } | Move-Item -Destination "$root\scripts\" -Force
Get-ChildItem "$root\*.txt" | Move-Item -Destination "$root\docs\" -Force

$ghost = "$root\`$base"
if (Test-Path $ghost) { Remove-Item $ghost -Recurse -Force; Write-Host "Removed ghost folder" }

Write-Host "scripts/:" ((Get-ChildItem "$root\scripts" | Select-Object -ExpandProperty Name) -join ", ")
Write-Host "docs/:"    ((Get-ChildItem "$root\docs"    | Select-Object -ExpandProperty Name) -join ", ")
Write-Host "root files:" ((Get-ChildItem "$root" -File | Select-Object -ExpandProperty Name) -join ", ")
