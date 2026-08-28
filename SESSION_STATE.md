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
| MD_METERS | v2.3 | ALL-PASS (46 logs) |
| NJ_NJCJIS | v4.17 | ALL-PASS (41 logs) |
| NM_NMLETS_OFML | v2.7 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.26 | ALL-PASS (65 logs) |
| OH_LEADS | v2.11 | ALL-PASS (65 logs) |
| OR_LEDS | v2.6 | ALL-PASS (27 logs) |
| TN_TIES | v2.6 | ALL-PASS (67 logs) |
| TX_TLETS | v4.22 | ALL-PASS (98 logs) |
| _7 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**MD_METERS v2.3 IS SWEPT AND WAITING ON ONE JIRA DECISION.** ALL-PASS 46/46 (Veh 11 / Per 27 / Gun 1
/ Art 1 / Boat 6), four log gates 46/46, `enforce -Provider MD_METERS` 44P/0F/0W, ledger records the
install, SQVR populated, picklists captured. Blocked ONLY at stage 5: a v2.3 release line is DRAFTED
in `providers/MD_METERS/docs/tracking/DEX_TICKET.md` and deliberately NOT posted -- DEX-987 (found by
JQL, recorded nowhere in the repo before today) has zero comments and Jira lifts ONE provider at a
time. **Rob's approval is the next physical action.**

**THEN: import + sweep the next of 6** (`report_import_owed.ps1`) -- CA_CLETS_OCATS, CA_CONTRA_COSTA,
CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS. All gate-clean, all blocked at stage 4.
**ORDER IS IMPORT FIRST, THEN PICKLIST CAPTURE** (Rob 2026-08-28: *"you have to import before we can
do picklists"*) -- the console script scrapes the RENDERED form, so the JSON must be in the tenant
first. The capture precedes CHOOSING TEST VALUES, which is why CA_VENTURA still cannot fix its
hollow toggle.

**MISSION 12 of 20** (`report_mission_status.ps1`): 6 blocked at test, 1 (MD) at jira. History: git
log, not here.

## ROB'S CALLS, NOT MINE

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- pending; the portfolio's only remaining fidelity findings
  (4 UNDER / 3 OVER, verbatim in its BUILD_NOTES). Hold the SWEEP, not the import.
- **LA_LEMS BoatQuery `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **eSUN 228KB tenant export** in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS

- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default, so that test
  proves nothing. Needs TEST_VALUE_OVERRIDES -- but choose the value AFTER its picklist capture.
- **6 providers owe the one-time picklist capture** + TX_TLETS_CCH (parked), 0 owe a re-scope --
  `audit_picklist_scope -All`. Was "10", then 7; MD closed its capture 2026-08-28.
- **6 providers carry an EMPTY 13-line SQVR scaffold** ("populate after build") and
  `audit_sqvr_integrity` PASSES all of them -- a file naming nothing and asserting no total gives the
  gate nothing to compare, so only the version string is really checked. CA_eSUN,
  CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY + **NM_NMLETS_OFML, OR_LEDS, TN_TIES which are ALL-PASS and
  counted LIFECYCLE-COMPLETE**. MD and IL are the two fixed so far (2026-08-28 / 08-18) -- MD's CHECK
  2 went from comparing NOTHING to comparing its 14-combo total. Making an empty QUERY PATHS section
  a `[FAIL]` is a `tools/` change that lands 6 red at once: **Rob's direction, not taken.**
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
