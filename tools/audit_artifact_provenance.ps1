<#
  audit_artifact_provenance.ps1 -- IS THIS EVIDENCE, OR SOMETHING SHAPED LIKE EVIDENCE?

  THE AXIS NOTHING ELSE CHECKS
  ----------------------------
  This repo has ~40 gates and every one of them asks a CORRECTNESS question: does the built request
  match the devdoc, the metadata, the logs, the plan. Not one asks a PROVENANCE question: was this
  artifact actually PRODUCED BY A TOOL, and does it describe the version that is here NOW?

  The whole trust model rests on tool output. `enforce` reads report FILES, not live tools. Reviewers
  read `docs/`. A restarted session reads SESSION_STATE. So an artifact that merely LOOKS like tool
  output is indistinguishable from one that is -- and this repo has already been bitten by that in
  five different ways:

    * FROZEN OUTPUT WEARING A TOOL'S NAME (found 2026-08-19, and it is what motivated this gate).
      `audit_session_state.ps1` and `verify_claims.ps1` sat in the REPO ROOT next to the real ones in
      `tools/`. They contained NO POWERSHELL AT ALL -- just captured console text from 2026-07-30
      asserting "[PASS] all 6 provider version(s) named match the active JSON" and "111 lines". Six
      providers, when there are twenty. A frozen green board, in the place where a reader most expects
      a gate. `audit_ps51_parse` only scans `tools/*.ps1`, so nothing in the repo had ever looked at
      them.
    * A STALE REPORT MAKING A FIXED PROVIDER LOOK BROKEN. NM_NMLETS_OFML, 2026-08-19: enforce kept
      reporting "2 metadata divergence FAIL(s)" AFTER the registry rows were written, because it reads
      METADATA_AUDIT_*.txt while the live tool already said 100 PASS / 0 FAIL.
    * A REPORT REGENERATED FROM A MUTANT. usx-tooling 5c: mutation-testing with `enforce` rewrites
      VALIDATOR/VERIFY/METADATA/CAD reports from a JSON state that no longer exists, and
      `git checkout` of the JSON does not undo them.
    * A STATE FILE CONTRADICTING THE LOGS. `.test_state.json` was authoritative until it wasn't;
      the standing rule is now "test status from logs, NOT the state file".
    * PROSE ASSERTING TOTALS NOBODY COMPUTED. The SQVR carried "17 combos" against a JSON holding 12
      for nine version bumps, until audit_sqvr_integrity started comparing.

  Every one of those is the same shape: EVIDENCE THAT CANNOT BE FALSIFIED BY ITS OWN CONTENT.

  FOUR CLASSES
  ------------
    F FROZEN     a *.ps1 that contains no PowerShell but does contain gate-style output. It is a
                 PHOTOGRAPH of a gate passing. [FAIL] -- this is the only class that blocks, because
                 a reader cannot tell it from the real tool and it can never disagree with reality.
    S STALE      a docs/ report older than the active JSON it purports to describe. [WARN] -- enforce
                 PHASE 1 already watches a hand-picked ANCILLARY subset; this covers EVERY report and
                 names each one, because the subset was chosen before half these reports existed.
    U UNSOURCED  a file in docs/reports/ whose name prefix appears in NO tool under tools/. Nothing
                 in the repo can generate it, so it is hand-authored evidence sitting where readers
                 expect machine output. [NOTE] -- deliberately not a FAIL: a legitimately renamed
                 generator would trip it, so it needs a human glance, not a block.
    O ORPHAN     a report whose embedded version does not match any JSON present. [NOTE].

  WHAT IT DOES NOT DO: it does not judge whether the CONTENT is correct -- that is every other gate's
  job. It only asks whether the artifact is what it claims to be. A frozen file full of accurate
  numbers is still frozen.

  ALWAYS PRINTS ITS DENOMINATORS, and a run that examined nothing says [NO-VERDICT] rather than
  reporting clean -- the failure mode this gate exists to catch would otherwise apply to the gate.

  Usage: .\audit_artifact_provenance.ps1 [-Provider <NAME>] [-Quiet] [-OutFile <path>]
#>

param([string]$Provider, [switch]$Quiet, [string]$OutFile)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') { $script:lines += $s; if (-not $Quiet) { Write-Host $s -ForegroundColor $c } }

Out-Line ''
Out-Line ('=' * 96)
Out-Line '  ARTIFACT PROVENANCE -- is this evidence, or something shaped like evidence?'
Out-Line ('  ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Out-Line ('=' * 96)

$frozen = @(); $stale = @(); $unsourced = @(); $orphan = @()
$nPs1 = 0; $nReports = 0; $nProv = 0

# ---------- class F: frozen output wearing a .ps1 name (scan the WHOLE repo, not just tools/) ----
# The real tools all contain at least one of these tokens. Output files contain none of them but do
# contain gate furniture ([PASS]/[FAIL]/==== banners). Requiring BOTH conditions is what keeps a
# legitimately tiny helper script from being accused.
$codeTokens = '(\$[A-Za-z_]|param\(|function\s|Write-Host|foreach\s*\(|if\s*\(|\[CmdletBinding|Get-ChildItem|Set-Content)'
foreach ($f in @(Get-ChildItem $repoRoot -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $nPs1++
    $txt = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $txt) { continue }
    $hasCode   = $txt -match $codeTokens
    $looksLikeOutput = ($txt -match '\[(PASS|FAIL|WARN|INFO|NOTE)\]') -or ($txt -match '={10,}')
    if (-not $hasCode -and $looksLikeOutput) {
        $rel = $f.FullName.Replace($repoRoot, '').TrimStart('\')
        $twin = Join-Path $toolDir $f.Name
        $note = if ((Test-Path $twin) -and ($f.FullName -ne (Resolve-Path $twin).Path)) { " -- IMPERSONATES the real tools\$($f.Name)" } else { '' }
        $frozen += "$rel ($($f.Length)b)$note"
    }
}

# ---------- per-provider classes S / U / O ----------
$provDirs = @(Get-ChildItem (Join-Path $repoRoot 'providers') -Directory |
              Where-Object { Test-Path (Join-Path $_.FullName 'scripts') })
if ($Provider) { $provDirs = @($provDirs | Where-Object { $_.Name -ieq $Provider }) }

# every literal report-name prefix any tool can write (class U's denominator)
$toolText = ''
foreach ($t in @(Get-ChildItem $toolDir -Filter '*.ps1' -File)) { $toolText += (Get-Content $t.FullName -Raw) }

foreach ($d in $provDirs) {
    $p = $d.Name
    $json = Get-ProviderRootJson -ProvDir $d.FullName -Provider $p
    if (-not $json) { continue }
    $nProv++
    $jsonTime = (Get-Item $json).LastWriteTime
    $ver = ''
    $m = [regex]::Match((Split-Path $json -Leaf), '_v([0-9]+\.[0-9]+)\.json$'); if ($m.Success) { $ver = $m.Groups[1].Value }

    $repDir = Join-Path $d.FullName 'docs\reports'
    if (-not (Test-Path $repDir)) { $repDir = Join-Path $d.FullName 'docs' }
    foreach ($r in @(Get-ChildItem $repDir -File -ErrorAction SilentlyContinue)) {
        $nReports++
        # S: older than the JSON it describes
        if ($r.LastWriteTime -lt $jsonTime.AddMinutes(-1)) {
            $mins = [int]($jsonTime - $r.LastWriteTime).TotalMinutes
            $stale += ("{0,-22} {1,-42} {2} min older than the JSON" -f $p, $r.Name, $mins)
        }
        # U: no tool contains this file's name prefix
        $stem = ($r.BaseName -replace [regex]::Escape($p), '') -replace '^[_-]+|[_-]+$', ''
        if ($stem.Length -ge 4 -and $toolText -notmatch [regex]::Escape($stem)) {
            $unsourced += ("{0,-22} {1}" -f $p, $r.Name)
        }
        # O: names a version that is not the active one and no JSON of that version exists
        $vm = [regex]::Match($r.Name, '_v([0-9]+\.[0-9]+)')
        if ($vm.Success -and $vm.Groups[1].Value -ne $ver) {
            if (-not (Test-Path (Join-Path $d.FullName ("{0}_v{1}.json" -f $p, $vm.Groups[1].Value)))) {
                $orphan += ("{0,-22} {1} names v{2}; active is v{3}" -f $p, $r.Name, $vm.Groups[1].Value, $ver)
            }
        }
    }
}

Out-Line ''
Out-Line ("  EXAMINED: {0} .ps1 file(s) repo-wide / {1} report(s) across {2} provider(s)" -f $nPs1, $nReports, $nProv)
if ($nPs1 -eq 0 -or $nProv -eq 0) {
    Out-Line '  [NO-VERDICT] nothing was examined -- that is not a clean result' 'Red'
    if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII }
    exit 0
}
Out-Line ''
foreach ($x in $frozen)    { Out-Line "  [FAIL] F FROZEN     $x" 'Red' }
foreach ($x in $stale)     { Out-Line "  [WARN] S STALE      $x" 'Yellow' }
foreach ($x in $unsourced) { Out-Line "  [NOTE] U UNSOURCED  $x" 'Yellow' }
foreach ($x in $orphan)    { Out-Line "  [NOTE] O ORPHAN     $x" 'Yellow' }
if (-not ($frozen.Count + $stale.Count + $unsourced.Count + $orphan.Count)) {
    Out-Line '  [PASS] every artifact is attributable, current, and generated by a tool' 'Green'
}

Out-Line ''
Out-Line ("  F frozen {0} / S stale {1} / U unsourced {2} / O orphan {3}" -f $frozen.Count, $stale.Count, $unsourced.Count, $orphan.Count)
Out-Line '  F is the only blocking class: a frozen file cannot disagree with reality, so its PASS is not evidence.'
Out-Line ('=' * 96)
if ($OutFile) { $lines | Set-Content $OutFile -Encoding ASCII; if (-not $Quiet) { Write-Host "  -> $OutFile" -ForegroundColor Cyan } }
if ($frozen.Count) { exit 1 } else { exit 0 }
