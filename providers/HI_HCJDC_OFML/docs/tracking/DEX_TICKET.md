# HI_HCJDC_OFML — DEX Ticket

**Active ticket:** [DEX-1257 — \[HI - HI_HCJDC_OFML\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-1257)
Project: DEX (CJIS/USx/DEx Implementation) · Status (2026-08-04): In Progress

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting a version
     mention. Never write one in advance and never let a sync tool generate one.
     v4.16-v4.18 are NOT here because they are NOT posted -- the absence IS the record. -->
POSTED: v4.18 comment 795241 2026-08-14
POSTED: v4.20 comment 799997 2026-08-17

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-1257`
> (fields: comment; cloudId `5ba7ec1f-1b3f-4b21-a2f2-5d04d124de2c`). It is ~51k chars and blows the
> tool-result limit: fetch it, then parse the saved result for comment ids / versions rather than
> reading it whole.
>
> **THIS FILE HAS ALREADY LIED ONCE.** Until 2026-08-04 it stopped at comment 783015 (v4.11) while
> the ticket carried three more — v4.12 (786501), v4.13 (786580) and a full **v4.14 ALL-PASS release
> line** (787024, 2026-07-28). Read from the file, HI looked like it owed three changelogs plus a
> first release line; read from the ticket, it owed one short re-verification note. The equivalent
> file on FL produced a confidently wrong "nine versions owed" the same way.
>
> **`audit_lifecycle` (enforce 2r) READS THIS FILE, NOT THE TICKET** — it can PASS on a lie and FAIL
> on the truth. A 2r GAP means "check both".
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C.

**Posted so far** (indexed from the ticket 2026-08-04 — 16 comments, all accounted for):
- 767719 / 767758 / 767834 (2026-06-25) — initial changelog dump; v4.5 changelog; v4.5 release line.
- 768556 (06-26) v4.6 · 769522 (06-29) testing-tier clarification · 771643 + 772055 (07-02) v4.7 +
  its process-validation re-run · 780048 (07-15) v4.8 · 781296 (07-17) v4.9 · 782246 (07-20) v4.10.
- 782806 + 783015 (07-21) — v4.11 Firearm CAD fix (`GunSerialNumber`->`serialNumber`) changelog, then
  its RELEASE LINE (12/12 combos, both PHASE 6 gates 45/45, enforce 27P/0F/0W).
- 786501 (07-27) v4.12 relabel · 786580 (07-27) v4.13 Boat stolen-label + uppercase titles.
- **787024 (07-28) — v4.14 changelog + RELEASE LINE**, 46/46 ALL-PASS, two log gates, enforce 31P.
- **791589 (2026-08-04) — v4.14 RE-VERIFICATION.** Same version, re-swept from scratch on Rob's call
  after the build process changed; package reset first so all 46 captures are fresh. **Four** log
  gates now (content 46/46, metadata 46/46, combo attribution 46/46, plan completeness 5/5), enforce
  44P/0F/0W, inflation 0/0/0/0. Carries the wire evidence for the two layout claims: DL/DH genuinely
  independent (`State=GA` on DL vs `State=NJ` on DH, same session, both -> canonical `<State>`), and
  OLN>Name holding separately on each card.

**Current: v4.15 — TENANT-VERIFIED 2026-08-10, ALL-PASS 46/46.**
DEX-1283 Attention `'X'` removal: dropped `initialValue='X'` from the hidden DH gate-feeder and
`Attention='X'` from both KQ/KQN combo `defaults[]` (`PurposeCode='C'` kept). The control, its
`any[]` membership and the `CommsysGetLastNameFirstNameInitialRuleHandler` attribute are unchanged —
only the literal value went. HI was the last provider still prefilling it; FL/TX/CA_CLETS/NY all run
the same handler with no prefill and resolve the officer name on 38/38 DH wires. Gates: validator
65P/0F/0W, verify clean, fidelity 14 branches 0/0, 0 prefill-dead, gate efficacy 8/8, enforce
40 PASS / 0 HI-scoped FAIL-or-WARN.
**The discriminating observation CAME BACK POSITIVE, 9 of 9.** Every KQ/KQN wire carries
`<Attention>SGAMBELLONE R</Attention>` with no `initialValue` and no combo default anywhere in the
JSON; zero logs carry a literal `X`. The `any[]` membership alone feeds the handler — v2.9's
gate-feeder claim is now refuted on HI's own wires rather than inferred from the other four
providers. Control: the DL side emits no `<Attention>` element at all, so the field is genuinely
DH-scoped and does not leak through the shared pool.
Gates: four log gates 46/46 (content, metadata, attribution, plan completeness 5/5), inflation
0/0/0/0, enforce 43 PASS / 0 HI-scoped FAIL-or-WARN, validator 65P/0F/0W.
**Stated limit — do NOT overclaim it on the ticket:** the CAD path is verified by inspection only.
Removing `Attention='X'` from KQ/KQN `defaults[]` is precisely the half no form-driven log can
exercise, and DEX-1283's second symptom ("not present when you do it from a CAD event") is that
path.

**POSTED 2026-08-10 — comment 795241: v4.15 changelog + RELEASE LINE** (approved by Rob, "do both").
Carries the 9/9 Attention evidence, the v2.9-was-confounded explanation, the DL-side control
observation, and the CAD-is-inspection-only limit stated rather than glossed. Also notes the SQVR
corrections and the gate fix behind them. Rob attached the v4.15 JSON and updated the catalog in the
same pass — recorded in `IMPORT_LEDGER.md` section C, deliberately NOT on the ticket.

**Nothing owed to this ticket.**

**Prior: v4.14 — tenant-verified twice (2026-07-28, re-verified 2026-08-04), ALL-PASS 46/46**
(Vehicle 16 / Person 14 / Firearm 6 / Article 3 / Boat 7), four log gates green, enforce 44P/0F/0W.

(v4.14 itself: nothing owed — its changelog and both release lines are posted, 787024 + 791589.)

**Note:** [DEX-983](https://mark43.atlassian.net/browse/DEX-983) ("\[HI - HCJDC-OFML\]") is an
older **duplicate**, marked Done — do NOT post there. Use DEX-1257.

**JIRA CONSOLIDATION PASS 2026-08-11.** 15 superseded comments on this ticket were rewritten to one-line stubs, each pointing at comment 795241 (the v4.15 release line). The version history remains readable at comment 767719. Format for every future update is fixed by `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`; there is no delete-comment tool, so superseded comments are stubbed, never removed.
