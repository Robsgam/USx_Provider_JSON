<#
  audit_extension_version.ps1 -- IF THE EXTENSION CHANGED, ITS BUILD STRING MUST CHANGE.

  WHY THIS EXISTS. Rob, 2026-09-16: "next time advance the extnsion version every time you make a
  change wso we can track it better."

  He is asking for it because I have been inconsistent about it in a way that WASTED HIS TIME. The
  extension is reloaded by hand in the browser, so the BUILD string printed to the console is the
  ONLY way to tell "my fix is live" from "the reload silently did not take". ui.js says so in its
  own banner -- "READ THIS LINE FIRST IF A BUTTON SEEMS MISSING" -- and on 2026-09-16 I shipped a
  DEPLOY-button fix and did not bump it, so there was no way to distinguish a stale extension from
  a broken one. That is the whole cost: a debugging session with one unnecessary unknown in it.

  WHY A GATE AND NOT A NOTE. This repo has already concluded, more than once, that advice without a
  mechanism does not change behaviour (usx-tooling Step 8: the probe rules were READ and then
  broken the same session; the same reasoning produced the flag system and the pre-commit hook).
  I had bumped this string correctly on 09-15 and then not on 09-16 -- the knowledge was present
  and the habit was the defect, which is exactly the case a gate is for.

  WHAT IT CHECKS. If any automation/extension/*.js differs from HEAD, then the LIVE BUILD token in
  ui.js must also differ from HEAD.
    !! IT KEYS ON THE LIVE TOKEN ONLY. ui.js contains SEVERAL "BUILD <stamp>" strings -- the banner
    carries retired ones as prose history (2026-09-02b, 2026-09-11h, ...). A naive grep matches
    those too and would compare the wrong one, so the pattern is anchored to the one line that is
    actually printed: "control panel injected. BUILD <stamp>".

  -Bump advances it: same day -> next letter (a -> b -> c), new day -> today + 'a'. So the fix for
  a failure is one command, which is the difference between a gate people satisfy and a gate people
  bypass.

  Usage:
    .\tools\audit_extension_version.ps1            # working tree vs HEAD
    .\tools\audit_extension_version.ps1 -Staged    # staged vs HEAD (the pre-commit mode)
    .\tools\audit_extension_version.ps1 -Bump      # advance the token, then re-check
#>
[CmdletBinding()]
param([switch]$Staged, [switch]$Bump, [string]$OutFile, [switch]$Quiet)

$ErrorActionPreference = 'Stop'
$repo  = Split-Path -Parent $PSScriptRoot
$uiRel = 'automation/extension/ui.js'
$uiAbs = Join-Path $repo 'automation\extension\ui.js'

$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$s) { $lines.Add($s) | Out-Null; if (-not $Quiet) { Write-Host $s } }
function Done([int]$code) {
    if ($OutFile) { [System.IO.File]::WriteAllText($OutFile, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false))) }
    exit $code
}

# The LIVE token, not the retired ones kept as banner history.
$RX = 'control panel injected\.\s*BUILD\s+(\S+?)\s'
function Get-LiveBuild([string]$text) {
    $m = [regex]::Match($text, $RX)
    if ($m.Success) { return $m.Groups[1].Value.TrimEnd('.', ',', '-') }
    return $null
}

Emit ''
Emit '===================================================================================='
Emit '  EXTENSION VERSION GATE -- a changed extension must announce a new BUILD'
Emit '===================================================================================='

if (-not (Test-Path $uiAbs)) { Emit "  [FAIL] $uiRel not found"; Done 1 }

if ($Bump) {
    $cur = [System.IO.File]::ReadAllText($uiAbs)
    $tok = Get-LiveBuild $cur
    if (-not $tok) { Emit '  [FAIL] no live BUILD token found -- refusing to invent one.'; Done 1 }
    $today = (Get-Date).ToString('yyyy-MM-dd')
    if ($tok -match '^(\d{4}-\d{2}-\d{2})([a-z]?)$') {
        $d = $Matches[1]; $sfx = $Matches[2]
        if ($d -eq $today) {
            $next = if ($sfx) { [char]([int][char]$sfx + 1) } else { 'b' }
            $newTok = "$today$next"
        } else { $newTok = "${today}a" }
    } else { $newTok = "${today}a" }
    # Replace EVERY occurrence of the old token: the banner names it twice (the injected line and
    # the "if the console does not say X" instruction), and updating only one makes the instruction
    # tell the operator to look for a stamp that no longer exists.
    $updated = $cur.Replace($tok, $newTok)
    [System.IO.File]::WriteAllText($uiAbs, $updated, (New-Object System.Text.UTF8Encoding($false)))
    Emit ("  BUMPED: {0} -> {1}  ({2} occurrence(s) replaced)" -f $tok, $newTok,
          ([regex]::Matches($cur, [regex]::Escape($tok))).Count)
}

# what changed?
Push-Location $repo
try {
    # ⚠️ git WRITES TO STDERR ON SUCCESS ("warning: LF will be replaced by CRLF...") and under
    # $ErrorActionPreference='Stop' that noise becomes a TERMINATING NativeCommandError -- this gate
    # died on a CLEAN tree with "NotSpecified: (warning: in the... Git touches it)". Same class as
    # the Edge-stderr trap audit_extension_syntax.ps1 already documents, different executable.
    # Relax the preference for the native calls only, and merge stderr so it cannot become an error
    # record at all.
    $prevEA = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $diffArgs = if ($Staged) { @('diff', '--cached', '--name-only', '--diff-filter=ACM') }
                    else         { @('diff', 'HEAD', '--name-only', '--diff-filter=ACM') }
        $changed = @((& git @diffArgs 2>&1) | ForEach-Object { "$_" } |
                     Where-Object { $_ -notmatch '^warning:' -and $_.Trim() })
        $headText = ((& git show ("HEAD:" + $uiRel) 2>&1) | ForEach-Object { "$_" }) -join "`n"
        if ($headText -match '^fatal:') { $headText = '' }
    } finally { $ErrorActionPreference = $prevEA }
    $extChanged = @($changed | Where-Object { $_ -match '^automation/extension/.*\.js$' })
    $headTok  = if ($headText) { Get-LiveBuild $headText } else { $null }
    $workTok  = Get-LiveBuild ([System.IO.File]::ReadAllText($uiAbs))
} finally { Pop-Location }

Emit ("  mode          : {0}" -f $(if ($Staged) { 'STAGED vs HEAD' } else { 'working tree vs HEAD' }))
Emit ("  extension .js changed: {0}" -f $extChanged.Count)
foreach ($f in $extChanged) { Emit ("      {0}" -f $f) }
Emit ("  BUILD at HEAD : {0}" -f $(if ($headTok) { $headTok } else { '(none -- no HEAD copy)' }))
Emit ("  BUILD now     : {0}" -f $(if ($workTok) { $workTok } else { '(none)' }))

if (-not $workTok) {
    Emit '  [FAIL] no live BUILD token in ui.js. The console banner is the only way an operator can'
    Emit '         tell a stale extension from a broken one -- it must exist.'
    Done 1
}
if ($extChanged.Count -eq 0) {
    Emit '  [PASS] no extension JS changed -- nothing to announce.'
    Done 0
}
if (-not $headTok) {
    Emit '  [PASS] no HEAD copy of ui.js to compare against (first commit of it).'
    Done 0
}
if ($workTok -ceq $headTok) {
    Emit ''
    Emit ("  [FAIL] {0} extension file(s) changed but BUILD is still '{1}'." -f $extChanged.Count, $workTok)
    Emit '         The extension is reloaded BY HAND, so this string is the only signal that the'
    Emit '         reload took. Shipping a change without bumping it means a stale extension and a'
    Emit '         broken one look identical -- which is exactly the unnecessary unknown that cost'
    Emit '         time on the SC_SLED deploy button.'
    Emit '         FIX:  tools\audit_extension_version.ps1 -Bump'
    Done 1
}
Emit ''
Emit ("  [PASS] extension changed and BUILD advanced {0} -> {1}." -f $headTok, $workTok)
Done 0
