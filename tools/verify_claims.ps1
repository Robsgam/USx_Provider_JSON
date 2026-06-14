<#
  verify_claims.ps1 -- Hypothesis Quarantine Gate

  WHY: the FL_FCIC v4.7->v5.0 churn happened because an unverified platform-behavior
  HYPOTHESIS ("value-comparison conditions gate firing") was written into the KB and BOTH
  simulators as "live-proven FL v4.8" BEFORE the discriminating test (T-A/T-B) was run. The
  simulators then produced false-confidence PASS results. Nothing checked that a "live-proven"
  claim referenced a real committed test log. This tool is that check.

  KB STATUS CONVENTION (enforced here):
    STATUS: LIVE-PROVEN <test-log path>           -- behavior confirmed by a committed test log
    STATUS: HYPOTHESIS <named discriminating test> -- not yet proven; MUST NOT be encoded as fact

  Scans: knowledge-base/*.txt + tools/test_commsys.ps1 + tools/run_test_matrix.ps1

  Checks:
    A. Every "STATUS: LIVE-PROVEN <path>" cites a test-log path that EXISTS in the repo.
       (archived logs under tests/_archive_pre_v*/ count -- they are committed evidence.)
    B. Every "STATUS: HYPOTHESIS <test>" names a non-empty discriminating test.
    C. Every concrete test-log path reference (providers/.../tests/....txt) in any scanned
       file resolves. Catches stale citations after a reset archives the logs.

  Exit 0 = all claims backed.  Exit 1 = at least one unbacked/stale claim.

  Usage:
    .\verify_claims.ps1
    .\verify_claims.ps1 -OutFile claims_report.txt
#>

param(
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path

$output = [System.Text.StringBuilder]::new()
function Out-Line($text)            { [void]$output.AppendLine($text); Write-Host $text }
function Out-Color($text, $color)   { [void]$output.AppendLine($text); Write-Host $text -ForegroundColor $color }

$failCount = 0
$passCount = 0
$infoCount = 0

# Resolve a cited path (relative to repo root) and report existence.
# Test-log filenames are long and descriptive -- many exceed Windows MAX_PATH (260). Windows
# PowerShell 5.1 (which enforce.ps1 uses to invoke this tool) fails Test-Path on those, so fall
# back to the \\?\ extended-length prefix, which .NET resolves regardless of length.
function Test-RepoPath($p) {
    $p = $p.Trim().Trim('"').Trim("'")
    if (-not $p) { return $false }
    $full = Join-Path $repoRoot ($p -replace '/', '\')
    if (Test-Path -LiteralPath $full) { return $true }
    $ext = "\\?\" + $full
    return ([System.IO.File]::Exists($ext) -or [System.IO.Directory]::Exists($ext))
}

Out-Color "============================================================" "Cyan"
Out-Color "  VERIFY CLAIMS -- Hypothesis Quarantine Gate" "Cyan"
Out-Color "============================================================" "Cyan"

# ── Gather scan targets ────────────────────────────────────────────────────────
$kbDir = Join-Path $repoRoot "knowledge-base"
$scanFiles = @()
$scanFiles += Get-ChildItem $kbDir -Filter "*.txt" -File -ErrorAction SilentlyContinue
foreach ($sim in @("test_commsys.ps1", "run_test_matrix.ps1")) {
    $simPath = Join-Path $toolDir $sim
    if (Test-Path $simPath) { $scanFiles += Get-Item $simPath }
}

# Regex for a concrete test-log path: providers\<p>\tests\...\<file>.txt
# Filenames may contain = + ; ( ) - but never spaces or quotes.
$pathRegex = '(providers[\\/][^\s''"]*tests[\\/][^\s''"]*\.txt)'

# ── CHECK A + B: STATUS convention lines ───────────────────────────────────────
Out-Line ""
Out-Color "  CHECK A/B: STATUS convention (LIVE-PROVEN / HYPOTHESIS)" "Yellow"

$statusLineCount = 0
foreach ($f in $scanFiles) {
    $rel = $f.FullName.Substring($repoRoot.Length + 1)
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
        $lineNo++
        if ($line -match 'STATUS:\s*LIVE-PROVEN\s+(\S+)') {
            $path = $Matches[1]
            # Skip convention/template examples like "STATUS: LIVE-PROVEN <test-log path>".
            if ($path -match '[<>]') { continue }
            $statusLineCount++
            if (Test-RepoPath $path) {
                Out-Color "    [PASS] $rel`:$lineNo LIVE-PROVEN cites existing log" "Green"
                $passCount++
            } else {
                Out-Color "    [FAIL] $rel`:$lineNo LIVE-PROVEN cites MISSING log: $path" "Red"
                $failCount++
            }
        } elseif ($line -match 'STATUS:\s*LIVE-PROVEN\s*$') {
            $statusLineCount++
            Out-Color "    [FAIL] $rel`:$lineNo LIVE-PROVEN with NO cited test-log path" "Red"
            $failCount++
        } elseif ($line -match 'STATUS:\s*HYPOTHESIS\s+(\S.*)$') {
            # Skip convention/template examples like "STATUS: HYPOTHESIS <named discriminating test>".
            if ($Matches[1] -match '[<>]') { continue }
            $statusLineCount++
            Out-Color "    [INFO] $rel`:$lineNo HYPOTHESIS -- must NOT be encoded as fact in a simulator: $($Matches[1].Trim())" "Gray"
            $infoCount++
        } elseif ($line -match 'STATUS:\s*HYPOTHESIS\s*$') {
            $statusLineCount++
            Out-Color "    [FAIL] $rel`:$lineNo HYPOTHESIS with NO named discriminating test" "Red"
            $failCount++
        }
    }
}
if ($statusLineCount -eq 0) {
    Out-Color "    [INFO] no STATUS: convention lines found yet (retrofit load-bearing rules)" "Gray"
    $infoCount++
}

# ── CHECK C: concrete test-log path references resolve ─────────────────────────
Out-Line ""
Out-Color "  CHECK C: concrete test-log path citations resolve" "Yellow"

$citationCount = 0
foreach ($f in $scanFiles) {
    $rel = $f.FullName.Substring($repoRoot.Length + 1)
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
        $lineNo++
        foreach ($m in [regex]::Matches($line, $pathRegex)) {
            $citationCount++
            $path = $m.Groups[1].Value
            if (Test-RepoPath $path) {
                $passCount++
            } else {
                Out-Color "    [FAIL] $rel`:$lineNo cites MISSING test log: $path" "Red"
                $failCount++
            }
        }
    }
}
if ($citationCount -eq 0) {
    Out-Color "    [INFO] no concrete test-log path citations found" "Gray"
    $infoCount++
} elseif ($failCount -eq 0) {
    Out-Color "    [PASS] all $citationCount path citation(s) resolve" "Green"
}

# ── VERDICT ────────────────────────────────────────────────────────────────────
Out-Line ""
Out-Color "============================================================" "Cyan"
if ($failCount -eq 0) {
    Out-Color "  CLAIMS VERIFIED: $passCount PASS / 0 FAIL / $infoCount INFO" "Green"
    Out-Line  "  Every live-proven claim references a committed test log."
} else {
    Out-Color "  BLOCKED: $passCount PASS / $failCount FAIL / $infoCount INFO" "Red"
    Out-Line  "  An unbacked or stale 'live-proven' claim was found. Either cite a committed"
    Out-Line  "  test log or downgrade the claim to STATUS: HYPOTHESIS <discriminating test>."
}
Out-Color "============================================================" "Cyan"

if ($OutFile) {
    $output.ToString() | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "Report saved: $OutFile" -ForegroundColor Gray
}

if ($failCount -gt 0) { exit 1 }
exit 0
