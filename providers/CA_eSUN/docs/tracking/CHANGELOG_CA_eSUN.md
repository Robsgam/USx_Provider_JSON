# CA_eSUN -- Changelog

Auto-generated from `CA_eSUN_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.4** | Generated: 2026-08-20

---

## v2.4 -- 2026-08-20 -- LAYOUT COLLAPSE 16->6 CARDS + NAME COMPONENTS + 4 OVER-PERMITS CLEARED

**CHANGED:**
  LAYOUT -- 16 cards -> 6, the uniform shape (usx-cosmetic Step 3b). Vehicle 4->1  
    (OPTIONS/PLATE/VIN/OWNER merged), Person 5->2 (DL + DH, the DH-suffix pool being  
    the isolation mechanism), Firearm 3->1, Article 1 (unchanged), Boat 3->1. Card  
    titles ALL-CAPS and path-carrying; canonical labels (OLN, Vehicle Identification  
    Number, Date of Birth, Sex, Stolen Check, Plate Number/Type/Year); the four  
    prefilled controls take BARE labels with one LABEL-OVERRIDE tag each, one per line.  
  NAME COMPONENTS -- 8 new controls across all FOUR name pools (Person DL NameMiddle/  
    NameSuffix, Person DH NameMiddleDH/NameSuffixDH, Vehicle owner VehNameMiddle/  
    VehNameSuffix, Firearm owner GunNameMiddle/GunNameSuffix). Each is composed into its  
    pool's Name FormatStringRuleHandler sourceField (Last,First,Middle,Suffix) with the  
    separator list grown @(', ') -> @(', ', ' ', ' ') per AP #15, and POOLED into the  
    any[] of all 8 name combinations (DQ.N, QW.N, L1.N, KQ.N, L1.N.DH, QGH.A, QGH.B,  
    VP.D, VP.N). Pool membership is what puts a component on the wire -- AZ_AZDPS is the  
    wire-PROVEN precedent (DOE, JOHN A JR). audit_name_components: 8 C1 -> 0.  
  QW.N BUILT (new combination) -- metadata QW{Name} SET=[CaRequestPurposeCode,BirthDate,  
    Name] with an EMPTY <Any>, i.e. BirthDate is MANDATORY there. The in-state name+DOB  
    search had been riding L1.N's any[], which L1{Name} does not define. Ordered AHEAD of  
    L1.N because L1.N's set[] is a strict subset and first-match would leave it dead.  
    Synthetic split of metadata keyRef QW (LIMITATION #21/#36) -- only the Name branch.  
  OVER-PERMITS CLEARED, 4 -> 0 (all four PRE-EXISTING in v2.3, none introduced here):  
    - QV.P: LicensePlateTypeCode + LicensePlateYear removed from any[] -- metadata  
      QV{LicensePlateNumber} has an EMPTY <Any>. Their CAD defaults[] went with them  
      (they had become wiring class E, inert -- caught by audit_wiring_closure).  
    - L1.N: BirthDate removed from any[] -- it is now MANDATORY on the new QW.N.  
    - L1.N.DH: BirthDateDH removed from any[] -- there is NO DH counterpart of QW to  
      mandate it, so in-state DH name search is name-only, exactly as L1{Name} defines.  
**REASON:**
  CA_eSUN was one of the un-collapsed layouts (16 cards) and the last of the four  
  multi-name-pool providers with no middle-name or suffix control -- its own metadata  
  declares request Name with four components on every query built here, so an officer  
  could not enter two of them and FormatStringRuleHandler could not wire them.  
  The 4 OVER-PERMITTED branches were NOT in the work order; they were folded in because  
  this provider already owed a full sweep, making the fix free of re-test cost, and  
  because CA_eSUN has a non-repo twin running in PRODUCTION at San Diego Sheriff.  
  Building QW.N is the third answer to an over-permit (usx-build 3d): rather than choose  
  between tightening L1.N's any[] and accepting the divergence, giving BirthDate a  
  combination that MANDATES it costs the officer nothing -- the fill routes to QW.N.  
  Signature of a real fix rather than a suppression: branches HELD at 27 while both  
  defect classes went to zero, and reachability rose 19 -> 20 with all combos reachable.  
NOT DONE, and proven rather than asserted:  
  metadata 4{LicensePlateNumber} is NOT built. It differs from QV.P only by  
  LicensePlateTypeCode, which is form-prefilled 'PC' because the sole OOS plate variant  
  RQ{LicensePlateNumber} MANDATES it and metadata defines no looser OOS plate variant --  
  so the prefill is LOAD-BEARING; removing it would leave every out-of-state plate query  
  with no combination able to fire. With it, 4's variable set[] is identical to QV.P's:  
  an exact collision no ordering can separate (BUILD_RULES 24, AZ_AZDPS DQPN/DQP).  
  Registered as rule class 'built-as', NOT 'dropped-combo' -- the existence classes  
  suppress a whole keyRef's comparison, and the first attempt at this row dropped  
  branches 27 -> 26 while silencing nothing (usx-adjudicate Step 4 trap #2).  
SHARED CONTEXT, deliberate: the DL card carries State + Purpose Code and the DH  
  combinations read them too. Cards are visual grouping only -- one form, one field pool  
  -- so a second RegistrationStateDH control would make the officer type the same  
  jurisdiction twice for the same person. RegistrationState is in any[] and in the  
  EXISTS/NOT_EXISTS routing gates of both pools, never in a set[], so sharing it routes  
  DL and DH to the same jurisdiction, which is the correct behaviour for one person.  
GATES: validator 73P/0F/0W | name components 16 examined, 0 blocking | layout flow 6  
  cards / 18 rows / 53 fields / 20 combos, 0 findings | wiring closure 0 breaks in all  
  ten classes | reachability 20/20 | prefill shadow 0 (35 pairs) | fidelity 27 branches  
  0 UNDER / 0 OVER | suppression scope 249 rows / 0 over-broad.  
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

