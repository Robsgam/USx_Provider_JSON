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
$script:PlatformFed = @{ 'dexStateUserId' = '1234' }

# Fields that Get-TestValue INTENTIONALLY leaves empty (not a mapping gap): in-state State
# (leave blank = home), optional name parts, and auto-populated hidden Attention. Everything
# else returning $null is a genuine unmapped field -> the combo would fire under-filled. Track loud.
$script:KnownEmpty = '(?i)^(registrationState|state|nameMiddle|nameSuffix|nameMiddleDH|nameSuffixDH|attention)$'
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
                    $val = Get-AnyFillValue $ent $ff $isOOS $entFormDefaults
                    Note-IfUnresolved "$ent $kr any[]" $ff $val
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
                foreach ($af in $anyNames) {
                    $ff = Resolve-FieldId $af $q $fieldIds
                    if (@($hiddenIds) -icontains $ff) { continue }
                    $v = Get-AnyFillValue $ent $ff $true $entFormDefaults $false
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
            $fd = @{}
            foreach ($f in $gFills) { $fd[$f.fieldId] = $f.value }
            foreach ($k in $entDefaults.Keys) { if (-not $fd.ContainsKey($k)) { $fd[$k] = $entDefaults[$k] } }
            $simKr = Get-SimFiringKeyRef $entQidms $fd
            if (-not $simKr) { continue }   # nothing fires for this fill -> not a valid guardrail
            $gCandidates.Add([PSCustomObject]@{ query = $gr.loserQidm.query; simKr = $simKr; fills = $gFills; loserKr = $gr.loserKr })
        }
        # Disambiguate guardrail log filenames ONLY when >1 loser combo resolves to the SAME
        # winner (e.g. FL_FCIC Boat: relatedHitSearchIndicator routes Hull between the FBQ and
        # QB combo families -- both "Hull wins" scenarios simulate to the same expectedKeyRef and
        # silently overwrote one another's log before this existed, 2026-07-02). Leaving
        # guardrailLoser unset for non-colliding winners keeps existing filenames stable across
        # providers that don't hit this (Get-CmPlanLabel falls back to the undisambiguated name).
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
