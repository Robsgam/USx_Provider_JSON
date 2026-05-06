<#
  verify_build.ps1 -- Post-build verification for provider JSONs
  Catches mistakes that slip past the structural validator:
    1. Banned string patterns (from banned_patterns.txt)
    2. QIF fieldId / QIDM sourceField / QIDM combo consistency
    3. RMS QIDM name vs sourceField alignment
    4. Cross-bundle fieldId consistency
    5. camelCase enforcement (when provider has been migrated)
    6. NJ reference pattern comparison (ImageIndicator, queryLabel, etc.)
  FAILS the build if any check fails. Called automatically by build_report.ps1.

  Usage: .\verify_build.ps1 -Path <provider.json>
         .\verify_build.ps1 -Path <provider.json> -CamelCase
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [switch]$CamelCase
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
        if (-not $formFieldIds.ContainsKey($entity)) { $formFieldIds[$entity] = [System.Collections.Generic.HashSet[string]]::new() }
        $cfgText = $cfg | ConvertTo-Json -Depth 100 -Compress
        $fieldMatches = [regex]::Matches($cfgText, '"fieldId"\s*:\s*"([^"]+)"')
        foreach ($m in $fieldMatches) {
            [void]$formFieldIds[$entity].Add($m.Groups[1].Value)
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
            # Attention uses handler auto-populate (no form field needed)
            if ($attr.rule -and $attr.rule.function -match 'LastNameFirstNameInitial') { continue }
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

# ── CHECK 5: camelCase fieldId enforcement ────────────────────────────────────
Write-Host ""
Write-Host "--- CHECK 5: camelCase Enforcement ---" -ForegroundColor Yellow

if ($CamelCase) {
    $platformFields = @('CAD_UNIT_SELECT_VALUE','CAD_EVENT_SELECT_VALUE','LINK_CURRENT_ASSIGNED_EVENT')
    $allFieldIds = @()
    foreach ($k in $formFieldIds.Keys) { $allFieldIds += $formFieldIds[$k] }
    $entityFieldIds = @($allFieldIds | Where-Object { $_ -notin $platformFields })
    $badCase = @($entityFieldIds | Where-Object { $_ -cmatch '^[A-Z]' })
    if ($badCase.Count -gt 0) {
        Fail "QIF fieldIds starting with uppercase (should be camelCase): $($badCase -join ', ')"
    } else {
        Pass "All $($entityFieldIds.Count) QIF fieldIds are camelCase (excluded $($platformFields.Count) platform fields)"
    }

    if ($providerBundle) {
        $badSources = @()
        foreach ($cfg in $providerBundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            foreach ($attr in $cfg.attributes) {
                foreach ($sf in $attr.sourceField) {
                    if ($sf -cmatch '^[A-Z]') { $badSources += "$($cfg.name).$sf" }
                }
            }
        }
        if ($badSources.Count -gt 0) {
            Fail "CommSys QIDM sourceFields starting with uppercase: $($badSources -join ', ')"
        } else {
            Pass "All CommSys QIDM sourceFields are camelCase"
        }
    }
} else {
    Info "camelCase check skipped (use -CamelCase to enable)"
}

# ── CHECK 6: NJ reference pattern comparison ─────────────────────────────────
Write-Host ""
Write-Host "--- CHECK 6: Reference Pattern Check ---" -ForegroundColor Yellow

if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }

        if (-not $cfg.queryLabel) {
            Fail "QIDM '$($cfg.name)' missing queryLabel"
        } else {
            $validLabels = @('Vehicle Registration','Vehicle Stolen','Driver License','Driver History','Firearm','Article','Boat','Wanted Person','Missing Person','Supervised Release','RMS')
            if ($cfg.queryLabel -notin $validLabels) {
                Fail "QIDM '$($cfg.name)' queryLabel='$($cfg.queryLabel)' not in standard set [$($validLabels -join ', ')]"
            }
        }

        $imgAttr = $cfg.attributes | Where-Object { $_.name -match '[Ii]mage[Ii]ndicator' }
        if ($imgAttr) {
            if ($imgAttr.size -ne 1) {
                Fail "QIDM '$($cfg.name)' ImageIndicator size=$($imgAttr.size), must be 1"
            }
        }

        foreach ($combo in $cfg.combinations) {
            if (-not $combo.keyReference) {
                Fail "QIDM '$($cfg.name)' has a combination with no keyReference"
            }
            if (-not $combo.state) {
                Fail "QIDM '$($cfg.name)' has a combination with no state"
            }
        }
    }
    Pass "Reference patterns checked (queryLabel, ImageIndicator size, keyReference, state)"
}

if ($rmsBundle) {
    $rmsAutoSelectCount = 0
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if ($cfg.autoSelect -eq $true) { $rmsAutoSelectCount++ }
        else { Fail "RMS QIDM '$($cfg.name)' missing autoSelect=true" }
    }
    if ($rmsAutoSelectCount -gt 0) {
        Pass "All $rmsAutoSelectCount RMS QIDMs have autoSelect=true"
    }
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
