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
    $out = & powershell -ExecutionPolicy Bypass -File $t @argsList 2>&1 | Out-String
    # DETECTION = a [FAIL] *or* a [WARN] line. Counting WARN matters: several checks are
    # deliberately warn-level (verify_build CHECK 9 "flags survivors for review"), and a
    # harness that only looked for [FAIL] would libel them as blind. Learned the hard way
    # 2026-07-30 -- the first run of this harness falsely accused CHECK 9 for exactly that.
    $nFail = @([regex]::Matches($out,'\[FAIL\]')).Count
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
    return @{ N = ($nFail + $nWarn); NFail = $nFail; NWarn = $nWarn; NPass = $nPass; Vacuous = $vacuous; Detail = $first; Ok = $true }
}

# JSON mutation helper: load, mutate via scriptblock, write back
function Set-Mutant([scriptblock]$mut) {
    $j = $pristine | ConvertFrom-Json
    & $mut $j
    ($j | ConvertTo-Json -Depth 60) | Set-Content $workJson -Encoding utf8
}
function Reset-Mutant { Set-Content $workJson -Value $pristine -NoNewline -Encoding utf8 }

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
       Desc='remove RegistrationStateDH EXISTS from DALLOUT so the out-of-state DH path is no longer discriminated from DALL'
       Gate='verify_build.ps1'; Args={ @('-Path',$workJson) }
       Mut={ param($j) $c=Get-Cfg $j '*_DriverHistoryQuery'; $cm=Get-Combo $c 'DALLOUT'
             $cm.requirements.conditions=@($cm.requirements.conditions | Where-Object { "$($_.field)" -notmatch 'RegistrationStateDH' }) } }

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
     Mut={ param($j) $n=Get-Node $j 'Vehicle' 'VehicleMakeCode'
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
)

# Fold in this provider's own map. A provider with no map still runs the generic mutations, but
# report the shortfall rather than letting a thin run look like full coverage.
if ($PROV_MUTS.ContainsKey($Provider)) {
    $MUTS += @($PROV_MUTS[$Provider])
    Emit "  provider-specific mutations for ${Provider}: $(@($PROV_MUTS[$Provider]).Count)" $null
} elseif ($Provider -ne 'TX_TLETS') {
    Emit "  [NOTE] no provider-specific mutation map for $Provider -- the generic mutations below name TX keyRefs and will report INVALID here. That is honest, not a pass." 'Yellow'
}

# ── run ───────────────────────────────────────────────────────────────────────────────
$killed=0; $survived=0; $invalid=0
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

    # MUTANT: the gate must now fail
    try { Set-Mutant $m.Mut } catch {
        Emit ("  {0,-26} {1,-34} [INVALID] mutation could not be applied: {2}" -f $m.Id,$m.Gate,$_.Exception.Message) 'Yellow'; $invalid++; Reset-Mutant; continue }
    $mut = Run-Gate $m.Gate (& $m.Args)
    if ($mut.N -gt $base.N) {
        Emit ("  {0,-26} {1,-34} [KILLED]  findings {2} -> {3}" -f $m.Id,$m.Gate,$base.N,$mut.N) 'Green'
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
Emit "  KILLED $killed / $total   SURVIVED $survived   INVALID $invalid" $(if($survived -or $invalid){'Red'}else{'Green'})
if ($survived -eq 0 -and $invalid -eq 0 -and $total -gt 0) {
    Emit "  Every gate in this suite demonstrably FAILS on its own defect class." 'Green'
    Emit "  That is what makes their PASS meaningful." 'Green'
} else {
    Emit "  A SURVIVED row means that gate cannot see that defect -- its green light proves nothing there." 'Red'
}
Emit "----------------------------------------------------------------" 'Cyan'
Emit "" $null

if ($OutFile) { [System.IO.File]::WriteAllLines($OutFile, $lines, (New-Object System.Text.UTF8Encoding($false))) }
exit $(if ($survived -gt 0 -or $invalid -gt 0) { 1 } else { 0 })
