<#
  test_commsys.ps1 -- CommSys Query Simulator
  Reads a provider JSON, simulates form input, matches QIDM combos,
  and shows the XML that would be sent to CommSys for each query path.

  Usage: .\test_commsys.ps1 -Path <provider.json> [-Entity <name>] [-Combo <keyRef>]
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [string]$Entity,
    [string]$Combo,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json

$qidms = @()
foreach ($bundle in $json.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -eq "QUERYINPUTDATAMAPPING" -and $cfg.handlerFunction -eq "CommsysTransactionRequestHandler") {
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
    PurposeCode                = "D"
    Attention                  = "DISPATCHER JONES"
    Requestor                  = "DISPATCHER JONES"
    NyNyspinTransactionName    = "DALL"
    dexStateUserId             = "BADGE"
    StateDH                    = "AZ"
    SocialSecurityNumber       = "123456789"
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
    NCICNumber                  = "V123456789"
    ImageIndicator              = "Y"
    RelatedHitSearchIndicator   = "Y"
    dexStateUserId              = "BADGE"
}
$testData["Firearm"] = @{
    caRequestPurposeCode      = "C"
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
}
$testData["Article"] = @{
    caRequestPurposeCode      = "C"
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
    ImageIndicator                = "Y"
    RelatedHitSearchIndicator     = "Y"
    MiscellaneousDescriptiveText  = "TEST BOAT"
    dexStateUserId                = "BADGE"
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
        default { return $val }
    }
}

# ── Get form value for an attribute ──
function Get-AttrValue($attr, $formData) {
    $sourceFields = @()
    if ($attr.sourceField -is [System.Array]) { $sourceFields = $attr.sourceField }
    elseif ($attr.sourceField) { $sourceFields = @($attr.sourceField) }

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

# ── Build XML ──
function Build-Xml($qidm, $combo, $formData) {
    $kr = $combo.keyReference
    if (-not $kr) { $kr = $combo.keyRef }

    $msgKey = $kr
    if ($kr -match '^(FRQ|FDQ|FBQ|QV|QW|QG|QA|QB|BQ|RQ|DQ|KQ)') {
        $msgKey = $Matches[1]
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<Transaction>')
    [void]$sb.AppendLine("  <MessageKey>$msgKey</MessageKey>")

    foreach ($attr in $qidm.attributes) {
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

        $anyOk = $true
        $matched = @()
        if ($anyFields.Count -gt 0) {
            $anyOk = $false
            foreach ($f in $anyFields) {
                if ($filledNames -contains $f) { $anyOk = $true; $matched += $f }
            }
        }

        $fires = $setOk -and $anyOk

        if ($fires) {
            Write-Host ""
            Write-Host "    [FIRES] $kr" -ForegroundColor Green
            Write-Host "      set: [$($setFields -join ', ')]" -ForegroundColor Gray
            if ($anyFields.Count -gt 0) {
                Write-Host "      any: [$($anyFields -join ', ')] -> matched: [$($matched -join ', ')]" -ForegroundColor Gray
            }

            $xml = Build-Xml $qidm $c $formData
            Write-Host "      -- CommSys XML --" -ForegroundColor Cyan
            foreach ($line in $xml.Split([Environment]::NewLine)) {
                if ($line.Trim()) { Write-Host "      $line" -ForegroundColor White }
            }
        }
        else {
            $reason = ""
            if (-not $setOk) { $reason = "missing set: $($missing -join ', ')" }
            elseif (-not $anyOk) { $reason = "no any[] match" }
            Write-Host "    [SKIP] $kr -- $reason" -ForegroundColor DarkGray
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

            $condFields = @()
            if ($c.requirements -and $c.requirements.conditions) {
                foreach ($cond in $c.requirements.conditions) {
                    $flds = if ($cond.field -is [System.Array]) { $cond.field -join ',' } else { $cond.field }
                    $vals = if ($cond.value -is [System.Array]) { $cond.value -join ',' } else { $cond.value }
                    $condFields += "  condition: $flds $($cond.operator) $vals"
                }
            }

            $setOk = $true
            $missing = @()
            foreach ($f in $setFields) {
                if ($filledNames -notcontains $f) { $setOk = $false; $missing += $f }
            }

            $anyOk = $true
            $matched = @()
            if ($anyFields.Count -gt 0) {
                $anyOk = $false
                foreach ($f in $anyFields) {
                    if ($filledNames -contains $f) { $anyOk = $true; $matched += $f }
                }
            }

            $fires = $setOk -and $anyOk

            [void]$sb.AppendLine("")
            if ($fires) {
                [void]$sb.AppendLine("  [FIRES] $kr")
            } else {
                $reason = ""
                if (-not $setOk) { $reason = "missing set: $($missing -join ', ')" }
                elseif (-not $anyOk) { $reason = "no any[] match" }
                [void]$sb.AppendLine("  [SKIP] $kr -- $reason")
            }
            [void]$sb.AppendLine("    REQUIRED (set): [$($setFields -join ', ')]")
            [void]$sb.AppendLine("    OPTIONAL (any): [$($anyFields -join ', ')]")
            foreach ($cf in $condFields) { [void]$sb.AppendLine("    $cf") }

            if ($fires) {
                [void]$sb.AppendLine("    TEST INSTRUCTIONS: Enter values for: $($setFields -join ' + ')")
                if ($anyFields.Count -gt 0) {
                    [void]$sb.AppendLine("      Defaults/optional: $($anyFields -join ', ')")
                }

                $xml = Build-Xml $qidm $c $formData
                [void]$sb.AppendLine("    EXPECTED XML:")
                foreach ($line in $xml.Split([Environment]::NewLine)) {
                    if ($line.Trim()) { [void]$sb.AppendLine("      $line") }
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
