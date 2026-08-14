# NJ_NJCJIS — DEX Ticket

**Active ticket:** [DEX-988 — \[NJ - NJCJIS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-988)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting a version
     mention. Never write one in advance and never let a sync tool generate one. -->
POSTED: v4.15 comment 795856 2026-08-11

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-988`
> (fields: comment) before stating what is owed. Until 2026-08-03 this file indexed 2 comments while
> the ticket held 16 and was current through **v4.14**. On FL the same shape produced a confidently
> wrong answer ("nine versions owed" when it was five).
>
> **`audit_lifecycle` (enforce 2r) READS THIS FILE, NOT THE TICKET** — so it can PASS on a lie (file
> updated, nothing posted) and FAIL on the truth (posted, file stale). A 2r GAP means "check both".
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C. Note the
> ticket's OWN older comments do carry Newark import lines — that precedent is superseded.

**Posted so far** (older comments not all indexed; the ticket is authoritative):
- 2026-07-20 — comment 782204: initial changelog dump + v4.9 cosmetic-relabel release line
  (all 5 entities re-tested/blocked, enforce 28P/0F/0W). Bert Anzini USx test tenant note included.
- 2026-07-21 — comment 782803: v4.10 Firearm CAD fix (GunSerialNumber->serialNumber) changelog
  + RELEASE LINE — all 5 entities re-tested at v4.10 (35/35 logs verified, enforce 26P/0F/0W CLOSED).
- 2026-07-27 — comments 786485 / 786498 / 786578: v4.11 DEX-1284 relabel, v4.12 Person consolidated
  to ONE Driver License card, v4.13 UPPERCASE card titles.
- 2026-07-28 — comments 786904 / 786921: v4.14 layout pass (Vehicle 3 cards -> 1, Boat title
  enumerated) + **RELEASE LINE** 35/35 ALL-PASS, enforce 31P/0F/0W.
- 2026-08-03 — comment 790914: v4.15 changelog + release line at **36/36**. **SUPERSEDED by 795856**
  — its count was correct for the plan as it then stood, but the plan later grew to 40 tests.
- **2026-08-11 — comment 795856: v4.15 coverage extension + full re-verification, ALL-PASS 40/40.**
  **First comment written to the canonical template** (`knowledge-base/JIRA_COMMENT_TEMPLATE.txt`) —
  six fixed sections, so it is the reference example for the other six tickets.

**Current: v4.15 — tenant-verified 2026-08-11, ALL-PASS 40/40** (Vehicle 13 / Person 10 / Firearm 6 /
Article 3 / Boat 8), four log gates 40/40, inflation 0/0/0/0, enforce 43 PASS / 0 NJ-scoped FAIL-or-WARN.
No rebuild and no re-import: the JSON never changed, the **test plan** grew by four out-of-state
toggle tests that had never been generated, so NJ correctly read PARTIAL (36 of 40) until they were
captured. All four transmit `<State>AK</State>` and attribute to their expected keyRef, which proves
NJ carries out-of-state state as an `any[]` passenger on the same combination rather than forking to
a dedicated OOS keyRef the way FL and NY do.

> ⚠️ **A PRIOR CLAIM ON THIS TICKET IS NOW SUPERSEDED, deliberately.** Comment 771940 (v4.8,
> 2026-07-02) reports the Hull+Reg guardrail as "QBN — RegistrationNumber **absent** from wire".
> v4.15 reversed that on purpose: hull still wins the routing, but `RegistrationNumber` now rides in
> `QBN`'s `any[]` because NJ's devdoc BoatQuery #1 lists it as an optional on the hull combination.
> Silently dropping it was the defect. Wire-confirmed 2026-08-03. Do NOT "restore" the old behaviour
> by reading that older comment — and do not read it as a regression.

**Nothing owed to this ticket.** Closed by comment 795856 at full plan coverage.

**CONSOLIDATION PASS 2026-08-11.** NJ carried nine changelog comments and three mutually exclusive
completion claims (35/35, 36/36, 40/40 — each posted as final). All superseded comments on this
ticket are now one-line stubs pointing at 795856; the version history remains readable at 782204.
Two special stubs, because a generic "superseded" would have misled: **771940** states that its
Hull+Reg claim was *deliberately reversed* at v4.15 and must not be "restored", and **790914** names
36/40 as the count that was corrected rather than merely outdated. This ticket is why the
edit-in-place half of the posting rule exists.
