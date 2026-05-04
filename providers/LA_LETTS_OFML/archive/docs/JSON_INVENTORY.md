# LA_LETTS_OFML JSON Inventory

Every JSON version/iteration is documented here. This file tracks what each one is,
when it was built, and its current status.

## Active

| File | Version | Date | Description |
|------|---------|------|-------------|
| LA_LETTS_OFML_BASE.json | v1.0 | 2026-04-22 | **CURRENT** -- Phase 1 standup. 3 bundles (LA_LEMS, ENTITIES, RMS). 5 entities, 6 CommSys QIDMs + 2 RMS QIDMs. Import PENDING. |

## Phases directory (phases/)

| File | Version | Date | Description |
|------|---------|------|-------------|
| phases/01_standup/LA_LETTS_OFML_v1.0_2026-04-22.json | v1.0 | 2026-04-22 | Phase 1 archive snapshot. Identical to root LA_LETTS_OFML_BASE.json. |

## Version lineage

```
LA_LETTS_OFML.json (source)
  +-- LA_LETTS_OFML_BASE.json v1.0 <-- CURRENT
        - 5 entities: Vehicle, Person, Firearm, Article, Boat
        - 6 CommSys QIDMs + 2 RMS QIDMs + QRDM
        - Note: ENTTIY_Boat typo fixed 2026-04-22
```
