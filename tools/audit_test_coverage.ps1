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
      UNCOVERED             -- (2026-08-31) the provider is TENANT-VERIFIED at its current version,
                               yet a BUILT combo has NO log and NO registered existence-class
                               exception. Exit non-zero.
    Wired into enforce.ps1 as a blocking phase. Default (no -Gate) keeps advisory exit 0.

  WHY UNCOVERED EXISTS -- the link that was measured but never gated.
    Rob, 2026-08-31: "how do we confidently say that all providers that are swept have all the logs
    that match every combination and no combo was left out unless explicitly told to." By gate, we
    could not. Every OTHER link was blocking -- devdoc->built (2p), metadata->built (2n/2b),
    built->reachable (2h), planned->logged (plan completeness), logged->truthful (6c/6d/2i) -- but
    BUILT->PLANNED was not. A built combo that emit_test_plan generates no test for produces no test,
    no log, and NO FAILURE, because ALL-PASS means "every PLAN test passed", not "every COMBO was
    tested". OH_LEADS's dealer-plate ATDP had no plan test at all and was found by hand. This tool
    already collected $untestedCombos and only PRINTED them; -Gate failed solely on INCONSISTENT, so
    a CONSISTENTLY INCOMPLETE provider passed. Measuring is not gating.
  SCOPE is deliberate: ALL-PASS providers only, via the shared _test_status_lib classifier. A
    never-tested provider has zero logs, so gating it would redden 7 providers for work not yet owed
    -- a FAIL nobody can clear, which LAW 2b calls noise.
  EXEMPTION is the registry, existence class only (dead-combo / not-built / shadow / unbuilt /
    dropped-combo) via the shared Get-DivergenceRuleClass. That IS "explicitly told to". FL_FCIC's
    FBQBoatHullIdNumber / FBQRegistrationNumber are exactly this -- dead by Rob's explicit 2026-08-12
    ruling -- so FL reads 28/30 logged, 2 registered-exempt, 0 UNCOVERED.
  SOUND ON FILENAMES because enforce 2i (audit_log_combo_attribution) is ALREADY BLOCKING and proves
    every log's NAMED combo is what fired; given 2i green, filename-coverage == attribution-coverage.
    Re-replaying here would duplicate 2i (LAW 4). If 2i is ever demoted, revisit this.
  BASELINE 2026-08-31: 19 providers scoped / 0 UNCOVERED / 0 INCONSISTENT -- it lands at ZERO, the
    only honest way to introduce a gate. LAW 2 proven by commenting out FL's two dead-combo rows:
    the verdict flipped INCOMPLETE-consistent -> UNCOVERED naming both combos, and back on restore.
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
# _test_status_lib: the SAME ALL-PASS classifier portfolio_status / SESSION_STATE /
# report_mission_status use, so the combo->log coverage gate cannot disagree with them about which
# providers are tenant-verified and therefore owe coverage.
. "$PSScriptRoot\_test_status_lib.ps1"
# _divergence_rules: Get-DivergenceRuleClass -- ONE definition of "existence class"
# (dead-combo / not-built / shadow / unbuilt / dropped-combo) shared with audit_metadata and
# audit_requirement_fidelity, so those gates and this one can never disagree about what an
# approved not-built decision looks like.
. "$PSScriptRoot\_divergence_rules.ps1"
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
    # LABEL PRECISION (2026-07-29): this is COMBO coverage -- a combo counts as covered once it
    # has >=1 matching log, so a combo with 1 of its 6 PLANNED tests captured still reads 100%.
    # FL_FCIC reported "Coverage 100%" with 7 Boat plan tests never captured. Plan completeness is
    # a DIFFERENT measure -- see report_test_status/portfolio_status (OwedPlanTests -> PARTIAL).
    Out-LineColor "    Combo coverage:         $coveragePct%  (combos with >=1 log; NOT plan-test completeness -- see report_test_status for owed tests)" $coverageColor

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

        # Blocked entities may be legitimately PRESERVED at an older version than the
        # current global build (reset_test_package.ps1 keeps an entity blocked across a
        # rebuild as long as its fingerprint is unchanged -- see block_entity.ps1). Their
        # still-valid pre-rebuild logs are stamped with that preserved version, not the
        # current one, so provenance must accept EITHER version for a blocked entity, or a
        # legitimately-preserved entity gets misflagged as stale/INCONSISTENT.
        $stateJsonPath = Join-Path (Join-Path $provDir "logs") ".test_state.json"
        if (-not (Test-Path $stateJsonPath)) { $stateJsonPath = Join-Path (Join-Path $provDir "tests") ".test_state.json" }
        $blockedVersions = @{}
        if (Test-Path $stateJsonPath) {
            try {
                $ts = Get-Content $stateJsonPath -Raw | ConvertFrom-Json
                if ($ts.entities) {
                    foreach ($p in $ts.entities.PSObject.Properties) {
                        if ($p.Value.status -eq 'blocked' -and $p.Value.version) { $blockedVersions[$p.Name] = "$($p.Value.version)" }
                    }
                }
            } catch { $blockedVersions = @{} }
        }

        # PROVENANCE PASS -- the core integrity fix. A combo is "validly backed" only
        # when at least one log matching it passes Test-LogProvenance: stamped version ==
        # build version (or the entity's preserved blocked version), stamped fingerprint ==
        # the entity's current fingerprint, and XML present. Stale or unstamped logs do NOT
        # count, so a [CONFIRMED] marker can never rest on a pre-rebuild or hand-edited log
        # again (the NJ v4.7 failure mode).
        $validBackedCombos = 0
        $staleBackedCombos = 0
        $provenanceNotes = @()
        foreach ($ent in ($combosByEntity.Keys | Sort-Object)) {
            $fpE = $null; if ($entFp.Contains($ent)) { $fpE = $entFp[$ent] }
            $acceptVers = @($buildVer)
            if ($blockedVersions.ContainsKey($ent) -and ($blockedVersions[$ent] -ne $buildVer)) { $acceptVers += $blockedVersions[$ent] }
            foreach ($c in $combosByEntity[$ent]) {
                # Entity-scoped: a log tagged with a DIFFERENT entity's folder can never back
                # this combo, even if its filename happens to contain the same keyRef (e.g.
                # NY_NYSPIN_EJUSTICE Boat's RVEH/RCAR vs Vehicle's RVEH/RCAR).
                $matched = @($testLogs | Where-Object {
                    (-not $_.PSObject.Properties['Entity'] -or $_.Entity -eq $ent) -and (Match-TestLogToCombo $_.Name $c $provName)
                })
                if ($matched.Count -eq 0) { continue }
                $valid = $false; $firstReason = $null
                foreach ($log in $matched) {
                    foreach ($v in $acceptVers) {
                        $pr = Test-LogProvenance $log.FullName $v $fpE
                        if ($pr.Valid) { $valid = $true; break }
                        elseif (-not $firstReason) { $firstReason = ($pr.Reasons -join '; ') }
                    }
                    if ($valid) { break }
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

        # ── COMBO -> LOG COVERAGE, AS A GATE (added 2026-08-31) ────────────────────────────────────
        # THE LINK THIS CLOSES. Rob: "how do we confidently say that all providers that are swept have
        # all the logs that match every combination and no combo was left out unless explicitly told
        # to." Until now: we could not, by gate. Every OTHER link in the chain was blocking --
        # devdoc->built (2p), metadata->built (2n/2b), built->reachable (2h), planned->logged
        # (plan completeness), logged->truthful (6c/6d/2i) -- but BUILT->PLANNED was not. A built combo
        # that emit_test_plan generates no test for produces no test, no log, and NO FAILURE, because
        # ALL-PASS means "every PLAN test passed", not "every COMBO was tested". It has already bitten
        # once: OH_LEADS's dealer-plate ATDP had no plan test at all, found only by hand.
        # This tool already computed $untestedCombos and only PRINTED them; -Gate failed solely on
        # INCONSISTENT, so a provider that was CONSISTENTLY INCOMPLETE passed. Measuring it is not the
        # same as gating it.
        #
        # SCOPED TO TENANT-VERIFIED PROVIDERS, and that scope is load-bearing, not a softener: a
        # never-tested provider has ZERO logs, so every combo is trivially "untested" and gating it
        # would redden 7 providers for work that is not yet owed -- turning a real gate into noise
        # nobody can clear (LAW 2b). Uses the SAME classifier as portfolio_status / SESSION_STATE /
        # report_mission_status, so the four cannot disagree.
        #
        # EXEMPTION IS THE REGISTRY, AND ONLY THE EXISTENCE CLASS. A combo carrying a
        # dead-combo / not-built / shadow / unbuilt / dropped-combo row is a decision already taken
        # with reasoning a stranger can evaluate; that IS "explicitly told to". Classified by
        # Get-DivergenceRuleClass rather than a local pattern, so this gate and audit_metadata /
        # audit_requirement_fidelity can never disagree about what an existence rule is. FL_FCIC's two
        # Boat combos (FBQBoatHullIdNumber, FBQRegistrationNumber) are exactly this: dead by Rob's
        # explicit 2026-08-12 decision, so FL's 10/12 Boat coverage is CORRECT and this gate says so.
        #
        # WHY IT IS SOUND TO MATCH ON THE LOG FILENAME rather than replaying each wire: enforce 2i
        # (audit_log_combo_attribution) is ALREADY BLOCKING and proves every log's NAMED combo is what
        # actually fired. Given 2i green, filename-coverage and attribution-coverage are the same set.
        # Re-replaying here would duplicate 2i (LAW 4). If 2i is ever demoted, this reasoning dies with
        # it -- so do not demote it without revisiting this comment.
        $uncoveredUnexempt = @()
        $coverageScoped    = $false
        $exemptNames       = @()
        $tState = $null
        try { $tState = Get-ProviderTestState -ProvDir $provDir -Name $provName } catch { $tState = $null }
        if ($tState -and "$($tState.State)" -eq 'ALL-PASS') {
            $coverageScoped = $true
            $regPath = Find-DocsPath $provDir 'tracking' "${provName}_ACCEPTED_DIVERGENCES.txt"
            $regLines = if ($regPath -and (Test-Path $regPath)) { Get-Content -LiteralPath $regPath } else { @() }
            foreach ($u in $untestedCombos) {
                $kr = "$($u.KeyReference)"
                $exempt = $false
                foreach ($rl in $regLines) {
                    if ($rl -match '^\s*#') { continue }
                    $cols = $rl -split '\|'
                    if ($cols.Count -lt 4) { continue }
                    if ("$($cols[1])".Trim() -ne $kr) { continue }
                    if ((Get-DivergenceRuleClass "$($cols[3])".Trim()) -eq 'existence') { $exempt = $true; break }
                }
                if ($exempt) { $exemptNames += $kr } else { $uncoveredUnexempt += $u }
            }
        }

        $notConfirmedNote = $null
        if ($gateReasons.Count -gt 0) {
            $verdict = "INCONSISTENT"
        } elseif ($coverageScoped -and $uncoveredUnexempt.Count -gt 0) {
            # A tenant-verified provider with a built combo that has no log and no registered
            # existence-class exception. Distinct from INCONSISTENT: nothing here CONTRADICTS anything
            # -- the records agree, and they agree that a combo was never tested.
            $verdict = "UNCOVERED"
        } elseif ($sqvrExists -and $sqvrPending -eq 0 -and $sqvrConfirmed -gt 0 -and $sqConfirmed) {
            $verdict = "CLOSED"
        } else {
            $verdict = "INCOMPLETE-consistent"
            if ($sqvrExists -and $sqvrPending -eq 0 -and $sqvrConfirmed -gt 0 -and -not $sqConfirmed) {
                $notConfirmedNote = "SUPPORTED_QUERIES not CONFIRMED -- devdoc-verify the query set and flip STATUS: CONFIRMED before declaring this provider done"
            }
        }

        $vColor = switch ($verdict) { "CLOSED" { "Green" } "INCONSISTENT" { "Red" } "UNCOVERED" { "Red" } default { "Yellow" } }
        Out-Line ""
        Out-LineColor "  GATE VERDICT: $verdict" $vColor
        $tvShow = if ($testVer) { "v$testVer" } else { "(unset)" }
        $mcShow = if ($null -ne $matrixCount) { $matrixCount } else { "n/a" }
        Out-Line "    build v$buildVer | tier $activeTier | logs/.test_version $tvShow | combos JSON=$totalCombos matrix=$mcShow"
        Out-Line "    SQVR: $sqvrConfirmed CONFIRMED / $sqvrPending PENDING / $sqvrApprovedSkip APPROVED-SKIP | valid-backed combos: $validBackedCombos"
        foreach ($r in $gateReasons) { Out-LineColor "    - $r" "Red" }
        if ($verdict -eq "UNCOVERED") {
            Out-LineColor "    - $($uncoveredUnexempt.Count) BUILT combo(s) have NO log and NO registered existence-class exception:" "Red"
            foreach ($u in $uncoveredUnexempt) { Out-LineColor "        $($u.Entity) $($u.Query) $($u.KeyReference)" "Red" }
            Out-Line          "      Fix by testing them, or record the decision in ${provName}_ACCEPTED_DIVERGENCES.txt with an"
            Out-Line          "      existence-class rule (dead-combo / not-built / shadow) and a reason a stranger can evaluate."
        }
        if ($coverageScoped) {
            Out-Line "    combo->log coverage: $($totalCombos - $untestedCombos.Count)/$totalCombos logged, $($exemptNames.Count) registered-exempt$(if($exemptNames.Count){" ($($exemptNames -join ', '))"}), $($uncoveredUnexempt.Count) UNCOVERED"
        } else {
            Out-Line "    combo->log coverage: NOT SCOPED -- provider is not ALL-PASS at its current version, so no coverage is owed yet"
        }
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
    $uncovered    = @($summaryRows | Where-Object { $_.Verdict -eq "UNCOVERED" })
    foreach ($row in ($summaryRows | Sort-Object Provider)) {
        if (-not $row.Verdict) { continue }
        $c = switch ($row.Verdict) { "CLOSED" { "Green" } "INCONSISTENT" { "Red" } "UNCOVERED" { "Red" } default { "Yellow" } }
        Out-LineColor ("  {0,-24} {1}" -f $row.Provider, $row.Verdict) $c
    }

    if ($OutFile) {
        $output.ToString() | Out-File -FilePath $OutFile -Encoding utf8
    }

    # PRINT THE DENOMINATOR. A gate that reports "0 problems" without saying how many providers it
    # actually SCOPED is the vacuous pass this repo keeps finding (ENGINEERING_STANDARD 4.3):
    # audit_sqvr_integrity CHECK 2 compared NOTHING on 17 of 20 while printing PASS.
    $scopedCount = @($summaryRows | Where-Object { $_.Verdict }).Count
    Out-Line ""
    Out-Line "  SCOPE: $scopedCount provider(s) received a verdict; combo->log coverage is gated only on"
    Out-Line "         providers that are ALL-PASS at their current version (a never-tested provider owes none)."
    if ($scopedCount -eq 0) {
        Out-LineColor "  [NO-VERDICT] no provider was evaluated -- this is NOT a pass" "Red"
        exit 1
    }

    Out-Line ""
    if ($inconsistent.Count -gt 0 -or $uncovered.Count -gt 0) {
        if ($inconsistent.Count -gt 0) {
            Out-LineColor "  GATE: BLOCKED -- $($inconsistent.Count) provider(s) INCONSISTENT" "Red"
            Out-Line "  Fix the contradictions above before declaring any provider tested/DONE."
        }
        if ($uncovered.Count -gt 0) {
            Out-LineColor "  GATE: BLOCKED -- $($uncovered.Count) provider(s) UNCOVERED (a BUILT combo has no log and no registered exception)" "Red"
            Out-Line "  Either test the named combo(s), or record the decision in the provider's ACCEPTED_DIVERGENCES"
            Out-Line "  with an existence-class rule and a reason a stranger can evaluate. Do NOT clear this by"
            Out-Line "  deleting the combo -- 'we do not leave out queries because it is hard' (Rob, AZ_AZDPS)."
        }
        exit 1
    } else {
        Out-LineColor "  GATE: PASS -- no INCONSISTENT and no UNCOVERED providers" "Green"
        exit 0
    }
}
