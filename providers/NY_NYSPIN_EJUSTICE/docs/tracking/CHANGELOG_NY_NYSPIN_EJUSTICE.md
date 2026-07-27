# NY_NYSPIN_EJUSTICE -- Changelog

Auto-generated from `NY_NYSPIN_EJUSTICE_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.16** | Generated: 2026-07-27

---

## v4.16 -- 2026-07-27 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.15 -- 2026-07-27 -- DEX-1284 shadow-review follow-up -- in/out routing gates (FUNCTIONAL)

**CHANGED:** Gated the 4 previously-ungated in/out combos so an out-of-state (State-bearing) query
         no longer co-fires with its NY in-state sibling. Existence-only RegistrationState gates  
         (poisoned-array-safe):  
           VehicleRegistrationQuery  
             - RVEHOUT (OOS plate)  += RegistrationState EXISTS  
             - RVEH    (NY plate)   += RegistrationState NOT_EXISTS  
             - RCAR    (NY VIN)     += RegistrationState NOT_EXISTS  (alongside existing LPN NOT_EXISTS)  
           BoatQuery  
             - BVIN    (OOS hull)   += RegistrationState EXISTS  
             - RVEH    (NY reg)     += RegistrationState NOT_EXISTS  (alongside existing Hull NOT_EXISTS)  
             - RCAR    (NY hull)    += RegistrationState NOT_EXISTS  
         (RVIN and BVEH were already State-gated; DriverHistory in/out already gated at v4.0.)  
         Header comment corrected 7 QIDMs/17 combos -> 6/16 (DGRP was removed at v4.11) and the  
         stale DGRP QIDM/DL+DGRP lines dropped.  
**REASON:** DEX-1284 portfolio shadow-query review. Rob's rule: in-state vs out-of-state are ALWAYS
         distinct queries (the FL_FCIC pattern) -- both siblings must stay reachable but must NOT  
         co-fire. Adversarial re-review confirmed NY has NO shadow-subset combos to remove (unlike  
         TX_TLETS QV). Functional routing change: Vehicle + Boat reset for re-test from T1;  
         Person/Firearm/Article fingerprints unchanged (preserved-blocked). NOT yet tenant-tested  
         at v4.15 (Rob re-runs the NY sweep).  

## v4.14 -- 2026-07-27 -- DEX-1284: Person cards -- OLN + State + NCIC Image on the top line

**CHANGED:** Both Person cards (DRIVER LICENSE + DRIVER HISTORY) now place the primary identifier
         and the two routing/option fields together on the TOP row (6/3/3):  
           - OLN [6] | State [3] | NCIC Image [3]  
         Merged the old two-row arrangement (row 1 = OLN full-width [12]; row 1B = State/Image  
         [6/6]) into one top row per card. OLN keeps the width (long identifier); State and  
         NCIC Image are short codes at 3 each. Name row (First/Last/MI/Suffix) and DOB/Sex row  
         follow unchanged. Applies to CARD_PER_DL and CARD_PER_DH identically.  
         No label/fieldId/combo/default change -- pure row/column regrouping.  
**REASON:** DEX-1284 (Rob) -- "on the person put OLN, State and NCIC Image on the top line for each
         card." Recorded as the global Person top-row pattern in BUILD_RULES Section 11 (future  
         retrofit per provider on revisit -- Rob: "expect this level of cleanup on all providers").  
         Layout-only -- no combo/QIDM/routing/fieldId change. All 5 entities reset for re-test at  
         v4.14 (block-by-version; Vehicle force-reopened so its v4.13 logs don't carry over).  

## v4.13 -- 2026-07-27 -- DEX-1284: Vehicle card 4/4/4 balance + global field-size/placement standard

**CHANGED:** Rebalanced the Vehicle card to a uniform 4/4/4 column grid so fields align
         left-to-right AND top-to-bottom:  
           - ROW_VEH_1 (Plate Number / Plate Type / Plate Year): 4/2/2 -> 4/4/4  
             (was filling only 8 of 12 cols; Plate Type/Year were cramped at width 2)  
           - ROW_VEH_2 (VIN / Vehicle Make / Vehicle Year): 6/3/3 -> 4/4/4  (VIN 6 -> 4)  
           - ROW_VEH_3 (State / NCIC Image): 6/6 -> 4/4  (State 6 -> 4; a 2-char code no  
             longer sits in a half-row box; State/Image align under the columns above)  
         No label/fieldId/combo/default change on the Vehicle card.  
TOOLING/DOCS (this session, no NY JSON impact beyond the layout above): (1) corrected  
         docs/reference/NY_NYSPIN_EJUSTICE_SUPPORTED_QUERIES.txt -- removed the false  
         "DL Name Search | Name" CONFIRMED line (NyNyspinDriverLicenseNameQuery is an  
         "Expanded Transactions Supported" transaction @844, NOT Basic; removed from the build  
         at v4.11) and embedded the devdoc ground-truth Basic list. (2) hardened  
         tools/audit_supported_queries.ps1 (Get-DevdocBasic) to extract + embed each devdoc's  
         real "Basic Queries Supported" list into the seeded template and print it every run  
         (closes the rubber-stamp hole that let the DGRP shadow pass a CONFIRMED gate).  
**REASON:** DEX-1284 (Leo/Rob) -- "shorten VIN and State so everything looks balanced left-to-right
         and top-to-bottom; do better at field size and placement globally." New GLOBAL  
         field-size/placement standard recorded in BUILD_RULES Section 11 (uniform grid, size to  
         the grid, no lopsided <12 rows, no half-row box for a short code field), FUTURE-RETROFIT  
         per-provider on revisit. Layout-only -- no combo/QIDM/routing/fieldId change. All 5  
         entities reset for re-test at v4.13.  

## v4.12 -- 2026-07-27 -- DEX-1284: HI-style lean label pass (all 5 entities) + global "NCIC Image" convention

**CHANGED:** Stripped every inline field helper EXCEPT the State routing hint, across all 5 entities.
         The card TITLE now carries each entity's query paths (the NY Vehicle model extended to  
         the rest):  
           - Person DL card title -> 'Driver License Search by OLN, "OR" Name'  
           - Person DH card title -> 'Driver History Search by OLN, "OR" Name'  
           - Firearm card title    -> 'Firearm Search by Serial Number'  
           - Article card title    -> 'Article Search by Serial Number'  
           - Boat card title       -> 'Boat Search by Registration, "OR" Hull ID'  
           - Vehicle title unchanged ('Vehicle Registration Search by Plate, "OR" VIN' -- the model)  
         Field label strips: Plate Number / VIN / Vehicle Make / Vehicle Year (Vehicle);  
         First/Last/MI/Suffix/DOB/Sex/Purpose Code (Person DL+DH); Gun Make / Caliber (Firearm);  
         Article Type (Article); Registration Number (Boat). State keeps 'State (leave blank for NY)'.  
         Image fields (ImageIndicator + DH) -> canonical bare "NCIC Image".  
         Firearm + Article stolen-hit toggle (relatedHitSearchIndicator) -> "Stolen Check".  
TOOLING: verify_build.ps1 CHECK 15 Rule 3 gained a $canonicalBareLabels allowlist that accepts the  
         bare "NCIC Image" label (global convention -- purely permissive, cannot regress any  
         provider). LABEL-OVERRIDE tags added for the deliberately-bare any[] fields  
         (VehicleMakeCode, vehicleYear, nameMiddle, nameSuffix, nameMiddleDH, nameSuffixDH, GunMake,  
         GunCaliber, relatedHitSearchIndicator).  
**REASON:** DEX-1284 (Leo) direct feedback -- lean/HI-style labels, card title guides the query. Two
         NEW GLOBAL conventions recorded in BUILD_RULES Section 11 + CLAUDE.md field-config, both  
         FUTURE-RETROFIT (applied per-provider on its revisit turn, NY first): (1) canonical  
         "NCIC Image" image-field label; (2) lean-label / card-title-carries-the-path style.  
         Label/title-only -- NO combo/QIDM/routing/fieldId/default change. All 5 entities reset for  
         re-test at v4.12. DEFERRED: none for this pass (purpose-code dropdown still pending Leo).  

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

