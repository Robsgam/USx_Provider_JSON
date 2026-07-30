<#
  _combo_value_resolver.ps1 -- shared combo set[]/any[] test-value resolution.

  Extracted 2026-07-06 from emit_test_plan.ps1 and generate_test_matrix.ps1, whose
  Get-TestValue functions were flagged (2026-07-06) as duplicated but deliberately left
  unmerged pending a careful pass. A full line-by-line diff of the two switch tables found
  ~35 IDENTICAL cases (same regex, same output) plus a real, pre-existing set of behavioral
  differences between the two tools:
    - licensePlateTypeCode / licensePlateYear / imageIndicator: generate_test_matrix prefers
      the QIF field's initialValue (props.default_) when present; emit_test_plan does not
      (it has no field-object context, only a bare fieldId string).
    - registrationState: emit_test_plan also treats a bare "state" fieldId as an alias;
      generate_test_matrix requires the exact "registrationState" name.
    - registrationStateDH: emit_test_plan hardcodes 'NJ'; generate_test_matrix uses the
      field's initialValue.
    - nameMiddle / nameSuffix: emit_test_plan returns $null (its Note-IfUnresolved trust
      check treats this as an intentionally-blank field); generate_test_matrix returns ''.
    - birthDate: emit_test_plan emits ISO yyyy-MM-dd (native <input type=date>);
      generate_test_matrix emits US MM/dd/yyyy (its matrix is a human-read test sheet).
    - randomRequest / gunModel / requestorDH / nyNyspinTransactionNameDH: only
      emit_test_plan has explicit cases (NY-specific test values); generate_test_matrix has
      no case for these (falls through to its generic 'TEST' filler).
    - dexStateUserId: only generate_test_matrix has an explicit case ('BADGE');
      emit_test_plan has no case (falls through to $null, which its trust check flags as
      unmapped -- dexStateUserId is a hidden/handler-fed field in every in-scope provider,
      so this has never actually fired).
    - Unknown/unmatched fieldId: emit_test_plan returns $null (silence -> its own
      Note-IfUnresolved trust check surfaces it loudly); generate_test_matrix returns the
      literal 'TEST' (a human-legible placeholder for its printed test sheet).
  This module does NOT merge those differences away -- it reproduces both tools' exact
  current output via the -Caller parameter, deduplicating only the ~35 provably-identical
  cases and the TEST_VALUE_OVERRIDES.txt loading logic. Verified byte-identical output
  (NY_NYSPIN_EJUSTICE emit_test_plan + generate_test_matrix, FL_FCIC generate_test_matrix)
  before/after this extraction, 2026-07-06.

  Exports:
    Get-ComboValueOverrides -ProviderJsonPath <path>
      Reads docs/reference/TEST_VALUE_OVERRIDES.txt (fieldId=value lines, '#' comments) next
      to the given provider JSON. Returns @{ Overrides = <hashtable>; Path = <string> }.
    Get-ComboTestValue -FieldId <string> -IsOOS <bool> -Caller <EmitTestPlan|GenerateTestMatrix>
                        [-Overrides <hashtable>] [-FieldDefault <string>]
      Resolves a DOM fieldId (case-insensitive) to a synthetic test value, reproducing the
      calling tool's exact pre-extraction behavior (see divergences above).
#>

function Get-ComboValueOverrides {
    param(
        [Parameter(Mandatory)][string]$ProviderJsonPath
    )
    $overrides = @{}
    $ovPath = Join-Path (Split-Path (Resolve-Path $ProviderJsonPath) -Parent) 'docs\reference\TEST_VALUE_OVERRIDES.txt'
    if (Test-Path $ovPath) {
        foreach ($line in Get-Content $ovPath) {
            if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
            $k, $v = $line -split '=', 2
            $overrides[$k.Trim()] = $v.Trim()
        }
    }
    return [PSCustomObject]@{ Overrides = $overrides; Path = $ovPath }
}

function Get-ComboTestValue {
    param(
        [Parameter(Mandatory)][string]$FieldId,
        [Parameter(Mandatory)][bool]$IsOOS,
        [Parameter(Mandatory)][ValidateSet('EmitTestPlan', 'GenerateTestMatrix')][string]$Caller,
        [hashtable]$Overrides = @{},
        [string]$FieldDefault = $null,
        [string]$Entity = $null
    )
    # ENTITY-SCOPED OVERRIDES ('<Entity>.<fieldId>=value') take precedence over the bare
    # 'fieldId=value' form. Added 2026-07-30: some fieldIds are REUSED across entities but need a
    # DIFFERENT valid value per entity, and a bare override cannot express that. NCICNumber is the
    # case that forced it -- Article, Gun and Boat all use the same fieldId, but an NCIC record
    # number is typed by its leading letter per NCIC file, so one value can only ever be valid for
    # one of them. TX sent X123456789 for all three and the provider errored on every NCIC query
    # (Rob, v4.15 sweep); those logs proved the field transmits but not that the query resolves.
    if ($Entity) {
        foreach ($k in $Overrides.Keys) {
            if ($k -ieq "$Entity.$FieldId") { return $Overrides[$k] }
        }
    }
    foreach ($k in $Overrides.Keys) {
        if ($k -ieq $FieldId) { return $Overrides[$k] }
    }

    $isMatrix = ($Caller -eq 'GenerateTestMatrix')

    # ── Divergent cases: each caller's pre-existing, independently-verified behavior.
    # None of these field-name prefixes overlap the shared table below, so branching here
    # first vs. falling through to the switch cannot change which case wins for any fieldId.
    if ($isMatrix) {
        if ($FieldId -match '(?i)^registrationState$') { if ($IsOOS) { return 'GA' }; return $null }
        if ($FieldId -match '(?i)^registrationStateDH') { return $FieldDefault }
        if ($FieldId -match '(?i)^licensePlateTypeCode') { if ($FieldDefault) { return $FieldDefault }; return 'PC' }
        if ($FieldId -match '(?i)^licensePlateYear') { if ($FieldDefault) { return $FieldDefault }; return (Get-Date).Year.ToString() }
        if ($FieldId -match '(?i)^imageIndicator') { if ($FieldDefault) { return $FieldDefault }; return 'N' }
        if ($FieldId -match '(?i)^nameMiddle') { return '' }
        if ($FieldId -match '(?i)^nameSuffix') { return '' }
        if ($FieldId -match '(?i)^birthDate') { return '01/15/1990' }
        if ($FieldId -match '(?i)^dexStateUserId') { return 'BADGE' }
    } else {
        if ($FieldId -match '(?i)^(registrationState|state)$') { if ($IsOOS) { return 'GA' }; return $null }
        if ($FieldId -match '(?i)^registrationStateDH') { return 'NJ' }
        if ($FieldId -match '(?i)^licensePlateTypeCode') { return 'PC' }
        if ($FieldId -match '(?i)^licensePlateYear') { return (Get-Date).Year.ToString() }
        if ($FieldId -match '(?i)^imageIndicator') { return 'N' }
        if ($FieldId -match '(?i)^nameMiddle') { return $null }
        if ($FieldId -match '(?i)^nameSuffix') { return $null }
        if ($FieldId -match '(?i)^birthDate') { return '1990-01-15' }
        if ($FieldId -match '(?i)^randomRequest') { return 'N' }
        if ($FieldId -match '(?i)^gunModel') { return 'TEST' }
        if ($FieldId -match '(?i)^requestorDH') { return 'SGAMBELLONE' }
        if ($FieldId -match '(?i)^nyNyspinTransactionNameDH') { return 'DLIC' }
    }

    # ── CCH-suffixed fields (TX_TLETS_CCH, added 2026-07-15): these must be checked BEFORE
    # the generic patterns below since switch -Regex takes the first match, and a few CCH
    # field names would otherwise collide with an unrelated base-field case intended for a
    # different provider/context (attentionCCH would silently inherit '^attention' -> $null,
    # meant for TX_TLETS main's automated hidden Attention gate-feeder -- CCH's Attention is a
    # plain visible manually-typed field and needs a real value). The rest are genuinely new
    # field names (Requestor/Operator/FreeText/InquiryReason/NletsDestination/etc.) with no
    # prior case at all.
    switch -Regex ($FieldId) {
        '(?i)^attentionCCH'                { return 'SGAMBELLONE' }
        '(?i)^requestorCCH'                { return 'SGAMBELLONE' }
        '(?i)^operatorCCH'                 { return 'SGAMBELLONE' }
        '(?i)^freeTextCCH'                 { return 'TEST FREE TEXT MESSAGE' }
        '(?i)^inquiryReasonCCH'            { return 'TRAFFIC STOP' }
        '(?i)^nletsDestination\d*CCH'      { return 'TX' }
        '(?i)^stateIdNumberCCH'            { return 'TX1234567' }
        '(?i)^fbiNumberCCH'                { return '123456789' }
        '(?i)^miscellaneousNumberCCH'      { return 'MISC123456789' }
        '(?i)^addressCityStateCCH'         { return 'AUSTIN TX' }
        '(?i)^addressStreetCCH'            { return '5805 N LAMAR BLVD' }
        '(?i)^addressZipCodeCCH'           { return '787520000' }
        '(?i)^buildingNameCCH'             { return 'HQ' }
        '(?i)^departmentNameCCH'           { return 'RECORDS' }
        '(?i)^expandedNameSearchIndicatorCCH' { return 'Y' }
        '(?i)^stateCCH'                    { return 'TX' }
        default { break }
    }

    # ── Shared cases: verified identical (same regex, same output) in both tools today ──
    switch -Regex ($FieldId) {
        '(?i)^licensePlateNumber'          { return 'TEST123' }
        '(?i)^vehicleIdentificationNumber' { return '1HGCM82633A123456' }
        '(?i)^vehicleMakeCode'             { return 'CNST_FORD' }
        '(?i)^vehicleYear'                 { return '2023' }
        '(?i)^decalNumber'                 { return 'FL12345678' }
        '(?i)^titleLienInformation'        { return 'ABCD1234' }
        '(?i)^operatorLicenseNumber'       { return 'D999888777' }
        '(?i)^nameLast'                    { return 'DOE' }
        '(?i)^nameFirst'                   { return 'JOHN' }
        '(?i)^addressCity'                 { return 'RENO' }
        '(?i)^addressStreetNumber'         { return '123' }
        '(?i)^sexCode'                     { return 'M' }
        '(?i)^(gun)?serialNumber'          { return 'GUN12345' }
        '(?i)^gunMake'                     { return 'IMI' }
        '(?i)^gunCaliber'                  { return '11' }
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
        '(?i)^gunTypeCode'                 { return 'H' }
        '(?i)^raceCode'                    { return 'W' }
        '(?i)^height$'                     { return '509' }
        '(?i)^addressCounty'               { return 'LA' }
        '(?i)^appsRequestIndicator'        { return 'Y' }
        '(?i)^articleBrand'                { return 'SONY' }
        '(?i)^articleCategory'             { return 'E' }
        '(?i)^(caRequestPurposeCode|purposeCode)' { return 'C' }
        '(?i)^stickerNumber'               { return 'STK1234567' }
        '(?i)^financialResponsibilityType' { return 'Y' }
        '(?i)^regionId'                    { return '0001' }
        '(?i)^reasonCode'                  { return 'C' }
        '(?i)^expandedBirthDateSearchCode' { return 'Y' }
        '(?i)^messageKey'                  { return 'CPL' }
        '(?i)^attention'                   { return $null }
        default {
            if ($isMatrix) { return 'TEST' }
            return $null
        }
    }
}

function Get-ComboToggleValue {
    <#
      Returns a value GUARANTEED distinct from $Default and valid for the field, for use as the
      "toggled" value in an any-field (`_af_`) test -- whose entire purpose is to prove an officer
      CAN change an optional field away from its default and have that change transmit. The base
      combo test already sends the field at its default (via form initialValue / combo defaults[]),
      so a toggle value equal to the default proves nothing (the "hollow toggle" bug: every
      Get-ComboTestValue constant that happens to equal a provider's real default -- imageIndicator
      'N', relatedHitSearchIndicator 'Y', reasonCode/purposeCode 'C', licensePlateTypeCode 'PC',
      licensePlateYear '2026' -- produced a toggle test that re-sent the default; found 2026-07-20
      across 6 providers). Returns $null when no distinct valid value can be safely derived -- the
      caller must then FLAG the test as non-load-bearing rather than emit it silently.

      Derivation order (first match wins):
        1. Per-provider override: TEST_VALUE_OVERRIDES.txt '<fieldId>.toggle=<value>' (escape hatch
           for domain-specific fields; loaded by Get-ComboValueOverrides, same file as base values).
        2. Binary Y/N (keyed off the DEFAULT value, not the field name -- covers every Y/N field:
           imageIndicator, related(Hit)?Search(Hit)?Indicator, randomRequest, appsRequestIndicator,
           expandedBirthDateSearchCode, ...): invert Y<->N.
        3. Picklist-backed select (>=2 scoped tenant options): first option whose leading code
           token != $Default (usx_lib matches ^CODE) -- guaranteed tenant-valid.
        4. Four-digit year (licensePlateYear / $Default ~ ^\d{4}$): $Default - 1.
        5. Known standard code FormInputs with no tenant picklist (purposeCode/purposeCodeDH/
           reasonCode): curated Nlets-standard alternate ('C' -> 'F'); overridable by step 1.
        6. Else $null (caller flags hollow).
    #>
    param(
        [Parameter(Mandatory)][string]$FieldId,
        [string]$Default = $null,
        [string[]]$PicklistOptions = @(),
        [bool]$IsOOS = $false,
        [hashtable]$Overrides = @{}
    )

    # 1. Per-provider toggle override (<fieldId>.toggle=<value>).
    $toggleKey = "$FieldId.toggle"
    foreach ($k in $Overrides.Keys) {
        if ($k -ieq $toggleKey) { return $Overrides[$k] }
    }

    $def = "$Default".Trim()

    # 2. Binary Y/N -- invert against the default (domain inferred from the default value).
    if ($def -ieq 'Y') { return 'N' }
    if ($def -ieq 'N') { return 'Y' }

    # 3. Picklist-backed select -- first scoped option whose leading code token differs.
    if (@($PicklistOptions).Count -ge 2) {
        foreach ($opt in $PicklistOptions) {
            $code = ("$opt" -split '\s')[0]        # usx_lib matches ^CODE; option text is "CODE - Label"
            if ($code -and $code -ine $def) { return $code }
        }
    }

    # 4. Four-digit year.
    if ($FieldId -match '(?i)licensePlateYear' -or $def -match '^\d{4}$') {
        $yr = 0
        if ([int]::TryParse($def, [ref]$yr) -and $yr -gt 1) { return "$($yr - 1)" }
    }

    # 5. Known standard code FormInputs (no tenant picklist). Nlets purpose/reason codes:
    #    'C' (criminal justice) is the near-universal default; 'F' (firearms-related) is a
    #    standard, widely-valid alternate. Overridable via step 1 for any tenant that rejects it.
    if ($FieldId -match '(?i)^(caRequestPurposeCode|purposeCode|reasonCode)') {
        if ($def -ieq 'C') { return 'F' }
        if ($def -and $def -ine 'C') { return 'C' }
    }

    # 6. No distinct valid value derivable -- caller flags as hollow.
    return $null
}
