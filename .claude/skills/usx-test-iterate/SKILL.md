---
name: usx-test-iterate
description: Use for live USx Tenant Testing of a provider (batch capture import from Downloads, one entity at a time), OR when a provider's devdoc/metadata XML has been updated and the existing JSON needs to be reconciled against the change. Covers the GATE 0-5 test protocol and the diff/audit propagation workflow. Trigger on "let's test <PROVIDER>", "here's the XML" (mid test loop), "the devdoc changed", "new metadata for <PROVIDER>", or "what changed vs current build".
---

# USx Test / Iterate / Metadata-Devdoc Update

Router over `knowledge-base/TESTING_REQUIREMENTS.txt` (the test-protocol source of truth) and
the diff/audit tools. Two halves below — use A for live tenant testing sessions, B when source
documents (devdoc PDF or metadata XML) changed for a provider that's already built.

## Part A — Live testing loop

**Why the capture package exists:** to strictly prove the CommSys query is 100% metadata-correct
and that every combination is logged and accounted for. That proof rests on TWO independent gates,
both in enforce PHASE 6, neither skippable:
- **6c `audit_log_content.ps1`** — each log's QUERY STRING satisfies its plan test's full fill-set;
  guardrails show winner-only wire (log ↔ JSON-derived plan).
- **6d `audit_log_metadata.ps1`** — each log's COMMSYS wire XML validated DIRECTLY against the
  metadata: every `<Request>` field is a metadata-defined field for that query, and the present
  field-set satisfies a real metadata combination's required `set[]` (log ↔ metadata). This is the
  direct check; do not treat the transitive metadata↔JSON↔plan chain as a substitute for it.

### A0. GATE 1 check, always first

Any version bump restarts testing from Test 1 — full stop, no resuming mid-matrix. Confirm
`logs/.test_version` (or legacy `tests/.test_version`) matches the provider's current JSON
version before touching anything. If it doesn't match, run:
```
tools/reset_test_package.ps1 -Provider <NAME>
```
(normally auto-run by `pipeline.ps1` right after a successful build — check whether that already
happened before running it again). This archives prior logs, resets every SQVR marker to
`[PENDING]`, clears STATUS live rows, and re-stamps the version.

### A1. Per-entity RENDER GATE

Before running any combo test for an entity, present and confirm that entity's RENDER test
PASSES first. This re-arms on every version bump — don't skip it because "it passed last
version."

### A2. Full-pass sequence (GATE 0 — all-or-nothing, no "Preliminary" tier)

For each entity, in order: render → every combo's required `set[]` fields → each combo's `any[]`
permutations → guardrail/priority tests (e.g. identifier-priority: does Plate really win over VIN
when both are entered?) → deselect tests (`queriesToDeselect` mutual exclusion actually
deselects) → one negative test (empty form, confirm no query fires).

### A3. Capture ingestion loop — AUTOMATED, never wait for the user

The user captures tests via a browser extension that downloads batch files to `~/Downloads/` as
`usx_captured_batch_labeled.json` (with numeric suffixes `(1)`, `(2)`, etc. for multiples).
`tools/import_captured_tests.ps1` reads these, infers combos from the XML, creates versioned test
logs, updates SQVR, and archives the batch file.

**Standing directives:**
- **Block by VERSION, not by entity.** Any version bump = retest ALL entities from scratch at the
  new version — the user re-sends every entity's captures, and the Chrome extension makes that
  cheap. Do NOT tell the user an entity "doesn't need re-capture because its fingerprint didn't
  change" (that older per-entity-preservation model is retired). A version is DONE only when every
  entity has current-version logs that pass both gates. If `reset_test_package` preserved some
  entities as "blocked (unchanged)", ignore that as a coverage excuse — expect and ingest a full
  re-send.
- **Proactive polling.** When the user says they're testing, downloading, or capturing — or when
  you've just imported one batch and more entities remain — immediately check `~/Downloads/` for
  new `usx_captured_batch_labeled*.json` files. Do NOT wait for the user to say "it's downloaded"
  or "process it". Check, and if nothing is there yet, say so briefly and check again after the
  user's next message.
- **Import immediately.** When a batch file is found: inventory it (count + entity/query/combo
  breakdown), import via `import_captured_tests.ps1 -InputFile <path> -Provider <NAME>`, report
  the result (N PASS / N FAIL), then immediately run `audit_test_coverage.ps1` to show remaining
  gaps.
- **No manual log creation.** Do not use `new_test_log.ps1` or `post_test.ps1` directly — the
  import tool handles the full pipeline (log creation, SQVR update, STATUS update, archival).
- **Entity unblocking.** If the user wants a full retest and entities are blocked in
  `.test_state.json`, reopen them (set status to "open", bump version to current) without asking.
  The user saying "retest everything" is sufficient authorization.

**Preferred mechanism — the supervised watcher.** Start `tools/watch_captures.ps1 -Once` as a
background task (the environment enforces a single watcher; kill any stale one first). It sweeps
Downloads, **relabels (content-match) → imports → commits+pushes → archives**, then exits `-Once`
which notifies you. Relaunch it after each batch so every page the user downloads auto-ingests and
you report the result without being prompted. Persistent (no `-Once`) watchers never notify and get
killed by the environment — always use `-Once` + relaunch.

**Ingestion is not complete until the batch is VALIDATED.** After each batch imports, run BOTH
log gates for the provider — do not wait for the final enforce to discover a bad capture:
- `tools/audit_log_content.ps1 -Provider <NAME>` — log ↔ plan fill-set.
- `tools/audit_log_metadata.ps1 -Provider <NAME>` — log ↔ metadata (every wire field metadata-valid;
  field-set satisfies a real metadata combo). This is the direct CommSys-correctness proof.
Report both results with the PASS/FAIL count. A green import with a failing gate is NOT ingested —
surface the delta (A5 discrepancy protocol) and resolve before moving on.

**Sequence per batch:**
1. Watcher (or manual): a batch lands in `~/Downloads/` as `usx_captured_batch_labeled*.json`
   (skip empty `[]`). Manual fallback if the watcher is down: `import_captured_tests.ps1 -Provider <NAME>`.
2. Inventory: report count + entity/query/combo breakdown.
3. Ingest: relabel + import (the watcher does this; or run `import_captured_tests.ps1`).
4. Report: N PASS / N FAIL / N skipped.
5. **Validate:** `audit_log_content.ps1` AND `audit_log_metadata.ps1` for the provider → report both.
6. Coverage: `tools/audit_test_coverage.ps1 -Path <json>` — report remaining gaps.
7. When all combos covered, 0 PENDING, and both gates green → proceed to A7 (GATE 5).

### A4. Standard sequence per query path (TESTING_REQUIREMENTS Section 12)

T1 minimum-required-only → T2 required + 1 optional → T3 required + all optional → T4 all form
fields present (confirm extras beyond this combo's pool are ignored, not silently sent) → T5
out-of-state variant.

### A5. Discrepancy protocol

Any mismatch between expected and actual XML/behavior: **STOP**. Capture the XML, report the
exact delta to the user, resolve the root cause before continuing to the next test. Never
rationalize an anomaly ("that's probably fine", "expected quirk") without a root-cause
explanation you can point to in the metadata/build script.

### A6. HYPOTHESIS QUARANTINE (GATE 4)

A new platform-behavior claim (something you observed live that isn't already documented) may
only enter the KB or a simulator tagged one of:
- `STATUS: LIVE-PROVEN <committed log path>` — only after the confirming log is actually
  committed.
- `STATUS: HYPOTHESIS <discriminating test that would confirm/deny it>` — if not yet confirmed.

Never write an unconfirmed hypothesis into the KB as if it were settled fact.

### A7. GATE 5 — before declaring PASS or DONE

`tools/enforce.ps1 -Provider <NAME>` PHASE 6 verdict must read CLOSED (every combo either
`[CONFIRMED]` with a backing XML-bearing log at the current version/fingerprint, or an explicit
`[APPROVED SKIP]`).

**FOUR gates, not two (corrected 2026-07-29 — the two-gate definition was provably
insufficient).** FL_FCIC and TX_TLETS both passed 6c AND 6d for their entire test history while
7 and 8 of their logs were filed under combos that never fired, and while plan tests had never
been captured at all. Content + metadata integrity cannot see either problem:

- **6c Log-content integrity** (`audit_log_content.ps1 -Provider <NAME>`) — log ↔ plan fill-set.
- **6d Log-metadata integrity** (`audit_log_metadata.ps1 -Provider <NAME>`) — log ↔ metadata
  field/combo. The direct CommSys-correctness proof. A green 6c with a failing/absent 6d is NOT done.
- **2i Log combo attribution** (`audit_log_combo_attribution.ps1 -Path <json>`) — the log's NAMED
  combo is what ACTUALLY fired. The wire XML carries NO keyRef, so a filename is never evidence;
  this replays the recorded QUERY STRING to prove it. Without this a dead or shadowed combo
  carries a green PASS log that is really its shadower's.
- **Plan completeness** — `report_test_status.ps1 -Provider <NAME>` must NOT read PARTIAL. The
  classifier diffs plan tests against captured logs (`OwedPlanTests`). Beware the metrics that
  CANNOT see this and will happily say you are done: `audit_test_coverage` reports "Coverage 100%"
  once every combo has ≥1 log (a combo with 1 of 6 planned tests counts as covered), and
  `audit_log_content` prints the "N log(s) vs M plan test(s)" delta and then PASSes on the logs
  that exist. ALL-PASS requires zero owed plan tests.

Also required before declaring DONE: `audit_combo_reachability.ps1` (enforce 2h) shows no
unregistered DEAD combo — testing an unreachable combo is impossible, so it must be removed or
registered, never "tested".
`tools/verify_claims.ps1` must show no unbacked live-proven claims. All docs current, everything
committed and pushed. If any of this fails, the session is not done — fix what's flagged, don't
declare victory around it.

## Part B — Devdoc or metadata XML changed for an existing provider

### B1. Diff against current KB understanding

```
tools/diff_docs.ps1 -NewDoc <path to updated devdoc/engineering doc> -Provider <NAME>
```
Reports NEW / REMOVED / CONFIRMED across 7 element types (fields, handlers, queries, keyRefs,
operators, properties, limitations) versus what the KB currently documents for this provider.

### B2. Diff against the current build

```
tools/audit_metadata.ps1 -Path providers\<NAME>\<NAME>_v<X.Y>.json
```
Treats the metadata XML as gospel and reports every query/field/combo gap between it and the
built JSON. Uses a `$formOnlyFields` whitelist (ImageIndicator, State, Attention, PurposeCode,
etc.) and a `$fieldAliases` map so it doesn't false-positive on legitimate form-only fields or
known aliasing (e.g. CaRequestPurposeCode ↔ PurposeCode) — read its output carefully before
assuming every flagged line is a real gap.

### B3. Regenerate the reference doc

```
tools/extract_metadata_reference.ps1 -XmlPath <path to metadata.xml> -Path <provider json>
```
Refreshes `docs/<PROVIDER>_METADATA_REFERENCE.txt` — the authoritative combo-requirement
document everything else in this repo reads from. Do this *before* editing the build script so
your diff against B2's findings is against fresh ground truth.

### B4. The one rule that resolves most apparent conflicts

**Metadata is field-authority. Devdoc is query-authority.** Never drop a metadata-defined field
just because a devdoc description doesn't mention it (the NJ MessageContinueKeyCode precedent —
restored in v4.3 after being wrongly dropped for exactly this reason). Never build a query the
devdoc doesn't list as supported, even if the metadata XML defines the transaction.

### B5. Shared-module vs single-provider fix

If the change is provider-specific: fix that provider's build script only.

If the change affects a *shared* module (`tools/_build_rms_bundle.ps1`,
`tools/_build_layout_helpers.ps1`, etc.) and therefore multiple providers:
```
tools/flag_pending_fix.ps1 -FixId <id> -Description <text> -Providers <list|all> -Origin <NAME> -Date <date>
```
writes a `[FLAG:<id>]` into every still-pending provider's `PENDING_UPDATES.txt`, which blocks
`enforce.ps1` PHASE 1 for that provider until it's rebuilt. Check portfolio status any time with
`tools/audit_reverse_propagation.ps1`. **One provider at a time** — never mass-rebuild every
flagged provider in one pass; the flag exists precisely so each one gets fixed at its own next
scheduled rebuild, not all at once.

### B6. Rebuild

```
tools/pipeline.ps1 -Provider <NAME>
```
This is a version bump — it auto-triggers GATE 1 (Part A0 above): the *entire* existing test
package restarts from Test 1, regardless of how small the metadata/devdoc change was. There is
no partial-retest path.

## Verification

Part A: `tools/enforce.ps1 -Provider <NAME>` PHASE 6 = CLOSED.
Part B: `tools/audit_metadata.ps1 -Path <json>` shows 0 FAIL after the rebuild, and
`tools/enforce.ps1 -Provider <NAME>` exits 0.
