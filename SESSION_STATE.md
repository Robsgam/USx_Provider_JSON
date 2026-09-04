# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-09-04 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.12 | ALL-PASS (53 logs) |
| CA_CLETS | v2.27 | ALL-PASS (99 logs) |
| CA_CLETS_OCATS | v2.12 | PARTIAL -- 2 plan test(s) owed (60 captured) |
| CA_eSUN | v3.1 | NEVER-TESTED -- 74 test(s) owed |
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

---

**CA_eSUN v3.1 SHIPPED 2026-09-04 -- the MAINLINE, and it unblocked the whole portfolio.**
v3.0's `purposeCodeDH` FormSelect failed `audit_cross_provider` CHECK 5, which every provider's
enforce reads, so ONE field held all 20 BLOCKED and `report_mission_status` at 0 of 20. eSUN is
RIGHT (its live SDSO v1.0 uses FormSelect -- that dropdown is what DEX-1313 converts to radio);
registered in `tools/config/accepted_field_divergences.json` beside the existing `PurposeCode` row.
Also fixed in v3.1: middle/suffix name controls added (cleared 8 verify_build + all 16 wiring
breaks -- one omission, 24 findings), State labels carry `leave blank for California`, and TWO OF MY
OWN REGISTRY ROWS USED RULE NAMES THE GATES DO NOT READ (`not-built` -> `devdoc-combo-unbuilt`,
`metadata-mandatory-not-in-devdoc` -> `devdoc-optional-unreachable`) so they silenced nothing.
validator 70P/0F/26W -> **78P/0F/2W**; branches held at 27.

**CA_CLETS_OCATS IS PARTIAL, NOT ALL-PASS** -- 60 logs vs a 62-test plan, **2 owed**. This file
claimed "ALL-PASS 5/5 (65 logs)" for three days; CLAUDE.md's table was right and this was the stale
one. Stage 5 also remains: DEX-980 is `Blocked`, release line drafted, awaiting Rob.
**MD_METERS IS LIFECYCLE-COMPLETE at v2.4** -- `POSTED: v2.4 comment 808820` on DEX-987.
**CA_eSUN DEX-1313** -- `POSTED: v2.2 comment 811409` covers the RADIOBUTTON line ONLY; the v3.x
mainline still owes its own release line. eSUN is the first provider with a SUBTASK, so name which
ticket (DEX-1312 parent / DEX-1313 subtask).
? **JIRA REMAINS HELD** -- approval is ONE PROVIDER AT A TIME and never carries.

**The queue** (`report_import_owed.ps1`) -- CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO,
CA_VENTURA_COUNTY, LA_LEMS, all blocked at stage 4 (test). **SDSO LIVE runs eSUN v1.0 against a repo
at v3.1** -- a LIVE bump is a coordinated re-import and Rob's call, never a repo action.
**IMPORT FIRST, THEN PICKLIST CAPTURE** (Rob 2026-08-28) -- the console script scrapes the RENDERED
form, so the capture precedes CHOOSING TEST VALUES; that is why CA_VENTURA cannot fix its hollow toggle.

## OFFICER GUIDES -- 20/20 CURRENT, 473 rows, 0 stale (2026-09-04)

Convention in `usx-build` Step 4c. Rows enumerate devdoc-style; in-state and out-of-state are
SEPARATE rows sharing a message key; the key shown is the METADATA's, not our built one (269 of 381
built keyRefs are invented); in-state rows say "State - leave blank for <the home state>".
`audit_guide_completeness` proves every combination is on a sheet: **381 combos / 92 split / 0
DROPPED**, predicted == actual on all 20. Step 13 runs on EVERY build -- CLAUDE.md wrongly called it
opt-in until 2026-09-04.

## ROB'S CALLS, NOT MINE

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- 4 UNDER / 3 OVER, verbatim in its BUILD_NOTES. Hold the
  SWEEP, not the import.
- **LA_LEMS BoatQuery `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **MINED-KEYREF ATTRIBUTION, 4 EXPOSED** (`_probes/sweep_mined_keyref_shadow.ps1`): CA_eSUN Vehicle
  QV.V->4V and Boat QB.H->4V / QB.R->4B, CA_SAN_LUIS_OBISPO QV.V->4V. A keyRef never reaches the
  wire, so this is ATTRIBUTION (a rename), not a wire change. Both providers never-tested.
- **eSUN 228KB tenant export** in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **194 of 264 registry rows (73%) are unverifiable** by `audit_registry_currency`; 7 providers at
  zero checkable rows, and the first row opened by hand in that zone was FALSE.
- **CA_eSUN v2.2 carries 2 known items, recorded in its BUILD_NOTES, deliberately OFF the ticket**:
  the 7 validator FAILs the 53 captures REFUTE (State sends CA/GA, SexCode sends M), and the
  BirthDate over-permit whose fix would collapse the owner-name search. **No response data will ever
  be forthcoming** (Rob 2026-09-03), so the second is unanswerable from evidence.
- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default. Needs
  TEST_VALUE_OVERRIDES -- choose the value AFTER its picklist capture.
- **5 providers owe the one-time picklist capture** + TX_TLETS_CCH (parked); OCATS captured 5/5 at v2.11.
- **LIMITATION #41** (populated HOME state routes a local plate to NLETS) -- paused pending CommSys.
- **NCIC hit blocks CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI and TN.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02. OH's `ReasonCode`/`Requestor` =
  the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH testing PARKED. DH NOT SUPPORTED FROM CAD.
  TN `RQ01` + name-component casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, and neither does `primaryFieldReference`.** Before calling an
  identity-label difference a defect, ask whether the label ships.
- **4 providers carry `[FLAG:plan-dedupe-vacuous-tests]`** (FL, HI, IL, NJ). CORRECTLY deferred --
  regenerating their plans orphans their logs and drops them out of ALL-PASS. **Not work owed.**
- **Jira is HELD and lifts ONE PROVIDER AT A TIME.** No approval carries to the next provider.

## RULES I BROKE -- READ BEFORE EDITING

- **A REGISTRY ROW ONLY SUPPRESSES IF ITS RULE NAME IS THE ONE THE GATE READS.** I wrote two eSUN
  rows with descriptive names and they silenced nothing for a day. Grep the gate for its literal
  rule string before writing the row, and re-run the gate to confirm the finding actually cleared.
- **VALIDATE EVERY PROBE AGAINST A KNOWN ANSWER.** A finding appearing identically across ~19
  providers is one global cause, not 19 defects. Same week: a sweep reported 2 false ORPHANs against
  tenant-verified HI because I required primaryField equality and HI's variant declares none.
- **NEVER verify a produced file with `Test-Path`** -- a leftover satisfies it. Compare write times.
- **REPLACE this file, never append.** It has failed its own 120-line gate three times.
