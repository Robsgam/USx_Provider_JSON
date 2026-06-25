DEX-1257 Jira follow-up — POST AFTER v4.4 live testing completes.
====================================================================

DONE 2026-06-25: Initial full changelog dump posted to DEX-1257 (comment id 767719).

PENDING (post once v4.4 live test passes): add a follow-up comment with the
v4.3 -> v4.4 diff and the import/test release line. Draft:

--------------------------------------------------------------------
**HI_HCJDC_OFML v4.4 — what changed vs v4.3** (post-test update)

- **Vehicle / VehicleRegistrationQuery:** removed the two dormant stolen combos
  **QVP** (plate+state) and **QVV** (VIN+MakeCode). QIDM now has **4 combos**
  (RQ / RQV / M55L / M55S) vs 6 in v4.3.
- **Why:** v4.3 live test showed that clearing the Vehicle Type dropdown on a
  Plate+State query made QVP the only matching combo, firing an unintended
  QV (stolen). The form should never emit a stolen query directly — the state
  CommSys server auto-generates QV from supplied fields (data-mined via QRDM).
- **Behavior change:** a Plate+State query with Vehicle Type cleared and no
  Plate Type/Year now matches no combo and fires nothing (unsupported path).
- **Scope:** Vehicle QIDM only. Article / Boat / Firearm / Person fingerprints
  unchanged (carried over as CONFIRMED; not retested).
- _Imported to USx HI TEST tenant — v4.4, [fill in test result] ._
--------------------------------------------------------------------
(Confirm the diff against the repo CHANGELOG before posting; fill the release line with the actual v4.4 test outcome.)
