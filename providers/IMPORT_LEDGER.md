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
| NJ_NJCJIS | usx-nj-njcjis.mark43.com | DEX-988 | v4.15 (36 logs) | v4.15 | current (tenant-complete 2026-07-31, ALL-PASS 36/36, four log gates green) |
| FL_FCIC | usx.fl-fcic.mark43.com (`usx.` dot form) | DEX-971 | none (logs archived) | v7.14 | v7.13 dropped-optional fix + v7.14 FRQ over-permit removal built; package reset — re-import+capture owed (109 plan tests) |
| HI_HCJDC_OFML | usx-hi-hcjdc-ofml.mark43.com | DEX-1257 | v4.14 (46 logs) | v4.14 | current (tenant-complete, ALL-PASS 46/46) |
| NY_NYSPIN_EJUSTICE | usx-ny-nyspin-ejustice.mark43.com | DEX-969 | v4.19 (64 logs) | v4.19 | current (tenant-complete, ALL-PASS 64/64) |
| TX_TLETS | usx-tx-tlets.mark43.com | DEX-967 | v4.18 (89 logs) | v4.18 | current (tenant-complete, ALL-PASS 89/89, 16/16 mutations killed) |
| CA_CLETS | usx-ca-clets.mark43.com | DEX-976 | v2.22 (90 logs) | v2.22 | logs current at v2.22, but the provider is BLOCKED on 4 enforce FAILs + 6 under-required findings — do not treat the log count as "done" |
| AZ_AZDPS | usx-az-azdps.mark43.com | DEX-974 | none | v3.3 | never imported/captured; DEX-974 had no JSON attached as of 2026-07-22. Confirm `dexStateUserId` populates on the FIRST query or all 5 badge combos silently fall back |

All other providers (CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY,
CA_eSUN, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES,
TX_TLETS_CCH): **0 logs at any version → never installed on a USx test tenant.** Galvanized/built
in repo, awaiting first tenant import.

---

## B. Foundation Tenants (customer staging — MANUAL, from import reports)

| Tenant | Provider | Version | Imported | Notes |
|---|---|---|---|---|
| Newark Foundation | NJ_NJCJIS | v4.14 | 2026-07-28 | **BEHIND repo v4.15** — v4.15 adds RegistrationNumber to Boat QBN any[] (hull search now transmits the reg number instead of dropping it, devdoc BoatQuery #1). Manual re-import owed |
| Bert Anzini USx test tenant | NJ_NJCJIS | v4.9 | 2026-07-20 | **frozen on purpose** — CAD-config test only, any valid JSON suffices; do not flag drift |
| Miami Springs Foundation | FL_FCIC | v7.12 | 2026-07-28 | **BEHIND repo v7.14** — v7.13 adds RegistrationNumber to FBQBoatHullIdNumber any[] (dropped-optional fix); v7.14 removes VehicleMakeCode/vehicleYear over-permits from FRQ{Plate} and FRQ{VIN}. Manual re-import owed |
| North Miami Foundation | FL_FCIC | v7.12 | 2026-07-28 | current — v7.8→v7.12 (v7.9 relabel + v7.10 UPPERCASE + v7.11 UI/label fixes + v7.12 Vehicle-first order) |
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

_Last reconciled: 2026-07-28._

### TX_TLETS / TX_TLETS_CCH -- built, NOT YET IMPORTED (recorded 2026-07-30)

- **TX_TLETS v4.18** -- built + gated (enforce 0 FAIL / 0 WARN), **not imported to any tenant.**
  Tenant re-sweep owed from T1; the v4.16 logs were archived by the v4.17/v4.18 bumps. The USx
  provider tenant still holds whatever was last installed there -- log-derived, not assumed.
- **TX_TLETS_CCH v1.14** -- built + gated, **never tenant-tested, not imported.** BASE-SYNC v4.18.

Recorded because `audit_lifecycle.ps1` (enforce PHASE 2r) treats SILENCE as the defect: "built but
not imported" is a perfectly good state and must be WRITTEN, so that "where is v4.18 installed" is
never answered from memory.