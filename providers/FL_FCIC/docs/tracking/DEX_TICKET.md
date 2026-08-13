# FL_FCIC — DEX Ticket

**Active ticket:** [DEX-971 — \[FL - FCIC\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-971)
Project: DEX (CJIS/USx/DEx Implementation) · Status: In Progress (reopened 2026-06-25)

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

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
  · ⚠️ **superseded** — those 118 logs were archived by later bumps; stubbed 2026-08-11
- comment 790815 — **THE LIVE RELEASE LINE.** Created 2026-08-03 as v7.13–v7.18; extended
  IN PLACE to **v7.13–v7.23** on 2026-08-13 (110/110 ALL-PASS). Never post a sibling —
  edit this comment. Only TWO comments on this ticket are live: 767875 (history anchor)
  and 790815; the other 14 are stubs from the 2026-08-11 consolidation pass.

**Current: v7.23 — TENANT-VERIFIED 2026-08-12, ALL-PASS 110/110** (Vehicle 20 / Person 21 / Firearm
15 / Article 16 / Boat 38), four log gates 110/110, enforce 42 PASS / 0 provider-scoped FAIL-or-WARN,
30 combos all reachable. **Lifecycle CLOSED 2026-08-13:** release line posted (comment 790815, edited
in place), JSON attached to DEX-971, posted to the catalog, and imported to Miami Springs + North
Miami Foundation — all recorded in `providers/IMPORT_LEDGER.md` B and C. What v7.23 changed: Firearm row re-order (Gun Make drops to the first cell of row 2, directly beneath the Serial Number it qualifies; NCIC Image takes the row-1 slot it vacated — still 2 visible rows) **and NCIC Image now defaults to `Y` on all five entities** — 5 form controls plus all 25 combo `defaults[]`, because CAD ignores form `initialValue` and a form-only flip would leave every CAD-originated query still asking `N`. Safe on this provider, measured before applying: `ImageIndicator` sits in **0** `set[]` and **0** conditions across all 36 combinations, so no prefill can move routing (reachability 30/30 and prefill-shadow 92 pairs 0 FAIL, both unchanged from v7.20); and FL's devdoc carries no "must be filled if ImageIndicator = Y" conditional, so the TX_TLETS T6 class does not apply. **⚠️ One consequence is Rob's to rule on and is NOT silenced:** `audit_cross_provider` hard-codes `Vehicle ImageIndicator initialValue='N'`, so FL now carries a permanent `[WARN] ... (expected 'N')`, and a 20-provider measurement shows every provider used Person=`Y` with the other entities=`N` — FL is now the sole exception. The other 19 are flagged `[FLAG:ncic-image-default-y-everywhere]` to take it at their own rebuilds rather than being mass-rebuilt. **Also open, deliberately not fixed:** FL's raw metadata `<Any>` for **FBQ** does not define `ImageIndicator`, yet all four built FBQ combos carry it in `any[]` with a `defaults[]` entry — a genuine OVER-PERMIT that `audit_requirement_fidelity` cannot see because the field is on its `$formOnly` whitelist (so its "0 OVER-PERMITTED / 30 branches" is true about a question it does not ask). Pre-existing since v7.6 and tolerated on the wire at v7.18. Prior: **v7.20** — cosmetic/layout pass on Rob's rendered-form review, **zero wire change**: four rows retired (Vehicle VIN-Seq joins the Decal row; Firearm 2 visible rows; Article Serial+Type+OAN on top with the rest combined below; Boat State/Stolen/NCIC Image moved up under the identifier row). DH State relabelled `Destination State (required, not FL)` — the label had to carry BOTH facts, since "State (required)" invites the one destination FCIC says KQ cannot take. **Two requested items were refused by the sources and measured rather than argued:** an FL default on DH State (FCIC 2026-06-12: KQ requires "the destination to be something other than FL"), and a Boat Stolen Check default (injected into a replica → `[FAIL] 4 dead combination(s) of 30 checked` — FBQ Hull/Reg self-unsatisfiable and QB shadowing BQ Hull/Reg; I had predicted 2). Gates: validator 91P/0F/0W, verify_build 0W/0F, wiring closure closed 0/10, prefill-shadow 92 pairs 0 FAIL, `audit_layout_flow` 4 findings → 1 (that one verified PRE-EXISTING by re-running the gate against v7.19 from git). Prior: **v7.19 — BUILT then superseded before any sweep;** Stolen Check defaults to 'Y' on Firearm + Article (form default AND the combo defaults[] CAD twin), Boat deliberately excluded for the discriminator reason measured above. Prior: **v7.18 — tenant-verified, ALL-PASS 116/116** (Vehicle 20 / Person 21 /
Firearm 15 / Article 16 / Boat 44), four log gates green, enforce 41P/0F/0W. Covers v7.13 FBQ hull
RegistrationNumber, v7.14 FRQ over-permit removal, v7.15 Requestor, v7.16
RelatedHitSearchIndicator + VINSequenceNumber, v7.17 dead-control removal.

**Owed to the ticket: NOTHING.** v7.23 is posted (790815, edited in place 2026-08-13). This line
previously read "the v7.13–v7.17 changelog + v7.17 release line owed" and was **wrong** — that range
had already been posted and extended to v7.18 on 2026-08-11, and this file never recorded 790815 at
all. That is the second time this file has misstated what the ticket owes, so: **read the ticket
(`getJiraIssue DEX-971`, fields: comment) before answering the question, every time.**

The comment is now FOUR sections (Rob 2026-08-13 — the six-section shape was "way too many details").
"Known limits" and "Documented skips" are no longer posted; that content lives in
`knowledge-base/PLATFORM_CONSTRAINTS.txt` and `FL_FCIC_ACCEPTED_DIVERGENCES.txt`, which own and gate
it. The parked `LIMITATION #38` VehicleMakeCode item stays **excluded** from Jira (Rob's call).

**JIRA CONSOLIDATION PASS 2026-08-11.** 14 superseded comments on this ticket were rewritten to one-line stubs. FL carried FOUR mutually exclusive ALL-PASS claims -- 121/121, 118/118, 117/117, 116/116 -- so each of those stubs NAMES the count it was corrected to rather than saying only "superseded". Comment 767877 additionally states that its version (v6.7) NEVER SHIPPED, so nobody hunts for logs that cannot exist. History remains readable at comment 767875. Format for every future update is fixed by `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; there is no delete-comment tool, so superseded comments are stubbed, never removed.
