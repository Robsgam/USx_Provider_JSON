# TX_TLETS -- Changelog

Auto-generated from `TX_TLETS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.22** | Generated: 2026-08-27

---

## v4.22 -- 2026-08-27 -- QV plate RESTORED with State promoted any[]->set[] -- the devdoc (InState)

                 plate path had been UNREACHABLE since v4.17 (WIRE CHANGE)  
**CHANGED:** Added QVLicensePlateNumber to TX_TLETS_VehicleInsuranceRegistrationQuery --
  set[LicensePlateNumber, RegistrationState], any[regionId], state='In', ordered LAST of the 6.  
  VehReg 5 -> 6 combos; 19 -> 20 CommSys combos portfolio-side for this provider.  
**REASON:** Rob reported from the tenant 2026-08-27: entering a plate and a State did not light up
  the Vehicle Registration box. CONFIRMED -- and the form was behaving exactly as configured.  
  The configuration was a REGISTERED, ROB-ACCEPTED gap (see the adjudication note below), not a  
  defect that had gone unnoticed. What changes at v4.22 is the RULING, not the diagnosis.  
  THE BEHAVIOR: from v4.17 through v4.21 a plate+State fill matched NO combination at all.  
    RQ{Plate} requires Year+Type, REG{Plate} requires Year+FRT, and nothing had a plate-only  
    set[]. Proven with tools\test_commsys.ps1: against v4.21 all five combos report [SKIP]  
    (only the RMS elastic query fired, which is why the officer saw *something* happen);  
    against v4.16 the identical fill FIRES QV with <LicensePlateNumber> + <State>. That pair of  
    runs dates the break exactly to v4.17.  
  HOW IT HAPPENED -- a ruling outlived its premise:  
    v4.9  ruled QV{Plate} a redundant subset-shadow of RQ/REG. TRUE AT THE TIME: the form  
          prefilled LicensePlateTypeCode=PC, LicensePlateYear and FRT=E, so a bare plate  
          auto-satisfied RQ or REG and an explicit QV really did add nothing.  
    v4.14 removed all four routing-affecting Vehicle prefills (BUILD_RULES 24) and stated the  
          new intent in its own notes: "plate -> QV", "a bare plate now returns plain  
          registration (QV)". THIS DELETED THE PREMISE OF THE v4.9 RULING.  
    v4.17 re-applied the v4.9 ruling anyway ("remove the QV metadata shadows, restoring Rob's  
          v4.9 ruling") to a config where its premise no longer held. The hole opened here.  
  THIS WAS NOT AN UNDISCOVERED GAP -- IT WAS ADJUDICATED AND ACCEPTED, AND IS NOW REVISITED.  
    TX_TLETS_ACCEPTED_DIVERGENCES.txt has carried, since 2026-07-30, the entry  
    "VehicleInsuranceRegistrationQuery | (devdoc #5) | LicensePlateNumber |  
    devdoc-optional-unreachable", which states the symptom exactly -- "Plate+State and  
    Plate+State+RegionId therefore match nothing and send nothing" -- names the same root cause  
    ("Two individually-correct removals -- the prefills and the shadow -- together left this  
    gap"), and records ROB'S RULING: OPTION A, ACCEPT.  
    That same entry pre-specified today's fix: "Option B (rebuild QV{Plate} as a terminal  
    LAST-ordered fallback, which cannot steal fills the way the v4.9 QV did) remains available  
    if Rob revisits." v4.22 IS Option B. Rob revisited it 2026-08-27 after hitting the dead form  
    in the tenant. So this version is a RULING CHANGE on a registered, accepted trade-off --  
    not the discovery of an invisible defect. Do not re-tell it as the latter.  
  WHAT DID GO WRONG, AND IS WORTH FIXING SEPARATELY:  
    (1) THE CHANGELOG WAS HOLLOW. v4.17's entry reads only "Rebuilt via pipeline.ps1 / Scheduled  
        rebuild" while that build DELETED two combinations. Only the git commit subject mentioned  
        QV. A version that changes combinations MUST say so in this file, because this file  
        generates the changelog and is the first thing the next reader trusts. The gap was  
        recoverable only because the ACCEPTED_DIVERGENCES entry existed; the changelog alone  
        would have left it invisible.  
    (2) THE ACCEPTANCE WAS NOT VISIBLE TO THE OFFICER OR THE FORM. An accepted "sends nothing"  
        path looks identical to a broken one from the tenant. The 2026-07-30 entry itself notes  
        that label/card-hint work to TELL the officer was considered and DEFERRED ("leave the  
        labels alone for now"). That deferral is why this surfaced as a bug report rather than a  
        known limitation -- worth revisiting for any other accepted send-nothing path.  
    (3) TESTS STRUCTURALLY CANNOT COVER THIS CLASS. TX was ALL-PASS with 96 logs at v4.21. The  
        test plan is generated FROM the built combos, so removing a combination removes its own  
        test. There is never a red test for a path that no longer exists -- which is precisely  
        why removals must be adjudicated at removal time, as this one correctly was.  
  WHY State IS set[] AND NOT any[] -- Rob's ruling 2026-08-27: "make state a set and the qv of  
    plate number only will shadow properly." The metadata marks State OPTIONAL; the devdoc marks  
    it REQUIRED ("(InState) LicensePlateNumber, State [RegionId]"). Rob ruled for the devdoc.  
    The promotion is also exactly what makes the restore safe: set[Plate,State] cannot match a  
    bare plate, so this QV is GATED and cannot ungate-shadow RQ/REG the way the v4.9 version did.  
    Ordered LAST so the more specific combos still win first-match.  
  VERIFIED, all three via test_commsys against v4.22:  
    plate+State                -> QV FIRES, wire = LicensePlateNumber + State.  
    plate+State+Year+Type      -> RQ wins first-match; QV reported "FIRES shadowed"; UNION POOL  
                                  = plate/type/year/State, IDENTICAL to RQ's own set[]+any[], so  
                                  NO over-send under LIMITATION #1.  
    plate only, no State       -> QV [SKIP] missing set: RegistrationState. Nothing fires. This  
                                  is intended under the devdoc-required reading of State.  
  DEPENDENCY, DO NOT BREAK: Vehicle RegistrationState (ROW_VEH_1) carries NO initialValue --  
    verified before promoting it. If a prefill is ever added there, set[Plate,State] is always  
    satisfied, QV silently degrades to plate-only, and the v4.9 shadow returns. Do not prefill  
    Vehicle State.  
  QV{VIN} DELIBERATELY STAYS OUT: RQ{VIN} is already set[VIN], so the VIN input path exists.  
    QV{VIN} would be the genuine ungated shadow the v4.9 ruling described. audit_query_trace  
    reports 1 MISSING, not 2, for this reason.  
  ALL 5 ENTITIES RESET at v4.22 (96 prior logs archived). CCH rebuild owed in lockstep  
    (BASE-SYNC) -- TX_TLETS_CCH v1.17 carries the IDENTICAL defect, removed in the same v4.17  
    lockstep commit. IMPORT + full re-sweep owed.  

## v4.21 -- 2026-08-18 -- Layout convergence -- 3 audit_layout_flow findings fixed, 1 recorded (NO WIRE CHANGE)

**CHANGED:** (1)+(2) L7 LABEL-CAPACITY -- 'nameMiddle' and 'nameMiddleDH' were labelled 'MI', which
  means middle INITIAL, on maxLen=30 controls that accept a full middle name. Relabelled  
  'Middle Name' with a LABEL-OVERRIDE comment, matching AZ_AZDPS v3.10 and HI_HCJDC_OFML v4.20.  
  (3) L3 HIDDEN-MID-CARD -- the hidden Attention gate-feeder row (ROW_PER_DHA) was row 1 of 6 in  
  CARD_PER_DH, ABOVE all visible content, while this provider's OWN DL card already places its  
  hidden EmailAddress feeder last (ROW_PER_DL_OE). Moved to the last row of the DH card. Row  
  position carries no wire meaning -- the handler is fed by any[] membership, not by ordering  
  (HI_HCJDC_OFML v4.15 retired the initialValue='X' gate-feeder myth).  
  (4) NOT CHANGED, recorded as a LAYOUT-OVERRIDE at ROW_PER_L1: L2 SET-BELOW-ANY reports optional  
  'messageKey' sitting above mandatory 'NameLast' for CPLName. DEX-1283 #4 (Leo CAD review,  
  Rob-approved) explicitly asked for "OLN pairs with CPL/DWI/RDL on the top line", and OLN on that  
  row IS mandatory for DQOLN. The gate is right about the geometry and wrong about the remedy.  
  Lockstep: TX_TLETS_CCH v1.17 applies the same three fixes + the same override, BASE-SYNC -> v4.21.  
**REASON:** audit_layout_flow has flagged the 'MI' labels since 2026-08-11 and the labels shipped
  2026-07-27 -- but NOTHING EVER RAN IT, so the findings only surfaced when someone thought to ask.  
  Wiring it into enforce as PHASE 2w (advisory) on 2026-08-18 is what exposed them. Sequencing was  
  Rob's call: TX already owed 6 Person tests, so fixing FIRST cost ONE 98-test sweep instead of 6  
  tests now plus a 98-test re-sweep later (104 tests, two releases).  
NO WIRE CHANGE. Labels and row order only. Verified: validator 79P/0F/0W unchanged from v4.20;  
  combo requirements byte-identical (proven by diffing v4.20 vs v4.21 set[]/any[] -- 41 vs 41 on  
  the CCH variant, same method); requirement fidelity 19 branches / 0 UNDER / 0 OVER, which is  
  TX's exact regression-fixture baseline; devdoc combinations 20 compared / 0 unbuilt.  
ALSO ADJUDICATED, no change needed: the 14 conditional-constraint triggers that  
  check_test_preconditions.ps1 raised the moment its PreToolUse hook was repaired (it had never  
  executed). 12 of 14 are the gate applying a DriverHistoryQuery-scoped devdoc constraint to  
  Article/Boat/DL/Gun combos -- "Must be filled if ImageIndicator = Y" occurs exactly TWICE in the  
  whole TX devdoc and both sit under the DH heading. The 2 real ones (KQName/KQOLN) are LIVE-PROVEN  
  satisfied: both carry defaults ReasonCode=C, and the wire shows <ReasonCode>C</ReasonCode> plus a  
  real <EmailAddress> alongside <ImageIndicator>Y</ImageIndicator>.  
AND: the Name separator was investigated and deliberately LEFT ALONE. TX emits <Name>DOE,JOHN A JR</Name>  
  with NO space, where 18 of 20 providers use ', '. That is CORRECT here: the 2025 TCIC/TLETS manual,  
  Part 1 p125 "Texas Driver License Search Criteria", requires "LASTNAME,FIRSTNAME". The ', ' form is  
  the NCIC/TCIC format from Part 2 p88 (INTERPOL section). A cross-provider majority is not evidence  
  about one provider's spec -- see knowledge-base/FIELD_REFERENCE.txt "SEPARATOR: THE PROVIDER'S OWN  
  STATE MANUAL OVERRIDES", which previously carried a standing order to "normalize to comma-space at  
  each provider's rebuild" that would have broken this build.  
TESTED: ALL-PASS 5/5, 96/96 logs, 0 FAIL (Vehicle 19 / Person 38 / Firearm 10 / Article 8 / Boat 21).  
  Name components wire-proven for the first time on TX -- DOE,JOHN / DOE,JOHN A / DOE,JOHN JR /  
  DOE,JOHN A JR, degrading cleanly with no double space. Retires [FLAG:nameparts-untested-unfrozen].  
PLAN CORRECTED 98 -> 96 DURING THIS SWEEP, and the 2 removed tests were never coverage. Repairing  
  audit_log_inflation's clone check (it could never fail -- every wire carries a unique transaction  
  id, present BOTH as an <Id> element and an id="..." attribute, so no two logs ever hashed alike)  
  exposed two vacuous plan tests that emit_test_plan had been generating for every provider:  
    - Boat: the guardrails vs BQRegistrationNumber and vs QBRegistrationNumber were BYTE-IDENTICAL,  
      because both losers contribute only 'RegistrationNumber'. The existing disambiguation renamed  
      the FILES, which hid the duplication rather than removing it.  
    - Vehicle: the VIN guardrail's fill-set equalled the VINVehicleIdentificationNumber combo test's,  
      so it staged no identifier competition at all -- it just re-ran that combo.  
  emit_test_plan now drops both classes AND PRINTS EACH DROP (a cap nobody sees reads as coverage).  
  Their 2 orphan logs were deleted. Every one of the 19 CommSys combos is still covered; what went  
  away is a test that proved one thing twice and a test that proved nothing. Other providers keep  
  their current plans until their own next rebuild (rule 8c) -- 35 clone groups are outstanding  
  across NY/FL/NJ/HI/CA and are recorded in SESSION_STATE for triage there, not swept from here.  

## v4.20 -- 2026-08-14 -- NCIC Image defaults to 'Y' on Firearm/Article/Boat (WIRE CHANGE)

**CHANGED:** ImageIndicator initialValue 'N' -> 'Y' on the three entities still at 'N', in BOTH halves
  of the default: the form FormSelect initialValue (Firearm ROW_GUN_2, Article ROW_ART_2, Boat  
  ROW_BOA_2 -- 3 authored sites, x3 layout variants) AND the combo defaults[] twin on all 10  
  carrying combinations (QGGunSerialNumber, QGNCICNumber, QAArticleSerialNumber, QANCICNumber,  
  BQRegistrationNumber, BQBoatHullIdNumber, QBRegistrationNumber, QBBoatHullIdNumber,  
  QBNCICNumber -- plus Vehicle, which TX does not carry an ImageIndicator control for). Person was  
  already 'Y' and is untouched. Takes [FLAG:ncic-image-default-y-everywhere]. Lockstep: TX_TLETS_CCH  
  v1.16 applies the identical change the same day and bumps its BASE-SYNC marker to v4.20.  
**REASON:** Rob 2026-08-12, "ncic image should default to y everywhere". BOTH halves are required --
  CAD ignores form initialValue, so a form-only flip leaves CAD-originated queries on 'N'.  
THIS IS A WIRE CHANGE. ImageIndicator rides in any[] on all 10 combos, so the value IS transmitted  
  and N->Y changes what NCIC is asked for. Hence the bump and the full 92-log re-sweep. The gain is  
  response-side: with 'N' NCIC returned no image, so a hit came back without a photo and nothing  
  errored -- a silent under-ask invisible to every request-side gate.  
*** THE TX_TLETS T6 GATE -- CHECKED FIRST, AND THIS IS THE PROVIDER THAT GATE EXISTS FOR. ***  
  TX's devdoc DOES carry conditional wording: lines 129-130, "Must be filled if ImageIndicator = Y",  
  against EmailAddress and ReasonCode. That is exactly the class that produced the T6 rule (a  
  default silently making another field mandatory). SCOPE RESOLVED BY LOCATING THE OWNING HEADING:  
  the nearest query heading at or above line 129 is DriverHistoryQuery (line 62), so the conditional  
  belongs to DH -- which is on PERSON, was ALREADY at 'Y' before this change, and already  
  auto-populates both ReasonCode and EmailAddress through hidden gate-feeders. This change touches  
  Firearm/Article/Boat only, none of which has a conditional. So the flip is clear of T6, but ONLY  
  because of where the conditional sits -- read the heading, never the bare grep hit.  
ALSO MEASURED SAFE: ImageIndicator is in ZERO set[]s and ZERO conditions on TX (counted from the  
  emitted v4.19 JSON), so no prefill can shadow a combination (BUILD_RULES 24) and there is no  
  NOT_EXISTS-gated branch to kill (20b). Contrast AZ_AZDPS, where this flip is RULED OUT because  
  ImageIndicator sits in 2 set[]s and 'Y' kills DQN + DQP. All 10 combos already carried a  
  defaults[] entry, so this edits values and adds no keys.  
NO COLLISION on this provider: every initialValue='N' and every defaults value='N' in the build  
  script was already ImageIndicator's. Verified after: 0 sites left at 'N',  
  RelatedHitSearchIndicator still 'Y' at all its sites. (NJ_NJCJIS v4.16 was NOT like this --  
  RandomRequest shares both spellings there and a careless replace-all would have downgraded every  
  vehicle query to a random record. Check per provider.)  

## v4.19 -- 2026-08-06 -- DEX-1283: removed unneeded X default on Attention/EmailAddress

**CHANGED:** Removed initialValue='X' from the Attention (DH) and EmailAddress (DL+DH) hidden
  gate-feeders, and the matching combo defaults[] entries ($imgDefs EmailAddress; $imgDefsDH  
  Attention + EmailAddress). sourceField stays non-empty and both fields stay in their combos'  
  any[] -- those two remain required (ConnectCic rejects an empty sourceField[] at import;  
  the platform serializes only fired-combo set[]/any[] fields). Only the third, never-isolated  
  condition from RULE_HANDLERS.txt handler #13's 2026-06-22 finding (live-proven  
  HI_HCJDC_OFML v2.9) was removed.  
**REASON:** DEX-1283 reported Attention/EmailAddress showing "X" on USx forms. A scratch proof JSON
  (24 captures) and then this real rebuild (92/92 captures, all 5 entities) both show the  
  rule handlers (CommsysGetLastNameFirstNameInitialRuleHandler,  
  GetUserProfileSingleValueRuleHandler) resolve the real officer values unconditionally --  
  with nothing in the source field at all. The "X" a form snapshot shows is the raw  
  pre-handler value in dex-log's Query String column, not what reaches CommSys; removing the  
  default changes nothing on the wire and needed no CAD defaults[] fallback either. Lockstep  
  rebuild: TX_TLETS_CCH v1.15 applied the identical fix same day. See  
  knowledge-base/RULE_HANDLERS.txt handler #13 for the full evidence trail.  

## v4.18 -- 2026-07-30 -- Devdoc optionals x routing: 17 dropped optionals wired (commit b95bc364)

**CHANGED:** 17 devdoc-listed optionals that the officer could fill but that were transmitted
  NOWHERE were added to the any[] of the combos whose metadata variant defines them, across the  
  Vehicle/Person/Firearm/Article/Boat queries.  
**REASON:** Found by the then-new audit_devdoc_optionals gate -- a devdoc-legal fill fired a query
  but the optional rode in NO matching combo's set[]/any[], so it was silently dropped. Same  
  defect class as FL v7.13/v7.16.  
  NOTE (2026-08-03): this entry originally read "CHANGED: Rebuilt via pipeline.ps1 / REASON:  
  Scheduled rebuild", which understated a 17-field wire change. Recovered from the commit body.  
  Fifth instance of this class found today (FL had four) -- a pipeline rebuild stamps a generic  
  entry and, if nobody replaces it, the change becomes invisible to anyone reading BUILD_NOTES as  
  the source of truth.  

## v4.17 -- 2026-07-30 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.16 -- 2026-07-30 -- DH card mirrored to DL + entity-scoped NCIC test values

**CHANGED:** DH rows now match DL exactly -- ROW_PER_DHL1 6/6 (OLN + Purpose Code), ROW_PER_DHN1 6/6
  (First + Last), NEW ROW_PER_DHN1B 6/6 (MI + Suffix). DH had kept OLN on an 8/4 and all four  
  name fields on a 3/3/3/3. Both Person cards now read 6/6 x4 then the 4/4/4 options row.  
**REASON:** Rob -- applying DEX-1283 #4 to DL only was too literal; DH had the same uneven-field
  problem the ticket reported. Layout only, no QIDM/combo/wire change (query_trace unchanged).  
  Paired with entity-scoped test-value overrides ('<Entity>.fieldId=value', new) so NCICNumber  
  sends a valid per-file prefix: Article A123456789 / Firearm G123456789 / Boat B123456789.  
  v4.15 sent X123456789 for all three and the provider errored on every NCIC query -- 'X' is  
  not a valid NCIC file prefix, so those logs proved the field transmits, not that the query  
  resolves. Test-data change only; it does not itself bump the JSON.  

## v4.15 -- 2026-07-30 -- DEX-1283 #4 UI adjustments (Leo CAD review) -- layout + labels only

**CHANGED:** Person DL card rows restructured per the ticket: ROW_PER_L1 6/6 = OLN + CPL/DWI/RDL;
  ROW_PER_N1 6/6 = First + Last; NEW ROW_PER_N1B 6/6 = MI + Suffix; ROW_PER_N2 6/6 = DOB + Sex  
  (was OLN alone on a 12, then First/Last/MI/Suffix/messageKey crammed on a 3/3/2/2/2). messageKey  
  relabelled 'Message Key' -> 'CPL/DWI/RDL (optional)'; its LABEL-OVERRIDE removed since the '('  
  qualifier now satisfies verify_build CHECK 15 natively. Boat State label  
  'State (leave blank for TX)' -> bare 'State' (it was the only non-bare State label in the file).  
**REASON:** DEX-1283 #4, uneven fields wrapping in CAD. NO QIDM, combo, routing or wire change --
  query_trace still 21 built / 0 PREFILL-DEAD / 0 SHADOW / 0 MISSING; verify_build 16P/0F/0W.  
  Version bump archives the v4.14 93-log sweep; re-sweep owed (Rob: log collection is not a  
  burden, do the right fix). CCH v1.11 lockstep owed.  

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

