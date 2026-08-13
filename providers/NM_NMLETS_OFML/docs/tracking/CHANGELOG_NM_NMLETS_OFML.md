# NM_NMLETS_OFML -- Changelog

Auto-generated from `NM_NMLETS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.1** | Generated: 2026-08-13

---

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

