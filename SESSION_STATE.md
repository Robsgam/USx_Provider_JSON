# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-09-10 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.12 | ALL-PASS (53 logs) |
| CA_CLETS | v2.27 | ALL-PASS (99 logs) |
| CA_CLETS_OCATS | v2.12 | ALL-PASS (62 logs) |
| CA_eSUN | v3.3 | ALL-PASS (74 logs) |
| FL_FCIC | v7.24 | ALL-PASS (104 logs) |
| HI_HCJDC_OFML | v4.20 | ALL-PASS (48 logs) |
| IL_LEADS_OFML | v2.8 | ALL-PASS (43 logs) |
| MD_METERS | v2.4 | ALL-PASS (47 logs) |
| NJ_NJCJIS | v4.17 | ALL-PASS (39 logs) |
| NM_NMLETS_OFML | v2.7 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.26 | ALL-PASS (65 logs) |
| OH_LEADS | v2.11 | ALL-PASS (65 logs) |
| OR_LEDS | v2.6 | ALL-PASS (27 logs) |
| TN_TIES | v2.6 | ALL-PASS (67 logs) |
| TX_TLETS | v4.22 | ALL-PASS (98 logs) |
| _5 others_ | -- | never tenant-tested: CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

**MISSION: 13 of 20 LIFECYCLE-COMPLETE** (`report_mission_status.ps1`). Owed: **test 4**
(CA_CONTRA_COSTA -- BLOCKED on Rob's JAWS call; CA_SAN_LUIS_OBISPO, CA_VENTURA, LA_LEMS -- measured
sweep-ready, CA_VENTURA residual is its hollow toggle pending a picklist capture) and **jira 2**
(CA_CLETS_OCATS DEX-980; CA_eSUN DEX-1312/1313 owes a v3.3 release line). TX_TLETS_CCH is PARKED.
**A never-tested provider is owed a SWEEP, not an import** (Rob 2026-09-09). **SDSO LIVE runs eSUN
v1.0 vs repo v3.3** -- Rob's call. Officer guides 20/20 current. Handover: `USX_PROJECT_GUIDE.pdf`.
**ANY PRIOR JSON IS ONE COMMAND:** `get_provider_version.ps1 -Provider <P> -Version <X.Y>` -- 671
artifacts, byte-exact from git. RETRIEVAL, not rebuild: re-running an old script does NOT reproduce it.

## ROB'S CALLS, NOT MINE

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- 4 UNDER / 3 OVER, verbatim in its BUILD_NOTES. Hold the
  SWEEP, not the import. **LA_LEMS `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **MINED-KEYREF, 4 EXPOSED** (`_probes/sweep_mined_keyref_shadow.ps1`): eSUN QV.V->4V, QB.H->4V, QB.R->4B; CA_SAN_LUIS_OBISPO QV.V->4V. A rename, not a wire change; both never-tested. eSUN's 228KB tenant export sits in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **194 of 264 registry rows unverifiable** by `audit_registry_currency`; 7 providers at zero checkable rows, and the first row opened by hand there was FALSE.
- **CA_eSUN v2.2: 2 BUILD_NOTES items deliberately OFF the ticket** -- the 7 validator FAILs the 53 captures REFUTE, and the BirthDate over-permit whose fix collapses the owner-name search.
- **LIMITATION #41** (HOME state routes a local plate to NLETS) -- paused pending CommSys; 5 providers owe a picklist capture. **CA_VENTURA hollow toggle** needs a TEST_VALUE_OVERRIDE after its capture. **RESWEEP 2026-09-08: 20/20 ENFORCED 0F/0W**; fidelity 426 branches, the only 4 UNDER / 4 OVER are CA_CONTRA_COSTA(Rob(s JAWS call).

## THE DEPLOY LOOP IS BUILT AND PROVEN (2026-09-11/12) -- detail in git, resume point below.

`emit_import_job.ps1` -> review `providers\IMPORT_JOB.json` -> **panel button RUN THE JOB FOR THIS
TENANT** -> auto re-export -> `watch_imports.ps1` -> `verify_tenant_import` PASS/DID-NOT-LAND/FAIL.
`deploy_probe.js` is the ONLY file that can write; dry-run by default; 46 mutation cases in
`audit_deploy_guards`. First automated import proven by hash: usx-fl-fcic CA_eSUN v3.3 -> FL_FCIC v7.24.
⚠️ **NEVER hand Rob a console command** -- GUI only. ⚠️ An import **REPLACES** the bundle set.

## ⏸ TENANT WORK IS HELD (Rob 2026-09-14: "HOLD ALL THIS ... we need to pivot to a new provider")

**THE RECOVERY RECORD IS `providers\HELD_TENANT_WORK.md` -- read it before resuming.** Nothing is
half-applied: all committed, all gates green, and the only outstanding action is ONE operator click.
In one line: **`newarkpd-foundation` (68055618928) runs NJ_NJCJIS v4.16 while ledger AND catalog say
v4.17** -- proven five ways including three pulls two days apart at payload SHA `E8A370D0ABB66B1A`.
Job `job-20260912-215904` is cut; `intendedProvider` is recorded on its `tenant_map.json` row.
⚠️ **Still unexplained, and worth more than the import: WHY the 2026-08-20 import did not land** when
the release line and catalog update from the same pass did. Also held (Rob's calls): scoping,
`LEDGER_PATCH.md`, `hawaii-dle` LIVE, the batch, Confluence.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02. OH's `ReasonCode`/`Requestor` =
  the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH testing PARKED. DH NOT SUPPORTED FROM CAD.
  TN `RQ01` + name-component casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, nor does `primaryFieldReference`** -- before calling an
  identity-label difference a defect, ask whether the label ships. **`[FLAG:plan-dedupe-vacuous-
  tests]` is DONE** (FL/HI/IL/NJ/NY, 2026-08-31); inflation reads 853 logs / 0 findings.
- **NY DEMOTED-QUALIFIER: CLOSED, not owed** (`ny-demote-mandatory-qualifier` is [KILLED] 2026-09-09;
  no third fix -- two REJECTED, see `FINDINGS_REGISTER.md`). **NJ guardrail mutation: N/A, not stale**
  -- unhostable portfolio-wide; do NOT re-aim. Both were stale-OWED claims IN THIS FILE that invented
  work on tenant-verified providers -- **measure before believing this file.**
- **Jira is HELD and lifts ONE PROVIDER AT A TIME.** No approval carries to the next provider.

## RULES I BROKE -- READ BEFORE EDITING

- Two durable rules MOVED to `usx-tooling` (Steps 6 / 8a): **a registry row only suppresses if its
  rule name is the string the gate greps**, and **validate every probe against a known answer WITH
  negative controls**. **A `#`-COMMENTED LINE IS NOT A FINDING** (2-6 false blockers on 4 providers).
- **NEVER verify a produced file with `Test-Path`** (a leftover satisfies it -- compare write times). **REPLACE this file, never append:** it has failed its own 120-line gate five times, twice today.
- **A SAME-LOOKING STRUCTURE ON ANOTHER PROVIDER IS A QUESTION, NEVER A PRECEDENT.** 5 claims
  retracted 2026-09-08. Read that provider's OWN `<Requirements>` FIRST.
- **A STALE MUTATION IS INDISTINGUISHABLE FROM A BLIND GATE** -- give every new mutation a `Valid={}`.
- **AN EXPLANATION IS NOT A MEASUREMENT.** I wrote a plausible `file://` story for 3 extension
  scripts instead of getting the real error; they were genuinely broken, dead 5 days.
- **MY OWN LEDGER/STATE ROWS GO STALE WITHIN HOURS.** I wrote eSUN "NOT IMPORTED" and it was false
  by afternoon; a tool caught that Section A had no eSUN row at all. Re-read before citing.
