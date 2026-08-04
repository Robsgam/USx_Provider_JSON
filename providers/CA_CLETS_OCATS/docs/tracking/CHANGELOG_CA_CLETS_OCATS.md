# CA_CLETS_OCATS -- Changelog

Auto-generated from `CA_CLETS_OCATS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.3** | Generated: 2026-08-04

---

## v2.3 -- 2026-08-02 -- Wire ArticleCategory; fix an Authorization size read from the wrong transaction (5f010dd5)

**CHANGED:** ArticleCategory wired so the officer's value is transmitted, and an Authorization field
  size corrected -- it had been read from the WRONG transaction's metadata.  
**REASON:** The size error is the instructive half: a field definition taken from a sibling
  transaction looks valid and is not. Recovered 2026-08-03 from commit 5f010dd5; this entry read  
  "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.2 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.0 -- 2026-05-07 -- Initial build

**CHANGED:** New provider build from CA_CLETS_OCATS.xml metadata (System CLETS_OCATS v21).
         Based on CA_CLETS patterns with OCATS-specific adaptations.  
SCOPE:   5 basic queries (VehicleRegistrationQuery, DriverLicenseQuery, GunQuery,  
         ArticleSingleQuery, BoatQuery). No DriverHistoryQuery (no KQ MessageKeys).  
COMBOS:  19 total across 5 QIDMs.  
DESIGN:  Single-card BASE + multi-card MC. CaRequestPurposeCode hidden on all forms.  
         VP owner search on Vehicle. yyyyMMdd date format per CA standard.  
VALIDATOR: BASE 63P/0F/0W/2LIM | MC 63P/0F/0W/2LIM | Verify CLEAN  

## v1.2 -- 2026-05-11 -- LIMITATION elimination pass

