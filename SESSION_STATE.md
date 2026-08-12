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
| AZ_AZDPS | v3.11 | ALL-PASS (50 logs) |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.19 | NEVER-TESTED -- 116 test(s) owed |
| HI_HCJDC_OFML | v4.15 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.3 | NEVER-TESTED -- 41 test(s) owed |
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

**AZ_AZDPS v3.10 BUILT 2026-08-12 -- cosmetic/layout pass + the hidden-State fix below.**
`audit_layout_flow` 12 -> **0, PASSES**. **WIRE PROVABLY UNCHANGED** (3 bundles' QIDMs byte-identical
to v3.9). PHASE 1 clean, fuzz **8/8 caught 0 survived** (v3.9 had 1), AZ-scoped enforce 0F/0W.
**OWED: RE-IMPORT + full re-sweep** (bump archived v3.9's 55 logs -- accepted, testing is not a blocker).
**HONEST SPLIT (rules AND build changed in one pass):** new tool vs OLD v3.9 = **8**, vs v3.10 = 0.
**8 real fixes; the other 4 were MY TOOL wrong.** Re-run a new gate against the PRE-FIX artifact or
you cannot tell a fix from a suppression. Applying the ruleset found 2 conflicts IN it, both fixed.
**HIDDEN-STATE DEFECT FIXED -- Rob was right ("we should never hide a state fiedl").**
`RegistrationStateDH` was a hidden SelH pinned to `AZ` since **v1.1 (2026-04-20)**, making
**out-of-state DH UNREACHABLE** (the `(Out)` half of BOTH devdoc combos dead). Now visible `[6 3 3]`,
`initialValue='AZ'` kept (0 NOT_EXISTS gates, so safe). Devdoc: both DH combos `(In/Out)`, State
**unbracketed**; metadata: State in `<Set>` on both KQ variants, NO separate OOS transaction -- State
is always sent and its VALUE picks the destination. **The wire was never wrong; the FORM blocked the
officer.** Full reasoning in AZ BUILD_NOTES v3.10.
**ROOT CAUSE WAS A GATE:** `verify_build` CHECK 6's whitelist led with a BARE SUBSTRING `'(?i)state'`,
so it printed "documented exception, allowed" for four months. **REMOVED** (measured: 0 of 20 gain a
WARN). LAW 2 re-proven with a SELF-CHECKED probe -- **my first injection was a dud (duplicate JSON
key, last-wins); always confirm the mutation in the PARSED object.** Sweep: AZ was the ONLY provider
hiding a real State field. **STATE CONVENTION then adopted portfolio-wide-standard (17 of 20):
`State (leave blank for <ST>)` + NO default; DH is `State (required)` because its State is
set[]-mandatory (FL precedent). Boat KEEPS no-default -- prefilling it killed 4 combos at v3.7.**
**OH_LEADS is the only never-swept provider. Testing is no longer a blocker on deciding a fix.**

**JIRA CONSOLIDATED 08-11:** 7 tickets, 91 comments stubbed, 2 keepers each. **RULE: one comment per
RELEASE, EDIT in place if numbers move -- never a sibling correction.** Format single-sourced in
`knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; procedure in `JIRA_REFERENCE.txt` (**no status column**).
No delete tool; edits IRREVERSIBLE. 2r 2 PASS / 0 GAP on all 9.
**THE LESSON, three times now:** the stub inventory came from `DEX_TICKET.md` and was short by 18; the
AZ ledger claimed "never installed" against on-disk v3.6 artifacts; CLAUDE.md wrote up AZ's hidden
State as a FEATURE. **A tracking file is a CLAIM; the artifact is the evidence.**

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold, BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO devdoc
  combos, and zero-comparison is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect LA's
  `[WARN] Cross-provider` on EVERY provider's enforce -- it is LA's, not the one tested.**
- **Jira: DRAFT AND WAIT, every provider, every time** (one approval != the next). **Tenant info stays
  OFF tickets** -- attachment/catalog/Foundation go in `IMPORT_LEDGER.md` B and C.
- **DRIVER HISTORY IS NOT SUPPORTED FROM CAD** (Rob 2026-08-12). So "DH has no State combo default
  and CAD ignores form initialValue" is MOOT, not a defect -- I raised it, he closed it. Never
  re-raise, and never add a State default to DH to "fix" it.
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
280 cells 0 unportable | fidelity fixture 116br 0/0 | registry currency 0 stale | PS-5.1 parse 110/0.
The decision-trail hook + `git log -n 40` hold the reasoning; do NOT re-derive.

## OPEN DECISIONS -- Rob's call

**LA_LEMS DP/DQ** -- PARKED. **TRIAGE EVERY FUZZ SURVIVOR FRESH:** AZ's 08-04 closure names TWO only
and does not cover later seeds. **A STALE MUTATION LOOKS LIKE A BLIND GATE** -- 08-12 `az-state-
prefill-routes` "SURVIVED" because it INHERITED the prefill my build change removed; a mutation must
CREATE the whole defect. composite-`Name` component survivors are the genuine no-op.
**Residual, recorded, NOT owed:** `VEHICLE_BODY_STYLE|NJ_NIBRS` in all 20 QRDMs (HYPOTHESIS) |
fidelity advisory 11 UNDER / 40 OVER | CCH spec-plan names | `audit_devdoc_optionals` /
`audit_log_content` FLAKE under parallel load | `attributeTypeId=RACE` x10 vs FIELD_REFERENCE.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c, `usx-test-iterate`.
- **A RECORD IS A CLAIM -- READ THE ARTIFACT. Worst repeat offender.** 08-10: HI's BUILD_NOTES called
  the Attention `'X'` the gate-feeder; I read the note and stopped instead of asking whether that
  version could support the claim (it changed two things at once). Rob overruled me; the wire proved
  him right 9/9. Same class: 2r reads `DEX_TICKET.md` not the ticket; enforce reads CACHED reports.
  **Exit 0 is not evidence a gate spoke -- grep its VERDICT line, print the DENOMINATOR.**
- **A GREEN GATE IS NOT COVERAGE OF THE QUESTION YOU ASKED.** 08-10 AZ: fidelity said 0 OVER while 4
  fields were over-permitted, because two variants shared a keyRef. Ask what the gate COMPARES.
- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED**; check if ALREADY ADJUDICATED first (registry
  + `git log`). **DON'T RE-IMPLEMENT A PARSER (std 4.4)**; **NEVER cite another provider as authority**
  (only CC->CA_CLETS, `<BASE>_<VARIANT>`->`<BASE>`); aim a mutation at the gate OWNING the class.
- **A finding across MANY providers is usually YOUR PROBE** -- verify at artifact level either way.
  **A shared-tool change reddening ANOTHER provider gets a FLAG, never a fix** (8c). Add a new
  gate/test-kind to EVERY harness. MUTATE -> restore -> RE-STAMP -> verify. `.Replace()` no-ops on CRLF.
- **REPLACE, never append** -- gate caught me TEN+ times, 4x today. **Cut an OLD line per new one.**
