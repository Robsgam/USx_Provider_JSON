# NM_NMLETS_OFML -- Changelog

Auto-generated from `NM_NMLETS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.7** | Generated: 2026-08-31

---

## v2.7 -- 2026-08-27 -- IN-STATE PLATE SEARCHES STOP DISCARDING THE PLATE TYPE AND YEAR THE OFFICER

                CAN SEE IN THE FORM  
**CHANGED** (Vehicle only -- Person, Firearm, Article and Boat are byte-identical):
  RQ.P -- the `conditions = [RegistrationState] EXISTS` gate REMOVED. This combination now  
    serves the plate search in BOTH directions. set[] and any[] are unchanged  
    (set[LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear], any[RegistrationState]),  
    so an out-of-state search transmits State exactly as it did at v2.6.  
  QV.P -- REMOVED (was set[LicensePlateNumber], any[], gated RegistrationState NOT_EXISTS).  
**REASON** -- THE DEFECT, stated as what the officer experienced:
  LicensePlateTypeCode and LicensePlateYear are PREFILLED on the form (PC / current year). On an  
  in-state plate search (State left blank, which the label explicitly invites -- "State (leave  
  blank for NM)") the State gate made RQ.P unreachable, so QV.P fired instead. QV.P is  
  set[LicensePlateNumber] with an EMPTY any[], so BOTH prefilled fields were SILENTLY DISCARDED.  
  They sat populated in front of the officer and never reached the wire. Nothing errored.  
WHY THE GATE WAS WRONG -- both authorities, neither ambiguous:  
  DEVDOC has exactly ONE plate combination and it is NOT split by state:  
    "#1 (In/Out) LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear,  
     [State, State2, State3, State4, State5]"   -- type and year MANDATORY, State OPTIONAL.  
  METADATA RQ{LicensePlateNumber} = Set[LicensePlateNumber, LicensePlateTypeCode,  
    LicensePlateYear] Any[FormORI, State, State2..State5]. State is in <Any>: an OPTIONAL, not a  
    FORK. Gating on a field the metadata merely permits is the documented anti-pattern --  
    TN_TIES KQ.N was gated `RegistrationState EXISTS` while its metadata had Any[State], which  
    made an in-state driver-history name search impossible.  
WHY QV.P COULD NOT SIMPLY BE REORDERED INSTEAD (structural, not a preference):  
  metadata QV{LicensePlateNumber} = Set[LicensePlateNumber] is a STRICT SUBSET of RQ{plate}, and  
  type/year are prefilled so they are ALWAYS present. Under first-match: RQ.P first leaves QV  
  unreachable; QV first steals every plate fill and kills RQ.P, which is this same defect with  
  the roles reversed and would drop type+year out of state too. The only way to keep both is to  
  un-prefill type/year so they can be ABSENT -- offered as option 2 of 3 and DECLINED (Rob  
  2026-08-27) because it cuts against the standing plate-defaults convention. Registered as  
  `VehicleRegistrationQuery | QV | LicensePlateNumber | dropped-combo`.  
NOT A DATA-MINED PROBLEM, and the first diagnosis said it was:  
  I reported that the in-state path had been built from a DATA-MINED transaction, citing  
  audit_data_mined's DM1 note. That was WRONG and Rob caught it ("i thought we established data  
  mined transactions from devdoc"). Verified against the raw XML: there is NO separate QV  
  transaction -- QV and RQ are both <Combination> nodes of the SINGLE VehicleRegistrationQuery  
  <Transaction>. DM1 matches the devdoc's mined list BY NAME and says in its own output that it  
  "exists to CLOSE the debate", not to report a gap. The keyRef never reaches the wire either  
  way. The real defect was combination SELECTION, not transaction choice. TN_TIES hit the same  
  naming confusion and renamed its QV.* keyRefs for it.  
SCOPE HELD DELIBERATELY: the VIN pair (RQ.V / QV.V) keeps its State fork. Devdoc #2 makes only  
  VehicleIdentificationNumber mandatory, so the in-state VIN path drops nothing devdoc-mandatory  
  and the gate never flagged it. Changing it would be scope creep on a released provider.  
GATES: validator 66P/0F/0W - reachability 11/11 all reachable (no dead combo created) - fidelity  
  13 branches / 0 UNDER / 0 OVER - devdoc combinations 0 FAIL - audit_devdoc_optionals  
  MANDATORY-NOT-TRANSMITTED finding CLEARED (this was the finding that started it) - wiring  
  closure 0 breaks - enforce 0 FAIL / 0 WARN.  
COST: archives the 36-log v2.6 package to logs/<Entity>/_archive_pre_v2.7/ (verified on disk, not  
  taken from reset_test_package's summary line, which is known to under-report). NM drops  
  ALL-PASS -> NEVER-TESTED and owes a re-import plus a full 5-entity re-sweep from T1. NM is on  
  its USx provider tenant ONLY -- no Foundation and no LIVE row, checked against ledger sections  
  B and C -- so no coordinated re-import is involved.  

## v2.6 -- 2026-08-21 -- DH PURPOSE CODE: moved up one line, and given the default it never had

**CHANGED** (both by operator directive, Rob 2026-08-21 on the rendered form):
  LAYOUT -- Purpose Code moved UP one line to the END of the DH qualifier row, eliminating  
    the lone third row it had been sitting on by itself. The card is now two rows:  
      ROW_PER_DH_1 [3 3 3 3]    First  Middle  Last  Suffix  
      ROW_PER_DH_2 [3 3 2 2 2]  OLN  DOB  Sex  Race  Purpose Code  
    Race stays immediately after Sex per the 2026-08-20 directive; Purpose Code goes AFTER  
    Race, so that ordering is preserved rather than disturbed. This also matches the DL card,  
    where Purpose Code is likewise the last field of the last qualifier row.  
  purposeCodeDH -- initialValue 'C' ADDED, plus the combo defaults[] twin on BOTH DH combos  
    (KQ.N and KQ.O).  
WHY IT HAD NO DEFAULT: no reason. Asked to explain it and could not -- it was an oversight  
  from v2.4/v2.5, not a decision, and nothing in the build recorded a justification.  
  THE ASYMMETRY IT LEFT: the DL side has purposeCode in set[] on BOTH combos, prefilled 'C',  
  with a defaults[] twin. The DH side had purposeCodeDH in any[] on both combos with NO prefill  
  and NO default. So a DL query transmitted PurposeCode=C while a DH query transmitted no  
  purpose code at all unless the officer typed one.  
WHY THE PREFILL IS SAFE HERE, checked before adding it rather than after:  
  BUILD_RULES 24 only bites when the prefilled field sits in a set[] -- an always-present value  
  then makes that combo always match and collapses it onto a plainer sibling. purposeCodeDH is  
  in NO set[] at all (any[] on KQ.N and KQ.O), so there is nothing for it to shadow.  
  audit_prefill_shadow confirms: 0 findings across 14 ordered pairs, and reachability holds at  
  12/12. Metadata agrees it is optional -- KQ{Name} and KQ{OperatorLicenseNumber} both carry  
  PurposeCode inside <Any>.  
  (Contrast the DL side, where the prefill IS on a set[] field and is safe for the different,  
  CA_CLETS reason: purposeCode is in EVERY DL combo's set[], so it cannot favour one over another.)  
WHY THE COMBO defaults[] TWIN IS NOT OPTIONAL: CAD ignores form initialValue (BUILD_RULES 12).  
  Without the twin a CAD-dispatched DH query would still have gone out with no PurposeCode --  
  the exact gap being closed. Added to both DH combos.  
GATES: validator 66P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | wiring closure 0 breaks  
  in all ten classes | name components 0 blocking / 8 examined | reachability 12/12 | prefill  
  shadow 0 (14 pairs) | fidelity 14 branches 0 UNDER / 0 OVER | test_phase2 PRE-FLIGHT CLEAR,  
  36 tests / 130 fills.  
LAYOUT FLOW still reports 1 finding and it is the RECORDED OPERATOR OVERRIDE, unchanged by this  
  edit: L9 raceCode on the DL card's ROW_PER_DL_3, beside BirthDate/SexCode/purposeCode. Rob  
  directed race onto line 3 after sex; it stays. Nothing on the DH card is flagged.  
NOT TESTED: never tenant-tested at any version. v2.5 was never imported or driven, so this bump  
  archived 0 logs. Owes an import, a first-ever sweep, and the one-time picklist capture.  

## v2.6 -- 2026-08-21 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.5 -- 2026-08-20 -- Name components pooled -- the officer's middle name will now reach the state

**CHANGED:** middle/suffix added to the any[] of both NAME combos, and only those:
    DL.NAME  any[RegistrationState,ImageIndicator,Attention]        -> +NameMiddle, NameSuffix  
    KQ.N     any[purposeCodeDH,raceCodeDH,RegistrationState]        -> +NameMiddleDH, NameSuffixDH  
  UNTOUCHED: DL.OLN and KQ.O -- OLN paths, where name plays no part.  
  any[] not set[]: optional qualifiers. In set[] a middle name becomes MANDATORY and a driver  
  without one could not be searched.  
**REASON:** v2.3 added the controls and composed them into each Name attribute, which moved
  audit_name_components from C1 NO-CONTROL to C3 NOT-IN-POOL -- and v2.4's notes recorded that as  
  "the documented C3 class whose impact is UNPROVEN". It is not benign: composed-but-unpooled means  
  the officer can type a middle name and it goes nowhere.  
  WHAT SETTLED IT: AZ_AZDPS pools its components and its AUTO-GENERATED `DQN_af_nameMiddle` /  
  `_af_nameSuffix` logs carry `DOE, JOHN A` and `DOE, JOHN JR` against a `DOE, JOHN` control.  
  POOLED IS WIRE-PROVEN. Whether unpooled also works is still unproven and no longer needs an  
  answer, because the pooled path is what ships. Same change applied to NJ_NJCJIS v4.17 (already  
  wire-proven on its re-sweep) and OH_LEADS v2.11 this same day.  
SELF-CLOSING: emit_test_plan emits one test per any[] field, so the v2.5 plan ALREADY contains the  
  proof tests -- verified on disk: NameMiddle, NameSuffix, NameMiddleDH, NameSuffixDH. Nothing  
  hand-written. NM's first sweep will prove or refute the wire.  
VERIFIED: name components 4 C3 -> 0 (8 examined, 0 C1 / 0 C2 / 0 C3) - wiring closure 0 breaks  
  across all ten classes - 12 combinations all reachable - requirement fidelity 14 branches HELD at  
  0 UNDER / 0 OVER (branches did not fall, so nothing was suppressed) - prefill shadow 14 pairs  
  0 FAIL - validator 66 PASS / 0 FAIL / 0 WARN.  
FOUR LABEL-OVERRIDE tags added for the bare "Middle Name"/"Suffix" labels, which only trip CHECK 15  
  Rule 3 BECAUSE the fields are now any[]-only -- i.e. the WARN is the fix working. Written ONE PER  
  LINE with ' -- ' on the same line: verify_build matches that pattern per line, and on OH_LEADS the  
  same day I wrote all six fieldIds on one line with the '--' wrapped, which registered NOTHING and  
  left all six WARNs standing through a rebuild.  
COST: zero test package -- NM has never been tenant-tested and never imported, so nothing was  
  archived. Still owed: an IMPORT of v2.5 and a picklist capture before the sweep.  

## v2.4 -- 2026-08-20 -- Operator cosmetic pass -- State to the top line, Race after Sex on both Person cards

**CHANGED** (dictated by Rob 2026-08-20: "move state to top line 2nd feild ... for person move race to
3rd line after sex and on dh 2nd line after sex"):  
  VEHICLE  ROW_VEH_1 [3,3,3,3] = Plate Number | STATE | Plate Type | Plate Year.  
           State was on its own third row; it is now the 2nd field on the top line.  
  DL       ROW_PER_DL_3 [3,3,3,3] = Date of Birth | Sex | RACE | Purpose Code.  
           Race moves up from the lone 4th row to sit immediately after Sex; the 4th row is gone.  
  DH       ROW_PER_DH_2 [3,3,3,3] = OLN | Date of Birth | Sex | RACE.  
           Purpose Code displaced to ROW_PER_DH_3 -- it is an optional any[] qualifier on both DH  
           combos, so it is the right field to move rather than an identifier.  
  BOAT     ROW_BOA_1 [4,4,4] = Hull ID | STATE | Registration Number.  ** MY EXTENSION, NOT  
           DICTATED ** -- the directive named no card, and State is the same routing field here  
           (EXISTS -> Nlets BQ.H/BQ.R, NOT_EXISTS -> NCIC QB.H/QB.R), so it was carried across for  
           uniformity. Say the word and it becomes [Hull, Registration, State]; see the trade-off  
           noted in the build script at ROW_BOA_1.  
**REASON:** operator directive. The State placement also happens to be defensible on its own terms --
on NM, RegistrationState is the field that decides WHICH NETWORK every vehicle and boat query hits,  
so the officer's first decision was previously the last thing on the card.  

## v2.3 -- 2026-08-20 -- LAYOUT COLLAPSED 13 cards -> 6, and the officer could not enter a middle name or suffix

**CHANGED:**
  - Vehicle 3 cards -> 1 ("VEHICLE SEARCH BY PLATE, OR BY VIN"). OPTIONS held a single shared  
    control (State); PLATE and VIN are the two identifier paths and now lead their own rows.  
  - Person 5 cards -> 2, the ONLY entity legitimately at two: DRIVER LICENSE + DRIVER HISTORY.  
    The DH-suffix fieldIds are a separate field pool and that separation IS the isolation  
    mechanism, so collapsing to one card would be wrong, not tidier.  
  - Boat 3 cards -> 1 ("BOAT SEARCH BY HULL ID, OR BY REGISTRATION NUMBER").  
  - Firearm/Article titles made path-carrying ("... BY SERIAL NUMBER", "... BY SERIAL NUMBER + TYPE").  
  - MIDDLE NAME + SUFFIX CONTROLS ADDED on BOTH name pools (NameMiddle/NameSuffix and  
    NameMiddleDH/NameSuffixDH), composed into each Name composite.  
  - Labels to canon: DH OLN control read "License Number" -> "OLN"; "(optional)" stripped from  
    Vehicle Make, Make, Caliber, Model, Race, Purpose Code; "Vehicle Year (Nlets registration  
    search)" -> "Vehicle Year". State KEEPS its routing hint -- that is the sanctioned location.  
**REASON:** two separate gates were reporting on this provider and neither had been acted on.
  audit_layout_flow: 6 findings -- L4 CARDS-NOT-COLLAPSED on Vehicle/Person/Boat, two L5  
  WASTED-WIDTH (Plate maxLen 10 and Boat RegistrationNumber maxLen 8 each alone on a full  
  12-column row), and an L9 RMS-ONLY-BESIDE-IDENTIFIER (raceCode shared a row with the mandatory  
  purposeCode, so an RMS-only field sat beside a state identifier and read as though it queried  
  the state). audit_name_components: 4 C1 NO-CONTROL -- Name.Middle and Name.Suffix on BOTH  
  DriverLicenseQuery and DriverHistoryQuery, i.e. the metadata defines them and the officer  
  COULD NOT ENTER THEM. Rob, 2026-08-20: "veh has 3 cards  person has 5 and boat has 3  reall  
  the process is to callapose them".  
**RESULT:** layout_flow 6 findings -> 0 (6 cards / 15 rows / 37 fields / 14 combinations compared,
  so not a vacuous pass). name_components 4 C1 -> 0 C1 / 0 C2, PASS on 8 components examined.  
  audit_wiring_closure 0 breaks across all ten classes -- the four new controls are not dead and  
  the Attention requirement is still fillable. validator 66 PASS / 0 FAIL / 0 WARN.  

## v2.2 -- 2026-08-18 -- DriverLicenseQuery was missing BOTH of its mandatory fields -- PurposeCode + Attention

**CHANGED:**
  - PurposeCode PROMOTED into set[] on BOTH DL combos (DL.NAME, DL.OLN) + a visible "Purpose Code"  
    Inp control prefilled 'C' + the CAD defaults[] twin on both combos.  
  - Attention wired to the standing auto-handler: attribute (size 30, sourceField Attention,  
    targetField Attention, rule CommsysGetLastNameFirstNameInitialRuleHandler) + any[] membership on  
    both DL combos + a HIDDEN feeder control, no prefill, no combo default. REGISTERED as  
    demoted-to-any on both combos.  
  - Labels owed on this provider's revisit turn: "License Number" -> "OLN" (DEX-1284) and  
    "Image (optional)" -> "NCIC Image". ROW_PER_OPT_1 widened 4/4/4 -> 3/3/3/3 for the new control.  
**REASON:** audit_requirement_fidelity reported FOUR severity-1 UNDER-REQUIRED findings --
  "DL.OLN UNDER-REQUIRED: PurposeCode (ABSENT); Attention (ABSENT)" and the same on DL.NAME.  
  ABSENT, not demoted: neither field was in set[] NOR any[], so the officer could not supply them at  
  all and every NM driver-licence query went out missing two fields its metadata makes mandatory.  

## v2.1 -- 2026-08-01 -- DH raceCodeDH form field -> attributeTypeId (AP #11 CommSys-direction fix)

**CHANGED:** DriverHistory race form field 'raceCodeDH' switched from codeTypeCategory='NIBRS_RACE'
         (code-string dropdown) to attributeTypeId='RACE'+codeTypeProvider='NIBRS', matching the  
         DL 'raceCode' field. The DH RaceCode CommSys attr has codeTypeProvider='NIBRS' (attr-ID  
         reverse-lookup); the code-string field fed it a bare code it couldn't resolve.  
**REASON:** Latent AP #11 (CommSys reverse-lookup direction) surfaced by the meta-audit 2026-07-24
         and caught by the new validate check. NM is untested, so no re-test cost. Still NOT  
         USx-tenant-tested; VERIFY the DH race filter on the wire at tenant test.  

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.0 -- 2026-05-07 -- Initial build -- 6 basic queries, 14 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

