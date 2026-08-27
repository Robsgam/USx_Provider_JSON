# OR_LEDS — DEX Ticket

**Active ticket:** [DEX-992 — \[OR - LEDS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-992)
Project: DEX (CJIS/USx/DEx Implementation) · Tenant: usx-or-leds.mark43.com

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting "the
     version appears somewhere in this file" as evidence (every DEX_TICKET.md names its own current
     version, so that check could not fail). Format, exactly:
         POSTED: v<X.Y> comment <id> <YYYY-MM-DD>                                                -->


**Current: v2.6 — tenant-verified 2026-08-27, ALL-PASS 27/27** (Vehicle 8 / Person 9 / Firearm 4 /
Article 1 / Boat 5). FIRST EVER tenant install and FIRST EVER sweep for this provider.

**NOTHING POSTED YET — there is no `POSTED:` line above on purpose.** The v2.6 release comment is
drafted and awaiting Rob's approval. Jira updates are HELD (2026-07-31) and the hold lifts one
provider at a time: Rob approved the NM_NMLETS_OFML post on 2026-08-27, and that approval does NOT
carry to this provider. `audit_lifecycle` STAGE 5 will report a GAP until the marker is written, and
that GAP is CORRECT — it is the absence of a post, not a missing record of one.

## How this ticket was found

This file was created 2026-08-27. Before that OR_LEDS had **no DEX_TICKET.md and no ledger row**, so
its ticket was recorded NOWHERE in the repo — the same state TN_TIES was in on 2026-08-24. It was
located the same way: JQL against the DEX project on the issue summary
(`summary ~ "LEDS" OR summary ~ "Oregon"`), which returned exactly one match.

DEX-992 was opened **2026-03-23**, is assigned to Rob, and sits in **Backlog** with **zero comments in
its entire history** — so the v2.6 release line, when approved, will be an *initial post*, not a
supersede. Section 1 of the comment must say "initial post" rather than naming a superseded id.

## History

v2.6 (2026-08-27) — Vehicle is the first card. OR_LEDS was the only provider of 20 opening on Person,
  and its own CAD_DISPATCH / FIRST_RESPONDER variants were already Vehicle-first, so only its default
  disagreed with itself. Layout only: every QUERYINPUTDATAMAPPING in both the OR_LEDS and RMS bundles
  is byte-identical to v2.5.
  Two weak tests were fixed BEFORE the first sweep rather than after it, both test data with no
  configuration impact — the middle-name fill (`A` -> `MICHAEL`, against a 30-char "Middle Name"
  control) and the plate-type toggle (`PC` -> `TK`, which had equalled the form default and therefore
  proved nothing). Both are wire-proven in the v2.6 logs.
  One-time tenant picklist capture completed the same day, also a first: 10 dropdowns across all five
  entities.
v2.5 and earlier — never installed on any tenant, never swept. See
  `docs/tracking/OR_LEDS_BUILD_NOTES.txt` for the per-version build history.
