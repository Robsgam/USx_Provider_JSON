# FL_FCIC JSON Inventory

Every JSON version/iteration is preserved. This file documents what each one is,
when it was built, and whether it's active, archived, or a dead-end.

## Active (root directory)

| File | Version | Size | Date | Description |
|------|---------|------|------|-------------|
| FL_FCIC_BASE.json | v2.6 | — | 2026-04-22 | **CURRENT** — Attention fix: added CommsysGetLastNameFirstNameInitialRuleHandler to DH QIDMs, removed Attention FormInput, moved Attention set[]→any[]. Matches CA_eSUN/LA_LETTS_OFML pattern. |
| FL_FCIC_v2.6_2026-04-22.json | v2.6 | — | 2026-04-22 | Archive snapshot of v2.6. |
| FL_FCIC_v2.5_2026-04-21.json | v2.5 | 189KB | 2026-04-21 | v2.2 + label updates + DHQ autoSelect=True + DHQ State→any[]. Superseded by v2.6. |
| FL_FCIC_v2.2_test.json | v2.2 | 189KB | 2026-04-21 | BASELINE — Single Person QIF (6 cards). Imported and tested. FDQName CONFIRMED. |
| FL_FCIC_v2.3_split.json | v2.3 | 1.1MB | 2026-04-21 | Split entity Person (FL/OOS/DH). 67 PASS. **SexCode reverse-lookup BROKEN** (LIMITATION #28). |
| FL_FCIC_BASE.json | v1.4 | 998KB | 2026-04-07 | Pre-entity-split base. 25 FL_FCIC QIDMs, 5 QIFs, single-card per entity. |
| FL_FCIC_entity_split_investigation.zip | — | 47KB | 2026-04-21 | Package: v2.2 + v2.3 + failure doc for entity-split codeTypeProvider investigation. |

## Scripts (scripts/)

| File | Purpose |
|------|---------|
| build_v2.1.ps1 | v2.1 merged Person build from FL_FCIC.json |
| build_v2.1_test.ps1 | v2.1 layout test variant |
| build_v2.2_test.ps1 | v2.2 build (6-card Person, Firearm +NCIC/PCN) |
| build_v2.3_split.ps1 | v2.3 split entity Person build from v2.2 |
| build_layout_fix.ps1 | Layout fix utilities |
| transform_person_layout.ps1 | Person layout transformation |
| test_commsys.ps1 | CommSys XML test harness |
| test_layout.ps1 | Layout rendering test |
| verify_json.ps1 | JSON structure verification |

## Test/Diagnostic (tests/ — not for import)

| File | Size | Date | Purpose |
|------|------|------|---------|
| FL_FCIC_ProviderTest.json | 711KB | 2026-04-20 | NJ_NJCJIS config under FL_FCIC provider. Proved reverse-lookup works on FL instance. |
| FL_FCIC_SexTest_v2.json | 166KB | 2026-04-17 | Entity-split with attributeTypeId=SEX. Proved duplicate targetField is the bug. |
| FL_FCIC_SexCode_Test.json | 45KB | 2026-04-16 | Early sex code test (minimal config). |

## Phases (phases/)

| File | Location | Version | Description |
|------|----------|---------|-------------|
| FL_FCIC_v2.4_hybrid.json | 02_split_entity/ | v2.4 | Hybrid: FL=attributeTypeId, OOS=codeTypeCategory. **BROKEN** (same collision). |
| FL_FCIC_v2.3_2026-04-21.json | 02_split_entity/ | v2.3 | Split entity archive copy. |
| FL_FCIC.json | phases/ | v2.0 | Entity-split era (OOS-suffix fieldIds). Duplicate targetField bug. |
| FL_FCIC_v2.0_2026-04-09.json | phases/ | v2.0 | Entity-split era snapshot. |
| FL_FCIC_v2.1_CLEAN.json | 01_standup/ | v2.1 | Merged Person, type fixes applied. Superseded by v2.2. |
| FL_FCIC_v2.1_CLEAN_noBOM.json | 01_standup/ | v2.1 | Cache-bust copy of v2.1_CLEAN. |
| FL_FCIC_v2.1_test.json | 01_standup/ | v2.1 | First v2.1 build. Type bugs (AP#21-23). |
| FL_FCIC_v2.1_layout_test.json | 01_standup/ | v2.1 | Layout test during v2.1→v2.2 transition. |

## Archive directory (archive/)

| File | Version | Date | Description |
|------|---------|------|-------------|
| FL_FCIC_BASE_v1.0_2026-04-07.json | v1.0 | 2026-04-07 | Initial full build from FL_FCIC.xml. |
| FL_FCIC_BASE_v1.1_2026-04-07.json | v1.1 | 2026-04-07 | Added all NCIC/Nlets combos. |
| FL_FCIC_BASE_v1.2_2026-04-07.json | v1.2 | 2026-04-07 | Per-transaction field review. |
| FL_FCIC_BASE_v1.3_2026-04-07.json | v1.3 | 2026-04-07 | KQ combo tightened. |
| FL_FCIC_BASE_v1.4_2026-04-07.json | v1.4 | 2026-04-07 | autoSelect/queriesToDeselect. Final BASE. |

## Version lineage

```
FL_FCIC.xml (source)
  └─ FL_FCIC_BASE v1.0 → v1.1 → v1.2 → v1.3 → v1.4 (archive/)
       └─ FL_FCIC.json v2.0 (entity-split, DEAD END — duplicate targetField)
            └─ FL_FCIC_v2.1_test.json (merged Person, CRASHED — type bugs AP#21-23)
                 └─ FL_FCIC_v2.1_CLEAN.json (type fixes applied)
                      └─ FL_FCIC_v2.2_test.json ← BASELINE (imported, FDQName CONFIRMED)
                           └─ FL_FCIC_v2.3_split.json (BROKEN — LIMITATION #28)
                           │    └─ FL_FCIC_v2.4_hybrid.json (BROKEN — same collision)
                           └─ FL_FCIC_v2.5_2026-04-21.json (label/autoSelect/State fixes)
                                └─ FL_FCIC_v2.6_2026-04-22.json ← CURRENT
                                     Attention fix: handler added, form field removed,
                                     Attention moved set[]→any[] on both DH QIDMs.

Entity-split + codeTypeProvider: 3 approaches tested, ALL BROKEN.
See PLATFORM_LIMITATIONS.txt LIMITATION #28 and ENTITY_SPLIT_CODETYPEPROVIDER_FAILURE.txt.
```
