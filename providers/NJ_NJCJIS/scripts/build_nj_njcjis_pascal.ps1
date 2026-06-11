# build_nj_njcjis_pascal.ps1 -- NJ_NJCJIS PASCAL TEST VARIANT (testing only)
# =====================================================================
# TESTING-ONLY ARTIFACT (2026-06-11) -- DO NOT IMPORT AS MAINLINE
# Purpose: manual CAD + OnScene casing test. OnScene (Forge entity config)
# reportedly sends PascalCase; CAD sends camelCase. This JSON recases the
# form-side layer of MAINLINE NJ_NJCJIS.json to PascalCase so both products
# can be probed against it. Expected outcomes when testing:
#   - OnScene (PascalCase) SHOULD populate/fire.
#   - CAD (camelCase)      SHOULD FAIL to auto-populate (that is the experiment).
#
# Mechanism: loads the CURRENT mainline NJ_NJCJIS.json and renames every
# exact-match camelCase form field string to PascalCase:
#   - QIF layout props.fieldId (all entities, all 3 variants)
#   - QIDM sourceField arrays (CommSys + RMS)
#   - combo set[]/any[] entries (CommSys + RMS)
#   - QRDM internal attribute names where they exact-match (consistent, harmless)
# UNCHANGED: QIDM attribute names + targetFields (already PascalCase -- the
# NJCJIS XML is identical), defaults[].field, conditions refs (attribute
# names), keyReference values (excluded), AUTH, QMF, CAD context tokens,
# RMS elastic targetFields, node keys.
#
# Spelling authority: inverse of tools/config/patch8_rename_map.json where
# available; first-letter-uppercase otherwise; ncicNumber -> NCICNumber
# special-cased to match the attribute name.
# KNOWN WATCH ITEM: pure recase yields GunSerialNumber/ArticleSerialNumber;
# the OnScene/Forge list uses generic 'SerialNumber' -- those two fields are
# expected NOT to populate from OnScene. Record, don't fix here.
#
# No existing build scripts or shared tools are modified by this generator.
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_nj_njcjis_pascal.ps1
# =====================================================================

$DIR = (Resolve-Path "$PSScriptRoot\..").Path
$SRC = "$DIR\NJ_NJCJIS.json"
$OUT = "$DIR\NJ_NJCJIS_PASCAL.json"

# camelCase -> PascalCase rename map (NJ field set; exact-string-value matches only)
$renames = @{
    'licensePlateNumber'          = 'LicensePlateNumber'
    'licensePlateTypeCode'        = 'LicensePlateTypeCode'
    'licensePlateYear'            = 'LicensePlateYear'
    'randomRequest'               = 'RandomRequest'
    'registrationState'           = 'RegistrationState'
    'imageIndicator'              = 'ImageIndicator'
    'vehicleIdentificationNumber' = 'VehicleIdentificationNumber'
    'ncicNumber'                  = 'NCICNumber'
    'vehicleMakeCode'             = 'VehicleMakeCode'
    'nameFirst'                   = 'NameFirst'
    'nameLast'                    = 'NameLast'
    'birthDate'                   = 'BirthDate'
    'sexCode'                     = 'SexCode'
    'operatorLicenseNumber'       = 'OperatorLicenseNumber'
    'gunSerialNumber'             = 'GunSerialNumber'
    'gunMake'                     = 'GunMake'
    'gunCaliber'                  = 'GunCaliber'
    'gunModel'                    = 'GunModel'
    'articleSerialNumber'         = 'ArticleSerialNumber'
    'articleTypeCode'             = 'ArticleTypeCode'
    'registrationNumber'          = 'RegistrationNumber'
    'boatHullIdNumber'            = 'BoatHullIdNumber'
}

function Convert-Casing($node, $parentProp) {
    if ($null -eq $node) { return $null }
    if ($node -is [string]) {
        # keyReference values stay as-built (platform-internal labels)
        if ($parentProp -eq 'keyReference') { return $node }
        if ($renames.ContainsKey($node) -and $renames[$node] -cne $node) { return $renames[$node] }
        return $node
    }
    if ($node -is [array]) {
        return ,@($node | ForEach-Object { Convert-Casing $_ $parentProp })
    }
    if ($node -is [PSCustomObject]) {
        foreach ($p in $node.PSObject.Properties) {
            $p.Value = Convert-Casing $p.Value $p.Name
        }
        return $node
    }
    return $node
}

if (-not (Test-Path $SRC)) { throw "Mainline JSON not found: $SRC" }
$json = Get-Content $SRC -Raw | ConvertFrom-Json

$json = Convert-Casing $json $null

# Mark the provider bundle so the variant is identifiable on the tenant
foreach ($b in $json.bundles) {
    if ($b.provider -eq 'NJ_NJCJIS') {
        $b.description = "$($b.description) -- PASCAL test variant (form-side fieldIds recased; testing only)"
    }
}

$json | ConvertTo-Json -Depth 100 | Out-File $OUT -Encoding utf8NoBOM
Write-Host "Built NJ_NJCJIS_PASCAL.json (testing-only PascalCase variant from mainline)" -ForegroundColor Green
Write-Host "  -> $OUT"

# Structural validation (read-only check; casing-specific audits intentionally skipped)
$VALIDATOR = Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1" -ErrorAction SilentlyContinue
if ($VALIDATOR) {
    & $VALIDATOR.Path -Path $OUT
}
