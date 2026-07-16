<#
  audit_test_coverage.ps1 -- Test Coverage Auditor
  Maps QIDM combinations to test log files and generates a coverage report.

  Usage:
    .\audit_test_coverage.ps1                                  # All providers
    .\audit_test_coverage.ps1 -Path providers\FL_FCIC\FL_FCIC_MC.json
    .\audit_test_coverage.ps1 -OutFile coverage_report.txt

  Checks:
    1. Combo Inventory     -- extract all CommSys QIDM combos from JSON
    2. Test Log Inventory  -- scan logs/<Entity>/ directories for .txt files (legacy: tests/)
    3. Coverage Matrix     -- match combos to test logs (fuzzy)
    4. SQVR Alignment      -- compare [CONFIRMED] vs test log count
    5. Orphan Test Logs    -- test logs that don't match any combo
    6. Overall Summary     -- coverage percentage + missing tests

  -Gate mode (blocking iterate-phase gate):
    Computes a per-provider loop verdict and exits non-zero if ANY provider is
    INCONSISTENT. The three verdicts:
      CLOSED                -- nothing [PENDING]; every path [CONFIRMED]-with-XML or
                               [APPROVED SKIP]; TEST_MATRIX combo count == JSON; version aligned.
      INCOMPLETE-consistent -- combos still [PENDING], no contradictions. Legitimate for a
                               freshly-built / not-yet-tested provider (e.g. FL v5.0). NOT done.
      INCONSISTENT          -- a contradiction exists (see Gate-Verdict). Exit non-zero.
    Wired into enforce.ps1 as a blocking phase. Default (no -Gate) keeps advisory exit 0.
#>

param(
    [string]$Path,
    [string]$OutFile,
    [switch]$Gate
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent

# Shared active-JSON resolver (handles versioned <PROVIDER>_v<X.Y>.json names)
. "$PSScriptRoot\_resolve_provider_json.ps1"
# docs/ reorg pilot (2026-07-01, NJ_NJCJIS first)
. "$PSScriptRoot\_resolve_docs_path.ps1"
# Shared combo extraction + test-log matching (kept in sync with block_entity.ps1).
. "$PSScriptRoot\_combo_match.ps1"
# Shared provenance + tier helpers (version/fingerprint stamp validation).
. "$PSScriptRoot\_test_provenance.ps1"
# get_entity_fingerprints.ps1 begins with its own param($Path,$OutFile); dot-sourcing
# it executes that param block in THIS scope and would reset our $Path/$OutFile to null.
# Preserve and restore them around the dot-source.
$__savedPath = $Path; $__savedOutFile = $OutFile
. "$PSScriptRoot\get_entity_fingerprints.ps1"
$Path = $__savedPath; $OutFile = $__savedOutFile

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

function Get-ProviderName($jsonPath) {
    $dir = Split-Path $jsonPath -Parent
    return Split-Path $dir -Leaf
}

# Get-CommSysQidms / Get-ComboInfo / Get-ComboShortLabel / Match-TestLogToCombo
# now live in _combo_match.ps1 (dot-sourced above) so the coverage gate and the
# block_entity gate share one matcher and cannot drift.

# ══════════════════════════════════════════════════════════════════════════════
# GATE HELPERS (used only in -Gate mode)
# ══════════════════════════════════════════════════════════════════════════════

# Read the build-script version ($Version = "X.Y"). Mirrors enforce.ps1 / reset_test_package.ps1.
# Prefer the canonical mainline script build_<provider>.ps1 -- providers in a multi-JSON state
# (e.g. NJ: pascal / random_collapsed / random_removed branches) carry several build scripts, and
# the gate evaluates the shipped mainline <PROVIDER>.json, so it must read the mainline version.
function Get-BuildVersion($provDir) {
    $scriptsDir = Join-Path $provDir "scripts"
    if (-not (Test-Path $scriptsDir)) { return $null }
    $provName = Split-Path $provDir -Leaf
    $canonical = Join-Path $scriptsDir ("build_" + $provName.ToLower() + ".ps1")
    $script = $null
    if (Test-Path $canonical) {
        $script = Get-Item $canonical
    } else {
        $script = Get-ChildItem $scriptsDir -Filter "build_*" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' } | Select-Object -First 1
        if (-not $script) {
            $script = Get-ChildItem $scriptsDir -Filter "build_*_mc*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        }
    }
    if (-not $script) { return $null }
    $text = [System.IO.File]::ReadAllText($script.FullName)
    # Allow an optional branch suffix (e.g. "3.6-COLLAPSED") so the compare against .test_version holds.
    if ($text -match '\$Version\s*=\s*["'']([0-9]+\.[0-9]+(?:-[A-Za-z]+)?)["'']') { return $Matches[1] }
    return $null
}

# Read logs/.test_version (the version the current logs belong to). Empty/absent -> $null.
# Legacy fallback: tests/.test_version, for providers not yet migrated off the old tests/ folder.
function Get-TestVersion($provDir) {
    $f = Join-Path (Join-Path $provDir "logs") ".test_version"
    if (-not (Test-Path $f)) { $f = Join-Path (Join-Path $provDir "tests") ".test_version" }
    if (-not (Test-Path $f)) { return $null }
    $v = ((Get-Content $f -Raw) -replace "^﻿", '').Trim()
    if (-not $v) { return $null }
    return $v
}

# Collect test logs: current standard is providers/<PROVIDER>/logs/<Entity>/*.txt (one folder per
# entity, no separate narrative tests/ folder -- eliminated 2026-07-01). Legacy fallback for
# providers not yet migrated: providers/<PROVIDER>/tests/*.txt.
function Get-TestLogFiles($provDir) {
    $logsRoot = Join-Path $provDir "logs"
    $logs = @()
    if (Test-Path $logsRoot) {
        $entityDirs = Get-ChildItem $logsRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '_archive_pre_v*' }
        foreach ($ed in $entityDirs) {
            $entityLogs = @(Get-ChildItem $ed.FullName -Filter "*.txt" -File -ErrorAction SilentlyContinue)
            foreach ($l in $entityLogs) {
                $l | Add-Member -NotePropertyName 'Entity' -NotePropertyValue $ed.Name -Force
            }
            $logs += $entityLogs
        }
    }
    if ($logs.Count -eq 0) {
        $testsDir = Join-Path $provDir "tests"
        if (Test-Path $testsDir) {
            $logs = @(Get-ChildItem $testsDir -Filter "*.txt" -File -ErrorAction SilentlyContinue)
        }
    }
    return @($logs | Sort-Object Name)
}

# Parse the combo count the TEST_MATRIX claims: "COMBO COVERAGE (13/13)" -> 13 (denominator),
# fallback "QIDM SUMMARY (6 QIDMs, 13 combos)" -> 13. Returns $null if no matrix / unparseable.
function Get-MatrixComboCount($provDir, $provName) {
    $m = Find-DocsPath $provDir 'reports' "${provName}_TEST_MATRIX.txt"
    if (-not (Test-Path $m)) { return $null }
    $text = [System.IO.File]::ReadAllText($m)
    if ($text -match 'COMBO COVERAGE\s*\(\s*\d+\s*/\s*(\d+)\s*\)') { return [int]$Matches[1] }
    if ($text -match 'QIDM SUMMARY\s*\(\s*\d+\s*QIDMs?,\s*(\d+)\s*combos?\)') { return [int]$Matches[1] }
    return $null
}

# A negative/empty-form test log carries no XML by design -- excluded from the XML requirement.
function Test-IsNegativeLog($logName) {
    return ($logName -match '(?i)negative')
}

# A log "has XML" when it contains a real angle-bracket element and is not still a stub
# (post_test.ps1 writes "Not captured" / new_test_log.ps1 writes "[PASTE RAW XML HERE]").
function Test-LogHasXml($logFullPath) {
    $text = [System.IO.File]::ReadAllText($logFullPath)
    if ($text -match '\[PASTE RAW XML HERE\]') { return $false }
    # Require an actual XML element (e.g. <Query>, <?xml, <MessageKey>...) somewhere in the log.
    if ($text -match '<\?xml' -or $text -match '<[A-Za-z][\w:.-]*>') { return $true }
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
        if ($provName -eq 'CA_CONTRA_COSTA') { continue }

        # Resolve the active root JSON: bare <PROVIDER>.json, versioned
        # <PROVIDER>_v<X.Y>.json (current standard), then legacy _MC/_BASE. The
        # single/versioned branch is required: merged providers (NJ, FL, CA_CLETS,
        # ...) have no _MC/_BASE suffix and were otherwise silently skipped, so the
        # gate never saw the shipped JSON.
        $jsonPath = Get-ProviderRootJson -ProvDir $dir.FullName -Provider $provName
        if (-not $jsonPath) { continue }

        $providerJsons += [PSCustomObject]@{
            Name = $provName
            Path = $jsonPath
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

    $testLogs = @(Get-TestLogFiles $provDir)

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
                # Logs scanned from a migrated logs/<Entity>/ folder carry an Entity tag -- a combo
                # can only be satisfied by a log from its OWN entity folder. Cross-entity keyRef
                # reuse (e.g. NY_NYSPIN_EJUSTICE Boat's RVEH/RCAR vs Vehicle's RVEH/RCAR) otherwise
                # lets a Vehicle log false-positive-match a same-named Boat combo. Legacy flat
                # tests/ logs carry no Entity tag -- fall back to unscoped matching for those.
                if ($log.PSObject.Properties['Entity'] -and $log.Entity -ne $ent) { continue }
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

    $sqvrPath = Find-DocsPath $provDir 'tracking' "${provName}_SQVR.txt"
    $sqvrConfirmed = 0
    $sqvrPending = 0
    $sqvrApprovedSkip = 0
    $sqvrExists = $false

    if (Test-Path $sqvrPath) {
        $sqvrExists = $true
        $sqvrContent = [System.IO.File]::ReadAllText($sqvrPath)
        $sqvrConfirmed = ([regex]::Matches($sqvrContent, '\[CONFIRMED\]')).Count
        $sqvrPending = ([regex]::Matches($sqvrContent, '\[PENDING\]')).Count
        $sqvrApprovedSkip = ([regex]::Matches($sqvrContent, '\[APPROVED SKIP\]')).Count

        Out-Line "    SQVR file: found"
        Out-Line "    [CONFIRMED]: $sqvrConfirmed"
        Out-Line "    [PENDING]:   $sqvrPending"

        # Alignment = every combo confirmed and nothing pending. The SQVR legitimately carries
        # EXTRA [CONFIRMED] rows beyond the combo set (guardrail / negative / render checks), so an
        # exact count match is the wrong test -- require 0 PENDING and confirmed >= combos instead.
        $sqvrAligned = ($sqvrPending -eq 0) -and ($sqvrConfirmed -ge $testedCombos)
        if ($sqvrAligned) {
            $extra = $sqvrConfirmed - $testedCombos
            $extraNote = if ($extra -gt 0) { " (+$extra guardrail/negative/render rows)" } else { "" }
            Out-LineColor "    Alignment: YES (SQVR confirmed=$sqvrConfirmed >= combos=$testedCombos, 0 pending)$extraNote" "Green"
        } else {
            Out-LineColor "    Alignment: NO (SQVR confirmed=$sqvrConfirmed, tested combos=$testedCombos, pending=$sqvrPending)" "Yellow"
            if ($sqvrPending -gt 0) {
                Out-LineColor "    WARN: SQVR still has $sqvrPending [PENDING] marker(s) -- combos not fully confirmed" "Yellow"
            } else {
                Out-LineColor "    WARN: fewer SQVR [CONFIRMED] than tested combos (SQVR under-marked / truncated -- needs update)" "Yellow"
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
    $sqvrStatus = if (-not $sqvrExists) { "N/A" } elseif (($sqvrPending -eq 0) -and ($sqvrConfirmed -ge $testedCombos)) { "YES" } else { "NO" }
    Out-Line "    SQVR status:"
    if ($sqvrExists) {
        Out-Line "      [CONFIRMED]: $sqvrConfirmed"
        Out-Line "      [PENDING]:   $sqvrPending"
        $sqvrAlignColor = if ($sqvrStatus -eq "YES") { "Green" } else { "Yellow" }
        Out-LineColor "      Aligned with test logs: $sqvrStatus" $sqvrAlignColor
    } else {
        Out-Line "      (no SQVR file)"
    }

    # ── GATE VERDICT (only computed in -Gate mode) ──
    $verdict = $null
    if ($Gate) {
        $buildVer    = Get-BuildVersionForProvider $provDir
        $testVer     = Get-TestVersion $provDir
        $matrixCount = Get-MatrixComboCount $provDir $provName
        $activeTier  = Get-ActiveTier $provDir

        # Per-entity current fingerprints (for provenance match).
        $entFp = @{}
        try { $entFp = Get-EntityFingerprints -Path $jsonPath } catch { $entFp = @{} }

        # PROVENANCE PASS -- the core integrity fix. A combo is "validly backed" only
        # when at least one log matching it passes Test-LogProvenance: stamped version ==
        # build version, stamped fingerprint == the entity's current fingerprint, and XML
        # present. Stale or unstamped logs do NOT count, so a [CONFIRMED] marker can never
        # rest on a pre-rebuild or hand-edited log again (the NJ v4.7 failure mode).
        $validBackedCombos = 0
        $staleBackedCombos = 0
        $provenanceNotes = @()
        foreach ($ent in ($combosByEntity.Keys | Sort-Object)) {
            $fpE = $null; if ($entFp.Contains($ent)) { $fpE = $entFp[$ent] }
            foreach ($c in $combosByEntity[$ent]) {
                $matched = @($testLogs | Where-Object { Match-TestLogToCombo $_.Name $c $provName })
                if ($matched.Count -eq 0) { continue }
                $valid = $false; $firstReason = $null
                foreach ($log in $matched) {
                    $pr = Test-LogProvenance $log.FullName $buildVer $fpE
                    if ($pr.Valid) { $valid = $true; break }
                    elseif (-not $firstReason) { $firstReason = ($pr.Reasons -join '; ') }
                }
                if ($valid) { $validBackedCombos++ }
                else {
                    $staleBackedCombos++
                    $lbl = Get-ComboShortLabel $c
                    $provenanceNotes += "$ent $($c.KeyReference) ($lbl): $firstReason"
                }
            }
        }

        $gateReasons = @()
        # Gate: if SQVR claims all combos confirmed (confirmed >= totalCombos, no pending)
        # but the logs don't back it up -- flag INCONSISTENT.
        # Guards skip when SQVR has no/few confirmations (provider not yet tested).
        if ($sqvrConfirmed -ge $totalCombos -and $sqvrPending -eq 0 -and $validBackedCombos -lt $totalCombos) {
            $gateReasons += "Only $validBackedCombos of $totalCombos combo(s) have a valid current-version XML backing log ($staleBackedCombos matched only stale/unstamped logs)"
        }
        if ($null -ne $matrixCount -and $matrixCount -ne $totalCombos) {
            $gateReasons += "TEST_MATRIX combo count ($matrixCount) != JSON combo count ($totalCombos) -- matrix is stale, regenerate"
        }

        # Done-criterion: a provider is not CLOSED until its supported-query set is devdoc-CONFIRMED
        # (STATUS: CONFIRMED in SUPPORTED_QUERIES). PROVISIONAL = the list is still JSON-derived and
        # unverified against the devdoc, i.e. legitimately "not done yet" -- hold at INCOMPLETE
        # (non-blocking) rather than declaring CLOSED. Applies to every future provider.
        $sqConfirmed = $false
        $sqRefPath  = Join-Path (Join-Path $provDir 'docs\reference') "${provName}_SUPPORTED_QUERIES.txt"
        $sqFlatPath = Join-Path (Join-Path $provDir 'docs') "${provName}_SUPPORTED_QUERIES.txt"
        $sqFile = if (Test-Path $sqRefPath) { $sqRefPath } elseif (Test-Path $sqFlatPath) { $sqFlatPath } else { $null }
        if ($sqFile) {
            $sqFirstLine = Get-Content -LiteralPath $sqFile -TotalCount 1
            if ($sqFirstLine -match 'STATUS:\s*CONFIRMED') { $sqConfirmed = $true }
        }

        $notConfirmedNote = $null
        if ($gateReasons.Count -gt 0) {
            $verdict = "INCONSISTENT"
        } elseif ($sqvrExists -and $sqvrPending -eq 0 -and $sqvrConfirmed -gt 0 -and $sqConfirmed) {
            $verdict = "CLOSED"
        } else {
            $verdict = "INCOMPLETE-consistent"
            if ($sqvrExists -and $sqvrPending -eq 0 -and $sqvrConfirmed -gt 0 -and -not $sqConfirmed) {
                $notConfirmedNote = "SUPPORTED_QUERIES not CONFIRMED -- devdoc-verify the query set and flip STATUS: CONFIRMED before declaring this provider done"
            }
        }

        $vColor = switch ($verdict) { "CLOSED" { "Green" } "INCONSISTENT" { "Red" } default { "Yellow" } }
        Out-Line ""
        Out-LineColor "  GATE VERDICT: $verdict" $vColor
        $tvShow = if ($testVer) { "v$testVer" } else { "(unset)" }
        $mcShow = if ($null -ne $matrixCount) { $matrixCount } else { "n/a" }
        Out-Line "    build v$buildVer | tier $activeTier | logs/.test_version $tvShow | combos JSON=$totalCombos matrix=$mcShow"
        Out-Line "    SQVR: $sqvrConfirmed CONFIRMED / $sqvrPending PENDING / $sqvrApprovedSkip APPROVED-SKIP | valid-backed combos: $validBackedCombos"
        foreach ($r in $gateReasons) { Out-LineColor "    - $r" "Red" }
        if ($notConfirmedNote) { Out-LineColor "    - $notConfirmedNote" "Yellow" }
        if ($provenanceNotes.Count -gt 0 -and $verdict -eq 'INCONSISTENT') {
            foreach ($n in ($provenanceNotes | Select-Object -First 12)) { Out-LineColor "      x $n" "DarkYellow" }
        }
    }

    # ── Store summary row ──
    $summaryRows += [PSCustomObject]@{
        Provider  = $provName
        Combos    = $totalCombos
        Tests     = $totalTests
        Coverage  = "$coveragePct%"
        SqvrMatch = $sqvrStatus
        Verdict   = $verdict
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

# ══════════════════════════════════════════════════════════════════════════════
# GATE SUMMARY + EXIT (only in -Gate mode)
# ══════════════════════════════════════════════════════════════════════════════

if ($Gate) {
    Out-Line ""
    Out-LineColor "========================================" "Cyan"
    Out-LineColor " ITERATE-PHASE GATE VERDICTS" "Cyan"
    Out-LineColor "========================================" "Cyan"

    $inconsistent = @($summaryRows | Where-Object { $_.Verdict -eq "INCONSISTENT" })
    foreach ($row in ($summaryRows | Sort-Object Provider)) {
        if (-not $row.Verdict) { continue }
        $c = switch ($row.Verdict) { "CLOSED" { "Green" } "INCONSISTENT" { "Red" } default { "Yellow" } }
        Out-LineColor ("  {0,-24} {1}" -f $row.Provider, $row.Verdict) $c
    }

    if ($OutFile) {
        $output.ToString() | Out-File -FilePath $OutFile -Encoding utf8
    }

    Out-Line ""
    if ($inconsistent.Count -gt 0) {
        Out-LineColor "  GATE: BLOCKED -- $($inconsistent.Count) provider(s) INCONSISTENT" "Red"
        Out-Line "  Fix the contradictions above before declaring any provider tested/DONE."
        exit 1
    } else {
        Out-LineColor "  GATE: PASS -- no INCONSISTENT providers (CLOSED or INCOMPLETE-consistent)" "Green"
        exit 0
    }
}
