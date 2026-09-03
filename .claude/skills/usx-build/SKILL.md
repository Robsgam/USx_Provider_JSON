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

### 3a — "silently not transmitted": RUN THE ADJUDICATOR, DO NOT READ THE WORDING

`tools\audit_optional_scope.ps1 -Provider <NAME>` — do this **before** touching a dropped-optional
finding. On 2026-08-01 the identical sentence

> `#N +[Field] -> fires KEYREF but optional(s) Field are in NO matching combo's set[]/any[] --
> silently not transmitted`

was a **real dropped value** on AZ_AZDPS, CA_eSUN, CA_SAN_LUIS_OBISPO and OH_LEADS, and the **correct
behaviour** on TX_TLETS_CCH, NM_NMLETS_OFML, OH_LEADS(boat), OR_LEDS, MD_METERS and TN_TIES. Eleven
adjudications, same words, opposite answers. The wording carries no information — the metadata does.

**Why the ambiguity is structural, not sloppiness:** the devdoc gives **one flat optional list per
query**, while the metadata scopes optionals **per variant** — across separate transactions (in-state
NCIC keyRef vs out-of-state Nlets keyRef) or across **Choice branches** (a nested `<Set>` scoping
fields to one alternative). A flat list cannot express "optional, but only on the Nlets path".

**The only question.** Never "is it in the devdoc bracket?" — it always is, that is why it fired:

> **Does the FIRING combo's own metadata variant define this field?**
> **YES → FIX** — add it to that combo's `any[]`; we are discarding what the officer typed.
> **NO → REGISTER** — adding it would **OVER-PERMIT**, i.e. transmit a field that transaction does not
> define. That is a *new* defect, and `audit_requirement_fidelity` will duly report it as
> OVER-PERMITTED. "Adding it anyway to be safe" is not safe.

Scope by **(query, keyRef, primaryFieldReference)**. A keyRef is **not** a variant: `OR_LEDS`'s `BQ`
carries both `BQ{BoatHullIdNumber}` and `BQ{RegistrationNumber}`, and an unnarrowed lookup found
`RegistrationNumber` on the *sibling* and recommended FIX on the **hull** combo. Two providers flipped
FIX → REGISTER once PF narrowing was added.

**Severity order — do not treat these as one bucket:**
1. **UNDER-REQUIRED `set[]`** (a metadata-mandatory field sitting in `any[]`, with no looser variant)
   → the query can fire **without** it and the request is **INVALID**. `OR_LEDS` DQ.N/SexCode.
   6d catches this on a live log; **6c and 2i cannot** — a *missing requirement* is invisible to
   content and attribution checks, which is how a committed PASS log once carried one.
2. **Missing combination** — a metadata variant with no built counterpart, so fills fall to a looser
   combo and the extra fields vanish. `CA_SAN_LUIS_OBISPO` DQ.N/QVC.N, `OH_LEADS` QWA.
3. **Dropped optional** — narrower query than asked for, nothing errors.
4. **Over-permitted** — a field the variant does not define. What you create by "fixing" a #3 wrongly.

**When you add a missing combination, order it AHEAD of the looser one.** The looser combo's `set[]`
is a strict subset, so first-match hands it every fill and the new path is dead on arrival.

**A State gate belongs where the metadata FORKS BY state** — never on a variant that merely permits
`State` as an optional. `TN_TIES` KQ.N was gated `RegistrationState EXISTS` while metadata
`KQ{Name}` has `Any[State]`, which made an in-state driver-history name search **impossible** with no
other name combo to fall through to.

**Three registry traps, all live-caught:**
- **An UNBUILT-class row must name the UNBUILT thing, never a live combo.** Rules matching
  `shadow|unbuilt|not-built|dropped-combo|dead-combo` make `audit_requirement_fidelity` skip that
  keyRef's whole comparison. Registering CA's unbuilt devdoc VehReg #1 under `KeyRef = IA.QV`
  suppressed the **built and working** `IA.QV` branch and dropped coverage 27 → 26 with the finding
  count still at 0. Use `(devdoc #N)`. The tool now emits
  `[NOTE] REGISTRY OVER-SUPPRESSION RISK` when an unbuilt-class row names a built combo — if you see
  it, fix the row, don't ignore it.
- `audit_devdoc_optionals`' `Test-Accepted` matches the registry `Field` against the *filled*
  fields — for a "(mandatory only) NO COMBO FIRES" the un-filled optional is **not** one of them.
  Register a **mandatory** field of that devdoc item.
- `audit_requirement_fidelity`'s prefix bridge connects a registry keyRef (a BUILT combo name) to a
  bare metadata keyRef. A row for `FRQTitleLienInformation` once muted **all four** FRQ branches on
  FL, so 27 branches were compared while 3 were dark and it read "0 under / 0 over".
  **Watch BRANCHES-COMPARED, not just the finding count** — a suppression that lowers coverage looks
  identical to a clean run.

### 3d — BUILD EVERY VARIANT OF EVERY IN-SCOPE QUERY. "Register it as a skip" is the LAST resort, not the first.

**Rob, 2026-08-18 (CA_CLETS_OCATS):** *"not sure why you stopped short of making all the queries
combinations worked from the dev doc and metat data  proceed with that directive until complete with
a high level of confidemnce."*

I had REGISTERED two metadata variants as `dropped-combo` skips — `4K` (plate + plate-type) and `VC`
(owner name + business indicator) — with reasons that were *true* and still wrong as decisions: "no
devdoc Basic combination makes Plate + LicensePlateTypeCode mandatory", "BusinessIndicator appears
NOWHERE in the devdoc". Both are variants of `VehicleRegistrationQuery`, which **is** devdoc-Basic
supported. A registry row is not a substitute for a combination.

**THE SCOPE RULE, and it is a two-authority test — do not collapse it to one:**

> **Devdoc = QUERY authority** (is this transaction in scope at all — the "Basic Queries Supported" list).
> **Metadata = FIELD authority** (what that transaction's variants require and permit).
> **For every transaction the devdoc authorizes, BUILD EVERY metadata variant of it.** The devdoc's flat
> combination list does NOT have to enumerate a variant for that variant to be real — the metadata
> defines it, and the devdoc already authorized the query.

**What this is NOT.** Do not read it as "build every combination in the XML". Measure the denominator
before you act: `CA_CLETS_OCATS.xml` holds **214 combinations across 111 transactions**, and exactly
**FIVE** are devdoc-Basic. The rest are NCIC record **ENTRY / MODIFY / CANCEL / LOCATE** operations
(`BEArticleEntry`, `BEBoatCancel`, `UP.EA`, `UA.XB`, `AOSHazardousMaterialQuery`, …) — writing and
cancelling records, a different product surface. Building those is not completeness, it is scope
invention. **Enumerate metadata variants PER BUILT TRANSACTION, never per XML.**

**Building the missing variant is usually the RIGHT FIX for an OVER-PERMIT, and that is the payoff.**
On OCATS, built `4` permitted five optionals its own `<Any>` (which is EMPTY) does not define — two of
them prefilled, so every in-state plate query transmitted undefined fields. It looked like a binary:
tighten `4`'s `any[]` or accept the divergence. **Building `4K` was the third answer**: once
`LicensePlateTypeCode` is MANDATORY somewhere, removing it from `4`'s `any[]` costs the officer nothing
— the fill routes to `4K` instead. Result: fidelity `23 branches / 1 UNDER / 7 OVER` →
`25 branches / 0 UNDER / 0 OVER`, and query-trace `3 MISSING` → `0`. **Branches went UP while both
defect classes went to zero** — the signature of a real fix rather than a suppression.

**FOUR THINGS THAT WILL BITE, all of them on that one provider:**

1. **A prefilled field in the new variant's `set[]` makes it DEAD ON ARRIVAL (BUILD_RULES 24).**
   `4K` = `set[PurposeCode, Plate, LicensePlateTypeCode]`, and PlateType was prefilled `'PC'` — so its
   set collapsed to an always-present `[Plate]` and collided **exactly** with `4`. An exact collision
   is the one case ordering CANNOT separate (AZ_AZDPS DQPN/DQP). A "built" combo that can never fire is
   **worse** than an unbuilt one: it counts toward coverage and carries logs. **Remove the form
   prefill** so the field discriminates, and keep it in `defaults[]` for CAD — `defaults[]` does not
   participate in routing (`audit_combo_reachability` counts only form `initialValue` as always-present).
   Then verify with reachability, not reasoning.
2. **A NEW discriminator control must NOT be prefilled either, for the mirror reason.** `VC`'s
   `BusinessIndicator` is the only thing separating VC from VP; prefilling it would make VC always match
   and kill the plain owner-name search.
3. **ORDER THE NEW VARIANT AHEAD OF THE LOOSER ONE.** Its `set[]` is a superset, so if the subset combo
   sits first it takes every fill and the new path is dead (usx-build Step 3, and it applies here twice:
   `4K` ahead of `4`, `VC` ahead of `VP`).
4. **RETIRE THE OLD SKIP ROW IN THE SAME PASS — this one is silent.** An unbuilt-class rule
   (`dropped-combo|not-built|shadow|unbuilt|dead-combo`) makes `audit_requirement_fidelity` **skip that
   keyRef's ENTIRE comparison**. Leave the row in after building the combo and you have silenced the
   branch you just added: coverage FALLS while the finding count reads 0, which is indistinguishable
   from a clean run. Keep the retired text as history and say what superseded it.

**WHEN A VARIANT GENUINELY CANNOT BE BUILT, say why STRUCTURALLY and prove it.** OCATS' `QV{plate}` and
`QV{VIN}` have `set[]`s **identical** to `4` and `4V`; their `<Any>` adds only one optional each, and
**optionals cannot discriminate** because routing tests field PRESENCE against `set[]` plus conditions.
So no fill can distinguish them — whichever is ordered first takes everything. That is a routing
IMPOSSIBILITY (6a: "impossible = no configuration satisfies it"), not a preference, and
`audit_query_trace` agrees by reporting 0 MISSING once a combo of the same shape exists. Contrast that
with "the devdoc doesn't list it", which is **not** a reason. And do NOT import another provider's
explanation as authority: FL_FCIC's registry calls QV a platform auto-send "platform-confirmed", but
that claim is **not in the knowledge base**, so on a different provider it is a thing to verify, not a
fact to cite.

**Verify completeness with the tools, not by re-reading your own diff:**
```
tools\audit_query_trace.ps1 -Provider <NAME>          # MISSING must reach 0 (or be structurally justified)
tools\audit_requirement_fidelity.ps1 -Provider <NAME> # branches must RISE; UNDER/OVER must not
tools\audit_combo_reachability.ps1 -Path <json>       # every NEW combo must be REACHABLE
tools\audit_prefill_shadow.ps1 -Path <json>           # a prefill removal must not have created a shadow
tools\audit_wiring_closure.ps1 -Provider <NAME>       # a new control must not be a dead control
tools\validate.ps1 -Path <json>                       # a new control needs its row's templateColumns widened
```
That last one is not padding: adding a third control to a `cols = @('6','6')` row produced three real
validator WARNs on the first attempt.

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

## Step 4b — AFTER A DIRECT BUILD-SCRIPT RUN, RESET THE TEST PACKAGE

`pipeline.ps1` calls `reset_test_package.ps1` for you (its step 1). **Calling
`providers/<P>/scripts/build_<p>.ps1` directly does NOT** — so the prior version's TEST_PLAN
survives the version bump, and its tests still name combos that no longer exist.

```
tools\reset_test_package.ps1 -Provider <NAME> -Force
```

**How this bites, and why it looks like someone else's bug:**
`audit_simulator_parity` is a **GLOBAL** cross-check despite taking `-Path` — it walks EVERY
provider's plan against the canonical firing walk. Rebuilding CA_CONTRA_COSTA to v2.2 without
resetting left 4 stale plan tests expecting `ID.L1`/`IG.QGH`, and that made
`[FAIL] simulator parity` appear on **all five** unrelated providers in the next batch, each looking
like its own defect. One reset cleared all five (1173 plan tests across 20 plans agree).

So: a per-provider gate can carry a GLOBAL finding. Before treating the same FAIL on N providers as
N defects, check whether the tool is provider-scoped at all.

## Step 4c — THE OFFICER GUIDE IS A DELIVERABLE, NOT A BY-PRODUCT (convention set 2026-09-03)

`render_officer_guide.ps1` produces the sheet a department actually reads. It is regenerated by
`build_report` step 13, so it comes out of a normal rebuild — but its **contents are a convention**,
and the convention changed. Applied to all 13 swept providers on the day it was set, so the
portfolio is uniform; a provider rebuilt after that date inherits it automatically.

**Four columns, message key hard left:**

| Message key | Search by | Required fields | Optional fields |
|---|---|---|---|
| `RQ.P`<br>*Vehicle Registration by Plate Number - out-of-state* | Plate Number | CA Purpose Code, Plate Number, Plate Type, Plate Year | State |

- **The message key is the `keyReference`.** `QV`, `RQ`, `DQ`, `KQ`, `QGB` are the state's own
  transaction mnemonics — what a supervisor sees in a wire log or a CLETS manual. Without this
  column there was no way to tie a row on the sheet to a row in a log.
- **The interpretation underneath is DERIVED, never glossed.** It is composed from the combination's
  own query label, the identifier it searches by, and its `state` marking. Do **not** add a
  hand-written key dictionary ("QV = DMV vehicle inquiry") — that is an unsourced claim that goes
  stale the first time a keyRef moves, and it is the same class this repo refuses everywhere else.
- **Headers say REQUIRED and OPTIONAL**, not "Must enter" / "You can also add". The old wording read
  well but did not use the words a spec conversation uses, so the sheet could not be matched against
  a devdoc or a metadata reference without translating in your head.

**Mark43 branding — all of it sourced from Confluence "Brand Resources" (Marketing, page 4462313473),
none of it from memory:** palette `#24364E` navy / `#134DD1` blue / `#B4C7CF` grey; **Arial**, because
that page assigns Archivo to website and marketing collateral and Arial to "all other internal and
external docs"; and the company name is **Mark43** — no space, and never "M43", not even internally.

**The logo lives at `tools/assets/mark43_logo.png`** and every guide picks it up with no argument.
It is Mark43's own published file from the site header, and it is **embedded as a base64 data URI**,
never linked — the PDF is produced by headless Edge and an external `<img src>` renders as a broken
box in print. If a `.svg` is ever dropped beside it, the renderer prefers it automatically.
**Never redraw or approximate the logo.** The brand page forbids altering scale, colour or outline,
so a hand-rolled lookalike breaches the guideline it is meant to honour.

⚠️ **KEEP `render_officer_guide.ps1` PURE ASCII.** Literal em/en dashes in that file rendered every
guide's title as `CA_eSUN â€" Officer Query Guide` for months: PowerShell 5.1 reads a BOM-less script
as cp1252, so a UTF-8 dash arrives as three characters and is re-encoded on write. The page already
declared `utf-8` — the corruption was upstream, in the source. Emit `&mdash;` / `&middot;` instead;
entities cannot be misread whatever encoding the file is read as. This is the KB's documented PS 5.1
trap showing up as **silent output corruption** rather than a parse failure, which is worse: nothing
errors, the sheet just looks wrong to whoever prints it.

## Step 5 — FINALIZE

```
tools\enforce.ps1 -Provider <NAME>     # exit 0 IS the definition of done
git add -A ; git commit ; git push
tools\audit_lifecycle.ps1 -Provider <NAME>
```

**A version bump archives that provider's entire test package** — weigh every cosmetic change
against a full re-sweep of Rob's hands-on time.

**Standing instructions (do not re-ask):**
- **Jira: HELD** until the process and results are fully trusted, and **DRAFT-AND-WAIT every
  provider every time** — approval on one does not carry to the next. When the hold lifts:
  **one comment per RELEASE**, and if the numbers move before the next release **EDIT that comment
  in place** rather than posting a correction as a sibling. Format is fixed —
  `knowledge-base/JIRA_COMMENT_TEMPLATE.txt` is the single source; procedure in
  `knowledge-base/JIRA_REFERENCE.txt`. **There is no delete-comment tool** and an edit is
  irreversible, so capture the original body first. Sibling corrections are what left FL claiming
  121/121 → 118 → 117 → 116 and NJ 35 → 36 → 40 on one thread each; 73 comments had to be rewritten
  to stubs on 2026-08-11 to undo it.
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

## Step 6 — DECISIONS THAT ARE NOT YOURS (added 2026-08-05, all four paid for on AZ_AZDPS in one day)

### 6a. A DIRECTIVE IS NOT YOURS TO REVERT. If it creates a conflict, put up options.

Rob said "requester needs to be automated — this is non-negotiable." Automating it made `ACWL` a dead
combo, so I **reverted his instruction twice** and reported the conflict as a reason it couldn't be
done. His answer: *"you do not get to override my decisions, only advise when impossible."*

The conflict was real and the revert was still wrong — the fix was a one-line **reordering** (`ACWL`
ahead of `DQPN`), which is what the ordering rules already prescribed. I burned two cycles reverting
instead of one solving.

- **Impossible** = no configuration satisfies it. Say so, with the evidence.
- **Costly / creates a second problem** = NOT impossible. Present 2–3 concrete options with costs and
  a recommendation, then implement the choice.
- Never leave a directive un-implemented because you found a difficulty. Reverting it silently is the
  worst of both: the work is undone and the decision is made for them.

### 6b. BEFORE reasoning about a prefill, check the MANDATORILY-DEFAULTED list.

`ImageIndicator` (and `RandomRequest`, and any field the platform forces) **MUST carry a FormSelect
initialValue or it does not serialize at all** — FIELD_REFERENCE.txt Section 9 / BUILD_RULES 20b.

I reasoned from first principles instead: "it's in a `set[]`, so it's a routing field, so BUILD_RULES
24 forbids a prefill" — and left it blank. That would have shipped `DQPN`/`DQP` **permanently
unsatisfiable**, because their `set[]` requires a field that never becomes present. Two combos that
look built and cannot fire is worse than not having them.

The corollary that follows, and the actual discriminator rule: when the mandatorily-defaulted field
is always present, it CANNOT discriminate. Find the field that varies — on AZ that was `Requestor`
(officer/handler-fed, no default) — and order most-specific-first so nothing is shadowed.

### 6c. READ THE PROVIDER'S OWN BUILD_NOTES FOR THE FIELD YOU ARE ABOUT TO CHANGE.

I removed `RegistrationNumber` from AZ's Boat hull combos to enforce "reg or hull, not both".
`audit_devdoc_optionals` raised 4 dropped-optional FAILs and `audit_optional_scope` adjudicated FIX
(put it back). **AZ's v3.4 BUILD_NOTES already recorded making that exact change at v3.1 and
reversing it**, with the reasoning: identifier priority is about ROUTING, never about deleting a
permitted field from the payload. WHICH COMBO FIRES and WHAT THE WINNER TRANSMITS are two different
questions; a NOT_EXISTS guardrail settles the first and says nothing about the second.

`grep <FieldName> providers/<P>/docs/tracking/<P>_BUILD_NOTES.txt` costs seconds. A reversal already
written down is the cheapest authority in the repo.

### 6d. AN IMPORTED VERSION IS FROZEN. Change it and you must bump it.

v3.5 was in the AZ tenant when the automated `Requestor`, the `ACWL` reorder and the Y/N Stolen Check
landed — all under the same version number. The tenant showed a VISIBLE Requestor and FREE-TEXT
Stolen Check while the repo's v3.5 said otherwise. Rob caught it ("its still at 3.5").

**A version number describing two different forms is worse than no version:** the wire XML carries no
version, so every log captured against it is unattributable — `audit_log_inflation` attack B by
construction. Before editing a provider JSON, check whether the active version is installed
(`IMPORT_LEDGER.md`, or non-archived `logs/` = install proof for a USx provider tenant). If it is, the
edit is a BUMP, not an edit.
