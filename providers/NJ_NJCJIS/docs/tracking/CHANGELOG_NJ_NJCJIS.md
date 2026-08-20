# NJ_NJCJIS -- Changelog

Auto-generated from `NJ_NJCJIS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.17** | Generated: 2026-08-20

---

## v4.17 -- 2026-08-20 -- Middle name + Suffix -- the officer could not enter two components NJ's own metadata defines

**CHANGED:**
  - ROW_PER_2 [3,3,3,3] = First Name | MIDDLE NAME | Last Name | SUFFIX (was First | Last at [6,6]).  
  - DriverLicenseQuery Name composite: sourceField @('NameLast','NameFirst') ->  
    @('NameLast','NameFirst','NameMiddle','NameSuffix').  
  - AP #15: FormatStringRuleHandler arguments @(', ') -> @(', ', ' ', ' ') -- separators must equal  
    (sourceFields - 1) or the build hard-fails.  
**REASON:** audit_name_components reported 2 C1 NO-CONTROL findings. VERIFIED IN NJ'S OWN RAW XML (the
  sanctioned exception): the Name field declares `Name :: First + Last + Middle + Suffix` and  
  DriverLicenseQuery references it. So the provider accepts four components, the form offered two,  
  and the wire could only ever carry `DOE, JOHN`. Capability is WIRE-PROVEN elsewhere, not  
  theoretical: AZ_AZDPS v3.11 emitted `DOE, JOHN A JR` across 10 captures and TX_TLETS v4.21 proved  
  it again, both degrading with no double space when a component is blank.  
SCOPE: ONE name pool, Person only. NJ has no DriverHistory card, and a first count of "3 NameFirst  
  controls" was the SAME fieldId across the three layout variants (default/CAD_DISPATCH/  
  FIRST_RESPONDER), not three pools -- checked before proposing, because the cost here is real.  
NO layout work: NJ is the portfolio's cleanest provider on that axis, audit_layout_flow 0 findings.  

## v4.16 -- 2026-08-14 -- NCIC Image defaults to 'Y' on Vehicle/Firearm/Article/Boat (WIRE CHANGE)

**CHANGED:** ImageIndicator initialValue 'N' -> 'Y' on the four entities that were still 'N', in BOTH
  halves of the default: the form FormSelect initialValue (Vehicle ROW_VEH_3, Firearm ROW_GUN_2,  
  Article ROW_ART_1, Boat ROW_BOA_1 -- 4 authored sites, x3 layout variants = 12 emitted controls)  
  AND the combo defaults[] twin on all 6 carrying combinations (RANDFULL, RANDFULLN, QG, QA, QB,  
  QBN). Person (FULL/FULLN) was already 'Y' and is untouched. Takes  
  [FLAG:ncic-image-default-y-everywhere].  
**REASON:** Rob 2026-08-12, "ncic image should default to y everywhere". BOTH HALVES ARE REQUIRED --
  CAD ignores form initialValue entirely, so a form-only flip would leave CAD-originated queries  
  still sending 'N' while officer-driven ones sent 'Y'. That split is the same class as the  
  original BadgeNumber defect.  
THIS IS A WIRE CHANGE, NOT COSMETIC. ImageIndicator rides in any[] on all 6 combos, so the value IS  
  transmitted; N->Y changes what NCIC is asked for. Hence the version bump and the full re-sweep of  
  all 40 logs. What it buys is response-side: with 'N' NCIC returns no image, so an officer got a  
  hit with no photo and nothing errored -- a silent under-ask, invisible to every request-side gate.  
MEASURED SAFE BEFORE FLIPPING, not assumed:  
  * ImageIndicator is in ZERO set[]s and ZERO conditions on NJ (counted from the emitted v4.15  
    JSON). So no prefill can shadow a combination (BUILD_RULES 24) and there is no  
    NOT_EXISTS-gated branch to kill (BUILD_RULES 20b). Contrast AZ_AZDPS, where the same flip is  
    RULED OUT because ImageIndicator sits in 2 set[]s and 'Y' kills DQN + DQP.  
  * TX_TLETS T6 gate clear: NJ's devdoc carries NO "must be filled if ImageIndicator = Y"  
    conditional wording anywhere (grepped). TX/TX_CCH DO carry one, but it is scoped to  
    DriverHistoryQuery -- a query this change does not touch on any provider.  
  * All 6 combos already carried a defaults[] entry for the field, so this edits values and adds  
    no new keys.  
A COLLISION I NEARLY CAUSED AND CAUGHT BY CHECKING FIRST -- worth reading before the next provider  
  takes this flag. RandomRequest ALSO uses initialValue = 'N' (line 476) and value = 'N' (lines 187,  
  203) in this very script, so a replace-all on "initialValue = 'N'" or "value = 'N'" would have  
  flipped RandomRequest to 'Y' as well. NJ's own field label spells out the consequence: "Random  
  Request (N = full record; Y = random)" -- i.e. it would have silently downgraded every vehicle  
  query from a full record to a random one. Every pattern used here is anchored on the fieldId  
  ("field = 'ImageIndicator'", "Sel 'ImageIndicator' 'NCIC Image'"), and RandomRequest was  
  re-verified at 'N' on all 3 sites afterwards.  

## v4.14 -- 2026-07-30 -- Layout review -- Vehicle 1-card collapse + Boat title (direct Rob feedback, NO functional change)

**CHANGED:** Two changes from the NJ v4.13 rendered-form review (mirrors the FL v7.11/v7.12 pass):
  (1) Vehicle collapsed from 3 cards (SEARCH OPTIONS + PLATE SEARCH + VIN SEARCH) to ONE  
    "VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, \"OR\" VIN" card -- Row 1 Plate/Type/Year,  
    Row 2 VIN, Row 3 shared options State/Random Request/NCIC Image (matches FL's collapsed  
    Vehicle + NJ's own v4.12 Person consolidation).  
  (2) Boat card title "BOAT SEARCH" -> "BOAT SEARCH BY REGISTRATION NUMBER, \"OR\" HULL ID"  
    (Boat has 2 identifier paths; HI/NY Reg-first convention + NJ's Reg-first field order).  
**REASON:** Rob's layout review before the NJ tenant sweep. QIDM/combos/routing/fieldIds/defaults all
  unchanged -- both VehReg combos (RANDFULL/RANDFULLN) read the same fieldIds. Layout/title-only.  
  ALL 5 ENTITIES RESET for re-test at v4.14 (block by version).  

## v4.13 -- 2026-07-27 -- UPPERCASE card titles (Rob global decision, NO functional change)

**CHANGED:** All card titles UPPERCASED, wording unchanged (e.g. "Driver License Search by OLN,
  \"OR\" Name" -> all-caps; "Search Options" -> "SEARCH OPTIONS"; Firearm/Article/Boat already  
  uppercase). Mechanical uppercase transform; no wording/field/combo/QIDM change. New global  
  convention (BUILD_RULES Section 11).  
**REASON:** Rob -- "everything needs to be upper case." Title-only. verify_build clean. ALL 5
  ENTITIES RESET at v4.13 (block by version). NOT yet re-tested.  

## v4.12 -- 2026-07-27 -- DEX-1284 Person consolidation (direct Rob feedback, layout-only, NO functional change)

**CHANGED:** Collapsed the 3-card Person split (SEARCH OPTIONS + LICENSE NUMBER + NAME SEARCH) into
  ONE "Driver License Search by OLN, \"OR\" Name" card, matching NY/TX/FL. Layout:  
    ROW_PER_1 (6/3/3): OLN | State | NCIC Image   (Rob-confirmed FL top-row model)  
    ROW_PER_2 (6/6):   First Name | Last Name  
    ROW_PER_3 (6/6):   Date of Birth | Sex  
  The DriverLicense QIDM (FULL=OLN / FULLN=Name combos) is unchanged -- both combos read from the  
  single card now. State keeps initialValue=NJ + its RegistrationState LABEL-OVERRIDE. Vehicle  
  keeps its own OPTIONS card (only Person consolidated). Supersedes the v4.11 note that deferred  
  this consolidation to Rob.  
**REASON:** Rob -- "consolidate the nj person down." Brings NJ's Person in line with the consolidated
  single-DL-card pattern on NY/TX/FL. Layout-only, no combo/QIDM/routing/fieldId/default change.  
  verify_build 15P/0W/0F. ALL 5 ENTITIES RESET for re-test at v4.12 (block by version). NOT yet  
  re-tested.  

## v4.11 -- 2026-07-27 -- DEX-1284 relabel/naming-convention pass (direct Rob feedback, NO functional change)

**CHANGED:** Applied the NY/TX/FL portfolio conventions:
  - OLN: OperatorLicenseNumber DL "License Number (or search by Name + DOB)" -> "OLN"  
  - canonical bare "NCIC Image" on every image field (Vehicle OPTIONS, Person OPTIONS, Gun,  
    Article, Boat) -- was "Image (optional)"  
  NJ has no Driver History card and no relatedHitSearchIndicator/stolen toggle  
  (VehicleStolenQuery is a user-approved skip), so "Stolen Check" does not apply. Person keeps  
  its existing 3-card structure (SEARCH OPTIONS / LICENSE NUMBER / NAME SEARCH) -- the OLN field  
  already sits alone on its own full-width card (CARD_PER_OLN), so no DL top-row restructure was  
  needed; whether to consolidate OLN+Name onto one "Driver License" card (as on NY/TX/FL) is  
  deferred to Rob.  
**REASON:** DEX-1284 portfolio relabel. NJ's v4.9 relabel predated the OLN/NCIC-Image conventions
  (those landed on NY v4.11+). Label-only, no combo/QIDM/routing/fieldId/default change.  
  verify_build 15P/0W/0F. ALL 5 ENTITIES RESET for re-test at v4.11 (block by version). NOT yet  
  re-tested.  

## v4.10 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.9 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.8 -- 2026-07-01 -- Metadata-driven keyRef rename (DQ/DQN/RQ/RQN did not exist in devdoc)

**CHANGED:** DriverLicenseQuery DQ->FULL, DQN->FULLN (devdoc keyReference is 'FULL' for both
  combos, confirmed in source/NJ_NJCJIS.xml). VehicleRegistrationQuery RQ->RANDFULL,  
  RQN->RANDFULLN (devdoc defines 4 combos under keyReference 'RAND' and 'FULL', each  
  identical Set/Any per identifier -- one merged physical combo per identifier required;  
  compound name reflects both devdoc terms it serves). NJ build script only.  
**REASON:** user audit -- 'DQ'/'DQN'/'RQ'/'RQN' do not exist anywhere in NJ's devdoc; they were
  a cross-provider <Entity>Q/<Entity>QN naming habit carried over from another provider's  
  build script, not derived from this provider's own metadata. Version bump invalidates  
  all prior test evidence under the old keyRef names; full re-test from T1 required.  

## v4.7 -- 2026-06-26 -- VehicleMakeName code source corrected (RND-62365)

**CHANGED:** VehicleMakeName result-mapping code source corrected VEHICLE/VehicleType ->
  attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present on the  
  Newark instance; matches RND-54190 runbook + sibling VehicleModelName). Shared module  
  tools/_build_rms_bundle.ps1; NJ rebuilt only (other 4 live providers tabled).  
**REASON:** v4.6's VehicleType/VEHICLE pairing is absent on the Newark instance, breaking vehicle
  queries (Newark vehicle "Mock results processed"). Re-import + full re-test from T1 required.  

## v4.6 -- 2026-06-25 -- Remove top-level version field (platform Integer validation)

**CHANGED:** Removed "version" field from JSON output (Write-ProviderJson); platform now
  deserializes this as java.lang.Integer and rejects dotted string format ("4.5").  
  Version tracked in bundle description and all docs; enforce reads from description regex.  
**CHANGED** (in-place, same v4.6): dropped the " MC" suffix from the PROVIDER bundle
  description; stamped "Provider configuration for NJ_NJCJIS v4.6" into ALL 3 bundle  
  descriptions (ENTITIES/PROVIDER/RMS) and moved `description` to the first field of each  
  bundle for near-the-top visibility. Build-EntitiesBundle/Build-RmsBundle gained an  
  optional -Description param. Metadata-only -- no QIF/QIDM/query change; entity  
  fingerprints unchanged, so the 5 confirmed entities (T1-T29) carry over.  
**REASON:** Platform update tightened version field validation; import failed post-platform-deploy.

## v4.5 -- 2026-06-24 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.4 -- 2026-06-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.3 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.2 -- 2026-06-18 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.1 -- 2026-06-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.0 -- 2026-06-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.5-PASCAL -- 2026-06-11 -- TESTING-ONLY PascalCase variant (NJ_NJCJIS_PASCAL.json)

**CHANGED**
  - Generated FROM mainline v3.5 by new standalone scripts/build_nj_njcjis_pascal.ps1  
    (transform of the built JSON; ZERO changes to mainline build script or shared tools)  
  - Form-side layer recased camelCase -> PascalCase: all 22 QIF fieldIds, CommSys +  
    RMS QIDM sourceFields, combo set[]/any[] (ncicNumber -> NCICNumber special case)  
  - UNCHANGED: QIDM attribute names/targetFields (NJCJIS XML identical), defaults[].field,  
    conditions, keyReferences, AUTH, CAD context tokens, RMS elastic API keys  
**REASON**
  - Platform naming convention now PascalCase for all form params (eng analysis).  
    OnScene (Forge) attribute params were silently ignored against camelCase config  
    keys -- the original Newark OnScene issue. CAD data payloads confirmed PascalCase  
    on USx tenant (P2/P3 inbound captures): CAD + OnScene agree, no dual-casing needed.  
  - Live: P1 typed PASS, P3 CAD-with-state PASS, P2 known condition (State default  
    not surviving codeTypeProvider when CAD state blank -- accepted), P4 union-  
    serialization semantics proof. Imported USx + Newark Foundation 2026-06-11.  
  - HISTORY NOTE: prior camelCase was DELIBERATE Patch 8 alignment to the CAD contract  
    as stated 2026-05-05 ("CAD emits camelCase, case-sensitive"); the platform  
    convention inverted -- this is a contract change, not a config mistake.  
    Portfolio migration (19 providers + tooling) EARMARKED, one provider at a time.  

## v3.5 -- 2026-06-09 -- Name Search card layout — 2 rows

**CHANGED**
  - Split CARD_PER_NAME from 1 row (First/Last/DOB/Sex) to 2 rows:  
    ROW_PER_N1: First Name (6), Last Name (6)  
    ROW_PER_N2: Date of Birth (6), Sex (6)  
**REASON**
  - Usability: 4 fields on one row too cramped; DOB+Sex belong on separate line  

## v3.4 -- 2026-05-21 -- Single-JSON merge + State defaults

**CHANGED**
  - Merged BASE/MC into single build: build_nj_njcjis.ps1 → NJ_NJCJIS.json (no suffix)  
  - Added State='NJ' to defaults[] on 6 combos (RQ_RAND, RQ, RQN_RAND, RQN, QVP, DQ)  
  - Reports now in docs/ (not docs/mc/)  
  - Deleted old BASE build script  
**REASON**
  - BASE/MC split doubled maintenance with no benefit; single-JSON is the standard  
  - State defaults required for CAD dispatch (CommSys priority over RMS 400 bug)  

## v3.3 -- 2026-05-19 -- Combination-level defaults for CAD dispatch

**CHANGED**
  - Added defaults[] to ALL 13 CommSys combos across 6 QIDMs  
  - VehicleRegistrationQuery: RandomRequest=N, ImageIndicator=N, LicensePlateTypeCode=PC, LicensePlateYear=2026 on RQ/RQN; ImageIndicator=N + plate defaults on RQ_RAND/RQN_RAND  
  - VehicleStolenQuery: ImageIndicator=N on QVN/QVP/QVV  
  - DriverLicenseQuery: ImageIndicator=Y on DQ/DQN  
  - GunQuery: ImageIndicator=N on QG  
  - ArticleSingleQuery: ImageIndicator=N on QA  
  - BoatQuery: ImageIndicator=N on QB/QBN  
  - Same defaults on both BASE and MC  
**REASON**
  - CAD dispatch does NOT apply QIF form initialValues  
  - Without combo defaults[], CAD-dispatched XML omits defaulted fields entirely  
  - Caught by NJ CAD XML analysis: VIN query had only VIN+State, missing RandomRequest/ImageIndicator  
  - New BUILD_RULES.txt Section 12 and audit_cad.ps1 CHECK 6 codify this as build-time gate  

## v3.2 -- 2026-05-18 -- CAD-compatible rebuild -- conditions routing for RandomRequest

**CHANGED**
  - RandomRequest moved from set[] to any[] on all VehicleRegistrationQuery combos (RQ, RQN, RQ_RAND, RQN_RAND)  
  - Added conditions routing: RQ_RAND/RQN_RAND require RandomRequest EQUALS Y, RQ/RQN have no conditions (fallback)  
  - CAD dispatch now falls through to RQ/RQN when RandomRequest is absent  
  - Same fix applied to both BASE and MC variants  
**REASON**
  - CAD dispatch does not send RandomRequest (not in CAD field list)  
  - v3.1 had RandomRequest in set[] (per metadata) -- no combo matched from CAD, VehReg never fired  
  - Conditions routing lets form users still hit RAND combos (RandomRequest=Y) while CAD falls through  

## v3.1 -- 2026-05-11 -- DL combo reorder + validator path fix -- UNTESTED

**CHANGED**
  - DL combos reordered: Name (3 set fields) before OLN (2 set fields) -- most-specific first  
  - Build script updated to use shared tools/validate.ps1 (was referencing non-existent local validator)  
  - MC also rebuilt with same combo reorder  
**REASON**
  - Combo ordering rule: most-specific combination must be first (LIMITATION #3)  
  - Previous order had OLN (2 set) before Name (3 set), violating standard  
**RESULT**
  - 69P/0F/0W/0LIM (BASE and MC)  
  - NOT YET TESTED -- needs live DL test before replacing v3.0 at Newark  

## v3.0 -- 2026-05-08 -- Locked for Newark import

**CHANGED**
  - Folder renamed to NJ_NJCJIS_LOCKED  
  - Lock gates added to build scripts and validator (require -Force to rebuild)  
  - Imported to Newark Foundation Tenant 2026-05-11  
**REASON**
  - v2.9 passed 16/16 live tests; v3.0 is the same JSON with lock protection  
**RESULT**
  - Imported Newark Foundation Tenant 2026-05-11  

## v2.9 -- 2026-05-08 -- PlateYear dynamic + PlateType default + WARNs eliminated

**CHANGED**
  - PlateYear: dynamic $currentYear via build script (was hardcoded 2026)  
  - PlateType: initialValue='PC' default added  
  - All validator WARNs eliminated (0F/0W)  
  - Rebuilt with current monorepo toolchain  
**REASON**
  - Cross-provider standardization: PlateYear/PlateType defaults mandatory on all providers  

## v2.9 -- 2026-05-08 -- *** LOCKED -- READY FOR LIVE TEST ***

**CHANGED**
  - VehReg: autoSelect=true, NO queriesToDeselect (default query)  
  - VehStolen: NO autoSelect, queriesToDeselect=[VehicleRegistrationQuery] (opt-in)  
  - Same config as v2.7 but with confirmed working autoSelect/deselect behavior  
**REASON**
  - v2.8 bidirectional queriesToDeselect deadlocked (same as v2.3)  
  - User requested simplest approach: VehReg default, Stolen manual opt-in  
**RESULT**
  - LIVE TEST: 16/16 PASS (T2-T17, 2026-05-08)  
  - All 11 combos + OOS + any[] fields + negative confirmed  

## v2.8 -- 2026-05-08 -- FAILED -- bidirectional queriesToDeselect deadlock

**CHANGED**
  - Both QIDMs have queriesToDeselect pointing at each other  
  - VehReg: autoSelect=true, queriesToDeselect=[VehicleStolenQuery]  
  - VehStolen: NO autoSelect, queriesToDeselect=[VehicleRegistrationQuery]  
**REASON**
  - Attempted to prevent manual co-selection from v2.7  
**RESULT**
  - "original 2 error pop up" -- same deadlock as v2.3  

## v2.7 -- 2026-05-08 -- PARTIAL -- warning + manual co-selection allowed

**CHANGED**
  - Reordered QIDMs: VehStolen before VehReg in configurations array  
**REASON**
  - v2.6 had VehStolen auto-selecting because evaluated last in JSON order  
**RESULT**
  - VehReg auto-selects correctly on plate entry  
  - Warning "You cannot run Vehicle Stolen with Vehicle Registration" appears (cosmetic)  
  - Both checkboxes can be manually co-checked (queriesToDeselect one-directional on manual click)  

## v2.6 -- 2026-05-08 -- PARTIAL -- Stolen still auto-selects (ordering issue)

**CHANGED**
  - Moved defaulted fields from set[] to any[] on VehReg combos  
  - RQ: randomRequest, registrationState, licensePlateTypeCode -> any[]  
  - RQN: randomRequest, registrationState -> any[]  
**REASON**
  - LIMITATION #31: initialValue not counted for set[] by platform combo evaluator  
**RESULT**
  - Both QIDMs have autoSelect=true, last in JSON order wins (VehStolen after VehReg)  
  - "are you doing it backwards?" -- Stolen auto-selects, not Reg  

## v2.5 -- 2026-05-08 -- FAILED -- only Stolen auto-selects

**CHANGED**
  - Added autoSelect=true to VehStolen (both QIDMs now have autoSelect)  
**REASON**
  - v2.4 had simpler QVP combo (1 set field) stealing auto-select from RQ (4 set fields)  
**RESULT**
  - Discovered LIMITATION #31: initialValue fields not counted for set[]  
  - VehReg RQ had 3 defaulted fields in set[] that platform ignored  

## v2.4 -- 2026-05-08 -- FAILED -- VehStolen lights up first on plate entry

**CHANGED**
  - VehReg: queriesToDeselect=[VehicleStolenQuery]  
  - VehStolen: no queriesToDeselect  
  - Initial attempt at dual Vehicle QIDM with one-way deselect  
**REASON**
  - New VehicleStolenQuery shares Vehicle form; needs checkbox routing  
**RESULT**
  - QVP combo (set=[licensePlateNumber]) simpler than RQ, fires first  
  - "vehicle stolen lights up first when i enter a plate"  

## v2.3 -- 2026-05-07 -- Monorepo rebuild with latest tools

**CHANGED**
  - Rebuilt with current validate.ps1/build_report.ps1 toolchain  
  - Reports regenerated at docs/base/ and docs/mc/  
**REASON**
  - Standardization after monorepo migration  
**RESULT**
  - BASE: 67 PASS / 0 FAIL / 5 WARN / 1 LIMITATION  
  - MC:   67 PASS / 0 FAIL / 0 WARN / 1 LIMITATION  

## v2.2 -- 2026-05-05 -- camelCase fieldId rename (BASE only)

**CHANGED**
  - All BASE fieldIds converted to camelCase for CAD auto-populate  
  - 7 WARNs introduced (validator checks PascalCase names)  
  - MC retains PascalCase and has 0 WARN  
**REASON**
  - CAD field name alignment (project_cad_field_alignment memory)  

## v2.1 -- 2026-05-05 -- Patch 7 + Patch 8 + AUTH keyRef

**CHANGED**
  - RMS QIDMs: autoSelect=true (Patch 7)  
  - LicensePlateNumberIn -> licensePlateNumber (Patch 8, BASE)  
  - AUTH combination: keyReference='AUTH' added  
**REASON**
  - Cross-provider standardization from monorepo audit  

## v2.0 -- 2026-04-28 -- Full rebuild from new 2026-04-28 XML metadata

**CHANGED**
  - New VehicleStolenQuery (3 combos: QVN/QVP/QVV)  
  - RandomRequest mandatory on VehicleRegistrationQuery (default N)  
  - ImageIndicator on all 6 transactions  
  - GunModel added to GunQuery  
  - State removed from BoatQuery, RegistrationNumber maxLength 8->20  
  - All keyRefs reinvented (LIMITATION #21)  
  - Patch 1+3+6 applied to RMS  
**REASON**
  - New XML metadata (2026-04-28) adds VehicleStolenQuery, RandomRequest, ImageIndicator  
**RESULT**
  - 66 PASS / 0 FAIL / 7 WARN / 2 LIMITATION (BASE)  
  - 66 PASS / 0 FAIL / 0 WARN / 2 LIMITATION (MC)  
LIVE TEST  
  - BASE: 17/17 PASS (2026-04-29)  
  - MC:   57/57 PASS (2026-04-29)  

## v2.0-mc -- 2026-04-28 -- MC variant of v2.0 BASE

**CHANGED**
  - Multi-card layout: Vehicle (OPTIONS+PLATE+VIN), Person (OPTIONS+LICENSE+NAME)  
  - Firearm, Article, Boat single-card (same as BASE)  
  - QIDMs identical to BASE (6 QIDMs, 11 combos)  
  - RMS identical to BASE (HIDLE + Patch 1+3+6)  
**REASON**
  - Standard MC variant per build methodology  

## v4.15 -- 2026-08-02 -- Boat hull over-fill now carries RegistrationNumber (devdoc-order ruling)

**CHANGED:** QBN any[] += RegistrationNumber.
**REASON:** devdoc BoatQuery #1 is 'BoatHullIdNumber [ImageIndicator, RegistrationNumber]'. Hull is
listed FIRST, so it wins the over-fill -- devdoc listing order is the TIEBREAKER when two  
equally-specific single-identifier queries could both execute (Rob 2026-07-31). And the winning  
combination is explicitly allowed to carry the reg number as an optional, so it must ride in  
any[]. Before this, filling hull + reg number fired QBN and SILENTLY DROPPED the reg number.  
