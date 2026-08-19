# Rebuild Tracker
Generated: 2026-05-08 | Last updated: 2026-07-06

## CURRENT STATUS -- see CLAUDE.md, not this section

**This file is a historical/technical archive, not the current-status source.** Current
version/score/status per provider lives in `CLAUDE.md`'s "Provider Status" table (kept in
sync via `sync_provider_table.ps1`); current build/test order lives in memory
`project_provider_work_order` (git is authoritative for what's actually done -- check
per-provider `CHANGELOG_<PROVIDER>.md` for that provider's full version history).

As of 2026-07-06, the providers that have gone through the post-methodology-shift pipeline
(PascalCase-native, single-JSON, identifier-priority guardrails) are: NJ_NJCJIS, CA_CLETS,
HI_HCJDC_OFML, FL_FCIC, NY_NYSPIN_EJUSTICE. NY_NYSPIN_EJUSTICE testing is intentionally PARKED
at the browser-capture step (user request 2026-07-02) -- resume there, don't re-rebuild. All
other providers (AZ_AZDPS, LA_LEMS, and the legacy v1.x stubs) are not yet rebuilt (TX_TLETS rebuilt v4.0 2026-07-09, tested, block-deferred)
under the current methodology; their BASE/MC and legacy-casing paths in shared tools are still
load-bearing.

Gating reality: each "test" needs the JSON imported to the USx tenant by the user; this env returns
NO live state responses (request-side XML + visual only). Methodology: challenge/verify + secure data
before running down a path (do NOT assume; confirm against XML/devdoc/live logs first).

**RESOLVED -- PascalCase vs camelCase:** PascalCase is the native, authored-from-the-start
standard (see CLAUDE.md Field Configuration Rules). NJ/FL/HI/CA_CLETS/NY are converted; remaining
providers convert on their own next scheduled rebuild, one at a time -- no mass update.

## Version Table -- machine-synced, do not hand-edit the version/score columns

`tools/sync_version_docs.ps1` updates each provider's row here automatically at every rebuild;
`enforce.ps1` CHECK 3g WARNs if a provider's current version string is missing from this file.
This table exists to satisfy that gate -- for narrative status/notes, see CLAUDE.md's Provider
Status table instead (this table's Notes column is intentionally terse).

| # | Provider | Version | BASE Score | MC Score | LIM | Notes |
|---|---|---|---|---|---|---|
| 1 | NJ_NJCJIS | v4.16 |  | 61P/0F/0W/0LIM | 0 | in-scope, single-JSON |
| 2 | HI_HCJDC_OFML | v4.20 |  | 65P/0F/0W/0LIM | 0 | in-scope, single-JSON |
| 3 | NY_NYSPIN_EJUSTICE | v4.24 |  | 76P/0F/0W/0LIM | 0 | in-scope, single-JSON, BLOCKED v4.6 (full pass 2026-07-10) |
| 4 | AZ_AZDPS | v3.11 |  | 68P/0F/0W/0LIM | 0 | v3.1 (2026-07-24) existence-gate identifier-priority guardrails added (were demotion-only in v3.0); single-JSON; NOT USx-tenant-tested |
| 5 | FL_FCIC | v7.24 |  | 91P/0F/0W/0LIM | 0 | in-scope, single-JSON |
| 6 | TX_TLETS | v4.21 |  | 79P/0F/0W/0LIM | 0 | REBUILT v4.0, TESTED (2026-07-10), block-deferred pending EmailAddress handler |
| 7 | LA_LEMS | v3.1 |  | 65P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 8 | CA_CLETS | v2.26 |  | 79P/0F/0W/0LIM | 0 | in-scope, single-JSON |
| 9 | CA_VENTURA_COUNTY | v2.4 |  | 82P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 10 | CA_CLETS_OCATS | v2.6 |  | 66P/0F/0W/0LIM | 1 | out of scope |
| 11 | CA_eSUN | v2.3 |  | 72P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 12 | CA_SAN_LUIS_OBISPO | v2.4 |  | 67P/0F/0W/0LIM | 0 | out of scope |
| 13 | IL_LEADS_OFML | v2.8 |  | 61P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 14 | MD_METERS | v2.0 |  | 70P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 15 | OH_LEADS | v2.9 |  | 78P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 16 | NM_NMLETS_OFML | v2.2 |  | 66P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 17 | OR_LEDS | v2.3 |  | 55P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 18 | TN_TIES | v2.1 |  | 74P/0F/0W/0LIM | 0 | galvanized single-JSON 2026-07-23 (NOT USx-tenant-tested) |
| 19 | TX_TLETS_CCH | v1.17 |  | 112P/0F/0W/0LIM | 0 | base-6 re-synced to TX_TLETS v4.7 (email handler + FRT=E, QWName removed); lockstep restored; CCH stub, NOT USx-tenant-tested |
| 20 | CA_CONTRA_COSTA | v2.3 |  | 79P/0F/0W/0LIM | 0 | framework build (CA_CLETS copy + merged metadata); JAWS expanded/unbuilt; NOT USx-tenant-tested |

---

## ARCHIVE -- resolved rebuild history below this line

The sections below are a running technical/engineering-decision log (root-cause analyses, gap
audits, cross-provider rollout notes) kept for institutional context beyond what a single
provider's CHANGELOG captures. Entries are point-in-time and many are superseded by later
entries further down -- when in doubt, trust git log / the provider's CHANGELOG over anything
here.

**Pruned 2026-07-06**: purely historical entries with zero remaining forward action (fully
resolved, captured in git history/CHANGELOGs, no live provider still pending) were deleted
outright rather than kept as dead weight -- e.g. 2026-05-08/05-11 WARN-elimination sweeps, the
2026-05-14 shared-module migration writeups, and a stale duplicate "current status" scorecard
that contradicted the CURRENT STATUS section above. Entries with a mix of resolved + still-open
providers were trimmed to just the open part, with the resolved part verified against current
JSON/CHANGELOG content (not assumed) before removal. Two internally-duplicated tracking tables
(poisoned-array conditions, tracked in two separate sections) were merged into one.

## Attention auto-populate -- PENDING TX_TLETS (2026-06-22)

HI v2.9 resolved Attention auto-populate for optional Attention fields (root cause: this
ConnectCic instance serializes ONLY the fired combo's `set[]`/`any[]` fields, so a handler-only
Attention with no `any[]` entry and no gate-feeder field never reaches the wire). Fix: add
`'Attention'` to the combo's `any[]` + a hidden gate-feeder field (`InpH 'Attention' ...
initialValue='X'`), keep `sourceField=['Attention']` (do NOT empty it -- rejected at import).
FL_FCIC applied this at v6.0 (CONFORMS, see Attention conformance table below).

**RESOLVED for TX_TLETS** (v3.12 / v4.0): Attention auto-populated via handler + hidden gate-feeder
(initialValue='X'), present in both DH combo `any[]` (v4.0 merged the image-variant split to
`KQName`/`KQOLN`). Ref: `knowledge-base/RULE_HANDLERS.txt` entry 13.

## ParseCommsysNameRuleHandler empty-args regression -- RESOLVED for in-scope providers

ROOT CAUSE (2026-06-24): `tools/_build_rms_bundle.ps1` helper `_R($fn, $args)` named its param
`$args` (PowerShell reserved automatic variable) -> collision silently dropped every passed
arguments array during a bug window (intro commit `13a13c8` -> fix `1951db4`, 2026-06-17).
Symptom: Person `Name` attr gets empty args -> `ParseCommsysNameRuleHandler` returns nothing ->
CAD `buildParsedPersonTitle` falls back to DL# as the entity title. Canonical handler spec:
Confluence "Attribute Handle" (Cringer) handler #3; repo summary `knowledge-base/RULE_HANDLERS.txt` #19.

Shared module fixed; remediation = rebuild from current source (no patch). **Verified 2026-07-06**
by grepping current root JSONs: CA_CLETS and NY_NYSPIN_EJUSTICE -- the two in-scope providers
built inside the bug window -- now have zero empty-`arguments[]` occurrences for this handler;
both confirmed fixed by their post-bug rebuilds (CA_CLETS v2.12, NY v4.0).

**Still pending** (out of scope, built inside the bug window, fixes automatically on next
rebuild -- no separate action needed): AZ_AZDPS, TX_TLETS_CCH.

## VehicleMakeName QRDM make-table fix (RND-62365) -- RESOLVED for in-scope providers

The QRDM `VehicleMakeName` attribute resolved vehicle make against the FIREARM make table
(`codeTypeCategory='NCIC_FIREARM_MAKE'`/`codeTypeSource='NJ_NIBRS'`, AP #24) -- wrong; only the
regex fallback masked it. Corrected in `tools/_build_rms_bundle.ps1` `Build-CommsysQrdm` to
`codeTypeSource='VEHICLE'`/`codeTypeCategory='VehicleType'` (2026-06-24, user-verified vs
platform registry; vehicle codes live in the `VehicleType` table under the `VEHICLE` source).
Shared-module fix -- applies automatically on each provider's next rebuild, no separate action
needed. KB: `RULE_HANDLERS.txt` #16 + CLAUDE.md code-type pairings.

**Verified 2026-07-06** by grepping current root JSONs: all 5 in-scope providers carry the
corrected `codeTypeSource: NCIC` -- NJ (fixed v4.5), CA_CLETS (v2.10), HI (v4.6), FL_FCIC (v6.8),
NY (v4.0), and TX_TLETS (v4.0 -- VEHICLE_MAKE/NCIC verified present in the JSON). **Still pending** (out of scope, fixes automatically on next rebuild): AZ_AZDPS.

A related gate, CHECK 15 (`verify_build.ps1` State-label wording), also passes for all 5
in-scope providers, and now TX_TLETS too (v4.0 added State routing hints -- verify_build CHECK 15 clean).

## DEFERRED BACKLOG -- Process-hardening Tier 3 (2026-06-14, documented per user; REMIND at trigger)

From the tools/scripts/KB consolidation audit. Tier 1 (KB poisoned-array centralization, README fix,
QIDM builder helpers, doctor.ps1) + Tier 2 done/in-progress. Tier 3 deferred:

- **Data-driven generic build engine** -- replace ~20 bespoke `build_<provider>.ps1` (~80% boilerplate)
  with one engine + per-provider config. SCAFFOLDED/DEFERRED (user can't dedicate a big Claude block).
  The 30-60h figure is a brute-force [Guessing] estimate -- **do NOT commit to it.** Before any real
  work, run a cheap time-boxed (~1-2h) SPIKE for a measured number / smarter path: derive ONE provider's
  config from its existing JSON -> generate -> diff (config-by-example round-trip). If that works, per-
  provider cost may be ~minutes and the whole effort far less than guessed. `generate_build_script.ps1`
  (the incomplete BASE/MC-era seed) was deleted 2026-07-06 as dead code -- it scaffolded separate
  BASE+MC build scripts, contradicting the current single-JSON build model. Any future engine/scaffold
  should be authored fresh from an existing single-JSON build script (e.g. `build_fl_fcic.ps1`), not
  resurrected from that generator. **REMINDER TRIGGER:** 5+ NEW providers queued, OR idle capacity for the spike.
  Until then, use the new `Build-QidmCombo`/`Build-QidmAttribute` helpers incrementally at each rebuild
  (semantic-reformat, validator-verified -- not byte-diff).
- **Modularize `validate.ps1`** (~2200 lines, 6 coupled phases) -- SKIP. Risk > benefit; revisit only if
  it grows materially or a phase needs independent reuse.

## Poisoned-Array / Value-Comparison Conditions -- per-provider status

POISONED-ARRAY RULE (live-proven FL v4.9 T-A/T-B, USx tenant RMS client): any value-comparison
condition (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) disables its ENTIRE conditions array, including
co-resident NOT_EXISTS members. See `knowledge-base/QIDM_REFERENCE.txt` Sec 2a +
`PLATFORM_BUG_REPORT.txt` BUG 6. **Poisoned = inert, NOT automatically broken** -- benign if
routing is carried elsewhere, harmful if it causes misroute/over-send. Fix at each provider's
own rebuild, one at a time (never a mass sweep).

| Provider | Status |
|---|---|
| CA_CLETS | RESOLVED v2.5 (2026-06-14) -- server-routing model confirmed (wire=MessageType, keyRefs server-selected by field VALUE); 20 inert conditions removed + 13 redundant IV.4* combos deleted. |
| NY_NYSPIN_EJUSTICE | RESOLVED v4.0 (2026-07-02) -- verified 2026-07-06: zero EQUALS/NOT_EQUALS conditions in current JSON. DALHOUT/DALLOUT now use existence-only (EXISTS/NOT_EXISTS) State routing. |
| NJ_NJCJIS | KNOWN BENIGN, no action -- RandomRequest EQUALS Y/N; routing carried by field value, identical MessageKey across the poisoned combo. Live-passed 2026-05-28 NJCJIS tenant. |
| TX_TLETS | RESOLVED v4.0 (2026-07-09) -- verified 2026-07-13: the v4.0 rebuild merged the DH image-variant split and the shipped `TX_TLETS_v4.0.json` has ZERO EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX conditions. ImageIndicator=Y is now a plain `any[]` default (no value-comparison condition), so the poisoned-array risk is gone. |
| TX_TLETS_CCH | OUT OF SCOPE -- intentional separate data-ingestion stub (user directive). |

Process lesson: simulator/combo-match tests PASS without exercising conditions live -- false
confidence (TX 40/40, CA_CLETS 40/40 both pre-finding). The static guard (`validate.ps1` G-31,
`verify_build.ps1` CHECK 11) + request-side USx tenant test close that gap.

## ImageIndicator set[] anomaly -- LA_LEMS (flagged 2026-06-15)

Repo-wide scan (all 24 provider JSONs, during FL_FCIC v5.0 USx tenant testing) found `imageIndicator`
in a combo `set[]` (i.e. REQUIRED) in exactly ONE place: **`LA_LEMS_MC.json` combo `DP`**.
Everywhere else it is `any[]`/`defaults[]` only. ImageIndicator should not be required (FCIC-class
metadata defaults blank->N; it is a query modifier, not a search key). **At LA_LEMS's next rebuild:
verify DP and move `imageIndicator` out of `set[]` into `any[]`** unless LA metadata genuinely
requires it. Context + full ImageIndicator serialization finding: `knowledge-base/FIELD_REFERENCE.txt`
Section 9. One provider at a time -- do not touch LA before its rebuild.

## Process Gap-Proofing -- IMPLEMENTED 2026-06-14

Three-pillar iterate-phase gate built and wired into `enforce.ps1` (blocking): `audit_test_coverage.ps1
-Gate` (per-provider CLOSED / INCOMPLETE-consistent / INCONSISTENT verdict, exits non-zero only
on INCONSISTENT so fresh all-PENDING builds aren't blocked), `verify_claims.ps1` (every KB/simulator
claim tagged "live-proven" must cite a real committed test log; unbacked claims flagged as
HYPOTHESIS), and a tightened `reset_test_package.ps1` (regenerates TEST_MATRIX, warns on combo
delta) + `verify_build.ps1` CHECK 10 (RMS combos subset-of CommSys combos) / CHECK 11
(value-comparison conditions flagged). Docs: `knowledge-base/TESTING_REQUIREMENTS.txt` GATES 0-5,
QIDM_REFERENCE.txt + BUILD_RULES.txt STATUS convention. Full original design rationale: plan file
`swift-gathering-snowglobe.md` (outside the repo) if ever needed.

## Residual UNBUILT Verification -- ongoing process rule (2026-06-12)

`extract_metadata_reference.ps1` phantom-UNBUILT bug fixed 2026-06-12 (synthetic keyRef matching).
Remaining UNBUILT rows in each `METADATA_REFERENCE.txt` are genuine non-matches: a mix of
documented approved skips, LIMITATION #21/#36 collapses, and possible real gaps -- treat every
residual row as a gap until proven otherwise against the devdoc "Basic Queries Supported" combos
(NOT key mnemonics -- devdocs may not contain key lists).

**ACTION at each provider's next rebuild:** classify every UNBUILT row in its METADATA_REFERENCE
as BUILT-VARIANT / APPROVED-SKIP (cite devdoc+BUILD_NOTES) / REAL-GAP (build it). One provider at
a time -- do not mass-sweep.

## RMS Person QIDM Pool Isolation (2026-06-12) -- GATED, not yet applied

FL v4.8 live evidence: RMS follows the union-pool serialization model -- a full DL card sends
dlNumber+name+DOB+sex in ONE elastic query (all four Person combos match, no conditions, pool =
union). Fix designed in BUILD_RULES Section 4 ("RMS POOL ISOLATION"): OLN-first combos +
licenseNumber NOT_EXISTS conditions in `_build_rms_bundle.ps1`. **DO NOT APPLY until gates clear:**
- G1: live impact test (does the elastic search AND criteria? OLN-match/name-mismatch record:
  OLN-only vs full-card results)
- G2: verify RmsRestPayloadHandler honors conditions (zero RMS conditions exist portfolio-wide;
  conditions only proven on the CommSys handler)

When applied, propagates to every provider at its rebuild (shared module). `test_commsys.ps1`
already simulates RMS QIDMs + prints a UNION POOL line per QIDM.

## Shadowed Combo Findings (G-16 subset check, 2026-06-12)

`validate.ps1` G-16 upgraded from consecutive-count heuristic to true subset-shadowing detection
(an earlier UNCONDITIONED combo whose set[] is a subset of a later combo's set[] makes the later
combo unreachable under first-match).

| Provider | Status |
|---|---|
| CA_CLETS | RESOLVED -- IV.4* combos deleted entirely as part of the poisoned-array fix (v2.5); IR.QVC.N shadow fixed v2.12 (RegistrationState NOT_EXISTS + SexCode EXISTS added for mutual exclusion, `verify_build` CHECK 16 reachability CLEAN). Verified 2026-07-06: zero IV.4* keyRefs remain in current JSON. |
| TX_TLETS | RESOLVED v4.0 (2026-07-09) -- CHECK-16 reachability pass added existence-only EXISTS gates (VIN FRT EXISTS, QV-VIN RegionId EXISTS) so the VIN combos are individually reachable; verify_build CHECK 16 clean. |
| TX_TLETS_CCH | STILL OPEN (out of scope, CCH stub) -- `QVVehicleIdentificationNumber` shadowed by `RQVehicleIdentificationNumber`; fixes on its next rebuild. |

NY/NJ/HI/FL_FCIC and all other providers: 0 findings.

## Remaining Limitations (portfolio-wide)
- TX_TLETS: 2 LIM -- EmailAddress is QIDM-only on DL+DH (no form field, handler-filled); genuinely
  unfixable without platform form field additions. See also [[project_tx_email_field_other_team]]
  (EmailAddress form field/handler now owned by a separate eng team -- do not build/modify it).

## One-Directional queriesToDeselect -- per-provider status (rule flagged 2026-05-12)

Rule (KB BUILD_RULES.txt Sec 11 + AP #14/#23): default query (DL, VehReg) has autoSelect=true and
NO queriesToDeselect; opt-in query (DH, VehStolen) deselects ONLY the default. NEVER bidirectional
(mutual cross-deselect -> error popup, see `knowledge-base/PLATFORM_BUG_REPORT.txt` BUG 2).

DL+DH -- remove queriesToDeselect from DriverLicenseQuery:
- FIXED: CA_CLETS (v1.8), FL_FCIC (since v3.9), TX_TLETS (v3.1), NY_NYSPIN_EJUSTICE (v4.0, DH-suffix + one-directional)
- Already correct: NJ_NJCJIS (since v2.9), HI_HCJDC_OFML (one-directional since v1.8 -- DL has no deselect; DH deselects DL only)
- STILL FLAGGED (out of scope, fix at next rebuild): AZ_AZDPS, LA_LEMS, TN_TIES, OH_LEADS,
  NM_NMLETS_OFML, MD_METERS, CA_SAN_LUIS_OBISPO, CA_eSUN, CA_VENTURA_COUNTY

VehReg+VehStolen -- remove queriesToDeselect from VehicleRegistrationQuery:
- FIXED: TX_TLETS (v3.1)
- N/A: HI_HCJDC_OFML (no VehicleStolenQuery built)

## Attention Field -- Automated Handler is the Standard (REVERSED 2026-06-22)

REVERSAL: the prior "expose Attention as a visible field" directive (FL_FCIC v4.0, flagged
2026-05-13) is REVERSED. Wherever Attention is part of a query as an OPTIONAL field, it is
auto-populated via `CommsysGetLastNameFirstNameInitialRuleHandler` (no visible field) -- the
automated-Attention standard (BUILD_RULES Sec 14, user directive 2026-06-22). REQUIRED Attention
(metadata set[], e.g. CCH) stays a visible officer-supplied field.

Conformance (`verify_build.ps1` CHECK 8):
| Provider | Attention state | Status |
|---|---|---|
| HI_HCJDC_OFML | handler on DriverHistoryQuery | CONFORMS |
| LA_LEMS | handler on all 6 QIDMs | CONFORMS |
| TN_TIES, CA_eSUN, CA_VENTURA_COUNTY, OH_LEADS | handler on DriverHistoryQuery | CONFORMS |
| FL_FCIC | converted to handler v5.3 / v6.0 | CONFORMS |
| TX_TLETS | converted to handler v3.9 (2026-06-22) | CONFORMS |
| TX_TLETS_CCH | CCH = required (visible, exempt); DH optional still visible | OUT OF SCOPE (do not touch) |
| NJ, CA_CLETS, CA_OCATS, CA_SLO, IL, MD, NY, OR, AZ, NM | no optional Attention attr | N/A |

**Also noted:** TX_TLETS EmailAddress on DL+DH -- no form field AND no handler (orphan, sends empty).

## Single-JSON Merge -- 2026-05-21 (extended through 2026-07-02)

BASE/MC dual-variant build path eliminated for the 5 in-scope providers: NJ_NJCJIS, FL_FCIC,
CA_CLETS, HI_HCJDC_OFML, NY_NYSPIN_EJUSTICE -- all MERGED (one build script, one JSON output,
reports in `docs/`). Remaining out-of-scope providers merge on their own next rebuild (see
"Flagged for Full Rebuild" below). Tools updated: `pipeline.ps1`, `enforce.ps1`,
`build_report.ps1`, `sync_version_docs.ps1`, `audit_cad.ps1`. KB updated: BUILD_RULES.txt
Section 6, CLAUDE.md.

## Flagged for Full Rebuild on Next Test (14 remaining, all out of scope)

On first test of each remaining provider: (1) delete old BASE script, rename MC->primary
(`build_<provider>.ps1`), update output to `<PROVIDER>.json`; (2) run build script, then
`build_report.ps1`, verify 0 FAIL on all checks including CAD audit; (3) reports go to `docs/`
(not `docs/base/` or `docs/mc/`).

| Provider | MC Script Updated | Attention Fix Needed | Notes |
|---|---|---|---|
| TX_TLETS | YES | YES (DH only) | +race dead field, camelCase applied |
| LA_LEMS | YES | YES (ALL 7 QIDMs) | +race dead field |
| AZ_AZDPS | YES | NO | Keep SSN, remove PlateYear, unique $final assembly |
| CA_VENTURA_COUNTY | YES | YES (DH only) | Standard cleanup |
| CA_eSUN | YES | YES (DH only) | Standard cleanup |
| CA_SAN_LUIS_OBISPO | YES | NO | Standard cleanup |
| CA_CLETS_OCATS | YES | NO | Standard cleanup |
| IL_LEADS_OFML | YES | NO | Standard cleanup |
| MD_METERS | YES | NO | +race dead field |
| OH_LEADS | YES | YES (DH only) | Standard cleanup |
| NM_NMLETS_OFML | YES | NO | Standard cleanup |
| OR_LEDS | YES | NO | Standard cleanup |
| TN_TIES | YES | YES (DH only) | Keep SSN |
| CA_CONTRA_COSTA | DONE | NO | v2.0 framework built as CA_CLETS copy 2026-07-23; JAWS expanded/unbuilt (backfill if devdoc changes) |

(HI_HCJDC_OFML and NY_NYSPIN_EJUSTICE were on this list originally -- both since fully merged
and rebuilt under the current methodology; removed from the table 2026-07-06.)

## CAD Defaults -- Flagged 2026-05-19

CAD dispatch does NOT apply QIF form initialValues. Fields in `any[]` with initialValues need
combination-level `defaults[]` to ensure CAD-dispatched XML includes them. `audit_cad.ps1` CHECK 6
validates this automatically. BUILD_RULES.txt Section 12 documents the rule. All 5 in-scope
providers have this resolved (see each provider's CHANGELOG). Fix on next rebuild of each
remaining provider -- fields to default are provider-specific, check each provider's form
initialValues, not a universal list. Common gaps found historically: ImageIndicator,
LicensePlateTypeCode/LicensePlateYear, RelatedHitSearchIndicator, PurposeCode.

## Legacy Artifact Cleanup -- Flagged 2026-06-03

On rebuild of each remaining provider, also clean up legacy BASE/MC artifacts. See
BUILD_RULES.txt Section 13 for full checklist.

| Cleanup Item | Providers Affected |
|---|---|
| Delete _BASE_TEST_MATRIX.txt + _MC_TEST_MATRIX.txt | All except NJ, FL, TX, CA_CLETS, HI, NY (cleaned on rebuild) |
| Rename _MC suffix JSON to {PROVIDER}.json | Remaining _MC suffix providers |
| Consolidate dual JSON (BASE + MC) | Any provider with 2 root JSONs |
| Regenerate METADATA_REFERENCE (remove "MC expansion candidate") | Remaining unmerged providers |

## Medium-Priority Tool Enhancements (post-TX, not blocking)

### 4A -- verify_build.ps1: DH-suffix fieldId isolation CHECK
  Validate all DH card fieldIds end with DH suffix.
  Cross-check DH QIDM sourceFields only reference DH-suffixed tokens.
  Prevents DL/DH field bleed without needing a USx tenant test to detect it.
  Track: add after TX_TLETS rebuild (TX is the highest-DH-complexity provider).

### 4B -- audit_cad.ps1 CHECK 6 enhancement: defaults[].field name validation
  Current CHECK 6 validates that combo defaults[] entries exist.
  Enhancement: verify each defaults[].field matches a QIDM attribute name (not sourceField),
  and that the field appears in the combo any[]. Catches wrong-field-name defaults silently
  passing the existing check.
  Track: add during TX rebuild cycle.

### 4C -- lint_build_scripts.ps1: hardcoded value detector
  Flag string literals in combo set[]/any[] matching year patterns (^\d{4}$), 2-letter
  state codes, or version strings. $currentYear already enforced for PlateYear; extend
  to catch accidental hardcodes elsewhere (e.g., hardcoded '2025' in a year field).
  Track: add during TX rebuild cycle.
