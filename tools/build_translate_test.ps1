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

  ⚠️ M2b IS THE DECISIVE TEST AND IT NEEDS NO BASELINE CONTROL. Rob: "lets assume the 16 is a
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

  ⚠️ PRECONDITION -- PROVE THE OBSERVATION CHANNEL BEFORE IMPORTING ANYTHING. Run any query on the
  target tenant AS IT STANDS and confirm dex-log shows an outgoing CommSys XML. A practice tenant
  may have no live provider connection, in which case no request is built and this rig cannot
  answer anything. Proving you can SEE the answer costs nothing; building the question first means
  debugging two unknowns at once (the same sequencing argument as usx-deploy Step 0).

  ⚠️ AN IMPORT REPLACES THE BUNDLE SET. practice-robsgambellone currently carries a NOT-OUR-BUILD
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
            @{ id = 'FLD_PLATE'; node = (Inp 'LicensePlateNumber' 'Plate' '10' 'ROW_X1') }
            @{ id = 'FLD_PTYPE'; node = (Inp 'LicensePlateTypeCode' ('Plate Type -- type ' + $InStateValue) '2' 'ROW_X1') }
        )}
        @{ id = 'ROW_X2'; cols = @('6','6'); fields = @(
            @{ id = 'FLD_STATE'; node = (Sel 'RegistrationState' 'State -- BLANK for in-state, GA for out-of-state' @{ attributeTypeId = 'STATE' } 'ROW_X2') }
            @{ id = 'FLD_PYEAR'; node = (Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_X2') }
        )}
        @{ id = 'ROW_X3'; cols = @('6','6'); fields = @(
            @{ id = 'FLD_PXLAT'; node = (Inp 'PlateTypeXlate' ('M2a free-text probe -- type ' + $InStateValue + ' here too') '2' 'ROW_X3') }
            # M2b -- THE GOOD TEST, and it exists because Rob asked "lets assume the 16 is a proper
            # code type instead of a fill field ... it doesnt have to be plate types only".
            # A free-text probe has NO SOURCE CODE SYSTEM to map FROM, so M2a may have been testing
            # nothing. This control is bound to a REAL code table, built EXACTLY as FL_FCIC builds
            # it (attributeTypeId=VEHICLE_MAKE + codeTypeProvider=NCIC on the control).
            # WHY VEHICLE_MAKE IS THE IDEAL SUBJECT: we already KNOW the untranslated answer.
            # LIMITATION #38 measured it on 16 logs across 4 providers -- the officer picks
            # "CNST_FORD - FORD" and the wire carries <VehicleMakeCode>CNST_FORD</VehicleMakeCode>,
            # DESPITE the control declaring codeTypeProvider=NCIC. So FORM-level codeTypeProvider is
            # ALREADY PROVEN NOT TO TRANSLATE. The single untested variable is the same property on
            # the ATTRIBUTE. No baseline control is needed here: those 16 logs ARE the baseline.
            @{ id = 'FLD_VMAKE'; node = (Sel 'VehicleMakeCode' 'M2b code-type probe -- pick any make (e.g. FORD)' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_X3') }
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

# ---- QIDM -------------------------------------------------------------------------------------
# THREE attributes, all reading the SAME typed plate-type value, writing DIFFERENT wire tags, so a
# single request shows raw and candidate-translated values side by side.
$attrs = @(
    Build-QidmAttribute -Name 'LicensePlateNumber' -Size 10 -SourceField @('LicensePlateNumber')
    Build-QidmAttribute -Name 'LicensePlateYear'   -Size 4  -SourceField @('LicensePlateYear')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'

    # CONTROL (C): no rule, no codeTypeProvider. Whatever the officer typed should appear verbatim.
    Build-QidmAttribute -Name 'LicensePlateTypeCode' -Size 2 -SourceField @('LicensePlateTypeCode') `
        -Description 'CONTROL -- no rule, no codeTypeProvider. Shows the raw typed value.'

    # M2: same source value, but the ATTRIBUTE declares an NCIC code provider while the control is
    # free text. Nobody has ever made these disagree.
    #
    # ⚠️ ROUND 1 EMITTED NO TAG FOR THIS AND THAT WAS A RIG DEFECT, NOT A RESULT. An attribute is
    # serialized only when its SOURCEFIELD is in the firing combination's set[]/any[] pool -- and
    # `LicensePlateTypeCode` IS in the pool, yet only ONE tag appeared. Two attributes sharing one
    # sourceField is therefore not sufficient: the platform emitted the attribute whose NAME matches
    # the pooled field and dropped the other. So M2 now reads its OWN dedicated control
    # (`PlateTypeXlate`), which is placed in the pool in its own right. If the tag is still absent
    # after that, the absence is about the MECHANISM rather than about the wiring.
    Build-QidmAttribute -Name 'PlateTypeXlate' -Size 2 -SourceField @('PlateTypeXlate') `
        -TargetField 'VehicleStyleCode' -CodeTypeProvider 'NCIC' `
        -Description 'M2a -- attribute-level codeTypeProvider over a FREE-TEXT source.'

    # M2b -- THE DECISIVE ONE. Same targetField the 16 LIMITATION #38 logs already measured, so the
    # comparison is against a KNOWN value rather than against a second control:
    #   attribute WITHOUT codeTypeProvider (every provider today) -> wire = CNST_FORD
    #   attribute WITH    codeTypeProvider (nobody, ever)         -> wire = ?
    # If this emits FORD, attribute-level resolution translates -- which both answers NY's
    # many-to-one question AND makes LIMITATION #38 (PARKED, portfolio-wide, 21 providers) fixable.
    # If it emits CNST_FORD, code-system translation does not exist on the request path at all and
    # we stop looking.
    Build-QidmAttribute -Name 'VehicleMakeCode' -Size 24 -SourceField @('VehicleMakeCode') `
        -CodeTypeProvider 'NCIC' `
        -Description 'M2b -- attribute-level codeTypeProvider over a REAL code table (VEHICLE_MAKE).'
)

$combos = @(
    # XOUT first: most specific. M1 lives here -- a default on a field the officer ALREADY filled.
    Build-QidmCombo -KeyReference 'XOUT' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber','RegistrationState','LicensePlateTypeCode','LicensePlateYear') `
        -Any @('PlateTypeXlate','VehicleMakeCode') `
        -Defaults @([PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = $OutOfStateCode }) `
        -State 'Out'

    # XIN: in-state. NO default -- this is the raw-passthrough baseline. Gated so it cannot also
    # match an out-of-state fill (the same RegistrationState NOT_EXISTS seam NY already uses).
    Build-QidmCombo -KeyReference 'XIN' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber') -Any @('LicensePlateTypeCode','PlateTypeXlate','VehicleMakeCode') `
        -Conditions @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }) `
        -State 'In'
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
Write-Host '  ---- RUN IT ----------------------------------------------------------------------'
Write-Host '  0. FIRST prove the channel: run any query on the target tenant AS IT STANDS and'
Write-Host '     confirm dex-log shows an outgoing CommSys XML. No XML = this rig cannot answer.'
Write-Host '  1. Import this JSON (it REPLACES the bundle set on that tenant).'
Write-Host ("  2. Submit A in-state : Plate=TEST123, Plate Type={0}, State BLANK  -> XIN" -f $InStateValue)
Write-Host ("  3. Submit B OOS      : Plate=TEST123, Plate Type={0}, State=GA     -> XOUT" -f $InStateValue)
Write-Host '  4. Read the request XML for each and compare these tags:'
Write-Host ("       <LicensePlateTypeCode>  A should be {0}.  B = {1} means M1 (combo default)" -f $InStateValue, $OutOfStateCode)
Write-Host ("                               OVERRIDES a filled value -> many-to-one is FREE." -f $null)
Write-Host ("                               B = {0} means defaults only FILL WHEN EMPTY." -f $InStateValue)
Write-Host '       <VehicleStyleCode>      M2. ABSENT = the field is not valid here (a CONFOUND,'
Write-Host '                               not a result) -- judge it against the control tag.'
Write-Host '===================================================================================='
Write-Host ''
