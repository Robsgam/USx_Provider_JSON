# TN_TIES -- Changelog

Auto-generated from `TN_TIES_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.3** | Generated: 2026-08-24

---

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

