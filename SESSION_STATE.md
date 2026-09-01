# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-09-01 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.12 | ALL-PASS (53 logs) |
| CA_CLETS | v2.27 | ALL-PASS (99 logs) |
| CA_CLETS_OCATS | v2.11 | ALL-PASS (65 logs) |
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
| _6 others_ | -- | never tenant-tested: CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

**CA_CLETS_OCATS SWEPT 2026-09-01 -- ALL-PASS 5/5 (65 logs), 4 log gates 65/65, stage 6 recorded.**
**ONLY STAGE 5 REMAINS** -- DEX-980 is `Blocked` with zero comments; release line drafted, awaiting Rob.
**MD_METERS IS LIFECYCLE-COMPLETE at v2.4** -- `POSTED: v2.4 comment 808820` on DEX-987.
⛔ **JIRA REMAINS HELD** -- approval is ONE PROVIDER AT A TIME and never carries.

**The queue** (`report_import_owed.ps1`) -- CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO,
CA_VENTURA_COUNTY, LA_LEMS. All gate-clean, all blocked at stage 4 (test).
**IMPORT FIRST, THEN PICKLIST CAPTURE** (Rob 2026-08-28) -- the console script scrapes the RENDERED
form. The capture precedes CHOOSING TEST VALUES; that is why CA_VENTURA cannot fix its hollow toggle.

**MISSION 13 of 20** (`report_mission_status`; 13 of 19 eligible -- TX_TLETS_CCH is PARKED). OCATS is
NOT counted yet -- lifecycle-complete needs all six stages and its Jira post is owed. The 5 remaining
are blocked at the SAME stage, so the gap is one activity, not five problems.

## ROB'S CALLS, NOT MINE

- **MD_METERS DL State: TAKEN, shipped v2.4, WIRE-PROVEN, POSTED.** `ZLDR.N_any` carries
  `<State>GA</State>` where v2.3 discarded it. I DEVIATED from the option's literal wording
  (`ZLDR.N + RegistrationState EXISTS`) -- it kills the plain in-state name search, and the raw
  metadata confirmed why (`ZLDR{Name}` has State in `<Any>`: an optional, not a fork).
- **CA_CONTRA_COSTA JAWS/SuperQuery** -- the portfolio's only remaining fidelity findings (4 UNDER /
  3 OVER, verbatim in its BUILD_NOTES). Hold the SWEEP, not the import.
- **LA_LEMS BoatQuery `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **eSUN 228KB tenant export** in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **2026-08-28 SWEEP -> section 5. IN-SCOPE ANSWER: ZERO** -- nothing was on the table from the
  unreachable-optional class. My "59 fields / 8 providers" counted combinations we never build (Rob:
  *"you aren't counting non basic supported queries section of metadata"*). What survives is
  structural: **194 of 264 registry rows (73%) are unverifiable** by `audit_registry_currency`, 7
  providers at zero checkable rows -- and the first row opened by hand in that zone was FALSE.
- **DOC-AUTHORITY DEBT CLOSED ON THE FINISHED SET, 2026-08-31.** NM, OR_LEDS and TN_TIES each had an
  empty SQVR scaffold AND a circular `PROVISIONAL` extract while lifecycle-complete; all three now
  carry a verified `CONFIRMED` extract (GATING, not INFO) and a populated SQVR. Each went **45 -> 46
  PASS** (NM 44 -> 45) purely because PHASE 2e became a real gate. Measured after:
  **empty SQVR scaffolds 6 -> 3** (CA_SLO, CA_VENTURA, CA_eSUN -- **all never-tested**, so NO
  lifecycle-complete provider carries one) and **PROVISIONAL extracts 9 -> 6**, of which
  **MD_METERS is the only tenant-verified one left** and MD is held. Docs only: no bump, no re-sweep.
  MD DL State (5e) is now CLOSED -- taken and shipped in v2.4.
- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default. Needs
  TEST_VALUE_OVERRIDES -- choose the value AFTER its picklist capture.
- **5 providers owe the one-time picklist capture** + TX_TLETS_CCH (parked); OCATS captured 5/5 at v2.11.
- **3 providers carry stale ancillary artifacts** (CA_VENTURA, LA_LEMS, TX_TLETS_CCH); clear via
  `build_report -IncludeExtended` at each one's own turn. No wire impact.
- **LIMITATION #41** (populated HOME state routes a local plate to NLETS) -- paused pending CommSys.
  It constrains option 1 of section 5e.
- **NCIC hit blocks CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI and TN. **Officer guides
  content-poor**; rewrite requested, shape not agreed.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02 (44 of the sweep's 59 unreachable
  fields are this). OH's `ReasonCode`/`Requestor` = the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH
  testing PARKED. DH NOT SUPPORTED FROM CAD. TN `RQ01` + name-component casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, and neither does `primaryFieldReference`** (Rob 2026-08-28:
  *"we are building the combos, not attesting to the keyref commsys will use"*). Before calling an
  identity-label difference a defect, ask whether the label ships.
- **4 providers carry `[FLAG:plan-dedupe-vacuous-tests]`** (FL, HI, IL, NJ). CORRECTLY deferred --
  regenerating their plans orphans their logs and drops them out of ALL-PASS. **Not work owed.**
- **Jira is HELD and lifts ONE PROVIDER AT A TIME.** No approval carries to the next provider.

## RULES I BROKE -- READ BEFORE EDITING

- **VALIDATE EVERY PROBE AGAINST A KNOWN ANSWER BEFORE BELIEVING IT. Seven failed today and each one
  first looked like a portfolio finding:** relative paths after the shell cwd moved; resolver param
  (`-ProvDir` not `-Provider`); a document-spanning regex (92 built combos vs a truth of 14); the wire
  element is `<State>` not `<RegistrationState>`; grepping a registry for a literal FIELD name when
  the covering row scopes it `QW | *` (**grep the SCOPE, never the token**); scoping a metadata sweep
  by TRANSACTION not COMBINATION (inflated a finding count from 0 to 59 -- a built transaction still
  holds combinations we never build); and **a KEYREF IS NOT A VARIANT, broken twice in one sweep** --
  matching `ZDRV` by name called MD's unbuilt `DriverLicenseQuery/ZDRV{OLN}` built, because
  `ZDRV.N`/`.O` live under DriverHistoryQuery. Scope keyRef to its transaction, always.
- **Read `ACCEPTED_DIVERGENCES` and the devdoc's `Data-Mined Transactions:` line BEFORE calling a gap
  new.** I re-derived MD's `ZWAR.N`/State and `ZDRV.N`/SexCode rows (both recorded 2026-08-01) and
  published a false finding against FL, which Rob remembered and my probe did not.
- **REPLACE this file, never append.** I took it to 126 lines twice in one session, failing its own
  gate both times. Detail goes in `FINDINGS_REGISTER.md`; this file POINTS.
- **Know whether a tool WRITES before running it as a "check"** -- `block_entity` stamps, commits and
  pushes; `audit_*`/`report_*` read. **Mutate a REPLICA, never the real file** -- `git checkout --`
  restores content but stamps mtime.
