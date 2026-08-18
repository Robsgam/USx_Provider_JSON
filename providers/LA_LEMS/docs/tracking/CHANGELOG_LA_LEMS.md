# LA_LEMS -- Changelog

Auto-generated from `LA_LEMS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.1** | Generated: 2026-08-18

---

## v3.1 -- 2026-08-18 -- DP/DQ re-discriminated on STATE -- the parked BUILD_RULES 20b WARN is RESOLVED (WIRE CHANGE)

**CHANGED:** DriverLicenseQuery DP and DQ no longer route on ImageIndicator presence. They now split on
  RegistrationState -- DP gated NOT_EXISTS (in-state), DQ gated EXISTS (out-of-state) -- and their  
  `state` properties are corrected from In/Out on both to DP='In' / DQ='Out'. DP also stopped  
  carrying RegistrationState in any[]; ImageIndicator moved INTO DQ's any[] with a defaults[] twin.  
  Form: the ImageIndicator label 'Image (Y for photo; clear for no-photo DL)' -> canonical 'NCIC Image'.  
**REASON:** THE WARN WAS RIGHT AND THE BUILD WAS WRONG, and it had been parked because both obvious
  fixes looked worse than the warning. Reading the metadata dissolved the dilemma -- the  
  discriminator was never ImageIndicator:  
    <MessageKey name="DP" description="Driver License Photo Inquiry"/>  
    <MessageKey name="DQ" description="Nlets Driver License Query"/>  
    DP <Set> OLN, ImageIndicator  <Any> Attention                     -- NO State field AT ALL  
    DQ <Set> OLN                  <Any> State, State2..State5, ImageIndicator  
  DP is the IN-STATE photo inquiry; DQ is the OUT-OF-STATE Nlets query with up to five destination  
  states. Under the old design BOTH gated on ImageIndicator presence while the form prefills 'Y',  
  so DP always won and DQ WAS PERMANENTLY DEAD -- the officer could never reach Nlets. The form label  
  even instructed "clear" a Y/N dropdown that has no blank option, i.e. it documented an interaction  
  the UI does not offer. RegistrationState carries no initialValue here (LIMITATION #30, label reads  
  "State (leave blank for LA)"), so both branches are now live; verified no other prefilled Person  
  control gates DP/DQ.  
CONSEQUENCES: validator 63P/0F/1W -> 65P/0F/0W (the 0W is REAL, not suppressed); cross-provider  
  2W -> 1W. ImageIndicator is now routing-INERT, so [FLAG:ncic-image-default-y-everywhere] applies  
  to LA with NO carve-out -- LA is no longer a second AZ_AZDPS, and that carve-out only ever existed  
  because of the bad discriminator.  
REGRESSION I INTRODUCED AND THE GATE CAUGHT: widening DQ's any[] made audit_cad FAIL ("combo DQ --  
  missing default for ImageIndicator"). v3.0 was 0 FAIL, so it was mine -- confirmed by running  
  audit_cad against the v3.0 JSON from git rather than assuming. CAD ignores form initialValue, so  
  the defaults[] twin is mandatory. Added; back to 60P/0F/0W.  
DEVDOC-vs-METADATA, REGISTERED WITH EVIDENCE (DriverHistoryQuery Attention, devdoc items #1+#2):  
  the devdoc marks Attention MANDATORY on both DH combinations; the metadata's single DH transaction  
  (lines 3294-3508) defines SIX fields and Attention is not among them. The devdoc resolves itself --  
  metadata says Attention is "Mandatory for all transactions in which it is INCLUDED", so the M  
  marker means mandatory-WHERE-INCLUDED. Decisive corroboration: the IN-SERVICE hand-built Lafayette  
  JSON maps Attention into both DH any[] but has NO Attention form control anywhere, so the mapping  
  is INERT and production never transmits it either -- our build and the running build are  
  WIRE-IDENTICAL here, ours just carries no dead attribute. That file also UNDER-REQUIRES PurposeCode  
  (any[] where metadata puts it in <Set>); we follow the metadata. Registered on the DEVDOC ITEM  
  numbers, never a built keyRef, so no built combination's comparison is suppressed. Branches  
  compared held at 12 before and after; LA over-broad suppressions 0.  
  NOT OWED -- COMMSYS ASKS ARE ON HOLD (Rob 2026-08-18). The same DH section also INVERTS  
  PurposeCode and State (devdoc: State mandatory, [PurposeCode] optional; metadata: PurposeCode in  
  <Set>, State in <Any>). Recorded as a known devdoc error; do NOT raise it, and do NOT list it as  
  owed work. Metadata governs and the build already follows it, so nothing is blocked by the hold.  
  RULING APPLIED HERE (Rob 2026-08-18): "meta data wins over dev doc / built to the spec and ignore  
  the running json." The metadata alone decides this row. The in-service Lafayette JSON is CONTEXT,  
  NOT AUTHORITY -- it happens to agree on Attention, but it also under-requires PurposeCode, so a  
  shipped config shows what someone built and what a provider tolerates, never what the spec  
  requires. The registration reason was rewritten to rest on the metadata alone.  
ALSO REGISTERED: BoatQuery State dropped-optional, adjudicated MECHANICALLY by audit_optional_scope  
  as REGISTER (State is not defined on the firing variant QB{BoatHullIdNumber}, so adding it would  
  OVER-PERMIT; it is defined on the BQ variants, which is why the devdoc's flat list mentions it).  
FLAGS RETIRED, conditions verified: validate-imgind-20b-l30 (asked for a rebuild to re-record  
  scores -- done, and the 20b WARN it predicted is now resolved) and testplan-platformfed-presence  
  (deferred a plan re-emit to this provider's own rebuild -- done, logs/LA_LEMS_TEST_PLAN_v3.1.json,  
  25 tests counted from the emitted plan; LA has 0 logs so nothing was invalidated).  
*** THE ImageQuery PARK IS NOW LIFTED. *** The open item at the top of this file defers devdoc-Basic  
  ImageQuery explicitly because "LA_LEMS is PARKED on Rob's call (the BUILD_RULES 20b WARN must not  
  be silenced)". That WARN is resolved, so the stated reason for the deferral is gone and ImageQuery  
  is genuinely owed at LA's next turn. Note its metadata combination is keyReference="DP"  
  primaryFieldReference="OperatorLicenseNumber" -- the SAME keyRef as DriverLicenseQuery's photo  
  combo, so it must be keyed by (query,keyRef) per BUILD_RULES 13, and it is worth deciding whether  
  the DL-form photo path and ImageQuery are two doors to one transaction before building both.  
NOT TESTED: LA_LEMS has never been imported to any tenant, so this is a WIRE CHANGE on a provider  
  that ships nowhere. 0 logs at any version -- nothing was archived and nothing re-runs.  

## v3.0 -- 2026-07-23 -- v2.5 -> v3.0 methodology galvanization (commit 1fb723db)

**CHANGED:** Galvanized to the single-JSON model (native PascalCase, versioned root filename, legacy
  MC/BASE consolidated).  
**REASON:** Portfolio methodology alignment. Enforce-clean, NOT live-tested. LA_LEMS remains BLOCKED
  on its 2 deferred DH-Attention devdoc items -- that is the only reason. Recovered 2026-08-03  
  from commit 1fb723db; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.0-mc -- 2026-05-05 -- MC multi-card layout variant


## v2.0 -- 2026-05-05 -- Complete rebuild from scratch


## v1.0 -- 2026-04-22 -- Initial standup


## v2.4 -- 2026-05-11 -- LIMITATION elimination pass


## v2.5 -- 2026-05-11 -- purposeCodeDH field type fix

