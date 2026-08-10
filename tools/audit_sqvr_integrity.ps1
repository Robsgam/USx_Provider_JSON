<#
  audit_sqvr_integrity.ps1 -- is the SQVR still telling the truth about the JSON?

  WHY THIS EXISTS
  ---------------
  The SQVR is hand-maintained prose that ASSERTS things about the build (which combos exist,
  how many, which version). Nothing verified those assertions, so it silently rotted every
  time a combo was added or removed -- the recurring "SQVR staleness" class:

    TX_TLETS  still listed QVLicensePlateNumber + QVVehicleIdentificationNumber and claimed
              "Total CommSys combos: 21 (7 Vehicle)" -- both QV combos were REMOVED at v4.9
              and the per-combo blocks were cleaned at v4.10, but the summary was missed.
              It also carried [CONFIRMED] on two combos that cannot fire.
    AZ_AZDPS  still documented ACQW/ACQWN/ACQM/ACQMN as [PENDING] test work after v3.3
              deleted both WMPI QIDMs as out-of-devdoc-Basic-scope.
    HI_HCJDC  described Vehicle as "3 cards" after v4.14 collapsed it to one.

  A stale SQVR is worse than no SQVR: it is the document a tester reads to decide what to
  test, so rot here converts directly into wasted tenant-test time.

  WHAT IT CHECKS
  --------------
  1. Every keyRef named in a `keyReference:` line exists in the JSON -- UNLESS its block is
     explicitly marked as a known-unbuilt path. HI's QVV/QVP are legitimately documented
     [DORMANT] (VehicleStolenQuery is not built, the server auto-generates it), so markers
     DORMANT / NOT BUILT / NOTBUILT / REMOVED / OUT OF SCOPE / NOT APPLICABLE / SKIP are
     accepted and reported as [NOTE].
  2. Stated totals match reality -- the GRAND-total combo count, the CommSys QIDM count and the
     Architecture line. CHECK 2 REPORTS ITS OWN DENOMINATOR and says so when it finds nothing to
     compare; see the note below for why that is not cosmetic.
  3. The stated "JSON version:" matches the active JSON's filename version.

  WHY CHECK 2 PRINTS A DENOMINATOR (fixed 2026-08-10, LAW 2 / ENGINEERING_STANDARD 4.3)
  --------------------------------------------------------------------------------------
  CHECK 2 originally matched three EXACT phrasings: 'Total CommSys combos: N', 'N CommSys QIDMs'
  and '^Architecture: ..., N combos'. Measured across the portfolio, those fire on 3 providers.
  The other 17 got ZERO totals comparisons and the tool still printed
  '[PASS] SQVR consistent with the JSON' -- a vacuous pass on 85% of the portfolio, on the one
  check this tool exists to perform.
  It was caught on HI_HCJDC_OFML, which wrote 'Total combos: 12 CommSys' -- the word CommSys
  AFTER the number, so every pattern missed. HI's SQVR asserted 17 combos against a JSON holding
  12, plus 'CONFIRMED: none on v4.6' and 'PENDING: ALL 5 entities' on a provider tenant-verified
  ALL-PASS twice, and this gate passed it through nine version bumps. The SQVR is what a tester
  reads to decide what to test, so a stale total is not a typo.
  Only 7 of 20 SQVRs assert a grand total at all. For the 13 that do not, CHECK 2 now emits an
  explicit [NOTE] that it did not run, rather than contributing silence to a PASS. Making that a
  FAIL was rejected: it would redden 13 providers for a sentence they never wrote.

  THE PHRASING TRAP -- read before "simplifying" the grand-total regex.
  NJ_NJCJIS writes 'Total combos: 5 QIDMs / 8 combos (+ 3 user-approved skips)'. The obvious
  pattern 'Total combos:\s*(\d+)' captures 5 -- the QIDM count -- and emits a FALSE FAIL against
  a JSON with 8. So the number immediately PRECEDING the word 'combos' wins, and only if there is
  none do we fall back to the number FOLLOWING 'combos:'. That ordering resolves all 7 asserting
  providers correctly (FL 31, HI 12, LA 12, NJ 8, NY 16, TX 19 -- verified 2026-08-10 against
  audit_test_coverage's count from each emitted JSON). Do NOT broaden this to a bare
  '(\d+) combos' anywhere in the file: every SQVR carries per-entity and per-section counts
  ('15 combos', '8 combos', '2 combos') that are not the grand total.

  Deliberately NOT checked: whether every JSON combo has an SQVR block. 13 never-tested
  providers use a lighter SQVR format with no per-combo blocks at all; flagging those would
  be 13 false alarms and would push a pointless mass-rewrite.

  Usage: .\audit_sqvr_integrity.ps1 -Path <provider.json> [-OutFile <path>]
  Exit:  0 = SQVR consistent with the JSON, 1 = stale content found
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

$jsonPath = (Resolve-Path $Path).Path
$provDir  = Split-Path $jsonPath -Parent
$json = [System.IO.File]::ReadAllText($jsonPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json

$lines = @()
function Emit($t, $c = "Gray") { Write-Host $t -ForegroundColor $c; $script:lines += $t }

Emit "================================================================"
Emit "  SQVR INTEGRITY AUDIT -- $(Split-Path $jsonPath -Leaf)"
Emit "================================================================"

$sqvr = Get-ChildItem $provDir -Recurse -Filter '*_SQVR.txt' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $sqvr) {
    Emit "  [INFO] no SQVR file found -- nothing to verify" "DarkGray"
    if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
    exit 0
}

# -- live keyRefs + counts from the JSON --
$live = @{}; $qidmCount = 0
foreach ($b in $json.bundles) {
    if ($b.provider -in @('MARK43','RMS')) { continue }
    foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if ($c.handlerFunction -eq 'RmsRestPayloadHandler') { continue }
        $qidmCount++
        foreach ($cb in $c.combinations) { if ($cb.keyReference) { $live["$($cb.keyReference)"] = $true } }
    }
}
$comboCount = 0
foreach ($b in $json.bundles) {
    if ($b.provider -in @('MARK43','RMS')) { continue }
    foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and $c.handlerFunction -ne 'RmsRestPayloadHandler') {
            $comboCount += @($c.combinations).Count
        }
    }
}

$txt = Get-Content $sqvr.FullName
$fail = 0; $note = 0; $pass = 0
$unbuiltMarkers = 'DORMANT|NOT BUILT|NOTBUILT|NOT-BUILT|REMOVED|OUT OF SCOPE|OUT-OF-SCOPE|NOT APPLICABLE|APPROVED SKIP|SKIPPED'

# -- CHECK 1: keyRefs named in the SQVR must exist --
# A numbered section header (e.g. "7. WMPIWantedPersonInquiry ... [REMOVED v3.3]") marks EVERY
# combo in that section as intentionally unbuilt, so the marker must be carried forward for the
# whole section -- a fixed look-back window misses combos further down (it accepted AZ's ACQM but
# still flagged ACQW/ACQWN/ACQMN in the same removed sections).
$sectionUnbuilt = $false
for ($i = 0; $i -lt $txt.Count; $i++) {
    if ($txt[$i] -match '^\s*\d+\.\s+\S') {
        $sectionUnbuilt = ($txt[$i] -match $unbuiltMarkers)
    }
    $m = [regex]::Match($txt[$i], '^\s*keyReference:\s*(\S+)')
    if (-not $m.Success) { continue }
    $kr = $m.Groups[1].Value
    if ($live.ContainsKey($kr)) { continue }

    # Block-level marker (the combo's own lines) OR an unbuilt-marked enclosing section.
    $lo = [Math]::Max(0, $i - 14)
    $ctx = ($txt[$lo..$i] -join ' ')
    if ($sectionUnbuilt -or $ctx -match $unbuiltMarkers) {
        Emit "  [NOTE] '$kr' (L$($i+1)) is not in the JSON, but its block is marked as a known-unbuilt path" "DarkYellow"
        $note++
    } else {
        Emit "  [FAIL] STALE: keyReference '$kr' (L$($i+1)) does not exist in the JSON" "Red"
        Emit "         Either the combo was removed and this block was left behind, or the block needs an" "Yellow"
        Emit "         explicit marker (DORMANT / REMOVED / NOT BUILT / OUT OF SCOPE)." "Yellow"
        $fail++
    }
}

# -- CHECK 2: stated totals --
# Assertions COMPARED is tracked and printed: a CHECK 2 that matched nothing must not be
# indistinguishable from a CHECK 2 that found everything correct. See the header note.
$allTxt = $txt -join "`n"
$totalsChecked = 0

# Grand-total combo count. Accept every phrasing the portfolio actually uses:
#   'Total CommSys combos: 19'          -> 19
#   'Total combos: 12 CommSys + RMS'    -> 12
#   'Total combos: 31 CommSys (6 QIDMs)'-> 31
#   'Total combos: 5 QIDMs / 8 combos'  -> 8   (NOT 5 -- see THE PHRASING TRAP in the header)
# Scope to the line carrying the 'Total ... combos' phrase so per-section counts can't be swept in.
$totalLine = ($txt | Where-Object { $_ -match 'Total\s+(CommSys\s+)?combos?\s*:' } | Select-Object -First 1)
if ($totalLine) {
    $stated = $null
    # A digit immediately BEFORE the word 'combos' is the authoritative one when present.
    $pre = [regex]::Match($totalLine, '(\d+)\s+combos?\b')
    if ($pre.Success) { $stated = [int]$pre.Groups[1].Value }
    else {
        $post = [regex]::Match($totalLine, 'combos?\s*:\s*(\d+)')
        if ($post.Success) { $stated = [int]$post.Groups[1].Value }
    }
    if ($null -ne $stated) {
        $totalsChecked++
        if ($stated -eq $comboCount) { Emit "  [PASS] stated CommSys combo total ($comboCount) matches the JSON" "Green"; $pass++ }
        else { Emit "  [FAIL] SQVR states $stated combo(s) but the JSON has $comboCount -- '$($totalLine.Trim())'" "Red"; $fail++ }
    }
}
$m3 = [regex]::Match($allTxt, '(\d+)\s+CommSys QIDMs')
if ($m3.Success) {
    $totalsChecked++
    if ([int]$m3.Groups[1].Value -eq $qidmCount) { Emit "  [PASS] stated CommSys QIDM count ($qidmCount) matches the JSON" "Green"; $pass++ }
    else { Emit "  [FAIL] stated '$($m3.Groups[1].Value) CommSys QIDMs' but the JSON has $qidmCount" "Red"; $fail++ }
}
$m4 = [regex]::Match($allTxt, '(?m)^Architecture:.*?,\s*(\d+)\s+combos')
if ($m4.Success) {
    $totalsChecked++
    if ([int]$m4.Groups[1].Value -eq $comboCount) { Emit "  [PASS] Architecture line combo count ($comboCount) matches the JSON" "Green"; $pass++ }
    else { Emit "  [FAIL] Architecture line says '$($m4.Groups[1].Value) combos' but the JSON has $comboCount" "Red"; $fail++ }
}
if ($totalsChecked -eq 0) {
    Emit "  [NOTE] CHECK 2 DID NOT RUN -- this SQVR asserts no combo/QIDM total, so nothing was compared" "Yellow"
    Emit "         (not a defect: 13 of 20 SQVRs use the lighter format. Recorded so a silent" "DarkGray"
    Emit "          non-comparison is never read as a verified total -- ENGINEERING_STANDARD 4.3.)" "DarkGray"
} else {
    Emit "  [INFO] CHECK 2 compared $totalsChecked stated total(s) against the JSON" "DarkGray"
}

# -- CHECK 3: stated version --
$verM = [regex]::Match((Split-Path $jsonPath -Leaf), '_v([0-9]+\.[0-9]+)\.json$')
if ($verM.Success) {
    $actual = $verM.Groups[1].Value
    $m5 = [regex]::Match($allTxt, '(?m)^JSON version:\s*v?([0-9]+\.[0-9]+)')
    if ($m5.Success) {
        if ($m5.Groups[1].Value -eq $actual) { Emit "  [PASS] stated JSON version v$actual matches the active JSON" "Green"; $pass++ }
        else { Emit "  [FAIL] SQVR says 'JSON version: v$($m5.Groups[1].Value)' but the active JSON is v$actual" "Red"; $fail++ }
    }
}

Emit ""
Emit "================================================================"
$nsfx = if ($note -gt 0) { " ($note documented-unbuilt note(s))" } else { "" }
if ($fail -eq 0) { Emit "  [PASS] SQVR consistent with the JSON$nsfx" "Green" }
else { Emit "  [FAIL] $fail stale SQVR assertion(s)$nsfx" "Red" }
Emit "================================================================"

if ($OutFile) {
    $d = Split-Path $OutFile -Parent
    if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

if ($fail -gt 0) { exit 1 } else { exit 0 }
