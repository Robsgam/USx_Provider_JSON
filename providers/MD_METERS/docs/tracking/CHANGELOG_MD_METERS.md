# MD_METERS -- Changelog

Auto-generated from `MD_METERS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.4** | Generated: 2026-08-31

---

## v2.4 -- 2026-08-31 -- STATE IS NOW THE DL IN/OUT DISCRIMINATOR -- it stops being silently discarded on

                the warrant name path, and two dead fills are recovered  
**CHANGED** (DriverLicenseQuery only; no other entity, no form change, no field added or removed):
  ZWAR.N -- ADDED condition `RegistrationState NOT_EXISTS`.  
  ZLDR.N -- REMOVED condition `raceCode NOT_EXISTS`.  (NO State condition added -- see below.)  
  ZLDR.O -- REMOVED condition `raceCode NOT_EXISTS`.  
  set[] / any[] / defaults[] / attributes / layout: ALL UNCHANGED on all 4 combos.  
**REASON** -- one authority fact drives all three edits:
  metadata ZWAR{Name} = Set[BirthDate, Name, RaceCode, SexCode] Any[ImageIndicator]  
    -- defines NO State field at all.  
  metadata ZLDR{Name} = Set[BirthDate, Name, SexCode]  Any[State, ImageIndicator, ...]  
  metadata ZWAR{OperatorLicenseNumber} = Set[Name, OperatorLicenseExpirationYear,  
    OperatorLicenseNumber, RaceCode, SexCode]  
  metadata ZLDR{OperatorLicenseNumber} = Set[OperatorLicenseNumber] Any[State, ImageIndicator]  
  So RaceCode is scoped BY THE METADATA to the two in-state warrant paths, and State to the two  
  ZLDR paths. The build had it backwards: raceCode was doing the discriminating and State was  
  doing nothing.  
  (1) THE DEFECT: at v2.3 an officer who filled Name+Sex+DOB+Race+State matched ZWAR.N -- whose  
      variant defines no State -- so the STATE THEY TYPED WAS SILENTLY DISCARDED. Same class as  
      the v2.3 plate type/year defect one version earlier, and as TN_TIES KQ.N.  
  (2) TWO DEAD FILLS, found by simulation and not by reading: `OLN + Race` matched NOTHING at  
      v2.3. ZWAR.O needs five fields so it could not take it, and `raceCode NOT_EXISTS` blocked  
      the only other OLN path -- officer types two valid identifiers, no query is sent.  
*** WHY ZLDR.N DID *NOT* GET `RegistrationState EXISTS` -- THE LITERAL FIX WAS SIMULATED AND  
    REJECTED. Read this before anyone "completes" the symmetry:  
  Adding it kills the plain in-state name search. Simulated on the v2.3 JSON in memory via the  
  canonical tools/_sim_helpers.ps1 Get-FiringKeyRef (the same first-match walk the platform  
  does): with `State EXISTS` on ZLDR.N, `Name+Sex+DOB` -> NOTHING FIRES, and `OLN+Race` stays  
  dead. That is the TN_TIES KQ.N defect verbatim. A State gate belongs ONLY where the metadata  
  FORKS by state; ZLDR{Name} carries State in <Any>, i.e. an OPTIONAL, so there is no fork to  
  gate on. Dropping the raceCode gate achieves the same routing with nothing dead.  
ROUTING, VERIFIED ON THE EMITTED v2.4 (not on intent) -- all 8 fills route, 0 dead:  
  Name+Sex+DOB            -> ZLDR.N     (plain in-state name search, ALIVE)  
  Name+Sex+DOB+Race       -> ZWAR.N     (in-state warrant; Race transmits)  
  Name+Sex+DOB+State      -> ZLDR.N     (State transmits -- was ZWAR.N, discarded)  
  Name+Sex+DOB+Race+State -> ZLDR.N     (State wins; Race dropped, SPEC-CORRECT: no ZLDR  
                                         variant defines RaceCode)  
  OLN only / OLN+Race / OLN+State -> ZLDR.O   (OLN+Race was DEAD at v2.3)  
  full warrant OLN fill   -> ZWAR.O     (unchanged; its set[] is a strict superset, ordered 1st)  
COST, stated plainly: this archives the v2.3 tenant package -- 46 ALL-PASS logs ->  
  logs/<Entity>/_archive_pre_v2.4/, 15 SQVR markers reset to [PENDING]. A full re-sweep is owed.  
  Rob's call, taken 2026-08-31 with that cost on the table.  
GATES: 71P/0F/0W. PHASE 1 steps 1-5b clean (15 branches 0 under / 0 over; 0 prefill-dead,  
  0 shadow, 0 missing; devdoc combinations all accounted for; optionals all route AND transmit).  

## v2.3 -- 2026-08-27 -- BOTH DOCUMENTED PLATE SEARCHES NOW WORK -- the in-state one stops discarding the

                plate type and year, and the plate-only one stops being unreachable  
**CHANGED** (VehicleRegistrationQuery + the Vehicle form; no other entity touched):
  ZLRG.P -- `RegistrationState EXISTS` condition REMOVED. set[]/any[]/defaults[] unchanged.  
  FORM -- LicensePlateTypeCode initialValue 'PC' and LicensePlateYear initialValue <year> BOTH  
    REMOVED. The combo defaults[] on ZLRG.P are KEPT, so CAD-originated queries still supply them  
    (CAD ignores form initialValue; defaults[] does not participate in routing).  
  ZVEH.P -- unchanged, including its `RegistrationState NOT_EXISTS` gate. See below.  
**REASON** -- TWO defects, one cause:
  metadata ZLRG{LicensePlateNumber} = Set[LicensePlateNumber, LicensePlateTypeCode,  
    LicensePlateYear] Any[State, ImageIndicator]  -- State is an OPTIONAL, not a fork.  
  metadata ZVEH{LicensePlateNumber} = Set[LicensePlateNumber] Any[ImageIndicator].  
  devdoc #4 "(mand) LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear [opt State]"  
  devdoc #3 "(mand) LicensePlateNumber"                      -- BOTH are documented searches.  
  (1) Gating ZLRG.P on State made devdoc #4 unreachable in-state, so a plate+type+year fill fell  
      through to ZVEH.P and the type and year were SILENTLY DISCARDED -- while prefilled and  
      visible to the officer. Same anti-pattern as TN_TIES KQ.N, NM_NMLETS_OFML RQ.P v2.7 and  
      CA_CLETS_OCATS DQ.N v2.8.  
  (2) The prefill destroyed the REAL discriminator. Type+year are precisely what separates the two  
      metadata variants, so prefilling them makes them always-present and would have killed the  
      plate-only search the moment the State gate came off (BUILD_RULES 24). Removing the State  
      gate WITHOUT un-prefilling would have traded defect (1) for a dead ZVEH.P.  
WHY UN-PREFILLING IS NOT A DEVIATION FROM THE PLATE-DEFAULTS STANDARD: it is the OOS-ONLY PLATE  
  CARD EXCEPTION already recorded for HI v3.0 -- when the out-of-state plate combo requires Plate  
  Type + Plate Year and the in-state one does not, BOTH are left blank, and validate.ps1 G-1 was  
  refined to PASS a blank PlateYear when its sibling PlateType is also blank. Confirmed: validator  
  71 PASS / 0 FAIL / 0 WARN. It is also outside Rob's 2026-08-27 keep-the-convention ruling by that  
  ruling's own terms -- it applies where "no routing depends on its presence", and here routing  
  depends on exactly these two fields.  
ZVEH.P KEEPS ITS `RegistrationState NOT_EXISTS` GATE deliberately: metadata ZVEH{plate} does not  
  define State at all, so without the gate a plate+State fill (with no type/year) would match  
  ZVEH.P and drop the State silently -- reintroducing this same defect class one combination over.  
  With the gate that fill honestly fires nothing, which is the correct outcome for a fill no  
  metadata variant accepts. ZLRG.P is a strict superset and is ordered first, so specificity now  
  routes the pair with no State gate on the winning side.  
GATES: validator 71P/0F/0W - audit_devdoc_optionals 1 FAIL -> 0 - fidelity 15 branches / 0 UNDER /  
  0 OVER UNCHANGED - reachability 12/12 ALL REACHABLE (ZVEH.P verified still live, which is the  
  whole point of un-prefilling) - prefill shadow 0 FAIL / 14 pairs - enforce 0 FAIL / 0 WARN.  
  [FLAG:plan-dedupe-vacuous-tests] RETIRED by this rebuild; plan regenerated to 46 tests.  
COST: NONE. MD_METERS has never been tenant-tested (0 logs at any version), so no package is  
  archived and it is on no Foundation or LIVE tenant.  

## v2.2 -- 2026-08-20 -- LAYOUT COLLAPSE 13->6 CARDS + NAME COMPONENTS

**CHANGED:**
  LAYOUT -- 13 cards -> 6, the uniform shape (usx-cosmetic Step 3b). Vehicle 3->1  
    (OPTIONS/PLATE/VIN merged), Person 5->2 (DL + DH, the DH-suffix pool being the  
    isolation mechanism), Firearm 1 (retitled), Article 1 (retitled), Boat 3->1.  
    Card titles ALL-CAPS and path-carrying. Canonical labels: 'License Number' -> 'OLN'  
    on both pools (DEX-1284); State keeps its routing hint ('leave blank for MD') because  
    MD routes in-state vs Nlets by State presence.  
  NAME COMPONENTS -- 4 new controls (NameMiddle/NameSuffix on the DL pool,  
    NameMiddleDH/NameSuffixDH on the DH pool), each composed into its pool's Name  
    FormatStringRuleHandler sourceField (Last,First,Middle,Suffix) with the separator list  
    grown @(', ') -> @(', ', ' ', ' ') per AP #15, and POOLED into the any[] of all FOUR  
    name combinations (ZWAR.O, ZLDR.N, ZWAR.N, ZDRV.N). Pool membership is what puts a  
    component on the wire -- AZ_AZDPS is the wire-PROVEN precedent (DOE, JOHN A JR).  
    audit_name_components: 4 C1 -> 0, 8 components examined.  
**REASON:**
  MD_METERS was one of the un-collapsed layouts (13 cards) and its own metadata declares  
  request Name with four components on every query built here, so an officer could not  
  enter two of them and FormatStringRuleHandler could not wire them.  
MEASURED AND NOT OWED -- this provider was carrying a STALE claim, not a defect:  
  CLAUDE.md's ImageIndicator section named MD_METERS as the LAST provider still holding  
  'N' values ("N=6 / Y=3, i.e. 2 entities") and therefore the last one owed the  
  ncic-image-default-y-everywhere flip. Measured from this build script before touching  
  anything: ImageIndicator carries TWELVE combo defaults[] all at 'Y', ZERO at 'N', and  
  all three form controls (Vehicle/Person/Boat) are already initialValue='Y'. It is also  
  in NO combination's set[] and NO condition, so the safety guard that rules out AZ_AZDPS  
  and LA_LEMS does not apply here either. audit_reverse_propagation agrees independently:  
  "[ncic-image-default-y-everywhere] PROPAGATED -- no provider still carries the flag".  
  Nothing was changed for it. The CLAUDE.md line is the thing that is out of date, and  
  that same paragraph already warns its own measuring probe under-reports.  
GATES: validator 70P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components  
  0 blocking / 8 examined | layout flow 0 findings | wiring closure 0 breaks in all ten  
  classes | reachability 12/12 | prefill shadow 0 (14 pairs) | fidelity 15 branches  
  0 UNDER / 0 OVER.  
NOT TESTED: never tenant-tested. Owes an import and a first-ever sweep.  

## v2.1 -- 2026-08-19 -- Last ncic-image carrier closed + 3 unfireable plan tests fixed -- 0 FAIL / 0 WARN

**CHANGED:**
  - ImageIndicator now defaults 'Y' on EVERY entity that defines the control. Vehicle  
    (ZLRG.P, ZLRG.V, ZVEH.P, ZVEH.V) and Boat (ZBOA.H, ZBOA.R) flipped from 'N'; Person  
    (ZWAR.O/N, ZLDR.O/N, ZDRV.O/N) was already 'Y'. Emitted JSON now reads 9 of 9 form  
    initialValues at 'Y' and 12 of 12 combo defaults[] at 'Y'.  
  - Canonical label applied to all three controls: "Image (optional)" -> "NCIC Image".  
  - NEW docs/reference/TEST_VALUE_OVERRIDES.txt with Person.OperatorLicenseExpirationYear=2028.  
**REASON:** three live flags, all three retired in this one rebuild -- [FLAG:ncic-image-default-y-everywhere],
  [FLAG:plan-fillability-unfireable-tests], [FLAG:validate-imgind-20b-l30].  

## v2.0 -- 2026-08-02 -- Galvanize to v2.0 -- single JSON, native PascalCase (commit bb656ac1)

**CHANGED:** Consolidated legacy BASE+MC into one versioned MD_METERS_v2.0.json; DH cards +
  queriesToDeselect (no Attention -- MD metadata does not define it); State relabeled  
  "leave blank for MD".  
**REASON:** State already had no initialValue per LIMITATION #30, so the label carries the hint rather
  than a routing-breaking prefill. Attention is absent BY AUTHORITY, not by omission -- MD's  
  metadata does not define it, so adding it would OVER-PERMIT. Recovered 2026-08-03 from commit  
  bb656ac1; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v1.0 -- 2026-05-07 -- MC multi-card layout


## v1.0 -- 2026-05-06 -- /07  Initial standup -- 6 basic queries, 14 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

