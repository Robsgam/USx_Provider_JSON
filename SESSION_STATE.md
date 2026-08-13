# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-13 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.11 | ALL-PASS (50 logs) |
| CA_CLETS | v2.24 | ALL-PASS (90 logs) |
| FL_FCIC | v7.23 | ALL-PASS (110 logs) |
| HI_HCJDC_OFML | v4.15 | ALL-PASS (46 logs) |
| IL_LEADS_OFML | v2.4 | NEVER-TESTED -- 41 test(s) owed |
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

**NEXT: NOTHING IS MID-FLIGHT. FL_FCIC IS DONE.** Repo clean+pushed, no watcher running, no stranded
captures. Pick up with **(a)** IL_LEADS_OFML v2.3 -- re-import + 41-test sweep, the ONLY owed sweep;
**(b)** the 3 held Jira drafts, ON EXPLICIT APPROVAL ONLY; **(c)** the two open tool decisions below.
**FL_FCIC v7.23 TENANT-VERIFIED -- ALL-PASS 110/110** (Veh 20/Per 21/Gun 15/Art 16/Boat 38), 4 log gates
110/110. **Three contested decisions WIRE-PROVEN:** Boat Stolen Check 'Y' on 24 QB wires (18Y/6N/**0
absent**); BQ-ahead-of-QB RECOVERED `BQBoatHullIdNumber`+`BQRegistrationNumber`; `<State>NJ</State>` 7/7
DH wires, **0** FL.

**⛔ LIMITATION #40 -- THE WIRE IS A UNION ACROSS EVERY MATCHING COMBINATION, not the firing combo's
field list. LIVE-PROVEN, 38/38 Boat logs, 0 mispredicted.** Proof: `FBQDecalNumber_af_BoatHullIdNumber`
carries `DecalNumber` (in NO QB combo, so FBQ{Decal} fired -- 2i was RIGHT) yet ALSO `ImageIndicator` +
`RelatedHitSearchIndicator`, which it does not define; they ride because the fill also satisfies
QB{Hull}. Control: decal-alone matches no QB combo and carries neither, though the form still holds
`ImageIndicator=Y` -- MATCH-driven, not "the form value is always sent".
**CORRECTS WHAT I WROTE EARLIER TODAY:** I logged the `$formOnly` whitelist (ImageIndicator,
RegistrationState) as a gate hole. #40 says it is an EMPIRICAL WORKAROUND -- `audit_requirement_fidelity`
models the FIRING combo only and cannot express a union. **Do NOT narrow it without reading #40.** Nor
is removing a field from the firing combo a guaranteed fix: v7.23 stripped `ImageIndicator` from all 4
FBQ combos (correct per both authorities) and 5 of 8 FBQ wires still carry it.
**WITHDRAWN -- the `audit_devdoc_optionals` "re-route hole" DOES NOT EXIST.** I reported it, Rob said
fix it, the code refuted it: the DROPPED check runs FIRST and `continue`s, and its pool is a UNION over
co-matching combos -- which #40 proves is what the wire does. My mutation removed `Requestor` from ONE
combo and survived CORRECTLY. **LAW 2:** strip it from ALL 12 Boat lists -> those fills FAIL. Catalogued
`fl-drop-optional-everywhere`, efficacy **13/13**. **DO NOT "FIX" IT** -- reasoning in the tool header.

**NCIC IMAGE RULE (Rob): 'Y' on EVERY entity** -- he ruled the GATE wrong, not the build.
`audit_cross_provider` now expects 'Y' on Vehicle (guards HOISTED out of the Person block first, else
Vehicle got a silently dead guard; LAW-2 proven 3 ways). CLAUDE.md + FIELD_REFERENCE + BUILD_RULES 684 +
`preflight_rebuild` corrected. **NOT MECHANICAL: AZ has it in 2 `set[]`s, LA in 1 + 2 conditions.** All
19 others carry `[FLAG:ncic-image-default-y-everywhere]`, BLOCKING their enforce PHASE 1 (verified on
NJ) -- 6 tenant-verified providers un-done until rebuilt; lift if he scopes narrower.
**USE [Certain]/[Likely]/[Guessing] TAGS.** **STATE-DEFAULT RULE (a stuck T26 to learn):** a `set[]`
field with no value **GATES THE BROWSER SEND BUTTON** (NY v4.20) -- default a mandatory State only where
the devdoc has an (In)/(In/Out) combo. AZ DH (In/Out) -> defaults; FL DH (Out)-ONLY -> blank + label.

**JIRA: one comment per RELEASE, EDIT in place -- never a sibling correction.** Format in
`knowledge-base/JIRA_COMMENT_TEMPLATE.txt`, procedure in `JIRA_REFERENCE.txt` (**no status column**).
No delete tool; edits IRREVERSIBLE. **DRAFT AND WAIT every provider, every time -- one approval != the
next.** **Tenant info stays OFF tickets** (-> `IMPORT_LEDGER.md` B/C). **GUI ONLY; form review is Rob's
MANUAL gate -- never prompt.** Awaiting: AZ v3.11, **FL v7.23 (RELEASE LINE, ALL-PASS 110/110)**, IL v2.3.

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO devdoc combos, which is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect LA's
  `[WARN] Cross-provider` on EVERY provider's enforce.** Its VehReg is the SAME CLASS as AZ's DH bug
  (both combos `(In/Out)`, State in `set[]`, control BLANK -> Send gated). NOT FIXED; Rob's call.
- **DRIVER HISTORY IS NOT SUPPORTED FROM CAD** (Rob 08-12). So "DH has no State combo default and CAD
  ignores form initialValue" is MOOT -- I raised it, he closed it. Never re-raise.

## STATE

**ENFORCED 0F/0W except:** LA_LEMS + CA_CONTRA_COSTA (above); **all 19 non-FL providers now carry
`[FLAG:ncic-image-default-y-everywhere]`**, each clearing at its OWN rebuild; MD also carries
`[FLAG:validate-imgind-20b-l30]`. **EXPECT ON EVERY PROVIDER'S ENFORCE, not the one you tested:**
`[FAIL] Repo audit` = LA + MD STATUS score drift from the 08-07 `validate.ps1` change; syncing them =
back-door mass rebuild (8c). All 8 tenant-tested providers are at full plan coverage; none PARTIAL.

Invariants: devdoc-UNBUILT 2 (LA) | wiring 1/10 (TN RQ05) | audit_metadata 20/20 | portability 280 cells
0 unportable | fidelity 116br 0/0 | registry 0 stale | PS-5.1 110/0 | gate efficacy 13/13. **TRIAGE EVERY
FUZZ SURVIVOR FRESH.** **Residual, NOT owed** (`git log`): `VEHICLE_BODY_STYLE|NJ_NIBRS` HYPOTHESIS |
fidelity advisory 11 UNDER / 40 OVER | `audit_devdoc_optionals` parallel-load FLAKE.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING (cases: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c)

- **A RECORD IS A CLAIM -- READ THE ARTIFACT.** **Exit 0 is not evidence a gate spoke -- grep its
  VERDICT line, print the DENOMINATOR.** 08-12: three confident EMPTY answers, plus a wire probe that
  matched `_FBQ` inside `QB..._vs_FBQ...` and searched the RESPONSE section as if it were the request.
  **ADD A CONTROL** (a log that SHOULD carry the field) -- that is what caught all of them.
- **VERIFY WITH A DIFFERENT PATTERN THAN YOU EDITED WITH** -- my N->Y sweep and its residual check
  shared one over-strict regex, so a `;   value = 'N'` site survived and the check said 0 left.
- **A GREEN GATE IS NOT COVERAGE OF THE QUESTION YOU ASKED.** Ask what it COMPARES: fidelity said
  `0 OVER-PERMITTED` on FL while FBQ carries an undefined `ImageIndicator` -- `$formOnly` whitelist.
- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED**; check ALREADY ADJUDICATED first (registry +
  `git log`). **DON'T RE-IMPLEMENT A PARSER (4.4)**; **NEVER cite another provider as authority** (only
  CC->CA_CLETS, `<BASE>_<VARIANT>`->`<BASE>`); aim a mutation at the gate OWNING the class.
- **MESSAGE KEYS ARE NEVER SENT** -- wire = `<MessageType>` + FIELDS; `FBQ`/`QB`/`BQ` are
  `<Combination>`s of ONE `<Transaction>`. I swept 20 JSONs against each devdoc's `Data-Mined
  Transactions: NCIC (QA,QB,QG,QV,QW)` line and reported **10 providers building them -- 100% FALSE**.
  **READ THE WIRE BEFORE SWEEPING 20 PROVIDERS.**
- **A finding across MANY providers is usually YOUR PROBE** (a State sweep flagged 65; truth was 1).
  **`@()` BEFORE `[0]`.** A shared-tool change reddening ANOTHER provider gets a FLAG, never a fix
  (8c). MUTATE -> restore -> RE-STAMP -> verify. `.Replace()` no-ops on CRLF.
- **REPLACE, never append** -- the gate caught me 10+ times, 12 rounds today alone. **REWRAPPING NEVER
  REDUCES THE COUNT. Delete a whole block, then re-run the gate BEFORE committing.**
