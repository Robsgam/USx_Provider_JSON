---
name: usx-deploy
description: Use when importing a provider JSON into a tenant and PROVING it landed — "deploy", "import to <tenant>", "push v<X.Y> to <tenant>", "verify the import", "did the import work". Covers the import-then-export-then-compare loop: the read-only import plan, the before-snapshot that makes proof possible, the manual-import-first sequencing, and the content-hash acceptance test that a label check and a byte compare both get wrong. Trigger on any request to install a JSON on a tenant or to confirm one installed. NOT for building a JSON (usx-build) and NOT for tenant query testing (usx-test-iterate).
---

# USx Deploy — import, export, prove

Rob's goal, 2026-09-11: *"the idea is for the tool to eventually execute the imports, then run
an export, then compare the 2 to confirm the json update takes place"* and *"maybe a skill that
imports and runs the export o check what the actual cversion is with proof."*

**There is deliberately NO write path in this repo yet.** `Import JSON` is on the extension's
DESTRUCTIVE denylist, `admin_probe.js` is GET-only by construction, and the separation is
Rob's own call: *"maybe we just leave this tool as the auditor and generate another tool only
for deployment with safe guards."* This skill is the procedure that works **today with a manual
import**, and is the contract any future deployment tool must satisfy.

## Step 0 — THE ORDER MATTERS: verify a MANUAL import before automating anything

Do the first import **by hand in the tenant UI** and let the tooling prove it. Not caution for
its own sake — sequencing:

> **If the verifier cannot prove a manual import landed, it certainly cannot verify an
> automated one.** Automating the write first means debugging two unproven halves at once, and
> the half that matters for safety is the one that says "this worked".

A manual import also needs no new safeguards, no denylist exception, and no decision about
clicking `#do-import` from script.

## Step 1 — Plan it, read-only

```
tools\report_import_plan.ps1                      # everything
tools\report_import_plan.ps1 -Provider FL_FCIC    # one provider
```

**It plans on CONTENT, not labels, and that is the whole value.** Planning off bundle
descriptions would have queued four tenants that need nothing (`usx-hi-hcjdc-ofml` label v4.19 /
content == repo v4.20; both NY tenants label v4.24 / content == v4.26; `usx-or-leds` label v2.5 /
content == v2.6). Each would be a **no-op import that archives a test package and burns a full
re-test cycle**.

It names, per row, **which bundles would change**. ⚠️ But the FL import on 2026-09-11 showed
the import REPLACES the bundle set rather than merging: the tenant's CA_eSUN bundle was REMOVED,
not left alongside. So a partial file would presumably delete whatever it omits. Treat the
per-row bundle list as "what will differ afterwards", not as "only these will be touched".

It will NOT queue a `NOT-OUR-BUILD` config. Overwriting a config we did not author is a
different decision and needs a human.

## Step 2 — CAPTURE THE BEFORE, or there is no proof

```
extension button "6b. PULL THE CONFIGS"   with ONLY the target deptId in the box
tools\ingest_tenant_configs.ps1
```

⚠️ **THIS IS THE STEP THAT GETS SKIPPED AND IT IS THE ONE THAT MAKES THE REST MEANINGLESS.**
`verify_tenant_import.ps1` reports **UNPROVEN** without a before-snapshot, and it deliberately
refuses to fall back on "AFTER matches REPO, therefore it worked" — a tenant **already** at the
target version satisfies that with no import having happened at all.

`ingest_tenant_configs.ps1` archives the prior config to `_versions\tenant_exports\_before\`
**only when the re-pull differs**. So a BEFORE exists only if the tenant was pulled *both* before
and after. Pull first.

## Step 3 — Import

**AUTOMATED as of 2026-09-11.** Panel section `DEPLOY`, two buttons: `DRY RUN` then
`EXECUTE THE IMPORT`. Needs `serve_plans.ps1` running.

**THERE IS NO PROVIDER BOX. Do not add one back.** Rob: *"typing fcic in tath window is not right
you should already know what the tenatn is supposed to be based on my direct input intitally since
you ahve not deployed any on your own."* It was a hazard, not friction — a typo there imports the
WRONG PROVIDER and **every guard still passes**: valid version-stamped build, right deptId, matching
modal field. Nothing compared the payload's provider to the tenant's intended one because nothing
knew it. Now `GET /target/<deptId>` answers that from the repo record, in a stated authority order:

| source | means |
|---|---|
| `explicit-map` | `intendedProvider` on the tenant's `tenant_map.json` row |
| `usx-subdomain` | the `usx-<slug>` subdomain, which encodes it by construction |
| *(neither)* | **409 REFUSED** — an unrecorded tenant is not a deploy target |

⚠️ **The INSTALLED bundle is never the authority**, only context. `usx-fl-fcic` is the proof: it was
carrying a **CA_eSUN** bundle, so "what is installed" names exactly the wrong provider on the one
tenant we deployed to first. Intent comes from the record; the install is what we are correcting.

Two consequences worth knowing: a supplied provider is treated as an **assertion to check** (mismatch
→ refuse, so a typo becomes a refusal), and `tenantStatus` now comes from the record — it used to be
a caller-supplied field, which meant the LIVE guard was armed only by an operator who volunteered the
status, i.e. **disarmed by default on exactly the tenants it protects** (`hawaii-dle` is LIVE).

The three controls, by id:

| id | label | |
|---|---|---|
| `#import-dept-btn` | Import JSON | opens the dialog |
| `#import-from-file-btn` | Browse… | picks the file (unused — we set the textarea) |
| `#do-import` | **Import** | **executes** |

### ⚠️ THE DEPT-ID FIELD IS POPULATED *AFTER* THE MODAL RENDERS. Wait for it.

The first dry run refused with `could not identify the modal target field unambiguously`, and that
message was **wrong about its own cause**. The measured modal holds only three inputs
(`#import-dept-id-input`, `#import-file-name`, `#import-file`), so the original heuristic — scan
non-file inputs for a `/^\d{3,}$/` value, require exactly one — had no competing candidate and
should have matched. It found **zero**: the page's own jQuery (`fsRequest` → `loadDepartmentBundles`)
fills that field a beat after the modal appears, and we opened and read in the same breath.

Resolving by id alone would have fixed only the wording — an empty field still fails the
target-agreement guard. `openImportModal` now waits on `targetReady()` (field present **and**
non-empty) and distinguishes "modal never rendered" from "modal rendered, dept-id never populated".

**The harness missed this because its fixture was invented, not measured** — one anonymous
`<input type="text" value="69510828830">`, i.e. exactly the shape the heuristic was written for. It
scored 20/20 while the real page refused. `audit_deploy_guards.ps1` now builds the DOM from
`usx_admin_dialog_*.json` and asserts the resolver's **own return value** rather than driving it
through `runGuards` (where a null field and a mismatched field both produce a refusal, so broken and
fixed score identically). Verified by reverting the heuristic: **2 BROKEN / 27**.
## Step 4 — Export again and PROVE it

```
extension button "6b. PULL THE CONFIGS"   again, same single deptId
tools\ingest_tenant_configs.ps1
tools\verify_tenant_import.ps1 -Tenant usx-fl-fcic
```

**The verdict is CONTENT HASHES, never a version string.** Three things are compared per bundle:
BEFORE (archived) / AFTER (fresh pull) / REPO (the build we meant to install).

| Verdict | Means |
|---|---|
| `PASS` | content CHANGED **and** every comparable bundle now matches the repo build |
| `THE IMPORT DID NOT LAND` | every bundle byte-identical to BEFORE — **whatever the label says** |
| `LABEL-ONLY CHANGE` | description moved, content did not. Counted as FAILURE |
| `UNPROVEN` | no BEFORE archived. Not a pass |
| `FAIL` | changed, but does not match the repo build — *worse than unchanged, because it looks like success* |

## The two traps that make the naive checks wrong

1. **A LABEL CHECK PASSES ON A NO-OP.** The version rides in a bundle *description* and imports
   are per-bundle, so a tenant can end up with a new description over unchanged content — or the
   reverse. Four tenants were carrying stale labels over current content on 2026-09-11.
2. **A RAW BYTE COMPARE FAILS ON A CORRECT IMPORT.** The platform re-serializes on export,
   emitting `"conditions":null` / `"defaults":null` where our build omits the property (+324
   bytes on one AZ bundle). A 246KB export and a 928KB repo JSON at the *same* version are
   expected to differ; only equality would be surprising.

Both are avoided by `tools\_bundle_identity.ps1` — description excluded, platform nulls
normalized. **Any future deployment tool MUST use that module or it will report failure on a
successful import.**

## Safeguards the future deployment tool must carry

Ordered by how much each actually prevents, not by how good it sounds:

1. **Consume a saved plan file, never a live decision.** Plan → review → execute *that* plan.
2. **Pre-flight per tenant: re-export and confirm the BEFORE still matches the plan.** Abort the
   row if it changed — this is what stops us overwriting someone else's concurrent change.
3. **Refuse if no BEFORE is on disk.** No baseline, no import; rollback must be possible.
4. **Dry-run by default.** `-Execute` required.
5. **Explicit deptId list per run. No `-All`, ever.**
6. **LIVE tenants gated separately** — typed confirmation naming the tenant, never batched with
   test tenants. `hawaii-dle` is LIVE.
7. **One tenant before any batch**, per provider+version.
8. **Automatic blocking acceptance test** — step 4 above, on content.
9. **Structural refusal on NOT-OUR-BUILD and on `tenant_scope.json` exclusions.**
10. **A committed audit log per attempt:** tenant, deptId, from, to, before-hash, after-hash,
    verdict, timestamp. That is the ledger input.
11. **Abort control**, as the census has.

## The first subject: `usx-fl-fcic` — and why it is a good one

Rob, 2026-09-11: *"we can test it with fl then run the auditor to be sure it worked"* /
*"the usx fl tenant nto all florida tenants"*.

`usx-fl-fcic` (deptId **69510828830**, status TEST) currently carries a **CA_eSUN bundle with
only 2 bundles — no RMS at all** — matching **no build of ours**. So:

- it is `usx-*`, satisfying Rob's own standing rule to refuse any host that is not;
- there is **no tuned customer config to clobber**, which is the main risk of a first import;
- the import is also a **fix** — our FL test tenant should carry FL_FCIC, not eSUN;
- the outcome is **sharply verifiable**: 2 bundles → 3, and the provider bundle must hash-match
  repo `FL_FCIC v7.24`;
- a BEFORE is already on disk (245,253 bytes).

⚠️ `report_import_plan.ps1` does **not** list it, correctly — it is `NOT-OUR-BUILD`, and that
class is refused by default. Importing here is a **human override of that refusal**, which is
exactly the kind of decision the refusal exists to surface rather than make.

## Ledger

The tooling **reports deltas and does not touch `IMPORT_LEDGER.md`** — hand-authored, Rob's
source of truth: *"i will help align them with our ledger as needed."* After a verified import,
hand him the before/after hashes and the verdict; he updates the ledger.

## Verification

```
tools\report_import_plan.ps1 -OutFile providers\IMPORT_PLAN.txt   # queue, before
tools\verify_tenant_import.ps1 -Tenant <name>                     # exit 0 ONLY on a real PASS
tools\audit_tenant.ps1 -Tenant <name>                             # the dossier, after
```

`verify_tenant_import.ps1` exits **1** on UNPROVEN, DID-NOT-LAND, LABEL-ONLY and FAIL — so it
can be chained without reading the prose. Its three verdict paths were each exercised against
replica fixtures (`-TenantDir`) rather than by mutating the live export directory.
