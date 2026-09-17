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
SC_SLED became the 21st. **Derive live: `report_mission_status.ps1`.** Owed per that tool 09-14:
**test 5** (CA_CONTRA_COSTA BLOCKED on Rob's JAWS call; CA_SAN_LUIS_OBISPO, CA_VENTURA, LA_LEMS
sweep-ready, CA_VENTURA owes a picklist capture; SC_SLED sweep HELD, its IMPORT wanted) and **jira
2** (CA_CLETS_OCATS DEX-980; CA_eSUN DEX-1312/1313 owes a v3.3 release line). TX_TLETS_CCH PARKED.
**A never-tested provider is owed a SWEEP, not an import** (Rob 09-09) -- SC_SLED is the EXCEPTION
twice over. **SDSO LIVE runs eSUN v1.0 vs repo v3.3** -- Rob's call. Handover: `USX_PROJECT_GUIDE.pdf`.
**ANY PRIOR JSON IS ONE COMMAND:** `get_provider_version.ps1 -Provider <P> -Version <X.Y>` -- 671
artifacts, byte-exact. RETRIEVAL, not rebuild: re-running an old script does NOT reproduce it.

## ⭐ SERVE_PLANS AND THE JOB FILES -- CHECK THIS FIRST

**`serve_plans.ps1` MUST RUN DETACHED** (`-WindowStyle Hidden`; a reboot kills it). **VERIFY BY
CURLING `/ping /pulljob /job /roster` ON PORT 8477** -- name and start time both lied 09-14; on
09-15 I curled the WRONG PORT and got the NO-CONNECT I expected. **Machine pages:** heavy gates ONE
AT A TIME, never piped through `Select-String` (buffers to 0). **`RUN THE JOB` + `7b` RESCAN are
PROVEN.** ⚠️ **PANEL COLOURS 09-16:** a pull that got NOTHING reads RED, partial AMBER.

## SC_SLED v1.10 -- IMPORT IT; DO NOT SWEEP IT (Rob 2026-09-16)

✅ v1.9 tab order + layout CONFIRMED on the tenant. v1.10 = **77P/0F/0W/2LIM**. The #28 /
Sex+Race-dropdown adjudication and the `validate.ps1` fix are CLOSED -- reasoning in the v1.10
commit body. ⚠️ **OPEN, NEEDS ROB:** the AM's 5 `DestinationCode` optionals are UNMAPPED -- an AM
DELIVERS to the ORI named. ✅ **STATE DROPDOWN READ 09-17, POPULATED** -- `NJ_NIBRS_STATE|NJ_NIBRS`
resolves off-NJ; keep the `Sel`. ⚠️ **POPULATED ≠ PROVEN WIRE VALUE** (#38: VEHICLE_MAKE populates
and ships `CNST_FORD`) and the KB's "sends 2-letter code" was UNCITED -- open, settles with one
read-only GET, no import (see `FIELD_REFERENCE` NJ_NIBRS_STATE row). ⚠️ **usx-sc-sled CARRIES THE
MULTILINE PROBE, NOT v1.10**, so **v1.10 must go back**.

## 🟢 THE MULTILINE BOX EXISTS -- `FormTextarea`, LOWERCASE `a` (measured 2026-09-17)

**`CAPABILITY #48`; the slot held a FALSE LIMITATION for six hours** (3 of its 4 sources were USAGE
CENSUSES -- same lesson as `#44`). `FormTextArea` with a capital A does NOTHING: EXACT-MATCH
resolver, and the validator's duplicate-tag refusal is the only reason both casings got tested. All
5 candidate PROPS dead; `Text` does NOT render (no help-text channel); all 7 tabs rendered, so **an
unknown `resolvedName` is IGNORED, not FATAL**.

✅ **ROUND 2: IT TRANSMITS (3/3) AND NEWLINES DIE BEFORE THE WIRE** -- FORM STATE already holds **0
LF / 247 spaces** (each Enter -> ~124 spaces), so it is the CONTROL layer, not the serializer.
**ENTER SUBMITS THE QUERY.** **Wire values are UPPERCASED and a no-rule `FormInput` did it too,
CORRECTING `#44`'s handler attribution.** Evidence in `docs/evidence/2026-09-17_MULTILINE_*`.
⚠️ **VERDICT: adopt for WRAP-AND-SCROLL, never line breaks** -- 3 words cost 262 of the 501-char
`FreeText` budget, arriving as one gappy line. **OPEN:** Shift+Enter or paste-only? `maxLength`?

## ROB'S CALLS + OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- 4 UNDER / 3 OVER, in its BUILD_NOTES; hold the SWEEP, not the import. **LA_LEMS `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **194 of 264 registry rows unverifiable** by `audit_registry_currency`; 7 providers at zero checkable rows, and the first row opened by hand there was FALSE.
- **CA_eSUN v2.2: 2 BUILD_NOTES items OFF the ticket** (the 7 validator FAILs the 53 captures REFUTE; the BirthDate over-permit whose fix collapses owner-name search). **+2 from 09-14, Rob's call: 10 radiobutton-experiment ORPHANS, and it is the ONLY 1 of 15 ALL-PASS providers with no `DEX_TICKET_ARCHIVE.md`** despite a POSTED marker.
- **LIMITATION #41** (HOME state routes a local plate to NLETS) -- paused pending CommSys; 5 providers owe a picklist capture. **CA_VENTURA hollow toggle** needs a TEST_VALUE_OVERRIDE after its capture. Portfolio 2026-09-14: **21/21 ENFORCED 741P/0F/0W**; the only 4 UNDER / 4 OVER are CA_CONTRA_COSTA, Rob's JAWS call.

## DEPLOY LOOP BUILT + PROVEN -- ALL OTHER TENANT WORK HELD (Rob 2026-09-14)

**RECOVERY RECORD: `providers\HELD_TENANT_WORK.md` -- READ BEFORE RESUMING.** Nothing half-applied;
one operator click outstanding. Mechanics live in the `usx-deploy` skill. ⚠️ **GUI only** and an
import **REPLACES** the bundle set. `newarkpd-foundation` runs NJ v4.16 vs ledger v4.17 and stays
MANUAL (Rob). Still unexplained, worth more than the import: **WHY the 08-20 Newark import did not
land.** Held (Rob's): scoping, the batch, Confluence.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02. OH's `ReasonCode`/`Requestor` =
  the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH PARKED. DH NOT FROM CAD. TN `RQ01` + name-casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, nor does `primaryFieldReference`** -- ask whether the label
  ships. **`[FLAG:plan-dedupe-vacuous-tests]` DONE**; inflation 2026-09-14: 927 logs / 0 findings.
- **NY DEMOTED-QUALIFIER CLOSED** ([KILLED] 09-09, 2 fixes REJECTED); **NJ guardrail mutation N/A,
  not stale**. Both were stale-OWED claims IN THIS FILE that invented work -- **measure before
  believing this file.** **Jira is HELD, lifts ONE PROVIDER AT A TIME**; no approval carries over.
- **`hawaii-dle` LIVE on v4.15 vs repo v4.20 = DECISION, NOT A GAP** (Rob 09-15) -- reports will keep
  flagging it; correct signal. **NEWARK STAYS MANUAL FOREVER.** Dallas ledger row CLOSED 09-15.

## RULES I BROKE -- READ BEFORE EDITING

- Durable rules live in `usx-tooling` (6 / 8a): **a registry row suppresses only if its rule name is
  the string the gate greps**; **validate every probe against a known answer WITH negative controls**;
  **a `#`-COMMENTED LINE IS NOT A FINDING**; **NEVER verify a produced file with `Test-Path`** (09-17
  `build_report` died at 13/17, files newer, manifest stale); **REUSE THE PARSER** (ENG-STD 4.4 --
  `Get-BundleList` knows both bundle shapes; hand-rolling it got 0 nodes from all 66 exports).
- **A SAME-LOOKING STRUCTURE ELSEWHERE IS A QUESTION, NEVER A PRECEDENT.** **A STANDING RULE IS NOT
  EVIDENCE**; **AN EXPLANATION IS NOT A MEASUREMENT**; **A GATE THAT MEASURED NOTHING IS NOT A PASS**;
  **A CENSUS BOUNDS CURRENT USE, NOT THE PLATFORM** (09-17, #48); **MY OWN STATE ROWS GO STALE WITHIN
  HOURS** -- re-read before citing.
