# Rebuild Tracker
Generated: 2026-05-08 | Last updated: 2026-05-21

## Status: 16 PROVIDERS FLAGGED FOR REBUILD — Single-JSON merge + HIDLE_MC migration

All 18 active providers rebuilt and validated (0 FAIL / 0 WARN). But audit found
7 providers with CommsysGetLastNameFirstNameInitialRuleHandler on Attention attribute
and NO visible form field — same pattern fixed on FL_FCIC v4.0.

## Final Scorecard (2026-05-11)

| # | Provider | Version | BASE Score | MC Score | LIM | Notes |
|---|---|---|---|---|---|---|
| 1 | NJ_NJCJIS | v3.5 |  | 69P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-21, State defaults, v3.4 imported USx Provider Tenant + Newark Foundation |
| 2 | HI_HCJDC_OFML | v1.7 |  | 67P/0F/0W/0LIM | 0 | State no-default, purposeCodeDH fixed. GAP (2026-06-08): DL SexCode-primary combo missing (metadata DQ primaryFieldReference=SexCode has no JSON combo -- add on rebuild) |
| 3 | NY_NYSPIN_EJUSTICE | v2.9 |  | 81P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-22, DGRP added, layout 13→7 cards, VehicleMakeCode FormSelect, one-directional deselect, CAD defaults |
| 4 | AZ_AZDPS | v2.3 |  | 71P/0F/0W/0LIM | 0 | |
| 5 | FL_FCIC | v4.6 |  | 87P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-21, QW removed, 7 QIDMs/33 combos, Attention visible |
| 6 | TX_TLETS | v3.3 |  | 86P/0F/0W/0LIM | 0 | EmailAddress user-fillable, Attention visible, one-directional deselect |
| 7 | LA_LEMS | v2.5 |  | 63P/0F/0W/0LIM | 0 | State no-default, purposeCodeDH fixed |
| 8 | CA_CLETS | v2.4 |  | 91P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-21, 40/40 combos, 6 QIDMs, live-tested |
| 9 | CA_VENTURA_COUNTY | v1.4 |  | 72P/0F/0W/0LIM | 0 | |
| 10 | CA_CLETS_OCATS | v1.2 |  | 63P/0F/0W/0LIM | 0 | |
| 11 | CA_eSUN | v1.5 |  | 71P/0F/0W/0LIM | 0 | |
| 12 | CA_SAN_LUIS_OBISPO | v1.3 |  | 65P/0F/0W/0LIM | 0 | |
| 13 | IL_LEADS_OFML | v1.1 |  | 61P/0F/0W/0LIM | 0 | |
| 14 | MD_METERS | v1.3 |  | 69P/0F/0W/0LIM | 0 | State no-default. GAP (2026-06-08): Gun GunMake-primary combo missing (metadata ZGUN primaryFieldReference=GunMake has no JSON combo -- add on rebuild) |
| 15 | OH_LEADS | v1.3 |  | 77P/0F/0W/0LIM | 0 | |
| 16 | NM_NMLETS_OFML | v1.3 |  | 66P/0F/0W/0LIM | 0 | |
| 17 | OR_LEDS | v1.3 |  | 58P/0F/0W/0LIM | 0 | |
| 18 | TN_TIES | v1.4 |  | 80P/0F/0W/0LIM | 0 | |

**CA_CONTRA_COSTA**: MC script created (clean-build HIDLE_MC pattern). Incomplete — awaiting updated devdoc/metadata decision.

## What Was Fixed (2026-05-08 through 2026-05-11)

### WARN Elimination (all 18 providers)
- ArticleType sourceField references (6 providers)
- Attention field combo placement (3 providers)
- State routing issues (3 providers)
- ImageIndicator defaults (2 providers)
- DH-suffix fieldId consistency (2 providers)
- Total: ~75 WARNs eliminated down to 0

### Dynamic PlateYear (all 18 providers)
- `$currentYear = [string](Get-Date).Year` added to all build scripts
- `initialValue = $currentYear` replaces hardcoded '2026'

### DH-suffix fieldIds (9 DL+DH providers)
- All 9 providers with DL+DH now use DH-suffix pattern
- queriesToDeselect configured on all 9

### Combo Ordering (all 18 providers)
- Most-specific combinations first in every QIDM

### State initialValue Removal (HI, LA, MD)
- Removed per "start clean" principle — LIM #30 eliminated
- Officers must explicitly select state

### purposeCodeDH Field Type Fix (HI, LA)
- Changed from FormSelect (attributeTypeId=DEX_INQUIRY_PURPOSE_CODE) to FormInput (maxLength=1, initialValue=C)
- Matches FL/NM/OH/TN/TX majority pattern

## Cross-Provider Audit (2026-05-11)
- 323 PASS / 0 FAIL / 2 WARN / 192 INFO
- 2 WARNs: CA_SAN_LUIS_OBISPO CaRequestPurposeCode (documented in metadata as intentional)

## Remaining Limitations (2 total)
- TX_TLETS: 2 LIM — EmailAddress is QIDM-only on DL+DH (no form field, handler-filled)
- These are genuinely unfixable without platform form field additions

## Attention Field Hidden Automation — Flagged 2026-05-13

Fix pattern (same as FL_FCIC v4.0): remove CommsysGetLastNameFirstNameInitialRuleHandler,
add visible FormInput for Attention (DH-suffix where applicable), update sourceField.

| # | Provider | QIDMs affected | Scope | Fix |
|---|---|---|---|---|
| 1 | LA_LEMS | v2.5 |  | 63P/0F/0W/0LIM |
| 2 | HI_HCJDC_OFML | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 3 | TX_TLETS | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 4 | CA_eSUN | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 5 | CA_VENTURA_COUNTY | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 6 | OH_LEADS | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 7 | TN_TIES | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |

**Already clean:** NJ, CA_CLETS, CA_OCATS, CA_SLO, IL, MD, NY, OR (no Attention attr),
AZ (Attention visible, no handler), NM (Attention InpH, no handler), FL (FIXED v4.0)

**Also noted:** TX_TLETS EmailAddress on DL+DH — no form field AND no handler (orphan, sends empty).

## KB-Based RMS — 2026-05-14

All 38 build scripts (19 BASE + 19 MC) now use `tools/_build_rms_bundle.ps1`
to construct the RMS bundle and CommSys QRDM from inline KB specifications. No external
template dependency — HIDLE_MC.json and HIDLE.json load paths both eliminated.

**Methodology**: Build from KB knowledge + metadata/devdocs only. `_build_rms_bundle.ps1`
defines all RMS and CommSys result-mapping data in code. No HIDLE.json, no patches, no
cleanup. Build scripts call `Build-RmsBundle` and `Build-CommsysQrdm` directly.

**BASE migration (2026-05-14)**: All 19 BASE scripts previously loaded `source/HIDLE.json`,
cloned CommSys QRDM, and applied 5 inline patches (Patch 1/3/6/7/8). Replaced with
`Build-CommsysQrdm` + `Build-RmsBundle` — same 2-line pattern as MC scripts. ~87 lines of
HIDLE load + QRDM clone + patch code eliminated per script (~1,650 lines total).
Migration script `_migrate_base_rms.ps1` deleted after successful run.

## Shared Layout Helpers — 2026-05-14

All 38 build scripts (19 BASE + 19 MC) now use `tools/_build_layout_helpers.ps1` for QIF layout construction.
Previously each script duplicated ~95 lines of identical helper functions (N, Inp, InpH, Sel,
SelH, Dt, BuildMultiCardLayout, AddCadNodes, AddFrNodes, MakeLayouts). Now consolidated into
a single 103-line shared module. InpH signature standardized to include maxLen parameter
(AZ_AZDPS 6 call sites updated). ~1,800 lines of duplication eliminated.

### Provider Helpers — `tools/_build_provider_helpers.ps1`

All 38 build scripts (19 BASE + 19 MC) now use `tools/_build_provider_helpers.ps1` for provider
boilerplate: AUTH config, QMF, QRDM, ENTITIES bundle, and output+validation. Previously each
script duplicated ~60 lines of identical AUTH/QMF/QRDM blocks plus ~20 lines of output/validation
code. Now consolidated into 5 shared functions (Build-Auth, Build-Qmf, Build-ProviderQrdm,
Build-EntitiesBundle, Write-ProviderJson). Write-ProviderJson standardizes pretty-printed output,
phase archiving, and validator-with-exit-on-fail across all scripts. ~2,400 lines
of duplication eliminated. Migration completed 2026-05-14 with 5 verification builds (CA_CLETS_OCATS
63P, IL_LEADS_OFML 61P, AZ_AZDPS 71P, FL_FCIC 102P, TN_TIES 80P — all 0F/0W).

### Already Built, Verified, and MERGED to Single-JSON (3)

| Provider | Version | Score | Status |
|---|---|---|---|
| NJ_NJCJIS | v3.5 |  | Single-JSON merged 2026-05-21, State defaults, CAD audit CLEAN |
| CA_CLETS | v2.4 |  | Single-JSON merged 2026-05-21, 40/40 combos, live-tested |
| FL_FCIC | v4.6 |  | Single-JSON merged 2026-05-21, 33 combos, Attention visible |

### Flagged for Full Rebuild on Next Test (16)

Scripts updated, NOT yet built. On first test of each provider:
1. Delete old BASE script, rename MC→primary (`build_<provider>.ps1`), update output to `<PROVIDER>.json`
2. Run build script, then build_report.ps1, verify 0 FAIL on all checks including CAD audit
3. Reports go to `docs/` (not `docs/base/` or `docs/mc/`)

| # | Provider | MC Script Updated | Attention Fix Needed | Notes |
|---|---|---|---|---|
| 1 | TX_TLETS | YES | YES (DH only) | +race dead field, camelCase applied |
| 2 | HI_HCJDC_OFML | YES | YES (DH only) | Standard cleanup |
| 3 | LA_LEMS | YES | YES (ALL 7 QIDMs) | +race dead field |
| 4 | AZ_AZDPS | YES | NO | Keep SSN, remove PlateYear, unique $final assembly |
| 5 | NY_NYSPIN_EJUSTICE | DONE (v2.0) | DONE (v2.0) | Merged 2026-05-22 |
| 6 | CA_VENTURA_COUNTY | YES | YES (DH only) | Standard cleanup |
| 7 | CA_eSUN | YES | YES (DH only) | Standard cleanup |
| 8 | CA_SAN_LUIS_OBISPO | YES | NO | Standard cleanup |
| 9 | CA_CLETS_OCATS | YES | NO | Standard cleanup |
| 10 | IL_LEADS_OFML | YES | NO | Standard cleanup |
| 11 | MD_METERS | YES | NO | +race dead field |
| 12 | OH_LEADS | YES | YES (DH only) | Standard cleanup |
| 13 | NM_NMLETS_OFML | YES | NO | Standard cleanup |
| 14 | OR_LEDS | YES | NO | Standard cleanup |
| 15 | TN_TIES | YES | YES (DH only) | Keep SSN |
| 16 | CA_CONTRA_COSTA | NO | NO | Incomplete — awaiting updated devdoc/metadata |

## Single-JSON Merge — 2026-05-21

BASE/MC dual-variant build path eliminated. One build script per provider → one JSON output.
- NJ_NJCJIS, FL_FCIC, CA_CLETS: MERGED (scripts renamed, JSONs renamed, reports in docs/)
- 16 remaining providers: merge on next rebuild (see instructions above)
- Tools updated: pipeline.ps1, enforce.ps1, build_report.ps1, sync_version_docs.ps1, audit_cad.ps1
- KB updated: BUILD_RULES.txt Section 6, CLAUDE.md

## CAD Defaults — Flagged 2026-05-19

CAD dispatch does NOT apply QIF form initialValues. Fields in any[] with initialValues
need combination-level `defaults[]` to ensure CAD-dispatched XML includes them.
audit_cad.ps1 CHECK 6 now validates this automatically. BUILD_RULES.txt Section 12 documents the rule.

**NJ_NJCJIS v3.3 DONE** — all 13 combos have defaults. 0 FAIL on CAD audit CHECK 6.

**142 FAIL across remaining 17 providers.** Most common missing defaults:
- ImageIndicator (nearly all providers that have it)
- LicensePlateTypeCode / LicensePlateYear (all providers with plate combos)
- RelatedHitSearchIndicator (TX_TLETS)
- PurposeCode (CA providers — flagged as INFO due to codeTypeProvider)

Fix on next rebuild of each provider. Fields to default are provider-specific — check
each provider's form initialValues, not a universal list.

## Legacy Artifact Cleanup — Flagged 2026-06-03

On rebuild of each remaining provider, also clean up legacy BASE/MC artifacts.
See BUILD_RULES.txt Section 13 for full checklist.

| Cleanup Item | Providers Affected |
|---|---|
| Delete _BASE_TEST_MATRIX.txt + _MC_TEST_MATRIX.txt | 14 (all except NJ, FL, TX, CA_CLETS — cleaned 2026-06-03) |
| Delete BASE_SIM/MC_SIM test logs | AZ_AZDPS, NY_NYSPIN_EJUSTICE |
| Rename _MC suffix JSON to {PROVIDER}.json | 12 (_MC suffix providers) |
| Consolidate dual JSON (BASE + MC) | HI_HCJDC_OFML (only provider with 2 root JSONs) |
| Regenerate METADATA_REFERENCE (remove "MC expansion candidate") | 14 (all except NJ, FL, TX, CA_CLETS — fixed 2026-06-03) |

## Next Actions
- TX_TLETS v3.3 live testing in progress (imported TLETS USx Tenant 2026-06-03)
- Provider work order: TX_TLETS (ACTIVE), NY, AZ
- Merge BASE/MC → single-JSON on each rebuild (16 providers)
- Fix Attention hidden automation on next rebuild of each flagged provider
- Fix CAD defaults (142 FAILs) on next rebuild of each provider
- Legacy cleanup per Section 13 checklist on each rebuild
- Each provider's first test triggers: merge scripts → build → build_report → verify all checks CLEAN
