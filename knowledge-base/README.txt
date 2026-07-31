CONNECTCIC KNOWLEDGE BASE
===========================
Central reference for all ConnectCIC / CommSys provider JSON projects.
Last updated: 2026-06-09
Covers: 20 providers in consolidated monorepo (all galvanized to single-JSON, PascalCase)
  All 20: NJ/AZ/FL/NY/HI/TX/LA/CA_CLETS + TX_TLETS_CCH (variant of TX_TLETS) +
          CA_VENTURA_COUNTY/CA_CONTRA_COSTA/CA_CLETS_OCATS/CA_eSUN/CA_SAN_LUIS_OBISPO/
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
FILES IN THIS FOLDER (14 files, organized by question)
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
                           All 24 platform limitations (non-contiguous, #1-#37) + all 27 anti-patterns
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

  UNIVERSAL_SEARCH_HANDLERS.txt  "What handlers does the PLATFORM accept?"
                           AUTHORITATIVE registry captured from Confluence (HandlerConfiguration
                           .java): message/REST/attribute handlers incl. ones no provider uses,
                           the fallbackRule mechanism, the behaviors block, and the deployed-
                           vs-ours CA_eSUN deltas. CHECK HERE before saying a handler does not exist.

  RULE_HANDLERS.txt        "What handlers exist?"
                           25 handlers: 4 property paths, 9 handler functions,
                           15 attribute rule handlers, 1 special handler.
                           Origin map, dead ends, build script checklist.

  CANADIAN_QUERIES_AVAILABLE.txt  "Which providers have Canadian query metadata?"
                           REFERENCE ONLY -- cross-provider availability matrix
                           (CA_CLETS/FL_FCIC/OR_LEDS/NY_NYSPIN/NJ_NJCJIS). ZERO
                           providers have built these; blocked pending official
                           devdoc + metadata. Not part of the standard read order --
                           only relevant if/when Canadian queries are prioritized.

  JIRA_REFERENCE.txt       "What DEX ticket maps to this provider?"
                           Provider -> DEX ticket mapping (cloudId + per-provider
                           ticket/status/last-comment table). Reference for changelog
                           comment updates.

  PLATFORM_BUG_REPORT.txt  "What platform bugs are open/worked-around?"
                           Confirmed CommSys/ConnectCIC platform defects found during
                           testing that cannot be fixed via JSON config -- reproduction
                           steps + affected providers, submitted to engineering.

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
      5. Standard pattern comparison (queryLabel, ImageIndicator, keyReference, state)
      6. Visible-First Mandate (no hidden/auto-populated fields outside approved exceptions)
      7. Synthetic keyRef documentation -- WARNs on multi-combo QIDMs missing LIMITATION
         #21/#36 comment block in build script (BUILD_RULES.txt Section 15)
      (14 checks total; also label-hint CHECK 13, reachability CHECK 14, VehicleMakeCode-Sel.
       The camelCase and BASE-vs-MC cross-variant checks were removed 2026-07-24 -- obsolete
       under the single-JSON PascalCase model.)
    Called automatically by build_report.ps1 as step 6. Can also run standalone.
    Usage: -Path <json>
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

  tools/_archive/render_cad_guide.ps1  (ARCHIVED 2026-07-24 -- overlapped render_officer_guide)
    Was: provider CAD auto-dispatch reference (CAD-dispatched query paths + fields CAD
    auto-populates per combo). Consolidated into render_officer_guide.ps1; no longer active.

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
    CAD dispatch field alignment auditor. Validates CAD-populated field alignment,
    CAD_DISPATCH/FIRST_RESPONDER layout variants, combo defaults[] presence for
    CAD-populated fields, and QIDM sourceField alignment. (5 checks; the legacy
    Patch-8 camelCase-rename check and -Variant BASE|MC flag were removed 2026-07-24.)
    Usage: .\audit_cad.ps1 [-Path <json>] [-OutFile <path>]

  tools/audit_simulator_parity.ps1
    Tool-integrity gate. Confirms test_commsys.ps1 and run_test_matrix.ps1 both
    dot-source _sim_helpers.ps1 and use Test-ComboConditionsCore (no private/
    attribute-name condition logic). FAILs on drift. Run live by enforce Phase 2d.
    Usage: .\audit_simulator_parity.ps1 [-Path <json>] [-OutFile <path>]

  tools/audit_session_state.ps1
    Is SESSION_STATE.md still telling the truth? That file is the session PICK-UP POINT --
    injected into every new session by the SessionStart hook -- so its value is being TRUSTED on
    restart, and a stale one is worse than none. Its predecessor was a memory file: not in git,
    appended to instead of replaced, and it drifted badly enough to cost ~an hour of re-prompting
    per restart (2026-07-29). Now committed AND verified.
    Checks: every provider version it names matches the active JSON; it names no provider that no
    longer exists; its "Last updated" is not >14 days behind the last commit; and it has not grown
    past ~120 lines (the accumulation failure mode that killed the predecessor). Does NOT check
    prose. Gated by enforce PHASE 2l.
    Usage: .\audit_session_state.ps1 [-OutFile <path>]

  tools/audit_form_review.ps1
    Has a HUMAN looked at the rendered form for THIS build? Every other gate proves the
    REQUEST is correct; none proves the FORM is usable. Through 2026-07 every label/title/
    layout defect was caught by a person opening the rendered form -- a card titled
    "NCIC FIREARM QUERY" among "SEARCH BY" siblings, "Sex (optional)" beside "Date of Birth
    (required with Name)" on one card, fields wrapping mid-row. No tool flagged any of them.
    Records WHICH BUILD was reviewed in docs/tracking/<PROVIDER>_FORM_REVIEW.txt
    (<version> | <date> | <reviewer> | APPROVED or CHANGES-REQUESTED | <notes>).
    ADVISORY, always exit 0, surfaced by enforce PHASE 2k: a review is a human act and must
    not be manufacturable to satisfy a gate. Promote to blocking per-provider before shipping.
    Usage: .\audit_form_review.ps1 -Path <json> [-Record -Reviewer <name> [-Verdict ...]]

  tools/audit_sqvr_integrity.ps1
    Is the SQVR still telling the truth about the JSON? The SQVR is hand-maintained prose
    ASSERTING which combos exist, how many, and at what version -- and nothing verified it, so
    it rotted on every combo add/remove. It is also the document a tester reads to decide what
    to test, so rot converts directly into wasted tenant-test time.
    Checks: (1) every `keyReference:` named in the SQVR exists in the JSON, unless its block or
    enclosing numbered section is marked DORMANT / REMOVED / NOT BUILT / OUT OF SCOPE / NOT
    APPLICABLE / APPROVED SKIP (those report [NOTE] -- e.g. HI_HCJDC_OFML's QVV/QVP are
    legitimately documented dormant); (2) stated totals ("Total CommSys combos: N",
    "N CommSys QIDMs", "Architecture: ... N combos") match the JSON; (3) the stated
    "JSON version:" matches the active JSON filename.
    Deliberately NOT checked: whether every JSON combo has an SQVR block -- 13 never-tested
    providers use a lighter format with no per-combo blocks, and flagging those would be pure
    noise plus pressure for a pointless mass-rewrite.
    Found 2026-07-29: TX_TLETS (listed the QV combos removed at v4.9 + "21 combos / 7 Vehicle"),
    AZ_AZDPS (v3.3-deleted WMPI combos still marked [PENDING] test work + "8 QIDMs / 18 combos"
    + a "hidden InpH" badge description that does not match the built JSON).
    Gated by enforce PHASE 2j.
    Usage: .\audit_sqvr_integrity.ps1 -Path <json> [-OutFile <path>]

  tools/audit_log_combo_attribution.ps1    Did each saved test log's NAMED combo actually fire? The wire XML carries NO keyRef
    (MessageType is just the query name), so a log named for combo A is indistinguishable
    from one where a sibling B fired -- "84 logs PASS" can silently mean "76 combos
    exercised, 8 filed under combos that never ran". Replays each log's recorded QUERY
    STRING: routing is existence-based, so field PRESENCE fully determines the winner.
    Walks the owning QIDM in array order and compares first-match to the claim.
    Uses _sim_helpers.ps1 Test-ComboConditionsCore, so it cannot drift from the simulator.
    Strips _any / _af_<field> / _guardrail_vs_<other> suffixes to recover the base keyRef.
    Scopes the QIDM by the log header's query name -- NEVER by bare keyRef, which collides
    across QIDMs (NY_NYSPIN_EJUSTICE reuses RVEH/RCAR on Vehicle AND Boat; a bare lookup
    reported 8 bogus failures until fixed). See BUILD_RULES Section 13.
    Found 2026-07-29 -- 17 misattributed logs of 417: TX_TLETS x8 (2 genuinely unreachable
    combos), FL_FCIC x7 + CA_CLETS x2 (reachable combos whose any-field/any test fill
    included a higher-priority identifier and rerouted). NY/NJ/HI 100% clean.
    Usage: .\audit_log_combo_attribution.ps1 -Path <json> [-OutFile <path>]

  tools/audit_combo_reachability.ps1
    FILL-INDEPENDENT dead-combo gate. The platform fires the FIRST matching combination
    in a QIDM, so combo A is unreachable if some B ordered before it matches whenever A
    does. The silent case: B's extra set[] fields are all form-prefilled (initialValue),
    so B's set is always satisfied and B always wins. Such a combo still validates, still
    counts toward coverage, and can even carry a PASS test log -- the wire XML has no
    keyRef, so a log named for A is indistinguishable from one where B fired.
    Counts ONLY form initialValue as "always present" (combo defaults[] are excluded:
    apply-order vs matching is unverified, and a combo's own defaults cannot satisfy its
    own set[]). Conditions on a prefilled field are resolved -- EXISTS is always true,
    NOT_EXISTS always false. RMS QIDMs skipped (intentional specificity cascade).
    A dead combo registered in <PROVIDER>_ACCEPTED_DIVERGENCES.txt with rule
    'dead-combo*' reports [NOTE] instead of [FAIL].
    Found 2026-07-29: TX_TLETS RQLicensePlateNumber + RQVehicleIdentificationNumber
    (both behind FinancialResponsibilityType=E), CA_SAN_LUIS_OBISPO B2.O (ungated OLN
    twin), LA_LEMS DQ (ImageIndicator must always be defaulted, so existence-gating on
    it can never work).
    Usage: .\audit_combo_reachability.ps1 -Path <json> [-OutFile <path>]

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
    Run with -All to regenerate METADATA_REFERENCE.txt for all 20 providers.
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

  tools/audit_log_metadata.ps1
    DIRECT log-vs-metadata integrity audit: parses each saved test log's COMMSYS wire XML and
    validates it against the metadata XML -- every <Request> field must be a metadata-defined
    field for that query (or a known form-only field), and the present field-set must satisfy a
    real metadata combination's required set[] (Choice/OR alternatives expanded). This is the
    direct proof the CommSys query is 100% metadata-correct, vs the transitive metadata<->JSON
    (audit_metadata) + JSON<->plan (audit_log_content) chain. Wired into enforce.ps1 PHASE 6d;
    providers without current-version logs or metadata XML pass by absence. Uses _metadata_parse.ps1.
    Usage: .\tools\audit_log_metadata.ps1 -Provider <name> [-Quiet]

  tools/_metadata_parse.ps1
    Shared metadata-XML parser (dot-sourced by audit_log_metadata): Get-MetadataTransactions
    returns per-query fields + combos with requiredSets (alternative required-field arrays,
    expanding <Choice> OR-branches and nested <Set> AND-groups). Also $MetaFormOnlyFields,
    $MetaFieldAliases (mirrors audit_metadata.ps1 + State<->RegistrationState wire alias),
    Test-MetaFieldEquiv. One source of truth so the log-metadata and JSON-metadata gates agree.

  tools/emit_picklist_scope.ps1
    Emits providers/<P>/logs/<P>_PICKLIST_SCOPE.json -- every visible FormSelect per entity
    (fieldId + category/source) -- for the browser's __usxScopePicklists, which opens each
    dropdown UNFILTERED and dumps the tenant's actual option list (cap 500/field).
    Usage: .\tools\emit_picklist_scope.ps1 -Path providers/<P>/<P>_vX.Y.json

  tools/audit_xml_consistency.ps1
    On-demand (manual; not run by enforce/pipeline/build_report).
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

  tools/audit_picklist_scope.ps1
    ADVISORY picklist-scope reminder (never blocks; emits [NOTE], always exits 0). Reminds when
    a provider still owes its one-time tenant picklist capture (no TENANT_PICKLISTS.json) or when
    a build introduced a new non-null code category the capture doesn't cover. Only real
    codeTypeCategory dropdowns are compared (attributeTypeId STATE/SEX/VEHICLE_MAKE capture as
    null and are tenant-stable). Required categories are scoped to the ENTITIES bundle (not RMS).
    enforce.ps1 surfaces the NOTE without affecting the verdict/exit code.
    Usage: .\tools\audit_picklist_scope.ps1 -Path <provider.json>

  tools/_archive/audit_metadata_field_coverage.ps1  (ARCHIVED 2026-07-24 -- advisory, never gated)
    Was: ADVISORY "form behind the metadata" detector ([FIELD-GAP]/[OK], always exit 0) flagging a
    built-combo metadata field not wired into the query's QIDM and not on the curated skip list.
    This is the class that hid on NY DGRP. Archived (on-demand, never enforce-gated); the
    devdoc/metadata coverage gate now lives in audit_supported_queries.ps1 + audit_metadata.ps1.

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

  tools/_combo_value_resolver.ps1
    Shared module: combo set[]/any[] test-value resolution (Get-ComboTestValue,
    Get-ComboValueOverrides). Extracted 2026-07-06 from emit_test_plan.ps1 and
    generate_test_matrix.ps1's near-identical Get-TestValue functions after a line-by-line
    diff confirmed ~35 identical cases plus a documented set of real, pre-existing
    behavioral differences (QIF-default awareness, date format, a few provider-specific
    fields) -- see the module header for the full list and the -Caller parameter that
    reproduces each tool's exact prior output. Verified byte-identical output before/after
    extraction (NY_NYSPIN_EJUSTICE emit_test_plan + generate_test_matrix, FL_FCIC
    generate_test_matrix). Dot-source only; defines functions, no side effects.

  tools/_metadata_keyref_match.ps1
    Shared module: XML-keyRef-to-JSON-built-combo matcher (Get-KeyRefDeclarations,
    Resolve-XmlKeyRefBuild). Extracted 2026-07-06 -- audit_metadata.ps1 CHECK 4 and
    extract_metadata_reference.ps1's BUILD COVERAGE each independently decided "is this
    XML keyRef built," using different heuristics that could disagree (confirmed live on
    FL_FCIC's QV/QW). Declaration-first: a provider's ACCEPTED_DIVERGENCES.txt may carry
    keyRef-level `built-as`/`not-built` rows (new rule types, same file as the existing
    field-level rules); falls back to the mechanical keyRef/dotted-base/synthetic-suffix
    rule otherwise. The mechanical rule alone is insufficient -- NJ_NJCJIS's
    RANDFULL/RANDFULLN compound rename requires an explicit `built-as` declaration (see
    NJ_NJCJIS_ACCEPTED_DIVERGENCES.txt). Verified: byte-identical output for providers/
    keyRefs with no declaration; enforce.ps1 FAIL/WARN counts unchanged for all 5 in-scope
    providers. Dot-source only; defines functions, no side effects.

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

  tools/report_test_status.ps1
    Portfolio live-test status from ACTUAL log data. Reads the RESULT: lines of
    the real logs/<Entity>/<PROVIDER>_v<ver>_*.txt files (version resolved from the
    active root JSON filename) and reports per-entity PASS/FAIL/PENDING + an
    ALL-PASS/PARTIAL/NEVER-TESTED/NOT-TRACKED roll-up. Deliberately does NOT read
    logs/.test_state.json (its status field is block-lock bookkeeping, not a test
    ledger, and drifts). Use this to answer "what is tested and passing right now".
    Shares its classifier with portfolio_status.ps1 via tools/_test_status_lib.ps1.
    Usage: .\report_test_status.ps1 [-Provider <name>] [-OutFile <path>]

  tools/portfolio_status.ps1
    THE canonical one-screen portfolio status table. One fixed-column table --
    Provider / Ver / Meth (GALV|LEGACY) / Validator (P/F/W/LIM) / Live-test
    (state tested/5 (#logs)) -- plus totals and a git footer. Assembled from the
    active root JSON filename, the newest VALIDATOR_REPORT, and actual log RESULT
    lines (log-truth), never hand-typed. Reference this verbatim for any "where is
    everything" question instead of hand-assembling a status table (which drifts).
    Usage: .\portfolio_status.ps1 [-Provider <name>] [-OutFile <path>]

  tools/_test_status_lib.ps1  (shared module, dot-sourced)
    Single source of truth for per-provider status classification, consumed by both
    report_test_status.ps1 (narrative view) and portfolio_status.ps1 (table view) so
    the two cannot drift. Exports Get-ProviderTestState / Get-ProviderValidatorScore /
    Get-ProviderMethodology.

  tools/audit_branch_currency.ps1
    BRANCH CURRENCY (enforce PHASE 2o, ADVISORY -- never blocks). Warns when the long-lived working
    branch drifts from main: main older than N days, branch more than N commits ahead, or a branch
    named for ONE provider carrying commits that touch others. Origin (Rob 2026-07-30, "keep these
    things in line... so nothing gets stale and nothing gets left behind"): nothing watched the gap
    and it reached 216 commits / 8 days unnoticed, while main's TX still could not run out-of-state
    plate or VIN queries. Advisory because Rob imports JSON from the provider ROOT FOLDER (working
    tree), so branch state does not affect installs -- the point is that drift becomes a decision
    instead of an accident. Merging is a human call about what ships to a customer.
    Usage: .\audit_branch_currency.ps1 [-MaxAhead 50] [-MaxMainAgeDays 7] [-OutFile <path>]
  tools/audit_query_trace.ps1
    QUERY TRACE -- every metadata combination -> built? reachable? if not, WHY? Answers the one
    question no other gate asks: "are we missing a COMBINATION, and is one of our own form
    defaults the reason?" Classifies each metadata combo BUILT / PREFILL-DEAD (a sibling wins
    because its extra set[] field is form-prefilled -- names the prefill to remove; RECOVERABLE)
    / SHADOW (identical required set[], needs a discriminating condition) / MISSING (adjudicate
    against devdoc Basic scope). Advisory: metadata is FIELD authority, devdoc is QUERY authority,
    so a MISSING may be legitimately out of scope.
    Origin (TX_TLETS v4.13 post-mortem, 2026-07-29): TX shipped 3 of 7 vehicle combinations with
    141 PASS / 0 FAIL. audit_supported_queries checks BUILT->devdoc (blind to a never-built combo);
    audit_metadata CHECK 5 checks PRIMARY-FIELD coverage, which an in-state combo satisfies (blind
    to a missing out-of-state variant on the same field); audit_combo_reachability only walks
    combos that ARE built. TX's two devdoc "(OutofState)" paths were deleted as dead when they were
    only unreachable because the form prefilled their discriminators.
    PARSER NOTE -- the metadata shape is <Combination><Requirements><Set>, fields carry @reference
    (NOT InnerText), and <Any>/<Choice> are nested INSIDE <Set>. Matching is CONTAINMENT, not
    equality, and both sides are normalized through the QIDM attribute sourceFields (metadata says
    'Name'/'OperatorLicenseNumber'; built set[] says NameLast,NameFirst / OperatorLicenseNumberDH).
    Getting any of that wrong silently reports every combo as an empty-set SHADOW -- validate any
    change against TX_TLETS, whose answer is known (17 built / 4 PREFILL-DEAD / 0 SHADOW / 0 MISSING).
    NESTED-CHOICE NOTE (2026-07-30) -- a <Choice> may contain nested <Set> children, not just
    <Field>: <Set><Choice><Set>..</Set><Set>..</Set></Choice><Any>..</Any></Set>. Each nested
    <Set> is a complete ALTERNATIVE requirement set (typically the in-state vs out-of-state
    branch), so one metadata Combination expands to N logical combinations. A Choice/Field-only
    XPath returns EMPTY on that shape and the outer <Set> reads requirement-free -- which is how
    NY_NYSPIN_EJUSTICE's DALL x2 and RVEH were wrongly reported MISSING. 13 of 18 providers use
    the nested shape (TX_TLETS has 60), so validate any parser change against BOTH TX_TLETS
    (flat Choice/Field) and NY_NYSPIN_EJUSTICE (nested Choice/Set). A fourth shape exists too:
    TX GunQuery/QG puts a nested <Set> and a bare <Field> as SIBLINGS in one <Choice>.
    Usage: .\audit_query_trace.ps1 -Provider <name> | -Providers a,b | -All [-OutFile <path>]
  tools/audit_devdoc_order.ps1
    DEVDOC ORDER -- is the built combination order consistent with the DEVDOC listing order?
    Rob 2026-07-31: ordering has TWO lines. Line 1 is SPECIFICITY (an ungated subset ahead of a
    superset steals every fill -- audit_combo_reachability + build_phase1 [3]). Line 2 is the DEVDOC
    LISTING ORDER, the TIEBREAKER when two DIFFERENT queries could both execute on the filled fields.
    NJ Boat forced it: hull and registration-number are separate, EQUALLY-SPECIFIC single-identifier
    searches, so specificity CANNOT resolve them and the devdoc's order is the product answer.
    Nothing verified line 2 until now -- Rob caught that, the tooling did not, and it is the dimension
    behind the QV/QW mess that was hand-ruled three times and regressed twice.
    Flags an INVERSION -- a devdoc-LATER item positioned AHEAD of a devdoc-EARLIER one -- but ONLY
    when the earlier-positioned combo is UNGATED. A condition on it legitimately hands the over-fill
    back, which is exactly how NJ is CORRECT despite QB (devdoc #2) sitting first: QB carries
    'BoatHullIdNumber NOT_EXISTS' so a hull fill defers to QBN (devdoc #1). Flagging that would be a
    false positive.
    MUTATION-PROVEN: nj-devdoc-order-inversion strips that guardrail and the gate goes 0 -> 2 findings
    (KILLED). Takes -Path precisely so it CAN be mutation-tested; build_phase1 [3b] delegates here so
    there is ONE implementation.
    KNOWN LIMIT, PRINTED EVERY RUN: only combos that MAP to a devdoc item are checked. Synthetic
    combos with no devdoc counterpart (3/8 NJ, 5/19 TX, 7/16 NY, 8/30 FL, 11/25 CA) get NO order
    verification, and neither does the order BETWEEN two synthetics. The mapped/unmapped counts are
    always shown so the coverage is never implied.
    Usage: .\audit_devdoc_order.ps1 -Path <json> [-OutFile <path>]
  tools/test_phase2.ps1
    PHASE 2 -- TEST. Pre-flight before a sweep (-Provider X) and validation after each ingest
    (-PostIngest). Rob 2026-07-31, after having to force the spec-plan check himself: "this gap I had
    to force you to close needs to be wired in when I say test."
    So STEP 1 is the SPEC-PLAN vs JSON-PLAN comparison, and it BLOCKS. emit_test_plan derives tests
    from the BUILT JSON -- a MIRROR, where no combo means no test means no failure -- and that is what
    6c validates against. emit_test_plan_spec derives from DEVDOC + METADATA and is the INDEPENDENT
    statement. The DELTA is the point: a JSON plan LARGER than the spec plan is not reassuring, it
    usually means the spec parser could not read the devdoc and the independent check covers nothing.
    NJ_NJCJIS is the proof case -- JSON plan 35 tests / 5 entities, spec plan 7 / Vehicle only,
    because NJ's devdoc uses a MULTI-LINE "Possible Combinations" layout the parser reads only INLINE.
    Its enforce 2p read [PASS] over nine unparsed blocks and nobody would have known.
    RULE: the spec plan must cover every entity the JSON plan covers; a missing entity means 2p/2q
    PASS on that provider is UNPROVEN for it, not clean. A sweep may still proceed on the JSON plan
    (that is what validated TX's 89 and NY's 64), but the shortfall is REPORTED, never silent.
    -PostIngest runs all FOUR log gates -- 6c content, 6d metadata, 2i attribution, plan completeness
    -- because two is provably not enough: FL and TX both passed 6c+6d while carrying mis-attributed
    logs and uncaptured plan tests.
    Usage: .\test_phase2.ps1 -Provider <NAME> [-PostIngest] [-OutFile <path>]
  tools/build_phase1.ps1
    PHASE 1 -- BUILD. ONE command, hands-off, ends in a SHORTCOMINGS report with an INTERPRETATION
    section. Rob 2026-07-31: the whole process is three functions -- BUILD (this), TEST (manual
    render check + tenant log capture/ingest + build-log iteration + third-party updates), and
    FINALIZE (a store for COMPLETED JSONs, deliberately unspecified until we get there).
    Phase 1 proves, in Rob's order: (1) every devdoc combination accounted for, (2) every OPTIONAL
    field combination accounted for, (3) queries PRIORITISED as the devdoc lists them, (4) shadow
    queries identified and unable to fire ahead of a higher-order/more-required combination,
    (5) fidelity + reachability + trace, (6) gate efficacy, (7) enforce.
    CHECKS 3 AND 4 ARE NEW and are the generalisation of the most expensive lesson of 2026-07-29..31:
    the platform fires the FIRST matching combination, so ORDER IS SEMANTICS. An UNGATED combination
    whose set[] is a strict SUBSET of a later one steals every fill from it -- exactly what TX's
    QV/QW did. That was hand-ruled three times and regressed twice because NO gate looked at order.
    The check flags subset-ahead-of-superset unless the earlier combo carries a discriminating
    condition.
    The INTERPRETATION section is the point, not decoration: it encodes the judgement calls already
    paid for -- check built?/devdoc-Basic?/subset-shadowed? before removing any prefill (HI's 2 and
    CA's 12 were all already-adjudicated shadows, and removing CA's mandatory-everywhere purposeCode
    prefill would break CAD); fix order or add a condition, NEVER delete the superset (that cost TX
    two out-of-state paths at v4.13); and the devdoc test on a dropped optional points OPPOSITE ways
    on FL v7.14 vs HI M55S, so run it per provider.
    Usage: .\build_phase1.ps1 -Provider <NAME> [-Rebuild] | -All [-OutFile <path>]
  tools/_divergence_rules.ps1  (shared module, dot-sourced)
    ONE definition of what an ACCEPTED_DIVERGENCES rule NAME means, so the ENFORCER
    (audit_metadata) and the MEASURER (audit_suppression_scope) can never disagree -- if they did,
    the measurement would be fiction. Classes: to-set (promoted-to-set) | to-any (promoted-to-any,
    demoted-to-any, added-to-any) | existence (not-built, devdoc-combo-unbuilt,
    metadata-shadow-autofired, dead-combo-*, dropped-combo, shadow-unbuilt-*, missing-primary-combo)
    | other (devdoc-optional-unreachable, built-as, prefilled-mandatory-autopopulated,
    precondition-adjudicated-satisfied). 'other' licenses NOTHING by design -- those rows adjudicate
    officer-facing behaviour or a precondition, not field placement or combo existence; if one needs
    to suppress a check, give it a properly-named rule rather than widening the class.
    A check may only be silenced by a row whose class matches what that check tests. audit_metadata
    Test-AllowListed takes -AcceptClass for this.
    Test-DirectionAwareOptIn: per-provider gate. Narrowing is STRICTER than legacy behaviour and can
    turn a GREEN provider RED (a real finding stops being silenced), so a provider opts in with
    '# SUPPRESSION-SCOPE: direction-aware' in its <P>_ACCEPTED_DIVERGENCES.txt -- marker lives with
    the data it governs, same convention as '# BASE-SYNC:'. Without it, behaviour is byte-identical
    to before. TX_TLETS opted in 2026-07-30 (was 0 findings / 16-16 kills, so downside bounded);
    every other provider opts in at its own rebuild turn, never as a portfolio sweep.
  tools/audit_suppression_scope.ps1
    SUPPRESSION SCOPE -- is each accepted divergence as narrow as it was GRANTED? READ-ONLY,
    changes no verdict, cannot turn a provider red. An ACCEPTED_DIVERGENCES row records ONE
    adjudicated decision about ONE field on ONE combo, but audit_metadata's Test-AllowListed
    matched on (query,keyRef,field) and DISCARDED the Rule column -- so a row saying "regionId may
    ride in RQ{VIN} any[]" also silenced the OPPOSITE defect, "regionId wrongly PROMOTED INTO
    set[]". Invisible for months because suppression leaves no trace: a check that stops speaking
    looks exactly like a check with nothing to say. Found only by mutation testing --
    audit_gate_efficacy flipped promote-any-to-set from KILLED to SURVIVED the moment 4 legitimate
    promoted-to-any rows were added to TX_TLETS.
    THE ACCEPTED-DIVERGENCE TAX: every entry buys a blind spot, and its WIDTH is set by how
    precisely the suppression is keyed, not by what the entry claims. 2026-07-30 baseline:
    116 rows / 209 over-broad suppressions / 15 providers; 3 call sites still direction-blind
    (audit_metadata CHECK 4e, CHECK 4, CHECK 5).
    FIXABLE CHEAPLY because the rule vocabulary ALREADY encodes direction (promoted-to-set vs
    promoted-to-any vs demoted-to-any vs not-built) -- the enforcement just threw the name away.
    Fix = pass -IgnoreRule at each blind call site; CHECK 4d is the worked pattern.
    Narrowing can turn a GREEN provider RED (a real finding stops being silenced), so it is a
    release-timing call: one provider at a time, never a portfolio sweep.
    Its $checks call-site inventory is HAND-MAINTAINED -- add a registry-reading check without
    listing it there and this tool under-reports. Re-derive with
    Select-String tools\*.ps1 -Pattern 'ACCEPTED_DIVERGENCES|Test-AllowListed'.
    Usage: .\audit_suppression_scope.ps1 [-Provider <NAME>] [-Detail] [-OutFile <path>]
  tools/audit_requirement_fidelity.ps1
    REQUIREMENT FIDELITY -- does each BUILT combination require EXACTLY what its metadata branch
    requires? The dimension no other gate measured. audit_metadata asks whether a field is
    metadata-DEFINED; audit_query_trace whether a combo EXISTS; audit_combo_reachability whether
    the form can REACH it; 6d audit_log_metadata whether a captured request SATISFIES a combo. A
    combination can pass all four while built LOOSER than the spec, and 6d cannot ever catch that
    because it validates the log against the combination AS WE BUILT IT -- a gate that reads its
    expectation from the artifact under test cannot see that the artifact is wrong. This one reads
    the expectation from the XML only.
      UNDER-REQUIRED  metadata mandatory, built optional/absent -> can send an INCOMPLETE request
      OVER-PERMITTED  built any[] member the branch does not define -> can send a rejected field
    Found NY RVEHOUT: the out-of-state plate branch requires Plate+PlateTypeCode+PlateYear+State
    all mandatory; we built set[Plate,State] with the other two in any[].
    WARN-only by design -- a build may legitimately tighten or split a branch, and only Rob rules
    on combination semantics. NEVER auto-tighten a set[]: a mandatory field the form PREFILLS
    becomes an always-true discriminator and kills every sibling after it (BUILD_RULES 24).
    REGISTRY-AWARE: reads <P>_ACCEPTED_DIVERGENCES.txt and downgrades registered decisions to
    [NOTE]. A metadata alternative registered shadow/unbuilt (TX QV, QW) is SKIPPED rather than
    force-matched to a sibling -- force-matching is what reported CPL against DQOLN. A field
    registered `promoted-to-any` is not an over-permit (Rob standing rule: never DROP a
    devdoc-optional combination field, ride it in any[]). Registry keyRefs are BUILT names
    (QVLicensePlateNumber) or devdoc pointers ("(devdoc #3)") while metadata keyRefs are bare
    (QV, QW), so matching is exact | prefix | word-boundary-in-row-text, deliberately generous;
    the NOTE count is printed so over-suppression stays visible. TX_TLETS: 0/0 with 12 NOTE.
    NON-VACUITY is proven live, not asserted: the same gate reports NY RVEHOUT and 17 CA_CLETS
    findings, so the suppression has not disabled it.
    FALSE-POSITIVE SOURCES, all four hit on the first run -- fix these before believing output:
    Name is a COMPOSITE (metadata 'Name' vs built NameLast/First/Middle/Suffix) and must match
    BIDIRECTIONALLY; form-only fields (ImageIndicator/State/PurposeCode/Attention/email/reasonCode)
    are never over-permits; the metadata->built assignment must be 1:1 and indexed POSITIONALLY,
    because a transaction can declare the SAME keyRef twice (NY RNAM, TX QB/RQ, FL FRQ) and every
    duplicate carries alt=0, so a natural key collides; and aliases matter
    (GunSerialNumber/ArticleSerialNumber -> serialNumber, CaRequestPurposeCode -> purposeCode,
    State -> RegistrationState). Unbuilt/parked combos (TX QV, QW) spill their alternatives onto a
    sibling and read as UNDER-REQUIRED -- adjudicate against the accepted-divergence registry.
    Usage: .\audit_requirement_fidelity.ps1 [-Provider <NAME>] [-OutFile <path>]
  tools/audit_devdoc_combinations.ps1
    DEVDOC -> BUILT, at COMBINATION granularity (enforce PHASE 2p). The one direction nothing
    else checked. PHASE 2e checks BUILT->devdoc and only by QUERY NAME ("is BoatQuery in the
    Basic Queries Supported list?" -- yes, for months, while ~24 combinations under those 6 names
    were never compared to anything). PHASE 2n enumerates METADATA but only for transactions that
    already have a QIDM. Every other tool enumerates the JSON. So a devdoc-listed combination that
    was never built sat outside the whole gate stack -- and could not fail a test either, because
    the TEST PLAN IS GENERATED FROM THE JSON: no combo, no test, no failure.
    Origin (2026-07-30): TX_TLETS v4.16 read 36 PASS / 0 FAIL / 0 WARN with 95/95 tenant tests,
    and two devdoc-Basic combinations were unbuilt AND unrecorded -- BoatQuery #2 "(OutofState)
    Name, BirthDate, State" (out-of-state boat by OWNER NAME) and DriverLicenseQuery #3
    "Name, BirthDate, SexCode, RaceCode" (= metadata keyRef QW). Both defensible on inspection
    (metadata BoatQuery defines no Name/BirthDate; TX builds -SkipRace so RaceCode is wired
    nowhere) -- but defensible is a HUMAN judgement that must be RECORDED, not an absence.
    [FAIL] UNWIRED  = a mandatory devdoc field for that path is in NO built combo's set[]/any[]
                      for that query. Mechanical, no judgement needed. Suppress by recording it
                      in docs/tracking/<P>_ACCEPTED_DIVERGENCES.txt, rule devdoc-combo-unbuilt.
    [NOTE] NO-EXACT = all mandatory fields wired but no single set[] covers them. Usually
                      legitimate (metadata is field-authority and may require more, or one devdoc
                      item is split across keyRefs). Human review, never blocks.
    PARSER NOTE -- devdoc text is pdftotext output, so it wraps and repeats; the tool glues
    continuation lines, attributes each "Possible Combinations" line to the nearest preceding
    <X>Query heading, strips (InState)/(OutofState) qualifiers, and treats [bracketed] fields as
    optional. It maps devdoc field NAMES to fieldIds via an alias table that is load-bearing, not
    cosmetic: the first portfolio run reported 48 FAIL, and the AZ ones were false -- AZ wires
    BadgeNumber as dexStateUserId, and OR/TN/OH wire ArticleSerialNumber as the generic
    serialNumber. TWO parser bugs were caught pre-ship and both are guarded now: (1) a function
    returning @($x) UNWRAPS to a bare string in PowerShell, so callers doing [0] took the first
    CHARACTER -- every wired set became a set of letters and the tool claimed 20/20 UNBUILT on a
    provider that is 21/21 correct; (2) it now FAILS LOUDLY if the built-side walk finds no
    queries or a query with 0 wired fields, instead of reporting that as a coverage gap.
    -Explain prints both the parsed devdoc items AND the built-side wired inventory -- a parser
    that cannot show its intermediate state is indistinguishable from one that is silently wrong,
    which is the entire failure class this tool exists for. Validate any change against TX_TLETS,
    whose answer is known: 0 FAIL / 4 NOTE with the divergences recorded (2 FAIL without them).
    Usage: .\audit_devdoc_combinations.ps1 -Path <json> | -All [-Explain] [-OutFile <path>]

  tools/audit_devdoc_optionals.ps1
    Every devdoc combination x EVERY SUBSET of its [bracketed] optionals (enforce PHASE 2q,
    ADVISORY). Every other gate checks only MANDATORY fields. An optional can do two things that
    a mandatory-only check cannot see:
      1. NO-FIRE / RE-ROUTE -- the fill matches no combo (our set[] demands a field the devdoc
         calls optional), or adding the optional changes which keyRef wins first-match.
      2. DROPPED OPTIONAL -- the officer types a devdoc-legal optional, it is in no matching
         combo's set[]/any[] (so the LIMITATION #1 union pool does not carry it either), and it
         is silently not transmitted. The query succeeds, just narrower than asked. Nothing errors.
    Origin (2026-07-30, Rob: "account for every combination with every combination of optionals --
    that was a long standing directive"): TX_TLETS v4.17 sat at 36 PASS / 0 FAIL while 20 of 252
    devdoc-legal fills were defective. 17 dropped an optional (BirthDate on CPL, FRT on DPSI --
    metadata omits both from any[]; Rob's standing rule is that a devdoc-OPTIONAL combination
    field is NEVER dropped, it rides in any[]). Fixed at v4.18. The other 3 fire no combo at all.
    Reuses the devdoc parser from audit_devdoc_combinations.ps1 via its -Explain output, and
    _sim_helpers.ps1 (Get-FiringKeyRef / Test-ComboMatches) for routing -- deliberately NOT a
    second parser or a second predicate; four parser bugs in this toolchain came from
    re-implementing something that already existed. Prefills are seeded into every fill because a
    form initialValue is present on every real submission.
    ADVISORY on purpose: the residual "devdoc-legal fill sends no query" class is a PRODUCT call
    (accept that the platform auto-fires the shadow that would have covered it, vs build
    something). A tool must not manufacture that acceptance. Record dispositions under rule
    `devdoc-optional-unreachable`, then promote to blocking.
    Usage: .\audit_devdoc_optionals.ps1 -Path <json> [-Verbose2] [-OutFile <path>]
  tools/audit_gate_efficacy.ps1
    MUTATION TESTING FOR THE GATE SUITE -- the only tool here that audits the TOOLS instead of the
    config. Answers the question that makes every other green light meaningful: "does this gate
    actually FAIL when the defect it exists to catch is present?"
    Origin (Rob 2026-07-30: "i need a way for me to trust your output. make it happen."): "0 FAIL"
    is produced identically by (a) a correct config and (b) a broken/inert check, and Rob had no way
    to tell them apart. Not hypothetical -- in ONE session: sync_provider_table was silently inert
    for all 20 providers (score regex demanded a /LIM segment the table no longer had);
    audit_query_trace read metadata field names from InnerText instead of @reference and called
    every combination an empty-set SHADOW; audit_devdoc_combinations hit the PowerShell
    single-element-array unwrap and claimed 20/20 UNBUILT on a 21/21-correct provider; audit_metadata
    CHECK 4e compared against the query-wide set[] union instead of per-keyReference.
    METHOD: for each defect CLASS, inject that exact defect into a throwaway replica and run the
    owning gate. Detection = findings INCREASE over baseline (not "any finding at all" -- some gates
    legitimately carry adjudicated findings, e.g. audit_devdoc_optionals reports 3 NO-FIRE fills on
    TX by design; demanding a spotless baseline would make those gates untestable). Counts [WARN]
    as well as [FAIL], because several checks are deliberately warn-level.
    KILLED = gate caught it, so its PASS is evidence. SURVIVED = gate is blind, so its PASS proves
    nothing for that class. INVALID = harness misconfigured; fix the harness, not the gate.
    DISCIPLINE THIS TOOL ENFORCES ON ITSELF: a mutation must CREATE the defect, not merely resemble
    it. The first draft prefilled LicensePlateYear to test prefill-death -- but Year is in BOTH
    RQ and REG set[], so it starves neither, and the tool falsely accused audit_combo_reachability.
    The real mutation is prefilling LicensePlateTypeCode (RQ is index 0 and PlateTypeCode is its
    only extra set[] field vs REG, so prefilling it starves REG) -- the exact prefill removed at
    v4.14. Always verify the mutant on disk before believing a SURVIVED verdict.
    FIRST RUN, TX_TLETS v4.18: 12 KILLED / 3 SURVIVED. The survivors are REAL GATE DEFECTS:
      verify_build VehicleMakeCode gate -- recurses all 3 layout variants then Sort-Object -Unique,
        so a field that is FormInput in `default` but FormSelect in CAD_DISPATCH reports PASS.
        Proven: mutant on disk reads {"resolvedName":"FormInput"} and the gate printed
        "[PASS] VehicleMakeCode field 'VehicleMakeCode' is FormSelect".
      audit_metadata CHECK 4e -- does not detect stickerNumber demoted out of DPSI set[] into any[].
        The keyRef-scoping guard is ruled out (0 suppression traces when instrumented); an earlier
        continue short-circuits. Root cause NOT yet isolated.
      audit_metadata CHECK 4d -- does not detect regionId forced into RQ{VIN} set[].
    Usage: .\audit_gate_efficacy.ps1 -Provider TX_TLETS [-Only <substring>] [-Scratch <dir>] [-OutFile <path>]
  tools/fuzz_gate_efficacy.ps1
    RANDOM mutation testing -- the companion audit_gate_efficacy structurally cannot be.
    Origin (Rob 2026-07-31: "can you generate random mutations? i feel like this is the same issue
    we had with testing the json queries against itself."). He is right and it is the same
    circularity one level up: audit_gate_efficacy's catalogue is HAND-AUTHORED, so every entry is a
    defect someone already thought of, aimed at the gate already known to own it. A 16/16 KILLED
    score therefore proves the gates catch the ANTICIPATED classes and says nothing about the ones
    nobody wrote a mutation for -- the same shape as validating a JSON against a plan derived from
    that same JSON: check and subject share an author, so they agree by construction.
    METHOD: remove the author. Mutation SITES are ENUMERATED FROM THE JSON ITSELF (118 on
    NJ_NJCJIS) -- set->any, any->set, drop-set, drop-any, over-permit grafted from a SIBLING
    combination (a real transaction field, not an invention, which would be caught trivially and
    prove nothing), drop-conditions, swap-order, prefill a form field, FormSelect->FormInput. Then
    the WHOLE panel runs and the only question asked is: did ANY gate react? Nothing is aimed.
    Detection is by new finding TEXT, not a count delta (a mutation that WORSENS an existing finding
    line is invisible to counting -- that hole produced two false SURVIVED verdicts on 2026-07-30).
    A SURVIVOR IS A CANDIDATE, NOT A VERDICT. Harmless-by-construction edits survive CORRECTLY: an
    any[] addition the devdoc already lists as optional, or reordering two combinations that can
    never both match. Triage each; promote the triaged-real ones into audit_gate_efficacy $MUTS so
    they become permanent regression tests, then fix the gate.
    -Seed makes every run reproducible and is printed, so any survivor can be re-derived exactly.
    WHAT ITS FIRST WIDE RUN FOUND WAS A DEFECT IN THE HARNESSES THEMSELVES: `Set-Content -Encoding
    utf8` writes a BOM under Windows PowerShell 5.1 (pwsh 7 does not), and validate.ps1 rightly
    FAILs on a BOM -- so under 5.1 EVERY mutation was "caught" by the BOM check rather than by the
    gate owning its defect, scoring a meaningless CAUGHT 30/30. audit_gate_efficacy carried the
    identical line, so its KILLED score was equally BOM-dependent under 5.1. Both now write UTF-8
    without BOM explicitly. Lesson: a harness whose own artifact trips a gate cannot measure it.
    audit_query_trace.ps1 is DELIBERATELY EXCLUDED from the panel (takes only -Provider, cannot be
    aimed at a mutated replica; leaving it in reported a vacuous run on every mutation, which reads
    as a gate that never objects). Its PREFILL-DEAD class is covered by audit_combo_reachability.
    Usage: .\fuzz_gate_efficacy.ps1 -Provider <name> [-Mutations 15] [-Seed <int>] [-OutFile <path>]
  tools/audit_log_inflation.ps1
    COVERAGE-INFLATION ATTACKS. Every other log gate asks "is what we sent correct?" -- none asks
    "are these N logs actually N DISTINCT tests?", which is the cheapest way for a green 109/109 to
    be a lie. Four attacks, all must be 0:
      A CLONE      two logs with whitespace-normalised-identical wire XML = ONE test wearing two
                   names, counted twice by every coverage metric.
      B FPRINT     a log records the Entity Fingerprint it was captured against; if the JSON was
                   rebuilt IN PLACE without a version bump, the log is stale while its filename
                   still says current. Version equality cannot see that.
      C ORPHAN     a wire field that is no longer a targetField of the current QIDM for that query
                   = the log predates a field rename/removal. AUTH envelope elements
                   (Session/Id/Authentication/UserName/ORI/Mnemonic) are excluded -- counting them
                   produced exactly 6 false hits per log and buried any real orphan.
      D DEGENERATE a _guardrail_ test whose two competing identifiers were filled with the SAME
                   value proves nothing about priority; either combo "matches" that value.
    First run 2026-07-31 over 434 logs / 6 providers: 0/0/0/0 on all four. That is real evidence the
    tenant-test coverage is not inflated -- and it is the first such evidence, because nothing had
    ever asked.
    Read its header for the two bugs it caught in ITSELF (a vacuous fingerprint parse that passed
    everything, and verdict-by-substring). Both are the house failure mode, not trivia.
    Usage: .\audit_log_inflation.ps1 [-Providers <list>]
  tools/audit_order_risk.ps1
    THE HONEST ORDERING NUMBER. audit_devdoc_order truthfully says "mapped N of M -- unmapped combos
    are NOT checked", which reads as "up to 44% of combos are unverified" and pushes the reader
    toward reordering combos that are already deterministic. But ordering has TWO lines, and LINE 1
    (specificity, via audit_combo_reachability) covers EVERY pair fill-independently. A pair is only
    genuinely at risk when line 1 is silent AND line 2 does not cover it: neither set[] is a subset
    of the other (they are peers), BOTH are ungated (a condition defers deterministically), and they
    are co-satisfiable. Only then does nothing but the devdoc's listing order decide the winner.
    First run 2026-07-31: TX 5, NY 0, NJ 0, FL 19, HI 0, CA_CLETS 2. So NY/NJ/HI ordering is FULLY
    pinned by specificity + conditions and the devdoc-order coverage gap cannot affect them; FL's 19
    are the Article/Boat/Gun NCIC-vs-identifier peers, which the devdoc DOES order explicitly (FL
    Boat #10 Name precedes #11 Hull, and #10 lists BoatHullIdNumber as a legal optional -- so name
    winning a name+state+hull over-fill is CORRECT, not the identifier-priority violation it looks
    like at a glance; verified against the devdoc 2026-07-31 after wrongly calling it a defect).
    Usage: .\audit_order_risk.ps1 [-Providers <list>]
  tools/audit_lifecycle.ps1
    THE LIFECYCLE TAIL (enforce PHASE 2r, ADVISORY) -- stages 5 and 6, which had NO gate at all:
    STAGE 5 is the Jira entry (docs/tracking/DEX_TICKET.md must name the CURRENT version) and
    STAGE 6 is the import record (providers/IMPORT_LEDGER.md must ACCOUNT for the current version --
    either an install record or an explicit not-yet-imported line).
    Origin (Rob 2026-07-30: "all gates need to operate from initial build/rebuild all the way to
    posting the jira entry and logging where jsons are imported"): coverage stopped at "the JSON is
    correct and tested". A version could be built, tested, documented and pushed with no Jira comment
    and no ledger line, and nothing noticed -- so the ticket the rest of the org reads drifts behind
    the repo, and "where is version X installed" gets answered from memory, which CLAUDE.md forbids.
    ADVISORY by design (-Strict to block): Jira updates get placed ON HOLD, and Foundation-tenant
    imports are another party's action on another party's schedule. A gate that blocks a build
    because an external party has not acted teaches everyone to bypass it. What this removes is not
    the delay -- it is the ability to LOSE the fact. A GAP is not a build defect.
    Usage: .\audit_lifecycle.ps1 [-Provider <NAME>] [-Strict] [-OutFile <path>]
  tools/sync_session_state.ps1
    GENERATES the derived block of SESSION_STATE.md (run by pipeline after sync_provider_table).
    Origin (Rob 2026-07-30: "check for duplication of data that keeps drifting... remove redundant
    steps or automate them"): "TX_TLETS is at v4.18" is stored in FOURTEEN places and enforce spends
    FIFTEEN assertions reconciling them. Almost all fourteen are generated; exactly three were typed
    by hand -- SESSION_STATE.md, IMPORT_LEDGER.md, DEX_TICKET.md. SESSION_STATE was hand-corrected
    THREE times on 2026-07-30 alone. audit_session_state (enforce 2l) gates it, but gating a
    hand-maintained file only reports the drift afterwards; it does not prevent it.
    IMPORT_LEDGER stays manual ON PURPOSE -- it records an EXTERNAL act (someone imported something
    into a tenant), and generating it would be fabricating evidence. DEX_TICKET stays manual because
    Rob holds the Jira trigger.
    GENERATED: the Last-updated stamp, the branch line, the tenant-test table -- all from
    _test_status_lib.ps1, the same primitives portfolio_status and the CLAUDE.md table use, so the
    three cannot disagree. NEVER TOUCHED: next-physical-action, what-is-owed, open-decisions,
    hard-won-rules. Judgement does not belong to a generator.
    A provider earns a named row if it was tenant-tested at some point -- now (ALL-PASS/PARTIAL) or
    previously (archived logs => a bump reset it, re-sweep owed). Every provider owes plan tests, so
    "owed > 0" alone named all 20 and defeated the collapse.
    -DryRun prints the block without writing. Use it: the first draft guessed .Verdict/.LogCount
    (neither exists on the lib's return -- it is State/Pass/Fail/Pending/OwedPlanTests) and rendered
    every row "unknown (0 logs)". -DryRun caught that before a byte was written.
    Usage: .\sync_session_state.ps1 [-DryRun]
  tools/emit_test_plan_spec.ps1
    Generates the test plan from the DEVDOC + METADATA instead of from the built JSON.
    Origin (Rob 2026-07-30: "the test json needs to be wired to the metadata and dev doc and not the
    json itself"): emit_test_plan.ps1 derives every test from the JSON's own combinations, so the
    plan is a MIRROR of what was built and can only confirm what is there -- no combo, no test, no
    failure. That is exactly how TX_TLETS held 95/95 ALL-PASS while carrying 2 unbuilt devdoc paths,
    17 untransmittable devdoc optionals, and 3 devdoc-legal fills that send no query. A mirror cannot
    see an omission.
    Deriving from the SPEC inverts the failure modes into visibility:
      devdoc path never built     -> test exists, driver submits, NOTHING FIRES -> FAIL
      devdoc optional not carried -> test fills it, wire lacks it -> FAIL (audit_log_metadata)
      the Plate+Year NO-FIRE case -> tested and loud, instead of structurally untestable
    WHAT THE JSON STILL SUPPLIES, and only this: the fieldId to type into and its entity. The driver
    must address real controls. It gets NO vote on the test population -- if a devdoc field has no
    form control the test is emitted as UNREACHABLE, which is the finding, not a reason to skip.
    Reuses (never re-parses): audit_devdoc_combinations -Explain for items, the metadata XML for
    type/maxLength value synthesis, TEST_VALUE_OVERRIDES for entity-scoped values, and
    _sim_helpers Get-FiringKeyRef to state which combo SHOULD fire.
    Writes logs/<P>_TEST_PLAN_SPEC_v<X.Y>.json -- a SEPARATE file from the JSON-derived plan on
    purpose. The DELTA between the two is the artifact worth reading: tests the spec demands that the
    build cannot serve. First run, TX_TLETS v4.18: 74 tests, 17 expected NO-FIRE, 5 UNREACHABLE,
    versus 89 JSON-derived tests of which ZERO could fail on an omission.
    NOT YET TRIAGED: only 3 of the 17 NO-FIRE are the known accepted plate fills. The other 14 are
    unexamined -- they may be real findings or artifacts of the one-optional-at-a-time subsetting and
    synthesised values. Triage before treating any of them as defects.
    Usage: .\emit_test_plan_spec.ps1 -Provider <NAME> [-DryRun]
  tools/_claude_table_cells.ps1  (shared module, dot-sourced)
    Canonical renderers for the DERIVED cells of the CLAUDE.md Provider Status table,
    consumed by BOTH the writer (sync_provider_table.ps1) and the checker (enforce.ps1
    CHECK 3j) so the two cannot drift apart. Exports Format-ClaudeValidatorCell /
    Format-ClaudeTenantCell / Format-ClaudeVersionCell / Test-ClaudeScoreCellShape.
    Origin (2026-07-29): sync_provider_table owned a private score regex that required a
    "/<n>LIM" segment; the rebuilt table dropped that segment, so the regex matched no row,
    the tool reported "no change" for all 20 providers, and the table silently rotted
    (TX_TLETS held 78P after v4.13 removed 2 checks; NY/FL/CA held stale tenant verdicts).
    Change a cell format HERE only -- never in a caller.

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

  tools/audit_variant_sync.ps1
    Base<->variant lockstep drift check. A VARIANT provider (e.g. TX_TLETS_CCH) shares its
    base-6 QIDMs with its BASE provider (TX_TLETS) but is a separate build script with NO
    auto-propagation, so it can silently drift behind when the base changes (TX_TLETS_CCH had
    drifted ~4 versions before this existed). Detection is MARKER-DRIVEN: a provider is a variant
    IFF its build script declares `# BASE-SYNC: <BASE> vX.Y` (avoids name-heuristic false positives
    like CA_CLETS_OCATS, which is an independent provider). For each declared variant it compares
    the marker version to the base's CURRENT version and flags drift. Composed into doctor.ps1.
    When you build a variant (CCH etc.), add the marker; when the base bumps, re-sync + update it.
    Usage: .\audit_variant_sync.ps1 [-Path providers] [-OutFile <path>]

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
    AVOID as template: v3.x series (split entity NJ/OOS); recoverable from git history
    (phases/ retired -- git log/git show is authoritative for prior versions).

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
