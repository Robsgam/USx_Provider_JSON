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
**Last updated:** 2026-07-31 (generated) · **Branch:** `main`

## Tenant-test state — GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.22 | ALL-PASS (90 logs) |
| FL_FCIC | v7.14 | NEVER-TESTED — 109 test(s) owed |
| HI_HCJDC_OFML | v4.14 | ALL-PASS (46 logs) |
| NJ_NJCJIS | v4.14 | ALL-PASS (35 logs) |
| NY_NYSPIN_EJUSTICE | v4.19 | ALL-PASS (64 logs) |
| TX_TLETS | v4.18 | ALL-PASS (89 logs) |
| _14 others_ | — | never tenant-tested: AZ_AZDPS, CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 — `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**TX_TLETS v4.18 is the solid one and needs nothing.** ALL-PASS 89/89, enforce 39 PASS/0 FAIL/0 WARN,
gate efficacy KILLED 16/16, requirement fidelity 0/0, 0 over-broad suppressions. Do not re-sweep it.

**Rob's call on NY before its 67-test sweep.** NY v4.17 Vehicle has two recorded metadata-fidelity
findings (`RVEHOUT` demotes two mandatory fields; `RVEH` over-permits `LicensePlateYear`). Rob PARKED
the ruling 2026-07-30. The cost of sweeping first: fixing them later bumps to v4.18 and archives all
67 fresh logs. Settling it first costs one build. See NY PENDING_UPDATES.txt "[OPEN 2026-07-30]".

Order after NY: NJ, FL, then CA_CLETS, HI. Everything outside those 6 is TABLED.

**Run the `usx-resume` skill before acting on this.** It sweeps for environment state this file
cannot see (captures stranded in Downloads, stray `watch_captures` processes, a build script bumped
but not rebuilt). Do not start a bump, a sweep, or a Jira comment on your own initiative after a
restart — Rob may have done things in the gap.

## Gate status

Run `tools\enforce.ps1 -SkipGit`. **Expect `0 FAIL / 0 WARN`.** That is the invariant.

Do NOT record the PASS count here. It grows every time a gate is added (it moved 427→430 within an
hour of this file being created, purely from new gates), so an absolute number is guaranteed to go
stale and teaches the next session to distrust the file. `0 FAIL / 0 WARN` is the only durable
assertion. If you get a FAIL or WARN, the tool is right and this file is out of date.

## What is actually owed

1. **NY v4.17 re-test** (~67 tests, from T1). The `NY-METADATA-PARSER-UNKNOWN` flag is RESOLVED
   (nested `<Choice><Set>`; NY's DriverHistory build is metadata-exact). Two Vehicle fidelity
   findings remain OPEN awaiting Rob -- settle them before spending 67 tests.
2. **170 over-broad divergence suppressions across 14 providers** (`tools\audit_suppression_scope.ps1`).
   Every accepted divergence buys a blind spot; TX_TLETS is at 0 via the
   `# SUPPRESSION-SCOPE: direction-aware` marker. Add the marker at each provider's own rebuild turn,
   never as a sweep -- narrowing can turn a green provider red. TX_TLETS_CCH (29) is the natural next.
3. **CA_CLETS has a REAL shipped defect**, flagged `[UNDER-REQUIRED-CHOICE-BRANCH]`: `IG.QGH` needs
   `purposeCode+Name+(Age OR BirthDate)`, both discriminators were built optional, and a committed
   PASS log shipped with neither. Two independent gates agree. Fixed at CA_CLETS's turn.
4. **31 PREFILL-DEAD combos remain** (CA_CLETS 12, CA_CONTRA_COSTA 12, HI 2, OH_LEADS 1) — each
   already flagged in its own PENDING_UPDATES.txt, fixed at that provider's turn. **BUILD_RULES 24**
   is the rule; `enforce` PHASE 2n is the gate. Removing a prefill is what RESTORES the combo —
   never delete a devdoc-supported combo that only our own default made unreachable.
3. **Jira: HOLD.** Rob's instruction 2026-07-29 — do **not** comment on DEX-1283 (TX) or DEX-1284
   (NY), and hold the regular per-provider Jira update **until after testing**.
4. **AZ_AZDPS v3.3** — never tenant-tested. Before its first sweep, confirm on the **first query**
   that the platform populates `dexStateUserId`, or all 5 badge combos silently fall back to
   DQN/BQ/BQH.
5. **4 providers have no devdoc text extract** → NJ, FL, LA_LEMS, CA_CLETS_OCATS were fixed
   2026-07-29; if `audit_structure` CHECK 9b warns again, run
   `pdftotext source/<P>.pdf source/<P>_DEVDOC.txt`.

## Open decisions (Rob's, do not decide these yourself)

- **NY home-state strip / DEX-1284.** Only config lever is removing `RegistrationState` from NY's
  CAD layout variants, which would stop an officer running an out-of-state plate from a CAD event.
  **BUILD_RULES §23 forbids that trade.** Correct fix is the injection layer. Not started.
- ~~Branch merge to `main`~~ — DONE 2026-07-30 (fast-forward, no merge commit).
- **LA_LEMS `DQ`** and **TN_TIES prose divergence file** — Rob: "handled when we get to them."
  Do NOT re-raise as open issues; both leave enforce green.

## Hard-won rules you will otherwise re-derive (read before touching routing or tests)

- **BUILD_RULES §20** — first-match firing + union pool; dead combos; a log cannot prove which
  combo fired. **§21** — the firing model is LIVE-PROVEN, do not re-derive it. **§22** — one
  provider per tenant, so cross-provider cosmetic drift has zero customer value (freeze & ship).
  **§23** — form queries first; CAD injection never takes precedence; DH cannot work from CAD
  injection at all (DH-suffixed fields).
- **`knowledge-base/UNIVERSAL_SEARCH_HANDLERS.txt`** is the authoritative platform handler
  registry. `RULE_HANDLERS.txt` only documents what we already build — checking only that file
  produced a wrong "no such handler exists" answer on 2026-07-29.
- **Never hand-edit a provider JSON.** Edit the build script; `enforce` rebuilds and compares.
- **Any version bump resets that provider's whole test package.** Weigh every cosmetic change
  against a full tenant re-sweep of Rob's hands-on time.
- `pdftotext` **is** available at `C:\Program Files\Git\mingw64\bin\pdftotext.exe` (not on PATH).
- `pwsh -File` **stringifies** array/hashtable args — `-Providers a,b` and `-Override @{}` fail
  that way. Call the script in-session instead.
