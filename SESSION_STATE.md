# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-21 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| AZ_AZDPS | v3.11 | ALL-PASS (58 logs) |
| CA_CLETS | v2.26 | ALL-PASS (111 logs) |
| FL_FCIC | v7.24 | ALL-PASS (118 logs) |
| HI_HCJDC_OFML | v4.20 | ALL-PASS (50 logs) |
| IL_LEADS_OFML | v2.8 | ALL-PASS (44 logs) |
| NJ_NJCJIS | v4.17 | ALL-PASS (41 logs) |
| NM_NMLETS_OFML | v2.6 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.26 | ALL-PASS (65 logs) |
| OH_LEADS | v2.11 | NEVER-TESTED -- 66 test(s) owed |
| TX_TLETS | v4.21 | ALL-PASS (96 logs) |
| _10 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**THE BUILD QUEUE IS EMPTY.** Rob's "build them all" (08-20) is COMPLETE -- twelve providers rebuilt
in one pass (NY, OH, NM, LA_LEMS, CA_eSUN, MD_METERS, TN_TIES, OR_LEDS, CA_VENTURA_COUNTY,
CA_SAN_LUIS_OBISPO, CA_CLETS_OCATS, CA_CONTRA_COSTA), each `enforce` 45 PASS / 0 FAIL / 0 WARN,
each committed separately.

**EVERYTHING NOW BLOCKS ON ONE ACTIVITY: IMPORT + SWEEP.** 13 of 20 are NEVER-TESTED and every one
is build/spec/reachability-complete -- nothing further can be BUILT to move the number. Queue
authority is `report_import_owed.ps1`, never this file. **Picklist capture is owed on ELEVEN
providers**: every rebuild regenerated `<P>_PICKLIST_SCOPE.json`, but only a tenant capture
produces `TENANT_PICKLISTS.json`.

**TWO PORTFOLIO INVARIANTS CLOSED, measured across all 20 -- do not re-open:**
`audit_name_components` **216 examined / 0 C1 / 0 C2 / 0 C3** (every officer can now type middle
name + suffix, every component composed AND pooled) and `audit_layout_flow` **139 -> 10 findings**,
19 -> 7 providers. The 10 remaining sit on FL(1) HI(1) IL(2) NM(1) TX(1) TX_CCH(2) -- six of seven
TENANT-VERIFIED, so each costs a re-sweep. **NM's L9 is an ACCEPTED OPERATOR OVERRIDE.**

## OPEN DECISIONS THAT ARE ROB'S, NOT MINE

- **CA_CONTRA_COSTA JAWS / SuperQuery ruling** -- pending; v2.4 deliberately did not pre-empt it. Its
  4 UNDER / 3 OVER (IR.QVC.N BirthDate+Age, NLTS.DQ.N SexCode+BirthDate, IR.QVC.O/.C/.S Age) are
  listed verbatim in its BUILD_NOTES and untouched: CA_CLETS and Ventura require OPPOSITE things there.
- **TN_TIES `RQ01{LicensePlateNumber}` is NOT BUILT.** It maps to devdoc "1. (In) LicensePlateNumber";
  the build serves blank-State plate with `QV.P`, the NCIC query. If wrong, in-state TN plate searches
  reach NCIC not TIES/DMV. Routing-model question, in TN's BUILD_NOTES.
- **Name-component fieldId casing is split ~50/50 and SEVEN providers are internally MIXED** (AZ 6/6,
  CA_CLETS 10/23, FL 6/13). No gate flags it; AZ, the only wire-PROVEN one, is itself mixed. Converging
  is a 16-provider sweep -- needs a ruling, not a habit.
- **TOOLING GAP, REAL AND UNFIXED:** `audit_requirement_fidelity` does not descend into a `<Choice>`
  nested in `<Any>`, so a legal optional reads as OVER-PERMITTED. Proven on CA_eSUN `L1{Name}` and
  registered there (`demoted-to-any`, scoped to `L1.N` not bare `L1`). **Some of the portfolio's
  remaining OVER-PERMITs may be this same false class.** Owes the 6-provider fixture + 20-provider sweep.

## OPEN FINDINGS -- confirmed, unfixed

- **PAUSED PENDING COMMSYS -- LIMITATION #41:** a populated HOME state routes a local plate to NLETS.
  Our config is provably clean; evidence in `PLATFORM_CONSTRAINTS.txt` #41. Read before any State work.
- **HI's NCIC hit block is CONFIG-PRESENT, NOT RENDERING-VERIFIED.** Needs ONE hit query in HI's own tenant.
- **38 UNTRIAGED clone groups** (`audit_log_inflation`) -- clear at each provider's own rebuild, never a sweep.
- **Officer guides are content-poor, not stale.** Rewrite requested; shape not agreed.
- 1 live flag: `nameparts-untested-unfrozen` (TX_TLETS_CCH). CA_eSUN's fillability flag CLEARED 08-20.
- Suppression registry: **252 rows / 0 over-broad / 0 STALE.**

## ON HOLD / DO NOT RE-RAISE

- **`State2`-`State5` MULTI-STATE NLETS BROADCAST -- PARKED UNTIL ROB BRINGS IT UP (2026-08-21).** Do
  not re-raise, do not propose propagating the registry row to the 7 providers missing it, do not
  cost it again. Already ruled OUT OF SCOPE by Rob on 2026-08-02 ("multi-destination Nlets routing is
  not built on any provider"); it is registered on 6 of the 13 affected providers, rule class `other`
  so it silences nothing. **I re-derived it as a new open question on 08-21 anyway, on a provider that
  had three such rows** -- the pre-sweep flow reads the spec plan's UNREACHABLE findings and never
  cross-checks the registry, so it will keep looking new. It is not. The 24 UNREACHABLE spec tests on
  NM are this, and they are expected output.
- **COMMSYS ASKS ARE ON HOLD (Rob 08-18).** LA's devdoc PurposeCode/State inversion is recorded, NOT owed.
- **HI PlateType default on a CAD VIN check -- HELD.** Defaulting it kills the in-state plate search (BR 24).
- **CA_CONTRA_COSTA spec block CLEARED 08-19** via the DEVDOC-OF-RECORD fallback to `CA_CLETS` -- do not
  re-file it as "Rob's call". Separate from the still-open JAWS ruling above.
- **DH IS NOT SUPPORTED FROM CAD** (08-12). **`audit_devdoc_optionals` re-route hole DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination** (LIVE-PROVEN 38/38).
- **CLOSED:** the 28 TX/TX_CCH `ImageIndicator=Y` triggers; CA_CLETS purpose-code dropdown (#39); LIVE
  CA_eSUN `DEX_INQUIRY_PURPOSE_CODE` (SHELVED 08-17); `ncic-image-default-y-everywhere` (fully propagated --
  CLAUDE.md still names MD_METERS as owing it and that prose is STALE, measured 08-20).

## RULES I HAVE BROKEN -- READ FIRST (`usx-adjudicate`, `usx-metadata`, `usx-tooling` 5b/5c)

- **`<Any>` IS NESTED INSIDE `<Set>` in this schema, so `$c.Requirements.Any` returns NOTHING.** I read that
  as "no optionals anywhere", tightened three `any[]` pools on CA_eSUN v2.4 and DROPPED A LEGAL OPTIONAL.
  **Dump `$c.Requirements.OuterXml` -- it is the only read of a `<Requirements>` block worth trusting.**
  Caught because the probe contradicted a committed registry row. One of them had to be wrong; it was mine.
- **AN OPERATOR OVERRIDE IS RECORDED FOR A REASON -- READ THE COMMENT BEFORE "FIXING" THE FINDING.** I
  re-split NM's race row to satisfy L9 and had to revert: Rob directed race onto line 3 after sex, and the
  override was already written in NM's BUILD_NOTES *and* in the code comment I displaced.
- **A `head -N` SPLICE IS ONLY SAFE IF YOU KNOW WHAT LINE N IS.** Three BUILD_NOTES inserts landed inside an
  existing entry today (OR, OCATS, NY) because header depth varies per provider. Check, then splice.
- **NARROWING AN `any[]` STRANDS ITS `defaults[]`** (wiring class E). Happened on CA_eSUN and Ventura.
- **A GATE SUITE CHAINED AFTER A FAILED BUILD REPORTS ON THE STALE JSON.** On Ventura the tell was that
  `RESULTS: 82 PASS` was ABSENT, not that anything complained. Confirm the build line before reading gates.
- **templateColumns must match the CHILD COUNT *and* sum to 12** -- validate.ps1 and L6 constrain it from
  opposite directions. L6 does not fire on a single-field row, so a lone control legitimately takes `@('6')`.
- **A FINDING ON EVERY PROVIDER IS YOUR PROBE.** Anchor on the gate's own verdict line.
- **`-Quiet` SUPPRESSES `Write-Host`**, so a piped capture gets nothing. **`@($null).Count` IS 1.**
- **A TOOL THAT AUTO-COMMITS MUST STAGE ONLY WHAT IT WROTE** (fixed 08-20). The 228KB CA_eSUN blob is still
  in pushed history at `8273a87f`; un-tracking does not remove it and a rewrite is Rob's call.
