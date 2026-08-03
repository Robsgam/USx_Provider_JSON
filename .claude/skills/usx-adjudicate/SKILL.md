---
name: usx-adjudicate
description: Use when a gate reports a finding and you must decide what to DO about it — fix the build, record it as an accepted divergence, or dismiss it as a tool artefact. Trigger on "is this real", "should we build it or register it", "silently not transmitted", "NO COMBO FIRES", "UNREACHABLE", "OVER-PERMITTED", "missing from JSON set[]", any fuzz survivor, or any finding you are about to act on. NOT for reading metadata grammar (use usx-metadata) or writing a gate (use usx-tooling).
---

# Adjudicating a finding without shipping the wrong fix

This is the most repeated high-stakes routine in the project: a gate prints something, and you decide
whether to change a provider, write a registry row, or walk away. On 2026-08-02 it ran about ten
times in one day and **two of those adjudications were wrong on the first attempt** — one drafted a
complete fix that the metadata then refuted, one wrote a registry row that silently cost coverage.
Both were caught by the steps below, which is why they are steps and not advice.

**The governing fact: the finding's WORDING carries almost no information.** The same sentence was a
real dropped value on four providers and correct behaviour on six, in one day.

## Step 1 — Validate the probe before believing the number

A finding you produced yourself is a measurement, and an unvalidated measurement is a guess.

- **Run the probe against a KNOWN-PRESENT case first.** A zero means nothing until you have seen the
  probe return non-zero for something you know exists. (`GunTypeCode` absent from OR_LEDS's
  `GunQuery` was only trustworthy because `GunMake` and `GunCaliber` both resolved in the same query.)
- **A finding repeated across many providers is usually YOUR bug.** 25 "orphan deselects" across 13
  providers = config *names* compared against *query* names. 100 "dead controls" across all 20 = the
  layout helper's parameter name instead of the emitted fieldId. **Systemic-looking findings are
  systemic-looking because the probe is systematically wrong.**
- **Two gates disagreeing is a gift.** Suspect the one that SIMPLIFIED its authority. `audit_metadata`
  said six LA_LEMS fields were missing while `audit_requirement_fidelity` said 0/0 — the first was
  comparing against a sibling-variant union.

## Step 2 — Establish the cause at the right granularity

Almost every wrong adjudication comes from answering at too coarse a level.

| You are tempted to ask | Ask instead |
|---|---|
| does the metadata define this field? | does the **FIRING COMBINATION's own `<Requirements>`** define it? |
| does this keyRef require it? | a **keyRef is not a variant** — scope by (query, keyRef, primaryFieldReference) |
| does this transaction define it? | **transaction-level agreement is not variant-level agreement** |
| what is this field's maxLength? | its maxLength **inside the transaction you are building** |

`OH_LEADS` had a complete fix written — attributes, controls, handler, combo wiring — because the
metadata defined `ReasonCode`/`Requestor`/`UserName` on the DriverLicense **transaction** and the
devdoc listed them on that **query**. The built variant `DL{OLN}`'s `<Any>` is EMPTY; they belong to
`BMVIMS`. Reverted. See `usx-metadata` shape 6.

## Step 3 — Choose the disposition

| Evidence | Disposition |
|---|---|
| The firing combo's own variant DEFINES the field, and it is absent from the build | **FIX** — ride it in `any[]` (never `set[]` unless the variant mandates it) |
| The variant does NOT define it (devdoc's flat list belongs to a different variant) | **REGISTER** — adding it would OVER-PERMIT, a new defect |
| Metadata defines it nowhere for any built query | **REGISTER** as not-buildable |
| A committed tenant log proves the current behaviour works | **DISMISS + correct the document that said otherwise** |
| The gate compared the wrong things | **FIX THE GATE**, and see `usx-tooling` Step 5b first |
| Correct-but-unbuilt, and building costs a re-sweep | **Rob's call.** Present cost explicitly |

**`audit_optional_scope.ps1 -Provider <P>` answers Step 3 mechanically for the dropped-optional
class.** Run it instead of reasoning. It does not cover `NO COMBO FIRES` — that is adjudicated by hand.

## Step 4 — If REGISTER: get the row right, then MEASURE it

Two ways to write a row that is worse than writing none:

1. **Naming a BUILT keyRef with an existence-class rule** (`devdoc-combo-unbuilt`, `not-built`,
   `dropped-combo`) suppresses that combination's ENTIRE comparison. On IL_LEADS_OFML this dropped
   branches-compared 9 → 8 while the finding it was meant to record stayed exactly where it was.
   **Name the unbuilt item** — the convention is `(devdoc #N)` as the keyRef.
2. **A row that silences nothing and costs coverage.** Class `other`
   (`devdoc-optional-unreachable`, `built-as`, …) licenses no check by design — good for a *record*,
   useless as a *suppression*. Two rows were written and reverted the same day for this.

**Always capture branches-compared BEFORE and AFTER:**
```
tools\audit_requirement_fidelity.ps1 -Provider <P>    # before
tools\accept_divergence.ps1 -Provider <P> -Query <Q> -KeyRef <K> -Field <F> -Rule <R> -Reason "..."
tools\audit_requirement_fidelity.ps1 -Provider <P>    # after -- branches MUST NOT fall
tools\audit_suppression_scope.ps1                     # over-broad MUST NOT rise
```
A registration that lowers the denominator looks identical to a clean run. New registries are born
direction-aware; a legacy one silences by (query, keyRef, field) regardless of rule class.

**Write the REASON as evidence, not as a verdict.** Name the raw `<Requirements>` you read, the
probe you validated, the officer impact, and — if the answer could be different elsewhere — say so.
The rows that have aged well all say "do NOT generalise from another provider".

## Step 5 — If FIX: check the cost before you touch the build

- **Is the provider tenant-verified?** A build change archives its logs and owes a full sweep from
  T1. `report_test_status.ps1 -Provider <P>` — never assume.
- **Free now vs. expensive later.** If the provider already owes a sweep, folding a fix in costs
  nothing; deferring buys a second sweep. That argument is what carried FL_FCIC v7.16.
- **Prefer `any[]`.** A field in `set[]` becomes a routing discriminator, and prefilling one hides
  every combination that needs it (BUILD_RULES 24).
- **Never automate a field without approval.** Only `Attention` and `Requestor` are on the approved
  auto-populate standard; everything else ships as a visible control first.
- **Verify the emitted filename after a version bump.** Literal-match bumps silently no-op.

## Step 6 — Corroborate, then record where the next reader will look

- **A second independent gate agreeing is the strongest signal available in this repo.**
  IL_LEADS_OFML's unbuildable Article path was believed because `audit_devdoc_optionals` AND the
  spec-derived plan found it from different directions.
- A finding whose disposition is "recorded" must land in the registry **and** in the commit body.
  Commit bodies are the only place the reasoning survives, and `emit_decision_trail.ps1` surfaces
  them at session start — so write the body for the person who has forgotten everything.

## Verification

```
tools\audit_requirement_fidelity.ps1 -Provider <P>   # branches held, findings as expected
tools\audit_suppression_scope.ps1                    # over-broad did not rise
tools\enforce.ps1 -Provider <P>                      # exit 0
tools\report_test_status.ps1 -Provider <P>           # logs intact if you did not intend a re-sweep
```
