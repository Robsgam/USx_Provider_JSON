CONNECTCIC KNOWLEDGE BASE
===========================
Central reference for all ConnectCIC / CommSys provider JSON projects.
Last updated: 2026-05-06
Covers: 8 providers (NJ/AZ/FL/NY/HI/TX/LA/CA) in consolidated monorepo

CURRENT STATUS: See CLAUDE.md provider table for versions, counts, and import status.
  NJ_NJCJIS is the structural reference for all new builds.
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
FILES IN THIS FOLDER (9 files, organized by question)
================================================================================

  README.txt               This file -- index and overview

  BUILD_RULES.txt          "How do I structure a provider JSON?"
                           3-bundle architecture, AUTH/QMF/QRDM configs, RMS patches 1-6,
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
                           All 30 platform limitations (#1-#30) + all 27 anti-patterns
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
                           test sequences, validator markers, failure investigation

  IMPORT_ERRORS.txt        "Why did import fail?"
                           7 known import errors with root cause and fix

  RULE_HANDLERS.txt        "What handlers exist?"
                           24 handlers: 4 property paths, 9 handler functions,
                           14 attribute rule handlers, 1 special handler.
                           Origin map, dead ends, build script checklist.

  READ ORDER FOR A NEW PROVIDER:
    1. README.txt (this file)
    2. BUILD_RULES.txt (understand the structure before writing any code)
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
    Import error messages:          IMPORT_ERRORS.txt
    Provider-specific constraints:  PROVIDER_CONSTRAINTS.txt
    First-import test checklist:    TESTING_REQUIREMENTS.txt Section 8
    Cross-provider consistency:     PROVIDER_CONSTRAINTS.txt (bottom section)
    Anti-patterns by number:        PLATFORM_CONSTRAINTS.txt (cross-reference index)
    Defaults and usability:         TESTING_REQUIREMENTS.txt Section 6

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
    Master build report. Runs all 6 tools (validator + layout + query sim + picklist + HTML + verify).
    Usage: powershell.exe -ExecutionPolicy Bypass -File build_report.ps1 -Path <json>
    Run after EVERY JSON build or edit.

  tools/verify_build.ps1
    Post-build verification. Catches issues that slip past the structural validator:
      1. Banned string patterns (from banned_patterns.txt)
      2. QIF fieldId / QIDM sourceField / combo consistency
      3. RMS QIDM name vs sourceField alignment
      4. Cross-bundle fieldId consistency
      5. camelCase enforcement (opt-in via -CamelCase flag)
      6. NJ reference pattern comparison (queryLabel, ImageIndicator, keyReference, state)
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

  tools/render_html.ps1
    Self-contained HTML layout report with color-coded fields and QIDM tables.
    Usage: -Path <json> -OutFile <path>

  tools/new_test_log.ps1
    Creates a stub test log in tests/. Required by GATE 2 before every test.
    Usage: -Provider <name> -Variant BASE -Version <ver> -Entity <entity> -Combo <combo>

  tools/test_layout.ps1
    QIF layout tree validator. Checks parent-child relationships and generates
    an HTML form preview for visual inspection.
    Usage: -Path <json>

  tools/compare_hidle.ps1
    Compares a provider's RMS bundle against the current HIDLE.json template.
    Reports structural differences (added/removed/changed attributes and combos).
    Usage: -Path <json>

  tools/build_codetype_test.ps1
    Generates CODETYPE_TEST.json for dropdown validation. Tests which
    codeTypeCategory + codeTypeSource combinations produce non-empty dropdowns.
    Usage: -OutFile <path>

  tools/audit_repo.ps1
    Full monorepo consistency audit. Checks KB docs, build scripts, tools,
    provider JSONs, and CLAUDE.md for drift, stale references, missing
    documentation, banned patterns, report completeness, and cross-provider
    JSON consistency. 11 categories:
      1. Banned patterns repo-wide
      2. Report step count consistency
      3. QueryLabel standard
      4. Stale archive references
      5. Build script completeness (dual output, validator)
      6. Tool documentation
      7. Render tool correctness
      8. CLAUDE.md consistency
      9. Provider canonical structure (dirs, docs)
      10. Report file completeness (all 6 per variant)
      11. Cross-provider JSON consistency (RMS autoSelect, AUTH keyRef, queryLabels)
    Sources of truth extracted at runtime. FAILS (exit 1) on any issue.
    Usage: .\audit_repo.ps1 [-Category <1-11>]

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

  templates/HIDLE.json
    Structural template for all builds. Provides RMS bundle, rule handler names,
    QUERYRESULTDATAMAPPING, and AUTHENTICATION pattern.

  templates/CA_ESUN.json
    Reference for single-card QUERYINPUTFORM layouts.

  providers/FL_FCIC/FL_FCIC.json
    Reference for multi-query person forms (autoSelect, queriesToDeselect,
    DH-suffix pattern, GunQuery sourceField naming).

  providers/NJ_NJCJIS/   *** CONFIRMED BASELINE ***
    Phase 1 standup COMPLETE -- v2.0, 64P/0F/3W/2LIM (2026-04-29).
    Legacy repo (read-only): https://github.com/LooseConnection/NJ_NJCIS_JSON
    NJ_NJCJIS_BASE.json = permanent Phase 1 reference (do not overwrite).
    Best reference for: NCIC state pattern, NIBRS sex pattern, RMS person state patch,
    Phase 1 single-card architecture, build script structure.
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

  templates/CODETYPE_TEST.json
    Code source dropdown test file. Shows which codeTypeCategory values
    populate under which codeTypeSource. Use before committing any new dropdown.

================================================================================
ARCHIVE
================================================================================

  knowledge-base/archive/
    Contains the original pre-consolidation KB files (18 files).
    Preserved for reference only. All content has been merged into the 9 files above.
    Do not use archived files for builds -- use the consolidated versions.
