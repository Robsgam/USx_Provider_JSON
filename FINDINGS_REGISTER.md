# FINDINGS REGISTER — THE WORK LOG

> **This file is the guide for work moving forward** (Rob, 2026-08-20: *"i want the build test stsues
> we derived to be durably saved and be the guide for work moving forward"*). Build order, per-provider
> status, and every open finding live here. Read it before starting any provider.
>
> **Why it exists.** Every finding below came from a gate that already existed and that **nothing ran
> automatically**. `audit_layout_flow` (08-11) and `audit_name_components` (08-17) were wired into no
> orchestrator, so their findings surfaced only when a human typed the tool name. That is how
> NJ_NJCJIS — *named in writing* in CLAUDE.md on 08-17 — sat at `0 FAIL / 0 WARN` through a full
> portfolio sweep and two more days of runs. Both are now wired (`enforce` PHASE 2w / 2x, advisory).
> **This file is the backstop: a finding written here cannot be lost to nobody thinking to ask.**
>
> **Rules.** Never delete a row — move it to DONE with the version that fixed it. `REAL?` is the
> load-bearing column: prefilled, adjudicated or cosmetic findings are **not** defects, and treating
> one as a defect costs a re-sweep for nothing. Re-derive every number with the tools
> (`audit_layout_flow -All`, `audit_name_components -All`, `audit_wiring_closure -All`), never from
> memory. **DO NOT BUILD anything here until the pass is authorised.**

---

## 0. THE COST RULE — why the order looks like this

| State | Meaning | Cost of changing it |
|---|---|---|
| **never-tested** | no logs at all | **nothing** — no package to lose, no re-sweep |
| **tenant-verified** | passing logs from a sweep Rob sat through | archives those logs → **Rob must re-drive the whole sweep** |

Every provider in the build queue below is **never-tested**, so the entire queue costs zero of Rob's
time. That is why it runs first. The tenant-verified providers are tracked separately, and only two
of them need anything at all.

Standing rulings: **re-test cost is NOT grounds to defer a fix** (Rob 2026-08-11), and
**"resweeping a fixed provider is what needs to happen"** (Rob 2026-08-20) — so a real defect gets
fixed even on a verified provider. The cost table decides ORDER, never whether.

---

## 1. BUILD ORDER — Rob's queue, 2026-08-20 — ✅ **COMPLETE, ALL TWELVE BUILT**

Rob 2026-08-20: *"build them all and build contra costa as a ca clets clone for now."* Done in one
pass, one provider at a time, each `enforce` **45 PASS / 0 FAIL / 0 WARN**, each committed and
pushed separately. **Every row below is now IMPORT + SWEEP work, not build work.**

| # | Provider | Built | Cards | What it took beyond the queue entry |
|---|---|---|---|---|
| — | **NY_NYSPIN_EJUSTICE** | v4.24 → **v4.26** | — | v4.25 did the labels + DH merge; v4.26 fixed 2 L6 rows found by the portfolio-wide sweep |
| 1 | **OH_LEADS** | v2.10 → **v2.11** | 5 | name pool fix on 4 combos |
| 2 | **NM_NMLETS_OFML** | v2.4 → **v2.5** | 6 | name pool fix on 2 combos. **Its L9 is an ACCEPTED OPERATOR OVERRIDE** — race on line 3 after sex, by Rob's directive. I tried to "fix" it and reverted |
| 3 | **LA_LEMS** | v3.1 → **v3.2** | 12 → 6 | the corrected L2 rule caught a Boat row *I* had just mis-ordered |
| 4 | **CA_eSUN** | v2.3 → **v2.5** | 16 → 6 | 4 pre-existing OVER-PERMITs cleared; **built `QW.N`** (a real metadata variant) rather than accept a divergence. v2.5 REVERTED one v2.4 tightening — see §D |
| 5 | **MD_METERS** | v2.1 → **v2.2** | 13 → 6 | **owed NOTHING on ImageIndicator** — CLAUDE.md names it as the last `'N'` carrier and that prose is STALE (12 defaults already `'Y'`, 0 at `'N'`) |
| 6 | **TN_TIES** | v2.2 → **v2.3** | 14 → 6 | class-J `RQ05` adjudicated: the registry row was already right, the CODE COMMENT was arguing the opposite of the devdoc. **Found unbuilt `RQ01` — Rob's call, §C** |
| 7 | **OR_LEDS** | v2.4 → **v2.5** | 11 → 5 | layout only, as predicted — and the collapse EXPOSED a real L9 that the small cards had hidden |
| 8 | **CA_VENTURA_COUNTY** | v2.4 → **v2.5** | 20 → 6 | widest collapse. 1 UNDER / 9 OVER cleared; `IV.4` registered as structurally unbuildable |
| 9 | **CA_SAN_LUIS_OBISPO** | v2.4 → **v2.5** | 13 → 6 | OLN maxLen asymmetry (17 DL / 20 DH) PRESERVED and flagged so nobody harmonises it |
| 10 | **CA_CLETS_OCATS** | v2.6 → **v2.7** | 16 → 5 | the two UN-PREFILLED discriminators (`LicensePlateTypeCode`, `businessIndicator`) survived the rewrite — v2.6's `4K`/`VC` work intact |
| 11 | **CA_CONTRA_COSTA** | v2.3 → **v2.4** | 7 → 6 | clone shape done. **JAWS ruling still open**; its 4 UNDER / 3 OVER deliberately untouched, listed verbatim in its BUILD_NOTES |

**Portfolio effect, measured across all 20 (never from memory):**
`audit_name_components` **216 components / 0 C1 / 0 C2 / 0 C3** — closed.
`audit_layout_flow` **139 → 10 findings**, providers-with-findings **19 → 7**. The 10 remaining are on
FL(1) HI(1) IL(2) NM(1) TX(1) TX_TLETS_CCH(2); six of those seven are tenant-verified, so each costs
a full re-sweep, and NM's is the recorded override. Validator: 20 providers **0 FAIL / 0 WARN**.

**Not in the build queue, tracked separately:**

| Provider | State | Owed |
|---|---|---|
| ~~**NJ_NJCJIS** v4.17~~ | ✅ **LIFECYCLE-COMPLETE 2026-08-20** | Nothing. 41/41 ALL-PASS, DEX-988 comment **802981**, middle name + suffix wire-proven |
| **TX_TLETS_CCH** v1.17 | fully wired | **DRIVE ONLY** — 14 pooled combos, 24 planned tests, 0 logs. Never imported. Lockstep with TX_TLETS |
| AZ, CA_CLETS, FL, HI, IL, TX | tenant-verified | nothing built; layout findings above cost a re-sweep each |


## 2. NAME COMPONENTS — ✅ **CLOSED 2026-08-20. 216 components / 0 C1 / 0 C2 / 0 C3 across all 20.**

`audit_name_components -All` now reports **20 providers compared / 216 components examined /
C1 no-control 0 / C2 not-composed 0 / C3 not-in-pool 0**. Every provider's officer can type a middle
name and a suffix, every component is composed into its pool's `FormatStringRuleHandler`, and every
component sits in at least one combination's `any[]`.

**The chain is self-closing, which is why it is finished rather than merely built:** components in
`any[]` → `emit_test_plan` generates one `_af_` test per `any[]` field → the sweep proves the wire.
Nothing hand-written. AZ is the reference: `DQN` → `DOE, JOHN` · `DQN_af_nameMiddle` →
`DOE, JOHN A` · `DQN_af_nameSuffix` → `DOE, JOHN JR`. NJ_NJCJIS reproduced it live on 08-20.

**What remains is PROOF, not wiring.** Seven providers have committed `_af_` logs (AZ, CA_CLETS, FL,
HI, IL, NJ, TX). The other thirteen have the plan tests generated and will prove them on their first
sweep — TX_TLETS_CCH is the one that is fully wired and has never been driven at all
(`[FLAG:nameparts-untested-unfrozen]`, 14 pooled combos / 24 planned tests / 0 logs).

**The one thing NOT settled is COSMETIC and needs a ruling, not a build:** the fieldId casing is split
roughly 50/50 (`NameMiddle` vs `nameMiddle`) and SEVEN providers are internally MIXED — AZ 6/6,
CA_CLETS 10/23, FL 6/13, IL 2/4, NY 4/9, OH 4/10, OR 2/4. No gate flags it. See §C.

## 3. NJ_NJCJIS — CLOSED 2026-08-20

Plan regenerated (39 → 41), swept 41/41, middle name and suffix wire-proven. Nothing owed.

---
## 4. NY WORK ORDER — CLOSED. Built as v4.25 then v4.26.

v4.25 delivered the labels (`MI` → `Middle Name` on both pools) and the DH card merge Rob asked
for. v4.26 then fixed two L6 rows (Vehicle `ROW_VEH_3`, Article `ROW_ART_2` — `@('4','4')` →
`@('6','6')`) that only surfaced once the portfolio-wide sweep compared NY against a converged
baseline. Neither version was ever imported, so the second bump cost nothing.

## A. TENANT-VERIFIED — high priority (Rob 2026-08-20). Each fix costs a re-sweep.

| Provider | Ver | Logs at risk | Finding | Class | REAL? | Status |
|---|---|---|---|---|---|---|
| **NJ_NJCJIS** | v4.17 | 0 (already archived) | Middle+Suffix absent, then not-in-pool | C1 ×2 → C3 ×2 | **YES** | **FIXED 08-20** — controls + composite + AP #15 separators + `FULL.any[]`. Now 0 C1 / 0 C2 / 0 C3. **Owes: import, 40-test sweep, DEX-988 comment, Newark re-import** |
| **NY_NYSPIN_EJUSTICE** | v4.24 | 75 | `RVIN` needs `RegistrationState`, positioned below the VIN row | L2 SET-BELOW-ANY | **NO — I REPORTED THIS AS A DEAD END AND IT IS NOT.** `RCAR` is `set[VehicleIdentificationNumber]` gated `State NOT_EXISTS`, so a VIN with State blank fires `RCAR`. State below the identifiers is CORRECT — it chooses the network | **CLOSED — false positive.** L2 rule corrected 08-20 |
| **NY_NYSPIN_EJUSTICE** | v4.24 | 75 | `MI` label on `nameMiddle` **maxLen=35**, and again on `nameMiddleDH` | L7 ×2 | **YES** — label says *initial*, field takes a full name, so the officer under-fills and the wire carries a less specific name. Sat unnoticed 07-27 → 08-18 | OPEN |
| **NY_NYSPIN_EJUSTICE** | v4.24 | 75 | `ROW_ART_2` and `ROW_VEH_3` sum to 8 not 12 | L6 ×2 | no — dead space only | OPEN (cosmetic) |
| **FL_FCIC** | v7.24 | 118 | Same shape as NY: `RegistrationState` below 2 optionals on the VIN combo | L2 | **NO — same false positive.** `FRQVehicleIdentificationNumber` is `set[VehicleIdentificationNumber]` gated `State NOT_EXISTS` and backs it | **CLOSED — false positive** |
| **FL_FCIC** | v7.24 | 118 | Boat `ROW_BOA_4B` — `BirthDate` alone on a 12-col row | L5 | no — cosmetic | OPEN |
| **CA_CLETS** | v2.26 | **111** | `purposeCode` positioned below optionals on `IG.QGB` and `IR.QVC.N` | L2 ×2 | **NO** — `purposeCode` is prefilled `'C'` on all 5 entities, so it cannot be left blank. **Do not "fix" this** | CLOSED — benign |
| **TX_TLETS** | v4.21 | **96** | `NameLast` below optional `messageKey` on `CPLName` | L2 | **NO** — already a recorded DEX-1283 override | CLOSED — adjudicated |
| **IL_LEADS_OFML** | v2.8 | **44** | `ROW_BOA_2`, `ROW_GUN_2` sum to 8 not 12 | L6 ×2 | no — dead space only | OPEN (cosmetic) |
| **HI_HCJDC_OFML** | v4.20 | **50** | `ROW_VEH_1` — `LicensePlateNumber` (maxLen 10) alone on a 12-col row | L5 | no — cosmetic | OPEN (cosmetic) |
| **OH_LEADS** | v2.10 | **56** | Middle/Suffix controls exist and are composed but are **in no combination pool** | C3 ×6 | **YES** — see the C3 note above; the officer's middle name is dropped today | OPEN |
| **AZ_AZDPS** | v3.11 | 58 | — | — | — | **CLEAN on all three gates.** The reference for name-component wiring |

⚠️ **A layout/label fix leaves the wire IDENTICAL and that is provable, not assumed.** Method used on
OH v2.10: the PROVIDER bundle (all QIDMs + AUTH/QMF/QRDM) hashes identically with the version string
normalised, the ENTITIES bundle matches with `props.title` blanked, and every captured wire is
byte-identical to its predecessor with transaction ids normalised. Do that rather than asserting it.
**Per-entity fingerprints are the WRONG proof** — they include the layout, so they legitimately move.

---

## B. NEVER-TESTED — ✅ **ALL BUILT 2026-08-20.** These rows are now IMPORT + SWEEP work.

Every provider that was in this table has been rebuilt; see §1 for the versions and what each took.
Kept here only as the record of what the pass was FOR — do not re-derive work from it.

| Provider | Now | Layout findings | C1 | Residual, if any |
|---|---|---|---|---|
| **CA_VENTURA_COUNTY** | v2.5 | 0 | 0 | `IV.4` registered unbuildable (MessageKeyModifier has no authority anywhere in the XML) |
| **CA_eSUN** | v2.5 | 0 | 0 | 1 OVER-PERMIT that is a **GATE GAP, not a defect** — Choice-inside-Any; registered |
| **CA_CLETS_OCATS** | v2.7 | 0 | 0 | — |
| **CA_CONTRA_COSTA** | v2.4 | 0 | 0 | **4 UNDER / 3 OVER deliberately untouched — Rob's JAWS ruling** |
| **TN_TIES** | v2.3 | 0 | 0 | class-J `RQ05` registered (both fixes are worse); **unbuilt `RQ01` is Rob's call** |
| **MD_METERS** | v2.2 | 0 | 0 | — (owed nothing on ImageIndicator; CLAUDE.md prose is stale) |
| **CA_SAN_LUIS_OBISPO** | v2.5 | 0 | 0 | OLN maxLen 17/20 asymmetry PRESERVED by design |
| **LA_LEMS** | v3.2 | 0 | 0 | Lafayette runs a hand-built LA_LEMS that is NOT ours |
| **OR_LEDS** | v2.5 | 0 | 0 | — |
| **TX_TLETS_CCH** | v1.17 | 2 (L2, L4 — L4 is by design) | 0 | **DRIVE ONLY**, never rebuilt. `[FLAG:nameparts-untested-unfrozen]` |
| **NM_NMLETS_OFML** | v2.5 | 1 (L9, **recorded override**) | 0 | — |
| **NY_NYSPIN_EJUSTICE** | v4.26 | 0 | 0 | — |
| **OH_LEADS** | v2.11 | 0 | 0 | — |

## C. PORTFOLIO / PROCESS — not provider-specific

| Item | Detail | Status |
|---|---|---|
| **13 providers owe IMPORT + SWEEP** | Every one is build/spec/reachability-complete. Authority: `report_import_owed.ps1`. **Nothing further can be BUILT to move the mission number** | **THE ONLY REMAINING ACTIVITY** |
| **11 providers owe a PICKLIST CAPTURE** | Each rebuild regenerated `<P>_PICKLIST_SCOPE.json`, but only a tenant capture produces `TENANT_PICKLISTS.json` | OPEN |
| **AZ_AZDPS owes a PICKLIST RE-SCOPE — and nothing swept for it** | ✅ **SWEEP FIXED 2026-08-21; the capture itself is still owed.** AZ's `TENANT_PICKLISTS.json` covers **one entity** (Vehicle, 3 fields), so `NCIC_ARTICLE_TYPE`, `NCIC_FIREARM_CALIBER`, `NCIC_FIREARM_MAKE` and `YES_NO_UNKNOWN` were never scoped. **`audit_picklist_scope` had been REPORTING this correctly all along** — but `enforce` runs it ONE PROVIDER AT A TIME and `doctor` did not run it at all, so the NOTE only appeared if someone happened to enforce AZ. Now has `-All`/`-Providers` and is composed into `doctor`: **20 examined / 10 owe the one-time capture / 1 owe a re-scope / 9 current.** ⚠️ **DO NOT "improve" this to a per-CONTROL check.** My control-level probe said "21 of 158 dropdowns uncovered" and read as portfolio-wide drift; 13 of the 21 were AZ (already reported) and the other 8 are `RegistrationStateDH`/`ImageIndicatorDH`/`relatedHitSearchIndicator` REUSING an already-captured category — same option list, nothing to re-capture. Per-control would be 8 permanent non-findings | OPEN — **tenant action**: capture AZ's 4 categories on its next visit |
| **`audit_query_trace` resolved metadata names against the attribute `name` only** | ✅ **FIXED 2026-08-21.** It now also matches `targetField`, which is the actual wire contract (`usx-tooling` Step 3). FL_FCIC's DH QIDM names every attribute cleanly (`State` ← `RegistrationStateDH`) except ONE, declared `name=OperatorLicenseNumberDH` / `targetField=OperatorLicenseNumber` — so metadata `OperatorLicenseNumber` matched nothing, fell back to the literal name, and `KQ set[OperatorLicenseNumber,State]` was reported UNBUILT while it is built as `KQOperatorLicenseNumber` and the wire says `<OperatorLicenseNumber>` on all 4 logs. **Portfolio-wide: BUILT 391 → 392, MISSING 21 → 20, exactly one line removed, none added** — a resolution, not a suppression. LAW 2: deleting the combo from a replica brings the identical MISSING line straight back. ⚠️ **My first diagnosis — "it matches on the keyRef string" — was WRONG;** it has matched on `set[]` containment since it was written | DONE |
| **`audit_requirement_fidelity` cannot see a `<Choice>` nested in `<Any>`** | So a legal optional reads OVER-PERMITTED. PROVEN on CA_eSUN `DriverLicenseQuery L1{Name}` = `Set[PurposeCode, Name, Any[Choice[Age\|BirthDate]]]`; registered there as `demoted-to-any` scoped to `L1.N`. **Some of the portfolio's remaining OVER-PERMITs may be this same false class** | OPEN — owes the 6-provider fixture + 20-provider sweep |
| **Name-component fieldId casing — RE-MEASURED 2026-08-24, and this row was WRONG** | It said "SEVEN providers internally MIXED (AZ 6/6, CA_CLETS 10/23, FL 6/13)". Measured at the **form fieldId** level across all 20: **PascalCase 10** (OCATS, CONTRA_COSTA, eSUN, SLO, VENTURA, LA_LEMS, MD, NJ, NM, TN) · **camelCase 9** (CA_CLETS, FL, HI, IL, NY, OH, OR, TX, TX_CCH) · **internally mixed: ONE — AZ_AZDPS** (`nameMiddle`+`NameMiddleDH`, `nameSuffix`+`NameSuffixDH`). The old "seven" came from counting raw strings without asking which KEY they sat under; a first pass today reported **all 20** as mixed for exactly that reason, because PascalCase `targetField` beside camelCase `fieldId` is the DOCUMENTED convention, not a defect. **Rob's PascalCase ruling is settled and complete and this is NOT a hole in it** — middle name and suffix are not among the 22 CAD-integration tokens (verified: 0 matches), CAD never auto-populates them, so the rule never reached them; they were added provider-by-provider 08-17 → 08-21 following whatever each build script already did. **ZERO functional impact:** not CAD-populated, and the wire carries the composite `<Name>` from the format handler regardless of the control's name. Converging all 19 = 19 rebuilds + archiving 10 passing test packages for no functional gain — **NOT recommended.** | **Only AZ is worth fixing** (internal inconsistency, free at the rebuild its plan-dedupe flag already owes). The 10-vs-9 split is a no-op |
| **TN_TIES `RQ01` unbuilt** | Maps to devdoc "1. (In) LicensePlateNumber"; the build serves blank-State plate with `QV.P`, the NCIC query. If wrong, in-state TN plate searches reach NCIC not TIES/DMV | **Rob's call** — routing model |
| **CA_CONTRA_COSTA JAWS / SuperQuery scope** | v2.4 built as the CA_CLETS clone and deliberately did NOT pre-empt the ruling. Its 4 UNDER / 3 OVER are listed verbatim in its BUILD_NOTES | **Rob's ruling** |
| **CLAUDE.md prose is STALE in two places** | (1) names MD_METERS as the last `ImageIndicator='N'` carrier — measured 08-20, MD has 12 `'Y'` defaults and ZERO `'N'`, and `audit_reverse_propagation` says the flag is fully PROPAGATED. (2) `audit_layout_flow` baseline still reads "139 findings / 19 providers" | OPEN — doc-only |
| eSUN export in git history | 228KB tenant export still in pushed history at `8273a87f`; removing it needs a rewrite + force-push | **Rob's call** |
| Newark Foundation behind | v4.16 vs repo v4.17 | **Rob's call** |
| HDLE held at v4.15 | Deliberate. HI production discards NCIC hit content until the hit block is verified | HELD by decision |
| HI hit block | Config-present, never exercised against a live hit response | Needs 1 hit query in HI's own tenant |
| Officer guides | Content-poor, not stale. Rewrite requested, shape not agreed | OPEN |
| 38 clone groups | `audit_log_inflation` class A. Class B/C/D all 0 | Clears at each provider's own rebuild |
| `audit_name_components` now at 0 | 216 components, 0 C1/C2/C3 across all 20 | **Ready to make BLOCKING** |
| `audit_layout_flow` residue = 10 | 7 providers; 6 tenant-verified (re-sweep each) + NM's recorded override | Make BLOCKING once those are recorded overrides |

---

## D. MY OWN RECURRING ERRORS — read before trusting a number in here

- **`<Any>` IS NESTED INSIDE `<Set>` in this schema.** `$c.Requirements.Any` returns NOTHING, so I read
  "no optionals anywhere", tightened three `any[]` pools on CA_eSUN v2.4 and **dropped a legal
  optional**. **Dump `$c.Requirements.OuterXml`.** Caught only because my fresh measurement
  contradicted a committed registry row — one of them had to be wrong, and it was mine.
- **A finding on every provider is my probe, not the portfolio.** `-match` is CASE-INSENSITIVE; a
  single-line regex finds nothing in pretty-printed JSON; `@($null).Count` is 1; `-Quiet` suppresses
  `Write-Host` so a piped capture is empty.
- **An operator override is recorded FOR A REASON.** I re-split NM's race row to satisfy L9 and had to
  revert — Rob directed it, and the override was in the BUILD_NOTES *and* the comment I displaced.
- **A line-number `sed` is invalid the moment the file changes length**, and **a `head -N` splice is
  only safe if you know what line N is** — three BUILD_NOTES inserts landed inside an existing entry.
- **Narrowing an `any[]` strands its `defaults[]`** (wiring class E). Twice in one day.
- **A gate suite chained after a FAILED build reports on the stale JSON.** The tell was an ABSENT
  `RESULTS:` line, not a complaint. Confirm the build succeeded before reading gates.
- **Read a gate's verdict BEFORE committing, not after.**

---
## L2 RULE CORRECTED 2026-08-20 — five of its seven findings were FALSE POSITIVES

`audit_layout_flow`'s L2 asserted *"an officer can fill everything visible above it and still fail."*
It evaluated ONE combination in isolation and never asked whether another combo in the same query
fires on what was already filled. Two guards added:

- **(d) FALLBACK EXISTS** — an alternative combo whose `set[]` is satisfiable from *this combo's own
  pool minus the flagged field*. **NY**: `RVIN` needs `RegistrationState`, but `RCAR` is
  `set[VehicleIdentificationNumber]` gated `State NOT_EXISTS`, so a VIN with State blank fires `RCAR`.
  **FL** identical (`FRQVehicleIdentificationNumber` backs `RQVehicleIdentificationNumber`). State
  sitting on the shared-context row below the identifiers is CORRECT — it is the field that chooses
  the network.
- **(e) PREFILLED** — a mandatory field carrying a form `initialValue` can never be blank, so its
  position cannot cause the failure. CA_CLETS / CA_CONTRA_COSTA `purposeCode` = `'C'`.

⚠️ **MY FIRST VERSION OF GUARD (d) WAS A BLANKET SUPPRESSOR AND THE LAW 2 PROBE CAUGHT IT.** It
accepted any combo satisfiable from fields *positioned above* the flagged one — so on NY it latched
onto `RVEH` (`set[LicensePlateNumber]`) merely because a plate control sits on row 1, even though the
officer filled a VIN. Deleting `RCAR` from a replica did NOT bring the finding back, which is how the
bug surfaced. Since nearly every card has some identifier above, that version would have silenced
almost every real L2 — a gate that cannot fail, introduced while fixing a gate that fired wrongly.
Corrected to test the combo's OWN pool. LAW 2 then passed both ways: `RCAR` removed → fires;
`RCAR` present → silent.

**Portfolio effect: 83 → 78 layout findings, L2 7 → 2.** The two survivors (TX_TLETS, TX_TLETS_CCH
`CPLName`) are REAL — `NameLast` after `messageKey` with no fallback — and are the recorded DEX-1283
override, so they should keep reporting.

**Rows superseded in section A above:** NY's L2 and FL's L2 are NOT defects. Do not fix them.
