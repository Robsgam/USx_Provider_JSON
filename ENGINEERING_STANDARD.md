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
