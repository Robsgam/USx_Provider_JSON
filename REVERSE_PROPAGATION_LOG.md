# Reverse-Propagation Log

Pending-rebuild ledger for shared-module / JSON bug fixes that must propagate to
providers on their next rebuild. This is the machine-readable companion to the
narrative `REBUILD_TRACKER.md` (which explains the "why"); this file is the
source-of-truth list of *who is pending which fix*.

**How it works** (pull-based, one-at-a-time — no mass patching):
- A fix ships in a shared module / build script. It self-applies to each provider on
  that provider's next rebuild (the build script also deletes its `PENDING_UPDATES.txt`).
- `tools/flag_pending_fix.ps1` writes a `[FLAG:<id>]` stub into each still-pending
  provider's `docs/tracking/PENDING_UPDATES.txt` and appends a row here.
- `enforce.ps1` PHASE 1 FAILs any provider whose `PENDING_UPDATES.txt` has a non-`#`
  line — so a flagged provider cannot be tested until it is rebuilt.
- `tools/audit_reverse_propagation.ps1` reads this ledger + every `PENDING_UPDATES.txt`
  and reports pending/propagated status. Composed into `doctor.ps1`.
- **Hand-curate the Status column** as providers rebuild (mark applied vX.Y). A fix with
  zero remaining pending providers is fully propagated (leave the row for history).

| Fix ID | Description | Origin | Affected | Status |
|---|---|---|---|---|
| RND-62365 | VehicleMakeName QRDM result-mapping code source VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (shared module _build_rms_bundle.ps1) | shared module; applied NJ v4.7, FL v6.8, HI v4.6, CA v2.10 | TX_TLETS, NY_NYSPIN_EJUSTICE, AZ_AZDPS | pending: TX_TLETS, NY_NYSPIN_EJUSTICE, AZ_AZDPS |
| PARSECOMMSYS-ARGS | ParseCommsysName empty-args `_R $args`-drop bug (DL#-instead-of-name in CAD) | shared module 1951db4; applied NJ v4.0, CA v2.12 | TX_TLETS, NY_NYSPIN_EJUSTICE, AZ_AZDPS | pending: TX_TLETS, NY_NYSPIN_EJUSTICE, AZ_AZDPS |
| EMIT-GUARDRAIL-SIM | emit_test_plan guardrail expectedKeyRef now simulated (was a structural heuristic that mislabelled in-state/OOS split routing). Regenerate TEST_PLAN + re-run/re-validate guardrail routing. Test-harness fix, NO config change -- clear this flag after the guardrail re-validation passes. | HI_HCJDC_OFML | CA_CLETS, NJ_NJCJIS | FULLY PROPAGATED 2026-07-02: NJ cleared (simulated expectedKeyRefs match live v4.8 guardrail logs); CA_CLETS cleared (live full re-run 93/93 PASS proved IA.QV/ID.L1/IR.QVC.O/IR.QVC.N/NLTS.KQ.O/IA.QB.H guardrail routings the old heuristic had mislabelled as OOS NLTS.*) |
