# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-27 (generated) | **Branch:** `main`

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
| TX_TLETS | v4.22 | NEVER-TESTED -- 98 test(s) owed |
| _8 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**IMPORT + SWEEP. The build queue is EMPTY.** 7 providers are NEVER-TESTED and every one is
build/spec/reachability-complete -- nothing further can be BUILT to move the number. Queue authority
is `report_import_owed.ps1`, never this file. Smallest first: LA_LEMS, MD_METERS, CA_SLO.
**OR_LEDS is ONE APPROVAL from complete** -- 5 of 6 stages done, only the Jira post outstanding.

**MISSION: 11 of 20 = 55%** (`report_mission_status.ps1`; target 19/20). 7 blocked at test, 1 at jira.
**MEASURED 2026-08-27:** reachability 20/20 all combos reachable - combo coverage 100% on all 12
tenant-verified providers - fidelity 420 branches / 4 UNDER / 4 OVER, all CA_CONTRA_COSTA.

## AWAITING ROB -- DRAFTED, NOT POSTED

- **OR_LEDS v2.6 -> DEX-992.** Ticket located by JQL 2026-08-27 (it was recorded NOWHERE before);
  Backlog, ZERO comments, so the release line is an **initial post**, not a supersede. Comment is
  drafted; NOT posted. Jira is HELD (2026-07-31) and lifts ONE PROVIDER AT A TIME -- Rob approved
  NM on 08-27 and that does NOT carry. STAGE 5 GAP on OR is CORRECT: absence of a post, not a
  missing record of one.

## OPEN DECISIONS THAT ARE ROB'S, NOT MINE

- **CA_CONTRA_COSTA JAWS / SuperQuery ruling** -- pending; v2.4 deliberately did not pre-empt it. Its
  4 UNDER / 3 OVER are the portfolio's ONLY remaining fidelity findings, listed verbatim in its
  BUILD_NOTES and untouched: CA_CLETS and Ventura require OPPOSITE things there. Blocks a 92-test sweep.
- **LA_LEMS BoatQuery: build `QB{reg}` instead of `BQ{reg}`?** Devdoc makes `Attention` MANDATORY and
  State optional; metadata splits them across two ROUTING-INDISTINGUISHABLE variants, so only one can
  be built. Swapping would transmit the mandatory field and lose only an optional one -- strictly
  better conformance. Recorded in LA's registry, NOT taken: LA is under the CommSys hold.
- **eSUN 228KB tenant export in pushed history** at `8273a87f` -- removing it needs a rewrite + force-push.

## OPEN FINDINGS -- confirmed, unfixed

- **PAUSED PENDING COMMSYS -- LIMITATION #41:** a populated HOME state routes a local plate to NLETS.
  Our config is provably clean; evidence in `PLATFORM_CONSTRAINTS.txt` #41. Read before any State work.
- **NCIC hit blocks are CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI *and* TN. Make "does a mined
  hit render?" a stated sweep objective. NOT a request-side question -- a sweep cannot settle it.
- **Officer guides are content-poor, not stale.** Rewrite requested; shape not agreed.
- **7 live flags, all one id: `[FLAG:plan-dedupe-vacuous-tests]`** (CA_SLO and MD retired theirs at
  their 08-27 rebuilds). Each clears at its OWN next rebuild; not new work. Derive from
  `audit_reverse_propagation.ps1`, never from memory.
- **`audit_devdoc_optionals` MANDATORY-NOT-TRANSMITTED (new 08-27): 1 finding left, CA_CONTRA_COSTA.**
  12 of 13 closed. It is blocked behind the JAWS ruling above.
- **CLAUDE.md is STALE in 3 spots**: "Entity Display Order" default still says Person-first (20 of 20
  are Vehicle-first); TEST_VALUE_OVERRIDES entity-scoped keys are called "preferred" but
  `_combo_value_resolver.ps1` does NOT implement them (a `Entity.fieldId` line matches NOTHING while
  the tool still reports it loaded); the `audit_layout_flow` 139 baseline.

## ON HOLD / DO NOT RE-RAISE

- **`State2`-`State5` MULTI-STATE NLETS BROADCAST -- PARKED UNTIL ROB BRINGS IT UP.** Ruled OUT OF
  SCOPE 2026-08-02. The pre-sweep flow reads the spec plan's UNREACHABLE findings without cross-checking
  the registry, so it WILL keep looking new. NM's 24 UNREACHABLE spec tests are this; expected output.
- **COMMSYS ASKS ARE ON HOLD.** LA's devdoc PurposeCode/State inversion is recorded, NOT owed.
- **TN `RQ01`** and **name-component casing (Pascal 11 / camel 9)** -- both CLOSED 08-24, mis-recorded
  as open risks once already. Do not re-open. A keyRef NEVER reaches the wire.
- **TX_TLETS_CCH testing PARKED.** **DH IS NOT SUPPORTED FROM CAD.** **LIMITATION #40: the wire is a
  UNION across every MATCHING combination** (LIVE-PROVEN 38/38).
- **Plate type/year prefills: KEEP where optional AND nothing routes on them** (Rob 08-27). Where
  routing DOES depend on them the OOS-only exception applies -- un-prefill BOTH (HI v3.0 shape).

## RULES I BROKE TODAY -- READ BEFORE EDITING ANYTHING

- **NEVER nest one shell's quoting inside another's.** A PowerShell here-string inside a bash heredoc
  let bash eat every literal "n" in a build script (`function` -> `fu<NL>ctio<NL>`). Restored with
  `git checkout` and verified by `audit_reproducible`, NOT by eye. Use the Edit tool for multi-line.
- **An edit anchored INSIDE a block leaves its opening orphaned.** Cost a build failure whose reported
  line was 20 lines PAST the damage -- the parser reports where it gave up, not where you broke it.
- **A stale artifact in a scratchpad looks exactly like a fresh one.** I read a 14-day-old enforce
  report and nearly reported `625 PASS / 22 FAIL` as current. Check the timestamp.
- **Verify a tool's success line against the artifact.** "2 overrides loaded" was true while the
  overrides matched nothing (wrong key namespace). Read the emitted plan, not the console.
- **`audit_combo_reachability`'s "N checked" is NOT a combo count.** Use `audit_test_coverage`.
