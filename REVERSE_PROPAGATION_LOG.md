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
| RND-62365 | VehicleMakeName QRDM result-mapping code source VEHICLE/VehicleType -> attributeType=VEHICLE_MAKE/codeTypeSource=NCIC (shared module _build_rms_bundle.ps1) | shared module; applied NJ v4.7, FL v6.8, HI v4.6, CA v2.10 | TX_TLETS, NY_NYSPIN_EJUSTICE, AZ_AZDPS | NY_NYSPIN_EJUSTICE cleared (v4.0, confirmed VEHICLE_MAKE/NCIC in rebuilt JSON, 2026-07-02); TX_TLETS cleared (v4.0, 2026-07-09, calls the shared Build-RmsBundle module -- confirmed VEHICLE_MAKE/NCIC present, verified again on the v4.6 rebuild 2026-07-21); pending: AZ_AZDPS |
| PARSECOMMSYS-ARGS | ParseCommsysName empty-args `_R $args`-drop bug (DL#-instead-of-name in CAD) | shared module 1951db4; applied NJ v4.0, CA v2.12 | TX_TLETS, NY_NYSPIN_EJUSTICE, AZ_AZDPS | NY_NYSPIN_EJUSTICE cleared (v4.0, confirmed non-empty ParseCommsysNameRuleHandler arguments in rebuilt JSON, 2026-07-02); TX_TLETS cleared (v4.0, 2026-07-09, calls the shared Build-RmsBundle module -- confirmed non-empty ParseCommsysNameRuleHandler arguments present, verified again on the v4.6 rebuild 2026-07-21); pending: AZ_AZDPS |
| EMIT-GUARDRAIL-SIM | emit_test_plan guardrail expectedKeyRef now simulated (was a structural heuristic that mislabelled in-state/OOS split routing). Regenerate TEST_PLAN + re-run/re-validate guardrail routing. Test-harness fix, NO config change -- clear this flag after the guardrail re-validation passes. | HI_HCJDC_OFML | CA_CLETS, NJ_NJCJIS | FULLY PROPAGATED 2026-07-02: NJ cleared (simulated expectedKeyRefs match live v4.8 guardrail logs); CA_CLETS cleared (live full re-run 93/93 PASS proved IA.QV/ID.L1/IR.QVC.O/IR.QVC.N/NLTS.KQ.O/IA.QB.H guardrail routings the old heuristic had mislabelled as OOS NLTS.*) |
| FORM-REACHABLE-COMBOS | Remove routing-affecting form defaults so every devdoc Basic combination is reachable FROM THE FORM. Prefills that satisfy a required field make a sibling combo win first-match forever. Per audit_query_trace: TX_TLETS/TX_TLETS_CCH = FRT=E + PlateYear=2026 (4 combos, incl. both OutofState paths - also restore RQ+QV, deleted v4.13 as false dead-combos); CA_CLETS = purposeCode=C (12 combos); HI_HCJDC_OFML = vehicleTypeCode=1 (2 combos). Also stop defaulting State where it is any[]-only (TX/AZ/NJ). Gated by enforce PHASE 2n. | TX_TLETS | CA_CLETS, HI_HCJDC_OFML, TX_TLETS_CCH | pending: CA_CLETS, HI_HCJDC_OFML, TX_TLETS_CCH (flagged 2026-07-30) |
| METADATA-DEMOTION-ADJUDICATE | audit_metadata CHECK 4e (new 2026-07-30) reports metadata-required fields built as any[]. Each must be promoted to set[] OR recorded in <PROVIDER>_ACCEPTED_DIVERGENCES.txt with a reason. Counts: AZ_AZDPS 9 (dexStateUserId handler-populated x4 + BirthDate/SexCode on DQSS/KQ -- AZ already carries 2 accepted NOTEs of the same shape), CA_eSUN 2, CA_SAN_LUIS_OBISPO 2, CA_VENTURA_COUNTY 2, OR_LEDS 1. Blocks enforce PHASE 2b until adjudicated. | audit_metadata | AZ_AZDPS, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, OR_LEDS | pending: AZ_AZDPS, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, OR_LEDS (flagged 2026-07-30) |
| NY-METADATA-PARSER-UNKNOWN | audit_query_trace reports 3 NY combos (DALL x2, RVEH) with an EMPTY set[]. Unresolved whether NY metadata genuinely omits Requirements for those combos or the parser misses NY XML shape. NY audit verdict is NOT trustworthy until this is settled -- resolve as step 1 of NY work, before acting on any NY finding. | audit_query_trace | NY_NYSPIN_EJUSTICE | pending: NY_NYSPIN_EJUSTICE (flagged 2026-07-30) |
| UNDER-REQUIRED-CHOICE-BRANCH | Metadata Choice branch requires a field we built as optional any[], so an incomplete wire request can be sent and passes gate 6d. CA_CLETS IG.QGH: metadata needs purposeCode+Name+(Age OR BirthDate); built any[BirthDate,age] means NEITHER is required and log CA_CLETS_v2.22_IG.QGH.txt shipped with neither. NY RVEHOUT is the same class (PlateTypeCode+PlateYear mandatory in alt2, built optional). Gate: tools\audit_requirement_fidelity.ps1. Fix = split the Choice into one combo per branch, never prefill a newly-mandatory field (BUILD_RULES 24). | _metadata_parse.ps1 Get-MetaAltSets unwrap fix | CA_CLETS | pending: CA_CLETS (flagged 2026-07-30) |
