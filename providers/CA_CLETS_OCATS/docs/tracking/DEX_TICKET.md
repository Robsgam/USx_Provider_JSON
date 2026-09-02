# CA_CLETS_OCATS — DEX ticket

**Ticket: [DEX-980](https://mark43.atlassian.net/browse/DEX-980) — "[CA - OCATS] USx Provider Build"**
Opened 2026-03-23 by Gordon Hallof · project DEX (CJIS/USx/DEx Implementation) · label `USx` ·
**unassigned** · **status `Blocked`**

**Current: v2.12 — BUILT 2026-09-02, NOT IMPORTED, NOT TENANT-VERIFIED.**

## ⛔ JIRA DEFERRED BY ROB, 2026-09-02 — AND THE v2.11 DRAFT BELOW IS WITHDRAWN

Rob: *"rebuild ocats and defer the jira until we have a solid josn."* Both halves are instructions.

**The v2.11 release line drafted further down MUST NOT BE POSTED.** It is superseded, and it was
never merely stale — it describes a build carrying a **real over-permit**: `RQ.P` transmitted
`VehicleMakeCode` and `vehicleYear` on out-of-state plate searches, which metadata
`RQ{LicensePlateNumber}` (`<Any>` = `[State, LicensePlateTypeCode]`) does not define. Fixed at
v2.12. Had Jira not been held, that comment would have certified a defective JSON as verified —
which is the entire reason the hold exists. It is kept below as HISTORY, not as a queued action.

**Nothing is owed to this ticket until v2.12 is imported and re-swept**, at which point a NEW
release line is drafted from scratch and awaits its own approval. Approval never carries — not from
MD_METERS, and not from this ticket's own earlier draft.

**Cost of the rebuild, stated plainly:** the v2.11 ALL-PASS package (65 logs, 65 PASS / 0 FAIL) is
archived to `logs/<Entity>/_archive_pre_v2.12/`. CA_CLETS_OCATS is **no longer ALL-PASS** and is
**no longer lifecycle-complete-eligible** until re-imported and re-swept (65 tests).

Ticket state as last read from Jira (2026-09-02): **`In Progress`** — it had been `Blocked`, and
moved at 2026-09-01 16:37 ET; **0 comments**; unassigned; reporter Gordon Hallof.

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
another provider never carries. MD_METERS was approved on 2026-08-31 for MD_METERS ONLY.

**As of 2026-09-01 there IS something to post** — v2.11 is tenant-verified — so `audit_lifecycle`
stage 5 now reports a real `[GAP]` rather than *not yet due*. That GAP is correct and must stay open
until Rob approves. **Two things need his decision, and they are separate:** (1) the comment body
below, and (2) whether a ticket in **`Blocked`** status should receive a release line at all — the
repo still does not know why it is blocked.

## DRAFT RELEASE LINE — v2.11 — AWAITING APPROVAL, NOT POSTED

Four sections per `knowledge-base/JIRA_COMMENT_TEMPLATE.txt`. Every number tool-derived
(`report_test_status`, `audit_test_coverage`, VALIDATOR_REPORT, live `enforce`, `audit_log_inflation`).
No tenant/attachment/catalog detail — those live in `IMPORT_LEDGER.md` sections B and C (Rob,
2026-08-03).

    🤖 Auto-update from the ConnectCIC provider-JSON repo — generated from the build and
    gate artifacts (BUILD_NOTES, the four log gates, `audit_log_inflation`, `enforce`).

    **CA_CLETS_OCATS v2.11 — TENANT-VERIFIED**

    **1. Scope**
    Versions covered: v2.9–v2.11. Configuration changed: yes. Supersedes: initial post —
    this is the first comment on DEX-980.

    **2. Changed**
    - Article Type dropdown rendered EMPTY and is now populated: `ArticleTypeCode` paired
      `NCIC_ARTICLE_TYPE` with `codeTypeSource='CA_CLETS_OCATS'`, which resolves to no
      table, so the control offered zero options and could not be filled. Corrected to
      `codeTypeSource='CA_CLETS'`.
    - v2.9 (userId hidden + auto-populated, State taking over DL/Vehicle routing, devdoc
      Veh #1+#2 merged) was BUILT AND WITHDRAWN. v2.10 is byte-identical to v2.8. The
      CLETS User ID already travels in the transaction envelope, so hiding the field
      solved nothing and cost two devdoc combinations.
    - Test data only, no configuration impact: `userId` and `businessIndicator` gained
      values, recovering three built combinations (`AWVEHQ`, `VC`, `OCNAMQ`) that had no
      generated test at all and therefore could never have been driven.

    **3. Verified on the wire**
    Vehicle 25 / Person 18 / Firearm 5 / Article 10 / Boat 7 = 65
    Article Type reaches the wire for the first time — the driver opened the control and
    selected `BBICYCL - Bicycle` on all four Article tests that carry it, where v2.10
    offered an empty list. `firearmMake='IMI'` also selected live, which settles the
    picklist truncation WARN that could only ever be answered by a fill. All three
    identifier-priority guardrails held: plate over VIN, OLN over name, hull over
    registration number.

    **4. Gates**
    validator 66P/0F/0W · four log gates 65/65 (content, metadata, attribution, plan
    completeness 5/5) · inflation 0/0/0/0 · enforce 46 PASS / 0 provider-scoped
    FAIL-or-WARN · 21 combos, all reachable

    **RELEASE LINE — v2.11 is verified and ready.**

When a release line is eventually approved, post as a NEW comment (2026-08-17 reversal: *"post as a
new comment and leave the other comments there"*), then record here, flush-left:

    POSTED: v<X.Y> comment <id> <YYYY-MM-DD>

That structured marker is what `audit_lifecycle` reads. It exists because the stage-5 check used to be
`-match "v$ver"` over the whole file, which could never fail — every ticket file names its own current
version — and on 2026-08-14 it reported PASS while three providers were genuinely behind. The comment
ID is the one fact the repo cannot derive from itself.

## History

**v2.11 is the FIRST EVER tenant install and FIRST EVER sweep for this provider** (2026-09-01,
65 logs). Nothing before it was ever installed, so there is no superseded package and no prior
counts a reader could confuse with the current ones.

**No history-anchor comment is warranted** — the same call made for OR_LEDS and MD_METERS. An anchor
exists to stop a reader mistaking an old release line for current state, and DEX-980 has none: the
drafted v2.11 comment will be the ticket's first. Enumerating v2.1–v2.10 would list build-only
versions that never reached a tenant and tell a reader nothing.
