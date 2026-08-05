<#
  fuzz_gate_efficacy.ps1 -- RANDOM mutation testing. Answers the question audit_gate_efficacy
  structurally cannot.

  WHY THIS EXISTS (Rob, 2026-07-31): "can you generate random mutations? i feel like this is the
  same issue we had with testing the json queries against itself."

  He is right, and it is the same circularity one level up. audit_gate_efficacy's catalogue is
  HAND-AUTHORED: every entry is a defect someone already thought of, aimed at the gate already
  known to own it. So a 16/16 KILLED score proves the gates catch the defects we anticipated -- it
  says NOTHING about the defect classes nobody wrote a mutation for. That is exactly the shape of
  the earlier failure where the JSON was validated against a plan derived from that same JSON: the
  check and the thing being checked shared an author, so they agreed by construction.

  This tool removes the author. Mutations are ENUMERATED FROM THE JSON ITSELF -- pick a random
  QIDM, a random combination, a random field, and perturb it -- then the WHOLE gate panel runs and
  we ask only: did ANY gate notice? Nothing is aimed. A mutation no gate detects is a SURVIVOR,
  i.e. a candidate blind spot that no hand-written test would ever have surfaced.

  HONEST LIMITS, stated up front because a fuzzer that overclaims is worse than none:

  1. A SURVIVOR IS A CANDIDATE, NOT A VERDICT. Some random perturbations are genuinely harmless --
     adding a field to any[] that the devdoc already lists as optional changes nothing a gate
     should complain about. Every survivor needs human triage. This tool sorts the haystack; it
     does not decide.
  2. It cannot detect a defect class for which NO gate exists at all in a way that distinguishes
     it from a harmless edit. It finds gates that are blind, not requirements that were never
     written down.
  3. Semantic equivalence is not modelled. Reordering two combinations that can never both match
     is a no-op, and will show up as a survivor.

  Runs are REPRODUCIBLE: -Seed drives every choice, and the seed is printed. A survivor can always
  be re-derived and promoted into audit_gate_efficacy's permanent catalogue once triaged.

  Usage:
    .\tools\fuzz_gate_efficacy.ps1 -Provider NJ_NJCJIS [-Mutations 15] [-Seed 20260731] [-OutFile <path>]
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [int]$Mutations = 15,
    [int]$Seed = 0,
    [string]$Scratch,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = Split-Path $toolDir -Parent
. (Join-Path $toolDir '_resolve_provider_json.ps1')

$lines = @()
function Emit([string]$s, $c = 'Gray') { $script:lines += $s; if ($c) { Write-Host $s -ForegroundColor $c } else { Write-Host $s } }

if ($Seed -eq 0) { $Seed = [int](Get-Date -UFormat %j) * 1000 + (Get-Date).Hour * 10 + (Get-Date).Minute % 10 }
$rand = New-Object System.Random($Seed)

$srcDir = Join-Path $repoRoot "providers\$Provider"
if (-not (Test-Path $srcDir)) { Emit "  [ERROR] provider not found: $Provider" 'Red'; exit 1 }
$srcJson = Get-ProviderRootJson -ProvDir $srcDir -Provider $Provider
if (-not $srcJson) { Emit "  [ERROR] no active JSON for $Provider" 'Red'; exit 1 }
$jsonLeaf = Split-Path $srcJson -Leaf

if (-not $Scratch) { $Scratch = Join-Path $env:TEMP "usx_gate_fuzz\$Provider" }
$work = $Scratch

Emit ''
Emit '================================================================' 'Cyan'
Emit "  RANDOM MUTATION FUZZ -- $Provider" 'Cyan'
Emit '  mutations are enumerated FROM THE JSON, not from a hand-written list' 'Cyan'
Emit '================================================================' 'Cyan'
Emit "  source JSON : $jsonLeaf"
Emit "  seed        : $Seed   (re-run with -Seed $Seed to reproduce exactly)"
Emit "  mutations   : $Mutations"

# Replica: same construction as audit_gate_efficacy (full rebuild, never a partial file delete --
# copying -Recurse into a surviving directory nests source\source and silently hides the metadata
# XML from the gates, which produced two FALSE survivors on 2026-07-30).
if (Test-Path $work) { [System.IO.Directory]::Delete($work, $true) }
New-Item -ItemType Directory -Force -Path $work | Out-Null
Copy-Item $srcJson (Join-Path $work $jsonLeaf) -Force
foreach ($sub in 'source','scripts','docs') {
    $s = Join-Path $srcDir $sub
    if (Test-Path $s) { Copy-Item $s -Destination $work -Recurse -Force }
}
$workJson = Join-Path $work $jsonLeaf
$pristine = Get-Content $workJson -Raw

# ── the gate PANEL. Every gate runs on every mutation: the whole point is that the mutation is
# not aimed, so we cannot know in advance which gate ought to own it. Panel is the -Path-capable
# JSON-reading gates; log gates are included because a JSON change can invalidate a saved log.
$PANEL = @(
    'validate.ps1'
    'verify_build.ps1'
    'audit_metadata.ps1'
    'audit_combo_reachability.ps1'
    'audit_requirement_fidelity.ps1'
    # audit_query_trace.ps1 is DELIBERATELY ABSENT: it takes only -Provider and reads the real
    # provider directory, so it cannot be aimed at a mutated replica. Leaving it in the panel made
    # it report a vacuous run on every mutation, which is worse than absent -- it looks like a gate
    # that never objects. Its defect class (PREFILL-DEAD) is covered here by audit_combo_reachability.
    'audit_devdoc_combinations.ps1'
    'audit_devdoc_optionals.ps1'
    'audit_devdoc_order.ps1'
    'audit_cad.ps1'
    'audit_log_content.ps1'
    'audit_log_combo_attribution.ps1'
    # Added 2026-08-02. Both are JSON-scoped and BLOCKING in enforce, and both were absent -- so
    # every survivor count this harness has ever printed was measured against a panel NARROWER than
    # the gate stack it is meant to characterise, i.e. survivors were OVERSTATED. audit_wiring_closure
    # needed a -Path mode added to be aimable at a replica at all; a blocking gate that cannot be
    # mutation-tested has an efficacy nobody has measured.
    'audit_wiring_closure.ps1'
    'audit_supported_queries.ps1'
)

function Run-Panel {
    $hits = @()
    foreach ($g in $PANEL) {
        $t = Join-Path $toolDir $g
        if (-not (Test-Path $t)) { continue }
        $out = ''
        try { $out = & powershell -ExecutionPolicy Bypass -File $t '-Path' $workJson 2>&1 | Out-String } catch { $out = "$_" }
        $fl = @([regex]::Matches($out, '(?m)^.*\[(?:FAIL|WARN)\].*$') | ForEach-Object { $_.Value.Trim() })
        # Vacuity: a gate that never looked must not be read as "clean". Same detector as
        # audit_gate_efficacy -- any verdict marker or a parseable RESULT total counts as work.
        $ran = ($out -match '\[PASS\]|\[FAIL\]|\[WARN\]|\[NOTE\]|\[SKIP\]|\[INFO\]') -or ($out -match '(?m)RESULTS?:\s*\d+') -or ($out -match 'Total:\s*\d+')
        $hits += [pscustomobject]@{ Gate = $g; Lines = $fl; Ran = $ran }
    }
    return $hits
}

# WRITE UTF-8 WITHOUT BOM, EXPLICITLY. `Set-Content -Encoding utf8` emits a BOM under Windows
# PowerShell 5.1 (pwsh 7 does not), and validate.ps1 correctly FAILs on a BOM -- so under 5.1 every
# single mutation was "caught" by the BOM check rather than by the gate that owns its defect. The
# first wide run of this fuzzer scored a meaningless CAUGHT 30/30 that way (2026-07-31). A harness
# whose own artifact trips a gate cannot measure that gate.
$script:noBom = New-Object System.Text.UTF8Encoding($false)
function Set-Work($obj) { [System.IO.File]::WriteAllText($workJson, ($obj | ConvertTo-Json -Depth 60), $script:noBom) }
function Reset-Work { [System.IO.File]::WriteAllText($workJson, $pristine, $script:noBom) }

# ── ENUMERATE mutation SITES from the JSON. No defect names, no keyRefs written by hand. ────────
# Conditions live in BOTH places across the portfolio (combo-level FL style, requirements-level
# NY/CA style) -- mirrors _sim_helpers Get-ComboConditions.
function Get-CondList($cm) {
    $c1 = @($cm.conditions | Where-Object { $_ })
    $c2 = @($cm.requirements.conditions | Where-Object { $_ })
    return @($c1 + $c2)
}
$probe = $pristine | ConvertFrom-Json
$sites = @()
foreach ($b in $probe.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.type -eq 'QUERYINPUTDATAMAPPING' -and "$($c.provider)" -ne 'RMS') {
            $ci = 0
            foreach ($cm in @($c.combinations)) {
                $set = @($cm.requirements.set | Where-Object { $_ })
                $any = @($cm.requirements.any | Where-Object { $_ })
                foreach ($f in $set) { $sites += [pscustomobject]@{ Kind='set-to-any';   Cfg=$c.name; Idx=$ci; Field=$f } }
                foreach ($f in $set) { $sites += [pscustomobject]@{ Kind='drop-set';     Cfg=$c.name; Idx=$ci; Field=$f } }
                foreach ($f in $any) { $sites += [pscustomobject]@{ Kind='drop-any';     Cfg=$c.name; Idx=$ci; Field=$f } }
                foreach ($f in $any) { $sites += [pscustomobject]@{ Kind='any-to-set';   Cfg=$c.name; Idx=$ci; Field=$f } }
                if (@(Get-CondList $cm).Count) { $sites += [pscustomobject]@{ Kind='drop-conditions'; Cfg=$c.name; Idx=$ci; Field='' } }
                # over-permit: graft a field this combination does not carry, taken from a SIBLING
                # combination of the same QIDM (so it is a real field of the transaction, not an
                # invention -- an invented name would be caught trivially and prove nothing).
                $sib = @(@($c.combinations) | ForEach-Object { @($_.requirements.set) + @($_.requirements.any) } | Where-Object { $_ } | Select-Object -Unique)
                foreach ($f in @($sib | Where-Object { $set -notcontains $_ -and $any -notcontains $_ })) {
                    $sites += [pscustomobject]@{ Kind='over-permit'; Cfg=$c.name; Idx=$ci; Field=$f }
                }
                $ci++
            }
            if (@($c.combinations).Count -ge 2) {
                for ($a = 0; $a -lt @($c.combinations).Count - 1; $a++) {
                    $sites += [pscustomobject]@{ Kind='swap-order'; Cfg=$c.name; Idx=$a; Field='' }
                }
            }
        }
        if ($c.type -eq 'QUERYINPUTFORM') {
            $lay = $c.layout.'default'
            if ($lay) { foreach ($nid in $lay.PSObject.Properties.Name) {
                $fid = "$($lay.$nid.props.fieldId)"
                if (-not $fid) { continue }
                $sites += [pscustomobject]@{ Kind='prefill-field'; Cfg=$c.name; Idx=$nid; Field=$fid }
                if ("$($lay.$nid.type.resolvedName)" -eq 'FormSelect') {
                    $sites += [pscustomobject]@{ Kind='select-to-input'; Cfg=$c.name; Idx=$nid; Field=$fid }
                }
            } }
        }
    }
}
Emit ''
Emit ("  enumerated {0} mutation site(s) across the JSON; sampling {1}" -f $sites.Count, $Mutations)
if (-not $sites.Count) { Emit '  [ERROR] no mutation sites found' 'Red'; exit 1 }

# ── BASELINE ────────────────────────────────────────────────────────────────────────────────────
Emit ''
Emit '  baseline (pristine replica) ...'
$base = Run-Panel
$baseMap = @{}; foreach ($h in $base) { $baseMap[$h.Gate] = $h }
$vac = @($base | Where-Object { -not $_.Ran })
foreach ($v in $vac) { Emit "  [NOTE] baseline: $($v.Gate) never looked (vacuous) -- it cannot contribute a verdict" 'DarkYellow' }
$baseNoise = ($base | ForEach-Object { $_.Lines.Count } | Measure-Object -Sum).Sum
Emit ("  baseline findings across panel: {0}" -f $baseNoise)

# ── apply helpers (operate on a fresh object each time) ──────────────────────────────────────────
function Apply-Mutation($j, $s) {
    $cfg = $null
    foreach ($b in $j.bundles) { foreach ($c in $b.configurations) { if ("$($c.name)" -eq $s.Cfg) { $cfg = $c } } }
    if (-not $cfg) { throw "config '$($s.Cfg)' not found" }
    switch ($s.Kind) {
        'set-to-any' {
            $cm = @($cfg.combinations)[$s.Idx]
            $cm.requirements.set = @(@($cm.requirements.set) | Where-Object { $_ -ne $s.Field })
            $cm.requirements.any = @(@($cm.requirements.any) + $s.Field)
        }
        'any-to-set' {
            $cm = @($cfg.combinations)[$s.Idx]
            $cm.requirements.any = @(@($cm.requirements.any) | Where-Object { $_ -ne $s.Field })
            $cm.requirements.set = @(@($cm.requirements.set) + $s.Field)
        }
        'drop-set' {
            $cm = @($cfg.combinations)[$s.Idx]
            $cm.requirements.set = @(@($cm.requirements.set) | Where-Object { $_ -ne $s.Field })
        }
        'drop-any' {
            $cm = @($cfg.combinations)[$s.Idx]
            $cm.requirements.any = @(@($cm.requirements.any) | Where-Object { $_ -ne $s.Field })
        }
        'over-permit' {
            $cm = @($cfg.combinations)[$s.Idx]
            $cm.requirements.any = @(@($cm.requirements.any) + $s.Field)
        }
        'drop-conditions' {
            $cm = @($cfg.combinations)[$s.Idx]
            if ($cm.PSObject.Properties['conditions']) { $cm.conditions = @() }
            if ($cm.requirements.PSObject.Properties['conditions']) { $cm.requirements.conditions = @() }
        }
        'swap-order' {
            $arr = @($cfg.combinations)
            $tmp = $arr[$s.Idx]; $arr[$s.Idx] = $arr[$s.Idx + 1]; $arr[$s.Idx + 1] = $tmp
            $cfg.combinations = $arr
        }
        'prefill-field' {
            $n = $cfg.layout.'default'.$($s.Idx)
            if ($n.props.PSObject.Properties['initialValue']) { $n.props.initialValue = 'FUZZ1' }
            else { $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'FUZZ1' -Force }
        }
        'select-to-input' {
            $n = $cfg.layout.'default'.$($s.Idx)
            $n.type.resolvedName = 'FormInput'
        }
        default { throw "unknown mutation kind '$($s.Kind)'" }
    }
}

# ── SAMPLE + RUN ────────────────────────────────────────────────────────────────────────────────
# Sample without replacement so one site is not tested twice while others go untouched.
$pool = @($sites | Sort-Object { $rand.Next() })
$pick = @($pool | Select-Object -First ([Math]::Min($Mutations, $pool.Count)))

Emit ''
Emit ("  {0,-4} {1,-17} {2,-34} {3,-26} {4}" -f '#','KIND','WHERE','FIELD','VERDICT')
Emit ('  ' + ('-' * 118))

$survivors = @(); $caught = 0; $invalid = 0
$i = 0
foreach ($s in $pick) {
    $i++
    $shortCfg = "$($s.Cfg)" -replace "^$([regex]::Escape($Provider))_", ''
    $label = ("  {0,-4} {1,-17} {2,-34} {3,-26}" -f $i, $s.Kind, ("$shortCfg[$($s.Idx)]"), $s.Field)
    Reset-Work
    try {
        $j = $pristine | ConvertFrom-Json
        Apply-Mutation $j $s
        Set-Work $j
    } catch {
        Emit ($label + "[INVALID] could not apply: $_") 'DarkYellow'
        $invalid++; continue
    }
    $now = Run-Panel
    # NEW finding TEXT, not a count delta. A mutation that WORSENS an existing finding line instead
    # of adding one is invisible to counting -- that hole produced two false SURVIVED verdicts in
    # audit_gate_efficacy on 2026-07-30.
    $newLines = @()
    foreach ($h in $now) {
        $bl = if ($baseMap.ContainsKey($h.Gate)) { $baseMap[$h.Gate].Lines } else { @() }
        foreach ($l in $h.Lines) { if ($bl -notcontains $l) { $newLines += "$($h.Gate): $l" } }
    }
    if ($newLines.Count) {
        $caught++
        $g = ($newLines | ForEach-Object { ($_ -split ':')[0] } | Select-Object -Unique) -join ', '
        Emit ($label + "[CAUGHT]  by $g") 'Green'
        Emit ("       " + ($newLines[0] -replace '\s+', ' ')) 'DarkGray'
    } else {
        # A SURVIVOR IS ONLY EVIDENCE IF EVERY GATE ACTUALLY LOOKED (added 2026-08-04).
        # Vacuity was checked at baseline and never again, so a gate that RAN but examined nothing on
        # THIS mutation contributes no new lines and the mutation reads SURVIVED -- indistinguishable
        # from a genuine blind spot. That is not hypothetical: audit_devdoc_optionals is in this panel
        # and is KNOWN to flake under parallel load (SESSION_STATE records it), and it demonstrably
        # DOES fire on the Boat drop-any RegistrationNumber mutation when run alone -- yet that
        # mutation was reported SURVIVED. A false SURVIVED is worse than a missed one: it sends you
        # to widen a gate that already works.
        $blind = @($now | Where-Object { -not $_.Ran } | ForEach-Object { $_.Gate })
        if ($blind.Count) {
            Emit ($label + "[SURVIVED?] no gate reacted, BUT " + $blind.Count + " gate(s) never looked on this mutation: " + ($blind -join ', ') + " -- RE-RUN THOSE ALONE before treating this as a blind spot") 'DarkYellow'
        } else {
            Emit ($label + '[SURVIVED] no gate reacted (every panel gate looked)') 'Red'
        }
        $survivors += $s
    }
}

Reset-Work

Emit ''
Emit ('  ' + ('-' * 118))
Emit ("  CAUGHT {0} / {1}   SURVIVED {2}   INVALID {3}   (seed {4})" -f $caught, ($caught + $survivors.Count), $survivors.Count, $invalid, $Seed) `
     $(if ($survivors.Count) { 'Yellow' } else { 'Green' })
if ($survivors.Count) {
    Emit ''
    Emit '  SURVIVORS -- candidate blind spots. TRIAGE EACH, do not assume all are real:' 'Yellow'
    Emit '  a survivor is real only if the mutated JSON would actually behave differently in a way' 'DarkGray'
    Emit '  a gate SHOULD own. THREE classes survive CORRECTLY -- check these before filing a defect:' 'DarkGray'
    Emit '   (a) SYNTHETIC COMBO -- the mutated combination maps to NO metadata alternative (FL_FCIC' 'DarkGray'
    Emit '       BQName: set[BirthDate,NameLast,NameFirst,RegistrationState], and metadata QB defines' 'DarkGray'
    Emit '       only Hull/CoastGuardDoc/NCIC/ProcessControl/RegistrationNumber branches). Per-combination' 'DarkGray'
    Emit '       fidelity has nothing to compare against, so no mutation of it can produce a finding.' 'DarkGray'
    Emit '       This is a REAL COVERAGE LIMIT, not a gate bug: the same synthetic population that' 'DarkGray'
    Emit '       audit_devdoc_order leaves unchecked (8 of 30 combos on FL) has no fidelity gate either.' 'DarkGray'
    Emit '   (b) DEVDOC-SANCTIONED OPTIONAL -- an any[] addition the devdoc already lists as optional' 'DarkGray'
    Emit '       on that branch is not an over-permit.' 'DarkGray'
    Emit '   (c) SEMANTIC NO-OP -- reordering two combinations that can never both match (a condition' 'DarkGray'
    Emit '       on one defers to the other), or prefilling a field no combo routes on.' 'DarkGray'
    foreach ($s in $survivors) {
        $shortCfg = "$($s.Cfg)" -replace "^$([regex]::Escape($Provider))_", ''
        Emit ("    - {0} @ {1}[{2}] {3}" -f $s.Kind, $shortCfg, $s.Idx, $s.Field) 'Yellow'
    }
    Emit ''
    Emit '  Promote any TRIAGED-REAL survivor into audit_gate_efficacy.ps1 $MUTS so it becomes a' 'DarkGray'
    Emit '  permanent regression test, then fix the gate.' 'DarkGray'
}
Emit ('  ' + ('-' * 118))

if ($OutFile) { $lines | Out-File $OutFile -Encoding utf8 }
exit 0
