# TX_TLETS — DEX-967 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Under the one-comment-per-release
rule the SAME comment id is rewritten each release, so without a capture the previous release
statement is gone for good. Pattern established on NJ_NJCJIS 2026-08-14; this is TX's.

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## comment 790861 — captured 2026-08-14, immediately before the v4.20 edit

State at capture: created 2026-08-03 as the v4.13–v4.18 release line, **already edited in place once**
(to v4.19, on 2026-08-11, during the consolidation pass). Carrying **v4.19** at 92/92.
Superseded by: the v4.20 release line written into this same comment id on 2026-08-14.

```
🤖 Auto-update from the ConnectCIC provider-JSON repo — generated from the build and gate artifacts (BUILD_NOTES, the four log gates, `audit_log_inflation`, `enforce`).

**TX_TLETS v4.19 — TENANT-VERIFIED**

**1. Scope**
Versions covered: v4.13–v4.19. Configuration changed: yes. Supersedes: comment 786638 (v4.12).
_This comment previously stated v4.18 at 89/89, which was already stale when posted — TX was v4.19 with 92 logs. Per the posting rule adopted 2026-08-11, a release comment is **edited in place** when its numbers move rather than corrected by a sibling comment; that is what has happened here._

**2. Changed**

* **v4.19 (DEX-1283)** — removed `initialValue='X'` from the Attention (DH) and EmailAddress (DL+DH) hidden gate-feeders, plus the matching combo `defaults[]` entries. `sourceField` stays non-empty and both fields remain in their combos' `any[]`: ConnectCic rejects an empty `sourceField[]` at import, and the platform serializes only the fired combo's `set[]`/`any[]` fields. Only the never-isolated third condition from the 2026-06-22 handler finding was removed.
* **v4.14** — all 7 Vehicle metadata combinations made form-reachable: removed four routing-affecting prefills (`LicensePlateTypeCode=PC` and others) that permanently hid every combination requiring their absence; `RQ`/`QV` restored.
* **v4.13** — removed 2 dead `RQ` combos; established BUILD_RULES 23 (form queries first).
* v4.15–v4.18 — DEX-1283 UI adjustments from the CAD review, Person DL card restructure, label and layout passes. No wire change.

**3. Verified on the wire**
Vehicle 20 / Person 32 / Firearm 10 / Article 8 / Boat 22 = **92**
The rule handlers (`CommsysGetLastNameFirstNameInitialRuleHandler`, `GetUserProfileSingleValueRuleHandler`) resolve the real officer name and email **with nothing in the source field at all**. The "X" visible in a form snapshot is the raw pre-handler value in dex-log's Query String column, not what reaches CommSys — so removing the default changed nothing on the wire, which is what the 92 captures confirm.

**4. Gates**
validator 79P/0F/0W · four log gates 92/92 (content, metadata, attribution, plan completeness 5/5) · inflation 0/0/0/0 · enforce 41 PASS / 0 provider-scoped FAIL-or-WARN · 19 combos, all reachable

**5. Known limits**
The CAD-dispatch half of the DEX-1283 fix — removing `Attention`/`EmailAddress` from the combo `defaults[]` — is verified by **inspection only**. No form-driven log exercises the CAD path, and that path is DEX-1283's second reported symptom ("not present when you do it from a CAD event"). Treat CAD as addressed by configuration review, not by captured evidence.

**6. Documented skips**
`VehicleRegistrationQuery` — metadata does define it (7 combinations), but `VehicleInsuranceRegistrationQuery` is built instead, deliberately: it is the richer response (registration **plus** financial-responsibility/insurance detail) and already carries RQ and QV by both plate and VIN with byte-identical requirements to the unbuilt sibling. Building the second transaction would duplicate those paths for no additional information. Rob's ruling, 2026-08-11 — not to be built back in. 6 of 7 devdoc-Basic queries built.

**RELEASE LINE — v4.19 is verified and ready.**
```

**Three things this capture preserves that the v4.20 edit necessarily drops:**

1. **Sections 5 and 6** — this body predates the 2026-08-13 four-section ruling. The CAD-verified-by-
   inspection-only caveat and the `VehicleRegistrationQuery` documented skip (Rob's 2026-08-11 ruling
   that `VehicleInsuranceRegistrationQuery` is built instead, being the richer response) leave the
   ticket here. Both remain true and both live in the repo — the skip in
   `TX_TLETS_ACCEPTED_DIVERGENCES.txt`, the CAD caveat in the BUILD_NOTES.
2. **The v4.13–v4.19 change list**, including the v4.14 form-reachability recovery and the v4.13 dead-
   `RQ` removal. The v4.20 body covers only the NCIC-image change; the earlier work is not restated
   and its absence is not a regression.
3. **Its own self-correction note** — that this comment had once claimed v4.18 at 89/89 while TX was
   already v4.19 with 92 logs. That is the incident the edit-in-place rule exists to prevent, and it
   is worth keeping legible.
