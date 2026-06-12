# NJ_NJCJIS — Field Casing Review (camelCase vs PascalCase)

> **SUPERSEDED 2026-06-11 — read this first.** This document's conclusion ("camelCase
> fieldIds are correct; renaming to PascalCase would be a regression") was accurate
> against the CAD contract **as stated at the time** (eng 2026-05-05: CAD emits
> camelCase, case-sensitive; Patch 8 aligned all configs to it). The platform naming
> convention has since **inverted**: PascalCase is now the standard for all form params
> (eng analysis 2026-06-11). OnScene (Forge) submits Pascal attribute params that were
> silently ignored against camelCase config keys — the Newark OnScene failure that
> prompted this review's original question. CAD data payloads are also Pascal now
> (P2/P3 inbound captures, USx tenant). Current state: `NJ_NJCJIS_PASCAL.json`
> (testing-only, scripts/build_nj_njcjis_pascal.ps1) is the recased pilot, imported to
> USx + Newark Foundation 2026-06-11. The camelCase era was correct tracking of the
> then-stated contract — a contract change, not a configuration mistake. Portfolio
> migration earmarked, one provider at a time.

Date: 2026-06-09
Scope: explains camelCase vs PascalCase and documents the current mapping of three fields
(`registrationState`, `vehicleMakeCode`, `sexCode`) inside `NJ_NJCJIS.json` (v3.5).
Prompted by a Newark Foundation request to rename these three to PascalCase.

## 1. camelCase vs PascalCase

- **camelCase** — first word lowercase, later words capitalized: `registrationState`,
  `vehicleMakeCode`, `sexCode`.
- **PascalCase** — every word capitalized, including the first: `RegistrationState`,
  `VehicleMakeCode`, `SexCode`, `State`.

They are different strings. Field matching in this platform is **case-sensitive**, so
`registrationState` and `RegistrationState` are NOT interchangeable.

## 2. How casing relates to the JSON — every field has TWO sides

Each field appears twice in the JSON, in two different casings, **on purpose**:

| Side | Where in JSON | Casing | Who consumes it |
|---|---|---|---|
| Form / CAD side | QIF `fieldId`; QIDM `sourceField`; combo `set[]`/`any[]` | **camelCase** | The on-screen form AND CAD/First-Responder auto-populate (matches the fieldId, case-sensitive) |
| Provider XML side | QIDM attribute `name` + `targetField` | **PascalCase** | The provider's transaction XML schema (the literal element name sent to NJCJIS) |

So camelCase is **not** wrong and PascalCase is **not** wrong — each casing faces a different
system. The QIDM is the bridge: it reads the camelCase form field (`sourceField`) and writes the
PascalCase XML element (`targetField`).

## 3. The three fields, as currently mapped

### registrationState
- **Form (QIF), camelCase** — `NJ_NJCJIS.json:108-118`
  ```json
  "RegistrationState_Input": {                // Craft.js node key (cosmetic)
      "props": {
          "fieldId":  "registrationState",     // <-- the matching key (camelCase)
          "label":  "State",
          "attributeTypeId":  "STATE",
          "initialValue":  "NJ"
      }
  }
  ```
- **QIDM (request mapping)** — `NJ_NJCJIS.json:5471-5477`
  ```json
  { "name": "State", "sourceField": ["registrationState"], "targetField": "State", "codeTypeProvider": "NCIC" }
  ```
  camelCase `registrationState` (form/CAD) → PascalCase XML element `State`.
- Note: the PascalCase form requested, `RegistrationState`, is used **nowhere** in the JSON —
  the form key is `registrationState` and the XML element is `State`.

### vehicleMakeCode
- **Form (QIF), camelCase** — `NJ_NJCJIS.json:360-370`
  ```json
  "VehicleMakeCode_Input": {                  // Craft.js node key (cosmetic)
      "props": {
          "fieldId":  "vehicleMakeCode",       // <-- the matching key (camelCase)
          "label":  "Vehicle Make",
          "attributeTypeId":  "VEHICLE_MAKE",
          "codeTypeProvider":  "NCIC"
      }
  }
  ```
- **QIDM (request mapping)** — `NJ_NJCJIS.json:5488-5493`
  ```json
  { "name": "VehicleMakeCode", "sourceField": ["vehicleMakeCode"], "targetField": "VehicleMakeCode" }
  ```
  camelCase `vehicleMakeCode` (form/CAD) → PascalCase XML element `VehicleMakeCode`.

### sexCode
- **Form (QIF), camelCase** — `NJ_NJCJIS.json:1584` → `"fieldId": "sexCode"`
- **QIDM (request mapping)** — `NJ_NJCJIS.json:5849-5855`
  ```json
  { "name": "SexCode", "sourceField": ["sexCode"], "targetField": "SexCode", "codeTypeProvider": "NIBRS" }
  ```
  camelCase `sexCode` (form/CAD) → PascalCase XML element `SexCode`.

## 4. The likely source of confusion

The Craft.js **node key** is PascalCase (`RegistrationState_Input`, `VehicleMakeCode_Input`),
but the **`fieldId` property** underneath is camelCase. CAD auto-populate matches the `fieldId`
property, not the node key. Eyeballing the node key makes a field look PascalCase when its
matching key is camelCase.

Also, the QIDM attribute `name`/`targetField` are PascalCase (`State`, `VehicleMakeCode`,
`SexCode`) because those are the XML element names — seeing those can read like the field "is"
PascalCase, but that is the XML side, not the form/CAD fieldId.

## 5. CAD vs First Responder — the mapping is GLOBAL, not per-variant

There is **one `fieldId` per field**, shared by all three layout variants
(`default`, `CAD_DISPATCH`, `FIRST_RESPONDER`). The variants only add context cards and reorder;
they do not redefine fieldIds. The QIDM `sourceField → targetField` mapping lives once in the
PROVIDER bundle and is variant-agnostic. Therefore casing cannot be "right for CAD but wrong for
First Responder" — it is the same camelCase string in every context. A real CAD-vs-FR behavioral
difference would live elsewhere (context cards, or what the dispatch system emits), not in
fieldId casing.

## 6. Current state and assessment

- All three fields are **camelCase on the form/CAD side** and **PascalCase on the XML side** —
  the correct, intended configuration. `docs/CAD_AUDIT_NJ_NJCJIS.txt` reports `[PASS]` for all
  three (`in QIF and CAD list`).
- The CAD field list itself is camelCase (`tools/config/cad_field_mapping.json`), and engineering
  confirmed (2026-05-05) CAD dispatch emits camelCase, matched case-sensitively.
- `RegistrationState` / `VehicleMakeCode` / `SexCode` are the **pre–Patch-8 names**;
  `tools/config/patch8_rename_map.json` maps exactly those PascalCase names **→ camelCase** for
  CAD alignment. Renaming the fieldIds back to PascalCase would reverse that fix, flip
  `audit_cad.ps1` to `[FAIL] wrong case`, and break CAD auto-populate (and the USx NJCJIS tenant
  which expects camelCase).

**Conclusion:** the three fields are configured correctly as-is. The PascalCase the form fieldId
"should" be is already present where it belongs (the XML `targetField`/`name`). No fieldId rename
is warranted; doing so would be a regression.
