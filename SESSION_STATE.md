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

**IL v2.2 -- ROB RE-IMPORTS, then sweep.** Tenant `usx-il-leads-ofml.mark43.com`, **DEX-984**.
**v2.1 IS INSTALLED** (proven: picklist capture returned v2.1-only labels `NCIC Image`/`Stolen
Check`/`Make`; 0 logs = never TESTED, not never installed), so v2.2 needs a re-import. v2.1 =
DEX-1284 collapse (11 cards -> 5); v2.2 = cosmetic pass (VIN spelled out, 3 identifier-priority
hints removed, Person name First-then-Last). Both label/order ONLY -- 3 guardrails + composite Name
`sourceField=[NameLast,NameFirst]` LAST-first wire format untouched. enforce 0F/0W IL-scoped,
**gate efficacy 18/18**, 2e gating, 41 plan tests 0 unfireable. Extension **manifest 0.4.0** adds the
IL host (matched only 7 before -- nothing would have injected). I wrongly recorded "no tenant" + "no
Jira ticket", inferred from those files' silence.
**PICKLISTS: 4 of 5 entities clean** (Person 5/5, Firearm 4/4, Article 1/1, Boat 3/3);
**Vehicle owes a re-scope** -- 3 fields `not found in DOM` because the FIREARM form was rendered
while Vehicle was selected. **Read `renderedSelectsNotInScope` every time** -- it names the
wrong-form fields. Re-scoping one entity replaces only that entity, so a bad recapture destroys good.

**NEXT AFTER IL: HI_HCJDC_OFML** -- v4.14 ALL-PASS 46/46, owed the DEX-1283 Attention/Requestor `X`
check; determine FIRST whether its field is `any[]`-only or `set[]`-mandatory (NY needed a different
fix for exactly that). Then AZ_AZDPS v3.7 (59 owed), then the remaining 12.
Jira: NY DEX-969 comment **794205**; FL/TX/CA_CLETS posted 08-06.

**GATE WORK 08-07 (4 gaps CLOSED):** `audit_wiring_closure` **class J ROUTING-ONLY** (EXISTS
condition on a field in NEITHER set[] nor any[]; EXISTS-only, else ~244 NOT_EXISTS false hits) --
97 examined, **1 hit TN_TIES RQ05**, flagged not fixed. `validate.ps1` checks COMPONENT TYPE for
`attributeTypeId` SEX/RACE. 2q honours EXISTENCE rows in the NO-COMBO-FIRES branch ONLY -- the naive
fix would have silenced LA_LEMS's parked finding. **PRE-EXISTING not mine:** NY efficacy 13/14
(`ny-drop-oos-guardrail` vs untouched `verify_build`; NY 13/13 record stale since 07-30);
`audit_requirement_fidelity -All` misattributes registry rows across providers.

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

Invariants: devdoc-UNBUILT 2 (LA) | wiring closure 1/10 (TN RQ05, flagged) | audit_metadata 20/20 |
portability 280 cells 0 unportable | fidelity fixture 116br 0/0 (414 total) | registry currency 0
stale | PS-5.1 parse 108/0. Gate stack changed heavily 08-02/04/07 -- decision-trail hook +
`git log -n 40` hold the reasoning; do NOT re-derive.

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
