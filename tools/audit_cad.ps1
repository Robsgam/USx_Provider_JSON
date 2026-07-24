<#
  audit_cad.ps1 -- CAD dispatch field alignment auditor
  Validates that all provider JSONs expose the correct CAD-integration fieldIds
  (PascalCase USx tokens, camelCase accepted where not yet renamed) so CAD
  auto-populate works universally.

  Checks:
    1. CAD Field Name Alignment (QIF fieldIds vs universal CAD field list)
    2. CAD_DISPATCH Layout Variant Exists (with CONTEXT_INFO_CARD)
    3. FIRST_RESPONDER Layout Variant Exists
    4. QIDM sourceField Case Alignment (sourceField matches QIF fieldId exactly)
    5. CAD Defaults Coverage (any[] fields with form initialValue need combo defaults[])

  Note: the legacy -Variant <BASE|MC> switch and the Patch 8 camelCase check were retired
  2026-07-24 -- the portfolio is single-JSON and PascalCase-galvanized, so the BASE branch
  and the camelCase-rename Patch 8 check were permanently dead.

  Usage:
    .\audit_cad.ps1                                  # scan all providers
    .\audit_cad.ps1 -Path providers\NJ_NJCJIS\NJ_NJCJIS_v4.10.json
    .\audit_cad.ps1 -OutFile docs\cad_audit.txt      # write to file
#>

param(
    [string]$Path,
    [string]$OutFile
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

# Build PascalCase expectations from the Patch 8 rename map (reversed): the galvanized
# fieldIds are PascalCase, so each camelCase CAD token maps to its PascalCase form.
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
    $provDirs = Get-ChildItem -Path $providersDir -Directory |
        Where-Object { $_.Name -ne 'CA_CONTRA_COSTA' }
    $jsonFiles = @()
    foreach ($pd in $provDirs) {
        $candidates = Get-ChildItem -Path $pd.FullName -Filter '*.json' -File |
            Where-Object { $_.Name -notmatch '(archive|phases|release)' }
        # Single-JSON portfolio: pick the one versioned root JSON (legacy _BASE/_MC excluded).
        $f = $candidates | Where-Object { $_.Name -notmatch '_(BASE|MC)\.json$' } | Select-Object -First 1
        if ($f) { $jsonFiles += $f }
    }
    $jsonFiles = @($jsonFiles | Sort-Object Name)
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

# ── Helper: Extract fieldId -> initialValue map from a QIF layout ───────────

function Get-LayoutInitialValues($layoutObj) {
    $map = @{}
    if (-not $layoutObj) { return $map }
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
            if (-not $fid) { continue }
            $iv = $null
            try { $iv = $node.props.initialValue } catch {}
            if ($iv) { $map[$fid] = $iv }
        }
    }
    return $map
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
    Out " CAD AUDIT: $provName"
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
                initialValues = @{}
                cadLayout     = $null
                frLayout      = $null
                qifName       = $cfg.name
            }
        }

        # Default layout fieldIds + initialValues
        $defLayout = $null
        try { $defLayout = $cfg.layout.default } catch {}
        if ($defLayout) {
            $defFields = Get-LayoutFieldIds $defLayout
            foreach ($f in $defFields) {
                [void]$qifByEntity[$entity].allFieldIds.Add($f)
                [void]$qifByEntity[$entity].defaultFields.Add($f)
            }
            $ivMap = Get-LayoutInitialValues $defLayout
            foreach ($k in $ivMap.Keys) {
                $qifByEntity[$entity].initialValues[$k] = $ivMap[$k]
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
            # Galvanized providers use PascalCase USx fieldIds; some non-renamed fields are
            # still camelCase. Accept EITHER: the camelCase CAD token as-is, OR any valid
            # PascalCase candidate. Candidates: the patch8-inverse form (where available) AND
            # the plain first-letter-uppercase form (with ncicNumber special-cased). Both are
            # needed because the patch8 reverse map can yield a stale form for fields renamed
            # in Patch 8 -- e.g. licensePlateNumber reverses to the BANNED 'LicensePlateNumberIn',
            # while the correct recased form is 'LicensePlateNumber'.
            $pascalCands = [System.Collections.Generic.List[string]]::new()
            if ($camelToPascal.ContainsKey($cadField)) { $pascalCands.Add($camelToPascal[$cadField]) }
            if ($cadField -eq 'ncicNumber') { $pascalCands.Add('NCICNumber') }
            if ($cadField) { $pascalCands.Add($cadField.Substring(0,1).ToUpper() + $cadField.Substring(1)) }
            $hitPascal = $pascalCands | Where-Object { $qifFieldSet.Contains($_) } | Select-Object -First 1
            if ($qifFieldSet.Contains($cadField)) {
                # camelCase form found -- fine (field not yet renamed to PascalCase)
                Out-Pass "${cadField}: in QIF and CAD list"
            } elseif ($hitPascal) {
                Out-Pass "${cadField}: in QIF as '$hitPascal' (PascalCase USx fieldIds)"
            } else {
                # Check for wrong case
                $wrongCase = $null
                foreach ($f in $qifFieldSet) {
                    if ($f -ieq $cadField -and $f -cne $cadField) { $wrongCase = $f; break }
                }
                if ($wrongCase) {
                    Out-Fail "${wrongCase}: wrong case (expected '$cadField' or one of: $($pascalCands -join ', '))"
                } else {
                    Out-Info "${cadField}: in CAD list, not in QIF (CAD sends it but form doesn't have it)"
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

    # ── CHECK 4: QIDM sourceField Case Alignment ────────────────────────────
    Out ''
    Out '--- CHECK 4: QIDM sourceField Case Alignment ---'

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

    # ── CHECK 5: CAD Defaults Coverage ─────────────────────────────────────────
    # For each CommSys QIDM combo, any[] fields with a form initialValue must
    # have a combination-level defaults[] entry. CAD dispatch does NOT apply
    # form initialValues — without defaults[], those fields are absent from XML.
    # Exceptions:
    #   - Fields guaranteed by conditions (user must have set them for combo to fire)
    #   - codeTypeProvider fields (e.g., State) need defaults too — CommSys priority
    Out ''
    Out '--- CHECK 5: CAD Defaults Coverage ---'

    if ($providerBundle) {
        foreach ($cfg in $providerBundle.configurations) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            $entity = $cfg.targetEntity
            $qidmName = $cfg.name
            $qifData = $qifByEntity[$entity]

            if (-not $qifData) { continue }
            $ivMap = $qifData.initialValues

            # Build sourceField -> attribute name map, and track codeTypeProvider attrs
            $sfToAttrName = @{}
            $codeTypeProviderAttrs = [System.Collections.Generic.HashSet[string]]::new()
            if ($cfg.attributes) {
                foreach ($attr in $cfg.attributes) {
                    if (-not $attr.sourceField) { continue }
                    foreach ($sf in $attr.sourceField) {
                        $sfToAttrName[$sf] = $attr.name
                    }
                    if ($attr.codeTypeProvider) {
                        [void]$codeTypeProviderAttrs.Add($attr.name)
                    }
                }
            }

            $comboIdx = 0
            foreach ($combo in $cfg.combinations) {
                $comboIdx++
                $keyRef = $combo.keyReference
                # CAD ignores QIF initialValue for BOTH set[] and any[] fields, so a field in
                # EITHER list that carries an initialValue needs a matching combo defaults[] entry.
                # (Earlier this scanned any[] only and silently missed set[] fields like HI
                #  vehicleTypeCode=1 on M55L/M55S -- a real CAD gap.)
                $comboFields = @()
                if ($combo.requirements.any) { $comboFields += @($combo.requirements.any) }
                if ($combo.requirements.set) { $comboFields += @($combo.requirements.set) }
                $comboFields = $comboFields | Select-Object -Unique

                # Collect fields guaranteed by conditions (user must set them, or NOT_EXISTS gates
                # them out) -- normalized lowercase so casing never causes a miss.
                $conditionFields = [System.Collections.Generic.HashSet[string]]::new()
                if ($combo.requirements.conditions) {
                    foreach ($cond in $combo.requirements.conditions) {
                        $condField = $null
                        if ($cond.field -is [array]) { $condField = $cond.field[0] }
                        else { $condField = $cond.field }
                        if ($condField) { [void]$conditionFields.Add(([string]$condField).ToLower()) }
                    }
                }

                # Collect existing defaults for this combo. defaults[].field may be authored in
                # attribute-name (PascalCase) OR sourceField (camelCase) casing depending on the
                # build script, so normalize to lowercase -- matching by attrName OR sourceField.
                $existingDefaults = [System.Collections.Generic.HashSet[string]]::new()
                if ($combo.requirements.defaults) {
                    foreach ($d in $combo.requirements.defaults) {
                        [void]$existingDefaults.Add(([string]$d.field).ToLower())
                    }
                }

                $missing = @()
                $codeTypeMissing = @()
                foreach ($cField in $comboFields) {
                    if (-not $ivMap.ContainsKey($cField)) { continue }
                    $attrName = $sfToAttrName[$cField]
                    if (-not $attrName) { continue }
                    if ($existingDefaults.Contains($attrName.ToLower())) { continue }
                    if ($existingDefaults.Contains(([string]$cField).ToLower())) { continue }
                    if ($conditionFields.Contains($attrName.ToLower())) { continue }
                    if ($conditionFields.Contains(([string]$cField).ToLower())) { continue }
                    $missing += "$attrName (form default='$($ivMap[$cField])')"
                }

                if ($missing.Count -eq 0 -and $codeTypeMissing.Count -eq 0) {
                    Out-Pass "QIDM '$qidmName' combo $keyRef -- defaults cover all initialValue any[] fields"
                } else {
                    foreach ($m in $missing) {
                        Out-Fail "QIDM '$qidmName' combo $keyRef -- missing default for $m"
                    }
                    foreach ($m in $codeTypeMissing) {
                        Out-Info "QIDM '$qidmName' combo $keyRef -- $m"
                    }
                }
            }
        }
    } else {
        Out-Warn "No provider bundle found -- cannot check CAD defaults coverage"
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
