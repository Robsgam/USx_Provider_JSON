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
| FL_FCIC | usx.fl-fcic.mark43.com (`usx.` dot form) | DEX-971 | v7.17 (116 logs) | v7.17 | current (tenant-complete 2026-08-03, ALL-PASS 116/116, four log gates green). Swept in one session: Vehicle 20 / Person 21 / Firearm 15 / Article 16 / Boat 44, every entity reconciling submitted-vs-captured. Proved v7.15 Requestor (all 116 wires), v7.16 RelatedHitSearchIndicator (Gun+Article) and the v7.14 FRQ over-permit removal (0 of 12 FRQ wires carry VehicleMakeCode/vehicleYear). Note: this tenant sends ORI/Mnemonic=CA1234567 regardless of provider |
| HI_HCJDC_OFML | usx-hi-hcjdc-ofml.mark43.com | DEX-1257 | v4.14 (46 logs) | v4.14 | current (tenant-complete, ALL-PASS 46/46) |
| NY_NYSPIN_EJUSTICE | usx-ny-nyspin-ejustice.mark43.com | DEX-969 | v4.19 (64 logs) | v4.19 | current (tenant-complete, ALL-PASS 64/64) |
| TX_TLETS | usx-tx-tlets.mark43.com | DEX-967 | v4.18 (89 logs) | v4.18 | current (tenant-complete, ALL-PASS 89/89, 16/16 mutations killed) |
| CA_CLETS | usx-ca-clets.mark43.com | DEX-976 | v2.23 (90 logs) | v2.23 | current (tenant-complete, ALL-PASS 90/90). The prior note here read "BLOCKED on 4 enforce FAILs + 6 under-required findings" — resolved at v2.23; enforce is 0 FAIL / 0 WARN. Count corrected 89→90 on 2026-08-04: the 89 was read mid-ingest, before the Firearm re-capture landed |
| AZ_AZDPS | usx-az-azdps.mark43.com | DEX-974 | none | v3.4 | never imported/captured; DEX-974 had no JSON attached as of 2026-07-22. Confirm `dexStateUserId` populates on the FIRST query or all 5 badge combos silently fall back |

All other providers (CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY,
CA_eSUN, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES,
TX_TLETS_CCH): **0 logs at any version → never installed on a USx test tenant.** Galvanized/built
in repo, awaiting first tenant import.

---

## B. Foundation Tenants (customer staging — MANUAL, from import reports)

| Tenant | Provider | Version | Imported | Notes |
|---|---|---|---|---|
| Newark Foundation | NJ_NJCJIS | v4.15 | 2026-08-03 | current — v4.14→v4.15, imported by Rob after the v4.15 re-sweep (36/36 ALL-PASS). Picks up the Boat QBN `RegistrationNumber` fix: a hull search now transmits the reg number instead of silently dropping it (devdoc BoatQuery #1) — wire-proven in that sweep |
| Bert Anzini USx test tenant | NJ_NJCJIS | v4.9 | 2026-07-20 | **frozen on purpose** — CAD-config test only, any valid JSON suffices; do not flag drift |
| Miami Springs Foundation | FL_FCIC | v7.17 | 2026-08-03 | current — v7.12→v7.17, imported by Rob after the v7.17 tenant sweep (116/116 ALL-PASS). Picks up v7.13 FBQ hull RegistrationNumber, v7.14 FRQ over-permit removal, v7.15 Requestor, v7.16 RelatedHitSearchIndicator/VINSequenceNumber, v7.17 dead-control removal |
| North Miami Foundation | FL_FCIC | v7.17 | 2026-08-03 | current — v7.12→v7.17, same import pass as Miami Springs |
| Balcones Heights TX Foundation | TX_TLETS | v4.18 | 2026-08-03 | current — v4.12→v4.18, imported by Rob after the v4.18 re-sweep (89/89 ALL-PASS). Picks up v4.13 dead-RQ removal, v4.14 all-7-Vehicle-combos-reachable (prefills out), v4.15/v4.16 UI, v4.17 QV shadow removal, v4.18 17 dropped optionals |

## C. Published JSON — Jira ticket + Confluence catalog (MANUAL, from Rob's confirmation)

The THIRD destination class, added 2026-08-03. A/B above cover tenants; nothing tracked where a JSON
was *published* for other teams to pull, so "which version of FL is in the catalog" was not stale —
it was **unanswerable**, which is worse. Rob attaches the JSON to the DEX ticket and posts it to the
[USx CommSys Data Providers Catalog](https://mark43.atlassian.net/wiki/spaces/SEARCH/pages/6956810378/USx+CommSys+Data+Providers+Catalog);
the MCP tooling cannot attach files, so this is manual in both directions — recorded here on his
confirmation, never inferred from a version bump.

| Provider | Version | Attached to ticket | Posted to catalog | Notes |
|---|---|---|---|---|
| FL_FCIC | v7.17 | DEX-971, 2026-08-03 | 2026-08-03 | after the 116/116 ALL-PASS sweep; same pass as the Miami Springs + North Miami imports |
| TX_TLETS | v4.18 | DEX-967, 2026-08-03 | 2026-08-03 | after the 89/89 ALL-PASS re-sweep; same pass as the Balcones Heights import |
| NY_NYSPIN_EJUSTICE | v4.19 | DEX-969, 2026-08-03 | 2026-08-03 | after the 64/64 ALL-PASS re-sweep. No Foundation tenant carries NY, so there is no section B row to match |
| NJ_NJCJIS | v4.15 | DEX-988, 2026-08-03 | 2026-08-03 | after the 36/36 ALL-PASS re-sweep; same pass as the Newark Foundation import |
| CA_CLETS | v2.23 | DEX-976, 2026-08-03 | 2026-08-03 | after the 90/90 ALL-PASS re-sweep. No Foundation tenant carries CA_CLETS |
| HI_HCJDC_OFML | v4.14 | DEX-1257, 2026-08-04 | 2026-08-04 | after the 46/46 ALL-PASS re-sweep. **No version bump** — v4.14 was already published; re-published as the re-verified artifact. Last of the original six |

> **TENANT INFO STAYS OFF THE TICKETS (Rob, 2026-08-03, restated).** Nothing in section B or C goes
> into a Jira comment — not the attachment, not the catalog post, not a Foundation import. **This
> overrides the ticket's own precedent:** DEX-967's v4.10 and v4.12 comments both end with an
> explicit `IMPORT: ... Balcones Heights` line, and v4.11 warned that Balcones had fallen behind, so
> the convention on that ticket was to publish it. It was raised and Rob confirmed: leave it off.
> A future session reading those older comments will think an IMPORT line is expected — it is not.

**Maintenance:** add/bump a row in A/B/C ONLY when an import or publish is actually reported (per
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

### TX_TLETS_CCH -- built, NOT YET IMPORTED (recorded 2026-07-30, TX_TLETS half corrected 2026-08-03)

- **TX_TLETS v4.18 -- SUPERSEDED, this row was WRONG.** It read "**not imported to any tenant** /
  tenant re-sweep owed from T1" as of 2026-07-30, and then the sweep happened: `usx-tx-tlets` now
  carries **89 v4.18 logs, ALL-PASS 89/89**, which the table above records. Logs ARE the install
  proof for a USx provider tenant, so v4.18 is installed and this section contradicted its own
  table for four days. Left in place rather than deleted because the contradiction is the lesson:
  a hand-written "not imported" note does not expire on its own, while the log-derived table does
  update — **when the two disagree, the table wins.**
- **TX_TLETS_CCH v1.14** -- built + gated, **never tenant-tested, not imported.** BASE-SYNC v4.18.
  Still accurate: 0 logs at any version.

Recorded because `audit_lifecycle.ps1` (enforce PHASE 2r) treats SILENCE as the defect: "built but
not imported" is a perfectly good state and must be WRITTEN, so that "where is v4.18 installed" is
never answered from memory.