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

---

# VERSION CATALOGUE — read off the tenants, 2026-09-10

**Method:** the extension clicks each configuration page's own **Export JSON** control in a
hidden iframe and reads the version out of the exported bundle's `description`
(`"Provider configuration for <P> v<X.Y>"`). 11 requested, **10 version strings read**.

⚠️ This is the ONLY way to get our version. The bundle table's `Version` column is a
platform counter (see above), and there is no API endpoint to harvest.

| tenant | provider | **MEASURED** | ledger claims | verdict |
|---|---|---|---|---|
| **newarkpd-foundation** | NJ_NJCJIS | **v4.16** | **v4.17** | 🔴 **DRIFT** |
| practice-bertanzini | NJ_NJCJIS | v4.9 | v4.9 | agrees (frozen on purpose) |
| miamispringspd-foundation | FL_FCIC | v7.24 | v7.24 | agrees |
| northmiami-foundation | FL_FCIC | v7.24 | v7.24 | agrees |
| homesteadpd-fl-foundation | FL_FCIC | v7.24 | v7.24 | agrees |
| balconesheightspd-foundation | TX_TLETS | v4.22 | v4.22 | agrees |
| hdle-foundation | HI_HCJDC_OFML | v4.15 | v4.15 | agrees (held by decision) |
| mariposacso-foundation | CA_CLETS | v2.27 | v2.27 | agrees |
| mariposacso **(LIVE)** | CA_CLETS | v2.27 | v2.27 | agrees |
| aurorapd-il-foundation | IL_LEADS_OFML | v2.8 | v2.8 | agrees |
| lafayettesheriff-la **(LIVE)** | — | **(no version string)** | "not ours — hand-built" | ✅ **CONFIRMS** |

**agrees = 10 · drift = 1**

## 🔴 NEWARK FOUNDATION RUNS v4.16 WHILE THE LEDGER CLAIMS v4.17

The ledger's Newark row reads *"**v4.17** | **2026-08-20** | current — **v4.16 → v4.17,
imported by Rob and reported same day**"*. The tenant reports **v4.16**.

**TWO INDEPENDENT SIGNALS AGREE, which is why this is stated as a finding rather than a
suspicion:**
1. **The version string** in Newark's exported bundle description: `v4.16`.
2. **The platform bundle counter, from a different column entirely.** Our own
   `usx-nj-njcjis` tenant runs repo v4.17 and reports `NJ_NJCJIS/78`. Newark reports
   `NJ_NJCJIS/77` — exactly one import behind. And `practice-bertanzini`, deliberately
   frozen at v4.9, reports `74`. The counter increments per import and orders the three
   tenants exactly as their version strings do.

So either the v4.17 import to Newark did not take, was rolled back, or was reported as
intent rather than completion. **Which of those is Rob's to say — this file records the
measurement, not the cause.** Not fixed here: importing is an outward-facing change.

**This is what the whole exercise was for.** Section B is maintained by hand from verbal
reports because "the capture tool can't reach them", and nothing could check it. First full
run, first real drift — on a Foundation tenant, three weeks old.

### The counter hypothesis now has SEVEN confirmations and exactly ONE contradiction

When the full census correlated every ledger row to its platform subdomain (2026-09-10), the
platform counter could be checked against the ledger's own version claims across tenants that
should agree -- an independent test I could not run with one tenant at a time:

| ledger claims | tenants | counter |
|---|---|---|
| FL_FCIC v7.24 | Miami Springs, North Miami, Homestead | **all `/114`** |
| CA_CLETS v2.27 | Mariposa Foundation, Mariposa LIVE | **both `/24`** |
| HI_HCJDC_OFML v4.15 | HDLE Foundation, HDLE LIVE | **both `/32`** |

Seven tenants, three providers, three separate import dates: **same claimed version, same counter,
every time.** The counter is therefore a usable proxy for "same config generation" -- NOT for a
version number, which it still cannot give (Anzini reads `74` having been imported once, so it is
not a per-tenant import count either).

Against that, ONE contradiction: **Newark reads `77` while our own `usx-nj-njcjis` tenant, on repo
v4.17, reads `78`.** The rule holds in all seven cases where the ledger is right and breaks in the
one case where the version string already said it was wrong. That is corroboration, not a second
finding -- and it is why the Newark row above is stated as a measurement rather than a suspicion.

## ✅ LAFAYETTE CONFIRMS THE LEDGER BY WHAT IS *MISSING*

`lafayettesheriff-la` exported a bundle named `LA_LEMS` (counters `ENTITIES/358 LA_LEMS/22
RMS/10`) but carries **NO** `"Provider configuration for …"` description. Our builds always
carry it — the convention exists because the platform rejects a top-level `version` field.
Its **absence is positive evidence** that this is not our build, which is exactly what the
ledger says: *"NOT OURS — hand-built by engineering"*. A gap in the data confirming a
documented fact is the cheapest kind of verification there is.

(Note the contrast with our own `usx-la-lems` test tenant, which carries `LA_LETTS_OFML/1` —
the pre-rename name, and a different bundle entirely.)

## The 4 empty tenants CORROBORATE the record

`usx-ca-contra-costa`, `usx-ca-san-louis-obispo`, `usx-ca-ventura-county` have **no provider
bundle** — and those are exactly three of the providers this repo lists as NEVER-TESTED. Never
imported → nothing to import → no bundle. Independent confirmation of the ledger's
never-imported rows from the platform side, which is the first time that has been possible.
`usx-sc-sled` is empty too and has no provider here at all.

---

# PHASE 2 — EVERY TENANT'S ACTUAL VERSION, READ FROM ITS OWN EXPORT (2026-09-11)

Rob: *"i thought you were supposed to export every json you find."* All **64** carrier tenants
swept via the Export JSON control. **0 UNRESOLVED** — every one reached a verdict. Full table:
`providers/TENANT_VERSION_REPORT.txt`, regenerate with `tools\ingest_tenant_versions.ps1`.

**32 VERSION-READ · 32 EXPORTED-BUT-NO-VERSION-STRING · 0 unresolved.**

## The probe was checked before the findings were believed

32 of 64 reading "not our build" is the shape that usually means a broken probe, so the
denominator was measured first. **Truncation ruled out:** `probeExportControls` caps a blob at
400,000 chars and *nothing reached it* — the no-version blobs top out at 245,253 bytes while
blobs that read fine reach 332,297. **Mechanism proven working:** `usx-nj-njcjis` reads
**v4.17 = repo v4.17**. So a tenant reading OLDER than the repo is a real measurement.

## 🔴 THREE PROVIDER TENANTS ARE BEHIND THEIR OWN COMMITTED LOGS — NEEDS A RULING

| Provider tenant | Tenant exports | Repo | Committed logs stamped | Logs |
|---|---|---|---|---|
| `usx-ny-nyspin-ejustice` | **v4.24** | v4.26 | **v4.26** | 65 |
| `usx-hi-hcjdc-ofml` | **v4.19** | v4.20 | **v4.20** | 48 |
| `usx-or-leds` | **v2.5** | v2.6 | **v2.6** | 27 |

`.test_version` reads the repo version on all three, and `reset_test_package` archives prior
logs on a bump — so current-version logs exist for a version the tenant does not appear to be
running. CLAUDE.md treats a provider tenant's newest non-archived `logs/` as *"proof of what's
installed there, self-verifying"*. **On these three that premise is contradicted.**

TWO CANDIDATE EXPLANATIONS, NEITHER CONFIRMED — do not act on one without the test below:
1. The log header's version stamp is written from the **repo** version at ingest time, not from
   what the tenant actually ran. If so, no log anywhere proves which build produced its wire,
   and that is a gate gap, not a provider defect.
2. A partial/failed re-import left the PROVIDER bundle at the older build.

DISCRIMINATING TEST (cheap, one tenant): re-export `usx-ny-nyspin-ejustice` retaining the full
blob and count how many distinct `Provider configuration for … v…` strings it holds. The sweep
regex stops at the FIRST non-RMS match, so a tenant carrying both v4.24 and v4.26 descriptions
would report v4.24 and my read would be the artifact. `keepFull` was not set on this run, so the
blob is gone — this cannot be settled from the saved file.

## The hand-built LA_LEMS is on ~24 tenants, not one

The ledger records ONE hand-built LA_LEMS (`lafayettesheriff-la`). The sweep finds the same
no-version-string LA_LEMS lineage across **24 tenants**, in exactly **4 byte-identical groups**:

| fullBytes | tenants | what |
|---|---|---|
| 165,447 | 13 `*-demo` tenants | one seeded demo config |
| 165,523 | `justin-demo`, `cbp-demo`, `dea-demo` | a second seeded config |
| 163,687 | `lafayettesheriff-la`, `lafayettela-sherifftraining` | the ledger's hand-built pair |
| 163,602 | `neworleanspd`, `neworleanspd-foundation` | New Orleans LIVE + foundation |

Identical byte counts = one config copied, not 24 installs. This is what the earlier
"LA_LEMS 1 → 22" reconciliation was actually counting. **None carry our version string**, so
our `LA_LEMS` v3.2 is still on no tenant anywhere — the ledger is right.

## Newly measured, absent from the ledger (our build, real version)

| Tenant | Provider | Tenant | Repo | |
|---|---|---|---|---|
| `ny-nycapss-foundation` | NY_NYSPIN_EJUSTICE | v4.24 | v4.26 | byte-identical to `usx-ny-nyspin-ejustice` (258,341 / ENTITIES-574 NY-46 RMS-70) |
| `onscene` | HI_HCJDC_OFML | v4.15 | v4.20 | |
| `lakewoodoh-foundation` | OH_LEADS | v2.11 | v2.11 | current |
| `amyblair` | FL_FCIC | v7.18 | v7.24 | |
| `qa-amyblair-test`, `qa-amyb-test` | IL_LEADS_OFML | v2.8 | v2.8 | current |

⚠️ `ny-nycapss-foundation` being byte-identical to our NY test tenant does **NOT** identify what
NY CAPSS is, and must **NOT** be used to close the ledger's unlocated "Albany County NY
Foundation" row. That remains `_needsHumanInput` in `tools/config/tenant_map.json`.

## SDSO: the "eSUN v1.0" claim is NOT corroborated by the tenant

`sdso` and `sandiegoso-foundation` are byte-identical (244,743 / `ENTITIES/315 CA_eSUN/42`) and
carry **no version string at all**. SESSION_STATE says *"SDSO LIVE runs eSUN v1.0 vs repo v3.3"*.
This read cannot confirm v1.0 — it can only say the installed config is **not one of our builds**.
Whatever "v1.0" came from, it did not come from the tenant. Same for `sandiegoharborpd-foundation`
(`CA_eSUN/18`) and `fullwooddemo` (`CA_eSUN/30`).

## Already-adjudicated, NOT re-raised

- `usx-fl-fcic` carries `ENTITIES/588 CA_eSUN/41` and no FL_FCIC bundle. **Rob ruled this an
  unrelated test on 2026-09-10 and the finding was retracted.** Recorded here only so the next
  sweep does not rediscover it as an alarm. `practice-robsgambellone` is byte-identical to it.
- `newarkpd-foundation` v4.16 vs ledger v4.17 — confirmed again; Rob's call, unchanged.
- `lafayettesheriff-la` — no version string, CONFIRMS the ledger's "not ours".
- `gordo` carries `HI_HCJDC` (not `HI_HCJDC_OFML`) and `ccpd`/`ccpd-jms-migration-round-1` carry
  `RecordsArchive` — bundle names that are not ours, no version string.

## Cost note for the next sweep

The panel says "~2s each". **It is up to ~24s each** — `probeExportControls` runs two 12-second
budgets back to back (wait-for-table, then watch-after-click), and the second exits early only if
a `<pre>`/`<textarea>` appears or the page grows 2000+ chars. 64 tenants took ~50 minutes. The
`Refused to set unsafe header "Cookie"` console lines are the department page's own jQuery
(`fsRequest` → `loadDepartmentBundles`) and cost nothing — they are not the slowness.
