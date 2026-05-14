<#
  _migrate_mc_to_hidle_mc.ps1 — Migrate MC build scripts to use HIDLE_MC.json
  Replaces HIDLE.json load + all RMS patches with HIDLE_MC.json load + cleanup-only.
  Also removes LicensePlateNumberIn string replacements from output section.

  Usage: powershell -ExecutionPolicy Bypass -File _migrate_mc_to_hidle_mc.ps1 [-DryRun]
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$base = (Resolve-Path "$PSScriptRoot\..\providers").Path

$providers = @{
    'TX_TLETS' = @{
        script = 'build_tx_tlets_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $true
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'HI_HCJDC_OFML' = @{
        script = 'build_hi_hcjdc_ofml_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'LA_LEMS' = @{
        script = 'build_la_lems_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $true
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'NY_NYSPIN_EJUSTICE' = @{
        script = 'build_ny_nyspin_ejustice_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'CA_VENTURA_COUNTY' = @{
        script = 'build_ca_ventura_county_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'CA_eSUN' = @{
        script = 'build_ca_esun_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'CA_SAN_LUIS_OBISPO' = @{
        script = 'build_ca_san_luis_obispo_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'CA_CLETS_OCATS' = @{
        script = 'build_ca_clets_ocats_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'IL_LEADS_OFML' = @{
        script = 'build_il_leads_ofml_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'MD_METERS' = @{
        script = 'build_md_meters_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS','race'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $true
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'OH_LEADS' = @{
        script = 'build_oh_leads_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'NM_NMLETS_OFML' = @{
        script = 'build_nm_nmlets_ofml_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'OR_LEDS' = @{
        script = 'build_or_leds_mc.ps1'
        deadPerAttrs = "'socialSecurityNumber','licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'firstNameLastNameSocialSecurityNumber','driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $false
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
    'AZ_AZDPS' = @{
        script = 'build_az_azdps_mc.ps1'
        deadPerAttrs = "'licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $true
        removePlateYear = $true
        varName = '$rmsVehQidm'
    }
    'TN_TIES' = @{
        script = 'build_tn_ties_mc.ps1'
        deadPerAttrs = "'licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS'"
        deadPerCombos = "'driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS'"
        filterRaceCode = $false
        keepSSN = $true
        removePlateYear = $false
        varName = '$rmsVehQidm'
    }
}

$changed = 0
$errors  = 0

foreach ($prov in $providers.Keys | Sort-Object) {
    $cfg = $providers[$prov]
    $dir = Get-ChildItem $base -Directory | Where-Object { $_.Name -like "${prov}*" } | Select-Object -First 1
    if (-not $dir) { Write-Host "  [SKIP] $prov -- folder not found" -ForegroundColor Yellow; continue }

    $scriptPath = Join-Path $dir.FullName "scripts\$($cfg.script)"
    if (-not (Test-Path $scriptPath)) { Write-Host "  [SKIP] $prov -- script not found: $scriptPath" -ForegroundColor Yellow; continue }

    $content = Get-Content $scriptPath -Raw
    $original = $content

    # 1. Update HIDLE path: source\HIDLE.json -> ..\..\templates\HIDLE_MC.json
    $content = $content -replace '\$DIR\\source\\HIDLE\.json', '$DIR\..\..\templates\HIDLE_MC.json'
    $content = $content -replace 'source\\HIDLE\.json', '..\..\templates\HIDLE_MC.json'

    # 2. Find RMS section boundaries
    $lines = $content -split "`r?`n"
    $rmsStart = -1
    $rmsEnd   = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'BUNDLE 3: RMS|RMS \(from HIDLE|RMS \(identical') {
            $rmsStart = $i
        }
        if ($rmsStart -ge 0 -and $i -gt $rmsStart + 2) {
            if ($lines[$i] -match '^\s*#\s*=+' -and $i -gt $rmsStart + 3) {
                $nextLine = if ($i + 1 -lt $lines.Count) { $lines[$i + 1] } else { '' }
                if ($nextLine -match 'WRITE OUTPUT|FINAL ASSEMBLY|OUTPUT|WRITE|ASSEMBLY') {
                    $rmsEnd = $i - 1
                    break
                }
                if ($lines[$i + 1] -match '^\s*#\s*=+') {
                    $lookAhead = if ($i + 2 -lt $lines.Count) { $lines[$i + 2] } else { '' }
                    if ($lookAhead -match '\$output\s*=|\$final\s*=|\$json\s*=') {
                        $rmsEnd = $i - 1
                        break
                    }
                }
            }
        }
    }

    if ($rmsStart -lt 0) {
        Write-Host "  [ERROR] $prov -- could not find RMS section start" -ForegroundColor Red
        $errors++
        continue
    }

    # If we couldn't find the end by section marker, look for the output variable assignment
    if ($rmsEnd -lt 0) {
        for ($i = $rmsStart + 5; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*#\s*=+\s*$') {
                $j = $i + 1
                while ($j -lt $lines.Count -and $lines[$j] -match '^\s*#') { $j++ }
                if ($j -lt $lines.Count -and $lines[$j] -match '^\s*\$(output|final|json)\s*=') {
                    $rmsEnd = $i - 1
                    break
                }
            }
        }
    }

    if ($rmsEnd -lt 0) {
        Write-Host "  [ERROR] $prov -- could not find RMS section end (start at line $($rmsStart+1))" -ForegroundColor Red
        $errors++
        continue
    }

    # Build the new RMS section
    $newRms = @()
    $newRms += '# BUNDLE 3: RMS (from HIDLE_MC -- camelCase, registrationState, autoSelect pre-configured)'
    $newRms += '# ====================================================================='
    $newRms += '$rmsBundle = $hidle.bundles | Where-Object { $_.name -eq ''RMS'' }'
    $newRms += '$rmsVehQidm    = $rmsBundle.configurations | Where-Object { $_.name -eq ''RMS Vehicle search query'' }'
    $newRms += '$rmsPersonQidm = $rmsBundle.configurations | Where-Object { $_.query -eq ''Person'' }'
    $newRms += ''
    $newRms += '# RMS cleanup: remove unused HIDLE fields'
    $newRms += "`$deadVehAttrs = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')"
    $newRms += '$rmsVehQidm.attributes   = @($rmsVehQidm.attributes   | Where-Object { $_.name -notin $deadVehAttrs })'
    $newRms += '$rmsVehQidm.combinations = @($rmsVehQidm.combinations | Where-Object { $_.keyReference -notin @(''licensePlateOutAndState'',''OwnerFirstAndLastName'') })'
    $newRms += 'foreach ($combo in $rmsVehQidm.combinations) {'
    $newRms += '    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -notin $deadVehAttrs })'
    $newRms += '}'

    if ($cfg.removePlateYear) {
        $newRms += ''
        $newRms += '# AZ-specific: remove LicensePlateYear from Vehicle any[] (no elastic mapping)'
        $newRms += 'foreach ($combo in $rmsVehQidm.combinations) {'
        $newRms += '    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne ''LicensePlateYear'' })'
        $newRms += '}'
    }

    $newRms += ''
    $newRms += "`$deadPerAttrs = @($($cfg.deadPerAttrs))"
    $newRms += '$rmsPersonQidm.attributes   = @($rmsPersonQidm.attributes   | Where-Object { $_.name -notin $deadPerAttrs })'
    $newRms += '$rmsPersonQidm.combinations = @($rmsPersonQidm.combinations | Where-Object {'
    $newRms += "    `$_.keyReference -notin @($($cfg.deadPerCombos))"
    $newRms += '})'

    if ($cfg.filterRaceCode) {
        $newRms += 'foreach ($combo in $rmsPersonQidm.combinations) {'
        $newRms += '    $combo.requirements.any = @($combo.requirements.any | Where-Object { $_ -ne ''RaceCode'' })'
        $newRms += '}'
    }

    # Reconstruct the file
    $before = $lines[0..($rmsStart - 1)]
    $after  = $lines[($rmsEnd + 1)..($lines.Count - 1)]
    $newLines = @()
    $newLines += $before
    $newLines += $newRms
    $newLines += ''
    $newLines += $after

    $content = $newLines -join "`r`n"

    # 3. Remove LicensePlateNumberIn replacement lines
    $content = $content -replace "(?m)^\s*\`\$json\s*=\s*\`\$json\s*-replace\s*'LicensePlateNumberIn'.*\r?\n", ''
    $content = $content -replace "(?m)^\s*\`\$jsonReadable\s*=\s*\`\$jsonReadable\s*-replace\s*'LicensePlateNumberIn'.*\r?\n", ''
    $content = $content -replace "(?m)^\s*#\s*Patch 8:.*LicensePlateNumberIn.*\r?\n", ''

    # 4. Remove autoSelect patch blocks (already in HIDLE_MC)
    $content = $content -replace "(?ms)foreach\s*\(\`\$rmsCfg\s+in\s+\`\$rmsBundle\.configurations\)\s*\{[^}]*autoSelect[^}]*\}\s*\r?\n?", ''

    # 5. Fix AZ-specific: replace $rmsVehicleQidm refs in OUTPUT section with $rmsVehQidm (now standardized)
    # Actually, AZ has a completely different structure — it builds $final first, then patches.
    # With HIDLE_MC, the RMS bundle is patched BEFORE assembly, so $final just includes $rmsBundle.

    # 6. Update header comments: HIDLE.json -> HIDLE_MC.json
    $content = $content -replace 'HIDLE\.json \(RMS template\)', 'HIDLE_MC.json (RMS template — camelCase, registrationState, autoSelect)'
    $content = $content -replace 'source\\HIDLE\.json\s+--\s+RMS template', 'templates\HIDLE_MC.json -- RMS template (camelCase, registrationState, autoSelect)'
    $content = $content -replace 'Patch 1\+3\+6\+7\+8', 'cleanup only (HIDLE_MC pre-configured)'
    $content = $content -replace 'Patch 1\+3\+6\+7', 'cleanup only (HIDLE_MC pre-configured)'
    $content = $content -replace 'RMS: Patched \(1\+3\+6\+7\+8\)', 'RMS: cleanup only (HIDLE_MC pre-configured)'
    $content = $content -replace 'RMS: Patched \(1\+3\+6\+7\)', 'RMS: cleanup only (HIDLE_MC pre-configured)'

    if ($content -eq $original) {
        Write-Host "  [SKIP] $prov -- no changes needed" -ForegroundColor Gray
        continue
    }

    if ($DryRun) {
        Write-Host "  [DRY] $prov -- would update $scriptPath" -ForegroundColor Cyan
        $changed++
    } else {
        [System.IO.File]::WriteAllText($scriptPath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  [OK] $prov -- updated $($cfg.script)" -ForegroundColor Green
        $changed++
    }
}

Write-Host ""
Write-Host "Migration complete: $changed updated, $errors errors"
if ($DryRun) { Write-Host "(DRY RUN -- no files were modified)" -ForegroundColor Yellow }
