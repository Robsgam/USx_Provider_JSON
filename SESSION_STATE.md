# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-09-18 (generated) | **Branch:** `main`

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
| NY_NYSPIN_EJUSTICE | v4.27 | NEVER-TESTED -- 65 test(s) owed |
| OH_LEADS | v2.11 | ALL-PASS (65 logs) |
| OR_LEDS | v2.6 | ALL-PASS (27 logs) |
| SC_SLED | v1.18 | NEVER-TESTED -- 30 test(s) owed |
| TN_TIES | v2.6 | ALL-PASS (67 logs) |
| TX_TLETS | v4.23 | NEVER-TESTED -- 101 test(s) owed |
| _5 others_ | -- | never tenant-tested: CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

**MISSION** -- headline count deliberately NOT restated (it read "13 of 20" and went stale the moment
SC_SLED became the 21st). Owed per `report_mission_status` 09-14: **test 5** (CA_CONTRA_COSTA BLOCKED
on Rob's JAWS call; CA_SAN_LUIS_OBISPO / CA_VENTURA / LA_LEMS sweep-ready, CA_VENTURA owes a picklist
capture) and **jira 2** (CA_CLETS_OCATS DEX-980; CA_eSUN v3.3 release line). TX_TLETS_CCH PARKED.
**A never-tested provider is owed a SWEEP, not an import** (Rob 09-09). **SDSO LIVE runs eSUN v1.0 vs
repo v3.3** -- Rob's call. Handover: `USX_PROJECT_GUIDE.pdf`. **ANY PRIOR JSON IS ONE COMMAND:**
`get_provider_version.ps1 -Provider <P> -Version <X.Y>` -- RETRIEVAL, not rebuild.

## ⭐ SERVE_PLANS AND THE JOB FILES -- CHECK THIS FIRST

**`serve_plans.ps1` MUST RUN DETACHED** (`-WindowStyle Hidden`; a reboot kills it). **VERIFY BY
CURLING `/ping /pulljob /job /roster` ON PORT 8477** -- name and start time both lied 09-14, and on
09-15 I curled the WRONG PORT and got the NO-CONNECT I expected. **Machine pages:** heavy gates ONE
AT A TIME, never piped through `Select-String` (buffers to 0). **`RUN THE JOB` + `7b` RESCAN are
PROVEN.** ⚠️ Panel colours: a pull that got NOTHING reads RED, partial AMBER.

## SC_SLED v1.11 -- ACTIVE WORK. SWEEP IN FLIGHT: 10 of 65 logged, 55 OWED

`report_sweep_ledger` 09-18: Vehicle 3/10, Person 6/9, Firearm 0/39, Article 1/1, Boat 0/6 -- the
authority over any capture's "all entries captured" line. ⚠️ **Its 39 Firearm FOLDS IN the 34 Wanted
Person tests** (this section read "Firearm 0/5 + Wanted Person 0/34"). SC_SLED is the ONLY provider
with >1 QIF on one entity, so entity-bucketing is exactly where a per-entity lookup misattributes --
UNRESOLVED, do not quote the split as fact. ✅ **STALE GUARDRAIL LOG ARCHIVED** to
`logs/Person/_archive_stale_plan_reemit/` and `enforce -Provider SC_SLED` is CLEAN; cause was a
MID-SWEEP plan re-emit, which does NOT archive logs the way a version bump does. Re-capture owed.
⚠️ **14 captures sit UNINGESTED in Downloads** as `usx_captured_*.unmatched.json` (09-17): 12 Vehicle
(`QVRQ.V`x4 `QVRQ.P`x2 `QV.P`x4 +2 unresolved), 1 AdminMsg, 1 DriverRegistration -- NONE in any
committed log (by transactionId). NEEDS ROB: relabel+ingest, or discard and re-drive?
🔻 **PICKLISTS 9/14 captured 09-18; OWED: the `Wanted Person` TAB (5).** Scope+driver+`test_phase2 [2b]`
now bucket by TAB -- re-scope from that tab (needs driver **BUILD 2026-09-18a**). Boat/AdminMsg own NO
dropdowns; nothing owed there.
✅ **WANTED PERSON IS NOW A SELECTABLE TAB** (09-17, Rob asked twice; plans carry `tab`/`qif`) --
needs extension **BUILD 2026-09-17e**. ⚠️ **NEEDS ROB:** the AM's 5 `DestinationCode` optionals are
UNMAPPED and an AM DELIVERS to the ORI named. ⚠️ **POPULATED ≠ PROVEN WIRE VALUE** -- the State `Sel`
renders (keep it) but "sends a 2-letter code" is UNCITED; one read-only GET settles it, no import
(#38: VEHICLE_MAKE populates and still ships `CNST_FORD`). ⚠️ **CONFIRM WHAT THE TENANT CARRIES
BEFORE SWEEPING** -- usx-sc-sled last knowingly held the MULTILINE PROBE.
🟢 **MULTILINE CLOSED**: `FormTextarea` (lowercase `a`) renders AND transmits -- `CAPABILITY #48`,
adopted here for **wrap-and-scroll, never line breaks**. ⚠️⚠️ **STILL OWED AS A PRODUCT ASK and it is
the real finding: ENTER SENDS A HALF-WRITTEN AM** to the addressed ORI (Shift+Enter too; standard
HTML, so every `FormInput` has it). Raise that, not box height.

## ROB'S CALLS + OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **CA_CONTRA_COSTA JAWS** 4 UNDER / 3 OVER -- hold the SWEEP, not the import. **LA_LEMS `QB{reg}`/`BQ{reg}`** not taken. **CA_eSUN**: 2 BUILD_NOTES items off-ticket, 10 radiobutton ORPHANS, no `DEX_TICKET_ARCHIVE.md` despite a POSTED marker.
- **194 of 264 registry rows unverifiable** by `audit_registry_currency` (7 providers at zero checkable rows; the first opened by hand was FALSE). **LIMITATION #41** paused pending CommSys; 5 providers owe a picklist capture, CA_VENTURA also a TEST_VALUE_OVERRIDE.
- **TX_TLETS** manual reviewed in full 09-17 (`docs/reference/TX_TLETS_TLETS_MANUAL_NOTES.txt`). Owed to CommSys, DOC fixes only: the devdoc FRT bracket on combo #1, and the `RSDWW` MessageKey description.

## DEPLOY LOOP PROVEN -- ALL OTHER TENANT WORK HELD (Rob 2026-09-14)

**RECOVERY RECORD: `providers\HELD_TENANT_WORK.md` -- READ BEFORE RESUMING.** Nothing half-applied;
one operator click outstanding; mechanics in the `usx-deploy` skill. ⚠️ **GUI only**, and an import
**REPLACES** the bundle set. Still unexplained and worth more than the import: **WHY the 08-20 Newark
import did not land.** Also held (Rob's): scoping, the batch, Confluence.

## DO NOT RE-RAISE

`State2`-`State5` broadcast OUT OF SCOPE 08-02 (the TLETS manual's 5-inquiry max EXPLAINS those
fields, it does not reopen them). OH `ReasonCode`/`Requestor` = BMVIMS. CommSys asks HELD.
TX_TLETS_CCH PARKED. DH NOT FROM CAD. TN `RQ01` CLOSED. NY demoted-qualifier [KILLED] 09-09.
NJ guardrail mutation N/A not stale. `[FLAG:plan-dedupe-vacuous-tests]` DONE. **A keyRef NEVER
reaches the wire, nor does `primaryFieldReference`.** Jira HELD, lifts ONE PROVIDER AT A TIME.
`hawaii-dle` v4.15 vs repo v4.20 and `newarkpd-foundation` MANUAL are **DECISIONS, NOT GAPS**.
⚠️ Several of the above were once stale-OWED claims IN THIS FILE that invented work --
**measure before believing this file.**

## RULES I BROKE -- READ BEFORE EDITING

Durable set lives in `usx-tooling` (6 / 8a). Shortlist: **a registry row suppresses only if its rule
name is the string the gate greps**; **validate every probe against a known answer WITH negative
controls**; **a `#`-COMMENTED LINE IS NOT A FINDING**; **never verify a produced file with
`Test-Path`**; **REUSE THE PARSER**; **never route PowerShell content edits through bash** (mangled
backticks once commented out a live control). **A SAME-LOOKING STRUCTURE IS A QUESTION, NEVER A
PRECEDENT**; **A STANDING RULE IS NOT EVIDENCE**; **AN EXPLANATION IS NOT A MEASUREMENT**; **A GATE
THAT MEASURED NOTHING IS NOT A PASS**; **A CENSUS BOUNDS CURRENT USE, NOT THE PLATFORM** (#48);
**REACHABLE IS NOT FINDABLE** (Wanted Person ran for weeks while invisible, and I called it fixed
once already); **MY OWN STATE ROWS GO STALE WITHIN HOURS.**
⚠️ **`report_mission_status.ps1` IS NOT READ-ONLY** (09-17): it runs `enforce -Provider <P>` per
provider, auto-enabling reproducibility, which REWRITES reports/guides/manifests. **STILL NOT FIXED**
-- but the 7-ahead-of-14 manifest split it left is GONE: a full `enforce` on 09-18 regenerated all
21 (160 files, 240+/240-, and a filtered diff proved ZERO non-timestamp/fingerprint lines changed).
