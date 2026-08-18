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
FILES IN THIS FOLDER (16 files incl. this README, organized by question)
  Count corrected 2026-08-11: it read "14" while the folder held 15, so it was already
  stale before JIRA_COMMENT_TEMPLATE.txt was added. Recount when you add a file.
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
                           All 25 platform limitations (non-contiguous, #1-#38) + all 27 anti-patterns
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

  JIRA_COMMENT_TEMPLATE.txt "What EXACTLY does a DEX changelog comment look like?"
                           THE CANONICAL FORMAT, single source -- six fixed sections in a
                           fixed order, every one always present ("None" rather than
                           omitted). Written 2026-08-11 on Rob's "i want the same format
                           for each provider and for each update", after a measured sweep
                           found 87 automation-posted comments across 7 tickets with no
                           two providers sharing a structure. Also holds the two standing
                           constraints -- ONE COMMENT PER RELEASE and EDIT IT IF THE
                           NUMBERS MOVE (never a correction as a sibling: that is how
                           DEX-969 accumulated NINE contradictory totals and DEX-967's
                           latest comment ended up claiming 89/89 at v4.18 while the
                           provider was v4.19/92), and the fact that NO DELETE-COMMENT
                           TOOL EXISTS, so superseded comments are rewritten to the stub
                           defined here and every edit is irreversible. Includes which
                           comments may be edited at all: only the automation's own, never
                           Rob's manual notes or a third party's, and NOT identified by
                           displayName since the automation posts under his account.

  FIDELITY_TRIAGE.txt      "audit_requirement_fidelity flagged something -- is it real?"
                           How to read an UNDER-REQUIRED / OVER-PERMITTED finding, and the
                           tool's known blind spot: when two metadata variants SHARE a
                           keyRef it bridges on the bare keyRef and compares against the
                           UNION of their requirements. Confirmed twice (OH_LEADS BMVIMS
                           DL pair; AZ_AZDPS's two ACVR variants, where 4 real
                           over-permits read as 0 both before AND after the fix).

  PRODUCTION_TRIAGE.txt    "A live/production query is misbehaving -- where do I start?"

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

    CHECK 0 -- TRANSACTION-NAME SCOPE (added 2026-08-04, BLOCKING). The check this
    file's own auto-written template text had DESCRIBED since 2026-07-27 -- "a built
    query whose transaction name is NOT in the list above is a SHADOW / scope
    violation" -- and never performed. Everything else in the tool compares each
    combo's queryLabel against the HAND-MAINTAINED extract, and A LABEL IS NOT A
    TRANSACTION: the metadata defines DUPLICATE TRANSACTION PAIRS -- a plain devdoc
    name and an <Provider>-prefixed sibling carrying DIFFERENT <Requirements> -- so
    the prefixed one is a different query wearing the same approved label.
      AZ_AZDPS built the out-of-Basic AzAzdpsDriverLicenseQuery under the approved
      label 'Driver License'. Every combo scored [PASS], including
        [PASS] combo DQSS: 'Driver License | SocialSecurityNumber' is devdoc-supported
      which is flatly false -- AZ's Basic DriverLicenseQuery entry defines no SSN
      field anywhere. Choosing the prefixed sibling cost the two ImageIndicator="Y"
      driver-photo paths (devdoc #2 and #5, metadata DQP -- which exists ONLY under
      the Basic transaction) and the name-only search (devdoc #3, Set[Name]), while
      adding an SSN path the devdoc never authorizes.

    Three deliberate properties, each paid for:
      * GATES ON THE DEVDOC, NOT THE EXTRACT'S STATUS. AZ's extract is PROVISIONAL,
        and that was the THIRD layer hiding this -- even a detected mismatch would
        have printed INFO. The devdoc is QUERY authority; a human's sign-off flag on
        a JSON-seeded file cannot make an out-of-scope transaction in-scope. CHECK 0
        failures are therefore counted in $scopeFail, SEPARATE from $fail: the first
        build of this check printed its [FAIL] line and still exited 0, because the
        final exit gated $fail behind the extract STATUS. A gate that speaks and is
        not listened to is still a mute gate.
      * REFUSES TO GATE ON AN UNREADABLE LIST. If the Basic section yields zero names
        (CA_CONTRA_COSTA, PDF-only devdocs) it reports INFO and states that nothing
        was verified. Gating on an EMPTY ground truth would invert into failing every
        built query -- the same vacuity defect in the other direction.
      * VARIANT EXEMPTION, MARKER-DRIVEN. A provider whose build script declares
        "# BASE-SYNC:" is a variant and is authorized for Basic UNION the devdoc's
        "Transactions Supported" section, because building the variant transactions
        is the entire point of a variant. Same marker audit_variant_sync uses, so an
        independent provider sharing a name prefix (CA_CLETS_OCATS) is never mistaken
        for one. Found by the 20-provider sweep, which flagged TX_TLETS_CCH's 8 CCH
        transactions -- all of them in that section, i.e. MY scope model was wrong,
        not the build. Do NOT widen this to base providers: on a base, "it's somewhere
        in the devdoc" is exactly the reasoning that put the wrong transaction in AZ.

    Same pass fixed the devdoc extractor's '$'-anchored query-name pattern. pdftotext
    routinely merges the query heading onto the following field-table header, e.g. HI's
      "BoatQuery            XML Tag Name         M/C/O Size Possible Values"
    so the anchored pattern silently UNDER-READ the ground truth: HI as 5 of 6 (no
    BoatQuery) and NJ_NJCJIS as 1 of 6 -- and then PASSed every query it had never
    heard of. An under-read Basic list makes this gate weaker while looking identical
    to a clean run, so the relaxed pattern was measured across all 20 BEFORE landing:
    it adds exactly 6 names (HI BoatQuery; NJ ArticleSingleQuery, BoatQuery,
    DriverLicenseQuery, GunQuery, VehicleStolenQuery) and admits no non-query text.

    Baseline 2026-08-04: 1 violation of 20 -- AZ_AZDPS only. The other direction
    (devdoc-Basic but NOT BUILT) is INFO, never WARN: every current instance is an
    adjudicated skip (FL/LA/OH/OR ImageQuery, TX VehicleRegistrationQuery merged into
    VehicleInsuranceRegistrationQuery, NJ VehicleStolenQuery), so raising warnings
    would manufacture noise on settled decisions -- but a Basic query silently DROPPED
    is a real class nothing else watches, so it must stay visible.

    NOTE: enforce Phase 2e reads the COMMITTED SUPPORTED_QUERY_AUDIT report, SHA-gated
    against BUILD_MANIFEST. A tool change therefore does NOT take effect until each
    provider's report is regenerated -- hand-writing one fails Test-ReportTrusted.
    Re-run build_report.ps1 -Path <json> for every provider after changing this tool,
    or the new check is silently inactive everywhere the report is stale.
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
    Prints the SWEEP LEDGER (report_sweep_ledger.ps1) after EVERY ingest -- see below.
    Usage: .\tools\watch_captures.ps1            # auto-import + commit
           .\tools\watch_captures.ps1 -NoCommit  # import only, no git commit
           .\tools\watch_captures.ps1 -Once      # exit after first import (supervised mode:
                                                 # the supervisor reports the summary + re-arms)

  tools/audit_change_scope.ps1
    WRITE-SCOPE GUARDRAIL: reports which provider directories the working tree (or a git ref)
    actually touches, and FAILS when it is more than the provider in scope.
    WHY (2026-08-18, Rob: "we need to put guardrails around your drift but respect the portfolio
    implications"): one-provider-at-a-time kept being broken by ACCRETION rather than by decision --
    a shared validate.ps1 change moved MD_METERS 69->70 and OH_LEADS 77->78, and their reports and
    docs were regenerated "while I was there", which is a mass rebuild by the back door.
    IT GUARDS *WRITE* SCOPE, NOT READ SCOPE. Measuring across providers is always allowed and is
    MANDATORY after any shared-tool change -- see ENGINEERING_STANDARD.md 4.5, which also carries the
    inference guardrail: a cross-provider MAJORITY is evidence about the portfolio, never about one
    provider's spec (18-of-20 on the Name separator nearly drove a wrong "fix" to a CORRECT build).
    A provider declaring `# BASE-SYNC: <scope>` is auto-allowed, because variant lockstep is
    mandatory. tools/, knowledge-base/ and repo-root writes are reported as PORTFOLIO-WIDE rather
    than flagged. An empty worktree reports "[NOTE] nothing staged", never "scope clean".
    Usage: .\tools\audit_change_scope.ps1 -Provider TX_TLETS
           .\tools\audit_change_scope.ps1 -Provider TX_TLETS -Allow OH_LEADS
           .\tools\audit_change_scope.ps1 -Provider TX_TLETS -Ref HEAD~3

  tools/report_sweep_ledger.ps1
    THE SWEEP LEDGER: planned vs logged vs owed, per entity, derived from the REPO (the active
    JSON's version -> its test plan -> the current-version logs on disk). Auto-printed by
    watch_captures.ps1 after every ingest.
    WHY (2026-08-18, Rob: "we need to fix this process"): mid-sweep on TX_TLETS v4.21 the Boat
    entity was driven -- 22 queries submitted -- and then never captured, because the fetch
    drained a manifest that still held the previous entity. capture.js reported "done. +8 new,
    ALL 8 manifest entries captured", which is TRUE and USELESS: it confirms it drained the
    manifest and never checks the manifest held what you just ran. A success line that cannot
    fail. Four earlier entities had each cost several "did it land?" round trips, and Boat was
    only caught by hand-diffing the repo. The browser knows what it QUEUED; only the repo knows
    what is ON DISK, and on-disk logs are what 6c/6d/2i, plan completeness and portfolio_status
    all read.
    Counts ONLY current-version logs (filters <PROVIDER>_v<ver>_*, skips _archive_) and takes its
    entity list FROM THE PLAN, never a hardcoded five. Always exits 0 -- a report, not a gate --
    but prints [NO-VERDICT] rather than a clean-looking zero when there is no active JSON or no
    plan for the active version.
    Usage: .\tools\report_sweep_ledger.ps1 -Provider TX_TLETS
           .\tools\report_sweep_ledger.ps1 -All
           .\tools\report_sweep_ledger.ps1 -Provider TX_TLETS -Quiet

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
  tools/audit_buildnotes_fidelity.ps1
    BUILD_NOTES FIDELITY -- is the CURRENT version's entry the generic stub pipeline.ps1 stamps
    ("CHANGED: Rebuilt via pipeline.ps1 / REASON: Scheduled rebuild") while the JSON actually
    changed? Built 2026-08-03 after NINE hand-corrections in one session (FL 4, TX 3, NY 2).
    No judgement required: the stub is TRUE for a reproducibility rebuild and FALSE for a wire
    change, and the JSON decides. Previous-version blob comes from git -- the commit that adds
    <P>_v<cur>.json also removes its predecessor, USUALLY AS A RENAME (parsing only 'D' left 11 of
    14 cases NOT COMPARABLE, i.e. the gate declining to judge most of what it was built for);
    legacy <P>_MC/<P>_BASE/bare-<P> predecessors are accepted too, which closed the last 3.
    Matches the STRUCTURAL stub, never the phrase -- a substring grep flagged NY, whose repaired
    entry QUOTES the stub it replaced, so the naive version would have flagged exactly the
    providers that were fixed.
    BASELINE: 14 GENERIC / 14 compared / 14 FAIL / 0 not-comparable. NOT ONE was a true no-op.
    Branch coverage: FAIL proven 14x, not-a-stub PASS proven 6x, and the generic+identical PASS
    path is UNEXERCISED (no version pair here is a real no-op) -- do not claim it verified.
    NOT in enforce yet by design: it would turn 14 of 20 providers red. Wire it after the entries
    are repaired so it lands at zero, same sequencing as audit_registry_currency. In doctor.ps1.
    Usage: .\audit_buildnotes_fidelity.ps1 [-Provider <NAME>] [-All] [-Quiet] [-OutFile <path>]
  tools/audit_registry_currency.ps1
    REGISTRY CURRENCY -- is each ACCEPTED_DIVERGENCES row's PREMISE still true? The companion
    question to audit_suppression_scope, which asks how WIDE a row's suppression is. A row can be
    perfectly scoped, silence nothing, and still be WRONG because the condition it describes was
    fixed away. Built 2026-08-03 after FL_FCIC's 'promoted-to-any-UNJUSTIFIED-NEEDS-RULING' row
    read as a live open decision four days after commit 7b13a67c closed it -- it got a version bump
    APPROVED before the emitted JSON refuted it in under a minute.
    Checks the DIRECTION classes only: to-any (promoted/demoted/added-to-any) asserts the field
    rides in that combo's any[]; to-set asserts it sits in set[]. Field absent from the
    combination's own set[] AND any[] (both namespaces) -> [FAIL] STALE. Combo gone -> STALE.
    Existence-class staleness is NOT re-implemented -- audit_requirement_fidelity already emits
    [NOTE] REGISTRY OVER-SUPPRESSION RISK for an unbuilt-class row naming a built combo.
    DELIBERATELY CONSERVATIVE and it UNDER-reports: presence matches in any namespace, including
    canon-token containment either direction, so 'PurposeCode' is satisfied by
    'CaRequestPurposeCode' with no alias table. A PASS means no row is PROVABLY stale, never that
    every row was verified -- 'other'/existence rows are counted NOT-CHECKABLE and printed in the
    denominator. Baseline 2026-08-03: 247 rows / 72 checkable (29%) / 3 STALE.
    THE TRAP IT FELL INTO FIRST, recorded in its header: v1 pooled every attribute targetField in
    the QIDM for namespace tolerance, which made it blind to its own motivating defect (the field
    was defined on a SIBLING combo of the same query). Presence must be per-COMBINATION. Found only
    by LAW 2 injection -- the clean 20-provider run before that was a false 0/0.
    Usage: .\audit_registry_currency.ps1 [-Provider <NAME>] [-All] [-Path <replica>] [-Quiet] [-OutFile <path>]
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
  tools/audit_defect_classes.ps1
    ⚠️ EXPERIMENTAL -- DO NOT QUOTE ITS OUTPUT AS FINDINGS, NOT WIRED INTO ANY GATE. Read its header
    banner before running it.
    INTENT (Rob 2026-07-31: "i want this process to be fruitful"): by the fourth provider the session
    was re-deriving the same handful of defect classes from scratch each time. The classes are now
    KNOWN, so enumerate them across the portfolio in ONE ranked pass instead of 13 sequential
    investigations. Reads each provider's OWN metadata -- never assumes a sibling's answer applies
    (CA_CLETS_OCATS and CA_SAN_LUIS_OBISPO looked like certain suspects and were both CLEAN).
    CLASSES: C1 collapsed <Choice>-in-<Set> (WIRE-INVALID -- request satisfies no metadata variant;
    6d catches it, 6c/2i cannot); C2 over-required set[] (fill falls through to a looser combo whose
    pool lacks the field, so an officer value is silently dropped); C3 an optional the query can carry
    nowhere; C4 prefill on a routing field (BUILD_RULES 24, skipped when the field is in EVERY combo's
    set[] and so cannot shadow).
    WHY IT IS NOT TRUSTED YET: it has failed its known-answer test four times, improving each run
    (19 -> 9 -> 7 -> 6 candidates against a CA family whose true answer is 1). Two of those failures
    were it flagging combos that had just been FIXED, and one was a length floor the author added that
    broke the first fix. The residual bug is characterised in the header: the primaryFieldReference
    restriction is not taking effect, so CA_CONTRA_COSTA's IR.QVC.* rows are compared against the
    {Name} variant's Choice group. Fix that, re-run until the CA family yields exactly
    CA_VENTURA_COUNTY, and only then wire it anywhere.
    THE LESSON IS WORTH MORE THAN THE TOOL SO FAR: validate a new parser against a known answer
    BEFORE trusting a single number it produces. That discipline stopped 19, then 9, then 7, then 6
    bogus findings from reaching a report -- the same rule that caught the vacuous fingerprint check
    in audit_log_inflation and the registry over-suppression in audit_requirement_fidelity.
    Usage: .\audit_defect_classes.ps1 [-Providers <list>] [-All] [-Class C1,C2] [-OutFile <path>]
  tools/audit_lifecycle.ps1
    THE LIFECYCLE TAIL (enforce PHASE 2r, ADVISORY) -- stages 5 and 6, which had NO gate at all:
    STAGE 5 is the Jira entry (docs/tracking/DEX_TICKET.md must carry a structured
    `POSTED: v<X.Y> comment <id> <YYYY-MM-DD>` marker for the CURRENT version) and
    STAGE 6 is the import record (providers/IMPORT_LEDGER.md must ACCOUNT for the current version --
    either an install record or an explicit not-yet-imported line).
    STAGE 5 IS SCOPED TO TENANT-VERIFIED PROVIDERS (State='ALL-PASS' via the shared _test_status_lib
    classifier, so it cannot disagree with portfolio_status): nothing is owed to a ticket for a
    version that has not passed stage 4. Baseline 2026-08-14: 8 compared, 12 not yet due,
    4 PASS (FL/IL/NJ/NY) / 4 GAP (TX v4.18-vs-v4.19, CA_CLETS v2.23-vs-v2.24,
    HI v4.15-vs-v4.18, AZ never posted).
    ** WHY A MARKER AND NOT A VERSION MENTION (rewritten 2026-08-14 -- this check was VACUOUS) **
    It used to be `(Get-Content DEX_TICKET.md -Raw) -match "v$ver"`, a substring match over the whole
    file. Every DEX_TICKET.md carries a `**Current: v4.19 -- tenant-verified...**` line, so the
    version was ALWAYS mentioned and the check COULD NOT FAIL for any provider whose pointer file was
    current. It reported 7 of 8 tenant-verified providers PASS while THREE were behind on the real
    ticket; Rob found it by reading the tickets while the board showed green (ENGINEERING_STANDARD
    4.3). THE ASYMMETRY WITH STAGE 6, and why only stage 5 changed: stage 6's authority IS the
    ledger, so text in it literally is the record; stage 5's authority is JIRA, which this tool
    cannot reach, so the file is a CLAIM about an external system -- and a claim that restates the
    repo's own version number is no evidence. The marker carries the one thing the repo cannot derive
    from itself: the comment ID. NOT fixable by a tighter regex -- "the version must appear on a line
    naming a comment" was rejected because NJ_NJCJIS's record reads "Closed by comment 795856 at full
    plan coverage" and names no version, so it would have false-GAPped the most finished provider in
    the portfolio (if a check fires on the provider you derived it from, the check is wrong).
    LAW 2, all three branches proven by injection on FL_FCIC: marker removed -> GAP; marker removed
    but the version still mentioned (EXACTLY the old vacuous pass) -> GAP; marker naming a stale
    version -> GAP that reports WHICH version was last posted, which is the actionable half.
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

  tools/audit_layout_flow.ps1
    IS THE FORM A PROJECTION OF ITS COMBINATIONS? -- the cosmetic/usability direction no gate
    covered. render_layout.ps1 renders the form but has no opinion; verify_build CHECK 15
    checks label TEXT; audit_wiring_closure checks that a control REACHES the wire. None asked
    whether the form's SHAPE -- card count, row order, field order, widths, grouping -- follows
    the query paths the officer actually drives. Built 2026-08-11 on Rob's ask ("see if you can
    figure out card label feild label and file size/ordeing based on query combinations and
    flow ... build a cosmetic skill around it if we are successful").
    Rules (7 mechanised, see .claude/skills/usx-cosmetic for the full set incl. the two that
    are not): L4 one card per entity (Person 2 = DL+DH) · L2 mandatory set[] leads its own
    optionals · L3 hidden/auto rows last · L5 no full 12-col row for a control that cannot use
    it · L6 visible rows sum to 12 · L7 label must match capacity (MI only if maxLen=1) ·
    L9 an RMS-only field must not share a row with a mandatory CommSys identifier.
    THE GOAL IS UNIFORMITY -- Rob 2026-08-11: "the skill should posintion them all the same in
    terms of layouts and veriabege". An officer working two states should not have to relearn
    the form, so DIVERGENCE BETWEEN PROVIDERS IS A FINDING, NOT A PREFERENCE; the only
    legitimate reason A differs from B is that A's own combinations/metadata force it. Most of
    the variation in the current portfolio is just the order the providers were built in.
    THE OPERATOR HAS FINAL SAY on every finding -- each is a RECOMMENDATION, and an override
    must be recorded (# LABEL-OVERRIDE: tag, or a BUILD_NOTES line) or it gets rediscovered
    and re-litigated next pass.
    ADVISORY and NOT YET wired into enforce/pipeline (Rob: "lets test before we put any of this
    in the the production pipeline") -- because the rules were still being corrected, not
    because drift is acceptable. Wire it once the portfolio is converged and the remaining
    findings are all recorded overrides.
    WHAT IT COST TO GET RIGHT -- the first draft raised 165 findings and was wrong three ways,
    each caught only by running it against the providers it was DERIVED FROM:
      * `hidden` is a NODE-level property, not props.hidden -> NINE false findings in one run,
        all hidden gate-feeders the officer never sees. verify_build CHECK 6 had it right.
      * L1 "form order should match combo array order" WITHDRAWN. The array encodes
        SPECIFICITY for first-match firing; form order should follow IDENTIFIER PRIORITY, which
        lives in the NOT_EXISTS guardrails. Fired 4 times on AZ, wrong 4 times.
      * L2 punished the convention it should reward. A field in >1 combo's any[] is SHARED
        CONTEXT and belongs grouped high with the primary identifier, hence above the
        combo-specific mandatory fields. Un-guarded it raised 8 findings against FL_FCIC --
        one of the two layouts the rules came from -- and was 71 of 165 findings.
      IF A RULE FIRES ON THE PROVIDER YOU COPIED IT FROM, THE RULE IS WRONG.
    LAW 2 proven both directions: PASSES clean on NJ_NJCJIS (8 rows compared, so not a vacuous
    pass) and FAILS on an injected templateColumns defect.
    Baseline 2026-08-11: 20 compared / 19 with findings / 139 total. L4 34 · L5 26 · L2 11 ·
    L7 10 · L3 7 · L9 3. The L4 mass is the un-collapsed-layout split -- collapsed providers
    run 5-6 cards, un-collapsed 11-20 (CA_VENTURA 20, CA_CLETS_OCATS 16, TN/MD/NM/CA_SLO 13-14,
    LA 12, OR 11). Their LOW scores on the other rules are PARTLY VACUOUS: small cards hold
    few rows, so there is less to trip. L4 says so in its own message.
    NJ_NJCJIS is the only clean provider and OH_LEADS the next (2) -- the two most recent
    layout passes. Do NOT copy FL (7) or NY (6) for layout; they predate the convention.

  tools/audit_provider_uniformity.ps1
    ARE THE FINISHED PROVIDERS THE SAME SHAPE? -- the artifact-set direction that neither
    structural gate covers. audit_structure.ps1 checks ONE provider against a template IN
    ISOLATION, and reported "RESULT: ALL CLEAN" on all six tenant-complete providers while
    their artifact sets genuinely differed -- a template says "docs/ must exist", never "IL
    must carry the same files as TX". audit_cross_provider.ps1 IS cross-provider but its 8
    checks all compare JSON CONTENT (defaults, queryLabels, code types, field types, fieldId
    casing, RMS autoSelect) and it never looks at what is on disk. So "the finished providers
    are documented and packaged identically" was an assumption nobody had measured.
    Built 2026-08-10 when Rob asked to confirm it. What the sweep found, all of it green on
    every existing gate:
      * CA_CLETS carried CAD_GUIDE_CA_CLETS.html/.pdf -- output of render_cad_guide.ps1,
        ARCHIVED 2026-07-24 and consolidated into render_officer_guide.ps1 (see the archived
        -tools section above). Dated Jun 26, so an officer-facing folder held a CAD guide
        describing a ~v2.1x form while the shipped JSON was v2.24. Deleted, uncited.
      * TX_TLETS carried a vestigial logs/.gitkeep beside 29 live entries. Deleted.
      * CLAUDE.md still called the docs/ 4-category migration and the phases/ retirement a
        "rollout, NJ_NJCJIS pilot" five weeks after both hit 20/20. Corrected.
    WHY IT IS NOT TIDINESS: the artifact set IS the deliverable for a finished provider --
    the officer guide a department reads, the SQVR a tester reads to decide what to test, the
    BUILD_NOTES a Jira changelog is written from. A provider silently missing one is
    INCOMPLETE, and the reason nobody noticed is that no gate compared it to its peers.
    THE HARD PART IS NOT FLATTENING STATE INTO STRUCTURE. Three files are legitimately absent
    on some providers and manufacturing them would be a real defect:
      * <P>_FORM_REVIEW.txt   -- records that a HUMAN reviewed the rendered form. Creating one
        to satisfy a uniformity check fakes Rob's own manual gate, which is exactly what
        audit_form_review's header forbids ("a review is a human act and must not be
        manufacturable to satisfy a gate"). IL has none because none was recorded.
      * PENDING_UPDATES.txt   -- reverse-propagation flag STATE; absent means no pending flag.
        Naive-probe warning: grepping this file for 'FLAG' counts "# [FLAG:...] RESOLVED"
        comment lines, so CA_CLETS reads as 2 pending flags when it has zero. Count ACTIVE.
      * TEST_VALUE_OVERRIDES.txt -- OPTIONAL override read by emit_test_plan,
        emit_test_plan_spec, generate_test_matrix, import_picklists, _combo_value_resolver.
    Those live in an $optionalByDesign allowlist, each WITH its reason, and report [NOTE] --
    an auditable allowlist rather than invisible silence. '.gitkeep' is deliberately NOT in it:
    v1 of the allowlist included it and would have hidden its own motivating finding.
    Scopes to State='ALL-PASS' via _test_status_lib (the same classifier portfolio_status and
    SESSION_STATE use, so the three cannot disagree). PRINTS ITS DENOMINATOR and FAILs a
    scope under 2 providers -- comparing one provider to itself is the vacuous pass that let
    audit_sqvr_integrity CHECK 2 compare nothing on 17 of 20 the very same day.
    LAW 2 proven three ways: a removed OFFICER_GUIDE pdf, a re-introduced .gitkeep, and a
    single-provider scope. Baseline: 6 providers x 56 tokens, 5 areas identical, 8 explained.
    Composed into doctor.ps1. Usage: [-Providers <list>] [-All] [-Quiet] [-OutFile <path>]

  tools/audit_tool_portability.ps1
    TOOL PORTABILITY SWEEP -- does every shared gate actually RUN on every provider?
    Rob, 2026-08-01: "shared tools need to work everywhere." Every gate here is
    provider-agnostic BY INTENTION, and several were provider-specific BY ACCIDENT,
    each found only when someone happened to run it somewhere new:
      * _resolve_provider_xml.ps1 did not exist, so four tools hand-rolled an
        alphabetical `*.xml` glob. On the ONE provider carrying two XMLs it read a
        6-node excerpt as if it were the 466-node metadata and reported green.
      * audit_requirement_fidelity compared SOURCEFIELDS against metadata field
        references, so any provider naming a control unexpectedly (VehNameLast,
        OwnerLastName, firearmMake) produced false findings.
      * that tool's $formOnly whitelist was written in sourceField spellings, so when
        comparison moved into targetField space it stopped matching -- on AZ only.
      * sync_session_state.ps1 was a HARD PARSE FAILURE under PowerShell 5.1 while
        working fine under pwsh 7, and silently broke a pipeline step.
    Every one was invisible until a tool met a provider it had never met.
    WHAT IT MEASURES, and what it deliberately does NOT: not whether a gate PASSES --
    a FAIL is a real answer. It measures whether the gate can RUN AND REACH A VERDICT:
      [OK] a recognisable verdict line;  [NO-VERDICT] finished without one -- which is
      exactly how a tool "passes" a provider it cannot actually handle;  [CRASH] threw
      or exited non-zero with nothing;  [RUNTIME-ERR] verdict present but a null-deref
      or ParserError in the output.
    A gate that cannot reach a verdict on a provider is UNPORTABLE THERE regardless of
    what the green board says -- the same "a step that did not run is NOT a pass"
    principle the rest of the gates are built on.
    Covers the 12 -Path-taking gates x every provider. Provider-scoped and repo-wide
    tools have different invocation contracts and are covered by enforce.
    RE-RUN IT AFTER ANY PORTABILITY FIX: those routinely break a DIFFERENT provider --
    the $formOnly namespace break did exactly that, and only a full re-sweep showed it.

  tools/audit_optional_scope.ps1
    FIX-vs-REGISTER ADJUDICATOR for "silently not transmitted" findings. Answers
    mechanically what was being re-derived by hand every time.
    THE PROBLEM: audit_devdoc_optionals reports, in IDENTICAL wording,
      "#N +[Field] -> fires KEYREF but optional(s) Field are in NO matching combo's
       set[]/any[] -- silently not transmitted"
    On 2026-08-01 that one sentence was a REAL DROPPED VALUE on AZ_AZDPS (boat
    RegistrationNumber), CA_eSUN (purposeCode), CA_SAN_LUIS_OBISPO (DL State) and
    OH_LEADS (DL BirthDate) -- and the CORRECT BEHAVIOUR on TX_TLETS_CCH (QWI
    BirthDate/RaceCode/SexCode), NM_NMLETS_OFML (QV VehicleYear), OH_LEADS (Boat
    ImageIndicator), OR_LEDS, MD_METERS and TN_TIES. Same words, opposite answers,
    ELEVEN times in one day.
    WHY: the devdoc gives ONE FLAT OPTIONAL LIST PER QUERY while the metadata
    spreads those optionals across SEPARATE TRANSACTIONS (in-state NCIC keyRef vs
    out-of-state Nlets keyRef) or across CHOICE BRANCHES (a nested <Set> scoping
    fields to one alternative). A flat list cannot distinguish a GLOBAL optional
    from one scoped to a single alternative.
    THE ONLY QUESTION THAT MATTERS -- and it is never "is it in the devdoc bracket?",
    it always is, that is why the finding fired:
        DOES THE FIRING COMBO'S OWN METADATA VARIANT DEFINE THIS FIELD?
          YES -> FIX      metadata permits it on this exact path; we are dropping
                          the officer's value. Add it to that combo's any[].
          NO  -> REGISTER adding it would OVER-PERMIT: transmit a field the
                          transaction does not define. That is a NEW defect, and
                          audit_requirement_fidelity will report it as OVER-PERMITTED.
    It prints, for a REGISTER, which OTHER variants DO define the field -- that is
    the evidence line the accepted-divergence reason needs.
    MUST NARROW BY primaryFieldReference, and the tool was WRONG without it: a
    metadata keyRef routinely carries several variants (OR_LEDS BQ has both
    BQ{BoatHullIdNumber} and BQ{RegistrationNumber}). Unnarrowed, it found
    RegistrationNumber on the SIBLING reg variant and advised [FIX] on the HULL
    combo -- which would have over-permitted. Caught because its own evidence line
    named BQ{RegistrationNumber} while the firing combo was BQ.H. A KEYREF IS NOT A
    VARIANT: same restriction defect that put 5 false rows on audit_defect_classes
    the same day. It now reads each built combo's declared PF from the JSON and
    reports [CHECK] rather than guessing when no variant matches.
    VERIFIED against three independent known answers (OR_LEDS BQ{BoatHullIdNumber},
    MD_METERS ZWAR{Name}, TN_TIES DQ{Name}) by reading the raw XML.
    RECOMMENDS ONLY -- never edits, not wired into any gate. The reason still has to
    be written into the registry or build script, because the reason is the durable
    part. Handles the dropped-optional class only; NO-COMBO-FIRES is still by hand.

  tools/audit_provider_linkage.ps1
    PROVIDER LINKAGE GATE (advisory). EVERY PROVIDER JSON IS STANDALONE. Its build
    is justified by ITS OWN devdoc (query authority) and ITS OWN metadata XML
    (field authority); CLAUDE.md + this knowledge-base are the only SHARED
    authority. Flags a build script that names a DIFFERENT provider in code or
    comment. Comments count: a comment is where the JUSTIFICATION lives, and a
    justification that points at another provider is precisely the defect.
    THE ONLY TWO DIRECTED LINKS (allowlisted):
      1. CA_CONTRA_COSTA -> CA_CLETS  (explicit ruling: full CA_CLETS copy + JAWS)
      2. <BASE>_<VARIANT> -> <BASE>   (CCH etc., declared by `# BASE-SYNC: <BASE>
                                       vX.Y`, drift-gated by audit_variant_sync)
    WHY THIS IS NOT COSMETIC -- the near-miss that produced the gate:
      CA_CLETS and CA_VENTURA_COUNTY both have an IR.QVC{Name} DriverLicense
      combination and they require OPPOSITE things. CA_CLETS's has FOUR metadata
      variants, one of which puts Choice[Age|BirthDate] inside <Any> -- legally
      OPTIONAL there, and CA_CLETS correctly registered a demoted-to-any
      divergence. Ventura's has exactly ONE variant with the Choice inside <Set>
      -- MANDATORY, so it must be split into one combination per branch. Copying
      the "tenant-verified sibling" would have shipped a request Ventura's own
      metadata calls invalid. A SIBLING PROVIDER IS NOT EVIDENCE; where it looks
      like evidence it is actively misleading.
    Excludes codeTypeSource/codeTypeProvider/codeTypeCategory lines -- e.g.
    codeTypeSource='CA_CLETS' is the platform registry value NCIC_ARTICLE_TYPE
    requires, not a provider link. (25 of the first 93 hits were exactly this; a
    gate with false positives gets ignored, which is worse than no gate.)
    Baseline 2026-08-01: 68 references across 20 providers. Deliberately ADVISORY
    and NOT a flag_pending_fix flag -- comment provenance has zero wire impact, so
    blocking six tenant-verified providers over it would be disproportionate.
    Cleaned per provider at its own rebuild (one provider at a time).

  tools/audit_ps51_parse.ps1
    PS 5.1 PARSE GATE. Every tools/*.ps1 must parse on the engine that RUNS it.
    pipeline.ps1/enforce.ps1 invoke tools as `powershell -File` = Windows
    PowerShell 5.1, while interactive work here often uses pwsh 7. The grammars
    differ, so a tool can be written, run and "verified" under 7 and still be a
    HARD PARSE FAILURE under 5.1 -- which appears as swallowed ParserError text,
    not as a FAIL line in a report. Found 2026-08-01 when sync_session_state.ps1
    silently broke pipeline step 8, and audit_defect_classes.ps1 had the same
    defect while being used all day.
    TWO 5.1-ONLY FAILURE MODES:
      1. Non-ASCII inside a DOUBLE-QUOTED / interpolated string in a BOM-less
         file. 5.1 decodes such a file as cp1252, and BOTH an em-dash
         (U+2014 = E2 80 94) and a box-drawing char (U+2500 = E2 94 80) contain
         byte 0x94, which cp1252 maps to a RIGHT DOUBLE QUOTATION MARK -- 5.1
         treats that as a string delimiter, so the string ends mid-line.
         The repo's 66 other BOM-less non-ASCII scripts are fine ONLY because
         theirs sit in SINGLE-quoted strings, where 5.1 never scans for
         interpolation. RULE: non-ASCII is fine in '...', NEVER in "...$x...".
      2. Nested same-type quotes inside $( ), e.g. "$(if($b){" -- x"})" --
         PS7 accepts it, 5.1 does not.
    It PRINTS THE ENGINE VERSION and REFUSES to report a clean verdict unless
    running on 5.1, because the first version of this very check was run by
    pwsh 7, used the PS7 grammar, and reported "99 scanned / 0 failures" while
    two files were broken. Same class as the JAWS-only XML misread: A CHECK THAT
    CONSULTS THE WRONG AUTHORITY CANNOT FAIL HONESTLY.
    Composed into doctor.ps1. LAW 2 verified: injecting an em-dash into an
    interpolated string is caught, with the cause named.

  tools/_resolve_provider_xml.ps1    Shared metadata-XML resolver (Get-ProviderMetadataXml). The XML counterpart of
    _resolve_provider_json.ps1, added 2026-08-01 because it did NOT exist: six tools
    each hand-rolled XML resolution and four used `Get-ChildItem source -Filter
    '*.xml' | Select-Object -First 1`, which is alphabetical, not authoritative.
    Resolution order: exact <PROVIDER>.xml -> the BASE provider's XML for a variant
    (<BASE>_<SUFFIX>, mirroring the devdoc base/variant sharing rule) -> the only
    *.xml present -> $null WITH a warning. It deliberately REFUSES to choose between
    multiple candidates: a caller can handle $null but cannot detect a plausible
    wrong answer.
    WHY IT EXISTS: on CA_CONTRA_COSTA (the one provider carrying two XMLs) the old
    glob returned CA_CONTRA_COSTA_JAWS_ONLY.xml -- 6 <Combination> nodes instead of
    466 -- so a gate ran green against 1.3% of the metadata and manufactured five
    false defect findings that survived five reasoning passes. The pick was not even
    stable: Get-ChildItem's native order and Sort-Object Name disagree on which of
    the two comes first. The same glob sat in pipeline.ps1 feeding
    extract_metadata_reference.ps1, so it could have regenerated
    METADATA_REFERENCE.txt -- the repo's field authority -- from that excerpt.
    THE CLASS, worth naming: A GATE THAT READS THE WRONG AUTHORITY CANNOT FAIL
    HONESTLY. It reports PASS or FAIL with equal confidence and no denominator to
    betray it. Same family as the vacuous fingerprint check and the registry
    over-suppression.
    Dot-sourced by audit_defect_classes.ps1, audit_log_metadata.ps1,
    audit_requirement_fidelity.ps1, pipeline.ps1.

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

emit_decision_trail.ps1 -- SessionStart hook #3, the REASONING pointer for a restarted session.
  SESSION_STATE.md carries STATE and usx-resume carries ENVIRONMENT; neither carries JUDGEMENT.
  The judgement earned in a long session lives in commit BODIES, which nothing read at startup --
  so every restart re-learned the same lessons. This prints the recent commit subjects as an index
  plus the self-correction lines from their bodies, and tells the reader to go read the bodies.
  Derived from git on every run, so it can never go stale and duplicates nothing.
  Added 2026-08-02 after Rob observed the resume path was not producing a continuous line of thought.

audit_wiring_closure.ps1 -- FORM <-> QIDM closure. Does every control reach the wire, and does
  every wired field have a control? Five silent breaks (dead control / orphan attribute /
  unfillable requirement / inert condition / inert default). Added 2026-08-02 after a VISIBLE
  prefilled control on CA_SAN_LUIS_OBISPO turned out to be in no combination's any[] -- its value
  discarded on every query -- while every existing gate reported that provider green.

report_import_owed.ps1 -- THE IMPORT QUEUE. Which built versions are waiting to be installed, across
  all providers at once. Added 2026-08-17 after TEN provider versions were bumped in a single session
  and nothing ever said they needed importing -- Rob: "you need to alert when a new version is built
  to prompt for import   iver lost track of all the things you are fixing."
  THE GAP WAS STRUCTURAL, NOT FORGETFULNESS. Every other gate is scoped to ONE provider and answers
  "is this build correct?". audit_lifecycle stage 6 is the closest thing and is per-provider,
  advisory, and satisfied by an explicit "not imported yet" ledger line -- so it goes quiet exactly
  when a queue is piling up. Nothing in the repo looked across providers and asked "what is built but
  not installed anywhere?". A repo can be entirely correct and still be useless to whoever has to
  install it.
  KEEPS THE THREE TENANT CLASSES APART (IMPORT_LEDGER.md defines them) and that is the whole value:
    USx Provider Tenant -- log-DERIVED, self-verifying (the capture tool is locked to these).
    Foundation          -- manual; only known because someone reported an import.
    LIVE / Production   -- manual, and a bump is a COORDINATED re-import, never a repo action. A LIVE
                           row may be DELIBERATELY HELD BEHIND (HDLE is), so "behind" is not
                           automatically drift -- the report prints the ledger's own note and marks
                           such rows "NOT owed" rather than guessing.
  ALWAYS EXITS 0 -- it is a REPORT, not a gate. Owing an import is a normal state; making it blocking
  would train everyone to skip it.
  -Since UNDER-REPORTS AND SAYS SO IN ITS OWN OUTPUT: it detects bumps via git RENAME detection, so a
  version swap recorded as add+delete is invisible. Measured 2026-08-17: it found 8 of 10 real bumps
  and silently omitted CA_CONTRA_COSTA and CA_eSUN. Run with NO arguments for the authoritative
  queue -- that path compares versions directly and cannot miss one.
  AUTO-FIRES from reset_test_package.ps1, gated on $priorGlobal -ne $version. That guard is
  load-bearing: the first version printed unconditionally (fired on -Force and same-version reruns),
  which is noise rather than an alert and would have been ignored within a day. Note the reset can
  legitimately run at an UNCHANGED version -- a reopened entity is enough to trigger it -- so
  reaching the tail does NOT imply a version bump.
  TWO BUGS FOUND WHILE BUILDING IT, both of which made it lie: (1) @($null).Count IS 1, so wrapping a
  missing hashtable key in @() produced a phantom "Foundation '': v vs repo vX.Y" line for all 12
  providers with no ledger row -- it looked like a ledger-parsing bug and was not (probing the ledger
  for empty-tenant rows returned nothing). (2) a bare --since=YYYY-MM-DD yields ZERO git lines while
  --since='YYYY-MM-DD 00:00' yields 310, so the report announced "no provider version changed" while
  ten had -- a false NEGATIVE, the worst outcome for a prompt.
  Baseline 2026-08-17: 20 examined / 15 provider-tenant imports owed / 3 Foundation behind / 0 LIVE
  behind / 2 deliberately held.

audit_name_components.ps1 -- METADATA COMPONENT -> FORM CONTROL coverage. The authority->built
  direction at COMPONENT granularity, and the twin of audit_devdoc_combinations that nobody built.
  Every other gate enumerates the JSON and is therefore closed under what we built, so a
  metadata-defined name component with NO CONTROL produces nothing to audit: no control, no orphan
  attribute, and no test (the plan is generated FROM the JSON). It cannot be found by looking harder
  at what exists -- only the metadata can say a control is MISSING.
  Added 2026-08-17. Cost of not having it: 15 of 20 providers ship no middle-name and no suffix
  control while their own metadata declares request Name with four components (First/Last/Middle/
  Suffix) on the queries we built -- all 15 at 0 FAIL / 0 WARN, four of them (NJ/FL/IL/CA_CLETS)
  tenant-verified ALL-PASS. And 6 of those controls were DELETED on 2026-08-02 after
  audit_wiring_closure correctly reported them unwired: that gate walks JSON->JSON, so it can say a
  control is USELESS but never that one is MISSING, and its answer was misread as "should not exist".
  Capability is wire-PROVEN: AZ_AZDPS v3.11, 10 captures, FormatStringRuleHandler emits
  "DOE, JOHN A JR" and degrades cleanly to "DOE, JOHN JR" (no double space, no stray comma).
  DO NOT "SIMPLIFY" THE SCOPE TO A NAME WHITELIST. First+Last+Middle+Suffix is a GENERIC TYPE
  SIGNATURE the metadata stamps on 100+ non-person fields (ChemicalName, SchoolName,
  AddressStreetName, BoatName, EnhancedNameSearchIndicator; SupervisorName even carries
  Day+Month+Year), and component-count is never control-count in general -- Day+Month+Year
  composites (BirthDate and 200+ siblings) map to exactly ONE FormDate control. Filtering to
  composites REFERENCED BY A BUILT TRANSACTION'S COMBINATIONS leaves exactly one field, 'Name',
  with zero noise across 125 built transactions, so the scope is derived and self-extends.
  Resolves the control through the attribute's own sourceField, never a token search of the form:
  Person carries TWO name pools (DL + DH-suffixed) on the SAME entity, and an entity-wide token
  match reported HI's DriverLicenseQuery against 'nameMiddleDH' -- the wrong card.
  C1 no-control and C2 not-composed BLOCK. C3 not-in-pool (composed, but the fieldId is in no
  combination set[]/any[]) is [NOTE] ONLY, because its impact is UNPROVEN: audit_wiring_closure's
  class A requires "no attribute sources it AND no combo references it", so it deliberately treats
  attribute-sourcing as reaching the wire and calls HI_HCJDC_OFML closed. Neither position has a
  committed log. Settle it with ONE HI Driver License query filling middle + suffix -- HI is the
  only provider that isolates the variable (controls composed, zero any[]).
  0 components compared is a [FAIL], not a vacuous PASS.
  Baseline 2026-08-17: 20 compared / 216 components / 80 C1 / 0 C2 / 4 C3; clean on AZ, NY, TX,
  TX_CCH. Scope is broader than Person -- CA_CLETS also owes it on Vehicle/Firearm/Boat owner-name
  searches.

SKILL usx-adjudicate -- deciding what to DO about a finding (fix / register / dismiss / fix-the-gate).
  Added 2026-08-02 after ten adjudications in one day, two of them wrong on the first attempt.
  The wording of a finding carries almost no information: the same sentence was a real dropped value
  on four providers and correct behaviour on six. Validate the probe, establish cause at COMBINATION
  granularity, and measure branches-compared before AND after any registration.

  tools/audit_prefill_shadow.ps1
    WHICH PREFILL KILLED THE COMBO -- BUILD_RULES 24 enforced at the CAUSE.
    Added 2026-08-05. BUILD_RULES 24 has said since the 35-combos-across-6-providers
    incident that a form initialValue on any set[] field makes it always-present and
    permanently hides every combo needing its absence. NOTHING ENFORCED IT.
    audit_combo_reachability owns the CONSEQUENCE (it reports "DEAD COMBO" once a combo
    is already unreachable) and never says WHY -- which makes a dead-combo verdict read
    like a design trade-off you can accept rather than a defect you caused.
    THE CASE: AZ_AZDPS v3.7 prefilled ImageIndicator, Requestor AND dexStateUserId --
    three set[] fields in one version -- which collapsed the variable requirement of
        DQPN  -> [NameLast, NameFirst]        == DQN's
        DQP   -> [OperatorLicenseNumber]      == DQ's
        ACQB  -> [RegistrationNumber]         == BQ's
        ACQBH -> [BoatHullIdNumber]           == BQH's
    into four EXACT collisions that no ordering can separate, killing DQN/DQ/BQ/BQH. The
    options put to Rob all involved deleting or registering the losers; his answer was
    "we do not leave out queries because it is hard ... use ordering and recognize the
    shadows." The real fix was to UN-prefill the discriminators metadata already supplied
    (ImageIndicator for the DL pairs, RegistrationState for the Boat in/out pairs).
    THE RULE IS NOT "no prefill on a set[] field" -- that would condemn legitimate cases:
      For an ordered pair (A before B) in one QIDM, FAIL only when
        (a) A shadows B on the VARIABLE sets  (set[] minus prefilled fields), AND
        (b) that subset relation does NOT already hold on the RAW set[]s.
      (a) alone is a structural shadow and belongs to audit_combo_reachability. Requiring
      (b) is what spares a prefill that sits in EVERY combo's set[]: it cancels out of both
      sides and creates no new relation -- CA_CLETS purposeCode, and AZ's own
      dexStateUserId, which is REQUIRED (without it the badge combos cannot match at all).
    Honours mutually exclusive existence gates (one EXISTS / other NOT_EXISTS on the same
    field can never co-fire). Prints the pair count and FAILS a zero-pair run -- a gate that
    compared nothing is not a pass.
    Baseline 2026-08-05: 20/20 providers clean, 645 ordered pairs compared, zero false
    positives. Proven able to FAIL by re-injecting the ImageIndicator prefill on a replica
    inside the provider dir: 2 FAIL, naming both pairs and all three culprit prefills.
    Usage: .\audit_prefill_shadow.ps1 -Path <json> [-OutFile <path>]
