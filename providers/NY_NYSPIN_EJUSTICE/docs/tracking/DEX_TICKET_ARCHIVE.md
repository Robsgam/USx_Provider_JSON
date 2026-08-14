# NY_NYSPIN_EJUSTICE — DEX-969 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Under the one-comment-per-release
rule the SAME comment id is rewritten each release, so without a capture the previous release
statement is gone. Pattern established on NJ_NJCJIS 2026-08-14; this is NY's.

NY is the provider that most needs this: it carried **22 comments and eight mutually inconsistent
log counts** (17, 64, 66, 67, 72, 73 …) before the 2026-08-11 consolidation. The edit-in-place rule
is what stopped that, and this archive is what keeps the superseded text recoverable.

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## comment 794205 — captured 2026-08-14, immediately before the v4.24 edit

State at capture: created 2026-08-07 as the v4.20–v4.23 release line, updated 2026-08-11 in the
consolidation pass. Carrying **v4.23** at 69/69.
Superseded by: the v4.24 release line written into this same comment id on 2026-08-14.

```
🤖 Auto-update from the ConnectCIC provider-JSON repo — generated from the build and gate artifacts (BUILD_NOTES, the four log gates, `audit_log_inflation`, `enforce`).

**NY_NYSPIN_EJUSTICE v4.23 — TENANT-VERIFIED**

**1. Scope**
Versions covered: v4.20–v4.23. Configuration changed: yes. Supersedes: comment 790896 (v4.19).

**2. Changed**

* **v4.21 (DEX-1283)** — this provider needed a **different fix from TX/FL/CA_CLETS**, and that difference is the point. On NY, `requestorDH` is metadata-**mandatory** in `set[]`, so `set[]` membership makes the browser gate the Send button; v4.20's plain `'X'` removal left `DALHOUT` permanently unsubmittable. v4.21 instead **demoted** `requestorDH` from `set[]` to `any[]`, which both removes the literal and restores submission. The plain removal that worked elsewhere was the wrong fix here.
* **v4.22–v4.23 (DEX-1284)** — Purpose Code dropdown reverted to a free-text input: the tenant renders that code-type list empty, so a dropdown made the field unfillable. Vehicle home-state strip kept.
* v4.20 — DEX-1283 first attempt, superseded by v4.21 as above.

**3. Verified on the wire**
Vehicle 19 / Person 27 / Firearm 5 / Article 4 / Boat 14 = **69**
The DH out-of-state paths (`DALHOUT`/`DALLOUT`) submit and resolve, which is what v4.20 could not do. `RegistrationStateDH` EXISTS/NOT_EXISTS routing confirmed on the wire, and the home-state strip is live-proven.

**4. Gates**
validator 76P/0F/0W · four log gates 69/69 (content, metadata, attribution, plan completeness 5/5) · inflation 0/0/0/0 · enforce 42 PASS / 0 provider-scoped FAIL-or-WARN · 16 combos, all reachable

**5. Known limits**
The CAD-dispatch path is not exercised by any form-driven log on this provider. The Purpose Code revert is a **tenant-specific** accommodation — the code-type list renders empty on this tenant, and whether it populates elsewhere is untested, so the free-text input is the safe form rather than a proven-universal one.

**6. Documented skips**
None — all 6 devdoc-Basic queries built. (The `DGRP` name-search QIDM was removed at v4.11 under DEX-1284 as out-of-Basic-scope, not skipped from the Basic set.)

**RELEASE LINE — v4.23 is verified and ready.**
```

**What this capture preserves that the v4.24 edit necessarily drops:**

1. **Sections 5 and 6** — predating the 2026-08-13 four-section ruling. Two things leave the ticket
   here and are worth knowing: the CAD-dispatch path is exercised by no form-driven log on this
   provider, and **the Purpose Code free-text revert is a TENANT-SPECIFIC accommodation** — that
   code-type list renders empty on this tenant (LIMITATION #39) and whether it populates elsewhere
   is untested. Do not "restore" the dropdown on the assumption it was a mistake.
2. **The v4.21 fix and why NY needed a different one from TX/FL/CA_CLETS.** `requestorDH` is
   metadata-mandatory in `set[]` here, so `set[]` membership gates the browser's Send button; the
   plain `'X'` removal that worked on the other providers left `DALHOUT` permanently unsubmittable,
   and the fix was a `set[]`→`any[]` demotion. That is the single most reusable piece of knowledge
   on this ticket and it is not restated in the v4.24 body.
3. **The `DGRP` note** — removed at v4.11 as out-of-Basic-scope, NOT a skipped Basic query.
