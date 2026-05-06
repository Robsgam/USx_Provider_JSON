<#
  preflight_check.ps1 -- Pre-build validation against PROVIDER_CONFIG.txt
  Catches configuration drift before the build runs:
    1. PROVIDER_CONFIG.txt exists
    2. BirthDate format in build script matches PROVIDER_CONFIG
    3. Supported query list cross-reference
  Run from build scripts or standalone before any rebuild.

  Usage: .\preflight_check.ps1 -Provider <PROVIDER_NAME>
         .\preflight_check.ps1 -Provider CA_CLETS -BuildScript .\scripts\build_ca_clets.ps1
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Provider,
    [string]$BuildScript
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$providerDir = "$repoRoot\providers\$Provider"
$configPath = "$providerDir\source\PROVIDER_CONFIG.txt"

$failCount = 0
$warnCount = 0
$passCount = 0

function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:failCount++ }
function Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warnCount++ }
function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:passCount++ }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PRE-FLIGHT CHECK: $Provider" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# --- Check 1: PROVIDER_CONFIG.txt exists ---
Write-Host "`n=== Check 1: PROVIDER_CONFIG.txt ===" -ForegroundColor White

if (-not (Test-Path $configPath)) {
    Fail "PROVIDER_CONFIG.txt not found at $configPath"
    Write-Host "`n  PREFLIGHT: $passCount PASS / $failCount FAIL / $warnCount WARN"
    Write-Host "  Cannot continue without PROVIDER_CONFIG.txt" -ForegroundColor Red
    exit 1
}
Pass "PROVIDER_CONFIG.txt exists"

$configLines = Get-Content $configPath

# --- Parse config ---
$dateFormat = $null
$supportedQueries = @()
$inSupported = $false

foreach ($line in $configLines) {
    if ($line -match 'BirthDate target format:\s*(\S+)') {
        $dateFormat = $Matches[1]
    }
    if ($line -match '^SUPPORTED QUERIES') { $inSupported = $true; continue }
    if ($inSupported -and $line -match '^\d+\.\s+(\S+)') {
        $supportedQueries += $Matches[1]
    }
    if ($inSupported -and $line -match '^$' -and $supportedQueries.Count -gt 0) {
        $inSupported = $false
    }
    if ($line -match '^NOT SUPPORTED|^EXPANDED|^CA-SPECIFIC|^NJ-SPECIFIC|^[A-Z]+-SPECIFIC') {
        $inSupported = $false
    }
}

# --- Check 2: Date format ---
Write-Host "`n=== Check 2: Date Format ===" -ForegroundColor White

if ($dateFormat) {
    Pass "PROVIDER_CONFIG date format: $dateFormat"
} else {
    Warn "No BirthDate format found in PROVIDER_CONFIG.txt"
}

# --- Check 3: Build script date format match ---
Write-Host "`n=== Check 3: Build Script Date Format ===" -ForegroundColor White

if ($BuildScript -and $dateFormat) {
    if (Test-Path $BuildScript) {
        $scriptContent = Get-Content $BuildScript -Raw
        $dateMatches = [regex]::Matches($scriptContent, "CommsysParseDateRuleHandler.*?arguments\s*=\s*@\('yyyy-MM-dd'\s*,\s*'(\w+)'\)")
        if ($dateMatches.Count -eq 0) {
            $dateMatches = [regex]::Matches($scriptContent, "'yyyy-MM-dd'\s*,\s*'(\w+)'")
        }

        if ($dateMatches.Count -gt 0) {
            $allMatch = $true
            foreach ($m in $dateMatches) {
                $scriptFmt = $m.Groups[1].Value
                if ($scriptFmt -ne $dateFormat) {
                    Fail "Build script uses '$scriptFmt' but PROVIDER_CONFIG says '$dateFormat'"
                    $allMatch = $false
                }
            }
            if ($allMatch) {
                Pass "Build script date format matches PROVIDER_CONFIG ($dateFormat) [$($dateMatches.Count) occurrence(s)]"
            }
        } else {
            Warn "No CommsysParseDateRuleHandler found in build script (may not use date fields)"
        }
    } else {
        Warn "Build script not found: $BuildScript"
    }
} elseif (-not $BuildScript) {
    Write-Host "  [SKIP] No -BuildScript specified" -ForegroundColor Gray
} else {
    Write-Host "  [SKIP] No date format in PROVIDER_CONFIG" -ForegroundColor Gray
}

# --- Check 4: Supported queries ---
Write-Host "`n=== Check 4: Supported Queries ===" -ForegroundColor White

if ($supportedQueries.Count -gt 0) {
    Pass "$($supportedQueries.Count) supported queries in PROVIDER_CONFIG:"
    foreach ($q in $supportedQueries) {
        Write-Host "    - $q" -ForegroundColor Gray
    }
} else {
    Warn "No supported queries parsed from PROVIDER_CONFIG.txt"
}

# --- Check 5: Cross-check build script QIDMs against supported list ---
Write-Host "`n=== Check 5: Build Script QIDM Cross-Check ===" -ForegroundColor White

if ($BuildScript -and $supportedQueries.Count -gt 0 -and (Test-Path $BuildScript)) {
    $scriptContent = Get-Content $BuildScript -Raw
    $qidmMatches = [regex]::Matches($scriptContent, "query\s*=\s*['""](\w+Query)['""]")
    $scriptQueries = $qidmMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

    if ($scriptQueries.Count -gt 0) {
        foreach ($sq in $scriptQueries) {
            if ($sq -in $supportedQueries) {
                Pass "QIDM '$sq' is in supported list"
            } else {
                Warn "QIDM '$sq' in build script but NOT in PROVIDER_CONFIG supported list"
            }
        }
        foreach ($cq in $supportedQueries) {
            if ($cq -notin $scriptQueries) {
                Warn "PROVIDER_CONFIG lists '$cq' but not found in build script"
            }
        }
    } else {
        Write-Host "  [SKIP] No query= assignments found in build script" -ForegroundColor Gray
    }
} else {
    Write-Host "  [SKIP] No build script or no supported queries to cross-check" -ForegroundColor Gray
}

# --- Summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " PREFLIGHT: $passCount PASS / $failCount FAIL / $warnCount WARN" -ForegroundColor $(if ($failCount -gt 0) { "Red" } elseif ($warnCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    Write-Host "`n  FIX ALL FAILURES before building." -ForegroundColor Red
    exit 1
}
