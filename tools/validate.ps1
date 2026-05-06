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

$entitiesBundle = $null
$providerBundles = @()
$rmsBundle = $null

foreach ($b in $json.bundles) {
    if (-not $b.name) { Write-Fail "Bundle missing 'name' property"; continue }
    if (-not $b.type) { Write-Fail "Bundle '$($b.name)' missing 'type' property"; continue }
    if ($b.type -ne 'BUNDLE') { Write-Fail "Bundle '$($b.name)' type='$($b.type)' -- must be 'BUNDLE' (confirmed import failure)" }
    if (-not $b.provider) { Write-Warn "Bundle '$($b.name)' missing 'provider' property" }

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
if (-not $rmsBundle) { Write-Warn "No RMS bundle (optional but expected)" }

# Bundle count (exactly 3: ENTITIES + Provider + RMS)
if ($json.bundles.Count -lt 3) {
    Write-Warn "Only $($json.bundles.Count) bundles -- expected 3 (ENTITIES + Provider + RMS)"
} elseif ($json.bundles.Count -gt 3) {
    Write-Warn "$($json.bundles.Count) bundles -- expected exactly 3 (ENTITIES + Provider + RMS)"
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
            } else {
                foreach ($cadEnt in $entitiesBundle.order.CAD_DISPATCH) {
                    if ($entitiesBundle.order.default -notcontains $cadEnt) {
                        Write-Warn "ENTITIES order CAD_DISPATCH lists '$cadEnt' not in default order array"
                    }
                }
            }
            if (-not $entitiesBundle.order.FIRST_RESPONDER) {
                Write-Warn "ENTITIES order missing 'FIRST_RESPONDER' key -- first responder view will use default order"
            } else {
                foreach ($frEnt in $entitiesBundle.order.FIRST_RESPONDER) {
                    if ($entitiesBundle.order.default -notcontains $frEnt) {
                        Write-Warn "ENTITIES order FIRST_RESPONDER lists '$frEnt' not in default order array"
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
    }

    foreach ($cfg in $entitiesBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTFORM") {
            if ($cfg.type -eq "QUERYINPUTDATAMAPPING") {
                Write-Fail "ENTITIES bundle contains QIDM '$($cfg.name)' -- QIDMs belong in provider bundle, not ENTITIES (will be invisible to validation)"
            } elseif ($cfg.type -eq "AUTHENTICATION" -or $cfg.type -eq "QUERYMESSAGEFORMAT" -or $cfg.type -eq "QUERYRESULTDATAMAPPING") {
                Write-Fail "ENTITIES bundle contains $($cfg.type) '$($cfg.name)' -- belongs in provider or RMS bundle"
            } else {
                Write-Warn "ENTITIES bundle contains non-QIF: $($cfg.name) (type=$($cfg.type))"
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
        }
        if ($cfg.combinations) {
            Write-Fail "QIF '$($cfg.name)' has 'combinations' array -- combinations belong on QIDMs, not QIFs"
        }
        if ($cfg.providerType -eq 'Commsys') {
            Write-Warn "QIF '$($cfg.name)' has providerType='Commsys' -- QIF should not have CommSys providerType (confirmed AZ v2.0)"
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
                        if ($node.props.initialValue -ne 'PC') {
                            Write-Warn "QIF '$($cfg.name)' PlateType initialValue='$($node.props.initialValue)' -- standard is 'PC'"
                        } else {
                            Write-Pass "QIF '$($cfg.name)' PlateType initialValue='PC'"; Inc-Pass
                        }
                    }
                    if ($node.props.fieldId -match '^(LicensePlateYear|licensePlateYear|PlateYear)$') {
                        if (-not $node.props.initialValue) {
                            Write-Warn "QIF '$($cfg.name)' '$($node.props.fieldId)' missing initialValue -- standard is current year"
                        }
                    }
                    if ($node.props.fieldId -eq 'ImageIndicator') {
                        $expectedImgInit = if ($cfg.targetEntity -eq 'Person') { 'Y' } else { 'N' }
                        if ($node.props.initialValue -ne $expectedImgInit) {
                            Write-Warn "QIF '$($cfg.name)' ImageIndicator initialValue='$($node.props.initialValue)' -- expected '$expectedImgInit' for $($cfg.targetEntity)"
                        } else {
                            Write-Pass "QIF '$($cfg.name)' ImageIndicator default='$expectedImgInit' for $($cfg.targetEntity)"; Inc-Pass
                        }
                        if ($node.type.resolvedName -and $node.type.resolvedName -ne 'FormSelect') {
                            Write-Warn "QIF '$($cfg.name)' ImageIndicator is $($node.type.resolvedName) -- should be FormSelect with YES_NO_UNKNOWN"
                        }
                    }
                    # AP #24: NCIC_FIREARM_MAKE on Vehicle form field
                    if ($node.props.codeTypeCategory -and $node.props.codeTypeCategory -match 'FIREARM' -and $cfg.targetEntity -eq 'Vehicle') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' uses codeTypeCategory='$($node.props.codeTypeCategory)' on Vehicle -- firearm makes only (AP #24)"
                    }
                    # AP #6: YES_NO should be YES_NO_UNKNOWN
                    if ($node.props.codeTypeCategory -eq 'YES_NO') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' codeTypeCategory='YES_NO' -- should be 'YES_NO_UNKNOWN' (AP #6: empty dropdown)"
                    }
                    # AP #7: NCIC_ARTICLE_TYPE requires CA_CLETS source
                    if ($node.props.codeTypeCategory -eq 'NCIC_ARTICLE_TYPE' -and $node.props.codeTypeSource -eq 'NCIC') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' NCIC_ARTICLE_TYPE with codeTypeSource='NCIC' -- empty dropdown, use 'CA_CLETS' (AP #7)"
                    }
                    # AP #13: NIBRS_RACE requires NIBRS source
                    if ($node.props.codeTypeCategory -eq 'NIBRS_RACE' -and $node.props.codeTypeSource -eq 'NCIC') {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' NIBRS_RACE with codeTypeSource='NCIC' -- empty dropdown, use 'NIBRS' (AP #13)"
                    }
                    # Generic: categories that don't populate under NCIC codeTypeSource
                    if ($node.props.codeTypeSource -eq 'NCIC' -and $node.props.codeTypeCategory) {
                        $nonNcicCategories = @('NIBRS_SEX','NIBRS_ETHNICITY','VEHICLE_BODY_STYLE','VEHICLE_TYPE')
                        if ($nonNcicCategories -contains $node.props.codeTypeCategory) {
                            Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' codeTypeCategory='$($node.props.codeTypeCategory)' with codeTypeSource='NCIC' -- empty dropdown, needs different source"
                        }
                    }
                    # STATE field visibility pattern
                    if ($node.props.attributeTypeId -eq 'STATE' -and $node.props.hidden -ne $true) {
                        if ($node.type.resolvedName -eq 'FormInput') {
                            Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' visible FormInput with attributeTypeId='STATE' -- use FormSelect with codeTypeProvider='NCIC' or hide for outbound-only"
                        }
                    }
                    # Visible Attention FormInput: only flag if a QIDM auto-fills it via handler
                    if ($node.props.fieldId -eq 'Attention' -and $node.props.hidden -ne $true) {
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
                            }
                        }
                    }
                    # AP #3: attributeTypeId='RACE' on form field without codeTypeProvider (sends numeric ID, not code)
                    if ($node.props.attributeTypeId -eq 'RACE' -and -not $node.props.codeTypeProvider) {
                        Write-Warn "QIF '$($cfg.name)' field '$($node.props.fieldId)' has attributeTypeId='RACE' without codeTypeProvider -- sends numeric ID, use codeTypeCategory='NIBRS_RACE' or add codeTypeProvider (AP #3)"
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
                        }
                        if ($node.props.codeTypeProvider -ne 'NIBRS') {
                            Write-Warn "QIF '$($cfg.name)' SexCode field missing codeTypeProvider='NIBRS' -- dropdown shows wrong values"
                        }
                        if ($node.props.codeTypeCategory) {
                            Write-Warn "QIF '$($cfg.name)' SexCode field has codeTypeCategory='$($node.props.codeTypeCategory)' -- use attributeTypeId=SEX + codeTypeProvider=NIBRS instead"
                        }
                    }
                    # LicensePlateNumber fieldId check — canonical name is licensePlateNumber (no In/Out suffix)
                    if ($node.props.fieldId -match '^LicensePlateNumber(In|Out)$' -and $cfg.targetEntity -eq 'Vehicle') {
                        Write-Warn "QIF '$($cfg.name)' uses deprecated fieldId='$($node.props.fieldId)' -- use 'licensePlateNumber' (no In/Out suffix)"
                    }
                    # PlateYear current year check
                    if ($node.props.fieldId -match '^(LicensePlateYear|licensePlateYear|PlateYear)$' -and $node.props.initialValue) {
                        $currentYear = (Get-Date).Year.ToString()
                        if ($node.props.initialValue -ne $currentYear) {
                            Write-Warn "QIF '$($cfg.name)' '$($node.props.fieldId)' initialValue='$($node.props.initialValue)' -- current year is $currentYear"
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
                    }
                    if ($formRoot.props.layout -ne 'page') {
                        Write-Warn "QIF '$($cfg.name)' layout '$layoutName' FORM_ROOT layout='$($formRoot.props.layout)' -- expected 'page'"
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
                }
            }
        }

        # ImageIndicator: only WARN if a QIDM maps it but form doesn't have it
        if (-not $fids.Contains('ImageIndicator')) {
            if ($entitiesWithImageIndicatorQidm.ContainsKey($entity)) {
                Write-Warn "$entity missing fieldId 'ImageIndicator' -- QIDM maps it but form has no field"
            }
        }

        if ($entity -eq 'Vehicle') {
            if (-not $fids.Contains('PlateYear') -and -not $fids.Contains('LicensePlateYear') -and -not $fids.Contains('licensePlateYear')) {
                Write-Warn "Vehicle missing PlateYear/LicensePlateYear -- standard default is current year"
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
            'StaticValueRuleHandler')
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule -and $attr.rule.function -and $attr.rule.function -is [string]) {
                if ($knownHandlers -notcontains $attr.rule.function) {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' rule.function='$($attr.rule.function)' -- not in known handlers list (typo?)"
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
            Write-Warn "QIDM '$($cfg.name)' has $($phantomFields.Count) sourceField(s) not found in $entity QIF:"
            foreach ($pf in $phantomFields) { Write-Host "         $pf" -ForegroundColor Yellow }
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
                }
                if ($combo.requirements -and $combo.requirements.set) {
                    foreach ($reqField in $combo.requirements.set) {
                        if ($entityFields -and -not $entityFields.Contains($reqField)) {
                            if ($systemSourceFields -notcontains $reqField) {
                                Write-Warn "QIDM '$($cfg.name)' combo '$($combo.keyReference)' set[] references '$reqField' not in QIF fieldIds"
                            }
                        }
                    }
                }
                if ($combo.requirements -and $combo.requirements.any) {
                    foreach ($reqField in $combo.requirements.any) {
                        if ($entityFields -and -not $entityFields.Contains($reqField)) {
                            if ($systemSourceFields -notcontains $reqField) {
                                Write-Warn "QIDM '$($cfg.name)' combo '$($combo.keyReference)' any[] references '$reqField' not in QIF fieldIds"
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
                }
            }

            # CommSys combos must have state property ('In', 'Out', or 'In/Out')
            if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
                $validStates = @('In','Out','In/Out')
                foreach ($combo in $cfg.combinations) {
                    if (-not $combo.state) {
                        $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                        Write-Warn "QIDM '$($cfg.name)' combo '$comboId' missing state property -- CommSys combos need state='In', 'Out', or 'In/Out'"
                    } elseif ($validStates -notcontains $combo.state) {
                        $comboId = if ($combo.keyReference) { $combo.keyReference } else { "(unnamed)" }
                        Write-Warn "QIDM '$($cfg.name)' combo '$comboId' state='$($combo.state)' -- must be 'In', 'Out', or 'In/Out'"
                    }
                }
            }

            # Check CommSys combos have primaryFieldReference
            if ($cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
                $missingPfr = @($cfg.combinations | Where-Object { -not $_.primaryFieldReference })
                if ($missingPfr.Count -gt 0) {
                    Write-Warn "QIDM '$($cfg.name)' has $($missingPfr.Count) combo(s) missing 'primaryFieldReference'"
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
                    }
                }
            }

            # G-16: Combination ordering -- operational priority determines order, not set[] count
            if ($cfg.combinations.Count -gt 1) {
                $prevSetCount = [int]::MaxValue
                $orderOk = $true
                foreach ($combo in $cfg.combinations) {
                    $setCount = 0
                    if ($combo.requirements -and $combo.requirements.set) { $setCount = $combo.requirements.set.Count }
                    if ($setCount -gt $prevSetCount) { $orderOk = $false; break }
                    $prevSetCount = $setCount
                }
                if (-not $orderOk) {
                    Write-Limitation "QIDM '$($cfg.name)' combo order has fewer set[] fields before more -- verify operational priority is correct (first match fires)"
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
            }
        }
        if (-not $cfg.description) { Write-Warn "QIDM '$($cfg.name)' missing description property" }
        if (-not $cfg.providerType) { Write-Warn "QIDM '$($cfg.name)' missing providerType property" }
        elseif ($cfg.providerType -ne 'Commsys') { Write-Warn "QIDM '$($cfg.name)' providerType='$($cfg.providerType)' -- expected 'Commsys'" }

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
                }
                if ($cfg.queryLabel -match 'Query') {
                    Write-Info "QIDM '$($cfg.name)' queryLabel='$($cfg.queryLabel)' contains 'Query' -- label by search type not query name (AP #25)"
                }
                $badLabels = @('Vehicle','Person','NCIC','DMV','FCIC','NJCJIS','TLETS','LEMS','AZDPS','NYSPIN')
                if ($badLabels -contains $cfg.queryLabel) {
                    Write-Warn "QIDM '$($cfg.name)' queryLabel='$($cfg.queryLabel)' -- do not use entity or system names as labels (AP #25)"
                }
            } else {
                Write-Warn "QIDM '$($cfg.name)' missing queryLabel property"
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
                } elseif ($attr.rule.arguments[0] -ne 'true') {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysGetDexStateUserIdRuleHandler arguments[0]='$($attr.rule.arguments[0])' -- expected 'true'"
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

            # Check LicensePlateNumber sourceField — canonical name is licensePlateNumber (no In/Out suffix)
            foreach ($attr in $cfg.attributes) {
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($sf in $sfs) {
                    if ($sf -match '^LicensePlateNumber(In|Out)$') {
                        Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' sourceField='$sf' uses deprecated In/Out suffix -- use 'licensePlateNumber' instead"
                    }
                }
                # targetField should be XML element name (LicensePlateNumber), not form fieldId variant
                if ($attr.targetField -match '^LicensePlateNumber(In|Out)$') {
                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' targetField='$($attr.targetField)' -- XML element should be 'LicensePlateNumber' (targetField is XML name, not form fieldId)"
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
                        if ($attnInCombo) {
                            Write-Warn "QIDM '$($cfg.name)' Attention attr '$($attr.name)' in combo set[]/any[] -- auto-fill handler present, should not be in combos"
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
                                } elseif ($dateArgs[0] -ne 'yyyy-MM-dd') {
                                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysParseDateRuleHandler first argument='$($dateArgs[0])' -- expected 'yyyy-MM-dd'"
                                } elseif ($dateArgs[1] -notmatch '^[yMd\-/]+$') {
                                    Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' CommsysParseDateRuleHandler second argument='$($dateArgs[1])' -- does not look like a date format"
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
                    }
                }
            }
        }

        # Check AP #4: IgnoreUserValueRuleHandler (dead end)
        foreach ($attr in $cfg.attributes) {
            if ($attr.rule -and $attr.rule.function -eq 'IgnoreUserValueRuleHandler') {
                Write-Warn "QIDM '$($cfg.name)' attr '$($attr.name)' uses IgnoreUserValueRuleHandler -- DEAD END, does not substitute argument (AP #4)"
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

    # Check RMS Patch 3: Person QIDM should have registrationState attribute AND in combo any[]
    # Patch 4: Person uses singular 'registrationStateAttrId' (no ArrayWrapper), Vehicle uses plural 'registrationStateAttrIds' (WITH ArrayWrapper)
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if ($cfg.targetEntity -ne 'Person') { continue }
        $hasRegState = $false
        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'registrationStateAttrId' -or $attr.targetField -eq 'registrationStateAttrIds') {
                $hasRegState = $true
                if ($attr.targetField -eq 'registrationStateAttrIds') {
                    Write-Fail "RMS Person QIDM '$($cfg.name)' attr '$($attr.name)' targetField='registrationStateAttrIds' (plural) -- Person must use singular 'registrationStateAttrId' (Patch 4)"
                }
                if ($attr.rule -and $attr.rule.function -eq 'AttributeArrayWrapperRuleHandler') {
                    Write-Fail "RMS Person QIDM '$($cfg.name)' attr '$($attr.name)' has AttributeArrayWrapperRuleHandler on registrationState -- Person uses singular, no ArrayWrapper needed (Patch 4)"
                }
            }
        }
        if (-not $hasRegState) {
            Write-Warn "RMS Person QIDM '$($cfg.name)' missing registrationState attribute (Patch 3)"
        } else {
            Write-Pass "RMS Person QIDM '$($cfg.name)' has registrationState attr (Patch 3)"; Inc-Pass
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
                    Write-Warn "RMS Person QIDM '$($cfg.name)' combo '$comboId' missing 'RegistrationState' in any[] -- person search ignores state filter (Patch 3)"
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

    # Patch 1: RMS Vehicle QIDM should have RegistrationState in combo any[]
    # Patch 4/5: Vehicle uses plural 'registrationStateAttrIds' WITH AttributeArrayWrapperRuleHandler
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -ne "QUERYINPUTDATAMAPPING") { continue }
        if ($cfg.targetEntity -ne 'Vehicle') { continue }

        foreach ($attr in $cfg.attributes) {
            if ($attr.targetField -eq 'registrationStateAttrId') {
                Write-Warn "RMS Vehicle QIDM '$($cfg.name)' attr '$($attr.name)' targetField='registrationStateAttrId' (singular) -- Vehicle must use plural 'registrationStateAttrIds' (Patch 4)"
            }
            if ($attr.targetField -eq 'registrationStateAttrIds') {
                if (-not $attr.rule -or $attr.rule.function -ne 'AttributeArrayWrapperRuleHandler') {
                    Write-Warn "RMS Vehicle QIDM '$($cfg.name)' attr '$($attr.name)' registrationStateAttrIds missing AttributeArrayWrapperRuleHandler (Patch 5)"
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
            Write-Warn "RMS Vehicle QIDM '$($cfg.name)' no combo has 'RegistrationState' in any[] (Patch 1 -- plate search ignores state)"
        } else {
            Write-Pass "RMS Vehicle QIDM '$($cfg.name)' has RegistrationState in combo any[] (Patch 1)"; Inc-Pass
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
    if ($hasSeparateInOut -and $allFieldProps.ContainsKey($entity)) {
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
                                    Write-Warn "QIDM '$($q.name)' has separate In/Out combos but $entity State field '$fid' has initialValue='$($node.props.initialValue)' -- changes combo routing (LIMITATION #30)"
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
        Write-Limitation "${entity}: $($autoSelectQidms.Count) QIDMs have autoSelect=true on a SINGLE QIF -- co-fire by design (DL+DH co-fire is standard police workflow)"
        foreach ($asq in $autoSelectQidms) {
            Write-Host "         $($asq.name) (query=$($asq.query))" -ForegroundColor DarkYellow
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
            foreach ($attr in $dhQidm.attributes) {
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($sf in $sfs) {
                    if ($systemSourceFields -contains $sf) { continue }
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

    # LIMITATION #24: queriesToDeselect needed when >1 QIDM on single QIF
    if ($entityQifCount -eq 1 -and $eqidms.Count -gt 1) {
        $hasDeselect = $false
        foreach ($q in $eqidms) {
            if ($q.queriesToDeselect -and $q.queriesToDeselect.Count -gt 0) { $hasDeselect = $true; break }
        }
        if (-not $hasDeselect) {
            Write-Limitation "$entity : $($eqidms.Count) QIDMs on 1 QIF but none have queriesToDeselect -- checkbox toggling may not deselect other queries (LIMITATION #24)"
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
                    } elseif ($attr.rule.arguments[0] -ne 'true') {
                        Write-Warn "AUTH '$($auth.name)' attr '$($attr.name)' CommsysGetDexStateUserIdRuleHandler arguments[0]='$($attr.rule.arguments[0])' -- expected 'true'"
                    }
                }
                if ($attr.name -eq 'ORI' -or $attr.targetField -eq 'ORI') { $hasORI = $true }
                if ($attr.name -eq 'Mnemonic' -or $attr.targetField -eq 'Mnemonic') { $hasMnemonic = $true }
            }
            if (-not $hasDexHandler) {
                Write-Warn "AUTH '$($auth.name)' missing CommsysGetDexStateUserIdRuleHandler on UserName attribute"
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
                }
                if ($authCombo.requirements -and $authCombo.requirements.set) {
                    if ($authCombo.requirements.set -notcontains 'ORI') {
                        Write-Warn "AUTH '$($auth.name)' combo set[] missing 'ORI' -- auth may not fire"
                    }
                    if ($authCombo.requirements.set -notcontains 'Mnemonic') {
                        Write-Warn "AUTH '$($auth.name)' combo set[] missing 'Mnemonic' -- auth may not fire"
                    }
                }
            }
        } else {
            Write-Warn "AUTH '$($auth.name)' has no combinations -- auth pattern may not fire"
        }
        if ($auth.signInRequired -ne $false -and $auth.signInRequired -ne $null) {
            Write-Warn "AUTH '$($auth.name)' signInRequired='$($auth.signInRequired)' -- expected false"
        }
        if ($auth.deviceRegistrationOptional -ne $false -and $auth.deviceRegistrationOptional -ne $null) {
            Write-Warn "AUTH '$($auth.name)' deviceRegistrationOptional='$($auth.deviceRegistrationOptional)' -- expected false"
        }
    }

    if (-not $qmf) { Write-Fail "Bundle '$($bundle.name)' missing QUERYMESSAGEFORMAT config" }
    else {
        Write-Pass "QUERYMESSAGEFORMAT present"; Inc-Pass
        if ($qmf.handlerFunction -and $qmf.handlerFunction -ne 'CommsysWsiOutgoingMessageHandler') {
            Write-Warn "QMF '$($qmf.name)' handlerFunction='$($qmf.handlerFunction)' -- expected 'CommsysWsiOutgoingMessageHandler'"
        }
        if (-not $qmf.authenticationParent) {
            Write-Warn "QMF '$($qmf.name)' missing authenticationParent -- expected 'LawEnforcementTransaction'"
        } elseif ($qmf.authenticationParent -ne 'LawEnforcementTransaction') {
            Write-Warn "QMF '$($qmf.name)' authenticationParent='$($qmf.authenticationParent)' -- expected 'LawEnforcementTransaction'"
        }
        if (-not $qmf.payloadParent) {
            Write-Warn "QMF '$($qmf.name)' missing payloadParent -- expected 'LawEnforcementTransaction'"
        } elseif ($qmf.payloadParent -ne 'LawEnforcementTransaction') {
            Write-Warn "QMF '$($qmf.name)' payloadParent='$($qmf.payloadParent)' -- expected 'LawEnforcementTransaction'"
        }
    }

    if (-not $results) { Write-Fail "Bundle '$($bundle.name)' missing QUERYRESULTDATAMAPPING config" }
    else {
        Write-Pass "QUERYRESULTDATAMAPPING present"; Inc-Pass
        if ($results.handlerFunction -and $results.handlerFunction -ne 'CommsysResultsHandler') {
            Write-Warn "QRDM '$($results.name)' handlerFunction='$($results.handlerFunction)' -- expected 'CommsysResultsHandler'"
        }
    }
}

# RMS bundle checks
if ($rmsBundle) {
    if (-not $rmsBundle.provider) {
        Write-Warn "RMS bundle missing 'provider' property -- expected 'RMS'"
    } elseif ($rmsBundle.provider -ne 'RMS') {
        Write-Warn "RMS bundle provider='$($rmsBundle.provider)' -- expected 'RMS'"
    }
    # Check for unknown config types in RMS bundle
    $knownRmsTypes = @('QUERYINPUTDATAMAPPING','AUTHENTICATION','QUERYMESSAGEFORMAT','QUERYRESULTDATAMAPPING','QUERYRESULTSLAYOUT')
    foreach ($cfg in $rmsBundle.configurations) {
        if ($cfg.type -and $knownRmsTypes -notcontains $cfg.type) {
            Write-Warn "RMS bundle config '$($cfg.name)' has unknown type '$($cfg.type)' -- may be silently ignored"
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
        }
    }
    else { Write-Fail "RMS bundle missing AUTHENTICATION config" }
    if ($rmsQmf) {
        Write-Pass "RMS QUERYMESSAGEFORMAT present"; Inc-Pass
        if ($rmsQmf.handlerFunction -and $rmsQmf.handlerFunction -ne 'RestRequestHandler') {
            Write-Warn "RMS QMF handlerFunction='$($rmsQmf.handlerFunction)' -- expected 'RestRequestHandler'"
        }
    }
    else { Write-Fail "RMS bundle missing QUERYMESSAGEFORMAT config" }
    if ($rmsResults) {
        Write-Pass "RMS QUERYRESULTDATAMAPPING present"; Inc-Pass
        if ($rmsResults.handlerFunction -and $rmsResults.handlerFunction -ne 'RmsRestResultsHandler') {
            Write-Warn "RMS QRDM handlerFunction='$($rmsResults.handlerFunction)' -- expected 'RmsRestResultsHandler'"
        }
    }
    else { Write-Fail "RMS bundle missing QUERYRESULTDATAMAPPING config" }
    if ($rmsLayout) {
        Write-Pass "RMS QUERYRESULTSLAYOUT present"; Inc-Pass
        if ($rmsLayout.handlerFunction -and $rmsLayout.handlerFunction -ne 'QueryResultsLayoutHandler') {
            Write-Warn "RMS QRSL handlerFunction='$($rmsLayout.handlerFunction)' -- expected 'QueryResultsLayoutHandler'"
        }
    }
    else { Write-Fail "RMS bundle missing QUERYRESULTSLAYOUT config" }

    # ParallelQuery handler (optional -- HIDLE provides parallelQueryHandler on RMS bundle)
    if ($rmsBundle.ParallelQuery -and $rmsBundle.ParallelQuery.function) {
        if ($rmsBundle.ParallelQuery.function -ne 'parallelQueryHandler') {
            Write-Warn "RMS bundle ParallelQuery.function='$($rmsBundle.ParallelQuery.function)' -- expected 'parallelQueryHandler'"
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
        } else {
            Write-Pass "RMS QIDM '$($rq.name)' autoSelect=true"; Inc-Pass
        }
        if ($rq.handlerFunction -and $rq.handlerFunction -ne 'RmsRestPayloadHandler') {
            Write-Fail "RMS QIDM '$($rq.name)' handlerFunction='$($rq.handlerFunction)' -- must be 'RmsRestPayloadHandler'"
        }
        if ($rq.queryLabel -and $rq.queryLabel -ne 'RMS') {
            Write-Warn "RMS QIDM '$($rq.name)' queryLabel='$($rq.queryLabel)' -- expected 'RMS'"
        } elseif (-not $rq.queryLabel) {
            Write-Warn "RMS QIDM '$($rq.name)' missing queryLabel -- expected 'RMS'"
        }
    }

    # Patch 6: Known dead HIDLE attrs that must be removed
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
                        Write-Warn "RMS $($cfg.targetEntity) QIDM '$($cfg.name)' has dead HIDLE sourceField '$sf' -- remove per Patch 6"
                    }
                }
            }
        }
        if ($deadCombos) {
            foreach ($combo in $cfg.combinations) {
                if ($combo.keyReference -and $deadCombos -contains $combo.keyReference) {
                    Write-Warn "RMS $($cfg.targetEntity) QIDM '$($cfg.name)' has dead HIDLE combo '$($combo.keyReference)' -- remove per Patch 6"
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
