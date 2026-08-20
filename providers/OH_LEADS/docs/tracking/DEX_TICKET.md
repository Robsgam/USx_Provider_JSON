# OH_LEADS — DEX Ticket

**Active ticket:** [DEX-990 — \[OH - LEADS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-990)
Project: DEX (CJIS/USx/DEx Implementation) · Status (verified 2026-08-10): In Progress · Unassigned

POSTING RULE -- **REVERSED 2026-08-17 BY ROB, and this file had the SUPERSEDED version until
2026-08-18.** It previously said "ONE COMMENT PER RELEASE, and EDIT it in place if the numbers move"
and "six numbered sections". Both are wrong now, and following them would have destroyed a record:
  * **POST A NEW COMMENT PER RELEASE. Do NOT edit the previous release line** -- leave it in place as
    history. Rob: "post as a new comment and leave the other comments there. we can't keep erasing
    the previous posts everytime." There is NO delete-comment tool and an edit is IRREVERSIBLE, so
    edit-in-place silently overwrote each prior release's evidence.
  * **FOUR sections, not six** (Rob 2026-08-13 -- six was "way too many details"). Known limits and
    documented skips are NOT in the comment; they live in `PLATFORM_CONSTRAINTS.txt` and
    `<P>_ACCEPTED_DIVERGENCES.txt`, which already own and gate them.
  * Every new release comment must name the comment id it SUPERSEDES and say the old one is retained
    as history -- that is what keeps the thread unambiguous without erasing it.
Format is FIXED for every provider and every update: `knowledge-base/JIRA_COMMENT_TEMPLATE.txt` is
the single source (two shapes per ticket: one release line, one history anchor). Only
automation-authored (🤖) comments may ever be edited: never Rob's own manual notes, never a third
party's.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-990`
> (cloudId `5ba7ec1f-1b3f-4b21-a2f2-5d04d124de2c`). `audit_lifecycle` (enforce 2r) READS THIS FILE,
> NOT THE TICKET — it can PASS on a lie and FAIL on the truth. HI's equivalent file did exactly that.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C.

**HOW THIS TICKET NUMBER WAS FOUND, because it was NOT recorded anywhere in the repo.** OH_LEADS was
absent from `knowledge-base/JIRA_REFERENCE.txt` AND from the `IMPORT_LEDGER.md` DEX column, so there
was no repo source to copy — and inventing a plausible number is a mistake already made once on IL
in this project. It was found by querying Jira for DEX issues matching OH/Ohio/LEADS: **DEX-990,
summary "\[OH - LEADS\] USx Provider Build"**, the identical naming pattern to IL's DEX-984
"\[IL - LEADS-OFML\] USx Provider Build". Then fetched directly to confirm the summary, the
In-Progress status, and that it carries **zero comments**.

Its description also supplies a fact the ledger was missing: the tenant is
**`usx-oh-leads.mark43.com`**.

**Posted so far:** NOTHING. `comments: []`, total 0 — this ticket has never been commented on, by
**Posted 2026-08-18 -- the FIRST comments this ticket has ever carried, by anyone.** Verified
`comments: []`, total 0 immediately before posting, so this was a genuine first post and not a
catch-up. Two comments, which is the full complement for a ticket (one release line + one history
anchor); everything after this is a new release line.

POSTED: v2.9 comment 801112 2026-08-18
POSTED: v2.9 comment 801113 2026-08-18
POSTED: v2.10 comment 802507 2026-08-20

**Posted 2026-08-20 -- v2.10 release line, comment 802507.** A NEW comment, per the 2026-08-17 rule;
801112 is LEFT IN PLACE as the v2.9 history and 802507 names it as superseded-but-retained. Three
comments now: 801113 (history anchor) + 801112 (v2.9, retained) + 802507 (CURRENT).
  DISCLOSED AGAIN RATHER THAN QUIETLY DROPPED, because all three carried over unchanged from v2.9:
  inflation is 2/0/0/0 (RN_af_AddressCounty == RN_any, ATDP == ATDP_guardrail_vs_RQ.P), the ATDP
  guardrail reproduces its base test's wire so it adds no independent evidence, and Middle/Suffix are
  still not exercised (wire reads `DOE, JOHN`). A cosmetic release is exactly where a stale caveat
  would be easiest to drop, so it is repeated verbatim.
  THE COSMETIC CLAIM IS WIRE-PROVEN, not asserted: all 56 captured wires are byte-identical to their
  v2.9 archived counterparts with transaction ids normalised (56/0/0), and ARTICLE -- the one card not
  edited -- is the unchanged-fingerprint control.

  801112 = RELEASE LINE (current state -- read this one). OH_LEADS v2.9 TENANT-VERIFIED, 56/56.
  801113 = HISTORY ANCHOR (v1.0 -> v2.9, wire-affecting changes marked; no metrics, by design --
           metrics belong only in the release line, which is what stopped the contradictory-total
           problem on the older tickets). Points at 801112 for current state.
  DISCLOSED IN 801112 RATHER THAN ROUNDED OFF: inflation is 2/0/0/0, not 0/0/0/0 (two of the 56 logs
  are not distinct tests), the ATDP guardrail was inconclusive, and the v2.7 Middle/Suffix controls
  were NOT exercised by the sweep -- they are composed into Name but sit in no set[]/any[], so the
  plan cannot fill them and the wire read `DOE, JOHN`. Making that provable is a wire change (v3.0).
**Current: v2.10 -- TENANT-VERIFIED ALL-PASS 5/5 (56 logs, 56 PASS / 0 FAIL) 2026-08-20.** Cosmetic
only: the parenthetical helper clause removed from all 5 card titles that carried one. NO wire change,
and that is PROVEN rather than claimed -- all 56 captured wires are byte-identical to their v2.9
counterparts (transaction ids normalised), with ARTICLE, the one card not edited, as the
unchanged-fingerprint control. Release line **comment 802507**; 801112 retained as v2.9 history.

THIS FILE CARRIED **TWO** COMPETING "Current:" LINES UNTIL 2026-08-20 -- `v2.4 BUILT, NEVER
tenant-tested` AND `v2.9 TENANT-VERIFIED` -- one directly contradicting the other, with nothing
marking which was live. That is the same defect `JIRA_COMMENT_TEMPLATE.txt` was written to stop on
the TICKETS (DEX-969 once showed nine mutually exclusive totals), reproduced here in the repo file
that `audit_lifecycle` reads. Collapsed to ONE line; prior states are history below, never a second
"Current". Superseded, for the record: v2.9 TENANT-VERIFIED 2026-08-18 (the first ever tenant import
and first ever sweep for this provider), and before it v2.4 BUILT 2026-08-10, never imported.
Recent history (full detail in `OH_LEADS_BUILD_NOTES.txt`):
- **v2.4** — **card collapse 14 → 6** (Vehicle 6→1, Person 5→2, Boat 3→1) with every title now
  carrying its query paths; OH had been the only provider of nine with 0 path-carrying titles. Zero
  routing change. Helper labels fell 18 → 2 as a *consequence* (the survivors were saying which combo
  needs a field — a card title's job). Plus **ImageQuery BUILT**, the last unbuilt devdoc-Basic query:
  `Set[OperatorLicenseNumber]` per metadata v9 BMVIMS, `autoSelect=false` so it is an officer opt-in
  photo request rather than something that co-fires on every OLN entry. New queryLabel
  **Driver Photo** registered in `verify_build` and the CLAUDE.md table. Extract promoted
  PROVISIONAL → **CONFIRMED** (gating): 23 PASS / 0 FAIL / 0 WARN, 7 of 7 Basic queries built.
- **v2.3** — DEX-1283 Attention `'X'` removed (feeder + both KQ.N/KQ.O combo `defaults[]`) and a
  DEX-1284 label pass: `License Number` → **OLN** (OH was the only provider of nine not using the
  canonical label), three different image labels → **NCIC Image**, three verbose stolen-check labels
  → **Stolen Check**, `(optional)` suffixes stripped, and four `# LABEL-OVERRIDE:` tags added so the
  lean labels register as INFO rather than CHECK 15 WARNs. Cleared
  `[FLAG:validate-imgind-20b-l30]` — validator recorded 78 PASS where STATUS.txt was stuck at 77P.

**Owed to this ticket:** the full changelog dump (v1.0 → v2.4), then a release line once the sweep
passes. **Jira is DRAFT-AND-WAIT — draft and wait for Rob's explicit approval before posting.**

**BOTH OPEN ITEMS ARE CLOSED at v2.4 (Rob's call 2026-08-10: "fix 1 and 2 — that was the point").**
1. ~~`ImageQuery` devdoc-Basic and NOT BUILT~~ → **BUILT.** `Set[OperatorLicenseNumber]` exactly per
   metadata v9 `BMVIMS`, `autoSelect=false` (officer opt-in, so it does not co-fire on every OLN
   entry), no new form control needed. CHECK 0 now reports all **7 of 7** Basic transactions built.
2. ~~14 cards, 0 path-carrying titles~~ → **6 cards, 6 path-carrying titles**, matching the portfolio.
   Person deliberately stays at TWO cards (DL + DH) because the DH-suffix fieldIds are a separate
   field pool — that is the isolation mechanism, and HI/NY/TX/AZ keep the same split.

**One advisory remains, pre-existing and NOT introduced by v2.4:** `audit_requirement_fidelity`
reports 1 UNDER-REQUIRED (`DQ.O` missing `SocialSecurityNumber`). It is the shared-keyRef artifact —
`BMVIMS` names both DriverLicenseQuery's OLN variant *and* its SSN variant, and the tool bridges on
the bare keyRef and compares against their union. **DL-by-SSN is not in OH's Basic DL list** (five
combinations, OLN and Name only), so that variant is correctly unbuilt. Deliberately not registered:
naming the BUILT combo `DQ.O` with an existence-class rule would suppress its whole comparison.
