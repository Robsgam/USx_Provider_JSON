# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-09-17 (generated) | **Branch:** `main`

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
| _6 others_ | -- | never tenant-tested: CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, SC_SLED, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

**MISSION** -- headline count deliberately NOT restated: it read "13 of 20" and went stale the moment
SC_SLED became the 21st. **Derive live: `report_mission_status.ps1`.** Owed per that tool 2026-09-14:
**test 5** (CA_CONTRA_COSTA BLOCKED on Rob's JAWS call; CA_SAN_LUIS_OBISPO, CA_VENTURA, LA_LEMS
sweep-ready, CA_VENTURA owes a picklist capture; **SC_SLED sweep HELD on the docs -- but its IMPORT
is wanted, see its section**) and **jira 2** (CA_CLETS_OCATS DEX-980; CA_eSUN DEX-1312/1313 owes a
v3.3 release line). TX_TLETS_CCH is PARKED. **A never-tested provider is owed a SWEEP, not an
import** (Rob 09-09) -- SC_SLED is the EXCEPTION twice over: on no tenant, and now the deploy pilot.
**SDSO LIVE runs eSUN v1.0 vs repo v3.3** -- Rob's call. Handover: `USX_PROJECT_GUIDE.pdf`.
**ANY PRIOR JSON IS ONE COMMAND:** `get_provider_version.ps1 -Provider <P> -Version <X.Y>` -- 671
artifacts, byte-exact. RETRIEVAL, not rebuild: re-running an old script does NOT reproduce it.

## ⭐ SERVE_PLANS AND THE JOB FILES -- CHECK THIS FIRST

**`serve_plans.ps1` MUST RUN DETACHED** (`Start-Process ... -WindowStyle Hidden`; a reboot or a
background task kills it). **VERIFY BY CURLING `/ping /pulljob /job /roster` ON PORT 8477** -- name
and start time both lied 09-14; on 09-15 I curled the WRONG PORT and got the NO-CONNECT I expected.
**Machine pages** -- heavy gates ONE AT A TIME, never piped through `Select-String` (buffers to 0).
**`RUN THE JOB` + `7b` RESCAN are PROVEN, not hypotheses** (09-15: 1790 indexed / 2 new / 4s). ⚠️ **PANEL
COLOURS CHANGED 09-16:** a pull that got NOTHING reads RED, partial AMBER, green only if all accounted.

## SC_SLED v1.8 -- IMPORT IT (proves the deploy path); DO NOT SWEEP IT (Rob 2026-09-16)

⚠️ **IMPORT v1.8. v1.7 IS ON THE TENANT WITH THE WRONG TAB ORDER; v1.6 IS BROKEN, NEVER SEND IT.**
v1.7 measured-installed 09-16 23:08Z (counters 601/4/70 -> 602/5/70, row ids unchanged). Rob read the
strip: *"tab order is still wrong ... put admin at the end like i asked"* -- Admin Message rendered 6th,
Boat 7th. **TAB RULE NOW LIVE-PROVEN:** the order array's DUPLICATE entity entries carry NO information;
forms of one entity render in `configurations[]` order; so **same-entity tabs are always ADJACENT and a
tab is last only if it sits on the LAST entity.** v1.8 moves Admin Message (QIF *and* QIDM -- #26 makes a
split pair fire NOTHING silently) from Article to Boat. ⚠️ **PRICE, 3rd capability given up to place a
tab:** Boat is now 2-QIF, #28 kills its reverse-lookup, so Boat `RegistrationState` is a 2-char TYPE-IN
(any[]-only, not a routing field). Article hosts a 2nd QIF FREE but is not last. Scoped divergence row #3.
⚠️ **SWEEP HOLD NARROWED, NOT LIFTED** -- docs suspect (*"veh reg adn veh stolen seem mixed"*);
`QVRQ`/`QWDQ`/`QBBQ` COMPOUND. 9 QIDMs / 18 combos / **7 QIFs = 7 TABS** / 77P-0F-2W-2LIM / 65 plan tests.
**CO-FIRE IS ROB'S ACCEPTED DESIGN** -- 1 LIM per co-firing entity; 2 WARNs are the Option A trade, NOT
silenced. ONLY provider of 21 with >1 QIF on an entity (`probe_multi_qif_entities.ps1`). ⚠️ **OPEN, NEEDS
ROB:** the AM's 5 `DestinationCode` optionals are UNMAPPED on purpose (5 WARNs standing) -- an AM DELIVERS text to the ORI named there, so a guessed value picks a real SC recipient.

## ROB'S CALLS + OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- 4 UNDER / 3 OVER, in its BUILD_NOTES; hold the SWEEP, not the import. **LA_LEMS `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **194 of 264 registry rows unverifiable** by `audit_registry_currency`; 7 providers at zero checkable rows, and the first row opened by hand there was FALSE.
- **CA_eSUN v2.2: 2 BUILD_NOTES items OFF the ticket** (the 7 validator FAILs the 53 captures REFUTE; the BirthDate over-permit whose fix collapses owner-name search). **+2 from 09-14, Rob's call: 10 radiobutton-experiment ORPHANS, and it is the ONLY 1 of 15 ALL-PASS providers with no `DEX_TICKET_ARCHIVE.md`** despite a POSTED marker.
- **LIMITATION #41** (HOME state routes a local plate to NLETS) -- paused pending CommSys; 5 providers owe a picklist capture. **CA_VENTURA hollow toggle** needs a TEST_VALUE_OVERRIDE after its capture. Portfolio 2026-09-14: **21/21 ENFORCED 741P/0F/0W**; the only 4 UNDER / 4 OVER are CA_CONTRA_COSTA, Rob's JAWS call.

## THE DEPLOY LOOP IS BUILT AND PROVEN -- and ALL TENANT WORK IS HELD (Rob 2026-09-14)

**RECOVERY RECORD: `providers\HELD_TENANT_WORK.md` -- READ IT BEFORE RESUMING.** Nothing is
half-applied; the only outstanding action is ONE operator click. `newarkpd-foundation` (68055618928)
runs NJ_NJCJIS v4.16 while ledger AND catalog say v4.17, proven five ways -- and per Rob it stays
MANUAL. Loop: `emit_import_job.ps1` -> review `IMPORT_JOB.json` -> panel **RUN THE JOB FOR THIS
TENANT** -> auto re-export -> `watch_imports.ps1` -> `verify_tenant_import`. `deploy_probe.js` is
the ONLY writer; dry-run default; 46 mutation cases. ⚠️ **GUI only, never a console command.** ⚠️ An
import **REPLACES** the bundle set. ⚠️ Still unexplained and worth more than the import: **WHY the
2026-08-20 Newark import did not land.** Held (Rob's): scoping, the batch, Confluence.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02. OH's `ReasonCode`/`Requestor` =
  the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH PARKED. DH NOT FROM CAD. TN `RQ01` + name-casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, nor does `primaryFieldReference`** -- ask whether the label
  ships. **`[FLAG:plan-dedupe-vacuous-tests]` DONE**; inflation 2026-09-14: 927 logs / 0 findings.
- **NY DEMOTED-QUALIFIER: CLOSED, not owed** ([KILLED] 2026-09-09; two fixes REJECTED, see
  `FINDINGS_REGISTER.md`). **NJ guardrail mutation: N/A, not stale** -- do NOT re-aim. Both were
  stale-OWED claims IN THIS FILE that invented work -- **measure before believing this file.**
- **Jira is HELD and lifts ONE PROVIDER AT A TIME.** No approval carries to the next provider.
- **`hawaii-dle` LIVE on v4.15 vs repo v4.20 = DECISION, NOT A GAP** (Rob 09-15: *"hawaii will sit at
  that version until we meet with them again"*) -- reports will keep flagging it; that is correct
  signal. **NEWARK STAYS MANUAL FOREVER**. Dallas ledger row CLOSED 09-15 (content-proven v4.22).

## RULES I BROKE -- READ BEFORE EDITING

- Durable rules live in `usx-tooling` (6 / 8a): **a registry row suppresses only if its rule name is
  the string the gate greps**; **validate every probe against a known answer WITH negative
  controls**. **A `#`-COMMENTED LINE IS NOT A FINDING.** **NEVER verify a produced file with
  `Test-Path`** -- compare write times, and do not trust a tool's own success line either
  (09-14: `extract_metadata_reference` printed a summary and wrote nothing without `-OutFile`).
- **A SAME-LOOKING STRUCTURE ELSEWHERE IS A QUESTION, NEVER A PRECEDENT** -- read that provider's
  OWN `<Requirements>`. **A STANDING RULE IS NOT EVIDENCE**: 09-14 the rule prescribing
  `autoSelect=false` for VehStolen had ZERO tenant-proven carriers. **AN EXPLANATION IS NOT A
  MEASUREMENT** and **A GATE THAT MEASURED NOTHING IS NOT A PASS**. **A RULE ABOUT ONE PROCESS IS A
  RULE ABOUT THE QUERY** -- the documented `watch_captures` self-match trap bit me on `serve_plans`
  and I killed a phantom. **MY OWN STATE ROWS GO STALE WITHIN HOURS** -- re-read before citing.
