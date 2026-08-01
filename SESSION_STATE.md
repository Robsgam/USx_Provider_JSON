# SESSION STATE — where we are RIGHT NOW

> **This file is the pick-up point.** It is injected into every new session by the SessionStart
> hook, and it is committed to git so it can never drift from the code it describes.
>
> **Rules for whoever edits this (including future me):**
> 1. **CURRENT STATE ONLY.** No history, no changelog, no "prior — v4.12 did X". History lives in
>    git and in `providers/<P>/docs/tracking/CHANGELOG_<P>.md`. If you find yourself appending a
>    dated section, you are doing it wrong — *replace* the content instead.
> 2. Keep it under ~80 lines. If it grows past that it stops being read, which defeats the point.
> 3. Update it **in the same commit** as the work it describes. A stale state file is worse than none.
> 4. Numbers here must be derived, not remembered — run `tools\portfolio_status.ps1` and
>    `tools\enforce.ps1`.




<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-01 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.23 | ALL-PASS (89 logs) |
| FL_FCIC | v7.14 | ALL-PASS (109 logs) |
| HI_HCJDC_OFML | v4.14 | ALL-PASS (46 logs) |
| NJ_NJCJIS | v4.15 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.19 | ALL-PASS (64 logs) |
| TX_TLETS | v4.18 | ALL-PASS (89 logs) |
| _14 others_ | -- | never tenant-tested: AZ_AZDPS, CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## ⛔ ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- Rob 2026-07-31 "on hold until further notice". Parked CLEAN at v2.2,
  enforce 36P/0F/0W, test package reset. Everything owed is in its `PENDING_UPDATES.txt`, including
  that **JAWS is unbuildable** (devdoc defers to a doc not in `source/`; metadata has ZERO JAWS nodes).
- **Jira: ALL updates HELD** until the process is trusted. `enforce` 2r's `[GAP]` is EXPECTED.
- **Form review is Rob's MANUAL gate.** `enforce` 2k's `[INFO] not reviewed` is the steady state.
  Never prompt for it, never list it as owed. Record only when he says so.
- LA_LEMS `DQ`, TN_TIES prose divergence -- "handled when we get to them."

## STATE

6 providers tenant-tested and ENFORCED 0 FAIL / 0 WARN (433 logs, four log gates green):
TX v4.18 (89), NY v4.19 (64), NJ v4.15 (36), FL v7.14 (109), HI v4.14 (46), CA_CLETS v2.23 (89).
8 more PHASE-1 audited and BLOCKED as expected (never-tested): AZ, LA_LEMS, MD_METERS, TN_TIES,
OH_LEADS, NM, OR_LEDS, IL. **5 unaudited**: CA_CLETS_OCATS, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY,
TX_TLETS_CCH, and CA_CONTRA_COSTA (on hold).

## ⚖️ OPEN PORTFOLIO QUESTION -- Rob's call, do not settle unilaterally

**NCIC-number-keyed combos: built on TX/FL, registered-as-unbuilt on OH_LEADS.** All three devdocs
list them as Basic-supported (TX 3 items, FL 2, OH_LEADS 3). TX_TLETS and FL_FCIC BUILD
`QGNCICNumber` / `QANCICNumber` / `QBNCICNumber`; OH_LEADS does not, and on 2026-07-31 that was
registered as acceptable citing its devdoc's "Data-Mined Transactions: NCIC (QA, QB, QG, QV, QW)"
plus CLAUDE.md's existing "2 NCIC shadows dropped" note for that provider. Internally consistent for
OH_LEADS, INCONSISTENT across the portfolio. Either:
  (a) NCIC-keyed queries are worth building -> OH_LEADS has a real 2-combo gap, un-register it; or
  (b) they are data-mined and should not be built -> TX and FL each carry 3 combos of redundant
      surface, on TENANT-VERIFIED providers (removing them would bump both and archive 89 + 109 logs).
BUILD_RULES already says the data-mined list is NOT build scope in either direction until the platform
confirms semantics -- which is exactly why this needs deciding rather than inferring.

## NEXT PHYSICAL ACTION

1. **CA_VENTURA_COUNTY IG.QGH** -- the ONLY C1 candidate in the whole portfolio, now confirmed twice
   (by hand, and by the verified scanner). Its GunQuery `set[]` satisfies NO branch of metadata's
   mandatory `Choice[Age|BirthDate]`, so the request is wire-invalid. Flagged
   `[FLAG:GUN-NAME-CHOICE-IN-SET]`. **Its devdoc GunQuery section did not parse -- get the query
   authority before fixing.** Both fields exist in metadata, so this is tractable in one build pass.
2. Adjudicate the ~25 documented findings on the 8 audited providers (FIX-vs-REGISTER per
   `usx-build` Step 3).

`tools/audit_defect_classes.ps1` is **DONE for C1** (verified: known-answer = 1; agrees with 6d on
the six). C2/C3/C4 are RETIRED as duplicates of `audit_requirement_fidelity` /
`audit_devdoc_optionals` / `audit_query_trace` -- do not resurrect them; the evidence is in its
param block. Not wired into any gate yet, deliberately.

## RULES I BROKE TWICE TODAY -- READ BEFORE BUILDING

- **After a DIRECT build-script run, run `reset_test_package.ps1` AND sync docs.** `pipeline.ps1` does
  it; calling the provider script does not. I skipped it on CA_CONTRA_COSTA and again on CA_eSUN an
  hour later; each time a stale plan broke the GLOBAL `audit_simulator_parity` check and made ONE
  self-inflicted defect look like five unrelated provider failures. `usx-build` Step 4b.
- **Use the Edit tool for multi-line text, never `.Replace()`** -- CRLF no-ops silently, and a 3-arg
  call is read as a StringComparison and mangles the file. **Broken a THIRD time on 2026-08-01**
  (multi-line `.Replace()` reported success and changed nothing). There is no situation where
  `.Replace()` on a multi-line block is the right tool. Reach for Edit first, every time.
- **A gate that reads the WRONG AUTHORITY cannot fail honestly** -- it reports PASS or FAIL with
  equal confidence and no denominator to betray it. Two instances found 2026-08-01 in one tool:
  an alphabetical `*.xml` glob (read a 6-node excerpt as if it were 466-node metadata) and a
  flattened `<Choice>` (a branch can be a nested `<Set>` GROUP, not just a `<Field>`).
  **When two gates disagree, suspect the one that simplified its authority.**
- **Before building a new check, ask which existing gate already owns the question.** 3 of 4 classes
  in `audit_defect_classes` turned out to duplicate `audit_requirement_fidelity` /
  `audit_devdoc_optionals` / `audit_query_trace`, each as the weaker copy.
- **`powershell -File` stringifies array args** (`-Providers a,b` becomes one provider named "a,b").
- **Never grep a whole tool output for `FAIL`** -- headers explain what a failure IS. Anchor on the
  verdict line.
- **A step that did not run is NOT a pass.** Always print the denominator (compared count, branches).