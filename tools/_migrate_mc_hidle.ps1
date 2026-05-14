<#
  _migrate_mc_hidle.ps1 — Migrate MC build scripts from HIDLE.json + patches to HIDLE_MC.json (clean build)
  Removes: Patches 1, 3, 7, 8, 9 and Apply-CadFieldAlignment
  Keeps: Patch 6 (renamed to "RMS cleanup")
  Updates: HIDLE.json path → HIDLE_MC.json, header comments
  Usage: powershell -File _migrate_mc_hidle.ps1 -Path <build_script.ps1> [-DryRun]
#>
param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$lines = Get-Content $Path
$out = [System.Collections.Generic.List[string]]::new()
$removed = @{ patch1=0; patch3=0; patch7=0; patch8=0; patch9=0; cadAlign=0; hidlePath=0 }
$skip = $false
$skipUntil = $null

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # ── Skip Apply-CadFieldAlignment block ──
    if ($line -match '# CAD Field Alignment:') {
        $skip = $true
        $removed.cadAlign++
        continue
    }
    if ($skip -and $line -match '-RmsBundle') {
        $skip = $false
        continue
    }
    if ($skip) { continue }

    # ── Replace HIDLE.json path with HIDLE_MC.json ──
    if ($line -match 'HIDLE\.json' -and $line -notmatch 'HIDLE_MC\.json') {
        $newLine = $line -replace 'source[/\\]+HIDLE\.json', '..\..\..\..\templates\HIDLE_MC.json' `
                         -replace 'source\\HIDLE\.json', '..\..\..\..\templates\HIDLE_MC.json' `
                         -replace "source\\\\HIDLE\.json", '..\..\..\..\templates\HIDLE_MC.json'
        if ($newLine -eq $line) {
            $newLine = $line -replace 'HIDLE\.json', 'HIDLE_MC.json'
        }
        $out.Add($newLine)
        $removed.hidlePath++
        continue
    }

    # ── Remove Patch 1 block (add registrationState to Vehicle combo) ──
    if ($line -match '# Patch 1:' -or ($line -match 'Patch 1' -and $line -match 'registrationState|RegistrationState')) {
        $skip = $true
        $skipUntil = 'nextSection'
        $removed.patch1++
        continue
    }

    # ── Remove Patch 3 block (add registrationState to Person QIDM) ──
    if ($line -match '# Patch 3:' -or ($line -match 'Patch 3' -and $line -match 'RegistrationState|registrationState')) {
        $skip = $true
        $skipUntil = 'nextSection'
        $removed.patch3++
        continue
    }

    # ── Remove Patch 7 block (autoSelect=true) ──
    if ($line -match '# Patch 7:' -or ($line -match 'Patch 7' -and $line -match 'autoSelect')) {
        $skip = $true
        $skipUntil = 'nextSection'
        $removed.patch7++
        continue
    }

    # ── Remove Patch 8 block (LicensePlateNumberIn rename) ──
    if ($line -match '# Patch 8' -or ($line -match 'Patch 8' -and $line -match 'LicensePlateNumberIn')) {
        $skip = $true
        $skipUntil = 'nextSection'
        $removed.patch8++
        continue
    }

    # ── Remove Patch 9 block (camelCase alignment) ──
    if ($line -match '# Patch 9:' -or ($line -match 'Patch 9' -and $line -match 'camelCase')) {
        $skip = $true
        $skipUntil = 'nextSection'
        $removed.patch9++
        continue
    }

    # ── Skip detection: content lines that belong to a removed patch ──
    if ($skip) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed -match '^#\s*(=|Patch|WRITE|BUNDLE|RMS)' -or $trimmed -match '^\$output\b') {
            $skip = $false
            $out.Add($line)
        }
        continue
    }

    # ── Rename Patch 6 header to "RMS cleanup" ──
    if ($line -match '# Patch 6:' -or $line -match '#\s*Patch 6\b') {
        $out.Add(($line -replace 'Patch 6[^#]*', 'RMS cleanup: remove unused HIDLE fields'))
        continue
    }

    # ── Remove standalone LicensePlateNumberIn replacement lines ──
    if ($line -match 'LicensePlateNumberIn' -and $line -match '-replace|\.Replace') {
        $removed.patch8++
        continue
    }

    # ── Update RMS bundle header comment ──
    if ($line -match 'BUNDLE 3: RMS.*HIDLE' -and $line -notmatch 'HIDLE_MC') {
        $out.Add(($line -replace 'from HIDLE[^)]*', 'from HIDLE_MC — camelCase, registrationState, autoSelect pre-configured'))
        continue
    }

    # ── Update MC variant header comment ──
    if ($line -match '# MC variant:.*PascalCase') {
        $out.Add(($line -replace 'PascalCase fieldIds.*$', 'camelCase fieldIds for CAD auto-populate.'))
        continue
    }

    $out.Add($line)
}

# ── Clean up consecutive blank lines (max 2) ──
$final = [System.Collections.Generic.List[string]]::new()
$blankCount = 0
foreach ($line in $out) {
    if ($line.Trim() -eq '') {
        $blankCount++
        if ($blankCount -le 2) { $final.Add($line) }
    } else {
        $blankCount = 0
        $final.Add($line)
    }
}

$content = $final -join "`r`n"

if ($DryRun) {
    Write-Host "[DRY RUN] Would modify: $Path"
} else {
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Migrated: $Path"
}

Write-Host "  Removed: Patch1=$($removed.patch1) Patch3=$($removed.patch3) Patch7=$($removed.patch7) Patch8=$($removed.patch8) Patch9=$($removed.patch9) CadAlign=$($removed.cadAlign)"
Write-Host "  HIDLE path updated: $($removed.hidlePath)"
