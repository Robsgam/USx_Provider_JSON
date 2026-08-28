# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-28 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.12 | ALL-PASS (53 logs) |
| CA_CLETS | v2.27 | ALL-PASS (99 logs) |
| FL_FCIC | v7.24 | ALL-PASS (118 logs) |
| HI_HCJDC_OFML | v4.20 | ALL-PASS (50 logs) |
| IL_LEADS_OFML | v2.8 | ALL-PASS (44 logs) |
| NJ_NJCJIS | v4.17 | ALL-PASS (41 logs) |
| NM_NMLETS_OFML | v2.7 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.26 | ALL-PASS (65 logs) |
| OH_LEADS | v2.11 | ALL-PASS (65 logs) |
| OR_LEDS | v2.6 | ALL-PASS (27 logs) |
| TN_TIES | v2.6 | ALL-PASS (67 logs) |
| TX_TLETS | v4.22 | ALL-PASS (98 logs) |
| _8 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**DRIVE THE MD_METERS SWEEP.** v2.3 is IMPORTED to its USx provider tenant (2026-08-28) and its
one-time picklist capture is COMPLETE -- 13 selects / 5 entities, `audit_picklist_scope` now silent
on MD while it still speaks on LA_LEMS, so that silence is a verdict and not a vacuum. PHASE 1 green
(8/8 fuzz), enforce 45P/0F/0W, pre-flight CLEAR, 46 tests / 0 hollow toggles. Queue authority for
the other 6 is `report_import_owed.ps1`; all 7 never-tested providers are GATE-CLEAN.

**ORDER IS IMPORT FIRST, THEN PICKLIST CAPTURE** (Rob 2026-08-28: *"you have to import before we can
do picklists"*). This block used to say capture FIRST, which is impossible -- the console script
scrapes the RENDERED form, so the JSON must already be in the tenant. The real rule is that the
capture precedes CHOOSING TEST VALUES: that is what let OR pick a valid plate-type value and is why
CA_VENTURA still cannot fix its hollow toggle.

**MISSION 12 of 20** (`report_mission_status.ps1`). All 7 remaining blocked at the SAME stage --
tenant test. Nothing further can be BUILT to move it. History: git log, not here.

## ROB'S CALLS, NOT MINE

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- pending; the portfolio's only remaining fidelity findings
  (4 UNDER / 3 OVER, verbatim in its BUILD_NOTES). Hold the SWEEP, not the import.
- **LA_LEMS BoatQuery `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **eSUN 228KB tenant export** in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS

- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default, so that test
  proves nothing. Needs TEST_VALUE_OVERRIDES -- but choose the value AFTER its picklist capture.
- **7 providers owe the one-time picklist capture**, 0 owe a re-scope, 13 current -- measured
  2026-08-28 via `audit_picklist_scope -All`. This line read "10" and was stale.
- **3 providers carry stale ancillary artifacts** (picklist report + label review predate the JSON):
  CA_VENTURA_COUNTY, LA_LEMS, TX_TLETS_CCH. Portfolio `enforce` WARNs on each. Clear at each
  provider's own turn via `build_report -Path <json> -IncludeExtended`; no wire impact.
- **LIMITATION #41** (populated HOME state routes a local plate to NLETS) -- paused pending CommSys.
- **NCIC hit blocks CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI and TN.
- **Officer guides content-poor**; rewrite requested, shape not agreed.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02 (NM's 24 UNREACHABLE spec tests
  are this). CommSys asks HELD. TX_TLETS_CCH testing PARKED. DH NOT SUPPORTED FROM CAD.
  TN `RQ01` + name-component casing CLOSED 08-24. A keyRef NEVER reaches the wire.
- **4 providers carry `[FLAG:plan-dedupe-vacuous-tests]`** (FL, HI, IL, NJ). CORRECTLY deferred --
  regenerating their plans orphans their logs and drops them out of ALL-PASS. **Not work owed.**
- **Jira is HELD and lifts ONE PROVIDER AT A TIME.** No approval carries to the next provider.
  The TX/OR release comments each carry a catalog/Foundation line -- a deliberate override of the
  template's "NO TENANT DETAIL" rule, directed by Rob each time. Do not "correct" them, do not repeat
  unasked.

## RULES I BROKE -- READ BEFORE EDITING

- **Know whether a tool WRITES before running it as a "check".** `block_entity` stamps, commits and
  pushes; running it across 5 providers to "verify" a change flipped NY/NJ/TN state. Reverted.
  `audit_*`/`report_*` read; `block_entity`/`post_test`/`reset_test_package`/`flag_pending_fix` write.
- **Mutate a REPLICA, never the real file.** `git checkout --` restores content but stamps mtime, so
  MD's JSON outran its own artifacts and enforce went 0 FAIL -> 3 FAIL on a provider I never changed.
- **A probe that matches its own command line lies** -- twice today.
- **Check ACCEPTED_DIVERGENCES before calling a reported gap new** -- TX's plate+State symptom, cause
  and fix were all recorded 2026-07-30; I re-derived them.
- **SQVR prose never expires on its own** -- resets rewrite MARKERS, not narrative.
- **Run `audit_session_state` BEFORE committing this file.** I wrote a "what we did today" section,
  which is precisely the accumulation the 120-line gate exists to stop, and committed it failing.
