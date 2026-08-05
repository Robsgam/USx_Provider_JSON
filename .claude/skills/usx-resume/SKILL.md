---
name: usx-resume
description: Resume the USx Provider JSON project after a restart, crash, or any gap — restore and VERIFY the working environment so work continues as if nothing happened. Trigger on "resume", "pick up where we left off", "where were we", "continue", "I restarted you", or as the first action in any session that opens with the SESSION_STATE.md block. Also use before starting new work after a long gap, to confirm nothing was left half-finished.
---

# Resume USx work — "as if you blinked"

`SESSION_STATE.md` (auto-injected by the SessionStart hook) tells you the *information*: versions,
what is owed, open decisions. It cannot tell you the *environment*: what is running, what is
half-finished, what is sitting in Downloads waiting to be ingested.

This skill closes that gap. **Run the sweep before doing anything else.** It is cheap — a few
read-only commands — and it prevents the two expensive failure modes: silently redoing finished
work, and building on a half-applied change.

## Step 0 — THE MANDATORY READS. Do these BEFORE Step 1, every session, no exceptions.

Added 2026-08-05 because on 2026-08-04/05 I ran a full day of provider and tool work — seven shared
tools edited, one provider rebuilt three times — **without opening `ENGINEERING_STANDARD.md` once and
without invoking `usx-build` or `usx-tooling` at all.** Rob: *"you have strayed from global directives
that were supposed to be wired in as mandatory reads."* He was right, and the cause was not a
knowledge gap: the documents existed, were correct, and were specific. Nothing forced the read, bash
one-liners were cheaper than reading, and I chose speed. Every other "must" in this repo has a tool
that blocks; these did not. This step is the block.

### 0a. Read `ENGINEERING_STANDARD.md` — at minimum §1, §4, §5.

It is the repo-root, top-level contract for what "done" means, and CLAUDE.md's first section says
*read this first*. The three sections that decide whether a day's work is sound:

- **§1 — the three laws.** The form comes first; a gate that cannot fail is not a gate; authority is
  directional and BOTH directions need a gate.
- **§4 — rules for building a gate.** Two of these are the ones that get broken:
  - **§4.4 NEVER RE-IMPLEMENT AN EXISTING PARSER.** *"Five parsers were written wrong in one session
    by re-deriving something that already existed."* Reuse `_resolve_provider_json.ps1`
    (`Get-ProviderRootJson`) for JSON resolution, `_sim_helpers.ps1` for routing/which-combo-fires,
    `_metadata_keyref_match.ps1` + `audit_devdoc_combinations -Explain` for devdoc items. **Every
    false finding on 2026-08-04/05 came from this one rule** — hand-globbing `providers/$p/*.json`,
    hand-writing presence comparisons, and putting a replica in the scratchpad where no `source/`
    sits beside it (use the in-provider `$workJson` pattern `audit_gate_efficacy` uses).
  - **§4.3 DISTINGUISH "found nothing" from "never looked."** Zero findings with zero checks is a
    vacuous pass and must FAIL. Print the denominator. Hit three times in one day: 0 branches
    compared, 0 portability cells, an empty plan diffed twice.
- **§5 — what "finished" means.** Read it before calling anything ready. It is stricter than
  `enforce` alone, and it names `audit_gate_efficacy` (catalogued — NOT the random fuzz harness;
  do not conflate the two, I reported a fuzz survivor as an efficacy failure).

### 0b. INVOKE THE PHASE SKILL BEFORE ACTING, not after something fails.

| About to do | Invoke first |
|---|---|
| rebuild / audit a provider, change a provider JSON | `usx-build` |
| write or edit ANY `tools/*.ps1` | `usx-tooling` |
| decide MANDATORY-vs-OPTIONAL, which variant a combo implements | `usx-metadata` |
| act on a gate finding (fix / register / dismiss) | `usx-adjudicate` |
| tenant testing, capture ingest | `usx-test-iterate` |

The trigger conditions are literal. "Any edit to `tools/*.ps1`" means the first edit, not the first
edit that goes wrong. Writing new rules INTO a skill is not a substitute for reading it — I did both
on the same day and still broke the rules I had just written.

### 0c. Two habits that cost the most, stated as commands.

- **Route through the tool that owns the question.** CLAUDE.md's Source Authority table is mandatory
  routing, not advice. `portfolio_status.ps1` verbatim for status — never hand-assemble a table.
- **Run a gate BEFORE `git commit` and branch on its result.** I pushed twice in one session while
  `audit_session_state.ps1` read `[FAIL]`, the second time after writing the rule about it. Reading
  the verdict *alongside* the commit is not reading it.

## Step 1 — Read what the hook gave you

`SESSION_STATE.md` is already in context. If it is NOT (no `=== USx SESSION_STATE.md ===` block),
the hook did not fire: read the file directly and tell Rob the hook is broken.

Treat it as a **summary, not truth**. Git and the tools are authoritative. It states
`0 FAIL / 0 WARN` as the invariant and deliberately records no PASS count — do not "helpfully"
add one back, it drifts within the hour.

## Step 2 — Verify the repo (never assume)

```powershell
git -C C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON status --short --branch
git -C C:\Users\RobSgambellone\.local\bin\USx_Provider_JSON log --oneline -10
tools\portfolio_status.ps1          # canonical per-provider table -- never hand-assemble this
tools\enforce.ps1 -SkipGit          # expect 0 FAIL / 0 WARN
```

Reconcile against `SESSION_STATE.md`. **A mismatch means the file is stale — fix the file** (and
`enforce` PHASE 2l should have caught it, so note why it didn't).

## Step 3 — Sweep for leftover ENVIRONMENT state

This is the part no document can cover.

```powershell
# a) captures stranded in Downloads (a session that died mid-sweep leaves these)
Get-ChildItem "$env:USERPROFILE\Downloads" -Filter 'usx_captured*' -File -ErrorAction SilentlyContinue |
  Select-Object Name,Length,LastWriteTime

# b) stray watcher processes -- CONCURRENT watchers deadlock (feedback_capture_ingest_serialize)
#    MUST exclude self: the query's own command line contains the string "watch_captures", so a
#    naive -match reports a phantom watcher EVERY time (verified 2026-07-29 -- it flagged a PID that
#    had already exited, i.e. the sweep process itself). Match the actual script invocation and
#    exclude this process and its parent.
$self = @($PID, (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId)
Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" |
  Where-Object { $_.CommandLine -match 'watch_captures\.ps1' -and $self -notcontains $_.ProcessId } |
  Select-Object ProcessId,CommandLine
# If this returns nothing, there is no stray watcher. Confirm a hit still exists before killing it.

# c) half-applied bump: build script version vs the active JSON on disk
#    (enforce PHASE 2f reproducibility also catches this -- read its output)
```

**How to act:**
- **Stranded captures** → do NOT ingest reflexively. Check whether they are already imported
  (compare against `providers/<P>/logs/<Entity>/`), and confirm which provider/version they belong
  to. A capture from a superseded version must be discarded, not imported. Then run exactly ONE
  `tools\watch_captures.ps1 -Once` — never two concurrently.
- **Stray watchers** → kill them (excluding your own shell) before starting any ingest.
- **Half-applied bump** → finish it (`tools\pipeline.ps1 -Provider <NAME>`) or revert it. Never
  leave a build script ahead of its JSON; `enforce` will fail reproducibility and the JSON on disk
  is what would ship.

## Step 4 — State the single next physical action, then stop

Report, in a few lines:
1. where things stand (from the verified tools, not the file),
2. anything the sweep found,
3. **the one next physical action**, and whose it is — yours or Rob's.

Then **stop and let Rob confirm.** Do not start a version bump, a test sweep, or a Jira comment on
your own initiative after a restart: you have no way to know what he did in the gap.

## Landmines that specifically bite on resume

- **A version bump resets that provider's entire test package.** If the state file says a re-test
  is owed, it is owed from T1 — do not resume mid-matrix.
- **Jira may be on hold.** Check `SESSION_STATE.md` before commenting on any DEX ticket; Rob has
  held updates until after testing before.
- **Deferred ≠ open.** Items Rob has explicitly deferred (e.g. LA_LEMS, TN_TIES) must not be
  re-raised as findings. The state file marks these.
- **Don't re-derive settled rules.** BUILD_RULES §20–23 and
  `knowledge-base/UNIVERSAL_SEARCH_HANDLERS.txt` exist so you don't re-investigate the firing
  model, the one-provider-per-tenant ruling, form-queries-first, or the handler registry.
- **`pwsh -File` stringifies array/hashtable args** — `-Providers a,b` and `-Override @{}` silently
  fail that way. Call the script in-session instead.

