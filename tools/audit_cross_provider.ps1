<#
  audit_cross_provider.ps1 -- Cross-provider consistency audit
  Validates ALL provider JSONs against documented RULES (not against NJ
  or any specific provider). Checks default field values, version matching,
  queryLabel standards, code type pairings, field type consistency,
  camelCase enforcement, CA-specific rules, RMS autoSelect, and entity
  display order.

  9 checks, sources of truth from config files + current year.

  Usage: .\audit_cross_provider.ps1
         .\audit_cross_provider.ps1 -Path C:\path\to\providers
         .\audit_cross_provider.ps1 -OutFile report.txt
#>

param(
    [string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

if (-not $Path) { $Path = Join-Path $repoRoot 'providers' }
if (-not (Test-Path $Path)) {
    Write-Error "Providers directory not found: $Path"
    exit 1
}

# ── Output capture ────────────────────────────────────────────────────────────
$script:outputLines = @()

function Out($msg) {
    $script:outputLines += $msg
    Write-Host $msg
}

function OutColor($msg, $color) {
    $script:outputLines += $msg
    Write-Host $msg -ForegroundColor $color
}

$script:failCount = 0
$script:warnCount = 0
$script:passCount = 0
$script:infoCount = 0

function Fail($msg)  { OutColor "    [FAIL] $msg" Red;        $script:failCount++ }
function Warn($msg)  { OutColor "    [WARN] $msg" Yellow;     $script:warnCount++ }
function Pass($msg)  { OutColor "    [PASS] $msg" Green;      $script:passCount++ }
function Info($msg)  { OutColor "    [INFO] $msg" Gray;       $script:infoCount++ }

# ── Skip list ─────────────────────────────────────────────────────────────────
$skipProviders = @()  # (CA_CONTRA_COSTA was skipped while parked/incomplete; removed 2026-07-24 -- completed build, audited normally)

# ── Discover providers ────────────────────────────────────────────────────────
$providerDirs = @(Get-ChildItem $Path -Directory | Where-Object { $_.Name -notin $skipProviders })

# ── Load all provider JSONs ───────────────────────────────────────────────────
# Structure: array of { Name, Variant (BASE/MC), Json, RawText, FilePath }
$allProviders = @()

foreach ($pd in $providerDirs) {
    $provName = $pd.Name
    # Find root JSONs at the top level of the provider directory. Covers both the legacy
    # BASE/MC dual-variant naming AND the current single-JSON standard (versioned
    # <PROVIDER>_v<X.Y>.json or bare <PROVIDER>.json) so migrated providers are actually audited.
    $jsonFiles = @(Get-ChildItem $pd.FullName -File -Filter '*.json' |
        Where-Object {
            $_.Name -match '_BASE\.json$|_MC\.json$' -or
            $_.Name -match "^$([regex]::Escape($provName))_v[\d.]+\.json$" -or
            $_.Name -eq "$provName.json"
        })

    foreach ($jf in $jsonFiles) {
        $variant = if ($jf.Name -match '_MC\.json$') { 'MC' }
                   elseif ($jf.Name -match '_BASE\.json$') { 'BASE' }
                   else { 'SINGLE' }
        try {
            $rawText = [System.IO.File]::ReadAllText($jf.FullName)
            $parsed = $rawText | ConvertFrom-Json
            $allProviders += [PSCustomObject]@{
                Name     = $provName
                Variant  = $variant
                Json     = $parsed
                RawText  = $rawText
                FilePath = $jf.FullName
                Tag      = "${provName} (${variant})"
            }
        } catch {
            # Will be reported below
            $allProviders += [PSCustomObject]@{
                Name     = $provName
                Variant  = $variant
                Json     = $null
                RawText  = $null
                FilePath = $jf.FullName
                Tag      = "${provName} (${variant})"
                Error    = $_.Exception.Message
            }
        }
    }
}

# ── Helper: Get all form fields from ENTITIES bundle QIFs ─────────────────────
# Returns array of { Entity, FieldId, ResolvedName, Props }
function Get-FormFields {
    param([object]$json)
    $fields = @()
    if (-not $json -or -not $json.bundles) { return $fields }

    $entitiesBundle = $json.bundles | Where-Object { $_.provider -eq 'MARK43' -or $_.name -eq 'ENTITIES' } | Select-Object -First 1
    if (-not $entitiesBundle -or -not $entitiesBundle.configurations) { return $fields }

    foreach ($cfg in $entitiesBundle.configurations) {
        if ($cfg.type -ne 'QUERYINPUTFORM') { continue }
        $entity = $cfg.targetEntity
        if (-not $entity) { continue }

        # Scan default layout variant
        $layoutObj = $null
        try { $layoutObj = $cfg.layout.default } catch { }
        if (-not $layoutObj) {
            try { $layoutObj = $cfg.layout.PSObject.Properties['default'].Value } catch { continue }
        }
        if (-not $layoutObj) { continue }

        foreach ($prop in $layoutObj.PSObject.Properties) {
            $node = $prop.Value
            if (-not $node) { continue }
            $resolvedName = $null
            try { $resolvedName = $node.type.resolvedName } catch { continue }
            if ($resolvedName -notin @('FormInput','FormSelect','FormDate','FormCheckbox')) { continue }

            $p = $null
            try { $p = $node.props } catch { continue }
            if (-not $p) { continue }

            $fieldId = $null
            try { $fieldId = $p.fieldId } catch { }
            if (-not $fieldId) { continue }

            $hidden = $false
            try { $hidden = $node.hidden } catch { }

            $fields += [PSCustomObject]@{
                Entity       = $entity
                FieldId      = $fieldId
                ResolvedName = $resolvedName
                Props        = $p
                Hidden       = $hidden
            }
        }
    }
    return $fields
}

# ── Helper: Get QIDM configs from a specific bundle type ──────────────────────
function Get-QidmConfigs {
    param([object]$json, [string]$bundleProvider)
    $qidms = @()
    if (-not $json -or -not $json.bundles) { return $qidms }
    foreach ($bundle in $json.bundles) {
        if ($bundleProvider -and $bundle.provider -ne $bundleProvider) { continue }
        if (-not $bundle.configurations) { continue }
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') { $qidms += $cfg }
        }
    }
    return $qidms
}

# ── Helper: Get all QIDM configs (CommSys = not MARK43, not RMS) ──────────────
function Get-CommSysQidms {
    param([object]$json)
    $qidms = @()
    if (-not $json -or -not $json.bundles) { return $qidms }
    foreach ($bundle in $json.bundles) {
        if ($bundle.provider -eq 'MARK43' -or $bundle.provider -eq 'RMS') { continue }
        if (-not $bundle.configurations) { continue }
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -eq 'QUERYINPUTDATAMAPPING') { $qidms += $cfg }
        }
    }
    return $qidms
}

# ── Helper: Get routing-gate fieldIds (fields used in CommSys combo conditions) ──
# A field referenced by any combo condition (EXISTS/NOT_EXISTS/…) is a routing gate: giving it
# an initialValue would change which combo fires, so it is intentionally left un-defaulted
# (the State / LIMITATION #30 rule, applied to plate fields for OOS-gated providers like HI).
function Get-RoutingGateFields {
    param([object]$json)
    $gate = @()
    foreach ($q in (Get-CommSysQidms -json $json)) {
        if (-not $q.combinations) { continue }
        foreach ($c in $q.combinations) {
            # A set[] field IS a routing gate -- the STRONGEST one. The platform fires the first
            # combo whose whole set[] is present, so a required field's presence/absence is what
            # selects between siblings. This function previously counted only explicit conditions,
            # which is why the "PlateType must default to PC" rule kept FAILing providers that
            # correctly leave it blank: defaulting a set[] field makes the combo requiring it match
            # on every submission and permanently hides its siblings FROM THE FORM (35 such
            # combinations across 6 providers, found 2026-07-30; see enforce PHASE 2n /
            # tools\audit_query_trace.ps1, and BUILD_RULES 23 -- the form comes first).
            $sets = $null
            try { $sets = $c.requirements.set } catch { }
            if ($sets) { $gate += @($sets | Where-Object { $_ }) }

            $conds = $null
            try { $conds = $c.requirements.conditions } catch { }
            if (-not $conds) { continue }
            foreach ($cond in $conds) {
                $f = $null
                try { $f = $cond.field } catch { }
                if ($f) { $gate += @($f) }
            }
        }
    }
    return @($gate | Select-Object -Unique)
}

# ── Helper: Get ENTITIES bundle ───────────────────────────────────────────────
function Get-EntitiesBundle {
    param([object]$json)
    if (-not $json -or -not $json.bundles) { return $null }
    return $json.bundles | Where-Object { $_.provider -eq 'MARK43' -or $_.name -eq 'ENTITIES' } | Select-Object -First 1
}

# ── Header ────────────────────────────────────────────────────────────────────
Out ""
OutColor "========================================" Cyan
OutColor " CROSS-PROVIDER AUDIT" Cyan
OutColor " $(Get-Date -Format 'yyyy-MM-dd HH:mm')" Cyan
OutColor " Providers directory: $Path" Cyan
OutColor "========================================" Cyan

$parseFailures = @($allProviders | Where-Object { $null -eq $_.Json })
if ($parseFailures.Count -gt 0) {
    Out ""
    OutColor "--- PARSE FAILURES ---" Red
    foreach ($pf in $parseFailures) {
        Fail "$($pf.Tag): JSON parse failed -- $($pf.Error)"
    }
}

$validProviders = @($allProviders | Where-Object { $null -ne $_.Json })
Out ""
Out "  Loaded: $($validProviders.Count) provider JSONs from $($providerDirs.Count) providers (skipped: $($skipProviders -join ', '))"

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 1: Default Field Values
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 1: Default Field Values ---" Yellow

$currentYear = (Get-Date).Year.ToString()

foreach ($prov in $validProviders) {
    Out "  $($prov.Tag):"
    $fields = Get-FormFields -json $prov.Json
    $gateFields = Get-RoutingGateFields -json $prov.Json

    if ($fields.Count -eq 0) {
        Info "No form fields found (possible parse issue)"
        continue
    }

    # Vehicle LicensePlateTypeCode: initialValue must be 'PC' -- UNLESS it is a combo routing gate
    # (OOS-gated providers like HI leave it blank by design; defaulting it would misroute).
    $vehPlateType = @($fields | Where-Object { $_.Entity -eq 'Vehicle' -and $_.FieldId -match '^[Ll]icensePlateTypeCode$' })
    if ($vehPlateType.Count -gt 0) {
        $iv = $null
        try { $iv = $vehPlateType[0].Props.initialValue } catch { }
        if ($iv -eq 'PC') {
            Pass "Vehicle LicensePlateTypeCode initialValue='PC'"
        } elseif ($vehPlateType[0].FieldId -in $gateFields) {
            Info "Vehicle LicensePlateTypeCode has no default -- combo routing gate (OOS-gated by design, LIMITATION #30 analogue)"
        } else {
            Fail "Vehicle LicensePlateTypeCode initialValue='$iv' (expected 'PC')"
        }
    } else {
        # Check if Vehicle entity exists at all
        $vehFields = @($fields | Where-Object { $_.Entity -eq 'Vehicle' })
        if ($vehFields.Count -gt 0) {
            Fail "Vehicle LicensePlateTypeCode field not found"
        } else {
            Info "No Vehicle entity fields found"
        }
    }

    # Vehicle LicensePlateYear: initialValue must be current year -- UNLESS it is a combo routing
    # gate (OOS-gated providers leave it blank by design, same as LicensePlateTypeCode above).
    $vehPlateYear = @($fields | Where-Object { $_.Entity -eq 'Vehicle' -and $_.FieldId -match '^[Ll]icensePlateYear$' })
    if ($vehPlateYear.Count -gt 0) {
        $iv = $null
        try { $iv = $vehPlateYear[0].Props.initialValue } catch { }
        if ($iv -eq $currentYear) {
            Pass "Vehicle LicensePlateYear initialValue='$currentYear'"
        } elseif (($vehPlateYear[0].FieldId -in $gateFields) -or ('LicensePlateTypeCode' -in $gateFields)) {
            # Year is the OOS-only companion of LicensePlateTypeCode; when the type code gates OOS
            # routing, the year field is intentionally left blank alongside it.
            Info "Vehicle LicensePlateYear has no default -- OOS-only companion of the plate-type routing gate"
        } else {
            Warn "Vehicle LicensePlateYear initialValue='$iv' (expected '$currentYear')"
        }
    } else {
        $vehFields = @($fields | Where-Object { $_.Entity -eq 'Vehicle' })
        if ($vehFields.Count -gt 0) {
            Warn "Vehicle LicensePlateYear field not found"
        }
    }

    # Person ImageIndicator: initialValue must be 'Y'. The prefill is REQUIRED, not optional --
    # ImageIndicator does not serialize at all without one (FIELD_REFERENCE.txt Section 9), so the
    # original expectation stands. What is ALSO worth flagging (BUILD_RULES 20b, added 2026-08-04) is
    # the consequence: because it always exists, a combo gated ImageIndicator NOT_EXISTS is
    # permanently dead. LA_LEMS DriverLicenseQuery is the portfolio's only instance (DP gated EXISTS,
    # DQ gated NOT_EXISTS). Sitting in a set[] is NOT itself a problem -- AZ_AZDPS v3.5's DQP/DQPN
    # require Set[BadgeNumber, ImageIndicator, ..., Requestor] for the driver-licence photo and
    # discriminate on Requestor, which has no default.
    # $prov.Json, NOT $json -- the per-provider parse lives on the loop object. Written as $json
    # first, which is UNDEFINED at this scope, so the loop never ran and the flag stayed $false with
    # no error to show why. Silent-wrong, not broken.
    $personImg = @($fields | Where-Object { $_.Entity -eq 'Person' -and $_.FieldId -match '^[Ii]mageIndicator$' })
    if ($personImg.Count -gt 0) {
        $iv = $null
        try { $iv = $personImg[0].Props.initialValue } catch { }
        $imgNotExistsGate = $false
        foreach ($b in $prov.Json.bundles) {
            foreach ($c in $b.configurations) {
                if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
                foreach ($cm in @($c.combinations)) {
                    foreach ($cd in @($cm.requirements.conditions)) {
                        if ("$($cd.operator)" -ne 'NOT_EXISTS') { continue }
                        foreach ($f in @($cd.field)) {
                            if ("$f" -match '^[Ii]mageIndicator') { $imgNotExistsGate = $true }
                        }
                    }
                }
            }
        }
        if ($iv -and $imgNotExistsGate) {
            Warn "Person ImageIndicator initialValue='$iv' AND a combo gates on ImageIndicator NOT_EXISTS -- that branch is permanently DEAD (BUILD_RULES 20b)"
        } elseif ($iv -eq 'Y') {
            Pass "Person ImageIndicator initialValue='Y'"
        } else {
            Warn "Person ImageIndicator initialValue='$iv' (expected 'Y')"
        }
    } else {
        $personFields = @($fields | Where-Object { $_.Entity -eq 'Person' })
        if ($personFields.Count -gt 0) {
            Info "Person ImageIndicator not present (provider-specific)"
        }
    }

    # Vehicle ImageIndicator: initialValue must be 'N'
    $vehImg = @($fields | Where-Object { $_.Entity -eq 'Vehicle' -and $_.FieldId -match '^[Ii]mageIndicator$' })
    if ($vehImg.Count -gt 0) {
        $iv = $null
        try { $iv = $vehImg[0].Props.initialValue } catch { }
        if ($iv -eq 'N') {
            Pass "Vehicle ImageIndicator initialValue='N'"
        } else {
            Warn "Vehicle ImageIndicator initialValue='$iv' (expected 'N')"
        }
    } else {
        $vehFields = @($fields | Where-Object { $_.Entity -eq 'Vehicle' })
        if ($vehFields.Count -gt 0) {
            Info "Vehicle ImageIndicator not present (provider-specific)"
        }
    }

    # Other entities ImageIndicator: INFO only
    $otherEntities = @($fields | Where-Object { $_.FieldId -match '^[Ii]mageIndicator$' -and $_.Entity -ne 'Person' -and $_.Entity -ne 'Vehicle' })
    foreach ($oe in $otherEntities) {
        $iv = $null
        try { $iv = $oe.Props.initialValue } catch { }
        if ($iv -eq 'Y' -or $iv -eq 'N') {
            Info "$($oe.Entity) ImageIndicator initialValue='$iv'"
        } else {
            Info "$($oe.Entity) ImageIndicator initialValue='$iv' (expected 'Y' or 'N')"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 2: BASE+MC Version Matching
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 2: BASE+MC Version Matching ---" Yellow

$providerNames = @($validProviders | ForEach-Object { $_.Name } | Select-Object -Unique)

foreach ($provName in $providerNames) {
    $baseEntry = $validProviders | Where-Object { $_.Name -eq $provName -and $_.Variant -eq 'BASE' } | Select-Object -First 1
    $mcEntry = $validProviders | Where-Object { $_.Name -eq $provName -and $_.Variant -eq 'MC' } | Select-Object -First 1

    if (-not $baseEntry -or -not $mcEntry) {
        # Only one variant -- nothing to compare
        if ($baseEntry -and -not $mcEntry) {
            Info "${provName}: BASE only (no MC to compare)"
        } elseif ($mcEntry -and -not $baseEntry) {
            Info "${provName}: MC only (no BASE to compare)"
        }
        continue
    }

    # Extract version from bundle descriptions
    # Look in the provider bundle (not ENTITIES, not RMS)
    function Extract-Version {
        param([object]$json)
        if (-not $json) { return $null }
        # Prefer the top-level JSON `version` field (authoritative); fall back to bundle description.
        if ($json.version) { return $json.version }
        if (-not $json.bundles) { return $null }
        foreach ($bundle in $json.bundles) {
            if ($bundle.provider -eq 'MARK43' -or $bundle.provider -eq 'RMS') { continue }
            if ($bundle.description -match 'v(\d+\.\d+)') {
                return $Matches[1]
            }
        }
        return $null
    }

    $baseVer = Extract-Version -json $baseEntry.Json
    $mcVer = Extract-Version -json $mcEntry.Json

    if (-not $baseVer -and -not $mcVer) {
        Info "${provName}: No version found in either BASE or MC bundle description"
    } elseif (-not $baseVer) {
        Warn "${provName}: MC version='$mcVer' but BASE has no version in bundle description"
    } elseif (-not $mcVer) {
        Warn "${provName}: BASE version='$baseVer' but MC has no version in bundle description"
    } elseif ($baseVer -eq $mcVer) {
        Pass "${provName}: BASE v${baseVer} = MC v${mcVer}"
    } else {
        Warn "${provName}: BASE v${baseVer} != MC v${mcVer}"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 3: queryLabel Standards
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 3: queryLabel Standards ---" Yellow

$labelConfigPath = Join-Path $PSScriptRoot 'config\standard_query_labels.json'
$standardLabels = $null
if (Test-Path $labelConfigPath) {
    try {
        $labelConfig = Get-Content $labelConfigPath -Raw | ConvertFrom-Json
        $standardLabels = @{}
        foreach ($prop in $labelConfig.queryLabels.PSObject.Properties) {
            $standardLabels[$prop.Name] = $prop.Value
        }
        $rmsLabel = $labelConfig.rmsLabel
        Info "Loaded $($standardLabels.Count) standard queryLabel mappings + RMS='$rmsLabel'"
    } catch {
        Fail "Failed to parse standard_query_labels.json: $_"
    }
} else {
    Fail "Config not found: $labelConfigPath"
}

if ($standardLabels) {
    foreach ($prov in $validProviders) {
        $qidms = Get-CommSysQidms -json $prov.Json
        $rmsQidms = Get-QidmConfigs -json $prov.Json -bundleProvider 'RMS'
        $allQidms = $qidms + $rmsQidms
        $labelIssues = @()

        foreach ($q in $allQidms) {
            $qName = if ($q.name) { $q.name } else { $q.query }
            $queryType = $q.query

            if (-not $q.queryLabel) {
                $labelIssues += "[WARN] QIDM '$qName' missing queryLabel"
                $script:warnCount++
                continue
            }

            if ($q.provider -eq 'RMS') {
                # RMS QIDMs should have label 'RMS'
                if ($q.queryLabel -ne $rmsLabel) {
                    $labelIssues += "[FAIL] RMS QIDM '$qName' queryLabel='$($q.queryLabel)' (expected '$rmsLabel')"
                    $script:failCount++
                }
            } elseif ($queryType -and $standardLabels.ContainsKey($queryType)) {
                $expected = $standardLabels[$queryType]
                if ($q.queryLabel -ne $expected) {
                    $labelIssues += "[FAIL] QIDM '$qName' queryLabel='$($q.queryLabel)' (expected '$expected' for $queryType)"
                    $script:failCount++
                }
            } else {
                # Unknown query type -- not in the standard list
                $labelIssues += "[INFO] QIDM '$qName' query='$queryType' not in standard_query_labels.json"
                $script:infoCount++
            }
        }

        if ($labelIssues.Count -gt 0) {
            Out "  $($prov.Tag):"
            foreach ($li in $labelIssues) {
                if ($li -match '^\[FAIL\]') { OutColor "    $li" Red }
                elseif ($li -match '^\[WARN\]') { OutColor "    $li" Yellow }
                else { OutColor "    $li" Gray }
            }
        } else {
            Out "  $($prov.Tag):"
            Pass "All $($allQidms.Count) QIDM queryLabels match standards"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 4: Code Type Pairings
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 4: Code Type Pairings ---" Yellow

$pairingsConfigPath = Join-Path $PSScriptRoot 'config\code_type_pairings.json'
$pairingsConfig = $null
if (Test-Path $pairingsConfigPath) {
    try {
        $pairingsConfig = Get-Content $pairingsConfigPath -Raw | ConvertFrom-Json
        $universalPairings = @{}
        foreach ($p in $pairingsConfig.pairings) {
            if ($p.providerSpecific -eq $true) { continue }
            $universalPairings[$p.category] = $p.source
        }
        Info "Loaded $($universalPairings.Count) universal code type pairings"
    } catch {
        Fail "Failed to parse code_type_pairings.json: $_"
    }
} else {
    Fail "Config not found: $pairingsConfigPath"
}

if ($pairingsConfig) {
    foreach ($prov in $validProviders) {
        $fields = Get-FormFields -json $prov.Json
        $selectFields = @($fields | Where-Object { $_.ResolvedName -eq 'FormSelect' })
        $issues = @()

        foreach ($sf in $selectFields) {
            $cat = $null; $src = $null
            try { $cat = $sf.Props.codeTypeCategory } catch { }
            try { $src = $sf.Props.codeTypeSource } catch { }

            if (-not $cat) { continue }  # No code type category -- skip

            if ($universalPairings.ContainsKey($cat)) {
                $expectedSrc = $universalPairings[$cat]
                if (-not $src) {
                    $issues += "[FAIL] $($sf.Entity)/$($sf.FieldId): category='$cat' but no codeTypeSource (expected '$expectedSrc')"
                    $script:failCount++
                } elseif ($src -ne $expectedSrc) {
                    $issues += "[FAIL] $($sf.Entity)/$($sf.FieldId): category='$cat' source='$src' (expected '$expectedSrc')"
                    $script:failCount++
                }
            } else {
                # Not in universal list -- provider-specific
                if (-not $src) {
                    $issues += "[WARN] $($sf.Entity)/$($sf.FieldId): category='$cat' not in universal list, no source set"
                    $script:warnCount++
                } else {
                    $issues += "[INFO] $($sf.Entity)/$($sf.FieldId): category='$cat' source='$src' (provider-specific)"
                    $script:infoCount++
                }
            }
        }

        Out "  $($prov.Tag):"
        if ($issues.Count -gt 0) {
            foreach ($iss in $issues) {
                if ($iss -match '^\[FAIL\]') { OutColor "    $iss" Red }
                elseif ($iss -match '^\[WARN\]') { OutColor "    $iss" Yellow }
                else { OutColor "    $iss" Gray }
            }
        } else {
            $catCount = @($selectFields | Where-Object {
                $c = $null; try { $c = $_.Props.codeTypeCategory } catch { }; $c
            }).Count
            if ($catCount -gt 0) {
                Pass "All $catCount FormSelect code type pairings are valid"
            } else {
                Info "No FormSelect fields with codeTypeCategory found"
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 5: Field Type Consistency Across Providers
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 5: Field Type Consistency ---" Yellow

$divergencePath = Join-Path $PSScriptRoot "config\accepted_field_divergences.json"
$acceptedDivergences = @()
if (Test-Path $divergencePath) {
    $divConfig = Get-Content $divergencePath -Raw | ConvertFrom-Json
    $acceptedDivergences = @($divConfig.fields | ForEach-Object { $_.fieldId })
}

# Build map: fieldId -> { type -> providerList }
$fieldTypeMap = @{}

foreach ($prov in $validProviders) {
    # Use BASE + SINGLE (single-JSON) providers; skip only MC to avoid double-counting the
    # BASE+MC pair with identical fields. Single-JSON providers have no twin, so they are included.
    if ($prov.Variant -eq 'MC') { continue }

    $fields = Get-FormFields -json $prov.Json
    foreach ($f in $fields) {
        $fid = $f.FieldId
        $ftype = $f.ResolvedName

        if (-not $fieldTypeMap.ContainsKey($fid)) {
            $fieldTypeMap[$fid] = @{}
        }
        if (-not $fieldTypeMap[$fid].ContainsKey($ftype)) {
            $fieldTypeMap[$fid][$ftype] = @()
        }
        if ($prov.Name -notin $fieldTypeMap[$fid][$ftype]) {
            $fieldTypeMap[$fid][$ftype] += $prov.Name
        }
    }
}

$consistentCount = 0
$inconsistentCount = 0

foreach ($fid in ($fieldTypeMap.Keys | Sort-Object)) {
    $typeMap = $fieldTypeMap[$fid]
    $types = @($typeMap.Keys)

    # Only check fields used by 2+ providers
    $totalProviders = 0
    foreach ($t in $types) { $totalProviders += $typeMap[$t].Count }
    if ($totalProviders -lt 2) { continue }

    if ($types.Count -eq 1) {
        Pass "${fid}: $($types[0]) across all $totalProviders providers"
        $consistentCount++
    } else {
        $parts = @()
        foreach ($t in ($types | Sort-Object)) {
            $provList = ($typeMap[$t] | Sort-Object) -join ','
            $parts += "$t in $provList"
        }
        if ($fid -in $acceptedDivergences) {
            Info "${fid}: $($parts -join ' but ') (accepted divergence)"
        } else {
            Fail "${fid}: $($parts -join ' but ')"
        }
        $inconsistentCount++
    }
}

Out ""
Info "Field type consistency: $consistentCount consistent / $inconsistentCount inconsistent (fields shared by 2+ providers)"

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 6: Field-ID casing (methodology-aware)
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 6: Field-ID Casing ---" Yellow

$platformFields = @('CAD_UNIT_SELECT_VALUE','CAD_EVENT_SELECT_VALUE','LINK_CURRENT_ASSIGNED_EVENT')

# The 22 USx CAD-integration tokens authored in PascalCase (CLAUDE.md Field Configuration Rules).
# Their presence marks a provider as built under the PascalCase methodology.
$usxPascalTokens = @(
    'LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RandomRequest','RegistrationState',
    'ImageIndicator','VehicleIdentificationNumber','NCICNumber','VehicleMakeCode','NameFirst','NameLast',
    'BirthDate','SexCode','OperatorLicenseNumber','GunSerialNumber','GunMake','GunCaliber','GunModel',
    'ArticleSerialNumber','ArticleTypeCode','RegistrationNumber','BoatHullIdNumber')

foreach ($prov in $validProviders) {
    # BASE + SINGLE only; MC duplicates BASE fields.
    if ($prov.Variant -eq 'MC') { continue }

    $fields = Get-FormFields -json $prov.Json
    $allFieldIds = @($fields | ForEach-Object { $_.FieldId } | Select-Object -Unique)
    $checkableFieldIds = @($allFieldIds | Where-Object { $_ -notin $platformFields })

    # Detect casing methodology: a provider that authors any of the 22 USx tokens in PascalCase
    # is a PascalCase provider. Its per-field casing correctness is enforced by verify_build /
    # audit_cad (which are casing-aware); here we only flag underscores (never valid off-platform).
    $isPascalProvider = @($checkableFieldIds | Where-Object { $_ -cin $usxPascalTokens }).Count -gt 0

    Out "  $($prov.Name):"
    if ($isPascalProvider) {
        $violations = @($checkableFieldIds | Where-Object { $_ -match '_' })
        if ($violations.Count -gt 0) {
            Warn "PascalCase provider: fieldIds with underscores ($($violations.Count)): $($violations -join ', ')"
        } else {
            Pass "PascalCase provider: all $($checkableFieldIds.Count) fieldIds underscore-free (casing verified per-provider by verify_build/audit_cad)"
        }
    } else {
        # Legacy camelCase provider: first char lowercase, no underscores.
        $violations = @($checkableFieldIds | Where-Object {
            ($_ -cmatch '^[A-Z]') -or ($_ -match '_')
        })
        if ($violations.Count -gt 0) {
            Warn "Non-camelCase fieldIds ($($violations.Count)): $($violations -join ', ')"
        } else {
            if ($checkableFieldIds.Count -gt 0) {
                Pass "All $($checkableFieldIds.Count) fieldIds are camelCase"
            } else {
                Info "No checkable fieldIds found"
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 7: CA-Specific Rules
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 7: CA-Specific Rules ---" Yellow

foreach ($prov in $validProviders) {
    $isCA = $prov.Name -match '^CA_'
    $fields = Get-FormFields -json $prov.Json

    # CA-specific fieldId patterns (explicit CaRequestPurposeCode names)
    $caExplicitFields = @($fields | Where-Object {
        $_.FieldId -eq 'CaRequestPurposeCode' -or $_.FieldId -eq 'caRequestPurposeCode' -or
        $_.FieldId -eq 'CaRequestPurposeCodeDH' -or $_.FieldId -eq 'caRequestPurposeCodeDH'
    })
    # CA providers may also use generic 'purposeCode'/'purposeCodeDH' as the CAD-aligned rename
    $caAllFields = if ($isCA) {
        @($fields | Where-Object {
            $_.FieldId -eq 'CaRequestPurposeCode' -or $_.FieldId -eq 'caRequestPurposeCode' -or
            $_.FieldId -eq 'CaRequestPurposeCodeDH' -or $_.FieldId -eq 'caRequestPurposeCodeDH' -or
            $_.FieldId -eq 'purposeCode' -or $_.FieldId -eq 'purposeCodeDH'
        })
    } else { $caExplicitFields }

    Out "  $($prov.Tag):"

    if ($isCA) {
        # CA providers: CaRequestPurposeCode (or DH-suffix or purposeCode rename) should exist in Person QIF
        $personPurpose = @($caAllFields | Where-Object { $_.Entity -eq 'Person' })
        if ($personPurpose.Count -eq 0) {
            $personFields = @($fields | Where-Object { $_.Entity -eq 'Person' })
            if ($personFields.Count -gt 0) {
                Warn "CaRequestPurposeCode not found in Person QIF"
            } else {
                Info "No Person entity fields found"
            }
        } else {
            $pf = $personPurpose[0]
            if ($pf.Hidden -eq $true) {
                Warn "CaRequestPurposeCode is hidden (must be visible for officers)"
            } elseif ($pf.ResolvedName -ne 'FormInput') {
                Info "CaRequestPurposeCode type='$($pf.ResolvedName)' (FormInput preferred)"
            } else {
                $fieldName = $pf.FieldId
                Pass "CaRequestPurposeCode present and visible in Person QIF ($fieldName, type=$($pf.ResolvedName))"
            }
        }
    } else {
        # Non-CA: explicit CaRequestPurposeCode names should NOT exist (generic purposeCode is fine)
        if ($caExplicitFields.Count -gt 0) {
            $entities = ($caExplicitFields | ForEach-Object { $_.Entity }) -join ', '
            Warn "CaRequestPurposeCode found on non-CA provider in: $entities"
        } else {
            Pass "No CaRequestPurposeCode (correct for non-CA provider)"
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 8: RMS autoSelect
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 8: RMS autoSelect ---" Yellow

foreach ($prov in $validProviders) {
    $rmsQidms = Get-QidmConfigs -json $prov.Json -bundleProvider 'RMS'

    Out "  $($prov.Tag):"
    if ($rmsQidms.Count -eq 0) {
        Info "No RMS QIDMs found"
        continue
    }

    $missingAutoSelect = @($rmsQidms | Where-Object { $_.autoSelect -ne $true })
    if ($missingAutoSelect.Count -gt 0) {
        $names = ($missingAutoSelect | ForEach-Object { if ($_.name) { $_.name } else { $_.query } }) -join ', '
        Fail "RMS QIDMs missing autoSelect=true: $names"
    } else {
        Pass "All $($rmsQidms.Count) RMS QIDMs have autoSelect=true"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# CHECK 9: Entity Display Order
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "--- CHECK 9: Entity Display Order ---" Yellow

$requiredOrderKeys = @('default', 'CAD_DISPATCH', 'FIRST_RESPONDER')
$vehicleFirstKeys = @('CAD_DISPATCH', 'FIRST_RESPONDER')

foreach ($prov in $validProviders) {
    $entitiesBundle = Get-EntitiesBundle -json $prov.Json

    Out "  $($prov.Tag):"

    if (-not $entitiesBundle) {
        Fail "No ENTITIES bundle found"
        continue
    }

    $order = $null
    try { $order = $entitiesBundle.order } catch { }

    if (-not $order) {
        Fail "ENTITIES bundle missing 'order' object"
        continue
    }

    $orderIssues = @()

    # Check all 3 required keys exist
    foreach ($key in $requiredOrderKeys) {
        $arr = $null
        try { $arr = $order.$key } catch { }
        if (-not $arr) {
            try { $arr = $order.PSObject.Properties[$key].Value } catch { }
        }

        if (-not $arr) {
            $orderIssues += "[FAIL] order.$key missing"
            $script:failCount++
            continue
        }

        # Must be an array
        if ($arr -isnot [System.Array] -and $arr -isnot [System.Collections.IList]) {
            $orderIssues += "[FAIL] order.$key is not an array"
            $script:failCount++
            continue
        }

        # Values must be strings (targetEntity names)
        $nonStrings = @($arr | Where-Object { $_ -isnot [string] })
        if ($nonStrings.Count -gt 0) {
            $orderIssues += "[FAIL] order.$key contains non-string values"
            $script:failCount++
        }

        # CAD_DISPATCH and FIRST_RESPONDER must have Vehicle first
        if ($key -in $vehicleFirstKeys) {
            if ($arr.Count -gt 0 -and $arr[0] -ne 'Vehicle') {
                $orderIssues += "[FAIL] order.$key first element='$($arr[0])' (must be 'Vehicle')"
                $script:failCount++
            }
        }
    }

    if ($orderIssues.Count -gt 0) {
        foreach ($oi in $orderIssues) {
            if ($oi -match '^\[FAIL\]') { OutColor "    $oi" Red }
            else { OutColor "    $oi" Yellow }
        }
    } else {
        Pass "Entity display order correct (3 keys, Vehicle first in CAD_DISPATCH + FIRST_RESPONDER)"
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
Out ""
OutColor "========================================" Cyan
OutColor " CROSS-PROVIDER AUDIT SUMMARY" Cyan
OutColor "========================================" Cyan
Out "  Providers: $($providerDirs.Count) (skipped: $($skipProviders -join ', '))"
Out "  JSONs loaded: $($validProviders.Count)"

$totalChecks = $script:passCount + $script:failCount + $script:warnCount
Out "  Total: $($script:passCount) PASS / $($script:failCount) FAIL / $($script:warnCount) WARN / $($script:infoCount) INFO"

if ($script:failCount -gt 0) {
    OutColor "  RESULT: AUDIT FAILED" Red
} elseif ($script:warnCount -gt 0) {
    OutColor "  RESULT: AUDIT PASSED with warnings" Yellow
} else {
    OutColor "  RESULT: AUDIT PASSED" Green
}
OutColor "========================================" Cyan
Out ""

# ── Write to file ─────────────────────────────────────────────────────────────
if ($OutFile) {
    # Strip ANSI / color codes (output lines are plain text already)
    $script:outputLines | Out-File -FilePath $OutFile -Encoding UTF8
    Write-Host "Report written to: $OutFile" -ForegroundColor Gray
}

if ($script:failCount -gt 0) { exit 1 }
