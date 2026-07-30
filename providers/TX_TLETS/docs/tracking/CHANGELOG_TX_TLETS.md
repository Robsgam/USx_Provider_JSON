# TX_TLETS -- Changelog

Auto-generated from `TX_TLETS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.14** | Generated: 2026-07-30

---

## v4.14 -- 2026-07-30 -- Vehicle: all 7 metadata combinations made FORM-REACHABLE (prefills removed, RQ/QV restored)

**CHANGED:** Removed the four routing-affecting Vehicle prefills -- LicensePlateTypeCode=PC,
  LicensePlateYear=<year>, financialResponsibilityType=E, RegistrationState=TX -- from BOTH the  
  form initialValue and every combo defaults[]. Rebuilt the VehicleInsuranceRegistrationQuery  
  combination array from 3 combos to all 7 in metadata, most-specific-first, and RESTORED  
  RQLicensePlateNumber + RQVehicleIdentificationNumber (deleted at v4.13) plus  
  QVLicensePlateNumber + QVVehicleIdentificationNumber. RQ{VIN} and QV{VIN} share an identical  
  metadata set[] ({VIN}) -- the one real shadow pair -- split on RegionId EXISTS/NOT_EXISTS, the  
  only optional that differs between them. Combos now select by officer input:  
    plate+year+type -> RQ (OutofState) | plate+year+FRT -> REG (InState+insurance)  
    plate -> QV | VIN+FRT -> VIN | VIN -> RQ/QV{VIN} by RegionId | sticker -> DPSI  
**REASON:** v4.13 shipped 3 of 7 combinations and had DELETED the devdoc's two "(OutofState)" vehicle
  paths as "dead combos" -- so out-of-state plate and VIN search did not exist in the provider.  
  They were never dead: the form prefilled their discriminators, so the combo requiring the  
  prefilled field matched on EVERY submission and nothing else could win first-match. The v4.13  
  justification ("Officer impact none: REG/VIN return a superset") was wrong -- an in-state TX DMV  
  query is not a superset of an out-of-state Nlets query, it is a different destination system.  
  Found by tools\audit_query_trace.ps1, now gated by enforce PHASE 2n. 35 such combinations exist  
  across 6 providers; TX is the first fixed. Rob 2026-07-30: "remove defaults that affect routing"  
  + "the form comes first". Officer-facing change: a bare plate now returns plain registration (QV)  
  instead of registration+insurance -- type FRT=E for the insurance return, as the devdoc intends.  
  audit_query_trace: 21 built / 0 PREFILL-DEAD / 0 SHADOW / 0 MISSING. Reachability: 21/21.  
  ALL 5 ENTITIES RESET at v4.14. CCH rebuild owed in lockstep (BASE-SYNC -> v4.14). NOT yet re-tested.  

## v4.13 -- 2026-07-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.12 -- 2026-07-27 -- Person 2-card fold -- OPTIONS duplicated onto DL + DH (direct Rob feedback)

**CHANGED:** Folded the standalone SEARCH OPTIONS card away -- Person is now 2 cards (DRIVER LICENSE
  + DRIVER HISTORY), with the State / NCIC Image / Reason Code options DUPLICATED onto the BOTTOM  
  row of EACH card:  
    - DL card last row (ROW_PER_DL_OPT): State + NCIC Image + Reason Code -- shared fieldIds  
      (RegistrationState/ImageIndicator/reasonCode), DriverLicenseQuery unchanged. The single  
      hidden EmailAddress feeder moved here too (ROW_PER_DL_OE).  
    - DH card last row (ROW_PER_DH_OPT): DH-suffixed copies (RegistrationStateDH/ImageIndicatorDH/  
      reasonCodeDH) -- unique fieldIds, self-contained DH like NY/HI. The DriverHistoryQuery  
      attributes (State/ImageIndicator/ReasonCode sourceField) + KQName/KQOLN any[] were re-sourced  
      to the DH-suffixed names. Attribute names + wire targetFields UNCHANGED -> wire request identical.  
  EmailAddress is NOT duplicated: the single shared hidden feeder on the DL card serves both QIDMs  
  (both still source 'emailAddress'), so the RND-57165 handler (separate eng team) is UNTOUCHED.  
  This resolves the v4.8 "OPTIONS card kept / fold deferred" note.  
**REASON:** Rob 2026-07-27 -- "fix person to be 2 card and duplicate the search options into each card
  dl and dh; make it the last line of each card." verify_build 16P/0W/0F; test_commsys confirms  
  KQName/KQOLN still fire (OLN>Name guardrail intact). Layout + DH-sourcing change (wire-identical).  
  ALL 5 ENTITIES RESET at v4.12 (block by version). CCH rebuilt in lockstep (BASE-SYNC -> v4.12).  
  NOT yet re-tested.  

## v4.11 -- 2026-07-27 -- UPPERCASE card titles (Rob global decision, NO functional change)

**CHANGED:** All card titles UPPERCASED, wording unchanged (e.g. "Driver License Search by OLN,
  \"OR\" Name" -> "DRIVER LICENSE SEARCH BY OLN, \"OR\" NAME"; "Firearm Search by Serial Number,  
  \"OR\" NCIC Number" -> all-caps). New global convention (BUILD_RULES Section 11). Mechanical  
  uppercase transform of every card `title` string; no wording/field/combo/QIDM change.  
**REASON:** Rob -- "everything needs to be upper case" (card-title standardization, chosen form =
  uppercase current wording). Title-only. verify_build clean. ALL 5 ENTITIES RESET at v4.11  
  (block by version). CCH rebuilt in lockstep (v1.7, BASE-SYNC -> v4.11). NOT yet re-tested.  

## v4.10 -- 2026-07-27 -- Person DL top-row -- OLN alone on the top line (direct Rob feedback)

**CHANGED:** Restructured CARD_PER_DL to mirror the DH card's 3-content-line layout. The DL card
  had OLN + Date of Birth + Sex lumped on one row (ROW_PER_L1, 6/3/3). Now:  
    ROW_PER_L1 (12)   -- OLN alone  
    ROW_PER_N1 (3/3/2/2/2) -- First/Last/MI/Suffix/Message Key  (unchanged)  
    ROW_PER_N2 (6/6)  -- Date of Birth / Sex   (NEW -- moved off ROW_PER_L1, matches DH's ROW_PER_DHN2)  
  Also removed the stale QV Plate / QV VIN combo blocks from TX_TLETS_SQVR.txt (both combos were  
  removed at v4.9 but their SQVR entries -- incl. a [PENDING] marker that blocked Vehicle block-out  
  -- were left behind).  
**REASON:** Rob, reviewing the rendered TX Person form during the v4.10 tenant re-test: "keep it three
  lines like the DH card with just OLN on top line." Layout-only -- no combo/QIDM/routing/fieldId/  
  label change. Person reopened for re-test; Vehicle (block-locked at v4.9, fingerprint unchanged)  
  preserved. CCH variant rebuilt in lockstep (v1.6, BASE-SYNC -> v4.10).  

## v4.9 -- 2026-07-27 -- DEX-1284 shadow-query correction: removed QV subset-shadows (FUNCTIONAL)

**CHANGED:** Removed QVLicensePlateNumber + QVVehicleIdentificationNumber from
  VehicleInsuranceRegistrationQuery (7 -> 5 combos; 19 total CommSys). Both were ungated  
  SUBSET-SHADOWS: QV{LicensePlateNumber} is a subset of REG{Plate,Year,FRT} / RQ{Plate,Type,Year};  
  QV{VehicleIdentificationNumber} is a subset of VIN{VIN,FRT}. The extra fields are FRT/Type/Year  
  QUALIFIERS of the same plate/VIN query -- NOT a state discriminator -- so the platform auto-fires  
  the metadata QV transaction from the larger query and an explicit combo was redundant (same class  
  as the QWName removal v4.2 and NY's DGRP v4.11).  
  - RegionId (an OPTIONAL member of the QV combination) KEPT and moved to the RQ plate + RQ VIN  
    any[] -- a devdoc-optional combination field is NEVER dropped (Rob 2026-07-27); it serializes  
    into the union pool the platform's auto-fired regional QV reads. ROW_VEH_3 stays 4/4/4.  
  - Boat QB in-state combos (QBRegistrationNumber, QBBoatHullIdNumber) gated RegistrationState  
    NOT_EXISTS -- they were ungated and co-fired with the State-bearing BQ OOS combos; now  
    mutually exclusive (in-state fires State-blank, OOS fires State-present), matching FL_FCIC's  
    in/out gating. state field set 'In/Out' -> 'In'.  
RULING (Rob 2026-07-27): in-state vs out-of-state are ALWAYS distinct queries -> kept and gated  
  (State EXISTS/NOT_EXISTS), never removed. Only ungated subset-shadows whose extra fields are  
  same-query qualifiers (no state discriminator) are removable -- that was QV, not the in/out pairs.  
**REASON:** DEX-1284 adversarial re-review of NY+TX corrected the shadow-query model (a subset combo is
  platform-auto-fired from its superset, not "unreachable"). Portfolio subset-shadow map run same day.  
  FUNCTIONAL change -> all 5 entities reset for re-test from T1. TX_TLETS_CCH rebuilt in lockstep (v1.5).  

## v4.8 -- 2026-07-27 -- DEX-1284: relabel/naming-convention pass (NY-established portfolio conventions)

**CHANGED:** Applied the conventions established on NY_NYSPIN_EJUSTICE (BUILD_RULES Section 11):
  - OLN: OperatorLicenseNumber (DL) + OperatorLicenseNumberDH (DH) label -> "OLN".  
  - NCIC Image: every image field (Person OPTIONS, Gun, Article, Boat) -> canonical "NCIC Image"  
    (was "NCIC Image - if available"; verify_build CHECK 15 accepts the bare canonical label).  
  - Stolen Check: relatedHitSearchIndicator (Gun/Article/Boat) -> "Stolen Check"  
    (was "(Y) for NCIC stolen-<entity> check").  
  - Lean labels: stripped remaining "(optional)"/"(or use X)"/"(required)" helpers -- Vehicle  
    Make/Year, VIN (was spelled-out "Vehicle Identification Number" -> "VIN"), Firearm Serial  
    Number, Gun Make/Caliber, Article Type, Boat Registration Number, MI/Suffix (DL+DH),  
    Message Key. Bare any[]-only fields carry LABEL-OVERRIDE tags.  
  - Card titles: Person DL/DH now carry the query paths ("Driver License/History Search by OLN,  
    \"OR\" Name"); Firearm/Article titles switched "Query by" -> "Search by".  
  - Uniform 4/4/4 grid on Vehicle: ROW_VEH_1 5/2/2/3 -> 3/3/3/3, ROW_VEH_2 5/4/3 -> 4/4/4.  
PERSON OPTIONS CARD KEPT (NOT folded into DL/DH): the NY-style Person top-row (OLN + State +  
  NCIC Image on each card) would require DH-suffixed copies of the shared State/Image/Reason/  
  EmailAddress fields AND touching the EmailAddress handler, which is owned by a separate eng  
  team (RND-57165 -- do not build/modify). So State/Image stay on the shared SEARCH OPTIONS card  
  (Image relabeled "NCIC Image"); OLN stays on the DL/DH top rows. Flagged to Rob.  
SHADOW INSPECTION: portfolio review (2026-07-27) + the hardened devdoc gate confirm all built  
  queries are in the TX devdoc "Basic Queries Supported" list (VehicleInsuranceRegistrationQuery  
  is the Basic-authorized RQ alternative; QWName shadow already removed v4.2). No shadow to remove.  
**REASON:** DEX-1284 (Rob) -- "same relabeling and naming convention along with the shadow inspection."
  Label/title/layout-only -- NO combo/QIDM/routing/fieldId/default change. All 5 entities reset for  
  re-test at v4.8. TX_TLETS_CCH variant rebuilt in lockstep (BASE-SYNC -> v4.8).  

## v4.7 -- 2026-07-21 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.6 -- 2026-07-21 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.5 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.4 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.3 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.2 -- 2026-07-15 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.1 -- 2026-07-15 -- EmailAddress auto-populate handler (RND-57165)

**CHANGED:** EmailAddress converted from a manually-typed field to the automated-handler pattern --
         GetUserProfileSingleValueRuleHandler (arguments=['email']) on the QIDM attribute (both  
         DriverLicenseQuery and DriverHistoryQuery), same hidden-gate-feeder mechanism already  
         proven for Attention: emailAddress_Input on the shared Person SEARCH OPTIONS card  
         converted to a hidden InpH with initialValue='X', and EmailAddress='X' added to both  
         $imgDefs (DL) and $imgDefsDH (DH) combo defaults so the gate-feeder value actually  
         reaches the serialization pool (audit_cad CHECK 6). Confirmed ReasonCode="C" default  
         already existed on both -- no change needed there, satisfies the ticket's second ask.  
         Added GetUserProfileSingleValueRuleHandler to validate.ps1's known-handlers list and  
         verify_build.ps1's hidden-field approved-exception whitelist (both previously only knew  
         about Attention/requestorDH); added it to knowledge-base/RULE_HANDLERS.txt as handler  
         #25. Reference material (ticket summary, Confluence handler doc, sample config) saved  
         to source/RND-57165_EmailAddressHandler/.  
**REASON:**  Texas CJIS Security Policy requires DL-photo requests (ImageIndicator=Y) to carry the
         actual signed-in officer's email, not a shared/agency address or an officer-typed value  
         that could be wrong or blank -- this was the one deliverable the separate eng team  
         (RND-57165) had to build before TX_TLETS could be re-tested and block_entity-locked;  
         the field was deliberately left visible/manual since v4.0 specifically as a stand-in  
         until this handler was delivered.  
VALIDATOR: 81P/0F/0W/0LIM. VERIFY: 15P/0W/0F. Full re-test from Test 1 (GATE 1) required before  
         re-locking -- this is a version bump on a previously fully-tested provider.  

## v4.0 -- 2026-07-09 -- Rebuild under current methodology (PascalCase + condensed UI + reachability)

**CHANGED:**
  1. PascalCase USx CAD fieldIds authored natively (22-token set) + -PascalCaseUsxFields on the RMS  
     bundle; Mark43-internal keys stay camelCase. Versioned root filename TX_TLETS_v4.0.json.  
  2. Cleared both PENDING_UPDATES flags -- shared-module fixes verified present in the JSON:  
     VehicleMakeName QRDM now VEHICLE_MAKE/NCIC (RND-62365, not the firearm table); ParseCommsysName  
     carries its NormalizedName* args (PARSECOMMSYS-ARGS).  
  3. Condensed FL-style UI + full CHECK-15 label-hint pass across all 5 entities. Person keeps the  
     shared OPTIONS card; emailAddress exposed/untouched (auto-handler to be added later by the  
     owning team). Exposed MessageKey (CPL/DWI/RDL) on the DL card + CPL combo any[] (metadata is  
     the field-authority).  
  4. CHECK-16 reachability: set[] does NOT gate firing (only primaryFieldReference + conditions do),  
     so the metadata combos that differed only by set[] were permanently shadowed. Added  
     existence-only EXISTS gates so all are reachable: VIN -> FinancialResponsibilityType EXISTS;  
     QV-VIN -> RegionId EXISTS (+ RegionId promoted any->set, ordered before RQ-VIN, recorded in  
     ACCEPTED_DIVERGENCES); DL DQName -> SexCode EXISTS; QWName -> BirthDate EXISTS; Boat BQ combos  
     -> RegistrationState EXISTS.  
  5. DH image-variant split MERGED to 2 combos (KQName/KQOLN). The v3.8 set[]-based split never  
     actually enforced "Image=Y only with email" (set[] does not gate firing) and shadowed the  
     plain path. ImageIndicator=Y default now triggers the ReasonCode=C + EmailAddress trio, all in  
     any[] (sent when present; email typed now, handler later).  
  6. Structure migrated: docs -> 4-category (tracking/reports/reference/deliverables), tests/ -> logs/,  
     phases/ retired, stray TX_TLETS_FINAL.plan.json removed.  
**RESULT:** validator 81P/0F/0W, verify_build CLEAN (16 checks incl. reachability), 22 CommSys combos,
  7 cards. Full re-test from T1 on re-import.  
**REASON:** Scheduled rebuild under the current methodology (was out-of-scope/camelCase/legacy layout).

## v3.13 -- 2026-06-24 -- Gap-audit remediation (Hull>Reg completion + CAD plate defaults)

**CHANGED:**
  1. Hull>Reg guardrail COMPLETED -- added boatHullIdNumber NOT_EXISTS to BQRegistrationNumber.  
     v3.12 only gated the in-state QBRegistrationNumber; the OOS Nlets BQRegistrationNumber was  
     missed, so Hull+Reg+State co-entry still bled RegistrationNumber into the Hull XML. Found by  
     verify_build CHECK 12 once it was promoted to FAIL (was a silent WARN).  
  2. CAD plate-default gap -- REGLicensePlateNumber (set: plate+year+FRT) and RQLicensePlateNumber  
     (set: plate+year+type) require licensePlateYear / licensePlateTypeCode in set[], but CAD  
     ignores form initialValue, so CAD-dispatched REG/RQ plate queries could not fire. Added  
     LicensePlateYear=$currentYear and (RQ) LicensePlateTypeCode=PC combo defaults. Surfaced by  
     audit_cad CHECK 6 after it was fixed to scan set[] (not just any[]).  
CONTEXT: part of the portfolio gap-audit (TX/FL/HI). Tooling hardened in the same pass:  
  verify_build CHECK 14 (gate-xor-companion), CHECK 12 -> FAIL, run_test_matrix exact-match,  
  audit_cad case-fix + set[] scan, and verify_build + audit_cad wired into enforce as blocking gates.  
**RESULT:** 83P/0F/0W/0LIM; verify_build CLEAN (14 checks); audit_cad 76P/0F; conductor 37/37.
  Re-import + full re-test from T1 (test package reset).  

## v3.12 -- 2026-06-23 -- Identifier-priority rollout + Attention resolved

**CHANGED:**
  1. Identifier-priority guardrail applied for all 3 pairs (NOT_EXISTS conditions,  
     camelCase QIF sourceField -- verify_build CHECK 13):  
     - Plate>VIN: licensePlateNumber NOT_EXISTS on the VIN-path vehicle combos  
       (VINVehicleIdentificationNumber, RQVehicleIdentificationNumber, QVVehicleIdentificationNumber).  
     - OLN>Name (DL): operatorLicenseNumber NOT_EXISTS on DQName / QWName / CPLName.  
     - OLN>Name (DH): operatorLicenseNumberDH NOT_EXISTS on KQNameImg / KQName.  
     - Hull>Reg: boatHullIdNumber NOT_EXISTS on QBRegistrationNumber.  
  2. ATTENTION auto-populate RESOLVED (reverses the v3.11 "INERT" conclusion) using the  
     HI v2.9 pattern: 'Attention' added to all 4 DH combo any[]; hidden InpH gate-feeder  
     (initialValue='X') added to the DH card; sourceField=['Attention'];  
     CommsysGetLastNameFirstNameInitialRuleHandler on the Attention attribute. Pending  
     live confirmation at re-test.  
  3. CAD audit CHECK 6: added Attention=X default to both DH combo default sets  
     ($imgDefsDH / $noImgDefsDH) to match the gate-feeder's form initialValue.  
  4. vehicleYear added to the VIN combo any[] (attribute existed but was in no combo any[],  
     so it was silently dropped from VIN XML).  
  5. QBRegistrationNumber: boatHullIdNumber removed from any[] -- a field cannot be in the  
     serialization pool AND be the subject of a NOT_EXISTS gate on the same combo (the  
     contradiction also poisoned the test conductor's minimal-data injection).  
TOOLING: generate_test_matrix.ps1 now emits the full keyRef (not the collapsed short prefix)  
  in each Expected line, so run_test_matrix.ps1 resolves the specific combo rather than the  
  first sibling sharing a prefix (QBRegistrationNumber / QBBoatHullIdNumber / QBNCICNumber  
  previously all collapsed to 'QB' and false-passed). Verified non-regressive on FL (42/42).  
**REASON:** Roll the identifier-priority guardrail to TX (3rd provider after HI/FL) and resolve
  Attention now that the HI v2.9 root cause (missing from combo any[]) is understood.  
**RESULT:** 83P/0F/0W/0LIM; conductor 37/37 PASS; CAD audit 76P/0F; metadata 178P/0F.
  Re-import + full re-test from T1 (test package reset).  

## v3.11 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.10 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.9 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.8 -- 2026-06-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.7 -- 2026-06-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.6 -- 2026-06-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.5 -- 2026-06-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.4 -- 2026-06-14 -- Poisoned-array fix (DL+DH ImageIndicator conditions)


## v3.3 -- 2026-06-09 -- Remove unauthorized VehicleStolenQuery


## v3.2 -- 2026-05-26 -- Conditional image/email routing (ImageIndicator conditions)


## v3.1 -- 2026-05-22 -- Single JSON rebuild (BASE/MC merge, 0 LIM)


## v3.0 -- 2026-05-20 -- Fresh rebuild -- minimized cards, tightened layouts, full defaults


## v2.7 -- 2026-05-18 -- One-directional queriesToDeselect fix


## v2.6 -- 2026-05-18 -- EmailAddress user-fillable + Attention fix + DH-suffix


## v2.2 -- 2026-05-07 -- Add VehicleStolenQuery (metadata gap fix)


## v2.1 -- 2026-05-06 -- PlateType/PlateYear defaults (cross-provider audit)


## v2.0-mc -- 2026-05-05 -- MC multi-card layout variant


## v2.0 -- 2026-05-05 -- Complete rebuild from scratch


## v1.0 -- 2026-04-23 -- queryLabel standardization (direct JSON edit)


## v1.0 -- 2026-04-21 -- Initial standup


## v2.5 -- 2026-05-11 -- LIMITATION elimination pass

