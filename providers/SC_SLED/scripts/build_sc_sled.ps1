<#
.SYNOPSIS
  Build SC_SLED JSON (single versioned output, multi-card-capable from the start).
.DESCRIPTION
  South Carolina SLED (system version 13). First GROUND-UP provider since the toolchain changed,
  so this script is deliberately written against the CURRENT model rather than copied from a
  sibling: it uses Build-Qidm / Build-QidmAttribute / Build-QidmCombo, which every other provider
  hand-writes as PSCustomObject literals.

  PHASE 1 (this version): QIDM-FIRST. One card per entity, every field, 100% combination coverage.
  Layout refinement is Phase 2 and must not be mixed in -- NJ and NY both conflated QIDM + layout +
  state model early and could not isolate which layer broke.

  SCOPE -- devdoc "Basic Query Transactions" is the authority. Rob's decisions 2026-09-14:
    BUILT (8 here): ArticleSingleQuery, BoatQuery, DriverLicenseQuery, DriverRegistrationQuery,
                    GunQuery, VehicleRegistrationQuery, VehicleStolenQuery, WantedPersonQuery
    AdministrativeMessage -- Rob said BUILD, but it is a free-text message to another agency with no
      entity and no precedent in 20 providers. Deliberately NOT in this version: it needs a design
      decision about what surface it lives on, and guessing would be worse than asking. Tracked as
      owed, not skipped.
    NOT BUILT, available-not-built: CCH (11), WMPI person queries (5), AOS (2). ~40 WMPE
      entry/modify/cancel are record WRITING -- a different product surface, out of scope entirely.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File providers/SC_SLED/scripts/build_sc_sled.ps1
#>

$ErrorActionPreference = 'Stop'
$scriptDir   = Split-Path $MyInvocation.MyCommand.Path -Parent
$providerDir = Split-Path $scriptDir -Parent
$repoRoot    = Split-Path (Split-Path $providerDir -Parent) -Parent

. (Join-Path $repoRoot 'tools\_build_layout_helpers.ps1')
. (Join-Path $repoRoot 'tools\_build_rms_bundle.ps1')
. (Join-Path $repoRoot 'tools\_build_provider_helpers.ps1')

$providerName = 'SC_SLED'
$Version      = '1.0'
$currentYear  = (Get-Date).Year.ToString()

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host " Building $providerName v$Version" -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

# =====================================================================
# STANDING DECISIONS APPLIED HERE, each with the reason it is not a guess
# =====================================================================
#
# State2..State5 -- EXCLUDED. Every SC query that permits State also permits State2..State5 (a
#   multi-state broadcast). Multi-state broadcast is OUT OF SCOPE by standing decision 2026-08-02.
#   These are metadata optionals being deliberately dropped, so they need an ACCEPTED_DIVERGENCES
#   row -- audit_devdoc_optionals will otherwise report them as silently-not-transmitted, and it
#   would be right to.
#
# RegistrationState -- NO initialValue, label hint instead. SC has no in-state/out-of-state keyRef
#   split (both paths carry the same keyRef and state='In/Out'), so State is any[]-only and the
#   decision tree PERMITS a default. Not taking it: defaulting means every query transmits
#   State=SC, which is a WIRE CHANGE I cannot justify before a tenant test, and blank transmits
#   nothing. Matches OR/TN/MD/NM, which all ship a hint and no default. Revisit at Phase 2 with
#   evidence, not before.
#
# ImageIndicator -- initialValue 'Y' + a matching combo defaults[] on every carrying combo (CAD
#   ignores form initialValue). Safe here because ImageIndicator is in NO set[] and no condition,
#   so a prefill cannot collapse a combo onto a plainer sibling -- the AZ_AZDPS DQPN/DQP failure.
#
# Name -- composite, LAST-first (`LAST, FIRST MIDDLE SUFFIX`), sourceField order
#   NameLast/NameFirst/NameMiddle/NameSuffix (PascalCase -- NameFirst and NameLast are CAD tokens;
#   TN_TIES v2.6 and the token list agree). SC metadata declares a single Name field of 30.
#
# FIELD-ID CASING IS PER-FIELD, NOT A BLANKET RULE, and I got it wrong on the first pass. The 22
#   USx CAD tokens are PascalCase; the documented exceptions stay camelCase because CAD populates
#   them that way -- serialNumber, vehicleYear, raceCode, caRequestPurposeCode. So GunSerialNumber
#   is the ATTRIBUTE name while its sourceField is serialNumber (MD_METERS states this outright).
#   Non-token fields are not CAD-populated, so their casing is ours; the metadata name is used.
#
# DUPLICATE keyRefs IN METADATA -- SC reuses one keyRef across the alternatives of a single
#   transaction (VehicleRegistrationQuery declares QVRQ twice, VehicleStolenQuery QV twice,
#   WantedPersonQuery QWA five times, DriverRegistrationQuery DQ twice). A keyRef must be unique
#   per QIDM or the later combo silently overwrites the earlier, so each is given a synthetic
#   suffix. keyRef is platform-internal and the provider routes by field CONTENT, not by keyRef
#   name -- invented keyRefs are proven to work (NY v1.19).
#
# ---- SYNTHETIC keyRef INVENTORY (LIMITATION #21 / #36) -------------------------------------
#   Every multi-combination QIDM below, with the metadata keyRef it splits and the reason.
#   BUILD_RULES Section 15 requires this block; verify_build CHECK 7 reads it.
#
#   VehicleRegistrationQuery  metadata QVRQ x2  ->  QVRQ.P (plate+type+year) · QVRQ.V (VIN)
#   VehicleStolenQuery        metadata QV   x2  ->  QV.P (plate)             · QV.VM (VIN+make)
#   DriverLicenseQuery        DQ + QWDQ, ALREADY DISTINCT IN METADATA -- no suffix invented; the
#                             two combos carry the real keyRefs. Listed here because the QIDM has
#                             >1 combination, not because anything was synthesised.
#   DriverRegistrationQuery   metadata DQ   x2  ->  DQ.RN (DOB+name) · DQ.RO (OLN). NOTE both are
#                             keyRef DQ in metadata, the SAME transaction DriverLicenseQuery's DQ
#                             combo uses -- the split is per-QIDM uniqueness, not a new transaction.
#   WantedPersonQuery         metadata QWA  x5  ->  QWA.NCIC · QWA.OCA · QWA.P · QWA.VM · QWA.N
#   BoatQuery                 metadata QBBQ x1 with a <Choice> nested under <Set> (hull|reg), so
#                             ONE declared combination is TWO real alternatives ->  QBBQ.H · QBBQ.R
#                             This is the LIMITATION #36 Choice-split case, not a duplicate keyRef.
# --------------------------------------------------------------------------------------------

# =====================================================================
# 1. PROVIDER BUNDLE -- AUTH / QMF / QRDM
# =====================================================================
$auth    = Build-Auth -ProviderName $providerName
$qmf     = Build-Qmf -ProviderName $providerName
$results = Build-ProviderQrdm -ProviderName $providerName

# =====================================================================
# 2. VEHICLE -- VehicleRegistrationQuery
#    Metadata: QVRQ Plate+PlateType+PlateYear [State..5] | QVRQ VIN [State..5, Make, Year]
#    Synthetic keyRefs QVRQ.P / QVRQ.V (metadata declares QVRQ for both).
# =====================================================================
$vehRegAttrs = @(
    Build-QidmAttribute -Name 'LicensePlateNumber'          -Size 10 -SourceField @('LicensePlateNumber')
    Build-QidmAttribute -Name 'LicensePlateTypeCode'        -Size 2  -SourceField @('LicensePlateTypeCode')
    Build-QidmAttribute -Name 'LicensePlateYear'            -Size 4  -SourceField @('LicensePlateYear')
    Build-QidmAttribute -Name 'VehicleIdentificationNumber' -Size 20 -SourceField @('VehicleIdentificationNumber')
    Build-QidmAttribute -Name 'VehicleMakeCode'             -Size 4  -SourceField @('VehicleMakeCode')
    Build-QidmAttribute -Name 'VehicleYear'                 -Size 4  -SourceField @('vehicleYear')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'
)
$vehRegCombos = @(
    # Plate path FIRST -- 3 mandatory fields, the most specific.
    Build-QidmCombo -KeyReference 'QVRQ.P' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear') `
        -Any @('RegistrationState') `
        -Defaults @(
            [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
            [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
        )
    # VIN path. Plate>VIN identifier priority: refuse to fire when a plate was supplied, so an
    # over-filled form runs the plate query rather than both.
    Build-QidmCombo -KeyReference 'QVRQ.V' -PrimaryFieldReference 'VehicleIdentificationNumber' `
        -Set @('VehicleIdentificationNumber') `
        -Any @('RegistrationState','VehicleMakeCode','vehicleYear') `
        -Conditions @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
)
$vehRegQuery = Build-Qidm -ProviderName $providerName -Query 'VehicleRegistrationQuery' `
    -TargetEntity 'Vehicle' -QueryLabel 'Vehicle Registration' `
    -Attributes $vehRegAttrs -Combinations $vehRegCombos `
    -Description 'VehicleRegistrationQuery -- QVRQ.P (plate + type + year), QVRQ.V (VIN). Synthetic suffixes: metadata declares QVRQ for both alternatives. Plate>VIN guardrail on the VIN path. State2-State5 deliberately not built (multi-state broadcast out of scope).'

# =====================================================================
# 3. VEHICLE -- VehicleStolenQuery
#    Metadata: QV Plate [VIN, State, Make] | QV VIN+Make
#    Rob 2026-09-14 chose to BUILD this, against the NJ precedent: SC's devdoc lists
#    "NCIC (QA, QB, QG, QV, QW) ... returned from Data mining", and QV is this query, so the state
#    may already run it. His call, recorded here rather than argued.
#    MEASURED 2026-09-14 (Rob: "build both and we can sort it out ... i think they each have a
#    shadow of the other"). He is right that each masks the other, but the MECHANISM is CO-FIRE,
#    not shadowing -- shadowing only happens WITHIN one QIDM's combination array, and these are
#    two QIDMs. QV.P set[Plate] vs QVRQ.P set[Plate,PlateType,PlateYear]: PlateType='PC' and
#    PlateYear are FORM-PREFILLED, so QVRQ.P's effective set collapses to an always-present
#    [Plate] -- EXACTLY EQUAL to QV.P. That is the AZ_AZDPS DQPN/DQP exact-collision shape, which
#    ordering cannot separate. test_commsys confirms: one plate entry fires QVRQ.P AND QV.P; one
#    VIN fires QVRQ.V AND QV.VM. Since QVRQ IS "SC Vehicle Stolen/Reg Inquiry" (its own MessageKey
#    description), the stolen check goes out TWICE. Dropping QV would lose NO field.
#
#    ⚠️ MASKING STOLEN IS NOT AVAILABLE AS AN OBVIOUS FIX -- both mechanisms are disqualified TODAY:
#      (a) queriesToDeselect alone is PROVEN NOT TO WORK for this shape. NY_NYSPIN v2.8 live-tested
#          it: the LOWER-threshold query sent twice and the higher-threshold one zero times, because
#          deselect only unchecks a box in the UI and cannot recall a queued send. QV.P is the
#          lower-threshold query here (1 mandatory field vs 3), so it is the one that would send.
#      (b) autoSelect=$false is the prescribed fix and has ZERO TENANT-PROVEN CARRIERS. Measured:
#          the only live ones in the portfolio are TX_TLETS_CCH's 8 CCH queries, and that provider
#          is PARKED and NEVER tenant-tested. The one tenant-OBSERVED outcome of the flag is the
#          CA_eSUN v3.0-v3.2 failure, where the platform rendered the checkbox and never ACTIVATED
#          it, so Send stayed DISABLED and 13 of 13 DH tests could not send.
#    So the first SC_SLED import is the DISCRIMINATING TEST, and SC_SLED is the right subject
#    precisely because it has never been tested -- nothing tuned is at risk. Until then: BOTH
#    BUILT, both autoSelect=$true, no deselect. Do not "fix" this from the rule alone.
#
#    SC_SLED is also the ONLY provider in the portfolio that builds a standalone VehicleStolenQuery
#    (FL_FCIC, HI_HCJDC_OFML and NJ_NJCJIS each removed theirs; MD_METERS never had one), so there
#    is no working example to copy and no precedent to appeal to in either direction.
# =====================================================================
$vehStolenAttrs = @(
    Build-QidmAttribute -Name 'LicensePlateNumber'          -Size 10 -SourceField @('LicensePlateNumber')
    Build-QidmAttribute -Name 'VehicleIdentificationNumber' -Size 20 -SourceField @('VehicleIdentificationNumber')
    Build-QidmAttribute -Name 'VehicleMakeCode'             -Size 4  -SourceField @('VehicleMakeCode')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'
)
$vehStolenCombos = @(
    # VIN+Make first -- 2 mandatory fields. Plate>VIN priority still applies.
    Build-QidmCombo -KeyReference 'QV.VM' -PrimaryFieldReference 'VehicleIdentificationNumber' `
        -Set @('VehicleIdentificationNumber','VehicleMakeCode') `
        -Conditions @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
    Build-QidmCombo -KeyReference 'QV.P' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber') `
        -Any @('VehicleIdentificationNumber','RegistrationState','VehicleMakeCode')
)
$vehStolenQuery = Build-Qidm -ProviderName $providerName -Query 'VehicleStolenQuery' `
    -TargetEntity 'Vehicle' -QueryLabel 'Vehicle Stolen' `
    -Attributes $vehStolenAttrs -Combinations $vehStolenCombos `
    -Description 'VehicleStolenQuery -- QV.VM (VIN + make), QV.P (plate). Synthetic suffixes: metadata declares QV for both. BUILT BY ROB DECISION 2026-09-14 despite the devdoc listing QV among the data-mined NCIC transactions.'

# =====================================================================
# 4. PERSON -- DriverLicenseQuery
#    Metadata: DQ OLN [Image, State..5] | QWDQ Sex+DOB+Name [OLN, State..5]
#    These two keyRefs are DISTINCT in metadata, so no synthetic suffix is needed.
#
#    MEASURED 2026-09-14 -- the Person side behaves DIFFERENTLY from Vehicle, so do not reason
#    about them together:
#      * WITHIN this QIDM there IS a real shadow, and it is ONE-DIRECTIONAL, not mutual.
#        test_commsys on a Name+Sex+DOB+OLN fill: "[FIRES first-match] QWDQ" then
#        "[FIRES shadowed -- first match above wins] DQ". DQ is NOT dead -- on an OLN-ONLY fill
#        QWDQ's set cannot be satisfied, so DQ is the only thing that can fire. Both reachable.
#      * ACROSS QIDMs, QWDQ CO-FIRES with WantedPersonQuery's QWA.N: QWA.N needs only
#        set[NameLast,NameFirst] and shares this card's UNSUFFIXED field pool, so a Name+Sex+DOB
#        fill satisfies both. QWDQ is "SC Driver Wanted/Reg Inquiry" (its MessageKey description),
#        so the WANTED check goes out twice. Gating QWA.N out would reproduce the TN_TIES KQ.N
#        defect -- it kills the plain name-wanted search, which is the only way to run one.
#      * DriverRegistrationQuery does NOT interact with this card at all: its fieldIds are
#        DR-suffixed, so it is a separate pool and test_commsys shows it not firing from here.
#        But its OLN branch is an AUTHORITY-LEVEL DUPLICATE of this QIDM's DQ combo -- the metadata
#        keys BOTH DriverRegistrationQuery combinations 'DQ', and its OLN variant's <Requirements>
#        are IDENTICAL to this one's (Set[OperatorLicenseNumber], Any[ImageIndicator,State..5]).
#        The only thing DriverRegistrationQuery adds is the DQ NAME path. Cards stay separate by
#        Rob's call 2026-09-14 ("keep the cards separate for now").
#      * SexCode ON DriverRegistrationQuery IS OPTIONAL AND THE AUTHORITIES DISAGREE -- metadata
#        wins, so it stays in any[]. The DEVDOC lists DriverRegistrationQuery #1 as
#        mand=[BirthDate, Name, SexCode]; the METADATA <Requirements> for that DQ variant reads
#        Set[BirthDate, Name] with SexCode inside <Any>. Metadata is FIELD authority (usx-build
#        Step 3), and the distinction is deliberate rather than a slip: the SAME XML makes SexCode
#        MANDATORY on QWDQ (Set[SexCode, BirthDate, Name]) and optional here, so SC is separating
#        the compound wanted/reg inquiry from the plain registration one. Promoting it to set[]
#        would block a legitimate name+DOB registration search. audit_devdoc_combinations reports
#        this as a [NOTE] for human check -- that note is EXPECTED and is NOT to be silenced with a
#        registry row: an existence-class rule would suppress the whole keyRef comparison in
#        audit_requirement_fidelity, costing coverage and buying nothing.
#      * AN OLN-ONLY SEARCH GETS NO WANTED CHECK, AND THAT IS SC'S DESIGN, NOT A DEFECT HERE.
#        QWDQ requires the full Name+Sex+BirthDate triple and QWA defines NO OLN-mandatory branch
#        (OLN is an optional on QWA{Name} only), so no metadata-sanctioned combination can run a
#        wanted check off a licence number alone. Building one would invent a variant.
# =====================================================================
$dlAttrs = @(
    Build-QidmAttribute -Name 'OperatorLicenseNumber' -Size 20 -SourceField @('OperatorLicenseNumber')
    Build-QidmAttribute -Name 'Name' -Size 30 -SourceField @('NameLast','NameFirst','NameMiddle','NameSuffix') `
        -Rule ([PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') })
    Build-QidmAttribute -Name 'BirthDate' -Size 8 -SourceField @('BirthDate') `
        -Rule ([PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') })
    Build-QidmAttribute -Name 'SexCode' -Size 1 -SourceField @('SexCode') -CodeTypeProvider 'NIBRS'
    Build-QidmAttribute -Name 'ImageIndicator' -Size 1 -SourceField @('ImageIndicator')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'
)
$dlCombos = @(
    # Name path first -- 3 mandatory fields.
    Build-QidmCombo -KeyReference 'QWDQ' -PrimaryFieldReference 'Name' `
        -Set @('SexCode','BirthDate','NameLast','NameFirst') `
        -Any @('OperatorLicenseNumber','RegistrationState') `
        # NO ImageIndicator default: metadata gives ImageIndicator to the OLN path (DQ) and NOT to
        # this name path (QWDQ), so a default here would be INERT -- audit_wiring_closure class E.
        # A SC name search cannot request an image; only an OLN lookup can.
    # OLN path. OLN>Name identifier priority is the usual rule, but here the NAME combo requires
    # THREE fields and the OLN combo ONE, so name is the more specific and is ordered first; the
    # guardrail that matters is the reverse -- an OLN-only fill must not be captured by the name
    # combo, which it cannot be, because Name/Sex/DOB would be absent.
    Build-QidmCombo -KeyReference 'DQ' -PrimaryFieldReference 'OperatorLicenseNumber' `
        -Set @('OperatorLicenseNumber') `
        -Any @('ImageIndicator','RegistrationState') `
        -Defaults @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
)
$dlQuery = Build-Qidm -ProviderName $providerName -Query 'DriverLicenseQuery' `
    -TargetEntity 'Person' -QueryLabel 'Driver License' `
    -Attributes $dlAttrs -Combinations $dlCombos `
    -Description 'DriverLicenseQuery -- QWDQ (name + sex + DOB), DQ (OLN). Both keyRefs are declared distinctly in metadata. State2-State5 deliberately not built.'

# =====================================================================
# 5. PERSON -- DriverRegistrationQuery  (ISOLATED from DriverLicenseQuery)
#    Metadata: DQ DOB+Name [State..5, Sex] | DQ OLN [Image, State..5]
#
#    ⚠️ THIS IS THE PROVIDER'S REAL DESIGN PROBLEM. DriverLicenseQuery and
#    DriverRegistrationQuery EACH declare a combo with keyReference DQ and an IDENTICAL mandatory
#    set of [OperatorLicenseNumber]. An exact set[] collision cannot be separated by ordering --
#    AZ_AZDPS killed DQPN and DQP exactly that way. Two fixes are applied together:
#      1. SYNTHETIC keyRefs DQ.RN / DQ.RO, because DQ is also duplicated WITHIN this transaction.
#      2. DR-SUFFIXED fieldIds, so this query reads its own controls and cannot be triggered by the
#         Driver License card. This is the proven DL+DH isolation pattern.
#    Rob chose to build both (2026-09-14): both are devdoc-Basic, so skipping one needed approval
#    anyway, and they return different records (licence vs registration).
#
#    ONE-DIRECTIONAL queriesToDeselect: the opt-in query deselects the default, never both ways --
#    mutual queriesToDeselect deadlocks into an error popup.
# =====================================================================
$drAttrs = @(
    Build-QidmAttribute -Name 'OperatorLicenseNumber' -Size 20 -SourceField @('OperatorLicenseNumberDR')
    Build-QidmAttribute -Name 'Name' -Size 30 -SourceField @('NameLastDR','NameFirstDR','NameMiddleDR','NameSuffixDR') `
        -Rule ([PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') })
    Build-QidmAttribute -Name 'BirthDate' -Size 8 -SourceField @('BirthDateDR') `
        -Rule ([PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') })
    Build-QidmAttribute -Name 'SexCode' -Size 1 -SourceField @('SexCodeDR') -CodeTypeProvider 'NIBRS'
    Build-QidmAttribute -Name 'ImageIndicator' -Size 1 -SourceField @('ImageIndicatorDR')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationStateDR') -TargetField 'State' -CodeTypeProvider 'NCIC'
)
$drCombos = @(
    Build-QidmCombo -KeyReference 'DQ.RN' -PrimaryFieldReference 'Name' `
        -Set @('BirthDateDR','NameLastDR','NameFirstDR') `
        -Any @('RegistrationStateDR','SexCodeDR') `
        # NO ImageIndicator default -- same metadata asymmetry as DriverLicenseQuery's name path.
    Build-QidmCombo -KeyReference 'DQ.RO' -PrimaryFieldReference 'OperatorLicenseNumber' `
        -Set @('OperatorLicenseNumberDR') `
        -Any @('ImageIndicatorDR','RegistrationStateDR') `
        -Defaults @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
)
$drQuery = Build-Qidm -ProviderName $providerName -Query 'DriverRegistrationQuery' `
    -TargetEntity 'Person' -QueryLabel 'Driver Registration' `
    -Attributes $drAttrs -Combinations $drCombos `
    -QueriesToDeselect @('DriverLicenseQuery') `
    -Description 'DriverRegistrationQuery -- DQ.RN (name + DOB), DQ.RO (OLN). ISOLATED from DriverLicenseQuery with DR-suffixed fieldIds AND synthetic keyRefs: metadata gives BOTH transactions a keyRef of DQ, and their OLN combos have IDENTICAL mandatory sets, which ordering cannot separate. Note SexCode is OPTIONAL here and MANDATORY on the DriverLicense name combo -- the devdoc lists it as mandatory for both; metadata is field authority.'

# =====================================================================
# 6. PERSON -- WantedPersonQuery
#    Metadata: QWA x5 -- Name | Plate+PlateState | VIN+Make | Name+OCA | NCICNumber
#    All five declare keyRef QWA, so all five get synthetic suffixes.
#    CROSS-ENTITY: two combos search by vehicle identifiers on the PERSON entity, so the Person
#    form carries plate/VIN controls. Same shape as CA_CLETS carrying Name on Vehicle/Gun/Boat.
# =====================================================================
$wpAttrs = @(
    Build-QidmAttribute -Name 'Name' -Size 30 -SourceField @('NameLast','NameFirst','NameMiddle','NameSuffix') `
        -Rule ([PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') })
    Build-QidmAttribute -Name 'BirthDate' -Size 8 -SourceField @('BirthDate') `
        -Rule ([PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') })
    Build-QidmAttribute -Name 'SexCode' -Size 1 -SourceField @('SexCode') -CodeTypeProvider 'NIBRS'
    Build-QidmAttribute -Name 'RaceCode' -Size 1 -SourceField @('raceCode') -CodeTypeProvider 'NIBRS'
    Build-QidmAttribute -Name 'OperatorLicenseNumber'       -Size 20 -SourceField @('OperatorLicenseNumber')
    Build-QidmAttribute -Name 'SocialSecurityNumber'        -Size 9  -SourceField @('SocialSecurityNumber')
    Build-QidmAttribute -Name 'FBINumber'                   -Size 9  -SourceField @('FBINumber')
    Build-QidmAttribute -Name 'MiscellaneousNumber'         -Size 15 -SourceField @('MiscellaneousNumber')
    Build-QidmAttribute -Name 'NCICNumber'                  -Size 10 -SourceField @('NCICNumber')
    Build-QidmAttribute -Name 'OriginatingAgencyCaseNumber' -Size 20 -SourceField @('OriginatingAgencyCaseNumber')
    Build-QidmAttribute -Name 'LicensePlateNumber'          -Size 10 -SourceField @('LicensePlateNumber')
    Build-QidmAttribute -Name 'LicensePlateStateCode'       -Size 2  -SourceField @('LicensePlateStateCode') -CodeTypeProvider 'NCIC'
    Build-QidmAttribute -Name 'VehicleIdentificationNumber' -Size 20 -SourceField @('VehicleIdentificationNumber')
    Build-QidmAttribute -Name 'VehicleMakeCode'             -Size 24 -SourceField @('VehicleMakeCode')
    Build-QidmAttribute -Name 'ImageIndicator'              -Size 1  -SourceField @('ImageIndicator')
    Build-QidmAttribute -Name 'ExpandedNameSearchCode'      -Size 1  -SourceField @('ExpandedNameSearchCode')
    Build-QidmAttribute -Name 'ExpandedBirthDateSearchCode' -Size 1  -SourceField @('ExpandedBirthDateSearchCode')
    Build-QidmAttribute -Name 'RelatedHitSearchIndicator'   -Size 1  -SourceField @('RelatedHitSearchIndicator')
)
$imgDefault = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
$wpCombos = @(
    # Ordered most-specific first. Identifier priority: NCIC number and OCA are unique handles, so
    # they precede the broad name search; the vehicle paths precede name for the same reason.
    Build-QidmCombo -KeyReference 'QWA.NCIC' -PrimaryFieldReference 'NCICNumber' `
        -Set @('NCICNumber') -Any @('ImageIndicator','RelatedHitSearchIndicator') -Defaults $imgDefault
    Build-QidmCombo -KeyReference 'QWA.OCA' -PrimaryFieldReference 'OriginatingAgencyCaseNumber' `
        -Set @('NameLast','NameFirst','OriginatingAgencyCaseNumber') `
        -Any @('ExpandedNameSearchCode','ImageIndicator','RelatedHitSearchIndicator') -Defaults $imgDefault
    Build-QidmCombo -KeyReference 'QWA.P' -PrimaryFieldReference 'LicensePlateNumber' `
        -Set @('LicensePlateNumber','LicensePlateStateCode') `
        -Any @('VehicleIdentificationNumber','VehicleMakeCode','ImageIndicator','RelatedHitSearchIndicator') -Defaults $imgDefault
    # NO `LicensePlateNumber NOT_EXISTS` GATE HERE, DELIBERATELY (fixed 2026-09-14).
    # It was here as a Plate>VIN guardrail while LicensePlateNumber also sat in this combo's any[],
    # which verify_build correctly called DEAD CONFIG -- the condition can never be satisfied at the
    # same time as the optional it contradicts, and it poisons the test conductor.
    # BOTH obvious repairs were considered and the other one is WORSE: keeping the gate and dropping
    # plate from any[] creates a DEAD ZONE -- a VIN+Make+Plate fill with NO plate state matches
    # QWA.P (needs state), does not match QWA.VM (plate exists), and has no name for QWA.N, so
    # NOTHING fires. That is the TN_TIES KQ.N defect shape.
    # The guardrail does not need a condition: QWA.P is ORDERED AHEAD of this combo, so a full
    # plate+state fill takes the plate path by first-match. Ordering is the mechanism, conditions
    # are not (usx-build Step 2). Metadata backs the any[]: QWA{VIN,Make}'s <Any> holds a nested
    # <Set>[LicensePlateNumber, LicensePlateStateCode], so plate IS a defined optional here.
    Build-QidmCombo -KeyReference 'QWA.VM' -PrimaryFieldReference 'VehicleIdentificationNumber' `
        -Set @('VehicleIdentificationNumber','VehicleMakeCode') `
        -Any @('LicensePlateNumber','LicensePlateStateCode','ImageIndicator','RelatedHitSearchIndicator') -Defaults $imgDefault
    Build-QidmCombo -KeyReference 'QWA.N' -PrimaryFieldReference 'Name' `
        -Set @('NameLast','NameFirst') `
        -Any @('BirthDate','SexCode','raceCode','FBINumber','MiscellaneousNumber','OperatorLicenseNumber',
               'SocialSecurityNumber','ImageIndicator','ExpandedBirthDateSearchCode','ExpandedNameSearchCode',
               'RelatedHitSearchIndicator') `
        -Conditions @(
            [PSCustomObject]@{ field = @('NCICNumber');                  operator = 'NOT_EXISTS' }
            [PSCustomObject]@{ field = @('OriginatingAgencyCaseNumber'); operator = 'NOT_EXISTS' }
        ) -Defaults $imgDefault
)
$wpQuery = Build-Qidm -ProviderName $providerName -Query 'WantedPersonQuery' `
    -TargetEntity 'Person' -QueryLabel 'Wanted Person' `
    -Attributes $wpAttrs -Combinations $wpCombos `
    -Description 'WantedPersonQuery -- QWA.NCIC, QWA.OCA, QWA.P, QWA.VM, QWA.N. All five alternatives declare keyRef QWA in metadata, so all five carry synthetic suffixes. Cross-entity: two combos search by vehicle identifiers on the Person entity. Identifier-priority guardrails keep the broad name search behind the unique handles.'

# =====================================================================
# 7. FIREARM -- GunQuery       Metadata: QG GunSerialNumber [Make, Model, Caliber]
# =====================================================================
$gunAttrs = @(
    Build-QidmAttribute -Name 'GunSerialNumber' -Size 11 -SourceField @('serialNumber')
    Build-QidmAttribute -Name 'GunMake'    -Size 3 -SourceField @('GunMake')
    Build-QidmAttribute -Name 'GunModel'   -Size 4 -SourceField @('GunModel')
    Build-QidmAttribute -Name 'GunCaliber' -Size 4 -SourceField @('GunCaliber')
)
$gunCombos = @(
    Build-QidmCombo -KeyReference 'QG' -PrimaryFieldReference 'GunSerialNumber' `
        -Set @('serialNumber') -Any @('GunMake','GunModel','GunCaliber')
)
$gunQuery = Build-Qidm -ProviderName $providerName -Query 'GunQuery' `
    -TargetEntity 'Firearm' -QueryLabel 'Firearm' `
    -Attributes $gunAttrs -Combinations $gunCombos `
    -Description 'GunQuery -- QG (serial number, with make/model/caliber optional). Single metadata combination.'

# =====================================================================
# 8. ARTICLE -- ArticleSingleQuery
#    Metadata: QA set[ArticleTypeCode + ArticleSerialNumber] -- BOTH mandatory, no optionals.
# =====================================================================
$artAttrs = @(
    Build-QidmAttribute -Name 'ArticleSerialNumber' -Size 20 -SourceField @('ArticleSerialNumber')
    Build-QidmAttribute -Name 'ArticleTypeCode'     -Size 7  -SourceField @('ArticleTypeCode')
)
$artCombos = @(
    Build-QidmCombo -KeyReference 'QA' -PrimaryFieldReference 'ArticleSerialNumber' `
        -Set @('ArticleSerialNumber','ArticleTypeCode')
)
$artQuery = Build-Qidm -ProviderName $providerName -Query 'ArticleSingleQuery' `
    -TargetEntity 'Article' -QueryLabel 'Article' `
    -Attributes $artAttrs -Combinations $artCombos `
    -Description 'ArticleSingleQuery -- QA. BOTH serial number and type code are mandatory in metadata, and there are no optionals, so the officer must supply both.'

# =====================================================================
# 9. BOAT -- BoatQuery
#    ⚠️ THE ONE <Choice> IN THE ENTIRE SC_SLED METADATA, and it matters: the requirement is
#    Hull OR RegistrationNumber, expressed as a Choice nested directly under Set. The generated
#    METADATA_REFERENCE.txt shows this combination with an EMPTY Set column -- reading that file
#    alone would produce a Boat query with no requirements at all. The raw XML (the sanctioned
#    exception) and _metadata_parse's Get-MetaAltSets both expand it to the two alternatives the
#    devdoc lists. Recorded as a finding against extract_metadata_reference, not worked around
#    silently.
#    Synthetic keyRefs QBBQ.H / QBBQ.R; metadata declares QBBQ once for both branches.
# =====================================================================
$boatAttrs = @(
    Build-QidmAttribute -Name 'BoatHullSerialNumber' -Size 20 -SourceField @('BoatHullIdNumber')
    Build-QidmAttribute -Name 'RegistrationNumber'   -Size 8  -SourceField @('RegistrationNumber')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'
)
$boatCombos = @(
    # Hull>Registration identifier priority: hull is the unique handle.
    # RegistrationNumber is DELIBERATELY NOT in this combo's any[]. The metadata puts Hull and
    # RegistrationNumber in a <Choice> nested directly under <Set>, so reg is the OTHER MANDATORY
    # ALTERNATIVE, not an optional on the hull branch -- that branch's own <Any> holds State alone.
    # Carrying it made audit_requirement_fidelity report OVER-PERMITTED (2026-09-14): on a hull+reg
    # fill QBBQ.H wins on identifier priority and would have transmitted a field this branch does
    # not define. Discarding the reg value is the CORRECT behaviour here, not a dropped optional.
    Build-QidmCombo -KeyReference 'QBBQ.H' -PrimaryFieldReference 'BoatHullSerialNumber' `
        -Set @('BoatHullIdNumber') -Any @('RegistrationState')
    Build-QidmCombo -KeyReference 'QBBQ.R' -PrimaryFieldReference 'RegistrationNumber' `
        -Set @('RegistrationNumber') -Any @('RegistrationState') `
        -Conditions @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
)
$boatQuery = Build-Qidm -ProviderName $providerName -Query 'BoatQuery' `
    -TargetEntity 'Boat' -QueryLabel 'Boat' `
    -Attributes $boatAttrs -Combinations $boatCombos `
    -Description 'BoatQuery -- QBBQ.H (hull), QBBQ.R (registration number). The metadata expresses Hull OR Registration as a Choice nested under Set, which METADATA_REFERENCE.txt renders as an EMPTY required set; both branches come from the raw XML. Hull>Registration guardrail on the registration path.'

# =====================================================================
# 10. AdministrativeMessage -- ROB'S CALL 2026-09-14: "make it its card at the end. we can alwasy
#     remove it later." Devdoc-Basic, and the only transaction here that is NOT a search: an officer
#     sends free text to up to five destination ORIs.
#
#     ⚠️ STATUS: HYPOTHESIS -- THIS IS THE FIRST NON-ENTITY SURFACE IN THE PORTFOLIO.
#     The platform's documented entity set is Person/Vehicle/Firearm/Article/Boat, and CLAUDE.md
#     states the ENTITIES `order` array must use targetEntity values. Nothing in OUR tooling forbids
#     a sixth: validate.ps1 only requires targetEntity to be PRESENT, and Build-EntitiesBundle takes
#     the order as a string array. Whether the PLATFORM renders an unknown entity is unverified.
#
#     THE BLAST RADIUS IS THE REAL QUESTION, not whether AM appears. AZ v2.0 proved the order array
#     is load-bearing -- forms do not render when ENTITIES is not first -- so an unknown member could
#     in principle break the five that matter. That is why it goes LAST in every order array: if the
#     platform truncates or ignores from the unknown entry onward, the five known entities have
#     already been placed.
#
#     DISCRIMINATING TEST (do this on the FIRST import, before any query testing):
#       1. Do Vehicle/Person/Firearm/Article/Boat still render, in that order? <- the one that matters
#       2. Does an AdministrativeMessage form appear at the end?
#     If 1 fails, remove AM from the order arrays (Rob: "we can always remove it later") and re-import.
#     Do NOT record this as working until both are observed.
# =====================================================================
$amAttrs = @(
    Build-QidmAttribute -Name 'FreeText'         -Size 501 -SourceField @('FreeText')
    Build-QidmAttribute -Name 'DestinationCode'  -Size 9   -SourceField @('DestinationCode')
    Build-QidmAttribute -Name 'DestinationCode2' -Size 9   -SourceField @('DestinationCode2')
    Build-QidmAttribute -Name 'DestinationCode3' -Size 9   -SourceField @('DestinationCode3')
    Build-QidmAttribute -Name 'DestinationCode4' -Size 9   -SourceField @('DestinationCode4')
    Build-QidmAttribute -Name 'DestinationCode5' -Size 9   -SourceField @('DestinationCode5')
)
# ⚠️ DEVDOC AND METADATA DISAGREE HERE AND METADATA WINS. The devdoc marks DestinationCode as
# MANDATORY ("M/C/O  M O O O O M") and lists combination 1 as
# "FreeText, DestinationCode, [DestinationCode2..5]". The metadata puts ALL FIVE destination codes
# in <Any> and makes only FreeText mandatory. Metadata is FIELD authority (devdoc is QUERY
# authority), so DestinationCode is built as an optional -- and the label carries the devdoc's
# expectation so the officer is not misled by a form that would accept a message with no recipient.
$amCombos = @(
    Build-QidmCombo -KeyReference 'AM' -PrimaryFieldReference 'FreeText' `
        -Set @('FreeText') `
        -Any @('DestinationCode','DestinationCode2','DestinationCode3','DestinationCode4','DestinationCode5')
)
$amQuery = Build-Qidm -ProviderName $providerName -Query 'AdministrativeMessage' `
    -TargetEntity 'AdministrativeMessage' -QueryLabel 'Administrative Message' `
    -Attributes $amAttrs -Combinations $amCombos `
    -Description 'AdministrativeMessage -- AM. Free text to up to five destination ORIs; the only non-search transaction SC declares as Basic. STATUS: HYPOTHESIS -- first non-entity surface in the portfolio; whether the platform renders a sixth targetEntity is unverified, so it is ordered LAST and the first import must confirm the other five still render. Metadata makes only FreeText mandatory while the devdoc marks DestinationCode mandatory; metadata is field authority, so the destination codes are optional and the label carries the expectation.'

Write-Host '  QIDMs built: 9 (including AdministrativeMessage -- HYPOTHESIS, see script header)' -ForegroundColor Green

# =====================================================================
# 10. RMS BUNDLE -- from KB specs. No -KeepSsn (SC WantedPerson carries SSN in the CommSys
#     query, which is separate from the RMS person pool) and no -SkipRace.
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields

Write-Host '  RMS bundle built from KB specs' -ForegroundColor Green
# =====================================================================
# 12. LAYOUTS -- PHASE 1 SHAPE: ONE CARD PER ENTITY.
#     Deliberately not pretty. The standard says confirm QIDMs first and refine layout in Phase 2,
#     because NJ and NY both changed QIDM + layout + state model together and then could not tell
#     which layer had broken. Every control the QIDMs reference exists here exactly once, so a
#     wiring failure is a wiring failure rather than a layout question.
#
#     LABELS ARE THE ONLY HINT MECHANISM THE PLATFORM RENDERS (no helperText, no placeholder), so
#     each carries one of the canonical hint types: routing alternative, identifier priority,
#     in-state default, or optional indicator.
# =====================================================================

# ---- Vehicle: VehicleRegistrationQuery + VehicleStolenQuery -------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE -- REGISTRATION BY PLATE OR VIN, STOLEN CHECK BY PLATE OR VIN + MAKE'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','3','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN (plate takes priority if both are entered)' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';            node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE' } 'ROW_VEH_2' }
                @{ id = 'vehicleYear_Input';                node = Inp 'vehicleYear' 'Vehicle Year (optional)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('12'); fields = @(
                @{ id = 'RegistrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for SC)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle -- 1 card (Phase 1). Registration QVRQ.P (plate+type+year) / QVRQ.V (VIN), Stolen QV.P (plate) / QV.VM (VIN+make). Plate>VIN guardrails on both VIN paths.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# ---- Person: DriverLicense + DriverRegistration (isolated) + WantedPerson -----------------------
# The DR block repeats the licence controls with a DR suffix ON PURPOSE. DriverLicenseQuery and
# DriverRegistrationQuery have IDENTICAL mandatory sets on their OLN paths and metadata gives both
# the keyRef DQ; separate controls are what make them independently selectable at all.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE -- BY OLN, OR BY NAME + DOB + SEX'
        rows  = @(
            @{ id = 'ROW_DL_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_DL_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for SC)' @{ attributeTypeId = 'STATE' } 'ROW_DL_1' }
            )}
            @{ id = 'ROW_DL_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameLast_Input';  node = Inp 'NameLast' 'Last Name' '30' 'ROW_DL_2' }
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_DL_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_DL_2' }
            )}
            @{ id = 'ROW_DL_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameSuffix_Input';     node = Inp 'NameSuffix' 'Suffix' '30' 'ROW_DL_3' }
                @{ id = 'BirthDate_Input';      node = Dt  'BirthDate' 'Date of Birth' 'ROW_DL_3' }
                @{ id = 'SexCode_Input';        node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DL_3' }
                @{ id = 'ImageIndicator_Input'; node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_DL_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DR'
        title = 'DRIVER REGISTRATION -- SEPARATE QUERY, ITS OWN FIELDS'
        rows  = @(
            @{ id = 'ROW_DR_1'; cols = @('6','6'); fields = @(
                @{ id = 'OperatorLicenseNumberDR_Input'; node = Inp 'OperatorLicenseNumberDR' 'OLN' '20' 'ROW_DR_1' }
                @{ id = 'RegistrationStateDR_Input';     node = Sel 'RegistrationStateDR' 'State (leave blank for SC)' @{ attributeTypeId = 'STATE' } 'ROW_DR_1' }
            )}
            @{ id = 'ROW_DR_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameLastDR_Input';   node = Inp 'NameLastDR' 'Last Name' '30' 'ROW_DR_2' }
                @{ id = 'NameFirstDR_Input';  node = Inp 'NameFirstDR' 'First Name' '30' 'ROW_DR_2' }
                @{ id = 'NameMiddleDR_Input'; node = Inp 'NameMiddleDR' 'Middle Name' '30' 'ROW_DR_2' }
            )}
            @{ id = 'ROW_DR_3'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameSuffixDR_Input';     node = Inp 'NameSuffixDR' 'Suffix' '30' 'ROW_DR_3' }
                @{ id = 'BirthDateDR_Input';      node = Dt  'BirthDateDR' 'Date of Birth' 'ROW_DR_3' }
                @{ id = 'SexCodeDR_Input';        node = Sel 'SexCodeDR' 'Sex (optional)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DR_3' }
                @{ id = 'ImageIndicatorDR_Input'; node = Sel 'ImageIndicatorDR' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_DR_3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_WANTED'
        title = 'WANTED PERSON -- NCIC NUMBER, CASE NUMBER, VEHICLE, OR NAME'
        rows  = @(
            @{ id = 'ROW_WP_1'; cols = @('6','6'); fields = @(
                @{ id = 'NCICNumber_Input';                  node = Inp 'NCICNumber' 'NCIC Number (searched alone, takes priority)' '10' 'ROW_WP_1' }
                @{ id = 'OriginatingAgencyCaseNumber_Input';  node = Inp 'OriginatingAgencyCaseNumber' 'Originating Agency Case Number (with last name)' '20' 'ROW_WP_1' }
            )}
            @{ id = 'ROW_WP_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'raceCode_Input';             node = Sel 'raceCode' 'Race (optional)' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_WP_2' }
                @{ id = 'SocialSecurityNumber_Input'; node = Inp 'SocialSecurityNumber' 'SSN (optional)' '9' 'ROW_WP_2' }
                @{ id = 'FBINumber_Input';            node = Inp 'FBINumber' 'FBI Number (optional)' '9' 'ROW_WP_2' }
                @{ id = 'MiscellaneousNumber_Input';  node = Inp 'MiscellaneousNumber' 'Miscellaneous Number (optional)' '15' 'ROW_WP_2' }
            )}
            @{ id = 'ROW_WP_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'ExpandedNameSearchCode_Input';      node = Inp 'ExpandedNameSearchCode' 'Expanded Name Search (optional)' '1' 'ROW_WP_3' }
                @{ id = 'ExpandedBirthDateSearchCode_Input'; node = Inp 'ExpandedBirthDateSearchCode' 'Expanded DOB Search (optional)' '1' 'ROW_WP_3' }
                @{ id = 'RelatedHitSearchIndicator_Input';   node = Inp 'RelatedHitSearchIndicator' 'Related Hit Search (optional)' '1' 'ROW_WP_3' }
            )}
            @{ id = 'ROW_WP_4'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'WP_LicensePlateNumber_Input';    node = Inp 'LicensePlateNumber' 'Plate Number (wanted vehicle -- needs plate state)' '10' 'ROW_WP_4' }
                @{ id = 'LicensePlateStateCode_Input';    node = Sel 'LicensePlateStateCode' 'Plate State' @{ attributeTypeId = 'STATE' } 'ROW_WP_4' }
                @{ id = 'WP_VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN (wanted vehicle -- needs make)' '20' 'ROW_WP_4' }
                @{ id = 'WP_VehicleMakeCode_Input';       node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE' } 'ROW_WP_4' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person -- 3 cards (Phase 1). Driver License (QWDQ name / DQ OLN), Driver Registration (DQ.RN / DQ.RO, DR-suffixed and isolated because metadata gives both transactions keyRef DQ with identical OLN sets), Wanted Person (QWA.NCIC / .OCA / .P / .VM / .N, cross-entity on plate and VIN).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ---- Firearm ------------------------------------------------------------------------------------
$gunLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM -- BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';      node = Sel 'GunMake' 'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunModel_Input';     node = Inp 'GunModel' 'Model (optional)' '4' 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmForm = [PSCustomObject]@{
    description  = 'Firearm -- 1 card. QG (serial number; make/model/caliber optional).'
    label        = 'Firearm'
    layout       = $gunLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ---- Article ------------------------------------------------------------------------------------
# BOTH fields are mandatory in metadata and there are NO optionals, so both labels say so.
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE -- SERIAL NUMBER AND TYPE ARE BOTH REQUIRED'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number (required)' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type (required)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article -- 1 card. QA requires BOTH ArticleSerialNumber and ArticleTypeCode; metadata declares no optionals.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ---- Boat ---------------------------------------------------------------------------------------
$boatLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOAT'
        title = 'BOAT -- BY HULL ID, OR BY REGISTRATION NUMBER'
        rows  = @(
            @{ id = 'ROW_BOAT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID (takes priority over registration)' '20' 'ROW_BOAT_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOAT_1' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for SC)' @{ attributeTypeId = 'STATE' } 'ROW_BOAT_1' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat -- 1 card. QBBQ.H (hull) / QBBQ.R (registration number). The metadata expresses these as a Choice nested under Set, which the generated METADATA_REFERENCE renders as an EMPTY required set.'
    label        = 'Boat'
    layout       = $boatLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

# ---- AdministrativeMessage -- its own card, ordered LAST (Rob 2026-09-14) ------------------------
# STATUS: HYPOTHESIS. See the AdministrativeMessage QIDM block above for the discriminating test.
$amLayout = MakeLayouts @(
    @{
        id    = 'CARD_AM'
        title = 'ADMINISTRATIVE MESSAGE -- FREE TEXT TO UP TO FIVE AGENCIES'
        rows  = @(
            @{ id = 'ROW_AM_1'; cols = @('12'); fields = @(
                @{ id = 'FreeText_Input'; node = Inp 'FreeText' 'Message (required, up to 501 characters)' '501' 'ROW_AM_1' }
            )}
            @{ id = 'ROW_AM_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'DestinationCode_Input';  node = Inp 'DestinationCode' 'Destination ORI (devdoc expects at least one)' '9' 'ROW_AM_2' }
                @{ id = 'DestinationCode2_Input'; node = Inp 'DestinationCode2' 'Destination ORI 2 (optional)' '9' 'ROW_AM_2' }
                @{ id = 'DestinationCode3_Input'; node = Inp 'DestinationCode3' 'Destination ORI 3 (optional)' '9' 'ROW_AM_2' }
            )}
            @{ id = 'ROW_AM_3'; cols = @('4','4'); fields = @(
                @{ id = 'DestinationCode4_Input'; node = Inp 'DestinationCode4' 'Destination ORI 4 (optional)' '9' 'ROW_AM_3' }
                @{ id = 'DestinationCode5_Input'; node = Inp 'DestinationCode5' 'Destination ORI 5 (optional)' '9' 'ROW_AM_3' }
            )}
        )
    }
)
$amForm = [PSCustomObject]@{
    description  = 'Administrative Message -- 1 card, ordered LAST. The only non-search transaction SC declares as Basic. STATUS: HYPOTHESIS -- first non-entity targetEntity in the portfolio; the first import must confirm the five real entities still render.'
    label        = 'Administrative Message'
    layout       = $amLayout
    name         = 'ENTITY_AdministrativeMessage'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'AdministrativeMessage'
}

# =====================================================================
# 13. ENTITIES BUNDLE -- must be bundle #1 or the forms do not render (AZ v2.0).
#     AdministrativeMessage is LAST in all three orders so that if the platform ignores or truncates
#     at an unknown entity, the five real ones have already been placed.
# =====================================================================
$entityOrder = @('Vehicle','Person','Firearm','Article','Boat','AdministrativeMessage')
$entitiesBundle = Build-EntitiesBundle `
    -Configurations @($vehicleForm, $personForm, $firearmForm, $articleForm, $boatForm, $amForm) `
    -DefaultOrder $entityOrder -CadOrder $entityOrder -FrOrder $entityOrder

# =====================================================================
# 14. ASSEMBLE -- ENTITIES first, then PROVIDER, then RMS.
# =====================================================================
$allQidms = @($vehRegQuery, $vehStolenQuery, $dlQuery, $drQuery, $wpQuery, $gunQuery, $artQuery, $boatQuery, $amQuery)

$providerBundle = [PSCustomObject]@{
    configurations = @(@($auth, $qmf, $results) + $allQidms)
    description    = "Provider configuration for $providerName v$Version -- South Carolina SLED. 9 Basic transactions, $((@($allQidms | ForEach-Object { $_.combinations })).Count) combinations."
    name           = $providerName
    type           = 'BUNDLE'
    provider       = $providerName
}

$bundle = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

Write-Host ("  QIDMs: {0}   combinations: {1}   entity forms: 6" -f $allQidms.Count, (@($allQidms | ForEach-Object { $_.combinations })).Count) -ForegroundColor Cyan

# --- Output (versioned filename carries the version; NEVER add a top-level version field) ---
$OUT = Join-Path $providerDir "${providerName}_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

Write-ProviderJson -BundleObject $bundle -OutPath $OUT -Label "$providerName v$Version"
