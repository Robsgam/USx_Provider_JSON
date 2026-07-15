---
name: usx-add-cch
description: Use when adding Computerized Criminal History (CCH) query transactions onto an EXISTING USx provider JSON that already has its base queries built. Not for a brand-new provider (see usx-new-provider for that) and not a general metadata update (see usx-test-iterate Part B for that). Generalizes the TX_TLETS_CCH v1.1 pattern. Trigger on "add CCH to <PROVIDER>", "does <PROVIDER> support criminal history queries", or when a provider's metadata is found to expose CCHCriminalHistory*-style transactions that aren't built yet.
---

# USx Add CCH (Computerized Criminal History) to an Existing Provider

Generalizes the TX_TLETS_CCH v1.1 rebuild (2026-07-15, commit `970eb732`) into a repeatable
pattern. Reference implementation: `providers/TX_TLETS_CCH/scripts/build_tx_tlets_cch.ps1`
(CCH section starts after the base-6 QIDMs, ~line 197 onward) and
`providers/TX_TLETS_CCH/docs/TX_TLETS_CCH_METADATA_REFERENCE.txt`.

**This is additive, not a new provider.** The target provider's existing base queries,
attributes, and layout are untouched — CCH is layered on top of its Person entity as new QIDMs
and new cards.

## Step 1 — Confirm the target actually has unbuilt CCH metadata

```
grep -i "CCHCriminalHistory\|CCH" providers\<TARGET>\docs\*METADATA_REFERENCE*.txt
grep -i "CCH" providers\<TARGET>\docs\*METADATA_AUDIT*.txt
```

**Do not assume TX's 8-transaction list (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) is universal.** Transaction
names and counts vary per state's metadata — e.g. CA_CLETS's metadata exposes a *different*
CCH transaction set (AQ/Entry/FQ/IQ/QH/QHT/QHY/Query), confirmed unbuilt in
`METADATA_AUDIT_CA_CLETS.txt` as of 2026-07-15, and is a real candidate for this skill's first
real-world use. Read the target's own metadata fresh every time — never port a transaction list
from another provider's build script.

## Step 2 — Read the target's own CCH combo structure

Once confirmed, read (or regenerate via `tools/extract_metadata_reference.ps1`) that provider's
`docs/<TARGET>_METADATA_REFERENCE.txt` for each CCH transaction: its field list (name, type,
size), and its metadata combinations (KeyRef, Primary, Set, Any) — this is the literal input
that drives what attributes/combos you author. Do not skip straight to writing combos from
memory of the TX pattern.

## Step 3 — Build metadata's *actual* combo structure, verbatim (the hard-won rule)

This is the single most important rule from the TX_TLETS_CCH v1.1 audit: **never invent a
substitute combo that forces an optional field as if it were required.**

Concrete failure mode (TX_TLETS_CCH v1.0's actual mistake, corrected in v1.1): metadata defined
a bare "Name" combo for QH (Requestor/Operator/InquiryReason/Name/PurposeCode required,
SSN/MiscNumber optional). The original build instead invented `QH.NAME.SSN`/`QH.NAME.MISC`,
wrongly making SSN/MiscNumber *required* qualifiers — silently narrower than what the officer
could actually search with, and non-conformant to metadata (flagged FAIL by
`audit_metadata.ps1`: "field PROMOTED to set[] but metadata has it in any[]"). The fix: build
the real bare combo, carry the optional fields in `any[]`.

**If metadata nests a `<Choice>` inside `<Set>`** (2+ mutually-exclusive required-field paths —
e.g. TX's QWI DOB-path / Misc-path / SSN-path split), that IS a case for one dedicated combo per
branch, each with its own required set — this is LIMITATION #36
(`knowledge-base/PLATFORM_CONSTRAINTS.txt`), not a bug. The distinction: `<Choice>` inside
`<Any>` → one combo, optional fields in `any[]`. `<Choice>` inside `<Set>` → one combo per
branch, required fields in each branch's `set[]`.

## Step 4 — Field isolation convention (copy verbatim)

Every CCH form fieldId and sourceField gets a literal `CCH` suffix: `attentionCCH`,
`nameLastCCH`, `birthDateCCH`, `inquiryReasonCCH`, etc. `targetField` stays bare (unsuffixed) —
it's XML/metadata-facing, not a form field. This guarantees zero collision with the base
provider's existing fieldIds no matter how similarly named (e.g. base `attention` vs CCH
`attentionCCH` never conflict).

## Step 5 — Manual-select exposure convention

Every CCH QIDM: `autoSelect = $false`, `queryLabel` = the transaction's human name (e.g.
`'CCH Criminal History (QH)'`, `'CCH Admin Query (AQ)'`) — this is what renders as the named
checkbox. No field-content auto-routing, no co-fire with the base provider's queries. The
officer explicitly opts in to a CCH search; nothing about CCH ever fires automatically.

## Step 6 — Synthetic keyRef convention (LIMITATION #21/#36)

Where metadata reuses one keyRef across multiple combos, or where you split a `<Choice>` (Step
3), invent dot-suffixed labels: `QH.BDOB` / `QH.NAME` / `QH.SID` / `QH.FBI`, `QR.FBI` / `QR.SID`,
etc. Comment each multi-combo QIDM with the standard citation:
```
# PLATFORM CONSTRAINT: ConnectCIC requires unique keyRefs per QIDM (LIMITATION #21/#36).
# Metadata uses keyRef '<X>' for [these combos / this Choice]; synthetic labels differentiate
# routing. NOT real <STATE> transaction codes.
```
These synthetic keyRefs never appear in the real metadata — they're internal routing labels only
(`verify_build.ps1` CHECK 9 checks every multi-combo QIDM has this documentation).

## Step 7 — 3-card CCH layout skeleton (organizing pattern, adapt field placement)

Reference pattern from `build_tx_tlets_cch.ps1`'s `$perLayout`:
- **CCH OPTIONS** — shared fields every CCH query needs (Attention, InquiryReason, PurposeCode).
- **CCH PERSON** — identity + search identifiers (Name, DOB, Sex, Race, State, SSN, MiscNumber,
  FBI#, SID#, Operator, Requestor, image/related-hit indicators).
- **CCH RECORD/ADMIN** — address/building/department fields, Nlets destination(s), FreeText.

Adapt which specific fields land on which card to the target state's actual CCH field list — the
3-way grouping is the reusable part, not the exact field-to-card assignment.

## Step 8 — Test-value resolver: check before adding, don't duplicate

`tools/_combo_value_resolver.ps1` already has provider-agnostic CCH-suffix test-value cases
(added commit `970eb732`, matches any `*CCH`-suffixed fieldId generically via regex — not
TX-specific). **Do not re-add these per-provider.** Only add a *new* case if the target state's
CCH metadata introduces a field name TX's set never had (check by running
`tools/emit_test_plan.ps1 -Path <json>` after the build and looking for new "no test value"
trust-issue warnings on CCH fields).

## Step 9 — Field-size fidelity per transaction

Don't assume a same-named field needs the same `maxLength` across every CCH transaction in the
provider. TX's own AQ/AR `NletsDestination` fields are 9 chars while FQ/IQ's same-named fields
are 2 chars per their own metadata — if the target state's CCH transactions share form fields
across transactions with differing metadata sizes, check `audit_metadata.ps1`'s maxLength WARN
carefully: confirm whether it's comparing the *same* transaction's own field (real) or a
different transaction's same-named field (a known tool-scoping wrinkle) before "fixing" a field
size that might actually be correct.

## Step 10 — Gate chain (version bump on an existing provider)

```
tools/pipeline.ps1 -Provider <TARGET>
```
Iterate to 0 FAIL / 0 WARN / 0 LIMITATION. This is a version bump on an already-tested provider,
so it triggers GATE 1 from the `usx-test-iterate` skill — the *entire* existing test package
restarts from Test 1, not just the new CCH transactions. Confirm the user is prepared for a full
re-test before starting, since it affects entities that had nothing to do with CCH.

## Verification

`tools/enforce.ps1 -Provider <TARGET>` exits 0. `tools/audit_metadata.ps1 -Path <json>` shows 0
FAIL for the CCH transactions (any accepted metadata divergence documented in
`docs/<TARGET>_ACCEPTED_DIVERGENCES.txt`, not silently left failing).
`tools/test_commsys.ps1 -Path <json> -Entity Person` confirms every CCH combo resolves.
