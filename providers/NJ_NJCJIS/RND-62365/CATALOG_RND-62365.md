# RND-62365 — NJ_NJCJIS Findings Catalog

_Catalogued 2026-06-26. Investigation only — no build changes made. Propagation to other providers
DEFERRED until NJ is fully characterized and fixed (per "characterize before propagate")._

---

## 1. Confirmed baseline

- **Newark currently runs the v3.5 PASCAL variant** ("from cringer reference"). The fresh
  `Newark Export.json` is **byte-identical** to the earlier `department-export-…(2).json`. This is the
  working revert target.
- It still carries the **original name-display bug** (`ParseCommsysName` empty args) — so reverting to
  fix vehicle/OnScene re-broke the name display. Newark is stuck between two bugs.
- The regression is **100% inside the v4.6 diff** (platform constant: live = revert target).

## 2. Instance code-type map (from CODETYPE_TEST_NJ.json probe)

Verified which code-type tables exist/populate on the imported instance. Pattern: `attributeType(Id)`
forms and the canonical category/source pairings populate; wrong-source variants are blank.

**Vehicle make/model verdicts:**
- ❌ `VehicleType` / `VEHICLE` (VM01) — **BLANK** (no such table)
- ✅ `VEHICLE_MAKE` / `NCIC` (VM02), `VEHICLE_MAKE` / `VEHICLE` (VM05)
- ✅ `attributeType=VEHICLE_MAKE` (VM03), `+ NCIC` (VM04) ← runbook
- ✅ `attributeType=VEHICLE_MODEL` (VM08), `+ NCIC` (VM06) ← what we ship for model
- ❌ `VEHICLE_MODEL` / `NCIC` category (VM07) — BLANK (model must use attributeType form)

## 3. Complete v4.6 codeType audit (result mapping + forms)

Every codeType usage in NJ_NJCJIS v4.6 cross-referenced against the probe map:

| Where | Attribute | Pairing | Verdict |
|---|---|---|---|
| QRDM Results | AddressStateCode | `NJ_NIBRS_STATE`/`NJ_NIBRS` | ✅ good |
| QRDM Results | RaceCode | `NIBRS_RACE`/`NIBRS` | ✅ good |
| QRDM Results | SexCode | `attrType=SEX`/`NIBRS` | ✅ good |
| QRDM Results | EyeColorCode | `attrType=EYE_COLOR`/`NCIC` | ✅ family exists |
| QRDM Results | HairColorCode | `attrType=HAIR_COLOR`/`NCIC` | ✅ family exists |
| QRDM Results | VehicleColorCode | `attrType=ITEM_COLOR`/`NCIC` | ✅ family exists |
| QRDM Results | VehicleStyleCode | `VEHICLE_BODY_STYLE`/`NJ_NIBRS` | ✅ good |
| QRDM Results | VehicleModelName | `attrType=VEHICLE_MODEL`/`NCIC` | ✅ good |
| **QRDM Results** | **VehicleMakeName** | **`VehicleType`/`VEHICLE`** | ❌ **BLANK — REGRESSION** |
| Form | All FormSelect dropdowns (State/Sex/Plate/Gun/Article/YesNo) | various | ✅ all good |

**Result: the ONLY codeType defect in NJ v4.6 is `VehicleMakeName`.** Everything else uses a pairing
the probe confirms exists.

## 4. Issue inventory

### ISSUE 1 — VehicleMakeName wrong/absent code source (FIXED in v4.7)
v4.6 used `codeTypeCategory='VehicleType'` + `codeTypeSource='VEHICLE'`. The CODETYPE_TEST probe proved
that table is **ABSENT on the Newark instance** (empty). On the vehicle result path this leaves the make
unresolved.
- **RETRACTION:** an earlier draft of this catalog said this attribute "throws." The Attribute Handle
  spec (handler #6 `CommsysResultAttributeMappingRuleHandler`) says it **returns null when the code is
  not found — it does not throw**. So whether the absent source produces a hard "Query execution failed"
  or just a blank make is **Newark-version-dependent**: Newark runs a pre-RND-54190 Federated Search, and
  the spec describes post-fix behavior. Throw-vs-blank is unconfirmed without the server log.
- **Why vehicle-specific & fits the screenshot:** the absent source is only hit when a vehicle RECORD with
  a make code is mapped. Person no-record responses have nothing to resolve → they pass (matches the
  screenshot: plate fails, persons return).
- **Source:** shared `tools/_build_rms_bundle.ps1` (`Build-CommsysQrdm`, VehicleMakeName block).
- **FIX (NJ v4.7, 2026-06-26):** `attributeType='VEHICLE_MAKE'` + `codeTypeSource='NCIC'`, removed
  `codeTypeCategory`. Probe-confirmed present (VM04); matches RND-54190 runbook + sibling VehicleModelName.
  NJ rebuilt only; other 4 live providers share the module but stay tabled (one at a time).
- **Verification pending:** SCOPE_MATRIX.md cell 3 on v4.7 (vehicle-with-record must now resolve).

### ISSUE 2 — Name-display fix (PRESENT & CORRECT, keep)
`ParseCommsysName` args populated for Name/NameLast/NameFirst/NameMiddle in NJ_NJCJIS_Results. This is
the RND-62365 fix; it is correct. Not a defect — it's what v4.6 adds.

### ISSUE 3 — OnScene (RECLASSIFIED: v4.6 already contains the fix; person-break unsubstantiated)
The **shared RMS bundle** (`RMS_Results`) went from empty-args to populated-args in v4.6 across ~11
attributes including `Name` (FormatNameRuleHandler). **These populated args ARE the RND-57208 OnScene
fix** — authored by ProServices (Rob) and **validated end-to-end in AutomatedQA CAD for person AND
vehicle** per the runbook. They are proven-good, not a suspect.
- **Evidence re-read (mock-error screenshot):** the failing query is **ABC123 (a plate → vehicle)**:
  `NJ_NJCJIS Query execution failed — "Mock results processed"`. The **person** queries in the same
  view (SMIITH JAMES; JAMES SMITH) **returned** (`NCIC (1)`). No person-OnScene failure is shown.
- **Correction:** earlier this was over-escalated as an unexplained open blocker. There is NO evidence
  in hand that person OnScene is broken. Leo's prose "OnScene doesn't work for person or vehicle" is
  most likely the vehicle failure (ISSUE 1) inside a mixed CAD batch, or conflation.
- **Action:** confirm with Leo whether person OnScene genuinely fails on v4.6 (vs the vehicle failure).
  Do NOT treat as a blocker. ISSUE 1 is very likely the entire regression.

### ISSUE 4 — VehicleMakeName fallback regex 'rule' path (LATENT dependency)
v4.6 activated `fallbackRule = ['regex:VMA/([^\s]+)','trim','rule']` (v3.5 was inert `[]`). The `'rule'`
re-run path depends on the RND-54190 **Federated Search lowercase-key deploy**. Even after fixing
ISSUE 1's codeType, if the fallback fires (composite VMA/ string in the response) and that deploy is
absent at Newark, it could still fail.
- **Decision needed:** confirm the Federated Search deploy at Newark, OR revert the fallback to inert
  until it is.

### ISSUE 5 — Missing AttrId attributes (ENHANCEMENT, not a query hard-fail)
RND-54190 requires `VehicleMakeAttrId`, `VehicleModelAttrId` (and `BodyStyleAttrId`) for RMS
Update-to-Profile make/model/body-style dropdowns. We emit none. Doesn't block the query; affects RMS
profile pre-fill completeness. Depends on RMS + Federated Search deploys.

## 5. What's NOT an issue (verified)
- Vehicle combos collapsed 4→2 (RQ_RAND/RQN_RAND removed): behavior-preserving (RAND conditions were
  already inert poisoned-arrays).
- Height/VehicleYear arg additions: standard handler-arg population, low risk.
- QMF and AUTHENTICATION: functionally identical to v3.5.

## 6. Path to v4.7
ISSUE 1 (VehicleMakeName codeType) is the confirmed regression and the fix is clear. ISSUE 3 is NOT a
blocker — v4.6 already carries the validated OnScene name fix. Remaining before/with the build:
- **Decide ISSUE 4** (fallback `rule` path): confirm the RND-54190 Federated Search deploy at Newark,
  or revert the fallback to inert to be safe.
- **Decide ISSUE 5** (AttrId attrs): include now or defer.
- **Optional confirmation:** ask Leo to confirm person OnScene actually works on v4.6 (expected: it
  does), so we're not chasing a phantom.

## 7. Blast radius (for later — NOT acting now)
ISSUE 1 + the RMS bundle changes come from the **shared** `_build_rms_bundle.ps1`, so they already
exist in CA_CLETS v2.9, FL v6.7, HI v4.5, TX_TLETS. Propagation handled only after NJ is fully fixed
and re-tested. Our test methodology validates the request side only (combo fire + XML), never result
mapping — which is why CA_CLETS passed 40/40 while carrying ISSUE 1. That testing gap is itself a
finding to address.
