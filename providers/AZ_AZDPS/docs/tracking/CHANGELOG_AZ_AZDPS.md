# AZ_AZDPS -- Changelog

Auto-generated from `AZ_AZDPS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.5** | Generated: 2026-08-04

---

## v3.5 -- 2026-08-04 -- DL built on the WRONG TRANSACTION since v3.3 -- switched to devdoc-Basic DriverLicenseQuery

**CHANGED:** (1) DL transaction AzAzdpsDriverLicenseQuery -> DriverLicenseQuery. AZ's metadata defines
  BOTH as separate transactions with DIFFERENT <Requirements>; only the unprefixed one is in the  
  devdoc "Basic Queries Supported" list. (2) ADDED the two photo paths that transaction alone  
  supports -- DQPN (devdoc #2, by Name) and DQP (devdoc #5, by OLN), both implementing metadata  
  DQP, with new ImageIndicator + Requestor controls. (3) LOOSENED the name search to DQN =  
  Set[Name] per Basic DQ{Name}: name alone is now sufficient. (4) DELETED DQSS -- an SSN search the  
  Basic devdoc does not list. (5) STRIPPED the over-permits from DQ{OLN} any[] (BirthDate, SexCode,  
  BadgeNumber -- metadata defines only Any[State]). (6) DH queriesToDeselect re-pointed at the new  
  query name; an entry naming a query that no longer exists is silently INERT.  
**REASON:** THREE OFFICER-VISIBLE CAPABILITIES WERE MISSING, not a naming nicety.
  * NO DRIVER-LICENCE PHOTO EXISTED AT ALL. Metadata DQP is defined ONLY under the Basic  
    transaction, so devdoc #2 and #5 were unreachable: `Requestor` appeared ZERO times in the  
    emitted JSON and the single `ImageIndicator` hit was a QRDM *response* mapping, not a control.  
    The devdoc documents the field explicitly ("Y - Request Driver License Photo").  
  * A NAME-ONLY DL SEARCH WAS IMPOSSIBLE. Devdoc #3 is "Name, [SexCode]" and Basic DQ{Name} is  
    Set[Name] Any[BirthDate, SexCode, State]; the prefixed sibling's DQ{Name} = Set[Name, SexCode,  
    BirthDate] made DOB *and* sex mandatory. An officer holding just a name got nothing.  
  * AN UNAUTHORIZED SSN SEARCH WAS BEING OFFERED (DQSS).  
HOW IT SURVIVED: audit_supported_queries compared each combo's queryLabel against a hand-maintained  
  extract and never the transaction name. 'Driver License' is legitimately on that list, so every  
  combo scored [PASS] -- including "[PASS] combo DQSS: 'Driver License | SocialSecurityNumber' is  
  devdoc-supported", a flatly false statement. Three layers had to align: the label comparison, the  
  extract's PROVISIONAL status (which downgraded mismatches to INFO), and a '$'-anchored devdoc  
  parser. Closed by that tool's CHECK 0 (2026-08-04), which gates on the devdoc itself and blocked  
  this build until fixed. The v3.4 build script had FLAGGED the inversion in its own header comment  
  as an open question for Rob -- so it was known and recorded, just never gated.  
ONE REGISTRY ROW WAS NOT A DIVERGENCE BUT A BUG: 'ACWL | Name | devdoc-optional-unreachable' argued  
  "metadata makes SexCode MANDATORY on every name variant ... there is NO looser one". True of the  
  prefixed sibling, FALSE of the Basic transaction, whose DQ{Name} is exactly that looser variant.  
  Retired. A registration whose premise is scoped to the wrong transaction silences a real defect.  
ORDERING: DQPN, DQP, ACWL, DQN, DQ. DQ{OLN} set[] is a STRICT SUBSET of DQP{OLN} set[], so DQP must  
  precede DQ or the photo path is dead on arrival; DQN set[] is a subset of both ACWL and DQPN.  
  OLN>Name guardrail kept (SSN dropped from the cascade), gate-xor-companion (CHECK 14) preserved.  
ImageIndicator and Requestor carry NO initialValue: both are in DQP set[], i.e. ROUTING fields, and  
  a prefill would make DQP always-match and shadow every plainer DL search (BUILD_RULES 24).  
  RegistrationState keeps initialValue='AZ' -- it is any[]-only here, so it routes nothing.  
The SSN control STAYS: consumed by the RMS person QIDM (firstNameLastNameSocialSecurityNumber,  
  -KeepSsn), which audit_wiring_closure counts as reaching the wire. Dropped from the card TITLE  
  though -- it is no longer a CommSys DL path, and advertising it as one would be a lie on the form.  
ALL 5 ENTITIES RESET at v3.5 (block by version). No re-sweep cost: AZ has never been tenant-tested.  

## v3.4 -- 2026-08-01 -- One real wire fix, six registrations, one gate defect (commit 50e4268c)

**CHANGED:** One real wire fix plus six accepted-divergence registrations; a gate defect found in the
  same pass was corrected. AZ reached ENFORCED (0 FAIL / 0 WARN) as the 9th green provider.  
**REASON:** See commit 50e4268c for the per-finding adjudication. Recovered 2026-08-03 -- this entry
  read "Rebuilt via pipeline.ps1 / Scheduled rebuild", hiding a wire change behind a no-op.  

## v3.3 -- 2026-07-28 -- SCOPE CORRECTION -- build only devdoc "Basic Queries Supported" (direct Rob directive)

**CHANGED:** Removed WMPIWantedPersonInquiry + WMPIMissingPersonInquiry -- they are NOT in the AZ
  devdoc "Basic Queries Supported" section (which is exactly 6: Article/Boat/DH/DL/Gun/VehReg);  
  they live in a separate "Wanted Missing Person Inquiries (WMP-I)" section. Both QIDMs deleted +  
  dropped from the provider bundle; the Person WANTED/MISSING card removed -> Person is now 2 cards  
  (DRIVER LICENSE + DRIVER HISTORY), matching the portfolio. raceCode (the only WMPI-card field the  
  RMS person search still needs: race <- raceCode) RELOCATED to the DL card (bare "Race"). Other  
  WMPI-only fields (NCICNumber, ExpandedName/BirthDate, Age/Height/Weight/Eye/Hair/AreaCode/FormORI,  
  Person relatedHitSearchIndicator) removed with the card. Clears the 18 audit_metadata WARNs (they  
  were the metadata-vs-Basic delta for the out-of-scope WMPI paths).  
**REASON:** Rob -- "stick to basic supported queries section only." I had (wrongly) proposed BUILDING
  the unbuilt WMPI paths to clear the WARNs -- the inverse of the devdoc-authority rule (devdoc Basic  
  list = build scope; metadata is field-authority, not a build checklist). Query-set change (removes  
  2 non-Basic queries); the 6 retained queries' wire is unchanged. ALL 5 ENTITIES RESET at v3.3.  

## v3.2 -- 2026-07-28 -- DEX-1284 convention pass (direct Rob feedback, layout/label-only, NO functional change)

**CHANGED:** Brought AZ from the pre-DEX-1284 methodology in line with FL/NJ/HI/NY/TX/CA.
  STRUCTURE: Vehicle 3 cards -> 1; Boat 3 cards -> 1; Person 7 cards -> 3 (DRIVER LICENSE / DRIVER  
    HISTORY / WANTED-MISSING). Hidden badge (dexStateUserId), RegistrationStateDH SelH, Attention  
    feeder all folded onto the consuming card, preserved exactly.  
  CA-LESSON CHECK: verified from the QIDM set[]/any[] that BOTH WMPI queries source the DL card's  
    shared Name/DOB/Sex -> DL name kept VISIBLE (no orphan); Wanted/Missing name search reads it  
    from the DL card (shared-name design, unchanged wire).  
  LABELS: OLN (was "License Number (DL)/(DH)"); "Related Hit (Y)" -> "Stolen Check"; stripped all  
    "(optional)"/"(DH)" helpers -> bare + LABEL-OVERRIDE; State "(default AZ...)" -> bare "State"  
    (initialValue=AZ kept); enumerated card titles; M.I. -> MI.  
**REASON:** Rob -- "move to arizona, use all lessons learned." Layout/label-only, no combo/QIDM/routing/
  fieldId/default/wire change. AZ has no ImageIndicator (NCIC Image N/A). ALL 5 ENTITIES RESET at  
  v3.2. NOT yet USx-tenant-tested.  

## v3.1 -- 2026-07-24 -- Identifier-priority guardrails hardened (demotion-only -> existence-gate)

**CHANGED:** Added existence-only EXISTS/NOT_EXISTS conditions to the CommSys combos.
  - Vehicle Plate>VIN: ACVRV -> LicensePlateNumber NOT_EXISTS (VIN dropped from ACVR any[])  
  - DL OLN>SSN>Name: DQSS -> OLN NOT_EXISTS; ACWL/DQN -> OLN + SSN NOT_EXISTS  
    (Name/SSN dropped from DQ any[]; Name dropped from DQSS any[])  
  - DH OLN>Name: KQH -> OperatorLicenseNumberDH NOT_EXISTS (DH-suffix pool)  
  - Boat Hull>Reg: ACQB/BQ -> BoatHullIdNumber NOT_EXISTS (Hull dropped from their any[])  
  - WMPI NCIC>Name: ACQW/ACQM -> NCICNumber NOT_EXISTS (NCIC dropped from their any[])  
  - Badge combos ACWL/ACQB/ACQBH -> dexStateUserId EXISTS (metadata-faithful badge gate;  
    stops them shadowing the no-badge DQN/BQ/BQH fallbacks -- verify_build CHECK 16)  
**REASON:** v3.0 had ZERO conditions -- "priority" was demotion-only, which does NOT create mutual
  exclusivity (LIMITATION #1: any[] fields still union into the serialized pool). v3.0 over-sent  
  on every multi-identifier input (plate query also serialized VIN, DL name also OLN+SSN, DH name  
  also OLN, boat reg also Hull, WMPI name also NCIC). v3.1 adopts the proven CA_VENTURA/CA_eSUN  
  existence-gate pattern. Guardrail-hardening only -- query set / keyRefs / DH-suffix / badge  
  feeder / Attention handler / -KeepSsn all unchanged. No State gates (AZ has no in/out keyRef  
  split). ACCEPTED_DIVERGENCES corrected (removed the false "serializes ONLY the intended  
  identifier" claim). NOT yet live-tested at v3.1.  

## v3.0 -- 2026-07-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.3 -- 2026-05-14 -- LIMITATION elimination pass

