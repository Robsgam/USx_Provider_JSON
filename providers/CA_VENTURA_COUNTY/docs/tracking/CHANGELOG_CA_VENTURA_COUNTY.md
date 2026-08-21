# CA_VENTURA_COUNTY -- Changelog

Auto-generated from `CA_VENTURA_COUNTY_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.5** | Generated: 2026-08-20

---

## v2.5 -- 2026-08-20 -- LAYOUT COLLAPSE 20->6 CARDS + NAME COMPONENTS + 10 PRE-EXISTING FIDELITY FINDINGS CLEARED

**CHANGED:**
  LAYOUT -- 20 cards -> 6, the widest collapse in the portfolio. Vehicle 4->1, Person 5->2  
    (DL + DH), Firearm 3->1, Article 3->1, Boat 5->1. Titles ALL-CAPS and path-carrying.  
    The "(DH)" label suffixes are dropped -- the card title now says DRIVER HISTORY, so  
    repeating it on every control was noise; the fieldIds keep their DH suffix, which is  
    what actually isolates the pool. 'Race' -> 'Race (optional)' (BUILD_RULES 11).  
  NAME COMPONENTS -- 4 new controls covering 10 findings, because FOUR of the five Name  
    composites share ONE field pool: Vehicle-owner (IN.VP), DL, Gun-owner (IG.QGH) and  
    Boat-owner (NLTS.BQ.N) all source ('NameLast','NameFirst'), so NameMiddle/NameSuffix  
    serve all four; the DH pool gets NameMiddleDH/NameSuffixDH. All FIVE composites had  
    their sourceField extended and separators grown @(', ') -> @(', ', ' ', ' ') (AP #15),  
    and the components were POOLED into the any[] of ALL TEN name combinations (IN.VP,  
    NLTS.DQ.N, IR.QVC.NB, IR.QVC.NA, ID/IN.L1, KQ x2, IG.QGH.A, IG.QGH.B, NLTS.BQ.N).  
    audit_name_components: 10 C1 -> 0, 20 components examined.  
  FIDELITY 1 UNDER / 9 OVER -> 0 / 0, branches HELD at 45 then 44 by design. All ten were  
    PRE-EXISTING in v2.4 and none involved name components -- verified before touching them.  
    - IA.QV any[] shed LicensePlateYear, VehicleMakeCode and vehicleYear. Raw <Requirements>:  
      IA.QV{plate} = Set[CaRequestPurposeCode, LicensePlateNumber, Any[State]]. Those three  
      fields belong to the OUT-OF-STATE variant, NLTS.RQ{plate} =  
      Set[PurposeCode, plate, LicensePlateTypeCode, LicensePlateYear, State,  
      Any[VehicleMakeCode, VehicleYear]], which IS built as NLTS.RQ.P. So nothing the  
      metadata allows was lost: fill State and NLTS.RQ.P fires and carries all three.  
      The 9 count is 3 fields x 3 metadata alternatives (IA.QV, IV.4A, IV.4) all pairing  
      to the one built IA.QV.  
    - Its LicensePlateYear CAD default[] went with the field: once PlateYear left the any[]  
      the default could never be applied (audit_wiring_closure class E). Caught immediately,  
      which is the second time in this session that tightening an any[] left an inert default.  
REGISTERED, not built -- IV.4, and the reason is STRUCTURAL rather than "the devdoc omits it":  
  IV.4{plate} = Set[PurposeCode, plate, MessageKeyModifier], all mandatory, no <Any>.  
  MessageKeyModifier occurs EXACTLY ONCE in the entire XML -- inside this one combination --  
  with no ValueList, no description and no devdoc entry, so there is no authority for what an  
  officer would type and a control would leave the combination unfillable (wiring class C).  
  Registering it removes a FALSE pairing: fidelity was matching this unbuilt alternative to  
  built IA.QV (both {LicensePlateNumber}, so the identifier-intersection guard cannot reject  
  it) and reporting MessageKeyModifier as UNDER-REQUIRED against a combo whose own variant  
  never mentions it. Branches 45 -> 44 deliberately; the branch that left was comparing two  
  unrelated things. 0 over-broad suppressions across 251 rows, measured before and after.  
ALSO RECORDED: the IV.4x family (IV.4A/4C/4E/4F/4H/4I/4K/4L/4M/4P/4S/4T, IL.A1) discriminates  
  on LicensePlateTypeCode VALUES ('AP', 'CO/TK/TR', 'MC', 'RE/PE', 'TL', 'PC/AQ', 'AT', 'DX',  
  'EX', 'DL', 'AR', 'IP', 'TM'). Routing tests field PRESENCE, not value, so none of them can  
  be separated from each other or from IA.QV -- the same structural shadow CLAUDE.md already  
  records for the CA_CLETS sibling. Not a gap to close.  
GATES: validator 82P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 20 examined | layout flow 0 findings | wiring closure 0 breaks in all ten  
  classes | reachability 30/30 | prefill shadow 0 (80 pairs) | fidelity 44 branches 0 UNDER  
  / 0 OVER.  
NOT TESTED: never tenant-tested. Owes an import and a first-ever sweep.  

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

