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

## Provider Status (updated 2026-09-10)

| Provider | Path | Version | Validator | Tenant test | Notable patterns | History |
|---|---|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS/ | v4.17 | 61P/0F/0W | ALL-PASS 5/5 (39 logs) | VehicleStolenQuery NOT built (USER-APPROVED skip; state auto-runs QV, response data-mined via QRDM); VehReg 2 combos (RANDFULL/RANDFULLN), poisoned-array RandomRequest=Y conditions removed (RandomRequest user-controlled in any[]); DriverLicense 2 combos (FULL/FULLN); PascalCase USx fieldIds (CAD/OnScene), Mark43/RMS keys stay camelCase; CAD combo defaults; NCIC state; shared RMS module, RMS Vehicle stripped to 3 attrs | [changelog](providers/NJ_NJCJIS/docs/tracking/CHANGELOG_NJ_NJCJIS.md) |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v4.20 | 65P/0F/0W | ALL-PASS 5/5 (48 logs) | 6 basic queries (Article/Boat/DH/DL/Gun/VehReg), 12 CommSys combos all reachable (corrected 2026-08-10 — this row said "16" and the SQVR said "17"; both stale, counted from the emitted JSON via `audit_test_coverage`); single JSON; Person 2 cards (Driver License + Driver History, each self-contained w/ own State, DH-suffix, one-directional deselect); Vehicle 1 card (v4.14, collapsed from Search Options/Plate/VIN, OOS-first routing); Boat/Firearm/Article 1 card; Type Code dropdown (VEHICLE_TYPE/HI_NIBRS); ImageIndicator=N combo defaults on all VehReg combos; State in DL/DH any[] + VehReg any[] for OOS; identifier-priority guardrails complete (Plate>VIN, OLN>Name DL+DH, Hull>Reg); Name Last-first (v4.0); DH Attention auto-handler with **NO prefill and NO combo default** (v4.15, DEX-1283) -- `any[]` membership alone feeds `CommsysGetLastNameFirstNameInitialRuleHandler`, LIVE-PROVEN `<Attention>SGAMBELLONE R</Attention>` on 9/9 DH wires; the retired `initialValue='X'` was never the gate-feeder its v2.9 note claimed | [changelog](providers/HI_HCJDC_OFML/docs/tracking/CHANGELOG_HI_HCJDC_OFML.md) |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v4.26 | 76P/0F/0W | ALL-PASS 5/5 (65 logs) | PascalCase, 5 cards (Veh 1, Per 2 [DL+DH], Gun 1, Art 1, Boat 1), 16 combos, 6 QIDMs (DGRP name-search removed v4.11, DEX-1284), DH self-contained w/ own StateDH/ImageDH + OOS combos (DALHOUT/DALLOUT) RegistrationStateDH EXISTS/NOT_EXISTS routing, Vehicle plate OOS combo (RVEHOUT), NyNyspinTransactionName visible on DH (default DALL), PurposeCode default C on DH OOS combos, Choice-set OOS pattern (LIMIT #36), DH-suffix+one-directional queriesToDeselect, CAD defaults, State no-default (LIMIT #30), identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg) | [changelog](providers/NY_NYSPIN_EJUSTICE/docs/tracking/CHANGELOG_NY_NYSPIN_EJUSTICE.md) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v3.12 | 68P/0F/0W | ALL-PASS 5/5 (53 logs) | dexStateUserId hidden badge, DH-suffix isolation, RegistrationStateDH hidden SelH (initialValue AZ), Attention auto-handler (CommsysGetLastNameFirstNameInitialRuleHandler), KeepSsn, invented keyRefs (ACVRV/DQN/KQH), existence-gate identifier-priority guardrails + badge-present gates, 6 QIDMs (WMPI Wanted/Missing removed v3.3 -- not devdoc-Basic). Person 2 cards (DL+DH), Vehicle/Boat 1 card each | [changelog](providers/AZ_AZDPS/docs/tracking/CHANGELOG_AZ_AZDPS.md) |
| FL_FCIC | providers/FL_FCIC/ | v7.24 | 91P/0F/0W | ALL-PASS 5/5 (104 logs) | 1-card Vehicle + 1-card Boat (both collapsed from 2), Person(DL+DH OOS-only). Devdoc combo order + EXISTENCE-ONLY routing conditions (State NOT_EXISTS / OLN NOT_EXISTS / RelatedHit NOT_EXISTS) for first-match + pool isolation; ALL value-comparison conditions removed (poisoned-array rule, QIDM_REFERENCE Sec 2a); DH KQ out-of-state only; DH+Boat destination state = NCIC dropdown; Boat QB stolen routing via relatedHitSearchIndicator in set[]; identifier-priority guardrails complete (Plate>VIN, OLN>Name, Hull>Reg); Attention auto-populated (handler); RMS Vehicle stripped to 3 attrs | [changelog](providers/FL_FCIC/docs/tracking/CHANGELOG_FL_FCIC.md) |
| TX_TLETS_CCH | providers/TX_TLETS_CCH/ | v1.18 | 113P/0F/0W | NEVER 0/5 | Separate CCH-gated provider. Base 6 QIDMs identical to TX_TLETS main. All 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) on Person, autoSelect=false (named-checkbox via queryLabel), every CCH field CCH-suffixed (full isolation, zero collision), 3 CCH cards. Synthetic keyRefs (QR/QWI/ZR) + Choice splits; QH 5 combos (BDOB/NAME.SSN/NAME.MISC/SID/FBI -- NAME split to honor the mandatory SSN\|Misc Choice, v1.5). FreeText capped display. CCH response QRDM out of scope. **TESTING PARKED (Rob 2026-08-21)** -- proof of concept for parallel base+variant building; no tenant need. Marker: `docs/tracking/TEST_PARKED.txt`. Lockstep with TX_TLETS is NOT parked | [changelog](providers/TX_TLETS_CCH/docs/tracking/CHANGELOG_TX_TLETS_CCH.md) |
| TX_TLETS | providers/TX_TLETS/ | v4.22 | 80P/0F/0W | ALL-PASS 5/5 (98 logs) | 6 cards (Veh 1, Per 2 [DL+DH], Gun 1, Art 1, Boat 1 -- corrected 2026-08-02, was "7 cards / Per 3 [Options+DL+DH]" describing the retired 3-card Person design; counted from the emitted JSON), 19 CommSys combos, 6 QIDMs, PascalCase, identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg), QV plate/VIN subset-shadows removed (v4.9), in/out State-gated (FL pattern), MessageKey on DL, DH merged (Image=Y triggers Reason+Email trio, both auto-populated via hidden gate-feeders), CAD plate defaults (PlateYear/PlateType on REG/RQ, FRT=E on REG/VIN), DH-suffix+one-directional queriesToDeselect, TX-specific (DPSI/REG/VIN+FRT), -SkipRace on RMS | [changelog](providers/TX_TLETS/docs/tracking/CHANGELOG_TX_TLETS.md) |
| LA_LEMS | providers/LA_LEMS/ | v3.2 | 65P/0F/0W | NEVER 0/5 | DH-suffix+queriesToDeselect, Attention auto-handler (AP #27, feeder pattern), DP/DQ routing toggle, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/LA_LEMS/docs/tracking/CHANGELOG_LA_LEMS.md) |
| CA_CLETS | providers/CA_CLETS/ | v2.27 | 79P/0F/0W | ALL-PASS 5/5 (99 logs) | purposeCode (CAD-aligned fieldId), DH-suffix fieldIds, cross-entity Name on Veh/Gun/Boat, no ImageIndicator, 6 basic queries, yyyyMMdd dates, CAD defaults on IA.QV. DL: 8 combos (NLTS.DQ.N/DQ + IR.QVC.N/O/C/S + in-state ID.L1/IN.L1). RegistrationState EXISTS guards all NLTS combos. OLN cascade: OLN+State->NLTS.DQ, OLN+CII->IR.QVC.O, OLN-only->ID.L1. Name cascade: Name+State->NLTS.DQ.N, Name+Sex->IR.QVC.N, Name-only->IN.L1. CII->IR.QVC.C, SSN->IR.QVC.S. | [changelog](providers/CA_CLETS/docs/tracking/CHANGELOG_CA_CLETS.md) |
| CA_VENTURA_COUNTY | providers/CA_VENTURA_COUNTY/ | v2.5 | 82P/0F/0W | NEVER 0/5 | 6 basic queries, CaRequestPurposeCode (visible Inp), DL+DH DH-suffix+queriesToDeselect, cross-entity (IN.VP/IG.QGH/NLTS.BQ.N), Attention auto-handler, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/CA_VENTURA_COUNTY/docs/tracking/CHANGELOG_CA_VENTURA_COUNTY.md) |
| CA_CONTRA_COSTA | providers/CA_CONTRA_COSTA/ | v2.4 | 79P/0F/0W | NEVER 0/5 | CA_CLETS twin (6 families / 40 combos / PascalCase / race kept in RMS); JAWS+SuperQuery unbuilt-in-metadata; RequestingAgencyId only on the (unbuilt) JAWS combos | [changelog](providers/CA_CONTRA_COSTA/docs/tracking/CHANGELOG_CA_CONTRA_COSTA.md) |
| CA_CLETS_OCATS | providers/CA_CLETS_OCATS/ | v2.12 | 66P/0F/0W | ALL-PASS 5/5 (62 logs) | CLETS_OCATS v21, 5 basic queries (no DH), VP owner search, CaRequestPurposeCode on all combos, OCATS-specific queries (warrants/juvenile/LARS) available-not-built | [changelog](providers/CA_CLETS_OCATS/docs/tracking/CHANGELOG_CA_CLETS_OCATS.md) |
| CA_eSUN | providers/CA_eSUN/ | v3.3 | 79P/0F/0W | ALL-PASS 5/5 (74 logs) | 6 QIDMs, CaRequestPurposeCode (visible Inp, officer-selectable), VP owner search, gun-by-name (QGH), Attention auto-handler, DL+DH DH-suffix+queriesToDeselect (visible DH cards), OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/CA_eSUN/docs/tracking/CHANGELOG_CA_eSUN.md) |
| CA_SAN_LUIS_OBISPO | providers/CA_SAN_LUIS_OBISPO/ | v2.8 | 67P/0F/0W | NEVER 0/5 | Regional interface (not direct CLETS), DL+DH DH-suffix+queriesToDeselect, short keyRefs, no State initialValue (LIMITATION #30 in/out split), no ImageIndicator | [changelog](providers/CA_SAN_LUIS_OBISPO/docs/tracking/CHANGELOG_CA_SAN_LUIS_OBISPO.md) |
| IL_LEADS_OFML | providers/IL_LEADS_OFML/ | v2.8 | 61P/0F/0W | ALL-PASS 5/5 (43 logs) | 5 basic queries (no DH), Z2/Z5 keyRefs, CDCName in AUTH, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails | [changelog](providers/IL_LEADS_OFML/docs/tracking/CHANGELOG_IL_LEADS_OFML.md) |
| MD_METERS | providers/MD_METERS/ | v2.4 | 71P/0F/0W | ALL-PASS 5/5 (47 logs) | 6 basic queries, DH-suffix+queriesToDeselect, ZVEH/ZLRG/ZWAR/ZLDR/ZDRV/ZBOA keyRefs, OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails, State no-default; **DL State-as-discriminator (v2.4)** -- `RegistrationState NOT_EXISTS` on ZWAR.N ONLY, and the `raceCode NOT_EXISTS` gates on ZLDR.N/ZLDR.O are GONE. Metadata scopes `RaceCode` to both ZWAR variants and NEITHER ZLDR variant, and `ZWAR{Name}` defines no State field at all -- so at v2.3 a Name+Sex+DOB+Race+**State** fill matched ZWAR.N and the State was silently discarded, while `OLN+Race` matched NOTHING. ⚠️ **Do NOT "complete the symmetry" by adding `RegistrationState EXISTS` to ZLDR.N** -- simulated and rejected: it kills the plain in-state name search (`Name+Sex+DOB` -> nothing fires), the TN_TIES `KQ.N` defect verbatim. `ZLDR{Name}` carries State in `<Any>` (an optional, not a state FORK). All 8 DL fills verified routing on the emitted v2.4. Also v2.4: ZGUN `primaryFieldReference` aligned `GunSerialNumber` -> `GunMake` (label only, no wire change) which cleared a live `audit_metadata` CHECK 5 FAIL that a registry row with an inert rule name had failed to suppress; **`ImageIndicator` is `'Y'` on all 3 carrying entities (Boat/Person/Vehicle)** — this cell called MD "the last portfolio `ImageIndicator='N'` carrier (N=6/Y=3)" until 2026-09-08, and a node-level census of all 20 JSONs measured **Y=40 / N=0 portfolio-wide**; the flag closed at MD **v2.1** per `REVERSE_PROPAGATION_LOG.md` | [changelog](providers/MD_METERS/docs/tracking/CHANGELOG_MD_METERS.md) |
| OH_LEADS | providers/OH_LEADS/ | v2.11 | 78P/0F/0W | ALL-PASS 5/5 (65 logs) | 6 basic queries, 7 VehReg combos (9 metadata, 2 NCIC shadows dropped) + owner SSN/Name cross-entity, DH-suffix+queriesToDeselect, Attention eSUN feeder, existence-only routing gates, identifier-priority guardrails (Plate>VIN>SSN>Name, OLN>Name, Hull>Reg), State no-default; NCIC Image defaults `'Y'` on all 3 carrying entities (v2.5, Rob's rule -- safe here because ImageIndicator is in NO `set[]` and no condition, unlike AZ/LA); **ImageQuery (devdoc-Basic) REMOVED v2.6 BY DIRECTIVE** -- user-approved skip, registered `ImageQuery \| (devdoc #1) \| OperatorLicenseNumber \| devdoc-combo-unbuilt`, so 6 QIDMs not 7. Photos still ride IN-BAND via `ImageIndicator` on DQ.O; the standalone "Driver Photo" transaction is gone. It was BUILT at v2.4 to satisfy `audit_supported_queries` CHECK 0 and the directive SUPERSEDES that -- a documented skip satisfies CHECK 0 equally, so do NOT re-add it to green a gate. CHECK 2's `supported 'Driver Photo \| OperatorLicenseNumber' has NO combo` WARN is EXPECTED and deliberately not silenced (deleting the row would falsify the devdoc ground truth CHECK 0 compares against); enforce does not escalate it | [changelog](providers/OH_LEADS/docs/tracking/CHANGELOG_OH_LEADS.md) |
| NM_NMLETS_OFML | providers/NM_NMLETS_OFML/ | v2.7 | 65P/0F/0W | ALL-PASS 5/5 (36 logs) | 6 basic queries, DH-suffix+queriesToDeselect, GunModel field, existence-only routing gates (Vehicle/Boat NCIC-vs-Nlets by State), identifier-priority guardrails, DH PurposeCode+RaceCode optional any[] | [changelog](providers/NM_NMLETS_OFML/docs/tracking/CHANGELOG_NM_NMLETS_OFML.md) |
| OR_LEDS | providers/OR_LEDS/ | v2.6 | 55P/0F/0W | ALL-PASS 5/5 (27 logs) | 5 basic queries (no DH), invented keyRefs (RQ/DQ/QG/QA/BQ splits), OOS EXISTS/NOT_EXISTS gates, identifier-priority guardrails, MC multi-card | [changelog](providers/OR_LEDS/docs/tracking/CHANGELOG_OR_LEDS.md) |
| TN_TIES | providers/TN_TIES/ | v2.6 | 73P/0F/0W | ALL-PASS 5/5 (67 logs) | 6 basic queries, 22 combos (8 Veh incl. Dealer/Handicap/Temp specialty, 5 DL, 3 DH, Gun/Article/Boat), no State initialValue (LIMITATION #30), DH-suffix + queriesToDeselect, Attention auto-handler feeder, existence-only OOS gates + identifier-priority guardrails | [changelog](providers/TN_TIES/docs/tracking/CHANGELOG_TN_TIES.md) |

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

**LOCKSTEP INCLUDES THE ADJUDICATIONS, NOT JUST THE BUILD (2026-08-24).** A variant inherits the base's QIDMs, devdoc and metadata -- so it inherits the base's REASONING about them too. `TX_TLETS_CCH` was in perfect build lockstep (marker current at v4.21, `audit_variant_sync` CHECK 1 `[PASS]`) while carrying a stale subset of `TX_TLETS`'s `ACCEPTED_DIVERGENCES`: 8 base rows absent, 4 of them re-raising OVER-PERMITTED findings the base closed on 2026-07-30 against the SAME byte-identical metadata XML. **When the base bumps, propagate its registry rows for base-6 combinations as well as its combos** -- copy them VERBATIM (reason text + original date) so the evidence travels, or record a comment in the variant's own registry naming the keyRef and field saying why not. `audit_variant_sync` CHECK 2 now gates this. **Copying is not automatic:** an existence-class row (`shadow`/`unbuilt`/`dead-combo`) suppresses a whole keyRef comparison, so measure branches-compared before and after -- one such row cost a branch (36 -> 35) even though its keyRef is not built in the variant.

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

Full reference: `knowledge-base/PLATFORM_CONSTRAINTS.txt` (22 APs + 27 LIMITATIONs, non-contiguous AP #2-#27 / LIMITATION #1-#40, with cross-reference index).

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
| NCIC_FIREARM_MAKE | NCIC **or NJ_NIBRS** | FIREARM makes only. NOT vehicle makes (AP #24). **NJ_NIBRS is also valid for this category -- LIVE-PROVEN, not assumed:** NJ_NJCJIS pairs it with NJ_NIBRS on its GunMake dropdown and the officer selected a value in tenant tests (`providers/NJ_NJCJIS/logs/Firearm/NJ_NJCJIS_v4.15_QG_af_GunMake.txt` and `_QG_any.txt`, form='03' -> wire='03'). An empty dropdown cannot be filled, so those logs prove the source resolves. Recorded 2026-08-02 after a code-type sweep flagged the pairing as suspect against this table; the table was incomplete, the build was right |
| VehicleType | **VEHICLE** | QRDM response **vehicle make** lookup (VehicleMakeName). Vehicle codes live in the `VehicleType` table under the `VEHICLE` source (user-verified vs platform registry 2026-06-24). NOT NCIC_FIREARM_MAKE. |
| NCIC_FIREARM_CALIBER | NCIC | FormInput also valid |
| NCIC_ARTICLE_TYPE | **CA_CLETS** | NCIC gives empty dropdown |
| YES_NO_UNKNOWN | **NCIC** | Y/N only. NIBRS adds Unknown (3 options) |
| NIBRS_SEX | NIBRS | DO NOT use attributeTypeId=SEX (see Sex Code section) |
| NIBRS_RACE | NIBRS | DO NOT use attributeTypeId=RACE. NCIC = empty dropdown |
| NJ_NIBRS_STATE | NJ_NIBRS | For OOS state dropdowns |
| VEHICLE_BODY_STYLE | Provider-specific | NJ=NJ_NIBRS, CA=VEHICLE. NCIC = empty. ⚠️ **OPEN, do not "fix" on this row alone:** a sweep on 2026-08-02 found the built state is uniformly `VEHICLE_BODY_STYLE\|NJ_NIBRS` in the `<PROVIDER>_Results` QRDM of **all 20 providers** (it comes from the shared `Build-CommsysQrdm`, hence identical everywhere), which contradicts the CA=VEHICLE note above. Whether an NJ_NIBRS source resolves off-NJ is **UNVERIFIABLE from the repo** -- QRDM lookups resolve platform-side into the RMS UI and never appear in the captured wire response, so no committed log can settle it. STATUS: HYPOTHESIS. Discriminating test: import one non-NJ provider and check whether a response body style renders or comes back blank. Changing 19 providers off a doc line would be exactly the unverified churn the hypothesis gate exists to stop |
| -- | **attributeTypeId** | -- |
| VEHICLE_MAKE | NCIC (via attributeTypeId) | **MUST be FormSelect (Sel) wherever the field is built.** Dropdown works. NEVER use FormInput. Confirmed USx-tenant-tested: FL, CA_CLETS, TX, NY -- but read that narrowly: it confirms the dropdown POPULATES and a value can be SELECTED, **not that a valid code reaches the wire.** ⚠️ **It does not: see LIMITATION #38.** Those same four providers all transmit `<VehicleMakeCode>CNST_FORD</VehicleMakeCode>` (the raw attribute code) where FL metadata requires the first four characters to be a valid code-manual code. **PARKED by Rob 2026-08-03** ("the drop down is what it is for now") -- all 20 providers build it, so a fix is a portfolio-wide bump archiving 324+ logs. Do not "discover" this again. **NOT ALL PROVIDERS CARRY IT** -- NJ_NJCJIS and HI_HCJDC_OFML build NO VehicleMakeCode field at all (verified 2026-08-01: absent from form AND every QIDM; neither provider's devdoc COMBINATIONS require it, and the devdoc's other mentions are response/field-definition tables). The earlier "Confirmed: NJ" claim here was wrong -- NJ has no such field to have confirmed. Consequence: verify_build's VehicleMakeCode check is VACUOUS on those two, and audit_gate_efficacy's `vehiclemake-as-input` mutation reports N/A there by design. |

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
Three requirements (all must be met): QIDM attribute `size=1`, FormSelect `initialValue='Y'`, field listed in set[] or any[].

**`initialValue='Y'` ON EVERY ENTITY — rule changed 2026-08-12 (Rob).** This line used to read "'Y'
(or 'N' for vehicle)", and `audit_cross_provider` enforced `'N'` on Vehicle, so FL_FCIC v7.21 — the
first build to follow the new rule — was reported as the defect. Rob's ruling: *"ncic image should
default to y everywhere ... this should not generate a warn when its the proper way to do this.
whatever is triggering the warning needs to be fixed."* The gate was encoding the old convention and
was changed to expect `'Y'` on Vehicle, with **both safety guards kept** (they had to be hoisted out
of the Person block first, or Vehicle would have gained a wrong-but-quiet check):
- **In a `set[]` and NOT prefilled → PASS.** The field is a routing DISCRIMINATOR; a prefill collapses
  its combo onto a plainer sibling (AZ_AZDPS v3.7 killed DQN/DQ/BQ/BQH exactly that way). **This is why
  "everywhere" is not mechanical** — AZ_AZDPS has ImageIndicator in 2 `set[]`s and LA_LEMS in 1 `set[]`
  + 2 conditions, so those two need a ruling, not a flip.
- **Prefilled AND gated `NOT_EXISTS` → WARN** (BUILD_RULES 20b, permanently dead branch).
- Pair the form `initialValue` with a matching combo `defaults[]` on every carrying combo: CAD ignores
  form `initialValue`, so a form-only flip leaves CAD-originated queries still sending the old value.

Rollout: FL_FCIC v7.21 first, then IL_LEADS_OFML v2.4 and HI_HCJDC_OFML v4.17, each at its OWN
rebuild (rule 8c). Remaining flag-carriers WARN here — that is correct signal, not noise.

**"EVERYWHERE" IS 14 PROVIDERS, NOT 20 — measured 2026-08-14, and the flag was flagged to `all`
mechanically before anyone counted.** Of 20 providers, **6 build NO `ImageIndicator` control at all**
(CA_CLETS + CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY — verified
absent from every QUERYINPUTFORM *and* every QIDM), so the rule is NOT-APPLICABLE there; adding
controls to satisfy it would OVER-PERMIT, the same adjudication that scoped HI to Vehicle-only and
excluded IL's Article. A further **3 have exactly one Person control already at `'Y'`**
(NM_NMLETS_OFML, OR_LEDS, TN_TIES) and are therefore already conformant — there is no second entity
to set. **All 9 retired 2026-08-14 with Rob's approval, plus AZ_AZDPS** (below), taking live flags
16 → 7 with zero JSON change, zero version bump and zero test package archived.

**AZ_AZDPS IS RULED OUT AND IT WAS MEASURED, NOT ARGUED.** `ImageIndicator` sits in **2 `set[]`s**
there (`DQPN`/`DQP`, the licence-photo paths) while `Requestor` and `dexStateUserId` are both hidden
AND prefilled. v3.10 injected `'Y'` and rebuilt: `DQPN` collapsed to `[NameLast,NameFirst]` (= `DQN`)
and `DQP` to `[OperatorLicenseNumber]` (= `DQ`), killing **both plain searches** — BUILD_RULES 24.
Rob's rule carries its own caveat (*"if it does not effect routing"*) and on AZ it does, so the blank
is load-bearing: it is what keeps the photo path OPT-IN.

**NOTHING IS OWED — CLOSED, MEASURED 2026-09-08. THIS LINE SAID "2" AND HAS NOW GONE STALE TWICE.**
It previously said "7", was corrected to "2" on 2026-08-18, and was stale again by three MD_METERS
versions. A **NODE-level census of every `ImageIndicator` control in all 20 emitted JSONs** reads:

> **Y = 40 · N = 0 · blank = 0 · no-`initialValue`-property = 2 · providers with NO control = 6 of 20**
> `STILL CARRYING 'N': NONE.`

MD_METERS — named here as "the last carrier" and as a wire change still owed — reads
**Boat=Y Person=Y Vehicle=Y** at v2.4. The 2 without an `initialValue` property are AZ_AZDPS's
Person control (**the load-bearing blank**, see the AZ ruling above — it is in 2 `set[]`s, so a
prefill kills `DQPN`/`DQP`) and TX_TLETS_CCH's `imageIndicatorCCH`.

**Corroborated from the authority for flag state, not from the same probe:** no provider carries a
LIVE `[FLAG:ncic-image-default-y-everywhere]` (all 16 mentions are retired comment records), and
`REVERSE_PROPAGATION_LOG.md` records *"RESOLVED at MD_METERS v2.1 — and MD_METERS WAS THE LAST
CARRIER, so this portfolio flag is now fully closed."* **LA_LEMS needs no ruling either:** it builds
ONE control, on Person, already `'Y'` — the same already-conformant class as NM/OR/TN.

⚠️ **A STALE *OWED* CLAIM MANUFACTURES WORK, which is the exact mirror of a stale DO-NOT-RE-RAISE
suppressing it** (the failure SESSION_STATE records for `[FLAG:plan-dedupe-vacuous-tests]`). This
line survived two corrections and presented finished work as outstanding on a tenant-verified
provider for three weeks. Found 2026-09-08 by a random fuzz mutation prefilling MD's Vehicle
control, which forced a measurement of what the value actually was.

⚠️ **The OLD measuring probe under-reported and must never be used as a control census:** it matched
an `initialValue` within 900 chars of the `fieldId`, so a deliberately BLANK control was invisible —
which is why AZ_AZDPS read as having none. **Read NODES** (`props.fieldId` + `props.initialValue`,
with `hidden` at node level), and report a blank as `(blank)` rather than as absent.

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
| ImageQuery | Driver Photo |
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

## Tools (107 scripts + 18 shared modules in `tools/`, + `tools/_probes/` (8 graduated ad-hoc probes) + `tools/config/` (7 JSON reference tables, incl. `tenant_map.json` -- the canonical subdomain <-> deptId <-> ledger-name join) + 3 archived tools in `tools/_archive/`)

All tools are provider-agnostic. `banned_patterns.txt` is the only non-script (consumed by verify_build.ps1).

⚠️ **THE TABLES BELOW ARE AN INDEX, NOT THE REASONING.** Each row is one line — purpose + key
flags. The WHY behind every gate (the incident that produced it, the traps that make its PASS
mean less than it looks, the baselines, the "do NOT simplify this" warnings) lives in
**`knowledge-base/TOOL_REFERENCE.txt`**, relocated there VERBATIM on 2026-09-08. Reason: this file
had reached 156,874 chars against a **150,000-char load limit** and the Tools section alone was 53%
of it, so the TAIL of this file — the new-provider Quick Start, whose Step 0 is the naming gate —
was at risk of never reaching context. Nothing was deleted. **Read `TOOL_REFERENCE.txt` before
changing a gate, when judging whether a PASS is evidence, or when a finding looks novel.**

Shared modules (dot-sourced, `_`-prefixed): `_build_rms_bundle.ps1`, `_build_layout_helpers.ps1`, `_build_provider_helpers.ps1`, `_json_canonical.ps1`, `_resolve_provider_json.ps1` (active-JSON resolver `Get-ProviderRootJson` — bare → versioned → `_MC` → `_BASE`), `_resolve_provider_xml.ps1` (metadata-XML resolver `Get-ProviderMetadataXml` — exact `<PROVIDER>.xml` → base provider's XML for a variant → the only XML present → `$null` + warning; **refuses to guess between multiple candidates**, because an alphabetical glob made a gate read CA_CONTRA_COSTA's 6-node JAWS-only excerpt instead of the real 466-node metadata and report green — see `knowledge-base/README.txt`).

**`_probe.ps1` — THE PROBE HARNESS (added 2026-09-01).** Primitives for answering an ad-hoc question without re-deriving what is easy to get wrong; it THROWS rather than returning an empty result. A probe is a `.ps1` that dot-sources this module, NEVER a bash one-liner — that deletes the shell-boundary defect class by construction. ⚠️ Never dot-source it from a gate or orchestrator. Full rationale, the twelve historical slips it exists to prevent, and the export list: `knowledge-base/TOOL_REFERENCE.txt`.

### Core Build Pipeline (run every build via build_report.ps1)

| # | Tool | Purpose | Key flags |
|---|---|---|---|
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos); also flags a top-level `version` field (platform-reject) and a CommSys `codeTypeProvider` reverse-lookup vs the code-string field (AP #11, CommSys direction). **PLATFORM DESERIALIZATION SHAPE now covers the QIDM subtree too (2026-09-10)** — `requirements.set/any/conditions` and a condition's `field` must be ARRAYS, `keyReference` a STRING. It already did this for the Craft.js layout (`templateColumns` must be an array of strings) and the top-level `version`, but never for combinations — which is exactly where CA_eSUN v3.0/v3.1 shipped `"conditions": {...}` and the platform rejected the whole file (`Cannot deserialize ArrayList<Combination$Condition> from Object value`) with ~40 gates green. Cause: a PowerShell helper returning ONE object unwraps to a scalar. FAIL-only, so it adds no PASS line and moves no score (verified: all 20 providers' P counts unchanged). ⚠️ Validates against OUR recorded expectations, NOT the platform's schema — the only true test of deserializability is an import | `-Path <json>` `-ShowDetail` |
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
| -- | `build_report.ps1` | **Master orchestrator** — always runs 1, 5-9 + saves reports to docs/, then prunes orphaned variant reports (build-owned report files for a JSON variant no longer present — e.g. after consolidating branches). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-IncludeExtended` |

### Auditors (repo-wide checks)

| Tool | Purpose | Key flags |
|---|---|---|
| `enforce.ps1` | **MANDATORY FINAL GATE** -- runs ALL checks (build freshness, validator scores, doc sync, cross-provider, repo audit, git status) | `-Provider <name>` `-SkipGit` `-Rebuild` `-Reproducible` `-OutFile` |
| `audit_reproducible.ps1` | Proves committed JSON == a fresh build: runs the build script twice into scratch (via $env:REPRO_OUTPATH hook), checks DETERMINISM + CURRENCY (version/PlateYear normalized). FAIL=non-deterministic; WARN=stale. Opt-in via `enforce -Reproducible` | `-Path <json>` `-OutFile` `-Strict` |
| `_json_canonical.ps1` | Shared canonical JSON serialization + hashing (ConvertTo-Canonical, Get-Sha256Hex, New-NormalizedClone). Reused by get_entity_fingerprints + audit_reproducible | (dot-sourced) |
| `pipeline.ps1` | **ONE-COMMAND PIPELINE** -- build + report + metadata + sync + version docs + cross-provider + repo audit + enforce in 8 steps; stops on first failure | `-Provider <name>` (required) `-SkipBuild` `-SkipEnforce` |
| `doctor.ps1` | **ONE-SHOT HEALTH DASHBOARD** -- read-only snapshot: score_all -Quick + poisoned-array sweep (validate G-31) + git status + reverse-propagation status + variant sync + PS-5.1 parse + **suppression scope / tool portability / provider linkage** (the three. See `knowledge-base/TOOL_REFERENCE.txt`. | `-SkipPoison` `-OutFile` |
| `flag_pending_fix.ps1` | **REVERSE-PROPAGATE** a shared-module/JSON fix as a doc-stub flag: writes `[FLAG:<id>]` into each still-pending provider's PENDING_UPDATES.txt (blocks enforce PHASE 1 until rebuilt; build script clears it) + appends a REVERSE_PROPAGATION_LOG.md row. Idempotent. | `-FixId` `-Description` `-Providers <list\|all>` `-Origin` `-Date` `-DryRun` `-OutFile` |
| `audit_reverse_propagation.ps1` | Portfolio status view: reads every PENDING_UPDATES.txt + REVERSE_PROPAGATION_LOG.md, reports which providers are pending/propagated per fix + gaps. Informational (enforce PHASE 1 is the gate); composed into doctor.ps1 | `-OutFile` |
| `audit_variant_sync.ps1` | Base↔variant lockstep drift check. For each provider declaring `# BASE-SYNC: <BASE> vX.Y` in its build script (marker-driven, no name-heuristic false positives), flags drift if the marker is behind the base's current version. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <dir>` `-OutFile` |
| `emit_decision_trail.ps1` | **THE REASONING POINTER FOR A RESTARTED SESSION** — third SessionStart hook, injected after `SESSION_STATE.md`. That file restores STATE and `usx-resume` restores ENVIRONMENT, so a new session knows *where* things stand. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Count <n>` `-Lessons <n>` |
| `audit_query_selectable.ps1` | **CAN THE OFFICER ACTUALLY SEND EVERY QUERY WE BUILT?** (enforce PHASE 2y, BLOCKING) — every other gate validates the REQUEST; none asked whether the query can be SELECTED at all. `autoSelect=$false` makes the platform render a query's checkbox and never ACTIVATE it, so Send stays DISABLED: CA_eSUN v3.0/v3.1/v3.2 shipped that on DriverHistoryQuery and 13 of 13 DH tests could not send while ~40 gates read green. ⚠️ **"assert `$true`" IS THE WRONG GATE, measured before writing it:** 8 of 124 QIDMs legitimately carry `$false` (all TX_TLETS_CCH CCH transactions — opt-in by design) and are MECHANICALLY IDENTICAL to the bug, so the gate demands a **declaration** (`<Query> \| * \| autoSelect \| opt-in-query`, classified `selectability`). ⚠️ **ABSENT ≠ FALSE:** the first cut failed on not-`$true` and raised 67 findings across 13 mostly-ALL-PASS providers; **44 of 44** absent-autoSelect queries on tenant-verified providers hold logs, so absent is the platform default and IS sendable — do NOT re-tighten. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Path <json>` `-All` `-Quiet` `-OutFile` |
| `audit_wiring_closure.ps1` | **FORM <-> QIDM WIRING CLOSURE** — the direction nothing else checks. Every other gate validates the REQUEST against an AUTHORITY (devdoc, metadata, reachability, logs). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-All` `-Quiet` |
| `audit_name_components.ps1` | **METADATA COMPONENT -> FORM CONTROL COVERAGE** — the authority→built direction at COMPONENT granularity, and the twin nobody built. `audit_devdoc_combinations` closes this gap for COMBINATIONS. ⚠️ **SCOPE IS DERIVED — do not "simplify" to a name whitelist.** `First+Last+Middle+Suffix` is a GENERIC TYPE SIGNATURE stamped on 100+ non-person fields (`ChemicalName`, `SchoolName`, `AddressStreetName`, `EnhancedNameSearchIndicator`; one is nonsense. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Path <json>` `-All` `-Quiet` `-OutFile` |
| `audit_session_state.ps1` | **SESSION PICK-UP GATE** (enforce 2l) -- verifies `SESSION_STATE.md`, the repo-root pick-up point auto-injected into every new session by the SessionStart hook. See `knowledge-base/TOOL_REFERENCE.txt`. | `-OutFile` |
| `audit_form_review.ps1` | **RENDERED FORM REVIEW** (enforce 2k, ADVISORY) -- records which build a human actually looked at, in `docs/tracking/<P>_FORM_REVIEW.txt`. Every other gate proves the request is correct. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-Record -Reviewer <name>` |
| `audit_sqvr_integrity.ps1` | **SQVR TRUTH GATE** (enforce 2j) -- the SQVR is hand-maintained prose asserting which combos exist/how many/what version, and nothing verified it, so it rotted on every combo add-remove; it's also what a tester reads to decide what to test. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_log_metadata_attribution.ps1` | **WHICH COMBO DOES THE WIRE SAY THIS IS? -- the log-stage direction that closes the feedback loop** (Rob 2026-09-02, during the CA_CLETS_OCATS v2.12 sweep: *"be sure the logs are matched to a query combo independently of the original metadata sweep used to. ⚠️ **THE COMPARISON AXIS IS THE REQUIRED SET, NOT `primaryFieldReference` -- the first draft used PF and produced 22 FALSE DISAGREEs across 4 providers**, the shape that means the probe is broken. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-All` `-Quiet` `-OutFile` |
| `audit_log_combo_attribution.ps1` | **LOG ATTRIBUTION GATE** -- did each saved log's NAMED combo actually fire? The wire XML carries no keyRef, so this was unverifiable and a green package could overstate coverage (17 of 417 logs were filed under combos that never ran, found 2026-07-29). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_combo_reachability.ps1` | **DEAD-COMBO GATE** (fill-independent) -- the platform fires the FIRST matching combo, so combo A is unreachable if a B ordered before it matches whenever A does. Silent case: B's extra `set[]` fields are all form-prefilled (`initialValue`), so B always wins. ⚠️ **Its "N combination(s) checked" is NOT a combo count — never cite it as one.** It reports what it COMPARED, which is systematically lower than the provider's combo total (HI_HCJDC_OFML 10 checked vs 12 combos; IL_LEADS_OFML 7 vs 9). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_prefill_shadow.ps1` | **WHICH PREFILL KILLED THE COMBO** -- BUILD_RULES 24 at the CAUSE, not the consequence. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_gate_efficacy.ps1` | **MUTATION TESTING FOR THE GATES** (LAW 2 -- a gate that cannot fail is not a gate). Injects each known defect CLASS into a throwaway replica and checks the owning gate actually FAILs. KILLED=its PASS is evidence. ⚠️ **`[INVALID]` IS A FINDING, NOT A SKIP -- ENGINEERING_STANDARD 5 requires 0 INVALID as well as 0 SURVIVED, because a step that did not run is not a pass and a STALE MUTATION IS INDISTINGUISHABLE FROM A BLIND GATE.** Fixed 2026-09-02. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Only <substr>` `-OutFile` |
| `fuzz_gate_efficacy.ps1` | **RANDOM mutation testing** -- what the hand-authored catalogue structurally cannot do. Mutation sites are ENUMERATED FROM THE JSON (set↔any, drop, over-permit from a sibling combo, drop-conditions, swap-order, prefill, Select→Input), aimed at nothing. **`-Kinds` AIMS it at specific classes and every run prints a PER-KIND CENSUS (2026-09-08)** -- sampling was not just thin (8 of ~281 sites) but UNEVEN across the 9 kinds, and nothing said which went untouched. Unknown kind, or a kind with 0 sites here, FAILS LOUDLY. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Mutations <n>` `-Seed <int>` `-Kinds <list>` `-OutFile` |
| `audit_log_inflation.ps1` | **COVERAGE-INFLATION ATTACKS** -- every other log gate asks "is what we sent correct?"; none asked "are these N logs actually N DISTINCT tests?". ⚠️ **ITS 2026-07-31 BASELINE OF "0/0/0/0 over 434 logs / 6 providers" WAS TWO KINDS OF FALSE, both fixed 2026-08-18.** (1) **Attack A COULD NOT FAIL.** Every wire carries a unique transaction id. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Providers <list>` |
| `audit_order_risk.ps1` | **THE HONEST ORDERING NUMBER** -- `audit_devdoc_order`'s "mapped N of M" reads as "up to 44% unverified", but LINE 1 (specificity, via reachability) covers every pair. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Providers <list>` |
| `audit_devdoc_combinations.ps1` | **DEVDOC -> BUILT GATE, at COMBINATION granularity** (enforce PHASE 2p / PHASE 1 step 1) -- the one direction no other gate checks. ⚠️ **That zero-compare FAIL was itself VACUOUS on the one provider it caught, and stayed the portfolio's last blocking spec finding for 17 days** — CA_CONTRA_COSTA's devdoc says "Basic Queries Supported. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-All` `-Explain` |
| `audit_devdoc_order.ps1` | **DEVDOC-ORDER TIEBREAKER GATE** (PHASE 1 step 3b) -- line 2 of the ordering rule: when two DIFFERENT queries could both execute on the filled fields, the devdoc-earlier one must fire. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_requirement_fidelity.ps1` | **PER-COMBINATION mandatory/optional fidelity** (enforce PHASE 2s, advisory) -- built `set[]`/`any[]` vs the metadata alternative it implements. Catches UNDER-REQUIRED (a metadata-mandatory field demoted to `any[]` or absent) and OVER-PERMITTED. ⚠️ **The keyRef-wide FALLBACK is deliberate and must NOT be removed:** if the triple ever fails to line up, an EMPTY pool would INVENT an over-permit on every optional, turning a suppression bug into a false-positive storm. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_lifecycle.ps1` | **LIFECYCLE TAIL** (enforce PHASE 2r, advisory) -- stages 5 and 6, previously ungated: the Jira entry and the import record (`IMPORT_LEDGER.md` accounts for the current version, either an install or an explicit not-yet-imported line -- silence is the defect). ⚠️ **It used to be `-match "v$ver"` over the whole file, which COULD NOT FAIL:** every `DEX_TICKET.md` carries a `**Current: v4.19 -- tenant-verified...**` line, so the version was always mentioned. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Strict` |
| `audit_layout_flow.ps1` | **IS THE FORM A PROJECTION OF ITS COMBINATIONS?** — the cosmetic/usability direction nothing covered. `render_layout` renders but has no opinion; `verify_build` CHECK 15 checks label TEXT; `audit_wiring_closure` checks a control *reaches* the wire. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Path <json>` `-All` `-Quiet` `-OutFile` |
| `audit_provider_uniformity.ps1` | **ARE THE FINISHED PROVIDERS THE SAME SHAPE?** — the direction neither structural gate covers. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Providers <list>` `-All` `-Quiet` `-OutFile` |
| `audit_tool_portability.ps1` | **TOOL PORTABILITY SWEEP** — *"shared tools need to work everywhere."* Runs the 12 `-Path`-taking gates against **every** provider and reports whether each can **run and reach a verdict** — not whether it passes. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Only <list>` `-OutFile` |
| `audit_optional_scope.ps1` | **FIX-vs-REGISTER ADJUDICATOR** for "silently not transmitted" findings (advisory, recommends only). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-OutFile` |
| `audit_provider_linkage.ps1` | **PROVIDER LINKAGE GATE** (ADVISORY) — every provider JSON is **standalone**; its build is justified by ITS OWN devdoc (query authority) + ITS OWN metadata XML (field authority). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-OutFile` |
| `audit_buildnotes_fidelity.ps1` | **BUILD_NOTES FIDELITY GATE** — does the current version's BUILD_NOTES entry describe what changed, or is it the stub `pipeline.ps1` stamps (`CHANGED: Rebuilt via pipeline.ps1 / REASON: Scheduled rebuild`)? Built 2026-08-03 after. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-All` `-Quiet` `-OutFile` |
| `audit_registry_currency.ps1` | **REGISTRY CURRENCY GATE** — is each `ACCEPTED_DIVERGENCES` row's **premise** still true? The companion to `audit_suppression_scope`, which asks how *wide* a row's suppression is; this asks whether the condition it describes still exists. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-All` `-Path <replica>` `-Quiet` `-OutFile` |
| `audit_ps51_parse.ps1` | **PS 5.1 PARSE GATE** — every `tools/*.ps1` must parse on the engine that actually runs it. `pipeline`/`enforce` invoke tools as `powershell -File` (5.1). See `knowledge-base/TOOL_REFERENCE.txt`. | `-OutFile` |
| `audit_extension_syntax.ps1` | **EXTENSION JS SYNTAX GATE** (composed into `doctor`) — the PowerShell twin of the row above, for `automation/extension/*.js`, which **nothing parsed** until 2026-09-09. On 2026-09-04 the `usx_lib.js` build tag (a single-quoted `console.log` grown into prose) acquired `initialValue='C'`; that apostrophe closed the literal and **the driver and capture tools were dead for five days**, found only when the operator opened a tenant console. A parse error is TOTAL — `window.__usxLib` is assigned on the line ABOVE the bad one and still never existed, so `capture.js`/`driver.js` logged `usx_lib not loaded` and `ui.js` fell back to a red "NOT a test tenant" banner (two alarming symptoms, one cause). Uses `new Function()`, which **parses without executing**, so a verdict means "valid JavaScript" and not "ran cleanly in this environment" — a page load conflates syntax with runtime throws, and under `file://` Chrome sanitizes the reason to the useless `Script error.`, which is exactly how the real breakage got explained away as an environment artifact. ⚠️ **Must use `Start-Process -RedirectStandardOutput`, never pipeline capture** — Edge detaches when spawned from `powershell.exe` and `& $browser` returns ZERO characters (verified on a one-line page, so not size or timing). A deliberately unterminated string is parsed **on every run** as a self-test: if the control does not fail, the gate reports itself inert (LAW 2). Proven against the real 2026-09-04 file → `[FAIL] usx_lib.js -- missing ) after argument list`, the tenant's exact message. | `-Path <dir>` `-OutFile` `-Quiet` |
| `audit_repo.ps1` | Full monorepo audit (18 categories: banned patterns, versions, docs, structure, cross-provider, camelCase) | `-Category <1-18>` |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase) | `-Path <providers-dir>` `-OutFile` |
| `audit_structure.ps1` | Provider folder structure (naming, required dirs/files, reports, freshness) | `-Path <provider-dir>` `-OutFile` |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphan detection). ⚠️ **Scoped to ALL-PASS providers only** (shared `_test_status_lib` classifier) -- a never-tested provider has zero logs, so gating it would redden 7 providers for work not yet owed, the un-clearable FAIL LAW 2b calls noise. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-Gate` `-OutFile` |
| `report_import_owed.ps1` | **THE IMPORT QUEUE — what is built but not installed.** Rob 2026-08-17: *"you need to alert when a new version is built to prompt for import   iver lost track of all the things you are fixing."* That day **TEN provider versions were bumped in one session**. ⚠️ **`-Since` UNDER-REPORTS and says so in its own output** — it finds bumps via git RENAME detection, so a version swap recorded as add+delete is invisible; measured on 2026-08-17 it found 8 of 10 real bumps and silently omitted CA_CONTRA_COSTA and CA_eSUN. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Since <ref\|date>` `-Quiet` `-OutFile` |
| `audit_change_scope.ps1` | **IS THIS CHANGE INSIDE THE PROVIDER I WAS TOLD TO WORK ON?** Rob 2026-08-18: *"we need to put guardrails around your drift but respect the portfolio implications."* One-provider-at-a-time kept being broken by **accretion, never by decision**. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Allow <list>` `-Ref <ref>` `-Quiet` |
| `report_sweep_ledger.ps1` | **THE SWEEP LEDGER — planned vs logged vs owed, per entity, FROM THE REPO.** Rob 2026-08-18: *"we need to fix this process."* During the TX_TLETS v4.21 sweep the Boat entity was driven (22 submitted) and then **never captured**. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-All` `-Quiet` `-OutFile` |
| `report_mission_status.ps1` | **THE 95% METRIC, COMPUTED INSTEAD OF CLAIMED.** `ENGINEERING_STANDARD` 5.1 defines the mission as 19 of 20 providers LIFECYCLE-COMPLETE (all six stages), and until 2026-08-19 that number lived in PROSE and was recomputed BY HAND. ⚠️ **Its first three runs were wrong and every failure was the probe, not the portfolio**. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Quiet` `-OutFile` |
| `audit_artifact_provenance.ps1` | **IS THIS EVIDENCE, OR SOMETHING SHAPED LIKE EVIDENCE?** The axis none of the other ~40 gates covers: every one of them asks a CORRECTNESS question (does the request match the devdoc/metadata/logs). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Quiet` `-OutFile` |
| `portfolio_status.ps1` | **CANONICAL PORTFOLIO STATUS** -- the single one-screen fixed-column table (Provider / Ver / Meth / Validator P-F-W-LIM / USx-tenant-test state+logs) + totals + git footer. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-OutFile` |
| `report_test_status.ps1` | USx-tenant-test NARRATIVE view (per-entity log counts + PASS/FAIL/PENDING breakdown). Same `_test_status_lib.ps1` classifier as portfolio_status. Reads log RESULT lines, NOT `.test_state.json`. | `-Provider <name>` `-OutFile` |
| `score_all.ps1` | Provider scorecard -- runs validator on all providers, sorted table with rebuild flags. NOTE: its BASE/MC columns show `--` for galvanized single-JSON providers; use `portfolio_status.ps1` for the complete picture. | `-Quick` (parse existing reports) `-OutFile` |
| `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches, AP #21-23) | `-Path <dir>` `-OutFile` |
| `sync_provider_table.ps1` | Auto-updates CLAUDE.md provider table scores from validator reports | `-DryRun` `-OutFile` |
| `sync_version_docs.ps1` | Auto-updates STATUS.txt, SQVR.txt, JSON_INVENTORY.md (versioned filename), REBUILD_TRACKER.md, BUILD_NOTES.txt (date checksum), per-provider CHANGELOG_<PROVIDER>.md, and the repo-root CHANGELOG.md "Current:" line, with current version and scores | `-Provider <name>` `-DryRun` |
| `generate_changelog.ps1` | Renders per-provider `docs/CHANGELOG_<PROVIDER>.md` (Markdown) from `<PROVIDER>_BUILD_NOTES.txt`. Deterministic. Step 16 of build_report; re-run by sync_version_docs | `-Path <json>` `-Provider <name>` `-OutFile <path>` |
| `preflight_rebuild.ps1` | Per-provider rebuild action plan (validator WARNs + linter + flags → checklist) | `-Provider <name>` `-All` `-Quick` `-OutFile` |
| `audit_log_content.ps1` | Saved-log integrity: every test log's QUERY STRING must satisfy its plan test's full fill-set (not identifier-only). NOTE: also prints the log-count vs plan-test-count delta, but PASSes on the logs that exist -- plan completeness is the classifier's job (PARTIAL state) | `-Provider <name>` `-Quiet` |
| `audit_supported_queries.ps1` | DEVDOC GROUND-TRUTH GATE: validates the JSON's built queries against the devdoc "Basic Queries Supported" list (build_report step 14). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-OutFile` |
| `audit_xml_consistency.ps1` | On-demand run-over-run wire-XML regression check (manual; not run by enforce/pipeline/build_report): same combo + same fills must produce identical wire XML run to run. Compares the working tree against a git ref | `-Provider <name>` `-BaselineRef <commit>` `-Quiet` |
| `audit_simulator_parity.ps1` | Guards that test_commsys.ps1 and run_test_matrix.ps1 share one canonical condition-evaluation path | `-Path <json>` |
| `audit_data_mined.ps1` | **DATA-MINED TRANSACTIONS -- what the state runs FOR us, and why that is not an unbuilt gap** (build_phase1 step **5b**, ADVISORY). Two mechanical facts that were invisible to every gate until 2026-08-24: **(1) the keyRef NEVER reaches the wire**. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-All` `-Providers <list>` `-Quiet` `-OutFile` |
| `audit_picklist_scope.ps1` | ADVISORY picklist-scope reminder (never blocks): flags providers missing the one-time TENANT_PICKLISTS.json capture, or carrying a capture that predates a newly-built dropdown CATEGORY. **SWEEP MODE + doctor wiring added 2026-08-21**. ⚠️ **Do NOT re-cut it to per-CONTROL granularity**. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <json>` `-All` `-Providers <list>` `-Quiet` |
| `verify_claims.ps1` | Hypothesis Quarantine Gate: blocks unverified platform-behavior claims from driving churn (must cite committed test logs). Repo-wide -- takes NO -Path (passing one is silently ignored) | `-OutFile <path>` |
| `get_entity_fingerprints.ps1` | Computes per-entity canonical fingerprints (via _json_canonical) for test-state tracking / block_entity | `-Path <json>` |

### Metadata & Extraction

| Tool | Purpose | Key flags |
|---|---|---|
| `extract_metadata_reference.ps1` | Generates METADATA_REFERENCE.txt from XML + JSON (field definitions, combo requirements, coverage) | `-XmlPath <xml>` `-Path <json>` `-OutFile` `-All` |
| `extract_queries.ps1` | Parses metadata XML into SQVR-ready tracking file | `-XmlPath <xml>` `-OutFile` |
| `diff_docs.ps1` | Diffs updated engineering docs against KB files (NEW/REMOVED/CONFIRMED per category) | `-NewDoc` `-KbFile` `-OutFile` `-Provider` |
| `check_test_preconditions.ps1` | Cross-checks combo defaults against devdoc conditional field constraints (the "Must be filled if X=Y" gate). WARN-ONLY, always exits 0 (pipeline treats it as advisory). See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-Query <name>` `-FromHook` |

### Provider Lifecycle

| Tool | Purpose | Key flags |
|---|---|---|
| `new_provider.ps1` | Scaffolds new provider (canonical structure, build scripts, doc templates, tool registrations) | `-XmlPath <xml>` `-PdfPath` `-Force` |
| `emit_test_plan_spec.ps1` | **SPEC-DERIVED TEST PLAN** -- generates the plan from the DEVDOC + METADATA, not the built JSON, so it is an INDEPENDENT statement of what the provider should do rather than a mirror of what we built (a mirror can only confirm what is there: no combo -> no. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-DryRun` |
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
| `import_picklists.ps1` | Merges usx_picklists_*.json downloads into docs/reference/TENANT_PICKLISTS.json + validates current test values. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <download>` |
| `ingest_tenant_export.ps1` | **WHICH VERSION IS ACTUALLY INSTALLED ON A TENANT** — read from the platform rather than inferred from `logs/`. Reads the extension's `usx_admin_export_*.json`, extracts the embedded full config to `_versions/tenant_exports/`, and pulls provider + version from the bundle description, cross-referencing the repo's current version. ⚠️ **The admin bundle table's `Version` column is a PLATFORM COUNTER, not ours** (eSUN's reads 590/48/70 at v3.3) — it cannot answer this; the **Export JSON** control can, because our version rides in the bundle `description`, a convention that exists only because the platform rejects a top-level `version` field. ⚠️ `-Diff` reports hash difference as **EXPECTED** (the platform re-serializes: 246KB export vs 928KB repo at the same version); only equality would be surprising. 0 files FAILs rather than passing quietly. First result: dept 69510509021 = CA_eSUN tenant v3.3 == repo v3.3. See `knowledge-base/TOOL_REFERENCE.txt`. | `-All` `-Path <file>` `-Diff` `-OutDir <dir>` `-Quiet` |
| `ingest_tenant_scan.ps1` | **WHICH TENANTS HAVE A PROVIDER JSON WE DO NOT KNOW ABOUT?** Rob 2026-09-10: *"the goal is to uncover any json imports that we do not know about"* -- and, immediately after, *"well also verifiying the known ones that proved useful here"*. Reads the extension census chunks (`usx_admin_scan_<from>-<to>_*.json`), classifies every tenant carrying a non-ENTITIES/non-RMS bundle as KNOWN-FLEET (`usx-*`) / KNOWN-LEDGER (IMPORT_LEDGER section B) / **UNKNOWN**, and separately flags any bundle NAME that is not one of our 20. WARNING: refuses three conflations that each produced a wrong answer the same day -- **unresolved is not empty**, **a missing chunk is not an empty range** (it names the uncovered index offsets), and **no version is claimed** (the bundle-table Version column is a platform counter; versions come from `ingest_tenant_export.ps1`). 0 chunk files FAILs rather than passing quietly. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Path <dir>` `-OutFile` `-Quiet` |
| `get_provider_version.ps1` | **RETRIEVE ANY PRIOR PROVIDER JSON, ON DEMAND** — byte-exact, from git history. Built 2026-09-10 after Rob asked for HI v4.15 and got back only the tenant export he had supplied himself, while the repo-authored v4.15 sat in git the whole time. ⚠️ **RETRIEVAL, NOT REBUILD** — re-running an old build script does NOT reproduce an old version (3 shared-module + 6 HI-script commits landed after v4.15, so today's run emits today's RMS bundle); the git blob is the ONLY byte-exact source. **671 retrievable artifacts / 21 providers** (257 versioned-filename + 414 pre-versioned blobs via `-IncludeLegacy`, which reads the version out of the bundle description for the `<P>.json`/`_MC`/`_BASE` era). ⚠️ **`--diff-filter=A` UNDER-REPORTS**: a version swap is a RENAME, so additions-only finds 40 not 257, and HI reads 2 not 18. Verifies CONTENT (`git hash-object` vs the committed blob) not existence; REFUSES an `-OutPath` inside `providers\` (would break ONE-JSON-IN-ROOT) and refuses an ambiguous version rather than guessing. Extracts to the gitignored `_versions\` and are NEVER committed. See `knowledge-base/TOOL_REFERENCE.txt`. | `-Provider <name>` `-List` `-Version <X.Y>` `-IncludeLegacy` `-Commit <sha>` `-Variant <legacy\|MC\|BASE>` `-All` `-OutPath <dir>` `-Force` |
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
| **What anti-patterns apply?** | `knowledge-base/PLATFORM_CONSTRAINTS.txt` (22 APs + 27 LIMITATIONs, non-contiguous AP #2-#27 / LIMITATION #1-#40) | Memory, training data |
| **Why does this tool exist / what does its PASS actually prove?** | `knowledge-base/TOOL_REFERENCE.txt` (the WHY behind every gate — incidents, baselines, blind spots, "do NOT simplify this" warnings) | The one-line CLAUDE.md table row alone — it is an index, not the reasoning |
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
| **"test"** | `test_phase2.ps1 -Provider <NAME>` (then `-PostIngest`) | **AUTOMATED** — the browser driver runs the plan and the watcher ingests; the human's part is the rendered-form review (pre and post) evidenced on the Jira ticket. Pre-flight: [1] SPEC-vs-JSON plan coverage (an independent statement, not a JSON mirror), [2] package alignment + **FILLABILITY** (rewritten 2026-08-18 — see below), [3] environment. `-PostIngest` runs the FOUR log gates: 6c content, 6d metadata, 2i attribution, plan completeness. |
| **"finalize" / "save"** | `enforce.ps1 -Provider <NAME>` → commit+push → `audit_lifecycle.ps1` | Exit 0 is the definition of done. The lifecycle tail (PHASE 2r) is what makes it *finished* rather than merely green: the Jira entry names the current version and the import ledger accounts for it. |


**PHASE 2 STEP [2] FILLABILITY -- the check that was named but never performed (2026-08-18).** It
read `$bad = $jt2 | Where-Object { $_.expectedKeyRef -match "NO-FIRE|UNREACHABLE" }` -- it grepped
two marker strings and **never looked at the FILLS**, so it printed "50 plan tests, 0 that cannot fire"
and **"PRE-FLIGHT CLEAR -- sweep away"** on an OH_LEADS plan holding tests that provably could not run.
The operator drove it and the browser reported `field "undefined" did not fill (value="undefined")` on
RS and RN, then three consecutive RN tests never submitted at all. **The driver console blamed latency;
it was not latency** -- RN's mandatory `OwnerLastName`/`OwnerFirstName` were never in the fills, so the
tenant correctly kept Send DISABLED. Now checks three classes and prints its denominator: **BLANK FILL**
(fieldId or value empty -- the driver fills `undefined`), **ORPHAN FILL** (a fill naming a control that
does not exist -- an unpropagated rename), **UNSATISFIED** (a mandatory `set[]` field neither filled nor
form-prefilled -- nothing is sent), plus a `[NOTE]` for a built combo with **no plan test at all**
(OH's dealer-plate `ATDP` had none). A 0-fill run WARNs rather than passing. **The information already
existed and nothing consumed it:** `emit_test_plan` prints `Vehicle RN set[]: OwnerLastName has no test
value (unmapped in Get-TestValue)` by name -- the same orphaned-finding shape as `audit_layout_flow`.
Fix is test data, not a build: add the named fields to `docs/reference/TEST_VALUE_OVERRIDES.txt`
(entity-scoped `<Entity>.<fieldId>=value` preferred). OH went 50 tests / 2 BLANK / 7 UNSATISFIED ->
**56 tests / 151 fills clean**, recovering ATDP. ⚠️ **Its first draft raised ~125 ORPHAN findings and
every one was MY PROBE** -- nodes sit **directly under each layout variant**, there is no `.nodes` level,
so `$cf.layout.default.nodes` yields nothing and every field on every entity read as orphaned. Use the
`audit_wiring_closure` enumeration (`layout.PSObject.Properties` -> variant -> node). LAW 2 both ways:
FAILS on OH, and **all 8 tenant-verified providers are clean (592 tests / 1948 fills)** -- expected,
since a package that actually drove and passed cannot contain an unfireable test. Live elsewhere and
FLAGGED, not fixed: `[FLAG:plan-fillability-unfireable-tests]` on TN_TIES (4 BLANK / 4 UNSAT),
CA_eSUN (26 UNSAT), MD_METERS (3 UNSAT).


Two is not enough and neither is one: `pipeline.ps1` builds, but only PHASE 1 asks *whether the
build matches the devdoc*; `enforce` gates the repo, but only PHASE 2 proves the wire.

**Each phase has a SKILL that packages its reasoning** (`.claude/skills/`). The skill is where the
non-obvious traps live — read it before running the phase, not after it fails:

| Skill | Phase / trigger |
|---|---|
| `usx-build` | **PHASE 1.** "rebuild X", "audit X", any provider-JSON change. Authority-reading rules (`<Choice>` position; METADATA_REFERENCE flattens branches), the two lines of ordering, FIX-vs-REGISTER, LAW 2 mutation discipline, and the verdict-by-substring / BOM / array-unwrap traps. |
| `usx-test-iterate` | **PHASE 2.** "let's test X", or a devdoc/metadata change needing reconciliation. Routes through `test_phase2`; includes the submitted-vs-captured reconciliation that a lost Chrome download otherwise hides. |
| `usx-metadata` | **Reading the authorities without fooling yourself.** Use whenever deciding MANDATORY-vs-OPTIONAL, which variant a built combo implements, whether a finding is a real defect or a tool artefact, or why two authorities disagree — and before any change to a metadata-parsing tool. Holds the five grammar shapes (`<Choice>` position; a Choice branch can be a nested `<Set>` GROUP; a nested `<Set>` is a mandatory group; optionals are scoped PER VARIANT while the devdoc lists them FLAT; transaction-envelope vs per-query fields), **a keyRef is NOT a variant** (it decided five outcomes in one day), sourceField-vs-targetField, the new-provider ingestion checklist, and the conflict-resolution table for when metadata and devdoc genuinely disagree. |
| `usx-tooling` | **Changing a shared tool without making things quietly worse.** Use for any new gate or edit to `tools/*.ps1`. A tool change can lower coverage, break one provider, or silence a real finding — and all three look exactly like success. Holds the **regression fixture** (six 0/0 providers + branches-must-not-fall, which has already refuted one plausible improvement and caught a self-inflicted one mid-change), the portability-vs-correctness distinction, resolver/namespace rules, the PowerShell 5.1 traps, LAW 2 proof steps, and the suppression checklist (*a registration that costs coverage and buys nothing is worse than none*). |
| `usx-adjudicate` | **A gate reported something and you must decide what to DO.** The most repeated high-stakes routine in the project -- and on 2026-08-02 two of ~10 adjudications were wrong on the first attempt (a complete OH_LEADS fix the metadata refuted; an IL_LEADS_OFML registry row that cost coverage and silenced nothing). Holds: validate the probe before believing it (a systemic-looking finding is usually YOUR bug -- 25 and 100 false hits in one day), establish cause at COMBINATION granularity not transaction/keyRef, the FIX/REGISTER/DISMISS/FIX-THE-GATE table, registration mechanics (never name a BUILT keyRef with an existence-class rule; measure branches-compared before AND after), and the cost check before touching a tenant-verified build. |
| `usx-cosmetic` | **A COSMETIC / layout pass** — card titles, field labels, widths, row grouping, field order. Built 2026-08-11 because every prior cosmetic pass was somebody's eye, so nothing accumulated and each provider re-litigated it. Holds the insight that makes it reviewable at all — **a good form is a projection of the combination array, not a matter of taste** — the 9 rules (7 mechanised by `audit_layout_flow.ps1`), the cost rules (a cosmetic bump archives the whole test package, but re-test cost is NOT grounds to defer), and the traps that made **three of my first four hand findings wrong**: `hidden` is a NODE-level property, `render_layout` prints the node id where you expect the card title, and a label on a hidden field is dead text. |
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

`build_report.ps1` runs 17 steps. Steps 1, 5, 6, 7, 8, 9 always run (read-only on the JSON; core gated outputs). Steps 2 (layout report), 3 (query simulator), and 4 (picklist scanner) — plus 10 (test conductor), 11 (response simulator) and 12 (label review) — are advisory outputs enforce.ps1 (and audit_repo.ps1 Category 10) never require — demoted to opt-in 2026-07-06 (steps 10-12) and 2026-07-06 follow-up (steps 2-4, once Category 10's report-completeness check no longer required them), skipped by default, run via `-IncludeExtended` or the underlying tool standalone. ⚠️ **STEP 13 (OFFICER GUIDE) IS NOT IN THAT SET — it runs on EVERY build, unconditionally.** This line listed it as opt-in until 2026-09-04, when the code was read: there is no `if ($IncludeExtended)` around it. The claim mattered because it is the difference between "a rebuild refreshes the sheet a department reads" and "the sheet silently rots until someone remembers a flag" — and it was the doc, not the code, that was wrong. **Its output is now echoed rather than swallowed:** the call piped to `Out-Null`, which discarded the renderer's `[WARN] PDF NOT REWRITTEN` stale-guard and its `MESSAGE KEYS:` denominator line, so on a normal build the one signal saying "the PDF on disk does not match the HTML just produced" went nowhere. That is exactly how IL_LEADS_OFML shipped a 24-minute-stale PDF while every board read green. Step 14 (supported-query audit), 15 (per-provider changelog), and **16-17 (devdoc-combination coverage + combo reachability, added 2026-08-19 — the two BLOCKING enforce phases that until then left NO artifact anywhere in `docs/`, so a spec PASS could not be audited after the fact)** always run — both are read by enforce.ps1 (Phase 2e / Phase 3 doc-sync).

`enforce.ps1` runs ~10 phase sections: PHASE 1 (build freshness -- TEST_MATRIX currency AND, added 2026-08-02, **ANCILLARY/RENDER ARTIFACT CURRENCY**: the rendered LAYOUT html, picklist report, response simulation, label review and officer guide must not predate the JSON. WARN not FAIL -- they carry no wire impact -- but they are what a reviewer/tester actually reads, and they were unwatched from 2026-07-06 (demoted to `-IncludeExtended`, and audit_repo Category 10 stopped requiring them) until a sweep found 18 of 20 providers carrying a stale artifact and the render file describing a superseded JSON on all seven of the largest. Regenerate via `build_report -Path <json> -IncludeExtended`), 2 (validator scores), 2b (metadata-divergence gate), 2c (structural verify + CAD gates), 2d (simulator parity), 2e (devdoc supported-query gate), 2f (build reproducibility — opt-in via -Reproducible for a full-portfolio run; auto-on for a single -Provider run), 2g (base<->variant lockstep via audit_variant_sync), 2h (combo reachability / dead-combo gate via audit_combo_reachability -- run live per provider; `dead-combo*` accepted divergences report [NOTE] and don't block), 2i (log combo attribution via audit_log_combo_attribution -- replays each log's recorded fill to confirm the named combo is what fired; stale logs on registered dead combos report [NOTE]), 2j (SQVR integrity via audit_sqvr_integrity -- SQVR-named keyRefs must exist in the JSON and stated totals/version must match), 2k (rendered form review via audit_form_review -- ADVISORY; records which build a human actually reviewed), 2t (FORM<->QIDM WIRING CLOSURE via audit_wiring_closure -- BLOCKING; a control that silently discards officer input is not a judgement call), 2w (LAYOUT FLOW via audit_layout_flow -- ADVISORY/non-blocking, added 2026-08-18; is the form a projection of its combinations. Wired because the gate existed from 2026-08-11 and nothing ran it, so L7 `MI`-label drift sat unseen on 3 providers for three weeks. A 0-compared run WARNs rather than passing vacuously), 3 (doc version sync — 8 locations per provider: CLAUDE.md, STATUS, SQVR, JSON_INVENTORY, BUILD_NOTES + date checksum, REBUILD_TRACKER, per-provider CHANGELOG_<PROVIDER>.md, repo-root CHANGELOG.md Current line), 4+5 (cross-provider + repo integrity, run in parallel), 6 (iterate-phase gate + hypothesis quarantine), git status. Exit 0 = verified. Exit 1 = blocked.

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

**docs/ 4-CATEGORY STRUCTURE — ROLLOUT COMPLETE, 20/20 (verified 2026-08-10).** It began as an
NJ_NJCJIS pilot on 2026-07-01 and this section described it as an in-progress rollout for five weeks
after it finished; the resolver fallback below is now dead code in practice, kept only so a
newly-scaffolded provider still resolves before its first build. `phases/` is likewise retired on
**20/20**. Legacy `tests/` survives on exactly **2** (CA_CLETS, FL_FCIC) and is ARCHIVE-ONLY —
`audit_structure` accepts that deliberately because KB docs cite those paths. Uniformity across the
tenant-complete set is now gated by `audit_provider_uniformity.ps1`. Original description follows.

`docs/` splits into
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
