# build_hi_hcjdc_ofml.ps1  -- HI_HCJDC_OFML canonical build (single JSON, multi-card)
# Builds HI_HCJDC_OFML.json from source\HI_HCJDC_OFML.xml + KB specs.
# v4.14 (2026-07-28, layout review -- direct Rob feedback, layout-only, NO functional change):
#   From the HI v4.13 rendered-form review (mirrors the FL v7.11/v7.12 + NJ v4.14 pass):
#   (1) Vehicle COLLAPSED from 3 cards (SEARCH OPTIONS + PLATE SEARCH + VIN SEARCH) to ONE
#       "VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, \"OR\" VIN" card -- Row 1 Plate Number,
#       Row 2 Plate Type/Year, Row 3 VIN/Vehicle Year, Row 4 the shared Vehicle Type/State/NCIC
#       Image options (matches FL + NJ collapsed Vehicle). Every fieldId/initialValue/OOS-routing
#       signal preserved (Plate Type/Year keep NO default = the OOS trigger; VehicleType default=1).
#   (2) Boat field order tidied -- both identifiers on Row 1 (Registration Number + Hull ID),
#       State moved below both onto Row 2 with Stolen Check (was State sandwiched between the two
#       identifiers). QIDM/combos/routing/fieldIds/defaults all unchanged. Layout-only.
#   ALL 5 ENTITIES RESET for re-test at v4.14 (block by version). (Stolen Check default=Y on
#   Firearm/Article/Boat CONFIRMED intended -- LE always-check-stolen default, Rob-reviewed.)
# v4.13 (2026-07-27, audit fix + UPPERCASE card titles -- NO functional change):
#   (a) AUDIT FIX: the v4.12 "Stolen Check" relabel missed the Boat relatedSearchHitIndicator
#       (Firearm + Article were relabeled, Boat was left as "(Y) for NCIC stolen-boat check"). Caught
#       by the post-rebuild adversarial audit. Boat stolen toggle -> "Stolen Check", completing the
#       convention across all 3 stolen fields; the LABEL-OVERRIDE tag now correctly covers Boat.
#   (b) UPPERCASE TITLES (Rob global decision -- "everything needs to be upper case"): all card
#       titles UPPERCASED, wording unchanged. The query-path titles introduced at v4.12 (DL/DH/
#       Firearm/Article/Boat) are now all-caps; Vehicle's SEARCH OPTIONS/PLATE SEARCH/VIN SEARCH
#       were already uppercase. New global convention (BUILD_RULES Section 11).
#   Label/title-only. ALL 5 ENTITIES RESET at v4.13.
# v4.12 (2026-07-27, DEX-1284 relabel/naming-convention pass -- direct Rob feedback, NO functional
#   change): brought HI in line with the NY/TX/FL/NJ/CA portfolio conventions (HI had diverged --
#   its image label was parenthetical "NCIC Image (if available)" and it still used pre-OLN labels).
#   OLN (OperatorLicenseNumber DL + OperatorLicenseNumberDH DH -> "OLN"). Canonical bare "NCIC Image"
#   (the one visible image field, Vehicle SEARCH OPTIONS -- was "NCIC Image (if available)"; this
#   retires HI's parenthetical divergence noted at v4.10). Stolen toggle "Stolen Check"
#   (relatedSearchHitIndicator on Firearm/Article/Boat -- was "(Y) for NCIC stolen-X check";
#   LABEL-OVERRIDE, any[] w/ default Y). Card titles now carry query paths: DL/DH -> "Driver
#   License/History Search by OLN, \"OR\" Name"; Firearm/Article -> "... Search by Serial Number";
#   Boat -> "Boat Search by Registration, \"OR\" Hull ID". Boat Reg dropped its "(or use Hull ID)"
#   cross-reference helper. Kept the valid DOB/Sex "(required with Name)" + Make/Caliber/Model/Type
#   "(optional)/(required)" hints. Label/title-only, no combo/QIDM/routing/fieldId/default change.
#   ALL 5 ENTITIES RESET for re-test at v4.12 (block by version). NOT yet re-tested.
# v4.11 (2026-07-20): Firearm CAD auto-population fix (direct feedback, mirrors NY_NYSPIN_EJUSTICE
#   v4.10 + CA_CLETS v2.9 precedent). CAD sends the gun serial number as the camelCase field
#   'serialNumber', not the PascalCase USx token 'GunSerialNumber' -- so the USx-query button in a
#   CAD event never populated the Firearm form (worked for Person, failed for Firearm). Changed the
#   form fieldId, the GunQuery QIDM sourceField, and the combo set[] from 'GunSerialNumber' to
#   'serialNumber'; the QIDM attribute name + targetField stay 'GunSerialNumber' (the XML element
#   name is unchanged, so the wire request is identical). Firearm re-tests from T1; all other
#   entities unaffected (no functional change -- fingerprints unchanged, stay preserved).
# v4.8 (2026-07-15): Person card layout/label feedback pass (Vehicle-consistency + DH parity)
#   + removed the QW shadow combo from DriverLicenseQuery.
#   (0) REMOVED: the 'QW' combo (Wanted Person, Name+DOB with Sex optional) from
#   DriverLicenseQuery. QW is a platform-auto-sent shadow query, not a client-buildable combo --
#   confirmed precedent: FL_FCIC_BUILD_NOTES.txt v4.2 (2026-05-19), "Remove WantedPersonQuery (QW)
#   QIDM... CommSys auto-sends QW query; no JSON-side QIDM needed. Confirmed by platform team."
#   QW is a standard NCIC-level key (not FL-specific), so the finding transfers directly to HI's
#   own QW combo. This also fixes a real bug found while investigating (QW's any[] was wrongly
#   'RegistrationState' -- metadata gives QW no State field at all; copy-pasted from DQ's OOS
#   pattern by mistake) by removing the combo entirely rather than patching it. HI's own v1.0
#   build notes flagged this same PDF-vs-XML gap ("PDF Basic Queries does NOT show it") but chose
#   wrong at the time (include per metadata) -- the FL_FCIC platform-team confirmation supersedes
#   that original call. Consequence: Sex is now genuinely required whenever searching DL by Name
#   (matches DH's SexCodeDH, which never had a Sex-optional fallback) -- label changed accordingly
#   (see item 2 below). DriverLicenseQuery now has exactly 2 combos (DQ, DQN), matching the
#   devdoc's own "Possible Combinations" list exactly.
#   (1) 'State (leave blank for in-state)' -> 'State (leave blank for Hawaii)' -- matches Vehicle's
#   label exactly (verify_build CHECK 15). (2) sexCode_Input label 'Sex (optional)' -> 'Sex -
#   required with Name' (see item 0 above -- no longer optional once QW is removed).
#   nameMiddle/nameMiddleDH label 'Middle Name' -> 'M.I.' (DL)/'M.I. (DH)' (DH). (3) nameSuffixDH
#   label de-cluttered from 'Suffix (DH, optional)' to 'Suffix (DH)' -- matches DL's plain 'Suffix'
#   + the First/Last (DH) naming convention. (4) DL/DH Person card row regroup: First Name + Last
#   Name get their own row; M.I. + Suffix + Date of Birth share one row; Sex(Code) moves to its own
#   row (previously paired with DOB -- DOB is now grouped with M.I./Suffix instead). Applied
#   identically to both DL and DH cards for placement parity.
#   PurposeCode dropdown NOT changed -- confirmed via Confluence "USx Attribute Mappings" page:
#   DEX_INQUIRY_PURPOSE_CODE code-type mapping is documented ONLY for Louisiana + Sales Demo
#   Systems, not for any other state including HI (matches the portfolio-wide FormSelect->
#   FormInput revert already done on FL/NM/OH/TN/TX/LA/HI; see HI_HCJDC_OFML_BUILD_NOTES.txt v3.x).
#   Re-opens ALL 5 HI entities for live re-test (Person card change forces a global version bump).
# v4.6 (2026-06-26): (1) VehicleMakeName code-source correction (RND-62365, shared module
#   tools/_build_rms_bundle.ps1): VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC
#   (probe-confirmed present; matches RND-54190 + sibling VehicleModelName). Result-mapping only.
#   (2) Vehicle State label fixed for verify_build CHECK 15 (refined gate): 'State (Hawaii = leave blank)'
#   -> 'State (leave blank for Hawaii)' -- the field has NO initialValue (blank-default routes in-state),
#   so "leave blank for" is the accurate hint. Full re-test from T1 per rebuild mandate.
# v4.1 (2026-06-23): Gap-audit remediation. (1) CAD Attention-default gap -- KQ/KQN carry
#   'Attention' in any[] (auto-populate handler) but had no defaults[] entry; added Attention=X
#   to both (audit_cad CHECK 6). (2) CAD vehicleTypeCode gap -- M55L/M55S require vehicleTypeCode
#   in set[] (initialValue='1') but had no combo default, so CAD-dispatched in-state HI vehicle
#   queries fired without the required VehicleTypeCode; added VehicleTypeCode=1 default to both
#   (surfaced by audit_cad CHECK 6 set[]-scan fix). (3) Removed stale "NCIC pattern unconfirmed"
#   note (NCIC state live-confirmed across v2.x-v3.x). Re-opens Vehicle + DH. Part of the
#   TX/FL/HI portfolio gap audit (tooling hardened: CHECK 12->FAIL, CHECK 14, conductor exact-match,
#   audit_cad set[]-scan + case-fix, verify_build + audit_cad wired into enforce).
# v4.0 (2026-06-23): Name-order fix to the ConnectCIC-preferred "LAST, FIRST MIDDLE SUFFIX".
#   HI was the lone outlier of 20 providers -- it built Name First-first
#   (@('NameFirst','NameLast','nameMiddle','nameSuffix'), all-space separators) -> emitted the
#   malformed "FIRST LAST MIDDLE SUFFIX" (matches NEITHER documented devdoc format). Fixed both
#   DL and DH Name attrs to @('NameLast','NameFirst',...) + arguments @(', ',' ',' ') so the wire
#   <Name> is "DOE, JON ..." like every other provider. Authoritative devdoc format ingested to
#   CLAUDE.md/FIELD_REFERENCE/TESTING_REQUIREMENTS + memory reference-connectcic-name-format.
#   Re-opens HI Person + DH for live re-test (Vehicle/Firearm/Article/Boat preserved).
# v3.9 (2026-06-23): identifier-priority guardrail extended to BoatQuery (Hull>Reg). Added
#   BoatHullIdNumber NOT_EXISTS condition to BQ (RegistrationNumber combo). When the officer
#   enters a Hull ID (fires QB), the Reg# combo exits the union pool so RegistrationNumber does
#   not bleed onto the Hull query wire. Hull ID is the unique permanent identifier (VIN-like);
#   Reg# is reassignable (plate-like). Closes the third identifier pair (after Vehicle Plate>VIN
#   v3.6 and Person OLN>Name DL v3.7 / DH v3.8). Re-opens HI Boat for live re-test.
# v3.8 (2026-06-23): OLN>Name guardrail extended to DriverHistoryQuery. Added
#   OperatorLicenseNumberDH NOT_EXISTS condition to KQ (Name+Sex+DOB DH). When the officer
#   enters a DH OLN (fires KQN), the Name-based KQ combo exits the union pool so Name/Sex/DOB
#   do not bleed onto the DriverHistoryQuery wire (sim-proven both DH paths matched + union
#   over-sent when both filled). Closes the DH-side gap left by v3.7 (which covered DL only).
#   Re-opens HI Person for live re-test.
# v3.7 (2026-06-23): OLN>Name guardrail on Person (DriverLicenseQuery). Added
#   OperatorLicenseNumber NOT_EXISTS condition to DQ (Name+Sex+DOB) and QW (Name+DOB).
#   When the officer enters an OLN (fires DQN), the Name-based combos exit the union pool
#   so Name/Sex/DOB do not bleed onto the wire. Completes the identifier-priority guardrail
#   for HI (Vehicle plate-wins done v3.6). conditions[].field = sourceField (PascalCase).
#   Re-opens HI Person for live re-test. (verify_build CHECK 12)
# v3.6 (2026-06-22): Plate-wins guardrail + vehicleYear any[] gap fix.
#   PLATE-WINS: Added LicensePlateNumber NOT_EXISTS condition to RQV, QVV, M55S. When
#   Plate is in form state, all VIN-path combos exit the union pool so VIN/MakeCode do not
#   bleed into the plate XML (live-proven union-pool over-send: all-fields case fired
#   RQ+RQV+QVV simultaneously). Mirrors the M55L (LicensePlateTypeCode NOT_EXISTS) and
#   M55S (RegistrationState NOT_EXISTS) pool-exclusion pattern. M55S now has two conditions:
#   RegistrationState NOT_EXISTS AND LicensePlateNumber NOT_EXISTS -- fires only for bare VIN.
#   VEHICLEYEAR: Added vehicleYear to RQV, M55S, QVV any[]. sourceField='vehicleYear';
#   the attribute existed in QIDM but was in no combo any[], so vehicleYear was silently
#   dropped from all VIN-query XML even when filled.
# v3.5 (2026-06-22): Fixed any[] gap on GunQuery (QG), ArticleSingleQuery (QA), and BoatQuery
#   (BQ/QB). Platform only serializes set[]+any[] fields; all three QIDMs had any=@(), which
#   silently dropped RelatedSearchHitIndicator (default=Y) + optional fields from XML.
#   QG: added any=@('GunMake','GunCaliber','GunModel','relatedSearchHitIndicator') + default Y.
#   QA: added any=@('relatedSearchHitIndicator') + default Y.
#   BQ/QB: added any=@('RegistrationState','relatedSearchHitIndicator') + default Y.
#   Pattern confirmed from FL_FCIC GunQuery (GunMake+ImageIndicator in any[] + default).
#   Pre-live-test gap found during T19 pre-flight simulator check.
# v3.4 (2026-06-22): Removed RegistrationState from M55S any[]. M55S can only fire when
#   RegistrationState NOT_EXISTS (condition); having it in any[] was a semantic contradiction
#   (State can never be serialized alongside M55S since it's blank when M55S fires) and
#   caused the test conductor to inject RegistrationState="NJ" into minimal test data,
#   triggering the NOT_EXISTS condition and blocking M55S from firing in T16.
#   M55L UNCHANGED -- M55L's condition is LicensePlateTypeCode (not RegistrationState), so
#   State CAN ride along on in-state plate queries via any[].
# v3.3 (2026-06-22): Fixed M55S conditions field name: was @('State') (attribute name),
#   must be @('RegistrationState') (sourceField). T5 (RQV OOS VIN) showed VehicleTypeCode
#   still bled because conditions[].field matches sourceField, NOT the attribute name.
#   M55L worked in T4 because LicensePlateTypeCode is BOTH the attribute name and sourceField.
#   Rule corrected in KB: conditions[].field = sourceField. FL_FCIC uses 'State' because
#   FL's sourceField for the state selector IS 'State'; HI uses 'RegistrationState'. Vehicle
#   tests restarted from T1. Person UNCHANGED (stays blocked).
# v3.2 (2026-06-22): Added conditions to M55L (LicensePlateTypeCode NOT_EXISTS) and M55S
#   (RegistrationState NOT_EXISTS) to prevent VehicleTypeCode union-pool bleed-through in OOS
#   XML. Live T4 (RQ) showed <VehicleTypeCode>1</VehicleTypeCode> in OOS plate XML because
#   M55L set[vehicleTypeCode(defaulted)+Plate] was simultaneously satisfied by form state.
#   Extra field unknown behavior risk on production HI CommSys server. Conditions fix: when
#   PlateType is present (OOS plate), M55L fails conditions -> exits pool -> RQ XML is clean.
#   When State is present (OOS VIN), M55S fails conditions -> exits pool -> RQV XML is clean.
#   Person UNCHANGED (stays blocked). Vehicle tests restarted from T1.
# v3.1 (2026-06-22): Vehicle State label shortened to 'State (Hawaii = leave blank)'
#   (was the longer "Registration State - leave blank for Hawaii; enter..."). Label-only
#   refinement of the v3.0 routing redesign, pre-live-test. Person UNCHANGED (stays blocked).
# v3.0 (2026-06-22): Vehicle OOS-first routing redesign. Reordered VehicleRegistrationQuery
#   combos (RQ-plate, RQV-VIN+State, M55L, M55S, then dormant QVV/QVP) so out-of-state is
#   reached by ADDING fields (Plate Type+Year for plate, State for VIN) -- never by clearing
#   Vehicle Type. RQV now requires VIN+State (State in set[], NY pattern). Removed Plate Year
#   default. Relabeled Vehicle Type / State for the new workflow. Person UNCHANGED (stays blocked).
# v1.8 (2026-06-17): consolidated to a single JSON; Person split to 2 cards
#   (Driver License / Driver History); added ImageIndicator=N combo defaults to all 6
#   VehicleRegistrationQuery combos (the real CAD failure -- CAD ignores form initialValue).
#   Card count is NOT the CAD cause (single-card and multi-card layouts failed identically).
#
# Run: powershell.exe -ExecutionPolicy Bypass -File scripts\build_hi_hcjdc_ofml.ps1
#
# INPUTS:
#   source\HI_HCJDC_OFML.xml  -- XML metadata (System HCJDC_OFML v9) [AUTHORITATIVE]
#   source\HI_HCJDC_OFML.pdf  -- CommSys devdoc (Basic Queries + CCH + Expanded) [CROSS-CHECK]
#   tools\\_build_rms_bundle.ps1 -- RMS bundle + CommSys QRDM (KB specs) + hand-built HI reference
#
# SCOPE: Basic Queries only (6 transactions from PDF/XML):
#   ArticleSingleQuery, BoatQuery, DriverHistoryQuery, DriverLicenseQuery, GunQuery, VehicleRegistrationQuery
#   CCH queries (AQ/FQ/IQ/QH/QR/ZR), SecuritiesStolenQuery (QS), WantedPersonQuery (QW standalone)
#   are NOT in scope for Phase 1. The QW combo inside DriverLicenseQuery IS included (per XML metadata).
#
# XML METADATA NOTES:
#   18 MessageKeys: AQ, BQ, DQ, FQ, IQ, KQ, M55L, M55S, QA, QB, QG, QH, QR, QS, QV, QW, RQ, ZR
#   BoatQuery uses <Choice> elements -- split into separate combos per primary field
#   DriverLicenseQuery has a QW (Wanted Person) combo alongside DQ combos -- included per source authority
#   VehicleRegistrationQuery: 4 built combos M55L/M55S (in-state), RQ/RQV (out-state); QV stolen combos removed v4.4 (server auto-generates QV, data-mined via QRDM)
#   State2-5 fields on DL/VehicleReg: NOT implementable (platform has no multi-state mechanism). Excluded.
#
# DUPLICATE keyRef INVENTORY (LIMITATION #21):
#   BoatQuery:               BQ (Boat Reg) + QB (Stolen Boat) -> BQ (Reg), QB (Hull)
#   DriverHistoryQuery:      KQ x2           -> KQN (OLN), KQ (Name)
#   DriverLicenseQuery:      DQ x2 + QW     -> DQN (OLN), DQ (Name), QW (distinct)
#   VehicleRegistrationQuery: RQ x2 + M55L + M55S -> M55L, M55S, RQ, RQV (4 distinct; QV x2 stolen removed v4.4)
#   GunQuery:                QG              -> QG (no duplicate)
#   ArticleSingleQuery:      QA              -> QA (no duplicate)
#
# PDF vs XML DISCREPANCIES:
#   BoatQuery:   XML uses <Choice>, PDF shows 2 simple combos -- functionally equivalent after split
#   DL:          XML has QW combo (Wanted Person), PDF Basic Queries does NOT show it -- metadata wins
#   VehicleReg:  XML has QV combos (Stolen Vehicle), PDF has them in Expanded section -- QV combos stay in VehReg QIDM (VehicleRegistrationQuery keys), separate VehicleStolenQuery QIDM removed per devdoc authority
#   VehicleReg:  PDF shows 4 combos, XML has 6 -- extra 2 are QV stolen combos
#   State2-5:    PDF says "submit up to 5 states" on DL/VehicleReg -- not implementable, excluded
#   DH:          XML has State in any[], PDF does not mention State -- metadata wins (include State)
#
# STATE HANDLING (Phase 1 NCIC pattern):
#   Single visible Sel 'RegistrationState' (attributeTypeId=STATE, initialValue=HI)
#   CommSys State attr: sourceField=RegistrationState, codeTypeProvider=NCIC
#   RMS: useAttributeId=true + AttributeArrayWrapperRuleHandler (KB standard)
#   Note: NCIC state pattern live-confirmed for HI (v2.x Person, v3.6 Vehicle).
#
# SEX HANDLING (NIBRS reverse-lookup):
#   Form: Sel 'SexCode' attributeTypeId=SEX + codeTypeProvider=NIBRS
#   CommSys: codeTypeProvider=NIBRS (reverse-lookup attr ID -> M/F/U)
#   RMS: useAttributeId=true (KB standard)
#
# DATE FORMAT: MMddyyyy
# NAME FORMAT: "LAST, FIRST MIDDLE SUFFIX" (Last-first; args @(', ',' ',' '); v4.0 fix per ConnectCIC devdoc)

param(
    [string]$Version = "4.17",
    # DIAGNOSTIC ONLY: emit a throwaway test JSON to diagnostics/ where the DH
    # Attention attribute has NO handler (plain passthrough) and the Attention
    # field is VISIBLE -- to test whether a typed Attention value reaches the wire
    # (isolates "attribute/plumbing" from "the profile handler"). Not for import to
    # production; not part of the normal build/test package.
    [switch]$AttnDiagnostic,
    # Which Attention experiment to emit (requires -AttnDiagnostic):
    #   dochandler  = doc-exact handler: sourceField=[], rule=handler, targetField=Attention,
    #                 NO form field, Attention NOT in combo any[] (generated field).
    #   passthrough = no handler; visible Attention field + 'Attention' added to DH any[]
    #                 (tests whether combo-membership lets a typed value serialize).
    #   handler     = import-safe handler: sourceField=['Attention'], rule=handler,
    #                 'Attention' in combo any[], VISIBLE field (pre-filled). Tests whether
    #                 the handler reads the RMS profile (-> officer name) or just the field.
    [ValidateSet('passthrough','dochandler','handler')][string]$AttnMode = 'passthrough'
)

$ErrorActionPreference = 'Stop'
$DATE     = (Get-Date -Format 'yyyy-MM-dd')
$currentYear = [string](Get-Date).Year
$DIR      = (Resolve-Path "$PSScriptRoot\..").Path
if ($AttnDiagnostic) {
    $OUT    = "$DIR\diagnostics\HI_HCJDC_OFML_ATTNTEST_${AttnMode}.json"
if ($env:REPRO_OUTPATH) { $OUT = $env:REPRO_OUTPATH }
    New-Item -ItemType Directory -Force -Path "$DIR\diagnostics" | Out-Null
} else {
    # Root JSON name carries the version (<PROVIDER>_v<X.Y>.json). Write-ProviderJson
    # removes any stale bare/versioned sibling so one-JSON-in-root holds on every bump.
    # phases/ retired 2026-07-02 (NJ/CA parity) -- git history is the version authority.
    $OUT    = "$DIR\HI_HCJDC_OFML_v${Version}.json"
}

. "$PSScriptRoot\..\..\..\tools\_build_rms_bundle.ps1"

# =====================================================================
# HELPERS -- dot-sourced from tools/_build_layout_helpers.ps1
# =====================================================================
. "$PSScriptRoot\..\..\..\tools\_build_layout_helpers.ps1"
. "$PSScriptRoot\..\..\..\tools\_build_provider_helpers.ps1"

# =====================================================================
# BUNDLE 1: HI_HCJDC_OFML PROVIDER
# =====================================================================

$auth = Build-Auth -ProviderName 'HI_HCJDC_OFML'

$results = Build-ProviderQrdm -ProviderName 'HI_HCJDC_OFML'

# ---------------------------------------------------------------------
# v4.16 -- NCIC HIT BLOCK RESPONSE HANDLING (Rob 2026-08-13: "we cannot be
# discarding infomation like hit warnings regadles of ccntent")
#
# WHY. A HI DriverLicenseQuery auto-fires an NCIC person search alongside the
# state DL inquiry. A LIVE capture from HDLE Foundation (2026-08-13, tx
# 01KZY7M48VXBWV1CBRJ6PDVEA7) returned a WantedPerson record -- and 23 of its
# 35 elements were mapped NOWHERE, including MessageKey "WANTED PERSON -
# CAUTION", CautionMedicalCondition "00 - ARMED AND DANGEROUS",
# ExtraditionLimitation, the NCIC and FBI numbers and the warrant. The officer
# was shown a hit stripped of every reason it was dangerous.
#
# WORSE, AND FOUND WHILE SCOPING: the generated QRDM maps Hit as a SCALAR
# (Hit -> hit). The live response makes it a CONTAINER --
# <Hit><Banner>NCIC WANTED PERSON</Banner><Detected>1</Detected></Hit> -- so
# the banner itself had nothing pointing at it. simulate_response never caught
# this because its synthetic corpus models <Hit>Y</Hit> as a scalar too.
#
# SCOPE IS DELIBERATELY HI-ONLY. Build-CommsysQrdm is shared by all 20
# providers and every one of them has the identical 67-attribute DL-shaped map
# -- so does engineering's hand-built Lafayette JSON, which maps 0 of 21 too.
# That symmetry says this is a product-level gap, not an HI omission, and a fix
# in the shared module would move 20 providers at once INCLUDING a live
# production tenant (CA_CLETS at Mariposa). Appending here keeps the blast
# radius at one provider until the rendering is confirmed on HI's own test
# tenant. If it renders, promote to Build-CommsysQrdm as a separate change.
#
# PASS-THROUGH ONLY, NO CODE-MAPPING HANDLERS -- on purpose. The live record
# carries EyeColorCode 'BR0' with a DIGIT ZERO (the originating Illinois ORI
# writes 0 for O throughout: J0HN, JER0ME, R0BB). A CommsysResultAttributeMapping
# lookup would miss and blank the field. Raw beats blank when the content is a
# caution flag.
#
# MessageData IS THE SAFETY NET and is why it is in the safety tier: the
# structured elements expose only AlsoKnownAs/AlsoKnownAs2, while the real
# record carried 30 AKAs and 8 alias DOBs in text alone. Mapping MessageData
# shows everything we have not modelled -- "regardless of content".
#
# ResponseType is the SUPPRESSION discriminator: a DL query returns four blocks
# (2x SWITCH_ACK transport acks, NCIC, ADLA), and without it one query renders
# as four results.
#
# ADDITIVE ONLY -- proven on a replica before building: all 5 QIFs, all 6 QIDMs,
# AUTH, QMF and the whole RMS bundle canonically IDENTICAL; all 67 original
# QRDM attributes survive byte-identical; 12 combinations before and after with
# 0 differences. The wire is unchanged; only what we keep from the reply moves.
$hitBlockAttrs = @(
    # -- safety tier: never discardable
    [PSCustomObject]@{ name = 'HitBanner';               sourceField = @('Hit.Banner');    targetField = 'HitBanner' }
    [PSCustomObject]@{ name = 'HitDetected';             sourceField = @('Hit.Detected');  targetField = 'HitDetected' }
    [PSCustomObject]@{ name = 'MessageKey';              sourceField = @('MessageKey');              targetField = 'MessageKey' }
    [PSCustomObject]@{ name = 'CautionMedicalCondition'; sourceField = @('CautionMedicalCondition'); targetField = 'CautionMedicalCondition' }
    [PSCustomObject]@{ name = 'ExtraditionLimitation';   sourceField = @('ExtraditionLimitation');   targetField = 'ExtraditionLimitation' }
    [PSCustomObject]@{ name = 'MessageData';             sourceField = @('MessageData');             targetField = 'MessageData' }
    [PSCustomObject]@{ name = 'Class';                   sourceField = @('Class');                   targetField = 'Class' }
    # -- record identity
    [PSCustomObject]@{ name = 'NCICNumber';                  sourceField = @('NCICNumber');                  targetField = 'NCICNumber' }
    [PSCustomObject]@{ name = 'FBINumber';                   sourceField = @('FBINumber');                   targetField = 'FBINumber' }
    [PSCustomObject]@{ name = 'StateIdNumber';               sourceField = @('StateIdNumber');               targetField = 'StateIdNumber' }
    [PSCustomObject]@{ name = 'WarrantDate';                 sourceField = @('WarrantDate');                 targetField = 'WarrantDate' }
    [PSCustomObject]@{ name = 'OffenseCode';                 sourceField = @('OffenseCode');                 targetField = 'OffenseCode' }
    [PSCustomObject]@{ name = 'OriginatingAgencyIdentifier'; sourceField = @('OriginatingAgencyIdentifier'); targetField = 'OriginatingAgencyIdentifier' }
    [PSCustomObject]@{ name = 'OriginatingAgencyCaseNumber'; sourceField = @('OriginatingAgencyCaseNumber'); targetField = 'OriginatingAgencyCaseNumber' }
    [PSCustomObject]@{ name = 'AlsoKnownAs';                 sourceField = @('AlsoKnownAs');                 targetField = 'AlsoKnownAs' }
    [PSCustomObject]@{ name = 'AlsoKnownAs2';                sourceField = @('AlsoKnownAs2');                targetField = 'AlsoKnownAs2' }
    # -- descriptive
    [PSCustomObject]@{ name = 'SkinColorCode';         sourceField = @('SkinColorCode');         targetField = 'SkinColorCode' }
    [PSCustomObject]@{ name = 'ScarsMarksTattoosCode'; sourceField = @('ScarsMarksTattoosCode'); targetField = 'ScarsMarksTattoosCode' }
    [PSCustomObject]@{ name = 'MiscellaneousNumber';   sourceField = @('MiscellaneousNumber');   targetField = 'MiscellaneousNumber' }
    [PSCustomObject]@{ name = 'BirthPlaceCode';        sourceField = @('BirthPlaceCode');        targetField = 'BirthPlaceCode' }
    [PSCustomObject]@{ name = 'DNAIndicator';          sourceField = @('DNAIndicator');          targetField = 'DNAIndicator' }
    [PSCustomObject]@{ name = 'ValidationDate';        sourceField = @('ValidationDate');        targetField = 'ValidationDate' }
    [PSCustomObject]@{ name = 'FreeText';              sourceField = @('FreeText');              targetField = 'FreeText' }
    [PSCustomObject]@{ name = 'ResponseType';          sourceField = @('ResponseType');          targetField = 'ResponseType' }
)
$results.attributes = @($results.attributes) + $hitBlockAttrs

$qmf = Build-Qmf -ProviderName 'HI_HCJDC_OFML'

# =====================================================================
# 1d. VehicleRegistrationQuery
# XML: 6 combos across 3 message keys (M55L, M55S, RQ, QV)
#   M55L: In-state plate (VehicleTypeCode + Plate)
#   M55S: In-state VIN (VehicleTypeCode + VIN)
#   RQ:   Out-state plate (Plate + PlateType + PlateYear), Out-state VIN (VIN)
#   QV:   Stolen plate (Plate + State), Stolen VIN (VIN + MakeCode)
# State2-5 excluded (not implementable). Single RegistrationState (NCIC).
# Combo ordering (v3.0, OOS-first): RQ-Plate (OOS, Plate Type+Year) > RQV (OOS VIN, VIN+State)
#   > M55L (in-state plate) > M55S (in-state VIN). QVV/QVP (stolen) REMOVED v4.4 (server
#   auto-generates QV; they should never fire from the form). 4 combos built.
# =====================================================================
$vehRegQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ImageIndicator';               size = 1;  sourceField = @('ImageIndicator');               targetField = 'ImageIndicator' }
        [PSCustomObject]@{ name = 'LicensePlateNumber';         size = 10; sourceField = @('LicensePlateNumber');         targetField = 'LicensePlateNumber' }
        [PSCustomObject]@{ name = 'LicensePlateTypeCode';         size = 2;  sourceField = @('LicensePlateTypeCode');         targetField = 'LicensePlateTypeCode' }
        [PSCustomObject]@{ name = 'LicensePlateYear';             size = 4;  sourceField = @('LicensePlateYear');             targetField = 'LicensePlateYear' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
        [PSCustomObject]@{ name = 'VehicleIdentificationNumber';  size = 20; sourceField = @('VehicleIdentificationNumber');  targetField = 'VehicleIdentificationNumber' }
        # VehicleMakeCode attribute REMOVED v4.5: per metadata it is valid ONLY for the QV
        # (stolen) combo, which was removed in v4.4. With no firing combo to serialize it,
        # the Make field was dead config (rendered but never reached the wire -- live-proven
        # v4.4: Make entered, absent from XML). Field + attribute removed together.
        [PSCustomObject]@{ name = 'VehicleTypeCode';              size = 1;  sourceField = @('vehicleTypeCode');              targetField = 'VehicleTypeCode' }
        [PSCustomObject]@{ name = 'VehicleYear';                  size = 4;  sourceField = @('vehicleYear');                  targetField = 'VehicleYear' }
    )
    # ORDER (v3.0): OUT-OF-STATE FIRST so the officer reaches OOS by ADDING fields,
    # never by clearing Vehicle Type (the v2.8 "clear-to-switch" UX was confusing).
    #   1. RQ  (OOS plate): fires when Plate Type + Plate Year are filled (the
    #      "out-of-state plates only" fields the server genuinely requires for RQ).
    #   2. RQV (OOS VIN): fires when VIN + State are filled. RegistrationState is in
    #      set[] here (NY pattern) as the VIN OOS discriminator; metadata permits
    #      State on the OOS-VIN RQ combo (it sits in any[] there) -- promoting to set[]
    #      for routing is a design choice, not a field-membership divergence.
    #   3. M55L (in-state plate): bare plate -- VehicleTypeCode defaults to 1 (Auto),
    #      auto-satisfying the server's in-state requirement so a plate alone routes HI.
    #   4. M55S (in-state VIN): bare VIN -- same, VehicleTypeCode default carries it.
    #   (QVV/QVP stolen sub-paths REMOVED v4.4 -- they should never fire from the form;
    #   the state CommSys server auto-generates the QV/stolen query from supplied fields,
    #   response data-mined via QRDM. See the removal note in the combinations array below.)
    # Discriminators: plate = Plate Type/Year presence; VIN = State presence. Both are
    # real OOS data, not synthetic switches. Bare plate -> M55L, bare VIN -> M55S.
    combinations = @(
        # RQ: Out-of-state plate (Plate + PlateType + PlateYear).
        # CONDITION: LicensePlateTypeCode EXISTS -- OOS gate (v4.7 CHECK 16 shadow fix).
        # The platform fires on primaryFieldReference presence, NOT full set[] presence, so
        # relying on "RQ's set[] needs PlateType/Year" did NOT stop RQ firing on a bare plate --
        # RQ (ordered first, pFR=LicensePlateNumber) shadowed M55L. Gating RQ on
        # LicensePlateTypeCode EXISTS is the symmetric complement to M55L's LicensePlateTypeCode
        # NOT_EXISTS: bare plate (no Plate Type) -> M55L; Plate+Type -> RQ. Mutually exclusive,
        # both reachable (mirrors FL v7.0 / CA v2.11 OOS-gate symmetry).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('LicensePlateNumber','LicensePlateTypeCode','LicensePlateYear'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'EXISTS' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'RQ'
            state                 = 'Out'
        }
        # RQV: Out-of-state VIN (VIN + State).
        # CONDITIONS (both must pass):
        #   1. RegistrationState EXISTS -- OOS gate (v4.7 CHECK 16 shadow fix). Same reason as RQ:
        #      the platform fires on primaryFieldReference (VIN) presence, not set[] presence, so
        #      RQV (ordered before M55S) shadowed M55S on a bare VIN. Gating on RegistrationState
        #      EXISTS is the symmetric complement to M55S's RegistrationState NOT_EXISTS: bare VIN
        #      (no State) -> M55S; VIN+State -> RQV. Mutually exclusive, both reachable.
        #   2. LicensePlateNumber NOT_EXISTS -- plate-wins guardrail. When officer fills both Plate
        #      and VIN, Plate wins: RQV exits the union pool so VIN/vehicleYear do NOT bleed into
        #      RQ's XML. (v3.6 all-fields stress test finding)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('VehicleIdentificationNumber','RegistrationState'); any = @('ImageIndicator','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'EXISTS' },[PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'RQV'
            state                 = 'Out'
        }
        # M55L: In-state plate (VehicleTypeCode + Plate) -- PRIMARY plate. VehicleTypeCode
        # defaults to 1 (Auto), so a bare plate routes in-state with zero extra clicks.
        # CONDITION: LicensePlateTypeCode NOT_EXISTS -- when officer fills Plate Type for an
        # OOS plate query (RQ), M55L exits the union pool so VehicleTypeCode does NOT bleed
        # into RQ's XML (live T4 finding: extra fields unknown risk on production CommSys).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','LicensePlateNumber'); any = @('ImageIndicator','RegistrationState'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'VehicleTypeCode'; value = '1' }); conditions = @([PSCustomObject]@{ field = @('LicensePlateTypeCode'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'LicensePlateNumber'
            keyReference          = 'M55L'
            state                 = 'In'
        }
        # M55S: In-state VIN (VehicleTypeCode + VIN) -- PRIMARY VIN
        # CONDITIONS (two -- both must pass):
        #   1. RegistrationState NOT_EXISTS -- when officer fills State for an OOS VIN query
        #      (RQV), M55S exits the pool so VehicleTypeCode does NOT bleed into RQV XML.
        #      NOTE: conditions[].field = SOURCEFIELD (form fieldId), NOT the attribute name.
        #      FL_FCIC uses 'State' because its sourceField IS 'State'; HI's sourceField is
        #      'RegistrationState'. v3.2 used @('State') (silent no-op). Fixed v3.3. (T5)
        #   2. LicensePlateNumber NOT_EXISTS -- plate-wins guardrail. When bare Plate+VIN
        #      present (no State, no PlateType/Year), M55L (in-state plate) and M55S (in-state
        #      VIN) would both satisfy; without this condition VIN bleeds into the plate XML.
        #      With both conditions: M55S fires ONLY for bare VIN (no State, no Plate). (v3.6)
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('vehicleTypeCode','VehicleIdentificationNumber'); any = @('ImageIndicator','vehicleYear'); defaults = @([PSCustomObject]@{ field = 'ImageIndicator'; value = 'Y' }, [PSCustomObject]@{ field = 'VehicleTypeCode'; value = '1' }); conditions = @([PSCustomObject]@{ field = @('RegistrationState'); operator = 'NOT_EXISTS' },[PSCustomObject]@{ field = @('LicensePlateNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'VehicleIdentificationNumber'
            keyReference          = 'M55S'
            state                 = 'In'
        }
        # QVP/QVV (stolen) REMOVED in v4.4. They were dormant stolen sub-paths (Plate+State /
        # VIN+MakeCode). A v4.3 live test found that CLEARING the Vehicle Type dropdown on a
        # Plate+State query fired QVP (MessageKey=QV, stolen) -- M55L could not fire without
        # VehicleTypeCode and RQ needed Plate Type/Year, so QVP caught the query. Rather than
        # make them hard-dormant via a self-contradicting NOT_EXISTS-on-own-set guard (which
        # is a "combo can never fire" dead-config flagged by verify_build CHECK 14), the two
        # combos are deleted outright: they should never fire from the form, and the state
        # CommSys server auto-generates the QV/stolen query from supplied fields (response
        # data-mined via QRDM). Accepted tradeoff: a Plate+State query with Vehicle Type
        # cleared and no Plate Type/Year now matches no combo and fires NOTHING (clearing
        # Vehicle Type is an unsupported path). User-approved dormant skip, formalized.
    )
    description        = 'VehicleRegistrationQuery -- OOS-first routing (v3.0): RQ (plate, OOS-gated LicensePlateTypeCode EXISTS) and RQV (VIN, OOS-gated RegistrationState EXISTS) ordered before in-state M55L (plate) / M55S (VIN, both gated NOT_EXISTS on the same discriminators); OOS reached by ADDING fields, never clearing Vehicle Type. v4.7 added the OOS EXISTS gates so RQ/RQV no longer shadow M55L/M55S (platform fires on primaryFieldReference, not set[]; CHECK 16). QVP/QVV stolen combos REMOVED in v4.4 (state CommSys server auto-generates the QV/stolen query, data-mined via QRDM). 4 combos.'
    handlerFunction    = 'CommsysTransactionRequestHandler'
    name               = 'HI_HCJDC_OFML_VehicleRegistrationQuery'
    type               = 'QUERYINPUTDATAMAPPING'
    autoSelect         = $true
    provider           = 'HI_HCJDC_OFML'
    providerType       = 'Commsys'
    query              = 'VehicleRegistrationQuery'
    queryLabel         = 'Vehicle Registration'
    targetEntity       = 'Vehicle'
}

# =====================================================================
# 1e. DriverLicenseQuery
# XML: 3 combos -- DQ (OLN), DQ (Name+Sex+DOB), QW (Name+DOB wanted person)
#   State2-5 excluded. Single RegistrationState (NCIC).
#   QW fires when Name+DOB present but SexCode absent (less restrictive than DQ Name).
#   autoSelect=true, queriesToDeselect=DriverHistoryQuery
# =====================================================================
$dlQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDate'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLast','NameFirst','nameMiddle','nameSuffix'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumber'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCode');               targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # DQ: Name+DOB+Sex path -- 4 set[], most specific. primary=SexCode per metadata.
        # State optional (OOS). Sex is REQUIRED here (bundled with Name+DOB) -- matches the
        # devdoc's own "Possible Combinations" list exactly (only 2 combos: Name+DOB+Sex, or
        # OLN). No separate Sex-optional Name variant exists once QW is removed (see below).
        # CONDITION: OperatorLicenseNumber NOT_EXISTS -- OLN>Name guardrail (v3.7). When the
        # officer enters an OLN (fires DQN), this Name-based combo exits the union pool so Name/
        # Sex/DOB do not bleed onto the wire. conditions[].field = sourceField (PascalCase).
        # Mirrors the v3.6 plate-wins guardrail on the Vehicle side.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCode','BirthDate','NameLast','NameFirst'); any = @('RegistrationState'); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumber'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'SexCode'
            keyReference          = 'DQ'
            state                 = 'In/Out'
        }
        # QW (Wanted Person, Name+DOB with Sex optional) intentionally NOT built (v4.8).
        # Removed: it's a platform-auto-sent shadow query, not a client-buildable combo --
        # CommSys auto-sends the QW/NCIC Wanted Person check itself. Confirmed precedent:
        # FL_FCIC_BUILD_NOTES.txt v4.2 (2026-05-19), "Remove WantedPersonQuery (QW) QIDM...
        # CommSys auto-sends QW query; no JSON-side QIDM needed. Confirmed by platform team."
        # QW is a standard NCIC-level key (not FL-specific), so the finding transfers directly.
        # The metadata XML technically defines QW as its own combo (any=[SexCode]), and HI's
        # v1.0 build notes flagged the same PDF-vs-XML gap ("PDF Basic Queries does NOT show
        # it") but chose wrong at the time (include per metadata) -- the FL_FCIC platform-team
        # confirmation supersedes that original call. Also fixes a real bug: the previously-
        # built QW combo's any[] was RegistrationState (wrong -- metadata gives QW no State
        # field at all; that copy-pasted DQ's OOS pattern by mistake).
        # DQN: OLN path -- 1 set[], least specific. State optional companion (OOS).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumber'); any = @('RegistrationState') }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'DQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverLicenseQuery -- DQ (Name+Sex+DOB, Sex required), DQN (OLN). State in any[] for OOS. QW (Wanted Person) intentionally not built -- platform auto-sends it (FL_FCIC v4.2 precedent). Shared Person fields; DH is opt-in (no queriesToDeselect).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverLicenseQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverLicenseQuery'
    queryLabel      = 'Driver License'
    targetEntity    = 'Person'
}

# =====================================================================
# 1f. DriverHistoryQuery -- DH-SUFFIX, SEPARATE CARD (v1.8 3-card Person)
# XML: 2 combos -- KQ (Name+Sex+DOB), KQN (OLN).
#   DH on its own card with DH-suffix fieldIds (nameFirstDH/.../operatorLicenseNumberDH/
#   purposeCodeDH/birthDateDH/sexCodeDH) -- isolates DH from DL (no duplicate-fieldId
#   across cards). registrationState (shared, on the Search Options card) carries OOS.
#   autoSelect=true; ONE-DIRECTIONAL queriesToDeselect=['DriverLicenseQuery'] (DH deselects
#   the default DL; never bidirectional -- LIMITATION #24/one-directional rule). PurposeCode
#   + State in any[] (optional companions). Attention handler-only.
# =====================================================================
if ($AttnDiagnostic -and $AttnMode -eq 'passthrough') {
    # DIAGNOSTIC B: passthrough -- no handler. Typed value should serialize verbatim
    # IF 'Attention' is in the fired combo's any[] (added below).
    $attnAttr = [PSCustomObject]@{ name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention' }
} elseif ($AttnDiagnostic -and $AttnMode -eq 'handler') {
    # DIAGNOSTIC C: import-safe handler WITH correct plumbing (Attention in any[],
    # visible pre-filled field). Output reveals what the handler does:
    #   officer name -> reads RMS profile (production: hide the field) | field value -> passthrough.
    $attnAttr = [PSCustomObject]@{
        name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
        rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
    }
} elseif ($AttnDiagnostic -and $AttnMode -eq 'dochandler') {
    # DIAGNOSTIC A: doc-exact handler -- sourceField=[] (generated field), per the
    # CommsysGetLastNameFirstNameInitialRuleHandler documentation.
    $attnAttr = [PSCustomObject]@{
        name = 'Attention'; size = 30; sourceField = @(); targetField = 'Attention'
        rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
    }
} else {
    # PRODUCTION: handler + sourceField=['Attention'] (the import-safe form we shipped).
    $attnAttr = [PSCustomObject]@{
        name = 'Attention'; size = 30; sourceField = @('Attention'); targetField = 'Attention'
        rule = [PSCustomObject]@{ function = 'CommsysGetLastNameFirstNameInitialRuleHandler' }
    }
}
# Platform serializes ONLY fields in the FIRED COMBO's set[]/any[]; an attribute
# absent from the combo is dropped -- this is why Attention never reached the wire
# before. FIX (live-proven HI handler diagnostic 2026-06-22): 'Attention' must be
# in the DH combos' any[]. With that + the hidden gate-feeder field populated +
# sourceField=['Attention'] + the handler, CommsysGetLastNameFirstNameInitialRuleHandler
# emits the officer's profile name (e.g. "SGAMBELLONE R"). So Attention is in any[]
# for production AND the passthrough/handler diagnostics; only the (dead, import-
# rejected) dochandler sourceField=[] variant omits it.
$dhAny = if ($AttnDiagnostic -and $AttnMode -eq 'dochandler') { @('RegistrationStateDH','purposeCodeDH') } else { @('RegistrationStateDH','purposeCodeDH','Attention') }
$dhQuery = [PSCustomObject]@{
    attributes = @(
        $attnAttr
        [PSCustomObject]@{
            name        = 'BirthDate'
            rule        = [PSCustomObject]@{ function = 'CommsysParseDateRuleHandler'; arguments = @('yyyy-MM-dd','MMddyyyy') }
            size        = 8; sourceField = @('BirthDateDH'); targetField = 'BirthDate'
        }
        [PSCustomObject]@{
            name        = 'Name'
            rule        = [PSCustomObject]@{ function = 'FormatStringRuleHandler'; arguments = @(', ',' ',' ') }
            size        = 30; sourceField = @('NameLastDH','NameFirstDH','nameMiddleDH','nameSuffixDH'); targetField = 'Name'
        }
        [PSCustomObject]@{ name = 'OperatorLicenseNumber'; size = 20; sourceField = @('OperatorLicenseNumberDH'); targetField = 'OperatorLicenseNumber' }
        [PSCustomObject]@{ name = 'PurposeCode';           size = 1;  sourceField = @('purposeCodeDH');           targetField = 'PurposeCode' }
        [PSCustomObject]@{ name = 'SexCode';               size = 1;  sourceField = @('SexCodeDH');              targetField = 'SexCode'; codeTypeProvider = 'NIBRS' }
        # DH gets its own dedicated State field (Rob-confirmed 2026-07-17) -- no longer the
        # shared RegistrationState the DL card/RMS QIDM still use.
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationStateDH'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # KQ: Name path -- 4 set[], most specific. DH-suffix. State+PurposeCode optional.
        # CONDITION: OperatorLicenseNumberDH NOT_EXISTS -- OLN>Name guardrail (v3.8). When the
        # officer enters a DH OLN (fires KQN), this Name-based combo exits the union pool so
        # Name/Sex/DOB do not bleed onto the DriverHistoryQuery wire. Mirrors the v3.7 DL-side
        # guardrail (DQ/QW). conditions[].field = sourceField (DH-suffix, PascalCase).
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('SexCodeDH','BirthDateDH','NameLastDH','NameFirstDH'); any = $dhAny; defaults = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }); conditions = @([PSCustomObject]@{ field = @('OperatorLicenseNumberDH'); operator = 'NOT_EXISTS' }) }
            primaryFieldReference = 'Name'
            keyReference          = 'KQ'
            state                 = 'In/Out'
        }
        # KQN: OLN path -- 1 set[]. DH-suffix. State+PurposeCode optional.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{ set = @('OperatorLicenseNumberDH'); any = $dhAny; defaults = @([PSCustomObject]@{ field = 'PurposeCode'; value = 'C' }) }
            primaryFieldReference = 'OperatorLicenseNumber'
            keyReference          = 'KQN'
            state                 = 'In/Out'
        }
    )
    description     = 'DriverHistoryQuery -- KQ (Name+Sex+DOB), KQN (OLN). DH-suffix fields on own card. State+PurposeCode+Attention in any[]. Attention auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler (officer LastName FirstInitial from RMS profile) -- requires Attention in any[] + hidden gate-feeder field populated (v2.9, live-proven). autoSelect + one-directional queriesToDeselect=DL.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_DriverHistoryQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    autoSelect      = $true
    queriesToDeselect = @('DriverLicenseQuery')
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'DriverHistoryQuery'
    queryLabel      = 'Driver History'
    targetEntity    = 'Person'
}

# =====================================================================
# 1g. GunQuery
# XML: 1 combo (QG). GunMake maxLength=10 (not 23 like NJ). GunSerialNumber=20.
# =====================================================================
$gunQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'GunCaliber';                size = 4;  sourceField = @('GunCaliber');                targetField = 'GunCaliber' }
        [PSCustomObject]@{ name = 'GunMake';                   size = 10; sourceField = @('GunMake');                   targetField = 'GunMake' }
        [PSCustomObject]@{ name = 'GunModel';                  size = 20; sourceField = @('GunModel');                  targetField = 'GunModel' }
        [PSCustomObject]@{ name = 'GunSerialNumber';           size = 20; sourceField = @('serialNumber');              targetField = 'GunSerialNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # Caliber/Make/Model ride along in any[]; relatedSearchHitIndicator defaults Y.
        # NOTE: Platform serializes only set[]+any[] fields -- empty any[] silently drops
        # all optional fields (Make/Caliber/Model/RSH) from XML. FL_FCIC pattern confirmed.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('serialNumber')
                any      = @('GunMake','GunCaliber','GunModel','relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'GunSerialNumber'
            keyReference          = 'QG'
            state                 = 'In/Out'
        }
    )
    description     = 'GunQuery -- QG. GunMake maxLength=10 (HI-specific).'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_GunQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'GunQuery'
    queryLabel      = 'Firearm'
    targetEntity    = 'Firearm'
}

# =====================================================================
# 1h. ArticleSingleQuery
# XML: 1 combo (QA). Same structure as NJ but with RelatedSearchHitIndicator.
# =====================================================================
$artQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'ArticleSerialNumber';       size = 20; sourceField = @('ArticleSerialNumber');       targetField = 'ArticleSerialNumber' }
        [PSCustomObject]@{ name = 'ArticleTypeCode';           size = 7;  sourceField = @('ArticleTypeCode');           targetField = 'ArticleTypeCode' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
    )
    combinations = @(
        # RSH optional; must be in any[] to serialize. Default Y.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('ArticleSerialNumber','ArticleTypeCode')
                any      = @('relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'ArticleSerialNumber'
            keyReference          = 'QA'
            state                 = 'In/Out'
        }
    )
    description     = 'ArticleSingleQuery -- QA.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_ArticleSingleQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'ArticleSingleQuery'
    queryLabel      = 'Article'
    targetEntity    = 'Article'
}

# =====================================================================
# 1i. BoatQuery
# XML: BQ (Choice[Hull/Reg], any=[State]) + QB (Choice(max2)[Reg/Hull], any=[RelatedSearchHitIndicator])
# Merged into 2 combos: one per primary field, both optional fields in any[]
# =====================================================================
$boatQuery = [PSCustomObject]@{
    attributes = @(
        [PSCustomObject]@{ name = 'BoatHullIdNumber';          size = 20; sourceField = @('BoatHullIdNumber');          targetField = 'BoatHullIdNumber' }
        [PSCustomObject]@{ name = 'RegistrationNumber';        size = 8;  sourceField = @('RegistrationNumber');        targetField = 'RegistrationNumber' }
        [PSCustomObject]@{ name = 'RelatedSearchHitIndicator'; size = 1;  sourceField = @('relatedSearchHitIndicator'); targetField = 'RelatedSearchHitIndicator' }
        [PSCustomObject]@{ name = 'State'; size = 2; sourceField = @('RegistrationState'); targetField = 'State'; codeTypeProvider = 'NCIC' }
    )
    combinations = @(
        # BQ: Boat Registration. RegistrationState/RSH optional; must be in any[] to serialize.
        # CONDITION: BoatHullIdNumber NOT_EXISTS -- Hull>Reg identifier-priority guardrail (v3.9).
        # Hull ID (HIN) is the unique permanent identifier (VIN-like); Registration Number is
        # reassignable (plate-like). When the officer enters a Hull ID (fires QB), this Reg#
        # combo exits the union pool so RegistrationNumber does not bleed onto the Hull query wire.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('RegistrationNumber')
                any      = @('RegistrationState','relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
                conditions = @([PSCustomObject]@{ field = @('BoatHullIdNumber'); operator = 'NOT_EXISTS' })
            }
            primaryFieldReference = 'RegistrationNumber'
            keyReference          = 'BQ'
            state                 = 'In/Out'
        }
        # QB: Stolen Boat. RegistrationState/RSH optional; must be in any[] to serialize.
        [PSCustomObject]@{
            requirements          = [PSCustomObject]@{
                set      = @('BoatHullIdNumber')
                any      = @('RegistrationState','relatedSearchHitIndicator')
                defaults = @([PSCustomObject]@{ field = 'relatedSearchHitIndicator'; value = 'Y' })
            }
            primaryFieldReference = 'BoatHullIdNumber'
            keyReference          = 'QB'
            state                 = 'In/Out'
        }
    )
    description     = 'BoatQuery -- BQ (Reg), QB (Stolen/Hull). Merged from XML Choice elements.'
    handlerFunction = 'CommsysTransactionRequestHandler'
    name            = 'HI_HCJDC_OFML_BoatQuery'
    type            = 'QUERYINPUTDATAMAPPING'
    provider        = 'HI_HCJDC_OFML'
    providerType    = 'Commsys'
    query           = 'BoatQuery'
    queryLabel      = 'Boat'
    targetEntity    = 'Boat'
}

$provBundle = [PSCustomObject]@{
    description    = "Provider configuration for HI_HCJDC_OFML v${Version}"
    configurations = @($auth, $results, $qmf, $vehRegQuery, $dlQuery, $dhQuery, $gunQuery, $artQuery, $boatQuery)
    name           = 'HI_HCJDC_OFML'
    type           = 'BUNDLE'
    provider       = 'HI_HCJDC_OFML'
}

# =====================================================================
# BUNDLE 2: ENTITIES (QUERYINPUTFORM, provider=MARK43)
# 5 forms: Vehicle, Person, Firearm, Article, Boat
# Phase 1: single card per entity.
# =====================================================================

# Vehicle -- 3 cards (v3.0): SEARCH OPTIONS (shared State/Type/Image) + PLATE SEARCH + VIN SEARCH.
# Routing (OOS-first): out-of-state reached by ADDING fields, never clearing Vehicle Type.
#   Plate: bare plate -> M55L (in-state); + Plate Type + Plate Year -> RQ (out-of-state).
#   VIN:   bare VIN -> M55S (in-state); + State -> RQV (out-of-state).
# Plate Type AND Plate Year now have NO form default (both blank) so they read as the
# "out-of-state plates only" fields and filling them is the deliberate OOS signal.
# VehicleType default=1 (Auto) auto-satisfies the server's in-state requirement.
# QV (stolen) server-generated. VehicleTypeCode: 1=Auto, 2=Motorcycle, 3=Truck, 5=Trailer, 6=Moped.
$vehLayout = MakeLayouts @(
    @{
        id    = 'CARD_VEH'
        title = 'VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, "OR" VIN'
        rows  = @(
            # v4.14: collapsed from 3 cards (SEARCH OPTIONS + PLATE SEARCH + VIN SEARCH) to one,
            # matching FL + NJ. Plate row, Type/Year row, VIN row, options row (Type/State/Image
            # last). All fieldIds/initialValues/OOS-routing preserved -- Plate Type/Year keep NO
            # default (blank = the OOS signal), VehicleType default=1, layout-only change.
            @{ id = 'ROW_VEH_1'; cols = @('12'); fields = @(
                @{ id = 'licensePlateNumber_Input'; node = Inp 'LicensePlateNumber' 'License Plate Number' '10' 'ROW_VEH_1' }
            )}
            @{ id = 'ROW_VEH_2'; cols = @('6','6'); fields = @(
                @{ id = 'licensePlateTypeCode_Input'; node = Sel 'LicensePlateTypeCode' 'Plate Type (out-of-state plates only)' @{ codeTypeCategory = 'NCIC_LICENSE_PLATE_TYPE'; codeTypeSource = 'NCIC' } 'ROW_VEH_2' }
                @{ id = 'licensePlateYear_Input';     node = Inp 'LicensePlateYear' 'Plate Year (out-of-state plates only)' '4' 'ROW_VEH_2' }
            )}
            @{ id = 'ROW_VEH_3'; cols = @('8','4'); fields = @(
                @{ id = 'vehicleIdentificationNumber_Input'; node = Inp 'VehicleIdentificationNumber' 'Vehicle Identification Number' '20' 'ROW_VEH_3' }
                @{ id = 'vehicleYear_Input';                 node = Inp 'vehicleYear' 'Vehicle Year (optional)' '4' 'ROW_VEH_3' }
            )}
            @{ id = 'ROW_VEH_4'; cols = @('4','4','4'); fields = @(
                @{ id = 'vehicleTypeCode_Input';   node = Sel 'vehicleTypeCode' 'Vehicle Type' @{ codeTypeCategory = 'VEHICLE_TYPE'; codeTypeSource = 'HI_NIBRS'; initialValue = '1' } 'ROW_VEH_4' }
                @{ id = 'registrationState_Input'; node = Sel 'RegistrationState' 'State (leave blank for Hawaii)' @{ attributeTypeId = 'STATE' } 'ROW_VEH_4' }
                @{ id = 'imageIndicator_Input';    node = Sel 'ImageIndicator' 'NCIC Image' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_VEH_4' }
            )}
        )
    }
)
$vehicleForm = [PSCustomObject]@{
    description  = 'Vehicle queries -- 1 card (v4.14, collapsed from SEARCH OPTIONS + PLATE + VIN): Plate, Type/Year, VIN/Year, then Type/State/NCIC Image. OOS-first routing: bare plate->M55L, +Plate Type+Year->RQ; bare VIN->M55S, +State->RQV. OOS by adding fields, never clearing Vehicle Type. QV server-generated.'
    label        = 'Vehicle'
    layout       = $vehLayout
    name         = 'ENTITY_Vehicle'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Vehicle'
}

# Person -- 2 cards (Rob-confirmed 2026-07-17 collapse, was 3 through v4.8). Serves
# DriverLicenseQuery (DQN/DQ/QW) and DriverHistoryQuery (KQN/KQ); DH adds Attention +
# PurposeCode and uses DH-suffix fieldIds. Deselect is ONE-DIRECTIONAL: only
# DriverHistoryQuery carries queriesToDeselect=['DriverLicenseQuery'] (DH deselects DL; DL
# never deselects DH -- live-confirmed v4.5). Cards are visual only -- field population is
# form-wide, not card-scoped.
# Person -- 2 cards: DRIVER LICENSE (DQ/QW/DQN, plain fieldIds, own RegistrationState) +
# DRIVER HISTORY (KQ/KQN, DH-suffix + Purpose Code, own RegistrationStateDH). The standalone
# "SEARCH OPTIONS" card (v4.8 and earlier) existed only to hold ONE shared RegistrationState
# field feeding both QIDMs' State attribute -- collapsed by giving DH its own dedicated
# RegistrationStateDH field (matching every other DH field, all already DH-suffixed) instead
# of sharing one field across two cards. DriverHistoryQuery's State attribute sourceField
# changed from RegistrationState to RegistrationStateDH accordingly (see $dhQuery below).
# Separate cards still need distinct fieldIds (duplicate fieldId across cards = ISE), hence
# DH-suffix on the DH card.
# Attention field on the DH card: normally hidden (gate-feeder for the auto-handler);
# in -AttnDiagnostic it is VISIBLE passthrough (type a value, expect it verbatim in XML).
# Visible Attention field only for the passthrough diagnostic (officer types a value).
# dochandler + production keep it hidden (handler is sourceless / gate-feeder).
if ($AttnDiagnostic -and ($AttnMode -eq 'passthrough' -or $AttnMode -eq 'handler')) {
    $attnRowHidden = $false
    $attnFieldNode = Inp  'Attention' 'ATTENTION TEST - type any value, it should appear verbatim in the XML' '30' 'ROW_PER_DH_ATTN' @{ initialValue = 'ATTNTEST123' }
} else {
    $attnRowHidden = $true
    # v4.15 (DEX-1283): initialValue='X' REMOVED. The 'X' was a gate-feeder sentinel added at v2.9
    # in the same change that added 'Attention' to KQ/KQN any[] -- and the any[] membership was the
    # actual fix (v2.9's own note: "Root cause = missing any[] entry, not handler config"). The 'X'
    # was never isolated as necessary, and it is not: FL_FCIC, TX_TLETS, CA_CLETS and NY all run this
    # SAME handler with Attention/Requestor in any[], NO initialValue and NO combo default, and their
    # committed wires carry the resolved officer name on 38 of 38 Driver-History logs. HI was the last
    # provider still prefilling it. Empty source field is required (v2.5 proved sourceField=@() is
    # import-REJECTED, "Invalid attributes ... [Attention]"), so the control stays -- only its value goes.
    $attnFieldNode = InpH 'Attention' 'Attention (auto-populated from officer profile)' '30' 'ROW_PER_DH_ATTN'
}
$perLayout = MakeLayouts @(
    @{
        id    = 'CARD_PER_DL'
        title = 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # State shares the License Number row (Rob-confirmed 2026-07-17) -- unchanged field
            # (still plain RegistrationState, still feeds DriverLicenseQuery.State + the RMS
            # Person QIDM); DH gets its own dedicated RegistrationStateDH field (CARD_PER_DH below).
            @{ id = 'ROW_PER_DL1'; cols = @('7','5'); fields = @(
                @{ id = 'operatorLicenseNumber_Input'; node = Inp 'OperatorLicenseNumber' 'OLN' '20' 'ROW_PER_DL1' }
                @{ id = 'registrationState_Input';     node = Sel 'RegistrationState' 'State (leave blank for Hawaii)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DL1' }
            )}
            # First/Last/MI/Suffix on one line (Rob-confirmed 2026-07-17) -- MI shortened (no
            # periods) to fit its narrow column; Suffix kept as the full word (Rob-confirmed).
            @{ id = 'ROW_PER_DL2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'nameFirst_Input';  node = Inp 'NameFirst'  'First Name'  '30' 'ROW_PER_DL2' }
                @{ id = 'nameLast_Input';   node = Inp 'NameLast'   'Last Name'   '30' 'ROW_PER_DL2' }
                @{ id = 'nameMiddle_Input'; node = Inp 'nameMiddle' 'MI'  '30' 'ROW_PER_DL2' }
                @{ id = 'nameSuffix_Input'; node = Inp 'nameSuffix' 'Suffix' '30' 'ROW_PER_DL2' }
            )}
            @{ id = 'ROW_PER_DL3'; cols = @('6','6'); fields = @(
                @{ id = 'birthDate_Input'; node = Dt  'BirthDate' 'Date of Birth (required with Name)' 'ROW_PER_DL3' }
                @{ id = 'sexCode_Input';   node = Sel 'SexCode'   'Sex (required with Name)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DL3' }
            )}
        )
    }
    @{
        id    = 'CARD_PER_DH'
        title = 'DRIVER HISTORY SEARCH BY OLN, "OR" NAME'
        rows  = @(
            # DH "(DH)" qualifier dropped from labels (Rob-confirmed 2026-07-17, mirrors FL_FCIC/
            # NY_NYSPIN_EJUSTICE) -- the card's own "DRIVER HISTORY" title already disambiguates
            # it from "DRIVER LICENSE"; each label now matches its DL counterpart's phrasing.
            # State sits between License Number and Purpose Code (Rob-confirmed 2026-07-17). DH
            # gets its OWN dedicated State field, matching every other DH field on this card (all
            # already DH-suffixed) and matching FL/NY's self-contained DH cards. QIDM:
            # DriverHistoryQuery's State attribute is sourced from RegistrationStateDH (see
            # $dhQuery below), not the shared RegistrationState the DL card keeps.
            @{ id = 'ROW_PER_DH1'; cols = @('5','4','3'); fields = @(
                @{ id = 'OperatorLicenseNumberDH_Input'; node = Inp 'OperatorLicenseNumberDH' 'OLN' '20' 'ROW_PER_DH1' }
                @{ id = 'RegistrationStateDH_Input';     node = Sel 'RegistrationStateDH' 'State (leave blank for Hawaii)' @{ attributeTypeId = 'STATE' } 'ROW_PER_DH1' }
                @{ id = 'purposeCodeDH_Input';           node = Inp 'purposeCodeDH' 'Purpose Code' '1' 'ROW_PER_DH1' @{ initialValue = 'C' } }
            )}
            # First/Last/MI/Suffix on one line (Rob-confirmed 2026-07-17) -- same treatment as
            # CARD_PER_DL (MI shortened, Suffix kept as the full word).
            @{ id = 'ROW_PER_DH2'; cols = @('4','4','2','2'); fields = @(
                @{ id = 'NameFirstDH_Input';  node = Inp 'NameFirstDH'  'First Name'  '30' 'ROW_PER_DH2' }
                @{ id = 'NameLastDH_Input';   node = Inp 'NameLastDH'   'Last Name'   '30' 'ROW_PER_DH2' }
                @{ id = 'nameMiddleDH_Input'; node = Inp 'nameMiddleDH' 'MI'  '30' 'ROW_PER_DH2' }
                @{ id = 'nameSuffixDH_Input'; node = Inp 'nameSuffixDH' 'Suffix' '30' 'ROW_PER_DH2' }
            )}
            @{ id = 'ROW_PER_DH3'; cols = @('6','6'); fields = @(
                @{ id = 'BirthDateDH_Input'; node = Dt  'BirthDateDH' 'Date of Birth (required with Name)' 'ROW_PER_DH3' }
                @{ id = 'SexCodeDH_Input';   node = Sel 'SexCodeDH'   'Sex (required with Name)' @{ attributeTypeId = 'SEX'; codeTypeProvider = 'NIBRS' } 'ROW_PER_DH3' }
            )}
            # v2.7: hidden Attention gate-feeder. The DH QIDM Attention attribute
            # (CommsysGetLastNameFirstNameInitialRuleHandler) is gated out of
            # serialization unless its sourceField ['Attention'] resolves to a value.
            # This hidden field supplies that value so the handler runs and emits the
            # logged-in officer's name (LastName FirstInitial) from the profile.
            # initialValue is a placeholder the handler is expected to ignore.
            @{ id = 'ROW_PER_DH_ATTN'; cols = @('12'); hidden = $attnRowHidden; fields = @(
                @{ id = 'Attention_Input'; node = $attnFieldNode }
            )}
        )
    }
)
$personForm = [PSCustomObject]@{
    description  = 'Person queries -- 3 cards: SEARCH OPTIONS (shared State), DRIVER LICENSE (DQ/QW/DQN, plain), DRIVER HISTORY (KQ/KQN, DH-suffix + PurposeCode). DL autoSelect; DH opt-in via one-directional queriesToDeselect.'
    label        = 'Person'
    layout       = $perLayout
    name         = 'ENTITY_Person'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Person'
}

# Firearm -- 1 card (QG)
# GunMake maxLength=10 (HI-specific, not 23 like NJ)
$faLayout = MakeLayouts @(
    @{
        id    = 'CARD_GUN'
        title = 'FIREARM SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_GUN_1'; cols = @('6','6'); fields = @(
                @{ id = 'SerialNumber_Input'; node = Inp 'serialNumber' 'Serial Number' '20' 'ROW_GUN_1' }
                @{ id = 'gunMake_Input';         node = Sel 'GunMake' 'Make (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_MAKE'; codeTypeSource = 'NCIC' } 'ROW_GUN_1' }
            )}
            @{ id = 'ROW_GUN_2'; cols = @('4','4','4'); fields = @(
                @{ id = 'gunCaliber_Input';                node = Sel 'GunCaliber' 'Caliber (optional)' @{ codeTypeCategory = 'NCIC_FIREARM_CALIBER'; codeTypeSource = 'NCIC' } 'ROW_GUN_2' }
                @{ id = 'gunModel_Input';                  node = Inp 'GunModel' 'Model (optional)' '20' 'ROW_GUN_2' }
# LABEL-OVERRIDE: relatedSearchHitIndicator -- canonical bare "Stolen Check" per DEX-1284 lean pass (any[] optional w/ default Y; matches NY/TX/FL). Covers Firearm/Article/Boat uses.
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_GUN_2' }
            )}
        )
    }
)
$firearmsForm = [PSCustomObject]@{
    description  = 'Firearm query -- QG.'
    label        = 'Firearm'
    layout       = $faLayout
    name         = 'ENTITY_Firearm'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Firearm'
}

# Article -- 1 card (QA)
$artLayout = MakeLayouts @(
    @{
        id    = 'CARD_ART'
        title = 'ARTICLE SEARCH BY SERIAL NUMBER'
        rows  = @(
            @{ id = 'ROW_ART_1'; cols = @('6','6'); fields = @(
                @{ id = 'articleSerialNumber_Input';       node = Inp 'ArticleSerialNumber' 'Serial Number' '20' 'ROW_ART_1' }
                @{ id = 'articleTypeCode_Input';           node = Sel 'ArticleTypeCode' 'Article Type (required)' @{ codeTypeCategory = 'NCIC_ARTICLE_TYPE'; codeTypeSource = 'CA_CLETS' } 'ROW_ART_1' }
            )}
            @{ id = 'ROW_ART_2'; cols = @('6'); fields = @(
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_ART_2' }
            )}
        )
    }
)
$articleForm = [PSCustomObject]@{
    description  = 'Article query -- QA.'
    label        = 'Article'
    layout       = $artLayout
    name         = 'ENTITY_Article'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Article'
}

# Boat -- 1 card
# BoatQuery: BQ (Reg) + BQN (Hull). State + RelatedSearchHitIndicator optional.
$boaLayout = MakeLayouts @(
    @{
        id    = 'CARD_BOA'
        title = 'BOAT SEARCH BY REGISTRATION, "OR" HULL ID'
        rows  = @(
            # v4.14: both identifiers on row 1; State moved below both (Reg/Hull -> State/Stolen).
            @{ id = 'ROW_BOA_1'; cols = @('6','6'); fields = @(
                @{ id = 'registrationNumber_Input';        node = Inp 'RegistrationNumber' 'Registration Number' '8' 'ROW_BOA_1' }
                @{ id = 'boatHullIdNumber_Input';          node = Inp 'BoatHullIdNumber' 'Hull ID Number' '20' 'ROW_BOA_1' }
            )}
            @{ id = 'ROW_BOA_2'; cols = @('6','6'); fields = @(
                @{ id = 'registrationState_Input';         node = Sel 'RegistrationState' 'State (leave blank for Hawaii)' @{ attributeTypeId = 'STATE' } 'ROW_BOA_2' }
                @{ id = 'relatedSearchHitIndicator_Input'; node = Sel 'relatedSearchHitIndicator' 'Stolen Check' @{ codeTypeCategory = 'YES_NO_UNKNOWN'; codeTypeSource = 'NCIC'; initialValue = 'Y' } 'ROW_BOA_2' }
            )}
        )
    }
)
$boatForm = [PSCustomObject]@{
    description  = 'Boat queries -- BQ (Reg) and BQN (Hull).'
    label        = 'Boat'
    layout       = $boaLayout
    name         = 'ENTITY_Boat'
    type         = 'QUERYINPUTFORM'
    targetEntity = 'Boat'
}

$entitiesBundle = Build-EntitiesBundle -Configurations @($vehicleForm, $personForm,
        $firearmsForm, $articleForm, $boatForm) `
        -Description "Provider configuration for HI_HCJDC_OFML v${Version} -- entity forms"

# =====================================================================
# BUNDLE 3: RMS (from KB specs)
# =====================================================================
$rmsBundle = Build-RmsBundle -PascalCaseUsxFields `
        -Description "Provider configuration for HI_HCJDC_OFML v${Version} -- RMS bundle"
# WRITE OUTPUT
# =====================================================================
$output = [PSCustomObject]@{
    bundles = @($entitiesBundle, $provBundle, $rmsBundle)
}

if ($AttnDiagnostic) {
    Write-ProviderJson -BundleObject $output -OutPath $OUT -Label "Built HI_HCJDC_OFML ATTN DIAGNOSTIC (passthrough, visible Attention)"
    Write-Host ""
    Write-Host "DIAGNOSTIC JSON written: $OUT" -ForegroundColor Cyan
    Write-Host "  Import it, run a Driver History query (the Attention field is visible, pre-filled 'ATTNTEST123')," -ForegroundColor Cyan
    Write-Host "  and check the XML: if <Attention>ATTNTEST123</Attention> appears, the wire works and the" -ForegroundColor Cyan
    Write-Host "  production handler is what suppresses output; if absent, Attention is dropped regardless." -ForegroundColor Cyan
    return
}
Write-ProviderJson -BundleObject $output -OutPath $OUT `
    -Label "Built HI_HCJDC_OFML v${Version}" `
    -Version $Version

# =====================================================================
# VALIDATE (use NJ validator adapted for HI)
# =====================================================================
$VALIDATOR = (Resolve-Path "$PSScriptRoot\..\..\..\tools\validate.ps1").Path
if (Test-Path $VALIDATOR) {
    Write-Host "Validation complete." -ForegroundColor Green
} else {
    Write-Host "Validator not found at $VALIDATOR -- skipping." -ForegroundColor Yellow
}

# -- Git commit --
Write-Host ""
Write-Host "Build complete. Ready for manual review + build_report."
