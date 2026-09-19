# SC_SLED — DEX Ticket

**Active ticket:** [DEX-993 — "[SC - SLED] USx Provider Build"](https://mark43.atlassian.net/browse/DEX-993)
Project: DEX (CJIS/USx/DEx Implementation) · Tenant: **usx-sc-sled.mark43.com** (deptId 73046844870)

| | |
|---|---|
| Type / Priority | Task · P3 |
| Status | **In Progress** (unresolved) |
| Reporter | Gordon Hallof |
| Assignee | *(unassigned)* |
| Created | 2026-03-23 |
| Labels | `USx` |
| Description | "Build USx Provider for SC SLED" |
| Comments | **1** — Rob, 2026-04-21: *"PO Submitted for Commsys Metadata"* |

⚠️ **THIS FILE PREVIOUSLY DENIED BOTH OF ITS OWN HEADLINE FACTS, and that is why it is being
rewritten rather than appended to.** Until 2026-09-19 it read `**Active ticket:** NONE YET — no DEX
ticket has been created for SC_SLED` and `⚠️ This provider has NO tenant ... installed nowhere.`
Both were false: DEX-993 has existed since 2026-03-23, and SC_SLED has been on usx-sc-sled since
2026-09-16. The file was written before either was true and never revisited.
IT MATTERS BECAUSE THIS FILE IS THE AUTHORITY `audit_lifecycle.ps1` READS. A pointer that denies
its own ticket cannot report a Jira gap — the gate was comparing against a document that said
there was nothing to compare to. Rob found it by pasting the ticket URL, not by any check firing.
**A POINTER FILE IS A CLAIM ABOUT THE WORLD AND HAS TO BE RE-READ AGAINST THE WORLD.**

## Deployment — what is actually installed, and how we know

**SC_SLED v1.18 is on usx-sc-sled**, deployed 2026-09-18 19:05:17 via the panel's RUN THE JOB
button: `verdict=CLICKED`, `dryRun=false`, `guardsFailed=[]`, payload `SC_SLED v1.18`. The 63-test
sweep ran against it 15 minutes later and every entity captured.

⚠️ **A CLICKED VERDICT IS NOT PROOF OF LANDING** — `verify_tenant_import.ps1` is, and it cannot run
here: this tenant's **Export JSON returns nothing** (CLICKED-BUT-NO-JSON), so there is no config on
disk to hash. Bundle NAMES from the live table plus the paired deploy record are the strongest
evidence this tenant permits. Version history today: v1.15 (14:28) → v1.16 (15:32, re-run 15:39) →
v1.17 (16:38) → v1.18 (19:05), all CLICKED with no failed guards.

## Testing

**ALL-PASS 6/6 entities · 79 logs · 0 FAIL · 0 PENDING** (v1.18, swept 2026-09-18).

| Entity | Plan tests | Logs |
|---|---|---|
| Vehicle | 10 | 10 (+8 co-fire) |
| Person | 9 | 9 (+8 co-fire) |
| **Other** (Wanted Person) | 33 | 33 |
| Firearm / Article / Boat | 5 / 1 / 5 | 5 / 1 / 5 |
| **Total** | **63** | **63 planned + 16 co-fire = 79 files** |

`enforce -Provider SC_SLED` 45 PASS / 0 FAIL / 0 WARN · validator 75P/0F/0W/2LIM ·
log content 0 failing / 79 · metadata attribution AGREE 79 / DISAGREE 0 · combo attribution 79/79.

## Jira hold

**Jira is HELD** (Rob 2026-07-31) and lifts ONE PROVIDER AT A TIME. Nothing has been posted to
DEX-993 since the 2026-04-21 PO comment, and nothing may be until the hold lifts for SC_SLED
specifically. `enforce` PHASE 2r printing a `[GAP]` for the Jira stage is the EXPECTED steady state,
not a defect, and must never be listed as owed work.

<!-- STAGE-5 MARKERS. Machine-read by tools\audit_lifecycle.ps1. One line per release, written ONLY
     when the post has been approved and actually made. The Jira comment id is the point: it is the
     one fact this repo cannot derive from itself, which is why the gate stopped accepting "the
     version appears somewhere in this file" as evidence (every DEX_TICKET.md names its own current
     version, so that check could not fail). Format, exactly:
         POSTED: v<X.Y> comment <id> <YYYY-MM-DD>                                                -->
POSTED: v1.18 comment 821482 2026-09-19

**Hold LIFTED for SC_SLED by Rob, 2026-09-19** ("post it"), after the drafts were shown and
approved. The lift is for THIS PROVIDER ONLY — the portfolio-wide hold of 2026-07-31 stands for
every other provider, and one approval never carries to the next (JIRA_COMMENT_TEMPLATE: "DRAFT AND
WAIT ... every provider, every time").

Two comments posted, which is the template's two-shapes-per-ticket rule, not a duplicate:
  - **821482** — the v1.18 RELEASE LINE. Four fixed sections; supersedes nothing (initial post).
  - **821483** — the VERSION HISTORY anchor (v1.0 → v1.18, wire-affecting changes marked, cosmetic
    runs collapsed). Carries no metrics by design and ends by pointing at 821482, so it can never
    be mistaken for current state — that separation is what stopped tickets accumulating mutually
    exclusive log counts.

⚠️ NEITHER COMMENT CARRIES TENANT, ATTACHMENT OR CATALOG DETAIL. That is barred from tickets
(Rob 2026-08-03) and lives in `providers/IMPORT_LEDGER.md` instead. Nor do they use internal
vocabulary — no keyRefs, no `codeTypeCategory`, no LIMITATION numbers: the ticket is a release
announcement for PM/engineering, and the limitations' system of record is
`knowledge-base/PLATFORM_CONSTRAINTS.txt`.

⚠️ THE NUMBERS IN 821482 CAME FROM A TOOL RUN MINUTES BEFORE POSTING, and getting them required
fixing the tool first: `report_test_status` was printing five entity rows summing to 46 above a
total of `PASS=79`, with a `6/5` denominator, because its render loop iterated a hardcoded five
entities while the totals already counted `Other`. Drafting from it unfixed would have published a
five-entity split omitting all 33 Wanted Person logs — on a ticket, where it is irreversible.

## What the release line will have to say — v1.18

Rewritten 2026-09-19. The previous version of this section described **v1.0** and three of its four
claims are now false; they are listed at the end so nobody reinstates them from an old diff.

1. **Two vehicle queries co-fire by design-for-now, and it is now MEASURED rather than predicted.**
   A plate or VIN entry sends BOTH `QVRQ` ("SC Vehicle Stolen/Reg", compound) and `QV` ("Stolen
   Vehicle"), so the stolen check goes out twice. Rob 2026-09-14: *"build both and we can sort it
   out."* Captured proof is in `logs/Vehicle/*_cofire_with_T*.txt`. Person likewise co-fires
   `DriverLicenseQuery` + `DriverRegistrationQuery` off one name or OLN.
2. **Wanted Person is its own tab on entity `Other`** — the sixth entity, and SC_SLED is the only
   provider in the portfolio that uses it. It renders, dispatches and captures: 33/33.
3. **An OLN-only person search returns no wanted check.** SC's design (`QWDQ` requires the full
   name triple; `QWA` defines no OLN-mandatory branch), not a gap in this build.
4. **Vehicle Make is a free-text box on the Wanted Person tab**, by operator directive
   (Rob 2026-09-18: *"leave veh make as a free text  no choice"*) — see LIMITATION #50 below.
5. **TWO NEW PLATFORM LIMITATIONS were found here and both are portfolio-wide facts**, not SC
   quirks. They are the most reusable thing this build produced:
   - **LIMITATION #49** — two QIDM configs sharing one `query` both render a selectable checkbox
     and **only one ever dispatches**; the other sends nothing, silently. Cost three versions
     (v1.15–v1.17) during which the Person wanted-person check never reached the wire while every
     gate read green. `validate.ps1` now FAILs on a duplicate `query`.
   - **LIMITATION #50** — on entity `Other`, an `attributeTypeId` control does **not** resolve and
     the wire carries the platform's internal numeric row id (`<SexCode>73046851255</SexCode>`)
     even with `codeTypeProvider` set. `codeTypeCategory` DOES resolve there. Fixed at v1.18 by
     reverting Sex/Race/State to the category form.

RETIRED CLAIMS from the v1.0 draft — do NOT reinstate:
  ~~"AdministrativeMessage is STATUS: HYPOTHESIS, a 6th card"~~ — REMOVED at v1.13 by directive and
    registered `devdoc-combo-unbuilt`; restoring it would need `targetEntity=Other`, which the
    Wanted Person tab now occupies.
  ~~"a name+sex+DOB entry sends both QWDQ and QWA.N"~~ — untrue since v1.17; Wanted Person left the
    Person tab, so there is no name-driven double wanted check.
  ~~"SC_SLED is installed nowhere / has no tenant"~~ — see Deployment above.
