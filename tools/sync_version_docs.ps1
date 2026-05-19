<#
  sync_version_docs.ps1 -- Auto-update version-dependent docs after a build
  Updates 4 files to match the current build script version and validator scores:
    1. STATUS.txt       -- header version + validator scores
    2. SQVR.txt         -- header version + validator scores
    3. JSON_INVENTORY.md -- root entry + new version section
    4. REBUILD_TRACKER.md -- provider row version + scores

  Reads version from build script, scores from validator reports.
  Run AFTER build_report.ps1 generates reports, BEFORE enforce.ps1.

  Usage:
    .\sync_version_docs.ps1 -Provider FL_FCIC
    .\sync_version_docs.ps1 -Provider FL_FCIC -DryRun
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$today    = Get-Date -Format "yyyy-MM-dd"

if (-not (Test-Path $provDir)) {
    Write-Host "  [ERROR] Provider not found: $provDir" -ForegroundColor Red
    exit 1
}

# ── Counters ─────────────────────────────────────────────────────────────────
$script:updated = 0
$script:skipped = 0

function Updated($msg) {
    Write-Host "  [UPDATED] $msg" -ForegroundColor Green
    $script:updated++
}

function Skipped($msg) {
    Write-Host "  [SKIP] $msg" -ForegroundColor Gray
    $script:skipped++
}

# ── Read version from build script ───────────────────────────────────────────
function Get-ScriptVersion($provPath) {
    $scripts = Get-ChildItem (Join-Path $provPath "scripts") -Filter "build_*" -File |
        Where-Object { $_.Name -notmatch '_mc' }
    if ($scripts.Count -eq 0) { return $null }
    $text = [System.IO.File]::ReadAllText($scripts[0].FullName)
    if ($text -match '\$Version\s*=\s*["''"]([^"'']+)["''"]') {
        return $Matches[1]
    }
    return $null
}

# ── Read validator score from report ─────────────────────────────────────────
function Get-ValidatorScore($variant) {
    $reportDir = Join-Path $provDir "docs\$variant"
    if (-not (Test-Path $reportDir)) { return $null }
    $report = Get-ChildItem $reportDir -Filter "VALIDATOR_REPORT_*" -File | Select-Object -First 1
    if (-not $report) { return $null }
    $content = [System.IO.File]::ReadAllText($report.FullName)
    if ($content -match 'RESULTS:\s+(\d+)\s+PASS\s*/\s*(\d+)\s+FAIL\s*/\s*(\d+)\s+WARN\s*/\s*(\d+)\s+LIMITATION') {
        return "$($Matches[1])P/$($Matches[2])F/$($Matches[3])W/$($Matches[4])LIM"
    }
    if ($content -match 'RESULTS:\s+(\d+)\s+PASS\s*/\s*(\d+)\s+FAIL\s*/\s*(\d+)\s+WARN') {
        return "$($Matches[1])P/$($Matches[2])F/$($Matches[3])W/0LIM"
    }
    return $null
}

function Get-PassCount($score) {
    if ($score -match '^(\d+)P') { return $Matches[1] }
    return $null
}

# ── Read data ────────────────────────────────────────────────────────────────
$version = Get-ScriptVersion $provDir
if (-not $version) {
    Write-Host "  [ERROR] Could not read version from build script" -ForegroundColor Red
    exit 1
}

$baseScore = Get-ValidatorScore "base"
$mcScore   = Get-ValidatorScore "mc"

$hasMc = Test-Path (Join-Path $provDir "${Provider}_MC.json")
$mcArchived = $false
if (-not $hasMc -and -not $mcScore) { $mcArchived = $true }

Write-Host ""
Write-Host "  sync_version_docs -- $Provider v${version}" -ForegroundColor Cyan
Write-Host "    BASE: $baseScore"
if ($hasMc) { Write-Host "    MC:   $mcScore" }
else        { Write-Host "    MC:   (archived/none)" }
Write-Host ""

if ($DryRun) { Write-Host "  ** DRY RUN -- no files will be changed **" -ForegroundColor Yellow; Write-Host "" }

# ══════════════════════════════════════════════════════════════════════════════
#  1. STATUS.txt
# ══════════════════════════════════════════════════════════════════════════════
$statusFile = Join-Path $provDir "docs\${Provider}_STATUS.txt"
if (Test-Path $statusFile) {
    $text = [System.IO.File]::ReadAllText($statusFile)
    $changed = $false

    # Header line: Current: vX.X | BASE ...
    $scoreHeader = if ($hasMc) { "BASE $baseScore | MC $mcScore" } else { "BASE $baseScore" }
    $newHeader = "Current: v${version} | $scoreHeader | Updated $today"
    if ($text -match '(?m)^Current:\s+v[^\r\n]+') {
        $text = $text -replace '(?m)^Current:\s+v[^\r\n]+', $newHeader
        $changed = $true
    }

    # Current version line
    if ($text -match '(?m)^Current version\s*:\s*v[^\r\n]+') {
        $text = $text -replace '(?m)^Current version\s*:\s*v[^\r\n]+', "Current version : v${version}"
        $changed = $true
    }

    # Last updated line
    if ($text -match '(?m)^Last updated\s*:\s*[^\r\n]+') {
        $text = $text -replace '(?m)^Last updated\s*:\s*[^\r\n]+', "Last updated    : $today"
        $changed = $true
    }

    # Validator BASE score
    if ($baseScore -and $text -match '(?m)^\s+BASE:\s+\d+\s+PASS') {
        $bp = Get-PassCount $baseScore
        $text = $text -replace '(?m)^(\s+BASE:\s+)\d+(\s+PASS\s*/\s*)\d+(\s+FAIL\s*/\s*)\d+(\s+WARN)', "`${1}${bp}`${2}0`${3}0`$4"
        $changed = $true
    }

    # Validator MC score
    if ($mcScore -and $text -match '(?m)^\s+MC:\s+\d+\s+PASS') {
        $mp = Get-PassCount $mcScore
        $text = $text -replace '(?m)^(\s+MC:\s+)\d+(\s+PASS\s*/\s*)\d+(\s+FAIL\s*/\s*)\d+(\s+WARN)', "`${1}${mp}`${2}0`${3}0`$4"
        $changed = $true
    }

    if ($changed -and -not $DryRun) {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($statusFile, $text, $enc)
        Updated "STATUS.txt -- v${version}, BASE $baseScore$(if ($mcScore) { ", MC $mcScore" })"
    } elseif ($changed) {
        Updated "(dry) STATUS.txt -- v${version}"
    } else {
        Skipped "STATUS.txt -- already current"
    }
} else {
    Skipped "STATUS.txt -- not found"
}

# ══════════════════════════════════════════════════════════════════════════════
#  2. SQVR.txt
# ══════════════════════════════════════════════════════════════════════════════
$sqvrFile = Join-Path $provDir "docs\${Provider}_SQVR.txt"
if (Test-Path $sqvrFile) {
    $text = [System.IO.File]::ReadAllText($sqvrFile)
    $changed = $false

    # Last updated line
    if ($text -match '(?m)^Last updated:\s*[^\r\n]+') {
        $text = $text -replace '(?m)^Last updated:\s*[^\r\n]+', "Last updated: $today"
        $changed = $true
    }

    # JSON version line
    $versionLine = if ($hasMc) { "JSON version: v${version} BASE + v${version} MC" }
                   else        { "JSON version: v${version} BASE" }
    if ($text -match '(?m)^JSON version:\s*[^\r\n]+') {
        $text = $text -replace '(?m)^JSON version:\s*[^\r\n]+', $versionLine
        $changed = $true
    }

    # Validator line
    $valLine = if ($hasMc) {
        "Validator: $baseScore (BASE) | $mcScore (MC)"
    } else {
        "Validator: $baseScore (BASE)"
    }
    if ($text -match '(?m)^Validator:\s+\d+P[^\r\n]+') {
        $text = $text -replace '(?m)^Validator:\s+\d+P[^\r\n]+', $valLine
        $changed = $true
    }

    if ($changed -and -not $DryRun) {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($sqvrFile, $text, $enc)
        Updated "SQVR.txt -- v${version}"
    } elseif ($changed) {
        Updated "(dry) SQVR.txt -- v${version}"
    } else {
        Skipped "SQVR.txt -- already current"
    }
} else {
    Skipped "SQVR.txt -- not found"
}

# ══════════════════════════════════════════════════════════════════════════════
#  3. JSON_INVENTORY.md
# ══════════════════════════════════════════════════════════════════════════════
$invFile = Join-Path $provDir "docs\JSON_INVENTORY.md"
if (Test-Path $invFile) {
    $text = [System.IO.File]::ReadAllText($invFile)
    $changed = $false
    $vEsc = [regex]::Escape($version)

    # Update ONLY the Root section (between "## Root" and the next "##")
    if ($text -match '(?ms)(## Root[^\r\n]*\r?\n)(.*?)((?=\r?\n## )|$)') {
        $rootHeader = $Matches[1]
        $rootBody   = $Matches[2]
        $provEscInv = [regex]::Escape($Provider)

        if ($baseScore) {
            $rootBody = $rootBody -replace "(\|\s*${provEscInv}_BASE\.json\s*\|)\s*v[^\|]+\|\s*\w+\s*\|[^\|]*\|",
                "`$1 v${version} | Current | $baseScore. |"
        }
        if ($mcScore -and $hasMc) {
            $rootBody = $rootBody -replace "(\|\s*${provEscInv}_MC\.json\s*\|)\s*v[^\|]+\|\s*\w+\s*\|[^\|]*\|",
                "`$1 v${version} | Current | $mcScore. |"
        }

        $text = $text.Substring(0, $text.IndexOf($Matches[0])) + $rootHeader + $rootBody + $text.Substring($text.IndexOf($Matches[0]) + $Matches[0].Length)
        $changed = $true
    }

    # Add version section if not present
    if ($text -notmatch "## v$vEsc") {
        $mcRow = if ($hasMc -and $mcScore) {
            "`n| ${Provider}_MC.json | v${version} | Current | $mcScore. |"
        } else { "" }

        $newSection = @"

## v${version} ($today)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| ${Provider}_BASE.json | v${version} | Current | $baseScore. |$mcRow

"@
        # Insert before the first existing version section (## vN.N)
        if ($text -match '(?m)^## v\d+\.\d+') {
            $pos = $text.IndexOf($Matches[0])
            $text = $text.Substring(0, $pos) + $newSection + $text.Substring($pos)
        } else {
            $text += $newSection
        }
        $changed = $true
    }

    if ($changed -and -not $DryRun) {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($invFile, $text, $enc)
        Updated "JSON_INVENTORY.md -- v${version} section"
    } elseif ($changed) {
        Updated "(dry) JSON_INVENTORY.md -- v${version}"
    } else {
        Skipped "JSON_INVENTORY.md -- already has v${version}"
    }
} else {
    Skipped "JSON_INVENTORY.md -- not found"
}

# ══════════════════════════════════════════════════════════════════════════════
#  4. REBUILD_TRACKER.md
# ══════════════════════════════════════════════════════════════════════════════
$tracker = Join-Path $repoRoot "REBUILD_TRACKER.md"
if (Test-Path $tracker) {
    $text = [System.IO.File]::ReadAllText($tracker)
    $provEsc = [regex]::Escape($Provider)
    $changed = $false

    # Match the provider row in any table and update version + scores
    # Pattern: | N | PROVIDER | vX.X | SCORE | SCORE | N | notes |
    if ($text -match "(?m)^\|[^|]*\|\s*${provEsc}\s*\|") {
        $mcCol = if ($mcScore) { $mcScore } elseif ($mcArchived) { "-- (archived)" } else { "--" }
        $text = $text -replace "(?m)^(\|[^|]*\|\s*${provEsc}\s*\|)\s*v[^|]+\|[^|]+\|[^|]+\|([^|]+\|[^|]*\|)",
            "`$1 v${version} | $baseScore | $mcCol |`$2"
        $changed = $true
    }

    # Also update "Already Built and Verified" section if present
    if ($text -match "(?m)^\|\s*${provEsc}\s*\|\s*v\d") {
        $text = $text -replace "(?m)^(\|\s*${provEsc}\s*\|)\s*v[^|]+\|[^|]+\|",
            "`$1 v${version} | $baseScore |"
        $changed = $true
    }

    if ($changed -and -not $DryRun) {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tracker, $text, $enc)
        Updated "REBUILD_TRACKER.md -- $Provider v${version}"
    } elseif ($changed) {
        Updated "(dry) REBUILD_TRACKER.md -- $Provider v${version}"
    } else {
        Skipped "REBUILD_TRACKER.md -- already current or no row found"
    }
} else {
    Skipped "REBUILD_TRACKER.md -- not found"
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  sync_version_docs: $($script:updated) updated / $($script:skipped) skipped" -ForegroundColor $(if ($script:updated -gt 0) { "Green" } else { "Gray" })
