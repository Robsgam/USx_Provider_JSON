<#
  audit_lifecycle.ps1 -- the END of the lifecycle: is this version's Jira entry filed, and is it
  recorded WHERE the JSON was imported?

  WHY THIS EXISTS (Rob 2026-07-30: "all gates need to operate from initial build/rebuild all the way
  to posting the jira entry and logging where jsons are imported"):
    Gate coverage stopped at "the JSON is correct and tested". Everything after that -- telling the
    customer-facing ticket, and recording which tenant received which version -- was carried by
    memory and habit. Two concrete exposures:
      1. A version can be built, tested, documented and pushed with NO Jira comment. Nothing
         noticed. The DEX ticket is what the rest of the org reads, so a silent version bump means
         the org's picture of the provider is a version (or four) behind.
      2. providers/IMPORT_LEDGER.md is the single source of truth for where each JSON is installed,
         and for Foundation tenants it is MANUALLY maintained (the capture tool cannot reach them).
         A manual ledger with no gate drifts by construction. "Where is version X installed" then
         gets answered from memory, which CLAUDE.md explicitly forbids.

  WHAT IT CHECKS, per provider
    STAGE 5 (Jira)   -- docs/tracking/DEX_TICKET.md carries a structured
                        `POSTED: v<X.Y> comment <id> <YYYY-MM-DD>` marker for the CURRENT version.
                        Only checked on providers that are tenant-verified (ALL-PASS); nothing is
                        owed to a ticket for a version that has not passed stage 4 yet.
    STAGE 6 (Import) -- providers/IMPORT_LEDGER.md accounts for the CURRENT version: either an
                        install record, or an explicit not-yet-imported line. Silence is the defect;
                        "built but not imported" is a perfectly good answer that must be WRITTEN.

  ── WHY STAGE 5 NEEDS A MARKER AND NOT A VERSION MENTION (rewritten 2026-08-14) ──
  This check used to be `(Get-Content DEX_TICKET.md -Raw) -match "v$ver"` -- a substring match over
  the WHOLE FILE. Every DEX_TICKET.md carries a `**Current: v4.19 -- tenant-verified...**` line, so
  the version was ALWAYS mentioned and the check COULD NOT FAIL for any provider whose pointer file
  was up to date. On 2026-08-14 it reported 7 of 8 tenant-verified providers PASS while THREE were
  behind on the actual ticket: TX_TLETS (release line at v4.18, repo v4.19), CA_CLETS (v2.23 vs
  v2.24) and AZ_AZDPS (no release line has EVER been posted). Rob found it by reading the tickets;
  the board said green. That is the vacuous-pass class ENGINEERING_STANDARD 4.3 exists to forbid, and
  it is worse than having no gate, because a green board stops anyone looking.

  THE ASYMMETRY THAT MAKES STAGE 5 DIFFERENT FROM STAGE 6, and the reason only stage 5 changed:
  stage 6's authority IS the ledger -- a mention there literally is the record, so matching text in
  it is sound. Stage 5's authority is JIRA, which this tool cannot reach. The file is therefore a
  CLAIM about an external system, and a claim that restates the repo's own version number is no
  evidence at all. The marker fixes that by carrying something the repo cannot derive from itself:
  the Jira COMMENT ID. A `Current:` line can be written by a doc-sync tool; a comment id can only
  come from having actually posted.

  WHY NOT JUST TIGHTEN THE REGEX -- the obvious "the version must appear on a line that also names a
  comment" was tried on paper and rejected: NJ_NJCJIS's posted-record line reads "Closed by comment
  795856 at full plan coverage" and names NO version, so that rule would have false-GAPped the most
  thoroughly finished provider in the portfolio. (usx-cosmetic's rule applies to gates too: if a
  check fires on the provider you derived it from, the check is wrong.) A marker is a small
  convention cost paid once per release; a heuristic over free prose is a permanent false-positive
  generator.

  THE MARKER IS WRITTEN WHEN THE POST IS APPROVED AND MADE -- never in advance, never by a sync
  tool. Jira is on hold and posting is draft-and-wait per provider, so the marker is also the record
  of Rob's approval having been given. Multiple markers may accumulate (one per release); the most
  recent one naming the current version is what satisfies the gate, and the others stay as history.

  LAW 2 PROOF (2026-08-14, by injection on FL_FCIC, all three branches):
    marker removed                                    -> GAP
    marker removed BUT the version still mentioned    -> GAP   <-- the exact old vacuous PASS
    marker naming a stale version                     -> GAP naming which version WAS last posted
  This class is NOT in audit_gate_efficacy's catalogue and cannot be added as-is: that harness
  mutates the provider JSON only (it has no .md mutation kind), so a doc-marker mutation would need
  a new kind in the harness. Noted so the absence reads as a known bound, not an oversight.

  SEVERITY -- advisory by default (-Strict makes it blocking).
    Jira updates have been explicitly placed ON HOLD by Rob more than once, and Foundation-tenant
    imports are somebody else's action on somebody else's schedule. A gate that blocks the build
    because an external party has not acted yet would train everyone to bypass it. So this REPORTS
    relentlessly and blocks only when asked. What it removes is the ability to LOSE the fact.

  Usage: .\audit_lifecycle.ps1 [-Provider TX_TLETS] [-Strict] [-OutFile <path>]
#>

param(
    [string]$Provider,
    [switch]$Strict,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir "_resolve_provider_json.ps1")
# Shared classifier -- the SAME primitives portfolio_status / report_test_status / sync_session_state
# use, so "is stage 5 due yet" can never disagree with the tenant-test state those three report.
. (Join-Path $toolDir "_test_status_lib.ps1")

# The marker stage 5 requires. Leading list punctuation is tolerated so it can sit in a bullet list;
# the POSTED token must still open the content of its own line.
$script:PostedRx = '^[\s\-\*>]*(?:\*\*)?POSTED:(?:\*\*)?\s*v([0-9]+\.[0-9]+)\s+comment\s+(\d+)\s+(\d{4}-\d{2}-\d{2})'

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s,$c){ $lines.Add($s); if($c){Write-Host $s -ForegroundColor $c}else{Write-Host $s} }

Emit "" $null
Emit "================================================================" 'Cyan'
Emit "  LIFECYCLE TAIL AUDIT -- Jira entry + import record" 'Cyan'
Emit "================================================================" 'Cyan'

$ledgerPath = Join-Path $repoRoot 'providers\IMPORT_LEDGER.md'
$ledger = if (Test-Path $ledgerPath) { Get-Content $ledgerPath -Raw } else { $null }
if (-not $ledger) { Emit "  [FAIL] providers\IMPORT_LEDGER.md is missing -- there is no record of where anything is installed" 'Red' }

$targets = @()
if ($Provider) { $targets += Join-Path $repoRoot "providers\$Provider" }
else { $targets += (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | ForEach-Object { $_.FullName }) }

$fails = 0; $notes = 0; $passes = 0
# DENOMINATORS (ENGINEERING_STANDARD 4.3). "0 gaps" must be distinguishable from "nothing looked".
$checked5 = 0; $skipped5 = 0
foreach ($pd in ($targets | Sort-Object)) {
    $name = Split-Path $pd -Leaf
    $jp = Get-ProviderRootJson -ProvDir $pd -Provider $name
    if (-not $jp) { continue }
    # version from the filename: <PROVIDER>_v<X.Y>.json
    $ver = ''
    $m = [regex]::Match((Split-Path $jp -Leaf), '_v([0-9]+\.[0-9]+)\.json$')
    if ($m.Success) { $ver = $m.Groups[1].Value }
    if (-not $ver) { Emit "  [NOTE] $name -- version not in filename, cannot check lifecycle tail" 'Yellow'; $notes++; continue }

    # ── STAGE 5: Jira ──
    # DUE ONLY WHEN STAGE 4 IS DONE. A provider that has never been tenant-verified owes its ticket
    # nothing -- there is no verified version to announce -- and reporting a GAP there would bury the
    # 4 real ones under 12 fake ones. Scoped via the shared classifier, not a local re-derivation.
    $tstate = 'UNKNOWN'
    try { $tstate = (Get-ProviderTestState -ProvDir $pd -Name $name).State } catch { $tstate = 'UNKNOWN' }
    $stage5Due = ($tstate -eq 'ALL-PASS')

    $dex = Get-ChildItem $pd -Recurse -Filter 'DEX_TICKET.md' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $stage5Due) {
        Emit "  [NOTE] $name v$ver -- Jira: not due (tenant-test state $tstate; stage 5 follows stage 4)" 'DarkGray'
        $skipped5++
    } elseif (-not $dex) {
        Emit "  [NOTE] $name v$ver -- no DEX_TICKET.md; no ticket pointer exists for this provider" 'Yellow'; $notes++
    } else {
        $checked5++
        # Collect EVERY marker, so a GAP can say what WAS last posted -- the actionable half.
        $marks = @()
        foreach ($ln in @(Get-Content $dex.FullName)) {
            $mm = [regex]::Match($ln, $script:PostedRx)
            if ($mm.Success) {
                $marks += [pscustomobject]@{ Ver = $mm.Groups[1].Value; Comment = $mm.Groups[2].Value; Date = $mm.Groups[3].Value }
            }
        }
        $hit = @($marks | Where-Object { $_.Ver -eq $ver }) | Select-Object -Last 1
        if ($hit) {
            Emit "  [PASS] $name v$ver -- Jira: POSTED marker present (comment $($hit.Comment), $($hit.Date))" 'Green'; $passes++
        } elseif ($marks.Count -eq 0) {
            Emit "  [GAP ] $name v$ver -- Jira: NO 'POSTED:' marker in DEX_TICKET.md. No release line has ever been recorded for this provider." 'Yellow'
            Emit "         record it when the post is approved and made:  POSTED: v$ver comment <id> <YYYY-MM-DD>" 'DarkGray'
            if ($Strict) { $fails++ } else { $notes++ }
        } else {
            $last = @($marks | Sort-Object Date) | Select-Object -Last 1
            Emit "  [GAP ] $name v$ver -- Jira: last recorded post is v$($last.Ver) (comment $($last.Comment), $($last.Date)). v$ver is NOT posted; the ticket the org reads is behind the repo." 'Yellow'
            if ($Strict) { $fails++ } else { $notes++ }
        }
    }

    # ── STAGE 6: import record ──
    if ($ledger) {
        $sect = ''
        # take the ledger lines mentioning this provider
        $hits = @($ledger -split "`n" | Where-Object { $_ -match [regex]::Escape($name) })
        if (-not $hits.Count) {
            Emit "  [GAP ] $name v$ver -- Import: provider absent from IMPORT_LEDGER.md entirely" 'Yellow'
            if ($Strict) { $fails++ } else { $notes++ }
        } elseif (($hits -join ' ') -match [regex]::Escape("v$ver")) {
            Emit "  [PASS] $name v$ver -- Import: ledger accounts for the current version" 'Green'; $passes++
        } else {
            Emit "  [GAP ] $name v$ver -- Import: ledger mentions the provider but NOT v$ver. Record the install, or record explicitly that v$ver is not imported yet -- silence is the defect." 'Yellow'
            if ($Strict) { $fails++ } else { $notes++ }
        }
    }
}

Emit "" $null
Emit "----------------------------------------------------------------" 'Cyan'
Emit "  RESULT: $passes PASS / $fails FAIL / $notes GAP-or-NOTE  (advisory unless -Strict)" $(if($fails){'Red'}elseif($notes){'Yellow'}else{'Green'})
Emit "  STAGE 5 (Jira): $checked5 provider(s) compared, $skipped5 not yet due (not tenant-verified)." 'DarkGray'
if ($checked5 -eq 0) {
    Emit "  [NOTE] STAGE 5 DID NOT RUN -- no in-scope provider is tenant-verified, so this run says NOTHING about Jira." 'Yellow'
}
Emit "  A GAP is not a build defect -- it is a fact about the lifecycle that would otherwise be lost." 'DarkGray'
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
exit $(if ($fails) { 1 } else { 0 })
