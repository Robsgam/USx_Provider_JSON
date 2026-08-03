# SESSION STATE — where we are RIGHT NOW

> **This file is the pick-up point.** It is injected into every new session by the SessionStart
> hook, and it is committed to git so it can never drift from the code it describes.
>
> **Rules for whoever edits this (including future me):**
> 1. **CURRENT STATE ONLY.** No history, no changelog, no "prior — v4.12 did X". History lives in
>    git and in `providers/<P>/docs/tracking/CHANGELOG_<P>.md`. If you find yourself appending a
>    dated section, you are doing it wrong — *replace* the content instead.
> 2. Keep it under ~80 lines. If it grows past that it stops being read, which defeats the point.
> 3. Update it **in the same commit** as the work it describes. A stale state file is worse than none.
> 4. Numbers here must be derived, not remembered — run `tools\portfolio_status.ps1` and
>    `tools\enforce.ps1`.




<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-03 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.23 | ALL-PASS (89 logs) |
| FL_FCIC | v7.17 | NEVER-TESTED -- 116 test(s) owed |
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

## STATE

**18 of 20 ENFORCED 0 FAIL / 0 WARN** (full sweep, measured). BLOCKED: LA_LEMS + CA_CONTRA_COSTA above.
The CC block is a GATE getting stricter, not a provider getting worse -- do not loosen it back.

**ENFORCED is not "done". Only FIVE are tenant-tested:** TX v4.18, NY v4.19, NJ v4.15, HI v4.14,
CA_CLETS v2.23 (324 logs, four log gates green). **15 are ENFORCED but NEVER swept** -- the whole
remaining backlog. FL_FCIC left the verified set deliberately (now v7.17); its 109 logs are archived.
Also bumped and un-swept: OR_LEDS v2.2, CA_CLETS_OCATS v2.3, CA_SAN_LUIS_OBISPO v2.3.

Invariants currently held: devdoc-UNBUILT 2 (both LA_LEMS) | wiring closure 0/9 classes |
audit_metadata 20/20 clean | gate efficacy 10/10 KILLED | portability 260 cells 0 unportable |
fidelity fixture 116 branches 0 UNDER 0 OVER | spec-plan NO-FIRE 24.

**The gate stack changed a lot on 2026-08-02/03.** Do NOT re-derive it: the SessionStart decision-trail
hook prints the recent commit subjects and the self-correction lines from their bodies, and
`git log -n 40` has the full reasoning. New: enforce **PHASE 2t** wiring closure (BLOCKING),
PHASE 1 **ancillary/render currency** (WARN), zero-comparison devdoc FAIL, fidelity
**UNSATISFIED-CLAIM**, `emit_decision_trail.ps1`, and skill **`usx-adjudicate`** (8 skills).

## OPEN DECISIONS -- Rob's call, do not settle unilaterally

1. **AZ_AZDPS DL scope inversion.** Devdoc's Basic list names `DriverLicenseQuery`; the build implements
   the out-of-Basic `AzAzdpsDriverLicenseQuery` and skips the Basic one (which alone supports images).
   Boat has the same fork and builds the Basic one, so DL is the lone inversion. Switching rewires
   Person entirely.
2. **NCIC-number-keyed combos:** BUILT on TX/FL, REGISTERED-unbuilt on OH_LEADS, all three devdocs list
   them Basic. Either OH has a real 2-combo gap, or TX/FL carry redundant surface (removing bumps TX and
   archives its 89 logs).

## NEXT PHYSICAL ACTION

**TENANT TESTING** -- 15 never-swept providers, via `test_phase2.ps1 -Provider <NAME>` then `-PostIngest`.
Entry point **verified working 2026-08-03** on TX (89 plan tests), MD (42) and AZ (53): 0 tests that
cannot fire, spec plan covering every entity. Nothing else in PHASE 1 is owed but the 2 decisions above.

**Residual gaps -- recorded, NOT owed, do not "discover" again:** `VEHICLE_BODY_STYLE|NJ_NIBRS` uniform
across all 20 QRDMs vs CLAUDE.md's "CA=VEHICLE" -- marked **HYPOTHESIS** there because QRDM lookups
resolve platform-side and NO artifact in this repo can settle it | fidelity advisory 11 UNDER / 40 OVER
(none on the fixture; adjudicate with `usx-adjudicate`) | CCH spec-plan name divergences |
`audit_devdoc_optionals`/`audit_log_content` can FLAKE under parallel load -- re-run a lone odd FAIL
alone before believing it.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Most now live in the skills, with the concrete case attached: `usx-adjudicate` (validate the probe;
fix vs register), `usx-metadata` shape 6 (transaction-level agreement is not variant-level),
`usx-tooling` 5b (verify the artifact before fixing the gate) and 5c (mutation footprints).
What must be in front of you before you touch anything:

- **NEVER cite another provider as authority.** Only `CA_CONTRA_COSTA`->`CA_CLETS` and
  `<BASE>_<VARIANT>`->`<BASE>`. CA_CLETS and CA_VENTURA_COUNTY share an `IR.QVC{Name}` combo requiring
  OPPOSITE things. Ask "what does X's OWN authority require?"
- **A step that did not run is NOT a pass.** Print the denominator. A gate can pass vacuously, go MUTE
  (no verdict line), or FLAKE under load -- all three read as green, and all three happened this week.
- **A finding repeated across MANY providers is almost always YOUR PROBE** (100 / 67 / 25 / 6 false
  findings in two days, every one my own canonicalisation or name-space error).
- **When you add a gate, add it to EVERY harness** -- fuzz panel, portability sweep, efficacy catalogue
  -- not just `enforce`. Missed twice in one day.
- **MUTATION ORDER: mutate -> restore -> RE-STAMP -> verify -> commit.** `git status` clean is necessary,
  not sufficient.
- **Multi-line `.Replace()` no-ops on CRLF -- use the Edit tool.** **Verify the emitted filename after a
  version bump.** **Document a new tool in the SAME action** (CLAUDE.md + KB README + count).
- **REPLACE this file's content, never append.** The line gate has now caught me THREE times.