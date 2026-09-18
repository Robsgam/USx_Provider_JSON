WHY THIS LOG IS HERE AND NOT DELETED
====================================
Archived 2026-09-17.

FILE: SC_SLED_v1.11_DQ.RO_guardrail_vs_DQ.RN.txt

WHAT IT IS. A valid guardrail capture, correctly run and correctly saved at the time. It asserts
that within DriverRegistrationQuery an OLN fill (DQ.RO) wins over a Name fill (DQ.RN).

WHY IT NO LONGER MATCHES. The v1.11 TEST_PLAN was REGENERATED MID-SWEEP (2026-09-17, when the
QV.VM plan gap was closed and again when per-test `tab`/`qif` was added). The current plan's
Person guardrail is T19, which expects `DQ` to win -- there is no longer any plan test carrying
the label `DQ.RO_guardrail_vs_DQ.RN`, so `audit_log_content` reported this log as STALE and
`enforce -Provider SC_SLED` was BLOCKED on it.

⚠️ THE MECHANISM WORTH REMEMBERING: `reset_test_package.ps1` archives logs when the JSON VERSION
changes. A PLAN RE-EMIT INSIDE THE SAME VERSION does not. So re-emitting a plan mid-sweep can
orphan an already-captured log with no version bump and no archive step -- and the orphan keeps a
`v1.11` filename, which reads as current evidence. That is why it is moved rather than left in
place: a stale log that looks current is worse than a missing one.

NOT DELETED, because it is real wire evidence and the routing question it records may still
matter if the DriverRegistration guardrail is revisited.

WHAT IS OWED. The Person sweep is 7 of 9; the current guardrail (T19) still needs capturing, and
it is counted in the 54 tests SC_SLED still owes. Nothing about this archive reduces that count.

Diagnosis note: this log was originally reported as a CONTENT MISMATCH, which would have sent
someone to re-run a query that was fine. It was reclassified to STALE only after a null-guard bug
in `audit_log_content.ps1` was fixed the same day (`@($hash[$missingKey])` is `@($null)`, whose
`.Count` is 1, so the stale-guard never fired and the candidate loop crashed on $null). See that
tool's entry in knowledge-base/TOOL_REFERENCE.txt.
