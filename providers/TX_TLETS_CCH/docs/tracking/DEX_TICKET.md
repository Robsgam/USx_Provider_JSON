# TX_TLETS_CCH — DEX ticket pointer

**No ticket of its own. It reports through its BASE: DEX-967 — [TX - TLETS] USx Provider Build**
https://mark43.atlassian.net/browse/DEX-967  (status `In Progress` as of 2026-09-04)

Recorded 2026-09-04. **The absence is VERIFIED, not assumed** — a JQL sweep of project DEX for
`summary ~ "CCH"` or `summary ~ "TLETS"` returns no CCH provider-build ticket. The only TX
provider-build ticket is DEX-967; the neighbouring TX rows are DEX-968 (dropdown information),
DEX-1282 (email handler) and a set of per-customer Denton/Pharr deployment items, none of which is
this provider.

That is the expected shape, not a gap: TX_TLETS_CCH is a **variant** declaring
`# BASE-SYNC: TX_TLETS`, and a variant inherits its base's devdoc, metadata and — since 2026-08-24
— its base's adjudications. Reporting through the base's ticket follows the same rule.

## Posted

None, and none is owed. **TESTING IS PARKED** (Rob, 2026-08-21) — marker at
`docs/tracking/TEST_PARKED.txt`. This provider was a proof of concept for building a base and its
variant in parallel; there is no tenant need. `report_import_owed` lists it as
*deliberately held, NOT owed*, and `portfolio_status` shows `PARKED (no test expectation)`.

**Do not list this provider as owing a Jira post, an import, or a sweep.** A parked provider cannot
reach lifecycle-complete, and `report_mission_status` excludes it from the eligible denominator
(19 of 20) for exactly that reason.

## What is NOT parked

**Lockstep with TX_TLETS is NOT parked.** When the base bumps, this variant must be re-synced and
its `# BASE-SYNC:` marker moved, and the base's registry rows for base-6 combinations must travel
with it — `audit_variant_sync` CHECK 1 gates the marker and CHECK 2 gates the adjudications. CHECK 2
exists because this provider once read `[PASS]` on a current marker while carrying a stale subset of
the base's ACCEPTED_DIVERGENCES: 8 base rows absent, 4 of them re-raising OVER-PERMITTED findings the
base had already closed against byte-identical metadata.

## Standing

Jira is HELD (2026-07-31). A release comment is DRAFT-AND-WAIT, every provider, every time, and no
approval carries. Being behind on Jira is the expected consequence of the hold, not owed work.
