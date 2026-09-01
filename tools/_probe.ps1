# _probe.ps1 -- THE PROBE HARNESS. Primitives for answering an ad-hoc question about the portfolio
# without re-deriving the things that are easy to get wrong.
#
# WHY THIS EXISTS
# ---------------
# Rob, 2026-09-01: "every thing we have been building should make the error rate decrease not
# increase." On 2026-08-31 twelve of my measurements were wrong before they were right, and THREE of
# them briefly looked like real portfolio findings -- one of them handed the operator apparent
# evidence that we were deleting queries and their logs, while he was asking exactly that question.
#
# EVERY ONE OF THEM HAPPENED IN A THROWAWAY PROBE, NEVER IN A COMMITTED GATE. The gates have
# infrastructure: shared resolvers, printed denominators, LAW 2 mutation proof. The probes had none,
# and probes are how most questions get answered. Sorted by root cause:
#
#   bash <-> PowerShell boundary (6):  a git-bash path /c/... became C:\c\... and a plan file read as
#     EMPTY, so a 118-test plan was diffed against nothing and reported "28 combos lose coverage";
#     `-Allow A,B` was stringified by `powershell -File` and matched nothing; `${j//\//\\}` and
#     `$(...)` went unexpanded inside nested quotes and every count read 0; `$?` after a pipe returned
#     grep's status instead of the tool's; `grep | head || echo missing` could never report missing.
#   RE-DERIVING WHAT THE REPO ALREADY HAS (4):  the emitted QIDM type is QUERYINPUTDATAMAPPING and I
#     wrote QUERYINPUTDATAMAP (-> "combos: 0"); Get-FiringKeyRef is POSITIONAL and I passed invented
#     -Qidm/-Filled (-> all 8 fills "NOTHING FIRES" on a JSON that routes all 8); the metadata XML has
#     a DEFAULT NAMESPACE and my unprefixed XPath returned nothing (-> "OH_LEADS defines no
#     DriverLicenseQuery variants"); provider dirs were hand-globbed (-> zero providers enumerated).
#   NO ABORT ON A VACUOUS RESULT (2):  zeros were formatted into tidy tables and read as findings.
#
# THE PROSE FIX WAS ALREADY TRIED AND DID NOT WORK. usx-tooling Step 8 ("PROBE HYGIENE AND HONEST
# VERIFICATION") was written 2026-08-05 after the previous round of exactly this. It says validate
# against a known answer, print the denominator, make sure the check can fail. It was read this
# session and every rule in it was still broken -- because reaching for a shared module from inside a
# bash one-liner is awkward, and writing the glob takes five seconds. Advice without a mechanism does
# not change behaviour; that is the same conclusion this repo reached about flags, gates and the
# rendered-form review.
#
# THE RULE THAT COMES WITH THIS FILE
# ----------------------------------
#   A PROBE IS A .ps1 FILE THAT DOT-SOURCES THIS MODULE. NEVER A BASH ONE-LINER.
# That single rule deletes the whole boundary class by construction: no path translation, no array
# stringification, no pipeline exit codes, no nested-quote expansion. Measured against 2026-08-31,
# 10 of the 12 slips become impossible; the other two (a bad .NET format specifier and a typo) failed
# LOUDLY on first run, which is the acceptable kind.
#
# AND WHEN A PROBE IS WORTH RE-ASKING, GRADUATE IT to tools/_probes/<name>.ps1 with a header saying
# what it answers -- as sweep_dead_fill.ps1 and adjudicate_state_gate.ps1 were on 2026-08-31. That is
# how a throwaway becomes reviewed infrastructure instead of being re-derived next month.
#
# WHAT THIS IS NOT: not a gate, not an orchestrator, and it must never be dot-sourced by one. Gates
# own their own resolution so their behaviour is auditable in one file. This is scaffolding for
# ANSWERING QUESTIONS, and it deliberately throws rather than returning an empty result.
#
# Usage:
#   . "$PSScriptRoot\_probe.ps1"          (from a .ps1 in tools/ or tools/_probes/)
#   $p = Get-ProbeProviders
#   $q = Get-ProbeQidms -Provider MD_METERS -Entity Person
#   Get-ProbeFiring -Provider MD_METERS -Entity Person -Fills @{ OperatorLicenseNumber='D1' }

$ErrorActionPreference = 'Stop'

$script:ProbeRepo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:ProbeTools = Join-Path $script:ProbeRepo 'tools'

# Canonical helpers. Dot-sourced HERE so a probe never re-implements them.
# NOT dot-sourced: get_entity_fingerprints.ps1 -- it opens with its own param($Path,$OutFile) block,
# which would execute in the caller's scope and null out their parameters (audit_test_coverage
# documents having to save/restore around it).
. (Join-Path $script:ProbeTools '_resolve_provider_json.ps1')
. (Join-Path $script:ProbeTools '_resolve_provider_xml.ps1')
. (Join-Path $script:ProbeTools '_sim_helpers.ps1')
. (Join-Path $script:ProbeTools '_metadata_parse.ps1')
. (Join-Path $script:ProbeTools '_divergence_rules.ps1')

function Get-ProbeRepoRoot { return $script:ProbeRepo }

# ---------------------------------------------------------------------------------------------
# ASSERTIONS -- the point of the harness. A probe that cannot tell "found nothing" from
# "never looked" is not a probe (ENGINEERING_STANDARD 4.3).
# ---------------------------------------------------------------------------------------------

# THROWS on zero. Use it on every count a conclusion rests on. This is the guard that was missing
# when an empty plan file produced "28 combos lose coverage" -- the probe had no way to notice it had
# read nothing, so it formatted the nothing into a table.
function Assert-ProbeNonZero {
    param([Parameter(Mandatory)][AllowNull()]$Count, [Parameter(Mandatory)][string]$What)
    $n = 0
    if ($null -ne $Count) { if ($Count -is [array]) { $n = $Count.Count } else { $n = [int]$Count } }
    if ($n -le 0) { throw "PROBE ABORT: $What measured ZERO. Refusing to report -- fix the probe, do not report the zero." }
    return $n
}

# ---------------------------------------------------------------------------------------------
# PROVIDERS -- DERIVED, never globbed. A hand-written glob returned zero providers and the sweep
# printed a perfectly formatted table of nothing for all 20.
# ---------------------------------------------------------------------------------------------
function Get-ProbeProviders {
    param([switch]$AllPassOnly)
    $dirs = @(Get-ChildItem (Join-Path $script:ProbeRepo 'providers') -Directory |
              Where-Object { Test-Path (Join-Path $_.FullName 'scripts') } | Sort-Object Name)
    [void](Assert-ProbeNonZero $dirs.Count 'provider directories')
    $names = @($dirs | ForEach-Object { $_.Name })
    if ($AllPassOnly) {
        . (Join-Path $script:ProbeTools '_test_status_lib.ps1')
        $names = @($names | Where-Object {
            $st = $null
            try { $st = Get-ProviderTestState -ProvDir (Get-ProbeProviderDir -Provider $_) -Name $_ } catch { $st = $null }
            $st -and "$($st.State)" -eq 'ALL-PASS'
        })
        [void](Assert-ProbeNonZero $names.Count 'ALL-PASS providers')
    }
    Write-Output @($names) -NoEnumerate
}

function Get-ProbeProviderDir {
    param([Parameter(Mandatory)][string]$Provider)
    $d = Join-Path (Join-Path $script:ProbeRepo 'providers') $Provider
    if (-not (Test-Path $d)) { throw "PROBE ABORT: no provider directory for '$Provider'" }
    return $d
}

# ---------------------------------------------------------------------------------------------
# THE ACTIVE JSON -- via the canonical resolver, which needs BOTH -ProvDir AND -Provider. Passing
# only one of them threw "missing mandatory parameters" and, in a suppressed-error context, produced
# "no json/xml on all 20".
# ---------------------------------------------------------------------------------------------
function Get-ProbeJsonPath {
    param([Parameter(Mandatory)][string]$Provider)
    $d = Get-ProbeProviderDir -Provider $Provider
    $j = Get-ProviderRootJson -ProvDir $d -Provider $Provider
    if (-not $j -or -not (Test-Path $j)) { throw "PROBE ABORT: no active JSON for '$Provider'" }
    return $j
}

function Get-ProbeVersion {
    param([Parameter(Mandatory)][string]$Provider)
    $leaf = Split-Path (Get-ProbeJsonPath -Provider $Provider) -Leaf
    $m = [regex]::Match($leaf, '_v([0-9]+\.[0-9]+)\.json$')
    if (-not $m.Success) { throw "PROBE ABORT: cannot parse a version from '$leaf'" }
    return $m.Groups[1].Value
}

function Get-ProbeJsonObject {
    param([Parameter(Mandatory)][string]$Provider)
    return (Get-Content (Get-ProbeJsonPath -Provider $Provider) -Raw | ConvertFrom-Json)
}

# ---------------------------------------------------------------------------------------------
# QIDMs -- THE EMITTED TYPE IS 'QUERYINPUTDATAMAPPING'. Writing QUERYINPUTDATAMAP (no -PING) yielded
# "combos: 0" and made a correct JSON look empty. The RMS bundle is excluded: its QIDMs are form-fed
# too but are a different contract, and including them silently doubles Person/Vehicle combo counts.
# ---------------------------------------------------------------------------------------------
function Get-ProbeQidms {
    param(
        [Parameter(Mandatory)][string]$Provider,
        [string]$Entity,
        [string]$Query,
        [switch]$IncludeRms
    )
    $j = Get-ProbeJsonObject -Provider $Provider
    $out = @()
    foreach ($b in $j.bundles) {
        if (-not $IncludeRms -and "$($b.provider)" -eq 'RMS') { continue }
        foreach ($c in $b.configurations) {
            if ("$($c.type)" -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ($Entity -and "$($c.targetEntity)" -ne $Entity) { continue }
            if ($Query  -and "$($c.query)"        -ne $Query)  { continue }
            $out += $c
        }
    }
    # -NoEnumerate: PowerShell UNWRAPS a single-element array on return, so `$q.Count` came back
    # $null instead of 1 in the harness's own self-test -- the exact false-zero this file exists to
    # prevent. Caught by the self-test on first run, which is the point of having one.
    Write-Output @($out) -NoEnumerate
}

function Get-ProbeCombos {
    param([Parameter(Mandatory)][string]$Provider, [string]$Entity, [string]$Query)
    $rows = @()
    foreach ($q in (Get-ProbeQidms -Provider $Provider -Entity $Entity -Query $Query)) {
        foreach ($c in @($q.combinations)) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $rows += [pscustomobject]@{
                Provider = $Provider; Entity = $q.targetEntity; Query = $q.query
                KeyRef = "$kr"; PrimaryField = "$($c.primaryFieldReference)"
                Set = @($c.requirements.set | Where-Object { $_ })
                Any = @($c.requirements.any | Where-Object { $_ })
                Conditions = @(Get-ComboConditions $c)
                Qidm = $q; Combo = $c
            }
        }
    }
    Write-Output @($rows) -NoEnumerate
}

# ---------------------------------------------------------------------------------------------
# THE FORM -- node enumeration. Nodes sit DIRECTLY under each layout variant; there is no .nodes
# level. Assuming one produced ~125 false "orphan fill" findings in test_phase2's first draft.
# `hidden` is a NODE-level property, not props.hidden -- assuming otherwise produced 9 false
# audit_layout_flow findings, every one a hidden gate-feeder the officer never sees.
# ---------------------------------------------------------------------------------------------
function Get-ProbeFormNodes {
    param([Parameter(Mandatory)][string]$Provider, [Parameter(Mandatory)][string]$Entity)
    $j = Get-ProbeJsonObject -Provider $Provider
    $nodes = @()
    foreach ($b in $j.bundles) {
        foreach ($c in $b.configurations) {
            if ("$($c.type)" -ne 'QUERYINPUTFORM') { continue }
            if ("$($c.targetEntity)" -ne $Entity) { continue }
            if (-not $c.layout) { continue }
            foreach ($vp in $c.layout.PSObject.Properties) {
                foreach ($np in $vp.Value.PSObject.Properties) {
                    $n = $np.Value
                    if (-not $n.props) { continue }
                    $nodes += [pscustomobject]@{
                        Variant = $vp.Name; NodeId = $np.Name
                        FieldId = "$($n.props.fieldId)"
                        InitialValue = "$($n.props.initialValue)"
                        Hidden = [bool]$n.hidden      # NODE level, not props
                        Node = $n
                    }
                }
            }
        }
    }
    Write-Output @($nodes) -NoEnumerate
}

# fieldId -> initialValue for one entity. A field with a value here is ALWAYS PRESENT on submit
# whether or not the driver types it -- the fact that made two HI plan tests emit identical wire.
function Get-ProbeFormDefaults {
    param([Parameter(Mandatory)][string]$Provider, [Parameter(Mandatory)][string]$Entity)
    $d = @{}
    foreach ($n in (Get-ProbeFormNodes -Provider $Provider -Entity $Entity)) {
        if ($n.FieldId -and $n.InitialValue -ne '') { $d[$n.FieldId] = $n.InitialValue }
    }
    return $d
}

# ---------------------------------------------------------------------------------------------
# ROUTING -- named-parameter wrapper over the canonical walk. Get-FiringKeyRef is POSITIONAL
# ($entQidms, $formData); calling it with invented -Qidm/-Filled bound NOTHING and reported every
# fill as "NOTHING FIRES" on a JSON that actually routed all of them.
# Form prefills are merged in by default, because that is what the tenant actually submits.
# ---------------------------------------------------------------------------------------------
function Get-ProbeFiring {
    param(
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(Mandatory)][string]$Entity,
        [Parameter(Mandatory)][hashtable]$Fills,
        [switch]$IgnoreFormDefaults
    )
    $qidms = Get-ProbeQidms -Provider $Provider -Entity $Entity
    [void](Assert-ProbeNonZero $qidms.Count "QIDMs for $Provider/$Entity")
    $data = @{}
    if (-not $IgnoreFormDefaults) {
        foreach ($kv in (Get-ProbeFormDefaults -Provider $Provider -Entity $Entity).GetEnumerator()) { $data[$kv.Key] = $kv.Value }
    }
    foreach ($kv in $Fills.GetEnumerator()) { $data[$kv.Key] = $kv.Value }
    return (Get-FiringKeyRef $qidms $data)
}

# ---------------------------------------------------------------------------------------------
# THE TEST PLAN -- returns the tests ARRAY and asserts it is non-empty. An empty read here is what
# produced the false "28 combos lose coverage". Note the SPEC plan is a DIFFERENT artifact
# (<P>_TEST_PLAN_SPEC_v*.json); a glob of *TEST_PLAN* matches both and reading the wrong one gave
# "the driver submitted 12 but the plan holds 23".
# ---------------------------------------------------------------------------------------------
function Get-ProbePlan {
    param([Parameter(Mandatory)][string]$Provider, [switch]$Spec)
    $ver = Get-ProbeVersion -Provider $Provider
    $name = if ($Spec) { "${Provider}_TEST_PLAN_SPEC_v${ver}.json" } else { "${Provider}_TEST_PLAN_v${ver}.json" }
    $f = Join-Path (Join-Path (Get-ProbeProviderDir -Provider $Provider) 'logs') $name
    if (-not (Test-Path $f)) { throw "PROBE ABORT: no plan at $f" }
    $tests = @((Get-Content $f -Raw | ConvertFrom-Json).tests)
    [void](Assert-ProbeNonZero $tests.Count "plan tests in $name")
    Write-Output @($tests) -NoEnumerate
}

# ---------------------------------------------------------------------------------------------
# LOGS -- CURRENT VERSION ONLY, archives excluded. A bare logs/<Entity>/*.txt count includes
# stale-version logs and reports coverage no gate would accept; -Recurse without the archive filter
# pulled a plan out of _archive_pre_v3.1 and reported archived history as live clutter.
# ---------------------------------------------------------------------------------------------
function Get-ProbeLogs {
    param([Parameter(Mandatory)][string]$Provider, [string]$Entity)
    $ver = Get-ProbeVersion -Provider $Provider
    $logsDir = Join-Path (Get-ProbeProviderDir -Provider $Provider) 'logs'
    if (-not (Test-Path $logsDir)) { Write-Output @() -NoEnumerate; return }
    $files = @(Get-ChildItem $logsDir -Recurse -Filter "${Provider}_v${ver}_*.txt" -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notmatch '[\\/]_archive' })
    if ($Entity) { $files = @($files | Where-Object { $_.Directory.Name -eq $Entity }) }
    Write-Output @($files) -NoEnumerate
}

# The wire request from a log, NORMALISED: the transaction id appears as an <Id> ELEMENT *and* an
# id="..." ATTRIBUTE, so two logs of the same request never hash alike until both are stripped --
# which is why audit_log_inflation's clone check could not fail for its whole life.
function Get-ProbeWire {
    param([Parameter(Mandatory)][string]$LogPath)
    $c = Get-Content $LogPath -Raw
    if ($c -notmatch '(?s)COMMSYS XML\s*-+\s*(.*?)(?=\r?\n\s*-{3,}|\r?\nCOMMSYS XML RESPONSE)') { return $null }
    $x = $Matches[1] -replace '<Id>[^<]*</Id>', '<Id/>' -replace 'id="[^"]*"', 'id=""'
    return ($x -replace '\s+', '')
}

# The dex-log field map a log recorded (what the driver actually filled).
function Get-ProbeLogFills {
    param([Parameter(Mandatory)][string]$LogPath)
    $c = Get-Content $LogPath -Raw
    if ($c -match '(?s)QUERY STRING\s*-+\s*(\{.*?\})') {
        try { return ($Matches[1] | ConvertFrom-Json) } catch { return $null }
    }
    return $null
}

# ---------------------------------------------------------------------------------------------
# METADATA -- via _metadata_parse, which handles the DEFAULT NAMESPACE and resolves Choice /
# nested-Set into alternative required-sets. A hand-written unprefixed XPath returns NOTHING against
# these files and briefly made OH_LEADS look like it defined no DriverLicenseQuery variants at all.
# ---------------------------------------------------------------------------------------------
function Get-ProbeMetadata {
    param([Parameter(Mandatory)][string]$Provider)
    $d = Get-ProbeProviderDir -Provider $Provider
    $xml = Get-ProviderMetadataXml -ProvDir $d -Provider $Provider
    if (-not $xml) { throw "PROBE ABORT: no metadata XML resolved for '$Provider'" }
    $tx = Get-MetadataTransactions -XmlPath $xml
    [void](Assert-ProbeNonZero $tx.Keys.Count "metadata transactions for $Provider")
    return $tx
}

# Per-VARIANT <Any> optionals, keyed "<transaction>|<keyRef>|<primaryFieldReference>".
# _metadata_parse does not expose these. Keyed by the FULL triple on purpose: a keyRef is NOT a
# variant -- matching on keyRef alone paired NM_NMLETS_OFML's VIN combo QV.V against metadata
# QV{LicensePlateNumber} (the PLATE variant) and published a false REAL finding.
function Get-ProbeMetadataOptionals {
    param([Parameter(Mandatory)][string]$Provider)
    $d = Get-ProbeProviderDir -Provider $Provider
    $xmlPath = Get-ProviderMetadataXml -ProvDir $d -Provider $Provider
    if (-not $xmlPath) { throw "PROBE ABORT: no metadata XML resolved for '$Provider'" }
    [xml]$m = Get-Content $xmlPath -Raw
    $nsm = New-Object System.Xml.XmlNamespaceManager($m.NameTable)
    $ns = $m.DocumentElement.NamespaceURI
    if ($ns) { $nsm.AddNamespace('ns', $ns) }
    $pre = if ($ns) { 'ns:' } else { '' }
    $out = @{}
    foreach ($tx in $m.SelectNodes("//${pre}Transaction[@name]", $nsm)) {
        $tn = $tx.GetAttribute('name')
        foreach ($c in $tx.SelectNodes(".//${pre}Combination", $nsm)) {
            $k = $tn + '|' + $c.GetAttribute('keyReference') + '|' + $c.GetAttribute('primaryFieldReference')
            $opt = @()
            foreach ($f in $c.SelectNodes(".//${pre}Any//${pre}Field", $nsm)) {
                $r = $f.GetAttribute('reference'); if (-not $r) { $r = $f.GetAttribute('name') }
                if ($r) { $opt += $r }
            }
            $out[$k] = @($opt | Select-Object -Unique)
        }
    }
    [void](Assert-ProbeNonZero $out.Keys.Count "metadata combinations for $Provider")
    return $out
}

# ---------------------------------------------------------------------------------------------
# THE REGISTRY -- accepted divergences, with the SHARED rule classifier. Grep the SCOPE, never the
# token: a covering row scoped `QW | *` does not contain the field name, and grepping for the literal
# field published a false "unrecorded gap" against FL_FCIC that Rob remembered and the probe did not.
# ---------------------------------------------------------------------------------------------
function Get-ProbeDivergences {
    param([Parameter(Mandatory)][string]$Provider)
    . (Join-Path $script:ProbeTools '_resolve_docs_path.ps1')
    $d = Get-ProbeProviderDir -Provider $Provider
    $reg = Find-DocsPath $d 'tracking' "${Provider}_ACCEPTED_DIVERGENCES.txt"
    if (-not $reg -or -not (Test-Path $reg)) { Write-Output @() -NoEnumerate; return }
    $rows = @()
    foreach ($l in (Get-Content -LiteralPath $reg)) {
        if ($l -match '^\s*#' -or -not $l.Trim()) { continue }
        $cols = $l -split '\|'
        if ($cols.Count -lt 4) { continue }
        $rule = "$($cols[3])".Trim()
        $rows += [pscustomobject]@{
            Query = "$($cols[0])".Trim(); KeyRef = "$($cols[1])".Trim()
            Field = "$($cols[2])".Trim(); Rule = $rule
            Class = (Get-DivergenceRuleClass $rule)
            Line = $l
        }
    }
    Write-Output @($rows) -NoEnumerate
}
