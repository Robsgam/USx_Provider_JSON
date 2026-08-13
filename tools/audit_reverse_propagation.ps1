<#
  audit_reverse_propagation.ps1 -- portfolio status view for reverse-propagated fixes.

  Reads every provider's PENDING_UPDATES.txt (via _resolve_docs_path.ps1) + the
  repo-root REVERSE_PROPAGATION_LOG.md ledger, and cross-references them:
    * PENDING FLAGS BY FIX -- which providers currently carry each [FLAG:<id>]
      (these FAIL enforce.ps1 PHASE 1 until rebuilt).
    * LEDGER CROSS-CHECK -- for each logged fix: how many affected providers are
      still pending vs cleared; a fix with 0 pending providers is fully PROPAGATED.
    * Gaps -- pending flags with no ledger row (UNLOGGED), and unstructured legacy
      pending lines (no [FLAG:] prefix) surfaced for triage.

  Informational only -- always exits 0. enforce.ps1 PHASE 1 is the actual gate;
  this tool just gives visibility. Composed into doctor.ps1.

  Usage: .\audit_reverse_propagation.ps1 [-OutFile status.txt]
#>
param(
    [string]$OutFile
)
$ErrorActionPreference = "Stop"
$tool = $PSScriptRoot
$repo = (Resolve-Path "$tool\..").Path
$providersDir = Join-Path $repo "providers"
. "$tool\_resolve_docs_path.ps1"

$script:outputLines = @()
function Out($msg)           { $script:outputLines += $msg; Write-Host $msg }
function OutColor($msg,$col) { $script:outputLines += $msg; Write-Host $msg -ForegroundColor $col }
function Warn($msg) { OutColor "    [WARN] $msg" Yellow }
function Info($msg) { OutColor "    [INFO] $msg" Gray }
function Good($msg) { OutColor "    [ OK ] $msg" Green }

# ── 1. Scan PENDING_UPDATES across providers ──
# fixId -> @(providers) for structured [FLAG:id]; unstructured lines kept per provider.
$pendingByFix = @{}
$unstructured = @{}   # provider -> @(lines)
# INERT FLAGS -- a flag whose text is present but sits on a '#' comment line, so enforce.ps1 L207
# skips it and the provider passes PHASE 1 while believing itself flagged. Detected here because
# NOTHING else could see it: the flag LOOKS present to a human reading the file and is invisible to
# the gate. Live-caught 2026-08-13 on CA_CLETS, where flag_pending_fix appended
# [FLAG:ncic-image-default-y-everywhere] onto a file whose last line had no trailing newline,
# gluing it into a comment. The appender is fixed (Add-LineSafely), but that does not FIND damage
# already done -- this does, and it distinguishes an inert flag from a deliberately RETIRED one
# (which carries a '# RETIRED <date>' marker on the preceding line).
$inertFlags = @()     # @{Provider; FixId; Line}
$provDirs = @(Get-ChildItem $providersDir -Directory)
foreach ($pd in $provDirs) {
    $prov = $pd.Name
    $pending = Find-DocsPath $pd.FullName 'tracking' 'PENDING_UPDATES.txt'
    if (-not (Test-Path $pending)) { continue }
    # THE TEST IS POSITIONAL, NOT VOCABULARY. A first attempt excluded comment lines containing
    # RETIRED/WITHDRAWN and reported 15 "inert" flags across 8 providers -- every one a deliberate
    # '# [FLAG:x] RESOLVED at v2.2 ...' closure record. Fifteen findings across eight providers is
    # the signature of a bad probe, not a portfolio defect, and no keyword list survives contact
    # with prose (RESOLVED / CLEARED / NOT APPLICABLE / "claimed ...").
    # The GLUED bug has a structural signature instead: the append lands mid-line, so the flag has
    # PROSE BEFORE IT ('...no CAD field supplies.[FLAG:ncic-image...]'), whereas every deliberate
    # record opens its comment with the token ('# [FLAG:x]  RESOLVED ...'). So: a '#' line whose
    # [FLAG: is preceded by anything other than the leading '#' and whitespace is glued.
    foreach ($ln in @(Get-Content $pending)) {
        $t = $ln.TrimStart()
        if (-not $t.StartsWith('#')) { continue }
        if ($ln -notmatch '\[FLAG:([^\]]+)\]') { continue }
        $fid  = $Matches[1].Trim()
        # Two glue shapes, both caught:
        #   prose-before   '#  ...supplies.[FLAG:x]'  -> body does not start with the token
        #   bare-hash glue '#[FLAG:x]'                -> glued onto a lone '#' (the header's last
        #                                                line), with NO space after the hash.
        # Every deliberate record -- written by this tool or by hand -- is '# [FLAG:x] ...' WITH a
        # space. Found because the LAW 2 injection landed on a bare '#' and slipped through the
        # first version of this check.
        $body = $t.TrimStart('#').TrimStart()
        $spacedRecord = $t -match '^#\s+\[FLAG:'
        if ($body.StartsWith('[FLAG:') -and $spacedRecord) { continue }   # deliberate record
        $inertFlags += [pscustomobject]@{ Provider = $prov; FixId = $fid; Line = $ln.Trim() }
    }
    $lines = Get-Content $pending | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') }
    foreach ($ln in $lines) {
        if ($ln -match '\[FLAG:([^\]]+)\]') {
            $fid = $Matches[1].Trim()
            if (-not $pendingByFix.ContainsKey($fid)) { $pendingByFix[$fid] = @() }
            $pendingByFix[$fid] += $prov
        } else {
            if (-not $unstructured.ContainsKey($prov)) { $unstructured[$prov] = @() }
            $unstructured[$prov] += $ln.Trim()
        }
    }
}

# ── 2. Read ledger rows ──
$ledgerPath = Join-Path $repo "REVERSE_PROPAGATION_LOG.md"
$ledgerFixes = @{}   # fixId -> [ordered]@{ Description; Origin; Affected; Status }
if (Test-Path $ledgerPath) {
    foreach ($ln in (Get-Content $ledgerPath)) {
        if ($ln -notmatch '^\|') { continue }
        if ($ln -match '^\|\s*Fix ID\s*\|') { continue }       # header
        if ($ln -match '^\|\s*-+\s*\|') { continue }            # separator
        $cells = ($ln -split '\|') | ForEach-Object { $_.Trim() }
        # cells[0] is empty (leading |). Expect: '', FixId, Desc, Origin, Affected, Status
        if ($cells.Count -lt 6) { continue }
        $fid = $cells[1] -replace '^\[FLAG:', '' -replace '\]$',''
        if (-not $fid) { continue }
        $ledgerFixes[$fid] = [ordered]@{
            Description = $cells[2]; Origin = $cells[3]; Affected = $cells[4]; Status = $cells[5]
        }
    }
}

Out ""
Out "================================================================"
Out "  REVERSE-PROPAGATION STATUS"
Out "  ledger: $(if (Test-Path $ledgerPath) { 'REVERSE_PROPAGATION_LOG.md' } else { '(none yet)' })"
Out "================================================================"

# ── 3. Pending flags by fix ──
Out ""
Out "--- PENDING FLAGS BY FIX (block enforce PHASE 1 until rebuilt) ---"
if ($pendingByFix.Count -eq 0) {
    Good "no structured [FLAG:*] pending in any provider"
} else {
    foreach ($fid in ($pendingByFix.Keys | Sort-Object)) {
        $provs = @($pendingByFix[$fid] | Sort-Object -Unique)
        Info "[$fid] pending in $($provs.Count): $($provs -join ', ')"
    }
}

# ── 4. Ledger cross-check ──
Out ""
Out "--- LEDGER CROSS-CHECK ---"
if ($ledgerFixes.Count -eq 0) {
    Info "ledger has no fix rows"
} else {
    foreach ($fid in ($ledgerFixes.Keys | Sort-Object)) {
        $pendingProvs = @()
        if ($pendingByFix.ContainsKey($fid)) { $pendingProvs = @($pendingByFix[$fid] | Sort-Object -Unique) }
        if ($pendingProvs.Count -eq 0) {
            Good "[$fid] PROPAGATED -- no provider still carries the flag"
        } else {
            Warn "[$fid] $($pendingProvs.Count) pending: $($pendingProvs -join ', ')"
        }
    }
}

# ── 5. Gaps ──
Out ""
Out "--- GAPS ---"
$gaps = 0
foreach ($fid in ($pendingByFix.Keys | Sort-Object)) {
    if (-not $ledgerFixes.ContainsKey($fid)) {
        Warn "[$fid] pending in providers but has NO ledger row (add it to REVERSE_PROPAGATION_LOG.md)"
        $gaps++
    }
}
if ($unstructured.Count -gt 0) {
    foreach ($prov in ($unstructured.Keys | Sort-Object)) {
        foreach ($ln in $unstructured[$prov]) {
            Info "unstructured pending ($prov): $ln"
        }
    }
    Info "unstructured lines still block enforce -- convert to [FLAG:<id>] via flag_pending_fix.ps1 for tracking"
}
if ($gaps -eq 0 -and $unstructured.Count -eq 0) { Good "no gaps -- every pending flag is logged and structured" }

# ── INERT FLAGS ────────────────────────────────────────────────────────────────────────────────
# A flag the gate cannot see. This is NOT informational like the rest of this report: an inert flag
# is a provider that believes itself blocked and is not, so it can be tenant-tested and shipped
# with the fix still owed. It reads as done from the board and as pending from the file.
Out ""
if ($inertFlags.Count -gt 0) {
    foreach ($f in $inertFlags) {
        Warn "INERT FLAG -- $($f.Provider) carries [FLAG:$($f.FixId)] on a COMMENT line: enforce cannot see it"
        Info "    fix: move it to its own line, or retire it properly --"
        Info "    tools\flag_pending_fix.ps1 -Retire -FixId $($f.FixId) -Providers $($f.Provider) -Description '<what was done>'"
    }
} else {
    Good "no inert flags -- every flag present in a PENDING_UPDATES file is on a line enforce can see"
}

Out ""
Out "================================================================"
Out "  Fixes pending: $($pendingByFix.Count) structured + $($unstructured.Keys.Count) provider(s) with legacy lines"
Out "  Inert flags: $($inertFlags.Count)   (scanned $($provDirs.Count) provider PENDING_UPDATES files)"
Out "  (informational -- enforce.ps1 PHASE 1 is the gate)"
Out "================================================================"

if ($OutFile) {
    $script:outputLines -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8
    Write-Host "`n  Saved: $OutFile" -ForegroundColor Green
}
