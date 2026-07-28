# AZ_AZDPS -- Changelog

Auto-generated from `AZ_AZDPS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.2** | Generated: 2026-07-28

---

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

