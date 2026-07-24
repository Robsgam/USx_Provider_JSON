---
name: usx-new-provider
description: Use when the user provides a new USx/ConnectCIC provider's metadata XML and/or devdoc PDF and wants a provider JSON built from scratch. Covers naming verification, source setup, QIDM-first build methodology, and the full validate->report->enforce gate chain. Trigger on "new provider", "onboard <STATE>", "build a provider from this XML/PDF", or when the user hands over a `<PROVIDER>.xml` file that doesn't yet have a folder under providers/.
---

# USx New Provider Build

This is a router over the repo's own knowledge-base (`knowledge-base/*.txt`) and tools
(`tools/*.ps1`) — those files are the source of truth and will keep changing. This skill tells
you *when* to read which one and inlines only the handful of non-obvious gotchas that cause real
repeated mistakes. Do not duplicate KB content here from memory; read the cited file/section live.

## Step 0 — Naming gate (BUILD_RULES.txt Section 0)

Before creating anything: open the metadata XML, read its filename. The provider folder name
MUST equal that filename minus `.xml` — never guess from the devdoc title or a user-supplied
abbreviation. State the derived name back to the user before scaffolding. A mismatch here means
renaming 10+ files later (folder, build script, all doc files, CLAUDE.md, KB README).

## Step 1 — Scaffold + fill placeholders

```
tools/new_provider.ps1 -XmlPath <path\to\provider.xml> -PdfPath <path\to\devdoc.pdf>
```

The scaffolder emits the current single-JSON model directly: one `build_<provider>.ps1` stub
(dot-sources the 3 shared modules, versioned `<PROVIDER>_v<X.Y>.json` output + REPRO hook,
`-PascalCaseUsxFields` RMS call), the 4-category `docs/` layout
(`tracking/`/`reports/`/`reference/`/`deliverables/`), and `logs/`. No BASE/MC stub, no
`phases/`, no `tests/` — those are retired repo-wide (BUILD_RULES Section 6). Immediately follow
up: fill in the `docs/tracking/` placeholders (JSON_INVENTORY.md / STATUS.txt / SQVR.txt) for
real — the scaffolder's generic text will fail repo audits if left as-is.

## Step 2 — Extract + read source materials

```
tools/extract_queries.ps1 -XmlPath <path\to\provider.xml>
```
populates SQVR.txt with the transaction list from metadata. Then:
```
pdftotext source/<PROVIDER>.pdf source/<PROVIDER>_DEVDOC.txt
```
Read the devdoc's **"Basic Queries Supported"** section. This is the *default* scope authority —
metadata defining a transaction does NOT by itself authorize building it if the devdoc doesn't
list it under this heading (see CLAUDE.md's Source Authority Lookup Table).

**Expanded/additional transactions — a judgment call, not an automatic build.** Devdocs often
have a second, later section (worded like "Expanded Transactions Supported") listing further
metadata-defined transactions beyond the basic set. Confirmed precedent (NY_NYSPIN_EJUSTICE's
`NyNyspinDriverLicenseNameQuery`/DGRP, added at v2.1): it's acceptable to build one of these when
it provides clear additional officer search value ("broader search coverage" was NY's own
documented reason) — but this is a deliberate scope-expansion decision, not something to do by
default. If you find candidates in this section, surface them to the user explicitly and get
sign-off before building, rather than silently including or silently excluding them.

**Tool note**: `extract_queries.ps1`'s SQVR output can hide a transaction's true combo structure
if the metadata nests a `<Choice>` of 2+ alternative required-field paths inside a `<Set>` (e.g.
an in-state path vs. an out-of-state path under one `<Combination>` element) — the tool now
surfaces each alternative path explicitly (fixed 2026-07-15, was previously silently dropping
Choice content). If a combo's extracted `set:` looks suspiciously empty or a devdoc-implied
combo seems to be missing, check the raw XML directly for a nested `<Choice>` before assuming
the transaction has no requirements or the combo doesn't exist.

## Step 3 — KB read order (README.txt's own prescribed order — follow it)

README.txt → BUILD_RULES.txt (Section 0 + 3-bundle structure) → PLATFORM_CONSTRAINTS.txt (31
LIMITATIONs + 27 anti-patterns — read this before writing any combo) → FIELD_REFERENCE.txt →
QIDM_REFERENCE.txt → PROVIDER_CONSTRAINTS.txt → TESTING_REQUIREMENTS.txt → RULE_HANDLERS.txt.

## Step 4 — Build, QIDM-first (BUILD_RULES.txt Section 6)

One build script → one JSON, always multi-card-*capable* from the start (no separate BASE/MC
variants — merged repo-wide 2026-05-21).

- **Phase 1 — QIDM confirmation**: single card per entity, every field, 100% query-path
  coverage. Run `tools/test_commsys.ps1 -Path <json>` to confirm every combo fires before
  touching layout. Do not "park" a combo as an MC-later candidate.
- **Phase 2 — layout refinement**: multi-card only for entities with 2+ mutually-exclusive
  required-field search paths. QIDM does not change in this phase — layout only, then retest
  affected entities.
- **Phase 3 — split entity**: only if Phase 2 reveals a genuine state-model conflict that can't
  coexist in one QIF. Rare — the NCIC single-state-field pattern (FIELD_REFERENCE Section 5)
  avoids this for most providers. Reference case where skipping straight to Phase 2/3 without
  confirming Phase 1 first caused undiagnosable failures: NJ and NY both conflated QIDM+layout+
  state-model changes early and couldn't isolate which layer broke.

## Step 5 — Combo authoring (QIDM_REFERENCE.txt Sections 2, 2a, 6)

Exact JSON shape:
```json
{
  "requirements": {
    "set": ["field1"], "any": ["field2"],
    "conditions": [{ "field": ["SourceFieldName"], "operator": "NOT_EXISTS" }],
    "defaults": [{ "field": "AttrName", "value": "X" }]
  },
  "primaryFieldReference": "<attribute name>",
  "keyReference": "<unique per QIDM>",
  "state": "In/Out"
}
```
- Property is `keyReference`, never `keyRef` — the wrong name causes silent null then import
  rejection.
- `conditions[].field` must be the form sourceField/fieldId, NOT the attribute `name` — an
  attribute-name-keyed condition is silently inert.
- **Poisoned-array rule (live-proven, do not violate)**: a conditions array containing ANY
  value-comparison operator (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) disables the *entire* array,
  including co-resident EXISTS/NOT_EXISTS members — the combo then fires unconditionally by
  set[]/any[] alone. Never use value-comparison conditions for routing. Use existence-only
  EXISTS/NOT_EXISTS, or route by set[] membership + combo ordering instead. A genuine
  value-gated requirement is not buildable config-side — document it as a LIMITATION, don't fake
  it with an inert condition.
- Duplicate keyRef in metadata across combos: invent a distinct synthetic keyRef (keyRef is
  platform-internal, the provider routes by field content not keyRef name) — see
  QIDM_REFERENCE Section 4's merge-vs-split decision tree before declaring anything
  not-implementable.
- Most-specific combo (most set[] fields) first in the array.

## Step 6 — RMS bundle (BUILD_RULES.txt Section 4)

```powershell
$rmsBundle = Build-RmsBundle [-KeepSsn] [-SkipRace] [-PascalCaseUsxFields]
```
Walk the D1-D6 decision list in BUILD_RULES Section 4 explicitly for this provider (Vehicle
plate any[] fields, whether to keep the OOS `licensePlateOutAndState` combo, Person
`registrationState` always-add, Sex handling — instance-specific, verify NIBRS reverse-lookup
before keeping `sexAttrId`, dead-attribute cleanup). Do **not** attempt RMS pool isolation (the
union-pool over-send is a known, designed-but-gated fix — not yet cleared, see BUILD_RULES
Section 4's G1/G2 gates).

## Step 7 — Label hints (verify_build.ps1 CHECK 15, BUILD_RULES Section 11)

Labels are the *only* hint mechanism the platform renders (no helperText/placeholder). Every
field needs one of the 7 canonical hint types (routing alternative, identifier priority, routing
context, in-state default, optional indicator, conditional requirement, abbreviation expansion).
State-suffixed fields specifically need either "(leave blank for STATE)" or "(default STATE -
change for out-of-state)" or CHECK 15 fails outright.

## Step 8 — CAD defaults (BUILD_RULES.txt Section 12)

CAD dispatch ignores QIF `initialValue` entirely. Any `any[]` field carrying a form default also
needs a matching `defaults[]` entry in every combo where it's relevant (keyed by attribute name /
PascalCase targetField, not sourceField) — `audit_cad.ps1` CHECK 6 validates this.

## Step 9 — Attention automated-handler standard (BUILD_RULES.txt Section 14)

Default posture is visible-first for every officer-facing field — Attention is the *one*
standing exception. Wherever Attention is optional (`any[]`), it MUST use
`CommsysGetLastNameFirstNameInitialRuleHandler` + a hidden gate-feeder field
(`InpH ... initialValue='X'`) — no visible Attention input when it's optional. Required Attention
(in `set[]`, e.g. CCH-style transactions) stays visible and typed — that's exempt.

## Step 10 — Gate chain

```
tools/pipeline.ps1 -Provider <NAME>
```
Chains build → report → metadata extraction → CLAUDE.md sync → version-doc sync →
cross-provider audit → repo audit → enforce, stopping on first failure. Iterate build-script
fixes until this exits 0 (0 FAIL / 0 WARN / 0 LIMITATION). Never declare a new provider done
without a clean `tools/enforce.ps1 -Provider <NAME>` run — that is the actual completion gate,
not a subjective read of the reports.

## Step 11 — Defaults/usability audit (TESTING_REQUIREMENTS.txt Section 5)

Run after Phase 1, before calling the build "done": confirm standard defaults are present
(Vehicle PlateType=PC / PlateYear=current-year / ImageIndicator=N; Person ImageIndicator=Y;
every other entity ImageIndicator=N) and check State-default safety (LIMITATION #30 — only safe
to default State=home for NCIC-pattern providers with no separate in-state/out-of-state keyRef
split; providers with an in/out split need the card-title-hint approach instead of an
`initialValue`).

## Verification

`tools/enforce.ps1 -Provider <NAME>` exit 0 is the actual gate. Everything else (validate,
build_report, cross-provider audit) is diagnostic detail enforce.ps1 already aggregates.
