# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-12 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.10 | NEVER-TESTED -- 55 test(s) owed |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.18 | ALL-PASS (116 logs) |
| HI_HCJDC_OFML | v4.15 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.2 | ALL-PASS (41 logs) |
| NJ_NJCJIS | v4.15 | ALL-PASS (40 logs) |
| NY_NYSPIN_EJUSTICE | v4.23 | ALL-PASS (69 logs) |
| TX_TLETS | v4.19 | ALL-PASS (92 logs) |
| _12 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**AZ_AZDPS v3.10 BUILT 2026-08-12 -- cosmetic/layout pass, Rob: "fix all 12 and bring az to the
standard layout".** `audit_layout_flow` 12 -> **0 findings, PASSES**. **WIRE PROVABLY UNCHANGED:** all
3 bundles' QIDMs byte-identical to v3.9. PHASE 1 clean incl. fuzz **8/8 caught, 0 survived** (v3.9 had
1). AZ-scoped enforce 0 FAIL / 0 WARN. **OWED: RE-IMPORT + full 55-test re-sweep** (the bump archived
v3.9's 55 logs -- accepted cost, testing is not a blocker).
**HONEST SPLIT, because I changed rules and the build in one pass:** new tool vs OLD v3.9 = **8
findings**, vs v3.10 = 0. So **8 were real fixes; the other 4 of the original 12 were MY TOOL being
wrong.** Always re-run the new gate against the pre-fix artifact or you cannot tell a fix from a
suppression.
**APPLYING THE RULESET FOUND TWO CONFLICTS IN IT** -- both fixed in the tool with the reasoning:
(a) L5 vs L6 -- a lone short control has NO legal width (12 = wasted, 4 = short row), so L6 now judges
MULTI-field rows only; (b) L8 vs L2 -- grouping all four name parts necessarily puts optional
middle/suffix ahead of mandatory DOB/Sex, so name components are excluded from L2. L8 wins: a name is
one thing to an officer. Reference providers improved too (FL 7->4, NY 6->5, OH 2->1, NJ still 0).
**NOT TOUCHED, awaiting Rob:** `RegistrationStateDH` is HIDDEN + prefilled AZ, so **out-of-state
driver history is unreachable**. Making it visible is FUNCTIONAL, not cosmetic, and needs a devdoc
ruling -- deliberately left alone rather than silently changed under a cosmetic mandate.
**OH_LEADS is the only never-swept provider. Testing is no longer a blocker on deciding a fix.**

**JIRA CONSOLIDATED 08-11:** 7 tickets, **91 comments stubbed**, 2 keepers each. **THE RULE: one
comment per RELEASE, EDIT it in place if numbers move -- never a sibling correction** (that left FL
claiming 121-118-117-116). Format single-sourced in `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`;
procedure + ticket map in `JIRA_REFERENCE.txt` (**do not re-add a status column**). **No delete tool
exists, edits are IRREVERSIBLE** -- capture first; only robot-attributed comments, and NOT by
displayName. 2r now 2 PASS / 0 GAP on all 9.

**THE LESSON, twice today:** my stub inventory came from `DEX_TICKET.md` and was short by **18
comments**; the AZ ledger row claimed "never installed" while a v3.6 picklist and v3.6 Person logs sat
on disk. **A tracking file is a CLAIM; the artifact is the evidence.**

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
change -- **LA + MD only now; OH's cleared at its v2.4 rebuild.** Syncing them = back-door mass
rebuild (8c). **All 8 tenant-tested providers are at full plan coverage; nothing is PARTIAL.**

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
