# TX_TLETS — DEX Ticket

**Active ticket:** [DEX-967 — \[TX - TLETS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-967)
Project: DEX (CJIS/USx/DEx Implementation) · Status (2026-07-21): In Progress

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

Related tickets: DEX-968 (TX identified dropdown info), DEX-1282 (email handler subtask,
delivered as RND-57165 → TX v4.1). TX_TLETS_CCH has **no** ticket of its own — tracked here only
by mention, not posted to (per Rob's call).

**Posted so far (history predates this pointer file — 4 comments on the ticket v4.0→v4.5,
2026-07-09 to 2026-07-17, not individually indexed here):**
- 2026-07-21 — comment 783347: v4.6 (Firearm CAD `GunSerialNumber`→`serialNumber` fix +
  reverse-propagation-ledger cleanup) + v4.7 (cosmetic: Vehicle Make/Year helper, Firearm NCIC-row
  move) + the 2026-07-20 hollow-toggle reopen (never previously posted) + the capture-extension
  multiple-download-gate fix (commit 9a5501e8) + RELEASE LINE — full re-test from Test 1, all 5
  entities, 21/21 combos, 87 logs, both gates 87/87, enforce 27P/0F/0W CLOSED. Known shadow
  limitation (QVVehicleIdentificationNumber) carried forward.
