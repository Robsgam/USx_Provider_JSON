
================================================================================
PRE-EDIT CAPTURE -- comment 791400, taken 2026-08-17 before the v2.25 in-place edit
================================================================================
Captured because addCommentToJiraIssue EDITS IN PLACE and there is no delete/undo. This
is the body as it stood at v2.24 (created 2026-08-04, last edited 2026-08-11 13:42 EDT).

NOTE ON SHAPE: this version still carries the OLD SIX-SECTION format. The v2.25 rewrite
drops "5. Known limits" and "6. Documented skips" per the 2026-08-13 ruling (four sections
only). Before dropping them, each was verified as recorded in the repo -- 14 ACCEPTED_DIVERGENCES
rows name IV.4*, the purposeCode-prefill rationale is in BUILD_NOTES, and the CAD/Attention
inspection-only note is in BUILD_NOTES. Nothing in 5 or 6 existed only on the ticket.

--- BEGIN ORIGINAL BODY (791400 @ v2.24) ---
Auto-update from the ConnectCIC provider-JSON repo -- generated from the build and gate
artifacts (BUILD_NOTES, the four log gates, audit_log_inflation, enforce).

**CA_CLETS v2.24 -- TENANT-VERIFIED**

1. Scope
Versions covered: v2.15-v2.24. Configuration changed: yes. Supersedes: comment 787391 (v2.19).
Extended in place from v2.23 to v2.24 rather than posting a sibling comment, per the posting
rule adopted 2026-08-11.

2. Changed
* v2.24 (DEX-1283) -- removed initialValue='X' from the Attention (DH) hidden gate-feeder and
  the matching combo defaults[] on NLTS.KQ.N / NLTS.KQ.O. sourceField stays non-empty and
  Attention remains in both combos' any[]: ConnectCic rejects an empty sourceField[] at import,
  and the platform serializes only the fired combo's set[]/any[] fields.
* v2.23 -- IG.QGH split into IG.QGH.A (Age) and IG.QGH.B (BirthDate). The single combo satisfied
  NO metadata variant: #4 requires SexCode, and #5/#6 put Choice[Age|BirthDate] inside <Set>,
  making one of them mandatory. It had been shipping a request no variant accepted, and a
  committed PASS log had masked it -- the class only gate 6d can see, because a missing
  requirement is invisible to content and attribution checks.
* v2.20-v2.22 -- IR.QVC.O no longer requires criminalIdNumber (metadata variant #3 makes CII/SSN
  optional); new IR.QVC.OS carries the SSN branch; ID.L1 gained a socialSecurityNumber
  NOT_EXISTS gate. That trio closed devdoc DriverLicenseQuery #6, where the form accepted an SSN
  and the wire silently dropped it. NLTS.DQ.N gained SexCode in any[]; IR.QVC.C dropped age,
  which neither its metadata variant nor devdoc #5 defines.
* v2.15-v2.19 -- in/out existence-gating fix on Vehicle, label and card-collapse passes. Layout
  and routing-gate work; no dropped or added wire fields.

3. Verified on the wire
Vehicle 23 / Person 41 / Firearm 7 / Article 10 / Boat 9 = 90
CommsysGetLastNameFirstNameInitialRuleHandler resolves the real signed-in officer's name with
nothing in the source field at all -- proven first on TX_TLETS v4.19 and FL_FCIC v7.18, and
confirmed here across a full re-sweep. The "X" a form snapshot shows is the raw pre-handler
value in dex-log's Query String column, not what CommSys receives.

4. Gates
validator 79P/0F/0W - four log gates 90/90 (content, metadata, attribution, plan completeness
5/5) - inflation 0/0/0/0 - enforce 42 PASS / 0 provider-scoped FAIL-or-WARN - 27 combos, all
reachable

5. Known limits
The CAD-dispatch half of the DEX-1283 fix (removing Attention from combo defaults[]) is verified
by INSPECTION ONLY -- no form-driven log exercises the CAD path, which is DEX-1283's second
reported symptom. Note also that CA_CLETS's purposeCode='C' prefill is retained deliberately: it
sits in EVERY CA combination's set[], so it cannot shadow one combo over another, and removing it
would break CAD injection (CAD does not apply form initialValues). The 12 unreachable IV.4x
plate-type sub-variants are structurally shadowed by IA.QV's strict-subset set[], with or without
that prefill -- all 12 are registered.

6. Documented skips
None -- all 6 devdoc-Basic queries built.

**RELEASE LINE -- v2.24 is verified and ready.**
--- END ORIGINAL BODY ---
