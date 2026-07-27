# NY_NYSPIN_EJUSTICE -- Changelog

Auto-generated from `NY_NYSPIN_EJUSTICE_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.11** | Generated: 2026-07-27

---

## v4.11 -- 2026-07-27 -- DEX-1284: remove DGRP name-search card + OLN relabel (2-card Person)

**CHANGED:** Removed the NyNyspinDriverLicenseNameQuery (DGRP) "DL NAME SEARCH" QIDM + card ->
         Person condensed to 2 cards (DRIVER LICENSE + DRIVER HISTORY). Relabeled the OLN field  
         on both cards (OperatorLicenseNumber / OperatorLicenseNumberDH) "License Number (or  
         search by Name)" -> "OLN" (global OLN labeling convention, NY's revisit turn).  
         QIDMs 7->6, Person cards 3->2, combos 17->16.  
**REASON:** DEX-1284 (Leo) -- the DGRP card was a name-only shadow of DriverLicenseQuery's DLICN
         (Name+DOB+Sex) combo, an Expanded/non-Basic transaction. Data-safe removal (DGRP fields  
         self-contained). DL-by-name now runs via DLICN (requires Name+DOB+Sex). RMS person query  
         unchanged. DEFERRED to Rob's specifics: HI-style label trim, CAD-render QA; purpose code  
         left as-is. ALL 5 entities reset for re-test at v4.11.  

## v4.10 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.9 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.8 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.7 -- 2026-07-13 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.6 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.5 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.4 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.3 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.2 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.1 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.0 -- 2026-07-06 -- Cross-provider hardening rollout (rebuild, not a routine pipeline pass)

**CHANGED:**
  - PascalCase conversion: the 22 USx CAD-integration field names authored natively  
    PascalCase (sourceField/set/any/layout fieldId); RMS bundle built with  
    -PascalCaseUsxFields. Fields not on the 22-token list (vehicleYear, nameMiddle(DH),  
    nameSuffix(DH), relatedHitSearchIndicator, purposeCodeDH, requestorDH,  
    nyNyspinTransactionNameDH) intentionally stayed camelCase.  
  - Poisoned-array fix (DriverHistoryQuery): the old State-value-comparison conditions  
    (In=IN('NY','null'), Out=NOT_EQUALS 'NY') keyed on the attribute NAME instead of  
    sourceField AND used value-comparison operators -- per the live-proven  
    POISONED-ARRAY RULE these were wholly inert, so DALHOUT/DALH/DALLOUT/DALL had zero  
    real in-state/OOS routing. Replaced with existence-only conditions on  
    RegistrationState (EXISTS on the OOS combos, NOT_EXISTS on the in-state combos).  
  - Identifier-priority guardrail rollout (3 pairs): Vehicle Plate>VIN (LicensePlateNumber  
    NOT_EXISTS on RVIN/RCAR), Person OLN>Name on both DriverLicenseQuery (DLICN) and  
    DriverHistoryQuery (DALHOUT/DALH), and Boat Hull>Reg (BoatHullIdNumber NOT_EXISTS on  
    BVEH/RVEH).  
  - OOS-gate symmetry hardening: added RegistrationState EXISTS to RVIN (Vehicle) and  
    BVEH (Boat) -- set[] is not a firing gate, so these OOS combos were previously  
    shadowing their in-state counterparts (RCAR / Boat RVEH) on a bare-identifier  
    payload regardless of State (verify_build CHECK 16, a genuine pre-existing latent  
    bug exposed once the new NOT_EXISTS guardrails made those combos checkable).  
  - CAD default gap fix: added PurposeCode='C' to DALHOUT/DALLOUT's defaults[] (form  
    initialValue existed but had no matching combo default; CAD ignores initialValues).  
  - Adopted the versioned root JSON filename (NY_NYSPIN_EJUSTICE_v4.0.json), replacing  
    the bare NY_NYSPIN_EJUSTICE.json, matching NJ/HI/FL/CA_CLETS.  
  - Cleared 2 shared-module PENDING_UPDATES.txt flags (RND-62365 VehicleMakeName QRDM,  
    PARSECOMMSYS-ARGS ParseCommsysName empty-args bug) -- both fixes already live in  
    shared tooling, picked up automatically by this rebuild.  
**REASON:** NY had never received the identifier-priority/poisoned-array/PascalCase rollouts
  already live-proven on HI_HCJDC_OFML/FL_FCIC/TX_TLETS/CA_CLETS. Full re-test mandate --  
  Vehicle/Person/Boat entities reset to PENDING (Firearm/Article structurally unchanged  
  besides PascalCase renames, which do not change wire XML).  

## v3.0 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.9 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.8 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.7 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.6 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.5 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.4 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.3 -- 2026-06-08 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.2 -- 2026-06-08 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-06-03 -- Layout tightening + DGRP QIDM


## v2.0 -- 2026-05-22 -- Single JSON rebuild (BASE/MC merge, 7 fixes)


## v1.6 -- 2026-05-18 -- Single JSON output + shared tooling rebuild

**CHANGED**
  - Single pretty-printed JSON output (READABLE files eliminated)  
  - Rebuilt with current shared tooling improvements  
  - No functional QIDM or layout changes  
**REASON**
  - Repo-wide elimination of dual JSON output (minified + readable)  
  - Shared module updates (_build_provider_helpers.ps1, _build_rms_bundle.ps1)  
VALIDATOR  
  - BASE: 74 PASS / 0 FAIL / 0 WARN  
  - MC:   74 PASS / 0 FAIL / 0 WARN  

## v1.5 -- 2026-05-11 -- LIMITATION elimination pass

**CHANGED**
  - DH-suffix fieldIds, queriesToDeselect, combo ordering  
  - DGRP removed, DLICN restored in DL QIDM for single checkbox  
VALIDATOR  
  - BASE: 74 PASS / 0 FAIL / 0 WARN / 0 LIMITATION  
  - MC:   74 PASS / 0 FAIL / 0 WARN / 0 LIMITATION  

## v1.2 -- 2026-05-07 -- Monorepo rebuild + Patch 8

**CHANGED**
  - Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)  
  - Rebuilt with current validate.ps1/build_report.ps1 toolchain  
  - Reports regenerated at docs/base/ and docs/mc/  
**REASON**
  - CAD auto-populate standardization (Patch 8, all providers)  
  - Monorepo migration standardization  
VALIDATOR  
  - BASE: 72 PASS / 0 FAIL / 0 WARN / 5 LIMITATION  
  - MC:   72 PASS / 0 FAIL / 0 WARN / 5 LIMITATION  

## v1.1 -- 2026-04-30 -- NJ cross-reference rebuild (GATE 7)

**CHANGED**
  - ImageIndicator FormSelect added to ALL entities (Vehicle, Firearm, Article, Boat forms)  
    Person already had ImageIndicator; changed from FormInput to FormSelect (NIBRS/YES_NO_UNKNOWN)  
  - ImageIndicator QIDM attribute + combo any[] added to ALL QIDMs that support it  
    Vehicle (RVIN/RVEH/RCAR), Gun (GINQ), Article (AINQ), Boat (BVEH/BVIN/RVEH/RCAR)  
  - AUTH keyReference='AUTH' added to authentication combination  
  - RMS autoSelect=true added to both Vehicle and Person RMS QIDMs (Patch 7)  
  - MC build script: same fixes mirrored in multi-card layout (OPTIONS cards + entity cards)  
**REASON**
  - Cross-reference against NJ_NJCJIS baseline (GATE 7) revealed 11 warnings:  
    ImageIndicator missing from 4 entities, Person Image was FormInput not FormSelect,  
    AUTH had no keyReference, RMS QIDMs missing autoSelect  
  - Validator updated same session: WARN/LIMITATION taxonomy, Write-Limitation function  
  - v1.0 was declared DONE without NJ cross-reference — this rebuild corrects that  
VALIDATOR  
  - BASE: 71 PASS / 0 FAIL / 0 WARN / 5 LIMITATION / 13 FIRE / 0 SKIP  
  - MC:   71 PASS / 0 FAIL / 0 WARN / 5 LIMITATION / 13 FIRE / 0 SKIP  

## v1.0 -- 2026-04-24 -- Phase 1 + MC confirmed build

**CHANGED**
  - Both BASE and MC variants live-tested: BASE 15/15 PASS, MC 19/19 PASS  
  - Patch 6 (RMS cleanup) applied  
  - DGRP removed, DLICN handles Name path within DriverLicenseQuery  
  - queryLabel standard applied  
  - NCIC state pattern and NIBRS sex reverse-lookup confirmed  
  - PlateType=PC, PlateYear=2026 defaults (retested 2026-04-28)  

## v1.1-old -- 2026-04-20 -- Fix RMS import error: sexcodeoos missing attribute

**CHANGED**
  - build_ny_nyspin_ejustice.ps1: RMS sex removal patch now strips 'SexCodeOOS'  
    from combination any[] in addition to 'SexCode'.  
  - Filter condition changed from name-based to targetField-based (targetField -ne 'sexAttrId')  
    so both 'sex' (sourceField=SexCode) and 'sexOOS' (sourceField=SexCodeOOS) attrs are removed.  
**REASON**
  - Import failed: "Missing attributes found in query input data mapping: [sexcodeoos]"  
  - HIDLE RMS Person QIDM has 4 OOS combinations (driversLicenseNumberOOS etc.) that include  
    'SexCodeOOS' in any[]. When we removed the sexOOS attribute but not the combination  
    reference, the platform rejected the bundle (unresolved sourceField reference).  
  - Fix: filter both SexCode and SexCodeOOS from combination any[]/set[].  

## v1.0 -- 2026-04-20 -- Phase 1 reboot -- single-card single-entity build from XML metadata

**CHANGED**
  - Complete rewrite of build_ny_nyspin_ejustice.ps1 (Phase 1 architecture).  
  - 5 QIFs (single card each): Vehicle, Person, Firearm, Article, Boat.  
  - 7 QIDMs: VehicleRegistrationQuery (RVEH/RVIN/RCAR), BoatQuery (BVEH/BVIN/RVEH/RCAR),  
    DriverLicenseQuery (DLIC), NyNyspinDriverLicenseNameQuery (DGRP),  
    DriverHistoryQuery (DALL+DALH), GunQuery (GINQ), ArticleSingleQuery (AINQ).  
  - WINQ/MINQ excluded (no Transaction XML in metadata).  
  - State: blank-default NJ_NIBRS_STATE + hidden SelH RegistrationState (RMS).  
  - Sex: NIBRS_SEX CommSys-only, removed from RMS Person QIDM.  
  - DH-suffix fieldIds on all DH fields.  
**REASON**
  - Prior builds (v1.0-v1.21) built multi-card/split-entity before QIDMs were confirmed.  
    Phase 1 single-card isolates QIDM problems from layout problems (NJ lesson).  

## v1.5 -- 2026-05-11 -- LIMITATION elimination pass

