# post_test.ps1
# Instant-save tool for test results. After ANY test completes, this script
# immediately saves all artifacts, updates docs, commits, and pushes.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File tools\post_test.ps1 `
#     -Provider TX_TLETS -Entity Vehicle -Query VehicleRegistrationQuery `
#     -Combo IA.QV -Result PASS -Description "Plate search basic"
#
#   With XML capture:
#   powershell.exe -ExecutionPolicy Bypass -File tools\post_test.ps1 `
#     -Provider FL_FCIC -Entity Person -Query DriverLicenseQuery `
#     -Combo FDQ+OLN -Result PASS -Description "DL by OLN" `
#     -XmlRequest "<xml>...</xml>" -XmlResponse "<xml>...</xml>" `
#     -FormState "OLN=D123456789, State=blank" -Notes "FDQ fires, no QW co-fire"

param(
    [Parameter(Mandatory)][string]$Provider,
    [Parameter(Mandatory)][string]$Entity,
    [Parameter(Mandatory)][string]$Query,
    [Parameter(Mandatory)][string]$Combo,
    [Parameter(Mandatory)][ValidateSet('PASS','FAIL')][string]$Result,
    [Parameter(Mandatory)][string]$Description,
    [ValidateSet('BASE','MC')][string]$Variant = 'BASE',

    [string]$XmlRequest,
    [string]$XmlResponse,
    [string]$FormState,
    [string]$Notes,
    [switch]$NoCommit,
    [switch]$Negative
)

$ErrorActionPreference = "Stop"

# ============================================================================
# HARD GATE: No XML = No PASS (unless negative test)
# ============================================================================

if ($Result -eq 'PASS' -and -not $Negative -and (-not $XmlRequest -or $XmlRequest.Trim().Length -eq 0)) {
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
Write-Host " Combo: $Combo  Result: $Result  Variant: $Variant" -ForegroundColor Cyan
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

# Build form state section
$formStateContent = if ($FormState) { $FormState } else { "Not captured" }

# Build XML sections
$xmlReqContent  = if ($XmlRequest)  { $XmlRequest }  else { "Not captured" }
$xmlRespContent = if ($XmlResponse) { $XmlResponse } else { "Not captured" }

# Auto-generate field analysis from XML if available
$fieldAnalysis = "Not captured (no XML provided)"
if ($XmlRequest) {
    $autoAnalysis = Get-XmlFieldAnalysis $XmlRequest
    if ($autoAnalysis) {
        $fieldAnalysis = "AUTO-EXTRACTED FROM XML REQUEST:`n$autoAnalysis"
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
Variant: $Variant
Date: $timestamp
Result: $Result
================================================================

FORM STATE
----------
$formStateContent

XML REQUEST
-----------
$xmlReqContent

XML RESPONSE
------------
$xmlRespContent

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

    $comboEsc = [regex]::Escape($Combo)

    # Strategy 1: Find "keyReference: <Combo>" line, then look UP for the
    #             description line that has [PENDING] and replace ONLY that one.
    $keyRefIdx = -1
    for ($i = 0; $i -lt $sqvrLines.Count; $i++) {
        if ($sqvrLines[$i] -match "^\s*keyReference:\s*${comboEsc}(\s|$)") {
            $keyRefIdx = $i
            break
        }
    }

    if ($keyRefIdx -ge 0) {
        # Walk backwards from keyReference line to find the [PENDING] description line
        for ($j = $keyRefIdx - 1; $j -ge [Math]::Max(0, $keyRefIdx - 5); $j--) {
            if ($sqvrLines[$j] -match '\[PENDING\]') {
                $sqvrLines[$j] = $sqvrLines[$j] -replace '\[PENDING\]', $newMarker
                $sqvrUpdated = $true
                break
            }
        }
    }

    # Strategy 2: Combo might be the short name on the description line itself
    #             (e.g., "RQ+Plate", "FRQ+VIN", "REG Plate").
    #             Match: line starts with whitespace + combo text + " -- " + ... + [PENDING]
    if (-not $sqvrUpdated) {
        # Normalize combo for matching: "RQ.Plate" -> also try "RQ Plate", "RQ+Plate"
        $comboVariants = @($comboEsc)
        $comboVariants += [regex]::Escape(($Combo -replace '[.+]', ' '))
        $comboVariants += [regex]::Escape(($Combo -replace '[. ]', '+'))
        $comboVariants = $comboVariants | Select-Object -Unique

        for ($i = 0; $i -lt $sqvrLines.Count; $i++) {
            foreach ($cv in $comboVariants) {
                if ($sqvrLines[$i] -match "^\s+${cv}\s+--.*\[PENDING\]") {
                    $sqvrLines[$i] = $sqvrLines[$i] -replace '\[PENDING\]', $newMarker
                    $sqvrUpdated = $true
                    break
                }
            }
            if ($sqvrUpdated) { break }
        }
    }

    # Strategy 3: Combo might be embedded in the description line text
    #             (e.g., user passes "RMS co-fire" and the line says "  RMS co-fire [PENDING]")
    if (-not $sqvrUpdated) {
        for ($i = 0; $i -lt $sqvrLines.Count; $i++) {
            if ($sqvrLines[$i] -match $comboEsc -and $sqvrLines[$i] -match '\[PENDING\]') {
                $sqvrLines[$i] = $sqvrLines[$i] -replace '\[PENDING\]', $newMarker
                $sqvrUpdated = $true
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
        Write-Ok "SQVR: [PENDING] -> $newMarker"
    } else {
        Write-Warn "SQVR: Could not find [PENDING] marker for combo '$Combo'"
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
JSON version: $Variant
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
Current version : $Variant
Provider        : $Provider

LIVE TEST RESULTS -- $Variant (post_test.ps1)
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

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
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
    else { "Updated [PENDING] -> [FAILED]" }
} else { "No matching [PENDING] found (manual update needed)" }

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
