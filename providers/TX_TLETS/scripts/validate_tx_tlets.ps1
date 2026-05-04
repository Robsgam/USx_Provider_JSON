# validate_tx_tlets.ps1
# Structural validator for TX_TLETS.json
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
#   powershell.exe -ExecutionPolicy Bypass -File scripts\validate_tx_tlets.ps1
#   powershell.exe -ExecutionPolicy Bypass -File scripts\validate_tx_tlets.ps1 -JsonFile "path\to\other.json"

param(
    [string]$JsonFile = "$PSScriptRoot\..\TX_TLETS.json"
)

$script:ErrorCount = 0
$script:WarnCount  = 0

function Write-Pass  ($msg) { Write-Host "  [PASS]  $msg" -ForegroundColor Green  }
function Write-Fail  ($msg) { Write-Host "  [FAIL]  $msg" -ForegroundColor Red;    $script:ErrorCount++ }
function Write-Warn  ($msg) { Write-Host "  [WARN]  $msg" -ForegroundColor Yellow; $script:WarnCount++  }
function Write-Info  ($msg) { Write-Host "  [INFO]  $msg" -ForegroundColor Cyan    }
function Write-Header($msg) { Write-Host "`n--- $msg ---" -ForegroundColor White   }

if (-not (Test-Path $JsonFile)) {
    Write-Host "ERROR: File not found: $JsonFile" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor White
Write-Host " TX_TLETS JSON VALIDATOR" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host " File: $JsonFile"
Write-Host " Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

$json = Get-Content $JsonFile -Raw | ConvertFrom-Json
$allConfigs = $json.bundles | ForEach-Object { $_.configurations }

$qidms = @($allConfigs | Where-Object { $_.type -eq "QUERYINPUTDATAMAPPING" -and $_.provider -eq "TX_TLETS" })
$qifs  = @($allConfigs | Where-Object { $_.type -eq "QUERYINPUTFORM" })

Write-Host " QIDMs (TX_TLETS): $($qidms.Count)"
Write-Host " QIFs  (ENTITIES): $($qifs.Count)"

# Build form fieldId index
$formFieldIndex = @{}
foreach ($qif in $qifs) {
    $label = $qif.label
    if (-not $qif.layout -or -not $qif.layout.default) { continue }
    foreach ($nodeProp in $qif.layout.default.PSObject.Properties) {
        $node = $nodeProp.Value
        if ($node.props -and $node.props.PSObject.Properties.Name -contains "fieldId") {
            $fid = $node.props.fieldId
            if ($fid -and $fid -ne "") {
                if (-not $formFieldIndex.ContainsKey($fid)) {
                    $formFieldIndex[$fid] = [System.Collections.Generic.List[string]]::new()
                }
                if ($label -notin $formFieldIndex[$fid]) { $formFieldIndex[$fid].Add($label) }
            }
        }
    }
}
Write-Host " Unique form fieldIds: $($formFieldIndex.Count)"

# QIF count check
Write-Header "CHECK 0 -- ENTITIES Bundle QIF Count"
$expectedQifCount = 5   # Vehicle, Person, Firearm, Article, Boat
if ($qifs.Count -eq $expectedQifCount) {
    Write-Pass "QIF count = $($qifs.Count) (expected $expectedQifCount)"
} else {
    Write-Warn "QIF count = $($qifs.Count), expected $expectedQifCount"
    Write-Info "Present QIFs: $(($qifs | ForEach-Object { $_.label }) -join ', ')"
}

# Per-QIDM checks
$globalSourceFieldMap = @{}
foreach ($qidm in $qidms) {
    Write-Header "QIDM: $($qidm.name)  [query=$($qidm.query), entity=$($qidm.targetEntity)]"

    if (-not $qidm.attributes -or $qidm.attributes.Count -eq 0) {
        Write-Warn "No attributes defined"
        continue
    }

    $sfLookup   = @{}
    $attrNameSet = @{}
    foreach ($attr in $qidm.attributes) {
        $attrNameSet[$attr.name] = $true
        foreach ($sf in $attr.sourceField) {
            $sfLookup[$sf] = $attr.name
            $globalSourceFieldMap[$sf] = $qidm.name
        }
    }

    Write-Info "Attributes ($($qidm.attributes.Count)): $(($sfLookup.Keys | Sort-Object) -join ', ')"

    if (-not $qidm.combinations -or $qidm.combinations.Count -eq 0) {
        Write-Warn "No combinations defined"
    } else {
        $keyRefs = @($qidm.combinations | ForEach-Object { $_.keyReference })
        $dupes   = $keyRefs | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($dupes) {
            foreach ($d in $dupes) { Write-Fail "Duplicate keyReference: '$($d.Name)'" }
        } else {
            Write-Pass "keyReferences unique [$($keyRefs -join ', ')]"
        }

        $comboOk = $true
        foreach ($combo in $qidm.combinations) {
            $kr   = $combo.keyReference
            $refs = [System.Collections.Generic.List[string]]::new()
            if ($combo.requirements.set) { foreach ($v in $combo.requirements.set) { $refs.Add($v) } }
            if ($combo.requirements.any) { foreach ($v in $combo.requirements.any) { $refs.Add($v) } }
            foreach ($ref in $refs) {
                if (-not $sfLookup.ContainsKey($ref)) {
                    Write-Fail "[$kr] combination ref '$ref' not found as a sourceField in this QIDM"
                    $comboOk = $false
                }
            }
            if ($combo.primaryFieldReference) {
                $pfr = $combo.primaryFieldReference
                if (-not $attrNameSet.ContainsKey($pfr)) {
                    Write-Fail "[$kr] primaryFieldReference '$pfr' is not an attribute name in this QIDM"
                    $comboOk = $false
                }
            }
        }
        if ($comboOk) { Write-Pass "All combination field references valid" }
    }

    $sfOk = $true
    foreach ($sf in ($sfLookup.Keys | Sort-Object)) {
        if (-not $formFieldIndex.ContainsKey($sf)) {
            Write-Fail "sourceField '$sf' (attr '$($sfLookup[$sf])') not found as a fieldId in any QUERYINPUTFORM"
            $sfOk = $false
        }
    }
    if ($sfOk) { Write-Pass "All $($sfLookup.Count) sourceFields exist as form fieldIds" }
}

# Coverage check
Write-Header "CHECK -- QIF fieldId Coverage"
$unmapped = @($formFieldIndex.Keys | Where-Object { -not $globalSourceFieldMap.ContainsKey($_) } | Sort-Object)
$knownUnmapped = @(
    "CAD_UNIT_SELECT_VALUE",
    "CAD_EVENT_SELECT_VALUE",
    "RegistrationState"
)
$unexpectedUnmapped = $unmapped | Where-Object { $_ -notin $knownUnmapped }
$expectedUnmapped   = $unmapped | Where-Object { $_ -in    $knownUnmapped }
foreach ($f in $expectedUnmapped)   { Write-Info "Unmapped (by design): '$f' in [$($formFieldIndex[$f] -join ', ')]" }
foreach ($f in $unexpectedUnmapped) { Write-Warn "Unmapped (unexpected): '$f' in [$($formFieldIndex[$f] -join ', ')]" }
if ($unexpectedUnmapped.Count -eq 0) { Write-Pass "No unexpected unmapped form fields" }

# Summary
Write-Host "`n========================================" -ForegroundColor White
Write-Host " SUMMARY" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
if ($script:ErrorCount -eq 0 -and $script:WarnCount -eq 0) {
    Write-Host " All checks passed. File is structurally clean." -ForegroundColor Green
} else {
    $color = if ($script:ErrorCount -gt 0) { "Red" } else { "Yellow" }
    Write-Host " Errors:   $($script:ErrorCount)" -ForegroundColor $color
    Write-Host " Warnings: $($script:WarnCount)"  -ForegroundColor Yellow
}
Write-Host ""
exit $script:ErrorCount
