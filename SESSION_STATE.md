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
- **LA_LEMS** -- its 2 DH-`Attention` devdoc items are DEFERRED. Only reason it is BLOCKED.
- **Jira: ALL updates HELD.** `enforce` 2r `[GAP]` is EXPECTED.
- **Form review is Rob's MANUAL gate.** 2k `[INFO] not reviewed` is steady state. Never prompt.
- TN_TIES prose divergence -- when we get to it.
- **NCIC-number-keyed combos: CLOSED 2026-08-03.** TX/FL each list it in their OWN devdoc Possible
  Combinations, so both correctly BUILD it. The "Data-Mined ... NCIC (QA,QB,QG,QV,QW)" line names
  standalone TRANSACTIONS, not a combination keyed on the NCICNumber FIELD. Residue is OH-only.

## STATE

**18 of 20 ENFORCED 0 FAIL / 0 WARN** (full sweep, measured). BLOCKED: LA_LEMS + CA_CONTRA_COSTA above.
The CC block is a GATE getting stricter, not a provider getting worse -- do not loosen it back.

**ENFORCED is not "done". SIX are tenant-tested and ALL SIX WERE RE-SWEPT 2026-08-03/04** on Rob's
call after the build process changed -- FL 116, CA_CLETS 90, TX 89, NY 64, HI 46, NJ 36 = **441 logs**,
every one captured fresh against a reset package, four log gates green on each.
**14 ENFORCED but NEVER swept** = the whole remaining backlog.

Invariants held: devdoc-UNBUILT 2 (both LA_LEMS) | wiring closure 0/9 classes | audit_metadata 20/20 |
gate efficacy 11/11 KILLED | portability 260 cells 0 unportable | fidelity fixture 116 branches 0/0 |
spec-plan NO-FIRE 24 | **registry currency 0 stale / 69 checkable** | **BUILD_NOTES fidelity 0 generic
of 20**. Gate stack changed heavily 2026-08-02/04 -- do NOT re-derive it; the decision-trail hook +
`git log -n 40` hold the reasoning. NEW since 2026-08-03: `audit_registry_currency`,
`audit_buildnotes_fidelity` (enforce **PHASE 2u**, BLOCKING, added at zero).

## NEXT PHYSICAL ACTION

**The 14 never-swept providers**, via `test_phase2.ps1 -Provider <NAME>` then `-PostIngest`. Each needs
an import first (Rob's hands), then ~20 min of driver + watcher. Nothing else is owed on the six.

**Jira is CURRENT on all six** (FL 790815, TX 790861, NY 790896, NJ 790914, CA_CLETS 791400) -- the
HELD-updates rule was lifted for these by Rob 2026-08-03. **HI v4.14 is the one release line still
owed**, and its `DEX_TICKET.md` has not been checked against DEX-1257 yet.

**TENANT INFO STAYS OFF THE TICKETS** (Rob 2026-08-03, restated): no attachment note, no catalog post,
no Foundation import line -- even though older comments on DEX-967/988 carry `IMPORT:` lines. Track it
in `IMPORT_LEDGER.md` sections B (Foundation) and **C (published JSON: ticket + catalog)**.

## OPEN DECISIONS -- Rob's call, do not settle unilaterally

1. **AZ_AZDPS DL scope inversion.** Devdoc's Basic list names `DriverLicenseQuery`; the build implements
   the out-of-Basic `AzAzdpsDriverLicenseQuery` and skips the Basic one (which alone supports images).
   Boat has the same fork and builds the Basic one, so DL is the lone inversion. Rewires Person.

**Residual gaps -- recorded, NOT owed, do not "discover" again:** `VEHICLE_BODY_STYLE|NJ_NIBRS` uniform
across all 20 QRDMs vs CLAUDE.md's "CA=VEHICLE" -- **HYPOTHESIS**, no repo artifact can settle it |
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