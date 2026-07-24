# AZ_AZDPS -- Changelog

Auto-generated from `AZ_AZDPS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.1** | Generated: 2026-07-24

---

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

