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
| CA_CLETS | v2.25 | ALL-PASS (109 logs) |
| FL_FCIC | v7.24 | NEVER-TESTED -- 118 test(s) owed |
| HI_HCJDC_OFML | v4.19 | NEVER-TESTED -- 52 test(s) owed |
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

**THREE PROVIDERS AWAIT A TENANT SWEEP, all bumped today to wire middle name + suffix:**
**FL_FCIC v7.24 (118 tests) · HI_HCJDC_OFML v4.19 (52) · IL_LEADS_OFML v2.8 (44)**, plus
**OR_LEDS v2.3** (never tenant-tested). Metadata declares request `Name` with FOUR components
(First/Last/**Middle/Suffix**); middle+suffix had no control, so the officer could not enter them.
Wire-PROVEN on AZ and CA_CLETS: `DOE, JOHN A JR`, degrading cleanly to `DOE, JOHN JR`. FL and OR are
RESTORATIONS -- v7.17/v2.2 deleted those controls as "dead"; the fix was to WIRE them, and Rob
reversed that call on 08-17.
**⚠ IF A FIX IS FOLDED INTO AN ALREADY-BUILT VERSION, REGENERATE THE PLAN BY HAND.** The version does
not move, so `reset_test_package` correctly skips it and the plan silently describes the OLD JSON --
this nearly made the CA_CLETS sweep prove nothing (0 of 90 tests filled middle/suffix). `-Path`, not
`-Provider`. Count the fills BEFORE running, not after.
**HI's sweep also settles C3**: v4.18 had the controls composed but in no `any[]`, and
`audit_wiring_closure` calls that CLOSED. If `<Name>` now carries middle+suffix where 46 v4.18 logs
never could, `any[]` membership is load-bearing and C3 should become BLOCKING.
**Still owed after these: 60 components / 11 providers** -- CA_CONTRA 10 · CA_VENTURA 10 · CA_eSUN 8 ·
OH 6 · OCATS 4 · CA_SLO 4 · LA 4 · MD 4 · NM 4 · TN 4 · NJ 2. Then AZ's owed Jira line.

**⚠ PRODUCTION = TWO LIVE TENANTS: CA_CLETS at MARIPOSA · HI_HCJDC_OFML v4.15 at HDLE.**
A LIVE version is frozen -- a bump is a coordinated re-import, not a repo action. **Mariposa is now
BEHIND (tenant v2.24, repo v2.25) and that is the open production action above.** **HDLE is
deliberately HELD at v4.15** (repo/catalog/ticket v4.18) until the hit block is verified, so there
the artifact is intentionally AHEAD. **Consequence: HDLE production discards NCIC hit content
today.** HDLE Foundation held at v4.15 for the same reason; Mariposa Foundation also owes v2.25.
**Neither LIVE row was discoverable from the repo** -- the capture tool cannot reach these tenants,
so ASK at every import; HDLE LIVE was missed for a day because "foundation and live" read as one.

**JIRA: 4 sections, one comment per RELEASE, EDIT IN PLACE, DRAFT AND WAIT every time.** Full rules
in `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`. Capture the pre-edit body first (`DEX_TICKET_ARCHIVE.md`).

**EXTENSION v0.5.2**: manifest `https://*.mark43.com/rms/*`; the ARM switch replaced the allowlist --
per-host, 8 `requireArmed()` gates, no dialogs. Match patterns CANNOT match a URL hash. **⚡ Fetch
results returns ONLY the last ▶ Run Plan; Chrome may save a SECOND file -- always ingest/analyse ALL.**

## OPEN FINDINGS -- confirmed, unfixed

- **⏸ PAUSED PENDING COMMSYS -- LIMITATION #41: a populated HOME state routes a local plate to
  NLETS** (Mariposa Foundation CA_CLETS: `State=CA` satisfied `NLTS.RQ.P`, not `IA.QV`). Our config
  is provably clean; evidence, both unrun tests and the DO-NOT-APPLY-YET reasoning are in
  `PLATFORM_CONSTRAINTS.txt` #41. **Read it before touching any State field.**
- **`audit_requirement_fidelity` over-permit blind spot.** `vehicleYear` in IL `Z2.P any[]` (metadata
  does not define it there) goes unreported -- control and mutant both 9 branches / 0 OVER. Suspect
  `$shPool` inheriting the sibling VIN branch; not confirmed.
- **HI's NCIC hit block is CONFIG-PRESENT, NOT RENDERING-VERIFIED.** v4.16-v4.18 added 25 QRDM
  attributes; the 46/46 sweep proves the REQUEST unchanged and nothing about the response -- no test
  returned a real hit. Needs ONE deliberate hit query in HI's own tenant (not HDLE); also settles the
  dotted `Hit.Banner` syntax. **Product-level gap:** all 20 providers AND engineering's hand-built
  Lafayette JSON map 0 of 21 such fields.
- **Officer guides are content-poor, not stale** (all 20 regenerate current). HI's says "pick a row"
  when the PLATFORM picks by field content, and never names the discriminator. Rewrite requested.

## ON HOLD / DO NOT RE-RAISE

- **HI PlateType default on a CAD VIN check -- HELD, "may be a cad side fix". DO NOT ADD IT.** Wire
  shows M55S fired correctly; `LicensePlateTypeCode initialValue=''` is the routing discriminator and
  defaulting it kills the in-state plate search (BUILD_RULES 24). KB carve-out also held.
- **CA_CONTRA_COSTA** BLOCKED: `audit_devdoc_combinations` compares ZERO devdoc combos.
  **LA_LEMS PARKED**: real BUILD_RULES 20b WARN, do NOT silence. Rob's call.
- **DH IS NOT SUPPORTED FROM CAD** (Rob 08-12) -- relevant to LIMITATION #41: DH is out of scope for
  the CAD-fills-State question. **`audit_devdoc_optionals` "re-route hole" DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination.** LIVE-PROVEN 38/38.
  Do not narrow fidelity's `$formOnly` without reading it.

## STATE

**0F/0W except** LA_LEMS + CA_CONTRA_COSTA. **`[FLAG:ncic-image-default-y-everywhere]` is 16 -> 2**
(Rob-approved): 10 retired with ZERO JSON change -- 6 build NO ImageIndicator control (rule N/A), 3
already `'Y'`, and **AZ is RULED OUT -- MEASURED** (`'Y'` kills `DQN`+`DQP`, BUILD_RULES 24). **Owed:
MD_METERS + OH_LEADS only** -- Rob-held, a WIRE change so bump + re-sweep each.
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