# USx Provider JSON - Consolidated Monorepo

All ConnectCIC provider JSON configurations, knowledge base, and shared tools in a single repo. All new provider projects go here using the same file and build structure as existing providers.

Owner: rob.sgambellone@mark43.com
Consolidated: 2026-05-04

## Repo Structure

```
providers/{PROVIDER}/     -- 20 providers (8 active + 11 new + 1 CCH stub)
knowledge-base/           -- Build rules, anti-patterns, platform limitations
tools/                     -- Shared scripts (validator, renderers, simulators)
```

## Provider Status (updated 2026-06-14)

| Provider | Path | Version | Status | Notable patterns |
|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS/ | v3.5 | 69P/0F/0W/0LIM -- 14/14 PASS full combo coverage -- v3.5 imported USx NJCJIS Tenant + Newark Foundation Tenant 2026-05-28 | conditions routing (RAND/FULL), CAD combo defaults on all 13 combos incl State, autoSelect=false on Stolen, queriesToDeselect VehReg/Stolen, NCIC state, shared RMS module, RMS Vehicle stripped to 3 attrs |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v1.7 | 67P/0F/0W/0LIM (BASE) 67P/0F/0W/0LIM (MC) | 6-transaction build, VehicleTypeCode, ImageIndicator in all Vehicle any[], State no-default |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v3.0 | 81P/0F/0W/0LIM | 7 cards (Veh 1, Per 3+2 fields, Gun 1, Art 1, Boat 1), 17 combos, 7 QIDMs, DGRP (DL Name Search), DH OOS combos (DALHOUT/DALLOUT), Vehicle plate OOS combo (RVEHOUT), NyNyspinTransactionName visible on DH (default DALL), PurposeCode default C on DH in-state combos, Choice-set OOS pattern (LIMIT #36), DH-suffix+one-directional queriesToDeselect, CAD defaults all 17 combos, State no-default (LIMIT #30) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v2.3 | 71P/0F/0W/0LIM (BASE) 71P/0F/0W/0LIM (MC) | dexStateUserId, DH-suffix, WMPI queries, hidden badge |
| FL_FCIC | providers/FL_FCIC/ | v5.0 | 90P/0F/0W/0LIM -- 31/31 combos, 6 QIDMs -- v5.0 NOT yet imported; test package reset to T1 (v4.9 T-A/T-B: value-comparison conditions proven wholly inert -> POISONED-ARRAY RULE, QIDM_REFERENCE Sec 2a) | 2-card: Vehicle(Options+Search), Person(DL+DH OOS-only), Boat(Options+Search). Devdoc combo order + EXISTENCE-ONLY routing conditions (State NOT_EXISTS / OLN NOT_EXISTS / RelatedHit NOT_EXISTS) for first-match + pool isolation; ALL value-comparison conditions removed v5.0 (poisoned-array, live-proven T-A/T-B 2026-06-12), DH KQ out-of-state only (State in set[], no default; not-FL gate = LIMITATION + platform escalation, NOT enforceable config-side), DH+Boat destination state = NCIC dropdown restored v5.0, Boat QB stolen routing via relatedHitSearchIndicator in set[], BQ x3 restored, QV pending data-mined confirmation, one-directional queriesToDeselect, Attention visible, RMS Vehicle stripped to 3 attrs, RMS union-pool over-send fix designed but GATED (G1 impact / G2 handler verification) |
| TX_TLETS_CCH | providers/TX_TLETS_CCH/ | v1.0 | 119P/0F/0W -- STUB: 14 QIDMs (6 base + 8 CCH) | Separate CCH-gated provider. Base 6 QIDMs ported from TX_TLETS. All 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) on Person, autoSelect=false (named-checkbox via queryLabel), every CCH field CCH-suffixed (full isolation, zero collision), 3 CCH cards. Synthetic keyRefs (QH/QR/QWI/ZR) + Choice splits. FreeText capped display. CCH response QRDM out of scope. NOT live-tested |
| TX_TLETS | providers/TX_TLETS/ | v3.4 | 81P/0F/0W/1LIM -- v3.4 poisoned-array fix; NOT yet imported, test pkg reset to T1 | 6 cards (Veh 1, Per 3 DH+DL+Options, Gun 1, Art 1, Boat 1), 22 combos, 6 QIDMs, v3.4 removed inert ImageIndicator EQUALS Y conditions (poisoned-array; merged Img/catchall pairs DL 7→4, DH 4→2; image/email/reason in any[], email manual-entry pending future handler), email→shared OPTIONS card, CPL Name combo, DH-suffix+one-directional queriesToDeselect, TX-specific (DPSI/REG/VIN+FRT), CAD defaults, -SkipRace on RMS |
| LA_LEMS | providers/LA_LEMS/ | v2.5 | 63P/0F/0W/0LIM (BASE) 63P/0F/0W/0LIM (MC) | DH-suffix+queriesToDeselect, Attention handler (AP #27), DP/DQ routing toggle, State in set[], State no-default |
| CA_CLETS | providers/CA_CLETS/ | v2.5 | 76P/0F/0W/0LIM -- v2.5 poisoned-array cleanup; NOT yet re-imported, test pkg reset to T1 | purposeCode (CAD-aligned fieldId), State routing (blank=in-state via set[] presence, NOT conditions), DH-suffix fieldIds, cross-entity Name on Veh/Gun/Boat, no ImageIndicator, 6 basic queries, yyyyMMdd dates, CAD defaults on IA.QV. v2.5: removed 20 inert value-comparison conditions (poisoned-array) -- IV.4* plate types are SERVER-routed by LicensePlateTypeCode value (wire=MessageType=VehicleRegistrationQuery, keyRef internal); deleted 13 redundant IV.4* + IV.4V/IV.4B duplicates; IR.QVC criminal combos (devdoc DL #3-7, CII/SSN/OLN, IR.QVC server-routed) kept, IR.QVC.N set[] fixed (Name+SexCode per devdoc #3/#4); -SkipRace on RMS, RMS Vehicle stripped to 3 attrs |
| CA_VENTURA_COUNTY | providers/CA_VENTURA_COUNTY/ | v1.4 | 68P/0F/0W (BASE) 72P/0F/0W (MC) | 6 basic queries, CaRequestPurposeCode (visible Inp), DL+DH DH-suffix+queriesToDeselect, MC cross-entity (IN.VP/IG.QGH/NLTS.BQ.N) |
| CA_CONTRA_COSTA | providers/CA_CONTRA_COSTA/ | -- | INCOMPLETE -- metadata has only JAWS person queries, no OLN, no Vehicle/Boat/Gun/Article; CLETSPersonSuperQuery in devdoc but NOT in metadata; waiting for updated docs | 2 transactions (6 combos), Person only, RequestingAgencyId on all combos |
| CA_CLETS_OCATS | providers/CA_CLETS_OCATS/ | v1.2 | 63P/0F/0W/0LIM (BASE) 63P/0F/0W/0LIM (MC) | CLETS_OCATS v21, 5 basic queries (no DH), VP owner search, 19 combos, OCATS-specific queries available (warrants, juvenile, LARS) |
| CA_eSUN | providers/CA_eSUN/ | v1.5 | 71P/0F/0W/0LIM (BASE) 71P/0F/0W/0LIM (MC) | CaRequestPurposeCode (visible Inp), VP owner search, gun-by-name, Attention handler, MC multi-card (14 cards) |
| CA_SAN_LUIS_OBISPO | providers/CA_SAN_LUIS_OBISPO/ | v1.3 | 65P/0F/0W (BASE) 65P/0F/0W (MC) | Regional interface, DL+DH DH-suffix+queriesToDeselect, short keyRefs, MC multi-card (15 cards) |
| IL_LEADS_OFML | providers/IL_LEADS_OFML/ | v1.1 | 61P/0F/0W/0LIM (BASE) 61P/0F/0W/0LIM (MC) | 5 basic queries (no DH), Z2/Z5 keyRefs, MC multi-card (11 cards) |
| MD_METERS | providers/MD_METERS/ | v1.3 | 69P/0F/0W/0LIM (BASE) 69P/0F/0W/0LIM (MC) | 6 basic queries, DH-suffix+queriesToDeselect, ZVEH/ZLRG/ZDRV invented keyRefs, MC multi-card (12 cards), State no-default |
| OH_LEADS | providers/OH_LEADS/ | v1.3 | 77P/0F/0W/0LIM (BASE) 77P/0F/0W/0LIM (MC) | 6 basic queries, 9 VehReg combos, BMVIMS, owner search (RN), MC multi-card (14 cards) |
| NM_NMLETS_OFML | providers/NM_NMLETS_OFML/ | v1.3 | 66P/0F/0W/0LIM (BASE) 66P/0F/0W/0LIM (MC) | 6 basic queries, DH-suffix+queriesToDeselect, GunModel field, MC multi-card (12 cards) |
| OR_LEDS | providers/OR_LEDS/ | v1.3 | 58P/0F/0W/0LIM (BASE) 58P/0F/0W/0LIM (MC) | 5 basic queries (no DH), invented keyRefs, MC multi-card (11 cards) |
| TN_TIES | providers/TN_TIES/ | v1.4 | 80P/0F/0W/0LIM (BASE) 80P/0F/0W/0LIM (MC) | 6 basic queries, 28 combos, no State initialValue, MC multi-card (14 cards), DH-suffix |

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

## Build Model — Single JSON, Multi-Card from Start

One build script per provider → one `<PROVIDER>.json`. Always multi-card. No separate BASE/MC variants.

**Step 1 — QIDM Confirmation**: Build all QIDMs and combinations. Every field, every combo. Run `test_commsys.ps1` to verify all combos fire. 100% coverage from the start — no "MC expansion candidate" parking.

**Step 2 — Layout Refinement**: One card per search path for entities with 2+ distinct paths. QIDM does not change. Layout only. Retest affected entities.

**Step 3 — Split Entity**: Only if multi-card reveals a state model conflict that cannot coexist in one QIF. Most providers never need this if NCIC state pattern works.

**Why QIDM-first**: NJ and NY both introduced layout complexity before confirming QIDM paths. When tests failed it was impossible to tell if the failure was the QIDM, the layout, or the state model. Confirm QIDMs first — isolate layout from data path problems.

---

## 3-Bundle Structure

Every provider JSON has exactly 3 bundles in this order:

1. **ENTITIES** (`provider='MARK43'`): All QIFs (entity input forms) + display order
2. **PROVIDER** (`provider=[PROVIDER_NAME]`): AUTH, QMF, QRDM, all QIDMs
3. **RMS** (`provider='RMS'`): Built from KB specs via `_build_rms_bundle.ps1`

**ENTITIES must be first.** Confirmed AZ v2.0: forms do not render when ENTITIES is not first.

**QUERYINPUTFORM belongs ONLY in the ENTITIES bundle.** Adding it to any other bundle causes duplicate entity form cards.

---

## Anti-Patterns and Platform Limitations

Full reference: `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 31 LIMITATIONs with cross-reference index).

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
| -- | **attributeTypeId** | -- |
| VEHICLE_MAKE | NCIC (via attributeTypeId) | **MUST be FormSelect (Sel) on ALL providers.** Dropdown works. NEVER use FormInput. Confirmed: NJ, FL, CA_CLETS, TX live-tested. |

### State Field — NCIC Pattern (preferred)

Single visible Sel 'RegistrationState': `attributeTypeId='STATE'`, `initialValue='<state>'`.
CommSys QIDM State attr: `sourceField=['RegistrationState']`, `targetField='State'`, `codeTypeProvider='NCIC'`.
RMS: KB standard (`useAttributeId=true` + `AttributeArrayWrapperRuleHandler`).

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

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 5 (working pattern, critical rules, fallback).

---

## QIDM Architecture

### queryLabel Standard

Every QIDM must have a `queryLabel` property. Use these standard values:

| Query | queryLabel |
|---|---|
| VehicleRegistrationQuery | Vehicle Registration |
| VehicleStolenQuery | Vehicle Stolen |
| DriverLicenseQuery | Driver License |
| NyNyspinDriverLicenseNameQuery | DL Name Search |
| DriverHistoryQuery | Driver History |
| GunQuery | Firearm |
| ArticleSingleQuery | Article |
| BoatQuery | Boat |
| WMPIPersonWINQQuery | Wanted Person |
| WMPIPersonMINQQuery | Missing Person |
| CAISupervisedReleaseQuery | Supervised Release |
| CCHCriminalHistoryQHQuery | CCH Criminal History (QH) |
| CCHCriminalHistoryIQQuery | CCH Name Inquiry (IQ) |
| CCHCriminalHistoryQWIQuery | CCH Wanted/III (QWI) |
| CCHCriminalHistoryQRQuery | CCH Record Request (QR) |
| CCHCriminalHistoryZRQuery | CCH Record Request (ZR) |
| CCHCriminalHistoryFQQuery | CCH SID Query (FQ) |
| CCHCriminalHistoryAQQuery | CCH Admin Query (AQ) |
| CCHCriminalHistoryARQuery | CCH Admin Response (AR) |
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

## RMS Bundle — Built from KB Specs

**All builds**: RMS bundle and CommSys QRDM are constructed by `tools/_build_rms_bundle.ps1` from inline KB specifications. No external template dependency (no HIDLE.json). Build scripts dot-source the module and call:
- `Build-RmsBundle` — returns complete RMS bundle (AUTH, QMF, Vehicle QIDM, Person QIDM, QRDM, ResultsLayout)
- `Build-CommsysQrdm -ProviderName <name>` — returns CommSys QRDM for the PROVIDER bundle

**Flags**: `Build-RmsBundle -KeepSsn` (AZ, TN) to include socialSecurityNumber. `Build-RmsBundle -SkipRace` (TX, LA, MD, CA_CONTRA_COSTA) to exclude race attr and raceCode from combo any[].

**No post-build patches.** If a new issue is found, update the build script or `_build_rms_bundle.ps1` — never add a JSON patch.

---

## QIF Layout Helpers — Shared Module

**All builds**: All QIF layout construction functions are defined in `tools/_build_layout_helpers.ps1`. Build scripts dot-source it alongside `_build_rms_bundle.ps1`.

**Exports**: `N` (node factory), `Inp` (FormInput), `InpH` (hidden FormInput), `Sel` (FormSelect), `SelH` (hidden FormSelect), `Dt` (FormDate), `BuildMultiCardLayout` (multi-card layout engine with hidden row support), `AddCadNodes` (CAD dispatch context card), `AddFrNodes` (First Responder context card), `MakeLayouts` (builds all 3 layout variants: default, CAD_DISPATCH, FIRST_RESPONDER).

**InpH signature**: `InpH($fid, $lbl, $maxLen, $parentId, $extra)` — same as Inp but `hidden=$true`. Pass `$null` for maxLen when not needed.

---

## Provider Helpers — Shared Module

**All builds**: Provider boilerplate (AUTH, QMF, QRDM, ENTITIES bundle, output+validation) is defined in `tools/_build_provider_helpers.ps1`. Build scripts dot-source it alongside the layout and RMS modules.

**Exports**:
- `Build-Auth -ProviderName <name> [-ExtraAttributes <array>] [-ExtraAny <array>]` — standard 3-attr AUTH config (ORI, Mnemonic, UserName/dexStateUserId). IL_LEADS_OFML uses `-ExtraAttributes` for CDCName.
- `Build-Qmf -ProviderName <name>` — QUERYMESSAGEFORMAT with CommsysWsiOutgoingMessageHandler.
- `Build-ProviderQrdm -ProviderName <name>` — wraps Build-CommsysQrdm, sets name/description/provider.
- `Build-EntitiesBundle -Configurations <array> [-DefaultOrder <array>] [-CadOrder <array>] [-FrOrder <array>]` — ENTITIES bundle with configurable display order. Defaults to Vehicle-first standard.
- `Write-ProviderJson -BundleObject <obj> -OutPath <path> [-PhasePath <path>] [-Label <string>]` — ConvertTo-Json readable output, UTF-8 no BOM, runs validator with exit-on-fail.

---

## Rule Handler Reference

Full reference: `knowledge-base/RULE_HANDLERS.txt` (24 handlers — 6 directly configured, rest platform-defined in RMS).

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

## Tools (33 scripts + 3 shared modules in `tools/`)

All tools are provider-agnostic. `banned_patterns.txt` is the only non-script (consumed by verify_build.ps1).

### Core Build Pipeline (run every build via build_report.ps1)

| # | Tool | Purpose | Key flags |
|---|---|---|---|
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos) | `-Path <json>` `-ShowDetail` |
| 2 | `render_layout.ps1` | CLI layout tree renderer | `-Path <json>` `-Summary` `-Entity` `-Variant` `-QidmOnly` |
| 3 | `test_commsys.ps1` | CommSys query simulator (combo matching + XML output) | `-Path <json>` `-Entity` `-Combo` `-OutFile` |
| 4 | `report_picklists.ps1` | Scans FormSelect dropdowns + QRDM/QIDM code types | `-Path <json>` `-OutFile` |
| 5 | `render_html.ps1` | Self-contained HTML layout report with color-coded fields and QIDM tables | `-Path <json>` `-OutFile` |
| 6 | `verify_build.ps1` | Post-build verification (banned patterns, fieldId consistency, reference patterns, Visible-First Mandate / hidden-field check) | `-Path <json>` `-CamelCase` |
| 7 | `audit_metadata.ps1` | Validates QIDM configs against authoritative XML metadata | `-Path <json>` `-OutFile` |
| 8 | `audit_cad.ps1` | CAD dispatch field alignment (camelCase fieldIds, layout variants, Patch 8) | `-Path <json>` `-Variant` `-OutFile` |
| 9 | `generate_test_matrix.ps1` | Auto-generates test matrix from JSON (render + combo + any[] + deselect + negatives) | `-Path <json>` `-OutFile` |
| 10 | `run_test_matrix.ps1` | Automated test conductor — validates all test matrix cases via combo simulation | `-Path <json>` `-Matrix <file>` `-OutFile` |
| 11 | `simulate_response.ps1` | CJIS response handler simulator: executes all QRDM handler transformations (Height, Name, VehicleYear, truncate, AttributeMapping) against comprehensive synthetic test data per entity. Target: 0 MISSING / 0 UNMAPPED. No live data required. | `-Path <json>` `-Entity` `-RunEdgeCases` `-OutFile` |
| -- | `build_report.ps1` | **Master orchestrator** — runs all 11 above + saves reports to docs/ | `-Path <json>` |

### Auditors (repo-wide checks)

| Tool | Purpose | Key flags |
|---|---|---|
| `enforce.ps1` | **MANDATORY FINAL GATE** -- runs ALL checks (build freshness, validator scores, doc sync, cross-provider, repo audit, git status) | `-Provider <name>` `-SkipGit` `-Rebuild` `-OutFile` |
| `pipeline.ps1` | **ONE-COMMAND PIPELINE** -- build + report + metadata + sync + version docs + cross-provider + repo audit + enforce in 8 steps; stops on first failure | `-Provider <name>` (required) `-SkipBuild` `-SkipEnforce` |
| `doctor.ps1` | **ONE-SHOT HEALTH DASHBOARD** -- read-only snapshot: score_all -Quick + poisoned-array sweep (validate G-31) + git status | `-SkipPoison` `-OutFile` |
| `audit_repo.ps1` | Full monorepo audit (18 categories: banned patterns, versions, docs, structure, cross-provider, camelCase) | `-Category <1-18>` |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase) | `-Path <providers-dir>` `-OutFile` |
| `audit_structure.ps1` | Provider folder structure (naming, required dirs/files, reports, freshness) | `-Path <provider-dir>` `-OutFile` |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphan detection) | `-Path <json>` `-OutFile` |
| `score_all.ps1` | Provider scorecard -- runs validator on all providers, sorted table with rebuild flags | `-Quick` (parse existing reports) `-OutFile` |
| `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches, AP #21-23) | `-Path <dir>` `-OutFile` |
| `sync_provider_table.ps1` | Auto-updates CLAUDE.md provider table scores from validator reports | `-DryRun` `-OutFile` |
| `sync_version_docs.ps1` | Auto-updates STATUS.txt, SQVR.txt, JSON_INVENTORY.md, REBUILD_TRACKER.md, BUILD_NOTES.txt (date checksum) with current version and scores | `-Provider <name>` `-DryRun` |
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
| `new_test_log.ps1` | Creates stub test log in tests/ (GATE 2 requirement) | `-Provider` `-Variant` `-Version` `-Entity` `-Combo` `-Description` |
| `post_test.ps1` | Instant-save after test (artifacts, STATUS, SQVR, commit, push) | `-Provider` `-Entity` `-Query` `-Combo` `-Result` `-Description` |
| `reset_test_package.ps1` | Rebuild restarts testing: on version change, archives prior logs, resets SQVR→PENDING, clears STATUS rows, stamps tests/.test_version. Auto-run by pipeline after build. | `-Provider` `-Force` |

### Utilities

| Tool | Purpose | Key flags |
|---|---|---|
| `test_layout.ps1` | QIF layout validator + HTML form preview | `-Path <json>` |
| `build_codetype_test.ps1` | Generates CODETYPE_TEST.json for dropdown validation | `-OutputPath` |
| `check_docs.ps1` | Documentation consistency gate (version numbers across all provider docs) | (no args) |
| `preflight_check.ps1` | Pre-build validation against PROVIDER_CONFIG.txt | (no args) |
| `map_cad_fields.ps1` | Maps CAD field names to provider JSON fieldIds (MATCH/CASE_MISMATCH/NO_MATCH) | `-Path <json>` `-CadFields` `-OutFile` `-GeneratePatch` |
| `report_cad_mapping.ps1` | HTML report mapping CAD fields to provider sourceField/targetField per QIDM | `-Path <json>` `-OutFile` |
| `Apply-CadFieldAlignment.ps1` | CAD field alignment function for MC builds (PascalCase → camelCase rename) | dot-source; `-QidmList` `-FormList` `-RmsBundle` `-ProviderRenames` |
| `generate_build_script.ps1` | Generates build script from metadata XML (field mapping, QIDM generation, layout) | `-XmlPath <xml>` `-DevdocPath` `-OutDir` |

Validator must pass clean (0 FAIL) before import. Verify must pass clean (0 FAIL). Fix all failures before proceeding.

---

## Import Error Quick Reference

See `knowledge-base/IMPORT_ERRORS.txt` for error-to-fix mapping.

---

## Versioning Policy

- **NEVER overwrite a tested JSON.** Save every iteration.
- Name format: `<PROVIDER>_v<X.Y>_<date>.json` or `<PROVIDER>_v<X.Y>.json`
- Document every JSON in `docs/JSON_INVENTORY.md`
- Keep all JSONs in project root
- Build scripts handle version archiving. Phase snapshots are saved to phases/.

---

## Source Authority Lookup Table — MANDATORY ROUTING

When you need information, use ONLY the source listed below. Do NOT substitute raw sources, do NOT guess, do NOT skip to the underlying data. If the tool/file does not exist yet, create it first.

| Question | Authoritative Source | NEVER Use |
|---|---|---|
| **Which queries** does this provider support? | Devdoc "Basic Queries Supported" section (`source/<PROVIDER>_DEVDOC.txt`) | XML metadata transaction names, naming pattern guesses |
| **How are fields defined** (types, sizes, combo requirements)? | `docs/<PROVIDER>_METADATA_REFERENCE.txt` (auto-generated by `extract_metadata_reference.ps1`) | Raw XML metadata files (`source/*.xml`) |
| **What field type** (FormInput/FormSelect/FormDate) should a field use? | `METADATA_REFERENCE.txt` field definitions + `audit_cross_provider.ps1` for consistency | Manual XML inspection, guessing from field name |
| **What combos fire** for a given entity/field set? | `test_commsys.ps1 -Path <json> -Entity <entity>` | Manual build script reading, mental combo matching |
| **What does the layout look like?** | `render_layout.ps1 -Path <json> -Summary` | Reading raw Craft.js node tree in JSON |
| **Are there structural issues?** | `build_report.ps1 -Path <json>` (runs all 11 tools) | Spot-reading JSON sections |
| **Is this field consistent across providers?** | `audit_cross_provider.ps1 -Path providers/` | Manual grep across provider folders |
| **Are all docs/versions in sync?** | `enforce.ps1 -Provider <name>` | Manual file-by-file comparison |
| **What anti-patterns apply?** | `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 31 LIMITATIONs) | Memory, training data |
| **What does the RMS bundle contain?** | `tools/_build_rms_bundle.ps1` (all builds) + CLAUDE.md RMS Bundle section | Raw JSON inspection |
| **Current build state** (scores, warnings) | `docs/` report files (generated by `build_report.ps1`). Legacy: `docs/base/` or `docs/mc/` | Re-running validator ad hoc |
| **Test coverage status** | `audit_test_coverage.ps1 -Path <json>` + `docs/<PROVIDER>_SQVR.txt` | Counting test log files manually |

**Rule: If a tool exists for the question, run the tool. If an extracted file exists, read the file. Raw sources are LAST resort only when no extracted reference exists.**

---

## Workflow

Three commands run everything. No manual checklists.

| Action | Command |
|---|---|
| **Build + verify one provider** | `pipeline.ps1 -Provider <NAME>` |
| **Build + verify multiple providers** | `pipeline.ps1 -Providers 'TX_TLETS','HI_HCJDC_OFML'` |
| **Build + verify ALL providers** | `pipeline.ps1 -All` |
| **Final verification (all providers)** | `enforce.ps1` |
| **New provider setup** | `new_provider.ps1 -XmlPath <xml>` |

`pipeline.ps1` chains 8 steps: build JSON → build report (steps 1-9 parallel) → extract metadata → sync CLAUDE.md → sync version docs → cross-provider audit → repo audit → enforce. Stops on first failure. Flags: `-SkipBuild` (reports only), `-SkipEnforce` (mid-work), `-DeferAudit` (skip steps 6-7 for mid-work iterations).

**Rebuild restarts testing.** Step 1 calls `reset_test_package.ps1` after a successful build: when the JSON version changes, prior live test logs no longer line up with the shipped JSON, so they are archived to `tests/_archive_pre_v<ver>/`, all SQVR markers reset `[CONFIRMED]→[PENDING]`, STATUS live rows cleared, and `tests/.test_version` stamped. The full test matrix re-runs from Test 1 — never resume mid-matrix across a rebuild. See `knowledge-base/TESTING_REQUIREMENTS.txt` Section 11 GATE 1.

**Batch mode** (`-Providers` or `-All`): runs per-provider steps (1-3) sequentially per provider, then ONE sync pass, ONE cross-provider audit, ONE repo audit, ONE enforce. Eliminates redundant global audits when rebuilding multiple providers.

`build_report.ps1` runs 11 tools. Steps 1-9 execute in parallel (all read-only on the JSON), step 10 (test conductor) runs after step 9, step 11 (response simulator + missing-field test) runs last.

`enforce.ps1` runs 5 phases: build freshness, validator scores, doc version sync (6 locations per provider: CLAUDE.md, STATUS, SQVR, JSON_INVENTORY, BUILD_NOTES + date checksum, REBUILD_TRACKER), cross-provider + repo integrity (phases 4-5 run in parallel), git status. Exit 0 = verified. Exit 1 = blocked.

**If enforce.ps1 passes, the work is done. If it doesn't, fix what it flags.**

### Design Decisions (applied automatically)

- Phase 1 = single card per entity
- 2+ search paths = multi-card (Phase 2)
- DH on same form as DL = DH-suffix fieldIds
- Duplicate keyRefs = invent distinct keyRef
- Most-specific combination first in array
- Investigate all 4 solution paths (multi-combo, separate transaction, DH-suffix, reference builds) before declaring not implementable
- Test NCIC state pattern (ST-1) on first import of any new provider

---

## Canonical Provider Structure

Every provider under `providers/` MUST have this structure. All new providers follow the same layout.

**NAMING RULE**: `<PROVIDER>` MUST match the metadata XML filename minus `.xml`. Verify before creating the folder. See `BUILD_RULES.txt` Section 0.

**ONE JSON IN ROOT RULE**: Exactly one JSON in the provider root folder at all times.
- New providers: `<PROVIDER>.json` (no suffix)
- Legacy providers may still have `<PROVIDER>_MC.json` or `<PROVIDER>_BASE.json` until rebuild
- NEVER multiple JSONs in root simultaneously. Enforce checks this.

```
providers/<PROVIDER>/
├── <PROVIDER>.json                        # Current JSON (single output per provider)
├── docs/
│   ├── <PROVIDER>_STATUS.txt              # Live test matrix + current state
│   ├── <PROVIDER>_BUILD_NOTES.txt         # Change log with CHANGED/REASON per version
│   ├── <PROVIDER>_SQVR.txt                # Supported Query Validation Report
│   ├── <PROVIDER>_METADATA_REFERENCE.txt  # Auto-generated metadata combo requirements
│   ├── JSON_INVENTORY.md                  # Every JSON version ever produced
│   ├── VALIDATOR_REPORT_*.txt             # Build reports (10 files from build_report.ps1)
│   └── ...                                # Other reports (LAYOUT, QUERY, PICKLIST, etc.)
├── tests/                                 # Per-test log files (one per test executed)
├── phases/                                # Version snapshots
├── scripts/                               # Provider-specific build scripts
│   └── build_<provider>.ps1               # Single build script per provider
├── source/                                # Input materials
│   ├── <provider>.xml                     # Metadata XML
│   └── <provider>.pdf                     # Devdoc PDF
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
4. RMS bundle built automatically from KB specs (no template copy needed)
5. Convert PDF to text: `pdftotext source/<PROVIDER>.pdf source/<PROVIDER>_DEVDOC.txt`
6. Run `extract_queries.ps1 -XmlPath source/<PROVIDER>.xml` to populate SQVR
7. Read devdoc "Basic Queries Supported" — this is the ONLY authority for WHICH queries to build

### Step 2: Build
8. Create build script in `scripts/` (must include validator call)
9. Build all QIDMs and multi-card layout in one pass. 100% combo coverage from start.
10. GATE 1 after every build (report + commit + push)
11. Update SQVR with [PENDING] markers for every query path

### Step 3: Iterate
12. Refine layout (card splits, field ordering, defaults)
13. Split entity only if needed (NCIC state pattern usually avoids this)
14. GATE 5 before declaring DONE

### Bulk Onboarding (10+ providers)
See `TESTING_REQUIREMENTS.txt` Section 16 for the complete workflow.
Key rule: batch setup (folders, source materials), serial builds (one provider at a time).
