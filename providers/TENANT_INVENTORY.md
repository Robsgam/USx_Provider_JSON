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

## Findings -- one since EXPLAINED by Rob, three standing

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

**Consequence for tooling — SOLVED in v5:** read each configuration page in a HIDDEN IFRAME.
Same-origin, so the page's own scripts run, the table fills, and the DOM is readable — the
live-DOM result for all 21 from one click, no endpoint archaeology and no manual page loads.
It polls until rows appear and reports `ROWS` / `NO-ROWS-WITHIN-BUDGET` / `ERROR`, because a
fixed delay returning an empty table would recreate the 21-zeros defect with a new cause.

---

# WHAT IS ACTUALLY IMPORTED — full sweep, 2026-09-10

**21 read via iframe · 21 returned rows · 0 timed out · 0 errored.**

| tenant | provider bundle | RMS? | verdict |
|---|---|---|---|
| usx-az-azdps | AZ_AZDPS /18 | yes | ok |
| usx-ca-clets | CA_CLETS /24 | yes | ok |
| usx-ca-clets-ocats | CA_CLETS_OCATS /2 | yes | ok |
| usx-ca-esun | CA_eSUN /48 | yes | ok |
| usx-hi-hcjdc-ofml | HI_HCJDC_OFML /36 | yes | ok |
| usx-il-leads-ofml | IL_LEADS_OFML /3 | yes | ok |
| usx-md-meters | MD_METERS /2 | yes | ok |
| usx-nj-njcjis | NJ_NJCJIS /78 | yes | ok |
| usx-nm-nmlets | NM_NMLETS_OFML /5 | yes | ok |
| usx-ny-nyspin-ejustice | NY_NYSPIN_EJUSTICE /46 | yes | ok |
| usx-oh-leads | OH_LEADS /4 | yes | ok |
| usx-or-leds | OR_LEDS /1 | yes | ok |
| usx-tn-ties | TN_TIES /4 | yes | ok |
| usx-tx-tlets | TX_TLETS /34 | yes | ok |
| usx-fl-fcic | CA_eSUN /41 | NO | ✅ unrelated test (Rob) -- re-import before sweeping |
| **usx-la-lems** | **LA_LETTS_OFML /1** | yes | 🟠 **PRE-RENAME NAME** |
| usx-ca-contra-costa | — | no | none imported |
| usx-ca-san-louis-obispo | — | no | none imported |
| usx-ca-ventura-county | — | no | none imported |
| usx-sc-sled | — | no | none imported (no provider here either) |
| usx (bare) | — | no | none; DEPARTMENT_SETUP_FAILURE |

## ✅ FL_FCIC's TENANT CARRIES CA_eSUN's BUNDLE -- EXPLAINED, NOT A DEFECT

**Rob, 2026-09-10: "fl running esun was a unrelated test".** That closes it. The observation
below is accurate and is kept ONLY so the next sweep does not re-raise it as a discovery --
and because the verification method is worth keeping. The one thing that survives: whoever
re-sweeps FL_FCIC must RE-IMPORT FL first, or the test would drive eSUN's form. Sequencing
note, not a finding.

### The observation and how it was verified

`usx-fl-fcic` (69510828830) carries `ENTITIES/588` + **`CA_eSUN/41`**, and **no RMS bundle**.
There is no `FL_FCIC` bundle on it at all.

**VERIFIED, NOT INFERRED — two independent checks:**
1. **The page identifies itself.** Each configuration page renders its own heading
   `<subdomain> (<deptId>)`. FL's result carries `usx-fl-fcic (69510828830)`, and across all
   21 results **0 headings mismatched their requested id** — so this is not an iframe reading
   a stale or wrong document, which is the failure mode that would fake exactly this.
2. **The bundle id proves shared identity.** Every provider bundle id is unique to one tenant
   (`aqiaric`=AZ, `dvd855o`=CA_CLETS, `dr0eolh`=TX, …) — **except `w7p2cdq`, which appears on
   TWO tenants: `usx-ca-esun` and `usx-fl-fcic`.** Same bundle object, two tenants, different
   versions (48 vs 41). A name collision cannot produce a shared id.

**WHY THIS MATTERS MORE THAN A TIDINESS PROBLEM.** FL_FCIC is recorded here as ALL-PASS 5/5
with 104 logs at v7.24. Those logs were captured when FL's config was loaded. **The tenant no
longer runs it.** Anyone re-testing FL_FCIC today would be driving CA_eSUN's form and
capturing CA_eSUN's wire, filed under FL — the unattributable-log hazard, arriving through the
one door no gate watches: the tenant changing under a green repo.

**Re-import FL before any FL sweep.** Not done here: importing into a tenant is an
outward-facing change and Rob's call, and this file is a record, not an action.

## 🟠 LA_LEMS's TENANT CARRIES THE PRE-RENAME NAME

`usx-la-lems` has `LA_LETTS_OFML/1` — the provider's name **before** the repo renamed it to
`LA_LEMS`. Its `ENTITIES/365` and `RMS/59` are far older than every other tenant (~570-590 and
~70), so this is an ancient import, not a recent mistake. Consistent with LA_LEMS being
NEVER-TESTED in our records: the bundle predates the rename and nothing has been imported since.

## The 4 empty tenants CORROBORATE the record

`usx-ca-contra-costa`, `usx-ca-san-louis-obispo`, `usx-ca-ventura-county` have **no provider
bundle** — and those are exactly three of the providers this repo lists as NEVER-TESTED. Never
imported → nothing to import → no bundle. Independent confirmation of the ledger's
never-imported rows from the platform side, which is the first time that has been possible.
`usx-sc-sled` is empty too and has no provider here at all.
