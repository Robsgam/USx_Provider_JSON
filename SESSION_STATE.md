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
6 need two things: **5 a tenant test** (CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA,
LA_LEMS) and **CA_CLETS_OCATS ONE Jira comment** (DEX-980 `Blocked`, release line drafted).
TX_TLETS_CCH is PARKED so it can never complete -- whether the 19-of-20 target moves to the eligible
denominator is Rob's call on ENGINEERING_STANDARD 5.1.
**CA_eSUN DEX-1313** -- comment 811409 covers the RADIOBUTTON line ONLY; v3.x still owes a release
line. eSUN is the first provider with a SUBTASK: name the ticket (DEX-1312 parent / DEX-1313 sub).

**The queue** = the 5 above (`report_import_owed.ps1`). **SDSO LIVE runs eSUN v1.0 against a repo at
v3.1** -- a LIVE bump is a coordinated re-import and Rob's call, never a repo action. **IMPORT FIRST,
THEN PICKLIST CAPTURE** (Rob 2026-08-28): the console script scrapes the RENDERED form, so the capture
precedes CHOOSING TEST VALUES -- which is why CA_VENTURA cannot fix its hollow toggle yet.

**OFFICER GUIDES 20/20 CURRENT** (473 rows, 0 stale); convention in `usx-build` Step 4c, checker is
`_probes/audit_guide_completeness.ps1`. **EXTENSION v0.5.6** -- `audit_extension_syntax.ps1` (in
`doctor`) parses the browser scripts, which nothing did until a 1-char break killed the driver and
capture tools for 5 days (2026-09-04..09).

## ROB'S CALLS, NOT MINE

- **CA_CONTRA_COSTA JAWS/SuperQuery** -- 4 UNDER / 3 OVER, verbatim in its BUILD_NOTES. Hold the
  SWEEP, not the import. **LA_LEMS `QB{reg}` vs `BQ{reg}`** -- in LA's registry, not taken.
- **MINED-KEYREF, 4 EXPOSED** (`_probes/sweep_mined_keyref_shadow.ps1`): eSUN QV.V->4V, QB.H->4V,
  QB.R->4B; CA_SAN_LUIS_OBISPO QV.V->4V. A rename, not a wire change; both never-tested. eSUN's
  228KB tenant export sits in pushed history at `8273a87f` -- removal needs a force-push.

## OPEN FINDINGS -- detail lives in `FINDINGS_REGISTER.md`, do NOT restate it here

- **194 of 264 registry rows (73%) unverifiable** by `audit_registry_currency`; 7 providers at zero
  checkable rows, and the first row opened by hand in that zone was FALSE.
- **CA_eSUN v2.2: 2 items in its BUILD_NOTES, deliberately OFF the ticket** -- the 7 validator FAILs
  the 53 captures REFUTE, and the BirthDate over-permit whose fix collapses the owner-name search.
- **CA_VENTURA hollow toggle**: `LicensePlateTypeCode` toggles to its own form default -- needs a
  TEST_VALUE_OVERRIDE, value chosen AFTER its picklist capture.
- **LIMITATION #41** (HOME state routes a local plate to NLETS) -- paused pending CommSys. 5 providers owe the picklist capture. **NCIC hit blocks CONFIG-PRESENT, NOT RENDERING-VERIFIED** on HI and TN.
- **RESWEEP 2026-09-08: 20/20 ENFORCED 0F/0W, no defect in any provider JSON.** Fidelity 426 branches / 4 UNDER / 4 OVER / 0 NEVER-COMPARED -- all 4+4 are CA_CONTRA_COSTA's (Rob's JAWS call).
## RND-71625 -- IN FLIGHT, JIRA REPLY HELD (Rob: "hold the jira reply and hold on any changes")

**EVIDENCE GATHERED 2026-09-09 -- THE TICKET'S RMS CLAIM DOES NOT REPRODUCE.** Full detail +
verbatim message in `FINDINGS_REGISTER.md`; do not restate here. IL LEADS, simulation OFF + no
device ID: an amber icon renders in 1-3ms, Send + both checkboxes are DISABLED, and hovering gives
*"Computer/Device name "LAPTOP-NLHTE6T0" not found, please have your administrator add this device
to the universal search devices"*. So the officer IS told. **The narrower real findings:** the glyph
is `mdi-information` (circle-i), not a warning icon, and the message is hover-only on an icon with
NO aria-label/title -- invisible to a screen reader, which plausibly explains the original report.
**The control run is NO LONGER blocking.** **NOT concluded:** whether RMS shows a NOTICE -- the only
hit was MY OWN PANEL TEXT (v0.5.8 self-detection bug, fixed v0.5.9): zero evidence, not a negative.
**Jira still HELD.** `deviceRegistrationOptional` (`_build_rms_bundle.ps1:90`, `$true` on
`RestAuthenticationHandler` vs `$false` on Commsys, all 20) is untouched AND this evidence does not
support it -- RMS *does* block, the opposite of what that hypothesis predicts.

## DO NOT RE-RAISE

- `State2`-`State5` multi-state broadcast: OUT OF SCOPE 2026-08-02. OH's `ReasonCode`/`Requestor` =
  the BMVIMS case. CommSys asks HELD. TX_TLETS_CCH testing PARKED. DH NOT SUPPORTED FROM CAD.
  TN `RQ01` + name-component casing CLOSED 08-24.
- **A keyRef NEVER reaches the wire, and neither does `primaryFieldReference`.** Before calling an
  identity-label difference a defect, ask whether the label ships.
- **THE NY DEMOTED-QUALIFIER GAP IS CLOSED, not owed** -- measured 2026-09-09,
  `ny-demote-mandatory-qualifier` is **[KILLED]** (2/2, 0 SURVIVED/INVALID); the NEVER-COMPARED ->
  FAIL change fixed it. No third fix (two REJECTED, see `FINDINGS_REGISTER.md`). **Second** stale-OWED
  claim here to manufacture work on a tenant-verified provider -- **measure before believing this.**
- **`[FLAG:plan-dedupe-vacuous-tests]` is DONE, not deferred** (FL, HI, IL, NJ, NY) -- TAKEN
  2026-08-31; `audit_log_inflation` reads 853 logs / 0 findings.
- **Jira is HELD and lifts ONE PROVIDER AT A TIME.** No approval carries to the next provider.

## RULES I BROKE -- READ BEFORE EDITING

- Two durable rules MOVED to `usx-tooling` (Step 6 / Step 8a) where they are read at the right
  moment: **a registry row only suppresses if its rule name is the string the gate greps**, and
  **validate every probe against a known answer WITH negative controls** (a too-narrow detector
  reports a clean miss -- `authwatch` read `warnish:false` on a live amber icon).
- **NEVER verify a produced file with `Test-Path`** -- a leftover satisfies it. Compare write times.
- **REPLACE this file, never append.** It has failed its own 120-line gate three times.
- **A SAME-LOOKING STRUCTURE ON ANOTHER PROVIDER IS A QUESTION, NEVER A PRECEDENT.** FIVE claims
  retracted 2026-09-08, each from inferring off familiar shape instead of that provider's OWN
  authority. Read the variant's `<Requirements>` FIRST.
- **A STALE MUTATION IS INDISTINGUISHABLE FROM A BLIND GATE** and sends you to widen a gate that
  works. `audit_gate_efficacy` takes `Valid={}` preconditions -- give every new mutation one.
- **AN EXPLANATION IS NOT A MEASUREMENT.** My harness said 3 extension scripts did not load; I wrote
  a plausible `file://` story instead of getting the real error, and committed the story. The files
  were genuinely broken -- driver+capture dead 5 days. Go get the unsanitized error.
