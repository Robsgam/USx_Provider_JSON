# JSON Inventory - NJ_NJCJIS

All JSON versions produced for this provider.

## Root (current)

> NOTE (2026-06-10): one-JSON-in-root rule SUSPENDED by user directive for the Vehicle
> Stolen design evaluation. Three JSONs coexist until a winner is chosen: mainline +
> two experimental branches. Either branch may be promoted to mainline; the losers
> (and this note) are removed at decision time.

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v3.5 | Current (mainline) | 69P/0F/0W/0LIM. 5 QIDMs, 13 combos. Imported USx NJCJIS Tenant + Newark Foundation 2026-05-28. |
| NJ_NJCJIS_VehStolenSeparate.json | v3.7-SEPARATE | Experimental branch (was RANDOM_COLLAPSED, renamed 2026-06-14) | 70P/0F/0W/0LIM. Stolen suffix-isolated on dedicated "Vehicle Stolen" card (title renamed from "RANDOM" 2026-06-14; licensePlateNumberRand/vehicleIdentificationNumberRand + ncicNumber/vehicleMakeCode); Stolen autoSelect=true, no queriesToDeselect. Built by build_nj_njcjis_vehstolenseparate.ps1. NOT live-tested. |
| NJ_NJCJIS_VehStolenRemoved.json | v3.6-REMOVED | Experimental branch (was RANDOM_REMOVED, renamed 2026-06-14) | 63P/0F/0W/0LIM. VehicleStolenQuery (QVN/QVP/QVV) eliminated — USER-APPROVED SKIP of 3 metadata QV combos. Stolen preserved via Random=Y; sole loss NCIC#. ncicNumber/vehicleMakeCode removed from layout. Built by build_nj_njcjis_vehstolenremoved.ps1. Vehicle live test (request-side) COMPLETE 2026-06-14 — all PASS. |
| NJ_NJCJIS_PASCAL.json | v3.5-PASCAL | TESTING ONLY | 69P/0F/0W. Mainline v3.5 with form-side layer recased to PascalCase (fieldIds, CommSys+RMS sourceFields, combo set[]/any[]; targetFields/defaults/AUTH untouched — NJCJIS XML identical). For manual CAD (camel, expected to FAIL populate) + OnScene (Pascal, expected to work) casing probe. Generated from mainline by build_nj_njcjis_pascal.ps1; no build-process changes. Watch: GunSerialNumber/ArticleSerialNumber vs OnScene's generic 'SerialNumber'. |

## phases/current/

| File | Version | Date | Notes |
|------|---------|------|-------|
| NJ_NJCJIS_v3.5_2026-05-28.json | v3.5 | 2026-05-28 | Name Search card layout — 2 rows. |
| NJ_NJCJIS_v3.4_2026-05-21.json | v3.4 | 2026-05-21 | Single JSON merge. |

## Legacy (deleted, in git history)

| Version | Notes |
|---------|-------|
| v3.0-v3.3 | Pre-merge BASE/MC snapshots. Deleted 2026-06-03. Available in git history. |
| v3.0 LOCKED | Imported Newark Foundation. 14/14 live tests PASS. |
| v1.x | Pre-v2.0 rebuild (2026-04-28). |







## v4.5 (2026-06-24)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v4.5 | Current | 61P/0F/0W/0LIM. |
## v4.4 (2026-06-23)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v4.4 | Current | 63P/0F/0W/0LIM. |
## v4.3 (2026-06-22)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v4.3 | Current | 61P/0F/0W/0LIM. |
## v4.2 (2026-06-18)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v4.2 | Current | 61P/0F/0W/0LIM. |
## v4.1 (2026-06-17)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v4.1 | Current | 61P/0F/0W/0LIM. |
## v4.0 (2026-06-17)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v4.0 | Current | 61P/0F/0W/0LIM. |
## v3.5 (2026-06-03)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| NJ_NJCJIS.json | v3.5 | Current | 69P/0F/0W/0LIM. |
