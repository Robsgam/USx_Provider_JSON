<#
  audit_registry_currency.ps1 -- is each ACCEPTED_DIVERGENCES row's PREMISE still true?

  WHY THIS EXISTS (2026-08-03, from a defect that cost most of a session)
    Asked whether any open decision blocked FL_FCIC testing, I found this row:

      VehicleRegistrationQuery | FRQLicensePlateNumber | VehicleMakeCode |
      promoted-to-any-UNJUSTIFIED-NEEDS-RULING | "OPEN QUESTION ... NOT an approval.
      FRQLicensePlateNumber and FRQVehicleIdentificationNumber both carry VehicleMakeCode and
      vehicleYear in any[] ... Rob's call."

    It read as a live open decision. Rob approved the fix it asked for -- remove the fields, bump
    to v7.18. NONE OF THAT WAS NEEDED: commit 7b13a67c had already removed them FOUR DAYS EARLIER
    as v7.14. The row had outlived the fix that closed it. Verifying against the emitted JSON took
    under a minute and refuted the row outright; without that check the cost was a rebuild, a new
    version, and a second tenant import for a change already shipped.

    The row was NOT over-broad -- it silenced nothing, exactly as its author intended. It was
    STALE. Nothing in the repo asked whether a recorded decision still describes a real condition.

  WHAT OWNS WHAT (LAW 4 -- checked before building this)
    audit_suppression_scope  -- how WIDE is a row's suppression vs how wide it was granted (breadth)
    audit_requirement_fidelity -- [NOTE] REGISTRY OVER-SUPPRESSION RISK when an unbuilt-class row
                                  names a BUILT combo (that is existence-class staleness; NOT
                                  re-implemented here, deliberately)
    THIS TOOL                -- do the DIRECTION-class rows (to-any / to-set) still describe the
                                JSON? That question had no owner.

  THE CHECK
    A direction-class row asserts a placement:
      to-any  (promoted-to-any, demoted-to-any, added-to-any, promoted-to-any-*) -> "field rides in
              that combo's any[]"
      to-set  (promoted-to-set)                                                  -> "field sits in
              that combo's set[]"
    If the named (query, keyRef) combo exists and the field is in NEITHER its set[] nor its any[],
    the premise is gone -> [FAIL] STALE. If the combo itself no longer exists -> [FAIL] STALE.

  DELIBERATELY CONSERVATIVE -- read a PASS narrowly
    A false STALE would send someone to DELETE a legitimate adjudication, which is worse than
    missing one. So a field counts as PRESENT if it matches in ANY namespace: raw sourceFields,
    attribute targetFields, attribute names, or by canon-token containment either direction
    (so a row saying 'PurposeCode' is satisfied by a combo carrying 'CaRequestPurposeCode', and
    no hand-maintained alias table is needed -- the class of false finding that forced one onto
    audit_requirement_fidelity).
    Consequence: this tool UNDER-reports. A PASS means "no row is provably stale", never "every
    row was verified". 'other'-class and existence-class rows are counted as NOT-CHECKABLE and
    printed in the denominator -- a check that parses nothing passes everything.

  Usage:
    .\audit_registry_currency.ps1 -Provider FL_FCIC
    .\audit_registry_currency.ps1 -All [-Quiet] [-OutFile <path>]
    .\audit_registry_currency.ps1 -Provider FL_FCIC -Path <replica.json>   # aim at a replica
#>

param(
    [string]$Provider,
    [switch]$All,
    [string]$Path,
    [switch]$Quiet,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $toolDir '..')).Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_divergence_rules.ps1')
. (Join-Path $toolDir '_resolve_docs_path.ps1')

$lines = @()
function Out-Line([string]$s, [string]$c = 'Gray') {
    $script:lines += $s
    if (-not $Quiet) { Write-Host $s -ForegroundColor $c }
}

# Canon: same shape as audit_requirement_fidelity's, minus the alias table -- containment
# matching below covers what aliases did, without a list to keep current.
function Canon([string]$t) {
    $k = ($t -replace '[^A-Za-z0-9]', '').ToLower()
    if ($k.Length -gt 2 -and $k.EndsWith('dh'))  { $k = $k.Substring(0, $k.Length - 2) }
    if ($k.Length -gt 3 -and $k.EndsWith('cch')) { $k = $k.Substring(0, $k.Length - 3) }
    return $k
}

# Does $needle appear among $haystack tokens, in either containment direction?
function Test-TokenPresent([string]$needle, $haystack) {
    $n = Canon $needle
    if (-not $n) { return $true }        # nothing to look for -> do not accuse
    foreach ($h in @($haystack)) {
        $k = Canon "$h"
        if (-not $k) { continue }
        if ($k -eq $n) { return $true }
        if ($k.Length -ge 3 -and $n.Length -ge 3) {
            if ($k.Contains($n) -or $n.Contains($k)) { return $true }
        }
    }
    return $false
}

function Get-BuiltCombos([string]$jsonPath, [string]$provName) {
    # (query, keyRef) -> @{ Set/Any/Names } in EVERY namespace the row's field might be written in.
    $raw = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $map = @{}
    foreach ($b in $raw.bundles) {
        foreach ($c in $b.configurations) {
            if ("$($c.type)" -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ("$($c.provider)" -eq 'RMS' -or "$($c.name)" -match '^RMS ') { continue }
            $q = "$($c.name)" -replace "^$([regex]::Escape($provName))_", ''

            # sourceField -> targetField for THIS QIDM. Used ONLY to translate a combination's OWN
            # set[]/any[] into wire space -- NEVER as a presence pool of its own.
            #
            # THE BUG THIS COMMENT EXISTS TO PREVENT (caught by LAW 2 injection, 2026-08-03): the
            # first version added every attribute targetField/name in the QIDM to the pool, to be
            # tolerant about namespaces. That made the gate blind to the exact defect it was built
            # for -- FL's stale row claims VehicleMakeCode rides in FRQLicensePlateNumber's any[],
            # and VehicleMakeCode IS an attribute of VehicleRegistrationQuery (it is on the RQ
            # combos), so the QIDM-wide pool reported it PRESENT and the row read as current.
            # Presence must be evaluated PER COMBINATION or this check cannot fail.
            $s2t = @{}
            foreach ($at in @($c.attributes)) {
                $tf = "$($at.targetField)"; if (-not $tf) { continue }
                foreach ($sf in @($at.sourceField)) { if ("$sf") { $s2t[(Canon $sf)] = $tf } }
            }

            foreach ($cm in @($c.combinations)) {
                $kr = "$($cm.keyReference)"; if (-not $kr) { continue }
                $s = @($cm.requirements.set | Where-Object { $_ })
                $a = @($cm.requirements.any | Where-Object { $_ })
                # this combination's own fields, in BOTH namespaces
                $pool = @()
                foreach ($f in (@($s) + @($a))) {
                    $pool += "$f"
                    $k = Canon "$f"
                    if ($s2t.ContainsKey($k)) { $pool += $s2t[$k] }
                }
                $entry = @{ Query = $q; KeyRef = $kr; Set = $s; Any = $a; Pool = $pool }
                $map["$q|$kr"] = $entry
                # keyRef-only fallback, used ONLY when the row's query does not resolve
                if (-not $map.ContainsKey("*|$kr")) { $map["*|$kr"] = $entry }
            }
        }
    }
    return $map
}

function Invoke-ProviderCheck([string]$provName, [string]$jsonOverride) {
    $pd = Join-Path $repoRoot "providers\$provName"
    if (-not (Test-Path $pd)) { Out-Line "  [SKIP] $provName -- no provider directory" 'DarkYellow'; return $null }

    $reg = Find-DocsPath $pd 'tracking' "${provName}_ACCEPTED_DIVERGENCES.txt"
    if (-not $reg -or -not (Test-Path $reg)) {
        Out-Line "  [PASS] $provName -- no accepted-divergence registry (nothing to go stale)" 'Green'
        return @{ Rows = 0; Checkable = 0; Stale = 0; NotCheckable = 0 }
    }

    $jp = if ($jsonOverride) { $jsonOverride } else { Get-ProviderRootJson -ProvDir $pd -Provider $provName }
    if (-not $jp -or -not (Test-Path $jp)) {
        # refuse loudly: a tool that cannot run has NOT passed
        Out-Line "  [FAIL] $provName -- could not resolve the active JSON; verdict WITHHELD (not a pass)" 'Red'
        return @{ Rows = 0; Checkable = 0; Stale = 1; NotCheckable = 0; Withheld = $true }
    }

    $built = Get-BuiltCombos $jp $provName
    $rows = 0; $checkable = 0; $stale = 0; $notCheckable = 0
    $findings = @()

    foreach ($line in (Get-Content $reg)) {
        $t = "$line".Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $parts = $t -split '\|'
        if ($parts.Count -lt 4) { continue }
        $rows++

        $query  = $parts[0].Trim()
        $keyRef = $parts[1].Trim()
        $field  = $parts[2].Trim()
        $rule   = $parts[3].Trim()

        $cls = Get-DivergenceRuleClass $rule
        # The NEEDS-RULING variant classes as 'other' (licenses nothing, by design) but still makes
        # a placement claim. Recover direction from the rule STRING so today's defect is caught.
        if ($cls -eq 'other') {
            if ($rule -match '^promoted-to-any|^demoted-to-any|^added-to-any') { $cls = 'to-any' }
            elseif ($rule -match '^promoted-to-set')                           { $cls = 'to-set' }
        }

        if ($cls -notin @('to-any', 'to-set')) { $notCheckable++; continue }
        # a row naming a devdoc item rather than a built combo cannot be checked this way
        if ($keyRef -match '^\(' -or -not $keyRef) { $notCheckable++; continue }

        $key = "$query|$keyRef"
        $combo = if ($built.ContainsKey($key)) { $built[$key] } elseif ($built.ContainsKey("*|$keyRef")) { $built["*|$keyRef"] } else { $null }

        if (-not $combo) {
            $checkable++; $stale++
            $findings += "       [STALE] $query / $keyRef ($rule) -- no such built combination any more; the row describes a combo that is gone"
            continue
        }

        $checkable++
        if (-not (Test-TokenPresent $field $combo.Pool)) {
            $stale++
            $where = if ($cls -eq 'to-any') { 'any[]' } else { 'set[]' }
            $findings += "       [STALE] $query / $keyRef ($rule) -- claims '$field' rides in $where, but it is in NEITHER set[] nor any[] nor the attribute map. Premise fixed away; retire the row."
        }
    }

    if ($stale -gt 0) {
        Out-Line "  [FAIL] $provName -- $stale stale row(s) of $checkable checkable ($rows total, $notCheckable not-checkable)" 'Red'
        foreach ($f in $findings) { Out-Line $f 'Red' }
    } else {
        Out-Line "  [PASS] $provName -- 0 stale of $checkable checkable row(s) ($rows total, $notCheckable not-checkable)" 'Green'
    }
    return @{ Rows = $rows; Checkable = $checkable; Stale = $stale; NotCheckable = $notCheckable }
}

Out-Line ''
Out-Line '===================================================================================='
Out-Line '  ACCEPTED-DIVERGENCE REGISTRY CURRENCY -- is each row''s premise still true?'
Out-Line '  Direction-class rows only (to-any / to-set). Conservative: a PASS means no row is'
Out-Line '  PROVABLY stale, NOT that every row was verified. See header.'
Out-Line '===================================================================================='
Out-Line ''

$targets = @()
if ($All) {
    $targets = Get-ChildItem (Join-Path $repoRoot 'providers') -Directory | Select-Object -ExpandProperty Name | Sort-Object
} elseif ($Provider) {
    $targets = @($Provider)
} else {
    Write-Host 'Specify -Provider <NAME> or -All' -ForegroundColor Yellow
    exit 2
}

$tRows = 0; $tCheck = 0; $tStale = 0; $tNot = 0; $provsWithStale = 0
foreach ($p in $targets) {
    $r = Invoke-ProviderCheck $p $Path
    if (-not $r) { continue }
    $tRows += $r.Rows; $tCheck += $r.Checkable; $tStale += $r.Stale; $tNot += $r.NotCheckable
    if ($r.Stale -gt 0) { $provsWithStale++ }
}

Out-Line ''
Out-Line '------------------------------------------------------------------------------------'
Out-Line "  TOTALS: $tRows registry row(s) / $tCheck CHECKABLE / $tStale STALE / $tNot not-checkable"
Out-Line "          providers with stale rows: $provsWithStale of $($targets.Count)"
if ($tCheck -eq 0 -and $tRows -gt 0) {
    Out-Line '  [FAIL] parsed rows but checked ZERO of them -- this run is not evidence.' 'Red'
    $tStale = [Math]::Max($tStale, 1)
} elseif ($tStale -eq 0) {
    Out-Line '  A stale row is a CLOSED decision still reading as open. None found.' 'Green'
}
Out-Line '------------------------------------------------------------------------------------'
Out-Line ''

if ($OutFile) { $lines | Set-Content -Path $OutFile -Encoding ASCII }
if ($tStale -gt 0) { exit 1 } else { exit 0 }
