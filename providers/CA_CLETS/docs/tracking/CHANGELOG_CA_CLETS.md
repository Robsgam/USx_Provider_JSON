# CA_CLETS -- Changelog

Auto-generated from `CA_CLETS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.22** | Generated: 2026-07-31

---

## v2.22 -- 2026-07-28 -- Lean-label pass + stale combo-count doc fixes (direct Rob feedback + adversarial audit, NO functional change)

**CHANGED:**
  (1) LEAN LABELS -- stripped every "(optional)"/"(with Name, optional)"/"(required with Name)"  
    helper now that the card titles carry the query paths (matches FL/NJ/HI/NY/TX): Vehicle  
    Make/Year/City/Street; DL DOB/Age/Height/County/Race; Article Type/Brand/Category -> bare, each  
    any[]-only field tagged # LABEL-OVERRIDE so verify_build CHECK 15 stays clean. Boat owner Name  
    "(out-of-state only)" -> "(out-of-state)"; Boat DOB helper dropped. State fields keep their  
    "leave blank for CA" routing hint.  
  (2) STALE COMBO COUNTS (adversarial-audit finding, doc-only): bundle description 40->25 combos,  
    VehicleRegistrationQuery 6->5, BoatQuery 7->6 (the 40/6/7 were pre-v2.5 counts, before the 13  
    IV.4* + IV.4V/IV.4B deletions) + header card-count 8->6.  
**REASON:** Rob -- "clean up all the optional labels, cleaner pass like the other providers" + the
  adversarial audit's stale-string findings. Label/doc-only, no combo/QIDM/routing/fieldId/default  
  change; wire identical. Audit confirmed the v2.21 Person fold is fully intact. ALL 5 ENTITIES RESET.  

## v2.21 -- 2026-07-28 -- FIX botched v2.20 Person fold -- DH card lost its State field (Rob caught it)

**CHANGED:** v2.20 folded the shared RegistrationState onto the DL card ONLY, on the wrong premise
  that CA's DH uses no State. The DriverHistoryQuery (NLTS.KQ, Nlets/interstate) DOES source State  
  (attribute State -> RegistrationState, present in both KQ.N/KQ.O any[]) and needs a destination  
  State for OOS history -- so the DH card was left with no State field (botched Person screen).  
  FIX (TX v4.12 pattern): DH card gets its own RegistrationStateDH; the DH QIDM State attribute +  
  both combos' any[] re-sourced RegistrationState -> RegistrationStateDH. State now on BOTH cards  
  (DL shared RegistrationState, DH suffixed RegistrationStateDH). targetField stays 'State' so the  
  CommSys wire is identical. Attention (hidden) + purposeCodeDH were already on the DH card.  
**REASON:** Rob -- "person screen is botched, you did not account for state/attention/purpose code for
  DH out-of-state queries, was supposed to go on both cards." Correct. Root cause: I judged fold  
  cost from the DH combo set[] and missed State in the DH any[]. Layout + form-field-isolation only,  
  no combo/routing/wire change. ALL 5 ENTITIES RESET at v2.21.  

## v2.20 -- 2026-07-28 -- Layout review -- Person OPTIONS fold + 4 title enumerations (direct Rob feedback, NO functional change)

**CHANGED:**
  (1) Person SEARCH OPTIONS card folded into DL -- State + Purpose Code moved onto the DL card's  
    bottom row (the DriverLicenseQuery combos source these shared fieldIds). Person = 2 cards  
    (DL + DH). Unlike TX v4.12, NO DH-suffixed copies needed: CA's DH is already self-contained  
    (its own purposeCodeDH; DriverHistoryQuery uses NO State), verified from the build-script DH  
    QIDM sourceFields.  
  (2) Enumerated the 4 bare card titles: Vehicle "...BY LICENSE PLATE, OR VIN, OR NAME"; Firearm  
    "...BY SERIAL NUMBER, OR NAME"; Article "...BY SERIAL NUMBER, OR OWNER APPLIED NUMBER"; Boat  
    "...BY HULL ID, OR REGISTRATION NUMBER, OR OWNER APPLIED NUMBER" (DL/DH already enumerated).  
**REASON:** Rob's layout review before the CA_CLETS tenant sweep. Layout/title-only, no combo/QIDM/
  routing/fieldId/default change -- wire identical to v2.19 (the in/out gating fix). ALL 5 ENTITIES  
  RESET for re-test at v2.20. CA-FAMILY: propagate to Ventura/eSUN/SLO/OCATS/Contra Costa on their pass.  

## v2.19 -- 2026-07-27 -- In/out gating fix on Vehicle + Boat (FUNCTIONAL, adversarial-audit finding)

**CHANGED:** Completed the DEX-1284 existence-gate in/out routing that CA never received (it was on
  the older pre-DEX-1284 model where the in-state catchalls relied on set[]/ordering alone). Now  
  the OOS combos fire only when State is present and the in-state catchalls only when State is  
  blank, so they no longer co-fire/shadow:  
    Vehicle: NLTS.RQ.P += RegistrationState EXISTS  (was UNGATED -- v2.11 claimed it gated "all 6  
               NLTS combos" but its own list named NLTS.RQ.V and MISSED NLTS.RQ.P, so RQ.P fired  
               on any plate and shadowed the in-state IA.QV)  
             IA.QVK   += RegistrationState NOT_EXISTS  
             IA.QV    += RegistrationState NOT_EXISTS  
    Boat:    IA.QB.H  += RegistrationState NOT_EXISTS  
             IA.QB.R  += RegistrationState NOT_EXISTS  
             (NLTS.BQ.H/R were already EXISTS-gated; IA.QB.O is a standalone OAN path with no OOS  
              sibling, so it was left ungated.)  
  RegistrationState dropped from the in-state combos' any[] (gate-XOR-companion). Existence-only  
  (poisoned-array-safe).  
**REASON:** Adversarial audit found CA running the pre-DEX-1284 routing model -- the exact co-fire/
  shadow bug NY v4.15 / TX v4.9 / FL fixed. test_commsys confirms: plate+State -> NLTS.RQ.P only  
  (IA.QV now SKIPs on State present); plate-alone -> IA.QV. verify_build 16P/0W/0F, CHECK 14  
  reachability PASS. FUNCTIONAL -> all 5 entities reset (block by version). NOT yet re-tested.  
  FAMILY FOLLOW-UP: CA_VENTURA/eSUN/SLO/OCATS/Contra Costa (same template) likely need the same  
  fix -- flagged, not done here.  

## v2.18 -- 2026-07-27 -- UPPERCASE card titles + gunCaliber CAD-token fix (audit finding)

**CHANGED:** (a) All card titles UPPERCASED, wording unchanged (e.g. "Driver License Search by OLN,
  CII, SSN, \"OR\" Name" -> all-caps; "Search Options" -> "SEARCH OPTIONS"; Firearm/Article/Boat  
  already uppercase). New global convention (BUILD_RULES Section 11).  
  (b) AUDIT FIX: gunCaliber -> GunCaliber (form fieldId + QIDM sourceField + Gun combo any[] +  
  LABEL-OVERRIDE tag). GunCaliber is a PascalCase CAD-integration token; CA was the only provider  
  emitting it camelCase (TX/HI/NY/NJ all use GunCaliber), so CAD would not auto-populate caliber.  
  Attribute name + targetField were already 'GunCaliber' -- only the form-fed casing was wrong.  
**REASON:** Rob -- "everything needs to be upper case" (titles) + the adversarial audit caught the
  gunCaliber casing. Title/casing-only, no combo/QIDM/routing change. verify_build clean. ALL 5  
  ENTITIES RESET at v2.18 (block by version). NOT yet re-tested.  

## v2.17 -- 2026-07-27 -- DEX-1284 relabel/naming-convention pass (direct Rob feedback, NO functional change)

**CHANGED:** Applied the portfolio OLN convention:
  - OperatorLicenseNumber (DL) + OperatorLicenseNumberDH (DH) "License Number" -> "OLN"  
  - DL/DH card titles carry query paths: "Driver License Search by OLN, CII, SSN, \"OR\" Name"  
    and "Driver History Search by OLN, \"OR\" Name"  
  CA_CLETS has NO ImageIndicator field (bare "NCIC Image" N/A) and NO relatedHitSearchIndicator/  
  stolen toggle ("Stolen Check" N/A). Cross-reference helpers were already stripped at v2.13; the  
  "(optional)" indicators on genuinely-optional any[] fields (DOB/Age/Height/County/Race) are  
  valid CHECK 15 hints and are kept. DL top row (OLN + CII + SSN alternate identifiers) unchanged  
  -- OLN already leads.  
**REASON:** DEX-1284 portfolio relabel. Label/title-only, no combo/QIDM/routing/fieldId/default
  change. verify_build 16P/0W/0F. ALL 5 ENTITIES RESET for re-test at v2.17 (block by version).  
  NOT yet re-tested.  

## v2.16 -- 2026-07-24 -- Race re-added to RMS person search

**CHANGED:** Dropped -SkipRace from Build-RmsBundle (raceCode now in the RMS Person any[]);
         switched the raceCode form field from codeTypeCategory='NIBRS_RACE' to  
         attributeTypeId='RACE'+codeTypeProvider='NIBRS' (mirrors the SexCode dual-consumer  
         field) so it feeds the RMS race attr (useAttributeId=true) without tripping AP #11  
         while still sending the code to the CommSys RaceCode wire.  
**REASON:** Rob (2026-07-24) -- harmonize the CA family so all six providers offer race in the RMS
        person search (CA_VENTURA/eSUN/SLO/OCATS already keep it). Reverses the v2.x -SkipRace.  
        ALL 5 entities reset for re-test from Test 1 (was USx-tenant-tested at v2.15).  
        VERIFY at re-test: RACE dropdown populates + CommSys RaceCode wire unchanged.  

## v2.15 -- 2026-07-21 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.14 -- 2026-07-21 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.13 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.12 -- 2026-07-01 -- Restore in-state DriverLicenseQuery combos (ID.L1 / IN.L1)

**CHANGED:** DL 6 -> 8 combos. Restored ID.L1 (in-state OLN) + IN.L1 (in-state Name), the real
  devdoc keyRefs v2.11 removed. Added gating conditions so all 8 are mutually exclusive:  
  IR.QVC.O += criminalIdNumber EXISTS; IR.QVC.N += RegistrationState NOT_EXISTS + SexCode EXISTS;  
  ID.L1 = RegistrationState NOT_EXISTS + criminalIdNumber NOT_EXISTS; IN.L1 = OLN NOT_EXISTS +  
  RegistrationState NOT_EXISTS + SexCode NOT_EXISTS. Validator 77P/0F/0W; verify CLEAN (CHECK 16  
  reachability confirms all 8 reachable).  
**REASON:** v2.11 removed ID.L1/IN.L1 expecting "CommSys auto-dispatches, consistent with Vehicle
  pattern" -- but Vehicle keeps an unconditioned in-state catchall (IA.QV/IA.QVK) and DL kept  
  none, so a plain in-state driver lookup (OLN-only or name-only, no State) fired nothing.  
  Full re-test from T1 required.  

## v2.11 -- 2026-06-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.10 -- 2026-06-26 -- : VehicleMakeName code source VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present). Shared module; result-mapping only, request-side combos unchanged.


## v2.9 -- 2026-06-26 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.8 -- 2026-06-26 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.7 -- 2026-06-26 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.6 -- 2026-06-26 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.5 -- 2026-06-14 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.4 -- 2026-06-09 -- Single-JSON merge

**CHANGED:** Merged BASE/MC into single build: build_ca_clets.ps1 → CA_CLETS.json (no suffix).
         Deleted old BASE build script. Reports now in docs/ (not docs/mc/).  
         Phase snapshots to phases/ (not phases/mc/).  
**REASON:**  BASE/MC split doubled maintenance; single-JSON is the standard.
VALIDATOR: 91P/0F/0W  
TEST CONDUCTOR: 52/52 PASS  

## v2.1 -- 2026-05-19 -- Full combo coverage BASE + CAD defaults fix

**CHANGED:** Added 3 cross-entity combos to single-card BASE layout:
         - IN.VP (Vehicle by owner Name) -- nameFirst/nameLast on Vehicle card  
         - IG.QGH (Firearm by owner Name) -- nameFirst/nameLast on Firearm card  
         - NLTS.BQ.N (Boat by owner Name+DOB OOS) -- nameFirst/nameLast/birthDate on Boat card  
         Added CAD defaults on IA.QV combo (LicensePlateTypeCode=PC, LicensePlateYear=$currentYear).  
         Archived MC variant -- all 20 combos achievable on single-card-per-entity BASE.  
**REASON:**  audit_metadata.ps1 CHECK 5 (Primary Field Coverage) identified 3 metadata search paths
         with no matching combo. Cross-entity Name fields on Veh/Gun/Boat cards enable these  
         combos without needing a separate MC layout. CAD audit flagged missing defaults on IA.QV.  
VALIDATOR: BASE 70P/0F/0W/0LIM  
CAD AUDIT: 80P/0F/0W/57INFO  
TEST CONDUCTOR: 32/32 PASS (20 combos)  

## v1.9 -- 2026-05-19 -- CAD field alignment: purposeCode fieldId

**CHANGED:** Renamed fieldId 'caRequestPurposeCode' to 'purposeCode' on all 5 entity forms.
         Renamed 'caRequestPurposeCodeDH' to 'purposeCodeDH' on Person DH fields.  
         QIDM targetField='CaRequestPurposeCode' unchanged (XML element name).  
**REASON:**  CAD dispatch sends PurposeCode (PascalCase). Platform matches case-insensitively
         to JSON fieldId. 'caRequestPurposeCode' did not match -> zero combos fired from CAD.  
         'purposeCode' matches CAD's 'PurposeCode'. QIDM sourceField→targetField handles  
         the mapping to the correct XML element name CaRequestPurposeCode.  
VALIDATOR: BASE 66P/0F/0W/0LIM | MC 70P/0F/0W/0LIM  
IMPORT TEST: 3/3 CAD PASS (IA.QV plate, NLTS.RQ.P OOS plate, IA.QVK VIN)  
CROSS-PROVIDER: All CA providers need same rename on next rebuild (CA_eSUN, CA_VENTURA,  
                CA_SAN_LUIS_OBISPO, CA_CLETS_OCATS).  

## v1.8 -- 2026-05-12 -- One-directional queriesToDeselect fix

**CHANGED:** Removed queriesToDeselect from DL QIDM (was bidirectional with DH).
**REASON:**  Bidirectional queriesToDeselect suppresses DH autoSelect. One-directional pattern:
         DL=default (autoSelect=true, no deselect), DH=opt-in (autoSelect=true, deselects DL).  
VALIDATOR: BASE 66P/0F/0W/0LIM | MC 70P/0F/0W/0LIM  
IMPORT TEST: 18/18 PASS (2026-05-12)  

## v1.7 -- 2026-05-11 -- camelCase fieldIds + DH-suffix + combo ordering

**CHANGED:** Full camelCase conversion, DH-suffix fieldIds, combo priority reorder.
**REASON:**  CAD auto-populate + standard patterns.
VALIDATOR: BASE 66P/0F/0W/0LIM | MC 70P/0F/0W/0LIM  

## v1.6 -- 2026-05-07 -- /08) -- VehicleMakeCode dropdown + Stats cleanup

**CHANGED:** VehicleMakeCode from FormInput (free-text) to FormSelect with attributeTypeId='VEHICLE_MAKE',
         codeTypeProvider='NCIC'. Matches NJ, FL, AZ pattern for vehicle make dropdown.  
         Removed abandoned Stats info card feature (AddInfoCard function, -Stats switch).  
         MC script updated 2026-05-08 to match BASE (was still FormInput).  
**REASON:**  All imported providers (NJ, FL, AZ) use dropdown for VehicleMakeCode. Free-text required
         officers to know NCIC make codes; dropdown provides searchable list.  
VALIDATOR: BASE 64P/0F/0W/5LIM | MC 68P/0F/0W/7LIM | Verify CLEAN  

## v1.5 -- 2026-05-06 -- PlateType/PlateYear defaults + PurposeCode layout fix

**CHANGED:** LicensePlateTypeCode initialValue='PC', LicensePlateYear initialValue='2026' (both BASE+MC).
         CaRequestPurposeCode moved from position 1 to position 3 on all 5 entity ROW_1.  
**REASON:**  Standard defaults per cross-provider audit (6/8 providers already had them).
         Safe because State (not PlateType/Year) is the combo routing discriminator.  
         PurposeCode is auto-filled so belongs at end, not taking prime position.  
VALIDATOR: BASE 64P/0F/0W/5LIM | MC 68P/0F/0W/7LIM | Verify CLEAN  

## v1.4 -- 2026-05-06 -- BirthDate format fix

**CHANGED:** CommsysParseDateRuleHandler target format: MMddyyyy -> yyyyMMdd (all BirthDate attrs)
**REASON:**  CA_ESUN (production CA provider) uses yyyyMMdd. Our build had MMddyyyy (copied from
         NJ pattern without verifying CA-specific format). BirthDate would have been sent as  
         e.g., "01151990" (Jan 15) instead of "19900115" — wrong date interpretation by CA backend.  
ALSO:    Added PROVIDER_CONFIG.txt with verified date format, supported query list, CA patterns.  
         Build script header cleaned (removed stale "9 transactions" count).  

## v1.3 -- 2026-05-06 -- Devdoc audit: removed unsupported QIDMs

**CHANGED:** Removed WMPIWantedPersonQuery, WMPIMissingPersonQuery, CAISupervisedReleaseQuery
**REASON:**  Devdoc "Basic Queries Supported:" lists exactly 6 queries. These 3 are NOT in the
         devdoc's basic or expanded query lists. Built in error during v1.0-v1.2 because  
         extract_queries.ps1 invented a "Basic" category from naming patterns instead of  
         checking the devdoc. CA_ESUN (production CA provider) confirms: 6 basic + Lojack only.  

## v1.2 -- 2026-05-06 -- Phase 2 MC cross-entity combos

**CHANGED:** MC variant adds person fields to Vehicle/Firearm/Boat forms for cross-entity combos
**REASON:**  Metadata defines name-based combos on non-person entities; MC enables them

## v1.1 -- 2026-05-06 -- Phase 2 SupervisedRelease + OOS boat

**CHANGED:** Added CAISupervisedReleaseQuery (9th QIDM) + NLTS.BQ OOS boat combos
**REASON:**  Metadata IR.QVC transaction confirmed valid; OOS boat combos buildable without cross-entity

## v1.0 -- 2026-05-06 -- Phase 1 single-card standup

**CHANGED:** Full Phase 1 build: 5 entities, 8 CommSys QIDMs (21 combos), RMS
**REASON:**  Initial CA_CLETS provider JSON for ConnectCIC

## v0.0 -- 2026-05-06

**CHANGED:** Project scaffolding created
**REASON:**  Initial provider setup

## v1.7 -- 2026-05-11 -- LIMITATION elimination pass

