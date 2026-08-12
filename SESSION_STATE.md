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
**8 real fixes; 4 were MY TOOL wrong.** Re-run a new gate against the PRE-FIX artifact or you cannot
tell a fix from a suppression.
**USE [Certain]/[Likely]/[Guessing] TAGS -- standing directive, and I dropped them for a whole
session until Rob called it out 08-12. Tag every load-bearing claim.**
**AZ v3.11 TENANT-VERIFIED ALL-PASS 50/50** (Veh 9 / Per 21 / Gun 6 / Art 3 / Boat 11), four log
gates 50/50, inflation 0/0/0/0. **`<State>NJ</State>` on 7/7 DH logs -- OUT-OF-STATE DH WORKS, and at
v3.9 it was UNREACHABLE** (hidden control pinned to AZ). `<Attention>SGAMBELLONE R</Attention>` x7,
Stolen Check Y x10 + N x10, `<UserName>MK43RS` 50/50, zero bare `>X<`.
**THE v3.10 REGRESSION AND ITS RULE:** I made DH State visible (right) AND dropped its default
(wrong). **A `set[]` field with no value GATES THE BROWSER SEND BUTTON** -- NY v4.20's mechanism,
already written down, and Rob hit it at T26. v3.11 restored the default, kept it VISIBLE. **The
decision rule: default a mandatory State only when the devdoc has an (In) or (In/Out) combo.** AZ's
DH is (In/Out) -> needs it. **FL's DH is (Out)-ONLY -> blank + 'State (required)' is CORRECT there**,
so copying FL onto AZ was the error. Same field, opposite answer, decided by each provider's scope.

**JIRA: 91 comments stubbed 08-11, one comment per RELEASE, EDIT in place -- never a sibling
correction.** Format in `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`, procedure in `JIRA_REFERENCE.txt`
(**no status column**). No delete tool; edits IRREVERSIBLE. **NOTHING POSTS WITHOUT ROB'S EXPLICIT
APPROVAL (08-12).** Awaiting approval: AZ v3.11, FL v7.19, IL v2.3.
**A tracking file is a CLAIM; the artifact is the evidence** -- 4x now (stub inventory short by 18;
AZ ledger said "never installed" against on-disk v3.6 logs; CLAUDE.md wrote up the hidden State as a
FEATURE; a stale v3.10 TEST_PLAN drove a changed form).

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- on hold, BLOCKED (08-02): `audit_devdoc_combinations` compares ZERO devdoc
  combos, and zero-comparison is a FAIL. The gate got stricter; CC did not get worse.
- **LA_LEMS -- PARKED (08-04).** Real BUILD_RULES 20b WARN; do NOT silence. **Expect LA's
  `[WARN] Cross-provider` on EVERY provider's enforce -- it is LA's, not the one tested.**
  **NEW 08-12, NOT FIXED (parked + never tested): LA VehReg is the SAME CLASS as AZ's DH bug** --
  devdoc combos 1+2 are BOTH `(In/Out)` with State UNBRACKETED, every built combo has State in
  `set[]`, and the control is BLANK. So an in-state LA plate query needs an explicit LA pick, and a
  `set[]` field with no value gates the browser Send button. Rob's call whether to fix.
- **Jira: DRAFT AND WAIT, every provider, every time** (one approval != the next). **Tenant info stays
  OFF tickets** -- attachment/catalog/Foundation go in `IMPORT_LEDGER.md` B and C.
- **DRIVER HISTORY IS NOT SUPPORTED FROM CAD** (Rob 2026-08-12). So "DH has no State combo default
  and CAD ignores form initialValue" is MOOT, not a defect -- I raised it, he closed it. Never
  re-raise, and never add a State default to DH to "fix" it.
- **GUI ONLY -- Rob never runs commands.** Translate console names to buttons. **Form review is his
  MANUAL gate** -- 2k `[INFO] not reviewed` is steady state; never prompt.

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

**TRIAGE EVERY FUZZ SURVIVOR FRESH** -- old closures name specific seeds only. **A STALE MUTATION
LOOKS LIKE A BLIND GATE**: 08-12 `az-state-prefill-routes` "SURVIVED" because it INHERITED a prefill
my build change removed; a mutation must CREATE the whole defect. composite-`Name` = genuine no-op.
**Residual, NOT owed** (detail in `git log`): `VEHICLE_BODY_STYLE|NJ_NIBRS` HYPOTHESIS | fidelity
advisory 11 UNDER / 40 OVER | `audit_devdoc_optionals`+`audit_log_content` FLAKE under parallel load.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

Cases live in the skills: `usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c, `usx-test-iterate`.
- **A RECORD IS A CLAIM -- READ THE ARTIFACT. Worst repeat offender.** 08-10 HI: BUILD_NOTES called
  the Attention `'X'` the gate-feeder; I stopped at the note instead of asking whether that version
  could support it. Rob overruled me; the wire proved him right 9/9. **Exit 0 is not evidence a gate
  spoke -- grep its VERDICT line, print the DENOMINATOR.** 08-12: I filtered a build for
  `RESULTS:|FAIL`, a ParserError matched neither, and I read 3 cycles of stale-JSON gate output.
- **A GREEN GATE IS NOT COVERAGE OF THE QUESTION YOU ASKED.** 08-10 AZ: fidelity said 0 OVER while 4
  fields were over-permitted, because two variants shared a keyRef. Ask what the gate COMPARES.
- **CITE THE ARTIFACT LINE OR SAY YOU HAVEN'T CHECKED**; check if ALREADY ADJUDICATED first (registry
  + `git log`). **DON'T RE-IMPLEMENT A PARSER (std 4.4)**; **NEVER cite another provider as authority**
  (only CC->CA_CLETS, `<BASE>_<VARIANT>`->`<BASE>`); aim a mutation at the gate OWNING the class.
- **A finding across MANY providers is usually YOUR PROBE** -- 08-12 a State sweep flagged 65 rows on
  15 providers; the real answer was 1. **`@()` BEFORE `[0]`** -- a 1-element `Where-Object` result is a
  STRING and `[0]` gives its FIRST CHARACTER, which made every lookup key `Person|R` and every row
  read "(blank)". A shared-tool change reddening ANOTHER provider gets a FLAG, never a fix (8c).
  MUTATE -> restore -> RE-STAMP -> verify. `.Replace()` no-ops on CRLF.
- **REPLACE, never append** -- gate caught me TEN+ times. **Cut an OLD line per new one.**
