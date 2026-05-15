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
$repoRoot = Split-Path $PSScriptRoot -Parent

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

# Build a short label for a combo (e.g., "FRQ+Plate", "KQ+OLN", "IA.QV")
# This is what test log filenames typically contain.
function Get-ComboShortLabel($combo) {
    $kr = $combo.KeyReference
    if (-not $kr) { return $null }

    # For dotted keyRefs (CA providers: IA.QV, NLTS.RQ.P, etc.) return as-is
    if ($kr -match '\.') { return $kr }

    # Extract prefix (FRQ, DQ, KQ, QG, QA, QB, BQ, RQ, QV, QW, FDQ, FBQ, etc.)
    $prefix = ""
    if ($kr -match '^(FRQ|FDQ|FBQ|NLTS|QB|QV|QW|QG|QA|BQ|RQ|DQ|KQ)') {
        $prefix = $Matches[1]
    } elseif ($kr -match '^([A-Z]{2,4})') {
        $prefix = $Matches[1]
    }
    if (-not $prefix) { return $kr }

    # Determine the field keyword from what remains after the prefix
    $remainder = $kr.Substring($prefix.Length)
    $fieldWord = ""

    # Map common field names to their test-log abbreviations
    if ($remainder -match 'LicensePlateNumber') { $fieldWord = "Plate" }
    elseif ($remainder -match 'VehicleIdentificationNumber') { $fieldWord = "VIN" }
    elseif ($remainder -match 'OperatorLicenseNumber') { $fieldWord = "OLN" }
    elseif ($remainder -match '^Name$') { $fieldWord = "Name" }
    elseif ($remainder -match 'GunSerialNumber|ArticleSerialNumber|serialNumber') { $fieldWord = "Serial" }
    elseif ($remainder -match 'NCICNumber') { $fieldWord = "NCIC" }
    elseif ($remainder -match 'ProcessControlNumber') { $fieldWord = "PCN" }
    elseif ($remainder -match 'BoatHullIdNumber') { $fieldWord = "Hull" }
    elseif ($remainder -match 'RegistrationNumber') { $fieldWord = "Reg" }
    elseif ($remainder -match 'CoastGuardDocumentNumber') { $fieldWord = "CG" }
    elseif ($remainder -match 'DecalNumber') { $fieldWord = "Decal" }
    elseif ($remainder -match 'TitleLienInformation') { $fieldWord = "Title" }
    elseif ($remainder -match 'OwnerAppliedNumber') { $fieldWord = "OAN" }
    else { $fieldWord = $remainder }

    return "$prefix+$fieldWord"
}

function Match-TestLogToCombo($logName, $combo, $providerName) {
    $kr = $combo.KeyReference
    if (-not $kr) { return $false }

    $logUpper = $logName.ToUpper()
    $entity = $combo.Entity

    # ── TIER 1: Exact keyReference in filename ──
    # e.g., "IA.QV" or "FRQLicensePlateNumber" literally in the filename
    if ($logUpper.Contains($kr.ToUpper())) { return $true }

    # ── TIER 2: Short label match (PREFIX+FIELD) ──
    # Test logs commonly use format: DATE_Entity_PREFIX+Field_Description.txt
    # e.g., "2026-05-01_Vehicle_FRQ+Plate_..." matches combo with label "FRQ+Plate"
    # Use boundary-aware match to prevent "RQ+Plate" matching inside "FRQ+Plate"
    $shortLabel = Get-ComboShortLabel $combo
    if ($shortLabel) {
        $escaped = [regex]::Escape($shortLabel.ToUpper())
        if ($logUpper -match "(^|[_\.\s])${escaped}([_\.\+\s]|$)") { return $true }
    }

    # ── TIER 3: Entity + exact prefix match ──
    # Must match entity AND the combo prefix with appropriate delimiters
    if (-not $entity) { return $false }
    if (-not $logUpper.Contains($entity.ToUpper())) { return $false }

    # Extract the combo prefix (FRQ, DQ, KQ, QG, QA, QB, BQ, RQ, QV, QW, FDQ, FBQ, etc.)
    $prefix = ""
    if ($kr -match '^(FRQ|FDQ|FBQ|NLTS|QB|QV|QW|QG|QA|BQ|RQ|DQ|KQ)') {
        $prefix = $Matches[1]
    }
    # For dotted keyRefs, extract the dotted prefix
    $dottedPrefix = ""
    if ($kr -match '^([A-Z]+\.[A-Z]+(?:\.[A-Z]+)?)') {
        $dottedPrefix = $Matches[1]
    }

    if ($prefix) {
        $pUpper = $prefix.ToUpper()
        # Match prefix with delimiter boundaries: _FRQ+ _FRQ_ .FRQ. _FRQ.
        if ($logUpper -match "[\._]${pUpper}[\+\._]|[\._]${pUpper}\b") {
            # Prefix matched inside the entity's filename. Now verify field alignment
            # to avoid FRQ+Plate matching a FRQ+VIN test log when they share prefix.
            $shortLabel2 = Get-ComboShortLabel $combo
            if ($shortLabel2) {
                $fieldPart = ($shortLabel2 -split '\+', 2)[1]
                if ($fieldPart) {
                    $fUpper = $fieldPart.ToUpper()
                    # Check if the field keyword is also in the filename
                    if ($logUpper.Contains($fUpper)) { return $true }
                }
            }
            # If we could not determine a specific field, the prefix alone is not enough
            # to avoid false positives. Fall through to tier 4.
        }
    }
    if ($dottedPrefix) {
        if ($logUpper.Contains($dottedPrefix.ToUpper())) { return $true }
    }

    # ── TIER 4: Entity + primary set field keyword ──
    # Last resort: match entity + a distinctive keyword from the first set[] field
    # Only use this if there is exactly one distinguishing set field pattern
    # (to avoid false positives between combos sharing entity)
    # We intentionally do NOT match here -- tiers 1-3 should cover standard naming.

    return $false
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
        if ($provName -match '_(BLOCKED)$' -or $provName -eq 'CA_CONTRA_COSTA') { continue }

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
            $label = Get-ComboShortLabel $c
            Out-Line "        $($c.KeyReference) ($label)  set=[$setStr]$anyStr"
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
                $label = Get-ComboShortLabel $c
                $entResults += [PSCustomObject]@{
                    Mark  = [char]0x2713  # checkmark
                    Combo = "$($c.KeyReference) ($label)"
                    File  = $matchFile
                    Color = "Green"
                }
            } else {
                $label = Get-ComboShortLabel $c
                $untestedCombos += $c
                $entResults += [PSCustomObject]@{
                    Mark  = [char]0x2717  # X mark
                    Combo = "$($c.KeyReference) ($label)"
                    File  = "NOT TESTED"
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
            $padCombo = $r.Combo.PadRight(40)
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

    $sqvrPath = Join-Path (Join-Path $provDir "docs") "${provName}_SQVR.txt"
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

        # Compare: SQVR confirmed should roughly match tested combo count
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
            $label = Get-ComboShortLabel $u
            Out-LineColor "      - $($u.Entity) $($u.Query) $($u.KeyReference) ($label)" "Red"
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

$hdr = "Provider".PadRight($colProv) +
       "Combos".PadRight($colCombo) +
       "Tests".PadRight($colTests) +
       "Coverage".PadRight($colCov) +
       "SQVR Match"
Out-LineColor $hdr "White"
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
$weightedMatched = 0
foreach ($row in $summaryRows) {
    $pctVal = $row.Coverage -replace '%',''
    if ($pctVal -match '^\d+$') {
        $weightedMatched += [int]$pctVal * $row.Combos / 100
    }
}
$overallPct = if ($totalAllCombos -gt 0) { [math]::Round($weightedMatched / $totalAllCombos * 100) } else { 0 }

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
