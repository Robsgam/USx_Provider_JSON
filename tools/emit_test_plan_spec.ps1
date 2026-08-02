<#
  emit_test_plan_spec.ps1 -- generate the test plan from the DEVDOC + METADATA, not from the JSON.

  WHY THIS EXISTS (Rob 2026-07-30: "the test json needs to be wired to the metadata and dev doc and
  not the json itself"):
    emit_test_plan.ps1 derives every test from the BUILT JSON's combinations. That makes the plan a
    MIRROR of what we built, so it can only ever confirm what is there:
        no combo  ->  no test  ->  no failure.
    That is exactly how TX_TLETS sat at 95/95 ALL-PASS while carrying TWO unbuilt devdoc paths, 17
    devdoc optionals it could not transmit, and three devdoc-legal fills that send no query at all.
    A mirror cannot see an omission.

    Deriving from the SPEC inverts it. The plan becomes an independent statement of what the provider
    is SUPPOSED to do, and the failure modes become visible:
      devdoc path never built      -> a test exists, the driver submits, NOTHING FIRES -> FAIL
      devdoc optional not carried  -> a test fills it, the wire lacks it -> FAIL (audit_log_metadata)
      Plate+Year NO-FIRE           -> tested, and it fails loudly instead of being untestable
      our combo with no devdoc base -> appears as built-but-unplanned, i.e. an extra to justify

  WHAT IS AND IS NOT TAKEN FROM THE JSON -- the distinction is the whole point:
    FROM THE SPEC (devdoc + metadata): WHICH tests exist, which fields each one fills, and what the
      expected outcome is. The JSON gets no vote on the test population.
    FROM THE JSON: only the fieldId to type into and the entity it lives on. Unavoidable -- the
      driver has to address real form controls -- but it decides nothing about coverage. If a
      devdoc field has NO form field, that is not a reason to drop the test; it is emitted as
      UNREACHABLE, which is the finding.

  SOURCES, all reused rather than re-parsed (ENGINEERING_STANDARD section 4 rule 4):
    devdoc items   audit_devdoc_combinations.ps1 -Explain   (already validated against TX)
    field defs     the provider's metadata XML (type / maxLength) for value synthesis
    overrides      docs/reference/TEST_VALUE_OVERRIDES.txt   (entity-scoped wins over bare)
    expected combo tools/_sim_helpers.ps1 Get-FiringKeyRef   (the canonical predicate)

  OUTPUT: logs/<PROVIDER>_TEST_PLAN_SPEC_v<X.Y>.json -- deliberately a SEPARATE file from the
  JSON-derived plan so the two can be compared rather than one silently replacing the other. The
  delta between them IS the interesting artifact: tests the spec demands that the build cannot serve.

  Usage: .\emit_test_plan_spec.ps1 -Provider TX_TLETS [-DryRun]
#>

param(
    [Parameter(Mandatory=$true)][string]$Provider,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$toolDir  = $PSScriptRoot
$repoRoot = (Resolve-Path "$toolDir\..").Path
. (Join-Path $toolDir '_resolve_provider_json.ps1')
. (Join-Path $toolDir '_sim_helpers.ps1')

$provDir = Join-Path $repoRoot "providers\$Provider"
$jsonPath = Get-ProviderRootJson -ProvDir $provDir -Provider $Provider
if (-not $jsonPath) { Write-Host "  [ERROR] no active JSON for $Provider" -ForegroundColor Red; exit 1 }
$ver = ''
$m = [regex]::Match((Split-Path $jsonPath -Leaf), '_v([0-9]+\.[0-9]+)\.json$')
if ($m.Success) { $ver = $m.Groups[1].Value }

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPEC-DERIVED TEST PLAN -- $Provider v$ver" -ForegroundColor Cyan
Write-Host "  tests come from the DEVDOC + METADATA; the JSON only supplies fieldIds" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# ── 1. devdoc items, from the already-validated parser ────────────────────────────────
$ddTool = Join-Path $toolDir 'audit_devdoc_combinations.ps1'
$ddRaw = & powershell -ExecutionPolicy Bypass -File $ddTool -Path $jsonPath -Explain 2>&1 | Out-String
$items = @()
foreach ($ln in ($ddRaw -split "`n")) {
    $mm = [regex]::Match($ln, 'devdoc\s+(\S+)\s+#(\d+):\s*mand=\[([^\]]*)\]\s*opt=\[([^\]]*)\]')
    if (-not $mm.Success) { continue }
    $items += [pscustomobject]@{
        Query = $mm.Groups[1].Value; Num = [int]$mm.Groups[2].Value
        Mand = @($mm.Groups[3].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Opt  = @($mm.Groups[4].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
}
if (-not $items.Count) { Write-Host "  [FAIL] parsed 0 devdoc items -- do NOT read this as 'nothing to test'" -ForegroundColor Red; exit 1 }
Write-Host "  devdoc items parsed: $($items.Count)"

# ── 2. metadata field definitions (type + maxLength) for value synthesis ──────────────
$xmlPath = Join-Path $provDir "source\$Provider.xml"
if (-not (Test-Path $xmlPath)) {
    $base = ($Provider -split '_')[0..1] -join '_'
    $alt = Join-Path $repoRoot "providers\$base\source\$base.xml"
    if (Test-Path $alt) { $xmlPath = $alt }
}
$fieldDef = @{}
if (Test-Path $xmlPath) {
    [xml]$x = Get-Content $xmlPath -Raw
    foreach ($fl in $x.SelectNodes('//*[local-name()="Field"]')) {
        $n = "$($fl.name)"; if (-not $n) { continue }
        if (-not $fieldDef.ContainsKey($n)) {
            $fieldDef[$n] = [pscustomobject]@{ Type = "$($fl.type)"; Max = "$($fl.maxLength)" }
        }
    }
}
Write-Host "  metadata field definitions: $($fieldDef.Count)"

# ── 3. JSON: fieldId + entity ONLY (no vote on coverage) ─────────────────────────────
$j = Get-Content $jsonPath -Raw | ConvertFrom-Json
$qidms = @{}; $formFields = @{}   # entity -> @{canon = fieldId}
# entity -> @{fieldId = initialValue}. A PREFILLED control is ALWAYS present when the officer hits
# submit -- it is not something they have to type. Evaluating the firing predicate against the
# devdoc fills ALONE therefore simulates an empty prefilled control, which no officer can produce,
# and every combo whose set[] needs that field reads NO-FIRE. That is not a hypothetical: the CLETS
# family carries a transaction-envelope purposeCode prefilled 'C' on every entity and appearing in
# NO devdoc combination list, so this blindness reported 74 of 79 CA_CLETS tests and 72 of 79
# CA_VENTURA_COUNTY tests as "a devdoc-legal fill sends no query" when in fact every one of them
# fires. 294 NO-FIRE across the portfolio, mostly noise -- which is worse than useless, because it
# buried the handful of REAL ones (FL x1, OR_LEDS x3) in a number nobody could act on.
# Same primitive audit_combo_reachability already uses: count form initialValue as always-present.
$prefills = @{}
function Canon([string]$t) { (($t -replace '[^A-Za-z0-9]','').ToLower() -replace 'dh$','') -replace 'cch$','' }
foreach ($b in $j.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.combinations -and $c.name -notmatch '^RMS' -and $c.name -notmatch 'Results$') {
            $q = $c.name -replace "^$([regex]::Escape($Provider))_",''
            if ($q -match 'Query$') { $qidms[$q] = $c }
        }
        if ($c.type -eq 'QUERYINPUTFORM' -and $c.layout.'default') {
            $e = "$($c.targetEntity)"; if (-not $formFields.ContainsKey($e)) { $formFields[$e] = @{} }
            if (-not $prefills.ContainsKey($e)) { $prefills[$e] = @{} }
            $lay = $c.layout.'default'
            foreach ($nid in $lay.PSObject.Properties.Name) {
                $p = $lay.$nid.props
                if ($p -and $p.fieldId) {
                    # DH-AWARE INDEX. Canon() strips the trailing 'DH', so NameLastDH and NameLast both
                    # canonicalise to 'namelast' and a single first-wins map kept whichever came first
                    # (the DL control). Every DriverHistory test then filled DL fields, DH combos
                    # require DH-suffixed fields, and all 14 DH tests came back NO-FIRE -- a generator
                    # artifact reported as if it were a provider defect. Keep the two families in
                    # SEPARATE key spaces and let the caller ask for the one it needs.
                    $raw = "$($p.fieldId)"
                    $k = Canon $raw
                    if ($null -ne $p.initialValue -and "$($p.initialValue)".Length) { $prefills[$e][$raw] = "$($p.initialValue)" }
                    if ($raw -cmatch 'DH$') {
                        if (-not $formFields[$e].ContainsKey("dh|$k")) { $formFields[$e]["dh|$k"] = $raw }
                    } else {
                        if (-not $formFields[$e].ContainsKey($k)) { $formFields[$e][$k] = $raw }
                    }
                }
            }
        }
    }
}

# ── 4. test-value overrides (entity-scoped wins) ──────────────────────────────────────
$ov = @{}
$ovPath = Join-Path $provDir 'docs\reference\TEST_VALUE_OVERRIDES.txt'
if (Test-Path $ovPath) {
    foreach ($l in (Get-Content $ovPath)) {
        if ($l -match '^\s*#' -or $l -notmatch '=') { continue }
        $kv = $l -split '=', 2
        $ov[$kv[0].Trim()] = $kv[1].Trim()
    }
}
# composite + alias expansion: a devdoc field name may map to several form fields
$expand = @{ 'name' = @('namelast','namefirst'); 'state' = @('registrationstate')
             'gunserialnumber' = @('serialnumber'); 'articleserialnumber' = @('articleserialnumber','serialnumber')
             'gunmake' = @('gunmake','firearmmake'); 'badgenumber' = @('dexstateuserid') }

function Get-Value([string]$devField, [string]$fieldId, [string]$ent) {
    if ($ov.ContainsKey("$ent.$fieldId")) { return $ov["$ent.$fieldId"] }
    if ($ov.ContainsKey($fieldId)) { return $ov[$fieldId] }
    $def = $null; if ($fieldDef.ContainsKey($devField)) { $def = $fieldDef[$devField] }
    $ty = if ($def) { $def.Type } else { '' }
    $mx = 0; if ($def -and $def.Max) { [void][int]::TryParse($def.Max, [ref]$mx) }
    switch -Regex ("$devField|$ty") {
        '(?i)birthdate|date'      { return '1990-01-15' }
        '(?i)^name'               { return 'DOE' }
        '(?i)sexcode'             { return 'M' }
        '(?i)racecode'            { return 'W' }
        '(?i)state'               { return 'TX' }
        '(?i)imageindicator'      { return 'N' }
        '(?i)relatedhit'          { return 'Y' }
        '(?i)financialresp'       { return 'Y' }
        '(?i)purposecode|reasoncode' { return 'C' }
        '(?i)vehicleidentification'  { return '1HGCM82633A123456' }
        '(?i)licenseplateyear|vehicleyear' { return '2026' }
        '(?i)licenseplatetype'    { return 'PC' }
        default {
            $base = 'TEST123'
            if ($mx -gt 0 -and $base.Length -gt $mx) { $base = $base.Substring(0,$mx) }
            return $base
        }
    }
}
function Resolve-FieldIds([string]$devField, [string]$ent, [bool]$preferDH) {
    $c = Canon $devField
    $want = if ($expand.ContainsKey($c)) { @($expand[$c]) } else { @($c) }
    $out = @()
    foreach ($w in $want) {
        if (-not $formFields[$ent]) { continue }
        # A DH-targeted query must drive the DH-suffixed controls; fall back to the plain family only
        # for fields that have no DH twin (e.g. Attention, which exists once).
        if ($preferDH -and $formFields[$ent].ContainsKey("dh|$w")) { $out += $formFields[$ent]["dh|$w"] }
        elseif ($formFields[$ent].ContainsKey($w))                 { $out += $formFields[$ent][$w] }
    }
    return ,@($out)
}
# Is this query DH-targeted? Derived from the QIDM's OWN combo fields, never from its name -- a
# name test would miss a provider that suffixes differently.
function Test-IsDhQuery($qidm) {
    foreach ($cm in @($qidm.combinations)) {
        foreach ($fl in (@($cm.requirements.set) + @($cm.requirements.any))) {
            if ("$fl" -cmatch 'DH$') { return $true }
        }
    }
    return $false
}

# ── 5. build the plan: mandatory-only, then one test per optional ─────────────────────
$tests = @(); $n = 0; $unreachable = 0; $nofire = 0
foreach ($it in ($items | Sort-Object Query, Num)) {
    if (-not $qidms.ContainsKey($it.Query)) { continue }   # query not built at all -- 2p owns that
    $ent = "$($qidms[$it.Query].targetEntity)"
    $isDh = Test-IsDhQuery $qidms[$it.Query]

    $subsets = @( ,@() )                                   # mandatory-only first
    foreach ($o in $it.Opt) { $subsets += ,@($o) }          # then each optional on its own

    foreach ($sub in $subsets) {
        $fills = @(); $miss = @()
        foreach ($fld in (@($it.Mand) + @($sub))) {
            $ids = Resolve-FieldIds $fld $ent $isDh
            if (-not $ids.Count) { $miss += $fld; continue }
            foreach ($id in $ids) { $fills += [pscustomobject]@{ fieldId = $id; value = (Get-Value $fld $id $ent) } }
        }
        # what SHOULD fire, per the canonical predicate
        # Seed with the entity's PREFILLED controls first, then let the devdoc fills win on any
            # field the officer actually types. `fills` stays devdoc-derived -- it is what the driver
            # types, and a prefilled control needs no typing -- but the PREDICTION has to be made
            # against the form state that will really be submitted. See the $prefills note above.
            $fd = @{}
            if ($prefills.ContainsKey($ent)) { foreach ($pk in $prefills[$ent].Keys) { $fd[$pk] = $prefills[$ent][$pk] } }
            foreach ($f in $fills) { $fd[$f.fieldId] = $f.value }
        $fired = $null
        try { $fired = Get-FiringKeyRef @($qidms[$it.Query]) $fd } catch { }
        $n++
        $expect = if ($miss.Count) { 'UNREACHABLE' } elseif (-not $fired) { 'NO-FIRE' } else { $fired }
        if ($expect -eq 'UNREACHABLE') { $unreachable++ }
        if ($expect -eq 'NO-FIRE') { $nofire++ }
        $tests += [pscustomobject]@{
            n = $n; entity = $ent; query = $it.Query
            specSource = "devdoc $($it.Query) #$($it.Num)"
            optionalsAdded = @($sub)
            expectedKeyRef = $expect
            unwiredFields  = @($miss)
            fills = @($fills)
        }
    }
}

Write-Host "  tests generated: $n   expected NO-FIRE: $nofire   UNREACHABLE (devdoc field not on form): $unreachable"
$plan = [pscustomobject]@{
    provider = $Provider; version = $ver; derivedFrom = 'devdoc + metadata (NOT the built JSON)'
    note = 'expectedKeyRef=NO-FIRE means the devdoc allows this fill but no built combo matches -- the driver should submit it and the sweep should record that nothing was sent. UNREACHABLE means a devdoc field has no form control at all.'
    testCount = $n; tests = $tests
}
$outPath = Join-Path $provDir "logs\${Provider}_TEST_PLAN_SPEC_v$ver.json"
if ($DryRun) {
    Write-Host "  DRY RUN -- first 3 tests:" -ForegroundColor Yellow
    $tests | Select-Object -First 3 | ForEach-Object { Write-Host "    T$($_.n) $($_.specSource) expect=$($_.expectedKeyRef) fills=$((($_.fills|ForEach-Object{"$($_.fieldId)=$($_.value)"}) -join ', '))" -ForegroundColor DarkGray }
    exit 0
}
($plan | ConvertTo-Json -Depth 12) | Set-Content $outPath -Encoding utf8
Write-Host "  [OK] written: $outPath" -ForegroundColor Green
exit 0
