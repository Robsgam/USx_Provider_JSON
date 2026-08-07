# SESSION STATE — where we are RIGHT NOW

> **The pick-up point** — injected into every new session by the SessionStart hook, committed so it
> cannot drift from the code. **CURRENT STATE ONLY** (history lives in git + `CHANGELOG_<P>.md`);
> **REPLACE, never append**; keep under ~80 lines or it stops being read; update in the SAME commit as
> the work; derive every number from `portfolio_status.ps1` / `enforce.ps1` rather than remembering it.




<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-07 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.7 | NEVER-TESTED -- 59 test(s) owed |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.18 | ALL-PASS (116 logs) |
| HI_HCJDC_OFML | v4.14 | ALL-PASS (46 logs) |
| NJ_NJCJIS | v4.15 | PARTIAL -- 4 plan test(s) owed (36 captured) |
| NY_NYSPIN_EJUSTICE | v4.23 | ALL-PASS (69 logs) |
| TX_TLETS | v4.19 | ALL-PASS (92 logs) |
| _13 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

DEX-1283/1284 cycle **FL -> NY -> CA_CLETS -> HI**: FL v7.18, TX v4.19 (+CCH v1.15), CA_CLETS v2.24,
NY v4.23 are DONE -- built, swept, Jira-posted, ledger-recorded. **HI_HCJDC_OFML is the only one
left**: v4.14, ALL-PASS 46/46, NOT yet checked for the Attention/Requestor `X` pattern. Check FIRST
whether its field is `any[]`-only or `set[]`-mandatory -- NY needed a different fix for exactly that
reason (below). Then AZ_AZDPS v3.7 (NEVER-TESTED, 59 owed; needs Rob's review + import), then the 13.

Jira: NY DEX-969 at comment **794205** (verified 08-07). FL/TX/CA_CLETS posted 08-06.

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold, now BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO
  devdoc combos and zero-comparison is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect
  `[WARN] Cross-provider: 207P/0F/1W` on EVERY provider's enforce -- it is LA's, not the one tested.**
- **Jira: DRAFT AND WAIT, every provider, every time.** Rob approves each post individually;
  establishing it once (TX) did not authorize the rest. **Tenant info stays OFF the tickets** --
  attachment/catalog/Foundation belong in `IMPORT_LEDGER.md` B and C.
- **GUI ONLY -- Rob never runs commands.** Translate console names to buttons (driver prints
  `__usxCaptureBatch()`; say "⚡ Fetch results"). Corrected 3x. Memory: `feedback_gui_only_no_commands`.
- **Form review is Rob's MANUAL gate.** 2k `[INFO] not reviewed` is steady state. Never prompt.
- TN_TIES prose divergence -- later. NCIC-number-keyed combos CLOSED 08-03 (OH residue only).

## STATE

**ENFORCED 0F/0W except:** LA_LEMS + CA_CONTRA_COSTA (above); MD_METERS + OH_LEADS carry
`[FLAG:validate-imgind-20b-l30]` and clear at their OWN next rebuild -- don't rebuild to chase a score.

**NJ + TX PARTIAL is a coverage GAIN, not a regression.** OWED: NJ 4 + TX 3 OOS-toggle tests (fill
**AK**), never generated before. Capture them -> ALL-PASS; no bump, no re-sweep.

Invariants: devdoc-UNBUILT 2 (LA) | wiring closure 0/9 | audit_metadata 20/20 | portability 260 cells
0 unportable | fidelity fixture 116 branches 0/0 | registry currency 0 stale | BUILD_NOTES 0 generic.
Gate stack changed heavily 08-02/04 -- do NOT re-derive; decision-trail hook + `git log -n 40` hold it.
**NEW 08-07: `value-strip` plan-test kind** -- `emit_test_plan` auto-tests any
`IgnoreUserValueRuleHandler` field with the handler's own ignored value. Only NY uses the rule; 19
others verified unchanged.

## OPEN DECISIONS -- Rob's call

**LA_LEMS DP/DQ** -- PARKED. (AZ DL scope inversion CLOSED v3.5; the two AZ fuzz survivors CLOSED
08-04 as HARNESS artifacts -- do NOT widen those gates.)

**Residual, recorded, NOT owed:** `VEHICLE_BODY_STYLE|NJ_NIBRS` across all 20 QRDMs vs CLAUDE.md's
"CA=VEHICLE" -- HYPOTHESIS, unsettleable from the repo | fidelity advisory 11 UNDER / 40 OVER (none on
the fixture; use `usx-adjudicate`) | CCH spec-plan name divergences | `audit_devdoc_optionals` /
`audit_log_content` FLAKE under parallel load -- re-run alone.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c, `usx-test-iterate`.

- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED.** Three misses on 08-06/07, one shape:
  concluded from partial evidence with the decisive check within reach -- assumed a code table was
  universal when its own captured label read "CA Purpose Code"; called a WORKING fix a defect by
  reading one `<Set>` line and forgetting keyRefs are never transmitted (LIMITATION #37), which a
  30-second wire diff reversed; blamed a stale/cached plan for "17 vs 19 tests" when one grep found a
  hardcoded filter. Not a knowledge gap -- a speak-before-checking gap.
- **NEVER cite another provider as authority.** Only CC->CA_CLETS and `<BASE>_<VARIANT>`->`<BASE>`.
  CA_CLETS and CA_VENTURA_COUNTY share an `IR.QVC{Name}` requiring OPPOSITE things.
- **A RECORD IS A CLAIM -- read the artifact.** **`audit_lifecycle` (2r) reads `DEX_TICKET.md`, NOT
  the ticket.** Re-proven 08-07: it read "Nothing owed" while FOUR versions were unposted and 2r
  PASSed throughout. Fetch the ticket (~86k -- delegate to an agent, keep only the conclusion).
- **A step that did not run is NOT a pass; print the denominator.** After wiring a gate, GREP FOR ITS
  VERDICT LINE -- built a mute gate twice. Exit 0 is not evidence a gate spoke.
- **A finding across MANY providers is almost always YOUR PROBE** (100/67/25/6 false findings).
- **The driver's "N queries submitted" is NOT a send count.** Re-run before diagnosing.
- **Add a new gate/test-kind to EVERY harness AND every consumer** -- fuzz, portability, efficacy;
  for a plan-test kind also the label fn, relabeler, importer AND `driver.js`'s filter. Missing that
  last one silently dropped the new tests from every run (08-07) and looked like a stale plan.
- **MUTATION ORDER: mutate -> restore -> RE-STAMP -> verify.** `git status` clean is not sufficient.
- **Multi-line `.Replace()` no-ops on CRLF -- use Edit.** Document a new tool in the SAME action.
- **REPLACE this file, never append.** The line gate has now caught me SIX times.
