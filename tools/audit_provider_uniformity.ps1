<#
  audit_provider_uniformity.ps1 -- ARE THE FINISHED PROVIDERS ACTUALLY THE SAME SHAPE?

  THE DIRECTION NOTHING ELSE CHECKS.
  ---------------------------------
  Two gates look like they already cover this and neither does:

    * audit_structure.ps1  checks ONE provider against a template, IN ISOLATION. Every one of the
      seven tenant-complete providers reports "RESULT: ALL CLEAN" while their artifact sets
      genuinely differ -- because a template says "docs/ must exist", not "IL must carry the same
      files as TX".
    * audit_cross_provider.ps1 is cross-provider but compares JSON CONTENT (8 checks: defaults,
      queryLabels, code types, field types, fieldId casing, RMS autoSelect). It never looks at the
      artifact set on disk.

  So "the finished providers are documented and packaged identically" was an assumption nobody
  measured. Asked to confirm it on 2026-08-10, a hand sweep found: CA_CLETS carrying
  CAD_GUIDE_*.html/.pdf that NO tool in the repo produces (an orphan deliverable), a stray
  logs/.gitkeep on TX_TLETS, a one-off logs/_archive_relabel_v4.10 on NY that matches no other
  provider's archive convention, and CLAUDE.md still describing the docs/ 4-category migration and
  the phases/ retirement as "rolling out, NJ_NJCJIS pilot" when both are 100% complete on all 20.
  Every one of those passed every existing gate.

  WHY THIS IS NOT JUST TIDINESS. The artifact set IS the deliverable for a finished provider: the
  officer guide a department reads, the SQVR a tester reads to decide what to test, the changelog a
  Jira comment is written from. A provider silently missing one of those is not "untidy", it is
  incomplete -- and the reason nobody noticed is that no gate compared it to its peers.

  WHAT IT WILL NOT DO -- AND THIS IS THE HARD PART.
  ------------------------------------------------
  Making providers "identical" must not flatten STATE into STRUCTURE. Three files are LEGITIMATELY
  absent on some providers, and manufacturing them would be a real defect, not a fix:

    * <P>_FORM_REVIEW.txt   -- records that A HUMAN looked at the rendered form. Rob's own manual
      gate. Creating one to satisfy a uniformity check would manufacture a review that never
      happened -- exactly what audit_form_review's header warns against ("a review is a human act
      and must not be manufacturable to satisfy a gate"). IL_LEADS_OFML has none because none was
      recorded. Correct.
    * PENDING_UPDATES.txt   -- flag STATE. Its absence means "no pending reverse-propagation flag",
      which is the good state. Note the naive probe here too: grepping this file for the string
      'FLAG' counts `# [FLAG:...] RESOLVED` comment lines, so CA_CLETS reads as "2 pending flags"
      when it has zero. Count ACTIVE flags, never occurrences of the word.
    * TEST_VALUE_OVERRIDES.txt -- an OPTIONAL per-provider override consumed by emit_test_plan,
      emit_test_plan_spec, generate_test_matrix, import_picklists and _combo_value_resolver.
      Absent = nothing to override. FL/NY/TX/NJ have one; CA_CLETS/HI/IL do not need one.

  Likewise PROVIDER-SPECIFIC content is not divergence: source/ holds each provider's own devdoc
  and metadata, IL carries IL_LEADS_OFML_STATE_BULLETINS.txt + bulletins/ for an ISP bulletin, NY
  carries NY_BASIC_COMBO_RUNSHEET.md. And CA_CLETS/FL_FCIC retain an ARCHIVE-ONLY legacy tests/,
  which audit_structure deliberately accepts because KB docs cite those paths -- that is a reasoned
  decision on record, not drift. Reporting any of these as FAIL would train the next reader to
  ignore this tool.

  So: FAIL on unexplained divergence only. NOTE the allowlisted ones WITH their reason, so the
  allowlist is auditable instead of invisible.

  PRINTS ITS DENOMINATOR (ENGINEERING_STANDARD 4.3). A uniformity check that compared one provider,
  or zero tokens, would report "uniform" -- the same vacuous pass that let audit_sqvr_integrity's
  CHECK 2 compare nothing on 17 of 20 providers while printing PASS (fixed 2026-08-10, same day).
  Fewer than 2 providers in scope is a FAIL, not a clean run.

  SCOPE. Defaults to the tenant-complete providers (State 'ALL-PASS' per _test_status_lib, the same
  classifier portfolio_status / SESSION_STATE use, so the three cannot disagree). A provider still
  mid-build is SUPPOSED to be missing artifacts. -Providers overrides; -All takes every provider.

  Usage: .\audit_provider_uniformity.ps1 [-Providers <list>] [-All] [-Quiet] [-OutFile <path>]
  Exit:  0 = uniform (or divergence fully explained), 1 = unexplained divergence
#>

param(
    [string[]]$Providers,
    [switch]$All,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $toolDir
$provRoot = Join-Path $repoRoot 'providers'

. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_test_status_lib.ps1')

$lines = New-Object System.Collections.Generic.List[string]
function Emit([string]$t, [string]$c = 'Gray') {
    $lines.Add($t) | Out-Null
    if (-not $Quiet) { Write-Host $t -ForegroundColor $c }
}

# ---------------------------------------------------------------------------------------------
# The allowlist. Every entry carries a REASON, because a suppression whose justification lives
# only in someone's head is how a wrong diagnosis outlives its author.
# Key = normalized filename token. Value = why its absence (or presence) is legitimate.
# ---------------------------------------------------------------------------------------------
$optionalByDesign = @{
    '<P>_FORM_REVIEW.txt'      = 'records a HUMAN rendered-form review; manufacturing one would fake the review (Rob''s manual gate)'
    'PENDING_UPDATES.txt'      = 'reverse-propagation flag STATE -- absent means no pending flag, which is the good state'
    'TEST_VALUE_OVERRIDES.txt' = 'OPTIONAL per-provider test-value override; absent means nothing to override'
    '<P>_STATE_BULLETINS.txt'  = 'provider-specific state bulletin log (IL ISP); only exists where a bulletin was issued'
    'bulletins'                = 'provider-specific bulletin PDFs + extracts, companion to <P>_STATE_BULLETINS.txt'
    'NY_BASIC_COMBO_RUNSHEET.md' = 'NY-specific hand runsheet; provider content, not a pipeline artifact'
}

# NOT allowlisted on purpose: '.gitkeep'. A placeholder is only meaningful while its directory is
# empty, so once logs/ carries real captures the file is vestigial -- and it appeared on exactly one
# of six finished providers, which is drift by definition. TX_TLETS's was removed 2026-08-10 with 29
# live entries beside it. Blanket-allowing '.gitkeep' would have hidden that, which is why the first
# version of this allowlist was wrong.

# Directories whose CONTENTS are provider-specific inputs, not pipeline artifacts.
$contentDirs = @('source')

# ---------------------------------------------------------------------------------------------
# TEST-STATE artifacts. These exist as a CONSEQUENCE of tenant testing, so on a provider that has
# never been tested their absence is the CORRECT state, not drift.
#
# Added 2026-08-10 after running the default ALL-PASS scope out to 9 providers (7 tenant-complete
# + AZ_AZDPS + OH_LEADS, both NEVER-TESTED) on Rob's ask to compare them. It reported 14
# divergences of which ELEVEN were this one fact restated -- "no captures yet, so no logs/<Entity>/".
# That is a probe reporting its own scope as a finding, and it buried the 3 real gaps. The default
# scope had hidden the flaw because every provider in it was tested.
#
# The distinction that matters is WHICH SIDE OF TESTING an artifact is born on:
#   PRE-test  (a provider should have it BEFORE its first sweep, so absence IS a real gap):
#             <P>_PICKLIST_SCOPE.json / .console.js -- emit_picklist_scope.ps1 produces these and
#             the browser scope tool CONSUMES them, so they are an input to testing.
#   POST-test (absence is correct until tested):
#             logs/<Entity>/ folders, TENANT_PICKLISTS.json (import_picklists.ps1 writes it FROM a
#             capture download), .test_state.json / .test_version.
# ---------------------------------------------------------------------------------------------
$postTestArtifacts = @(
    'Vehicle','Person','Firearm','Article','Boat',
    'TENANT_PICKLISTS.json','.test_state.json','.test_version'
)
# Which providers in scope have actually been tenant-tested (log-truth, same classifier as above).
$testedState = @{}

# ---------------------------------------------------------------------------------------------
# Scope
# ---------------------------------------------------------------------------------------------
$allDirs = Get-ChildItem $provRoot -Directory | Sort-Object Name
$scope = @()
if ($Providers) {
    $scope = @($allDirs | Where-Object { $Providers -contains $_.Name })
} elseif ($All) {
    $scope = @($allDirs)
} else {
    foreach ($d in $allDirs) {
        $st = Get-ProviderTestState -ProvDir $d.FullName -Name $d.Name
        if ($st.State -eq 'ALL-PASS') { $scope += $d }
    }
}

Emit ("=" * 100)
Emit "  PROVIDER UNIFORMITY AUDIT -- do the finished providers carry the same artifact set?"
Emit ("=" * 100)

if ($scope.Count -lt 2) {
    Emit ""
    Emit "  [FAIL] only $($scope.Count) provider(s) in scope -- a uniformity check needs at least 2." 'Red'
    Emit "         Comparing one provider to itself is a vacuous pass, not a clean run." 'DarkGray'
    if ($OutFile) { $lines -join "`r`n" | Set-Content -Path $OutFile -Encoding ASCII }
    exit 1
}

$scopeLabel = if ($Providers) { 'explicit -Providers' } elseif ($All) { 'ALL providers' } else { 'tenant-complete (ALL-PASS)' }
Emit ""
Emit "  Scope: $scopeLabel -- $($scope.Count) provider(s)"
Emit "         $(($scope | ForEach-Object { $_.Name }) -join ', ')"

foreach ($d in $scope) {
    $st = Get-ProviderTestState -ProvDir $d.FullName -Name $d.Name
    $testedState[$d.Name] = ($st.State -eq 'ALL-PASS' -or $st.State -eq 'PARTIAL' -or $st.State -eq 'HAS-FAIL')
}
$untested = @($scope | Where-Object { -not $testedState[$_.Name] } | ForEach-Object { $_.Name })
if ($untested.Count -gt 0) {
    Emit "         NEVER-TESTED in scope: $($untested -join ', ') -- POST-test artifacts (logs/<Entity>/," 'DarkGray'
    Emit "         TENANT_PICKLISTS.json, .test_state) report [NOTE] for these, not [FAIL]. PRE-test" 'DarkGray'
    Emit "         inputs like <P>_PICKLIST_SCOPE.* still FAIL, because a provider needs those to test." 'DarkGray'
}

# ---------------------------------------------------------------------------------------------
# Collect the normalized artifact token set per provider, per area
# ---------------------------------------------------------------------------------------------
function Normalize([string]$name, [string]$prov) {
    $n = $name
    $n = $n -replace [regex]::Escape($prov), '<P>'
    $n = $n -replace [regex]::Escape($prov.ToLower()), '<p>'
    $n = $n -replace '_v[0-9]+\.[0-9]+', '_v<X.Y>'
    $n = $n -replace '_[0-9]{8}', '_<date>'
    $n = $n -replace '_pre_v<X\.Y>', '_pre_v<X.Y>'
    return $n
}

$areas = [ordered]@{
    'docs/tracking'     = { param($p) Join-Path $p 'docs\tracking' }
    'docs/reports'      = { param($p) Join-Path $p 'docs\reports' }
    'docs/reference'    = { param($p) Join-Path $p 'docs\reference' }
    'docs/deliverables' = { param($p) Join-Path $p 'docs\deliverables' }
    'scripts'           = { param($p) Join-Path $p 'scripts' }
    'logs (top level)'  = { param($p) Join-Path $p 'logs' }
}

$fail = 0; $note = 0; $pass = 0; $tokensCompared = 0

foreach ($area in $areas.Keys) {
    $resolver = $areas[$area]
    $sets = @{}
    foreach ($d in $scope) {
        $dir = & $resolver $d.FullName
        $items = @()
        if (Test-Path $dir) {
            $items = @(Get-ChildItem $dir -Force -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -notmatch '^_archive' } |
                       ForEach-Object { Normalize $_.Name $d.Name })
        }
        $sets[$d.Name] = @($items | Sort-Object -Unique)
    }

    $union = @($sets.Values | ForEach-Object { $_ } | Sort-Object -Unique)
    $tokensCompared += $union.Count

    Emit ""
    Emit "  --- $area  ($($union.Count) distinct artifact token(s)) ---"

    if ($union.Count -eq 0) {
        Emit "      [NOTE] no artifacts in this area on any provider in scope -- nothing to compare" 'Yellow'
        $note++
        continue
    }

    $areaClean = $true
    foreach ($tok in $union) {
        $have    = @($sets.Keys | Where-Object { $sets[$_] -contains $tok } | Sort-Object)
        $missing = @($sets.Keys | Where-Object { $sets[$_] -notcontains $tok } | Sort-Object)
        if ($missing.Count -eq 0) { continue }   # on every provider -- uniform

        $reason = $null
        foreach ($k in $optionalByDesign.Keys) { if ($tok -eq $k) { $reason = $optionalByDesign[$k] } }

        # A POST-test artifact missing ONLY on never-tested providers is correct state, not drift.
        if (-not $reason -and $postTestArtifacts -contains $tok) {
            $missingAllUntested = @($missing | Where-Object { $testedState[$_] }).Count -eq 0
            if ($missingAllUntested) {
                $reason = "POST-test artifact -- absent only on never-tested provider(s), which is the correct state"
            }
        }

        if ($reason) {
            Emit "      [NOTE] $tok" 'Yellow'
            Emit "             on $($have.Count)/$($scope.Count): $($have -join ', ')" 'DarkGray'
            Emit "             ALLOWED: $reason" 'DarkGray'
            $note++
            $areaClean = $false
        }
        elseif ($have.Count -eq 1) {
            Emit "      [FAIL] $tok exists ONLY on $($have[0]) -- unexplained singleton" 'Red'
            Emit "             Either it belongs on all $($scope.Count), or it is an orphan to remove." 'DarkGray'
            $fail++
            $areaClean = $false
        }
        else {
            Emit "      [FAIL] $tok present on $($have.Count)/$($scope.Count), MISSING on: $($missing -join ', ')" 'Red'
            $fail++
            $areaClean = $false
        }
    }
    if ($areaClean) { Emit "      [PASS] identical across all $($scope.Count) provider(s)" 'Green'; $pass++ }
}

# ---------------------------------------------------------------------------------------------
# logs/<Entity>/ -- the five entity folders must exist on every finished provider
# ---------------------------------------------------------------------------------------------
Emit ""
Emit "  --- logs/<Entity>/ folders ---"
$entities = @('Vehicle','Person','Firearm','Article','Boat')
$entClean = $true
foreach ($e in $entities) {
    $tokensCompared++
    $missing = @($scope | Where-Object { -not (Test-Path (Join-Path $_.FullName "logs\$e")) } | ForEach-Object { $_.Name })
    if ($missing.Count -eq 0) { continue }
    # Entity log folders are created BY capture ingest, so on a never-tested provider their absence
    # is the correct state. Only a TESTED provider missing one is a real finding.
    $missingTested = @($missing | Where-Object { $testedState[$_] })
    if ($missingTested.Count -gt 0) {
        Emit "      [FAIL] logs/$e missing on TESTED provider(s): $($missingTested -join ', ')" 'Red'
        $fail++; $entClean = $false
    } else {
        Emit "      [NOTE] logs/$e absent on never-tested: $($missing -join ', ') -- correct state" 'Yellow'
        $note++; $entClean = $false
    }
}
if ($entClean) { Emit "      [PASS] all 5 entity folders present on all $($scope.Count) provider(s)" 'Green'; $pass++ }

# ---------------------------------------------------------------------------------------------
# Legacy layout that should be GONE everywhere (structure, not state)
# ---------------------------------------------------------------------------------------------
Emit ""
Emit "  --- retired layout (phases/ and live tests/) ---"
$legacyClean = $true
foreach ($d in $scope) {
    $tokensCompared++
    if (Test-Path (Join-Path $d.FullName 'phases')) {
        Emit "      [FAIL] $($d.Name) still has phases/ -- retired; git history is authoritative" 'Red'
        $fail++; $legacyClean = $false
    }
    $t = Join-Path $d.FullName 'tests'
    if (Test-Path $t) {
        $live = @(Get-ChildItem $t -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^_archive' })
        if ($live.Count -gt 0) {
            Emit "      [FAIL] $($d.Name) tests/ has $($live.Count) LIVE item(s) -- pipeline v2 eliminated tests/" 'Red'
            $fail++; $legacyClean = $false
        } else {
            Emit "      [NOTE] $($d.Name) tests/ is ARCHIVE-ONLY -- accepted (KB docs cite those paths)" 'Yellow'
            $note++; $legacyClean = $false
        }
    }
}
if ($legacyClean) { Emit "      [PASS] no phases/ and no tests/ on any provider in scope" 'Green'; $pass++ }

# ---------------------------------------------------------------------------------------------
# Verdict -- with the denominator
# ---------------------------------------------------------------------------------------------
Emit ""
Emit ("=" * 100)
Emit "  COMPARED: $($scope.Count) provider(s) x $tokensCompared artifact token(s)/check(s)"
if ($fail -eq 0) {
    Emit "  [PASS] uniform -- $pass area(s) identical, $note explained divergence(s)" 'Green'
} else {
    Emit "  [FAIL] $fail unexplained divergence(s) ($pass area(s) clean, $note explained)" 'Red'
    Emit "         An unexplained singleton is usually an ORPHAN (no tool produces it) or a" 'DarkGray'
    Emit "         MISSING deliverable. Decide which, then either propagate it or delete it --" 'DarkGray'
    Emit '         and if it is legitimately optional, add it to $optionalByDesign WITH a reason.' 'DarkGray'
}
Emit ("=" * 100)

if ($OutFile) { $lines -join "`r`n" | Set-Content -Path $OutFile -Encoding ASCII }
exit ([int]($fail -gt 0))
