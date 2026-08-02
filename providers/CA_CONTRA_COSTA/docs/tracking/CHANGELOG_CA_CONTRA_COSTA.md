# CA_CONTRA_COSTA -- Changelog

Auto-generated from `CA_CONTRA_COSTA_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-02

---

## v2.2 -- 2026-07-31 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-07-24 -- Race re-added to RMS person search (mirrors CA_CLETS v2.16)

**CHANGED:** Dropped -SkipRace from Build-RmsBundle (raceCode now in the RMS Person any[]);
         raceCode form field -> attributeTypeId='RACE'+codeTypeProvider='NIBRS' (SexCode  
         dual-consumer pattern, clears AP #11).  
**REASON:** Rob (2026-07-24) -- harmonize the CA family so CC offers race in the RMS person search
        (was -SkipRace, inherited from the CA_CLETS copy). Still NOT USx-tenant-tested.  

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild
