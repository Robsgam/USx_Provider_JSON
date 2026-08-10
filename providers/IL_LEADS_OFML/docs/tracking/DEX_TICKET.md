# IL_LEADS_OFML — DEX Ticket

**Active ticket:** [DEX-984](https://mark43.atlassian.net/browse/DEX-984)
Project: DEX (CJIS/USx/DEx Implementation)

Ticket number supplied by Rob 2026-08-07. **This file did not exist before that**, and its absence
was briefly reported as "IL has no Jira ticket" — an inference from the silence of
`knowledge-base/JIRA_REFERENCE.txt` and this missing file, not a verified fact. The lesson is the
standing one: absence of a record is not evidence of absence.

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

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
