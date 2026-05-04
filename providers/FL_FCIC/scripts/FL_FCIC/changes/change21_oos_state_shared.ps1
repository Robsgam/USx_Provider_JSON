$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

# ─── 1. Update State_OutStatePlate fieldId in all 3 layout variants ────────────
$oos = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Vehicle_OOS' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $node = $oos.layout.$variant.State_OutStatePlate
    if ($node) {
        $node.props.fieldId = 'RegistrationState'
        Write-Host "${variant}: State_OutStatePlate fieldId -> RegistrationState"
    }
}

# ─── 2. Remove RegistrationStateOut attribute from VRQ ─────────────────────────
$vrq = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_VehicleRegistrationQuery') { $vrq = $_ }
        }
    }
}

$vrq.attributes = @($vrq.attributes | Where-Object { $_.name -ne 'RegistrationStateOut' })
Write-Host "Removed attribute: RegistrationStateOut"

# ─── 3. Update QV/RQ plate combinations: RegistrationStateOut -> RegistrationState ─
foreach ($combo in $vrq.combinations) {
    $combo.requirements.set = @($combo.requirements.set | ForEach-Object {
        if ($_ -eq 'RegistrationStateOut') { 'RegistrationState' } else { $_ }
    })
}
Write-Host "Combinations updated: RegistrationStateOut -> RegistrationState"

# ─── 4. Write back ─────────────────────────────────────────────────────────────
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
