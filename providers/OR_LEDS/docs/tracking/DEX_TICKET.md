# OR_LEDS — DEX Ticket

**Active ticket:** [DEX-992 — \[OR - LEDS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-992)
Project: DEX (CJIS/USx/DEx Implementation) · Tenant: usx-or-leds.mark43.com

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting "the
     version appears somewhere in this file" as evidence (every DEX_TICKET.md names its own current
     version, so that check could not fail). Format, exactly:
         POSTED: v<X.Y> comment <id> <YYYY-MM-DD>                                                -->
POSTED: v2.6 comment 807713 2026-08-28


**Current: v2.6 — tenant-verified 2026-08-27, ALL-PASS 27/27** (Vehicle 8 / Person 9 / Firearm 4 /
Article 1 / Boat 5). FIRST EVER tenant install and FIRST EVER sweep for this provider.

**POSTED 2026-08-28 — comment 807713, the FIRST comment DEX-992 has ever carried.** Rob approved the
post explicitly ("post it and note that the jira ticket and catalog have been updated"); the Jira
hold (2026-07-31) lifts one provider at a time and his TX_TLETS approval the previous day did not
carry here. Section 1 says "initial post" rather than naming a superseded id, because there was no
prior release line to supersede — the correct shape for a ticket with no history.

The comment carries a closing line stating the ticket attachment and the catalog have been updated
to v2.6, at Rob's explicit direction. That is a DELIBERATE OVERRIDE of the template rule barring
catalog/tenant detail from tickets (JIRA_COMMENT_TEMPLATE.txt, "NO TENANT DETAIL ANYWHERE", Rob
2026-08-03) — the same override he directed on TX_TLETS the day before. Do not treat it as licence
to add such lines unprompted, and do not "correct" the posted comment.

NO HISTORY ANCHOR WAS POSTED, deliberately. The template defines a second one-per-ticket shape for
an initial version-history dump, and DEX-992 has neither shape. It was skipped because OR_LEDS has
no history worth anchoring: v2.5 and earlier were never installed on any tenant and never swept, so
a history anchor would list build-only versions and say nothing a reader needs. Raised with Rob
before posting; he approved the release line alone. If OR ever accumulates shipped versions, add the
anchor then and point it at the then-current release line.

STAGE 5 is now SATISFIED and OR_LEDS is LIFECYCLE-COMPLETE on all six stages.

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
