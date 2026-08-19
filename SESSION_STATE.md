# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-19 (generated) | **Branch:** `main`

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
| NJ_NJCJIS | v4.16 | ALL-PASS (40 logs) |
| NY_NYSPIN_EJUSTICE | v4.24 | ALL-PASS (75 logs) |
| OH_LEADS | v2.9 | ALL-PASS (56 logs) |
| TX_TLETS | v4.21 | ALL-PASS (96 logs) |
| _11 others_ | -- | never tenant-tested: CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## NEXT PHYSICAL ACTION

**THE 95% IS NOW A TOOL, NOT A CLAIM: `tools\report_mission_status.ps1` -> 9 of 20 = 45%.**
It reports each provider at its FIRST unmet stage and groups the rest by blocking stage, which is what
turns the score into a queue. **ALL ELEVEN incomplete providers are now blocked at the SAME stage (test),
with build+spec+reachability met on every one** -- CA_CONTRA_COSTA was the last exception and cleared
08-19, so the remaining 55% is ONE ACTIVITY. Building more will not move the number.

**?? NO LOG SWEEP AND NO IMPORT UNTIL ROB LIFTS THIS (his words, 08-19): "we will not run a log sweep
until we get this all fixed and figured out."** The queue above is READY, not authorised -- do NOT pick a
never-tested provider and import it, which is what this file told the last session to do. Ask first.

**FIVE PROVIDERS REBUILT 08-18/19, ALL 0 FAIL** -- CA_CLETS_OCATS v2.6, NM_NMLETS_OFML v2.2,
MD_METERS v2.1, TN_TIES v2.2, OR_LEDS v2.4 (last four also 0 WARN). Highlights: OCATS BUILT the two
variants I had wrongly registered as skips (4K, VC) which took over-permits 7->0 -- **building the
missing variant is usually the right fix for an over-permit**; NM's DL was missing BOTH mandatory
fields because a `<Choice>` inside `<Set>` hid them; TN's stolen check was FREE-TEXT and the gate
harness found it by reporting a FALSE survivor; OR was transmitting two fields its transaction does not
define. MD closed the LAST `ncic-image` carrier, so `audit_cross_provider` now reads AUDIT PASSED.

**PORTFOLIO SWEEP 08-19 -- what it found and fixed:**
- **2 FROZEN artifacts deleted.** `audit_session_state.ps1` and `verify_claims.ps1` sat in the REPO ROOT
  containing NO PowerShell -- captured console text from 07-30 asserting `[PASS] all 6 provider(s)` and
  `111 lines`. A photograph of a gate passing, in the place a reader expects a gate.
- **NEW GATE `audit_artifact_provenance.ps1`** (in `doctor`): F frozen / S stale / U unsourced / O orphan.
  Baseline now 140 scripts + 273 reports, **all four classes 0**. U 0 means every report is attributable
  to a generator -- a clean result on an axis nothing measured before.
- **28 stale reports** regenerated (4 CA providers x 7). **4 GENERIC BUILD_NOTES** replaced: all four were
  the SAME family-wide `<Authentication>/<DeviceId>` production fix, stubbed on 5 of 6 CA providers by one
  propagation pass. BUILD_NOTES fidelity is now **0 GENERIC across all 20**.
- OH_LEADS `DEX_TICKET_ARCHIVE.md` created (uniformity FAIL -> `docs/reports identical across all 9`).
- `build_zz_test_conditions.ps1` moved root -> `tools/`; **the move broke it twice** (dot-sources became
  `tools\tools\...`, output would have landed in `tools\`). Both repaired. Its being at root is why the
  undocumented-tool gate had never seen it.

**? PRODUCTION = TWO LIVE TENANTS: CA_CLETS at MARIPOSA - HI_HCJDC_OFML v4.15 at HDLE.** A LIVE version is
frozen -- a bump is a coordinated re-import, not a repo action. **HDLE is deliberately HELD at v4.15**
(repo/ticket v4.20) until the hit block is verified, **so HDLE production discards NCIC hit content today.**
Authority is `report_import_owed.ps1`, NOT this file. Neither LIVE row is discoverable from the repo -- ASK.

**JIRA: 4 sections, one NEW comment per RELEASE -- never edit the previous one.** Name the superseded id in
Section 1. DRAFT AND WAIT, every provider, every time. Rules: `JIRA_COMMENT_TEMPLATE.txt`.

## OPEN FINDINGS -- confirmed, unfixed

- 0 over-broad suppressions / 248 rows / 0 STALE. **The "21 over-broad" that sat here was ONE PROVIDER
  MISSING A MARKER** -- `# SUPPRESSION-SCOPE: direction-aware` was on 19 of 20; the 08-02 sweep opted in
  "all 8 remaining eligible" and skipped CA_CONTRA_COSTA. Adding it: 21 -> 0, `audit_metadata` **215 PASS /
  0 FAIL both before and after**, so it un-silenced nothing. It was never a portfolio problem.
- **? PAUSED PENDING COMMSYS -- LIMITATION #41:** a populated HOME state routes a local plate to NLETS.
  Our config is provably clean; evidence in `PLATFORM_CONSTRAINTS.txt` #41. Read before any State work.
- **HI's NCIC hit block is CONFIG-PRESENT, NOT RENDERING-VERIFIED.** Needs ONE hit query in HI's OWN tenant.
- **38 UNTRIAGED clone groups** (`audit_log_inflation`) -- duplicate/vacuous guardrails; clear at each
  provider's own rebuild via the `emit_test_plan` fix, never a sweep.
- **Officer guides are content-poor, not stale.** Rewrite requested; shape not agreed.
- 2 live flags: `nameparts-untested-unfrozen` (TX_TLETS_CCH), `plan-fillability-unfireable-tests` (CA_eSUN).

## ON HOLD / DO NOT RE-RAISE

- **COMMSYS ASKS ARE ON HOLD (Rob 08-18).** LA's devdoc PurposeCode/State inversion is recorded, NOT owed.
- **HI PlateType default on a CAD VIN check -- HELD.** Defaulting it kills the in-state plate search (BR 24).
- **CA_CONTRA_COSTA spec block CLEARED 08-19 -- do not re-file it as "Rob's call".** Its devdoc really does
  say "Basic Queries Supported: None", but the defect was the authority CHAIN, not the build: the gate now
  falls back to the DEVDOC OF RECORD (`CA_CLETS`, the one blessed directed link) and compares 34, equal to
  its base. It did NOT manufacture a pass -- the fallback's first run raised a real unbuilt VehReg #1
  (`FileCode`/`InfoCode`), the same item CA_CLETS had already registered. **A vacuous FAIL is still
  un-actionable: no build change could ever have cleared a devdoc that lists no queries.**
- **DH IS NOT SUPPORTED FROM CAD** (08-12). **`audit_devdoc_optionals` re-route hole DOES NOT EXIST** (withdrawn).
- **LIMITATION #40: the wire is a UNION across every MATCHING combination** (LIVE-PROVEN 38/38).
- **CLOSED, do not re-raise:** the 28 TX/TX_CCH `ImageIndicator=Y` constraint triggers; CA_CLETS purpose-code
  dropdown (#39); LIVE CA_eSUN `DEX_INQUIRY_PURPOSE_CODE` (SHELVED 08-17, do not act).

## RULES I HAVE BROKEN -- READ FIRST (`usx-adjudicate`, `usx-metadata` 6, `usx-tooling` 5b/5c)

- **A FINDING ON EVERY PROVIDER IS YOUR PROBE.** `report_mission_status` said "0 of 20" three times before
  it was right; each cause was my own regex, never the portfolio. **ANCHOR ON THE GATE'S VERDICT LINE.**
- **`-like` IS A WILDCARD MATCHER -- use `.Contains()` for literal text.** Markdown prose is full of `*` and
  `[`, so a `-like` guard silently returned False on a line that was byte-identical. Cost 3 attempts.
- **`-Quiet` SUPPRESSES `Write-Host`, so a piped capture gets NOTHING** -- my `doctor` wiring printed
  headers with no content. Verify a new dashboard section actually REPORTS, not just that it ran.
- **MOVING A FILE BREAKS ITS RELATIVE PATHS.** `$PSScriptRoot` moves with it. Check dot-sources AND outputs.
- **PRINT THE OBJECT'S KEYS / READ THE API BEFORE PROBING.** `Get-ProviderTestState` (not ...Status);
  layout nodes sit DIRECTLY under each variant with no `.nodes` level; **`@($null).Count` IS 1**.
- **READ THE GATE VERDICT BEFORE COMMITTING, not after.** **REPLACE this file, never append.**