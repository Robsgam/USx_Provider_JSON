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
**Last updated:** 2026-07-30 (generated) · **Branch:** `main`

## Tenant-test state — GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.22 | ALL-PASS (90 logs) |
| FL_FCIC | v7.12 | ALL-PASS (111 logs) |
| HI_HCJDC_OFML | v4.14 | ALL-PASS (46 logs) |
| NJ_NJCJIS | v4.14 | ALL-PASS (35 logs) |
| NY_NYSPIN_EJUSTICE | v4.17 | NEVER-TESTED — 67 test(s) owed |
| TX_TLETS | v4.18 | ALL-PASS (89 logs) |
| _14 others_ | — | never tenant-tested: AZ_AZDPS, CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 — `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## ▶ NEXT PHYSICAL ACTION

**TX v4.17 re-sweep is owed from T1** (~85 tests; the v4.16 logs were archived by the bump).
v4.17 removed the QV{Plate}/QV{VIN} metadata shadows; v4.18 fixed 17 dropped devdoc optionals (BirthDate on CPL, FRT on DPSI), restoring Rob's binding v4.9 ruling after
they were re-added in error at v4.14 — Vehicle is 5 combos, 19 total. Then **NY v4.17** (also from
T1, never started). Order after: NJ, FL, then CA_CLETS, HI. Everything outside those 6 is TABLED.

**Standing rule that cost three versions to relearn:** QV and QW are PLATFORM-AUTO-FIRED metadata
shadows, NOT devdoc in/out combinations — never build them, and never "restore" them alongside a
genuine prefill-dead fix. RQ{Plate}/RQ{VIN} are the OPPOSITE case (real devdoc "(OutofState)"
paths) and STAY built. `audit_query_trace` reporting QV [MISSING] is EXPECTED; see
TX_TLETS_ACCEPTED_DIVERGENCES rule `metadata-shadow-autofired`.

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

1. **NY v4.17 re-test** (~67 tests, from T1). Step 1 is the empty-`set[]` metadata parser question
   flagged `NY-METADATA-PARSER-UNKNOWN` — resolve that before trusting NY's query-trace verdict.
2. **31 PREFILL-DEAD combos remain** (CA_CLETS 12, CA_CONTRA_COSTA 12, HI 2, OH_LEADS 1) — each
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
