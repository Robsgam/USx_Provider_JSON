$raw = Get-Content 'D:/JSON BACKUP/FL_FCIC.json' -Raw -Encoding UTF8
if ($raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
$j = $raw | ConvertFrom-Json

$currentYear = (Get-Date).Year.ToString()

# ─── 1. Update LPYear_InStatePlate and LPYear_InStateDecal fieldIds in all 3 layout variants ───
$inState = $j.bundles[0].configurations | Where-Object { $_.name -eq 'ENTITY_Vehicle_InState' }

foreach ($variant in @('default','CAD_DISPATCH','FIRST_RESPONDER')) {
    $nodes = $inState.layout.$variant
    foreach ($key in @('LPYear_InStatePlate','LPYear_InStateDecal')) {
        $node = $nodes.$key
        if ($node) {
            $node.props.fieldId       = 'LicensePlateYear'
            $node.props | Add-Member -NotePropertyName 'initialValue' -NotePropertyValue $currentYear -Force
        }
    }
    Write-Host "${variant}: LPYear_InStatePlate + LPYear_InStateDecal updated, fieldId=LicensePlateYear, initialValue=$currentYear"
}

# ─── 2. Update FL_FCIC_VehicleRegistrationQuery ────────────────────────────────
$vrq = $null
$j.bundles | ForEach-Object {
    if ($_.configurations) {
        $_.configurations | ForEach-Object {
            if ($_.name -eq 'FL_FCIC_VehicleRegistrationQuery') { $vrq = $_ }
        }
    }
}

# Rename LicensePlateYearIn attribute to LicensePlateYear, remove LicensePlateYearDecal
$newAttrs = [System.Collections.Generic.List[object]]::new()
foreach ($attr in $vrq.attributes) {
    switch ($attr.name) {
        'LicensePlateYearIn' {
            $attr.name        = 'LicensePlateYear'
            $attr.sourceField = @('LicensePlateYear')
            $newAttrs.Add($attr)
        }
        'LicensePlateYearDecal' {
            # Drop — now covered by LicensePlateYear
            Write-Host "Removed attribute: LicensePlateYearDecal"
        }
        default { $newAttrs.Add($attr) }
    }
}
$vrq.attributes = $newAttrs.ToArray()
Write-Host "Renamed LicensePlateYearIn -> LicensePlateYear"

# ─── 3. Update combinations ────────────────────────────────────────────────────
foreach ($combo in $vrq.combinations) {
    $combo.requirements.set = $combo.requirements.set | ForEach-Object {
        switch ($_) {
            'LicensePlateYearIn'    { 'LicensePlateYear' }
            'LicensePlateYearDecal' { 'LicensePlateYear' }
            default                 { $_ }
        }
    }
}
Write-Host "Combinations updated: LicensePlateYearIn/Decal -> LicensePlateYear"

# ─── 4. Write back ─────────────────────────────────────────────────────────────
$out = $j | ConvertTo-Json -Depth 100 -Compress
[System.IO.File]::WriteAllText('D:/JSON BACKUP/FL_FCIC.json', $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "Done."
