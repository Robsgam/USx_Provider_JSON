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
| FL_FCIC | usx.fl-fcic.mark43.com (`usx.` dot form) | DEX-971 | **v7.23 (110 logs)** | **v7.23** | **v7.23 IMPORTED + TENANT-VERIFIED 2026-08-12 -- ALL-PASS 110/110** (Veh 20 / Per 21 / Gun 15 / Art 16 / Boat 38), four log gates 110/110 each, submitted-vs-captured reconciled per entity. **Three contested decisions WIRE-PROVEN:** Boat Stolen Check 'Y' on 24 QB wires (18 Y / 6 N toggle / 0 absent); the BQ-ahead-of-QB reorder RECOVERED `BQBoatHullIdNumber` + `BQRegistrationNumber`, both fired where the prefill had shadowed them dead; `<State>NJ</State>` on 7/7 DH wires with 0 carrying FL, upholding FCIC's destination rule. **The sweep also produced LIMITATION #40 (LIVE-PROVEN): the wire is a UNION across every MATCHING combination, not the firing combo's field list** -- 38/38 Boat logs predicted, 0 mispredicted. Consequence: v7.23 removed `ImageIndicator` from all 4 FBQ combos (correct per metadata FBQ `<Any>` and devdoc items 1-4) yet 5 of 8 FBQ wires still carry it, because those fills also match a QB combination. Prior: **v7.23 BUILT 2026-08-12 -- RE-IMPORT + full 116-test re-sweep OWED.** Firearm row re-order (Gun Make to the first cell of row 2, beneath the Serial Number it qualifies; NCIC Image takes its row-1 slot) **and NCIC Image defaults to `Y` on all five entities** -- 5 form controls + all 25 combo `defaults[]` (CAD ignores form `initialValue`, so a form-only flip leaves CAD queries on `N`). Measured safe first: `ImageIndicator` is in 0 `set[]` / 0 conditions of 36 combinations, and reachability 30/30 + prefill-shadow 92 pairs 0 FAIL are unchanged; no devdoc "must be filled if Image = Y" conditional. **⚠️ ROB'S RULING OWED, gate NOT silenced:** `audit_cross_provider` hard-codes `Vehicle ImageIndicator='N'`, so FL now carries a permanent `[WARN] (expected 'N')`; a 20-provider sweep found every provider on Person=`Y` / others=`N`, so FL is the sole exception. The other 19 carry `[FLAG:ncic-image-default-y-everywhere]` and take it at their OWN rebuild -- which BLOCKS their enforce PHASE 1 meanwhile (verified on NJ), so 6 tenant-verified providers are un-done until then. **Also OPEN, not fixed:** metadata's FBQ `<Any>` omits `ImageIndicator` yet all 4 built FBQ combos carry it in `any[]`+`defaults[]` -- a real OVER-PERMIT invisible to `audit_requirement_fidelity` (`$formOnly` whitelist). Prior: **v7.20** -- cosmetic/layout pass on Rob's rendered-form review, **zero wire change**: four rows retired (Vehicle VIN-Seq joins the Decal row; Firearm two visible rows; Article Serial+Type+OAN on top with the rest combined below; Boat State/Stolen/NCIC Image lifted from the bottom to directly under the identifier row). DH State relabelled `Destination State (required, not FL)` -- both facts are needed, since "State (required)" on a Florida form invites the ONE destination FCIC says KQ cannot take. **Two requested items were REFUSED BY THE SOURCES and measured, not argued:** (a) an FL default on DH State -- FCIC 2026-06-12, "the destination to be something other than FL"; (b) a Boat Stolen Check default -- injected into a replica (all 3 layout variants, asserted in the reparsed JSON) and the owning gates returned `[FAIL] 4 dead combination(s) of 30 checked` at the SAME denominator as the clean baseline: FBQ Hull/Reg self-unsatisfiable and QB shadowing BQ Hull/Reg. I had predicted 2, so this was worth measuring. `audit_layout_flow` 4 findings -> 1, and that one was verified PRE-EXISTING by re-running the gate against the v7.19 artifact from git. **NOTHING ABOUT v7.20 IS WIRE-VERIFIED -- Rob's own sweep settles it** ("once we test live(not with you) we can finailize any assumptions"). Prior: **v7.19 BUILT 2026-08-12 and superseded the same day before any sweep;** Stolen Check defaults to 'Y' on Firearm + Article (form initialValue AND the combo defaults[] CAD twin -- CAD ignores form initialValue, so a form-only default would give CAD-originated queries no stolen check at all). **BOAT deliberately excluded:** there the same field IS the routing discriminator, gated EXISTS on QB and NOT_EXISTS on FBQ, so a default would kill the ordinary Boat registration search (BUILD_RULES 24). Prior: current (tenant-complete 2026-08-06, ALL-PASS 116/116, four log gates green). DEX-1283 fix: removed initialValue='X' from Attention (DH) + Requestor (VehReg/DH/Gun/Article/Boat, 6 hidden feeders) -- both confirmed resolving the real officer name on the wire with nothing in the source field. Full re-sweep: Vehicle 20 / Person 21 / Firearm 15 / Article 16 / Boat 44, matching the pre-rebuild v7.17 count exactly. Note: this tenant sends ORI/Mnemonic=CA1234567 regardless of provider |
| HI_HCJDC_OFML | usx-hi-hcjdc-ofml.mark43.com | DEX-1257 | v4.15 (46 logs) | v4.15 | current (tenant-complete 2026-08-10, ALL-PASS 46/46, four log gates green, inflation 0/0/0/0). DEX-1283 fix: removed the Attention `'X'` — form `initialValue` **and** both KQ/KQN combo `defaults[]`; HI was the last provider carrying it. **The re-sweep's discriminating observation came back POSITIVE: `<Attention>SGAMBELLONE R</Attention>` on 9/9 DH wires with no prefill and no default**, so the `any[]` membership alone feeds the handler and the v2.9 gate-feeder theory is refuted on this provider's own wires. Caveat kept deliberately: the CAD `defaults[]` half of the fix is verified by inspection only — no form-driven log exercises the CAD path |
| NY_NYSPIN_EJUSTICE | usx-ny-nyspin-ejustice.mark43.com | DEX-969 | v4.23 (69 logs) | v4.23 | current (tenant-complete 2026-08-07, ALL-PASS 69/69, four log gates green). DEX-1283 fix landed at v4.21 as a `requestorDH` set[]->any[] demotion, NOT the plain 'X' removal that worked on TX/FL/CA_CLETS -- on NY the field is metadata-mandatory in set[], so set[] membership makes the BROWSER gate Send and v4.20 left DALHOUT permanently unsubmittable. DEX-1284: Purpose Code dropdown reverted (LIMITATION #39, renders empty on this tenant); Vehicle home-state strip kept and live-proven |
| TX_TLETS | usx-tx-tlets.mark43.com | DEX-967 | v4.19 (92 logs) | v4.19 | current (tenant-complete 2026-08-06, ALL-PASS 92/92). DEX-1283 fix: removed initialValue='X' from Attention (DH) + EmailAddress (DL+DH) hidden feeders + matching combo defaults[] -- both confirmed resolving the real officer name/email on the wire with nothing in the source field. Lockstep: TX_TLETS_CCH v1.15 same fix, same day (built + gated, not yet tenant-tested) |
| CA_CLETS | usx-ca-clets.mark43.com | DEX-976 | v2.24 (90 logs) | v2.24 | current (tenant-complete 2026-08-06, ALL-PASS 90/90). DEX-1283 fix: removed initialValue='X' from the Attention (DH) hidden feeder + matching combo defaults[] -- confirmed resolving the real officer name on the wire with nothing in the source field. Full re-sweep matches the pre-rebuild v2.23 count exactly |
| AZ_AZDPS | usx-az-azdps.mark43.com | DEX-974 | **v3.11 (50 logs)** | **v3.11** | **v3.11 IMPORTED + TENANT-VERIFIED 2026-08-12 -- ALL-PASS 50/50** (Veh 9 / Per 21 / Gun 6 / Art 3 / Boat 11), four log gates 50/50, inflation 0/0/0/0. **OUT-OF-STATE DRIVER HISTORY NOW WORKS AND IS WIRE-PROVEN** -- `<State>NJ</State>` on 7 of 7 DH logs, where at v3.9 the hidden AZ-pinned control made it unreachable. `<Attention>SGAMBELLONE R</Attention>` x7 still resolves; Stolen Check on the wire as both Y x10 and N x10; `<UserName>MK43RS</UserName>` 50/50. v3.11 restored the DH State default that v3.10 wrongly dropped (a set[] field with no value gates the browser Send button -- the NY v4.20 mechanism). Prior: v3.10 (cosmetic/layout pass, never swept -- superseded same day). The bump archived the v3.9 package (55 logs -> `logs/<Entity>/_archive_pre_v3.10/`), which is the accepted cost. **The WIRE IS PROVABLY UNCHANGED** -- all three bundles' QIDMs are byte-identical to v3.9, so this is layout and labels only. Prior: **v3.9 IMPORTED 2026-08-11 and SWEPT — ALL-PASS 55/55, first full sweep this provider has ever had.** The install is now **log-proven**, not reported: 55 non-archived v3.9 logs across all 5 entities, attack-B fingerprint 55/55 matching. Prior to today the tenant sat on v3.6. ⚠️ **CORRECTED 2026-08-11: this row previously read "nothing has ever been installed on this tenant", which was FALSE** — three independent artifacts refute it: `docs/reference/TENANT_PICKLISTS.json` is stamped `version=3.6` (a picklist scope capture requires a rendered form in the tenant), `logs/Person/_archive_pre_v3.6/` holds real v3.6 captures (`AZ_AZDPS_v3.6_ACWL.txt`, three DQ guardrail logs, …), and AZ's own BUILD_NOTES says at v3.7 *"Requires a tenant RE-IMPORT: v3.6 is installed and its Person logs are archived as evidence of a mispredicting plan."* The later BUILD_NOTES entries then cite THIS row's wrong claim back as authority ("NOT imported (IMPORT_LEDGER section A: installed = none)") — a records loop, and exactly why a tracking file is a claim and the artifact is the evidence. **v3.6 → v3.9 is a WIRE change** (v3.8 removed the Attention `'X'` and four Vehicle over-permits), so capturing against the installed v3.6 would file v3.9-named logs for a different payload — `audit_log_inflation` attack B by construction. 55 tests owed; first FULL sweep (Person was partially swept at v3.6). **Picklists are v3.6-era and `entities=Vehicle` ONLY** — the other four entities' dropdowns have never been scoped. v3.9 (2026-08-10) = DEX-1284 `NCIC Image` label; v3.8 = DEX-1283 Attention `'X'` removal + four Vehicle over-permits removed. DEX-974 had no JSON attached as of 2026-07-22 and carries no changelog comment to date. Confirm `dexStateUserId` populates on the FIRST query or all 5 badge combos silently fall back |
| OH_LEADS | usx-oh-leads.mark43.com | DEX-990 | none | **v2.4** | **v2.4 NOT imported — nothing ever installed on this tenant.** Tenant URL + DEX number both recovered 2026-08-10: OH was absent from `JIRA_REFERENCE.txt` AND this ledger's DEX column, so DEX-990 "\[OH - LEADS\] USx Provider Build" was found by querying Jira (zero comments on it) and the host came from that ticket's own description. v2.4 = card collapse 14->6 (all titles carry query paths) + ImageQuery BUILT (last unbuilt devdoc-Basic query, autoSelect=false opt-in photo request); v2.3 = DEX-1283 Attention `'X'` + DEX-1284 labels (`License Number`→OLN, 3 image spellings→`NCIC Image`, 3 stolen labels→`Stolen Check`), `[FLAG:validate-imgind-20b-l30]` cleared. **Both v2.3 open items CLOSED at v2.4** — ImageQuery built (7 of 7 devdoc-Basic queries now built) and the cards collapsed 14→6 with every title carrying its query paths. Supported-query extract promoted PROVISIONAL→**CONFIRMED** (gating), 23 PASS / 0 FAIL / 0 WARN |
| IL_LEADS_OFML | usx-il-leads-ofml.mark43.com | DEX-984 | v2.2 (41 logs, ARCHIVED) | **v2.3** | **v2.3 BUILT 2026-08-12 -- RE-IMPORT + full 41-test re-sweep OWED.** Stolen Check now defaults to 'Y' on ALL FOUR entities that carry it (Vehicle/Person/Firearm/Boat), form initialValue AND the combo defaults[] CAD twin on all 8 carrying combos. Safe: any[]-only everywhere, so no routing moved -- IL's Vehicle discriminator is RegistrationState (Z2.P EXISTS vs Z5 NOT_EXISTS) and is untouched. IL was the widest gap of the two non-conformant providers. Prior: **was current — tenant-complete 2026-08-07, ALL-PASS 41/41, four log gates green.** v2.2 imported by Rob and swept the same day: Vehicle 14 / Person 10 / Boat 9 / Firearm 5 / Article 3, 0 FAIL / 0 PENDING. Gates: 6c 41/41 content, 6d 41/41 metadata, 2i 41/41 attribution, plan completeness 5/5 entities. **All three identifier-priority guardrails are now LIVE-PROVEN on the wire**, which matters because v2.2 removed their on-screen hints: plate+VIN → `<LicensePlateNumber>` rides and `<VehicleIdentificationNumber>` is absent; OLN+Name → `<OperatorLicenseNumber>` rides and the literal `<Name` appears **0** times; hull+reg → `<BoatHullIdNumber>` rides and `<RegistrationNumber>` **0**. The cosmetic pass was label-only in fact, not just in intent. **The composite Name still serialises LAST-first** — `<Name>DOE, JOHN</Name>` on all five `Z2.N` logs despite the form now showing First before Last (form order and QIDM `sourceField` order are independent). Tenant picklists captured with v2.2 loaded: 18/18 dropdowns, 0 capture errors; the three 300-row truncation WARNs (`VehicleMakeCode`, `articleTypeCode`, `firearmMake`) were all resolved by live fill during the sweep — `CNST_FORD - FORD`, `BBICYCL - Bicycle`, `11 - 11 mm Mauser` all selected cleanly. Earlier history: v2.1 was installed first (evidenced by the picklist capture returning v2.1-only labels), then v2.2 over it; an early revision of this row wrongly said "no USx tenant provisioned", inferred from this ledger's own silence rather than verified. Capture extension covers this host as of manifest 0.4.0 |

All other providers (CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY,
CA_eSUN, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OR_LEDS, TN_TIES,
TX_TLETS_CCH): **0 logs at any version → never installed on a USx test tenant.** Galvanized/built
in repo, awaiting first tenant import. (OH_LEADS was in this collapsed list until 2026-08-10; it now
has its own row above because its tenant host and DEX ticket were recovered. The others still have no
recorded tenant URL — that is a gap in this ledger, not evidence a tenant does not exist.)

---

## B. Foundation Tenants (customer staging — MANUAL, from import reports)

| Tenant | Provider | Version | Imported | Notes |
|---|---|---|---|---|
| Newark Foundation | NJ_NJCJIS | v4.15 | 2026-08-03 | current — v4.14→v4.15, imported by Rob after the v4.15 re-sweep (36/36 ALL-PASS). Picks up the Boat QBN `RegistrationNumber` fix: a hull search now transmits the reg number instead of silently dropping it (devdoc BoatQuery #1) — wire-proven in that sweep |
| Bert Anzini USx test tenant | NJ_NJCJIS | v4.9 | 2026-07-20 | **frozen on purpose** — CAD-config test only, any valid JSON suffices; do not flag drift |
| Miami Springs Foundation | FL_FCIC | v7.23 | 2026-08-13 | current — v7.18→v7.23, imported by Rob after the v7.23 re-sweep (110/110 ALL-PASS). Picks up v7.19–v7.22 Stolen Check + NCIC Image defaulting to `Y` on all entities, BQ ordered ahead of QB (recovers 2 out-of-state Boat paths), and the v7.23 FBQ `ImageIndicator` over-permit removal |
| North Miami Foundation | FL_FCIC | v7.23 | 2026-08-13 | current — v7.18→v7.23, same import pass as Miami Springs |
| Balcones Heights TX Foundation | TX_TLETS | v4.18 | 2026-08-03 | current — v4.12→v4.18, imported by Rob after the v4.18 re-sweep (89/89 ALL-PASS). Picks up v4.13 dead-RQ removal, v4.14 all-7-Vehicle-combos-reachable (prefills out), v4.15/v4.16 UI, v4.17 QV shadow removal, v4.18 17 dropped optionals |
| Lafayette Parish | LA_LEMS | **NOT OURS — hand-built by engineering** | in service as of 2026-08-13 | **The only tenant in this ledger running a JSON this repo did not build.** Copy held at `providers/LA_LEMS/source/Lafayette Parish LA_LEMS 8.13.2026.json` (Rob, 2026-08-13) as the reference to diff against if Lafayette reports a problem. Our `LA_LEMS_v3.0` is NOT installed anywhere. See the comparison in §B.1 below before answering any Lafayette question |

### B.1 Lafayette Parish LA_LEMS — the hand-built engineering JSON, and how it differs from ours

Recorded 2026-08-13. Rob supplied the deployed file so we can answer Lafayette issue reports against
what is **actually running there**, not against `LA_LEMS_v3.0`, which is installed on no tenant.
Reference copy: `providers/LA_LEMS/source/Lafayette Parish LA_LEMS 8.13.2026.json` (150 KB).

**Do not "fix" our build to match it, and do not treat it as authority.** It is a peer artifact
built by another team from the same devdoc + metadata. Where the two disagree, the devdoc and the
metadata XML decide — not this file. Its value is diagnostic: if Lafayette reports a symptom, the
difference list below is the candidate set.

| | Hand-built (deployed) | Ours (`LA_LEMS_v3.0`) |
|---|---|---|
| Top level | `{bundles[3], behaviors{}}` | `{bundles[3]}` — no `behaviors` |
| Bundle order | **`LA_LEMS` → `ENTITIES` → `RMS`** | `ENTITIES` → `LA_LEMS` → `RMS` |
| `queryLabel` | `LA_LEMS`, `LA_LEMS DL`, `LA_LEMS Driver History` | `Vehicle Registration`, `Driver License`, `Driver History`, … |
| `keyReference` style | concatenated field names (`OperatorLicenseNumberRegistrationStateAttention`) | metadata transaction keyRefs (`DP`, `DQ`, `QWA`, `QWDN`, `KQName`, `QG`, `QA`, `QB`, `BQ`) |
| DL combos | 2 | **4** (QWDN / QWA / DP / DQ) |
| Veh / DH / Boat / Gun / Article combos | 2 / 2 / 2 / 1 / 1 | 2 / 2 / 2 / 1 / 1 |
| DH `Attention` | **wired** — attribute `Attention` ← `Attention`, rule `CommsysGetLastNameFirstNameInitialRuleHandler`, in both combos' `any[]` | **absent from the DH QIDM entirely** |
| DH field isolation | shared pool (`NameLast`, `BirthDate`, …) | DH-suffixed (`NameLastDH`, `BirthDateDH`, …) |
| Boat QIF name | `ENTTIY_Boat` (transposed typo) | `ENTITY_Boat` |

**Four things worth knowing before you use this file:**

1. **It answers our 2 open LA_LEMS enforce FAILs.** `audit_devdoc_combinations` reports
   `DriverHistoryQuery #1` and `#2` as devdoc-listed but UNBUILT because mandatory `Attention` is
   wired nowhere in that query. The deployed JSON wires it exactly the way our own Automated
   Attention standard does (AP #27 feeder pattern, same handler we already run on our LA DL). That
   makes it a worked precedent for the fix — **evidence the shape is accepted in production, not
   authority that it is correct.** Still adjudicate against LA's metadata per `usx-adjudicate`.
2. **`behaviors` is real and in production.** `{"ParallelQuery": {function: parallelQueryHandler,
   isEnabled: false}}` — the top-level block documented in
   `knowledge-base/UNIVERSAL_SEARCH_HANDLERS.txt` that **no repo build emits**. Disabled here, so
   this is not evidence it does anything; it is evidence the platform accepts the key.
3. **ENTITIES is NOT first, and it is deployed. HYPOTHESIS, do not act on it.** CLAUDE.md states
   ENTITIES must be first or forms do not render (confirmed AZ v2.0). Either that rule is narrower
   than written, or Lafayette has a rendering fault nobody has reported. **Do not reorder any
   provider's bundles on the strength of this file.** Discriminating evidence would be a Lafayette
   user confirming the forms render.
4. **Its DL coverage is thinner than ours** (2 combos vs 4). If Lafayette reports "a driver search
   I expect does not run", that gap is the first place to look — not a defect in our build.

Regenerate any of the above with a JSON diff; nothing here is hand-maintained state.

## C. Published JSON — Jira ticket + Confluence catalog (MANUAL, from Rob's confirmation)

The THIRD destination class, added 2026-08-03. A/B above cover tenants; nothing tracked where a JSON
was *published* for other teams to pull, so "which version of FL is in the catalog" was not stale —
it was **unanswerable**, which is worse. Rob attaches the JSON to the DEX ticket and posts it to the
[USx CommSys Data Providers Catalog](https://mark43.atlassian.net/wiki/spaces/SEARCH/pages/6956810378/USx+CommSys+Data+Providers+Catalog);
the MCP tooling cannot attach files, so this is manual in both directions — recorded here on his
confirmation, never inferred from a version bump.

| Provider | Version | Attached to ticket | Posted to catalog | Notes |
|---|---|---|---|---|
| FL_FCIC | v7.23 | DEX-971, 2026-08-13 | 2026-08-13 | after the v7.23 re-sweep (110/110 ALL-PASS); same pass as the Miami Springs + North Miami imports. Release line is DEX-971 comment 790815, EDITED IN PLACE from v7.18 → v7.23 (no sibling comment). Supersedes the v7.18 publish of 2026-08-06 |
| TX_TLETS | v4.18 | DEX-967, 2026-08-03 | 2026-08-03 | after the 89/89 ALL-PASS re-sweep; same pass as the Balcones Heights import |
| NY_NYSPIN_EJUSTICE | v4.23 | DEX-969, 2026-08-07 | 2026-08-07 | after the DEX-1284 closure (69/69 ALL-PASS). Supersedes the v4.19 publish of 2026-08-03. No Foundation tenant carries NY, so there is no section B row to match |
| NJ_NJCJIS | v4.15 | DEX-988, 2026-08-03 | 2026-08-03 | after the 36/36 ALL-PASS re-sweep; same pass as the Newark Foundation import |
| CA_CLETS | v2.24 | DEX-976, 2026-08-06 | 2026-08-06 | after the DEX-1283 fix (90/90 ALL-PASS re-sweep). No Foundation tenant carries CA_CLETS |
| HI_HCJDC_OFML | v4.15 | DEX-1257, 2026-08-10 | 2026-08-10 | Rob's confirmation 2026-08-10: v4.15 JSON attached to DEX-1257 and the catalog updated, in the same pass as the v4.15 changelog + release line (comment 795241). Follows the 46/46 ALL-PASS re-sweep that settled DEX-1283 on the wire (9/9 DH `<Attention>` resolved with no prefill, no default). Supersedes the v4.14 publish of 2026-08-04. No Foundation tenant carries HI |
| HI_HCJDC_OFML | v4.14 | DEX-1257, 2026-08-04 | 2026-08-04 | after the 46/46 ALL-PASS re-sweep. **No version bump** — v4.14 was already published; re-published as the re-verified artifact. Last of the original six |
| IL_LEADS_OFML | v2.2 | DEX-984, 2026-08-10 | 2026-08-10 | Rob's confirmation 2026-08-10. First publish for this provider — DEX-984 had zero comments and zero attachments before today. Follows the 41/41 ALL-PASS first-ever tenant sweep (v2.2) and the DEX-1284 convention pass + card collapse. No Foundation tenant carries IL, so there is no section B row to match |

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

_Last reconciled: 2026-08-07._

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