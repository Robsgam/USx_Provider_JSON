# USx Provider JSON - Consolidated Monorepo

All ConnectCIC provider JSON configurations, knowledge base, and shared tools in a single repo. All new provider projects go here using the same file and build structure as existing providers.

Owner: rob.sgambellone@mark43.com
Consolidated: 2026-05-04

## Repo Structure

```
providers/{PROVIDER}/     -- 19 providers (8 active + 11 new)
knowledge-base/           -- Build rules, anti-patterns, platform limitations
tools/                     -- Shared scripts (validator, renderers, simulators)
templates/                 -- HIDLE.json, CA_ESUN.json, CODETYPE_TEST.json
```

## Provider Status (updated 2026-05-11)

| Provider | Path | Version | Status | Notable patterns |
|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS_LOCKED/ | v3.0 | 69P/0F/0W/1LIM LOCKED -- 14/14 PASS full combo coverage -- DEPLOYED Newark NJ foundation 2026-05-11 | conditions routing (RAND/FULL), autoSelect=false on Stolen, queriesToDeselect VehReg/Stolen, NCIC state, Patch 1+3+6+7+8 |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v1.3 | 70P/0F/0W/5LIM (BASE) 70P/0F/0W/5LIM (MC) NEW | 7-transaction build, VehicleStolenQuery, VehicleTypeCode, ImageIndicator in all Vehicle any[] |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v1.5 | 74P/0F/0W/1LIM (BASE) 74P/0F/0W/1LIM (MC) NEW | DL+DH DH-suffix+queriesToDeselect, WINQ/MINQ, State no-default (LIMIT #30) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v2.2 | 70P/0F/0W/4LIM (BASE) 70P/0F/0W/4LIM (MC) NEW | dexStateUserId, DH-suffix, WMPI queries, hidden badge |
| FL_FCIC | providers/FL_FCIC/ | v3.3 | 101P/0F/0W/4LIM (BASE) 101P/0F/0W/5LIM (MC) NEW | DL+DH shared form, 6-card Person, QB routing (FL-8) |
| TX_TLETS | providers/TX_TLETS/ | v2.5 | 83P/0F/0W/3LIM (BASE) 83P/0F/0W/3LIM (MC) NEW | DH-suffix+queriesToDeselect, TX-specific queries (DPSI/REG/VIN+FRT), VehicleStolenQuery, EmailAddress QIDM-only pattern |
| LA_LEMS | providers/LA_LEMS/ | v2.3 | 63P/0F/0W/1LIM (BASE) 63P/0F/0W/1LIM (MC) NEW | DH-suffix+queriesToDeselect, Attention handler (AP #27), DP/DQ routing toggle, State in set[] |
| CA_CLETS | providers/CA_CLETS/ | v1.6 | 64P/0F/0W/5LIM (BASE) 68P/0F/0W/7LIM (MC) NEW | CaRequestPurposeCode, LIMITATION #30, 2-QIDM co-fire (DL+DH), MC multi-card (18 cards), cross-entity (IN.VP/IG.QGH/NLTS.BQ.N), no ImageIndicator, 6 basic queries, yyyyMMdd dates |
| CA_VENTURA_COUNTY | providers/CA_VENTURA_COUNTY/ | v1.3 | 66P/0F/0W/6LIM (BASE) 70P/0F/0W/8LIM (MC) NEW | 6 basic queries, CaRequestPurposeCode (visible Inp), DL+DH co-fire, MC cross-entity (IN.VP/IG.QGH/NLTS.BQ.N) |
| CA_CONTRA_COSTA | providers/CA_CONTRA_COSTA/ | -- | FLAGGED -- no basic queries per devdoc | Only expanded JAWS queries; needs decision |
| CA_CLETS_OCATS | providers/CA_CLETS_OCATS/ | v1.1 | 63P/0F/0W/2LIM (BASE) 63P/0F/0W/2LIM (MC) NEW | CLETS_OCATS v21, 5 basic queries (no DH), VP owner search, 19 combos, OCATS-specific queries available (warrants, juvenile, LARS) |
| CA_eSUN | providers/CA_eSUN/ | v1.4 | 70P/0F/0W/5LIM (BASE) 70P/0F/0W/5LIM (MC) NEW | CaRequestPurposeCode (visible Inp), VP owner search, gun-by-name, Attention handler, MC multi-card (14 cards) |
| CA_SAN_LUIS_OBISPO | providers/CA_SAN_LUIS_OBISPO/ | v1.2 | 63P/0F/0W/4LIM (BASE) 63P/0F/0W/4LIM (MC) NEW | Regional interface, no CaRequestPurposeCode, short keyRefs, MC multi-card (13 cards) |
| IL_LEADS_OFML | providers/IL_LEADS_OFML/ | v1.1 | 61P/0F/0W/0LIM (BASE) 61P/0F/0W/0LIM (MC) NEW | 5 basic queries (no DH), Z2/Z5 keyRefs, MC multi-card (11 cards) |
| MD_METERS | providers/MD_METERS/ | v1.1 | 67P/0F/0W/6LIM (BASE) 67P/0F/0W/6LIM (MC) NEW | 6 basic queries, ZVEH/ZLRG/ZDRV invented keyRefs, MC multi-card (11 cards) |
| OH_LEADS | providers/OH_LEADS/ | v1.2 | 76P/0F/0W/4LIM (BASE) 76P/0F/0W/4LIM (MC) NEW | 6 basic queries, 9 VehReg combos, BMVIMS, owner search (RN), MC multi-card (14 cards) |
| NM_NMLETS_OFML | providers/NM_NMLETS_OFML/ | v1.2 | 64P/0F/0W/4LIM (BASE) 64P/0F/0W/4LIM (MC) NEW | 6 basic queries, GunModel field, MC multi-card (11 cards) |
| OR_LEDS | providers/OR_LEDS/ | v1.2 | 58P/0F/0W/1LIM (BASE) 58P/0F/0W/1LIM (MC) NEW | 5 basic queries (no DH), invented keyRefs, MC multi-card (11 cards) |
| TN_TIES | providers/TN_TIES/ | v1.3 | 79P/0F/0W/3LIM (BASE) 79P/0F/0W/3LIM (MC) NEW | 6 basic queries, 28 combos, no State initialValue, MC multi-card (14 cards), DH-suffix |

## Legacy Repos (READ-ONLY)

Individual repos are preserved for history but are now read-only. All active work happens here.

- [NJ_NJCIS_JSON](https://github.com/LooseConnection/NJ_NJCIS_JSON) (LooseConnection)
- [HI_HCJDC_OFML](https://github.com/Robsgam/HI_HCJDC_OFML) (Robsgam)
- [NY_NYSPIN_EJUSTICE](https://github.com/Robsgam/NY_NYSPIN_EJUSTICE) (Robsgam)
- [AZ_AZDPS](https://github.com/Robsgam/AZ_AZDPS) (Robsgam)
- [CA_CLETS](https://github.com/Robsgam/CA_CLETS) (Robsgam)
- [FL_FCIC_JSON](https://github.com/LooseConnection/FL_FCIC_JSON) (LooseConnection)
- [TX_TLETS_JSON](https://github.com/LooseConnection/TX_TLETS_JSON) (LooseConnection)
- [LA_LEMS (formerly LA_LETTS_OFML)](https://github.com/LooseConnection/LA_LETTS_OFML) (LooseConnection)
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
RMS QIDM combo references a field name with no matching attribute definition in the same QIDM. Import error: "Missing attributes found in query input data mapping: [fieldname]". Common cause: copying CommSys combo field lists to RMS combos without verifying each has an RMS attribute. LicensePlateYear has no RMS equivalent — remove from RMS combos. Confirmed: LA_LEMS v1.0 (2026-04-29).

### Attention field pattern (not numbered — reference builds only)
Do NOT add a visible Attention FormInput. Do NOT put Attention in `set[]`. Platform auto-fills implicitly but this is unreliable. Use `CommsysGetLastNameFirstNameInitialRuleHandler` on the Attention QIDM attribute instead (CA_eSUN, LA_LEMS pattern).

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

### LIMITATION #31: initialValue fields not counted for set[] combo evaluation
Platform combo evaluator ignores `initialValue` defaults on FormSelect/FormInput when evaluating `set[]` requirements. Only fields the user actively enters or changes are counted as "populated." Fields with `initialValue` (State=NJ, PlateType=PC, RandomRequest=N, ImageIndicator=Y/N) must go in `any[]`, not `set[]`. Confirmed NJ v2.6: VehicleStolenQuery fired but VehicleRegistrationQuery did not until defaulted fields were moved from set[] to any[].

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

Entity names, config names, and labels do NOT work. Check the Entity Display Order section above before any order fix.

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

## Tools (31 scripts in `tools/`)

All tools are provider-agnostic. `banned_patterns.txt` is the only non-script (consumed by verify_build.ps1).

### Core Build Pipeline (run every build via build_report.ps1)

| # | Tool | Purpose | Key flags |
|---|---|---|---|
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos) | `-Path <json>` `-ShowDetail` `-Force` (override lock) |
| 2 | `render_layout.ps1` | CLI layout tree renderer | `-Path <json>` `-Summary` `-Entity` `-Variant` `-QidmOnly` |
| 3 | `test_commsys.ps1` | CommSys query simulator (combo matching + XML output) | `-Path <json>` `-Entity` `-Combo` `-OutFile` |
| 4 | `report_picklists.ps1` | Scans FormSelect dropdowns + QRDM/QIDM code types | `-Path <json>` `-OutFile` |
| 5 | `render_html.ps1` | Self-contained HTML layout report with color-coded fields and QIDM tables | `-Path <json>` `-OutFile` |
| 6 | `verify_build.ps1` | Post-build verification (banned patterns, fieldId consistency, reference patterns) | `-Path <json>` `-CamelCase` |
| 7 | `audit_metadata.ps1` | Validates QIDM configs against authoritative XML metadata | `-Path <json>` `-OutFile` |
| 8 | `audit_cad.ps1` | CAD dispatch field alignment (camelCase fieldIds, layout variants, Patch 8) | `-Path <json>` `-Variant` `-OutFile` |
| -- | `build_report.ps1` | **Master orchestrator** — runs all 8 above + saves reports to docs/ | `-Path <json>` `-Release` (bundles to release/) |

### Auditors (repo-wide checks)

| Tool | Purpose | Key flags |
|---|---|---|
| `audit_repo.ps1` | Full monorepo audit (16 categories: banned patterns, versions, docs, structure, cross-provider) | `-Category <1-16>` |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase) | `-Path <providers-dir>` `-OutFile` |
| `audit_structure.ps1` | Provider folder structure (naming, required dirs/files, reports, freshness) | `-Path <provider-dir>` `-OutFile` |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphan detection) | `-Path <json>` `-OutFile` |
| `score_all.ps1` | Provider scorecard -- runs validator on all providers, sorted table with rebuild flags | `-Quick` (parse existing reports) `-OutFile` |
| `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches, AP #21-23) | `-Path <dir>` `-OutFile` |
| `sync_provider_table.ps1` | Auto-updates CLAUDE.md provider table scores from validator reports | `-DryRun` `-OutFile` |
| `preflight_rebuild.ps1` | Per-provider rebuild action plan (validator WARNs + linter + flags → checklist) | `-Provider <name>` `-All` `-Quick` `-OutFile` |

### Metadata & Extraction

| Tool | Purpose | Key flags |
|---|---|---|
| `extract_metadata_reference.ps1` | Generates METADATA_REFERENCE.txt from XML + JSON (field definitions, combo requirements, coverage) | `-XmlPath <xml>` `-Path <json>` `-OutFile` `-All` |
| `extract_queries.ps1` | Parses metadata XML into SQVR-ready tracking file | `-XmlPath <xml>` `-OutFile` |
| `diff_docs.ps1` | Diffs updated engineering docs against KB files (NEW/REMOVED/CONFIRMED per category) | `-NewDoc` `-KbFile` `-OutFile` `-Provider` |

### Provider Lifecycle

| Tool | Purpose | Key flags |
|---|---|---|
| `new_provider.ps1` | Scaffolds new provider (canonical structure, build scripts, doc templates, tool registrations) | `-XmlPath <xml>` `-PdfPath` `-Force` |
| `lock_provider.ps1` | One-command lock/unlock (folder rename, STATUS.txt, cascading reference updates) | `-Provider <name>` `-Action <Lock\|Unlock>` |
| `new_test_log.ps1` | Creates stub test log in tests/ (GATE 2 requirement) | `-Provider` `-Variant` `-Version` `-Entity` `-Combo` `-Description` |
| `post_test.ps1` | Instant-save after test (artifacts, STATUS, SQVR, commit, push) | `-Provider` `-Entity` `-Query` `-Combo` `-Result` `-Description` |

### Utilities

| Tool | Purpose | Key flags |
|---|---|---|
| `test_layout.ps1` | QIF layout validator + HTML form preview | `-Path <json>` |
| `compare_hidle.ps1` | Compares provider RMS bundle against HIDLE.json template | `-Path <json>` |
| `build_codetype_test.ps1` | Generates CODETYPE_TEST.json for dropdown validation | `-OutFile` |
| `check_docs.ps1` | Documentation consistency gate (version numbers across all provider docs) | (no args) |
| `preflight_check.ps1` | Pre-build validation against PROVIDER_CONFIG.txt | (no args) |
| `map_cad_fields.ps1` | Maps CAD field names to provider JSON fieldIds (MATCH/CASE_MISMATCH/NO_MATCH) | `-Path <json>` `-CadFields` `-OutFile` `-GeneratePatch` |
| `report_cad_mapping.ps1` | HTML report mapping CAD fields to provider sourceField/targetField per QIDM | `-Path <json>` `-OutFile` |

### Quick Reference

```powershell
# Full build pipeline (runs all 8 tools, saves reports)
powershell -ExecutionPolicy Bypass -File tools/build_report.ps1 -Path providers/<PROVIDER>/<PROVIDER>_BASE.json

# Full monorepo audit (16 categories)
powershell -ExecutionPolicy Bypass -File tools/audit_repo.ps1

# Metadata reference (run after every build)
powershell -ExecutionPolicy Bypass -File tools/extract_metadata_reference.ps1 -XmlPath providers/<PROVIDER>/source/<PROVIDER>.xml -Path providers/<PROVIDER>/<PROVIDER>_BASE.json -OutFile providers/<PROVIDER>/docs/<PROVIDER>_METADATA_REFERENCE.txt

# Test log stub (GATE 2, before every test)
powershell -ExecutionPolicy Bypass -File tools/new_test_log.ps1 -Provider <NAME> -Variant BASE -Version <ver> -Entity <entity> -Combo <combo> -Description "<desc>"

# Provider scorecard (all providers at a glance)
powershell -ExecutionPolicy Bypass -File tools/score_all.ps1 -Quick

# Build script linter (catch anti-patterns before build)
powershell -ExecutionPolicy Bypass -File tools/lint_build_scripts.ps1

# Preflight rebuild plan (single provider or all)
powershell -ExecutionPolicy Bypass -File tools/preflight_rebuild.ps1 -Provider <NAME> -Quick
powershell -ExecutionPolicy Bypass -File tools/preflight_rebuild.ps1 -All -Quick

# Sync CLAUDE.md scores after rebuilds
powershell -ExecutionPolicy Bypass -File tools/sync_provider_table.ps1
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
- Build scripts handle version archiving. Phase snapshots are saved to phases/base/ and phases/mc/.

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
- Commit JSON + all 8 report files
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

**TRIGGER: You complete a provider build (BASE or MC JSON created/updated)**
- Run extract_metadata_reference.ps1 to generate/update METADATA_REFERENCE.txt
- Commit alongside the JSON and build reports

**TRIGGER: You create a new provider folder**
- Verify folder name matches XML filename (minus .xml) BEFORE creating
- Create full canonical structure (docs/, tests/, phases/, scripts/, source/)
- Copy HIDLE.json from templates/ to source/
- Add provider to CLAUDE.md provider table
- Add provider to tools/new_test_log.ps1 knownPaths
- Update README.txt provider count if needed

**TRIGGER: You rename a provider**
- git mv the folder
- Rename all doc files (STATUS.txt, BUILD_NOTES.txt, SQVR.txt)
- Update content in all doc files
- Update CLAUDE.md, README.txt, new_test_log.ps1
- Grep full repo for old name to catch stragglers

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

1. Run `build_report.ps1 -Path <json>` (validator + layout + query sim + picklist + HTML + verify + metadata audit + CAD audit)
2. Verify 0 FAIL in validator output
3. Commit the JSON + all 8 report files to `docs/base/` or `docs/mc/`
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
2. Verify `docs/base/` (and `docs/mc/` if applicable) contains all 8 report files
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

**NAMING RULE**: `<PROVIDER>` MUST match the metadata XML filename minus `.xml`. Verify before creating the folder. See `BUILD_RULES.txt` Section 0.

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
│   ├── <PROVIDER>_METADATA_REFERENCE.txt  # Auto-generated metadata combo requirements
│   ├── JSON_INVENTORY.md                  # Every JSON version ever produced
│   ├── base/                              # BASE variant reports (8 files)
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

### Step 0: Naming (CRITICAL — do this FIRST)
- Open the metadata XML file and read its filename
- Provider folder name MUST match the XML filename minus `.xml`
- Example: `NM_NMLETS_OFML.xml` → folder `providers/NM_NMLETS_OFML/`
- Do NOT guess from devdoc titles, abbreviations, or user-supplied names
- Mismatched names require renaming 10+ files per provider (see `BUILD_RULES.txt` Section 0)

### Step 1: Setup
1. Read `knowledge-base/README.txt` then this file
2. Create provider folder with canonical structure (see above)
3. Copy metadata XML and devdoc PDF to `source/`
4. Copy `templates/HIDLE.json` to `source/HIDLE.json`
5. Convert PDF to text: `pdftotext source/<PROVIDER>.pdf source/<PROVIDER>_DEVDOC.txt`
6. Run `extract_queries.ps1 -XmlPath source/<PROVIDER>.xml` to populate SQVR
7. Read devdoc "Basic Queries Supported" — this is the ONLY authority for WHICH queries to build

### Step 2: Build
8. Create build script in `scripts/` (must include validator call + dual output)
9. Phase 1: single card, all entities, confirm all query paths
10. GATE 1 after every build (report + commit + push)
11. Update SQVR with [PENDING] markers for every query path

### Step 3: Iterate
12. Phase 2: multi-card for entities with 2+ search paths
13. Phase 3: split entity only if needed (NCIC state pattern usually avoids this)
14. GATE 5 before declaring any variant DONE

### Bulk Onboarding (10+ providers)
See `TESTING_REQUIREMENTS.txt` Section 16 for the complete workflow.
Key rule: batch setup (folders, source materials), serial builds (one provider at a time).
