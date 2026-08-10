# HI_HCJDC_OFML -- Changelog

Auto-generated from `HI_HCJDC_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.15** | Generated: 2026-08-10

---

## v4.15 -- 2026-08-10 -- DEX-1283: remove the Attention 'X' prefill -- HI was the last provider carrying it

**CHANGED:** Three sites, all for one field. (1) The hidden DH gate-feeder
  InpH 'Attention' loses initialValue='X'. (2) KQ combo defaults[] loses  
  Attention='X' (PurposeCode='C' KEPT). (3) KQN combo defaults[] likewise.  
  The Attention CONTROL, its any[] membership on KQ/KQN, and the attribute  
  (sourceField=['Attention'] + CommsysGetLastNameFirstNameInitialRuleHandler)  
  are all UNCHANGED. Only the literal value goes.  
**REASON:** DEX-1283 ("TX Provider Issues", sub-task of DEX-967) item 2 -- Attention being
  set to X from USx forms. Applied to FL_FCIC v7.18, TX_TLETS v4.19 and CA_CLETS v2.24  
  on 2026-08-06; HI was the last provider still prefilling it.  
WHY THE 'X' WAS NOT NEEDED -- and why the provider's own history says otherwise.  
  v2.9 (2026-06-22) recorded the 'X' as the gate-feeder that makes the handler's  
  sourceField='Attention' RESOLVE, live-proven by <Attention>SGAMBELLONE R</Attention>.  
  That conclusion was CONFOUNDED: v2.9 changed TWO things in one version -- it added  
  'Attention' to KQ/KQN any[] AND added the 'X'. Its own text names the real cause  
  ("Root cause = missing any[] entry, not handler config"), so the any[] membership was  
  the fix and the 'X' rode along, never isolated. Measured 2026-08-10 across the  
  portfolio: FL_FCIC, TX_TLETS, CA_CLETS and NY_NYSPIN_EJUSTICE all run this SAME  
  handler with the field in any[], NO initialValue and NO combo default, and their  
  committed wires carry the resolved officer name on 38 of 38 Driver-History logs  
  (FL 7/7, TX 13/13, CA_CLETS 7/7, NY 11/11 DH-OOS). An empty source field is  
  sufficient. Rob caught the wrong call ("why would we leave it here") -- a June note  
  had been weighted over August wire evidence.  
NOT the NY shape, and NOT a set[] requirement. NY is the provider with the set[]  
  story and it runs the OPPOSITE way: requestorDH was metadata-mandatory in set[],  
  which made the BROWSER gate Send and left DALHOUT permanently unsubmittable, so  
  v4.21 DEMOTED it set[] -> any[]. No provider needs this field in set[] for the  
  handler to fire; NY's problem was getting it OUT of set[]. HI's Attention was  
  already any[]-only, so no placement change was needed here.  
THE CONTROL STAYS. v2.5 proved sourceField=@() is import-REJECTED by ConnectCic  
  ("Invalid attributes ... [Attention]"), reverted at v2.6 -- so the hidden control and  
  the sourceField reference must remain. Only the value is removed.  
WHY THIS IS WORTH A BUMP + FULL RE-SWEEP: v4.14 is tenant-verified ALL-PASS 46/46 and  
  published (DEX-1257 + catalog, 2026-08-04), so an imported version is frozen. Beyond  
  portfolio consistency, the combo defaults[] Attention='X' sits on the CAD path, which  
  NONE of the 46 form-driven logs exercises -- and DEX-1283's second symptom is exactly  
  "not present when you do it from a CAD event". That path was carrying a literal 'X'  
  with no test able to see it.  
EXPECTED AFTER RE-TEST: <Attention>SGAMBELLONE R</Attention> unchanged on all 9 DH  
  wires. If it comes back ABSENT, the v2.9 gate-feeder theory was right after all and  
  this must be reverted -- that is the single discriminating observation of the re-sweep.  
ANSWERED 2026-08-10 -- PREDICTION HELD, 9 of 9. USx tenant re-sweep ALL-PASS 46/46  
  (Vehicle 16 / Person 14 / Firearm 6 / Article 3 / Boat 7). Every KQ/KQN log carries  
  <Attention>SGAMBELLONE R</Attention> with NO initialValue and NO combo default  
  anywhere in the JSON: KQ, KQN, KQ_any, KQN_any, KQ_af_RegistrationStateDH,  
  KQN_af_RegistrationStateDH, KQ_af_purposeCodeDH, KQN_af_purposeCodeDH,  
  KQN_guardrail_vs_KQ. Zero logs carry a literal 'X'. So the any[] membership alone  
  feeds the handler and the v2.9 'X' was decoration on a confounded version -- now  
  settled by wire evidence on THIS provider, not inferred from the other four.  
  Control observation worth keeping: the DL side (DQ, DQN, DQ_any, DQN_any,  
  DQN_guardrail_vs_DQ) emits NO <Attention> element at all -- the field is genuinely  
  DH-scoped and does not leak through the shared field pool.  
  Gates: four log gates 46/46 (content, metadata, attribution, plan completeness 5/5),  
  inflation 0/0/0/0 (46 distinct wires, fingerprints matched, no orphan field, no  
  degenerate guardrail), enforce 43 PASS / 0 HI-scoped FAIL-or-WARN.  
  STILL UNTESTED BY CONSTRUCTION: the CAD path. Removing Attention='X' from KQ/KQN  
  defaults[] is the half of this fix that no form-driven log can exercise (see the BUMP  
  rationale above), so DEX-1283's "not present when you do it from a CAD event" symptom  
  is addressed by inspection, not by a captured wire. Do not record it as proven.  
SCRIPT : scripts/build_hi_hcjdc_ofml.ps1  
OUTPUT : HI_HCJDC_OFML_v4.15.json  

## v4.14 -- 2026-07-30 -- Layout review -- Vehicle 1-card collapse + Boat order tidy (direct Rob feedback, NO functional change)

RE-SWEPT 2026-08-04 at the SAME version -- 6th and LAST of the original six (Rob's call after the  
  build process changed). Package reset with -Force so 46 fresh captures REPLACED the prior 46.  
  46/46 ALL-PASS -- Vehicle 16, Person 14, Firearm 6, Article 3, Boat 7. Four log gates green  
  (6c 46/46, 6d 46/46, 2i 46/46 attribution, plan completeness 5/5). enforce 44P/0F/0W.  
  audit_log_inflation 0/0/0/0.  
  WIRE EVIDENCE -- this provider makes the STRONGEST layout claims of the six, and both hold:  
  * DL and DH are GENUINELY independent, not two views of one pool: the DL card carried State=GA  
    while the DH card carried State=NJ IN THE SAME OFFICER SESSION. Both resolve to the canonical  
    un-suffixed <State> element on the wire, so the DH-suffix is purely form-side isolation with  
    NO wire footprint. DQ/DQN send DriverLicenseQuery, KQ/KQN send DriverHistoryQuery.  
  * OLN>Name holds SEPARATELY on each card -- DQN_guardrail_vs_DQ and KQN_guardrail_vs_KQ each  
    send OperatorLicenseNumber ONLY, with no Name/BirthDate/SexCode leaking. This is the only  
    provider claiming that guardrail twice, and the case most likely to leak if the pools were  
    shared. It does not.  
  * Boat Hull>Reg: QB_guardrail_vs_BQ sends BoatHullIdNumber ONLY. NOTE this is the OPPOSITE  
    correct answer from NJ v4.15, where the reg number deliberately RIDES ALONG on the hull query  
    -- because NJ's devdoc lists it as an optional on the hull combination and HI's does not.  
    Same-looking guardrail, two right answers, each decided by the provider's OWN authority.  
  * ImageIndicator=N combo default confirmed on every VehReg combo, with the toggle tests carrying  
    Y -- default applied AND genuinely exercised.  
  * GunMake=IMI (letter code) where NJ_NJCJIS sends GunMake=03 (numeric NIBRS) from the SAME  
    NCIC_FIREARM_MAKE category/source pair. The per-tenant code-table difference was documented  
    from one provider's evidence; it is now confirmed from both, same session.  
  Two shortfalls, both recovered by re-running: one disabled-Send timeout on the GunMake toggle  
  (12th such today, 12th to clear on retry, never once reproducible) and one capture-side loss of  
  QG_af_GunCaliber.  
**CHANGED:** From the HI v4.13 rendered-form review (mirrors FL v7.11/v7.12 + NJ v4.14):
  (1) Vehicle collapsed from 3 cards (SEARCH OPTIONS + PLATE SEARCH + VIN SEARCH) to ONE  
    "VEHICLE REGISTRATION SEARCH BY LICENSE PLATE, \"OR\" VIN" card -- Plate row, Type/Year row,  
    VIN/Year row, then Vehicle Type/State/NCIC Image options row (matches FL + NJ).  
  (2) Boat field order tidied -- both identifiers (Registration Number + Hull ID) on row 1,  
    State + Stolen Check on row 2 (State was sandwiched between the two identifiers).  
**REASON:** Rob's layout review before the HI tenant sweep. Every fieldId/initialValue/OOS-routing
  signal preserved (Plate Type/Year keep NO default = OOS trigger, VehicleType default=1);  
  QIDM/combos/routing unchanged. Layout-only. ALL 5 ENTITIES RESET for re-test at v4.14 (block by  
  version). Stolen Check default=Y on Firearm/Article/Boat CONFIRMED intended (LE always-check  
  default, Rob-reviewed).  

## v4.13 -- 2026-07-27 -- Boat stolen-label audit fix + UPPERCASE card titles (NO functional change)

**CHANGED:** (a) AUDIT FIX: the v4.12 "Stolen Check" relabel missed the Boat relatedSearchHitIndicator
  (Firearm + Article were relabeled; Boat was left "(Y) for NCIC stolen-boat check"). Caught by the  
  post-rebuild adversarial audit. Boat stolen toggle -> "Stolen Check"; the LABEL-OVERRIDE tag now  
  correctly covers all 3 (Firearm/Article/Boat).  
  (b) UPPERCASE TITLES: all card titles UPPERCASED, wording unchanged (v4.12 query-path titles  
  DL/DH/Firearm/Article/Boat now all-caps; Vehicle SEARCH OPTIONS/PLATE/VIN already caps). New  
  global convention (BUILD_RULES Section 11).  
**REASON:** Adversarial audit (Boat stolen miss) + Rob "everything needs to be upper case" (titles).
  Label/title-only, no combo/QIDM/routing change. verify_build clean. ALL 5 ENTITIES RESET at  
  v4.13 (block by version). NOT yet re-tested.  

## v4.12 -- 2026-07-27 -- DEX-1284 relabel/naming-convention pass (direct Rob feedback, NO functional change)

**CHANGED:** Brought HI in line with the NY/TX/FL/NJ/CA portfolio conventions (HI had diverged --
  parenthetical image label + pre-OLN labels):  
  - OLN: OperatorLicenseNumber (DL) + OperatorLicenseNumberDH (DH) -> "OLN"  
  - canonical bare "NCIC Image" (the one visible image field, Vehicle SEARCH OPTIONS -- was  
    "NCIC Image (if available)"; retires HI's v4.10 parenthetical divergence)  
  - "Stolen Check" (relatedSearchHitIndicator on Firearm/Article/Boat -- was  
    "(Y) for NCIC stolen-X check"; LABEL-OVERRIDE, any[] w/ default Y)  
  - card titles carry query paths: DL/DH "Driver License/History Search by OLN, \"OR\" Name";  
    Firearm/Article "... Search by Serial Number"; Boat "Boat Search by Registration, \"OR\" Hull ID"  
  - Boat Reg dropped "(or use Hull ID)" cross-reference helper  
  Kept the valid DOB/Sex "(required with Name)" + Make/Caliber/Model/Type "(optional)/(required)"  
  hints.  
**REASON:** DEX-1284 portfolio relabel -- HI was the one revisited provider still on the old
  parenthetical "NCIC Image (if available)" wording and pre-OLN labels. Label/title-only, no  
  combo/QIDM/routing/fieldId/default change. verify_build 15P/0W/0F. ALL 5 ENTITIES RESET for  
  re-test at v4.12 (block by version). NOT yet re-tested.  

## v4.11 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.10 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.9 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.8 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.7 -- 2026-07-02 -- NJ/CA-parity modernization + CHECK 16 shadow fix

**CHANGED:** (1) Retired phases/ (removed $PHASEDIR/$VEROUT/-PhasePath; git rm phases/) -- git
  history is the version authority (NJ v4.7 parity). (2) Migrated docs/ to the 4-category  
  structure (tracking/reports/reference/deliverables) and transitioned tests/ -> logs/<Entity>/  
  (legacy tests/ eliminated). (3) VehicleRegistrationQuery -- added OOS reachability gates:  
  LicensePlateTypeCode EXISTS on RQ, RegistrationState EXISTS on RQV, so RQ/RQV no longer shadow  
  M55L/M55S. (4) Corrected stale header comments (VehReg is 4 combos not 6 post-v4.4 QVP/QVV  
  removal; name format is Last-first per v4.0).  
**REASON:** (1-2) Adopt the 2026-07-01 pipeline reorg HI had not yet picked up. (3) verify_build
  CHECK 16 (combo reachability, added post-v4.6 with CA v2.11) found RQ/RQV shadowing M55L/M55S:  
  the platform fires on primaryFieldReference presence, NOT full set[] presence, so RQ  
  (pFR=LicensePlateNumber, ordered first) fired on a bare plate and shadowed the in-state M55L.  
  The EXISTS gates are symmetric to M55L/M55S's NOT_EXISTS gates (FL v7.0 / CA v2.11 pattern):  
  bare plate->M55L, Plate+Type->RQ, bare VIN->M55S, VIN+State->RQV -- mutually exclusive + reachable.  
  (4) Doc accuracy.  
AUDITS: keyRef-vs-devdoc audit CLEAN -- every base keyRef is a real HI XML MessageKey  
  (RQ/M55L/M55S/DQ/QW/KQ/QG/QA/BQ/QB); RQV/DQN/KQN are documented synthetic disambiguations of  
  metadata combos that share a keyReference (RQ x2, DQ x2, KQ x2), LIMITATION #21 / CHECK 9 PASS.  
  NOT the NJ-class wrong-base-term bug (NJ's base terms were wrong vs its devdoc; HI's are correct).  
**RESULT:** 66P/0F/0W, verify CLEAN (incl. CHECK 16). Only the Vehicle fingerprint changes (OOS gates);
  Person/Firearm/Article/Boat unchanged -> prior blocks carry over. Vehicle re-test required; full  
  re-import. JSON key-order also refreshed from current shared modules (harmless).  

## v4.6 -- 2026-06-26 -- : VehicleMakeName VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present; shared module; result-mapping only). Vehicle State label -> 'State (leave blank for Hawaii)' for verify CHECK 15.

**CHANGED:** (1) VehicleMakeName result-mapping (QRDM response) code source corrected from
  attributeType=VEHICLE / codeTypeSource=VehicleType to attributeType=VEHICLE_MAKE /  
  codeTypeSource=NCIC (shared module tools/_build_rms_bundle.ps1; RND-62365). (2) Vehicle  
  State field label changed from 'State (Hawaii = leave blank)' to 'State (leave blank for  
  Hawaii)' to satisfy verify_build CHECK 15 wording.  
**REASON:** (1) RND-62365 -- VEHICLE/VehicleType pairing was absent on the platform registry
  (probe-confirmed VEHICLE_MAKE/NCIC present; matches RND-54190 runbook + sibling  
  VehicleModelName). Result-mapping only -- request-side combos/QIDMs unchanged. (2) CHECK 15  
  refined 2026-06-26 to require the "leave blank for" phrasing on the State label.  
**RESULT:** 66P/0F/0W, verify CLEAN. No QIF/QIDM/combo/conditions change (entity request
  fingerprints identical to v4.5). Rebuild un-confirms all entities -- full re-test from T1.  

## v4.5 -- 2026-06-25 -- Remove orphaned VehicleMakeCode (Make) field -- dead config after QVP/QVV removal

**CHANGED:** Removed the VehicleMakeCode QIDM attribute and the "Make - optional" dropdown from
  the Vehicle VIN SEARCH card (Vehicle Year now full-width on its row). Vehicle QIDM only.  
**REASON:** Per metadata VehicleMakeCode is valid ONLY for the QV (stolen) combo, which was
  removed in v4.4. With no surviving combo (RQ/RQV/M55L/M55S) carrying it in set[]/any[],  
  the Make field was dead config -- it rendered but could never reach the wire. Live-proven  
  v4.4: officer entered Make="YOU'LL HAUL IT" on two VIN fires and it was absent from the XML  
  both times. Adding it to a registration combo would be metadata-invalid (Make is not a  
  registration field), so the field + attribute are removed together.  
**RESULT:** Vehicle re-opens for retest (RQ/RQV/M55L/M55S + guardrails + negative + confirm Make
  field gone from VIN card). Other 4 entities unchanged -- blocks carry over per entity reset.  

## v4.4 -- 2026-06-25 -- QVP/QVV stolen combos removed (clearing Vehicle Type no longer surfaces QV)

**CHANGED:** Removed the two dormant stolen combos (QVP plate+state, QVV VIN+MakeCode) from the
  VehicleRegistrationQuery QIDM. VehicleRegistrationQuery now builds 4 combos (RQ, RQV, M55L,  
  M55S). Vehicle QIDM only -- other entity fingerprints unchanged.  
**REASON:** Live test (v4.3) found that CLEARING the Vehicle Type dropdown on a Plate+State query
  fired QVP (MessageKey=QV, stolen): M55L could not fire without VehicleTypeCode and RQ needed  
  Plate Type/Year, so QVP caught the query and emitted an unintended QV. QVP/QVV were only  
  shadow-dormant (ordered last). They should never fire from the form -- the state CommSys  
  server auto-generates the QV/stolen query from supplied fields (response data-mined via  
  QRDM) -- so they are deleted outright rather than made hard-dormant via a self-contradicting  
  NOT_EXISTS-on-own-set guard (which verify_build CHECK 14 correctly flags as a dead combo).  
**RESULT:** Vehicle re-opens for retest (RQ/RQV/M55L/M55S + guardrails + negative). Other 4
  entities' fingerprints unchanged -- blocks carry over per entity reset. Accepted tradeoff:  
  a Plate+State query with Vehicle Type cleared and no Plate Type/Year now matches no combo  
  and fires nothing (clearing Vehicle Type is an unsupported path). Formalizes the prior  
  user-approved dormant skip of QVP/QVV.  

## v4.3 -- 2026-06-25 -- Versioned filename + version-marker cleanup (NJ-parity galvanization)

**CHANGED:** Root JSON now versioned (HI_HCJDC_OFML_v4.3.json). Removed the top-level
  "version" field (platform rejects it as java.lang.Integer; superseded the v4.2 note  
  below). Stamped "Provider configuration for HI_HCJDC_OFML v4.3" into all 3 bundle  
  descriptions (ENTITIES/PROVIDER/RMS) with description-first ordering for near-the-top  
  visibility. Build-EntitiesBundle/Build-RmsBundle now receive -Description. Added the  
  per-provider CHANGELOG; pruned stale phase snapshot dirs; removed legacy split wording.  
**REASON:** Match the NJ_NJCJIS standard (versioned filenames, version-in-all-bundles, auto
  changelog) and drop the import-breaking version field.  
**RESULT:** Metadata/structure-cosmetic only -- no QIF/QIDM/query change; entity fingerprints
  unchanged, so the 5 confirmed entities carry over (no retest).  

## v4.2 -- 2026-06-24 -- Adopt version field + VehicleMakeName QRDM fix (shared-module currency)

**CHANGED:** Native rebuild on current shared modules. (1) Top-level "version":"4.2" now
  emitted by Write-ProviderJson. (2) VehicleMakeName QRDM attribute codeType corrected  
  from NCIC_FIREARM_MAKE/NJ_NIBRS (firearm-make table -- wrong) to VehicleType/VEHICLE,  
  matching the 2026-06-24 _build_rms_bundle.ps1 fix. Query/combo behavior unchanged  
  (entity fingerprints identical); only results-mapping make resolution + the version  
  field differ.  
**REASON:** Reproducibility audit (audit_reproducible.ps1) found the committed v4.1 JSON was
  DETERMINISTIC but STALE -- it predated the 2026-06-24 shared-module fixes. Rebuilt to  
  bring the committed JSON back in sync with a fresh build.  

## v4.1 -- 2026-06-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.0 -- 2026-06-23 -- Name-order fix (Last-first; HI was lone outlier of 20 providers)

**CHANGED:** HI was the only provider building Name in First-first order, emitting malformed
  "FIRST LAST MIDDLE SUFFIX" (e.g. "JON DOE" instead of "DOE, JON"). Both DL and DH Name  
  attributes now use @('NameLast','NameFirst',...) sourceField order + @(', ',' ',' ') separators  
  -> ConnectCIC-preferred "LAST, FIRST MIDDLE SUFFIX". Re-opens Person+DH for live re-test  
  (Name emitted in different order changes response parsing).  
**REASON:** Cross-provider name-order audit 2026-06-23 found HI as the lone outlier.

## v3.9 -- 2026-06-23 -- Boat Hull>Reg identifier-priority guardrail

**CHANGED:** BoatHullIdNumber NOT_EXISTS condition added to BQ combo (RegistrationNumber set[]).
  When Hull ID is entered, the Reg-path combo exits the union pool so only QB (Hull combo) fires.  
  Hull ID is the unique permanent identifier (VIN-like); Registration Number is reassignable  
  (plate-like). Without the guardrail: enter Hull+Reg -> QB+BQ union over-send (both combos fire).  
  Third identifier pair closed: Vehicle Plate>VIN (v3.6), Person OLN>Name DL+DH (v3.7/v3.8),  
  Boat Hull>Reg (v3.9). Re-opens Boat for live re-test.  
**REASON:** Portfolio review during FL identifier-priority rollout found Boat QIDM had the same
  co-satisfiable identifier pair problem as Vehicle (Plate/VIN) and Person (OLN/Name).  

## v3.8 -- 2026-06-23 -- DH OLN>Name identifier-priority guardrail

**CHANGED:** OperatorLicenseNumberDH NOT_EXISTS added to KQ (DriverHistoryQuery Name combo). When
  OLN is entered on the DH card, the Name combo exits the union pool so Name/DOB/Sex do not  
  bleed into the OLN XML. Mirror of the DL guardrail (v3.7) applied to DH-suffix fields.  
  Without the guard: enter OLN+Name on DH card -> KQN+KQ union over-send (both combos fire,  
  Name+OLN both serialized). Sim-proven before live test.  
**REASON:** DH-side gap found during v3.7 portfolio review -- OLN>Name guardrail must cover
  DriverHistoryQuery as well as DriverLicenseQuery.  

## v3.7 -- 2026-06-23 -- DL OLN>Name identifier-priority guardrail

**CHANGED:** OperatorLicenseNumber NOT_EXISTS condition added to DQ (Name+Sex+DOB combo) and QW
  (Name+DOB combo) in DriverLicenseQuery. When OLN is entered, Name combos exit the union  
  pool so Name/Sex/DOB do not bleed into the OLN XML. Without the guard: enter OLN+Name ->  
  DQN+DQ union over-send (Name+DOB+Sex appear in OLN XML). DL guardrail live-confirmed T6+T8.  
  conditions[].field uses PascalCase (OperatorLicenseNumber) per the form sourceField/fieldId.  
**REASON:** Identifier-priority rollout pattern (Plate>VIN done v3.6; OLN>Name is the second pair).
  DH-side gap (KQ) found and queued for v3.8.  

## v3.6 -- 2026-06-22 -- Plate-wins guardrail + vehicleYear any[] gap fix

**CHANGED:** (1) Added LicensePlateNumber NOT_EXISTS condition to RQV, QVV, and M55S.
  When LicensePlateNumber is in form state, all VIN-path combos exit the union pool  
  so VehicleIdentificationNumber and VehicleMakeCode do not bleed into the plate XML.  
  Discovered via all-fields stress test: Plate+PlateType+PlateYear+VIN+State+Make  
  simultaneously fired RQ+RQV+QVV via union pool -- VIN+Make appeared in XML. Plate  
  should win when present. Mirrors M55L (LicensePlateTypeCode NOT_EXISTS) and M55S  
  (RegistrationState NOT_EXISTS) pool-exclusion pattern. M55S now has two conditions:  
  RegistrationState NOT_EXISTS AND LicensePlateNumber NOT_EXISTS (both must pass).  
  Documented as VEHICLEREGISTRATIONQUERY PLATE-WINS GUARDRAIL in KB BUILD_RULES.  
  (2) Added vehicleYear to any[] of RQV, M55S, and QVV. vehicleYear attribute  
  (sourceField='vehicleYear', targetField='VehicleYear') existed in QIDM but was in  
  no combo's any[], so it was silently dropped from all VIN query XML even when  
  filled by the officer. Plate-path combos (RQ, M55L, QVP) unchanged -- vehicleYear  
  is a VIN-search field only.  
**REASON:** All-fields stress test (2026-06-22) revealed union-pool over-send + any[] gap

## v3.5 -- 2026-06-22 -- QG/QA/BQ/QB any[] gap fix

**CHANGED:** Added any[] and relatedSearchHitIndicator default=Y to GunQuery (QG),
  ArticleSingleQuery (QA), and BoatQuery (BQ/QB). All three QIDMs had any=@() which  
  silently dropped RelatedSearchHitIndicator (default=Y) and optional fields (GunMake,  
  GunCaliber, GunModel on Gun; RegistrationState on Boat) from XML. Platform only  
  serializes set[]+any[] fields. Gap found via simulator pre-flight before first live  
  Firearm/Article/Boat test; v3.4 never had a live test of these three entities.  
  NOTE: Whether v3.4 would have dropped RSH=Y in live XML is unproven (form initialValue=Y  
  may have put it in form state regardless), but the any[] pattern is required and correct --  
  matches FL_FCIC GunQuery and the Attention any[] fix precedent from v2.9.  
  RESULT: 68P/0F/0W/0LIM. Firearm (QG bare + QG+optionals), Article (QA), Boat (BQ/QB)  
  all live-confirmed on v3.5. All 5 entities CONFIRMED. Cosmetic pass pending.  
**REASON:** Pre-live simulator gap detection -- optional fields would not serialize without any[]

## v3.4 -- 2026-06-22 -- M55S any[] RegistrationState removal

**CHANGED:** Removed RegistrationState from M55S any[]. M55S only fires when RegistrationState
  NOT_EXISTS, so State can never serialize alongside it -- the any[] entry was a semantic  
  contradiction and caused the test conductor's Build-MinimalData to inject State="NJ",  
  triggering the NOT_EXISTS condition and blocking M55S (T16 FAIL). M55L UNCHANGED (its  
  condition is LicensePlateTypeCode, so State rides along on in-state plate queries).  
**REASON:** T16 test conductor FAIL -- M55S did not fire; root cause = any[]/condition conflict.

## v3.3 -- 2026-06-22 -- conditions[].field sourceField fix

**CHANGED:** M55S conditions field corrected from @('State') to @('RegistrationState'). T5 (RQV
  OOS VIN) showed VehicleTypeCode still bled because conditions[].field matches the form  
  sourceField, not the QIDM attribute name. M55L worked (T4) only because LicensePlateTypeCode  
  is both attribute name and sourceField. Rule corrected in KB. Vehicle tests restart from T1.  
**REASON:** T5 FAIL -- VehicleTypeCode present in RQV XML (M55S conditions silently no-op'd)

## v3.2 -- 2026-06-22 -- Vehicle State label + minor UX

**CHANGED:** Vehicle State label shortened to 'State (Hawaii = leave blank)' (from longer v3.0
  label). Minor UX refinement only -- pre-live-test pass.  
**REASON:** Label clarity pass before first Vehicle live test.

## v3.1 -- 2026-06-22 -- Label pass

**CHANGED:** Vehicle Type ('Auto (Hawaii queries)') and State ('blank for Hawaii; enter state
  for out-of-state') labels refined. Minor UX iteration.  
**REASON:** Post-v3.0 routing redesign label pass.

## v3.0 -- 2026-06-22 -- Vehicle OOS-first routing redesign (3-card SEARCH OPTIONS / PLATE / VIN)

**CHANGED:** Reordered VehicleRegistrationQuery combos to OOS-first: RQ-plate, RQV VIN+State,
  M55L, M55S (dormant QVV/QVP). OOS is now reached by ADDING fields (add Plate Type+Year  
  for plate; add State for VIN), never by clearing Vehicle Type. RQV now requires VIN+State  
  (State in set[]); removed Plate Year default so a bare plate routes in-state without a year.  
  Vehicle Type combo distinction replaced by State presence: State blank = Hawaii (in-state);  
  State filled = out-of-state. Labels updated to explain the routing.  
**REASON:** v2.8 3-card design confused officers: "clear Vehicle Type to switch to OOS" UX was
  backwards (adding fields = OOS, not clearing). Redesigned to additive routing.  

## v2.9 -- 2026-06-22 -- Attention auto-populate RESOLVED (live-proven)

**CHANGED:** Root cause found: platform serializes ONLY fired-combo set[]/any[] fields. Attention
  handler (CommsysGetLastNameFirstNameInitialRuleHandler) was configured correctly but Attention  
  was NOT in any KQ/KQN combo any[], so it never reached the wire. Fix: added 'Attention' to  
  KQ + KQN any[]; hidden gate-feeder InpH 'Attention' initialValue=X on DH card so the handler's  
  sourceField='Attention' resolves. Live-proven: wire showed <Attention>SGAMBELLONE R</Attention>.  
**REASON:** T10 FAIL -- Attention blank in XML. Root cause = missing any[] entry, not handler config.

## v2.8 -- 2026-06-22 -- Vehicle 3-card design + entity-aware test block-out tooling

**CHANGED:** Vehicle redesigned as 3 cards (SEARCH OPTIONS / PLATE SEARCH / VIN SEARCH) with
  in-state-primary combo order (M55L/M55S first, RQ-plate/RQV-VIN after). Removed Plate  
  Type/Year form defaults so a bare plate routes in-state. RegistrationState added to any[]  
  on M55L/M55S/QVV (State rides along on in-state queries). QVP/QVV dormant (CommSys  
  auto-generates QV). Pointed labels. Also added tooling: entity-aware test block-out  
  (get_entity_fingerprints.ps1 / block_entity.ps1 / .test_state.json) -- per-entity  
  fingerprint reset so rebuilds that touch one entity don't re-open others.  
**REASON:** v2.7 had confusing routing; v2.8 moved to additive OOS selection.

## v2.7 -- 2026-06-22 -- Hidden Attention gate-feeder (experimental, superseded by v2.9)

**CHANGED:** Added InpH 'Attention' initialValue=X on DH card so the auto-Attention handler's
  sourceField resolves when the platform serializes. EXPERIMENTAL -- handler behavior  
  (emit officer name vs echo 'X') was unverified at import. Re-import + re-test from T1.  
  SUPERSEDED: v2.9 proved live that the handler emits the officer RMS profile name, not 'X'.  
**REASON:** v2.6 hypothesis -- hidden gate-feeder needed for handler sourceField to resolve.

## v2.6 -- 2026-06-22 -- REVERT Attention sourceField to @('Attention') (v2.5 unimportable)

**CHANGED:** sourceField on Attention attribute reverted from @() (empty array) back to
  @('Attention'). ConnectCic REJECTED v2.5 at import with "Invalid attributes ... [Attention]"  
  -- empty sourceField is not accepted on this platform. KB RULE_HANDLERS entry 13 corrected.  
  Attention auto-populate believed still INERT (real fix came in v2.9). Re-import + re-test.  
**REASON:** v2.5 import rejection -- platform requires non-empty sourceField[].

## v2.5 -- 2026-06-22 -- PascalCase USx fieldIds + Attention empty-sourceField attempt (UNIMPORTABLE)

**CHANGED:** (1) NATIVE PascalCase USx fieldIds (was camelCase through v2.3). 22 USx CAD tokens
  authored PascalCase; RMS via Build-RmsBundle -PascalCaseUsxFields. (2) Attention sourceField  
  set to @() (empty) based on hypothesis handler doesn't need a form field. FAILED AT IMPORT:  
  ConnectCic rejected with "Invalid attributes ... [Attention]". Superseded by v2.6.  
**REASON:** PascalCase migration + Attention hypothesis test (proved that empty sourceField is rejected).

## v2.4 -- 2026-06-18 -- NATIVE PascalCase USx fieldIds (consolidated single JSON)

**CHANGED:** USx CAD field names (22 tokens) changed from camelCase to PascalCase throughout --
  form fieldIds, QIDM sourceFields, combo set[]/any[]. RMS via Build-RmsBundle -PascalCaseUsxFields  
  so RMS form-fed sourceFields match. Mark43-internal targetFields stay camelCase. Was camelCase  
  through v2.3 (pre-PascalCase conversion). Single JSON model (consolidated v1.8).  
**REASON:** PascalCase migration for CAD/OnScene auto-populate alignment.

## v2.3 -- 2026-06-17 -- DQ primaryFieldReference fix + docs cleanup

**CHANGED:** DQ primaryFieldReference corrected from 'Name' to 'SexCode' (metadata-aligned).
  Stale docs subdirectory removed. Single JSON model reinforced.  
**REASON:** Metadata alignment audit found primaryFieldReference mismatch on DQ combo.

## v2.2 -- 2026-06-17 -- RegistrationState in any[] for OOS queries

**CHANGED:** RegistrationState added to any[] on M55L, M55S, QVV, and DL/DH combos. State now
  rides along on in-state queries (can be filled by officer or CAD; not required for in-state).  
**REASON:** State was absent from any[], silently dropped when filled even if officer entered it.

## v2.1 -- 2026-06-17 -- Vehicle 3-card design iteration

**CHANGED:** Minor layout/label iteration on 3-card Vehicle design.
**REASON:** Post-v2.0 UX pass.

## v2.0 -- 2026-06-17 -- Vehicle 3-card design (initial)

**CHANGED:** Initial implementation of 3-card Vehicle layout (SEARCH OPTIONS / PLATE SEARCH /
  VIN SEARCH). First version with entity-separate cards.  
**REASON:** v1.x single-card Vehicle was not scalable for complex routing.

## v1.9 -- 2026-06-17 -- Post-consolidation iteration

**CHANGED:** Build iteration after single-JSON consolidation. Minor fixes.
**REASON:** Post-consolidation stabilization.

## v1.8 -- 2026-06-17 -- Single-JSON consolidation

**CHANGED:** Consolidated the dual build variants into a single HI_HCJDC_OFML.json. Build
  script merged. No separate per-variant scripts or JSON files from this version onward.  
**REASON:** Single JSON build model adopted repo-wide 2026-06-17.

## v1.1 -- 2026-05-07 -- Add VehicleStolenQuery

**CHANGED**
  - Added VehicleStolenQuery QIDM with 2 combos: QV.P (plate), QV.V (VIN)  
  - Added queriesToDeselect mutual exclusion between VehicleRegistrationQuery and VehicleStolenQuery  
  - VehicleRegistrationQuery: autoSelect=true, queriesToDeselect=VehicleStolenQuery  
  - VehicleStolenQuery: autoSelect=false (officer must manually check), queriesToDeselect=VehicleRegistrationQuery  
  - Invented keyRefs QV.P and QV.V per LIMITATION #21 (metadata has duplicate QV)  
  - 7 transactions, 17 combos total (was 6 transactions, 15 combos)  
  - Validator: 70P/0F/1W/4LIM (was 65P/0F/1W/4LIM)  

## v1.0 -- 2026-04-28 -- Initial build

**CHANGED**
  - Full build from XML metadata + HIDLE RMS reference  
  - 6 transactions, 15 combos, NCIC state pattern  
  - QV stolen + QW wanted combos included per metadata  
  - VehicleTypeCode default=1 (Auto) for in-state routing  
  - Empty any[] on all combos (XML <Any> inside <Set> = optional)  
  - Patch 1+3+6 applied to RMS  

## v1.5 -- 2026-05-11 -- LIMITATION elimination pass


## v1.7 -- 2026-05-27 -- Remove unauthorized VehicleStolenQuery


## v1.6 -- 2026-05-11 -- purposeCodeDH field type fix

