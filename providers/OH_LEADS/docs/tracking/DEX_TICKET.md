# OH_LEADS — DEX Ticket

**Active ticket:** [DEX-990 — \[OH - LEADS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-990)
Project: DEX (CJIS/USx/DEx Implementation) · Status (verified 2026-08-10): In Progress · Unassigned

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

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

**Current: v2.4 — BUILT 2026-08-10, NEVER tenant-tested, never imported.**
Recent history (full detail in `OH_LEADS_BUILD_NOTES.txt`):
- **v2.4** — **card collapse 14 → 6** (Vehicle 6→1, Person 5→2, Boat 3→1) with every title now
  carrying its query paths; OH had been the only provider of nine with 0 path-carrying titles. Zero
  routing change. Helper labels fell 18 → 2 as a *consequence* (the survivors were saying which combo
  needs a field — a card title's job). Plus **ImageQuery BUILT**, the last unbuilt devdoc-Basic query:
  `Set[OperatorLicenseNumber]` per metadata v9 BMVIMS, `autoSelect=false` so it is an officer opt-in
  photo request rather than something that co-fires on every OLN entry. New queryLabel
  **Driver Photo** registered in `verify_build` and the CLAUDE.md table. Extract promoted
  PROVISIONAL → **CONFIRMED** (gating): 23 PASS / 0 FAIL / 0 WARN, 7 of 7 Basic queries built.
- **v2.3** — DEX-1283 Attention `'X'` removed (feeder + both KQ.N/KQ.O combo `defaults[]`) and a
  DEX-1284 label pass: `License Number` → **OLN** (OH was the only provider of nine not using the
  canonical label), three different image labels → **NCIC Image**, three verbose stolen-check labels
  → **Stolen Check**, `(optional)` suffixes stripped, and four `# LABEL-OVERRIDE:` tags added so the
  lean labels register as INFO rather than CHECK 15 WARNs. Cleared
  `[FLAG:validate-imgind-20b-l30]` — validator recorded 78 PASS where STATUS.txt was stuck at 77P.

**Owed to this ticket:** the full changelog dump (v1.0 → v2.4), then a release line once the sweep
passes. **Jira is DRAFT-AND-WAIT — draft and wait for Rob's explicit approval before posting.**

**BOTH OPEN ITEMS ARE CLOSED at v2.4 (Rob's call 2026-08-10: "fix 1 and 2 — that was the point").**
1. ~~`ImageQuery` devdoc-Basic and NOT BUILT~~ → **BUILT.** `Set[OperatorLicenseNumber]` exactly per
   metadata v9 `BMVIMS`, `autoSelect=false` (officer opt-in, so it does not co-fire on every OLN
   entry), no new form control needed. CHECK 0 now reports all **7 of 7** Basic transactions built.
2. ~~14 cards, 0 path-carrying titles~~ → **6 cards, 6 path-carrying titles**, matching the portfolio.
   Person deliberately stays at TWO cards (DL + DH) because the DH-suffix fieldIds are a separate
   field pool — that is the isolation mechanism, and HI/NY/TX/AZ keep the same split.

**One advisory remains, pre-existing and NOT introduced by v2.4:** `audit_requirement_fidelity`
reports 1 UNDER-REQUIRED (`DQ.O` missing `SocialSecurityNumber`). It is the shared-keyRef artifact —
`BMVIMS` names both DriverLicenseQuery's OLN variant *and* its SSN variant, and the tool bridges on
the bare keyRef and compares against their union. **DL-by-SSN is not in OH's Basic DL list** (five
combinations, OLN and Name only), so that variant is correctly unbuilt. Deliberately not registered:
naming the BUILT combo `DQ.O` with an existence-class rule would suppress its whole comparison.
