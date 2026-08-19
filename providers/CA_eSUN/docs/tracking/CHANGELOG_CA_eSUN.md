# CA_eSUN -- Changelog

Auto-generated from `CA_eSUN_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.3** | Generated: 2026-08-19

---

## v2.3 -- 2026-08-17 -- CA-FAMILY HEADER FIX -- <Authentication>/<DeviceId> (Mariposa LIVE failure)

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

## v2.2 -- 2026-08-01 -- 55 devdoc-optional FAILs traced to ONE envelope field (commit 03efbc68)

**CHANGED:** Fixed the single transaction-envelope field whose absence produced 55 separate
  devdoc-optional FAILs. CA_eSUN reached ENFORCED as the 10th green provider.  
**REASON:** The lesson is the ratio -- 55 findings, ONE cause. A finding count is not a defect count,
  and chasing them individually would have been 55x the work. Recovered 2026-08-03 from commit  
  03efbc68; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.1 -- 2026-07-31 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.2 -- 2026-05-07 -- MC multi-card layout + full combo refinement


## v1.1 -- 2026-05-07 -- PlateType/PlateYear defaults + DH-suffix refinement


## v1.0 -- 2026-05-06 -- /07  Initial standup -- 6 basic queries, 17 combos


## v1.5 -- 2026-05-11 -- LIMITATION elimination pass

