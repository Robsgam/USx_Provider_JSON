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

**IL_LEADS_OFML v2.1 DONE 08-07** (DEX-1284 pass + HI-style collapse, 11 cards -> 5; layout ONLY,
structure identical to v2.0). IL enforce 0F/0W. Extract **PROVISIONAL -> CONFIRMED** (2e gates now);
ledger names v2.1 not-imported. **No IL tenant exists, so IL CANNOT be tenant-tested** -- provisioning
+ import is Rob's step. IL has NO Jira ticket (no `JIRA_REFERENCE.txt` entry, no `DEX_TICKET.md`).

**IL mutation map added: gate efficacy 6/17 (40%) -> 15/17 (88%).** The old "6/6 KILLED" was 6 generic
STRUCTURAL mutations with ZERO routing ones, so by LAW 2 IL's routing gates were unproven. 11 IL rows
added to `$MUTS`. Controls held: **TX 16/16, NJ 11/11, SURVIVED 0.** Also fixed a message that told
NJ/AZ/HI/FL/IL "no provider-specific mutation map" while they ran 1-11 -- it consulted only the
`$PROV_MUTS` hashtable, not `OnlyProvider` rows, understating the very coverage it reports.

**NEXT: HI_HCJDC_OFML** -- v4.14 ALL-PASS 46/46, still owed the DEX-1283 Attention/Requestor `X`
check. Determine FIRST whether its field is `any[]`-only or `set[]`-mandatory -- NY needed a
different fix for that exact reason. Then AZ_AZDPS v3.7 (59 owed; needs Rob review + import),
then the remaining 12. Jira: NY DEX-969 comment **794205**; FL/TX/CA_CLETS posted 08-06.

**FOUR OPEN GATE GAPS -- all mutation-found, none blocking, do NOT re-derive:**
1. `il-inert-condition-field` SURVIVED: a condition naming a fieldId **no control emits** is inert;
   `audit_wiring_closure` misses it though "inert condition" is its own documented class D.
2. `il-guardrail-wire-leak` SURVIVED: dropping State from Z2.P `any[]` with its `EXISTS` condition
   intact -- the field ROUTES but never reaches the wire. Closure is per-provider, defect is
   per-COMBINATION.
3. `select-to-input`: nothing stops a dropdown-required field (SexCode/raceCode/State) built as
   FormInput; `verify_build` hard-gates only VehicleMakeCode.
4. **2p/2q rule-vocabulary split** -- one adjudicated devdoc combo cannot be recorded so BOTH honour
   it: 2p hardcodes `devdoc-combo-unbuilt` (`audit_devdoc_combinations` L323), 2q hardcodes
   `devdoc-optional-unreachable` (`audit_devdoc_optionals` L163), neither uses shared
   `_divergence_rules.ps1`. IL's Article-#2 row satisfies 2p, is INERT for 2q -> 2q prints
   `NO COMBO FIRES` forever. Renaming fixes 2q and BREAKS 2p: GATE fix, never a registry edit.

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
