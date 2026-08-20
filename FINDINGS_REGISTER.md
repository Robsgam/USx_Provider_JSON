# FINDINGS REGISTER — open defects per provider

> Created 2026-08-20 at Rob's direction: *"log everything you found as to be fixed so we dont lose it
> and lets start teacking them all."*
>
> **Why this file exists.** Every finding below came from a gate that already existed and that
> **nothing ran automatically**. `audit_layout_flow` (built 08-11) and `audit_name_components`
> (built 08-17) were wired into no orchestrator, so their findings only surfaced when a human typed
> the tool name. That is how NJ_NJCJIS — *named in writing* in CLAUDE.md on 08-17 as carrying the
> name-component gap — sat at `0 FAIL / 0 WARN` through a full portfolio sweep and two further days
> of runs. Both gates are now wired (`enforce` PHASE 2w and 2x, advisory). **This file is the
> backstop for the same failure: a finding written here cannot be lost by nobody thinking to ask.**
>
> **Rules for this file.** One row per finding. Never delete a row — move it to DONE with the version
> that fixed it. `REAL?` is the load-bearing column: a finding that is prefilled, adjudicated or
> cosmetic is *not* a defect, and treating it as one costs a re-sweep for nothing.
> Re-derive counts with `audit_layout_flow -All`, `audit_name_components -All`,
> `audit_wiring_closure -All`. Never from memory.

## The rule that decides priority

| State | Meaning | Cost of fixing |
|---|---|---|
| **tenant-verified** | has passing logs from a sweep Rob sat through | changing it archives those logs → **Rob must re-drive the whole sweep** |
| **never-tested** | no logs at all | **nothing** — no package to lose, no re-sweep |

Rob 2026-08-20: **FL, TX, NJ, NY, CA_CLETS, IL, HI are all high priority** — i.e. the tenant-verified
set is to be fixed despite the re-sweep cost, not deferred because of it. Re-test cost is explicitly
**not** grounds to defer (Rob 2026-08-11).

---

## THE DISCOVERY THAT CHANGES SEVERAL ROWS BELOW — read before working any C3

`audit_name_components` grades three classes. C1 NO-CONTROL (the officer cannot enter it) and C2
NOT-COMPOSED block; **C3 NOT-IN-POOL is labelled "[NOTE] impact UNPROVEN"** — composed into the Name
attribute but present in no combination's `set[]`/`any[]`.

**C3 is NOT benign, and it is no longer unproven.** Found 2026-08-20 on NJ: adding the middle/suffix
controls and composing them into `Name` moved the finding C1 → C3, which reads like success. It is
not. **AZ_AZDPS — the only provider with a wire-PROVEN `DOE, JOHN A JR` — carries
`nameMiddle`/`nameSuffix` in the `any[]` of EVERY name combo** (`ACWL`, `DQPN`, `DQN`, and `KQH` on
the DH side). Pool membership is what puts a component on the wire. Without it the officer types a
middle name and **it is silently dropped**.

So: **a C3 row is a half-finished C1 fix.** Add the components to the name combo's `any[]` (never
`set[]` — they are optional qualifiers), and never to an OLN-path combo where name plays no part.

---

## TRIAGE — what each provider needs. **NOTES ONLY; DO NOT BUILD.**

Rob 2026-08-20: *"do not build just make the notes and we will bulk rebuild all providre that we flag
it and let it run later. we want to triage them all. right now nj is retest only and ny should be
rebuild and retest"*

**One item at a time, minimal drift.** Nothing in section A or B is to be built until the bulk pass is
authorised. This table is the queue for that pass.

| Provider | ACTION | Needs Rob? | Why |
|---|---|---|---|
| **NJ_NJCJIS** v4.17 | **RETEST ONLY** | import + sweep | Build is DONE (middle+suffix, composite, AP #15, `FULL.any[]`). 0 C1 / 0 C2 / 0 C3, enforce 46 PASS / 0 FAIL / 0 WARN. Owes: import, 40-test sweep, DEX-988 comment, Newark re-import |
| **NY_NYSPIN_EJUSTICE** v4.24 | **REBUILD + RETEST** | no — fully specified | 2 label fixes + DH rows 3&4 merged. Work order below is complete and unambiguous |
| **OH_LEADS** v2.10 | REBUILD + RETEST | no | C3 ×6 — the `any[]` pool fix. Officer's middle name is dropped today |
| **NM_NMLETS_OFML** v2.4 | REBUILD + RETEST | no | C3 ×4 — same `any[]` pool fix. Already owes a sweep anyway |
| **TN_TIES** v2.2 | REBUILD | no | Layout collapse 14→6, C1 ×4, **+ the class-J wiring break** |
| **CA_VENTURA_COUNTY** v2.4 | REBUILD | no | 20→6 cards, C1 ×10 |
| **CA_eSUN** v2.3 | REBUILD | no | 16→6 cards, C1 ×8, fillability flag |
| **CA_CLETS_OCATS** v2.6 | REBUILD | no | 16→6 cards, C1 ×4 |
| **CA_CONTRA_COSTA** v2.3 | REBUILD | **YES** | 7→6 cards, C1 ×10 — **and a scope question: builds no JAWS/SuperQuery despite the recorded recipe** |
| **MD_METERS** v2.1 | REBUILD | no | 13→6 cards, C1 ×4 |
| **CA_SAN_LUIS_OBISPO** v2.4 | REBUILD | no | 13→6 cards, C1 ×4 |
| **LA_LEMS** v3.1 | REBUILD | no | 12→6 cards, C1 ×4 |
| **OR_LEDS** v2.4 | REBUILD | no | 11→6 cards, layout only (0 C1) |
| **TX_TLETS_CCH** v1.17 | HOLD | no | Must move in lockstep with TX_TLETS (`# BASE-SYNC`). 9 cards is correct |
| **FL_FCIC** v7.24 | **NOTHING** | no | Its L2 was my false positive. Only a date picker on a wide row remains — cosmetic |
| **CA_CLETS** v2.26 | **NOTHING** | no | Both L2s benign (`purposeCode` prefilled). Clean after the L2 fix |
| **TX_TLETS** v4.21 | **NOTHING** | no | Its L2 is the recorded DEX-1283 override |
| **IL_LEADS_OFML** v2.8 | NOTHING | no | 2 dead-space rows only |
| **HI_HCJDC_OFML** v4.20 | NOTHING | no | 1 wasted-width row only |
| **AZ_AZDPS** v3.11 | NOTHING | no | Clean on all three gates. Reference build |

---

## NY WORK ORDER — for the bulk rebuild. NOT YET BUILT.

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
