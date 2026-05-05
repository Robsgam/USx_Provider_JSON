<#
  verify_build.ps1 -- Post-build verification for provider JSONs
  Catches mistakes that slip past the structural validator:
    1. Banned string patterns (from banned_patterns.txt)
    2. QIF fieldId / QIDM sourceField / QIDM combo consistency
    3. RMS QIDM name vs sourceField alignment
  FAILS the build if any check fails. Called automatically by build_report.ps1.

  Usage: .\verify_build.ps1 -Path <provider.json>
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
$toolDir = $PSScriptRoot

$resolved = Resolve-Path $Path
$jsonName = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
$rawText = [System.IO.File]::ReadAllText($resolved)
$json = $rawText | ConvertFrom-Json

$failCount = 0
$passCount = 0

function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:passCount++ }
function Info($msg) { Write-Host "  [INFO] $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " POST-BUILD VERIFICATION: $jsonName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ── CHECK 1: Banned patterns ──────────────────────────────────────────────────
Write-Host ""
Write-Host "--- CHECK 1: Banned Patterns ---" -ForegroundColor Yellow

$bannedFile = Join-Path $toolDir "banned_patterns.txt"
if (Test-Path $bannedFile) {
    $patterns = Get-Content $bannedFile | Where-Object { $_ -and $_ -notmatch '^\s*#' -and $_.Trim() -ne '' }
    foreach ($pat in $patterns) {
        $matches = [regex]::Matches($rawText, $pat)
        if ($matches.Count -gt 0) {
            Fail "Banned pattern '$pat' found $($matches.Count) time(s)"
        } else {
            Pass "No banned pattern '$pat'"
        }
    }
} else {
    Info "No banned_patterns.txt found -- skipping"
}

# ── CHECK 2: QIF fieldId vs QIDM sourceField consistency ─────────────────────
Write-Host ""
Write-Host "--- CHECK 2: fieldId / sourceField Consistency ---" -ForegroundColor Yellow

$entitiesBundle = $json.bundles | Where-Object { $_.provider -eq 'MARK43' }
$providerBundle = $json.bundles | Where-Object { $_.provider -ne 'MARK43' -and $_.provider -ne 'RMS' }
$rmsBundle = $json.bundles | Where-Object { $_.provider -eq 'RMS' }

$formFieldIds = @{}
if ($entitiesBundle) {
    foreach ($cfg in $entitiesBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        $entity = $cfg.targetEntity
        $nodesJson = $cfg.formConfiguration.formLayout.default
        if (-not $nodesJson) { continue }
        $nodes = if ($nodesJson -is [string]) { $nodesJson | ConvertFrom-Json } else { $nodesJson }
        foreach ($prop in $nodes.PSObject.Properties) {
            $node = $prop.Value
            if ($node.props -and $node.props.fieldId) {
                if (-not $formFieldIds.ContainsKey($entity)) { $formFieldIds[$entity] = [System.Collections.Generic.HashSet[string]]::new() }
                [void]$formFieldIds[$entity].Add($node.props.fieldId)
            }
        }
    }
}

if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $entity = $cfg.targetEntity
        $qidmName = $cfg.name
        $entityFields = if ($formFieldIds.ContainsKey($entity)) { $formFieldIds[$entity] } else { $null }

        foreach ($attr in $cfg.attributes) {
            foreach ($sf in $attr.sourceField) {
                if ($entityFields -and -not $entityFields.Contains($sf)) {
                    Fail "QIDM '$qidmName' attr '$($attr.name)' sourceField='$sf' not in $entity QIF fieldIds"
                }
            }
        }

        foreach ($combo in $cfg.combinations) {
            $allRefs = @()
            if ($combo.requirements.set) { $allRefs += $combo.requirements.set }
            if ($combo.requirements.any) { $allRefs += $combo.requirements.any }
            $attrNames = @($cfg.attributes | ForEach-Object { $_.name })
            $attrSources = @($cfg.attributes | ForEach-Object { $_.sourceField } | ForEach-Object { $_ })

            foreach ($ref in $allRefs) {
                if ($ref -notin $attrSources) {
                    Fail "QIDM '$qidmName' combo ref '$ref' not in any attribute sourceField"
                }
            }

            if ($combo.primaryFieldReference) {
                if ($combo.primaryFieldReference -notin $attrNames) {
                    Fail "QIDM '$qidmName' primaryFieldReference='$($combo.primaryFieldReference)' not in attribute names [$($attrNames -join ', ')]"
                }
            }
        }
    }
    Pass "CommSys QIDM fieldId/sourceField/combo consistency checked"
}

# ── CHECK 3: RMS QIDM name vs sourceField alignment ──────────────────────────
Write-Host ""
Write-Host "--- CHECK 3: RMS QIDM Consistency ---" -ForegroundColor Yellow

if ($rmsBundle) {
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $qidmName = $cfg.name
        $attrNames = @($cfg.attributes | ForEach-Object { $_.name })

        foreach ($combo in $cfg.combinations) {
            $allRefs = @()
            if ($combo.requirements.set) { $allRefs += $combo.requirements.set }
            if ($combo.requirements.any) { $allRefs += $combo.requirements.any }

            foreach ($ref in $allRefs) {
                $matchAttr = $cfg.attributes | Where-Object { $_.sourceField -contains $ref }
                if (-not $matchAttr) {
                    Fail "RMS '$qidmName' combo ref '$ref' has no matching attribute sourceField"
                }
            }

            if ($combo.primaryFieldReference -and $combo.primaryFieldReference -notin $attrNames) {
                Fail "RMS '$qidmName' primaryFieldReference='$($combo.primaryFieldReference)' not in attribute names"
            }
        }
    }
    Pass "RMS QIDM name/sourceField/combo consistency checked"
}

# ── CHECK 4: Cross-bundle fieldId consistency ─────────────────────────────────
Write-Host ""
Write-Host "--- CHECK 4: Cross-Bundle fieldId Consistency ---" -ForegroundColor Yellow

if ($providerBundle -and $rmsBundle) {
    $commsysSources = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($attr in $cfg.attributes) {
            foreach ($sf in $attr.sourceField) { [void]$commsysSources.Add($sf) }
        }
    }

    $rmsSources = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($attr in $cfg.attributes) {
            foreach ($sf in $attr.sourceField) { [void]$rmsSources.Add($sf) }
        }
    }

    $shared = @($commsysSources | Where-Object { $rmsSources.Contains($_) })
    $commsysOnly = @($commsysSources | Where-Object { -not $rmsSources.Contains($_) })
    $rmsOnly = @($rmsSources | Where-Object { -not $commsysSources.Contains($_) })

    Info "Shared fieldIds (CommSys+RMS): $($shared.Count)"
    Info "CommSys-only: $($commsysOnly.Count) [$($commsysOnly -join ', ')]"
    if ($rmsOnly.Count -gt 0) {
        Info "RMS-only (expected for RMS-specific fields): $($rmsOnly.Count)"
    }

    $orphans = @()
    foreach ($sf in $rmsSources) {
        $allFormFields = @()
        foreach ($k in $formFieldIds.Keys) { $allFormFields += $formFieldIds[$k] }
        if ($sf -notin $allFormFields -and $sf -notin $commsysSources) {
            $orphans += $sf
        }
    }
    if ($orphans.Count -gt 0) {
        Info "RMS-only sourceFields (HIDLE defaults, no form match): $($orphans.Count) [$($orphans -join ', ')]"
    }
    Pass "Cross-bundle fieldId consistency checked"
}

# ── SUMMARY ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($failCount -gt 0) {
    Write-Host " VERIFICATION FAILED: $failCount FAIL / $passCount PASS" -ForegroundColor Red
} else {
    Write-Host " VERIFICATION PASSED: $passCount PASS / 0 FAIL" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) { exit 1 }
