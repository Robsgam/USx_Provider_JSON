$base    = "C:\Users\RobSgambellone\.local\bin\NJ_NJCJIS"
$archive = "$base\archive"
$logs    = "$base\logs"
$phases  = "$base\phases"

# Create phase directories
@("$phases\01_standup",
  "$phases\02_person",
  "$phases\02_person\logs",
  "$phases\03_vehicle",
  "$phases\03_vehicle\logs",
  "$phases\04_firearm",
  "$phases\04_firearm\logs",
  "$phases\05_article",
  "$phases\05_article\logs",
  "$phases\06_boat",
  "$phases\06_boat\logs") | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
Write-Host "Directories created"

# Phase 01 standup -- v1.0 to v1.3
Copy-Item "$archive\NJ_NJCJIS_v1.0_2026-04-07.json" "$phases\01_standup\" -Force
Copy-Item "$archive\NJ_NJCJIS_v1.1_2026-04-07.json" "$phases\01_standup\" -Force
Copy-Item "$archive\NJ_NJCJIS_v1.2_2026-04-07.json" "$phases\01_standup\" -Force
Copy-Item "$archive\NJ_NJCJIS_v1.3_2026-04-07.json" "$phases\01_standup\" -Force

# Phase 02 person -- v1.4 to v2.1
@("v1.4","v1.5","v1.6","v1.7","v1.8","v1.9","v2.0","v2.1") | ForEach-Object {
    Copy-Item "$archive\NJ_NJCJIS_${_}_2026-04-08.json" "$phases\02_person\" -Force
}

# Phase 02 logs -- all DL query logs
Get-ChildItem "$logs\*.txt" | Copy-Item -Destination "$phases\02_person\logs\" -Force

Write-Host "Phase 01 standup: $((@(Get-ChildItem "$phases\01_standup\*.json")).Count) JSON files"
Write-Host "Phase 02 person:  $((@(Get-ChildItem "$phases\02_person\*.json")).Count) JSON files, $((@(Get-ChildItem "$phases\02_person\logs\*.txt")).Count) logs"
