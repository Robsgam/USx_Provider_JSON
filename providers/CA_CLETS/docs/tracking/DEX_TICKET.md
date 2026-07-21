# CA_CLETS — DEX Ticket

**Active ticket:** [DEX-976 — \[CA - CLETS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-976)
Project: DEX (CJIS/USx/DEx Implementation) · Status (2026-07-21): In Progress

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

**Posted so far (history predates this pointer file -- 12 comments on the ticket from v2.5
through v2.12, 2026-06-14 to 2026-07-02, not individually indexed here):**
- 2026-07-21 — comment 783180: v2.13 (relabel) + v2.14 (Vehicle card collapse + helpers) dump,
  plus v2.15 fix (removed APPSRequestIndicator -- a stale v2.7 accepted-divergence decision whose
  own reasoning inverted the field-authority rule; live testing at v2.14 caught it via
  audit_log_metadata.ps1 FAILing 9/9 IR.QVC.N logs) + RELEASE LINE -- all 5 entities re-tested at
  v2.15 (25/25 combos, 92/92 logs both gates green, enforce 28P/0F/0W CLOSED).
