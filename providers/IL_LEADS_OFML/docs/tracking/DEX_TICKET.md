# IL_LEADS_OFML — DEX Ticket

**Active ticket:** [DEX-984](https://mark43.atlassian.net/browse/DEX-984)
Project: DEX (CJIS/USx/DEx Implementation)

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting a version
     mention. Never write one in advance and never let a sync tool generate one. -->
POSTED: v2.7 comment 795242 2026-08-13

Ticket number supplied by Rob 2026-08-07. **This file did not exist before that**, and its absence
was briefly reported as "IL has no Jira ticket" — an inference from the silence of
`knowledge-base/JIRA_REFERENCE.txt` and this missing file, not a verified fact. The lesson is the
standing one: absence of a record is not evidence of absence.

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-984`
> (fields: comment) before asserting what is or is not owed.
>
> **`audit_lifecycle` (enforce 2r) READS THIS FILE, NOT THE TICKET.** So it can PASS on a lie (this
> file updated, nothing actually posted) and FAIL on the truth (posted, file stale). Treat a 2r
> verdict as "check both", never as proof either way.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Those belong in `providers/IMPORT_LEDGER.md` sections B and C.
>

**Current: v2.7 — TENANT-VERIFIED 2026-08-13, ALL-PASS 41/41** (Vehicle 14 / Person 10 / Boat 9 /
Firearm 5 / Article 3), four log gates 41/41, inflation 0/0/0/0, enforce 41 PASS / 0 IL-scoped
FAIL-or-WARN, 9 combos all reachable. This closed the portfolio's LAST owed tenant sweep.

**Posted:** only TWO comments are live on DEX-984 —
- `795041` — version-history anchor (v1.0 → v2.2)
- `795242` — **THE LIVE RELEASE LINE.** Created 2026-08-10 as v2.2; edited IN PLACE to **v2.7** on
  2026-08-13. Never post a sibling; edit this one. Original v2.2 body captured before the edit.

**Owed to the ticket: NOTHING.** v2.7 release line posted; JSON attached and catalog updated
2026-08-13 (recorded in `IMPORT_LEDGER.md` section C, not here).

**FORMAT CHANGED 2026-08-13 — the comment is now FOUR sections**, not six (Rob: the six-section
shape was "way too many details"). "Known limits" and "Documented skips" are no longer posted.
Consequence for THIS ticket, stated because the edit was irreversible: the three documented
non-builds that used to be visible in comment 795242 (Article devdoc #2, Boat `State2`–`State5`,
Boat `RegistrationState` staying optional) are no longer on the ticket. They remain recorded in
`IL_LEADS_OFML_ACCEPTED_DIVERGENCES.txt`, which owns and gates them.

> **JIRA UPDATES ARE HELD** (2026-07-31, Rob) until the process and results are fully trusted, and
> every post is DRAFT-AND-WAIT for explicit approval — establishing that once on another provider
> did not authorize it here.

## Posted comments

| Comment id | Version | Date | What |
|---|---|---|---|
| **795041** | v1.0 → v2.2 | 2026-08-10 | **First post on this ticket** — full changelog dump. Verified before posting that DEX-984 was genuinely empty (`comments: []`), so this is the initial dump, not a catch-up. Covers v2.2 cosmetic pass, v2.1 DEX-1284 convention pass + card collapse, v2.0 galvanization, v1.1/v1.0, plus the three documented non-builds (Article devdoc #2, Boat State2–5, Boat RegistrationState staying optional). Tenant details deliberately excluded. |
| **795242** | v2.2 | 2026-08-10 | **v2.2 RELEASE LINE.** ALL-PASS 41/41 (Veh 14 / Per 10 / Gun 5 / Art 3 / Boat 9), four log gates 41/41 each + plan completeness 5/5, validator 61P/0F/0W, 9 combos all reachable. Names all three guardrails with their conditions (`Z2.V` plate>VIN, `Z2.N` OLN>Name, `BQ.R` hull>reg) and confirms composite `Name` still wires LAST-first despite the v2.2 form reorder. Was held pending HI's sweep; released by Rob's "do both" once HI came back 46/46. |

**The published "9 combos" was verified, not assumed.** IL is one of the 13 providers whose SQVR
asserts no combo total, so `audit_sqvr_integrity` CHECK 2 reports `DID NOT RUN` here and had never
machine-checked it — and the same class of stale count was found wrong by 5 on HI the same day.
Re-counted from the emitted v2.2 JSON via `audit_test_coverage`: 9 combos / 9 matched / 100%. Correct
as published. Note `audit_combo_reachability` says "7 combination(s) checked" for IL — that is what it
COMPARED, not a combo count; do not cite it as one.

**Current: v2.3 — BUILT 2026-08-12, re-import + full 41-test re-sweep OWED.** Stolen Check now
defaults to `Y` on all four entities that carry it (Vehicle / Person / Firearm / Boat) — form
`initialValue` **and** the matching combo `defaults[]` on all eight carrying combos, because CAD
ignores form defaults and a form-only change would leave CAD-originated queries with no stolen check
at all. Safe: the field is `any[]`-only everywhere on IL, so no routing moved — IL's Vehicle
discriminator is `RegistrationState` (`Z2.P` EXISTS vs `Z5` NOT_EXISTS) and is untouched. Rob's
standing rule, 2026-08-12: default everywhere it makes sense and does not ruin in-state routing.
IL and FL were the only two of eight tested providers not following it. Gates: validator 61P/0F/0W,
prefill-shadow 5 pairs 0 FAIL, combo reachability 7 checked all reachable, audit_cad 60P/0F/0W.

## Owed at the next lift of the Jira hold

- **v2.2** (2026-08-07) — cosmetic pass on Rob's rendered-form review of v2.1: Vehicle VIN label
  spelled out to `Vehicle Identification Number` (helper removed), Person name fields reordered
  First-then-Last, and the identifier-priority hints stripped from Person `Last Name` and Boat
  `Registration Number`. Label/order ONLY — every guardrail and the LAST-first name wire format are
  unchanged. Gate efficacy 18/18.
- **v2.1** (2026-08-07) — DEX-1284 convention pass + card collapse: Vehicle/Person/Boat 3 cards → 1
  (11 cards → 5), `OLN` / `NCIC Image` / `Stolen Check` canonical labels, ALL-CAPS path-carrying card
  titles, uniform 4/4/4 grid. Layout/label ONLY — 9 combos, fidelity 9 branches 0 under / 0 over,
  0 prefill-dead, structurally identical to v2.0. Supported-query extract promoted
  PROVISIONAL → CONFIRMED so `audit_supported_queries` CHECK 0 now gates (10 PASS / 0 FAIL).
- Earlier versions (v1.0 → v2.0) have never been posted either; a first dump should cover the whole
  history, not just the two above. Read `docs/tracking/CHANGELOG_IL_LEADS_OFML.md` for the rendered
  source.

## Open external dependency — ISP LEADS bulletin, deadline 2026-11-01

**Not owed by this repo, but it has a date.** The 2026-08-06 LEADS Daily Bulletin says ISP turns on
edits on **2026-11-01** that reject FoxTalk/OFML messages with self-closing required HDR fields
(`<USR/>`, `<ORI/>`) or legacy free-text message keys (`<MKE>FREE</MKE>`). Assessed at v2.2 on
2026-08-10: **not out of spec on either class** — 41/41 captured wires carry populated `<UserName>`
and `<ORI>` with zero self-closing auth elements, and only structured keys are built
(Z2/Z5/QG/QA/BQ, no `FRE`).

Two confirmations owed, **both tenant-side not JSON-side**: production must supply a real IL ORI +
state UserId (ours are the `MK43RS` / `MK1234567` test values), and `<CDCName>` — declared correctly
in AUTH but absent from all 41 wires — must be populated per-transaction or via "Other State
Settings". One question for CommSys decides whether that CDCName gap matters at all: does their OFML
serializer **omit** an empty ConnectCIC auth field or **self-close** it?

Full analysis, evidence and the likely-metadata-change scenarios:
**`docs/reference/IL_LEADS_OFML_STATE_BULLETINS.txt`** · bulletin PDF + text extract in
`docs/reference/bulletins/`.

## Tenant

`https://usx-il-leads-ofml.mark43.com/rms/#/universal-search` — EXISTS, and **v2.1 IS INSTALLED**
(evidenced by the 2026-08-07 picklist capture returning the v2.1-only rendered labels `NCIC Image`,
`Stolen Check`, `Make`). 0 logs means never tenant-TESTED, not never installed. The repo is now
**v2.2**, so a **re-import is owed before any sweep** — an imported version is frozen, which is why
the cosmetic pass took a version bump rather than editing v2.1 in place. The capture extension covers
this host as of `automation/extension/manifest.json` **0.4.0** (before that it matched only 7 tenants,
so neither the driver nor the capture hook would have injected on IL). Import status is tracked in
`providers/IMPORT_LEDGER.md`, not here.

**JIRA CONSOLIDATION PASS 2026-08-11.** NOTHING to collapse on this ticket -- both of its comments are current (795041 history, 795242 release line). It was the only one of the seven already conforming to the one-comment-per-release rule, because it was first posted after that rule existed. Format for every future update is fixed by `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; there is no delete-comment tool, so superseded comments are stubbed, never removed.
