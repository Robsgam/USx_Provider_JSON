# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-18 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.11 | ALL-PASS (58 logs) |
| CA_CLETS | v2.26 | ALL-PASS (111 logs) |
| FL_FCIC | v7.24 | ALL-PASS (118 logs) |
| HI_HCJDC_OFML | v4.20 | ALL-PASS (50 logs) |
| IL_LEADS_OFML | v2.8 | ALL-PASS (44 logs) |
| NJ_NJCJIS | v4.16 | ALL-PASS (40 logs) |
| NY_NYSPIN_EJUSTICE | v4.24 | ALL-PASS (75 logs) |
| TX_TLETS | v4.21 | ALL-PASS (96 logs) |
| _12 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**TX_TLETS v4.21 + NY_NYSPIN_EJUSTICE v4.24 BOTH LIFECYCLE-COMPLETE (all 6 stages).** TX 96/96
(layout convergence, wire `DOE,JOHN A JR`, Jira 800608); NY 75/75 (6 new Person tests, wire
`DOE, JOHN A JR`, Jira 800806 correcting 794205's premature 69/69 claim). Name-parts flag RETIRED on
both. **LA_LEMS v3.1 also now exits 0** -- DP/DQ re-split on State, 20b WARN resolved not silenced.
**OH_LEADS v2.5 DONE** -- NCIC Image closed at ZERO cost (never-tested/never-imported), so that flag is
MD_METERS ONLY. **NEXT: `OR_LEDS v2.3`.** Still owed: 60 name components / 11 NEVER-TESTED providers.
**SEPARATOR IS PER-PROVIDER, NOT A CONVENTION:** TX emits `DOE,JOHN` (no space, TCIC/TLETS Part 1
p125); NY emits `DOE, JOHN` (NCIC form). They MUST differ. See ENGINEERING_STANDARD 4.5.
**THE SWEEP LOOP NOW SELF-REPORTS:** `watch_captures` prints `report_sweep_ledger` (planned/logged/owed
per entity) after EVERY ingest. **Trust that table, not the browser** -- `capture.js` "ALL n manifest
entries captured" only means it drained the manifest, and on 08-18 it said so while 22 Boat tests were
missing. **CHECK THE LEDGER BEFORE ASKING THE OPERATOR TO RE-RUN ANYTHING.** If `worker download failed
... sendMessage` appears, reload the tenant TAB (invalidated `chrome.runtime`); ONE watcher only.

**⚠ PRODUCTION = TWO LIVE TENANTS: CA_CLETS at MARIPOSA · HI_HCJDC_OFML v4.15 at HDLE.**
A LIVE version is frozen -- a bump is a coordinated re-import, not a repo action. **Mariposa Foundation
AND LIVE are BOTH CURRENT at v2.26. HDLE Foundation AND LIVE are deliberately HELD at v4.15**
(repo/ticket v4.20) until the hit block is verified — **so HDLE production discards NCIC hit content
today.** Authority is `report_import_owed.ps1`, NOT this file. **Neither LIVE row was discoverable from
the repo** (the capture tool cannot reach them) -- so ASK at every import.

**JIRA (RULE REVERSED 08-17): 4 sections, one NEW comment per RELEASE -- do NOT edit the previous one.**
Name the superseded comment id in Section 1. DRAFT AND WAIT. Rules: `JIRA_COMMENT_TEMPLATE.txt`.

**EXTENSION v0.5.2**: manifest `https://*.mark43.com/rms/*`; ARM switch, per-host, 8 `requireArmed()` gates. Patterns CANNOT match a URL hash. **Chrome may save a SECOND file (`... (1).json`) -- ingest ALL.**

## OPEN FINDINGS -- confirmed, unfixed

- **⏸ PAUSED PENDING COMMSYS -- LIMITATION #41: a populated HOME state routes a local plate to NLETS**
  (Mariposa CA_CLETS: `State=CA` satisfied `NLTS.RQ.P`, not `IA.QV`). Our config is provably clean;
  evidence + DO-NOT-APPLY-YET reasoning in `PLATFORM_CONSTRAINTS.txt` #41. **Read it before any State field.**
- **`audit_requirement_fidelity` over-permit blind spot:** `vehicleYear` injected into IL `Z2.P any[]` goes unreported (control + mutant both 9 branches). Suspect `$shPool` inheriting sibling VIN.
- **HI's NCIC hit block is CONFIG-PRESENT, NOT RENDERING-VERIFIED.** v4.16-v4.18 added 25 QRDM attrs;
  sweeps prove the REQUEST unchanged, nothing about the response. Needs ONE hit query in HI's OWN tenant
  (not HDLE); settles dotted `Hit.Banner`. **Product gap: all 20 + Lafayette map 0 of 21 such fields.**
- **Officer guides are content-poor, not stale.** HI's says "pick a row" though the PLATFORM picks by field content, never naming the discriminator. Rewrite requested; shape not agreed.
- **NEW 08-18: `audit_log_inflation` attack A COULD NEVER FAIL until today; now 38 UNTRIAGED clone
  groups** (FL 12, NY 10, CA 8, AZ 4, NJ 3, HI 2, IL 1, TX 0). The transaction id appears BOTH as an
  `<Id>` element AND an `id="..."` ATTRIBUTE, so no two logs ever hashed alike; also its default scope
  was a hardcoded SIX, so AZ+IL had never been examined. Both fixed; keyed on wire+fills so a PASSING
  guardrail is not mis-flagged. NOT blocking (no orchestrator runs it). They are duplicate/vacuous
  guardrails and clear at each provider's own rebuild via the `emit_test_plan` fix -- never a sweep.
- **CLOSED 08-18, do not re-raise:** the 28 TX/TX_CCH `ImageIndicator=Y` constraint triggers (12 of 14 were the gate applying a DH-scoped devdoc line portfolio-wide; the 2 real ones are wire-proven satisfied). Reasoning in TX's v4.21 BUILD_NOTES. **COMMSYS ASKS ARE ON HOLD (Rob 08-18)** -- LA's devdoc PurposeCode/State inversion is recorded, NOT owed, do NOT raise.


## ON HOLD / DO NOT RE-RAISE

- **HI PlateType default on a CAD VIN check -- HELD, "may be a cad side fix". DO NOT ADD IT.** Wire
  shows M55S fired correctly; `LicensePlateTypeCode initialValue=''` is the routing discriminator and
  defaulting it kills the in-state plate search (BUILD_RULES 24). KB carve-out also held.
- **CA_CONTRA_COSTA** BLOCKED: `audit_devdoc_combinations` compares ZERO devdoc combos.
  **LA_LEMS PARKED**: real BUILD_RULES 20b WARN, do NOT silence. Rob's call.
- **DH IS NOT SUPPORTED FROM CAD** (Rob 08-12), so it is out of scope for LIMITATION #41's CAD-fills-State question. **`audit_devdoc_optionals` re-route hole DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination** (LIVE-PROVEN 38/38) -- do
  not narrow fidelity's `$formOnly` without reading it. **CA_CLETS purpose-code dropdown: CLOSED (#39).**
- **SHELVED 08-17, DO NOT ACT:** LIVE CA_eSUN export uses `DEX_INQUIRY_PURPOSE_CODE` (#39 calls it
  EMPTY-rendering), no initialValue, `clearOnSubmit`, no `defaults[]` -> supplies NO PC to a CAD query.

## STATE

**0F/0W except** LA_LEMS + CA_CONTRA_COSTA. **`[FLAG:ncic-image-default-y-everywhere]` 16 -> 1, MD_METERS
ONLY** -- OH_LEADS v2.5 closed it (Rob-held elsewhere: a WIRE change = bump + re-sweep. AZ RULED OUT, MEASURED).
**LA + MD STATUS DRIFT IS RESOLVED (08-18, Rob-approved doc sync): repo audit 352 PASS / 0 FAIL, and
enforce can reach exit 0 again -- it had been blocking ALL 20.** LA's STATUS now shows its real score.
**`[FLAG:nameparts-untested-unfrozen]` now TX_TLETS_CCH ONLY** (HI/TX/NY retired on wire evidence).
**"95%" IS DEFINED — `ENGINEERING_STANDARD.md` §5.1 (Rob 08-18): 19/20 providers LIFECYCLE-COMPLETE;
today 8/20 = 40%** (AZ, CA_CLETS, FL, HI, IL, NJ, NY, TX). NOT the gate pass-rate. Stage 4 needs stage
6 first, so `report_import_owed.ps1` IS the roadmap; advisory residue moves it 0.
**Wired 08-18:** `audit_layout_flow` -> enforce **2w ADVISORY**; `report_sweep_ledger` -> every ingest.

## RULES I HAVE BROKEN -- READ FIRST (`usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c)

- **PRINT THE OBJECT'S KEYS BEFORE PROBING IT.** Confident-empty wrong paths: `$cb.defaults` (really
  `.requirements.defaults`), `.PSObject.Properties` on an ARRAY, `PENDING_UPDATES.txt` in the provider
  root (it is `docs/tracking/`), `$qif.layouts` (it is `.layout`). **`@($null).Count` IS 1** -- and on
  08-18 that made QMF's empty `attributes` read as populated, so my "fix" broke all 6 providers.
- **ADD A CONTROL; a finding across MANY providers -- or one contradicting a gate -- is usually YOUR
  PROBE.** A "portfolio-wide harness defect" was my probe. **NEVER read `[0]` and generalise.**
- **A CHECK MUST NOT MATCH ITS OWN TEXT**, and **VERIFY THE VERIFIER**: `node` is not installed, so
  `node --check` is a vacuous pass. **A ZERO IS NOT A MEASUREMENT until that same probe has produced a
  NON-ZERO on a known case.** 3x on 08-18: counted `[WARN]` in a tool emitting none; `'...$'` on a
  multi-line blob cannot match a mid-string line (needs `(?m)` or split-then-match); and **I blamed a
  defect on the work I touched last -- `git log -S` put the `MI` labels 3 weeks earlier.**
- **READ THE GATE VERDICT BEFORE COMMITTING, not in the same command.** A shared-tool change
  reddening another provider gets a FLAG, never a fix (8c). **REPLACE, never append.**
