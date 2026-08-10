# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-10 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.9 | NEVER-TESTED -- 55 test(s) owed |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.18 | ALL-PASS (116 logs) |
| HI_HCJDC_OFML | v4.15 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.2 | ALL-PASS (41 logs) |
| NJ_NJCJIS | v4.15 | PARTIAL -- 4 plan test(s) owed (36 captured) |
| NY_NYSPIN_EJUSTICE | v4.23 | ALL-PASS (69 logs) |
| TX_TLETS | v4.19 | ALL-PASS (92 logs) |
| _12 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**IN FLIGHT (Rob 08-10: "work on az and oh, then circle back to test nj"):** AZ **v3.8 BUILT** (two
wire fixes below); **OH_LEADS rebuild NEXT, NOT started** -- ACTIVE `[FLAG:validate-imgind-20b-l30]`
("rebuild to re-record scores") + STATUS 77P vs actual 78P, both clear on rebuild. THEN NJ's 4 OOS
tests (fill **AK**). OH also owes nothing else: PHASE 1 is clean bar the same shared-keyRef fidelity
artifact (BMVIMS DL pair -- DL-by-SSN is NOT devdoc-Basic, so correctly unbuilt).
**AZ v3.8 = (1) DEX-1283 Attention `'X'` removed** (feeder + KQH/KQ defaults; control/`any[]`/handler
untouched; Requestor='X' KEPT, different field). **I had declared AZ done WITH this in it** (98676c95):
the retrofit is convention-only, NO gate checks it, and it surfaced only via OH's fuzz
`prefill-field @ Attention` SURVIVING (already prefilled = no-op). **Sweep: 8 providers still carry the
`X`** -- AZ, OH, TN, LA, CA_eSUN, CA_VENTURA, CA_SLO, CA_CC. **A gate for this is worth building.**
**AZ v3.8 = (2) FOUR OVER-PERMITS on Vehicle.** TWO `ACVR` variants share one keyRef: plate
`Any[PlateYear, PlateTypeCode, State]` vs VIN `Any[MakeCode, VehicleYear, State]`. ACVR carried
make+year; ACVRV the plate pair **+ their defaults[]** (dropping `any[]` alone leaves INERT DEFAULTS,
class E). Devdoc agrees -> FIX. **Fidelity said 0 OVER before AND after** (unions both variants across
the shared keyRef) -- verified by raw XML + simulator, not a gate. 2nd FIDELITY_TRIAGE shared-keyRef
instance (OH's BMVIMS DL pair is 1st). NOT swept.
**Jira POSTED 08-10 (both approved by Rob's "do both"):** DEX-1257 comment **795241** = HI v4.15
changelog + release line; DEX-984 comment **795242** = IL v2.2 release line. Rob attached HI's v4.15
JSON + updated the catalog; recorded in `IMPORT_LEDGER.md` section C, deliberately NOT on the ticket.

**HI v4.15 + IL v2.2 CLOSED end to end** (46/46, 41/41, four log gates each, posted, ledgered).
DEX-1283 on HI SETTLED BY WIRE 9/9. **Its CAD half stays inspection-only** -- no form log reaches the
CAD path, which is DEX-1283's 2nd symptom; never let a later summary upgrade that to "verified".
**GATE WORK 08-10** (detail in `git log`): `audit_sqvr_integrity` CHECK 2 was **VACUOUS on 17 of 20**
-- fixed, prints its denominator, coverage 3->7. **Trap: NJ writes `Total combos: 5 QIDMs / 8 combos`
-- the digit BEFORE "combos" wins.** New gate **`audit_provider_uniformity`** (finished providers'
artifact SETS vs each other; nothing checked that). **`audit_combo_reachability`'s "N checked" is NOT a
combo count** -- use `audit_test_coverage`. **PRE-EXISTING:** NY efficacy 13/14; `-All` fidelity
misattributes registry rows.

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold, BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO devdoc
  combos, and zero-comparison is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect
  `[WARN] Cross-provider: 207P/0F/1W` on EVERY provider's enforce -- it is LA's, not the one tested.**
- **Jira: DRAFT AND WAIT, every provider, every time** (one approval != the next). **Tenant info stays
  OFF tickets** -- attachment/catalog/Foundation go in `IMPORT_LEDGER.md` B and C.
- **GUI ONLY -- Rob never runs commands.** Translate console names to buttons. Corrected 3x.
  **Form review is Rob's MANUAL gate** -- 2k `[INFO] not reviewed` is steady state; never prompt.
  TN_TIES prose divergence -- later. NCIC-number-keyed combos CLOSED 08-03 (OH residue only).

## STATE

**ENFORCED 0F/0W except:** LA_LEMS + CA_CONTRA_COSTA (above); MD_METERS carries
`[FLAG:validate-imgind-20b-l30]`, clears at its OWN rebuild. **EXPECT ON EVERY PROVIDER'S ENFORCE, not
the one you tested:** `[FAIL] Repo audit` = LA/MD/OH STATUS score drift from the 08-07 `validate.ps1`
change (OH's clears when its rebuild lands). Syncing them now = mass-rebuild-by-back-door (8c).
**NJ + TX PARTIAL is a coverage GAIN.** OWED: NJ 4 + TX 3 OOS-toggle tests (fill **AK**), never
generated before. Capture -> ALL-PASS; no bump, no re-sweep.

Invariants: devdoc-UNBUILT 2 (LA) | wiring closure 1/10 (TN RQ05) | audit_metadata 20/20 | portability
280 cells 0 unportable | fidelity fixture 116br 0/0 | uniformity 6 prov 0 unexplained | registry
currency 0 stale | PS-5.1 parse 109/0. Gate stack changed heavily 08-02/04/07/10 -- the
decision-trail hook + `git log -n 40` hold the reasoning; do NOT re-derive.

## OPEN DECISIONS -- Rob's call

**LA_LEMS DP/DQ** -- PARKED. **AZ's 08-04 fuzz closure (`over-permit SexCode @ DQP`, `drop-any
RegistrationNumber @ Boat hull`) names THOSE TWO ONLY and does not cover later seeds** -- 08-10 threw
different ones and one was a real 4-field over-permit. Triage every survivor fresh; the
composite-`Name` component class is the genuine no-op (no authority defines two Name fields).
**Residual, recorded, NOT owed:** `VEHICLE_BODY_STYLE|NJ_NIBRS` in all 20 QRDMs vs CLAUDE.md's
"CA=VEHICLE" (HYPOTHESIS, unsettleable) | fidelity advisory 11 UNDER / 40 OVER | CCH spec-plan name
divergences | `audit_devdoc_optionals` / `audit_log_content` FLAKE under parallel load, re-run alone |
`attributeTypeId=RACE` in 10 providers vs FIELD_REFERENCE (stale KB line) | **FL SQVR 31-30, flagged.**

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c, `usx-test-iterate`.
- **A RECORD IS A CLAIM -- READ THE ARTIFACT. Worst repeat offender.** 08-10: HI's BUILD_NOTES called
  the Attention `'X'` the gate-feeder; I read the note and stopped instead of asking whether that
  version could support the claim (it changed two things at once). Rob overruled me; the wire proved
  him right 9/9. Same class: 2r reads `DEX_TICKET.md` not the ticket; enforce reads CACHED reports.
  **Exit 0 is not evidence a gate spoke -- grep its VERDICT line, print the DENOMINATOR.**
- **A GREEN GATE IS NOT COVERAGE OF THE QUESTION YOU ASKED.** 08-10 AZ: fidelity said 0 OVER while 4
  fields were over-permitted, because two variants shared a keyRef. Ask what the gate COMPARES.
- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED**; **check if it is ALREADY ADJUDICATED first**
  (registry + `git log`) -- but a closure names SPECIFIC findings and does not generalise.
  **DON'T RE-IMPLEMENT A PARSER (std 4.4)**; **NEVER cite another provider as authority** (only
  CC->CA_CLETS, `<BASE>_<VARIANT>`->`<BASE>`); **AIM A MUTATION AT THE GATE OWNING THE CLASS.**
- **A finding across MANY providers is usually YOUR PROBE** -- verify at artifact level either way.
  **A shared-tool change reddening ANOTHER provider gets a FLAG, never a fix** (8c). Add a new
  gate/test-kind to EVERY harness. MUTATE -> restore -> RE-STAMP -> verify. `.Replace()` no-ops on CRLF.
- **REPLACE, never append** -- gate caught me TEN+ times, 4x today. **Cut an OLD line per new one.**
