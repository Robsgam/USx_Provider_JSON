# FL_FCIC — DEX Ticket

**Active ticket:** [DEX-971 — \[FL - FCIC\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-971)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress (reopened 2026-06-25)

Post the changelog here on every version bump (dump first, then per-version diff, led by the
🤖 auto-update attribution line; release line after that version's live testing passes).

> **THIS FILE IS NOT THE TICKET — read the ticket.** On 2026-08-03 it listed nothing past v7.8, so
> "what does FL owe Jira?" was answered as *nine versions owed, last posted v7.8*. Wrong: the ticket
> was current through **v7.12 including a v7.12 ALL-PASS release line**, and only five versions were
> owed. Verify against `getJiraIssue DEX-971` (fields: comment) before stating what is owed.
>
> **Distribution facts are INTERNAL (Rob 2026-08-03)** — JSON attached to the ticket, posted to the
> catalog, Foundation imports. Track them in `providers/IMPORT_LEDGER.md` (sections B and C).
> **Do NOT put them in a Jira comment.**

**Posted so far:**
- comment 767875 — initial full changelog dump (2026-06-25)
- comment 767877 — v6.7 changelog (superseded by v6.8 before testing began)
- comment 769437 — v6.8 changelog (VehicleMakeName QRDM source fix, RND-62365)
- comment 769601 — v7.0 + v6.9 (OOS-gate symmetry; Boat Hull>Reg extended to QB/BQ)
- comment 770030 — v7.1 changelog **+ release line** (FBQ Hull>Reg completed; all 5 entities PASS)
- comment 772088 — v7.1 zero-error pass (121/121 captured; 2 harness defects found + fixed)
- comment 782269 — v7.7 re-test complete (toggle-fix cycle; 118/118)
- comment 782805 — v7.8 Firearm CAD fix (GunSerialNumber → serialNumber) changelog
- comment 782839 — v7.8 **RELEASE LINE** (30/30 combos, 117/117 logs, enforce 25P/0F/0W)
- comment 786470 — v7.9 DEX-1284 relabel/naming pass (built; re-test pending)
- comment 786577 — v7.10 UPPERCASE card titles (no functional change)
- comment 786730 — v7.11 UI/label-review pass (4 cosmetic fixes)
- comment 786812 — v7.12 entity display-order change (Person-first → Vehicle-first)
- comment 786864 — v7.12 **RELEASE LINE** (118/118 ALL-PASS, both log gates green)
  · ⚠️ **superseded by v7.17** — those 118 logs were archived by the v7.13–v7.17 bumps

**Current: v7.17 — tenant-verified 2026-08-03, ALL-PASS 116/116** (Vehicle 20 / Person 21 /
Firearm 15 / Article 16 / Boat 44), four log gates green, enforce 41P/0F/0W. Covers v7.13 FBQ hull
RegistrationNumber, v7.14 FRQ over-permit removal, v7.15 Requestor, v7.16
RelatedHitSearchIndicator + VINSequenceNumber, v7.17 dead-control removal.

**Owed to the ticket:** the v7.13–v7.17 changelog + v7.17 release line, as ONE consolidated comment
(the per-version format is what made this thread TLDR — Rob 2026-08-03). Drafted and approved-pending;
the parked `LIMITATION #38` VehicleMakeCode item is deliberately **excluded** from Jira (Rob's call)
and lives in `knowledge-base/PLATFORM_CONSTRAINTS.txt` instead.
