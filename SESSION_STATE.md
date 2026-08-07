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

**IL_LEADS_OFML v2.1 DONE 08-07.** DEX-1284 pass + HI-style collapse (Veh/Per/Boat 3 cards -> 1;
11 -> 5), OLN/`NCIC Image`/`Stolen Check` labels, ALL-CAPS path titles, 4/4/4 grid. Layout ONLY --
9 combos, 0 under/over, 0 prefill-dead, 6/6 killed, unchanged from v2.0. IL enforce 0F/0W (40 PASS).
Also closed: extract **PROVISIONAL -> CONFIRMED** (CHECK 0 gates; devdoc Basic = the 5 built) +
ledger names v2.1 not-imported. No IL tenant exists, so it cannot be tenant-tested. IL has NO Jira
ticket (no `JIRA_REFERENCE.txt` entry, no `DEX_TICKET.md`) -- do not invent one.

**NEXT: HI_HCJDC_OFML** -- v4.14 ALL-PASS 46/46, still owed the DEX-1283 Attention/Requestor `X`
check. Determine FIRST whether its field is `any[]`-only or `set[]`-mandatory -- NY needed a
different fix for that exact reason. Then AZ_AZDPS v3.7 (59 owed; needs Rob review + import),
then the remaining 12. Jira: NY DEX-969 comment **794205**; FL/TX/CA_CLETS posted 08-06.

**TOOLING BUG, 08-07, NOT fixed (needs `usx-tooling` + a LAW 2 mutation):** one adjudicated devdoc
combination cannot be recorded so that BOTH sibling gates honour it. 2p hardcodes rule
`devdoc-combo-unbuilt` (`audit_devdoc_combinations` L323); 2q hardcodes `devdoc-optional-unreachable`
(`audit_devdoc_optionals` L163); **neither uses the shared `_divergence_rules.ps1` vocabulary.** So
IL's Article-#2 row satisfies 2p and is INERT for 2q -> 2q prints `[FAIL] ArticleSingleQuery #2 ->
NO COMBO FIRES` permanently. Renaming the rule fixes 2q and BREAKS 2p: it is a GATE fix, never a
registry edit. 2q is advisory, so nothing is blocked. Also open: `select-to-input` fuzz survivor --
no gate stops a dropdown-required field (SexCode/raceCode/State) being built as FormInput;
`verify_build` hard-gates only VehicleMakeCode.

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
`value-strip` plan-test kind added 08-07 (only NY uses `IgnoreUserValueRuleHandler`; 19 unchanged).

## OPEN DECISIONS -- Rob's call

**LA_LEMS DP/DQ** -- PARKED. (AZ DL scope inversion CLOSED v3.5; the two AZ fuzz survivors CLOSED
08-04 as HARNESS artifacts -- do NOT widen those gates.)

**Residual, recorded, NOT owed:** `VEHICLE_BODY_STYLE|NJ_NIBRS` across all 20 QRDMs vs CLAUDE.md's
"CA=VEHICLE" -- HYPOTHESIS, unsettleable from the repo | fidelity advisory 11 UNDER / 40 OVER (none on
the fixture; use `usx-adjudicate`) | CCH spec-plan name divergences | `audit_devdoc_optionals` /
`audit_log_content` FLAKE under parallel load -- re-run alone | `attributeTypeId=RACE` used by 10
providers vs FIELD_REFERENCE "DO NOT use" (AP #3) -- stale KB line, CA_CLETS is tenant-proven.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c, `usx-test-iterate`.

- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED.** Repeated 08-06/07 and again 08-07 (invented
  a DEX number for IL; read grep COUNTS as "HI builds State2-5" when the 4 hits were EXCLUSION
  comments). One shape: concluding while the decisive check is within reach. Not knowledge -- haste.
- **CHECK IF IT IS ALREADY ADJUDICATED FIRST.** 08-07: re-derived BOTH IL findings from scratch;
  both were already in `ACCEPTED_DIVERGENCES` from 08-02 with the same reasoning. Read the registry
  and `git log` before investigating.
- **NEVER cite another provider as authority.** Only CC->CA_CLETS and `<BASE>_<VARIANT>`->`<BASE>`.
  CA_CLETS and CA_VENTURA_COUNTY share an `IR.QVC{Name}` requiring OPPOSITE things.
- **A RECORD IS A CLAIM -- read the artifact.** `audit_lifecycle` (2r) reads `DEX_TICKET.md`, NOT the
  ticket; enforce reads CACHED reports (2e said PROVISIONAL after the file said CONFIRMED -- rerun
  `build_report`). Exit 0 is not evidence a gate spoke: grep its VERDICT line; print the denominator.
- **A finding across MANY providers is almost always YOUR PROBE** (100/67/25/6 false findings; 08-07
  `attributeTypeId=RACE` in 10 providers was a stale KB line, not 10 defects).
- **Add a new gate/test-kind to EVERY harness AND consumer** -- fuzz, portability, efficacy, and for
  a plan-test kind the label fn, relabeler, importer AND `driver.js`'s filter.
- **MUTATION ORDER: mutate -> restore -> RE-STAMP -> verify.** `git status` clean is not sufficient.
- **Multi-line `.Replace()` no-ops on CRLF -- use Edit.** Document a new tool in the SAME action.
- **REPLACE this file, never append.** The line gate has now caught me SEVEN times.
