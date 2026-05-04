# AZ_AZDPS JSON Inventory

Every JSON version/iteration is documented here. This file tracks what each one is,
when it was built, and its current status.

## Active

| File | Version | Size | Date | Description |
|------|---------|------|------|-------------|
| AZ_AZDPS.json | v1.1 | 1159KB | 2026-04-20 | **CURRENT** -- Phase 1 with dexStateUserId auto-fill. Badge hidden on all 5 forms. 8 QIDMs + 5 QIFs (single card each). Validator: 0 errors, 0 warnings. Import PENDING. |

## Phases directory (phases/)

| File | Version | Date | Description |
|------|---------|------|-------------|
| phases/01_standup/AZ_AZDPS_v1.0_2026-04-15.json | v1.0 | 2026-04-15 | Original basic build (8 QIFs, split-entity layout). Superseded by Phase 1 rebuild. |
| phases/01_standup/AZ_AZDPS_v1.0_2026-04-20.json | v1.0 | 2026-04-20 | Phase 1 rebuild: 5 QIFs, single card each, visible Badge field. Superseded by v1.1. |
| phases/01_standup/AZ_AZDPS_v1.1_2026-04-20.json | v1.1 | 2026-04-20 | Archive of current root JSON. dexStateUserId hidden InpH, Badge removed from forms. |
| phases/01_standup/AZ_AZDPS_v2.0_2026-04-20.json | v2.0 | 2026-04-20 | Multi-card/split-entity approach (RETIRED). Forms did not render (QIF provider bug). |
| phases/01_standup/AZ_AZDPS_v2.1_2026-04-20.json | v2.1 | 2026-04-20 | RETIRED. Forms did not render (type='BUNDLE' missing; order flat array). |
| phases/01_standup/AZ_AZDPS_v2.2_2026-04-20.json | v2.2 | 2026-04-20 | RETIRED. Forms did not render (type='BUNDLE' missing; order flat array). |
| phases/01_standup/AZ_AZDPS_v2.3_2026-04-20.json | v2.3 | 2026-04-20 | RETIRED. Rendered but wrong layout (split entity + multi-card). Triggered Phase 1 rebuild. |

## Version lineage

```
AZ_AZDPS.xml + AZ_AZDPS.pdf (sources)
  +-- v2.x series (multi-card/split-entity, RETIRED)
  |     v2.0 -> v2.1 -> v2.2 -> v2.3 (all failed or wrong layout)
  |
  +-- Phase 1 rebuild (single-card approach)
        +-- v1.0 2026-04-15 (original basic build, 8 QIFs)
        +-- v1.0 2026-04-20 (Phase 1 rebuild, 5 QIFs, visible Badge)
        +-- v1.1 2026-04-20 <-- CURRENT
              - 5 entities: Vehicle, Person, Firearm, Article, Boat
              - 8 QIDMs: VehicleRegistration, AzAzdpsDriverLicense, DriverHistory,
                Gun, Article, Boat, WMPIWantedPerson, WMPIMissingPerson
              - dexStateUserId hidden auto-fill on all forms
              - DH-suffix isolation for DriverHistory
              - NCIC state, NIBRS sex confirmed
```
