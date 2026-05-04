# NJ_NJCJIS JSON Inventory

Every iteration saved. Never overwrite.

## Active (root directory)

| File | Version | Date | Description |
|---|---|---|---|
| NJ_NJCJIS_mc.json | v2.0-mc | 2026-04-21 | **Currently testing.** Multi-card layout (2 cards per Vehicle/Person/Boat). 38 PASS / 0 FAIL. |
| NJ_NJCJIS_BASE.json | v1.7 | 2026-04-20 | Phase 1 baseline. Single-card. 25/25 PASS. DO NOT OVERWRITE. |

## Phase Archives

| File | Location | Version | Notes |
|---|---|---|---|
| NJ_NJCJIS_v2.1_2026-04-21.json | phases/03_split_entity/ | v2.1-mc | Split entity Person (mc + split) |
| NJ_NJCJIS_v2.0_2026-04-21.json | phases/02_multicard/ | v2.0-mc | Multi-card build (mc only) |
| NJ_NJCJIS_v1.7_2026-04-20.json | phases/01_standup/ | v1.7 | Final standup single-card (25/25 PASS) |
| NJ_NJCJIS_v1.6_2026-04-20.json | phases/01_standup/ | v1.6 | Pre-NCIC state |
| NJ_NJCJIS_v1.2_2026-04-20.json | phases/01_standup/ | v1.2 | Early standup |

## Version Lineage

```
v1.0-v1.2 (standup iterations)
  → v1.6 (pre-NCIC state)
    → v1.7 (NCIC state + NIBRS sex = Phase 1 COMPLETE)
      → v2.0 (Phase 2 multi-card: Vehicle 2-card, Person 2-card, Boat 2-card)
        → v2.1 (Phase 3 split entity: Person-NJ + Person-OOS, 6 QIFs)
```
