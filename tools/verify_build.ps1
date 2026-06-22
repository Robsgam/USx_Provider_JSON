<#
  verify_build.ps1 -- Post-build verification for provider JSONs
  Catches mistakes that slip past the structural validator:
    1. Banned string patterns (from banned_patterns.txt)
    2. QIF fieldId / QIDM sourceField / QIDM combo consistency
    3. RMS QIDM name vs sourceField alignment
    4. Cross-bundle fieldId consistency
    5. camelCase enforcement (when provider has been migrated)
    6. Standard pattern comparison (ImageIndicator, queryLabel, etc.)
    7. Cross-variant consistency (BASE vs MC field type mismatches)
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
$warnCount = 0

function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:passCount++ }
function Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warnCount++ }
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
            # Attention auto-populate handler: skip the sourceField/QIF check here
            # (the handler supplies the value). CHECK 8 (Visible-First Mandate) flags
            # the hidden-auto-populate case where no visible form field backs it.
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
        Info "RMS-only sourceFields (RMS defaults, no form match): $($orphans.Count) [$($orphans -join ', ')]"
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

# ── CHECK 6: Standard pattern comparison ──────────────────────────────────────
Write-Host ""
Write-Host "--- CHECK 6: Reference Pattern Check ---" -ForegroundColor Yellow

if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }

        if (-not $cfg.queryLabel) {
            Fail "QIDM '$($cfg.name)' missing queryLabel"
        } else {
            $validLabels = @('Vehicle Registration','Vehicle Stolen','Driver License','Driver History','DL Name Search','Firearm','Article','Boat','Wanted Person','Missing Person','Supervised Release','RMS','CCH Criminal History (QH)','CCH Name Inquiry (IQ)','CCH Wanted/III (QWI)','CCH Record Request (QR)','CCH Record Request (ZR)','CCH SID Query (FQ)','CCH Admin Query (AQ)','CCH Admin Response (AR)')
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

# ── CHECK 7: Cross-variant consistency (BASE vs MC field types) ──────────────
Write-Host ""
Write-Host "--- CHECK 7: Cross-Variant Consistency ---" -ForegroundColor Yellow

$isBase = $jsonName -match '_BASE$'
$isMc   = $jsonName -match '_MC$'
$providerDir = Split-Path $resolved -Parent

if ($isBase) {
    $mcName = $jsonName -replace '_BASE$', '_MC.json'
    $mcPath = Join-Path $providerDir $mcName
} elseif ($isMc) {
    $baseName = $jsonName -replace '_MC$', '_BASE.json'
    $mcPath = $null
    $basePath = Join-Path $providerDir $baseName
}

$otherPath = if ($isBase) { $mcPath } elseif ($isMc) { $basePath } else { $null }

if ($otherPath -and (Test-Path $otherPath)) {
    $otherJson = [System.IO.File]::ReadAllText($otherPath) | ConvertFrom-Json
    $otherEntities = $otherJson.bundles | Where-Object { $_.provider -eq 'MARK43' }
    $thisEntities = $entitiesBundle
    $otherLabel = if ($isBase) { 'MC' } else { 'BASE' }
    $thisLabel = if ($isBase) { 'BASE' } else { 'MC' }

    $fieldTypeDiffs = 0
    foreach ($thisCfg in $thisEntities.configurations) {
        if ($thisCfg.type -ne 'QUERYINPUTFORM') { continue }
        $entity = $thisCfg.targetEntity
        $otherCfg = $otherEntities.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' -and $_.targetEntity -eq $entity }
        if (-not $otherCfg) { continue }

        $thisText = $thisCfg | ConvertTo-Json -Depth 100 -Compress
        $otherText = $otherCfg | ConvertTo-Json -Depth 100 -Compress

        $thisFields = @{}
        foreach ($m in [regex]::Matches($thisText, '"fieldId"\s*:\s*"([^"]+)"[^}]*?"resolvedName"\s*:\s*"([^"]+)"')) {
            $thisFields[$m.Groups[1].Value] = $m.Groups[2].Value
        }
        foreach ($m in [regex]::Matches($thisText, '"resolvedName"\s*:\s*"([^"]+)"[^}]*?"fieldId"\s*:\s*"([^"]+)"')) {
            if (-not $thisFields.ContainsKey($m.Groups[2].Value)) {
                $thisFields[$m.Groups[2].Value] = $m.Groups[1].Value
            }
        }

        $otherFields = @{}
        foreach ($m in [regex]::Matches($otherText, '"fieldId"\s*:\s*"([^"]+)"[^}]*?"resolvedName"\s*:\s*"([^"]+)"')) {
            $otherFields[$m.Groups[1].Value] = $m.Groups[2].Value
        }
        foreach ($m in [regex]::Matches($otherText, '"resolvedName"\s*:\s*"([^"]+)"[^}]*?"fieldId"\s*:\s*"([^"]+)"')) {
            if (-not $otherFields.ContainsKey($m.Groups[2].Value)) {
                $otherFields[$m.Groups[2].Value] = $m.Groups[1].Value
            }
        }

        foreach ($fid in $thisFields.Keys) {
            $caseMatch = $otherFields.Keys | Where-Object { $_ -ieq $fid } | Select-Object -First 1
            if ($caseMatch -and $thisFields[$fid] -ne $otherFields[$caseMatch]) {
                Fail "$entity field '$fid': $thisLabel=$($thisFields[$fid]) but $otherLabel=$($otherFields[$caseMatch])"
                $fieldTypeDiffs++
            }
        }
    }
    if ($fieldTypeDiffs -eq 0) {
        Pass "All shared fields have matching types across $thisLabel and $otherLabel"
    }
} elseif ($otherPath) {
    Info "No $( if ($isBase) {'MC'} else {'BASE'} ) JSON found -- skipping cross-variant check"
} else {
    Info "Not a BASE/MC variant -- skipping cross-variant check"
}

# ── CHECK 8: Visible-First Mandate (no hidden/auto-populated fields) ──────────
# KB: BUILD_RULES.txt "Visible-First Mandate". All officer-facing query fields
# MUST be visible (hidden=false). Do NOT hide or auto-populate a field without
# explicit user approval or live-test evidence. Documented exceptions are
# whitelisted below; anything else is a WARN requiring justification.
Write-Host ""
Write-Host "--- CHECK 8: Visible-First Mandate ---" -ForegroundColor Yellow

# Whitelist of fieldId patterns that may be legitimately hidden (see BUILD_RULES.txt):
#   - RMS dual-field State (SelH for RMS + InpH for outbound XML) when NCIC single-visible unavailable
#   - dexStateUserId auto-populated from the officer's RMS profile
#   - CAD / First-Responder dispatch context fields
$hiddenFieldWhitelist = @(
    '(?i)state',                         # RMS dual-field State exception
    '(?i)dexStateUserId',                # AUTH user id from RMS profile
    '(?i)cadUnit|cadEvent|linkToEvent'   # CAD / First-Responder context
)

# Recursively collect hidden form-field nodes (hidden=true + props.fieldId + Form* type)
$hiddenFields = [System.Collections.Generic.List[object]]::new()
function Find-HiddenFields($node) {
    if ($null -eq $node) { return }
    if ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
        foreach ($item in $node) { Find-HiddenFields $item }
        return
    }
    if ($node -is [psobject]) {
        $props = $node.PSObject.Properties
        $hiddenProp = $props | Where-Object { $_.Name -eq 'hidden' }
        if ($hiddenProp -and $hiddenProp.Value -eq $true -and $node.props -and $node.props.fieldId) {
            $rn = if ($node.type -and $node.type.resolvedName) { $node.type.resolvedName } else { '' }
            if ($rn -match '^Form') {
                $hiddenFields.Add([pscustomobject]@{ fieldId = $node.props.fieldId; type = $rn })
            }
        }
        foreach ($p in $props) { Find-HiddenFields $p.Value }
    }
}
if ($entitiesBundle) { Find-HiddenFields $entitiesBundle }

$flaggedHidden = 0
$uniqueHidden = $hiddenFields | Sort-Object fieldId -Unique
foreach ($hf in $uniqueHidden) {
    $isWhitelisted = $false
    foreach ($pat in $hiddenFieldWhitelist) { if ($hf.fieldId -match $pat) { $isWhitelisted = $true; break } }
    if ($isWhitelisted) {
        Info "Hidden field '$($hf.fieldId)' ($($hf.type)) -- documented exception, allowed"
    } else {
        Warn "Hidden field '$($hf.fieldId)' ($($hf.type)) not on approved-exception list -- expose visible (hidden=false) or get approval (BUILD_RULES Visible-First Mandate)"
        $flaggedHidden++
    }
}

# Attention auto-populate handler -- APPROVED STANDARD (user decision 2026-06-22).
# Wherever Attention is part of a query it is auto-populated via
# CommsysGetLastNameFirstNameInitialRuleHandler (no visible field required).
# Flag the INVERSE: an Attention attribute with NO handler (a manual visible
# field) should be converted to the automated handler per the standard.
$autoPopHandlers = 0
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($attr in $cfg.attributes) {
            if ($attr.name -ne 'Attention') { continue }
            $hasHandler = ($attr.rule -and $attr.rule.function -match 'LastNameFirstNameInitial')
            if ($hasHandler) {
                Info "QIDM '$($cfg.name)' attr 'Attention' uses CommsysGetLastNameFirstNameInitialRuleHandler -- approved automated-Attention standard"
            } else {
                Warn "QIDM '$($cfg.name)' attr 'Attention' has no auto-populate handler -- wire CommsysGetLastNameFirstNameInitialRuleHandler per automated-Attention standard (BUILD_RULES Visible-First Mandate)"
                $autoPopHandlers++
            }
        }
    }
}

if ($flaggedHidden -eq 0 -and $autoPopHandlers -eq 0) {
    Pass "Visible-First Mandate: no unapproved hidden fields; Attention automation conforms to standard"
}

# ── CHECK 9: Synthetic keyRef documentation in build script ──────────────────
# KB: BUILD_RULES.txt Section 15. Every QIDM with >1 combo uses synthetic keyRefs
# (LIMITATION #21 or #36). The build script MUST have a LIMITATION comment block
# immediately before the $...Query definition for each such QIDM.
Write-Host ""
Write-Host "--- CHECK 9: Synthetic keyRef Documentation ---" -ForegroundColor Yellow

$providerDir   = Split-Path $resolved -Parent
$providerName  = Split-Path $providerDir -Leaf
$scriptName    = "build_$($providerName.ToLower()).ps1"
$scriptPath    = Join-Path $providerDir "scripts\$scriptName"

if (-not (Test-Path $scriptPath)) {
    Info "Build script '$scriptName' not found -- skipping synthetic keyRef documentation check"
} elseif ($providerBundle) {
    $scriptLines   = Get-Content $scriptPath
    $multiComboQIDMs = @($providerBundle.configurations | Where-Object {
        $_.type -eq 'QUERYINPUTDATAMAPPING' -and $_.combinations.Count -gt 1
    })

    $missingDocs = 0
    foreach ($cfg in $multiComboQIDMs) {
        $firstKeyRef    = $cfg.combinations[0].keyReference
        $keyRefLineIdx  = -1
        for ($i = 0; $i -lt $scriptLines.Count; $i++) {
            if ($scriptLines[$i] -match [regex]::Escape("'$firstKeyRef'")) {
                $keyRefLineIdx = $i
                break
            }
        }
        if ($keyRefLineIdx -lt 0) {
            Info "QIDM '$($cfg.name)': keyRef '$firstKeyRef' not found in build script -- skipping"
            continue
        }
        # Search the 40 lines before the first keyRef occurrence for LIMITATION #21 or #36
        $searchStart = [Math]::Max(0, $keyRefLineIdx - 40)
        $window      = $scriptLines[$searchStart..($keyRefLineIdx - 1)]
        $hasDoc      = $window | Where-Object { $_ -match 'LIMITATION #21|LIMITATION #36' }
        if (-not $hasDoc) {
            Warn "QIDM '$($cfg.name)' has $($cfg.combinations.Count) combos but build script has no LIMITATION #21/#36 comment before keyRef '$firstKeyRef' -- add synthetic keyRef block (BUILD_RULES Section 15)"
            $missingDocs++
        }
    }

    if ($missingDocs -eq 0) {
        if ($multiComboQIDMs.Count -gt 0) {
            Pass "All $($multiComboQIDMs.Count) multi-combo QIDMs have LIMITATION #21/#36 documentation in build script"
        } else {
            Info "No multi-combo QIDMs -- synthetic keyRef documentation not required"
        }
    }
} else {
    Info "No provider bundle -- skipping synthetic keyRef documentation check"
}

# ── CHECK 10: RMS combos subset of CommSys combos ────────────────────────────
# RMS must not query on a field-path the CommSys form doesn't actually map. Every field
# used in an RMS combo's set[]/any[] should also appear in some CommSys combo's set[]/any[].
# A drift (RMS field with no CommSys counterpart) means the two bundles disagree on what the
# officer can search -- usually a rename that landed in one bundle but not the other.
Write-Host ""
Write-Host "--- CHECK 10: RMS combos subset of CommSys combos ---" -ForegroundColor Yellow

function Get-ComboReqFields($bundle) {
    $fields = [System.Collections.Generic.HashSet[string]]::new()
    if (-not $bundle) { return $fields }
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($combo in $cfg.combinations) {
            if ($combo.requirements.set) { foreach ($f in $combo.requirements.set) { [void]$fields.Add($f) } }
            if ($combo.requirements.any) { foreach ($f in $combo.requirements.any) { [void]$fields.Add($f) } }
        }
    }
    return $fields
}

# RMS-generic combo fields legitimately have no CommSys counterpart -- the shared RMS module
# (_build_rms_bundle.ps1) searches on these even when the provider's CommSys form does not.
$rmsGenericFields = @('raceCode','socialSecurityNumber')

if ($providerBundle -and $rmsBundle) {
    $commsysComboFields = Get-ComboReqFields $providerBundle
    $rmsComboFields     = Get-ComboReqFields $rmsBundle
    $drift = @($rmsComboFields | Where-Object { -not $commsysComboFields.Contains($_) -and ($rmsGenericFields -notcontains $_) })
    if ($drift.Count -gt 0) {
        Warn "RMS combo field(s) not used by any CommSys combo (RMS/CommSys drift): $($drift -join ', ')"
    } else {
        Pass "RMS combo fields ($($rmsComboFields.Count)) are a subset of CommSys combo fields ($($commsysComboFields.Count)) (RMS-generic allowed)"
    }
} else {
    Info "No RMS+CommSys bundle pair -- skipping RMS subset check"
}

# ── CHECK 11: surviving value-comparison routing conditions ───────────────────
# POISONED-ARRAY RULE (QIDM_REFERENCE Sec 2a, LIVE-PROVEN FL v4.9 T-A/T-B): a conditions
# array containing ANY value-comparison operator (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) is
# disabled in its entirety, incl. co-resident EXISTS/NOT_EXISTS. Flag survivors for review
# at this provider's rebuild -- redesign to presence/existence-only routing or escalate.
Write-Host ""
Write-Host "--- CHECK 11: Value-Comparison Conditions (poisoned-array) ---" -ForegroundColor Yellow

$valueOps = @('EQUALS','NOT_EQUALS','IN','NOT_IN','REGEX')
$valueComparisonHits = @()
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($combo in $cfg.combinations) {
            # conditions live under requirements.conditions (the combo-level "conditions"
            # property is a separate, unused null field). Check both for safety.
            $condArrays = @()
            if ($combo.requirements -and $combo.requirements.conditions) { $condArrays += ,$combo.requirements.conditions }
            if ($combo.conditions) { $condArrays += ,$combo.conditions }
            foreach ($conds in $condArrays) {
                foreach ($cond in $conds) {
                    if ($cond.operator -and ($valueOps -contains $cond.operator)) {
                        $valueComparisonHits += "$($cfg.name)/$($combo.keyReference): $($cond.operator)"
                    }
                }
            }
        }
    }
}
if ($valueComparisonHits.Count -gt 0) {
    Warn "Value-comparison conditions present (poisoned-array; inert on CommSys form path) -- redesign at rebuild: $($valueComparisonHits -join '; ')"
} else {
    Pass "No value-comparison routing conditions (existence-only or none)"
}

# ── SUMMARY ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($failCount -gt 0) {
    Write-Host " VERIFICATION FAILED: $failCount FAIL / $warnCount WARN / $passCount PASS" -ForegroundColor Red
} elseif ($warnCount -gt 0) {
    Write-Host " VERIFICATION PASSED (with warnings): $passCount PASS / $warnCount WARN / 0 FAIL" -ForegroundColor Yellow
} else {
    Write-Host " VERIFICATION PASSED: $passCount PASS / 0 WARN / 0 FAIL" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failCount -gt 0) { exit 1 }
