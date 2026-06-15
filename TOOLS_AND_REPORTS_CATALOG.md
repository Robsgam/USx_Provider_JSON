# USx Provider JSON — Tools & Reports Catalog
Generated 2026-06-14. Inventory of every script in `tools/` and every report/log file type the
pipeline produces. Authoritative listing taken from the live `tools/` directory; descriptions from
CLAUDE.md's tool table and observed behavior.

Counts: **39 PowerShell scripts + 3 shared modules** in `tools/`, plus `banned_patterns.txt`.
Run order for a full build: `pipeline.ps1` → `build_report.ps1` (11 steps) → audits → `enforce.ps1`.

================================================================================
## A. SHARED MODULES (dot-sourced by build scripts — not run directly)
================================================================================
| File | Purpose |
|------|---------|
| `_build_rms_bundle.ps1` | Builds the RMS bundle + CommSys QRDM from inline KB specs. `Build-RmsBundle` (flags `-KeepSsn`, `-SkipRace`), `Build-CommsysQrdm`. |
| `_build_layout_helpers.ps1` | QIF layout (Craft.js node) factories: `N`, `Inp`, `InpH`, `Sel`, `SelH`, `Dt`, `BuildMultiCardLayout`, `AddCadNodes`, `AddFrNodes`, `MakeLayouts`. |
| `_build_provider_helpers.ps1` | Provider boilerplate: `Build-Auth`, `Build-Qmf`, `Build-ProviderQrdm`, `Build-EntitiesBundle`, `Write-ProviderJson` (writes JSON + phase snapshot + runs validator). |

================================================================================
## B. CORE BUILD-REPORT PIPELINE (the 11 steps `build_report.ps1` runs; each writes a report)
================================================================================
| # | Tool | Purpose | Report file produced |
|---|------|---------|----------------------|
| — | `build_report.ps1` | **Master orchestrator** — runs the 11 below (1-9 parallel) and saves all reports to `docs/`. | (all below) |
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, query sim) + **G-31 poisoned-array** WARN + G-16 shadow LIMITATION. PASS/FAIL/WARN/LIMITATION. | `VALIDATOR_REPORT_<P>.txt` |
| 2 | `render_layout.ps1` | Renders QIF layouts as a text card/field tree (`-Summary`, `-Entity`, `-Variant`, `-QidmOnly`). | `LAYOUT_REPORT_<P>.txt` |
| 3 | `test_commsys.ps1` | CommSys query simulator — shows which combos fire (first-match/shadow/poisoned) and the request XML. | `QUERY_REPORT_<P>.txt` |
| 4 | `report_picklists.ps1` | Scans all FormSelect dropdowns + QRDM/QIDM code types (code-type audit). | `PICKLIST_REPORT_<P>.txt` |
| 5 | `render_html.ps1` | Self-contained color-coded HTML layout report (QIDM tables, rule handlers, combo priority). | `LAYOUT_<P>.html` |
| 6 | `verify_build.ps1` | Post-build verification: banned patterns, fieldId consistency, Visible-First mandate, CHECK 10 (RMS⊆CommSys), CHECK 11 (value-comparison conditions). | `VERIFY_REPORT_<P>.txt` |
| 7 | `audit_metadata.ps1` | Validates QIDM configs against the authoritative XML metadata (fields, combo requirements). | `METADATA_AUDIT_<P>.txt` |
| 8 | `audit_cad.ps1` | CAD dispatch field alignment (camelCase fieldIds, layout variants, CHECK 6 combo defaults). | `CAD_AUDIT_<P>.txt` |
| 9 | `generate_test_matrix.ps1` | Auto-generates the test matrix (render + combo + any[] + deselect + negatives) from the JSON. | `<P>_TEST_MATRIX.txt` |
| 10 | `run_test_matrix.ps1` | Test conductor — validates every matrix case via combo simulation. | `TEST_VALIDATION_<P>.txt` |
| 11 | `simulate_response.ps1` | CJIS response-handler simulator (Height/Name/VehicleYear/truncate/AttributeMapping) vs synthetic data; target 0 MISSING. | `RESPONSE_SIMULATION_<P>.txt` |
| (pre) | `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches). | `LINT_REPORT_<P>.txt` |

================================================================================
## C. GATES & AUDITORS (repo-wide / pre-import gates)
================================================================================
| Tool | Purpose |
|------|---------|
| `enforce.ps1` | **MANDATORY FINAL GATE** — 6 phases: build freshness, validator scores, doc version sync, cross-provider + repo integrity, iterate-phase gate + hypothesis quarantine. Exit 0 = verified. |
| `pipeline.ps1` | **ONE-COMMAND PIPELINE** — build → report → metadata → sync → version docs → cross-provider → repo audit → enforce (stops on first failure). `-Provider`/`-Providers`/`-All`. |
| `audit_repo.ps1` | Full monorepo audit (18 categories: banned patterns, versions, docs, structure, cross-provider, camelCase, undocumented tools, phase snapshots). |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase). |
| `audit_structure.ps1` | Per-provider folder structure (naming, required dirs/files, report freshness). |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphans); `-Gate` → CLOSED / INCOMPLETE-consistent / INCONSISTENT. |
| `verify_claims.ps1` | Hypothesis quarantine — every KB/simulator "live-proven" claim must cite a committed test log. |
| `score_all.ps1` | Provider scorecard — validator scores across all providers, sorted, with rebuild flags (`-Quick` parses existing reports). |
| `preflight_rebuild.ps1` | Per-provider rebuild action plan (validator WARNs + linter + flags → checklist). `-Provider`/`-All`. |
| `preflight_check.ps1` | Pre-build validation against `PROVIDER_CONFIG.txt`. |
| `check_docs.ps1` | Documentation consistency gate (version numbers across all provider docs). |

================================================================================
## D. SYNC (keep docs/scorecards aligned with the JSON)
================================================================================
| Tool | Purpose |
|------|---------|
| `sync_provider_table.ps1` | Updates the CLAUDE.md provider table scores from validator reports. |
| `sync_version_docs.ps1` | Updates STATUS / SQVR / JSON_INVENTORY / REBUILD_TRACKER / BUILD_NOTES with the current version + scores. |

================================================================================
## E. METADATA & EXTRACTION
================================================================================
| Tool | Purpose |
|------|---------|
| `extract_metadata_reference.ps1` | Generates `<P>_METADATA_REFERENCE.txt` (field defs, combo requirements, coverage map, **server-value-routing annotations**). |
| `extract_queries.ps1` | Parses metadata XML into an SQVR-ready tracking file. |
| `diff_docs.ps1` | Diffs updated engineering docs against KB files (NEW/REMOVED/CONFIRMED per category). |
| `generate_build_script.ps1` | Generates a provider build script from metadata XML (field mapping, QIDM generation, layout). |

================================================================================
## F. PROVIDER & TEST LIFECYCLE
================================================================================
| Tool | Purpose |
|------|---------|
| `new_provider.ps1` | Scaffolds a new provider (canonical folders, build-script stubs, doc templates); derives folder name from XML filename. |
| `new_test_log.ps1` | Creates a per-test stub in `tests/` with XML-capture sections (GATE 2). |
| `post_test.ps1` | Instant-save after a test — writes the log (blocks PASS without `-XmlRequest` unless `-Negative`), updates SQVR + STATUS, commits, pushes. |
| `reset_test_package.ps1` | On version change: archives prior logs to `tests/_archive_pre_v<ver>/`, resets SQVR → PENDING, regenerates TEST_MATRIX, stamps `tests/.test_version`. |

================================================================================
## G. CAD & UTILITY
================================================================================
| Tool | Purpose |
|------|---------|
| `map_cad_fields.ps1` | Maps CAD field names to JSON fieldIds (MATCH/CASE_MISMATCH/NO_MATCH); `-GeneratePatch`. |
| `report_cad_mapping.ps1` | HTML report mapping CAD fields to provider sourceField/targetField per QIDM. |
| `Apply-CadFieldAlignment.ps1` | CAD field-alignment function (PascalCase → camelCase rename); dot-sourced by build scripts. |
| `test_layout.ps1` | QIF layout validator + HTML form preview. |
| `build_codetype_test.ps1` | Generates `CODETYPE_TEST.json` for dropdown validation. |
| `banned_patterns.txt` | (data, not a script) One regex per line — patterns that must NOT appear in any output JSON; consumed by `verify_build.ps1` CHECK 1. |

================================================================================
## H. PER-PROVIDER REPORT / LOG FILES (in `providers/<P>/docs/`)
================================================================================
Auto-generated each build (overwritten):
| File | What it's for |
|------|---------------|
| `VALIDATOR_REPORT_<P>.txt` | Structural validation result (PASS/FAIL/WARN/LIMITATION) — the pre-import gate. |
| `LAYOUT_REPORT_<P>.txt` | Text tree of cards/rows/fields per layout variant. |
| `LAYOUT_<P>.html` | Visual color-coded layout + QIDM/combo report. |
| `QUERY_REPORT_<P>.txt` | Which combos fire for sample input + the generated CommSys request XML. |
| `PICKLIST_REPORT_<P>.txt` | All dropdowns and their code-type sources. |
| `VERIFY_REPORT_<P>.txt` | Post-build correctness checks beyond structure. |
| `METADATA_AUDIT_<P>.txt` | QIDM-vs-XML-metadata conformance. |
| `CAD_AUDIT_<P>.txt` | CAD field alignment + combo-default coverage. |
| `<P>_TEST_MATRIX.txt` | Generated list of test cases to run (render/combo/any[]/deselect/negative). |
| `TEST_VALIDATION_<P>.txt` | Test-conductor result (each matrix case simulated). |
| `RESPONSE_SIMULATION_<P>.txt` | Response-handler (QRDM) mapping check; MAPPED/MISSING/UNMAPPED. |
| `LINT_REPORT_<P>.txt` | Build-script anti-pattern scan. |
| `<P>_METADATA_REFERENCE.txt` | Extracted field defs + combo requirements + server-value-routing notes (use this, not raw XML). |

Hand-maintained / sync-updated (persist across builds):
| File | What it's for |
|------|---------------|
| `<P>_STATUS.txt` | Live test matrix, current version/import state, and the NEXT-SESSION pick-up notes. |
| `<P>_BUILD_NOTES.txt` | Change log: CHANGED/REASON per version. |
| `<P>_SQVR.txt` | Supported Query Validation Report — per-combo `[PENDING]`/`[CONFIRMED]` markers. |
| `JSON_INVENTORY.md` | Every JSON version ever produced for the provider. |

================================================================================
## I. TEST LOGS (in `providers/<P>/tests/`)
================================================================================
One file per executed test, created by `new_test_log.ps1` / `post_test.ps1`.
Naming: `<date>_<Entity>_<Combo>_<short-desc>_v<version>.txt` (or `<P>_<Entity>_<Query>_<Combo>_...`).
Each holds: form state, the server-log REQUEST + RESPONSE XML (mandatory for a PASS), the combo that
fired, RMS co-fire, and PASS/FAIL. Superseded logs are archived to `tests/_archive_pre_v<ver>/` on
rebuild (`reset_test_package.ps1`).

================================================================================
## J. REPO-ROOT / CROSS-PROVIDER DOCS
================================================================================
| File | What it's for |
|------|---------------|
| `CLAUDE.md` | Repo guide + provider status table + build model + source-authority routing. |
| `REBUILD_TRACKER.md` | Authoritative rebuild flags, versions, scores, sweep status (incl. poisoned-array catalog). |
| `providers/PROVIDER_STATUS_SUMMARY.txt` | All-provider version/score/status/flags snapshot. |
| `providers/PLATFORM_BUG_REPORT.txt` | Platform bugs reported to the platform team. |
| `knowledge-base/*.txt` | BUILD_RULES, FIELD_REFERENCE, QIDM_REFERENCE, PLATFORM_CONSTRAINTS, etc. (the build authority). |
