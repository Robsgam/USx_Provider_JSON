<#
  test_cad_dispatch.ps1 -- CAD Dispatch Coverage Validator
  Determines which combos CAD auto-populate can trigger and validates that each
  CAD-triggerable combo fires as expected when the platform auto-populates form
  fields from incident context.

  How it works:
    1. Load provider JSON + cad_field_mapping.json (same list audit_cad.ps1 uses).
    2. For each CommSys combo, check if all set[] fields are covered by:
         (a) a CAD field for that entity (case-insensitive PascalCase match), OR
         (b) a combo defaults[] entry.
    3. For each CAD-triggerable combo, build a minimal form state containing only
       those CAD-sent fields + defaults, then run the combo simulator.
    4. Verify the expected combo fires first.  Report PASS / FAIL / SKIP.

  Limitations (by design -- not bugs):
    - Combos whose set[] requires fields absent from both the CAD list and combo
      defaults[] are marked SKIP (not CAD-triggerable from auto-populate alone).
    - Union-pool co-fires (LIMITATION #1) are noted but do not cause FAIL.
    - RMS QIDMs are excluded (CAD auto-populate targets CommSys transactions only).

  Usage:
    pwsh -File tools\test_cad_dispatch.ps1 -Provider CA_CLETS
    pwsh -File tools\test_cad_dispatch.ps1 -Provider NJ_NJCJIS -OutFile docs\CAD_DISPATCH_TEST.txt
#>

param(
    [Parameter(Mandatory)][string]$Provider,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

# ── Shared combo-condition predicates ────────────────────────────────────────
. (Join-Path $PSScriptRoot '_sim_helpers.ps1')

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Out {
    param([string]$Msg, [ConsoleColor]$Color = 'White', [switch]$NoNewline)
    if ($NoNewline) { Write-Host $Msg -ForegroundColor $Color -NoNewline }
    else            { Write-Host $Msg -ForegroundColor $Color }
    if ($script:outLines) { $script:outLines += $Msg }
}

# Enumerate all formInput fieldIds from a QIF layout variant.
function Get-QifAllFieldIds($layouts) {
    $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($layout in $layouts) {
        foreach ($nodeKey in $layout.nodes.PSObject.Properties.Name) {
            $node = $layout.nodes.$nodeKey
            if ($node.type -in @('FormInput','FormSelect','FormDate','FormCheckbox')) {
                if ($node.props -and $node.props.fieldId) { [void]$ids.Add($node.props.fieldId) }
            }
        }
    }
    return $ids
}

# Resolve a QIDM combo's set[] field to the QIF fieldId (case-insensitive).
# Returns the canonical fieldId used in the QIF, or $null if not found.
function Resolve-FieldId([string]$field, $qifFieldIds) {
    foreach ($id in $qifFieldIds) {
        if ($id -ieq $field) { return $id }
    }
    return $null
}

# Check if a field name is "CAD-sendable" for the given entity:
#   camelCase exact match OR PascalCase equivalent (e.g., "licensePlateNumber" -> "LicensePlateNumber").
function Test-IsCadField([string]$field, $cadList) {
    foreach ($cf in $cadList) {
        if ($cf -ieq $field) { return $true }
        # Build PascalCase from camelCase CAD name (uppercase first char)
        $pascal = $cf[0].ToString().ToUpper() + $cf.Substring(1)
        if ($pascal -eq $field) { return $true }
    }
    return $false
}

# Resolve the camelCase CAD field name to the matching QIF fieldId.
function Get-CadFieldId([string]$cadField, $qifFieldIds) {
    foreach ($id in $qifFieldIds) {
        if ($id -ieq $cadField) { return $id }
        $pascal = $cadField[0].ToString().ToUpper() + $cadField.Substring(1)
        if ($pascal -eq $id) { return $id }
    }
    return $null
}

# Get all sourceFields from QIDM attributes that have a value in formData.
function Get-FilledNamesForQidm($qidm, $formData) {
    $filled = [System.Collections.Generic.List[string]]::new()
    foreach ($attr in $qidm.attributes) {
        $sourceFields = @()
        if ($attr.sourceField -is [System.Array]) { $sourceFields = @($attr.sourceField) }
        elseif ($attr.sourceField) { $sourceFields = @($attr.sourceField) }

        foreach ($sf in $sourceFields) {
            if ($formData.ContainsKey($sf) -and -not [string]::IsNullOrWhiteSpace("$($formData[$sf])")) {
                if (-not $filled.Contains($sf)) { $filled.Add($sf) }
                if (-not $filled.Contains($attr.name)) { $filled.Add($attr.name) }
            }
        }
    }
    return $filled
}

# ── Load files ───────────────────────────────────────────────────────────────

$repoRoot     = Split-Path $PSScriptRoot -Parent
$cadFieldPath = Join-Path $PSScriptRoot 'config\cad_field_mapping.json'

if (-not (Test-Path $cadFieldPath)) { Write-Error "CAD field mapping not found: $cadFieldPath"; exit 1 }
$cadConfig = Get-Content $cadFieldPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Discover provider JSON (versioned name wins over bare name)
$provDir = Join-Path $repoRoot "providers\$Provider"
if (-not (Test-Path $provDir)) { Write-Error "Provider directory not found: $provDir"; exit 1 }
$jsonCandidates = Get-ChildItem $provDir -Filter '*.json' -File |
    Where-Object { $_.Name -notmatch '(archive|phases|release|CODETYPE)' } |
    Sort-Object Name -Descending
$jsonFile = $jsonCandidates | Where-Object { $_.Name -match "^${Provider}_v" } | Select-Object -First 1
if (-not $jsonFile) { $jsonFile = $jsonCandidates | Where-Object { $_.BaseName -eq $Provider } | Select-Object -First 1 }
if (-not $jsonFile) { Write-Error "No provider JSON found in $provDir"; exit 1 }

$json = [System.IO.File]::ReadAllText($jsonFile.FullName, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json

# ── Collect QIF layouts + CommSys QIDMs ──────────────────────────────────────

$allQifLayouts = @{}    # entity -> list of layout objects
$commSysQidms  = @()

foreach ($bundle in $json.bundles) {
    foreach ($cfg in $bundle.configurations) {
        if ($cfg.type -eq 'QUERYINPUTFORM') {
            $ent = $cfg.targetEntity
            if (-not $allQifLayouts.ContainsKey($ent)) { $allQifLayouts[$ent] = @() }
            foreach ($lv in $cfg.layoutVariants) {
                $allQifLayouts[$ent] += $lv
            }
        }
        if ($cfg.type -eq 'QUERYINPUTDATAMAPPING' -and $cfg.handlerFunction -eq 'CommsysTransactionRequestHandler') {
            $commSysQidms += $cfg
        }
    }
}

# Build per-entity fieldId sets
$qifFieldsByEntity = @{}
foreach ($ent in $allQifLayouts.Keys) {
    $qifFieldsByEntity[$ent] = Get-QifAllFieldIds $allQifLayouts[$ent]
}

# ── Test value catalog: sensible values per fieldId stem ─────────────────────

$testValues = @{
    # Vehicle
    LicensePlateNumber          = 'ABC1234'
    LicensePlateTypeCode        = 'PC'
    LicensePlateYear            = '2026'
    VehicleIdentificationNumber = '1HGCM82633A123456'
    RegistrationState           = 'NV'
    VehicleMakeCode             = 'FORD'
    VehicleYear                 = '2023'
    # Person
    purposeCode                 = 'C'
    OperatorLicenseNumber       = 'D123456789'
    NameLast                    = 'DOE'
    NameFirst                   = 'JOHN'
    NameMiddle                  = 'A'
    BirthDate                   = '1990-01-15'
    SexCode                     = 'M'
    RaceCode                    = 'W'
    SocialSecurityNumber        = '123456789'
    Age                         = '30'
    Height                      = '510'
    # Firearm
    GunSerialNumber             = 'SN123456'
    serialNumber                = 'SN123456'
    GunMake                     = 'SMTH'
    firearmMake                 = 'SMTH'
    GunCaliber                  = '9MM'
    GunModel                    = 'M&P'
    GunTypeCode                 = 'P'
    # Article
    ArticleSerialNumber         = 'ART123456'
    ArticleTypeCode             = 'COMP'
    articleBrand                = 'APPLE'
    # Boat
    BoatHullIdNumber            = 'FL1234AB56H7'
    RegistrationNumber          = 'FL1234AB'
    # Common
    addressCity                 = 'LOS ANGELES'
    addressStreetNumber         = '123'
}

function Get-TestValue([string]$fieldId) {
    if ($testValues.ContainsKey($fieldId)) { return $testValues[$fieldId] }
    return 'TEST'
}

# ── Output buffer ─────────────────────────────────────────────────────────────

$script:outLines = if ($OutFile) { [System.Collections.Generic.List[string]]::new() } else { $null }

# ── Main ──────────────────────────────────────────────────────────────────────

$passCount = 0; $failCount = 0; $skipCount = 0; $results = @()

Write-Out ""
Write-Out "================================================================" Cyan
Write-Out "  CAD Dispatch Coverage Test -- $Provider ($(Split-Path $jsonFile -Leaf))" Cyan
Write-Out "================================================================" Cyan
Write-Out "  CAD field mapping: $cadFieldPath" DarkGray
Write-Out ""

foreach ($qidm in $commSysQidms) {
    $ent = $qidm.targetEntity
    $cadList = @()
    if ($cadConfig.$ent) { $cadList = @($cadConfig.$ent) }
    $qifIds  = if ($qifFieldsByEntity.ContainsKey($ent)) { $qifFieldsByEntity[$ent] } else { @() }

    Write-Out "--- $($qidm.name) [$ent] ---" Yellow

    foreach ($combo in $qidm.combinations) {
        $kr = if ($combo.keyReference) { $combo.keyReference } else { $combo.keyRef }
        $setFields = @()
        if ($combo.requirements -and $combo.requirements.set) { $setFields = @($combo.requirements.set) }
        $defaults  = @()
        if ($combo.defaults) { $defaults = @($combo.defaults) }

        # ── Step 1: Check CAD-triggerability ────────────────────────────────
        $notCovered = @()
        foreach ($f in $setFields) {
            $fromCad     = Test-IsCadField $f $cadList
            $fromDefault = $defaults | Where-Object { $_.field -eq $f } | Select-Object -First 1
            if (-not $fromCad -and -not $fromDefault) { $notCovered += $f }
        }

        if ($notCovered.Count -gt 0) {
            $skipCount++
            $results += [PSCustomObject]@{ Entity=$ent; Combo=$kr; Result='SKIP'; Reason="set[] field(s) not in CAD list or defaults: $($notCovered -join ', ')"; First='' }
            Write-Out "    [SKIP] $kr  -- not CAD-triggerable: $($notCovered -join ', ')" DarkGray
            continue
        }

        # ── Step 2: Build minimal CAD form state ────────────────────────────
        $formData = @{}

        # CAD fields: only those that appear in this combo's set[] (minimal — avoid triggering others)
        foreach ($f in $setFields) {
            $isCad = Test-IsCadField $f $cadList
            if ($isCad) {
                $qifId = Get-CadFieldId ($f[0].ToString().ToLower() + $f.Substring(1)) $qifIds
                if (-not $qifId) { $qifId = $f }  # fall back to as-is
                $formData[$qifId] = Get-TestValue $qifId
            }
        }

        # Defaults: inject default values so the simulator sees the field as filled
        foreach ($d in $defaults) {
            if (-not $formData.ContainsKey($d.field)) {
                $formData[$d.field] = $d.value
            }
        }

        # ── Step 3: Run combo simulation ────────────────────────────────────
        $filledNames = Get-FilledNamesForQidm $qidm $formData

        $firstFire = $null
        $coFires   = @()

        foreach ($c in $qidm.combinations) {
            $ckr = if ($c.keyReference) { $c.keyReference } else { $c.keyRef }
            $cset = @()
            if ($c.requirements -and $c.requirements.set) { $cset = @($c.requirements.set) }
            $cany = @()
            if ($c.requirements -and $c.requirements.any) { $cany = @($c.requirements.any) }

            $setOk = $true
            foreach ($sf in $cset) { if ($filledNames -notcontains $sf) { $setOk = $false; break } }
            $anyOk = $true
            if ($cset.Count -eq 0 -and $cany.Count -gt 0) {
                $anyOk = ($cany | Where-Object { $filledNames -contains $_ }).Count -gt 0
            }
            $condResult = Test-ComboConditionsCore (Get-ComboConditions $c) $formData

            if ($setOk -and $anyOk -and $condResult.ok) {
                if (-not $firstFire) { $firstFire = $ckr }
                else { $coFires += $ckr }
            }
        }

        # ── Step 4: Evaluate result ──────────────────────────────────────────
        $cadFieldsSent = ($formData.Keys | Sort-Object) -join ', '

        if ($firstFire -eq $kr) {
            $passCount++
            $coNote = if ($coFires.Count -gt 0) { " (co-fires shadowed: $($coFires -join ', '))" } else { "" }
            $results += [PSCustomObject]@{ Entity=$ent; Combo=$kr; Result='PASS'; Reason=$cadFieldsSent; First=$firstFire }
            Write-Out "    [PASS] $kr$coNote" Green
            Write-Out "           CAD sends: $cadFieldsSent" DarkGray
        }
        elseif (-not $firstFire) {
            $failCount++
            $results += [PSCustomObject]@{ Entity=$ent; Combo=$kr; Result='FAIL'; Reason="combo did not fire (set[] fields not resolved in filledNames -- sourceField mismatch?)"; First='(none)' }
            Write-Out "    [FAIL] $kr -- did not fire" Red
            Write-Out "           CAD sends: $cadFieldsSent" DarkGray
            Write-Out "           filledNames: $($filledNames -join ', ')" DarkGray
        }
        else {
            $failCount++
            $results += [PSCustomObject]@{ Entity=$ent; Combo=$kr; Result='FAIL'; Reason="wrong first-match: $firstFire fired instead"; First=$firstFire }
            Write-Out "    [FAIL] $kr -- shadowed by $firstFire" Red
            Write-Out "           CAD sends: $cadFieldsSent" DarkGray
        }
    }

    Write-Out ""
}

# ── Summary ───────────────────────────────────────────────────────────────────

$total = $passCount + $failCount + $skipCount
Write-Out "================================================================" Cyan
Write-Out "  RESULTS: $passCount PASS / $failCount FAIL / $skipCount SKIP  (of $total combos)" $(if ($failCount -gt 0) { 'Red' } else { 'Green' })
Write-Out "================================================================" Cyan
Write-Out ""

if ($skipCount -gt 0) {
    Write-Out "SKIPPED (not CAD-triggerable):" DarkGray
    foreach ($r in ($results | Where-Object { $_.Result -eq 'SKIP' })) {
        Write-Out "  $($r.Entity)/$($r.Combo) -- $($r.Reason)" DarkGray
    }
    Write-Out ""
}

# ── Write output file ─────────────────────────────────────────────────────────

if ($OutFile) {
    $script:outLines | Out-File $OutFile -Encoding utf8 -Force
    Write-Host "  Report written: $OutFile" -ForegroundColor DarkGray
}

if ($failCount -gt 0) { exit 1 }
