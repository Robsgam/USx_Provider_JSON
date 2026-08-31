# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-31 (generated) | **Branch:** `main`

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

**MD_METERS v2.3 is SWEPT and waiting on TWO decisions from Rob, both recorded, neither taken.**
ALL-PASS 46/46, four log gates 46/46, `enforce -Provider MD_METERS` 43P/0F/0W, ledger records the
install, SQVR populated, picklists captured.
1. **Jira** -- a v2.3 release line is DRAFTED in `providers/MD_METERS/docs/tracking/DEX_TICKET.md`
   and NOT posted. DEX-987 (found by JQL; was recorded nowhere in the repo) has zero comments.
2. **DriverLicenseQuery State** -- three options in `FINDINGS_REGISTER.md` **section 5e**. Any of them
   is v2.4 and archives the 46-log package.

**THEN: import + sweep the next of 6** (`report_import_owed.ps1`) -- CA_CLETS_OCATS, CA_CONTRA_COSTA,
CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS. All gate-clean, all blocked at stage 4.
**IMPORT FIRST, THEN PICKLIST CAPTURE** (Rob 2026-08-28) -- the console script scrapes the RENDERED
form. The capture precedes CHOOSING TEST VALUES; that is why CA_VENTURA cannot fix its hollow toggle.

**MISSION 12 of 20**: 6 blocked at test, 1 (MD) at jira.

## ROB'S CALLS, NOT MINE

- **MD_METERS DL State** -- section 5e, three options, all v2.4 (archives 46 logs).
  **FL_FCIC owes NOTHING** -- I reported `ExpandedNameSearchCode` as an unrecorded gap and RETRACTED it;
  Rob: *"for fl i thought we parked that."* See 5b.
- **CA_CONTRA_COSTA JAWS/SuperQuery** -- the portfolio's only remaining fidelity findings (4 UNDER /
  3 OVER, verbatim in its BUILD_NOTES). Hold the SWEEP, not the import.
- **LA_LEMS BoatQuery `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **eSUN 228KB tenant export** in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **2026-08-28 SWEEP -> section 5. THE IN-SCOPE ANSWER IS ZERO -- nothing was on the table from the
  unreachable-optional class.** My "59 unreachable fields / 8 providers" counted fields on
  combinations we never build; Rob: *"you aren't counting non basic supported queries section of
  metadata."* Re-scoped per COMBINATION: 22 sit on keyRefs we do not build (out of scope), 37 on
  built combos and every one is `State2`-`State5` (out of scope) or NM's registered
  `FormORI`/`RelatedHitSearchIndicator`. MD's row was still worth adding but was NOT "the one
  unrecorded item". What survives is structural: **193 of 263 registry rows (73%) are unverifiable** by
  `audit_registry_currency` (7 providers have zero checkable rows) -- and the first row opened by hand
  in that zone was FALSE. **8 of 20 `SUPPORTED_QUERIES` extracts PROVISIONAL; 5 carry an empty SQVR
  scaffold its gate passes** -- OR / TN in both AND lifecycle-complete. **NM closed both 08-31**
  (extract verified vs devdoc -> `CONFIRMED`/GATING, SQVR 13 markers; enforce 44 -> **45 PASS** as
  PHASE 2e became a real gate). Still OPEN and Rob's: MD DL State (5e).
- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default. Needs
  TEST_VALUE_OVERRIDES -- choose the value AFTER its picklist capture.
- **6 providers owe the one-time picklist capture** + TX_TLETS_CCH (parked).
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
