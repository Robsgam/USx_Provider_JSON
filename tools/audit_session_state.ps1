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
