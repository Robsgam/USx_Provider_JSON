# post_test.ps1
# Instant-save tool for test results. After ANY test completes, this script
# immediately saves all artifacts, updates docs, commits, and pushes.
#
# ── COMBO TEST (with XML from server logs) ──────────────────────────────────
#   pwsh -File tools\post_test.ps1 `
#     -Provider TX_TLETS -Entity Person -Query DriverLicenseQuery `
#     -Combo "DQ+Name" -Result PASS -Description "DL by Name" `
#     -XmlRequest "<xml>...</xml>" -FormState "Sex=M, DOB=01/15/1990, Last=DOE, First=JOHN"
#
# ── RENDER GATE (no query fired — visual check only) ────────────────────────
#   pwsh -File tools\post_test.ps1 `
#     -Provider TX_TLETS -Entity Person -Query RENDER -Combo RENDER `
#     -Result PASS -Description "Person RENDER gate" -Render
#
# ── NEGATIVE TEST (empty form, no Send) ─────────────────────────────────────
#   pwsh -File tools\post_test.ps1 `
#     -Provider TX_TLETS -Entity Person -Query NEGATIVE -Combo NEGATIVE `
#     -Result PASS -Description "Empty form no send" -Negative
#
# ── FAIL (any test type — no XML required) ──────────────────────────────────
#   pwsh -File tools\post_test.ps1 `
#     -Provider TX_TLETS -Entity Person -Query DriverLicenseQuery `
#     -Combo "DQ+Name" -Result FAIL -Description "Wrong keyRef" `
#     -Notes "Expected DQ fired QW instead"
#
# ── RMS PAIR (optional, Person/Vehicle only) ────────────────────────────────
#   Add -RmsRequestJson (the RMS-side elasticQuery JSON string) and -RmsResponse
#   (e.g. "No Returns") when captured. Absent is normal for Gun/Article/Boat/DH
#   (no RMS mapping exists for those entities) -- not a gap to chase.
#   Writes the log's RMS QUERY section AND a standalone logs/rms/<stem>.json
#   snippet (paired with logs/xml/<stem>.xml, same filename stem as the log).

param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Entity,
    [Parameter(Mandatory)][string]$Query,
    [Parameter(Mandatory)][string]$Combo,
    [Parameter(Mandatory)][ValidateSet('PASS','FAIL')][string]$Result,
    [Parameter(Mandatory)][string]$Description,

    [string]$XmlRequest,
    [string]$XmlResponse,
    [string]$FormState,
    [string]$RmsRequestJson,  # RMS-side elasticQuery JSON (Person/Vehicle only; absent = no RMS mapping for this entity, not a gap)
    [string]$RmsResponse,     # RMS-side response text (e.g. "No Returns")
    [string]$Notes,
    [string]$Tier,   # tiers removed 2026-07-01; defaults to 'Full' via Get-ActiveTier
    [switch]$NoCommit,
    [switch]$Negative,
    [switch]$Render
)

$ErrorActionPreference = "Stop"

# Shared provenance helpers (version/fingerprint/tier resolution + stamp parsing).
. "$PSScriptRoot\_test_provenance.ps1"
. "$PSScriptRoot\get_entity_fingerprints.ps1"
. "$PSScriptRoot\_resolve_provider_json.ps1"

# ============================================================================
# HARD GATE: No XML = No PASS (unless negative test)
# ============================================================================

if ($Result -eq 'PASS' -and -not $Negative -and -not $Render -and (-not $XmlRequest -or $XmlRequest.Trim().Length -eq 0)) {
    Write-Host ""
    Write-Host "  BLOCKED: Cannot save PASS without XML evidence." -ForegroundColor Red
    Write-Host "  Pass -XmlRequest with the server log XML, or use -Negative for empty-form tests." -ForegroundColor Red
    Write-Host ""
    exit 1
}

# ============================================================================
# HELPERS
# ============================================================================

function Write-Step($step, $total, $msg) {
    Write-Host ""
    Write-Host "  [$step/$total] $msg" -ForegroundColor Yellow
}
function Write-Ok($msg)   { Write-Host "         $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    WARN $msg" -ForegroundColor DarkYellow }
function Write-Err($msg)  { Write-Host "   ERROR $msg" -ForegroundColor Red }

# Query name -> short code for filenames
function Get-QueryShort([string]$queryName) {
    switch -Wildcard ($queryName) {
        'VehicleRegistrationQuery'      { return 'VehReg' }
        'VehicleInsuranceRegistrationQuery' { return 'VehReg' }
        'VehicleStolenQuery'            { return 'VehStolen' }
        'DriverLicenseQuery'            { return 'DL' }
        'DriverHistoryQuery'            { return 'DH' }
        'GunQuery'                      { return 'Gun' }
        'ArticleSingleQuery'            { return 'Article' }
        'BoatQuery'                     { return 'Boat' }
        'WantedPersonQuery'             { return 'WantedPerson' }
        'WMPIPersonWINQQuery'           { return 'WINQ' }
        'WMPIPersonMINQQuery'           { return 'MINQ' }
        'CAISupervisedReleaseQuery'     { return 'SuperRelease' }
        default                         { return ($queryName -replace 'Query$','') }
    }
}

# Attempt to extract fields from XML request for auto-analysis
function Get-XmlFieldAnalysis([string]$xml) {
    if (-not $xml -or $xml.Trim().Length -eq 0) { return $null }
    $lines = @()
    # Simple regex extraction of XML element values
    $matches = [regex]::Matches($xml, '<(\w+)>([^<]+)</\1>')
    foreach ($m in $matches) {
        $fieldName = $m.Groups[1].Value
        $fieldVal  = $m.Groups[2].Value.Trim()
        # Skip wrapper elements and noise
        if ($fieldName -notin @('MessageType','Transaction','TransactionId','QueryType',
            'RequestMessage','ResponseMessage','soap','Body','Header','Envelope')) {
            $lines += "  {0,-30} {1}" -f $fieldName, $fieldVal
        }
    }
    if ($lines.Count -gt 0) {
        return ($lines -join "`n")
    }
    return $null
}

# ============================================================================
# STEP 0: RESOLVE PATHS
# ============================================================================

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " POST-TEST SAVE: $Provider $Entity $Query" -ForegroundColor Cyan
Write-Host " Combo: $Combo  Result: $Result" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$totalSteps = if ($NoCommit) { 5 } else { 6 }

# ============================================================================
# STEP 1: LOCATE PROVIDER
# ============================================================================

Write-Step 1 $totalSteps "Locating provider directory..."

$providerDir = Join-Path $repoRoot "providers\$Provider"
if (-not (Test-Path $providerDir)) {
    # Try case-insensitive search
    $found = Get-ChildItem (Join-Path $repoRoot "providers") -Directory |
        Where-Object { $_.Name -ieq $Provider } | Select-Object -First 1
    if ($found) {
        $providerDir = $found.FullName
        $Provider = $found.Name
    } else {
        Write-Err "Provider directory not found: providers\$Provider"
        Write-Err "Available providers:"
        Get-ChildItem (Join-Path $repoRoot "providers") -Directory | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
        exit 1
    }
}

$testsDir = Join-Path $providerDir "tests"
if (-not (Test-Path $testsDir)) {
    New-Item -ItemType Directory -Path $testsDir -Force | Out-Null
    Write-Warn "Created missing tests/ directory"
}

$docsDir = Join-Path $providerDir "docs"
if (-not (Test-Path $docsDir)) {
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    Write-Warn "Created missing docs/ directory"
}

Write-Ok "Provider: $providerDir"
Write-Ok "Tests:    $testsDir"

# ── Resolve provenance stamp: build version + this entity's fingerprint + tier ──
# Stamped into the log so a [CONFIRMED] combo can later be proven to rest on a log
# run against THIS JSON version + entity structure (not a stale or hand-edited log).
$buildVersion = Get-BuildVersionForProvider $providerDir
if (-not $buildVersion) { $buildVersion = "unknown" }

$entityFingerprint = $null
$activeJsonPath = Get-ProviderRootJson -ProvDir $providerDir -Provider $Provider
if ($activeJsonPath -and (Test-Path $activeJsonPath)) {
    try {
        $fpMap = Get-EntityFingerprints -Path $activeJsonPath
        if ($fpMap.Contains($Entity)) { $entityFingerprint = $fpMap[$Entity] }
    } catch { }
}
if (-not $entityFingerprint) { $entityFingerprint = "unknown" }

if (-not $Tier) { $Tier = Get-ActiveTier $providerDir }

Write-Ok "Stamp:    v$buildVersion / $($entityFingerprint.Substring(0,[Math]::Min(12,$entityFingerprint.Length))) / $Tier"

# ============================================================================
# STEP 2: CREATE OR UPDATE TEST LOG
# ============================================================================

Write-Step 2 $totalSteps "Creating test log..."

$dateStr   = Get-Date -Format 'yyyy-MM-dd'
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$queryShort = Get-QueryShort $Query
$descSafe  = $Description -replace '[\\/:*?"<>|,()\[\] ]', '_'
$comboSafe = $Combo -replace '[\\/:*?"<>|,()\[\] ]', '_'

$logFilename = "${Provider}_${Entity}_${queryShort}_${comboSafe}_${descSafe}_${dateStr}.txt"
# Truncate to keep total path (with archive subdir) under MAX_PATH=260.
# Archive adds ~22 chars (_archive_pre_vX.Y\) so cap filename at 155 chars.
if ($logFilename.Length -gt 155) {
    $ext  = ".txt"
    $stem = $logFilename.Substring(0, 155 - $ext.Length)
    $logFilename = "${stem}${ext}"
}
$logPath     = Join-Path $testsDir $logFilename

# Check for existing log for same combo (any date)
$existingLogs = @(Get-ChildItem $testsDir -Filter "${Provider}_${Entity}_${queryShort}_${comboSafe}_*" -File 2>$null)
$isUpdate = $false
if ($existingLogs.Count -gt 0) {
    # Update the most recent one
    $existingLog = $existingLogs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Warn "Found existing log: $($existingLog.Name)"
    Write-Warn "Creating new log (preserving old)"
    $isUpdate = $true
}

# Build form state section (the dex-log field-map JSON, e.g. {"ImageIndicator":"N",...})
$formStateContent = if ($FormState) { $FormState } else { "Not captured" }

# Build XML sections
$xmlReqContent  = if ($XmlRequest)  { $XmlRequest }  else { "Not captured" }
$xmlRespContent = if ($XmlResponse) { $XmlResponse } else { "Not captured" }

# Build RMS section. Absent is EXPECTED (not a gap) for entities with no RMS mapping
# (Gun/Article/Boat/DH -- only Person/Vehicle have one per the RMS bundle).
$rmsContent = "Not captured"
if ($RmsRequestJson -or $RmsResponse) {
    $rmsReqPretty = $RmsRequestJson
    if ($RmsRequestJson) {
        try { $rmsReqPretty = ($RmsRequestJson | ConvertFrom-Json | ConvertTo-Json -Depth 8) } catch { $rmsReqPretty = $RmsRequestJson }
    }
    $rmsReqDisplay  = if ($RmsRequestJson) { $rmsReqPretty } else { "Not captured" }
    $rmsRespDisplay = if ($RmsResponse)    { $RmsResponse }  else { "Not captured" }
    $rmsContent = "Request:`n$rmsReqDisplay`n`nResponse:`n$rmsRespDisplay"
}

# Auto-generate field analysis from XML if available
$fieldAnalysis = "Not captured (no XML provided)"
if ($XmlRequest) {
    $autoAnalysis = Get-XmlFieldAnalysis $XmlRequest
    if ($autoAnalysis) {
        $fieldAnalysis = "AUTO-EXTRACTED FROM COMMSYS XML:`n$autoAnalysis"
    } else {
        $fieldAnalysis = "XML provided but no fields extracted (check format)"
    }
}

# Build notes section
$notesContent = if ($Notes) { $Notes } else { "" }

$logContent = @"
================================================================
TEST LOG: $Provider $Entity $Query
Combo: $Combo ($Description)
Date: $timestamp
Result: $Result
JSON Version: $buildVersion
Entity Fingerprint: $entityFingerprint
Tier: $Tier
================================================================

QUERY STRING
------------
$formStateContent

COMMSYS XML
-----------
$xmlReqContent

COMMSYS XML RESPONSE
--------------------
$xmlRespContent

RMS QUERY
---------
$rmsContent

FIELD ANALYSIS
--------------
$fieldAnalysis

NOTES
-----
$notesContent

RESULT: $Result
"@

$logContent | Set-Content -LiteralPath $logPath -Encoding UTF8
Write-Ok "Saved: $logPath"

# Per-query raw snippet files (providers/<PROVIDER>/logs/xml/, logs/rms/) -- byte-faithful
# passthrough of the same content embedded above, broken out standalone so each side is
# independently inspectable/diffable without parsing the narrative log. Filename stem matches
# the test log (minus .txt) so the pair is always findable by name alone.
$logStem = [System.IO.Path]::GetFileNameWithoutExtension($logFilename)
if ($XmlRequest) {
    $xmlLogDir = Join-Path $providerDir "logs\xml"
    if (-not (Test-Path $xmlLogDir)) { New-Item -ItemType Directory -Path $xmlLogDir -Force | Out-Null }
    $xmlSnippetPath = Join-Path $xmlLogDir "$logStem.xml"
    $XmlRequest | Set-Content -LiteralPath $xmlSnippetPath -Encoding UTF8
}
if ($RmsRequestJson -or $RmsResponse) {
    $rmsLogDir = Join-Path $providerDir "logs\rms"
    if (-not (Test-Path $rmsLogDir)) { New-Item -ItemType Directory -Path $rmsLogDir -Force | Out-Null }
    $rmsSnippetPath = Join-Path $rmsLogDir "$logStem.json"
    $rmsRequestObj = $null
    if ($RmsRequestJson) { try { $rmsRequestObj = $RmsRequestJson | ConvertFrom-Json } catch { $rmsRequestObj = $RmsRequestJson } }
    ([PSCustomObject]@{ request = $rmsRequestObj; response = $RmsResponse } | ConvertTo-Json -Depth 8) |
        Set-Content -LiteralPath $rmsSnippetPath -Encoding UTF8
}

# ============================================================================
# STEP 3: UPDATE SQVR
# ============================================================================

Write-Step 3 $totalSteps "Updating SQVR..."

$sqvrPath = Join-Path $docsDir "${Provider}_SQVR.txt"
$sqvrUpdated = $false

if (Test-Path $sqvrPath) {
    $sqvrLines = @(Get-Content $sqvrPath -Encoding UTF8)

    if ($Result -eq 'PASS') {
        $newMarker = '[CONFIRMED]'
    } else {
        $newMarker = "[FAILED -- $dateStr]"
    }

    # SQVR documents BASE combo names only (e.g. "RQN") -- it has no entries for the
    # any-field/all-any variant labels import_captured_tests.ps1 constructs for log-naming
    # (e.g. "RQN_af_RandomRequest", "DQN_any"). Matching $Combo directly against SQVR text
    # therefore never found a marker for any variant test, only base-combo tests. Strip the
    # variant suffix for SQVR lookup purposes; $Combo (full label) is still used everywhere
    # else (log filename, description, STATUS row) so per-kind logs stay distinct.
    $baseCombo = $Combo -replace '(_af_[A-Za-z0-9]+|_any)$', ''
    $comboEsc = [regex]::Escape($baseCombo)

    # Match ANY marker state, not just [PENDING] -- a combo's FIRST variant test (base,
    # any-field, or all-any -- whichever runs first) already flips the marker away from
    # [PENDING], so every SUBSEQUENT variant of the same combo would otherwise never find a
    # [PENDING] to replace and would falsely WARN. Matching any marker lets us detect the
    # "already at the target state" case (a satisfied no-op, not a warning) while still
    # correctly downgrading CONFIRMED->FAILED (or updating a FAILED date) when the new result
    # actually differs.
    $markerPattern = '\[(?:PENDING|CONFIRMED|FAILED[^\]]*)\]'
    $newMarkerEsc = [regex]::Escape($newMarker)
    $alreadySatisfied = $false

    # Strategy 1: Find "keyReference: <Combo>" line, then look UP for the
    #             description line carrying a marker and replace ONLY that one.
    $keyRefIdx = -1
    for ($i = 0; $i -lt $sqvrLines.Count; $i++) {
        if ($sqvrLines[$i] -match "^\s*keyReference:\s*${comboEsc}(\s|$)") {
            $keyRefIdx = $i
            break
        }
    }

    if ($keyRefIdx -ge 0) {
        # Walk backwards from keyReference line to find the marker description line
        for ($j = $keyRefIdx - 1; $j -ge [Math]::Max(0, $keyRefIdx - 5); $j--) {
            if ($sqvrLines[$j] -match $markerPattern) {
                if ($sqvrLines[$j] -match $newMarkerEsc) { $alreadySatisfied = $true }
                else { $sqvrLines[$j] = $sqvrLines[$j] -replace $markerPattern, $newMarker; $sqvrUpdated = $true }
                break
            }
        }
    }

    # Strategy 2: Combo might be the short name on the description line itself
    #             (e.g., "RQ+Plate", "FRQ+VIN", "REG Plate").
    #             Match: line starts with whitespace + combo text + " -- " + ... + marker
    if (-not $sqvrUpdated -and -not $alreadySatisfied) {
        # Normalize combo for matching: "RQ.Plate" -> also try "RQ Plate", "RQ+Plate"
        $comboVariants = @($comboEsc)
        $comboVariants += [regex]::Escape(($baseCombo -replace '[.+]', ' '))
        $comboVariants += [regex]::Escape(($baseCombo -replace '[. ]', '+'))
        $comboVariants = $comboVariants | Select-Object -Unique

        for ($i = 0; $i -lt $sqvrLines.Count; $i++) {
            foreach ($cv in $comboVariants) {
                if ($sqvrLines[$i] -match "^\s+${cv}\s+--.*${markerPattern}") {
                    if ($sqvrLines[$i] -match $newMarkerEsc) { $alreadySatisfied = $true }
                    else { $sqvrLines[$i] = $sqvrLines[$i] -replace $markerPattern, $newMarker; $sqvrUpdated = $true }
                    break
                }
            }
            if ($sqvrUpdated -or $alreadySatisfied) { break }
        }
    }

    # Strategy 3: Combo might be embedded in the description line text
    #             (e.g., user passes "RMS co-fire" and the line says "  RMS co-fire [PENDING]")
    if (-not $sqvrUpdated -and -not $alreadySatisfied) {
        for ($i = 0; $i -lt $sqvrLines.Count; $i++) {
            if ($sqvrLines[$i] -match $comboEsc -and $sqvrLines[$i] -match $markerPattern) {
                if ($sqvrLines[$i] -match $newMarkerEsc) { $alreadySatisfied = $true }
                else { $sqvrLines[$i] = $sqvrLines[$i] -replace $markerPattern, $newMarker; $sqvrUpdated = $true }
                break
            }
        }
    }

    if ($sqvrUpdated) {
        # Update the "Last updated" line; clear "NOT yet imported" on first test run
        $sqvrLines = $sqvrLines | ForEach-Object {
            if ($_ -match '^Last updated:') {
                $_ -replace '(Last updated:\s*).*', "`${1}${dateStr}"
            } elseif ($_ -match '^Live test:.*NOT yet imported') {
                $_ -replace 'NOT yet imported.*', 'In progress'
            } else { $_ }
        }
        ($sqvrLines -join "`n") | Set-Content -Path $sqvrPath -Encoding UTF8 -NoNewline
        Write-Ok "SQVR: -> $newMarker"
    } elseif ($alreadySatisfied) {
        # A prior variant test for this same base combo already set the marker to this exact
        # state (e.g. base combo PASSed and flipped [PENDING]->[CONFIRMED]; this any-field/any
        # variant also PASSed) -- nothing to change, and NOT a warning-worthy condition.
        Write-Ok "SQVR: already $newMarker for '$baseCombo' (no change needed)"
    } else {
        $comboDisplay = if ($baseCombo -ne $Combo) { "'$Combo' (base '$baseCombo')" } else { "'$Combo'" }
        Write-Warn "SQVR: Could not find a marker for combo $comboDisplay"
        Write-Warn "      Manual update may be needed: $sqvrPath"
    }
} else {
    # Create a minimal SQVR stub
    Write-Warn "SQVR not found -- creating stub: $sqvrPath"
    $marker = if ($Result -eq 'PASS') { '[CONFIRMED]' } else { "[FAILED -- $dateStr]" }
    $sqvrStub = @"
$Provider -- SUPPORTED QUERY VALIDATION REPORT (SQVR)
======================================================
Last updated: $dateStr
JSON version: (see REBUILD_TRACKER.md)
Live test: In progress

================================================================================
$Query -- $Entity Entity
================================================================================

  $Combo -- $Description $marker
    keyReference: $Combo
"@
    $sqvrStub | Set-Content -Path $sqvrPath -Encoding UTF8
    $sqvrUpdated = $true
    Write-Ok "SQVR stub created with $marker"
}

# ============================================================================
# STEP 4: UPDATE STATUS.txt
# ============================================================================

Write-Step 4 $totalSteps "Updating STATUS.txt..."

$statusPath = Join-Path $docsDir "${Provider}_STATUS.txt"
$statusUpdated = $false

# The test matrix row to add/update
$matrixRow = "  {0,-5} {1,-10} {2,-10} {3,-20} {4,-8} {5}" -f
    "---", $dateStr, $Entity, "${queryShort}:${Combo}", $Result, $Description

if (Test-Path $statusPath) {
    $statusLines = @(Get-Content $statusPath -Encoding UTF8)
    $statusContent = $statusLines -join "`n"

    # Look for an existing row with this entity+combo
    $rowPattern = "(?m)^.*${Entity}.*${comboSafe}.*$"
    $existingRow = $statusLines | Where-Object { $_ -match $Entity -and $_ -match [regex]::Escape($Combo) }

    if ($existingRow) {
        # Update existing row
        $idx = [array]::IndexOf($statusLines, $existingRow[0])
        if ($idx -ge 0) {
            $statusLines[$idx] = $matrixRow
            $statusUpdated = $true
        }
    }

    if (-not $statusUpdated) {
        # Anchor to the "LIVE TEST RESULTS" section header, then insert after the last row in it.
        # A backward scan with ^\s*\d+\s was incorrectly matching build-log lines like
        # "      3 layout variants..." before reaching the LIVE TEST section.
        $insertIdx = -1
        $liveTestStart = -1
        for ($i = 0; $i -lt $statusLines.Count; $i++) {
            if ($statusLines[$i] -match 'LIVE TEST RESULTS') {
                $liveTestStart = $i
                break
            }
        }
        if ($liveTestStart -ge 0) {
            for ($i = $liveTestStart; $i -lt $statusLines.Count; $i++) {
                if ($statusLines[$i] -match '^\s+---\s') {
                    $insertIdx = $i
                }
                # Stop when we hit the next major section header (all-caps word at col 0)
                if ($i -gt $liveTestStart -and $statusLines[$i] -match '^[A-Z][A-Z ]') {
                    break
                }
            }
        }

        if ($insertIdx -ge 0) {
            # Insert after the last row
            $before = $statusLines[0..$insertIdx]
            $after  = if ($insertIdx + 1 -lt $statusLines.Count) { $statusLines[($insertIdx + 1)..($statusLines.Count - 1)] } else { @() }
            $statusLines = @($before) + @($matrixRow) + @($after)
            $statusUpdated = $true
        } else {
            # Append a new test section at the end
            $statusLines += @(
                "",
                "LIVE TEST RESULTS (v3.4)",
                "========================",
                $matrixRow
            )
            $statusUpdated = $true
        }
    }

    if ($statusUpdated) {
        # Update the "Last updated" line
        $statusLines = $statusLines | ForEach-Object {
            if ($_ -match '^Last updated') {
                "Last updated    : $dateStr"
            } else {
                $_
            }
        }
        ($statusLines -join "`n") | Set-Content -Path $statusPath -Encoding UTF8 -NoNewline
        Write-Ok "STATUS: Updated test matrix"
    }
} else {
    # Create a minimal STATUS stub
    Write-Warn "STATUS.txt not found -- creating stub: $statusPath"
    $statusStub = @"
$Provider -- Build Status
========================
Last updated    : $dateStr
Provider        : $Provider

LIVE TEST RESULTS (post_test.ps1)
--------------------------------------------------
  #     Date        Entity      Combo                Result    Notes
  ---   ----------  ----------  -------------------  --------  -----
$matrixRow
"@
    $statusStub | Set-Content -Path $statusPath -Encoding UTF8
    $statusUpdated = $true
    Write-Ok "STATUS stub created with test row"
}

# ============================================================================
# STEP 5: GIT COMMIT AND PUSH
# ============================================================================

if (-not $NoCommit) {
    Write-Step 5 $totalSteps "Committing and pushing..."

    # Stage the files
    $filesToAdd = @($logPath)
    if ($sqvrUpdated) { $filesToAdd += $sqvrPath }
    if ($statusUpdated) { $filesToAdd += $statusPath }
    if ($xmlSnippetPath) { $filesToAdd += $xmlSnippetPath }
    if ($rmsSnippetPath) { $filesToAdd += $rmsSnippetPath }

    $gitOk = $true
    foreach ($f in $filesToAdd) {
        $relPath = $f.Replace("$repoRoot\", "").Replace("\", "/")
        try {
            & git -C $repoRoot add $relPath 2>&1 | Out-Null
        } catch {
            Write-Warn "git add failed for: $relPath"
            $gitOk = $false
        }
    }

    if ($gitOk) {
        $commitMsg = @"
Test: $Provider $Entity $Query $Combo - $Result

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
"@
        try {
            $commitOutput = & git -C $repoRoot commit -m $commitMsg 2>&1 | Out-String
            $commitHash = ""
            if ($commitOutput -match '\[[\w/\-]+\s+([a-f0-9]{7,})\]') {
                $commitHash = $Matches[1]
            }

            try {
                $pushOutput = & git -C $repoRoot push 2>&1 | Out-String
                Write-Ok "Git: Committed and pushed ($commitHash)"
            } catch {
                Write-Warn "Git: Committed ($commitHash) but push failed: $_"
                Write-Warn "     Run 'git push' manually."
            }
        } catch {
            Write-Warn "Git: commit failed: $_"
            Write-Warn "     Files are staged. Run 'git commit' and 'git push' manually."
        }
    } else {
        Write-Warn "Git: Some files could not be staged. Commit skipped."
    }
} else {
    Write-Step 5 $totalSteps "Skipping git commit (-NoCommit)"
    Write-Ok "Files saved locally. Remember to commit and push when done batching."
}

# ============================================================================
# STEP 6: SUMMARY
# ============================================================================

$stepLabel = if ($NoCommit) { 5 } else { 6 }
Write-Step $stepLabel $totalSteps "Summary"

$relLogPath = $logPath.Replace("$repoRoot\", "").Replace("\", "/")
$sqvrStatus = if ($sqvrUpdated) {
    if ($Result -eq 'PASS') { "Updated [PENDING] -> [CONFIRMED]" }
    else { "Updated -> [FAILED]" }
} elseif ($alreadySatisfied) {
    "Already $newMarker (no change needed)"
} else { "No matching marker found (manual update needed)" }

$statusStatus = if ($statusUpdated) { "Updated test matrix" } else { "No update" }

$gitStatus = if ($NoCommit) {
    "Skipped (-NoCommit)"
} else {
    if ($commitHash) { "Committed and pushed ($commitHash)" }
    else { "Attempted (check warnings above)" }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " TEST SAVED: $Provider $Entity $Query $Combo" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Result:    $Result" -ForegroundColor $(if ($Result -eq 'PASS') { 'Green' } else { 'Red' })
Write-Host "  Test log:  $relLogPath" -ForegroundColor White
Write-Host "  SQVR:      $sqvrStatus" -ForegroundColor White
Write-Host "  STATUS:    $statusStatus" -ForegroundColor White
Write-Host "  Git:       $gitStatus" -ForegroundColor White
if ($isUpdate) {
    Write-Host "  Note:      Previous log for this combo preserved" -ForegroundColor DarkYellow
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
