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
function Canon([string]$t) { (($t -replace '[^A-Za-z0-9]','').ToLower() -replace 'dh$','') -replace 'cch$','' }
foreach ($b in $j.bundles) {
    foreach ($c in $b.configurations) {
        if ($c.combinations -and $c.name -notmatch '^RMS' -and $c.name -notmatch 'Results$') {
            $q = $c.name -replace "^$([regex]::Escape($Provider))_",''
            if ($q -match 'Query$') { $qidms[$q] = $c }
        }
        if ($c.type -eq 'QUERYINPUTFORM' -and $c.layout.'default') {
            $e = "$($c.targetEntity)"; if (-not $formFields.ContainsKey($e)) { $formFields[$e] = @{} }
            $lay = $c.layout.'default'
            foreach ($nid in $lay.PSObject.Properties.Name) {
                $p = $lay.$nid.props
                if ($p -and $p.fieldId) {
                    $k = Canon "$($p.fieldId)"
                    if (-not $formFields[$e].ContainsKey($k)) { $formFields[$e][$k] = "$($p.fieldId)" }
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
function Resolve-FieldIds([string]$devField, [string]$ent) {
    $c = Canon $devField
    $want = if ($expand.ContainsKey($c)) { @($expand[$c]) } else { @($c) }
    $out = @()
    foreach ($w in $want) { if ($formFields[$ent] -and $formFields[$ent].ContainsKey($w)) { $out += $formFields[$ent][$w] } }
    return ,@($out)
}

# ── 5. build the plan: mandatory-only, then one test per optional ─────────────────────
$tests = @(); $n = 0; $unreachable = 0; $nofire = 0
foreach ($it in ($items | Sort-Object Query, Num)) {
    if (-not $qidms.ContainsKey($it.Query)) { continue }   # query not built at all -- 2p owns that
    $ent = "$($qidms[$it.Query].targetEntity)"

    $subsets = @( ,@() )                                   # mandatory-only first
    foreach ($o in $it.Opt) { $subsets += ,@($o) }          # then each optional on its own

    foreach ($sub in $subsets) {
        $fills = @(); $miss = @()
        foreach ($fld in (@($it.Mand) + @($sub))) {
            $ids = Resolve-FieldIds $fld $ent
            if (-not $ids.Count) { $miss += $fld; continue }
            foreach ($id in $ids) { $fills += [pscustomobject]@{ fieldId = $id; value = (Get-Value $fld $id $ent) } }
        }
        # what SHOULD fire, per the canonical predicate
        $fd = @{}; foreach ($f in $fills) { $fd[$f.fieldId] = $f.value }
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
