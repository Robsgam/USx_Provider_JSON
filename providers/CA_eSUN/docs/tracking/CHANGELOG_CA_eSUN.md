# CA_eSUN -- Changelog

Auto-generated from `CA_eSUN_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-04

---

## v2.2 -- 2026-08-01 -- 55 devdoc-optional FAILs traced to ONE envelope field (commit 03efbc68)

**CHANGED:** Fixed the single transaction-envelope field whose absence produced 55 separate
  devdoc-optional FAILs. CA_eSUN reached ENFORCED as the 10th green provider.  
**REASON:** The lesson is the ratio -- 55 findings, ONE cause. A finding count is not a defect count,
  and chasing them individually would have been 55x the work. Recovered 2026-08-03 from commit  
  03efbc68; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.1 -- 2026-07-31 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.2 -- 2026-05-07 -- MC multi-card layout + full combo refinement


## v1.1 -- 2026-05-07 -- PlateType/PlateYear defaults + DH-suffix refinement


## v1.0 -- 2026-05-06 -- /07  Initial standup -- 6 basic queries, 17 combos


## v1.5 -- 2026-05-11 -- LIMITATION elimination pass

