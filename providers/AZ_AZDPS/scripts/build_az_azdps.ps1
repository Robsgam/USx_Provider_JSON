# build_az_azdps.ps1
# Builds AZ_AZDPS_v<X.Y>.json from source\AZ_AZDPS.xml + tools\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs)
# SINGLE-JSON multi-card build (consolidated from the retired BASE + MC scripts at v3.0).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_az_azdps.ps1
#
# v3.4 (2026-08-01, ONE WIRE FIX + FOUR REGISTRATIONS -- all decided from AZ's OWN devdoc + metadata):
#   WIRE FIX -- Boat hull searches were SILENTLY DROPPING a registration number the provider accepts.
#     v3.1 hardened Hull>Reg by gating the Reg combos `BoatHullIdNumber NOT_EXISTS` (correct, kept) AND
#     by removing RegistrationNumber from the HULL combos' any[] "so the hull pool never carries the
#     reg number". That second half conflated two different things. WHICH COMBO FIRES is the guardrail
#     and the NOT_EXISTS gate already enforces it. WHAT THE WINNER TRANSMITS is separate, and both
#     authorities say carry it: metadata ACQB{BoatHullIdNumber} = Set[BadgeNumber, BoatHullIdNumber]
#     Any[RegistrationNumber, RelatedHitSearchIndicator], and devdoc BoatQuery #1 lists
#     RegistrationNumber as a legal optional. audit_devdoc_optionals reported it on 4 fills ("fires
#     ACQBH but optional(s) RegistrationNumber are in NO matching combo's set[]/any[]").
#     RESTORED to ACQBH + BQH any[]. NOT reversed on ACQB/BQ -- those are gated hull-NOT_EXISTS, so
#     hull can never be present when they fire and listing it would be dead config.
#     Identifier priority is about ROUTING, never about deleting a permitted field from the payload.
#   REGISTERED (4 audit_metadata CHECK 4e FAILs, all variant-matching artefacts, none a real defect):
#     KQ | BirthDateDH + SexCodeDH -- built KQ declares PF=OperatorLicenseNumber and implements
#       metadata KQ{OperatorLicenseNumber} = Set[State, OperatorLicenseNumber] EXACTLY; the finding
#       pairs it against the sibling KQ{Name} variant, which KQH implements. Promoting them would make
#       the OLN-only driver-history search -- the commonest one -- unreachable.
#     DQSS | BirthDate + SexCode -- DQSS is a SYNTHETIC keyRef, so the auditor resolves it by PREFIX to
#       the DQ family and compares against DQ{Name}. Its real variant is DQ{SocialSecurityNumber} =
#       Set[SocialSecurityNumber], which requires nothing else at all.
#   REGISTERED (2 devdoc-optionals NO-FIRE): devdoc brackets SexCode as optional on the name searches
#     (#1 "BadgeNumber, BirthDate, Name, [SexCode]" and #3 "Name, [SexCode]") but metadata makes it
#     MANDATORY on every name variant -- ACWL{Name} and DQ{Name} both put SexCode in <Set>, and there
#     is no looser one. Metadata is FIELD-authority. Building to the brackets would emit a request no
#     variant accepts. The gate itself confirms the build is right: "#1 +[SexCode] -> ACWL" is OK.
#   CORRECTION (same day): I first recorded this as a PARSER DEFECT -- "the devdoc parser drops items
#     containing an `="Y"` literal and silently renumbers". THAT WAS WRONG, and the parser is right.
#     AZ's devdoc contains TWO separate driver-licence sections, and the two blocks belong to
#     DIFFERENT query headings:
#       line 161  DriverLicenseQuery         <- its block has the ImageIndicator="Y" + Requestor items
#       line 393  AzAzdpsDriverLicenseQuery  <- its block is what the parser reported, correctly
#     Nothing is dropped and nothing is renumbered; the items I thought were missing belong to another
#     query. Verified by locating the nearest heading above each block.
#
#   REAL OPEN QUESTION THIS EXPOSED -- Rob's call, NOT settled here. The devdoc's
#     "Basic Queries Supported:" section (line 25) spans lines 27-244 and its driver-licence entry is
#     `DriverLicenseQuery` (line 161). Everything from line 298 on -- including
#     `AzAzdpsDriverLicenseQuery` (393) -- is OUTSIDE that section. Metadata defines BOTH as distinct
#     transactions. This build implements AzAzdpsDriverLicenseQuery and does NOT implement the Basic
#     DriverLicenseQuery, so on the strict reading (devdoc Basic list is the sole scope authority) the
#     DL scope is INVERTED: we build the out-of-Basic variant and skip the Basic one, which is also the
#     only one supporting image requests (ImageIndicator="Y" + Requestor).
#     Contrast Boat, where the same fork exists (BoatQuery line 66 Basic vs AzAzdpsBoatQuery line 337)
#     and this build correctly implements the Basic BoatQuery -- so DL is the lone inversion.
#     NOT changed unilaterally: switching transactions rewires the whole Person entity and the v3.3
#     scope correction was itself a direct Rob directive naming "DriverLicenseQuery". Flagged in
#     PENDING_UPDATES and SESSION_STATE.
#   No re-sweep cost: AZ has never been USx-tenant-tested. ALL 5 ENTITIES RESET at v3.4.
# v3.3 (2026-07-28, SCOPE CORRECTION -- direct Rob directive): build ONLY the devdoc "Basic Queries
#   Supported" section. The AZ Basic list is exactly 6 queries (ArticleSingleQuery, BoatQuery,
#   DriverHistoryQuery, DriverLicenseQuery, GunQuery, VehicleRegistrationQuery). WMPIWantedPersonInquiry
#   + WMPIMissingPersonInquiry are NOT in it (they live in a separate "Wanted Missing Person Inquiries
#   (WMP-I)" devdoc section) -- so they are REMOVED: both QIDMs deleted, the Person WANTED/MISSING card
#   removed, Person is now 2 cards (DRIVER LICENSE + DRIVER HISTORY) like the rest of the portfolio.
#   raceCode was the only WMPI-card field the RMS person search still needs (race <- raceCode), so it
#   was RELOCATED to the DL card (bare "Race", NJ/CA pattern). The other WMPI-only fields (NCICNumber,
#   ExpandedName/BirthDate, Age/Height/Weight/Eye/Hair/AreaCode/FormORI, Person relatedHitSearchIndicator)
#   are gone with the card. This clears the 18 audit_metadata WARNs (they were the metadata-vs-Basic
#   delta for the out-of-scope WMPI paths -- the "no combo left behind rule is BASIC-scoped" lesson).
#   Rationale: I had proposed BUILDING the unbuilt WMPI paths to satisfy those WARNs -- the inverse of
#   the devdoc-authority rule; Rob corrected it. Layout + query-set change (removes 2 non-Basic queries),
#   no change to the 6 retained queries' wire. ALL 5 ENTITIES RESET at v3.3. NOT yet USx-tenant-tested.
# v3.2 (2026-07-28, DEX-1284 convention pass -- direct Rob feedback, layout/label-only, NO functional
#   change): brought AZ from the pre-DEX-1284 methodology in line with the FL/NJ/HI/NY/TX/CA portfolio.
#   STRUCTURE: Vehicle 3 cards (OPTIONS+PLATE+VIN) -> 1; Boat 3 cards (OPTIONS+REG+HULL) -> 1; Person
#   7 cards -> 3 (DRIVER LICENSE / DRIVER HISTORY / WANTED-MISSING). The shared hidden badge
#   (dexStateUserId, per-entity), RegistrationStateDH SelH, and Attention feeder all fold onto the
#   card that consumes them -- preserved exactly (fieldIds/initialValues/InpH/SelH unchanged).
#   CA-LESSON CHECK applied: verified from the QIDM set[]/any[] that BOTH WMPI queries source the DL
#   card's shared Name/DOB/Sex, so the DL name stays VISIBLE (WMPI reads it from the pool -- no orphan);
#   a Wanted/Missing name search enters Name on the Driver License card + descriptors on the
#   Wanted/Missing card (shared-name design, unchanged wire).
#   LABELS: OLN (License Number (DL)/(DH) -> "OLN"); "Related Hit (Y)" -> "Stolen Check"
#   (Firearm/Article/Boat/WMPI); stripped every "(optional)"/"(DH)" helper -> bare + LABEL-OVERRIDE
#   (Make/Year, MI/Suffix, Exp Name/DOB, Area Code/Form ORI, Gun Make/Model/Caliber); State
#   "(default AZ - change for out-of-state)" -> bare "State" (initialValue=AZ kept, NJ pattern,
#   LABEL-OVERRIDE); card titles enumerate query paths; M.I. -> MI; dropped "(DH)" field qualifiers.
#   AZ has NO ImageIndicator (NCIC Image N/A). No combo/QIDM/routing/fieldId/default/wire change.
#   ALL 5 ENTITIES RESET at v3.2. NOT yet USx-tenant-tested.
# v3.1 (2026-07-24): identifier-priority guardrails HARDENED from demotion-only to existence-gate.
#   v3.0 had ZERO conditions on its CommSys combos -- "priority" was implemented only by demoting the
#   lower identifier to any[], which does NOT create mutual exclusivity (LIMITATION #1: any[] fields
#   still enter the union pool). Multi-identifier input over-sent (plate query also serialized VIN; DL
#   name query also serialized OLN+SSN; DH name also OLN; boat reg also Hull; WMPI name also NCIC).
#   v3.1 adds existence-only EXISTS/NOT_EXISTS conditions (the proven CA_VENTURA/CA_eSUN pattern):
#     Vehicle Plate>VIN   : ACVRV gets LicensePlateNumber NOT_EXISTS (+ VIN dropped from ACVR any[])
#     DL      OLN>SSN>Name: DQSS gets OLN NOT_EXISTS; ACWL/DQN get OLN+SSN NOT_EXISTS
#                           (+ Name/SSN dropped from DQ any[], Name dropped from DQSS any[])
#     DH      OLN>Name     : KQH gets OperatorLicenseNumberDH NOT_EXISTS (DH-suffix pool)
#     Boat    Hull>Reg     : ACQB/BQ get BoatHullIdNumber NOT_EXISTS (+ Hull dropped from their any[])
#     WMPI    NCIC>Name    : ACQW/ACQM get NCICNumber NOT_EXISTS (+ NCIC dropped from their any[])
#   No State gates added: AZ has NO in-state/OOS keyRef split (single combo per identifier, State
#   default AZ in any[]) -- LIMITATION #30 does not apply. Query set/keyRefs/DH-suffix/badge/Attention
#   feeder/-KeepSsn all unchanged. Guardrail-hardening only. NOT yet live-tested at v3.1.
#
# METHODOLOGY (v3.0 rebuild, 2026-07-22):
#   - USx CAD-integration field names authored in PascalCase DIRECTLY (layout fieldIds, QIDM
#     sourceField, combo set[]/any[]) to match Cringer's reference. Mark43/RMS-internal keys
#     (dexStateUserId, vehicleYear, nameMiddle/nameSuffix, relatedHitSearchIndicator, attention,
#     purposeCode, WMPI descriptors, SocialSecurityNumber) stay camelCase / as-authored.
#     RMS form-fed fields recased via Build-RmsBundle -PascalCaseUsxFields. NEVER a whole-tree
#     recase post-transform (the removed Convert-UsxCasing collapsed Craft.js nodes arrays).
#   - QIDM attribute `name` and `targetField` are the metadata wire contract and are UNCHANGED
#     by the casing pass (e.g. State attribute keeps name/targetField='State'; only its
#     sourceField recases registrationState -> RegistrationState).
#   - GunQuery serial number uses fieldId/sourceField/set 'serialNumber' (CAD sends camelCase
#     serialNumber) while attribute name + targetField + primaryFieldReference stay
#     'GunSerialNumber' -- same class of CAD fix already applied to NJ/FL/HI/TX.
#   - Single versioned root JSON (AZ_AZDPS_v${Version}.json); phases/ retired (git history is the
#     archive); Write-ProviderJson deletes any stale root sibling (incl. legacy AZ_AZDPS_MC.json).
#
# QUERYINPUTDATAMAPPING (CommSys -- 8 QIDMs):
#   VehicleRegistrationQuery         ACVR (Plate+Badge), ACVRV (VIN+Badge -- invented)
#   AzAzdpsDriverLicenseQuery        DQ (OLN), DQN (Name), DQSS (SSN), ACWL (Badge+Name)
#   DriverHistoryQuery               KQ (OLN+State), KQH (Name+State -- invented)
#   GunQuery                         ACQG (Badge+Serial)
#   ArticleSingleQuery               ACQA (Badge+Type+Serial)
#   BoatQuery                        ACQB (Reg+Badge), ACQBH (Hull+Badge), BQ (Reg), BQH (Hull)
#   (WMPI Wanted/Missing REMOVED v3.3 -- not in the devdoc "Basic Queries Supported" section.)
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle (1 card), Person (2 cards: DL+DH), Firearm (1 card), Article (1 card), Boat (1 card)
#
# STATE: NCIC pattern confirmed (attributeTypeId=STATE, codeTypeProvider=NCIC)
# SEX: NIBRS confirmed (attributeTypeId=SEX, codeTypeProvider=NIBRS)
# DH-SUFFIX: OperatorLicenseNumberDH, NameLastDH, etc. -- isolates DH from DL field pool
# BadgeNumber: v3.7 -- NOW ACTUALLY WIRED. This comment asserted the handler since v3.x while the
#   attribute carried NO rule in all 5 places, so dexStateUserId was EMPTY at submit and the 9 combos
#   requiring it in set[] could never match (AZ v3.6 wire: DQP log had no <BadgeNumber>, DQ fired, 7 of
#   16 Person logs FAILED). Now: attribute rule=CommsysGetDexStateUserIdRuleHandler args=['true'] +
#   hidden feeder initialValue='X' + combo defaults[] (CAD ignores form initialValue). size stays 4 per
#   AZ metadata -- a 6-char DEX id (UserName resolved MK43RS) TRUNCATES by design (Rob 2026-08-05).
#   HYPOTHESIS until a wire proves it: the registry documents this handler only for an AUTHENTICATION
#   attribute; on a QUERY attribute it is undocumented. If ignored, the feeder still fires the combo but
#   sends 'X' instead of the officer id -- read <BadgeNumber> on a Vehicle log to tell those apart.
# KeepSsn: AZ includes socialSecurityNumber in the RMS Person bundle.
# Date format: yyyyMMdd (AZ)
#
# CRITICAL: Same fieldId CANNOT appear on multiple cards -- causes Internal Server Error.
#           Shared fields (RegistrationState, dexStateUserId, RegistrationStateDH) go on shared
#           OPTIONS cards.
#
# keyRef INVENTORY (LIMITATION #21 -- ConnectCIC requires unique keyRefs per QIDM; multi-combo
# QIDMs below reuse metadata keyRefs + invented distinct keyRefs where two combos share one):
#   VehicleRegistrationQuery   : ACVR (Plate), ACVRV (VIN -- invented)
#   AzAzdpsDriverLicenseQuery  : ACWL (Badge+Name), DQN (Name -- invented), DQ (OLN), DQSS (SSN)
#   DriverHistoryQuery         : KQ (OLN), KQH (Name -- invented)
#   BoatQuery                  : ACQB (Reg+Badge), ACQBH (Hull+Badge), BQ (Reg), BQH (Hull)
#
# LABEL-OVERRIDE: LicensePlateTypeCode -- merely-defaulted convenience field (initialValue PC), no
#   routing meaning; bare label is the accepted portfolio pattern (NY/TX precedent, CHECK 15 Rule 3)
# LABEL-OVERRIDE: LicensePlateYear -- merely-defaulted convenience field (initialValue current year),
#   no routing meaning; bare label accepted (NY/TX precedent, CHECK 15 Rule 3)

$ErrorActionPreference = "Stop"
$Version = '3.10'
$currentYear = [string](Get-Date).Year
$DIR    = (Resolve-Path "$PSScriptRoot\..").Path
$OUT    = "$DIR\AZ_AZDPS_v${Version}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }
. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: AZ_AZDPS PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'AZ_AZDPS'

# QUERYRESULTDATAMAPPING (from KB specs)
$results = Build-ProviderQrdm -ProviderName 'AZ_AZDPS'

$qmf = Build-Qmf -ProviderName 'AZ_AZDPS'

# =====================================================================
# 1d. VehicleRegistrationQuery -- ACVR (Plate) + ACVRV (VIN, invented)
# =====================================================================
$vehQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber'; rule = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }; size = 4; sourceField = @('dexStateUserId'); targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';          size = 10; sourceField = @('LicensePlateNumber');          targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';        size = 2;  sourceField = @('LicensePlateTypeCode');        targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';            size = 4;  sourceField = @('LicensePlateYear');            targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State';                       size = 2;  sourceField = @('RegistrationState');           targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber'; size = 20; sourceField = @('VehicleIdentificationNumber'); targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';             size = 4;  sourceField = @('VehicleMakeCode');             targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                 size = 4;  sourceField = @('vehicleYear');                 targetField = 'VehicleYear' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Plate>VIN guardrail: VIN removed from any[] so the plate combo's serialized
                # pool never carries VehicleIdentificationNumber (VIN has its own combo ACVRV).
                # v3.8 OVER-PERMIT REMOVED: VehicleMakeCode + vehicleYear are GONE from this any[].
                # metadata Combination keyReference="ACVR" primaryFieldReference="LicensePlateNumber"
                # is Set[BadgeNumber, LicensePlateNumber] Any[LicensePlateYear, LicensePlateTypeCode,
                # State] -- it defines NEITHER make nor year. Those two belong to the SIBLING variant
                # (primaryFieldReference="VehicleIdentificationNumber"), and devdoc #1/#3 agree:
                # plate optionals are [LicensePlateTypeCode, LicensePlateYear] only.
                set = @('dexStateUserId','LicensePlateNumber')
                any = @('LicensePlateYear','LicensePlateTypeCode','RegistrationState')
                defaults = @(
                    [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' }
                    [PSCustomObject]@{ field = 'LicensePlateYear';     value = $currentYear }
                    [PSCustomObject]@{ field = 'State';                value = 'AZ' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'ACVR'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Plate>VIN guardrail: LicensePlateNumber NOT_EXISTS gates this VIN combo OUT when
                # a plate is present, so plate+VIN co-entry fires ACVR (plate) only and VIN is not
                # double-sent. Plate removed from any[] per gate-xor-companion (CHECK 14).
                # v3.8 OVER-PERMIT REMOVED: LicensePlateTypeCode + LicensePlateYear are GONE from
                # this any[], AND their combo defaults[] went with them. metadata Combination
                # keyReference="ACVR" primaryFieldReference="VehicleIdentificationNumber" is
                # Set[BadgeNumber, VehicleIdentificationNumber] Any[VehicleMakeCode, VehicleYear,
                # State] -- it defines no plate field at all, and devdoc #2/#4/#5 agree. The two
                # defaults HAD to go in the same edit: a default on a field that is in neither set[]
                # nor any[] is an INERT DEFAULT (audit_wiring_closure class E) -- removing the any[]
                # entry alone would have traded one defect for another. The portfolio
                # PlateType=PC / PlateYear=<year> standard is a PLATE-combo convention; on a VIN
                # transaction those fields are undefined, so it does not apply here.
                set = @('dexStateUserId','VehicleIdentificationNumber')
                any = @('RegistrationState','VehicleMakeCode','vehicleYear')
                defaults = @(
                    [PSCustomObject]@{ field = 'State';                value = 'AZ' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'ACVRV'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for VehicleRegistrationQuery (ACVR Plate + ACVRV VIN)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_VehicleRegistrationQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery -- the devdoc-BASIC transaction (v3.5 SCOPE CORRECTION)
# =====================================================================
# v3.5 SWITCHED TRANSACTIONS: AzAzdpsDriverLicenseQuery -> DriverLicenseQuery.
#
# The devdoc "Basic Queries Supported" section names `DriverLicenseQuery`. AZ's metadata defines BOTH
# it and an `AzAzdps`-prefixed sibling as SEPARATE transactions with DIFFERENT <Requirements>, and
# v3.3/v3.4 built the prefixed one -- out of Basic scope. It passed audit_supported_queries for months
# because that gate compared each combo's queryLabel ('Driver License', legitimately on the approved
# list) and never the transaction name; it even printed
#     [PASS] combo DQSS: 'Driver License | SocialSecurityNumber' is devdoc-supported
# which is flatly false. Closed by that tool's CHECK 0 (2026-08-04), which now blocks it.
#
# WHAT THE WRONG SIBLING COST -- concrete, not stylistic. Devdoc DriverLicenseQuery has 8 Possible
# Combinations; the prefixed transaction cannot express three of them:
#   #2 (In) BadgeNumber, BirthDate, ImageIndicator="Y", Name, Requestor, SexCode  -> metadata DQP{Name}
#   #5 (In) BadgeNumber, ImageIndicator="Y", OperatorLicenseNumber, Requestor     -> metadata DQP{OLN}
#        DQP EXISTS ONLY UNDER THE BASIC TRANSACTION. So AZ had NO driver-licence PHOTO request at all
#        -- `Requestor` appeared 0 times in the emitted JSON and the only `ImageIndicator` hit was a
#        QRDM *response* mapping. The devdoc documents the field explicitly ("Y - Request Driver
#        License Photo").
#   #3 (In) Name, [SexCode]  -> Basic DQ{Name} = Set[Name] Any[BirthDate, SexCode, State]
#        The prefixed sibling's DQ{Name} = Set[Name, SexCode, BirthDate] makes DOB **and** sex
#        MANDATORY, so an officer holding only a name could not run a DL query. THIS ALSO RETIRES the
#        v3.4 registry row asserting "metadata makes SexCode MANDATORY on every name variant ... there
#        is no looser one" -- true of the prefixed sibling, FALSE of the Basic transaction. A
#        registration whose premise is scoped to the wrong transaction is not a divergence, it is a bug.
# And what it ADDED: DQ{SocialSecurityNumber}, an SSN search the Basic devdoc does not list anywhere.
# DQSS is DELETED. The SSN form control stays -- it is consumed by the RMS person QIDM
# (firstNameLastNameSocialSecurityNumber, -KeepSsn), which audit_wiring_closure counts as reaching
# the wire, so it is not a dead control.
#
# BASIC METADATA VARIANTS, and the combo implementing each:
#   DQP {Name}                  Set[BadgeNumber, ImageIndicator, Name, Requestor] Any[BirthDate, SexCode]  -> DQPN (invented)
#   DQP {OperatorLicenseNumber} Set[BadgeNumber, ImageIndicator, OperatorLicenseNumber, Requestor]  (NO Any) -> DQP
#   ACWL{Name}                  Set[BadgeNumber, Name, SexCode, BirthDate] Any[OperatorLicenseNumber, State] -> ACWL
#   DQ  {Name}                  Set[Name] Any[BirthDate, SexCode, State]                                     -> DQN (invented)
#   DQ  {OperatorLicenseNumber} Set[OperatorLicenseNumber] Any[State]                                        -> DQ
# DQPN/DQN are invented keyRefs (LIMITATION #21) because each metadata keyRef carries two variants and
# tools resolve combos by (query, keyRef); duplicates would collide. Provider routes by field content.
#
# ORDER (first match wins): DQPN, DQP, ACWL, DQN, DQ.
#   DQ{OLN} set[] is a STRICT SUBSET of DQP{OLN} set[], so DQP must precede DQ or the photo path is
#   dead on arrival. Likewise DQN set[] is a subset of both ACWL and DQPN. Within the name/OLN pairs
#   the devdoc order (#2 before #5, #3 before #4) is honoured; they are mutually exclusive anyway via
#   the OLN>Name guardrail below, so nothing depends on that tiebreak.
#
# OLN>Name guardrail retained, SSN dropped from the cascade (OLN>SSN>Name -> OLN>Name): every Name
# combo carries OperatorLicenseNumber NOT_EXISTS so an OLN+Name over-fill sends the OLN query alone.
# Gate-xor-companion (CHECK 14) still holds -- a field that is a NOT_EXISTS gate is never also an
# any[] companion, which is why ACWL does NOT carry metadata's Any[OperatorLicenseNumber].
#
# ImageIndicator CARRIES initialValue='Y' (MANDATORY -- FIELD_REFERENCE.txt Section 9 / BUILD_RULES
# 20b: without it the field does not serialize at all, which would make DQPN/DQP permanently
# unsatisfiable since their set[] requires it). REQUESTOR is the actual discriminator: officer-entered,
# no default, so Requestor-filled routes to the photo paths and Requestor-empty falls through to
# ACWL/DQN/DQ, none of which define ImageIndicator. BUILD_RULES 24 is satisfied because NO combo
# needs ImageIndicator ABSENT -- there is no ImageIndicator NOT_EXISTS gate here, which is exactly
# what makes LA_LEMS's DP/DQ toggle a registered dead combo and this build reachable.
# (RegistrationState keeps initialValue='AZ' -- any[]-ONLY in every combo here, so it routes nothing.)
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber'; rule = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }; size = 4; sourceField = @('dexStateUserId'); targetField = 'BadgeNumber' }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        # ImageIndicator: metadata Alphabetic maxLength 1, valueListName=ImageIndicatorList
        # (Y = Request Image / N = Do not Request Image). size=1 per the ImageIndicator rule.
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        # Requestor: metadata Alphanumeric maxLength 5, mandatory on both DQP variants. AUTOMATED --
        # Rob 2026-08-04, non-negotiable. Attention feeder pattern: hidden InpH makes the field present,
        # the handler supplies officer identity, size=5 caps it.
        [PSCustomObject]@{
            name        = 'Requestor'
            rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size        = 5; sourceField = @('Requestor'); targetField = 'Requestor'
        }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode';  codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationState');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # devdoc #1 (In) and #6 (Out) -- badge + full descriptors. Badge-present gate keeps
                # ACWL from shadowing DQN's badge-absent path (metadata DQ{Name} has no BadgeNumber).
                # metadata Any also lists OperatorLicenseNumber, deliberately NOT carried: OLN is the
                # NOT_EXISTS gate here, and gate-xor-companion (CHECK 14) forbids both roles.
                set = @('dexStateUserId','BirthDate','NameLast','NameFirst','SexCode')
                any = @('nameMiddle','nameSuffix','RegistrationState')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('dexStateUserId');        operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'ACWL'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # devdoc #2 -- photo request by NAME. Implements DQP{Name} EXACTLY: metadata Any is
                # [BirthDate, SexCode] and contains NO State, so RegistrationState is deliberately
                # absent from any[] and gets no default -- adding it would OVER-PERMIT a field this
                # variant does not define.
                set = @('dexStateUserId','ImageIndicator','NameLast','NameFirst','Requestor')
                any = @('BirthDate','SexCode','nameMiddle','nameSuffix')
                # CAD IGNORES FORM initialValues (audit_cad CHECK 5), so a field carrying a form
                # default and participating in this combo needs an explicit combo default or a
                # CAD-injected query goes out without it -- and ImageIndicator is in set[] here, so
                # without this the CAD path could not satisfy the combo at all.
                defaults = @( [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'Requestor'; value = 'X' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQPN'
            state                 = 'In'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # devdoc #5 -- photo request by OLN. Implements DQP{OperatorLicenseNumber} EXACTLY:
                # metadata defines NO <Any> at all for this variant, so any[] is EMPTY and there is no
                # State default. OLN is top of the cascade, so no NOT_EXISTS gate.
                set = @('dexStateUserId','ImageIndicator','OperatorLicenseNumber','Requestor')
                any = @()
                # CAD default for the same reason as DQPN. Note this is a DEFAULT on a set[] field,
                # which is legitimate -- it is not an any[] addition, so it cannot over-permit a field
                # this variant does not define.
                defaults = @( [PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'Requestor'; value = 'X' } )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQP'
            state                 = 'In'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # devdoc #3 (In) "Name, [SexCode]" and #7 (Out). Implements Basic DQ{Name} =
                # Set[Name] Any[BirthDate, SexCode, State] -- NAME ALONE IS SUFFICIENT. This is the
                # search v3.4 could not perform: the prefixed sibling's DQ{Name} demanded Name+Sex+DOB.
                set = @('NameLast','NameFirst')
                any = @('BirthDate','SexCode','dexStateUserId','nameMiddle','nameSuffix','RegistrationState')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # devdoc #4 (In) "OperatorLicenseNumber" and #8 (Out) "+State". Implements DQ{OLN} =
                # Set[OperatorLicenseNumber] Any[State] EXACTLY.
                # v3.5 STRIPPED THE OVER-PERMITS: BirthDate and SexCode were in any[] though this
                # variant defines neither, so an OLN+DOB+sex fill transmitted two fields the
                # transaction does not define. dexStateUserId (BadgeNumber) is out for the same
                # reason -- devdoc #4 is OLN ALONE, and the badge rides only on the DQP/ACWL paths.
                set = @('OperatorLicenseNumber')
                any = @('RegistrationState')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverLicenseQuery (devdoc-Basic): DQPN/DQP photo paths + ACWL badge+Name + DQN Name-only + DQ OLN'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    queriesToDeselect  = @('DriverHistoryQuery')
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- KQ (OLN), KQH (Name, invented)
# DH-suffix isolation. RegistrationStateDH hidden with initialValue='AZ'. Date: yyyyMMdd.
# =====================================================================
$dhistQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'Attention'
            rule        = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
            size        = 30; sourceField = @('attention'); targetField = 'Attention'
        }
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
            size        = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLastDH','NameFirstDH','NameMiddleDH','NameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        # v3.5 DH-SUFFIXED: was sourceField 'purposeCode'. This is a DH-ONLY control, so AP #14 /
        # LIMITATION #25 requires the DH suffix. It went unflagged for four versions because
        # validate.ps1's DL+DH suffix check locates the DL QIDM with `query -eq 'DriverLicenseQuery'`
        # (EXACT match) -- and v3.3/v3.4 named it 'AzAzdpsDriverLicenseQuery', so $dlQidm was $null and
        # the ENTIRE check never ran on AZ. Same root cause as the CHECK 0 scope violation: the wrong
        # transaction name silently switched a gate off. Fixing the name turned the gate on, and it
        # immediately found this.
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State';                 size = 2;  sourceField = @('RegistrationStateDH');     targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN>Name guardrail (DH-suffix pool): OperatorLicenseNumberDH NOT_EXISTS gates this
                # DH Name combo OUT when a DH OLN is present, so KQ (OLN) fires alone. OLN-DH removed
                # from any[] per gate-xor-companion (CHECK 14).
                set = @('RegistrationStateDH','NameLastDH','NameFirstDH','BirthDateDH','SexCodeDH')
                any = @('attention','NameMiddleDH','NameSuffixDH','purposeCodeDH')
                # DEX-1283 v3.8: the Attention='X' default is GONE. 'attention' stays in any[] and the
                # attribute keeps CommsysGetLastNameFirstNameInitialRuleHandler -- any[] membership is
                # what feeds the handler, proven on FL/TX/CA_CLETS/NY/HI over 47 of 47 DH wires.
                defaults = @(
                    [PSCustomObject]@{ field = 'State';     value = 'AZ' }
                )
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # OLN is top of the DH OLN>Name pair -- no gate needed. Name-composite (DH-suffix)
                # removed from any[] so the OLN pool never carries the DH Name.
                # v3.5 OVER-PERMIT STRIPPED: BirthDateDH and SexCodeDH were carried here as
                # "demoted-to-any companions", but metadata KQ{OperatorLicenseNumber} =
                # Set[State, OLN] Any[PurposeCode, Attention] defines NEITHER, and devdoc
                # DriverHistoryQuery #1 brackets ONLY [Attention, PurposeCode]. Both authorities
                # agree, so an OLN+DOB+sex fill was transmitting two fields this transaction does
                # not define. The four registry rows defending it argued the UNDER-REQUIRED
                # direction (do not promote into set[]) -- correct, and not the question asked;
                # removal was never considered. They are retired.
                set = @('RegistrationStateDH','OperatorLicenseNumberDH')
                any = @('attention','purposeCodeDH')
                # DEX-1283 v3.8 -- see the KQH note above; only the literal 'X' was removed.
                defaults = @(
                    [PSCustomObject]@{ field = 'State';     value = 'AZ' }
                )
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for DriverHistoryQuery (KQ OLN + KQH Name -- DH-suffix isolation)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    # v3.5: follows the DL transaction rename. A queriesToDeselect entry naming a query that no longer
    # exists is silently INERT -- the DH card would stop deselecting DL and both would co-fire.
    queriesToDeselect  = @('DriverLicenseQuery')
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery -- ACQG (Badge+Serial)
# CAD sends camelCase serialNumber -> fieldId/sourceField/set use 'serialNumber';
# attribute name + targetField + primaryFieldReference stay 'GunSerialNumber' (wire unchanged).
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber'; rule = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }; size = 4; sourceField = @('dexStateUserId'); targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'GunCaliber';               size = 4;  sourceField = @('GunCaliber');               targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                  size = 4;  sourceField = @('GunMake');                  targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                 size = 11; sourceField = @('GunModel');                 targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';          size = 11; sourceField = @('serialNumber');             targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','serialNumber')
                any = @('GunCaliber','GunMake','GunModel','relatedHitSearchIndicator')
                # v3.10 CAD twin for the Stolen Check form default (audit_cad CHECK 6): CAD ignores form
                # initialValue, so without this a CAD-originated query carries no stolen check at all.
                defaults = @( [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'ACQG'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for GunQuery (ACQG)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery -- ACQA (Badge+Type+Serial)
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';      size = 11; sourceField = @('ArticleSerialNumber');      targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';          size = 7;  sourceField = @('ArticleTypeCode');          targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'BadgeNumber'; rule = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }; size = 4; sourceField = @('dexStateUserId'); targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set = @('dexStateUserId','ArticleTypeCode','ArticleSerialNumber')
                any = @('relatedHitSearchIndicator')
                # v3.10 CAD twin for the Stolen Check form default (audit_cad CHECK 6): CAD ignores form
                # initialValue, so without this a CAD-originated query carries no stolen check at all.
                defaults = @( [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
            }
            primaryFieldReference = 'ArticleTypeCode'
            keyReference          = 'ACQA'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for ArticleSingleQuery (ACQA)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery -- ACQB/ACQBH (Badge), BQ/BQH (no Badge)
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BadgeNumber'; rule = [PSCustomObject]@{ function = 'CommsysGetDexStateUserIdRuleHandler'; arguments = @('true') }; size = 4; sourceField = @('dexStateUserId'); targetField = 'BadgeNumber' }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';         size = 20; sourceField = @('BoatHullIdNumber');         targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';       size = 8;  sourceField = @('RegistrationNumber');       targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator';size = 1;  sourceField = @('relatedHitSearchIndicator');targetField = 'RelatedHitSearchIndicator' }
        [PSCustomObject]@{ name = 'State';                    size = 2;  sourceField = @('RegistrationState');        targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull>Reg guardrail: BoatHullIdNumber NOT_EXISTS gates this Reg combo OUT when a
                # hull is present (ACQBH fires alone). Hull removed from any[] per CHECK 14.
                set = @('dexStateUserId','RegistrationNumber')
                any = @('relatedHitSearchIndicator')
                # v3.10 CAD twin for the Stolen Check form default (audit_cad CHECK 6): CAD ignores form
                # initialValue, so without this a CAD-originated query carries no stolen check at all.
                defaults = @( [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                # v3.7: State default REMOVED. This combo is gated RegistrationState NOT_EXISTS and State is
                # no longer in its any[], so the default could never be applied -- audit_wiring_closure
                # class E (inert default). A default on a field the combo gates ABSENT is self-defeating.
                conditions = @(
                    # Badge-present gate (see ACWL): ACQB/ACQBH are the badge boat transactions;
                    # BQ/BQH are the no-badge fallbacks. dexStateUserId EXISTS stops the badge combo
                    # shadowing the no-badge combo's payload (CHECK 16).
                    [PSCustomObject]@{ field = @('dexStateUserId');    operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'ACQB'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull is top of the Hull>Reg pair -- no Hull/Reg gate. Badge-present gate (see ACQB)
                # keeps the badge/no-badge routing symmetric (ACQBH is badge, BQH is fallback).
                #
                # v3.4: RegistrationNumber RESTORED to any[]. It had been removed "so the hull pool
                # never carries the reg number", but that conflated two different things:
                #   * WHICH COMBO FIRES is the guardrail, and it is already enforced by the
                #     `BoatHullIdNumber NOT_EXISTS` condition on the Reg combos (ACQB / BQ) -- enter
                #     both and the hull combo still wins, unchanged.
                #   * WHAT THE WINNER TRANSMITS is a separate question, and BOTH authorities say
                #     carry it: metadata ACQB{BoatHullIdNumber} is
                #     Set[BadgeNumber, BoatHullIdNumber] Any[RegistrationNumber, RelatedHitSearchIndicator],
                #     and devdoc BoatQuery #1 lists RegistrationNumber as a legal optional.
                # Scrubbing it meant an officer could type a registration number the provider accepts
                # as a refinement and have it SILENTLY DROPPED -- audit_devdoc_optionals reported
                # exactly that on 4 fills ("fires ACQBH but optional(s) RegistrationNumber are in NO
                # matching combo's set[]/any[]"). Priority is about routing, never about deleting a
                # permitted field from the winner's payload.
                # NOT done in the reverse direction: BoatHullIdNumber must NOT go into the Reg combos'
                # any[], because they are gated hull-NOT_EXISTS -- a field that can never be present
                # when the combo fires is dead config (verify_build rejects gate-XOR-companion).
                set = @('dexStateUserId','BoatHullIdNumber')
                any = @('RegistrationNumber','relatedHitSearchIndicator')
                # v3.10 CAD twin for the Stolen Check form default (audit_cad CHECK 6): CAD ignores form
                # initialValue, so without this a CAD-originated query carries no stolen check at all.
                defaults = @( [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('dexStateUserId'); operator = 'EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'ACQBH'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull>Reg guardrail (no-Badge path): BoatHullIdNumber NOT_EXISTS gates this Reg
                # combo OUT when a hull is present (BQH fires alone). Hull removed from any[].
                set = @('RegistrationNumber')
                any = @('dexStateUserId','RegistrationState','relatedHitSearchIndicator')
                defaults = @( [PSCustomObject]@{ field = 'State'; value = 'AZ' } , [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                # Hull is top of the Hull>Reg pair (no-Badge path) -- no gate.
                # v3.4: RegistrationNumber RESTORED to any[], same reasoning as ACQBH above -- the
                # Hull>Reg guardrail is the `BoatHullIdNumber NOT_EXISTS` gate on BQ, not the removal
                # of a metadata-permitted, devdoc-listed optional from the winner's payload.
                set = @('BoatHullIdNumber')
                any = @('RegistrationNumber','dexStateUserId','RegistrationState','relatedHitSearchIndicator')
                # v3.10 CAD twin for the Stolen Check form default (audit_cad CHECK 6): CAD ignores form
                # initialValue, so without this a CAD-originated query carries no stolen check at all.
                defaults = @( [PSCustomObject]@{ field = 'RelatedHitSearchIndicator'; value = 'Y' } )
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }
                )
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQH'
            state                 = 'In/Out'
        }
    )
    description     = 'Mapping for BoatQuery (ACQB+ACQBH Badge, BQ+BQH no-Badge)'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'AZ_AZDPS_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'AZ_AZDPS'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}


# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43) -- MULTI-CARD
# =====================================================================

# VEHICLE -- 3 cards: OPTIONS, PLATE SEARCH, VIN SEARCH
# RegistrationState + dexStateUserId on shared OPTIONS card (no duplicate fieldIds)
# v3.2: collapsed 3 cards (OPTIONS+PLATE+VIN) -> 1. State + hidden badge fold onto the single card.
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, "OR" VIN'
        rows  = @(
            # v3.10 (Rob 2026-08-12: "on veh put state on top line and tighenten up the filed sizes"):
            # State joins the plate row and the widths tighten to [3 3 3 3]. State is any[]-only on
            # both Vehicle combos so it is shared context, not a discriminator -- putting it on the
            # top line is safe and it is where FL/NY carry it.
            @{ id = 'ROW_VEH_1'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'LicPlate_Input';  node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'PlateType_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'PlateYear_Input'; node = Inp 'LicensePlateYear' 'Plate Year' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
                @{ id = 'State_Veh_Input'; node = Sel 'RegistrationState' 'State (leave blank for AZ)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_1' }
            )}
            # v3.10: tightened [6 3 3] -> [5 4 3], which is FL_FCIC's Vehicle VIN row exactly.
            @{ id = 'ROW_VEH_2'; cols = @('5','4','3'); fields = @(
                @{ id = 'VIN_Input';       node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                # LABEL-OVERRIDE: VehicleMakeCode -- bare per DEX-1284 lean pass (any[] optional VIN qualifier)
                @{ id = 'Make_Veh_Input';  node = Sel 'VehicleMakeCode' 'Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                # LABEL-OVERRIDE: vehicleYear -- bare per DEX-1284 lean pass (any[] optional VIN qualifier)
                @{ id = 'Year_Veh_Input';  node = Inp 'vehicleYear' 'Year' '4' 'ROW_VEH_2' }
            )}
            # v3.10 STATE CONVENTION (Rob: "we want consistency"): portfolio standard, MEASURED not
            # assumed -- 17 of 20 providers label State 'State (leave blank for <ST>)' with NO
            # initialValue; only AZ, NJ and TX used bare 'State' + a home default. Label and default
            # are COUPLED: "leave blank for AZ" is only true if blank really means AZ.
            # Safe: State is any[]-ONLY on both Vehicle combos (ACVR/ACVRV), so it routes nothing.
            # WIRE DELTA, stated plainly: an in-state Vehicle query no longer auto-sends
            # <State>AZ</State>; metadata has State in <Any> so both forms are valid.
            # ROW_VEH_3 RETIRED at v3.10 -- State moved to the plate row per Rob's layout request.
            @{ id = 'ROW_VEH_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Veh'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_VEH_BADGE' @{ initialValue = 'X' } }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card (v3.2, collapsed from OPTIONS+PLATE+VIN): Plate/Type/Year, VIN/Make/Year, State, hidden badge. Plate+Badge (ACVR) and VIN+Badge (ACVRV).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# PERSON -- 2 cards (v3.3): DRIVER LICENSE + DRIVER HISTORY. (v3.2 consolidated the old 7 cards to 3;
# v3.3 then removed the WANTED/MISSING card with the out-of-Basic-scope WMPI queries.) Shared hidden
# fields fold onto the consuming card: dexStateUserId badge on DL; RegistrationStateDH (SelH) +
# Attention feeder on DH. raceCode (RMS person-search "race") lives on the DL card.
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        # v3.5: SSN dropped from the title -- it is no longer a CommSys DL search path (DQSS deleted
        # as out-of-Basic-scope); the control remains for the RMS person search only, so advertising it
        # as a DL path would be a lie on the form.
        title = 'DRIVER LICENSE SEARCH BY OLN "OR" NAME -- ADD REQUESTOR + NCIC IMAGE FOR A LICENCE PHOTO'
        rows  = @(
            # v3.10 (L9): SSN moved OFF this row. It is in NO CommSys combination -- it feeds the RMS
            # person search ONLY -- so sitting beside OLN it read as a state-query identifier and took
            # the most prominent slot on the card. OLN now shares the row with the shared-context
            # State + NCIC Image, matching FL/NY row 1 ([6 3 3] identifier + context).
            @{ id = 'ROW_PER_DL_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OLN_Per_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL_1' }
                # v3.10: portfolio State convention (17 of 20) -- hint + NO default. any[]-only on
                # all three DL combos (ACWL/DQN/DQ), so it routes nothing.
                @{ id = 'State_Per_Input'; node = Sel 'RegistrationState' 'State (leave blank for AZ)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL_1' }
                # NCIC IMAGE STAYS BLANK ON AZ, AND IT IS THE ONE ROUTING EXCEPTION -- MEASURED, NOT
                # ARGUED. Rob 2026-08-12: "ncic image should be ruled the same IF IT DOES NOT EFFECT
                # ROUTING ... use defaults everywhere where it made sense and didn't ruin in state
                # default routing". On AZ it DOES affect routing, so the caveat excludes it. Tested by
                # setting initialValue='Y' and rebuilding -- both gates FAILED immediately:
                #   [FAIL] 'DQPN' SHADOWS 'DQN' only because of prefill(s): dexStateUserId,
                #          ImageIndicator, Requestor
                #   [FAIL] 'DQP'  SHADOWS 'DQ'  only because of prefill(s): (same three)
                #   [FAIL] DEAD COMBO: DriverLicenseQuery/DQN   +   DriverLicenseQuery/DQ
                # WHY: ImageIndicator is set[]-MANDATORY on DQPN/DQP while dexStateUserId and
                # Requestor are hidden AND prefilled, so adding the third prefill collapses DQPN's
                # VARIABLE requirement to [NameLast, NameFirst] -- identical to DQN's set[] -- and
                # DQP's to [OperatorLicenseNumber], identical to DQ's. DQPN/DQP are ordered first, so
                # the plain name search and the plain OLN search both die. That is BUILD_RULES 24.
                # THE TRADE, stated: blank costs one extra click to request a photo (the officer picks
                # Y/N, which is what makes DQPN/DQP fire at all -- proven on 4 v3.9 tenant logs).
                # A default would cost the two most common DL searches. Blank is correct.
                # NOTE the portfolio rule needs this caveat: CLAUDE.md's "ImageIndicator needs an
                # initialValue" holds where the field is any[]-only, which is true on FL/IL/NJ/NY/TX
                # (all Person='Y', other entities='N'). AZ is the only provider where it sits in
                # set[] as the photo discriminator, and there BUILD_RULES 24 outranks it.
                @{ id = 'ImageInd_Per_Sel'; node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_PER_DL_1' }
            )}
            # v3.10 (L8): First BEFORE Last, portfolio convention. The wire is UNAFFECTED -- the
            # composite Name attribute keeps sourceField order [NameLast, NameFirst, ...] with
            # FormatStringRuleHandler, which is what emits ConnectCIC LAST-first. Form-control order
            # and QIDM sourceField order are independent (wire-proven on IL v2.2).
            # v3.10 (L7): 'MI' -> 'Middle Name'. The field is maxLen=20, i.e. a full middle name;
            # 'MI' means middle INITIAL and misrepresented capacity. FL keeps 'MI' only because its
            # equivalent field is maxLen=1. All four name parts now share one row (L8).
            @{ id = 'ROW_PER_DL_2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirst_Input';  node = Inp 'NameFirst' 'First Name' '20' 'ROW_PER_DL_2' }
                @{ id = 'NameLast_Input';   node = Inp 'NameLast'  'Last Name'  '30' 'ROW_PER_DL_2' }
                # LABEL-OVERRIDE: nameMiddle -- bare "Middle Name" per DEX-1284 lean pass (any[] optional); v3.10 renamed from "MI" because maxLen=20 is a full middle name, not an initial
                @{ id = 'NameMiddle_Input'; node = Inp 'nameMiddle' 'Middle Name' '20' 'ROW_PER_DL_2' }
                # LABEL-OVERRIDE: nameSuffix -- bare "Suffix" per DEX-1284 lean pass (any[] optional)
                @{ id = 'NameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix'       '4' 'ROW_PER_DL_2' }
            )}
            # v3.10: DOB + Sex are CommSys qualifiers (both in ACWL's set[]) and stay with the
            # name group they qualify.
            @{ id = 'ROW_PER_DL_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input';  node = Dt  'BirthDate'  'Date of Birth'  'ROW_PER_DL_3' }
                @{ id = 'SexCode_Input';    node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_3' }
            )}
            # v3.10 (L9): the RMS-ONLY row. Neither SSN nor Race appears in ANY CommSys combination
            # -- both feed only the RMS person search -- so they are grouped together and kept OFF
            # any row carrying a mandatory state identifier. Previously SSN sat beside OLN (reading
            # as a state identifier) and Race beside RegistrationState.
            @{ id = 'ROW_PER_DL_4'; cols = @('6','6'); fields = @(
                # LABEL-OVERRIDE: SocialSecurityNumber -- bare "SSN" (RMS-only person-search field)
                @{ id = 'SSN_Per_Input';  node = Inp 'SocialSecurityNumber' 'SSN' '9' 'ROW_PER_DL_4' }
                # LABEL-OVERRIDE: raceCode -- bare "Race" (any[]/RMS-only person-search field; relocated from the removed WMPI card, v3.3)
                @{ id = 'RaceCode_Input'; node = Sel 'raceCode' 'Race' @{ attributeTypeId = 'RACE'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL_4' }
            )}
            # v3.5 -- the DRIVER LICENCE PHOTO path (devdoc #2 / #5, metadata DQP).
            # ImageIndicator CARRIES initialValue='Y' AND THAT IS MANDATORY, not a style choice:
            # FIELD_REFERENCE.txt Section 9 / BUILD_RULES 20b -- without a FormSelect initialValue it
            # DOES NOT SERIALIZE AT ALL. My first cut left it blank, reasoning that a set[] member is a
            # routing field and BUILD_RULES 24 forbids prefilling one. That would have shipped DQPN and
            # DQP permanently unsatisfiable: their set[] requires ImageIndicator, and an unserialized
            # field is never present, so neither photo combo could EVER fire. Two paths that look built
            # and cannot run is strictly worse than the v3.4 state of not having them.
            # REQUESTOR IS THE REAL DISCRIMINATOR. It is officer-entered with NO default, so:
            #   Requestor filled -> DQPN/DQP match -> photo request (ImageIndicator rides as Y)
            #   Requestor empty  -> ACWL/DQN/DQ match -> ordinary DL search; none of those variants
            #                       defines ImageIndicator, so the Y never reaches the wire
            # BUILD_RULES 24 is satisfied because NO combo needs ImageIndicator ABSENT -- there is no
            # ImageIndicator NOT_EXISTS gate anywhere in this build. That distinction is the whole
            # rule: LA_LEMS gates DP on ImageIndicator EXISTS and DQ on NOT_EXISTS, and its DQ is a
            # registered dead combo precisely because the prefill makes the field always-present.
            # Left visible and un-automated: exposing a field before automating it is the standing rule.
            # v3.10 (L5): ImageIndicator MOVED to row 1 beside OLN + State. It had a whole 12-column
            # row to itself for a two-option dropdown, which it cannot use; FL and NY both carry it at
            # [3] in the identifier row. Its initialValue='Y' and every word of the reasoning above is
            # UNCHANGED -- only the row and width moved. Row ROW_PER_DL_5 is retired.
            # Requestor HIDDEN + handler-fed. ORDERING IS WHAT KEEPS THIS SAFE: because Requestor and
            # ImageIndicator are BOTH always-present, DQPN's variable requirement is only badge+Name --
            # a strict subset of ACWL's badge+Name+DOB+Sex. ACWL is therefore ordered FIRST (Option A):
            # most-specific-first, and the devdoc agrees since item #1 precedes the #2 photo variant.
            # Ordered the other way, ACWL is a dead combo -- measured, not theorised.
            @{ id = 'ROW_PER_DL_REQ'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Requestor_Per'; node = InpH 'Requestor' 'Requestor (auto)' '5' 'ROW_PER_DL_REQ' @{ initialValue = 'X' } }
            )}
            @{ id = 'ROW_PER_DL_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_Per'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_PER_DL_BADGE' @{ initialValue = 'X' } }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # v3.10: OLN 8 -> 6 (maxLen=20 needs no more than half a row; FL/NY both use 6) and
            # Purpose Code 4 -> 3, matching the [6 3 3] identifier-row shape used everywhere else.
            # The third slot is empty here because DH's State is HIDDEN (see ROW_PER_DH_STEDH).
            # v3.10 -- STATE IS NOW VISIBLE, and it should never have been hidden.
            # Rob 2026-08-12: "i don't think we should ever hide a state fiedl why was this done?"
            # He was right, and BOTH authorities say so:
            #   DEVDOC (query authority), DriverHistoryQuery -- Basic Queries Supported, line 97:
            #     1. (In/Out) OperatorLicenseNumber, State, [Attention, PurposeCode]
            #     2. (In/Out) BirthDate, Name, SexCode, State, [Attention, PurposeCode]
            #   Both combinations are (In/Out) and State is UNBRACKETED = required and officer-supplied.
            #   METADATA (field authority), raw <Requirements> per <Combination> -- the sanctioned
            #   raw-XML exception -- both KQ variants put <Field reference="State"/> directly inside
            #   <Set>: mandatory, no <Choice>, no nested <Set>. There is NO separate out-of-state
            #   transaction and no in/out keyRef fork, so State is ALWAYS sent and its VALUE selects
            #   the destination.
            # The clincher is the contrast on this same provider: DriverLicenseQuery's devdoc splits
            # (In) combos #1-#5 (NO State at all) from (Out) combos #6-#8 (State present). AZ's devdoc
            # DOES distinguish in/out where that is the design -- and for DH it deliberately does not.
            # WHY IT WAS HIDDEN, from AZ's own BUILD_NOTES at v1.1 (2026-04-20), the FIRST build:
            #   "DH hidden state: InpH fieldId='StateDH', initialValue='AZ' (mandatory in KQ/KQH set[])"
            # i.e. "the field is mandatory, so guarantee it is present by prefilling and hiding it."
            # Same wrong move as the ImageIndicator case (usx-build 6b) -- except here it buys NOTHING
            # and costs a documented capability: out-of-state driver history was UNREACHABLE, both
            # devdoc combinations' (Out) half dead. It then survived because CLAUDE.md wrote it up as a
            # feature ("RegistrationStateDH hidden SelH") -- a record became its own justification.
            # initialValue='AZ' is KEPT and is SAFE under BUILD_RULES 24: no AZ combination requires
            # State ABSENT and there is no NOT_EXISTS gate on it anywhere (verified, 0 occurrences), so
            # the prefill cannot shadow one path over another. In-state stays one-click; the officer
            # changes it for out-of-state. maxLength=2 per the devdoc size row; QIDM targetField='State'.
            # Row shape [6 3 3] matches FL/NY's DH row 1 exactly (OLN | State | Purpose Code).
            @{ id = 'ROW_PER_DH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OLN_DH_Input';     node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH_1' }
                # v3.10 STATE CONVENTION -- DH is the ONE case that cannot take the "leave blank"
                # hint, because State is set[]-MANDATORY on both KQ combos: blank means the query
                # cannot fire, so "leave blank for AZ" would be a lie. FL_FCIC is the only other
                # provider with a mandatory DH State and it uses exactly this -- blank, labelled
                # 'State (required)', no default. Adopted verbatim so the two agree.
                # The AZ default is dropped for the same reason it was wrong to HIDE the field: it
                # silently pinned every driver-history query to Arizona. The officer now picks.
                @{ id = 'StateDH_Input';   node = Sel 'RegistrationStateDH' 'State (required)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DH_1' }
                @{ id = 'Purpose_DH_Input';  node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DH_1' }
            )}
            # v3.10 (L8 + L7): First BEFORE Last, all four name parts on one row, and 'MI' ->
            # 'Middle Name' because the field is maxLen=20. Wire unaffected: the composite NameDH
            # attribute keeps its own sourceField order, which is what emits LAST-first.
            @{ id = 'ROW_PER_DH_2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH' 'First Name' '20' 'ROW_PER_DH_2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'  'Last Name'  '30' 'ROW_PER_DH_2' }
                # LABEL-OVERRIDE: NameMiddleDH -- bare "Middle Name" per DEX-1284 lean pass (any[] optional); v3.10 renamed from "MI" because maxLen=20 is a full middle name, not an initial
                @{ id = 'NameMiddleDH_Input'; node = Inp 'NameMiddleDH' 'Middle Name' '20' 'ROW_PER_DH_2' }
                # LABEL-OVERRIDE: NameSuffixDH -- bare "Suffix" per DEX-1284 lean pass (any[] optional)
                @{ id = 'NameSuffixDH_Input'; node = Inp 'NameSuffixDH' 'Suffix'       '4' 'ROW_PER_DH_2' }
            )}
            # v3.10 (L2): DOB + Sex on their own row. Both are MANDATORY in KQH's set[], and they had
            # been sharing a row with the optional middle name and suffix -- so the officer met two
            # optional boxes before reaching two required ones. Mandatory fields lead.
            @{ id = 'ROW_PER_DH_3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input';  node = Dt  'BirthDateDH'  'Date of Birth'  'ROW_PER_DH_3' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'SexCodeDH' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH_3' }
            )}
            # v3.10: ROW_PER_DH_STEDH RETIRED -- RegistrationStateDH moved to the visible row 1 above.
            # DH remains self-contained via its own DH-suffixed field pool + the Attention feeder.
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_DH_Input'; node = InpH 'attention' 'Attention (auto)' '30' 'ROW_PER_DH_ATTN' }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 2 cards (v3.3): DRIVER LICENSE (OLN/SSN/Name/DOB/Sex/State/Race + hidden badge) + DRIVER HISTORY (DH-suffix + hidden StateDH/Attention). WMPI Wanted/Missing removed v3.3 (out of devdoc Basic Queries Supported scope); Race relocated to the DL card for RMS person search.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# FIREARM -- 1 card
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL NUMBER'
        rows  = @(
            # v3.10 (L5 + L3): Serial Number was alone on a 12-column row at maxLen=11, and the hidden
            # badge row sat BETWEEN it and the make/model/caliber group, splitting fields that belong
            # together. Serial now leads its own group at [6] and the badge row moved to the bottom.
            # v3.10 (Rob: "alos move stolen cehck to top line"): Serial + Stolen Check share row 1 at
            # [8 4]. Stolen Check stays BLANK by design -- relatedHitSearchIndicator is any[] OPTIONAL
            # on ACQG, so unlike ImageIndicator (set[]) it needs no default and must not read
            # "required". LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284.
            @{ id = 'ROW_GUN_1'; cols = @('8','4'); fields = @(
                @{ id = 'Serial_FA_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                @{ id = 'RelHit_FA_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                # LABEL-OVERRIDE: GunMake -- bare per DEX-1284 lean pass (any[] optional)
                @{ id = 'Make_FA_Input';   node = Sel 'GunMake'    'Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                # LABEL-OVERRIDE: GunModel -- bare per DEX-1284 lean pass (any[] optional)
                @{ id = 'Model_FA_Input';  node = Inp 'GunModel'   'Model'   '11' 'ROW_GUN_2' }
                # LABEL-OVERRIDE: GunCaliber -- bare per DEX-1284 lean pass (any[] optional)
                @{ id = 'Cal_FA_Input';    node = Sel 'GunCaliber' 'Caliber' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
            )}
            # ROW_GUN_3 RETIRED at v3.10 -- Stolen Check moved to row 1.
            # v3.10 (L3): hidden rows LAST. Was row 2 of 4, splitting serial from make/model/caliber.
            @{ id = 'ROW_GUN_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_FA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_GUN_BADGE' @{ initialValue = 'X' } }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm queries -- ACQG (Badge+Serial required).'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# ARTICLE -- 1 card
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY TYPE + SERIAL NUMBER'
        rows  = @(
            # v3.10 (Rob: "article all 3 on top line"): Type + Serial + Stolen Check on one row at
            # [4 5 3]. Type and Serial are BOTH mandatory in ACQA's set[]; Stolen Check is any[]
            # OPTIONAL and stays BLANK by design -- no default, and it must not read "required".
            # LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
            @{ id = 'ROW_ART_1'; cols = @('4','5','3'); fields = @(
                @{ id = 'Type_ART_Input';   node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
                @{ id = 'Serial_ART_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '11' 'ROW_ART_1' }
                @{ id = 'RelHit_ART_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_1' }
            )}
            # v3.10 (L3): hidden rows LAST. Was row 2 of 3, between the identifiers and Stolen Check.
            @{ id = 'ROW_ART_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_ART'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_ART_BADGE' @{ initialValue = 'X' } }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article queries -- ACQA (Badge+TypeCode+Serial required).'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# BOAT -- 3 cards: OPTIONS, REGISTRATION, HULL
# RegistrationState + dexStateUserId on shared OPTIONS card (no duplicate fieldIds)
# v3.2: collapsed 3 cards (OPTIONS+REGISTRATION+HULL) -> 1. Both identifiers on row 1, State + Stolen
# Check on row 2, hidden badge.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY REGISTRATION NUMBER, "OR" HULL ID'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'Reg_BOA_Input';  node = Inp 'RegistrationNumber' 'Registration Number' '8'  'ROW_BOA_1' }
                @{ id = 'Hull_BOA_Input'; node = Inp 'BoatHullIdNumber'   'Hull ID Number'      '20' 'ROW_BOA_1' }
            )}
            # v3.10 (L6): [4 4] -> [6 6] so the shared-context row tiles the full width.
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                # LABEL-OVERRIDE: RegistrationState -- bare "State" (NJ pattern); initialValue=AZ kept
                # v3.7: initialValue='AZ' REMOVED -- LIMITATION #30. State is now the Boat in/out ROUTING
                # discriminator. Prefilled, ACQB's variable requirement collapsed to [RegistrationNumber],
                # IDENTICAL to BQ's, and ACQBH's to [BoatHullIdNumber], identical to BQH's -- four exact
                # collisions no ordering can separate, which is what made BQ/BQH dead combos. Metadata
                # supplies the discriminator: ACQB/ACQBH are the badge/NCIC in-state variants, BQ/BQH
                # carry State in <Any> (the Nlets out-of-state path). Blank => in-state, filled => OOS.
                @{ id = 'State_BOA_Input';  node = Sel 'RegistrationState' 'State (leave blank for AZ)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                # LABEL-OVERRIDE: relatedHitSearchIndicator -- "Stolen Check" per DEX-1284 (any[] optional)
                @{ id = 'RelHit_BOA_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
            @{ id = 'ROW_BOA_BADGE'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'dexStateUserId_BOA'; node = InpH 'dexStateUserId' 'Badge (auto)' $null 'ROW_BOA_BADGE' @{ initialValue = 'X' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card (v3.2, collapsed from OPTIONS+REGISTRATION+HULL): Reg/Hull, State/Stolen Check, hidden badge. ACQB/ACQBH (Badge) and BQ/BQH (no Badge).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm, $firearmsForm, $articleForm, $boatForm)

# =====================================================================
# BUNDLE 3: RMS (from KB specs -- PascalCase USx fields, KeepSsn, registrationState/autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -KeepSsn -PascalCaseUsxFields `
    -Description "Provider configuration for AZ_AZDPS v${Version} -- RMS bundle"

# =====================================================================
# FINAL ASSEMBLY
# =====================================================================
$provBundle = [PSCustomObject]@{
    name           = 'AZ_AZDPS'
    type           = 'BUNDLE'
    description    = "Provider configuration for AZ_AZDPS v${Version}"
    configurations = @($auth, $results, $qmf, $vehQuery, $dlQuery, $dhistQuery, $gunQuery, $artQuery, $boatQuery)
    provider       = 'AZ_AZDPS'
}

# =====================================================================
# v3.7 -- CAD DEFAULT FOR THE BADGE, applied to EVERY combo that carries it
# =====================================================================
# CAD ignores form initialValue entirely (audit_cad CHECK 5), so a combo that lists dexStateUserId --
# and on AZ NINE of them require it in set[] -- cannot be satisfied by a CAD-injected query unless the
# combo itself defaults it. AZ is the only provider in the portfolio that puts the badge in a set[].
#
# WHY A LOOP AND NOT NINE HAND-EDITS: audit_cad named nine combos across five QIDMs, two of which had
# no defaults array at all. Nine separate edits is nine chances to miss one, and a PARTIAL fix here is
# worse than none -- it leaves some entities unreachable under CAD while the board reads green. This is
# also exactly how the original defect survived: the BadgeNumber attribute needed the same change in
# FIVE places and got it in none. Deriving the list from the combos themselves cannot miss one, and it
# keeps working if a badge-carrying combo is added later.
foreach ($cfg in $provBundle.configurations) {
    if ($cfg.type -ne 'QUERYINPUTDATAMAPPING') { continue }
    foreach ($cm in @($cfg.combinations)) {
        $pool = @(@($cm.requirements.set) + @($cm.requirements.any)) | Where-Object { $_ }
        if ($pool -notcontains 'dexStateUserId') { continue }
        $existing = @($cm.requirements.defaults | Where-Object { $_ } | ForEach-Object { "$($_.field)" })
        if ($existing -contains 'BadgeNumber') { continue }
        $badgeDef = [PSCustomObject]@{ field = 'BadgeNumber'; value = 'X' }
        if ($cm.requirements.PSObject.Properties.Name -contains 'defaults' -and $cm.requirements.defaults) {
            $cm.requirements.defaults = @(@($cm.requirements.defaults) + $badgeDef)
        } else {
            $cm.requirements | Add-Member -NotePropertyName defaults -NotePropertyValue @($badgeDef) -Force
        }
    }
}

$final = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

# =====================================================================
# OUTPUT
# =====================================================================
Write-ProviderJson -BundleObject $final -OutPath $OUT `
    -Label "Built AZ_AZDPS v${Version} (single-JSON consolidation, native PascalCase USx fields, GunQuery serialNumber CAD fix, KeepSsn)" `
    -Version $Version
