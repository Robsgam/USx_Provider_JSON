# HELD: tenant deployment work — the resume record

> **Rob, 2026-09-14: "HOLD ALL THIS AND BE SURE WE CAN RECOVER AT THIS POINT   we need to pivot to a
> new provider."** This file is that recovery point. Nothing below is half-applied: every change is
> committed, every gate is green, and the one outstanding action is a single operator click.
>
> It lives here rather than in `SESSION_STATE.md` because that file has a hard 120-line gate and is a
> *pick-up point*, not a work order. Squeezing a recovery record into a line budget is how detail gets
> dropped — and dropped detail is exactly what "be sure we can recover" forbids.

## The one outstanding action

**Newark Foundation is staged and one click from done.**

```
tenant   newarkpd-foundation      deptId 68055618928      status TEST (not LIVE)
runs     NJ_NJCJIS v4.16          repo/catalog/ledger all say v4.17
job      job-20260912-215904      v4.16 -> v4.17, changes ENTITIES + NJ_NJCJIS
url      https://newarkpd-foundation.mark43.com/rms/api/support/admin/departments/configurations/68055618928
```

**To finish it:**

1. `tools\watch_imports.ps1 -Once -DeptId 68055618928` (background — it notifies)
2. Open the url above → USx panel → **DEPLOY** → **RUN THE JOB FOR THIS TENANT**
3. The panel re-exports automatically; the watcher ingests and runs `verify_tenant_import`
4. Expect: `ENTITIES` and `NJ_NJCJIS` both CHANGED and both `== REPO`; `RMS` unchanged, already equal

**Preconditions already satisfied** — do not redo these:

- `intendedProvider: NJ_NJCJIS` is recorded on Newark's `tools\config\tenant_map.json` row. This is a
  deliberate override of the standing rule that the deploy path refuses any host that is not `usx-*`;
  the authorisation, date and evidence are in `_intendedProviderWhy` on that row. `/target/68055618928`
  resolves with `source: "explicit-map"`.
- The job is cut and still accurate. `expectBundlesNow` = `ENTITIES, NJ_NJCJIS, RMS`, so the browser
  refuses the row if the tenant has moved since.
- No prior Newark `_before` archive exists, so the current v4.16 extract becomes the BEFORE cleanly
  when the post-import pull lands. The proof will be a real three-way comparison.
- TEST status, so **no `liveConfirmed`** is required.

## Why we are confident Newark is on v4.16 — five independent signals

Rob pushed back on this specifically (*"are you absolutely sure ... this is why i wanted to create
this tool and mechanish to audit the live deployments"*), and the pushback was right: the original
claim rested on a day-old snapshot. He re-pulled, and it held.

| Signal | Evidence |
|---|---|
| Bundle description | reads `Provider configuration for NJ_NJCJIS v4.16` |
| **Content hash** | `ENTITIES 42b4bc4136c5` and `NJ_NJCJIS 2508b97924d7` equal the **v4.16** build pulled byte-exact from git, and differ from v4.17 (`00110ec90371` / `a7415fdd4e71`) |
| Control on that test | ENTITIES and NJ_NJCJIS genuinely **differ** between v4.16 and v4.17, so the comparison could have come out the other way. RMS is identical in both and cannot discriminate — stated rather than hidden |
| Repetition | three captures — `2026-09-11 14:10Z`, `19:06Z`, `2026-09-13 04:12Z` — all payload SHA `E8A370D0ABB66B1A`, 201,627 bytes |
| Same-sweep control | in the *same* sweep `usx-nj-njcjis` read **v4.17** correctly, and Newark's config hash is unique to Newark — so neither a systematic misread nor an iframe mix-up |

Platform counter corroborates independently: **77** on Newark vs **78** on our v4.17 provider tenant
vs **74** on Anzini at v4.9 — ordered exactly as the versions are.

**What it costs while unfixed:** v4.16 → v4.17 is the middle-name + suffix fix. A Newark officer
cannot enter either on a Driver License search; the wire can only carry `DOE, JOHN`.

## ⚠️ The open question that matters more than the import

**Why did the 2026-08-20 import not land?** The ledger records it as completed in the same pass as the
DEX-988 release line and the catalog update — and Rob confirmed on 2026-09-14 that **v4.17 IS in the
catalog**. So two of the three actions in that pass demonstrably happened and the third did not, while
all three were recorded as done.

Re-importing fixes the tenant. It does not explain the gap, and the same failure could be sitting on
any import reported from memory rather than from an export. The **six unrecorded installs** below
suggest the *recording* step is where this leaks.

## Also held — all Rob's decisions, not code

1. **Scoping.** `tools\config\tenant_scope.json` ships EMPTY by design (nothing is excluded until Rob
   says so), so an `-All` job still queues `amyblair` and `onscene`, which he has already said will be
   excluded. `providers\TENANT_GROUPS.pdf` is the document to mark up; the candidate groups are in the
   scope file's `_candidates` block as a proposal only.
2. **`providers\LEDGER_PATCH.md`.** 16 content-verified tenants have **no ledger row** (every `usx-*`
   fleet tenant among them); 8 more appear only in Section B.0, which records no version by design.
   **0 contradictions** where the ledger does state a version — except Newark. The tool never writes
   the ledger.
3. **`hawaii-dle` is LIVE**, queued with `liveConfirmed: false`. Armed only by hand, in the job file.
4. **The batch.** *"update all fl_fcic tenants … i would have to launch it."* The seam is threaded
   (`doc` through every DOM read in the write path; 6 iframe cases prove it) but **nothing batches
   yet**. The five preconditions are at the foot of `automation\extension\deploy_probe.js` under
   `DESIGN TARGET`.
5. **Confluence output** — last, and with per-publish approval.

## Sync state across all providers, as measured 2026-09-13

- **1 ledger contradiction:** Newark (v4.17 claimed / v4.16 measured)
- **6 unrecorded installs:** `amyblair` FL v7.18 · `onscene` HI v4.15 · `lakewoodoh-foundation` OH
  v2.11 · `ny-nycapss-foundation` NY v4.26 · `qa-amyblair-test` + `qa-amyb-test` IL v2.8
- **1 reverse gap:** ledger row *"Albany County NY Foundation"* v4.26 matches **no tenant** on this host
- **5 tenants genuinely behind** besides Newark: `amyblair`, `hawaii-dle`, `hdle-foundation`,
  `onscene`, `practice-bertanzini`
- **All 16 `usx-*` provider tenants are current.** The tenants we test on need nothing.

## Environment to restore

- `tools\serve_plans.ps1` on port **8477** — serves `/job`, `/target/<deptId>`, `/build/<PROVIDER>`,
  `/plan/<P>`, `/scope/<P>`. Start it before using the panel; a stale instance from a previous day has
  served pre-change code before, so check the process start time if anything reads oddly.
- No watcher running. The last one timed out cleanly having proven nothing, which is the correct
  report rather than a pass.
- `tools\install_git_hooks.ps1` — pre-commit blocks a commit that breaks extension JS or `tools\*.ps1`.
  Re-install after a fresh clone; `.git\hooks` is not version-controlled.

## Reports that describe all of this

Regenerate them all with `tools\refresh_tenant_reports.ps1` — it owns the set, uses the newest tenant
export as a data clock, and verifies each rewrite by write time rather than `Test-Path`.

`IMPORT_PLAN.txt` · `TENANT_PROVENANCE.txt` · `LEDGER_PATCH.md` · `TENANT_GROUPS.html/.pdf` ·
`NOTOURS_REUSE.txt` · `NOTOURS_IDENTITY.txt` · `LEDGER_VS_REALITY.txt` · `TENANT_BUNDLE_VERSIONS.txt` ·
`TENANT_SCAN_REPORT.txt` · `TENANT_VERSION_REPORT.txt` · `TENANT_CONFIG_REPORT.txt`

⚠️ `IMPORT_LEDGER.md` and `TENANT_INVENTORY.md` are **hand-authored** and are never regenerated.
