<#
  audit_log_combo_attribution.ps1 -- did the log's NAMED combo actually fire?

  WHY THIS EXISTS
  ---------------
  Every saved test log asserts a combo in its "Combo:" header and filename. Nothing
  verified that assertion, because the CommSys wire XML carries NO keyRef -- MessageType
  is just the query name. So a log named for combo A is indistinguishable from one where
  a sibling B fired, and "84 logs PASS" could silently mean "82 combos exercised, 2
  attributed to combos that never ran".

  That is exactly what happened on TX_TLETS v4.12: RQLicensePlateNumber and
  RQVehicleIdentificationNumber each carried a PASS log, but both are unreachable behind
  REG/VIN (FinancialResponsibilityType is form-prefilled 'E'), so each log actually
  exercised its shadower. The RQLicensePlateNumber log's own wire proves it -- it carries
  BOTH FinancialResponsibilityType (REG's set field) AND LicensePlateTypeCode (RQ's).

  HOW IT WORKS
  ------------
  Each log stores its QUERY STRING: the exact dex-log field map that was submitted. All
  routing is EXISTENCE-based (value-comparison operators poison the whole array, so they
  are banned), which means field PRESENCE in that map fully determines which combo fires.
  So the fill can be replayed deterministically:

    1. read the log's QUERY STRING (fill), "Combo:" header, and query name
    2. find the QIDM that owns the claimed keyRef
    3. walk that QIDM's combinations IN ORDER; first one whose set[] is satisfied and
       whose conditions pass is what the platform actually fired
    4. compare to the claimed keyRef

  Uses _sim_helpers.ps1 Test-ComboConditionsCore -- the same canonical predicate as
  test_commsys.ps1 / run_test_matrix.ps1, so this cannot drift from the simulator.

  Log name suffixes are stripped to recover the base keyRef: _any, _af_<field>,
  _guardrail_vs_<other>. A _guardrail_vs_X log asserts that X did NOT win, so the
  claimed combo is the part before _guardrail_vs_.

  Usage: .\audit_log_combo_attribution.ps1 -Path <provider.json> [-OutFile <path>]
  Exit:  0 = every log's named combo is what fired, 1 = at least one misattribution
#>

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot '_sim_helpers.ps1')

$jsonPath = (Resolve-Path $Path).Path
$json = [System.IO.File]::ReadAllText($jsonPath, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
$provDir = Split-Path $jsonPath -Parent
$logsDir = Join-Path $provDir 'logs'

$lines = @()
function Emit($t, $c = "Gray") { Write-Host $t -ForegroundColor $c; $script:lines += $t }

Emit "================================================================"
Emit "  LOG COMBO ATTRIBUTION AUDIT -- $(Split-Path $jsonPath -Leaf)"
Emit "================================================================"

if (-not (Test-Path $logsDir)) {
    Emit "  [INFO] no logs/ directory -- nothing to attribute" "DarkGray"
    if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
    exit 0
}

# -- Collect CommSys QIDMs, keyRef -> owning QIDM --
$qidms = @()
foreach ($b in $json.bundles) {
    if ($b.provider -in @('MARK43','RMS')) { continue }
    foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
        if ($c.handlerFunction -eq 'RmsRestPayloadHandler') { continue }
        $qidms += $c
    }
}

# Exclude archived logs -- they belong to superseded versions.
$logFiles = Get-ChildItem $logsDir -Recurse -Filter '*.txt' -File |
            Where-Object { $_.FullName -notmatch '_archive' }

$ok = 0; $mismatch = 0; $skipped = 0
foreach ($lf in $logFiles) {
    $text = [System.IO.File]::ReadAllText($lf.FullName)

    $mCombo = [regex]::Match($text, '(?m)^Combo:\s*(\S+)')
    $mFill  = [regex]::Match($text, '(?s)QUERY STRING\s*\r?\n-+\r?\n\s*(\{.*?\})\s*\r?\n')
    if (-not $mCombo.Success -or -not $mFill.Success) { $skipped++; continue }

    $claimRaw = $mCombo.Groups[1].Value
    # strip harness suffixes to recover the base keyRef
    $claim = $claimRaw -replace '_guardrail_vs_.*$','' -replace '_af_.*$','' -replace '_any$',''

    try { $fillObj = $mFill.Groups[1].Value | ConvertFrom-Json } catch { $skipped++; continue }
    $fill = @{}
    foreach ($p in $fillObj.PSObject.Properties) {
        if (-not [string]::IsNullOrWhiteSpace("$($p.Value)")) { $fill[$p.Name] = $p.Value }
    }

    # QIDM that owns the claimed keyRef -- MUST be scoped by query name, never by bare
    # keyRef. keyRefs collide across QIDMs within one provider (NY_NYSPIN_EJUSTICE reuses
    # RVEH/RCAR on both VehicleRegistrationQuery and BoatQuery), so a bare-keyRef lookup
    # picks the wrong QIDM and evaluates a Vehicle fill against Boat combos -> bogus
    # "NO COMBO FIRES". See BUILD_RULES.txt Section 13 (shared-tool keyRef scoping).
    # Header line: "TEST LOG: <PROVIDER> <Entity> <QueryName>"
    $mQuery = [regex]::Match($text, '(?m)^TEST LOG:\s+\S+\s+(\S+)\s+(\S+)')
    $logEntity = if ($mQuery.Success) { $mQuery.Groups[1].Value } else { $null }
    $logQuery  = if ($mQuery.Success) { $mQuery.Groups[2].Value } else { $null }

    $candidates = @($qidms | Where-Object {
        @($_.combinations | ForEach-Object { $_.keyReference }) -contains $claim
    })
    if ($candidates.Count -eq 0) { $skipped++; continue }
    $owner = $null
    if ($candidates.Count -eq 1) {
        $owner = $candidates[0]
    } else {
        if ($logQuery)  { $owner = $candidates | Where-Object { $_.name -match [regex]::Escape($logQuery) } | Select-Object -First 1 }
        if (-not $owner -and $logEntity) { $owner = $candidates | Where-Object { $_.targetEntity -eq $logEntity } | Select-Object -First 1 }
        if (-not $owner) {
            Emit ""
            Emit "  [FAIL] AMBIGUOUS: $($lf.Name)" "Red"
            Emit "         keyRef '$claim' exists in $($candidates.Count) QIDMs and the log header did not disambiguate"
            $mismatch++
            continue
        }
    }

    # First matching combination wins
    $fired = $null
    foreach ($cb in @($owner.combinations)) {
        $setOk = $true
        foreach ($f in @($cb.requirements.set)) { if (-not $fill.ContainsKey($f)) { $setOk = $false; break } }
        if (-not $setOk) { continue }
        $cr = Test-ComboConditionsCore (Get-ComboConditions $cb) $fill
        if (-not $cr.ok) { continue }
        $fired = $cb.keyReference
        break
    }

    if ($null -eq $fired) {
        Emit ""
        Emit "  [FAIL] NO COMBO FIRES: $($lf.Name)" "Red"
        Emit "         claimed '$claim' but the recorded fill satisfies no combination in $($owner.name -replace '.*_','')"
        $mismatch++
    } elseif ($fired -ne $claim) {
        Emit ""
        Emit "  [FAIL] MISATTRIBUTED: $($lf.Name)" "Red"
        Emit "         claims '$claim' but the recorded fill fires '$fired' (ordered earlier, first-match wins)"
        Emit "         => this log is evidence for '$fired', NOT for '$claim'" "Yellow"
        $mismatch++
    } else {
        $ok++
    }
}

Emit ""
Emit "================================================================"
$sk = if ($skipped -gt 0) { " ($skipped unparseable/non-CommSys skipped)" } else { "" }
if ($mismatch -eq 0) {
    Emit "  [PASS] $ok log(s) verified -- named combo is what fired$sk" "Green"
} else {
    Emit "  [FAIL] $mismatch misattributed log(s); $ok verified$sk" "Red"
}
Emit "================================================================"

if ($OutFile) {
    $d = Split-Path $OutFile -Parent
    if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Saved: $OutFile" -ForegroundColor Gray
}

if ($mismatch -gt 0) { exit 1 } else { exit 0 }
