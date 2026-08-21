# OR_LEDS -- Changelog

Auto-generated from `OR_LEDS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.5** | Generated: 2026-08-20

---

## v2.5 -- 2026-08-20 -- LAYOUT COLLAPSE 11->5 CARDS; L9 RMS-ONLY ROW SPLIT

**CHANGED:**
  LAYOUT -- 11 cards -> 5, the uniform shape (usx-cosmetic Step 3b). Vehicle 3->1,  
    Person 3->1, Firearm 1, Article 1, Boat 3->1. Titles ALL-CAPS and path-carrying.  
    Canonical labels: 'VIN' -> 'Vehicle Identification Number', 'License Number' -> 'OLN'  
    (DEX-1284), 'Image (optional)' -> 'NCIC Image'. State keeps its routing hint on all  
    three carrying entities -- OR forks in-state vs Nlets on State presence.  
  PERSON IS LEGITIMATELY ONE CARD, not the usual DL + DH pair: OR builds no  
    DriverHistoryQuery (5 basic queries, no DH), so there is no second field pool to  
    isolate. The uniform target's "Person = 2 cards" is a consequence of DH-suffix  
    isolation, not a rule to satisfy where DH does not exist.  
  BOAT -- Hull now LEADS Registration. The old layout put the REGISTRATION card first,  
    which read as though registration were the primary path; the identifier-priority  
    guardrail is Hull > Reg, so the form now matches the routing.  
  L9 FIX -- ROW_PER_3 split into two rows. raceCode is RMS-ONLY on OR (it appears in NO  
    CommSys combination) and was sharing a row with the mandatory CommSys identifiers  
    BirthDate and SexCode, so the most prominent qualifier row implied a state query that  
    never happens. It now sits with NCIC Image, which is a CommSys OPTIONAL rather than an  
    identifier. Found by audit_layout_flow L9 after the collapse -- the finding did not  
    exist before, because the pre-collapse cards were too small to trip it (which is the  
    vacuity L4 warns about in its own message).  
NOT CHANGED, because it was already right: OR's name components were WIRED at v2.3 --  
  nameMiddle/nameSuffix are composed into the Name FormatStringRuleHandler  
  (@(', ',' ',' ') separators, AP #15) AND pooled in DQ.N's any[]. audit_name_components  
  reports 0 blocking / 4 examined. Worth recording because v2.2 had DELETED those two  
  controls as "dead", and v2.3 restored and wired them -- the fix for an unwired control  
  is to wire it, not to remove the officer's ability to type it.  
GATES: validator 55P/0F/0W | verify_build 16 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 4 examined | layout flow 1 finding -> 0 | wiring closure 0 breaks in all ten  
  classes | reachability 7/7 | prefill shadow 0 (5 pairs) | fidelity 8 branches 0 UNDER /  
  0 OVER.  
NOT TESTED: never tenant-tested. Owes an import and a first-ever sweep.  

## v2.4 -- 2026-08-19 -- VehicleMakeCode + VehicleYear removed -- the vehicle query cannot carry them; 0F/0W

**CHANGED:**
  - VehicleMakeCode and vehicleYear removed from all three RQ combos' any[] (RQ.PO, RQ.V, RQ.P).  
  - Their two QIDM attributes removed, and both form controls removed with ROW_VEH_VIN_2.  
    The VIN card is now VIN only.  
  - REGISTERED VehicleRegistrationQuery | RQ.V | VehicleMakeCode and | VehicleYear as  
    devdoc-optional-unreachable.  
**REASON:** audit_requirement_fidelity reported 4 OVER-PERMITTED --
  "RQ -> built 'RQ.PO' OVER-PERMITTED: VehicleMakeCode; VehicleYear" and the same on RQ.V. We were  
  transmitting two fields this transaction does not define.  

## v2.3 -- 2026-08-17 -- RESTORE middle name + suffix on DriverLicenseQuery

**CHANGED:** Wired the metadata-defined middle-name and suffix components of the composite `Name`
  field so they reach the wire: added the two form controls per name path, appended them to that  
  query's composite Name sourceField, and added them to every name-search combination's any[].  
  FormatStringRuleHandler separators went @(', ') -> @(', ',' ',' ') -- AP #15 requires fields-1  
  separators, so four sourceFields need three. Name rows regrouped to carry all four parts, with  
  mandatory qualifiers moved to their own row beneath (layout rules L8/L2). No set[] was touched  
  and every addition is any[]-only, so NO ROUTING CHANGED.  
**REASON:** Found by tools\audit_name_components.ps1 (new 2026-08-17) -- the authority->built gate at
  COMPONENT granularity. This provider's own metadata declares request `Name` with FOUR components  
  (First/Last/Middle/Suffix) on the queries built here, but middle and suffix had no form control,  
  so the officer could not enter them at all. No existing gate could see it: every other gate  
  enumerates the JSON and is therefore closed under what we built, and because the test plan is  
  generated FROM the JSON, a missing control produces no test and so can never fail.  
  CAPABILITY IS WIRE-PROVEN, not theoretical: AZ_AZDPS v3.11 and CA_CLETS v2.25 (109/109 logs)  
  both emit <Name>DOE, JOHN A JR</Name> and degrade cleanly to "DOE, JOHN JR" when the middle name  
  is absent -- no double space, no stray comma.  RESTORATION. v2.2 (commit 56b8b7ca, 2026-08-02) deleted ROW_PER_NAME_2, which held nameMiddle and  
  nameSuffix, as dead controls -- the v2.2 note in this file states the reasoning verbatim: "the  
  Name attribute sources only [NameLast, NameFirst], so an officer's middle name or suffix was  
  silently discarded". That observation was correct and the remedy was backwards: OR metadata  
  declares request Name with four components, so the sourceField should have been extended rather  
  than the controls removed. Rob reversed the call on 2026-08-17.  

## v2.2 -- 2026-08-02 -- Remove 3 dead officer controls (Rob 2026-08-02, commit 56b8b7ca)

**CHANGED:** Deleted the visible-but-unwired Person nameMiddle and nameSuffix, and Firearm
  gunTypeCode. No wire change -- none of the three was ever transmitted.  
**REASON:** audit_wiring_closure class A (dead control). Name attributes source only
  [NameLast, NameFirst], so a middle name or suffix was silently discarded. gunTypeCode was the  
  worse case -- not merely unwired but UNWIREABLE: OR's XML defines GunTypeCode exactly once,  
  under CPICBIGunQuery, a transaction this build does not carry. It comes back WITH its attribute  
  and combination if CPICBIGunQuery ever enters scope. Rob's call was remove, not wire. Recovered  
  2026-08-03 from commit 56b8b7ca; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.1 -- 2026-08-02 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + PlateType/PlateYear defaults


## v1.0 -- 2026-05-06 -- Initial build -- 5 basic queries, 8 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

