# CA_CLETS -- Changelog

Auto-generated from `CA_CLETS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.8** | Generated: 2026-06-26

---

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

