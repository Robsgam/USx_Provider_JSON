# USx Provider JSON - Consolidated Monorepo

All ConnectCIC provider JSON configurations, knowledge base, and shared tools in a single repo. All new provider projects go here using the same file and build structure as existing providers.

Owner: rob.sgambellone@mark43.com
Consolidated: 2026-05-04

## Repo Structure

```
providers/{PROVIDER}/     -- 8 provider builds (NJ, AZ, FL, HI, LA, NY, TX, CA)
knowledge-base/           -- Build rules, anti-patterns, platform limitations
tools/                     -- Shared scripts (validator, renderers, simulators)
templates/                 -- HIDLE.json, CA_ESUN.json, CODETYPE_TEST.json
```

## Provider Status (updated 2026-05-06)

| Provider | Path | Version | Status | Use as reference for |
|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS/ | v2.3 | 67P/0F/5W/1LIM (BASE camelCase) 0W/1LIM (MC) | queriesToDeselect VehReg/Stolen, RandomRequest, NCIC state, Patch 1+3+6+7+8 |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v1.1 | 64P/0F/1W/4LIM import PENDING | 6-transaction build, VehicleTypeCode, ImageIndicator in all Vehicle any[] |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v1.1 | 71P/0F/0W/5LIM import PENDING | DL+DH co-fire, DH-suffix, WINQ/MINQ, State no-default (LIMIT #30) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v2.0 | 69P/0F/0W/4LIM import PENDING | dexStateUserId, DH-suffix, WMPI queries, hidden badge |
| FL_FCIC | providers/FL_FCIC/ | v3.0 | 100P/0F/1W/4LIM 21+60 PASS import PENDING | DL+DH shared form, 6-card Person, QB routing (FL-8) |
| TX_TLETS | providers/TX_TLETS/ | v2.1 | 73P/0F/13W/3LIM import PENDING | TX-specific queries (DPSI/REG/VIN+FRT), EmailAddress QIDM-only pattern |
| LA_LETTS_OFML | providers/LA_LETTS_OFML/ | v2.0 | 48P/0F/32W/4LIM import PENDING | Attention handler (AP #27), DP/DQ routing toggle, State in set[] |
| CA_CLETS | providers/CA_CLETS/ | v1.5 | 64P/0F/0W/5LIM (BASE) 68P/0F/0W/7LIM (MC) import PENDING | CaRequestPurposeCode, LIMITATION #30, 2-QIDM co-fire (DL+DH), MC cross-entity, no ImageIndicator, 6 basic queries, yyyyMMdd dates |

## Legacy Repos (READ-ONLY)

Individual repos are preserved for history but are now read-only. All active work happens here.

- [NJ_NJCIS_JSON](https://github.com/LooseConnection/NJ_NJCIS_JSON) (LooseConnection)
- [HI_HCJDC_OFML](https://github.com/Robsgam/HI_HCJDC_OFML) (Robsgam)
- [NY_NYSPIN_EJUSTICE](https://github.com/Robsgam/NY_NYSPIN_EJUSTICE) (Robsgam)
- [AZ_AZDPS](https://github.com/Robsgam/AZ_AZDPS) (Robsgam)
- [FL_FCIC_JSON](https://github.com/LooseConnection/FL_FCIC_JSON) (LooseConnection)
- [TX_TLETS_JSON](https://github.com/LooseConnection/TX_TLETS_JSON) (LooseConnection)
- [LA_LETTS_OFML](https://github.com/LooseConnection/LA_LETTS_OFML) (LooseConnection)
- [ConnectCIC-KB](https://github.com/Robsgam/ConnectCIC-KB) (Robsgam)

---

## Build Phase Model — NEVER SKIP PHASES

**Phase 1 — STANDUP**: Single entity, single card per QIF. ALL fields on one card. Confirm every query path and QIDM combination before touching layout. Save `<PROVIDER>_BASE.json` when done.

**Phase 2 — MULTI-CARD**: One card per search path. QIDM does not change. Layout only. Retest affected entities.

**Phase 3 — SPLIT ENTITY**: Only if multi-card reveals a state model conflict that cannot coexist in one QIF. Most providers never need Phase 3 if NCIC state pattern works.

**Why this order**: NJ and NY both introduced layout complexity before confirming QIDM paths. When tests failed it was impossible to tell if the failure was the QIDM, the layout, or the state model. Phase 1 single-card eliminates layout as a variable.

---

## 3-Bundle Structure

Every provider JSON has exactly 3 bundles in this order:

1. **ENTITIES** (`provider='MARK43'`): All QIFs (entity input forms) + display order
2. **PROVIDER** (`provider=[PROVIDER_NAME]`): AUTH, QMF, QRDM, all QIDMs
3. **RMS** (`provider='RMS'`): Cloned from HIDLE.json, patched per provider

**ENTITIES must be first.** Confirmed AZ v2.0: forms do not render when ENTITIES is not first.

**QUERYINPUTFORM belongs ONLY in the ENTITIES bundle.** Adding it to any other bundle causes duplicate entity form cards.

---

## Anti-Patterns — CONFIRMED BROKEN, DO NOT ATTEMPT

### AP #1: attributeTypeId='STATE' in a QIDM sourceField
Platform serializes the numeric attribute ID (e.g. 69509884952) instead of the 2-letter state code. Use InpH (hidden FormInput) with initialValue='NY' for outbound XML. Keep SelH with attributeTypeId=STATE only for RMS.

### AP #2: attributeTypeId='SEX' WITHOUT codeTypeProvider='NIBRS'
Form stores numeric attribute ID; QIDM without codeTypeProvider writes raw ID to XML. Must have codeTypeProvider='NIBRS' on BOTH the form field AND the QIDM SexCode attribute.

### AP #3: attributeTypeId='RACE' on outbound XML fields
Same numeric ID issue. Use codeTypeCategory='NIBRS_RACE', codeTypeSource='NIBRS'.

### AP #4: IgnoreUserValueRuleHandler for state hardcoding
Passes raw sourceField value through unchanged. Does NOT substitute argument. DEAD END. Use InpH with initialValue.

### AP #5: Duplicate keyReference in one QIDM
Import fails: "Duplicate key references found in query input data mapping." Every combination in a QIDM must have a distinct keyReference.

### AP #9: QUERYINPUTFORM in RMS bundle
Causes each entity form card to render twice. QIF belongs ONLY in ENTITIES bundle.

### AP #11: useAttributeId=True with codeTypeCategory fields in RMS QIDM
Does NOT convert NIBRS codes to attribute IDs. RMS receives "M" and returns 400.

### AP #12: Split QIDM configs without checking LIMITATION #2
Platform picks ONE QIDM per (targetEntity, query) pair. The second is silently ignored. Always check before splitting.

### AP #14: queriesToDeselect on shared form without DH-suffix fieldIds
When both QIDMs reference the same fieldId in set[], mutual deselect deadlocks. Always pair with DH-suffix fieldIds.

### AP #15: FormatStringRuleHandler argument count mismatch
Arguments count must equal sourceField count minus 1. 2 fields = 1 arg. 4 fields = 3 args.

### AP #16: Assuming separate QIF sub-forms isolate QIDM evaluation
Platform uses a SHARED field-value pool for ALL Person QIDMs regardless of active sub-form.

### AP #18: Removing RMS sex without also removing SexCodeOOS
HIDLE has BOTH 'SexCode' and 'SexCodeOOS' sex attrs. Filter by targetField='sexAttrId' to remove both. Also remove both from combination any[]/set[] arrays.

### AP #21-23: Build Script Type Errors
- **AP #21**: `templateColumns` MUST be array of strings (`["6","6"]`), not integers
- **AP #22**: `maxLength` MUST be a string (`"20"`), not a number
- **AP #23**: `autoSelect` MUST be boolean (`true`), not string
- Use `keyReference` (NOT `keyRef`) on QIDM combinations — wrong property name causes silent null
- Use `rule: { function: "HandlerName" }` (NOT `ruleHandlers: [{name:...}]`)

### AP #24: Using NCIC_FIREARM_MAKE for Vehicle Make
NCIC_FIREARM_MAKE contains firearm manufacturers only, NOT vehicle makes. No `NCIC_VEHICLE_MAKE` category exists. HIDLE.json incorrectly maps VehicleMakeName to NCIC_FIREARM_MAKE in result QIDM. Use `attributeTypeId='VEHICLE_MAKE'` for dropdown (works for RMS, does NOT serialize to XML). Confirmed 2026-04-24 on MK43RS.

### AP #25: Wrong queryLabel values
Do NOT use entity names ("Vehicle", "Person"), system names ("NCIC"), or append "Query". Use the standard labels: Vehicle Registration, Driver License, Driver History, Firearm, Article, Boat, RMS. See FIELD_REFERENCE.txt Section 12.

### AP #26: Card title with non-ASCII characters (em dash, smart quotes)
Platform renders multi-byte UTF-8 as mojibake in card titles. Em dash "—" becomes "â€"". Use ASCII hyphen-minus (U+002D) only. Confirmed 2026-04-24 on NY MC.

### AP #27: Phantom field reference in RMS QIDM combo set[]/any[]
RMS QIDM combo references a field name with no matching attribute definition in the same QIDM. Import error: "Missing attributes found in query input data mapping: [fieldname]". Common cause: copying CommSys combo field lists to RMS combos without verifying each has an RMS attribute. LicensePlateYear has no RMS equivalent — remove from RMS combos. Confirmed: LA_LETTS_OFML v1.0 (2026-04-29).

### Attention field pattern (not numbered — reference builds only)
Do NOT add a visible Attention FormInput. Do NOT put Attention in `set[]`. Platform auto-fills implicitly but this is unreliable. Use `CommsysGetLastNameFirstNameInitialRuleHandler` on the Attention QIDM attribute instead (CA_eSUN, LA_LETTS_OFML pattern).

---

## Platform Limitations — Key Behaviors

### LIMITATION #1: set[]/any[] control combo selection, not field sending
When a combo fires, ALL populated QIDM attributes are sent. set/any cannot suppress which attributes serialize. Servers are tolerant of extra fields.

### LIMITATION #2: ONE QIDM per (targetEntity, query) pair
Multiple QIDMs sharing the same targetEntity+query — only one is evaluated. The others are silently ignored regardless of autoSelect setting.

**Merge decision**: Can merge when all keyRefs are distinct. Cannot merge when keyRefs duplicate (use invented distinct keyRef — see QIDM section).

### LIMITATION #3: First matching combination fires
Put most-specific combination first in the array.

### LIMITATION #4: attributeTypeId='STATE' sends numeric attribute ID
Only use on hidden SelH for RMS. Never map in QIDM for outbound XML.

### LIMITATION #12: No conditional field visibility
`hidden` is static true/false only. Cannot show/hide based on user input. Workaround: all fields visible; QIDM set/any handles routing.

### LIMITATION #21: Duplicate keyReference rejected at import
Each combination within a QIDM must have a distinct keyReference. keyRef is platform-internal only — provider does not validate it. Invented keyRefs work.

### LIMITATION #24-25: DL+DH shared form — autoSelect + DH-suffix fieldIds
When DL and DH share a form: autoSelect=true + queriesToDeselect + DH-suffix fieldIds (NameFirstDH, OperatorLicenseNumberDH, etc.). Both parts required.

### LIMITATION #26: Shared field pool across Person QIDMs
Platform evaluates ALL Person QIDMs from one shared field-value pool regardless of active sub-form. queriesToDeselect is ineffective in both directions.

### LIMITATION #27: No AttributeArrayWrapperRuleHandler on RMS sex
Wraps sexAttrId in array → RMS 400. HIDLE default (useAttributeId=true, no handler) is correct.

---

## Field Configuration Rules

### Code Type Pairings (confirmed working)

| codeTypeCategory | codeTypeSource | Notes |
|---|---|---|
| NCIC_LICENSE_PLATE_TYPE | NCIC | Baseline |
| NCIC_FIREARM_TYPE | NCIC | Baseline |
| NCIC_FIREARM_MAKE | NCIC | FIREARM makes only. NOT vehicle makes (AP #24) |
| NCIC_FIREARM_CALIBER | NCIC | FormInput also valid |
| NCIC_ARTICLE_TYPE | **CA_CLETS** | NCIC gives empty dropdown |
| YES_NO_UNKNOWN | **NCIC** | Y/N only. NIBRS adds Unknown (3 options) |
| NIBRS_SEX | NIBRS | DO NOT use attributeTypeId=SEX (see Sex Code section) |
| NIBRS_RACE | NIBRS | DO NOT use attributeTypeId=RACE. NCIC = empty dropdown |
| NJ_NIBRS_STATE | NJ_NIBRS | For OOS state dropdowns |
| VEHICLE_BODY_STYLE | Provider-specific | NJ=NJ_NIBRS, CA=VEHICLE. NCIC = empty |

### State Field — NCIC Pattern (preferred)

Single visible Sel 'RegistrationState': `attributeTypeId='STATE'`, `initialValue='<state>'`.
CommSys QIDM State attr: `sourceField=['RegistrationState']`, `targetField='State'`, `codeTypeProvider='NCIC'`.
RMS: HIDLE default (`useAttributeId=true` + `AttributeArrayWrapperRuleHandler`).

One field handles both CommSys (2-letter code via reverse-lookup) and RMS (dynamic attr ID).

**CONFIRMED**: NJ, AZ, NY. **UNCONFIRMED**: FL — test ST-1 on first import.

**CAUTION**: Do NOT set `initialValue` on State when the provider has separate in-state vs OOS keyRefs (e.g., NY: RCAR vs RVIN). The default causes OOS combos to fire instead of in-state, changing the documented query type. Use card title hints ("Leave blank for NY queries") instead. OK to set initialValue when provider has no separate in-state keyRefs (e.g., NJ). See LIMITATION #30.

Fallback (when NCIC not supported): dual-field pattern — SelH for RMS + InpH for XML. See `knowledge-base/BUILD_RULES.txt` Section 7.

### State Field — Combination any[]
Use the form fieldId `'RegistrationState'` in any[] — NOT the attribute name `'State'`.

### Date Fields
FormDate sends ISO yyyy-MM-dd. QIDM attribute: `rule=CommsysParseDateRuleHandler`, `arguments=['yyyy-MM-dd','MMddyyyy']`.

### Name (composite)
Separate FormInput fields: NameFirst, NameLast, NameMiddle, NameSuffix.
QIDM: `rule=FormatStringRuleHandler`, sourceField=all name fields, targetField='Name'.
`arguments` count = sourceField count minus 1 (2 fields → 1 arg, 4 fields → 3 args).
Check provider MetaData to confirm which Name fields are accepted.

### LicensePlateNumber
In-state: `fieldId='licensePlateNumber'`. OOS: `fieldId='LicensePlateNumberOut'`.
Generic 'LicensePlateNumber' does NOT trigger RMS plate search.
QIDM `targetField` remains 'LicensePlateNumber'.

### ImageIndicator
Three requirements (all must be met): QIDM attribute `size=1`, FormSelect `initialValue='Y'` (or 'N' for vehicle), field listed in set[] or any[].

---

## Sex Code Configuration

This is the most complex field. Follow exactly.

### Working Pattern (CommSys + RMS simultaneously)

**Form field:**
```json
{
  "type": { "resolvedName": "FormSelect" },
  "props": {
    "fieldId": "SexCode",
    "label": "Sex",
    "attributeTypeId": "SEX",
    "codeTypeProvider": "NIBRS"
  }
}
```

**CommSys QIDM SexCode attribute:**
```json
{
  "name": "SexCode",
  "size": 1,
  "sourceField": ["SexCode"],
  "targetField": "SexCode",
  "codeTypeProvider": "NIBRS"
}
```

**RMS QIDM sex attribute (HIDLE default — do NOT modify):**
```json
{
  "name": "sex",
  "sourceField": ["SexCode"],
  "targetField": "sexAttrId",
  "useAttributeId": true
}
```

Result: CommSys gets `<SexCode>M</SexCode>`, RMS gets `sexAttrId:"69509891711"` (string).

### Critical Rules

1. **NO AttributeArrayWrapperRuleHandler** on RMS sex attribute — causes array wrapping → RMS 400.
2. **NO codeTypeCategory=NIBRS_SEX** on form when RMS sex filter is needed — stores string "M", useAttributeId + string → array error.
3. **NO duplicate targetField** in any QIDM using codeTypeProvider — two attrs mapping to same targetField breaks reverse-lookup. Entity-split designs create duplicates and are INCOMPATIBLE.
4. Reverse-lookup (codeTypeProvider=NIBRS) works on ALL tested instances (NJ, AZ, FL). Prior "FL doesn't support reverse-lookup" was wrong — the failure was duplicate targetFields.

### Fallback (CommSys-only)
When duplicate targetFields are unavoidable (entity-split design):
- Form: `codeTypeCategory='NIBRS_SEX'`, `codeTypeSource='NIBRS'`
- CommSys QIDM: keep `codeTypeProvider='NIBRS'`
- RMS: REMOVE sex attribute and SexCode/SexCodeOOS from all combination arrays

Preferred: merge to single-entity design to use full pattern.

---

## QIDM Architecture

### queryLabel Standard

Every QIDM must have a `queryLabel` property. Use these standard values:

| Query | queryLabel |
|---|---|
| VehicleRegistrationQuery | Vehicle Registration |
| VehicleStolenQuery | Vehicle Stolen |
| DriverLicenseQuery | Driver License |
| DriverHistoryQuery | Driver History |
| GunQuery | Firearm |
| ArticleSingleQuery | Article |
| BoatQuery | Boat |
| WMPIPersonWINQQuery | Wanted Person |
| WMPIPersonMINQQuery | Missing Person |
| CAISupervisedReleaseQuery | Supervised Release |
| RMS (all) | RMS |

Label by what the officer is searching for, not by backend system name. Do not use entity names ("Person"), system names ("NCIC", "DMV"), or append "Query".

### Combination Format
```json
{
  "requirements": { "set": [...], "any": [...] },
  "primaryFieldReference": "<attribute name>",
  "keyReference": "<unique key>",
  "state": "In/Out"
}
```

- `keyReference` not `keyRef` — wrong property name causes silent null, then import rejection
- `primaryFieldReference` uses the QIDM attribute name (e.g. 'Name'), not sourceField
- `state` is required on CommSys QIDMs
- No `name` property on combinations

### Merge vs Split Decision

1. Is another QIDM targeting the same (targetEntity, query)? If no → safe to create separate QIDM.
2. Can you merge? All keyRefs distinct across both → merge into one QIDM.
3. Duplicate keyRefs? → (a) Check for separate MetaData transaction. (b) Invent a distinct keyRef (DALL + DALH). Provider routes by field content, not keyRef. (c) DH-suffix fieldIds. (d) Only after a–c fail: declare not implementable.

**keyRef is platform-internal only.** Provider does not validate it. Invented keyRefs work. Confirmed: NY v1.19.

### DL + DH on Same Form (Scenario A — FL pattern)
- autoSelect=true + queriesToDeselect on each QIDM
- DH-suffix fieldIds: NameFirstDH, NameLastDH, BirthDateDH, SexCodeDH, OperatorLicenseNumberDH
- DH QIDM references only DH-suffixed names in set[]/sourceField

### DL + DH on Separate Forms (Scenario B — NY pattern)
- Shared field pool makes queriesToDeselect ineffective
- DH co-fires with DL on OLN entry = correct police workflow
- For true isolation: DH-suffix fieldIds on DH form

### Combination Ordering
Most-specific (most set[] fields) first. Less-specific last.

---

## RMS Bundle — Standard Patches (REQUIRED, not in HIDLE)

Apply all patches in every build script after cloning RMS from HIDLE.json.

**Patch 1 — Vehicle plate + state**: Add 'RegistrationState' to RMS Vehicle `licensePlateIn` combination any[].

**Patch 2 — Vehicle OOS cleanup**: Drop 'RegistrationStateOut' from `licensePlateOutAndState` set[] (or keep if OOS forms use LicensePlateNumberOut).

**Patch 3 — Person state**: Add `registrationState` attribute to RMS Person QIDM: `sourceField=['RegistrationState']`, `targetField='registrationStateAttrId'`, `useAttributeId=true`. Add 'RegistrationState' to ALL person combination any[]. Note: Person uses singular `registrationStateAttrId` (string, NO ArrayWrapper). Vehicle uses plural `registrationStateAttrIds` (array, WITH ArrayWrapper).

**Patch 6 — RMS cleanup (ALWAYS apply after all other patches)**: Remove unused HIDLE fields that have no matching form fieldId. Vehicle: remove `LicensePlateNumberOut`, `RegistrationStateOut`, `OwnerFirstName`, `OwnerLastName` attrs + `licensePlateOutAndState`, `OwnerFirstAndLastName` combos + clean any[] refs. Person: remove `socialSecurityNumber` + all OOS-suffixed attrs (`licenseNumberOOS`, `firstNameOOS`, `lastNameOOS`, `dateOfBirthOOS`, `sexOOS`) + SSN combo + all OOS combos. See `BUILD_RULES.txt` Section 4 Patch 6 for full list. Exception: keep OOS attrs if the provider uses DH-suffix fieldIds (e.g., FL_FCIC).

---

## Rule Handler Reference (source: HandlerConfiguration.java)

Full reference: `knowledge-base/RULE_HANDLERS.txt` (24 handlers documented).

**Directly configured in provider JSON (6 handlers):**

| Handler | Used in | Signature |
|---|---|---|
| CommsysOriAuthenticationHandler | AUTH handlerFunction | — |
| CommsysTransactionRequestHandler | QIDM handlerFunction (every QIDM) | — |
| CommsysWsiOutgoingMessageHandler | QMF handlerFunction | — |
| CommsysGetDexStateUserIdRuleHandler | AUTH UserName attr | arguments=['true'] |
| CommsysParseDateRuleHandler | QIDM BirthDate attr | arguments=['yyyy-MM-dd','<provider-fmt>'] |
| FormatStringRuleHandler | QIDM Name attr | arguments=separators (count = fields - 1) |

**Inherited from HIDLE (do NOT manually configure):**

| Handler | Where | Note |
|---|---|---|
| CommsysResultsHandler | QRDM | Response parsing |
| RmsRestResultsHandler | RMS bundle | Response parsing |
| RmsRestPayloadHandler | RMS bundle | Request building |
| AttributeArrayWrapperRuleHandler | RMS Vehicle registrationStateAttrIds | Do NOT add to sex attrs |

**Dead ends / not used:**

| Handler | Status |
|---|---|
| IgnoreUserValueRuleHandler | DEAD END — does not substitute argument |
| All Parse*/Format{Array,Name}/Height*/Regex*/Article* handlers | Response-side only (QRDM) |

---

## Entity Display Order

ENTITIES bundle `order` array must use targetEntity values:
```json
{
  "default":         ["Person","Vehicle","Firearm","Article","Boat"],
  "CAD_DISPATCH":    ["Vehicle","Person","Firearm","Article","Boat"],
  "FIRST_RESPONDER": ["Vehicle","Person","Firearm","Article","Boat"]
}
```

Entity names, config names, and labels do NOT work. Check NJ reference first before any order fix.

---

## Layout Structure (Craft.js Node Tree)

```
ROOT → FORM_ROOT (Form, hidePageItems=true, layout='page')
     → ROOT_PAGE (Page, title='Page 1')
     → CARD_xxx (Card, optional title)
        → ROW_xxx (Row, templateColumns=['6','6'])
           → FIELD_xxx (FormInput / FormSelect / FormDate / FormCheckbox)
```

Three layout variants per QIF: `default`, `CAD_DISPATCH`, `FIRST_RESPONDER`.

**CAD_DISPATCH**: Prepend CONTEXT_INFO_CARD with CadUnit_Input + CadEvent_Input before entity cards. ROW_0.parent MUST point to 'CONTEXT_INFO_CARD' (not ROOT_CARD).

**FIRST_RESPONDER**: Same as CAD_DISPATCH (+ optional LinkToEvent checkbox). Whether platform renders FIRST_RESPONDER distinctly is unconfirmed. Include in all builds.

**templateColumns**: Array of strings. `['12']` = full width. `['6','6']` = two columns. `['4','4','4']` = three columns.

---

## Tools — Run Before Every Import

All shared tools are in `tools/`. Provider-agnostic.

```powershell
# 6-phase validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos)
powershell -ExecutionPolicy Bypass -File tools/validate.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json

# Layout tree validator + HTML form preview
powershell -ExecutionPolicy Bypass -File tools/test_layout.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json

# CommSys query simulator (form data -> combo matching -> XML output)
powershell -ExecutionPolicy Bypass -File tools/test_commsys.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json

# Full build report (runs all 6: validator + layout + query sim + picklist + HTML + verify)
powershell -ExecutionPolicy Bypass -File tools/build_report.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json

# Post-build verification (banned_patterns.txt, fieldId consistency, reference patterns)
# Called automatically by build_report.ps1 as step 6. Can also run standalone:
powershell -ExecutionPolicy Bypass -File tools/verify_build.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json
powershell -ExecutionPolicy Bypass -File tools/verify_build.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json -CamelCase
```

Validator must pass clean (0 FAIL) before import. Verify must pass clean (0 FAIL). Fix all failures before proceeding.

---

## Import Error Quick Reference

| Error | Root Cause | Fix |
|---|---|---|
| "Duplicate key references" | Two combos share keyReference in one QIDM | Use distinct keyRefs |
| Duplicate entity form cards | QIF in wrong bundle | Move QIF to ENTITIES bundle only |
| State sends numeric ID | attributeTypeId='STATE' in QIDM | Use InpH with initialValue |
| RMS 400 on sex | sexAttrId with useAttributeId on NIBRS_SEX field | Remove sex from RMS QIDM |
| Query doesn't fire | LIMITATION #2 — second QIDM ignored | Merge QIDMs |
| Empty dropdown | Wrong codeTypeSource | Check FIELD_REFERENCE.txt Section 2 |
| "Missing attributes in query input data mapping" | RMS combo references field with no attribute | Remove orphan field from RMS combo (AP #27) |

---

## Versioning Policy

- **NEVER overwrite a tested JSON.** Save every iteration.
- Name format: `<PROVIDER>_v<X.Y>_<date>.json` or `<PROVIDER>_v<X.Y>.json`
- Document every JSON in `docs/JSON_INVENTORY.md`
- Keep all JSONs in project root
- `bump_version.ps1` archives current before rebuilding

---

## SESSION START PROTOCOL

At the start of every session that touches a provider JSON repo, before doing any work:

1. Read this CLAUDE.md fully (or confirm it was loaded in system context)
2. Read the provider's repo CLAUDE.md
3. Run `git status` on every repo you will touch — confirm clean and synced
4. Check `docs/` has: STATUS.txt, SQVR.txt, BUILD_NOTES.txt, base/ reports
5. Check `tests/` exists
6. If ANYTHING from steps 3-5 is wrong, fix it FIRST before starting the requested task

This costs 2 minutes and prevents "I'll come back to it" drift.

---

## TRIGGER RULES — AUTOMATIC CHAINING

These are cause-and-effect rules. When the trigger happens, the actions are MANDATORY — not "remember to also do" but "you are not done until these are also done."

**TRIGGER: You edit or create any `.json` provider file**
- Run build_report.ps1
- Commit JSON + all 6 report files
- Push to GitHub
- Update docs/STATUS.txt if version changed
- Update docs/SQVR.txt if query paths changed

**TRIGGER: You complete a live test (user reports PASS or FAIL)**
- Fill in the test log stub (FORM STATE, XML, FIELD ANALYSIS, RESULT)
- Commit and push the completed log
- Update docs/STATUS.txt test matrix row
- Update docs/SQVR.txt — flip [PENDING] to [CONFIRMED] if PASS

**TRIGGER: You update any KB file (knowledge-base/, CLAUDE.md)**
- Commit and push the monorepo
- Check: does this change affect CLAUDE.md or any build script? If yes, update those too
- Check: does this change affect any build script? If yes, propagate

**TRIGGER: You discover a new limitation, anti-pattern, or import error**
- Add to the appropriate KB file (PLATFORM_CONSTRAINTS.txt, IMPORT_ERRORS.txt)
- Fire the KB update trigger above

**TRIGGER: You are about to end your response**
- Run the END-OF-RESPONSE VERIFICATION below

---

## END-OF-RESPONSE VERIFICATION

Before ending ANY response that involved file changes, run this checklist mentally and fix anything that fails. Do not output the checklist to the user — just do the work silently. Only mention it if something was missing and you fixed it.

1. Every file I edited — is it saved, committed, and pushed?
2. Every JSON I touched — did build_report.ps1 run? Are reports committed?
3. Every test completed — is there a log file in tests/? Is it committed?
4. STATUS.txt — does it reflect the current state?
5. SQVR — does it reflect the current confirmed/pending state?
6. Did I update anything in the KB? If yes, is the KB pushed? Are affected repos updated?
7. Is there anything I said I would do but haven't done yet?

If #7 is yes: do it now, or explicitly tell the user it's deferred and why.

---

## GAP ANALYSIS — EVERY STEP, NOT JUST THE END

Run an explicit gap check after EVERY action. Do not wait until end of batch, end of testing, or until the user asks "are you sure."

**After presenting a test batch:** Cross-check every QIDM combo against the test list. Count combos, count tests — if they don't match, identify the gap before proceeding.

**After completing each test:** Update SQVR [PENDING] → [CONFIRMED] AND STATUS.txt test matrix immediately. GATE 3 includes doc updates, not just test logs.

**After completing a test phase:** Full cross-check: (a) count all combos from build script, (b) count all test log files, (c) count all [CONFIRMED] markers in SQVR, (d) verify all three numbers agree. Report the gap check result.

**Before declaring "done" or "complete":** Full gap check PLUS verify: negative tests for all entities, all any[] fields tested, all co-fire paths tested, all OOS paths tested.

The user should NEVER have to prompt for gap analysis. It is automatic.

---

## MANDATORY GATES — BLOCKING REQUIREMENTS

These are not suggestions. Each gate BLOCKS progression to the next step. Do not skip, defer, or batch any gate. Failure to follow these gates means the work is incomplete regardless of whether the JSON "works."

### GATE 1: After Every JSON Build or Edit

1. Run `build_report.ps1 -Path <json>` (validator + layout + query sim + picklist + HTML)
2. Verify 0 FAIL in validator output
3. Commit the JSON + all 6 report files to `docs/base/` or `docs/mc/`
4. `git push` immediately
5. **CANNOT proceed to import or testing until reports are committed and pushed**

### GATE 2: Before Each Live Test

1. Run `new_test_log.ps1` to create a stub log file in `tests/`
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\new_test_log.ps1 `
     -Provider <NAME> -Variant BASE -Version <ver> -Entity <entity> -Combo <combo> -Description "<desc>"
   ```
2. Have the user open browser dev tools (F12 > Network) before submitting the query
3. **CANNOT execute the test without a stub log file created on disk**

### GATE 3: After Each Live Test

1. Paste raw XML request from browser dev tools into the log file
2. Fill in FORM STATE, REQUEST SUMMARY, FIELD ANALYSIS, and RESULT sections
3. `git add` + `git commit` + `git push` the completed log file
4. **CANNOT proceed to the next test until the current log is committed and pushed**

### GATE 4: After Each Test Session

1. Update `docs/<PROVIDER>_STATUS.txt` test matrix with all results from this session
2. Commit and push STATUS.txt
3. **CANNOT report a test session as complete without updated STATUS.txt**

### GATE 5: Before Reporting PASS or DONE on Any Variant

1. Verify `tests/` directory contains one log file per test executed (count must match)
2. Verify `docs/base/` (and `docs/mc/` if applicable) contains all 6 report files
3. Verify `docs/<PROVIDER>_STATUS.txt` is current
4. Verify `docs/<PROVIDER>_SQVR.txt` exists with [CONFIRMED]/[PENDING] per query path
5. Verify all files are committed and pushed to GitHub
6. **CANNOT declare PASS or DONE until all 5 checks pass. If any are missing, create them first.**

### GATE 6: After Any KB Update

1. Commit and push the monorepo
2. Check if the KB change affects CLAUDE.md or build scripts
3. If yes: update affected files and commit
4. **CANNOT finish a KB update without checking cross-file impact**

---

## Operational Rules

1. **Investigate all solutions before declaring not implementable.** Check: (a) multi-combo QIDM with distinct keyRefs, (b) separate MetaData transaction, (c) DH-suffix fieldIds, (d) reference builds. Only declare blocked after all four fail.

2. **Apply autonomous design decisions without prompting:**
   - Phase 1 = always single card
   - 2+ search paths = multi-card automatically (Phase 2)
   - DH on same form as DL = DH-suffix fieldIds automatically
   - Duplicate MetaData keyRefs = invented distinct keyRef first
   - queriesToDeselect on DL QIDMs = NEVER (deadlocks)
   - Most-specific combination first in array

3. **Validate after every build.** Run `validate.ps1` after every build script execution. Build script serializers (C#/PowerShell) silently produce wrong types.

4. **Test NCIC state pattern on first import** of any new provider. Run ST-1 (in-state plate query). If CommSys `<State>` element is absent, fall back to dual-field pattern.

5. **Pre-deployment validation is a deliverable, not a step.** When you run `validate.ps1`, `test_commsys.ps1`, or `build_report.ps1` — the output files ARE test results. They must be committed to `docs/base/` or `docs/mc/` and pushed. If the validator output is not in the repo, the validation didn't happen as far as the project record is concerned.

---

## Canonical Provider Structure

Every provider under `providers/` MUST have this structure. All new providers follow the same layout.

```
providers/<PROVIDER>/
├── <PROVIDER>_BASE.json                   # Current BASE JSON
├── <PROVIDER>_MC.json                     # Current MC JSON (if applicable)
├── <PROVIDER>_BASE_READABLE.json          # Pretty-printed BASE (for engineers)
├── <PROVIDER>_MC_READABLE.json            # Pretty-printed MC (if applicable)
├── docs/
│   ├── <PROVIDER>_STATUS.txt              # Live test matrix + current state
│   ├── <PROVIDER>_BUILD_NOTES.txt         # Change log with CHANGED/REASON per version
│   ├── <PROVIDER>_SQVR.txt                # Supported Query Validation Report
│   ├── JSON_INVENTORY.md                  # Every JSON version ever produced
│   ├── base/                              # BASE variant reports (6 files)
│   └── mc/                                # MC variant reports (if applicable)
├── tests/                                 # Per-test log files (one per test executed)
├── phases/                                # Version snapshots
│   ├── base/
│   └── mc/
├── scripts/                               # Provider-specific build scripts
│   ├── build_<provider>.ps1
│   └── build_<provider>_mc.ps1
├── source/                                # Input materials
│   ├── <provider>.xml                     # Metadata XML
│   └── <provider>.pdf                     # Devdoc PDF
    └── HIDLE.json                         # RMS template
```

When a repo does not match this structure, fix it before doing any other work.

---

## Quick Start — New Provider

1. Read `knowledge-base/README.txt` then this file
2. Create repo with canonical structure above
3. Copy `templates/HIDLE.json` to `source/`
4. Copy metadata XML and devdoc PDF to `source/`
5. Create build script in `scripts/`
6. Phase 1: single card, all entities, confirm all query paths
7. GATE 1 after every build (report + commit + push)
8. Create SQVR with [PENDING] markers for every query path
9. Phase 2: multi-card for entities with 2+ search paths
10. Phase 3: split entity only if needed (NCIC state pattern usually avoids this)
11. GATE 5 before declaring any variant DONE
