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
