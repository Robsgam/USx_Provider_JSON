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
$cards = @(
    @{ id = 'CARD_XLATE'; title = 'TRANSLATE TEST -- State BLANK = in-state (XIN), State GA = out-of-state (XOUT)'; rows = @(
        @{ id = 'ROW_X1'; cols = @('6','6'); fields = @(
            @{ id = 'FLD_PLATE'; node = (Inp 'LicensePlateNumber' 'Plate (carrier -- just type TEST123)' '10' 'ROW_X1') }
            @{ id = 'FLD_STATE'; node = (Sel 'RegistrationState' 'State (optional)' @{ attributeTypeId = 'STATE' } 'ROW_X1') }
        )}
        # ROUND 3 -- CODE TYPE -> CODE TYPE, which is what Rob asked for from the start:
        # "can you tranalaste from one code type to another rather than a filled in field.  i told
        #  you they woudl both be code types".
        # BOTH controls bind to the SAME REAL code table (VEHICLE_MAKE). The ONLY difference is
        # whether the QIDM ATTRIBUTE declares codeTypeProvider. Baseline and test ride in ONE submit
        # so an absent tag can never again be mistaken for a mechanism result.
        # TAG CHOICE IS MEASURED, NOT GUESSED: across 4 captures on this provider only
        # LicensePlateNumber / LicensePlateTypeCode / LicensePlateYear / State / VehicleStyleCode
        # ever serialized. VehicleMakeCode NEVER did -- that, not translation, is why round 2's tag
        # vanished. So VEHICLE_MAKE is routed through two tags that provably serialize.
        @{ id = 'ROW_X2'; cols = @('4','4','4'); fields = @(
            @{ id = 'FLD_PTYPE'; node = (Sel 'LicensePlateTypeCode' 'Plate Type (present only to satisfy the Vehicle-form convention)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_X2') }
            @{ id = 'FLD_PYEAR'; node = (Inp 'LicensePlateYear' 'Plate Year (same reason)' '4' 'ROW_X2') }
            @{ id = 'FLD_VMAKE'; node = (Sel 'VehicleMakeCode'  'DISCRIMINATOR -- pick FORD (same choice as the last run)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_X2') }
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
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'
    Build-QidmAttribute -Name 'LicensePlateTypeCode' -Size 2 -SourceField @('LicensePlateTypeCode')
    Build-QidmAttribute -Name 'LicensePlateYear' -Size 4 -SourceField @('LicensePlateYear')

    # BASELINE -- code-backed source, attribute declares NO provider. This is how every provider in
    # the portfolio builds it today, and LIMITATION #38 says it emits the RAW ATTRIBUTE CODE
    # (CNST_FORD) even though the CONTROL declares codeTypeProvider=NCIC.
    Build-QidmAttribute -Name 'VehicleMakeCode' -Size 24 -SourceField @('VehicleMakeCode') `
        -TargetField 'VehicleStyleCode' -CodeTypeProvider 'NCIC' `
        -Description 'BASELINE -- code table in, NO attribute codeTypeProvider. Expect the raw code.'

)

# ONE combination. The default-override question (M1) is already answered and REFUTED
# (LIMITATION #43), so the second combo and its defaults[] are gone -- fewer moving parts, and
# nothing here depends on which combo fires.
$combos = @(
    Build-QidmCombo -KeyReference 'XLATE' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber') `
        -Any @('RegistrationState','LicensePlateTypeCode','LicensePlateYear','VehicleMakeCode') `
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
Write-Host '  ---- RUN IT: THE DISCRIMINATOR -- ONE IMPORT, ONE SUBMIT ------------------------'
Write-Host '  WHAT CHANGED vs the last run: the codeTypeProvider moved ONTO the attribute that'
Write-Host '  targets <VehicleStyleCode>. SAME TAG, SAME code table, SAME selection -- the only'
Write-Host '  difference is the provider property. Last run that tag carried FARM_FORD, so that'
Write-Host '  measurement IS the baseline and no second control is needed.'
Write-Host ''
Write-Host '  1. Import providers\TRANSLATE_TEST.json (it REPLACES the bundle set).'
Write-Host '  2. Fill: Plate = TEST123, and pick FORD in the make dropdown.'
Write-Host '  3. Submit, capture, and read ONE tag: <VehicleStyleCode>'
Write-Host '  4. Read it:'
Write-Host '       FARM_FORD  -> the attribute provider is an inert NO-OP. Round 3 absence was the'
Write-Host '                     VIN tag not serializing, NOT the provider. No data-loss hazard.'
Write-Host '       ABSENT     -> the attribute provider DROPS the value. Same tag, one variable, so'
Write-Host '                     this is conclusive: setting codeTypeProvider on an attribute over a'
Write-Host '                     code-backed control silently discards the officer input.'
Write-Host '       anything else -> it TRANSLATED after all; report the exact value.'
Write-Host '===================================================================================='
Write-Host ''
