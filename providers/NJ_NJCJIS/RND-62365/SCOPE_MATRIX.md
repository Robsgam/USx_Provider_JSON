# RND-62365 — OnScene Failure Scope Re-Verification Matrix

**Run on NJ_NJCJIS v4.7** (the VehicleMakeName fix build). Purpose: (1) confirm the vehicle fix works,
(2) settle whether the failure is vehicle-only (STRAND 1) or all-entity (STRAND 2). No server logs needed.

## Why this matrix
Static analysis (RND-62365 investigation) showed the only evidence-backed failure is the **vehicle**
query (screenshot: plate fails, persons return). Every changed result handler is documented to return
null on missing data — not throw — so a universal all-entity crash is not explained by the JSON. This
matrix replaces Leo's prose ("all OnScene fail") with recorded per-cell results.

## Setup
- Import **NJ_NJCJIS_v4.7.json** to the target tenant (USx test tenant first; Newark if available).
- Reload the form between tests (Clear-form bug: it remembers the last active query — see
  project_clear_form_bug).
- For each cell, record: **PASS** (results render, no error) / **FAIL** (+ paste the exact error text).

## Matrix — run every cell

| # | Entity | Query (key) | Input that returns NO record | Input that returns a RECORD (mock hit) |
|---|--------|-------------|------------------------------|----------------------------------------|
| 1 | Person | DriverLicense (OLN) | OLN with no match | OLN known to return a mock person |
| 2 | Person | DriverLicense (Name) | Name+DOB no match | Name+DOB known mock hit |
| 3 | Vehicle | VehicleRegistration (plate RQ) | plate no match | **plate known to return a mock vehicle (make/model present)** |
| 4 | Vehicle | VehicleRegistration (VIN RQN) | VIN no match | VIN known mock hit |
| 5 | Firearm | Gun (serial QG) | serial no match | serial known mock hit |
| 6 | Article | Article (serial QA) | serial no match | serial known mock hit |
| 7 | Boat | Boat (reg QB / hull QBN) | no match | known mock hit |

**Cell 3 (vehicle-with-record) is the critical one** — it's the path VehicleMakeName runs on. On v4.6 it
failed ("Mock results processed"); on v4.7 it should now render the make.

## Interpretation
- **Only cell 3/4 (vehicle-with-record) failed on v4.6 and now PASSES on v4.7** → STRAND 1 confirmed and
  fixed. Done (pending Newark confirmation + logs next week).
- **All entities FAIL even on the no-record cells (1,3,5,6,7 left column)** → STRAND 2: not the handler.
  The cause is the config-version / dependency-bundle binding (see version probe below). Stop handler
  work; pursue the bundle binding.
- **Only RECORD cells fail across multiple entities** → a result-mapping handler throws on populated data
  in Newark's pre-RND-54190 build. Capture which entities + which field; needs the Datadog stack.

## Companion: version/bundle probe (STRAND 2 test, no logs)
Ask Yevhen / Leo:
> When v4.6 was imported to the Newark Foundation tenant, did the import carry the matching
> **NJ_NJCJIS_Results** config version **and** the dependency bundle, or only the query JSON?
> (In automated-qa the working fix moved NJ_NJCJIS_Results v2→v3 **and** dep bundle 135→136 together.
> If Newark's mock/simulation is bound to a version set and only the query JSON changed, that mismatch
> alone could surface as "Mock results processed" on every query.)

A "query JSON only" answer strongly implicates STRAND 2 regardless of the matrix.
