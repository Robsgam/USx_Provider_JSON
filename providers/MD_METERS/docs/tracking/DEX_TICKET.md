# MD_METERS — DEX ticket

**Ticket: [DEX-987](https://mark43.atlassian.net/browse/DEX-987) — "[MD - METERS] USx Provider Build"**
Opened 2026-03-23 by Gordon Hallof · status **In Progress** · project DEX (CJIS/USx/DEx Implementation) · Task / P3 / label `USx` · **unassigned** · tenant `https://usx-md-meters.mark43.com`

**Current: v2.4 — tenant-verified ALL-PASS 5/5 (47 logs, 47 PASS / 0 FAIL) on 2026-08-31.** v2.3 (46 logs) is
SUPERSEDED, its package archived to `logs/<Entity>/_archive_pre_v2.4/` and RETAINED as history.

**LIVE TICKET STATE READ FROM JIRA 2026-08-31 (not from this file): 0 comments, status In Progress.**
Three facts here were STALE or MISSING and were corrected from the ticket itself, which is why reading
it beat trusting the file: (1) this line said status **Backlog** — Jira says **In Progress** (ticket
`updated` 2026-08-28T14:12, the day of the v2.3 sweep); (2) the version was v2.3; (3) the ticket
DESCRIPTION carries the tenant URL `https://USx-MD-METERS.MARK43.COM`, and `IMPORT_LEDGER.md` had
carried `*URL not recorded — ASK*` for MD — the ONLY provider row missing one. Now recorded as
`usx-md-meters.mark43.com`, matching the portfolio convention.

**RESOLVED 2026-08-31 — the v2.4 comment is POSTED (808820); see "Jira posting status" below.** This
spot previously warned that the file CLAIMED a v2.3 release line "has been DRAFTED" while storing no
draft at all — it lived only in a chat turn and was gone. Kept as a note because the lesson outlived
the defect: **an approval-gated artifact that exists only in conversation does not survive the
session.** Draft into this file, or accept that it will be re-drafted from scratch.

## How this ticket was found (2026-08-28)

This file did not exist, and DEX-987 was recorded **nowhere in the repo** — no `DEX_TICKET.md`, no
`IMPORT_LEDGER.md` row, no `JIRA_REFERENCE` entry. It was located by JQL against the DEX project
(`summary ~ "METERS" OR summary ~ "Maryland"`), which returned **exactly one** issue, so there was no
ambiguity to resolve. Same hole TN_TIES (DEX-994), NM_NMLETS_OFML (DEX-989) and OR_LEDS (DEX-992) were
in — all four tickets were opened 2026-03-23 and sat untouched.

## Jira posting status

POSTED: v2.4 comment 808820 2026-08-31

**The FIRST comment this ticket has ever carried.** Posted 2026-08-31 14:00 EDT with Rob's explicit
approval for MD_METERS only — the Jira hold (2026-07-31) lifts ONE PROVIDER AT A TIME and this
approval does NOT carry to any other provider. Posted as a NEW comment per the 2026-08-17 reversal
(*"post as a new comment and leave the other comments there"*); nothing was stubbed or edited, because
there was nothing there to stub.

Content: the four-section release template (`knowledge-base/JIRA_COMMENT_TEMPLATE.txt`), every number
taken from a tool rather than from a conversation — `report_test_status` for the 47/47 entity split,
`audit_test_coverage` for the 14-combo count (NOT `audit_combo_reachability`'s "N checked", which runs
lower), `audit_log_inflation` for 0/0/0/0, and a live `enforce` for 46 PASS. Section 1 records
"Supersedes: initial post" and folds in v2.3's own tenant verification (46 logs, 2026-08-28), which was
never announced — otherwise that pass would appear nowhere on the ticket.

**Deliberately NOT in the comment:** no history anchor (v1.0–v2.2 are build-only; an anchor would
enumerate versions that never reached a tenant — same call as OR_LEDS 2026-08-28), and **no tenant,
attachment or catalog detail** per Rob 2026-08-03. The JSON-attachment and provider-catalog facts live
in `providers/IMPORT_LEDGER.md`, which is their system of record.

The marker above is what `audit_lifecycle` stage 5 reads. It exists because the stage-5 check used to
be `-match "v$ver"` over the whole file, which could never fail — every ticket file names its own
current version — and on 2026-08-14 it reported PASS while three providers were genuinely behind. The
comment ID is the one fact the repo cannot derive from itself.

**Next release:** post a NEW comment, name 808820 as the one it supersedes, and say 808820 is RETAINED
AS HISTORY. Do not edit 808820 — there is no delete-comment tool and an edit is irreversible.

ID is the one fact the repo cannot derive from itself.

## History

No prior version of MD_METERS was ever installed on a tenant or swept, so there is no history to
anchor: v2.3 is the first build to reach a tenant. A history anchor comment would enumerate
build-only versions and tell a reader nothing — the same call made for OR_LEDS on 2026-08-28.
