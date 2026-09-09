<#
  audit_gate_efficacy.ps1 -- MUTATION TESTING FOR THE GATE SUITE. Does each gate actually FAIL
  when the defect it exists to catch is present?

  WHY THIS EXISTS (Rob 2026-07-30: "i need a way for me to trust your output. make it happen."):
    Every other tool in this repo tells you about the CONFIG. Nothing tells you about the TOOLS.
    So "0 FAIL" is ambiguous in the worst possible way -- it is produced identically by:
        (a) the config is correct, and
        (b) the check is broken, inert, or looking at the wrong thing.
    Rob has no way to tell those apart, and this session proved (b) is not hypothetical:
      - sync_provider_table.ps1 was SILENTLY INERT for all 20 providers. Its score regex required
        a "/<n>LIM" segment the table no longer had, so every replace was a no-op and it printed
        "no change" for months while the table rotted.
      - audit_query_trace.ps1 read metadata field names from InnerText instead of @reference and
        looked for <Any>/<Choice> outside <Set>, so it reported every combination as an empty-set
        SHADOW. Caught only because TX's answer was already known independently.
      - audit_devdoc_combinations.ps1 (first draft) hit the PowerShell single-element-array unwrap:
        a function returning @($x) came back as a bare string, callers indexed [0] and got the
        first CHARACTER. Every wired-field set became a set of letters and it claimed 20/20 UNBUILT
        on a provider that is 21/21 correct.
      - audit_metadata CHECK 4e compared against the QUERY-WIDE metadata set[] union instead of the
        per-keyReference set[], so a field mandatory in one combination looked mandatory in its
        siblings -- 2 false FAILs on legitimate any[] additions, and 22 earlier ones on composites.
    Four inert-or-wrong checkers in one session. A green board built on those is not evidence.

  WHAT IT DOES
    For each known defect CLASS, inject that exact defect into a throwaway replica of the provider
    and run the gate that owns it. Two assertions per mutation, both required:
        BASELINE  -- the gate must PASS on the unmutated replica  (else the harness is misconfigured,
                     reported INVALID, never counted as a success)
        MUTANT    -- the gate must FAIL on the mutated replica     (else the gate is BLIND)
    A mutation the gate catches is KILLED. One it misses SURVIVED, and a survivor means that gate's
    green light means nothing for that defect class.

  HOW TO READ THE OUTPUT
    KILLED   n/n  -> those gates are proven capable of failing. Their PASS is evidence.
    SURVIVED      -> that gate cannot see that defect. Do NOT trust its PASS for that class.
    INVALID       -> the harness could not establish a clean baseline; fix the harness, not the gate.

  SCOPE: one provider at a time, on purpose (-Provider TX_TLETS). The replica lives in the
  scratch dir; logs/ are not copied (838 files, and no mutation here concerns them).

  Usage: .\audit_gate_efficacy.ps1 -Provider TX_TLETS [-Only <substring>] [-OutFile <path>]
#>

param(
    [Parameter(Mandatory=$true)][string]$Provider,
    [string]$Only,
    [string]$Scratch,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir "_resolve_provider_json.ps1")

$lines = New-Object System.Collections.Generic.List[string]
function Emit($s,$c){ $lines.Add($s); if($c){Write-Host $s -ForegroundColor $c}else{Write-Host $s} }

$srcDir = Join-Path $repoRoot "providers\$Provider"
if (-not (Test-Path $srcDir)) { Emit "  [ERROR] provider not found: $Provider" 'Red'; exit 1 }
$srcJson = Get-ProviderRootJson -ProvDir $srcDir -Provider $Provider
if (-not $srcJson) { Emit "  [ERROR] no active JSON for $Provider" 'Red'; exit 1 }
$jsonLeaf = Split-Path $srcJson -Leaf

if (-not $Scratch) {
    $Scratch = Join-Path $env:TEMP "usx_gate_efficacy\$Provider"
}
$work = $Scratch

Emit "" $null
Emit "================================================================" 'Cyan'
Emit "  GATE EFFICACY (mutation testing) -- $Provider" 'Cyan'
Emit "  can each gate actually FAIL when its defect is present?" 'Cyan'
Emit "================================================================" 'Cyan'
Emit "  source JSON : $jsonLeaf" $null
Emit "  replica     : $work" $null

# ── build the replica (everything a gate reads, except logs) ──────────────────────────
# Rebuild the replica COMPLETELY, directories included. Deleting only FILES and then
# Copy-Item -Recurse into a surviving directory nests it (source -> source\source), which silently
# strips the metadata XML out of the gates' reach. That happened on 2026-07-30 and produced two
# FALSE "SURVIVED" verdicts: audit_metadata could not find the XML, scored 0 PASS / 0 FAIL on BOTH
# baseline and mutant, and the zero delta read as "gate is blind".
if (Test-Path $work) { [System.IO.Directory]::Delete($work, $true) }
New-Item -ItemType Directory -Force -Path $work | Out-Null
Copy-Item $srcJson (Join-Path $work $jsonLeaf) -Force
foreach ($sub in 'source','scripts','docs') {
    $s = Join-Path $srcDir $sub
    if (Test-Path $s) { Copy-Item $s -Destination $work -Recurse -Force }
}
$workJson = Join-Path $work $jsonLeaf
$pristine = Get-Content $workJson -Raw

# ── gate runners. Each returns @{ Fail=<bool>; Detail=<string> } ──────────────────────
function Run-Gate([string]$tool, [string[]]$argsList) {
    $t = Join-Path $toolDir $tool
    if (-not (Test-Path $t)) { return @{ Fail = $null; Detail = "tool missing: $tool" } }
    # A CHILD GATE WRITING TO stderr MUST NOT ABORT THE WHOLE SWEEP. Caught 2026-09-09: during a
    # 20-provider run, TX_TLETS died after 4 of its 18 mutations with
    #     NativeCommandError at audit_gate_efficacy.ps1:100
    # and it was NOT reproducible -- TX ran 18/18 clean immediately before and immediately after.
    # Cause: this script sets $ErrorActionPreference='Stop', and under Stop a NATIVE command that
    # writes anything to stderr raises a TERMINATING error, so one transient line from a child gate
    # kills a run that was otherwise fine. The damage is not the crash, it is what the crash LOOKS
    # like: no totals line is emitted, so `build_phase1` step 6 falls to its else branch and reports
    # "no mutation map for TX_TLETS -- its green gates are UNPROVEN" on a provider with 18 working
    # mutations. A harness that intermittently aborts and then mis-describes itself is worse than
    # one that fails loudly. Same defect class as the Edge-stderr fix in audit_extension_syntax
    # earlier the same day: stderr from a child is DATA here, not an exception.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try   { $out = & powershell -ExecutionPolicy Bypass -File $t @argsList 2>&1 | Out-String }
    catch { $out = "HARNESS: child gate threw -- $($_.Exception.Message)" }
    finally { $ErrorActionPreference = $prevEap }
    # DETECTION = a [FAIL] *or* a [WARN] line. Counting WARN matters: several checks are
    # deliberately warn-level (verify_build CHECK 9 "flags survivors for review"), and a
    # harness that only looked for [FAIL] would libel them as blind. Learned the hard way
    # 2026-07-30 -- the first run of this harness falsely accused CHECK 9 for exactly that.
    # ...AND [LIMITATION], added 2026-08-04 -- the SAME hole, one verdict class further along.
    # validate.ps1 emits THREE classes (FAIL / WARN / LIMITATION) and its RESULTS line counts them
    # separately, but this harness only looked for the first two. So the `az-state-prefill-routes`
    # mutation -- put RegistrationState back into a set[] while the form prefills it, the real
    # LIMITATION #30 mechanism -- reported SURVIVED while validate.ps1 was in fact reacting
    # correctly, which an ad-hoc replica run had already shown. A harness that cannot see a whole
    # verdict class will libel every check that speaks in it, exactly as the WARN omission above
    # libelled verify_build CHECK 9 on 2026-07-30. Same lesson, so keep them together.
    $nFail = @([regex]::Matches($out,'\[FAIL\]|\[LIMITATION\]')).Count
    # FULL finding TEXT, not just a count. Count-only detection is blind to a mutation that WORSENS
    # an existing finding line instead of adding one -- measured 2026-07-30, when two NJ mutations
    # reported SURVIVED purely because RANDFULL already carried an UNDER-REQUIRED line and the
    # mutation added a field to it rather than a new line. A gate that cannot see a defect get worse
    # is exactly the class this harness exists to expose, so it must not have that hole itself.
    $fLines = @([regex]::Matches($out,'(?m)^.*\[(?:FAIL|WARN|LIMITATION)\].*$') | ForEach-Object { $_.Value.Trim() })
    $nWarn = @([regex]::Matches($out,'\[WARN\]')).Count
    # VACUOUS-RUN DETECTOR. "no findings" and "ran no checks" are different things, and a gate that
    # skipped its subject entirely looks identical to a clean pass. audit_metadata emits
    # "[SKIP] No XML metadata found" + "Providers checked: 0" + exit 0 when the XML is missing, so a
    # harness that only counted findings called it blind when it had never looked. Any run with zero
    # PASS lines, or an explicit 0-subjects summary, is VACUOUS and cannot support a verdict.
    $nPass = @([regex]::Matches($out,'\[PASS\]')).Count
    # "Did the gate RUN?" must not be inferred from [PASS] alone. Not every gate emits [PASS] --
    # audit_devdoc_optionals emits only [FAIL]/[NOTE]/[SKIP] plus a RESULT total, and a [PASS]-only
    # test declared it VACUOUS once TX went clean (0 FAIL / 0 WARN / 11 NOTE), i.e. the detector
    # misfired exactly when the provider became correct. Evidence of work = any verdict marker OR a
    # parseable RESULT/RESULTS total. Fixed 2026-07-30.
    $nNote  = @([regex]::Matches($out,'\[NOTE\]|\[SKIP\]|\[INFO\]')).Count
    $hasTot = ($out -match '(?m)RESULTS?:\s*\d+') -or ($out -match 'Total:\s*\d+')
    $ranSomething = ($nPass + $nFail + $nWarn + $nNote) -gt 0 -or $hasTot
    $vacuous = (-not $ranSomething) -or ($out -match 'Providers checked:\s*0') -or ($out -match '\[SKIP\] No XML metadata')
    $first = ''
    foreach ($l in ($out -split "`n")) { if ($l -match '\[FAIL\]|\[WARN\]') { $first = $l.Trim(); break } }
    return @{ N = ($nFail + $nWarn); NFail = $nFail; NWarn = $nWarn; NPass = $nPass; Vacuous = $vacuous; Detail = $first; Lines = $fLines; Ok = $true }
}

# JSON mutation helper: load, mutate via scriptblock, write back
function Set-Mutant([scriptblock]$mut) {
    $j = $pristine | ConvertFrom-Json
    & $mut $j
    # WRITE UTF-8 WITHOUT BOM, EXPLICITLY. `Set-Content -Encoding utf8` emits a BOM under Windows
    # PowerShell 5.1 (pwsh 7 does not), and validate.ps1 correctly FAILs on a BOM -- so whenever
    # this harness runs under 5.1, EVERY mutation gets "killed" by the BOM check instead of by the
    # gate that owns its defect, and the KILLED score becomes meaningless. Found 2026-07-31 by
    # fuzz_gate_efficacy.ps1, which carried the same line and scored a fake CAUGHT 30/30 under 5.1.
    [System.IO.File]::WriteAllText($workJson, ($j | ConvertTo-Json -Depth 60), (New-Object System.Text.UTF8Encoding($false)))
}
function Reset-Mutant { [System.IO.File]::WriteAllText($workJson, $pristine, (New-Object System.Text.UTF8Encoding($false))) }

function Get-Cfg($j, [string]$nameLike) {
    foreach ($b in $j.bundles) { foreach ($c in $b.configurations) { if ("$($c.name)" -like $nameLike) { return $c } } }
    return $null
}
function Get-Combo($cfg, [string]$kr) {
    foreach ($cm in $cfg.combinations) { if ("$($cm.keyReference)" -eq $kr) { return $cm } }
    return $null
}
function Get-Node($j, [string]$entity, [string]$fieldId) {
    foreach ($b in $j.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTFORM' -or "$($c.targetEntity)" -ne $entity) { continue }
        $lay = $c.layout.'default'
        foreach ($nid in $lay.PSObject.Properties.Name) {
            if ("$($lay.$nid.props.fieldId)" -eq $fieldId) { return $lay.$nid }
        } } }
    return $null
}

# FIND A DROPDOWN BY WHAT MAKES IT ONE, NOT BY ITS NAME. Added 2026-09-02.
# `codetype-select-as-input` hunted three hardcoded fieldIds (relatedHitSearchIndicator /
# RelatedHitSearchIndicator / ImageIndicator) and threw 'no codeTypeCategory dropdown found to
# mutate' when none was present -- which is the case on ALL SIX CA providers, none of which builds
# an ImageIndicator control (CLAUDE.md records that as correct: the field is absent from their
# metadata). MEASURED 2026-09-02: 6 of 20 providers reported [INVALID] -- CA_CLETS, CA_CLETS_OCATS,
# CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY -- while each carries 5-6 real
# codeTypeCategory-driven FormSelects that are perfectly valid targets. So validate.ps1's
# codeTypeCategory branch had never been efficacy-proven on a single CA provider, and
# ENGINEERING_STANDARD 5 requires 0 INVALID as well as 0 SURVIVED. An INVALID is not a harmless
# skip: 'a step that did not run is NOT a pass', and a stale mutation is indistinguishable from a
# blind gate (the fl-drop-devdoc-optional lesson).
# Selects on the PROPERTY the rule is about, so it self-extends to any future dropdown.
# ── DERIVED (auto-targeting) MUTATION HELPERS ────────────────────────────────────────────
# WHY THESE EXIST. Measured 2026-09-09: of 47 catalogued mutations, 33 hardcode ONE provider's
# query/keyRef/field, so IL ran 20 and TX 18 while FIFTEEN providers ran only 7-9 -- essentially
# the globals. Those fifteen scored "0 SURVIVED / 0 INVALID" because almost nothing was aimed at
# them, which is not the same as their gates being proven. Hand-writing 15 bespoke sets would be
# ~150 rows, each hardcoding a target that rots the moment that provider is rebuilt -- the exact
# staleness the [INVALID] verdict exists to catch. So instead the DEFECT CLASS is expressed once
# and the TARGET is computed from whatever provider is in front of it.
#
# THE RULE THAT MAKES THEM SAFE: a derived mutation must CREATE the defect, not merely resemble it.
# The `prefill-routing-field` note above records what happens otherwise -- its first draft prefilled
# a field present in BOTH combos, which starves neither, and it FALSELY ACCUSED a working gate. So
# each helper below returns a target ONLY when the mutation provably changes routing, and $null
# otherwise, which the caller reports as [N/A] rather than as a survivor.
# MIRRORS audit_combo_reachability's OWN config filter, deliberately. The first draft excluded
# only QUERYINPUTFORM, which let RMS-bundle QIDMs through -- and on TN_TIES the alphabetically
# first match was "RMS Person Search query". Mutating that produced no finding and reported
# SURVIVED against a gate that never looks at RMS combinations and is right not to. If a mutation
# targets a config its gate does not examine, it measures nothing and libels the gate; so the
# selector must be the gate's, not a plausible approximation of it (ENGINEERING_STANDARD 4.4 --
# never re-implement an existing parser).
function Get-QidmConfigs($j) {
    $out = @()
    foreach ($b in $j.bundles) {
        if ($b.provider -in @('MARK43','RMS')) { continue }
        foreach ($c in $b.configurations) {
            if ($c.type -ne 'QUERYINPUTDATAMAPPING') { continue }
            if ($c.handlerFunction -eq 'RmsRestPayloadHandler') { continue }
            if (@($c.combinations).Count -ge 2) { $out += $c }
        }
    }
    # Deterministic order: the harness must pick the SAME target every run, or a KILLED today and a
    # SURVIVED tomorrow would look like a gate regression instead of a coin toss.
    return @($out | Sort-Object { "$($_.name)" })
}
# A SHADOW needs the victim's set[] to become a duplicate of an EARLIER combo's, with nothing left
# to discriminate them -- so conditions are cleared too. A leftover NOT_EXISTS gate would keep the
# victim reachable and the mutation would report SURVIVED against a gate that was right.
function Get-ShadowTarget($j) {
    foreach ($c in (Get-QidmConfigs $j)) {
        $cms = @($c.combinations)
        # THE SOURCE'S CONDITIONS ARE CLEARED BY THE MUTATION, so the source does not need to be
        # ungated to begin with -- and that matters, because requiring an ungated source produced
        # [N/A] on exactly the guardrailed providers this exists to cover (MD_METERS, TN_TIES: every
        # early combo carries an identifier-priority gate like Hull>Reg, so nothing qualified).
        #
        # WHY THE FIRST DRAFT LIBELLED THE GATE, kept because the lesson is the point: it copied a
        # GATED source's set[] onto the victim and cleared only the VICTIM's conditions. On MD's
        # BoatQuery the source ZBOA.H carries `RegistrationNumber NOT_EXISTS`, so filling Hull+Reg
        # BLOCKS the source while the victim still matches -- the victim stayed perfectly REACHABLE,
        # no defect was created, and it reported SURVIVED against a gate that was entirely right.
        # A conditioned combo is not unconditionally dominant and cannot starve anything.
        $srcSet = @($cms[0].requirements.set)
        if (-not $srcSet.Count) { continue }
        for ($i = $cms.Count - 1; $i -ge 1; $i--) {
            $vSet = @($cms[$i].requirements.set)
            # Must currently DIFFER, else the mutation is a no-op and a no-op cannot fail.
            $same = ($vSet.Count -eq $srcSet.Count) -and -not @(Compare-Object $vSet $srcSet -ErrorAction SilentlyContinue).Count
            if (-not $same) { return @{ Cfg = $c; Source = $cms[0]; Victim = $cms[$i] } }
        }
    }
    return $null
}
# A PREFILL only shadows when the victim's set[] is its earlier sibling's set[] PLUS EXACTLY ONE
# extra field, and that field carries no form initialValue yet. Prefilling it makes the extra field
# always-present, so the victim matches whenever the sibling does and first-match starves it.
# This is TX's real RQ/REG case (BUILD_RULES 24), derived instead of hardcoded.
function Get-PrefillShadowTarget($j) {
    foreach ($c in (Get-QidmConfigs $j)) {
        $cms = @($c.combinations)
        for ($a = 0; $a -lt $cms.Count - 1; $a++) {
            $aSet = @($cms[$a].requirements.set)
            if (-not $aSet.Count) { continue }
            for ($b = $a + 1; $b -lt $cms.Count; $b++) {
                $bSet = @($cms[$b].requirements.set)
                if ($bSet.Count -ne $aSet.Count + 1) { continue }
                $extra = @($bSet | Where-Object { $aSet -notcontains $_ })
                $missing = @($aSet | Where-Object { $bSet -notcontains $_ })
                if ($extra.Count -ne 1 -or $missing.Count -ne 0) { continue }
                # the extra field must exist as a form control WITHOUT a prefill
                foreach ($bnd in $j.bundles) { foreach ($cf in $bnd.configurations) {
                    if ($cf.type -ne 'QUERYINPUTFORM') { continue }
                    $lay = $cf.layout.'default'; if (-not $lay) { continue }
                    foreach ($nid in $lay.PSObject.Properties.Name) {
                        $n = $lay.$nid
                        if (-not $n.props) { continue }
                        if ("$($n.props.fieldId)" -ne "$($extra[0])") { continue }
                        if ($n.props.PSObject.Properties.Name -contains 'initialValue' -and "$($n.props.initialValue)" -ne '') { continue }
                        return @{ Node = $n; Field = "$($extra[0])"; Victim = $cms[$b]; Cfg = $c }
                    }
                } }
            }
        }
    }
    return $null
}

function Get-CodeTypeSelectNode($j) {
    foreach ($b in $j.bundles) { foreach ($c in $b.configurations) {
        if ($c.type -ne 'QUERYINPUTFORM') { continue }
        $lay = $c.layout.'default'
        if (-not $lay) { continue }
        foreach ($nid in $lay.PSObject.Properties.Name) {
            $n = $lay.$nid
            if (-not $n.props) { continue }
            if ("$($n.type.resolvedName)" -ne 'FormSelect') { continue }
            if (-not $n.props.codeTypeCategory) { continue }
            return $n
        } } }
    return $null
}

# ── PER-PROVIDER MUTATION MAPS ────────────────────────────────────────────────────────
# The table below names REAL keyRefs and fieldIds, so it is provider-shaped by necessity. A
# provider without a map cannot be mutation-tested, and by LAW 2 its gates' PASS is therefore not
# yet evidence -- say so rather than implying coverage.
#
# NY_NYSPIN_EJUSTICE IS THE KEYREF-COLLISION PROVIDER (BUILD_RULES 13): it reuses RVEH and RCAR on
# BOTH VehicleRegistrationQuery AND BoatQuery. Every NY mutation must therefore be QUERY-SCOPED --
# Get-Cfg by QIDM name first, then Get-Combo within it. A bare keyRef lookup would silently mutate
# the Boat combo while claiming to test Vehicle, which is the exact bug that produced 8 bogus
# "NO COMBO FIRES" results in audit_log_combo_attribution on 2026-07-29.
#
# NY prefill note, verified 2026-07-30: purposeCodeDH='C' and requestorDH='X' ARE prefilled AND ARE
# in DALHOUT/DALLOUT set[]. That is the BUILD_RULES 24 shape but NOT a violation here -- the
# discriminator is RegistrationStateDH EXISTS/NOT_EXISTS, which is correctly NOT prefilled, so no
# combination is hidden (query_trace: 0 PREFILL-DEAD). The prefill-dead mutation below therefore
# targets RegistrationStateDH, the field that IS the discriminator, because a mutation must CREATE
# the defect rather than merely resemble it.
$PROV_MUTS = @{
  'NY_NYSPIN_EJUSTICE' = @(
    @{ Id='ny-prefill-discriminator'
       Desc='initialValue on RegistrationStateDH -- it is the EXISTS/NOT_EXISTS discriminator between DALHOUT/DALH and DALLOUT/DALL, so prefilling it permanently decides the gate and starves the in-state pair'
       Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
       Mut={ param($j) $n=Get-Node $j 'Person' 'RegistrationStateDH'; $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'NY' -Force } }

    @{ Id='ny-fidelity-demote-mandatory'; OnlyProvider='NY_NYSPIN_EJUSTICE'
     Desc='LicensePlateYear demoted from RVEHOUT set[] to any[] though devdoc #3 AND metadata RVEH alt2 both make it mandatory -- the exact defect fixed at v4.18, so the gate that found it must be proven able to find it again.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'RVEHOUT'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'LicensePlateYear' })
           $cm.requirements.any=@(@($cm.requirements.any)+'LicensePlateYear') } }

  @{ Id='ny-keyref-collision-scope'
       Desc='break the BoatQuery RVEH combo only -- a query-scoped gate must still catch it while the identically-named VehicleRegistrationQuery RVEH stays intact (BUILD_RULES 13)'
       Gate='audit_metadata.ps1'; Args={ @('-Path',$workJson) }
       Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'; $cm=Get-Combo $c 'RVEH'
             $cm.requirements.set=@('RegistrationState'); $cm.requirements.any=@('RegistrationNumber') } }

    @{ Id='ny-drop-oos-guardrail'
       Desc='DALLOUT loses BOTH RegistrationStateDH from set[] AND its EXISTS condition, so the out-of-state DH path is no longer discriminated from DALL -- and because purposeCodeDH is PREFILLED, DALLOUT collapses to an always-satisfiable [OLN] ahead of DALL and steals every in-state OLN fill'
       Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
       # RE-AIMED 2026-09-08. It previously removed ONLY the `RegistrationStateDH EXISTS` condition
       # and was assigned to verify_build -- and it had been reporting SURVIVED for weeks, which I
       # twice published as a gate blind spot. It was neither: RegistrationStateDH is ALSO MANDATORY
       # in DALLOUT's set[], so the condition was redundant BY CONSTRUCTION and its removal changed
       # nothing. (One of 63 such redundant `X EXISTS on a field already in set[]` conditions found
       # portfolio-wide that day -- a house convention documenting the in/out fork, harmless in
       # itself, and it silently invalidated this test.)
       #
       # THE RE-AIM KEEPS THE ORIGINAL INTENT -- "the OOS path is no longer discriminated from DALL"
       # -- instead of just making it fire somewhere. Dropping State from set[] AND the condition
       # leaves DALLOUT = set[OperatorLicenseNumberDH, purposeCodeDH], UNGATED. purposeCodeDH is
       # PREFILLED (its own registry row: prefilled-mandatory-autopopulated), and reachability
       # counts a form initialValue as always-present, so DALLOUT's effective set collapses to
       # [OperatorLicenseNumberDH] -- identical to DALL, which is ordered AFTER it. DALLOUT then
       # takes every in-state OLN fill and sends an out-of-state DH query with NO destination state.
       # GATE CHANGED verify_build -> audit_combo_reachability: an always-satisfiable combo ordered
       # ahead of its sibling is a REACHABILITY question, not a structural-verification one.
       # Note audit_prefill_shadow deliberately does NOT own this: its rule spares a pair whose
       # subset relation already holds on the RAW set[]s (DALL [OLN] is a subset of DALLOUT's raw
       # set either way), which is exactly the hand-off it documents to reachability.
       Valid={ param($j) $c=Get-Cfg $j '*_DriverHistoryQuery'; $cm=Get-Combo $c 'DALLOUT'
               (@($cm.requirements.set) -contains 'RegistrationStateDH') -and (@($cm.requirements.set) -contains 'purposeCodeDH') }
       ValidWhy='DALLOUT no longer carries BOTH RegistrationStateDH and purposeCodeDH in set[], so this mutation can no longer collapse it onto DALL. Re-derive the DH combos before re-aiming again.'
       Mut={ param($j) $c=Get-Cfg $j '*_DriverHistoryQuery'; $cm=Get-Combo $c 'DALLOUT'
             $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'RegistrationStateDH' })
             $cm.requirements.conditions=@($cm.requirements.conditions | Where-Object { "$($_.field)" -notmatch 'RegistrationStateDH' }) } }

    # ── THE ONE REAL GATE GAP FOUND BY THE 2026-09-08 PORTFOLIO RESWEEP ──────────────────────────
    # Promoted per usx-tooling: "Promote a TRIAGED-REAL survivor into audit_gate_efficacy $MUTS,
    # then fix the gate." Order matters -- catalogued first so the gap cannot be lost, fixed second.
    # EXPECT THIS TO REPORT SURVIVED until the gate is fixed. That is the point: an honest SURVIVED
    # on a real gap is worth more than a hidden one, and ENGINEERING_STANDARD 5 will correctly hold
    # NY short of "finished" while it stands.
    #
    # THE DEFECT: metadata DALL{Name} mandates BirthDate in BOTH alternatives
    #   alt1 = BirthDate, Name, SexCode        alt2 = BirthDate, Name, PurposeCode, Requestor, SexCode, State
    # Built DALH = set[BirthDateDH, NameLastDH, NameFirstDH, SexCodeDH] -- an EXACT match to alt1.
    # Demoting BirthDateDH to any[] means DALH can FIRE WITHOUT IT and the request is one the
    # metadata calls invalid: UNDER-REQUIRED, severity #1 in the usx-build order.
    #
    # WHY NO GATE REACTS: the alternative->built assignment is a SCORE-BASED BEST FIT. Once DALH no
    # longer matches alt1, DALHOUT outscores it and absorbs TWO alternatives while DALH is claimed
    # by none -- and an unpaired built combo is SKIPPED. Branches-compared stays at 16 because every
    # ALTERNATIVE still found a server, so the denominator cannot reveal it either. The mutation
    # escapes by destroying the comparison that would have judged it.
    # This is the QUALIFIER-level twin of the escape the file already documents at its
    # UNSATISFIED-CLAIM guard, which only fires when the combo loses its IDENTIFIER -- DALH still
    # has Name, so it does not trip.
    #
    # ✅ CLOSED THE SAME DAY, and BE PRECISE ABOUT HOW. audit_requirement_fidelity now treats a
    # NEVER-COMPARED built combination as a [FAIL] + exit 1 (promoted from [NOTE] once the residue
    # reached 0 portfolio-wide), so this mutation is CAUGHT: 0 -> 1 findings.
    # IT IS CAUGHT BY THE NEVER-COMPARED FAIL, **NOT** BY AN UNDER-REQUIRED FINDING. The gate still
    # cannot say WHICH mandatory field went missing; what it can now say is "I never compared this
    # combination, so read nothing into my silence about it". That is a weaker claim than detection
    # and it is the honest one -- do not read this KILLED as evidence that component-level
    # UNDER-REQUIRED detection improved. It did not.
    # Why that is nonetheless the right fix: UNDER-REQUIRED was never broken -- it fires whenever the
    # combo is PAIRED (CA_CONTRA_COSTA reports 4 UNDER today). The defect hid entirely in the SKIP,
    # so closing the skip closes the escape without re-scoring the pairing, which is the change that
    # produced a 36-finding blast radius and was reverted.
    #
    # ⚠️ A SECOND REPRODUCTION I CLAIMED WAS FALSE, recorded so it is not re-added as evidence:
    # TX_TLETS_CCH BQBoatHullIdNumber / RegistrationState looked identical, but metadata
    # BQ{BoatHullIdNumber} = Set[BoatHullIdNumber] Any[State] -- State is OPTIONAL there, so
    # demoting it ALIGNS the build with metadata and 0 UNDER was the CORRECT answer. Always read the
    # variant's own <Requirements> before calling a demotion under-required.
    @{ Id='ny-demote-mandatory-qualifier'
       Desc='BirthDateDH demoted from DALH set[] to any[] though metadata DALL{Name} mandates BirthDate in BOTH alternatives -- DALH can then fire without it and the request is invalid'
       Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
       # Cannot go stale silently: if BirthDateDH ever leaves DALH's set[], or the metadata stops
       # mandating BirthDate, this reports INVALID instead of masquerading as a survivor.
       Valid={ param($j) $c=Get-Cfg $j '*_DriverHistoryQuery'; $cm=Get-Combo $c 'DALH'
               @($cm.requirements.set) -contains 'BirthDateDH' }
       ValidWhy='BirthDateDH is no longer in DALH set[], so this mutation cannot create an UNDER-REQUIRED demotion. Re-derive against the current DH combos before re-aiming.'
       Mut={ param($j) $c=Get-Cfg $j '*_DriverHistoryQuery'; $cm=Get-Combo $c 'DALH'
             $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'BirthDateDH' })
             $cm.requirements.any=@(@($cm.requirements.any) + 'BirthDateDH') } }

    @{ Id='ny-dup-targetfield'
       Desc='two attributes writing one outbound targetField in a REQUEST QIDM (FIELD_REFERENCE Sec 4)'
       Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
       Mut={ param($j) $c=Get-Cfg $j '*_GunQuery'; $a=$c.attributes[0].PSObject.Copy(); $a.name='ClonedForMutation'; $c.attributes=@($c.attributes)+$a } }

    @{ Id='ny-remove-a-built-combo'
       Desc='delete the VehicleRegistrationQuery RCAR combo (VIN-only, in-state) -- a real search path disappears'
       Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
       Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'
             $cm=Get-Combo $c 'RVIN'; $cm.requirements.set=@('VehicleIdentificationNumber')
             $cm.requirements.conditions=@() } }

    @{ Id='ny-toplevel-version-field'
       Desc='a top-level version field, which the platform rejects (deserialised as Integer)'
       Gate='validate.ps1'; Args={ @('-Path',$workJson) }
       Mut={ param($j) $j | Add-Member -NotePropertyName version -NotePropertyValue '4.17' -Force } }
  )
}
# ── THE MUTATION TABLE ────────────────────────────────────────────────────────────────
# Each entry: the defect class, the gate that owns it, and the exact injection.
$MUTS = @(
  # ── registry currency ──────────────────────────────────────────────────────────────────
  @{ Id='nj-registry-row-stranded'; OnlyProvider='NJ_NJCJIS'
     Desc='LicensePlateTypeCode removed from RANDFULL any[] while NJ''s registry still carries the live row "RANDFULLN|RANDFULL ... LicensePlateTypeCode | demoted-to-any". That row now describes a placement that does not exist -- the exact shape of the FL_FCIC defect of 2026-08-03, where a promoted-to-any row outlived by four days the commit that closed it and got a version bump APPROVED before the emitted JSON refuted it. Catalogued because the gate built for that defect was BLIND to it on first write: v1 pooled every attribute in the QIDM, so a field defined on a SIBLING combo counted as present. It passed a clean 20-provider run while unable to fail.'
     Gate='audit_registry_currency.ps1'; Args={ @('-Provider','NJ_NJCJIS','-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'RANDFULL'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'LicensePlateTypeCode' }) } }

  # ── State-prefill routing (LIMITATION #30) ─────────────────────────────────────────────
  @{ Id='az-state-prefill-routes'; OnlyProvider='AZ_AZDPS'
     Desc='RegistrationState ADDED to DriverLicenseQuery/DQ set[], making it a routing field while the Person form still prefills it with initialValue=AZ -- the real LIMITATION #30 mechanism (an always-present field permanently hides every combo needing its ABSENCE). Catalogued 2026-08-04 alongside NARROWING that check: validate.ps1 G-3 used to fire on ANY QIDM that had a state=In or state=Out combo plus a State prefill, without asking whether State was in a set[] at all. That flagged AZ v3.5 twice purely because its DQP photo combos are honestly labelled state=In (metadata DQP defines NO State field, so they cannot serve out-of-state) while ACWL/DQ/DQN are In/Out -- a LABEL, not a routing risk, and the alternative was to MISLABEL DQP as In/Out to satisfy the gate. Measured at zero LIMITATION #30 lines across all 20 providers before narrowing, so no coverage was lost. This mutation is what makes the narrowed check''s PASS mean something: it puts State back into a set[] and the check must fail again.'
     Gate='validate.ps1'; Args={ @('-Path',$workJson) }
     # 2026-08-12 -- NOW INJECTS BOTH HALVES. It used to add State to set[] ONLY, and relied on the
     # AZ build already carrying initialValue='AZ' on the Person State control. AZ v3.10 adopted the
     # portfolio State convention (17 of 20 providers: 'State (leave blank for <ST>)' with NO
     # default), which REMOVED that prefill -- so the mutation stopped creating a LIMITATION #30
     # condition at all and reported SURVIVED while validate.ps1 was behaving correctly. State in a
     # set[] with no prefill is simply a mandatory field, not a routing hazard.
     # That is a STALE MUTATION, not a blind gate: its precondition was a build detail that
     # legitimately changed. A mutation must CREATE the whole defect it tests, never inherit half of
     # it from the provider -- otherwise a correct build change silently converts the catalogue entry
     # into a permanent false accusation, which is the exact failure mode this harness exists to
     # avoid inflicting on other gates.
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'; $cm=Get-Combo $c 'DQ'
           $cm.requirements.set=@(@($cm.requirements.set)+'RegistrationState')
           $n=Get-Node $j 'Person' 'RegistrationState'
           if ($n.props.PSObject.Properties.Name -contains 'initialValue') { $n.props.initialValue = 'AZ' }
           else { $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'AZ' -Force } } }

  # ── devdoc transaction-name scope ──────────────────────────────────────────────────────
  @{ Id='hi-out-of-basic-transaction'; OnlyProvider='HI_HCJDC_OFML'
     Desc='DriverLicenseQuery''s QIDM `query` renamed to the provider-prefixed HiHcjdcOfmlDriverLicenseQuery while queryLabel STAYS ''Driver License'' -- AZ_AZDPS''s exact live shape. The metadata defines DUPLICATE TRANSACTION PAIRS (a plain devdoc name and an <Provider>-prefixed sibling with DIFFERENT <Requirements>), so the prefixed one is a different query wearing an approved label. Catalogued because audit_supported_queries scored AZ [PASS] on EVERY combo for months -- it compared queryLabel against a hand-maintained extract and never looked at the transaction name, emitting "[PASS] combo DQSS: ''Driver License | SocialSecurityNumber'' is devdoc-supported" when AZ''s Basic DL entry defines no SSN field at all. On AZ the wrong sibling cost the two ImageIndicator="Y" photo paths (devdoc #2/#5, metadata DQP, which exists ONLY under the Basic transaction) and the name-only search (#3). The label is deliberately left UNCHANGED: mutating it too would be caught by the pre-existing label check and would prove nothing about CHECK 0. HI is the subject on purpose -- its Basic list was itself being under-read as 5 of 6 (pdftotext merges "BoatQuery" onto the field-table header), so this mutation guards the anchor fix as well as the scope check.'
     Gate='audit_supported_queries.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'
           $c.query = 'HiHcjdcOfmlDriverLicenseQuery' } }

  # ── attributeTypeId dropdown MUST be FormSelect (SEX / RACE) ───────────────────────────
  # GENERIC (no OnlyProvider): every provider builds a SexCode control with attributeTypeId='SEX'.
  # Catalogued 2026-08-07 with the validate.ps1 check it proves. The defect had NO gate: the SexCode
  # and raceCode checks validated PROPS (attributeTypeId / codeTypeProvider / codeTypeCategory) and
  # never the COMPONENT TYPE, so flipping FormSelect -> FormInput left all of them passing while the
  # officer free-types where a numeric RMS attribute ID is required. Found by fuzz on IL_LEADS_OFML
  # (`select-to-input @ ENTITY_Person[SexCode_Input]` SURVIVED the entire panel) -- and the identical
  # mutation on RegistrationState was CAUGHT, because the STATE block did test the type. One of three
  # attributeTypeId dropdowns covered, two not.
  @{ Id='sexcode-as-input'
     Desc='the Person SexCode control flipped from FormSelect to FormInput while keeping attributeTypeId=SEX + codeTypeProvider=NIBRS -- every props-based check still passes, but the officer now free-types where a numeric RMS attribute ID is required, breaking the CommSys code AND the RMS sex reverse-lookup'
     Gate='validate.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j)
           $n = $null
           foreach ($ent in @('Person')) { foreach ($fid in @('SexCode','sexCode')) {
               if (-not $n) { $n = Get-Node $j $ent $fid } } }
           if (-not $n) { throw 'no SexCode control on the Person form' }
           $n.type.resolvedName = 'FormInput' } }

  # SECOND member of the same class, catalogued because the FIRST fix was scoped too narrowly and
  # only more fuzz seeds revealed it. sexcode-as-input covers the attributeTypeId branch; this
  # covers the codeTypeCategory branch, which stayed uncovered and kept surviving on
  # relatedHitSearchIndicator across FOUR entities plus articleTypeCode. Two mutations, because a
  # single one would let half the rule rot silently if the other branch regressed.
  @{ Id='codetype-select-as-input'
     Desc='a codeTypeCategory-driven dropdown (relatedHitSearchIndicator, YES_NO_UNKNOWN) flipped from FormSelect to FormInput with its props intact -- the officer free-types where a coded value is required and it reaches the wire uncoded. Distinct from sexcode-as-input: that one is attributeTypeId-driven, this one codeTypeCategory-driven, and the original SEX/RACE-only check was blind to this branch.'
     Gate='validate.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j)
           # Prefer the historically-named controls so the mutation stays byte-identical on the 14
           # providers where it already ran; fall back to ANY codeTypeCategory FormSelect, which is
           # what the rule is actually about. See Get-CodeTypeSelectNode for the 6-provider blind
           # spot this closes.
           $n = $null
           foreach ($ent in @('Vehicle','Person','Firearm','Boat')) {
               foreach ($fid in @('relatedHitSearchIndicator','RelatedHitSearchIndicator','ImageIndicator')) {
                   if (-not $n) { $n = Get-Node $j $ent $fid } } }
           if (-not $n) { $n = Get-CodeTypeSelectNode $j }
           if (-not $n) { throw 'no codeTypeCategory-driven FormSelect exists in this JSON to mutate' }
           $n.type.resolvedName = 'FormInput' } }

  # ── IL_LEADS_OFML ──────────────────────────────────────────────────────────────────────
  # Added 2026-08-07 at v2.1. BEFORE this map, IL ran only the 6 generic/structural mutations
  # (banned-pattern, toplevel-version-field, entities-bundle-not-first, missing-querylabel,
  # dup-targetfield-request, vehiclemake-as-input) and scored a flattering "6/6 KILLED" -- which is
  # 6 of the 15 known defect classes, i.e. 40%, with NOT ONE routing or combination mutation among
  # them. By LAW 2 that made every IL routing gate's PASS non-evidence, and the "6/6" actively
  # concealed it. IL's routing is condition-heavy (three Vehicle combos separated ONLY by
  # RegistrationState EXISTS/NOT_EXISTS plus a Plate NOT_EXISTS guardrail), so the untested classes
  # were precisely the ones that matter here.
  #
  # IL SHAPE, read from the emitted v2.1 JSON (not the build script's intent):
  #   VehicleRegistrationQuery  Z2.P set[LicensePlateNumber]           cond RegistrationState EXISTS
  #                             Z2.V set[VehicleIdentificationNumber]  cond LicensePlateNumber NOT_EXISTS
  #                             Z5   set[LicensePlateNumber]           cond RegistrationState NOT_EXISTS
  #   DriverLicenseQuery        Z2.N set[BirthDate,NameLast,NameFirst] cond OperatorLicenseNumber NOT_EXISTS
  #                             Z2.O set[OperatorLicenseNumber]        (ungated)
  #   GunQuery QG / ArticleSingleQuery QA / BoatQuery BQ.H (ungated), BQ.R cond Hull NOT_EXISTS
  @{ Id='il-prefill-routing-field'; OnlyProvider='IL_LEADS_OFML'
     Desc='initialValue=IL on the Vehicle RegistrationState control. It is the sole discriminator between Z2.P (State EXISTS) and Z5 (State NOT_EXISTS), so prefilling it makes State permanently present and Z5''s NOT_EXISTS permanently FALSE -- Z5, the in-state plate search, becomes self-unsatisfiable. This is BUILD_RULES 24, the class that killed 35 combos across 6 providers, and it is exactly what IL''s v2.0 BUILD_NOTES records DROPPING the State initialValue to avoid. Targets the discriminator rather than a field every combo needs, so the mutation CREATES the defect instead of resembling it.'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'RegistrationState'; $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'IL' -Force } }

  @{ Id='il-demote-set-to-any'; OnlyProvider='IL_LEADS_OFML'
     Desc='VehicleIdentificationNumber demoted from Z2.V set[] to any[] though metadata Z2{VehicleIdentificationNumber} requires it in <Set>. The query could then fire with no VIN at all -- an INVALID request, the severity-1 UNDER-REQUIRED class.'
     Gate='audit_metadata.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'Z2.V'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'VehicleIdentificationNumber' })
           $cm.requirements.any=@(@($cm.requirements.any)+'VehicleIdentificationNumber') } }

  @{ Id='il-promote-any-to-set'; OnlyProvider='IL_LEADS_OFML'
     Desc='relatedHitSearchIndicator PROMOTED into Z5 set[] though metadata Z5 defines it in <Any>. Making an optional stolen-check flag mandatory means the in-state plate search cannot fire until the officer sets it.'
     Gate='audit_metadata.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'Z5'
           $cm.requirements.set=@(@($cm.requirements.set)+'relatedHitSearchIndicator') } }

  @{ Id='il-poisoned-condition'; OnlyProvider='IL_LEADS_OFML'
     Desc='A value-comparison operator (EQUALS) added to Z2.P''s conditions array alongside its EXISTS gate. ONE value-comparison operator disables the ENTIRE conditions array including the co-resident EXISTS (QIDM_REFERENCE Sec 2a), so Z2.P would stop being State-gated and, sitting at index 0 with set[LicensePlateNumber], would steal every plate fill from Z5. Nothing about the array LOOKS broken, which is why this class needs a gate rather than review.'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'Z2.P'
           $cm.requirements.conditions=@(@($cm.requirements.conditions)+([pscustomobject]@{ field=@('LicensePlateTypeCode'); operator='EQUALS'; value='PC' })) } }

  @{ Id='il-drop-identifier-guardrail'; OnlyProvider='IL_LEADS_OFML'
     Desc='Z2.V''s "LicensePlateNumber NOT_EXISTS" guardrail removed. The condition is load-bearing and the trace is not obvious: on plate+VIN with NO State, Z2.P fails (State EXISTS false), so evaluation reaches Z2.V -- whose set[VIN] IS satisfied -- and only the guardrail defers it so Z5 can serve the plate. Without it a VIN search fires where the officer supplied a plate, inverting IL''s Plate>VIN identifier priority. AIMED AT audit_devdoc_order, NOT audit_combo_reachability: the first version targeted reachability and correctly SURVIVED, because nothing becomes unreachable (Z5 still fires on plate-only, no State) -- what changes is WHICH combo wins a plate+VIN fill, which is an ORDERING defect. Repointed 2026-08-07 rather than recorded as a blind spot, per "a mutation must be aimed at the gate that OWNS the defect class" -- the same error that made nj-drop-devdoc-optional a false survivor. Devdoc VehReg #1 is the plate search, so a now-ungated VIN combo sitting ahead of it is exactly the INVERSION that gate defines.'
     Gate='audit_devdoc_order.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'Z2.V'
           $cm.requirements.conditions=@() } }

  @{ Id='il-inert-condition-field'; OnlyProvider='IL_LEADS_OFML'
     Desc='Z2.N''s condition repointed from OperatorLicenseNumber to a fieldId no control emits (NoSuchField), so the OLN>Name guardrail silently stops discriminating while still LOOKING present in the JSON. A condition naming a non-existent sourceField is inert, and an inert guardrail reads identical to a working one on review.'
     Gate='audit_wiring_closure.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'; $cm=Get-Combo $c 'Z2.N'
           $cm.requirements.conditions[0].field=@('NoSuchField') } }

  @{ Id='il-drop-devdoc-optional'; OnlyProvider='IL_LEADS_OFML'
     Desc='firearmMake removed from QG any[] though the IL devdoc lists GunQuery #1 as "GunSerialNumber, [GunCaliber, GunMake, ImageIndicator, ...]" and metadata QG defines GunMake in <Any>. Both authorities agree it is carryable, so the officer types a make and it is silently not transmitted -- the dropped-optional class, which errors nowhere.'
     Gate='audit_devdoc_optionals.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_GunQuery'; $cm=Get-Combo $c 'QG'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'firearmMake' }) } }

  @{ Id='il-remove-a-built-combo'; OnlyProvider='IL_LEADS_OFML'
     Desc='BQ.R deleted outright. The IL devdoc lists BoatQuery #2 as "RegistrationNumber, State, [...]" and metadata defines BQ{RegistrationNumber}, so removing it deletes a documented search path. This is the class that is invisible to every JSON-enumerating check -- the test plan is generated FROM the JSON, so no combo means no test means no failure -- and only a devdoc->built direction can see it (LAW 3).'
     Gate='audit_devdoc_combinations.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'
           $c.combinations=@(@($c.combinations) | Where-Object { "$($_.keyReference)" -ne 'BQ.R' }) } }

  @{ Id='il-true-shadow-pair'; OnlyProvider='IL_LEADS_OFML'
     Desc='Both Z2.P''s and Z5''s conditions stripped, leaving two combinations with IDENTICAL set[LicensePlateNumber] and nothing to separate them. Z2.P sits first, so Z5 can never fire under any fill -- a genuine shadow no ordering can fix. Distinct from il-drop-identifier-guardrail: that one inverts which query serves a fill, this one makes a combination permanently dead.'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'
           (Get-Combo $c 'Z2.P').requirements.conditions=@(); (Get-Combo $c 'Z5').requirements.conditions=@() } }

  @{ Id='il-fidelity-demote-mandatory'; OnlyProvider='IL_LEADS_OFML'
     Desc='articleTypeCode demoted from QA set[] to any[] though metadata QA requires Set[ArticleSerialNumber, ArticleTypeCode]. Demotes the QUALIFIER, deliberately NOT the ArticleSerialNumber identifier: FL taught that demoting an identifier lets the matcher simply RE-PAIR the alternative to a sibling combo that still carries it, so the mutation is defeated by re-pairing rather than by gate blindness. IL has only ONE Article combination, so there is no sibling to re-pair to and the defect must surface.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_ArticleSingleQuery'; $cm=Get-Combo $c 'QA'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'articleTypeCode' })
           $cm.requirements.any=@(@($cm.requirements.any)+'articleTypeCode') } }

  # PROMOTED FUZZ SURVIVOR (fuzz seed 33 #4, triaged real 2026-08-07) -- and the mutation that
  # CAUSED audit_wiring_closure class J to exist. It survived every gate on the panel because no
  # gate asked the per-COMBINATION question: audit_wiring_closure was per-provider (State still
  # reaches the wire via sibling combos, so it looked wired) and audit_devdoc_optionals cannot see
  # it either, because State is NOT a devdoc OPTIONAL on VehReg -- it is mandatory on devdoc #5 and
  # absent from #1's brackets, so there is no optional subset to test. Aiming it at 2q was my error;
  # the honest fix was a new class, not a wider 2q. Class J baseline: 100 EXISTS conditions examined
  # portfolio-wide, 1 pre-existing hit (TN_TIES RQ05).
  # PROMOTED FROM A FUZZ SURVIVOR, 2026-08-13. fuzz_gate_efficacy (seed 558203) reported
  # 'set-to-any @ DriverLicenseQuery[0] NameLast' SURVIVED. Triaged REAL: control and mutant BOTH
  # scored 9 branches compared / 0 UNDER / 0 OVER, so the gate looked and could not see it. Cause:
  # audit_requirement_fidelity resolves set[]/any[] through the QIDM attribute map, and every name
  # component maps onto the single targetField 'Name' -- so [NameLast,NameFirst] and [NameFirst] are
  # byte-identical after resolution. Distinct from il-fidelity-demote-mandatory, which demotes a
  # SCALAR field (articleTypeCode) and was always caught; only a COMPOSITE hides this way.
  # Fixed by the composite-completeness check in audit_requirement_fidelity; this mutation is what
  # stops it silently regressing. Portfolio impact of the fix when added: 421 branches compared
  # before and after, 0 providers drifted, so it introduced no false positives.
  @{ Id='il-fidelity-composite-incomplete'; OnlyProvider='IL_LEADS_OFML'
     Desc='NameLast demoted from Z2.N set[] to any[] though metadata Z2{Name} puts Name in <Set> with no looser variant and no <Choice>. The DL name search could then fire on DOB + first name alone, and FormatStringRuleHandler would put a surname-less ", JOHN" on the wire. Invisible to field-granularity comparison because the sibling component NameFirst still resolves to targetField Name.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'; $cm=Get-Combo $c 'Z2.N'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'NameLast' })
           $cm.requirements.any=@(@($cm.requirements.any)+'NameLast') } }

  # PROMOTED FUZZ SURVIVOR (CA_SAN_LUIS_OBISPO, seed 1246792, triaged real 2026-09-02) -- the
  # SIBLING-VARIANT OPTIONAL LEAK. audit_requirement_fidelity collected the metadata <Any> pool
  # keyed on "transaction|keyRef" instead of the full "transaction|keyRef|primaryFieldReference"
  # triple, so EVERY alternative of a keyRef inherited every sibling alternative's optionals and an
  # over-permit against the narrower variant read as legal. The original survivor was SexCodeDH on
  # DriverHistoryQuery B2.O (metadata B2{OLN} = Set[OLN] Any[Attention,PurposeCode]; SexCode is in
  # the SIBLING B2{Name}'s <Any>). Catalogued here on the VEHICLE family instead, because that is
  # where the SAME bug was hiding real live defects on three providers -- CA_SLO 2, CA_eSUN 4 and
  # tenant-verified CA_CLETS_OCATS 2 -- all of them a plate combo carrying the VIN sibling's
  # VehicleMakeCode/VehicleYear. SLO's RQ{LicensePlateNumber} declares NO <Any> AT ALL, so the pool
  # is unambiguously empty and the mutation cannot be excused by a looser reading.
  # WHY THIS MUTATION AND NOT THE DH ONE: the asymmetry that made the bug diagnosable was that the
  # identical mutation on sibling KQ.O was CAUGHT, purely because KQ{Name} carries SexCode in <Set>
  # rather than <Any>. A mutation whose kill depends on which grammar slot a THIRD variant used is
  # too fragile to be a permanent catalogue row; the empty-<Any> Vehicle case is not.
  # If someone re-widens that pool key back to the keyRef "to avoid false positives", this SURVIVES.
  @{ Id='slo-fidelity-sibling-optional-leak'; OnlyProvider='CA_SAN_LUIS_OBISPO'
     Desc='VehicleMakeCode added to RQ.P any[] though metadata RQ{LicensePlateNumber} declares NO <Any> at all -- the field is defined only on the VIN sibling RQ{VehicleIdentificationNumber}. Was SURVIVED before 2026-09-02 because the optional pool was keyed on keyRef alone, so the plate variant inherited the VIN variant''s optionals. A KEYREF IS NOT A VARIANT.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'RQ.P'
           if ($null -eq $cm.requirements.PSObject.Properties['any']) { Add-Member -InputObject $cm.requirements -MemberType NoteProperty -Name any -Value @('VehicleMakeCode') }
           else { $cm.requirements.any=@(@($cm.requirements.any)+'VehicleMakeCode') } } }

  @{ Id='il-guardrail-wire-leak'; OnlyProvider='IL_LEADS_OFML'
     Desc='RegistrationState removed from Z2.P any[] while its "RegistrationState EXISTS" routing condition is left in place -- the field decides which query fires and then does not ride the wire, so an out-of-state plate query goes out with no destination state. Per-COMBINATION defect: sibling combos still carry State, so every per-provider and form-level check reads it as wired.'
     Gate='audit_wiring_closure.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'Z2.P'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'RegistrationState' }) } }

  # ── OR_LEDS ────────────────────────────────────────────────────────────────────────────
  @{ Id='or-drop-devdoc-mandatory-from-firing-combo'; OnlyProvider='OR_LEDS'
     Desc='RegistrationState removed from RQ.V any[] -- the MANDATORY-NOT-TRANSMITTED class, closed 2026-08-27. OR devdoc VehicleRegistrationQuery #4 is "(Out) VehicleIdentificationNumber, State [VehicleMakeCode, VehicleYear]", so State is MANDATORY on the out-of-state VIN search; removing it there leaves it wired on RQ.PO and RQ.P, so the officer can no longer perform that search and nothing errors. MEASURED BEFORE THE FIX: SURVIVED all 7 gates that reached a verdict (validate, verify_build, audit_metadata, audit_requirement_fidelity, audit_devdoc_combinations, audit_devdoc_optionals, audit_combo_reachability) with BYTE-IDENTICAL output on both arms. Why each was blind: audit_devdoc_combinations (2p) asks only whether a mandatory field is wired SOMEWHERE in the query and a sibling satisfies that; audit_devdoc_optionals tracked OPTIONALS only; audit_requirement_fidelity compares against METADATA, and OR metadata has State in <Any> on RQ{VIN}, so a request without it is perfectly VALID -- nothing is metadata-wrong, what breaks is LAW 1 (the officer cannot reach a devdoc-listed search). DELIBERATELY DISTINCT from il-drop-any-with-live-condition, which removes RegistrationState from IL Z2.P any[] while leaving its "RegistrationState EXISTS" condition in place: that one is caught by audit_wiring_closure class D (inert condition). RQ.V has NO condition on State -- its condition is LicensePlateNumber NOT_EXISTS -- so there is no inert condition to detect, which is exactly why this survived and that one does not. If someone removes the re-route guard from the mandatory check, this still KILLs but the portfolio gains ~18 false positives from identifier-priority guardrails; see the comment in audit_devdoc_optionals.'
     Gate='audit_devdoc_optionals.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'RQ.V'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'RegistrationState' }) } }

  # ── FL_FCIC ────────────────────────────────────────────────────────────────────────────
  @{ Id='fl-drop-optional-everywhere'; OnlyProvider='FL_FCIC'
     Desc='Requestor removed from EVERY BoatQuery combination -- the genuine dropped-optional defect, as opposed to removing it from ONE combo (which is a CORRECT survivor, because the LIMITATION #1/#40 union pool still carries it from a co-matching combination). Catalogued 2026-08-12 after I reported a non-existent "the re-route NOTE masks a dropped optional" hole in audit_devdoc_optionals: the DROPPED check runs FIRST and continues, so the NOTE is only reached when nothing was dropped, and the union pool is CORRECT because LIMITATION #40 proves the wire is a union across every MATCHING combination (38/38 FL Boat logs, 0 mispredicted). This mutation exists so the distinction is permanent: it must KILL, while a single-combo removal legitimately survives. If someone "fixes" the union pool into a per-combo check, the tool starts reporting drops that do not occur on the wire.'
     Gate='audit_devdoc_optionals.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'
           foreach ($cb in @($c.combinations)) {
             foreach ($k in @('set','any')) {
               $cur = @($cb.requirements.$k)
               if ($cur -contains 'Requestor') { $cb.requirements.$k = @($cur | Where-Object { $_ -ne 'Requestor' }) } } } } }

  @{ Id='fl-drop-devdoc-optional'; OnlyProvider='FL_FCIC'
     Desc='RegistrationNumber removed from QBBoatHullIdNumber any[] -- reverts the dropped-optional fix (officer types hull + reg number, reg number silently not transmitted). RE-POINTED 2026-08-12, and the reason is the standing trap: it used to aim at FBQBoatHullIdNumber, which FL v7.22 made a REGISTERED DEAD COMBO (Rob directed the Boat Stolen Check to default Y, so that combo''s relatedHitSearchIndicator NOT_EXISTS condition is permanently false). A combo that cannot fire cannot produce a dropped-optional finding, so the mutation silently became a NO-OP and reported *** SURVIVED -- GATE IS BLIND *** on a gate that had fired 5 times that same hour. A STALE MUTATION LOOKS EXACTLY LIKE A BLIND GATE; the fix is the mutation, never the gate. QB{BoatHullIdNumber} is the live equivalent -- metadata defines RegistrationNumber in its <Any> and v7.22 added it there for exactly this devdoc-optional reason, so the mutation now reverts a real, reachable fix.'
     Gate='audit_devdoc_optionals.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'; $cm=Get-Combo $c 'QBBoatHullIdNumber'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'RegistrationNumber' }) } }

  @{ Id='fl-fidelity-demote-mandatory'; OnlyProvider='FL_FCIC'
     Desc='LicensePlateYear demoted from FRQDecalNumber set[] to any[] though metadata FRQ{Decal} requires set[DecalNumber, LicensePlateYear]. Demotes a QUALIFIER, deliberately NOT the identifier: the first version demoted BoatHullIdNumber out of FBQBoatHullIdNumber, and once the matcher became identifier-first that alternative simply RE-PAIRED to QBBoatHullIdNumber (which still carried the hull) and no finding appeared -- the mutation was defeated by re-pairing rather than by gate blindness. A mutation must create a defect the matcher cannot route around.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'FRQDecalNumber'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'LicensePlateYear' })
           $cm.requirements.any=@(@($cm.requirements.any)+'LicensePlateYear') } }

  @{ Id='fl-drop-identifier-from-set'; OnlyProvider='FL_FCIC'
     Desc='OperatorLicenseNumber deleted from FDQOperatorLicenseNumber set[] entirely -- the mutation the entry above had to ABANDON. That note records demoting the identifier being "defeated by re-pairing rather than by gate blindness": branch/combo pairing is a score-based best fit and legally many-to-one, so a sibling combo that still carried the identifier simply outscored the cripple and took the branch. Every branch stayed served, branches-compared did not move, and the report read 0 UNDER-REQUIRED. fuzz_gate_efficacy found it independently (seed 777, drop-set) and it was confirmed NOT a regression by running the pre-change tool from git against the same mutant. Closed 2026-08-03 by the UNSATISFIED-CLAIM check, which walks BUILT combinations instead of metadata branches and so cannot be routed around: a search combination whose set[] carries no identifier cannot identify a record. Measured across the portfolio at 411 branches / 0 UNSATISFIED-CLAIM before being catalogued.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'; $cm=Get-Combo $c 'FDQOperatorLicenseNumber'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'OperatorLicenseNumber' }) } }

  @{ Id='fl-prefill-routing-field'; OnlyProvider='FL_FCIC'
     Desc='LicensePlateNumber given a form initialValue while it is a set[] discriminator -- BUILD_RULES 24, the class that killed 35 combos across 6 providers'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'LicensePlateNumber'; $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'AAA1234' -Force } }

  # ── NJ_NJCJIS ──────────────────────────────────────────────────────────────────────────
  @{ Id='nj-devdoc-order-inversion'; OnlyProvider='NJ_NJCJIS'
     Desc='BoatQuery combos left in devdoc-inverted order (QB=devdoc#2 ahead of QBN=devdoc#1) AND QB stripped of its BoatHullIdNumber NOT_EXISTS guardrail -- so a hull+regnum over-fill fires the devdoc-LATER path. This is line 2 of the ordering rule (Rob 2026-07-31): specificity cannot separate two equally-specific single-identifier searches, so the devdoc order decides. NJ is CORRECT today only because that guardrail defers to hull; remove it and the inversion becomes real.'
     Gate='audit_devdoc_order.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'; $cm=Get-Combo $c 'QB'
           $cm.requirements.conditions=@() } }

  # DELIBERATELY NOT A MUTATION: the entity-prefix alias guard (2026-07-31).
  # I added `nj-devdoc-prefix-blind` here -- rename BoatHullIdNumber to BoatBoatHullIdNumber
  # everywhere so the field is still fully wired but prefixed, and audit_devdoc_combinations must
  # still see it as wired. It reported SURVIVED, which was the CORRECT behaviour (the tool stayed
  # silent because the field IS wired) but this harness's semantics are "inject a DEFECT, the gate
  # must FAIL". An inverted assertion parked here shows up as a permanent SURVIVED row, i.e. a
  # standing accusation that the gate is blind -- which would teach the next session to skim past
  # survivors, the exact habit these tools exist to prevent. Removed same day.
  # The prefix handling is instead protected by: (a) the $entityPrefixes list and its rationale in
  # audit_devdoc_combinations, and (b) the recorded evidence that CA_eSUN went 4 devdoc FAILs -> 0.
  # If someone wants a regression test for it, it belongs in a known-answer harness, not here.

  @{ Id='nj-guardrail-wire-leak'; OnlyProvider='NJ_NJCJIS'
     Desc='RegistrationNumber removed from QBN any[], making the reg number a genuine OUT-OF-POOL identifier on the hull-wins guardrail wire. Guards the 2026-07-31 widening of the guardrail-wire exemption: that check used to compare only against the winner BASE combo test fills, which are minimum-required-only, so a devdoc-sanctioned OPTIONAL identifier on the winner (devdoc BoatQuery #1 lists RegistrationNumber as opt on the hull query) read as a leak. The exemption now uses the winner combo set[] u any[] POOL -- and this mutation proves that widening did not make the check unfailable: an identifier NOT in the pool still FAILs. Without it the widening would be indistinguishable from deleting the check.'
     Gate='audit_log_content.ps1'; Args={ @('-Path',$workJson) }
     # MIS-AIMED, and NOT fixable by adding the missing test. audit_log_content's guardrail-wire
     # check reads ONLY plan tests with kind='guardrail'. NJ's plan has exactly TWO -- Vehicle and
     # Person -- and NO Boat guardrail test, so mutating Boat QBN's any[] is evaluated by nothing.
     # ⚠️ DO NOT "FIX" THIS BY GENERATING A BOAT GUARDRAIL TEST. NJ deliberately rides
     # RegistrationNumber along on the hull query, because NJ's devdoc lists it as an optional on
     # the hull combination -- HI's does not, which is why HI HAS QB_guardrail_vs_BQ and sends hull
     # ONLY. HI's own BUILD_NOTES record the contrast verbatim: "Same-looking guardrail, two right
     # answers, each decided by the provider's OWN authority." The guardrail-wire check demands
     # winner-only XML, so a Boat guardrail test on NJ would FAIL on a CORRECT build and would
     # archive a tenant-verified 39-log package to do it. That wrong fix was proposed and withdrawn
     # on 2026-09-08 -- the precondition below exists so it is not proposed a third time.
     # TO RE-AIM: point this at Vehicle or Person, where a kind='guardrail' plan test exists.
     # READ THE PLAN FROM THE REAL PROVIDER DIR ($srcDir), NOT THE REPLICA. The replica copies only
     # source/scripts/docs -- never logs -- and audit_log_content itself says "-Path overrides ONLY
     # the provider JSON ...; logs and the test plan still come from the provider directory". Looking
     # in the replica would return $false because the FILE IS ABSENT, i.e. the right verdict for the
     # wrong reason, and would keep reading INVALID even after a Boat guardrail test was added.
     # RECLASSIFIED N/A 2026-09-09, after MEASURING that it is unhostable ANYWHERE.
     # The instruction above said "re-aim at Vehicle or Person". That was investigated and it does
     # not work, for a structural reason worth writing down so nobody re-attempts it:
     #   A -Path mutation can only change the WINNER'S POOL (set[] u any[] from the JSON). The
     #   losing identifiers, the winner ids and the wire itself all come from the PLAN and the
     #   COMMITTED LOGS, which -Path does not touch. So the ONLY way a pool removal can cause a
     #   FAIL is if a losing identifier is ON THE WIRE and exempted ONLY by the pool.
     #   NJ's two guardrails are both CLEAN -- Vehicle RANDFULL's wire carries no VIN, Person
     #   FULLN's carries no Name -- so there is no exemption to withdraw on either.
     #   A 20-provider sweep of every guardrail plan test found **ZERO** cases portfolio-wide where
     #   the pool exemption changes a verdict. The exemption is currently INERT everywhere.
     # KEEP THE EXEMPTION REGARDLESS: it is a guard against a FALSE FAIL when a provider legitimately
     # rides an optional identifier along (the live NJ v4.15 Boat case that motivated it). Inert is
     # not dead -- removing it would re-break Rob's devdoc-order ruling the moment such a plan test
     # exists. What is NOT true any more is that this mutation proves the guard works; nothing can,
     # until a provider's plan carries a guardrail of that shape.
     NaIf={ param($j) $true }
     NaWhy="UNHOSTABLE PORTFOLIO-WIDE, not stale and not re-aimable. A -Path mutation can only change the winner's POOL; losers/winner-ids/wire come from the plan + committed logs. Failing needs a losing identifier ON THE WIRE exempted ONLY by the pool -- a 20-provider sweep found ZERO such guardrails (NJ Vehicle sends no VIN, NJ Person sends no Name). Do NOT add a Boat guardrail test to NJ: its devdoc permits RegistrationNumber on the hull query, so winner-only XML would FAIL on a correct build. The exemption stays as a false-FAIL guard; it is inert, not dead."
     Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'; $cm=Get-Combo $c 'QBN'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'RegistrationNumber' }) } }

  @{ Id='nj-fidelity-demote-mandatory'; OnlyProvider='NJ_NJCJIS'
     Desc='LicensePlateNumber demoted from RANDFULL set[] to any[] though metadata RAND/FULL both require it'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'RANDFULL'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'LicensePlateNumber' })
           $cm.requirements.any=@(@($cm.requirements.any)+'LicensePlateNumber') } }

  @{ Id='nj-drop-metadata-mandatory'; OnlyProvider='NJ_NJCJIS'
     Desc='RandomRequest removed from RANDFULL entirely. NJ rides RandomRequest/State/PlateType in any[] precisely so BOTH byte-identical metadata variants (RAND and FULL) stay satisfiable, so dropping it makes a metadata-MANDATORY field unreachable in that combination. GATE CORRECTED 2026-07-30: this was first aimed at audit_devdoc_optionals, which correctly stayed SILENT -- RandomRequest is metadata-mandatory and is NOT listed as a devdoc optional, so no optional subset was being dropped and 2q had nothing to say. A mutation must be aimed at the gate that OWNS the defect class; audit_metadata owns combination field coverage.'
     # GATE CORRECTED TWICE. First aimed at audit_devdoc_optionals, which correctly stayed silent --
     # RandomRequest is metadata-MANDATORY, not a devdoc optional, so no optional subset was dropped.
     # Then at audit_metadata, which ALSO cannot see it: its CHECK 4 tests coverage across the UNION
     # of the sibling combos implementing a keyRef ("covered by RANDFULL,RANDFULLN"), so a field
     # removed from ONE combination still passes while the other carries it. That union blindness is
     # a REAL documented gap (ENGINEERING_STANDARD) and is NOT fixed here.
     # audit_requirement_fidelity is per-combination and DOES own this class. It reports because the
     # 'demoted-to-any' registry entry only excuses the field RIDING IN any[]; removing it entirely
     # leaves it transmittable NOWHERE, which is not the state that was granted.
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_VehicleRegistrationQuery'; $cm=Get-Combo $c 'RANDFULL'
           $cm.requirements.any=@(@($cm.requirements.any) | Where-Object { $_ -ne 'RandomRequest' }) } }

  @{ Id='nj-prefill-routing-field'; OnlyProvider='NJ_NJCJIS'
     Desc='LicensePlateNumber given a form initialValue. RANDFULL is combination [1] set[LicensePlateNumber] with NO conditions and RANDFULLN is [2] gated LicensePlateNumber NOT_EXISTS, so a prefilled plate makes RANDFULL match every submission AND fails RANDFULLN gate -- RANDFULLN is orphaned outright. BUILD_RULES 24.'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     # DIRECT ASSIGNMENT, not Add-Member: this field already HAS an initialValue property (empty
     # string), and Add-Member -Force on an existing NoteProperty did not take, so the replica went
     # unmutated and the harness reported SURVIVED against a gate that was never actually challenged.
     # Set the property when it exists; only Add-Member when it does not.
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'LicensePlateNumber'
           if ($n.props.PSObject.Properties.Name -contains 'initialValue') { $n.props.initialValue = 'AAA1234' }
           else { $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'AAA1234' -Force } } }

  @{ Id='prefill-routing-field'; OnlyProvider='TX_TLETS'
     Desc='initialValue on LicensePlateTypeCode -- RQ{Plate} is index 0 and its ONLY extra set[] field vs REG is PlateTypeCode, so prefilling it makes RQ match on Plate+Year alone and REG becomes unreachable. This is the EXACT prefill removed at v4.14. (First draft of this harness prefilled LicensePlateYear instead, which is in BOTH combos set[] and therefore starves neither -- it falsely accused the gate. A mutation must CREATE the defect, not merely resemble it.)'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'LicensePlateTypeCode'; $n.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'PC' -Force } }

  @{ Id='dup-targetfield-request'
     Desc='two attributes writing one outbound targetField in a REQUEST QIDM (FIELD_REFERENCE Sec 4)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_GunQuery'; $a=$c.attributes[0].PSObject.Copy(); $a.name='ClonedForMutation'; $c.attributes=@($c.attributes)+$a } }

  @{ Id='demote-set-to-any'; OnlyProvider='TX_TLETS'
     Desc='stickerNumber moved out of DPSI set[] into any[] (audit_metadata CHECK 4e)'
     Gate='audit_metadata.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*VehicleInsuranceRegistrationQuery'; $cm=Get-Combo $c 'DPSIStickerNumber'
           $cm.requirements.set=@('RegistrationState'); $cm.requirements.any=@('stickerNumber') } }

  @{ Id='promote-any-to-set'; OnlyProvider='TX_TLETS'
     Desc='regionId forced into RQ{VIN} set[] though metadata has it in any[] (CHECK 4d)'
     Gate='audit_metadata.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*VehicleInsuranceRegistrationQuery'; $cm=Get-Combo $c 'RQVehicleIdentificationNumber'
           $cm.requirements.set=@('VehicleIdentificationNumber','regionId') } }

  @{ Id='fidelity-demote-mandatory'; OnlyProvider='TX_TLETS'
     Desc='LicensePlateYear demoted from REG set[] to any[] though metadata REG REQUIRES it (audit_requirement_fidelity UNDER-REQUIRED). Proves the fidelity gate can fail -- until -Path was added it could not even be run against a replica, so it had no failure proof at all.'
     Gate='audit_requirement_fidelity.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*VehicleInsuranceRegistrationQuery'; $cm=Get-Combo $c 'REGLicensePlateNumber'
           $cm.requirements.set=@(@($cm.requirements.set) | Where-Object { $_ -ne 'LicensePlateYear' })
           $cm.requirements.any=@(@($cm.requirements.any)+'LicensePlateYear') } }

  @{ Id='poisoned-condition'; OnlyProvider='TX_TLETS'
     Desc='a value-comparison routing condition, which poisons the whole conditions array (AP/LIMIT)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_BoatQuery'; $cm=Get-Combo $c 'QBNCICNumber'
           $cm.requirements | Add-Member -NotePropertyName conditions -NotePropertyValue @([pscustomobject]@{field=@('RegistrationState');operator='EQUALS';value='TX'}) -Force } }

  @{ Id='drop-identifier-guardrail'; OnlyProvider='TX_TLETS'
     Desc='remove the Plate>VIN guardrail (LicensePlateNumber NOT_EXISTS) from RQ{VIN} (CHECK 10)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*VehicleInsuranceRegistrationQuery'
           foreach($kr in 'RQVehicleIdentificationNumber','VINVehicleIdentificationNumber'){
             $cm=Get-Combo $c $kr
             $cm.requirements.conditions=@($cm.requirements.conditions | Where-Object { "$($_.field)" -notmatch 'LicensePlateNumber' }) } } }

  @{ Id='vehiclemake-as-input'
     Desc='VehicleMakeCode changed from FormSelect to FormInput (hard gate: dropdown required)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     # N/A, NOT A HARNESS BUG: NJ_NJCJIS and HI_HCJDC_OFML carry NO VehicleMakeCode field in either
     # the form or any QIDM (verified 2026-08-01 -- neither provider's devdoc COMBINATIONS require it;
     # the devdoc's other mentions are response/field-definition tables). Get-Node returns $null and
     # the mutation used to die with "Cannot bind argument to parameter 'InputObject'", which reads
     # like a broken harness. Throw a clear message instead: the gate is not blind, there is simply
     # nothing for it to check on that provider, and its silence there proves nothing either way.
     # DECLARED N/A rather than left to throw. The throw above produced the right words under the
     # wrong verdict -- "[INVALID] mutation could not be applied" -- which counts toward the INVALID
     # total that ENGINEERING_STANDARD 5 requires to be ZERO. So a provider whose devdoc simply does
     # not call for a VehicleMakeCode control could never reach "finished", an un-clearable FAIL
     # (LAW 2b). Now it reports [N/A] and is counted separately. 6 of 20 providers are in this class.
     NaIf={ param($j) -not (Get-Node $j 'Vehicle' 'VehicleMakeCode') }
     NaWhy='this provider builds NO VehicleMakeCode control (form or QIDM) -- verified 2026-08-01, its devdoc COMBINATIONS do not require one. The gate is not blind; there is nothing here to check, and its silence proves nothing either way. Building one to satisfy this mutation would be OVER-BUILDING.'
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'VehicleMakeCode'
           if (-not $n) { throw "N/A -- this provider has no VehicleMakeCode form field, so the VehicleMakeCode gate has nothing to check here (not a gate defect, not a harness defect)" }
           # Craft.js stores type as {"resolvedName":"FormSelect"}; older shapes use a bare string.
           if($n.type -is [string]){ $n.type='FormInput' }
           elseif($n.type.PSObject.Properties.Name -contains 'resolvedName'){ $n.type.resolvedName='FormInput' }
           else { $n | Add-Member -NotePropertyName type -NotePropertyValue 'FormInput' -Force }
           if($n.props.PSObject.Properties.Name -contains 'codeTypeCategory'){ $n.props.PSObject.Properties.Remove('codeTypeCategory') }
           $n.props.PSObject.Properties.Remove('attributeTypeId') } }

  @{ Id='banned-pattern'
     Desc='reintroduce the banned LicensePlateNumberIn fieldId (CHECK 1)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'LicensePlateNumber'; $n.props.fieldId='LicensePlateNumberIn' } }

  @{ Id='inert-condition-field'; OnlyProvider='TX_TLETS'
     Desc='conditions[].field pointing at a non-existent fieldId, so the gate never fires (CHECK 11)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'; $cm=Get-Combo $c 'CPLName'
           $cm.requirements.conditions=@([pscustomobject]@{field=@('NoSuchFieldAnywhere');operator='NOT_EXISTS'}) } }

  @{ Id='toplevel-version-field'
     Desc='a top-level version field, which the platform rejects (deserialized as Integer)'
     Gate='validate.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $j | Add-Member -NotePropertyName version -NotePropertyValue '4.18' -Force } }

  @{ Id='entities-bundle-not-first'
     Desc='ENTITIES no longer the first bundle (forms silently do not render)'
     Gate='validate.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $b=@($j.bundles); $j.bundles=@($b[1],$b[0])+$b[2..($b.Count-1)] } }

  @{ Id='missing-querylabel'
     Desc='queryLabel removed from a QIDM (CHECK 5 reference patterns)'
     Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_ArticleSingleQuery'; $c.PSObject.Properties.Remove('queryLabel') } }

  @{ Id='drop-devdoc-optional'; OnlyProvider='TX_TLETS'
     Desc='BirthDate removed from CPLName any[], so a devdoc-legal optional cannot transmit'
     Gate='audit_devdoc_optionals.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_DriverLicenseQuery'; $cm=Get-Combo $c 'CPLName'
           $cm.requirements.any=@($cm.requirements.any | Where-Object { "$_" -ne 'BirthDate' }) } }

  @{ Id='remove-a-built-combo'; OnlyProvider='TX_TLETS'
     Desc='delete DPSIStickerNumber entirely (a whole devdoc search path disappears)'
     Gate='audit_devdoc_combinations.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*VehicleInsuranceRegistrationQuery'
           $c.combinations=@($c.combinations | Where-Object { "$($_.keyReference)" -ne 'DPSIStickerNumber' })
           # also strip the stickerNumber form field so the devdoc field is wired nowhere
           foreach($b in $j.bundles){ foreach($cf in $b.configurations){
             if($cf.type -ne 'QUERYINPUTFORM' -or "$($cf.targetEntity)" -ne 'Vehicle'){continue}
             foreach($v in 'default','CAD_DISPATCH','FIRST_RESPONDER'){ $lay=$cf.layout.$v; if(-not $lay){continue}
               foreach($nid in @($lay.PSObject.Properties.Name)){ if("$($lay.$nid.props.fieldId)" -eq 'stickerNumber'){ $lay.PSObject.Properties.Remove($nid) } } } } }
           $c.attributes=@($c.attributes | Where-Object { "$($_.name)" -ne 'StickerNumber' }) } }

  @{ Id='true-shadow-pair'; OnlyProvider='TX_TLETS'
     Desc='two combos with identical set[] and no discriminator, so the later one is unreachable'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     Mut={ param($j) $c=Get-Cfg $j '*_GunQuery'; $cm=Get-Combo $c 'QGNCICNumber'
           $cm.requirements.set=@('serialNumber') } }

  # ── DERIVED, EVERY PROVIDER ─────────────────────────────────────────────────────────────
  # These two carry the same defect classes as the TX/IL rows above, but compute their target
  # from whichever provider is running, so the fifteen thin providers stop scoring clean on the
  # globals alone. Each declares NaIf so a provider with no valid target reports [N/A] instead of
  # a false SURVIVED, and each Desc names the target it actually chose.
  @{ Id='derived-shadow-pair'
     Desc='DERIVED: the LAST combination of the largest QIDM has its set[] overwritten with the FIRST combination''s set[] and its conditions cleared, making it an exact duplicate ordered later -- so first-match starves it and it is unreachable. Same class as true-shadow-pair (TX) but self-targeting, so it exercises audit_combo_reachability on EVERY provider rather than one.'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     NaIf={ param($j) -not (Get-ShadowTarget $j) }
     NaWhy='no QIDM has two combinations whose set[] currently DIFFER, so no duplicate can be manufactured -- the mutation would be a no-op and a no-op cannot fail'
     Mut={ param($j) $t = Get-ShadowTarget $j
           if (-not $t) { throw 'no shadow target' }
           $t.Victim.requirements.set = @(@($t.Source.requirements.set))
           # BOTH sides' conditions go. The victim's, so nothing discriminates it; the SOURCE's,
           # so the source is unconditionally dominant and genuinely starves the victim. Clearing
           # only the victim's leaves a gated source that cannot starve anything -- see the note
           # in Get-ShadowTarget for the MD_METERS run where that reported a false SURVIVED.
           foreach ($cm in @($t.Source, $t.Victim)) {
               if ($cm.requirements.PSObject.Properties.Name -contains 'conditions') {
                   $cm.requirements.conditions = @()
               }
           } } }

  @{ Id='derived-prefill-routing-field'
     Desc='DERIVED: BUILD_RULES 24. Finds a combination whose set[] is an earlier sibling''s set[] PLUS EXACTLY ONE extra field, where that field has no form initialValue, and prefills it -- so the extra field is always present, the victim matches whenever the sibling does, and first-match starves the victim. This is TX''s real RQ/REG prefill derived rather than hardcoded. The one-extra-field test is what keeps it honest: prefilling a field present in BOTH combos starves neither and would falsely accuse a working gate, which is exactly how the first draft of prefill-routing-field went wrong.'
     Gate='audit_combo_reachability.ps1'; Args={ @('-Path',$workJson) }
     NaIf={ param($j) -not (Get-PrefillShadowTarget $j) }
     NaWhy='no (earlier-sibling + exactly-one-extra-unprefilled-field) triple exists here, so no prefill can create a shadow -- prefilling anything else would not change routing and the gate would be right to stay silent'
     Mut={ param($j) $t = Get-PrefillShadowTarget $j
           if (-not $t) { throw 'no prefill-shadow target' }
           $t.Node.props | Add-Member -NotePropertyName initialValue -NotePropertyValue 'X' -Force } }
)

# Fold in this provider's own map. A provider with no map still runs the generic mutations, but
# report the shortfall rather than letting a thin run look like full coverage.
if ($PROV_MUTS.ContainsKey($Provider)) {
    $MUTS += @($PROV_MUTS[$Provider])
}
# COUNT THE PROVIDER'S OWN MUTATIONS FROM BOTH SOURCES. There are two conventions in this file --
# the $PROV_MUTS hashtable (NY only) and an OnlyProvider tag on a $MUTS row (NJ, AZ, HI, FL, IL) --
# and this message used to consult ONLY the hashtable. So every provider using the second
# convention was told "no provider-specific mutation map" while running 4-11 dedicated mutations:
# NJ (4), AZ (1), HI (1), FL (4) and IL (11) all got a note asserting the opposite of the truth,
# directly understating the coverage this tool exists to report. Found 2026-08-07 while adding the
# IL map -- the note fired on a run in which all 11 IL mutations had just executed. The shortfall
# warning is still worth printing, but it must be driven by the ACTUAL count, not by one of the
# two places a map can live.
$ownCount = @($PROV_MUTS[$Provider]).Count + @($MUTS | Where-Object { $_.OnlyProvider -eq $Provider }).Count
if ($ownCount -gt 0) {
    Emit "  provider-specific mutations for ${Provider}: $ownCount" $null
} elseif ($Provider -ne 'TX_TLETS') {
    Emit "  [NOTE] no provider-specific mutation map for $Provider -- only the generic/structural mutations run, so the routing and combination classes are UNTESTED here and this run's KILLED score covers a fraction of the catalogue. That is honest, not a pass." 'Yellow'
}

# ── run ───────────────────────────────────────────────────────────────────────────────
$killed=0; $survived=0; $invalid=0; $na_count=0
Emit "" $null
Emit ("  {0,-26} {1,-34} {2}" -f 'MUTATION','GATE','VERDICT') $null
Emit ("  " + ("-"*88)) $null

foreach ($m in $MUTS) {
    if ($Only -and "$($m.Id)" -notlike "*$Only*") { continue }
    # A mutation that names concrete keyRefs/fieldIds is provider-shaped and must not be run
    # elsewhere. Running TX's combo mutations against NY produced 8 INVALID ("property 'set' cannot
    # be found") plus 1 false SURVIVED -- noise that buries the 6 real NY verdicts and, worse, looked
    # like a blind gate. Skip silently; the per-provider map is what supplies real coverage.
    if ($m.OnlyProvider -and $m.OnlyProvider -ne $Provider) { continue }

    # BASELINE: the gate must be clean on the pristine replica, or the harness is at fault
    Reset-Mutant
    $base = Run-Gate $m.Gate (& $m.Args)
    if (-not $base.Ok) {
        Emit ("  {0,-26} {1,-34} [INVALID] {2}" -f $m.Id,$m.Gate,$base.Detail) 'Yellow'; $invalid++; continue
    }
    if ($base.Vacuous) {
        Emit ("  {0,-26} {1,-34} [INVALID] baseline run was VACUOUS (0 PASS / skipped subject) -- the gate never looked, so nothing can be concluded" -f $m.Id,$m.Gate) 'Yellow'
        $invalid++; continue
    }
    # NOTE: the baseline is allowed to be non-zero. Some gates legitimately carry known,
    # adjudicated findings (audit_devdoc_optionals reports 3 NO-FIRE fills on TX by design).
    # Requiring a spotless baseline would make those gates untestable, so detection is measured
    # as an INCREASE over baseline, not as "any finding at all".

    # ── PRECONDITION: can this mutation still CREATE its defect? ────────────────────────────────
    # ENGINEERING_STANDARD 4.2: "a mutation must CREATE the defect, not resemble it. Verify the
    # mutant on disk before believing any SURVIVED verdict." Until 2026-09-08 nothing enforced that,
    # and the cost was measured: the portfolio's ONLY TWO surviving catalogued mutations were BOTH
    # broken tests, and both were reported for weeks as gate blind spots --
    #
    #   ny-drop-oos-guardrail  removes `RegistrationStateDH EXISTS` from DALLOUT to un-discriminate
    #                          it from DALL. But RegistrationStateDH is ALREADY MANDATORY in
    #                          DALLOUT's set[], so the condition is redundant and its removal
    #                          changes nothing. The named defect cannot occur.
    #   nj-guardrail-wire-leak takes RegistrationNumber out of Boat QBN's any[] to make it an
    #                          out-of-pool identifier on a guardrail wire. But audit_log_content's
    #                          guardrail check only reads plan tests with kind='guardrail', and NJ
    #                          has exactly two -- Vehicle and Person. There is no Boat guardrail
    #                          test, so nothing evaluates the change.
    #
    # In BOTH cases SURVIVED was the CORRECT answer and the gate was fine. That is worse than a
    # missed defect: a stale mutation is indistinguishable from a blind gate, so it sends you to
    # widen a gate that already works (usx-tooling: "a false SURVIVED is worse than a missed one").
    # ENGINEERING_STANDARD 5 already requires 0 INVALID as well as 0 SURVIVED -- this is what makes
    # the INVALID reachable instead of silently mislabelling it a survivor.
    #
    # A mutation MAY declare Valid={ param($j) ... } returning $true when its defect is still
    # creatable, plus ValidWhy for the message. Absent = assumed valid, so every existing row keeps
    # its current behaviour and this adds no verdict churn.
    # NOT-APPLICABLE IS NOT THE SAME AS STALE, and conflating them cost real time.
    # Added 2026-09-09. `INVALID` was carrying two opposite meanings:
    #   STALE -- the mutation USED to create its defect and no longer can. A real problem: it hides
    #            a gate nobody is testing, and a stale mutation is indistinguishable from a blind
    #            gate. Must be fixed.
    #   N/A   -- this provider legitimately has no such construct, so there is nothing to mutate.
    #            NOT a problem, and NOT fixable: "fixing" it means BUILDING something the provider's
    #            authority does not call for, which is the OVER-BUILD defect class.
    # ENGINEERING_STANDARD 5 requires 0 INVALID, and with both classes in one bucket that bar was
    # unreachable on providers with a legitimate N/A -- an un-clearable FAIL, which LAW 2b calls
    # noise. Measured on NJ_NJCJIS: BOTH its INVALIDs were N/A, not stale.
    #   * vehiclemake-as-input -- NJ builds NO VehicleMakeCode field (its devdoc does not require
    #     one), so verify_build's check has nothing to see here.
    #   * nj-guardrail-wire-leak -- unhostable ANYWHERE: a -Path mutation can only change the
    #     winner's POOL, while the losing ids, winner ids and wire all come from the plan and the
    #     committed logs. Failing needs a losing identifier that is ON THE WIRE and exempted ONLY by
    #     the pool, and a 20-provider sweep found ZERO such guardrails. It is not re-aimable.
    # N/A is still COUNTED AND PRINTED separately so it can never become a quiet dumping ground,
    # and it must be DECLARED by the mutation with a reason -- silence still reads as STALE.
    if ($m.NaIf) {
        $nj = $pristine | ConvertFrom-Json
        $na = $false
        try { $na = [bool](& $m.NaIf $nj) } catch { $na = $false }
        if ($na) {
            $why = if ($m.NaWhy) { $m.NaWhy } else { 'this provider has no such construct -- nothing to mutate' }
            Emit ("  {0,-26} {1,-34} [N/A] {2}" -f $m.Id, $m.Gate, $why) 'DarkGray'
            $na_count++; continue
        }
    }
    if ($m.Valid) {
        $vj = $pristine | ConvertFrom-Json
        $ok = $false
        try { $ok = [bool](& $m.Valid $vj) } catch { $ok = $false }
        if (-not $ok) {
            $why = if ($m.ValidWhy) { $m.ValidWhy } else { 'precondition not met -- this mutation can no longer create its defect' }
            Emit ("  {0,-26} {1,-34} [INVALID] STALE MUTATION: {2}" -f $m.Id, $m.Gate, $why) 'Yellow'
            $invalid++; continue
        }
    }

    # MUTANT: the gate must now fail
    try { Set-Mutant $m.Mut } catch {
        Emit ("  {0,-26} {1,-34} [INVALID] mutation could not be applied: {2}" -f $m.Id,$m.Gate,$_.Exception.Message) 'Yellow'; $invalid++; Reset-Mutant; continue }
    $mut = Run-Gate $m.Gate (& $m.Args)
    # KILLED if the finding COUNT rose OR any finding TEXT is new. The second clause catches a
    # mutation that makes an EXISTING finding worse -- invisible to a count comparison.
    $newLines = @($mut.Lines | Where-Object { @($base.Lines) -notcontains $_ })
    if ($mut.N -gt $base.N -or $newLines.Count -gt 0) {
        $how = if ($mut.N -gt $base.N) { "findings $($base.N) -> $($mut.N)" } else { "$($newLines.Count) NEW finding text (count unchanged at $($mut.N))" }
        Emit ("  {0,-26} {1,-34} [KILLED]  {2}" -f $m.Id,$m.Gate,$how) 'Green'
        if ($newLines.Count -gt 0) { Emit ("       $($newLines[0])") 'DarkGray' }
        Emit ("       $($mut.Detail)") 'DarkGray'
        $killed++
    } else {
        Emit ("  {0,-26} {1,-34} *** SURVIVED -- GATE IS BLIND TO THIS ***" -f $m.Id,$m.Gate) 'Red'
        Emit ("       defect: $($m.Desc)") 'DarkGray'
        Emit ("       This gate's PASS is NOT evidence for this defect class.") 'DarkGray'
        $survived++
    }
    Reset-Mutant
}

Reset-Mutant
$total = $killed + $survived
Emit "" $null
Emit "----------------------------------------------------------------" 'Cyan'
# N/A is printed in the totals ALWAYS, including when it is 0, so a reader can tell "no
# not-applicable rows" from "this build does not report them" -- print the denominator.
Emit ("  KILLED $killed / $total   SURVIVED $survived   INVALID(stale) $invalid   N/A $na_count") $(if($survived -or $invalid){'Red'}else{'Green'})
if ($survived -eq 0 -and $invalid -eq 0 -and $total -gt 0) {
    Emit "  Every gate in this suite demonstrably FAILS on its own defect class." 'Green'
    Emit "  That is what makes their PASS meaningful." 'Green'
    if ($na_count -gt 0) {
        Emit "  $na_count row(s) are N/A: this provider has no such construct, so there is nothing to" 'DarkGray'
        Emit "  mutate. NOT a gap and NOT fixable -- building the construct to satisfy a mutation is" 'DarkGray'
        Emit "  the OVER-BUILD defect class. Distinct from INVALID(stale), which IS a real problem." 'DarkGray'
    }
} else {
    Emit "  A SURVIVED row means that gate cannot see that defect -- its green light proves nothing there." 'Red'
    if ($invalid) { Emit "  An INVALID(stale) row means the mutation no longer creates its defect -- fix the MUTATION." 'Red' }
}
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
exit $(if ($survived -gt 0 -or $invalid -gt 0) { 1 } else { 0 })
