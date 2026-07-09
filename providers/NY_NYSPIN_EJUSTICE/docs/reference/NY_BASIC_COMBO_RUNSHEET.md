# NY_NYSPIN_EJUSTICE v4.6 — Basic Combo Run-Sheet

Purpose: manually run the NY v4.6 basic combos in the USx tenant, evaluate workflow/helper-text/layout,
and capture each so the logs can be ingested. **Do NOT block_entity until this pass is reviewed.**

Provider URL: https://usx-ny-nyspin-ejustice.mark43.com/

---

## How to run + capture ONE combo

1. **Fill & fire** — on `/universal-search`, pick the entity tab, fill the fields listed below, click
   **Send**. (Text entry auto-checks the query and enables Send.)
2. **Capture** — go to `/admin/dex-log`, open the entry that just fired, open the browser Console and
   run `__usxCapture()`. It downloads **`usx_captured_<txId>.json`** to `~/Downloads` (contains the
   ConnectCic request XML + form state + combo context).
3. **Hand back** — leave the capture watcher running (I start it) and it auto-ingests; or just tell me
   and I run `import_captured_tests.ps1`. Each capture becomes one log at
   `logs/<Entity>/NY_NYSPIN_EJUSTICE_v4.6_<Combo>.txt`.

Sample fill values below are synthetic — any well-formed value works; what matters is the
**Expected keyRef** that fires.

---

## A. The 7 primary basic combos (one per card — run these first)

| # | Entity | Card | Fill (fieldId = value) | Expected keyRef |
|---|--------|------|------------------------|-----------------|
| 1 | Vehicle | VEHICLE QUERY | `LicensePlateNumber = TEST123` | **RVEH** |
| 2 | Person | DRIVER LICENSE | `OperatorLicenseNumber = D999888777` | **DLIC** |
| 3 | Person | DRIVER HISTORY | `OperatorLicenseNumberDH = D999888777` | **DALL** |
| 4 | Person | DL NAME SEARCH | `NameLastDGRP = DOE`, `NameFirstDGRP = JOHN` | **DGRP** |
| 5 | Firearm | FIREARM QUERY | `GunSerialNumber = GUN12345` | **GINQ** |
| 6 | Article | ARTICLE QUERY | `ArticleSerialNumber = ART99999`, `ArticleTypeCode = BBICYCL` | **AINQ** |
| 7 | Boat | BOAT QUERY | `RegistrationNumber = FL1234AB` | **RVEH** |

---

## B. DGRP auto-fire isolation — the #1 thing to confirm (2 captures)

DGRP (DL Name Search) must fire **alone from its own card** and must **not** co-fire when only the
Driver License card is used. Two captures prove it:

- **B1 — DGRP fires alone.** Fill ONLY the DL NAME SEARCH card: `NameLastDGRP = DOE`,
  `NameFirstDGRP = JOHN`. Send. Expect **only DGRP** (NyNyspinDriverLicenseNameQuery). No DL/DH co-fire.
- **B2 — DGRP absent from DL.** Fill ONLY the DRIVER LICENSE card — either the name path
  (`BirthDate = 1990-01-15`, `NameLast = DOE`, `NameFirst = JOHN`, `SexCode = M` → DLICN) or OLN
  (`OperatorLicenseNumber = D999888777` → DLIC). Send. Expect the DriverLicenseQuery combo to fire and
  **DGRP to be absent**.

---

## C. Alternate-identifier / out-of-state basics (same cards — run if doing full basic coverage)

State picklists: **leave blank = in-state (NY)**; **fill = out-of-state (OOS)**. DOB `1990-01-15`
shows on the form as `01/15/1990`.

| Entity | Card | Fill | Expected keyRef |
|--------|------|------|-----------------|
| Vehicle | VEHICLE QUERY | `VehicleIdentificationNumber = 1HGCM82633A123456` | RCAR (in-state VIN) |
| Vehicle | VEHICLE QUERY | `LicensePlateNumber = TEST123`, `RegistrationState = GA` | RVEHOUT (OOS plate) |
| Vehicle | VEHICLE QUERY | `VehicleIdentificationNumber = 1HGCM82633A123456`, `RegistrationState = GA` | RVIN (OOS VIN) |
| Person | DRIVER LICENSE | `BirthDate = 1990-01-15`, `NameLast = DOE`, `NameFirst = JOHN`, `SexCode = M` | DLICN (name) |
| Person | DRIVER HISTORY | `OperatorLicenseNumberDH = D999888777`, `purposeCodeDH = C`, `RegistrationStateDH = NJ` | DALLOUT (OLN OOS) |
| Person | DRIVER HISTORY | `BirthDateDH = 1990-01-15`, `NameLastDH = DOE`, `NameFirstDH = JOHN`, `SexCodeDH = M` | DALH (name in-state) |
| Person | DRIVER HISTORY | above + `purposeCodeDH = C`, `RegistrationStateDH = NJ` | DALHOUT (name OOS) |
| Boat | BOAT QUERY | `RegistrationNumber = FL1234AB`, `RegistrationState = GA` | BVEH (OOS reg) |
| Boat | BOAT QUERY | `BoatHullIdNumber = FL1234AB56H7` | RCAR (in-state hull) |
| Boat | BOAT QUERY | `BoatHullIdNumber = FL1234AB56H7`, `RegistrationState = GA` | BVIN (OOS hull) |

---

## D. Identifier-priority guardrails (fill BOTH competing identifiers → priority winner fires)

| Entity | Fill both | Winner (loser must be absent from the wire) |
|--------|-----------|---------------------------------------------|
| Vehicle | `LicensePlateNumber = TEST123` + `VehicleIdentificationNumber = 1HGCM82633A123456` | **RVEH** (Plate > VIN) |
| Person DL | `OperatorLicenseNumber = D999888777` + full name | **DLIC** (OLN > Name) |
| Person DH | `OperatorLicenseNumberDH = D999888777` + full DH name | **DALL** (OLN > Name) |
| Boat | `BoatHullIdNumber = FL1234AB56H7` + `RegistrationNumber = FL1234AB` | **RCAR** (Hull > Reg) |

---

## What to evaluate while running (the point of this pass)

- **Workflow** — does the card order / query flow make sense per entity? Does DGRP feel isolated?
- **Helper text** — are the path tags clear (`(Name search)`, `(DH, ...)`, `(opt)`, `State (leave
  blank for NY)`, `Plate Number (or search by VIN)`)? Anything ambiguous?
- **Layout** — row packing / column widths comfortable? Anything cramped or awkward?

Note any wording/layout changes; those are provisional (refined during manual use, not graded tests).
Once you're happy and the captures are in, we block_entity-lock v4.6.
