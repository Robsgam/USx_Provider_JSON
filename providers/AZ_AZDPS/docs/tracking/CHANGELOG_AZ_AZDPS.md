# AZ_AZDPS -- Changelog

Auto-generated from `AZ_AZDPS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.4** | Generated: 2026-08-04

---

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

