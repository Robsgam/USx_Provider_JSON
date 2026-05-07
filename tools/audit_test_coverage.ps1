<#
  audit_test_coverage.ps1 -- Test Coverage Auditor
  Maps QIDM combinations to test log files and generates a coverage report.

  Usage:
    .\audit_test_coverage.ps1                                  # All providers
    .\audit_test_coverage.ps1 -Path providers\FL_FCIC\FL_FCIC_MC.json
    .\audit_test_coverage.ps1 -OutFile coverage_report.txt

  Checks:
    1. Combo Inventory     -- extract all CommSys QIDM combos from JSON
    2. Test Log Inventory  -- scan tests/ directory for .txt files
    3. Coverage Matrix     -- match combos to test logs (fuzzy)
    4. SQVR Alignment      -- compare [CONFIRMED] vs test log count
    5. Orphan Test Logs    -- test logs that don't match any combo
    6. Overall Summary     -- coverage percentage + missing tests
#>

param(
    [string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent)

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

function Get-ProviderName($jsonPath) {
    $dir = Split-Path $jsonPath -Parent
    return Split-Path $dir -Leaf
}

function Get-CommSysQidms($json) {
    $qidms = @()
    foreach ($bundle in $json.bundles) {
        if ($bundle.provider -eq 'RMS') { continue }
        if ($bundle.name -eq 'RMS') { continue }
        foreach ($cfg in $bundle.configurations) {
            if ($cfg.type -eq "QUERYINPUTDATAMAPPING" -and
                $cfg.handlerFunction -eq "CommsysTransactionRequestHandler") {
                $qidms += $cfg
            }
        }
    }
    return $qidms
}

function Get-ComboInfo($qidm) {
    $combos = @()
    foreach ($c in $qidm.combinations) {
        $kr = $c.keyReference
        if (-not $kr) { $kr = $c.keyRef }
        $setFields = @()
        if ($c.requirements -and $c.requirements.set) { $setFields = @($c.requirements.set) }
        $anyFields = @()
        if ($c.requirements -and $c.requirements.any) { $anyFields = @($c.requirements.any) }
        $combos += [PSCustomObject]@{
            KeyReference = $kr
            Entity       = $qidm.targetEntity
            Query        = $qidm.query
            QidmName     = $qidm.name
            Set          = $setFields
            Any          = $anyFields
            State        = $c.state
        }
    }
    return $combos
}

function Match-TestLogToCombo($logName, $combo, $providerName) {
    # Strategy: fuzzy match on keyReference substring in the test log filename
    $kr = $combo.KeyReference
    if (-not $kr) { return $false }

    # Direct keyReference match (e.g., "FRQ+Plate" matches keyRef "FRQLicensePlateNumber")
    # Extract the prefix from keyReference (e.g., "FRQ" from "FRQLicensePlateNumber")
    $krPrefix = ""
    if ($kr -match '^([A-Z]{2,5}\.?[A-Z]{0,5}\.?[A-Z]?)') {
        $krPrefix = $Matches[1]
    }

    # Also try dotted keyRefs (e.g., "IA.QV" from CA providers)
    $krClean = $kr

    # Check if the log filename contains the keyReference or its prefix
    $logUpper = $logName.ToUpper()
    $krUpper = $krClean.ToUpper()

    # Exact keyReference in filename (e.g., "IA.QV" in "CA_CLETS_Vehicle_IA.QV_...")
    if ($logUpper -match [regex]::Escape($krUpper)) { return $true }

    # Entity match + keyRef prefix match (e.g., "Vehicle" + "FRQ" in filename)
    $entity = $combo.Entity
    if ($entity -and $logUpper.Contains($entity.ToUpper())) {
        # Try prefix (FRQ, DQ, KQ, QG, QA, QB, BQ, RQ, QV, QW, FDQ, FBQ, etc.)
        if ($kr -match '^([A-Z]{2,4})') {
            $prefix = $Matches[1]
            # Check for prefix in filename with word boundary (e.g., _FRQ+ or _FRQ_ or _FRQ.)
            if ($logUpper -match "[\._\+]$($prefix.ToUpper())[\._\+\s]|_$($prefix.ToUpper())\+|_$($prefix.ToUpper())_") {
                return $true
            }
        }
        # Try dotted prefix (e.g., IA.QV, NLTS.RQ.P)
        if ($kr -match '^([A-Z]+\.[A-Z]+(?:\.[A-Z]+)?)') {
            $dottedPrefix = $Matches[1]
            if ($logUpper.Contains($dottedPrefix.ToUpper())) { return $true }
        }
    }

    # Fallback: check if combo short label appears (e.g., "Plate" for LicensePlateNumber in set[])
    # This is very generous fuzzy matching
    $entity = $combo.Entity
    if ($entity -and $logUpper.Contains($entity.ToUpper())) {
        # Check for primary field keywords
        foreach ($sf in $combo.Set) {
            $fieldKeyword = $sf -replace '(License|Plate|Number|Registration|Operator|Vehicle|Identification|Serial|Article|Type|Code|Boat|Hull|Id|Coast|Guard|Document|Process|Control|Owner|Applied|Birth|Date|NCIC|Title|Lien|Information|Decal)', '$1'
            # Extract the most meaningful word from the field name
            if ($sf -match 'LicensePlateNumber') {
                if ($logUpper -match 'PLATE') { return $true }
            }
            if ($sf -match 'VehicleIdentificationNumber') {
                if ($logUpper -match 'VIN') { return $true }
            }
            if ($sf -match 'OperatorLicenseNumber') {
                if ($logUpper -match 'OLN') { return $true }
            }
            if ($sf -match 'Name(Last|First)') {
                if ($logUpper -match '[\._]NAME[\._\+]|_NAME_|BY.NAME') { return $true }
            }
            if ($sf -match 'GunSerialNumber|serialNumber') {
                if ($logUpper -match 'SERIAL') { return $true }
            }
            if ($sf -match 'ArticleSerialNumber') {
                if ($logUpper -match 'SERIAL') { return $true }
            }
            if ($sf -match 'NCICNumber') {
                if ($logUpper -match 'NCIC') { return $true }
            }
            if ($sf -match 'ProcessControlNumber') {
                if ($logUpper -match 'PCN') { return $true }
            }
            if ($sf -match 'BoatHullIdNumber') {
                if ($logUpper -match 'HULL') { return $true }
            }
            if ($sf -match 'RegistrationNumber') {
                if ($logUpper -match 'REG(?!ISTRATIONSTATE)') { return $true }
            }
            if ($sf -match 'CoastGuardDocumentNumber') {
                if ($logUpper -match 'COAST.?GUARD|CG') { return $true }
            }
            if ($sf -match 'DecalNumber') {
                if ($logUpper -match 'DECAL') { return $true }
            }
            if ($sf -match 'TitleLienInformation') {
                if ($logUpper -match 'TITLE') { return $true }
            }
            if ($sf -match 'OwnerAppliedNumber') {
                if ($logUpper -match 'OAN|OWNER') { return $true }
            }
        }
    }

    return $false
}

function Format-ComboLabel($combo) {
    $kr = $combo.KeyReference
    $setStr = ($combo.Set -join ', ')
    return "$kr  set=[$setStr]"
}

# ══════════════════════════════════════════════════════════════════════════════
# DISCOVER PROVIDERS
# ══════════════════════════════════════════════════════════════════════════════

$providerJsons = @()

if ($Path) {
    $resolved = Resolve-Path $Path
    $providerJsons += [PSCustomObject]@{
        Name = Get-ProviderName $resolved
        Path = $resolved.Path
        Dir  = Split-Path $resolved -Parent
    }
} else {
    $providersDir = Join-Path $repoRoot "providers"
    foreach ($dir in (Get-ChildItem $providersDir -Directory)) {
        $provName = $dir.Name
        # Skip CA_CONTRA_COSTA per spec
        if ($provName -eq "CA_CONTRA_COSTA") { continue }

        # Prefer MC.json (more combos), fall back to BASE.json
        $mcJson = Get-ChildItem $dir.FullName -Filter "*_MC.json" -File | Select-Object -First 1
        $baseJson = Get-ChildItem $dir.FullName -Filter "*_BASE.json" -File | Select-Object -First 1

        $jsonFile = $null
        if ($mcJson) { $jsonFile = $mcJson }
        elseif ($baseJson) { $jsonFile = $baseJson }
        else { continue }

        $providerJsons += [PSCustomObject]@{
            Name = $provName
            Path = $jsonFile.FullName
            Dir  = $dir.FullName
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT BUFFER
# ══════════════════════════════════════════════════════════════════════════════

$output = [System.Text.StringBuilder]::new()

function Out-Line($text) {
    [void]$output.AppendLine($text)
    Write-Host $text
}
function Out-LineColor($text, $color) {
    [void]$output.AppendLine($text)
    Write-Host $text -ForegroundColor $color
}

# ══════════════════════════════════════════════════════════════════════════════
# PROCESS EACH PROVIDER
# ══════════════════════════════════════════════════════════════════════════════

$summaryRows = @()

foreach ($prov in ($providerJsons | Sort-Object Name)) {
    $provName = $prov.Name
    $provDir = $prov.Dir
    $jsonPath = $prov.Path
    $jsonFileName = Split-Path $jsonPath -Leaf

    # --- Parse JSON ---
    try {
        $raw = [System.IO.File]::ReadAllText($jsonPath, [System.Text.UTF8Encoding]::new($false))
        $json = $raw | ConvertFrom-Json
    } catch {
        Out-LineColor "  ERROR: Could not parse $jsonFileName -- $_" "Red"
        $summaryRows += [PSCustomObject]@{
            Provider = $provName; Combos = 0; Tests = 0; Coverage = "ERR"
            SqvrMatch = "ERR"
        }
        continue
    }

    Out-Line ""
    Out-LineColor "========================================" "Cyan"
    Out-LineColor " TEST COVERAGE: $provName" "Cyan"
    Out-LineColor " JSON: $jsonFileName" "Cyan"
    Out-LineColor "========================================" "Cyan"

    # ── CHECK 1: Combo Inventory ──
    Out-Line ""
    Out-LineColor "  CHECK 1: Combo Inventory" "Yellow"

    $qidms = Get-CommSysQidms $json
    $allCombos = @()
    $combosByEntity = @{}

    foreach ($qidm in $qidms) {
        $combos = Get-ComboInfo $qidm
        foreach ($c in $combos) {
            $allCombos += $c
            $ent = $c.Entity
            if (-not $combosByEntity.ContainsKey($ent)) {
                $combosByEntity[$ent] = @()
            }
            $combosByEntity[$ent] += $c
        }
    }

    $totalCombos = $allCombos.Count
    Out-Line "    Total CommSys combos: $totalCombos"

    foreach ($ent in ($combosByEntity.Keys | Sort-Object)) {
        $entCombos = $combosByEntity[$ent]
        Out-Line "      $ent`: $($entCombos.Count) combos"
        foreach ($c in $entCombos) {
            $setStr = ($c.Set -join ', ')
            $anyStr = if ($c.Any.Count -gt 0) { " any=[$($c.Any -join ', ')]" } else { "" }
            Out-Line "        $($c.KeyReference)  set=[$setStr]$anyStr"
        }
    }

    # ── CHECK 2: Test Log Inventory ──
    Out-Line ""
    Out-LineColor "  CHECK 2: Test Log Inventory" "Yellow"

    $testsDir = Join-Path $provDir "tests"
    $testLogs = @()
    if (Test-Path $testsDir) {
        $testLogs = @(Get-ChildItem $testsDir -Filter "*.txt" -File | Sort-Object Name)
    }

    $totalTests = $testLogs.Count
    Out-Line "    Total test logs: $totalTests"

    if ($totalTests -gt 0) {
        foreach ($log in $testLogs) {
            Out-Line "      $($log.Name)"
        }
    } else {
        Out-Line "      (none)"
    }

    # ── CHECK 3: Coverage Matrix ──
    Out-Line ""
    Out-LineColor "  CHECK 3: Coverage Matrix" "Yellow"

    $testedCombos = 0
    $untestedCombos = @()
    $matchedLogs = @{}  # track which logs matched a combo

    foreach ($ent in ($combosByEntity.Keys | Sort-Object)) {
        $entCombos = $combosByEntity[$ent]
        $entTested = 0
        $entTotal = $entCombos.Count

        $entResults = @()

        foreach ($c in $entCombos) {
            $matched = $false
            $matchFile = ""

            foreach ($log in $testLogs) {
                if (Match-TestLogToCombo $log.Name $c $provName) {
                    $matched = $true
                    $matchFile = $log.Name
                    $matchedLogs[$log.Name] = $true
                    break
                }
            }

            if ($matched) {
                $entTested++
                $testedCombos++
                $entResults += [PSCustomObject]@{
                    Mark = [char]0x2713  # checkmark
                    Combo = $c.KeyReference
                    File = $matchFile
                    Color = "Green"
                }
            } else {
                $untestedCombos += $c
                $entResults += [PSCustomObject]@{
                    Mark = [char]0x2717  # X mark
                    Combo = $c.KeyReference
                    File = "NOT TESTED"
                    Color = "Red"
                }
            }
        }

        $pct = if ($entTotal -gt 0) { [math]::Round(($entTested / $entTotal) * 100) } else { 0 }
        $queryName = if ($entCombos.Count -gt 0) { $entCombos[0].Query } else { "?" }
        Out-Line ""
        $pctColor = if ($pct -eq 100) { "Green" } elseif ($pct -gt 0) { "Yellow" } else { "Red" }
        Out-LineColor "    $ent ($queryName): $entTested/$entTotal combos tested ($pct%)" $pctColor

        foreach ($r in $entResults) {
            $padCombo = $r.Combo.PadRight(30)
            if ($r.Color -eq "Green") {
                Out-LineColor "      $($r.Mark) $padCombo -- $($r.File)" "Green"
            } else {
                Out-LineColor "      $($r.Mark) $padCombo -- $($r.File)" "Red"
            }
        }
    }

    # ── CHECK 4: SQVR Alignment ──
    Out-Line ""
    Out-LineColor "  CHECK 4: SQVR Alignment" "Yellow"

    $sqvrPath = Join-Path $provDir "docs" "${provName}_SQVR.txt"
    $sqvrConfirmed = 0
    $sqvrPending = 0
    $sqvrExists = $false

    if (Test-Path $sqvrPath) {
        $sqvrExists = $true
        $sqvrContent = [System.IO.File]::ReadAllText($sqvrPath)
        $sqvrConfirmed = ([regex]::Matches($sqvrContent, '\[CONFIRMED\]')).Count
        $sqvrPending = ([regex]::Matches($sqvrContent, '\[PENDING\]')).Count

        Out-Line "    SQVR file: found"
        Out-Line "    [CONFIRMED]: $sqvrConfirmed"
        Out-Line "    [PENDING]:   $sqvrPending"

        # Compare: SQVR confirmed should roughly match test log count
        $sqvrAligned = ($sqvrConfirmed -eq $testedCombos)
        if ($sqvrAligned) {
            Out-LineColor "    Alignment: YES (SQVR confirmed=$sqvrConfirmed, tested combos=$testedCombos)" "Green"
        } else {
            Out-LineColor "    Alignment: NO (SQVR confirmed=$sqvrConfirmed, tested combos=$testedCombos)" "Yellow"
            if ($sqvrConfirmed -gt $testedCombos) {
                Out-LineColor "    WARN: SQVR has more [CONFIRMED] than matched test logs (some logs may use non-standard naming)" "Yellow"
            } else {
                Out-LineColor "    WARN: More test logs match combos than SQVR [CONFIRMED] markers (SQVR may need update)" "Yellow"
            }
        }
    } else {
        Out-Line "    SQVR file: NOT FOUND"
        Out-LineColor "    WARN: No SQVR file at $sqvrPath" "Yellow"
    }

    # ── CHECK 5: Orphan Test Logs ──
    Out-Line ""
    Out-LineColor "  CHECK 5: Orphan Test Logs" "Yellow"

    $orphanCount = 0
    foreach ($log in $testLogs) {
        if (-not $matchedLogs.ContainsKey($log.Name)) {
            $orphanCount++
            Out-Line "    INFO: $($log.Name)"
        }
    }
    if ($orphanCount -eq 0) {
        Out-Line "    (none -- all test logs matched a combo)"
    } else {
        Out-Line "    $orphanCount orphan log(s) (may be negative tests, regression tests, render checks, etc.)"
    }

    # ── CHECK 6: Overall Coverage Summary ──
    Out-Line ""
    Out-LineColor "  CHECK 6: Overall Coverage" "Yellow"

    $coveragePct = if ($totalCombos -gt 0) { [math]::Round(($testedCombos / $totalCombos) * 100) } else { 0 }
    $coverageColor = if ($coveragePct -eq 100) { "Green" } elseif ($coveragePct -gt 50) { "Yellow" } else { "Red" }

    Out-LineColor "    Total combos (CommSys): $totalCombos" "White"
    Out-LineColor "    Total test logs:        $totalTests" "White"
    Out-LineColor "    Matched combos:         $testedCombos" "White"
    Out-LineColor "    Coverage:               $coveragePct%" $coverageColor

    if ($untestedCombos.Count -gt 0) {
        Out-Line ""
        Out-Line "    Missing tests:"
        foreach ($u in $untestedCombos) {
            Out-LineColor "      - $($u.Entity) $($u.Query) $($u.KeyReference)" "Red"
        }
    }

    Out-Line ""
    $sqvrStatus = if (-not $sqvrExists) { "N/A" } elseif ($sqvrConfirmed -eq $testedCombos) { "YES" } else { "NO" }
    Out-Line "    SQVR status:"
    if ($sqvrExists) {
        Out-Line "      [CONFIRMED]: $sqvrConfirmed"
        Out-Line "      [PENDING]:   $sqvrPending"
        $sqvrAlignColor = if ($sqvrStatus -eq "YES") { "Green" } else { "Yellow" }
        Out-LineColor "      Aligned with test logs: $sqvrStatus" $sqvrAlignColor
    } else {
        Out-Line "      (no SQVR file)"
    }

    # ── Store summary row ──
    $summaryRows += [PSCustomObject]@{
        Provider  = $provName
        Combos    = $totalCombos
        Tests     = $totalTests
        Coverage  = "$coveragePct%"
        SqvrMatch = $sqvrStatus
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY TABLE
# ══════════════════════════════════════════════════════════════════════════════

Out-Line ""
Out-LineColor "========================================" "Cyan"
Out-LineColor " TEST COVERAGE SUMMARY" "Cyan"
Out-LineColor "========================================" "Cyan"
Out-Line ""

# Column widths
$colProv = 24
$colCombo = 8
$colTests = 8
$colCov = 10
$colSqvr = 12

$header = "Provider".PadRight($colProv) +
          "Combos".PadRight($colCombo) +
          "Tests".PadRight($colTests) +
          "Coverage".PadRight($colCov) +
          "SQVR Match"
Out-LineColor $header "White"
Out-Line ("-" * ($colProv + $colCombo + $colTests + $colCov + $colSqvr))

foreach ($row in ($summaryRows | Sort-Object Provider)) {
    $line = $row.Provider.PadRight($colProv) +
            "$($row.Combos)".PadRight($colCombo) +
            "$($row.Tests)".PadRight($colTests) +
            "$($row.Coverage)".PadRight($colCov) +
            $row.SqvrMatch

    $color = "White"
    if ($row.Coverage -eq "100%") { $color = "Green" }
    elseif ($row.Coverage -eq "0%" -or $row.Coverage -eq "ERR") { $color = "Red" }
    else { $color = "Yellow" }

    Out-LineColor $line $color
}

# Totals
$totalAllCombos = ($summaryRows | Measure-Object -Property Combos -Sum).Sum
$totalAllTests = ($summaryRows | Measure-Object -Property Tests -Sum).Sum
$overallPct = if ($totalAllCombos -gt 0) { [math]::Round(($summaryRows | ForEach-Object {
    $pctVal = $_.Coverage -replace '%',''
    if ($pctVal -match '^\d+$') { [int]$pctVal * $_.Combos / 100 } else { 0 }
} | Measure-Object -Sum).Sum / $totalAllCombos * 100) } else { 0 }

Out-Line ("-" * ($colProv + $colCombo + $colTests + $colCov + $colSqvr))

$totalLine = "TOTAL".PadRight($colProv) +
             "$totalAllCombos".PadRight($colCombo) +
             "$totalAllTests".PadRight($colTests) +
             "$overallPct%".PadRight($colCov) +
             ""
Out-LineColor $totalLine "Cyan"

Out-Line ""
Out-Line "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Out-Line ""

# ══════════════════════════════════════════════════════════════════════════════
# WRITE OUTPUT FILE
# ══════════════════════════════════════════════════════════════════════════════

if ($OutFile) {
    $output.ToString() | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "Report saved: $OutFile" -ForegroundColor Green
}
