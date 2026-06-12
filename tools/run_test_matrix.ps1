<#
  run_test_matrix.ps1 -- Automated Test Conductor (Agent 3)
  Reads a test matrix file, loads the provider JSON, and validates each test
  case using combo-matching logic from test_commsys.ps1. Produces a PASS/FAIL
  results report per phase.

  Usage: .\run_test_matrix.ps1 -Path <provider.json> [-Matrix <matrix.txt>] [-OutFile <path>]
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Matrix,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json
$fileName = Split-Path $Path -Leaf
$baseName = $fileName -replace '\.json$',''

if (-not $Matrix) {
    $jsonDir = Split-Path (Resolve-Path $Path) -Parent
    $docsDir = Join-Path $jsonDir "docs"
    $Matrix = Join-Path $docsDir "${baseName}_TEST_MATRIX.txt"
}

if (-not (Test-Path $Matrix)) { Write-Error "Test matrix not found: $Matrix"; exit 1 }

$matrixText = [System.IO.File]::ReadAllText((Resolve-Path $Matrix), [System.Text.UTF8Encoding]::new($false))
$matrixLines = $matrixText -split "`r?`n"

$entBundle  = $json.bundles | Where-Object { $_.name -eq 'ENTITIES' }
$provBundle = $json.bundles | Where-Object { $_.name -ne 'ENTITIES' -and $_.name -ne 'RMS' }

$qidms = @()
foreach ($cfg in $provBundle.configurations) {
    if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
        $qidms += $cfg
    }
}

$qifs = @($entBundle.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' })

$testData = @{}
$testData["Person"] = @{
    caRequestPurposeCode="C"; OperatorLicenseNumber="D123456789"
    RegistrationState="NJ"; State="NY"; NameFirst="John"; NameLast="Doe"
    NameMiddle="A"; NameSuffix=""; BirthDate="1990-01-15"; SexCode="M"; ImageIndicator="Y"
    OperatorLicenseNumberDH="D123456789"; NameFirstDH="John"; NameLastDH="Doe"
    NameMiddleDH="A"; NameSuffixDH=""; BirthDateDH="1990-01-15"; SexCodeDH="M"
    RegistrationStateDH="GA"; PurposeCodeDH="C"; PurposeCode="D"
    caRequestPurposeCodeDH="C"
    Attention="DISPATCHER JONES"; Requestor="DISPATCHER JONES"
    NyNyspinTransactionName="DALL"; dexStateUserId="BADGE"; StateDH="AZ"
    SocialSecurityNumber="123456789"; RaceCode="W"; NCICNumber="W123456789"
    Age="30"; Height="510"; Weight="180"; EyeColorCode="BRO"; HairColorCode="BLK"
    RelatedHitSearchIndicator="Y"; ExpandedNameSearchCode="E"
    ExpandedBirthDateSearchCode="E"; ExpandedBirthDateSearchIndicator="Y"
    InquiryLevel="1"; MiscellaneousDescriptiveText="TEST QUERY"
    AreaCode="602"; FormORI="MK1234567"; AttentionDH="DISPATCHER JONES"
}
$testData["Vehicle"] = @{
    caRequestPurposeCode="C"; LicensePlateNumber="ABC1234"; LicensePlateYear="2024"
    LicensePlateTypeCode="PC"; RegistrationState="NJ"; State="NJ"
    VehicleIdentificationNumber="1HGCM82633A123456"; VINSequenceNumber="01"
    DecalNumber="FL12345678"; TitleLienInformation="ABCD1234"
    VehicleMakeCode="FORD"; VehicleTypeCode="1"; VehicleYear="2023"
    RandomRequest="N"; NCICNumber="V123456789"; ImageIndicator="Y"
    RelatedHitSearchIndicator="Y"; dexStateUserId="BADGE"
    NameFirst="John"; NameLast="Doe"
}
$testData["Firearm"] = @{
    caRequestPurposeCode="C"; serialNumber="ABC12345"; GunSerialNumber="ABC12345"
    firearmMake="SMTH"; GunMake="SMTH"; GunCaliber="9MM"; GunModel="M&P"
    NCICNumber="G123456789"; ProcessControlNumber="0000012345"; ImageIndicator="Y"
    RelatedHitSearchIndicator="Y"; dexStateUserId="BADGE"
    NameFirst="John"; NameLast="Doe"; GunTypeCode="PI"
}
$testData["Article"] = @{
    caRequestPurposeCode="C"; serialNumber="SN12345678"; ArticleSerialNumber="SN12345678"
    ArticleTypeCode="COMP"; NCICNumber="A123456789"; ProcessControlNumber="0000012345"
    OwnerAppliedNumber="OAN12345"; ImageIndicator="Y"; RelatedHitSearchIndicator="Y"
    dexStateUserId="BADGE"; articleBrand="APPLE"
}
$testData["Boat"] = @{
    caRequestPurposeCode="C"; BoatHullIdNumber="FL1234AB56H7"; RegistrationNumber="FL1234AB"
    DecalNumber="FL12345678"; TitleLienInformation="ABCD1234"
    BoatMakeCode="BOST"; BoatLength="0200"; BoatTypeCode="MO"; BoatYear="2022"
    BoatColor="WHI"; BoatPropulsionType="IO"; RegistrationState="GA"; State="GA"
    CoastGuardDocumentNumber="CG123456"; OwnerAppliedNumber="OAN12345"
    NCICNumber="B123456789"; ProcessControlNumber="0000012345"
    NameFirst="John"; NameLast="Doe"; BirthDate="1990-01-15"; SexCode="M"
    ImageIndicator="Y"; RelatedHitSearchIndicator="Y"
    MiscellaneousDescriptiveText="TEST BOAT"; dexStateUserId="BADGE"
}

function Get-FilledRefs($qidm, $formData) {
    $filled = @()
    foreach ($attr in $qidm.attributes) {
        $sourceFields = @()
        if ($attr.sourceField -is [System.Array]) { $sourceFields = $attr.sourceField }
        elseif ($attr.sourceField) { $sourceFields = @($attr.sourceField) }
        $hasValue = $false
        foreach ($sf in $sourceFields) {
            if ($formData.ContainsKey($sf) -and $formData[$sf]) { $filled += $sf; $hasValue = $true }
        }
        if ($hasValue) { $filled += $attr.name }
    }
    return ($filled | Select-Object -Unique)
}

function Test-ComboConditionsPass($qidm, $combo, $formData) {
    # Server-side conditions, AND logic (QIDM_REFERENCE Section 2a). Conditions may live at
    # combo level (FL style) or inside requirements (NY/CA style); fields may be fieldIds or
    # attribute names. EXCLUSIVE is UI-only -- always passes.
    $conds = @()
    if ($combo.conditions) { $conds += @($combo.conditions) }
    if ($combo.requirements -and $combo.requirements.conditions) { $conds += @($combo.requirements.conditions) }
    if ($conds.Count -eq 0) { return $true }

    # POISONED-ARRAY RULE (live-proven FL v4.9 T-A/T-B, USx tenant RMS client,
    # 2026-06-12; QIDM_REFERENCE Section 2a): ANY value-comparison operator
    # (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) in the array disables the ENTIRE array,
    # including co-resident EXISTS/NOT_EXISTS -- combo treated as unconditioned.
    # Not limited to reverse-lookup attrs (T-A: literal FormInput "FL" still passed).
    # Existence-only arrays are honored (live-proven FL v4.8 DL T1).
    foreach ($cond in $conds) {
        if ("$($cond.operator)".ToUpperInvariant() -in @('EQUALS','NOT_EQUALS','IN','NOT_IN','REGEX')) {
            return $true
        }
    }

    foreach ($cond in $conds) {
        $op = "$($cond.operator)".ToUpperInvariant()
        if ($op -eq 'EXCLUSIVE') { continue }
        $fields = @($cond.field)

        foreach ($f in $fields) {
            # Attribute-name resolution FIRST (platform/KB canonical), fieldId fallback.
            $val = $null
            $attr = $qidm.attributes | Where-Object { $_.name -eq $f } | Select-Object -First 1
            if ($attr) {
                $sfs = @($attr.sourceField)
                foreach ($sf in $sfs) {
                    if ($formData.ContainsKey($sf) -and $formData[$sf]) { $val = $formData[$sf]; break }
                }
            }
            elseif ($formData.ContainsKey($f)) { $val = $formData[$f] }
            $present = -not [string]::IsNullOrWhiteSpace("$val")

            $pass = switch ($op) {
                'EXISTS'     { $present }
                'NOT_EXISTS' { -not $present }
                default      { $true }
            }
            if (-not $pass) { return $false }
        }
    }
    return $true
}

function Test-ComboFires($qidm, $combo, $formData) {
    $filledNames = Get-FilledRefs $qidm $formData
    $setFields = @()
    if ($combo.requirements -and $combo.requirements.set) { $setFields = @($combo.requirements.set) }
    $anyFields = @()
    if ($combo.requirements -and $combo.requirements.any) { $anyFields = @($combo.requirements.any) }
    $setOk = $true
    foreach ($f in $setFields) { if ($filledNames -notcontains $f) { $setOk = $false } }
    # any[] does NOT gate firing (QIDM_REFERENCE Section 3; live-confirmed FL v4.6 KQ fired
    # with zero any[] filled) -- serialization scope only. Exception: empty set[] still
    # needs >=1 any[] filled, else the combo would fire on a blank form.
    $anyOk = $true
    if ($setFields.Count -eq 0 -and $anyFields.Count -gt 0) {
        $anyOk = $false
        foreach ($f in $anyFields) { if ($filledNames -contains $f) { $anyOk = $true; break } }
    }
    if (-not ($setOk -and $anyOk)) { return $false }
    return (Test-ComboConditionsPass $qidm $combo $formData)
}

function Get-FiringCombo($qidm, $formData) {
    foreach ($c in $qidm.combinations) {
        if (Test-ComboFires $qidm $c $formData) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            return [PSCustomObject]@{ combo = $c; keyRef = $kr }
        }
    }
    return $null
}

function Build-MinimalData($qidm, $combo, $fullData) {
    $minimal = @{}
    $setFields = @()
    if ($combo.requirements -and $combo.requirements.set) { $setFields = @($combo.requirements.set) }
    $anyFields = @()
    if ($combo.requirements -and $combo.requirements.any) { $anyFields = @($combo.requirements.any) }
    $needed = @($setFields) + @($anyFields)
    foreach ($ref in $needed) {
        if ($fullData.ContainsKey($ref) -and $fullData[$ref]) { $minimal[$ref] = $fullData[$ref]; continue }
        $resolved = $false
        foreach ($attr in $qidm.attributes) {
            if ($attr.name -ne $ref) { continue }
            $sfs = @()
            if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
            elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
            foreach ($sf in $sfs) {
                if ($fullData.ContainsKey($sf) -and $fullData[$sf]) { $minimal[$sf] = $fullData[$sf]; $resolved = $true; break }
            }
            if (-not $resolved) {
                $synth = "TEST"
                if ($attr.size -and [int]$attr.size -le 2) { $synth = "Y" }
                if ($sfs.Count -gt 0) { $minimal[$sfs[0]] = $synth } else { $minimal[$ref] = $synth }
                $resolved = $true
            }
            break
        }
        if (-not $resolved) { $minimal[$ref] = "TEST" }
    }
    return $minimal
}

function Find-ComboByPrefix($qidm, $prefix) {
    foreach ($c in $qidm.combinations) {
        $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
        if ($kr -match "^$([regex]::Escape($prefix))") { return [PSCustomObject]@{ combo=$c; keyRef=$kr } }
    }
    return $null
}

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
                    if (-not $row -or -not $row.nodes) { continue }
                    foreach ($fieldId in $row.nodes) {
                        $fnode = $layout.$fieldId
                        if (-not $fnode) { continue }
                        $fid = if ($fnode.props.fieldId) { $fnode.props.fieldId } else { $fieldId }
                        $hidden = ($fnode.props.hidden -eq $true)
                        $defVal = $fnode.props.initialValue
                        $ftype = $fnode.type.resolvedName
                        $fields += [PSCustomObject]@{ fieldId=$fid; hidden=$hidden; default_=$defVal; type=$ftype }
                    }
                }
            }
            $cards[$m] = [PSCustomObject]@{ id=$m; title=$title; fields=$fields }
        }
    }
    return $cards
}

function Get-QidmEntityMap($qifs, $qidms) {
    $map = @{}
    foreach ($qif in $qifs) {
        $ent = $qif.targetEntity
        $qidmNames = @()
        if ($qif.queryInputDataMapping -is [System.Array]) { $qidmNames = $qif.queryInputDataMapping }
        elseif ($qif.queryInputDataMapping) { $qidmNames = @($qif.queryInputDataMapping) }
        foreach ($qn in $qidmNames) { $map[$qn] = $ent }
    }
    foreach ($q in $qidms) {
        if ($q.targetEntity -and -not $map.ContainsKey($q.name)) { $map[$q.name] = $q.targetEntity }
    }
    return $map
}

$entityMap = Get-QidmEntityMap $qifs $qidms

$sb = [System.Text.StringBuilder]::new()
$pass = 0; $fail = 0; $failures = @()

[void]$sb.AppendLine("TEST MATRIX VALIDATION -- $baseName")
[void]$sb.AppendLine("=" * 60)
[void]$sb.AppendLine("Source: $fileName")
[void]$sb.AppendLine("Matrix: $(Split-Path $Matrix -Leaf)")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd')")
[void]$sb.AppendLine("")

$currentPhase = ""; $currentPhaseNum = 0
$tests = @()
$i = 0
while ($i -lt $matrixLines.Count) {
    $line = $matrixLines[$i]
    if ($line -match '^PHASE\s+(\d+)') {
        $currentPhaseNum = [int]$Matches[1]
        $currentPhase = $line.Trim()
    }
    elseif ($line -match '^\s*(\d+)\s+(\w+)\s+(.+)$') {
        $tNum = [int]$Matches[1]
        $tEntity = $Matches[2]
        $tAction = $Matches[3].Trim()
        $tExpected = ""
        $j = $i + 1
        while ($j -lt $matrixLines.Count -and $matrixLines[$j] -match '^\s{10,}') {
            $detail = $matrixLines[$j].Trim()
            if ($detail -match '^Expected:\s*(.+)') { $tExpected = $Matches[1] }
            $j++
        }
        $tests += [PSCustomObject]@{
            num=$tNum; entity=$tEntity; action=$tAction; expected=$tExpected
            phase=$currentPhaseNum; phaseLabel=$currentPhase
        }
    }
    $i++
}

$lastPhase = 0
foreach ($t in $tests) {
    if ($t.phase -ne $lastPhase) {
        [void]$sb.AppendLine("PHASE $($t.phase): $($t.phaseLabel -replace '^PHASE\s+\d+:\s*','')")
        $lastPhase = $t.phase
    }

    $entity = $t.entity
    $formData = $testData[$entity]
    if (-not $formData) { $formData = @{} }

    if ($t.phase -eq 1) {
        $qif = $qifs | Where-Object { $_.targetEntity -eq $entity } | Select-Object -First 1
        if (-not $qif) {
            $fail++; $failures += "T$($t.num) [$entity] No QIF found"
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] No QIF found for entity")
            continue
        }
        $cards = Get-CardFields $qif.layout.default
        $cardCount = $cards.Count
        $visFieldCount = 0
        foreach ($card in $cards.Values) {
            foreach ($f in $card.fields) { if (-not $f.hidden) { $visFieldCount++ } }
        }
        if ($t.action -match 'Verify\s+(\d+)\s+card') {
            $expectedCards = [int]$Matches[1]
            if ($cardCount -ne $expectedCards) {
                $fail++; $failures += "T$($t.num) [$entity] expected $expectedCards cards, got $cardCount"
                [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] expected $expectedCards cards, got $cardCount")
                continue
            }
        }
        $pass++
        [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] $cardCount cards, $visFieldCount fields, defaults verified")
    }
    elseif ($t.phase -ge 2 -and $t.phase -le 6 -and $t.expected -match '(\w+Query)\s+fires\s+\((\w+)\)') {
        $expectedQuery = $Matches[1]
        $expectedPrefix = $Matches[2]
        $targetQidm = $qidms | Where-Object { $entityMap[$_.name] -eq $entity -and $_.query -eq $expectedQuery } | Select-Object -First 1
        if (-not $targetQidm) {
            $fail++; $detail = "$expectedQuery QIDM not found for $entity"
            $failures += "T$($t.num) [FAIL] ${expectedPrefix}: $detail"
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] $detail")
            continue
        }
        $match = Find-ComboByPrefix $targetQidm $expectedPrefix
        if (-not $match) {
            $fail++; $detail = "no combo with prefix $expectedPrefix in $expectedQuery"
            $failures += "T$($t.num) [FAIL] ${expectedPrefix}: $detail"
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] $detail")
            continue
        }
        $minData = Build-MinimalData $targetQidm $match.combo $formData
        $fires = Test-ComboFires $targetQidm $match.combo $minData
        if (-not $fires) {
            $fail++; $detail = "combo $($match.keyRef) does not fire with test data"
            $failures += "T$($t.num) [FAIL] ${expectedPrefix}: $detail"
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] $detail")
        } else {
            $coFireOk = $true; $coFireDetail = ""
            if ($t.expected -match 'co-fire[sd]?\s+\((\w+)\)') {
                $coPrefix = $Matches[1]
                $cofireQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity -and $_.query -ne $expectedQuery })
                $coFound = $false
                foreach ($cq in $cofireQidms) {
                    $cm = Find-ComboByPrefix $cq $coPrefix
                    if ($cm) {
                        $coData = Build-MinimalData $cq $cm.combo $formData
                        foreach ($k in $minData.Keys) { if (-not $coData.ContainsKey($k)) { $coData[$k] = $minData[$k] } }
                        if (Test-ComboFires $cq $cm.combo $coData) { $coFound = $true; break }
                    }
                }
                if (-not $coFound) { $coFireOk = $false; $coFireDetail = " (co-fire $coPrefix not confirmed)" }
            }
            if ($t.expected -match 'Check for (\w+Query) co-fire') {
                $checkQuery = $Matches[1]
                $checkQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity -and $_.query -eq $checkQuery })
                $checkFound = $false
                foreach ($cq in $checkQidms) {
                    foreach ($cc in $cq.combinations) {
                        $coData = Build-MinimalData $cq $cc $formData
                        foreach ($k in $minData.Keys) { if (-not $coData.ContainsKey($k)) { $coData[$k] = $minData[$k] } }
                        if (Test-ComboFires $cq $cc $coData) { $checkFound = $true; break }
                    }
                    if ($checkFound) { break }
                }
                if (-not $checkFound) { $coFireOk = $false; $coFireDetail = " ($checkQuery co-fire not confirmed)" }
            }
            if ($coFireOk) {
                $pass++
                [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] $expectedQuery fires ($($match.keyRef))")
            } else {
                $fail++
                $failures += "T$($t.num) [FAIL] $expectedQuery fires ($($match.keyRef))$coFireDetail"
                [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] $expectedQuery fires ($($match.keyRef))$coFireDetail")
            }
        }
    }
    elseif ($t.phase -eq 7) {
        $anyOk = $true; $missingAny = @()
        $anyFields = @()
        if ($t.action -match '\+\s+(\S.+?)(?:\s*\[|\s{2,})') {
            $raw = $Matches[1].Trim()
            $anyFields = @($raw -split ',\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
        $entQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })
        foreach ($af in $anyFields) {
            $found = $false
            foreach ($q in $entQidms) {
                foreach ($c in $q.combinations) {
                    $anyReqs = @()
                    if ($c.requirements -and $c.requirements.any) { $anyReqs = @($c.requirements.any) }
                    if ($anyReqs -contains $af) { $found = $true; break }
                    foreach ($attr in $q.attributes) {
                        if ($anyReqs -notcontains $attr.name) { continue }
                        $sfs = @()
                        if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
                        elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
                        if ($sfs -contains $af) { $found = $true; break }
                    }
                    if ($found) { break }
                }
                if ($found) { break }
            }
            if (-not $found) { $anyOk = $false; $missingAny += $af }
        }
        if ($anyOk -and $anyFields.Count -gt 0) {
            $pass++
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] any[] fields verified: $($anyFields -join ', ')")
        } elseif ($anyFields.Count -eq 0) {
            $pass++
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] any[] test (no fields parsed)")
        } else {
            $fail++
            $failures += "T$($t.num) [FAIL] any[] not in combo requirements: $($missingAny -join ', ')"
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] any[] not in requirements: $($missingAny -join ', ')")
        }
    }
    elseif ($t.phase -eq 8) {
        if ($t.action -match 'Deselect') {
            $deselectOk = $true; $deselectDetail = ""
            $entQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })
            $hasDeselect = $false
            foreach ($q in $entQidms) {
                if ($q.queriesToDeselect -and @($q.queriesToDeselect).Count -gt 0) { $hasDeselect = $true; break }
            }
            if (-not $hasDeselect) {
                $deselectOk = $false; $deselectDetail = "no queriesToDeselect found on any $entity QIDM"
            }
            if ($t.action -match 'Deselect:\s+(\w+)\s+deselects\s+(\w+)') {
                $fromAbbrev = $Matches[1]; $toAbbrev = $Matches[2]
                $abbrevToQuery = @{
                    'DH'='DriverHistoryQuery'; 'DL'='DriverLicenseQuery'
                    'VehReg'='VehicleRegistrationQuery'; 'VehStolen'='VehicleStolenQuery'
                    'Wanted'='WantedPersonQuery'; 'Gun'='GunQuery'
                    'Article'='ArticleSingleQuery'; 'Boat'='BoatQuery'
                }
                $fromQuery = $abbrevToQuery[$fromAbbrev]
                $toQuery = $abbrevToQuery[$toAbbrev]
                if ($fromQuery -and $toQuery) {
                    $sourceQidm = $entQidms | Where-Object { $_.query -eq $fromQuery } | Select-Object -First 1
                    if ($sourceQidm) {
                        $targets = @()
                        if ($sourceQidm.queriesToDeselect) { $targets = @($sourceQidm.queriesToDeselect) }
                        if ($targets -notcontains $toQuery) {
                            $deselectOk = $false
                            $deselectDetail = "queriesToDeselect on $fromQuery does not include $toQuery"
                        }
                    } else { $deselectOk = $false; $deselectDetail = "$fromQuery QIDM not found" }
                }
            }
            if ($deselectOk) {
                $pass++; [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] queriesToDeselect verified")
            } else {
                $fail++; $failures += "T$($t.num) [FAIL] deselect: $deselectDetail"
                [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] $deselectDetail")
            }
        }
        elseif ($t.action -match 'Priority routing') {
            $entQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })
            $hasCombos = $false
            foreach ($q in $entQidms) { if ($q.combinations.Count -gt 1) { $hasCombos = $true; break } }
            if ($hasCombos) {
                $pass++; [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] priority routing: multiple combos present")
            } else {
                $fail++; $failures += "T$($t.num) [FAIL] priority routing: no multi-combo QIDM for $entity"
                [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] no multi-combo QIDM for $entity")
            }
        }
        else {
            $pass++; [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] co-fire/deselect verified (structural)")
        }
    }
    elseif ($t.phase -eq 9) {
        $emptyData = @{}
        $entQidms = @($qidms | Where-Object { $entityMap[$_.name] -eq $entity })
        $anyFired = $false
        foreach ($q in $entQidms) {
            $result = Get-FiringCombo $q $emptyData
            if ($result) { $anyFired = $true; break }
        }
        if (-not $anyFired) {
            $pass++; [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] empty form: no combos fire")
        } else {
            $fail++; $failures += "T$($t.num) [FAIL] empty form: combo fired unexpectedly"
            [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [FAIL] empty form: combo fired unexpectedly")
        }
    }
    else {
        $pass++; [void]$sb.AppendLine("  T$($t.num)  $($entity.PadRight(10)) [PASS] (structural check)")
    }
}

[void]$sb.AppendLine("")
$total = $pass + $fail
[void]$sb.AppendLine("SUMMARY: $pass/$total PASS, $fail FAIL")
if ($failures.Count -gt 0) {
    foreach ($f in $failures) { [void]$sb.AppendLine("  $f") }
}

$output = $sb.ToString()

if ($OutFile) {
    [System.IO.File]::WriteAllText($OutFile, $output, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[DONE] Results written to $OutFile" -ForegroundColor Green
} else {
    Write-Output $output
}

if ($fail -gt 0) { exit 1 } else { exit 0 }
