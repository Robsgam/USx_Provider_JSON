<#
  generate_test_matrix.ps1 -- Test Matrix Generator (Agent 2)
  Reads a provider JSON, extracts QIDMs/combos/cards/fields, and generates
  a complete TEST_MATRIX.txt in the standard 9-phase format.

  Co-fire QIDMs (VehicleStolenQuery, WantedPersonQuery) are folded as
  annotations on primary QIDM tests, not listed as separate tests.

  Usage: .\generate_test_matrix.ps1 -Path <provider.json> [-OutFile <path>] [-Variant <BASE|MC>]
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile,
    [ValidateSet('BASE','MC')][string]$Variant = 'MC'
)

$ErrorActionPreference = "Stop"

# ── Parse JSON ──
$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json

$entBundle  = $json.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$provBundle = $json.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' }

if (-not $entBundle)  { Write-Error "No ENTITIES bundle found"; exit 1 }
if (-not $provBundle) { Write-Error "No provider bundle found"; exit 1 }

$providerName = $provBundle.name
$fileName = Split-Path $Path -Leaf

# ── Extract version ──
$version = "unknown"
if ($provBundle.description -match 'v(\d+\.\d+)') { $version = $Matches[1] }
elseif ($fileName -match 'v(\d+\.\d+)') { $version = $Matches[1] }

# ── Collect CommSys QIDMs ──
$qidms = @()
foreach ($cfg in $provBundle.configurations) {
    if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
        $qidms += $cfg
    }
}

# ── Collect QIFs ──
$qifs = @($entBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' })

# ════════════════════════════════════════════════════════════════════════
#  HELPER FUNCTIONS
# ════════════════════════════════════════════════════════════════════════

function Get-CardFields($layout) {
    $cards = [ordered]@{}
    if (-not $layout) { return $cards }
    $members = ($layout | Get-Member -MemberType NoteProperty).Name
    foreach ($m in $members) {
        $node = $layout.$m
        if ($node.type.resolvedName -eq 'Card') {
            $title = if ($node.props.title) { $node.props.title } elseif ($node.props.label) { $node.props.label } else { $m }
            $fields = @()
            if ($node.nodes) {
                foreach ($rowId in $node.nodes) {
                    $row = $layout.$rowId
                    if (-not $row) { continue }
                    $cols = if ($row.props.templateColumns) { $row.props.templateColumns -join ',' } else { '12' }
                    $rowFields = @()
                    if ($row.nodes) {
                        foreach ($fieldId in $row.nodes) {
                            $fnode = $layout.$fieldId
                            if (-not $fnode) { continue }
                            $fid = if ($fnode.props.fieldId) { $fnode.props.fieldId } else { $fieldId }
                            $ftype = switch ($fnode.type.resolvedName) {
                                'FormSelect'    { 'Sel' }
                                'FormInput'     { 'Inp' }
                                'FormDate'      { 'FormDate' }
                                'FormDateInput' { 'FormDate' }
                                'CheckboxInput' { 'Chk' }
                                default         { $fnode.type.resolvedName }
                            }
                            $extra = @()
                            if ($fnode.props.attributeTypeId)   { $extra += $fnode.props.attributeTypeId }
                            if ($fnode.props.codeTypeCategory)  { $extra += "$($fnode.props.codeTypeCategory)/$($fnode.props.codeTypeSource)" }
                            if ($fnode.props.initialValue)      { $extra += $fnode.props.initialValue }
                            if ($fnode.props.maxLength)          { $extra += "$($fnode.props.maxLength)" }
                            if ($fnode.props.hidden -eq $true)   { $extra += 'HIDDEN' }
                            $label = if ($fnode.props.label) { $fnode.props.label } else { $fid }
                            $rowFields += [PSCustomObject]@{
                                fieldId = $fid; label = $label; type = $ftype; extra = $extra -join ', '
                                hidden = ($fnode.props.hidden -eq $true); default_ = $fnode.props.initialValue
                                nodeId = $fieldId; attrTypeId = $fnode.props.attributeTypeId
                                codeType = $fnode.props.codeTypeCategory; codeSource = $fnode.props.codeTypeSource
                                maxLen = $fnode.props.maxLength
                            }
                        }
                    }
                    $fields += [PSCustomObject]@{ rowId = $rowId; cols = $cols; fields = $rowFields }
                }
            }
            $cards[$m] = [PSCustomObject]@{ id = $m; title = $title; rows = $fields }
        }
    }
    return $cards
}

function Get-QidmEntityMap($qifs, $qidms) {
    $map = @{}
    foreach ($qif in $qifs) {
        $entity = $qif.targetEntity
        $qidmNames = @()
        if ($qif.queryInputDataMapping -is [System.Array]) { $qidmNames = $qif.queryInputDataMapping }
        elseif ($qif.queryInputDataMapping) { $qidmNames = @($qif.queryInputDataMapping) }
        foreach ($qn in $qidmNames) { $map[$qn] = $entity }
    }
    foreach ($q in $qidms) {
        if ($q.targetEntity -and -not $map.ContainsKey($q.name)) { $map[$q.name] = $q.targetEntity }
    }
    return $map
}

function Get-ComboShortName($keyRef) {
    if ($keyRef -match '^(FRQ|FDQ|FBQ|QV|QW|QG|QA|QB|BQ|RQ|DQ|KQ|DALL|DALH|RCAR|RVIN|IN|IG|NLTS|DPSI|REG|VIN|FRT|ZVEH|ZLRG|ZDRV|Z2|Z5)') {
        return $Matches[1]
    }
    return $keyRef.Substring(0, [Math]::Min(6, $keyRef.Length))
}

function Get-PrimaryField($keyRef, $setFields) {
    $suffix = $keyRef
    foreach ($prefix in @('FRQ','FDQ','FBQ','QV','QW','QG','QA','QB','BQ','RQ','DQ','KQ','DALL','DALH','RCAR','RVIN','IN','IG','NLTS','DPSI','REG','VIN','FRT','ZVEH','ZLRG','ZDRV','Z2','Z5')) {
        if ($keyRef.StartsWith($prefix)) { $suffix = $keyRef.Substring($prefix.Length); break }
    }
    if ($suffix) { return $suffix }
    if ($setFields.Count -gt 0) { return $setFields[0] }
    return "unknown"
}

function Get-CoFireMap($qidms, $entityMap) {
    $byEntity = @{}
    foreach ($q in $qidms) {
        $ent = if ($entityMap[$q.name]) { $entityMap[$q.name] } else { $q.targetEntity }
        if (-not $byEntity.ContainsKey($ent)) { $byEntity[$ent] = @() }
        $byEntity[$ent] += $q
    }
    $cofire = @{}
    foreach ($ent in $byEntity.Keys) {
        if ($byEntity[$ent].Count -gt 1) {
            foreach ($q in $byEntity[$ent]) {
                $others = @($byEntity[$ent] | Where-Object { $_.name -ne $q.name })
                $cofire[$q.name] = $others
            }
        }
    }
    return $cofire
}

function Get-DeselectMap($qidms) {
    $deselect = @{}
    foreach ($q in $qidms) {
        if ($q.queriesToDeselect -and @($q.queriesToDeselect).Count -gt 0) {
            $deselect[$q.name] = @($q.queriesToDeselect)
        }
    }
    return $deselect
}

# Classify each QIDM as PRIMARY, DESELECT, or COFIRE
function Get-QidmRoles($qidms, $entityMap, $deselectMap) {
    $roles = @{}
    $byEntity = @{}
    foreach ($q in $qidms) {
        $ent = $entityMap[$q.name]
        if (-not $byEntity.ContainsKey($ent)) { $byEntity[$ent] = @() }
        $byEntity[$ent] += $q
    }
    foreach ($ent in $byEntity.Keys) {
        $entQidms = $byEntity[$ent]
        if ($entQidms.Count -eq 1) { $roles[$entQidms[0].name] = 'PRIMARY'; continue }

        $hasPrimary = $false
        foreach ($q in $entQidms) {
            if ($deselectMap.ContainsKey($q.name)) {
                $roles[$q.name] = 'DESELECT'
            } elseif ($q.autoSelect -eq $true) {
                $roles[$q.name] = 'PRIMARY'; $hasPrimary = $true
            }
        }

        $unclassified = @($entQidms | Where-Object { -not $roles.ContainsKey($_.name) } | Sort-Object { $_.combinations.Count } -Descending)
        foreach ($q in $unclassified) {
            if (-not $hasPrimary) { $roles[$q.name] = 'PRIMARY'; $hasPrimary = $true }
            else { $roles[$q.name] = 'COFIRE' }
        }
    }
    return $roles
}

# Resolve a combo's set[] attribute names to form fieldIds
function Resolve-SetToFieldIds($combo, $qidm, $allFields) {
    $setNames = @()
    if ($combo.requirements -and $combo.requirements.set) { $setNames = @($combo.requirements.set) }
    $ids = @()
    foreach ($sf in $setNames) {
        $match = $allFields | Where-Object { $_.fieldId -eq $sf } | Select-Object -First 1
        if ($match) { $ids += $match.fieldId; continue }
        foreach ($attr in $qidm.attributes) {
            if ($attr.name -eq $sf) {
                $sfs = @()
                if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                foreach ($s in $sfs) {
                    $fm = $allFields | Where-Object { $_.fieldId -eq $s } | Select-Object -First 1
                    if ($fm) { $ids += $fm.fieldId; break }
                }
                break
            }
        }
    }
    return $ids
}

function Get-TestValue($field, $isOOS) {
    $fid = $field.fieldId
    switch -Regex ($fid) {
        '(?i)^licensePlateNumber'           { return 'TEST123' }
        '(?i)^licensePlateTypeCode'         { $d = $field.default_; if ($d) { return $d } else { return 'PC' } }
        '(?i)^licensePlateYear'             { $d = $field.default_; if ($d) { return $d } else { return (Get-Date).Year.ToString() } }
        '(?i)^vehicleIdentificationNumber'  { return '1HGCM82633A123456' }
        '(?i)^vehicleMakeCode'              { return 'FORD' }
        '(?i)^vehicleYear'                  { return '2023' }
        '(?i)^decalNumber'                  { return 'FL12345678' }
        '(?i)^titleLienInformation'         { return 'ABCD1234' }
        '(?i)^registrationState$'           { if ($isOOS) { return 'GA' } else { return $null } }
        '(?i)^registrationStateDH'          { return $field.default_ }
        '(?i)^operatorLicenseNumber$'       { return 'D999888777' }
        '(?i)^operatorLicenseNumberDH'      { return 'D999888777' }
        '(?i)^nameLast$'                    { return 'DOE' }
        '(?i)^nameLastDH'                   { return 'DOE' }
        '(?i)^nameFirst$'                   { return 'JOHN' }
        '(?i)^nameFirstDH'                  { return 'JOHN' }
        '(?i)^nameMiddle'                   { return '' }
        '(?i)^nameSuffix'                   { return '' }
        '(?i)^birthDate$'                   { return '01/15/1990' }
        '(?i)^birthDateDH'                  { return '01/15/1990' }
        '(?i)^sexCode$'                     { return 'M' }
        '(?i)^sexCodeDH'                    { return 'M' }
        '(?i)^imageIndicator'               { $d = $field.default_; if ($d) { return $d } else { return 'N' } }
        '(?i)^gunSerialNumber'              { return 'GUN12345' }
        '(?i)^gunMake'                      { return 'SMTH' }
        '(?i)^gunCaliber'                   { return '9MM' }
        '(?i)^ncicNumber'                   { return 'X123456789' }
        '(?i)^processControlNumber'         { return '0000012345' }
        '(?i)^articleSerialNumber'           { return 'ART99999' }
        '(?i)^articleTypeCode'              { return 'BBICYCL' }
        '(?i)^ownerAppliedNumber'           { return 'OAN999' }
        '(?i)^boatHullIdNumber'             { return 'FL1234AB56H7' }
        '(?i)^registrationNumber'           { return 'FL1234AB' }
        '(?i)^coastGuardDocumentNumber'     { return 'CG123456' }
        '(?i)^relatedHitSearchIndicator'    { return 'Y' }
        '(?i)^purposeCode'                  { return 'C' }
        '(?i)^attention'                    { return 'SMITH J' }
        '(?i)^caRequestPurposeCode'         { return 'C' }
        '(?i)^dexStateUserId'               { return 'BADGE' }
        default                             { return 'TEST' }
    }
}

function Get-QueryShortLabel($query) {
    switch ($query) {
        'VehicleRegistrationQuery'  { 'Vehicle Registration' }
        'VehicleStolenQuery'        { 'Vehicle Stolen' }
        'DriverLicenseQuery'        { 'Driver License' }
        'DriverHistoryQuery'        { 'Driver History' }
        'WantedPersonQuery'         { 'Wanted Person' }
        'GunQuery'                  { 'Firearm' }
        'ArticleSingleQuery'        { 'Article' }
        'BoatQuery'                 { 'Boat' }
        default                     { $query -replace 'Query$','' }
    }
}

function Get-QueryAbbrev($query) {
    switch ($query) {
        'VehicleRegistrationQuery'  { 'VehReg' }
        'VehicleStolenQuery'        { 'VehStolen' }
        'DriverLicenseQuery'        { 'DL' }
        'DriverHistoryQuery'        { 'DH' }
        'WantedPersonQuery'         { 'Wanted' }
        'GunQuery'                  { 'Gun' }
        'ArticleSingleQuery'        { 'Article' }
        'BoatQuery'                 { 'Boat' }
        default                     { $query -replace 'Query$','' }
    }
}

function Get-ShortFieldLabel($suffix) {
    switch -Regex ($suffix) {
        '(?i)^LicensePlateNumber'            { return 'Plate' }
        '(?i)^VehicleIdentificationNumber'   { return 'VIN' }
        '(?i)^OperatorLicenseNumber'         { return 'OLN' }
        '(?i)^BoatHullIdNumber'              { return 'Hull' }
        '(?i)^RegistrationNumber$'           { return 'Reg' }
        '(?i)^DecalNumber'                   { return 'Decal' }
        '(?i)^TitleLienInformation'          { return 'TitleLien' }
        '(?i)^CoastGuardDocumentNumber'      { return 'CG' }
        '(?i)^GunSerialNumber'               { return 'Serial' }
        '(?i)^ArticleSerialNumber'           { return 'Serial' }
        '(?i)^OwnerAppliedNumber'            { return 'OAN' }
        '(?i)^NCICNumber'                    { return 'NCIC' }
        '(?i)^ProcessControlNumber'          { return 'PCN' }
        '(?i)^Name'                          { return 'Name' }
        default                              { return $suffix }
    }
}

function Get-ComboSortKey($keyRef, [switch]$FieldFirst) {
    $prefix = Get-ComboShortName $keyRef
    $field = Get-PrimaryField $keyRef @()
    $prefixOrder = switch ($prefix) {
        'FRQ' { 0 }  'FDQ' { 0 }  'FBQ' { 0 }
        'RQ'  { 1 }  'DQ'  { 1 }  'BQ'  { 1 }
        'KQ'  { 2 }
        'QV'  { 3 }  'QW'  { 3 }  'QB'  { 3 }
        'QG'  { 0 }  'QA'  { 0 }
        default { 5 }
    }
    $fieldOrder = switch -Regex ($field) {
        '(?i)^(OperatorLicenseNumber|LicensePlateNumber|BoatHullIdNumber|GunSerialNumber|ArticleSerialNumber)' { 0 }
        '(?i)^(VehicleIdentificationNumber|RegistrationNumber)' { 1 }
        '(?i)^Name' { 2 }
        '(?i)^DecalNumber' { 3 }
        '(?i)^TitleLien' { 4 }
        '(?i)^(OwnerApplied|CoastGuard)' { 5 }
        '(?i)^NCICNumber' { 6 }
        '(?i)^ProcessControl' { 7 }
        default { 9 }
    }
    if ($FieldFirst) { return $fieldOrder * 100 + $prefixOrder }
    return $prefixOrder * 100 + $fieldOrder
}

# ════════════════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════════════════

$entityMap   = Get-QidmEntityMap $qifs $qidms
$cofireMap   = Get-CoFireMap $qidms $entityMap
$deselectMap = Get-DeselectMap $qidms
$qidmRoles   = Get-QidmRoles $qidms $entityMap $deselectMap

# ── Build entity data ──
$entityData = [ordered]@{}
foreach ($qif in $qifs) {
    $entity = $qif.targetEntity
    $cards = Get-CardFields $qif.layout.default
    $cardCount = $cards.Count
    $allFields = @(); $fieldCount = 0
    foreach ($card in $cards.Values) {
        foreach ($row in $card.rows) {
            foreach ($f in $row.fields) { $allFields += $f; if (-not $f.hidden) { $fieldCount++ } }
        }
    }
    $entQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })
    $totalCombos = 0
    foreach ($q in $entQidms) { $totalCombos += $q.combinations.Count }

    # Detect dedicated Options card (routing-only fields)
    $hasOptionsCard = $false
    foreach ($card in $cards.Values) {
        $allRouting = $true; $fCnt = 0
        foreach ($row in $card.rows) {
            foreach ($f in $row.fields) {
                if ($f.hidden) { continue }; $fCnt++
                if ($f.fieldId -notmatch '(?i)(registrationState|relatedHitSearchIndicator|imageIndicator|randomRequest)$') { $allRouting = $false }
            }
        }
        if ($allRouting -and $fCnt -gt 0 -and $cardCount -gt 1) { $hasOptionsCard = $true }
    }

    # Collect all set[] attribute names across all combos (for auxiliary any[] filter)
    $allSetAttrNames = @{}
    foreach ($q in $entQidms) {
        foreach ($c in $q.combinations) {
            if ($c.requirements -and $c.requirements.set) {
                foreach ($sf in $c.requirements.set) { $allSetAttrNames[$sf] = $true }
            }
        }
    }

    $entityData[$entity] = [PSCustomObject]@{
        entity = $entity; qif = $qif; cards = $cards; cardCount = $cardCount
        allFields = $allFields; fieldCount = $fieldCount; qidms = $entQidms
        combos = $totalCombos; hasOptionsCard = $hasOptionsCard
        allSetAttrNames = $allSetAttrNames
    }
}

$totalQidms = $qidms.Count
$totalCombos = 0
foreach ($q in $qidms) { $totalCombos += $q.combinations.Count }

# ── Validator score (capture all streams including Write-Host) ──
$validatorScore = "unknown"
try {
    $valOutput = & "$PSScriptRoot\validate.ps1" -Path $Path -Force *>&1 | Out-String
    if ($valOutput -match '(\d+)\s+PASS\s+/\s+(\d+)\s+FAIL\s+/\s+(\d+)\s+WARN') {
        $p = $Matches[1]; $f = $Matches[2]; $w = $Matches[3]
        $limMatch = [regex]::Match($valOutput, '(\d+)\s+LIMITATION')
        $l = if ($limMatch.Success) { $limMatch.Groups[1].Value } else { '0' }
        $validatorScore = "${p} PASS / ${f} FAIL / ${w} WARN / ${l} LIMITATION"
    }
} catch { }

# ── Entity test order: Options-card entities first, then multi-card, then single-card ──
$stdPriority = @{ 'Vehicle'=500; 'Boat'=400; 'Person'=300; 'Firearm'=200; 'Article'=100 }
$entityOrder = @($entityData.Keys | Sort-Object {
    $ed = $entityData[$_]
    $bp = if ($stdPriority.ContainsKey($_)) { $stdPriority[$_] } else { 50 }
    $ob = if ($ed.hasOptionsCard) { 10000 } else { 0 }
    -($ob + $ed.cardCount * 1000 + $bp)
})

# ════════════════════════════════════════════════════════════════════════
#  OUTPUT
# ════════════════════════════════════════════════════════════════════════

$sb = [System.Text.StringBuilder]::new()
$combosCovered = @{}
$comboTestRefs = @{}

# ── Header ──
[void]$sb.AppendLine("$providerName $Variant v$version -- TEST MATRIX")
[void]$sb.AppendLine("=" * 50)
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd')")
[void]$sb.AppendLine("Variant: $Variant $(if ($Variant -eq 'MC') { '(multi-card per entity)' } else { '(single-card per entity)' })")
[void]$sb.AppendLine("Validator: $validatorScore")
[void]$sb.AppendLine("")

# ── Form Fields (follows entity test order) ──
[void]$sb.AppendLine("FORM FIELDS ($Variant layout)")
[void]$sb.AppendLine("-" * 40)
$formFieldOrder = @($entityData.Keys | Sort-Object { switch ($_) { 'Vehicle' { 0 } 'Person' { 1 } 'Firearm' { 2 } 'Article' { 3 } 'Boat' { 4 } default { 5 } } })
foreach ($ent in $formFieldOrder) {
    $ed = $entityData[$ent]
    [void]$sb.AppendLine("$ent ($($ed.cardCount) card$(if ($ed.cardCount -ne 1){'s'}), $($ed.fieldCount) fields):")
    foreach ($card in $ed.cards.Values) {
        [void]$sb.AppendLine("  $($card.id) ($($card.title)):")
        $visibleRows = @($card.rows | Where-Object { ($_.fields | Where-Object { -not $_.hidden }).Count -gt 0 })
        $rowIdx = 0
        foreach ($row in $card.rows) {
            $fds = @()
            foreach ($f in $row.fields) {
                if ($f.hidden) { continue }
                $d = "$($f.fieldId) [$($f.type)"
                if ($f.extra) { $d += " $($f.extra)" }
                $d += "]"
                $fds += $d
            }
            if ($fds.Count -gt 0) {
                $rowIdx++
                if ($visibleRows.Count -le 1) { [void]$sb.AppendLine("    $($fds -join ', ')") }
                else { [void]$sb.AppendLine("    ROW $rowIdx`: $($fds -join ', ')") }
            }
        }
    }
    [void]$sb.AppendLine("")
}

# ── QIDM Summary (with prefix breakdown and role annotations) ──
[void]$sb.AppendLine("QIDM SUMMARY ($totalQidms QIDMs, $totalCombos combos)")
[void]$sb.AppendLine("-" * 40)
foreach ($q in $qidms) {
    $role = $qidmRoles[$q.name]
    $autoSel = if ($q.autoSelect -eq $true) { ', autoSelect=true' } else { '' }

    # Combo prefix breakdown: (RQ x2, FRQ x4)
    $prefixCounts = [ordered]@{}
    foreach ($c in $q.combinations) {
        $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
        $pf = Get-ComboShortName $kr
        if (-not $prefixCounts.Contains($pf)) { $prefixCounts[$pf] = 0 }
        $prefixCounts[$pf]++
    }
    $pfSort = @{ 'RQ'=0;'DQ'=0;'BQ'=0;'FRQ'=10;'FDQ'=10;'FBQ'=10;'KQ'=20;'QV'=30;'QW'=30;'QB'=30;'QG'=0;'QA'=0 }
    $prefixStr = ($prefixCounts.GetEnumerator() | Sort-Object { $k=$pfSort[$_.Key]; if($null -eq $k){50}else{$k} } | ForEach-Object { "$($_.Key) x$($_.Value)" }) -join ', '

    $deselStr = ''
    if ($deselectMap.ContainsKey($q.name)) {
        $targets = ($deselectMap[$q.name] | ForEach-Object { Get-QueryAbbrev $_ }) -join ', '
        $deselStr = ", deselects: [$targets]"
    }

    $cofStr = ''
    if ($role -eq 'COFIRE' -and $cofireMap.ContainsKey($q.name)) {
        $primary = $cofireMap[$q.name] | Where-Object { $qidmRoles[$_.name] -eq 'PRIMARY' } | Select-Object -First 1
        if ($primary) { $cofStr = " -- co-fires with $(Get-QueryAbbrev $primary.query)" }
    }

    [void]$sb.AppendLine("  $($q.query): $($q.combinations.Count) combos ($prefixStr)$autoSel$deselStr$cofStr")
}
[void]$sb.AppendLine("")

# ════════════════════════════════════════════════════════════════════════
#  PHASES
# ════════════════════════════════════════════════════════════════════════

$testNum = 0

# ── PHASE 1: RENDER ──
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("TEST MATRIX")
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("")
[void]$sb.AppendLine("PHASE 1: RENDER (verify card structure, fields, picklists, defaults)")
[void]$sb.AppendLine("-" * 72)
[void]$sb.AppendLine("#   Entity      Action                                              Result")
[void]$sb.AppendLine("--  ----------  --------------------------------------------------  ------")

foreach ($ent in $entityOrder) {
    $ed = $entityData[$ent]
    $testNum++
    [void]$sb.Append(("{0,2}  {1,-10}  Render form. Verify {2} card{3}:" -f $testNum, $ent, $ed.cardCount, $(if ($ed.cardCount -ne 1){'s'} else {''})))
    [void]$sb.AppendLine("                        [    ]")
    foreach ($card in $ed.cards.Values) {
        [void]$sb.AppendLine("              $($card.id): titled `"$($card.title)`".")
        foreach ($row in $card.rows) {
            $fds = @()
            foreach ($f in $row.fields) {
                if ($f.hidden) { continue }
                $d = $f.label
                if ($f.type -eq 'Sel') { $d += " dropdown" }
                if ($f.default_) { $d += "=$($f.default_)" }
                elseif ($f.type -eq 'Sel' -and -not $f.default_) { $d += " (no default)" }
                $fds += $d
            }
            if ($fds.Count -gt 0) { [void]$sb.AppendLine("              $($fds -join ', ').") }
        }
    }
}

# ── COMBO PHASES (one per entity, co-fire folded as annotations) ──
$phaseNum = 1
foreach ($ent in $entityOrder) {
    $ed = $entityData[$ent]
    if ($ed.combos -eq 0) { continue }
    $phaseNum++

    # Classify this entity's QIDMs
    $primaryQidms  = @($ed.qidms | Where-Object { $qidmRoles[$_.name] -eq 'PRIMARY' })
    $deselectQidms = @($ed.qidms | Where-Object { $qidmRoles[$_.name] -eq 'DESELECT' })
    $cofireQidms   = @($ed.qidms | Where-Object { $qidmRoles[$_.name] -eq 'COFIRE' })

    # Generate combo tests into buffer (need count for header)
    $phaseSb = [System.Text.StringBuilder]::new()
    $phaseTestCount = 0

    # Process PRIMARY QIDMs → one test per combo, with co-fire annotations
    # Options-card entities sort by prefix (FRQ→RQ), others sort by field (OLN→Name)
    $fieldFirst = -not $ed.hasOptionsCard
    foreach ($q in $primaryQidms) {
        $sortedCombos = @($q.combinations | Sort-Object { Get-ComboSortKey $(if ($_.keyReference) { $_.keyReference } else { $_.keyRef }) -FieldFirst:$fieldFirst })
        foreach ($c in $sortedCombos) {
            $testNum++; $phaseTestCount++
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $shortName = Get-ComboShortName $kr
            $setFieldNames = @()
            if ($c.requirements -and $c.requirements.set) { $setFieldNames = @($c.requirements.set) }
            $primaryField = Get-PrimaryField $kr $setFieldNames
            $shortField = Get-ShortFieldLabel $primaryField

            # Routing suffix: +State or +Stolen when routing field is in set[]
            $routingSuffix = ''
            foreach ($sf in $setFieldNames) {
                if ($sf -match '(?i)^(RegistrationState|State)$') { $routingSuffix = '+State' }
                if ($sf -match '(?i)RelatedHitSearch') { $routingSuffix = '+Stolen' }
            }
            $comboLabel = "$shortName+$shortField$routingSuffix"

            # Detect OOS (State in set[])
            $isOOS = [bool]($setFieldNames | Where-Object { $_ -match '(?i)^(RegistrationState|State)$' })

            # Resolve set[] to fill instructions
            $fillInstructions = @(); $filledFieldIds = @()
            foreach ($sf in $setFieldNames) {
                $formField = $ed.allFields | Where-Object { $_.fieldId -eq $sf } | Select-Object -First 1
                if (-not $formField) {
                    foreach ($attr in $q.attributes) {
                        if ($attr.name -eq $sf) {
                            $sfs = @()
                            if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                            elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                            foreach ($s in $sfs) {
                                $formField = $ed.allFields | Where-Object { $_.fieldId -eq $s } | Select-Object -First 1
                                if ($formField) { break }
                            }; break
                        }
                    }
                }
                if ($formField) {
                    $val = Get-TestValue $formField $isOOS
                    if ($val) {
                        $fillInstructions += "$($formField.fieldId)=$val"
                        $filledFieldIds += $formField.fieldId
                    }
                }
            }

            # Check which co-fire combos are satisfied by this test's fields
            $cofireHits = @()
            foreach ($cq in $cofireQidms) {
                foreach ($cc in $cq.combinations) {
                    $ccIds = Resolve-SetToFieldIds $cc $cq $ed.allFields
                    if ($ccIds.Count -eq 0) { continue }
                    $allIn = $true
                    foreach ($fid in $ccIds) {
                        if ($fid -notin $filledFieldIds) { $allIn = $false; break }
                    }
                    if ($allIn) {
                        $ckr = if ($cc.keyReference) { $cc.keyReference } else { $cc.keyRef }
                        $cShort2 = Get-ComboShortName $ckr
                        $cField2 = Get-ShortFieldLabel (Get-PrimaryField $ckr @())
                        $cofireHits += [PSCustomObject]@{ kr = $ckr; query = $cq.query; short = $cShort2; field = $cField2 }
                        $cfKey = "$($cq.name)|$ckr"
                        $combosCovered[$cfKey] = $true
                        if (-not $comboTestRefs.ContainsKey($cfKey)) {
                            $comboTestRefs[$cfKey] = @{ num = $testNum; label = "$cShort2+$cField2"; cofire = $true }
                        }
                    }
                }
            }

            $pKey = "$($q.name)|$kr"
            $combosCovered[$pKey] = $true
            $comboTestRefs[$pKey] = @{ num = $testNum; label = $comboLabel; cofire = $false }

            $fillStr = $fillInstructions -join ', '
            if ($fillStr.Length -gt 40) { $fillStr = $fillStr.Substring(0, 37) + '...' }

            [void]$phaseSb.Append(("{0,2}  {1,-10}  {2,-17}  {3,-32} " -f $testNum, $ent, $comboLabel, $fillStr))
            [void]$phaseSb.AppendLine("[    ]")

            $expected = "$($q.query) fires ($shortName)"
            foreach ($ch in $cofireHits) {
                $expected += ". Check for $($ch.query) co-fire"
            }
            [void]$phaseSb.AppendLine("              Expected: $expected")
        }
    }

    # Uncovered co-fire combos get explicit tests
    foreach ($cq in $cofireQidms) {
        foreach ($cc in $cq.combinations) {
            $ckr = if ($cc.keyReference) { $cc.keyReference } else { $cc.keyRef }
            $cfKey = "$($cq.name)|$ckr"
            if ($combosCovered.ContainsKey($cfKey)) { continue }

            $testNum++; $phaseTestCount++
            $cShort = Get-ComboShortName $ckr
            $ccSetNames = @()
            if ($cc.requirements -and $cc.requirements.set) { $ccSetNames = @($cc.requirements.set) }
            $cPrimary = Get-PrimaryField $ckr $ccSetNames
            $cShortField = Get-ShortFieldLabel $cPrimary
            $comboLabel = "$cShort+$cShortField"

            # Resolve co-fire set[] to fill instructions
            $fillInstructions = @(); $filledFieldIds = @()
            foreach ($sf in $ccSetNames) {
                $formField = $ed.allFields | Where-Object { $_.fieldId -eq $sf } | Select-Object -First 1
                if (-not $formField) {
                    foreach ($attr in $cq.attributes) {
                        if ($attr.name -eq $sf) {
                            $sfs = @()
                            if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                            elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                            foreach ($s in $sfs) {
                                $formField = $ed.allFields | Where-Object { $_.fieldId -eq $s } | Select-Object -First 1
                                if ($formField) { break }
                            }; break
                        }
                    }
                }
                if ($formField) {
                    $val = Get-TestValue $formField $false
                    if ($val) {
                        $fillInstructions += "$($formField.fieldId)=$val"
                        $filledFieldIds += $formField.fieldId
                    }
                }
            }

            $combosCovered[$cfKey] = $true
            $comboTestRefs[$cfKey] = @{ num = $testNum; label = $comboLabel; cofire = $true }

            # Determine which primary combo also fires alongside
            $alsoFires = ''
            foreach ($pq in $primaryQidms) {
                foreach ($pc in $pq.combinations) {
                    $pcIds = Resolve-SetToFieldIds $pc $pq $ed.allFields
                    if ($pcIds.Count -eq 0) { continue }
                    $allIn = $true
                    foreach ($fid in $pcIds) {
                        if ($fid -notin $filledFieldIds) { $allIn = $false; break }
                    }
                    if ($allIn) {
                        $pkr = if ($pc.keyReference) { $pc.keyReference } else { $pc.keyRef }
                        $pShort = Get-ComboShortName $pkr
                        $alsoFires = "$($pq.query) fires ($pShort). "
                        break
                    }
                }
                if ($alsoFires) { break }
            }

            $fillStr = $fillInstructions -join ', '
            if ($fillStr.Length -gt 40) { $fillStr = $fillStr.Substring(0, 37) + '...' }

            [void]$phaseSb.Append(("{0,2}  {1,-10}  {2,-17}  {3,-32} " -f $testNum, $ent, $comboLabel, $fillStr))
            [void]$phaseSb.AppendLine("[    ]")
            [void]$phaseSb.AppendLine("              Expected: ${alsoFires}$($cq.query) co-fires ($cShort)")
        }
    }

    # Process DESELECT QIDMs → one test per combo (after co-fire explicit tests)
    foreach ($q in $deselectQidms) {
        $sortedCombos = @($q.combinations | Sort-Object { Get-ComboSortKey $(if ($_.keyReference) { $_.keyReference } else { $_.keyRef }) -FieldFirst:$fieldFirst })
        foreach ($c in $sortedCombos) {
            $testNum++; $phaseTestCount++
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $shortName = Get-ComboShortName $kr
            $setFieldNames = @()
            if ($c.requirements -and $c.requirements.set) { $setFieldNames = @($c.requirements.set) }
            $primaryField = Get-PrimaryField $kr $setFieldNames
            $shortField = Get-ShortFieldLabel $primaryField
            $routingSuffix = ''
            foreach ($sf in $setFieldNames) {
                if ($sf -match '(?i)^(RegistrationState|State)$') { $routingSuffix = '+State' }
                if ($sf -match '(?i)RelatedHitSearch') { $routingSuffix = '+Stolen' }
            }
            $comboLabel = "$shortName+$shortField$routingSuffix"
            $isOOS = [bool]($setFieldNames | Where-Object { $_ -match '(?i)^(RegistrationState|State)$' })
            $fillInstructions = @(); $filledFieldIds = @()
            foreach ($sf in $setFieldNames) {
                $formField = $ed.allFields | Where-Object { $_.fieldId -eq $sf } | Select-Object -First 1
                if (-not $formField) {
                    foreach ($attr in $q.attributes) {
                        if ($attr.name -eq $sf) {
                            $sfs = @()
                            if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                            elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                            foreach ($s in $sfs) {
                                $formField = $ed.allFields | Where-Object { $_.fieldId -eq $s } | Select-Object -First 1
                                if ($formField) { break }
                            }; break
                        }
                    }
                }
                if ($formField) {
                    $val = Get-TestValue $formField $isOOS
                    if ($val) { $fillInstructions += "$($formField.fieldId)=$val"; $filledFieldIds += $formField.fieldId }
                }
            }
            $dKey = "$($q.name)|$kr"
            $combosCovered[$dKey] = $true
            $comboTestRefs[$dKey] = @{ num = $testNum; label = $comboLabel; cofire = $false }
            $fillStr = $fillInstructions -join ', '
            if ($fillStr.Length -gt 40) { $fillStr = $fillStr.Substring(0, 37) + '...' }
            [void]$phaseSb.Append(("{0,2}  {1,-10}  {2,-17}  {3,-32} " -f $testNum, $ent, $comboLabel, $fillStr))
            [void]$phaseSb.AppendLine("[    ]")
            [void]$phaseSb.AppendLine("              Expected: $($q.query) fires ($shortName)")
        }
    }

    # Write phase header + body
    $cofireNote = ''
    if ($cofireQidms.Count -gt 0) {
        $cfLabels = ($cofireQidms | ForEach-Object { Get-QueryAbbrev $_.query }) -join '/'
        $pLabels  = ($primaryQidms | ForEach-Object { Get-QueryAbbrev $_.query }) -join '/'
        $cofireNote = " -- $cfLabels co-fires with $pLabels"
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("PHASE $phaseNum`: $($ent.ToUpper()) COMBOS ($phaseTestCount tests, $($ed.combos) combos$cofireNote)")
    [void]$sb.AppendLine("-" * 72)
    [void]$sb.AppendLine("#   Entity      Combo              Fields to fill                   Result")
    [void]$sb.AppendLine("--  ----------  -----------------  -------------------------------- ------")
    [void]$sb.Append($phaseSb.ToString())
}

# ── ANY[] PHASE ──
# Only entities with truly auxiliary any[] fields (not ImageIndicator, not set[] in other combos)
$phaseNum++
$anyByEntity = @{}
foreach ($ent in $entityOrder) {
    $ed = $entityData[$ent]
    $bestCandidate = $null; $bestScore = -1

    foreach ($q in $ed.qidms) {
        foreach ($c in $q.combinations) {
            $anyFields = @()
            if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }
            $setFields = @()
            if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }

            $auxiliary = @()
            foreach ($af in $anyFields) {
                if ($af -in $setFields) { continue }
                # Resolve to form fieldId
                $formFid = $null
                foreach ($attr in $q.attributes) {
                    if ($attr.name -eq $af) {
                        $sfs = @()
                        if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                        elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                        if ($sfs.Count -gt 0) { $formFid = $sfs[0] }
                        break
                    }
                }
                if (-not $formFid) { $formFid = $af }
                # Skip ImageIndicator
                if ($formFid -match '(?i)^imageIndicator$') { continue }
                # Skip fields that are set[] in other combos (not truly auxiliary)
                if ($ed.allSetAttrNames.ContainsKey($af)) { continue }
                $auxiliary += $formFid
            }

            if ($auxiliary.Count -gt 0) {
                $score = $auxiliary.Count * 100 - $setFields.Count
                if ($score -gt $bestScore) {
                    $bestScore = $score
                    $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
                    $bestCandidate = [PSCustomObject]@{ qidm = $q; combo = $c; kr = $kr; anyFields = $auxiliary }
                }
            }
        }
    }
    if ($bestCandidate) { $anyByEntity[$ent] = $bestCandidate }
}

if ($anyByEntity.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("PHASE $phaseNum`: ANY[] FIELD TESTS ($($anyByEntity.Count) tests)")
    [void]$sb.AppendLine("-" * 72)
    [void]$sb.AppendLine("#   Entity      Combo              any[] field tested               Result")
    [void]$sb.AppendLine("--  ----------  -----------------  -------------------------------- ------")

    $anyEntityOrder = @($anyByEntity.Keys | Sort-Object { -$anyByEntity[$_].qidm.combinations.Count })
    foreach ($ent in $anyEntityOrder) {
        $at = $anyByEntity[$ent]
        $testNum++
        $shortName = Get-ComboShortName $at.kr
        $setNames = @()
        if ($at.combo.requirements -and $at.combo.requirements.set) { $setNames = @($at.combo.requirements.set) }
        $primaryField = Get-PrimaryField $at.kr $setNames
        $comboLabel = "$shortName+$(Get-ShortFieldLabel $primaryField)"
        $anyStr = ($at.anyFields | Select-Object -First 3) -join ', '
        [void]$sb.Append(("{0,2}  {1,-10}  {2,-17}  + {3,-29} " -f $testNum, $ent, $comboLabel, $anyStr))
        [void]$sb.AppendLine("[    ]")
        [void]$sb.AppendLine("              Expected: any[] fields present in XML output.")
    }
}

# ── CO-FIRE / DESELECT PHASE ──
$anyCofire = $false; $anyDeselect = $false
foreach ($ent in $entityOrder) {
    foreach ($q in $entityData[$ent].qidms) {
        if ($qidmRoles[$q.name] -eq 'COFIRE')  { $anyCofire = $true }
        if ($qidmRoles[$q.name] -eq 'DESELECT') { $anyDeselect = $true }
    }
}

if ($anyCofire -or $anyDeselect) {
    $phaseNum++
    $cfTests = 0
    if ($anyDeselect) { $cfTests++ }
    if ($anyCofire) { $cfTests++ }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("PHASE $phaseNum`: CO-FIRE / DESELECT VERIFICATION ($cfTests tests)")
    [void]$sb.AppendLine("-" * 72)
    [void]$sb.AppendLine("#   Entity      Action                                              Result")
    [void]$sb.AppendLine("--  ----------  --------------------------------------------------  ------")

    if ($anyDeselect) {
        $testNum++
        foreach ($qn in $deselectMap.Keys) {
            $q = $qidms | Where-Object { $_.name -eq $qn } | Select-Object -First 1
            if ($q) {
                $ent = $entityMap[$qn]
                $fromShort = Get-QueryAbbrev $q.query
                $toShort = ($deselectMap[$qn] | ForEach-Object { Get-QueryAbbrev $_ }) -join ', '
                [void]$sb.Append(("{0,2}  {1,-10}  " -f $testNum, $ent))
                [void]$sb.AppendLine("Deselect: $fromShort deselects $toShort.     [    ]")
                [void]$sb.AppendLine("              Fill both query fields. Check deselect behavior.")
                break
            }
        }
    }

    if ($anyCofire) {
        $testNum++
        # Pick entity with Options card + multiple QIDMs for routing test
        $routingEnt = $null
        foreach ($e in $entityOrder) {
            if ($entityData[$e].hasOptionsCard -and $entityData[$e].qidms.Count -gt 1) { $routingEnt = $e; break }
        }
        if (-not $routingEnt) {
            foreach ($e in $entityOrder) {
                if ($entityData[$e].qidms.Count -gt 1) { $routingEnt = $e; break }
            }
        }
        if ($routingEnt) {
            [void]$sb.Append(("{0,2}  {1,-10}  " -f $testNum, $routingEnt))
            [void]$sb.AppendLine("Priority routing: verify more-specific combo wins.  [    ]")
            [void]$sb.AppendLine("              Fill fields that match multiple combos, verify correct one fires.")
        }
    }
}

# ── NEGATIVES ──
$phaseNum++
[void]$sb.AppendLine("")
[void]$sb.AppendLine("PHASE $phaseNum`: NEGATIVES (empty forms = no send)")
[void]$sb.AppendLine("-" * 72)
[void]$sb.AppendLine("#   Entity      Action                                              Result")
[void]$sb.AppendLine("--  ----------  --------------------------------------------------  ------")
# Pick 1st and 3rd entities for variety (e.g., Vehicle + Person, not Vehicle + Boat)
$negEntities = @($entityOrder[0])
if ($entityOrder.Count -ge 3) { $negEntities += $entityOrder[2] }
elseif ($entityOrder.Count -ge 2) { $negEntities += $entityOrder[1] }
foreach ($ent in $negEntities) {
    $testNum++
    [void]$sb.Append(("{0,2}  {1,-10}  " -f $testNum, $ent))
    [void]$sb.AppendLine("Empty form, verify no Send button / no request.    [    ]")
}

# ── FOOTER ──
[void]$sb.AppendLine("")
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("TOTAL: $testNum tests")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("COMBO COVERAGE ($($combosCovered.Count)/$totalCombos):")
foreach ($q in $qidms) {
    $qCombos = $q.combinations
    $covered = 0; $refObjs = @()
    $uniquePrefixes = @($qCombos | ForEach-Object { Get-ComboShortName $(if ($_.keyReference) { $_.keyReference } else { $_.keyRef }) } | Select-Object -Unique)
    foreach ($c in $qCombos) {
        $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
        $qKey = "$($q.name)|$kr"
        if ($combosCovered.ContainsKey($qKey)) { $covered++ }
        if ($comboTestRefs.ContainsKey($qKey)) { $refObjs += $comboTestRefs[$qKey] }
    }
    $sortedRefs = @($refObjs | Sort-Object { $_.num })
    $role = $qidmRoles[$q.name]
    $stripPrefix = ($uniquePrefixes.Count -eq 1 -and $role -eq 'PRIMARY' -and -not $deselectMap.ContainsKey($q.name))
    $refs = @()
    foreach ($r in $sortedRefs) {
        $lbl = $r.label -replace '\+State$', '' -replace '\+Stolen$', ''
        if (-not $r.cofire -and $stripPrefix) {
            $pf = $uniquePrefixes[0]
            $lbl = $lbl -replace "^$([regex]::Escape($pf))\+", ''
        }
        $suffix = if ($r.cofire) { ' co-fire' } else { '' }
        $refs += "T$($r.num)($lbl$suffix)"
    }
    $refStr = if ($refs.Count -gt 0) { " -- $($refs -join ', ')" } else { '' }
    [void]$sb.AppendLine("  $($q.query): $covered/$($qCombos.Count)$refStr")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("IMPORT FILE: $fileName")

# ── Output ──
$result = $sb.ToString()

if ($OutFile) {
    [System.IO.File]::WriteAllText($OutFile, $result, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[PASS] Test matrix written to $OutFile ($testNum tests, $($combosCovered.Count)/$totalCombos combos)" -ForegroundColor Green
} else {
    Write-Output $result
}

Write-Host ""
Write-Host "  Tests: $testNum | Combos: $($combosCovered.Count)/$totalCombos | Entities: $($entityData.Count) | QIDMs: $totalQidms" -ForegroundColor Cyan
