# CA_VENTURA_COUNTY -- Changelog

Auto-generated from `CA_VENTURA_COUNTY_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.4** | Generated: 2026-08-19

---

## v2.4 -- 2026-08-17 -- CA-FAMILY HEADER FIX -- <Authentication>/<DeviceId> (Mariposa LIVE failure)

**CHANGED:** Build-Auth called with -IncludeDeviceId, adding <Authentication>/<DeviceId> -- the
  agency-assigned CLETS Terminal Identifier. No form control: DeviceId sits in validate.ps1's  
  $systemSourceFields alongside ORI and Mnemonic, so it is supplied by the platform, not typed.  
**REASON:** Rob 2026-08-17 -- "the header is missing the device id in the auth part and its failing at
  mariposa ... this is required for all ca providers." Applied to ALL SIX CA providers in one pass  
  because the requirement is CA-family-wide rather than per-provider (commit 1a8477c2).  
RECOVERED 2026-08-19: this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild", which is  
  measurably FALSE for a production auth-header fix -- audit_buildnotes_fidelity FAILed it with  
  "GENERIC entry but the JSON CHANGED". The truth was never lost, only misfiled: the commit body  
  and the build script's own header both record it.  
  THIS WAS SYSTEMIC, NOT A ONE-OFF SLIP. The same family-wide pass stubbed the BUILD_NOTES of  
  FIVE of the six CA providers (CA_CLETS_OCATS was recovered earlier the same day, this is the  
  remaining four). A propagation pass that touches N providers writes N stubs, and nothing forced  
  a human to replace any of them -- which is why audit_buildnotes_fidelity exists and why it is  
  worth wiring into the portfolio dashboard rather than leaving it to be run by hand.  

## v2.3 -- 2026-08-01 -- Removed an over-permit INTRODUCED at v2.2, caught by an ADVISORY gate (5e73a120)

**CHANGED:** Removed an over-permitted field introduced by the v2.2 build.
**REASON:** Self-inflicted at v2.2 and caught by an ADVISORY gate -- the argument for reading
  advisories, not only blocking ones. Recovered 2026-08-03 from commit 5e73a120; this entry read  
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

## v1.2 -- 2026-05-07 -- MC multi-card layout + cross-entity combos


## v1.1 -- 2026-05-07 -- PlateType/PlateYear defaults + combo refinement


## v1.0 -- 2026-05-06 -- Initial standup -- 6 basic queries


## v1.4 -- 2026-05-11 -- LIMITATION elimination pass

