# TN_TIES — DEX Ticket

**Active ticket:** [DEX-994 — \[TN_TIES\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-994)
Project: DEX (CJIS/USx/DEx Implementation) · Status (verified 2026-08-24): **Backlog** · Unassigned

POSTING RULE — read this before adding anything:
  * **POST A NEW COMMENT PER RELEASE. Do NOT edit the previous release line** — leave it as history.
    Rob 2026-08-17: "post as a new comment and leave the other comments there. we can't keep erasing
    the previous posts everytime." There is NO delete-comment tool and an edit is IRREVERSIBLE, so
    edit-in-place silently destroyed each prior release's evidence.
  * **FOUR sections, not six** (Rob 2026-08-13 — six was "way too many details"). Known limits and
    documented skips are NOT in the comment; they live in `PLATFORM_CONSTRAINTS.txt` and
    `TN_TIES_ACCEPTED_DIVERGENCES.txt`, which already own and gate them.
  * Every new release comment must name the comment id it SUPERSEDES and say the old one is retained.
Format is FIXED: `knowledge-base/JIRA_COMMENT_TEMPLATE.txt` (two shapes — one release line, one
history anchor). Only automation-authored (🤖) comments may ever be edited: never Rob's own notes,
never a third party's. Do NOT judge authorship by displayName — the automation posts under his account.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-994`
> (cloudId `5ba7ec1f-1b3f-4b21-a2f2-5d04d124de2c`). `audit_lifecycle` (enforce 2r) READS THIS FILE,
> NOT THE TICKET — it can PASS on a lie and FAIL on the truth, which is why the marker below carries
> a comment ID (the one fact the repo cannot derive from itself) rather than a version number.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Those live in `providers/IMPORT_LEDGER.md` sections B and C.

POSTED: v2.6 comment 804754 2026-08-24   (HISTORY ANCHOR, v1.0 → v2.6)
POSTED: v2.6 comment 804755 2026-08-24   (RELEASE LINE)

**HOW THIS TICKET WAS FOUND, because it was recorded nowhere in the repo.** TN_TIES had no
DEX_TICKET.md, no row in `IMPORT_LEDGER.md`, and no entry in `knowledge-base/JIRA_REFERENCE.txt` —
the same position NM_NMLETS_OFML was in on 2026-08-21. Located by JQL against project DEX on
2026-08-24: `summary ~ "TIES" OR summary ~ "Tennessee" OR summary ~ "TN"` returned six issues, of
which exactly one is a provider build — **DEX-994 "[TN_TIES] USx Provider Build"**, created
2026-03-23, whose description names the tenant `https://USx-TN-TIES.MARK43.COM`. The other five are
THP support tickets (DEX-1061, DEX-789, DEX-505, DEX-9, DEX-8) and must not be confused with it.
The ticket had **ZERO comments in its entire history** before 2026-08-24, so 804754/804755 are the
first two and there was nothing to supersede.

**Current: v2.6 — TENANT-VERIFIED 2026-08-24, ALL-PASS 67/67** (Veh 19 / Per 36 / Gun 4 / Art 1 /
Boat 7), four log gates 67/67 each, inflation 0/0/0/0, 21 CommSys combos 100% covered, validator
73P/0F/0W, enforce 46 PASS / 0 FAIL / 0 WARN. **First-ever tenant sweep for this provider.**
The release change: an in-state plate search no longer transmits `LicensePlateTypeCode`. The control
is prefilled `PC` because `RQ.P` (out-of-state) requires it, so every in-state query had been
asserting "passenger automobile" — for a motorcycle, trailer or commercial plate too. Neither devdoc
#1 nor metadata `RQ01` defines that field; the permission came from `QV{plate}`, a DATA-MINED NCIC
variant. **Proven both directions:** in-state wires carry no plate type, `RQ.P` wires still do — so a
combination was narrowed, not a field broken. And proven surgical: against the archived v2.5 captures,
**64 wires byte-identical / 3 changed / 0 new**, the 3 being every wire of the one combination
touched.
Also first-proven here: dealer plate, handicap placard and temporary plate (three of seven vehicle
searches that had **no test value**, so their tests carried blank fills and could never have been
driven), `InquiryTypeIndicator` in both states, `ExpandedNameSearchCode`, and `PurposeCode=C` on the
KQ driver-history combos but on **no** `DQ05` wire — the distinction a form prefill would have
destroyed by collapsing `KQ.O` onto `DQ05`.
Release line **comment 804755**; **804754** is the history anchor.
