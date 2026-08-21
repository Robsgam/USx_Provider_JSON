# NM_NMLETS_OFML -- Changelog

Auto-generated from `NM_NMLETS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.6** | Generated: 2026-08-21

---

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

