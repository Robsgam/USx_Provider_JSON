# NM_NMLETS_OFML -- Changelog

Auto-generated from `NM_NMLETS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-18

---

## v2.2 -- 2026-08-18 -- DriverLicenseQuery was missing BOTH of its mandatory fields -- PurposeCode + Attention

**CHANGED:**
  - PurposeCode PROMOTED into set[] on BOTH DL combos (DL.NAME, DL.OLN) + a visible "Purpose Code"  
    Inp control prefilled 'C' + the CAD defaults[] twin on both combos.  
  - Attention wired to the standing auto-handler: attribute (size 30, sourceField Attention,  
    targetField Attention, rule CommsysGetLastNameFirstNameInitialRuleHandler) + any[] membership on  
    both DL combos + a HIDDEN feeder control, no prefill, no combo default. REGISTERED as  
    demoted-to-any on both combos.  
  - Labels owed on this provider's revisit turn: "License Number" -> "OLN" (DEX-1284) and  
    "Image (optional)" -> "NCIC Image". ROW_PER_OPT_1 widened 4/4/4 -> 3/3/3/3 for the new control.  
**REASON:** audit_requirement_fidelity reported FOUR severity-1 UNDER-REQUIRED findings --
  "DL.OLN UNDER-REQUIRED: PurposeCode (ABSENT); Attention (ABSENT)" and the same on DL.NAME.  
  ABSENT, not demoted: neither field was in set[] NOR any[], so the officer could not supply them at  
  all and every NM driver-licence query went out missing two fields its metadata makes mandatory.  

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

