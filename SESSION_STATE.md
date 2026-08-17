# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-17 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.11 | ALL-PASS (58 logs) |
| CA_CLETS | v2.26 | ALL-PASS (111 logs) |
| FL_FCIC | v7.24 | ALL-PASS (118 logs) |
| HI_HCJDC_OFML | v4.20 | ALL-PASS (50 logs) |
| IL_LEADS_OFML | v2.8 | NEVER-TESTED -- 44 test(s) owed |
| NJ_NJCJIS | v4.16 | ALL-PASS (40 logs) |
| NY_NYSPIN_EJUSTICE | v4.24 | ALL-PASS (69 logs) |
| TX_TLETS | v4.20 | ALL-PASS (92 logs) |
| _12 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**TWO SWEEPS OWED: `IL_LEADS_OFML v2.8` (44) · `OR_LEDS v2.3`.** DONE 08-17:
**FL_FCIC v7.24** (118/118, all 4 log gates green), **CA_CLETS v2.26** (111/111 --
`<CaRequestPurposeCode>C` + `<PurposeCode>I` in ONE request, impossible before) and
**HI_HCJDC_OFML v4.20** (50/50 -- 0 malformed `<Name>`, 0 on KQN, all four shapes on KQ/DQ).
Import queue: `tools\report_import_owed.ps1`. **FL owes Jira (last post v7.23, comment 790815) + a
ledger line.** **OR is a RESTORATION** — v2.2 deleted middle/suffix as "dead"; the fix was to WIRE
them, and Rob reversed that call on 08-17.
**⚡ Fetch results ONLY returns the LAST ▶ Run Plan, and it can miss the run's TAIL** — FL Firearm
fetched 11 of 15 (T59-T62 absent, dex-log rows had not rendered). Fetch after EVERY entity, ~10s
after "plan run complete", and DIFF the plan against the logs before calling an entity done.
**C3 IS STILL UNSETTLED and HI can no longer settle it.** The v4.19 sweep could not decide whether
`any[]` membership is REQUIRED for a composite `sourceField` to reach the wire, because v4.18 never
had a test that FILLED middle/suffix (frozen resolver) -- so there is no v4.18 wire to compare. What
is proven is only that control + sourceField + any[] works. Deciding it needs a deliberate probe on a
provider still composed-but-not-in-any[]; after v4.20 HI is not one.
**⚠ IF A FIX IS FOLDED INTO AN ALREADY-BUILT VERSION, REGENERATE THE PLAN BY HAND** (`-Path`, not
`-Provider`) — the version does not move, so `reset_test_package` skips it and the plan describes the
OLD JSON. Count the fills BEFORE running. **Still owed after these: 60 name components / 11 providers.**

**⚠ PRODUCTION = TWO LIVE TENANTS: CA_CLETS at MARIPOSA · HI_HCJDC_OFML v4.15 at HDLE.**
A LIVE version is frozen -- a bump is a coordinated re-import, not a repo action. **Mariposa was
re-imported to v2.25 on 08-17 (Foundation AND LIVE) and the repo has since moved to v2.26, so it is
behind again -- a SECOND production re-import in one day is Rob's call, not a repo action.** **HDLE is
deliberately HELD at v4.15** (repo/catalog/ticket v4.18) until the hit block is verified, so there
the artifact is intentionally AHEAD. **Consequence: HDLE production discards NCIC hit content
today.** HDLE Foundation held at v4.15 for the same reason; Mariposa Foundation also owes v2.25.
**Neither LIVE row was discoverable from the repo** -- the capture tool cannot reach these tenants,
so ASK at every import; HDLE LIVE was missed for a day because "foundation and live" read as one.

**JIRA (RULE REVERSED 08-17): 4 sections, one NEW comment per RELEASE -- do NOT edit the previous one.**
Name the superseded comment id in Section 1. DRAFT AND WAIT. Rules: `JIRA_COMMENT_TEMPLATE.txt`.

**EXTENSION v0.5.2**: manifest `https://*.mark43.com/rms/*`; the ARM switch replaced the allowlist --
per-host, 8 `requireArmed()` gates, no dialogs. Match patterns CANNOT match a URL hash. **⚡ Fetch
results returns ONLY the last ▶ Run Plan; Chrome may save a SECOND file -- always ingest/analyse ALL.**

## OPEN FINDINGS -- confirmed, unfixed

- **⏸ PAUSED PENDING COMMSYS -- LIMITATION #41: a populated HOME state routes a local plate to
  NLETS** (Mariposa Foundation CA_CLETS: `State=CA` satisfied `NLTS.RQ.P`, not `IA.QV`). Our config
  is provably clean; evidence, both unrun tests and the DO-NOT-APPLY-YET reasoning are in
  `PLATFORM_CONSTRAINTS.txt` #41. **Read it before touching any State field.**
- **`audit_requirement_fidelity` over-permit blind spot:** `vehicleYear` injected into IL `Z2.P any[]`
  goes unreported (control + mutant both 9 branches / 0 OVER). Suspect `$shPool` inheriting the
  sibling VIN branch.
- **HI's NCIC hit block is CONFIG-PRESENT, NOT RENDERING-VERIFIED.** v4.16-v4.18 added 25 QRDM
  attributes; the 46/46 sweep proves the REQUEST unchanged and nothing about the response -- no test
  returned a real hit. Needs ONE deliberate hit query in HI's own tenant (not HDLE); also settles the
  dotted `Hit.Banner` syntax. **Product-level gap:** all 20 providers AND engineering's hand-built
  Lafayette JSON map 0 of 21 such fields.
- **Officer guides are content-poor, not stale.** HI's says "pick a row" when the PLATFORM picks by
  field content and never names the discriminator. Rewrite requested; shape not agreed.

## ON HOLD / DO NOT RE-RAISE

- **HI PlateType default on a CAD VIN check -- HELD, "may be a cad side fix". DO NOT ADD IT.** Wire
  shows M55S fired correctly; `LicensePlateTypeCode initialValue=''` is the routing discriminator and
  defaulting it kills the in-state plate search (BUILD_RULES 24). KB carve-out also held.
- **CA_CONTRA_COSTA** BLOCKED: `audit_devdoc_combinations` compares ZERO devdoc combos.
  **LA_LEMS PARKED**: real BUILD_RULES 20b WARN, do NOT silence. Rob's call.
- **DH IS NOT SUPPORTED FROM CAD** (Rob 08-12), so it is out of scope for LIMITATION #41's CAD-fills-State question. **`audit_devdoc_optionals` re-route hole DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination** (LIVE-PROVEN 38/38) -- do
  not narrow fidelity's `$formOnly` without reading it. **CA_CLETS purpose-code dropdown: CLOSED (#39).**

## STATE

**0F/0W except** LA_LEMS + CA_CONTRA_COSTA. **`[FLAG:ncic-image-default-y-everywhere]` 16 -> 2, owed on
MD_METERS + OH_LEADS ONLY** (Rob-held; a WIRE change, so bump + re-sweep each. AZ is RULED OUT -- MEASURED).
**Expect on EVERY provider's enforce:** `[FAIL] Repo audit` = LA + MD STATUS drift; syncing them is
a back-door mass rebuild. **`[FLAG:nameparts-untested-unfrozen]` pending on HI/NY/TX/TX_CCH.**

## RULES I HAVE BROKEN -- READ FIRST (`usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c)

- **PRINT THE OBJECT'S KEYS BEFORE PROBING IT.** Four wrong paths in one day, each producing a
  confident empty answer: `$cb.defaults` (really `.requirements.defaults`), `.PSObject.Properties`
  on an ARRAY, `PENDING_UPDATES.txt` in the provider root (it is `docs/tracking/`), picklist options
  (`entities.<E>.fields.<id>.options`).
- **ADD A CONTROL; a finding across MANY providers -- or one that contradicts a gate -- is usually
  YOUR PROBE.** A "portfolio-wide harness defect" was my probe (a byte-identical copy with a different
  FILENAME also scored 0). **NEVER read `[0]` and generalise:** on 08-15 I checked 1 of 9
  `RegistrationState` controls and declared the field blank -- right by luck, wrong by method.
- **A CHECK MUST NOT MATCH ITS OWN TEXT**, and **VERIFY THE VERIFIER**: `node` is not installed, so
  `node --check` is a vacuous pass; prove a probe can FAIL before trusting its green.
- **READ THE GATE VERDICT BEFORE COMMITTING, not in the same command.** A shared-tool change
  reddening another provider gets a FLAG, never a fix (8c). **REPLACE, never append.**
