# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-10 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.7 | NEVER-TESTED -- 59 test(s) owed |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.18 | ALL-PASS (116 logs) |
| HI_HCJDC_OFML | v4.15 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.2 | ALL-PASS (41 logs) |
| NJ_NJCJIS | v4.15 | PARTIAL -- 4 plan test(s) owed (36 captured) |
| NY_NYSPIN_EJUSTICE | v4.23 | ALL-PASS (69 logs) |
| TX_TLETS | v4.19 | ALL-PASS (92 logs) |
| _12 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**TWO JIRA DRAFTS AWAIT ROB'S APPROVAL -- nothing else is owed on HI or IL.**
1. **DEX-1257 HI v4.15** changelog + release line. 2. **DEX-984 IL v2.2** release line (drafted +
approved in substance 08-10, was HELD until HI tested -- HI is now tested, so it unblocks; still
draft-and-wait). Then AZ_AZDPS v3.7 (59 owed), then the remaining 12.

**HI_HCJDC_OFML v4.15 TENANT-COMPLETE 08-10 -- ALL-PASS 46/46** (Veh 16/Per 14/Gun 6/Art 3/Boat 7),
four log gates 46/46, inflation 0/0/0/0, enforce 43 PASS 0 HI-scoped F/W, validator 65P/0F/0W.
**DEX-1283 Attention `'X'` removal is SETTLED BY WIRE, 9/9:** `<Attention>SGAMBELLONE R</Attention>`
lands on every KQ/KQN log with NO `initialValue` and NO combo default -- `any[]` membership alone
feeds the handler, so v2.9's gate-feeder claim is refuted on HI's own wires (it changed two things in
one version and its own text named `any[]` as root cause). Rob caught me arguing to keep the `X`; I
was weighting a June note over August evidence. Control: DL side emits NO `<Attention>` at all.
**STATED LIMIT, do not overclaim:** the CAD `defaults[]` half is inspection-only -- no form-driven
log exercises the CAD path, which is exactly DEX-1283's second symptom.

**IL_LEADS_OFML v2.2 DONE.** ALL-PASS 41/41, four log gates, 3 guardrails wire-proven, Name LAST-first.
**DEX-984 comment 795041** = first-ever post (full v1.0->v2.2 dump). Ledger C records attach+catalog.

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
**EXPECT ON EVERY PROVIDER'S ENFORCE, not the one you tested:** `[FAIL] Repo audit 3 FAIL` =
LA/MD/OH STATUS.txt score drift (63P/70P/78P) from the 08-07 `validate.ps1` generalization. Each
clears at its OWN rebuild -- syncing them now is the mass-rebuild-by-back-door mistake (tooling 8c).

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
