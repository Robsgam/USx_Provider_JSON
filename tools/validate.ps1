# ConnectCIC Provider JSON Validator
# Pre-tests provider JSON before platform import
# Validates: structure, layout, QIDM references, combinations, autoSelect conflicts, encoding
#
# Usage: .\validate.ps1 -Path <json-file> [-Verbose]

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [switch]$ShowDetail
)

$ErrorActionPreference = "Stop"

function Write-Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Write-Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warnCount++ }
function Write-Limitation($msg) { Write-Host "  [LIMITATION] $msg" -ForegroundColor DarkYellow; $script:limitCount++ }
function Write-Info($msg) { if ($ShowDetail) { Write-Host "  [INFO] $msg" -ForegroundColor Gray } }

$script:failCount = 0
$script:warnCount = 0
$script:limitCount = 0
$script:passCount = 0

function Inc-Pass { $script:passCount++ }

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 0: FILE-LEVEL CHECKS
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 0: File & Encoding ===" -ForegroundColor Cyan

if (-not (Test-Path $Path)) {
    Write-Fail "File not found: $Path"
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($Path)
$fileSize = $bytes.Length
Write-Info "File size: $fileSize bytes"

# BOM check
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Fail "UTF-8 BOM detected (bytes EF BB BF). Strip before import."
} else {
    Write-Pass "No BOM"; Inc-Pass
}

# Null bytes (UTF-16 indicator)
$nullBytes = 0
foreach ($b in $bytes) { if ($b -eq 0) { $nullBytes++ } }
if ($nullBytes -gt 0) {
    Write-Fail "Found $nullBytes null bytes -- possible UTF-16 encoding. Re-encode as UTF-8."
} else {
    Write-Pass "Clean UTF-8 encoding"; Inc-Pass
}

# JSON parse
try {
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $json = $raw | ConvertFrom-Json
    Write-Pass "JSON parses successfully"; Inc-Pass
} catch {
    Write-Fail "JSON parse error: $_"
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 1: TOP-LEVEL STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 1: Bundle Structure ===" -ForegroundColor Cyan

if (-not $json.bundles) {
    Write-Fail "Missing top-level 'bundles' array"
    exit 1
}
Write-Pass "bundles array present ($($json.bundles.Count) bundles)"; Inc-Pass
# A top-level 'version' field is REJECTED by the platform: it deserializes as java.lang.Integer,
# so a dotted string like "4.10" throws at import. Version lives ONLY in the filename + the bundle
# description (enforce CHECK 3i). validate was blind to this known import-killer (mutation-test M4).
if ($json.PSObject.Properties.Name -contains 'version') {
    Write-Fail "Top-level 'version' field present ('$($json.version)') -- platform rejects it (parses as Integer; a dotted string fails import). Remove it; version belongs in the filename + bundle description."
}

$entitiesBundle = $null
$providerBundles = @()
$rmsBundle = $null

foreach ($b in $json.bundles) {
    if (-not $b.name) { Write-Fail "Bundle missing 'name' property"; continue }
    if (-not $b.type) { Write-Fail "Bundle '$($b.name)' missing 'type' property"; continue }
    if ($b.type -ne 'BUNDLE') { Write-Fail "Bundle '$($b.name)' type='$($b.type)' -- must be 'BUNDLE' (confirmed import failure)" }
    if (-not $b.provider) { Write-Warn "Bundle '$($b.name)' missing 'provider' property"; Write-Host "    [FIX] Add 'provider' property to bundle '$($b.name)' -- ENTITIES uses 'MARK43', provider bundle uses provider name, RMS uses 'RMS'" -ForegroundColor Cyan }

    if ($b.name -eq "ENTITIES") { $entitiesBundle = $b }
    elseif ($b.name -eq "RMS") { $rmsBundle = $b }
    else { $providerBundles += $b }

    if (-not $b.configurations -or $b.configurations.Count -eq 0) {
        Write-Fail "Bundle '$($b.name)' has no configurations"
    } else {
        Write-Pass "Bundle '$($b.name)': $($b.configurations.Count) configurations"; Inc-Pass
    }
}

if (-not $entitiesBundle) { Write-Fail "No ENTITIES bundle found" }
if ($providerBundles.Count -eq 0) { Write-Fail "No provider bundle found" }
if (-not $rmsBundle) { Write-Warn "No RMS bundle (optional but expected)"; Write-Host "    [FIX] Add a third bundle named 'RMS' with provider='RMS' -- use Build-RmsBundle from tools/_build_rms_bundle.ps1" -ForegroundColor Cyan }

# Bundle count (exactly 3: ENTITIES + Provider + RMS)
if ($json.bundles.Count -lt 3) {
    Write-Warn "Only $($json.bundles.Count) bundles -- expected 3 (ENTITIES + Provider + RMS)"
    Write-Host "    [FIX] Add the missing bundle(s) -- every provider JSON requires exactly 3: ENTITIES (QIFs), Provider (AUTH+QMF+QRDM+QIDMs), RMS (from _build_rms_bundle.ps1)" -ForegroundColor Cyan
} elseif ($json.bundles.Count -gt 3) {
    Write-Warn "$($json.bundles.Count) bundles -- expected exactly 3 (ENTITIES + Provider + RMS)"
    Write-Host "    [FIX] Remove extra bundles -- merge provider configs into a single provider bundle or remove duplicates" -ForegroundColor Cyan
}

# RmsRestPayloadHandler QIDMs must be in RMS bundle, not provider bundle
foreach ($b in $providerBundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -eq "QUERYINPUTDATAMAPPING" -and $c.handlerFunction -eq 'RmsRestPayloadHandler') {
            Write-Fail "QIDM '$($c.name)' with handlerFunction='RmsRestPayloadHandler' in provider bundle '$($b.name)' -- must be in RMS bundle"
        }
    }
}

# AP #9: QIF in provider or RMS bundle (causes duplicate entity form cards)
foreach ($b in $providerBundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -eq "QUERYINPUTFORM") {
            Write-Fail "QIF '$($c.name)' in provider bundle '$($b.name)' -- QIFs belong ONLY in ENTITIES bundle (AP #9)"
        }
    }
}
if ($rmsBundle) {
    foreach ($c in $rmsBundle.configurations) {
        if ($c.type -eq "QUERYINPUTFORM") {
            Write-Fail "QIF '$($c.name)' in RMS bundle -- QIFs belong ONLY in ENTITIES bundle (AP #9)"
        }
    }
}

# Check bundle order
if ($json.bundles[0].name -ne "ENTITIES") {
    Write-Fail "ENTITIES bundle is not first -- confirmed AZ v2.0: forms render incorrectly when ENTITIES is not first"
} else {
    Write-Pass "ENTITIES bundle is first"; Inc-Pass
}

# Check ENTITIES bundle has provider='MARK43' (AP: forms won't render without it)
if ($entitiesBundle) {
    if ($entitiesBundle.provider -eq 'MARK43') {
        Write-Pass "ENTITIES bundle provider='MARK43'"; Inc-Pass
    } else {
        $qifProviders = @($entitiesBundle.configurations | Where-Object { $_.provider -eq 'MARK43' })
        if ($qifProviders.Count -gt 0) {
            Write-Pass "ENTITIES QIFs have provider='MARK43' individually"; Inc-Pass
        } else {
            Write-Fail "ENTITIES bundle missing provider='MARK43' -- forms will not render after import (confirmed AZ v2.0)"
        }
    }

    # Check ENTITIES order is nested object, not flat array
    if ($entitiesBundle.order) {
        if ($entitiesBundle.order -is [System.Array]) {
            Write-Fail "ENTITIES order is a flat array -- must be nested object {default:[...], CAD_DISPATCH:[...], FIRST_RESPONDER:[...]} (confirmed AZ v2.2)"
        } elseif ($entitiesBundle.order.default) {
            Write-Pass "ENTITIES order is nested object with 'default' key"; Inc-Pass
            if (-not $entitiesBundle.order.CAD_DISPATCH) {
                Write-Warn "ENTITIES order missing 'CAD_DISPATCH' key -- CAD dispatch view will use default order"
                Write-Host "    [FIX] Add 'CAD_DISPATCH' key to ENTITIES order object with entity array (typically Vehicle first: ['Vehicle','Person','Firearm','Article','Boat'])" -ForegroundColor Cyan
            } else {
                foreach ($cadEnt in $entitiesBundle.order.CAD_DISPATCH) {
                    if ($entitiesBundle.order.default -notcontains $cadEnt) {
                        Write-Warn "ENTITIES order CAD_DISPATCH lists '$cadEnt' not in default order array"
                        Write-Host "    [FIX] Either add '$cadEnt' to the 'default' order array, or remove it from 'CAD_DISPATCH'" -ForegroundColor Cyan
                    }
                }
            }
            if (-not $entitiesBundle.order.FIRST_RESPONDER) {
                Write-Warn "ENTITIES order missing 'FIRST_RESPONDER' key -- first responder view will use default order"
                Write-Host "    [FIX] Add 'FIRST_RESPONDER' key to ENTITIES order object with entity array (typically same as CAD_DISPATCH)" -ForegroundColor Cyan
            } else {
                foreach ($frEnt in $entitiesBundle.order.FIRST_RESPONDER) {
                    if ($entitiesBundle.order.default -notcontains $frEnt) {
                        Write-Warn "ENTITIES order FIRST_RESPONDER lists '$frEnt' not in default order array"
                        Write-Host "    [FIX] Either add '$frEnt' to the 'default' order array, or remove it from 'FIRST_RESPONDER'" -ForegroundColor Cyan
                    }
                }
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 2: ENTITY ORDER & QIF VALIDATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 2: Entity QIFs ===" -ForegroundColor Cyan

$qifs = @()
$allFieldIds = @{}  # entity -> Set of fieldIds
$allFieldProps = @{}  # entity -> fieldId -> {attributeTypeId, codeTypeProvider, codeTypeCategory}

if ($entitiesBundle) {
    # Check order array
    if ($entitiesBundle.order) {
        $orderDefault = $entitiesBundle.order.default
        if ($orderDefault) {
            Write-Pass "Entity order defined: $($orderDefault -join ', ')"; Inc-Pass
        }
    } else {
        Write-Warn "No entity order array defined"
        Write-Host "    [FIX] Add 'order' object to ENTITIES bundle: {default:[...], CAD_DISPATCH:[...], FIRST_RESPONDER:[...]} using targetEntity values" -ForegroundColor Cyan
    }

    foreach ($cfg in $entitiesBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTFORM") {
            if ($cfg.type -eq "QUERYINPUTDATAMAPPING") {
                Write-Fail "ENTITIES bundle contains QIDM '$($cfg.name)' -- QIDMs belong in provider bundle, not ENTITIES (will be invisible to validation)"
            } elseif ($cfg.type -eq "AUTHENTICATION" -or $cfg.type -eq "QUERYMESSAGEFORMAT" -or $cfg.type -eq "QUERYRESULTDATAMAPPING") {
                Write-Fail "ENTITIES bundle contains $($cfg.type) '$($cfg.name)' -- belongs in provider or RMS bundle"
            } else {
                Write-Warn "ENTITIES bundle contains non-QIF: $($cfg.name) (type=$($cfg.type))"
                Write-Host "    [FIX] Move '$($cfg.name)' (type=$($cfg.type)) to the provider or RMS bundle -- ENTITIES bundle should only contain QUERYINPUTFORM configs" -ForegroundColor Cyan
            }
            continue
        }
        $qifs += $cfg

        if (-not $cfg.targetEntity) {
            Write-Fail "QIF '$($cfg.name)' missing targetEntity"
            continue
        }
        if (-not $cfg.layout) {
            Write-Fail "QIF '$($cfg.name)' missing layout"
            continue
        }
        if (-not $cfg.label) {
            Write-Warn "QIF '$($cfg.name)' missing 'label' property"
            Write-Host "    [FIX] Add 'label' property to QIF '$($cfg.name)' with a descriptive name (e.g. 'Vehicle Query', 'Person Query')" -ForegroundColor Cyan
        }
        if ($cfg.combinations) {
            Write-Fail "QIF '$($cfg.name)' has 'combinations' array -- combinations belong on QIDMs, not QIFs"
        }
        if ($cfg.providerType -eq 'Commsys') {
            Write-Warn "QIF '$($cfg.name)' has providerType='Commsys' -- QIF should not have CommSys providerType (confirmed AZ v2.0)"
            Write-Host "    [FIX] Remove 'providerType' property from QIF '$($cfg.name)' -- providerType belongs on QIDMs, not QIFs" -ForegroundColor Cyan
        }

        # Pre-scan: does this QIF's PlateType carry a default? Used by the PlateYear
        # OOS-only exception below -- when PlateType has NO default (blank), the plate
        # extras are out-of-state-only fields and PlateYear is legitimately blank too
        # (HI v3.0 pattern). Only an asymmetric pair (PlateType defaulted, PlateYear
        # blank) is a real omission worth a WARN.
        $plateTypeHasDefault = $false
        if ($cfg.layout.default) {
            foreach ($p in $cfg.layout.default.PSObject.Properties) {
                $nd = $p.Value
                if ($nd.props -and $nd.props.fieldId -match '^(PlateType|LicensePlateTypeCode|licensePlateTypeCode)$' -and $nd.props.initialValue) {
                    $plateTypeHasDefault = $true; break
                }
            }
        }

        # Extract fieldIds from all layout variants
        $entityFieldIds = New-Object System.Collections.Generic.HashSet[string]
        $entityFieldPropsMap = @{}

        $cfg.layout.PSObject.Properties | ForEach-Object {
            $layoutName = $_.Name
            $layoutObj = $_.Value
            $nodeNames = @()

            $layoutObj.PSObject.Properties | ForEach-Object {
                $nodeName = $_.Name
                $node = $_.Value
                $nodeNames += $nodeName

                # Extract fieldId from form controls
                if ($node.props -and $node.props.fieldId) {
                    [void]$entityFieldIds.Add($node.props.fieldId)
                    $fid = $node.props.fieldId
                    if (-not $entityFieldPropsMap.ContainsKey($fid)) {
                        $entityFieldPropsMap[$fid] = @{
                            attributeTypeId = $node.props.attributeTypeId
                            codeTypeProvider = $node.props.codeTypeProvider
                            codeTypeCategory = $node.props.codeTypeCategory
                            fieldType = $node.type.resolvedName
                            initialValue = $node.props.initialValue
                        }
                    }
                }

                # Validate node has required properties
                if (-not $node.type -or -not $node.type.resolvedName) {
                    Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': missing type.resolvedName"
                }

                # Validate prop types (Craft.js expects specific types)
                if ($node.type.resolvedName -eq 'Row' -and $node.props.templateColumns) {
                    $tc = $node.props.templateColumns
                    if ($tc -isnot [System.Array]) {
                        Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': templateColumns is $($tc.GetType().Name) '$tc' -- must be ARRAY of strings (e.g. [""6"", ""6""])"
                    } elseif ($tc -is [System.Array]) {
                        foreach ($tcItem in $tc) {
                            if ($tcItem -isnot [string]) {
                                Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': templateColumns item '$tcItem' is $($tcItem.GetType().Name) -- must be STRING"
                                break
                            }
                        }
                    }
                    if ($tc -is [System.Array] -and $node.nodes) {
                        if ($tc.Count -ne $node.nodes.Count) {
                            Write-Warn "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': templateColumns has $($tc.Count) entries but Row has $($node.nodes.Count) children -- misaligned columns"
                            Write-Host "    [FIX] In build script: adjust templateColumns to match child count ($($node.nodes.Count)) or add/remove child fields to match column count ($($tc.Count))" -ForegroundColor Cyan
                        }
                    }
                }
                if ($node.props.maxLength -ne $null) {
                    $ml = $node.props.maxLength
                    if ($ml -is [int] -or $ml -is [long] -or $ml -is [double]) {
                        Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': maxLength is NUMBER $ml -- must be STRING ""$ml"""
                    }
                }
                if ($node.props.isCanvas -ne $null -and $node.props.isCanvas -is [string]) {
                    Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': isCanvas is STRING -- must be BOOLEAN"
                }
                if ($node.type.resolvedName -eq 'Card' -and $node.props.isCanvas -eq $false) {
                    Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': Card has isCanvas=false -- form will not render"
                }
                if ($node.props.hidden -ne $null -and $node.props.hidden -is [string]) {
                    Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': hidden is STRING -- must be BOOLEAN"
                }
                if ($node.props.autoSelect -ne $null -and $node.props.autoSelect -is [string]) {
                    Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nodeName': autoSelect is STRING -- must be BOOLEAN (AP #23)"
                }

                # G-1: Standard field defaults (check only 'default' layout to avoid 3x noise)
                if ($layoutName -eq 'default' -and $node.props -and $node.props.fieldId) {
                    if ($node.props.fieldId -match '^(PlateType|LicensePlateTypeCode|licensePlateTypeCode)$' -and $node.type.resolvedName -eq 'FormSelect') {
                        if ($node.props.initialValue -eq 'PC') {
                            Write-Pass "QIF '$($cfg.name)' PlateType initialValue='PC'"; Inc-Pass
                        } elseif (-not $node.props.initialValue) {
                            Write-Pass "QIF '$($cfg.name)' PlateType no initialValue (combo defaults expected)"; Inc-Pass
                        } else {
                            Write-Warn "QIF '$($cfg.name)' PlateType initialValue='$($node.props.initialValue)' -- expected 'PC' or empty"
                            Write-Host "    [FIX] In build script: set initialValue='PC' or remove initialValue (if combo defaults cover it)" -ForegroundColor Cyan
                        }
                    }
                    if ($node.props.fieldId -match '^(LicensePlateYear|licensePlateYear|PlateYear)$') {
                        if (-not $node.props.initialValue) {
                            if ($plateTypeHasDefault) {
                                Write-Warn "QIF '$($cfg.name)' '$($node.props.fieldId)' missing initialValue -- standard is current year"
                                Write-Host "    [FIX] In build script: add initialValue=`$currentYear (dynamic) on the '$($node.props.fieldId)' field" -ForegroundColor Cyan
                            } else {
                                Write-Pass "QIF '$($cfg.name)' '$($node.props.fieldId)' no initialValue (OOS-only plate field; PlateType also blank)"; Inc-Pass
                            }
                        }
                    }
                    if ($node.props.fieldId -eq 'ImageIndicator') {
                        # BUILD_RULES 20b, added as a CHECK 2026-08-04: the real defect is not
                        # "ImageIndicator sits in a set[]" -- it is "some combo needs ImageIndicator
                        # ABSENT". ImageIndicator MUST carry an initialValue or it does not serialize
                        # at all (FIELD_REFERENCE.txt Section 9), so it ALWAYS exists, so any
                        # NOT_EXISTS gate on it is permanently dead. LA_LEMS DriverLicenseQuery is the
                        # portfolio's only instance: DP is gated ImageIndicator EXISTS and DQ
                        # ImageIndicator NOT_EXISTS, making DQ unreachable (registered dead-combo,
                        # decision pending). Being in a set[] is FINE on its own -- AZ_AZDPS v3.5's
                        # DQP/DQPN require Set[BadgeNumber, ImageIndicator, ..., Requestor] for the
                        # driver-licence photo (devdoc #2/#5) and discriminate on REQUESTOR, an
                        # officer-entered field with no default, so the prefill routes nothing there.
                        # I first wrote this exemption the other way round -- pass when ImageIndicator
                        # is in a set[], warn when it is prefilled -- which both blessed LA_LEMS's real
                        # violation and would have kept AZ's photo combos unserializable. Measure what
                        # an exemption actually covers, and gate on the MECHANISM, not on a proxy.
                        if (-not $script:imgIndGateComputed) {
                            $script:imgIndNotExistsGate = $false
                            # $imgIndRoutes = is ImageIndicator a set[] DISCRIMINATOR? Computed HERE with
                            # the gate flag so the two can never drift apart. Written as a bare
                            # $script:imgIndRoutes reference first, with its computation deleted in an
                            # earlier rewrite of this block -- an UNDEFINED variable is falsy, so the
                            # PASS branch silently never fired and the WARN persisted with no error to
                            # show why. Second time today: same shape as $json vs $prov.Json.
                            $script:imgIndRoutes = $false
                            foreach ($b2 in $json.bundles) {
                                foreach ($c2 in $b2.configurations) {
                                    if ($c2.type -ne 'QUERYINPUTDATAMAPPING') { continue }
                                    foreach ($cm2 in @($c2.combinations)) {
                                        foreach ($f2 in @($cm2.requirements.set)) {
                                            if ("$f2" -match '^[Ii]mageIndicator') { $script:imgIndRoutes = $true }
                                        }
                                    }
                                }
                            }
                            foreach ($b in $json.bundles) {
                                foreach ($c in $b.configurations) {
                                    if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
                                    foreach ($cm in @($c.combinations)) {
                                        foreach ($cd in @($cm.requirements.conditions)) {
                                            if ("$($cd.operator)" -ne 'NOT_EXISTS') { continue }
                                            foreach ($f in @($cd.field)) {
                                                if ("$f" -match '^[Ii]mageIndicator') { $script:imgIndNotExistsGate = $true }
                                            }
                                        }
                                    }
                                }
                            }
                            $script:imgIndGateComputed = $true
                        }
                        # THREE cases, because a prefill is required in one and FORBIDDEN in another:
                        #   in a set[] and NOT prefilled  -> PASS. It is a DISCRIMINATOR. Prefilling it
                        #     collapses its combo's variable requirement onto a plainer sibling's and
                        #     kills that sibling. AZ_AZDPS v3.7: prefilled ImageIndicator made DQPN's
                        #     variable set [NameLast,NameFirst] -- IDENTICAL to DQN's -- and DQP's
                        #     [OperatorLicenseNumber], identical to DQ's. Four exact collisions, and no
                        #     ordering can separate identical sets, so DQN/DQ went DEAD. Un-prefilled,
                        #     ImageIndicator is what keeps the photo paths distinct from the plain ones.
                        #   prefilled AND gated NOT_EXISTS -> WARN. BUILD_RULES 20b: always-present, so
                        #     that branch is permanently dead (LA_LEMS DP/DQ).
                        #   neither in a set[] nor prefilled -> WARN. The original rule: a toggle that
                        #     never serializes.
                        if ($script:imgIndRoutes -and -not $node.props.initialValue) {
                            Write-Pass "QIF '$($cfg.name)' ImageIndicator has no initialValue -- CORRECT: it is a set[] DISCRIMINATOR; a prefill would collapse its combo onto a plainer sibling"; Inc-Pass
                        } elseif ($node.props.initialValue -and $script:imgIndNotExistsGate) {
                            Write-Warn "QIF '$($cfg.name)' ImageIndicator initialValue='$($node.props.initialValue)' AND a combo gates on ImageIndicator NOT_EXISTS -- that branch is permanently DEAD (BUILD_RULES 20b: never existence-gate a mandatorily-defaulted field)"
                        } elseif (-not $node.props.initialValue) {
                            Write-Warn "QIF '$($cfg.name)' ImageIndicator has no initialValue -- expected 'Y' or 'N'"
                            Write-Host "    [FIX] In build script: set ImageIndicator initialValue='Y' or 'N' per provider requirement" -ForegroundColor Cyan
                        } else {
                            Write-Pass "QIF '$($cfg.name)' ImageIndicator default='$($node.props.initialValue)' for $($cfg.targetEntity)"; Inc-Pass
                        }
                        if ($node.type.resolvedName -and $node.type.resolvedName -ne 'FormSelect') {
                            Write-Warn "QIF '$($cfg.name)' ImageIndicator is $($node.type.resolvedName) -- should be FormSelect with YES_NO_UNKNOWN"
                            Write-Host "    [FIX] In build script: change ImageIndicator from $($node.type.resolvedName) to FormSelect with codeTypeCategory='YES_NO_UNKNOWN', codeTypeSource='NCIC'" -ForegroundColor Cyan
                        }
                    }
                    # AP #24: NCIC_FIREARM_MAKE on Vehicle form field
                    if ($node.props.codeTypeCategory -and $node.props.codeTypeCategory -match 'FIREARM' -and $cfg.targetEntity -eq 'Vehicle') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' uses codeTypeCategory='$($node.props.codeTypeCategory)' on Vehicle -- firearm makes only (AP #24)"
                        Write-Host "    [FIX] In build script: change '$($node.props.fieldId)' to FormInput (text) or use attributeTypeId='VEHICLE_MAKE' -- no NCIC_VEHICLE_MAKE category exists" -ForegroundColor Cyan
                    }
                    # AP #6: YES_NO should be YES_NO_UNKNOWN
                    if ($node.props.codeTypeCategory -eq 'YES_NO') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' codeTypeCategory='YES_NO' -- should be 'YES_NO_UNKNOWN' (AP #6: empty dropdown)"
                        Write-Host "    [FIX] In build script: change codeTypeCategory from 'YES_NO' to 'YES_NO_UNKNOWN' on field '$($node.props.fieldId)'" -ForegroundColor Cyan
                    }
                    # AP #7: NCIC_ARTICLE_TYPE requires CA_CLETS source
                    if ($node.props.codeTypeCategory -eq 'NCIC_ARTICLE_TYPE' -and $node.props.codeTypeSource -eq 'NCIC') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' NCIC_ARTICLE_TYPE with codeTypeSource='NCIC' -- empty dropdown, use 'CA_CLETS' (AP #7)"
                        Write-Host "    [FIX] In build script: change codeTypeSource from 'NCIC' to 'CA_CLETS' on field '$($node.props.fieldId)'" -ForegroundColor Cyan
                    }
                    # AP #13: NIBRS_RACE requires NIBRS source
                    if ($node.props.codeTypeCategory -eq 'NIBRS_RACE' -and $node.props.codeTypeSource -eq 'NCIC') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' NIBRS_RACE with codeTypeSource='NCIC' -- empty dropdown, use 'NIBRS' (AP #13)"
                        Write-Host "    [FIX] In build script: change codeTypeSource from 'NCIC' to 'NIBRS' on field '$($node.props.fieldId)'" -ForegroundColor Cyan
                    }
                    # Generic: categories that don't populate under NCIC codeTypeSource
                    if ($node.props.codeTypeSource -eq 'NCIC' -and $node.props.codeTypeCategory) {
                        $nonNcicCategories = @('NIBRS_SEX','NIBRS_ETHNICITY','VEHICLE_BODY_STYLE','VEHICLE_TYPE')
                        if ($nonNcicCategories -contains $node.props.codeTypeCategory) {
                            Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' codeTypeCategory='$($node.props.codeTypeCategory)' with codeTypeSource='NCIC' -- empty dropdown, needs different source"
                            Write-Host "    [FIX] In build script: change codeTypeSource from 'NCIC' to the correct source for '$($node.props.codeTypeCategory)' -- check FIELD_REFERENCE.txt Section 2 for valid pairings" -ForegroundColor Cyan
                        }
                    }
                    # STATE field visibility pattern
                    if ($node.props.attributeTypeId -eq 'STATE' -and $node.props.hidden -ne $true) {
                        if ($node.type.resolvedName -eq 'FormInput') {
                            Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' visible FormInput with attributeTypeId='STATE' -- use FormSelect with codeTypeProvider='NCIC' or hide for outbound-only"
                            Write-Host "    [FIX] In build script: change '$($node.props.fieldId)' to FormSelect (Sel) with attributeTypeId='STATE', or to hidden FormInput (InpH) if outbound-only" -ForegroundColor Cyan
                        }
                    }
                    # Visible Attention FormInput: only flag if a QIDM auto-fills it via handler.
                    # The hidden flag is node-level ($node.hidden), not in props -- a hidden
                    # Attention gate-feeder (the working pattern on ConnectCic) must NOT warn.
                    if ($node.props.fieldId -eq 'Attention' -and $node.hidden -ne $true -and $node.props.hidden -ne $true) {
                        $fieldType = $node.type.resolvedName
                        if ($fieldType -match 'FormInput|FormSelect') {
                            $attnAutoFilled = $false
                            foreach ($pb in $providerBundles) {
                                foreach ($qcfg in $pb.configurations) {
                                    if ($qcfg.type -ne "QUERYINPUTDATAMAPPING" -or $qcfg.targetEntity -ne $cfg.targetEntity) { continue }
                                    foreach ($qattr in $qcfg.attributes) {
                                        if (($qattr.targetField -eq 'Attention' -or $qattr.name -eq 'Attention') -and $qattr.rule -and $qattr.rule.function -eq 'CommsysGetLastNameFirstNameInitialRuleHandler') {
                                            $attnAutoFilled = $true
                                        }
                                    }
                                }
                            }
                            if ($attnAutoFilled) {
                                Write-Warn "QIF '$($cfg.name)' has visible $fieldType with fieldId='Attention' -- QIDM auto-fills via handler, should be hidden"
                                Write-Host "    [FIX] In build script: set hidden=`$true on the Attention field (or change to InpH) -- CommsysGetLastNameFirstNameInitialRuleHandler fills it automatically" -ForegroundColor Cyan
                            }
                        }
                    }
                    # AP #3: attributeTypeId='RACE' on form field without codeTypeProvider (sends numeric ID, not code)
                    if ($node.props.attributeTypeId -eq 'RACE' -and -not $node.props.codeTypeProvider) {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' has attributeTypeId='RACE' without codeTypeProvider -- sends numeric ID, use codeTypeCategory='NIBRS_RACE' or add codeTypeProvider (AP #3)"
                        Write-Host "    [FIX] In build script: if an RMS 'race' (useAttributeId) attr OR a CommSys RaceCode attr with codeTypeProvider consumes this field, KEEP attributeTypeId='RACE' and ADD codeTypeProvider='NIBRS' (produces the ID both need). ONLY if nothing consumes it as an ID (a -SkipRace provider): switch to codeTypeCategory='NIBRS_RACE'+codeTypeSource='NIBRS' and drop attributeTypeId." -ForegroundColor Cyan
                    }
                    # Y-only fields should be FormInput, not FormSelect
                    $yOnlyFields = @('RelatedHitSearchIndicator','ExpandedNameSearchCode','ExpandedBirthDateSearchIndicator')
                    if ($yOnlyFields -contains $node.props.fieldId -and $node.type.resolvedName -eq 'FormSelect') {
                        Write-Info "QIF '$($cfg.name)' field '$($node.props.fieldId)' is FormSelect -- Y-only fields can use FormInput maxLength=1 to avoid exposing N/U"
                    }
                    # SexCode form field chain: must have attributeTypeId=SEX AND codeTypeProvider=NIBRS (includes DH-suffix variants)
                    if ($node.props.fieldId -match '^SexCode(DH|OOS)?$') {
                        if ($node.props.attributeTypeId -ne 'SEX') {
                            Write-Warn "QIF '$($cfg.name)' SexCode field missing attributeTypeId='SEX' -- reverse-lookup will not work"
                            Write-Host "    [FIX] In build script: add attributeTypeId='SEX' to the SexCode FormSelect field" -ForegroundColor Cyan
                        }
                        if ($node.props.codeTypeProvider -ne 'NIBRS') {
                            Write-Warn "QIF '$($cfg.name)' SexCode field missing codeTypeProvider='NIBRS' -- dropdown shows wrong values"
                            Write-Host "    [FIX] In build script: add codeTypeProvider='NIBRS' to the SexCode FormSelect field" -ForegroundColor Cyan
                        }
                        if ($node.props.codeTypeCategory) {
                            Write-Warn "QIF '$($cfg.name)' SexCode field has codeTypeCategory='$($node.props.codeTypeCategory)' -- use attributeTypeId=SEX + codeTypeProvider=NIBRS instead"
                            Write-Host "    [FIX] In build script: remove codeTypeCategory='$($node.props.codeTypeCategory)' from SexCode and use attributeTypeId='SEX' + codeTypeProvider='NIBRS'" -ForegroundColor Cyan
                        }
                    }
                    # LicensePlateNumber fieldId check — canonical name is licensePlateNumber (no In/Out suffix)
                    if ($node.props.fieldId -match '^LicensePlateNumber(In|Out)$' -and $cfg.targetEntity -eq 'Vehicle') {
                        Write-Warn "QIF '$($cfg.name)' uses deprecated fieldId='$($node.props.fieldId)' -- use 'licensePlateNumber' (no In/Out suffix)"
                        Write-Host "    [FIX] In build script: rename fieldId from '$($node.props.fieldId)' to 'licensePlateNumber' and update all QIDM sourceField references" -ForegroundColor Cyan
                    }
                    # PlateYear current year check
                    if ($node.props.fieldId -match '^(LicensePlateYear|licensePlateYear|PlateYear)$' -and $node.props.initialValue) {
                        $currentYear = (Get-Date).Year.ToString()
                        if ($node.props.initialValue -ne $currentYear) {
                            Write-Warn "QIF '$($cfg.name)' '$($node.props.fieldId)' initialValue='$($node.props.initialValue)' -- current year is $currentYear"
                            Write-Host "    [FIX] In build script: update '$($node.props.fieldId)' initialValue to '$currentYear' (use `$currentYear dynamic variable)" -ForegroundColor Cyan
                        }
                    }
                }

                # Validate parent-child consistency
                if ($node.nodes) {
                    foreach ($child in $node.nodes) {
                        $childExists = $false
                        $layoutObj.PSObject.Properties | ForEach-Object {
                            if ($_.Name -eq $child) { $childExists = $true }
                        }
                        if (-not $childExists) {
                            Write-Fail "QIF '$($cfg.name)' layout '$layoutName': node '$nodeName' references child '$child' which doesn't exist"
                        }
                    }
                }
            }

            # Validate ROOT exists
            $hasRoot = $false
            foreach ($n in $nodeNames) { if ($n -eq "ROOT") { $hasRoot = $true } }
            if (-not $hasRoot) {
                Write-Fail "QIF '$($cfg.name)' layout '$layoutName': missing ROOT node"
            }

            # FORM_ROOT props check (hidePageItems=true, layout='page')
            $layoutNodes = @{}
            $layoutObj.PSObject.Properties | ForEach-Object { $layoutNodes[$_.Name] = $_.Value }
            if ($layoutNodes.ContainsKey('FORM_ROOT')) {
                $formRoot = $layoutNodes['FORM_ROOT']
                if ($formRoot.props) {
                    if ($formRoot.props.hidePageItems -ne $true) {
                        Write-Warn "QIF '$($cfg.name)' layout '$layoutName' FORM_ROOT missing hidePageItems=true"
                        Write-Host "    [FIX] In build script: add hidePageItems=`$true to FORM_ROOT props in '$layoutName' layout" -ForegroundColor Cyan
                    }
                    if ($formRoot.props.layout -ne 'page') {
                        Write-Warn "QIF '$($cfg.name)' layout '$layoutName' FORM_ROOT layout='$($formRoot.props.layout)' -- expected 'page'"
                        Write-Host "    [FIX] In build script: set FORM_ROOT props.layout='page' in '$layoutName' layout" -ForegroundColor Cyan
                    }
                }
            }

            # Bidirectional parent-child consistency (node.parent must match node that lists it as child)
            foreach ($nName in $layoutNodes.Keys) {
                $n = $layoutNodes[$nName]
                if ($n.parent) {
                    if (-not $layoutNodes.ContainsKey($n.parent)) {
                        Write-Fail "QIF '$($cfg.name)' layout '$layoutName': node '$nName' parent='$($n.parent)' does not exist -- orphan node will not render"
                    } else {
                        $parentNode = $layoutNodes[$n.parent]
                        if ($parentNode.nodes -and $parentNode.nodes -notcontains $nName) {
                            Write-Warn "QIF '$($cfg.name)' layout '$layoutName': node '$nName' parent='$($n.parent)' but parent does not list it as child"
                            Write-Host "    [FIX] In build script: add '$nName' to the nodes[] array of parent '$($n.parent)' in '$layoutName' layout" -ForegroundColor Cyan
                        }
                    }
                }
            }

            # Validate FormInput/FormSelect/FormDate have fieldId
            $layoutObj.PSObject.Properties | ForEach-Object {
                $node = $_.Value
                $typeName = $node.type.resolvedName
                if ($typeName -match 'FormInput|FormSelect|FormDate|FormCheckbox') {
                    if (-not $node.props -or -not $node.props.fieldId) {
                        Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$($_.Name)' ($typeName): missing fieldId in props"
                    }
                }
            }

            Write-Info "QIF '$($cfg.name)' layout '$layoutName': $($nodeNames.Count) nodes"
        }

        # Store fieldIds per entity (accumulate across QIFs sharing the same entity)
        $entity = $cfg.targetEntity
        if (-not $allFieldIds.ContainsKey($entity)) {
            $allFieldIds[$entity] = New-Object System.Collections.Generic.HashSet[string]
        }
        foreach ($fid in $entityFieldIds) {
            [void]$allFieldIds[$entity].Add($fid)
        }
        if (-not $allFieldProps.ContainsKey($entity)) { $allFieldProps[$entity] = @{} }
        foreach ($fid in $entityFieldPropsMap.Keys) {
            $allFieldProps[$entity][$fid] = $entityFieldPropsMap[$fid]
        }

        # Check 3 layout variants exist (default, CAD_DISPATCH, FIRST_RESPONDER)
        $layoutNames = @($cfg.layout.PSObject.Properties | ForEach-Object { $_.Name })
        $requiredLayouts = @('default','CAD_DISPATCH','FIRST_RESPONDER')
        foreach ($rl in $requiredLayouts) {
            if ($layoutNames -notcontains $rl) {
                Write-Warn "QIF '$($cfg.name)' missing '$rl' layout variant"
                Write-Host "    [FIX] In build script: add '$rl' layout variant to QIF '$($cfg.name)' -- clone from 'default' layout and add CONTEXT_INFO_CARD for CAD/FR variants" -ForegroundColor Cyan
            }
        }

        # Check card titles for non-ASCII characters (AP #26 -- mojibake)
        # Check duplicate fieldId across cards (causes Internal Server Error)
        $cfg.layout.PSObject.Properties | ForEach-Object {
            $layoutName = $_.Name
            $layoutObj2 = $_.Value
            $fieldCardMap = @{}
            $nodeMap = @{}
            $layoutObj2.PSObject.Properties | ForEach-Object { $nodeMap[$_.Name] = $_.Value }

            foreach ($nName in $nodeMap.Keys) {
                $n = $nodeMap[$nName]
                if ($n.props -and $n.props.title) {
                    $title = $n.props.title
                    if ($title -match '[^\x00-\x7F]') {
                        Write-Fail "QIF '$($cfg.name)' layout '$layoutName' node '$nName' title contains non-ASCII: '$title' (AP #26)"
                    }
                    if ($title -match '<[a-zA-Z/]') {
                        Write-Warn "QIF '$($cfg.name)' layout '$layoutName' node '$nName' title contains HTML tag: '$title' -- renders as plain text (LIMITATION #11)"
                        Write-Host "    [FIX] In build script: remove HTML tags from card title -- use plain ASCII text only" -ForegroundColor Cyan
                    }
                }
                if ($n.props -and $n.props.fieldId) {
                    $fid = $n.props.fieldId
                    $current = $nName
                    $cardName = $null
                    for ($walk = 0; $walk -lt 20; $walk++) {
                        $pName = $null
                        if ($nodeMap.ContainsKey($current) -and $nodeMap[$current].parent) {
                            $pName = $nodeMap[$current].parent
                        }
                        if (-not $pName -or -not $nodeMap.ContainsKey($pName)) { break }
                        if ($nodeMap[$pName].type -and $nodeMap[$pName].type.resolvedName -eq 'Card') {
                            $cardName = $pName
                            break
                        }
                        $current = $pName
                    }
                    if ($cardName) {
                        if (-not $fieldCardMap.ContainsKey($fid)) {
                            $fieldCardMap[$fid] = @($cardName)
                        } elseif ($fieldCardMap[$fid] -notcontains $cardName) {
                            $fieldCardMap[$fid] += $cardName
                        }
                    }
                }
            }
            foreach ($fid in $fieldCardMap.Keys) {
                if ($fieldCardMap[$fid].Count -gt 1) {
                    Write-Fail "QIF '$($cfg.name)' layout '$layoutName': fieldId '$fid' on multiple cards ($($fieldCardMap[$fid] -join ', ')) -- causes Internal Server Error"
                }
            }
        }

        Write-Pass "QIF '$($cfg.name)' -> $entity : $($entityFieldIds.Count) fieldIds"; Inc-Pass
    }

    # 0 QIFs = no entity forms at all
    if ($qifs.Count -eq 0) {
        Write-Fail "ENTITIES bundle has 0 QIFs -- no entity query forms defined"
    }

    # Duplicate QIF names
    $qifNames = @{}
    foreach ($q in $qifs) {
        if ($q.name) {
            if ($qifNames.ContainsKey($q.name)) {
                Write-Fail "ENTITIES bundle: duplicate QIF name '$($q.name)' (entities: $($qifNames[$q.name]), $($q.targetEntity)) -- second silently overwrites first at import"
            } else {
                $qifNames[$q.name] = $q.targetEntity
            }
        }
    }

    # Check entity order matches QIF targetEntities
    if ($entitiesBundle.order -and $entitiesBundle.order.default) {
        $orderEntities = $entitiesBundle.order.default
        $qifEntities = $qifs | ForEach-Object { $_.targetEntity } | Sort-Object -Unique
        foreach ($oe in $orderEntities) {
            if ($qifEntities -notcontains $oe) {
                Write-Fail "Entity '$oe' in order array but no QIF has targetEntity='$oe'"
            }
        }
        foreach ($qe in $qifEntities) {
            if ($orderEntities -notcontains $qe) {
                Write-Warn "QIF targetEntity '$qe' not in order array"
                Write-Host "    [FIX] Add '$qe' to the ENTITIES order.default array (and CAD_DISPATCH/FIRST_RESPONDER)" -ForegroundColor Cyan
            }
        }
    }

    # Scan QIDMs to find which entities have ImageIndicator attributes (scope check)
    $entitiesWithImageIndicatorQidm = @{}
    foreach ($bundle in $providerBundles) {
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
            foreach ($attr in $cfg.attributes) {
                if ($attr.targetField -eq 'ImageIndicator' -or $attr.name -eq 'ImageIndicator') {
                    $entitiesWithImageIndicatorQidm[$cfg.targetEntity] = $true
                }
            }
        }
    }

    # Expected fields per entity type (field existence checks)
    $expectedFieldsByEntity = @{
        'Vehicle' = @(
            @{ fieldId='PlateType'; altFieldIds=@('LicensePlateTypeCode','licensePlateTypeCode'); severity='WARN'; reason='standard default PC -- missing means officer must manually select' }
        )
    }
    # Expected field checks (deduplicated per entity, not per QIF)
    $checkedEntities = @{}
    foreach ($entity in $allFieldIds.Keys) {
        if ($checkedEntities.ContainsKey($entity)) { continue }
        $checkedEntities[$entity] = $true
        $fids = $allFieldIds[$entity]

        if ($expectedFieldsByEntity.ContainsKey($entity)) {
            foreach ($expected in $expectedFieldsByEntity[$entity]) {
                $found = $fids.Contains($expected.fieldId)
                if (-not $found -and $expected.altFieldIds) { foreach ($alt in $expected.altFieldIds) { if ($fids.Contains($alt)) { $found = $true; break } } }
                if (-not $found) {
                    Write-Warn "$entity missing fieldId '$($expected.fieldId)' -- $($expected.reason)"
                    Write-Host "    [FIX] In build script: add a FormSelect field with fieldId='$($expected.fieldId)' to the $entity QIF" -ForegroundColor Cyan
                }
            }
        }

        # ImageIndicator: only WARN if a QIDM maps it but form doesn't have it
        # Check standard names AND entity-specific variants (imageIndicatorArticle, imageIndicatorBoat, etc.)
        $hasImageIndicator = $fids.Contains('ImageIndicator') -or $fids.Contains('imageIndicator')
        if (-not $hasImageIndicator) {
            $entityLower = $entity.ToLower()
            foreach ($fid in $fids) {
                if ($fid -match '^[Ii]mageIndicator') { $hasImageIndicator = $true; break }
            }
        }
        if (-not $hasImageIndicator) {
            if ($entitiesWithImageIndicatorQidm.ContainsKey($entity)) {
                Write-Warn "$entity missing fieldId 'ImageIndicator' -- QIDM maps it but form has no field"
                Write-Host "    [FIX] In build script: add FormSelect with fieldId='ImageIndicator', codeTypeCategory='YES_NO_UNKNOWN', initialValue='Y' or 'N' to $entity QIF" -ForegroundColor Cyan
            }
        }

        if ($entity -eq 'Vehicle') {
            if (-not $fids.Contains('PlateYear') -and -not $fids.Contains('LicensePlateYear') -and -not $fids.Contains('licensePlateYear')) {
                Write-Warn "Vehicle missing PlateYear/LicensePlateYear -- standard default is current year"
                Write-Host "    [FIX] In build script: add FormInput with fieldId='LicensePlateYear' and initialValue=`$currentYear to Vehicle QIF" -ForegroundColor Cyan
            }
            if (-not $fids.Contains('VehicleYear') -and -not $fids.Contains('VehicleModelYear')) {
                Write-Info "Vehicle has no VehicleYear/VehicleModelYear input field (ok if year is result-only)"
            }
        }
    }

    # CAD_DISPATCH layout: check CONTEXT_INFO_CARD has CadUnit_Input + CadEvent_Input (INFO-level, only with -ShowDetail)
    foreach ($qif in $qifs) {
        if ($qif.layout.CAD_DISPATCH) {
            $hasContextCard = $false
            $hasCadUnit = $false
            $hasCadEvent = $false
            $qif.layout.CAD_DISPATCH.PSObject.Properties | ForEach-Object {
                $node = $_.Value
                if ($_.Name -match 'CONTEXT_INFO') { $hasContextCard = $true }
                if ($node.props -and $node.props.fieldId -eq 'CadUnit_Input') { $hasCadUnit = $true }
                if ($node.props -and $node.props.fieldId -eq 'CadEvent_Input') { $hasCadEvent = $true }
            }
            if ($hasContextCard) {
                if (-not $hasCadUnit) {
                    Write-Info "QIF '$($qif.name)' CAD_DISPATCH CONTEXT_INFO_CARD missing CadUnit_Input field"
                }
                if (-not $hasCadEvent) {
                    Write-Info "QIF '$($qif.name)' CAD_DISPATCH CONTEXT_INFO_CARD missing CadEvent_Input field"
                }
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 3: QIDM VALIDATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 3: QIDM Validation ===" -ForegroundColor Cyan

$qidms = @()
$systemSourceFields = @('ORI','Mnemonic','DeviceId','dexStateUserId','Requestor',
    'ExpandedNameSearchCode','OperatorLicenseStateCode','RelatedHitSearchIndicator',
    'NameSearchModifier','ReasonForInquiry')

# Check for duplicate config names in provider bundles
$provConfigNames = @{}
foreach ($bundle in $providerBundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.name) {
            if ($provConfigNames.ContainsKey($cfg.name)) {
                Write-Fail "Provider bundle duplicate config name '$($cfg.name)' (types: $($provConfigNames[$cfg.name]), $($cfg.type)) -- may cause silent overwrite at import"
            } else {
                $provConfigNames[$cfg.name] = $cfg.type
            }
        }
    }
}

# Check for unknown config types in provider bundles
$knownConfigTypes = @('QUERYINPUTDATAMAPPING','AUTHENTICATION','QUERYMESSAGEFORMAT','QUERYRESULTDATAMAPPING')
foreach ($bundle in $providerBundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -and $knownConfigTypes -notcontains $cfg.type) {
            Write-Warn "Provider bundle '$($bundle.name)' config '$($cfg.name)' has unknown type '$($cfg.type)' -- may be silently ignored"
            Write-Host "    [FIX] Change config type to one of: QUERYINPUTDATAMAPPING, AUTHENTICATION, QUERYMESSAGEFORMAT, QUERYRESULTDATAMAPPING" -ForegroundColor Cyan
        }
    }
}

foreach ($bundle in $providerBundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        $qidms += $cfg

        $entity = $cfg.targetEntity
        if (-not $entity) {
            Write-Fail "QIDM '$($cfg.name)' missing targetEntity"
            continue
        }

        if (-not $cfg.attributes -or $cfg.attributes.Count -eq 0) {
            Write-Fail "QIDM '$($cfg.name)' has no attributes"
            continue
        }

        # Get fieldIds for this entity
        $entityFields = $null
        if ($allFieldIds.ContainsKey($entity)) {
            $entityFields = $allFieldIds[$entity]
        }

        # Check for duplicate targetFields
        $targetFieldMap = @{}
        foreach ($attr in $cfg.attributes) {
            $tf = $attr.targetField
            if ($tf) {
                if ($targetFieldMap.ContainsKey($tf)) {
                    $targetFieldMap[$tf] += $attr.name
                } else {
                    $targetFieldMap[$tf] = @($attr.name)
                }
            }
        }
        foreach ($tf in $targetFieldMap.Keys) {
            if ($targetFieldMap[$tf].Count -gt 1) {
                Write-Fail "QIDM '$($cfg.name)' duplicate targetField '$tf' from attributes: $($targetFieldMap[$tf] -join ', ')"
            }
        }

        # Attribute name required
        foreach ($attr in $cfg.attributes) {
            if (-not $attr.name -or $attr.name -eq '') {
                Write-Fail "QIDM '$($cfg.name)' has unnamed attribute (targetField='$($attr.targetField)') -- all attributes require 'name' property"
            }
        }

        # Rule object structure validation
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule) {
                if (-not $attr.rule.function) {
                    Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' rule object missing 'function' property -- must be rule:{function:'HandlerName'}"
                } elseif ($attr.rule.function -is [System.Array]) {
                    Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' rule.function is ARRAY -- must be STRING"
                }
            }
        }

        # Known rule handler function enum (catch typos)
        $knownHandlers = @('CommsysGetDexStateUserIdRuleHandler','CommsysParseDateRuleHandler',
            'FormatStringRuleHandler','CommsysGetLastNameFirstNameInitialRuleHandler',
            'IgnoreUserValueRuleHandler','CommsysArticleAttributeRuleHandler',
            'CommsysResultAttributeMappingRuleHandler','CommysResultFallbackRegexRuleHandler',
            'HeightParserRuleHandler','ParseCommsysNameRuleHandler','ParseCommsysVehicleYearRuleHandler',
            'truncate','FormatArrayRuleHandler','FormatNameRuleHandler','AttributeArrayWrapperRuleHandler',
            'RmsRestPayloadHandler','RmsRestResultsHandler','RestRequestHandler','QueryResultsLayoutHandler',
            'StaticValueRuleHandler','GetUserProfileSingleValueRuleHandler')
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule -and $attr.rule.function -and $attr.rule.function -is [string]) {
                if ($knownHandlers -notcontains $attr.rule.function) {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' rule.function='$($attr.rule.function)' -- not in known handlers list (typo?)"
                    Write-Host "    [FIX] Check spelling of rule.function='$($attr.rule.function)' -- see RULE_HANDLERS.txt for valid handler names" -ForegroundColor Cyan
                }
            }
        }

        # G-4: Check for duplicate attribute names within QIDM
        $attrNameCounts = $cfg.attributes | Group-Object -Property name
        foreach ($ag in $attrNameCounts) {
            if ($ag.Count -gt 1) {
                Write-Fail "QIDM '$($cfg.name)' duplicate attribute name '$($ag.Name)' ($($ag.Count)x) -- silent conflict"
            }
        }

        # G-5: sourceField must be array, not string
        foreach ($attr in $cfg.attributes) {
            if ($attr.sourceField -and $attr.sourceField -is [string]) {
                Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' sourceField is STRING '$($attr.sourceField)' -- should be ARRAY @('$($attr.sourceField)')"
                Write-Host "    [FIX] In build script: change sourceField='$($attr.sourceField)' to sourceField=@('$($attr.sourceField)') (wrap in array)" -ForegroundColor Cyan
            }
        }

        # G-7: Every attribute must have targetField
        foreach ($attr in $cfg.attributes) {
            if (-not $attr.targetField) {
                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' missing targetField"
            }
        }

        # Attribute size required on all QIDM attributes
        foreach ($attr in $cfg.attributes) {
            if ($attr.size -eq $null) {
                Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' missing size property"
                Write-Host "    [FIX] In build script: add size=<number> to attr '$($attr.name)' (check metadata XML for expected field length)" -ForegroundColor Cyan
            }
        }

        # Check sourceField references against QIF fieldIds
        $phantomFields = @()
        foreach ($attr in $cfg.attributes) {
            $sourceFields = @()
            if ($attr.sourceField -is [System.Array]) {
                $sourceFields = $attr.sourceField
            } elseif ($attr.sourceField) {
                $sourceFields = @($attr.sourceField)
            }

            foreach ($sf in $sourceFields) {
                if ($systemSourceFields -contains $sf) { continue }
                if ($entityFields -and -not $entityFields.Contains($sf)) {
                    # Check if it has a rule (rule-based attributes may not need form fields)
                    if (-not $attr.rule) {
                        $phantomFields += "$($attr.name) (sourceField='$sf')"
                    }
                }
            }
        }
        if ($phantomFields.Count -gt 0) {
            $comboFields = @()
            foreach ($combo in $cfg.combinations) {
                if ($combo.requirements.set) { $comboFields += @($combo.requirements.set) }
                if ($combo.requirements.any) { $comboFields += @($combo.requirements.any) }
            }
            $comboFields = $comboFields | Select-Object -Unique
            $truePhantoms = @()
            $qidmOnlyAttrs = @()
            foreach ($pf in $phantomFields) {
                $attrName = if ($pf -match "^(\S+)\s") { $Matches[1] } else { $pf }
                $sfName = if ($pf -match "sourceField='([^']+)'") { $Matches[1] } else { $attrName }
                if ($comboFields -notcontains $sfName -and $comboFields -notcontains $attrName) {
                    $qidmOnlyAttrs += $pf
                } else {
                    $truePhantoms += $pf
                }
            }
            if ($truePhantoms.Count -gt 0) {
                Write-Warn "QIDM '$($cfg.name)' has $($truePhantoms.Count) sourceField(s) not found in $entity QIF:"
                Write-Host "    [FIX] Add matching form fields to $entity QIF, or add a rule handler to auto-populate these attributes, or remove them from the QIDM" -ForegroundColor Cyan
                foreach ($pf in $truePhantoms) { Write-Host "         $pf" -ForegroundColor Yellow }
            }
            if ($qidmOnlyAttrs.Count -gt 0) {
                Write-Limitation "QIDM '$($cfg.name)' has $($qidmOnlyAttrs.Count) QIDM-only attr(s) with no QIF field and no combo reference (will be empty unless handler-filled):"
                foreach ($pf in $qidmOnlyAttrs) { Write-Host "         $pf" -ForegroundColor DarkYellow }
            }
        }

        # Check combinations
        if (-not $cfg.combinations -or $cfg.combinations.Count -eq 0) {
            Write-Fail "QIDM '$($cfg.name)' has no combinations"
        } else {
            # Check combination requirements reference valid fields
            $keyRefs = @()
            foreach ($combo in $cfg.combinations) {
                if ($combo.keyReference) { $keyRefs += $combo.keyReference }
                else {
                    $comboIdx = [array]::IndexOf($cfg.combinations, $combo)
                    Write-Warn "QIDM '$($cfg.name)' combo at index $comboIdx missing keyReference -- platform uses keyRef for combo identification"
                    Write-Host "    [FIX] In build script: add a unique keyReference string to combo at index $comboIdx (e.g. derived from query type + primary field)" -ForegroundColor Cyan
                }
                if ($combo.requirements -and $combo.requirements.set) {
                    foreach ($reqField in $combo.requirements.set) {
                        if ($entityFields -and -not $entityFields.Contains($reqField)) {
                            if ($systemSourceFields -notcontains $reqField) {
                                Write-Warn "QIDM '$($cfg.name)' combo '$($combo.keyReference)' set[] references '$reqField' not in QIF fieldIds"
                                Write-Host "    [FIX] Add field '$reqField' to the $entity QIF, or remove '$reqField' from this combo's set[] array" -ForegroundColor Cyan
                            }
                        }
                    }
                }
                if ($combo.requirements -and $combo.requirements.any) {
                    foreach ($reqField in $combo.requirements.any) {
                        if ($entityFields -and -not $entityFields.Contains($reqField)) {
                            if ($systemSourceFields -notcontains $reqField) {
                                Write-Warn "QIDM '$($cfg.name)' combo '$($combo.keyReference)' any[] references '$reqField' not in QIF fieldIds"
                                Write-Host "    [FIX] Add field '$reqField' to the $entity QIF, or remove '$reqField' from this combo's any[] array" -ForegroundColor Cyan
                            }
                        }
                    }
                }
            }

            # Check for duplicate keyReferences
            $dupKeys = $keyRefs | Group-Object | Where-Object { $_.Count -gt 1 }
            foreach ($dk in $dupKeys) {
                Write-Fail "QIDM '$($cfg.name)' duplicate keyReference '$($dk.Name)' ($($dk.Count)x) -- import will fail"
            }

            # Check for wrong property name: keyRef instead of keyReference
            foreach ($combo in $cfg.combinations) {
                $raw = $combo | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($raw -contains 'keyRef') {
                    Write-Fail "QIDM '$($cfg.name)' combo uses 'keyRef' instead of 'keyReference' -- platform rejects as duplicate keys"
                    break
                }
            }

            # Combo 'name' property check (should use keyReference not name)
            foreach ($combo in $cfg.combinations) {
                $comboProps = $combo | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($comboProps -contains 'name') {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    Write-Warn "QIDM '$($cfg.name)' combo '$comboId' has 'name' property -- should use 'keyReference' only"
                    Write-Host "    [FIX] In build script: remove 'name' property from combo '$comboId' -- platform uses 'keyReference' for identification" -ForegroundColor Cyan
                }
            }

            # CommSys combos must have state property ('In', 'Out', or 'In/Out')
            if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
                $validStates = @('In','Out','In/Out')
                foreach ($combo in $cfg.combinations) {
                    if (-not $combo.state) {
                        $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                        Write-Warn "QIDM '$($cfg.name)' combo '$comboId' missing state property -- CommSys combos need state='In', 'Out', or 'In/Out'"
                        Write-Host "    [FIX] In build script: add state='In/Out' to combo '$comboId' (or 'In'/'Out' if provider has separate in-state/OOS routing)" -ForegroundColor Cyan
                    } elseif ($validStates -notcontains $combo.state) {
                        $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                        Write-Warn "QIDM '$($cfg.name)' combo '$comboId' state='$($combo.state)' -- must be 'In', 'Out', or 'In/Out'"
                        Write-Host "    [FIX] In build script: change state='$($combo.state)' to one of: 'In', 'Out', 'In/Out'" -ForegroundColor Cyan
                    }
                }
            }

            # Check CommSys combos have primaryFieldReference
            if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
                $missingPfr = @($cfg.combinations | Where-Object { -not $_.primaryFieldReference })
                if ($missingPfr.Count -gt 0) {
                    Write-Warn "QIDM '$($cfg.name)' has $($missingPfr.Count) combo(s) missing 'primaryFieldReference'"
                    Write-Host "    [FIX] In build script: add primaryFieldReference to each combo -- use the QIDM attribute name for the primary search field (e.g. 'LicensePlateNumber', 'Name')" -ForegroundColor Cyan
                }
            }

            # G-15: Combo must have requirements object (not bare set/any)
            foreach ($combo in $cfg.combinations) {
                if (-not $combo.requirements) {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    $comboProps = $combo | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    if ($comboProps -contains 'set' -or $comboProps -contains 'any') {
                        Write-Fail "QIDM '$($cfg.name)' combo '$comboId' has bare set[]/any[] -- must be inside requirements object"
                    }
                } else {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    if ($combo.requirements.set -ne $null -and $combo.requirements.set -is [string]) {
                        Write-Fail "QIDM '$($cfg.name)' combo '$comboId' requirements.set is STRING -- must be ARRAY"
                    }
                    if ($combo.requirements.any -ne $null -and $combo.requirements.any -is [string]) {
                        Write-Fail "QIDM '$($cfg.name)' combo '$comboId' requirements.any is STRING -- must be ARRAY"
                    }
                }
            }

            # G-17: primaryFieldReference must reference a valid attribute name
            $attrNames = @($cfg.attributes | ForEach-Object { $_.name })
            foreach ($combo in $cfg.combinations) {
                if ($combo.primaryFieldReference -and $attrNames -notcontains $combo.primaryFieldReference) {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    Write-Warn "QIDM '$($cfg.name)' combo '$comboId' primaryFieldReference='$($combo.primaryFieldReference)' not in attribute names"
                    Write-Host "    [FIX] In build script: change primaryFieldReference to a valid attribute name from this QIDM (available: $($attrNames -join ', '))" -ForegroundColor Cyan
                }
            }

            # G-27: Empty requirements (both set[] and any[] empty or missing)
            foreach ($combo in $cfg.combinations) {
                if ($combo.requirements) {
                    $setCount = if ($combo.requirements.set) { $combo.requirements.set.Count } else { 0 }
                    $anyCount = if ($combo.requirements.any) { $combo.requirements.any.Count } else { 0 }
                    if ($setCount -eq 0 -and $anyCount -eq 0) {
                        $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                        Write-Warn "QIDM '$($cfg.name)' combo '$comboId' has empty requirements (no set[], no any[]) -- fires on any form state"
                        Write-Host "    [FIX] In build script: add set[] and/or any[] arrays to combo '$comboId' requirements with the fields that should trigger this combo" -ForegroundColor Cyan
                    }
                }
            }

            # G-31: POISONED-ARRAY -- value-comparison conditions (EQUALS/NOT_EQUALS/IN/NOT_IN/
            # REGEX) are INERT on this platform; they disable the combo's ENTIRE conditions array
            # (incl. co-resident EXISTS/NOT_EXISTS), so it fires unconditioned and can join the
            # union pool / over-send. Only existence conditions are honored. Live-proven FL v4.9
            # T-A/T-B 2026-06-12 (QIDM_REFERENCE Sec 2a). WARN -> fix at provider rebuild.
            foreach ($combo in $cfg.combinations) {
                $cConds = @()
                if ($combo.conditions) { $cConds += $combo.conditions }
                if ($combo.requirements -and $combo.requirements.conditions) { $cConds += $combo.requirements.conditions }
                if ($cConds.Count -eq 0) { continue }
                $poison = @($cConds | Where-Object { "$($_.operator)".ToUpperInvariant() -in @('EQUALS','NOT_EQUALS','IN','NOT_IN','REGEX') })
                if ($poison.Count -gt 0) {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    $desc = ($poison | ForEach-Object { "$(@($_.field) -join '+') $("$($_.operator)".ToUpperInvariant())" }) -join '; '
                    Write-Warn "QIDM '$($cfg.name)' combo '$comboId' has POISONED-ARRAY condition(s) [$desc] -- value-comparison operators are INERT; the entire conditions array is disabled and the combo fires UNCONDITIONED (union-pool/over-send risk)."
                    Write-Host "    [FIX] In build script: remove value-comparison conditions; merge now-identical combos or route via EXISTS/NOT_EXISTS only. See QIDM_REFERENCE Sec 2a (poisoned-array)." -ForegroundColor Cyan
                }
            }

            # G-32: INERT CONDITION FIELD -- conditions[].field must be a FORM sourceField /
            # fieldId (the form-state key the platform reads), NOT the QIDM attribute `name`.
            # A field that matches only an attribute name whose sourceField differs (or matches
            # nothing) is SILENTLY INERT live: the EXISTS/NOT_EXISTS never sees the populated
            # form field, so the combo fires unconditioned (union-pool / over-send risk). The
            # valid form-state keys = every attribute's sourceField in THIS QIDM.
            # Live-proven HI v3.4 T5 (field=State [attr name, sourceField RegistrationState]
            # bled; field=RegistrationState suppressed). Cross-provider scan 2026-06-22 found
            # 10 inert (all FL_FCIC State NOT_EXISTS). Poisoned arrays (G-31) are skipped here.
            $validCondKeys = @{}
            foreach ($a in $cfg.attributes) {
                foreach ($sf in @($a.sourceField)) { if ($sf) { $validCondKeys["$sf"] = $true } }
            }
            $condAttrByName = @{}
            foreach ($a in $cfg.attributes) { if ($a.name) { $condAttrByName["$($a.name)"] = $a } }
            foreach ($combo in $cfg.combinations) {
                $cConds = @()
                if ($combo.conditions) { $cConds += $combo.conditions }
                if ($combo.requirements -and $combo.requirements.conditions) { $cConds += $combo.requirements.conditions }
                if ($cConds.Count -eq 0) { continue }
                # value-comparison arrays are already flagged by G-31 (poisoned) -- skip to avoid double-flag
                $hasValueCmp = @($cConds | Where-Object { "$($_.operator)".ToUpperInvariant() -in @('EQUALS','NOT_EQUALS','IN','NOT_IN','REGEX') }).Count -gt 0
                if ($hasValueCmp) { continue }
                $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                foreach ($cond in $cConds) {
                    $op = "$($cond.operator)".ToUpperInvariant()
                    if ($op -eq 'EXCLUSIVE') { continue }
                    foreach ($f in @($cond.field)) {
                        if (-not $f) { continue }
                        if ($validCondKeys.ContainsKey("$f")) { continue }   # resolves to a sourceField -> EFFECTIVE
                        if ($condAttrByName.ContainsKey("$f")) {
                            $sf = (@($condAttrByName["$f"].sourceField) -join ',')
                            Write-Warn "QIDM '$($cfg.name)' combo '$comboId' condition field '$f' ($op) is INERT -- '$f' is an attribute NAME (sourceField '$sf'); conditions match the FORM sourceField, not the attribute name, so this gate never fires (always treated as absent)."
                            Write-Host "    [FIX] In build script: change the conditions field from '$f' to '$sf' (the sourceField). Live-proven HI v3.4 T5; see QIDM_REFERENCE FIELD=SOURCEFIELD." -ForegroundColor Cyan
                        } else {
                            Write-Warn "QIDM '$($cfg.name)' combo '$comboId' condition field '$f' ($op) is INERT -- it matches no attribute sourceField in this QIDM (no such form-state key); the gate never fires."
                            Write-Host "    [FIX] In build script: set the conditions field to a real form sourceField/fieldId defined in this QIDM's attributes." -ForegroundColor Cyan
                        }
                    }
                }
            }

            # G-16: Combination ordering -- shadowing check. A later combo is unreachable when an
            # EARLIER combo's set[] is a subset of its set[] (first match fires) UNLESS the earlier
            # combo carries routing conditions (NOT_EXISTS/NOT_EQUALS defer to later combos --
            # devdoc-order standard, FL v4.7). Conditions may live at combo level (FL style) or
            # inside requirements (NY style).
            if ($cfg.combinations.Count -gt 1) {
                $shadowed = $null
                for ($oi = 0; $oi -lt $cfg.combinations.Count -and -not $shadowed; $oi++) {
                    $earlier = $cfg.combinations[$oi]
                    $eSet = @()
                    if ($earlier.requirements -and $earlier.requirements.set) { $eSet = @($earlier.requirements.set) }
                    $eConds = @()
                    if ($earlier.conditions) { $eConds += $earlier.conditions }
                    if ($earlier.requirements -and $earlier.requirements.conditions) { $eConds += $earlier.requirements.conditions }
                    if ($eConds.Count -gt 0 -or $eSet.Count -eq 0) { continue }
                    for ($oj = $oi + 1; $oj -lt $cfg.combinations.Count; $oj++) {
                        $later = $cfg.combinations[$oj]
                        $lSet = @()
                        if ($later.requirements -and $later.requirements.set) { $lSet = @($later.requirements.set) }
                        $isSubset = $true
                        foreach ($f in $eSet) { if ($lSet -notcontains $f) { $isSubset = $false; break } }
                        if ($isSubset) {
                            $eKr = if ($earlier.keyReference) { $earlier.keyReference } else { "(combo $oi)" }
                            $lKr = if ($later.keyReference) { $later.keyReference } else { "(combo $oj)" }
                            $shadowed = "QIDM '$($cfg.name)' combo '$lKr' is unreachable: earlier unconditioned combo '$eKr' set[] is a subset of its set[] (first match fires; add routing conditions to '$eKr' or reorder)"
                            break
                        }
                    }
                }
                if ($shadowed) {
                    Write-Limitation $shadowed
                }
            }

            Write-Pass "QIDM '$($cfg.name)' -> $entity : $($cfg.attributes.Count) attrs, $($cfg.combinations.Count) combos"; Inc-Pass
        }

        # Check for wrong rule format: ruleHandlers[] instead of rule{}
        foreach ($attr in $cfg.attributes) {
            $attrProps = $attr | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            if ($attrProps -contains 'ruleHandlers') {
                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' uses 'ruleHandlers' array instead of 'rule' object -- platform expects rule.function"
                break
            }
        }

        # Type safety: size must be number, useAttributeId must be boolean
        foreach ($attr in $cfg.attributes) {
            if ($attr.size -ne $null -and $attr.size -is [string]) {
                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' size is STRING '$($attr.size)' -- must be NUMBER"
            }
            if ($attr.useAttributeId -ne $null -and $attr.useAttributeId -is [string]) {
                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' useAttributeId is STRING '$($attr.useAttributeId)' -- must be BOOLEAN"
            }
        }

        # Check required QIDM properties
        if (-not $cfg.handlerFunction) { Write-Fail "QIDM '$($cfg.name)' missing handlerFunction" }
        elseif ($cfg.handlerFunction -ne 'CommsysTransactionRequestHandler') {
            Write-Fail "CommSys QIDM '$($cfg.name)' handlerFunction='$($cfg.handlerFunction)' -- must be 'CommsysTransactionRequestHandler'"
        }
        if (-not $cfg.provider) { Write-Fail "QIDM '$($cfg.name)' missing provider" }
        elseif ($cfg.provider -ne $bundle.name) {
            Write-Warn "QIDM '$($cfg.name)' provider='$($cfg.provider)' does not match bundle name '$($bundle.name)'"
            Write-Host "    [FIX] In build script: change QIDM provider from '$($cfg.provider)' to '$($bundle.name)' to match the parent bundle" -ForegroundColor Cyan
        }
        if (-not $cfg.query) { Write-Fail "QIDM '$($cfg.name)' missing query" }
        else {
            $knownQueries = @('VehicleRegistrationQuery','VehicleStolenQuery','DriverLicenseQuery','DriverHistoryQuery','GunQuery','ArticleSingleQuery','BoatQuery')
            if ($knownQueries -notcontains $cfg.query) {
                Write-Info "QIDM '$($cfg.name)' query='$($cfg.query)' -- not in standard set (may be provider-specific transaction)"
            }
            $queryEntityMap = @{
                'VehicleRegistrationQuery' = 'Vehicle'
                'VehicleStolenQuery'       = 'Vehicle'
                'DriverLicenseQuery'       = 'Person'
                'DriverHistoryQuery'       = 'Person'
                'GunQuery'                 = 'Firearm'
                'ArticleSingleQuery'       = 'Article'
                'BoatQuery'                = 'Boat'
            }
            $expectedEntity = $queryEntityMap[$cfg.query]
            if ($expectedEntity -and $cfg.targetEntity -ne $expectedEntity) {
                Write-Warn "QIDM '$($cfg.name)' query='$($cfg.query)' targets '$($cfg.targetEntity)' -- expected '$expectedEntity'"
                Write-Host "    [FIX] Change targetEntity from '$($cfg.targetEntity)' to '$expectedEntity', or verify query='$($cfg.query)' is correct for this entity" -ForegroundColor Cyan
            }
        }
        if (-not $cfg.description) { Write-Warn "QIDM '$($cfg.name)' missing description property"; Write-Host "    [FIX] In build script: add description property to QIDM '$($cfg.name)' (e.g. descriptive text of what this QIDM does)" -ForegroundColor Cyan }
        if (-not $cfg.providerType) { Write-Warn "QIDM '$($cfg.name)' missing providerType property"; Write-Host "    [FIX] In build script: add providerType='Commsys' to QIDM '$($cfg.name)'" -ForegroundColor Cyan }
        elseif ($cfg.providerType -ne 'Commsys') { Write-Warn "QIDM '$($cfg.name)' providerType='$($cfg.providerType)' -- expected 'Commsys'"; Write-Host "    [FIX] In build script: change providerType from '$($cfg.providerType)' to 'Commsys'" -ForegroundColor Cyan }

        # Check queryLabel standard (AP #25)
        if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
            $standardLabels = @{
                'VehicleRegistrationQuery' = 'Vehicle Registration'
                'VehicleStolenQuery'       = 'Vehicle Stolen'
                'DriverLicenseQuery'       = 'Driver License'
                'DriverHistoryQuery'       = 'Driver History'
                'GunQuery'                 = 'Firearm'
                'ArticleSingleQuery'       = 'Article'
                'BoatQuery'                = 'Boat'
            }
            if ($cfg.queryLabel) {
                $expectedLabel = $standardLabels[$cfg.query]
                if ($expectedLabel -and $cfg.queryLabel -ne $expectedLabel) {
                    Write-Warn "QIDM '$($cfg.name)' queryLabel='$($cfg.queryLabel)' -- standard is '$expectedLabel' (AP #25)"
                    Write-Host "    [FIX] In build script: change queryLabel from '$($cfg.queryLabel)' to '$expectedLabel'" -ForegroundColor Cyan
                }
                if ($cfg.queryLabel -match 'Query') {
                    Write-Info "QIDM '$($cfg.name)' queryLabel='$($cfg.queryLabel)' contains 'Query' -- label by search type not query name (AP #25)"
                }
                $badLabels = @('Vehicle','Person','NCIC','DMV','FCIC','NJCJIS','TLETS','LEMS','AZDPS','NYSPIN')
                if ($badLabels -contains $cfg.queryLabel) {
                    Write-Warn "QIDM '$($cfg.name)' queryLabel='$($cfg.queryLabel)' -- do not use entity or system names as labels (AP #25)"
                    Write-Host "    [FIX] In build script: change queryLabel to describe the search type (e.g. 'Vehicle Registration', 'Driver License', 'Firearm') per AP #25" -ForegroundColor Cyan
                }
            } else {
                Write-Warn "QIDM '$($cfg.name)' missing queryLabel property"
                Write-Host "    [FIX] In build script: add queryLabel property to QIDM '$($cfg.name)' -- see QIDM_REFERENCE.txt for standard labels per query type" -ForegroundColor Cyan
            }
        }

        # Check FormatStringRuleHandler argument count (AP #15)
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule -and $attr.rule.function -eq 'FormatStringRuleHandler') {
                $sfCount = 0
                if ($attr.sourceField -is [System.Array]) { $sfCount = $attr.sourceField.Count }
                elseif ($attr.sourceField) { $sfCount = 1 }
                $argCount = 0
                if ($attr.rule.arguments -is [System.Array]) { $argCount = $attr.rule.arguments.Count }
                $expected = [Math]::Max(0, $sfCount - 1)
                if ($argCount -ne $expected) {
                    Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' FormatStringRuleHandler: $argCount arguments but $sfCount sourceFields (need $expected args = fields - 1, AP #15)"
                }
            }
        }

        # CommsysGetDexStateUserIdRuleHandler must have arguments=['true']
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule -and $attr.rule.function -eq 'CommsysGetDexStateUserIdRuleHandler') {
                if (-not $attr.rule.arguments -or -not ($attr.rule.arguments -is [System.Array]) -or $attr.rule.arguments.Count -eq 0) {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysGetDexStateUserIdRuleHandler missing arguments -- needs @('true')"
                    Write-Host "    [FIX] In build script: add arguments=@('true') to the CommsysGetDexStateUserIdRuleHandler rule on attr '$($attr.name)'" -ForegroundColor Cyan
                } elseif ($attr.rule.arguments[0] -ne 'true') {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysGetDexStateUserIdRuleHandler arguments[0]='$($attr.rule.arguments[0])' -- expected 'true'"
                    Write-Host "    [FIX] In build script: change arguments[0] from '$($attr.rule.arguments[0])' to 'true'" -ForegroundColor Cyan
                }
            }
        }

        # Check AP #1: attributeTypeId='STATE' in CommSys QIDM sourceField without codeTypeProvider
        if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
            $entityProps = $null
            if ($allFieldProps.ContainsKey($entity)) { $entityProps = $allFieldProps[$entity] }
            if ($entityProps) {
                foreach ($attr in $cfg.attributes) {
                    $sfs = @()
                    if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                    elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                    foreach ($sf in $sfs) {
                        if ($entityProps.ContainsKey($sf) -and $entityProps[$sf].attributeTypeId -eq 'STATE') {
                            if (-not $attr.codeTypeProvider) {
                                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' sourceField='$sf' has attributeTypeId=STATE on form but NO codeTypeProvider on QIDM attr -- sends numeric ID (AP #1)"
                            } else {
                                Write-Pass "QIDM '$($cfg.name)' attr '$($attr.name)' STATE field with codeTypeProvider='$($attr.codeTypeProvider)' (AP #1)"; Inc-Pass
                            }
                        }
                    }
                }

                # Check AP #2: SexCode QIDM attr maps attributeTypeId=SEX without codeTypeProvider
                foreach ($attr in $cfg.attributes) {
                    if ($attr.targetField -eq 'SexCode') {
                        if ($attr.size -ne $null -and $attr.size -ne 1) {
                            Write-Warn "QIDM '$($cfg.name)' SexCode attr '$($attr.name)' size=$($attr.size) -- expected 1"
                            Write-Host "    [FIX] In build script: change SexCode attr size from $($attr.size) to 1" -ForegroundColor Cyan
                        }
                        if (-not $attr.codeTypeProvider) {
                            $sfs = @()
                            if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                            elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                            foreach ($sf in $sfs) {
                                if ($entityProps.ContainsKey($sf) -and $entityProps[$sf].attributeTypeId -eq 'SEX') {
                                    Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' maps attributeTypeId=SEX to SexCode WITHOUT codeTypeProvider -- sends numeric ID (AP #2)"
                                }
                            }
                        } else {
                            if ($attr.codeTypeProvider -ne 'NIBRS') {
                                Write-Warn "QIDM '$($cfg.name)' SexCode codeTypeProvider='$($attr.codeTypeProvider)' -- expected 'NIBRS' (AP #2)"
                                Write-Host "    [FIX] In build script: change SexCode QIDM attr codeTypeProvider from '$($attr.codeTypeProvider)' to 'NIBRS'" -ForegroundColor Cyan
                            } else {
                                Write-Pass "QIDM '$($cfg.name)' SexCode has codeTypeProvider='NIBRS' (AP #2)"; Inc-Pass
                            }
                        }
                    }
                }
            }

            # Check ImageIndicator size=1 and in combo any[]/set[] (G-20)
            foreach ($attr in $cfg.attributes) {
                if ($attr.targetField -eq 'ImageIndicator' -or $attr.name -eq 'ImageIndicator') {
                    if ($attr.size -ne 1) {
                        Write-Warn "QIDM '$($cfg.name)' ImageIndicator size=$($attr.size) -- expected 1"
                        Write-Host "    [FIX] In build script: change ImageIndicator attr size from $($attr.size) to 1" -ForegroundColor Cyan
                    } else {
                        Write-Pass "QIDM '$($cfg.name)' ImageIndicator size=1"; Inc-Pass
                    }
                    $imgInCombo = $false
                    $imgFieldName = if ($attr.sourceField -is [System.Array] -and $attr.sourceField.Count -eq 1) { $attr.sourceField[0] } elseif ($attr.sourceField -is [string]) { $attr.sourceField } else { $attr.name }
                    foreach ($combo in $cfg.combinations) {
                        if ($combo.requirements) {
                            if ($combo.requirements.set -and $combo.requirements.set -contains $imgFieldName) { $imgInCombo = $true }
                            if ($combo.requirements.any -and $combo.requirements.any -contains $imgFieldName) { $imgInCombo = $true }
                        }
                    }
                    if (-not $imgInCombo) {
                        Write-Warn "QIDM '$($cfg.name)' ImageIndicator attr '$imgFieldName' not in any combo set[]/any[] -- will not serialize to XML"
                        Write-Host "    [FIX] In build script: add '$imgFieldName' to the any[] array of every combo in QIDM '$($cfg.name)'" -ForegroundColor Cyan
                    }
                }
            }

            # Check AP #3: attributeTypeId='RACE' on CommSys outbound field
            if ($entityProps) {
                foreach ($attr in $cfg.attributes) {
                    if ($attr.targetField -eq 'RaceCode') {
                        $sfs = @()
                        if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                        elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                        foreach ($sf in $sfs) {
                            if ($entityProps.ContainsKey($sf) -and $entityProps[$sf].attributeTypeId -eq 'RACE' -and -not $attr.codeTypeProvider) {
                                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' maps attributeTypeId=RACE to RaceCode without codeTypeProvider -- sends numeric ID (AP #3)"
                            }
                        }
                    }
                }
            }

            # AP #11 (CommSys reverse-lookup direction): an attr WITH codeTypeProvider does an
            # attribute-ID -> provider-code reverse-lookup on the wire, so its form field must PRODUCE
            # an attribute ID (attributeTypeId=...). A code-string dropdown (codeTypeCategory without
            # attributeTypeId) feeds it a bare code the reverse-lookup can't resolve -> dropped/garbled
            # filter. The RMS useAttributeId direction is gated at the AP #11 block; this is the
            # CommSys-attr side (NM_NMLETS_OFML raceCodeDH was the live latent instance, 2026-07-24).
            if ($entityProps) {
                foreach ($attr in $cfg.attributes) {
                    if (-not $attr.codeTypeProvider) { continue }
                    $sfs = @()
                    if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                    elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                    foreach ($sf in $sfs) {
                        if ($entityProps.ContainsKey($sf)) {
                            $fp = $entityProps[$sf]
                            if ($fp.codeTypeCategory -and -not $fp.attributeTypeId) {
                                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' has codeTypeProvider='$($attr.codeTypeProvider)' (attr-ID reverse-lookup) but sourceField '$sf' is a code-string dropdown (codeTypeCategory='$($fp.codeTypeCategory)', no attributeTypeId) -- reverse-lookup can't resolve a code (AP #11, CommSys direction)"
                            }
                        }
                    }
                }
            }

            # Check LicensePlateNumber sourceField — canonical name is licensePlateNumber (no In/Out suffix)
            foreach ($attr in $cfg.attributes) {
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($sf in $sfs) {
                    if ($sf -match '^LicensePlateNumber(In|Out)$') {
                        Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' sourceField='$sf' uses deprecated In/Out suffix -- use 'licensePlateNumber' instead"
                        Write-Host "    [FIX] In build script: change sourceField from '$sf' to 'licensePlateNumber' and update combo set[]/any[] references" -ForegroundColor Cyan
                    }
                }
                # targetField should be XML element name (LicensePlateNumber), not form fieldId variant
                if ($attr.targetField -match '^LicensePlateNumber(In|Out)$') {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' targetField='$($attr.targetField)' -- XML element should be 'LicensePlateNumber' (targetField is XML name, not form fieldId)"
                    Write-Host "    [FIX] In build script: change targetField from '$($attr.targetField)' to 'LicensePlateNumber'" -ForegroundColor Cyan
                }
            }

            # G-11: Attention handler pattern — only flag if handler is present but misconfigured
            foreach ($attr in $cfg.attributes) {
                if ($attr.targetField -eq 'Attention' -or $attr.name -eq 'Attention') {
                    $hasAutoFillHandler = $attr.rule -and $attr.rule.function -eq 'CommsysGetLastNameFirstNameInitialRuleHandler'
                    if ($hasAutoFillHandler) {
                        $attnInCombo = $false
                        $attnFieldName = if ($attr.sourceField -is [System.Array] -and $attr.sourceField.Count -eq 1) { $attr.sourceField[0] } elseif ($attr.sourceField -is [string]) { $attr.sourceField } else { $attr.name }
                        foreach ($combo in $cfg.combinations) {
                            if ($combo.requirements) {
                                if ($combo.requirements.set -and $combo.requirements.set -contains $attnFieldName) { $attnInCombo = $true }
                                if ($combo.requirements.any -and $combo.requirements.any -contains $attnFieldName) { $attnInCombo = $true }
                            }
                        }
                        # LIVE-PROVEN (HI 2026-06-22): this platform serializes ONLY fields in
                        # the fired combo's set[]/any[]. An auto-fill Attention handler therefore
                        # MUST have its source field in a combo any[] or its output is dropped
                        # (handler emitted 'SGAMBELLONE R' only once Attention was in any[]).
                        # So the correct state is IN a combo; flag the INVERSE.
                        if (-not $attnInCombo) {
                            Write-Warn "QIDM '$($cfg.name)' Attention auto-fill handler present but '$attnFieldName' is NOT in any combo set[]/any[] -- the platform will DROP the handler output (it serializes only fired-combo fields)"
                            Write-Host "    [FIX] In build script: add '$attnFieldName' to the combo any[] arrays in QIDM '$($cfg.name)', and keep a populated (hidden) '$attnFieldName' gate-feeder field" -ForegroundColor Cyan
                        }
                    }
                }
            }

            # G-12: Date field needs CommsysParseDateRuleHandler
            if ($entityProps) {
                foreach ($attr in $cfg.attributes) {
                    $sfs = @()
                    if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                    elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                    foreach ($sf in $sfs) {
                        if ($entityProps.ContainsKey($sf) -and $entityProps[$sf].fieldType -eq 'FormDate') {
                            if (-not $attr.rule -or $attr.rule.function -ne 'CommsysParseDateRuleHandler') {
                                Write-Fail "QIDM '$($cfg.name)' attr '$($attr.name)' sourceField='$sf' is FormDate but no CommsysParseDateRuleHandler -- sends raw ISO date, query rejected"
                            } else {
                                Write-Pass "QIDM '$($cfg.name)' attr '$($attr.name)' FormDate with CommsysParseDateRuleHandler"; Inc-Pass
                                $dateArgs = $attr.rule.arguments
                                if (-not $dateArgs -or -not ($dateArgs -is [System.Array]) -or $dateArgs.Count -ne 2) {
                                    $ac = if ($dateArgs -is [System.Array]) { $dateArgs.Count } else { 0 }
                                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysParseDateRuleHandler needs exactly 2 arguments (has $ac) -- @('yyyy-MM-dd','<provider-format>')"
                                    Write-Host "    [FIX] In build script: set arguments=@('yyyy-MM-dd','<provider-date-format>') on attr '$($attr.name)' (check metadata for target format)" -ForegroundColor Cyan
                                } elseif ($dateArgs[0] -ne 'yyyy-MM-dd') {
                                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysParseDateRuleHandler first argument='$($dateArgs[0])' -- expected 'yyyy-MM-dd'"
                                    Write-Host "    [FIX] In build script: change first argument from '$($dateArgs[0])' to 'yyyy-MM-dd' (FormDate always sends ISO format)" -ForegroundColor Cyan
                                } elseif ($dateArgs[1] -notmatch '^[yMd\-/]+$') {
                                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysParseDateRuleHandler second argument='$($dateArgs[1])' -- does not look like a date format"
                                    Write-Host "    [FIX] In build script: change second argument to a valid date format string (e.g. 'MMddyyyy', 'yyyyMMdd') per provider metadata" -ForegroundColor Cyan
                                }
                            }
                        }
                    }
                }
            }
        }

        # AP #24: NCIC_FIREARM_MAKE on non-Firearm QIDM attribute
        foreach ($attr in $cfg.attributes) {
            if ($attr.codeTypeCategory -eq 'NCIC_FIREARM_MAKE' -and $entity -ne 'Firearm') {
                Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' uses NCIC_FIREARM_MAKE on $entity -- firearm makes only (AP #24)"
                Write-Host "    [FIX] In build script: remove codeTypeCategory='NCIC_FIREARM_MAKE' from $entity attr '$($attr.name)' -- use FormInput (text) for vehicle make" -ForegroundColor Cyan
            }
        }

        # AP #23: autoSelect type check on QIDM
        if ($cfg.autoSelect -ne $null -and $cfg.autoSelect -is [string]) {
            Write-Fail "QIDM '$($cfg.name)' autoSelect is STRING '$($cfg.autoSelect)' -- must be BOOLEAN (AP #23)"
        }

        # CommSys combo field→attribute cross-reference (AP #27 equivalent for CommSys)
        if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler' -and $cfg.combinations -and $cfg.attributes) {
            $commsysAttrSourceFields = New-Object System.Collections.Generic.HashSet[string]
            foreach ($attr in $cfg.attributes) {
                if ($attr.sourceField -is [System.Array]) {
                    foreach ($sf in $attr.sourceField) { [void]$commsysAttrSourceFields.Add($sf) }
                } elseif ($attr.sourceField) {
                    [void]$commsysAttrSourceFields.Add($attr.sourceField)
                }
            }
            foreach ($combo in $cfg.combinations) {
                if (-not $combo.requirements) { continue }
                $cFields = @()
                if ($combo.requirements.set) { $cFields += $combo.requirements.set }
                if ($combo.requirements.any) { $cFields += $combo.requirements.any }
                foreach ($cf in $cFields) {
                    if ($systemSourceFields -contains $cf) { continue }
                    if (-not $commsysAttrSourceFields.Contains($cf)) {
                        $cId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                        Write-Warn "QIDM '$($cfg.name)' combo '$cId' field '$cf' in set[]/any[] has no matching attribute sourceField"
                        Write-Host "    [FIX] Add a QIDM attribute with sourceField=['$cf'] to QIDM '$($cfg.name)', or remove '$cf' from combo '$cId' set[]/any[]" -ForegroundColor Cyan
                    }
                }
            }
        }

        # Check AP #4: IgnoreUserValueRuleHandler (dead end)
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule -and $attr.rule.function -eq 'IgnoreUserValueRuleHandler') {
                Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' uses IgnoreUserValueRuleHandler -- DEAD END, does not substitute argument (AP #4)"
                Write-Host "    [FIX] In build script: replace IgnoreUserValueRuleHandler with a hidden FormInput (InpH) with initialValue set to the desired value" -ForegroundColor Cyan
            }
        }
    }
}

# RMS QIDM combo vs attribute cross-check (AP #27)
if ($rmsBundle) {
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $cfg.attributes -or -not $cfg.combinations) { continue }

        $rmsAttrSourceFields = New-Object System.Collections.Generic.HashSet[string]
        foreach ($attr in $cfg.attributes) {
            if ($attr.sourceField -is [System.Array]) {
                foreach ($sf in $attr.sourceField) { [void]$rmsAttrSourceFields.Add($sf) }
            } elseif ($attr.sourceField) {
                [void]$rmsAttrSourceFields.Add($attr.sourceField)
            }
        }

        foreach ($combo in $cfg.combinations) {
            if (-not $combo.requirements) { continue }
            $comboFields = @()
            if ($combo.requirements.set) { $comboFields += $combo.requirements.set }
            if ($combo.requirements.any) { $comboFields += $combo.requirements.any }

            foreach ($field in $comboFields) {
                if (-not $rmsAttrSourceFields.Contains($field)) {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(no keyRef)" }
                    Write-Fail "RMS QIDM '$($cfg.name)' combo '$comboId': field '$field' in set[]/any[] has no matching attribute (AP #27 -- import will fail)"
                }
            }
        }
    }

    # RMS QIDM missing combinations check
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $cfg.combinations -or $cfg.combinations.Count -eq 0) {
            Write-Warn "RMS QIDM '$($cfg.name)' has no combinations -- RMS query will never fire"
            Write-Host "    [FIX] In build script: Build-RmsBundle in _build_rms_bundle.ps1 provides standard combinations" -ForegroundColor Cyan
        }
    }

    # Duplicate keyReference check on RMS QIDMs
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $cfg.combinations) { continue }
        $rmsKeyRefs = @()
        foreach ($combo in $cfg.combinations) {
            if ($combo.keyReference) { $rmsKeyRefs += $combo.keyReference }
        }
        $rmsDupKeys = $rmsKeyRefs | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($dk in $rmsDupKeys) {
            Write-Fail "RMS QIDM '$($cfg.name)' duplicate keyReference '$($dk.Name)' ($($dk.Count)x) -- import will fail"
        }
    }

    # Duplicate targetField check on RMS QIDMs (same check as CommSys, lines 467-483)
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $cfg.attributes) { continue }
        $rmsTargetFieldMap = @{}
        foreach ($attr in $cfg.attributes) {
            $tf = $attr.targetField
            if ($tf) {
                if ($rmsTargetFieldMap.ContainsKey($tf)) {
                    $rmsTargetFieldMap[$tf] += $attr.name
                } else {
                    $rmsTargetFieldMap[$tf] = @($attr.name)
                }
            }
        }
        foreach ($tf in $rmsTargetFieldMap.Keys) {
            if ($rmsTargetFieldMap[$tf].Count -gt 1) {
                Write-Fail "RMS QIDM '$($cfg.name)' duplicate targetField '$tf' from attributes: $($rmsTargetFieldMap[$tf] -join ', ') -- only last wins, silent data loss"
            }
        }
    }

    # Check LIMITATION #27: AttributeArrayWrapperRuleHandler on RMS sex attribute
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $cfg.attributes) { continue }
        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'sexAttrId') {
                if ($attr.rule -and $attr.rule.function -eq 'AttributeArrayWrapperRuleHandler') {
                    Write-Fail "RMS QIDM '$($cfg.name)' attr '$($attr.name)' has AttributeArrayWrapperRuleHandler on sexAttrId -- causes RMS 400 (LIMITATION #27)"
                }
            }
        }
    }

    # Type safety on RMS QIDM attributes: size must be number, useAttributeId must be boolean
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if (-not $cfg.attributes) { continue }
        foreach ($attr in $cfg.attributes) {
            if ($attr.size -ne $null -and $attr.size -is [string]) {
                Write-Fail "RMS QIDM '$($cfg.name)' attr '$($attr.name)' size is STRING '$($attr.size)' -- must be NUMBER"
            }
            if ($attr.useAttributeId -ne $null -and $attr.useAttributeId -is [string]) {
                Write-Fail "RMS QIDM '$($cfg.name)' attr '$($attr.name)' useAttributeId is STRING '$($attr.useAttributeId)' -- must be BOOLEAN"
            }
        }
    }

    # AP #18: Orphaned SexCode/SexCodeOOS references in RMS combos after sex attr removal
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if ($cfg.targetEntity -ne 'Person') { continue }
        $hasSexAttr = $false
        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'sexAttrId') { $hasSexAttr = $true; break }
        }
        if (-not $hasSexAttr) {
            foreach ($combo in $cfg.combinations) {
                if (-not $combo.requirements) { continue }
                $sexRefs = @()
                if ($combo.requirements.set) {
                    $sexRefs += @($combo.requirements.set | Where-Object { $_ -match 'SexCode' })
                }
                if ($combo.requirements.any) {
                    $sexRefs += @($combo.requirements.any | Where-Object { $_ -match 'SexCode' })
                }
                if ($sexRefs.Count -gt 0) {
                    $cId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    Write-Fail "RMS Person QIDM '$($cfg.name)' combo '$cId' references '$($sexRefs -join ', ')' but no sexAttrId attribute exists (AP #18 -- import will fail)"
                }
            }
        }
    }

    # RMS Person QIDM must have registrationState attribute AND in combo any[]
    # Person uses singular 'registrationStateAttrId' (no ArrayWrapper), Vehicle uses plural 'registrationStateAttrIds' (WITH ArrayWrapper)
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if ($cfg.targetEntity -ne 'Person') { continue }
        $hasRegState = $false
        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'registrationStateAttrId' -or $attr.targetField -eq 'registrationStateAttrIds') {
                $hasRegState = $true
                if ($attr.targetField -eq 'registrationStateAttrIds') {
                    Write-Fail "RMS Person QIDM '$($cfg.name)' attr '$($attr.name)' targetField='registrationStateAttrIds' (plural) -- Person must use singular 'registrationStateAttrId'"
                }
                if ($attr.rule -and $attr.rule.function -eq 'AttributeArrayWrapperRuleHandler') {
                    Write-Fail "RMS Person QIDM '$($cfg.name)' attr '$($attr.name)' has AttributeArrayWrapperRuleHandler on registrationState -- Person uses singular, no ArrayWrapper needed"
                }
            }
        }
        if (-not $hasRegState) {
            Write-Warn "RMS Person QIDM '$($cfg.name)' missing registrationState attribute"
            Write-Host "    [FIX] In build script: add registrationState attr with sourceField=['RegistrationState'], targetField='registrationStateAttrId', useAttributeId=true to RMS Person QIDM" -ForegroundColor Cyan
        } else {
            Write-Pass "RMS Person QIDM '$($cfg.name)' has registrationState attr"; Inc-Pass
            # G-8: RegistrationState must also be in every Person combo any[]
            foreach ($combo in $cfg.combinations) {
                if (-not $combo.requirements) { continue }
                $hasInAny = $false
                if ($combo.requirements.any) {
                    foreach ($f in $combo.requirements.any) {
                        if ($f -eq 'RegistrationState') { $hasInAny = $true }
                    }
                }
                if (-not $hasInAny) {
                    $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                    Write-Warn "RMS Person QIDM '$($cfg.name)' combo '$comboId' missing 'RegistrationState' in any[] -- person search ignores state filter"
                    Write-Host "    [FIX] In build script: add 'RegistrationState' to the any[] array of RMS Person combo '$comboId'" -ForegroundColor Cyan
                }
            }
        }
    }

    # AP #11: RMS QIDM useAttributeId=true but form field stores code string, not attribute ID
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        $entity = $cfg.targetEntity
        if (-not $entity -or -not $allFieldProps.ContainsKey($entity)) { continue }
        $entityProps = $allFieldProps[$entity]
        foreach ($attr in $cfg.attributes) {
            if ($attr.useAttributeId -ne $true) { continue }
            $sfs = @()
            if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
            elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
            foreach ($sf in $sfs) {
                if ($entityProps.ContainsKey($sf)) {
                    $fp = $entityProps[$sf]
                    if ($fp.codeTypeCategory -and -not $fp.attributeTypeId) {
                        Write-Fail "RMS QIDM '$($cfg.name)' attr '$($attr.name)' useAttributeId=true but sourceField '$sf' uses codeTypeCategory='$($fp.codeTypeCategory)' without attributeTypeId -- stores code string not ID (AP #11)"
                    }
                }
            }
        }
    }

    # RMS Vehicle QIDM must have RegistrationState in combo any[]
    # Vehicle uses plural 'registrationStateAttrIds' WITH AttributeArrayWrapperRuleHandler
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if ($cfg.targetEntity -ne 'Vehicle') { continue }

        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'registrationStateAttrId') {
                Write-Warn "RMS Vehicle QIDM '$($cfg.name)' attr '$($attr.name)' targetField='registrationStateAttrId' (singular) -- Vehicle must use plural 'registrationStateAttrIds'"
                Write-Host "    [FIX] In build script: change targetField from 'registrationStateAttrId' to 'registrationStateAttrIds' (plural) on RMS Vehicle attr '$($attr.name)'" -ForegroundColor Cyan
            }
            if ($attr.targetField -eq 'registrationStateAttrIds') {
                if (-not $attr.rule -or $attr.rule.function -ne 'AttributeArrayWrapperRuleHandler') {
                    Write-Warn "RMS Vehicle QIDM '$($cfg.name)' attr '$($attr.name)' registrationStateAttrIds missing AttributeArrayWrapperRuleHandler"
                    Write-Host "    [FIX] In build script: add rule={function:'AttributeArrayWrapperRuleHandler'} to RMS Vehicle registrationStateAttrIds attr" -ForegroundColor Cyan
                }
            }
        }

        $vehicleHasRegStateInAny = $false
        foreach ($combo in $cfg.combinations) {
            if ($combo.requirements -and $combo.requirements.any) {
                foreach ($f in $combo.requirements.any) {
                    if ($f -eq 'RegistrationState') { $vehicleHasRegStateInAny = $true; break }
                }
            }
            if ($vehicleHasRegStateInAny) { break }
        }
        if (-not $vehicleHasRegStateInAny) {
            Write-Warn "RMS Vehicle QIDM '$($cfg.name)' no combo has 'RegistrationState' in any[] -- plate search ignores state"
            Write-Host "    [FIX] In build script: add 'RegistrationState' to the any[] array of the RMS Vehicle licensePlateIn combo" -ForegroundColor Cyan
        } else {
            Write-Pass "RMS Vehicle QIDM '$($cfg.name)' has RegistrationState in combo any[]"; Inc-Pass
        }
    }
}

# G-3: State initialValue safety -- LIMITATION #30 (not RMS-dependent; checks CommSys QIDMs)
$warnedStateL30 = @{}
foreach ($q in $qidms) {
    if ($q.handlerFunction -ne 'CommsysTransactionRequestHandler') { continue }
    $entity = $q.targetEntity
    $hasSeparateInOut = $false
    foreach ($combo in $q.combinations) {
        if ($combo.state -eq 'In' -or $combo.state -eq 'Out') { $hasSeparateInOut = $true; break }
    }
    # LIMITATION #30's MECHANISM requires the State field to be in some combo's set[] (added 2026-08-04).
    # The constraint is: a form initialValue makes the field ALWAYS-PRESENT, which permanently hides
    # every combo needing its ABSENCE. That can only happen if State is a ROUTING field, i.e. it sits
    # in a set[]. When State is any[]-ONLY, a prefill changes which combo fires exactly nowhere, and
    # CLAUDE.md's own decision tree sanctions defaulting it ("default State to home only when
    # any[]-only"). Without this guard the check fired on AZ_AZDPS v3.5 purely because its DQP photo
    # combos are honestly labelled state='In' (metadata DQP defines no State field at all, so they
    # cannot serve out-of-state) while ACWL/DQ/DQN are 'In/Out' -- a LABEL, not a routing risk. The
    # alternative was to mislabel DQP as 'In/Out' to satisfy the gate, which is backwards.
    # Measured before landing: ZERO LIMITATION #30 lines across all 20 providers, so this narrowing
    # costs no existing coverage. Paired with the `az-state-prefill-routes` mutation in
    # audit_gate_efficacy, which puts State into a set[] and confirms the check still fires.
    $stateInSomeSet = $false
    foreach ($combo in $q.combinations) {
        if ($combo.requirements -and $combo.requirements.set) {
            foreach ($f in $combo.requirements.set) {
                if ("$f" -match '(?i)^(RegistrationState|State|RegistrationStateDH|StateDH)$') { $stateInSomeSet = $true; break }
            }
        }
        if ($stateInSomeSet) { break }
    }
    if ($hasSeparateInOut -and -not $stateInSomeSet) {
        Write-Pass "QIDM '$($q.name)' has In/Out combos but State is any[]-only -- a State prefill routes nothing (LIMITATION #30 N/A)"; Inc-Pass
    }
    if ($hasSeparateInOut -and $stateInSomeSet -and $allFieldProps.ContainsKey($entity)) {
        foreach ($fid in $allFieldProps[$entity].Keys) {
            $fp = $allFieldProps[$entity][$fid]
            if ($fp.attributeTypeId -eq 'STATE') {
                $warnKey = "$($q.name)_$fid"
                if ($warnedStateL30.ContainsKey($warnKey)) { continue }
                $qifList = @($qifs | Where-Object { $_.targetEntity -eq $entity })
                foreach ($qif in $qifList) {
                    $qif.layout.PSObject.Properties | ForEach-Object {
                        $_.Value.PSObject.Properties | ForEach-Object {
                            $node = $_.Value
                            if ($node.props -and $node.props.fieldId -eq $fid -and $node.props.initialValue) {
                                if (-not $warnedStateL30.ContainsKey($warnKey)) {
                                    Write-Limitation "QIDM '$($q.name)' has separate In/Out combos but $entity State field '$fid' has initialValue='$($node.props.initialValue)' -- combo routing affected (LIMITATION #30)"
                                    $warnedStateL30[$warnKey] = $true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4: AUTOSELECT & CROSS-REFERENCE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 4: AutoSelect & Cross-Reference ===" -ForegroundColor Cyan

# Group QIDMs by targetEntity
$entityQidms = @{}
foreach ($q in $qidms) {
    $e = $q.targetEntity
    if (-not $entityQidms.ContainsKey($e)) { $entityQidms[$e] = @() }
    $entityQidms[$e] += $q
}

foreach ($entity in $entityQidms.Keys) {
    $eqidms = $entityQidms[$entity]

    # Count QIFs for this entity (wrap in @() to prevent single-element scalar collapse)
    $entityQifCount = @($qifs | Where-Object { $_.targetEntity -eq $entity }).Count

    # Check autoSelect conflicts on single-form entities (wrap in @() to prevent single-element scalar collapse)
    $autoSelectQidms = @($eqidms | Where-Object { $_.autoSelect -eq $true })
    if ($autoSelectQidms.Count -gt 1 -and $entityQifCount -eq 1) {
        $hasCoFireDeselect = $false
        foreach ($asq in $autoSelectQidms) {
            if ($asq.queriesToDeselect -and $asq.queriesToDeselect.Count -gt 0) { $hasCoFireDeselect = $true; break }
        }
        # Suffix-isolation refinement: if every pair of autoSelect QIDMs has fully
        # disjoint set[] trigger pools, neither can arm from the other's field entry --
        # toggle control exists structurally (separate cards). Pattern precedent:
        # TX_TLETS_CCH (CCH-suffix), NJ VehStolenSeparate branch (Rand-suffix).
        $setPools = @()
        foreach ($asq in $autoSelectQidms) {
            $pool = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($c in $asq.combinations) {
                if ($c.requirements.set) { foreach ($f in $c.requirements.set) { [void]$pool.Add($f) } }
            }
            $setPools += ,$pool
        }
        $poolsDisjoint = $true
        for ($i = 0; $i -lt $setPools.Count -and $poolsDisjoint; $i++) {
            for ($j = $i + 1; $j -lt $setPools.Count; $j++) {
                foreach ($f in $setPools[$i]) {
                    if ($setPools[$j].Contains($f)) { $poolsDisjoint = $false; break }
                }
                if (-not $poolsDisjoint) { break }
            }
        }
        if ($hasCoFireDeselect) {
            Write-Pass "${entity}: $($autoSelectQidms.Count) QIDMs co-fire with autoSelect=true + queriesToDeselect on SINGLE QIF"; Inc-Pass
            foreach ($asq in $autoSelectQidms) {
                Write-Host "         $($asq.name) (query=$($asq.query), deselect=$($asq.queriesToDeselect -join ','))" -ForegroundColor DarkGreen
            }
        } elseif ($poolsDisjoint) {
            Write-Pass "${entity}: $($autoSelectQidms.Count) autoSelect QIDMs on SINGLE QIF with DISJOINT set[] pools (suffix-isolated) -- no uncontrolled co-arm possible"; Inc-Pass
            foreach ($asq in $autoSelectQidms) {
                Write-Host "         $($asq.name) (query=$($asq.query))" -ForegroundColor DarkGreen
            }
        } else {
            Write-Limitation "${entity}: $($autoSelectQidms.Count) QIDMs have autoSelect=true on a SINGLE QIF without queriesToDeselect -- co-fire lacks toggle control"
            foreach ($asq in $autoSelectQidms) {
                Write-Host "         $($asq.name) (query=$($asq.query))" -ForegroundColor DarkYellow
            }
        }
    } elseif ($autoSelectQidms.Count -gt 1 -and $entityQifCount -gt 1) {
        Write-Info "${entity}: $($autoSelectQidms.Count) autoSelect QIDMs across $entityQifCount QIFs (ok for multi-form)"
    }

    # Check queriesToDeselect type and references
    foreach ($q in $eqidms) {
        if ($q.queriesToDeselect -ne $null -and $q.queriesToDeselect -is [string]) {
            Write-Fail "QIDM '$($q.name)' queriesToDeselect is STRING '$($q.queriesToDeselect)' -- must be ARRAY"
        }
        if ($q.queriesToDeselect) {
            foreach ($desel in $q.queriesToDeselect) {
                $found = $false
                foreach ($other in $eqidms) {
                    if ($other.query -eq $desel) { $found = $true }
                }
                if (-not $found) {
                    Write-Fail "QIDM '$($q.name)' queriesToDeselect references '$desel' but no QIDM has query='$desel'"
                }
            }
        }
    }

    # AP #14 / LIMITATION #25: DH-suffix pattern detection when DL+DH on same single form
    if ($entityQifCount -eq 1 -and $eqidms.Count -gt 1) {
        $dlQidmArr = @($eqidms | Where-Object { $_.query -eq 'DriverLicenseQuery' })
        $dhQidmArr = @($eqidms | Where-Object { $_.query -eq 'DriverHistoryQuery' })
        $dlQidm = if ($dlQidmArr.Count -gt 0) { $dlQidmArr[0] } else { $null }
        $dhQidm = if ($dhQidmArr.Count -gt 0) { $dhQidmArr[0] } else { $null }
        if ($dlQidm -and $dhQidm) {
            $hasDhSuffix = $false
            $dhNonSuffixed = @()
            # Collect DL sourceFields to detect intentionally shared fields
            $dlSourceFields = @()
            foreach ($dlA in $dlQidm.attributes) {
                $dlSfs = @()
                if ($dlA.sourceField -is [System.Array]) { $dlSfs = $dlA.sourceField }
                elseif ($dlA.sourceField) { $dlSfs = @($dlA.sourceField) }
                $dlSourceFields += $dlSfs
            }
            foreach ($attr in $dhQidm.attributes) {
                if ($attr.rule -and $attr.rule.function) { continue }
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($sf in $sfs) {
                    if ($systemSourceFields -contains $sf) { continue }
                    if ($dlSourceFields -contains $sf) { continue }
                    if ($sf -match 'DH$') { $hasDhSuffix = $true }
                    else { $dhNonSuffixed += $sf }
                }
            }
            if (-not $hasDhSuffix) {
                Write-Limitation "$entity : DL + DH QIDMs on single form without DH-suffix fieldIds -- known platform constraint (AP #14 / LIMITATION #25)"
            } else {
                Write-Pass "$entity : DH QIDM uses DH-suffix fieldIds (AP #14)"; Inc-Pass
                if ($dhNonSuffixed.Count -gt 0) {
                    Write-Warn "$entity : DH QIDM has $($dhNonSuffixed.Count) non-suffixed sourceField(s): $($dhNonSuffixed -join ', ') -- all DH user fields need DH suffix"
                    Write-Host "    [FIX] In build script: rename DH sourceFields to DH-suffix variants (e.g. NameFirst->NameFirstDH, BirthDate->BirthDateDH) and update form fieldIds to match" -ForegroundColor Cyan
                }
            }
            # Check DL QIDM doesn't accidentally use DH-suffix fields
            foreach ($attr in $dlQidm.attributes) {
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($sf in $sfs) {
                    if ($sf -match 'DH$') {
                        Write-Warn "$entity : DL QIDM attr '$($attr.name)' uses DH-suffix sourceField '$sf' -- DL should use base fieldIds, not DH variants"
                        Write-Host "    [FIX] In build script: change DL QIDM attr '$($attr.name)' sourceField from '$sf' to '$($sf -replace 'DH$','')' (remove DH suffix)" -ForegroundColor Cyan
                    }
                }
            }
        }
    }

    # LIMITATION #2 check: multiple QIDMs with same (targetEntity, query)
    $queryGroups = $eqidms | Group-Object -Property query
    foreach ($qg in $queryGroups) {
        if ($qg.Count -gt 1) {
            Write-Fail "LIMITATION #2: $($qg.Count) QIDMs share ($entity, $($qg.Name)). Only 1 will be evaluated."
            foreach ($dup in $qg.Group) { Write-Host "         $($dup.name)" -ForegroundColor Red }
        }
    }

    # Cross-QIDM duplicate keyReference check (across QIDMs for same entity)
    if ($eqidms.Count -gt 1) {
        $allKeyRefs = @{}
        foreach ($q in $eqidms) {
            if (-not $q.combinations) { continue }
            foreach ($combo in $q.combinations) {
                if ($combo.keyReference) {
                    if ($allKeyRefs.ContainsKey($combo.keyReference)) {
                        $allKeyRefs[$combo.keyReference] += $q.name
                    } else {
                        $allKeyRefs[$combo.keyReference] = @($q.name)
                    }
                }
            }
        }
        foreach ($kr in $allKeyRefs.Keys) {
            if ($allKeyRefs[$kr].Count -gt 1) {
                $qNames = ($allKeyRefs[$kr] | Sort-Object -Unique) -join ', '
                Write-Warn "$entity : keyReference '$kr' appears in multiple QIDMs: $qNames -- may cause routing confusion"
                Write-Host "    [FIX] In build script: rename keyReference '$kr' to be unique per QIDM (e.g. append DL/DH suffix to distinguish)" -ForegroundColor Cyan
            }
        }
    }

    # LIMITATION #28: multi-QIF + codeTypeProvider breaks reverse-lookup
    if ($entityQifCount -gt 1 -and $allFieldProps.ContainsKey($entity)) {
        foreach ($fid in $allFieldProps[$entity].Keys) {
            $fp = $allFieldProps[$entity][$fid]
            if ($fp.codeTypeProvider) {
                Write-Fail "LIMITATION #28: $entity has $entityQifCount QIFs + field '$fid' uses codeTypeProvider='$($fp.codeTypeProvider)' -- reverse-lookup broken on multi-QIF entities"
                break
            }
        }
    }

    # LIMITATION #24: queriesToDeselect needed when DL+DH share a single QIF
    if ($entityQifCount -eq 1 -and $eqidms.Count -gt 1) {
        $hasDLQuery = $false; $hasDHQuery = $false
        foreach ($q in $eqidms) {
            if ($q.query -eq 'DriverLicenseQuery') { $hasDLQuery = $true }
            if ($q.query -eq 'DriverHistoryQuery') { $hasDHQuery = $true }
        }
        if ($hasDLQuery -and $hasDHQuery) {
            $hasDeselect = $false
            foreach ($q in $eqidms) {
                if ($q.queriesToDeselect -and $q.queriesToDeselect.Count -gt 0) { $hasDeselect = $true; break }
            }
            if (-not $hasDeselect) {
                Write-Limitation "$entity : DL + DH on 1 QIF but none have queriesToDeselect -- checkbox toggling may not deselect (LIMITATION #24)"
            }
        }
    }

    if ($entityQifCount -eq 0) {
        Write-Fail "$entity : $($eqidms.Count) QIDMs but 0 QIFs -- queries have no form to render"
    } else {
        Write-Pass "$entity : $($eqidms.Count) QIDMs, $entityQifCount QIF(s)"; Inc-Pass
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5: AUTH, QMF, RESULTS
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 5: Auth / QMF / Results ===" -ForegroundColor Cyan

foreach ($bundle in $providerBundles) {
    $authAll = @($bundle.configurations | Where-Object { $_.type -eq "AUTHENTICATION" })
    $qmfAll = @($bundle.configurations | Where-Object { $_.type -eq "QUERYMESSAGEFORMAT" })
    $resultsAll = @($bundle.configurations | Where-Object { $_.type -eq "QUERYRESULTDATAMAPPING" })
    if ($authAll.Count -gt 1) { Write-Fail "Bundle '$($bundle.name)' has $($authAll.Count) AUTHENTICATION configs -- expected exactly 1" }
    if ($qmfAll.Count -gt 1) { Write-Fail "Bundle '$($bundle.name)' has $($qmfAll.Count) QUERYMESSAGEFORMAT configs -- expected exactly 1" }
    if ($resultsAll.Count -gt 1) { Write-Fail "Bundle '$($bundle.name)' has $($resultsAll.Count) QUERYRESULTDATAMAPPING configs -- expected exactly 1" }
    $auth = if ($authAll.Count -gt 0) { $authAll[0] } else { $null }
    $qmf = if ($qmfAll.Count -gt 0) { $qmfAll[0] } else { $null }
    $results = if ($resultsAll.Count -gt 0) { $resultsAll[0] } else { $null }

    if (-not $auth) { Write-Fail "Bundle '$($bundle.name)' missing AUTHENTICATION config" }
    else {
        Write-Pass "AUTHENTICATION present"; Inc-Pass
        if ($auth.handlerFunction -and $auth.handlerFunction -ne 'CommsysOriAuthenticationHandler') {
            Write-Warn "AUTHENTICATION '$($auth.name)' handlerFunction='$($auth.handlerFunction)' -- expected 'CommsysOriAuthenticationHandler'"
            Write-Host "    [FIX] In build script: change AUTH handlerFunction from '$($auth.handlerFunction)' to 'CommsysOriAuthenticationHandler'" -ForegroundColor Cyan
        }
        if ($auth.attributes) {
            $hasDexHandler = $false
            $hasORI = $false
            $hasMnemonic = $false
            foreach ($attr in $auth.attributes) {
                if ($attr.rule -and $attr.rule.function -eq 'CommsysGetDexStateUserIdRuleHandler') {
                    $hasDexHandler = $true
                    if (-not $attr.rule.arguments -or -not ($attr.rule.arguments -is [System.Array]) -or $attr.rule.arguments.Count -eq 0) {
                        Write-Warn "AUTH '$($auth.name)' attr '$($attr.name)' CommsysGetDexStateUserIdRuleHandler missing arguments -- needs @('true')"
                        Write-Host "    [FIX] In build script: add arguments=@('true') to the CommsysGetDexStateUserIdRuleHandler rule on AUTH attr '$($attr.name)'" -ForegroundColor Cyan
                    } elseif ($attr.rule.arguments[0] -ne 'true') {
                        Write-Warn "AUTH '$($auth.name)' attr '$($attr.name)' CommsysGetDexStateUserIdRuleHandler arguments[0]='$($attr.rule.arguments[0])' -- expected 'true'"
                        Write-Host "    [FIX] In build script: change AUTH DexStateUserId arguments[0] from '$($attr.rule.arguments[0])' to 'true'" -ForegroundColor Cyan
                    }
                }
                if ($attr.name -eq 'ORI' -or $attr.targetField -eq 'ORI') { $hasORI = $true }
                if ($attr.name -eq 'Mnemonic' -or $attr.targetField -eq 'Mnemonic') { $hasMnemonic = $true }
            }
            if (-not $hasDexHandler) {
                Write-Warn "AUTH '$($auth.name)' missing CommsysGetDexStateUserIdRuleHandler on UserName attribute"
                Write-Host "    [FIX] In build script: add a UserName attribute with rule={function:'CommsysGetDexStateUserIdRuleHandler', arguments:['true']} to AUTH config" -ForegroundColor Cyan
            }
            if (-not $hasORI) { Write-Fail "AUTH '$($auth.name)' missing ORI attribute -- auth will fail on every query" }
            if (-not $hasMnemonic) { Write-Fail "AUTH '$($auth.name)' missing Mnemonic attribute -- auth will fail on every query" }
        } else {
            Write-Fail "AUTH '$($auth.name)' missing attributes array -- auth will fail on every query (no ORI/Mnemonic)"
        }
        if ($auth.combinations) {
            foreach ($authCombo in $auth.combinations) {
                if (-not $authCombo.keyReference) {
                    Write-Warn "AUTH '$($auth.name)' combination missing keyReference"
                    Write-Host "    [FIX] In build script: add keyReference='AUTH' (or unique string) to AUTH combination" -ForegroundColor Cyan
                }
                if ($authCombo.requirements -and $authCombo.requirements.set) {
                    if ($authCombo.requirements.set -notcontains 'ORI') {
                        Write-Warn "AUTH '$($auth.name)' combo set[] missing 'ORI' -- auth may not fire"
                        Write-Host "    [FIX] In build script: add 'ORI' to AUTH combo requirements.set[] array" -ForegroundColor Cyan
                    }
                    if ($authCombo.requirements.set -notcontains 'Mnemonic') {
                        Write-Warn "AUTH '$($auth.name)' combo set[] missing 'Mnemonic' -- auth may not fire"
                        Write-Host "    [FIX] In build script: add 'Mnemonic' to AUTH combo requirements.set[] array" -ForegroundColor Cyan
                    }
                }
            }
        } else {
            Write-Warn "AUTH '$($auth.name)' has no combinations -- auth pattern may not fire"
            Write-Host "    [FIX] In build script: add combinations array to AUTH with at least one combo containing requirements.set=['ORI','Mnemonic']" -ForegroundColor Cyan
        }
        if ($auth.signInRequired -ne $false -and $auth.signInRequired -ne $null) {
            Write-Warn "AUTH '$($auth.name)' signInRequired='$($auth.signInRequired)' -- expected false"
            Write-Host "    [FIX] In build script: set signInRequired=`$false on AUTH config" -ForegroundColor Cyan
        }
        if ($auth.deviceRegistrationOptional -ne $false -and $auth.deviceRegistrationOptional -ne $null) {
            Write-Warn "AUTH '$($auth.name)' deviceRegistrationOptional='$($auth.deviceRegistrationOptional)' -- expected false"
            Write-Host "    [FIX] In build script: set deviceRegistrationOptional=`$false on AUTH config" -ForegroundColor Cyan
        }
    }

    if (-not $qmf) { Write-Fail "Bundle '$($bundle.name)' missing QUERYMESSAGEFORMAT config" }
    else {
        Write-Pass "QUERYMESSAGEFORMAT present"; Inc-Pass
        if ($qmf.handlerFunction -and $qmf.handlerFunction -ne 'CommsysWsiOutgoingMessageHandler') {
            Write-Warn "QMF '$($qmf.name)' handlerFunction='$($qmf.handlerFunction)' -- expected 'CommsysWsiOutgoingMessageHandler'"
            Write-Host "    [FIX] In build script: change QMF handlerFunction from '$($qmf.handlerFunction)' to 'CommsysWsiOutgoingMessageHandler'" -ForegroundColor Cyan
        }
        if (-not $qmf.authenticationParent) {
            Write-Warn "QMF '$($qmf.name)' missing authenticationParent -- expected 'LawEnforcementTransaction'"
            Write-Host "    [FIX] In build script: add authenticationParent='LawEnforcementTransaction' to QMF config" -ForegroundColor Cyan
        } elseif ($qmf.authenticationParent -ne 'LawEnforcementTransaction') {
            Write-Warn "QMF '$($qmf.name)' authenticationParent='$($qmf.authenticationParent)' -- expected 'LawEnforcementTransaction'"
            Write-Host "    [FIX] In build script: change authenticationParent from '$($qmf.authenticationParent)' to 'LawEnforcementTransaction'" -ForegroundColor Cyan
        }
        if (-not $qmf.payloadParent) {
            Write-Warn "QMF '$($qmf.name)' missing payloadParent -- expected 'LawEnforcementTransaction'"
            Write-Host "    [FIX] In build script: add payloadParent='LawEnforcementTransaction' to QMF config" -ForegroundColor Cyan
        } elseif ($qmf.payloadParent -ne 'LawEnforcementTransaction') {
            Write-Warn "QMF '$($qmf.name)' payloadParent='$($qmf.payloadParent)' -- expected 'LawEnforcementTransaction'"
            Write-Host "    [FIX] In build script: change payloadParent from '$($qmf.payloadParent)' to 'LawEnforcementTransaction'" -ForegroundColor Cyan
        }
    }

    if (-not $results) { Write-Fail "Bundle '$($bundle.name)' missing QUERYRESULTDATAMAPPING config" }
    else {
        Write-Pass "QUERYRESULTDATAMAPPING present"; Inc-Pass
        if ($results.handlerFunction -and $results.handlerFunction -ne 'CommsysResultsHandler') {
            Write-Warn "QRDM '$($results.name)' handlerFunction='$($results.handlerFunction)' -- expected 'CommsysResultsHandler'"
            Write-Host "    [FIX] In build script: change QRDM handlerFunction from '$($results.handlerFunction)' to 'CommsysResultsHandler'" -ForegroundColor Cyan
        }
    }
}

# RMS bundle checks
if ($rmsBundle) {
    if (-not $rmsBundle.provider) {
        Write-Warn "RMS bundle missing 'provider' property -- expected 'RMS'"
        Write-Host "    [FIX] In build script: add provider='RMS' to the RMS bundle" -ForegroundColor Cyan
    } elseif ($rmsBundle.provider -ne 'RMS') {
        Write-Warn "RMS bundle provider='$($rmsBundle.provider)' -- expected 'RMS'"
        Write-Host "    [FIX] In build script: change RMS bundle provider from '$($rmsBundle.provider)' to 'RMS'" -ForegroundColor Cyan
    }
    # Check for unknown config types in RMS bundle
    $knownRmsTypes = @('QUERYINPUTDATAMAPPING','AUTHENTICATION','QUERYMESSAGEFORMAT','QUERYRESULTDATAMAPPING','QUERYRESULTSLAYOUT')
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -and $knownRmsTypes -notcontains $cfg.type) {
            Write-Warn "RMS bundle config '$($cfg.name)' has unknown type '$($cfg.type)' -- may be silently ignored"
            Write-Host "    [FIX] Change config type to one of: QUERYINPUTDATAMAPPING, AUTHENTICATION, QUERYMESSAGEFORMAT, QUERYRESULTDATAMAPPING, QUERYRESULTSLAYOUT" -ForegroundColor Cyan
        }
    }
    $rmsAuth = $rmsBundle.configurations | Where-Object { $_.type -eq "AUTHENTICATION" }
    $rmsQmf = $rmsBundle.configurations | Where-Object { $_.type -eq "QUERYMESSAGEFORMAT" }
    $rmsResults = $rmsBundle.configurations | Where-Object { $_.type -eq "QUERYRESULTDATAMAPPING" }
    $rmsLayout = $rmsBundle.configurations | Where-Object { $_.type -eq "QUERYRESULTSLAYOUT" }

    if ($rmsAuth) {
        Write-Pass "RMS AUTHENTICATION present"; Inc-Pass
        if ($rmsAuth.handlerFunction -and $rmsAuth.handlerFunction -ne 'RestAuthenticationHandler') {
            Write-Warn "RMS AUTH handlerFunction='$($rmsAuth.handlerFunction)' -- expected 'RestAuthenticationHandler'"
            Write-Host "    [FIX] In build script: change RMS AUTH handlerFunction from '$($rmsAuth.handlerFunction)' to 'RestAuthenticationHandler'" -ForegroundColor Cyan
        }
    }
    else { Write-Fail "RMS bundle missing AUTHENTICATION config" }
    if ($rmsQmf) {
        Write-Pass "RMS QUERYMESSAGEFORMAT present"; Inc-Pass
        if ($rmsQmf.handlerFunction -and $rmsQmf.handlerFunction -ne 'RestRequestHandler') {
            Write-Warn "RMS QMF handlerFunction='$($rmsQmf.handlerFunction)' -- expected 'RestRequestHandler'"
            Write-Host "    [FIX] In build script: change RMS QMF handlerFunction from '$($rmsQmf.handlerFunction)' to 'RestRequestHandler'" -ForegroundColor Cyan
        }
    }
    else { Write-Fail "RMS bundle missing QUERYMESSAGEFORMAT config" }
    if ($rmsResults) {
        Write-Pass "RMS QUERYRESULTDATAMAPPING present"; Inc-Pass
        if ($rmsResults.handlerFunction -and $rmsResults.handlerFunction -ne 'RmsRestResultsHandler') {
            Write-Warn "RMS QRDM handlerFunction='$($rmsResults.handlerFunction)' -- expected 'RmsRestResultsHandler'"
            Write-Host "    [FIX] In build script: change RMS QRDM handlerFunction from '$($rmsResults.handlerFunction)' to 'RmsRestResultsHandler'" -ForegroundColor Cyan
        }
    }
    else { Write-Fail "RMS bundle missing QUERYRESULTDATAMAPPING config" }
    if ($rmsLayout) {
        Write-Pass "RMS QUERYRESULTSLAYOUT present"; Inc-Pass
        if ($rmsLayout.handlerFunction -and $rmsLayout.handlerFunction -ne 'QueryResultsLayoutHandler') {
            Write-Warn "RMS QRSL handlerFunction='$($rmsLayout.handlerFunction)' -- expected 'QueryResultsLayoutHandler'"
            Write-Host "    [FIX] In build script: change RMS QRSL handlerFunction from '$($rmsLayout.handlerFunction)' to 'QueryResultsLayoutHandler'" -ForegroundColor Cyan
        }
    }
    else { Write-Fail "RMS bundle missing QUERYRESULTSLAYOUT config" }

    # ParallelQuery handler (optional -- HIDLE provides parallelQueryHandler on RMS bundle)
    if ($rmsBundle.ParallelQuery -and $rmsBundle.ParallelQuery.function) {
        if ($rmsBundle.ParallelQuery.function -ne 'parallelQueryHandler') {
            Write-Warn "RMS bundle ParallelQuery.function='$($rmsBundle.ParallelQuery.function)' -- expected 'parallelQueryHandler'"
            Write-Host "    [FIX] In build script: change RMS ParallelQuery.function from '$($rmsBundle.ParallelQuery.function)' to 'parallelQueryHandler'" -ForegroundColor Cyan
        } else {
            Write-Pass "RMS bundle ParallelQuery.function='parallelQueryHandler'"; Inc-Pass
        }
    } else {
        Write-Info "RMS bundle has no ParallelQuery.function -- Person+Vehicle RMS queries will run sequentially (ok if not configured)"
    }

    # Check RMS bundle-level ruleHandlers (wrong format if present as array instead of structured props)
    $rmsBundleProps = $rmsBundle | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    if ($rmsBundleProps -contains 'ruleHandlers') {
        Write-Warn "RMS bundle has 'ruleHandlers' property -- expected structured handler properties (PayloadHandler, ParallelQuery, etc.), not ruleHandlers array"
        Write-Host "    [FIX] In build script: remove 'ruleHandlers' array from RMS bundle -- use individual handler properties (PayloadHandler, ParallelQuery) from HIDLE.json template" -ForegroundColor Cyan
    }

    $rmsQidms = @($rmsBundle.configurations | Where-Object { $_.type -eq "QUERYINPUTDATAMAPPING" })
    if ($rmsQidms.Count -eq 0) {
        Write-Fail "RMS bundle has no QUERYINPUTDATAMAPPING configs (no RMS search queries)"
    } else {
        Write-Pass "RMS bundle has $($rmsQidms.Count) QIDM(s)"; Inc-Pass
    }

    # RMS QIDMs should have autoSelect=true (RMS fires alongside CommSys automatically)
    foreach ($rq in $rmsQidms) {
        if ($rq.autoSelect -ne $true) {
            Write-Warn "RMS QIDM '$($rq.name)' autoSelect is not true -- RMS queries should auto-fire with CommSys"
            Write-Host "    [FIX] In build script: set autoSelect=`$true on RMS QIDM '$($rq.name)'" -ForegroundColor Cyan
        } else {
            Write-Pass "RMS QIDM '$($rq.name)' autoSelect=true"; Inc-Pass
        }
        if ($rq.handlerFunction -and $rq.handlerFunction -ne 'RmsRestPayloadHandler') {
            Write-Fail "RMS QIDM '$($rq.name)' handlerFunction='$($rq.handlerFunction)' -- must be 'RmsRestPayloadHandler'"
        }
        if ($rq.queryLabel -and $rq.queryLabel -ne 'RMS') {
            Write-Warn "RMS QIDM '$($rq.name)' queryLabel='$($rq.queryLabel)' -- expected 'RMS'"
            Write-Host "    [FIX] In build script: change RMS QIDM queryLabel from '$($rq.queryLabel)' to 'RMS'" -ForegroundColor Cyan
        } elseif (-not $rq.queryLabel) {
            Write-Warn "RMS QIDM '$($rq.name)' missing queryLabel -- expected 'RMS'"
            Write-Host "    [FIX] In build script: add queryLabel='RMS' to RMS QIDM '$($rq.name)'" -ForegroundColor Cyan
        }
    }

    # Dead HIDLE attrs that must not be in RMS bundle
    # Skip attrs/combos that are actively used by the provider's form fields
    $formHasSSN = $false
    if ($allFieldIds -and $allFieldIds.ContainsKey('Person')) {
        $formHasSSN = $allFieldIds['Person'].Contains('SocialSecurityNumber')
    }
    $hidleDeadVehicle = @('LicensePlateNumberOut','RegistrationStateOut','OwnerFirstName','OwnerLastName')
    $hidleDeadPerson = @('licenseNumberOOS','firstNameOOS','lastNameOOS','dateOfBirthOOS','sexOOS')
    $hidleDeadCombosPerson = @('driversLicenseNumberOOS','firstNameLastNameDriversLicenseNumberOOS','firstNameLastNameDateOfBirthOOS','firstNameLastNameOOS')
    if (-not $formHasSSN) {
        $hidleDeadPerson += 'socialSecurityNumber'
        $hidleDeadCombosPerson += 'firstNameLastNameSocialSecurityNumber'
    }
    $hidleDeadCombosVehicle = @('licensePlateOutAndState','OwnerFirstAndLastName')
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        $deadList = $null
        $deadCombos = $null
        if ($cfg.targetEntity -eq 'Vehicle') { $deadList = $hidleDeadVehicle; $deadCombos = $hidleDeadCombosVehicle }
        if ($cfg.targetEntity -eq 'Person') { $deadList = $hidleDeadPerson; $deadCombos = $hidleDeadCombosPerson }
        if ($deadList) {
            foreach ($attr in $cfg.attributes) {
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($sf in $sfs) {
                    if ($deadList -contains $sf) {
                        Write-Warn "RMS $($cfg.targetEntity) QIDM '$($cfg.name)' has dead HIDLE sourceField '$sf' -- must be removed"
                        Write-Host "    [FIX] In build script: remove attribute with sourceField='$sf' from RMS $($cfg.targetEntity) QIDM and remove '$sf' from all combo set[]/any[] arrays" -ForegroundColor Cyan
                    }
                }
            }
        }
        if ($deadCombos) {
            foreach ($combo in $cfg.combinations) {
                if ($combo.keyReference -and $deadCombos -contains $combo.keyReference) {
                    Write-Warn "RMS $($cfg.targetEntity) QIDM '$($cfg.name)' has dead HIDLE combo '$($combo.keyReference)' -- must be removed"
                    Write-Host "    [FIX] In build script: remove combo '$($combo.keyReference)' from RMS $($cfg.targetEntity) QIDM '$($cfg.name)'" -ForegroundColor Cyan
                }
            }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6: COMBINATION QUERY SIMULATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n=== PHASE 6: Query Simulation ===" -ForegroundColor Cyan

foreach ($q in $qidms) {
    $entity = $q.targetEntity
    $entityFields = $null
    if ($allFieldIds.ContainsKey($entity)) { $entityFields = $allFieldIds[$entity] }

    foreach ($combo in $q.combinations) {
        $keyRef = $combo.keyReference
        if (-not $keyRef) { continue }

        $setFields = @()
        if ($combo.requirements -and $combo.requirements.set) {
            $setFields = $combo.requirements.set
        }

        # Simulate: if all set[] fields are populated, this combo fires
        $allSetResolvable = $true
        $unresolvable = @()
        foreach ($sf in $setFields) {
            if ($entityFields -and -not $entityFields.Contains($sf)) {
                if ($systemSourceFields -notcontains $sf) {
                    $allSetResolvable = $false
                    $unresolvable += $sf
                }
            }
        }

        # Check any[] fields resolvable
        $anyFields = @()
        if ($combo.requirements -and $combo.requirements.any) {
            $anyFields = $combo.requirements.any
        }
        $anyUnresolvable = @()
        foreach ($af in $anyFields) {
            if ($entityFields -and -not $entityFields.Contains($af)) {
                if ($systemSourceFields -notcontains $af) {
                    $anyUnresolvable += $af
                }
            }
        }

        if ($allSetResolvable -and $anyUnresolvable.Count -eq 0) {
            Write-Pass "QIDM '$($q.name)' combo '$keyRef': all set[]/any[] fields resolvable"; Inc-Pass
        } elseif (-not $allSetResolvable) {
            Write-Fail "QIDM '$($q.name)' combo '$keyRef': unresolvable set[] fields: $($unresolvable -join ', ')"
        }
        if ($anyUnresolvable.Count -gt 0) {
            Write-Warn "QIDM '$($q.name)' combo '$keyRef': unresolvable any[] fields: $($anyUnresolvable -join ', ')"
            Write-Host "    [FIX] Add form fields for: $($anyUnresolvable -join ', ') to the $entity QIF, or remove them from combo '$keyRef' any[]" -ForegroundColor Cyan
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n" -NoNewline
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
$resultLine = "  RESULTS: $script:passCount PASS / $script:failCount FAIL / $script:warnCount WARN"
if ($script:limitCount -gt 0) { $resultLine += " / $script:limitCount LIMITATION" }
Write-Host $resultLine -ForegroundColor $(if ($script:failCount -gt 0) { "Red" } elseif ($script:warnCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan

if ($script:failCount -gt 0) {
    Write-Host "`n  FIX all FAIL items before importing." -ForegroundColor Red
    exit 1
} elseif ($script:warnCount -gt 0) {
    Write-Host "`n  Review WARN items -- they may cause runtime issues." -ForegroundColor Yellow
    exit 0
} else {
    if ($script:limitCount -gt 0) { Write-Host "`n  $script:limitCount known limitation(s) -- documented, no action needed." -ForegroundColor DarkYellow }
    Write-Host "`n  Ready for import." -ForegroundColor Green
    exit 0
}
