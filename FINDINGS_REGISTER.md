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

**The casing question is CLOSED 2026-08-24, and this paragraph had the number wrong.** It said SEVEN
providers were internally MIXED (AZ 6/6, CA_CLETS 10/23, FL 6/13, IL 2/4, NY 4/9, OH 4/10, OR 2/4).
Measured at the **form fieldId** level across all 20: **PascalCase 10 / camelCase 9 / internally mixed
ONE — AZ_AZDPS**, fixed at v3.12 and wire-proven unchanged (53 paired captures byte-identical). Those
old counts came from tallying raw string occurrences without asking which KEY each sat under; a first
re-measurement reported **all 20** as mixed for exactly that reason, because PascalCase `targetField`
beside camelCase `fieldId` is the DOCUMENTED convention, not a defect. Rob's PascalCase ruling is
settled and complete and this was never a hole in it — middle name and suffix are not among the 22
CAD-integration tokens, CAD never auto-populates them, and the wire carries the composite regardless.
The 10-vs-9 split is cosmetic and is deliberately NOT being converged.

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
| **MD_METERS** | v2.3 | **46** | DL `(Out)` combination brackets `[State]` optional; `raceCode` alone decides direction, so a filled State is silently discarded when Race is also filled | 5e silent-discard | **YES** — same class as the v2.3 plate discard | **OPEN 2026-08-28** — three options in section 5e, all v2.4. Rob's call |

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
| **TN_TIES** | v2.3 | 0 | 0 | class-J `RQ05` registered (both fixes are worse); ~~unbuilt `RQ01`~~ **CLOSED 08-24 -- not a defect, the keyRef never reaches the wire** |
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
| **UNCONDITIONAL-ASSERTION SWEEP (the TN_TIES `RQ01` pattern) — DONE 2026-08-24, residue is ONE item** | Rob: *"sweep for it"*, after TN v2.6 removed a plate type that every in-state plate search was transmitting because the control is prefilled for the OUT-of-state combo's benefit. **Signature:** a field PREFILLED on the form, sitting in combo C's `any[]`, absent from C's own `set[]` — so C transmits it unconditionally — with the aggravating factor that it is `set[]`-mandatory on a DIFFERENT combo, i.e. the prefill exists for someone else. **`audit_requirement_fidelity` is structurally blind to this** (TN's case was metadata-permitted via `QV`, so 0 OVER-PERMITTED), which is why it needed its own sweep. **MEASURED: 20 providers / 378 combos / 96 prefilled controls → 280 candidates → 14 TIER-1 (the exact TN shape) across 6 providers.** Adjudication killed 13 of 14, and the deciding test was each provider's OWN devdoc: **plate TYPE on CA_CLETS/CA_SLO/CA_VENTURA is devdoc-MANDATORY in-state** (`(In) LicensePlateNumber, LicensePlateTypeCode`) so prefilling it is correct — the opposite of TN, whose devdoc #1 is `(In) LicensePlateNumber, [InquiryTypeIndicator]` with no plate type at all; **FL's plate year is a devdoc-listed in-state optional** (`#2 (In) LicensePlateNumber, [LicensePlateYear, Requestor]`) so correct; **CA_CLETS's plate year+type over-permit was ALREADY REGISTERED 2026-07-31** using this same devdoc test, and that row explicitly warns *"do not generalise one to the other"* — it was right; **AZ `dexStateUserId`, FL `relatedHitSearchIndicator='Y'`, LA `ImageIndicator='Y'`** are identity/officer-default fields under Rob's own standing rules. TIER 2 (267) is `ImageIndicator` ×100, `relatedHitSearchIndicator` ×49, `Attention` ×21 — deliberate defaults, not this pattern. **SURVIVING RESIDUE — exactly one: `CA_SAN_LUIS_OBISPO` `QV.P` `LicensePlateYear='2026'`.** Its devdoc lists plate year ONLY on `#3 (Out)`; `#1 (In)` is plate + plate type. So every in-state SLO plate search asserts registration year 2026, which can only narrow a match. Metadata `QV{plate}` permits it, so it is legal — same position TN was in. **CA_SLO is NEVER-TESTED, so the fix is FREE** | **Do it at CA_SLO's own next rebuild** (which it needs before its sweep anyway) — not a separate bump. Keep plate TYPE (devdoc-mandatory in-state), drop plate YEAR only |
| **AZ_AZDPS owes a PICKLIST RE-SCOPE — and nothing swept for it** | ✅ **SWEEP FIXED 2026-08-21; the capture itself is still owed.** AZ's `TENANT_PICKLISTS.json` covers **one entity** (Vehicle, 3 fields), so `NCIC_ARTICLE_TYPE`, `NCIC_FIREARM_CALIBER`, `NCIC_FIREARM_MAKE` and `YES_NO_UNKNOWN` were never scoped. **`audit_picklist_scope` had been REPORTING this correctly all along** — but `enforce` runs it ONE PROVIDER AT A TIME and `doctor` did not run it at all, so the NOTE only appeared if someone happened to enforce AZ. Now has `-All`/`-Providers` and is composed into `doctor`: **20 examined / 10 owe the one-time capture / 1 owe a re-scope / 9 current.** ⚠️ **DO NOT "improve" this to a per-CONTROL check.** My control-level probe said "21 of 158 dropdowns uncovered" and read as portfolio-wide drift; 13 of the 21 were AZ (already reported) and the other 8 are `RegistrationStateDH`/`ImageIndicatorDH`/`relatedHitSearchIndicator` REUSING an already-captured category — same option list, nothing to re-capture. Per-control would be 8 permanent non-findings | OPEN — **tenant action**: capture AZ's 4 categories on its next visit |
| **`audit_query_trace` resolved metadata names against the attribute `name` only** | ✅ **FIXED 2026-08-21.** It now also matches `targetField`, which is the actual wire contract (`usx-tooling` Step 3). FL_FCIC's DH QIDM names every attribute cleanly (`State` ← `RegistrationStateDH`) except ONE, declared `name=OperatorLicenseNumberDH` / `targetField=OperatorLicenseNumber` — so metadata `OperatorLicenseNumber` matched nothing, fell back to the literal name, and `KQ set[OperatorLicenseNumber,State]` was reported UNBUILT while it is built as `KQOperatorLicenseNumber` and the wire says `<OperatorLicenseNumber>` on all 4 logs. **Portfolio-wide: BUILT 391 → 392, MISSING 21 → 20, exactly one line removed, none added** — a resolution, not a suppression. LAW 2: deleting the combo from a replica brings the identical MISSING line straight back. ⚠️ **My first diagnosis — "it matches on the keyRef string" — was WRONG;** it has matched on `set[]` containment since it was written | DONE |
| **`audit_requirement_fidelity` cannot see a `<Choice>` nested in `<Any>`** | So a legal optional reads OVER-PERMITTED. PROVEN on CA_eSUN `DriverLicenseQuery L1{Name}` = `Set[PurposeCode, Name, Any[Choice[Age\|BirthDate]]]`; registered there as `demoted-to-any` scoped to `L1.N`. **Some of the portfolio's remaining OVER-PERMITs may be this same false class** | OPEN — owes the 6-provider fixture + 20-provider sweep |
| **Name-component fieldId casing — RE-MEASURED 2026-08-24, and this row was WRONG** | It said "SEVEN providers internally MIXED (AZ 6/6, CA_CLETS 10/23, FL 6/13)". Measured at the **form fieldId** level across all 20: **PascalCase 10** (OCATS, CONTRA_COSTA, eSUN, SLO, VENTURA, LA_LEMS, MD, NJ, NM, TN) · **camelCase 9** (CA_CLETS, FL, HI, IL, NY, OH, OR, TX, TX_CCH) · **internally mixed: ONE — AZ_AZDPS** (`nameMiddle`+`NameMiddleDH`, `nameSuffix`+`NameSuffixDH`). The old "seven" came from counting raw strings without asking which KEY they sat under; a first pass today reported **all 20** as mixed for exactly that reason, because PascalCase `targetField` beside camelCase `fieldId` is the DOCUMENTED convention, not a defect. **Rob's PascalCase ruling is settled and complete and this is NOT a hole in it** — middle name and suffix are not among the 22 CAD-integration tokens (verified: 0 matches), CAD never auto-populates them, so the rule never reached them; they were added provider-by-provider 08-17 → 08-21 following whatever each build script already did. **ZERO functional impact:** not CAD-populated, and the wire carries the composite `<Name>` from the format handler regardless of the control's name. Converging all 19 = 19 rebuilds + archiving 10 passing test packages for no functional gain — **NOT recommended.** | **Only AZ is worth fixing** (internal inconsistency, free at the rebuild its plan-dedupe flag already owes). The 10-vs-9 split is a no-op |
| ~~**TN_TIES `RQ01` unbuilt**~~ **CLOSED 2026-08-24 — NOT a defect, NOT Rob's call, and it was a DUPLICATE of a decision already recorded** | The row claimed "if wrong, in-state TN plate searches reach NCIC not TIES/DMV". **That is IMPOSSIBLE: the keyRef never reaches the wire.** A real capture carries `<MessageType>VehicleRegistrationQuery</MessageType>` plus the fields and **zero** keyRef occurrences — so `QV.P` and `RQ01` emit byte-identical requests, and nothing in the request can express "send to NCIC instead of DMV". Rob, 2026-08-24: *"we only send the VehicleRegistrationQuery and not the transaction name."* Three further confirmations, each from a different direction: (1) `RQ01{plate}`, `RV01{plate}` and `QV{plate}` all have `set[]=[LicensePlateNumber]`, so they are routing-INDISTINGUISHABLE — no fill can select between them (the OCATS precedent); (2) **TN's own `ACCEPTED_DIVERGENCES` already adjudicated it in plain language** — `RQ01 ... == QV.P -> DROPPED (kept QV.P)`, plus RV01/RQ03/RV03/RV — so this row was re-litigating a closed decision as an open risk; (3) both owning gates PASS — `audit_devdoc_combinations` 14 devdoc combinations compared / 0 FAIL, `audit_query_trace` 26 built / 0 SHADOW / 0 PREFILL-DEAD and its 2 MISSING are `KQ` on **Driver History**, nothing vehicle. The built shape matches the devdoc exactly: #1 (In) plate-alone → `QV.P` gated `State NOT_EXISTS`, #2 (Out) plate+type+year+State → `RQ.P` gated `State EXISTS`. **AND `QV` IS A DATA-MINED TRANSACTION** — devdoc line 9: *"Data-Mined Transactions: NCIC (QA, QB, QG, QV, QW) and DMV (Person and Vehicle) Tags returned from Data mining"* — so it is never a query we choose to send *instead of* the DMV one; TIES runs it and returns its tags mined. `InquiryTypeIndicator` (default `3` = registration AND hotfiles) is why ONE VehicleRegistrationQuery covers both, and why building no separate stolen-vehicle query is correct | **DONE.** Residual: rename `QV.*` keyRefs at TN's next build (cosmetic, zero wire impact, free — TN is never-tested — and the current names are what made this look like a bug) |
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

## 5. UNREACHABLE METADATA OPTIONALS + REGISTRY BLIND ZONE — swept 2026-08-28

Rob: *"i want to be sure we are not leaving issues on the table."* Prompted by MD_METERS: I reported
"14 of 14 combos covered, all reachable" and he said *"i doubt you have all the combinations
accounted for."* He was right, and the reason is structural — **every number I had was closed under
what we BUILT.** `audit_test_coverage` enumerates the JSON; `<P>_SUPPORTED_QUERIES.txt` on 9 of 20
providers says of itself *"DERIVED FROM JSON COMBOS"*. A list derived from the build cannot reveal
an omission in the build.

### 5a. THE DEFECT CLASS: an optional stranded on a collapsed/unbuilt duplicate-input variant

`audit_query_trace` matches metadata→built by **CONTAINMENT on the mandatory side** (documented in
its own source, and correct: the build legitimately reshapes combos). It asks *"does some built combo
require everything this variant requires and nothing it doesn't mention?"* — it **never asks whether
the matching combo can carry that variant's OPTIONALS.** So a metadata variant with an exclusive
optional reports as `COMPLETE / 0 MISSING` while the optional is unreachable. No other gate sees it
either: `audit_devdoc_optionals` only knows devdoc-listed optionals, and `audit_wiring_closure`
needs a control to exist before it can call one dead. **No control → nothing to orphan → no test
that can fail.** Same shape as the `audit_name_components` gap.

**PROBE (validated against MD's known answer before being believed):** for each built transaction,
list `<Field name>` in the metadata and check whether the name appears **anywhere** in the emitted
JSON. Zero occurrences = defined by the authority, unreachable by any officer.

⚠️ **THE 59 BELOW IS AN INFLATED DENOMINATOR AND ROB CAUGHT IT: *"are you sure about that? you aren't
counting non basic supported queries section of metadata."* CORRECTED 2026-08-28 — THE IN-SCOPE
ANSWER IS ZERO.**

The probe scoped to built TRANSACTIONS and then counted every field any of their combinations
reference. A built transaction still contains combinations we deliberately do not build — the Nlets
multi-state paths, the mined NCIC twins, the duplicate-input siblings. Re-measured per COMBINATION,
with the referencing keyRef checked for whether we build it:

| Scope | Count | Verdict |
|---|---|---|
| field sits on a keyRef we **do not build at all** | **22** — FL 13 (`RQ`/`QW`/`DQ`/`BQ`; FL builds `FRQ*`), LA 4 (`RQS`), OH 3 (`BMVIMS`), TX 1 (`QW`), MD 1 (`ZDRV` under DL) | **OUT OF BASIC SCOPE — "never a gap in either direction"** (usx-metadata Step 5) |
| field sits on a **built** combination | **37** — NM 21, HI 8, IL 4, LA 4 | every one is `State2`–`State5` (out of scope 2026-08-02) plus NM's `FormORI` ×12 and `RelatedHitSearchIndicator` ×6, both registered |
| **genuinely unrecorded AND in scope** | **0** | |

**Two flaws in my own table, both worth keeping.** (1) FL's 13 are ALL on unbuilt keyRefs, so FL was
exonerated twice over — the QW park (5b) and this. (2) **The BUILT column matched keyRef BY NAME
without scoping to the transaction**, so MD's `DriverLicenseQuery/ZDRV{OperatorLicenseNumber}` read
`BUILT=True` because `ZDRV.N`/`ZDRV.O` exist **under DriverHistoryQuery**. A KEYREF IS NOT A VARIANT,
for the second time in one sweep. MD's field is therefore out of scope by the same rule that clears
FL. Its registry row is still correct and worth having — it states exactly this reasoning — but
calling it *"the one genuinely unrecorded item"* was wrong.

**So the honest result of this sweep is: the portfolio was leaving NOTHING on the table from this
class.** What survives is 5c (the registry blind zone), 5e (MD's DL State question, which came from
reading the devdoc rather than from this probe), and the doc-authority residue in 5d.

**Original (inflated) triage table, kept so the correction is auditable — 8 providers, 59 fields:**

| Provider | Unreachable | Recorded? | Verdict |
|---|---|---|---|
| FL / HI / IL / LA / NM | 44 × `State2`–`State5` | registry mentions FL 9, HI 4, IL 2, LA 6, NM 9 | **RECORDED** — multi-state Nlets broadcast, OUT OF SCOPE 2026-08-02. Not owed. |
| OH_LEADS | `DriverLicenseQuery/ReasonCode`, `/Requestor`, `DriverHistoryQuery/ReasonCode` | registry 8 + 7 mentions | **RECORDED** — the documented DL-vs-BMVIMS case (usx-metadata Step 1 §6). Not owed. |
| NM_NMLETS_OFML | `FormORI` ×5, `RelatedHitSearchIndicator` ×4 | registry 2 + 2 | **RECORDED.** |
| TX_TLETS | `DriverLicenseQuery/ExpandedBirthDateSearchCode` | registry 1 | **RECORDED.** |
| **MD_METERS** | `DriverLicenseQuery/YearsPastViolationsWanted` | registry **0**, build-script comment only | **CLOSED 2026-08-28** — row added. Unbuildable either way: its variant's `set[]` is byte-identical to built `ZLDR{OLN}` (dead combo), and widening `ZLDR.O.any[]` would OVER-PERMIT. |
| FL_FCIC | `DriverLicenseQuery/ExpandedNameSearchCode` | registry row `QW | *` (wildcard) + devdoc declares QW MINED + Rob parked QW/QV 2026-07-30 | **RECORDED — my "unrecorded" verdict RETRACTED, see 5b.** |

### 5b. FL_FCIC `ExpandedNameSearchCode` — ❌ **RETRACTED 2026-08-28. NOT A FINDING. FULLY RECORDED.**

**Rob: *"for fl i thought we parked that."* He was right and I published a false finding against a
LIFECYCLE-COMPLETE provider.** The item is adjudicated three times over:

- **FL's registry line 16:** `DriverLicenseQuery | QW | * | not-built | NCIC Wanted Person Query --
  CommSys auto-sends QW as a side effect of the DL query firing (platform-confirmed);
  WantedPersonQuery removed v4.2`. The field scope is the **wildcard `*`**, covering every field on
  that keyRef.
- **FL's devdoc declares it MINED:** `Data-Mined Transactions: NCIC (QA, QB, QG, QV, QW)`. A mined
  transaction is run BY THE STATE off our single request (usx-metadata Step 2b), so building no QW
  combination is CORRECT, not an omission — and an optional that exists only on QW is not owed.
- **Rob parked it explicitly, 2026-07-30:** *"no qw and qv should stay parked"* — recorded verbatim in
  TX_TLETS' and TX_TLETS_CCH's registries.
- FL builds **zero** QW combos (verified), and already records the identical pattern two rows later:
  `RelatedHitSearchIndicator ... NOT WIRED ON VEHICLE BY DESIGN -- metadata scopes it to QV, which
  this build does not carry.`

**WHY MY PROBE MISSED IT, and this is the transferable lesson: A REGISTRY ROW CAN SCOPE ITS FIELD WITH
A WILDCARD.** I grepped each registry for the literal field name and counted 0. The row that covers it
says `QW | *`. **Grep the SCOPE (query + keyRef), never only the field token** — otherwise every
wildcard row reads as an absent adjudication. Same failure shape as the four probe errors logged in
SESSION_STATE: I checked for the specific string instead of the thing that would actually be written.

**Net effect on 5a: the sweep found ZERO unrecorded items outside MD_METERS.** The portfolio was in
better shape than my table claimed. What survives is the STRUCTURAL point in 5c — and the FL case
strengthens it rather than weakening it: the registry DID hold the answer, in a form no automated
check (and not my probe) could match against the metadata field it covers.

#### Original (wrong) text, kept so the retraction is auditable

Devdoc lists it as an optional field **and names it in DL combinations #3 and #4**. Metadata defines
it on `DriverLicenseQuery` and references it in the `QW` variants:
`QW{Name}` = `Set[BirthDate, Name] Any[OperatorLicenseNumber, ExpandedNameSearchCode, ImageIndicator, RelatedHitSearchIndicator]`
`QW{OperatorLicenseNumber}` = `Set[Name, OperatorLicenseNumber] Any[ExpandedNameSearchCode, ImageIndicator, RelatedHitSearchIndicator]`
**Neither mandates `State2`, so the State2 out-of-scope ruling does NOT cover it.** The string
`Expanded` appears **0 times** in `FL_FCIC_v7.24.json` and 0 times in its registry. FL is
tenant-verified ALL-PASS 118/118 and LIFECYCLE-COMPLETE. **TN_TIES builds the field** (its ledger row
records *"ExpandedNameSearchCode transmitting at all for the first time"*), so it is real and
buildable. REAL? **probably yes, needs Rob** — cost is a v7.25 bump archiving 118 logs.

### 5c. REGISTRY CURRENCY BLIND ZONE — 193 of 263 rows (73%) unverifiable

`audit_registry_currency` checks **direction-class rows only** (`to-any` / `to-set`). Everything
else — existence-class, `unbuilt`, `missing-*`, `dead-combo` — is *not-checkable*, and the tool says
so honestly (`[FAIL] parsed rows but checked ZERO of them -- this run is not evidence`). Measured:

**263 rows / 70 checkable / 0 stale / 193 not-checkable.** Seven providers have **zero** verifiable
rows: **LA_LEMS 22, OH_LEADS 15, OR_LEDS 9, AZ_AZDPS 6, IL_LEADS_OFML 5, MD_METERS 3, CA_SAN_LUIS_OBISPO 2.**

**This is not theoretical: the first row I opened by hand inside that zone was FALSE.** MD's
`GunQuery | ZGUN | GunMake | missing-primary-combo` (2026-06-23) asserted metadata had a separate
gun-by-make search path with no JSON combo and told the next rebuild to *"build ZGUN.M"*. Metadata
holds exactly ONE GunQuery combination; the row had mistaken `primaryFieldReference="GunMake"` for a
looser requirement set. It survived **three rebuilds** (v2.1, v2.2, v2.3), each reading "build this
at the next rebuild", and acting on it would have invented a combination with a `set[]` identical to
`ZGUN` — a guaranteed dead combo. Retired 2026-08-28.

⚠️ **AND ROB CORRECTED MY FOLLOW-UP, WHICH IS THE MORE USEFUL LESSON.** Retiring it un-silenced
`audit_metadata` CHECK 5 (`GunMake: no combo uses it as primaryFieldReference`) and I wrote that up
as a *"REAL DEFECT"* needing a v2.4 bump and a re-sweep. Rob: *"we are building the combos, not
attesting to the keyref commsys will use."* **`primaryFieldReference` is our internal label, the same
class as `keyReference` — which is PROVEN to reach the wire zero times.** The field SET is what ships,
and it matches metadata exactly. So: nominal, no bump, no re-sweep. It matters only for OUR narrowing
when one keyRef carries several PF variants (CA_CLETS `IR.QVC` = Name/OLN/CII/SSN); GunQuery has one
combination, so nothing can be mis-selected. **Generalise: before calling an identity-label
difference a defect, ask whether the label reaches the wire.**

### 5d. Other measurements from the same sweep — context, not defects

- **61 metadata→built combination collapses across 13 providers** (metadata combos minus built
  combos, per built transaction): CA_CLETS +13, CA_CONTRA_COSTA +13, CA_VENTURA_COUNTY +13,
  TN_TIES +7, FL_FCIC +5, OH_LEADS +5, CA_eSUN +4, CA_CLETS_OCATS +4, LA_LEMS +4,
  CA_SAN_LUIS_OBISPO +3, HI_HCJDC_OFML +3, NJ_NJCJIS +2, MD_METERS +1, TX_TLETS +1. Negative on
  NY −3 / TX_CCH −2 / OR −1 = `<Choice>` splits, expected. **NOT a defect count** — most collapses
  are identical-`set[]` variants, out-of-scope combinations or registered divergences. It is the
  denominator for 5a: 61 places the stranded-optional class can hide, and 5a's probe found 59 fields
  across 8 of them, of which 2 were unrecorded.
- **9 of 20 `SUPPORTED_QUERIES.txt` extracts are `STATUS: PROVISIONAL` and derived-from-JSON**
  (circular query authority): CA_CLETS_OCATS, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, CA_eSUN,
  LA_LEMS, MD_METERS, NM_NMLETS_OFML, OR_LEDS, TN_TIES. `audit_supported_queries` CHECK 0 still gates
  on the devdoc directly (it ignores the extract's STATUS by design, after the AZ transaction-scope
  defect), so this is not wide open — but the label-level checks are soft.
- **6 providers carry an empty 13-line SQVR scaffold** and `audit_sqvr_integrity` passes all six —
  a file naming nothing and asserting no total gives the gate nothing to compare. CA_eSUN,
  CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY + **NM_NMLETS_OFML, OR_LEDS, TN_TIES which are ALL-PASS and
  counted LIFECYCLE-COMPLETE.** MD (08-28) and IL (08-18) are the two fixed.
- **The same three providers — NM, OR, TN — appear in all three lists above** (PROVISIONAL extract,
  empty SQVR, LIFECYCLE-COMPLETE). They were the three most recent first-ever sweeps; the build and
  the wire were closed, the documentation authority was not.

### 5e. MD_METERS DriverLicenseQuery — the State question — ✅ **CLOSED 2026-08-31, SHIPPED AS v2.4**

**Rob's ruling: "Swap to State as the discriminator."** Built, gate-clean, and MD_METERS therefore
dropped out of lifecycle-complete: 46 ALL-PASS logs archived, 15 SQVR markers back to `[PENDING]`,
re-import + full re-sweep owed. That cost was on the table when the call was taken.

**WHAT SHIPPED — three edits, DriverLicenseQuery only, no form change and no field added:**
`ZWAR.N` gains `RegistrationState NOT_EXISTS`; `ZLDR.N` and `ZLDR.O` each LOSE `raceCode NOT_EXISTS`.

**⚠️ I DEVIATED FROM THE LITERAL OPTION WORDING, DELIBERATELY, AND THIS IS THE PART TO READ.**
The option preview said *"ZLDR.N + cond RegistrationState EXISTS"*. Simulated on the v2.3 JSON via
the canonical `tools/_sim_helpers.ps1 Get-FiringKeyRef` — the same first-match walk the platform
does — that variant **kills the plain in-state name search**: `Name+Sex+DOB` → **NOTHING FIRES**, and
`OLN+Race` stays dead. That is the `TN_TIES KQ.N` defect verbatim, and the rule it breaks is already
written down: *a State gate belongs ONLY where the metadata FORKS by state.* `ZLDR{Name}` carries
`State` in `<Any>` — an OPTIONAL, not a fork. Dropping the `raceCode` gate instead delivers exactly
the routing Rob asked for with nothing dead. **Metadata is what makes State the discriminator, not a
condition:** `RaceCode` appears in BOTH `ZWAR` variants and NEITHER `ZLDR` variant, and `ZWAR{Name}`
defines no `State` field at all.

**THE TWO DEFECTS IT FIXED, both found by simulation and neither by reading:**
1. At v2.3, `Name+Sex+DOB+Race+`**`State`** matched `ZWAR.N` — a variant that defines no State — so
   the state the officer typed was **silently discarded**. Same class as the v2.3 plate type/year
   defect one version earlier.
2. `OLN + Race` matched **NOTHING**. `ZWAR.O` needs five fields so it could not take it, and
   `raceCode NOT_EXISTS` blocked the only other OLN path. Two valid identifiers, no query sent.

**ROUTING VERIFIED ON THE EMITTED v2.4** (not on intent) — 8 fills, 0 dead: `Name+Sex+DOB`→`ZLDR.N`
· `+Race`→`ZWAR.N` · `+State`→`ZLDR.N` · `+Race+State`→`ZLDR.N` (Race dropped, spec-correct) ·
`OLN` / `OLN+Race` / `OLN+State`→`ZLDR.O` · full warrant OLN fill→`ZWAR.O`.

**A SECOND, UNRELATED FINDING SURFACED WHILE DOING THIS, AND IT WAS MINE.** `enforce` came back with
a live `[FAIL] GunMake: QIDM has attribute but NO combo uses it as primaryFieldReference`. On
2026-08-28 I replaced a false ZGUN registry row with a correct explanation carrying the rule name
`primaryfieldreference-is-our-label-not-an-attestation` — and `audit_metadata` CHECK 5 honours only
an **`existence`-class** rule, so **my registration suppressed nothing and left MD_METERS carrying a
FAIL nobody had re-run enforce to see.** Exactly the trap `usx-tooling` Step 6 names: *does it
suppress anything AT ALL?* Fixed the right way rather than by hunting for a rule name — the retired
row's own instruction was *"align the label at MD's next rebuild if one happens for another
reason"*, and this was that rebuild, so `ZGUN.primaryFieldReference` is now `GunMake`. Measured both
sides: `audit_metadata` **0 FAIL (114 PASS)**, `audit_requirement_fidelity` **unchanged at 15
branches / 0 UNDER / 0 OVER** — a real clearance at zero coverage cost, and no suppression needed.

**LIMITATION #41** (populated HOME state routes a local plate to NLETS) constrained the *rejected*
option 1 (defaulting State) and is untouched by what shipped — nothing here defaults State.

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

---

## 6. STATE-GATE / DEAD-FILL SWEEP — 2026-08-31, prompted by the MD_METERS v2.4 fix

**Rob: "sweep the other providers for that same state gate pattern."** Done across all 20 via a new
probe, `tools/_probes/sweep_dead_fill.ps1` (NOT wired into any orchestrator — see the recommendation
at the end). It reuses `tools/_sim_helpers.ps1 Get-FiringKeyRef`, i.e. the same first-match walk the
platform performs, and emits `[NO-VERDICT]` rather than a clean-looking zero when it compares nothing.

**Why a sweep was warranted rather than trusting the boards: MD_METERS v2.3 was PHASE-1 GREEN while
carrying its defect.** No existing gate asks *"does a legal-looking fill send nothing?"* —
`audit_combo_reachability` asks whether a combo can ever win, `audit_devdoc_combinations` whether a
devdoc path is built, `audit_query_trace` whether a metadata variant is unbuilt. A fill that satisfies
one combo and one extra field is outside all three.

**VALIDATED BOTH DIRECTIONS BEFORE BELIEVING IT** (the MD v2.3 JSON recovered from git into the
provider dir, so `source/` sat beside it): FLAGS `ZLDR.O set[OLN] + raceCode -> NOTHING FIRES` on
v2.3 — the exact defect found by hand — and both DL findings are GONE on v2.4.

**RESULT: 20 examined / 380 combos / 746 simulated fills / 48 raw rows / 30 distinct combos.**
Three distinct shapes, and only the first is the pattern Rob asked about:

### 6a. Shape A — the LITERAL TN_TIES `KQ.N` pattern. **4 hits, ALL ALREADY ADJUDICATED. ZERO NEW.**
State is mandatory in `set[]` (or the combo is gated `State EXISTS`), so the *in-state* version of
that search is impossible. `CA_CLETS` / `CA_CONTRA_COSTA` / `CA_VENTURA_COUNTY` `NLTS.BQ.N`, and
`FL_FCIC` `KQOperatorLicenseNumber`. Every one is recorded, verified at TRANSACTION granularity:
the CLETS-family rows say *"there is no in-state boat-by-name transaction to fall through to"* and
name the `CAIBoatRegistrationQuery` sibling trap; FL's DH is deliberately OOS-only (*"DH is OOS-only
so State is a mandatory"*, BUILD_NOTES 464). **Nothing owed. Do not re-raise.**

### 6b. Shape B — the MIRROR. **18 combos / 11 providers. THE REAL RESIDUE, and it is UNGATED.**
An in-state-only combo gated `RegistrationState NOT_EXISTS` with no out-of-state sibling to catch the
fill: the officer types a State and **nothing is sent at all**. This is the class MD v2.4 just fixed —
and MD's fix only worked because `ZLDR.N` existed to receive the State-bearing fill.
`CA_CLETS_OCATS` L1.N · `CA_SAN_LUIS_OBISPO` B2.N · `CA_VENTURA_COUNTY` IN.B2 · `CA_eSUN` L1.N,
L1.N.DH, QW.N, QV.P · `FL_FCIC` FBQDecalNumber, FBQTitleLienInformation, FRQDecalNumber ·
**`MD_METERS` ZVEH.P** · `NM_NMLETS_OFML` QV.V · `NY_NYSPIN_EJUSTICE` RVEH · `OH_LEADS` DN, QWA, RV ·
`TN_TIES` DQ05, DQ06.

**TRIAGE STATUS: ONE of 18 checked to spec, and it came back DEFENSIBLE.** `OH_LEADS` `DN`
(name-only, gated `State NOT_EXISTS`): `audit_query_trace` reports DL 6/7 built with the only MISSING
being the recorded `BMVIMS{SocialSecurityNumber}` — so OH's metadata defines **no** out-of-state
DL-by-name transaction, and "nothing fires" is spec-correct rather than a missing combination.
**The other 17 are UNVERIFIED CANDIDATES, not findings.** The discriminator is per combo and is the
one from `usx-build` Step 3: *does the metadata define an out-of-state variant of this search?*
YES → a missing combination (severity 2). NO → spec-correct, but a silent no-op the officer cannot
distinguish from a broken form, which is a FORM problem (card-title/label), not a wire problem.
⚠️ **There is a genuine design tension here and neither horn is free:** gate the in-state combo and a
State-bearing fill sends NOTHING; leave it ungated and the same fill fires in-state with the **State
silently discarded** — which is precisely the MD v2.3 defect. The only clean answer is that the
out-of-state combo must exist, or the path must not offer a State control.

### 6c. Shape C — an extra NON-STATE identifier kills the fill. **8 combos / 6 providers.**
`CA_eSUN` RQ.V · `HI_HCJDC_OFML` M55L · `NY_NYSPIN_EJUSTICE` RVIN · `OH_LEADS` QA.N · `TX_TLETS` and
`TX_TLETS_CCH` RQ/VIN VehicleIdentificationNumber (2 each). Shape: an identifier-priority guardrail
(`Plate>VIN`, `Hull>Reg`, …) gates the lower-priority combo `HigherPriorityField NOT_EXISTS`, and the
higher-priority combo needs MORE fields than were filled — so the officer with a VIN *and* a plate
gets nothing, while the VIN alone would have worked.
**TRIAGE: spec-consistent on the one measured.** On `TX_TLETS`, **plate-only ALSO fires nothing** —
every TX plate variant mandates `LicensePlateYear` plus `LicensePlateTypeCode`/`financialResponsibility
Type`/`State`, so a bare plate is not a legal request there either. The guardrail is not creating the
hole; the metadata's mandatory plate qualifiers are. Not a wire defect. Same UX-cliff character as 6b.

### 6d. WHAT I RECOMMEND, and what I did NOT do
**Did NOT touch any of the 11 providers** — one-provider-at-a-time, and 17 of the 18 need a
per-combo metadata adjudication that is Rob's call where an OOS variant turns out to exist.
**Did NOT wire the probe into `enforce`/`doctor`** — it would light up 15 of 20 at once, which is the
back-door mass rebuild `audit_layout_flow` was deliberately held out of the blocking pipeline to
avoid. It sits in `tools/_probes/` so it is re-runnable and does not masquerade as a gate.
**Worth promoting to a real gate once the residue is adjudicated**, because the class is currently
invisible to every board: 30 combos across 15 providers, 8 of them tenant-verified ALL-PASS.

**MY PROBE WAS WRONG FIVE TIMES BEFORE IT SAID ANYTHING TRUE, and every failure looked like a
provider defect:** the emitted QIDM type is `QUERYINPUTDATAMAPPING` not `...DATAMAP` (→ "combos: 0");
`Get-FiringKeyRef` is POSITIONAL `($entQidms,$formData)` and my named `-Qidm/-Filled` bound nothing
(→ all 8 MD fills read "NOTHING FIRES" on a JSON that routes all 8); `Test-Path "$_\scripts"` yielded
zero providers (→ `[NO-VERDICT]`, which is the only reason it did not print a clean PASS);
`Get-ProviderRootJson` needs **both** `-ProvDir` and `-Provider`; and the metadata XML has a **default
namespace**, so unprefixed XPath returned nothing and briefly looked like "OH defines no DL variants".
A sixth was in my own classification: a `grep -v` on `+RegistrationState` silently dropped two Shape-C
rows because the string also occurs inside `set[...]`. **Count on the added field, not the whole line.**

### 6e. SHAPE-B ADJUDICATED PER PROVIDER — 2026-08-31. **18 of 18 SPEC-CORRECT. ZERO WIRE DEFECTS.**

Rob: *"adjudicate Shape B per provider (17 metadata checks, most cheap)."* Done for all 18 (the
count in 6b said 17 + MD; it is 18 items), mechanically, against each provider's **own** raw metadata.
Probe kept at `tools/_probes/adjudicate_state_gate.ps1`. It reuses `_metadata_parse.ps1` for the hard
part (Choice / nested-`<Set>` resolution into alternative required-sets) and adds only the per-variant
`<Any>` read, which that module does not expose.

**THE TEST, and it is the one from `usx-build` Step 3 — does the FIRING transaction's own metadata
define an out-of-state variant our fill should have reached?**
- **T1** a variant REQUIRES `State` in `<Set>` **and our fill satisfies it** → REAL, missing combination.
- **T2** **our own variant** — same keyRef **and** same `primaryFieldReference` — permits `State` in
  `<Any>` → REAL, the gate refuses a fill the variant allows (TN_TIES `KQ.N` inverted).
- **T3b** an OOS-capable variant exists but our fill lacks its **other mandatory** fields →
  SPEC-CORRECT; nothing fires because the officer has not supplied the OOS path.
- **T3a** no variant requires or permits `State` at all → SPEC-CORRECT, no OOS path exists.

**VERDICT: all 18 land on T3b.** Every one names the variant and the missing fields, e.g.
`MD_METERS ZVEH.P → ZLRG{LicensePlateNumber} needs also: LicensePlateTypeCode, LicensePlateYear` ·
`TN_TIES DQ05 → KQ{OperatorLicenseNumber} needs also: Attention, PurposeCode` ·
`OH_LEADS DN → DQ{Name} needs also: SexCode, BirthDate` ·
`CA_eSUN QV.P → RQ{LicensePlateNumber} needs also: LicensePlateTypeCode, LicensePlateYear`.

**SO SHAPE B IS NOT A DEFECT CLASS. Combined with 6c, the sweep's honest yield is ZERO wire defects
across all 30 combos** — the residue is a single **FORM/UX** class: an officer who types a State on an
in-state-only path gets silence, because the out-of-state transaction mandates qualifiers they have not
filled. The cure is the form saying so (card-title / required-field affordance), which belongs to
`usx-cosmetic` at each provider's own turn. It is **not** a wire change and **not** a version bump.

**VALIDATED THREE WAYS, because a probe that can only ever say SPEC-CORRECT proves nothing (LAW 2):**
1. **Independent hand agreement** — my by-hand read of MD's Vehicle metadata (done before this probe
   existed) said `ZLRG{plate}` needs type+year. The probe says exactly that, unprompted.
2. **Cross-tool agreement** — `audit_query_trace` on OH_LEADS reports DL 6/7 built with the only
   MISSING being the recorded `BMVIMS{SocialSecurityNumber}`, i.e. `DQ{Name}` IS built. The probe
   independently concludes the OOS name path exists and needs Sex+DOB. Consistent.
3. **NEGATIVE CONTROL — T2 fires on a known real defect.** Aimed at `MD_METERS` **v2.2** (recovered
   from commit `22dc100c` into the provider dir, then deleted), whose `ZLRG.P` was gated
   `RegistrationState EXISTS` while `ZLRG{LicensePlateNumber}` permits `State` in `<Any>`: verdict
   `REAL-T2 gate refuses a State its own variant permits`. That is precisely the defect v2.3 fixed,
   so the REAL verdicts are reachable and the 18 SPEC-CORRECTs are load-bearing.

**MY FIRST RUN OF THIS ADJUDICATOR WAS WRONG TWICE AND REPORTED A FALSE DEFECT.** It returned
`17 SPEC-CORRECT + 1 REAL-T2 on NM_NMLETS_OFML QV.V` — and a uniform 17-of-18 across 11 providers is
the shape that means *your probe is broken*, so I looked rather than reporting it:
- **T2 matched on keyRef ALONE**, pairing NM's **VIN** combo `QV.V` against metadata
  `QV{LicensePlateNumber}`, the **plate** variant. **A keyRef is not a variant** — the single
  most-repeated bug in this toolchain, committed here by me while the rule sat in two skills I had
  already read. Narrowing by `primaryFieldReference` removed the finding entirely.
- **The SPEC-CORRECT evidence line asserted "no variant of X requires State"** unconditionally, which
  is FALSE wherever an OOS variant exists but simply is not satisfied (TN's `KQ.O` requires State *and*
  a PurposeCode). A verdict can be right while its stated reason is wrong, and the wrong reason is what
  outlives the author — hence T3b, which names the variant and the shortfall instead.
- Also, and worth stating because it touched a provider directory: recovering v2.2 I ran
  `git show <commit>:<path>` against the commit that **deleted** the file, and `2>/dev/null` turned the
  failure into an **empty `MD_METERS_v2.2.json` in the provider root** — a one-JSON-in-root violation
  that would have failed `enforce`. Caught and removed in the same action. Use the commit where the file
  **existed**, and never let `2>/dev/null` swallow a `git show` that writes a file.

---

## 7. AUDIT OF THE 13 "DONE" PROVIDERS vs ENGINEERING_STANDARD §5 — 2026-08-31

Rob: *"recheck all 13 'done' providers for accuracy and consistency ... double check the engineering
standard and see how it looks."* Every number below is from a tool run today, not from this file.

### 7a. WHAT IS ACTUALLY CLEAN ON ALL 13 — the majority, and worth stating so the findings read in scale
POSTED marker names the current version **13/13** · registry currency **0 stale** (263 rows, 70
checkable) · BUILD_NOTES fidelity **0 generic** · suppression scope **0 over-broad** · tool portability
**280 cells, 0 unportable** · PS-5.1 parse **118/0** · artifact provenance **F 0 / U 0 / O 0** ·
variant sync, iterate-phase gate, hypothesis quarantine, log-content integrity all PASS. The **21
stale reports** exist but every one is on a NEVER-TESTED provider (CA_VENTURA 7, LA_LEMS 7,
TX_TLETS_CCH 7) — **none on the 13**. Portfolio enforce: **689 PASS / 4 FAIL / 3 WARN**.

### 7b. ⛔ FOUR OF THE 13 FAIL THEIR OWN `enforce` GATE — so §5 bullet 1 holds on NINE, not thirteen
`FL_FCIC`, `HI_HCJDC_OFML`, `IL_LEADS_OFML`, `NJ_NJCJIS`. Verified directly:
`enforce -Provider FL_FCIC` → **BLOCKED: 45 PASS / 1 FAIL**. All four are blocked by the same
`[FLAG:plan-dedupe-vacuous-tests]` in `PENDING_UPDATES.txt`, and **that flag contradicts itself**:

> *"NOT DONE FOR YOU ON PURPOSE: if you are tenant-verified, regenerating now makes your existing logs
> ORPHAN … and drops you out of ALL-PASS, which is why this is a flag and not a sweep."*

…while the mechanism it rides on emits `PENDING_UPDATES.txt has unresolved items (**rebuild before
testing**)` and blocks enforce PHASE 1. So the flag instructs deferral and simultaneously blocks the
gate that defines "done", on providers that are **already tested and passed**. It is a deadlock, not a
backlog: nothing these four can do clears it except the rebuild the flag tells them not to do.
**This is also the mechanical reason the mission metric and §5 disagree** — `report_mission_status`
stage 1 reads `VALIDATOR_REPORT` (0F/0W, true on all 13) and never consults `enforce`.
**ROB'S CALL, three options, I did not pick one:** (i) scope enforce PHASE 1 so a flag does not block a
provider already ALL-PASS at its current version; (ii) comment the flag out with the deferral reason —
the convention these very files already use ("Lines without a leading `#` block enforce"), and what
HI/IL/NJ each did for the earlier `ncic-image` flag — **but that makes `audit_reverse_propagation` read
it as resolved when it is not**, so it needs a REVERSE_PROPAGATION_LOG row saying "deliberately
deferred"; (iii) accept that the honest count is 9 and let the metric say so.
I did **not** clear four providers' flags: that is a 4-provider write against one-provider-at-a-time,
and it changes what the repo tracks as owed.

### 7c. §5 BULLET 7 IS UNMET ON 13 OF 13 — no provider has a form review at its current version
6 have **no record at all** (AZ, MD, NM, OH, OR, TN); the other 7 are **behind**: FL reviewed at v7.12
vs v7.24 · TX v4.12 vs v4.22 · NY v4.16 vs v4.26 · HI v4.14 vs v4.20 · NJ v4.14 vs v4.17 · CA_CLETS
v2.22 vs v2.27 · IL v2.7 vs v2.8. **This is NOT a defect to fix by writing records** — CLAUDE.md is
explicit that the review is a human act, advisory on purpose, must not be manufacturable to satisfy a
gate, and must never be prompted for. So §5 bullet 7 can never pass mechanically, which means **as
written, §5 says ZERO providers are finished.** Either the bullet is qualified or the metric is.

### 7d. `MD_METERS` IS THE SOLE `PROVISIONAL` DEVDOC EXTRACT AMONG THE 13
The other 12 read `CONFIRMED`. MD's `SUPPORTED_QUERIES.txt` is derived FROM the JSON combos, so its
query list is confirmed against the build and not against the devdoc's Basic list — circular authority,
the exact condition closed on NM / OR_LEDS / TN_TIES on 2026-08-31. Its own ledger row already flags it
as owed. Docs-only, no bump, no re-sweep.

### 7e. `DEX_TICKET_ARCHIVE.md` MISSING ON `MD_METERS` AND `OR_LEDS` (11/13 have it)
The **only** unexplained divergence from `audit_provider_uniformity` (13 providers x 66 tokens, 5 areas
clean, 7 explained). **The reason it was deferred has expired:** it was left because Jira was held and
creating OR's alone could not clear the FAIL while MD was the other half. Both have now posted
(OR 807713 on 2026-08-28, MD 808820 today), so it is cheap and actionable.

### 7f. THE STANDARD ITSELF — two problems, and they are the reason 7b/7c were invisible
1. **§5 and §5.1 do not measure the same thing.** §5 lists **seven** conditions for "finished"; §5.1
   defines the portfolio metric as "all **6 stages** of §2 green" and `report_mission_status` implements
   §5.1. Bullets 5 (per-provider gate efficacy) and 7 (form review) sit **outside** the metric that is
   supposed to represent §5 — so a provider can be LIFECYCLE-COMPLETE while failing "finished". Today:
   metric **13**, §5 bullet 1 **9**, §5 bullet 7 **0**.
2. **§6.1 IS STALE.** It states mutation coverage is *"1 provider deep — `audit_gate_efficacy` proves 15
   defect classes on TX_TLETS only"*. The catalogue now names **five** providers (TX 13 refs, NJ 9, FL 7,
   NY 3, AZ 2) **plus a provider-agnostic subset**: `MD_METERS` appears in none of those maps and scored
   **8/8 killed, 0 survived** in today's `build_phase1`. The claim understates real coverage, which
   matters because §5 bullet 5 is judged against it.

### 7g. PROCESS NOTE ON THIS AUDIT
`audit_provider_linkage` FAILs on 12 providers (68 cross-provider comment references). Deliberately NOT
counted as a finding here: it is ADVISORY by design, comment provenance has no wire impact, and
CLAUDE.md says it is cleaned at each provider's own rebuild and is never a blocking flag.
Also: my `enforce -Provider FL_FCIC | grep ... ; echo $?` printed `0` because `$?` captured **grep's**
exit status, not enforce's. The `BLOCKED: 45 PASS / 1 FAIL` line is the evidence; the exit code I
printed was meaningless. Third time this session a pipeline exit status has misled me — `grep | head`
did it twice earlier. **Read the tool's own verdict line, never the pipeline's status.**
