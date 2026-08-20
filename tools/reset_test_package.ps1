<#
  reset_test_package.ps1 -- Restart the USx Tenant Testing package when a provider JSON is rebuilt.

  PRINCIPLE: A JSON rebuild (version bump) invalidates prior USx Tenant Testing logs -- combo
  routing, set[]/any[], conditions, or defaults may have changed. Logs from a prior
  version no longer line up with the shipped JSON. On every version change we restart
  testing from Test 1 so all logs match the current JSON.

  What it does (provider-agnostic):
    1. Reads the current version from the build script ($Version = "X.Y").
    2. Compares to logs/.test_version (the version the current logs belong to).
    3. If unchanged (and not -Force): no-op, prints "ALIGNED".
    4. If changed: archives all logs/<Entity>/*.txt -> logs/<Entity>/_archive_pre_v<version>/,
       resets every SQVR combo marker ([CONFIRMED]/[FAILED] -> [PENDING]),
       clears the STATUS "LIVE TEST RESULTS" rows, stamps logs/.test_version.

  NOTE (2026-07-01): the old tests/ folder (separate narrative logs) was eliminated --
  logs/<Entity>/<Provider>_v<X.Y>_<Combo>.txt is now the ONLY test log, and
  logs/.test_state.json + logs/.test_version (moved from tests/) are the entity
  fingerprint/version state.

  Called automatically by pipeline.ps1 after a successful build; can also be run manually.

  Usage:
    .\reset_test_package.ps1 -Provider NY_NYSPIN_EJUSTICE
    .\reset_test_package.ps1 -Provider NY_NYSPIN_EJUSTICE -Force   # reset even if version unchanged
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [switch]$Force,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
$provDir  = Join-Path $repoRoot "providers\$Provider"
$docsDir  = Join-Path $provDir "docs"

# Shared active-JSON resolver (handles versioned <PROVIDER>_v<X.Y>.json names)
. "$toolDir\_resolve_provider_json.ps1"
# STATUS/SQVR = "tracking"; TEST_MATRIX = "reports" (2026-07-01 docs/ reorg pilot) --
# resolves to docs/<category>/ for a migrated provider (NJ_NJCJIS), flat docs/ otherwise.
. "$toolDir\_resolve_docs_path.ps1"
$trackingDir = Get-DocsCategoryDir $provDir 'tracking'
$reportsDirForMatrix = Get-DocsCategoryDir $provDir 'reports'

function Say($msg, $color = "White") { if (-not $Quiet) { Write-Host $msg -ForegroundColor $color } }

if (-not (Test-Path $provDir)) {
    Write-Host "  [ERROR] Provider not found: $Provider" -ForegroundColor Red
    exit 1
}

# ── Determine current version from the build script ───────────────────────────
$buildScript = Get-ChildItem (Join-Path $provDir "scripts") -Filter "build_*" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '_mc' -and $_.Name -notmatch '_old' } | Select-Object -First 1

$version = $null
if ($buildScript) {
    $bsText = Get-Content $buildScript.FullName -Raw
    if ($bsText -match '\$Version\s*=\s*"([0-9]+\.[0-9]+)"') { $version = $Matches[1] }
}
if (-not $version) {
    # Fallback: read version from the JSON bundle description
    $json = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
    if ($json -and (Test-Path $json)) {
        $jText = Get-Content $json -Raw
        if ($jText -match "$Provider v([0-9]+\.[0-9]+)") { $version = $Matches[1] }
    }
}
if (-not $version) {
    Write-Host "  [ERROR] Could not determine version for $Provider" -ForegroundColor Red
    exit 1
}

# ── Locate active JSON (needed for per-entity fingerprints) ───────────────────
$activeJson = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $activeJson) { $activeJson = Join-Path $provDir "$Provider.json" }

# ── Per-entity fingerprints + state (entity-aware "block out") ────────────────
# A "blocked" entity whose fingerprint is unchanged is PRESERVED across a rebuild;
# every other entity (open, or blocked-but-changed, or all under -Force) is RESET.
. "$toolDir\get_entity_fingerprints.ps1"
$currentFp = @{}
if (Test-Path $activeJson) {
    try { $currentFp = Get-EntityFingerprints -Path $activeJson } catch { $currentFp = @{} }
}

$logsRoot      = Join-Path $provDir "logs"
if (-not (Test-Path $logsRoot)) { New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null }
$stateFile     = Join-Path $logsRoot ".test_version"      # legacy scalar (kept = global)
$stateJsonPath = Join-Path $logsRoot ".test_state.json"   # authority

# READ fallback for providers not yet migrated off the old tests/ folder (tests/ eliminated
# 2026-07-01, but only for NJ_NJCJIS so far -- every other provider's real blocked-entity state
# still lives at tests/.test_state.json). Without this fallback, $priorEntities comes up EMPTY
# for them, every entity looks "never blocked", and a plain (non -Force) reset call would
# SILENTLY un-confirm all of that provider's already-verified work. Found live auditing CA_CLETS
# (5/5 entities genuinely blocked in tests/.test_state.json, none yet in logs/). WRITE always
# targets logs/ (migrates the provider forward the first time this script runs for it).
$stateJsonReadPath = $stateJsonPath
if (-not (Test-Path $stateJsonReadPath)) {
    $legacyStateJsonPath = Join-Path (Join-Path $provDir "tests") ".test_state.json"
    if (Test-Path $legacyStateJsonPath) { $stateJsonReadPath = $legacyStateJsonPath }
}

$priorEntities = @{}
$priorGlobal   = $null
if (Test-Path $stateJsonReadPath) {
    try {
        $ps = Get-Content $stateJsonReadPath -Raw | ConvertFrom-Json
        if ($ps.entities) { foreach ($p in $ps.entities.PSObject.Properties) { $priorEntities[$p.Name] = $p.Value } }
        if ($ps.global) { $priorGlobal = "$($ps.global)" }
    } catch { $priorEntities = @{}; $priorGlobal = $null }
}

# BLOCK BY VERSION, TEST BY ENTITY (Rob, standing rule): a VERSION CHANGE reopens the WHOLE
# provider -- all 5 entities are re-tested at the new version, with NO fingerprint-preservation
# carryover. Fingerprint-preservation is allowed ONLY on a same-version rebuild (the entity-granular
# "test by entity" workflow within one version). So preservation is gated on the version being
# unchanged; on any version change every entity resets regardless of fingerprint.
$versionChanged = ($priorGlobal -and ($priorGlobal -ne $version))

$entityList = @($currentFp.Keys | Sort-Object)
$resetEntities    = New-Object System.Collections.Generic.List[string]
$preserveEntities = New-Object System.Collections.Generic.List[string]
foreach ($ent in $entityList) {
    $prior     = $priorEntities[$ent]
    $isBlocked = $prior -and $prior.status -eq 'blocked'
    $unchanged = $prior -and ($prior.fingerprint -eq $currentFp[$ent])
    if (-not $Force -and -not $versionChanged -and $isBlocked -and $unchanged) { $preserveEntities.Add($ent) }
    else { $resetEntities.Add($ent) }
}
$fullReset = ($preserveEntities.Count -eq 0)

# Build + persist the new state (do this even on the no-op path so global stays current).
function Write-TestState {
    $newEntities = [ordered]@{}
    foreach ($ent in $entityList) {
        if ($preserveEntities -contains $ent) {
            $newEntities[$ent] = [ordered]@{ version = $priorEntities[$ent].version; fingerprint = $currentFp[$ent]; status = 'blocked' }
        } else {
            $newEntities[$ent] = [ordered]@{ version = $version; fingerprint = $currentFp[$ent]; status = 'open' }
        }
    }
    $stateObj = [ordered]@{ global = $version; entities = $newEntities }
    [System.IO.File]::WriteAllText($stateJsonPath, ([pscustomobject]$stateObj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($stateFile, $version, (New-Object System.Text.UTF8Encoding($false)))
}

if ($resetEntities.Count -eq 0 -and -not $Force) {
    Write-TestState
    $pv = if ($preserveEntities.Count) { " (preserved: $($preserveEntities -join ', '))" } else { "" }
    Say "  ALIGNED: test package already at v$version$pv (no restart needed)" "Green"
    exit 0
}

# ── RESET (scoped to $resetEntities; full-file behavior when $fullReset) ───────

# 1. Archive prior test logs: providers/<PROVIDER>/logs/<Entity>/*.txt (the ONLY test log
#    location since 2026-07-01 -- the old separate tests/ narrative log was eliminated).
#    Entity is the FOLDER name here (filenames are <Provider>_v<Version>_<Combo>.txt, no
#    entity in the name), so scope by folder rather than a filename regex.
$archived = 0
if (Test-Path $logsRoot) {
    $entityDirs = Get-ChildItem $logsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '_archive_pre_v*' }
    foreach ($ed in $entityDirs) {
        if (-not $fullReset -and -not ($resetEntities -contains $ed.Name)) { continue }
        $snippetFiles = Get-ChildItem $ed.FullName -File -ErrorAction SilentlyContinue
        if (-not $snippetFiles) { continue }
        $snippetArchiveDir = Join-Path $ed.FullName "_archive_pre_v$version"
        foreach ($f in $snippetFiles) {
            if (-not (Test-Path $snippetArchiveDir)) { New-Item -ItemType Directory -Path $snippetArchiveDir | Out-Null }
            Move-Item $f.FullName (Join-Path $snippetArchiveDir $f.Name) -Force
            $archived++
        }
    }
}

# Helper: insert provisional-label banner after the first two lines (title + underline)
# of a doc file. Idempotent -- no second copy if already present.
$provisionalBanner = "LABELS PROVISIONAL -- refine wording during manual form use; not a graded test case."
function Add-ProvisionalBanner([string]$filePath) {
    if (-not (Test-Path $filePath)) { return }
    $lines = Get-Content $filePath -Encoding UTF8
    if ($lines | Where-Object { $_ -eq $provisionalBanner }) { return }
    $insertAt = [Math]::Min(2, $lines.Count)
    $newLines  = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $insertAt; $i++) { $newLines.Add($lines[$i]) }
    $newLines.Add($provisionalBanner)
    for ($i = $insertAt; $i -lt $lines.Count; $i++) { $newLines.Add($lines[$i]) }
    Set-Content -Path $filePath -Value $newLines -Encoding UTF8
}

# 2. Reset SQVR combo markers to [PENDING].
#    Full reset -> blanket replace (original behavior). Partial -> only markers in
#    sections for reset entities (SQVR section headers carry "-- <Entity> Entity";
#    cross-cutting sections like RMS BUNDLE/SUMMARY reset whenever anything resets).
$sqvrReset = 0
$sqvrPath = Join-Path $trackingDir "${Provider}_SQVR.txt"
if (Test-Path $sqvrPath) {
    if ($fullReset) {
        $sqvr = Get-Content $sqvrPath -Raw -Encoding UTF8
        $sqvrReset += ([regex]::Matches($sqvr, '\[CONFIRMED\]')).Count
        $sqvrReset += ([regex]::Matches($sqvr, '\[FAILED[^\]]*\]')).Count
        $sqvr = $sqvr -replace '\[CONFIRMED\]', '[PENDING]'
        $sqvr = $sqvr -replace '\[FAILED[^\]]*\]', '[PENDING]'
        Set-Content -Path $sqvrPath -Value $sqvr -NoNewline -Encoding UTF8
    } else {
        $lines = Get-Content $sqvrPath -Encoding UTF8
        $curEntity = $null          # $null = cross-cutting (reset when anything resets)
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($line in $lines) {
            if ($line -match '--\s+([A-Za-z]+)\s+Entity') { $curEntity = $Matches[1] }
            elseif ($line -match '^(RMS BUNDLE|SUMMARY)\s*$') { $curEntity = $null }
            $thisResets = ($null -eq $curEntity) -or ($resetEntities -contains $curEntity)
            if ($thisResets -and ($line -match '\[CONFIRMED\]' -or $line -match '\[FAILED[^\]]*\]')) {
                $sqvrReset += ([regex]::Matches($line, '\[CONFIRMED\]')).Count
                $sqvrReset += ([regex]::Matches($line, '\[FAILED[^\]]*\]')).Count
                $line = $line -replace '\[CONFIRMED\]', '[PENDING]' -replace '\[FAILED[^\]]*\]', '[PENDING]'
            }
            $out.Add($line)
        }
        Set-Content -Path $sqvrPath -Value $out -Encoding UTF8
    }
}
Add-ProvisionalBanner $sqvrPath

# 3. Clear STATUS "LIVE TEST RESULTS" data rows (Entity is column 3 of each row).
$statusCleared = 0
$statusPath = Join-Path $trackingDir "${Provider}_STATUS.txt"
if (Test-Path $statusPath) {
    $lines = Get-Content $statusPath -Encoding UTF8
    $out = New-Object System.Collections.Generic.List[string]
    $inLive = $false
    foreach ($line in $lines) {
        if ($line -match 'LIVE TEST RESULTS') { $inLive = $true; $out.Add($line); continue }
        if ($inLive) {
            # dated data row -> drop only if its Entity is in the reset set (or full reset)
            if ($line -match '^\s+---\s+\d{4}-\d{2}-\d{2}\s+(\S+)') {
                $rowEntity = $Matches[1]
                if ($fullReset -or ($resetEntities -contains $rowEntity)) { $statusCleared++; continue }
                $out.Add($line); continue
            }
            if ($line -match '^\s*\(none yet') { continue }
            if ($line -match '^\s+---\s+-{3,}') {
                $out.Add($line)
                $out.Add("  (none yet -- v$version USx Tenant Testing restarted from Test 1; prior logs archived to logs/<Entity>/_archive_pre_v$version/)")
                continue
            }
            if ($line -match '^\s*$' -or $line -match '^[A-Z]') { $inLive = $false }
        }
        $out.Add($line)
    }
    Set-Content -Path $statusPath -Value $out -Encoding UTF8
}
Add-ProvisionalBanner $statusPath

# 4. Stamp the new test state (.test_state.json authority + legacy .test_version scalar)
Write-TestState

# 5. Regenerate TEST_MATRIX so it never goes stale against the rebuilt JSON.
#    A combo add/remove between versions otherwise leaves the matrix claiming the old
#    count -- which audit_test_coverage -Gate flags as INCONSISTENT (matrix != JSON).
function Get-MatrixCount($matrixPath) {
    if (-not (Test-Path $matrixPath)) { return $null }
    $t = [System.IO.File]::ReadAllText($matrixPath)
    if ($t -match 'COMBO COVERAGE\s*\(\s*\d+\s*/\s*(\d+)\s*\)') { return [int]$Matches[1] }
    if ($t -match 'QIDM SUMMARY\s*\(\s*\d+\s*QIDMs?,\s*(\d+)\s*combos?\)') { return [int]$Matches[1] }
    return $null
}

$matrixPath = Join-Path $reportsDirForMatrix "${Provider}_TEST_MATRIX.txt"
$oldMatrixCount = Get-MatrixCount $matrixPath

# Locate the active JSON via the shared resolver (versioned <PROVIDER>_v<X.Y>.json -> bare
# -> _MC -> _BASE). Matches the resolution used at the top of this script (line ~70).
$activeJson = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $activeJson) { $activeJson = Join-Path $provDir "$Provider.json" }

$matrixRegenerated = $false
$matrixDelta = $null
if (Test-Path $activeJson) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "generate_test_matrix.ps1") -Path $activeJson -OutFile $matrixPath 2>&1 | Out-Null
    if (Test-Path $matrixPath) {
        $matrixRegenerated = $true
        $newMatrixCount = Get-MatrixCount $matrixPath
        if ($null -ne $oldMatrixCount -and $null -ne $newMatrixCount -and $oldMatrixCount -ne $newMatrixCount) {
            $matrixDelta = "$oldMatrixCount -> $newMatrixCount"
        }
    }
}

# 6. Version-stamped TEST_PLAN.json (logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json, root of the logs/
#    self-contained evidence package): archive any stale-version copy (rebuild changed the
#    version, so its plan no longer matches) and regenerate the current one so the driver never
#    runs against a stale plan.
$planRegenerated = $false
if (-not (Test-Path $logsRoot)) { New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null }
$oldPlans = @(Get-ChildItem $logsRoot -Filter "${Provider}_TEST_PLAN_v*.json" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "${Provider}_TEST_PLAN_v${version}.json" })
if ($oldPlans.Count -gt 0) {
    $planArchiveDir = Join-Path $logsRoot "_archive_pre_v$version"
    if (-not (Test-Path $planArchiveDir)) { New-Item -ItemType Directory -Path $planArchiveDir | Out-Null }
    foreach ($p in $oldPlans) { Move-Item $p.FullName (Join-Path $planArchiveDir $p.Name) -Force }
}
if (Test-Path $activeJson) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "emit_test_plan.ps1") -Path $activeJson 2>&1 | Out-Null
    $planRegenerated = Test-Path (Join-Path $logsRoot "${Provider}_TEST_PLAN_v${version}.json")
}

# 6b. THE SPEC PLAN, which this step silently ignored until 2026-08-20.
#     The $oldPlans filter above is "<P>_TEST_PLAN_v*.json"; the spec plan is
#     "<P>_TEST_PLAN_SPEC_v*.json", so "v" never sits where the wildcard expects it and the spec
#     plan was NEITHER archived NOR regenerated by any rebuild. Found on NM_NMLETS_OFML, which
#     reached v2.3 carrying SPEC plans for v2.1 and v2.2 and none for the version it was about to
#     be swept at.
#     WHY IT MATTERS RATHER THAN BEING UNTIDY: test_phase2 step [1] compares the JSON plan against
#     the SPEC plan as an INDEPENDENT statement of what the provider should do -- that is the whole
#     point of having two. Comparing the current JSON plan to a SUPERSEDED spec plan is a comparison
#     against the wrong baseline, and it still prints [PASS], so the check reads green while
#     answering a question nobody asked.
$specArchived = 0; $specRegenerated = $false
$oldSpecs = @(Get-ChildItem $logsRoot -Filter "${Provider}_TEST_PLAN_SPEC_v*.json" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "${Provider}_TEST_PLAN_SPEC_v${version}.json" })
if ($oldSpecs.Count -gt 0) {
    $specArchiveDir = Join-Path $logsRoot "_archive_pre_v$version"
    if (-not (Test-Path $specArchiveDir)) { New-Item -ItemType Directory -Path $specArchiveDir | Out-Null }
    foreach ($s in $oldSpecs) { Move-Item $s.FullName (Join-Path $specArchiveDir $s.Name) -Force }
    $specArchived = $oldSpecs.Count
}
if (Test-Path $activeJson) {
    # -Provider, NOT -Path: emit_test_plan_spec derives from the DEVDOC + METADATA and takes the
    # provider name (the JSON only supplies fieldIds).
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "emit_test_plan_spec.ps1") -Provider $Provider 2>&1 | Out-Null
    $specRegenerated = Test-Path (Join-Path $logsRoot "${Provider}_TEST_PLAN_SPEC_v${version}.json")
}

# 6c. THE PICKLIST SCOPE, which NO ORCHESTRATOR HAS EVER GENERATED (found 2026-08-20).
#     serve_plans exposes TWO endpoints the extension fetches -- /plan/<P> AND /scope/<P>. The scope
#     file (logs/<P>_PICKLIST_SCOPE.json) tells the browser which dropdowns to enumerate, and
#     emit_picklist_scope.ps1 was referenced by exactly nothing in the build or test path: only
#     audit_provider_uniformity (which merely NOTICES it) and the emitter itself.
#     THE EVIDENCE THAT IT WAS ALWAYS A MANUAL STEP: the 9 providers holding a scope file are
#     EXACTLY the 9 tenant-verified ones, and all 11 never-tested providers had none. Somebody ran
#     it by hand once per sweep, every time, and nothing recorded that as a required step -- so
#     "run the scope" failed in the browser for the 10th provider with a bare
#     "no scope for NM_NMLETS_OFML".
#     It is regenerated on every reset rather than created-if-absent on purpose: the scope enumerates
#     the form's FormSelect controls, so a rebuild that adds, removes or renames a dropdown makes the
#     previous scope wrong, not merely old -- and a wrong scope silently under-scopes the capture.
$scopeRegenerated = $false
if (Test-Path $activeJson) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $toolDir "emit_picklist_scope.ps1") -Path $activeJson 2>&1 | Out-Null
    $scopeRegenerated = Test-Path (Join-Path $logsRoot "${Provider}_PICKLIST_SCOPE.json")
}

Say ""
$scope = if ($fullReset) { "all entities" } else { "entities: $($resetEntities -join ', ')" }
Say "  RESET: $Provider test package restarted for v$version -- $scope" "Yellow"
if ($preserveEntities.Count) {
    Say "    - PRESERVED (blocked, unchanged): $($preserveEntities -join ', ')" "Green"
}
Say "    - archived $archived prior log(s) -> logs/<Entity>/_archive_pre_v$version/" "Gray"
Say "    - reset $sqvrReset SQVR marker(s) -> [PENDING]" "Gray"
Say "    - cleared $statusCleared STATUS USx-Tenant-Testing row(s)" "Gray"
Say "    - stamped logs/.test_state.json + .test_version = v$version" "Gray"
if ($matrixRegenerated) {
    Say "    - regenerated ${Provider}_TEST_MATRIX.txt" "Gray"
    if ($matrixDelta) {
        Say "    [WARN] TEST_MATRIX combo count changed ($matrixDelta) -- combos added/removed this rebuild" "Yellow"
    }
} else {
    Say "    [WARN] could not regenerate TEST_MATRIX (no active JSON found at $activeJson)" "Yellow"
}
if ($oldPlans.Count -gt 0) {
    Say "    - archived $($oldPlans.Count) stale-version TEST_PLAN file(s) -> logs/_archive_pre_v$version/" "Gray"
}
if ($planRegenerated) {
    Say "    - regenerated logs/${Provider}_TEST_PLAN_v${version}.json" "Gray"
} else {
    Say "    [WARN] could not regenerate TEST_PLAN (no active JSON found at $activeJson)" "Yellow"
}
if ($specArchived -gt 0) {
    Say "    - archived $specArchived stale-version TEST_PLAN_SPEC file(s) -> logs/_archive_pre_v$version/" "Gray"
}
if ($specRegenerated) {
    Say "    - regenerated logs/${Provider}_TEST_PLAN_SPEC_v${version}.json (the INDEPENDENT devdoc+metadata plan)" "Gray"
} else {
    Say "    [WARN] could not regenerate TEST_PLAN_SPEC -- test_phase2 step [1] will compare against a STALE or ABSENT spec baseline" "Yellow"
}
if ($scopeRegenerated) {
    Say "    - regenerated logs/${Provider}_PICKLIST_SCOPE.json (served as /scope/$Provider)" "Gray"
} else {
    Say "    [WARN] could not regenerate PICKLIST_SCOPE -- the browser scope tool will report 'no scope for $Provider'" "Yellow"
}
Say "  Re-run the full test matrix from Test 1 (see ${Provider}_TEST_MATRIX.txt)" "Gray"

# ------------------------------------------------------------------------------------------------
# IMPORT PROMPT. Added 2026-08-17 -- Rob: "you need to alert when a new version is built to prompt
# for import   iver lost track of all the things you are fixing."
#
# THIS IS THE RIGHT PLACE FOR IT and the reason is worth stating: this block only runs when the
# version ACTUALLY CHANGED (that is the whole trigger for a package reset), so the alert cannot
# fire spuriously on a rebuild-at-same-version and cannot be forgotten on a real bump. Putting it
# in build_report or enforce would fire on every run and be tuned out within a day.
#
# On 2026-08-17 TEN provider versions were bumped in one session and nothing ever said "these now
# need importing" -- every individual gate was green while the queue was invisible. A repo can be
# entirely correct and still be useless to whoever has to install it.
#
# Deliberately NOT a gate: printing only, exit code untouched. Owing an import is a normal state.
#
# *** GATED ON $priorGlobal -ne $version, AND THAT GUARD IS THE WHOLE POINT. ***
# The first version of this block sat at the unconditional tail and fired on EVERY run, including
# -Force resets and same-version reruns where nothing new was built. That is not an alert, it is
# noise, and it would have been tuned out inside a day -- so it FAILED the negative half of LAW 2
# even though it passed the positive half. Caught by testing the no-change case, which is the test
# it is tempting to skip because the feature "obviously works".
# Note the reset can run at an UNCHANGED version (a reopened entity is enough to trigger it), so
# reaching this line does NOT imply a version bump -- the comparison is required, not decorative.
#
# *** EVERY LINE BELOW MUST CONTAIN THE LITERAL "IMPORT", AND THAT IS NOT COSMETIC. ***
# A direct build reaches this script through _build_provider_helpers.ps1, which pipes this output
# through a KEYWORD FILTER (`RESET|archived|reset |cleared|stamped|regenerated|WARN|IMPORT`) before
# displaying it. The first version of this prompt was a bordered box whose lines matched none of
# those keywords, so it was silently swallowed on the ONE path every provider is actually built
# through -- the alert existed, fired correctly, and was invisible. Caught on its first real trigger
# (CA_CLETS v2.25 -> v2.26). If you reword these lines, keep "IMPORT" in each one, or re-check the
# filter in _build_provider_helpers.ps1.
if ("$priorGlobal" -ne "$version") {
Say ""
Say "  *** IMPORT NEEDED: $Provider v$version (was v$priorGlobal) -- the JSON on disk is now AHEAD of every tenant." "Yellow"
Say "  *** IMPORT NEEDED: nothing is verified until it is imported and swept, and a Foundation or LIVE tenant may" "Yellow"
Say "  *** IMPORT NEEDED: need it too -- only a human can confirm that (the capture tool cannot reach those)." "Yellow"
Say "  *** IMPORT NEEDED: full queue across all providers ->  tools\report_import_owed.ps1" "Yellow"
}
exit 0
