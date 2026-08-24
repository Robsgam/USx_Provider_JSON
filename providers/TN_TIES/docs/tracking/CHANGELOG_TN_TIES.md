# TN_TIES -- Changelog

Auto-generated from `TN_TIES_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.5** | Generated: 2026-08-24

---

## v2.5 -- 2026-08-24 -- COSMETIC PASS (Rob's directive) -- and it exposed three vehicle searches that

                could never have been driven  
**CHANGED**, all as directed:
  VEHICLE -- specialty plates (Dealer/Handicap/Temp) moved UP to row 2; VIN group down to row 3.  
    Plate Number STAYS on row 1 with Plate Type + Plate Year because RQ.P requires all three;  
    splitting them would scatter one combo's own mandatory fields across rows.  
  PERSON DL -- shared-context row promoted to position 2 (State / NCIC Image / Stolen Check /  
    Inquiry Type), names to 3, DOB group to 4. Expanded Name Search JOINS the DOB row instead of  
    sitting alone on a [6] row, so the card is 4 rows not 5; widths 4/4/4 -> 3/3/3/3, still 12.  
    Its "(optional)" dropped.  
  INQUIRY TYPE -- bare label everywhere (helper "(1/2/3, optional)" removed on Vehicle, Person  
    DL and Boat) + initialValue 3.  
  DH PURPOSE CODE -- combo defaults[] PurposeCode=C on KQ.N/KQ.O, and NO form initialValue.  
ROB RULED ON THE ONE THING THAT COULD HAVE BROKEN ROUTING, and it was measured first:  
  purposeCodeDH is in the set[] of KQ.N and KQ.O, while DQ05 is set[OperatorLicenseNumberDH]  
    ALONE. A form prefill makes a field always-present, so it would have collapsed KQ.O onto  
    DQ05 and killed the in-state DH-by-OLN path -- BUILD_RULES 24, the mechanism that killed  
    AZ DQPN/DQP. Presented as a three-way choice; Rob chose CAD-default-only. Routing untouched,  
    DQ05 alive, and reachability confirms it: 19 combinations, ALL reachable.  
  InquiryTypeIndicator by contrast is in the any[] of all 13 carrying combos and in NO set[], so  
    prefilling it cannot shadow anything. That asymmetry is why one got a form default and the  
    other did not.  
  A build-script ASSERTION now enforces the distinction instead of a comment asking for care:  
    Add-ComboDefault throws if asked to default a set[] field without an explicit -AllowInSet.  
CAD DEFAULT TWINS done as a LOOP, not 15 hand-edits (BUILD_RULES 12 -- CAD ignores form  
  initialValue): 5 Vehicle + 4 DL + 4 Boat for InquiryTypeIndicator, 2 DH for PurposeCode = 15,  
  asserted. A hand-kept list of 13 keyRefs is precisely what falls behind its own array.  
  NOTE the namespace trap inside it: set[]/any[] hold FORM fieldIds, defaults[].field holds the  
  QIDM ATTRIBUTE name. Identical for InquiryTypeIndicator, DIFFERENT for the DH field  
  (purposeCodeDH vs PurposeCode) -- matching the wrong one silently touches zero combos.  

## v2.4 -- 2026-08-24 -- keyRefs renamed off the DATA-MINED transactions, and the redundant dealer pair

                collapsed -- both were the SAME misconception  
**CHANGED:**
  (a) QV.P -> RQ01 (in-state plate, devdoc #1) and QV.V -> RQ03 (VIN, devdoc #3). The kept combos  
      now carry the metadata names for the paths they implement.  
  (b) The two dealer combos COLLAPSED to one ungated RQ05. v2.3 had RQ05 gated  
      `RegistrationState EXISTS` and QV.D gated NOT_EXISTS with IDENTICAL set[] and IDENTICAL  
      any[], and State in NEITHER -- so both emitted BYTE-IDENTICAL requests. Devdoc #4 is  
      "(In) DealerLicensePlateNumber, [InquiryTypeIndicator]" with no (Out) counterpart, so an  
      out-of-state dealer path was never a devdoc path. Ungated now matches RQ06/RQ07, which are  
      single and ungated for the same reason.  
**REASON** -- ONE ROOT CAUSE BEHIND BOTH: the belief that a keyRef selects a DESTINATION. v2.3's own
  code comment said it outright -- "the officer's State selects the destination rather than riding  
  the request" -- and the same belief produced a note carried in FOUR places claiming in-state TN  
  plate searches "reach NCIC not TIES/DMV", filed as needing Rob's ruling. THE KEYREF NEVER  
  REACHES THE WIRE: a request carries <MessageType>VehicleRegistrationQuery</MessageType> plus the  
  FIELDS and nothing else (verified against a real capture -- the keyRef appears ZERO times).  
  Rob 2026-08-24: "we only send the VehicleRegistrationQuery and not the transaction name."  
  And `QV` is one of the DATA-MINED transactions the devdoc names on its own line ("NCIC (QA, QB,  
  QG, QV, QW) and DMV ... Tags returned from Data mining") -- TIES runs it off our single request,  
  so naming an OUTGOING combo after it invited precisely the wrong reading. `InquiryTypeIndicator`  
  (default 3 = registration AND hotfiles) is why one query covers both.  
ZERO WIRE IMPACT FROM (a) -- a keyRef is platform-internal. (b) REMOVES one duplicate request:  
  the dealer pair would have produced a guaranteed audit_log_inflation attack-A clone group on  
  every sweep, and doubled the dealer tests for no coverage.  
ALSO CLEARED: [FLAG:plan-dedupe-vacuous-tests] -- this rebuild regenerates the plan.  
DOCS CORRECTED IN THE SAME PASS, because a stale justification is how this recurs: the  
  ACCEPTED_DIVERGENCES shadow table had "kept QV.P / kept QV.V" (now inverted, with the QV twins  
  recorded as dropped-mined); its "Net effect" paragraph claimed blank-State "routes to the NCIC  
  national keyRefs" (rewritten -- the State choice selects which FIELD SET is sent, not a  
  destination); and the RQ05 `routing-only-not-transmitted` row is RETIRED with history, because  
  the wiring-closure class J finding it adjudicated cannot fire once the State gate is gone. The  
  rule that row stated is still binding: State must NOT go into RQ05's any[] -- no dealer variant  
  defines it, so that would OVER-PERMIT.  
GUARDRAIL SO IT CANNOT RECUR: tools\audit_data_mined.ps1 (new 2026-08-24) reads the devdoc's  
  Data-Mined line -- which audit_supported_queries had only ever used as a parse BOUNDARY, so  
  nothing had read it -- and build_phase1 prints it as step 5b immediately after the query-trace  
  MISSING list, which is where the wrong conclusion gets drawn. usx-metadata Step 2b carries both  
  facts for whoever reads the authorities next.  
I CHECKED THE OTHER SIBLING PAIRS RATHER THAN ONLY FIXING THE ONE I NOTICED, and the Boat pairs  
  are LEGITIMATE -- keep them. BB.H/QB.H and BB.R/QB.R share a set[] just like the dealer pair did,  
  but BB carries `RegistrationState` in its any[] and QB does not (metadata: BB{hull} has  
  Any[InquiryTypeIndicator, State], QB{hull} has Any[InquiryTypeIndicator] only). So filling State  
  produces a genuinely DIFFERENT wire. That is the precise test: not "do the set[]s match" but  
  "can any fill make the two requests differ". Dealer failed it (State in NEITHER pool); Boat  
  passes it. Plate/VIN differ in set[] outright.  
THE RENAME STOPS AT VEHICLE, AND NOT ARBITRARILY: Article/QA and Firearm/QG are the ONLY keyRefs  
  their transactions define in the metadata, and Boat's blank-State paths have only QB. There is  
  no non-mined alternative to move to, so renaming them would mean INVENTING a keyRef for cosmetic  
  reasons. Vehicle was the one entity where metadata already offered non-mined names (RQ01/RQ03/  
  RQ05) for the same field sets. audit_data_mined DM1 therefore still annotates 4 combos on TN  
  (Article/QA, Boat/QB.H, Boat/QB.R, Firearm/QG) -- down from 7 -- and that residue is CORRECT.  
MEASURED v2.3 -> v2.4: Vehicle combos 8 -> 7 - total combos 22 -> 21 - plan 55 -> 54 - validator  
  74P/0F/0W -> 73P/0F/0W (one fewer combo to score) - reachability 20/20 -> 19/19 all reachable -  
  fidelity 28 branches / 0 UNDER / 0 OVER (HELD, so nothing was suppressed) - wiring closure  
  1 break -> 0 (the registered class J on RQ05 is gone because its State gate is gone) -  
  audit_data_mined DM1 7 -> 4, DM2 0, DM3 1 - zero QV.* combos or plan tests remain.  
NOT TESTED YET: never tenant-tested. Owes an import and a first-ever sweep.  
STATED OBJECTIVE OF THAT SWEEP -- CORRECTED 2026-08-24 BY ROB, and my first version was wrong:  
  "we want logs that show the xml message and verify that uit matches the metadata specs."  
  So: a saved log per plan test carrying the COMMSYS XML of the outgoing request, and gate 6d  
  (audit_log_metadata) green on every one of them -- every <Request> field metadata-defined for  
  that query, and the present field-set satisfying a real metadata combination's set[]. That is  
  the thing this package exists to prove, for all 21 combinations.  
  WHAT I WRONGLY WROTE HERE FIRST: "does a mined NCIC hit render?" That is a RESPONSE-side  
  question. It needs a real hit record in the tenant, which we do not control, and no amount of  
  REQUEST capture can settle it -- so it was not an objective a sweep could ever deliver.  
  audit_data_mined class DM3 records that the QRDM's hit/RelatedSearchHitIndicator mapping is  
  unexercised; that is a COVERAGE STATEMENT about the response mapping, not sweep work.  

## v2.3 -- 2026-08-20 -- LAYOUT COLLAPSE 14->6 CARDS + NAME COMPONENTS; RQ05 COMMENT CORRECTED

**CHANGED:**
  LAYOUT -- 14 cards -> 6, the uniform shape (usx-cosmetic Step 3b). Vehicle 4->1  
    (OPTIONS/PLATE/VIN/SPECIALTY merged, so all five vehicle identifiers -- plate, VIN,  
    dealer, handicap placard, temp plate -- sit on one card with the shared State +  
    Inquiry Type row last), Person 5->2 (DL + DH, the DH-suffix pool being the isolation  
    mechanism), Firearm 1, Article 1, Boat 3->1. Titles ALL-CAPS and path-carrying.  
    'License Number' -> 'OLN' on both pools; 'Image (Y/N)' -> canonical 'NCIC Image'.  
    State keeps its routing hint on all three carrying entities -- TN forks in-state vs  
    Nlets on State presence, so the lean-label pass does not apply to it.  
  NAME COMPONENTS -- 4 new controls (NameMiddle/NameSuffix on the DL pool,  
    NameMiddleDH/NameSuffixDH on the DH pool), each composed into its pool's Name  
    FormatStringRuleHandler sourceField (Last,First,Middle,Suffix) with the separator list  
    grown @(', ') -> @(', ', ' ', ' ') per AP #15, and POOLED into the any[] of all THREE  
    name combinations (the OOS DL name combo, the in-state DL name combo, and KQ.N on the  
    DH side). Pool membership is what puts a component on the wire -- AZ_AZDPS is the  
    wire-PROVEN precedent (DOE, JOHN A JR). audit_name_components: 4 C1 -> 0.  
  RQ05 CODE COMMENT CORRECTED (no JSON change from this part): it read "OOS dealer plate  
    (Nlets)". The devdoc's Possible Combinations list for VehicleRegistrationQuery reads  
    "4. (In) DealerLicensePlateNumber, [InquiryTypeIndicator]" and has NO (Out) dealer  
    entry, so QV.D (gated State NOT_EXISTS) is the combo that serves the devdoc path.  
    RQ05 is a SECOND metadata variant whose requirements are IDENTICAL to QV.D's -- both  
    Set[DealerLicensePlateNumber, Any[InquiryTypeIndicator]] -- so no fill can distinguish  
    them and the State-existence gate is the only thing keeping RQ05 reachable at all.  
KNOWN AND REGISTERED -- audit_wiring_closure class J, 1 break, EXPECTED:  
  "EXISTS 'RegistrationState' gates RQ05 but is in NEITHER its set[] NOR any[]". True as  
  stated. Both candidate fixes are worse than the finding: adding State to RQ05's any[]  
  OVER-PERMITS (neither dealer variant defines a State field), and removing the gate makes  
  RQ05 and QV.D an exact collision that kills one devdoc-authorized query. So the officer's  
  State selects the destination on this path and is not transmitted. Registered 2026-08-19  
  (rule 'routing-only-not-transmitted'); class J does not consult the registry, so the line  
  keeps printing -- that is expected, not a regression, and it does not block enforce.  
RESOLVED 2026-08-24 -- THIS NOTE WAS WRONG AND IT SENT A READER (Rob) LOOKING FOR A DEFECT THAT  
  CANNOT EXIST. It read: "metadata RQ01{LicensePlateNumber} ... is NOT BUILT -- the build serves the  
  blank-State plate case with QV.P instead. Whether an in-state TN plate search should reach the  
  TIES/DMV transaction rather than the NCIC one is a routing question for Rob."  
  THE KEYREF NEVER REACHES THE WIRE. A captured request carries  
  <MessageType>VehicleRegistrationQuery</MessageType> plus the fields, and ZERO occurrences of the  
  keyRef -- verified against a real AZ_AZDPS capture. Rob, 2026-08-24: "we only send the  
  VehicleRegistrationQuery and not the transaction name." So QV.P and RQ01 emit BYTE-IDENTICAL  
  requests; nothing in the request can express "route to NCIC instead of DMV", and the question the  
  note asked has no mechanism behind it.  
  THREE INDEPENDENT CONFIRMATIONS: (1) RQ01{plate}, RV01{plate} and QV{plate} all have  
  set[]=[LicensePlateNumber], so they are routing-INDISTINGUISHABLE -- no fill separates them;  
  (2) TN_TIES_ACCEPTED_DIVERGENCES.txt ALREADY recorded exactly this, "RQ01 ... == QV.P -> DROPPED  
  (kept QV.P)", so the note re-opened a decision this build had already made and written down;  
  (3) audit_devdoc_combinations PASSes with 14 devdoc combinations compared / 0 FAIL, and  
  audit_query_trace reports 0 vehicle MISSING (its 2 MISSING are KQ on Driver History).  
  AND QV IS A DATA-MINED TRANSACTION, which is the part the note missed entirely. Devdoc line 9:  
  "Data-Mined Transactions: NCIC (QA, QB, QG, QV, QW) and DMV (Person and Vehicle) Tags returned  
  from Data mining". QV is not an alternative destination we pick -- TIES runs it and returns its  
  tags mined into the response. InquiryTypeIndicator (O, default 3 = "Registration and hotfiles  
  check") is why ONE VehicleRegistrationQuery covers both, and why building no separate  
  stolen-vehicle query is correct here. It is wired in any[] on 6 of 8 vehicle combos; the two  
  without it (RQ06 handicap, RQ07 temporary) are correct -- the devdoc marks both "No hot files  
  check conducted" and the metadata gives them no <Any>.  
  WHAT IS ACTUALLY LEFT, and it is cosmetic: the keyRefs QV.P / QV.V / QV.D are named after a  
  DATA-MINED NCIC transaction, which is what made a correct build read as a defect. Rename them to  
  the metadata in-state names at the next build -- zero wire impact, and free while TN is  
  never-tested.  
  STILL GENUINELY UNVERIFIED (different question, do not conflate): TN's QRDM carries the shared  
  `hit` / `RelatedSearchHitIndicator` mapping, so mined-tag consumption is CONFIG-PRESENT but has  
  never been exercised -- TN has no logs. Same class as HI's unverified NCIC hit block. Make "does  
  a mined NCIC hit render?" a stated objective of TN's first sweep.  
GATES: validator 74P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 8 examined | layout flow 0 findings | wiring closure 1 break (the registered  
  class J above) | reachability 20/20 | prefill shadow 0 (47 pairs) | fidelity 28 branches  
  0 UNDER / 0 OVER | test_phase2 PRE-FLIGHT CLEAR, 55 test(s) / 174 fill(s) -- which also  
  resolves the [FLAG:plan-fillability-unfireable-tests] finding of 4 BLANK + 4 UNSATISFIED.  
NOT TESTED: never tenant-tested. Owes an import and a first-ever sweep.  

## v2.3 -- 2026-08-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.2 -- 2026-08-19 -- FREE-TEXT stolen check -> coded Y/N; 4 unfireable specialty-plate tests fixed; 0F/0W

**CHANGED:**
  - relatedHitSearchIndicator converted from a FREE-TEXT FormInput to a coded FormSelect  
    (YES_NO_UNKNOWN | NCIC), label "Related Hit Search (optional)" -> canonical "Stolen Check",  
    initialValue 'Y', plus the CAD defaults[] twin on all three carrying combos (QWA, DQ01, DQ06).  
    A '# LABEL-OVERRIDE:' tag records the bare label, the same mechanism OH_LEADS uses.  
  - NEW docs/reference/TEST_VALUE_OVERRIDES.txt with DealerLicensePlateNumber, HandicapPlacardNumber  
    and TemporaryLicensePlateNumber.  
  - REGISTERED VehicleRegistrationQuery | RQ05 | RegistrationState | routing-only-not-transmitted.  
  - Two flags retired: [FLAG:plan-fillability-unfireable-tests] and  
    [FLAG:wiring-closure-class-J-routing-only].  

## v2.1 -- 2026-08-01 -- KQ.N -- an in-state driver-history name search was IMPOSSIBLE (commit e3e40c53)

**CHANGED:** Removed the RegistrationState EXISTS gate from KQ.N, plus four DQ.N registrations.
**REASON:** KQ.N was gated RegistrationState EXISTS while metadata KQ{Name} has State in <Any> --
  optional, not a fork -- and there was no other name combo to fall through to, so an IN-STATE  
  driver-history name search could not be performed at all. THE RULE: a State gate belongs only  
  where the metadata FORKS BY state, never on a variant that merely permits State as an optional.  
  Recovered 2026-08-03 from commit e3e40c53; this entry read "Rebuilt via pipeline.ps1 /  
  Scheduled rebuild".  

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + PlateType/PlateYear defaults


## v1.0 -- 2026-05-06 -- Initial build -- 6 basic queries, 28 combos


## v1.4 -- 2026-05-11 -- LIMITATION elimination pass

