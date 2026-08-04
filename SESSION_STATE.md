# SESSION STATE — where we are RIGHT NOW

> **The pick-up point** — injected into every new session by the SessionStart hook, committed so it
> cannot drift from the code. **CURRENT STATE ONLY** (history lives in git + `CHANGELOG_<P>.md`);
> **REPLACE, never append**; keep under ~80 lines or it stops being read; update in the SAME commit as
> the work; derive every number from `portfolio_status.ps1` / `enforce.ps1` rather than remembering it.




<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-04 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.23 | ALL-PASS (90 logs) |
| FL_FCIC | v7.17 | ALL-PASS (116 logs) |
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

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold. Now **BLOCKED** (your call 2026-08-02): `audit_devdoc_combinations`
  compares ZERO devdoc combinations there, and a zero-comparison run is now a FAIL, not a PASS.
  Nothing about CC changed -- the gate stopped crediting a comparison that never ran. Clears by fixing
  the devdoc parse or recording why there is no combination table; **do neither while the hold stands.**
- **LA_LEMS -- PARKED (Rob 2026-08-04).** 2 DH-`Attention` items DEFERRED, plus a real BUILD_RULES 20b
  WARN (`ImageIndicator` prefilled `Y` while `DriverLicenseQuery/DQ` gates `ImageIndicator NOT_EXISTS`)
  -- same root cause as its registered 2026-07-29 dead combo, newly visible to two more gates. Nothing
  to diagnose; do NOT silence it with a divergence. **Expect `[WARN] Cross-provider: 207P/0F/1W` on
  EVERY provider's enforce -- that check is portfolio-wide, so the WARN is LA's, not the one under
  test.** Carries `[FLAG:validate-imgind-20b-l30]`.
- **Jira: ALL updates HELD.** `enforce` 2r `[GAP]` is EXPECTED.
- **Form review is Rob's MANUAL gate.** 2k `[INFO] not reviewed` is steady state. Never prompt.
- TN_TIES prose divergence -- when we get to it.
- **NCIC-number-keyed combos: CLOSED 2026-08-03.** TX/FL each list it in their OWN devdoc Possible
  Combinations, so both correctly BUILD it. The "Data-Mined ... NCIC (QA,QB,QG,QV,QW)" line names
  standalone TRANSACTIONS, not a combination keyed on the NCICNumber FIELD. Residue is OH-only.

## STATE

**ENFORCED 0F/0W except:** LA_LEMS + CA_CONTRA_COSTA (parked/blocked, above), and MD_METERS +
OH_LEADS which carry `[FLAG:validate-imgind-20b-l30]` -- they clear at their OWN next rebuild; do NOT
rebuild them to chase a score. CC's block is a GATE getting stricter, not a provider getting worse.

**ENFORCED is not "done". SIX are tenant-tested, all re-swept 2026-08-03/04** -- FL 116, CA 90, TX 89,
NY 64, HI 46, NJ 36 = **441 logs**, each fresh against a reset package, four log gates green.
**AZ v3.5 is enforce-clean and NEVER swept; 13 others never swept** = the backlog.

Invariants: devdoc-UNBUILT 2 (LA) | wiring closure 0/9 | audit_metadata 20/20 | portability 260 cells
0 unportable | fidelity fixture 116 branches 0/0 | registry currency 0 stale | BUILD_NOTES 0 generic |
AZ gate efficacy 7/7. Gate stack changed heavily 2026-08-02/04 -- do NOT re-derive it; the
decision-trail hook + `git log -n 40` hold the reasoning. NEW: `audit_registry_currency`,
`audit_buildnotes_fidelity` (2u), and `audit_supported_queries` **CHECK 0** (transaction-name scope --
it compared queryLabel, never the wire transaction, for months).

## NEXT PHYSICAL ACTION

**AZ_AZDPS v3.5**: Rob's cosmetic review -> import -> `test_phase2.ps1 -Provider AZ_AZDPS`, then
`-PostIngest`. After that, the 13 other never-swept providers (each needs an import first).

**Jira CURRENT on all six** (FL 790815, TX 790861, NY 790896, NJ 790914, CA 791400, HI 791589).
**TENANT INFO STAYS OFF THE TICKETS** (Rob, restated): no attachment, catalog or Foundation line --
track those in `IMPORT_LEDGER.md` B (Foundation) + C (published JSON).

## OPEN DECISIONS -- Rob's call, do not settle unilaterally

1. **AZ Boat fuzz survivor is a GATE gap, NOT a build defect.** Dropping `RegistrationNumber` from the
   hull combo's `any[]` goes unnoticed by every gate; AZ's build has it correct. Widening the gate is
   tooling work, deliberately not done in an AZ-only pass.
2. **LA_LEMS DP/DQ** -- PARKED, see ON HOLD. (AZ DL scope inversion: CLOSED at v3.5.)

**Residual gaps -- recorded, NOT owed, do not "discover" again:** `VEHICLE_BODY_STYLE|NJ_NIBRS` uniform
across all 20 QRDMs vs CLAUDE.md's "CA=VEHICLE" -- **HYPOTHESIS**, unsettleable from the repo |
fidelity advisory 11 UNDER / 40 OVER (none on the fixture; use `usx-adjudicate`) | CCH spec-plan name
divergences | `audit_devdoc_optionals`/`audit_log_content` FLAKE under parallel load -- re-run alone.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate` (validate the probe; fix vs register), `usx-metadata` 6
(transaction-level agreement is not variant-level), `usx-tooling` 5b/5c, `usx-test-iterate` (re-run
before diagnosing).

- **NEVER cite another provider as authority.** Only `CA_CONTRA_COSTA`->`CA_CLETS` and
  `<BASE>_<VARIANT>`->`<BASE>`. CA_CLETS and CA_VENTURA_COUNTY share an `IR.QVC{Name}` requiring
  OPPOSITE things. HI strips the loser on Hull>Reg; NJ deliberately carries it. Ask what X's OWN
  authority requires.
- **A RECORD IS A CLAIM, NOT EVIDENCE -- read the artifact first.** Cost most of 2026-08-03: a stale
  registry row + an understated BUILD_NOTES nearly drove a needless version bump; a stale
  `DEX_TICKET.md` produced "nine versions owed" when it was five. Both gated now (2u, registry
  currency) -- but `audit_lifecycle` still reads the FILE, not the ticket.
- **A step that did not run is NOT a pass; print the denominator.** Vacuous, MUTE and FLAKE all read
  green. **After wiring a gate, GREP FOR ITS VERDICT LINE** -- built a mute gate twice on 08-03/04
  (`-Quiet` in doctor; `$providerDirs` vs `$providers` in 2u, which printed a header, iterated
  nothing, and still reported 42 PASS / 0 FAIL). Exit 0 is not evidence a gate spoke.
- **A finding repeated across MANY providers is almost always YOUR PROBE** (100 / 67 / 25 / 6 false
  findings; plus a grep that asked only for 4 fields and "proved" 3 others missing).
- **The driver's "N queries submitted" is NOT a send count.** 12 timeouts / 4 providers on 08-03/04,
  all cleared by re-running. Re-run before diagnosing, and let a count SETTLE before theorising.
- **When you add a gate, add it to EVERY harness** -- fuzz, portability, efficacy -- not just `enforce`.
- **MUTATION ORDER: mutate -> restore -> RE-STAMP -> verify.** `git status` clean is necessary, not
  sufficient (6th instance: LA_LEMS mtime, 08-03).
- **Multi-line `.Replace()` no-ops on CRLF -- use the Edit tool.** **Document a new tool in the SAME
  action** (CLAUDE.md + KB README + count).
- **REPLACE this file's content, never append.** The line gate has caught me FIVE times.