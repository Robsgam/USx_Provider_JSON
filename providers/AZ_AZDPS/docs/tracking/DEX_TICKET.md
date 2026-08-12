# AZ_AZDPS — DEX Ticket

**Active ticket:** [DEX-974 — \[AZ - AZDPS\] USx Provider Build](https://mark43.atlassian.net/browse/DEX-974)
Project: DEX (CJIS/USx/DEx Implementation) · Status (verified 2026-08-10): In Progress · Unassigned

POSTING RULE (revised 2026-08-11): **ONE COMMENT PER RELEASE, and EDIT it in place if the numbers
move** -- never post a correction as a sibling comment. That is what produced contradictory totals
across these tickets (DEX-969 carried NINE; DEX-967's newest comment claimed 89/89 while the
provider was at 92). Format is FIXED for every provider and every update -- see
knowledge-base/JIRA_COMMENT_TEMPLATE.txt (six numbered sections, None rather than omitted;
plus the separate HISTORY-ANCHOR shape for the one initial dump). **No delete-comment tool exists**,
so superseded comments are rewritten to the stub defined there, never removed -- and every edit is
irreversible, so capture the original first. Only automation-authored (🤖) comments may be edited:
never Rob's own manual notes, never a third party's.

> **THIS FILE IS NOT THE TICKET — read the ticket.** Verify with `getJiraIssue DEX-974`
> (cloudId `5ba7ec1f-1b3f-4b21-a2f2-5d04d124de2c`). The equivalent file on HI_HCJDC_OFML lied once
> by stopping three comments short, and the one on FL produced a confidently wrong "nine versions
> owed" the same way. `audit_lifecycle` (enforce 2r) READS THIS FILE, NOT THE TICKET — it can PASS
> on a lie and FAIL on the truth.
>
> **TENANT INFO STAYS OFF THIS TICKET (Rob, 2026-08-03):** no attachment note, no catalog post, no
> Foundation import line. Track those in `providers/IMPORT_LEDGER.md` sections B and C.

**Why this file only exists from 2026-08-10:** AZ had no ticket pointer at all until then, so
`audit_lifecycle` reported `[NOTE] no DEX_TICKET.md; no ticket pointer exists for this provider` and
the lifecycle tail was ungated for this provider. It was created when
`audit_provider_uniformity` compared AZ against the seven tenant-complete providers and found
`DEX_TICKET.md` present on 7 of 9 — AZ and OH_LEADS were the two without one. The DEX number was
taken from `knowledge-base/JIRA_REFERENCE.txt` line 21 and `IMPORT_LEDGER.md`, which agree, and then
**confirmed against Jira itself** rather than trusted — the summary really is
"\[AZ - AZDPS\] USx Provider Build". (Inventing a DEX number is a mistake already made once on IL
in this project; hence the verification.)

**Posted so far** (indexed from the ticket 2026-08-10 — 1 comment, accounted for):
- 776896 (2026-07-10, Leo Hisoire) — a scheduling/roadmap note referencing FB-6040 and a Friday
  meeting. **Not a changelog.** No 🤖 auto-update comment has ever been posted here.

**Current: v3.10 — BUILT 2026-08-12 (cosmetic/layout pass). RE-IMPORT + full 55-test re-sweep owed.**
v3.10 took audit_layout_flow from 12 findings to 0. **The wire is provably unchanged** — all three
bundles'' QIDMs are byte-identical to v3.9 — so this is layout and labels only. Changes: SSN and Race
grouped onto their own row (both are RMS-only, in NO CommSys combination, and SSN had been sitting
beside OLN reading as a state identifier); MI → Middle Name on both name fields (maxLen=20, so
MI misrepresented capacity); name order First-before-Last with all four parts on one row; NCIC
Image moved off a full-width row into the identifier row; hidden badge rows moved to the bottom on
Firearm and Article, where they had been splitting the serial from make/model/caliber; row widths
tiled to 12. PHASE 1 clean, fuzz 8/8 caught 0 survived, AZ-scoped enforce 0 FAIL / 0 WARN.
**NOT changed, awaiting a ruling:** RegistrationStateDH is hidden and prefilled AZ, which makes
out-of-state driver history unreachable. That is functional, not cosmetic.

**Prior: v3.9 — TENANT-VERIFIED 2026-08-11, ALL-PASS 55/55** (Veh 11 / Per 24 / Gun 6 / Art 3 /
Boat 11), four log gates 55/55, inflation 0/0/0/0. First full sweep this provider ever had.
Recent history (full detail in `AZ_AZDPS_BUILD_NOTES.txt`):
- **v3.9** — DEX-1284 label conformance: `NCIC Image` canonicalised (one label; every other measured
  convention already conformed).
- **v3.8** — two real wire fixes: DEX-1283 Attention `'X'` removed (feeder `initialValue` + both
  KQH/KQ combo `defaults[]`), and **four over-permitted fields** removed from the Vehicle combos
  (`VehicleMakeCode`/`vehicleYear` off the plate combo, `LicensePlateTypeCode`/`LicensePlateYear`
  plus their `defaults[]` off the VIN combo) — the two metadata `ACVR` variants share one keyRef and
  define disjoint optionals.
- **v3.7** — BadgeNumber actually wired (it never had been) + four prefill shadows removed.

**Owed to this ticket:** the full changelog dump (v1.0 → v3.9) has NEVER been posted, plus a release
line once the 55-test sweep passes. **Jira is DRAFT-AND-WAIT: draft it and wait for Rob's explicit
approval before posting, every provider, every time.**
