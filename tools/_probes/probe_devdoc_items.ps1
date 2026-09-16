# ===========================================================================
#  probe_devdoc_items.ps1 -- HOW MANY DEVDOC COMBINATIONS DOES THE PARSER SEE,
#  PER PROVIDER?
#
#  The before/after denominator for any change to the devdoc parser in
#  audit_devdoc_combinations.ps1. That parser feeds enforce PHASE 2p (BLOCKING)
#  and emit_test_plan_spec.ps1, so a change that silently lowers its item count
#  lowers the coverage of a blocking gate and of the independent test plan --
#  and both would still print [PASS].
#
#  WHY IT EXISTS. On 2026-09-16 the parser was found to require every Basic
#  transaction name to end in "Query". SC_SLED's AdministrativeMessage does
#  not, so it was dropped SILENTLY: 18 items across 8 queries, `0 FAIL`, and no
#  mention of the 9th transaction anywhere. The tool's header claims it "FAILS
#  LOUDLY if it cannot find a Possible Combinations line for a query" -- but
#  AdministrativeMessage never became "a query" in its list, so there was
#  nothing for the loud guard to fire about. A guard cannot protect a case it
#  never recognised.
#
#  This is the NJ_NJCJIS incident in a new shape: there, 9 of 11 combination
#  blocks were invisible because the heading layout was unrecognised, and
#  PHASE 2p reported [PASS] over them for months.
#
#  USAGE
#    probe_devdoc_items.ps1                 # print the table
#    probe_devdoc_items.ps1 -Save <file>    # write a baseline to compare against
#    probe_devdoc_items.ps1 -Compare <file> # diff against a saved baseline; exits 1 on a FALL
# ===========================================================================
[CmdletBinding()]
param([string]$Save, [string]$Compare, [switch]$Quiet)

$ErrorActionPreference = 'Stop'
$repo  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tools = Join-Path $repo 'tools'
. (Join-Path $tools '_resolve_provider_json.ps1')

function Say([string]$s) { if (-not $Quiet) { Write-Host $s } }

Say ''
Say '===================================================================================='
Say '  DEVDOC ITEMS PER PROVIDER -- the denominator for a parser change'
Say '===================================================================================='

$rows = @()
foreach ($d in (Get-ChildItem (Join-Path $repo 'providers') -Directory | Sort-Object Name)) {
    # -ProvDir is MANDATORY on this resolver; omitting it is a parameter-binding error, not a
    # silent skip. Never hand-glob providers/$p/*.json instead (ENGINEERING_STANDARD 4.4).
    $json = Get-ProviderRootJson -ProvDir $d.FullName -Provider $d.Name
    if (-not $json) { continue }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File `
             (Join-Path $tools 'audit_devdoc_combinations.ps1') -Path $json -Explain 2>&1 | Out-String
    # one line per parsed item: "devdoc <Query> #N: mand=[...] opt=[...]"
    $items = @([regex]::Matches($out, 'devdoc\s+(\S+)\s+#\d+:'))
    $queries = @($items | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique | Sort-Object)
    $rows += [pscustomobject]@{
        Provider = $d.Name
        Items    = $items.Count
        Queries  = $queries.Count
        Names    = ($queries -join ',')
    }
}

if ($rows.Count -eq 0) { Say '  [FAIL] 0 providers measured -- that is not a baseline.'; exit 1 }

Say ''
Say ('  {0,-22} {1,6} {2,8}  {3}' -f 'provider', 'items', 'queries', 'query names')
foreach ($r in $rows) { Say ('  {0,-22} {1,6} {2,8}  {3}' -f $r.Provider, $r.Items, $r.Queries, $r.Names) }
Say ''
Say ('  TOTAL: {0} item(s) across {1} provider(s)' -f (($rows | Measure-Object Items -Sum).Sum), $rows.Count)

if ($Save) {
    $rows | ConvertTo-Json -Depth 4 | Set-Content $Save -Encoding UTF8
    Say ("  baseline saved: {0}" -f $Save)
}

if ($Compare) {
    if (-not (Test-Path $Compare)) { Say "  [FAIL] baseline $Compare not found"; exit 1 }
    # ⚠️ NO @() WRAPPER. ConvertFrom-Json already returns the array, and @() around it yields a
    # NESTED array: $base.Count reads 1, $base[0] is Object[], and $base[0].Provider stringifies
    # EVERY provider name into one bogus value -- so every row read as a "NEW provider" and the
    # comparison silently proved nothing. This is the exact trap _resolve_version_history.ps1's
    # header warns about, hit anyway. Flatten explicitly instead.
    $base = @(); Get-Content $Compare -Raw | ConvertFrom-Json | ForEach-Object { $base += $_ }
    $byName = @{}; foreach ($b in $base) { $byName[$b.Provider] = $b }
    $fell = @(); $grew = @()
    foreach ($r in $rows) {
        if (-not $byName.ContainsKey($r.Provider)) { $grew += ('{0}: NEW provider, {1} item(s)' -f $r.Provider, $r.Items); continue }
        $b = $byName[$r.Provider]
        if ($r.Items -lt $b.Items) { $fell += ('{0}: {1} -> {2} items  LOST [{3}]' -f $r.Provider, $b.Items, $r.Items, $b.Names) }
        elseif ($r.Items -gt $b.Items) { $grew += ('{0}: {1} -> {2} items  GAINED' -f $r.Provider, $b.Items, $r.Items) }
    }
    Say ''
    Say '  ---- vs baseline ----'
    if ($grew.Count) { Say '  GAINED (report it, do not assume it is free):'; $grew | ForEach-Object { Say ('    ' + $_) } }
    if ($fell.Count) {
        Say '  [FAIL] COVERAGE FELL -- a parser change that sees FEWER items lowers a BLOCKING gate:'
        $fell | ForEach-Object { Say ('    ' + $_) }
        exit 1
    }
    if (-not $grew.Count) { Say '  identical -- no item count moved on any provider.' }
    Say '  [PASS] no provider lost devdoc items.'
}
exit 0
