---
name: usx-test-iterate
description: Use for live USx Tenant Testing of a provider (paste-XML-and-log loops, one entity/combo at a time), OR when a provider's devdoc/metadata XML has been updated and the existing JSON needs to be reconciled against the change. Covers the GATE 0-5 test protocol and the diff/audit propagation workflow. Trigger on "let's test <PROVIDER>", "here's the XML" (mid test loop), "the devdoc changed", "new metadata for <PROVIDER>", or "what changed vs current build".
---

# USx Test / Iterate / Metadata-Devdoc Update

Router over `knowledge-base/TESTING_REQUIREMENTS.txt` (the test-protocol source of truth) and
the diff/audit tools. Two halves below — use A for live tenant testing sessions, B when source
documents (devdoc PDF or metadata XML) changed for a provider that's already built.

## Part A — Live testing loop

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

### A3. Per-test loop (GATE 2-3) — never batch, log immediately

1. `tools/new_test_log.ps1 -Provider <NAME> -Entity <E> -Combo <keyRef> ...` — stub the log
   *before* opening the form.
2. Open browser DevTools Network tab *before* submitting the query.
3. Submit, capture the raw XML request (both the CommSys/ConnectCic POST and, where the entity
   has an RMS mapping, the RMS elasticQuery POST — Vehicle/Person only; Gun/Article/Boat/DH have
   no RMS mapping, "Not captured" there is correct, not a gap).
4. Fill the log's FORM STATE / REQUEST SUMMARY / FIELD ANALYSIS / RESULT sections.
5. `tools/post_test.ps1 -Provider <NAME> -Entity <E> -Query <Q> -Combo <keyRef> -Result <PASS|FAIL> ...`
   — this commits and pushes automatically. Do not move to the next test before this completes.

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
`[APPROVED SKIP]`). `tools/verify_claims.ps1` must show no unbacked live-proven claims. All docs
current, everything committed and pushed. If any of this fails, the session is not done — fix
what's flagged, don't declare victory around it.

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
