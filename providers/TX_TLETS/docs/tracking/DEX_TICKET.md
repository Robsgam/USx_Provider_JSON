# TX_TLETS — DEX Ticket

**Active ticket:** [DEX-967 — \[TX - TLETS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-967)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting a version
     mention. Never write one in advance and never let a sync tool generate one.
     THE VERSION A COMMENT CARRIES IS MUTABLE. Under the edit-in-place rule the SAME comment id is
     rewritten to a newer version, so this marker must be updated on every in-place EDIT, not only
     when a new comment is created -- and the date is the EDIT date, not the creation date.
     Corrected 2026-08-14: this first read "v4.18 ... 2026-08-03" because it was backfilled from the
     history line below ("comment 790861 -- v4.13-v4.18 ... (2026-08-03)"), which records what 790861
     said WHEN CREATED. It was edited in place to v4.19 on 2026-08-11 and the live comment now reads
     "TX_TLETS v4.19 -- TENANT-VERIFIED ... RELEASE LINE -- v4.19 is verified and ready". Verified
     against Jira, not this file. A "comment N = version X" history line is stale by construction. -->
POSTED: v4.20 comment 790861 2026-08-14
POSTED: v4.21 comment 800608 2026-08-18
POSTED: v4.22 comment 807576 2026-08-27

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

Related tickets: DEX-968 (TX identified dropdown info), DEX-1282 (email handler subtask,
delivered as RND-57165 → TX v4.1). TX_TLETS_CCH has **no** ticket of its own — tracked here only
by mention, not posted to (per Rob's call).

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-967`
> (fields: comment) before stating what is owed. Until 2026-08-03 this file indexed ONE comment and
> said the rest "predates this pointer file", so it could not answer "what is owed" at all. The
> equivalent file on FL was 4 versions stale and produced a confidently wrong answer — "nine
> versions owed" when it was five. All 10 comment IDs are now listed below.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03).** No attachment note, no catalog post, no
> Foundation import line. **This overrides the ticket's own precedent** — the v4.10 and v4.12
> comments below both end with an `IMPORT: ... Balcones Heights` line, and v4.11 flagged Balcones as
> having fallen behind, so the old convention *was* to publish it. Rob was asked directly and
> confirmed: leave it off. Track it in `providers/IMPORT_LEDGER.md` sections B and C instead.

**Posted so far:**
- comment 776220 — v3.13→v4.0 rebuild under the current methodology (2026-07-09)
- comment 777144 — v4.0 full automation test pass; block-out deferred pending the EmailAddress handler
- comment 780118 — v4.1 EmailAddress auto-populate (RND-57165) + v4.2 QWName shadow removal
- comment 781401 — v4.5 **RELEASE LINE** (21/21 combos, 87 logs)
- comment 783347 — v4.6 Firearm CAD fix + v4.7 cosmetic + the 2026-07-20 hollow-toggle reopen + the
  capture-extension multiple-download-gate fix (commit 9a5501e8) + **v4.7 RELEASE LINE** (87 logs)
- comment 786271 — v4.8 DEX-1284 relabel pass; tenant testing complete (88 combinations)
- comment 786419 — v4.10 Person DL top-row; **RELEASE LINE** (83 logs)
- comment 786575 — v4.11 UPPERCASE card titles; warned the v4.10 tenant-complete state was reset
- comment 786638 — v4.12 Person 2-card fold; **RELEASE LINE** (84 logs)
- comment 790861 — **v4.13–v4.18 changelog + v4.18 RELEASE LINE** (2026-08-03): 89/89 ALL-PASS,
  four log gates green, enforce 41P/0F/0W, inflation 0/0/0/0. Tenant info deliberately omitted.

**Current: v4.19 — tenant-verified, ALL-PASS 92/92** (Vehicle 20 / Person 29 /
Firearm 10 / Article 8 / Boat 22), 33 combos, four log gates green, enforce 41 PASS / 0 FAIL / 0 WARN.

**Nothing owed to this ticket.** The v4.13–v4.18 gap was closed by comment 790861. The
per-version-comment format was collapsed to ONE consolidated comment at Rob's direction 2026-08-03
("it has become quite verbose and becomes tldr") — do not revert to a comment per version.
The parked `LIMITATION #38` VehicleMakeCode item is excluded from Jira by Rob's call and lives in
`knowledge-base/PLATFORM_CONSTRAINTS.txt`.

**JIRA CONSOLIDATION PASS 2026-08-11.** 10 superseded comments on this ticket were rewritten to one-line stubs, each pointing at comment 790861 (the current release line). The version history remains readable at comment 776220. Format for every future update is fixed by `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; there is no delete-comment tool, so superseded comments are stubbed, never removed.
