# NM_NMLETS_OFML -- Changelog

Auto-generated from `NM_NMLETS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.3** | Generated: 2026-08-20

---

## v2.3 -- 2026-08-20 -- LAYOUT COLLAPSED 13 cards -> 6, and the officer could not enter a middle name or suffix

**CHANGED:**
  - Vehicle 3 cards -> 1 ("VEHICLE SEARCH BY PLATE, OR BY VIN"). OPTIONS held a single shared  
    control (State); PLATE and VIN are the two identifier paths and now lead their own rows.  
  - Person 5 cards -> 2, the ONLY entity legitimately at two: DRIVER LICENSE + DRIVER HISTORY.  
    The DH-suffix fieldIds are a separate field pool and that separation IS the isolation  
    mechanism, so collapsing to one card would be wrong, not tidier.  
  - Boat 3 cards -> 1 ("BOAT SEARCH BY HULL ID, OR BY REGISTRATION NUMBER").  
  - Firearm/Article titles made path-carrying ("... BY SERIAL NUMBER", "... BY SERIAL NUMBER + TYPE").  
  - MIDDLE NAME + SUFFIX CONTROLS ADDED on BOTH name pools (NameMiddle/NameSuffix and  
    NameMiddleDH/NameSuffixDH), composed into each Name composite.  
  - Labels to canon: DH OLN control read "License Number" -> "OLN"; "(optional)" stripped from  
    Vehicle Make, Make, Caliber, Model, Race, Purpose Code; "Vehicle Year (Nlets registration  
    search)" -> "Vehicle Year". State KEEPS its routing hint -- that is the sanctioned location.  
**REASON:** two separate gates were reporting on this provider and neither had been acted on.
  audit_layout_flow: 6 findings -- L4 CARDS-NOT-COLLAPSED on Vehicle/Person/Boat, two L5  
  WASTED-WIDTH (Plate maxLen 10 and Boat RegistrationNumber maxLen 8 each alone on a full  
  12-column row), and an L9 RMS-ONLY-BESIDE-IDENTIFIER (raceCode shared a row with the mandatory  
  purposeCode, so an RMS-only field sat beside a state identifier and read as though it queried  
  the state). audit_name_components: 4 C1 NO-CONTROL -- Name.Middle and Name.Suffix on BOTH  
  DriverLicenseQuery and DriverHistoryQuery, i.e. the metadata defines them and the officer  
  COULD NOT ENTER THEM. Rob, 2026-08-20: "veh has 3 cards  person has 5 and boat has 3  reall  
  the process is to callapose them".  
**RESULT:** layout_flow 6 findings -> 0 (6 cards / 15 rows / 37 fields / 14 combinations compared,
  so not a vacuous pass). name_components 4 C1 -> 0 C1 / 0 C2, PASS on 8 components examined.  
  audit_wiring_closure 0 breaks across all ten classes -- the four new controls are not dead and  
  the Attention requirement is still fillable. validator 66 PASS / 0 FAIL / 0 WARN.  

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

