CONNECTCIC KNOWLEDGE BASE
===========================
Central reference for all ConnectCIC / CommSys provider JSON projects.
Last updated: 2026-05-04
Covers: 7 providers (NJ/AZ/FL/NY/HI/TX/LA) in consolidated monorepo

CURRENT BASELINE (use as structural reference for all new builds):
  NJ_NJCJIS_BASE.json -- v1.7 Phase 1, 25/25 PASS (2026-04-20)
  Phase model: single-entity, single-card QIFs. Confirm all QIDMs before layout work.
  NCIC state pattern confirmed NJ + AZ. NIBRS sex confirmed NJ + AZ.
  Avoid old NJ v3.x (split entity) and old NY v1.0-v1.21 (multi-form) as templates --
  those were built before Phase 1 model was established. Start from Phase 1 model.

This folder is the single authoritative reference for all future builds.
Read it before starting any new provider or making any structural change.

SOURCE AUTHORITY RULE: The provider XML (MetaData) is the build authority.
  When MetaData and DevDoc (PDF) disagree, MetaData wins.
  DevDoc-only fields are excluded from the build.
  Document any MetaData vs. DevDoc discrepancies in [PROVIDER]_PDF_XML_INCONSISTENCIES.txt.

================================================================================
FILES IN THIS FOLDER
================================================================================

  README.txt               This file -- index and overview
  BUNDLE_ARCHITECTURE.txt  3-bundle structure, AUTH/QMF/QRDM patterns, RMS patches, rule handlers
  FIELD_RULES.txt          Field type selection, codeType pairings, attribute rules
  QIDM_ARCHITECTURE.txt    QIDM design: combinations, routing, merge/split decisions
  FORM_ARCHITECTURE.txt    QIF design: state fields, layout, multi-card patterns
  IMPORT_ERRORS.txt        Error messages seen at import -- cause and fix
  ANTI_PATTERNS.txt        Confirmed dead ends -- do not attempt these (AP #1-27)
  BUILD_CHECKLIST.txt      Pre-build, pre-import, post-import steps
  SEX_CODE_PATTERN.txt     *** How to configure sex code for CommSys + RMS simultaneously ***
                           Three-layer chain (form + QIDM + RMS). Confirmed AZ, NJ, FL.
  RMS_SEX_ISSUE_REPORT.txt Full history of sex code investigation (19 options tested, root cause).
  RULE_HANDLERS.txt        Complete reference for all 24 rule handlers: 4 property paths,
                           handler functions, attribute rule handlers, dead ends.
  DEFAULTS_USABILITY.txt   Standard defaults, cross-project audit, State default safety rules
  DEVELOPER_TOOLS.txt      Required tools, scripts, workflow, and folder structure

  LIMITATION FILES (4 files, separated by category):
  PLATFORM_LIMITATIONS.txt   Immutable platform behaviors (query routing, field encoding,
                              shared pool, server-side overrides). #1-5, #7, #9, #23, #26, #28-30
  JSON_LIMITATIONS.txt        JSON structural/config rules (bundle order, field naming, code types,
                              type safety, layout constraints). #8, #10-14, #16-22, #24-25, #27
  TESTING_LIMITATIONS.txt     Instance-specific verification requirements, unconfirmed features,
                              validator markers. #6, #15, confirmation matrix
  PROVIDER_LIMITATIONS.txt    Per-provider exceptions and constraints. NJ/AZ/FL/NY/HI/TX/LA
                              specific rules, cross-provider consistency checks

  READ ORDER FOR A NEW PROVIDER:
    0. DEVELOPER_TOOLS.txt (verify all tools are installed)
    1. README.txt (this file)
    2. BUNDLE_ARCHITECTURE.txt (understand the structure before writing any code)
    3. PLATFORM_LIMITATIONS.txt (know the immutable platform constraints)
    4. JSON_LIMITATIONS.txt (know the JSON structural rules)
    5. ANTI_PATTERNS.txt (know what not to try before writing any field)
    6. FIELD_RULES.txt (look up every field type and code type pairing)
    7. QIDM_ARCHITECTURE.txt (combination and routing rules)
    8. FORM_ARCHITECTURE.txt (layout patterns per entity)
    9. PROVIDER_LIMITATIONS.txt (check your provider's specific constraints)
   10. BUILD_CHECKLIST.txt (run through before building, importing, and testing)
   11. DEFAULTS_USABILITY.txt (standard defaults, State safety, cross-project consistency)
   12. TESTING_LIMITATIONS.txt (instance-specific tests for first import)

  SPECIFIC TOPICS (go directly here for known issues):
    Sex code (CommSys + RMS):       SEX_CODE_PATTERN.txt
    State field architecture:       FIELD_RULES.txt Section 4
    Article type dropdown:          FIELD_RULES.txt Section 2 (codeTypeSource=CA_CLETS)
    Import error messages:          IMPORT_ERRORS.txt
    Provider-specific constraints:  PROVIDER_LIMITATIONS.txt
    First-import test checklist:    TESTING_LIMITATIONS.txt Section 1
    Cross-provider consistency:     PROVIDER_LIMITATIONS.txt (bottom section)

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
    Phase 1 standup COMPLETE -- v1.7, 25/25 PASS (2026-04-20).
    Legacy repo (read-only): https://github.com/LooseConnection/NJ_NJCIS_JSON
    NJ_NJCJIS_BASE.json = permanent Phase 1 reference (do not overwrite).
    Best reference for: NCIC state pattern, NIBRS sex pattern, RMS person state patch,
    Phase 1 single-card architecture, build script structure.
    AVOID as template: v3.x series (split entity NJ/OOS); archived in phases/08_split_entities/.

  providers/NY_NYSPIN_EJUSTICE/
    Phase 1 reboot complete -- v1.1 built (2026-04-20), import PENDING.
    Legacy repo (read-only): https://github.com/Robsgam/NY_NYSPIN_EJUSTICE
    Best reference for: DGRP/NyNyspinDriverLicenseNameQuery separate transaction,
    DALL+DALH invented keyRef, DH-suffix isolation, blank-default NJ_NIBRS_STATE (NCIC unconfirmed NY),
    NIBRS_SEX CommSys-only + sex removed from RMS (when reverse-lookup unconfirmed).
    AVOID as template: old NY v1.0-v1.21 (multi-form split-entity before Phase 1 model).

  providers/AZ_AZDPS/
    Phase 1 -- v1.1 built (2026-04-20), forms confirmed rendered, tests PENDING.
    Legacy repo (read-only): https://github.com/Robsgam/AZ_AZDPS
    Best reference for: all-on-one-person-card design (DL + DH + Wanted + Missing),
    dexStateUserId auto-populate pattern (badge hidden, auto-filled from officer profile),
    yyyyMMdd date format, AZ NCIC/NIBRS confirmed patterns, Wanted/Missing on Person form.
    8 QIDMs: VehicleReg, DL (4 paths), DH (2 paths), GunQuery, ArticleSingle, BoatQuery (4 paths),
    WMPIWanted (2 paths), WMPIMissing (2 paths).

  templates/CODETYPE_TEST.json
    Code source dropdown test file. Shows which codeTypeCategory values
    populate under which codeTypeSource. Use before committing any new dropdown.

================================================================================
FULL BUILD GUIDE (workflow, prompts, folder structure)
================================================================================

  knowledge-base/CONNECTCIC_BUILD_GUIDE.txt

  The build guide covers: folder structure, standup prompts, gap check process,
  build script pattern, phase transitions, test log format, documentation workflow.
  This knowledge base covers: confirmed technical rules and known issues.
  Use both together.
