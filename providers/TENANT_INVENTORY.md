# USx TENANT INVENTORY — measured from the support-admin department list

**Source:** `demo.mark43.com/rms/api/support/admin/departments`, read 2026-09-10 in Rob's
authenticated browser via `automation/extension/admin_probe.js` (READ-ONLY, GET only).
**NOT hand-maintained.** Re-derive it by clicking the admin panel's tenant-list button; do not
edit these ids by hand.

## Why this file exists

`IMPORT_LEDGER.md` section A carried tenant URLs that were **remembered, not derived**, and
CA_eSUN had none at all — I flagged that gap rather than guessing `usx-ca-esun.mark43.com`
from the naming pattern. This inventory settles it from the platform's own list.

**The host lists 1,785 departments.** Filtering `subdomain has: usx` matched **21**, which is
our fleet plus two surprises. Every row below is a `(departmentId, subdomain, status)` triple
read straight from the table's ID / Subdomain / Status columns.

## The 21 `usx-*` departments

| departmentId | subdomain | status | our provider |
|---|---|---|---|
| 69585917479 | usx-az-azdps | Test | AZ_AZDPS |
| 69586234535 | usx-ca-clets | Test | CA_CLETS |
| 72322272044 | usx-ca-clets-ocats | Test | CA_CLETS_OCATS |
| 69586006831 | usx-ca-contra-costa | Test | CA_CONTRA_COSTA |
| **69510509021** | **usx-ca-esun** | Test | **CA_eSUN** — the id in the URL Rob supplied |
| 69586091660 | usx-ca-san-louis-obispo | Test | CA_SAN_LUIS_OBISPO — ⚠️ see spelling note |
| 69510611328 | usx-ca-ventura-county | Test | CA_VENTURA_COUNTY |
| 69510828830 | usx-fl-fcic | Test | FL_FCIC |
| 69510710914 | usx-hi-hcjdc-ofml | Test | HI_HCJDC_OFML |
| 69510394285 | usx-il-leads-ofml | Test | IL_LEADS_OFML |
| 69510242248 | usx-la-lems | Test | LA_LEMS |
| 69509976793 | usx-md-meters | Test | MD_METERS |
| 69509881306 | usx-nj-njcjis | Test | NJ_NJCJIS |
| 69586413893 | usx-nm-nmlets | Test | NM_NMLETS_OFML |
| 69509789559 | usx-ny-nyspin-ejustice | Test | NY_NYSPIN_EJUSTICE |
| 69509682080 | usx-oh-leads | Test | OH_LEADS |
| 69586491910 | usx-or-leds | Test | OR_LEDS |
| 69586333849 | usx-tn-ties | Test | TN_TIES |
| 69509542782 | usx-tx-tlets | Test | TX_TLETS |
| **73046844870** | **usx-sc-sled** | Test | ⚠️ **NO PROVIDER IN THIS REPO** |
| 69987555758 | usx (bare) | **DEPARTMENT_SETUP_FAILURE** | none — broken tenant |

## Four findings, none of them guesses

1. **CA_eSUN's tenant is `usx-ca-esun` / 69510509021.** That is the exact department id from
   the configuration URL Rob supplied, so the mapping is confirmed rather than inferred. The
   `IMPORT_LEDGER.md` section A row previously read *"tenant URL NOT RECORDED — confirm and
   fill; I will not invent one"*. (For the record: the pattern-guess would have been right.
   Refusing to guess still cost nothing and the evidence took one click.)

2. **`usx-sc-sled` (73046844870) has a tenant and NO provider here.** South Carolina SLED.
   Nothing in `providers/`, nothing in the devdoc set, no mention in CLAUDE.md. Whether that
   is a future provider, someone else's work, or an abandoned provision is **Rob's call** —
   recorded, not acted on.

3. **TX_TLETS_CCH has NO tenant.** There is no `usx-tx-tlets-cch` row. Consistent with the
   standing PARKED ruling (Rob 2026-08-21, "no tenant need") — so the absence corroborates the
   record instead of contradicting it.

4. ⚠️ **THE SUBDOMAIN MISSPELLS SAN LUIS OBISPO: `usx-ca-san-louis-obispo`** ("louis", not
   "luis") while the provider is `CA_SAN_LUIS_OBISPO`. Any mapping that derives a hostname
   from the provider name by lower-casing and hyphenating will MISS this one. It is the
   platform's spelling and not ours to fix; it has to be handled as data.

## The bundle table — and why a fetch-based sweep reports 21 confident zeros

The per-department page `…/departments/configurations/<deptId>` carries a table with headers
**`ID | Name | Version`**, and that is the "is a JSON imported" answer. For CA_eSUN:

| ID | Name | Version |
|---|---|---|
| tfas8xq | ENTITIES | 590 |
| w7p2cdq | CA_eSUN | 48 |
| 0ydnyze | RMS | 70 |

That is exactly the mandated 3-bundle structure (ENTITIES / PROVIDER / RMS).

⚠️ **THE TABLE IS JAVASCRIPT-POPULATED, AND THIS IS THE TRAP.** The SAME page returns
**rowCount 0 when FETCHED** and **rowCount 3 from the LIVE DOM**. A fetch does not execute
scripts, so a fetch-based sweep across all 21 produced 21 empty tables — twenty-one confident
zeros that looked like "no tenant has a JSON imported". Proven by running both paths against
one page (department 69510509021) minutes apart.

⚠️ **`Version` IS A PLATFORM BUNDLE COUNTER, NOT OUR JSON VERSION.** 590 / 48 / 70 are not
`v3.3`. Do NOT read this column as the provider JSON version, and do not use it to answer
"which version is installed" — that remains what `logs/` proves for a provider tenant. What
the table DOES establish is *whether* a provider bundle is present and under what name.

**Consequence for tooling:** either read each page's live DOM (21 page loads), or find the
endpoint the page's JS calls and sweep that. `admin_probe.js` v4 reports the candidate URLs a
configuration page's own scripts reference (reported, never called) so the second route can be
built from evidence.
