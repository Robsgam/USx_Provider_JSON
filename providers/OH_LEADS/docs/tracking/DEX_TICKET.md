# OH_LEADS — DEX Ticket

**Active ticket:** [DEX-990 — \[OH - LEADS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-990)
Project: DEX (CJIS/USx/DEx Implementation) · Status (verified 2026-08-10): In Progress · Unassigned

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's tenant testing passes).

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-990`
> (cloudId `5ba7ec1f-1b3f-4b21-a2f2-5d04d124de2c`). `audit_lifecycle` (enforce 2r) READS THIS FILE,
> NOT THE TICKET — it can PASS on a lie and FAIL on the truth. HI's equivalent file did exactly that.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C.

**HOW THIS TICKET NUMBER WAS FOUND, because it was NOT recorded anywhere in the repo.** OH_LEADS was
absent from `knowledge-base/JIRA_REFERENCE.txt` AND from the `IMPORT_LEDGER.md` DEX column, so there
was no repo source to copy — and inventing a plausible number is a mistake already made once on IL
in this project. It was found by querying Jira for DEX issues matching OH/Ohio/LEADS: **DEX-990,
summary "\[OH - LEADS\] USx Provider Build"**, the identical naming pattern to IL's DEX-984
"\[IL - LEADS-OFML\] USx Provider Build". Then fetched directly to confirm the summary, the
In-Progress status, and that it carries **zero comments**.

Its description also supplies a fact the ledger was missing: the tenant is
**`usx-oh-leads.mark43.com`**.

**Posted so far:** NOTHING. `comments: []`, total 0 — this ticket has never been commented on, by
anyone. So the changelog dump here is a first post, not a catch-up (the same situation IL's DEX-984
was in on 2026-08-10, and it was verified as genuinely empty before posting there too).

**Current: v2.3 — BUILT 2026-08-10, NEVER tenant-tested, never imported.**
Recent history (full detail in `OH_LEADS_BUILD_NOTES.txt`):
- **v2.3** — DEX-1283 Attention `'X'` removed (feeder + both KQ.N/KQ.O combo `defaults[]`) and a
  DEX-1284 label pass: `License Number` → **OLN** (OH was the only provider of nine not using the
  canonical label), three different image labels → **NCIC Image**, three verbose stolen-check labels
  → **Stolen Check**, `(optional)` suffixes stripped, and four `# LABEL-OVERRIDE:` tags added so the
  lean labels register as INFO rather than CHECK 15 WARNs. Cleared
  `[FLAG:validate-imgind-20b-l30]` — validator now records 78 PASS where STATUS.txt was stuck at 77P.

**Owed to this ticket:** the full changelog dump (v1.0 → v2.3), then a release line once the sweep
passes. **Jira is DRAFT-AND-WAIT — draft and wait for Rob's explicit approval before posting.**

**TWO OPEN ITEMS THAT BELONG IN ANY POST, stated so they are not quietly dropped:**
1. **`ImageQuery` is devdoc-Basic and is NOT BUILT.** `audit_supported_queries` CHECK 0 reports it as
   "devdoc-Basic but NOT BUILT — each must be a documented skip", and it is documented nowhere. It is
   BUILDABLE: OH metadata defines `ImageQuery` (v9, 1 combination) and the devdoc gives
   `(In/Out) OperatorLicenseNumber, [ReasonCode, Requestor, UserName]`, all fields already present on
   the DL card. BUILD-vs-approved-skip is Rob's call.
2. **14 cards, 0 titles carrying a query path.** Every other provider runs 5–6 cards with
   path-carrying ALL-CAPS titles; OH's Vehicle alone is six cards. The collapse is the IL v2.1 pass
   and is a layout redesign that Rob's rendered-form review owns.
