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
| FL_FCIC | v7.22 | NEVER-TESTED -- 109 test(s) owed |
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

**FL_FCIC v7.22 BUILT 2026-08-12. NEXT: IMPORT + 109-test sweep (Rob's, not mine) -- "once we test
live(not with you) we can finailize any assumptions."** v7.20 retired 4 layout rows; v7.21 moved Gun
Make under Serial + set **NCIC Image='Y' on all 5 entities** (5 controls + all 25 combo `defaults[]`);
v7.22 set the **Boat Stolen Check='Y'** on Rob's direct order and **moved BQ ahead of QB**, which
recovered the 2 out-of-state combos his prefill had shadowed (reachability 4 dead -> 2, shadow 2F -> 0F).
The 2 remaining (FBQ Hull/Reg) are REGISTERED `dead-combo` by his decision. FL enforce: no FL FAIL/WARN.

**⛔ THE BIG LESSON: MESSAGE KEYS ARE NEVER SENT.** The wire carries `<MessageType>BoatQuery</MessageType>`
+ required/optional FIELDS -- Rob: *"we only send the transaction type and required and optional fields
... not the message keys."* Proven: log `FL_FCIC_v7.8_QBBoatHullIdNumber.txt` contains the literal `QB`
**ZERO** times. So `FBQ`/`QB`/`BQ` are NOT three transactions -- they are three `<Combination>`s of ONE
`<Transaction name="BoatQuery">`. Every devdoc says `Data-Mined Transactions: NCIC (QA,QB,QG,QV,QW)`; I
swept 20 JSONs for keyRefs matching those codes and reported **10 providers building data-mined
transactions (FL 12, TX 7)** -- **100% FALSE**, keyRefs are internal labels as CLAUDE.md already states.
**READ THE WIRE BEFORE SWEEPING 20 PROVIDERS.** I also retracted to Rob the claim that a Boat Stolen
default "kills the registration search": same MessageType, so the real loss is only a hull/reg query
WITHOUT the related-hit field. **Killing FBQ{Hull} then orphaned a devdoc optional** -- 5 FAIL,
`audit_optional_scope` 3x FIX, so `RegistrationNumber` went back into QB{Hull}/FBQ{Decal}/FBQ{TitleLien}
`any[]` (v6.9's "Hull>Reg de-bleed" had stripped it -- the AZ v3.1 mistake, `usx-build` 6c: identifier
priority is ROUTING, never deleting a permitted field). 5 FAIL -> 0.
**NCIC IMAGE RULE CHANGED (Rob): 'Y' on EVERY entity** -- he ruled the GATE wrong, not the build.
`audit_cross_provider` now expects 'Y' on Vehicle; both safety guards HOISTED out of the Person block
first (else Vehicle got a silently dead guard) and LAW-2 proven 3 ways. CLAUDE.md + FIELD_REFERENCE +
BUILD_RULES 684 + `preflight_rebuild` corrected. **NOT MECHANICAL: AZ has it in 2 `set[]`s, LA in 1 +
2 conditions.** All 19 others carry `[FLAG:ncic-image-default-y-everywhere]`, which BLOCKS their enforce
PHASE 1 (verified on NJ) -- 6 tenant-verified providers un-done until rebuilt; lift if he scopes narrower.
**REFUSED BY THE SOURCE, still standing:** an FL default on DH State -- FCIC wrote 2026-06-12 that KQ
needs a "destination something other than FL". Label: `Destination State (required, not FL)`.
**USE [Certain]/[Likely]/[Guessing] TAGS -- standing directive I dropped for a whole session until Rob
called it out 08-12.** **THE STATE-DEFAULT RULE (a stuck T26 to learn):** a `set[]` field with no value
**GATES THE BROWSER SEND BUTTON** (NY v4.20) -- default a mandatory State only where the devdoc has an
(In)/(In/Out) combo. AZ's DH is (In/Out) -> defaults; FL's is (Out)-ONLY -> blank + a label naming both
facts. Same field, opposite answer, per-provider scope.

**JIRA: one comment per RELEASE, EDIT in place -- never a sibling correction.** Format in
`knowledge-base/JIRA_COMMENT_TEMPLATE.txt`, procedure in `JIRA_REFERENCE.txt` (**no status column**).
No delete tool; edits IRREVERSIBLE. **NOTHING POSTS WITHOUT ROB'S EXPLICIT APPROVAL (08-12).**
Awaiting: AZ v3.11, FL v7.22, IL v2.3.

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold, BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO devdoc
  combos, and zero-comparison is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect LA's
  `[WARN] Cross-provider` on EVERY provider's enforce -- it is LA's, not the one tested.** Its VehReg
  is the SAME CLASS as AZ's DH bug (both combos `(In/Out)`, State in `set[]`, control BLANK -> Send
  gated on an in-state plate query). NOT FIXED; Rob's call.
- **Jira: DRAFT AND WAIT, every provider, every time** (one approval != the next). **Tenant info stays
  OFF tickets** -- attachment/catalog/Foundation go in `IMPORT_LEDGER.md` B and C.
- **DRIVER HISTORY IS NOT SUPPORTED FROM CAD** (Rob 08-12). So "DH has no State combo default and CAD
  ignores form initialValue" is MOOT -- I raised it, he closed it. Never re-raise.
- **GUI ONLY** (memory has the button map). **Form review is his MANUAL gate** -- never prompt.

## STATE

**ENFORCED 0F/0W except:** LA_LEMS + CA_CONTRA_COSTA (above); **all 19 non-FL providers now carry
`[FLAG:ncic-image-default-y-everywhere]`**, each clearing at its OWN rebuild; MD also carries
`[FLAG:validate-imgind-20b-l30]`. **EXPECT ON EVERY PROVIDER'S ENFORCE, not the one you tested:**
`[FAIL] Repo audit` = LA + MD STATUS score drift from the 08-07 `validate.ps1` change; syncing them =
back-door mass rebuild (8c). All 8 tenant-tested providers are at full plan coverage; none PARTIAL.

Invariants: devdoc-UNBUILT 2 (LA) | wiring 1/10 (TN RQ05) | audit_metadata 20/20 | portability 280 cells
0 unportable | fidelity 116br 0/0 | registry 0 stale | PS-5.1 110/0. **TRIAGE EVERY FUZZ SURVIVOR FRESH**
(`usx-tooling` 5/8d). **Residual, NOT owed** (`git log`): `VEHICLE_BODY_STYLE|NJ_NIBRS` HYPOTHESIS |
fidelity advisory 11 UNDER / 40 OVER | `audit_devdoc_optionals`+`audit_log_content` parallel-load FLAKE.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING (cases: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c)

- **A RECORD IS A CLAIM -- READ THE ARTIFACT. Worst repeat offender.** **Exit 0 is not evidence a gate
  spoke -- grep its VERDICT line, print the DENOMINATOR.** 08-12 gave three confident EMPTY answers
  (ParserError matching neither `RESULTS:` nor `FAIL`; a probe typing `QUERYINPUTDATAMAP` for
  `...MAPPING`; `Get-ProviderRootJson` needing BOTH `-Provider` AND `-ProvDir`).
- **VERIFY WITH A DIFFERENT PATTERN THAN YOU EDITED WITH** -- my N->Y sweep and its residual check
  shared one over-strict regex, so a `;   value = 'N'` site survived and the check said 0 left.
- **A GREEN GATE IS NOT COVERAGE OF THE QUESTION YOU ASKED.** Ask what it COMPARES: fidelity said
  `0 OVER-PERMITTED` on FL while FBQ carries an undefined `ImageIndicator` -- `$formOnly` whitelist.
- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED**; check ALREADY ADJUDICATED first (registry +
  `git log`). **DON'T RE-IMPLEMENT A PARSER (4.4)**; **NEVER cite another provider as authority** (only
  CC->CA_CLETS, `<BASE>_<VARIANT>`->`<BASE>`); aim a mutation at the gate OWNING the class.
- **A finding across MANY providers is usually YOUR PROBE** (a State sweep flagged 65; truth was 1).
  **`@()` BEFORE `[0]`.** A shared-tool change reddening ANOTHER provider gets a FLAG, never a fix
  (8c). MUTATE -> restore -> RE-STAMP -> verify. `.Replace()` no-ops on CRLF.
- **REPLACE, never append** -- gate caught me TEN+ times, incl. 8 rounds today. **Rewrapping does not
  reduce the line count -- DELETE a block.**
