CONNECTCIC KNOWLEDGE BASE
===========================
Central reference for all ConnectCIC / CommSys provider JSON projects.
Last updated: 2026-06-09
Covers: 20 providers in consolidated monorepo (8 active + 11 new + 1 CCH stub)
  Active (8): NJ/AZ/FL/NY/HI/TX/LA/CA_CLETS  | CCH stub (1): TX_TLETS_CCH
  New (11): CA_VENTURA_COUNTY/CA_CONTRA_COSTA/CA_CLETS_OCATS/CA_eSUN/CA_SAN_LUIS_OBISPO/
            IL_LEADS_OFML/MD_METERS/OH_LEADS/NM_NMLETS_OFML/OR_LEDS/TN_TIES

CURRENT STATUS: See CLAUDE.md provider table for versions, counts, and import status.
  Each provider JSON is standalone. CLAUDE.md and KB docs are the build authority.
  Phase model: single-entity, single-card QIFs. Confirm all QIDMs before layout work.
  NCIC state pattern confirmed NJ + AZ. NIBRS sex confirmed NJ + AZ + FL.
  Avoid old NJ v3.x (split entity) and old NY v1.0-v1.21 (multi-form) as templates.

This folder is the single authoritative reference for all future builds.
Read it before starting any new provider or making any structural change.

SOURCE AUTHORITY RULES:
  WHICH queries to build: DevDoc "Basic Queries Supported" is the ONLY authority.
    Metadata existence alone does NOT authorize building a query.
  HOW to build (fields, combos, keyRefs): MetaData is the build authority.
    When MetaData and DevDoc field descriptions disagree, MetaData wins.
  Document any MetaData vs. DevDoc discrepancies in provider docs.

================================================================================
FILES IN THIS FOLDER (10 files, organized by question)
================================================================================

  README.txt               This file -- index and overview

  BUILD_RULES.txt          "How do I structure a provider JSON?"
                           Provider naming and folder setup (Section 0), 3-bundle
                           architecture, AUTH/QMF/QRDM configs, RMS patches 1-6,
                           QIF layout structure, build phase model, state field patterns,
                           entity field patterns, layout constraints, type safety rules

  FIELD_REFERENCE.txt      "How do I configure this specific field?"
                           Field type selection, code type pairings table, attributeTypeId
                           rules, sex code 3-layer chain, state field NCIC/dual-field,
                           date/name/plate/ImageIndicator configs, operational identity
                           fields, initialValue defaults, queryLabel standard

  QIDM_REFERENCE.txt       "How do I set up query routing?"
                           QIDM properties, combination basics, routing rules, merge vs
                           split decision tree, multi-query person forms (DL+DH scenarios
                           A/B/C), known query patterns, field naming constraints

  PLATFORM_CONSTRAINTS.txt "What CAN'T I do? What breaks?"
                           All 31 platform limitations (#1-#31) + all 27 anti-patterns
                           (AP #1-#27) organized by category. Anti-patterns folded into
                           their related constraints. Confirmed dead ends.

  PROVIDER_CONSTRAINTS.txt "What's special about THIS provider?"
                           Per-provider exceptions: NJ(5), AZ(5), FL(7), NY(7), HI(5),
                           TX(4), LA(6). Cross-provider consistency rules.

  TESTING_REQUIREMENTS.txt "How do I build, test, and validate?"
                           Build phase model, pre-build checklist, autonomous design
                           decisions, RMS patch checklist, defaults/usability audit,
                           pre/post-import checklists, instance-specific behaviors,
                           confirmation status matrix, mandatory gates (2-5),
                           test sequences, validator markers, failure investigation,
                           bulk provider onboarding workflow (Section 16)

  IMPORT_ERRORS.txt        "Why did import fail?"
                           7 known import errors with root cause and fix

  RULE_HANDLERS.txt        "What handlers exist?"
                           24 handlers: 4 property paths, 9 handler functions,
                           14 attribute rule handlers, 1 special handler.
                           Origin map, dead ends, build script checklist.

  CANADIAN_QUERIES_AVAILABLE.txt  "Which providers have Canadian query metadata?"
                           REFERENCE ONLY -- cross-provider availability matrix
                           (CA_CLETS/FL_FCIC/OR_LEDS/NY_NYSPIN/NJ_NJCJIS). ZERO
                           providers have built these; blocked pending official
                           devdoc + metadata. Not part of the standard read order --
                           only relevant if/when Canadian queries are prioritized.

  BEFORE ANYTHING ELSE -- NAMING RULE:
    Provider folder name MUST match the metadata XML filename minus .xml.
    Example: NM_NMLETS_OFML.xml -> folder providers/NM_NMLETS_OFML/
    Verify the XML filename BEFORE creating the folder. Mismatches require
    renaming 10+ files per provider. See BUILD_RULES.txt Section 0.

  READ ORDER FOR A NEW PROVIDER:
    1. README.txt (this file)
    2. BUILD_RULES.txt (Section 0 naming + structure before writing any code)
    3. PLATFORM_CONSTRAINTS.txt (know the immutable constraints and dead ends)
    4. FIELD_REFERENCE.txt (look up every field type and code type pairing)
    5. QIDM_REFERENCE.txt (combination and routing rules)
    6. PROVIDER_CONSTRAINTS.txt (check your provider's specific constraints)
    7. TESTING_REQUIREMENTS.txt (build checklist, defaults audit, test workflow)
    8. RULE_HANDLERS.txt (handler signatures for build script reference)

  SPECIFIC TOPICS (go directly here for known issues):
    Sex code (CommSys + RMS):       FIELD_REFERENCE.txt Section 4
    State field architecture:       FIELD_REFERENCE.txt Section 5
    Article type dropdown:          FIELD_REFERENCE.txt Section 2 (codeTypeSource=CA_CLETS)
    QIDM merge vs split:           QIDM_REFERENCE.txt Section 4
    DL+DH multi-query patterns:    QIDM_REFERENCE.txt Section 5
    Metadata combo requirements:    Per-provider docs/<PROVIDER>_METADATA_REFERENCE.txt
    Import error messages:          IMPORT_ERRORS.txt
    Provider-specific constraints:  PROVIDER_CONSTRAINTS.txt
    First-import test checklist:    TESTING_REQUIREMENTS.txt Section 8
    Cross-provider consistency:     PROVIDER_CONSTRAINTS.txt (bottom section)
    Anti-patterns by number:        PLATFORM_CONSTRAINTS.txt (cross-reference index)
    Defaults and usability:         TESTING_REQUIREMENTS.txt Section 6
    Bulk provider onboarding:       TESTING_REQUIREMENTS.txt Section 16
    Provider naming/folder setup:   BUILD_RULES.txt Section 0
    Rename propagation checklist:   BUILD_RULES.txt Section 0

================================================================================
TOOLS
================================================================================

  tools/validate.ps1
    *** MANDATORY PRE-IMPORT VALIDATOR ***
    Run BEFORE every import. 6-phase validation:
      Phase 0: Encoding (BOM, UTF-16, JSON syntax)
      Phase 1: Bundle structure
      Phase 2: QIF layout (parent-child, fieldIds, ROOT node, prop types)
               Catches: templateColumns as string (AP #21), maxLength as number (AP #22)
      Phase 3: QIDM (duplicate targetField, phantom sourceField, combos, keyRef dupes)
      Phase 4: AutoSelect conflicts (AP #23), LIMITATION #2, queriesToDeselect cross-refs
      Phase 5: Auth/QMF/Results presence
      Phase 6: Query simulation (combo set[] field resolution)
    Usage: powershell.exe -ExecutionPolicy Bypass -File validate.ps1 -Path <json> [-ShowDetail]
    Calibrated against NJ_NJCJIS (37 PASS / 1 FAIL [BOM only]).

  tools/build_report.ps1
    Master build report. Always runs 9 core tools (validator + layout + query sim + picklist +
    HTML + verify + metadata audit + CAD audit + test matrix), then supported-query audit and
    per-provider changelog -- all of these are read back by enforce.ps1. Lint, test conductor,
    response simulator, label review, and officer guide are advisory-only (nothing gates on
    them) and were demoted to opt-in 2026-07-06: pass -IncludeExtended to also run them, or
    invoke the underlying tool standalone any time.
    After writing the manifest it PRUNES orphaned variant reports: any build-owned report file (or *_TEST_MATRIX.txt) for this provider whose name is not one this build produces (e.g. left over from a removed JSON variant) is deleted from the docs folder. Manual docs (TEST_PLAN_*, *_FIELD_CASING_REVIEW.md, *_SUPPORTED_QUERIES.txt, FIRST_RESPONDER_*) are never touched.
    Usage: powershell.exe -ExecutionPolicy Bypass -File build_report.ps1 -Path <json> [-IncludeExtended]
    Run after EVERY JSON build or edit.

  tools/verify_build.ps1
    Post-build verification. Catches issues that slip past the structural validator:
      1. Banned string patterns (from banned_patterns.txt)
      2. QIF fieldId / QIDM sourceField / combo consistency
      3. RMS QIDM name vs sourceField alignment
      4. Cross-bundle fieldId consistency
      5. camelCase enforcement (opt-in via -CamelCase flag)
      6. Standard pattern comparison (queryLabel, ImageIndicator, keyReference, state)
      7. Cross-variant consistency (BASE vs MC field type mismatches)
      8. Visible-First Mandate (no hidden/auto-populated fields outside approved exceptions)
      9. Synthetic keyRef documentation -- WARNs on multi-combo QIDMs missing LIMITATION
         #21/#36 comment block in build script (BUILD_RULES.txt Section 15)
    Called automatically by build_report.ps1 as step 6. Can also run standalone.
    Usage: -Path <json> [-CamelCase]
    FAILS the build (exit 1) if any check fails.

  tools/banned_patterns.txt
    One regex per line. Each pattern must NOT appear in any output JSON.
    Consumed by verify_build.ps1 Check 1. Add new patterns as issues are discovered.

  tools/render_layout.ps1
    CLI layout tree renderer.
    Usage: -Path <json> [-Summary] [-Entity <name>] [-Variant <type>] [-QidmOnly]

  tools/test_commsys.ps1
    CommSys query simulator. Shows which combos fire and simulated XML output.
    Usage: -Path <json> [-Entity <name>] [-Combo <keyRef>]

  tools/report_picklists.ps1
    Scans all FormSelect dropdowns + QRDM/QIDM code types.
    Usage: -Path <json> [-OutFile <path>]

  tools/suggest_field_labels.ps1
    Derives each field's (required)/(required for <keyRefs>)/(optional) label hint from the
    QIDM combo set[]/any[] -- the consistent method for the field labeling convention. Flags
    fields needing a human semantic hint (value meanings, out-of-state, cross-field "or use X").
    Called automatically by build_report.ps1 as step 12 only when -IncludeExtended is passed
    (advisory output, not read by enforce.ps1).
    Usage: -Path <json> [-OutFile <path>]

  tools/render_html.ps1
    Self-contained HTML layout report with color-coded fields and QIDM tables.
    Usage: -Path <json> -OutFile <path>

  tools/render_officer_guide.ps1
    Officer-facing printable quick-reference: every supported query + each search path's
    required/optional fields in plain English (no internal jargon). HTML + best-effort PDF
    via Edge headless. A transform of QIDM combos + queryLabel + QIF field labels.
    Called automatically by build_report.ps1 as step 13 only when -IncludeExtended is passed
    (advisory deliverable, not read by enforce.ps1).
    Usage: -Path <json> -OutFile <html> [-PdfFile <pdf>]

  tools/render_cad_guide.ps1
    Provider CAD auto-dispatch reference: documents the CAD-dispatched query paths and the
    fields CAD auto-populates per combo, in plain English. HTML + best-effort PDF via Edge
    headless. A transform of QIDM combos + combo defaults + CAD field alignment.
    Usage: -Path <providerJson> -OutFile <html> [-PdfFile <pdf>]

  tools/generate_changelog.ps1
    Per-provider changelog (Markdown) rendered from docs/<PROVIDER>_BUILD_NOTES.txt ->
    docs/CHANGELOG_<PROVIDER>.md. Deterministic (pure function of BUILD_NOTES). Step 16
    of build_report; also re-run by sync_version_docs.ps1 after the BUILD_NOTES date sync.
    sync_version_docs.ps1 additionally refreshes the repo-root CHANGELOG.md "Current:" line.
    Usage: -Path <json> | -Provider <name> [-OutFile <path>]

  tools/new_test_log.ps1
    Creates a stub test log in tests/. Required by GATE 2 before every test.
    Usage: -Provider <name> -Version <ver> -Entity <entity> -Combo <combo>

  tools/build_codetype_test.ps1
    Generates CODETYPE_TEST.json for dropdown validation. Tests which
    codeTypeCategory + codeTypeSource combinations produce non-empty dropdowns.
    Usage: -OutFile <path>

  tools/extract_queries.ps1
    Parses metadata XML and extracts all query transactions, fields, and
    combinations into a structured SQVR-ready tracking file.
    Usage: .\extract_queries.ps1 -XmlPath <metadata.xml> [-OutFile <path>]

  tools/preflight_check.ps1
    Pre-build validation against PROVIDER_CONFIG.txt. Catches configuration
    drift (BirthDate format, provider name, date format) before the build runs.
    Usage: .\preflight_check.ps1

  tools/audit_repo.ps1
    Full monorepo consistency audit. Checks KB docs, build scripts, tools,
    provider JSONs, and CLAUDE.md for drift, stale references, missing
    documentation, banned patterns, report completeness, and cross-provider
    JSON consistency. 18 categories:
      1. Banned patterns repo-wide
      2. Report step count consistency
      3. QueryLabel standard
      4. Stale archive references
      5. Build script completeness (validator)
      6. Tool documentation
      7. Render tool correctness
      8. CLAUDE.md consistency
      9. Provider canonical structure (dirs, docs)
      10. Report file completeness (all 10 reports per variant)
      11. Cross-provider JSON consistency (RMS autoSelect, AUTH keyRef, queryLabels)
      12. Version consistency (build script vs STATUS/SQVR/CLAUDE.md)
      13. BUILD_NOTES version coverage (current version has an entry)
      14. JSON_INVENTORY version coverage (current version has an entry)
      15. STATUS.txt score accuracy (PASS count matches validator report)
      16. Phase archive completeness (base/ has snapshot for current version)
      17. Validator WARN audit (0 WARN target on all providers)
      18. camelCase fieldId consistency (cross-provider fieldId casing)
    Sources of truth extracted at runtime. FAILS (exit 1) on any issue.
    Usage: .\audit_repo.ps1 [-Category <1-18>]

  tools/audit_cad.ps1
    CAD dispatch field alignment auditor. Validates camelCase fieldIds for
    CAD auto-populate, CAD_DISPATCH/FIRST_RESPONDER layout variants, Patch 8
    completeness, and QIDM sourceField case alignment.
    Usage: .\audit_cad.ps1 [-Path <json>] [-Variant <BASE|MC>] [-OutFile <path>]

  tools/audit_simulator_parity.ps1
    Tool-integrity gate. Confirms test_commsys.ps1 and run_test_matrix.ps1 both
    dot-source _sim_helpers.ps1 and use Test-ComboConditionsCore (no private/
    attribute-name condition logic). FAILs on drift. Run live by enforce Phase 2d.
    Usage: .\audit_simulator_parity.ps1 [-Path <json>] [-OutFile <path>]

  tools/audit_supported_queries.ps1
    Devdoc ground-truth gate. Checks every CommSys combo (queryLabel +
    primaryFieldReference) against docs/<PROVIDER>_SUPPORTED_QUERIES.txt, the
    human-reviewed devdoc "Basic Queries Supported" extract. PROVISIONAL extracts
    report INFO; CONFIRMED extracts FAIL on unsupported combos. Auto-writes a
    provisional template from the JSON when absent. Step 15 of build_report;
    gated by enforce Phase 2e.
    Usage: .\audit_supported_queries.ps1 -Path <json> [-OutFile <path>]

  tools/audit_cross_provider.ps1
    Cross-provider consistency audit. Validates ALL provider JSONs against
    documented rules: default field values, version matching, queryLabel
    standards, code type pairings, field type consistency, camelCase
    enforcement, CA-specific rules, RMS autoSelect, entity display order.
    Usage: .\audit_cross_provider.ps1 [-Path <providers-dir>] [-OutFile <path>]

  tools/audit_metadata.ps1
    Validates provider JSON QIDM configurations against authoritative XML
    metadata. Checks that every query/field/combo in metadata is correctly
    implemented in the JSON.
    Usage: .\audit_metadata.ps1 [-Path <json>] [-OutFile <path>]

  tools/accept_divergence.ps1
    Appends a reasoned entry to a per-provider accepted-divergence registry
    (providers/<Provider>/docs/<Provider>_ACCEPTED_DIVERGENCES.txt). Entries
    recorded here are read by audit_metadata.ps1 (CHECK 4 / 4d) and treated as
    [NOTE] instead of [FAIL], so intentional set/any divergences do not block
    the build gate. Idempotent -- skips if (query|keyRef|field) key already exists.
    Usage: .\accept_divergence.ps1 -Provider <name> -Query <query> -KeyRef <keyRef>
               -Field <field> -Rule <rule> -Reason <reason> [-TestLog <path>] [-Date <yyyy-MM-dd>]

  tools/audit_structure.ps1
    Validates provider folder structure against canonical rules. Checks folder
    naming, required dirs/files, report completeness, freshness, JSON internal
    provider name, source materials, phase archives, release bundle.
    Usage: .\audit_structure.ps1 [-Path <provider-dir>] [-OutFile <path>]

  tools/extract_metadata_reference.ps1
    Generates per-provider METADATA_REFERENCE.txt from metadata XML + provider
    JSON. Extracts: field definitions, combination requirements (Set/Any/Choice),
    build coverage map, MC expansion candidates, unbuilt transactions.
    Usage: .\extract_metadata_reference.ps1 -XmlPath <xml> -Path <json> [-OutFile <path>] [-All]
    Run with -All to regenerate METADATA_REFERENCE.txt for all 18 providers.
    Output: docs/<PROVIDER>_METADATA_REFERENCE.txt (per-provider deliverable).
    Cross-references built QIDM combos against metadata combos by keyReference.
    Standard deliverable alongside SQVR.txt and STATUS.txt.

  tools/audit_test_coverage.ps1
    Test coverage auditor. Maps QIDM combinations to test log files, generates
    coverage matrix, checks SQVR alignment, identifies orphan test logs.
    Usage: .\audit_test_coverage.ps1 [-Path <json>] [-OutFile <path>]

  tools/verify_claims.ps1
    Hypothesis quarantine. Every KB/simulator platform-behavior claim tagged
    "live-proven" must cite an existing committed test-log path; flags unbacked
    claims. Wired into enforce.ps1 PHASE 6. Long-path (>260) safe.
    Usage: .\verify_claims.ps1 [-OutFile <path>]

  tools/new_provider.ps1
    Scaffolds a new provider with canonical folder structure, build script
    stubs, doc templates, and tool registrations. Derives folder name from
    XML filename (enforcing naming rule).
    Usage: .\new_provider.ps1 -XmlPath <metadata.xml> [-PdfPath <devdoc.pdf>] [-Force]

  tools/post_test.ps1
    Instant-save tool for test results. After any test completes, saves all
    artifacts, updates docs (STATUS, SQVR), commits, and pushes. Supports
    XML capture and form state documentation.
    Usage: .\post_test.ps1 -Provider <name> -Entity <entity> -Query <query> -Combo <combo> -Result <PASS|FAIL> -Description <desc>

  tools/check_test_preconditions.ps1
    Pre-test gate: cross-checks combo defaults against devdoc conditional field
    constraints (FIELD CONSTRAINTS blocks in METADATA_REFERENCE.txt). Emits WARN
    to stdout if a default triggers a "Must be filled if" requirement that has no
    corresponding default or handler. Called by PreToolUse hook before post_test.ps1
    invocations. Exit 0 always (warn-only).
    Usage: .\check_test_preconditions.ps1 -Provider <name> [-Query <qidmName>]
           .\check_test_preconditions.ps1 -FromHook  (reads JSON from stdin, hook mode)

  tools/reset_test_package.ps1
    Restarts the live test package when a JSON is rebuilt. A version bump
    invalidates prior logs (routing/conditions/defaults may have changed), so
    affected logs must restart from Test 1 to line up with the shipped JSON.
    ENTITY-AWARE (via tests/.test_state.json): an entity "blocked out" with
    block_entity.ps1 is PRESERVED across rebuilds while its structural
    fingerprint (get_entity_fingerprints.ps1) is unchanged; every other entity
    (open, or blocked-but-changed, or all under -Force) is RESET -- archiving
    its tests/*.txt -> tests/_archive_pre_v<ver>/, resetting its SQVR markers
    [CONFIRMED]/[FAILED] -> [PENDING], and clearing its STATUS rows. Stamps
    tests/.test_state.json (authority) + tests/.test_version (legacy scalar =
    global). Full-reset behavior is unchanged when no entity is blocked.
    Idempotent (no-op when all entities are blocked & unchanged).
    Called automatically by pipeline.ps1 after a successful build.
    Usage: .\reset_test_package.ps1 -Provider <name> [-Force]

  tools/get_entity_fingerprints.ps1
    Computes a deterministic per-entity SHA256 fingerprint of behavior-relevant
    structure (QIF layout + QIDM combinations/attributes across PROVIDER and RMS
    bundles; excludes version/date/description). Dot-source for the
    Get-EntityFingerprints function, or run directly to print { entity -> hex }.
    Underlies entity-aware reset and the enforce block-out drift gate.
    Usage: .\get_entity_fingerprints.ps1 -Path <json> [-OutFile <json>]

  tools/block_entity.ps1
    "Blocks out" a validated entity so a later rebuild for a DIFFERENT entity
    does not wipe its results. Requires all of the entity's SQVR markers to be
    [CONFIRMED] (no [PENDING]/[FAILED]) unless -Force. Records the entity's
    current fingerprint + global version in tests/.test_state.json as
    status='blocked', then commits/pushes. reset_test_package.ps1 preserves it
    while unchanged; enforce.ps1 FAILS a blocked entity whose fingerprint drifts.
    Usage: .\block_entity.ps1 -Provider <name> -Entity <entity> [-Force] [-NoCommit]

  tools/watch_captures.ps1
    Downloads watcher for the automated USx Tenant Testing loop. Start once per session;
    monitors ~/Downloads for usx_captured_batch_labeled*.json files dropped by the browser
    extension's __usxBulkFetch, runs relabel_batch.ps1 (content-based label correction),
    then import_captured_tests.ps1 on each new file.
    Usage: .\tools\watch_captures.ps1            # auto-import + commit
           .\tools\watch_captures.ps1 -NoCommit  # import only, no git commit
           .\tools\watch_captures.ps1 -Once      # exit after first import (supervised mode:
                                                 # the supervisor reports the summary + re-arms)

  tools/relabel_batch.ps1
    Content-based batch relabeler, run by watch_captures.ps1 before every import. Browser
    label pairing is unreliable when tests share identifier values and differ only in
    optional fields (labels arrived rotated within a query family); the dex-log formState
    is ground truth. Matches each record to the provider TEST_PLAN test whose fills it
    satisfies (matcher shared with audit_log_content via _content_match.ps1) and rewrites
    labels in place, reporting corrections. With the deterministic positional pairing in
    capture.js, a clean run reports 0 corrections -- any correction is a process error.
    Usage: .\tools\relabel_batch.ps1 -BatchPath <file> [-PlanPath <file>]

  tools/_content_match.ps1
    Shared content-matching core (dot-sourced by relabel_batch + audit_log_content):
    tolerant value matching (state names, M/Male, CNST_ prefixes), plan-label naming,
    family-fillable sets, QIF formDefaults + dominant-value default detection.

  tools/audit_log_content.ps1
    Saved-log integrity audit: every test log's QUERY STRING must satisfy its plan test's
    FULL fill-set (identifier-only auditing passed label-rotated logs, 2026-07-02), and
    guardrail logs must show winner-only XML (losing identifier absent). Wired into
    enforce.ps1 PHASE 6c for the scoped provider; exit 0 = 0 stale / 0 mismatch /
    0 guardrail-wire failures.
    Usage: .\tools\audit_log_content.ps1 -Provider <name> [-Quiet]

  tools/emit_picklist_scope.ps1
    Emits providers/<P>/logs/<P>_PICKLIST_SCOPE.json -- every visible FormSelect per entity
    (fieldId + category/source) -- for the browser's __usxScopePicklists, which opens each
    dropdown UNFILTERED and dumps the tenant's actual option list (cap 500/field).
    Usage: .\tools\emit_picklist_scope.ps1 -Path providers/<P>/<P>_vX.Y.json

  tools/audit_xml_consistency.ps1
    Cross-run XML regression check: same combo + same fills must produce the SAME wire
    XML run after run (only the transaction id changes; normalized before diff). Compares
    current logs against a baseline git ref -- use the previous clean pass's commit of the
    SAME plan (diffs against a different-values baseline are expected, not regressions).
    Live-proven 2026-07-02: HI 45/45 SAME across two same-day full runs; CA/NJ diffs vs
    the prior day exposed that day's label rotations, not wire changes.
    Usage: .\tools\audit_xml_consistency.ps1 -Provider <name> [-BaselineRef <commit>]

  tools/serve_plans.ps1
    Localhost HTTP server (127.0.0.1:8477, TcpListener, CORS *) so the extension panel's
    "Load plan from repo" / "Scope picklists" buttons fetch the repo's CURRENT
    TEST_PLAN / PICKLIST_SCOPE for the tenant (provider derived from hostname) instead of
    the operator file-picking. Start once per session, like watch_captures.ps1.
    Usage: pwsh -File tools\serve_plans.ps1

  tools/import_picklists.ps1
    Merges usx_picklists_<provider>_<entity>.json downloads into
    docs/reference/TENANT_PICKLISTS.json and validates: FAIL on empty tenant tables and on
    plan test values that match no tenant option (the CA-gunTypeCode / NJ-GunMake class).
    Routed automatically by watch_captures.ps1. emit_test_plan.ps1 hard-gates select
    values against this file once it exists.
    Usage: .\tools\import_picklists.ps1 -Path <file|dir>

  tools/import_captured_tests.ps1
    Ingests browser-captured test records (usx_captured_*.json from the extension) into
    post_test.ps1. Each record carries provider/entity/query/combo/tier/expectedKeyRef +
    requestXml; result is computed (PASS when firedMessageType matches expected query).
    Infers combo from XML when no batch context is present (recovered dex-log entries).
    Usage: .\import_captured_tests.ps1                      # newest file in ~/Downloads
           .\import_captured_tests.ps1 -Path <file|dir>
           .\import_captured_tests.ps1 -Commit              # commit+push after importing

  tools/emit_test_plan.ps1
    Emits a machine-readable TEST_PLAN.json for the browser driver (__usxRunPlan). Converts
    a provider JSON into the ordered FULL pass: render marker, every combo (set[] fields
    resolved to form fieldId + test value), each combo's individual any[] tests + all-any,
    guardrail tests, negative marker. Tiers removed 2026-07-01 (-Tier accepted but ignored).
    Non-silently WARNs on unmapped combo fields / missing guardrails. Mirrors
    generate_test_matrix.ps1 logic in JSON the driver consumes.
    Usage: .\emit_test_plan.ps1 -Path <json> [-OutFile <path.plan.json>]

  tools/compare_captures.ps1
    Validation-only tool (no import). For each record in an automation capture file, finds
    the matching reference -- a committed test log (default) or a second capture file -- and
    diffs the ConnectCic Request field set (normalizing Transaction id). Reports MATCH/DIFF
    per combo. Use to prove automation reproduces the same queries as trusted reference logs.
    Usage: .\compare_captures.ps1 -CaptureFile <auto.json> -Provider <name>
           .\compare_captures.ps1 -CaptureFile <rerun.json> -ReferenceFile <ref.json>

  tools/_archive/backfill_log_stamps.ps1  (ARCHIVED 2026-07-06 -- past its migration window)
    One-time migration tool. Stamps pre-existing test logs (written before provenance stamping
    existed) with the JSON Version + Entity Fingerprint + Tier header that post_test.ps1 now
    writes automatically. Run only for providers whose logs were genuinely run against the
    CURRENT shipped JSON. Never use for providers whose logs predate a rebuild (those must
    re-test). Idempotent -- never overwrites an existing stamp. Moved to tools/_archive/ rather
    than deleted, in case a future rebuild ever needs this exact migration again; still runnable
    from its new path (internal tools/ references updated accordingly).
    Usage: .\_archive\backfill_log_stamps.ps1 -Provider <name> [-Apply] [-Tier <tier>]

  tools/_combo_match.ps1
    Shared module: CommSys combo enumeration + test-log filename matching. Single source of
    truth so audit_test_coverage.ps1 and block_entity.ps1 use identical matching rules.
    Dot-source only; defines functions (Get-CommSysQidms, etc.), no side effects.

  tools/_test_provenance.ps1
    Shared module: test-log provenance + tier helpers. Single source of truth for reading
    stamped JSON Version / Entity Fingerprint / Tier from a log header and determining
    whether a log validly backs a [CONFIRMED] combo. Used by post_test.ps1 (writer),
    audit_test_coverage.ps1, block_entity.ps1, and backfill_log_stamps.ps1 (readers).
    Dot-source only; defines functions, no side effects.

  tools/diff_docs.ps1
    Diffs updated engineering docs against KB files. Extracts 7 element
    types (fields, handlers, queries, keyRefs, operators, properties,
    limitations). Reports NEW, REMOVED, CONFIRMED per category.
    Usage: .\diff_docs.ps1 -NewDoc <path> [-KbFile <path>] [-OutFile <path>] [-Provider <name>]

  tools/score_all.ps1
    Provider scorecard. Runs validator on all providers (or parses existing
    reports in -Quick mode), outputs a sorted table with version, score
    scores, and rebuild flags. The go-to dashboard for project status.
    Usage: .\score_all.ps1 [-Quick] [-OutFile <path>]

  tools/doctor.ps1
    One-shot repo health dashboard (read-only). Composes score_all -Quick +
    poisoned-array sweep (validate.ps1 G-31) + git status + reverse-propagation
    status into one snapshot.
    Usage: .\doctor.ps1 [-SkipPoison] [-OutFile <path>]

  tools/flag_pending_fix.ps1
    Reverse-propagate a shared-module/JSON bug fix as a doc-stub flag. Writes a
    [FLAG:<id>] line into each still-pending provider's PENDING_UPDATES.txt (which
    enforce.ps1 PHASE 1 blocks on until rebuilt; the build script clears it) and
    appends a REVERSE_PROPAGATION_LOG.md row. Idempotent; skips origin + incomplete.
    Usage: .\flag_pending_fix.ps1 -FixId <id> -Description <text> -Providers <list|all> [-Origin <name>] [-Date <yyyy-MM-dd>] [-DryRun] [-OutFile <path>]

  tools/audit_reverse_propagation.ps1
    Portfolio status view for reverse-propagated fixes. Reads every PENDING_UPDATES.txt
    + REVERSE_PROPAGATION_LOG.md, reports which providers are pending/propagated per fix
    plus gaps. Informational (enforce PHASE 1 is the gate); composed into doctor.ps1.
    Usage: .\audit_reverse_propagation.ps1 [-OutFile <path>]

  tools/lint_build_scripts.ps1
    Static analysis of all build scripts for anti-patterns. Checks: PlateYear
    dynamic ($currentYear), field type correctness, missing RMS patches,
    AP #21-23 violations, validator call presence.
    Called automatically by build_report.ps1 as the [PRE] step only when -IncludeExtended is
    passed (advisory output, not read by enforce.ps1). Also called by preflight_rebuild.ps1.
    Usage: .\lint_build_scripts.ps1 [-Path <dir>] [-OutFile <path>]

  tools/preflight_rebuild.ps1
    Per-provider rebuild action plan. Combines validator WARNs, linter
    warnings, and rebuild flags into a prioritized checklist. Use before
    rebuilding to see exactly what needs to change.
    Usage: .\preflight_rebuild.ps1 [-Provider <name>] [-All] [-Quick] [-OutFile <path>]

  tools/sync_provider_table.ps1
    Auto-updates the CLAUDE.md provider table scores from validator report
    files. Ensures CLAUDE.md always reflects the latest build results.
    Usage: .\sync_provider_table.ps1 [-DryRun] [-OutFile <path>]

  tools/sync_version_docs.ps1
    Auto-updates version-dependent docs after a build. Updates 5 files to
    match the current build script version and validator scores:
      1. STATUS.txt (header, version, date, validator scores)
      2. SQVR.txt (header, version, date, validator scores)
      3. JSON_INVENTORY.md (root section + new version entry)
      4. REBUILD_TRACKER.md (provider row version + scores)
      5. BUILD_NOTES.txt (version entry date synced to JSON file date — build checksum)
    Called automatically by pipeline.ps1 as step 5.
    Usage: .\sync_version_docs.ps1 -Provider <name> [-DryRun]

  tools/enforce.ps1
    *** MANDATORY FINAL GATE -- RUN BEFORE DECLARING ANYTHING DONE ***
    Single-command verification that runs ALL checks in sequence:
      Phase 1: Build freshness (reports newer than JSONs, phase archives exist)
      Phase 2: Validator scores (0 FAIL / 0 WARN on every provider)
      Phase 3: Doc version sync (build script version matches STATUS, SQVR,
               BUILD_NOTES, JSON_INVENTORY, CLAUDE.md, REBUILD_TRACKER)
      Phase 4: Cross-provider consistency (audit_cross_provider.ps1 0 FAIL)
      Phase 5: Repo integrity (audit_repo.ps1 0 FAIL, git status clean)
    Exit 0 = ENFORCED (all gates clear). Exit 1 = BLOCKED (fix before done).
    Usage: .\enforce.ps1                          # all providers
           .\enforce.ps1 -Provider <name>         # single provider
           .\enforce.ps1 -SkipGit                 # skip git checks (mid-work)
           .\enforce.ps1 -Rebuild                 # auto-rebuild stale reports
           .\enforce.ps1 -OutFile <path>          # save full report

  tools/pipeline.ps1
    Complete build-to-verify pipeline (single JSON, multi-card model).
    ONE command. Runs EVERYTHING. No manual steps.
    Usage:
      .\pipeline.ps1 -Provider HI_HCJDC_OFML
      .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipBuild   # reports + audit only
      .\pipeline.ps1 -Provider HI_HCJDC_OFML -SkipEnforce # stop before enforce
      .\pipeline.ps1 -Providers TX_TLETS,HI_HCJDC_OFML    # batch
      .\pipeline.ps1 -All                                   # all active providers
    Steps (8):
      1. Build JSON (run build script). On a version change, automatically
         runs reset_test_package.ps1 -- rebuild restarts testing so logs
         line up with the new JSON.
      2. Build report (9 core tools via build_report.ps1; -IncludeExtended for the advisory ones)
      3. Extract metadata reference (METADATA_REFERENCE.txt)
      4. Sync CLAUDE.md provider table (sync_provider_table.ps1)
      5. Sync version docs (sync_version_docs.ps1 — STATUS, SQVR, JSON_INVENTORY, REBUILD_TRACKER, BUILD_NOTES, CHANGELOG)
      6. Cross-provider audit (audit_cross_provider.ps1 — ALL providers)
      7. Repo audit (audit_repo.ps1 — full monorepo)
      8. Enforce (enforce.ps1 — final gate)
    Stops on first failure with specific error reporting.
    Replaces manual multi-step workflow with one command.

  tools/generate_test_matrix.ps1
    Test matrix generator. Reads provider JSON and auto-generates a 9-phase
    test matrix: render verification, combo tests, any[] field tests, OOS
    routing, co-fire/deselect, negatives. Achieves 100% combo coverage.
    Called automatically by build_report.ps1 as step 9.
    Usage: .\generate_test_matrix.ps1 -Path <json> [-OutFile <path>]

  tools/run_test_matrix.ps1
    Automated test conductor. Reads a test matrix file and validates every
    test case against the provider JSON via combo simulation. Includes
    synthetic test data fallback for provider-specific fields.
    Called automatically by build_report.ps1 as step 10 only when -IncludeExtended is passed
    (advisory output, not read by enforce.ps1). Also used directly by emit_test_plan.ps1 and
    audit_simulator_parity.ps1 -- this demotion only removed build_report's own invocation.
    Usage: .\run_test_matrix.ps1 -Path <json> [-Matrix <file>] [-OutFile <path>]

  tools/simulate_response.ps1
    CJIS response handler simulator. Executes all QRDM handler transformations
    (Height, Name, VehicleYear, truncate, AttributeMapping) against comprehensive
    synthetic test data per entity. Target result: 0 MISSING / 0 UNMAPPED across all
    entities. No live data required. MISSING = attribute sourceField present in entity
    test data but absent from response (real gap). UNMAPPED = code value not in handler
    lookup table (real gap). Both must be 0.
    Called automatically by build_report.ps1 as step 11 only when -IncludeExtended is passed
    (advisory output, not read by enforce.ps1).
    Usage: .\simulate_response.ps1 -Path <json> [-Entity <name>] [-RunEdgeCases] [-OutFile <path>]

================================================================================
PREREQUISITES
================================================================================

  Git for Windows       https://gitforwindows.org/
                        Provides: bash, git, pdftotext (via MinGW)

  PowerShell 5.1+      Included with Windows. Scripts require -ExecutionPolicy Bypass.

  pdftotext             Included with Git for Windows MinGW.
                        Usage: pdftotext "source/<Provider>.pdf" "source/<PROVIDER>_DEVDOC.txt"
                        If missing: choco install poppler OR winget install poppler

================================================================================
AUTHORITATIVE SOURCE FILES (read-only)
================================================================================

  tools/_build_rms_bundle.ps1
    RMS bundle + CommSys QRDM built from KB specs. No external template dependency.

  tools/_build_layout_helpers.ps1
    QIF layout construction helpers (N, Inp, Sel, Dt, MakeLayouts, etc.).

  tools/_build_provider_helpers.ps1
    Provider boilerplate (Build-Auth, Build-Qmf, Build-ProviderQrdm, Build-EntitiesBundle, Write-ProviderJson).

  tools/_resolve_provider_json.ps1
    Shared active-JSON resolver (Get-ProviderRootJson). Locates a provider's
    active root JSON via the canonical chain: bare <PROVIDER>.json -> versioned
    <PROVIDER>_v<X.Y>.json (current standard) -> legacy _MC -> legacy _BASE.
    Dot-sourced by pipeline.ps1, reset_test_package.ps1, audit_test_coverage.ps1,
    sync_version_docs.ps1, audit_structure.ps1 so a versioned filename is found
    everywhere. (enforce.ps1, block_entity.ps1, build_report.ps1 carry their own
    equivalent fallbacks.)

  tools/_json_canonical.ps1
    Shared canonical JSON serialization + hashing (ConvertTo-Canonical,
    Get-Sha256Hex, New-NormalizedClone, Get-CanonicalJsonString). Key-sorted,
    array-order-preserving; New-NormalizedClone drops top-level version + plate
    year so reproducibility comparisons don't false-flag intentional variance.

  tools/_resolve_docs_path.ps1
    docs/ reorg pilot (2026-07-01, NJ_NJCJIS first). Get-DocsCategoryDir /
    Get-DocsPath / Find-DocsPath resolve a file to one of 4 category folders
    (tracking/reports/reference/deliverables) for a migrated provider, or the
    flat legacy docs/ location for any provider that hasn't migrated yet. A
    provider is "migrated" once ANY of its 4 category folders exists. Dot-
    sourced by build_report.ps1, post_test.ps1, reset_test_package.ps1,
    enforce.ps1, audit_repo.ps1, sync_version_docs.ps1, block_entity.ps1,
    audit_test_coverage.ps1, audit_supported_queries.ps1, run_test_matrix.ps1,
    generate_changelog.ps1, generate_test_matrix.ps1, diff_docs.ps1,
    check_test_preconditions.ps1, pipeline.ps1.
    Used by get_entity_fingerprints.ps1 and audit_reproducible.ps1.

  tools/audit_reproducible.ps1
    Build-reproducibility gate. Runs a provider's build script twice into scratch
    (via the $env:REPRO_OUTPATH hook in Write-ProviderJson -- committed files
    untouched), then checks DETERMINISM (two fresh builds identical) and CURRENCY
    (committed JSON == fresh build, version/PlateYear normalized). Non-determinism
    = FAIL; deterministic-but-stale commit = WARN. Opt-in via enforce -Reproducible.
    Usage: .\audit_reproducible.ps1 -Path <json> [-OutFile <path>] [-Strict]

  tools/_sim_helpers.ps1
    Canonical CommSys combo-firing predicate (Get-ComboConditions,
    Test-ComboConditionsCore) shared by test_commsys.ps1 and run_test_matrix.ps1
    so the two simulators cannot diverge. Condition model = form-state-key only
    (live-proven HI v3.4 T5); poisoned-array rule lives here.

  providers/FL_FCIC/FL_FCIC.json
    Reference for multi-query person forms (autoSelect, queriesToDeselect,
    DH-suffix pattern, GunQuery sourceField naming).

  providers/NJ_NJCJIS/
    v3.4 imported USx Provider Tenant + Newark Foundation Tenant (2026-05-21).
    Legacy repo (read-only): https://github.com/LooseConnection/NJ_NJCIS_JSON
    AVOID as template: v3.x series (split entity NJ/OOS); archived in phases/08_split_entities/.

  providers/NY_NYSPIN_EJUSTICE/
    Phase 1 reboot complete -- v1.1 built (2026-04-20), import PENDING.
    Legacy repo (read-only): https://github.com/Robsgam/NY_NYSPIN_EJUSTICE
    Best reference for: DALL+DALH invented keyRef, DH co-fire design,
    blank-default State (LIMITATION #30), NIBRS_SEX CommSys-only pattern.
    AVOID as template: old NY v1.0-v1.21 (multi-form split-entity before Phase 1 model).

  providers/AZ_AZDPS/
    Phase 1 -- v2.0 built (2026-04-30), import PENDING.
    Legacy repo (read-only): https://github.com/Robsgam/AZ_AZDPS
    Best reference for: all-on-one-person-card design (DL + DH + Wanted + Missing),
    dexStateUserId auto-populate pattern, yyyyMMdd date format, WMPI queries.

  tools/CODETYPE_TEST.json (generated by tools/build_codetype_test.ps1)
    Code source dropdown test file. Shows which codeTypeCategory values
    populate under which codeTypeSource. Use before committing any new dropdown.

================================================================================
ARCHIVE
================================================================================

  Archive deleted 2026-05-08. All content was merged into the 9 active KB files above
  during the 2026-05-04 consolidation.
