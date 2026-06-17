# Rebuild Tracker
Generated: 2026-05-08 | Last updated: 2026-06-14

## CURRENT TEST / BUILD ORDER (user directive 2026-06-14, SUBJECT TO CHANGE)

1. **FL_FCIC** (v5.1) -- DONE 2026-06-15. Imported to USx tenant; full matrix T1-T42 PASS
   (one-directional deselect + co-fire pool isolation confirmed); enforce-clean. Request-side.
2. **TX_TLETS** (v3.4) -- ACTIVE. Imported USx TLETS tenant 2026-06-15; RENDER PASS (all 4 entities);
   T1+ live testing in progress. Carry: Img/catchall merged + image/email in any[]; email-in-set[] CAD
   tabled (handler pending); image/email auto-send handlers pending.
3. **NJ_NJCJIS** -- test + DECIDE the Vehicle-Stolen branch winner (VehStolenRemoved vs
   VehStolenSeparate). Hopefully we know which way to go by then (PM input pending).
4. **NY_NYSPIN_EJUSTICE** -- (has 4 poisoned-array combos earmarked; analyze benign-vs-harmful at rebuild).
5. **AZ_AZDPS**.

Gating reality: each "test" needs the JSON imported to the USx tenant by the user; this env returns
NO live state responses (request-side XML + visual only). Methodology: challenge/verify + secure data
before running down a path (do NOT assume; confirm against XML/devdoc/live logs first).

**ON RECORD -- PascalCase vs camelCase:** may need to PAUSE the order and re-evaluate the form-param
casing question (PascalCase migration vs camelCase; OnScene/Forge exact-match vs CAD). Keep flagged;
revisit when it blocks or when the user calls it. See NJ STATUS PASCALCASE MIGRATION + [[nj-pascalcase-mock]].

## DEFERRED BACKLOG — Process-hardening Tier 3 (2026-06-14, documented per user; REMIND at trigger)

From the tools/scripts/KB consolidation audit. Tier 1 (KB poisoned-array centralization, README fix,
QIDM builder helpers, doctor.ps1) + Tier 2 done/in-progress. Tier 3 deferred:

- **Data-driven generic build engine** — replace ~20 bespoke `build_<provider>.ps1` (~80% boilerplate)
  with one engine + per-provider config. SCAFFOLDED/DEFERRED (user can't dedicate a big Claude block).
  The 30-60h figure is a brute-force [Guessing] estimate — **do NOT commit to it.** Before any real
  work, run a cheap time-boxed (~1-2h) SPIKE for a measured number / smarter path: derive ONE provider's
  config from its existing JSON → generate → diff (config-by-example round-trip). If that works, per-
  provider cost may be ~minutes and the whole effort far less than guessed. `generate_build_script.ps1`
  is the incomplete seed. **REMINDER TRIGGER:** 5+ NEW providers queued, OR idle capacity for the spike.
  Until then, use the new `Build-QidmCombo`/`Build-QidmAttribute` helpers incrementally at each rebuild
  (semantic-reformat, validator-verified — not byte-diff).
- **Modularize `validate.ps1`** (~2200 lines, 6 coupled phases) — SKIP. Risk > benefit; revisit only if
  it grows materially or a phase needs independent reuse.

## Poisoned-Array Exposure Catalog (2026-06-14, repo-wide sweep)

Source: `validate.ps1` G-31 (added 2026-06-14; also `verify_build.ps1` CHECK 11). Flags every
combo with a value-comparison condition (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) — these are INERT on
the platform (poisoned-array, QIDM_REFERENCE Sec 2a). **Poisoned = inert, NOT automatically broken**:
benign if routing is carried elsewhere (NJ RandomRequest — same MessageKey, server-side value
routing), harmful if it causes misroute/over-send (TX Img combos — union over-send). Each needs
per-case analysis. Fix at each provider's rebuild (one-at-a-time).

| Provider | Combos | Verdict / action |
|---|---|---|
| CA_CLETS | 0 (was 20) | FIXED v2.5 2026-06-14. Server-routing model confirmed (wire=MessageType=VehicleRegistrationQuery/DriverLicenseQuery; IV.4*/IR.QVC keyRefs server-selected by field VALUE, internal-only — 12 live VehReg + 9 DL logs). Removed 20 inert conditions; deleted 13 redundant IV.4* + IV.4V/IV.4B dups; IR.QVC criminal combos kept (devdoc DL #3-7), IR.QVC.N set[] fixed (Name+SexCode). 0F/0W/0LIM. ON RETEST QUEUE. |
| TX_TLETS | 5 | HARMFUL (Img/catchall union over-send). FIXING NOW (v3.4: strip conditions, merge pairs, keep image+email in any[]). |
| TX_TLETS_CCH | 5 | OUT OF SCOPE — intentional separate data-ingestion stub (user directive). |
| NY_NYSPIN_EJUSTICE | 4 | Earmark for NY's rebuild; analyze benign-vs-harmful then. |
| NJ_NJCJIS (mainline + PASCAL + VehStolenRemoved + VehStolenSeparate) | 2 each | KNOWN BENIGN — RandomRequest EQUALS Y; routing carried by field value, identical MessageKey. Documented. No action. |

Process lesson: simulator/combo-match tests PASS without exercising conditions live → false
confidence (TX 40/40, CA_CLETS 40/40 both pre-finding). The static guard + request-side live test
close that gap.

## ImageIndicator set[] anomaly — LA_LEMS (flagged 2026-06-15)

Repo-wide scan (all 24 provider JSONs, during FL_FCIC v5.0 live testing) found `imageIndicator`
in a combo `set[]` (i.e. REQUIRED) in exactly ONE place: **`LA_LEMS_MC.json` combo `DP`**.
Everywhere else it is `any[]`/`defaults[]` only. ImageIndicator should not be required (FCIC-class
metadata defaults blank→N; it is a query modifier, not a search key). **At LA_LEMS's next rebuild:
verify DP and move `imageIndicator` out of `set[]` into `any[]`** unless LA metadata genuinely
requires it. Context + full ImageIndicator serialization finding: `knowledge-base/FIELD_REFERENCE.txt`
Section 9. One provider at a time — do not touch LA before its rebuild.

## Process Gap-Proofing — IMPLEMENTED 2026-06-14 (then NJ)

DONE (all 3 pillars built + verified; design: plan `swift-gathering-snowglobe.md`):
- **Pillar 1** `tools/audit_test_coverage.ps1 -Gate` — per-provider verdict CLOSED /
  INCOMPLETE-consistent / INCONSISTENT; exits non-zero only on INCONSISTENT. Also fixed
  single-JSON discovery (merged providers were silently skipped) + canonical build-script
  version parse (NJ multi-script).
- **Pillar 2** new `tools/verify_claims.ps1` — every KB/simulator LIVE-PROVEN claim must cite
  a committed test log; long-path (>260) safe. KB STATUS convention added to QIDM_REFERENCE
  Sec 2a + BUILD_RULES §17; poisoned-array rule now cites the archived T-A/T-B logs.
- **Pillar 3** `reset_test_package.ps1` regenerates TEST_MATRIX (warns on combo delta);
  `verify_build.ps1` CHECK 10 (RMS combos ⊆ CommSys) + CHECK 11 (value-comparison conditions
  flag, WARN).
- Wired both into `enforce.ps1` **PHASE 6** (blocking). Docs: TESTING_REQUIREMENTS §11 GATES
  4-5 marked [TOOL]/[OP].

**First gate finding (action item, one-at-a-time):** CA_CLETS is **INCONSISTENT** — 40
[CONFIRMED] but only 36 XML-bearing logs (matches the known "NJ/CA_CLETS XML backfill needed"
note). Full `enforce.ps1` now BLOCKS on CA_CLETS until its logs carry XML or markers are
corrected. NJ mainline = CLOSED; TX_TLETS = CLOSED; FL v5.0 = INCOMPLETE-consistent (fresh,
correct). All other providers INCOMPLETE-consistent.

**Then:** run NJ through the new gates (user directive: gap-proofing first, then NJ).
Full design: plan file `swift-gathering-snowglobe.md` (outside the repo).

**Problem:** the build phase is hard-gated (`enforce.ps1` exit 0 or blocked) but the
test→change→iterate phase is only prose-gated, so a provider can carry stale `[CONFIRMED]`
markers, untested combos, missing XML, and a stale TEST_MATRIX yet still pass enforce and be
called "done." Separately, unverified platform-behavior hypotheses got written into KB +
both simulators as "live-proven" before the confirming test ran (the FL v4.7→v5.0 churn) —
nothing checks that a "live-proven" claim references a real committed test log.

**Pillar 1 — blocking iterate-phase gate.** Extend `tools/audit_test_coverage.ps1` with a
`-Gate` mode emitting CLOSED / INCOMPLETE-consistent / INCONSISTENT (block on: `[CONFIRMED]`
older than `tests/.test_version`; a `[CONFIRMED]` combo whose log lacks XML; TEST_MATRIX combo
count ≠ JSON; orphan logs). Wire into `enforce.ps1` as a blocking phase that fails on
INCONSISTENT (passes on INCOMPLETE-consistent so fresh all-PENDING builds aren't blocked) and
always prints the verdict.

**Pillar 2 — hypothesis quarantine.** New `tools/verify_claims.ps1`: every KB/simulator
platform-behavior claim tagged "live-proven" must reference an existing test-log path; flag
unbacked claims. KB convention: each behavior rule carries `STATUS: LIVE-PROVEN <log path>` or
`STATUS: HYPOTHESIS <discriminating test>`; a HYPOTHESIS may not be encoded in a simulator as fact.

**Pillar 3 — close silent drift.** Tighten `tools/reset_test_package.ps1` to regenerate
TEST_MATRIX (and warn on combo-count delta); add to `tools/verify_build.ps1`: RMS combos ⊆
CommSys combos, and flag any surviving value-comparison routing condition.

**Docs/rule/memory:** rewrite `knowledge-base/TESTING_REQUIREMENTS.txt` GATES 0-5 to point at
the enforced checks; add the quarantine rule + STATUS convention to QIDM_REFERENCE.txt +
BUILD_RULES.txt; durable lesson saved in memory [[iterate-phase-needs-hard-gate]].

**Verify the gates gate:** FL_FCIC v5.0 (all-PENDING) → INCOMPLETE-consistent, not blocked;
inject a stale `[CONFIRMED]` → INCONSISTENT + non-zero exit; `verify_claims` passes on the
poisoned-array rule (cites committed T-A/T-B logs), flags it if the citation is removed.

**Then:** run NJ through the new gates as the first real exercise (see NJ_NJCJIS_STATUS.txt PENDING).

---

## Status: 16 PROVIDERS FLAGGED FOR REBUILD — Single-JSON merge + HIDLE_MC migration

All 18 active providers rebuilt and validated (0 FAIL / 0 WARN). But audit found
7 providers with CommsysGetLastNameFirstNameInitialRuleHandler on Attention attribute
and NO visible form field — same pattern fixed on FL_FCIC v4.0.

## Final Scorecard (2026-05-11)

| # | Provider | Version | BASE Score | MC Score | LIM | Notes |
|---|---|---|---|---|---|---|
| 1 | NJ_NJCJIS | v4.0 |  | 61P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-21, State defaults, v3.4 imported USx Provider Tenant + Newark Foundation |
| 2 | HI_HCJDC_OFML | v1.8 |  | 67P/0F/0W/0LIM | 0 | State no-default, purposeCodeDH fixed. GAP (2026-06-08): DL SexCode-primary combo missing (metadata DQ primaryFieldReference=SexCode has no JSON combo -- add on rebuild) |
| 3 | NY_NYSPIN_EJUSTICE | v3.0 |  | 81P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-22, DGRP added, layout 13→7 cards, VehicleMakeCode FormSelect, one-directional deselect, CAD defaults |
| 4 | AZ_AZDPS | v2.3 |  | 71P/0F/0W/0LIM | 0 | |
| 5 | FL_FCIC | v5.1 |  | 92P/0F/0W/0LIM | 0 | v5.0 (2026-06-12): dropdown revert + poisoned-array purge -- ALL value-comparison conditions removed (proven wholly inert, T-A/T-B), existence-only routing (State/RelatedHit/OLN NOT_EXISTS), DH+Boat dest State = NCIC dropdown, not-FL gate = LIMITATION + BUG 6 escalation. BQ x3 restored v4.7, 31 combos. QV x2 PENDING platform confirmation. ImageQuery = user-approved scope skip. NOT yet imported |
| 6 | TX_TLETS | v3.8 |  | 83P/0F/0W/1LIM | 0 | EmailAddress user-fillable, Attention visible, one-directional deselect |
| 7 | LA_LEMS | v2.5 |  | 63P/0F/0W/0LIM | 0 | State no-default, purposeCodeDH fixed |
| 8 | CA_CLETS | v2.5 |  | 76P/0F/0W/0LIM | 0 | MERGED single-JSON 2026-05-21, 40/40 combos, 6 QIDMs, live-tested |
| 9 | CA_VENTURA_COUNTY | v1.4 |  | 72P/0F/0W/0LIM | 0 | |
| 10 | CA_CLETS_OCATS | v1.2 |  | 63P/0F/0W/0LIM | 0 | |
| 11 | CA_eSUN | v1.5 |  | 71P/0F/0W/0LIM | 0 | NEW SOURCE (2026-06-12): updated metadata XML + devdoc PDF received (old CA_eSUN.4.17.26.pdf removed). v1.5 build predates new source. On next rebuild: regen DEVDOC text, re-run extract_metadata_reference + extract_queries, diff_docs vs KB, rebuild against new XML |
| 12 | CA_SAN_LUIS_OBISPO | v1.3 |  | 65P/0F/0W/0LIM | 0 | |
| 13 | IL_LEADS_OFML | v1.1 |  | 61P/0F/0W/0LIM | 0 | |
| 14 | MD_METERS | v1.3 |  | 69P/0F/0W/0LIM | 0 | State no-default. GAP (2026-06-08): Gun GunMake-primary combo missing (metadata ZGUN primaryFieldReference=GunMake has no JSON combo -- add on rebuild) |
| 15 | OH_LEADS | v1.3 |  | 77P/0F/0W/0LIM | 0 | |
| 16 | NM_NMLETS_OFML | v1.3 |  | 66P/0F/0W/0LIM | 0 | |
| 17 | OR_LEDS | v1.3 |  | 58P/0F/0W/0LIM | 0 | |
| 18 | TN_TIES | v1.4 |  | 80P/0F/0W/0LIM | 0 | |
| 19 | TX_TLETS_CCH | v1.0 |  | 119P/0F/0W/0LIM | 0 | STUB 2026-06-09: separate CCH-gated provider, 6 base QIDMs (ported TX_TLETS) + 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR), CCH-suffixed fields, autoSelect=false named-checkbox, FreeText capped, CCH response QRDM out of scope, NOT live-tested |

**CA_CONTRA_COSTA**: MC script created (clean-build HIDLE_MC pattern). Incomplete — awaiting updated devdoc/metadata decision.

## Residual UNBUILT Verification (2026-06-12)

extract_metadata_reference.ps1 phantom-UNBUILT bug fixed 2026-06-12 (synthetic
keyRef matching). Remaining UNBUILT rows in each METADATA_REFERENCE.txt are now
genuine non-matches: a mix of documented approved skips, LIMITATION #21/#36
collapses, and possible real gaps. FL_FCIC verification found 5 of its 7 were
REAL GAPS misclassified as skips (QV x2, BQ x3 — see FL row above), so treat
every residual row as a gap until proven otherwise against the devdoc
"Basic Queries Supported" combos (NOT key mnemonics — devdocs may not contain
key lists; the v4.4 FL misread cited one that does not exist).

ACTION at each provider's next rebuild: classify every UNBUILT row in its
METADATA_REFERENCE as BUILT-VARIANT / APPROVED-SKIP (cite devdoc+BUILD_NOTES) /
REAL-GAP (build it). One provider at a time — do not mass-sweep.

## Poisoned-Array Conditions Sweep (flagged 2026-06-12)

POISONED-ARRAY RULE live-proven on FL v4.9 T-A/T-B (USx tenant, RMS client):
any value-comparison condition (EQUALS/NOT_EQUALS/IN/NOT_IN/REGEX) disables
its ENTIRE conditions array, incl. co-resident NOT_EXISTS. See
knowledge-base/QIDM_REFERENCE.txt Sec 2a + PLATFORM_BUG_REPORT.txt BUG 6.

Providers carrying value-comparison conditions — fix at each one's next
rebuild/test session (one provider at a time, NOT a mass sweep):

| Provider | Conditions at risk | Action at next session |
|---|---|---|
| NJ_NJCJIS | RandomRequest EQUALS Y/N (RAND vs FULL routing) | CONTRADICTION: live-passed 2026-05-28 NJCJIS tenant. Run ONE RAND=Y discriminating query — check firing keyRef. If poisoned: redesign per FL v5.0 pattern |
| TX_TLETS | ImageIndicator EQUALS Y conditions routing | Verify with one live query or redesign to existence/set[]-based routing |
| NY_NYSPIN_EJUSTICE | DALHOUT/DALLOUT State guards (if NOT_EQUALS) | Inspect JSON; replace with existence-only or set[] routing |
| CA_CLETS | IV.4* plate-type conditions (13 combos), State NOT_EQUALS guards | Inspect; IV.4* may be redundant anyway (see reference_ca_clets_iv4_routing) |

| Provider | Residual UNBUILT rows |
|---|---|
| CA_VENTURA_COUNTY | 20 |
| CA_eSUN | 10 (re-check against NEW 2026-06-12 source) |
| NJ_NJCJIS | 9 (4 expected: LIMITATION #21 RandomRequest collapse) |
| FL_FCIC | 7 -> 4 after v4.7 (BQ x3 restored; QV x2 pending platform confirmation of data-mined auto-send; QW x2 approved skip) |
| CA_CLETS_OCATS | 6 |
| CA_SAN_LUIS_OBISPO | 4 |
| OH_LEADS | 3 |
| TX_TLETS | 3 |
| TX_TLETS_CCH | 3 |
| HI_HCJDC_OFML | 2 (1 known: DL SexCode-primary combo, see row 2) |
| MD_METERS | 1 (known: Gun GunMake-primary combo, see row 14) |
| NM_NMLETS_OFML | 1 |
| AZ, CA_CLETS, CA_CONTRA_COSTA, IL, LA, NY, OR, TN | 0 |

## RMS Person QIDM Pool Isolation (2026-06-12) -- ALL 19 PROVIDERS, GATED

FL v4.8 live evidence: RMS follows the union-pool serialization model -- a full
DL card sends dlNumber+name+DOB+sex in ONE elastic query (all four Person combos
match, no conditions, pool = union). Fix designed in BUILD_RULES Section 4
("RMS POOL ISOLATION"): OLN-first combos + licenseNumber NOT_EXISTS conditions
in _build_rms_bundle.ps1. DO NOT APPLY until gates clear:
- G1: live impact test (does the elastic search AND criteria? OLN-match/name-
  mismatch record: OLN-only vs full-card results)
- G2: verify RmsRestPayloadHandler honors conditions (zero RMS conditions exist
  portfolio-wide; conditions only proven on the CommSys handler)
When applied, propagates to every provider at its rebuild (shared module).
test_commsys now simulates RMS QIDMs + prints a UNION POOL line per QIDM.

## Shadowed Combo Findings (G-16 subset check, 2026-06-12)

validate.ps1 G-16 upgraded from consecutive-count heuristic to true subset-shadowing
detection (an earlier UNCONDITIONED combo whose set[] is a subset of a later combo's
set[] makes the later combo unreachable under first-match). FL v4.7 clean. Latent
findings in other providers (verify/fix at each provider's next rebuild -- add routing
conditions or reorder; cross-check CA_CLETS IV.4* redundancy note):

| Provider | Shadowed combo | Shadowing combo |
|---|---|---|
| CA_CLETS | IA.QVK (VehicleRegistrationQuery) | IV.4V |
| CA_CLETS | IR.QVC.N (DriverLicenseQuery) | IN.L1 |
| CA_CLETS | IV.4B (BoatQuery) | IA.QB.R |
| TX_TLETS | QVVehicleIdentificationNumber (VehicleInsuranceRegistrationQuery) | RQVehicleIdentificationNumber |
| TX_TLETS_CCH | QVVehicleIdentificationNumber (VehicleInsuranceRegistrationQuery) | RQVehicleIdentificationNumber |

NY/NJ/FL and all 13 other providers: 0 findings (existing docs/ validator reports
predate the G-16 upgrade; scores refresh at each provider's next rebuild).

## What Was Fixed (2026-05-08 through 2026-05-11)

### WARN Elimination (all 18 providers)
- ArticleType sourceField references (6 providers)
- Attention field combo placement (3 providers)
- State routing issues (3 providers)
- ImageIndicator defaults (2 providers)
- DH-suffix fieldId consistency (2 providers)
- Total: ~75 WARNs eliminated down to 0

### Dynamic PlateYear (all 18 providers)
- `$currentYear = [string](Get-Date).Year` added to all build scripts
- `initialValue = $currentYear` replaces hardcoded '2026'

### DH-suffix fieldIds (9 DL+DH providers)
- All 9 providers with DL+DH now use DH-suffix pattern
- queriesToDeselect configured on all 9

### Combo Ordering (all 18 providers)
- Most-specific combinations first in every QIDM

### State initialValue Removal (HI, LA, MD)
- Removed per "start clean" principle — LIM #30 eliminated
- Officers must explicitly select state

### purposeCodeDH Field Type Fix (HI, LA)
- Changed from FormSelect (attributeTypeId=DEX_INQUIRY_PURPOSE_CODE) to FormInput (maxLength=1, initialValue=C)
- Matches FL/NM/OH/TN/TX majority pattern

## Cross-Provider Audit (2026-05-11)
- 323 PASS / 0 FAIL / 2 WARN / 192 INFO
- 2 WARNs: CA_SAN_LUIS_OBISPO CaRequestPurposeCode (documented in metadata as intentional)

## Remaining Limitations (2 total)
- TX_TLETS: 2 LIM — EmailAddress is QIDM-only on DL+DH (no form field, handler-filled)
- These are genuinely unfixable without platform form field additions

## One-Directional queriesToDeselect — Flagged 2026-05-12

Rule (KB BUILD_RULES.txt Sec 11 + AP #14/#23): default query (DL, VehReg) has
autoSelect=true and NO queriesToDeselect; opt-in query (DH, VehStolen) deselects
ONLY the default. NEVER bidirectional (mutual cross-deselect → error popup).
Fix at each provider's next rebuild; verify against current JSON (list is as-of
the flag date and may be stale — `verify_build.ps1` / audit catches live state).

DL+DH — remove queriesToDeselect from DriverLicenseQuery:
- FIXED: CA_CLETS (v1.8), FL_FCIC (correct since v3.9), TX_TLETS (v3.1)
- FLAGGED: NY_NYSPIN_EJUSTICE, AZ_AZDPS, LA_LEMS, HI_HCJDC_OFML, TN_TIES,
  OH_LEADS, NM_NMLETS_OFML, MD_METERS, CA_SAN_LUIS_OBISPO, CA_eSUN, CA_VENTURA_COUNTY
- Already correct: NJ_NJCJIS (since v2.9)

VehReg+VehStolen — remove queriesToDeselect from VehicleRegistrationQuery:
- FIXED: TX_TLETS (v3.1)
- FLAGGED: HI_HCJDC_OFML

## Attention Field Hidden Automation — Flagged 2026-05-13

Fix pattern (same as FL_FCIC v4.0): remove CommsysGetLastNameFirstNameInitialRuleHandler,
add visible FormInput for Attention (DH-suffix where applicable), update sourceField.

| # | Provider | QIDMs affected | Scope | Fix |
|---|---|---|---|---|
| 1 | LA_LEMS | v2.5 |  | 63P/0F/0W/0LIM |
| 2 | HI_HCJDC_OFML | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 3 | TX_TLETS | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 4 | CA_eSUN | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 5 | CA_VENTURA_COUNTY | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 6 | OH_LEADS | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |
| 7 | TN_TIES | DriverHistoryQuery | DH only | Add attentionDH FormInput on DH card; remove handler; sourceField→attentionDH |

**Already clean:** NJ, CA_CLETS, CA_OCATS, CA_SLO, IL, MD, NY, OR (no Attention attr),
AZ (Attention visible, no handler), NM (Attention InpH, no handler), FL (FIXED v4.0)

**Also noted:** TX_TLETS EmailAddress on DL+DH — no form field AND no handler (orphan, sends empty).

## KB-Based RMS — 2026-05-14

All 38 build scripts (19 BASE + 19 MC) now use `tools/_build_rms_bundle.ps1`
to construct the RMS bundle and CommSys QRDM from inline KB specifications. No external
template dependency — HIDLE_MC.json and HIDLE.json load paths both eliminated.

**Methodology**: Build from KB knowledge + metadata/devdocs only. `_build_rms_bundle.ps1`
defines all RMS and CommSys result-mapping data in code. No HIDLE.json, no patches, no
cleanup. Build scripts call `Build-RmsBundle` and `Build-CommsysQrdm` directly.

**BASE migration (2026-05-14)**: All 19 BASE scripts previously loaded `source/HIDLE.json`,
cloned CommSys QRDM, and applied 5 inline patches (Patch 1/3/6/7/8). Replaced with
`Build-CommsysQrdm` + `Build-RmsBundle` — same 2-line pattern as MC scripts. ~87 lines of
HIDLE load + QRDM clone + patch code eliminated per script (~1,650 lines total).
Migration script `_migrate_base_rms.ps1` deleted after successful run.

## Shared Layout Helpers — 2026-05-14

All 38 build scripts (19 BASE + 19 MC) now use `tools/_build_layout_helpers.ps1` for QIF layout construction.
Previously each script duplicated ~95 lines of identical helper functions (N, Inp, InpH, Sel,
SelH, Dt, BuildMultiCardLayout, AddCadNodes, AddFrNodes, MakeLayouts). Now consolidated into
a single 103-line shared module. InpH signature standardized to include maxLen parameter
(AZ_AZDPS 6 call sites updated). ~1,800 lines of duplication eliminated.

### Provider Helpers — `tools/_build_provider_helpers.ps1`

All 38 build scripts (19 BASE + 19 MC) now use `tools/_build_provider_helpers.ps1` for provider
boilerplate: AUTH config, QMF, QRDM, ENTITIES bundle, and output+validation. Previously each
script duplicated ~60 lines of identical AUTH/QMF/QRDM blocks plus ~20 lines of output/validation
code. Now consolidated into 5 shared functions (Build-Auth, Build-Qmf, Build-ProviderQrdm,
Build-EntitiesBundle, Write-ProviderJson). Write-ProviderJson standardizes pretty-printed output,
phase archiving, and validator-with-exit-on-fail across all scripts. ~2,400 lines
of duplication eliminated. Migration completed 2026-05-14 with 5 verification builds (CA_CLETS_OCATS
63P, IL_LEADS_OFML 61P, AZ_AZDPS 71P, FL_FCIC 102P, TN_TIES 80P — all 0F/0W).

### Already Built, Verified, and MERGED to Single-JSON (3)

| Provider | Version | Score | Status |
|---|---|---|---|
| NJ_NJCJIS | v4.0 |  | Single-JSON merged 2026-05-21, State defaults, CAD audit CLEAN |
| CA_CLETS | v2.5 |  | Single-JSON merged 2026-05-21, 40/40 combos, live-tested |
| FL_FCIC | v5.1 |  | Single-JSON merged 2026-05-21, 33 combos, Attention visible |

### Flagged for Full Rebuild on Next Test (16)

Scripts updated, NOT yet built. On first test of each provider:
1. Delete old BASE script, rename MC→primary (`build_<provider>.ps1`), update output to `<PROVIDER>.json`
2. Run build script, then build_report.ps1, verify 0 FAIL on all checks including CAD audit
3. Reports go to `docs/` (not `docs/base/` or `docs/mc/`)

| # | Provider | MC Script Updated | Attention Fix Needed | Notes |
|---|---|---|---|---|
| 1 | TX_TLETS | YES | YES (DH only) | +race dead field, camelCase applied |
| 2 | HI_HCJDC_OFML | YES | YES (DH only) | Standard cleanup |
| 3 | LA_LEMS | YES | YES (ALL 7 QIDMs) | +race dead field |
| 4 | AZ_AZDPS | YES | NO | Keep SSN, remove PlateYear, unique $final assembly |
| 5 | NY_NYSPIN_EJUSTICE | DONE (v2.0) | DONE (v2.0) | Merged 2026-05-22 |
| 6 | CA_VENTURA_COUNTY | YES | YES (DH only) | Standard cleanup |
| 7 | CA_eSUN | YES | YES (DH only) | Standard cleanup |
| 8 | CA_SAN_LUIS_OBISPO | YES | NO | Standard cleanup |
| 9 | CA_CLETS_OCATS | YES | NO | Standard cleanup |
| 10 | IL_LEADS_OFML | YES | NO | Standard cleanup |
| 11 | MD_METERS | YES | NO | +race dead field |
| 12 | OH_LEADS | YES | YES (DH only) | Standard cleanup |
| 13 | NM_NMLETS_OFML | YES | NO | Standard cleanup |
| 14 | OR_LEDS | YES | NO | Standard cleanup |
| 15 | TN_TIES | YES | YES (DH only) | Keep SSN |
| 16 | CA_CONTRA_COSTA | NO | NO | Incomplete — awaiting updated devdoc/metadata |

## Single-JSON Merge — 2026-05-21

BASE/MC dual-variant build path eliminated. One build script per provider → one JSON output.
- NJ_NJCJIS, FL_FCIC, CA_CLETS: MERGED (scripts renamed, JSONs renamed, reports in docs/)
- 16 remaining providers: merge on next rebuild (see instructions above)
- Tools updated: pipeline.ps1, enforce.ps1, build_report.ps1, sync_version_docs.ps1, audit_cad.ps1
- KB updated: BUILD_RULES.txt Section 6, CLAUDE.md

## CAD Defaults — Flagged 2026-05-19

CAD dispatch does NOT apply QIF form initialValues. Fields in any[] with initialValues
need combination-level `defaults[]` to ensure CAD-dispatched XML includes them.
audit_cad.ps1 CHECK 6 now validates this automatically. BUILD_RULES.txt Section 12 documents the rule.

**NJ_NJCJIS v3.3 DONE** — all 13 combos have defaults. 0 FAIL on CAD audit CHECK 6.

**142 FAIL across remaining 17 providers.** Most common missing defaults:
- ImageIndicator (nearly all providers that have it)
- LicensePlateTypeCode / LicensePlateYear (all providers with plate combos)
- RelatedHitSearchIndicator (TX_TLETS)
- PurposeCode (CA providers — flagged as INFO due to codeTypeProvider)

Fix on next rebuild of each provider. Fields to default are provider-specific — check
each provider's form initialValues, not a universal list.

## Legacy Artifact Cleanup — Flagged 2026-06-03

On rebuild of each remaining provider, also clean up legacy BASE/MC artifacts.
See BUILD_RULES.txt Section 13 for full checklist.

| Cleanup Item | Providers Affected |
|---|---|
| Delete _BASE_TEST_MATRIX.txt + _MC_TEST_MATRIX.txt | 14 (all except NJ, FL, TX, CA_CLETS — cleaned 2026-06-03) |
| Delete BASE_SIM/MC_SIM test logs | AZ_AZDPS, NY_NYSPIN_EJUSTICE |
| Rename _MC suffix JSON to {PROVIDER}.json | 12 (_MC suffix providers) |
| Consolidate dual JSON (BASE + MC) | HI_HCJDC_OFML (only provider with 2 root JSONs) |
| Regenerate METADATA_REFERENCE (remove "MC expansion candidate") | 14 (all except NJ, FL, TX, CA_CLETS — fixed 2026-06-03) |

## Next Actions
- TX_TLETS v3.3 live testing in progress (imported TLETS USx Tenant 2026-06-03)
- Provider work order: TX_TLETS (ACTIVE), NY, AZ
- Merge BASE/MC → single-JSON on each rebuild (16 providers)
- Fix Attention hidden automation on next rebuild of each flagged provider
- Fix CAD defaults (142 FAILs) on next rebuild of each provider
- Legacy cleanup per Section 13 checklist on each rebuild
- Each provider's first test triggers: merge scripts → build → build_report → verify all checks CLEAN
