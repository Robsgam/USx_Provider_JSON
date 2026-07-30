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

**Last updated:** 2026-07-29 · **Branch:** `rebuild/az_azdps_v3.0` (184+ ahead of `main`, unmerged
by choice — `main` stays at the last tenant-tested state)

---

## ▶ NEXT PHYSICAL ACTION

**Nothing is in flight. Waiting on Rob.** Last session ended deliberately, tree clean, all pushed.

When Rob is ready, the queue is: **NY v4.17 re-test** and **TX v4.13 re-test** (both reset by their
bumps, both from T1). Neither has been started — no partial sweep to resume.

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

## Tenant-test state (derive it: `tools\portfolio_status.ps1`)

| Provider | Ver | State |
|---|---|---|
| HI_HCJDC_OFML | v4.14 | ALL-PASS |
| NJ_NJCJIS | v4.14 | ALL-PASS |
| FL_FCIC | v7.12 | ALL-PASS (Boat re-run 2026-07-29, 47 captures) |
| CA_CLETS | v2.22 | ALL-PASS |
| NY_NYSPIN_EJUSTICE | **v4.17** | **re-test owed from T1** (DH row split — bump reset it) |
| TX_TLETS | **v4.14** | **re-test owed from T1** (2 dead RQ combos removed — bump reset it) |
| TX_TLETS_CCH | **v1.9** | never tenant-tested -- **BASE-SYNC STALE (base is v4.14), rebuild owed** |
| other 13 | — | never tenant-tested |

## What is actually owed

1. **NY v4.17 re-test** (67-ish tests) and **TX v4.13 re-test** (~77). TX's sweep absorbs the
   `QGNCICNumber` Firearm gap that was previously owed.
2. **Jira: HOLD.** Rob's instruction 2026-07-29 — do **not** comment on DEX-1283 (TX) or DEX-1284
   (NY), and hold the regular per-provider Jira update **until after testing**.
3. **AZ_AZDPS v3.3** — never tenant-tested. Before its first sweep, confirm on the **first query**
   that the platform populates `dexStateUserId`, or all 5 badge combos silently fall back to
   DQN/BQ/BQH.
4. **4 providers have no devdoc text extract** → NJ, FL, LA_LEMS, CA_CLETS_OCATS were fixed
   2026-07-29; if `audit_structure` CHECK 9b warns again, run
   `pdftotext source/<P>.pdf source/<P>_DEVDOC.txt`.

## Open decisions (Rob's, do not decide these yourself)

- **NY home-state strip / DEX-1284.** Only config lever is removing `RegistrationState` from NY's
  CAD layout variants, which would stop an officer running an out-of-state plate from a CAD event.
  **BUILD_RULES §23 forbids that trade.** Correct fix is the injection layer. Not started.
- **Branch merge to `main`** — what actually ships to a customer?
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
