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
| NY_NYSPIN_EJUSTICE | v4.24 | NEVER-TESTED -- 69 test(s) owed |
| TX_TLETS | v4.20 | NEVER-TESTED -- 92 test(s) owed |
| _12 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**NOTHING MID-FLIGHT.** **TWO owed Jira release lines, not four** (`audit_lifecycle` stage 5, all 8
verified against the LIVE tickets): **HI_HCJDC_OFML** v4.16-v4.18 (posted at v4.15/795241) and
**AZ_AZDPS** the ENTIRE history (nothing ever posted). DRAFT AND WAIT, separately. **6 of 8 are
lifecycle-COMPLETE.** Then **(b)** the officer-guide rewrite, **(c)** the fidelity over-permit blind
spot. **TX v4.19 catalog question CLOSED** (Rob 2026-08-14: catalog is v4.19) -- section C was stale,
not a real gap; TX is now aligned on every axis. **6 of 8 lifecycle-COMPLETE.**

**8/20 ALL-PASS, 538 logs. NO PROVIDER OWES A SWEEP** -- HI v4.18 closed the last (46/46, three
bumps in one sweep). FL v7.23 and IL v2.7 are lifecycle-COMPLETE: release line posted (EDITED IN
PLACE -- FL 790815, IL 795242), JSON attached, catalog updated, ledger recorded. **HI v4.18 is
tenant-verified and ledger-recorded but NOT lifecycle-complete -- the Jira half is owed.**

**⚠ PRODUCTION EXISTS (2026-08-13): CA_CLETS v2.24 IS LIVE AT MARIPOSA.** `IMPORT_LEDGER.md` has a
third tenant class now. A LIVE version is frozen -- a bump is a coordinated re-import, not a repo
action. **CA_CLETS is one of the providers the NCIC-image rollout would otherwise reach.** Also:
**HDLE Foundation runs HI v4.15 and is now BEHIND v4.18** (verified from a tenant export -- method
in ledger B.2). The gap loses NCIC hit-block content on a real hit; CAD is being tested against that
tenant, so a re-import is a coordination, not a repo action. Mariposa Foundation = CA_CLETS v2.24.

**JIRA IS NOW FOUR SECTIONS** (Rob: six was "way too many details"). "Known limits"/"Documented
skips" are NOT posted -- they live in `PLATFORM_CONSTRAINTS.txt` / `<P>_ACCEPTED_DIVERGENCES.txt`,
so anything new goes to a repo file FIRST or it is lost. Still one comment per RELEASE, edit in
place, **DRAFT AND WAIT every provider every time.**

**EXTENSION v0.5.2**: manifest is `https://*.mark43.com/rms/*`. **The allowlist WAS the safety; the
ARM switch replaced it** -- disarmed by default per host, 8 `requireArmed()` gates, ZERO browser
dialogs (Chrome's "prevent additional dialogs" silently killed `confirm()`). Panel toggleable via a
`Ux` dot. Match patterns CANNOT match a URL hash.

## OPEN FINDINGS -- confirmed, unfixed

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
- **LA_LEMS PARKED**: real BUILD_RULES 20b WARN, do NOT silence. Rob's call.
- **DH IS NOT SUPPORTED FROM CAD** (Rob 08-12). **`audit_devdoc_optionals` "re-route hole" DOES NOT
  EXIST** (withdrawn, efficacy 13/13).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination.** LIVE-PROVEN 38/38.
  Do not narrow fidelity's `$formOnly` without reading it.

## STATE

**0F/0W except** LA_LEMS + CA_CONTRA_COSTA. **`[FLAG:ncic-image-default-y-everywhere]` is 16 -> 7**
(9 retired 2026-08-14, Rob-approved, ZERO JSON change): **6 of 20 build NO ImageIndicator control at
all** so the rule is N/A, 3 more already have their only (Person) control at `'Y'`, and **AZ is RULED
OUT -- MEASURED**: `'Y'` kills `DQN`+`DQP` (2 `set[]`s, BUILD_RULES 24). Taken at FL v7.21 / IL v2.4 /
HI v4.17. **Owed: LA_LEMS needs a RULING; 6 carry real `'N'`s** (MD 2, NJ 4, NY 3, OH 2, TX 3,
TX_CCH 3) -- a WIRE change, so bump + full re-sweep each, at their own rebuild (8c).
**Expect on EVERY provider's enforce:** `[FAIL] Repo audit` = LA + MD STATUS drift; syncing them is
a back-door mass rebuild.

## RULES I HAVE BROKEN -- READ FIRST (`usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c)

- **PRINT THE OBJECT'S KEYS BEFORE PROBING IT.** Four wrong paths in one day, each producing a
  confident empty answer: `$cb.defaults` (really `.requirements.defaults`), `.PSObject.Properties`
  on an ARRAY, `PENDING_UPDATES.txt` in the provider root (it is `docs/tracking/`), picklist options
  (`entities.<E>.fields.<id>.options`).
- **ADD A CONTROL.** A "portfolio-wide harness defect" was MY probe -- a byte-identical copy with a
  different FILENAME also scored 0. I nearly declared both mutation harnesses broken.
- **A CHECK MUST NOT MATCH ITS OWN TEXT**, and **VERIFY THE VERIFIER**: `node` is not installed, so
  `node --check` is a vacuous pass; prove a probe can FAIL before trusting its green.
- **READ THE GATE VERDICT BEFORE COMMITTING, not in the same command.**
- **A finding across MANY providers is usually YOUR PROBE.** `@()` before `[0]`. A shared-tool change
  reddening another provider gets a FLAG, never a fix (8c). **REPLACE, never append.**