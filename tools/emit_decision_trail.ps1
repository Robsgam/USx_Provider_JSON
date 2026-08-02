<#
  emit_decision_trail.ps1 -- the REASONING pointer for a restarted session.

  WHY THIS EXISTS (Rob 2026-08-02: "i am not convinced the resume skill has the desired effect of a
  continuous stream of thought"):
    SESSION_STATE.md restores STATE -- versions, what is owed, open decisions. usx-resume restores
    ENVIRONMENT -- stray watchers, stranded captures, half-applied bumps. Between them a new session
    knows WHERE things stand. Neither restores JUDGEMENT, and judgement is what a long session
    actually accumulates.

    On 2026-08-02 the two most valuable outputs of the day were near-misses: a complete fix drafted
    for OH_LEADS that the per-combination <Requirements> then killed, and a CA_SAN_LUIS_OBISPO
    warning nearly "fixed" in the gate when the gate was right and the build was wrong. Both were
    written down -- in COMMIT MESSAGES, which nothing reads at startup. The richest record in the
    repo was the one record no session ever opened.

    This does not duplicate git (memory rule: never restate what git already records). It prints an
    INDEX plus the lesson lines, and tells the reader to go read the bodies.

  WHY NOT PUT IT IN SESSION_STATE.md:
    That file is capped (~120 lines, gated by audit_session_state) and is deliberately CURRENT STATE
    ONLY -- "no history, no changelog". A decision trail is history by definition, so it belongs in
    its own injection, derived fresh from git every time, never hand-maintained and never stale.

  Usage: .\emit_decision_trail.ps1 [-Count 14] [-Lessons 8]
#>

param(
    [int]$Count   = 14,   # commit subjects to index
    [int]$Lessons = 8     # lesson lines to surface verbatim
)

$ErrorActionPreference = 'SilentlyContinue'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Cues that actually occur in this repo's commit bodies. Deliberately a SMALL list of explicit
# self-correction / adjudication markers rather than a general summariser: the goal is to carry
# forward the things that were learned the hard way, not to restate what was done.
$cues = @(
    'THE LESSON', 'PROCESS NOTE', 'HONEST ABOUT', 'HOW I CHECKED', 'WHY I TRUST',
    'GOT THE .* WRONG', 'GOT .* BACKWARDS', 'was wrong', 'NEARLY', 'almost got',
    'HONEST CAVEAT', 'DELIBERATELY NOT', 'a fix I drafted'
)
$cueRx = '(?i)(' + (($cues | ForEach-Object { $_ }) -join '|') + ')'

Write-Output "=== USx DECISION TRAIL (derived from git -- the reasoning lives in the commit BODIES) ==="

$subjects = & git -C $repoRoot log --no-merges --pretty=format:'%ad|%s' --date=short -n $Count 2>$null
if (-not $subjects) {
    Write-Output "  (no git history readable -- run: git -C `"$repoRoot`" log -n 20)"
    return
}

Write-Output ""
Write-Output "-- last $Count commits --"
foreach ($line in $subjects) {
    $parts = $line -split '\|', 2
    $d = $parts[0]; $s = $parts[1]
    if ($s.Length -gt 96) { $s = $s.Substring(0, 93) + '...' }
    Write-Output ("   {0}  {1}" -f $d, $s)
}

# Lesson lines: scan bodies of a wider window than the subject index, newest first, de-duplicated.
$bodies = & git -C $repoRoot log --no-merges --pretty=format:'%H%n%b%n<<<END>>>' -n ([Math]::Max($Count, 30)) 2>$null
$lines = @($bodies -split "`n" | ForEach-Object { "$_".TrimEnd() })
$hits = New-Object System.Collections.Generic.List[string]
$seen = @{}
for ($i = 0; $i -lt $lines.Count; $i++) {
    $t = $lines[$i].Trim()
    if (-not $t -or $t -eq '<<<END>>>') { continue }
    if ($t -notmatch $cueRx) { continue }
    if ($t -match '^Co-Authored-By|^Claude-Session') { continue }
    # Skip CONTINUATION lines. A cue can land in the middle of a wrapped sentence, and starting the
    # quote there produces a fragment like "back to 9, over-broad still 0. The lesson is..." which
    # reads as a non sequitur. A real sentence start is capitalised or opens a clause.
    if ($t -cmatch '^[a-z]') { continue }
    # Require the cue to sit near the START of the thought, not trailing off the end of one.
    if ($t -match $cueRx -and $Matches[0]) {
        $pos = $t.IndexOf($Matches[0], [StringComparison]::OrdinalIgnoreCase)
        if ($pos -gt 60) { continue }
    }

    # Commit bodies are HARD-WRAPPED, so the cue line alone stops mid-thought -- the first version
    # of this emitted "GOT THE REGISTRATION WRONG FIRST, and only measuring caught it. The initial
    # row named the BUILT" and stopped, which is worse than useless: it names a mistake without the
    # correction. Pull following lines until the thought closes on sentence punctuation, or the
    # paragraph ends, or the budget runs out.
    $buf = $t
    $j = $i + 1
    while ($j -lt $lines.Count -and $buf.Length -lt 260) {
        $nxt = $lines[$j].Trim()
        if (-not $nxt -or $nxt -eq '<<<END>>>') { break }
        if ($nxt -match '^Co-Authored-By|^Claude-Session') { break }
        if ($buf -match '[.!?]$' -and $buf.Length -gt 150) { break }
        $buf = "$buf $nxt"
        $j++
    }
    if ($buf.Length -gt 300) { $buf = $buf.Substring(0, 297) + '...' }
    $k = ($buf.Substring(0, [Math]::Min(60, $buf.Length))).ToLower()
    if ($seen.ContainsKey($k)) { continue }
    $seen[$k] = $true
    $hits.Add($buf) | Out-Null
    $i = $j - 1
    if ($hits.Count -ge $Lessons) { break }
}

if ($hits.Count) {
    Write-Output ""
    Write-Output "-- hard-won, from those commit bodies (each one cost real time) --"
    foreach ($h in $hits) { Write-Output ("   * {0}" -f $h) }
}

Write-Output ""
Write-Output "READ THE BODIES BEFORE CONCLUDING ANYTHING IS NEW:  git log -n 25"
Write-Output "A finding that looks novel is often one already adjudicated, with the evidence in the"
Write-Output "commit that closed it. The standing rules live in .claude/skills/ (usx-metadata,"
Write-Output "usx-tooling, usx-build); this is the running record of how they were learned."
