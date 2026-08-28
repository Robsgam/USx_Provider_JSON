# MD_METERS — DEX ticket

**Ticket: [DEX-987](https://mark43.atlassian.net/browse/DEX-987) — "[MD - METERS] USx Provider Build"**
Opened 2026-03-23 · status **Backlog** · project DEX

**Current: v2.3 — tenant-verified ALL-PASS 5/5 (46 logs, 46 PASS / 0 FAIL) on 2026-08-28.**

## How this ticket was found (2026-08-28)

This file did not exist, and DEX-987 was recorded **nowhere in the repo** — no `DEX_TICKET.md`, no
`IMPORT_LEDGER.md` row, no `JIRA_REFERENCE` entry. It was located by JQL against the DEX project
(`summary ~ "METERS" OR summary ~ "Maryland"`), which returned **exactly one** issue, so there was no
ambiguity to resolve. Same hole TN_TIES (DEX-994), NM_NMLETS_OFML (DEX-989) and OR_LEDS (DEX-992) were
in — all four tickets were opened 2026-03-23 and sat untouched.

## Jira posting status

**NOTHING HAS BEEN POSTED TO DEX-987. It has zero comments.**

Jira updates are **HELD** (2026-07-31) and the hold lifts **one provider at a time** — an approval for
another provider never carries. A v2.3 release line has been DRAFTED and is awaiting Rob's approval;
it is not posted, and `audit_lifecycle` stage 5 will keep reporting a GAP until it is. That GAP is
correct and expected, not an oversight.

When approval is given, post as a NEW comment (do not stub or edit existing ones — the 2026-08-17
reversal: *"post as a new comment and leave the other comments there"*), then record here:

    POSTED: v2.3 comment <id> 2026-08-28

That structured marker is what `audit_lifecycle` reads. It exists because the stage-5 check used to be
`-match "v$ver"` over the whole file, which could never fail — every ticket file names its own current
version — and on 2026-08-14 it reported PASS while three providers were genuinely behind. The comment
ID is the one fact the repo cannot derive from itself.

## History

No prior version of MD_METERS was ever installed on a tenant or swept, so there is no history to
anchor: v2.3 is the first build to reach a tenant. A history anchor comment would enumerate
build-only versions and tell a reader nothing — the same call made for OR_LEDS on 2026-08-28.
