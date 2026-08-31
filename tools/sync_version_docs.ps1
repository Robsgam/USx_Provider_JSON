<#
  sync_version_docs.ps1 -- Auto-update version-dependent docs after a build
  DESCRIBED IN: CLAUDE.md (tools table + Workflow section), README.txt (line ~317 + pipeline step 7)
  Updates 5 files to match the current build script version and validator scores:
    1. STATUS.txt       -- header version + validator scores
    2. SQVR.txt         -- header version + validator scores
    3. JSON_INVENTORY.md -- root entry + new version section
    4. REBUILD_TRACKER.md -- provider row version + scores
    5. BUILD_NOTES.txt  -- version entry date synced to today (build checksum)

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

# Shared active-JSON resolver (handles versioned <PROVIDER>_v<X.Y>.json names)
. "$toolDir\_resolve_provider_json.ps1"
# docs/ reorg pilot (2026-07-01, NJ_NJCJIS first)
. "$toolDir\_resolve_docs_path.ps1"

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
        Where-Object { $_.Name -notmatch '_old' }
    if ($scripts.Count -eq 0) { return $null }
    $text = [System.IO.File]::ReadAllText($scripts[0].FullName)
    if ($text -match '\$Version\s*=\s*["''"]([^"'']+)["''"]') {
        return $Matches[1]
    }
    return $null
}

# ── Read validator score from report ─────────────────────────────────────────
function Get-ValidatorScore($variant) {
    if ($variant) {
        $reportDir = Join-Path $provDir "docs\$variant"
    } else {
        $reportDir = Get-DocsCategoryDir $provDir 'reports'
    }
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

# Try docs/ first (new single-variant), then docs/base and docs/mc (legacy)
$score = Get-ValidatorScore $null
$baseScore = Get-ValidatorScore "base"
$mcScore   = Get-ValidatorScore "mc"

# Active root JSON may be bare <PROVIDER>.json or versioned <PROVIDER>_v<X.Y>.json;
# both count as "single" (vs legacy _MC/_BASE variants).
$activeJson = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
$hasMc = Test-Path (Join-Path $provDir "${Provider}_MC.json")
$hasBase = Test-Path (Join-Path $provDir "${Provider}_BASE.json")
$hasSingle = [bool]$activeJson -and ($activeJson -notmatch '_(MC|BASE)\.json$')

# For single-variant providers, use the docs/ score as the primary
if ($hasSingle -and $score -and -not $baseScore -and -not $mcScore) {
    $mcScore = $score
    $hasMc = $false
}

Write-Host ""
Write-Host "  sync_version_docs -- $Provider v${version}" -ForegroundColor Cyan
if ($hasSingle -and $score) {
    Write-Host "    Score: $score"
} else {
    if ($baseScore) { Write-Host "    BASE: $baseScore" }
    if ($mcScore)   { Write-Host "    MC:   $mcScore" }
    elseif (-not $hasMc) { Write-Host "    MC:   (archived/none)" }
}
Write-Host ""

if ($DryRun) { Write-Host "  ** DRY RUN -- no files will be changed **" -ForegroundColor Yellow; Write-Host "" }

# ══════════════════════════════════════════════════════════════════════════════
#  1. STATUS.txt
# ══════════════════════════════════════════════════════════════════════════════
$statusFile = Get-DocsPath $provDir 'tracking' "${Provider}_STATUS.txt"
if (Test-Path $statusFile) {
    $text = [System.IO.File]::ReadAllText($statusFile)
    $changed = $false

    # Header line: Current: vX.X | SCORE ...
    if ($hasSingle -and $score) {
        $scoreHeader = $score
    } elseif ($hasMc) {
        $scoreHeader = "BASE $baseScore | MC $mcScore"
    } else {
        $scoreHeader = "BASE $baseScore"
    }
    $newHeader = "Current: v${version} | $scoreHeader | Updated $today"
    if ($text -match '(?m)^Current:\s+v[^\r\n]+') {
        $text = $text -replace '(?m)^Current:\s+v[^\r\n]+', $newHeader
        $changed = $true
    } else {
        # Legacy STATUS.txt (predates the "Current:" header convention, e.g. FL_FCIC 2026-07-02)
        # -- the "Last updated"/"Provider" replacements below can flip $changed=true while the
        # version string never actually lands anywhere in the file, so enforce's version grep
        # fails silently after a reported "[UPDATED]". Insert the header explicitly instead.
        $text = $text -replace '(?m)^(Provider\s*:\s*[^\r\n]+)', "`$1`r`n${newHeader}"
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

    # Safety net (2026-07-17, HI_HCJDC_OFML incident): a STATUS.txt with neither a "Current:"
    # header nor a "Provider :" legacy header (a third format the two branches above don't
    # recognize) can flip $changed=true from an unrelated regex (BASE/MC score, "Last updated")
    # while the version string itself never actually lands anywhere in the file -- this used to
    # print a false "[UPDATED] -- v${version}" even though grep for v${version} would still fail.
    # Verify the version string is actually present in the new text before claiming success.
    $versionActuallyPresent = $text -match [regex]::Escape("v${version}")

    if ($changed -and -not $DryRun) {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($statusFile, $text, $enc)
        if ($versionActuallyPresent) {
            Updated "STATUS.txt -- v${version}, BASE $baseScore$(if ($mcScore) { ", MC $mcScore" })"
        } else {
            Write-Host "  [WARN] STATUS.txt -- other fields updated but 'v${version}' string never matched any known header format (verify manually, add a 'Current: v${version} | ...' line)" -ForegroundColor Yellow
        }
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
$sqvrFile = Get-DocsPath $provDir 'tracking' "${Provider}_SQVR.txt"
if (Test-Path $sqvrFile) {
    $text = [System.IO.File]::ReadAllText($sqvrFile)
    $changed = $false

    # Last updated line
    if ($text -match '(?m)^Last updated:\s*[^\r\n]+') {
        $text = $text -replace '(?m)^Last updated:\s*[^\r\n]+', "Last updated: $today"
        $changed = $true
    }

    # JSON version line
    if ($hasSingle -and $score) {
        $versionLine = "JSON version: v${version}"
    } elseif ($hasMc) {
        $versionLine = "JSON version: v${version} BASE + v${version} MC"
    } else {
        $versionLine = "JSON version: v${version} BASE"
    }
    if ($text -match '(?m)^JSON version:\s*[^\r\n]+') {
        $text = $text -replace '(?m)^JSON version:\s*[^\r\n]+', $versionLine
        $changed = $true
    }

    # Validator line
    if ($hasSingle -and $score) {
        $valLine = "Validator: $score"
    } elseif ($hasMc) {
        $valLine = "Validator: $baseScore (BASE) | $mcScore (MC)"
    } else {
        $valLine = "Validator: $baseScore (BASE)"
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
$invFile = Get-DocsPath $provDir 'tracking' "JSON_INVENTORY.md"
if (Test-Path $invFile) {
    $text = [System.IO.File]::ReadAllText($invFile)
    $changed = $false
    $vEsc = [regex]::Escape($version)

    # Active root JSON leaf name (versioned <PROVIDER>_v<X.Y>.json, or bare/legacy)
    $activeLeaf = if ($activeJson) { Split-Path $activeJson -Leaf } else { "${Provider}.json" }

    # ------------------------------------------------------------------------------------------
    #  SELF-HEALING STATUS COLUMN -- added 2026-08-31. THIS FILE COULD NOT ANSWER ITS OWN QUESTION.
    #
    #  Every new version section below was written with a hardcoded "| Current |" and NOTHING ever
    #  demoted the previous one, so the Status column carried no information at all. Measured across
    #  the portfolio before this fix: 341 rows read "Current" and 9 read "Superseded" -- HI_HCJDC_OFML
    #  alone had 44 rows claiming Current, and its top block still declared v4.6 current while the
    #  active JSON was v4.20, fourteen versions later.
    #
    #  The top block was ALSO never updated on some providers, for a separate and quieter reason: the
    #  match below was anchored to '## Root' only, and 2 of 20 files head their top block '## Current'
    #  while 3 have NO top block at all. A non-matching heading meant the update silently did nothing
    #  -- no warning, no skip line. Now: both spellings are accepted, and a missing top block is
    #  CREATED rather than ignored.
    #
    #  Why enforce did not catch any of it: PHASE 3 asks only whether the file "has v<X.Y>" anywhere,
    #  a substring test that a 44-section history passes trivially. Same vacuous-check family as the
    #  empty-SQVR pass.
    #
    #  Order matters and is deliberate: DEMOTE everything first, then re-promote the active version.
    #  That makes the pass idempotent -- re-running at an unchanged version must leave exactly the
    #  active rows reading Current, not demote them and stop.
    # ------------------------------------------------------------------------------------------
    $dryTag = if ($DryRun) { '(dry) ' } else { '' }
    $preCurrent = ([regex]::Matches($text, '\|\s*Current\s*\|')).Count
    $text = [regex]::Replace($text, '\|\s*Current\s*\|', '| Superseded |')

    # Re-promote every row that names the ACTIVE version. Matches both the top-block row and the
    # '## v<active>' history rows, in either the single-JSON or legacy BASE/MC shape.
    $text = [regex]::Replace($text, "(\|\s*[A-Za-z0-9_.]+\.json\s*\|\s*v${vEsc}\s*\|)\s*Superseded\s*\|", '$1 Current |')
    $postCurrent = ([regex]::Matches($text, '\|\s*Current\s*\|')).Count
    if ($preCurrent -ne $postCurrent) {
        Updated "${dryTag}JSON_INVENTORY.md -- Status column normalised (Current rows ${preCurrent} -> ${postCurrent}; older versions now Superseded)"
        $changed = $true
    }

    # Create a top block if the file has none (3 of 20 had only version sections, so no pointer to
    # the active JSON existed at all -- the one thing a reader opens this file for).
    if ($text -notmatch '(?m)^##\s+(Root|Current)') {
        $topScore = if ($hasSingle -and $score) { "$score." } elseif ($baseScore) { "$baseScore." } else { '' }
        $topBlock = @"
## Current

| File | Version | Status | Notes |
|------|---------|--------|-------|
| ${activeLeaf} | v${version} | Current | $topScore |

"@
        if ($text -match '(?m)^## v\d+\.\d+') {
            $p0 = $text.IndexOf($Matches[0])
            $text = $text.Substring(0, $p0) + $topBlock + $text.Substring($p0)
        } else {
            $text += "`n" + $topBlock
        }
        Updated "${dryTag}JSON_INVENTORY.md -- created a '## Current' top block (file had no pointer to the active JSON)"
        $changed = $true
    }

    # Update the top section (between "## Root"/"## Current" and the next "##")
    #
    #  ⚠️ THE REGEX BELOW USED TO END '((?=\r?\n## )|$)' UNDER (?ms) AND THAT MADE THIS ENTIRE BLOCK A
    #  NO-OP ON EVERY PROVIDER, SILENTLY, FOR ITS WHOLE LIFE. Under the `m` flag `$` matches at the end
    #  of every LINE, so the alternation succeeded immediately after the heading line and the lazy
    #  `(.*?)` captured the EMPTY STRING. The block then "replaced" rows inside nothing, reported
    #  `$changed = $true`, and wrote the file back unchanged in that region.
    #  Proven 2026-08-31 by matching it against HI_HCJDC_OFML: group 2 came back empty while the same
    #  row pattern matched 44 times in the whole file. The visible symptom was AZ_AZDPS's top block
    #  still listing `AZ_AZDPS_BASE.json | v2.0` and `AZ_AZDPS_MC.json | v2.0` from the retired
    #  BASE/MC era, and HI's declaring v4.6 current at v4.20. Anchor is now `\z` (end of STRING).
    #
    #  The body is now REBUILT rather than regex-patched. Patching assumed the block already held a row
    #  naming this provider's active file, which is false the moment a provider is galvanized (the row
    #  still names _BASE/_MC) or renamed. A pointer block has exactly one job -- name the active JSON --
    #  so it is generated, not edited. Legacy BASE/MC history stays intact in the version sections.
    if ($text -match '(?s)(##\s+(?:Root|Current)[^\r\n]*\r?\n)(.*?)((?=\r?\n## )|\z)') {
        $whole      = $Matches[0]
        $rootHeader = $Matches[1]
        $topScore   = if ($hasSingle -and $score) { "$score." } elseif ($baseScore) { "$baseScore." } else { '' }

        $rootBody = @"

| File | Version | Status | Notes |
|------|---------|--------|-------|
| ${activeLeaf} | v${version} | Current | $topScore |
"@
        $idx  = $text.IndexOf($whole)
        $text = $text.Substring(0, $idx) + $rootHeader + $rootBody + $text.Substring($idx + $whole.Length)
        $changed = $true
    }

    # Add version section if not present
    if ($text -notmatch "## v$vEsc") {
        if ($hasSingle -and $score) {
            $fileRow = "| ${activeLeaf} | v${version} | Current | $score. |"
        } else {
            $fileRow = "| ${Provider}_BASE.json | v${version} | Current | $baseScore. |"
            if ($hasMc -and $mcScore) {
                $fileRow += "`n| ${Provider}_MC.json | v${version} | Current | $mcScore. |"
            }
        }

        $newSection = @"

## v${version} ($today)

| File | Version | Status | Notes |
|------|---------|--------|-------|
$fileRow

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

# ══════════════════════════════════════════════════════════════════════════════
#  5. BUILD_NOTES.txt -- date checksum (must match JSON file date)
# ══════════════════════════════════════════════════════════════════════════════
$notesFile = Get-DocsPath $provDir 'tracking' "${Provider}_BUILD_NOTES.txt"
$jsonFile = Join-Path $provDir "${Provider}.json"
if (-not (Test-Path $jsonFile)) {
    $jsonFile = Get-ChildItem $provDir -Filter "*.json" -File | Select-Object -First 1 -ExpandProperty FullName
}
$jsonDate = if ($jsonFile -and (Test-Path $jsonFile)) { (Get-Item $jsonFile).LastWriteTime.ToString('yyyy-MM-dd') } else { $today }

if (Test-Path $notesFile) {
    $text = [System.IO.File]::ReadAllText($notesFile)
    $vEsc = [regex]::Escape($version)
    $changed = $false

    if ($text -match "(?m)^(v${vEsc}\s+)(\d{4}-\d{2}-\d{2})(\s+.*)") {
        if ($Matches[2] -ne $jsonDate) {
            $text = $text -replace "(?m)^(v${vEsc}\s+)\d{4}-\d{2}-\d{2}(\s+.*)", "`${1}${jsonDate}`$2"
            $changed = $true
        }
    } elseif ($text -match "(?m)^(v${vEsc}\s+\()(\d{4}-\d{2}-\d{2})(\)\s+--.*)") {
        if ($Matches[2] -ne $jsonDate) {
            $text = $text -replace "(?m)^(v${vEsc}\s+\()\d{4}-\d{2}-\d{2}(\)\s+--.*)", "`${1}${jsonDate}`$2"
            $changed = $true
        }
    } elseif ($text -notmatch "(?m)^v${vEsc}\b") {
        $headerEnd = 0
        $lines = $text -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*$' -and $i -gt 2) { $headerEnd = $i; break }
            if ($lines[$i] -match '^v\d+\.\d+') { $headerEnd = $i; break }
            if ($lines[$i] -match '^-{10,}') { $headerEnd = $i + 1; break }
        }
        $stub = "v${version}  ${jsonDate}  Pipeline rebuild`n  CHANGED: Rebuilt via pipeline.ps1`n  REASON: Scheduled rebuild`n`n"
        $text = ($lines[0..($headerEnd-1)] -join "`n") + "`n" + $stub + ($lines[$headerEnd..($lines.Count-1)] -join "`n")
        $changed = $true
    }

    if ($changed -and -not $DryRun) {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($notesFile, $text, $enc)
        Updated "BUILD_NOTES.txt -- v${version} date → $jsonDate (matches JSON)"
    } elseif ($changed) {
        Updated "(dry) BUILD_NOTES.txt -- v${version} date → $jsonDate"
    } else {
        Skipped "BUILD_NOTES.txt -- v${version} date already matches JSON ($jsonDate)"
    }
} else {
    Skipped "BUILD_NOTES.txt -- not found"
}

# ══════════════════════════════════════════════════════════════════════════════
#  6. CHANGELOG -- per-provider (generated) + repo-root (refresh Current line)
# ══════════════════════════════════════════════════════════════════════════════

# 6a. Per-provider changelog: regenerate from the just-synced BUILD_NOTES.
$genTool = Join-Path $toolDir "generate_changelog.ps1"
$clProvFile = Get-DocsPath $provDir 'tracking' "CHANGELOG_${Provider}.md"
if ((Test-Path $genTool) -and -not $DryRun) {
    & powershell -ExecutionPolicy Bypass -File $genTool -Provider $Provider | Out-Null
    if (Test-Path $clProvFile) {
        Updated "CHANGELOG_${Provider}.md -- regenerated from BUILD_NOTES"
    } else {
        Skipped "CHANGELOG_${Provider}.md -- generator produced no file"
    }
} elseif ($DryRun) {
    Updated "(dry) CHANGELOG_${Provider}.md"
}

# 6b. Repo-root CHANGELOG.md: refresh ONLY the provider's "Current:" line tokens
#     (version, score, import filename). Curated milestone bullets are untouched.
#     Skips providers that have no section (the file is curated; sections aren't auto-created).
$changelog   = Join-Path $repoRoot "CHANGELOG.md"
$activeLeafCl = if ($activeJson) { Split-Path $activeJson -Leaf } else { "${Provider}.json" }
$scoreTok    = if ($score) { $score } elseif ($mcScore) { $mcScore } elseif ($baseScore) { $baseScore } else { $null }
if (Test-Path $changelog) {
    $cl = [System.IO.File]::ReadAllText($changelog)
    $provEscCl = [regex]::Escape($Provider)
    if ($cl -match "(?ms)(^##\s+${provEscCl}\b.*?)(?=^##\s|\z)") {
        $sec  = $Matches[1]
        $orig = $sec
        $sec = $sec -replace '(\*\*v)[\d.]+(\*\*)', "`${1}${version}`$2"
        if ($scoreTok) {
            $sec = $sec -replace '(?m)(^Current:.*?)\d+P/\d+F/\d+W(?:/\d+LIM)?', "`${1}$scoreTok"
        }
        $sec = $sec -replace '(import:\s*`)[^`]+(`)', "`${1}${activeLeafCl}`$2"
        if ($sec -ne $orig -and -not $DryRun) {
            $cl = $cl.Substring(0, $cl.IndexOf($orig)) + $sec + $cl.Substring($cl.IndexOf($orig) + $orig.Length)
            $enc = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($changelog, $cl, $enc)
            Updated "CHANGELOG.md -- $Provider Current -> v${version} ($activeLeafCl)"
        } elseif ($sec -ne $orig) {
            Updated "(dry) CHANGELOG.md -- $Provider Current -> v${version}"
        } else {
            Skipped "CHANGELOG.md -- $Provider Current already v${version}"
        }
    } else {
        Write-Host "  [INFO] CHANGELOG.md -- no '## $Provider' section (skipped)" -ForegroundColor Gray
    }
} else {
    Skipped "CHANGELOG.md -- not found"
}

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  sync_version_docs: $($script:updated) updated / $($script:skipped) skipped" -ForegroundColor $(if ($script:updated -gt 0) { "Green" } else { "Gray" })
