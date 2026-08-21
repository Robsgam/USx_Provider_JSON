---
name: usx-tooling
description: Use when writing a NEW shared tool under tools/, or changing an existing one — especially anything that parses metadata, compares fields, resolves paths, or suppresses findings. Trigger on "add a gate", "fix the audit", "why is this tool wrong", "make it work on all providers", or any edit to tools/*.ps1. Covers the regression fixture, the portability contract, PowerShell 5.1 traps, and the ways a tool change silently makes things worse. NOT for interpreting metadata content (use usx-metadata) or running the phases (usx-build / usx-test-iterate).
---

# Changing a shared tool without making things quietly worse

Every gate here is provider-agnostic **by intention**. Several were provider-specific **by
accident**, and each was found only when the tool met a provider it had never met. This skill is
how to avoid adding the next one.

**The governing fact: a tool change can lower coverage, break one provider, or silence a real
finding — and all three look exactly like success.** Measure, don't assert.

## Step 0 — Before writing anything, check it doesn't already exist

`ENGINEERING_STANDARD` LAW 4. Three of four classes in `audit_defect_classes` turned out to
duplicate `audit_requirement_fidelity` / `audit_devdoc_optionals` / `audit_query_trace` — each as
the **weaker** copy, and one of them (C2) was measuring the wrong thing entirely (it assumed `set[]`
must mirror metadata-mandatory, which is false for every synthetic keyRef split in the portfolio).
Ask which existing gate owns the question before adding one.

## Step 1 — THE REGRESSION FIXTURE. Use it or you are guessing.

Six providers report **0 UNDER / 0 OVER** on `audit_requirement_fidelity`, totalling
**116 branches compared** (re-measured 2026-08-02): `CA_CLETS` 27, `FL_FCIC` 30,
`HI_HCJDC_OFML` 14, `NJ_NJCJIS` 10, `NY_NYSPIN_EJUSTICE` 16, `TX_TLETS` 19.

**Five of the six are tenant-verified; `FL_FCIC` is NOT any more.** It left that set at v7.15–v7.17
(Requestor wiring, then dead-control removal), so it currently reads NEVER-TESTED and owes a full
sweep. Its 0/0 is still a valid **structural** baseline — the numbers must not move under a tool
change — but it is no longer backed by wire evidence, so do not cite FL as proof that a parser
agrees with reality. Check `report_test_status.ps1` before leaning on any fixture member's
authority; membership is stable, tenant-verification is not.

> **They must stay 0/0, and BRANCHES-COMPARED must not fall.**

Run the full 20-provider sweep **before committing**, not after. This fixture has already:
- **refuted a plausible improvement** — keyRef-scoped branch matching looked airtight (the tool's own
  header endorsed the policy) and drove UNDER from 15 to 27, breaking HI and NY. Reverted. See
  `knowledge-base/FIDELITY_TRIAGE.txt`.
- **caught a self-inflicted regression mid-improvement** — moving comparison to targetField space
  broke a sourceField-keyed whitelist, and AZ's OVER went **up** 6→11 while everything else improved.
  Only the full sweep showed it.

**Watch the denominator, not the finding count.** A suppression that lowers coverage looks identical
to a clean run. If branches-compared falls, name exactly which branches left and why — and if you
cannot, revert.

## Step 2 — Portability is a separate property from correctness

`tools\audit_tool_portability.ps1` runs the `-Path` gates against every provider and asks only
whether each **reaches a verdict**. **280 cells (14 gates x 20 providers), currently 0 unportable** (re-measured 2026-08-21; this line read 260/13 and was stale). The 13th is `audit_wiring_closure`, added 2026-08-02 -- it was blocking in enforce for a day while absent from this sweep AND from the fuzz panel, so **when you add a gate, add it to every harness that characterises the stack, not just to enforce**.

**A green portability sweep does NOT mean the tools are right.** Every real bug found on 2026-08-01
reached a verdict happily — it was just wrong:

| Bug | Symptom |
|---|---|
| alphabetical `*.xml` glob | read a 6-node excerpt as 466-node metadata, reported green |
| compared sourceFields to metadata refs | false findings on any unexpectedly-named control |
| whitelist in the wrong namespace | broke exactly one provider |
| PS-5.1 parse failure | worked under pwsh 7, silently broke a pipeline step |

Execution-portability is necessary; the fixture and the mutation harnesses cover correctness.

## Step 3 — Resolution and namespace rules

- **Never glob for a provider file.** Use `Get-ProviderRootJson` / `Get-ProviderMetadataXml`. The
  latter *refuses to choose* between multiple candidates on purpose: a caller can handle `$null`, but
  cannot detect a plausible wrong answer. Note the pick was not even stable — `Get-ChildItem`'s
  native order and `Sort-Object Name` disagreed on which of two files came first.
- **Scope every combo lookup by `(query, keyRef, primaryFieldReference)`.** A keyRef is not a
  variant, and the same keyRef appears under different transactions. This decided five outcomes in
  one day.
- **A whitelist must live in the same namespace as the comparison.** If you change what is being
  compared, re-express every lookup table in the new space.
- **Compare targetFields, not sourceFields** — the targetField is the wire contract.

## Step 4 — PowerShell 5.1 is the engine that runs your tool

`pipeline.ps1` / `enforce.ps1` invoke tools as `powershell -File` = **5.1**. Interactive work is
often pwsh 7. The grammars differ, so a tool can be written, run, and "verified" under 7 while being
a hard parse failure under 5.1 — which surfaces as swallowed `ParserError` text, not a FAIL line.

- **Non-ASCII inside a DOUBLE-QUOTED string in a BOM-less file breaks 5.1.** It decodes cp1252, and
  both `—` (U+2014) and `─` (U+2500) contain byte `0x94` = a right curly quote = string delimiter.
  Non-ASCII is fine in `'...'`, never in `"...$x..."`.
- **Nested same-type quotes inside `$()`** — PS7 accepts, 5.1 rejects.
- Run `tools\audit_ps51_parse.ps1` **as `powershell`**, not `pwsh`. It refuses to give a clean
  verdict off 5.1 because the first version of that very check ran under 7 and reported 99/0 while
  two files were broken.
- Other traps: `powershell -File` stringifies array args; `.Replace()` on a multi-line block no-ops
  silently on CRLF (**use the Edit tool**); `Set-Content -Encoding utf8` writes a BOM under 5.1.

## Step 5 — LAW 2: a gate that cannot fail is not a gate

Prove a new gate can FAIL before believing its PASS:
1. Inject the defect it claims to catch; confirm it FAILs with a useful message.
2. Confirm it PASSes on clean input.
3. If it depends on an environment assumption (engine, file present), make it **refuse loudly**
   rather than pass vacuously — *"a tool that cannot run has not PASSED."*

Then run `audit_gate_efficacy` (catalogued) and `fuzz_gate_efficacy` (unaimed).

### Triaging fuzz survivors — they are CANDIDATES, not verdicts

A survivor means *no gate reacted*. That is only a blind spot if the mutated JSON would actually
**behave differently on the wire**. Classify before believing:

| Mutation | Usually a CORRECT survivor when… | Real blind spot when… |
|---|---|---|
| `drop-conditions` | the condition merely restated a `set[]` requirement (gating `X EXISTS` when X is already in `set[]` is inert) | the condition was the **only** discriminator between two combos with identical `set[]` — then dropping it creates a shadow |
| `drop-any` of a form-only field (`RegistrationState`, `ImageIndicator`) | that field is on the `$formOnly` whitelist and metadata does not define it on that variant | metadata's `<Any>` **does** define it — then the officer's value is now silently dropped |
| `drop-set` of a composite-`Name` component | `Test-Has` treats any component as satisfying `Name`, so removing one still "matches" | the wire would send a partial name — a real defect the current granularity cannot see |
| `swap-order` | neither `set[]` is a subset of the other and they are not co-satisfiable | one is a subset of the other → first-match now steals every fill |
| `over-permit` | the added field is whitelisted, or the branch is unmapped so nothing compares it | the branch is mapped and the field is genuinely undefined there |
| `prefill-field` / `select-to-input` | the field is not in any `set[]`, so no routing changes | the field IS in a `set[]` → **BUILD_RULES 24**, the prefill hides every combo needing it |

**Cheapest decisive test:** ask whether the mutation changes *which combo fires* or *what the wire
carries*. If neither, it is a harmless edit and the gates are right to ignore it.

**Promote a TRIAGED-REAL survivor into `audit_gate_efficacy.ps1 $MUTS`** so it becomes a permanent
catalogued mutation. Do **not** promote one whose "defect" is an inverted assertion — a mutation that
*should* survive becomes a permanent SURVIVED row and teaches the next reader to ignore the report.
That mistake was made and reverted once already (`nj-devdoc-prefix-blind`).

**Recurring survivors worth knowing:** `drop-conditions` on a combo whose `set[]` already carries the
gated field, and `drop-any` of a form-only field, both showed up on four separate providers in one
sweep. Both are the correct-survivor case — which is exactly why a raw survivor **count** is not a
quality metric.

## Step 5b — "The tool is wrong" is a HYPOTHESIS, not a finding

The failure mode this skill creates in you: after you fix one genuine tool bug, the next warning
looks like the same bug. On 2026-08-02, minutes after correcting a real transaction-scoping mistake,
a `CA_SAN_LUIS_OBISPO` warning —

```
[WARN] OperatorLicenseNumber: QIF maxLength 20 > XML maxLength 17 -- server may reject
```

— was diagnosed as "`audit_metadata` isn't transaction-scoped" and a patch was started. **The tool
was right and the build was wrong**: the DL control really did accept 20 characters where that
transaction caps at 17. Had the gate been "fixed", the warning would have gone quiet with the defect
still shipping — and the obvious alternative "fix" (shrinking the field to match) would have
truncated a *valid* 20-character DH OLN, since that transaction genuinely allows 20.

**Before editing a gate that flagged something, verify the flagged artifact itself.** Read the
emitted JSON, not the build script's intent. A gate silenced by a tool change is the one defect no
denominator can reveal. Cheapest discriminator: does the finding survive when you check the actual
value by hand? If yes, the tool was right.

Corollary, both directions seen in one session: a *correction* to an artefact-producing tool
RESOLVES a finding to something concrete (`NO-FIRE` -> a named keyRef); a *suppression* makes it
vanish. If your change makes findings disappear rather than resolve, you suppressed something.

## Step 5c — Mutation-testing leaves footprints. `git checkout` is NOT a complete undo.

Mutating a real provider JSON in place is often the only way to aim a gate at a defect. Restoring it
is where the damage happens, and this bit **three times in one day**:

| Footprint | Symptom | Undone by |
|---|---|---|
| **mtime** — git writes a fresh timestamp | freshness gates FAIL: *"BUILD_NOTES date != JSON date"*, *"TEST_MATRIX predates JSON by 104m"* — on byte-identical files | `sync_version_docs -Provider <P>` (docs) or `build_report -Path <json>` (reports) |
| **derived artifacts** — reports regenerated FROM the mutant | provider fails on *"STATUS.txt missing correct BASE score"* after the JSON is restored | full `pipeline -Provider <P>` |
| **killed cleanup** — a timeout pre-empts `finally` | a marker/mutation left committed-adjacent | check `git status` immediately, every time |

Rules that follow:
- **Mutation-test with the STANDALONE tool, never `enforce`.** Standalone gates are read-only;
  `enforce` regenerates VALIDATOR_REPORT / VERIFY_REPORT / METADATA_AUDIT / CAD_AUDIT / LAYOUT /
  OFFICER_GUIDE / BUILD_MANIFEST / STATUS.txt. Those are written from a state that no longer exists
  and `git checkout` of the JSON does not undo them.
- **Prefer `-Path` against a replica** over in-place mutation. If a blocking gate lacks `-Path`, add
  it — a blocking gate that cannot be aimed at a replica has an efficacy nobody has measured.
- **After any in-place mutation, expect a re-stamp** and do it in the same action rather than
  discovering it in a later sweep. `git status` clean is necessary, not sufficient.
- **Keep the mutation window short.** A 10-minute timeout killing the run pre-empts `finally`.
- **RE-STAMP BEFORE YOU COMMIT, not after.** Fifth instance 2026-08-03: I mutated FL_FCIC, restored
  it, committed the findings, and only then ran `enforce` -- which reported BOTH footprint classes at
  once (`TEST_MATRIX predates JSON by 711m` AND `BUILD_NOTES date != JSON date`, the latter because
  the date had rolled over mid-session). The repair is `pipeline -Provider <P>` (stamps docs) plus
  `build_report -Path <json> -IncludeExtended` (regenerates the ancillary/render set the new PHASE 1
  currency check now watches). Order matters: mutate -> restore -> RE-STAMP -> verify -> commit.

## Step 6 — Suppression is dangerous. Re-measure it.

Before adding a registry path or exemption:
- Does it suppress **only** the intended case? An unbuilt-class rule naming a **built** combo skips
  that combo's whole comparison — that is how coverage dropped 27→26 with the finding count at 0.
- **Does it suppress anything at all?** Two registrations were written and reverted the same day:
  one keyed the wrong namespace, one removed 12 clean comparisons while changing no finding and
  silencing nothing. **A registration that costs coverage and buys nothing is worse than none.**
- **Is the tool right to refuse you?** `demoted-to-any` grants *"it rides in `any[]`"*; when the
  field is absent from `any[]` too, the tool still reports — a surviving mutation taught it that
  guard. Read the guard before trying a third spelling.

## Step 7 — Finish the job in the same action

- **Document a new tool in `knowledge-base/README.txt` AND the CLAUDE.md tools table immediately.**
  The undocumented-tool gate caught this **four times in one session**; the gate works, the habit was
  the defect.
- Update the tool count in the CLAUDE.md `## Tools (N scripts + M shared modules)` header.
- Write **why** in the tool's own header, with the concrete case that motivated it. A tool whose
  header explains the defect it prevents survives its author.

## Verification

```
powershell -File tools\audit_ps51_parse.ps1            # 0 PARSE-FAIL, on 5.1
powershell -File tools\audit_tool_portability.ps1      # 0 unportable
<full 20-provider sweep of the tool you changed>       # fixture 0/0, branches not fallen
tools\enforce.ps1 -Provider <a few>                    # 0 FAIL / 0 WARN
```

## Step 8 — PROBE HYGIENE AND HONEST VERIFICATION (added 2026-08-05)

### 8a. A PROBE REPORTING A SYSTEMIC FINDING IS GUILTY UNTIL ITS DENOMINATOR IS SHOWN.

Three self-inflicted "findings" in one day on AZ_AZDPS, each of which I started acting on:

| What I "found" | The actual cause |
|---|---|
| `audit_requirement_fidelity` is blind to an over-permit on a no-`<Any>` variant | I wrote the mutated replica into the **scratchpad**, so no `source/` sat beside it, `Get-ProviderMetadataXml` found nothing, and the tool reported **0 branches compared**. A replica must live INSIDE the provider dir — which is why `audit_gate_efficacy` uses `$workJson` there. |
| "driver submitted 12 but the plan holds 23" | My glob matched BOTH `<P>_TEST_PLAN_v*.json` and `<P>_TEST_PLAN_SPEC_v*.json`; I read counts off the wrong one. 12 planned, 12 submitted. |
| "a stale v3.0 TEST_PLAN is sitting in `logs/`" | `-Recurse` pulled it out of `logs/_archive_pre_v3.1/`. `reset_test_package` had done its job; I reported archived history as live clutter. |

Before reporting: print what the probe compared, and scope the glob. **A listing is not a finding.**
Pairs with the existing rule that a finding repeated across many providers is almost always your probe
— this is the single-provider version of the same error.

### 8b. YOUR VERIFICATION MUST BE ABLE TO FAIL, AND YOU MUST READ ITS VERDICT.

- `node --check driver.js` printed **"driver.js SYNTAX OK"** with node **not installed** — `$LASTEXITCODE`
  was still 0 from the previous command. Replaced with headless Chrome as a real V8 parser, and proved
  that probe could fail (injected `function broken( {` → `ERR`) before trusting its clean verdict.
- `audit_tool_portability -Only <gate>.ps1` reported **"0 cells exercised"** twice — `-Only` filters
  **providers**, not gates. Zero cells is not a pass. The real run was 260 cells.
- I committed a `SESSION_STATE` change while its own gate read **`[FAIL] 122 lines`**. Read the verdict
  BEFORE pushing, not after.

If a check cannot distinguish "clean" from "never ran", it is not a check yet.

### 8c. A SHARED-TOOL CHANGE THAT MOVES ANOTHER PROVIDER'S SCORE GETS A FLAG, NEVER A REBUILD.

My `validate.ps1` narrowing added a PASS line, which moved MD_METERS 69→70 and OH_LEADS 77→78 and
surfaced a real WARN on LA_LEMS. I regenerated all three providers' reports and synced their docs — a
mass rebuild by the back door, against one-provider-at-a-time. Rob: *"why are you straying… stick to
az only."*

Correct move: revert the other providers, sync ONLY the provider you are working on, and
`flag_pending_fix.ps1 -FixId <id> -Providers <P>` so each picks the change up at its OWN next rebuild.
Note `powershell -File` **stringifies array args**, so `-Providers 'A','B'` fails — call it once per
provider or in-session.

### 8d. A FUZZ SURVIVOR IS ONLY EVIDENCE IF EVERY PANEL GATE ACTUALLY LOOKED.

`audit_devdoc_optionals` is in the fuzz panel, flakes under parallel load, and **demonstrably fires**
on the Boat `drop-any RegistrationNumber` mutation when run alone — yet the harness reported that
mutation SURVIVED, and I recorded two "gate coverage gaps" that did not exist. The harness checked
vacuity once, at BASELINE, and never per mutation.

Fixed 2026-08-05: a survivor now names the gates that never looked and says to re-run them alone,
versus `[SURVIVED] no gate reacted (every panel gate looked)` when the verdict is trustworthy.
**A false SURVIVED is worse than a missed one — it sends you to widen a gate that already works.**
Also: `audit_gate_efficacy` counts `[FAIL]`, `[WARN]` **and `[LIMITATION]`** (validate's third verdict
class); omitting it made a correctly-reacting gate read SURVIVED.
