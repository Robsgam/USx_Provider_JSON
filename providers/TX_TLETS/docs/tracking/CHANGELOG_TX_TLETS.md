# TX_TLETS -- Changelog

Auto-generated from `TX_TLETS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.0** | Generated: 2026-07-10

---

## v4.0 -- 2026-07-09 -- Rebuild under current methodology (PascalCase + condensed UI + reachability)

**CHANGED:**
  1. PascalCase USx CAD fieldIds authored natively (22-token set) + -PascalCaseUsxFields on the RMS  
     bundle; Mark43-internal keys stay camelCase. Versioned root filename TX_TLETS_v4.0.json.  
  2. Cleared both PENDING_UPDATES flags -- shared-module fixes verified present in the JSON:  
     VehicleMakeName QRDM now VEHICLE_MAKE/NCIC (RND-62365, not the firearm table); ParseCommsysName  
     carries its NormalizedName* args (PARSECOMMSYS-ARGS).  
  3. Condensed FL-style UI + full CHECK-15 label-hint pass across all 5 entities. Person keeps the  
     shared OPTIONS card; emailAddress exposed/untouched (auto-handler to be added later by the  
     owning team). Exposed MessageKey (CPL/DWI/RDL) on the DL card + CPL combo any[] (metadata is  
     the field-authority).  
  4. CHECK-16 reachability: set[] does NOT gate firing (only primaryFieldReference + conditions do),  
     so the metadata combos that differed only by set[] were permanently shadowed. Added  
     existence-only EXISTS gates so all are reachable: VIN -> FinancialResponsibilityType EXISTS;  
     QV-VIN -> RegionId EXISTS (+ RegionId promoted any->set, ordered before RQ-VIN, recorded in  
     ACCEPTED_DIVERGENCES); DL DQName -> SexCode EXISTS; QWName -> BirthDate EXISTS; Boat BQ combos  
     -> RegistrationState EXISTS.  
  5. DH image-variant split MERGED to 2 combos (KQName/KQOLN). The v3.8 set[]-based split never  
     actually enforced "Image=Y only with email" (set[] does not gate firing) and shadowed the  
     plain path. ImageIndicator=Y default now triggers the ReasonCode=C + EmailAddress trio, all in  
     any[] (sent when present; email typed now, handler later).  
  6. Structure migrated: docs -> 4-category (tracking/reports/reference/deliverables), tests/ -> logs/,  
     phases/ retired, stray TX_TLETS_FINAL.plan.json removed.  
**RESULT:** validator 81P/0F/0W, verify_build CLEAN (16 checks incl. reachability), 22 CommSys combos,
  7 cards. Full re-test from T1 on re-import.  
**REASON:** Scheduled rebuild under the current methodology (was out-of-scope/camelCase/legacy layout).

## v3.13 -- 2026-06-24 -- Gap-audit remediation (Hull>Reg completion + CAD plate defaults)

**CHANGED:**
  1. Hull>Reg guardrail COMPLETED -- added boatHullIdNumber NOT_EXISTS to BQRegistrationNumber.  
     v3.12 only gated the in-state QBRegistrationNumber; the OOS Nlets BQRegistrationNumber was  
     missed, so Hull+Reg+State co-entry still bled RegistrationNumber into the Hull XML. Found by  
     verify_build CHECK 12 once it was promoted to FAIL (was a silent WARN).  
  2. CAD plate-default gap -- REGLicensePlateNumber (set: plate+year+FRT) and RQLicensePlateNumber  
     (set: plate+year+type) require licensePlateYear / licensePlateTypeCode in set[], but CAD  
     ignores form initialValue, so CAD-dispatched REG/RQ plate queries could not fire. Added  
     LicensePlateYear=$currentYear and (RQ) LicensePlateTypeCode=PC combo defaults. Surfaced by  
     audit_cad CHECK 6 after it was fixed to scan set[] (not just any[]).  
CONTEXT: part of the portfolio gap-audit (TX/FL/HI). Tooling hardened in the same pass:  
  verify_build CHECK 14 (gate-xor-companion), CHECK 12 -> FAIL, run_test_matrix exact-match,  
  audit_cad case-fix + set[] scan, and verify_build + audit_cad wired into enforce as blocking gates.  
**RESULT:** 83P/0F/0W/0LIM; verify_build CLEAN (14 checks); audit_cad 76P/0F; conductor 37/37.
  Re-import + full re-test from T1 (test package reset).  

## v3.12 -- 2026-06-23 -- Identifier-priority rollout + Attention resolved

**CHANGED:**
  1. Identifier-priority guardrail applied for all 3 pairs (NOT_EXISTS conditions,  
     camelCase QIF sourceField -- verify_build CHECK 13):  
     - Plate>VIN: licensePlateNumber NOT_EXISTS on the VIN-path vehicle combos  
       (VINVehicleIdentificationNumber, RQVehicleIdentificationNumber, QVVehicleIdentificationNumber).  
     - OLN>Name (DL): operatorLicenseNumber NOT_EXISTS on DQName / QWName / CPLName.  
     - OLN>Name (DH): operatorLicenseNumberDH NOT_EXISTS on KQNameImg / KQName.  
     - Hull>Reg: boatHullIdNumber NOT_EXISTS on QBRegistrationNumber.  
  2. ATTENTION auto-populate RESOLVED (reverses the v3.11 "INERT" conclusion) using the  
     HI v2.9 pattern: 'Attention' added to all 4 DH combo any[]; hidden InpH gate-feeder  
     (initialValue='X') added to the DH card; sourceField=['Attention'];  
     CommsysGetLastNameFirstNameInitialRuleHandler on the Attention attribute. Pending  
     live confirmation at re-test.  
  3. CAD audit CHECK 6: added Attention=X default to both DH combo default sets  
     ($imgDefsDH / $noImgDefsDH) to match the gate-feeder's form initialValue.  
  4. vehicleYear added to the VIN combo any[] (attribute existed but was in no combo any[],  
     so it was silently dropped from VIN XML).  
  5. QBRegistrationNumber: boatHullIdNumber removed from any[] -- a field cannot be in the  
     serialization pool AND be the subject of a NOT_EXISTS gate on the same combo (the  
     contradiction also poisoned the test conductor's minimal-data injection).  
TOOLING: generate_test_matrix.ps1 now emits the full keyRef (not the collapsed short prefix)  
  in each Expected line, so run_test_matrix.ps1 resolves the specific combo rather than the  
  first sibling sharing a prefix (QBRegistrationNumber / QBBoatHullIdNumber / QBNCICNumber  
  previously all collapsed to 'QB' and false-passed). Verified non-regressive on FL (42/42).  
**REASON:** Roll the identifier-priority guardrail to TX (3rd provider after HI/FL) and resolve
  Attention now that the HI v2.9 root cause (missing from combo any[]) is understood.  
**RESULT:** 83P/0F/0W/0LIM; conductor 37/37 PASS; CAD audit 76P/0F; metadata 178P/0F.
  Re-import + full re-test from T1 (test package reset).  

## v3.11 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.10 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.9 -- 2026-06-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.8 -- 2026-06-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.7 -- 2026-06-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.6 -- 2026-06-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.5 -- 2026-06-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v3.4 -- 2026-06-14 -- Poisoned-array fix (DL+DH ImageIndicator conditions)


## v3.3 -- 2026-06-09 -- Remove unauthorized VehicleStolenQuery


## v3.2 -- 2026-05-26 -- Conditional image/email routing (ImageIndicator conditions)


## v3.1 -- 2026-05-22 -- Single JSON rebuild (BASE/MC merge, 0 LIM)


## v3.0 -- 2026-05-20 -- Fresh rebuild -- minimized cards, tightened layouts, full defaults


## v2.7 -- 2026-05-18 -- One-directional queriesToDeselect fix


## v2.6 -- 2026-05-18 -- EmailAddress user-fillable + Attention fix + DH-suffix


## v2.2 -- 2026-05-07 -- Add VehicleStolenQuery (metadata gap fix)


## v2.1 -- 2026-05-06 -- PlateType/PlateYear defaults (cross-provider audit)


## v2.0-mc -- 2026-05-05 -- MC multi-card layout variant


## v2.0 -- 2026-05-05 -- Complete rebuild from scratch


## v1.0 -- 2026-04-23 -- queryLabel standardization (direct JSON edit)


## v1.0 -- 2026-04-21 -- Initial standup


## v2.5 -- 2026-05-11 -- LIMITATION elimination pass

