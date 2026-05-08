<#
  audit_cad.ps1 -- CAD dispatch field alignment auditor
  Validates that all provider JSONs use the correct camelCase fieldIds
  so CAD auto-populate works universally.

  Checks:
    1. CAD Field Name Alignment (QIF fieldIds vs universal CAD field list)
    2. CAD_DISPATCH Layout Variant Exists (with CONTEXT_INFO_CARD)
    3. FIRST_RESPONDER Layout Variant Exists
    4. Patch 8 Completeness (RMS sourceFields are camelCase in BASE)
    5. QIDM sourceField Case Alignment (sourceField matches QIF fieldId exactly)

  Usage:
    .\audit_cad.ps1                                  # scan all providers
    .\audit_cad.ps1 -Path providers\NJ_NJCJIS_LOCKED\NJ_NJCJIS_BASE.json
    .\audit_cad.ps1 -Variant MC                      # scan all MC JSONs
    .\audit_cad.ps1 -OutFile docs\cad_audit.txt      # write to file
#>

param(
    [string]$Path,
    [string]$OutFile,
    [ValidateSet('BASE','MC')][string]$Variant = 'BASE'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent

# ── Load config files ────────────────────────────────────────────────────────

$configDir    = Join-Path $PSScriptRoot 'config'
$cadFieldPath = Join-Path $configDir 'cad_field_mapping.json'
$patch8Path   = Join-Path $configDir 'patch8_rename_map.json'

if (-not (Test-Path $cadFieldPath)) { Write-Error "CAD field mapping not found: $cadFieldPath"; return }
if (-not (Test-Path $patch8Path))   { Write-Error "Patch 8 rename map not found: $patch8Path"; return }

$cadConfig = Get-Content $cadFieldPath -Raw -Encoding UTF8 | ConvertFrom-Json
$patch8Config = Get-Content $patch8Path -Raw -Encoding UTF8 | ConvertFrom-Json
$renameMap = [System.Collections.Generic.Dictionary[string,string]]::new()
foreach ($prop in $patch8Config.renameMap.PSObject.Properties) {
    $renameMap[$prop.Name] = $prop.Value
}

# Build entity CAD field lists
$entities = @('Vehicle','Person','Firearm','Article','Boat')
$cadFieldsByEntity = @{}
foreach ($ent in $entities) {
    $cadFieldsByEntity[$ent] = @()
    if ($cadConfig.$ent) {
        $cadFieldsByEntity[$ent] = @($cadConfig.$ent)
    }
}

# For MC variant, build PascalCase expectations from the rename map (reversed)
# MC uses PascalCase fieldIds, so CAD expectations become PascalCase
$camelToPascal = [System.Collections.Generic.Dictionary[string,string]]::new()
foreach ($k in $renameMap.Keys) {
    $camelToPascal[$renameMap[$k]] = $k
}

# ── Discover provider JSONs ──────────────────────────────────────────────────

$jsonFiles = @()
if ($Path) {
    if (-not (Test-Path $Path)) { Write-Error "File not found: $Path"; return }
    $jsonFiles += Get-Item $Path
} else {
    $providersDir = Join-Path $repoRoot 'providers'
    if (-not (Test-Path $providersDir)) { Write-Error "Providers dir not found: $providersDir"; return }
    $suffix = if ($Variant -eq 'MC') { '*_MC.json' } else { '*_BASE.json' }
    $jsonFiles = @(Get-ChildItem -Path $providersDir -Filter $suffix -Recurse |
        Where-Object { $_.DirectoryName -notmatch '(archive|phases|release|v1[\\\/])' -and $_.DirectoryName -notmatch 'CA_CONTRA_COSTA' } |
        Sort-Object Name)
}

if ($jsonFiles.Count -eq 0) { Write-Error "No provider JSONs found"; return }

# ── Output capture ───────────────────────────────────────────────────────────

$outputLines = [System.Collections.Generic.List[string]]::new()

function Out($msg) {
    $script:outputLines.Add($msg)
    Write-Host $msg
}
function Out-Pass($msg)  { $script:outputLines.Add("    [PASS] $msg"); Write-Host "    [PASS] $msg" -ForegroundColor Green; $script:totalPass++ }
function Out-Fail($msg)  { $script:outputLines.Add("    [FAIL] $msg"); Write-Host "    [FAIL] $msg" -ForegroundColor Red; $script:totalFail++ }
function Out-Warn($msg)  { $script:outputLines.Add("    [WARN] $msg"); Write-Host "    [WARN] $msg" -ForegroundColor Yellow; $script:totalWarn++ }
function Out-Info($msg)  { $script:outputLines.Add("    [INFO] $msg"); Write-Host "    [INFO] $msg" -ForegroundColor Gray; $script:totalInfo++ }

$script:totalPass = 0
$script:totalFail = 0
$script:totalWarn = 0
$script:totalInfo = 0
$providerCount = 0

# ── Helper: Extract fieldIds from a QIF layout ──────────────────────────────

function Get-LayoutFieldIds($layoutObj) {
    $fieldIds = [System.Collections.Generic.HashSet[string]]::new()
    if (-not $layoutObj) { return $fieldIds }
    foreach ($prop in $layoutObj.PSObject.Properties) {
        $node = $prop.Value
        if (-not $node.type) { continue }
        $resolved = $null
        try { $resolved = $node.type.resolvedName } catch {}
        if (-not $resolved) { continue }
        if ($resolved -in @('FormInput','FormSelect','FormDate','FormDateInput','FormCheckbox',
                            'CheckboxInput','TextInput','SelectInput','SelectHistoryInput','HiddenInput')) {
            $fid = $null
            try { $fid = $node.props.fieldId } catch {}
            if ($fid) { [void]$fieldIds.Add($fid) }
        }
    }
    return $fieldIds
}

# ── Helper: Check if layout variant has CONTEXT_INFO_CARD ───────────────────

function Test-ContextCard($layoutObj) {
    if (-not $layoutObj) { return @{ exists = $false; hasUnit = $false; hasEvent = $false } }
    $hasContextCard = $false
    $hasUnit = $false
    $hasEvent = $false
    foreach ($prop in $layoutObj.PSObject.Properties) {
        $node = $prop.Value
        if (-not $node.type) { continue }
        $resolved = $null
        try { $resolved = $node.type.resolvedName } catch {}
        if ($resolved -eq 'Card' -and $prop.Name -eq 'CONTEXT_INFO_CARD') {
            $hasContextCard = $true
        }
        $fid = $null
        try { $fid = $node.props.fieldId } catch {}
        if (-not $fid) {
            try { $fid = $node.props.attributeTypeId } catch {}
        }
        if ($fid -eq 'CAD_UNIT_SELECT_VALUE') { $hasUnit = $true }
        if ($fid -eq 'CAD_EVENT_SELECT_VALUE') { $hasEvent = $true }
    }
    return @{ exists = $hasContextCard; hasUnit = $hasUnit; hasEvent = $hasEvent }
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP: Process each provider
# ══════════════════════════════════════════════════════════════════════════════

foreach ($jf in $jsonFiles) {
    $provName = $jf.BaseName -replace '_(BASE|MC)$',''
    $providerCount++

    Out ''
    Out '========================================'
    Out " CAD AUDIT: $provName ($Variant)"
    Out '========================================'

    $data = Get-Content $jf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    # Parse bundles
    $entitiesBundle = $null
    $providerBundle = $null
    $rmsBundle = $null
    foreach ($b in $data.bundles) {
        if ($b.provider -eq 'MARK43') { $entitiesBundle = $b }
        elseif ($b.provider -eq 'RMS' -or $b.name -eq 'RMS') { $rmsBundle = $b }
        else { $providerBundle = $b }
    }

    if (-not $entitiesBundle) {
        Out-Fail "No ENTITIES bundle found -- skipping"
        continue
    }

    # Collect QIF data per entity: fieldIds from all layout variants, plus per-variant layout refs
    $qifByEntity = @{}   # entity -> { allFieldIds = HashSet, defaultFields = HashSet, cadLayout = obj, frLayout = obj }
    foreach ($cfg in $entitiesBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        $entity = $cfg.targetEntity
        if (-not $entity) { continue }

        if (-not $qifByEntity.ContainsKey($entity)) {
            $qifByEntity[$entity] = @{
                allFieldIds   = [System.Collections.Generic.HashSet[string]]::new()
                defaultFields = [System.Collections.Generic.HashSet[string]]::new()
                cadLayout     = $null
                frLayout      = $null
                qifName       = $cfg.name
            }
        }

        # Default layout fieldIds
        $defLayout = $null
        try { $defLayout = $cfg.layout.default } catch {}
        if ($defLayout) {
            $defFields = Get-LayoutFieldIds $defLayout
            foreach ($f in $defFields) {
                [void]$qifByEntity[$entity].allFieldIds.Add($f)
                [void]$qifByEntity[$entity].defaultFields.Add($f)
            }
        }

        # Compact layout fieldIds
        $compactLayout = $null
        try { $compactLayout = $cfg.layout.compact } catch {}
        if ($compactLayout) {
            $cFields = Get-LayoutFieldIds $compactLayout
            foreach ($f in $cFields) { [void]$qifByEntity[$entity].allFieldIds.Add($f) }
        }

        # Detail layout fieldIds
        $detailLayout = $null
        try { $detailLayout = $cfg.layout.detail } catch {}
        if ($detailLayout) {
            $dFields = Get-LayoutFieldIds $detailLayout
            foreach ($f in $dFields) { [void]$qifByEntity[$entity].allFieldIds.Add($f) }
        }

        # CAD_DISPATCH layout
        $cadLayout = $null
        try { $cadLayout = $cfg.layout.CAD_DISPATCH } catch {}
        if ($cadLayout) {
            $cadFields2 = Get-LayoutFieldIds $cadLayout
            foreach ($f in $cadFields2) { [void]$qifByEntity[$entity].allFieldIds.Add($f) }
            $qifByEntity[$entity].cadLayout = $cadLayout
        }

        # FIRST_RESPONDER layout
        $frLayout = $null
        try { $frLayout = $cfg.layout.FIRST_RESPONDER } catch {}
        if ($frLayout) {
            $frFields = Get-LayoutFieldIds $frLayout
            foreach ($f in $frFields) { [void]$qifByEntity[$entity].allFieldIds.Add($f) }
            $qifByEntity[$entity].frLayout = $frLayout
        }
    }

    # ── CHECK 1: CAD Field Name Alignment ────────────────────────────────────
    Out ''
    Out '--- CHECK 1: CAD Field Alignment ---'

    foreach ($ent in $entities) {
        $cadList = $cadFieldsByEntity[$ent]
        if ($cadList.Count -eq 0) { continue }

        $qifData = $qifByEntity[$ent]
        if (-not $qifData) {
            Out-Info "$ent -- no QIF found in this provider (expected if entity not supported)"
            continue
        }

        Out "  ${ent}:"
        $qifFieldSet = $qifData.allFieldIds

        foreach ($cadField in $cadList) {
            if ($Variant -eq 'MC') {
                # MC uses PascalCase. Check if the PascalCase version exists.
                $pascalField = $null
                if ($camelToPascal.ContainsKey($cadField)) {
                    $pascalField = $camelToPascal[$cadField]
                }
                if ($qifFieldSet.Contains($cadField)) {
                    # camelCase found in MC -- that's fine (some fields weren't renamed)
                    Out-Pass "${cadField}: in QIF and CAD list"
                } elseif ($pascalField -and $qifFieldSet.Contains($pascalField)) {
                    Out-Pass "${cadField}: in QIF as '$pascalField' (MC PascalCase)"
                } else {
                    # Check for wrong case
                    $wrongCase = $null
                    foreach ($f in $qifFieldSet) {
                        if ($f -ieq $cadField -and $f -cne $cadField) { $wrongCase = $f; break }
                    }
                    if ($wrongCase) {
                        Out-Fail "${wrongCase}: wrong case (expected '$cadField' or '$pascalField')"
                    } else {
                        Out-Info "${cadField}: in CAD list, not in QIF (CAD sends it but form doesn't have it)"
                    }
                }
            } else {
                # BASE uses camelCase
                if ($qifFieldSet.Contains($cadField)) {
                    Out-Pass "${cadField}: in QIF and CAD list"
                } else {
                    # Check for wrong case (PascalCase when should be camelCase)
                    $wrongCase = $null
                    foreach ($f in $qifFieldSet) {
                        if ($f -ieq $cadField -and $f -cne $cadField) { $wrongCase = $f; break }
                    }
                    if ($wrongCase) {
                        Out-Fail "${wrongCase}: wrong case (expected '$cadField')"
                    } else {
                        Out-Info "${cadField}: in CAD list, not in QIF (CAD sends it but form doesn't have it)"
                    }
                }
            }
        }

        # Fields in QIF but not in CAD list (provider-specific)
        $cadListLower = @($cadList | ForEach-Object { $_.ToLower() })
        $platformFields = @('CAD_UNIT_SELECT_VALUE','CAD_EVENT_SELECT_VALUE','LINK_CURRENT_ASSIGNED_EVENT')
        foreach ($qifField in $qifFieldSet) {
            if ($qifField -in $platformFields) { continue }
            $qifLower = $qifField.ToLower()
            $inCadList = $false
            foreach ($cf in $cadList) {
                if ($cf -ieq $qifField) { $inCadList = $true; break }
            }
            if (-not $inCadList) {
                Out-Info "${qifField}: in QIF, not in CAD list (provider-specific)"
            }
        }
    }

    # ── CHECK 2: CAD_DISPATCH Layout Variant ─────────────────────────────────
    Out ''
    Out '--- CHECK 2: CAD_DISPATCH Layout Variant ---'

    foreach ($ent in $entities) {
        $qifData = $qifByEntity[$ent]
        if (-not $qifData) { continue }

        if (-not $qifData.cadLayout) {
            Out-Fail "$ent QIF '$($qifData.qifName)': missing CAD_DISPATCH layout variant"
        } else {
            Out-Pass "$ent QIF '$($qifData.qifName)': CAD_DISPATCH layout exists"
            $ctxResult = Test-ContextCard $qifData.cadLayout
            if (-not $ctxResult.exists) {
                Out-Warn "$ent CAD_DISPATCH: missing CONTEXT_INFO_CARD"
            } elseif (-not $ctxResult.hasUnit -or -not $ctxResult.hasEvent) {
                $missing = @()
                if (-not $ctxResult.hasUnit) { $missing += 'CAD_UNIT_SELECT_VALUE' }
                if (-not $ctxResult.hasEvent) { $missing += 'CAD_EVENT_SELECT_VALUE' }
                Out-Warn "$ent CAD_DISPATCH: CONTEXT_INFO_CARD incomplete (missing $($missing -join ', '))"
            } else {
                Out-Pass "$ent CAD_DISPATCH: CONTEXT_INFO_CARD with unit + event"
            }
        }
    }

    # ── CHECK 3: FIRST_RESPONDER Layout Variant ──────────────────────────────
    Out ''
    Out '--- CHECK 3: FIRST_RESPONDER Layout Variant ---'

    foreach ($ent in $entities) {
        $qifData = $qifByEntity[$ent]
        if (-not $qifData) { continue }

        if (-not $qifData.frLayout) {
            Out-Warn "$ent QIF '$($qifData.qifName)': missing FIRST_RESPONDER layout variant"
        } else {
            Out-Pass "$ent QIF '$($qifData.qifName)': FIRST_RESPONDER layout exists"
        }
    }

    # ── CHECK 4: Patch 8 Completeness (BASE only) ───────────────────────────
    Out ''
    Out '--- CHECK 4: Patch 8 Completeness ---'

    if ($Variant -eq 'MC') {
        Out-Info "Skipped for MC variant (MC uses PascalCase, Patch 8 not applied)"
    } elseif (-not $rmsBundle) {
        Out-Warn "No RMS bundle found -- cannot check Patch 8"
    } else {
        foreach ($cfg in $rmsBundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            $qidmName = $cfg.name
            $badAttrs = @()
            $attrCount = 0

            # Check attribute sourceFields
            if ($cfg.attributes) {
                foreach ($attr in $cfg.attributes) {
                    if (-not $attr.sourceField) { continue }
                    foreach ($sf in $attr.sourceField) {
                        $attrCount++
                        if ($renameMap.ContainsKey($sf)) {
                            $badAttrs += "$sf (expected '$($renameMap[$sf])')"
                        }
                    }
                }
            }

            # Check combination set[]/any[] values
            $badCombos = @()
            if ($cfg.combinations) {
                foreach ($combo in $cfg.combinations) {
                    $allRefs = @()
                    if ($combo.requirements.set) { $allRefs += $combo.requirements.set }
                    if ($combo.requirements.any) { $allRefs += $combo.requirements.any }
                    foreach ($ref in $allRefs) {
                        if ($renameMap.ContainsKey($ref)) {
                            $badCombos += "$ref (expected '$($renameMap[$ref])')"
                        }
                    }
                }
            }

            if ($badAttrs.Count -eq 0 -and $badCombos.Count -eq 0) {
                Out-Pass "RMS $qidmName -- all sourceFields and combo refs are camelCase"
            } else {
                if ($badAttrs.Count -gt 0) {
                    foreach ($ba in $badAttrs) {
                        Out-Fail "RMS $qidmName attr sourceField: $ba"
                    }
                }
                if ($badCombos.Count -gt 0) {
                    foreach ($bc in $badCombos) {
                        Out-Fail "RMS $qidmName combo ref: $bc"
                    }
                }
            }
        }
    }

    # ── CHECK 5: QIDM sourceField Case Alignment ────────────────────────────
    Out ''
    Out '--- CHECK 5: QIDM sourceField Case Alignment ---'

    if ($providerBundle) {
        foreach ($cfg in $providerBundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            $entity = $cfg.targetEntity
            $qidmName = $cfg.name
            $qifData = $qifByEntity[$entity]

            if (-not $qifData) {
                Out-Info "QIDM '$qidmName' targets entity '$entity' -- no QIF found"
                continue
            }

            $qifFieldSet = $qifData.allFieldIds
            $badSources = @()

            if ($cfg.attributes) {
                foreach ($attr in $cfg.attributes) {
                    # Skip Attention handler (auto-populated, no form field)
                    if ($attr.rule -and $attr.rule.function -match 'LastNameFirstNameInitial') { continue }
                    if (-not $attr.sourceField) { continue }
                    foreach ($sf in $attr.sourceField) {
                        if ($qifFieldSet.Contains($sf)) {
                            # Exact match -- good
                        } else {
                            # Check if case-insensitive match exists
                            $caseMatch = $null
                            foreach ($f in $qifFieldSet) {
                                if ($f -ieq $sf -and $f -cne $sf) { $caseMatch = $f; break }
                            }
                            if ($caseMatch) {
                                $badSources += "attr '$($attr.name)' sourceField='$sf' (QIF has '$caseMatch')"
                            }
                            # If no match at all, that's a different check (verify_build CHECK 2)
                            # We only flag case mismatches here
                        }
                    }
                }
            }

            if ($badSources.Count -eq 0) {
                Out-Pass "QIDM '$qidmName': all sourceFields match QIF fieldIds (case-sensitive)"
            } else {
                foreach ($bs in $badSources) {
                    Out-Fail "QIDM '$qidmName': $bs"
                }
            }
        }
    } else {
        Out-Warn "No provider bundle found -- cannot check QIDM sourceField alignment"
    }

    # Also check RMS QIDM sourceFields against QIF fieldIds
    if ($rmsBundle) {
        foreach ($cfg in $rmsBundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            $entity = $cfg.targetEntity
            $qidmName = $cfg.name
            $qifData = $qifByEntity[$entity]

            if (-not $qifData) { continue }
            $qifFieldSet = $qifData.allFieldIds
            $badSources = @()

            if ($cfg.attributes) {
                foreach ($attr in $cfg.attributes) {
                    if (-not $attr.sourceField) { continue }
                    foreach ($sf in $attr.sourceField) {
                        if ($qifFieldSet.Contains($sf)) {
                            # Exact match
                        } else {
                            $caseMatch = $null
                            foreach ($f in $qifFieldSet) {
                                if ($f -ieq $sf -and $f -cne $sf) { $caseMatch = $f; break }
                            }
                            if ($caseMatch) {
                                $badSources += "attr '$($attr.name)' sourceField='$sf' (QIF has '$caseMatch')"
                            }
                        }
                    }
                }
            }

            if ($badSources.Count -eq 0) {
                Out-Pass "RMS QIDM '$qidmName': all sourceFields match QIF fieldIds (case-sensitive)"
            } else {
                foreach ($bs in $badSources) {
                    Out-Fail "RMS QIDM '$qidmName': $bs"
                }
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════

Out ''
Out '========================================'
Out ' CAD AUDIT SUMMARY'
Out '========================================'
Out "Providers: $providerCount"
Out "Total: $($script:totalPass) PASS / $($script:totalFail) FAIL / $($script:totalWarn) WARN / $($script:totalInfo) INFO"
Out ''

if ($OutFile) {
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    $outputLines -join "`r`n" | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "Report written to: $OutFile" -ForegroundColor Cyan
}

if ($script:totalFail -gt 0) { exit 1 }
