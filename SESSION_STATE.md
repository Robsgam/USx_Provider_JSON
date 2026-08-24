# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-24 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.12 | ALL-PASS (53 logs) |
| CA_CLETS | v2.27 | NEVER-TESTED -- 99 test(s) owed |
| FL_FCIC | v7.24 | ALL-PASS (118 logs) |
| HI_HCJDC_OFML | v4.20 | ALL-PASS (50 logs) |
| IL_LEADS_OFML | v2.8 | ALL-PASS (44 logs) |
| NJ_NJCJIS | v4.17 | ALL-PASS (41 logs) |
| NM_NMLETS_OFML | v2.6 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.26 | ALL-PASS (65 logs) |
| OH_LEADS | v2.11 | ALL-PASS (65 logs) |
| TN_TIES | v2.6 | ALL-PASS (67 logs) |
| TX_TLETS | v4.21 | ALL-PASS (96 logs) |
| _9 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, OR_LEDS, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**EVERYTHING BLOCKS ON ONE ACTIVITY: IMPORT + SWEEP.** The build queue is EMPTY. 10 of 20 are
NEVER-TESTED and every one is build/spec/reachability-complete -- nothing further can be BUILT to
move the number. Queue authority is `report_import_owed.ps1`, never this file. Smallest first:
OR_LEDS 27, LA_LEMS 31, MD_METERS 44. Decide CONTRA_COSTA's JAWS ruling before its 92-test sweep.

**MEASURED 2026-08-24, do not re-derive from prose:** picklist 20 examined / **10 owe the one-time
capture / 0 owe a re-scope** / 10 current (AZ's 16-dropdown capture completed) - `audit_name_components`
216 / 0 C1 / 0 C2 / 0 C3 - `audit_layout_flow` 10 findings on 7 providers (six tenant-verified, so
each costs a re-sweep; NM's L9 is an ACCEPTED OPERATOR OVERRIDE) - clone groups 38 -> **33** untriaged.

## OPEN DECISIONS THAT ARE ROB'S, NOT MINE

- **CA_CONTRA_COSTA JAWS / SuperQuery ruling** -- pending; v2.4 deliberately did not pre-empt it. Its
  4 UNDER / 3 OVER (IR.QVC.N BirthDate+Age, NLTS.DQ.N SexCode+BirthDate, IR.QVC.O/.C/.S Age) are
  listed verbatim in its BUILD_NOTES and untouched: CA_CLETS and Ventura require OPPOSITE things there.
- **eSUN 228KB tenant export in pushed history** at `8273a87f` -- removing it needs a rewrite + force-push.
- **TOOLING GAP, REAL AND UNFIXED:** `audit_requirement_fidelity` does not descend into a `<Choice>`
  nested in `<Any>`, so a legal optional reads as OVER-PERMITTED. Proven on CA_eSUN `L1{Name}` and
  registered there (`demoted-to-any`, scoped to `L1.N` not bare `L1`). **Some of the portfolio's
  remaining OVER-PERMITs may be this same false class.** Owes the 6-provider fixture + 20-provider sweep.

## CLOSED 2026-08-24 -- DO NOT RE-OPEN, BOTH WERE MIS-RECORDED AS OPEN RISKS

- **TN `RQ01` unbuilt was NEVER a defect and was already adjudicated in TN's own registry.** The
  premise ("in-state plate reaches NCIC not TIES/DMV") is IMPOSSIBLE: the keyRef does not reach the
  wire -- a capture carries `<MessageType>VehicleRegistrationQuery</MessageType>` + fields and ZERO
  keyRef occurrences (Rob: *"we only send the VehicleRegistrationQuery and not the transaction name"*).
  `RQ01`/`RV01`/`QV{plate}` all share `set[]=[LicensePlateNumber]` so they are routing-indistinguishable.
  **`QV` is a DATA-MINED transaction** (devdoc line 9: NCIC QA/QB/QG/QV/QW tags returned from data
  mining) and `InquiryTypeIndicator` defaults to 3 = registration AND hotfiles in one query -- which is
  why building no separate stolen-vehicle query is correct. Residual is cosmetic: rename `QV.*` keyRefs
  at TN's next build, since those names are what made a correct build read as a defect.
- **Name-component casing**: at fieldId level it is Pascal 10 / camel 9 / internally mixed **ONE** (AZ,
  fixed at v3.12, wire-proven by 53 paired byte-identical captures) -- NOT the "seven" recorded. The old
  count tallied raw strings without asking which KEY they sat under. The 10-vs-9 split is cosmetic and
  is deliberately NOT being converged (19 rebuilds + 10 archived passing packages for zero gain).

## OPEN FINDINGS -- confirmed, unfixed

- **PAUSED PENDING COMMSYS -- LIMITATION #41:** a populated HOME state routes a local plate to NLETS.
  Our config is provably clean; evidence in `PLATFORM_CONSTRAINTS.txt` #41. Read before any State work.
- **NCIC hit blocks are CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI *and* TN (TN's mined-tag
  consumption has never been exercised -- make "does a mined hit render?" a stated TN sweep objective).
- **Officer guides are content-poor, not stale.** Rewrite requested; shape not agreed.
- **9 live flags, all one id: `[FLAG:plan-dedupe-vacuous-tests]`** (CA_SLO, CA_VENTURA, FL, HI, IL, LA, MD, NJ, TX_TLETS_CCH) -- so portfolio `enforce` reads **BLOCKED: 678 PASS / 9 FAIL**, and every FAIL is that one flag. Each clears at its OWN next rebuild; this is not new work. This line previously claimed "1 live flag: `nameparts-untested-unfrozen`" -- wrong in BOTH directions (that flag is fully PROPAGATED, and the live one was missing). Derive from `audit_reverse_propagation.ps1`, never from memory. Suppression registry 255 rows / 0 over-broad / 0 STALE.

## ON HOLD / DO NOT RE-RAISE

- **`State2`-`State5` MULTI-STATE NLETS BROADCAST -- PARKED UNTIL ROB BRINGS IT UP (2026-08-21).** Do not
  re-raise, do not propose propagating the registry row, do not cost it again. Already ruled OUT OF SCOPE
  2026-08-02; registered on 6 of 13 affected providers, class `other` so it silences nothing. **I
  re-derived it as new on 08-21 anyway** -- the pre-sweep flow reads the spec plan's UNREACHABLE findings
  and never cross-checks the registry, so it will keep looking new. The 24 UNREACHABLE spec tests on NM
  are this, and they are expected output.
- **COMMSYS ASKS ARE ON HOLD (Rob 08-18).** LA's devdoc PurposeCode/State inversion is recorded, NOT owed.
- **HI PlateType default on a CAD VIN check -- HELD.** Defaulting it kills the in-state plate search (BR 24).
- **TX_TLETS_CCH testing PARKED** (marker: its `docs/tracking/TEST_PARKED.txt`). **DH IS NOT SUPPORTED
  FROM CAD** (08-12). **`audit_devdoc_optionals` re-route hole DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination** (LIVE-PROVEN 38/38).
- **CLAUDE.md prose STALE in 2 spots**: MD_METERS owing `ncic-image-default-y-everywhere` (propagated 08-20); the old `audit_layout_flow` 139 baseline.

## RULES I HAVE BROKEN -- READ FIRST (`usx-adjudicate`, `usx-metadata`, `usx-tooling` 5b/5c)

- **A FINDING ON EVERY PROVIDER IS YOUR PROBE, AND SO IS A FINDING THAT LOOKS SYSTEMIC.** In one day:
  a casing probe read all 20 as MIXED (it counted strings without checking which KEY), a picklist probe
  compared ZERO twice (bundle shape, then `type` is an OBJECT `{resolvedName}` not a string), and an
  XPath silently matched nothing because **bash collapses `''` inside a single-quoted `-Command`**.
  Every one was caught only because the probe printed its DENOMINATOR and treated zero as a FAIL.
- **`<Any>` IS NESTED INSIDE `<Set>`, so `$c.Requirements.Any` returns NOTHING.** I read that as "no
  optionals", tightened three `any[]` pools on CA_eSUN v2.4 and DROPPED A LEGAL OPTIONAL. Dump
  `$c.Requirements.OuterXml`. Metadata attributes are lowercase (`keyReference`) and need `-Raw`.
- **DIAGNOSE FROM THE MECHANISM, NOT THE SYMPTOM.** Two tool diagnoses in one day were wrong on the
  first attempt ("it matches on the keyRef" -- it never did; "nothing checks picklist currency" -- it
  does, per category). Both wrong fixes would have been worse than the bug. Run the existing tool and
  read its output BEFORE reading your own theory.
- **AN OPERATOR OVERRIDE IS RECORDED FOR A REASON -- READ THE COMMENT BEFORE "FIXING" THE FINDING.**
- **A `head -N` SPLICE IS ONLY SAFE IF YOU KNOW WHAT LINE N IS**; **NARROWING AN `any[]` STRANDS ITS
  `defaults[]`** (class E); **A GATE SUITE CHAINED AFTER A FAILED BUILD REPORTS ON THE STALE JSON**
  (the tell is an ABSENT `RESULTS:` line, not a complaint); **templateColumns must match the CHILD
  COUNT *and* sum to 12**; **`-Quiet` suppresses `Write-Host`**; **`@($null).Count` IS 1**.
- **AN IDENTICAL DISTRIBUTION IS NOT PROOF.** AZ v3.12's `<Name>` counts matched v3.11 exactly (9/4/4/2),
  equally consistent with two tests SWAPPING values. Only per-test pairing (53 identical) settled it.
