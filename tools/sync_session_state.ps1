<#
  sync_session_state.ps1 -- GENERATE the derived block of SESSION_STATE.md instead of hand-typing it.

  WHY THIS EXISTS (Rob 2026-07-30: "check for duplication of data that keeps drifting... remove
  redundant steps or automate them"):
    "TX_TLETS is at v4.18" is stored in FOURTEEN places, and enforce spends FIFTEEN assertions
    reconciling them. Almost all fourteen are generated -- the JSON filename, the bundle
    description, the TEST_PLAN filename, BUILD_MANIFEST, .test_version, and the six tracking docs
    sync_version_docs writes, plus the CLAUDE.md row sync_provider_table writes. Exactly three were
    typed by hand:
        SESSION_STATE.md   <- automated by THIS tool
        IMPORT_LEDGER.md   <- stays manual, and should: it records an EXTERNAL act (somebody
                              imported something into a tenant). Generating it would be fabricating
                              evidence.
        DEX_TICKET.md      <- stays manual by Rob's ruling; he holds the Jira trigger.
    SESSION_STATE was hand-corrected THREE times on 2026-07-30 alone. audit_session_state.ps1 gates
    it, but a gate on a hand-maintained file only tells you it is wrong afterwards -- it does not
    stop the drift. The fix is to stop typing the derivable part.

  WHAT IS GENERATED vs WHAT STAYS PROSE
    Generated (between the markers): the "Last updated" stamp, the branch line, and the
    tenant-test state table -- all of it derived from _test_status_lib.ps1, the SAME primitives
    portfolio_status.ps1 and the CLAUDE.md table use, so the three can never disagree.
    Prose (never touched): NEXT PHYSICAL ACTION, what is owed, open decisions, hard-won rules.
    Judgement does not belong to a generator.

  Usage: .\sync_session_state.ps1 [-DryRun]
#>

param([switch]$DryRun)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir "_resolve_provider_json.ps1")
. (Join-Path $toolDir "_test_status_lib.ps1")

$statePath = Join-Path $repoRoot 'SESSION_STATE.md'
if (-not (Test-Path $statePath)) { Write-Host "  [ERROR] SESSION_STATE.md not found" -ForegroundColor Red; exit 1 }

$BEGIN = '<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->'
$END   = '<!-- END GENERATED -->'

# ── derive ────────────────────────────────────────────────────────────────────────────
$today  = Get-Date -Format 'yyyy-MM-dd'
$branch = (git -C $repoRoot branch --show-current 2>$null)
if (-not $branch) { $branch = '(detached)' }

$rows = @()
foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name)) {
    $jp = Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name
    if (-not $jp) { continue }
    $state = Get-ProviderTestState -ProvDir $d.FullName -Name $d.Name
    $ver = ''
    $m = [regex]::Match((Split-Path $jp -Leaf), '_v([0-9]+\.[0-9]+)\.json$')
    if ($m.Success) { $ver = 'v' + $m.Groups[1].Value }
    # PROPERTY NAMES VERIFIED against _test_status_lib.ps1's actual return, not guessed. The first
    # draft used .Verdict/.LogCount -- neither exists -- and every row rendered "unknown (0 logs)".
    # The -DryRun caught it before a single byte was written, which is the whole reason this tool
    # has a -DryRun. Real shape: State / Pass / Fail / Pending / OwedPlanTests / EntitiesTested.
    $verdict = [string]$state.State
    if (-not $verdict) { $verdict = 'UNKNOWN' }
    $rows += [pscustomobject]@{ Name = $d.Name; Ver = $ver; Verdict = $verdict
                                Logs = [int]$state.Pass + [int]$state.Fail + [int]$state.Pending
                                Owed = [int]$state.OwedPlanTests; Failed = [int]$state.Fail
                                HasHistory = ((@(Get-ChildItem (Join-Path $d.FullName 'logs') -Recurse -Filter '*.txt' -File -ErrorAction SilentlyContinue)).Count -gt 0) }
}

# only the tenant-tested-or-owed providers earn a row; the rest collapse to one line, so the
# table stays short enough to actually be read (the accumulation failure that killed the
# memory-file predecessor of this document).
# A provider earns a NAMED row if it has been tested OR has plan tests owed. Owed-tests matters:
# TX_TLETS v4.18 reads NEVER-TESTED (its v4.16 logs were archived by the bump) yet owes 89 tests --
# collapsing it into the "others" bucket would hide the single largest outstanding action.
# A provider earns a NAMED row if it has been tenant-tested at SOME point -- currently (ALL-PASS /
# PARTIAL) or previously (archived logs, meaning a bump reset it and a re-sweep is owed). Every
# provider owes plan tests, so "Owed > 0" alone named all 20 and defeated the collapse; "has logs,
# current or archived" is the signal that actually separates real history from never-touched.
# TX_TLETS is the case that matters: NEVER-TESTED at v4.18 with 814 archived logs and 89 owed.
$named  = @($rows | Where-Object { $_.Verdict -notmatch 'NEVER' -or $_.HasHistory })
$never  = @($rows | Where-Object { $_.Verdict -match 'NEVER' -and -not $_.HasHistory })

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine($BEGIN)
[void]$sb.AppendLine("**Last updated:** $today (generated) · **Branch:** ``$branch``")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Tenant-test state — GENERATED, do not hand-edit')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the')
[void]$sb.AppendLine('CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| Provider | Ver | State |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($r in ($named | Sort-Object Name)) {
    $s = switch -Regex ($r.Verdict) {
        'ALL-PASS' { "ALL-PASS ($($r.Logs) logs)" }
        'PARTIAL'  { "PARTIAL — $($r.Owed) plan test(s) owed ($($r.Logs) captured)" }
        default    { "$($r.Verdict)$(if($r.Owed){" — $($r.Owed) test(s) owed"})" }
    }
    [void]$sb.AppendLine("| $($r.Name) | $($r.Ver) | $s |")
}
if ($never.Count) {
    [void]$sb.AppendLine("| _$($never.Count) others_ | — | never tenant-tested: $((($never | ForEach-Object { $_.Name }) -join ', ')) |")
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 — `0 FAIL / 0 WARN`.')
[void]$sb.AppendLine('No PASS count is recorded here on purpose: it moves every time a gate is added, so an')
[void]$sb.AppendLine('absolute number is guaranteed to go stale and teach the next session to distrust this file.')
[void]$sb.AppendLine($END)
$generated = $sb.ToString().TrimEnd()

# ── splice ────────────────────────────────────────────────────────────────────────────
$raw = [System.IO.File]::ReadAllText($statePath)
if ($raw -match [regex]::Escape($BEGIN)) {
    $pattern = [regex]::Escape($BEGIN) + '.*?' + [regex]::Escape($END)
    $new = [regex]::Replace($raw, $pattern, [System.Text.RegularExpressions.Regex]::Escape($generated).Replace('\','\\'), 'Singleline')
    # Regex.Replace mangles $ and \ in the replacement; do it positionally instead.
    $s = $raw.IndexOf($BEGIN); $e = $raw.IndexOf($END)
    if ($s -ge 0 -and $e -gt $s) { $new = $raw.Substring(0,$s) + $generated + $raw.Substring($e + $END.Length) }
} else {
    # First run: insert the generated block after the leading blockquote rules, before the first '---'.
    $idx = $raw.IndexOf("`n---")
    if ($idx -lt 0) { $new = $raw.TrimEnd() + "`r`n`r`n" + $generated + "`r`n" }
    else { $new = $raw.Substring(0,$idx) + "`r`n`r`n" + $generated + "`r`n" + $raw.Substring($idx) }
}

if ($DryRun) {
    Write-Host "  DRY RUN -- generated block would be:" -ForegroundColor Yellow
    $generated -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    exit 0
}
if ($new -eq $raw) { Write-Host "  [PASS] SESSION_STATE.md generated block already current" -ForegroundColor Green; exit 0 }
[System.IO.File]::WriteAllText($statePath, $new, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  [OK] SESSION_STATE.md generated block refreshed ($($named.Count) named provider(s), $($never.Count) collapsed)" -ForegroundColor Green
exit 0
