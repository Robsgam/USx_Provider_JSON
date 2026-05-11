# Rebuild Tracker
Generated: 2026-05-08 | Last updated: 2026-05-11

## Status: COMPLETE

All 18 active providers rebuilt and validated. 0 FAIL / 0 WARN across all 36 JSONs.

## Final Scorecard (2026-05-11)

| # | Provider | Version | BASE Score | MC Score | LIM | Notes |
|---|---|---|---|---|---|---|
| 1 | NJ_NJCJIS | v3.1 | 69P/0F/0W | 69P/0F/0W | 0 | LOCKED -- v3.0 DEPLOYED Newark NJ |
| 2 | HI_HCJDC_OFML | v1.6 | 72P/0F/0W | 72P/0F/0W | 0 | State no-default, purposeCodeDH fixed |
| 3 | NY_NYSPIN_EJUSTICE | v1.5 | 74P/0F/0W | 74P/0F/0W | 0 | State no-default |
| 4 | AZ_AZDPS | v2.3 | 71P/0F/0W | 71P/0F/0W | 0 | |
| 5 | FL_FCIC | v3.4 | 101P/0F/0W | 102P/0F/0W | 0 | |
| 6 | TX_TLETS | v2.5 | 84P/0F/0W | 84P/0F/0W | 2 | EmailAddress QIDM-only (unfixable) |
| 7 | LA_LEMS | v2.5 | 63P/0F/0W | 63P/0F/0W | 0 | State no-default, purposeCodeDH fixed |
| 8 | CA_CLETS | v1.7 | 66P/0F/0W | 70P/0F/0W | 0 | |
| 9 | CA_VENTURA_COUNTY | v1.4 | 68P/0F/0W | 72P/0F/0W | 0 | |
| 10 | CA_CLETS_OCATS | v1.2 | 63P/0F/0W | 63P/0F/0W | 0 | |
| 11 | CA_eSUN | v1.5 | 71P/0F/0W | 71P/0F/0W | 0 | |
| 12 | CA_SAN_LUIS_OBISPO | v1.3 | 65P/0F/0W | 65P/0F/0W | 0 | |
| 13 | IL_LEADS_OFML | v1.1 | 61P/0F/0W | 61P/0F/0W | 0 | |
| 14 | MD_METERS | v1.3 | 69P/0F/0W | 69P/0F/0W | 0 | State no-default |
| 15 | OH_LEADS | v1.3 | 77P/0F/0W | 77P/0F/0W | 0 | |
| 16 | NM_NMLETS_OFML | v1.3 | 66P/0F/0W | 66P/0F/0W | 0 | |
| 17 | OR_LEDS | v1.3 | 58P/0F/0W | 58P/0F/0W | 0 | |
| 18 | TN_TIES | v1.4 | 80P/0F/0W | 80P/0F/0W | 0 | |

**Skipped**: CA_CONTRA_COSTA (no basic queries per devdoc; awaiting decision)

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

## Next Actions
- Live testing per provider work order: CA_CLETS, FL_FCIC, TX_TLETS, NY, AZ
