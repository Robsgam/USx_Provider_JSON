---
name: usx-build
description: Use when the user says "build", "rebuild", or "re-audit" a USx/ConnectCIC provider that already exists under providers/ — i.e. PHASE 1 of the three-phase model. Covers the hands-off proof that the built JSON matches its devdoc + metadata BEFORE any human is asked for anything: devdoc combination coverage, optional-subset routing, combo priority, devdoc listing order, per-combination requirement fidelity, query trace, gate efficacy (catalogued + random fuzz), and enforce. Trigger on "rebuild <PROVIDER>", "build phase 1", "audit <PROVIDER>", "re-run the gates", or any provider-JSON change. NOT for a brand-new provider (use usx-new-provider) and NOT for tenant testing (use usx-test-iterate).
---

# USx Build — PHASE 1

Router over the repo's own tools and knowledge-base. Those are the source of truth and keep
changing; this skill says *when* to run what, and inlines only the reasoning that has been paid
for in real defects. **Do not restate KB content from memory — read the cited file live.**

Rob's model: **"you need to build the entire process around 3 functions — when I say rebuild or
build, when I say test, and when I save/finalize it."**

| Phase word | Command | Skill |
|---|---|---|
| build / rebuild | `tools\build_phase1.ps1 -Provider <NAME>` | **this one** |
| test | `tools\test_phase2.ps1 -Provider <NAME>` then `-PostIngest` | `usx-test-iterate` |
| finalize / save | `tools\enforce.ps1 -Provider <NAME>` → commit+push → `audit_lifecycle.ps1` | (below, Step 5) |

## Step 0 — One command runs the phase

```
tools\build_phase1.ps1 -Provider <NAME>          # audit only
tools\build_phase1.ps1 -Provider <NAME> -Rebuild # rebuild the JSON first
```

It runs, in order: **[1]** devdoc combinations built · **[2]** devdoc optional subsets route AND
transmit · **[3]** combo priority (no ungated subset ahead of a superset) · **[3b]** devdoc listing
order · **[4]** per-combination requirement fidelity · **[5]** query trace / prefill-dead · **[6]**
gate efficacy (hand-authored mutations) · **[6b]** random unaimed fuzz · **[7]** enforce. It ends
with SHORTCOMINGS plus an INTERPRETATION decision tree rather than a bare pass/fail.

**Do not hand-run the individual tools first.** If PHASE 1 is green there is nothing to chase; if
it is not, its SHORTCOMINGS list already names the owning tool.

## Step 1 — READ THE AUTHORITIES CORRECTLY. This is where defects come from.

Every shipped defect this process has caught traced back to misreading an authority, not to
sloppy code.

**Metadata is FIELD authority. Devdoc is QUERY authority.** Never drop a metadata-defined field
because a devdoc description omits it; never build a query the devdoc doesn't list as Supported.

**`<Choice>` POSITION IS LOAD-BEARING** (QIDM_REFERENCE.txt — Choice branch semantics):

```xml
<Set><Field Name/><Choice><Field Age/><Field BirthDate/></Choice></Set>
    -> ONE OF Age|BirthDate IS MANDATORY

<Set><Field Name/><Any><Choice><Field Age/><Field BirthDate/></Choice></Any></Set>
    -> both OPTIONAL
```

That single distinction decided real-vs-false on four findings in one session. CA_CLETS `IG.QGH`
was built with both discriminators in `any[]`; metadata had three `Name` variants and **none**
permitted it (#4 required `SexCode`; #5/#6 put the `Choice` inside `<Set>`). It shipped a request
no variant accepted and a committed PASS log proved it. The neighbouring `IR.QVC.N` looked
identical and was **correct**, because its variant #1 genuinely puts the `Choice` inside `<Any>`.

**`docs/reference/<P>_METADATA_REFERENCE.txt` FLATTENS Choice branches.** It emits one row per
`(keyRef, primaryField)` showing only the common mandatory prefix — so `IG.QGH Name` reads
`mandatory: CaRequestPurposeCode, Name`, collapsing three distinct variants. CLAUDE.md's Source
Authority table points here for "combo requirements", and following it builds the defect. **For any
question about whether a qualifier is mandatory, go to the raw XML `<Requirements>` per
`<Combination>`.** That is the one sanctioned raw-XML exception; state it when you do it.

**Devdoc square brackets mark optionals.** `#2 (In/Out) Name, Age` = Age MANDATORY.
`#1 GunSerialNumber, [GunCaliber, GunMake]` = those bracketed are optional. A build comment reading
"devdoc combos 2+3 add Age or BirthDate optionally" was the origin of the CA defect — preserved in
the source for a year.

## Step 2 — ORDER IS SEMANTICS (two lines, both required)

The platform fires the FIRST matching combination.

1. **SPECIFICITY** — an ungated combo whose `set[]` is a strict SUBSET of a later one steals every
   fill from it. Owned by `audit_combo_reachability` + step [3]. Covers **every** pair.
2. **DEVDOC LISTING ORDER** — the tiebreaker when two *different* queries could both execute on the
   filled fields (Rob: *"for nj we use the order that the combinations are listed as the priority
   for over filled fields"*). Owned by `audit_devdoc_order`, step [3b].

**`audit_devdoc_order` honestly reports "mapped N of M — unmapped combos are NOT checked", which
reads far worse than it is.** Run `tools\audit_order_risk.ps1` for the number that matters: pairs
where neither `set[]` is a subset of the other AND both are ungated, so *nothing but* devdoc order
decides. Measured 2026-07-31: TX 5, NY 0, NJ 0, FL 19, HI 0, CA_CLETS 2 — NY/NJ/HI ordering is
fully pinned and the coverage gap cannot touch them.

**A field listed as an optional on the WINNING devdoc combination belongs in that combo's `any[]`.**
FL Boat devdoc `#10 (Out) BirthDate, Name, State, [BoatHullIdNumber, ...]` precedes `#11` hull — so
name winning a name+state+hull over-fill is CORRECT and rides the hull along. Do not "fix" that
into an identifier-priority guardrail; I called it a defect once and the devdoc refuted it.

**NEVER prefill a routing field** (BUILD_RULES 24). A form `initialValue` on any `set[]` field makes
it always-present and permanently hides every combo needing its absence. This killed 35 combos
across 6 providers and made TX delete two real `(OutofState)` paths as fake "dead combos".
Counter-example worth knowing: CA's `purposeCode='C'` prefill is **harmless**, because purposeCode
is in *every* CA combo's `set[]` and so cannot shadow one over another — its 12 unreachable
`IV.4x` combos are structurally shadowed by `IA.QV`'s strict-subset `set[]`. A reverse-propagation
flag blamed the prefill; acting on it would have recovered nothing and broken CAD injection
portfolio-wide.

## Step 3 — FIX vs REGISTER. Get this wrong and you ship a regression.

Three outcomes, and the authorities decide which:

| Situation | Action |
|---|---|
| Both authorities agree the field/combo is wrong | **FIX the build script** |
| A LOOSER metadata variant legitimately permits what we built | **REGISTER** (`demoted-to-any` / `promoted-to-any`) |
| Devdoc brackets say optional but metadata says mandatory | **REGISTER** — metadata wins; "fixing" emits requests the metadata calls invalid |

`tools\accept_divergence.ps1 -Provider .. -Query .. -KeyRef .. -Field .. -Rule .. -Reason ..`

**Cite the variant in the Reason.** A registry row whose reason is a claim rather than evidence is
how a wrong diagnosis outlives its author.

**Two registry traps, both live-caught:**
- `audit_devdoc_optionals`' `Test-Accepted` matches the registry `Field` against the *filled*
  fields — for a "(mandatory only) NO COMBO FIRES" the un-filled optional is **not** one of them.
  Register a **mandatory** field of that devdoc item.
- `audit_requirement_fidelity`'s prefix bridge connects a registry keyRef (a BUILT combo name) to a
  bare metadata keyRef. A row for `FRQTitleLienInformation` once muted **all four** FRQ branches on
  FL, so 27 branches were compared while 3 were dark and it read "0 under / 0 over".
  **Watch BRANCHES-COMPARED, not just the finding count** — a suppression that lowers coverage looks
  identical to a clean run.

## Step 4 — THE GATES MUST BE ABLE TO FAIL (LAW 2)

`0 FAIL` is produced identically by a correct config and an inert check.

- `tools\audit_gate_efficacy.ps1 -Provider <NAME>` — injects each **known** defect class and checks
  the owning gate FAILs. KILLED = its PASS is evidence. SURVIVED = blind.
- `tools\fuzz_gate_efficacy.ps1 -Provider <NAME>` — **random**, sites enumerated FROM the JSON, aimed
  at nothing. This is the only check that can find a class nobody wrote a mutation for. Survivors are
  CANDIDATES needing triage; three classes survive *correctly* (synthetic combo with no metadata
  alternative; a devdoc-sanctioned optional; a semantic no-op).

**When you widen a gate's exemption, re-run its mutation before trusting the new PASS.** The
guardrail-wire exemption was widened twice in one day; both times `nj-guardrail-wire-leak` was
re-run to prove the check still fails.

**Promote any triaged-real fuzz survivor into `audit_gate_efficacy`'s `$MUTS`,** then fix the gate.

## Step 5 — FINALIZE

```
tools\enforce.ps1 -Provider <NAME>     # exit 0 IS the definition of done
git add -A ; git commit ; git push
tools\audit_lifecycle.ps1 -Provider <NAME>
```

**A version bump archives that provider's entire test package** — weigh every cosmetic change
against a full re-sweep of Rob's hands-on time.

**Standing instructions (do not re-ask):**
- **Jira: HELD** until the process and results are fully trusted. Do not comment on any DEX ticket.
- **Rendered form review is MANUAL and Rob's own gate.** `enforce` PHASE 2k is advisory and will
  read `[INFO] not reviewed`. **Never prompt for it, never list it as an owed item.** Be ready to
  record it when he says so: `tools\audit_form_review.ps1 -Path <json> -Record -Reviewer <name>`.

## Traps that have each cost real time

- **Verdict-by-substring.** Never grep a tool's whole output for `FAIL` — headers explain what a
  failure *is*. `test_phase2` scored a green 6c as FAILED off the summary line `RESULT: 0 FAIL`, and
  a scorecard called all six providers `INVERSION` because `audit_devdoc_order`'s header defines the
  word. **Anchor on the verdict line.**
- **Tools that `Write-Host`** produce nothing through an in-session pipeline. Capture with
  `& powershell -File <tool> ... 2>&1 | Out-String`.
- **A check that parses nothing passes everything.** Always print the DENOMINATOR (compared count,
  branches examined). A fingerprint check whose regex didn't match the tool's JSON output reported
  "all logs match" across 6 providers having compared zero.
- **`Set-Content -Encoding utf8` writes a BOM under PowerShell 5.1.** `validate.ps1` rightly FAILs on
  a BOM, so both mutation harnesses scored a fake 30/30 until they used
  `[IO.File]::WriteAllText(..., (New-Object Text.UTF8Encoding($false)))`.
- **PowerShell single-element array unwrap** — `@($x)` on a one-element result, `@($null).Count` is 1.
  This shredded `Get-MetaAltSets` into single-field alternatives and made gate 6d degraded on 13
  providers.
- **Multi-line `.Replace()` silently no-ops on CRLF.** Use the Edit tool; grep to confirm.
- **keyRefs COLLIDE across QIDMs** in one provider (BUILD_RULES 13). Always resolve query-scoped via
  `_sim_helpers`' `Get-ComboByKeyRef`; never search by bare keyRef.
- **Any tool answering "which combo fires" MUST call `Get-FiringKeyRef`** (`_sim_helpers.ps1:43`).
  `Infer-ComboFromXml` re-walked it without evaluating conditions and labelled a log for a
  condition-gated-out combo.

## Verification

PHASE 1 exits with SHORTCOMINGS empty and `enforce` at `0 FAIL / 0 WARN`. Anything else is the
work, not a footnote.
