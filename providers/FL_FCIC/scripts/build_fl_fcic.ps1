# build_fl_fcic.ps1 -- FL_FCIC
# Builds FL_FCIC.json from source\FL_FCIC.xml metadata + KB specs.
#
# v7.12 (2026-07-28, entity display-order change -- direct Rob feedback): default entity order
#   Person-first -> Vehicle-first (@('Person','Vehicle',...) -> @('Vehicle','Person','Firearm',
#   'Article','Boat')), so the default variant now matches the CAD_DISPATCH/FIRST_RESPONDER
#   variants (both already Vehicle-first). Order-array-only -- no QIF/QIDM/combo/routing/field/
#   label change; every per-entity fingerprint is byte-identical to v7.11, so the CommSys wire
#   for all 5 entities is unchanged. Still a version bump -> full test-package reset (block by
#   version); the v7.11 Vehicle captures (24 PASS) archive and re-capture at v7.12 (identical
#   wire expected).
# v7.11 (2026-07-28, UI/label-review pass -- direct Rob feedback, NO functional change): four
#   cosmetic label fixes surfaced reviewing the rendered v7.10 form before its tenant sweep.
#   (1) Boat card title was bare "BOAT SEARCH" (only card missing its query paths) ->
#   "BOAT SEARCH BY HULL ID, \"OR\" REGISTRATION NUMBER, \"OR\" COAST GUARD DOC #, \"OR\" NCIC
#   NUMBER, \"OR\" PCN" (matches Firearm/Article enumerated-path style). (2) Person DH BirthDate
#   label "DOB" -> "Date of Birth" (unifies with the DL card; pure cosmetic, same FormDate).
#   DH "MI" DELIBERATELY KEPT -- nameMiddleDH is a genuine 1-char middle-initial field (maxLen=1)
#   vs DL's full nameMiddle (maxLen=30); "MI" is accurate, "Middle Name" would misrepresent it.
#   (3) Vehicle lean-strip: VIN "(or search by Plate)" dropped (set[]-required, card title carries
#   the path); Vehicle Make/Year "(By VIN optional)" dropped -> bare (any[]-only, LABEL-OVERRIDE
#   tags added; matches the NY/TX DEX-1284 lean convention Vehicle hadn't yet received).
#   (4) Person DH State was bare "State" -> "State (required)" -- DH is OOS-only so State is a
#   mandatory destination (set[] in both KQ combos), NOT the "leave blank for FL" in/out toggle.
#   Label-only, no combo/QIDM/routing/fieldId/default change. ALL 5 ENTITIES stay RESET (already
#   reset at v7.10, never captured) -- re-test from T1.
# v7.9 (2026-07-27, DEX-1284 relabel/naming-convention pass -- direct Rob feedback, NO functional
#   change): applied the portfolio conventions established on NY/TX. OLN (OperatorLicenseNumber DL
#   "License Number (or search by Name + DOB)" + OperatorLicenseNumberDH "Driver License Number" ->
#   "OLN"). Canonical bare "NCIC Image" on every image field (Vehicle/DL/Gun/Article/Boat -- was
#   "NCIC Image - if available" / DL "Image (optional)"; this overrides the old FL-only
#   "- if available" wording, now superseded by the global DEX-1284 convention). Boat stolen toggle
#   "Y for NCIC stolen-boat check" -> "Stolen Check" (LABEL-OVERRIDE, any[] optional). DL card title
#   -> "Driver License Search by OLN, \"OR\" Name". Lean cross-reference strips: DL BirthDate/Sex
#   drop "(required with Name)" (both set[]-required on the Name combo); Gun Make drops
#   "(incl w/Serial Num only - optional)" -> bare (LABEL-OVERRIDE, any[]); Article Serial/OAN drop
#   "(with Article Type)"; Boat Reg drops "(or use Hull ID)". DL layout unchanged -- Rob confirmed
#   OLN + State + NCIC Image stay together on the top row (mirrors FL's own DH top row + the NY
#   model; NOT the TX "OLN alone" form, since FL carries State/Image on the DL card). Shadow-query
#   review: FL is the in/out-gating reference (existence-only State + OLN + Hull gates already
#   complete since v6.x/v7.x) -- nothing to remove. Label/title-only, no combo/QIDM/routing/fieldId/
#   default change. ALL 5 ENTITIES RESET for re-test at v7.9 (block by version).
# v7.8 (2026-07-20): Firearm CAD auto-population fix (direct feedback, mirrors NY_NYSPIN_EJUSTICE
#   v4.10 + CA_CLETS v2.9 precedent). CAD sends the gun serial number as the camelCase field
#   'serialNumber', not the PascalCase USx token 'GunSerialNumber' -- so the USx-query button in a
#   CAD event never populated the Firearm form (worked for Person, failed for Firearm). Changed the
#   form fieldId, the GunQuery QIDM sourceField, and the combo set[] from 'GunSerialNumber' to
#   'serialNumber'; the QIDM attribute name + targetField stay 'GunSerialNumber' (the XML element
#   name is unchanged, so the wire request is identical). Firearm re-tests from T1; Person/Vehicle/
#   Article/Boat unaffected (no functional change -- fingerprints unchanged, stay preserved).
# v7.7 (2026-07-16): Boat label cleanup (direct feedback, no ticket). RegistrationState_Input
#   "Destination State (blank for FL, required for name/DOB)" -> "State (leave blank for FL)"
#   (kept the minimal hint verify_build CHECK 15 Rule 1 requires on every State-suffixed field --
#   still enforced, unlike the relaxed DH-tag rule -- confirmed with Rob rather than dropping it
#   to a bare "State" which would FAIL). RelatedHitSearchIndicator_Input "Stolen Search (Y for
#   NCIC stolen-boat check)" -> "Y for NCIC stolen-boat check" (label becomes what was in the
#   parens). Dropped "Owner" from NameFirst_Input/NameLast_Input/BirthDate_Input ("Owner First
#   Name (out-of-state)" -> "First Name (out-of-state)", etc.). Label-only. Boat re-tests from
#   T1; Person/Vehicle/Article stay blocked at v7.6; Firearm stays open/PENDING at v7.6.
# v7.6 (2026-07-16): Article card cosmetic pass (DEX-1281, Gordon Hallof UX feedback) + Boat
#   direct-feedback restructuring (no ticket, mirrors the Article/Vehicle/Person patterns).
#   Article: card title -> "ARTICLE QUERY by Serial Number, "OR" Owner Applied Number, "OR"
#   NCIC Number, "OR" PCN"; split the old 4-field row into Serial Number + Owner Applied Number
#   (own row) and Article Type + Image (row below); dropped "(required)" from Article Type;
#   ImageIndicator -> "NCIC Image - if available" (matches Firearm v7.3/Vehicle v7.4). Boat:
#   collapsed from 2 cards to 1 -- merged CARD_BOA_OPT (DestState+Stolen+Image) into
#   CARD_BOA_SEARCH as a new bottom row (Boat didn't free up an existing row like Vehicle did,
#   so this is an added row, not a merge into one); reordered the owner NameLast/NameFirst
#   fields to First-then-Last (matching Person v7.5); ImageIndicator -> "NCIC Image - if
#   available". Both label/layout-only, no combo/QIDM/wire change. Article + Boat re-open for
#   live re-test (first time either has been touched this session); Person/Firearm/Vehicle stay
#   open/PENDING at v7.5, untouched by this rebuild.
# v7.5 (2026-07-16): Direct feedback (not a DEX ticket), two layout fixes. (1) Person CARD_DL
#   ROW_DL2 Name field order was still Last/First/Middle -- inconsistent with CARD_DH's ROW_DH2,
#   reordered to First/Last/MI in v7.2 (DEX-1278). Swapped NameFirst_Input/NameLast_Input order
#   to match (First, Last, Middle) -- label/fieldId/sourceField unchanged, pure visual reorder;
#   wire Name format (Last-first, FormatStringRuleHandler) unaffected either way. (2) Vehicle
#   collapsed from 2 cards to 1 -- merged CARD_VEH_OPT (State+Image) into CARD_VEH_SEARCH,
#   moved RegistrationState_Input + ImageIndicator_Input onto the bottom row alongside
#   DecalNumber_Input (freed up solo by v7.4's Title/Lien removal). No combo/QIDM/label change,
#   pure card/row restructuring. Person + Vehicle re-test from T1; Firearm stays open/PENDING at
#   v7.3 untouched; Article/Boat preserved blocked at v7.1.
# v7.4 (2026-07-16): Vehicle card cosmetic pass + intentional combo removal (DEX-1279, Gordon
#   Hallof UX feedback). Card title "Vehicle Search" -> "Vehicle Registration Search by License
#   Plate, "OR" VIN, "OR" Decal". Dropped "(or search by VIN/Decal)" from Plate Number (card
#   title now carries that context); "(out-of-state plates)" -> "(out-of-state)" on Plate
#   Type/Year; "(optional)" -> "(By VIN optional)" on Vehicle Make/Year. ImageIndicator "Image
#   (optional)" -> "NCIC Image - if available" -- FL-ONLY, deliberately NOT a global
#   verify_build/BUILD_RULES change this time (Gordon flagged this one has portfolio-wide
#   implications for Vehicle image labeling across all USx regions and wants to discuss before
#   it's rolled out anywhere else; hyphenated wording chosen to match the already-shipped
#   Firearm v7.3 label and satisfy CHECK 15 Rule 3 without any gate change).
#   REMOVED TitleLienInformation field + the FRQTitleLienInformation combo entirely (was a
#   live, devdoc-order-position-3-of-4, 100%-covered combo) -- Gordon's "Remove Title/Lien info
#   all together" is a deliberate product/UX decision to sunset that whole query path, not a
#   label cleanup. Documented as an approved-skip divergence (FL_FCIC_ACCEPTED_DIVERGENCES.txt +
#   FL_FCIC_SQVR.txt), same as the existing QV/QW not-built entries -- combo count 31 -> 30.
#   Vehicle re-tests from T1; Article/Boat stay preserved blocked at v7.1; Firearm/Person
#   unaffected (already open/PENDING from v7.3/v7.2).
# v7.3 (2026-07-16): Firearm card cosmetic pass (DEX-1280, Gordon Hallof UX feedback).
#   Card title "FIREARM QUERY" -> "FIREARM Query by Serial Number, "OR" NCIC Number, "OR" PCN".
#   GunSerialNumber label "Serial Number (or use NCIC#/PCN)" -> "Serial Number" (card title now
#   carries that context, same pattern as v7.2's Person DH change). GunMake "Gun Make
#   (optional)" -> "Gun Make (incl w/Serial Num only - optional)". ImageIndicator "Image
#   (optional)" -> "NCIC Image - if available". No gate conflicts (GunSerialNumber is in set[]
#   so exempt from the any[]-only hint rule regardless of wording; GunMake/ImageIndicator keep a
#   qualifier). Label-only, no combo/QIDM/wire change. Firearm re-tests from T1; Vehicle/Article/
#   Boat stay preserved blocked at v7.1; Person unaffected (already open/PENDING from v7.2).
# v7.2 (2026-07-16): Person DH card cosmetic pass (DEX-1278, Gordon Hallof UX feedback).
#   Card title "Driver History (Out-of-State Only)" -> "Driver History (Out-of-State) By
#   Name "OR" Drivers License Number". Dropped "(DH)"/"required with Name" qualifiers from
#   all 6 DH-suffix field labels (License Number, Destination State, Purpose Code, Last/First
#   Name, DOB, Sex) -- the new card title now carries the DH-vs-DL disambiguation that the
#   per-field tags used to (verify_build CHECK 15 Rule 2 downgraded FAIL->Info this session,
#   see BUILD_RULES Section 11 point 7). Reordered ROW_DH2 to First/Last/MI/DOB/Sex (was
#   Last/First/DOB/Sex) and added a new nameMiddleDH field ("MI") -- visible-only, NOT wired
#   into the KQName combo or the Name attribute's sourceField, mirroring the DL card's
#   existing unwired nameMiddle/nameSuffix fields. Label-only + one new unwired field --
#   no combo/QIDM/wire behavior change. Person re-tests from T1; Vehicle/Article/Boat/Firearm
#   fingerprints unchanged, preserved blocked at v7.1.
# v7.0 (2026-06-29): OOS-gate symmetry hardening (defense-in-depth, NO behavior/XML change).
#   Added RegistrationState EXISTS to the 3 zero-condition OOS combos -- RQLicensePlateNumber +
#   DQOperatorLicenseNumber (RegistrationState) and KQOperatorLicenseNumber (RegistrationStateDH).
#   These were the only combos in Vehicle/Person relying on set[] alone with no condition; set[] is
#   NOT a firing gate, so making the OOS-routing explicit mirrors the in-state combos' State NOT_EXISTS
#   and the Boat QB relatedHit EXISTS (v6.9). Rule: in-state => State NOT_EXISTS; OOS => State EXISTS.
#   Reevaluation found Vehicle (Plate>VIN) + Person (OLN>Name) had NO bleed and NO active shadow
#   (CHECK 12/14/16 already PASS); this is reorder-safety insurance, not a fix. Sim-verified routing
#   unchanged. Rebuild -> Vehicle/Person/Boat re-test from T1; Article/Firearm preserved.
# v6.9 (2026-06-29): Boat Hull>Reg guardrail EXTENDED to QB (stolen) + BQ (OOS) families.
#   QBRegistrationNumber and BQRegistrationNumber were "companion" combos (carried Hull in any[],
#   CHECK 12 exempt) -- but their set[] is satisfied by the same Hull+Reg input that fires the Hull
#   combo, making them latent shadows that stay dormant only by array order (live-proven single
#   dispatch, Boat T43). Converted both to "gated": added BoatHullIdNumber NOT_EXISTS condition +
#   removed Hull from their any[]. Also de-bled the Hull combos (QBBoatHullIdNumber/BQBoatHullIdNumber)
#   by removing RegistrationNumber from their any[]. FBQ family already gated (v6.0). Hull = unique
#   permanent identifier (HIN), Reg = reassignable -> Hull wins. Per BUILD_RULES GATE-XOR-COMPANION
#   + verify_build CHECK 12. ALSO (CHECK 16 shadow exposed by the new conditions): added
#   relatedHitSearchIndicator EXISTS to QBBoatHullIdNumber + QBRegistrationNumber -- set[] is not a
#   firing gate, so the QB combos were latently shadowing the BQ OOS Hull/Reg combos; the EXISTS
#   gate makes Stolen-routing explicit (mirrors FBQ relatedHit NOT_EXISTS). Same fix pattern as
#   CA_CLETS NLTS.DQ v2.11. Rebuild -> Boat entity re-test from start (full re-test mandate).
# v6.8 (2026-06-29): VehicleMakeName QRDM code source corrected VEHICLE/VehicleType ->
#   attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; shared module propagation;
#   matches NJ v4.7/HI v4.6/CA v2.10 fix). Fixes FL vehicle "Mock results processed" in RMS.
#   DH label qualification fix: RegistrationStateDH/purposeCodeDH/BirthDateDH labels now
#   include '(DH, ...)' qualifier (verify_build DH disambiguation rule, BUILD_RULES Sec 11).
#   Re-import + full re-test from T1.
# v6.5 (2026-06-23): Gap-audit remediation. (1) CAD Attention-default gap -- KQName and
#   KQOperatorLicenseNumber (DH) carry 'Attention' in any[] (auto-populate handler) but had NO
#   defaults[] entry, so CAD-dispatched DH queries dropped the officer's Attention value. Added
#   Attention=X combo default to both (audit_cad CHECK 6). (2) CAD plate-default gap -- FRQDecalNumber
#   (set: decal+plateYear) and RQLicensePlateNumber (set: plate+type+year+state) require PlateYear/
#   PlateType in set[] but CAD ignores form initialValue; added LicensePlateYear=$currentYear and
#   RQ LicensePlateTypeCode=PC defaults (surfaced by audit_cad CHECK 6 set[]-scan fix). (3) Header
#   conditions comment corrected: conditions[].field is the QIF sourceField, NOT the attribute name.
#   Re-import + full re-test (Person + Vehicle re-open). Part of the TX/FL/HI portfolio gap audit.
# v6.3 (2026-06-23): Label consistency pass: Hull ID Number hint removed (matches HI); boat owner
#   OOS abbreviation expanded to "out-of-state" throughout.
# v6.2 (2026-06-23): DH DOB label shortened "Date of Birth (DH) - required with Name" -> "DOB
#   (required with Name)". helperText/placeholder is NOT rendered on this platform and FormDate
#   has no help-text slot, so the qualifier stays in the label (the only rendered place).
# v6.1 (2026-06-23): Name separator normalized to comma-space ", " (was ","), so the wire
#   <Name> reads "Doe, John" per the ConnectCIC devdoc example (order was already Last-first).
#   Cosmetic alignment; ConnectCIC parses on the comma. All 3 Name attrs (DL/DH/Boat).
# v6.0 (2026-06-23): identifier-priority guardrail rollout + flagged fixes + new labels + guide:
#   - Vehicle Plate>VIN guardrail: LicensePlateNumber NOT_EXISTS added to FRQVehicleIdentificationNumber
#     + RQVehicleIdentificationNumber (VIN combos exit pool when a plate is also entered).
#   - Boat Hull>Reg guardrail (FBQ in-state family only, per design call): BoatHullIdNumber NOT_EXISTS
#     added to FBQRegistrationNumber + Hull removed from its any[]. QB/BQ families keep Hull+Reg as
#     intentional companions (NCIC/Nlets) -- NOT guarded.
#   - INERT STATE FIX: all conditions[].field changed @('State') -> @('RegistrationState') (the form
#     sourceField). These existence gates were attr-name-keyed and SILENTLY INERT; now LIVE, they
#     isolate in-state (FRQ/FDQ/FBQ) from OOS (RQ/DQ) combos. CHANGES ROUTING -> full re-test.
#   - ATTENTION auto-populate (HI v2.9 pattern): 'Attention' added to DH KQName/KQOLN any[] + hidden
#     gate-feeder field (initialValue='X') on the DH card. Reverses the prior "INERT" note.
#   - DL/DH OLN>Name guardrails already correct (FDQName/DQName/KQName carry OLN NOT_EXISTS).
#   - New labeling convention (suggest_field_labels: required/required-for/optional) + officer guide.
# Layout:
#   Vehicle: 2 cards (OPTIONS: State+Image, SEARCH: compacted rows)
#   Person:  2 cards (DL + DH, compacted rows)
#   Boat:    2 cards (OPTIONS: State+Stolen+Image, SEARCH: compacted rows)
#   Firearm: 1 card (compacted)
#   Article: 1 card (compacted)
#
# Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
#      & .\scripts\build_fl_fcic.ps1 -Version 4.3
#
# INPUTS:
#   source\FL_FCIC.xml   -- XML metadata (FCIC v94, 170+ message keys) [AUTHORITATIVE]
#   source\FL_FCIC.pdf   -- CommSys devdoc (6 basic queries) [CROSS-CHECK]
#   tools\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs, no external template)
#
# QUERYINPUTDATAMAPPING (CommSys -- 6 QIDMs, 31 combos):
#   Combo array order follows the devdoc "Possible Combinations" listing order in every
#   QIDM (v4.7 standard). Routing conditions are EXISTENCE-ONLY (State NOT_EXISTS /
#   RelatedHit NOT_EXISTS / OLN NOT_EXISTS) -- v5.0 POISONED-ARRAY RULE: any value
#   comparison (EQUALS/NOT_EQUALS/...) disables its entire conditions array, live-proven
#   v4.9 T-A/T-B 2026-06-12 (QIDM_REFERENCE Sec 2a). Existence conditions keep later
#   OOS/stolen combos reachable under first-match AND isolate the serialization pool.
#   VehicleRegistrationQuery   FRQ (Decal/plate/VIN) + RQ (plate+state/VIN+state) = 5 combos
#                              (FRQ Title/Lien REMOVED v7.4 DEX-1279 -- approved-skip, see
#                              FL_FCIC_ACCEPTED_DIVERGENCES.txt)
#                              QV (plate/VIN) NOT BUILT -- devdoc "Data-Mined Transactions"
#                              (QA, QB, QG, QV, QW) = CommSys auto secondaries [PENDING CONFIRMATION]
#   DriverLicenseQuery         FDQ (Name/OLN) + DQ (Name+state/OLN+state) = 4 combos, autoSelect=true
#   WantedPersonQuery          REMOVED -- CommSys auto-sends QW (platform-confirmed, v4.2)
#   DriverHistoryQuery         KQ (Name/OLN) = 2 combos, DH-suffix fields, OUT-OF-STATE ONLY:
#                              FCIC: "KQ is out of state and <XX> destination is required ...
#                              would require the destination to be something other than FL."
#                              State in set[], no default. Not-FL gate NOT enforceable
#                              (LIMITATION -- value conditions inert; platform escalation).
#   GunQuery                   QG (serial/NCIC/PCN) = 3 combos
#   ArticleSingleQuery         QA (serial/OAN/NCIC/PCN) = 4 combos
#   BoatQuery                  FBQ (hull/decal/reg/title) + QB (hull/CG/NCIC/PCN/reg)
#                              + BQ (name/hull/reg -- Nlets OOS, restored v4.7) = 12 combos
#
# ENTITIES (5 QUERYINPUTFORM):
#   Vehicle  -- 2 cards: OPTIONS(State/Image) + SEARCH(Plate/VIN/Decal)
#   Person   -- 2 cards: DL(OLN/State/Image/Name/DOB/Sex) + DH(OLN/DestState/Purpose/Name/DOB/Sex, OOS-only; Attention auto-populated)
#   Firearm  -- 1 card: serial + make + NCIC# + PCN + Image (2 rows)
#   Article  -- 1 card: serial + type + OAN + Image + NCIC# + PCN (2 rows)
#   Boat     -- 2 cards: OPTIONS(DestState/Stolen/Image) + SEARCH(Hull/Reg/CG/Decal/Title/NCIC/PCN/Name/DOB)
#
# FL-SPECIFIC PATTERNS:
#   Date format: yyyyMMdd (CommsysParseDateRuleHandler arguments=['yyyy-MM-dd','yyyyMMdd'])
#   Name format: FormatStringRuleHandler arguments=[', '] -> "Last, First" (devdoc comma-space)
#   Attention:   Auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler (no visible field; BUILD_RULES Sec 14)
#   DH-suffix:   OperatorLicenseNumberDH, NameLastDH, etc. (isolates DH from DL fields)
#   State:       No initialValue anywhere (LIMITATION #30 -- in-state vs OOS routing;
#                DH/BQ destination state must be non-FL per FCIC, cannot be defaulted).
#                ALL State fields = NCIC dropdown (attributeTypeId=STATE Sel +
#                codeTypeProvider NCIC). v5.0 reverted the v4.9 literal-FormInput
#                experiment: T-A proved value guards inert even on literal "FL", so the
#                FormInput bought nothing (POISONED-ARRAY RULE). The not-FL destination
#                rule is officer-facing only (card labels) -- LIMITATION + escalation.
#   Conditions:  NESTED inside requirements, field = @(QIF sourceField / form fieldId -- NOT the
#                attribute name; a wrong/attr-name token is SILENTLY INERT, verify_build CHECK 13)
#                (CA_CLETS/NY live-proven wire format). v4.7's combo-level camelCase
#                scalar conditions were SILENTLY IGNORED by the platform (live XML
#                evidence 2026-06-12: full DL card over-sent all fields).

param(
    [string]$Version = "7.17"
)

$ErrorActionPreference = 'Stop'
$provider = 'FL_FCIC'
$outPath  = "$PSScriptRoot\..\FL_FCIC_v${Version}.json"   # versioned root (NJ/HI parity); Write-ProviderJson removes stale siblings
if ($env:REPRO_OUTPATH) { $outPath = $env:REPRO_OUTPATH }

$currentYear = [string](Get-Date).Year
. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: FL_FCIC PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'FL_FCIC'
$results = Build-ProviderQrdm -ProviderName 'FL_FCIC'
$qmf = Build-Qmf -ProviderName 'FL_FCIC'

# =====================================================================
# 6 COMMSYS QIDMs
# =====================================================================

# --- 1. VehicleRegistrationQuery (FRQ + RQ) -- 5 combos ---
# XML: FRQ (plate/VIN/Decal) + RQ (plate+state/VIN+state)
# FRQ = FCIC-only (no NCIC/Nlets), RQ = with state routing
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'FRQ' and 'RQ' for multiple combos each; field-name suffixes
# (FRQLicensePlateNumber, RQLicensePlateNumber, etc.) are synthetic routing labels.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'DecalNumber';                  size = 10; sourceField = @('decalNumber');                  targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        [PSCustomObject]@{ name = 'VehicleMakeCode';              size = 24; sourceField = @('VehicleMakeCode');              targetField = 'VehicleMakeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    combinations = @(
        # Devdoc order: FRQ Decal(1), FRQ Plate(2), [FRQ TitleLien(3) REMOVED v7.4 DEX-1279 --
        # see FL_FCIC_ACCEPTED_DIVERGENCES.txt], FRQ VIN(4), [QV 5-6 not built], RQ Plate(7), RQ VIN(8)
        # FRQ combos carry State NOT_EXISTS: devdoc lists FRQ first, so a State-filled OOS
        # query must fall through to RQ; the condition also keeps State out of the FRQ pool.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('decalNumber','LicensePlateYear')
                any        = @('ImageIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
                # LicensePlateYear is in set[] with a form initialValue; CAD ignores initialValue,
                # so it needs a combo default or CAD-dispatched FRQ-by-decal can't fire (CHECK 6).
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear })
            }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FRQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('LicensePlateNumber')
                any        = @('LicensePlateYear','ImageIndicator')   # v7.14: VehicleMakeCode/vehicleYear REMOVED -- metadata FRQ{Plate} any[] is [LicensePlateYear, Requestor, ImageIndicator] and the FL devdoc lists neither, so riding them here was an out-of-spec over-send (audit_requirement_fidelity OVER-PERMITTED). They remain available on the OOS RQ{VIN} combo, where metadata DOES define them.
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
                defaults   = @(
                    [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }
                    [PSCustomObject]@{ field = 'ImageIndicator';   value = 'N' }
                )
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'FRQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('VehicleIdentificationNumber')
                any        = @('ImageIndicator')   # v7.14: VehicleMakeCode/vehicleYear REMOVED -- metadata FRQ{VIN} any[] is [Requestor, VINSequenceNumber, ImageIndicator]; neither field is defined on this branch nor listed in the FL devdoc. NOT touched on the OOS RQ{VIN} combo below, where metadata does define them.
                # v6.0: RegistrationState NOT_EXISTS (was @('State') -- inert, attr-name not sourceField; now live, isolates in-state FRQ from OOS RQ)
                #       + LicensePlateNumber NOT_EXISTS (Plate>VIN guardrail -- VIN combo exits pool when officer also enters a plate)
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');  operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'FRQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear','RegistrationState')
                any      = @('ImageIndicator')
                # v7.0: RegistrationState EXISTS -- explicit OOS gate (mirror of FRQ's State NOT_EXISTS).
                # set[] is not a firing gate; this makes RQ-by-plate require a destination State rather
                # than relying on array order + FRQ's NOT_EXISTS. No XML/behavior change. CHECK 16 parity.
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' })
                # PlateType/PlateYear are in set[] with form initialValues; CAD ignores initialValue,
                # so combo defaults are required for CAD-dispatched RQ-by-plate to fire (CHECK 6).
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }, [PSCustomObject]@{ field = 'LicensePlateYear'; value = $currentYear }, [PSCustomObject]@{ field = 'LicensePlateTypeCode'; value = 'PC' })
            }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQLicensePlateNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('VehicleIdentificationNumber','RegistrationState')
                any      = @('VehicleMakeCode','vehicleYear','ImageIndicator')
                # v6.0: LicensePlateNumber NOT_EXISTS (Plate>VIN guardrail -- OOS VIN combo exits pool when a plate is also entered)
                conditions = @([PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' })
                defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQVehicleIdentificationNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'VehicleRegistrationQuery -- devdoc order: FRQ (Decal, plate, VIN; State NOT_EXISTS), RQ (plate+state, VIN+state). 5 combos (FRQ Title/Lien removed v7.4, approved-skip).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_VehicleRegistrationQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'VehicleRegistrationQuery'
    queryLabel      = 'Vehicle Registration'
    targetEntity    = 'Vehicle'
}

# --- 2. VehicleStolenQuery -- REMOVED / QV combos PENDING CONFIRMATION ---
# Separate VehicleStolenQuery transaction is not in devdoc "Basic Queries Supported" (correct removal, v4.4).
# Devdoc DOES list QV combos 5-6 under VehicleRegistrationQuery, but QV appears in the devdoc
# "Data-Mined Transactions" list (QA, QB, QG, QV, QW) -- believed to be CommSys auto-sent
# secondary queries (QW precedent: platform-confirmed auto-send, v4.2). NOT BUILT pending
# platform confirmation. If refuted: build QV via Stolen Search toggle (Boat QB pattern).

# --- 3. DriverLicenseQuery (FDQ + DQ) -- 4 combos, autoSelect ---
# Devdoc order: FDQ Name(1), FDQ OLN(2), [QW 3-4 auto-sent], DQ Name(5), DQ OLN(6)
# Routing conditions (first-match + pool isolation):
#   State NOT_EXISTS on FDQ combos -- State filled falls through to DQ (devdoc lists FDQ first)
#   operatorLicenseNumber NOT_EXISTS on Name combos -- OLN filled falls through to the OLN
#   combo and excludes Name/DOB/Sex from the serialization pool (fixes full-card over-send)
# DQ is devdoc (In/Out): State=FL on DQ is legal, no NOT_EQUALS guard (deliberate).
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'FDQ' and 'DQ' for 2 combos each; synthetic labels
# (FDQName, FDQOperatorLicenseNumber, DQName, DQOperatorLicenseNumber) differentiate routing.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 80; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDate','NameLast','NameFirst','SexCode')
                any        = @('ImageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');                 operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'FDQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('OperatorLicenseNumber')
                any        = @('ImageIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'FDQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDate','NameLast','NameFirst','SexCode','RegistrationState')
                any        = @('ImageIndicator')
                conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'Name'
            keyReference          = 'DQName'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            # v7.0: RegistrationState EXISTS -- explicit OOS gate (mirror of FDQ's State NOT_EXISTS).
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber','RegistrationState'); any = @('ImageIndicator'); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' }); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQOperatorLicenseNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- devdoc order: FDQ (Name, OLN; State NOT_EXISTS), DQ (Name+state, OLN+state). OLN NOT_EXISTS isolates Name combos. autoSelect=true.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverLicenseQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# --- 4. WantedPersonQuery (QW) -- REMOVED ---
# CommSys auto-sends QW; no QIDM needed in JSON.

# --- 5. DriverHistoryQuery (KQ) -- 2 combos, DH-suffix fields, OUT-OF-STATE ONLY ---
# FCIC (2026-06-12): "Since the KQ is out of state and <XX> which denotes the destination
# is required, yes DriverHistoryQuery can only be used out of state and would require the
# destination to be something other than FL." Devdoc: State is Mandatory, both combos (Out).
# Therefore: registrationStateDH in set[] (no default possible -- destination must be an
# explicit officer choice). NO NOT_EQUALS FL gate: value-comparison conditions are wholly
# inert and poison the entire array (POISONED-ARRAY RULE, QIDM_REFERENCE Sec 2a; live-proven
# v4.9 T-A/T-B 2026-06-12). Not-FL destination is LIMITATION + platform escalation; the
# dropdown (no FL exclusion possible) + card title carry the officer-facing guard.
# Devdoc order: KQ Name(1), KQ OLN(2). operatorLicenseNumberDH NOT_EXISTS on KQName
# (existence-only array -- the working class) falls through to KQ OLN and keeps
# Name/DOB/Sex out of the pool on OLN searches.
# CAD dispatch cannot supply a destination state, so DH will not auto-fire from CAD (correct).
# DH-suffix fields isolate from DL field pool (AP #14)
# Attention: auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler. v6.0: now IN the DH
# combos' any[] + hidden gate-feeder field (HI v2.9 live-proven) so the handler emits the officer name.
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'KQ' for both combos; synthetic labels KQName and KQOperatorLicenseNumber
# differentiate routing. NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$dhQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        }
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('NameLastDH','NameFirstDH'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
        }
        # v5.1: attribute NAME made unique (OperatorLicenseNumberDH) so the KQName NOT_EXISTS
        # gate resolves to THIS field, not the DL QIDM's OperatorLicenseNumber. Conditions/
        # defaults/primaryFieldReference resolve attributes by NAME, entity-global; a shared
        # name collided -> the gate checked the DL field (blank on a DH query) -> never fired
        # -> full DH card over-sent Name/DOB/Sex (live FAIL 2026-06-15, txn 01KV5XVZ...).
        # targetField stays 'OperatorLicenseNumber' so the wire element is unchanged.
        [PSCustomObject]@{ name = 'OperatorLicenseNumberDH'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');            targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        # v5.0: dropdown restored (attributeTypeId=STATE Sel + NCIC reverse-lookup).
        # The v4.9 literal-FormInput experiment is over: T-A proved the NOT_EQUALS FL
        # gate is inert even against an exact-uppercase literal "FL", so the literal
        # field bought nothing and cost typo/case risk. Reverse-lookup serialization
        # is live-proven on all instances.
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDateDH','NameLastDH','NameFirstDH','SexCodeDH','RegistrationStateDH')
                any        = @('purposeCodeDH','Attention')
                # Attention auto-populates via the handler; the hidden gate-feeder carries
                # initialValue='X', so CAD dispatch needs a matching combo default (audit_cad CHECK 6).
                defaults   = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                # Existence-only array (working class). NEVER add a value comparison
                # here -- it would poison the array and kill this NOT_EXISTS (T-B).
                # v5.1: references the unique DH attr name (not the shared 'OperatorLicenseNumber')
                # so it resolves to operatorLicenseNumberDH, not the DL field.
                conditions = @(
                    [PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }
                )
            }
            primaryFieldReference = 'Name'
            keyReference          = 'KQName'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('OperatorLicenseNumberDH','RegistrationStateDH')
                any        = @('purposeCodeDH','Attention')
                defaults   = @([PSCustomObject]@{ field = 'Attention'; value = 'X' })
                # v7.0: RegistrationStateDH EXISTS -- explicit OOS gate. DH is OOS-only (destination
                # state mandatory); makes the requirement explicit rather than set[]-implicit. Existence-only.
                conditions = @([PSCustomObject]@{ field = @('RegistrationStateDH'); operator = 'EXISTS' })
            }
            primaryFieldReference = 'OperatorLicenseNumberDH'
            keyReference          = 'KQOperatorLicenseNumber'
            state                 = 'Out'
        }
    )
    description     = 'DriverHistoryQuery -- OOS only (FCIC): KQ by Name+DestState, KQ by OLN+DestState. State in set[] (dropdown, no default); not-FL gate is a LIMITATION (value conditions inert). DH-suffix fields. Attention auto-populated (handler).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_DriverHistoryQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
    queriesToDeselect = @('DriverLicenseQuery')
}

# --- 6. GunQuery (QG) -- 3 combos ---
# XML: QG by serial, QG by NCIC#, QG by PCN
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QG' for all 3 combos; synthetic labels QGGunSerialNumber,
# QGNCICNumber, QGProcessControlNumber differentiate routing. NOT real FCIC transaction codes.
# See PLATFORM_CONSTRAINTS.txt -- synthetic keyRef naming convention.
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunMake';               size = 23; sourceField = @('GunMake');               targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunSerialNumber';       size = 11; sourceField = @('serialNumber');          targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('NCICNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('processControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('serialNumber'); any = @('GunMake','ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QGGunSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('GunMake','ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QGNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('GunMake','ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QGProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG by serial, NCIC#, PCN.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_GunQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# --- 7. ArticleSingleQuery (QA) -- 4 combos ---
# XML: QA by serial+type, QA by OAN+type, QA by NCIC#, QA by PCN
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'QA' for all 4 combos; synthetic labels QAArticleSerialNumber,
# QAOwnerAppliedNumber, QANCICNumber, QAProcessControlNumber differentiate routing.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';   size = 20; sourceField = @('ArticleSerialNumber');   targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';       size = 7;  sourceField = @('ArticleTypeCode');       targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'ImageIndicator';        size = 1;  sourceField = @('ImageIndicator');        targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'NCICNumber';            size = 10; sourceField = @('NCICNumber');            targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'OwnerAppliedNumber';    size = 20; sourceField = @('ownerAppliedNumber');    targetField = 'OwnerAppliedNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';  size = 10; sourceField = @('processControlNumber');  targetField = 'ProcessControlNumber' }
    )
    combinations = @(
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleSerialNumber','ArticleTypeCode'); any = @('ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QAArticleSerialNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('ArticleTypeCode','ownerAppliedNumber'); any = @('ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'OwnerAppliedNumber'
            keyReference          = 'QAOwnerAppliedNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QANCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('ImageIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QAProcessControlNumber'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA by serial+type, OAN+type, NCIC#, PCN.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_ArticleSingleQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# --- 8. BoatQuery (FBQ + QB + BQ) -- 12 combos ---
# Devdoc order: FBQ Hull(1), FBQ Decal(2), FBQ Reg(3), FBQ Title(4),
#               QB Hull(5), QB CG(6), QB NCIC(7), QB PCN(8), QB Reg(9),
#               BQ Name(10), BQ Hull(11), BQ Reg(12)
# BQ (Nlets OOS) RESTORED v4.7 -- devdoc Boat combos 10-12 ARE the BQ paths and BQ is not
# in the data-mined list. The v4.4 removal cited a devdoc "key list (FBQ + QB only)" that
# does not exist (devdoc contains no key mnemonics; combos are the authority).
# Routing conditions (v5.0: EXISTENCE-ONLY -- value comparisons poison the whole array,
# POISONED-ARRAY RULE, QIDM_REFERENCE Sec 2a, live-proven v4.9 T-A/T-B 2026-06-12):
#   FBQ all: registrationState NOT_EXISTS (State filled falls through to BQ)
#   FBQ Hull/Reg additionally: relatedHitSearchIndicator NOT_EXISTS (any Stolen Search
#   value falls through to QB -- same routing as the v4.7 NOT_EQUALS Y intent, but in
#   the working operator class; officer types Y per card hint, live-proven 13/13 v3.x)
#   QB Hull/Reg: NO conditions -- relatedHitSearchIndicator in set[] does the gating
#   BQ all: NO conditions -- the non-FL destination rule is NOT enforceable config-side
#   (LIMITATION + platform escalation, same as DH KQ)
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21).
# Metadata uses keyRef 'FBQ', 'QB', 'BQ' for multiple combos each; field-name suffixes
# (FBQBoatHullIdNumber, QBRegistrationNumber, etc.) are synthetic routing labels.
# NOT real FCIC transaction codes. See PLATFORM_CONSTRAINTS.txt.
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name = 'BirthDate'; size = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
            rule = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','yyyyMMdd') }
        }
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 62; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'CoastGuardDocumentNumber';  size = 8;  sourceField = @('coastGuardDocumentNumber');  targetField = 'CoastGuardDocumentNumber' }
        [PSCustomObject]@{ name = 'DecalNumber';               size = 10; sourceField = @('decalNumber');               targetField = 'DecalNumber' }
        [PSCustomObject]@{ name = 'ImageIndicator';            size = 1;  sourceField = @('ImageIndicator');            targetField = 'ImageIndicator' }
        [PSCustomObject]@{
            name = 'Name'; size = 30; sourceField = @('NameLast','NameFirst'); targetField = 'Name'
            rule = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ') }
        }
        [PSCustomObject]@{ name = 'NCICNumber';                size = 10; sourceField = @('NCICNumber');                targetField = 'NCICNumber' }
        [PSCustomObject]@{ name = 'ProcessControlNumber';      size = 10; sourceField = @('processControlNumber');      targetField = 'ProcessControlNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        # v5.0: dropdown restored (attributeTypeId=STATE Sel + NCIC reverse-lookup) -- the
        # literal-FormInput experiment proved nothing gates on value anyway (T-A).
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'TitleLienInformation';      size = 8;  sourceField = @('titleLienInformation');      targetField = 'TitleLienInformation' }
        [PSCustomObject]@{ name = 'RelatedHitSearchIndicator'; size = 1;  sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator' }
    )
    combinations = @(
        # FBQ combos -- devdoc 1-4 (FCIC registration; State NOT_EXISTS defers to BQ,
        # Hull/Reg additionally RelatedHit NOT_EXISTS defers to QB -- existence-only arrays)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BoatHullIdNumber')
                # v7.1: RegistrationNumber removed from any[] -- LIMITATION #1 union over-send:
                # when Hull fires, any[] fields present in the form are sent regardless of conditions.
                # Reg was in Hull's any[], causing Reg to leak into XML even when Hull>Reg guardrail
                # correctly blocked FBQRegistrationNumber from firing.
                any        = @('decalNumber','titleLienInformation','RegistrationNumber','ImageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');             operator = 'NOT_EXISTS' }
                    # relatedHitSearchIndicator (camelCase = QIF fieldId); NOT RelatedHitSearchIndicator
                    # (attribute name) -- wrong casing is silently inert (live-proven HI v3.3 / FL v3.x pattern)
                    [PSCustomObject]@{ field = @('relatedHitSearchIndicator');     operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'FBQBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('decalNumber')
                # v7.1: RegistrationNumber removed from any[] (same LIMITATION #1 fix as FBQHull).
                any        = @('BoatHullIdNumber','titleLienInformation','ImageIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'DecalNumber'
            keyReference          = 'FBQDecalNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('RegistrationNumber')
                # v6.0: Hull removed from any[] -- the Hull>Reg guardrail below makes this combo
                # fire ONLY when Hull is absent, so Hull can never coexist here (would self-contradict).
                any        = @('decalNumber','titleLienInformation','RegistrationNumber','ImageIndicator')
                conditions = @(
                    [PSCustomObject]@{ field = @('RegistrationState');           operator = 'NOT_EXISTS' }
                    # relatedHitSearchIndicator (camelCase = QIF fieldId); NOT RelatedHitSearchIndicator
                    # (attribute name) -- wrong casing is silently inert (v6.3 bug, fixed v6.4)
                    [PSCustomObject]@{ field = @('relatedHitSearchIndicator');   operator = 'NOT_EXISTS' }
                    # Hull>Reg identifier-priority guardrail (FBQ in-state family). Hull ID is the
                    # unique permanent identifier; when present, this Reg combo exits and FBQ Hull wins.
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');           operator = 'NOT_EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'FBQRegistrationNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('titleLienInformation')
                # v7.1: RegistrationNumber removed from any[] (same LIMITATION #1 fix as FBQHull).
                any        = @('BoatHullIdNumber','decalNumber','ImageIndicator')
                conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'TitleLienInformation'
            keyReference          = 'FBQTitleLienInformation'
            state                 = 'In/Out'
        }
        # QB combos -- devdoc 5-9 (NCIC stolen; Hull/Reg gated by relatedHitSearchIndicator
        # in set[] -- presence-based, no conditions; officer types Y per card hint)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BoatHullIdNumber','relatedHitSearchIndicator')
                # v6.9: RegistrationNumber removed from any[] -- Hull>Reg guardrail de-bleed.
                # Hull is the priority identifier; the Hull query must not carry Reg on the wire.
                any        = @('ImageIndicator')
                # v6.9: relatedHitSearchIndicator EXISTS -- explicit Stolen gate. set[] membership
                # is NOT a firing gate (platform fires on primaryFieldReference); without this, the
                # QB combo would shadow the BQ OOS Hull combo on a Hull+State payload. Mirrors FBQ's
                # relatedHit NOT_EXISTS (FBQ<->QB routing symmetry). verify_build CHECK 16.
                conditions = @([PSCustomObject]@{ field = @('relatedHitSearchIndicator'); operator = 'EXISTS' })
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QBBoatHullIdNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('coastGuardDocumentNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'CoastGuardDocumentNumber'
            keyReference          = 'QBCoastGuardDocumentNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('NCICNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'NCICNumber'
            keyReference          = 'QBNCICNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('processControlNumber'); any = @('ImageIndicator','relatedHitSearchIndicator'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' }) }
            primaryFieldReference = 'ProcessControlNumber'
            keyReference          = 'QBProcessControlNumber'
            state                 = 'In/Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('RegistrationNumber','relatedHitSearchIndicator')
                any        = @('ImageIndicator')
                # Two conditions (v6.9):
                #  - BoatHullIdNumber NOT_EXISTS: Hull>Reg identifier-priority guardrail. Hull ID (HIN)
                #    is the unique permanent identifier; when Hull is also entered, this Reg combo exits
                #    and QBBoatHullIdNumber wins alone (kills the bleed).
                #  - relatedHitSearchIndicator EXISTS: explicit Stolen gate. set[] is not a firing gate;
                #    without this, QBRegistrationNumber shadows the BQ OOS Reg combo on a Reg+State
                #    payload (verify_build CHECK 16). Mirrors FBQ's relatedHit NOT_EXISTS.
                conditions = @(
                    [PSCustomObject]@{ field = @('BoatHullIdNumber');          operator = 'NOT_EXISTS' }
                    [PSCustomObject]@{ field = @('relatedHitSearchIndicator'); operator = 'EXISTS' }
                )
                defaults   = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'N' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'QBRegistrationNumber'
            state                 = 'In/Out'
        }
        # BQ combos -- devdoc 10-12 (Nlets OOS; destination state in set[]. Non-FL rule
        # NOT enforceable config-side -- LIMITATION, dropdown + card hint only)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BirthDate','NameLast','NameFirst','RegistrationState')
                any        = @('BoatHullIdNumber','RegistrationNumber')
            }
            primaryFieldReference = 'Name'
            keyReference          = 'BQName'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('BoatHullIdNumber','RegistrationState')
                # v6.9: RegistrationNumber removed from any[] -- Hull>Reg guardrail de-bleed (BQ OOS family).
                any        = @()
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'BQBoatHullIdNumber'
            state                 = 'Out'
        }
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set        = @('RegistrationNumber','RegistrationState')
                any        = @()
                # Hull>Reg identifier-priority guardrail (BQ OOS family, v6.9). When Hull+Reg+State
                # are all entered, this Reg combo exits and BQBoatHullIdNumber wins (kills the shadow).
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQRegistrationNumber'
            state                 = 'Out'
        }
    )
    description     = 'BoatQuery -- devdoc order: FBQ (hull/decal/reg/title; State+RelatedHit NOT_EXISTS), QB (hull/CG/NCIC/PCN/reg; Stolen in set[]), BQ (name/hull/reg; State in set[], non-FL is LIMITATION). 12 combos.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = "${provider}_BoatQuery"
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = $provider
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

# ─── v7.15: Requestor wired onto the five Basic queries that permit it ────────────────────────────
# Rob's call 2026-08-02, accepting the re-sweep cost.
# FL's OWN metadata defines Requestor (maxLength 30) and permits it as an OPTIONAL on every Basic
# query except DriverLicense -- 29 combinations across ArticleSingleQuery (QA), BoatQuery (FBQ/QB/BQ),
# DriverHistoryQuery (KQ), GunQuery (QG) and VehicleRegistrationQuery (FRQ/QV/RQ). Checked per query:
# mandatory=0 / optional>0 in all five, so it belongs in any[], never set[].
# It was wired NOWHERE, so an officer could not send a field the provider accepts -- and 20 of the
# independent spec plan's tests referenced it and could never be covered by any sweep.
# Standing rule: never DROP a devdoc-optional combination field.
# AUTO-POPULATED, not officer-typed. Requestor is an identity field on the approved
# automated-identity-field standard (Rob 2026-06-22, extended to Requestor 2026-07-06), so it takes
# CommsysGetLastNameFirstNameInitialRuleHandler and a HIDDEN gate-feeder -- exactly how this build
# already carries Attention (see $dhQuery). Building it as a visible FormInput asks the officer to
# retype their own name and trips verify_build's inverse check. Three parts, all required:
#   attr.rule       -- the handler that substitutes the officer's name
#   hidden feeder   -- an attribute whose sourceField has no value is DROPPED from serialization,
#                      so the handler never runs; the constant 'X' exists only to make it fire
#   combo defaults  -- CAD ignores form initialValue entirely (audit_cad CHECK 6), so without this a
#                      CAD-dispatched query silently drops Requestor
# No DH suffix, deliberately: DH-suffixing exists to stop a VISIBLE control from sharing the DL field
# pool, and DriverLicenseQuery defines no Requestor attribute at all -- so nothing on the DL path can
# transmit it however the pool is shared. It is any[]-only, so it also cannot alter routing.
foreach ($q in @($vehRegQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)) {
    $has = @($q.attributes | Where-Object { "$($_.name)" -eq 'Requestor' })
    if (-not $has.Count) {
        $q.attributes = @(@($q.attributes) + [PSCustomObject]@{
            name = 'Requestor'; size = 30; sourceField = @('Requestor'); targetField = 'Requestor'
            rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
        })
    }
    foreach ($cm in @($q.combinations)) {
        $cur = @($cm.requirements.any | Where-Object { $_ })
        if ($cur -notcontains 'Requestor') { $cm.requirements.any = @($cur + 'Requestor') }
        # defaults live INSIDE requirements (see the KQ combos above), NOT on the combination.
        # Putting them a level up emits a property no gate reads: audit_cad CHECK 6 still reported
        # "missing default" on all 26 while the JSON visibly contained them.
        $rq = $cm.requirements
        $dcur = @($rq.PSObject.Properties['defaults'] | ForEach-Object { $_.Value } | Where-Object { $_ })
        if (-not @($dcur | Where-Object { "$($_.field)" -eq 'Requestor' }).Count) {
            $dnew = @($dcur + [PSCustomObject]@{ field = 'Requestor'; value = 'X' })
            if ($rq.PSObject.Properties['defaults']) { $rq.defaults = $dnew }
            else { $rq | Add-Member -NotePropertyName defaults -NotePropertyValue $dnew }
        }
    }
}

# ─── v7.16: two more optionals FL's own authorities permit but nothing wired ──────────────────────
# Found by the SPEC-derived plan (devdoc+metadata, no vote from the JSON), which reported them
# UNREACHABLE -- a devdoc field with no form control at all. Both authorities agree on both.
#
# 1) RelatedHitSearchIndicator on Gun + Article. Devdoc lists it optional on GunQuery #1-3 and
#    ArticleSingleQuery #1-4, and the metadata puts it in <Any> on exactly those keyRefs (QG x3,
#    QA x4). The control was built on Boat only, so an officer could run a stolen check on a boat
#    but not on a firearm or an article. Optional, so any[] -- it is NOT the routing discriminator
#    it is on Boat's QB, where it sits in set[]. No initialValue: it is officer-chosen.
#
# 2) VINSequenceNumber on FRQ{VIN} ONLY. Metadata FRQ{VIN} <Any> is exactly
#    [Requestor, VINSequenceNumber, ImageIndicator]; v7.14 wired ImageIndicator, v7.15 Requestor,
#    this completes the branch. maxLength 2 read from this XML's own <Field>, not guessed.
#
# DELIBERATELY NOT DONE HERE -- RelatedHitSearchIndicator on Vehicle, and VehicleMake on
# VehicleRegistrationQuery #6. The devdoc lists optionals FLAT per query while the metadata scopes
# them PER VARIANT, and both of these belong to QV (the NCIC stolen path), which this build does not
# carry -- devdoc #5/#6 map to the FRQ combos, whose <Any> defines NEITHER field. Adding them to FRQ
# would OVER-PERMIT: a request carrying a field that branch does not define. VehicleMake is the same
# case v7.14 already decided when it removed VehicleMakeCode/vehicleYear from FRQ{VIN} (see the note
# on that combo above) -- this re-derivation from the raw <Requirements> confirms that call was right.
foreach ($cm in @($gunQuery.combinations) + @($artQuery.combinations)) {
    $cur = @($cm.requirements.any | Where-Object { $_ })
    if ($cur -notcontains 'relatedHitSearchIndicator') { $cm.requirements.any = @($cur + 'relatedHitSearchIndicator') }
}
foreach ($q in @($gunQuery, $artQuery)) {
    if (-not @($q.attributes | Where-Object { "$($_.name)" -eq 'RelatedHitSearchIndicator' }).Count) {
        $q.attributes = @(@($q.attributes) + [PSCustomObject]@{
            name = 'RelatedHitSearchIndicator'; size = 1
            sourceField = @('relatedHitSearchIndicator'); targetField = 'RelatedHitSearchIndicator'
        })
    }
}
if (-not @($vehRegQuery.attributes | Where-Object { "$($_.name)" -eq 'VINSequenceNumber' }).Count) {
    $vehRegQuery.attributes = @(@($vehRegQuery.attributes) + [PSCustomObject]@{
        name = 'VINSequenceNumber'; size = 2
        sourceField = @('vinSequenceNumber'); targetField = 'VINSequenceNumber'
    })
}
foreach ($cm in @($vehRegQuery.combinations | Where-Object { "$($_.keyReference)" -eq 'FRQVehicleIdentificationNumber' })) {
    $cur = @($cm.requirements.any | Where-Object { $_ })
    if ($cur -notcontains 'vinSequenceNumber') { $cm.requirements.any = @($cur + 'vinSequenceNumber') }
}

$providerBundle = [PSCustomObject]@{
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    description    = "Provider configuration for $provider v$Version"
    name           = $provider
    type           = 'BUNDLE'
    provider       = $provider
}

# =====================================================================
# BUNDLE 2: ENTITIES (5 QUERYINPUTFORM)
# =====================================================================

# --- Vehicle (1 card, v7.5: collapsed from 2 -- direct feedback) ---
# Plate/VIN/Decal (VehicleRegistrationQuery fields only); State+Image moved to the bottom row
# alongside Decal (v7.5 -- was its own "Search Options" card through v7.4).
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH_SEARCH'
        title = 'VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, "OR" VIN, "OR" DECAL'
        rows  = @(
            @{ id = 'ROW_VEH_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'LicensePlateNumber_Input';  node = Inp 'LicensePlateNumber' 'Plate Number' '10' 'ROW_VEH_1' }
                @{ id = 'LicensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (out-of-state)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC'; initialValue = 'PC' } 'ROW_VEH_1' }
                @{ id = 'LicensePlateYear_Input';    node = Inp 'LicensePlateYear' 'Plate Year (out-of-state)' '4' 'ROW_VEH_1' @{ initialValue = $currentYear } }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('5','4','3'); fields = @(
                @{ id = 'VehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'VIN' '20' 'ROW_VEH_2' }
                # LABEL-OVERRIDE: VehicleMakeCode -- bare "Vehicle Make" per DEX-1284 lean pass (any[] optional VIN qualifier, no default; card title carries the paths; matches NY/TX)
                @{ id = 'VehicleMakeCode_Input';              node = Sel 'VehicleMakeCode' 'Vehicle Make' @{ attributeTypeId = 'VEHICLE_MAKE'; codeTypeProvider = 'NCIC' } 'ROW_VEH_2' }
                # LABEL-OVERRIDE: vehicleYear -- bare "Vehicle Year" per DEX-1284 lean pass (any[] optional VIN qualifier, no default; card title carries the paths; matches NY/TX)
                @{ id = 'VehicleYear_Input';                  node = Inp 'vehicleYear' 'Vehicle Year' '4' 'ROW_VEH_2' }
            )}
            # v7.5: bottom row now carries Decal + State + Image together (was Decal alone
            # after v7.4's Title/Lien removal; State/Image moved down from the now-retired
            # CARD_VEH_OPT "Search Options" card).
            @{ id = 'ROW_VEH_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'DecalNumber_Input';        node = Inp 'decalNumber' 'Decal Number' '10' 'ROW_VEH_3' }
                @{ id = 'RegistrationState_Input';  node = Sel 'RegistrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_3' }
                @{ id = 'ImageIndicator_Input';     node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_REQ'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Requestor_Input'; node = InpH 'Requestor' 'Requestor (auto-populated from officer profile)' '30' 'ROW_VEH_REQ' @{ initialValue = 'X' } }
            )}
            @{ id = 'ROW_VEH_VSN'; cols = @('6'); fields = @(
        @{ id = 'VINSequenceNumber_Input'; node = Inp 'vinSequenceNumber' 'VIN Sequence Number (optional)' '2' 'ROW_VEH_VSN' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card (v7.5, collapsed from 2): Plate/VIN row, Make/Year row, Decal+State+Image bottom row. Title/Lien removed v7.4 (DEX-1279, approved-skip).'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# --- Person (DL card + DH card, DH-suffix fields) ---
# v3.9: Search Options merged into DL card (State+Image only serve DL)
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'
        rows  = @(
            @{ id = 'ROW_DL1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_DL1' }
                @{ id = 'RegistrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_DL1' }
                @{ id = 'ImageIndicator_Input';         node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_DL1' }
            )}
            # v7.17: nameMiddle / nameSuffix / nameMiddleDH REMOVED (Rob 2026-08-02). They were
            # visible controls wired to nothing -- every Name attribute here sources only
            # [NameLast, NameFirst] -- so an officer's middle name or suffix was silently discarded
            # on DL, DH and Boat alike. Found by audit_wiring_closure. Removed rather than wired:
            # no wire behaviour changes, and the form stops implying a precision it never delivered.
            @{ id = 'ROW_DL2'; cols = @('6','6'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name' '30' 'ROW_DL2' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name'  '30' 'ROW_DL2' }
            )}
            @{ id = 'ROW_DL3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'Date of Birth' 'ROW_DL3' }
                @{ id = 'SexCode_Input';   node = Sel 'SexCode' 'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DL3' }
            )}
        )
    }
    @{
        id    = 'CARD_DH'
        title = 'DRIVER HISTORY (OUT-OF-STATE) BY NAME "OR" DRIVERS LICENSE NUMBER'
        rows  = @(
            @{ id = 'ROW_DH1'; cols = @('6','3','3'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_DH1' }
                @{ id = 'RegistrationStateDH_Input';     node = Sel 'RegistrationStateDH' 'State (required)' @{ attributeTypeId = 'STATE' } 'ROW_DH1' }
                @{ id = 'PurposeCodeDH_Input';            node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_DH1' }
            )}
            # v7.2 (DEX-1278): reordered First/Last/MI/DOB/Sex (was Last/First/DOB/Sex);
            # nameMiddleDH added visible-only, mirrors DL card's unwired nameMiddle/nameSuffix
            # (not in the KQName combo's set[]/any[] or the Name attribute's sourceField).
            @{ id = 'ROW_DH2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name' '30' 'ROW_DH2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'  '30' 'ROW_DH2' }
                @{ id = 'BirthDateDH_Input';  node = Dt  'BirthDateDH'  'Date of Birth' 'ROW_DH2' }
                @{ id = 'SexCodeDH_Input';    node = Sel 'SexCodeDH'    'Sex' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_DH2' }
            )}
            @{ id = 'ROW_DH_REQ'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Requestor_Input'; node = InpH 'Requestor' 'Requestor (auto-populated from officer profile)' '30' 'ROW_DH_REQ' @{ initialValue = 'X' } }
            )}
            # v6.0: hidden Attention gate-feeder (HI v2.9 live-proven pattern). The DH Attention
            # attribute (CommsysGetLastNameFirstNameInitialRuleHandler, sourceField=['Attention'])
            # is dropped from serialization unless (a) Attention is in the fired combo's any[]
            # (added to KQName/KQOLN above) AND (b) its sourceField resolves to a value. This
            # hidden field supplies that value so the handler runs and emits the officer's profile
            # name (e.g. "SGAMBELLONE R"). Reverses FL's prior "INERT/known-limitation" note.
            @{ id = 'ROW_DH_ATTN'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Attention_Input'; node = InpH 'Attention' 'Attention (auto-populated from officer profile)' '30' 'ROW_DH_ATTN' @{ initialValue = 'X' } }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- DL (FDQ/DQ) + DH (KQ, out-of-state only) on separate cards. DH-suffix fields. QW auto-sent by CommSys.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# --- Firearm ---
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM QUERY BY SERIAL NUMBER, "OR" NCIC NUMBER, "OR" PCN'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '11' 'ROW_GUN_1' }
                # LABEL-OVERRIDE: GunMake -- bare "Gun Make" per DEX-1284 lean pass (any[] optional, no default; matches NY/TX)
                @{ id = 'GunMake_Input';         node = Sel 'GunMake' 'Gun Make' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'NCICNumber_Input';         node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_GUN_2' }
                @{ id = 'ProcessControlNumber_Input'; node = Inp 'processControlNumber' 'PCN' '10' 'ROW_GUN_2' }
                @{ id = 'ImageIndicator_Input';      node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_GUN_2' }
            )}
            @{ id = 'ROW_GUN_REQ'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Requestor_Input'; node = InpH 'Requestor' 'Requestor (auto-populated from officer profile)' '30' 'ROW_GUN_REQ' @{ initialValue = 'X' } }
            )}
            @{ id = 'ROW_GUN_RHS'; cols = @('6'); fields = @(
        # LABEL-OVERRIDE: relatedHitSearchIndicator -- canonical bare "Stolen Check" per DEX-1284 lean pass (any[] optional, no default)
        @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_GUN_RHS' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG by serial, NCIC#, PCN.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# --- Article ---
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE QUERY BY SERIAL NUMBER, "OR" OWNER APPLIED NUMBER, "OR" NCIC NUMBER, "OR" PCN'
        rows  = @(
            # v7.6 (DEX-1281): split the old 4-field row -- Serial Number + Owner Applied
            # Number on their own line, Article Type + Image below.
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleSerialNumber_Input'; node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'OwnerAppliedNumber_Input';  node = Inp 'ownerAppliedNumber' 'Owner Applied Number' '20' 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6','6'); fields = @(
                @{ id = 'ArticleTypeCode_Input'; node = Sel 'ArticleTypeCode' 'Article Type' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_2' }
                @{ id = 'ImageIndicator_Input';  node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_ART_2' }
            )}
            @{ id = 'ROW_ART_3'; cols = @('6','6'); fields = @(
                @{ id = 'NCICNumber_Input';           node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_ART_3' }
                @{ id = 'ProcessControlNumber_Input'; node = Inp 'processControlNumber' 'PCN' '10' 'ROW_ART_3' }
            )}
            @{ id = 'ROW_ART_REQ'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Requestor_Input'; node = InpH 'Requestor' 'Requestor (auto-populated from officer profile)' '30' 'ROW_ART_REQ' @{ initialValue = 'X' } }
            )}
            @{ id = 'ROW_ART_RHS'; cols = @('6'); fields = @(
        # LABEL-OVERRIDE: relatedHitSearchIndicator -- canonical bare "Stolen Check" per DEX-1284 lean pass (any[] optional, no default)
        @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_ART_RHS' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA by serial+type, OAN+type, NCIC#, PCN.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# --- Boat (2 cards: OPTIONS + SEARCH) ---
# v7.6: collapsed from 2 cards to 1 -- DestState/Stolen/Image moved to a new bottom row.
# SEARCH: Hull/Reg/CG/Decal/Title/NCIC/PCN + Name/DOB (BQ owner search, restored v4.7)
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA_SEARCH'
        title = 'BOAT SEARCH BY HULL ID, "OR" REGISTRATION NUMBER, "OR" COAST GUARD DOC #, "OR" NCIC NUMBER, "OR" PCN'
        rows  = @(
            @{ id = 'ROW_BOA_1'; cols = @('6','3','3'); fields = @(
                @{ id = 'BoatHullIdNumber_Input';   node = Inp 'BoatHullIdNumber' 'Hull ID Number' '62' 'ROW_BOA_1' }
                @{ id = 'RegistrationNumber_Input'; node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'CoastGuardDocumentNumber_Input'; node = Inp 'coastGuardDocumentNumber' 'Coast Guard Doc #' '8' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('3','3','3','3'); fields = @(
                @{ id = 'DecalNumber_Input';              node = Inp 'decalNumber' 'Decal Number' '10' 'ROW_BOA_2' }
                @{ id = 'TitleLienInformation_Input';     node = Inp 'titleLienInformation' 'Title/Lien Info' '8' 'ROW_BOA_2' }
                @{ id = 'NCICNumber_Input';               node = Inp 'NCICNumber' 'NCIC Number' '10' 'ROW_BOA_2' }
                @{ id = 'ProcessControlNumber_Input';     node = Inp 'processControlNumber' 'PCN' '10' 'ROW_BOA_2' }
            )}
            # v7.6: reordered First-before-Last, matching Person's v7.5 fix ("like the others").
            @{ id = 'ROW_BOA_3'; cols = @('4','4','4'); fields = @(
                @{ id = 'NameFirst_Input'; node = Inp 'NameFirst' 'First Name (out-of-state)' '30' 'ROW_BOA_3' }
                @{ id = 'NameLast_Input';  node = Inp 'NameLast'  'Last Name (out-of-state)'  '30' 'ROW_BOA_3' }
                @{ id = 'BirthDate_Input'; node = Dt  'BirthDate' 'DOB (out-of-state)' 'ROW_BOA_3' }
            )}
            # v7.6: DestState/Stolen/Image moved here from the now-retired CARD_BOA_OPT
            # "Search Options" card (Boat didn't free up an existing row like Vehicle did, so
            # this is a new row, not a merge into one).
            @{ id = 'ROW_BOA_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'RegistrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for FL)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_4' }
                # LABEL-OVERRIDE: relatedHitSearchIndicator -- canonical bare "Stolen Check" per DEX-1284 lean pass (any[] optional, no default; matches NY/TX portfolio convention)
                @{ id = 'RelatedHitSearchIndicator_Input'; node = Sel 'relatedHitSearchIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC' } 'ROW_BOA_4' }
                @{ id = 'ImageIndicator_Input';            node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'N' } 'ROW_BOA_4' }
            )}
            @{ id = 'ROW_BOA_REQ'; cols = @('12'); hidden = $true; fields = @(
                @{ id = 'Requestor_Input'; node = InpH 'Requestor' 'Requestor (auto-populated from officer profile)' '30' 'ROW_BOA_REQ' @{ initialValue = 'X' } }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- 1 card (v7.6, collapsed from 2): Hull/Reg/CG, Decal/Title/NCIC/PCN, OwnerName/DOB, DestState/Stolen/Image bottom row.'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($personForm, $vehicleForm, $firearmsForm, $articleForm, $boatForm) `
    -DefaultOrder @('Vehicle','Person','Firearm','Article','Boat') `
    -Description "Provider configuration for FL_FCIC v${Version} -- entity forms"

# =====================================================================
# BUNDLE 3: RMS (from KB specs — camelCase, registrationState, autoSelect)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields `
    -Description "Provider configuration for FL_FCIC v${Version} -- RMS bundle"

# =====================================================================
# FINAL ASSEMBLY + WRITE
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $providerBundle, $rmsBundle)
}

# phases/ snapshot mechanism retired 2026-07-13 (commit 3a458757, Tier B/C docs migration) --
# every version is already fully recoverable from git commit history. The directory itself was
# removed then but this -PhasePath call was missed, so this v7.2 build is the first to hit it
# (WriteAllText fails when the parent dir doesn't exist). Matches NJ_NJCJIS's already-migrated
# Write-ProviderJson call (no -PhasePath).
Write-ProviderJson -BundleObject $output -OutPath $outPath `
    -Label "Built FL_FCIC v${Version}" `
    -Version $Version

# Clear pending-updates gate so enforce.ps1 does not block testing after this rebuild
$pendingPath = Join-Path $PSScriptRoot "..\docs\PENDING_UPDATES.txt"
if (Test-Path $pendingPath) { Remove-Item $pendingPath -Force }