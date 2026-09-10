<#
  audit_query_selectable.ps1 -- CAN THE OFFICER ACTUALLY SEND EVERY QUERY WE BUILT?

  THE DIRECTION NOTHING ELSE CHECKS. Every other gate asks whether a REQUEST is
  correct -- does it match the devdoc, the metadata, the logs, is the combo
  reachable, does the control reach the wire. None asks the prior question:
  can the query be SELECTED at all? A query the platform never activates is
  perfectly formed and completely unsendable, and it looks identical to a
  working one in every artifact this repo produces.

  WHY IT EXISTS (CA_eSUN, found by Rob mid-sweep 2026-09-10):
    "dh is getting hung up with checkbox enabled but nothing in the check box
     so it never transmits"
  DriverHistoryQuery carried autoSelect=$false. The platform RENDERS the query
  checkbox but never ACTIVATES it, so no query is selected, Send stays DISABLED
  and nothing is sent. 13 of 13 DH tests could not send while all 17 non-DH
  tests did -- and it survived a re-run, so it was not the latency the driver's
  message suggests. eSUN's own registry already described the mechanism from an
  earlier sweep: "The tenant never activates a query checkbox and Send stays
  DISABLED ... there is simply no query to run."
  It shipped in v3.0, v3.1 AND v3.2 with ~40 gates green, and autoSelect had
  been $true at v2.4/v2.5/v2.6. Nothing was watching.

  ⚠️ THE NAIVE GATE IS WRONG, AND THIS WAS MEASURED BEFORE THE GATE WAS WRITTEN.
  "assert autoSelect -eq $true" would be a false accusation on the one provider
  where $false is CORRECT. Census of all 124 QIDMs across 20 providers:
  exactly 8 carry autoSelect=$false and ALL EIGHT are TX_TLETS_CCH's CCH
  transactions (AQ AR FQ IQ QH QR QWI ZR), where opt-in is the design -- CCH is
  not something you fire by filling a name, the officer ticks a named checkbox.

  AND THEY ARE MECHANICALLY INDISTINGUISHABLE FROM THE BUG. Both are
  autoSelect=$false with a queryLabel. Every QIDM has a queryLabel (it is
  mandatory), so the label cannot discriminate. NOTHING IN THE JSON separates
  "opt-in by design" from "silently unsendable".

  SO THE GATE DEMANDS A DECLARATION, not a shape. Every autoSelect=$false must
  carry a row in the provider's ACCEPTED_DIVERGENCES:
      <Query> | * | autoSelect | opt-in-query | <reason a stranger can evaluate>
  An undeclared one FAILs. That is what makes it catch the real defect while
  passing the real design: eSUN's $false had no reason recorded anywhere -- not
  the build script, not BUILD_NOTES, not the registry -- so this gate FAILs on
  it; TX_TLETS_CCH's eight are a deliberate decision, so they get written down
  where a stranger can read them, which they should have been all along.

  The rule name is classified 'selectability' in _divergence_rules.ps1 so that a
  demoted-to-any or dead-combo row can never silence a finding here, and this
  rule can never silence anything else.

  Usage:
    .\tools\audit_query_selectable.ps1 -Provider CA_eSUN
    .\tools\audit_query_selectable.ps1 -Path <json>      # aimable at a replica (mutation testing)
    .\tools\audit_query_selectable.ps1 -All
#>

param(
    [string]$Provider,
    [string]$Path,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot '_resolve_provider_json.ps1')
. (Join-Path $PSScriptRoot '_resolve_docs_path.ps1')
. (Join-Path $PSScriptRoot '_divergence_rules.ps1')

$lines = @()
$script:absentCount = 0   # explicit init -- do not rely on ++ against $null

# ── -Quiet MUST NOT SILENCE THE SUMMARY, AND THIS SHIPPED WRONG ONCE ──────────────
# First cut had ONE emitter that skipped Write-Host entirely under -Quiet. enforce calls
# this tool WITH -Quiet and parses its summary line, so the captured stdout was EMPTY, the
# regex never matched, and PHASE 2y printed "produced no parseable totals" for all 20
# providers while enforce reported 690 PASS / 0 FAIL / 0 WARN. A BLOCKING gate wired in and
# checking NOTHING, with a green board -- precisely the "gate that cannot fail" this repo
# hunts, self-inflicted minutes after writing the rule down.
# House convention (audit_wiring_closure): -Quiet suppresses only per-provider CHATTER.
#   Out2  -> ALWAYS prints. Findings and the summary/denominator go here.
#   Chat  -> suppressed by -Quiet. Banner and per-provider clean lines go here.
function Out2([string]$s) { $script:lines += $s; Write-Host $s }
function Chat([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

# Registry rows licensing an opt-in query, keyed by the QUERY they name. Reuses the
# shared rule vocabulary rather than pattern-matching the rule string here, so this
# tool cannot drift from audit_metadata / audit_suppression_scope about what a rule means.
function Get-OptInDeclarations([string]$provDir, [string]$prov) {
    $reg = Get-DocsPath $provDir 'tracking' ("{0}_ACCEPTED_DIVERGENCES.txt" -f $prov)
    $declared = @{}
    if (-not $reg -or -not (Test-Path $reg)) { return $declared }
    foreach ($ln in (Get-Content $reg)) {
        if ($ln -match '^\s*#') { continue }          # a commented line is NOT a declaration
        $parts = $ln -split '\|'
        if ($parts.Count -lt 5) { continue }
        $rule = $parts[3].Trim()
        if ((Get-DivergenceRuleClass $rule) -ne 'selectability') { continue }
        $q = $parts[0].Trim()
        if ($q) { $declared[$q.ToLower()] = $parts[4].Trim() }
    }
    return $declared
}

function Test-Provider([string]$prov, [string]$jsonPath) {
    $provDir = Join-Path $repoRoot ("providers\{0}" -f $prov)
    if (-not $jsonPath) { $jsonPath = Get-ProviderRootJson $provDir $prov }
    if (-not $jsonPath -or -not (Test-Path $jsonPath)) {
        Out2 ("  [NOTE] {0} -- no JSON resolved; nothing compared" -f $prov)
        return [pscustomobject]@{ Examined = 0; Fail = 0; Declared = 0 }
    }

    $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $declared = Get-OptInDeclarations $provDir $prov

    $examined = 0; $fails = 0; $declaredHits = 0
    foreach ($b in $json.bundles) {
        # RMS QIDMs are platform-fed, not officer-selected checkboxes -- out of scope.
        if ($b.provider -eq 'RMS') { continue }
        foreach ($cfg in $b.configurations) {
            if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            $examined++

            # $true is the normal, sendable case.
            if ($cfg.autoSelect -eq $true) { continue }

            # ── ABSENT IS NOT FALSE, AND THIS COST 59 FALSE FINDINGS ON THE FIRST RUN ──
            # The first cut of this gate FAILed on anything that was not $true, and reported
            # 67 findings across 13 providers -- most of them TENANT-VERIFIED ALL-PASS. A
            # finding that lands on many verified providers at once is one bad assumption, not
            # many defects (usx-tooling 8a). Discriminated with committed logs rather than by
            # reasoning about platform defaults: a query whose autoSelect property is ABSENT
            # could not hold logs for its entity if absence made it unselectable.
            # MEASURED: 44 of 44 absent-autoSelect queries on the 15 tenant-verified providers
            # have committed logs for their entity -- AZ/CA_CLETS/CA_CLETS_OCATS/FL/HI/IL/MD/
            # NJ/NM/NY/OH/OR/TN/TX. Absent behaves as the platform default and IS sendable.
            # Only an EXPLICIT $false suppresses activation, which is the CA_eSUN defect.
            # Do NOT "tighten" this back to "not $true" -- it was tried and it was wrong.
            if ($null -eq $cfg.autoSelect -or ($cfg.PSObject.Properties.Name -notcontains 'autoSelect')) {
                $script:absentCount++
                continue
            }

            # Not auto-selected. Resolve the query name the registry would name: the
            # QIDM name is '<PROVIDER>_<Query>', and the registry rows use <Query>.
            $qname = $cfg.name
            if ($qname -like ("{0}_*" -f $prov)) { $qname = $qname.Substring($prov.Length + 1) }

            $why = $null
            if ($declared.ContainsKey($qname.ToLower())) { $why = $declared[$qname.ToLower()] }
            elseif ($declared.ContainsKey("$($cfg.name)".ToLower())) { $why = $declared["$($cfg.name)".ToLower()] }

            $shown = if ($null -eq $cfg.autoSelect) { '(absent)' } else { "$($cfg.autoSelect)" }
            if ($why) {
                $declaredHits++
                $r = $why; if ($r.Length -gt 90) { $r = $r.Substring(0, 90) + '...' }
                Chat ("  [NOTE] {0} -- '{1}' is opt-in by declaration (autoSelect={2}): {3}" -f $prov, $qname, $shown, $r)
            } else {
                $fails++
                Out2 ("  [FAIL] {0} -- '{1}' has autoSelect={2} and NO 'opt-in-query' declaration: the platform renders its checkbox but never ACTIVATES it, so no query is selected, Send stays DISABLED and the officer cannot send it at all. Either set autoSelect=`$true, or record it: accept_divergence.ps1 -Provider {0} -Query {1} -KeyRef '*' -Field autoSelect -Rule opt-in-query -Reason '<why the officer must tick it>'" -f $prov, $qname, $shown)
            }
        }
    }
    # A PER-PROVIDER [PASS] LINE IS NOT COSMETIC. audit_gate_efficacy decides whether a gate's
    # BASELINE run was vacuous by counting its PASS lines, so a gate that only ever prints
    # [NOTE]/[FAIL] is scored [INVALID] "baseline run was VACUOUS -- the gate never looked" and
    # its mutation can never be killed. That happened to this gate on its first catalogued run.
    # It also satisfies ENGINEERING_STANDARD 4.3 directly: say what was examined, per provider.
    if ($fails -eq 0) {
        $extra = ''
        if ($declaredHits -gt 0) { $extra = (" ({0} declared opt-in)" -f $declaredHits) }
        Chat ("  [PASS] {0} -- every built query is selectable{1} ({2} QIDM(s) examined)" -f $prov, $extra, $examined)
    }
    return [pscustomobject]@{ Examined = $examined; Fail = $fails; Declared = $declaredHits }
}

Out2 ''
Chat '====================================================================================='
Chat '  QUERY SELECTABILITY -- can the officer actually SEND every query we built?'
Chat '====================================================================================='

$targets = @()
if ($Path) {
    if (-not (Test-Path $Path)) { Out2 ("  [FAIL] -Path not found: {0}" -f $Path); exit 1 }
    # Derive the provider from the replica's own directory, so the registry read is correct
    # even when the JSON is a mutation replica sitting inside the provider folder.
    $p = Split-Path (Split-Path $Path -Parent) -Leaf
    $targets = @([pscustomobject]@{ Prov = $p; Json = $Path })
} elseif ($All) {
    foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Sort-Object Name)) {
        $targets += [pscustomobject]@{ Prov = $d.Name; Json = $null }
    }
} elseif ($Provider) {
    $targets = @([pscustomobject]@{ Prov = $Provider; Json = $null })
} else {
    Out2 '  [FAIL] specify -Provider <name>, -Path <json>, or -All'
    exit 1
}

$totExam = 0; $totFail = 0; $totDecl = 0
foreach ($t in $targets) {
    $r = Test-Provider $t.Prov $t.Json
    $totExam += $r.Examined; $totFail += $r.Fail; $totDecl += $r.Declared
}

Out2 ''
Out2 ("  QIDMs examined: {0}   auto-selected or absent-default: {1}   opt-in DECLARED: {2}   UNDECLARED (FAIL): {3}" -f $totExam, ($totExam - $totDecl - $totFail), $totDecl, $totFail)
Out2 ("  (absent autoSelect is the platform default and is SENDABLE -- proven by 44 of 44 such queries holding committed logs on the 15 tenant-verified providers; {0} seen here)" -f $script:absentCount)

# A gate that examined nothing has not passed -- ENGINEERING_STANDARD 4.3.
if ($totExam -eq 0) {
    Out2 '  [FAIL] 0 QIDMs examined -- this is a VACUOUS run, not a pass. Check the JSON resolved.'
    if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

if ($totFail -gt 0) {
    Out2 ('  RESULT: {0} query/queries cannot be selected by an officer and are not declared opt-in.' -f $totFail)
} else {
    Out2 '  RESULT: every built query is either auto-selected or a DECLARED opt-in. None is silently unsendable.'
}
Chat '====================================================================================='
Out2 ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
if ($totFail -gt 0) { exit 1 } else { exit 0 }
