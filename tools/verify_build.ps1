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
    # FAIL, not skip: a missing rules file means the banned-pattern gate silently
    # no-ops and legacy anti-patterns creep back in unnoticed (finding J).
    Fail "banned_patterns.txt missing ($bannedFile) -- banned-pattern gate cannot run"
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
    Info "Single-JSON provider -- skipping cross-variant check"
}

# ── CHECK 8: Visible-First Mandate (no hidden/auto-populated fields) ──────────
# KB: BUILD_RULES.txt "Visible-First Mandate". All officer-facing query fields
# MUST be visible (hidden=false). Do NOT hide or auto-populate a field without
# explicit user approval or USx Tenant Testing evidence. Documented exceptions are
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
    '(?i)cadUnit|cadEvent|linkToEvent',  # CAD / First-Responder context
    '(?i)^Attention$'                    # auto-Attention gate-feeder (handler emits officer profile name; field hidden, value ignored)
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
        # Fields required (set[]) across this QIDM's combos. A REQUIRED Attention
        # (e.g. CCH criminal-history queries) is legitimately an officer-supplied
        # visible field -- the name-derived handler is the OPTIONAL-Attention
        # standard only -- so exempt required Attention from the WARN.
        $setFields = @()
        foreach ($c in $cfg.combinations) {
            if ($c.requirements -and $c.requirements.set) { $setFields += @($c.requirements.set) }
        }
        foreach ($attr in $cfg.attributes) {
            if ($attr.name -ne 'Attention') { continue }
            $hasHandler = ($attr.rule -and $attr.rule.function -match 'LastNameFirstNameInitial')
            $isRequired = ($setFields -contains 'Attention')
            foreach ($sf in $attr.sourceField) { if ($setFields -contains $sf) { $isRequired = $true } }
            if ($hasHandler) {
                # IMPORT CONSTRAINT (live-proven HI v2.5, 2026-06-22): ConnectCic REJECTS a
                # query-input-data-mapping attribute with an EMPTY sourceField
                # ("Invalid attributes found ... [Attention]"). So this handler's attribute
                # MUST carry a non-empty sourceField (e.g. @('Attention')) to import.
                # CAVEAT: with a sourceField that names no real form field, the attribute is
                # gated out of serialization at query time, so Attention never reaches the
                # wire -- the auto-Attention handler is effectively inert on this platform.
                # See RULE_HANDLERS.txt entry 13 + [[project_attention_sourcefield_bug]].
                $sfCount = @($attr.sourceField).Count
                if ($sfCount -eq 0) {
                    Fail "QIDM '$($cfg.name)' attr 'Attention' uses CommsysGetLastNameFirstNameInitialRuleHandler with EMPTY sourceField -- ConnectCic REJECTS this at import (live-proven HI v2.5). sourceField MUST be non-empty, e.g. @('Attention')"
                    $autoPopHandlers++
                } else {
                    Info "QIDM '$($cfg.name)' attr 'Attention' uses CommsysGetLastNameFirstNameInitialRuleHandler (non-empty sourceField -- importable; NOTE: does not serialize on this platform, see RULE_HANDLERS.txt entry 13)"
                }
            } elseif ($isRequired) {
                Info "QIDM '$($cfg.name)' attr 'Attention' is required (set[]) -- officer-supplied visible field, exempt from automated-Attention standard"
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

    # A file-level "keyRef INVENTORY (LIMITATION #21)" comment block that NAMES each QIDM is
    # equivalent documentation to a per-QIDM comment (and arguably better -- one place, complete).
    # Accept it: a QIDM passes if its query name appears in a comment line and the inventory
    # header exists. (HI/NJ use this style; FL uses per-QIDM. Both are valid.)
    $hasInventory = @($scriptLines | Where-Object { $_ -match 'INVENTORY' -and $_ -match 'LIMITATION #(21|36)' }).Count -gt 0

    $missingDocs = 0
    foreach ($cfg in $multiComboQIDMs) {
        # File-level inventory path: QIDM's query name documented in a comment line.
        if ($hasInventory) {
            $namedInComment = @($scriptLines | Where-Object { $_ -match '^\s*#' -and $_ -match [regex]::Escape($cfg.query) }).Count -gt 0
            if ($namedInComment) { continue }
        }
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
        # Search the 60 lines before the first keyRef occurrence for LIMITATION #21 or #36
        # (60 rather than 40: long attribute sections push the LIMITATION comment 40-50 lines back)
        $searchStart = [Math]::Max(0, $keyRefLineIdx - 60)
        $window      = $scriptLines[$searchStart..($keyRefLineIdx - 1)]
        $hasDoc      = $window | Where-Object { $_ -match 'LIMITATION #21|LIMITATION #36' }
        if (-not $hasDoc) {
            Fail "QIDM '$($cfg.name)' has $($cfg.combinations.Count) combos but build script has no LIMITATION #21/#36 comment (per-QIDM or file-level inventory naming '$($cfg.query)') -- add synthetic keyRef doc (BUILD_RULES Section 15)"
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

# ── CHECK 12: Identifier-priority guardrail (Plate>VIN, OLN>Name, Hull>Reg) ───
# KB: BUILD_RULES.txt "IDENTIFIER-PRIORITY GUARDRAIL". Covers Vehicle (Plate>VIN, HI v3.6),
# Person DL+DH (OLN>Name, FL/HI v3.7-3.8), and Boat (Hull>Reg, HI v3.9). DH-suffixed tokens
# are matched via the optional (DH)? in the OLN/Name regexes.
# When one QIDM has combos for two different search identifiers an officer can fill together,
# the platform serializes the UNION of all satisfied combos' set[]+any[] (LIMITATION #1). The
# lower-priority combos must carry a NOT_EXISTS condition on the higher-priority identifier's
# sourceField so they exit the pool. Casing-agnostic: matches the provider's actual token.
Write-Host ""
Write-Host "--- CHECK 12: Identifier-Priority Guardrail ---" -ForegroundColor Yellow

# does combo set[] contain a token matching $rx (case-insensitive, whole token)?
function Set-HasToken($combo, [string]$rx) {
    if (-not ($combo.requirements -and $combo.requirements.set)) { return $false }
    foreach ($f in @($combo.requirements.set)) { if ([string]$f -match $rx) { return $true } }
    return $false
}
# does combo any[] contain a token matching $rx? A lower-priority combo that lists the
# HIGHER-priority identifier in its OWN any[] is an INTENTIONAL dual-identifier combo
# (officer may supply both; e.g. FL Boat QB/BQ Hull+Reg companions) -- it is NOT a pure
# single-identifier combo, so the guardrail does not apply and we must not flag it.
function Any-HasToken($combo, [string]$rx) {
    if (-not ($combo.requirements -and $combo.requirements.any)) { return $false }
    foreach ($f in @($combo.requirements.any)) { if ([string]$f -match $rx) { return $true } }
    return $false
}
# does combo have a NOT_EXISTS condition whose field[] includes a token matching $rx?
function Has-NotExistsOn($combo, [string]$rx) {
    $conds = @()
    if ($combo.requirements -and $combo.requirements.conditions) { $conds += @($combo.requirements.conditions) }
    if ($combo.conditions) { $conds += @($combo.conditions) }
    foreach ($c in $conds) {
        if ($c.operator -eq 'NOT_EXISTS') {
            foreach ($fld in @($c.field)) { if ([string]$fld -match $rx) { return $true } }
        }
    }
    return $false
}

# Optional 'DH' suffix: DriverHistoryQuery combos use DH-suffixed sourceFields
# (OperatorLicenseNumberDH, NameLastDH/NameFirstDH). Without matching the suffix, CHECK 12
# was blind to the DH OLN/Name pair and never enforced the guardrail there (HI v3.7 gap,
# found live 2026-06-23 -> v3.8). Per-QIDM loop keeps DL (unsuffixed) and DH (suffixed) isolated.
$rxPlate = '(?i)^licensePlateNumber(DH)?$'
$rxVin   = '(?i)^vehicleIdentificationNumber(DH)?$'
$rxOln   = '(?i)^operatorLicenseNumber(DH)?$'
$rxName  = '(?i)^name(Last|First)(DH)?$'
# Boat: Hull > Reg. Hull ID (HIN) is the unique permanent identifier (VIN-like); Registration
# Number is reassignable (plate-like). HI v3.9 (found during HI review 2026-06-23).
$rxHull  = '(?i)^boatHullIdNumber$'
$rxReg   = '(?i)^registrationNumber$'
$guardViolations = 0
$guardPairs = 0

if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $combos = @($cfg.combinations)

        # Vehicle: Plate > VIN
        $hasPlate = @($combos | Where-Object { Set-HasToken $_ $rxPlate }).Count -gt 0
        $hasVin   = @($combos | Where-Object { Set-HasToken $_ $rxVin   }).Count -gt 0
        if ($hasPlate -and $hasVin) {
            $guardPairs++
            foreach ($c in $combos) {
                # pure VIN combo = set has VIN, and Plate is neither in set[] nor any[] (any[] = intentional dual-id combo, exempt)
                if ((Set-HasToken $c $rxVin) -and -not (Set-HasToken $c $rxPlate) -and -not (Any-HasToken $c $rxPlate)) {
                    if (-not (Has-NotExistsOn $c $rxPlate)) {
                        Fail "QIDM '$($cfg.name)' VIN combo '$($c.keyReference)' missing LicensePlateNumber NOT_EXISTS (plate>VIN guardrail; plate+VIN co-entry will bleed VIN into plate XML)"
                        $guardViolations++
                    }
                }
            }
        }

        # Person: OLN > Name
        $hasOln  = @($combos | Where-Object { Set-HasToken $_ $rxOln  }).Count -gt 0
        $hasName = @($combos | Where-Object { Set-HasToken $_ $rxName }).Count -gt 0
        if ($hasOln -and $hasName) {
            $guardPairs++
            foreach ($c in $combos) {
                # pure Name combo = set has Name, and OLN is neither in set[] nor any[] (any[] = intentional dual-id combo, exempt)
                if ((Set-HasToken $c $rxName) -and -not (Set-HasToken $c $rxOln) -and -not (Any-HasToken $c $rxOln)) {
                    if (-not (Has-NotExistsOn $c $rxOln)) {
                        Fail "QIDM '$($cfg.name)' Name combo '$($c.keyReference)' missing OperatorLicenseNumber NOT_EXISTS (OLN>Name guardrail; OLN+Name co-entry will bleed Name into OLN XML)"
                        $guardViolations++
                    }
                }
            }
        }

        # Boat: Hull > Reg
        $hasHull = @($combos | Where-Object { Set-HasToken $_ $rxHull }).Count -gt 0
        $hasReg  = @($combos | Where-Object { Set-HasToken $_ $rxReg  }).Count -gt 0
        if ($hasHull -and $hasReg) {
            $guardPairs++
            foreach ($c in $combos) {
                # pure Reg combo = set has RegistrationNumber, and Hull is neither in set[] nor any[]
                # (Hull in any[] = intentional Hull+Reg companion combo, e.g. FL Boat QB/BQ -- exempt)
                if ((Set-HasToken $c $rxReg) -and -not (Set-HasToken $c $rxHull) -and -not (Any-HasToken $c $rxHull)) {
                    if (-not (Has-NotExistsOn $c $rxHull)) {
                        Fail "QIDM '$($cfg.name)' Reg combo '$($c.keyReference)' missing BoatHullIdNumber NOT_EXISTS (Hull>Reg guardrail; Hull+Reg co-entry will bleed RegistrationNumber into Hull XML)"
                        $guardViolations++
                    }
                }
            }
        }
    }
    if ($guardViolations -eq 0) {
        if ($guardPairs -gt 0) { Pass "Identifier-priority guardrail satisfied on $guardPairs identifier pair(s)" }
        else { Info "No coexisting Plate/VIN or OLN/Name combo pairs -- guardrail not applicable" }
    }
} else {
    Info "No provider bundle -- skipping identifier-priority guardrail check"
}

# ── CHECK 13: conditions[].field must reference a QIF sourceField ──────────────
# INERT-CONDITIONS ROOT CAUSE (LIVE-PROVEN FL v4.x-v5.x, HI v3.2-v3.3): a conditions[].field
# value that does not match any QIF sourceField/fieldId is SILENTLY INERT on the platform.
# Casing matters -- 'State' != 'RegistrationState' (FL bug), 'State' != 'RegistrationState'
# (HI v3.2 M55S bug). The $formFieldIds hash built in CHECK 2 holds every fieldId from each
# entity's QIF. Case-sensitive match is intentional (casing IS the bug pattern).
Write-Host ""
Write-Host "--- CHECK 13: conditions[].field references a valid QIF sourceField ---" -ForegroundColor Yellow

$condFieldViolations = 0
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $entity = $cfg.targetEntity
        $entityFields = if ($formFieldIds.ContainsKey($entity)) { $formFieldIds[$entity] } else { $null }
        if (-not $entityFields -or $entityFields.Count -eq 0) {
            Info "QIDM '$($cfg.name)': no QIF found for entity '$entity' -- skipping conditions field check"
            continue
        }

        foreach ($combo in $cfg.combinations) {
            $condArrays = @()
            if ($combo.requirements -and $combo.requirements.conditions) { $condArrays += ,$combo.requirements.conditions }
            if ($combo.conditions) { $condArrays += ,$combo.conditions }
            foreach ($conds in $condArrays) {
                foreach ($cond in $conds) {
                    foreach ($fldToken in @($cond.field)) {
                        if (-not $entityFields.Contains([string]$fldToken)) {
                            Fail "QIDM '$($cfg.name)' combo '$($combo.keyReference)' conditions[].field='$fldToken' not found in $entity QIF fieldIds (silently inert -- use the form fieldId, not the attribute name; casing matters)"
                            $condFieldViolations++
                        }
                    }
                }
            }
        }
    }
    if ($condFieldViolations -eq 0) {
        Pass "All conditions[].field values reference valid QIF fieldIds (no inert conditions)"
    }
} else {
    Info "No provider bundle -- skipping conditions field validation"
}

# ── CHECK 14: NOT_EXISTS condition field must not be in the same combo's set[]/any[] ──
# GATE-XOR-COMPANION (LIVE-FOUND TX v3.12 2026-06-23): a NOT_EXISTS condition gates a combo
# OUT when its field has a value. If that same field is also in the combo's set[], the combo
# can NEVER fire (set requires present, condition requires absent). If it is in any[], the
# any[] entry is dead config (can never serialize -- any value blocks the combo) AND it poisons
# the test conductor (Build-MinimalData injects any[] fields, tripping the NOT_EXISTS so the
# combo falsely fails to fire). The two valid treatments are mutually exclusive: GATE it
# (NOT_EXISTS + field absent from set/any) OR keep it as a COMPANION (in any[], no condition).
# See BUILD_RULES.txt IDENTIFIER-PRIORITY GUARDRAIL "GATE XOR COMPANION".
Write-Host ""
Write-Host "--- CHECK 14: NOT_EXISTS field not in own set[]/any[] (gate-xor-companion) ---" -ForegroundColor Yellow

$gateContradictions = 0
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($combo in $cfg.combinations) {
            $req = $combo.requirements
            if (-not $req) { continue }
            $setTokens = @(); if ($req.set) { $setTokens = @($req.set) }
            $anyTokens = @(); if ($req.any) { $anyTokens = @($req.any) }
            $condArrays = @()
            if ($req.conditions) { $condArrays += ,$req.conditions }
            if ($combo.conditions) { $condArrays += ,$combo.conditions }
            foreach ($conds in $condArrays) {
                foreach ($cond in $conds) {
                    if ($cond.operator -ne 'NOT_EXISTS') { continue }
                    foreach ($fldToken in @($cond.field)) {
                        $tok = [string]$fldToken
                        if ($setTokens -contains $tok) {
                            Fail "QIDM '$($cfg.name)' combo '$($combo.keyReference)': NOT_EXISTS field '$tok' is also in set[] -- combo can NEVER fire (set requires it present, condition requires it absent)"
                            $gateContradictions++
                        }
                        if ($anyTokens -contains $tok) {
                            Fail "QIDM '$($cfg.name)' combo '$($combo.keyReference)': NOT_EXISTS field '$tok' is also in any[] -- dead config (can never serialize) + poisons test conductor; remove it from any[] (gate XOR companion)"
                            $gateContradictions++
                        }
                    }
                }
            }
        }
    }
    if ($gateContradictions -eq 0) {
        Pass "No NOT_EXISTS field appears in its own combo's set[]/any[] (no gate-xor-companion contradictions)"
    }
} else {
    Info "No provider bundle -- skipping gate-xor-companion check"
}

# ── CHECK 15: Form field label hints ─────────────────────────────────────────
# BUILD_RULES.txt Section 11. Three rules enforced:
#   1. State fields (fieldId ends in 'State'): label must contain 'leave blank for'
#      (tells officers to leave blank for in-state vs fill for OOS)
#   2. DH-suffix fields (fieldId ends in 'DH'): label must contain '(DH)'
#      (disambiguates DH from DL fields when both are on the same card)
#   3. any[]-only sourceFields (never appear in set[]): label must contain '(' or ' - '
#      (at minimum an '(optional)' qualifier or a routing context hint)
Write-Host ""
Write-Host "--- CHECK 15: Form Field Label Hints ---" -ForegroundColor Yellow

# Collect fieldId -> label from all QIF layouts (first occurrence wins; all variants share same labels)
$formFieldLabels = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($entitiesBundle) {
    foreach ($cfg in $entitiesBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        if (-not $cfg.layout) { continue }
        foreach ($layoutProp in $cfg.layout.PSObject.Properties) {
            $layoutObj = $layoutProp.Value
            if (-not $layoutObj) { continue }
            foreach ($nodeProp in $layoutObj.PSObject.Properties) {
                $node = $nodeProp.Value
                if (-not ($node -is [psobject]) -or -not $node.props) { continue }
                $fid = $node.props.fieldId
                $lbl = $node.props.label
                if ($fid -and $lbl -and -not $formFieldLabels.ContainsKey($fid)) {
                    $formFieldLabels[$fid] = $lbl
                }
            }
        }
    }
}

$labelViolations = 0

# Rule 1: State fields must give OOS routing guidance. TWO valid patterns:
#   - State NOT defaulted (blank routes to the OOS keyRef): label says 'leave blank for'.
#   - State defaulted to home in combo defaults[] (the approved pattern, e.g. NJ State=NJ): the officer
#     CHANGES it for OOS, so 'leave blank for' would be WRONG guidance; label says 'change for
#     out-of-state'. (Refined 2026-06-26, RND-62365: the old rule demanded 'leave blank for' on every
#     State field and FAILed NJ's design-correct label. Accept either hint -- purely permissive, so no
#     previously-passing provider regresses.)
foreach ($fid in @($formFieldLabels.Keys | Where-Object { $_ -match '(?i)State$' })) {
    $lbl = $formFieldLabels[$fid]
    $hasStateHint = ($lbl -match 'leave blank for') -or ($lbl -match '(?i)out[- ]of[- ]state') -or ($lbl -match '(?i)change\b.*\bfor\b')
    if (-not $hasStateHint) {
        Fail "Field '$fid' label='$lbl' missing State routing hint -- need 'leave blank for' (when State is not defaulted) or 'change for out-of-state' (when State is defaulted). BUILD_RULES Section 11"
        $labelViolations++
    }
}

# Rule 2: DH-suffix fields must carry a '(DH...' qualifier in the label.
# Accept '(DH)' AND richer forms like '(DH, optional)' / '(DH) - required with Name' -- the goal is
# DH-vs-DL disambiguation, which '(DH, optional)' satisfies. Match '(DH' at a word boundary so '(DHL)'
# or a bare 'DH' (no paren) still fail. (Refined 2026-06-26, RND-62365: old '\(DH\)' rejected HI's
# design-correct '(DH, optional)' labels; purely permissive -- no previously-passing provider regresses.)
foreach ($fid in @($formFieldLabels.Keys | Where-Object { $_ -match 'DH$' })) {
    $lbl = $formFieldLabels[$fid]
    if ($lbl -notmatch '\(DH\b') {
        Fail "Field '$fid' label='$lbl' missing '(DH...' qualifier (DH disambiguation -- BUILD_RULES Section 11)"
        $labelViolations++
    }
}

# Rule 3: any[]-only sourceFields must have a hint qualifier ('(' or ' - ')
# Collect fields that appear in any[] and those that appear in set[]; pure any[] = in any[], never in set[]
$everInSet  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$everInAny  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        foreach ($combo in $cfg.combinations) {
            if ($combo.requirements.set) { foreach ($f in @($combo.requirements.set)) { [void]$everInSet.Add($f) } }
            if ($combo.requirements.any) { foreach ($f in @($combo.requirements.any)) { [void]$everInAny.Add($f) } }
        }
    }
}
$pureAnyFields = @($everInAny | Where-Object { -not $everInSet.Contains($_) })
foreach ($fid in $pureAnyFields) {
    if (-not $formFieldLabels.ContainsKey($fid)) { continue }
    $lbl = $formFieldLabels[$fid]
    if ($lbl -notmatch '\(' -and $lbl -notmatch ' - ') {
        Warn "Field '$fid' (any[]-only) label='$lbl' has no routing qualifier -- add '(optional)' or context hint (BUILD_RULES Section 11)"
        $labelViolations++
    }
}

if ($labelViolations -eq 0) {
    Pass "All form field labels have required routing hint qualifiers ($($formFieldLabels.Count) fields scanned)"
} else {
    Info "$labelViolations field(s) need label hint fixes"
}

# ── CHECK 16: Combo Reachability (shadow detection) ──────────────────────────
# Platform fires first-match combo in array order. A combo B with conditions can be
# permanently shadowed by an earlier combo A that fires on B's minimal set[] input
# without any conditions blocking it. set[] membership is NOT a firing gate — the
# platform fires a combo when its primaryFieldReference is present regardless of
# whether all set[] fields have values. This check runs each combo's minimal payload
# (only its own set[] fields) against all earlier combos and FAILs if any earlier
# combo fires. LIVE-FOUND: CA_CLETS NLTS.DQ shadowed ID.L1 because NLTS.DQ had no
# conditions; corrected by adding RegistrationState EXISTS to NLTS.DQ (v2.11).
Write-Host ""
Write-Host "--- CHECK 16: Combo Reachability (shadow detection) ---" -ForegroundColor Yellow

$shadowFails = 0
if ($providerBundle) {
    foreach ($cfg in $providerBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        $combos = @($cfg.combinations)

        # Build attribute-name → sourceField[] map for this QIDM.
        # Platform fires a combo when its primaryFieldReference (attribute name) has a
        # value — NOT when all set[] fields are present. set[] controls serialization, not
        # triggering. Conditions are the actual trigger gates.
        $attrToSrc = @{}
        foreach ($attr in $cfg.attributes) {
            if ($attr.sourceField) { $attrToSrc[$attr.name] = @($attr.sourceField) }
        }

        for ($bi = 1; $bi -lt $combos.Count; $bi++) {
            $B = $combos[$bi]
            if (-not $B.requirements.conditions -or $B.requirements.conditions.Count -eq 0) { continue }

            # Build minimal payload: only B's set[] sourceFields, each with a sentinel value
            $payload = @{}
            foreach ($f in @($B.requirements.set)) { $payload[$f] = 'TEST' }

            # Check if any earlier combo A fires on this payload.
            # A fires when: A.primaryFieldReference source field is in payload
            #               AND all A.conditions pass against the payload.
            for ($ai = 0; $ai -lt $bi; $ai++) {
                $A = $combos[$ai]

                # Resolve A.primaryFieldReference → sourceField name(s)
                $primSrc = if ($attrToSrc.ContainsKey($A.primaryFieldReference)) {
                    @($attrToSrc[$A.primaryFieldReference])
                } else {
                    @($A.primaryFieldReference)  # same name fallback
                }
                $primaryInPayload = $primSrc | Where-Object { $payload.ContainsKey($_) -and $payload[$_] }
                if (-not $primaryInPayload) { continue }

                # Check A's conditions against the payload
                $aConditionsPass = $true
                foreach ($cond in @($A.requirements.conditions)) {
                    if (-not $cond -or -not $cond.field) { continue }
                    $condField = if ($cond.field -is [array]) { $cond.field[0] } else { [string]$cond.field }
                    if ([string]::IsNullOrEmpty($condField)) { continue }
                    $fieldPresent = $payload.ContainsKey($condField) -and $payload[$condField] -ne $null -and $payload[$condField] -ne ''
                    if ($cond.operator -eq 'NOT_EXISTS' -and $fieldPresent)  { $aConditionsPass = $false; break }
                    if ($cond.operator -eq 'EXISTS'     -and -not $fieldPresent) { $aConditionsPass = $false; break }
                }
                if (-not $aConditionsPass) { continue }

                # A fires on B's minimal payload → B is shadowed
                Fail "SHADOW: '$($A.keyReference)' fires before '$($B.keyReference)' on $($cfg.name) minimal set[] payload -- add EXISTS condition to '$($A.keyReference)' or reorder so '$($B.keyReference)' comes first"
                $shadowFails++
                break
            }
        }
    }
    if ($shadowFails -eq 0) {
        Pass "Combo reachability: all conditioned combos reachable (no earlier unconditioned combo shadows them)"
    }
} else {
    Info "No provider bundle -- skipping combo reachability check"
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
