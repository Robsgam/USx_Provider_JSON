# ENGINEERING STANDARD — ConnectCIC Provider JSON

**This is the top-level contract for what "done" means.** It is not notes, not a memory file, and
not a KB entry among forty others. It sits at the repo root, it is loaded via CLAUDE.md, and it is
the document a gate is measured against. If a rule matters, it belongs here or in `BUILD_RULES.txt`
— nowhere else.

Established 2026-07-30 (Rob: *"all this knowledge needs to be written in stone… it needs to be
higher level and all gates need to operate from initial build/rebuild all the way to posting the
jira entry and logging where jsons are imported"*).

---

## 1. The three laws

**LAW 1 — THE FORM COMES FIRST.**
Every combination the devdoc supports must be reachable by an officer typing into the rendered form,
with every documented combination of its optional fields. CAD injection, RMS convenience, and demo
behaviour never take precedence over that. A prefill that hides a search path is a defect, not a
default (`BUILD_RULES` 23, 24).

**LAW 2 — A GATE THAT CANNOT FAIL IS NOT A GATE.**
`0 FAIL` is produced identically by a correct config and by a broken check. Therefore every gate
must be **demonstrably capable of failing** on the defect class it owns, proven by mutation
(`tools/audit_gate_efficacy.ps1`). A gate's PASS is evidence **only** for the classes it has killed
a mutant on. Unproven gates are decoration.

**LAW 3 — AUTHORITY IS DIRECTIONAL, AND BOTH DIRECTIONS MUST BE CHECKED.**
Devdoc is **query** authority. Metadata XML is **field** authority. A check that only validates what
EXISTS can never see an omission, so every authority relationship needs a gate in **both**
directions. Every escaped defect in this repo's history is a one-directional check:

| Direction | Gate | What it would otherwise miss |
|---|---|---|
| BUILT → devdoc | `audit_supported_queries` (2e) | nothing — this one always existed |
| devdoc → BUILT (combination level) | `audit_devdoc_combinations` (2p) | a whole devdoc path never built |
| devdoc optionals → routing | `audit_devdoc_optionals` (2q) | an optional silently not transmitted |
| metadata → BUILT | `audit_query_trace` (2n), `audit_metadata` 4d/4e | prefill-dead combos, promote/demote drift |
| BUILT → wire | `audit_log_metadata` (6d), `audit_log_combo_attribution` (2i) | a log filed under a combo that never fired |

---

## 2. The lifecycle, and the gate that owns each stage

Nothing in this pipeline may be carried by memory or habit. Every stage has an owner.

| # | Stage | Owning gate(s) | Blocking? |
|---|---|---|---|
| 1 | **Build / rebuild** | `validate`, `verify_build` (15 checks), `audit_cad`, `lint_build_scripts`, `audit_reproducible` (2f) | YES |
| 2 | **Spec conformance** | `audit_metadata` (2b), `audit_supported_queries` (2e), `audit_devdoc_combinations` (2p), `audit_query_trace` (2n) | YES |
| 3 | **Reachability** | `audit_combo_reachability` (2h), `audit_devdoc_optionals` (2q) | 2h YES / 2q advisory |
| 4 | **Tenant test** | `audit_log_content` (6c), `audit_log_metadata` (6d), `audit_log_combo_attribution` (2i), `report_test_status` plan-completeness | YES |
| 5 | **Jira entry** | `audit_lifecycle` STAGE 5 | advisory (`-Strict` to block) |
| 6 | **Import record** | `audit_lifecycle` STAGE 6 → `providers/IMPORT_LEDGER.md` | advisory (`-Strict` to block) |
| — | **The gates themselves** | `audit_gate_efficacy` (mutation testing) | run per provider on demand |
| — | **Consolidated verdict** | `enforce.ps1` — exit 0 or the work is not done | YES |

Stages 5 and 6 are advisory **by design**: Jira updates get placed on hold, and Foundation-tenant
imports are another party's action on another party's schedule. A gate that blocks a build because
an external party has not acted trains everyone to bypass it. What these gates remove is not the
delay — it is the ability to **lose the fact**.

---

## 3. Defect classes, and how each was found

Written down so they are never re-derived, and so a new gate can be checked against the list.
Every one of these shipped past a green board.

| Class | What it looks like | Found by |
|---|---|---|
| **PREFILL-DEAD** | our own `initialValue` satisfies a field a combo requires, so a sibling always wins first-match and the combo is unreachable | manual trace, then `audit_query_trace` |
| **False dead-combo deletion** | a prefill makes a real path look dead, and it gets DELETED — TX v4.13 removed both devdoc `(OutofState)` vehicle paths this way | post-mortem |
| **Metadata shadow re-added** | a platform-auto-fired shadow (QV, QW) gets "restored" alongside a genuine prefill-dead fix, overturning a standing ruling | Rob, from memory of the v4.9 ruling |
| **Unbuilt devdoc combination** | a devdoc `Possible Combinations` item was never built; invisible because the test plan is generated FROM the JSON | `audit_devdoc_combinations` |
| **Dropped devdoc optional** | officer types a documented optional; no matching combo carries it; it is silently not transmitted and nothing errors | `audit_devdoc_optionals` |
| **Union-pool over-send** | the platform serialises set[]+any[] of ALL co-matching combos, sending fields the fired combo does not own | analytic sweep (0 on TX v4.18) |
| **Duplicate targetField** | two attributes write one field; which lands is undefined. The real cause of the FL sex reverse-lookup failure | `verify_build` CHECK 15 |
| **Poisoned conditions array** | one value-comparison operator disables the ENTIRE conditions array, including co-resident EXISTS | `verify_build` CHECK 9 |
| **keyRef scoping** | keyRefs collide across QIDMs; an unscoped lookup evaluates the wrong entity's data (`BUILD_RULES` 13) | repeatedly — 3× in one day |
| **Inert / vacuous gate** | the check runs, finds nothing, and reports PASS because it never looked. `sync_provider_table` was inert for 20 providers; `audit_metadata` passed with 0 checks when its XML was missing; `audit_repo` Category 11 still compares retired BASE/MC JSONs | `audit_gate_efficacy` |
| **Variant-collapsed verdict** | a check de-duplicates across layout variants, so a broken `default` is masked by an intact `CAD_DISPATCH` | `audit_gate_efficacy` mutation |
| **Non-discriminating test value** | the test value equals the thing it is supposed to distinguish (`messageKey=CPL` vs keyRef `CPL`), so the test proves nothing | wire audit |

---

## 4. Rules for building a gate

Violating these is how the four inert checkers above happened.

1. **Prove it fails.** Add a mutation to `audit_gate_efficacy.ps1` in the same commit as the gate.
   A gate without a killed mutant is not finished.
2. **A mutation must CREATE the defect, not resemble it.** Prefilling `LicensePlateYear` looks like
   a prefill-dead test but starves nothing (it is in both combos' `set[]`). Verify the mutant on
   disk before believing any SURVIVED verdict.
3. **Distinguish "found nothing" from "never looked."** Zero findings with zero checks is a vacuous
   pass and must FAIL. Emit a count of what was examined.
4. **Never re-implement an existing parser.** Five parsers were written wrong in one session by
   re-deriving something that already existed. Reuse `_sim_helpers.ps1` for routing,
   `_resolve_provider_json.ps1` for JSON resolution, `_metadata_keyref_match.ps1` and
   `audit_devdoc_combinations -Explain` for devdoc items.
5. **Scope by keyReference, never by bare name or query-wide union.** `BUILD_RULES` 13.
6. **Show intermediate state.** A parser that cannot print what it parsed is indistinguishable from
   one that is silently wrong. Every gate gets an `-Explain`/verbose path.
7. **PowerShell traps that have each cost real time:** a function returning `@($x)` unwraps to a
   scalar (comma-guard it); `@($null).Count` is 1; `Copy-Item -Recurse` into a surviving directory
   nests it; `-Path` globs match across `/`.
8. **Never hardcode a provider name in a shared tool.** A stale exemption list is a silent hole
   (`audit_repo.ps1` still exempts `TX_TLETS` in a category that no longer checks anything).

---

## 5. What "finished" means for a provider

All of the following, simultaneously, with no exceptions granted by narrative:

- `enforce.ps1 -Provider <NAME>` exits **0**: 0 FAIL / 0 WARN.
- Every metadata combination in devdoc-Basic scope is **built or recorded** in
  `<P>_ACCEPTED_DIVERGENCES.txt` with a reason a stranger can evaluate.
- Every devdoc combination, **and every subset of its optionals**, either routes and transmits or is
  recorded.
- Tenant test package: every combo has a log where it **WINS**, and every log's wire XML carries its
  own discriminator and lacks its sibling's.
- `audit_gate_efficacy -Provider <NAME>`: **0 SURVIVED, 0 INVALID.**
- Stages 5 and 6 recorded — Jira names the version, ledger accounts for the version.
- A human has looked at the rendered form (`audit_form_review`), pre- and post-test.

Anything less is in progress, and must be reported as in progress.

---

## 6. Deferred work, with the data preserved

Recorded so it is not re-derived. Deferred by decision, not forgotten.

### 6.1 Mutation coverage is 1 provider deep (Rob 2026-07-30: "leave #3 alone but save the data")

`audit_gate_efficacy.ps1` proves **15 defect classes** on **TX_TLETS only**. The other 19 providers'
gates are therefore *unproven*, and by LAW 2 their PASS is not yet evidence — the gates are the same
code, but the mutation table is TX-shaped (it names TX keyRefs: `DPSIStickerNumber`, `CPLName`,
`RQVehicleIdentificationNumber`, `QGNCICNumber`, and TX fieldIds `LicensePlateTypeCode`,
`stickerNumber`). Running it elsewhere needs a per-provider mutation map, not a new harness.

The 15 proven classes: prefill-routing-field, dup-targetfield-request, demote-set-to-any,
promote-any-to-set, poisoned-condition, drop-identifier-guardrail, vehiclemake-as-input,
banned-pattern, inert-condition-field, toplevel-version-field, entities-bundle-not-first,
missing-querylabel, drop-devdoc-optional, remove-a-built-combo, true-shadow-pair.

**Two lessons already banked from it, which is why the data is worth keeping even while deferred:**
1. A mutation must CREATE the defect, not resemble it (the LicensePlateYear-vs-LicensePlateTypeCode
   lesson — prefilling a field that both rival combos require starves neither).
2. "Found nothing" and "never looked" must be distinguishable, or a skipped subject reads as a clean
   pass (`audit_metadata` scored 0 PASS / 0 FAIL / exit 0 with its XML missing).

Also known and deferred: **TX_TLETS_CCH has 29 devdoc-optional defects** in its CCH-specific queries
(IQ, QWI — dropped `BirthDate`/`RaceCode`, two NO-FIRE mandatory fills). Its base-6 is identical to
TX and already fixed. Reproduce with
`tools\audit_devdoc_optionals.ps1 -Path providers\TX_TLETS_CCH\TX_TLETS_CCH_v1.14.json`.

### 6.2 TX minimal-plate entry fires NOTHING — open product decision

Verified on v4.18 with the canonical predicate:

| Officer types | What is sent |
|---|---|
| Plate only | **nothing** |
| Plate + Year | **nothing** |
| Plate + State | **nothing** |
| Plate + State + RegionId | **nothing** |
| Plate + Year + PlateType | `RQLicensePlateNumber` (devdoc OutofState #3) |
| Plate + Year + FRT | `REGLicensePlateNumber` (devdoc InState #1) |

**This hole was created by two individually-correct fixes.** Timeline, from the archived logs:
- **≤ v4.13** — minimal plate entry DID fire, because the form prefilled PlateType/Year/FRT and those
  prefills satisfied a combo. But the same prefills killed the OOS combos (the v4.13 deletion).
- **v4.14 – v4.16** — minimal plate entry DID fire, via `QV{Plate}`. 15 archived logs submit a plate
  with neither PlateType nor FRT, all of them `QV*` logs.
- **v4.17+** — QV removed per the binding v4.9 shadow ruling. Nothing catches minimal plate entry.

**Correction to an earlier claim of mine:** I wrote that these fills are "covered by the auto-fired
QV". That is NOT established. The auto-fire model (NJ precedent) is the STATE running QV alongside a
query the client sent. If no combo matches, no query is sent, so there is nothing for QV to attach
to. Treat coverage as UNKNOWN until proven on the wire, not as a mitigation.

Options, for Rob:
- **A. Accept + say so on the form.** Require Plate + Year + (PlateType or FRT). No routing change.
  Mandatory companion: the card must TELL the officer, because silent no-op is the worst outcome.
- **B. Rebuild `QV{Plate}` as a terminal fallback** — ordered LAST, no conditions, so it can only win
  when nothing more specific matches. Materially different from the v4.9 case, where QV was ordered
  so that it STOLE fills from real combos; as a last-resort row it steals nothing. Restores all four
  minimal fills. Cost: 20 combos, narrow reversal of the v4.9 ruling, v4.19 + full re-sweep.
- **C. Escalate to CommSys.** The devdoc lists FinancialResponsibilityType as OPTIONAL on the
  in-state plate query while the metadata REQUIRES it in `set[]` — a direct contradiction, and the
  reason Plate+Year cannot be built at all. Also confirm whether QV auto-fires with no client query.
---

## 7. Duplicated data — the drift engine, and what is allowed to be duplicated

**LAW 4 — DERIVE, DO NOT DUPLICATE.** A fact stored in N places drifts N−1 ways. If a fact can be
computed, it must be GENERATED from one source and never typed twice.

Measured 2026-07-30: **"TX_TLETS is at v4.18" is stored in 14 places**, and `enforce` PHASE 3 spends
**15 assertions** reconciling them. Reconciliation is not the fix — it is the symptom. Every
doc-sync failure in this repo's history is two of these 14 disagreeing.

| Copy | Status |
|---|---|
| build script `$Version` | **THE SOURCE** |
| JSON filename, bundle description, TEST_PLAN filename, `BUILD_MANIFEST`, `.test_version` | generated by the build |
| `STATUS`, `SQVR`, `JSON_INVENTORY`, `BUILD_NOTES`, `REBUILD_TRACKER`, `CHANGELOG_<P>` | generated by `sync_version_docs` |
| CLAUDE.md provider row | generated by `sync_provider_table` |
| `SESSION_STATE.md` | **was hand-typed → now generated** by `sync_session_state` (2026-07-30) |
| `IMPORT_LEDGER.md` | **stays manual, correctly** — see below |
| `DEX_TICKET.md` | **stays manual** — Rob holds the Jira trigger |

**Two things must NOT be generated**, and the distinction is the whole point:

- `IMPORT_LEDGER.md` records an **external act** — somebody imported something into a tenant.
  Generating it would be fabricating evidence. It is gated instead (`audit_lifecycle` STAGE 6), and
  the gate treats **silence as the defect**: "built but not imported" is a perfectly good answer
  that must be written down.
- Prose judgement — next physical action, open decisions, accepted divergences. A generator has no
  standing to decide what matters.

So the rule is not "generate everything". It is: **generate every DERIVABLE fact; gate every
EXTERNAL fact; hand-write only judgement.**

### What was already right, and should not be "improved"

`build_report` and `enforce` invoke **disjoint** tool sets — `enforce` reads `build_report`'s
hash-gated reports for the first group and runs the newer gates live. There is no duplicated
execution to remove. Checked 2026-07-30 rather than assumed; do not "optimise" this into a cache
that can go stale.
### Deferred: prefilled-mandatory fields have no wire verification (found 2026-07-30)

A combination's `set[]` may include a field the officer never types -- hidden and auto-populated
(NY `DALLOUT` carries `requestorDH`; the Automated Attention standard does the same on several
providers). **No gate can currently verify such a field reaches the wire**, and the reason is worth
stating because it is a two-gate hole, not an oversight in one tool:

* **6c `audit_log_content`** compares the log to the **plan's** `fills`. A hidden field is not in
  `fills` -- the driver cannot type it -- so 6c has nothing to assert and passes.
* **6d `audit_log_metadata`** requires the wire field-set to satisfy **some** metadata alternative.
  NY's `DALL` **alt1 is `[OperatorLicenseNumber]` alone** (the in-state branch), so a wire
  carrying OLN + PurposeCode + State but **no Requestor** still satisfies alt1 and passes.

The accepted-divergence rule `prefilled-mandatory-autopopulated` records the **design**. Nothing
checks the **result**. If a prefill ever fails, a metadata-mandatory field silently vanishes from the
wire and the package still reads green -- the exact class this standard exists to prevent.

**The fix is TWO parts and part 1 alone is inert:**
1. `emit_test_plan.ps1` -- emit `expectedInWire`: `set[]` members of the WINNING combo that are
   not in `fills`. Keep it **separate** from `fills`; folding them in would make every such test
   look unfillable to the driver.
2. `audit_log_content.ps1` (6c) -- assert each `expectedInWire` field is present in the captured wire.

**Two mistakes already made here, do not repeat them:** the first attempt edited
`emit_test_plan_spec.ps1`, but 6c globs `\${Provider}_TEST_PLAN_v*.json` which does **not** match
`TEST_PLAN_SPEC_v*` -- two plan files exist per provider and they are not interchangeable. And the
traversal returned empty on all 40 tests, so validate it against the known answer first: NY
`DALLOUT` `set[]` must resolve to `[OperatorLicenseNumberDH, purposeCodeDH, requestorDH,
RegistrationStateDH]`. **Regression guard:** TX_TLETS must stay 89/89 on 6c and 16/16 on
`audit_gate_efficacy`, and the new assertion needs its own mutation or it has no failure proof.

**Interim mitigation:** on the first `DALLOUT`/`DALHOUT` test of any sweep, read the wire and
confirm `<Requestor>` is present. One human look settles whether the prefill works at all.

#### requestorDH -- RESOLVED DIAGNOSIS (2026-07-30, 4th pass, VERIFIED not inferred)

Supersedes the paragraphs above. Two facts, both checked against the artifacts:

1. `requestorDH` **IS** node-hidden -- the flag is `layout.default.<node>.hidden`, **NOT**
   `props.hidden`. `Get-QifHiddenFieldIds` reads the node level. Checking `props.hidden` is what
   produced my wrong claim that "NY's Person form has zero hidden fields". It carries
   `initialValue='X'` (the gate-feeder sentinel, same as TX Attention/emailAddress).
2. **The plan ALREADY records it.** `NY_NYSPIN_EJUSTICE_TEST_PLAN_v4.19.json` `formDefaults.Person` =
   `{ImageIndicator=Y, ImageIndicatorDH=Y, purposeCodeDH=C, nyNyspinTransactionNameDH=DALL,
   requestorDH=X}`.

**So NO `emit_test_plan.ps1` change is needed** -- the data is present, and my whole `expectedInWire`
design was redundant. The gap is entirely in 6c: `audit_log_content.ps1` uses `formDefaults` as an
**allow-list** (so an extra snapshot field is not mistaken for another test's optional -- see its L50
comment) and **never as an assertion**.

**THE FIX -- one file, one rule:** in `audit_log_content.ps1`, for each log, require that every
`formDefaults` field which is also a `set[]` member of the winning combo is PRESENT in that log's
captured wire. `formDefaults` entries that are not `set[]` members stay advisory.

**Needs its own mutation** -- strip a prefilled `set[]` field from a log's wire and confirm 6c FAILs --
or the new assertion has no failure proof, which is LAW 2. **Regression guard:** TX_TLETS stays 89/89
on 6c and 16/16 on `audit_gate_efficacy`.

**Why it was not applied:** the edit belongs inside a per-log loop that was not read, and editing
blind into unread code is exactly what produced three prior failed attempts (wrong plan file;
props-vs-node hidden level; an inert TEST_VALUE_OVERRIDES entry). The diagnosis was the hard part.

##### Exact insertion point for the 6c assertion (read 2026-07-30, so it need not be re-derived)

`audit_log_content.ps1`, inside `foreach ($p in $parsed)` — insert **after L68**, where `$t` (the
matched plan test) is resolved and before the `$t.kind -eq 'guardrail'` branch at L74.

Variables already in scope at that point:
* `$p.Fs` — parsed QUERY STRING field set (the form snapshot)
* `$p.Content` — full log; the wire body is extracted at L85 as
  `'(?s)COMMSYS XML\s*-+\s*(.*?)(COMMSYS XML RESPONSE|RMS QUERY|FIELD ANALYSIS)'`
* `$fd` — that entity's `formDefaults` (computed L62:
  `$plan.formDefaults.PSObject.Properties[$cand.entity].Value`) — **note it is currently scoped to the
  `$cand` loop, so it must be recomputed for `$t.entity` after the match**
* `$t.comboKeyRef` / `$t.expectedKeyRef` — the winning combo

**THE ONE OPEN DESIGN CHOICE, and it is why this was not applied blind:** 6c never loads the provider
JSON, so it has no `set[]` to test membership against. Pick one:
  (a) have `emit_test_plan.ps1` write each combo test's `set[]` into the plan (small, keeps 6c
      plan-only, consistent with "the plan is the contract"); or
  (b) load the JSON in 6c via `Get-ProviderRootJson` and look the combo up by keyRef **scoped to the
      test's entity** — L77-82 documents why un-scoped keyRef lookup is wrong (NY Boat and Vehicle
      both use RVEH/RCAR).
(a) is preferable: it keeps 6c's inputs to plan + logs, which is what makes it independent of the JSON.

Reuse the existing `$onWire` value-matcher (L92-96) rather than writing a new one — it already handles
the substring-collision case and the fact that Name serialises as `DOE, JOHN`. It is currently defined
inside the guardrail branch; hoist it above L74 to share it.

**LAW 2 requirement:** add a mutation to `audit_gate_efficacy.ps1` that strips a prefilled `set[]`
field from a committed log's wire and confirms 6c FAILs. Without it the new assertion has no failure
proof and is indistinguishable from a check that cannot fire.
**Regression guard:** TX_TLETS must stay 89/89 on 6c and 16/16 on gate efficacy afterwards.

##### FL/NJ mutation maps added 2026-07-30 -- 4 SURVIVORS, likely MY mutations not gate blindness

`audit_gate_efficacy`: **FL_FCIC 8/9, NJ_NJCJIS 5/8 + 1 INVALID** (was 6 and 5 generic-only).
Confirmed KILLED and therefore genuinely protected:
* `fl-drop-devdoc-optional` (0 -> 6 findings) -- guards the v7.13 RegistrationNumber fix from
  silent regression. This is the mutation that matters most on FL.
* `fl-fidelity-demote-mandatory` (5 -> 7).

**The 4 survivors, with the diagnosis to CHECK FIRST (do not assume gate blindness):**
1. `fl-prefill-routing-field` and `nj-prefill-routing-field` -- both my mutations walk
   `$v.Value.nodes.PSObject.Properties`, but the real layout shape is
   `layout.<variant>.<nodeId>.props` with **no `.nodes` level**. The mutation almost certainly
   applied NOTHING, so findings could not increase and the harness correctly said SURVIVED.
   VERIFY by asserting the mutated replica JSON actually contains the injected `initialValue`
   before believing either verdict.
2. `nj-fidelity-demote-mandatory` and `nj-drop-devdoc-optional` -- NJ's fidelity baseline ALREADY
   reports RANDFULL UNDER-REQUIRED for RandomRequest/State/LicensePlateTypeCode. Adding
   LicensePlateNumber to that same finding **does not add a `[WARN]` LINE**, and the harness detects
   by counting lines. So this is likely harness SENSITIVITY, not gate blindness: a mutation that
   worsens an existing finding is invisible to a line-count detector.
   FIX EITHER the mutation (target a combo with no existing finding) OR the harness (compare finding
   TEXT, not just count). The latter is better and helps every provider.
3. `vehiclemake-as-input` reports INVALID on NJ -- "Cannot bind argument to parameter 'InputObject'
   because it is null", i.e. NJ has no node matching the mutation's VehicleMakeCode lookup. INVALID
   is honest (not counted as a pass); scope the mutation or fix its lookup.

**CONSEQUENCE FOR CONFIDENCE, stated plainly:** FL and NJ are NOT at the same evidential standard as
TX (16/16) and NY (13/13). Their gates pass, but 4 mutations have not demonstrated those gates can
fail. Do not quote FL/NJ confidence as equal to TX/NY until these are resolved.

##### Gate-efficacy detection is now TEXT-AWARE (2026-07-30) -- FL/TX/NY all clean, NJ at 6/8

The harness detected only `$mut.N -gt $base.N`, a COUNT of `[FAIL]`/`[WARN]` matches. That is blind to
a mutation which makes an EXISTING finding worse instead of adding a new line -- so a gate that cannot
see a defect DEGRADE looked identical to one that catches it. Detection now also compares finding
TEXT and reports "N NEW finding text (count unchanged at X)". It earned its keep immediately:
`nj-fidelity-demote-mandatory` flipped SURVIVED -> KILLED on exactly that clause.
Also fixed: two prefill mutations hand-rolled a layout traversal instead of using the existing
`Get-Node` helper the working TX mutation uses. Read the working sibling first.

**After both fixes: FL_FCIC 9/9, TX_TLETS 16/16, NY_NYSPIN_EJUSTICE 13/13 -- all SURVIVED 0.**

**NJ_NJCJIS is 6/8 + 1 INVALID. Two survivors remain, BOTH diagnosed as MY mutation-design errors,
not gate blindness. Do not "fix" the gates for these:**
1. `nj-drop-devdoc-optional` -- aimed at the WRONG GATE. It removes `RandomRequest` from RANDFULL's
   `any[]` and expects `audit_devdoc_optionals` (2q) to fire, but `RandomRequest` is metadata-
   MANDATORY (`RAND set[LicensePlateNumber, RandomRequest, State, LicensePlateTypeCode]`) and is NOT
   listed as a devdoc optional -- the NJ devdoc "Possible Combinations" lines do not mention it. So
   no optional subset is being dropped and 2q is CORRECT to stay silent. Repoint the mutation at
   `audit_metadata.ps1`, which owns combination field coverage. A mutation must be aimed at the gate
   that OWNS the defect class. (An attempt to repoint it silently no-op'd on a multi-line string
   replace -- use the Edit tool or a single-line replace, and VERIFY the Gate= line changed.)
2. `nj-prefill-routing-field` -- the DESIGN is right: RANDFULL is combination [1] `set[LicensePlateNumber]`
   with no conditions and RANDFULLN is [2] gated `LicensePlateNumber NOT_EXISTS`, so prefilling the
   plate should orphan RANDFULLN outright. It does not register. VERIFY FIRST that the mutated replica
   JSON actually contains the injected `initialValue` on the Vehicle `LicensePlateNumber` node --
   the field already carries `initialValue=''`, so an `Add-Member -Force` may be writing where a
   direct property assignment is needed. Do not conclude the reachability gate is blind until the
   replica is confirmed mutated.
3. `vehiclemake-as-input` is INVALID on NJ (no matching node). INVALID is honest -- never counted as
   a pass -- but scope or fix its lookup.

**CONFIDENCE: FL_FCIC now meets the bar (9/9 + enforce 37/0/0 + reproducible + 113 tests, 0 unfireable).
NJ_NJCJIS does NOT yet -- 2 of its 8 mutations have not shown its gates can fail.**

##### REAL GATE BLIND SPOT found 2026-07-30: audit_metadata CHECK 4 coverage is UNION-based

Proven by manual mutation, not inferred. Removing the metadata-MANDATORY field `RandomRequest` from
NJ `RANDFULL`s `any[]` left `audit_metadata` at **92 PASS / 0 FAIL / 0 WARN, byte-identical to
baseline**. The reason is visible in its own output:

    [PASS]   keyRef RAND: set field 'RandomRequest' covered by RANDFULL,RANDFULLN

CHECK 4 asks whether a metadata field is covered by the UNION of the sibling combos that implement
that keyRef. So a field can be dropped from ONE combination and the check still passes because
another combination still carries it. **Per-combination requirement loss is invisible to it.**
That matters wherever one metadata keyRef is implemented as several synthetic combos -- NJ
RANDFULL/RANDFULLN, TX RQ{Plate}/RQ{VIN}, FL FBQ x4, i.e. most of the portfolio.
`audit_requirement_fidelity` is per-combination and DOES see this class, which is why it exists --
but it is ADVISORY, so nothing BLOCKS on the defect today.
FIX: make CHECK 4 report per-combination when a keyRef maps to multiple built combos, or promote the
fidelity gate from advisory to blocking once its false-positive rate is understood. Either way,
verify against the mutation `nj-drop-metadata-mandatory`, which must go KILLED.

##### Still unproven: nj-prefill-routing-field
NJ Vehicle `LicensePlateNumber` has NO `initialValue` property at all -- a manual direct assignment
threw "The property initialValue cannot be found on this object". An earlier scan printed
`initialValue=''` and I read that as an empty-string default; it was a NULL rendering as empty. So
the mutation never lands and the SURVIVED verdict says nothing about the reachability gate either
way. Add the property with Add-Member on the props object and ASSERT the replica JSON contains it
before drawing any conclusion.

**NJ_NJCJIS is 6/8 and therefore does NOT meet the bar.** One survivor is a real, now-documented
gate gap; one is an unlanded mutation. Neither is evidence of a defect in NJ v4.14 itself, whose
substantive gates (enforce 40/0/0, reproducible, 35 plan tests all fireable) are clean.

##### FL_FCIC fidelity: a FAKE 0/0 caught, and the fix regressed TX -- both recorded (2026-07-30)

Rob: "I do not feel like you are giving FL and NJ the same attention TX got." Correct. TX had every
fidelity finding individually adjudicated to 0/0; FL and NJ were only being REPORTED. Working FL
properly surfaced two things:

**1. FL's already-adjudicated rows were never honoured.** `Test-RegisteredUnbuilt` matches rule
`shadow|unbuilt`, and **`not-built` does NOT contain `unbuilt`** (hyphenated). FL's registry rows
`DriverLicenseQuery|QW|*|not-built` and `VehicleRegistrationQuery|QV|*|not-built` were therefore
inert. Widen the rule regex to `shadow|unbuilt|not-built|dead-combo|dropped-combo`. SAFE on its own.

**2. Widening it alone produced a FAKE 0/0 on FL -- do not accept that result.** Branches compared
fell **30 -> 27**: the row `FRQTitleLienInformation` PREFIX-matches metadata keyRef `FRQ`, so it
suppressed ALL FOUR FRQ alternatives, including the plate and VIN branches that ARE built. Same class
as the TX REG over-suppression. Watch the BRANCHES-COMPARED count, not just the finding count -- a
suppression fix that lowers coverage is not a fix.

**3. The obvious tightening REGRESSES TX and was reverted.** Requiring a prefix match to also name a
field present in that alternative's `set[]` restored FL to 30 branches / 5 real findings, but took
TX from 0/0 with 12 NOTE to 2 UNDER / 2 OVER with 9 NOTE -- TX's QV and RQ suppressions rely on the
loose prefix. Reverted to keep the portfolio in a known-good state.
CORRECT FIX (not yet applied): match a registry row to an alternative when the row's Field is in that
alternative's `set[]` **OR** the row's Field is `*` **OR** the row's keyRef equals the metadata keyRef
exactly. Verify against ALL FOUR: TX must stay 19 branches 0/0 with 12 NOTE, NY 16 branches 0/0,
FL must stay at 30 branches, NJ at 8.

**FL's 5 GENUINE findings, still unadjudicated (metadata verified, no ruling guessed):**
metadata `FRQ set[LicensePlateNumber] any[LicensePlateYear, Requestor, ImageIndicator]` and
`FRQ set[VehicleIdentificationNumber] any[Requestor, VINSequenceNumber, ImageIndicator]` -- so
**VehicleMakeCode and vehicleYear are in NEITHER FRQ any[]**, and we ride both on both combos. The FL
devdoc's "Possible Combinations" lines do NOT mention them either, so the TX `promoted-to-any`
justification ("never DROP a devdoc-optional") does NOT apply here. They are either genuine
over-sends to remove, or a divergence needing its own reasoning. Rob's call.
Plus `FRQVehicleIdentificationNumber UNDER-REQUIRED: TitleLienInformation` -- spillover from the
Gordon-sunset combo, which the corrected suppression above should absorb.

##### REAL BLIND SPOT #2 (2026-07-31): audit_combo_reachability misses a prefill that defeats NOT_EXISTS

PROVEN, not inferred. Replica mutated and VERIFIED to contain the prefill (3 Vehicle nodes,
3 occurrences of the injected value in the written JSON), and `audit_combo_reachability` still
reported **[PASS] 6 combination(s) checked -- all reachable**. NJ_NJCJIS:

    RANDFULL  [1]  set[LicensePlateNumber]           no conditions
    RANDFULLN [2]  set[VehicleIdentificationNumber]  cond: LicensePlateNumber NOT_EXISTS

Prefill `LicensePlateNumber` and RANDFULL matches EVERY submission while RANDFULLN's `NOT_EXISTS`
can never be satisfied -- RANDFULLN is orphaned outright. The gate does not see it.

**Why this matters more than the count:** enforce PHASE 2h exists to enforce BUILD_RULES 24, the
defect class that killed 35 combinations across 6 providers. It catches the case where a prefill
SATISFIES an earlier combo's `set[]` discriminator. It misses the case where the prefill DEFEATS a
later combo's `NOT_EXISTS` guardrail. Identifier-priority guardrails (`Plate NOT_EXISTS`,
`OLN NOT_EXISTS`, `Hull NOT_EXISTS`) are used on essentially every provider, so this hole is
portfolio-wide, not NJ-specific.

**FIX:** when evaluating reachability, treat a form-prefilled field as always-present on BOTH sides
of a condition -- so `X NOT_EXISTS` where X is prefilled must resolve to permanently FALSE, making
that combination unreachable. Its docs already claim it "resolves EXISTS/NOT_EXISTS on prefilled
fields"; that claim is not borne out for the NOT_EXISTS direction.
**VERIFY WITH:** the `nj-prefill-routing-field` mutation, which must flip SURVIVED -> KILLED, and
`nj-prefill-routing-field`'s FL/TX equivalents must stay KILLED. Pin the portfolio: every provider's
enforce must still read 0 FAIL afterwards -- if a real dead combo surfaces, that is a FINDING to
adjudicate, not a regression to undo.

**Two independent gate blind spots were found in one session by mutation testing alone:**
this one, and audit_metadata CHECK 4's union-based coverage. Neither was visible from a green board.
Both were found only because a mutation was expected to fail and did not.
