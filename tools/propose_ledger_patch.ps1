<#
  propose_ledger_patch.ps1 -- PROPOSE ledger corrections. NEVER WRITE THEM.

  Rob, 2026-09-11: "i will help align them with our ledger as needed when we get to that" and, on
  the roadmap, "update our internal ledger".

  WHY IT PROPOSES INSTEAD OF WRITING, and this is the whole design:
  `providers\IMPORT_LEDGER.md` is HAND-AUTHORED and it is Rob's. Its rows are not data -- they are
  paragraphs of adjudication ("SDSO runs v1.0, NOT v3.3", "Lafayette is hand-built by engineering",
  "TX_TLETS_CCH is PARKED"). A tool that rewrote those would destroy reasoning it cannot reconstruct,
  and it would do it silently. So this emits a PATCH PROPOSAL -- line number, the exact text now
  there, the evidence, and the minimal edit -- and Rob applies what he agrees with.

  ⚠️ IT PROPOSES ONLY WHAT CONTENT PROVES. A version in this repo lives in a bundle DESCRIPTION, and
  a label is not a version: four tenants carry stale descriptions over current content, and
  `practice-bertanzini` read CLEAN for weeks because a stale ENTITIES label happened to match the
  ledger. So a proposal is raised ONLY when every comparable bundle HASHES EQUAL to a repo build
  (via _bundle_identity, description excluded and platform nulls normalised). A tenant that is
  merely LABELLED something gets no proposal at all -- it is reported in its own section with the
  reason, because "we could not prove it" and "it agrees" must never look the same.

  ⚠️ IT REFUSES TO GUESS WHICH LINE. The locator is the deptId, which is the only stable key
  (subdomains get renamed -- "HDLE LIVE" vs `hawaii-dle`). 0 matches is a MISSING-ROW finding, not a
  silent skip; 2+ matches is AMBIGUOUS and is reported rather than resolved.

  ⚠️ AN EMPTY PROPOSAL IS A PASS, AND IT PRINTS ITS DENOMINATOR. Unlike emit_import_job (where an
  empty job is a failure because you asked for one), "the ledger already agrees" is a legitimate
  healthy state. But it must be distinguishable from "the tool looked at nothing", so every run
  prints examined / content-proven / agree / disagree / missing / ambiguous.

  Usage:
    tools\propose_ledger_patch.ps1
    tools\propose_ledger_patch.ps1 -Tenant usx-fl-fcic
    tools\propose_ledger_patch.ps1 -OutFile providers\LEDGER_PATCH.md
#>
param(
    [string]$Tenant,
    [string]$TenantDir,
    [string]$LedgerPath,
    [string]$OutFile,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\_json_canonical.ps1"
. "$PSScriptRoot\_bundle_identity.ps1"

$lines = @()
function Say([string]$s) { $script:lines += $s; if (-not $Quiet) { Write-Host $s } }

Say '===================================================================================='
Say '  LEDGER PATCH PROPOSAL -- read-only. IMPORT_LEDGER.md is never written by this tool.'
Say '===================================================================================='

$ledger = if ($LedgerPath) { $LedgerPath } else { Join-Path $repoRoot 'providers\IMPORT_LEDGER.md' }
if (-not (Test-Path $ledger)) { Say ('  [FAIL] no ledger at {0}' -f $ledger); exit 1 }
$ledgerLines = @(Get-Content $ledger)
Say ('  ledger : {0} ({1} lines)' -f (Split-Path $ledger -Leaf), $ledgerLines.Count)

$tenantDir = if ($TenantDir) { $TenantDir } else { Join-Path $repoRoot '_versions\tenant_exports' }
if (-not (Test-Path $tenantDir)) { Say ('  [FAIL] no tenant exports at {0} -- pull them first.' -f $tenantDir); exit 1 }

# ---- repo side ---------------------------------------------------------------------------------
$repoVer = @{}; $repoHash = @{}
foreach ($d in (Get-ChildItem (Join-Path $repoRoot 'providers') -Directory)) {
    $cands = @(Get-ChildItem $d.FullName -Filter ('{0}_v*.json' -f $d.Name) -File -ErrorAction SilentlyContinue)
    if ($cands.Count -ne 1) { continue }
    $o = $null
    try { $o = Get-Content $cands[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ($cands[0].Name -match '_v([0-9]+\.[0-9]+)\.json$') { $repoVer[$d.Name] = $Matches[1] }
    foreach ($b in (Get-BundleList $o)) { $repoHash[('{0}|{1}' -f $d.Name, $b.name)] = (Get-BundleContentHash $b) }
}
if ($repoVer.Count -eq 0) { Say '  [FAIL] no repo builds indexed -- refusing to propose against an empty repo.'; exit 1 }
Say ('  repo   : {0} provider build(s) indexed' -f $repoVer.Count)

# ---- tenant side -------------------------------------------------------------------------------
$files = @(Get-ChildItem $tenantDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'provenance' })
if ($files.Count -eq 0) { Say '  [FAIL] no tenant configs on disk -- nothing measured, so nothing may be proposed.'; exit 1 }

$examined = 0; $proven = 0
$agree = @(); $disagree = @(); $missing = @(); $ambiguous = @(); $unproven = @(); $noversion = @(); $unparsed = @()

foreach ($f in $files) {
    $sub = ($f.BaseName -replace '_\d+$', '')
    if ($Tenant -and $sub -ne $Tenant -and ($f.BaseName -replace '^.*_(\d+)$', '$1') -ne $Tenant) { continue }
    $examined++

    $o = $null
    try { $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    $bl = Get-BundleList $o
    if ($bl.Count -eq 0) { continue }
    $dept = ($f.BaseName -replace '^.*_(\d+)$', '$1')

    # ⚠️ A -replace THAT DOES NOT MATCH RETURNS THE INPUT UNCHANGED -- it does not fail. One stray
    # file in the exports dir (`CA_eSUN_dept69510509021_20260910-163019.json`) does not fit the
    # `<subdomain>_<deptId>` convention, so `$dept` came back as the WHOLE BASENAME and the tool
    # duly proposed a ledger row reading
    #     | ... (dept CA_eSUN_dept69510509021_20260910-163019) | CA_eSUN v3.3 |
    # A proposal a human might paste into the ledger must never contain a value the tool did not
    # actually parse. The deptId is the JOIN KEY; if it is not numeric we do not have one.
    if ($dept -notmatch '^\d+$') {
        $unparsed += [pscustomobject]@{ File = $f.Name; Why = 'filename does not end in _<deptId> -- no join key, so nothing may be proposed for it' }
        continue
    }

    $pb = @($bl | Where-Object { ('{0}' -f $_.name) -ne 'ENTITIES' -and ('{0}' -f $_.name) -ne 'RMS' })[0]
    if (-not $pb) { continue }
    $pn  = ('{0}' -f $pb.name)
    $lbl = Get-BundleLabelVersion $pb

    # CONTENT PROOF: every comparable bundle must hash equal to the current repo build.
    $provenVer = $null
    if ($repoVer.ContainsKey($pn)) {
        $allMatch = $true; $compared = 0
        foreach ($b in $bl) {
            $k = '{0}|{1}' -f $pn, $b.name
            if (-not $repoHash.ContainsKey($k)) { $allMatch = $false; break }
            $compared++
            if ((Get-BundleContentHash $b) -ne $repoHash[$k]) { $allMatch = $false; break }
        }
        # A zero-compare must never read as agreement -- that is the vacuous-pass shape.
        if ($allMatch -and $compared -gt 0) { $provenVer = $repoVer[$pn] }
    }

    if (-not $provenVer) {
        $unproven += [pscustomobject]@{
            Sub = $sub; Dept = $dept; Provider = $pn
            Label = $(if ($lbl) { $lbl.Version } else { $null })
            Why = $(if (-not $lbl) { 'NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision' }
                    elseif (-not $repoVer.ContainsKey($pn)) { ('no repo build for {0}' -f $pn) }
                    else { 'content does not equal the current repo build -- it is BEHIND or divergent, so its exact version needs audit_tenant_provenance, not a guess' })
        }
        continue
    }
    $proven++

    # ---- locate the ledger row by deptId (the only stable key) ---------------------------------
    $hits = @()
    for ($i = 0; $i -lt $ledgerLines.Count; $i++) {
        if ($ledgerLines[$i] -match [regex]::Escape($dept)) { $hits += ($i + 1) }
    }

    if ($hits.Count -eq 0) {
        $missing += [pscustomobject]@{ Sub = $sub; Dept = $dept; Provider = $pn; Proven = $provenVer
                                       Label = $(if ($lbl) { $lbl.Version } else { $null }) }
        continue
    }
    # ⚠️ A ROW THAT STATES NO VERSION IS NOT A ROW THAT STATES THE WRONG ONE.
    # The first run of this tool reported 8 DISAGREEs and every one was MY LOGIC. The matched lines
    # were Section B.0, the NAME CORRELATION table, whose cells carry a PLATFORM COUNTER
    # (`IL_LEADS_OFML/3`) and deliberately no version -- the ledger says in its own text that the
    # counter is not our version. With no `vX.Y` on the line, "claims does not contain the measured
    # version" was trivially true, so a purely informational row was reported as a contradiction.
    # Eight findings of identical shape is the tell that the probe is the defect (usx-tooling 8a).
    # So: narrow to the lines that actually MAKE a version claim, and give a no-claim row its own
    # class rather than folding it into the alarming one.
    $versioned = @($hits | Where-Object { $ledgerLines[$_ - 1] -match 'v[0-9]+\.[0-9]+' })

    if ($versioned.Count -eq 0) {
        $noversion += [pscustomobject]@{ Sub = $sub; Dept = $dept; Provider = $pn; Proven = $provenVer
                                         Lines = $hits }
        continue
    }
    if ($versioned.Count -gt 1) {
        $ambiguous += [pscustomobject]@{ Sub = $sub; Dept = $dept; Provider = $pn; Proven = $provenVer; Lines = $versioned }
        continue
    }

    $lineNo = $versioned[0]
    $text = $ledgerLines[$lineNo - 1]
    # What does the ledger CLAIM for this tenant? Collect every vX.Y on its row.
    $claims = @([regex]::Matches($text, 'v([0-9]+\.[0-9]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

    if ($claims -contains $provenVer) {
        $agree += [pscustomobject]@{ Sub = $sub; Dept = $dept; Provider = $pn; Proven = $provenVer; Line = $lineNo }
    } else {
        $disagree += [pscustomobject]@{ Sub = $sub; Dept = $dept; Provider = $pn; Proven = $provenVer
                                        Claims = $claims; Line = $lineNo; Text = $text }
    }
}

Say ('  tenants: {0} examined / {1} CONTENT-PROVEN against a repo build' -f $examined, $proven)
Say ''
Say ('  agree {0}  |  DISAGREE {1}  |  NO LEDGER ROW {2}  |  row states no version {3}  |  ambiguous {4}  |  not content-proven {5}' -f
     $agree.Count, $disagree.Count, $missing.Count, $noversion.Count, $ambiguous.Count, $unproven.Count)
if ($unparsed.Count -gt 0) {
    # Printed, never silently dropped: a skipped input is part of the denominator.
    Say ''
    Say ('  {0} export file(s) SKIPPED -- the filename carries no deptId, so there is no join key:' -f $unparsed.Count)
    foreach ($u in $unparsed) { Say ('     {0}' -f $u.File) }
}
Say ''

# ---- THE PROPOSALS -----------------------------------------------------------------------------
if ($disagree.Count -gt 0) {
    Say '===================================================================================='
    Say '  PROPOSAL 1 -- THE LEDGER NAMES A VERSION THE CONTENT REFUTES'
    Say '===================================================================================='
    Say '  Evidence is a content hash, never a description. Apply only what you agree with.'
    Say ''
    foreach ($r in ($disagree | Sort-Object Sub)) {
        Say ('  {0}  (dept {1})' -f $r.Sub, $r.Dept)
        Say ('    measured : {0} v{1}   -- every comparable bundle hashes equal to the repo build' -f $r.Provider, $r.Proven)
        Say ('    ledger   : line {0} names {1}' -f $r.Line, (($r.Claims | ForEach-Object { 'v' + $_ }) -join ', '))
        $snip = $r.Text
        if ($snip.Length -gt 200) { $snip = $snip.Substring(0, 200) + ' ...' }
        Say ('    now      : {0}' -f $snip)
        # ⚠️ ONLY PROPOSE A LITERAL EDIT WHEN THE ROW NAMES EXACTLY ONE VERSION.
        # A ledger row is a PARAGRAPH, not a cell. The FL_FCIC row names v7.24 twice as the current
        # claim and v7.17 / v7.19 / v7.20 / v7.23 in PROSE as history ("regressed at v7.19",
        # "fixed at v7.23"). The first cut emitted an EDIT line for every one of them, so applying
        # the proposal verbatim would have REWRITTEN THE HISTORY to read as though it had always
        # been v7.24 -- silently destroying the reasoning this tool exists to protect, in the one
        # file it promises never to write.
        # Caught by the negative control (a mutated replica), not by review of the clean run --
        # which is the argument for having the control at all.
        if ($r.Claims.Count -eq 1) {
            Say ('    EDIT     : on line {0}, "v{1}" -> "v{2}"' -f $r.Line, $r.Claims[0], $r.Proven)
        } else {
            Say ('    CHOOSE   : this row names {0} different versions, so some are HISTORY, not the claim.' -f $r.Claims.Count)
            Say ('               Update only the cell that states what is installed; leave prose alone.')
        }
        Say ''
    }
}

if ($missing.Count -gt 0) {
    Say '===================================================================================='
    Say '  PROPOSAL 2 -- RUNS OUR BUILD, HAS NO LEDGER ROW'
    Say '===================================================================================='
    Say '  A tenant carrying our config that the ledger does not mention is a support exposure:'
    Say '  nobody is accountable for a version nobody recorded. Suggested Section B rows:'
    Say ''
    foreach ($r in ($missing | Sort-Object Provider, Sub)) {
        Say ('  | {0} | {1}.mark43.com (dept {2}) | {3} v{4} | content-verified {5} |' -f
             $r.Sub, $r.Sub, $r.Dept, $r.Provider, $r.Proven, (Get-Date -Format 'yyyy-MM-dd'))
    }
    Say ''
    Say '  (Rob decides which of these belong in the ledger at all -- several are demo/QA tenants'
    Say '   he has already said will be excluded. That decision is tenant_scope.json, not this.)'
    Say ''
}

if ($noversion.Count -gt 0) {
    Say '===================================================================================='
    Say '  PROPOSAL 3 -- THE LEDGER MENTIONS THIS TENANT BUT RECORDS NO VERSION'
    Say '===================================================================================='
    Say '  These are NOT contradictions -- the row exists and states nothing about a version.'
    Say '  Most are Section B.0, the NAME CORRELATION table, whose cells carry a PLATFORM COUNTER'
    Say '  by design. The ledger itself says the counter is not our version, so this is a gap in'
    Say '  the versioned sections (A / B), not an error in B.0. Worth recording the proven version'
    Say '  somewhere a reader would look for it:'
    Say ''
    foreach ($r in ($noversion | Sort-Object Provider, Sub)) {
        Say ('  {0,-32} dept {1,-13} proven {2} v{3}   (mentioned on line(s) {4})' -f
             $r.Sub, $r.Dept, $r.Provider, $r.Proven, ($r.Lines -join ', '))
    }
    Say ''
}

if ($ambiguous.Count -gt 0) {
    Say '===================================================================================='
    Say '  NOT PROPOSED -- THE DEPT ID APPEARS ON MORE THAN ONE LEDGER LINE'
    Say '===================================================================================='
    foreach ($r in $ambiguous) {
        Say ('  {0} (dept {1}) -- lines {2}. Measured {3} v{4}. Refusing to choose a line.' -f
             $r.Sub, $r.Dept, ($r.Lines -join ', '), $r.Provider, $r.Proven)
    }
    Say ''
}

if ($unproven.Count -gt 0) {
    Say '===================================================================================='
    Say ('  NOT PROPOSED -- NO CONTENT PROOF ({0} tenant(s))' -f $unproven.Count)
    Say '===================================================================================='
    Say '  Listed, never silently dropped. "We could not prove it" must not look like "it agrees".'
    foreach ($r in ($unproven | Sort-Object Sub | Select-Object -First 20)) {
        Say ('  {0,-34} {1,-20} {2}' -f $r.Sub, $r.Provider, $r.Why)
    }
    if ($unproven.Count -gt 20) { Say ('  ... and {0} more' -f ($unproven.Count - 20)) }
    Say ''
}

if ($disagree.Count -eq 0 -and $missing.Count -eq 0 -and $noversion.Count -eq 0) {
    Say '  NOTHING TO PROPOSE -- every content-proven tenant already agrees with the ledger.'
    Say '  (That is a real result, not an empty run: the denominator is printed above.)'
}

Say '===================================================================================='
Say '  This tool did NOT modify IMPORT_LEDGER.md and never will. The ledger is hand-authored;'
Say '  its rows carry adjudications a tool cannot reconstruct. Apply what you agree with.'
Say '===================================================================================='

if ($OutFile) {
    $lines | Set-Content $OutFile -Encoding ASCII
    Write-Host ("  written: {0}" -f $OutFile) -ForegroundColor Cyan
}
exit 0
