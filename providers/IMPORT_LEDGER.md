# USx JSON Import Ledger

**Single source of truth for which JSON version is installed in which tenant.**
No production environments exist yet — everything below is import/test or customer staging.

There are two tenant classes, tracked two different ways:

| Class | What it is | How its version is tracked |
|---|---|---|
| **USx Provider Tenant** | One per provider. The import/live-test tenant. The **driver capture tool is locked to these tenants only.** | **Self-verifying from logs** — the newest version with non-archived logs in `providers/<P>/logs/<Entity>/` IS the version installed on that provider's USx test tenant (you can only capture logs against the tenant the tool is pointed at). No manual entry needed; compute it. |
| **Foundation Tenant** | Customer staging (e.g. Newark, Balcones Heights). The capture tool **cannot** reach these. | **Manual** — recorded here only from an actual import report (never from an "update X" instruction). This section is the durable home that memory used to hold. |

> **Derivation rule (USx Provider Tenants):** `logs at version X = proof X is installed on that provider's USx test tenant.` Recompute the column below anytime with `tools/portfolio_status.ps1` (its log-derived USx-tenant-test column) or the one-liner at the bottom of this file. Do NOT hand-maintain it — logs are the truth.

---

## A. USx Provider Tenants (one per provider)

Version column = newest-logged version (= proven install). "repo" = current versioned root JSON.
When repo > tenant, the newer build has been built but not yet re-imported+captured on the tenant.

| Provider | URL | DEX | Installed (logged) | Repo | Note |
|---|---|---|---|---|---|
| NJ_NJCJIS | usx-nj-njcjis.mark43.com | DEX-988 | v4.10 (archived) | v4.13 | v4.11 relabel + v4.12 consolidation + v4.13 UPPERCASE titles built; all 5 reset — re-import+capture pending |
| FL_FCIC | usx.fl-fcic.mark43.com (`usx.` dot form) | DEX-971 | v7.8 (archived) | v7.10 | v7.9 relabel + v7.10 UPPERCASE titles built; all 5 reset — re-import+capture pending |
| HI_HCJDC_OFML | usx-hi-hcjdc-ofml.mark43.com | DEX-1257 | v4.11 (archived) | v4.13 | v4.12 relabel + v4.13 UPPERCASE titles + Boat-stolen audit fix built; all 5 reset — re-import+capture pending |
| NY_NYSPIN_EJUSTICE | usx-ny-nyspin-ejustice.mark43.com | DEX-969 | v4.16 (67 logs) | v4.16 | current (tenant-complete 2026-07-27, UPPERCASE-title re-sweep) |
| TX_TLETS | usx-tx-tlets.mark43.com | DEX-967 | v4.12 (84 logs) | v4.12 | current (tenant-complete 2026-07-27, Person 2-card-fold re-sweep) |
| CA_CLETS | usx-ca-clets.mark43.com | DEX-976 | none (logs archived) | v2.19 | last tenant-tested v2.12; v2.13-v2.19 built (v2.19 = in/out gating fix, FUNCTIONAL), not re-captured — re-test owed |
| AZ_AZDPS | usx-az-azdps.mark43.com | DEX-974 | none | v3.1 | never imported/captured; DEX-974 had no JSON attached as of 2026-07-22 |

All other providers (CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY,
CA_eSUN, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES,
TX_TLETS_CCH): **0 logs at any version → never installed on a USx test tenant.** Galvanized/built
in repo, awaiting first tenant import.

---

## B. Foundation Tenants (customer staging — MANUAL, from import reports)

| Tenant | Provider | Version | Imported | Notes |
|---|---|---|---|---|
| Newark Foundation | NJ_NJCJIS | v4.10 | 2026-07-22 | hands-off MODE — **behind repo v4.13** (relabel + consolidation + UPPERCASE titles); manual re-import owed |
| Bert Anzini USx test tenant | NJ_NJCJIS | v4.9 | 2026-07-20 | **frozen on purpose** — CAD-config test only, any valid JSON suffices; do not flag drift |
| Miami Springs Foundation | FL_FCIC | v7.8 | 2026-07-22 | hands-off MODE — **behind repo v7.10** (relabel + UPPERCASE titles); manual re-import owed |
| North Miami Foundation | FL_FCIC | v7.8 | 2026-07-22 | hands-off MODE — **behind repo v7.10** (relabel + UPPERCASE titles); manual re-import owed |
| Balcones Heights TX Foundation | TX_TLETS | v4.12 | 2026-07-27 | v4.2→v4.7→v4.10→v4.12 (Person 2-card fold); current |

**Maintenance:** add/bump a row here ONLY when an import is actually reported (per
`project_deployment_tracking` memory: never record from an "update X to latest" instruction alone).
Deployment architecture (which provider goes to which foundation) → KB `TESTING_REQUIREMENTS.txt`
Section 17.

---

## Recompute Section A (logs → installed version)

```bash
cd providers
for p in */; do p="${p%/}"; [ -d "$p/logs" ] || continue
  ver=$(ls "$p"/logs/*/*.txt 2>/dev/null | grep -v _archive | grep -oE "_v[0-9]+\.[0-9]+_" | sort -uV | tail -1 | tr -d '_v')
  cnt=$(ls "$p"/logs/*/*.txt 2>/dev/null | grep -v _archive | grep -E "_v${ver}_" | wc -l)
  printf "%-22s installed=%-8s (%s logs)\n" "$p" "${ver:-none}" "$cnt"
done
```

_Last reconciled: 2026-07-27._
