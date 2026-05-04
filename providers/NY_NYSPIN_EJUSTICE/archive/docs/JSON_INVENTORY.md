# NY_NYSPIN_EJUSTICE JSON Inventory

Every JSON version/iteration is documented here. This file tracks what each one is,
when it was built, and its current status.

## Active

| File | Version | Size | Date | Description |
|------|---------|------|------|-------------|
| NY_NYSPIN_EJUSTICE.json | v1.1 | 979KB | 2026-04-20 | **CURRENT** -- Phase 1 reboot. 5 entities (single card each), 7 QIDMs. RMS sex removal fix (AP #18). Validator: 0 errors, 0 warnings. Import PENDING. |

## Phases directory (phases/)

| File | Version | Date | Description |
|------|---------|------|-------------|
| phases/01_standup/NY_NYSPIN_EJUSTICE_v1.0_2026-04-20.json | v1.0 | 2026-04-20 | Phase 1 reboot initial build. FAILED import: missing sexcodeoos attribute in combination any[]. |
| phases/01_standup/NY_NYSPIN_EJUSTICE_v1.1_2026-04-20.json | v1.1 | 2026-04-20 | Phase 1 reboot with RMS sex removal fix. Archive of current root JSON. |

## Version lineage

```
NY_NYSPIN_EJUSTICE.xml (source, sole source for Phase 1 reboot)
  +-- Prior v1.0-v1.21 (archived in git, multi-card/split-entity era)
  |
  +-- Phase 1 reboot (clean restart 2026-04-20)
        +-- v1.0 (FAILED -- sexcodeoos in combination any[])
        +-- v1.1 <-- CURRENT
              - 5 entities: Vehicle, Person, Firearm, Article, Boat
              - 7 QIDMs: VehicleRegistration, Boat, DriverLicense, NyNyspinDriverLicenseName,
                DriverHistory, Gun, ArticleSingle
              - DH-suffix isolation for DriverHistory
              - WINQ/MINQ excluded (no Transaction XML from vendor)
```
