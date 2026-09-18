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
$Version      = '1.16'
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
# ---- v1.6: DRIVER REGISTRATION NOW CO-FIRES WITH DRIVER LICENSE ---------------------------------
# Rob 2026-09-16: "lets co fire driver reg and driver license since they are idnetical combos".
#
# WHAT CHANGED AND WHY IT IS SOUND. Through v1.5 this query was ISOLATED from DriverLicenseQuery by
# DR-suffixed fieldIds on their own card, because metadata gives BOTH transactions a keyRef of `DQ`
# with IDENTICAL mandatory sets -- a collision ordering cannot separate. That reasoning was about
# telling them APART. Rob's call is that they should not be told apart at all: they are the same
# search, so ONE fill should send BOTH queries.
#
# So every sourceField here now points at the SHARED Driver License controls, the DR-suffixed
# controls and their whole card are deleted, and `-QueriesToDeselect @('DriverLicenseQuery')` is
# GONE -- that deselect was the specific thing preventing the co-fire.
#
# THE MECHANISM IS ALREADY PROVEN ON THIS PROVIDER, not assumed: Vehicle carries
# VehicleRegistrationQuery and VehicleStolenQuery on ONE entity and ONE card, and test_commsys
# shows a single plate fill firing QVRQ.P AND QV.P. LIMITATION #2 is one QIDM per
# (targetEntity, QUERY) -- DriverLicenseQuery and DriverRegistrationQuery are DIFFERENT queries, so
# two QIDMs on Person is legal exactly as two on Vehicle is.
#
# CONSEQUENCE TO EXPECT ON THE WIRE: an OLN fill now sends TWO queries (DL `DQ` + DR `DQ.RO`), and a
# name+DOB fill sends two (DL name path + DR `DQ.RN`). That is the intent, and it is the same shape
# as the Vehicle reg/stolen co-fire Rob already ruled on. The synthetic keyRefs DQ.RN/DQ.RO are KEPT
# because a keyRef never reaches the wire -- they exist only so our own tooling can name the two
# branches apart.
# ALSO: Person drops to ONE card, so it keeps exactly one QIF and its codeTypeProvider
# reverse-lookup (LIMITATION #28) stays intact.
$drAttrs = @(
    Build-QidmAttribute -Name 'OperatorLicenseNumber' -Size 20 -SourceField @('OperatorLicenseNumber')
    Build-QidmAttribute -Name 'Name' -Size 30 -SourceField @('NameLast','NameFirst','NameMiddle','NameSuffix') `
        -Rule ([PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ', ' ', ' ') })
    Build-QidmAttribute -Name 'BirthDate' -Size 8 -SourceField @('BirthDate') `
        -Rule ([PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') })
    Build-QidmAttribute -Name 'SexCode' -Size 1 -SourceField @('SexCode') -CodeTypeProvider 'NIBRS'
    Build-QidmAttribute -Name 'ImageIndicator' -Size 1 -SourceField @('ImageIndicator')
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State' -CodeTypeProvider 'NCIC'
)
$drCombos = @(
    Build-QidmCombo -KeyReference 'DQ.RN' -PrimaryFieldReference 'Name' `
        -Set @('BirthDate','NameLast','NameFirst') `
        -Any @('RegistrationState','SexCode') `
        -Conditions @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
        # OLN>Name GUARDRAIL -- v1.7, and it only became necessary when v1.6 merged the cards.
        # Through v1.5 this query read DR-SUFFIXED controls, so an OLN typed into the Driver License
        # card could not reach it. Now it shares those controls, and DQ.RN is ordered FIRST, so an
        # OLN+Name+DOB fill matched DQ.RN, sent a NAME search, and DISCARDED THE OLN -- DQ.RO never
        # ran, because only one combination fires per QIDM.
        #
        # The alternative fix -- OperatorLicenseNumber in this combo's any[] -- is REFUSED, and the
        # raw <Requirements> is why (the sanctioned raw-XML exception): DriverRegistrationQuery
        # keyReference=DQ primaryFieldReference=Name reads Set[BirthDate, Name] with
        # Any[State..State5, SexCode] and does NOT define OperatorLicenseNumber at all. Adding it
        # would OVER-PERMIT a field the transaction has no tag for. Note DriverLicenseQuery's QWDQ
        # DOES carry OLN in its Any[], which is exactly why verify_build flagged only this one.
        #
        # NOT_EXISTS is existence-only, so it cannot poison the conditions array (QIDM_REFERENCE 2a),
        # and it leaves the plain name+DOB search untouched.
        #
        # NO ImageIndicator default -- same metadata asymmetry as DriverLicenseQuery's name path.
    Build-QidmCombo -KeyReference 'DQ.RO' -PrimaryFieldReference 'OperatorLicenseNumber' `
        -Set @('OperatorLicenseNumber') `
        -Any @('ImageIndicator','RegistrationState') `
        -Defaults @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
)
$drQuery = Build-Qidm -ProviderName $providerName -Query 'DriverRegistrationQuery' `
    -TargetEntity 'Person' -QueryLabel 'Driver Registration' `
    -Attributes $drAttrs -Combinations $drCombos `
    -Description 'DriverRegistrationQuery -- DQ.RN (name + DOB), DQ.RO (OLN). v1.6: CO-FIRES with DriverLicenseQuery on Rob''s call ("they are idnetical combos"), sharing the SAME Driver License controls. Through v1.5 it was isolated with DR-suffixed fieldIds and a queriesToDeselect, because metadata gives both transactions keyRef DQ with identical mandatory sets; that was solving telling-them-apart, which is no longer wanted. An OLN fill now sends both queries, the same shape as the proven Vehicle reg/stolen co-fire. Synthetic keyRefs kept: a keyRef never reaches the wire, they only let our tooling name the branches. SexCode is OPTIONAL here and MANDATORY on the DriverLicense name combo -- the devdoc lists it mandatory for both; metadata is field authority.'

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
    Build-QidmAttribute -Name 'SexCode' -Size 1 -SourceField @('SexCode') -CodeTypeProvider 'NIBRS'   # v1.12 RESTORED (AP #2) -- Firearm is single-QIF again, so LIMITATION #28 no longer breaks reverse-lookup
    Build-QidmAttribute -Name 'RaceCode' -Size 1 -SourceField @('raceCode') -CodeTypeProvider 'NIBRS'   # v1.15: paired with attributeTypeId='RACE' on the control (AP #1). The v1.3 bare form was the LIMITATION #28 fallback for the old two-QIF Wanted Person tab.
    Build-QidmAttribute -Name 'OperatorLicenseNumber'       -Size 20 -SourceField @('OperatorLicenseNumber')
    Build-QidmAttribute -Name 'SocialSecurityNumber'        -Size 9  -SourceField @('SocialSecurityNumber')
    Build-QidmAttribute -Name 'FBINumber'                   -Size 9  -SourceField @('FBINumber')
    Build-QidmAttribute -Name 'MiscellaneousNumber'         -Size 15 -SourceField @('MiscellaneousNumber')
    Build-QidmAttribute -Name 'NCICNumber'                  -Size 10 -SourceField @('NCICNumber')
    Build-QidmAttribute -Name 'OriginatingAgencyCaseNumber' -Size 20 -SourceField @('OriginatingAgencyCaseNumber')
    Build-QidmAttribute -Name 'LicensePlateNumber'          -Size 10 -SourceField @('LicensePlateNumber')
    Build-QidmAttribute -Name 'LicensePlateStateCode'       -Size 2  -SourceField @('LicensePlateStateCode')   # v1.3 NO codeTypeProvider -- see wpForm
    Build-QidmAttribute -Name 'VehicleIdentificationNumber' -Size 20 -SourceField @('VehicleIdentificationNumber')
    Build-QidmAttribute -Name 'VehicleMakeCode'             -Size 24 -SourceField @('VehicleMakeCode')
    Build-QidmAttribute -Name 'ImageIndicator'              -Size 1  -SourceField @('ImageIndicator')
    Build-QidmAttribute -Name 'ExpandedNameSearchCode'      -Size 1  -SourceField @('ExpandedNameSearchCode')
    Build-QidmAttribute -Name 'ExpandedBirthDateSearchCode' -Size 1  -SourceField @('ExpandedBirthDateSearchCode')
    Build-QidmAttribute -Name 'RelatedHitSearchIndicator'   -Size 1  -SourceField @('RelatedHitSearchIndicator')
)
# BOTH Y/N INDICATORS DEFAULT 'Y' ON EVERY CARRYING COMBO -- v1.16, Rob: "make related hit y by
# default". The form initialValue is NOT sufficient on its own: CAD ignores form initialValues
# (feedback_cad_defaults_required), so a form-only flip leaves every CAD-originated wanted-person
# query still sending nothing for Related Hit. The pair has to move together or the two entry
# points disagree about what was asked.
# SAFE because neither field is in any set[] or any condition in this provider -- they are
# any[]-only on all five QWA combos, so a default cannot collapse one combination onto a plainer
# sibling (BUILD_RULES 24, the AZ_AZDPS DQPN/DQP failure). MEASURED off the emitted JSON, not assumed.
$imgDefault = @(
    [PSCustomObject]@{ field = 'ImageIndicator';            value = 'Y' }
    [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' }
)
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
# =====================================================================
# 6b. THE WANTED PERSON SPLIT (v1.15) -- ONE TRANSACTION, TWO ENTITIES, SO IT CO-FIRES
#
# Rob 2026-09-18: "the wanted person query will need to cofire with person queires and vehicle
# queires were appropriate. so no longer will the wanted person tab exist but we will roll the
# wanted person query onto to each tab  veh on veh and person on person relative to the required
# and ioptional fields in the combinations."
#
# WHY TWO QIDMs AND NOT ONE. A QIDM has exactly ONE targetEntity, and CHECKBOXES ARE KEYED BY
# ENTITY -- measured with CHECKBOX_PROBE, not inferred. So a plate typed on the Vehicle tab can
# NEVER trigger a Person-entity query. The person-shaped combos and the vehicle-shaped ones have
# to be separate configurations.
#
# WHY BOTH KEEP query='WantedPersonQuery'. THE WIRE CARRIES `query` AS <MessageType> -- read from
# a real capture, not assumed:  <MessageType>WantedPersonQuery</MessageType>
# Inventing a second query name would put that invented string on the wire and SC would reject it.
# `name` MUST differ instead, because a duplicate config name is a SILENT OVERWRITE at import.
#
# AND THAT COMBINATION WAS PROVEN BEFORE IT WAS BUILT. providers\SHAREDQ_PROBE.json put two QIDMs
# with one shared `query` on Person and Vehicle, each with a control QIDM beside it so a null
# result would be readable. Rob, after importing: "on person typing in personkey both checkboxes
# lit up  same with veh". So the platform keys on (query, entity) -- both configs survive, both
# render, both activate. Had it keyed on `query` alone, one would have been dropped SILENTLY with
# every structural gate green, which is exactly why this was probed rather than attempted.
#
# THE CO-FIRE IS THE POINT, not a side effect: a name on the Person tab now fires DriverLicense +
# DriverRegistration + WantedPerson together, and a plate on the Vehicle tab fires
# VehicleRegistration + VehicleStolen + WantedPerson together.
# =====================================================================
$wpPersonAttrs = @($wpAttrs | Where-Object { $_.name -notin @('LicensePlateNumber','LicensePlateStateCode','VehicleIdentificationNumber','VehicleMakeCode') })
$wpVehAttrs    = @($wpAttrs | Where-Object { $_.name -in     @('LicensePlateNumber','LicensePlateStateCode','VehicleIdentificationNumber','VehicleMakeCode','ImageIndicator','RelatedHitSearchIndicator') })

# ⚠️ THE VEHICLE FORM ALREADY HAS A STATE CONTROL AND IT IS CALLED RegistrationState.
# QWA.P's metadata field is LicensePlateStateCode. Adding a SECOND state box to the Vehicle tab
# would be a duplicate control for one value -- two boxes, one meaning, and whichever the officer
# missed would silently change which combo fires. So the ATTRIBUTE keeps its metadata name (that
# is the wire contract, targetField) and its sourceField points at the control that already
# exists. set[]/any[] hold SOURCEFIELDS, so they name RegistrationState.
# ⚠️ AND IT NEEDS codeTypeProvider THE MOMENT IT POINTS THERE (AP #1). The Vehicle form's
# RegistrationState is a Sel carrying attributeTypeId='STATE'; an attributeTypeId control whose
# QIDM attribute has NO codeTypeProvider sends the platform's internal NUMERIC ROW ID instead of
# the 2-character state code. The validator FAILED the first v1.15 build on exactly this, which is
# the gate earning its keep -- the wire would have carried a number SC cannot read.
$wpVehAttrs = @($wpVehAttrs | ForEach-Object {
    if ($_.name -eq 'LicensePlateStateCode') {
        $_.sourceField = @('RegistrationState')
        $_ | Add-Member -NotePropertyName 'codeTypeProvider' -NotePropertyValue 'NCIC' -Force
    }
    $_
})

$wpPersonCombos = @($wpCombos | Where-Object { $_.keyReference -in @('QWA.NCIC','QWA.OCA','QWA.N') })
$wpVehCombos    = @($wpCombos | Where-Object { $_.keyReference -in @('QWA.P','QWA.VM') } | ForEach-Object {
    $_.requirements.set = @($_.requirements.set | ForEach-Object { if ($_ -eq 'LicensePlateStateCode') { 'RegistrationState' } else { $_ } })
    $_.requirements.any = @($_.requirements.any | ForEach-Object { if ($_ -eq 'LicensePlateStateCode') { 'RegistrationState' } else { $_ } })
    $_
})

$wpQuery = Build-Qidm -ProviderName $providerName -Query 'WantedPersonQuery' `
    -TargetEntity 'Person' -QueryLabel 'Wanted Person' `
    -Attributes $wpPersonAttrs -Combinations $wpPersonCombos `
    -Description 'WantedPersonQuery (PERSON half) -- QWA.NCIC, QWA.OCA, QWA.N. Lives on the Person entity since v1.15 so it CO-FIRES with DriverLicenseQuery and DriverRegistrationQuery off the same name/OLN controls: one name fill sends all three. The vehicle-identifier combos QWA.P and QWA.VM are the same transaction on the Vehicle entity -- see wpVehQuery. Identifier-priority guardrails keep the broad name search behind the unique handles (NCIC number, OCA).'

$wpVehQuery = Build-Qidm -ProviderName $providerName -Query 'WantedPersonQuery' `
    -TargetEntity 'Vehicle' -QueryLabel 'Wanted Person' `
    -Attributes $wpVehAttrs -Combinations $wpVehCombos `
    -Description 'WantedPersonQuery (VEHICLE half) -- QWA.P (plate + state) and QWA.VM (VIN + make). SAME `query` as the Person half, so the wire MessageType is identical; only `name` and `targetEntity` differ. Lives on Vehicle so a plate or VIN CO-FIRES the stolen/registration checks and the wanted-person check together. LicensePlateStateCode maps to the Vehicle form''s existing RegistrationState control rather than adding a second state box.'
# THE NAME SUFFIX IS THE ONLY WAY TO HAVE BOTH. Build-Qidm derives name from query on purpose --
# a passed name can disagree with `query`, and audit_sqvr_integrity plus the log-attribution gates
# key off it -- so the suffix is applied here, deliberately and visibly, rather than by teaching
# the shared helper to take an arbitrary name.
$wpVehQuery.name = "$($wpVehQuery.name)_Veh"

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
# !! targetEntity='Article' SINCE v1.12, AND IT IS THE FIX FOR THE GREYED CHECKBOX.
# Rob, 2026-09-18, reading the rendered page: "wanted person has a firearm button at the button that
# is greyed out" ... "that is not acceptable". MEASURED CAUSE: the query CHECKBOX LIST is keyed by
# targetEntity while TABS are keyed by QUERYINPUTFORM (CAPABILITY #47) -- two different keys. So every
# QIDM on an entity renders its checkbox on EVERY tab of that entity, and one of them is always
# unsatisfiable when the two forms are disjoint. WantedPersonQuery and GunQuery both sat on Firearm,
# so each appeared, permanently dead, on the other's tab; Rob confirmed the same on Boat/Admin Message
# ("boat has admin message on it too and admin has boat on it").
# THE RULE IS EXACT: zero greyed checkboxes <=> ONE QIF PER ENTITY <=> at most 5 tabs. Two QIFs on one
# entity can never both be clean -- each would have to carry the other's controls, and then both
# queries fire from both tabs, which is worse than a dead checkbox.
# So the Firearm CARD moved onto the Article QIF and this QIDM moved with it, leaving Wanted Person
# as the sole QIF on Firearm -- which is the tab Rob asked for twice and it keeps its own name,
# because the tab CAPTION comes from `label`, not targetEntity (measured 2026-09-18: this build
# renders a tab called "Wanted Person" off targetEntity='Firearm', which settles the question
# CAPABILITY #47 recorded as UNMEASURED).
# Same declaration-of-record-kind reasoning as $amQuery's host choice: targetEntity is where the
# transaction is FILED, not a claim that a firearm is an article.
$gunQuery = Build-Qidm -ProviderName $providerName -Query 'GunQuery' `
    -TargetEntity 'Firearm' -QueryLabel 'Firearm' `
    -Attributes $gunAttrs -Combinations $gunCombos `
    -Description 'GunQuery -- QG (serial number, with make/model/caliber optional). Single metadata combination. targetEntity=Article since v1.12 so the Firearm card can share the Article tab and leave Wanted Person as the only QIF on Firearm -- see the block above; this removes the permanently-greyed Firearm checkbox from the Wanted Person tab.'

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
    # v1.8 NO codeTypeProvider -- see the RegistrationState control in $boatLayout. Boat became a
    # TWO-QIF entity when Administrative Message moved here to sit last, so LIMITATION #28 kills the
    # reverse-lookup; the control is now a type-in and the officer enters the 2-char code directly,
    # which is the value that must reach the wire. A codeTypeProvider left here would be reverse-
    # looking-up an attribute id that no longer exists.
    Build-QidmAttribute -Name 'State' -Size 2 -SourceField @('RegistrationState') -TargetField 'State'
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
#     ⚠️ THE HYPOTHESIS RAN AND WAS REFUTED -- v1.1, 2026-09-16. LIMITATION #46.
#     v1.0 shipped this as its OWN entity (targetEntity='AdministrativeMessage'), ordered LAST so
#     that if the platform ignored an unknown entity the five real ones would still place.
#     THE DISCRIMINATING TEST RAN ON THE FIRST AUTOMATED IMPORT and split exactly:
#       1. Do the five still render, in order?   YES -- blast radius zero, the caution paid off.
#       2. Does an AdministrativeMessage form appear?   NO. Rob: "i did not see a admin card".
#     The build was CORRECT when re-checked (ENTITIES first, QIF present, ALL THREE order arrays
#     naming it, payload read-back byte-exact, bundle table 0 -> 3). A correctly-formed sixth
#     entity is SILENTLY DROPPED. Measured portfolio-wide the same day: 21 providers use exactly
#     Person/Vehicle/Firearm/Article/Boat; this was the only sixth and it vanished.
#
#     WHY IT IS FIVE IS *NOT* ESTABLISHED and must not be written down as if it were. Nothing in
#     the repo documents an entity list -- not the KB, not BUILD_RULES, and not
#     UNIVERSAL_SEARCH_HANDLERS.txt (a HANDLER registry with no entity section, so CLAUDE.md's
#     check-before-declaring-absent rule cannot help here). [Likely] targetEntity BINDS the form to
#     a record type RMS can store and display -- the five are the NCIC hot-file / RMS master types,
#     and _build_rms_bundle.ps1 defines targetEntity for only Vehicle and Person -- so an
#     AdministrativeMessage yields no record to map. That is reasoning, not fact.
#     Rob 2026-09-16: "we will not bother crinnger with this stuff  build it and we can iterate as
#     needed." So the card is hosted on Vehicle and the open questions stay in #46 unasked.
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
    # set[]/any[] hold SOURCEFIELDS (form fieldIds), so they carry the v1.2 AM suffix;
    # primaryFieldReference holds the ATTRIBUTE name, which does not. Mixing those two namespaces
    # is the mistake this line is shaped to avoid.
    Build-QidmCombo -KeyReference 'AM' -PrimaryFieldReference 'FreeText' `
        -Set @('FreeText') `
        -Any @('DestinationCode','DestinationCode2','DestinationCode3','DestinationCode4','DestinationCode5')
)
# TargetEntity is a RECOGNISED record kind, which is what makes this form render AT ALL
# (LIMITATION #46: an unrecognised value is silently dropped). It gets its OWN TAB because tabs are
# keyed by QUERYINPUTFORM rather than by entity (CAPABILITY #47, LIVE-PROVEN). It is NOT a claim
# that this searches for a boat.
#
# ⚠️ v1.8 MOVED THIS FROM 'Article' TO 'Boat' AND THE QIDM HAD TO MOVE WITH THE FORM.
# Leaving the QIDM on Article while the QIF moved to Boat would have SILENTLY BROKEN the query:
# LIMITATION #26 says the platform evaluates every QIDM of an entity against THAT ENTITY'S shared
# field pool, so FreeText typed on a Boat-hosted form lands in the BOAT pool while an Article-hosted
# QIDM reads the ARTICLE pool -- set[FreeText] would never be satisfied and NOTHING would fire, with
# no error anywhere. The form and its QIDM must name the same entity.
# ⚠️ THE AdministrativeMessage QIDM IS REMOVED AT v1.13 ALONG WITH ITS FORM -- see the removal note
# in the layout section. Its attributes and combinations above are DELIBERATELY KEPT: they are the
# adjudicated record of the devdoc/metadata disagreement over DestinationCode, and restoring the
# query is then a two-line change rather than a re-derivation.

Write-Host '  QIDMs built: 9 (WantedPersonQuery is TWO configs sharing one query -- Person + Vehicle, v1.15)' -ForegroundColor Green

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
#
#     v1.16 -- NOTHING IN PARENTHESES, BY DIRECTIVE. Rob 2026-09-18: "remove the both queires sent
#     on the card titles everywhere  nothign extra in ()". Every "(optional)" / "(required)" /
#     "(with name)" qualifier is gone from every label on every entity, and the two co-fire
#     announcements are gone from the card titles.
#
#     THAT IS AN OVERRIDE OF A REAL RULE, NOT A TIDY-UP, so it is recorded rather than argued
#     each rebuild. verify_build CHECK 13 Rule 3 REQUIRES an any[]-only field to carry "(" or " - "
#     so the officer can tell a required box from an optional one; the tags below are the sanctioned
#     escape hatch (BUILD_RULES 11 point 8) and downgrade the WARN to an auditable [INFO]. Without
#     them this is 10 WARNs a rebuild, which is how a real finding gets lost in accepted noise.
#
#     STATE IS THE ONE LABEL THAT KEPT ITS HINT, and it is not a parenthesis: "State - leave blank
#     for SC". Rule 1 makes that hint MANDATORY and it is FUNCTIONAL, not decorative -- blank routes
#     in-state and a filled value routes out-of-state, so an officer who does not know that cannot
#     work the form. The dash form satisfies the directive literally (nothing in brackets) and keeps
#     the routing guidance. Say the word and it becomes a bare "State" plus an override tag.
#
# LABEL-OVERRIDE: vehicleYear -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: raceCode -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: SocialSecurityNumber -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: FBINumber -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: MiscellaneousNumber -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: ExpandedNameSearchCode -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: ExpandedBirthDateSearchCode -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: RelatedHitSearchIndicator -- bare by directive (Rob 2026-09-18); it is now a Y/N dropdown defaulted Y, so the control itself shows it is pre-answered
# LABEL-OVERRIDE: GunMake -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: GunModel -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# LABEL-OVERRIDE: GunCaliber -- bare by directive (Rob 2026-09-18, nothing in parentheses)
# =====================================================================

# ---- Vehicle: VehicleRegistrationQuery + VehicleStolenQuery -------------------------------------
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE -- SEARCH BY PLATE, OR BY VIN'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';   node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            # v1.9, Rob: "on veh lets move state to the end of the second line  veh will have 2 lines".
            # State joins this row as its LAST field and ROW_VEH_3 is deleted, so Vehicle is 2 rows.
            # Sequence and widths only -- no fieldId, attribute, combo or wire change.
            # v1.10 widths, Rob: "on vin  shorten teh field length that displays  the helper for
            # stae is getting squished". VIN 5 -> 3 and State 2 -> 4, so the freed width goes where
            # the long label is. VIN's maxLength stays 20 -- that is the metadata size and is NOT
            # what was wide; only the COLUMN it displays in shrank.
            @{ id = 'ROW_VEH_2'; cols = @('3','3','2','4'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                @{ id = 'VehicleMakeCode_Input';            node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE' } 'ROW_VEH_2' }
                @{ id = 'vehicleYear_Input';                node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
                @{ id = 'RegistrationState_Input';          node = Sel 'RegistrationState' 'State - leave blank for SC' @{ attributeTypeId = 'STATE' } 'ROW_VEH_2' }
            )}
            # ---- WANTED PERSON OPTIONALS, NOW IN THE SAME CARD (v1.16) --------------------------
            # v1.15 put these two on a SECOND Vehicle card titled "WANTED PERSON -- SENT WITH THE
            # PLATE OR VIN SEARCH ABOVE". Rob 2026-09-18: "on veh why is it 2 cards? ... i want to
            # keep it one card if possible ... remove the both queires sent on the card titles
            # everywhere". The second card existed only to ANNOUNCE the co-fire, and the co-fire is
            # already stated in the officer guide banner, the test plan and the simulator -- three
            # places that are read deliberately, unlike a card title that has to be read every time.
            # QWA.P (plate + state) and QWA.VM (VIN + make) take their MANDATORY fields from the two
            # rows above; the pool is per ENTITY (LIMITATION #26), so moving these controls between
            # cards on the same tab changes nothing on the wire.
            #
            # BOTH ARE SAFE TO PREFILL AND THAT WAS MEASURED, NOT ASSUMED: neither ImageIndicator
            # nor RelatedHitSearchIndicator appears in ANY set[] or ANY condition anywhere in this
            # provider -- they are any[]-only on the five QWA combos. BUILD_RULES 24 (never prefill a
            # routing field) therefore does not bite; a prefill here cannot collapse one combination
            # onto a plainer sibling the way it killed AZ_AZDPS DQPN/DQP.
            @{ id = 'ROW_VEH_3'; cols = @('6','6'); fields = @(
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_VEH_3' }
                # Rob: "make related hit y by default and use the saem ncic image dropdown". It was a
                # 1-char FREE-TEXT box, so the officer could type anything and nothing defaulted.
                # Metadata gives it Alphabetic maxLen=1 -- the SAME shape as ImageIndicator -- so it
                # takes the same YES_NO_UNKNOWN|NCIC control and the same 'Y'.
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'RelatedHitSearchIndicator' 'Related Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_VEH_3' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle -- ONE card, 3 rows (v1.16). Three transactions CO-FIRE off it: Registration QVRQ.P plate+type+year / QVRQ.V VIN, Stolen QV.P plate / QV.VM VIN+make, and Wanted Person QWA.P plate+state / QWA.VM VIN+make. Plate>VIN guardrails on both VIN paths. v1.15 announced the wanted-person co-fire on a second card; v1.16 folded it in on Rob directive -- the co-fire is stated in the officer guide, the test plan and the simulator instead.'
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
        id    = 'CARD_PER'
        title = 'PERSON -- SEARCH BY OLN, BY NAME + DOB + SEX, BY NCIC NUMBER, OR BY NAME + CASE NUMBER'
        rows  = @(
            # OLN + State + NCIC Image on the TOP row at 6/3/3 is the documented Person pattern
            # (BUILD_RULES 11, PERSON CARDS top-row pattern) -- the primary identifier keeps the
            # width, the two short codes ride beside it, and OLN is not stranded on its own line.
            @{ id = 'ROW_PER_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State - leave blank for SC' @{ attributeTypeId = 'STATE' } 'ROW_PER_1' }
                @{ id = 'ImageIndicator_Input';        node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_1' }
            )}
            # ⚠️ NAME CONTROLS IN FIRST-LAST-MIDDLE-SUFFIX ORDER -- v1.9, Rob: "person do first last
            # middle suffic on second line ... we need to use that format everythwere". All four
            # components now sit on ONE row, so Suffix no longer trails onto the DOB row.
            #
            # THIS IS DISPLAY ORDER ONLY AND IT DOES NOT TOUCH THE WIRE. The composite Name is built
            # by the QIDM attribute, whose sourceField order stays
            # @('NameLast','NameFirst','NameMiddle','NameSuffix') feeding FormatStringRuleHandler to
            # emit the authoritative ConnectCIC format `LAST, FIRST MIDDLE SUFFIX`. Reordering the
            # CONTROLS cannot change that -- the handler reads the attribute, not the layout. Do NOT
            # "make them consistent" by reordering sourceField: that WOULD change the wire, and
            # LAST-first is the format rule every provider in the portfolio is cross-checked against.
            @{ id = 'ROW_PER_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst' 'First Name' '30' 'ROW_PER_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast' 'Last Name' '30' 'ROW_PER_2' }
                @{ id = 'NameMiddle_Input'; node = Inp 'NameMiddle' 'Middle Name' '30' 'ROW_PER_2' }
                @{ id = 'NameSuffix_Input'; node = Inp 'NameSuffix' 'Suffix' '30' 'ROW_PER_2' }
            )}
            # ---- WANTED PERSON CONTROLS, NOW IN THE SAME CARD (v1.16) ---------------------------
            # v1.15 split these onto a second Person card titled "WANTED PERSON -- ... (sent with
            # the driver queries)". Rob 2026-09-18: "same with person card  i want to keep it one
            # card if possible ... remove the both queires sent on the card titles everywhere".
            # Same reasoning as Vehicle: the second card announced the co-fire and nothing else, and
            # the co-fire is stated where it is actually read. Nothing is duplicated -- name, DOB,
            # sex, OLN, State and NCIC Image are SHARED with the rows above because the pool is per
            # ENTITY (LIMITATION #26). That sharing IS the co-fire.
            # NCIC Number and OCA are the two UNIQUE HANDLES: each is a set[] field of its own
            # combination and each is gated NOT_EXISTS on the name search, so filling one beats a name.
            @{ id = 'ROW_PER_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_PER_3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
                # attributeTypeId + codeTypeProvider, NOT the codeTypeCategory fallback. The
                # fallback was correct on the old Wanted Person tab (a two-QIF entity, where
                # LIMITATION #28 broke reverse-lookup) and is WRONG here: Person carries the RMS
                # Person QIDM, whose `race` attribute is useAttributeId=true, so a category-based
                # control stores the code STRING where RMS expects the attribute ID (AP #11). The
                # validator caught exactly that on the first v1.15 build. Portfolio standard --
                # AZ_AZDPS, CA_CLETS, CA_CONTRA_COSTA and CA_VENTURA_COUNTY all pair them this way.
                @{ id = 'raceCode_Input'; node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_3' }
            )}
            @{ id = 'ROW_PER_4'; cols = @('6','6'); fields = @(
                @{ id = 'NCICNumber_Input';                  node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_PER_4' }
                @{ id = 'OriginatingAgencyCaseNumber_Input'; node = Inp 'OriginatingAgencyCaseNumber' 'Case Number' '20' 'ROW_PER_4' }
            )}
            @{ id = 'ROW_PER_5'; cols = @('4','4','4'); fields = @(
                @{ id = 'SocialSecurityNumber_Input'; node = Inp 'SocialSecurityNumber' 'SSN' '9' 'ROW_PER_5' }
                @{ id = 'FBINumber_Input';            node = Inp 'FBINumber' 'FBI Number' '9' 'ROW_PER_5' }
                @{ id = 'MiscellaneousNumber_Input';  node = Inp 'MiscellaneousNumber' 'Misc Number' '15' 'ROW_PER_5' }
            )}
            @{ id = 'ROW_PER_6'; cols = @('4','4','4'); fields = @(
                @{ id = 'ExpandedNameSearchCode_Input';      node = Inp 'ExpandedNameSearchCode' 'Expand Name Search' '1' 'ROW_PER_6' }
                @{ id = 'ExpandedBirthDateSearchCode_Input'; node = Inp 'ExpandedBirthDateSearchCode' 'Expand DOB Search' '1' 'ROW_PER_6' }
                # Same change as the Vehicle tab: free-text 1-char box -> the NCIC Image dropdown
                # shape, defaulted 'Y'. any[]-only here too, so the prefill cannot shadow a combo.
                @{ id = 'RelatedHitSearchIndicator_Input';   node = Sel 'RelatedHitSearchIndicator' 'Related Hit' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_PER_6' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person -- ONE card, 6 rows (v1.16). THREE transactions CO-FIRE off it: DriverLicenseQuery (QWDQ name / DQ OLN), DriverRegistrationQuery (DQ.RN / DQ.RO) and WantedPersonQuery (QWA.NCIC / QWA.OCA / QWA.N). One name entry sends all three, because the field pool is per ENTITY (LIMITATION #26) and nothing is duplicated. v1.5 isolated DL from DR on a second DR-suffixed card; v1.15 gave Wanted Person a second card; v1.16 collapsed both on Rob directive. One QIF means Person keeps its codeTypeProvider reverse-lookup intact (LIMITATION #28).'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# ---- WANTED PERSON -- ITS OWN TAB (v1.3) --------------------------------------------------------
# Rob 2026-09-16: "now move wanted person to its own tab", then on being shown the cost:
# "start with option A  we can work backwards if we have to".
# Possible at all because tabs are keyed by QUERYINPUTFORM, not by entity -- CAPABILITY #47,
# LIVE-PROVEN (8 forms -> 8 tabs). Person drops 3 cards -> 2, the original decrowding request.
#
# !! HOST = Firearm, MEASURED NOT GUESSED. LIMITATION #28 breaks codeTypeProvider reverse-lookup on
# any entity carrying two QIFs, and #26 names the cause as a SHARED FIELD POOL -- so overlap was
# measured against every candidate. Denominator printed FIRST, because the first run of that probe
# extracted 0 fields and would have called every host "disjoint" vacuously:
#     Firearm  7 fields  overlap 0  DISJOINT  <- chosen; also the only single-combo host, so the
#     Boat     6 fields  overlap 0  DISJOINT     least interaction with LIMITATION #1 union-wire
#     Article  5 fields  overlap 0  DISJOINT  (already hosts Administrative Message)
#     Vehicle 10 fields  overlap 3  Plate / VIN / MakeCode -- rejected
#
# !! THREE DROPDOWNS BECAME TYPE-INS AND THAT IS THE PRICE OF THE TAB. I told Rob it was one
# (Race). It is three: this QIDM declares codeTypeProvider on RaceCode (NIBRS), SexCode (NIBRS) AND
# LicensePlateStateCode (NCIC). The validator had flagged only raceCode because SexCode had not yet
# been added to this form. On a two-QIF entity all three lose reverse-lookup, and AP #1 says the
# platform then sends its internal numeric row id instead of the code -- silently wrong Race/Sex/
# State values to SLED, which is worse than a clumsier control. So all three are FormInputs and
# their codeTypeProvider is removed from the QIDM attributes.
#   - labels carry the valid values, so the officer is not guessing at a bare box
#   - Person's OWN SexCode dropdown is UNTOUCHED: Person still has exactly ONE QIF, so its
#     reverse-lookup still works. The trade is scoped to this tab.
# TO WORK BACKWARDS: restore the three to Sel with their codeTypeProvider and move this card back
# onto Person. That is the v1.2 shape, one revert.
#
# !! THE TAB MUST BE SELF-CONTAINED. QWA.N and QWA.OCA search by NAME and the name boxes lived on
# the Driver License card, shared through the Person entity. The first v1.3 attempt moved the card
# without them and the validator FAILED: "QWA.OCA / QWA.N: unresolvable set[] fields: NameLast,
# NameFirst". So this form carries its own Name/DOB/Sex/OLN/Image controls -- the same reasoning
# that gives DriverHistory its DH-suffixed set.
# Field ids are deliberately NOT suffixed: pools are per-ENTITY and Firearm shares none of these
# names, so the QIDM sourceFields need no change.
# ---- THE WANTED PERSON FORM IS GONE (v1.15) ----------------------------------------------------
# Rob 2026-09-18: "no longer will the wanted person tab exist but we will roll the wanted person
# query onto to each tab  veh on veh and person on person relative to the required and ioptional
# fields in the combinations."
# Its controls did not disappear -- they MOVED to the tabs that already own those fields:
#   person-shaped (NCIC Number, Case Number, Race, SSN, FBI, Misc, the two Expand codes,
#                  Related Hit)  -> CARD_PER_WP on the Person tab
#   vehicle-shaped (NCIC Image, Related Hit)  -> CARD_VEH_WP on the Vehicle tab
# Name / DOB / Sex / OLN / plate / VIN / make / state are NOT repeated: the field pool is per
# ENTITY (LIMITATION #26), so the controls already on those tabs feed the QWA combinations
# directly. That sharing is exactly what produces the CO-FIRE Rob asked for -- one name fill
# satisfies DriverLicense, DriverRegistration AND WantedPerson at once.
# The QIDM split that makes this legal is in section 6b; it was PROVEN with SHAREDQ_PROBE before
# being built, because a same-query/two-entity config could have been silently dropped.

# ---- Firearm ------------------------------------------------------------------------------------
# ---- Article -- ITS OWN TAB AGAIN (v1.13) -------------------------------------------------------
# v1.12 merged the Firearm card in here to avoid a dead checkbox. v1.13 does not need to: with
# Administrative Message REMOVED there are exactly 6 forms for the 6 entity slots, so EVERY entity
# carries exactly ONE QIF and no tab can show another form's checkbox. Article is plain again.
# BOTH Article fields are mandatory in metadata and there are NO optionals, so both labels say so.
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE -- SERIAL NUMBER AND TYPE ARE BOTH REQUIRED'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'ArticleTypeCode_Input';     node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article -- 1 card. QA requires BOTH ArticleSerialNumber and ArticleTypeCode; metadata declares no optionals. Its own tab again at v1.13 (the v1.12 Firearm merge is undone).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# ---- Firearm -- ITS OWN TAB AGAIN (v1.13) -------------------------------------------------------
$gunLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM -- BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'serialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'GunMake_Input';      node = Sel 'GunMake' 'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
                @{ id = 'GunModel_Input';     node = Inp 'GunModel' 'Model' '4' 'ROW_GUN_1' }
                @{ id = 'GunCaliber_Input';   node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
        )
    }
)
$firearmForm = [PSCustomObject]@{
    description  = 'Firearm -- 1 card. QG (serial number; make/model/caliber optional). Sole QIF on the Firearm entity at v1.13, because Wanted Person moved to targetEntity=Other -- so no tab shows another form''s checkbox.'
    label        = 'Firearm'
    layout       = $gunLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ---- Boat -- ITS OWN TAB AGAIN (v1.13), the Administrative Message card is gone -----------------
$boatLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOAT'
        title = 'BOAT -- BY HULL ID, OR BY REGISTRATION NUMBER'
        rows  = @(
            @{ id = 'ROW_BOAT_1'; cols = @('4','4','4'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID' '20' 'ROW_BOAT_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOAT_1' }
                # ⚠️ TYPE-IN, NOT A DROPDOWN, SINCE v1.8 -- and this is a capability GIVEN UP, not a
                # preference. Administrative Message now shares targetEntity='Boat' to place its tab
                # last, which makes Boat a TWO-QIF entity, and LIMITATION #28 is explicit: "when
                # multiple QIFs target the same entity, codeTypeProvider reverse-lookup on QIDM
                # attributes fails -- the QIDM sends the raw attribute ID instead of the resolved
                # code." This control was `Sel ... attributeTypeId='STATE'` paired with
                # `-CodeTypeProvider 'NCIC'` on the BoatQuery State attribute, which is exactly that
                # rescue pattern (AP #1: attributeTypeId WITHOUT codeTypeProvider sends the platform's
                # internal numeric row id). Keeping the dropdown would have put a numeric id on the
                # wire where SC expects a 2-character state code.
                # THE COST IS SMALL AND WAS MEASURED BEFORE CHOOSING: State is any[]-ONLY on both
                # QBBQ.H and QBBQ.R, so it is a pure optional and NOT a routing discriminator -- no
                # BUILD_RULES 24 exposure -- and the label already told the officer to leave it blank
                # in state. Same trade the Wanted Person card took at v1.3 for LicensePlateStateCode.
                # ⚠️ v1.12 RE-OPENS THE DROPDOWN OPTION AND DELIBERATELY DOES NOT TAKE IT. Boat is a
                # SINGLE-QIF entity again, so LIMITATION #28 no longer applies and this could go back
                # to `Sel ... attributeTypeId='STATE'` + `-CodeTypeProvider 'NCIC'`. It is left as a
                # type-in in THIS bump on the script's own one-change-per-import rule: the structural
                # fix is what the next import has to prove, and a control that changed TYPE in the
                # same bump would confound a blank or wrong-coded State on the wire. Restore it in the
                # next bump, together with the Wanted Person card's Race/Sex/LicensePlateStateCode,
                # which are type-ins for exactly the same retired reason.
                @{ id = 'RegistrationState_Input';  node = Inp 'RegistrationState' 'State - leave blank for SC' '2' 'ROW_BOAT_1' }
            )}
        )
    }
)

# ---- ADMINISTRATIVE MESSAGE -- REMOVED AT v1.13 ------------------------------------------------
# Rob, 2026-09-18: "6 tabs  remove admin message and see what the cehckboxes look like".
# WHY THIS ONE GOES. Checkboxes are keyed by ENTITY -- MEASURED with CHECKBOX_PROBE, not argued --
# and the entity set is capped at SIX by the client itself (Sm = Object.values(ut) over
# PERSON/VEHICLE/FIREARM/ARTICLE/BOAT/OTHER). SC_SLED wanted SEVEN forms. Any 7th form doubles an
# entity, and a doubled entity ALWAYS strands a permanently-dead checkbox on BOTH of its tabs.
# Nothing in configuration removes it, and every candidate was tested on 2026-09-18:
#     enabled:false           -> not carried by the importer (checkbox still rendered)
#     order                   -> not carried (A=2/B=1 still rendered A first)
#     a second provider bundle-> does not scope a tab (appeared on both)
#     autoSelect:false        -> renders anyway, merely unticked
#     admin form<->interface  -> unlinking changed nothing
# So the choice was SEVEN tabs carrying dead checkboxes, or SIX clean tabs minus one form. AM is
# the one to drop: it is the only NON-SEARCH transaction in the build, and its tab is exactly where
# the stray Boat checkbox that started this appeared. The five real entities plus Wanted Person on
# Other now fill the six slots EXACTLY -- one QIF each, so no tab can show another form's query.
# WARNING: AM is devdoc-Basic SUPPORTED, so this is a USER-APPROVED SKIP and must be registered or
# audit_supported_queries CHECK 0 will correctly flag it as unbuilt.
# TO RESTORE IT: give AM targetEntity=Other and move Wanted Person back onto Firearm -- that trade
# buys the 7th tab and costs two dead checkboxes on the Firearm pair.
$boatForm = [PSCustomObject]@{
    # ⚠️ THE LABEL IS WHAT THE OFFICER READS ON THE TAB, AND IT SURVIVED A CARD REMOVAL ONCE.
    # v1.13 deleted the Administrative Message card from this form but left the v1.12 label saying
    # "Boat & Administrative Message", so the imported build rendered a tab promising a form that
    # was no longer there -- Rob, reading the live page: "last tab still says boat and admin
    # message". Every structural gate passed, because a label is not wired to anything: no
    # validator, no reachability check and no wiring gate compares a tab caption to the cards
    # under it. When a card leaves a form, CHANGE THE LABEL IN THE SAME EDIT.
    description  = 'Boat -- 1 card. QBBQ.H (hull) / QBBQ.R (registration number). The metadata expresses these as a Choice nested under Set, which the generated METADATA_REFERENCE renders as an EMPTY required set. Its own tab again at v1.13: the Administrative Message card that shared this QIF in v1.12 is gone, so Boat is one form on one entity.'
    label        = 'Boat'
    layout       = $boatLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

# =====================================================================
# 13. ENTITIES BUNDLE -- must be bundle #1 or the forms do not render (AZ v2.0).
#     SIX FORMS, FIVE DISTINCT ENTITIES. `Person` appears TWICE in the order array on purpose --
#     once for the real Person tab and once for the Administrative Message tab. That is what
#     CAPABILITY #47 measured working (the probe listed Person four times and got four tabs).
#     AM goes LAST so the five familiar tabs keep their established positions.
# =====================================================================
# ⚠️ THE BLOCK BELOW IS HISTORY AS OF v1.12 -- ITS MECHANICS ARE STILL TRUE, ITS LAYOUT IS NOT.
# It documents the SEVEN-tab arrangement (two QIFs each on Firearm and Boat). v1.12 merged those
# doubled slots into single QIFs to kill the greyed checkboxes, so there are now FIVE tabs, one per
# entity, and rules 1-3 no longer bind anything: with one form per entity the order array alone
# fixes the order. Rob's requested SEQUENCE is preserved as far as the merge allows --
# Vehicle, Person, Wanted Person, Article(+Firearm), Boat(+Administrative Message) -- with Firearm
# and Administrative Message now CARDS inside the last two tabs rather than tabs of their own.
# Kept verbatim because the three measured facts in it are what any future multi-QIF work must obey.
#
# TAB ORDER, Rob 2026-09-16: "veh per wanted person firearm articel boat admin mesage  in that order".
#
# ⚠️ MEASURED ON THE RENDERED TENANT AT v1.7, 2026-09-16 -- THE HYPOTHESIS THAT USED TO BE HERE IS
# NOW ANSWERED, AND IT WAS HALF WRONG. Rob read the strip after the v1.7 import:
#
#     rendered v1.7 : Vehicle | Person | Wanted Person | Firearm | Article | ADMIN MESSAGE | BOAT
#     asked for     : Vehicle | Person | Wanted Person | Firearm | Article | BOAT | ADMIN MESSAGE
#
# THE RULE, now LIVE-PROVEN rather than assumed:
#   1. The order array lists ENTITY names and DUPLICATES CARRY NO INFORMATION. v1.7 shipped
#      @('Vehicle','Person','Firearm','Firearm','Article','Boat','Article') -- two `Firearm` and two
#      `Article` entries that cannot say WHICH form takes which slot. The array is AMBIGUOUS BY
#      CONSTRUCTION; it effectively sets the order of the UNIQUE entities and nothing more.
#   2. Within one entity, its forms render in CONFIGURATIONS[] ORDER -- the half that was right, and
#      it is why Wanted Person correctly preceded Firearm.
#   3. CONSEQUENCE, and it is the constraint that actually governs layout here:
#      SAME-ENTITY TABS ARE ALWAYS ADJACENT. So a tab can only be LAST if it sits on the LAST
#      entity. On Article, Administrative Message was glued to Article at position 6 and Boat was
#      pushed to 7 -- no reordering of this array could have fixed it.
#
# THE v1.8 FIX therefore moves the HOST, not the order: $amForm and its QIDM go to targetEntity
# 'Boat', Boat is last in the unique-entity order, and ENTITY_Boat precedes ENTITY_AdministrativeMessage
# in the configurations array -- so rule 2 puts Boat 6th and Administrative Message 7th:
#     position 1 Vehicle        -> $vehicleForm
#     position 2 Person         -> $personForm
#     position 3 Firearm  (1st) -> $wpForm        <- Wanted Person
#     position 4 Firearm  (2nd) -> $firearmForm
#     position 5 Article        -> $articleForm
#     position 6 Boat     (1st) -> $boatForm
#     position 7 Boat     (2nd) -> $amForm        <- Administrative Message
#
# ⚠️ IT IS NOT FREE, AND THE BILL IS PAID IN $boatLayout: Boat is now a TWO-QIF entity, so
# LIMITATION #28 breaks its codeTypeProvider reverse-lookup and RegistrationState had to become a
# type-in. Article could host a second QIF for nothing (ArticleTypeCode resolves on the CONTROL via
# codeTypeCategory and no Article attribute uses codeTypeProvider); Boat could not. That asymmetry
# was measured from the emitted JSON before the move, not assumed.
#
# ⚠️ THE DUPLICATE ENTRIES ARE KEPT DELIBERATELY. They are inert by rule 1, and trimming this to the
# 5 unique entities in the SAME bump would be two experiments at once: if tabs then went missing,
# nothing would say whether the host move or the trimmed array caused it. One change per import.
# v1.12 -- FIVE FORMS, FIVE DISTINCT ENTITIES, ONE QIF EACH. The duplicate entries are GONE because
# the duplication itself is gone: ENTITY_Firearm merged into ENTITY_Article and
# ENTITY_AdministrativeMessage merged into ENTITY_Boat, which is what removes every greyed checkbox
# (see $gunQuery). Wanted Person remains its own tab on the Firearm slot.
$entityOrder = @('Vehicle','Person','Firearm','Article','Boat')
$entitiesBundle = Build-EntitiesBundle `
    -Configurations @($vehicleForm, $personForm, $firearmForm, $articleForm, $boatForm) `
    -DefaultOrder $entityOrder -CadOrder $entityOrder -FrOrder $entityOrder

# =====================================================================
# 14. ASSEMBLE -- ENTITIES first, then PROVIDER, then RMS.
# =====================================================================
$allQidms = @($vehRegQuery, $vehStolenQuery, $wpVehQuery, $dlQuery, $drQuery, $wpQuery, $gunQuery, $artQuery, $boatQuery)

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

Write-Host ("  QIDMs: {0}   combinations: {1}   entity forms: 5" -f $allQidms.Count, (@($allQidms | ForEach-Object { $_.combinations })).Count) -ForegroundColor Cyan

# --- Output (versioned filename carries the version; NEVER add a top-level version field) ---
$OUT = Join-Path $providerDir "${providerName}_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }

Write-ProviderJson -BundleObject $bundle -OutPath $OUT -Label "$providerName v$Version"
