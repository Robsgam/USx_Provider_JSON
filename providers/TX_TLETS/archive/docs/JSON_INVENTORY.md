# TX_TLETS JSON Inventory

Every JSON version/iteration is documented here. This file tracks what each one is,
when it was built, and its current status.

## Active

| File | Version | Size | Date | Description |
|------|---------|------|------|-------------|
| TX_TLETS.json | v1.0 | 176KB | 2026-04-21 | **CURRENT** -- Phase 1 standup. 3 bundles (ENTITIES, TX_TLETS, RMS). 5 entities, 7 CommSys QIDMs + 2 RMS QIDMs. Reviewed: 60 PASS / 0 FAIL / 1 WARN. Import PENDING. |

## Phases directory (phases/)

| File | Version | Date | Description |
|------|---------|------|-------------|
| phases/01_standup/TX_TLETS_v1.0_2026-04-21.json | v1.0 | 2026-04-21 | Phase 1 archive snapshot. Identical to root TX_TLETS.json. |

## Other files

| File | Size | Date | Description |
|------|------|------|-------------|
| TX_TLETS_layout_preview.html | 29KB | 2026-04-21 | Layout preview HTML for form visualization. Not for import. |

## Version lineage

```
TX_TLETS.xml (source)
  +-- TX_TLETS.json v1.0 <-- CURRENT
        - 5 entities: Vehicle, Person, Firearm, Article, Boat
        - 7 CommSys QIDMs + 2 RMS QIDMs + QRDM
        - 7 open issues from review (ROW_0 parent x5, missing RMS QRDM, SexCode mismatch)
```
