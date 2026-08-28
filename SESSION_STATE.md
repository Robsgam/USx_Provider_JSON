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

**IMPORT + SWEEP. The build queue is EMPTY and all 7 never-tested providers are GATE-CLEAN.**
Queue authority is `report_import_owed.ps1`, never this file. **MD_METERS v2.3 is teed up** --
PHASE 1 green (8/8 fuzz caught), enforce 45P/0F/0W, pre-flight CLEAR, 46 tests / 0 hollow toggles.
Run its ONE-TIME PICKLIST CAPTURE FIRST (`logs\MD_METERS_PICKLIST_SCOPE.console.js` in the tenant):
OR_LEDS picked a valid plate-type value that way, and CA_VENTURA cannot fix its hollow toggle
without one. Then: import -> capture picklists -> drive the plan -> watcher ingests.

**MISSION: 12 of 20 = 60%** (`report_mission_status.ps1`; target 19/20). ALL 7 remaining are
blocked at the SAME stage -- tenant test. 0 blocked at jira, build, spec or reachability.
**Nothing further can be BUILT to move the number.**

## DONE 2026-08-27/28 -- do not redo

- **TX_TLETS v4.22 LIFECYCLE-COMPLETE.** In-state plate path `{LicensePlateNumber, State}` restored
  (State promoted to `set[]` so it is GATED and cannot shadow the more specific plate paths).
  From v4.17-v4.21 plate+State matched NO combo and sent nothing. Wire-proven: 98/98 ALL-PASS,
  the QV wire carries LicensePlateNumber + State and NOTHING else. DEX-967 comment **807576**.
  CCH v1.18 in lockstep. **It did NOT move the mission number** -- TX was already complete at
  v4.21; a rebuild of a complete provider only holds the line.
- **OR_LEDS v2.6 LIFECYCLE-COMPLETE** -- DEX-992 comment **807713**, the FIRST comment that ticket
  has ever carried. No history anchor, deliberately (v2.5 and earlier were never installed).
  **This one DID move the number, 11 -> 12.**
- **LA_LEMS + CA_VENTURA_COUNTY**: dedupe flag retired, plans regenerated (32->31, 97->95, exactly
  as predicted). No version bump, no logs orphaned.
- **block_entity**: single-optional combos accept their `_af_<field>` log as any[] evidence. The
  gate and the plan generator were MUTUALLY UNSATISFIABLE; 72 more combos across 19 providers
  would each have hit it at their own next rebuild.
- **audit_name_components class C4 POOL-INCONSISTENT (BLOCKING)** + `audit_name_components` ADDED
  TO THE FUZZ PANEL. Two gaps: the gate could not see a name component dropped from ONE
  combination's any[], and the fuzzer could not have told us either way. Clean 20 providers /
  216 components / C4 compared 68 / 0 violations; mutant FAILs naming the combo.

## OPEN DECISIONS THAT ARE ROB'S, NOT MINE

- **CA_CONTRA_COSTA JAWS / SuperQuery ruling** -- pending. Its 4 UNDER / 3 OVER are the portfolio's
  ONLY remaining fidelity findings, listed verbatim in its BUILD_NOTES. Blocks a 92-test sweep.
  It is gate-clean and importable; hold the SWEEP, not the import.
- **LA_LEMS BoatQuery: build `QB{reg}` instead of `BQ{reg}`?** Recorded in LA's registry, NOT taken.
- **eSUN 228KB tenant export in pushed history** at `8273a87f` -- removing it needs a force-push.

## OPEN FINDINGS -- confirmed, unfixed

- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to `PC`, the value the form already
  defaults to, so that test proves nothing. Needs a TEST_VALUE_OVERRIDES entry -- but pick the value
  AFTER its picklist capture, or you will choose one the tenant does not offer.
- **4 providers still carry `[FLAG:plan-dedupe-vacuous-tests]`** -- FL_FCIC, HI_HCJDC_OFML,
  IL_LEADS_OFML, NJ_NJCJIS. All ALL-PASS, so the flags are CORRECTLY deferred: regenerating a plan
  orphans that provider's logs and drops it out of ALL-PASS. Each clears at its OWN next rebuild.
  **NOT work owed.**
- **PAUSED PENDING COMMSYS -- LIMITATION #41:** a populated HOME state routes a local plate to NLETS.
- **NCIC hit blocks are CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI *and* TN.
- **Officer guides are content-poor, not stale.** Rewrite requested; shape not agreed.
- **10 providers owe the one-time tenant picklist capture** (`audit_picklist_scope -All`).

## ON HOLD / DO NOT RE-RAISE

- **`State2`-`State5` MULTI-STATE NLETS BROADCAST -- PARKED.** Ruled OUT OF SCOPE 2026-08-02.
  NM's 24 UNREACHABLE spec tests are this; expected output.
- **COMMSYS ASKS ARE ON HOLD.** **TX_TLETS_CCH testing PARKED.** **DH IS NOT SUPPORTED FROM CAD.**
- **TN `RQ01`** and **name-component casing** -- CLOSED 08-24. A keyRef NEVER reaches the wire.
- **Jira is HELD** and lifts ONE PROVIDER AT A TIME. TX and OR were each approved separately on
  their own day; neither approval carries. DRAFT AND WAIT, every provider, every time.
- **The TX and OR comments each carry a closing line naming the catalog/Foundation tenant** -- a
  DELIBERATE OVERRIDE of the template's "NO TENANT DETAIL ANYWHERE" rule, directed by Rob both
  times and recorded as such. Do NOT "correct" those posted comments, and do NOT repeat it unasked.

## RULES I BROKE THIS SESSION -- READ BEFORE EDITING ANYTHING

- **KNOW WHETHER A TOOL WRITES BEFORE RUNNING IT AS A "CHECK".** I ran `block_entity` across five
  providers to "verify" a change; it STAMPS, COMMITS AND PUSHES. Six commits flipped NY/NJ/TN from
  open to blocked. Reverted. `audit_*` reads; `block_entity` / `post_test` / `reset_test_package`
  WRITE. The verification was never needed -- the change was strictly widening and provable by
  reading it.
- **MUTATE A REPLICA, NEVER THE REAL PROVIDER FILE.** `git checkout --` restores CONTENT but stamps
  MTIME TO NOW, so MD's JSON became newer than its own artifacts and enforce went 0 FAIL -> 3 FAIL,
  none of it MD's fault. The fuzz harness already builds a replica (with `source/` copied in so the
  metadata XML resolves) -- use that shape.
- **A PROBE THAT MATCHES ITS OWN COMMAND LINE LIES.** Twice: a watcher scan that matched the scan,
  and a combo enumeration that swept in `AUTH` and entity names. Both produced confident wrong
  numbers until checked.
- **CHECK ACCEPTED_DIVERGENCES BEFORE DIAGNOSING A REPORTED GAP AS NEW.** TX's plate+State symptom,
  its root cause AND its fix were recorded on 2026-07-30. I re-derived all of it.
- **SQVR PROSE NEVER EXPIRES ON ITS OWN.** `reset_test_package` rewrites STATUS MARKERS, not
  narrative. I removed a stale v4.12 block and immediately wrote a fresh stale one.
