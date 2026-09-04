<#
  audit_session_state.ps1 -- is SESSION_STATE.md still telling the truth?

  WHY THIS EXISTS
  ---------------
  SESSION_STATE.md is the pick-up point injected into every new session by the SessionStart hook.
  Its whole value is being TRUSTED on restart. The moment it is stale it is worse than nothing --
  it sends the next session confidently in the wrong direction.

  That is exactly what happened to the memory-file version it replaced: it accumulated dated
  sections, drifted from the repo (it was not in git, so nothing could check it), and cost Rob
  roughly an hour of re-prompting per restart on 2026-07-29.

  So the file is committed AND verified. This checks the claims that can be checked mechanically:
    1. every provider version it names matches the active JSON on disk
    2. it does not name a provider that no longer exists
    3. it is not obviously abandoned (its "Last updated" is not far behind the last commit)
    4. it has not started accumulating history again (the failure mode of its predecessor)

  It does NOT check prose. Keep the file short and current; that part is on the human (or the model).

  Usage: .\audit_session_state.ps1 [-OutFile <path>]
  Exit:  0 = consistent, 1 = stale
#>

param([string]$OutFile)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stateFile = Join-Path $repo 'SESSION_STATE.md'

$lines = @()
function Emit($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c; $script:lines += $t }

Emit "================================================================"
Emit "  SESSION_STATE.md INTEGRITY"
Emit "================================================================"

if (-not (Test-Path $stateFile)) {
    Emit "  [FAIL] SESSION_STATE.md is MISSING -- every new session starts blind." 'Red'
    Emit "         Recreate it: current gate status, per-provider test state, what is owed," 'Yellow'
    Emit "         open decisions. Derive numbers with portfolio_status.ps1 + enforce.ps1." 'Yellow'
    if ($OutFile) { [IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
    exit 1
}

$txt = Get-Content $stateFile -Raw
$fail = 0

# ── 1/2. provider versions named in the file must match the active JSON ──────────
$providersDir = Join-Path $repo 'providers'
$checked = 0
foreach ($m in [regex]::Matches($txt, '(?m)^\|\s*\*{0,2}([A-Z][A-Z_]+)\*{0,2}\s*\|\s*\*{0,2}(v[0-9]+\.[0-9]+)\*{0,2}\s*\|')) {
    $prov = $m.Groups[1].Value
    $stated = $m.Groups[2].Value
    $pDir = Join-Path $providersDir $prov
    if (-not (Test-Path $pDir)) {
        Emit "  [FAIL] names provider '$prov', which does not exist under providers/" 'Red'
        $fail++; continue
    }
    $j = Get-ChildItem $pDir -Filter "$prov`_v*.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $j) { Emit "  [INFO] $prov -- no versioned root JSON to compare"; continue }
    $actual = 'v' + [regex]::Match($j.Name, '_v([0-9]+\.[0-9]+)\.json$').Groups[1].Value
    $checked++
    if ($stated -ne $actual) {
        Emit "  [FAIL] $prov -- SESSION_STATE says $stated, active JSON is $actual" 'Red'
        $fail++
    }
}
if ($checked -gt 0 -and $fail -eq 0) { Emit "  [PASS] all $checked provider version(s) named match the active JSON" 'Green' }

# ── 3. not obviously abandoned ───────────────────────────────────────────────────
$um = [regex]::Match($txt, '(?m)\*\*Last updated:\*\*\s*([0-9]{4}-[0-9]{2}-[0-9]{2})')
if (-not $um.Success) {
    Emit "  [FAIL] no '**Last updated:** yyyy-mm-dd' line -- staleness cannot be judged" 'Red'
    $fail++
} else {
    $stamp = [datetime]::ParseExact($um.Groups[1].Value, 'yyyy-MM-dd', $null)
    $lastCommit = $null
    try { $lastCommit = [datetime]::Parse((git -C $repo log -1 --pretty=%cI 2>$null)) } catch { }
    if ($lastCommit) {
        $drift = ($lastCommit.Date - $stamp.Date).Days
        if ($drift -gt 14) {
            Emit "  [FAIL] stamped $($um.Groups[1].Value) but the last commit is $drift days newer -- stale" 'Red'
            $fail++
        } else {
            Emit "  [PASS] Last updated $($um.Groups[1].Value); last commit is $drift day(s) newer" 'Green'
        }
    }
}

# ── 4. has it started accumulating history again? ────────────────────────────────
# Its predecessor died by stacking dated sections. Length is the early-warning signal.
$lineCount = (Get-Content $stateFile).Count
if ($lineCount -gt 120) {
    Emit "  [FAIL] $lineCount lines -- it is accumulating again. REPLACE content, do not append." 'Red'
    Emit "         History belongs in git and docs/tracking/CHANGELOG_<P>.md. Target: under ~80." 'Yellow'
    $fail++
} else {
    Emit "  [PASS] $lineCount lines -- still short enough to actually be read" 'Green'
}

# ══════════════════════════════════════════════════════════════════════════════════════════════
#  SUPPRESSION CURRENCY -- is every "do not re-raise" claim still TRUE?
#
#  ADDED 2026-09-04, after a stale suppression cost a full planning cycle. SESSION_STATE said
#  "4 providers carry [FLAG:plan-dedupe-vacuous-tests] ... CORRECTLY deferred ... Not work owed"
#  while every one of those flags had been marked TAKEN AND DONE on 2026-08-31. That sentence was
#  then quoted into a documentation audit, into an adversarial agent's analysis, and into an
#  implementation plan as a HARD CONSTRAINT forbidding work that was already finished.
#
#  WHY THIS CLASS IS WORSE THAN AN ORDINARY STALE FACT, and why it needed its own check: the rest
#  of this tool verifies claims that ASSERT something (a version, a date, a line count), and a
#  wrong assertion eventually trips a gate. A DO-NOT-RE-RAISE asserts that something needs no
#  attention -- so when it rots it produces NO finding anywhere, by construction. It is the only
#  class of stale claim that gets quieter as it gets more wrong.
#
#  The check: every '[FLAG:<id>]' named in SESSION_STATE as deferred/not-owed is looked up in the
#  provider PENDING_UPDATES.txt files. If the flag's own record says TAKEN / DONE / RETIRED /
#  CLEARED, the suppression is stale -> FAIL, naming the flag. Prints its denominator; a run that
#  compares zero flags says so rather than contributing silence to a PASS.
# ══════════════════════════════════════════════════════════════════════════════════════════════
$ssText = $txt
# A line only CLAIMS a deferral if it asserts one NOW. Exclude lines that themselves record the
# flag as resolved -- otherwise the check false-positives on its own correction, which is exactly
# what happened on the first run: the corrected entry QUOTES the old wording ("correctly deferred",
# "not work owed") while explaining that it was wrong, and the naive match read the quotation as a
# live claim. A gate that cannot tell an assertion from a citation of one is not reading English,
# it is grepping.
$deferBlock = @($ssText -split "`n" | Where-Object {
    $_ -match '\[FLAG:[^\]]+\]' -and
    $_ -match '(?i)defer|not work owed|not owed|do not|correctly' -and
    $_ -notmatch '(?i)\bis DONE\b|\bTAKEN\b|\bRETIRED\b|\bCLEARED\b|used to say|previously said|corrected'
})
$flagsChecked = 0; $flagsStale = 0
foreach ($line in $deferBlock) {
    foreach ($m in [regex]::Matches($line, '\[FLAG:([^\]]+)\]')) {
        $flagId = $m.Groups[1].Value
        $flagsChecked++
        $done = @()
        foreach ($pu in (Get-ChildItem $providersDir -Directory -ErrorAction SilentlyContinue)) {
            $puFile = Join-Path $pu.FullName 'docs\tracking\PENDING_UPDATES.txt'
            if (-not (Test-Path $puFile)) { continue }
            foreach ($pl in (Get-Content $puFile)) {
                if ($pl -match [regex]::Escape($flagId) -and $pl -match '(?i)TAKEN|DONE|RETIRED|CLEARED') {
                    $done += $pu.Name
                }
            }
        }
        if ($done.Count -gt 0) {
            Emit ("  [FAIL] SUPPRESSION STALE: SESSION_STATE calls [FLAG:$flagId] deferred/not-owed, but it is recorded TAKEN/DONE on: " + (($done | Select-Object -Unique) -join ', ')) 'Red'
            $fail++; $flagsStale++
        }
    }
}
if ($flagsChecked -eq 0) {
    Emit "  [NOTE] suppression currency: 0 '[FLAG:...]' deferral claims found in SESSION_STATE -- nothing compared" 'Yellow'
} else {
    Emit "  [INFO] suppression currency: $flagsChecked deferral claim(s) checked, $flagsStale stale"
}

Emit ""
if ($fail -eq 0) { Emit "  [PASS] SESSION_STATE.md is consistent with the repo" 'Green' }
else { Emit "  [FAIL] $fail stale claim(s) -- fix SESSION_STATE.md before it misleads the next session" 'Red' }
Emit "================================================================"

if ($OutFile) {
    $d = Split-Path $OutFile -Parent
    if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [IO.File]::WriteAllText($OutFile, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
if ($fail -gt 0) { exit 1 } else { exit 0 }
