# First Responder layout not rendering Vehicle field defaults — NJ_NJCJIS

**Provider:** NJ_NJCJIS (v3.5) · **Date:** 2026-06-15 · **For:** Platform engineering

## Summary

The First Responder form renders the Vehicle tab fields **blank** (no Plate Type, Plate
Year, State, Image defaults), while the standard (`default`) form renders them populated.

The JSON config is **correct and identical** across all three layout contexts
(`default`, `CAD_DISPATCH`, `FIRST_RESPONDER`). The `initialValue` props are present in the
First Responder variant exactly as in `default`. This points to the FR render path not
applying QIF `initialValue` on form fields — the same behavior already observed for CAD
Dispatch.

**Verified programmatically:** all 4 NJ JSON variants have identical `initialValue`s across
all 3 layout contexts — 40 field-default comparisons, 0 mismatches.

## Evidence — identical config in all 3 contexts

File: `providers/NJ_NJCJIS/NJ_NJCJIS.json`, Vehicle QIF, `licensePlateTypeCode` + `licensePlateYear`.

### "default" variant (L235 / L257)

```jsonc
"LicensePlateTypeCode_Input": {
  "type": { "resolvedName": "FormSelect" },
  "props": {
    "fieldId": "licensePlateTypeCode",
    "label": "Plate Type",
    "initialValue": "PC",
    "codeTypeSource": "NCIC",
    "codeTypeCategory": "NCIC_LICENSE_PLATE_TYPE"
  },
  "hidden": false,
  "parent": "ROW_VEH_P1"
},
"LicensePlateYear_Input": {
  "type": { "resolvedName": "FormInput" },
  "props": {
    "fieldId": "licensePlateYear",
    "label": "Plate Year",
    "maxLength": "4",
    "initialValue": "2026"
  }
}
```

### "CAD_DISPATCH" variant (L609 / L631)

```jsonc
"LicensePlateTypeCode_Input": {
  "type": { "resolvedName": "FormSelect" },
  "props": {
    "fieldId": "licensePlateTypeCode",
    "label": "Plate Type",
    "initialValue": "PC",
    "codeTypeSource": "NCIC",
    "codeTypeCategory": "NCIC_LICENSE_PLATE_TYPE"
  },
  "hidden": false,
  "parent": "ROW_VEH_P1"
},
"LicensePlateYear_Input": {
  "type": { "resolvedName": "FormInput" },
  "props": {
    "fieldId": "licensePlateYear",
    "label": "Plate Year",
    "maxLength": "4",
    "initialValue": "2026"
  }
}
```

### "FIRST_RESPONDER" variant (L1064 / L1086) — same config, but renders blank

```jsonc
"LicensePlateTypeCode_Input": {
  "type": { "resolvedName": "FormSelect" },
  "props": {
    "fieldId": "licensePlateTypeCode",
    "label": "Plate Type",
    "initialValue": "PC",
    "codeTypeSource": "NCIC",
    "codeTypeCategory": "NCIC_LICENSE_PLATE_TYPE"
  },
  "hidden": false,
  "parent": "ROW_VEH_P1"
},
"LicensePlateYear_Input": {
  "type": { "resolvedName": "FormInput" },
  "props": {
    "fieldId": "licensePlateYear",
    "label": "Plate Year",
    "maxLength": "4",
    "initialValue": "2026"
  }
}
```

Same pattern for the other Vehicle defaults in the FR variant:
`registrationState: "NJ"` (L946), `imageIndicator: "N"` (L966 / L988).

## Cross-file verification (all 4 NJ JSONs × 5 entity forms × 3 contexts)

| NJ JSON | Vehicle | Person | Firearm | Article | Boat |
|---|---|---|---|---|---|
| NJ_NJCJIS.json (mainline) | MATCH | MATCH | MATCH | MATCH | MATCH |
| NJ_NJCJIS_PASCAL.json | MATCH | MATCH | MATCH | MATCH | MATCH |
| NJ_NJCJIS_VehStolenRemoved.json | MATCH | MATCH | MATCH | MATCH | MATCH |
| NJ_NJCJIS_VehStolenSeparate.json | MATCH | MATCH | MATCH | MATCH | MATCH |

Total: 40 field-default comparisons, 0 mismatches.

## Question for engineering

Does the First Responder (and CAD Dispatch) render path intentionally ignore QIF
`initialValue` on form fields?

- If **yes**, please confirm so we document it as expected behavior.
- If **no**, it is a render bug: the config is correct and identical across all three
  contexts in every NJ JSON.

Query integrity is preserved either way — combination-level `defaults[]` inject these values
into the dispatched XML, so the actual query still carries PlateType=PC, PlateYear=2026, etc.
The issue is purely the displayed form in the First Responder context.
