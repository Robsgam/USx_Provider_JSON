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
| CA_CLETS | v2.25 | NEVER-TESTED -- 90 test(s) owed |
| FL_FCIC | v7.23 | ALL-PASS (110 logs) |
| HI_HCJDC_OFML | v4.18 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.7 | PARTIAL -- 1 plan test(s) owed (41 captured) |
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

**CA_CLETS v2.25 -- RE-IMPORT AT MARIPOSA, THEN ONE QUERY TO CONFIRM `<DeviceId>` ARRIVES
POPULATED.** That single request is the only thing that closes a PRODUCTION FAILURE. The CA devdoc
puts the agency-assigned CLETS Terminal Identifier in `<Authentication>/<DeviceId>`, required
wherever mnemonic pooling is used (Mariposa is); without it ConnectCIC silently falls back to the
server IP and the state sees the wrong terminal. Added to **all six** CA providers via
`Build-Auth -IncludeDeviceId` (opt-in, so the 14 non-CA are untouched -- verified). **If `<DeviceId>`
arrives EMPTY the value must be set on the tenant's device-registration record -- a tenant config
action, NOT a JSON one, and NOT grounds to revert.** CA_CLETS's 90 logs are archived; it owes a full
re-sweep and is the ONLY one of the six that does (the other five were never tenant-tested).

**Then: 70 name components 14 providers cannot accept** -- `audit_name_components.ps1` (new
2026-08-17, NOT in enforce yet; it would redden 14 of 20). Metadata declares request `Name` with
First/Last/**Middle/Suffix**; middle+suffix have no control. Rob's order: **FL_FCIC (6) ·
NJ_NJCJIS (2) · IL_LEADS_OFML (2) -- going live soon** (CA_CLETS's 10 landed in v2.25, folded in so
it cost no second archive). Wire-PROVEN, AZ 10 captures: `DOE, JOHN A JR`. Then AZ's Jira line.

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

**EXTENSION v0.5.2**: manifest `https://*.mark43.com/rms/*`; **the allowlist WAS the safety, the ARM
switch replaced it** -- disarmed per host, 8 `requireArmed()` gates, ZERO browser dialogs. Match
patterns CANNOT match a URL hash. **`__usxCaptureBatch()` returns ONLY the last `__usxRunPlan`** --
two runs back-to-back silently loses the first (cost 3 entity runs on 08-14); run -> capture -> run.

## OPEN FINDINGS -- confirmed, unfixed

- **⏸ PAUSED PENDING COMMSYS -- LIMITATION #41: a populated HOME state routes a local plate to
  NLETS** (Mariposa Foundation CA_CLETS: `State=CA` satisfied `NLTS.RQ.P`, not `IA.QV`). Our config
  is provably clean; evidence, both unrun tests and the DO-NOT-APPLY-YET reasoning are in
  `PLATFORM_CONSTRAINTS.txt` #41. **Read it before touching any State field.**
- **`audit_requirement_fidelity` over-permit blind spot.** `vehicleYear` added to IL `Z2.P any[]`
  (metadata does not define it there) goes unreported -- control and mutant both 9 branches / 0 OVER.
  Reproduced with a control. Suspect `$shPool` inheriting the sibling VIN branch; not confirmed.
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