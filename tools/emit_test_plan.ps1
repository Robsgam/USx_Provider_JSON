<#
  emit_test_plan.ps1 -- emit a machine-readable TEST_PLAN.json for the browser driver.

  Tiers were removed 2026-07-01 -- the plan is always the single all-or-nothing full pass:
  per entity a render marker, every combo (set[] fields resolved to DOM fieldId + a test
  value), each combo's individual any[] field tests + an all-any test, guardrail tests, and
  a negative marker. The -Tier param is accepted for back-compat but ignored.

  Mirrors generate_test_matrix.ps1's resolution (combo set[] -> form fieldId via direct match
  or the QIDM attribute sourceField; Get-TestValue for values), but emits JSON the driver eats.

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
function Get-SimFilledRefs($qidm, $formData) {
    $filled = @()
    foreach ($attr in $qidm.attributes) {
        $sfs = @()
        if ($attr.sourceField -is [System.Array]) { $sfs = $attr.sourceField }
        elseif ($attr.sourceField) { $sfs = @($attr.sourceField) }
        $has = $false
        foreach ($sf in $sfs) { if ($formData.ContainsKey($sf) -and $formData[$sf]) { $filled += $sf; $has = $true } }
        if ($has) { $filled += $attr.name }
    }
    return ($filled | Select-Object -Unique)
}
function Get-SimFiringKeyRef($entQidms, $formData) {
    foreach ($q in $entQidms) {
        $filled = Get-SimFilledRefs $q $formData
        foreach ($c in $q.combinations) {
            $set = @($c.requirements.set)
            $any = @($c.requirements.any)
            $setOk = $true
            foreach ($f in $set) { if ($filled -notcontains $f) { $setOk = $false; break } }
            $anyOk = $true
            if ($set.Count -eq 0 -and $any.Count -gt 0) {
                $anyOk = $false
                foreach ($f in $any) { if ($filled -contains $f) { $anyOk = $true; break } }
            }
            if (-not ($setOk -and $anyOk)) { continue }
            if ((Test-ComboConditionsCore (Get-ComboConditions $c) $formData).ok) {
                if ($c.keyReference) { return $c.keyReference } else { return $c.keyRef }
            }
        }
    }
    return $null
}

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
$script:ValueOverrides = @{}
$ovPath = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'docs\reference\TEST_VALUE_OVERRIDES.txt'
if (Test-Path $ovPath) {
    foreach ($line in Get-Content $ovPath) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k, $v = $line -split '=', 2
        $script:ValueOverrides[$k.Trim()] = $v.Trim()
    }
    Write-Host "[emit] $($script:ValueOverrides.Count) test-value override(s) loaded from $ovPath"
}

# Test value per DOM fieldId (case-insensitive). Mirrors generate_test_matrix.ps1 Get-TestValue.
function Get-TestValue([string]$fid, [bool]$isOOS) {
    foreach ($k in $script:ValueOverrides.Keys) {
        if ($k -ieq $fid) { return $script:ValueOverrides[$k] }
    }
    switch -Regex ($fid) {
        '(?i)^licensePlateNumber'          { return 'TEST123' }
        '(?i)^licensePlateTypeCode'        { return 'PC' }
        '(?i)^licensePlateYear'            { return (Get-Date).Year.ToString() }
        '(?i)^vehicleIdentificationNumber' { return '1HGCM82633A123456' }
        # Make dropdown codes are category-prefixed (CNST_FORD, PASS_FORD, ...); usx_lib.js
        # anchors its option match to the leading code (^CODE\b), so a bare "FORD" matches
        # nothing and falls back to opts[0]. CNST_FORD is the documented CA/FL-consistent value.
        '(?i)^vehicleMakeCode'             { return 'CNST_FORD' }
        '(?i)^vehicleYear'                 { return '2023' }
        '(?i)^decalNumber'                 { return 'FL12345678' }
        '(?i)^titleLienInformation'        { return 'ABCD1234' }
        '(?i)^(registrationState|^state)$' { if ($isOOS) { return 'GA' } else { return $null } }
        '(?i)^registrationStateDH'         { return 'NJ' }
        '(?i)^operatorLicenseNumber'       { return 'D999888777' }
        '(?i)^nameLast'                    { return 'DOE' }
        '(?i)^nameFirst'                   { return 'JOHN' }
        '(?i)^nameMiddle'                  { return $null }
        '(?i)^nameSuffix'                  { return $null }
        # Cross-entity owner-address refinements (CA IN.VP any[]).
        '(?i)^addressCity'                 { return 'RENO' }
        '(?i)^addressStreetNumber'         { return '123' }
        # Native <input type=date> only accepts ISO yyyy-MM-dd via .value (usx_lib.js
        # fillText also normalizes defensively, but emit the right format at the source).
        '(?i)^birthDate'                   { return '1990-01-15' }
        '(?i)^sexCode'                     { return 'M' }
        '(?i)^imageIndicator'              { return 'N' }
        '(?i)^randomRequest'               { return 'N' }
        # Gun serial fieldId varies by provider: gunSerialNumber (NJ) or serialNumber (CA). Match both.
        '(?i)^(gun)?serialNumber'          { return 'GUN12345' }
        # Gun make dropdown uses provider code tables -- CA/NCIC use 3-char alpha codes (e.g. IMI),
        # NOT numeric; usx_lib anchors ^CODE, so a bare number matches nothing. IMI is confirmed live.
        '(?i)^gunMake'                     { return 'IMI' }
        '(?i)^gunCaliber'                  { return '11' }
        '(?i)^gunModel'                    { return 'TEST' }
        # Criminal-records (CA IR.QVC) + demographic optional fields.
        '(?i)^criminalIdNumber'            { return 'CII123456' }
        '(?i)^socialSecurityNumber'        { return '123456789' }
        '(?i)^age'                         { return '35' }
        '(?i)^ncicNumber'                  { return 'X123456789' }
        '(?i)^processControlNumber'        { return '0000012345' }
        '(?i)^articleSerialNumber'         { return 'ART99999' }
        '(?i)^articleTypeCode'             { return 'BBICYCL' }
        '(?i)^ownerAppliedNumber'          { return 'OAN999' }
        '(?i)^boatHullIdNumber'            { return 'FL1234AB56H7' }
        '(?i)^registrationNumber'          { return 'FL1234AB' }
        '(?i)^coastGuardDocumentNumber'    { return 'CG123456' }
        '(?i)^related(Hit)?Search(Hit)?Indicator' { return 'Y' }
        '(?i)^vehicleTypeCode'             { return '1' }
        '(?i)^gunTypeCode'                 { return 'H' }   # NCIC gun TYP code (H - BOMB); 'HP' is not in the table (live-confirmed CA 2026-07-02)
        '(?i)^raceCode'                    { return 'W' }
        '(?i)^height$'                     { return '509' }
        '(?i)^addressCounty'               { return 'LA' }
        '(?i)^appsRequestIndicator'        { return 'Y' }
        '(?i)^articleBrand'                { return 'SONY' }
        '(?i)^articleCategory'             { return 'E' }
        '(?i)^(caRequestPurposeCode|purposeCode)' { return 'C' }
        # Attention is AUTO-POPULATED by a handler into a HIDDEN InpH field (officer profile,
        # gate-feeder initialValue) -- there is NO visible control to fill, so the driver must
        # not try (doing so flags a false "under-filled"). It still serializes server-side; verify
        # it in the captured XML, not by filling. Skip like in-state State.
        '(?i)^attention'                   { return $null }
        default                            { return $null }   # unknown -> skip (avoid junk)
    }
}

# Fields that Get-TestValue INTENTIONALLY leaves empty (not a mapping gap): in-state State
# (leave blank = home), optional name parts, and auto-populated hidden Attention. Everything
# else returning $null is a genuine unmapped field -> the combo would fire under-filled. Track loud.
$script:KnownEmpty = '(?i)^(registrationState|state|nameMiddle|nameSuffix|attention)$'
$script:Unresolved = New-Object System.Collections.Generic.List[string]
function Note-IfUnresolved([string]$ctx, [string]$fid, $val) {
    if (($null -eq $val -or $val -eq '') -and $fid -notmatch $script:KnownEmpty) {
        $script:Unresolved.Add("${ctx}: '$fid' has no test value (unmapped in Get-TestValue)")
    }
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

foreach ($ent in $entities) {
    $fieldIds = Get-QifFieldIds $qifByEntity[$ent]
    $hiddenIds = @(Get-QifHiddenFieldIds $qifByEntity[$ent])
    $formDefaultsByEntity[$ent] = Get-QifFormDefaults $qifByEntity[$ent]
    $entQidms = @($qidms | Where-Object { $_.targetEntity -eq $ent })

    # render/negative are manual one-time checks done at initial provider build, not part
    # of the recurring per-rebuild test matrix (2026-07-01 user directive) -- omitted here.

    foreach ($q in $entQidms) {
        foreach ($c in $q.combinations) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $setNames = @($c.requirements.set)
            $isOOS = [bool]($setNames | Where-Object { $_ -match '(?i)^(registrationState|state)$' })
            $fills = Build-Fills $setNames $q $fieldIds $isOOS $hiddenIds
            # Trust: flag any set[] field we couldn't resolve a value for (under-fill risk).
            foreach ($sn in $setNames) { Note-IfUnresolved "$ent $kr set[]" (Resolve-FieldId $sn $q $fieldIds) (Get-TestValue (Resolve-FieldId $sn $q $fieldIds) $isOOS) }
            $n++
            $tests.Add([ordered]@{
                n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                expectedKeyRef = $kr; kind = 'combo'; tier = 'Full'; fills = $fills
            })
            # individual any[] field tests + all-together (full pass)
            $anyNames = @($c.requirements.any)
            if ($anyNames.Count -gt 0) {
                # One test per individual any[] field
                foreach ($af in $anyNames) {
                    $ff  = Resolve-FieldId $af $q $fieldIds
                    if (@($hiddenIds) -icontains $ff) { continue }   # hidden gate-feeder (e.g. automated Attention): nothing to type
                    $val = Get-TestValue $ff $isOOS
                    Note-IfUnresolved "$ent $kr any[]" $ff $val
                    if ($null -ne $val -and $val -ne '') {
                        $n++
                        $tests.Add([ordered]@{
                            n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                            expectedKeyRef = $kr; kind = 'any-field'; tier = 'Full'
                            anyField = $ff
                            fills = @(@($fills)) + @([ordered]@{ fieldId = $ff; value = "$val" })
                        })
                    }
                }
                # All any[] fields together
                $anyFills = Build-Fills ($setNames + $anyNames) $q $fieldIds $true $hiddenIds
                if (@($anyFills).Count -gt @($fills).Count) {
                    $n++
                    $tests.Add([ordered]@{
                        n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                        expectedKeyRef = $kr; kind = 'any'; tier = 'Full'; fills = $anyFills
                    })
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
            foreach ($sf in @($gr.loserCombo.requirements.set)) {
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
            $n++
            $tests.Add([ordered]@{
                n = $n; entity = $ent; query = $gr.loserQidm.query
                comboKeyRef = $null; expectedKeyRef = $simKr
                kind = 'guardrail'; tier = 'Full'; fills = $gFills
            })
        }
    }
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
$tpPath = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'docs\reference\TENANT_PICKLISTS.json'
if (Test-Path $tpPath) {
    $tp = Get-Content $tpPath -Raw | ConvertFrom-Json
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
