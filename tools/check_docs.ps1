<#
  check_docs.ps1 -- Documentation consistency gate
  Verifies version numbers and status match across all provider docs:
    1. STATUS.txt version header
    2. SQVR.txt version header
    3. BUILD_NOTES.txt latest version entry
    4. CLAUDE.md provider row
    5. Build script $Version default
  Run after every build to catch version drift before committing.

  Usage: .\check_docs.ps1 -Provider <PROVIDER_NAME>
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$providerDir = "$repoRoot\providers\$Provider"
$docsDir = "$providerDir\docs"

$failCount = 0
$warnCount = 0
$passCount = 0

function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warnCount++ }
function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:passCount++ }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " DOC CONSISTENCY CHECK: $Provider" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$versions = @{}

# --- Check 1: STATUS.txt ---
Write-Host "`n=== STATUS.txt ===" -ForegroundColor White
$statusPath = "$docsDir\${Provider}_STATUS.txt"
if (Test-Path $statusPath) {
    $statusLines = Get-Content $statusPath
    $baseVer = $null; $mcVer = $null
    foreach ($line in $statusLines) {
        if ($line -match 'BASE\s+v([\d.]+)') { $baseVer = $Matches[1] }
        if ($line -match 'MC\s+v([\d.]+)') { $mcVer = $Matches[1] }
        if ($line -match 'Current version:\s*v([\d.]+)') {
            if (-not $baseVer) { $baseVer = $Matches[1] }
            if (-not $mcVer) { $mcVer = $Matches[1] }
        }
    }
    if ($baseVer) {
        Pass "STATUS.txt BASE version: v$baseVer"
        $versions['STATUS_BASE'] = $baseVer
    } else { Warn "Cannot parse BASE version from STATUS.txt" }
    if ($mcVer) {
        Pass "STATUS.txt MC version: v$mcVer"
        $versions['STATUS_MC'] = $mcVer
    } else { Warn "Cannot parse MC version from STATUS.txt" }
} else { Fail "STATUS.txt not found: $statusPath" }

# --- Check 2: SQVR.txt ---
Write-Host "`n=== SQVR.txt ===" -ForegroundColor White
$sqvrPath = "$docsDir\${Provider}_SQVR.txt"
if (Test-Path $sqvrPath) {
    $sqvrLines = Get-Content $sqvrPath
    foreach ($line in $sqvrLines) {
        if ($line -match 'version:\s*v([\d.]+)\s*BASE') {
            $versions['SQVR_BASE'] = $Matches[1]
            Pass "SQVR.txt BASE version: v$($Matches[1])"
        }
        if ($line -match 'v([\d.]+)\s*MC') {
            $versions['SQVR_MC'] = $Matches[1]
            Pass "SQVR.txt MC version: v$($Matches[1])"
        }
        if ($line -match '^Version:\s*v([\d.]+)') {
            if (-not $versions.ContainsKey('SQVR_BASE')) {
                $versions['SQVR_BASE'] = $Matches[1]
                Pass "SQVR.txt version: v$($Matches[1])"
            }
            if (-not $versions.ContainsKey('SQVR_MC')) {
                $versions['SQVR_MC'] = $Matches[1]
            }
        }
    }
    if (-not $versions.ContainsKey('SQVR_BASE')) { Warn "Cannot parse BASE version from SQVR.txt" }
    if (-not $versions.ContainsKey('SQVR_MC')) { Warn "Cannot parse MC version from SQVR.txt" }
} else { Fail "SQVR.txt not found: $sqvrPath" }

# --- Check 3: BUILD_NOTES.txt ---
Write-Host "`n=== BUILD_NOTES.txt ===" -ForegroundColor White
$notesPath = "$docsDir\${Provider}_BUILD_NOTES.txt"
if (Test-Path $notesPath) {
    $notesLines = Get-Content $notesPath
    foreach ($line in $notesLines) {
        if ($line -match '^v([\d.]+)\s+[\d(]') {
            $versions['BUILD_NOTES'] = $Matches[1]
            Pass "BUILD_NOTES.txt latest version: v$($Matches[1])"
            break
        }
    }
    if (-not $versions.ContainsKey('BUILD_NOTES')) { Warn "Cannot parse latest version from BUILD_NOTES.txt" }
} else { Fail "BUILD_NOTES.txt not found: $notesPath" }

# --- Check 4: CLAUDE.md ---
Write-Host "`n=== CLAUDE.md ===" -ForegroundColor White
$claudePath = "$repoRoot\CLAUDE.md"
if (Test-Path $claudePath) {
    $claudeLines = Get-Content $claudePath
    foreach ($line in $claudeLines) {
        if ($line -match "\|\s*$Provider\s*\|.*\|\s*v([\d.]+)\s*\|") {
            $versions['CLAUDE_MD'] = $Matches[1]
            Pass "CLAUDE.md version: v$($Matches[1])"
            break
        }
    }
    if (-not $versions.ContainsKey('CLAUDE_MD')) { Warn "Cannot find $Provider version in CLAUDE.md" }
} else { Warn "CLAUDE.md not found: $claudePath" }

# --- Check 5: Build scripts ---
Write-Host "`n=== Build Scripts ===" -ForegroundColor White
$scriptsDir = "$providerDir\scripts"
if (Test-Path $scriptsDir) {
    $scripts = Get-ChildItem $scriptsDir -Filter "build_*.ps1"
    foreach ($script in $scripts) {
        $content = Get-Content $script.FullName -Raw
        if ($content -match '\$Version\s*=\s*[''"](\d[\d.]+)[''"]') {
            $scriptVer = $Matches[1]
            $key = "SCRIPT_$($script.Name)"
            $versions[$key] = $scriptVer
            Pass "$($script.Name) version: v$scriptVer"
        }
    }
} else { Warn "Scripts directory not found: $scriptsDir" }

# --- Cross-check all versions ---
Write-Host "`n=== Version Cross-Check ===" -ForegroundColor White
$allVersions = @($versions.Values | Sort-Object -Unique)
if ($allVersions.Count -eq 1) {
    Pass "All documents agree on version: v$($allVersions[0])"
} elseif ($allVersions.Count -eq 0) {
    Warn "No versions found to cross-check"
} else {
    Fail "VERSION MISMATCH detected across documents:"
    foreach ($key in ($versions.Keys | Sort-Object)) {
        $color = "White"
        Write-Host "    $key = v$($versions[$key])" -ForegroundColor $color
    }
}

# --- Check 6: Report files exist ---
Write-Host "`n=== Report Files ===" -ForegroundColor White
$requiredReports = @(
    "VALIDATOR_REPORT", "LAYOUT_REPORT", "QUERY_REPORT",
    "PICKLIST_REPORT", "VERIFY_REPORT"
)
foreach ($variant in @("base", "mc")) {
    $varDir = "$docsDir\$variant"
    if (Test-Path $varDir) {
        $varUpper = $variant.ToUpper()
        $suffix = if ($variant -eq "base") { "_BASE" } else { "_MC" }
        foreach ($rpt in $requiredReports) {
            $rptFile = "${rpt}_${Provider}${suffix}.txt"
            $rptPath = "$varDir\$rptFile"
            if (Test-Path $rptPath) {
                $lastWrite = (Get-Item $rptPath).LastWriteTime
                $today = Get-Date -Format 'yyyy-MM-dd'
                $fileDate = $lastWrite.ToString('yyyy-MM-dd')
                if ($fileDate -eq $today) {
                    Pass "$variant/$rptFile (today)"
                } else {
                    Warn "$variant/$rptFile last updated $fileDate (not today)"
                }
            } else {
                Fail "Missing report: $variant/$rptFile"
            }
        }
        $htmlFile = "LAYOUT_${Provider}${suffix}.html"
        if (Test-Path "$varDir\$htmlFile") {
            Pass "$variant/$htmlFile exists"
        } else {
            Warn "Missing HTML report: $variant/$htmlFile"
        }
    }
}

# --- Summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " DOC CHECK: $passCount PASS / $failCount FAIL / $warnCount WARN" -ForegroundColor $(if ($failCount -gt 0) { "Red" } elseif ($warnCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    Write-Host "`n  FIX ALL FAILURES before committing." -ForegroundColor Red
    exit 1
}
