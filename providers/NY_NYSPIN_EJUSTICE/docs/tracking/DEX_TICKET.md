# NY_NYSPIN_EJUSTICE — DEX Ticket

**Active ticket:** [DEX-969 — \[NY - NYSPIN_EJUSTICE\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-969)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

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
- 2026-08-07 — comment 794205: **v4.20–v4.23 changelog + v4.23 RELEASE LINE** — 69/69 ALL-PASS,
  four log gates green, enforce 42P/0F/1W (the 1W is the parked cross-provider LA_LEMS item, not
  NY's — stated in the comment rather than dropped). Records three findings: the `Requestor`
  client-side-Send-gate discovery (v4.20 broke DALHOUT live, v4.21 fixed it by set[]→any[]), the
  Purpose Code dropdown DISPROVEN on this tenant (LIMITATION #39), and the Vehicle home-state
  strip live-proven. Explains the 64→69 count (+2 Vehicle home-state tests, +3 DH guardrails).

**Current: v4.23 — tenant-verified 2026-08-07, ALL-PASS 69/69** (Vehicle 19 / Person 27 / Firearm 5 /
Article 4 / Boat 14), four log gates green, enforce 42 PASS / 0 FAIL / 1 WARN (LA_LEMS, not NY).

**Nothing owed to this ticket.** The v4.20–v4.23 gap was closed by comment 794205. NOTE: this line
read "Nothing owed" while FOUR versions were unposted (2026-08-06/07) — it was true when written at
v4.19 and rotted silently, exactly as the warning above predicts. Re-verify against the ticket, not
this line. The v4.17–v4.19 gap was closed by comment 790896. The
per-version-comment format was collapsed to ONE consolidated comment at Rob's direction 2026-08-03
("it has become quite verbose and becomes tldr") — do not revert to a comment per version.
The parked `LIMITATION #38` VehicleMakeCode item is excluded from Jira by Rob's call.

**JIRA CONSOLIDATION PASS 2026-08-11.** 23 superseded comments on this ticket were rewritten to one-line stubs (the largest set of the seven), each pointing at the current release line. The version history remains readable at comment 782804. Format for every future update is fixed by `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; there is no delete-comment tool, so superseded comments are stubbed, never removed.
