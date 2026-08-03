# NJ_NJCJIS — DEX Ticket

**Active ticket:** [DEX-988 — \[NJ - NJCJIS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-988)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

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
- 2026-08-03 — comment 790914: **v4.15 changelog + RELEASE LINE** — 36/36 ALL-PASS, four log gates
  green, enforce 42P/0F/0W, inflation 0/0/0/0.

**Current: v4.15 — tenant-verified 2026-08-03, ALL-PASS 36/36** (Vehicle 11 / Person 8 / Firearm 6 /
Article 3 / Boat 8), four log gates green, enforce 42 PASS / 0 FAIL / 0 WARN.

> ⚠️ **A PRIOR CLAIM ON THIS TICKET IS NOW SUPERSEDED, deliberately.** Comment 771940 (v4.8,
> 2026-07-02) reports the Hull+Reg guardrail as "QBN — RegistrationNumber **absent** from wire".
> v4.15 reversed that on purpose: hull still wins the routing, but `RegistrationNumber` now rides in
> `QBN`'s `any[]` because NJ's devdoc BoatQuery #1 lists it as an optional on the hull combination.
> Silently dropping it was the defect. Wire-confirmed 2026-08-03. Do NOT "restore" the old behaviour
> by reading that older comment — and do not read it as a regression.

**Nothing owed to this ticket.** The v4.15 gap was closed by comment 790914. One consolidated comment
per release, not one per version (Rob 2026-08-03: the per-version format "becomes tldr").
