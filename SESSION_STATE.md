# SESSION STATE — where we are RIGHT NOW

> **This file is the pick-up point.** It is injected into every new session by the SessionStart
> hook, and it is committed to git so it can never drift from the code it describes.
>
> **Rules for whoever edits this (including future me):**
> 1. **CURRENT STATE ONLY.** No history, no changelog, no "prior — v4.12 did X". History lives in
>    git and in `providers/<P>/docs/tracking/CHANGELOG_<P>.md`. If you find yourself appending a
>    dated section, you are doing it wrong — *replace* the content instead.
> 2. Keep it under ~80 lines. If it grows past that it stops being read, which defeats the point.
> 3. Update it **in the same commit** as the work it describes. A stale state file is worse than none.
> 4. Numbers here must be derived, not remembered — run `tools\portfolio_status.ps1` and
>    `tools\enforce.ps1`.




<!-- BEGIN GENERATED: tools\sync_session_state.ps1 -- do not hand-edit below this line -->
**Last updated:** 2026-08-02 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.23 | ALL-PASS (89 logs) |
| FL_FCIC | v7.15 | NEVER-TESTED -- 109 test(s) owed |
| HI_HCJDC_OFML | v4.14 | ALL-PASS (46 logs) |
| NJ_NJCJIS | v4.15 | ALL-PASS (36 logs) |
| NY_NYSPIN_EJUSTICE | v4.19 | ALL-PASS (64 logs) |
| TX_TLETS | v4.18 | ALL-PASS (89 logs) |
| _14 others_ | -- | never tenant-tested: AZ_AZDPS, CA_CLETS_OCATS, CA_CONTRA_COSTA, CA_eSUN, CA_SAN_LUIS_OBISPO, CA_VENTURA_COUNTY, IL_LEADS_OFML, LA_LEMS, MD_METERS, NM_NMLETS_OFML, OH_LEADS, OR_LEDS, TN_TIES, TX_TLETS_CCH |

**Gate invariant:** `tools\enforce.ps1 -Provider <NAME>` must exit 0 -- `0 FAIL / 0 WARN`.
No PASS count is recorded here on purpose: it moves every time a gate is added, so an
absolute number is guaranteed to go stale and teach the next session to distrust this file.
<!-- END GENERATED -->

---

## ON HOLD / DO NOT RE-RAISE

- **CA_CONTRA_COSTA** -- "on hold until further notice". Parked CLEAN, ENFORCED. All owed work is in its
  `PENDING_UPDATES.txt`, incl. that **JAWS is unbuildable** (devdoc defers to a doc not in `source/`;
  metadata has ZERO JAWS nodes).
- **LA_LEMS** -- its 2 DH-`Attention` devdoc items are DEFERRED by Rob ("handled when we get to them").
  They are the ONLY reason it is BLOCKED. Do not re-raise them as a gap.
- **Jira: ALL updates HELD** until the process is trusted. `enforce` 2r's `[GAP]` is EXPECTED.
- **Form review is Rob's MANUAL gate.** 2k `[INFO] not reviewed` is the steady state. Never prompt.
- TN_TIES prose divergence -- handled when we get to it.

## STATE

**19 of 20 providers ENFORCED 0 FAIL / 0 WARN** (measured by a full sweep, not inferred).
Only **LA_LEMS** is BLOCKED, on its 2 deferred items above.

**ENFORCED is not "done".** Only SIX are tenant-tested (433 logs, four log gates green):
TX v4.18, NY v4.19, NJ v4.15, FL v7.14, HI v4.14, CA_CLETS v2.23.
The other **13 are ENFORCED but NEVER USx-tenant-tested**, each owing a full 5-entity sweep from T1.
**That sweep backlog is now the single largest piece of outstanding work.**

**Portfolio devdoc-UNBUILT: 2** (was 13; both LA_LEMS). **C1 defects: 0.** **Undriveable combos: 0.**

## OPEN DECISIONS -- Rob's call, do not settle unilaterally

1. **AZ_AZDPS driver-licence SCOPE INVERSION.** AZ's devdoc "Basic Queries Supported" section spans
   lines 27-244 and its DL entry is `DriverLicenseQuery` (line 161). `AzAzdpsDriverLicenseQuery`
   (line 393) is OUTSIDE it. Metadata defines BOTH as distinct transactions. **The build implements the
   out-of-Basic one and skips the Basic one**, which is also the only DL transaction supporting image
   requests. Boat has the identical fork and builds the Basic one -- so DL is the LONE inversion.
   Switching rewires the whole Person entity; the v3.3 scope correction was your directive naming
   "DriverLicenseQuery", so your intent may already be that the built query satisfies it.
2. **NCIC-number-keyed combos: BUILT on TX/FL, REGISTERED-as-unbuilt on OH_LEADS.** All three devdocs
   list them Basic-supported. Either (a) worth building -> OH_LEADS has a real 2-combo gap, or (b)
   data-mined and not build scope -> TX and FL carry 3 combos of redundant surface each, on
   TENANT-VERIFIED providers (removing them bumps both and archives 89 + 109 logs).

## NEXT PHYSICAL ACTION

**Tenant testing.** 13 providers are ENFORCED and never swept; that is the whole remaining backlog and
it needs the browser driver (`test_phase2.ps1 -Provider <NAME>`, then `-PostIngest`). Nothing else in
PHASE 1 is owed except the two decisions above.

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

- **NEVER cite another provider as authority.** Only directed links: `CA_CONTRA_COSTA`->`CA_CLETS`,
  `<BASE>_<VARIANT>`->`<BASE>` (`# BASE-SYNC:`). PROOF: CA_CLETS and CA_VENTURA_COUNTY share an
  `IR.QVC{Name}` combo requiring OPPOSITE things -- copying the verified sibling ships a wire-invalid
  request. Gate: `audit_provider_linkage.ps1`. Ask "what does X's OWN authority require?".
- **"silently not transmitted" carries NO information -- run `audit_optional_scope.ps1`.** The same
  sentence was a real dropped value on 4 providers and correct behaviour on 6 in one day. See
  `usx-build` Step 3a for the one question and the severity order.
- **A KEYREF IS NOT A VARIANT.** Scope by (query, keyRef, primaryFieldReference). This decided outcomes
  four separate times: audit_defect_classes, CA_CLETS_OCATS OCNAMQ/AWVEHQ, OH_LEADS registry lookup,
  and audit_optional_scope's own first wrong answer.
- **A gate that reads the WRONG AUTHORITY cannot fail honestly** -- no denominator betrays it. An
  alphabetical `*.xml` glob read a 6-node excerpt as 466-node metadata; a flattened `<Choice>` hid that
  a branch can be a nested `<Set>` GROUP. **When two gates disagree, suspect the one that simplified.**
- **Verify a field EXISTS before treating a devdoc combo as owed**, and validate the probe against a
  known-present field first or a zero means nothing.
- **VERIFY THE EMITTED FILENAME after a version bump.** Three scripts use different `$Version` spacing
  (`[string]$Version`, extra spaces); literal-match bumps silently no-op and rebuild the old version.
- **Document a new tool in the SAME action that creates it.** The undocumented-tool gate caught me FOUR
  times in one session.
- **REPLACE this file's content, never append.** The line gate has caught me twice.
- **`powershell -File` stringifies array args.** **Never grep whole output for `FAIL`** -- anchor on the
  verdict line. **A step that did not run is NOT a pass** -- print the denominator.