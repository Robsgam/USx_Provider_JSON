# USx Provider JSON - Consolidated Monorepo

All ConnectCIC provider JSON configurations, knowledge base, and shared tools in a single repo. All new provider projects go here using the same file and build structure as existing providers.

Owner: rob.sgambellone@mark43.com
Consolidated: 2026-05-04

## THE ENGINEERING STANDARD — read this first

**`ENGINEERING_STANDARD.md` (repo root) is the top-level contract for what "done" means.** Three
laws (the form comes first; a gate that cannot fail is not a gate; authority is directional and both
directions must be checked), the 6-stage lifecycle with the gate that owns each stage — build →
spec → reachability → tenant test → **Jira entry** → **import record** — the catalogue of defect
classes that have shipped past a green board, the rules for building a gate, and the definition of
"finished" for a provider. Do not restate its rules elsewhere; point at it.
## Repo Structure

```
providers/{PROVIDER}/     -- 20 providers (all galvanized to single-JSON, PascalCase; TX_TLETS_CCH is a variant of TX_TLETS)
knowledge-base/           -- Build rules, anti-patterns, platform limitations
tools/                     -- Shared scripts (validator, renderers, simulators)
```

## Provider Status (updated 2026-08-01)

| Provider | Path | Version | Validator | Tenant test | Notable patterns | History |
|---|---|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS/ | v4.15 | 61P/0F/0W | ALL-PASS 5/5 (36 logs) | VehicleStolenQuery NOT built (USER-APPROVED skip; state auto-runs QV, response data-mined via QRDM); VehReg 2 combos (RANDFULL/RANDFULLN), poisoned-array RandomRequest=Y conditions removed (RandomRequest user-controlled in any[]); DriverLicense 2 combos (FULL/FULLN); PascalCase USx fieldIds (CAD/OnScene), Mark43/RMS keys stay camelCase; CAD combo defaults; NCIC state; shared RMS module, RMS Vehicle stripped to 3 attrs | [changelog](providers/NJ_NJCJIS/docs/tracking/CHANGELOG_NJ_NJCJIS.md) |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v4.14 | 65P/0F/0W | ALL-PASS 5/5 (46 logs) | 6 basic queries (Article/Boat/DH/DL/Gun/VehReg), 16 combos all reachable; single JSON; Person 2 cards (Driver License + Driver History, each self-contained w/ own State, DH-suffix, one-directional deselect); Vehicle 1 card (v4.14, collapsed from Search Options/Plate/VIN, OOS-first routing); Boat/Firearm/Article 1 card; Type Code dropdown (VEHICLE_TYPE/HI_NIBRS); ImageIndicator=N combo defaults on all VehReg combos; State in DL/DH any[] + VehReg any[] for OOS; identifier-priority guardrails complete (Plate>VIN, OLN>Name DL+DH, Hull>Reg); Name Last-first (v4.0) | [changelog](providers/HI_HCJDC_OFML/docs/tracking/CHANGELOG_HI_HCJDC_OFML.md) |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v4.19 | 76P/0F/0W | ALL-PASS 5/5 (64 logs) | PascalCase, 5 cards (Veh 1, Per 2 [DL+DH], Gun 1, Art 1, Boat 1), 16 combos, 6 QIDMs (DGRP name-search removed v4.11, DEX-1284), DH self-contained w/ own StateDH/ImageDH + OOS combos (DALHOUT/DALLOUT) RegistrationStateDH EXISTS/NOT_EXISTS routing, Vehicle plate OOS combo (RVEHOUT), NyNyspinTransactionName visible on DH (default DALL), PurposeCode default C on DH OOS combos, Choice-set OOS pattern (LIMIT #36), DH-suffix+one-directional queriesToDeselect, CAD defaults, State no-default (LIMIT #30), identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg) | [changelog](providers/NY_NYSPIN_EJUSTICE/docs/tracking/CHANGELOG_NY_NYSPIN_EJUSTICE.md) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v3.3 | 63P/0F/0W | NEVER 0/5 | dexStateUserId hidden badge, DH-suffix isolation, RegistrationStateDH hidden SelH (initialValue AZ), Attention auto-handler (CommsysGetLastNameFirstNameInitialRuleHandler), KeepSsn, invented keyRefs (ACVRV/DQN/KQH), existence-gate identifier-priority guardrails + badge-present gates, 6 QIDMs (WMPI Wanted/Missing removed v3.3 -- not devdoc-Basic). Person 2 cards (DL+DH), Vehicle/Boat 1 card each | [changelog](providers/AZ_AZDPS/docs/tracking/CHANGELOG_AZ_AZDPS.md) |
| FL_FCIC | providers/FL_FCIC/ | v7.14 | 91P/0F/0W | ALL-PASS 5/5 (109 logs) | 1-card Vehicle + 1-card Boat (both collapsed from 2), Person(DL+DH OOS-only). Devdoc combo order + EXISTENCE-ONLY routing conditions (State NOT_EXISTS / OLN NOT_EXISTS / RelatedHit NOT_EXISTS) for first-match + pool isolation; ALL value-comparison conditions removed (poisoned-array rule, QIDM_REFERENCE Sec 2a); DH KQ out-of-state only; DH+Boat destination state = NCIC dropdown; Boat QB stolen routing via relatedHitSearchIndicator in set[]; identifier-priority guardrails complete (Plate>VIN, OLN>Name, Hull>Reg); Attention auto-populated (handler); RMS Vehicle stripped to 3 attrs | [changelog](providers/FL_FCIC/docs/tracking/CHANGELOG_FL_FCIC.md) |
| TX_TLETS_CCH | providers/TX_TLETS_CCH/ | v1.14 | 112P/0F/0W | NEVER 0/5 | Separate CCH-gated provider. Base 6 QIDMs identical to TX_TLETS main. All 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) on Person, autoSelect=false (named-checkbox via queryLabel), every CCH field CCH-suffixed (full isolation, zero collision), 3 CCH cards. Synthetic keyRefs (QR/QWI/ZR) + Choice splits; QH 5 combos (BDOB/NAME.SSN/NAME.MISC/SID/FBI -- NAME split to honor the mandatory SSN\|Misc Choice, v1.5). FreeText capped display. CCH response QRDM out of scope. NOT USx-tenant-tested | [changelog](providers/TX_TLETS_CCH/docs/tracking/CHANGELOG_TX_TLETS_CCH.md) |
| TX_TLETS | providers/TX_TLETS/ | v4.18 | 79P/0F/0W | ALL-PASS 5/5 (89 logs) | 7 cards (Veh 1, Per 3 [Options+DL+DH], Gun 1, Art 1, Boat 1), 19 CommSys combos, 6 QIDMs, PascalCase, identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg), QV plate/VIN subset-shadows removed (v4.9), in/out State-gated (FL pattern), MessageKey on DL, DH merged (Image=Y triggers Reason+Email trio, both auto-populated via hidden gate-feeders), CAD plate defaults (PlateYear/PlateType on REG/RQ, FRT=E on REG/VIN), DH-suffix+one-directional queriesToDeselect, TX-specific (DPSI/REG/VIN+FRT), -SkipRace on RMS | [changelog](providers/TX_TLETS/docs/tracking/CHANGELOG_TX_TLETS.md) |
| LA_LEMS | providers/LA_LEMS/ | v3.0 | 64P/0F/0W | NEVER 0/5 | DH-suffix+queriesToDeselect, Attention auto-handler (AP #27, feeder pattern), DP/DQ routing toggle, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/LA_LEMS/docs/tracking/CHANGELOG_LA_LEMS.md) |
| CA_CLETS | providers/CA_CLETS/ | v2.23 | 79P/0F/0W | ALL-PASS 5/5 (89 logs) | purposeCode (CAD-aligned fieldId), DH-suffix fieldIds, cross-entity Name on Veh/Gun/Boat, no ImageIndicator, 6 basic queries, yyyyMMdd dates, CAD defaults on IA.QV. DL: 8 combos (NLTS.DQ.N/DQ + IR.QVC.N/O/C/S + in-state ID.L1/IN.L1). RegistrationState EXISTS guards all NLTS combos. OLN cascade: OLN+State->NLTS.DQ, OLN+CII->IR.QVC.O, OLN-only->ID.L1. Name cascade: Name+State->NLTS.DQ.N, Name+Sex->IR.QVC.N, Name-only->IN.L1. CII->IR.QVC.C, SSN->IR.QVC.S. | [changelog](providers/CA_CLETS/docs/tracking/CHANGELOG_CA_CLETS.md) |
| CA_VENTURA_COUNTY | providers/CA_VENTURA_COUNTY/ | v2.2 | 79P/0F/0W | NEVER 0/5 | 6 basic queries, CaRequestPurposeCode (visible Inp), DL+DH DH-suffix+queriesToDeselect, cross-entity (IN.VP/IG.QGH/NLTS.BQ.N), Attention auto-handler, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/CA_VENTURA_COUNTY/docs/tracking/CHANGELOG_CA_VENTURA_COUNTY.md) |
| CA_CONTRA_COSTA | providers/CA_CONTRA_COSTA/ | v2.2 | 79P/0F/0W | NEVER 0/5 | CA_CLETS twin (6 families / 40 combos / PascalCase / race kept in RMS); JAWS+SuperQuery unbuilt-in-metadata; RequestingAgencyId only on the (unbuilt) JAWS combos | [changelog](providers/CA_CONTRA_COSTA/docs/tracking/CHANGELOG_CA_CONTRA_COSTA.md) |
| CA_CLETS_OCATS | providers/CA_CLETS_OCATS/ | v2.1 | 64P/0F/0W | NEVER 0/5 | CLETS_OCATS v21, 5 basic queries (no DH), VP owner search, CaRequestPurposeCode on all combos, OCATS-specific queries (warrants/juvenile/LARS) available-not-built | [changelog](providers/CA_CLETS_OCATS/docs/tracking/CHANGELOG_CA_CLETS_OCATS.md) |
| CA_eSUN | providers/CA_eSUN/ | v2.1 | 72P/0F/0W | NEVER 0/5 | 6 QIDMs, CaRequestPurposeCode (visible Inp, officer-selectable), VP owner search, gun-by-name (QGH), Attention auto-handler, DL+DH DH-suffix+queriesToDeselect (visible DH cards), OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/CA_eSUN/docs/tracking/CHANGELOG_CA_eSUN.md) |
| CA_SAN_LUIS_OBISPO | providers/CA_SAN_LUIS_OBISPO/ | v2.1 | 65P/0F/0W | NEVER 0/5 | Regional interface (not direct CLETS), DL+DH DH-suffix+queriesToDeselect, short keyRefs, no State initialValue (LIMITATION #30 in/out split), no ImageIndicator | [changelog](providers/CA_SAN_LUIS_OBISPO/docs/tracking/CHANGELOG_CA_SAN_LUIS_OBISPO.md) |
| IL_LEADS_OFML | providers/IL_LEADS_OFML/ | v2.0 | 61P/0F/0W | NEVER 0/5 | 5 basic queries (no DH), Z2/Z5 keyRefs, CDCName in AUTH, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/IL_LEADS_OFML/docs/tracking/CHANGELOG_IL_LEADS_OFML.md) |
| MD_METERS | providers/MD_METERS/ | v2.0 | 69P/0F/0W | NEVER 0/5 | 6 basic queries, DH-suffix+queriesToDeselect, ZVEH/ZLRG/ZWAR/ZLDR/ZDRV/ZBOA keyRefs, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails, State no-default | [changelog](providers/MD_METERS/docs/tracking/CHANGELOG_MD_METERS.md) |
| OH_LEADS | providers/OH_LEADS/ | v2.0 | 76P/0F/0W | NEVER 0/5 | 6 basic queries, 7 VehReg combos (9 metadata, 2 NCIC shadows dropped) + owner SSN/Name cross-entity, DH-suffix+queriesToDeselect, Attention eSUN feeder, existence-only routing gates, identifier-priority guardrails (Plate>VIN>SSN>Name, OLN>Name, Hull>Reg), State no-default | [changelog](providers/OH_LEADS/docs/tracking/CHANGELOG_OH_LEADS.md) |
| NM_NMLETS_OFML | providers/NM_NMLETS_OFML/ | v2.1 | 66P/0F/0W | NEVER 0/5 | 6 basic queries, DH-suffix+queriesToDeselect, GunModel field, existence-only routing gates (Vehicle/Boat NCIC-vs-Nlets by State), identifier-priority guardrails, DH PurposeCode+RaceCode optional any[] | [changelog](providers/NM_NMLETS_OFML/docs/tracking/CHANGELOG_NM_NMLETS_OFML.md) |
| OR_LEDS | providers/OR_LEDS/ | v2.0 | 55P/0F/0W | NEVER 0/5 | 5 basic queries (no DH), invented keyRefs (RQ/DQ/QG/QA/BQ splits), OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails, MC multi-card | [changelog](providers/OR_LEDS/docs/tracking/CHANGELOG_OR_LEDS.md) |
| TN_TIES | providers/TN_TIES/ | v2.0 | 74P/0F/0W | NEVER 0/5 | 6 basic queries, 22 combos (8 Veh incl. Dealer/Handicap/Temp specialty, 5 DL, 3 DH, Gun/Article/Boat), no State initialValue (LIMITATION #30), DH-suffix + queriesToDeselect, Attention auto-handler feeder, existence-only OOS gates + identifier-priority guardrails | [changelog](providers/TN_TIES/docs/tracking/CHANGELOG_TN_TIES.md) |

## Import Tracking (which JSON version is in which tenant)

**`providers/IMPORT_LEDGER.md` is the single source of truth** for where each JSON is installed.
Two tenant classes: **USx Provider Tenants** (one per provider; the driver capture tool is locked
to these — so the newest version with non-archived `logs/` = proof of what's installed there,
self-verifying, never assume) and **Foundation Tenants** (customer staging, e.g. Newark / Miami
Springs / Balcones Heights — the capture tool can't reach them, so their versions are recorded
manually in the ledger from actual import reports only). Update the ledger's Foundation section on
every reported import; the Provider-Tenant section is log-derived (recompute via `portfolio_status.ps1`
or the ledger's one-liner). Do NOT answer "where is X installed" from memory alone — read the ledger.

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

## Provider Variants (CCH / "supported-stuff") — Source Sharing

**Base providers** (`TX_TLETS`, `NJ_NJCJIS`, …) are built **directly from their own devdoc + metadata** — `source/<PROVIDER>.pdf`/`.xml` are authoritative for the base.

**Variant providers** — `<BASE>_CCH` today, and other "supported-stuff" variants going forward (the expectation is a CCH variant for **every** provider eventually) — **reuse the BASE provider's devdoc + metadata by default, unless explicitly given their own.** Example: `TX_TLETS_CCH`'s devdoc IS the TLETS manual `source/TX_TLETS.pdf` (carried in its own `source/`), not a separate `TX_TLETS_CCH.pdf`. A variant may carry its own merged metadata XML (base + variant transactions), but the **devdoc (query authority) is the base's** unless told otherwise.

**Tooling must honor this** — do NOT demand a variant-named source doc or duplicate the base PDF under the variant name. `audit_structure.ps1`'s devdoc-PDF check accepts a base-prefixed PDF when the variant name strips (on `_`) to a sibling base provider directory (added 2026-07-24). Any future devdoc/metadata-resolution logic should follow the same base↔variant fallback.

**Base + variants = ONE logical provider (kept in lockstep).** A variant is *derived* from the base (it inherits the base's QIDMs/metadata/devdoc), so **any change to the base JSON — rebuild, combo edit, label pass, CAD fix — must propagate to (trigger a rebuild of) every variant.** Variants must never drift from their base independently. When you touch a base provider, rebuild its variants in the same pass and re-run their gates. Directory layout stays one-dir-per-variant (`TX_TLETS`, `TX_TLETS_CCH`), but they are treated as a unit. **Lockstep is enforced by convention + check (added 2026-07-24):** each variant's build script declares `# BASE-SYNC: <BASE> vX.Y` (the base version its base-6 is synced to), and `tools/audit_variant_sync.ps1` (composed into `doctor.ps1`) flags any declared variant whose marker is behind its base's current version. Detection is marker-driven, NOT name-based — so an independent provider that merely shares a name prefix (e.g. `CA_CLETS_OCATS`) is not mistaken for a variant. When the base bumps: re-sync the variant's base-6 and bump its `BASE-SYNC` marker. **Drift resolved 2026-07-24:** `TX_TLETS_CCH` v1.3 re-synced its base-6 to `TX_TLETS` v4.7 (email handler + FRT=E default added, QWName removed) and now declares `# BASE-SYNC: TX_TLETS v4.7`.

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

Full reference: `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 24 LIMITATIONs, non-contiguous #1-#37, with cross-reference index).

---

## Field Configuration Rules

### USx CAD Field Names — PascalCase (authored from the start)

The 22 USx CAD-integration field names (the ones CAD/OnScene auto-populate) are **PascalCase**, matching Cringer's engineering reference JSON. Mark43/RMS-internal keys (firstName, vinNumber, dlNumber, *AttrDetail.id, response JSON paths, …) stay camelCase.

- **Author PascalCase directly** in the build script — layout `Inp`/`Sel`/`Dt` fieldId args, QIDM `sourceField`, and combo `set[]`/`any[]`. The QIDM `targetField`, combo `defaults[].field`, and attribute `name` are already PascalCase.
- RMS form-fed fields: pass `-PascalCaseUsxFields` to `Build-RmsBundle`.
- **NEVER use a whole-tree recase post-transform.** The retired `Convert-UsxCasing` function (NJ ≤ v4.1) recursed the full output object and enumerated each Craft.js `nodes` list, collapsing single-child lists to a bare string and empty lists to `null`. Craft.js requires `nodes` to be an array, so the form body silently failed to render (only tab names showed). Removed 2026-06-18; all casing is now native.
- The 22 tokens: LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear, RandomRequest, RegistrationState, ImageIndicator, VehicleIdentificationNumber, NCICNumber, VehicleMakeCode, NameFirst, NameLast, BirthDate, SexCode, OperatorLicenseNumber, GunSerialNumber, GunMake, GunCaliber, GunModel, ArticleSerialNumber, ArticleTypeCode, RegistrationNumber, BoatHullIdNumber (+ DH-suffix variants where present).
- **Rollout status**: COMPLETE — all 20 providers are galvanized (native PascalCase, single versioned JSON, `Build-RmsBundle -PascalCaseUsxFields`). No camelCase-legacy providers remain. (camelCase persists only for the deliberate exceptions: in-state `licensePlateNumber`, RMS-internal keys, `serialNumber`/`vehicleYear`/`raceCode`/`caRequestPurposeCode` per the token rules.)

### Code Type Pairings (confirmed working)

| codeTypeCategory | codeTypeSource | Notes |
|---|---|---|
| NCIC_LICENSE_PLATE_TYPE | NCIC | Baseline |
| NCIC_FIREARM_TYPE | NCIC | Baseline |
| NCIC_FIREARM_MAKE | NCIC | FIREARM makes only. NOT vehicle makes (AP #24) |
| VehicleType | **VEHICLE** | QRDM response **vehicle make** lookup (VehicleMakeName). Vehicle codes live in the `VehicleType` table under the `VEHICLE` source (user-verified vs platform registry 2026-06-24). NOT NCIC_FIREARM_MAKE. |
| NCIC_FIREARM_CALIBER | NCIC | FormInput also valid |
| NCIC_ARTICLE_TYPE | **CA_CLETS** | NCIC gives empty dropdown |
| YES_NO_UNKNOWN | **NCIC** | Y/N only. NIBRS adds Unknown (3 options) |
| NIBRS_SEX | NIBRS | DO NOT use attributeTypeId=SEX (see Sex Code section) |
| NIBRS_RACE | NIBRS | DO NOT use attributeTypeId=RACE. NCIC = empty dropdown |
| NJ_NIBRS_STATE | NJ_NIBRS | For OOS state dropdowns |
| VEHICLE_BODY_STYLE | Provider-specific | NJ=NJ_NIBRS, CA=VEHICLE. NCIC = empty |
| -- | **attributeTypeId** | -- |
| VEHICLE_MAKE | NCIC (via attributeTypeId) | **MUST be FormSelect (Sel) wherever the field is built.** Dropdown works. NEVER use FormInput. Confirmed USx-tenant-tested: FL, CA_CLETS, TX, NY. **NOT ALL PROVIDERS CARRY IT** -- NJ_NJCJIS and HI_HCJDC_OFML build NO VehicleMakeCode field at all (verified 2026-08-01: absent from form AND every QIDM; neither provider's devdoc COMBINATIONS require it, and the devdoc's other mentions are response/field-definition tables). The earlier "Confirmed: NJ" claim here was wrong -- NJ has no such field to have confirmed. Consequence: verify_build's VehicleMakeCode check is VACUOUS on those two, and audit_gate_efficacy's `vehiclemake-as-input` mutation reports N/A there by design. |

### State Field

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 5 (NCIC pattern vs dual-field
fallback, RMS wiring, the initialValue-vs-routing decision tree, LIMITATION #30). One-line
summary: prefer the single NCIC-pattern `RegistrationState` field; do NOT set `initialValue`
on it when the provider has separate in-state vs OOS keyRefs (changes which combo fires) —
use a card title hint instead.

### Date Fields
FormDate sends ISO yyyy-MM-dd. QIDM attribute: `rule=CommsysParseDateRuleHandler`, `arguments=['yyyy-MM-dd','MMddyyyy']`.

### Name (composite)

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 7 (FormatStringRuleHandler wiring,
the authoritative ConnectCIC LAST-first / `LAST, FIRST MIDDLE SUFFIX` format rule, the
individual-component-tags recommendation, and per-provider audit history). One-line summary:
`sourceField` order is `@('nameLast','nameFirst','nameMiddle','nameSuffix')`; all 5 in-scope
providers (NJ/CA_CLETS/HI/FL/NY) build Last-first — cross-check this order on every new build.

### LicensePlateNumber
In-state: `fieldId='licensePlateNumber'`. OOS: `fieldId='LicensePlateNumberOut'`.
Generic 'LicensePlateNumber' does NOT trigger RMS plate search.
QIDM `targetField` remains 'LicensePlateNumber'.

### OLN field label (global — DEX-1284, 2026-07-27)
The operator-license-number field (`OperatorLicenseNumber` + DH variant) is labeled **"OLN"** on every provider — not "License Number"/"OL Number"/"Driver License Number". Card/query names stay "Driver License"/"Driver History"; only the field label is OLN. Applied to each provider on its revisit turn (not a retroactive sweep). See BUILD_RULES.txt Section 11 (CANONICAL FIELD LABEL — OLN).

### NCIC Image field label (global — DEX-1284, 2026-07-27)
Every image-toggle field (`ImageIndicator` + DH variant) is labeled exactly **"NCIC Image"** on every provider — not "NCIC Image - if available"/"Image (optional)"/"Image". **Future retrofit** — applied to each provider on its revisit turn (NY_NYSPIN_EJUSTICE v4.12 first), not a one-shot sweep. `verify_build.ps1` CHECK 15 Rule 3 accepts bare "NCIC Image" via its `$canonicalBareLabels` allowlist, so it needs no `(optional)` qualifier and no LABEL-OVERRIDE. Companion lean-label convention: strip inline helpers and let the **card title** carry the query paths (State keeps its routing hint; stolen-hit toggles → bare "Stolen Check"). See BUILD_RULES.txt Section 11.

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

**Flags**: `Build-RmsBundle -KeepSsn` (AZ, TN) to include socialSecurityNumber. `Build-RmsBundle -SkipRace` (TX_TLETS, TX_TLETS_CCH, LA_LEMS, MD_METERS) to exclude race attr and raceCode from combo any[]. `Build-RmsBundle -PascalCaseUsxFields` (all 20 providers — galvanization COMPLETE) to emit the form-fed `sourceField`/`set`/`any` USx references in PascalCase so they match the PascalCase form fieldIds; Mark43-internal targetFields stay camelCase.

**No post-build patches.** If a new issue is found, update the build script or `_build_rms_bundle.ps1` — never add a JSON patch.

---

## USx Tenant Test Capture — CommSys + RMS Pairing (standard as of NJ_NJCJIS v4.7, rolling out)

**Background:** `Build-RmsBundle` only emits a Vehicle QIDM and a Person QIDM (see above) — Gun,
Article, Boat, and DriverHistoryQuery have **no RMS mapping at all**. Prior to 2026-07-01, the
capture automation (`automation/extension/`) only scraped the CommSys/ConnectCic wire XML from
dex-log; it never touched the RMS side, so a whole class of RMS-only regressions (e.g. a QRDM
code-source mismatch producing "Mock results processed" — see NJ v4.6→v4.7, and the same class
fixed for FL/HI/CA) was only ever caught by someone manually screenshotting the RMS UI. This is
now closed: dex-log's table carries an RMS-destination row alongside the ConnectCic row for every
query that has an RMS mapping, and its own "View request and return" popup exposes the RMS
elasticQuery request + response text — `automation/extension/capture.js` now captures both and
pairs them by field-map content (order-independent), not by a fragile string/position match.

**Test log section order** (`tools/post_test.ps1`): header stamp (JSON Version/Entity
Fingerprint/Tier) → `QUERY STRING` (the dex-log field-map JSON) → `COMMSYS XML`
(pretty-printed/indented, not the minified wire string) → `COMMSYS XML RESPONSE`
→ `RMS QUERY` (request + response together) → `FIELD ANALYSIS` → `NOTES` → `RESULT`. `RMS QUERY`
reads "Not captured" for Gun/Article/Boat/DH — that's the **correct, expected** state (no RMS
mapping exists for those entities), not evidence of a gap.

**`logs/` — the ONLY test log, self-contained.** The separate narrative `tests/` folder was
eliminated 2026-07-01 (redundant once `logs/<Entity>/` carried the full FIELD ANALYSIS/NOTES/RESULT
content, not just wire evidence). Every test now has exactly one file:
`providers/<PROVIDER>/logs/<Entity>/<PROVIDER>_v<X.Y>_<Combo>.txt` — one folder per entity
(Vehicle, Person, Firearm, Article, Boat), one file per query, containing the full section order
above. The versioned test plan lives at the ROOT of this same folder:
`providers/<PROVIDER>/logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json` — `emit_test_plan.ps1`'s default
output. This makes `logs/` a standalone package (plan + every query's full evidence + narrative)
that doesn't require cross-referencing `docs/` to audit. `logs/.test_state.json` +
`logs/.test_version` (moved from the old `tests/` folder) are the entity fingerprint/version state
that `reset_test_package.ps1`/`block_entity.ps1` read and write.

**Rollout**: NJ_NJCJIS is the pilot/reference implementation (v4.7, 2026-07-01). Other providers
(CA_CLETS, FL_FCIC, NY_NYSPIN_EJUSTICE, TX_TLETS, etc.) pick this up automatically the next time
they go through a full rebuild/re-test cycle — do not backport it to another provider's capture
usage ad hoc before that.

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

Full reference: `knowledge-base/RULE_HANDLERS.txt` (25 handlers — 7 directly configured, rest platform-defined in RMS).

**AUTHORITATIVE PLATFORM REGISTRY: `knowledge-base/UNIVERSAL_SEARCH_HANDLERS.txt`** — captured 2026-07-29 from Confluence (`HandlerConfiguration.java`): every handler the platform *accepts*, including the ~8 no provider currently uses, plus the `fallbackRule` mechanism and the top-level `behaviors` block. **Check it before concluding a capability does not exist** — RULE_HANDLERS.txt documents only what we already build, and on 2026-07-29 that gap produced a wrong "no such handler exists" answer about `IgnoreUserValueRuleHandler`, which is running in production on CA_eSUN.

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

## Tools (84 scripts + 17 shared modules in `tools/`, + `tools/config/` (5 JSON reference tables) + 3 archived tools in `tools/_archive/`)

All tools are provider-agnostic. `banned_patterns.txt` is the only non-script (consumed by verify_build.ps1).

Shared modules (dot-sourced, `_`-prefixed): `_build_rms_bundle.ps1`, `_build_layout_helpers.ps1`, `_build_provider_helpers.ps1`, `_json_canonical.ps1`, `_resolve_provider_json.ps1` (active-JSON resolver `Get-ProviderRootJson` — bare → versioned → `_MC` → `_BASE`), `_resolve_provider_xml.ps1` (metadata-XML resolver `Get-ProviderMetadataXml` — exact `<PROVIDER>.xml` → base provider's XML for a variant → the only XML present → `$null` + warning; **refuses to guess between multiple candidates**, because an alphabetical glob made a gate read CA_CONTRA_COSTA's 6-node JAWS-only excerpt instead of the real 466-node metadata and report green — see `knowledge-base/README.txt`).

### Core Build Pipeline (run every build via build_report.ps1)

| # | Tool | Purpose | Key flags |
|---|---|---|---|
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos); also flags a top-level `version` field (platform-reject) and a CommSys `codeTypeProvider` reverse-lookup vs the code-string field (AP #11, CommSys direction) | `-Path <json>` `-ShowDetail` |
| 2 | `render_layout.ps1` | CLI layout tree renderer (LAYOUT_REPORT). Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 or audit_repo.ps1 Category 10 | `-Path <json>` `-Summary` `-Entity` `-Variant` `-QidmOnly` |
| 3 | `test_commsys.ps1` | CommSys query simulator (combo matching + XML output; QUERY_REPORT). Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 or audit_repo.ps1 Category 10 | `-Path <json>` `-Entity` `-Combo` `-OutFile` |
| 4 | `report_picklists.ps1` | Scans FormSelect dropdowns + QRDM/QIDM code types (PICKLIST_REPORT). Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 or audit_repo.ps1 Category 10 | `-Path <json>` `-OutFile` |
| 5 | `render_html.ps1` | Self-contained HTML layout report with color-coded fields and QIDM tables | `-Path <json>` `-OutFile` |
| 6 | `verify_build.ps1` | Post-build verification (banned patterns, fieldId consistency, reference patterns, Visible-First Mandate / hidden-field check) | `-Path <json>` |
| 7 | `audit_metadata.ps1` | Validates QIDM configs against authoritative XML metadata | `-Path <json>` `-OutFile` |
| 8 | `audit_cad.ps1` | CAD dispatch field alignment (PascalCase field alignment, CAD_DISPATCH/FIRST_RESPONDER layout variants, CAD defaults coverage) | `-Path <json>` `-OutFile` |
| 9 | `generate_test_matrix.ps1` | Auto-generates test matrix from JSON (render + combo + any[] + deselect + negatives) | `-Path <json>` `-OutFile` |
| 10 | `run_test_matrix.ps1` | Automated test conductor — validates all test matrix cases via combo simulation. Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 | `-Path <json>` `-Matrix <file>` `-OutFile` |
| 11 | `simulate_response.ps1` | CJIS response handler simulator: executes all QRDM handler transformations (Height, Name, VehicleYear, truncate, AttributeMapping) against comprehensive synthetic test data per entity. Target: 0 MISSING / 0 UNMAPPED. No live data required. Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 | `-Path <json>` `-Entity` `-RunEdgeCases` `-OutFile` |
| -- | `build_report.ps1` | **Master orchestrator** — always runs 1, 5-9 + saves reports to docs/, then prunes orphaned variant reports (build-owned report files for a JSON variant no longer present — e.g. after consolidating branches). Pass `-IncludeExtended` to also run 2-4 (layout/query/picklist reports) plus 10-11, lint/label-review/officer-guide/test-conductor (8 advisory outputs demoted from the default run 2026-07-06 -- nothing gates on them) | `-Path <json>` `-IncludeExtended` |

### Auditors (repo-wide checks)

| Tool | Purpose | Key flags |
|---|---|---|
| `enforce.ps1` | **MANDATORY FINAL GATE** -- runs ALL checks (build freshness, validator scores, doc sync, cross-provider, repo audit, git status) | `-Provider <name>` `-SkipGit` `-Rebuild` `-Reproducible` `-OutFile` |
| `audit_reproducible.ps1` | Proves committed JSON == a fresh build: runs the build script twice into scratch (via $env:REPRO_OUTPATH hook), checks DETERMINISM + CURRENCY (version/PlateYear normalized). FAIL=non-deterministic; WARN=stale. Opt-in via `enforce -Reproducible` | `-Path <json>` `-OutFile` `-Strict` |
| `_json_canonical.ps1` | Shared canonical JSON serialization + hashing (ConvertTo-Canonical, Get-Sha256Hex, New-NormalizedClone). Reused by get_entity_fingerprints + audit_reproducible | (dot-sourced) |
| `pipeline.ps1` | **ONE-COMMAND PIPELINE** -- build + report + metadata + sync + version docs + cross-provider + repo audit + enforce in 8 steps; stops on first failure | `-Provider <name>` (required) `-SkipBuild` `-SkipEnforce` |
| `doctor.ps1` | **ONE-SHOT HEALTH DASHBOARD** -- read-only snapshot: score_all -Quick + poisoned-array sweep (validate G-31) + git status + reverse-propagation status | `-SkipPoison` `-OutFile` |
| `flag_pending_fix.ps1` | **REVERSE-PROPAGATE** a shared-module/JSON fix as a doc-stub flag: writes `[FLAG:<id>]` into each still-pending provider's PENDING_UPDATES.txt (blocks enforce PHASE 1 until rebuilt; build script clears it) + appends a REVERSE_PROPAGATION_LOG.md row. Idempotent. | `-FixId` `-Description` `-Providers <list\|all>` `-Origin` `-Date` `-DryRun` `-OutFile` |
| `audit_reverse_propagation.ps1` | Portfolio status view: reads every PENDING_UPDATES.txt + REVERSE_PROPAGATION_LOG.md, reports which providers are pending/propagated per fix + gaps. Informational (enforce PHASE 1 is the gate); composed into doctor.ps1 | `-OutFile` |
| `audit_variant_sync.ps1` | Base↔variant lockstep drift check. For each provider declaring `# BASE-SYNC: <BASE> vX.Y` in its build script (marker-driven, no name-heuristic false positives), flags drift if the marker is behind the base's current version. Catches the class where a variant (CCH) silently falls behind its base (TX_TLETS). Composed into doctor.ps1. See "Provider Variants". | `-Path <dir>` `-OutFile` |
| `audit_session_state.ps1` | **SESSION PICK-UP GATE** (enforce 2l) -- verifies `SESSION_STATE.md`, the repo-root pick-up point auto-injected into every new session by the SessionStart hook. Checks the provider versions it names against the active JSONs, that it isn't >14 days behind the last commit, and that it hasn't grown past ~120 lines (the accumulation failure that killed its memory-file predecessor). A stale pick-up point is worse than none | `-OutFile` |
| `audit_form_review.ps1` | **RENDERED FORM REVIEW** (enforce 2k, ADVISORY) -- records which build a human actually looked at, in `docs/tracking/<P>_FORM_REVIEW.txt`. Every other gate proves the request is correct; none proves the form is usable, and every label/title/layout defect in 2026-07 was caught by eye, not by tooling. Advisory on purpose: a review is a human act and must not be manufacturable to satisfy a gate | `-Path <json>` `-Record -Reviewer <name>` |
| `audit_sqvr_integrity.ps1` | **SQVR TRUTH GATE** (enforce 2j) -- the SQVR is hand-maintained prose asserting which combos exist/how many/what version, and nothing verified it, so it rotted on every combo add-remove; it's also what a tester reads to decide what to test. Checks SQVR-named keyRefs exist in the JSON (blocks/sections marked DORMANT-REMOVED-NOT BUILT-OUT OF SCOPE report [NOTE]), stated combo/QIDM totals match, and stated JSON version matches. Does NOT require every combo to have a block (13 providers use a lighter format) | `-Path <json>` `-OutFile` |
| `audit_log_combo_attribution.ps1` | **LOG ATTRIBUTION GATE** -- did each saved log's NAMED combo actually fire? The wire XML carries no keyRef, so this was unverifiable and a green package could overstate coverage (17 of 417 logs were filed under combos that never ran, found 2026-07-29). Replays each log's recorded QUERY STRING (routing is existence-based, so field presence decides the winner) through the owning QIDM in array order, using the canonical `_sim_helpers` predicate. Scopes the QIDM by the log header's QUERY NAME, never bare keyRef (they collide across QIDMs -- BUILD_RULES 13). Stale logs on registered `dead-combo*` divergences report [NOTE] | `-Path <json>` `-OutFile` |
| `audit_combo_reachability.ps1` | **DEAD-COMBO GATE** (fill-independent) -- the platform fires the FIRST matching combo, so combo A is unreachable if a B ordered before it matches whenever A does. Silent case: B's extra `set[]` fields are all form-prefilled (`initialValue`), so B always wins. Such a combo still validates, still counts toward coverage, and can carry a PASS log -- the wire XML has no keyRef, so a log named for A can't be distinguished from one where B fired. Counts only form `initialValue` as always-present; resolves EXISTS/NOT_EXISTS on prefilled fields; skips RMS cascades. `dead-combo*` accepted divergences report [NOTE] not [FAIL] | `-Path <json>` `-OutFile` |
| `audit_gate_efficacy.ps1` | **MUTATION TESTING FOR THE GATES** (LAW 2 -- a gate that cannot fail is not a gate). Injects each known defect CLASS into a throwaway replica and checks the owning gate actually FAILs. KILLED=its PASS is evidence; SURVIVED=that gate is blind, its PASS proves nothing for that class. Catalogue is hand-authored, so its score is bounded by what we thought of -- pair it with `fuzz_gate_efficacy.ps1` | `-Provider <name>` `-Only <substr>` `-OutFile` |
| `fuzz_gate_efficacy.ps1` | **RANDOM mutation testing** -- what the hand-authored catalogue structurally cannot do. Mutation sites are ENUMERATED FROM THE JSON (set↔any, drop, over-permit from a sibling combo, drop-conditions, swap-order, prefill, Select→Input), aimed at nothing; the whole gate panel runs and the only question is whether ANY gate reacted. Survivors are CANDIDATES needing triage, not verdicts. `-Seed` makes runs reproducible. Wired into `build_phase1` step 6b | `-Provider <name>` `-Mutations <n>` `-Seed <int>` `-OutFile` |
| `audit_log_inflation.ps1` | **COVERAGE-INFLATION ATTACKS** -- every other log gate asks "is what we sent correct?"; none asked "are these N logs actually N DISTINCT tests?". Four attacks: **A** clone (identical wire XML counted twice), **B** fingerprint drift (JSON rebuilt in place without a version bump, so the log is stale while its filename reads current), **C** orphan wire field (predates a rename), **D** degenerate guardrail (competing identifiers filled with the SAME value proves nothing). 0/0/0/0 over 434 logs / 6 providers, 2026-07-31 | `-Providers <list>` |
| `audit_order_risk.ps1` | **THE HONEST ORDERING NUMBER** -- `audit_devdoc_order`'s "mapped N of M" reads as "up to 44% unverified", but LINE 1 (specificity, via reachability) covers every pair. A pair is only at risk if neither `set[]` is a subset of the other, BOTH are ungated, and they're co-satisfiable -- only then does devdoc listing order alone decide. TX 5 / NY 0 / NJ 0 / FL 19 / HI 0 / CA 2 | `-Providers <list>` |
| `audit_devdoc_order.ps1` | **DEVDOC-ORDER TIEBREAKER GATE** (PHASE 1 step 3b) -- line 2 of the ordering rule: when two DIFFERENT queries could both execute on the filled fields, the devdoc-earlier one must fire. Flags an INVERSION only when the devdoc-later combo sits ahead AND is UNGATED (a discriminating condition legitimately defers). Only combos that MAP to a devdoc item are checked; mapped/unmapped counts printed every run | `-Path <json>` `-OutFile` |
| `audit_requirement_fidelity.ps1` | **PER-COMBINATION mandatory/optional fidelity** (enforce PHASE 2s, advisory) -- built `set[]`/`any[]` vs the metadata alternative it implements. Catches UNDER-REQUIRED (a metadata-mandatory field demoted to `any[]` or absent) and OVER-PERMITTED. Where `audit_metadata` CHECK 4 tests the sibling-combo UNION and so cannot see a field missing from ONE combination | `-Path <json>` `-OutFile` |
| `audit_lifecycle.ps1` | **LIFECYCLE TAIL** (enforce PHASE 2r, advisory) -- stages 5 and 6, previously ungated: the Jira entry (`DEX_TICKET.md` names the current version) and the import record (`IMPORT_LEDGER.md` accounts for it, either an install or an explicit not-yet-imported line -- silence is the defect) | `-Provider <name>` |
| `audit_provider_linkage.ps1` | **PROVIDER LINKAGE GATE** (ADVISORY) — every provider JSON is **standalone**; its build is justified by ITS OWN devdoc (query authority) + ITS OWN metadata XML (field authority). Flags a build script naming a *different* provider, in code or comment, allowlisting only the **two directed links**: `CA_CONTRA_COSTA`→`CA_CLETS` (explicit ruling) and `<BASE>_<VARIANT>`→`<BASE>` (declared via `# BASE-SYNC:`, drift-gated by `audit_variant_sync`). Comments count — a comment is where the justification lives, and a justification pointing at another provider is the defect. **Why it's not cosmetic:** `CA_CLETS` and `CA_VENTURA_COUNTY` both have an `IR.QVC{Name}` DL combo and require **opposite** things — CA_CLETS's has 4 metadata variants with `Choice[Age\|BirthDate]` in `<Any>` (optional, correctly registered as demoted-to-any), Ventura's has 1 with it in `<Set>` (mandatory, must be split). Copying the "verified sibling" ships a request the other provider's metadata calls invalid. Excludes `codeTypeSource/Provider/Category` (e.g. `codeTypeSource='CA_CLETS'` is a platform registry value, not a link). Baseline 2026-08-01: 68 refs across 20 providers — ADVISORY, cleaned at each provider's own rebuild, never a blocking flag (comment provenance has no wire impact) | `-Provider <name>` `-OutFile` |
| `audit_ps51_parse.ps1` | **PS 5.1 PARSE GATE** — every `tools/*.ps1` must parse on the engine that actually runs it. `pipeline`/`enforce` invoke tools as `powershell -File` (5.1); interactive work often runs `pwsh` 7, and the grammars differ, so a tool can be built, run and "verified" under 7 while being a hard parse failure under 5.1 — which surfaces as swallowed ParserError text, not a FAIL line. Two 5.1-only modes found: (1) non-ASCII inside a **double-quoted/interpolated** string in a BOM-less file (5.1 decodes cp1252; both U+2014 and U+2500 contain byte `0x94` = right curly quote = string delimiter — the repo's 66 other non-ASCII scripts are safe only because theirs sit in *single*-quoted strings), (2) nested same-type quotes inside `$()`. **Prints the engine version and refuses to report clean unless on 5.1** — the first version of this check ran under pwsh 7 and reported 99/0 while two files were broken. Composed into `doctor.ps1` | `-OutFile` |
| `audit_repo.ps1` | Full monorepo audit (18 categories: banned patterns, versions, docs, structure, cross-provider, camelCase) | `-Category <1-18>` |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase) | `-Path <providers-dir>` `-OutFile` |
| `audit_structure.ps1` | Provider folder structure (naming, required dirs/files, reports, freshness) | `-Path <provider-dir>` `-OutFile` |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphan detection) | `-Path <json>` `-OutFile` |
| `portfolio_status.ps1` | **CANONICAL PORTFOLIO STATUS** -- the single one-screen fixed-column table (Provider / Ver / Meth / Validator P-F-W-LIM / USx-tenant-test state+logs) + totals + git footer. Assembled from the active root JSON, newest VALIDATOR_REPORT, and actual log RESULT lines (log-truth). **Reference THIS verbatim for any "where is everything" question -- never hand-assemble a status table.** Shares its classifier with report_test_status via `_test_status_lib.ps1` so the table + narrative views can't drift. | `-Provider <name>` `-OutFile` |
| `report_test_status.ps1` | USx-tenant-test NARRATIVE view (per-entity log counts + PASS/FAIL/PENDING breakdown). Same `_test_status_lib.ps1` classifier as portfolio_status. Reads log RESULT lines, NOT `.test_state.json`. | `-Provider <name>` `-OutFile` |
| `score_all.ps1` | Provider scorecard -- runs validator on all providers, sorted table with rebuild flags. NOTE: its BASE/MC columns show `--` for galvanized single-JSON providers; use `portfolio_status.ps1` for the complete picture. | `-Quick` (parse existing reports) `-OutFile` |
| `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches, AP #21-23) | `-Path <dir>` `-OutFile` |
| `sync_provider_table.ps1` | Auto-updates CLAUDE.md provider table scores from validator reports | `-DryRun` `-OutFile` |
| `sync_version_docs.ps1` | Auto-updates STATUS.txt, SQVR.txt, JSON_INVENTORY.md (versioned filename), REBUILD_TRACKER.md, BUILD_NOTES.txt (date checksum), per-provider CHANGELOG_<PROVIDER>.md, and the repo-root CHANGELOG.md "Current:" line, with current version and scores | `-Provider <name>` `-DryRun` |
| `generate_changelog.ps1` | Renders per-provider `docs/CHANGELOG_<PROVIDER>.md` (Markdown) from `<PROVIDER>_BUILD_NOTES.txt`. Deterministic. Step 16 of build_report; re-run by sync_version_docs | `-Path <json>` `-Provider <name>` `-OutFile <path>` |
| `preflight_rebuild.ps1` | Per-provider rebuild action plan (validator WARNs + linter + flags → checklist) | `-Provider <name>` `-All` `-Quick` `-OutFile` |
| `audit_log_content.ps1` | Saved-log integrity: every test log's QUERY STRING must satisfy its plan test's full fill-set (not identifier-only). NOTE: also prints the log-count vs plan-test-count delta, but PASSes on the logs that exist -- plan completeness is the classifier's job (PARTIAL state) | `-Provider <name>` `-Quiet` |
| `audit_supported_queries.ps1` | DEVDOC GROUND-TRUTH GATE: validates the JSON's built queries against the devdoc "Basic Queries Supported" list (build_report step 14) | `-Path <json>` `-OutFile` |
| `audit_xml_consistency.ps1` | On-demand run-over-run wire-XML regression check (manual; not run by enforce/pipeline/build_report): same combo + same fills must produce identical wire XML run to run. Compares the working tree against a git ref | `-Provider <name>` `-BaselineRef <commit>` `-Quiet` |
| `audit_simulator_parity.ps1` | Guards that test_commsys.ps1 and run_test_matrix.ps1 share one canonical condition-evaluation path | `-Path <json>` |
| `audit_picklist_scope.ps1` | ADVISORY picklist-scope reminder (never blocks): flags providers missing the one-time TENANT_PICKLISTS.json capture | `-Path <json>` |
| `verify_claims.ps1` | Hypothesis Quarantine Gate: blocks unverified platform-behavior claims from driving churn (must cite committed test logs). Repo-wide -- takes NO -Path (passing one is silently ignored) | `-OutFile <path>` |
| `get_entity_fingerprints.ps1` | Computes per-entity canonical fingerprints (via _json_canonical) for test-state tracking / block_entity | `-Path <json>` |

### Metadata & Extraction

| Tool | Purpose | Key flags |
|---|---|---|
| `extract_metadata_reference.ps1` | Generates METADATA_REFERENCE.txt from XML + JSON (field definitions, combo requirements, coverage) | `-XmlPath <xml>` `-Path <json>` `-OutFile` `-All` |
| `extract_queries.ps1` | Parses metadata XML into SQVR-ready tracking file | `-XmlPath <xml>` `-OutFile` |
| `diff_docs.ps1` | Diffs updated engineering docs against KB files (NEW/REMOVED/CONFIRMED per category) | `-NewDoc` `-KbFile` `-OutFile` `-Provider` |
| `check_test_preconditions.ps1` | Cross-checks combo defaults against devdoc conditional field constraints (the "Must be filled if X=Y" gate). WARN-ONLY, always exits 0 (pipeline treats it as advisory) -- it CANNOT prove a constraint is satisfied by a handler, so a WARN needs human adjudication. Passes VACUOUSLY when `source/<PROVIDER>_DEVDOC.txt` is absent (audit_structure CHECK 9b now flags that) | `-Provider <name>` `-Query <name>` `-FromHook` |

### Provider Lifecycle

| Tool | Purpose | Key flags |
|---|---|---|
| `new_provider.ps1` | Scaffolds new provider (canonical structure, build scripts, doc templates, tool registrations) | `-XmlPath <xml>` `-PdfPath` `-Force` |
| `new_test_log.ps1` | Creates stub test log in logs/<Entity>/ (migrated providers) or legacy tests/ (GATE 2 requirement) | `-Provider` `-Variant` `-Version` `-Entity` `-Combo` `-Description` |
| `post_test.ps1` | Instant-save after test (artifacts, STATUS, SQVR, commit, push) | `-Provider` `-Entity` `-Query` `-Combo` `-Result` `-Description` |
| `reset_test_package.ps1` | Rebuild restarts testing: on version change, archives prior logs/<Entity>/ files, resets SQVR→PENDING, clears STATUS rows, stamps logs/.test_version. Auto-run by pipeline after build. | `-Provider` `-Force` |

### Utilities

| Tool | Purpose | Key flags |
|---|---|---|
| `build_codetype_test.ps1` | Generates CODETYPE_TEST.json for dropdown validation | `-OutputPath` |
| `preflight_check.ps1` | Pre-build validation against PROVIDER_CONFIG.txt | (no args) |
| `render_officer_guide.ps1` | HTML/PDF officer query reference (required-vs-optional fields per query). **This is the one `build_report.ps1` step 13 runs.** | `-Path <json>` `-OutFile` `-PdfFile` |
| `accept_divergence.ps1` | Appends a reasoned entry to a provider's accepted-divergence registry (read by audit_metadata CHECK 4/4d/5) | `-Provider` `-Reason` |
| `suggest_field_labels.ps1` | Derives required/optional label hints from QIDM combos | `-Path <json>` |
| `emit_picklist_scope.ps1` | Emits the PICKLIST_SCOPE.json the browser scope tool consumes (one-time-per-provider tenant picklist capture) | `-Path <json>` |
| `import_picklists.ps1` | Merges usx_picklists_*.json downloads into docs/reference/TENANT_PICKLISTS.json + validates current test values | `-Path <download>` |
| `relabel_batch.ps1` | Content-based batch relabeler (pipeline stage before import); fixes unreliable browser-side label pairing | `-BatchPath <file>` `-PlanPath <file>` `-KeepUnmatched` |
| `serve_plans.ps1` | Localhost HTTP server so the browser extension loads the repo's current test plan / picklist scope itself | (no args) |
| `watch_captures.ps1` | Start once per test session; watches Downloads for usx_captured_*.json and ingests them | (no args) |

Validator must pass clean (0 FAIL) before import. Verify must pass clean (0 FAIL). Fix all failures before proceeding.

---

## Import Error Quick Reference

See `knowledge-base/IMPORT_ERRORS.txt` for error-to-fix mapping.

---

## Versioning Policy

- **NEVER overwrite a tested JSON.** Save every iteration.
- **Root JSON name carries the version: `<PROVIDER>_v<X.Y>.json` (STANDARD).** The build
  script sets `$OUT = "$DIR\<PROVIDER>_v${Version}.json"`. `Write-ProviderJson` removes any
  stale sibling root JSON (bare `<PROVIDER>.json` or an older `<PROVIDER>_v*.json`) before
  writing, so the one-JSON-in-root rule holds on every bump. The bare `<PROVIDER>.json` name
  is still accepted (legacy) but new/rebuilt providers should emit the versioned name.
- **Why the filename — not a top-level `version` field — carries the version:** the platform
  deserializes a top-level `version` as `java.lang.Integer` and rejects dotted strings ("4.6").
  So version lives (a) in the filename and (b) inside the bundle `description`
  ("Provider configuration for <PROVIDER> v<X.Y> ..."), which is what enforce CHECK 3i reads.
  Do NOT re-add a top-level `version` field.
- Phase snapshots are saved to `phases/` as `<PROVIDER>_v<X.Y>_<date>.json` — **legacy pattern,
  being retired provider-by-provider starting with NJ_NJCJIS (2026-07-01).** Every version is
  already fully recoverable from git commit history (`git log`/`git show`), which `phases/` only
  duplicated while accumulating same-version-rebuild noise (NJ had 3 separate v3.6 snapshots, 2x
  v4.1, 2x v4.5 before retirement). Providers not yet migrated still use `phases/` as documented —
  don't touch another provider's build script ad hoc; each one drops it on its own next rebuild.
- **Test plan filename carries the version too: `logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json`** — at the
  ROOT of `logs/` (the self-contained per-query evidence package, see "USx Tenant Test Capture" above),
  not `docs/`. Same reasoning as the root JSON above — a rebuild must never silently overwrite the
  prior version's plan with no trace. `emit_test_plan.ps1` computes this by default;
  `reset_test_package.ps1` archives any stale-version copy to `logs/_archive_pre_v<X.Y>/` and
  regenerates the current one on every reset. Rolled out to NJ_NJCJIS first; other providers pick
  it up on their next rebuild.
- Document every JSON in `docs/JSON_INVENTORY.md`. Keep all JSONs in project root.
- **Tools resolve the active JSON via `tools/_resolve_provider_json.ps1`
  (`Get-ProviderRootJson`)** — bare → versioned → `_MC` → `_BASE` — never by hardcoding
  `<PROVIDER>.json`.

---

## Source Authority Lookup Table — MANDATORY ROUTING

When you need information, use ONLY the source listed below. Do NOT substitute raw sources, do NOT guess, do NOT skip to the underlying data. If the tool/file does not exist yet, create it first.

| Question | Authoritative Source | NEVER Use |
|---|---|---|
| **Which queries** does this provider support? | Devdoc "Basic Queries Supported" section (`source/<PROVIDER>_DEVDOC.txt`) | XML metadata transaction names, naming pattern guesses |
| **How are fields defined** (types, sizes)? | `docs/<PROVIDER>_METADATA_REFERENCE.txt` (auto-generated by `extract_metadata_reference.ps1`) | Raw XML metadata files (`source/*.xml`) |
| **Is a field MANDATORY or OPTIONAL in a specific combination?** | **The raw XML `<Requirements>` of that `<Combination>`.** This is the ONE sanctioned raw-XML exception — say so when you use it. | ⚠️ **`METADATA_REFERENCE.txt` — it FLATTENS `<Choice>` branches.** It emits one row per `(keyRef, primaryField)` showing only the common mandatory prefix, so a keyRef with several variants collapses to one under-stated row. `IG.QGH Name` reads `mandatory: CaRequestPurposeCode, Name` while the XML holds THREE variants — and building to that row is precisely how CA_CLETS shipped a request no variant accepted (v2.23 fix). Until `extract_metadata_reference.ps1` emits one row per branch, this file cannot answer this question. |
| **What field type** (FormInput/FormSelect/FormDate) should a field use? | `METADATA_REFERENCE.txt` field definitions + `audit_cross_provider.ps1` for consistency | Manual XML inspection, guessing from field name |
| **What combos fire** for a given entity/field set? | `test_commsys.ps1 -Path <json> -Entity <entity>` | Manual build script reading, mental combo matching |
| **What does the layout look like?** | `render_layout.ps1 -Path <json> -Summary` | Reading raw Craft.js node tree in JSON |
| **Are there structural issues?** | `build_report.ps1 -Path <json>` (runs 9 core tools; `-IncludeExtended` for the 2 advisory ones) | Spot-reading JSON sections |
| **Is this field consistent across providers?** | `audit_cross_provider.ps1 -Path providers/` | Manual grep across provider folders |
| **Are all docs/versions in sync?** | `enforce.ps1 -Provider <name>` | Manual file-by-file comparison |
| **What anti-patterns apply?** | `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 24 LIMITATIONs, non-contiguous #1-#37) | Memory, training data |
| **What does the RMS bundle contain?** | `tools/_build_rms_bundle.ps1` (all builds) + CLAUDE.md RMS Bundle section | Raw JSON inspection |
| **Current build state** (scores, warnings) | `docs/` report files (generated by `build_report.ps1`). Legacy: `docs/base/` or `docs/mc/` | Re-running validator ad hoc |
| **Test coverage status** | `audit_test_coverage.ps1 -Path <json>` + `docs/<PROVIDER>_SQVR.txt` | Counting test log files manually |
| **Conditional field constraints** ("Must be filled if X = Y") | `docs/<PROVIDER>_METADATA_REFERENCE.txt` FIELD CONSTRAINTS section (per QIDM) + `source/<PROVIDER>_DEVDOC.txt` "Possible Values" column | Training data, memory |

**Rule: If a tool exists for the question, run the tool. If an extracted file exists, read the file. Raw sources are LAST resort only when no extracted reference exists.**

---

## Session continuity — SESSION_STATE.md

`SESSION_STATE.md` (repo root) is the **pick-up point** for a new session. The user's SessionStart hook injects it automatically, so a restarted session starts with current context instead of re-deriving it. It is **committed to git** (versioned, diffable) and **gated** by `enforce` PHASE 2l via `audit_session_state.ps1`.

**Rules:** current state ONLY (no history — that lives in git and `docs/tracking/CHANGELOG_<P>.md`); under ~80 lines or it stops being read; **update it in the same commit as the work it describes**. Never append a dated section — *replace* the content. Numbers in it must be derived from `portfolio_status.ps1` / `enforce.ps1`, never remembered.

## Workflow

### The three phases — what "rebuild", "test", and "finalize" each mean

Rob's model: **"you need to build the entire process around 3 functions — when I say rebuild or
build, when I say test, and when I save/finalize it."** Each phase has ONE orchestrator that owns
its gates, so the phase word maps to a command, not to a checklist someone has to remember.

| Phase word | Command | What it owns |
|---|---|---|
| **"build" / "rebuild"** | `build_phase1.ps1 -Provider <NAME>` | HANDS-OFF. Proves the build against the sources before a human is asked for anything: [1] every devdoc combination built, [2] every devdoc optional routes AND transmits, [3] combo priority (no ungated subset ahead of a superset), [3b] **devdoc listing order** as the tiebreaker, [4] per-combination requirement fidelity, [5] query trace / prefill-dead, [6] gate efficacy (hand-authored mutations), **[6b] random unaimed fuzz**, [7] enforce. Ends with SHORTCOMINGS + an INTERPRETATION decision tree rather than a bare pass/fail. |
| **"test"** | `test_phase2.ps1 -Provider <NAME>` (then `-PostIngest`) | **AUTOMATED** — the browser driver runs the plan and the watcher ingests; the human's part is the rendered-form review (pre and post) evidenced on the Jira ticket. Pre-flight: [1] SPEC-vs-JSON plan coverage (an independent statement, not a JSON mirror), [2] package alignment + unfireable-test check, [3] environment. `-PostIngest` runs the FOUR log gates: 6c content, 6d metadata, 2i attribution, plan completeness. |
| **"finalize" / "save"** | `enforce.ps1 -Provider <NAME>` → commit+push → `audit_lifecycle.ps1` | Exit 0 is the definition of done. The lifecycle tail (PHASE 2r) is what makes it *finished* rather than merely green: the Jira entry names the current version and the import ledger accounts for it. |

Two is not enough and neither is one: `pipeline.ps1` builds, but only PHASE 1 asks *whether the
build matches the devdoc*; `enforce` gates the repo, but only PHASE 2 proves the wire.

**Each phase has a SKILL that packages its reasoning** (`.claude/skills/`). The skill is where the
non-obvious traps live — read it before running the phase, not after it fails:

| Skill | Phase / trigger |
|---|---|
| `usx-build` | **PHASE 1.** "rebuild X", "audit X", any provider-JSON change. Authority-reading rules (`<Choice>` position; METADATA_REFERENCE flattens branches), the two lines of ordering, FIX-vs-REGISTER, LAW 2 mutation discipline, and the verdict-by-substring / BOM / array-unwrap traps. |
| `usx-test-iterate` | **PHASE 2.** "let's test X", or a devdoc/metadata change needing reconciliation. Routes through `test_phase2`; includes the submitted-vs-captured reconciliation that a lost Chrome download otherwise hides. |
| `usx-new-provider` | A brand-new provider from XML/PDF (naming gate first). |
| `usx-add-cch` | A CCH/"supported-stuff" variant of an existing base. |
| `usx-resume` | Session restart — sweeps for environment state no document can hold. |

**Two standing instructions that are NOT gaps and must never be listed as owed work:**
- **Jira is HELD** (2026-07-31) until the process and results are fully trusted. `enforce` PHASE 2r
  will print a `[GAP] DEX_TICKET.md does NOT name vX.Y` for every provider — expected, advisory.
- **The rendered form review is Rob's own MANUAL gate.** PHASE 2k prints `[INFO] not reviewed` as its
  steady state. Never prompt for it; be ready to record it with
  `audit_form_review.ps1 -Record -Reviewer <name>`.

Three commands run everything else. No manual checklists.

| Action | Command |
|---|---|
| **Build + verify one provider** | `pipeline.ps1 -Provider <NAME>` |
| **Build + verify multiple providers** | `pipeline.ps1 -Providers 'TX_TLETS','HI_HCJDC_OFML'` |
| **Build + verify ALL providers** | `pipeline.ps1 -All` |
| **Final verification (all providers)** | `enforce.ps1` |
| **New provider setup** | `new_provider.ps1 -XmlPath <xml>` |

`pipeline.ps1` chains 8 steps: build JSON → build report (steps 1-9 parallel) → extract metadata → sync CLAUDE.md → sync version docs → cross-provider audit → repo audit → enforce. Stops on first failure. Flags: `-SkipBuild` (reports only), `-SkipEnforce` (mid-work), `-DeferAudit` (skip steps 6-7 for mid-work iterations).

**Rebuild restarts testing.** Step 1 calls `reset_test_package.ps1` after a successful build: when the JSON version changes, prior USx tenant test logs no longer line up with the shipped JSON, so they are archived to `logs/<Entity>/_archive_pre_v<ver>/` (legacy: `tests/_archive_pre_v<ver>/`), all SQVR markers reset `[CONFIRMED]→[PENDING]`, STATUS live rows cleared, and `logs/.test_version` stamped. The full test matrix re-runs from Test 1 — never resume mid-matrix across a rebuild. See `knowledge-base/TESTING_REQUIREMENTS.txt` Section 11 GATE 1.

**MANDATORY before presenting any combo test instruction:** Read `docs/<PROVIDER>_METADATA_REFERENCE.txt` for the QIDM being tested. Find the FIELD CONSTRAINTS section (if any) and verify that no combo default triggers a "Must be filled if X = Y" conditional requirement on a field that has no default and no handler. If a violation exists: STOP, fix the build, rebuild, re-import — do not present the test instruction. This gate applies even if the test matrix has been generated and reviewed. (Rule origin: TX_TLETS T6 — DH ImageIndicator=Y default made EmailAddress silently required per devdoc; violation was not caught at metadata extraction.)

**Batch mode** (`-Providers` or `-All`): runs per-provider steps (1-3) sequentially per provider, then ONE sync pass, ONE cross-provider audit, ONE repo audit, ONE enforce. Eliminates redundant global audits when rebuilding multiple providers.

`build_report.ps1` runs 15 steps. Steps 1, 5, 6, 7, 8, 9 always run (read-only on the JSON; core gated outputs). Steps 2 (layout report), 3 (query simulator), and 4 (picklist scanner) — plus 10 (test conductor), 11 (response simulator), 12 (label review), and 13 (officer guide) — are advisory outputs enforce.ps1 (and audit_repo.ps1 Category 10) never require — demoted to opt-in 2026-07-06 (steps 10-13) and 2026-07-06 follow-up (steps 2-4, once Category 10's report-completeness check no longer required them), skipped by default, run via `-IncludeExtended` or the underlying tool standalone. Step 14 (supported-query audit) and 15 (per-provider changelog) always run — both are read by enforce.ps1 (Phase 2e / Phase 3 doc-sync).

`enforce.ps1` runs ~10 phase sections: PHASE 1 (build freshness), 2 (validator scores), 2b (metadata-divergence gate), 2c (structural verify + CAD gates), 2d (simulator parity), 2e (devdoc supported-query gate), 2f (build reproducibility — opt-in via -Reproducible for a full-portfolio run; auto-on for a single -Provider run), 2g (base<->variant lockstep via audit_variant_sync), 2h (combo reachability / dead-combo gate via audit_combo_reachability -- run live per provider; `dead-combo*` accepted divergences report [NOTE] and don't block), 2i (log combo attribution via audit_log_combo_attribution -- replays each log's recorded fill to confirm the named combo is what fired; stale logs on registered dead combos report [NOTE]), 2j (SQVR integrity via audit_sqvr_integrity -- SQVR-named keyRefs must exist in the JSON and stated totals/version must match), 2k (rendered form review via audit_form_review -- ADVISORY; records which build a human actually reviewed), 3 (doc version sync — 8 locations per provider: CLAUDE.md, STATUS, SQVR, JSON_INVENTORY, BUILD_NOTES + date checksum, REBUILD_TRACKER, per-provider CHANGELOG_<PROVIDER>.md, repo-root CHANGELOG.md Current line), 4+5 (cross-provider + repo integrity, run in parallel), 6 (iterate-phase gate + hypothesis quarantine), git status. Exit 0 = verified. Exit 1 = blocked.

**Same-date docs:** the FULL `pipeline.ps1` (not `build_report` alone) is what stamps every doc to the same date in one run — build_report regenerates the 16 report/guide/changelog artifacts, then step 5 `sync_version_docs` stamps STATUS/SQVR/JSON_INVENTORY/CHANGELOG and the BUILD_NOTES date checksum. Running pieces by hand can leave docs on mixed dates; run `pipeline.ps1 -Provider <name>` to refresh them together.

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
- New/rebuilt providers: `<PROVIDER>_v<X.Y>.json` (versioned name is the standard). Bare
  `<PROVIDER>.json` is still accepted (legacy).
- Legacy providers may still have `<PROVIDER>_MC.json` or `<PROVIDER>_BASE.json` until rebuild
- NEVER multiple JSONs in root simultaneously. `Write-ProviderJson` deletes stale siblings on
  build; enforce FAILs if more than one versioned JSON is present.

**docs/ 4-CATEGORY STRUCTURE (rollout, NJ_NJCJIS first, 2026-07-01):** `docs/` splits into
`tracking/`, `reports/`, `reference/`, `deliverables/` (see tree below for what goes where). A
provider is "migrated" once ANY of its 4 category folders exists — `tools/_resolve_docs_path.ps1`
(`Get-DocsCategoryDir`/`Get-DocsPath`/`Find-DocsPath`) resolves every tool's docs/ path
accordingly, falling back to the flat legacy `docs/` layout (unchanged) for any provider that
hasn't migrated. Migrate a provider by `git mv`-ing its existing docs/ files into the 4 category
folders on its next full rebuild — no tool code change needed, the resolver already handles both
states. Do not migrate a provider ad hoc outside of its own rebuild cycle.

```
providers/<PROVIDER>/
├── <PROVIDER>_v<X.Y>.json                 # Current JSON (single, version-named output per provider)
├── docs/                                   # 4-category structure [NJ_NJCJIS pilot 2026-07-01, rolling out]
│   │                                       # (legacy providers: same files, still flat in docs/ directly)
│   ├── tracking/                          # Hand-relevant, updated every version
│   │   ├── <PROVIDER>_STATUS.txt          # USx tenant test matrix + current state
│   │   ├── <PROVIDER>_SQVR.txt            # Supported Query Validation Report
│   │   ├── <PROVIDER>_BUILD_NOTES.txt     # Change log with CHANGED/REASON per version (source of truth)
│   │   ├── CHANGELOG_<PROVIDER>.md        # Auto-generated Markdown changelog (from BUILD_NOTES)
│   │   ├── JSON_INVENTORY.md              # Every JSON version ever produced
│   │   ├── DEX_TICKET.md                  # Jira DEX ticket pointer + changelog dump log
│   │   └── BUILD_MANIFEST_<PROVIDER>.json # Hash-gate manifest (enforce.ps1 trust check)
│   ├── reports/                           # Auto-generated by build_report.ps1, fully reproducible
│   │   ├── VALIDATOR_REPORT_*.txt         # 13 report types + TEST_MATRIX (see Tools table)
│   │   └── ...
│   ├── reference/                         # Derived from metadata XML, semi-static
│   │   ├── <PROVIDER>_METADATA_REFERENCE.txt
│   │   └── <PROVIDER>_SUPPORTED_QUERIES.txt
│   └── deliverables/                      # Officer/tester-facing, not read by tooling logic
│       └── OFFICER_GUIDE_<PROVIDER>.html/.pdf
├── logs/                                  # The ONLY test log location [NJ_NJCJIS pilot, rolling out; tests/ eliminated 2026-07-01]
│   ├── .test_state.json                   # Entity fingerprint/version/block-status (authority; moved from tests/)
│   ├── .test_version                      # Legacy scalar global version (moved from tests/)
│   ├── <PROVIDER>_TEST_PLAN_v<X.Y>.json    # Machine-readable plan for the browser driver (versioned filename — see Versioning Policy)
│   └── <Entity>/                          # One folder per entity (Vehicle, Person, Firearm, Article, Boat)
│       └── <PROVIDER>_v<X.Y>_<Combo>.txt   # Full test log: header stamp + QUERY STRING + COMMSYS XML + RMS QUERY + FIELD ANALYSIS + NOTES + RESULT
├── phases/                                # Version snapshots — LEGACY, being retired provider-by-provider (git history is authoritative); NJ_NJCJIS no longer uses this
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
