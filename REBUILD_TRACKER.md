# Rebuild Tracker
Generated: 2026-05-08

## Providers Flagged for Rebuild

| # | Provider | WARNs (BASE/MC) | PlateYear | PurposeCode DH | Priority |
|---|---|---|---|---|---|
| 1 | LA_LEMS | 32W / 32W | YES | -- | HIGH |
| 2 | TX_TLETS | 13W / 13W | YES | -- | HIGH |
| 3 | IL_LEADS_OFML | 7W / 3W | YES | -- | HIGH |
| 4 | MD_METERS | 5W / 2W | YES | -- | MED |
| 5 | OH_LEADS | 4W / 3W | YES | -- | MED |
| 6 | TN_TIES | 4W / 1W | YES | -- | MED |
| 7 | CA_eSUN | 3W / 3W | YES | -- | MED |
| 8 | OR_LEDS | 2W / 1W | YES | -- | MED |
| 9 | NM_NMLETS_OFML | 2W / 1W | YES | -- | MED |
| 10 | FL_FCIC | 1W / 1W | YES | -- | LOW |
| 11 | HI_HCJDC_OFML | 1W / 1W | YES | -- | LOW |
| 12 | CA_SAN_LUIS_OBISPO | 0W / 0W | YES | YES | LOW |
| 13 | NY_NYSPIN_EJUSTICE | 0W / 0W | YES | -- | LOW |
| 14 | AZ_AZDPS | 0W / 0W | YES | -- | LOW |
| 15 | CA_VENTURA_COUNTY | 0W / 0W | YES | -- | LOW |
| 16 | CA_CLETS_OCATS | 0W / 0W | YES | -- | LOW |

## Not Flagged (clean)

| Provider | Status | Notes |
|---|---|---|
| NJ_NJCJIS_LOCKED | 0W/1LIM | LOCKED -- PlateYear script fixed, takes effect on next unlock rebuild |
| CA_CLETS | 0W/5LIM (BASE) 0W/7LIM (MC) | Just rebuilt v1.6 -- PlateYear + PurposeCode already fixed |
| CA_CONTRA_COSTA | -- | No basic queries per devdoc; needs decision before any build |

## Fix Categories

### 1. WARN Elimination (11 providers)
Common WARN patterns identified in lean overview:
- **ArticleType-source**: Article QIDM sourceField references non-existent QIF field (6 providers)
- **Attention-in-combo**: Attention field in set[] instead of using handler pattern (3 providers)
- **State-routing**: State field issues (initialValue in set[], missing codeTypeProvider) (3 providers)
- **ImageIndicator-default**: Missing or wrong default value (2 providers)
- **DH-suffix**: Missing DH-suffix fieldIds on shared DL/DH form (2 providers)

Each provider's build script needs targeted fixes per its specific WARN list.
Run `validate.ps1 -Path <json> -ShowDetail` to see exact WARNs per provider.

### 2. Dynamic PlateYear (16 providers)
Add `$currentYear = [string](Get-Date).Year` to build script top.
Replace `initialValue = '2026'` with `initialValue = $currentYear`.
Affects both BASE and MC build scripts.

### 3. PurposeCode DH (1 provider)
CA_SAN_LUIS_OBISPO: Add PurposeCode attribute to DriverHistoryQuery QIDM.
Pattern: `name='PurposeCode', size=1, sourceField=['caRequestPurposeCode'], targetField='PurposeCode'`

## Rebuild Order

Rebuild by priority (highest WARN count first = most improvement per rebuild):
1. LA_LEMS (32W) -- biggest bang
2. TX_TLETS (13W)
3. IL_LEADS_OFML (7W)
4. MD_METERS (5W)
5. OH_LEADS (4W)
6. TN_TIES (4W)
7. CA_eSUN (3W)
8. OR_LEDS (2W)
9. NM_NMLETS_OFML (2W)
10. FL_FCIC (1W)
11. HI_HCJDC_OFML (1W)
12. CA_SAN_LUIS_OBISPO (PurposeCode only)
13-16. NY/AZ/VENTURA/OCATS (PlateYear only)

## Completion Checklist

Per provider rebuild:
- [ ] Fix WARNs in build script
- [ ] Add dynamic $currentYear
- [ ] Add PurposeCode DH (if applicable)
- [ ] Run build script (BASE + MC)
- [ ] Run build_report.ps1 (both variants)
- [ ] Verify 0 FAIL / 0 WARN
- [ ] Commit JSON + reports
- [ ] Push to GitHub
- [ ] Update CLAUDE.md provider table
- [ ] Update STATUS.txt
