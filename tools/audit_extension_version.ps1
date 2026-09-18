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

# ⚠️ THE CONSOLE BANNER IS NOT THE EXTENSION'S VERSION. THIS GATE WATCHED ONLY BANNERS UNTIL
# 2026-09-18, AND THAT IS THE THIRD TIME ROB HAS HAD TO SAY THE SAME SENTENCE.
# 2026-09-16 "next time advance the extnsion version every time you make a change" -> banner gate
# built. 2026-09-17 "the extension is not advancing the version like i asked" -> per-file banner
# check added. 2026-09-18 "still no version bump on extension   this is getting tiring havig to
# rpeat what are global instructions" -- and he was right a third time: manifest.json still read
# 0.8.0, untouched for weeks, while THIS GATE REPORTED PASS on a bump of three console strings.
# manifest.json's `version` is what the browser's extensions page shows and what an operator means
# by "the extension version"; a console banner is an in-page announcement we invented. Both matter
# and they answer different questions, so BOTH are gated now. A gate that passes while the thing it
# is named after stands still is the LAW 2 failure happening inside the gate itself.
$mfRel = 'automation/extension/manifest.json'
$mfAbs = Join-Path $repo 'automation\extension\manifest.json'
$MFRX  = '("version"\s*:\s*")([0-9]+\.[0-9]+\.[0-9]+)(")'
function Get-MfVersion([string]$text) {
    if (-not $text) { return $null }
    $m = [regex]::Match($text, $MFRX)
    if ($m.Success) { return $m.Groups[2].Value }
    return $null
}

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

# ⚠️ EVERY SCRIPT ANNOUNCES ITS OWN BUILD, AND THIS GATE USED TO WATCH ONLY ONE (fixed 2026-09-17).
# It keyed solely on ui.js's "control panel injected. BUILD <stamp>". So on 2026-09-17 driver.js was
# CHANGED TWICE -- the textarea fill fix and the off-form skip -- while its own banner still said
# "driver ready. BUILD 2026-09-02c", and this gate PASSED both commits. Rob read the console and
# said it plainly: "the extension is not advancing the version like i asked". The gate's own
# rationale is that a stale extension and a broken one must not look identical; that was true of
# driver.js specifically, inside the gate meant to prevent it.
# Each entry is the file's LIVE console banner -- the line an operator actually reads on load.
# A file with no banner is reported, never silently skipped (see the [WARN] below).
$BANNERS = [ordered]@{
    'automation/extension/ui.js'           = 'control panel injected\.\s*BUILD\s+(\S+?)[\s)]'
    'automation/extension/driver.js'       = 'driver ready\.\s*BUILD\s+(\S+?)[\s)]'
    'automation/extension/usx_lib.js'      = 'usx_lib loaded\.\s*BUILD\s+(\S+?)[\s)]'
    'automation/extension/deploy_probe.js' = 'deploy_probe loaded[^\r\n]*?BUILD\s+(\S+?)[\s)]'
    'automation/extension/admin_probe.js'  = 'admin_probe[^\r\n]*?BUILD\s+(\S+?)[\s)]'
}
function Get-FileBuild([string]$text, [string]$rx) {
    if (-not $text) { return $null }
    $m = [regex]::Match($text, $rx)
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
    Emit ("  BUMPED: {0} -> {1}  ({2} occurrence(s) replaced)  [ui.js]" -f $tok, $newTok,
          ([regex]::Matches($cur, [regex]::Escape($tok))).Count)

    # EVERY OTHER BANNERED SCRIPT GETS THE SAME STAMP. One stamp to look for across the whole
    # extension is the point -- per-file stamps drifting apart is how driver.js ended up three
    # weeks behind ui.js while this tool reported PASS. Replaces that file's OWN token only.
    foreach ($rel in $BANNERS.Keys) {
        if ($rel -eq $uiRel) { continue }
        $abs = Join-Path $repo $rel
        if (-not (Test-Path $abs)) { continue }
        $txt = [System.IO.File]::ReadAllText($abs)
        $own = Get-FileBuild $txt $BANNERS[$rel]
        if (-not $own) { Emit ("  [WARN] {0} has no live BUILD banner -- cannot stamp it." -f $rel); continue }
        if ($own -ceq $newTok) { Emit ("  already {0}: {1}" -f $newTok, $rel); continue }
        [System.IO.File]::WriteAllText($abs, $txt.Replace($own, $newTok), (New-Object System.Text.UTF8Encoding($false)))
        Emit ("  BUMPED: {0} -> {1}  [{2}]" -f $own, $newTok, $rel)
    }

    # THE PACKAGED VERSION -- the number the browser shows. Patch bump, surgical regex replace so
    # the manifest's formatting is untouched (a ConvertTo-Json round-trip would reflow the whole
    # file and bury the one line that changed).
    if (Test-Path $mfAbs) {
        $mfTxt = [System.IO.File]::ReadAllText($mfAbs)
        $mfCur = Get-MfVersion $mfTxt
        if (-not $mfCur) {
            Emit '  [WARN] manifest.json has no x.y.z version -- refusing to invent one.'
        } else {
            $pp = $mfCur.Split('.')
            $mfNew = "{0}.{1}.{2}" -f $pp[0], $pp[1], ([int]$pp[2] + 1)
            $mfOut = [regex]::Replace($mfTxt, $MFRX, ('${1}' + $mfNew + '${3}'), 1)
            [System.IO.File]::WriteAllText($mfAbs, $mfOut, (New-Object System.Text.UTF8Encoding($false)))
            Emit ("  BUMPED: {0} -> {1}  [manifest.json -- the version the BROWSER shows]" -f $mfCur, $mfNew)
        }
    }
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
    # ANY file under automation/extension/ -- not just .js. A changed content script, HTML page or
    # icon still ships as a new extension and still needs the browser-visible version to move.
    $extAny     = @($changed | Where-Object { $_ -match '^automation/extension/' })
    $headTok  = if ($headText) { Get-LiveBuild $headText } else { $null }
    $workTok  = Get-LiveBuild ([System.IO.File]::ReadAllText($uiAbs))
    $mfHeadTxt = ((& git show ("HEAD:" + $mfRel) 2>&1) | ForEach-Object { "$_" }) -join "`n"
    if ($mfHeadTxt -match '^fatal:') { $mfHeadTxt = '' }
    $mfHead = Get-MfVersion $mfHeadTxt
    $mfWork = if (Test-Path $mfAbs) { Get-MfVersion ([System.IO.File]::ReadAllText($mfAbs)) } else { $null }
} finally { Pop-Location }

Emit ("  mode          : {0}" -f $(if ($Staged) { 'STAGED vs HEAD' } else { 'working tree vs HEAD' }))
Emit ("  extension .js changed: {0}" -f $extChanged.Count)
foreach ($f in $extChanged) { Emit ("      {0}" -f $f) }
Emit ("  BUILD at HEAD : {0}" -f $(if ($headTok) { $headTok } else { '(none -- no HEAD copy)' }))
Emit ("  BUILD now     : {0}" -f $(if ($workTok) { $workTok } else { '(none)' }))
Emit ("  extension files changed (any type): {0}" -f $extAny.Count)
Emit ("  manifest.json version: HEAD {0} -> now {1}" -f $(if ($mfHead) { $mfHead } else { '(none)' }),
                                                        $(if ($mfWork) { $mfWork } else { '(none)' }))

# ── THE PACKAGED VERSION. CHECKED FIRST, so no later early-PASS can skip it. ─────────────────────
# This is the check whose absence let three console-string bumps report PASS while manifest.json
# sat at 0.8.0. It runs before the "no .js changed" and "no HEAD copy" shortcuts on purpose.
if ($extAny.Count -gt 0) {
    if (-not $mfWork) {
        Emit ''
        Emit "  [FAIL] $mfRel has no x.y.z version -- the browser-visible extension version cannot be read."
        Done 1
    }
    if ($mfHead -and ($mfWork -ceq $mfHead)) {
        Emit ''
        Emit ("  [FAIL] {0} extension file(s) changed but manifest.json version is still '{1}'." -f $extAny.Count, $mfWork)
        Emit '         THIS IS THE VERSION THE BROWSER SHOWS, and it is what "advance the extension'
        Emit '         version" means. A console banner is an in-page announcement we invented; the'
        Emit '         manifest version is the one an operator can check without opening DevTools.'
        Emit '         FIX:  tools\audit_extension_version.ps1 -Bump'
        Done 1
    }
    Emit ("  [PASS] manifest.json version advanced {0} -> {1}." -f $(if ($mfHead) { $mfHead } else { '(none)' }), $mfWork)
}

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
Emit ("  [PASS] ui.js BUILD advanced {0} -> {1}." -f $headTok, $workTok)

# ── PER-FILE BANNER CHECK (2026-09-17) ───────────────────────────────────────────────────────────
# ui.js advancing says nothing about the file that actually changed. Any CHANGED script carrying
# its own banner must have advanced its own stamp too, or an operator reading that script's load
# line cannot tell a reloaded extension from a stale one. This is the hole Rob caught.
$stale = @(); $unbannered = @()
Push-Location $repo
try {
    $prevEA2 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        foreach ($rel in $extChanged) {
            if (-not $BANNERS.Contains($rel)) { $unbannered += $rel; continue }
            $rx  = $BANNERS[$rel]
            $abs = Join-Path $repo $rel
            $wTok = Get-FileBuild ([System.IO.File]::ReadAllText($abs)) $rx
            $hTxt = ((& git show ("HEAD:" + $rel) 2>&1) | ForEach-Object { "$_" }) -join "`n"
            if ($hTxt -match '^fatal:') { $hTxt = '' }
            $hTok = Get-FileBuild $hTxt $rx
            if (-not $wTok) { $unbannered += $rel; continue }
            Emit ("  {0,-38} {1} -> {2}" -f $rel, $(if ($hTok) { $hTok } else { '(none)' }), $wTok)
            if ($hTok -and ($wTok -ceq $hTok)) { $stale += $rel }
        }
    } finally { $ErrorActionPreference = $prevEA2 }
} finally { Pop-Location }

foreach ($u in $unbannered) {
    Emit ("  [WARN] {0} changed but announces no BUILD -- its reload cannot be verified from the console." -f $u)
}
if ($stale.Count -gt 0) {
    Emit ''
    Emit ("  [FAIL] {0} changed file(s) did NOT advance their OWN BUILD banner:" -f $stale.Count)
    foreach ($s in $stale) { Emit ("         {0}" -f $s) }
    Emit '         ui.js advancing is not enough -- the operator reads the banner of the script that'
    Emit '         changed. driver.js sat at 2026-09-02c through two behaviour changes on 2026-09-17'
    Emit '         while this gate reported PASS; that is the defect this check closes.'
    Emit '         FIX:  tools\audit_extension_version.ps1 -Bump   (stamps every bannered script)'
    Done 1
}
Emit ("  [PASS] all {0} changed bannered script(s) advanced their own BUILD." -f
      @($extChanged | Where-Object { $BANNERS.Contains($_) }).Count)
Done 0
