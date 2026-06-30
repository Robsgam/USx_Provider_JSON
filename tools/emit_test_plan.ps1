<#
  emit_test_plan.ps1 -- emit a machine-readable TEST_PLAN.json for the browser driver.

  Turns a provider JSON + tier into the ordered list of tests the driver (__usxRunPlan)
  executes: per entity, a render marker, then every combo (set[] fields resolved to DOM
  fieldId + a test value), then a negative marker. FINAL tier additionally emits an any[]
  test per combo (base set[] + the optional fields). Guardrail/deselect tests are matrix-only
  for now (multi-field routing) -- noted in the plan meta.

  Mirrors generate_test_matrix.ps1's resolution (combo set[] -> form fieldId via direct match
  or the QIDM attribute sourceField; Get-TestValue for values), but emits JSON the driver eats.

  Usage:
    .\emit_test_plan.ps1 -Path providers\NJ_NJCJIS\NJ_NJCJIS_v4.7.json -Tier Preliminary
    .\emit_test_plan.ps1 -Path <json> -Tier Final -OutFile <path.plan.json>
#>

param(
    [Parameter(Mandatory)][string]$Path,
    [ValidateSet('Preliminary','Final')][string]$Tier = 'Preliminary',
    [string]$OutFile
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_combo_match.ps1"

$raw = [System.IO.File]::ReadAllText((Resolve-Path $Path), [System.Text.UTF8Encoding]::new($false))
$json = $raw | ConvertFrom-Json
$provName = (Split-Path (Split-Path (Resolve-Path $Path) -Parent) -Leaf)

$version = "unknown"
if ($json.version) { $version = $json.version }
elseif ((Split-Path $Path -Leaf) -match 'v(\d+\.\d+)') { $version = $Matches[1] }

# Test value per DOM fieldId (case-insensitive). Mirrors generate_test_matrix.ps1 Get-TestValue.
function Get-TestValue([string]$fid, [bool]$isOOS) {
    switch -Regex ($fid) {
        '(?i)^licensePlateNumber'          { return 'TEST123' }
        '(?i)^licensePlateTypeCode'        { return 'PC' }
        '(?i)^licensePlateYear'            { return (Get-Date).Year.ToString() }
        '(?i)^vehicleIdentificationNumber' { return '1HGCM82633A123456' }
        '(?i)^vehicleMakeCode'             { return 'FORD' }
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
        '(?i)^birthDate'                   { return '01/15/1990' }
        '(?i)^sexCode'                     { return 'M' }
        '(?i)^imageIndicator'              { return 'N' }
        '(?i)^randomRequest'               { return 'N' }
        '(?i)^gunSerialNumber'             { return 'GUN12345' }
        '(?i)^gunMake'                     { return '05' }
        '(?i)^gunCaliber'                  { return '11' }
        '(?i)^gunModel'                    { return 'TEST' }
        '(?i)^ncicNumber'                  { return 'X123456789' }
        '(?i)^processControlNumber'        { return '0000012345' }
        '(?i)^articleSerialNumber'         { return 'ART99999' }
        '(?i)^articleTypeCode'             { return 'BBICYCL' }
        '(?i)^ownerAppliedNumber'          { return 'OAN999' }
        '(?i)^boatHullIdNumber'            { return 'FL1234AB56H7' }
        '(?i)^registrationNumber'          { return 'FL1234AB' }
        '(?i)^coastGuardDocumentNumber'    { return 'CG123456' }
        '(?i)^relatedHitSearchIndicator'   { return 'Y' }
        '(?i)^(caRequestPurposeCode|purposeCode)' { return 'C' }
        '(?i)^attention'                   { return 'SMITH J' }
        default                            { return $null }   # unknown -> skip (avoid junk)
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

function Build-Fills($names, $qidm, $fieldIds, $isOOS) {
    $fills = @()
    foreach ($n in @($names)) {
        $fid = Resolve-FieldId $n $qidm $fieldIds
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

$isFinal = ($Tier -eq 'Final')
$tests = New-Object System.Collections.Generic.List[object]
$n = 0

foreach ($ent in $entities) {
    $fieldIds = Get-QifFieldIds $qifByEntity[$ent]
    $entQidms = @($qidms | Where-Object { $_.targetEntity -eq $ent })

    # render marker
    $n++; $tests.Add([ordered]@{ n = $n; entity = $ent; kind = 'render' })

    foreach ($q in $entQidms) {
        foreach ($c in $q.combinations) {
            $kr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $setNames = @($c.requirements.set)
            $isOOS = [bool]($setNames | Where-Object { $_ -match '(?i)^(registrationState|state)$' })
            $fills = Build-Fills $setNames $q $fieldIds $isOOS
            $n++
            $tests.Add([ordered]@{
                n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                expectedKeyRef = $kr; kind = 'combo'; tier = 'Preliminary'; fills = $fills
            })
            # FINAL: individual any[] field tests + all-together
            if ($isFinal) {
                $anyNames = @($c.requirements.any)
                if ($anyNames.Count -gt 0) {
                    # One test per individual any[] field
                    foreach ($af in $anyNames) {
                        $ff  = Resolve-FieldId $af $q $fieldIds
                        $val = Get-TestValue $ff $isOOS
                        if ($null -ne $val -and $val -ne '') {
                            $n++
                            $tests.Add([ordered]@{
                                n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                                expectedKeyRef = $kr; kind = 'any-field'; tier = 'Final'
                                anyField = $ff
                                fills = @(@($fills)) + @([ordered]@{ fieldId = $ff; value = "$val" })
                            })
                        }
                    }
                    # All any[] fields together
                    $anyFills = Build-Fills ($setNames + $anyNames) $q $fieldIds $true
                    if (@($anyFills).Count -gt @($fills).Count) {
                        $n++
                        $tests.Add([ordered]@{
                            n = $n; entity = $ent; query = $q.query; comboKeyRef = $kr
                            expectedKeyRef = $kr; kind = 'any'; tier = 'Final'; fills = $anyFills
                        })
                    }
                }
            }
        }
    }

    # Guardrail tests (Final only) -- after all combos, before negative
    if ($isFinal) {
        foreach ($gr in @(Get-GuardrailTests $entQidms $fieldIds)) {
            $gFills = @()
            $exFf  = $fieldIds | Where-Object { $_ -ieq $gr.excludedFid } | Select-Object -First 1
            $exVal = Get-TestValue ($exFf ?? $gr.excludedFid) $false
            if ($null -ne $exVal -and $exVal -ne '') {
                $gFills += [ordered]@{ fieldId = ($exFf ?? $gr.excludedFid); value = "$exVal" }
            }
            foreach ($sf in @($gr.loserCombo.requirements.set)) {
                $ff  = Resolve-FieldId $sf $gr.loserQidm $fieldIds
                $val = Get-TestValue $ff $false
                if ($null -ne $val -and $val -ne '') { $gFills += [ordered]@{ fieldId = $ff; value = "$val" } }
            }
            $n++
            $tests.Add([ordered]@{
                n = $n; entity = $ent; query = $gr.loserQidm.query
                comboKeyRef = $null; expectedKeyRef = $gr.winnerKr
                kind = 'guardrail'; tier = 'Final'; fills = $gFills
            })
        }
    }

    # negative marker
    $n++; $tests.Add([ordered]@{ n = $n; entity = $ent; kind = 'negative' })
}

$plan = [ordered]@{
    provider = $provName
    version  = $version
    tier     = $Tier
    note     = if ($isFinal) { 'Final: combos + individual any[] per field + all-any[] together + guardrail tests (kind=guardrail, manual). render/negative/guardrail are markers only — driver auto-submits combo/any-field/any kinds.' } else { 'Preliminary: render + every combo (required fields) + negative.' }
    testCount = $tests.Count
    tests    = $tests
}

if (-not $OutFile) {
    $docs = Join-Path (Split-Path (Resolve-Path $Path) -Parent) 'docs'
    if (-not (Test-Path $docs)) { New-Item -ItemType Directory -Path $docs | Out-Null }
    $OutFile = Join-Path $docs "${provName}_TEST_PLAN_$($Tier).json"
}
[System.IO.File]::WriteAllText($OutFile, ($plan | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[PASS] Test plan written: $OutFile ($($tests.Count) tests, tier $Tier)" -ForegroundColor Green
$tests | Where-Object { $_.kind -eq 'combo' } | ForEach-Object { "  T$($_.n) $($_.entity) $($_.comboKeyRef): $((@($_.fills | ForEach-Object { $_.fieldId + '=' + $_.value })) -join ', ')" } | Select-Object -First 12 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
