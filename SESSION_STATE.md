# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-14 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.11 | ALL-PASS (50 logs) |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.23 | ALL-PASS (110 logs) |
| HI_HCJDC_OFML | v4.18 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.7 | ALL-PASS (41 logs) |
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

**NOTHING MID-FLIGHT. 8/20 ALL-PASS, 538 logs, NO PROVIDER OWES A SWEEP.** 7 of 8 are
lifecycle-COMPLETE (release line EDITED IN PLACE + JSON attached + catalog + ledger).
**ONE owed Jira release line: AZ_AZDPS -- the ENTIRE history, nothing ever posted.** DRAFT AND WAIT.
Then **(b)** the HI one-hit verification query (see PRODUCTION below -- highest value outstanding),
**(c)** the officer-guide rewrite, **(d)** the fidelity over-permit blind spot.

**⚠ PRODUCTION = TWO LIVE TENANTS: CA_CLETS v2.24 at MARIPOSA · HI_HCJDC_OFML v4.15 at HDLE.**
A LIVE version is frozen -- a bump is a coordinated re-import, not a repo action. **They are in
OPPOSITE states, both deliberate:** Mariposa is on the CURRENT version; **HDLE is deliberately HELD
at v4.15** (repo/catalog/ticket are v4.18) until the hit block is verified -- so the published
artifact is intentionally AHEAD of the tenant. **Consequence: HDLE production discards NCIC hit
content today**, which is why the one-hit verification query is the highest-value test outstanding.
HDLE Foundation is held at v4.15 for the same reason. Mariposa Foundation = v2.24.
**Neither LIVE row was discoverable from the repo** -- the capture tool cannot reach these tenants,
so ASK at every import; HDLE LIVE was missed for a day because "foundation and live" read as one.

**JIRA: 4 sections, one comment per RELEASE, EDIT IN PLACE, DRAFT AND WAIT every time.** Full rules
in `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`. Capture the pre-edit body first (`DEX_TICKET_ARCHIVE.md`).

**EXTENSION v0.5.2**: manifest `https://*.mark43.com/rms/*`; **the allowlist WAS the safety, the ARM
switch replaced it** -- disarmed per host, 8 `requireArmed()` gates, ZERO browser dialogs. Match
patterns CANNOT match a URL hash. **`__usxCaptureBatch()` returns ONLY the last `__usxRunPlan`** --
two runs back-to-back silently loses the first (cost 3 entity runs on 08-14); run -> capture -> run.

## OPEN FINDINGS -- confirmed, unfixed

- **⏸ PAUSED 2026-08-15 PENDING COMMSYS -- LIMITATION #41: a populated HOME state routes a local
  plate to NLETS.** Seen on a Mariposa **Foundation** CA_CLETS request (`State=CA` + plate satisfied
  the interstate `NLTS.RQ.P`, not in-state `IA.QV`). **Our config is provably clean** -- full evidence,
  both unrun tests, the CA_eSUN handler that fixes it, and the DO-NOT-APPLY-YET reasoning are in
  `knowledge-base/PLATFORM_CONSTRAINTS.txt` LIMITATION #41. **Read that before touching any State
  field.** CA_CLETS is LIVE at Mariposa, so nothing changes without CommSys first.
- **`audit_requirement_fidelity` over-permit blind spot.** `vehicleYear` added to IL `Z2.P any[]`
  (metadata does not define it there) goes unreported -- control and mutant both 9 branches / 0 OVER.
  Reproduced with a control. Suspect `$shPool` inheriting the sibling VIN branch; not confirmed.
- **HI's NCIC hit block is CONFIG-PRESENT, NOT RENDERING-VERIFIED.** v4.16-v4.18 added 25 QRDM
  attributes so wanted/missing-person hit content stops being discarded; the 46/46 sweep proves the
  request unchanged and proves nothing about the response, because no test query returned a real
  hit. Needs ONE deliberate hit query viewed in the RMS UI (HI's own tenant, not HDLE), which also
  settles whether the dotted `Hit.Banner` syntax resolves. **This is a product-level gap, not HI's:**
  all 20 providers AND engineering's independently hand-built Lafayette JSON map 0 of 21 such fields.
- **`firearmMake` driven by no test** on IL -- 41/41 green, zero wire evidence. Fix =
  `TEST_VALUE_OVERRIDES`. Recorded in IL BUILD_NOTES.
- **Officer guides are content-poor, not stale** (all 20 regenerate current). HI's says "pick a row"
  when the PLATFORM picks by field content, and never names the discriminator -- which on HI differs
  per path: plate routes on **Plate Type**, VIN on **State**. Rewrite requested; shape not agreed.

## ON HOLD / DO NOT RE-RAISE

- **HI PlateType default on a CAD VIN check -- HELD, "may be a cad side fix". DO NOT ADD IT.** Wire
  shows M55S fired correctly. `LicensePlateTypeCode initialValue=''` is DELIBERATE -- it is the
  routing discriminator (`RQ` EXISTS vs `M55L` NOT_EXISTS) and defaulting it kills the in-state
  plate search (BUILD_RULES 24). KB carve-out to `feedback_plate_defaults` also held.
- **CA_CONTRA_COSTA** BLOCKED: `audit_devdoc_combinations` compares ZERO devdoc combos.
  **LA_LEMS PARKED**: real BUILD_RULES 20b WARN, do NOT silence. Rob's call.
- **DH IS NOT SUPPORTED FROM CAD** (Rob 08-12) -- relevant to LIMITATION #41: DH is out of scope for
  the CAD-fills-State question. **`audit_devdoc_optionals` "re-route hole" DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination.** LIVE-PROVEN 38/38.
  Do not narrow fidelity's `$formOnly` without reading it.

## STATE

**0F/0W except** LA_LEMS + CA_CONTRA_COSTA. **`[FLAG:ncic-image-default-y-everywhere]` is 16 -> 2**
(2026-08-14, Rob-approved): 10 retired with ZERO JSON change -- **6 of 20 build NO ImageIndicator
control at all** so the rule is N/A, 3 have their only (Person) control already `'Y'`, and **AZ is
RULED OUT -- MEASURED** (`'Y'` kills `DQN`+`DQP`, 2 `set[]`s, BUILD_RULES 24). TAKEN at FL v7.21 /
IL v2.4 / HI v4.17 / **NJ v4.16 / NY v4.24 / TX v4.20 + CCH v1.16** (all wire-proven by ratio
inversion). **Owed: MD_METERS + OH_LEADS only** -- Rob-held, a WIRE change so bump + re-sweep each.
**Expect on EVERY provider's enforce:** `[FAIL] Repo audit` = LA + MD STATUS drift; syncing them is
a back-door mass rebuild.

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