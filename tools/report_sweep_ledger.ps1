# report_sweep_ledger.ps1 -- THE SWEEP LEDGER: planned vs logged vs owed, per entity.
#
# WHY THIS EXISTS (2026-08-18, TX_TLETS v4.21 sweep -- Rob: "we need to fix this process"):
# during a 98-test sweep the Boat entity was driven (22 queries submitted) and then NOT captured,
# because the fetch drained a manifest that still held the PREVIOUS entity. capture.js reported
#     "done. +8 new, 8 total, ALL 8 manifest entries captured"
# which is TRUE and USELESS: it confirms it captured everything the manifest held, and never checks
# that the manifest held what you just ran. A success line that cannot fail -- the same defect class
# as an inert gate. The operator believed Boat was captured; the only reason it was caught is that
# somebody hand-diffed the repo. Four entities had already gone through the same loop, each costing
# multiple round trips of "run / fetch / did it land?".
#
# THE FIX IS NOT A BETTER CONSOLE MESSAGE. It is to make the REPO the authority and print it
# automatically at the one moment everybody is already looking -- immediately after each ingest.
# The browser knows what it queued; only the repo knows what is actually ON DISK, and on-disk logs
# are what every downstream gate (6c/6d/2i, plan completeness, portfolio_status) reads.
#
# COUNTS ONLY CURRENT-VERSION LOGS. It filters to '<PROVIDER>_v<ver>_*' and skips any _archive_
# path. A bare 'logs/<Entity>/*.txt' count would silently include a stale-version log left in the
# live folder and report coverage that no gate would accept.
#
# ALWAYS EXITS 0 -- it is a REPORT, not a gate. Owing captures mid-sweep is the normal state, and a
# blocking exit here would train everyone to skip it (same reasoning as report_import_owed.ps1).
# But it REFUSES TO REPORT A CLEAN LEDGER IT COULD NOT MEASURE: no active JSON, or no test plan for
# the active version, prints [NO-VERDICT] and reports nothing as complete. A tool that cannot run
# has not passed.
#
# Usage:  report_sweep_ledger.ps1 -Provider TX_TLETS
#         report_sweep_ledger.ps1 -All
#         report_sweep_ledger.ps1 -Provider TX_TLETS -Quiet    (one line, for automation)

[CmdletBinding()]
param(
    [string]$Provider,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. "$repo\tools\_resolve_provider_json.ps1"

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s, $color) {
    $lines.Add($s) | Out-Null
    if (-not $Quiet) { if ($color) { Write-Host $s -ForegroundColor $color } else { Write-Host $s } }
}

# ---- which providers ----
$targets = @()
if ($All) {
    $targets = @(Get-ChildItem (Join-Path $repo 'providers') -Directory | Select-Object -Expand Name)
} elseif ($Provider) {
    $targets = @($Provider)
} else {
    Write-Host "report_sweep_ledger.ps1: give -Provider <NAME> or -All" -ForegroundColor Yellow
    exit 0
}

$anyOwed = $false

foreach ($p in $targets) {
    $dir = Join-Path $repo "providers\$p"
    if (-not (Test-Path $dir)) { Emit "  [NO-VERDICT] $p -- no such provider directory" 'DarkYellow'; continue }

    $jsonPath = Get-ProviderRootJson -ProvDir $dir -Provider $p
    if (-not $jsonPath) { Emit "  [NO-VERDICT] $p -- no active root JSON; cannot measure a sweep" 'DarkYellow'; continue }

    $ver = [regex]::Match([IO.Path]::GetFileNameWithoutExtension($jsonPath), '_v([\d.]+)$').Groups[1].Value
    if (-not $ver) { Emit "  [NO-VERDICT] $p -- active JSON is not version-named; cannot match logs to a plan" 'DarkYellow'; continue }

    $logsRoot = Join-Path $dir 'logs'
    $planPath = Join-Path $logsRoot "${p}_TEST_PLAN_v$ver.json"
    if (-not (Test-Path $planPath)) {
        Emit "  [NO-VERDICT] $p v$ver -- no test plan at logs\${p}_TEST_PLAN_v$ver.json; NOTHING is being compared" 'DarkYellow'
        continue
    }

    try { $plan = Get-Content $planPath -Raw | ConvertFrom-Json } catch {
        Emit "  [NO-VERDICT] $p v$ver -- test plan is unreadable: $($_.Exception.Message)" 'DarkYellow'; continue
    }
    $tests = @($plan.tests)
    if (-not $tests.Count) { Emit "  [NO-VERDICT] $p v$ver -- test plan holds ZERO tests" 'DarkYellow'; continue }

    # Entities the plan actually names, in plan order (do not hardcode the five -- a provider may
    # legitimately build fewer, and hardcoding would invent OWED rows for entities that do not exist).
    $entities = @()
    foreach ($t in $tests) { $e = "$($t.entity)"; if ($e -and $entities -notcontains $e) { $entities += $e } }

    $prefix = "${p}_v${ver}_"
    $tPlanned = 0; $tLogged = 0

    Emit "" $null
    Emit "  $p v$ver -- SWEEP LEDGER          planned  logged   owed" 'Cyan'
    Emit "  ------------------------------------------------------------" 'DarkGray'

    foreach ($e in $entities) {
        $planned = @($tests | Where-Object { "$($_.entity)" -eq $e }).Count
        $entDir  = Join-Path $logsRoot $e
        $logged  = 0
        if (Test-Path $entDir) {
            $logged = @(Get-ChildItem $entDir -Filter '*.txt' -File -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/]_archive_' -and $_.Name.StartsWith($prefix) }).Count
        }
        $owed = $planned - $logged
        $tPlanned += $planned; $tLogged += $logged

        $mark = ''
        $col  = 'Gray'
        if ($owed -gt 0)  { $mark = "<-- OWED"; $col = 'Yellow'; $anyOwed = $true }
        elseif ($owed -lt 0) { $mark = "<-- MORE LOGS THAN PLAN TESTS -- investigate"; $col = 'Red'; $anyOwed = $true }
        else { $mark = '' ; $col = 'Green' }

        Emit ("  {0,-24} {1,7} {2,7} {3,6}   {4}" -f $e, $planned, $logged, [Math]::Max($owed,0), $mark) $col
    }

    Emit "  ------------------------------------------------------------" 'DarkGray'
    $tOwed = $tPlanned - $tLogged
    # A SURPLUS MUST NOT TOTAL TO "COMPLETE". Caught on its first real use, 2026-08-18: after the
    # plan generator was fixed to drop two vacuous guardrails, TX_TLETS read 96 planned / 98 logged,
    # so two rows said "MORE LOGS THAN PLAN TESTS -- investigate" while the TOTAL line still said
    # "COMPLETE -- every plan test has a log". Both were literally true and the summary was the lie:
    # a surplus means orphan logs (a plan test was renamed or removed and its log stayed behind), and
    # nobody reading a green total goes looking for it. This is the same vacuous-success class this
    # tool was written to kill, in the tool itself.
    if ($tLogged -gt $tPlanned) {
        Emit ("  {0,-24} {1,7} {2,7} {3,6}   *** {4} ORPHAN LOG(S) -- MORE LOGS THAN PLAN TESTS ***" -f 'TOTAL', $tPlanned, $tLogged, 0, ($tLogged - $tPlanned)) 'Red'
        Emit "  A log with no plan test is not coverage: the plan changed and the log was left behind." 'Red'
        Emit "  Delete the orphan(s) or restore the plan test -- do NOT read this as complete." 'Red'
        $anyOwed = $true
    }
    elseif ($tOwed -gt 0) {
        Emit ("  {0,-24} {1,7} {2,7} {3,6}   *** {4} TEST(S) STILL OWED ***" -f 'TOTAL', $tPlanned, $tLogged, $tOwed, $tOwed) 'Yellow'
        $owedEnts = @()
        foreach ($e in $entities) {
            $planned = @($tests | Where-Object { "$($_.entity)" -eq $e }).Count
            $entDir  = Join-Path $logsRoot $e
            $lg = 0
            if (Test-Path $entDir) {
                $lg = @(Get-ChildItem $entDir -Filter '*.txt' -File -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/]_archive_' -and $_.Name.StartsWith($prefix) }).Count
            }
            if ($planned - $lg -gt 0) { $owedEnts += "$e ($($planned - $lg))" }
        }
        Emit ("  NEXT: drive + fetch -> " + ($owedEnts -join ' , ')) 'Yellow'
        Emit "  A capture that reports 'ALL n manifest entries captured' has only confirmed it drained" 'DarkGray'
        Emit "  the manifest. THIS table is what says whether the sweep actually advanced." 'DarkGray'
    } else {
        Emit ("  {0,-24} {1,7} {2,7} {3,6}   COMPLETE -- every plan test has a log" -f 'TOTAL', $tPlanned, $tLogged, 0) 'Green'
    }
}

if ($Quiet) {
    # One machine-readable line for automation / callers that only want the headline.
    if ($anyOwed) { Write-Output "SWEEP: tests still owed" } else { Write-Output "SWEEP: complete" }
}

if ($OutFile) {
    $lines | Set-Content -Path $OutFile -Encoding ASCII
    if (-not $Quiet) { Write-Host "`n  Saved: $OutFile" -ForegroundColor DarkGray }
}

exit 0
