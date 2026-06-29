# FL_FCIC -- Changelog

Auto-generated from `FL_FCIC_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v6.9** | Generated: 2026-06-29

---

## v6.9 -- 2026-06-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.8 -- 2026-06-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.7 -- 2026-06-25 -- NJ/HI-parity galvanization (drop import-breaking version field; versioned filename)

**CHANGED:** Structural/cosmetic galvanization to match the NJ v4.6 / HI v4.3 standard. (1) Removed
  the top-level "version" field (v6.6 had adopted it) -- the platform deserializes it as  
  java.lang.Integer and rejects the dotted string, so v6.6 was unimportable. Now omitted by the  
  patched Write-ProviderJson. (2) Root JSON now versioned: FL_FCIC_v6.7.json (was bare  
  FL_FCIC.json); stale sibling removed by Write-ProviderJson. (3) Version stamped into all 3  
  bundle descriptions (ENTITIES/PROVIDER/RMS) via -Description on Build-EntitiesBundle and  
  Build-RmsBundle (PROVIDER bundle was already versioned). (4) Per-provider CHANGELOG_FL_FCIC.md  
  generated. No QIF/QIDM/combo/conditions change -- query behavior and entity fingerprints are  
  identical to v6.6.  
**REASON:** FL reopened (DEX-971) for re-import; v6.6 carried the import-breaking top-level version
  field. Bring FL to NJ/HI parity (versioned filename, version-in-all-bundles, auto changelog)  
  and make it importable again. FL already had the rest of the NJ/HI suite (identifier-priority  
  guardrails v6.0, native PascalCase v5.2, VehicleMakeName QRDM VehicleType/VEHICLE v6.6,  
  Last-first comma-space Name v6.1) -- no behavior changes needed.  
**RESULT:** Importable v6.7; structural only. Per the full-retest mandate, all 5 entities re-opened
  for a full live re-test from Test 1 (re-import + re-validate). HI-specific fixes NOT applied  
  (QVP/QVV removal, Make-field removal, First->Last name order -- all N/A to FL).  

## v6.6 -- 2026-06-24 -- Adopt version field + VehicleMakeName QRDM fix (shared-module currency)

**CHANGED:** Native rebuild on current shared modules. (1) Top-level "version":"6.6" now
  emitted by Write-ProviderJson. (2) VehicleMakeName QRDM attribute codeType corrected  
  from NCIC_FIREARM_MAKE/NJ_NIBRS (firearm-make table -- wrong) to VehicleType/VEHICLE,  
  matching the 2026-06-24 _build_rms_bundle.ps1 fix. Query/combo behavior unchanged  
  (entity fingerprints identical); only results-mapping make resolution + the version  
  field differ.  
**REASON:** Reproducibility audit (audit_reproducible.ps1) found the committed v6.5 JSON was
  DETERMINISTIC but STALE -- it predated the 2026-06-24 shared-module fixes. Rebuilt to  
  bring the committed JSON back in sync with a fresh build.  

## v6.5 -- 2026-06-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v6.4 -- 2026-06-23 -- FBQ Boat conditions casing fix (verify_build CHECK 13)

**CHANGED:** FBQBoatHullIdNumber and FBQRegistrationNumber conditions[].field changed from
  @('RelatedHitSearchIndicator') (attribute name, PascalCase) to @('relatedHitSearchIndicator')  
  (form fieldId, camelCase). Casing mismatch made the NOT_EXISTS gate silently inert: when an  
  officer entered Hull ID + Stolen=Y with no State, FBQ fired alongside QB (union over-send).  
  Fix makes the gate live; FBQ now exits the pool when stolen indicator is filled.  
**REASON:** Caught by new verify_build.ps1 CHECK 13 (conditions[].field must reference QIF fieldId).
  Boat entity re-opened for live re-test.  

## v6.3 -- 2026-06-23 -- Label consistency

**CHANGED:** (1) Hull ID Number field hint removed (redundant with label).
  (2) "OOS" -> "out-of-state" on Boat BQ owner field labels.  
**REASON:** Post-v6.0 label consistency pass.

## v6.2 -- 2026-06-23 -- DH DOB label qualifier

**CHANGED:** DOB field label on DH card -> "DOB (required with Name)". Platform does not render
  helperText, so the conditional-required qualifier must be in the label itself.  
**REASON:** Usability audit -- DH DOB conditional requirement was invisible without helperText.

## v6.1 -- 2026-06-23 -- Name separator normalization

**CHANGED:** FormatStringRuleHandler separator for DL+DH Name (NameLast+NameFirst) changed to
  ', ' (comma-space). Wire now emits <Name>Doe, John</Name> per ConnectCIC devdoc. Order was  
  already Last-first (correct since v4.x); only the comma-space separator needed fixing.  
**REASON:** ConnectCIC devdoc "LAST, FIRST MIDDLE SUFFIX" format -- comma-space between Last and First.

## v6.0 -- 2026-06-23 -- Identifier-priority rollout + inert conditions fix + Attention handler

**CHANGED:** (1) Plate>VIN guardrail: LicensePlateNumber NOT_EXISTS added to FRQVehicleIdentificationNumber
  and RQVehicleIdentificationNumber. When Plate entered, VIN combos exit the union pool.  
  (2) Boat Hull>Reg guardrail: BoatHullIdNumber NOT_EXISTS added to FBQRegistrationNumber  
  (in-state FBQ family only; QB+BQ companion combos are dual-id, exempt).  
  (3) INERT STATE FIX: all conditions[].field @('State') -> @('RegistrationState') in every  
  FRQ/FDQ/FBQ combo (10 places). 'State' was the QIDM attribute name, not the form sourceField --  
  all those gates were silently inert (live-proven HI v3.3). With fix, FRQ/FDQ/FBQ conditions  
  are LIVE routing gates. ROUTING CHANGE -- full re-test of all primary paths required.  
  (4) ATTENTION auto-populate RESTORED: 'Attention' added to DH KQName+KQOperatorLicenseNumber  
  any[]; hidden gate-feeder InpH 'Attention' initialValue=X added to DH card. Uses HI v2.9  
  live-proven pattern (handler emits officer LastName FirstInitial from RMS profile).  
  (5) DL/DH OLN>Name guardrail already correct (no change needed).  
  (6) Labels: required/optional indicators; DH card retitled "Driver History (Out-of-State Only)".  
  (7) Officer guide regenerated (single-page portrait table format).  
**REASON:** Identifier-priority rollout (HI done; FL next). Inert conditions hazard resolved.
  Re-import + full re-test from T1.  

## v5.5 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.4 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.3 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.2 -- 2026-06-18 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.1 -- 2026-06-15 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v5.0 -- 2026-06-15 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.9 -- 2026-06-12 -- DH + Boat destination state: blank 2-char FormInput (kills inert FL guard)

**CHANGED:** 1) DH card: registrationStateDH FormSelect (attributeTypeId=STATE) -> blank
            FormInput maxLen=2, label "Destination State (2-letter, not FL)". Officer  
            must type the literal 2-letter destination code.  
         2) Boat Options card: registrationState same change, label "Destination State  
            (2-letter, blank for FL)".  
         3) DH QIDM + Boat QIDM State attributes: codeTypeProvider='NCIC' REMOVED  
            (FormInput supplies the literal code directly -- no UUID reverse-lookup).  
         4) Vehicle + Person-DL State fields UNCHANGED (NCIC dropdown pattern): their  
            conditions are presence-based NOT_EXISTS only, unaffected by the inert rule  
            (4 live PASSes v4.8).  
**REASON:**  LIVE FAIL (v4.8, 2026-06-12): DH KQOperatorLicenseNumber with Destination=
         Florida SENT despite NOT_EQUALS FL guard. INERT-CONDITION RULE (QIDM_REFERENCE  
         Sec 2a): conditions evaluate the RAW pre-reverse-lookup value; the live form-  
         state capture showed registrationStateDH="Florida" (display label, not the  
         2-letter code; XML still serialized State=FL), so EQUALS/NOT_EQUALS never see  
         the code the guard names.  
         A FormInput carries the literal value the officer typed, so NOT_EQUALS FL is  
         evaluated against a real 2-letter code. Boat BQ combos carry the same  
         NOT_EQUALS FL guards and the same dropdown -- fixed in the same pass.  
         CAUTION: guard comparison is presumed case-sensitive -- a lowercase "fl" may  
         slip past NOT_EQUALS 'FL'. Verify in live testing; if it slips, add an  
         uppercase rule handler or accept as LIMITATION.  

## v4.8 -- 2026-06-12 -- Conditions migrated to live-proven format (v4.7 conditions were inert)

**CHANGED:** ALL conditions (DL FDQ/DQ, DH KQ, Vehicle FRQ, Boat FBQ/QB/BQ) migrated from
         combo-level camelCase-fieldId scalar style to the CA_CLETS/NY live-proven wire  
         format: nested INSIDE requirements, field = ["AttributeName"], value = ["..."]:  
           "requirements": { "set": [...], "any": [...],  
             "conditions": [ { "field": ["State"], "operator": "NOT_EQUALS", "value": ["FL"] } ] }  
         Field references changed to QIDM attribute names (State, OperatorLicenseNumber,  
         RelatedHitSearchIndicator). test_commsys + run_test_matrix condition resolution  
         updated to attribute-name-first precedence. No combo/set/any/order changes.  
**REASON:**  LIVE EVIDENCE (v4.7 imported to USx Tenant 2026-06-12, first DL test): full DL
         card produced XML containing OLN + Name + DOB + Sex + Image -- the v4.7  
         NOT_EXISTS conditions had NO effect (neither routing nor pool filtering).  
         Test log: tests/_archive_pre_v4.8/2026-06-12_Person_DL-FullCard_FAIL_*.txt.  
         v4.7 conditions sat at COMBO level (sibling of requirements) with camelCase  
         fieldIds and scalar values -- a format never live-verified. The platform reads  
         conditions from requirements.conditions (CA_CLETS production JSON has 20 such  
         conditions, live-tested NOT_EQUALS State routing; NY DALHOUT/DALLOUT same).  
         IMPLICATION: FL v4.6's QB combo-level conditions (Stolen EQUALS Y) were  
         likely ALSO inert -- the Stolen=N fall-through was never live-tested. Now  
         migrated and must be live-verified.  
         CAUTION: NOT_EXISTS is KB-documented server-side but not yet live-proven by  
         any provider (CA uses EQUALS/NOT_EQUALS only). v4.8 live test must explicitly  
         verify it: full DL card -> expect OLN+Image only. If NOT_EXISTS turns out  
         unsupported, the devdoc-order + pool-isolation design needs a rethink (escalate  
         to platform team before inventing workarounds).  

## v4.7 -- 2026-06-12 -- DH out-of-state-only correction, devdoc combo order, pool isolation, BQ restore

**CHANGED:** 1) DriverHistoryQuery: registrationStateDH moved any[]->set[] on both KQ combos;
            conditions registrationStateDH NOT_EQUALS FL added to both; combos reordered  
            to devdoc order (KQName first); operatorLicenseNumberDH NOT_EXISTS added to  
            KQName; combo state property In/Out -> Out; NO initialValue, NO CAD defaults  
            on State. DH card title 'Driver History' -> 'Driver History (Out-of-State Only)';  
            registrationStateDH label 'State (leave blank for FL)' -> 'Destination State';  
            operatorLicenseNumberDH label 'License Number (DH)' -> 'OLN (DH)'.  
         2) DriverLicenseQuery: combos reordered to devdoc order (FDQName, FDQOLN, DQName,  
            DQOLN); conditions registrationState NOT_EXISTS on both FDQ combos;  
            operatorLicenseNumber NOT_EXISTS on both Name combos.  
         3) VehicleRegistrationQuery: combos reordered to devdoc order (FRQ Decal/Plate/  
            Title/VIN, then RQ Plate/VIN); conditions registrationState NOT_EXISTS on all  
            four FRQ combos.  
         4) BoatQuery: combos reordered to devdoc order (FBQ 1-4, QB 5-9, BQ 10-12);  
            conditions registrationState NOT_EXISTS on all FBQ combos, plus  
            relatedHitSearchIndicator NOT_EQUALS Y on FBQ Hull/Reg (replaces the v4.6  
            QB-first ordering; QB EQUALS Y conditions unchanged). RESTORED BQ x3  
            (BQName, BQBoatHullIdNumber, BQRegistrationNumber -- removed v4.4 in error)  
            with registrationState in set[] and NOT_EQUALS FL conditions; restored Boat  
            form fields nameLast/nameFirst/birthDate (search card, owner OOS row) and  
            registrationState ('Destination State' on Options card); restored Boat QIDM  
            attributes Name (FormatStringRuleHandler), BirthDate (date handler), State (NCIC).  
         5) Gun + Article combos already match devdoc order -- unchanged.  
         CommSys combos: 28 -> 31. QIDMs: 6 (unchanged).  
**REASON:**  a) FCIC documentation (relayed 2026-06-12): "Since the KQ is out of state and
            <XX> which denotes the destination is required, yes DriverHistoryQuery can  
            only be used out of state and would require the destination to be something  
            other than FL." Devdoc: State is the only Mandatory field; both KQ combos (Out).  
            The v3.8 initialValue=FL design was invalid (FL is not a legal destination);  
            the v4.3 single-JSON merge silently dropped that initialValue (undocumented  
            regression) which left State omittable entirely -- v4.6 KQ test XML shipped  
            with no State element. Destination must be an explicit officer choice: set[],  
            no default. CAD-dispatched DH cannot supply a destination and will not  
            auto-fire -- correct behavior.  
         b) USER DIRECTIVE (new standard): combo array order follows the devdoc  
            "Possible Combinations" listing order in every QIDM. Because devdoc lists  
            in-state combos first, routing conditions (State NOT_EXISTS / RelatedHit  
            NOT_EQUALS Y / OLN NOT_EXISTS) keep later OOS/stolen combos reachable under  
            first-match evaluation AND isolate the serialization pool (LIMITATION #1) so  
            a fully-filled card sends only the firing path's fields (fixes DL over-send).  
         c) BQ restore: devdoc Boat "Possible Combinations" 10-12 ARE the BQ paths and BQ  
            is not in the data-mined list. The v4.4 removal cited a devdoc "key list  
            (FBQ + QB only)" that does not exist -- the devdoc contains no key mnemonics  
            (zero occurrences of FBQ/BQ/KQ/FDQ/RQ/DQ); metadata MessageKey definitions  
            are the only key source, and combos are the build authority.  
         ASSUMPTION: BQ destination state NOT_EQUALS FL mirrors the FCIC KQ rule  
            (Out-routed Nlets). Pending FCIC confirmation; guard trivially removable.  
         PENDING: QV x2 (devdoc Vehicle combos 5-6) NOT built -- QV is in the devdoc  
            "Data-Mined Transactions" list (QA, QB, QG, QV, QW), believed to be CommSys  
            auto-sent secondary queries (QW precedent: platform-confirmed auto-send,  
            v4.2). Awaiting platform confirmation; if refuted, build QV via Stolen Search  
            toggle (Boat QB pattern) in v4.8.  
         APPROVED SKIP: ImageQuery is in devdoc Basic Queries Supported but excluded by  
            user PHASE 2 scope (6-query build).  
         NOTE: conditions in this build use camelCase fieldIds + scalar values (FL  
            live-tested style, QB v4.6), not KB attribute-name style.  

## v4.6 -- 2026-06-09 -- Boat QB conditions routing (Stolen Search EQUALS Y)

**CHANGED:** Added conditions on QB+Hull and QB+Reg combos:
         relatedHitSearchIndicator EQUALS Y. Stolen Search = N or blank  
         now falls through to FBQ (registration) instead of firing QB (stolen).  
**REASON:**  Without conditions, selecting "N" from the Stolen Search dropdown
         still fired QB because the platform treats any populated value as  
         meeting set[] requirements. Conditions check the actual value.  

## v4.5 -- 2026-05-27 -- Boat Stolen Search field type fix

**CHANGED:** relatedHitSearchIndicator on Boat OPTIONS card changed from FormInput
         (officer typed "Y") to FormSelect dropdown (YES_NO_UNKNOWN/NCIC = Y/N).  
         No initialValue — field is routing toggle between FBQ (registration) and  
         QB (stolen) combos. Label changed from "Stolen Search (Y)" to "Stolen Search".  
**REASON:**  Cross-provider consistency. All other providers (TX, NY) use FormSelect for
         this field. FormInput required officer to know to type "Y".  

## v4.4 -- 2026-05-27 -- Remove unauthorized queries (VehicleStolenQuery + BQ combos)

**CHANGED:** Removed FL_FCIC_VehicleStolenQuery QIDM and its 6 combos (QV by plate/VIN/PCN/NCIC#/OAN/PartSerial).
         Removed 3 BQ combos from BoatQuery (BQName, BQBoatHullIdNumber, BQRegistrationNumber).  
         Removed Vehicle form fields: ncicNumber, processControlNumber, ownerAppliedNumber, partSerialNumber.  
         Removed Boat form fields: nameLast, nameFirst, birthDate, registrationState.  
         Provider bundle: 9 configs (was 10). CommSys combos: 28 (was 37). QIDMs: 6 (was 7).  
**REASON:**  VehicleStolenQuery not in devdoc "Basic Queries Supported". QV key listed under
         VehicleRegistrationQuery, not as a separate query. BQ (Nlets OOS Boat) not in devdoc  
         key list (FBQ + QB only). Devdoc is the ONLY authority for which queries to build;  
         metadata existence does not equal authorization.  
VALIDATOR: 87P/0F/0W  
TEST CONDUCTOR: 28/28 PASS  

## v4.3 -- 2026-05-21 -- Single-JSON merge

**CHANGED:** Merged BASE/MC into single build: build_fl_fcic.ps1 → FL_FCIC.json (no suffix).
         Deleted old BASE build script. Reports now in docs/ (not docs/mc/).  
**REASON:**  BASE/MC split doubled maintenance; single-JSON is the standard.
VALIDATOR: 101P/0F/0W  
TEST CONDUCTOR: 47/47 PASS  

## v4.2 -- 2026-05-19 -- Remove WantedPersonQuery (QW) QIDM

**CHANGED:** Removed FL_FCIC_WantedPersonQuery QIDM and its 2 combos (QWOperatorLicenseNumber, QWName).
         Provider bundle: 10 configs (was 11). CommSys combos: 33 (was 35). QIDMs: 7 (was 8).  
**REASON:**  CommSys auto-sends QW query; no JSON-side QIDM needed. Confirmed by platform team.
VALIDATOR: BASE 97P/0F/0W | MC 97P/0F/0W  
TEST CONDUCTOR: BASE 43/43 PASS | MC 43/43 PASS  

## v4.1 -- 2026-05-15 -- MC multi-card: Vehicle (2 cards) + Boat (2 cards) + State label fix

**CHANGED:** MC Vehicle split into 2 cards: Options(State,Image) + Vehicle Search(all search fields).
         MC Boat split into 2 cards: Options(State,Stolen,Image) + Boat Search(all search fields).  
         MC Options cards titled "Options". State field labeled "State (leave blank for FL)".  
         BASE: removed "State (leave blank for FL)" label on Vehicle and Boat, now just "State".  
         QIDMs unchanged (35 combos, 8 QIDMs).  
**REASON:**  BASE single-card allows officers to accidentally route in-state queries (FRQ/FBQ)
         through OOS paths (RQ/BQ) by filling State. MC physically isolates State on a separate  
         Options card, preventing accidental routing. Multi-card is the standard build model.  
         Person was already 2-card (DL+DH) since v3.8. Vehicle and Boat were never split.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v4.0 -- 2026-05-13 -- Attention field: handler-only to visible FormInput (attentionDH)

**CHANGED:** Removed CommsysGetLastNameFirstNameInitialRuleHandler from DH Attention attribute.
         Changed sourceField from 'Attention'/'AttentionDH' to 'attentionDH'/'AttentionDH' (DH-suffix).  
         Added attentionDH/AttentionDH FormInput (maxLen=30) to Person DH card/section (BASE+MC).  
         Attention is now a user-editable field, not a server-side automation.  
**REASON:**  Field was automated without user approval. User directive: expose all fields as visible
         and only automate after live testing reveals need. Handler was filling with logged-in  
         user's name ("LASTNAME F") server-side — correct output but wrong design philosophy.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.9 -- 2026-05-12 -- MC Person layout: merge Search Options into DL card (2 cards)

**CHANGED:** Removed CARD_OPTIONS. Moved RegistrationState + ImageIndicator into CARD_DL row 1.
         Person now has 2 cards: Driver License (State+Image+OLN+Name+DOB+Sex) and Driver History.  
**REASON:**  With RegistrationStateDH on the DH card (v3.8), the Search Options card only served DL.
         Separate card was confusing — officers didn't know which card's fields affected which query.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.8 -- 2026-05-12 -- RegistrationStateDH: isolate DH State from DL routing

**CHANGED:** Added RegistrationStateDH field (FormSelect, STATE, initialValue=FL) on DH card.
         DH QIDM State attribute sourceField changed from RegistrationState to RegistrationStateDH.  
         KQ combo set[] changed from RegistrationState to RegistrationStateDH.  
         DL State (RegistrationState on Search Options card) remains blank — no cross-contamination.  
**REASON:**  Shared State field confused officers: blank=correct for DL (FDQ), but DH requires State.
         Filling State for DH caused DL to route OOS (DQ) instead of in-state (FDQ).  
         DH-suffix pattern extended to State — consistent with all other DH fields.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.7 -- 2026-05-12 -- Person State label fix for DH reachability

**CHANGED:** Person State label from "State (leave blank for FL)" to "State" (BASE + MC).
**REASON:**  DH KQ combos require State in set[] — label told officers to leave it blank,
         making DH unreachable. Neutral label allows DL (blank=FDQ) and DH (filled=KQ).  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.6 -- 2026-05-12 -- Metadata audit: PurposeCode any[], FRQ/QV field alignment, no PurposeCode default

**CHANGED:** DH combos: PurposeCode moved from set[] to any[] (metadata says optional).
         FRQ Plate/VIN: added VehicleMakeCode, VehicleYear to any[].  
         QV VIN: added RegistrationState to any[].  
         Removed PurposeCode initialValue='C' from Person form (both BASE and MC).  
**REASON:**  Full metadata audit against FL_FCIC_METADATA_REFERENCE.txt. Combos were
         stricter than metadata requires. PurposeCode default removed per user request.  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v3.5 -- 2026-05-12 -- One-directional queriesToDeselect fix + DH autoSelect

**CHANGED:** Removed queriesToDeselect from DL QIDM (was bidirectional with DH).
         Changed DH QIDM autoSelect from false to true (BASE only — MC already had true).  
**REASON:**  Bidirectional queriesToDeselect causes platform deadlock/error popup (confirmed NJ v2.3/v2.8,
         CA_CLETS v1.7). One-directional pattern: DL=default (autoSelect=true, no deselect),  
         DH=opt-in (autoSelect=true, deselects DL). Confirmed working on CA_CLETS v1.8 (18/18 PASS).  
VALIDATOR: BASE 102P/0F/0W/0LIM | MC 102P/0F/0W/0LIM  

## v2.6 -- 2026-04-22 -- ATTENTION FIELD FIX -- match CA_eSUN / LA_LEMS pattern


## v3.0 -- 2026-05-01 -- COMPLETE REBUILD -- 8-QIDM merged architecture


## v3.1 -- 2026-05-07 -- Monorepo rebuild + Patch 8 + VehicleMakeCode fix


## v3.4 -- 2026-05-11 -- LIMITATION elimination pass

