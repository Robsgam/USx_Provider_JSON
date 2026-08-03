<#
  audit_buildnotes_fidelity.ps1 -- does the BUILD_NOTES entry for the CURRENT version actually
  describe what changed, or is it the generic stub a pipeline rebuild stamps?

  WHY THIS EXISTS (2026-08-03 -- NINE hand-corrections in ONE session)
    pipeline.ps1 stamps a placeholder entry:

        v2.23  2026-07-31  Pipeline rebuild
          CHANGED: Rebuilt via pipeline.ps1
          REASON: Scheduled rebuild

    If nobody replaces it, a real wire change becomes INVISIBLE to everyone reading BUILD_NOTES as
    the source of truth -- and BUILD_NOTES is what generate_changelog renders, what the Jira
    changelog is written from, and what the next session reads to answer "what changed?".
    CA_CLETS v2.23 carries the stub above while its own commit reads "four real wire defects fixed,
    five conflicts registered with authority" and the JSON went 10096 -> 9100 lines.
    Corrected by hand nine times on 2026-08-03 (FL 4, TX 3, NY 2). Nine hand-corrections means the
    fix is not more hand-correction. Rob: "build the gate".

    Downstream cost, measured the same day: asked what FL owed Jira, I read its DEX_TICKET pointer
    and BUILD_NOTES, and answered "nine versions owed, last posted v7.8". The ticket was current
    through v7.12 and five were owed. Records that understate themselves produce confident wrong
    answers.

  THE CHECK, and why it needs no judgement
    "Scheduled rebuild" is a TRUE statement for a reproducibility rebuild that changed nothing, and
    a FALSE one for a version that changed the wire. The JSON distinguishes them MECHANICALLY:

      generic entry + JSON IDENTICAL to previous version  -> PASS  (the stub is accurate)
      generic entry + JSON DIFFERS from previous version   -> FAIL  (a real change is hidden)
      specific entry                                       -> PASS  (nothing to check)

    Previous-version JSON comes from git: the commit that ADDS <P>_v<cur>.json also DELETES
    <P>_v<prev>.json (Write-ProviderJson removes the stale sibling), so both blobs are reachable
    from that one commit. Compared with version strings normalised away, since a pure rebuild
    legitimately rewrites the version inside the bundle descriptions.

  STRUCTURAL MATCH, NOT SUBSTRING -- this bit me while measuring the baseline
    A naive grep for "Rebuilt via pipeline" / "Scheduled rebuild" anywhere in the entry block
    reported NY_NYSPIN_EJUSTICE as generic, because the note I had just written to DOCUMENT the fix
    QUOTES the stub it replaced. The gate would have flagged exactly the providers that were
    repaired. So a stub is recognised only when the CHANGED / REASON values are NOTHING BUT the
    placeholder phrase.

  BASELINE 2026-08-03: 20 providers / 14 GENERIC entries / 14 comparisons / 14 FAIL / 0 not-comparable.
    NOT ONE generic entry was a true no-op. "Scheduled rebuild" has never been an accurate statement
    in this repo -- every stub concealed real work (CA_CLETS "four real wire defects fixed",
    CA_eSUN "55 devdoc-optional FAILs traced to ONE envelope field", CA_SAN_LUIS_OBISPO "cap the DL
    OLN control at 17", TX_TLETS_CCH "17 dropped optionals fixed", ...).
    The six providers that PASS do so because their entries were hand-written -- five of them by hand
    THE SAME DAY this gate was built, which is why the gate was built.

  BRANCH COVERAGE, stated honestly (LAW 2)
    FAIL  (generic + JSON changed)   -- proven 14x on real data.
    PASS  (entry is not a stub)      -- proven 6x on real data.
    PASS  (generic + JSON identical) -- **UNEXERCISED**. No version pair in this repo is a true
          no-op, so the exemption path has never fired. If it is wrong the gate OVER-reports, which
          is the safe direction, but do not claim it is verified.

  NOT WIRED INTO enforce YET, deliberately: it would turn 14 of 20 providers red at once. Wire it
  after the 14 entries are repaired so it lands at ZERO and acts as a regression guard -- the same
  sequencing used for audit_registry_currency. Composed into doctor.ps1 now so the count is visible.

  Usage:
    .\audit_buildnotes_fidelity.ps1 -Provider CA_CLETS
    .\audit_buildnotes_fidelity.ps1 -All [-Quiet] [-OutFile <path>]
#>

param(
    [string]$Provider,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $toolDir '..')).Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_resolve_docs_path.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') {
    $script:lines += $s
    if (-not $Quiet) { Write-Host $s -ForegroundColor $c }
}

# A stub is recognised ONLY when the value is nothing but the placeholder. See header.
function Test-GenericEntry([string]$block) {
    $changedGeneric = $false; $reasonGeneric = $false
    foreach ($ln in ($block -split "`r?`n")) {
        if ($ln -match '^\s*CHANGED:\s*(.+?)\s*$') {
            $v = $Matches[1]
            if ($v -match '^Rebuilt via pipeline(\.ps1)?\.?$') { $changedGeneric = $true }
        }
        if ($ln -match '^\s*REASON:\s*(.+?)\s*$') {
            $v = $Matches[1]
            if ($v -match '^Scheduled rebuild\.?$') { $reasonGeneric = $true }
        }
    }
    return ($changedGeneric -and $reasonGeneric)
}

function Get-EntryBlock([string]$notesText, [string]$ver) {
    $esc = [regex]::Escape($ver)
    # from the version header line up to the next version header (or end)
    $m = [regex]::Match($notesText, "(?ms)^v$esc\s.*?(?=^v\d|\z)")
    if ($m.Success) { return $m.Value }
    return $null
}

function Normalize-Json([string]$text) {
    # a pure rebuild legitimately rewrites the version inside bundle descriptions
    return (($text -replace 'v\d+\.\d+', 'vX') -replace '\s+', ' ')
}

function Invoke-One([string]$p) {
    $pd = Join-Path $repoRoot "providers\$p"
    if (-not (Test-Path $pd)) { return $null }
    $jp = Get-ProviderRootJson -ProvDir $pd -Provider $p
    if (-not $jp) { Out-Line "  [FAIL] $p -- no active JSON resolved; verdict WITHHELD" 'Red'; return @{ Fail = 1; Checked = 0; Generic = 0; Compared = 0; NotComparable = 0 } }

    $ver = [IO.Path]::GetFileNameWithoutExtension($jp) -replace "^$([regex]::Escape($p))_v", ''
    $notes = Find-DocsPath $pd 'tracking' "${p}_BUILD_NOTES.txt"
    if (-not $notes -or -not (Test-Path $notes)) {
        Out-Line "  [FAIL] $p -- no BUILD_NOTES found; verdict WITHHELD (not a pass)" 'Red'
        return @{ Fail = 1; Checked = 0; Generic = 0; Compared = 0; NotComparable = 0 }
    }

    $text  = [IO.File]::ReadAllText($notes)
    $block = Get-EntryBlock $text $ver
    if (-not $block) {
        Out-Line "  [FAIL] $p -- BUILD_NOTES has NO entry for the current version v$ver" 'Red'
        return @{ Fail = 1; Checked = 1; Generic = 0; Compared = 0; NotComparable = 0 }
    }

    if (-not (Test-GenericEntry $block)) {
        Out-Line "  [PASS] $p v$ver -- entry describes the change (not a stub)" 'Green'
        return @{ Fail = 0; Checked = 1; Generic = 0; Compared = 0; NotComparable = 0 }
    }

    # generic -- so the JSON must be unchanged for it to be TRUE
    $relCur = "providers/$p/" + [IO.Path]::GetFileName($jp)
    $sha = (& git -C $repoRoot log --diff-filter=A --format=%H -1 -- $relCur 2>$null | Select-Object -First 1)
    if (-not $sha) {
        Out-Line "  [NOTE] $p v$ver -- GENERIC entry, but the adding commit could not be found: NOT COMPARABLE (not evidence either way)" 'DarkYellow'
        return @{ Fail = 0; Checked = 1; Generic = 1; Compared = 0; NotComparable = 1 }
    }

    # The same commit removes the previous versioned JSON -- but git may record that as a DELETE or,
    # far more often, as a RENAME: 'R096  <old>.json  <new>.json' (a version bump rewrites one file
    # under a new name, so rename detection fires on the high similarity).
    # PARSING ONLY 'D' WAS MY BUG: it made 11 of 14 generic entries read NOT COMPARABLE, i.e. the
    # gate silently declined to judge the majority of the very cases it was built for. A weak
    # denominator is indistinguishable from a clean run -- always print it, then go and fix it.
    $stat = & git -C $repoRoot show --name-status --format='' $sha -- "providers/$p/" 2>$null
    $prevRel = $null
    $pe = [regex]::Escape($p)
    # Predecessor names: versioned (<P>_vX.Y.json) OR the legacy pre-galvanization roots
    # (<P>_MC.json / <P>_BASE.json / bare <P>.json). The three providers whose v2.0/v3.0 IS the
    # galvanization rebuild renamed <P>_MC.json -> <P>_v2.0.json, and excluding those left 3 of 14
    # generic entries unjudged -- a gate that declines a fifth of its own cases has a blind spot,
    # not a clean run.
    $prevPat = "(providers/$pe/(?:${pe}_v[0-9.]+|${pe}_MC|${pe}_BASE|$pe)\.json)"
    foreach ($l in @($stat)) {
        if ($l -match "^D\s+$prevPat")                              { $prevRel = $Matches[1] }
        elseif ($l -match "^R\d*\s+$prevPat\s+providers/$pe/")      { $prevRel = $Matches[1] }
    }
    if (-not $prevRel) {
        Out-Line "  [NOTE] $p v$ver -- GENERIC entry; no predecessor JSON deleted in $($sha.Substring(0,8)) (first version, or renamed): NOT COMPARABLE" 'DarkYellow'
        return @{ Fail = 0; Checked = 1; Generic = 1; Compared = 0; NotComparable = 1 }
    }

    $curTxt  = (& git -C $repoRoot show "${sha}:$relCur"  2>$null) -join "`n"
    $prevTxt = (& git -C $repoRoot show "${sha}^:$prevRel" 2>$null) -join "`n"
    if (-not $curTxt -or -not $prevTxt) {
        Out-Line "  [NOTE] $p v$ver -- GENERIC entry; could not read both blobs: NOT COMPARABLE" 'DarkYellow'
        return @{ Fail = 0; Checked = 1; Generic = 1; Compared = 0; NotComparable = 1 }
    }

    $prevVer = [IO.Path]::GetFileNameWithoutExtension($prevRel) -replace "^$([regex]::Escape($p))_v", ''
    if ((Normalize-Json $curTxt) -eq (Normalize-Json $prevTxt)) {
        Out-Line "  [PASS] $p v$ver -- generic entry is TRUE: JSON byte-identical to v$prevVer (pure rebuild)" 'Green'
        return @{ Fail = 0; Checked = 1; Generic = 1; Compared = 1; NotComparable = 0 }
    }

    $subj = (& git -C $repoRoot log -1 --format=%s $sha 2>$null)
    Out-Line "  [FAIL] $p v$ver -- GENERIC entry but the JSON CHANGED vs v$prevVer. A real change is hidden." 'Red'
    Out-Line "         BUILD_NOTES says: 'Rebuilt via pipeline.ps1 / Scheduled rebuild'" 'Red'
    Out-Line "         the commit says:  '$subj' ($($sha.Substring(0,8)))" 'Red'
    Out-Line "         FIX: replace the entry with what actually changed (recover it from that commit body)." 'Red'
    return @{ Fail = 1; Checked = 1; Generic = 1; Compared = 1; NotComparable = 0 }
}

Out-Line ''
Out-Line '===================================================================================='
Out-Line '  BUILD_NOTES FIDELITY -- is the current version''s entry a stub hiding a real change?'
Out-Line '  generic + JSON identical  = PASS (true statement)'
Out-Line '  generic + JSON CHANGED    = FAIL (a wire change recorded as a no-op)'
Out-Line '===================================================================================='
Out-Line ''

$targets = @()
if ($All) { $targets = Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Select-Object -ExpandProperty Name | Sort-Object }
elseif ($Provider) { $targets = @($Provider) }
else { Write-Host 'Specify -Provider <NAME> or -All' -ForegroundColor Yellow; exit 2 }

$tF = 0; $tC = 0; $tG = 0; $tCmp = 0; $tNC = 0
foreach ($p in $targets) {
    $r = Invoke-One $p
    if (-not $r) { continue }
    $tF += $r.Fail; $tC += $r.Checked; $tG += $r.Generic; $tCmp += $r.Compared; $tNC += $r.NotComparable
}

Out-Line ''
Out-Line '------------------------------------------------------------------------------------'
Out-Line "  TOTALS: $tC provider(s) checked / $tG GENERIC entr(ies) / $tCmp JSON comparison(s) made"
Out-Line "          $tF FAIL / $tNC not-comparable"
if ($tC -eq 0) { Out-Line '  [FAIL] checked ZERO providers -- this run is not evidence.' 'Red'; $tF = [Math]::Max($tF,1) }
elseif ($tF -eq 0) { Out-Line '  Every current-version entry either describes its change or is a TRUE no-op.' 'Green' }
Out-Line '------------------------------------------------------------------------------------'
Out-Line ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
if ($tF -gt 0) { exit 1 } else { exit 0 }
