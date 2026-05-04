## v1.0 Review — 2026-04-21

Ran the ConnectCIC toolchain (`validate.ps1`, `test_layout.ps1`, `test_commsys.ps1`) against `TX_TLETS.json`. Full report in `docs/REVIEW_v1.0.md`.

**Validator**: 60 PASS / 0 FAIL / 1 WARN
**Layout tree**: 5 errors (all CAD_DISPATCH)

---

### CRITICAL — Fix Before Import

**1. CAD_DISPATCH layout: ROW_0 parent mismatch (all 5 entities)**
`ROW_0.parent` = `"ROOT_CARD"` — should be `"CONTEXT_INFO_CARD"`.
CONTEXT_INFO_CARD.nodes correctly lists ROW_0, but the child doesn't point back.
Breaks parent/child tree integrity. Platform may reject or misrender the CAD form.

**Fix**: In all 5 CAD_DISPATCH layouts, change `ROW_0.parent` from `"ROOT_CARD"` to `"CONTEXT_INFO_CARD"`.

---

### HIGH — Will Cause Runtime Issues

**2. RMS bundle incomplete — missing QRDM + ResultsLayout**
RMS bundle has only 2 configs (AUTH + QMF). Missing:
- `QUERYRESULTDATAMAPPING` (RMS_Results)
- `QUERYRESULTSLAYOUT` (RMS_ResultsLayout)

Without these, RMS queries fire but results won't display. Copy from HIDLE.json template.

**3. SexCode config mismatch — form vs RMS QIDM**
- Form: `codeTypeSource: "NCIC"`, `codeTypeCategory: "SEX"` → stores display string ("M"/"F"/"U")
- RMS QIDM: `useAttributeId: true`, `targetField: "sexAttrId"` → expects numeric attribute ID

This is a type mismatch. RMS will receive `sexAttrId: "M"` instead of a numeric ID.

**Options** (see KB `SEX_CODE_PATTERN.txt`):
- a) Use `attributeTypeId: "SEX"` on form + `codeTypeProvider: "NIBRS"` on CommSys QIDM attr (if TX instance supports reverse-lookup)
- b) Keep current form config, remove sex from RMS QIDM entirely (CommSys-only)

---

### MEDIUM

**4. No FIRST_RESPONDER layout variant**
All 5 entities have only `default` + `CAD_DISPATCH`. Platform typically expects a third variant.
FIRST_RESPONDER = CAD_DISPATCH + LinkToEvent checkbox.

**5. Person single-card, no DH separation**
DLQ and DHQ share all field IDs (no DH-suffix like `NameFirstDH`). `autoSelect`/`queriesToDeselect` handles mutual exclusion, but the operator can't tell which fields belong to which query path.
Consider multi-card layout with DH-suffix fields (see FL_FCIC v2.2 pattern).

**6. MessageKey sourceField not on form (validator WARN)**
DLQ has attribute `MessageKey` with `sourceField="MessageKey"` but there's no form field for it. May be auto-generated from combo selection — test on import.

---

### LOW

**7. Build script hardcoded path**
`scripts/build_tx_tlets.ps1` line 19: `$DIR = "C:\Users\Gordon Hallof\TX_TLETS"` — needs updating.

**8. Project validator is limited**
`scripts/validate_tx_tlets.ps1` misses encoding/BOM, layout tree, autoSelect conflicts, ruleHandlers format checks. Use the universal `validate.ps1` from `ConnectCIC-KB/scripts/` as primary validator.

---

### Tools Used

All available in [ConnectCIC-KB/scripts/](https://github.com/Robsgam/ConnectCIC-KB):
- `validate.ps1` — 6-phase validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combo simulation)
- `test_layout.ps1` — Craft.js node tree validator + HTML form preview
- `test_commsys.ps1` — CommSys query simulator (form data → combo matching → XML)

```powershell
powershell -ExecutionPolicy Bypass -File validate.ps1 -Path TX_TLETS.json
powershell -ExecutionPolicy Bypass -File test_layout.ps1 -Path TX_TLETS.json
powershell -ExecutionPolicy Bypass -File test_commsys.ps1 -Path TX_TLETS.json
```
