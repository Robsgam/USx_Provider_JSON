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
  2. Stated totals match reality ("Total CommSys combos: N", "N CommSys QIDMs", "N combos").
  3. The stated "JSON version:" matches the active JSON's filename version.

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
$allTxt = $txt -join "`n"
$m2 = [regex]::Match($allTxt, 'Total CommSys combos:\s*(\d+)')
if ($m2.Success) {
    if ([int]$m2.Groups[1].Value -eq $comboCount) { Emit "  [PASS] stated CommSys combo total ($comboCount) matches the JSON" "Green"; $pass++ }
    else { Emit "  [FAIL] stated 'Total CommSys combos: $($m2.Groups[1].Value)' but the JSON has $comboCount" "Red"; $fail++ }
}
$m3 = [regex]::Match($allTxt, '(\d+)\s+CommSys QIDMs')
if ($m3.Success) {
    if ([int]$m3.Groups[1].Value -eq $qidmCount) { Emit "  [PASS] stated CommSys QIDM count ($qidmCount) matches the JSON" "Green"; $pass++ }
    else { Emit "  [FAIL] stated '$($m3.Groups[1].Value) CommSys QIDMs' but the JSON has $qidmCount" "Red"; $fail++ }
}
$m4 = [regex]::Match($allTxt, '(?m)^Architecture:.*?,\s*(\d+)\s+combos')
if ($m4.Success) {
    if ([int]$m4.Groups[1].Value -eq $comboCount) { Emit "  [PASS] Architecture line combo count ($comboCount) matches the JSON" "Green"; $pass++ }
    else { Emit "  [FAIL] Architecture line says '$($m4.Groups[1].Value) combos' but the JSON has $comboCount" "Red"; $fail++ }
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
