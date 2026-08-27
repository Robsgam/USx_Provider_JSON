# NM_NMLETS_OFML — DEX Ticket

**Active ticket:** [DEX-989 — \[NM - NMLETS_OFML\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-989)
Project: DEX (CJIS/USx/DEx Implementation) · Tenant: usx-nm-nmlets.mark43.com

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting "the
     version appears somewhere in this file" as evidence (every DEX_TICKET.md names its own current
     version, so that check could not fail). Format, exactly:
         POSTED: v<X.Y> comment <id> <YYYY-MM-DD>                                                -->


POSTED: v2.6 comment 803470 2026-08-21
POSTED: v2.7 comment 807336 2026-08-27
**Current: v2.7 — tenant-verified 2026-08-27, ALL-PASS 36/36** (Vehicle 6 / Person 19 / Firearm 5 /
Article 1 / Boat 5). Release line **comment 807336**; 803470 RETAINED as the v2.6 history, not
stubbed — one new comment per release (JIRA_COMMENT_TEMPLATE, rule reversed 2026-08-17: "post as a
new comment and leave the other comments there").
**JSON attached to DEX-989 and the provider catalog updated 2026-08-27 (Rob)** — ticket AND catalog
both on v2.7. Recorded here and in IMPORT_LEDGER section C rather than in the comment itself: the
template forbids tenant/attachment/catalog detail in the ticket body ("No host, no attachment note,
no catalog post"), because those belong to the ledger, which is their system of record.
v2.7 change: in-state plate searches stopped discarding LicensePlateTypeCode and LicensePlateYear,
and a multi-character middle name reached the state for the first time on this provider.
Prior: v2.6 — first-ever sweep of this provider at any version.

## History

This file was created 2026-08-21. Before that NM_NMLETS_OFML had **no DEX_TICKET.md at all**, which
is why `audit_lifecycle` reported stage 5 as "no DEX_TICKET.md" rather than as a gap against a known
ticket — the ticket existed (DEX-989, opened 2026-03-23) but the repo had never recorded the link.
Found by JQL search on the summary, not by guessing the number.

First release line posted 2026-08-21 as comment **803470** -- v2.6, TENANT-VERIFIED, ALL-PASS 36/36.
Nothing was superseded: there was no prior release line to name.
