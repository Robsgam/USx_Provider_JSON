# OR_LEDS -- Changelog

Auto-generated from `OR_LEDS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-07

---

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

