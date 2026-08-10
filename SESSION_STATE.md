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

**HI v4.15 TENANT-COMPLETE 08-10 -- ALL-PASS 46/46** (Veh 16/Per 14/Gun 6/Art 3/Boat 7), four log
gates 46/46, inflation 0/0/0/0, enforce 43 PASS 0 HI-scoped F/W. **DEX-1283 Attention `'X'` removal
SETTLED BY WIRE 9/9:** `<Attention>SGAMBELLONE R</Attention>` on every KQ/KQN log with NO prefill and
NO combo default, so `any[]` membership alone feeds the handler and v2.9's gate-feeder claim is
refuted on HI's own wires. Rob overruled my "leave it". DL side emits NO `<Attention>` at all.
**STATED LIMIT:** the CAD `defaults[]` half is inspection-only -- no form log exercises the CAD path,
which is exactly DEX-1283's second symptom. **IL v2.2 DONE** (41/41, DEX-984 comment 795041).

**GATE WORK 08-10 -- `audit_sqvr_integrity` CHECK 2 was VACUOUS on 17 of 20**, matching 3 exact
phrasings and printing `[PASS]` having compared nothing. HI's SQVR read `Total combos: 17` (JSON 12)
+ `PENDING: ALL 5 entities` on a twice-ALL-PASS provider, for nine bumps. Fixed: all real phrasings +
explicit `[NOTE] CHECK 2 DID NOT RUN` for the 13 asserting no total. Coverage 3->7. **Trap: NJ writes
`Total combos: 5 QIDMs / 8 combos` -- the digit BEFORE "combos" wins or you FAIL on the QIDM count.**
LAW 2 proven by re-injecting HI's 17. One real find: **FL 31-vs-30, `[FLAG:sqvr-totals-denominator]`,
NOT fixed by me** (tooling 8c). 08-07: wiring-closure class J (1 hit TN RQ05, flagged); `validate`
component-type check; 2q EXISTENCE rows. **PRE-EXISTING:** NY efficacy 13/14; `-All` fidelity
misattributes registry rows.

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

**LA_LEMS DP/DQ** -- PARKED. (AZ DL scope inversion CLOSED v3.5; the 2 AZ fuzz survivors CLOSED 08-04
as HARNESS artifacts -- do NOT widen those gates.)
**Residual, recorded, NOT owed:** `VEHICLE_BODY_STYLE|NJ_NIBRS` in all 20 QRDMs vs CLAUDE.md's
"CA=VEHICLE" -- HYPOTHESIS, unsettleable from the repo | fidelity advisory 11 UNDER / 40 OVER (none on
the fixture) | CCH spec-plan name divergences | `audit_devdoc_optionals` / `audit_log_content` FLAKE
under parallel load -- re-run alone | `attributeTypeId=RACE` in 10 providers vs FIELD_REFERENCE "DO
NOT use" (AP #3) -- stale KB line, CA_CLETS is tenant-proven.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c, `usx-test-iterate`.

- **A RECORD IS A CLAIM -- READ THE ARTIFACT. Worst repeat offender.** 08-10: HI's BUILD_NOTES said
  the Attention `'X'` was the gate-feeder, I read the note (correctly, per build 6c) and STOPPED
  there instead of asking whether the version asserting it could support the claim -- it changed two
  things at once. Rob overruled me and the wire proved him right 9/9. Same class: 2r reads
  `DEX_TICKET.md` not the ticket; enforce reads CACHED reports. **Exit 0 is not evidence a gate
  spoke -- grep its VERDICT line and print the DENOMINATOR** (08-10: `audit_sqvr_integrity` CHECK 2
  compared ZERO on 17 providers and printed PASS).
- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED.** 08-07: invented a DEX number; read grep
  COUNTS as "HI builds State2-5" when the 4 hits were EXCLUSION comments.
- **CHECK IF IT IS ALREADY ADJUDICATED FIRST** -- registry + `git log` before investigating.
- **AIM A MUTATION AT THE GATE THAT OWNS THE CLASS** (ordering defect -> `audit_devdoc_order`).
- **DON'T RE-IMPLEMENT A PARSER (std 4.4).** 08-10: hand-counted HI's combos twice, got nothing, then
  `audit_test_coverage` answered it instantly. **NEVER cite another provider as authority** (only
  CC->CA_CLETS, `<BASE>_<VARIANT>`->`<BASE>`).
- **A finding across MANY providers is usually YOUR PROBE** -- but not always: verify at artifact
  level either way (08-10's 17-of-20 vacuous check was real, confirmed on HI's own numbers first).
- **A shared-tool change that reddens ANOTHER provider gets a FLAG, never a fix** (tooling 8c).
- **Add a new gate/test-kind to EVERY harness AND consumer.** MUTATION ORDER: mutate -> restore ->
  RE-STAMP -> verify. Multi-line `.Replace()` no-ops on CRLF -- use Edit.
- **REPLACE this file, never append.** The line gate has now caught me NINE times.
