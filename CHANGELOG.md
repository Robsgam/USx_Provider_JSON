# ConnectCIC Provider Changelog

Track-level change history for Jira/release reference. Each entry is a meaningful milestone,
not every build bump. Routine pipeline rebuilds are omitted unless they carry functional changes.

---

## NJ_NJCJIS

Current: **v4.14** — 61P/0F/0W/0LIM | live test PENDING (full re-test from T1) | import: `NJ_NJCJIS_v4.14.json`

### v4.8 (2026-07-01) — Metadata-driven keyRef rename (DQ/DQN/RQ/RQN did not exist in devdoc)
- DriverLicenseQuery `DQ`→`FULL`, `DQN`→`FULLN` (devdoc keyReference is `FULL` for both combos, confirmed in raw devdoc XML)
- VehicleRegistrationQuery `RQ`→`RANDFULL`, `RQN`→`RANDFULLN` (devdoc defines 4 combos under keyReference `RAND`/`FULL`, each identical Set/Any per identifier — one merged physical combo per identifier required; compound name reflects both)
- `DQ`/`DQN`/`RQ`/`RQN` did not exist anywhere in NJ's devdoc — a cross-provider naming habit, not derived from this provider's own metadata; re-import + full re-test from T1

### v4.7 (2026-06-26) — VehicleMakeName code source corrected (RND-62365)
- VehicleMakeName result-mapping code source corrected VEHICLE/VehicleType → attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present; matches RND-54190 runbook + sibling VehicleModelName)
- Fixes Newark vehicle "Mock results processed" (v4.6 VehicleType/VEHICLE pairing absent on Newark instance)
- Shared module `tools/_build_rms_bundle.ps1`; NJ rebuilt only (other 4 live providers tabled); re-import + full re-test from T1

### v4.3–v4.5 (2026-06-22 – 2026-06-24) — Identifier-priority guardrails + pipeline rebuild
- Added `NOT_EXISTS` conditions to VehicleRegistrationQuery (Plate>VIN guardrail: `RQN` exits union pool when plate present)
- Added `NOT_EXISTS` condition to BoatQuery (Hull>Reg guardrail: `QB` exits when hull ID present)
- Added `NOT_EXISTS` condition to DriverLicenseQuery (OLN>Name guardrail: `DQ` exits when OLN present)
- Rebuilt via pipeline.ps1 for reproducibility; all 3 guardrails live-proven (T6, T13, T20)
- Fixed `_R $args` drop bug: `ParseCommsysName` handler restored RMS arg pass-through

### v4.0–v4.2 (2026-06-17 – 2026-06-18) — PascalCase fieldIds + single-JSON model
- All 22 USx CAD fieldIds natively authored PascalCase (removed `Convert-UsxCasing` transform)
- Merged BASE/MC → single `NJ_NJCJIS.json`; docs moved to `docs/` (not `docs/mc/`)
- VehicleStolenQuery QIDM removed (user-approved skip; `VehStolenRemoved` mainline chosen)
- 29-test matrix format: per-combo any[] tests + guardrail routing tests added

### v3.5-PASCAL (2026-06-11) — PascalCase evaluation variant
- First PascalCase live test on USx tenant; confirmed platform requires PascalCase for OnScene/CAD

### v3.6-COLLAPSED / v3.6-REMOVED (2026-06-10) — Stolen vehicle redesign evaluation
- Two experimental branches built: `VehStolenSeparate` (isolated RANDOM card) vs `VehStolenRemoved` (QV omitted)
- Neither live-tested; `VehStolenRemoved` promoted to mainline 2026-06-17

### v3.4 (2026-05-21) — BASE/MC merge + State defaults
- Merged to single-JSON build; `State=NJ` defaults added to all VehReg combos for CAD dispatch

### v3.3 (2026-05-19) — CAD defaults: all combos
- Added `defaults[]` to all 13 CommSys combos (CAD ignores QIF `initialValues`)
- New rule: `audit_cad.ps1 CHECK 6` gates this at build time

### v3.2 (2026-05-18) — RandomRequest conditions routing
- `RandomRequest` moved from `set[]` to `any[]`; conditions added (RAND combos fire when `Y`, else RQ/RQN fallback)
- Root cause: CAD dispatch omits `RandomRequest`; `set[]` placement blocked all CAD VehReg queries

### v3.1 (2026-05-11) — DL combo reorder
- Name (3 set fields) before OLN (2 set fields) — most-specific-first rule

### v3.0 (2026-05-08) — Newark lock + first live import
- v2.9 passed 16/16 live tests; v3.0 locked and imported Newark Foundation Tenant 2026-05-11

### v2.9 (2026-05-08) — One-directional deselect (resolved bidirectional deadlock)
- VehReg: `autoSelect=true`, no deselect (default query)
- VehStolen: no `autoSelect`, `queriesToDeselect=[VehicleRegistrationQuery]` (opt-in)
- Resolved "error pop up" caused by mutual `queriesToDeselect` (v2.3/v2.8 deadlock)
- LIVE TEST: 16/16 PASS

### v2.0 (2026-04-28) — New XML metadata rebuild
- New VehicleStolenQuery (QVN/QVP/QVV), RandomRequest mandatory, ImageIndicator on all transactions
- LIVE TEST: BASE 17/17 PASS, MC 57/57 PASS (2026-04-29)

---

## HI_HCJDC_OFML

Current: **v4.14** — 65P/0F/0W/0LIM | live test PENDING (full re-test from T1) | import: `HI_HCJDC_OFML_v4.14.json`

### v4.6 (2026-06-26) — VehicleMakeName code source corrected (RND-62365) + State label (CHECK 15)
- VehicleMakeName result-mapping code source corrected VEHICLE/VehicleType → attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present; matches RND-54190 runbook + sibling VehicleModelName)
- Vehicle State label → `State (leave blank for Hawaii)` to satisfy verify_build CHECK 15
- Shared module `tools/_build_rms_bundle.ps1`; result-mapping only (request-side combos/QIDMs unchanged); re-import + full re-test from T1

### v4.0–v4.2 (2026-06-23 – 2026-06-25) — Pipeline rebuild + 50-test matrix
- Reproducibility rebuild (behavior-identical to v3.9); entity fingerprints preserved
- Test matrix expanded to 50 tests (was 28): per-combo any[] tests + guardrail routing tests
- Attention handler confirmed: `KQ`/`KQN` auto-populate `<Attention>SGAMBELLONE R</Attention>`

### v3.9 (2026-06-22) — All 3 identifier-priority guardrails live-proven
- Hull>Reg guardrail added (`QB` NOT_EXISTS condition on `HullIdentificationNumber`)
- All 3 pairs live-proven: Plate>VIN (T6/T7), OLN>Name (T9/T10), Hull>Reg (T22/T23)
- 5/5 entities CONFIRMED; provider declared COMPLETE

### v3.6 (2026-06-22) — Plate-wins guardrail + vehicleYear fix
- `LicensePlateNumber NOT_EXISTS` condition on RQV/QVV/M55S (plate wins over VIN combos)
- `vehicleYear` added to RQV/M55S/QVV `any[]` (was missing; VIN searches lacked Year)
- LIVE TEST: 7/7 Vehicle tests PASS (T1–T7); guardrail decisive on T6 + T7

### v3.4 (2026-06-21) — M55S semantic fix + OLN>Name guardrail
- `RegistrationState` removed from M55S `any[]` (M55S only fires when State absent — contradiction)
- `conditions[].field` corrected: must match `sourceField` (form fieldId), NOT XML attribute name
- OLN NOT_EXISTS conditions added to DQ/QW/KQ (OLN>Name priority guardrail)

### v3.3 (2026-06-20) — conditions field sourceField fix (proof-of-concept)
- Root cause proven: `conditions[].field = 'State'` (attribute) was silently inert;
  `conditions[].field = 'RegistrationState'` (sourceField) is what the platform reads
- Controlled live test (HI T5): VehicleTypeCode no longer bleeding into RQV XML

### v2.9 (2026-06-20) — DH Attention handler + OLN>Name DL/DH
- Auto-populated `<Attention>` via hidden gate-feeder + handler on KQ/KQN
- DL/DH OLN>Name: NOT_EXISTS conditions on DQ/KQ so DQN/KQN win when OLN present

---

## CA_CLETS (CA_CLETS_OFML)

Current: **v2.22** — 77P/0F/0W/0LIM | live test PENDING (full re-test from T1) | import: `CA_CLETS_v2.22.json`

### v2.12 (2026-07-01) — Restore in-state DriverLicenseQuery combos (ID.L1 / IN.L1)
- DL 6 → 8 combos: restored `ID.L1` (in-state OLN) + `IN.L1` (in-state Name), the real devdoc keyRefs v2.11 removed
- v2.11 dropped them expecting "CommSys auto-dispatches, consistent with Vehicle pattern" — but Vehicle keeps an unconditioned in-state catchall (`IA.QV`/`IA.QVK`) and DL kept none, so a plain in-state driver lookup (OLN-only / name-only, no State) fired nothing
- Restored as gated catchalls; `IR.QVC.O`/`IR.QVC.N` conditions tightened for mutual exclusion; verify_build CHECK 16 reachability CLEAN. Full re-test from T1

### v2.10 (2026-06-26) — VehicleMakeName code source corrected (RND-62365)
- VehicleMakeName result-mapping code source corrected VEHICLE/VehicleType → attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (RND-62365; probe-confirmed present)
- Shared module `tools/_build_rms_bundle.ps1`; result-mapping only, request-side combos unchanged
- Identifier-priority guardrails CONFIRMED (prior). See REBUILD_TRACKER.

---

*For FL, TX, NY, AZ status see `REBUILD_TRACKER.md`.*
