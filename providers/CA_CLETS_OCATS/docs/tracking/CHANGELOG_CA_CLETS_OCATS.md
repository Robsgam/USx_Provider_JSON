# CA_CLETS_OCATS -- Changelog

Auto-generated from `CA_CLETS_OCATS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.6** | Generated: 2026-08-18

---

## v2.6 -- 2026-08-18 -- EVERY metadata variant of every devdoc-Basic query is now BUILT -- 4K and VC added

**CHANGED:**
  - BUILT 4K  = set[caRequestPurposeCode, LicensePlateNumber, LicensePlateTypeCode], ordered ahead  
    of `4` (whose set[] is a strict subset). Carries defaults[] LicensePlateTypeCode='PC' for CAD.  
  - BUILT VC  = set[caRequestPurposeCode, NameLast, NameFirst, businessIndicator], ordered ahead of  
    VP (strict subset). New BusinessIndicator attribute + a "Business Owner" Y/N control.  
  - `4` any[] and `4V` any[] emptied to match their metadata <Any>, which is EMPTY on both.  
  - REMOVED the LicensePlateTypeCode form prefill ('PC'); label "Plate Type (optional)" -> "Plate Type".  
  - ROW_VEH_NAME_1 widened 6/6 -> 4/4/4 for the third control.  
**REASON:** Rob 2026-08-18 -- "not sure why you stopped short of making all the queries combinations
  worked from the dev doc and metat data  proceed with that directive until complete with a high  
  level of confidemnce." v2.5 had REGISTERED 4K and VC as dropped-combo skips. That was stopping  
  short: both are variants of VehicleRegistrationQuery, which IS devdoc-Basic-supported, and the  
  metadata defines them and their mandatory fields. Devdoc = QUERY authority (is this query in  
  scope), metadata = FIELD authority (what the query requires). A variant of an AUTHORIZED query  
  gets BUILT, not skipped -- even where the devdoc's flat combination list never enumerates it.  

## v2.5 -- 2026-08-18 -- RQ.P: LicensePlateYear was OPTIONAL where the metadata MANDATES it

**CHANGED:** RQ.P `LicensePlateYear` moved from `any[]` into `set[]`, so its combination now reads
  set[caRequestPurposeCode, LicensePlateNumber, LicensePlateYear, RegistrationState].  
  Nothing else moved: the CAD `defaults[]` twin (LicensePlateTypeCode='PC', LicensePlateYear=  
  <current year>) and the registered RegistrationState promotion are unchanged.  
**REASON:** audit_requirement_fidelity reported
  "VehicleRegistrationQuery / RQ -> built 'RQ.P' UNDER-REQUIRED: LicensePlateYear (built any[])",  
  the severity-1 class -- a combination that can fire WITHOUT a field its metadata variant makes  
  mandatory sends a request the metadata calls INVALID.  
  READ FROM THE RAW XML <Requirements> PER <Combination>, the sanctioned exception:  
    RQ{LicensePlateNumber} = Set[CaRequestPurposeCode, LicensePlateNumber, LicensePlateYear]  
                             Any[State, LicensePlateTypeCode]  
  So Year is MANDATORY on the RQ plate path and State is merely OPTIONAL -- we had it exactly  
  inverted (State in set[], Year in any[]). The State half is DELIBERATE and already registered  
  ("OOS plate combo requires State; EXISTS-gated", 2026-07-23); only the Year half was a defect.  
  NOT REGISTERABLE: a demoted-to-any row is only honest when a LOOSER metadata variant permits the  
  field's absence, and RQ has no second plate variant. A plate-only search is legal under `4` and  
  `QV{plate}`, but those are DIFFERENT keyRefs on a different transaction -- they cannot license an  
  incomplete RQ.  

## v2.4 -- 2026-08-17 -- CA-FAMILY HEADER FIX -- <Authentication>/<DeviceId> (Mariposa LIVE failure)

**CHANGED:** Build-Auth called with -IncludeDeviceId, adding <Authentication>/<DeviceId> -- the
  agency-assigned CLETS Terminal Identifier. No form control: DeviceId sits in validate.ps1's  
  $systemSourceFields alongside ORI and Mnemonic.  
**REASON:** Rob 2026-08-17 -- "the header is missing the device id in the auth part and its failing at
  mariposa ... this is required for all ca providers." Applied to all six CA providers in one pass  
  because the requirement is CA-family-wide, not per-provider (commit 1a8477c2).  
RECOVERED 2026-08-18: this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild", which is FALSE  
  for a production auth-header fix -- audit_buildnotes_fidelity FAILed it ("GENERIC entry but the  
  JSON CHANGED vs v2.3"). The truth was never lost, only misfiled: the build script's own v2.4  
  header comment documented it. This is the SECOND stub recovered on this provider (v2.3 was the  
  first) -- the pipeline stamps a stub and nothing forces a human to replace it.  

## v2.3 -- 2026-08-02 -- Wire ArticleCategory; fix an Authorization size read from the wrong transaction (5f010dd5)

**CHANGED:** ArticleCategory wired so the officer's value is transmitted, and an Authorization field
  size corrected -- it had been read from the WRONG transaction's metadata.  
**REASON:** The size error is the instructive half: a field definition taken from a sibling
  transaction looks valid and is not. Recovered 2026-08-03 from commit 5f010dd5; this entry read  
  "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.2 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.0 -- 2026-05-07 -- Initial build

**CHANGED:** New provider build from CA_CLETS_OCATS.xml metadata (System CLETS_OCATS v21).
         Based on CA_CLETS patterns with OCATS-specific adaptations.  
SCOPE:   5 basic queries (VehicleRegistrationQuery, DriverLicenseQuery, GunQuery,  
         ArticleSingleQuery, BoatQuery). No DriverHistoryQuery (no KQ MessageKeys).  
COMBOS:  19 total across 5 QIDMs.  
DESIGN:  Single-card BASE + multi-card MC. CaRequestPurposeCode hidden on all forms.  
         VP owner search on Vehicle. yyyyMMdd date format per CA standard.  
VALIDATOR: BASE 63P/0F/0W/2LIM | MC 63P/0F/0W/2LIM | Verify CLEAN  

## v1.2 -- 2026-05-11 -- LIMITATION elimination pass

