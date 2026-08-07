# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

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

**IL_LEADS_OFML v2.1 READY TO TEST 08-07.** DEX-1284 pass + HI-style collapse (11 cards -> 5, layout
ONLY). IL enforce 0F/0W IL-scoped; **gate efficacy 6/17 (40%) -> 18/18**; 2e CONFIRMED-gating;
2q/2r/2t PASS; 41 plan tests, 0 unfireable. **TENANT EXISTS: `usx-il-leads-ofml.mark43.com`,
ticket DEX-984** (Rob, 08-07). I had recorded "no tenant provisioned" + "no Jira ticket" -- BOTH
WRONG, inferred from the ledger's/JIRA_REFERENCE's own silence rather than verified.
**Extension manifest 0.4.0 adds the IL host** -- it matched only 7 tenants, so NOTHING would have
injected on IL. **NEXT STEP IS ROB'S: import v2.1 into that tenant, then sweep.**

**NEXT AFTER IL: HI_HCJDC_OFML** -- v4.14 ALL-PASS 46/46, still owed the DEX-1283 Attention/Requestor
`X` check; determine FIRST whether its field is `any[]`-only or `set[]`-mandatory (NY needed a
different fix for exactly that). Then AZ_AZDPS v3.7 (59 owed), then the remaining 12.
Jira: NY DEX-969 comment **794205**; FL/TX/CA_CLETS posted 08-06.

**GATE WORK DONE 08-07 (all four gaps CLOSED; do NOT re-derive):** new `audit_wiring_closure`
**class J ROUTING-ONLY** (an EXISTS condition gating a combo on a field in NEITHER its set[] nor
any[] -- routes then never transmits; EXISTS only, since 244 of 344 conditions are NOT_EXISTS and
including them would fabricate ~244 findings). Baseline 97 EXISTS examined, **1 real hit: TN_TIES
RQ05** -> flagged `[FLAG:wiring-closure-class-J-routing-only]`, NOT fixed (one provider at a time).
`validate.ps1` now checks COMPONENT TYPE for `attributeTypeId` SEX/RACE (the props were checked, the
type never was; State already was). 2q now honours EXISTENCE-class registry rows **in the
NO-COMBO-FIRES branch ONLY** -- the naive version would have silenced LA_LEMS's real parked
dropped-optional, measured before shipping.

**PRE-EXISTING, NOT MINE, worth a look:** NY gate efficacy is **13/14** -- `ny-drop-oos-guardrail`
SURVIVES `verify_build` (which I never touched; docs claiming NY 13/13 are stale since 07-30).
`audit_requirement_fidelity -All` MISATTRIBUTES registry rows across providers (LA's rows printed
under IL's header; IL alone is clean 9br 0/0) -- a reporting bug, it misled me once.

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold, now BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO
  devdoc combos and zero-comparison is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect
  `[WARN] Cross-provider: 207P/0F/1W` on EVERY provider's enforce -- it is LA's, not the one tested.**
- **Jira: DRAFT AND WAIT, every provider, every time** (TX once != the rest authorized). **Tenant info
  stays OFF tickets** -- attachment/catalog/Foundation go in `IMPORT_LEDGER.md` B and C.
- **GUI ONLY -- Rob never runs commands.** Translate console names to buttons. Corrected 3x.
- **Form review is Rob's MANUAL gate.** 2k `[INFO] not reviewed` is steady state. Never prompt.
- TN_TIES prose divergence -- later. NCIC-number-keyed combos CLOSED 08-03 (OH residue only).

## STATE

**ENFORCED 0F/0W except:** LA_LEMS + CA_CONTRA_COSTA (above); MD_METERS + OH_LEADS carry
`[FLAG:validate-imgind-20b-l30]` and clear at their OWN next rebuild -- don't rebuild to chase a score.

**NJ + TX PARTIAL is a coverage GAIN, not a regression.** OWED: NJ 4 + TX 3 OOS-toggle tests (fill
**AK**), never generated before. Capture them -> ALL-PASS; no bump, no re-sweep.

Invariants: devdoc-UNBUILT 2 (LA) | wiring closure 0/9 | audit_metadata 20/20 | portability 260 cells
0 unportable | fidelity fixture 116 branches 0/0 | registry currency 0 stale | BUILD_NOTES 0 generic |
PS-5.1 parse 108/0. Gate stack changed heavily 08-02/04/07 -- do NOT re-derive; decision-trail hook +
`git log -n 40` hold it.

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

- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED.** 08-07: invented a DEX number for IL; read
  grep COUNTS as "HI builds State2-5" when the 4 hits were EXCLUSION comments. Haste, not knowledge.
- **CHECK IF IT IS ALREADY ADJUDICATED FIRST.** Re-derived both IL findings from scratch; both were
  already in `ACCEPTED_DIVERGENCES` since 08-02. Read the registry + `git log` before investigating.
- **AIM A MUTATION AT THE GATE THAT OWNS THE CLASS.** `il-drop-identifier-guardrail` "SURVIVED"
  reachability because it is an ORDERING defect -> repointed to `audit_devdoc_order`, KILLED.
- **NEVER cite another provider as authority.** Only CC->CA_CLETS and `<BASE>_<VARIANT>`->`<BASE>`.
- **A RECORD IS A CLAIM -- read the artifact.** 2r reads `DEX_TICKET.md`, not the ticket; enforce
  reads CACHED reports (2e said PROVISIONAL after the file said CONFIRMED -- rerun `build_report`).
  Exit 0 is not evidence a gate spoke: grep its VERDICT line; print the denominator.
- **A finding across MANY providers is almost always YOUR PROBE** (08-07: `attributeTypeId=RACE` in
  10 providers was a stale KB line, not 10 defects).
- **Add a new gate/test-kind to EVERY harness AND consumer** (fuzz, portability, efficacy; plan-kinds
  also need the label fn, relabeler, importer AND `driver.js` filter).
- **MUTATION ORDER: mutate -> restore -> RE-STAMP -> verify.** `git status` clean is not sufficient.
- **Multi-line `.Replace()` no-ops on CRLF -- use Edit.** Document a new tool in the SAME action.
- **REPLACE this file, never append.** The line gate has now caught me EIGHT times.
