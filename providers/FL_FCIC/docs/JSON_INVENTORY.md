# JSON Inventory -- FL_FCIC

All JSON versions produced for this provider.

## Root (current)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC.json | v4.4 | Current | 87P/0F/0W. Imported USx FCIC Tenant 2026-05-27. VehStolen+BQ removed. |

## phases/base/

| File | Version | Date | Notes |
|------|---------|------|-------|
| FL_FCIC_BASE.json | v3.1 | 2026-05-07 | Current phase snapshot |

## phases/mc/

| File | Version | Date | Notes |
|------|---------|------|-------|
| FL_FCIC_MC.json | v3.1 | 2026-05-07 | Current phase snapshot |

## phases/ (other)

| File | Version | Date | Notes |
|------|---------|------|-------|
| FL_FCIC_BASE_2026-05-01_backup.json | v2.6 | 2026-05-01 | Pre-v3.0 backup |
| 01_standup/FL_FCIC_v2.1_CLEAN_noBOM.json | v2.1 | -- | Phase 1 standup artifact |

## archive/

| File | Version | Status | Notes |
|------|---------|--------|-------|
| archive/FL_FCIC_BASE_v1.0_2026-04-07.json | v1.0 | Archived | Initial standup (2026-04-09). |
| archive/FL_FCIC_BASE_v1.1_2026-04-07.json | v1.1 | Archived | Iteration (2026-04-09). |
| archive/FL_FCIC_BASE_v1.2_2026-04-07.json | v1.2 | Archived | Iteration (2026-04-09). |
| archive/FL_FCIC_BASE_v1.3_2026-04-07.json | v1.3 | Archived | Iteration (2026-04-09). |
| archive/FL_FCIC_BASE_v1.4_2026-04-07.json | v1.4 | Archived | Last v1.x iteration (2026-04-09). |
| archive/FL_FCIC_v2.2_test.json | v2.2 | Archived | Single-QIF test build (2026-04-21). |
| archive/FL_FCIC_v2.3_split.json | v2.3 | Archived | Entity-split attempt (2026-04-21). |
| archive/FL_FCIC_v2.5_2026-04-21.json | v2.5 | Archived | Pre-v2.6 iteration (2026-04-21). |
| archive/FL_FCIC_v2.6_2026-04-22.json | v2.6 | Archived | Last v2.x before v3.0 rebuild (2026-04-23). |



## v4.4 (2026-05-27)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC.json | v4.4 | Current | 87P/0F/0W/0LIM. |
## v4.3 (2026-05-21)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC.json | v4.3 | Current | 101P/0F/0W/0LIM. |
## v4.2 (2026-05-19)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v4.2 | Current | 97P/0F/0W/0LIM. Removed WantedPersonQuery QIDM (CommSys auto-sends QW). 7 QIDMs, 33 combos. |
| FL_FCIC_MC.json | v4.2 | Current | 97P/0F/0W/0LIM. Same QW removal as BASE. |

## v4.1 (2026-05-15)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v4.1 | Archived | 102P/0F/0W/0LIM. State label fix (Vehicle+Boat). |
| FL_FCIC_MC.json | v4.1 | Archived | 102P/0F/0W/0LIM. MC 2-card: Vehicle(Options+Search), Boat(Options+Search). State+Stolen isolated. |

## v4.0 (2026-05-13)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v4.0 | Archived | 102P/0F/0W/0LIM. Attention field now visible FormInput (was hidden handler-only). |
| FL_FCIC_MC.json | v4.0 | Archived | 102P/0F/0W/0LIM. MC variant. |

## v3.9 (2026-05-12)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v3.9 | Archived | 102P/0F/0W/0LIM. MC Person 2-card layout (Search Options merged into DL). |
| FL_FCIC_MC.json | v3.9 | Archived | 102P/0F/0W/0LIM. MC variant. |

## v3.8 (2026-05-12)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v3.8 | Archived | 102P/0F/0W/0LIM. RegistrationStateDH isolates DH State from DL routing. |
| FL_FCIC_MC.json | v3.8 | Archived | 102P/0F/0W/0LIM. MC variant. |

## v3.7 (2026-05-12)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v3.7 | Archived | 102P/0F/0W/0LIM. Person State label fix for DH reachability. |
| FL_FCIC_MC.json | v3.7 | Archived | 102P/0F/0W/0LIM. MC variant. |

## v3.6 (2026-05-12)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v3.6 | Archived | 102P/0F/0W/0LIM. Metadata audit: PurposeCode any[], FRQ/QV field alignment, no PurposeCode default. |
| FL_FCIC_MC.json | v3.6 | Archived | 102P/0F/0W/0LIM. MC variant. |

## v3.5 (2026-05-12)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v3.5 | Archived | 102P/0F/0W/0LIM. One-directional queriesToDeselect fix + DH autoSelect=true. |
| FL_FCIC_MC.json | v3.5 | Archived | 102P/0F/0W/0LIM. MC variant. |

## v3.4 (2026-05-11)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| FL_FCIC_BASE.json | v3.4 | Archived | 101P/0F/0W/0LIM. DH-suffix fieldIds, queriesToDeselect, combo ordering, camelCase conversion. |
| FL_FCIC_MC.json | v3.4 | Archived | 102P/0F/0W/0LIM. MC variant. |
