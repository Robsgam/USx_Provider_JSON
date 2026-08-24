# CA_CLETS — DEX Ticket

**Active ticket:** [DEX-976 — \[CA - CLETS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-976)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting a version
     mention. Never write one in advance and never let a sync tool generate one.
     THE VERSION A COMMENT CARRIES IS MUTABLE. Under the edit-in-place rule the SAME comment id is
     rewritten to a newer version, so this marker must be updated on every in-place EDIT, not only
     when a new comment is created -- and the date is the EDIT date, not the creation date.
     Corrected 2026-08-14: this first read "v2.23 ... 2026-08-04", backfilled from the history line
     below, which records what 791400 said WHEN CREATED. The live comment reads "CA_CLETS v2.24 --
     TENANT-VERIFIED ... Extended in place from v2.23 to v2.24 ... RELEASE LINE -- v2.24 is verified
     and ready". Verified against Jira, not this file. -->
POSTED: v2.25 comment 791400 2026-08-17
POSTED: v2.26 comment 799898 2026-08-17
POSTED: v2.27 comment 804798 2026-08-24

POSTING RULE (**REVERSED 2026-08-17 by Rob**): **ONE NEW COMMENT PER RELEASE. Do NOT edit the previous
release line -- leave it in place.** Rob: *"post as a new comment and leave the other comments there. we
can't keep erasing the previous posts everytime."* The 08-11 edit-in-place rule was written against a
real defect (this ticket once carried TEN contradictory log counts) but its cost was worse: there is no
delete-comment tool and an edit is IRREVERSIBLE, so every release silently destroyed the previous
release's evidence -- 791400 was overwritten v2.23 -> v2.24 -> v2.25 before this. A rule whose safety
depends on remembering a manual archive step before an irreversible action is not safe.
**WHAT REPLACES THE PROTECTION:** every new release comment must name the comment id it SUPERSEDES and
state that the old one is retained as history (see 799898). That keeps the audit trail and still leaves
current state unambiguous. Stubbing is now for cleanup passes only, not the normal release flow.
Superseded wording, kept for context: "ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move -- never post a correction as a sibling comment." That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

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

**Current: v2.27 - tenant-verified, ALL-PASS 99/99** (Vehicle 22 / Person 43 / Firearm 13 /
Article 10 / Boat 11), four log gates 99/99, inflation 0/0/0/0, 27 combos all reachable,
validator 79P/0F/0W, enforce 46 PASS / 0 provider-scoped FAIL-or-WARN.
Release line posted as NEW comment **804798** on 2026-08-24, naming 799898 (v2.26) as superseded
and RETAINED as history -- per Rob's 2026-08-17 reversal of the edit-in-place rule.
v2.27 removed `LicensePlateYear` from `IA.QV`'s any[] and defaults[]: in-state plate searches were
transmitting an unconditional assertion that the plate's registration year is the current one.
Wire-proven surgical -- across all 99 logs `<LicensePlateYear>` appears on exactly the four
`NLTS.RQ.P` requests (where metadata mandates it) and on none of the 8 `IA.QV` requests, while the
`IA.QV` fill-map still carries the prefill. The form did not change; the combination did.

> NOTE 2026-08-24: this "Current" block had read **v2.25** ever since 791400, i.e. it was never
> updated when v2.26 was posted as comment 799898 on 2026-08-17. The POSTED: markers above were
> correct throughout, which is why `audit_lifecycle` stage 5 stayed green -- that gate reads the
> structured marker, not this prose. Prose under a gated marker can still rot; the marker is the
> authority, this block is the summary.

> ⚠️ **THE v2.22 RELEASE LINE ON THIS TICKET WAS GREEN AND WRONG.** Comment 787391 reports v2.22
> ALL-PASS; it passed 90/90 on three of the four log gates while shipping a request the metadata
> calls invalid. v2.23 fixed four wire defects it did not surface -- the `IG.QGH` split (a Name-only
> gun query was accepted and SENT), `IR.QVC.OS` (an OLN+SSN search routed to `ID.L1`, which defines
> no optionals, so the officer's SSN was accepted and NEVER TRANSMITTED), `NLTS.DQ.N` SexCode, and
> the `IR.QVC.C` age over-send. Do not treat the v2.22 comment as evidence of correctness. This is
> the case that motivated the fourth log gate and `audit_buildnotes_fidelity`.

**Nothing owed to this ticket.** The v2.23 gap was closed by comment 791400. One consolidated comment
per release, not one per version (Rob 2026-08-03: the per-version format "becomes tldr").

**JIRA CONSOLIDATION PASS 2026-08-11.** 17 superseded comments on this ticket were rewritten to one-line stubs, each pointing at the current release line. The version history remains readable at comment 783180. Format for every future update is fixed by `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; there is no delete-comment tool, so superseded comments are stubbed, never removed.
