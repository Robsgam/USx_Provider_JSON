# TX_TLETS v1.0 Review

**Reviewed**: 2026-04-21
**Reviewer**: Claude Code (via FL_FCIC project toolchain)
**File**: TX_TLETS.json (176KB)
**Validator**: 60 PASS / 0 FAIL / 1 WARN
**Layout**: 5 tree integrity errors (all CAD_DISPATCH)
**CommSys sim**: 18/29 combos fire with default test data

---

## Architecture Summary

| Component | Count | Notes |
|-----------|-------|-------|
| Bundles | 3 | ENTITIES, TX_TLETS, RMS |
| Entities | 5 | Vehicle, Person, Firearm, Article, Boat |
| CommSys QIDMs | 7 | Vehicle, DLQ, DHQ, Article, Boat, Gun + Results |
| RMS QIDMs | 2 | Vehicle, Person (in TX_TLETS bundle) |
| RMS configs | 2 | AUTH + QMF only |
| Layout variants | 2 | default + CAD_DISPATCH (no FIRST_RESPONDER) |

### Query Keys

| QIDM | Entity | Keys | Combos |
|------|--------|------|--------|
| TX_TLETS_VehicleInsuranceRegistrationQuery | Vehicle | RQ, QV, DPSI, REG, VIN | 7 |
| TX_TLETS_DriverLicenseQuery | Person | DQ, QW, CPL, RSDWW | 5 |
| TX_TLETS_DriverHistoryQuery | Person | KQ | 2 |
| TX_TLETS_ArticleSingleQuery | Article | QA | 2 |
| TX_TLETS_BoatQuery | Boat | QB, BQ | 5 |
| TX_TLETS_GunQuery | Firearm | QG | 2 |
| RMS Vehicle search query | Vehicle | (REST) | 2 |
| RMS Person Search query | Person | (REST) | 4 |

### TX-Specific Features

- **VehicleInsuranceRegistrationQuery** (not standard VehicleRegistrationQuery)
- **DPSI** combo: StickerNumber (TX DPS sticker)
- **REG** combo: FinancialResponsibilityType (TX insurance verification)
- **VIN** combo: FinancialResponsibilityType + VIN
- **CPL** combo: Criminal Punishment List (Name-based, TX-specific)
- **RSDWW** combo: OLN-based DL query (TX-specific variant)
- State initialValue="TX" on Vehicle and Person forms

---

## Issues Found

### CRITICAL — Fix Before Import

**1. CAD_DISPATCH layout: ROW_0 parent mismatch (all 5 entities)**
ROW_0 (CONTEXT_INFO_CARD's CAD row) has `parent: "ROOT_CARD"` instead of `parent: "CONTEXT_INFO_CARD"`.
CONTEXT_INFO_CARD.nodes = ["ROW_0"] is correct, but the child doesn't point back.
This breaks parent/child tree integrity. Platform may reject or misrender.
**Fix**: Change ROW_0.parent from "ROOT_CARD" to "CONTEXT_INFO_CARD" in all 5 CAD_DISPATCH layouts.

### HIGH — Will Cause Runtime Issues

**2. RMS bundle incomplete — missing QRDM + ResultsLayout**
RMS bundle has only 2 configs (AUTH + QMF). Missing:
- QUERYRESULTDATAMAPPING (RMS_Results) — needed to parse RMS response data
- QUERYRESULTSLAYOUT (RMS_ResultsLayout) — needed to render RMS results in UI
Without these, RMS queries may fire but results won't display.
**Fix**: Add RMS_Results and RMS_ResultsLayout configs (copy from HIDLE.json template).

**3. SexCode config mismatch — form vs RMS QIDM**
- Form field: `codeTypeSource: "NCIC", codeTypeCategory: "SEX"` — stores display string ("M"/"F"/"U")
- RMS QIDM: `useAttributeId: true, targetField: "sexAttrId"` — expects numeric attribute ID
- Result: RMS elastic search will receive `sexAttrId: "M"` (string) instead of numeric attr ID
- CommSys QIDM: No rule/codeTypeProvider on SexCode — passes whatever form stores
**Fix**: See KB SEX_CODE_PATTERN.txt. Two options:
  a. Use `attributeTypeId: "SEX"` on form + `codeTypeProvider: "NIBRS"` on CommSys QIDM attr (if instance supports reverse-lookup)
  b. Keep codeTypeCategory="SEX" on form, remove sex from RMS QIDM entirely (CommSys-only)

### MEDIUM — Should Fix

**4. No FIRST_RESPONDER layout variant**
All 5 entities have only default + CAD_DISPATCH. Platform may expect FIRST_RESPONDER.
Typically FIRST_RESPONDER = CAD_DISPATCH + LinkToEvent checkbox.
**Fix**: Clone CAD_DISPATCH, add CONTEXT_ROW2 with LinkToEvent_Input (FormCheckbox).

**5. Person single-card design — no DH separation**
DLQ and DHQ share all field IDs (no DH-suffix fields like NameFirstDH).
autoSelect/queriesToDeselect handles mutual exclusion, but:
- Both queries send identical data (same Name, DOB, Sex values)
- User can't fill DH-specific values separate from DL
- If PurposeCode/Attention are optional (in any[]), KQ can fire without them
**Consider**: Adding DH-suffix fields and multi-card layout (FL_FCIC v2.2 pattern) for clearer UX.

**6. MessageKey sourceField not on form (WARN)**
DLQ has attribute `MessageKey` (sourceField="MessageKey") but no form field.
This may be intentional (auto-generated from combo selection), or it may be a missing hidden field.
**Action**: Test on import — if combo selection auto-populates MessageKey, this is fine.

### LOW — Cleanup

**7. Build script hardcoded path**
`scripts/build_tx_tlets.ps1` line 19: `$DIR = "C:\Users\Gordon Hallof\TX_TLETS"`
**Fix**: Update to `$DIR = $PSScriptRoot\..` or correct user path.

**8. Project-specific validator is limited**
`scripts/validate_tx_tlets.ps1` runs 6 checks but misses encoding/BOM, layout tree validation, autoSelect conflicts, ruleHandlers format, keyRef vs keyReference checks.
**Fix**: Use the universal `validate.ps1` from connectcic-validator/ as primary validator. Keep project-specific one for QIDM-specific checks.

---

## Tool Results

### Validator (connectcic-validator/validate.ps1)
```
60 PASS / 0 FAIL / 1 WARN
WARN: TX_TLETS_DriverLicenseQuery has sourceField 'MessageKey' not found in Person QIF
```

### Layout Preview (test_layout.ps1)
```
5 entities rendered, 2 layouts each
5 ERRORS: ROW_0 parent mismatch in all CAD_DISPATCH layouts
```

### CommSys Simulator (test_commsys.ps1)
- Vehicle: 1/7 fire (State-dependent combos skip without test data for State)
- Person DLQ: 5/5 fire
- Person DHQ: 2/2 fire
- Article: 2/2 fire
- Boat: 3/5 fire (BQ combos skip — no State in test data)
- Gun: 2/2 fire

---

## Recommendations (priority order)

1. Fix ROW_0 parent in all 5 CAD_DISPATCH layouts
2. Add RMS_Results + RMS_ResultsLayout to RMS bundle
3. Test SexCode on import — confirm CommSys gets code, decide RMS approach
4. Add FIRST_RESPONDER layouts
5. Consider multi-card Person layout for DH separation
6. Update build script path
7. Add source XML/PDF to source/ directory
