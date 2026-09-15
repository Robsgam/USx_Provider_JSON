<#
  build_translate_test.ps1 -- TRANSLATE_TEST.json: does the platform translate a code value on the
  way OUT, so MANY in-state codes can collapse to ONE out-of-state code?

  Rob, 2026-09-15 (NY_NYSPIN_EJUSTICE):
      "in ny they use a custome plate type fo instate and ncic basic plate types for out of state.
       the ny plate codes are numeric ... we would have mulitple ny nistate plate types used on the
       form tranlasted down to 1 ncic code.  we would have this many to one assoication  i want you
       to buil a simple josn that tests only that function before we start prying everything else
       apart."

  THE QUESTION, STATED SO IT CAN BE ANSWERED WRONG: the officer types/picks a NEW YORK plate type
  (numeric, e.g. 16). On an IN-STATE query that value must reach the wire unchanged. On an
  OUT-OF-STATE query it must become the NCIC equivalent (PC) -- and several NY types map to that
  same one NCIC code, so this is MANY-TO-ONE, not a 1:1 code-table swap.

  WHY A TEST RIG AND NOT A BUILD. NY v4.26 is tenant-verified with 65 logs; a build bump archives
  the whole test package. And the capability is UNPROVEN -- so it gets isolated onto a throwaway
  config on a practice tenant, where the answer costs nothing and is about the PLATFORM rather than
  about NY. Rob: "the json would be provider independents only a handlwer test."

  ==== WHAT IS ALREADY KNOWN, SO THE TEST DOES NOT RE-ASK IT ====

  * THERE IS NO CONFIGURABLE MAPPING LAYER ON THE REQUEST PATH. LIMITATION #38 measured the
    resolution path on live wires and names this very field: RegistrationState "Georgia"->GA,
    SexCode "M - Male"->M, **LicensePlateTypeCode "PC - REGULAR..."->PC**. The wire value IS the
    selected attribute's CODE. So "translate PC into 16" has no known mechanism; the only way to
    send 16 is for the control's value to BE 16.
  * IgnoreUserValueRuleHandler is documented as FILTER-ONLY -- "it filters; it cannot SUBSTITUTE
    one value for another" (UNIVERSAL_SEARCH_HANDLERS section 4). Not a candidate.
  * The CommsysGet*CodeRuleHandler family (article/race/sex/state/plate/vehicle) is [UNUSED] with
    NO documented arguments. CommsysGetVehicleCodeRuleHandler's note "(uses articleCategoryCodes)"
    suggests a fixed internal table, not a configurable mapping.
  * CommsysResultAttributeMappingRuleHandler maps raw code -> display value, but it is a RESULT
    handler (response side). Wrong direction.

  So the rig tests the TWO mechanisms that could still plausibly do it, plus a CONTROL:

    M1  COMBO DEFAULT OVERRIDE -- does requirements.defaults[] on a field the officer ALREADY
        FILLED replace that value, or only fill it when empty? If it REPLACES, many-to-one is free
        and needs no new platform capability: the out-of-state combo defaults the plate type to PC
        and every NY code collapses to it. We ship combo defaults on every provider and have NEVER
        measured their override semantics -- audit_wiring_closure only checks a default is
        REACHABLE ("E INERT DEFAULT"), never what it does to a filled value.
    M2  ATTRIBUTE-LEVEL codeTypeProvider DISAGREEING WITH THE CONTROL -- Build-QidmAttribute
        already emits `codeTypeProvider` and SC_SLED ships it on State, but the attribute has
        always AGREED with its form control. Nobody has made them disagree. If the platform
        resolves the outgoing value through the ATTRIBUTE's code provider, that is translation at
        exactly the right layer.
    C   CONTROL -- the same typed value on a no-rule, no-default, no-provider attribute. Proves the
        observation channel works and shows the untranslated value for comparison. Without this,
        "the tag is missing" and "the tag was translated to empty" look identical.

  ==== HOW TO READ THE RESULT -- TWO SUBMITS, ONE IMPORT ====

    Submit A (IN-STATE):      Plate=TEST123, PlateType=16, State BLANK   -> fires XIN
    Submit B (OUT-OF-STATE):  Plate=TEST123, PlateType=16, State=GA      -> fires XOUT

    | tag on the wire         | mechanism | translation WORKS | translation DOES NOT |
    |-------------------------|-----------|-------------------|----------------------|
    | LicensePlateTypeCode    | M1        | PC on submit B    | 16   <- MEASURED, REFUTED |
    | VehicleStyleCode        | M2a       | a mapped value    | 16 (or absent)       |
    | VehicleMakeCode         | M2b       | FORD              | CNST_FORD            |

  ROUND 1 RESULT (2026-09-15, committed evidence): M1 IS REFUTED -- the default said PC and the
  wire said 16. See LIMITATION #43. M2a emitted no tag at all, which was a RIG DEFECT (its target
  field was never in a combination pool), not a platform result.

  ?? M2b IS THE DECISIVE TEST AND IT NEEDS NO BASELINE CONTROL. Rob: "lets assume the 16 is a
  proper code type instead of a fill field.  does that change anything.  can we test iwth any
  otehr code types to see   it doesnt have to be plate types only." It changes the test
  fundamentally: a FREE-TEXT source has no code system to map FROM, so M2a may have been testing
  nothing. VEHICLE_MAKE is the right subject because the untranslated answer is ALREADY MEASURED --
  LIMITATION #38, 16 logs across 4 providers: the officer picks "CNST_FORD - FORD" and the wire
  carries CNST_FORD **even though the CONTROL declares codeTypeProvider=NCIC**. So form-level
  codeTypeProvider is proven NOT to translate; the only untested variable is the same property on
  the ATTRIBUTE, which is what this rig adds. FORD on the wire = translation exists, NY's
  many-to-one is viable, AND the PARKED portfolio-wide #38 becomes fixable. CNST_FORD = code-system
  translation does not exist on the request path, and we stop looking.

  ?? PRECONDITION -- PROVE THE OBSERVATION CHANNEL BEFORE IMPORTING ANYTHING. Run any query on the
  target tenant AS IT STANDS and confirm dex-log shows an outgoing CommSys XML. A practice tenant
  may have no live provider connection, in which case no request is built and this rig cannot
  answer anything. Proving you can SEE the answer costs nothing; building the question first means
  debugging two unknowns at once (the same sequencing argument as usx-deploy Step 0).

  ?? AN IMPORT REPLACES THE BUNDLE SET. practice-robsgambellone currently carries a NOT-OUR-BUILD
  CA_eSUN config (2 bundles, no RMS); importing this removes it. A 2026-09-12 before-snapshot is in
  _versions\tenant_exports\, so it is recoverable.

  -Provider defaults to CA_eSUN because that is what the practice tenant already routes -- the
  provider NAME is what the platform routes on, so a name it does not know may never build a
  request at all. The CONTENT here is a test rig, not a CA_eSUN build.

  Usage:
    tools\build_translate_test.ps1
    tools\build_translate_test.ps1 -Provider CA_eSUN -OutPath providers\TRANSLATE_TEST.json
#>
param(
    [string]$Provider = 'CA_eSUN',
    [string]$OutPath,
    [string]$InStateValue = '16',
    [string]$OutOfStateCode = 'PC'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'tools\_build_layout_helpers.ps1')
. (Join-Path $repoRoot 'tools\_build_rms_bundle.ps1')
. (Join-Path $repoRoot 'tools\_build_provider_helpers.ps1')

if (-not $OutPath) { $OutPath = Join-Path $repoRoot 'providers\TRANSLATE_TEST.json' }

Write-Host ''
Write-Host '===================================================================================='
Write-Host '  BUILD TRANSLATE TEST -- many-to-one outgoing code translation'
Write-Host '===================================================================================='
Write-Host ("  provider (routing name): {0}" -f $Provider)
Write-Host ("  in-state value to type : {0}" -f $InStateValue)
Write-Host ("  out-of-state code      : {0}" -f $OutOfStateCode)

# ---- FORM -------------------------------------------------------------------------------------
# PlateType is a FormInput, NOT a FormSelect, and that is deliberate: no NY numeric plate-type code
# table exists on the platform (Rob 2026-09-15: "the code type we would tranalaste doesn't exsit
# yet"), so a FormSelect would have nothing to bind to and would render EMPTY (LIMITATION #39).
# Free text also makes the test sharper -- the typed value is unambiguous.
# Card/row/field shape is EXACTLY what BuildMultiCardLayout expects: every row carries its own id,
# and each field is an @{ id; node } pair whose node was built with the ROW id as its parentId.
# (Fields are not scriptblocks and MakeLayouts takes ONE positional argument -- both were guessed
# wrong on the first pass and the signatures had to be read.)
# FOUR THINGS THE VALIDATOR CAUGHT ON THE FIRST PASS, all copied from NY's working Vehicle form
# rather than guessed a second time:
#   * maxLength must be a STRING ("10"), not a number -- platform deserialization.
#   * templateColumns must match the row's child count (a 1-field row is @('12'), not @('6','6')).
#   * RegistrationState uses attributeTypeId='STATE' and NO codeTypeCategory. A code-string
#     dropdown there trips AP #11 TWICE: once for the State attribute's codeTypeProvider and again
#     for the RMS Vehicle QIDM's useAttributeId, neither of which can reverse-look-up a code string.
#   * LicensePlateYear is carried AND placed in XOUT's set[] -- it mirrors NY's real RVEHOUT (which
#     mandates Year) and clears the standard-default WARN without creating a DEAD CONTROL, which is
#     what adding it as an unused field would have done.
# ROUND 5 -- MULTIPLE CODE TYPES TRANSLATING IN ONE REQUEST.
# Rob: "make that json so the test shows how the tranaltion will work if we need more thatn one
# code type to wrok with".
# Two DIFFERENT code types are mapped in the same submit, each through its own table:
#   plate type  <- NY_NIBRS / NCIC_LICENSE_PLATE_TYPE  (Rob's new NYTESTPLATE: 16/17/18/19)
#   state       <- STATE / NCIC                        (already proven: GA -> GEORGIA)
# Plus a RAW control on the new table, so "it mapped" and "it did nothing" cannot be confused for
# the code type we have not measured yet. State needs no raw control -- its untranslated value (GA)
# is already on disk from three earlier captures.
$cards = @(
    @{ id = 'CARD_XLATE'; title = 'TRANSLATE TEST -- two code types mapped in ONE request'; rows = @(
        @{ id = 'ROW_X1'; cols = @('6','6'); fields = @(
            @{ id = 'FLD_PLATE'; node = (Inp 'LicensePlateNumber' 'Plate (carrier -- type TEST123)' '10' 'ROW_X1') }
            @{ id = 'FLD_STATE'; node = (Sel 'RegistrationState' 'MAPPED code type 2 -- pick Georgia' @{ attributeTypeId = 'STATE' } 'ROW_X1') }
        )}
        @{ id = 'ROW_X2'; cols = @('6','6'); fields = @(
            @{ id = 'FLD_PTYPE'; node = (Sel 'LicensePlateTypeCode' 'MAPPED code type 1 -- pick 16' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NY_NIBRS' } 'ROW_X2') }
            @{ id = 'FLD_PTRAW'; node = (Sel 'PlateTypeRaw' 'RAW control -- pick the SAME value (16)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NY_NIBRS' } 'ROW_X2') }
        )}
        @{ id = 'ROW_X3'; cols = @('12'); fields = @(
            @{ id = 'FLD_PYEAR'; node = (Inp 'LicensePlateYear' 'Plate Year (convention field -- ignore)' '4' 'ROW_X3') }
        )}
    )}
)
$layouts = MakeLayouts $cards

$vehForm = [PSCustomObject]@{
    name         = 'Vehicle'
    label        = 'Vehicle Query'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
    layout       = $layouts
}

# ROUND 3: ONE code table, TWO controls, TWO tags that PROVABLY serialize, BASELINE AND TEST IN THE
# SAME SUBMIT. The only variable between them is whether the ATTRIBUTE declares codeTypeProvider.
#
# Tag choice is measured, not assumed: across 4 captures on this provider only LicensePlateNumber /
# LicensePlateTypeCode / LicensePlateYear / State / VehicleStyleCode ever serialized, and
# VehicleMakeCode NEVER did. Round 2 routed the test THROUGH VehicleMakeCode and its tag vanished --
# that was the tag, not the mechanism. Both probes now use tags known to come out.
$attrs = @(
    Build-QidmAttribute -Name 'LicensePlateNumber' -Size 10 -SourceField @('LicensePlateNumber')
    Build-QidmAttribute -Name 'LicensePlateYear'   -Size 4  -SourceField @('LicensePlateYear')

    # ---- CODE TYPE 1: plate type, via Rob's provisioned NY table -------------------------------
    # MAPPED. size 20 (not the real 2) on purpose: if the mapped value is longer we must SEE it
    # rather than let truncation hide the result.
    [PSCustomObject]@{
        name        = 'LicensePlateTypeCode'
        rule        = [PSCustomObject]@{ function = 'CommsysResultAttributeMappingRuleHandler' }
        size        = 20
        sourceField = @('LicensePlateTypeCode')
        targetField = 'LicensePlateTypeCode'
        codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'
        codeTypeSource   = 'NY_NIBRS'
        description = 'CODE TYPE 1 MAPPED -- code -> description via NYTESTPLATE.'
    }
    # RAW control for code type 1 -- same table, same pick, NO rule.
    Build-QidmAttribute -Name 'PlateTypeRaw' -Size 20 -SourceField @('PlateTypeRaw') `
        -TargetField 'VehicleStyleCode' `
        -Description 'CODE TYPE 1 RAW -- same NY table, no rule. Expect the CODE.'

    # ---- CODE TYPE 2: state, via the STATE table (already proven GA -> GEORGIA) ----------------
    # codeTypeProvider STAYS: AP #1 requires it on an attributeTypeId control, and without it the
    # platform sends the internal numeric row id. It is the "emit the code" switch, not a mapper.
    [PSCustomObject]@{
        name        = 'State'
        rule        = [PSCustomObject]@{ function = 'CommsysResultAttributeMappingRuleHandler' }
        size        = 20
        sourceField = @('RegistrationState')
        targetField = 'State'
        codeTypeProvider = 'NCIC'
        attributeType    = 'STATE'
        codeTypeSource   = 'NCIC'
        description = 'CODE TYPE 2 MAPPED -- proven GA -> GEORGIA. Confirms two tables map in one request.'
    }
)

# ONE combination -- nothing here depends on routing.
$combos = @(
    Build-QidmCombo -KeyReference 'XLATE' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber') `
        -Any @('RegistrationState','LicensePlateTypeCode','PlateTypeRaw','LicensePlateYear') `
        -State 'In/Out'
)
$qidm = Build-Qidm -ProviderName $Provider -Query 'VehicleRegistrationQuery' -TargetEntity 'Vehicle' `
    -QueryLabel 'Vehicle Registration' -Attributes $attrs -Combinations $combos `
    -Description 'TRANSLATE TEST rig -- NOT a provider build. Tests outgoing many-to-one code translation.'

# ---- BUNDLES ----------------------------------------------------------------------------------
$entities = Build-EntitiesBundle -Configurations @($vehForm) `
    -DefaultOrder @('Vehicle') -CadOrder @('Vehicle') -FrOrder @('Vehicle') `
    -Description 'TRANSLATE_TEST -- entity form (Vehicle only)'

$providerBundle = [PSCustomObject]@{
    description    = ("Provider configuration for {0} v0.1 -- TRANSLATE TEST RIG (not a provider build)" -f $Provider)
    configurations = @(
        (Build-Auth -ProviderName $Provider),
        (Build-Qmf  -ProviderName $Provider),
        (Build-ProviderQrdm -ProviderName $Provider),
        $qidm
    )
    name           = $Provider
    type           = 'BUNDLE'
    provider       = $Provider
}

$rms = Build-RmsBundle -PascalCaseUsxFields

$bundle = [PSCustomObject]@{ bundles = @($entities, $providerBundle, $rms) }

Write-ProviderJson -BundleObject $bundle -OutPath $OutPath -Label 'TRANSLATE_TEST'

Write-Host ''
Write-Host ''
Write-Host '  ---- RUN IT: ROUND 5 -- TWO CODE TYPES, ONE REQUEST ----------------------------'
Write-Host '  1. Import providers\TRANSLATE_TEST.json.'
Write-Host '  2. Fill FOUR fields:  Plate = TEST123'
Write-Host '                        MAPPED code type 2 (State)      -> Georgia'
Write-Host '                        MAPPED code type 1 (Plate Type)  -> 16'
Write-Host '                        RAW control                      -> 16   (the same value)'
Write-Host '  3. Submit, capture, and read FOUR tags:'
Write-Host '       <State>                 code type 2, MAPPED -- expect GEORGIA (already proven)'
Write-Host '       <LicensePlateTypeCode>  code type 1, MAPPED -- expect the DESCRIPTION of code 16'
Write-Host '       <VehicleStyleCode>      code type 1, RAW    -- expect the CODE 16'
Write-Host '       <LicensePlateNumber>    carrier'
Write-Host '  4. Read it:'
Write-Host '       BOTH mapped tags differ from the raw one -> TWO code types translate in ONE'
Write-Host '         request, independently, each through its own table. That is the answer.'
Write-Host '       <LicensePlateTypeCode> = 16 -> the lookup ran but NYTESTPLATE descriptions are'
Write-Host '         still the codes themselves, so there is nothing to translate TO. Fix the TABLE,'
Write-Host '         not the config: set description 16->PC, 17->PC, 18->CO, 19->CO.'
Write-Host '       <LicensePlateTypeCode> absent -> the lookup returned null (doc: null when the'
Write-Host '         code is not found), which still proves it executed.'
Write-Host ''
Write-Host '  ? THE MAPPING LIVES IN THE DESCRIPTION COLUMN. The handler emits the DESCRIPTION, so'
Write-Host '    the table must be built backwards: CODE = the NY code, DESCRIPTION = the code you'
Write-Host '    want on the wire. Many-to-one then falls out -- 16 and 17 both described PC, 18 and'
Write-Host '    19 both described CO.'
Write-Host '===================================================================================='
Write-Host ''
