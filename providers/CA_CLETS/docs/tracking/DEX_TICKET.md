# CA_CLETS — DEX Ticket

**Active ticket:** [DEX-976 — \[CA - CLETS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-976)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-976`
> (fields: comment). DEX-976 is ~55k chars and blows the tool-result limit: fetch it, then grep the
> saved result for comment ids / versions rather than reading it whole. Until 2026-08-04 this file
> waved at "12 comments ... not individually indexed", so it could not answer "what is owed"; the
> equivalent file on FL produced a confidently wrong answer that way.
>
> **`audit_lifecycle` (enforce 2r) READS THIS FILE, NOT THE TICKET** — it can PASS on a lie and FAIL
> on the truth. A 2r GAP means "check both".
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C.

**Posted so far** (earlier history not individually indexed; the ticket is authoritative):
- 2026-07-21 — comment 783180: v2.13 (relabel) + v2.14 (Vehicle card collapse + helpers) dump,
  plus v2.15 fix (removed APPSRequestIndicator -- a stale v2.7 accepted-divergence decision whose
  own reasoning inverted the field-authority rule; live testing at v2.14 caught it via
  audit_log_metadata.ps1 FAILing 9/9 IR.QVC.N logs) + RELEASE LINE -- all 5 entities re-tested at
  v2.15 (25/25 combos, 92/92 logs both gates green, enforce 28P/0F/0W CLOSED).
- 2026-07-27/28 — comments 786579 / 786641 / 787391: v2.19 in/out-gating fix (existence-gate Vehicle
  + Boat OOS routing) through v2.22 Person/layout cleanup, ending in the **v2.22 RELEASE LINE**.
- 2026-08-04 — comment 791400: **v2.23 changelog + RELEASE LINE** — 90/90 ALL-PASS, four log gates
  green, enforce 43P/0F/0W, inflation 0/0/0/0, with all four wire fixes proven on the wire.

**Current: v2.23 — tenant-verified 2026-08-03, ALL-PASS 90/90** (Vehicle 23 / Person 41 / Firearm 7 /
Article 10 / Boat 9), four log gates green, enforce 43 PASS / 0 FAIL / 0 WARN.

> ⚠️ **THE v2.22 RELEASE LINE ON THIS TICKET WAS GREEN AND WRONG.** Comment 787391 reports v2.22
> ALL-PASS; it passed 90/90 on three of the four log gates while shipping a request the metadata
> calls invalid. v2.23 fixed four wire defects it did not surface -- the `IG.QGH` split (a Name-only
> gun query was accepted and SENT), `IR.QVC.OS` (an OLN+SSN search routed to `ID.L1`, which defines
> no optionals, so the officer's SSN was accepted and NEVER TRANSMITTED), `NLTS.DQ.N` SexCode, and
> the `IR.QVC.C` age over-send. Do not treat the v2.22 comment as evidence of correctness. This is
> the case that motivated the fourth log gate and `audit_buildnotes_fidelity`.

**Nothing owed to this ticket.** The v2.23 gap was closed by comment 791400. One consolidated comment
per release, not one per version (Rob 2026-08-03: the per-version format "becomes tldr").
