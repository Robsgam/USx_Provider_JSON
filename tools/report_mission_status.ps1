<#
  report_mission_status.ps1 -- THE 95% METRIC, COMPUTED INSTEAD OF CLAIMED.

  WHY THIS EXISTS
  ---------------
  ENGINEERING_STANDARD 5.1 defines the mission as "19 of 20 providers LIFECYCLE-COMPLETE"
  (all six stages: build -> spec -> reachability -> tenant test -> Jira entry -> import record).
  Until now that number lived in PROSE, in two places, and was recomputed BY HAND every time
  anyone asked. On 2026-08-18 it was written as "6/20" in the morning, "8/20" by the afternoon and
  "9/20" that night -- each correct when typed and stale within hours. A mission metric that only
  a human can compute is a mission metric nobody checks.

  Worse, the hand method could not answer the question that actually matters: WHICH STAGE IS
  BLOCKING WHICH PROVIDER. "9/20" tells you nothing about what to do next; "11 providers blocked at
  stage 4, of which 11 are blocked because stage 6 has not happened" tells you to go import.

  WHAT IT DOES NOT DO -- deliberately (LAW 4: do not duplicate an existing gate)
  ------------------------------------------------------------------------------
  It does NOT re-implement any check. Stage 4 uses the SAME classifier as portfolio_status.ps1 and
  SESSION_STATE (_test_status_lib.ps1), so the three can never disagree. Stages 5 and 6 read the
  same authorities audit_lifecycle.ps1 reads (the POSTED marker and IMPORT_LEDGER.md). Stages 1-3
  read the committed report artifacts. This is an AGGREGATOR with an opinion about ORDER, nothing
  more -- if a number here disagrees with the owning gate, the owning gate is right and this tool
  has a bug.

  THE ORDER IS THE POINT. Stages are strictly dependent: you cannot tenant-test what is not
  imported, and you cannot post a release line for a version that has not passed. So each provider
  is reported at its FIRST unmet stage -- its true blocker -- not as a list of everything it lacks.
  That is what turns a score into a work queue.

  ALWAYS EXITS 0 -- a REPORT, not a gate. Owing lifecycle stages is the normal state of a portfolio
  mid-flight; making this blocking would train everyone to skip it, exactly as report_import_owed
  and report_sweep_ledger note for the same reason. But it REFUSES to report a metric it could not
  measure: 0 providers examined prints [NO-VERDICT], never a clean-looking 0/0.

  Usage: .\report_mission_status.ps1 [-Quiet] [-OutFile <path>]
#>

param([switch]$Quiet, [string]$OutFile)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_test_status_lib.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; if (-not $Quiet) { Write-Host $s -ForegroundColor $c } }

# The six stages, in dependency order. Each returns $true when MET.
# TARGET comes from ENGINEERING_STANDARD 5.1 -- 19 of 20, not 20 of 20: one provider is allowed to
# be mid-flight at any time, because a portfolio with zero work in progress is a portfolio nobody
# is improving.
$TARGET_NUM = 19

$provDirs = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory |
              Where-Object { Test-Path (Join-Path $_.FullName 'scripts') } | Sort-Object Name)

Out-Line ''
Out-Line ('=' * 96)
Out-Line '  MISSION STATUS -- lifecycle completeness per provider (ENGINEERING_STANDARD 5.1)'
Out-Line ("  " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + "   target: $TARGET_NUM of 20 providers complete on enforce + all six stages")
Out-Line ('=' * 96)

if (-not $provDirs.Count) {
    Out-Line '  [NO-VERDICT] no provider directories found -- nothing was measured, which is NOT 0/0' 'Red'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 0
}

$rows = @()
foreach ($d in $provDirs) {
    $p    = $d.Name
    $json = Get-ProviderRootJson -ProvDir $d.FullName -Provider $p
    $ver  = ''
    if ($json) { $m = [regex]::Match((Split-Path $json -Leaf), '_v([0-9]+\.[0-9]+)\.json$'); if ($m.Success) { $ver = $m.Groups[1].Value } }

    # ---- stage 0 GATES: `enforce -Provider <P>` must report 0 FAIL **and** 0 WARN.
    # ADDED 2026-08-31, and it is the hole that made this metric overstate for weeks. Rob:
    # "be sure we aren't just rewiring to pass but rewiring to make it right."
    #   ENGINEERING_STANDARD 5.1 defined the metric as "all 6 stages of section 2 green", while
    #   section 5's FIRST condition for finished is `enforce.ps1 -Provider <NAME>` exiting 0. Those
    #   are different tests, and nothing reconciled them: stage 1 reads VALIDATOR_REPORT, which was
    #   0 FAIL / 0 WARN on FL_FCIC, HI_HCJDC_OFML, IL_LEADS_OFML and NJ_NJCJIS all through
    #   2026-08-31 while all four were `BLOCKED` by a PENDING_UPDATES flag. This metric called them
    #   LIFECYCLE-COMPLETE. A number that disagrees with the owning gate is worse than no number.
    # WHY IT IS RUN LIVE rather than read from a report: enforce writes NO per-provider artifact, so
    #   there is nothing committed to read -- the same reason stages 2 and 3 run live (see below).
    #   It costs ~30s per provider. That is the honest price of the metric being true.
    # THERE IS DELIBERATELY NO -SkipGates SWITCH. An escape hatch on the one stage that reads the
    #   authoritative gate is how this metric would quietly go back to overstating, and it is exactly
    #   what "rewiring to pass" would look like. If the run is too slow, run it less often.
    # THE VERDICT LINE IS PARSED, NOT THE EXIT CODE. On 2026-08-31 I read `$?` from a pipeline and
    #   got grep's status instead of enforce's; enforce also exits 0 while printing PASSED WITH
    #   WARNINGS. Absence of a verdict line is NOT-MET, never MET -- a step that did not run has
    #   not passed.
    $s0 = $false; $s0why = 'enforce produced no verdict line'
    $enf = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $toolDir 'enforce.ps1') -Provider $p -SkipGit 2>&1
    $verdict = @($enf | Where-Object { "$_" -match '(ENFORCED|BLOCKED|PASSED WITH WARNINGS):' } | Select-Object -Last 1)
    if ($verdict.Count) {
        $vl = "$($verdict[0])"
        if ($vl -match 'ENFORCED:\s*\d+\s*PASS\s*/\s*0\s*FAIL\s*/\s*0\s*WARN') { $s0 = $true }
        else { $s0why = ($vl.Trim() -replace '\s+', ' ') }
    }

    # ---- stage 1 BUILD: the validator report records 0 FAIL / 0 WARN for the ACTIVE version.
    $s1 = $false; $s1why = 'no VALIDATOR_REPORT'
    $vr = @(Get-ChildItem (Join-Path $d.FullName 'docs') -Recurse -Filter 'VALIDATOR_REPORT_*.txt' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending) | Select-Object -First 1
    if ($vr) {
        $txt = Get-Content $vr.FullName -Raw
        $mm = [regex]::Match($txt, '(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL\s*/\s*(\d+)\s*WARN')
        if ($mm.Success) {
            if ([int]$mm.Groups[2].Value -eq 0 -and [int]$mm.Groups[3].Value -eq 0) { $s1 = $true }
            else { $s1why = "validator $($mm.Groups[2].Value)F/$($mm.Groups[3].Value)W" }
        } else { $s1why = 'VALIDATOR_REPORT unparseable' }
    }

    # ---- stages 2 and 3 ARE RUN LIVE, AND THAT IS NOT LAZINESS -- THEY LEAVE NO ARTIFACT.
    # Every other stage can be read from something committed: a VALIDATOR_REPORT, the logs, the
    # DEX_TICKET marker, the ledger. audit_devdoc_combinations (enforce 2p) and
    # audit_combo_reachability (enforce 2h) run INSIDE enforce and write NOTHING to docs/ -- verified
    # 2026-08-19: zero files in the whole repo match *devdoc* or *reach*. So "was the spec proven for
    # THIS version?" is unanswerable from the repo after the fact, and the only honest options are to
    # re-run them or to report [UNKNOWN]. Guessing a filename is how the first draft of this tool
    # reported "0 of 20" with stages 2-3 failing on every provider -- an absurd result, which per this
    # repo's own rule means the probe is broken, not the portfolio.
    # THIS IS A RECORDED FINDING, not just an implementation note: two BLOCKING gates produce no
    # durable evidence, so their PASS cannot be audited later. See the provenance gate.
    $s2 = $false; $s2why = 'devdoc-combination gate did not reach a verdict'
    $s3 = $false; $s3why = 'reachability gate did not reach a verdict'
    if ($json) {
        # PARSE THE GATE'S OWN WORDS, DO NOT INVENT THE PHRASING. This cost three attempts: the real
        # output is "[PASS] <P> -- no unbuilt devdoc combination (4 note(s); 19 compared)" followed by
        # "RESULT: 0 FAIL / 4 NOTE". A regex for "combination(s) compared" matched NOTHING and made all
        # 20 providers read as blocked at stage 2 -- the same absurd-result-means-broken-probe lesson,
        # and exactly the verdict-by-substring trap usx-build lists. Anchor on the RESULT line plus the
        # compared denominator, and treat "no denominator" as UNKNOWN rather than as a pass.
        # THE GATE PRINTS THE SAME FACT TWO DIFFERENT WAYS -- both are live in the portfolio today:
        #     "... (4 note(s); 19 compared)"                  <- OH_LEADS shape
        #     "... (12 devdoc combination(s) compared)"       <- HI / NM / CA_eSUN shape
        # A regex for either one alone silently mis-reports the other four providers as unproven, which
        # is what happened on the third attempt. So: find the LINE that says "compared" and take the
        # first integer on it, rather than guessing the sentence. (The phrasing inconsistency in
        # audit_devdoc_combinations is itself recorded as a cleanup candidate -- one fact, one wording.)
        $o2  = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $toolDir 'audit_devdoc_combinations.ps1') -Path $json 2>&1 | Out-String)
        $cmpLine = ($o2 -split "`r?`n") | Where-Object { $_ -match 'compared' } | Select-Object -First 1
        $cmp = if ($cmpLine) { [regex]::Match($cmpLine, '(\d+)') } else { [regex]::Match('', 'x') }
        $res = [regex]::Match($o2, 'RESULT:\s*(\d+)\s*FAIL')
        if (-not $cmp.Success)                                  { $s2why = 'gate printed no compared-count (cannot tell clean from never-ran)' }
        elseif ([int]$cmp.Groups[1].Value -eq 0)                { $s2why = 'compared ZERO devdoc combinations (that gate calls this a FAIL)' }
        elseif ($res.Success -and [int]$res.Groups[1].Value -gt 0) { $s2why = "$($res.Groups[1].Value) devdoc-combination FAIL(s)" }
        else                                                    { $s2 = $true }

        $o3 = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $toolDir 'audit_combo_reachability.ps1') -Path $json 2>&1 | Out-String)
        if ($o3 -match 'all reachable') { $s3 = $true }
        elseif ($o3 -match '(?i)unreachable') { $s3why = 'unreachable combination(s)' }
    } else { $s2why = 'no active JSON'; $s3why = 'no active JSON' }

    # ---- stage 4 TENANT TEST: the SHARED classifier, so this cannot disagree with portfolio_status.
    $st   = Get-ProviderTestState -ProvDir $d.FullName -Name $p
    $s4   = ("$($st.State)" -eq 'ALL-PASS')
    # A PARKED provider is NOT "blocked at test" -- there is no test expectation to block on
    # (docs\tracking\TEST_PARKED.txt). Distinguished in the WHY so it never lands in the work
    # queue below, which exists to say what to go DO next. It still counts in the denominator:
    # see the PARKED note after the score, and note that 19-of-20 exists for one provider
    # MID-FLIGHT, which is not the same category as one deliberately parked.
    $s4why = if ($s4) { '' }
             elseif ($st.Parked) { "PARKED -- no test expectation ($($st.ParkReason))" }
             else { "tenant-test state $($st.State)" }

    # ---- stage 5 JIRA: the STRUCTURED marker only. A version number appearing somewhere in the
    # file is NOT evidence -- every DEX_TICKET.md names its own current version, which is why the
    # old -match "v$ver" check could not fail (audit_lifecycle, 2026-08-14).
    $s5 = $false; $s5why = 'no POSTED marker'
    $dt = Join-Path $d.FullName 'docs\tracking\DEX_TICKET.md'
    if (Test-Path $dt) {
        $txt = Get-Content $dt -Raw
        if ($txt -match "POSTED:\s*v$([regex]::Escape($ver))\s+comment\s+\d+") { $s5 = $true }
    } else { $s5why = 'no DEX_TICKET.md' }

    # ---- stage 6 IMPORT: the ledger must ACCOUNT for the active version -- an install line or an
    # explicit not-yet-imported line. Silence is the defect (audit_lifecycle stage 6).
    $s6 = $false; $s6why = 'ledger does not account for this version'
    $led = Join-Path $repoRoot 'providers\IMPORT_LEDGER.md'
    if (Test-Path $led) {
        foreach ($ln in (Get-Content $led)) {
            if ($ln -match [regex]::Escape($p) -and $ln -match ('v' + [regex]::Escape($ver))) { $s6 = $true; break }
        }
    } else { $s6why = 'no IMPORT_LEDGER.md' }

    # GATES FIRST, and that ORDER is deliberate. ENGINEERING_STANDARD 5 lists `enforce` exit 0 as its
    # first condition, and a provider whose own gate is BLOCKED should be reported as blocked THERE --
    # not at some later stage whose evidence the failing gate may itself undermine.
    $met   = @($s0,$s1,$s2,$s3,$s4,$s5,$s6)
    $names = @('gates','build','spec','reach','test','jira','import')
    $whys  = @($s0why,$s1why,$s2why,$s3why,$s4why,$s5why,$s6why)
    $first = -1
    for ($i = 0; $i -lt 7; $i++) { if (-not $met[$i]) { $first = $i; break } }

    $rows += [pscustomobject]@{
        Provider = $p; Ver = $ver; Parked = [bool]$st.Parked
        Stages   = (0..6 | ForEach-Object { if ($met[$_]) { 'X' } else { '.' } }) -join ''
        Count    = @($met | Where-Object { $_ }).Count
        Complete = ($first -lt 0)
        Blocker  = if ($first -lt 0) { '' } else { "$($names[$first]): $($whys[$first])" }
    }
}

Out-Line ''
Out-Line ('  {0,-22} {1,-6} {2,-14} {3}' -f 'PROVIDER','VER','G B S R T J I','FIRST UNMET STAGE (the only thing to do next)')
Out-Line ('  ' + ('-' * 92))
foreach ($r in ($rows | Sort-Object @{E='Complete';D=$true}, @{E='Count';D=$true}, 'Provider')) {
    $sig = ($r.Stages.ToCharArray() -join ' ')
    $col = if ($r.Complete) { 'Green' } elseif ($r.Count -ge 4) { 'Yellow' } else { 'Gray' }
    Out-Line ('  {0,-22} {1,-6} {2,-14} {3}' -f $r.Provider, "v$($r.Ver)", $sig, $(if ($r.Complete) { 'COMPLETE -- gates + all six stages' } else { $r.Blocker })) $col
}

$done = @($rows | Where-Object { $_.Complete }).Count
$pct  = [math]::Round(100.0 * $done / $rows.Count, 1)
$tpct = [math]::Round(100.0 * $TARGET_NUM / $rows.Count, 1)

Out-Line ''
Out-Line ('  ' + ('-' * 92))
Out-Line ("  LIFECYCLE-COMPLETE: {0} of {1} = {2}%     TARGET {3} of {1} = {4}%     GAP {5} provider(s)" -f `
          $done, $rows.Count, $pct, $TARGET_NUM, $tpct, [math]::Max(0, $TARGET_NUM - $done)) `
          $(if ($done -ge $TARGET_NUM) { 'Green' } else { 'Yellow' })

# PARKED PROVIDERS -- reported, NEVER silently absorbed into the target. A parked provider has no
# test expectation, so it can never reach LIFECYCLE-COMPLETE while the park stands, and it still
# occupies one of the 20. ENGINEERING_STANDARD 5.1's "19 of 20" exists to allow ONE provider
# MID-FLIGHT -- that is a different category from one deliberately parked, so whether the target
# should be measured against (20 - parked) is an ENGINEERING_STANDARD decision and NOT a default
# this tool is entitled to pick. Stating it is the whole point: a denominator quietly redefined by
# a tool is how a mission metric stops meaning anything.
$parked = @($rows | Where-Object { $_.Parked })
if ($parked.Count) {
    Out-Line ''
    Out-Line ("  PARKED (no test expectation -- cannot complete while parked): {0}" -f `
              (($parked | ForEach-Object { $_.Provider }) -join ', ')) 'DarkCyan'
    Out-Line ("  So {0} of the {1} are ELIGIBLE. Against the eligible set this reads {2} of {0}. Whether" -f `
              ($rows.Count - $parked.Count), $rows.Count, $done)
    Out-Line "  the TARGET moves to that denominator is Rob's call on ENGINEERING_STANDARD 5.1, not this tool's."
}

# WHERE THE QUEUE ACTUALLY IS. Grouping by blocking stage is what makes this a work queue instead
# of a scoreboard: 11 providers blocked at 'test' all need the SAME next action (import, then sweep).
# Parked providers are EXCLUDED here -- this block answers "what do I go do next", and a
# provider with no test expectation is not work. It is still reported, in the PARKED note above.
$byStage = $rows | Where-Object { -not $_.Complete -and -not $_.Parked } | Group-Object { ($_.Blocker -split ':')[0] } | Sort-Object Count -Descending
if ($byStage) {
    Out-Line ''
    Out-Line '  BLOCKED BY STAGE -- same stage means same next action:'
    foreach ($g in $byStage) {
        Out-Line ("    {0,-8} {1,2} provider(s): {2}" -f $g.Name, $g.Count, (($g.Group.Provider) -join ', '))
    }
}
Out-Line ''
Out-Line '  Stage key: G=gates(enforce -Provider: 0 FAIL AND 0 WARN, run LIVE -- ENGINEERING_STANDARD 5 bullet 1)'
Out-Line '             B=build(validator 0F/0W)  S=spec(devdoc combinations)  R=reach(all combos reachable)'
Out-Line '             T=test(tenant ALL-PASS)   J=jira(POSTED marker)       I=import(ledger accounts for version)'
Out-Line '  Every number here is read from the owning authority. If one disagrees with its gate, the GATE is right.'
Out-Line ('=' * 96)

if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII; if (-not $Quiet) { Write-Host "  -> $OutFile" -ForegroundColor Cyan } }
exit 0
