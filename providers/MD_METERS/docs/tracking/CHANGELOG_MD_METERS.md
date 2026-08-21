# MD_METERS -- Changelog

Auto-generated from `MD_METERS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-20

---

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

