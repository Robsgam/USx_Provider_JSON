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

Today: **by hand**, in the tenant's configuration UI. The three controls, by id:

| id | label | |
|---|---|---|
| `#import-dept-btn` | Import JSON | opens the dialog |
| `#import-from-file-btn` | Browse… | picks the file |
| `#do-import` | **Import** | **executes** |

### RESOLVED 2026-09-11 — the dialog was MEASURED, not guessed

Captured with the panel's `Capture THIS page` button (live-DOM read, clicks nothing), file
`usx_admin_dialog_*.json`:

| element | id | container | state |
|---|---|---|---|
| **TEXTAREA** | **`#import-json`** | `#import-modal` | **visible, NOT readonly** — THE PAYLOAD FIELD |
| INPUT file | `#import-file` | `#import-modal` | hidden, `accept=application/json,.json` |
| TEXTAREA | `#export-json` | `#export-modal` | readonly — where Export JSON puts its content |
| BUTTON | `#import-dept-btn` / `#import-from-file-btn` / `#do-import` | | open / browse / **execute** |

**So automation is feasible, and by the easy route.** Set `#import-json`.value directly — no
file picker, no `DataTransfer`, no OS dialog that page JS cannot drive. The hidden
`#import-file` input is a workable fallback (a real file input *can* be populated via
`DataTransfer`), but the textarea is strictly better: no file handling, and the payload can be
inspected before submitting.

⚠️ **ONE THING MEASURED-BUT-NOT-OBSERVED:** the capture caught `#import-json` with
`valueLength=0` — the dialog was open but empty. So the field is confirmed to EXIST and be
WRITABLE; it has not been *seen* receiving the file's contents. Rob's description ("it fills the
window with the contents of the json") plus the id sitting beside `#import-file` in the same
modal makes it near-certain. Confirm it by capturing once WITH the file loaded before writing
code that depends on it.

⚠️ Note why the existing tools could not answer this: `enumerateControls` queries only
`a, button, input[type=submit|button], [role=button]`, so a file input or textarea is invisible
to it — and button 4 reads a fresh hidden IFRAME, where the dialog is closed. The capture had to
read the LIVE `document`.

**Sketch of the write path, for when it is authorised:** set `#import-json`.value → dispatch
`input`/`change` (this is Semantic UI / jQuery, so a plain value set may suffice, but dispatching
costs nothing) → **verify the dept-id field equals the intended target** → click `#do-import`.
That dept-id field is a gift: the import target is an explicit, readable value, so a pre-flight
can assert it rather than trusting "whatever page we are on".

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
