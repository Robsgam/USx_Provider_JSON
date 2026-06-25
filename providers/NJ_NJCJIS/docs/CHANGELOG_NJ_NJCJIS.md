# NJ_NJCJIS -- Changelog

Auto-generated from `NJ_NJCJIS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.6** | Generated: 2026-06-25

---

## v4.6 -- 2026-06-25 -- Remove top-level version field (platform Integer validation)

**CHANGED:** Removed "version" field from JSON output (Write-ProviderJson); platform now
  deserializes this as java.lang.Integer and rejects dotted string format ("4.5").  
  Version tracked in bundle description and all docs; enforce reads from description regex.  
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
