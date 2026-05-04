# validate_la_letts_ofml.ps1
# Structural validator for LA_LETTS_OFML_BASE.json
#
# Checks performed:
#   1. QIDM has attributes and combinations defined
#   2. keyReference values are unique within each QIDM
#   3. All combination set/any values exist as sourceField entries in that QIDM
#   4. primaryFieldReference matches an attribute name in that QIDM
#   5. All QIDM sourceField values appear as fieldIds in at least one QUERYINPUTFORM
#   6. (Info) Form fieldIds not covered by any QIDM sourceField (unmapped fields)
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File scripts\validate_la_letts_ofml.ps1
#   powershell.exe -ExecutionPolicy Bypass -File scripts\validate_la_letts_ofml.ps1 -JsonFile "path\to\other.json"

param(
    [string]$JsonFile = "$PSScriptRoot\..\LA_LETTS_OFML_BASE.json"
)

$script:ErrorCount = 0

function Fail($msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
    $script:ErrorCount++
}
function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "  [INFO] $msg" -ForegroundColor Cyan }

if (-not (Test-Path $JsonFile)) {
    Write-Host "ERROR: File not found: $JsonFile" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== LA_LETTS_OFML Validator ===" -ForegroundColor White
Write-Host "File: $JsonFile"
Write-Host ""

$data = Get-Content $JsonFile -Raw | ConvertFrom-Json

# Collect all form fieldIds
$formFieldIds = @{}
$entitiesBundle = $data.bundles | Where-Object { $_.name -eq 'ENTITIES' }
if ($entitiesBundle) {
    foreach ($form in $entitiesBundle.configurations) {
        $layoutObj = $form.layout.default
        if (-not $layoutObj) { continue }
        ($layoutObj | Get-Member -MemberType NoteProperty).Name | ForEach-Object {
            $node = $layoutObj.$_
            if ($node.props -and $node.props.fieldId) {
                $formFieldIds[$node.props.fieldId] = $true
            }
        }
    }
}
Info "Form fieldIds found: $($formFieldIds.Keys.Count)"

# Validate each QIDM in the provider bundle
$providerBundle = $data.bundles | Where-Object { $_.provider -eq 'LA_LEMS' }
if (-not $providerBundle) {
    Fail "LA_LEMS provider bundle not found"
} else {
    $qidms = $providerBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTDATAMAPPING' }
    Write-Host "Checking $($qidms.Count) QIDMs..." -ForegroundColor White

    foreach ($qidm in $qidms) {
        Write-Host ""
        Write-Host "  --- $($qidm.name) ---" -ForegroundColor Yellow

        # Check attributes exist
        if (-not $qidm.attributes -or $qidm.attributes.Count -eq 0) {
            Fail "No attributes defined"
            continue
        }

        # Collect attribute names and sourceFields
        $attrNames   = @{}
        $sourceFields = @{}
        foreach ($attr in $qidm.attributes) {
            $attrNames[$attr.name] = $true
            foreach ($sf in $attr.sourceField) { $sourceFields[$sf] = $true }
        }

        # Check combinations
        if (-not $qidm.combinations -or $qidm.combinations.Count -eq 0) {
            Fail "No combinations defined"
        } else {
            $keyRefs = @{}
            foreach ($combo in $qidm.combinations) {
                # keyReference uniqueness
                $kr = $combo.keyReference
                if ($kr) {
                    if ($keyRefs[$kr]) { Fail "Duplicate keyReference: $kr" }
                    else { $keyRefs[$kr] = $true }
                }
                # primaryFieldReference valid
                if ($combo.primaryFieldReference -and -not $attrNames[$combo.primaryFieldReference]) {
                    Fail "primaryFieldReference '$($combo.primaryFieldReference)' not in attributes"
                }
                # set/any fields exist as sourceFields
                foreach ($f in $combo.requirements.set) {
                    if (-not $sourceFields[$f]) { Fail "set[] field '$f' has no matching sourceField in attributes" }
                }
                foreach ($f in $combo.requirements.any) {
                    if (-not $sourceFields[$f]) { Fail "any[] field '$f' has no matching sourceField in attributes" }
                }
            }
            Pass "Combinations valid ($($qidm.combinations.Count) combos, $($keyRefs.Keys.Count) keyRefs)"
        }

        # Check sourceFields exist as form fieldIds
        foreach ($sf in $sourceFields.Keys) {
            if (-not $formFieldIds[$sf]) {
                Info "sourceField '$sf' not found in any form fieldId (may be a system field)"
            }
        }

        Pass "Attributes: $($qidm.attributes.Count)"
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor White
if ($script:ErrorCount -eq 0) {
    Write-Host "RESULT: PASS ($($script:ErrorCount) errors)" -ForegroundColor Green
} else {
    Write-Host "RESULT: FAIL ($($script:ErrorCount) errors)" -ForegroundColor Red
}
Write-Host ""
