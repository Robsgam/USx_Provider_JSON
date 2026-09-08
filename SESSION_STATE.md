# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-09-08 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.12 | ALL-PASS (53 logs) |
| CA_CLETS | v2.27 | ALL-PASS (99 logs) |
| CA_CLETS_OCATS | v2.12 | ALL-PASS (62 logs) |
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


**MISSION: 13 of 20 LIFECYCLE-COMPLETE** (`report_mission_status.ps1`, 2026-09-08; was 9). The other
6 need exactly two things: **5 need a tenant test** (CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO,
CA_VENTURA_COUNTY, LA_LEMS) and **CA_CLETS_OCATS needs ONE Jira comment** (DEX-980 `Blocked`, release
line drafted). TX_TLETS_CCH is PARKED so it can never complete -- whether the 19-of-20 target moves
to the eligible denominator is Rob's call on ENGINEERING_STANDARD 5.1.
**CA_eSUN DEX-1313** -- `POSTED: v2.2 comment 811409` covers the RADIOBUTTON line ONLY; the v3.x
mainline still owes its own release line. eSUN is the first provider with a SUBTASK, so name which
ticket (DEX-1312 parent / DEX-1313 subtask).

**The queue** = the 5 above (`report_import_owed.ps1`). **SDSO LIVE runs eSUN v1.0 against a repo at
v3.1** -- a LIVE bump is a coordinated re-import and Rob's call, never a repo action. **IMPORT FIRST,
THEN PICKLIST CAPTURE** (Rob 2026-08-28): the console script scrapes the RENDERED form, so the capture
precedes CHOOSING TEST VALUES -- which is why CA_VENTURA cannot fix its hollow toggle yet.

**OFFICER GUIDES 20/20 CURRENT** (473 rows, 0 stale). Convention: `usx-build` Step 4c; in/out-of-state
are SEPARATE rows sharing a message key, in-state rows name the home state. Checker is
`_probes/audit_guide_completeness.ps1` -- **NOT in `tools/`**, which is why it escapes the orphan census.

## ROB'S CALLS, NOT MINE

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- 4 UNDER / 3 OVER, verbatim in its BUILD_NOTES. Hold the
  SWEEP, not the import.
- **LA_LEMS BoatQuery `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **MINED-KEYREF ATTRIBUTION, 4 EXPOSED** (`_probes/sweep_mined_keyref_shadow.ps1`): CA_eSUN QV.V->4V,
  QB.H->4V, QB.R->4B; CA_SAN_LUIS_OBISPO QV.V->4V. A rename, not a wire change. Both never-tested.
  Also: eSUN's 228KB tenant export sits in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **194 of 264 registry rows (73%) are unverifiable** by `audit_registry_currency`; 7 providers at
  zero checkable rows, and the first row opened by hand in that zone was FALSE.
- **CA_eSUN v2.2 carries 2 known items in its BUILD_NOTES, deliberately OFF the ticket**: the 7
  validator FAILs the 53 captures REFUTE (State sends CA/GA, SexCode sends M), and the BirthDate
  over-permit whose fix would collapse the owner-name search. **No response data will ever be
  forthcoming** (Rob 2026-09-03), so the second is unanswerable from evidence.
- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default -- needs
  TEST_VALUE_OVERRIDES, value chosen AFTER its picklist capture.
- **LIMITATION #41** (HOME state routes a local plate to NLETS) -- paused pending CommSys. 5 providers owe the picklist capture.
- **NCIC hit blocks CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI and TN.
- **RESWEEP 2026-09-08 COMPLETE: 20/20 ENFORCED 0F/0W, NO defect in any provider JSON**; 9 tooling
  bugs fixed. Fidelity **426 branches / 4 UNDER / 4 OVER / 0 NEVER-COMPARED** (was 6, uncounted) --
  only CA_CONTRA_COSTA's remain (Rob's JAWS ruling). TX's 2 closed: a stale row from a REVERSED
  decision, not a ruling owed.
- **THE ONE REAL GATE GAP, catalogued + UNFIXED**: a mandatory QUALIFIER demoted `set[]`->`any[]`, no
  gate reacts. Confirmed on **NY `DALH`/BirthDateDH ONLY** (my TX_CCH reproduction was FALSE -- State
  is OPTIONAL there). Mutation `ny-demote-mandatory-qualifier` reports SURVIVED deliberately, so **NY
  reads short of "finished" until fixed.** TWO fixes tried and REJECTED with numbers in
  `FINDINGS_REGISTER.md` -- read it before a third attempt.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02. OH's `ReasonCode`/`Requestor` =
  the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH testing PARKED. DH NOT SUPPORTED FROM CAD.
  TN `RQ01` + name-component casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, and neither does `primaryFieldReference`.** Before calling an
  identity-label difference a defect, ask whether the label ships.
- **`[FLAG:plan-dedupe-vacuous-tests]` is DONE, not deferred** (FL, HI, IL, NJ, NY) -- TAKEN
  2026-08-31; `audit_log_inflation` reads 853 logs / 0 findings. It previously read "correctly
  deferred", and that stale claim got quoted into an audit, an agent's analysis and a plan as a hard
  rule. **A stale DO-NOT-RE-RAISE suppresses real work invisibly.**
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
- **A SAME-LOOKING STRUCTURE ON ANOTHER PROVIDER IS A QUESTION, NEVER A PRECEDENT.** FIVE claims were
  retracted on 2026-09-08 -- 2 "blind gates" that were broken TESTS, an NJ Boat guardrail test that
  would have FAILED on a correct build, TX "needs Rob's ruling", and the TX_CCH reproduction. Every
  one came from inferring from familiar shape instead of reading that provider's own authority.
  HI's note says it best: "Same-looking guardrail, two right answers, each decided by the provider's
  OWN authority." Read the variant's `<Requirements>` FIRST.
- **A STALE MUTATION IS INDISTINGUISHABLE FROM A BLIND GATE**, and it sends you to widen a gate that
  already works. `audit_gate_efficacy` now takes `Valid={}` preconditions -- give every new mutation
  one, or it will rot into a false SURVIVED.
