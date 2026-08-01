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
**Last updated:** 2026-08-01 (generated) | **Branch:** `main`

## Tenant-test state -- GENERATED, do not hand-edit

Derived from `_test_status_lib.ps1`, the same primitives `portfolio_status.ps1` and the
CLAUDE.md table use, so these three can never disagree. Re-run `tools\sync_session_state.ps1`.

| Provider | Ver | State |
|---|---|---|
| CA_CLETS | v2.23 | ALL-PASS (89 logs) |
| FL_FCIC | v7.14 | ALL-PASS (109 logs) |
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

- **CA_CONTRA_COSTA** -- "on hold until further notice" (2026-07-31). Parked CLEAN at v2.2. All owed
  work is in its `PENDING_UPDATES.txt`, incl. **JAWS is unbuildable** (devdoc defers to a doc not in
  `source/`; metadata has ZERO JAWS nodes).
- **Jira: ALL updates HELD** until the process is trusted. `enforce` 2r `[GAP]` is EXPECTED.
- **Form review is Rob's MANUAL gate.** 2k `[INFO] not reviewed` is the steady state. Never prompt.
- LA_LEMS `DQ` + its 2 DH-`Attention` devdoc items, TN_TIES prose divergence -- "handled when we get
  to them."

## STATE

**10 providers ENFORCED 0 FAIL / 0 WARN.** Six are also tenant-tested (433 logs, four log gates
green): TX v4.18, NY v4.19, NJ v4.15, FL v7.14, HI v4.14, CA_CLETS v2.23. Four are ENFORCED but **NEVER tenant-tested** -- CA_VENTURA_COUNTY v2.2,
CA_CLETS_OCATS v2.1, AZ_AZDPS v3.4 and CA_eSUN v2.2 -- each owes a full 5-entity sweep from T1. ENFORCED is not "done"; it means the build matches its sources.
6 PHASE-1 audited and BLOCKED as expected (never tested): LA_LEMS, MD_METERS, TN_TIES, OH_LEADS,
NM, OR_LEDS, IL (minus CA_eSUN, now green). **2 unaudited**: CA_SAN_LUIS_OBISPO, TX_TLETS_CCH. Plus CA_CONTRA_COSTA (on hold).

**Portfolio devdoc-UNBUILT: 2** (was 13) -- both are LA_LEMS's deferred DH-`Attention` items.
**audit_defect_classes C1: 0 portfolio-wide.** Simulator-undriveable combos: 0 (was 36).

## OPEN PORTFOLIO QUESTION -- Rob's call, do not settle unilaterally

**NCIC-number-keyed combos: BUILT on TX/FL, REGISTERED-as-unbuilt on OH_LEADS.** All three devdocs
list them as Basic-supported. Either (a) they are worth building -> OH_LEADS has a real 2-combo gap,
un-register it; or (b) they are data-mined and should not be built -> TX and FL each carry 3 combos
of redundant surface on TENANT-VERIFIED providers (removing them bumps both and archives 89+109
logs). BUILD_RULES says the data-mined list is NOT build scope in either direction until the
platform confirms semantics -- which is why this needs deciding, not inferring.

Also owed: **CA_eSUN's 55 devdoc-optional FAILs.** Very likely the same load-bearing `purposeCode`
prefill that took CA_VENTURA_COUNTY from 8 FAIL to 0 -- but confirm against CA_eSUN's OWN metadata
(every combo must require it) before touching it.

## NEXT PHYSICAL ACTION

1. **AZ_AZDPS DRIVER-LICENCE SCOPE INVERSION -- Rob's call, do not settle unilaterally.** AZ's devdoc
   "Basic Queries Supported:" section (line 25) spans lines 27-244 and its DL entry is
   `DriverLicenseQuery` (line 161). `AzAzdpsDriverLicenseQuery` (line 393) is OUTSIDE it. Metadata
   defines BOTH as distinct transactions. **The build implements the out-of-Basic one and skips the
   Basic one**, which is also the only DL transaction supporting image requests
   (`ImageIndicator="Y"` + `Requestor`). Boat has the identical fork (BoatQuery 66 Basic vs
   AzAzdpsBoatQuery 337) and correctly builds the Basic one -- so DL is the LONE inversion, which is
   why it reads as an oversight rather than policy. Switching rewires the whole Person entity, and the
   v3.3 scope correction was a direct Rob directive naming "DriverLicenseQuery", so his intent may
   already be that the built query satisfies it. NOT a parser defect -- I claimed that first and it was
   wrong; the two devdoc blocks simply belong to two different query headings.
2. **CA_SAN_LUIS_OBISPO and TX_TLETS_CCH** are the last two never-audited providers. TX_TLETS_CCH is a
   VARIANT -- check its `# BASE-SYNC:` marker against TX_TLETS first (audit_variant_sync), since a
   variant must not drift from its base.
3. Adjudicate remaining findings on the other audited providers (FIX-vs-REGISTER, `usx-build` Step 3).

## RULES I HAVE BROKEN -- READ BEFORE BUILDING

- **NEVER cite another provider as authority or precedent.** Only directed links:
  `CA_CONTRA_COSTA`->`CA_CLETS`, `<BASE>_<VARIANT>`->`<BASE>` (`# BASE-SYNC:`). PROOF it matters:
  CA_CLETS and CA_VENTURA_COUNTY share an `IR.QVC{Name}` combo and require OPPOSITE things (4
  variants with the Choice in `<Any>` vs 1 with it in `<Set>`) -- copying the verified sibling ships
  a wire-invalid request. Gate: `audit_provider_linkage.ps1`. Reframe "should X match its siblings?"
  as "what does X's OWN authority require?".
- **A gate that reads the WRONG AUTHORITY cannot fail honestly** -- no denominator betrays it. Seen
  twice in one tool: an alphabetical `*.xml` glob (6-node excerpt read as 466-node metadata) and a
  flattened `<Choice>` (a branch can be a nested `<Set>` GROUP). **When two gates disagree, suspect
  the one that simplified its authority.**
- **Verify a field EXISTS before treating a devdoc combo as owed** -- and validate the probe against
  a known-present field, or a zero means nothing. AZ's devdoc lists two fields its metadata defines
  0 of 1896 times (not buildable); OCATS's defines its 39 times (buildable).
- **After a DIRECT build-script run, reset the test package AND sync docs.** `pipeline.ps1` does it;
  the provider script does not. Now mechanised in `Write-ProviderJson`.
- **Use the Edit tool for multi-line text, never `.Replace()`** -- CRLF no-ops silently. Broken 3x.
- **Before building a new check, ask which existing gate already owns the question.** 3 of 4
  `audit_defect_classes` classes duplicated existing gates as the weaker copy.
- **`powershell -File` stringifies array args**; run the array call in-session instead.
- **Never grep whole tool output for `FAIL`** -- anchor on the verdict line.
- **A step that did not run is NOT a pass.** Always print the denominator.
- **REPLACE this file's content, never append.** The 120-line gate caught me appending again.