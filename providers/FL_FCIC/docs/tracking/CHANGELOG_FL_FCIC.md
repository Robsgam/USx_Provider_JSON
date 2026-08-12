# FL_FCIC -- Changelog

Auto-generated from `FL_FCIC_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v7.22** | Generated: 2026-08-12

---

## v7.22 -- 2026-08-12 -- Boat Stolen Check defaults to 'Y' (Rob's directive) + BQ ordered ahead of QB

WHY: Rob 2026-08-12, after being shown the cost twice: "Default it to Y anyway."  
I HAD BEEN REFUSING THIS FOR TWO VERSIONS AND MY STATED REASON WAS PARTLY WRONG. v7.20's note and  
  the v7.20/v7.21 Jira drafts said defaulting it would kill "the ordinary Boat registration search".  
  THE WIRE REFUTES THAT. Log FL_FCIC_v7.8_QBBoatHullIdNumber.txt sends  
  `<MessageType>BoatQuery</MessageType>` and the literal string 'QB' appears ZERO times in the  
  request. Message keys are NOT TRANSMITTED -- CLAUDE.md has always said "keyRef is platform-internal  
  only; provider does not validate it" -- and the metadata has ONE `<Transaction name="BoatQuery">`  
  holding FBQ, QB and BQ as `<Combination>` elements. So FBQ and QB are NOT two different searches;  
  they are two FIELD COMBINATIONS of the same transaction. Rob supplied the correction: "we only send  
  the transaction type and required and optional fields ... not the message keys."  
WHAT IS ACTUALLY LOST -- narrow, and this is the accurate statement:  
  (a) a hull/registration BoatQuery that OMITS the related-hit indicator, and  
  (b) carrying decalNumber/titleLienInformation alongside a hull search.  
  NOT the Florida registration lookup: FBQDecalNumber and FBQTitleLienInformation carry no relatedHit  
  condition and are untouched, and clearing the dropdown to blank reaches the other two.  
**CHANGED:**
  1. Boat form relatedHitSearchIndicator initialValue='Y' + combo defaults[] on the three QB combos  
     that hold it in any[] (CG/NCIC/PCN). The two QB combos holding it in set[] cannot be satisfied  
     by a default from CAD -- a defaults[] entry does not satisfy set[] for ROUTING -- so a  
     CAD-originated boat query still routes to FBQ. That is sensible CAD behaviour, noted not fixed.  
  2. BQ BLOCK MOVED AHEAD OF THE QB BLOCK. This is the part that mattered. The prefill made  
     relatedHitSearchIndicator always-present, so QB{Hull}/QB{Reg} matched on the identifier ALONE  
     and -- ordered first -- stole every Hull+State / Reg+State fill from BQ, killing the  
     out-of-state boat search. Applied Rob's own AZ_AZDPS ruling ("we do not leave out queries  
     because it is hard ... use ordering and recognize the shadows"). BQ requires RegistrationState  
     in set[] so it CANNOT steal an in-state query. MEASURED: reachability 4 dead -> 2 dead,  
     prefill-shadow 2 FAIL -> 0 FAIL (92 pairs). Both OOS combos recovered at zero cost.  
     DEPARTS from devdoc listing order (QB 5-9 before BQ 10-12) DELIBERATELY -- specificity is line 1  
     of the ordering rule and devdoc order is only the tiebreaker; the prefill put them in conflict.  
  3. FBQBoatHullIdNumber + FBQRegistrationNumber REGISTERED as `dead-combo` accepted divergences,  
     naming this decision and the corrected loss statement. Reachability now reports  
     `[PASS] 30 combination(s) checked -- all reachable (2 accepted dead-combo divergence(s))`.  
A FINDING I RAISED AND RETRACTED THE SAME HOUR -- worth keeping because the probe was seductive.  
  Rob said "qb should not be in the json. that is the auto mined stuff" and pointed at the devdoc  
  line, which is real and on page 1 of 16 of 20 devdocs:  
      Data-Mined Transactions:  NCIC (QA, QB, QG, QV, QW) and DMV (Person and Vehicle)  
  I then swept all 20 JSONs for built keyRefs matching those codes and reported 10 providers with  
  "data-mined transactions built" -- FL 12, TX 7, TX_CCH 10. THAT FINDING WAS ENTIRELY FALSE. It  
  matched on keyRef NAMES, which are internal labels with no wire meaning. Nothing is being built or  
  sent that shouldn't be; `MessageType` carries the devdoc-supported query name and CommSys mines  
  NCIC internally. The standing rule caught it exactly as written -- "a finding across MANY providers  
  is usually YOUR PROBE" -- but only after Rob supplied the mechanism. READ THE WIRE BEFORE SWEEPING  
  20 PROVIDERS. The QV/QW `not-built` registry rows are about not building those QUERIES as separate  
  QIDMs, which is a different statement from keyRef naming.  
GATES: validator 91P/0F/0W, reachability 30/30 (2 accepted), prefill-shadow 92 pairs 0 FAIL,  
  wiring closure closed 0/10, verify_build 0W/0F.  
OWED: re-import + full 116-test sweep. Nothing wire-verified.  

## v7.21 -- 2026-08-12 -- Firearm row re-order + NCIC Image defaults to 'Y' on all five entities

WHY: Rob 2026-08-12, verbatim: "on firearm move gun make under serial number and move ncic imgae on  
  teh first line to replace it boat atill has an undefaulted stolen check and ncic image should  
  default to y everywhere"  
**CHANGED:**
  1. FIREARM row re-order (layout only). Gun Make drops to the FIRST cell of row 2 so it sits  
     directly beneath Serial Number -- the identifier it qualifies -- and NCIC Image takes the row-1  
     slot it vacated. Row 1 = Serial Number / Stolen Check / NCIC Image (the three controls the  
     officer touches first); row 2 = Gun Make / NCIC Number / PCN. Still exactly 2 visible rows.  
  2. NCIC IMAGE now defaults to 'Y' EVERYWHERE on this provider: 3 form controls flipped  
     (Vehicle/Article/Boat; Firearm flipped in the row edit above; Person was already 'Y') AND all  
     25 combo `defaults[]` entries, because CAD ignores form initialValue and a form-only flip would  
     leave every CAD-originated query still asking 'N'. Emitted-JSON assertion: 5 form controls 'Y',  
     25 combo defaults 'Y', 0 non-'Y'.  
SAFE, AND MEASURED BEFORE APPLYING -- not inferred from the Stolen Check decision:  
     ImageIndicator on FL is in **0** `set[]` and **0** conditions across all 36 combinations, and  
     rides `any[]` on 25. So no prefill can move routing (BUILD_RULES 24 does not bite). Confirmed  
     after the fact too: reachability 30/30 reachable, prefill-shadow 92 pairs 0 FAIL -- both  
     identical to v7.20.  
     Also cleared the MANDATORY pre-test gate (the TX_TLETS T6 class): FL's devdoc contains NO  
     "must be filled if ImageIndicator = Y" conditional anywhere -- every occurrence of the field is  
     inside a bracketed OPTIONAL list -- so defaulting 'Y' cannot silently make another field  
     required. FL's METADATA_REFERENCE has no FIELD CONSTRAINTS section at all (0 matches).  
BUT THE PORTFOLIO CONVENTION IS THE OPPOSITE, AND ROB WAS TOLD SO. Measured across all 20 providers  
  (20 compared, not sampled): **every** provider that builds the control uses Person='Y' and  
  Vehicle/Firearm/Article/Boat='N' -- 18 of 20 carry a Person 'Y', and the count of non-person  
  controls set to 'Y' before this change was ZERO out of 20. This is the exact inverse of the Stolen  
  Check case, where FL and IL genuinely were the outliers and Rob's instruction corrected them. Here  
  FL was already conformant and this change makes it the only provider of 20 defaulting the  
  non-person image request. Applied because it is Rob's explicit call and it is measurably safe; the  
  other 19 are FLAGGED (`flag_pending_fix`) to pick it up at their OWN next rebuild rather than being  
  mass-rebuilt (rule 8c), so uniformity is restored forward instead of by a back-door sweep.  
BOAT STOLEN CHECK -- STILL BLANK, and the reason is now STRONGER than the v7.20 reachability proof.  
  Read FL's raw metadata `<Requirements>` per `<Combination>` for BoatQuery (the sanctioned raw-XML  
  exception). RelatedHitSearchIndicator appears in `<Any>` on **QB only** -- all five variants. On  
  **FBQ** (the Florida registration transaction, 4 variants) it is NOT DEFINED AT ALL, and neither is  
  it on **BQ** (out-of-state Nlets, 3 variants). The FL devdoc says the same thing independently:  
  BoatQuery combos 1-4 are `(In)` and bracket only [DecalNumber, RegistrationNumber, Requestor,  
  TitleLienInformation]; combos 5-9 `(In/Out)` bracket [ImageIndicator, RelatedHitSearchIndicator,  
  Requestor]. So on Boat the stolen check is NOT "an any[] we could default for free" -- it is the  
  field that SELECTS the NCIC stolen transaction instead of the FL registration one. Defaulting it  
  would not add a stolen check to the boat registration query; it would REPLACE that query. That is  
  why Firearm and Article can default it (there it is a true `any[]` add-on to the same transaction,  
  metadata-defined on all 3 QG and all 4 QA variants) and Boat cannot. Same field, same provider,  
  opposite answers -- decided by the firing combination's own variant, exactly as the registry  
  already records for RelatedHitSearchIndicator on Vehicle FRQ vs QV.  
OPEN FINDING, DELIBERATELY NOT FIXED IN THIS PASS -- Rob's ruling (see DEX_TICKET):  
  The same raw-XML read shows FL's **FBQ** `<Any>` does not define **ImageIndicator** either, yet all  
  four built FBQ combos carry it in `any[]` WITH a `defaults[]` entry -- so every in-state Boat  
  registration query transmits an ImageIndicator the transaction does not define (an OVER-PERMIT).  
  It is PRE-EXISTING (since v7.6), was tolerated on the wire (v7.18 was ALL-PASS 116/116 with these  
  combos sending 'N'), and `audit_requirement_fidelity` is silent on it BY DESIGN because  
  ImageIndicator sits on that gate's `$formOnly` whitelist -- so its "0 OVER-PERMITTED / 30 branches"  
  is a true statement about a question it does not ask. There is no registry row for it. This change  
  flips its transmitted value N -> Y, which does not create the over-permit but does change what an  
  undefined field carries, and whether FCIC ignores 'Y' as it ignored 'N' is UNKNOWN [Guessing].  
  Recommended fix if Rob wants it: drop ImageIndicator from the 4 FBQ combos' any[]/defaults[]  
  (metadata-correct, and the control stays live for QB on the same card). Not done unilaterally  
  because it is a wire change on a previously tenant-verified path.  
GATES: validator 91P/0F/0W, reachability 30/30, prefill-shadow 92 pairs 0F, wiring closure closed  
  0/10, audit_layout_flow 1 finding (the same PRE-EXISTING L2 as v7.20, denominator unchanged).  
OWED: re-import + full 116-test sweep. Nothing here is wire-verified -- Rob runs the sweep.  

## v7.20 -- 2026-08-12 -- Cosmetic/layout pass on Rob's rendered-form review -- 4 rows retired, 0 wire change

WHY: Rob 2026-08-12, verbatim: "here is what i wan t in fl n veh put vin seq next to decal on sam  
  eline and should all the fields on person ass state default of fl under dh and remove the label  
  helper firearm stiolen check on top line 2 lines only article serial and article type and oan on  
  top line combine th rest on line 2 boat fix stolen check to have default and move state stolen and  
  ncic image to scond line and move the others down one"  
**CHANGED** (layout + labels only -- no QIDM, no combination, no default value touched):
    Vehicle  vinSequenceNumber joins the Decal row (ROW_VEH_3 -> 3/3/3/3); ROW_VEH_VSN RETIRED.  
             It had been a lone 6-wide row for a 2-character field, below the hidden Requestor row.  
    Firearm  Stolen Check moved up to ROW_GUN_1 (4/4/4); ROW_GUN_RHS RETIRED -> 2 visible rows.  
    Article  ROW_ART_1 = Serial + Article Type + OAN (4/4/4); ROW_ART_2 = NCIC + PCN + Stolen Check  
             + NCIC Image (3/3/3/3); ROW_ART_3 and ROW_ART_RHS RETIRED -> 2 visible rows.  
    Boat     State + Stolen Check + NCIC Image moved from the BOTTOM row up to ROW_BOA_2, directly  
             under the identifier row; Decal/Title/NCIC/PCN and the owner-name row each shift down  
             one. Officer picks scope right after typing the identifier.  
    Person   DH State label 'State (required)' -> 'Destination State (required, not FL)'  
             (LABEL-OVERRIDE); ROW_DH1 cols 6/3/3 -> 5/4/3 so it fits without wrapping.  
             TWO PASSES, and the first was wrong: I shipped 'Destination State (not FL)', which  
             fixed the FL trap but dropped that the field is mandatory. Rob: "the lable need to be  
             clear required and not fl". Each half alone misleads -- "State (required)" invites the  
             one illegal pick, "(not FL)" alone hides that the query cannot fire without it. All  
             three facts now on the label: DESTINATION (whose state), REQUIRED, NOT FL.  
             Also fixed in the same pass: moving vinSequenceNumber dropped its '(optional)'  
             qualifier and raised a real verify_build CHECK 15 WARN. Resolved with a LABEL-OVERRIDE  
             matching VehicleMakeCode/vehicleYear on the row above, not by re-adding the helper --  
             its whole row is bare-labelled per DEX-1284. verify_build now 0 WARN / 0 FAIL.  
TWO OF ROB'S ITEMS WERE REFUSED BY THE SOURCES, AND BOTH WERE MEASURED, NOT ARGUED:  
  1. "state default of fl under dh" -- REFUSED BY FCIC ITSELF. FCIC wrote 2026-06-12 that KQ "can  
     only be used out of state and would require the destination to be something other than FL";  
     the devdoc lists both KQ combos as (Out) with State unbracketed. An FL default would prefill  
     the ONE value the query cannot carry. Contrast AZ, whose DH is (In/Out) and so DOES default it  
     (AZ v3.11) -- same field, opposite answer, decided by each provider's own scope. The  
     "(required)" helper Rob wanted gone was replaced rather than deleted, because with no default  
     the control is the officer's only choice point and a bare "State" understates the constraint.  
  2. "boat fix stolen check to have default" -- REFUSED BY MEASUREMENT. Injected initialValue='Y'  
     into a replica inside the provider dir (all 3 layout variants, asserted present in the  
     REPARSED JSON) and ran the two owning gates. Same denominator as the clean baseline  
     (30 combinations checked / 92 ordered pairs), so the verdict change is the mutation alone:  
       clean   -> [PASS] 30 combination(s) checked -- all reachable / [PASS] no prefill-caused shadow  
       mutant  -> [FAIL] 4 dead combination(s) of 30 checked  
                  [FAIL] DEAD COMBO (self-unsatisfiable): BoatQuery/FBQBoatHullIdNumber  
                  [FAIL] DEAD COMBO (self-unsatisfiable): BoatQuery/FBQRegistrationNumber  
                  [FAIL] DEAD COMBO: BoatQuery/BQBoatHullIdNumber  
                  [FAIL] DEAD COMBO: BoatQuery/BQRegistrationNumber  
                  [FAIL] 'QBBoatHullIdNumber' SHADOWS 'BQBoatHullIdNumber' only because of  
                         prefill(s): relatedHitSearchIndicator   (+ the RegistrationNumber pair)  
     I predicted 2 dead combos; it is 4. On Boat this field IS the discriminator, gated BOTH ways  
     (EXISTS on QB where it also sits in set[]; NOT_EXISTS on FBQ), so a default turns FBQ's gate  
     permanently false AND lets QB eat BQ. BUILD_RULES 24. Blank is load-bearing on Boat only.  
STALE COMMENT CORRECTED: ROW_DH2 claimed 'nameMiddleDH added visible-only, mirrors DL card's unwired  
  nameMiddle/nameSuffix'. Measured against the emitted JSON: FL builds NO middle-name and NO suffix  
  input control anywhere. `nameMiddle` occurs exactly twice and BOTH are response-side  
  (QUERYRESULTDATAMAPPING); `nameSuffix`/`nameMiddleDH` occur zero times. So the dead-control class  
  Rob flagged on AZ does not exist on FL -- nothing to eliminate.  
GATES: validator 91P/0F/0W. audit_layout_flow 4 findings -> 1 (the three L3 HIDDEN-MID-CARD findings  
  cleared because retiring the trailing rows put the hidden Requestor rows at the bottom, where they  
  belong); denominator unchanged at 56 fields / 30 combinations, rows 26 -> 22. The 1 remaining  
  finding (L2, Vehicle RegistrationState after VehicleMakeCode on RQVehicleIdentificationNumber) is  
  PRE-EXISTING -- verified by running the gate against the v7.19 artifact from git, not assumed.  
  audit_wiring_closure closed, 0 breaks in all ten classes. prefill-shadow 92 pairs 0 FAIL.  
OWED: re-import + full 116-test sweep. v7.19's 20 Vehicle logs were archived by the version bump.  

## v7.19 -- 2026-08-12 -- Stolen Check defaults to 'Y' on Firearm + Article (Boat deliberately excluded)

WHY: Rob 2026-08-12 -- "if the stolen check is an any it makes sense to use a default of yes to get  
  the most out of every query ... previoulsy i stated to use defaults everywhere where it made sense  
  and didn't ruin in state default routing." FL was one of two providers not following that rule.  
MEASURED FIRST, across the 8 tenant-tested providers: HI (Article/Boat/Firearm), NY  
  (Article/Firearm) and TX (Article/Boat/Firearm) all default their stolen-hit indicator to 'Y' AND  
  carry the matching combo defaults[]. FL and IL were the only two leaving it blank. So this was  
  never a style question -- FL was the outlier.  
**CHANGED**, form + CAD twin together (a form initialValue alone is HALF a default, because CAD ignores
  form initialValue and would send no stolen check at all):  
    Firearm  form initialValue='Y'  + defaults[] on QGGunSerialNumber, QGNCICNumber,  
                                      QGProcessControlNumber  
    Article  form initialValue='Y'  + defaults[] on QAArticleSerialNumber, QAOwnerAppliedNumber,  
                                      QANCICNumber, QAProcessControlNumber  
  Safe on both: relatedHitSearchIndicator is any[]-ONLY on all seven of those combinations and  
  carries NO condition there, so it cannot shadow a path.  
BOAT DELIBERATELY NOT CHANGED -- and this is the load-bearing exception. On Boat the SAME field IS  
  the routing discriminator, gated BOTH ways: relatedHitSearchIndicator EXISTS on QB Hull/Reg (where  
  it also sits in set[]) and NOT_EXISTS on FBQ Hull/Reg. A default makes it permanently present,  
  which turns FBQ's NOT_EXISTS gate permanently FALSE and kills the ordinary Boat registration  
  search outright. BUILD_RULES 24. Do not "make Boat consistent" -- blank is the design.  
A TOOL BUG THIS EXPOSED, fixed in the same pass: audit_prefill_shadow built its prefilled-field map  
  GLOBALLY by fieldId, with no entity scoping. FL carries relatedHitSearchIndicator on Firearm,  
  Article AND Boat, so defaulting the first two made the audit believe Boat's control was prefilled  
  too and it raised two false FAILs ('QB shadows BQ'). A form initialValue lives on ONE QIF; each  
  entity has its own control instance. Now scoped per targetEntity. Verified: 20/20 providers 0 FAIL  
  with non-zero denominators, and LAW 2 re-proven -- a real SAME-entity shadow (AZ ImageIndicator)  
  still FAILs, so only the cross-entity false positive went away.  
GATES: validator 91P/0F/0W, prefill-shadow 92 pairs 0 FAIL, combo reachability 30 checked ALL  
  reachable, audit_cad 83P/0F/0W.  
COST: the bump archived the v7.18 package (116 logs). Re-import + full re-sweep owed.  
**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.18 -- 2026-08-06 -- DEX-1283: removed unneeded X default on Attention/Requestor

**CHANGED:** Removed initialValue='X' from the Attention (DH) and Requestor (VehReg, DH, Gun,
  Article, Boat -- 6 hidden feeders total) hidden gate-feeders, and the matching combo  
  defaults[] entries (Attention on KQName/KQOLN; Requestor's defaults-injection loop removed  
  entirely). sourceField stays non-empty and both fields stay in their combos' any[] -- those  
  two remain required (ConnectCic rejects an empty sourceField[] at import; the platform  
  serializes only fired-combo set[]/any[] fields).  
**REASON:** DEX-1283 (TX ticket, applying the same finding here per Rob's ordered revisit: FL, NY,
  CA_CLETS, HI). The rule handlers (CommsysGetLastNameFirstNameInitialRuleHandler on both  
  fields) resolve the real signed-in officer's name unconditionally -- proven on TX_TLETS v4.19  
  (92/92 captures with nothing in the source field at all) and on a disposable scratch build  
  before that. The "X" a form snapshot shows is the raw pre-handler value in dex-log's Query  
  String column, not what CommSys receives. Removing the default changes nothing on the wire.  
  See knowledge-base/RULE_HANDLERS.txt handler #13 for the full evidence trail. Accepts the  
  full re-sweep cost (116 ALL-PASS logs archived, all 5 entities restart from T1) -- same  
  trade-off Rob already accepted for the Requestor rollout itself (v7.15).  

## v7.17 -- 2026-08-03 -- Remove 3 dead officer controls from Person (commit 56b8b7ca)

**CHANGED:** Deleted the visible-but-unwired nameMiddle, nameSuffix and nameMiddleDH controls
  from the Person cards. No QIDM change, no wire change, no combo count change.  
**REASON:** audit_wiring_closure class A (dead control). Every Name attribute on this provider
  sources only [NameLast, NameFirst], so a middle name or suffix an officer typed was  
  silently DISCARDED -- on DL, DH and Boat alike. Rob's call was remove, not wire: removing  
  costs no match quality (nothing was ever transmitted) and stops the form implying a  
  precision it never delivered. nameMiddleDH had been added at v7.11 during a label pass  
  explicitly as "visible-only, NOT wired"; the later removal call is better-informed.  
  TENANT-VERIFIED v7.17 2026-08-03: Person swept 21/21, no middle/suffix field on any wire.  

## v7.16 -- 2026-08-02 -- RelatedHitSearchIndicator on Gun+Article, VINSequenceNumber on FRQ{VIN}

**CHANGED:** RelatedHitSearchIndicator added to the GunQuery and ArticleSingleQuery combos'
  any[]; VINSequenceNumber added to FRQVehicleIdentificationNumber any[] ONLY.  
**REASON:** Dropped devdoc optionals -- the officer could set them and they were transmitted
  nowhere. VINSequenceNumber is scoped to FRQ{VIN} because that is the only metadata  
  variant whose <Any> defines it; adding it elsewhere would OVER-PERMIT.  
  TENANT-VERIFIED v7.17 2026-08-03: RelatedHitSearchIndicator=Y confirmed on the wire in  
  both Firearm (15/15) and Article (16/16) sweeps.  

## v7.15 -- 2026-08-02 -- Wire Requestor onto the 5 Basic queries that permit it

**CHANGED:** Requestor added to the any[] of every combo whose metadata variant defines it,
  across all 5 Basic queries, with an 'X' combo default so CAD-dispatched queries carry it.  
**REASON:** emit_test_plan_spec UNREACHABLE -- Requestor was a devdoc optional on 26
  combinations with NO form control at all, so it could never be sent. This is the fix  
  that closed it.  
  TENANT-VERIFIED v7.17 2026-08-03: Requestor=SGAMBELLONE R present on the wire in all  
  116 logs across all 5 entities (auto-populated by the handler, not typed).  

## v7.14 -- 2026-07-31 -- FRQ over-permit removal: VehicleMakeCode/vehicleYear off both FRQ branches

**CHANGED:** FRQLicensePlateNumber any[] and FRQVehicleIdentificationNumber any[] both had
  VehicleMakeCode and vehicleYear removed. Resulting arrays match the metadata FRQ branches  
  exactly -- plate: [LicensePlateYear, ImageIndicator, Requestor]; VIN: [ImageIndicator,  
  Requestor, vinSequenceNumber]. No form change, no routing change, no combo count change.  
  Both fields remain on the OOS RQ{VIN} combo, where the metadata DOES define them.  
**REASON:** audit_requirement_fidelity OVER-PERMITTED. Metadata FRQ defines
  any[LicensePlateYear, Requestor, ImageIndicator] on the plate branch and  
  any[Requestor, VINSequenceNumber, ImageIndicator] on the VIN branch -- VehicleMakeCode and  
  VehicleYear appear in NEITHER, and the FL devdoc 'Possible Combinations' lines do not list  
  them either. So the never-drop-a-devdoc-OPTIONAL rule did not apply (no devdoc optional to  
  preserve) and these were genuine out-of-spec over-sends. Fixed at source in commit 7b13a67c.  
  NOTE (2026-08-03): this entry originally read 'Rebuilt via pipeline.ps1 / Scheduled rebuild',  
  which understated a real requirement change. The FL_FCIC_ACCEPTED_DIVERGENCES.txt row that  
  had parked this as 'promoted-to-any-UNJUSTIFIED-NEEDS-RULING -- Rob's call' (2026-07-30) was  
  left in place after the fix landed, so for four days a CLOSED item read as an open decision  
  blocking FL testing. Row removed 2026-08-03; this entry corrected in the same pass.  

## v7.13 -- 2026-07-30 -- Dropped-optional fix: RegistrationNumber on the FBQ hull path

**CHANGED:** FBQBoatHullIdNumber any[] += RegistrationNumber (and the sibling FBQ combo at the
same any[] shape). No form change, no routing change.  
**REASON:** enforce 2q FAILed on 5 devdoc-optional subsets -- BoatQuery #1/#2 +[RegistrationNumber]
fired FBQBoatHullIdNumber, but RegistrationNumber was in NO matching combo set[]/any[], so an  
officer entering a hull AND a registration number lost the reg number SILENTLY. Same class as  
TX_TLETS 17 dropped devdoc optionals. DETERMINATE, no product ruling needed: metadata FBQ  
set[BoatHullIdNumber] already lists any[DecalNumber, RegistrationNumber, Requestor,  
TitleLienInformation], so riding it satisfies BOTH metadata (field authority) and the standing  
rule never to DROP a devdoc-optional combination field.  
NOT CHANGED, deliberately: devdoc VehicleRegistrationQuery #3 (TitleLienInformation) stays  
UNBUILT -- Gordon Hallof sunset that path at v7.4 ("Remove Title/Lien info all together"). The  
enforce 2p FAIL was BOOKKEEPING: it had been recorded under keyRef FRQTitleLienInformation with  
rule not-built, which 2p does not accept for devdoc coverage. Re-filed as (devdoc #3) /  
devdoc-combo-unbuilt. Rebuilding that combo would reinstate a path a stakeholder killed -- the  
TX QV error class. Do not "fix" it.  
**RESULT:** all 5 entities re-test from T1; v7.12 111 logs archived by the bump.

## v7.12 -- 2026-07-30 -- Entity display-order change (direct Rob feedback)

**CHANGED:** Default entity display order Person-first -> Vehicle-first:
  @('Person','Vehicle','Firearm','Article','Boat') -> @('Vehicle','Person','Firearm','Article',  
  'Boat'). The default variant now matches CAD_DISPATCH/FIRST_RESPONDER (both already Vehicle-first).  
**REASON:** Rob -- "shift the order of the entities, have veh first then person." Order-array-only,
  no QIF/QIDM/combo/routing/field/label change; every per-entity fingerprint is byte-identical to  
  v7.11 so the CommSys wire for all 5 entities is unchanged. Still a version bump -> full  
  test-package reset (block by version). The v7.11 Vehicle captures (24 PASS, both log gates  
  green) archived to logs/Vehicle/_archive_pre_v7.12/ + stashed; re-capture at v7.12 expected  
  identical.  

## v7.11 -- 2026-07-28 -- UI/label-review pass (direct Rob feedback, NO functional change)

**CHANGED:** Four cosmetic label fixes surfaced reviewing the rendered v7.10 form before its tenant
  sweep:  
  (1) Boat card title "BOAT SEARCH" (the only card missing its query paths) ->  
    "BOAT SEARCH BY HULL ID, \"OR\" REGISTRATION NUMBER, \"OR\" COAST GUARD DOC #, \"OR\" NCIC  
    NUMBER, \"OR\" PCN" (matches the Firearm/Article enumerated-path title style).  
  (2) Person DH BirthDate label "DOB" -> "Date of Birth" (unifies with the DL card; pure  
    cosmetic, same FormDate). DH "MI" DELIBERATELY KEPT -- nameMiddleDH is a genuine 1-char  
    middle-initial field (maxLen=1) vs DL's full nameMiddle (maxLen=30); "MI" is accurate,  
    "Middle Name" would misrepresent it.  
  (3) Vehicle lean-strip: VIN "(or search by Plate)" dropped (set[]-required; card title carries  
    the path); Vehicle Make/Year "(By VIN optional)" dropped -> bare (any[]-only, LABEL-OVERRIDE  
    tags added; matches the NY/TX DEX-1284 lean convention Vehicle had not yet received).  
  (4) Person DH State "State" -> "State (required)" -- DH is OOS-only so State is a mandatory  
    destination (set[] in both KQ combos), NOT the "leave blank for FL" in/out toggle.  
**REASON:** Rob's UI/label review of v7.10 before the FL tenant sweep. Label-only, no combo/QIDM/
  routing/fieldId/default change. ALL 5 ENTITIES stay RESET (already reset at v7.10, never  
  captured) -- re-test from T1.  

## v7.10 -- 2026-07-27 -- UPPERCASE card titles (Rob global decision, NO functional change)

**CHANGED:** All card titles UPPERCASED, wording unchanged (e.g. "Driver License Search by OLN,
  \"OR\" Name" -> all-caps; "Boat Search" -> "BOAT SEARCH"). Mechanical uppercase transform;  
  no wording/field/combo/QIDM change. New global convention (BUILD_RULES Section 11).  
**REASON:** Rob -- "everything needs to be upper case." Title-only. verify_build clean. ALL 5
  ENTITIES RESET at v7.10 (block by version). NOT yet re-tested.  

## v7.9 -- 2026-07-27 -- DEX-1284 relabel/naming-convention pass (direct Rob feedback, NO functional change)

**CHANGED:** Applied the NY/TX portfolio conventions:
  - OLN: OperatorLicenseNumber (DL "License Number (or search by Name + DOB)") +  
    OperatorLicenseNumberDH ("Driver License Number") -> "OLN"  
  - canonical bare "NCIC Image" on every image field (Vehicle/DL/Gun/Article/Boat) -- was  
    "NCIC Image - if available" / DL "Image (optional)". Overrides the prior FL-only  
    "- if available" wording (now superseded by the global DEX-1284 convention).  
  - Boat stolen toggle "Y for NCIC stolen-boat check" -> "Stolen Check" (LABEL-OVERRIDE: any[])  
  - DL card title "Driver License" -> "Driver License Search by OLN, \"OR\" Name"  
  - lean cross-reference strips: DL BirthDate/Sex drop "(required with Name)" (both set[]-required  
    on the Name combo); Gun Make drops "(incl w/Serial Num only - optional)" -> bare  
    (LABEL-OVERRIDE: any[]); Article Serial/OAN drop "(with Article Type)"; Boat Reg drops  
    "(or use Hull ID)".  
  - DL layout unchanged: Rob confirmed OLN + State + NCIC Image stay on the top row (mirrors FL's  
    own DH top row OLN+State+PurposeCode + the NY model; NOT the TX OLN-alone form -- FL carries  
    State/Image on the DL card, TX had them on a separate OPTIONS card).  
**REASON:** DEX-1284 portfolio relabel. FL predated the OLN/NCIC-Image/Stolen-Check conventions even
  though it originated many other patterns. Shadow-query review: FL is the in/out-gating reference  
  (existence-only State/OLN/Hull gates already complete) -- nothing to remove. Label/title-only,  
  no combo/QIDM/routing/fieldId/default change. verify_build 16P/0W/0F (LABEL-OVERRIDE tags on  
  GunMake + relatedHitSearchIndicator). ALL 5 ENTITIES RESET for re-test at v7.9 (block by version).  
  NOT yet re-tested at v7.9.  

## v7.8 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.7 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.6 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.5 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.4 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.3 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.2 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.1 -- 2026-06-30 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v7.0 -- 2026-06-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.9 -- 2026-06-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.8 -- 2026-06-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.7 -- 2026-06-25 -- NJ/HI-parity galvanization (drop import-breaking version field; versioned filename)

**CHANGED:** Structural/cosmetic galvanization to match the NJ v4.6 / HI v4.3 standard. (1) Removed
  the top-level "version" field (v6.6 had adopted it) -- the platform deserializes it as  
  java.lang.Integer and rejects the dotted string, so v6.6 was unimportable. Now omitted by the  
  patched Write-ProviderJson. (2) Root JSON now versioned: FL_FCIC_v6.7.json (was bare  
  FL_FCIC.json); stale sibling removed by Write-ProviderJson. (3) Version stamped into all 3  
  bundle descriptions (ENTITIES/PROVIDER/RMS) via -Description on Build-EntitiesBundle and  
  Build-RmsBundle (PROVIDER bundle was already versioned). (4) Per-provider CHANGELOG_FL_FCIC.md  
  generated. No QIF/QIDM/combo/conditions change -- query behavior and entity fingerprints are  
  identical to v6.6.  
**REASON:** FL reopened (DEX-971) for re-import; v6.6 carried the import-breaking top-level version
  field. Bring FL to NJ/HI parity (versioned filename, version-in-all-bundles, auto changelog)  
  and make it importable again. FL already had the rest of the NJ/HI suite (identifier-priority  
  guardrails v6.0, native PascalCase v5.2, VehicleMakeName QRDM VehicleType/VEHICLE v6.6,  
  Last-first comma-space Name v6.1) -- no behavior changes needed.  
**RESULT:** Importable v6.7; structural only. Per the full-retest mandate, all 5 entities re-opened
  for a full live re-test from Test 1 (re-import + re-validate). HI-specific fixes NOT applied  
  (QVP/QVV removal, Make-field removal, First->Last name order -- all N/A to FL).  

## v6.6 -- 2026-06-24 -- Adopt version field + VehicleMakeName QRDM fix (shared-module currency)

**CHANGED:** Native rebuild on current shared modules. (1) Top-level "version":"6.6" now
  emitted by Write-ProviderJson. (2) VehicleMakeName QRDM attribute codeType corrected  
  from NCIC_FIREARM_MAKE/NJ_NIBRS (firearm-make table -- wrong) to VehicleType/VEHICLE,  
  matching the 2026-06-24 _build_rms_bundle.ps1 fix. Query/combo behavior unchanged  
  (entity fingerprints identical); only results-mapping make resolution + the version  
  field differ.  
**REASON:** Reproducibility audit (audit_reproducible.ps1) found the committed v6.5 JSON was
  DETERMINISTIC but STALE -- it predated the 2026-06-24 shared-module fixes. Rebuilt to  
  bring the committed JSON back in sync with a fresh build.  

## v6.5 -- 2026-06-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.4 -- 2026-06-23 -- FBQ Boat conditions casing fix (verify_build CHECK 13)

**CHANGED:** FBQBoatHullIdNumber and FBQRegistrationNumber conditions[].field changed from
  @('RelatedHitSearchIndicator') (attribute name, PascalCase) to @('relatedHitSearchIndicator')  
  (form fieldId, camelCase). Casing mismatch made the NOT_EXISTS gate silently inert: when an  
  officer entered Hull ID + Stolen=Y with no State, FBQ fired alongside QB (union over-send).  
  Fix makes the gate live; FBQ now exits the pool when stolen indicator is filled.  
**REASON:** Caught by new verify_build.ps1 CHECK 13 (conditions[].field must reference QIF fieldId).
  Boat entity re-opened for live re-test.  

## v6.3 -- 2026-06-23 -- Label consistency

**CHANGED:** (1) Hull ID Number field hint removed (redundant with label).
  (2) "OOS" -> "out-of-state" on Boat BQ owner field labels.  
**REASON:** Post-v6.0 label consistency pass.

## v6.2 -- 2026-06-23 -- DH DOB label qualifier

**CHANGED:** DOB field label on DH card -> "DOB (required with Name)". Platform does not render
  helperText, so the conditional-required qualifier must be in the label itself.  
**REASON:** Usability audit -- DH DOB conditional requirement was invisible without helperText.

## v6.1 -- 2026-06-23 -- Name separator normalization

**CHANGED:** FormatStringRuleHandler separator for DL+DH Name (NameLast+NameFirst) changed to
  ', ' (comma-space). Wire now emits <Name>Doe, John</Name> per ConnectCIC devdoc. Order was  
  already Last-first (correct since v4.x); only the comma-space separator needed fixing.  
**REASON:** ConnectCIC devdoc "LAST, FIRST MIDDLE SUFFIX" format -- comma-space between Last and First.

## v6.0 -- 2026-06-23 -- Identifier-priority rollout + inert conditions fix + Attention handler

**CHANGED:** (1) Plate>VIN guardrail: LicensePlateNumber NOT_EXISTS added to FRQVehicleIdentificationNumber
  and RQVehicleIdentificationNumber. When Plate entered, VIN combos exit the union pool.  
  (2) Boat Hull>Reg guardrail: BoatHullIdNumber NOT_EXISTS added to FBQRegistrationNumber  
  (in-state FBQ family only; QB+BQ companion combos are dual-id, exempt).  
  (3) INERT STATE FIX: all conditions[].field @('State') -> @('RegistrationState') in every  
  FRQ/FDQ/FBQ combo (10 places). 'State' was the QIDM attribute name, not the form sourceField --  
  all those gates were silently inert (live-proven HI v3.3). With fix, FRQ/FDQ/FBQ conditions  
  are LIVE routing gates. ROUTING CHANGE -- full re-test of all primary paths required.  
  (4) ATTENTION auto-populate RESTORED: 'Attention' added to DH KQName+KQOperatorLicenseNumber  
  any[]; hidden gate-feeder InpH 'Attention' initialValue=X added to DH card. Uses HI v2.9  
  live-proven pattern (handler emits officer LastName FirstInitial from RMS profile).  
  (5) DL/DH OLN>Name guardrail already correct (no change needed).  
  (6) Labels: required/optional indicators; DH card retitled "Driver History (Out-of-State Only)".  
  (7) Officer guide regenerated (single-page portrait table format).  
**REASON:** Identifier-priority rollout (HI done; FL next). Inert conditions hazard resolved.
  Re-import + full re-test from T1.  

## v5.5 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.4 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.3 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.2 -- 2026-06-18 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.1 -- 2026-06-15 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.0 -- 2026-06-15 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.9 -- 2026-06-12 -- DH + Boat destination state: blank 2-char FormInput (kills inert FL guard)

**CHANGED:** 1) DH card: registrationStateDH FormSelect (attributeTypeId=STATE) -> blank
            FormInput maxLen=2, label "Destination State (2-letter, not FL)". Officer  
            must type the literal 2-letter destination code.  
         2) Boat Options card: registrationState same change, label "Destination State  
            (2-letter, blank for FL)".  
         3) DH QIDM + Boat QIDM State attributes: codeTypeProvider='NCIC' REMOVED  
            (FormInput supplies the literal code directly -- no UUID reverse-lookup).  
         4) Vehicle + Person-DL State fields UNCHANGED (NCIC dropdown pattern): their  
            conditions are presence-based NOT_EXISTS only, unaffected by the inert rule  
            (4 live PASSes v4.8).  
**REASON:**  LIVE FAIL (v4.8, 2026-06-12): DH KQOperatorLicenseNumber with Destination=
         Florida SENT despite NOT_EQUALS FL guard. INERT-CONDITION RULE (QIDM_REFERENCE  
         Sec 2a): conditions evaluate the RAW pre-reverse-lookup value; the live form-  
         state capture showed registrationStateDH="Florida" (display label, not the  
         2-letter code; XML still serialized State=FL), so EQUALS/NOT_EQUALS never see  
         the code the guard names.  
         A FormInput carries the literal value the officer typed, so NOT_EQUALS FL is  
         evaluated against a real 2-letter code. Boat BQ combos carry the same  
         NOT_EQUALS FL guards and the same dropdown -- fixed in the same pass.  
         CAUTION: guard comparison is presumed case-sensitive -- a lowercase "fl" may  
         slip past NOT_EQUALS 'FL'. Verify in live testing; if it slips, add an  
         uppercase rule handler or accept as LIMITATION.  

## v4.8 -- 2026-06-12 -- Conditions migrated to live-proven format (v4.7 conditions were inert)

**CHANGED:** ALL conditions (DL FDQ/DQ, DH KQ, Vehicle FRQ, Boat FBQ/QB/BQ) migrated from
         combo-level camelCase-fieldId scalar style to the CA_CLETS/NY live-proven wire  
         format: nested INSIDE requirements, field = ["AttributeName"], value = ["..."]:  
           "requirements": { "set": [...], "any": [...],  
             "conditions": [ { "field": ["State"], "operator": "NOT_EQUALS", "value": ["FL"] } ] }  
         Field references changed to QIDM attribute names (State, OperatorLicenseNumber,  
         RelatedHitSearchIndicator). test_commsys + run_test_matrix condition resolution  
         updated to attribute-name-first precedence. No combo/set/any/order changes.  
**REASON:**  LIVE EVIDENCE (v4.7 imported to USx Tenant 2026-06-12, first DL test): full DL
         card produced XML containing OLN + Name + DOB + Sex + Image -- the v4.7  
         NOT_EXISTS conditions had NO effect (neither routing nor pool filtering).  
         Test log: tests/_archive_pre_v4.8/2026-06-12_Person_DL-FullCard_FAIL_*.txt.  
         v4.7 conditions sat at COMBO level (sibling of requirements) with camelCase  
         fieldIds and scalar values -- a format never live-verified. The platform reads  
         conditions from requirements.conditions (CA_CLETS production JSON has 20 such  
         conditions, live-tested NOT_EQUALS State routing; NY DALHOUT/DALLOUT same).  
         IMPLICATION: FL v4.6's QB combo-level conditions (Stolen EQUALS Y) were  
         likely ALSO inert -- the Stolen=N fall-through was never live-tested. Now  
         migrated and must be live-verified.  
         CAUTION: NOT_EXISTS is KB-documented server-side but not yet live-proven by  
         any provider (CA uses EQUALS/NOT_EQUALS only). v4.8 live test must explicitly  
         verify it: full DL card -> expect OLN+Image only. If NOT_EXISTS turns out  
         unsupported, the devdoc-order + pool-isolation design needs a rethink (escalate  
         to platform team before inventing workarounds).  

## v4.7 -- 2026-06-12 -- DH out-of-state-only correction, devdoc combo order, pool isolation, BQ restore

**CHANGED:** 1) DriverHistoryQuery: registrationStateDH moved any[]->set[] on both KQ combos;
            conditions registrationStateDH NOT_EQUALS FL added to both; combos reordered  
            to devdoc order (KQName first); operatorLicenseNumberDH NOT_EXISTS added to  
            KQName; combo state property In/Out -> Out; NO initialValue, NO CAD defaults  
            on State. DH card title 'Driver History' -> 'Driver History (Out-of-State Only)';  
            registrationStateDH label 'State (leave blank for FL)' -> 'Destination State';  
            operatorLicenseNumberDH label 'License Number (DH)' -> 'OLN (DH)'.  
         2) DriverLicenseQuery: combos reordered to devdoc order (FDQName, FDQOLN, DQName,  
            DQOLN); conditions registrationState NOT_EXISTS on both FDQ combos;  
            operatorLicenseNumber NOT_EXISTS on both Name combos.  
         3) VehicleRegistrationQuery: combos reordered to devdoc order (FRQ Decal/Plate/  
            Title/VIN, then RQ Plate/VIN); conditions registrationState NOT_EXISTS on all  
            four FRQ combos.  
         4) BoatQuery: combos reordered to devdoc order (FBQ 1-4, QB 5-9, BQ 10-12);  
            conditions registrationState NOT_EXISTS on all FBQ combos, plus  
            relatedHitSearchIndicator NOT_EQUALS Y on FBQ Hull/Reg (replaces the v4.6  
            QB-first ordering; QB EQUALS Y conditions unchanged). RESTORED BQ x3  
            (BQName, BQBoatHullIdNumber, BQRegistrationNumber -- removed v4.4 in error)  
            with registrationState in set[] and NOT_EQUALS FL conditions; restored Boat  
            form fields nameLast/nameFirst/birthDate (search card, owner OOS row) and  
            registrationState ('Destination State' on Options card); restored Boat QIDM  
            attributes Name (FormatStringRuleHandler), BirthDate (date handler), State (NCIC).  
         5) Gun + Article combos already match devdoc order -- unchanged.  
         CommSys combos: 28 -> 31. QIDMs: 6 (unchanged).  
**REASON:**  a) FCIC documentation (relayed 2026-06-12): "Since the KQ is out of state and
            <XX> which denotes the destination is required, yes DriverHistoryQuery can  
            only be used out of state and would require the destination to be something  
            other than FL." Devdoc: State is the only Mandatory field; both KQ combos (Out).  
            The v3.8 initialValue=FL design was invalid (FL is not a legal destination);  
            the v4.3 single-JSON merge silently dropped that initialValue (undocumented  
            regression) which left State omittable entirely -- v4.6 KQ test XML shipped  
            with no State element. Destination must be an explicit officer choice: set[],  
            no default. CAD-dispatched DH cannot supply a destination and will not  
            auto-fire -- correct behavior.  
         b) USER DIRECTIVE (new standard): combo array order follows the devdoc  
            "Possible Combinations" listing order in every QIDM. Because devdoc lists  
            in-state combos first, routing conditions (State NOT_EXISTS / RelatedHit  
            NOT_EQUALS Y / OLN NOT_EXISTS) keep later OOS/stolen combos reachable under  
            first-match evaluation AND isolate the serialization pool (LIMITATION #1) so  
            a fully-filled card sends only the firing path's fields (fixes DL over-send).  
         c) BQ restore: devdoc Boat "Possible Combinations" 10-12 ARE the BQ paths and BQ  
            is not in the data-mined list. The v4.4 removal cited a devdoc "key list  
            (FBQ + QB only)" that does not exist -- the devdoc contains no key mnemonics  
            (zero occurrences of FBQ/BQ/KQ/FDQ/RQ/DQ); metadata MessageKey definitions  
            are the only key source, and combos are the build authority.  
         ASSUMPTION: BQ destination state NOT_EQUALS FL mirrors the FCIC KQ rule  
            (Out-routed Nlets). Pending FCIC confirmation; guard trivially removable.  
         PENDING: QV x2 (devdoc Vehicle combos 5-6) NOT built -- QV is in the devdoc  
            "Data-Mined Transactions" list (QA, QB, QG, QV, QW), believed to be CommSys  
            auto-sent secondary queries (QW precedent: platform-confirmed auto-send,  
            v4.2). Awaiting platform confirmation; if refuted, build QV via Stolen Search  
            toggle (Boat QB pattern) in v4.8.  
         APPROVED SKIP: ImageQuery is in devdoc Basic Queries Supported but excluded by  
            user PHASE 2 scope (6-query build).  
         NOTE: conditions in this build use camelCase fieldIds + scalar values (FL  
            live-tested style, QB v4.6), not KB attribute-name style.  

## v4.6 -- 2026-06-09 -- Boat QB conditions routing (Stolen Search EQUALS Y)

**CHANGED:** Added conditions on QB+Hull and QB+Reg combos:
         relatedHitSearchIndicator EQUALS Y. Stolen Search = N or blank  
         now falls through to FBQ (registration) instead of firing QB (stolen).  
**REASON:**  Without conditions, selecting "N" from the Stolen Search dropdown
         still fired QB because the platform treats any populated value as  
         meeting set[] requirements. Conditions check the actual value.  

## v4.5 -- 2026-05-27 -- Boat Stolen Search field type fix

**CHANGED:** relatedHitSearchIndicator on Boat OPTIONS card changed from FormInput
         (officer typed "Y") to FormSelect dropdown (YES_NO_UNKNOWN/NCIC = Y/N).  
         No initialValue — field is routing toggle between FBQ (registration) and  
         QB (stolen) combos. Label changed from "Stolen Search (Y)" to "Stolen Search".  
**REASON:**  Cross-provider consistency. All other providers (TX, NY) use FormSelect for
         this field. FormInput required officer to know to type "Y".  

## v4.4 -- 2026-05-27 -- Remove unauthorized queries (VehicleStolenQuery + BQ combos)

**CHANGED:** Removed FL_FCIC_VehicleStolenQuery QIDM and its 6 combos (QV by plate/VIN/PCN/NCIC#/OAN/PartSerial).
         Removed 3 BQ combos from BoatQuery (BQName, BQBoatHullIdNumber, BQRegistrationNumber).  
         Removed Vehicle form fields: ncicNumber, processControlNumber, ownerAppliedNumber, partSerialNumber.  
         Removed Boat form fields: nameLast, nameFirst, birthDate, registrationState.  
         Provider bundle: 9 configs (was 10). CommSys combos: 28 (was 37). QIDMs: 6 (was 7).  
**REASON:**  VehicleStolenQuery not in devdoc "Basic Queries Supported". QV key listed under
         VehicleRegistrationQuery, not as a separate query. BQ (Nlets OOS Boat) not in devdoc  
         key list (FBQ + QB only). Devdoc is the ONLY authority for which queries to build;  
         metadata existence does not equal authorization.  
VALIDATOR: 87P/0F/0W  
TEST CONDUCTOR: 28/28 PASS  

## v4.3 -- 2026-05-21 -- Single-JSON merge

**CHANGED:** Merged BASE/MC into single build: build_fl_fcic.ps1 → FL_FCIC.json (no suffix).
         Deleted old BASE build script. Reports now in docs/ (not docs/mc/).  
**REASON:**  BASE/MC split doubled maintenance; single-JSON is the standard.
VALIDATOR: 101P/0F/0W  
TEST CONDUCTOR: 47/47 PASS  

## v4.2 -- 2026-05-19 -- Remove WantedPersonQuery (QW) QIDM

**CHANGED:** Removed FL_FCIC_WantedPersonQuery QIDM and its 2 combos (QWOperatorLicenseNumber, QWName).
         Provider bundle: 10 configs (was 11). CommSys combos: 33 (was 35). QIDMs: 7 (was 8).  
**REASON:**  CommSys auto-sends QW query; no JSON-side QIDM needed. Confirmed by platform team.
VALIDATOR: BASE 97P/0F/0W | MC 97P/0F/0W  
TEST CONDUCTOR: BASE 43/43 PASS | MC 43/43 PASS  

## v4.1 -- 2026-05-15 -- MC multi-card: Vehicle (2 cards) + Boat (2 cards) + State label fix

**CHANGED:** MC Vehicle split into 2 cards: Options(State,Image) + Vehicle Search(all search fields).
         MC Boat split into 2 cards: Options(State,Stolen,Image) + Boat Search(all search fields).  
         MC Options cards titled "Options". State field labeled "State (leave blank for FL)".  
         BASE: removed "State (leave blank for FL)" label on Vehicle and Boat, now just "State".  
         QIDMs unchanged (35 combos, 8 QIDMs).  
**REASON:**  BASE single-card allows officers to accidentally route in-state queries (FRQ/FBQ)
         through OOS paths (RQ/BQ) by filling State. MC physically isolates State on a separate  
         Options card, preventing accidental routing. Multi-card is the standard build model.  
         Person was already 2-card (DL+DH) since v3.8. Vehicle and Boat were never split.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v4.0 -- 2026-05-13 -- Attention field: handler-only to visible FormInput (attentionDH)

**CHANGED:** Removed CommsysGetLastNameFirstNameInitialRuleHandler from DH Attention attribute.
         Changed sourceField from 'Attention'/'AttentionDH' to 'attentionDH'/'AttentionDH' (DH-suffix).  
         Added attentionDH/AttentionDH FormInput (maxLen=30) to Person DH card/section (BASE+MC).  
         Attention is now a user-editable field, not a server-side automation.  
**REASON:**  Field was automated without user approval. User directive: expose all fields as visible
         and only automate after live testing reveals need. Handler was filling with logged-in  
         user's name ("LASTNAME F") server-side — correct output but wrong design philosophy.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.9 -- 2026-05-12 -- MC Person layout: merge Search Options into DL card (2 cards)

**CHANGED:** Removed CARD_OPTIONS. Moved RegistrationState + ImageIndicator into CARD_DL row 1.
         Person now has 2 cards: Driver License (State+Image+OLN+Name+DOB+Sex) and Driver History.  
**REASON:**  With RegistrationStateDH on the DH card (v3.8), the Search Options card only served DL.
         Separate card was confusing — officers didn't know which card's fields affected which query.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.8 -- 2026-05-12 -- RegistrationStateDH: isolate DH State from DL routing

**CHANGED:** Added RegistrationStateDH field (FormSelect, STATE, initialValue=FL) on DH card.
         DH QIDM State attribute sourceField changed from RegistrationState to RegistrationStateDH.  
         KQ combo set[] changed from RegistrationState to RegistrationStateDH.  
         DL State (RegistrationState on Search Options card) remains blank — no cross-contamination.  
**REASON:**  Shared State field confused officers: blank=correct for DL (FDQ), but DH requires State.
         Filling State for DH caused DL to route OOS (DQ) instead of in-state (FDQ).  
         DH-suffix pattern extended to State — consistent with all other DH fields.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.7 -- 2026-05-12 -- Person State label fix for DH reachability

**CHANGED:** Person State label from "State (leave blank for FL)" to "State" (BASE + MC).
**REASON:**  DH KQ combos require State in set[] — label told officers to leave it blank,
         making DH unreachable. Neutral label allows DL (blank=FDQ) and DH (filled=KQ).  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.6 -- 2026-05-12 -- Metadata audit: PurposeCode any[], FRQ/QV field alignment, no PurposeCode default

**CHANGED:** DH combos: PurposeCode moved from set[] to any[] (metadata says optional).
         FRQ Plate/VIN: added VehicleMakeCode, VehicleYear to any[].  
         QV VIN: added RegistrationState to any[].  
         Removed PurposeCode initialValue='C' from Person form (both BASE and MC).  
**REASON:**  Full metadata audit against FL_FCIC_METADATA_REFERENCE.txt. Combos were
         stricter than metadata requires. PurposeCode default removed per user request.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.5 -- 2026-05-12 -- One-directional queriesToDeselect fix + DH autoSelect

**CHANGED:** Removed queriesToDeselect from DL QIDM (was bidirectional with DH).
         Changed DH QIDM autoSelect from false to true (BASE only — MC already had true).  
**REASON:**  Bidirectional queriesToDeselect causes platform deadlock/error popup (confirmed NJ v2.3/v2.8,
         CA_CLETS v1.7). One-directional pattern: DL=default (autoSelect=true, no deselect),  
         DH=opt-in (autoSelect=true, deselects DL). Confirmed working on CA_CLETS v1.8 (18/18 PASS).  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v2.6 -- 2026-04-22 -- ATTENTION FIELD FIX -- match CA_eSUN / LA_LEMS pattern


## v3.0 -- 2026-05-01 -- COMPLETE REBUILD -- 8-QIDM merged architecture


## v3.1 -- 2026-05-07 -- Monorepo rebuild + Patch 8 + VehicleMakeCode fix


## v3.4 -- 2026-05-11 -- LIMITATION elimination pass

