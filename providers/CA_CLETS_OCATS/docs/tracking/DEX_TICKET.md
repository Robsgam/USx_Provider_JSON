# CA_CLETS_OCATS — DEX ticket

**Ticket: [DEX-980](https://mark43.atlassian.net/browse/DEX-980) — "[CA - OCATS] USx Provider Build"**
Opened 2026-03-23 by Gordon Hallof · project DEX (CJIS/USx/DEx Implementation) · label `USx` ·
**unassigned** · **status `Blocked`**

**Current: v2.8 — NOT imported, NEVER tenant-tested (0 logs at any version).**

## ⚠️ THE TICKET STATUS IS `Blocked`, AND THAT IS NOT LIKE THE OTHERS

Every other provider ticket found so far sat in **Backlog** or **In Progress**. DEX-980 is
explicitly **`Blocked`** (Jira status id 10500, "Task is blocked", category To Do). **This repo does
not know why**, and nothing in it records a reason — the status was read from Jira on 2026-09-01, not
inferred. Raised for Rob **before** the import, because if the block is external (CLETS approval, an
agency dependency, an OCATS-side prerequisite) then importing and sweeping may be premature no matter
how clean the build is. The build being ready and the *engagement* being ready are different facts.

## How this ticket was found (2026-09-01)

This file did not exist, and DEX-980 was recorded **nowhere in the repo** — no `DEX_TICKET.md`, no
`JIRA_REFERENCE.txt` entry, and `audit_provider_uniformity` reported `DEX_TICKET.md present on 6/7,
MISSING on: CA_CLETS_OCATS` when OCATS was compared against the finished providers. Located by JQL
against the DEX project (`summary ~ "OCATS" OR summary ~ "CLETS"`), which returned four issues; only
one is an OCATS provider build. The others are **DEX-976** (CA_CLETS, already recorded) and
**DEX-176 / DEX-184** (Mariposa County SO foundation-tenant and CLETS-certification tickets from 2024,
both Done and unrelated to a provider JSON).

Same hole MD_METERS (DEX-987), TN_TIES (DEX-994), NM_NMLETS_OFML (DEX-989) and OR_LEDS (DEX-992) were
in — all opened 2026-03-23 and unrecorded until someone went looking.

## Jira posting status

**NOTHING HAS BEEN POSTED TO DEX-980. It has zero comments.** Verified from the ticket, not assumed.

Jira updates are **HELD** (2026-07-31) and the hold lifts **one provider at a time** — an approval for
another provider never carries. There is also **nothing to post yet**: a release line reports
tenant-verified counts and OCATS has none. `audit_lifecycle` stage 5 correctly reports this provider
as *not yet due* rather than as a GAP, because it is not tenant-verified.

When a release line is eventually approved, post as a NEW comment (2026-08-17 reversal: *"post as a
new comment and leave the other comments there"*), then record here, flush-left:

    POSTED: v<X.Y> comment <id> <YYYY-MM-DD>

That structured marker is what `audit_lifecycle` reads. It exists because the stage-5 check used to be
`-match "v$ver"` over the whole file, which could never fail — every ticket file names its own current
version — and on 2026-08-14 it reported PASS while three providers were genuinely behind. The comment
ID is the one fact the repo cannot derive from itself.

## History

No version of CA_CLETS_OCATS has ever been installed on a tenant or swept, so there is no history to
anchor. A history-anchor comment would enumerate build-only versions and tell a reader nothing — the
same call made for OR_LEDS and MD_METERS.
