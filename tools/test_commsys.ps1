<#
  test_commsys.ps1 -- CommSys Query Simulator
  Reads a provider JSON, simulates form input, matches QIDM combos,
  and shows the XML that would be sent to CommSys for each query path.

  Usage: .\test_commsys.ps1 -Path <provider.json> [-Entity <name>] [-Combo <keyRef>]
                            [-Override @{ FieldId='value'; OtherField='' }]
  -Override: scenario data overlay applied to every entity's test data.
             Empty string value REMOVES the field (simulates blank form field).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$Entity,
    [string]$Combo,
    [string]$OutFile,
    [hashtable]$Override
)

$ErrorActionPreference = "Stop"

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json

$qidms = @()
foreach ($bundle in $json.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -eq "QUERYINPUTDATAMAPPING" -and
            $cfg.handlerFunction -in @("CommsysTransactionRequestHandler","RmsRestPayloadHandler")) {
            $qidms += $cfg
        }
    }
}

if ($qidms.Count -eq 0) {
    Write-Host "No CommSys QIDMs found." -ForegroundColor Red
    exit 1
}

# ── Test data per entity ──
$testData = @{}
$testData["Person"] = @{
    caRequestPurposeCode       = "C"
    OperatorLicenseNumber      = "D123456789"
    RegistrationState          = "NJ"
    State                      = "NY"
    NameFirst                  = "John"
    NameLast                   = "Doe"
    NameMiddle                 = "A"
    NameSuffix                 = ""
    BirthDate                  = "1990-01-15"
    SexCode                    = "M"
    ImageIndicator             = "Y"
    OperatorLicenseNumberDH    = "D123456789"
    NameFirstDH                = "John"
    NameLastDH                 = "Doe"
    NameMiddleDH               = "A"
    NameSuffixDH               = ""
    BirthDateDH                = "1990-01-15"
    SexCodeDH                  = "M"
    RegistrationStateDH        = "FL"
    purposeCodeDH              = "C"
    requestorDH                = "DISPATCHER JONES"
    PurposeCode                = "D"
    Attention                  = "DISPATCHER JONES"
    Requestor                  = "DISPATCHER JONES"
    NyNyspinTransactionName    = "DALL"
    dexStateUserId             = "BADGE"
    StateDH                    = "AZ"
    SocialSecurityNumber       = "123456789"
    criminalIdNumber           = "CA12345678"
    RaceCode                   = "W"
    NCICNumber                 = "W123456789"
    Age                        = "30"
    Height                     = "510"
    Weight                     = "180"
    EyeColorCode               = "BRO"
    HairColorCode              = "BLK"
    RelatedHitSearchIndicator       = "Y"
    ExpandedNameSearchCode          = "E"
    ExpandedBirthDateSearchCode     = "E"
    ExpandedBirthDateSearchIndicator = "Y"
    InquiryLevel                    = "1"
    MiscellaneousDescriptiveText    = "TEST QUERY"
    AreaCode                        = "602"
    FormORI                         = "MK1234567"
}
$testData["Vehicle"] = @{
    caRequestPurposeCode        = "C"
    purposeCode                 = "C"
    LicensePlateNumber          = "ABC1234"
    LicensePlateYear            = "2024"
    LicensePlateTypeCode        = "PC"
    RegistrationState           = "NJ"
    State                       = "NJ"
    VehicleIdentificationNumber = "1HGCM82633A123456"
    VINSequenceNumber           = "01"
    DecalNumber                 = "FL12345678"
    TitleLienInformation        = "ABCD1234"
    VehicleMakeCode             = "FORD"
    VehicleTypeCode             = "1"
    VehicleYear                 = "2023"
    RandomRequest               = "N"
    licensePlateNumberRand          = "ABC1234"
    vehicleIdentificationNumberRand = "1HGCM82633A123456"
    NCICNumber                  = "V123456789"
    ProcessControlNumber        = "0000012345"
    OwnerAppliedNumber          = "OAN999"
    PartSerialNumber            = "PSN12345"
    ImageIndicator              = "Y"
    RelatedHitSearchIndicator   = "Y"
    dexStateUserId              = "BADGE"
    nameLast                    = "Doe"
    nameFirst                   = "John"
    addressCity                 = "Los Angeles"
    addressStreetNumber         = "123"
}
$testData["Firearm"] = @{
    caRequestPurposeCode      = "C"
    purposeCode               = "C"
    serialNumber              = "ABC12345"
    GunSerialNumber           = "ABC12345"
    firearmMake               = "SMTH"
    GunMake                   = "SMTH"
    GunCaliber                = "9MM"
    GunModel                  = "M&P"
    NCICNumber                = "G123456789"
    ProcessControlNumber      = "0000012345"
    ImageIndicator            = "Y"
    RelatedHitSearchIndicator = "Y"
    dexStateUserId            = "BADGE"
    nameLast                  = "Doe"
    nameFirst                 = "John"
}
$testData["Article"] = @{
    caRequestPurposeCode      = "C"
    purposeCode               = "C"
    serialNumber              = "SN12345678"
    ArticleSerialNumber       = "SN12345678"
    ArticleTypeCode           = "COMP"
    NCICNumber                = "A123456789"
    ProcessControlNumber      = "0000012345"
    OwnerAppliedNumber        = "OAN12345"
    ImageIndicator            = "Y"
    RelatedHitSearchIndicator = "Y"
    dexStateUserId            = "BADGE"
}
$testData["Boat"] = @{
    caRequestPurposeCode       = "C"
    purposeCode                = "C"
    BoatHullIdNumber           = "FL1234AB56H7"
    RegistrationNumber         = "FL1234AB"
    DecalNumber                = "FL12345678"
    TitleLienInformation       = "ABCD1234"
    BoatMakeCode               = "BOST"
    BoatLength                 = "0200"
    BoatTypeCode               = "MO"
    BoatYear                   = "2022"
    BoatColor                  = "WHI"
    BoatPropulsionType         = "IO"
    RegistrationState          = "FL"
    State                      = "FL"
    CoastGuardDocumentNumber   = "CG123456"
    OwnerAppliedNumber         = "OAN12345"
    NCICNumber                 = "B123456789"
    ProcessControlNumber       = "0000012345"
    NameFirst                  = "John"
    NameLast                   = "Doe"
    BirthDate                  = "1990-01-15"
    SexCode                    = "M"
    ImageIndicator                = "Y"
    RelatedHitSearchIndicator     = "Y"
    MiscellaneousDescriptiveText  = "TEST BOAT"
    dexStateUserId                = "BADGE"
}

# ── Apply -Override scenario overlay (empty string removes the field) ──
if ($Override) {
    foreach ($entKey in @($testData.Keys)) {
        foreach ($k in $Override.Keys) {
            if ([string]::IsNullOrEmpty([string]$Override[$k])) {
                $testData[$entKey].Remove($k)
            } else {
                $testData[$entKey][$k] = $Override[$k]
            }
        }
    }
    $ovDesc = ($Override.GetEnumerator() | ForEach-Object {
        if ([string]::IsNullOrEmpty([string]$_.Value)) { "$($_.Key)=(removed)" } else { "$($_.Key)=$($_.Value)" }
    }) -join ', '
    Write-Host "  Override applied: $ovDesc" -ForegroundColor DarkYellow
}

# ── Rule handler simulation ──
function Invoke-RuleHandler($ruleFunction, $ruleArgs, $val, $allValues) {
    switch ($ruleFunction) {
        "CommsysParseDateRuleHandler" {
            if ($val -match '^\d{4}-\d{2}-\d{2}$') {
                $parts = $val.Split('-')
                $y = $parts[0]; $m = $parts[1]; $d = $parts[2]
                $outFmt = "yyyyMMdd"
                if ($ruleArgs -and $ruleArgs.Count -ge 2) { $outFmt = $ruleArgs[1] }
                switch ($outFmt) {
                    "MMddyyyy" { return "$m$d$y" }
                    "yyyyMMdd" { return "$y$m$d" }
                    default     { return "$y$m$d" }
                }
            }
            return $val
        }
        "FormatStringRuleHandler" {
            $seps = @()
            if ($ruleArgs) { $seps = @($ruleArgs) }
            $filled = @()
            for ($i = 0; $i -lt $allValues.Count; $i++) {
                if ($allValues[$i]) {
                    $filled += [PSCustomObject]@{ Value = $allValues[$i]; Pos = $i }
                }
            }
            if ($filled.Count -eq 0) { return $null }
            $result = ""
            for ($j = 0; $j -lt $filled.Count; $j++) {
                if ($j -gt 0) {
                    $sepIdx = $filled[$j - 1].Pos
                    if ($sepIdx -lt $seps.Count) { $result += $seps[$sepIdx] }
                    else { $result += " " }
                }
                $result += $filled[$j].Value
            }
            return $result
        }
        "ParseCommsysVehicleYearRuleHandler" {
            return $val
        }
        "CommsysGetLastNameFirstNameInitialRuleHandler" {
            # Auto-derives Attention as "LASTNAME F" from the query's name.
            # $allValues = @(lastName, firstName).
            $last = $null; $first = $null
            if ($allValues -and $allValues.Count -ge 1) { $last = $allValues[0] }
            if ($allValues -and $allValues.Count -ge 2) { $first = $allValues[1] }
            if (-not $last) { return $null }
            $fi = if ($first) { $first.Substring(0,1).ToUpper() } else { '' }
            return (("{0} {1}" -f $last.ToUpper(), $fi)).Trim()
        }
        default { return $val }
    }
}

# ── Get form value for an attribute ──
function Get-AttrValue($attr, $formData) {
    $sourceFields = @()
    if ($attr.sourceField -is [System.Array]) { $sourceFields = $attr.sourceField }
    elseif ($attr.sourceField) { $sourceFields = @($attr.sourceField) }

    # Attention auto-populate: the handler derives "LASTNAME F" from the query's
    # name fields, independent of its sourceField (['Attention']). Mirror that so
    # simulated XML shows the auto-populated value on the query, not a form entry.
    if ($attr.rule -and $attr.rule.function -match 'LastNameFirstNameInitial') {
        $last = $null; $first = $null
        foreach ($k in @('NameLastDH','NameLast','nameLast')) { if ($formData.ContainsKey($k) -and $formData[$k]) { $last = $formData[$k]; break } }
        foreach ($k in @('NameFirstDH','NameFirst','nameFirst')) { if ($formData.ContainsKey($k) -and $formData[$k]) { $first = $formData[$k]; break } }
        if (-not $last) { return $null }
        $val = Invoke-RuleHandler "CommsysGetLastNameFirstNameInitialRuleHandler" @() $null @($last, $first)
        if ($val -and $attr.size -gt 0 -and $val.Length -gt [int]$attr.size) { $val = $val.Substring(0, [int]$attr.size) }
        return $val
    }

    if ($attr.rule -and $attr.rule.function -eq "FormatStringRuleHandler") {
        $allValues = @()
        $hasAny = $false
        foreach ($sf in $sourceFields) {
            if ($formData.ContainsKey($sf) -and $formData[$sf]) {
                $allValues += $formData[$sf]
                $hasAny = $true
            } else {
                $allValues += $null
            }
        }
        if (-not $hasAny) { return $null }
        $ruleArgs = @()
        if ($attr.rule.arguments) { $ruleArgs = @($attr.rule.arguments) }
        $val = Invoke-RuleHandler "FormatStringRuleHandler" $ruleArgs $null $allValues
    }
    else {
        $val = $null
        foreach ($sf in $sourceFields) {
            if ($formData.ContainsKey($sf) -and $formData[$sf]) {
                $val = $formData[$sf]
                break
            }
        }
        if (-not $val) { return $null }

        if ($attr.rule -and $attr.rule.function) {
            $ruleArgs = @()
            if ($attr.rule.arguments) { $ruleArgs = @($attr.rule.arguments) }
            $val = Invoke-RuleHandler $attr.rule.function $ruleArgs $val @()
        }
    }

    if ($val -and $attr.size -gt 0 -and $val.Length -gt [int]$attr.size) {
        $val = $val.Substring(0, [int]$attr.size)
    }
    return $val
}

# ── Get all resolvable references (attr names + sourceField names with values) ──
function Get-FilledRefs($qidm, $formData) {
    $filled = @()
    foreach ($attr in $qidm.attributes) {
        $sourceFields = @()
        if ($attr.sourceField -is [System.Array]) { $sourceFields = $attr.sourceField }
        elseif ($attr.sourceField) { $sourceFields = @($attr.sourceField) }

        $hasValue = $false
        foreach ($sf in $sourceFields) {
            if ($formData.ContainsKey($sf) -and $formData[$sf]) {
                $filled += $sf
                $hasValue = $true
            }
        }
        if ($hasValue) { $filled += $attr.name }
    }
    return ($filled | Select-Object -Unique)
}

# ── Evaluate combo conditions (server-side AND logic) ──
# Conditions may live at combo level (FL style) or inside requirements (NY/CA style).
# Condition fields may be fieldIds (FL) or QIDM attribute names (NY/CA/KB) -- both resolved.
# Operators per QIDM_REFERENCE Section 2a. EXCLUSIVE is UI-only -- always passes here.
function Test-ComboConditions($qidm, $combo, $formData) {
    $conds = @()
    if ($combo.conditions) { $conds += @($combo.conditions) }
    if ($combo.requirements -and $combo.requirements.conditions) { $conds += @($combo.requirements.conditions) }
    $result = @{ ok = $true; failures = @(); warnings = @() }
    if ($conds.Count -eq 0) { return $result }

    # POISONED-ARRAY RULE (live-proven FL v4.9 T-A/T-B, USx tenant RMS client,
    # 2026-06-12; QIDM_REFERENCE Section 2a): a conditions array containing ANY
    # value-comparison operator (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) is disabled
    # IN ITS ENTIRETY -- including co-resident EXISTS/NOT_EXISTS members. The
    # combo behaves as unconditioned (fires by set[]/any[], joins the pool).
    # Scope is NOT limited to reverse-lookup attrs: T-A used a literal FormInput
    # carrying exact-uppercase "FL" and the NOT_EQUALS still passed.
    # Existence-ONLY arrays are honored (live-proven FL v4.8 DL T1).
    $poisoners = @($conds | Where-Object {
        "$($_.operator)".ToUpperInvariant() -in @('EQUALS','NOT_EQUALS','IN','NOT_IN','REGEX')
    })
    if ($poisoners.Count -gt 0) {
        $desc = ($poisoners | ForEach-Object { "$(@($_.field) -join '+') $("$($_.operator)".ToUpperInvariant()) $(@($_.value) -join ',')" }) -join '; '
        $result.warnings += "POISONED ARRAY: value-comparison condition(s) [$desc] disable this combo's ENTIRE conditions array (incl. any EXISTS/NOT_EXISTS) -- combo treated as UNCONDITIONED. Live-proven FL v4.9 T-A/T-B 2026-06-12."
        return $result
    }

    foreach ($cond in $conds) {
        $op = "$($cond.operator)".ToUpperInvariant()
        if ($op -eq 'EXCLUSIVE') { continue }

        # @() wraps scalars AND preserves arrays; assigning from an if-expression would
        # unroll a single-element array to a scalar (then [0] indexes a char) -- avoid.
        $fields = @($cond.field)

        foreach ($f in $fields) {
            # Resolve field value: QIDM attribute name FIRST (platform/KB canonical --
            # e.g. 'State' must resolve via the attr's sourceField like registrationStateDH,
            # not a same-named form field), then direct fieldId fallback.
            $val = $null
            $attr = $qidm.attributes | Where-Object { $_.name -eq $f } | Select-Object -First 1
            if ($attr) { $val = Get-AttrValue $attr $formData }
            elseif ($formData.ContainsKey($f)) { $val = $formData[$f] }
            $present = -not [string]::IsNullOrWhiteSpace("$val")

            $pass = switch ($op) {
                'EXISTS'     { $present }
                'NOT_EXISTS' { -not $present }
                default      { $true }
            }
            if (-not $pass) {
                $result.ok = $false
                $shown = if ($present) { "'$val'" } else { '(blank)' }
                $result.failures += "$f $op [value=$shown]"
            }
        }
    }
    return $result
}

# ── Build RMS elastic payload preview (RmsRestPayloadHandler QIDMs) ──
# Combo-scoped: targetField:value pairs for this combo's set[]+any[].
function Build-RmsPayload($qidm, $combo, $formData) {
    $relevantFields = @()
    if ($combo.requirements -and $combo.requirements.set) { $relevantFields += @($combo.requirements.set) }
    if ($combo.requirements -and $combo.requirements.any) { $relevantFields += @($combo.requirements.any) }
    $pairs = @()
    foreach ($attr in $qidm.attributes) {
        $sourceFields = @($attr.sourceField)
        $relevant = ($relevantFields -contains $attr.name)
        if (-not $relevant) {
            foreach ($sf in $sourceFields) { if ($relevantFields -contains $sf) { $relevant = $true; break } }
        }
        if (-not $relevant) { continue }
        $val = Get-AttrValue $attr $formData
        if ($val) { $pairs += "`"$($attr.targetField)`":`"$val`"" }
    }
    return "{`"elasticQuery`":{$($pairs -join ',')}}"
}

# ── Union serialization pool (LIMITATION #1 -- the platform model) ──
# Pool = union of set[]+any[] across ALL combos whose set[] AND conditions pass
# (any[] does not gate). Populated pool fields are what actually serializes.
# Live-proven for CommSys (FL v4.8) AND RMS (FL v4.8 elastic over-send).
function Get-UnionPool($qidm, $formData, $filledNames) {
    $pool = @()
    foreach ($c in $qidm.combinations) {
        $setFields = @()
        if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
        $setOk = $true
        foreach ($f in $setFields) { if ($filledNames -notcontains $f) { $setOk = $false; break } }
        if (-not $setOk) { continue }
        if (-not (Test-ComboConditions $qidm $c $formData).ok) { continue }
        $pool += $setFields
        if ($c.requirements -and $c.requirements.any) { $pool += @($c.requirements.any) }
    }
    $pool = @($pool | Select-Object -Unique)
    $serialized = @()
    foreach ($attr in $qidm.attributes) {
        $sourceFields = @($attr.sourceField)
        $inPool = ($pool -contains $attr.name)
        if (-not $inPool) {
            foreach ($sf in $sourceFields) { if ($pool -contains $sf) { $inPool = $true; break } }
        }
        if (-not $inPool) { continue }
        $val = Get-AttrValue $attr $formData
        if ($val) { $serialized += "$($attr.targetField)=$val" }
    }
    return $serialized
}

# ── Build XML ──
# Only includes attributes whose sourceFields/name are in this combo's set[]+any[].
# This produces the combo-accurate query — not every field in testData.
function Build-Xml($qidm, $combo, $formData) {
    $kr = $combo.keyReference
    if (-not $kr) { $kr = $combo.keyRef }

    $msgKey = $kr
    if ($kr -match '^(FRQ|FDQ|FBQ|QV|QW|QG|QA|QB|BQ|RQ|DQ|KQ)') {
        $msgKey = $Matches[1]
    }

    $relevantFields = @()
    if ($combo.requirements -and $combo.requirements.set) { $relevantFields += @($combo.requirements.set) }
    if ($combo.requirements -and $combo.requirements.any)  { $relevantFields += @($combo.requirements.any) }
    $relevantFields = $relevantFields | Select-Object -Unique

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<Transaction>')
    [void]$sb.AppendLine("  <MessageKey>$msgKey</MessageKey>")

    foreach ($attr in $qidm.attributes) {
        $sourceFields = @()
        if ($attr.sourceField -is [System.Array]) { $sourceFields = $attr.sourceField }
        elseif ($attr.sourceField) { $sourceFields = @($attr.sourceField) }

        # Attention auto-populate handler fires UNCONDITIONALLY whenever the
        # query runs -- it is handler-supplied, not combo-gated -- so always
        # include it regardless of the combo's set[]/any[] membership.
        $isAutoPop = ($attr.rule -and $attr.rule.function -match 'LastNameFirstNameInitial')

        if (-not $isAutoPop -and $sourceFields.Count -gt 0 -and $relevantFields.Count -gt 0) {
            $relevant = $relevantFields -contains $attr.name
            if (-not $relevant) {
                foreach ($sf in $sourceFields) {
                    if ($relevantFields -contains $sf) { $relevant = $true; break }
                }
            }
            if (-not $relevant) { continue }
        }

        $val = Get-AttrValue $attr $formData
        if (-not $val) { continue }
        $tf = $attr.targetField
        [void]$sb.AppendLine("  <$tf>$val</$tf>")
    }

    [void]$sb.Append('</Transaction>')
    return $sb.ToString()
}

# ── Main ──
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  CommSys Query Simulator -- $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

foreach ($qidm in $qidms) {
    $ent = $qidm.targetEntity
    if ($Entity -and $ent -ne $Entity) { continue }

    Write-Host ""
    Write-Host "--- QIDM: $($qidm.name) [$ent] ---" -ForegroundColor Yellow
    Write-Host "    Query: $($qidm.query)  |  Attrs: $($qidm.attributes.Count)  |  Combos: $($qidm.combinations.Count)"

    $formData = $testData[$ent]
    if (-not $formData) {
        Write-Host "    [SKIP] No test data for '$ent'" -ForegroundColor DarkGray
        continue
    }

    $filledNames = Get-FilledRefs $qidm $formData
    $firstMatch = $null

    foreach ($c in $qidm.combinations) {
        $kr = $c.keyReference
        if (-not $kr) { $kr = $c.keyRef }
        if ($Combo -and $kr -ne $Combo) { continue }

        $setFields = @()
        if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
        $anyFields = @()
        if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }

        $setOk = $true
        $missing = @()
        foreach ($f in $setFields) {
            if ($filledNames -notcontains $f) { $setOk = $false; $missing += $f }
        }

        # any[] does NOT gate firing (QIDM_REFERENCE Section 3; live-confirmed FL v4.6 KQ
        # fired with zero any[] filled) -- it scopes serialization only. Matched list is
        # informational. Sole exception: a combo with EMPTY set[] still needs >=1 any[]
        # filled, else it would fire on a blank form.
        $matched = @()
        foreach ($f in $anyFields) {
            if ($filledNames -contains $f) { $matched += $f }
        }
        $anyOk = $true
        if ($setFields.Count -eq 0 -and $anyFields.Count -gt 0) { $anyOk = ($matched.Count -gt 0) }

        $condResult = Test-ComboConditions $qidm $c $formData
        $fires = $setOk -and $anyOk -and $condResult.ok

        if ($fires) {
            $marker = if (-not $firstMatch) { $firstMatch = $kr; '[FIRES first-match]' } else { '[FIRES shadowed -- first match above wins]' }
            Write-Host ""
            Write-Host "    $marker $kr" -ForegroundColor Green
            Write-Host "      set: [$($setFields -join ', ')]" -ForegroundColor Gray
            if ($anyFields.Count -gt 0) {
                Write-Host "      any: [$($anyFields -join ', ')] -> matched: [$($matched -join ', ')]" -ForegroundColor Gray
            }
            foreach ($w in $condResult.warnings) {
                Write-Host "      [!] $w" -ForegroundColor Yellow
            }

            if ($qidm.handlerFunction -eq 'RmsRestPayloadHandler') {
                Write-Host "      -- RMS elastic payload (combo-scoped) --" -ForegroundColor Cyan
                Write-Host "      $(Build-RmsPayload $qidm $c $formData)" -ForegroundColor White
            } else {
                $xml = Build-Xml $qidm $c $formData
                Write-Host "      -- CommSys XML --" -ForegroundColor Cyan
                foreach ($line in $xml.Split([Environment]::NewLine)) {
                    if ($line.Trim()) { Write-Host "      $line" -ForegroundColor White }
                }
            }
        }
        else {
            $reason = ""
            if (-not $setOk) { $reason = "missing set: $($missing -join ', ')" }
            elseif (-not $anyOk) { $reason = "no any[] match" }
            else { $reason = "conditions failed: $($condResult.failures -join '; ')" }
            Write-Host "    [SKIP] $kr -- $reason" -ForegroundColor DarkGray
        }
    }
    if ($firstMatch) {
        Write-Host ""
        Write-Host "    >> PLATFORM FIRES: $firstMatch (first matching combo)" -ForegroundColor Magenta
        $unionPool = Get-UnionPool $qidm $formData $filledNames
        Write-Host "    >> UNION POOL (platform serializes): $($unionPool -join ', ')" -ForegroundColor Magenta
        if ($unionPool.Count -gt 0) {
            Write-Host "       (LIMITATION #1: pool = union of set[]+any[] of ALL matching combos;" -ForegroundColor DarkGray
            Write-Host "        if this exceeds the first-match combo's fields, the platform OVER-SENDS)" -ForegroundColor DarkGray
        }
    }
}

# ── Save reference file ──
if ($OutFile) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("CommSys Query Simulator -- Test Case Reference")
    [void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("JSON: $(Split-Path $Path -Leaf)")
    [void]$sb.AppendLine("=" * 72)

    foreach ($qidm in $qidms) {
        $ent = $qidm.targetEntity
        if ($Entity -and $ent -ne $Entity) { continue }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("QIDM: $($qidm.name) [$ent]")
        [void]$sb.AppendLine("Query: $($qidm.query)  |  Attrs: $($qidm.attributes.Count)  |  Combos: $($qidm.combinations.Count)")
        [void]$sb.AppendLine("-" * 72)

        $formData = $testData[$ent]
        if (-not $formData) {
            [void]$sb.AppendLine("  [SKIP] No test data for '$ent'")
            continue
        }

        $filledNames = Get-FilledRefs $qidm $formData

        foreach ($c in $qidm.combinations) {
            $kr = $c.keyReference
            if (-not $kr) { $kr = $c.keyRef }
            if ($Combo -and $kr -ne $Combo) { continue }

            $setFields = @()
            if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
            $anyFields = @()
            if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }

            $allConds = @()
            if ($c.conditions) { $allConds += @($c.conditions) }
            if ($c.requirements -and $c.requirements.conditions) { $allConds += @($c.requirements.conditions) }
            $condFields = @()
            foreach ($cond in $allConds) {
                $flds = if ($cond.field -is [System.Array]) { $cond.field -join ',' } else { $cond.field }
                $vals = if ($cond.value -is [System.Array]) { $cond.value -join ',' } else { $cond.value }
                $condFields += "  condition: $flds $($cond.operator) $vals"
            }

            $setOk = $true
            $missing = @()
            foreach ($f in $setFields) {
                if ($filledNames -notcontains $f) { $setOk = $false; $missing += $f }
            }

            # any[] does NOT gate firing (QIDM_REFERENCE Section 3) -- serialization scope only.
            $matched = @()
            foreach ($f in $anyFields) {
                if ($filledNames -contains $f) { $matched += $f }
            }
            $anyOk = $true
            if ($setFields.Count -eq 0 -and $anyFields.Count -gt 0) { $anyOk = ($matched.Count -gt 0) }

            $condResult = Test-ComboConditions $qidm $c $formData
            $fires = $setOk -and $anyOk -and $condResult.ok

            [void]$sb.AppendLine("")
            if ($fires) {
                [void]$sb.AppendLine("  [FIRES] $kr")
            } else {
                $reason = ""
                if (-not $setOk) { $reason = "missing set: $($missing -join ', ')" }
                elseif (-not $anyOk) { $reason = "no any[] match" }
                else { $reason = "conditions failed: $($condResult.failures -join '; ')" }
                [void]$sb.AppendLine("  [SKIP] $kr -- $reason")
            }
            foreach ($w in $condResult.warnings) {
                [void]$sb.AppendLine("    [!] $w")
            }
            [void]$sb.AppendLine("    REQUIRED (set): [$($setFields -join ', ')]")
            [void]$sb.AppendLine("    OPTIONAL (any): [$($anyFields -join ', ')]")
            foreach ($cf in $condFields) { [void]$sb.AppendLine("    $cf") }

            if ($fires) {
                [void]$sb.AppendLine("    TEST INSTRUCTIONS: Enter values for: $($setFields -join ' + ')")
                if ($anyFields.Count -gt 0) {
                    [void]$sb.AppendLine("      Defaults/optional: $($anyFields -join ', ')")
                }

                if ($qidm.handlerFunction -eq 'RmsRestPayloadHandler') {
                    [void]$sb.AppendLine("    EXPECTED RMS PAYLOAD (combo-scoped):")
                    [void]$sb.AppendLine("      $(Build-RmsPayload $qidm $c $formData)")
                } else {
                    $xml = Build-Xml $qidm $c $formData
                    [void]$sb.AppendLine("    EXPECTED XML:")
                    foreach ($line in $xml.Split([Environment]::NewLine)) {
                        if ($line.Trim()) { [void]$sb.AppendLine("      $line") }
                    }
                }
            }
        }
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("=" * 72)
    [System.IO.File]::WriteAllText($OutFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "  Saved test reference: $OutFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Filter: -Entity <name>  -Combo <keyRef>" -ForegroundColor DarkGray
Write-Host "  Edit testData in script to change form values." -ForegroundColor DarkGray
Write-Host "  Save: -OutFile <path> to save test case reference." -ForegroundColor DarkGray
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
