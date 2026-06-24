<#
  audit_reproducible.ps1 -- proves the "committed JSON == a fresh build" contract.

  Runs the provider's REAL build script TWICE into scratch files (via the
  $env:REPRO_OUTPATH hook in Write-ProviderJson -- committed files are never
  touched), then:
    1. DETERMINISM: canonical(scratch1) == canonical(scratch2)?  (same inputs ->
       same output). A mismatch is a genuine build bug -> FAIL.
    2. CURRENCY: canonical-normalized(scratch) == canonical-normalized(committed)?
       (normalization drops the top-level `version` field and the current-year
       PlateYear, which are intentionally variant). A mismatch means the build is
       deterministic but the COMMITTED JSON is STALE vs current build inputs
       (KB / shared modules) -> WARN (FAIL only with -Strict).
    3. Reports raw byte equality (scratch vs committed) as an info signal.

  Usage: .\audit_reproducible.ps1 -Path <provider.json> [-OutFile <report>] [-Strict]
  Exit: 1 if non-deterministic (or stale with -Strict); else 0.
#>
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '_json_canonical.ps1')

$resolved = (Resolve-Path $Path).Path
$provider = [System.IO.Path]::GetFileNameWithoutExtension($resolved) -replace '(?i)_(BASE|MC)$',''
$provDir  = Split-Path $resolved -Parent
$scriptDir = Join-Path $provDir 'scripts'

$lines = [System.Collections.Generic.List[string]]::new()
$fail = 0; $pass = 0; $warn = 0
function Emit($s) { $lines.Add($s); Write-Host $s }

Emit "================================================================"
Emit "  BUILD REPRODUCIBILITY AUDIT -- $provider"
Emit "================================================================"

# Locate the build script
if (-not (Test-Path $scriptDir)) { Emit "[FAIL] no scripts/ dir for $provider"; Emit "RESULTS: 0 PASS / 1 FAIL / 0 WARN"; if ($OutFile){[System.IO.File]::WriteAllText($OutFile,($lines-join"`r`n"),[System.Text.UTF8Encoding]::new($false))}; exit 1 }
$buildScript = Get-ChildItem $scriptDir -Filter 'build_*.ps1' -File | Select-Object -First 1
if (-not $buildScript) { Emit "[FAIL] no build_*.ps1 in $scriptDir"; Emit "RESULTS: 0 PASS / 1 FAIL / 0 WARN"; if ($OutFile){[System.IO.File]::WriteAllText($OutFile,($lines-join"`r`n"),[System.Text.UTF8Encoding]::new($false))}; exit 1 }
Emit "Build script: $($buildScript.Name)"
Emit ""

$tempBase = [System.IO.Path]::GetTempPath()
$scratch1 = Join-Path $tempBase "repro_${provider}_1.json"
$scratch2 = Join-Path $tempBase "repro_${provider}_2.json"

function Invoke-ScratchBuild($outPath) {
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    $env:REPRO_OUTPATH = $outPath
    try {
        & powershell.exe -ExecutionPolicy Bypass -File $buildScript.FullName 2>&1 | Out-Null
    } finally {
        Remove-Item Env:\REPRO_OUTPATH -ErrorAction SilentlyContinue
    }
    return (Test-Path $outPath)
}

function Show-FirstDiff($a, $b, $label) {
    $min = [Math]::Min($a.Length, $b.Length)
    $i = 0; while ($i -lt $min -and $a[$i] -eq $b[$i]) { $i++ }
    $start = [Math]::Max(0, $i - 40)
    $lenA = [Math]::Min(110, $a.Length - $start)
    $lenB = [Math]::Min(110, $b.Length - $start)
    Emit "  $label first differs at offset $($i):"
    Emit "    A: ...$($a.Substring($start, $lenA))..."
    Emit "    B: ...$($b.Substring($start, $lenB))..."
}

# --- Build twice into scratch ---
Emit "Building twice into scratch (committed files untouched)..."
if (-not (Invoke-ScratchBuild $scratch1)) { Emit "[FAIL] scratch build #1 produced no output"; Emit "RESULTS: 0 PASS / 1 FAIL / 0 WARN"; if ($OutFile){[System.IO.File]::WriteAllText($OutFile,($lines-join"`r`n"),[System.Text.UTF8Encoding]::new($false))}; exit 1 }
if (-not (Invoke-ScratchBuild $scratch2)) { Emit "[FAIL] scratch build #2 produced no output"; Emit "RESULTS: 0 PASS / 1 FAIL / 0 WARN"; if ($OutFile){[System.IO.File]::WriteAllText($OutFile,($lines-join"`r`n"),[System.Text.UTF8Encoding]::new($false))}; exit 1 }

# --- 1. Determinism: scratch1 vs scratch2 ---
$canon1 = ConvertTo-Canonical (Get-Content $scratch1 -Raw -Encoding UTF8 | ConvertFrom-Json)
$canon2 = ConvertTo-Canonical (Get-Content $scratch2 -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($canon1 -eq $canon2) {
    Emit "[PASS] DETERMINISTIC -- two fresh builds are canonically identical"; $pass++
} else {
    Emit "[FAIL] NON-DETERMINISTIC -- two fresh builds differ (build bug)"; $fail++
    Show-FirstDiff $canon1 $canon2 "scratch1 vs scratch2"
}

# --- 2. Currency: normalized scratch vs normalized committed ---
$normScratch   = ConvertTo-Canonical (New-NormalizedClone (Get-Content $scratch1 -Raw -Encoding UTF8 | ConvertFrom-Json) -Top)
$normCommitted = ConvertTo-Canonical (New-NormalizedClone (Get-Content $resolved -Raw -Encoding UTF8 | ConvertFrom-Json) -Top)
if ($normScratch -eq $normCommitted) {
    Emit "[PASS] CURRENT -- committed JSON matches a fresh build (version/PlateYear normalized)"; $pass++
} else {
    if ($Strict) { Emit "[FAIL] STALE -- committed JSON differs from a fresh build (rebuild needed)"; $fail++ }
    else         { Emit "[WARN] STALE -- committed JSON differs from a fresh build (rebuild needed)"; $warn++ }
    Show-FirstDiff $normCommitted $normScratch "committed vs fresh (normalized)"
}

# --- 3. Raw byte equality (info) ---
$rawScratchSha   = (Get-FileHash $scratch1 -Algorithm SHA256).Hash
$rawCommittedSha = (Get-FileHash $resolved -Algorithm SHA256).Hash
Emit ""
Emit "  raw byte-identical (scratch vs committed): $($rawScratchSha -eq $rawCommittedSha)"
Emit "  (raw includes version field + PlateYear; normalized compare above is authoritative)"

Remove-Item $scratch1, $scratch2 -Force -ErrorAction SilentlyContinue

Emit ""
Emit "RESULTS: $pass PASS / $fail FAIL / $warn WARN"
if ($OutFile) {
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
}
if ($fail -gt 0) { exit 1 } else { exit 0 }
