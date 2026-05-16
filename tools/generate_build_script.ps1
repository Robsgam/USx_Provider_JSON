<#
  generate_build_script.ps1 -- Automated build script generator (Agent 1)
  Reads a provider's metadata XML and generates both BASE and MC build scripts
  that follow the exact patterns used by existing providers (FL_FCIC, NJ_NJCJIS, CA_CLETS).

  Usage:
    .\generate_build_script.ps1 -XmlPath <metadata.xml>
    .\generate_build_script.ps1 -XmlPath <metadata.xml> -DevdocPath <devdoc.txt>
    .\generate_build_script.ps1 -XmlPath <metadata.xml> -OutDir <scripts/>

  Output: Two runnable PowerShell build scripts:
    build_<provider>.ps1      (BASE -- single card per entity)
    build_<provider>_mc.ps1   (MC   -- multi-card per entity)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$XmlPath,
    [string]$DevdocPath,
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

# ── Resolve paths ────────────────────────────────────────────────────────────
$xmlResolved = Resolve-Path $XmlPath
$providerName = [System.IO.Path]::GetFileNameWithoutExtension($xmlResolved)

if (-not $OutDir) {
    $xmlDir = Split-Path $xmlResolved -Parent
    $parentDir = Split-Path $xmlDir -Parent
    $OutDir = Join-Path $parentDir 'scripts'
}
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$providerLower = $providerName.ToLower()

# ── Entity mapping from query name ───────────────────────────────────────────
$queryEntityMap = @{
    'VehicleRegistrationQuery' = 'Vehicle'
    'VehicleStolenQuery'       = 'Vehicle'
    'DriverLicenseQuery'       = 'Person'
    'DriverHistoryQuery'       = 'Person'
    'WantedPersonQuery'        = 'Person'
    'WMPIPersonWINQQuery'      = 'Person'
    'WMPIPersonMINQQuery'      = 'Person'
    'GunQuery'                 = 'Firearm'
    'ArticleSingleQuery'       = 'Article'
    'BoatQuery'                = 'Boat'
}

$queryLabelMap = @{
    'VehicleRegistrationQuery' = 'Vehicle Registration'
    'VehicleStolenQuery'       = 'Vehicle Stolen'
    'DriverLicenseQuery'       = 'Driver License'
    'DriverHistoryQuery'       = 'Driver History'
    'WantedPersonQuery'        = 'Wanted Person'
    'WMPIPersonWINQQuery'      = 'Wanted Person'
    'WMPIPersonMINQQuery'      = 'Missing Person'
    'GunQuery'                 = 'Firearm'
    'ArticleSingleQuery'       = 'Article'
    'BoatQuery'                = 'Boat'
}

$autoSelectQueries = @('VehicleRegistrationQuery','DriverLicenseQuery','DriverHistoryQuery','BoatQuery')

# ── PascalCase to camelCase ──────────────────────────────────────────────────
function ConvertTo-CamelCase([string]$s) {
    if (-not $s) { return $s }
    # Special cases for known acronym prefixes
    if ($s -eq 'NCICNumber' -or $s -eq 'NcicNumber') { return 'ncicNumber' }
    if ($s -eq 'ORI') { return 'ori' }
    # General: lowercase first letter
    if ($s -cmatch '^[A-Z]+$') { return $s.ToLower() }
    return $s.Substring(0,1).ToLower() + $s.Substring(1)
}

# ── Field type detection ─────────────────────────────────────────────────────
$optionsFields = @('State','RegistrationState','ImageIndicator','CaRequestPurposeCode','RandomRequest','RelatedHitSearchIndicator','PurposeCode')

function Get-FieldFormInfo([string]$fieldName, [string]$maxLen) {
    $info = @{ type = 'Inp'; label = $fieldName; extra = @{}; selProps = $null; isDate = $false; isName = $false; isOptions = $false }
    switch -Regex ($fieldName) {
        '^BirthDate' { $info.type = 'Dt'; $info.label = 'Date of Birth'; $info.isDate = $true }
        '^Name$' { $info.isName = $true; return $info }
        '^(State|RegistrationState)$' {
            $info.type = 'Sel'; $info.label = 'State'; $info.isOptions = $true
            $info.selProps = "@{ attributeTypeId = 'STATE' }"
        }
        '^ImageIndicator$' {
            $info.type = 'Sel'; $info.label = 'Image'; $info.isOptions = $true
            $info.selProps = "@{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' }"
        }
        '^LicensePlateTypeCode$' {
            $info.type = 'Sel'; $info.label = 'Plate Type'
            $info.selProps = "@{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' }"
        }
        '^VehicleMakeCode$' {
            $info.type = 'Sel'; $info.label = 'Vehicle Make'
            $info.selProps = "@{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' }"
        }
        '^(GunMake|FirearmMake)$' {
            $info.type = 'Sel'; $info.label = 'Gun Make'
            $info.selProps = "@{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' }"
        }
        '^GunCaliber$' {
            $info.type = 'Sel'; $info.label = 'Gun Caliber'
            $info.selProps = "@{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' }"
        }
        '^ArticleTypeCode$' {
            $info.type = 'Sel'; $info.label = 'Article Type'
            $info.selProps = "@{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' }"
        }
        '^(GunTypeCode|FirearmType.*)$' {
            $info.type = 'Sel'; $info.label = 'Gun Type'
            $info.selProps = "@{ codeTypeCategory = 'NCIC_FIREARM_TYPE'; codeTypeSource = 'NCIC' }"
        }
        '^SexCode$' {
            $info.type = 'Sel'; $info.label = 'Sex'
            $info.selProps = "@{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' }"
        }
        '^RandomRequest$' {
            $info.type = 'Sel'; $info.label = 'Random Request'; $info.isOptions = $true
            $info.selProps = "@{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' }"
        }
        '^CaRequestPurposeCode$' {
            $info.type = 'Inp'; $info.label = 'Purpose Code'; $info.isOptions = $true
            $info.extra = @{ initialValue = 'C'; size = '1' }
        }
        '^LicensePlateYear$' {
            $info.type = 'Inp'; $info.label = 'Plate Year'
            $info.extra = @{ initialValue = '$currentYear'; size = '4' }
        }
        '^VehicleYear$' { $info.type = 'Inp'; $info.label = 'Vehicle Year'; $info.extra = @{ size = '4' } }
        '^ProcessControlNumber$' { $info.type = 'Inp'; $info.label = 'PCN' }
        '^(NCICNumber|NcicNumber)$' { $info.type = 'Inp'; $info.label = 'NCIC Number' }
        '^RelatedHitSearchIndicator$' {
            $info.type = 'Inp'; $info.label = 'Stolen Search (Y)'; $info.isOptions = $true
            $info.extra = @{ size = '1' }
        }
        '^PurposeCode$' { $info.type = 'Inp'; $info.label = 'Purpose Code'; $info.isOptions = $true; $info.extra = @{ size = '1' } }
        '^LicensePlateNumber$' { $info.label = 'Plate Number' }
        '^VehicleIdentificationNumber$' { $info.label = 'VIN' }
        '^OperatorLicenseNumber$' { $info.label = 'OLN' }
        '^GunSerialNumber$' { $info.label = 'Serial Number' }
        '^ArticleSerialNumber$' { $info.label = 'Serial Number' }
        '^OwnerAppliedNumber$' { $info.label = 'Owner Applied Number' }
        '^BoatHullIdNumber$' { $info.label = 'Hull ID Number' }
        '^RegistrationNumber$' { $info.label = 'Registration Number' }
        '^CoastGuardDocumentNumber$' { $info.label = 'Coast Guard Doc #' }
        '^TitleLienInformation$' { $info.label = 'Title/Lien Info' }
        '^DecalNumber$' { $info.label = 'Decal Number' }
        '^Attention$' { $info.label = 'Attention' }
        default {
            $info.label = ($fieldName -creplace '([A-Z])', ' $1').Trim()
        }
    }
    return $info
}

# ── Parse metadata XML ──────────────────────────────────────────────────────
[xml]$metadata = Get-Content $xmlResolved -Raw
$nsm = New-Object System.Xml.XmlNamespaceManager($metadata.NameTable)
$defaultNs = $metadata.DocumentElement.NamespaceURI
if ($defaultNs) { $nsm.AddNamespace('ns', $defaultNs) }
$nsPrefix = if ($defaultNs) { 'ns:' } else { '' }

function Parse-Requirements($reqNode, $nsMgr, $pre) {
    $result = @{ set = @(); any = @() }
    if (-not $reqNode) { return $result }
    $setNode = $reqNode.SelectSingleNode("${pre}Set", $nsMgr)
    if (-not $setNode) { return $result }
    foreach ($child in $setNode.ChildNodes) {
        if ($child.LocalName -eq 'Field') { $result.set += $child.GetAttribute('reference') }
        elseif ($child.LocalName -eq 'Any') {
            foreach ($f in $child.ChildNodes) {
                if ($f.LocalName -eq 'Field') { $result.any += $f.GetAttribute('reference') }
            }
        }
    }
    return $result
}

$transactions = [ordered]@{}
foreach ($txNode in $metadata.SelectNodes("//${nsPrefix}Transaction[@name]", $nsm)) {
    $txName = $txNode.GetAttribute('name')
    $txVersion = $txNode.GetAttribute('version')

    $fields = @()
    $fieldsNode = $txNode.SelectSingleNode("${nsPrefix}Fields", $nsm)
    if ($fieldsNode) {
        foreach ($f in $fieldsNode.ChildNodes) {
            if ($f.LocalName -eq 'Field') {
                $fields += @{
                    name      = $f.GetAttribute('name')
                    type      = $f.GetAttribute('type')
                    maxLength = $f.GetAttribute('maxLength')
                }
            }
        }
    }

    $combos = @()
    $combosNode = $txNode.SelectSingleNode("${nsPrefix}Combinations", $nsm)
    if ($combosNode) {
        foreach ($c in $combosNode.ChildNodes) {
            if ($c.LocalName -ne 'Combination') { continue }
            $kr = $c.GetAttribute('keyReference')
            $pf = $c.GetAttribute('primaryFieldReference')
            $reqNode = $c.SelectSingleNode("${nsPrefix}Requirements", $nsm)
            $reqs = Parse-Requirements $reqNode $nsm $nsPrefix
            $combos += @{ keyReference = $kr; primaryField = $pf; requirements = $reqs }
        }
    }

    if (-not $transactions.Contains($txName)) {
        $transactions[$txName] = @{ version = $txVersion; fields = $fields; combos = $combos }
    } else {
        $transactions[$txName].combos += $combos
    }
}

# ── Filter by devdoc if provided ─────────────────────────────────────────────
$supportedQueries = @($transactions.Keys)
if ($DevdocPath -and (Test-Path $DevdocPath)) {
    $devdocText = Get-Content $DevdocPath -Raw
    $filtered = @()
    foreach ($qName in $transactions.Keys) {
        if ($devdocText -match [regex]::Escape($qName)) { $filtered += $qName }
    }
    if ($filtered.Count -gt 0) { $supportedQueries = $filtered }
}

# ── Detect DH-suffix need ────────────────────────────────────────────────────
$hasDL = $supportedQueries -contains 'DriverLicenseQuery'
$hasDH = $supportedQueries -contains 'DriverHistoryQuery'
$needDhSuffix = $hasDL -and $hasDH

# ── Detect CaRequestPurposeCode ─────────────────────────────────────────────
$hasCaPurpose = $false
foreach ($qName in $supportedQueries) {
    $tx = $transactions[$qName]
    if (-not $tx) { continue }
    foreach ($f in $tx.fields) {
        if ($f.name -eq 'CaRequestPurposeCode') { $hasCaPurpose = $true; break }
    }
    if ($hasCaPurpose) { break }
}

# ── Group transactions by entity ─────────────────────────────────────────────
$entityQueries = [ordered]@{}
$entityFields = [ordered]@{}
$allQidmData = [ordered]@{}

foreach ($qName in $supportedQueries) {
    $entity = $queryEntityMap[$qName]
    if (-not $entity) { continue }
    $tx = $transactions[$qName]
    if (-not $tx) { continue }

    if (-not $entityQueries.Contains($entity)) { $entityQueries[$entity] = @() }
    $entityQueries[$entity] += $qName

    if (-not $entityFields.Contains($entity)) { $entityFields[$entity] = [ordered]@{} }

    $isDH = ($qName -eq 'DriverHistoryQuery' -and $needDhSuffix)
    $dhSuffix = if ($isDH) { 'DH' } else { '' }

    $qidmFields = @()
    $qidmCombos = @()
    $hasNameField = $false
    $nameSize = 30

    foreach ($f in $tx.fields) {
        $fname = $f.name
        $fmax = $f.maxLength
        if ($fname -eq 'Name') {
            $hasNameField = $true
            if ($fmax) { $nameSize = [int]$fmax }
            continue
        }
        # State/RegistrationState -> registrationState (standard form fieldId)
        if ($fname -eq 'State' -or $fname -eq 'RegistrationState') {
            $camelId = 'registrationState'
            if ($isDH) { $camelId = "registrationState$dhSuffix" }
            if (-not $entityFields[$entity].Contains($camelId)) {
                $entityFields[$entity][$camelId] = @{ pascalName = 'RegistrationState'; maxLength = $fmax; fromQuery = $qName; dhSuffix = $isDH }
            }
            $qidmFields += @{ pascalName = $fname; camelId = $camelId; maxLength = $fmax; isDH = $isDH }
            continue
        }
        $camelId = ConvertTo-CamelCase $fname
        if ($isDH -and $fname -notin @('CaRequestPurposeCode')) {
            $camelId = $camelId + $dhSuffix
        }
        if (-not $entityFields[$entity].Contains($camelId)) {
            $entityFields[$entity][$camelId] = @{ pascalName = $fname; maxLength = $fmax; fromQuery = $qName; dhSuffix = $isDH }
        }
        $qidmFields += @{ pascalName = $fname; camelId = $camelId; maxLength = $fmax; isDH = $isDH }
    }
    if ($hasNameField) {
        $lastId = if ($isDH) { "nameLast$dhSuffix" } else { 'nameLast' }
        $firstId = if ($isDH) { "nameFirst$dhSuffix" } else { 'nameFirst' }
        if (-not $entityFields[$entity].Contains($lastId)) {
            $entityFields[$entity][$lastId] = @{ pascalName = 'NameLast'; maxLength = '30'; fromQuery = $qName; dhSuffix = $isDH }
        }
        if (-not $entityFields[$entity].Contains($firstId)) {
            $entityFields[$entity][$firstId] = @{ pascalName = 'NameFirst'; maxLength = '30'; fromQuery = $qName; dhSuffix = $isDH }
        }
        $qidmFields += @{ pascalName = 'Name'; camelId = $null; maxLength = $nameSize; isDH = $isDH; isComposite = $true }
    }

    foreach ($c in $tx.combos) {
        $setFields = @()
        foreach ($sf in $c.requirements.set) {
            if ($sf -eq 'Name') {
                $setFields += if ($isDH) { "nameLast$dhSuffix" } else { 'nameLast' }
                $setFields += if ($isDH) { "nameFirst$dhSuffix" } else { 'nameFirst' }
                continue
            }
            if ($sf -eq 'State' -or $sf -eq 'RegistrationState') {
                $setFields += if ($isDH) { "registrationState$dhSuffix" } else { 'registrationState' }
                continue
            }
            $cc = ConvertTo-CamelCase $sf
            if ($isDH -and $sf -notin @('CaRequestPurposeCode')) { $cc = $cc + $dhSuffix }
            $setFields += $cc
        }
        $anyFields = @()
        foreach ($af in $c.requirements.any) {
            if ($af -eq 'Name') {
                $anyFields += if ($isDH) { "nameLast$dhSuffix" } else { 'nameLast' }
                $anyFields += if ($isDH) { "nameFirst$dhSuffix" } else { 'nameFirst' }
                continue
            }
            if ($af -eq 'State' -or $af -eq 'RegistrationState') {
                $anyFields += if ($isDH) { "registrationState$dhSuffix" } else { 'registrationState' }
                continue
            }
            $cc = ConvertTo-CamelCase $af
            if ($isDH -and $af -notin @('CaRequestPurposeCode')) { $cc = $cc + $dhSuffix }
            $anyFields += $cc
        }
        $qidmCombos += @{ keyReference = $c.keyReference; primaryField = $c.primaryField; set = $setFields; any = $anyFields }
    }

    $allQidmData[$qName] = @{
        entity     = $entity
        fields     = $qidmFields
        combos     = $qidmCombos
        hasName    = $hasNameField
        nameSize   = $nameSize
        isDH       = $isDH
        dhSuffix   = $dhSuffix
        version    = $tx.version
    }
}

# ── Helper: detect date format from provider name ────────────────────────────
$dateFormat = 'MMddyyyy'
if ($providerName -match '^(FL_|CA_)') { $dateFormat = 'yyyyMMdd' }

# ── Helper: build attribute line ─────────────────────────────────────────────
function Format-Attribute($fname, $camelId, $maxLen, $isDH, $dhSuffix, $hasNameComposite, $nameSize) {
    $pad = 60
    if ($fname -eq 'Name' -and $hasNameComposite) {
        $lastSrc = if ($isDH) { "nameLast$dhSuffix" } else { 'nameLast' }
        $firstSrc = if ($isDH) { "nameFirst$dhSuffix" } else { 'nameFirst' }
        $line = "        [PSCustomObject]@{`n"
        $line += "            name = 'Name'; size = $nameSize; sourceField = @('$lastSrc','$firstSrc'); targetField = 'Name'`n"
        $line += "            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(',') }`n"
        $line += "        }"
        return $line
    }
    if ($fname -match '^BirthDate') {
        $srcId = if ($isDH) { "birthDate$dhSuffix" } else { 'birthDate' }
        $line = "        [PSCustomObject]@{`n"
        $line += "            name = 'BirthDate'; size = $maxLen; sourceField = @('$srcId'); targetField = 'BirthDate'`n"
        $line += "            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','$dateFormat') }`n"
        $line += "        }"
        return $line
    }
    if ($fname -match '^(State|RegistrationState)$') {
        $srcId = if ($isDH) { "registrationState$dhSuffix" } else { 'registrationState' }
        return "        [PSCustomObject]@{ name = 'State'; size = $maxLen; sourceField = @('$srcId'); targetField = 'State'; codeTypeProvider = 'NCIC' }"
    }
    if ($fname -eq 'SexCode') {
        $srcId = if ($isDH) { "sexCode$dhSuffix" } else { 'sexCode' }
        return "        [PSCustomObject]@{ name = 'SexCode'; size = $maxLen; sourceField = @('$srcId'); targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }"
    }
    $sizeStr = if ($maxLen) { " size = $maxLen;" } else { '' }
    return "        [PSCustomObject]@{ name = '$fname';$sizeStr sourceField = @('$camelId'); targetField = '$fname' }"
}

# ── Helper: build combo line ─────────────────────────────────────────────────
function Format-Combo($kr, $pf, $setArr, $anyArr) {
    $setStr = ($setArr | ForEach-Object { "'$_'" }) -join ','
    $anyStr = if ($anyArr.Count -gt 0) { ($anyArr | ForEach-Object { "'$_'" }) -join ',' } else { '' }
    $line = "        [PSCustomObject]@{`n"
    $line += "            requirements          = [PSCustomObject]@{ set = @($setStr); any = @($anyStr) }`n"
    $line += "            primaryFieldReference = '$pf'`n"
    $line += "            keyReference          = '$kr'`n"
    $line += "            state                 = 'In/Out'`n"
    $line += "        }"
    return $line
}

# ── Helper: build field node line for layout ─────────────────────────────────
function Format-FieldNode($camelId, $pascalName, $maxLen, $rowId, $isDH, $dhLabel) {
    $info = Get-FieldFormInfo $pascalName $maxLen
    $labelSuffix = if ($isDH -and $dhLabel) { " ($dhLabel)" } else { '' }
    $label = $info.label + $labelSuffix
    $nodeId = "${camelId}_Input"

    if ($info.type -eq 'Dt') {
        return "                @{ id = '${nodeId}'; node = Dt  '$camelId' '$label' '$rowId' }"
    }
    if ($info.type -eq 'Sel' -and $info.selProps) {
        return "                @{ id = '${nodeId}'; node = Sel '$camelId' '$label' $($info.selProps) '$rowId' }"
    }
    $maxArg = if ($maxLen) { "'$maxLen'" } else { "''" }
    if ($info.extra.Count -gt 0) {
        $extraParts = @()
        foreach ($k in $info.extra.Keys) {
            $v = $info.extra[$k]
            if ($v -eq '$currentYear') {
                $extraParts += "$k = `$currentYear"
            } else {
                $extraParts += "$k = '$v'"
            }
        }
        $extraStr = '@{ ' + ($extraParts -join '; ') + ' }'
        return "                @{ id = '${nodeId}'; node = Inp '$camelId' '$label' $maxArg '$rowId' $extraStr }"
    }
    return "                @{ id = '${nodeId}'; node = Inp '$camelId' '$label' $maxArg '$rowId' }"
}

# ── Helper: arrange fields into rows (2-column default) ─────────────────────
function Build-LayoutRows($fieldList, $rowPrefix, [int]$startIdx = 1) {
    $rows = @()
    $idx = $startIdx
    $i = 0
    while ($i -lt $fieldList.Count) {
        $remaining = $fieldList.Count - $i
        if ($remaining -ge 3 -and $remaining % 2 -ne 0) {
            $cols = @('4','4','4')
            $rowFields = @($fieldList[$i], $fieldList[$i+1], $fieldList[$i+2])
            $i += 3
        } elseif ($remaining -ge 2) {
            $cols = @('6','6')
            $rowFields = @($fieldList[$i], $fieldList[$i+1])
            $i += 2
        } else {
            $cols = @('12')
            $rowFields = @($fieldList[$i])
            $i += 1
        }
        $rows += @{ id = "${rowPrefix}_${idx}"; cols = $cols; fields = $rowFields }
        $idx++
    }
    return $rows
}

# ── Count totals ─────────────────────────────────────────────────────────────
$totalQidms = $allQidmData.Count
$totalCombos = 0
foreach ($qd in $allQidmData.Values) { $totalCombos += $qd.combos.Count }
$totalEntities = $entityQueries.Count

$entityOrder = @()
foreach ($e in @('Person','Vehicle','Firearm','Article','Boat')) {
    if ($entityQueries.Contains($e)) { $entityOrder += $e }
}

$entityAbbr = @{ Vehicle = 'VEH'; Person = 'PER'; Firearm = 'GUN'; Article = 'ART'; Boat = 'BOA' }
$entityVarPrefix = @{ Vehicle = 'veh'; Person = 'per'; Firearm = 'gun'; Article = 'art'; Boat = 'boa' }

# ── Build QIDM code blocks ──────────────────────────────────────────────────
function Build-QidmBlock($qName) {
    $qd = $allQidmData[$qName]
    $entity = $qd.entity
    $isDH = $qd.isDH
    $dhSuffix = $qd.dhSuffix
    $varName = '$' + ($qName.Substring(0,1).ToLower() + $qName.Substring(1) -replace 'Query$','Query')
    $queryLabel = $queryLabelMap[$qName]
    if (-not $queryLabel) { $queryLabel = ($qName -replace 'Query$','') }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# --- $qName ($($qd.combos.Count) combos) ---")
    [void]$sb.AppendLine("$varName = [PSCustomObject]@{")
    [void]$sb.AppendLine("    attributes = @(")

    $sortedFields = @($qd.fields | Sort-Object { $_.pascalName })
    foreach ($f in $sortedFields) {
        if ($f.isComposite) {
            [void]$sb.AppendLine((Format-Attribute 'Name' $null $f.maxLength $isDH $dhSuffix $true $f.maxLength))
        } else {
            [void]$sb.AppendLine((Format-Attribute $f.pascalName $f.camelId $f.maxLength $isDH $dhSuffix $false 0))
        }
    }
    [void]$sb.AppendLine("    )")

    [void]$sb.AppendLine("    combinations = @(")
    foreach ($c in $qd.combos) {
        [void]$sb.AppendLine((Format-Combo $c.keyReference $c.primaryField $c.set $c.any))
    }
    [void]$sb.AppendLine("    )")

    [void]$sb.AppendLine("    description     = '$qName -- $($qd.combos.Count) combos.'")
    [void]$sb.AppendLine("    handlerFunction = 'CommsysTransactionRequestHandler'")
    [void]$sb.AppendLine("    name            = `"`${provider}_$qName`"")
    [void]$sb.AppendLine("    type            = 'QUERYINPUTDATAMAPPING'")
    if ($qName -in $autoSelectQueries) {
        [void]$sb.AppendLine("    autoSelect      = `$true")
    }
    [void]$sb.AppendLine("    provider        = `$provider")
    [void]$sb.AppendLine("    providerType    = 'Commsys'")
    [void]$sb.AppendLine("    query           = '$qName'")
    [void]$sb.AppendLine("    queryLabel      = '$queryLabel'")
    [void]$sb.AppendLine("    targetEntity    = '$entity'")
    if ($qName -eq 'DriverHistoryQuery' -and $needDhSuffix) {
        [void]$sb.AppendLine("    queriesToDeselect = @('DriverLicenseQuery')")
    }
    if ($qName -eq 'VehicleStolenQuery' -and ($supportedQueries -contains 'VehicleRegistrationQuery')) {
        # VehicleStolen: NO queriesToDeselect (one-directional pattern)
    }
    if ($qName -eq 'VehicleRegistrationQuery' -and ($supportedQueries -contains 'VehicleStolenQuery')) {
        [void]$sb.AppendLine("    queriesToDeselect = @('VehicleStolenQuery')")
    }
    [void]$sb.AppendLine("}")
    return $sb.ToString()
}

# ── Build layout blocks ──────────────────────────────────────────────────────
function Build-BaseLayoutBlock($entity) {
    $abbr = $entityAbbr[$entity]
    $vp = $entityVarPrefix[$entity]
    $fields = $entityFields[$entity]
    if (-not $fields -or $fields.Count -eq 0) { return '' }

    $cardId = "CARD_$abbr"
    $rowPrefix = "ROW_$abbr"
    $title = ($entity.ToUpper()) + ' SEARCH'
    if ($entity -eq 'Firearm') { $title = 'FIREARM QUERY' }
    if ($entity -eq 'Article') { $title = 'ARTICLE QUERY' }

    $fieldNodes = @()
    foreach ($fid in $fields.Keys) {
        $fdata = $fields[$fid]
        $isDH = $fdata.dhSuffix
        $dhLabel = if ($isDH) { 'DH' } else { '' }
        $fieldNodes += @{ camelId = $fid; pascalName = $fdata.pascalName; maxLen = $fdata.maxLength; isDH = $isDH; dhLabel = $dhLabel }
    }

    $rows = Build-LayoutRows $fieldNodes $rowPrefix
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("`$${vp}Layout = MakeLayouts @(")
    Emit-Card $sb $cardId $title $rows
    [void]$sb.AppendLine(")")
    return $sb.ToString()
}

function Emit-Card($sb, $cardId, $title, $rows) {
    [void]$sb.AppendLine("    @{")
    [void]$sb.AppendLine("        id    = '$cardId'")
    [void]$sb.AppendLine("        title = '$title'")
    [void]$sb.AppendLine("        rows  = @(")
    foreach ($row in $rows) {
        $colStr = ($row.cols | ForEach-Object { "'$_'" }) -join ','
        [void]$sb.AppendLine("            @{ id = '$($row.id)'; cols = @($colStr); fields = @(")
        foreach ($fn in $row.fields) {
            [void]$sb.AppendLine((Format-FieldNode $fn.camelId $fn.pascalName $fn.maxLen $row.id $fn.isDH $fn.dhLabel))
        }
        [void]$sb.AppendLine("            )}")
    }
    [void]$sb.AppendLine("        )")
    [void]$sb.AppendLine("    }")
}

function Build-McLayoutBlock($entity) {
    $abbr = $entityAbbr[$entity]
    $vp = $entityVarPrefix[$entity]
    $fields = $entityFields[$entity]
    if (-not $fields -or $fields.Count -eq 0) { return '' }

    $optFields = @()
    $searchFields = @()
    $dhFields = @()

    foreach ($fid in $fields.Keys) {
        $fdata = $fields[$fid]
        $isDH = $fdata.dhSuffix
        $isOpt = $fdata.pascalName -in $optionsFields
        if ($isDH) {
            $dhFields += @{ camelId = $fid; pascalName = $fdata.pascalName; maxLen = $fdata.maxLength; isDH = $true; dhLabel = 'DH' }
        } elseif ($isOpt) {
            $optFields += @{ camelId = $fid; pascalName = $fdata.pascalName; maxLen = $fdata.maxLength; isDH = $false; dhLabel = '' }
        } else {
            $searchFields += @{ camelId = $fid; pascalName = $fdata.pascalName; maxLen = $fdata.maxLength; isDH = $false; dhLabel = '' }
        }
    }

    $needOptionsCard = $optFields.Count -gt 0
    $needDhCard = $dhFields.Count -gt 0
    $needMultiCard = $needOptionsCard -or $needDhCard

    if (-not $needMultiCard) { return Build-BaseLayoutBlock $entity }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("`$${vp}Layout = MakeLayouts @(")
    $cardIdx = 0

    if ($needOptionsCard) {
        Emit-Card $sb "CARD_${abbr}_OPT" 'Options' (Build-LayoutRows $optFields "ROW_${abbr}_OPT")
    }

    if ($searchFields.Count -gt 0) {
        $searchCardId = if ($entity -eq 'Person' -and $needDhCard) { "CARD_DL" } else { "CARD_${abbr}_SEARCH" }
        $searchRowPrefix = if ($entity -eq 'Person' -and $needDhCard) { "ROW_DL" } else { "ROW_${abbr}" }
        $searchTitle = if ($entity -eq 'Person' -and $needDhCard) { 'Driver License' } else { "$entity Search" }
        Emit-Card $sb $searchCardId $searchTitle (Build-LayoutRows $searchFields $searchRowPrefix)
    }

    if ($needDhCard) {
        Emit-Card $sb 'CARD_DH' 'Driver History' (Build-LayoutRows $dhFields 'ROW_DH')
    }

    [void]$sb.AppendLine(")")
    return $sb.ToString()
}

# ── Build entity form block ──────────────────────────────────────────────────
function Build-EntityFormBlock($entity, $varSuffix) {
    $vp = $entityVarPrefix[$entity]
    $queries = $entityQueries[$entity]
    $queryDesc = ($queries -join ' + ')
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("`$${vp}Form = [PSCustomObject]@{")
    [void]$sb.AppendLine("    description  = '$entity queries -- $queryDesc'")
    [void]$sb.AppendLine("    label        = '$entity'")
    [void]$sb.AppendLine("    layout       = `$${vp}Layout")
    [void]$sb.AppendLine("    name         = 'ENTITY_$entity'")
    [void]$sb.AppendLine("    type         = 'QUERYINPUTFORM'")
    [void]$sb.AppendLine("    targetEntity = '$entity'")
    [void]$sb.AppendLine("}")
    return $sb.ToString()
}

# ── Build header comment ─────────────────────────────────────────────────────
function Build-Header($variant) {
    $sb = [System.Text.StringBuilder]::new()
    $varLabel = if ($variant -eq 'BASE') { 'BASE (single card)' } else { 'MC (multi-card)' }
    [void]$sb.AppendLine("# build_${providerLower}.ps1 -- $providerName $varLabel")
    if ($variant -eq 'MC') {
        [void]$sb.Replace("build_${providerLower}.ps1", "build_${providerLower}_mc.ps1")
    }
    [void]$sb.AppendLine("# AUTO-GENERATED by generate_build_script.ps1 -- Review before use")
    [void]$sb.AppendLine("# Source: $([System.IO.Path]::GetFileName($xmlResolved))")
    [void]$sb.AppendLine("#")
    [void]$sb.AppendLine("# QUERYINPUTDATAMAPPING (CommSys -- $totalQidms QIDMs, $totalCombos combos):")
    foreach ($qName in $supportedQueries) {
        $qd = $allQidmData[$qName]
        if (-not $qd) { continue }
        $ql = $queryLabelMap[$qName]
        if (-not $ql) { $ql = $qName }
        $krs = ($qd.combos | ForEach-Object { $_.keyReference }) -join '/'
        [void]$sb.AppendLine("#   $($qName.PadRight(30)) $krs = $($qd.combos.Count) combos")
    }
    [void]$sb.AppendLine("#")
    [void]$sb.AppendLine("# ENTITIES ($totalEntities QUERYINPUTFORM):")
    foreach ($e in $entityOrder) {
        $fids = @($entityFields[$e].Keys)
        $sample = ($fids | Select-Object -First 6) -join ', '
        if ($fids.Count -gt 6) { $sample += ', ...' }
        [void]$sb.AppendLine("#   $($e.PadRight(10)) -- $sample")
    }
    [void]$sb.AppendLine("")
    return $sb.ToString()
}

# ── Assemble complete script ─────────────────────────────────────────────────
function Build-Script($variant) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append((Build-Header $variant))

    [void]$sb.AppendLine("param(")
    [void]$sb.AppendLine("    [string]`$Version = `"1.0`"")
    [void]$sb.AppendLine(")")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("`$ErrorActionPreference = 'Stop'")
    [void]$sb.AppendLine("`$provider = '$providerName'")
    $jsonSuffix = if ($variant -eq 'BASE') { 'BASE' } else { 'MC' }
    [void]$sb.AppendLine("`$outPath  = `"`$PSScriptRoot\..\${providerName}_${jsonSuffix}.json`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("`$currentYear = [string](Get-Date).Year")
    [void]$sb.AppendLine(". `"`$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine(". `"`$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1`"")
    [void]$sb.AppendLine(". `"`$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1`"")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("# BUNDLE 1: $providerName PROVIDER")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("`$auth = Build-Auth -ProviderName '$providerName'")
    [void]$sb.AppendLine("`$results = Build-ProviderQrdm -ProviderName '$providerName'")
    [void]$sb.AppendLine("`$qmf = Build-Qmf -ProviderName '$providerName'")
    [void]$sb.AppendLine("")

    # QIDMs
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("# $totalQidms COMMSYS QIDMs")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("")

    $qidmVarNames = @()
    foreach ($qName in $supportedQueries) {
        if (-not $allQidmData.Contains($qName)) { continue }
        [void]$sb.Append((Build-QidmBlock $qName))
        [void]$sb.AppendLine("")
        $varName = '$' + ($qName.Substring(0,1).ToLower() + $qName.Substring(1) -replace 'Query$','Query')
        $qidmVarNames += $varName
    }

    # Provider bundle
    $configList = @('$auth', '$results', '$qmf') + $qidmVarNames
    $configStr = $configList -join ', '
    [void]$sb.AppendLine("`$providerBundle = [PSCustomObject]@{")
    [void]$sb.AppendLine("    configurations = @($configStr)")
    [void]$sb.AppendLine("    description    = `"Provider configuration for `$provider v`$Version`"")
    [void]$sb.AppendLine("    name           = `$provider")
    [void]$sb.AppendLine("    type           = 'BUNDLE'")
    [void]$sb.AppendLine("    provider       = `$provider")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")

    # Entity layouts
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("# BUNDLE 2: ENTITIES ($totalEntities QUERYINPUTFORM)")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("")

    $formVarNames = @()
    foreach ($e in $entityOrder) {
        $vp = $entityVarPrefix[$e]
        if ($variant -eq 'BASE') {
            [void]$sb.Append((Build-BaseLayoutBlock $e))
        } else {
            [void]$sb.Append((Build-McLayoutBlock $e))
        }
        [void]$sb.Append((Build-EntityFormBlock $e $variant))
        [void]$sb.AppendLine("")
        $formVarNames += "`$$($vp)Form"
    }

    $formStr = $formVarNames -join ', '
    $orderStr = ($entityOrder | ForEach-Object { "'$_'" }) -join ','
    [void]$sb.AppendLine("`$entitiesBundle = Build-EntitiesBundle -Configurations @($formStr) ``")
    [void]$sb.AppendLine("    -DefaultOrder @($orderStr)")
    [void]$sb.AppendLine("")

    # RMS + assembly
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("# BUNDLE 3: RMS (from KB specs)")
    [void]$sb.AppendLine("# =====================================================================")
    [void]$sb.AppendLine("`$rmsBundle = Build-RmsBundle")
    [void]$sb.AppendLine("`$output = [PSCustomObject]@{")
    [void]$sb.AppendLine("    bundles = @(`$entitiesBundle, `$providerBundle, `$rmsBundle)")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")

    $readSuffix = "${providerName}_${jsonSuffix}_READABLE.json"
    [void]$sb.AppendLine("`$outPathReadable = `"`$PSScriptRoot\..\$readSuffix`"")
    [void]$sb.AppendLine("Write-ProviderJson -BundleObject `$output -OutPath `$outPath -ReadablePath `$outPathReadable ``")
    [void]$sb.AppendLine("    -Label `"Built $providerName v`${Version}`"")

    return $sb.ToString()
}

# ── Generate both scripts ────────────────────────────────────────────────────
$baseScript = Build-Script 'BASE'
$mcScript = Build-Script 'MC'

$basePath = Join-Path $OutDir "build_${providerLower}.ps1"
$mcPath = Join-Path $OutDir "build_${providerLower}_mc.ps1"

[System.IO.File]::WriteAllText($basePath, $baseScript, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($mcPath,   $mcScript,   [System.Text.UTF8Encoding]::new($false))

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[PASS] Generated build_${providerLower}.ps1 (BASE) -- $totalQidms QIDMs, $totalCombos combos, $totalEntities entities" -ForegroundColor Green
Write-Host "[PASS] Generated build_${providerLower}_mc.ps1 (MC) -- $totalQidms QIDMs, $totalCombos combos, $totalEntities entities" -ForegroundColor Green
Write-Host ""
Write-Host "Output: $basePath" -ForegroundColor Cyan
Write-Host "Output: $mcPath" -ForegroundColor Cyan

if ($needDhSuffix) {
    Write-Host ""
    Write-Host "# TODO: DH-suffix detected (DL+DH both present). Review DH card fields and combo requirements." -ForegroundColor Yellow
}
if ($hasCaPurpose) {
    Write-Host ""
    Write-Host "# TODO: CaRequestPurposeCode detected. Review initialValue and visibility (Inp visible vs InpH hidden)." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "# TODO: Review generated scripts before running. Check:" -ForegroundColor Yellow
Write-Host "#   1. Combo ordering (most-specific set[] first)" -ForegroundColor Yellow
Write-Host "#   2. Date format arguments (currently: $dateFormat)" -ForegroundColor Yellow
Write-Host "#   3. State initialValue (currently: no default per LIMITATION #30)" -ForegroundColor Yellow
Write-Host "#   4. ImageIndicator initialValue (currently: N for vehicle, check per entity)" -ForegroundColor Yellow
Write-Host "#   5. Field labels and layout column widths" -ForegroundColor Yellow
Write-Host "#   6. queriesToDeselect direction (currently: one-directional)" -ForegroundColor Yellow
