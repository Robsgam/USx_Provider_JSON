<#
  emit_test_plan.ps1 -- emit a machine-readable TEST_PLAN.json for the browser driver.

  Tiers were removed 2026-07-01 -- the plan is always the single all-or-nothing full pass:
  per entity a render marker, every combo (set[] fields resolved to DOM fieldId + a test
  value), each combo's individual any[] field tests + an all-any test, guardrail tests, and
  a negative marker. The -Tier param is accepted for back-compat but ignored.

  Mirrors generate_test_matrix.ps1's resolution (combo set[] -> form fieldId via direct match
  or the QIDM attribute sourceField; Get-TestValue for values), but emits JSON the driver eats.

  Get-TestValue's value table is shared with generate_test_matrix.ps1 via
  tools/_combo_value_resolver.ps1 (Get-ComboTestValue -Caller 'EmitTestPlan') -- extracted
  2026-07-06 after a line-by-line diff confirmed ~35 identical cases plus a handful of real,
  pre-existing behavioral differences (date format, QIF-default awareness, a few NY-specific
  fields only this tool has values for). See that module's header for the full list.
  Verified byte-identical plan output for NY_NYSPIN_EJUSTICE before/after the extraction --
  this tool's output is exactly what it was. The field-id resolution helper below
  (Resolve-FieldId) is NOT shared with generate_test_matrix's Resolve-SetToFieldIds -- that
  one differs in case-sensitivity and fallback semantics in ways that need a separate,
  dedicated look, not bundled into this pass.

  Trust warnings (non-silent): reports any combo set[]/any[] field it could NOT resolve a test
  value for (genuinely unmapped -> that combo would fire under-filled), and any entity whose
  QIDMs carry NOT_EXISTS conditions but produced zero guardrail tests. A non-zero unresolved
  count is surfaced loudly so the plan is trustworthy before a re-run.

  Default output is version-stamped (matches the root-JSON convention, so a rebuild never
  silently overwrites the prior version's plan): logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json (root of
  the logs/ folder -- the self-contained per-query evidence package)

  Usage:
    .\emit_test_plan.ps1 -Path providers\NJ_NJCJIS\NJ_NJCJIS_v4.7.json
    .\emit_test_plan.ps1 -Path <json> -OutFile <path.plan.json>
#>

param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Tier = 'Full',   # accepted for back-compat; ignored (always full pass)
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_combo_match.ps1"
. "$PSScriptRoot\_sim_helpers.ps1"
. "$PSScriptRoot\_combo_value_resolver.ps1"

# ── Firing simulation ─────────────────────────────────────────────────────────
# Mirrors run_test_matrix.ps1's Test-ComboFires model (all set[] present + conditions;
# any[] does not gate) and evaluates conditions via the SHARED _sim_helpers
# Test-ComboConditionsCore, so a guardrail's expectedKeyRef equals what the conductor
# would say it fires -- by construction. This replaces the old structural heuristic
# ("winner = first combo that lists the excluded field in set[]"), which is wrong when an
# entity has in-state/OOS combo splits sharing an identifier (e.g. HI RQ/M55L on plate,
# RQV/M55S on VIN): a bare plate fires M55L (in-state), not RQ; a bare VIN fires M55S,
# not RQV. Combo defaults (e.g. VehicleTypeCode=1) are treated as present on the form.
function Get-EntityDefaultFields($entQidms) {
    $d = @{}
    foreach ($q in $entQidms) {
        foreach ($c in $q.combinations) {
            foreach ($def in @($c.requirements.defaults)) {
                if ($def.field) { $d["$($def.field)"] = "$($def.value)" }
            }
        }
    }
    return $d
}
# Get-SimFilledRefs + the combo walk now live in _sim_helpers.ps1 as Get-FiringKeyRef --
# ONE canonical implementation, so this cannot drift from the auditors (2026-07-29).
function Get-SimFiringKeyRef($entQidms, $formData) { return Get-FiringKeyRef $entQidms $formData }

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json
$provName = (Split-Path (Split-Path (Resolve-Path $Path) -Parent) -Leaf)

$version = "unknown"
if ($json.version) { $version = $json.version }
elseif ((Split-Path $Path -Leaf) -match 'v(\d+\.\d+)') { $version = $Matches[1] }

# Per-provider test value overrides. Code-table contents are TENANT data -- the same
# category/source pair holds different codes per tenant (NJ GunMake = numeric NIBRS codes
# '03 - Armalite...', HI/CA = NCIC letter codes 'IMI', live-confirmed 2026-07-02). Overrides
# live in docs/reference/TEST_VALUE_OVERRIDES.txt as `fieldId=value` lines ('#' comments).
$ovResult = Get-ComboValueOverrides -ProviderJsonPath $Path
$script:ValueOverrides = $ovResult.Overrides
if (Test-Path $ovResult.Path) {
    Write-Host "[emit] $($script:ValueOverrides.Count) test-value override(s) loaded from $($ovResult.Path)"
}

# Tenant picklists (docs/reference/TENANT_PICKLISTS.json) loaded ONCE up front. Used both by the
# any-field toggle-value derivation below (to pick a tenant-valid alternate for a select field)
# and by the tenant-picklist gate at the end of this script. Absent for un-scoped providers.
$script:TenantPicklists = $null
$tpPathUp = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'docs\reference\TENANT_PICKLISTS.json'
if (Test-Path $tpPathUp) {
    $script:TenantPicklists = Get-Content $tpPathUp -Raw | ConvertFrom-Json
}
# Scoped dropdown options for an (entity, fieldId), or @() if not a scoped select.
function Get-ScopedOptions([string]$entity, [string]$fid) {
    if (-not $script:TenantPicklists -or -not $script:TenantPicklists.entities) { return @() }
    $entObj = $script:TenantPicklists.entities.PSObject.Properties[$entity].Value
    if (-not $entObj -or -not $entObj.fields) { return @() }
    $fldObj = $entObj.fields.PSObject.Properties[$fid].Value
    if (-not $fldObj -or $fldObj.error) { return @() }
    return @($fldObj.options)
}

# Test value per DOM fieldId (case-insensitive). Delegates to the shared resolver
# (tools/_combo_value_resolver.ps1) -- see that module's header for the documented
# behavioral differences from generate_test_matrix.ps1's copy of this same-named function.
# $script:CurEntity is set by the per-entity loop below so entity-scoped overrides
# ('<Entity>.<fieldId>=value') can resolve -- needed where one fieldId is reused across entities
# but requires a different valid value each time (NCICNumber: A/G/B-prefixed per NCIC file).
function Get-TestValue([string]$fid, [bool]$isOOS) {
    $v = Get-ComboTestValue -FieldId $fid -IsOOS $isOOS -Caller 'EmitTestPlan' -Overrides $script:ValueOverrides -Entity $script:CurEntity
    if ($null -ne $v -and "$v" -ne '') { return $v }

    # ── ALREADY-PRESENT FALLBACKS (added 2026-08-05) ────────────────────────────────────────────
    # A set[] field the resolver cannot value made this generator UNABLE TO SATISFY the combo, so
    # the fill rerouted to a looser sibling and the test was DROPPED as unrunnable -- silently
    # deleting the only proof the combo works. On AZ_AZDPS v3.6 that dropped 14 tests and removed
    # EVERY test for ACWL, DQPN and DQP, i.e. the entire driver-licence photo feature (devdoc #2/#5)
    # would have gone to the tenant, passed an ALL-PASS sweep, and never once fired. "No combo -> no
    # test -> no failure", reached through the value resolver instead of through the JSON.
    #
    # Worse than the omission: the tests it KEPT predicted the wrong combo. In the tenant these
    # fields ARE present, so a name search really fires ACWL/DQPN, while the plan predicted DQN --
    # and gate 2i replays through this same simulator, so it would have agreed with the plan and
    # both would have been wrong about the wire.
    #
    # 1. FORM initialValue (hidden ones included). If the form ships a value, the field IS present
    #    when the officer submits -- nothing to type. Same rule audit_combo_reachability already
    #    uses for always-present fields, so the two tools now agree instead of disagreeing.
    if ($script:CurFormDefaults -and $script:CurFormDefaults.Contains($fid)) {
        return "$($script:CurFormDefaults[$fid])"
    }
    foreach ($k in @($script:CurFormDefaults.Keys)) {
        if ($k -ieq $fid) { return "$($script:CurFormDefaults[$k])" }
    }

    # 2. PLATFORM-POPULATED fields -- see $script:PlatformFed below.
    foreach ($k in $script:PlatformFed.Keys) {
        if ($fid -ieq $k) { return $script:PlatformFed[$k] }
    }

    return $v
}

# PLATFORM-POPULATED fields: hidden, NO form initialValue, filled by the platform/CAD at submit time
# and never by the officer. ONE definition, consumed by BOTH Get-TestValue (above) and
# Resolve-ExpectedKeyRef (below) -- if those two disagree about what is present, the plan predicts one
# combo and the driver produces another, which is the exact class this whole fix exists to remove.
# Deliberately a SHORT EXPLICIT allowlist, NOT "anything hidden": a hidden field that is genuinely
# empty must keep failing loudly. Values match each field's metadata maxLength (BadgeNumber = 4).
#
# REVERTED TO EMPTY 2026-08-05 -- THE WIRE REFUTED IT. I had put `dexStateUserId = '1234'` here on the
# reasoning that the hidden badge is platform-populated at submit time. It is NOT. AZ_AZDPS v3.6's
# captured DQP log carries only:
#     <State>AZ</State><OperatorLicenseNumber>D999888777</OperatorLicenseNumber>
# -- no <BadgeNumber>, no <ImageIndicator>, no <Requestor>. So DQP never fired; DQ (OLN-only) did, and
# 7 of 16 Person logs FAILED because the plan named a combo the tenant cannot reach.
# CONSEQUENCE: the generator DROPPING those combos as "cannot fire for its own fill" was CORRECT, and
# I overrode a true finding with an assumption. A field is only present if something DEMONSTRABLY fills
# it -- a form initialValue (below) is evidence; "the platform probably does it" is not. If a
# platform-fed field is ever added here it needs a captured wire showing the value, not a rationale.
$script:PlatformFed = @{}

# Fields that Get-TestValue INTENTIONALLY leaves empty (not a mapping gap): in-state State
# (leave blank = home) and the auto-populated hidden Attention. Everything else returning $null is a
# genuine unmapped field -> the combo would fire under-filled. Track loud.
#
# nameMiddle/nameSuffix/nameMiddleDH/nameSuffixDH REMOVED FROM THIS ALLOWLIST 2026-08-17. They sat
# here for months, which is the THIRD and most damaging layer of the same silence: the resolver
# returned $null, THIS LINE suppressed the warning about it, and the plan then omitted the field --
# so a test named "_any", whose entire job is to fill every optional, filled a subset and reported
# PASS. Contrast firearmMake, which was NOT on this list: for that one the gate DID fire, on every
# single plan regeneration, and the warning was simply never read. Two different failures --
# a suppressed gate and an unread one -- and the suppressed one is worse, because no amount of
# attention would have surfaced it.
# THE FIELDS ARE METADATA-DEFINED: provider metadata declares Name as type="Name" with FOUR
# components (First, Last, Middle, Suffix) on every provider examined. "Optional name parts" was
# never a reason to leave them untested; it was a reason to test them as optionals.
$script:KnownEmpty = '(?i)^(registrationState|state|attention)$'
$script:Unresolved = New-Object System.Collections.Generic.List[string]
function Note-IfUnresolved([string]$ctx, [string]$fid, $val) {
    if (($null -eq $val -or $val -eq '') -and $fid -notmatch $script:KnownEmpty) {
        $script:Unresolved.Add("${ctx}: '$fid' has no test value (unmapped in Get-TestValue)")
    }
}

# Toggle-coverage tracking + derivation for any[] fields. An any-field test only proves the
# officer can change an optional field AWAY from its default if the value it fills DIFFERS from
# that field's form default (the base combo test already sends the default). When the resolved
# base value equals the default, derive a distinct valid toggle value (or flag the test hollow).
$script:ToggleStats = @{ anyField = 0; inverted = 0; hollow = 0 }
$script:CondSkips = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------------------------------------
# MUTUALLY EXCLUSIVE FORM FIELDS -- declared by the COMBO, via the EXCLUSIVE condition operator.
# The tenant form refuses some pairs of otherwise-legal optionals outright:
#   "You cannot enter a value in both of these fields {Article Type, Article Brand}"
# and the all-any[] test, which fills every optional at once, therefore produced a test that could
# never submit -- the only genuine send failure in CA_eSUN's 43-test v2.1 sweep.
#
# THE CONFIG ALREADY SAYS SO AND I MISSED IT FIRST TIME. I looked for a metadata <Choice> (none
# exists) and a devdoc note (both are listed as plain optionals), concluded the rule lived nowhere
# in our sources, and wrote a hand-maintained per-provider file. It was redundant: CA_eSUN's
# combinations carry SEVEN of these --
#     ArticleSingleQuery/ArticleSerialNumber  EXCLUSIVE [ArticleTypeCode | ArticleBrand]
#     GunQuery, DriverLicenseQuery, AFS       EXCLUSIVE [BirthDate | Age]   (x6)
# -- so the file would have covered one of seven and gone stale the first time a combo moved.
# Reading the operator needs no per-provider file and works on every provider automatically.
# THE LESSON: I searched the two AUTHORITIES and stopped. The BUILT ARTEFACT is also a place a
# constraint can be stated, and here it was the only one that had it.
# Returns a key identifying the combo's EXCLUSIVE group this field belongs to, or $null.
# The condition names SOURCE fields (attribute names); the caller may hold either the attribute
# name or the resolved fieldId, so both are accepted -- the same reason audit_optional_scope
# narrows on (query, keyRef, primaryFieldReference) rather than trusting one spelling.
function Get-ExclusiveGroupFor($combo, $attrName, $fieldId) {
    # REFUSE A NULL COMBO rather than reporting "no groups". Passing the wrong variable here
    # returned $null silently and the plan regenerated looking perfectly clean with zero
    # exclusions applied -- the success-shaped failure this repo keeps rediscovering.
    if ($null -eq $combo) { throw "Get-ExclusiveGroupFor: null combination passed (wrong variable in scope?)" }
    foreach ($cd in @($combo.requirements.conditions)) {
        if (-not $cd) { continue }
        if ("$($cd.operator)".ToUpperInvariant() -ne 'EXCLUSIVE') { continue }
        $members = @($cd.field | ForEach-Object { "$_" })
        if ($members.Count -lt 2) { continue }
        if (($members -contains "$attrName") -or ($members -contains "$fieldId")) { return ($members -join '|') }
    }
    return $null
}

# ---------------------------------------------------------------------------------------------
# A COMBO'S OWN IN / NOT_IN LIST CONSTRAINS WHAT AN any[] TOGGLE MAY FILL.
#
# Rob 2026-09-02: "fix the plan generator first". CA_eSUN v2.1 T10 filled the VPNameBirthDateIn
# combo (which submits fine) plus RegistrationState=GA, and Send never enabled. The combo carries
#     { field:[RegistrationState], operator:IN, value:["CA","null","59872938171"] }
# an IN-STATE whitelist, so GA makes it match nothing and NO query arms. The test could not run by
# construction, and it burned three live runs looking like a build defect. Same for T23 on Person.
#
# WHY THE EXISTING "unrunnable" DROP DID NOT CATCH IT -- and this is the important part.
# That drop asks Resolve-ExpectedKeyRef which combo fires, which routes through _sim_helpers, whose
# documented model (QIDM_REFERENCE Sec 2a) is that a conditions array containing ANY value-comparison
# operator (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) is POISONED and disabled IN ITS ENTIRETY. Under that
# model these conditions are inert, the combo still "fires" with GA, and the test looks runnable.
# THE LIVE TENANT DISAGREES: with State blank T9 submits, with State=GA T10 does not, five runs
# running. That is direct evidence the conditions are evaluated -- but the poisoned-array rule is
# recorded from real experience on other providers, so this function deliberately does NOT change
# _sim_helpers or the firing model. It only refuses to GENERATE a fill that the combo's own declared
# value list rejects, which is correct under BOTH models: if conditions are inert the substituted
# value routes identically, and if they are live the test can now actually run.
#
# Substitute rather than skip wherever possible -- a skipped any[] field loses toggle coverage.
# Sentinels ('null', ''), and values that look like leaked ids rather than field values, are never
# substituted in: CA_eSUN's list literally contains "59872938171" beside "CA".
function Test-AnyValueAgainstConditions($combo, $attrName, $fieldId, $value, [ref]$skipLog, $ctx) {
    if ($null -eq $value -or "$value" -eq '') { return $value }
    $conds = @($combo.requirements.conditions | Where-Object { $_ })
    if ($conds.Count -eq 0) { return $value }
    foreach ($cond in $conds) {
        $op = "$($cond.operator)".ToUpperInvariant()
        if ($op -ne 'IN' -and $op -ne 'NOT_IN') { continue }
        # Conditions name the SOURCE field; the toggle may be keyed by attribute name or fieldId.
        $cf = @($cond.field) | ForEach-Object { "$_" }
        if (($cf -notcontains "$attrName") -and ($cf -notcontains "$fieldId")) { continue }
        $listed = @($cond.value | ForEach-Object { "$_" })
        $usable = @($listed | Where-Object { $_ -and $_ -ne 'null' -and $_ -notmatch '^\d{6,}$' })
        if ($op -eq 'IN') {
            if ($listed -contains "$value") { return $value }              # already legal
            if ($usable.Count -gt 0) { return $usable[0] }                 # substitute a legal one
            [void]$skipLog.Value.Add("$ctx any[$fieldId] -- combo requires $fieldId IN [$($listed -join ',')] and no usable value is listed; toggle test SKIPPED")
            return $null
        } else {
            if ($listed -notcontains "$value") { return $value }           # already legal
            [void]$skipLog.Value.Add("$ctx any[$fieldId] -- '$value' is excluded by NOT_IN [$($listed -join ',')]; toggle test SKIPPED")
            return $null
        }
    }
    return $value
}
function Get-AnyFillValue([string]$ent, [string]$ff, [bool]$isOOS, $formDefaults, [bool]$CountStats = $true) {
    $val = Get-TestValue $ff $isOOS
    $default = $null
    if ($formDefaults -and $formDefaults.Contains($ff)) { $default = "$($formDefaults[$ff])" }
    if ($default -and "$val" -eq "$default") {
        $opts = Get-ScopedOptions $ent $ff
        $toggle = Get-ComboToggleValue -FieldId $ff -Default $default -PicklistOptions $opts -IsOOS $isOOS -Overrides $script:ValueOverrides
        if ($toggle -and "$toggle" -ne "$default") {
            if ($CountStats) { $script:ToggleStats.inverted++ }
            return "$toggle"
        }
        if ($CountStats) {
            $script:ToggleStats.hollow++
            $script:Unresolved.Add("${ent} any[]: '$ff' toggle value '$val' == form default '$default' -- hollow toggle test (add '$ff.toggle=<value>' to TEST_VALUE_OVERRIDES.txt)")
        }
    }
    return $val
}

# Field DOM ids present in an entity's QIF (Craft.js flat layout -> props.fieldId).
function Get-QifFieldIds($qif) {
    $ids = @()
    if ($qif -and $qif.layout -and $qif.layout.default) {
        foreach ($p in $qif.layout.default.PSObject.Properties) {
            if ($p.Value.props -and $p.Value.props.fieldId) { $ids += $p.Value.props.fieldId }
        }
    }
    return $ids
}

# Hidden field ids (hidden gate-feeders, e.g. automated Attention). The driver cannot type
# into a hidden input, so the plan must never emit a fill for one -- it submits under-filled
# (CA NLTS.KQ.O_af_Attention, 2026-07-02). Their coverage rides along on every query via the
# initialValue + handler; there is nothing for the driver to exercise.
function Get-QifHiddenFieldIds($qif) {
    $ids = @()
    if ($qif -and $qif.layout -and $qif.layout.default) {
        foreach ($p in $qif.layout.default.PSObject.Properties) {
            if ($p.Value.props -and $p.Value.props.fieldId -and $p.Value.hidden -eq $true) { $ids += $p.Value.props.fieldId }
        }
    }
    return $ids
}

# QIF initialValues per fieldId (visible + hidden). Emitted into the plan as formDefaults so
# content matching (relabel_batch / audit_log_content) knows which extra snapshot fields are
# form defaults rather than another test's optionals (NJ Person ImageIndicator=Y, 2026-07-02).
function Get-QifFormDefaults($qif) {
    $d = [ordered]@{}
    if ($qif -and $qif.layout -and $qif.layout.default) {
        foreach ($p in $qif.layout.default.PSObject.Properties) {
            if ($p.Value.props -and $p.Value.props.fieldId -and $null -ne $p.Value.props.initialValue -and "$($p.Value.props.initialValue)" -ne '') {
                $d[$p.Value.props.fieldId] = "$($p.Value.props.initialValue)"
            }
        }
    }
    return $d
}

# Resolve a combo attribute name -> DOM fieldId (direct match, else QIDM attribute sourceField).
function Resolve-FieldId([string]$name, $qidm, $fieldIds) {
    $direct = $fieldIds | Where-Object { $_ -ieq $name } | Select-Object -First 1
    if ($direct) { return $direct }
    foreach ($attr in $qidm.attributes) {
        if ($attr.name -ieq $name) {
            foreach ($s in @($attr.sourceField)) {
                $m = $fieldIds | Where-Object { $_ -ieq $s } | Select-Object -First 1
                if ($m) { return $m }
            }
            $sfs = @($attr.sourceField); if ($sfs.Count) { return $sfs[0] }
        }
    }
    return $name
}

function Build-Fills($names, $qidm, $fieldIds, $isOOS, $hiddenIds = @()) {
    $fills = @()
    foreach ($n in @($names)) {
        $fid = Resolve-FieldId $n $qidm $fieldIds
        if (@($hiddenIds) -icontains $fid) { continue }   # hidden gate-feeder: driver can't type into it
        $val = Get-TestValue $fid $isOOS
        if ($null -ne $val -and $val -ne '') { $fills += [ordered]@{ fieldId = $fid; value = "$val" } }
    }
    return $fills
}

# Find combos with NOT_EXISTS conditions and return guardrail descriptors.
# Uses the emit-script QIDM model ($q.combinations, $q.attributes -- no .config wrapper).
function Get-GuardrailTests($EntQidms, $FieldIds) {
    $seen = @{}; $results = @()
    foreach ($q in $EntQidms) {
        foreach ($c in $q.combinations) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $notExists = @($c.requirements.conditions | Where-Object { $_.operator -eq 'NOT_EXISTS' })
            foreach ($ne in $notExists) {
                $excludedFid = @($ne.field)[0]
                if (-not $excludedFid) { continue }
                $key = "${kr}|${excludedFid}"
                if ($seen[$key]) { continue }
                $seen[$key] = $true
                $winner = $null; $winnerQ = $null; $winnerKr = $null
                foreach ($q2 in $EntQidms) {
                    foreach ($c2 in $q2.combinations) {
                        $kr2 = if ($c2.keyReference) { $c2.keyReference } else { $c2.keyRef }
                        if ($kr2 -eq $kr) { continue }
                        if ($c2.requirements.set | Where-Object { $_ -ieq $excludedFid }) {
                            $winner = $c2; $winnerQ = $q2; $winnerKr = $kr2; break
                        }
                    }
                    if ($winner) { break }
                }
                if (-not $winner) { continue }
                $results += [PSCustomObject]@{
                    loserQidm   = $q
                    loserCombo  = $c
                    loserKr     = $kr
                    winnerQidm  = $winnerQ
                    winnerKr    = $winnerKr
                    excludedFid = $excludedFid
                }
            }
        }
    }
    return $results
}

# ── Collect QIDMs + QIFs, group by entity ─────────────────────────────────────
$qidms = Get-CommSysQidms $json
$qifs  = @($json.bundles.configurations | Where-Object { $_.type -eq 'QUERYINPUTFORM' })
$qifByEntity = @{}
foreach ($qif in $qifs) { if ($qif.targetEntity) { $qifByEntity[$qif.targetEntity] = $qif } }

$entityOrder = @('Vehicle','Person','Firearm','Article','Boat')
$entities = @($qidms | ForEach-Object { $_.targetEntity } | Select-Object -Unique)
$entities = @($entityOrder | Where-Object { $entities -contains $_ }) + @($entities | Where-Object { $entityOrder -notcontains $_ })

$tests = New-Object System.Collections.Generic.List[object]
$formDefaultsByEntity = [ordered]@{}
$n = 0

# Two tests with the SAME fill set are the SAME SUBMISSION -- the officer types identical input and
# the platform can only do one thing with it, so they can never be told apart in evidence and the
# second can never receive its own log. Emitting both creates a permanently-unsatisfiable "owed
# test" and, worse, lets a capture be content-matched to whichever label sorts first.
# PROVEN 2026-07-29 on an FL_FCIC Boat run: n=76 (Hull+decal) had byte-identical fills to n=71
# (Hull+decal); the capture landed under n=71's label and n=76 read as owed forever. Five of FL's
# seven "missing" Boat tests were this, plus both of CA_CLETS's. Deduped here so plan coverage is
# a measurable number instead of an unreachable target.
# Keeps the FIRST occurrence in plan order and records what was folded into it -- never a silent drop.
function Get-FillKey($fills) {
    return ((@($fills) | Where-Object { $_ -and $_.fieldId } |
             ForEach-Object { "$($_.fieldId)=$($_.value)" } | Sort-Object) -join '|')
}

# Resolve expectedKeyRef by SIMULATION for the structural kinds too (combo / any-field /
# any) -- guardrails already did this (see Get-SimFiringKeyRef below). A test's own fill can
# REROUTE it: adding a higher-priority identifier as an any[] field makes an earlier combo
# win first-match, so the plan asserted a combo the query never reaches, the captured log
# was filed under it, and nothing caught the lie because the wire XML carries no keyRef.
# That produced 9 misattributed logs -- FL_FCIC Boat FBQ Decal/Registration/TitleLien (x7,
# rerouted to FBQBoatHullIdNumber / FBQDecalNumber) and CA_CLETS IR.QVC.S (x2, rerouted to
# IR.QVC.C). Found 2026-07-29 by audit_log_combo_attribution.ps1; see BUILD_RULES Sec 20d.
# When the fill reroutes, expectedKeyRef becomes the combo that ACTUALLY fires and
# reroutedFrom records the combo the test cannot reach -- so the plan never asserts a
# falsehood and the condition is visible BEFORE anyone spends a tenant test on it.
function Resolve-ExpectedKeyRef($entQidms, $fills, $entDefaults, $structuralKr) {
    $fd = @{}
    foreach ($f in @($fills)) { if ($f -and $f.fieldId) { $fd[$f.fieldId] = $f.value } }
    if ($entDefaults) {
        foreach ($k in $entDefaults.Keys) { if (-not $fd.ContainsKey($k)) { $fd[$k] = $entDefaults[$k] } }
    }
    # PLATFORM-FED fields must be modelled PRESENT here even though they are absent from $fills
    # (Build-Fills skips hidden fields -- the driver cannot type into them, correctly). Without this
    # the simulation thinks the badge is missing, so a badge-gated combo cannot win, the test is
    # dropped as "cannot fire for its own fill", and the plan predicts the looser sibling that the
    # TENANT will not actually fire. On AZ_AZDPS v3.6 that removed every test for ACWL/DQPN/DQP --
    # the whole driver-licence photo feature -- and mispredicted the name searches it kept.
    foreach ($k in $script:PlatformFed.Keys) { if (-not $fd.ContainsKey($k)) { $fd[$k] = $script:PlatformFed[$k] } }
    $sim = Get-SimFiringKeyRef $entQidms $fd
    if ($sim) { return $sim }
    return $structuralKr
}

foreach ($ent in $entities) {
    $script:CurEntity = $ent   # for entity-scoped test-value overrides
    $fieldIds = Get-QifFieldIds $qifByEntity[$ent]
    $hiddenIds = @(Get-QifHiddenFieldIds $qifByEntity[$ent])
    $formDefaultsByEntity[$ent] = Get-QifFormDefaults $qifByEntity[$ent]
    # Exposed to Get-TestValue so a form-shipped value counts as ALREADY-PRESENT rather than as an
    # unresolved field that reroutes the fill and gets the test dropped (see Get-TestValue).
    $script:CurFormDefaults = $formDefaultsByEntity[$ent]
    $entQidms = @($qidms | Where-Object { $_.targetEntity -eq $ent })

    # render/negative are manual one-time checks done at initial provider build, not part
    # of the recurring per-rebuild test matrix (2026-07-01 user directive) -- omitted here.

    foreach ($q in $entQidms) {
        foreach ($c in $q.combinations) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            # Filter nulls: @($null) is a 1-element array in PowerShell, not empty -- a combo
            # with no 'any' key (a valid minimal combo, e.g. CCH AR) must not inject a phantom
            # null entry that later crashes Get-ComboTestValue's mandatory -FieldId parameter.
            $setNames = @($c.requirements.set | Where-Object { $_ })
            $isOOS = [bool]($setNames | Where-Object { $_ -match '(?i)^(registrationState|state)$' })
            $fills = Build-Fills $setNames $q $fieldIds $isOOS $hiddenIds
            # Trust: flag any set[] field we couldn't resolve a value for (under-fill risk).
            foreach ($sn in $setNames) { Note-IfUnresolved "$ent $kr set[]" (Resolve-FieldId $sn $q $fieldIds) (Get-TestValue (Resolve-FieldId $sn $q $fieldIds) $isOOS) }
            $n++
            $expKr = Resolve-ExpectedKeyRef $entQidms $fills $formDefaultsByEntity[$ent] $kr
            $t0 = [ordered]@{
                n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                expectedKeyRef = $expKr; kind = 'combo'; tier = 'Full'; fills = $fills
            }
            if ($expKr -ne $kr) { $t0.reroutedFrom = $kr }
            $tests.Add($t0)
            # individual any[] field tests + all-together (full pass)
            $anyNames = @($c.requirements.any | Where-Object { $_ })
            if ($anyNames.Count -gt 0) {
                $entFormDefaults = $formDefaultsByEntity[$ent]
                # One test per individual any[] field. Value must DIFFER from the field's form
                # default (else the toggle proves nothing -- base combo already sends the default).
                foreach ($af in $anyNames) {
                    $ff  = Resolve-FieldId $af $q $fieldIds
                    if (@($hiddenIds) -icontains $ff) { continue }   # hidden gate-feeder (e.g. automated Attention): nothing to type
                    # NO CONTROL ON THE FORM -> NOTHING TO TYPE. Not every sourceField is a box.
                    # CA_eSUN's Article QIDM feeds TWO attributes from one picker: ArticleCategory
                    # from the ArticleTypeCode control, and ArticleTypeCode from a sourceField named
                    # ArticleTypeCodeRemainder that has no control and appears ZERO times in the
                    # metadata. It is DERIVED, not entered -- the platform splits the NCIC code, and
                    # the wire proves it: picking "BBICYCL - Bicycle" in the single box sends
                    # ArticleCategory=B and ArticleTypeCode=BICYCL. So the field is working exactly
                    # as designed, and the only thing broken was the plan trying to type into it,
                    # which produced 'field "ArticleTypeCodeRemainder" did not fill' on every run
                    # and left 2 tests permanently unloggable.
                    # I FIRST CALLED THIS A MISSING CONTROL NEEDING A v3 FORM CHANGE. It is not --
                    # reading the wire refuted that in one command, and audit_wiring_closure's
                    # matching "UNFILLABLE REQ" finding is a false positive for the same reason:
                    # that gate cannot tell a derived sourceField from an unbuilt one.
                    if (@($fieldIds) -notcontains $ff) {
                        [void]$script:CondSkips.Add("$ent $kr any[$ff] -- no control on the $ent form; treated as platform-DERIVED, not typed")
                        continue
                    }
                    $val = Get-AnyFillValue $ent $ff $isOOS $entFormDefaults
                    Note-IfUnresolved "$ent $kr any[]" $ff $val
                    # HONOUR THE COMBO'S OWN VALUE LIST. See Test-AnyValueAgainstConditions.
                    $val = Test-AnyValueAgainstConditions $c $af $ff $val ([ref]$script:CondSkips) "$ent $kr"
                    if ($null -ne $val -and $val -ne '') {
                        $script:ToggleStats.anyField++
                        $n++
                        $afFills = @(@($fills)) + @([ordered]@{ fieldId = $ff; value = "$val" })
                        $afKr = Resolve-ExpectedKeyRef $entQidms $afFills $entFormDefaults $kr
                        $tAf = [ordered]@{
                            n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                            expectedKeyRef = $afKr; kind = 'any-field'; tier = 'Full'
                            anyField = $ff
                            fills = $afFills
                        }
                        if ($afKr -ne $kr) { $tAf.reroutedFrom = $kr }
                        $tests.Add($tAf)
                    }
                }
                # All any[] fields together. Reuse the same toggle-aware derivation so the combined
                # test also carries non-default optionals (CountStats=$false -- the per-field loop
                # above already counted/flagged each field, don't double-count here).
                $anyFills = @(@($fills))
                $usedExclusiveGroups = @{}
                foreach ($af in $anyNames) {
                    $ff = Resolve-FieldId $af $q $fieldIds
                    if (@($hiddenIds) -icontains $ff) { continue }
                    # Same derived-field guard as the per-field loop above; without it here the
                    # all-any test still types into the phantom control and still fails.
                    if (@($fieldIds) -notcontains $ff) { continue }
                    # MUTUALLY EXCLUSIVE FIELDS -- fill only the FIRST member of a declared group.
                    # The tenant form refuses some pairs outright ("You cannot enter a value in both
                    # of these fields {Article Type, Article Brand}"), and that constraint is in
                    # NEITHER authority: no <Choice> in the metadata, plain optionals in the devdoc.
                    # So the all-any test happily filled both and produced the only genuine send
                    # failure in CA_eSUN's 43-test v2.1 sweep. Per-field toggle tests are unaffected
                    # -- each field alone is legal, and those are what prove the field works.
                    # THE COMBO ITSELF DECLARES THIS -- read it, do not re-state it elsewhere.
                    # My first version loaded these from a hand-written
                    # docs/reference/<P>_EXCLUSIVE_FIELDS.txt. That file was REDUNDANT: this
                    # provider's own combinations carry
                    #     { field: [ArticleTypeCode, ArticleBrand], operator: 'EXCLUSIVE' }
                    # and six more of the same shape (BirthDate|Age on GunQuery, DriverLicenseQuery
                    # and AFS). A hand-maintained copy would have covered ONE of the seven and gone
                    # stale the first time a combo changed. Reading the operator instead works on
                    # every provider with no per-provider file to write or remember.
                    # $c is the COMBINATION in this scope (see `foreach ($c in $q.combinations)`).
                    # My first attempt passed $cb, which is not defined here -- and the lookup then
                    # returned $null SILENTLY, so the plan regenerated with no exclusions applied
                    # and every sign of having worked. A wrong variable that throws is a nuisance;
                    # one that returns "nothing found" is a false clean run, which is why the
                    # function now refuses a null combo instead of treating it as "no groups".
                    $grp = Get-ExclusiveGroupFor $c $af $ff
                    if ($grp) {
                        if ($usedExclusiveGroups.ContainsKey($grp)) {
                            [void]$script:CondSkips.Add("$ent $kr (all-any) -- '$ff' omitted: the combo declares it EXCLUSIVE with '$($usedExclusiveGroups[$grp])'")
                            continue
                        }
                        $usedExclusiveGroups[$grp] = $ff
                    }
                    $v = Get-AnyFillValue $ent $ff $true $entFormDefaults $false
                    # SAME CONSTRAINT AS THE PER-FIELD LOOP ABOVE -- and this is the branch that
                    # actually produced CA_eSUN's T10/T23. Note the hardcoded $true above: the
                    # all-together test always asks for the OUT-OF-STATE value, so on an IN-STATE
                    # combo it reliably picks a State the combo's own IN list rejects. Applying the
                    # guard in only one of the two branches is why my first pass changed nothing.
                    $v = Test-AnyValueAgainstConditions $c $af $ff $v ([ref]$script:CondSkips) "$ent $kr (all-any)"
                    if ($null -ne $v -and $v -ne '') { $anyFills += [ordered]@{ fieldId = $ff; value = "$v" } }
                }
                if (@($anyFills).Count -gt @($fills).Count) {
                    $n++
                    $anyKr = Resolve-ExpectedKeyRef $entQidms $anyFills $entFormDefaults $kr
                    $tAny = [ordered]@{
                        n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                        expectedKeyRef = $anyKr; kind = 'any'; tier = 'Full'; fills = $anyFills
                    }
                    if ($anyKr -ne $kr) { $tAny.reroutedFrom = $kr }
                    $tests.Add($tAny)
                }
            }
        }
    }

    # Guardrail tests -- after all combos, before negative. Trust: if this entity's QIDMs
    # carry NOT_EXISTS conditions but no guardrail test resolved, flag it (silent-gap guard).
    $entGuardrails = @(Get-GuardrailTests $entQidms $fieldIds)
    $notExistsCount = 0
    foreach ($q in $entQidms) { foreach ($c in $q.combinations) { $notExistsCount += @($c.requirements.conditions | Where-Object { $_.operator -eq 'NOT_EXISTS' }).Count } }
    if ($notExistsCount -gt 0 -and $entGuardrails.Count -eq 0) {
        $script:Unresolved.Add("${ent}: $notExistsCount NOT_EXISTS condition(s) but 0 guardrail tests emitted (winner combo unresolved)")
    }
    if ($true) {
        $entDefaults = Get-EntityDefaultFields $entQidms
        $gCandidates = New-Object System.Collections.Generic.List[object]
        foreach ($gr in $entGuardrails) {
            $exFf  = $fieldIds | Where-Object { $_ -ieq $gr.excludedFid } | Select-Object -First 1
            if (-not $exFf) { $exFf = $gr.excludedFid }
            $exVal = Get-TestValue $exFf $false
            # Skip guardrails whose competing discriminator can't be filled (e.g. in-state State,
            # which Get-TestValue intentionally leaves blank). Without a fillable discriminator the
            # identifier conflict can't be constructed -- that NOT_EXISTS is in-state/OOS routing,
            # not identifier priority, and is already covered by the combo tests. (Prevents the
            # stale "bare VIN expects OOS RQV" class -- the discriminator there is State.)
            if ($null -eq $exVal -or $exVal -eq '') { continue }
            $gFills = @()
            $gFills += [ordered]@{ fieldId = $exFf; value = "$exVal" }
            foreach ($sf in @($gr.loserCombo.requirements.set | Where-Object { $_ })) {
                $ff  = Resolve-FieldId $sf $gr.loserQidm $fieldIds
                if (@($hiddenIds) -icontains $ff) { continue }   # hidden gate-feeder: driver can't type into it
                $val = Get-TestValue $ff $false
                if ($null -ne $val -and $val -ne '') { $gFills += [ordered]@{ fieldId = $ff; value = "$val" } }
            }
            # expectedKeyRef = what ACTUALLY fires for this fill (simulated), not the structural
            # winner heuristic (which mis-picks the OOS combo when an in-state sibling shares the
            # identifier). Combo defaults count as present on the form.
            # USE THE SHARED RESOLVER, not a private copy of the union (fixed 2026-08-05). This block
            # built its own $fd inline while the structural path went through Resolve-ExpectedKeyRef,
            # so the two could -- and did -- disagree: AZ_AZDPS v3.7 plan test n=36 expected 'DQ' while
            # the canonical walk fired 'DQP', which audit_simulator_parity caught as
            # "1 of 1249 plan test(s) disagree". Two code paths answering "which combo fires" is the
            # same class as one rule living in two tools: fixing one is not fixing it. Anything that
            # answers that question must call the one function (ENGINEERING_STANDARD 4.4 -- never
            # re-implement an existing parser).
            # $formDefaultsByEntity[$ent], NOT $entDefaults -- A NAMESPACE MISMATCH, fixed 2026-08-05.
            # Get-EntityDefaultFields returns COMBO defaults keyed by ATTRIBUTE name (BadgeNumber, State,
            # ImageIndicator); Get-FiringKeyRef matches FORM fieldIds (dexStateUserId, RegistrationState,
            # Requestor). So 'BadgeNumber=X' never registered the badge as present and this union was a
            # silent NO-OP, while the three structural call sites above correctly pass the form defaults.
            # Result: plan test n=36 expected 'DQ' where the canonical walk fires 'DQP', caught by
            # audit_simulator_parity as "1 of 1249 plan test(s) disagree". Proven by calling
            # Get-FiringKeyRef directly on the same fill: fills-only -> DQ, fills+FORM defaults -> DQP.
            # I first assumed a SECOND firing implementation; there is none -- Get-SimFiringKeyRef already
            # delegates to Get-FiringKeyRef. Same walk, wrong input. usx-tooling Step 3: a lookup table
            # must live in the same namespace as the comparison.
            $simKr = Resolve-ExpectedKeyRef $entQidms $gFills $formDefaultsByEntity[$ent] $null
            if (-not $simKr) { continue }   # nothing fires for this fill -> not a valid guardrail
            $gCandidates.Add([PSCustomObject]@{ query = $gr.loserQidm.query; simKr = $simKr; fills = $gFills; loserKr = $gr.loserKr })
        }
        # Disambiguate guardrail log filenames ONLY when >1 loser combo resolves to the SAME
        # winner (e.g. FL_FCIC Boat: relatedHitSearchIndicator routes Hull between the FBQ and
        # QB combo families -- both "Hull wins" scenarios simulate to the same expectedKeyRef and
        # silently overwrote one another's log before this existed, 2026-07-02). Leaving
        # guardrailLoser unset for non-colliding winners keeps existing filenames stable across
        # providers that don't hit this (Get-CmPlanLabel falls back to the undisambiguated name).
        # ---- DROP GUARDRAILS THAT PROVE NOTHING (added 2026-08-18) ----------------------------
        # A guardrail is defined by WHAT IS FILLED and WHAT FIRES -- not by which loser keyRef
        # inspired it. Two failures were shipping as coverage until audit_log_inflation's clone
        # check was repaired (it had never been able to fail, because every wire carries a unique
        # transaction id, so no two logs ever hashed alike):
        #   1. DUPLICATE guardrails. Two losers whose set[] fields are THE SAME produce an
        #      identical fill-set. TX_TLETS Boat: BQRegistrationNumber and QBRegistrationNumber
        #      both contribute only 'RegistrationNumber', so n97 and n98 were byte-identical tests
        #      with different filenames. The $winnerCounts disambiguation below renames the FILES,
        #      which hid the duplication instead of removing it.
        #   2. VACUOUS guardrails. If the fill-set matches a plain combo test already emitted for
        #      this entity, no identifier competition is staged at all -- the "guardrail" just
        #      re-runs that combo. TX_TLETS Vehicle: the VIN guardrail's fills equalled the
        #      VINVehicleIdentificationNumber combo test's fills.
        # Both are coverage inflation: a test that proves one thing twice, or nothing.
        # NOT SILENT -- every drop is reported, because a cap nobody sees reads as "covered".
        $seenGuardSig = @{}
        $comboSigs    = @{}
        foreach ($t in $tests) {
            if ("$($t.entity)" -ne $ent) { continue }
            $sig = (@($t.fills | ForEach-Object { "$($_.fieldId)=$($_.value)" }) | Sort-Object) -join '|'
            if ($sig) { $comboSigs[$sig] = "$($t.comboKeyRef)$(if($t.anyField){"_af_$($t.anyField)"})" }
        }
        $kept = New-Object System.Collections.Generic.List[object]
        foreach ($g in $gCandidates) {
            $sig = (@($g.fills | ForEach-Object { "$($_.fieldId)=$($_.value)" }) | Sort-Object) -join '|'
            if ($seenGuardSig.ContainsKey($sig)) {
                Write-Host "  [PLAN] $ent guardrail vs $($g.loserKr) DROPPED -- identical fill-set to the guardrail vs $($seenGuardSig[$sig]) (both losers contribute the same set[] fields, so it is the same test twice)" -ForegroundColor DarkYellow
                continue
            }
            if ($comboSigs.ContainsKey($sig)) {
                Write-Host "  [PLAN] $ent guardrail vs $($g.loserKr) DROPPED -- fill-set is identical to combo test '$($comboSigs[$sig])', so no identifier competition is staged" -ForegroundColor DarkYellow
                continue
            }
            $seenGuardSig[$sig] = $g.loserKr
            $kept.Add($g) | Out-Null
        }
        $gCandidates = $kept

        $winnerCounts = @{}
        foreach ($g in $gCandidates) { $winnerCounts[$g.simKr] = @($winnerCounts[$g.simKr]) + 1 }
        foreach ($g in $gCandidates) {
            $n++
            $test = [ordered]@{
                n = $n; entity = $ent; query = $g.query
                comboKeyRef = $null; expectedKeyRef = $g.simKr
                kind = 'guardrail'; tier = 'Full'; fills = $g.fills
            }
            if (@($winnerCounts[$g.simKr]).Count -gt 1) { $test.guardrailLoser = $g.loserKr }
            $tests.Add($test)
        }
    }

    # VALUE-STRIP tests. An attribute using IgnoreUserValueRuleHandler strips a SPECIFIC VALUE
    # from the outbound wire (e.g. CAD auto-fills the officer's home state) WITHOUT changing which
    # combo fires -- routing reads raw FORM state, the handler only transforms the OUTBOUND value
    # (UNIVERSAL_SEARCH_HANDLERS.txt Sec 4). No ordinary combo/any test ever fills the SPECIFIC
    # ignored value, so this defect class (DEX-1284, NY_NYSPIN_EJUSTICE v4.22-4.23) would otherwise
    # only ever be exercised by a one-off manual test outside the plan -- which the import pipeline
    # correctly drops as "matched no plan test" and which never becomes a committed log. Built in
    # 2026-08-06 so it survives every future rebuild automatically. Zero effect on any provider that
    # does not use this rule (only NY_NYSPIN_EJUSTICE's Vehicle State attribute does, as of writing).
    foreach ($q in $entQidms) {
        foreach ($attr in @($q.attributes | Where-Object { $_.rule -and $_.rule.function -eq 'IgnoreUserValueRuleHandler' })) {
            $srcNames = @($attr.sourceField | Where-Object { $_ })
            if (-not $srcNames.Count) { continue }
            $stripFid = $fieldIds | Where-Object { $_ -ieq $srcNames[0] } | Select-Object -First 1
            if (-not $stripFid) { $stripFid = $srcNames[0] }
            if (@($hiddenIds) -icontains $stripFid) { continue }   # can't type into a hidden field
            foreach ($ignoreVal in @($attr.rule.arguments | Where-Object { $_ })) {
                # One strip test per combo whose set[] actually REQUIRES this field (not any[] --
                # an optional field doesn't gate existence-based routing the way a set[] member
                # does, so it isn't part of the routing mechanics this test class exercises).
                # Every such combo, not just the first: the field is shared across all of them
                # (one QIDM attribute), and each is an independently reachable, independently
                # affected wire path (e.g. NY's RVIN [VIN+State] and RVEHOUT [plate+State] both
                # require RegistrationState and both route through the same handler).
                foreach ($q2 in $entQidms) {
                    foreach ($c2 in $q2.combinations) {
                        $origSetNames = @($c2.requirements.set | Where-Object { $_ })
                        if (-not ($origSetNames | Where-Object { $_ -ieq $srcNames[0] })) { continue }
                        $ownerKr = if ($c2.keyReference) { $c2.keyReference } else { $c2.keyRef }
                        $isOOS2 = [bool]($origSetNames | Where-Object { $_ -match '(?i)^(registrationState|state)$' })
                        $setNames2 = @($origSetNames | Where-Object { $_ -ine $srcNames[0] })
                        $vsFills = @(Build-Fills $setNames2 $q2 $fieldIds $isOOS2 $hiddenIds)
                        $vsFills += [ordered]@{ fieldId = $stripFid; value = "$ignoreVal" }
                        $n++
                        $vsKr = Resolve-ExpectedKeyRef $entQidms $vsFills $formDefaultsByEntity[$ent] $ownerKr
                        $tVs = [ordered]@{
                            n = $n; entity = $ent; query = $q2.query; comboKeyRef = $ownerKr
                            expectedKeyRef = $vsKr; kind = 'value-strip'; tier = 'Full'
                            strippedField = $stripFid; strippedValue = "$ignoreVal"
                            fills = $vsFills
                        }
                        if ($vsKr -ne $ownerKr) { $tVs.reroutedFrom = $ownerKr }
                        $tests.Add($tVs)
                    }
                }
            }
        }
    }
}

# ── DROP TESTS WHOSE NOMINAL COMBO CANNOT FIRE ───────────────────────────────────
# A test where expectedKeyRef != comboKeyRef is REROUTED: its own fill makes an earlier combo win
# first-match, so the combo it is named for never runs. Such a test must not be emitted at all:
#   - the driver submits it, the import names the log from comboKeyRef, and the result is a log
#     asserting a combo that did not fire -- audit_log_combo_attribution then FAILS it, correctly.
#     (FL_FCIC produced exactly 6 such logs on the 2026-07-29 Boat run.)
#   - the combo that DOES fire already has its own test with the same or narrower fill, so no
#     coverage is lost by dropping this one.
#   - and it can never be satisfied: 5 of FL's 7 "owed" tests had byte-identical fills to tests
#     that already had logs (n=76 Hull+decal == n=71 Hull+decal), so no separate evidence exists.
# Renaming them was tried first (2026-07-29) and was worse -- the import does not use this repo's
# label function, so a renamed test could never receive a log and simply read as owed forever.
# Dropping is the honest fix: the reroute is still visible in the reroutedFrom/expectedKeyRef of
# the LOG-BEARING sibling and in audit_combo_reachability's dead-combo report.
$kept    = New-Object System.Collections.Generic.List[object]
$dropped = New-Object System.Collections.Generic.List[string]
foreach ($t in $tests) {
    if ($t.reroutedFrom) {
        $dropped.Add("$($t.comboKeyRef)$(if($t.anyField){"/$($t.anyField)"}) [$($t.kind)] -- its fill fires $($t.expectedKeyRef) instead, so this combo never runs")
        continue
    }
    $kept.Add($t)
}
if ($dropped.Count -gt 0) {
    Write-Host "  [plan] dropped $($dropped.Count) unrunnable test(s) (nominal combo cannot fire for its own fill):" -ForegroundColor DarkYellow
    $dropped | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkGray }
    $i = 0
    foreach ($t in $kept) { $i++; $t.n = $i }
    $tests = $kept
}

# ── DROP TESTS THAT ARE A DUPLICATE OF AN EARLIER TEST, SAME ENTITY + SAME FILL ──
# Rob 2026-08-21, on NY_NYSPIN_EJUSTICE: "fix the 8 vacuous plan tests first".
#
# Two shapes, both of which emit a test that is LITERALLY another test run twice:
#   1. `X_af_<field>` == `X_any` when the combo has exactly ONE any[] optional. "Toggle the one
#      optional" and "fill every optional" are then the same fill, so the second proves nothing.
#   2. `X` == `X_guardrail_vs_Y` when the guardrail's losing identifier is not actually in the
#      fill -- the guardrail collapses onto its own base test and demonstrates no priority.
#      (NY: DALHOUT == DALHOUT_guardrail_vs_DALH, DALLOUT == DALLOUT_guardrail_vs_DALL.)
#
# WHY DEDUPE BY FILL-SET RATHER THAN BY SHAPE. Keying on (entity, sorted fills) is
# shape-agnostic: it catches both classes above and any future one, and it makes this generator
# agree with audit_log_inflation attack A BY CONSTRUCTION -- that gate keys on wire + fill-set
# for exactly this reason, so a plan that passes here cannot produce clone groups there. Writing
# two narrow rules instead would have left the next shape to be discovered by a live sweep.
#
# WHAT IS NOT LOST: identical fill means identical wire, so no combination loses coverage and no
# any[] field goes unexercised -- NY stayed at 16/16 combos, 100%. What goes is the double count.
# ORDER MATTERS: the FIRST occurrence is kept, and combo tests are emitted before their _af_/_any/
# _guardrail derivatives, so the surviving test is always the plainer, better-named one.
$seenFill = @{}
$kept2    = New-Object System.Collections.Generic.List[object]
$dupes    = New-Object System.Collections.Generic.List[string]
foreach ($t in $tests) {
    # NORMALISE OUT A FILL THAT MERELY RESTATES THE FORM DEFAULT (added 2026-08-31).
    #   The form ships that value whether or not the driver types it, so two tests differing ONLY by
    #   such a fill submit the IDENTICAL form state and produce the IDENTICAL wire -- yet their raw
    #   fill-sets differ, so the byte-identical-fill check above could not see them and both survived.
    #   FOUND ON HI_HCJDC_OFML v4.20 after the plan-dedupe pickup: `M55L_guardrail_vs_M55S` (2 fills)
    #   and `M55L_guardrail_vs_RQV` (the same 2 plus `vehicleTypeCode=1`) were kept as distinct tests,
    #   while HI's Vehicle form default IS `vehicleTypeCode=1` -- so the driver submitted the same
    #   thing twice and audit_log_inflation attack A still reported 1 clone group after the pickup
    #   cleared the other. The plan and that gate must agree BY CONSTRUCTION; this closes the gap.
    #   A fill carrying a DIFFERENT value than the default is a REAL distinction and is KEPT --
    #   a toggle test is required to differ from the default (feedback_toggle_tests_differ_from_default),
    #   so normalising on fieldId alone would have destroyed exactly the tests that matter.
    #   GUARD: if normalising empties the signature, fall back to the raw fill-set. An all-defaults
    #   test must not collapse onto every other all-defaults test across different combos.
    $fdE = $formDefaultsByEntity[$t.entity]
    $sigFills = @()
    foreach ($f in @($t.fills)) {
        if ($fdE -and $fdE.Contains($f.fieldId) -and "$($fdE[$f.fieldId])" -eq "$($f.value)") { continue }
        $sigFills += "$($f.fieldId)=$($f.value)"
    }
    if ($sigFills.Count -eq 0) { $sigFills = @($t.fills | ForEach-Object { "$($_.fieldId)=$($_.value)" }) }
    $sig = "$($t.entity)|" + ((@($sigFills) | Sort-Object) -join '&')
    if ($seenFill.ContainsKey($sig)) {
        $dupes.Add("$($t.comboKeyRef)$(if($t.anyField){"_af_$($t.anyField)"}) [$($t.kind)] -- byte-identical fill to $($seenFill[$sig])")
        continue
    }
    $seenFill[$sig] = "$($t.comboKeyRef)$(if($t.anyField){"_af_$($t.anyField)"})"
    $kept2.Add($t)
}
if ($dupes.Count -gt 0) {
    Write-Host "  [plan] dropped $($dupes.Count) DUPLICATE test(s) (same entity, byte-identical fill -- proves nothing twice):" -ForegroundColor DarkYellow
    $dupes | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkGray }
    $i = 0
    foreach ($t in $kept2) { $i++; $t.n = $i }
    $tests = $kept2
}

# ── DROP GUARDRAILS THAT CANNOT BE A CONTEST ─────────────────────────────────────
# A guardrail asserts "when BOTH identifiers are filled, WINNER fires, not LOSER". That is only
# a test if the loser could plausibly have won. When the winner and loser differ ONLY by an
# EXISTS / NOT_EXISTS condition on one field -- an in-state / out-of-state twin pair -- there is
# no contest: presence cannot be both, so the loser can never match the same fill.
#
# NY_NYSPIN_EJUSTICE, 2026-08-21: DALHOUT-vs-DALH and DALLOUT-vs-DALL differ only by whether
# RegistrationStateDH is present. Both guardrails filled exactly what plain DALHOUT / DALLOUT
# already fill, submitted a byte-identical wire, and proved nothing -- they surfaced as
# audit_log_inflation clone groups that the fill-set dedupe above could not see, because in the
# PLAN their fills differ from the winner's by one form-PREFILLED field (purposeCodeDH).
#
# THE TEST: a guardrail is vacuous when its fill-set is a SUBSET of the winner's OWN combo
# fill-set -- it adds no competing identifier at all. The five real guardrails on NY are all
# supersets (Plate+VIN, OLN+Name, Hull+Reg), so this keeps every genuine priority test and drops
# only the impossible ones. Verified on NY: 7 guardrails -> 5, and inflation A 2 -> 0.
$comboFillsByKey = @{}
foreach ($t in $tests) {
    if ($t.kind -eq 'combo') {
        $comboFillsByKey["$($t.entity)|$($t.comboKeyRef)"] =
            [System.Collections.Generic.HashSet[string]]::new([string[]]@($t.fills | ForEach-Object { "$($_.fieldId)" }))
    }
}
$kept3    = New-Object System.Collections.Generic.List[object]
$noContest = New-Object System.Collections.Generic.List[string]
foreach ($t in $tests) {
    if ($t.kind -eq 'guardrail' -and $t.expectedKeyRef) {
        $winKey = "$($t.entity)|$($t.expectedKeyRef)"
        if ($comboFillsByKey.ContainsKey($winKey)) {
            # A FIELD FILLED AT ITS OWN FORM DEFAULT IS NOT AN ADDED FIELD (BUILD_RULES 24, applied
            # to plan dedupe). OH_LEADS v2.11 shipped `ATDP` and `ATDP_guardrail_vs_RQ.P` as a
            # byte-identical inflation clone pair while PASSING this rule: the guardrail's fills
            # held LicensePlateYear=2026, absent from ATDP's own combo test -- so `$extra` was 1
            # and it read as a genuine competing identifier. But 2026 IS the form prefill, so it
            # was already present in the winner's form state and BOTH tests submitted the same
            # thing. Compare EFFECTIVE FORM STATE, not the fill list. A DIFFERENT value than the
            # default still counts as extra -- that is a real variation.
            $entDef = $formDefaultsByEntity[$t.entity]
            $extra = @($t.fills | Where-Object {
                if ($comboFillsByKey[$winKey].Contains("$($_.fieldId)")) { return $false }
                if ($entDef -and $entDef.Contains("$($_.fieldId)") -and
                    "$($entDef["$($_.fieldId)"])" -eq "$($_.value)") { return $false }
                return $true
            } | ForEach-Object { "$($_.fieldId)" })
            if ($extra.Count -eq 0) {
                $noContest.Add("$($t.expectedKeyRef) vs $($t.guardrailLoser) [$($t.entity)] -- fill adds no competing identifier over $($t.expectedKeyRef)'s own test; the pair differs only by a presence condition, so the loser can never match")
                continue
            }
        }
    }
    $kept3.Add($t)
}
if ($noContest.Count -gt 0) {
    Write-Host "  [plan] dropped $($noContest.Count) NO-CONTEST guardrail(s) (loser cannot match the same fill -- proves no priority):" -ForegroundColor DarkYellow
    $noContest | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkGray }
    $i = 0
    foreach ($t in $kept3) { $i++; $t.n = $i }
    $tests = $kept3
}

$plan = [ordered]@{
    provider = $provName
    version  = $version
    tier     = 'Full'
    note     = 'Full pass (tiers removed 2026-07-01): every combo + individual any[] per field + all-any[] together + guardrail tests. render/negative are manual one-time checks done at initial provider build only and are NOT part of the recurring test matrix (2026-07-01). The driver auto-submits all four kinds (combo/any-field/any/guardrail, 2026-07-01) -- guardrail fills[] already contains BOTH competing identifier fields, so it captures formState/RMS the same as any other test, no manual popup-capture workaround needed.'
    testCount = $tests.Count
    formDefaults = $formDefaultsByEntity
    tests    = $tests
}

if (-not $OutFile) {
    # Lives at the root of logs/ (not docs/) -- logs/ is the self-contained per-query evidence
    # package (plan + logs/<Entity>/ wire files), per the 2026-07-01 capture-pipeline standard.
    $logsDir = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'logs'
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
    $OutFile = Join-Path $logsDir "${provName}_TEST_PLAN_v${version}.json"
}
[System.IO.File]::WriteAllText($OutFile, ($plan | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[PASS] Test plan written: $OutFile ($($tests.Count) tests, full pass)" -ForegroundColor Green
$tests | Where-Object { $_.kind -eq 'combo' } | ForEach-Object { "  T$($_.n) $($_.entity) $($_.comboKeyRef): $((@($_.fills | ForEach-Object { $_.fieldId + '=' + $_.value })) -join ', ')" } | Select-Object -First 12 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Toggle-coverage summary -- any-field tests only prove a toggle if their value differs from the
# field default. Report inversions + any residual hollow tests so a hollow toggle never again
# passes unnoticed (the 6-provider silent-hollow bug, 2026-07-20).
# PRINT WHAT THE CONDITION CONSTRAINT DID. A substitution or a skip that reports nothing is
# indistinguishable from the check never running -- and this file's whole purpose is to stop
# generating tests that cannot run, so it must say when it acted.
if ($script:CondSkips.Count -gt 0) {
    # Header stays GENERIC because this list now carries two distinct causes -- a combo's own
    # IN/NOT_IN value list, and a tenant-enforced mutually-exclusive field pair. Each entry says
    # which; a header naming only one of them would misattribute the other.
    Write-Host ("[plan] {0} any[] fill(s) omitted -- each line says why:" -f $script:CondSkips.Count) -ForegroundColor Yellow
    $script:CondSkips | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkYellow }
}
Write-Host ("[{0}] Toggle coverage: {1} any-field test(s), {2} inverted from default, {3} hollow (flagged below)" -f `
    $(if ($script:ToggleStats.hollow -gt 0) { 'WARN' } else { 'PASS' }), `
    $script:ToggleStats.anyField, $script:ToggleStats.inverted, $script:ToggleStats.hollow) `
    -ForegroundColor $(if ($script:ToggleStats.hollow -gt 0) { 'Yellow' } else { 'Green' })

# Trust summary -- surface any unmapped fields / missing guardrails loudly (non-silent).
if ($script:Unresolved.Count -gt 0) {
    Write-Host ""
    Write-Host "[WARN] $($script:Unresolved.Count) trust issue(s) in this plan -- combos may fire under-filled or guardrails are missing:" -ForegroundColor Yellow
    foreach ($u in ($script:Unresolved | Select-Object -Unique)) { Write-Host "   - $u" -ForegroundColor Yellow }
    Write-Host "   Resolve (add the field's test value to Get-TestValue, or confirm it's intentionally blank) before the re-run." -ForegroundColor Yellow
} else {
    Write-Host "[PASS] Trust check: every combo set[]/any[] field resolved a test value; guardrails present where NOT_EXISTS conditions exist." -ForegroundColor Green
}

# Tenant-picklist gate: when the tenant's actual dropdown contents have been scoped
# (docs/reference/TENANT_PICKLISTS.json via __usxScopePicklists + import_picklists), every
# select fill value must match a tenant option the way usx_lib matches it (^CODE anchored).
# Catches the CA-gunTypeCode / NJ-GunMake class BEFORE any browser run. Hard FAIL (exit 1).
$tp = $script:TenantPicklists   # loaded once up front (also used by the toggle-value derivation)
if ($tp) {
    $tpFails = @(); $tpWarns = @()
    foreach ($t in $tests) {
        $entObj = if ($tp.entities) { $tp.entities.PSObject.Properties[$t.entity].Value } else { $null }
        if (-not $entObj) { continue }
        foreach ($fill in @($t.fills)) {
            if (-not $fill) { continue }
            $fldObj = $entObj.fields.PSObject.Properties[$fill.fieldId].Value
            if (-not $fldObj) { continue }               # not a scoped select (text input etc.)
            if ($fldObj.error) { continue }              # capture error already reported at import
            $re = '^' + [regex]::Escape("$($fill.value)") + '\b'
            if (-not @(@($fldObj.options) | Where-Object { $_ -match $re }).Count) {
                # Large lists are captured as ONE server page (~300); a miss there is
                # inconclusive -- the live fill is the authority (mirror import_picklists).
                if ($fldObj.truncated -or @($fldObj.options).Count -ge 250) {
                    $tpWarns += "$($t.entity).$($fill.fieldId): value '$($fill.value)' not in the captured subset ($(@($fldObj.options).Count) of a larger list) -- inconclusive, live fill is authority"
                } else {
                    $tpFails += "$($t.entity).$($fill.fieldId): value '$($fill.value)' matches no tenant option (first option: '$(@($fldObj.options)[0])')"
                }
            }
        }
    }
    $tpFails = @($tpFails | Select-Object -Unique); $tpWarns = @($tpWarns | Select-Object -Unique)
    foreach ($x in $tpWarns) { Write-Host "[WARN] Tenant-picklist gate: $x" -ForegroundColor Yellow }
    if ($tpFails.Count) {
        Write-Host ""
        Write-Host "[FAIL] Tenant-picklist gate: $($tpFails.Count) select value(s) do not exist in this tenant's dropdowns:" -ForegroundColor Red
        foreach ($x in $tpFails) { Write-Host "   - $x" -ForegroundColor Red }
        Write-Host "   Fix via docs/reference/TEST_VALUE_OVERRIDES.txt, then re-emit." -ForegroundColor Red
        exit 1
    }
    Write-Host "[PASS] Tenant-picklist gate: every select fill value exists in the scoped tenant dropdowns ($($tpWarns.Count) inconclusive on paged lists)." -ForegroundColor Green
}
