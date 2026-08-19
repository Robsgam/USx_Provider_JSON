# MD_METERS -- Changelog

Auto-generated from `MD_METERS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.1** | Generated: 2026-08-19

---

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

