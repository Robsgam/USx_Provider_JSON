# NJ_NJCJIS — DEX-988 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"a release comment is a living record
until the next release supersedes it"*, and *"there is no delete-comment tool ... any edit is
IRREVERSIBLE — capture the original body before overwriting it."* Until 2026-08-14 that capture
was never actually written anywhere: `IL_LEADS_OFML`'s DEX_TICKET.md says *"Original v2.2 body
captured before the edit"* and no such capture exists in the repo. An assertion that a backup was
taken is not a backup. This file is the real thing for NJ, and the pattern other providers should
follow when their release line is edited in place.

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## comment 795856 — captured 2026-08-14, immediately before the v4.16 edit

State at capture: created 2026-08-11, carrying the **v4.15** release line at 40/40.
Superseded by: the v4.16 release line written into this same comment id on 2026-08-14.

```
🤖 Auto-update from the ConnectCIC provider-JSON repo — generated from the build and gate artifacts (BUILD_NOTES, the four log gates, `audit_log_inflation`, `enforce`).

**NJ_NJCJIS v4.15 — TENANT-VERIFIED**

**1. Scope**
Versions covered: v4.15 (no version change). Configuration changed: **no** — test coverage only. Supersedes: comment 790914 (the v4.15 release line at 36/36).

**2. Changed**
No configuration change — **coverage extension plus a full re-verification.** The 2026-08-03 release line reported ALL-PASS 36/36, which was true for the plan as it then stood. The plan has since gained **four out-of-state toggle tests that had never been generated**, so the package correctly read PARTIAL (36 captured of 40) until today. The provider JSON is byte-identical; the test coverage grew.

The four newly captured tests, all exercising `RegistrationState = AK`:

| Entity | Combo | Fill |
| --- | --- | --- |
| Vehicle | `RANDFULL` | `LicensePlateNumber=TEST123` + `RegistrationState=AK` |
| Vehicle | `RANDFULLN` | `VehicleIdentificationNumber=1HGCM82633A123456` + `RegistrationState=AK` |
| Person | `FULL` | `NameLast=DOE, NameFirst=JOHN, BirthDate=1990-01-15` + `RegistrationState=AK` |
| Person | `FULLN` | `OperatorLicenseNumber=D999888777` + `RegistrationState=AK` |

**3. Verified on the wire**
Vehicle 13 / Person 10 / Firearm 6 / Article 3 / Boat 8 = **40**, all five entities re-run in one session so every log is same-session and same-version (verified three ways: 40 of 40 filenames at v4.15, 40 of 40 internal `JSON Version: 4.15` stamps, 0 logs predating the sweep).

All four new tests transmit `<State>AK</State>` and each attributed to its **expected** keyRef (`routing=VERIFIED (expected combo set[] on wire)`). This settles a point that had only ever been inferred: **NJ carries the out-of-state state as an** `any[]` passenger on the same combination, rather than forking to a dedicated out-of-state keyRef the way FL_FCIC and NY_NYSPIN_EJUSTICE do. That was the design intent; it is now wire-proven.

**4. Gates**
validator 61P/0F/0W · four log gates 40/40 (content, metadata, attribution, plan completeness 5/5) · inflation 0/0/0/0 · enforce 43 PASS / 0 provider-scoped FAIL-or-WARN · 8 combos, all reachable

**5. Known limits**
The four AK tests prove the out-of-state state reaches the wire and does not change which combination fires. They do **not** exercise a genuine out-of-state _response_ — no Nlets round-trip is involved, because NJ has no separate out-of-state transaction to route to. Separately, the CAD-dispatch path is not covered by any form-driven log on this provider.

**6. Documented skips**
`VehicleStolenQuery` — approved skip (Rob). The state auto-runs QV and the response is data-mined via the QRDM, so building it would duplicate a query the switch already issues. 5 of 6 devdoc-Basic queries built; the sixth is this skip.

**RELEASE LINE — v4.15 is verified at full plan coverage, 40/40.**
```

**Two things this capture preserves that the v4.16 edit necessarily drops:**

1. **Sections 5 and 6.** This body predates the 2026-08-13 four-section ruling, so it still carries
   "Known limits" and "Documented skips". Both are now barred from ticket comments and live in
   `knowledge-base/PLATFORM_CONSTRAINTS.txt` and `<P>_ACCEPTED_DIVERGENCES.txt` respectively. The
   `VehicleStolenQuery` approved skip and the "no Nlets round-trip / CAD not covered" caveats are
   therefore NOT lost — but they are no longer visible on the ticket, and this capture is the last
   place they appear in that wording.
2. **The v4.15 AK-test evidence.** The four out-of-state toggle tests and the finding they settled
   (NJ carries out-of-state State as an `any[]` passenger rather than forking to a dedicated OOS
   keyRef, unlike FL and NY) are v4.15's contribution and are not restated in the v4.16 body, which
   covers only the NCIC-image change. Both remain true of v4.16 — the JSON's OOS handling did not
   change — so do not read their absence as a regression.
