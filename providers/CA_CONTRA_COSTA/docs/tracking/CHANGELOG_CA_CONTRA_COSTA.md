# CA_CONTRA_COSTA -- Changelog

Auto-generated from `CA_CONTRA_COSTA_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.4** | Generated: 2026-08-20

---

## v2.4 -- 2026-08-20 -- CLONE SHAPE COMPLETED (7->6 cards) + NAME COMPONENTS + IA.QV OVER-PERMIT CLEARED

Rob 2026-08-20: "build contra costa as a ca clets clone for now. final ruling will be forth  
coming." This is that build. The JAWS / SuperQuery scope question is UNTOUCHED and still open.  
**CHANGED:**
  LAYOUT -- 7 cards -> 6. Only Person needed collapsing (3 -> 2): the standalone  
    'Search Options' card is gone and its State + Purpose Code row is now the DL card's last  
    row as shared context. Titles are now ALL-CAPS and path-carrying on all six cards.  
    'License Number' -> 'OLN', 'CII' -> 'CII Number', 'Hull ID' -> 'Hull ID Number'.  
  NAME COMPONENTS -- 10 findings closed. FOUR of the five Name composites share ONE field  
    pool (Vehicle-owner, DL, Gun-owner, Boat-owner all source ('NameLast','NameFirst')), so  
    NameMiddle/NameSuffix controls were added to those four FORMS and NameMiddleDH/  
    NameSuffixDH to the DH card. All five composites extended, separators grown  
    @(', ') -> @(', ', ' ', ' ') (AP #15), and the components POOLED into the any[] of ALL  
    EIGHT name combinations (IN.VP, NLTS.DQ.N, IR.QVC.N, IN.L1, NLTS.KQ.N, IG.QGH.A,  
    IG.QGH.B, NLTS.BQ.N). audit_name_components: 10 C1 -> 0, 20 components examined.  
    Three owner rows were split so all four components sit together per L8 (Vehicle, Firearm  
    and Boat each had First/Last sharing a row with unrelated qualifiers).  
  IA.QV any[] narrowed to RegistrationState ONLY, and the PlateType / PlateYear CAD defaults  
    removed with the fields they applied to. OVER-PERMITTED 7 -> 3, branches HELD at 27,  
    wiring closure still 0 breaks in all ten classes.  
WHY THAT ONE WAS SAFE TO FIX WHILE THE RULING IS PENDING, and how I checked:  
  read from THIS provider's OWN raw <Requirements> -- not imported from a sibling, because  
  audit_provider_linkage exists precisely for the case where CA_CLETS and  
  CA_VENTURA_COUNTY require OPPOSITE things on an identically-named combo:  
    IA.QV{plate}   = Set[CaRequestPurposeCode, LicensePlateNumber, Any[State]]  
    NLTS.RQ{plate} = Set[PurposeCode, plate, LicensePlateTypeCode, LicensePlateYear, State,  
                          Any[VehicleMakeCode, VehicleYear]]  
  NLTS.RQ.P IS built, so nothing the metadata allows was lost -- fill State and it fires and  
  carries all four fields. The pending ruling concerns the UNBUILT JAWS / SuperQuery  
  transactions, not the built VehicleRegistration path, so this does not pre-empt it.  
  Also corrected a stale code comment that called IA.QV a "catchall ... for any plate type  
  not matched above": NO IV.4x combination is built on this provider, so nothing above it  
  matches a plate type. The 13 IV.4x variants discriminate on PlateType VALUES and routing  
  tests PRESENCE, so they cannot be separated -- the same structural shadow already recorded  
  for CA_CLETS and re-confirmed on CA_VENTURA_COUNTY v2.5 today.  
STILL OPEN, DELIBERATELY -- 4 UNDER-REQUIRED / 3 OVER-PERMITTED, all PRE-EXISTING and all in  
the CA_CLETS-family Choice-branch area that Rob's forthcoming ruling bears on:  
    IR.QVC[alt1/2] -> IR.QVC.N  UNDER-REQUIRED: BirthDate (built any[])  
    IR.QVC[alt2/2] -> IR.QVC.N  UNDER-REQUIRED: Age (built any[])  
    NLTS.DQ        -> NLTS.DQ.N UNDER-REQUIRED: SexCode (ABSENT); BirthDate (built any[])  
    IR.QVC         -> IR.QVC.O / .C / .S  OVER-PERMITTED: Age  
  NOT touched. These are exactly the Choice-position questions where CLAUDE.md records that  
  CA_CLETS's IR.QVC has four metadata variants with Choice[Age|BirthDate] inside <Any> while  
  CA_VENTURA_COUNTY's single variant puts it inside <Set> -- opposite answers on the same  
  keyRef. Adjudicating them for CONTRA_COSTA while its spec authority is itself the subject  
  of a pending ruling is how the wrong fix gets shipped. Verified they are pre-existing: none  
  involves a name component, so this build did not introduce any of them.  
GATES: validator 79P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 20 examined | layout flow 0 findings | wiring closure 0 breaks in all ten  
  classes | reachability 27/27 | prefill shadow 0 (66 pairs) | fidelity 27 branches  
  4 UNDER / 3 OVER (all listed above, all deferred to the ruling).  
NOT TESTED: never tenant-tested. Owes an import and a first-ever sweep.  

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

## v2.2 -- 2026-07-31 -- Carried BOTH CA_CLETS v2.22 wire defects -- fixes propagated (commit 22801419)

**CHANGED:** Propagated both CA_CLETS v2.22 wire fixes, which this provider also carried.
**REASON:** CA_CONTRA_COSTA is built as a CA_CLETS copy plus Contra Costa's JAWS queries (the one
  explicitly sanctioned cross-provider link), so a CA_CLETS wire defect is inherited BY  
  CONSTRUCTION. Propagation is required, not optional. Recovered 2026-08-03 from commit 22801419;  
  this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.1 -- 2026-07-24 -- Race re-added to RMS person search (mirrors CA_CLETS v2.16)

**CHANGED:** Dropped -SkipRace from Build-RmsBundle (raceCode now in the RMS Person any[]);
         raceCode form field -> attributeTypeId='RACE'+codeTypeProvider='NIBRS' (SexCode  
         dual-consumer pattern, clears AP #11).  
**REASON:** Rob (2026-07-24) -- harmonize the CA family so CC offers race in the RMS person search
        (was -SkipRace, inherited from the CA_CLETS copy). Still NOT USx-tenant-tested.  

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild
