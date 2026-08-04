# OH_LEADS -- Changelog

Auto-generated from `OH_LEADS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-04

---

## v2.2 -- 2026-08-01 -- RQ.P State promoted to set[] (portfolio fidelity sweep, commit c3b76a94)

**CHANGED:** RQ.P -- State PROMOTED into set[] to match metadata RQ{LicensePlateNumber}.
**REASON:** Found by the portfolio fidelity sweep (413 branches / 29 UNDER / 49 OVER across 20
  providers, while the six tenant-verified providers were 0/0). An UNDER-REQUIRED set[] is the  
  severe class: the query can fire WITHOUT the field and the request is invalid, and neither 6c nor  
  2i can see it -- a missing requirement is invisible to content and attribution checks. Recovered  
  2026-08-03 from commit c3b76a94; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.1 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + PlateType/PlateYear defaults


## v1.0 -- 2026-05-06 -- Initial build -- 6 basic queries, 23 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

