# SESSION STATE — where we are RIGHT NOW

> **Pick-up point**, hook-injected + committed. CURRENT STATE ONLY (history = git + `CHANGELOG_<P>.md`).
> **REPLACE, never append**; hard gate at 120 lines; update in the SAME commit as the work; derive
> every number from `portfolio_status.ps1` / `enforce.ps1`, never from memory.

<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-20 (generated) | **Branch:** `main`

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
| NY_NYSPIN_EJUSTICE | v4.25 | NEVER-TESTED -- 73 test(s) owed |
| OH_LEADS | v2.10 | ALL-PASS (56 logs) |
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

**SWEEPING AGAIN -- the 08-19 hold is LIFTED. NEXT: NM_NMLETS_OFML v2.2 (Rob, 08-20: "we will test nm
next").** Pre-flight CLEAR (32 plan tests / 104 fills / 0 unfireable). **NM needs TWO things OH did not:
an IMPORT (never installed) and a PICKLIST CAPTURE -- it has no `TENANT_PICKLISTS.json`.** Note NM's
JSON plan is 32 tests against a SPEC plan of 51: the gate passes (every entity covered) but the sweep
will exercise a thinner slice of the spec than OH's did. Say so before, not after, the logs land.

**OH_LEADS v2.10 COMPLETE 08-20** -- cosmetic (parentheticals stripped from all 5 card titles that had
one), re-swept 56/56, four log gates 56/56, DEX-990 comment **802507**, ticket + catalog on v2.10.
**Wire-identity was PROVEN, not asserted: all 56 captured wires byte-identical to their v2.9 archived
counterparts, with ARTICLE -- the one card not edited -- as the unchanged-fingerprint control.**

**HEALTH, measured 08-20 (`doctor.ps1`) -- nothing owed:** 20 providers 0 FAIL / 0 WARN · PS-5.1 117/0 ·
portability 280 cells / 0 · provenance F0 S0 U0 O0 · 248 registry rows / 0 over-broad / 0 STALE ·
BUILD_NOTES 0 GENERIC / 20 · variant drift 0 · cross-provider AUDIT PASSED. `audit_provider_linkage`
FAILs on 12 providers are the KNOWN ADVISORY (comment provenance, no wire impact, cleared at each
provider's own rebuild) -- not a blocker, do not "fix" it as a sweep.
History of the 08-18/19 rebuilds and the portfolio sweep lives in git + `CHANGELOG_<P>.md`, not here.

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

- **A TOOL THAT AUTO-COMMITS MUST STAGE ONLY WHAT IT WROTE.** `import_captured_tests` ran
  `git add -- providers`, so the watcher's automatic capture commit swept in a 228KB untracked CA_eSUN
  tenant export and PUSHED it under the message "Import ... captures" -- fixed 08-20 to stage
  `providers/<P>/{logs,docs}` + `automation/captures` only. **The blob is still in pushed history at
  `8273a87f`; un-tracking does not remove it, and a rewrite is Rob's call.**
- **`sed` FALLBACK AFTER A FAILED HEREDOC OVERWROTE A LINE WITH `X`** in this very file, 08-20. A
  `cmd || sed ...` fallback runs the fallback when the FIRST command is merely absent (`python3`), not
  when the edit is needed. Use the Edit tool for prose; never a blind regex over a curated file.

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