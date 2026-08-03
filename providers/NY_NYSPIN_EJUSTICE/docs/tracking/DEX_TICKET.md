# NY_NYSPIN_EJUSTICE — DEX Ticket

**Active ticket:** [DEX-969 — \[NY - NYSPIN_EJUSTICE\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-969)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

**Related tickets:** DEX-970 ("Unable to Import JSON", Done), DEX-1066 ("assistance -
DriverHistoryQuery", Backlog), DEX-698 (DEx Support, Done). Provider-build ticket is **DEX-969**.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-969`
> (fields: comment). Until 2026-08-03 this file listed ONE comment (782804, v4.10) while the ticket
> was current through **v4.16** — 25 comments exist. A stale pointer produces confident wrong
> answers about what is owed; on FL the same shape yielded "nine versions owed" when it was five.
> **DEX-969 is large (~86k chars): fetch it, then grep the saved result for comment ids/versions
> rather than reading it whole.**
>
> **`audit_lifecycle` (enforce 2r) READS THIS FILE, NOT THE TICKET.** So it can PASS on a lie (this
> file updated, nothing actually posted) and FAIL on the truth (posted, file stale — which is what
> happened on 2026-08-03: comment 790896 went up and 2r still reported a GAP until this file was
> updated). Treat a 2r GAP as "check both", never as proof either way.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C.

**Posted so far** (older comments not individually indexed; the ticket is authoritative):
- 2026-07-21 — comment 782804: v4.10 Firearm CAD fix (GunSerialNumber->serialNumber) changelog
  + RELEASE LINE — full 5-entity retest, 17/17 combos CONFIRMED (0 PENDING), enforce CLOSED.
  Firearm serialNumber fix confirmed populating live (Leo Hisoire-reported CAD issue resolved).
- 2026-07-27 — comment 786614: v4.16 **RELEASE LINE** — all 5 entities re-tested, 67/67 logs,
  enforce 28P/0F/0W. Watcher file detection hardened this pass (FileSystemWatcher -> 3s polling).
- 2026-08-03 — comment 790896: **v4.17–v4.19 changelog + v4.19 RELEASE LINE** — 64/64 ALL-PASS,
  four log gates green, enforce 41P/0F/0W, inflation 0/0/0/0. Explains the 67→64 plan-count drop
  (the plan is derived from the build; v4.17–v4.19 changed the Vehicle surface to 17).

**Current: v4.19 — tenant-verified 2026-08-03, ALL-PASS 64/64** (Vehicle 17 / Person 24 / Firearm 5 /
Article 4 / Boat 14), four log gates green, enforce 41 PASS / 0 FAIL / 0 WARN.

**Nothing owed to this ticket.** The v4.17–v4.19 gap was closed by comment 790896. The
per-version-comment format was collapsed to ONE consolidated comment at Rob's direction 2026-08-03
("it has become quite verbose and becomes tldr") — do not revert to a comment per version.
The parked `LIMITATION #38` VehicleMakeCode item is excluded from Jira by Rob's call.
