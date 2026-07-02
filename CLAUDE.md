# USx Provider JSON - Consolidated Monorepo

All ConnectCIC provider JSON configurations, knowledge base, and shared tools in a single repo. All new provider projects go here using the same file and build structure as existing providers.

Owner: rob.sgambellone@mark43.com
Consolidated: 2026-05-04

## Repo Structure

```
providers/{PROVIDER}/     -- 20 providers (8 active + 11 new + 1 CCH stub)
knowledge-base/           -- Build rules, anti-patterns, platform limitations
tools/                     -- Shared scripts (validator, renderers, simulators)
```

## Provider Status (updated 2026-07-02)

| Provider | Path | Version | Status | Notable patterns |
|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS/ | v4.8 | 61P/0F/0W/0LIM -- v4.8 (2026-07-01): Metadata-driven keyRef rename -- DQ/DQN/RQ/RQN did not exist in NJ's devdoc (confirmed against raw devdoc XML, not just generated METADATA_REFERENCE.txt); DriverLicenseQuery DQ->FULL, DQN->FULLN (devdoc keyReference is FULL for both combos); VehicleRegistrationQuery RQ->RANDFULL, RQN->RANDFULLN (devdoc defines 4 combos under keyReference RAND and FULL, each identical Set/Any per identifier -- one merged physical combo per identifier required; compound name reflects both). Re-import + full re-test from T1. v4.7 (2026-06-26): VehicleMakeName code source corrected VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present; matches RND-54190 runbook + sibling VehicleModelName); fixes Newark vehicle "Mock results processed". Shared module _build_rms_bundle.ps1; NJ rebuilt only (other 4 live providers tabled). Re-import + full re-test from T1. v4.6 (2026-06-25): Removed top-level version field (platform deserializes as java.lang.Integer; rejects dotted string format). All T1-T29 PASS. v4.5 (2026-06-24): VehicleMakeName QRDM fix -- vehicle make was resolved via codeTypeCategory NCIC_FIREARM_MAKE/codeTypeSource NJ_NIBRS (FIREARM makes, AP #24); corrected to codeTypeSource VEHICLE / codeTypeCategory VehicleType (user-verified vs platform registry). Shared-module change (Build-CommsysQrdm) -- propagates to all providers on their next rebuild. Re-opens Vehicle response; full re-test + re-import (USx + Newark) required. v4.4 (2026-06-23) GAP-AUDIT: Boat Hull>Reg guardrail added to QB combo (BoatHullIdNumber NOT_EXISTS, PascalCase sourceField -- Hull+Reg co-entry no longer bleeds Reg into Hull XML); VehReg RQN synthetic-keyRef doc added (CHECK 9). verify_build CLEAN, audit_cad 51P/0F, conductor 18/18. Re-import to USx test + Newark Foundation. v4.2 NATIVE PascalCase USx fieldIds (Convert-UsxCasing post-transform REMOVED -- it collapsed Craft.js `nodes` arrays to scalars/null and broke form rendering; form now renders); RMS via Build-RmsBundle -PascalCaseUsxFields; v4.0 VehStolenRemoved+restored RMS args; v4.1 M/C/O-derived field labels + DQN State fix; NOT yet imported, test pkg reset to T1 | VehicleStolenQuery NOT built (USER-APPROVED skip; state auto-runs QV, response data-mined via QRDM); VehReg 2 combos (RANDFULL/RANDFULLN, formerly RQ/RQN -- v4.8 metadata-driven rename), poisoned-array RandomRequest=Y conditions removed (RandomRequest user-controlled in any[]); DriverLicense 2 combos (FULL/FULLN, formerly DQ/DQN -- v4.8 rename); PascalCase USx fieldIds (CAD/OnScene), Mark43/RMS keys stay camelCase; RMS handler args restored (fixed _R $args collision, matches HIDLE baseline); CAD combo defaults; NCIC state; shared RMS module, RMS Vehicle stripped to 3 attrs; v4.1: labels via suggest_field_labels.ps1 (required/optional from combos) + DQN State moved set[]->any[]+default NJ (was over-required vs metadata) |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v4.7 | 66P/0F/0W/0LIM -- v4.7 (2026-07-02): NJ/CA-parity modernization -- retired phases/ (git history is the version authority), migrated docs/ to the 4-category structure (tracking/reports/reference/deliverables), transitioned tests/ -> logs/<Entity>/. keyRef-vs-devdoc audit CLEAN: every base keyRef is a real HI XML-metadata MessageKey (RQ/M55L/M55S/DQ/QW/KQ/QG/QA/BQ/QB); the three not in the MessageKey list -- RQV/DQN/KQN -- are documented synthetic disambiguations of metadata combos that SHARE a keyReference (RQ x2 plate+VIN, DQ x2 OLN+Sex, KQ x2 OLN+Name), each suffixed off HI's own base term (LIMITATION #21, verify CHECK 9 PASS). This is NOT the NJ-class bug (NJ's base terms themselves were wrong vs its devdoc; HI's are all correct). In-state reachability: CHECK 16 (added post-v4.6 with CA v2.11) caught a latent shadow -- RQ (OOS plate) / RQV (OOS VIN) were ordered before M55L/M55S and, because the platform fires on primaryFieldReference (not set[]) presence, shadowed the in-state combos on a bare plate/VIN (the old "set[] needs Plate Type/Year so RQ won't fire on a bare plate" reasoning was wrong). FIXED with OOS gates -- LicensePlateTypeCode EXISTS on RQ, RegistrationState EXISTS on RQV -- symmetric to M55L/M55S's NOT_EXISTS gates (FL v7.0 / CA v2.11 OOS-gate pattern): bare plate->M55L, Plate+Type->RQ, bare VIN->M55S, VIN+State->RQV, all mutually exclusive + reachable. DL/DH/Boat carry optional State in any[] with no OOS gate -- no shadow there. JSON vs v4.6: JSON key-order refresh from current shared modules (harmless) PLUS the Vehicle OOS-gate conditions above; the other 4 entities (Person/Firearm/Article/Boat) are unchanged (fingerprints identical -> their prior blocks carry over). Vehicle re-test required. Stale header comments corrected (VehReg is 4 combos not 6 after v4.4 QVP/QVV removal; name format is Last-first per v4.0). Re-import + full re-test from T1. v4.6 (2026-06-26): VehicleMakeName result-mapping code source corrected VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present; matches RND-54190 runbook + sibling VehicleModelName; shared module; result-mapping only, request-side unchanged) + Vehicle State label -> 'State (leave blank for Hawaii)' for verify CHECK 15; re-import + full re-test from T1. v4.5 (2026-06-25) Removed orphaned VehicleMakeCode (Make) field: per metadata Make is valid ONLY for the QV stolen combo (removed v4.4), so with no surviving combo to serialize it the VIN-card Make dropdown was dead config (live-proven v4.4: Make entered, absent from XML both fires). Removed the attribute + form field (Vehicle Year now full-width on its row); Vehicle re-opens for retest. v4.4 (2026-06-25) QVP/QVV stolen combos REMOVED: deleted the two dormant stolen combos (QVP plate+state, QVV VIN+MakeCode) from VehicleRegistrationQuery (now 4 combos: RQ/RQV/M55L/M55S). Live v4.3 test found that CLEARING the Vehicle Type dropdown on a Plate+State query fired QVP (MessageKey=QV, stolen) -- M55L could not fire without VehicleTypeCode and RQ needed Plate Type/Year, so QVP caught it. They should never fire from the form (state CommSys auto-generates QV, data-mined via QRDM), so removed outright rather than made hard-dormant via a self-contradicting NOT_EXISTS-on-own-set guard (verify_build CHECK 14 flags that as a dead combo). Vehicle re-opens for retest; other 4 entities' fingerprints unchanged (blocks carry over). Accepted tradeoff: Plate+State with Vehicle Type cleared and no Plate Type/Year now fires nothing. v4.3 (2026-06-25) NJ-parity galvanization: versioned root filename (HI_HCJDC_OFML_v4.3.json); removed the import-breaking top-level version field; stamped the version into all 3 bundle descriptions (description-first, near-top); added per-provider changelog; pruned stale phase dirs. Metadata/cosmetic only -- entity fingerprints unchanged, 5 confirmed entities carry over. v4.2 (2026-06-24) reproducibility rebuild: VehicleMakeName QRDM fix (codeType VehicleType/VEHICLE; was firearm-make table NCIC_FIREARM_MAKE/NJ_NIBRS) from current shared modules -- committed v4.1 was deterministic but STALE per audit_reproducible.ps1; query/combo behavior unchanged (entity fingerprints identical). v4.1 (2026-06-23) GAP-AUDIT: CAD Attention-default added to KQ/KQN (handler value was dropped from CAD-dispatched DH); CAD vehicleTypeCode=1 default added to M55L/M55S (in-state CAD vehicle queries fired without the required VehicleTypeCode); stale "NCIC unconfirmed" note removed; orphaned BASE/MC test matrices deleted. verify_build CLEAN (14 checks), audit_cad 61P/0F, conductor 28/28. v4.0: Name-order fix -- HI was the lone outlier of 20 providers (built Name First-first -> malformed "FIRST LAST MIDDLE SUFFIX"); both DL+DH Name attrs now @('NameLast','NameFirst',...) + args @(', ',' ',' ') -> ConnectCIC-preferred "LAST, FIRST MIDDLE SUFFIX" (devdoc). Re-opens Person+DH for live re-test. v3.9: identifier-priority guardrail EXTENDED to BoatQuery (Hull>Reg) -- BQ (RegistrationNumber) gets BoatHullIdNumber NOT_EXISTS so Reg# exits the pool when a Hull ID is entered (Hull is the unique permanent id; Reg# reassignable). Third identifier pair closed (Vehicle Plate>VIN v3.6, Person OLN>Name DL v3.7/DH v3.8, Boat Hull>Reg v3.9). Re-opens Boat for live re-test. v3.8: OLN>Name guardrail EXTENDED to DriverHistoryQuery -- OperatorLicenseNumberDH NOT_EXISTS added to KQ so the DH Name combo exits the union pool when a DH OLN is entered (closes the DH-side gap left by v3.7; sim-proven KQ+KQN union over-send when both filled); DL guardrail (T6/T8) live-confirmed v3.7. v3.7: OLN>Name guardrail on Person (DriverLicenseQuery) -- OperatorLicenseNumber NOT_EXISTS added to DQ (Name+Sex+DOB) and QW (Name+DOB) so the Name combos exit the union pool when an OLN is entered (Name/Sex/DOB do not bleed onto the wire); completes the identifier-priority guardrail for HI (Vehicle plate-wins done v3.6); conditions[].field=sourceField (PascalCase); re-opens HI Person for live re-test. v3.6 FIX: Plate-wins guardrail: LicensePlateNumber NOT_EXISTS condition added to RQV, QVV, M55S. When Plate in form state, all VIN-path combos exit the union pool (all-fields stress test: RQ+RQV+QVV co-fired, VIN+MakeCode bled into plate XML). M55S now has two conditions (RegistrationState + LicensePlateNumber both NOT_EXISTS -- fires only for bare VIN). vehicleYear any[] gap fixed: added 'vehicleYear' to RQV/M55S/QVV any[] (attribute existed in QIDM but in no combo any[], silently dropped from all VIN XML). v3.5 FIX: GunQuery/ArticleSingleQuery/BoatQuery any[] gap -- RelatedSearchHitIndicator (default=Y) and optional fields (GunMake/Caliber/Model, Boat RegistrationState) were not in any[], so platform serialized only set[] fields. Added to any[] + default Y on all three QIDMs. v3.4 FIX: removed RegistrationState from M55S any[] (semantic contradiction -- M55S only fires when RegistrationState NOT_EXISTS, so State can never serialize alongside it; the any[] entry caused the test conductor to inject State="NJ" into minimal data and falsely block M55S firing). M55L UNCHANGED (its condition is LicensePlateTypeCode, so State rides along on in-state plate queries). v3.3 FIX: M55S conditions[].field corrected from 'State' (attribute name) to 'RegistrationState' (sourceField). T5 showed VehicleTypeCode still bled into RQV XML because conditions[].field must match the form sourceField, not the attribute name. M55L worked in T4 only because LicensePlateTypeCode is both the attribute name and sourceField. Rule corrected in KB: conditions[].field = sourceField. v3.2 Vehicle State label shortened to 'State (Hawaii = leave blank)' (label-only refinement of v3.0, pre-live-test). v3.0 VEHICLE OOS-FIRST ROUTING: reordered VehicleRegistrationQuery combos (RQ-plate, RQV VIN+State, M55L, M55S, dormant QVV/QVP) so out-of-state is reached by ADDING fields (Plate Type+Year for plate, State for VIN), never by clearing Vehicle Type (the v2.8 clear-to-switch UX confused officers). RQV now requires VIN+State (State in set[], NY pattern); removed Plate Year default; relabeled Vehicle Type ('Auto (Hawaii queries)') + State ('blank for Hawaii; enter the state for out-of-state'). Person UNCHANGED (stays blocked, fingerprint preserved across rebuild). v2.9 ATTENTION RESOLVED: auto-populates officer name (LastName FirstInitial from RMS profile) via CommsysGetLastNameFirstNameInitialRuleHandler. Root cause (live-proven 2026-06-22): platform serializes ONLY fired-combo set[]/any[] fields, and Attention was never in any[]; fix = Attention in KQ/KQN any[] + sourceField=['Attention'] + hidden gate-feeder field populated (handler emitted 'SGAMBELLONE R'). NOT sourceField=[] (rejected at import here). v2.8 Vehicle 3-card redesign (SEARCH OPTIONS / PLATE SEARCH / VIN SEARCH); in-state-primary combo order (M55L/M55S first); removed Plate Type/Year form defaults so a bare plate routes in-state; RegistrationState added to any[] on M55L/M55S/QVV (State rides along); QVP/QVV dormant (state CommSys auto-generates QV); pointed labels; (tooling) entity-aware test block-out -- per-entity fingerprint reset (get_entity_fingerprints.ps1 / block_entity.ps1 / .test_state.json); v2.7 hidden Attention gate-feeder field (InpH 'Attention' initialValue=X on DH card) so the auto-Attention handler's sourceField resolves and it serializes the officer profile name; verify_build CHECK 8 whitelists hidden Attention; EXPERIMENTAL -- verify live at T9/T10 whether Attention=officer name (handler ignores value) or =X (echoes); re-import + re-test from T1; v2.6 REVERTED Attention sourceField to @('Attention'): ConnectCic REJECTS empty sourceField at import ("Invalid attributes ... [Attention]", HI v2.5 import 2026-06-22); KB RULE_HANDLERS entry 13 corrected; Attention auto-populate believed INERT (SUPERSEDED by v2.9 -- real cause was Attention missing from DH any[], now fixed); v2.5 (empty sourceField) unimportable; re-import + full re-test from T1, test pkg reset; v2.4 NATIVE PascalCase USx fieldIds (RMS via Build-RmsBundle -PascalCaseUsxFields; was camelCase through v2.3); consolidated single JSON (v1.8); v2.3 DQ primaryFieldReference Name->SexCode (metadata-aligned, clears CHECK 5) + docs/mc removed; NOT yet imported, test pkg reset to T1 | 6 basic queries (Article/Boat/DH/DL/Gun/VehReg), 17 combos all reachable; single JSON; Person 3 cards (Search Options[State] + Driver License + Driver History, DH-suffix, one-directional deselect); Vehicle/Boat/Firearm/Article 1 card; Type Code dropdown (VEHICLE_TYPE/HI_NIBRS) per HIDLE ref; ImageIndicator=N combo defaults on all 6 VehReg combos (real CAD fix -- not card count); State in DL/DH any[] + VehReg RQ/RQV any[] for OOS (v2.2); labels: M/C/O-derived field hints + short card titles (DH Sex=required-with-Name, PurposeCode=optional) |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v4.0 | 81P/0F/0W/0LIM | PascalCase (v4.0), 7 cards (Veh 1, Per 3+2 fields, Gun 1, Art 1, Boat 1), 17 combos, 7 QIDMs, DGRP (DL Name Search), DH OOS combos (DALHOUT/DALLOUT) with State EXISTS/NOT_EXISTS routing (v4.0, replaces inert value-comparison conditions), Vehicle plate OOS combo (RVEHOUT), NyNyspinTransactionName visible on DH (default DALL), PurposeCode default C on DH OOS combos, Choice-set OOS pattern (LIMIT #36), DH-suffix+one-directional queriesToDeselect, CAD defaults all 17 combos, State no-default (LIMIT #30), identifier-priority guardrails v4.0 (Plate>VIN, OLN>Name DL+DH, Hull>Reg) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v2.3 | 71P/0F/0W/0LIM (BASE) 71P/0F/0W/0LIM (MC) | dexStateUserId, DH-suffix, WMPI queries, hidden badge |
| FL_FCIC | providers/FL_FCIC/ | v7.1 | 92P/0F/0W/0LIM -- 31/31 combos, 6 QIDMs -- v7.1 (2026-06-30): Boat Hull>Reg guardrail completed for FBQ in-state family -- RegistrationNumber removed from any[] of FBQBoatHullIdNumber/FBQDecalNumber/FBQTitleLienInformation (LIMITATION #1 union over-send: when Hull fires and Reg is in the form, any[] contents are serialized regardless of FBQRegistrationNumber's BoatHullIdNumber NOT_EXISTS guard; T48 FAIL confirmed live). QB/BQ families already fixed v6.9. Re-import + full re-test from T1. v7.0 (2026-06-29): OOS-gate symmetry hardening (defense-in-depth, NO behavior/XML change). Added RegistrationState EXISTS to the 3 zero-condition OOS combos -- RQLicensePlateNumber + DQOperatorLicenseNumber (RegistrationState) + KQOperatorLicenseNumber (RegistrationStateDH). These were the only combos in Vehicle/Person relying on set[] alone with no condition; set[] is NOT a firing gate, so explicit OOS-routing mirrors the in-state State NOT_EXISTS gates and the Boat QB relatedHit EXISTS (v6.9). Rule: in-state => State NOT_EXISTS; OOS => State EXISTS. Reevaluation found Vehicle (Plate>VIN) + Person (OLN>Name) had NO bleed + NO active shadow (CHECK 12/14/16 already PASS) -- this is reorder-safety, not a fix. Sim-verified routing unchanged (5 scenarios). Re-import + full re-test from T1. v6.9 (2026-06-29): Boat Hull>Reg guardrail EXTENDED to QB (stolen) + BQ (OOS) families -- QBRegistrationNumber/BQRegistrationNumber converted from companion to gated (BoatHullIdNumber NOT_EXISTS + Hull removed from any[]); QBBoatHullIdNumber/BQBoatHullIdNumber de-bled of RegistrationNumber. ALSO relatedHitSearchIndicator EXISTS added to QBBoatHullIdNumber+QBRegistrationNumber (explicit Stolen gate -- set[] is not a firing gate; killed latent QB->BQ shadows surfaced by verify_build CHECK 16, same pattern as CA_CLETS NLTS.DQ v2.11). Sim-verified all 4 Hull/Reg routing scenarios (Hull+Reg+Stolen, Reg+State, Hull+State, Hull+Reg+State). FBQ already gated v6.0. Re-import + full re-test from T1. v6.8 (2026-06-29): VehicleMakeName QRDM code source corrected VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; shared module propagation; matches NJ v4.7/HI v4.6/CA v2.10; fixes FL vehicle "Mock results processed" in RMS). Re-import + full re-test from T1. v6.7 (2026-06-25) NJ/HI-parity galvanization (reopened DEX-971): REMOVED the import-breaking top-level version field (v6.6 adopted it; platform rejects dotted string as Integer -- v6.6 was unimportable); versioned root filename FL_FCIC_v6.7.json; version stamped into all 3 bundle descriptions (-Description on Build-EntitiesBundle/Build-RmsBundle); per-provider CHANGELOG_FL_FCIC.md. Structural only -- no QIF/QIDM/combo/conditions change, entity fingerprints identical to v6.6. Full re-test from T1 (re-import). HI-specific fixes NOT applied (QVP/QVV removal, Make-field removal, First->Last name order -- all N/A to FL). v6.6 (2026-06-24) reproducibility rebuild: adopt top-level version field + VehicleMakeName QRDM fix (codeType VehicleType/VEHICLE; was firearm-make table NCIC_FIREARM_MAKE/NJ_NIBRS) from current shared modules -- committed v6.5 was deterministic but STALE per audit_reproducible.ps1; query/combo behavior unchanged (entity fingerprints identical). v6.5 (2026-06-23) GAP-AUDIT: CAD Attention-default added to KQName/KQOperatorLicenseNumber DH combos (handler value was dropped from CAD-dispatched DH); CAD plate-default gap fixed (FRQDecalNumber + RQLicensePlateNumber require PlateYear/PlateType in set[] -- added LicensePlateYear=$currentYear + PC defaults); header conditions comment corrected (field=sourceField not attr name). verify_build CLEAN, audit_cad 83P/0F, conductor 42/42. v6.4 (2026-06-23) FIX: FBQBoatHullIdNumber + FBQRegistrationNumber conditions[].field 'RelatedHitSearchIndicator' -> 'relatedHitSearchIndicator' (casing mismatch made the NOT_EXISTS gate silently inert -- Boat stolen=Y + no State co-fired FBQ+QB union; now FBQ exits pool correctly). CHECK 13 root-cause. v6.3 (2026-06-23) label consistency: Hull ID Number hint removed; OOS->out-of-state on boat owner fields. v6.2 (2026-06-23) DH DOB label -> "DOB (required with Name)" (helperText not rendered on platform; qualifier stays in label). v6.1 (2026-06-23) Name separator normalized to comma-space (wire <Name>="Doe, John" per devdoc; order already Last-first). v6.0 (2026-06-23) identifier-priority rollout + flagged fixes + new labels + officer guide: Vehicle Plate>VIN guardrail (LicensePlateNumber NOT_EXISTS on FRQ/RQ VIN combos); Boat Hull>Reg guardrail on FBQRegistrationNumber (FBQ in-state only; QB/BQ keep Hull+Reg companions); INERT STATE FIX -- all conditions[].field @('State')->@('RegistrationState') (were attr-name-keyed + silently inert; now LIVE, isolate in-state FRQ/FDQ/FBQ from OOS RQ/DQ -- ROUTING CHANGE, sim-verified); ATTENTION auto-populate restored via HI v2.9 pattern (Attention in DH any[] + hidden gate-feeder; reverses prior INERT note); DL/DH OLN>Name already correct; new labeling convention (required/optional/search-path hints) + single-page officer guide; re-import + full re-test from T1; v5.5 REVERTED Attention sourceField to @('Attention') (v5.4 emptied it; ConnectCic REJECTS empty sourceField at import -- live-proven HI v2.5); v5.3 Attention auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler (no visible field; automated-Attention standard, BUILD_RULES Sec 14) -- re-import + full re-test required, test pkg reset to T1; v5.2 NATIVE PascalCase USx fieldIds (was camelCase through v5.1; RMS via Build-RmsBundle -PascalCaseUsxFields) -- RE-IMPORT + full re-test required, test pkg reset to T1; v5.1 IMPORTED to USx Tenant, full matrix T1-T42 PASS 2026-06-15 (camelCase; one-directional deselect + co-fire pool isolation confirmed); (v4.9 T-A/T-B: value-comparison conditions proven wholly inert -> POISONED-ARRAY RULE, QIDM_REFERENCE Sec 2a) | 2-card: Vehicle(Options+Search), Person(DL+DH OOS-only), Boat(Options+Search). Devdoc combo order + EXISTENCE-ONLY routing conditions (State NOT_EXISTS / OLN NOT_EXISTS / RelatedHit NOT_EXISTS) for first-match + pool isolation; ALL value-comparison conditions removed v5.0 (poisoned-array, live-proven T-A/T-B 2026-06-12), DH KQ out-of-state only (State in set[], no default; not-FL gate = LIMITATION + platform escalation, NOT enforceable config-side), DH+Boat destination state = NCIC dropdown restored v5.0, Boat QB stolen routing via relatedHitSearchIndicator in set[], BQ x3 restored, QV pending data-mined confirmation, one-directional queriesToDeselect, Attention auto-populated (handler), RMS Vehicle stripped to 3 attrs, RMS union-pool over-send fix designed but GATED (G1 impact / G2 handler verification) |
| TX_TLETS_CCH | providers/TX_TLETS_CCH/ | v1.0 | 119P/0F/0W -- STUB: 14 QIDMs (6 base + 8 CCH) | Separate CCH-gated provider. Base 6 QIDMs ported from TX_TLETS. All 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) on Person, autoSelect=false (named-checkbox via queryLabel), every CCH field CCH-suffixed (full isolation, zero collision), 3 CCH cards. Synthetic keyRefs (QH/QR/QWI/ZR) + Choice splits. FreeText capped display. CCH response QRDM out of scope. NOT live-tested |
| TX_TLETS | providers/TX_TLETS/ | v3.13 | 83P/0F/0W/0LIM -- v3.13 (2026-06-23) GAP-AUDIT REMEDIATION: Hull>Reg guardrail COMPLETED (added boatHullIdNumber NOT_EXISTS to BQRegistrationNumber -- v3.12 only gated in-state QBRegistrationNumber, OOS BQ still bled Reg into Hull XML; found once CHECK 12 promoted WARN->FAIL); CAD plate-default gap fixed (REG/RQ plate combos require licensePlateYear/licensePlateTypeCode in set[] but CAD ignores initialValue -- added LicensePlateYear=$currentYear + RQ LicensePlateTypeCode=PC defaults; surfaced by audit_cad CHECK 6 set[]-scan fix). 24 CommSys combos. verify_build CLEAN (14 checks), audit_cad 76P/0F, conductor 37/37. re-import + full re-test from T1, test pkg reset. v3.12 (2026-06-23) IDENTIFIER-PRIORITY ROLLOUT + ATTENTION RESOLVED: all 3 guardrail pairs -- Plate>VIN (licensePlateNumber NOT_EXISTS on VIN/RQ/QV), OLN>Name DL (DQName/QWName/CPLName) + DH (KQNameImg/KQName), Hull>Reg (QBRegistrationNumber). ATTENTION RESOLVED via HI v2.9 pattern ('Attention' in all 4 DH combo any[] + hidden InpH gate-feeder + Attention=X default). v3.11: REVERTED Attention sourceField to @('Attention'); v3.8: 4-combo DH (image-variant split). v3.11: REVERTED Attention sourceField to @('Attention') (v3.10 emptied it; ConnectCic REJECTS empty sourceField at import); v3.9: Attention auto-populated via CommsysGetLastNameFirstNameInitialRuleHandler; v3.8: restore 4-combo DH (image-variant split); Image=Y serializes only when email present (union-exclusion) | 6 cards (Veh 1, Per 3 DH+DL+Options, Gun 1, Art 1, Boat 1), 24 CommSys combos, 6 QIDMs, identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg on both QB+BQ Reg combos), DH image-variant split (KQNameImg/KQName/KQOLNImg/KQOLN), email→shared OPTIONS card, CPL Name combo, Attention auto-populate (gate-feeder), CAD plate defaults (PlateYear/PlateType on REG/RQ), DH-suffix+one-directional queriesToDeselect, TX-specific (DPSI/REG/VIN+FRT), -SkipRace on RMS |
| LA_LEMS | providers/LA_LEMS/ | v2.5 | 63P/0F/0W/0LIM (BASE) 63P/0F/6W/0LIM (MC) | DH-suffix+queriesToDeselect, Attention handler (AP #27), DP/DQ routing toggle, State in set[], State no-default |
| CA_CLETS | providers/CA_CLETS/ | v2.12 | 77P/0F/0W/0LIM -- v2.12 (2026-07-01): RESTORED in-state DL combos ID.L1 (OLN) + IN.L1 (name), DL 6->8. v2.11 removed them expecting "CommSys auto-dispatches, consistent with Vehicle pattern" -- but Vehicle keeps an unconditioned in-state catchall (IA.QV/IA.QVK) and DL kept none, so a plain in-state driver lookup (OLN-only/name-only, no State) fired nothing. Restored as gated catchalls (real devdoc keyRefs); IR.QVC.O += criminalIdNumber EXISTS, IR.QVC.N += RegistrationState NOT_EXISTS + SexCode EXISTS for mutual exclusion; verify_build CHECK 16 reachability CLEAN. v2.11 (2026-06-29): IN.L1 (name in-state) + ID.L1 (OLN in-state) removed from DriverLicenseQuery -- CommSys auto-dispatches pure (In) queries, consistent with Vehicle pattern (Vehicle (In) combos 1-3 also not built); RegistrationState EXISTS condition added to all 6 NLTS combos (NLTS.DQ/NLTS.DQ.N/NLTS.RQ.V/NLTS.BQ.N/NLTS.BQ.H/NLTS.BQ.R) -- platform fires on primaryFieldReference presence, not all-set[] presence; without this NLTS combos shadowed in-state equivalents; verify_build CHECK 16 (combo reachability/shadow detection) added to pipeline. v2.10 (2026-06-26): VehicleMakeName result-mapping code source corrected VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365). | purposeCode (CAD-aligned fieldId), DH-suffix fieldIds, cross-entity Name on Veh/Gun/Boat, no ImageIndicator, 6 basic queries, yyyyMMdd dates, CAD defaults on IA.QV. DL: 8 combos (NLTS.DQ.N/DQ + IR.QVC.N/O/C/S + in-state ID.L1/IN.L1). RegistrationState EXISTS guards all NLTS combos. OLN cascade: OLN+State->NLTS.DQ, OLN+CII->IR.QVC.O, OLN-only->ID.L1. Name cascade: Name+State->NLTS.DQ.N, Name+Sex->IR.QVC.N, Name-only->IN.L1. CII->IR.QVC.C, SSN->IR.QVC.S. |
| CA_VENTURA_COUNTY | providers/CA_VENTURA_COUNTY/ | v1.4 | 68P/0F/0W (BASE) 72P/0F/0W (MC) | 6 basic queries, CaRequestPurposeCode (visible Inp), DL+DH DH-suffix+queriesToDeselect, MC cross-entity (IN.VP/IG.QGH/NLTS.BQ.N) |
| CA_CONTRA_COSTA | providers/CA_CONTRA_COSTA/ | -- | INCOMPLETE -- metadata has only JAWS person queries, no OLN, no Vehicle/Boat/Gun/Article; CLETSPersonSuperQuery in devdoc but NOT in metadata; waiting for updated docs | 2 transactions (6 combos), Person only, RequestingAgencyId on all combos |
| CA_CLETS_OCATS | providers/CA_CLETS_OCATS/ | v1.2 | 63P/0F/0W/0LIM (BASE) 63P/0F/0W/1LIM (MC) | CLETS_OCATS v21, 5 basic queries (no DH), VP owner search, 19 combos, OCATS-specific queries available (warrants, juvenile, LARS) |
| CA_eSUN | providers/CA_eSUN/ | v1.5 | 71P/0F/0W/0LIM (BASE) 71P/0F/1W/2LIM (MC) | CaRequestPurposeCode (visible Inp), VP owner search, gun-by-name, Attention handler, MC multi-card (14 cards) |
| CA_SAN_LUIS_OBISPO | providers/CA_SAN_LUIS_OBISPO/ | v1.3 | 65P/0F/0W (BASE) 65P/0F/0W (MC) | Regional interface, DL+DH DH-suffix+queriesToDeselect, short keyRefs, MC multi-card (15 cards) |
| IL_LEADS_OFML | providers/IL_LEADS_OFML/ | v1.1 | 61P/0F/0W/0LIM (BASE) 61P/0F/0W/1LIM (MC) | 5 basic queries (no DH), Z2/Z5 keyRefs, MC multi-card (11 cards) |
| MD_METERS | providers/MD_METERS/ | v1.3 | 69P/0F/0W/0LIM (BASE) 69P/0F/0W/1LIM (MC) | 6 basic queries, DH-suffix+queriesToDeselect, ZVEH/ZLRG/ZDRV invented keyRefs, MC multi-card (12 cards), State no-default |
| OH_LEADS | providers/OH_LEADS/ | v1.3 | 77P/0F/0W/0LIM (BASE) 77P/0F/1W/4LIM (MC) | 6 basic queries, 9 VehReg combos, BMVIMS, owner search (RN), MC multi-card (14 cards) |
| NM_NMLETS_OFML | providers/NM_NMLETS_OFML/ | v1.3 | 66P/0F/0W/0LIM (BASE) 66P/0F/0W/1LIM (MC) | 6 basic queries, DH-suffix+queriesToDeselect, GunModel field, MC multi-card (12 cards) |
| OR_LEDS | providers/OR_LEDS/ | v1.3 | 58P/0F/0W/0LIM (BASE) 58P/0F/0W/0LIM (MC) | 5 basic queries (no DH), invented keyRefs, MC multi-card (11 cards) |
| TN_TIES | providers/TN_TIES/ | v1.4 | 80P/0F/0W/0LIM (BASE) 80P/0F/1W/3LIM (MC) | 6 basic queries, 28 combos, no State initialValue, MC multi-card (14 cards), DH-suffix |

## Legacy Repos (READ-ONLY)

Individual repos are preserved for history but are now read-only. All active work happens here.

- [NJ_NJCIS_JSON](https://github.com/LooseConnection/NJ_NJCIS_JSON) (LooseConnection)
- [HI_HCJDC_OFML](https://github.com/Robsgam/HI_HCJDC_OFML) (Robsgam)
- [NY_NYSPIN_EJUSTICE](https://github.com/Robsgam/NY_NYSPIN_EJUSTICE) (Robsgam)
- [AZ_AZDPS](https://github.com/Robsgam/AZ_AZDPS) (Robsgam)
- [CA_CLETS](https://github.com/Robsgam/CA_CLETS) (Robsgam)
- [FL_FCIC_JSON](https://github.com/LooseConnection/FL_FCIC_JSON) (LooseConnection)
- [TX_TLETS_JSON](https://github.com/LooseConnection/TX_TLETS_JSON) (LooseConnection)
- [LA_LEMS (formerly LA_LETTS_OFML)](https://github.com/LooseConnection/LA_LETTS_OFML) (LooseConnection)
- [ConnectCIC-KB](https://github.com/Robsgam/ConnectCIC-KB) (Robsgam)

---

## Build Model — Single JSON, Multi-Card from Start

One build script per provider → one `<PROVIDER>.json`. Always multi-card. No separate BASE/MC variants.

**Step 1 — QIDM Confirmation**: Build all QIDMs and combinations. Every field, every combo. Run `test_commsys.ps1` to verify all combos fire. 100% coverage from the start — no "MC expansion candidate" parking.

**Step 2 — Layout Refinement**: One card per search path for entities with 2+ distinct paths. QIDM does not change. Layout only. Retest affected entities.

**Step 3 — Split Entity**: Only if multi-card reveals a state model conflict that cannot coexist in one QIF. Most providers never need this if NCIC state pattern works.

**Why QIDM-first**: NJ and NY both introduced layout complexity before confirming QIDM paths. When tests failed it was impossible to tell if the failure was the QIDM, the layout, or the state model. Confirm QIDMs first — isolate layout from data path problems.

---

## 3-Bundle Structure

Every provider JSON has exactly 3 bundles in this order:

1. **ENTITIES** (`provider='MARK43'`): All QIFs (entity input forms) + display order
2. **PROVIDER** (`provider=[PROVIDER_NAME]`): AUTH, QMF, QRDM, all QIDMs
3. **RMS** (`provider='RMS'`): Built from KB specs via `_build_rms_bundle.ps1`

**ENTITIES must be first.** Confirmed AZ v2.0: forms do not render when ENTITIES is not first.

**QUERYINPUTFORM belongs ONLY in the ENTITIES bundle.** Adding it to any other bundle causes duplicate entity form cards.

---

## Anti-Patterns and Platform Limitations

Full reference: `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 31 LIMITATIONs with cross-reference index).

---

## Field Configuration Rules

### USx CAD Field Names — PascalCase (authored from the start)

The 22 USx CAD-integration field names (the ones CAD/OnScene auto-populate) are **PascalCase**, matching Cringer's engineering reference JSON. Mark43/RMS-internal keys (firstName, vinNumber, dlNumber, *AttrDetail.id, response JSON paths, …) stay camelCase.

- **Author PascalCase directly** in the build script — layout `Inp`/`Sel`/`Dt` fieldId args, QIDM `sourceField`, and combo `set[]`/`any[]`. The QIDM `targetField`, combo `defaults[].field`, and attribute `name` are already PascalCase.
- RMS form-fed fields: pass `-PascalCaseUsxFields` to `Build-RmsBundle`.
- **NEVER use a whole-tree recase post-transform.** The retired `Convert-UsxCasing` function (NJ ≤ v4.1) recursed the full output object and enumerated each Craft.js `nodes` list, collapsing single-child lists to a bare string and empty lists to `null`. Craft.js requires `nodes` to be an array, so the form body silently failed to render (only tab names showed). Removed 2026-06-18; all casing is now native.
- The 22 tokens: LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear, RandomRequest, RegistrationState, ImageIndicator, VehicleIdentificationNumber, NCICNumber, VehicleMakeCode, NameFirst, NameLast, BirthDate, SexCode, OperatorLicenseNumber, GunSerialNumber, GunMake, GunCaliber, GunModel, ArticleSerialNumber, ArticleTypeCode, RegistrationNumber, BoatHullIdNumber (+ DH-suffix variants where present).
- **Rollout status**: NJ, FL, HI are PascalCase. The remaining providers are still camelCase — convert each on its next scheduled rebuild (author PascalCase + add the RMS switch), not in a mass update.

### Code Type Pairings (confirmed working)

| codeTypeCategory | codeTypeSource | Notes |
|---|---|---|
| NCIC_LICENSE_PLATE_TYPE | NCIC | Baseline |
| NCIC_FIREARM_TYPE | NCIC | Baseline |
| NCIC_FIREARM_MAKE | NCIC | FIREARM makes only. NOT vehicle makes (AP #24) |
| VehicleType | **VEHICLE** | QRDM response **vehicle make** lookup (VehicleMakeName). Vehicle codes live in the `VehicleType` table under the `VEHICLE` source (user-verified vs platform registry 2026-06-24). NOT NCIC_FIREARM_MAKE. |
| NCIC_FIREARM_CALIBER | NCIC | FormInput also valid |
| NCIC_ARTICLE_TYPE | **CA_CLETS** | NCIC gives empty dropdown |
| YES_NO_UNKNOWN | **NCIC** | Y/N only. NIBRS adds Unknown (3 options) |
| NIBRS_SEX | NIBRS | DO NOT use attributeTypeId=SEX (see Sex Code section) |
| NIBRS_RACE | NIBRS | DO NOT use attributeTypeId=RACE. NCIC = empty dropdown |
| NJ_NIBRS_STATE | NJ_NIBRS | For OOS state dropdowns |
| VEHICLE_BODY_STYLE | Provider-specific | NJ=NJ_NIBRS, CA=VEHICLE. NCIC = empty |
| -- | **attributeTypeId** | -- |
| VEHICLE_MAKE | NCIC (via attributeTypeId) | **MUST be FormSelect (Sel) on ALL providers.** Dropdown works. NEVER use FormInput. Confirmed: NJ, FL, CA_CLETS, TX live-tested. |

### State Field — NCIC Pattern (preferred)

Single visible Sel 'RegistrationState': `attributeTypeId='STATE'`, `initialValue='<state>'`.
CommSys QIDM State attr: `sourceField=['RegistrationState']`, `targetField='State'`, `codeTypeProvider='NCIC'`.
RMS: KB standard (`useAttributeId=true` + `AttributeArrayWrapperRuleHandler`).

One field handles both CommSys (2-letter code via reverse-lookup) and RMS (dynamic attr ID).

**CONFIRMED**: NJ, AZ, NY. **UNCONFIRMED**: FL — test ST-1 on first import.

**CAUTION**: Do NOT set `initialValue` on State when the provider has separate in-state vs OOS keyRefs (e.g., NY: RCAR vs RVIN). The default causes OOS combos to fire instead of in-state, changing the documented query type. Use card title hints ("Leave blank for NY queries") instead. OK to set initialValue when provider has no separate in-state keyRefs (e.g., NJ). See LIMITATION #30.

Fallback (when NCIC not supported): dual-field pattern — SelH for RMS + InpH for XML. See `knowledge-base/BUILD_RULES.txt` Section 7.

### State Field — Combination any[]
Use the form fieldId `'RegistrationState'` in any[] — NOT the attribute name `'State'`.

### Date Fields
FormDate sends ISO yyyy-MM-dd. QIDM attribute: `rule=CommsysParseDateRuleHandler`, `arguments=['yyyy-MM-dd','MMddyyyy']`.

### Name (composite)
Separate FormInput fields: NameFirst, NameLast, NameMiddle, NameSuffix.
QIDM: `rule=FormatStringRuleHandler`, sourceField=all name fields, targetField='Name'.
`arguments` count = sourceField count minus 1 (2 fields → 1 arg, 4 fields → 3 args).
Check provider MetaData to confirm which Name fields are accepted.

**AUTHORITATIVE ConnectCIC Name-format rule (devdoc, ingested 2026-06-23):**
- **Order MUST be LAST-first.** ConnectCIC's preferred single-field format is
  **`LAST, FIRST MIDDLE SUFFIX`** (e.g. `Doe, John Thomas Jr.`). The reverse
  (`FIRST MIDDLE LAST SUFFIX`) is *accepted but NOT recommended* — "more difficult to
  accurately reformat." So `sourceField` order = `@('nameLast','nameFirst','nameMiddle','nameSuffix')`
  and the first separator (after Last) is **`, ` (comma-space)** per the devdoc example.
- 2-field: `@('nameLast','nameFirst')`, `arguments=@(', ')`. 4-field: `arguments=@(', ',' ',' ')`.
- **Individual component tags are the RECOMMENDED approach** over single-field concatenation:
  the devdoc warns a non-hyphenated multi-part first/middle/last name "will not be handled
  properly" in a single field (ConnectCIC can't disambiguate the parts). Sending individual
  tags avoids this. Evaluate per provider (needs the ConnectCIC component tag names from
  metadata/devdoc) — flagged portfolio item. See [[reference-connectcic-name-format]].
- **Audit 2026-06-23:** all 20 providers build Last-first EXCEPT HI_HCJDC_OFML, which was
  First-first (`NameFirst,NameLast,...`) → emitted malformed `FIRST LAST MIDDLE SUFFIX`
  (matches neither documented format). Fix queued. Cross-check this order on every build.

### LicensePlateNumber
In-state: `fieldId='licensePlateNumber'`. OOS: `fieldId='LicensePlateNumberOut'`.
Generic 'LicensePlateNumber' does NOT trigger RMS plate search.
QIDM `targetField` remains 'LicensePlateNumber'.

### ImageIndicator
Three requirements (all must be met): QIDM attribute `size=1`, FormSelect `initialValue='Y'` (or 'N' for vehicle), field listed in set[] or any[].

---

## Sex Code Configuration

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 5 (working pattern, critical rules, fallback).

---

## QIDM Architecture

### queryLabel Standard

Every QIDM must have a `queryLabel` property. Use these standard values:

| Query | queryLabel |
|---|---|
| VehicleRegistrationQuery | Vehicle Registration |
| VehicleStolenQuery | Vehicle Stolen |
| DriverLicenseQuery | Driver License |
| NyNyspinDriverLicenseNameQuery | DL Name Search |
| DriverHistoryQuery | Driver History |
| GunQuery | Firearm |
| ArticleSingleQuery | Article |
| BoatQuery | Boat |
| WMPIPersonWINQQuery | Wanted Person |
| WMPIPersonMINQQuery | Missing Person |
| CAISupervisedReleaseQuery | Supervised Release |
| CCHCriminalHistoryQHQuery | CCH Criminal History (QH) |
| CCHCriminalHistoryIQQuery | CCH Name Inquiry (IQ) |
| CCHCriminalHistoryQWIQuery | CCH Wanted/III (QWI) |
| CCHCriminalHistoryQRQuery | CCH Record Request (QR) |
| CCHCriminalHistoryZRQuery | CCH Record Request (ZR) |
| CCHCriminalHistoryFQQuery | CCH SID Query (FQ) |
| CCHCriminalHistoryAQQuery | CCH Admin Query (AQ) |
| CCHCriminalHistoryARQuery | CCH Admin Response (AR) |
| RMS (all) | RMS |

Label by what the officer is searching for, not by backend system name. Do not use entity names ("Person"), system names ("NCIC", "DMV"), or append "Query".

### Combination Format
```json
{
  "requirements": { "set": [...], "any": [...] },
  "primaryFieldReference": "<attribute name>",
  "keyReference": "<unique key>",
  "state": "In/Out"
}
```

- `keyReference` not `keyRef` — wrong property name causes silent null, then import rejection
- `primaryFieldReference` uses the QIDM attribute name (e.g. 'Name'), not sourceField
- `state` is required on CommSys QIDMs
- No `name` property on combinations

### Merge vs Split Decision

1. Is another QIDM targeting the same (targetEntity, query)? If no → safe to create separate QIDM.
2. Can you merge? All keyRefs distinct across both → merge into one QIDM.
3. Duplicate keyRefs? → (a) Check for separate MetaData transaction. (b) Invent a distinct keyRef (DALL + DALH). Provider routes by field content, not keyRef. (c) DH-suffix fieldIds. (d) Only after a–c fail: declare not implementable.

**keyRef is platform-internal only.** Provider does not validate it. Invented keyRefs work. Confirmed: NY v1.19.

### DL + DH on Same Form (Scenario A — FL pattern)
- autoSelect=true + queriesToDeselect on each QIDM
- DH-suffix fieldIds: NameFirstDH, NameLastDH, BirthDateDH, SexCodeDH, OperatorLicenseNumberDH
- DH QIDM references only DH-suffixed names in set[]/sourceField

### DL + DH on Separate Forms (Scenario B — NY pattern)
- Shared field pool makes queriesToDeselect ineffective
- DH co-fires with DL on OLN entry = correct police workflow
- For true isolation: DH-suffix fieldIds on DH form

### Combination Ordering
Most-specific (most set[] fields) first. Less-specific last.

---

## RMS Bundle — Built from KB Specs

**All builds**: RMS bundle and CommSys QRDM are constructed by `tools/_build_rms_bundle.ps1` from inline KB specifications. No external template dependency (no HIDLE.json). Build scripts dot-source the module and call:
- `Build-RmsBundle` — returns complete RMS bundle (AUTH, QMF, Vehicle QIDM, Person QIDM, QRDM, ResultsLayout)
- `Build-CommsysQrdm -ProviderName <name>` — returns CommSys QRDM for the PROVIDER bundle

**Flags**: `Build-RmsBundle -KeepSsn` (AZ, TN) to include socialSecurityNumber. `Build-RmsBundle -SkipRace` (TX, LA, MD, CA_CONTRA_COSTA) to exclude race attr and raceCode from combo any[]. `Build-RmsBundle -PascalCaseUsxFields` (NJ, FL, HI — the PascalCase providers) to emit the form-fed `sourceField`/`set`/`any` USx references in PascalCase so they match the PascalCase form fieldIds; Mark43-internal targetFields stay camelCase. Default off (camelCase) for the not-yet-converted providers.

**No post-build patches.** If a new issue is found, update the build script or `_build_rms_bundle.ps1` — never add a JSON patch.

---

## Live Test Capture — CommSys + RMS Pairing (standard as of NJ_NJCJIS v4.7, rolling out)

**Background:** `Build-RmsBundle` only emits a Vehicle QIDM and a Person QIDM (see above) — Gun,
Article, Boat, and DriverHistoryQuery have **no RMS mapping at all**. Prior to 2026-07-01, the
capture automation (`automation/extension/`) only scraped the CommSys/ConnectCic wire XML from
dex-log; it never touched the RMS side, so a whole class of RMS-only regressions (e.g. a QRDM
code-source mismatch producing "Mock results processed" — see NJ v4.6→v4.7, and the same class
fixed for FL/HI/CA) was only ever caught by someone manually screenshotting the RMS UI. This is
now closed: dex-log's table carries an RMS-destination row alongside the ConnectCic row for every
query that has an RMS mapping, and its own "View request and return" popup exposes the RMS
elasticQuery request + response text — `automation/extension/capture.js` now captures both and
pairs them by field-map content (order-independent), not by a fragile string/position match.

**Test log section order** (`tools/post_test.ps1`): header stamp (JSON Version/Entity
Fingerprint/Tier) → `QUERY STRING` (the dex-log field-map JSON) → `COMMSYS XML`
(pretty-printed/indented, not the minified wire string) → `COMMSYS XML RESPONSE`
→ `RMS QUERY` (request + response together) → `FIELD ANALYSIS` → `NOTES` → `RESULT`. `RMS QUERY`
reads "Not captured" for Gun/Article/Boat/DH — that's the **correct, expected** state (no RMS
mapping exists for those entities), not evidence of a gap.

**`logs/` — the ONLY test log, self-contained.** The separate narrative `tests/` folder was
eliminated 2026-07-01 (redundant once `logs/<Entity>/` carried the full FIELD ANALYSIS/NOTES/RESULT
content, not just wire evidence). Every test now has exactly one file:
`providers/<PROVIDER>/logs/<Entity>/<PROVIDER>_v<X.Y>_<Combo>.txt` — one folder per entity
(Vehicle, Person, Firearm, Article, Boat), one file per query, containing the full section order
above. The versioned test plan lives at the ROOT of this same folder:
`providers/<PROVIDER>/logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json` — `emit_test_plan.ps1`'s default
output. This makes `logs/` a standalone package (plan + every query's full evidence + narrative)
that doesn't require cross-referencing `docs/` to audit. `logs/.test_state.json` +
`logs/.test_version` (moved from the old `tests/` folder) are the entity fingerprint/version state
that `reset_test_package.ps1`/`block_entity.ps1` read and write.

**Rollout**: NJ_NJCJIS is the pilot/reference implementation (v4.7, 2026-07-01). Other providers
(CA_CLETS, FL_FCIC, NY_NYSPIN_EJUSTICE, TX_TLETS, etc.) pick this up automatically the next time
they go through a full rebuild/re-test cycle — do not backport it to another provider's capture
usage ad hoc before that.

---

## QIF Layout Helpers — Shared Module

**All builds**: All QIF layout construction functions are defined in `tools/_build_layout_helpers.ps1`. Build scripts dot-source it alongside `_build_rms_bundle.ps1`.

**Exports**: `N` (node factory), `Inp` (FormInput), `InpH` (hidden FormInput), `Sel` (FormSelect), `SelH` (hidden FormSelect), `Dt` (FormDate), `BuildMultiCardLayout` (multi-card layout engine with hidden row support), `AddCadNodes` (CAD dispatch context card), `AddFrNodes` (First Responder context card), `MakeLayouts` (builds all 3 layout variants: default, CAD_DISPATCH, FIRST_RESPONDER).

**InpH signature**: `InpH($fid, $lbl, $maxLen, $parentId, $extra)` — same as Inp but `hidden=$true`. Pass `$null` for maxLen when not needed.

---

## Provider Helpers — Shared Module

**All builds**: Provider boilerplate (AUTH, QMF, QRDM, ENTITIES bundle, output+validation) is defined in `tools/_build_provider_helpers.ps1`. Build scripts dot-source it alongside the layout and RMS modules.

**Exports**:
- `Build-Auth -ProviderName <name> [-ExtraAttributes <array>] [-ExtraAny <array>]` — standard 3-attr AUTH config (ORI, Mnemonic, UserName/dexStateUserId). IL_LEADS_OFML uses `-ExtraAttributes` for CDCName.
- `Build-Qmf -ProviderName <name>` — QUERYMESSAGEFORMAT with CommsysWsiOutgoingMessageHandler.
- `Build-ProviderQrdm -ProviderName <name>` — wraps Build-CommsysQrdm, sets name/description/provider.
- `Build-EntitiesBundle -Configurations <array> [-DefaultOrder <array>] [-CadOrder <array>] [-FrOrder <array>]` — ENTITIES bundle with configurable display order. Defaults to Vehicle-first standard.
- `Write-ProviderJson -BundleObject <obj> -OutPath <path> [-PhasePath <path>] [-Label <string>]` — ConvertTo-Json readable output, UTF-8 no BOM, runs validator with exit-on-fail.

---

## Rule Handler Reference

Full reference: `knowledge-base/RULE_HANDLERS.txt` (24 handlers — 6 directly configured, rest platform-defined in RMS).

---

## Entity Display Order

ENTITIES bundle `order` array must use targetEntity values:
```json
{
  "default":         ["Person","Vehicle","Firearm","Article","Boat"],
  "CAD_DISPATCH":    ["Vehicle","Person","Firearm","Article","Boat"],
  "FIRST_RESPONDER": ["Vehicle","Person","Firearm","Article","Boat"]
}
```

Entity names, config names, and labels do NOT work. Check the Entity Display Order section above before any order fix.

---

## Layout Structure (Craft.js Node Tree)

```
ROOT → FORM_ROOT (Form, hidePageItems=true, layout='page')
     → ROOT_PAGE (Page, title='Page 1')
     → CARD_xxx (Card, optional title)
        → ROW_xxx (Row, templateColumns=['6','6'])
           → FIELD_xxx (FormInput / FormSelect / FormDate / FormCheckbox)
```

Three layout variants per QIF: `default`, `CAD_DISPATCH`, `FIRST_RESPONDER`.

**CAD_DISPATCH**: Prepend CONTEXT_INFO_CARD with CadUnit_Input + CadEvent_Input before entity cards. ROW_0.parent MUST point to 'CONTEXT_INFO_CARD' (not ROOT_CARD).

**FIRST_RESPONDER**: Same as CAD_DISPATCH (+ optional LinkToEvent checkbox). Whether platform renders FIRST_RESPONDER distinctly is unconfirmed. Include in all builds.

**templateColumns**: Array of strings. `['12']` = full width. `['6','6']` = two columns. `['4','4','4']` = three columns.

---

## Tools (59 scripts + 9 shared modules in `tools/`)

All tools are provider-agnostic. `banned_patterns.txt` is the only non-script (consumed by verify_build.ps1).

Shared modules (dot-sourced, `_`-prefixed): `_build_rms_bundle.ps1`, `_build_layout_helpers.ps1`, `_build_provider_helpers.ps1`, `_json_canonical.ps1`, `_resolve_provider_json.ps1` (active-JSON resolver `Get-ProviderRootJson` — bare → versioned → `_MC` → `_BASE`).

### Core Build Pipeline (run every build via build_report.ps1)

| # | Tool | Purpose | Key flags |
|---|---|---|---|
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos) | `-Path <json>` `-ShowDetail` |
| 2 | `render_layout.ps1` | CLI layout tree renderer | `-Path <json>` `-Summary` `-Entity` `-Variant` `-QidmOnly` |
| 3 | `test_commsys.ps1` | CommSys query simulator (combo matching + XML output) | `-Path <json>` `-Entity` `-Combo` `-OutFile` |
| 4 | `report_picklists.ps1` | Scans FormSelect dropdowns + QRDM/QIDM code types | `-Path <json>` `-OutFile` |
| 5 | `render_html.ps1` | Self-contained HTML layout report with color-coded fields and QIDM tables | `-Path <json>` `-OutFile` |
| 6 | `verify_build.ps1` | Post-build verification (banned patterns, fieldId consistency, reference patterns, Visible-First Mandate / hidden-field check) | `-Path <json>` `-CamelCase` |
| 7 | `audit_metadata.ps1` | Validates QIDM configs against authoritative XML metadata | `-Path <json>` `-OutFile` |
| 8 | `audit_cad.ps1` | CAD dispatch field alignment (camelCase fieldIds, layout variants, Patch 8) | `-Path <json>` `-Variant` `-OutFile` |
| 9 | `generate_test_matrix.ps1` | Auto-generates test matrix from JSON (render + combo + any[] + deselect + negatives) | `-Path <json>` `-OutFile` |
| 10 | `run_test_matrix.ps1` | Automated test conductor — validates all test matrix cases via combo simulation | `-Path <json>` `-Matrix <file>` `-OutFile` |
| 11 | `simulate_response.ps1` | CJIS response handler simulator: executes all QRDM handler transformations (Height, Name, VehicleYear, truncate, AttributeMapping) against comprehensive synthetic test data per entity. Target: 0 MISSING / 0 UNMAPPED. No live data required. | `-Path <json>` `-Entity` `-RunEdgeCases` `-OutFile` |
| -- | `build_report.ps1` | **Master orchestrator** — runs all 11 above + saves reports to docs/, then prunes orphaned variant reports (build-owned report files for a JSON variant no longer present — e.g. after consolidating branches) | `-Path <json>` |

### Auditors (repo-wide checks)

| Tool | Purpose | Key flags |
|---|---|---|
| `enforce.ps1` | **MANDATORY FINAL GATE** -- runs ALL checks (build freshness, validator scores, doc sync, cross-provider, repo audit, git status) | `-Provider <name>` `-SkipGit` `-Rebuild` `-Reproducible` `-OutFile` |
| `audit_reproducible.ps1` | Proves committed JSON == a fresh build: runs the build script twice into scratch (via $env:REPRO_OUTPATH hook), checks DETERMINISM + CURRENCY (version/PlateYear normalized). FAIL=non-deterministic; WARN=stale. Opt-in via `enforce -Reproducible` | `-Path <json>` `-OutFile` `-Strict` |
| `_json_canonical.ps1` | Shared canonical JSON serialization + hashing (ConvertTo-Canonical, Get-Sha256Hex, New-NormalizedClone). Reused by get_entity_fingerprints + audit_reproducible | (dot-sourced) |
| `pipeline.ps1` | **ONE-COMMAND PIPELINE** -- build + report + metadata + sync + version docs + cross-provider + repo audit + enforce in 8 steps; stops on first failure | `-Provider <name>` (required) `-SkipBuild` `-SkipEnforce` |
| `doctor.ps1` | **ONE-SHOT HEALTH DASHBOARD** -- read-only snapshot: score_all -Quick + poisoned-array sweep (validate G-31) + git status + reverse-propagation status | `-SkipPoison` `-OutFile` |
| `flag_pending_fix.ps1` | **REVERSE-PROPAGATE** a shared-module/JSON fix as a doc-stub flag: writes `[FLAG:<id>]` into each still-pending provider's PENDING_UPDATES.txt (blocks enforce PHASE 1 until rebuilt; build script clears it) + appends a REVERSE_PROPAGATION_LOG.md row. Idempotent. | `-FixId` `-Description` `-Providers <list\|all>` `-Origin` `-Date` `-DryRun` `-OutFile` |
| `audit_reverse_propagation.ps1` | Portfolio status view: reads every PENDING_UPDATES.txt + REVERSE_PROPAGATION_LOG.md, reports which providers are pending/propagated per fix + gaps. Informational (enforce PHASE 1 is the gate); composed into doctor.ps1 | `-OutFile` |
| `audit_repo.ps1` | Full monorepo audit (18 categories: banned patterns, versions, docs, structure, cross-provider, camelCase) | `-Category <1-18>` |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase) | `-Path <providers-dir>` `-OutFile` |
| `audit_structure.ps1` | Provider folder structure (naming, required dirs/files, reports, freshness) | `-Path <provider-dir>` `-OutFile` |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphan detection) | `-Path <json>` `-OutFile` |
| `score_all.ps1` | Provider scorecard -- runs validator on all providers, sorted table with rebuild flags | `-Quick` (parse existing reports) `-OutFile` |
| `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches, AP #21-23) | `-Path <dir>` `-OutFile` |
| `sync_provider_table.ps1` | Auto-updates CLAUDE.md provider table scores from validator reports | `-DryRun` `-OutFile` |
| `sync_version_docs.ps1` | Auto-updates STATUS.txt, SQVR.txt, JSON_INVENTORY.md (versioned filename), REBUILD_TRACKER.md, BUILD_NOTES.txt (date checksum), per-provider CHANGELOG_<PROVIDER>.md, and the repo-root CHANGELOG.md "Current:" line, with current version and scores | `-Provider <name>` `-DryRun` |
| `generate_changelog.ps1` | Renders per-provider `docs/CHANGELOG_<PROVIDER>.md` (Markdown) from `<PROVIDER>_BUILD_NOTES.txt`. Deterministic. Step 16 of build_report; re-run by sync_version_docs | `-Path <json>` `-Provider <name>` `-OutFile <path>` |
| `preflight_rebuild.ps1` | Per-provider rebuild action plan (validator WARNs + linter + flags → checklist) | `-Provider <name>` `-All` `-Quick` `-OutFile` |

### Metadata & Extraction

| Tool | Purpose | Key flags |
|---|---|---|
| `extract_metadata_reference.ps1` | Generates METADATA_REFERENCE.txt from XML + JSON (field definitions, combo requirements, coverage) | `-XmlPath <xml>` `-Path <json>` `-OutFile` `-All` |
| `extract_queries.ps1` | Parses metadata XML into SQVR-ready tracking file | `-XmlPath <xml>` `-OutFile` |
| `diff_docs.ps1` | Diffs updated engineering docs against KB files (NEW/REMOVED/CONFIRMED per category) | `-NewDoc` `-KbFile` `-OutFile` `-Provider` |

### Provider Lifecycle

| Tool | Purpose | Key flags |
|---|---|---|
| `new_provider.ps1` | Scaffolds new provider (canonical structure, build scripts, doc templates, tool registrations) | `-XmlPath <xml>` `-PdfPath` `-Force` |
| `new_test_log.ps1` | Creates stub test log in logs/<Entity>/ (migrated providers) or legacy tests/ (GATE 2 requirement) | `-Provider` `-Variant` `-Version` `-Entity` `-Combo` `-Description` |
| `post_test.ps1` | Instant-save after test (artifacts, STATUS, SQVR, commit, push) | `-Provider` `-Entity` `-Query` `-Combo` `-Result` `-Description` |
| `reset_test_package.ps1` | Rebuild restarts testing: on version change, archives prior logs/<Entity>/ files, resets SQVR→PENDING, clears STATUS rows, stamps logs/.test_version. Auto-run by pipeline after build. | `-Provider` `-Force` |

### Utilities

| Tool | Purpose | Key flags |
|---|---|---|
| `test_layout.ps1` | QIF layout validator + HTML form preview | `-Path <json>` |
| `build_codetype_test.ps1` | Generates CODETYPE_TEST.json for dropdown validation | `-OutputPath` |
| `preflight_check.ps1` | Pre-build validation against PROVIDER_CONFIG.txt | (no args) |
| `map_cad_fields.ps1` | Maps CAD field names to provider JSON fieldIds (MATCH/CASE_MISMATCH/NO_MATCH) | `-Path <json>` `-CadFields` `-OutFile` `-GeneratePatch` |
| `report_cad_mapping.ps1` | HTML report mapping CAD fields to provider sourceField/targetField per QIDM | `-Path <json>` `-OutFile` |
| `Apply-CadFieldAlignment.ps1` | CAD field alignment function for MC builds (PascalCase → camelCase rename) | dot-source; `-QidmList` `-FormList` `-RmsBundle` `-ProviderRenames` |
| `generate_build_script.ps1` | Generates build script from metadata XML (field mapping, QIDM generation, layout) | `-XmlPath <xml>` `-DevdocPath` `-OutDir` |

Validator must pass clean (0 FAIL) before import. Verify must pass clean (0 FAIL). Fix all failures before proceeding.

---

## Import Error Quick Reference

See `knowledge-base/IMPORT_ERRORS.txt` for error-to-fix mapping.

---

## Versioning Policy

- **NEVER overwrite a tested JSON.** Save every iteration.
- **Root JSON name carries the version: `<PROVIDER>_v<X.Y>.json` (STANDARD).** The build
  script sets `$OUT = "$DIR\<PROVIDER>_v${Version}.json"`. `Write-ProviderJson` removes any
  stale sibling root JSON (bare `<PROVIDER>.json` or an older `<PROVIDER>_v*.json`) before
  writing, so the one-JSON-in-root rule holds on every bump. The bare `<PROVIDER>.json` name
  is still accepted (legacy) but new/rebuilt providers should emit the versioned name.
- **Why the filename — not a top-level `version` field — carries the version:** the platform
  deserializes a top-level `version` as `java.lang.Integer` and rejects dotted strings ("4.6").
  So version lives (a) in the filename and (b) inside the bundle `description`
  ("Provider configuration for <PROVIDER> v<X.Y> ..."), which is what enforce CHECK 3i reads.
  Do NOT re-add a top-level `version` field.
- Phase snapshots are saved to `phases/` as `<PROVIDER>_v<X.Y>_<date>.json` — **legacy pattern,
  being retired provider-by-provider starting with NJ_NJCJIS (2026-07-01).** Every version is
  already fully recoverable from git commit history (`git log`/`git show`), which `phases/` only
  duplicated while accumulating same-version-rebuild noise (NJ had 3 separate v3.6 snapshots, 2x
  v4.1, 2x v4.5 before retirement). Providers not yet migrated still use `phases/` as documented —
  don't touch another provider's build script ad hoc; each one drops it on its own next rebuild.
- **Test plan filename carries the version too: `logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json`** — at the
  ROOT of `logs/` (the self-contained per-query evidence package, see "Live Test Capture" above),
  not `docs/`. Same reasoning as the root JSON above — a rebuild must never silently overwrite the
  prior version's plan with no trace. `emit_test_plan.ps1` computes this by default;
  `reset_test_package.ps1` archives any stale-version copy to `logs/_archive_pre_v<X.Y>/` and
  regenerates the current one on every reset. Rolled out to NJ_NJCJIS first; other providers pick
  it up on their next rebuild.
- Document every JSON in `docs/JSON_INVENTORY.md`. Keep all JSONs in project root.
- **Tools resolve the active JSON via `tools/_resolve_provider_json.ps1`
  (`Get-ProviderRootJson`)** — bare → versioned → `_MC` → `_BASE` — never by hardcoding
  `<PROVIDER>.json`.

---

## Source Authority Lookup Table — MANDATORY ROUTING

When you need information, use ONLY the source listed below. Do NOT substitute raw sources, do NOT guess, do NOT skip to the underlying data. If the tool/file does not exist yet, create it first.

| Question | Authoritative Source | NEVER Use |
|---|---|---|
| **Which queries** does this provider support? | Devdoc "Basic Queries Supported" section (`source/<PROVIDER>_DEVDOC.txt`) | XML metadata transaction names, naming pattern guesses |
| **How are fields defined** (types, sizes, combo requirements)? | `docs/<PROVIDER>_METADATA_REFERENCE.txt` (auto-generated by `extract_metadata_reference.ps1`) | Raw XML metadata files (`source/*.xml`) |
| **What field type** (FormInput/FormSelect/FormDate) should a field use? | `METADATA_REFERENCE.txt` field definitions + `audit_cross_provider.ps1` for consistency | Manual XML inspection, guessing from field name |
| **What combos fire** for a given entity/field set? | `test_commsys.ps1 -Path <json> -Entity <entity>` | Manual build script reading, mental combo matching |
| **What does the layout look like?** | `render_layout.ps1 -Path <json> -Summary` | Reading raw Craft.js node tree in JSON |
| **Are there structural issues?** | `build_report.ps1 -Path <json>` (runs all 11 tools) | Spot-reading JSON sections |
| **Is this field consistent across providers?** | `audit_cross_provider.ps1 -Path providers/` | Manual grep across provider folders |
| **Are all docs/versions in sync?** | `enforce.ps1 -Provider <name>` | Manual file-by-file comparison |
| **What anti-patterns apply?** | `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 31 LIMITATIONs) | Memory, training data |
| **What does the RMS bundle contain?** | `tools/_build_rms_bundle.ps1` (all builds) + CLAUDE.md RMS Bundle section | Raw JSON inspection |
| **Current build state** (scores, warnings) | `docs/` report files (generated by `build_report.ps1`). Legacy: `docs/base/` or `docs/mc/` | Re-running validator ad hoc |
| **Test coverage status** | `audit_test_coverage.ps1 -Path <json>` + `docs/<PROVIDER>_SQVR.txt` | Counting test log files manually |
| **Conditional field constraints** ("Must be filled if X = Y") | `docs/<PROVIDER>_METADATA_REFERENCE.txt` FIELD CONSTRAINTS section (per QIDM) + `source/<PROVIDER>_DEVDOC.txt` "Possible Values" column | Training data, memory |

**Rule: If a tool exists for the question, run the tool. If an extracted file exists, read the file. Raw sources are LAST resort only when no extracted reference exists.**

---

## Workflow

Three commands run everything. No manual checklists.

| Action | Command |
|---|---|
| **Build + verify one provider** | `pipeline.ps1 -Provider <NAME>` |
| **Build + verify multiple providers** | `pipeline.ps1 -Providers 'TX_TLETS','HI_HCJDC_OFML'` |
| **Build + verify ALL providers** | `pipeline.ps1 -All` |
| **Final verification (all providers)** | `enforce.ps1` |
| **New provider setup** | `new_provider.ps1 -XmlPath <xml>` |

`pipeline.ps1` chains 8 steps: build JSON → build report (steps 1-9 parallel) → extract metadata → sync CLAUDE.md → sync version docs → cross-provider audit → repo audit → enforce. Stops on first failure. Flags: `-SkipBuild` (reports only), `-SkipEnforce` (mid-work), `-DeferAudit` (skip steps 6-7 for mid-work iterations).

**Rebuild restarts testing.** Step 1 calls `reset_test_package.ps1` after a successful build: when the JSON version changes, prior live test logs no longer line up with the shipped JSON, so they are archived to `logs/<Entity>/_archive_pre_v<ver>/` (legacy: `tests/_archive_pre_v<ver>/`), all SQVR markers reset `[CONFIRMED]→[PENDING]`, STATUS live rows cleared, and `logs/.test_version` stamped. The full test matrix re-runs from Test 1 — never resume mid-matrix across a rebuild. See `knowledge-base/TESTING_REQUIREMENTS.txt` Section 11 GATE 1.

**MANDATORY before presenting any combo test instruction:** Read `docs/<PROVIDER>_METADATA_REFERENCE.txt` for the QIDM being tested. Find the FIELD CONSTRAINTS section (if any) and verify that no combo default triggers a "Must be filled if X = Y" conditional requirement on a field that has no default and no handler. If a violation exists: STOP, fix the build, rebuild, re-import — do not present the test instruction. This gate applies even if the test matrix has been generated and reviewed. (Rule origin: TX_TLETS T6 — DH ImageIndicator=Y default made EmailAddress silently required per devdoc; violation was not caught at metadata extraction.)

**Batch mode** (`-Providers` or `-All`): runs per-provider steps (1-3) sequentially per provider, then ONE sync pass, ONE cross-provider audit, ONE repo audit, ONE enforce. Eliminates redundant global audits when rebuilding multiple providers.

`build_report.ps1` runs 15 steps. Steps 1-9 execute in parallel (all read-only on the JSON); step 10 (test conductor), 11 (response simulator), 12 (label review), 13 (officer guide), 14 (supported-query audit), and 15 (per-provider changelog) run after.

`enforce.ps1` runs 5 phases: build freshness, validator scores, doc version sync (8 locations per provider: CLAUDE.md, STATUS, SQVR, JSON_INVENTORY, BUILD_NOTES + date checksum, REBUILD_TRACKER, per-provider CHANGELOG_<PROVIDER>.md, repo-root CHANGELOG.md Current line), cross-provider + repo integrity (phases 4-5 run in parallel), git status. Exit 0 = verified. Exit 1 = blocked.

**Same-date docs:** the FULL `pipeline.ps1` (not `build_report` alone) is what stamps every doc to the same date in one run — build_report regenerates the 16 report/guide/changelog artifacts, then step 5 `sync_version_docs` stamps STATUS/SQVR/JSON_INVENTORY/CHANGELOG and the BUILD_NOTES date checksum. Running pieces by hand can leave docs on mixed dates; run `pipeline.ps1 -Provider <name>` to refresh them together.

**If enforce.ps1 passes, the work is done. If it doesn't, fix what it flags.**

### Design Decisions (applied automatically)

- Phase 1 = single card per entity
- 2+ search paths = multi-card (Phase 2)
- DH on same form as DL = DH-suffix fieldIds
- Duplicate keyRefs = invent distinct keyRef
- Most-specific combination first in array
- Investigate all 4 solution paths (multi-combo, separate transaction, DH-suffix, reference builds) before declaring not implementable
- Test NCIC state pattern (ST-1) on first import of any new provider

---

## Canonical Provider Structure

Every provider under `providers/` MUST have this structure. All new providers follow the same layout.

**NAMING RULE**: `<PROVIDER>` MUST match the metadata XML filename minus `.xml`. Verify before creating the folder. See `BUILD_RULES.txt` Section 0.

**ONE JSON IN ROOT RULE**: Exactly one JSON in the provider root folder at all times.
- New/rebuilt providers: `<PROVIDER>_v<X.Y>.json` (versioned name is the standard). Bare
  `<PROVIDER>.json` is still accepted (legacy).
- Legacy providers may still have `<PROVIDER>_MC.json` or `<PROVIDER>_BASE.json` until rebuild
- NEVER multiple JSONs in root simultaneously. `Write-ProviderJson` deletes stale siblings on
  build; enforce FAILs if more than one versioned JSON is present.

**docs/ 4-CATEGORY STRUCTURE (rollout, NJ_NJCJIS first, 2026-07-01):** `docs/` splits into
`tracking/`, `reports/`, `reference/`, `deliverables/` (see tree below for what goes where). A
provider is "migrated" once ANY of its 4 category folders exists — `tools/_resolve_docs_path.ps1`
(`Get-DocsCategoryDir`/`Get-DocsPath`/`Find-DocsPath`) resolves every tool's docs/ path
accordingly, falling back to the flat legacy `docs/` layout (unchanged) for any provider that
hasn't migrated. Migrate a provider by `git mv`-ing its existing docs/ files into the 4 category
folders on its next full rebuild — no tool code change needed, the resolver already handles both
states. Do not migrate a provider ad hoc outside of its own rebuild cycle.

```
providers/<PROVIDER>/
├── <PROVIDER>_v<X.Y>.json                 # Current JSON (single, version-named output per provider)
├── docs/                                   # 4-category structure [NJ_NJCJIS pilot 2026-07-01, rolling out]
│   │                                       # (legacy providers: same files, still flat in docs/ directly)
│   ├── tracking/                          # Hand-relevant, updated every version
│   │   ├── <PROVIDER>_STATUS.txt          # Live test matrix + current state
│   │   ├── <PROVIDER>_SQVR.txt            # Supported Query Validation Report
│   │   ├── <PROVIDER>_BUILD_NOTES.txt     # Change log with CHANGED/REASON per version (source of truth)
│   │   ├── CHANGELOG_<PROVIDER>.md        # Auto-generated Markdown changelog (from BUILD_NOTES)
│   │   ├── JSON_INVENTORY.md              # Every JSON version ever produced
│   │   ├── DEX_TICKET.md                  # Jira DEX ticket pointer + changelog dump log
│   │   └── BUILD_MANIFEST_<PROVIDER>.json # Hash-gate manifest (enforce.ps1 trust check)
│   ├── reports/                           # Auto-generated by build_report.ps1, fully reproducible
│   │   ├── VALIDATOR_REPORT_*.txt         # 13 report types + TEST_MATRIX (see Tools table)
│   │   └── ...
│   ├── reference/                         # Derived from metadata XML, semi-static
│   │   ├── <PROVIDER>_METADATA_REFERENCE.txt
│   │   └── <PROVIDER>_SUPPORTED_QUERIES.txt
│   └── deliverables/                      # Officer/tester-facing, not read by tooling logic
│       └── OFFICER_GUIDE_<PROVIDER>.html/.pdf
├── logs/                                  # The ONLY test log location [NJ_NJCJIS pilot, rolling out; tests/ eliminated 2026-07-01]
│   ├── .test_state.json                   # Entity fingerprint/version/block-status (authority; moved from tests/)
│   ├── .test_version                      # Legacy scalar global version (moved from tests/)
│   ├── <PROVIDER>_TEST_PLAN_v<X.Y>.json    # Machine-readable plan for the browser driver (versioned filename — see Versioning Policy)
│   └── <Entity>/                          # One folder per entity (Vehicle, Person, Firearm, Article, Boat)
│       └── <PROVIDER>_v<X.Y>_<Combo>.txt   # Full test log: header stamp + QUERY STRING + COMMSYS XML + RMS QUERY + FIELD ANALYSIS + NOTES + RESULT
├── phases/                                # Version snapshots — LEGACY, being retired provider-by-provider (git history is authoritative); NJ_NJCJIS no longer uses this
├── scripts/                               # Provider-specific build scripts
│   └── build_<provider>.ps1               # Single build script per provider
├── source/                                # Input materials
│   ├── <provider>.xml                     # Metadata XML
│   └── <provider>.pdf                     # Devdoc PDF
```

When a repo does not match this structure, fix it before doing any other work.

---

## Quick Start — New Provider

### Step 0: Naming (CRITICAL — do this FIRST)
- Open the metadata XML file and read its filename
- Provider folder name MUST match the XML filename minus `.xml`
- Example: `NM_NMLETS_OFML.xml` → folder `providers/NM_NMLETS_OFML/`
- Do NOT guess from devdoc titles, abbreviations, or user-supplied names
- Mismatched names require renaming 10+ files per provider (see `BUILD_RULES.txt` Section 0)

### Step 1: Setup
1. Read `knowledge-base/README.txt` then this file
2. Create provider folder with canonical structure (see above)
3. Copy metadata XML and devdoc PDF to `source/`
4. RMS bundle built automatically from KB specs (no template copy needed)
5. Convert PDF to text: `pdftotext source/<PROVIDER>.pdf source/<PROVIDER>_DEVDOC.txt`
6. Run `extract_queries.ps1 -XmlPath source/<PROVIDER>.xml` to populate SQVR
7. Read devdoc "Basic Queries Supported" — this is the ONLY authority for WHICH queries to build

### Step 2: Build
8. Create build script in `scripts/` (must include validator call)
9. Build all QIDMs and multi-card layout in one pass. 100% combo coverage from start.
10. GATE 1 after every build (report + commit + push)
11. Update SQVR with [PENDING] markers for every query path

### Step 3: Iterate
12. Refine layout (card splits, field ordering, defaults)
13. Split entity only if needed (NCIC state pattern usually avoids this)
14. GATE 5 before declaring DONE

### Bulk Onboarding (10+ providers)
See `TESTING_REQUIREMENTS.txt` Section 16 for the complete workflow.
Key rule: batch setup (folders, source materials), serial builds (one provider at a time).
