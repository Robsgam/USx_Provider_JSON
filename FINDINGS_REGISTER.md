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

## 1. BUILD ORDER — Rob's queue, 2026-08-20

Ordered by Rob. Work strictly top-down, one provider at a time, minimal drift.

| # | Provider | Build work | Status |
|---|---|---|---|
| 1 | **OH_LEADS** v2.10 | `any[]` pool fix on 4 name combos (`DQ.N`, `QWA`, `DN`, `KQ.N`) | **NEXT** |
| 2 | **NM_NMLETS_OFML** v2.4 | `any[]` pool fix on its 2 name combos | queued |
| 3 | **LA_LEMS** v3.1 | collapse 12→6 cards; add name controls + compose + pool | queued |
| 4 | **CA_eSUN** v2.3 | collapse 16→6; name controls; `[FLAG:plan-fillability-unfireable-tests]` (26 UNSAT) | queued |
| 5 | **MD_METERS** v2.1 | collapse 13→6; name controls | queued |
| 6 | **TN_TIES** v2.2 | collapse 14→6; name controls; **+ the class-J wiring break on `RQ05`** | queued |
| 7 | **OR_LEDS** v2.4 | collapse 11→6 — **LAYOUT ONLY**, its name components are already pooled | queued |
| 8 | **CA_VENTURA_COUNTY** v2.4 | collapse 20→6 (worst in portfolio); name controls | queued |
| 9 | **CA_SAN_LUIS_OBISPO** v2.4 | collapse 13→6; name controls | queued |
| 10 | **CA_CLETS_OCATS** v2.6 | collapse 16→6; name controls | queued |
| 11 | **CA_CONTRA_COSTA** v2.3 | collapse 7→6; name controls | ⛔ **PARKED — awaiting Rob's ruling** on whether JAWS / SuperQuery / RequestingAgencyId is in scope |

**Not in the build queue, tracked separately:**

| Provider | State | Owed |
|---|---|---|
| ~~**NJ_NJCJIS** v4.17~~ | ✅ **LIFECYCLE-COMPLETE 2026-08-20** | Nothing owed. 41/41 ALL-PASS, four log gates 41/41, DEX-988 comment **802981**, catalog + ticket + Newark Foundation all on v4.17. **Middle name and suffix wire-proven** (`DOE, JOHN A` / `DOE, JOHN JR` vs a `DOE, JOHN` control) — the first time in this provider's history |
| **NY_NYSPIN_EJUSTICE** v4.24 | build spec'd, not built | **REBUILD + RETEST** — 2 `MI` labels + DH rows 3&4 merged (§4). Its name components are already wire-proven |
| **TX_TLETS_CCH** v1.17 | fully wired | **DRIVE ONLY** — 14 pooled combos, 24 planned tests, 0 logs. Never imported. Lockstep with TX_TLETS |
| AZ, CA_CLETS, FL, HI, IL, TX | clean | nothing |

---

## 2. NAME COMPONENTS — status across all 20

`POOLED` = combos whose `set[]`/`any[]` carries a middle/suffix control · `PLAN_af` = auto-generated
`_af_` tests · `LOGS_af` = committed logs proving it on the wire.

**The chain is self-closing:** put the components in `any[]` → `emit_test_plan` generates one test per
`any[]` field → the sweep proves the wire. Nothing hand-written. AZ is the reference:
`DQN` → `DOE, JOHN` · `DQN_af_nameMiddle` → `DOE, JOHN A` · `DQN_af_nameSuffix` → `DOE, JOHN JR`.

```
PROVIDER               POOLED   PLAN_af   LOGS_af   STATUS
AZ_AZDPS               4        8         8         COVERED -- nothing owed
CA_CLETS               8        16        16        COVERED -- nothing owed
CA_CLETS_OCATS         0        0         0         NO CONTROLS -- needs controls + pool
CA_CONTRA_COSTA        0        0         0         NO CONTROLS -- needs controls + pool
CA_eSUN                0        0         0         NO CONTROLS -- needs controls + pool
CA_SAN_LUIS_OBISPO     0        0         0         NO CONTROLS -- needs controls + pool
CA_VENTURA_COUNTY      0        0         0         NO CONTROLS -- needs controls + pool
FL_FCIC                4        8         8         COVERED -- nothing owed
HI_HCJDC_OFML          2        4         4         COVERED -- nothing owed
IL_LEADS_OFML          1        2         2         COVERED -- nothing owed
LA_LEMS                0        0         0         NO CONTROLS -- needs controls + pool
MD_METERS              0        0         0         NO CONTROLS -- needs controls + pool
NJ_NJCJIS              1        0         0         pooled but UNPROVEN
NM_NMLETS_OFML         0        0         0         NEEDS THE any[] FIX
NY_NYSPIN_EJUSTICE     3        6         6         COVERED -- nothing owed
OH_LEADS               0        0         0         NEEDS THE any[] FIX
OR_LEDS                1        2         0         pooled but UNPROVEN
TN_TIES                0        0         0         NO CONTROLS -- needs controls + pool
TX_TLETS               3        6         6         COVERED -- nothing owed
TX_TLETS_CCH           14       24        0         pooled but UNPROVEN
```

**7 COVERED · 2 need the `any[]` fix · 3 pooled but never swept · 8 need controls built.**

Read the four states as different work, not one number:
- **NO CONTROLS** — the officer cannot type it. Needs control + composite + `any[]`, in the same pass
  as that provider's card collapse. These 8 are the 48 C1 findings seen from the other side.
- **NEEDS THE any[] FIX** — controls exist, labelled correctly, composed into `Name`, and **in no
  combination pool, so the value is silently dropped.** Worse than a missing field: the form looks
  complete. OH's own wire says `<Name>DOE, JOHN</Name>` on all 56 logs.
- **pooled but UNPROVEN** — build is right, no logs yet. Needs DRIVING, not building.
- **COVERED** — components pooled, plan tests generated, wire proven. Nothing owed.

⚠️ **`set[]` would be WRONG.** Components go in `any[]` — they are optional qualifiers. In `set[]` a
middle name becomes MANDATORY and any driver without one cannot be searched. Confirmed by
`audit_requirement_fidelity` on NJ: 10 branches / 0 UNDER-REQUIRED / 0 OVER-PERMITTED.

---

## 3. NJ_NJCJIS — plan regeneration, before its sweep

NJ reads `POOLED 1 / PLAN_af 0 / LOGS_af 0`. The pool is correct; the **plan is stale** because
`reset_test_package` ran BEFORE the `any[]` entries were added, so it generated no `_af_` name tests.
**Regenerate the plan before driving**, or the sweep will pass 40/40 and prove nothing about the fix
that motivated the version. Found by measuring the table above, not by any gate.

---
## 4. NY WORK ORDER — for the bulk rebuild. NOT YET BUILT.

**DO change — the real finding (Rob confirmed by eye: *"oh i see midddle name not middle iniital"*):**

| Where | From | To |
|---|---|---|
| `build_ny_nyspin_ejustice.ps1:690` `nameMiddle` (DL card) | `'MI'` | `'Middle Name'` |
| `build_ny_nyspin_ejustice.ps1:713` `nameMiddleDH` (DH card) | `'MI'` | `'Middle Name'` |

Both fields are `maxLength=35` — full middle names, not initials. NY's components ARE in the combo
pool (0 C1 / 0 C3), so the data path works; the label is the only thing making officers under-fill it.
TX_TLETS fixed the identical mislabel at v4.21. Add `# LABEL-OVERRIDE:` tags per AZ's precedent.

**Cosmetic, dictated by Rob 2026-08-20 — Person DH card, merge the last visible row into the third.**
Rob, clarifying: *"for ny last row is the foruth row that is visibile  purpose code and transaction
type need to be with dob and sex on the same line"*. RESOLVED — no ambiguity left, build exactly this:

```
BEFORE                                                    AFTER
DH_1  [6,3,3]    OLN | State | Image                      DH_1  [6,3,3]    OLN | State | Image
DH_2  [4,4,2,2]  First | Last | Middle | Suffix           DH_2  [4,4,2,2]  First | Last | Middle | Suffix
DH_3  [6,6]      BirthDate | SexCode                      DH_3  [3,3,3,3]  BirthDate | SexCode |
DH_4  [6,6]      purposeCode | nyNyspinTransactionName                     purposeCode | nyNyspinTransactionName
DH_5B [12]       requestor   (FIELD-HIDDEN)               DH_4  -- REMOVED, absorbed into DH_3
                                                          DH_5B [12]       requestor   (FIELD-HIDDEN, stays last)
```
Result: **3 visible rows + the hidden feeder**, and rows 1-3 then match the DL card's shape.

⚠️ **MY FIRST READING OF THIS WAS WRONG AND THE REASON IS A DOCUMENTED TRAP.** I reported the DH card
as having FIVE visible rows and offered Rob two guesses, because my probe tested `$row.hidden` only.
`requestorDH` is hidden at the **FIELD/NODE** level, not the row level — so the card really does show
FOUR rows, exactly as Rob said. `usx-cosmetic` Step 3 records this precise trap ("`hidden` is a
NODE-level property, NOT `props.hidden`"; it produced nine false findings on its first run) and
`verify_build` CHECK 6 has always read it correctly. **When counting what an officer sees, a row is
invisible if the row is hidden OR every field in it is hidden.**

**DO NOT change — verified deliberate, and I nearly "fixed" it:**
`ROW_VEH_3 [4,4]` and `ROW_ART_2 [4,4]` are flagged L6 ROW-NOT-12 (4 columns of dead space). They are
an **accepted decision from Rob's own v4.13 feedback**, recorded in the build script header AND
BUILD_NOTES lines 263-264: *"ROW_VEH_3 6/6 -> 4/4 (State 6 -> 4; a 2-char code no longer sits in a
half-row box; State/Image align under the columns above)"*. Leave both. This is why usx-build 6c says
to read the provider's own notes for the field you are about to change — the cheapest authority in the
repo, and it stopped a wrong edit here.

**Cost:** v4.24 → v4.25, archives **75 logs**, owes a 75-test sweep. Wire provably unchanged (prove it
the OH v2.10 way, not with per-entity fingerprints).

---

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

## B. NEVER-TESTED — fixing costs Rob nothing. Do these without asking.

| Provider | Ver | Cards → target | Layout | C1 | Other |
|---|---|---|---|---|---|
| **CA_VENTURA_COUNTY** | v2.4 | 20 → 6 | 11 (L4,L5,L6) | **10** | |
| **CA_eSUN** | v2.3 | 16 → 6 | 11 (L4,L5,L6) | **8** | `[FLAG:plan-fillability-unfireable-tests]` — 26 UNSAT plan tests |
| **CA_CLETS_OCATS** | v2.6 | 16 → 6 | 12 (L4,L5,L6) | 4 | |
| **CA_CONTRA_COSTA** | v2.3 | 7 → 6 | 6 (L2,L4,L6) | **10** | builds no JAWS/SuperQuery despite the recorded recipe — scope question for Rob |
| **TN_TIES** | v2.2 | 14 → 6 | 5 (L4,L5) | 4 | **+ wiring class J: `RQ05` is gated `EXISTS RegistrationState` but the field is in neither its `set[]` nor `any[]` — the officer's value routes and is then NOT transmitted.** Only wiring break in the portfolio |
| **MD_METERS** | v2.1 | 13 → 6 | 5 (L4,L5) | 4 | |
| **CA_SAN_LUIS_OBISPO** | v2.4 | 13 → 6 | 5 (L4,L5) | 4 | |
| **LA_LEMS** | v3.1 | 12 → 6 | 5 (L4,L5) | 4 | Lafayette runs a hand-built LA_LEMS that is NOT ours |
| **OR_LEDS** | v2.4 | 11 → 6 | 7 (L4,L5,L9) | 0 | layout only |
| **TX_TLETS_CCH** | v1.17 | 9 → **9 (correct)** | 2 (L2,L4) | 0 | 6 base + 3 CCH cards is by design — its L4 is **not** a collapse gap. `[FLAG:nameparts-untested-unfrozen]`. Must stay in lockstep with TX_TLETS (`# BASE-SYNC`) |
| **NM_NMLETS_OFML** | v2.4 | 6 → 6 ✔ | 1 (L9, **recorded override**) | 0 | **C3 ×4 — needs the `any[]` pool fix** (see the C3 note) |

---

## C. PORTFOLIO / PROCESS — not provider-specific

| Item | Detail | Status |
|---|---|---|
| eSUN export in git history | A 228KB tenant department export was committed+pushed by the capture watcher's broad `git add -- providers` (fixed). Untracked again, but **the blob remains in pushed history at `8273a87f`** — removing it needs a history rewrite + force-push | **Rob's call** |
| Newark Foundation behind | v4.16 vs repo v4.17. Customer tenant | **Rob's call** |
| HDLE held at v4.15 | Deliberate. HI production discards NCIC hit content until the hit block is verified | HELD by decision |
| HI hit block | Config-present, never exercised against a live hit response | Needs 1 hit query in HI's own tenant |
| 12 C3 → 0 | NJ done; OH 6 and NM 4 remain | OPEN |
| Officer guides | Content-poor, not stale. Rewrite requested, shape not agreed | OPEN |
| ~30 clone groups | `audit_log_inflation` class A. Duplicate/vacuous guardrail tests; class B/C/D all 0 | Clears at each provider's own rebuild |
| `audit_name_components` not blocking | Advisory (PHASE 2x) because 48 C1 across 7 providers would redden them all at once | Make BLOCKING when residue is 0 |
| `audit_layout_flow` not blocking | Advisory (PHASE 2w), same reason | Make BLOCKING when residue is recorded overrides only |

---

## D. MY OWN RECURRING ERRORS — read before trusting a number in here

- **A finding on every provider is my probe, not the portfolio.** Four hand-written regexes misled me
  on 2026-08-20 alone: one said CA_CLETS `purposeCode` was **not** prefilled (it is, on all 5
  entities) and would have had me "fix" a non-defect on a 111-log provider. **Read parsed JSON, not
  pattern-matched text.**
- **PowerShell `-match` is CASE-INSENSITIVE** — summary lines like `C1 no-control 50` matched an
  uppercase `C1 NO-CONTROL` pattern and inflated a per-provider count, inventing a finding on
  TX_TLETS_CCH that does not exist.
- **A line-number `sed` is invalid the moment the file changes length** — bumping `$Version` that way
  left NJ/NM with TWO assignments; the second wins, so the build silently produced the OLD version
  while reporting success.
- **Read a gate's verdict BEFORE committing, not after.** Done twice; the second time the commit body
  asserted "4 PASS / 124 lines" while the gate said 2 FAIL / 134 lines.

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
