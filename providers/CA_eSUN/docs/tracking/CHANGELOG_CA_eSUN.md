# CA_eSUN -- Changelog

Auto-generated from `CA_eSUN_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.6** | Generated: 2026-08-27

---

## v2.6 -- 2026-08-27 -- FOUR SILENTLY-DISCARDED-FIELD DEFECTS CLOSED: driver history stops dropping DOB

                and Sex, and the plate search stops dropping plate type and year  
**CHANGED:**
  KQ.N (DriverHistoryQuery) -- `RegistrationState EXISTS` condition REMOVED.  
  RQ.P (VehicleRegistrationQuery) -- RegistrationState DEMOTED set[] -> any[], EXISTS gate REMOVED.  
  4    (VehicleRegistrationQuery) -- NEW COMBINATION, set[caRequestPurposeCode, LicensePlateNumber,  
       LicensePlateTypeCode], ordered between RQ.P and QV.P.  
  FORM -- LicensePlateTypeCode / LicensePlateYear prefills REMOVED (combo defaults[] kept for CAD).  
  L1.N.DH and QV.P keep their NOT_EXISTS gates -- see below, both deliberate.  
**REASON** -- the same anti-pattern twice, plus one missing variant:
  metadata KQ{Name} = Set[CaRequestPurposeCode, Name, SexCode, BirthDate]  
                      Any[Attention, PurposeCode, State]        -- State OPTIONAL, not a fork.  
  metadata RQ{plate} = Set[CaRequestPurposeCode, plate, LicensePlateTypeCode, LicensePlateYear]  
                      Any[State]                                -- State OPTIONAL, not a fork.  
  Gating both on State made them reachable only out of state, so devdoc DriverHistoryQuery #3  
  (BirthDate, Name, SexCode) and VehicleRegistrationQuery #8 (plate, type, year) fell through to  
  L1.N.DH and QV.P respectively -- and those looser combos do not carry the extra fields, so the  
  officer's DOB+Sex and plate type+year were SILENTLY DISCARDED. Never gate on a field the metadata  
  merely permits: TN_TIES KQ.N, NM RQ.P v2.7, CA_CLETS_OCATS DQ.N v2.8, MD_METERS ZLRG.P v2.3.  
  devdoc #2 "(mand) LicensePlateNumber, LicensePlateTypeCode" had NO built counterpart at all --  
  metadata 4{plate} existed and was never built, so that fill also fell to QV.P and lost its type.  
  Built per Rob's 2026-08-18 directive: build every metadata variant of an in-scope query.  
THE PREFILL HAD TO GO OR THE FIX WOULD HAVE KILLED TWO COMBOS: type+year are exactly what separates  
  RQ{plate} from 4{plate} from QV{plate}. Prefilled, they are always present, so RQ.P would have  
  won every plate fill and BOTH 4 and QV.P would have been dead on arrival (BUILD_RULES 24).  
  Un-prefilled, specificity routes all three: plate+type+year -> RQ.P, plate+type -> 4, plate ->  
  QV.P. This is the OOS-only plate-card exception already recorded for HI v3.0, and it is outside  
  Rob's keep-the-convention ruling by that ruling's own terms (routing depends on these fields).  
  Verified: reachability 21/21 ALL reachable, prefill shadow 0 FAIL / 41 pairs.  
TWO NOT_EXISTS GATES KEPT ON PURPOSE, both for the same reason: metadata L1{Name} and QV{plate}  
  have EMPTY <Any> elements and define no State, so removing their gates would let a Name+State or  
  plate+State fill match them and drop the State silently -- this very defect, one combination over.  
ONE FINDING REGISTERED RATHER THAN BUILT: devdoc #6 "(mand) plate [opt State]" now fires nothing.  
  No metadata plate variant accepts plate+State (QV and 4 have empty <Any>; only RQ permits State  
  and it requires type+year), so it is devdoc-legal and metadata-impossible. An honest no-fire beats  
  a silently narrowed query. Recorded as VehicleRegistrationQuery | QV.P | State.  
REGISTRY ROW RETIRED: `DriverLicenseQuery | L1.N | BirthDate | demoted-to-any`. It was correct and  
  it was masking a TOOL defect -- audit_requirement_fidelity did not descend into a <Choice> nested  
  inside <Any>, fixed the same day. Measured inert before retiring (27 branches / 0 / 0 with and  
  without it). Kept as commented history.  
GATES: validator 73P -> 75P / 0F / 0W - audit_devdoc_optionals 4 FAIL -> 0 - fidelity 27 branches /  
  0 UNDER / 0 OVER UNCHANGED - reachability 21/21 - prefill shadow 0 FAIL - enforce 0 FAIL / 0 WARN.  
COST: NONE. CA_eSUN has never been tenant-tested (0 logs at any version); no Foundation, no LIVE.  

## v2.6 -- 2026-08-27 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.5 -- 2026-08-20 -- CORRECTS v2.4 -- I DROPPED A LEGAL OPTIONAL ON THE STRENGTH OF A BROKEN PROBE

**CHANGED:**
  L1.N any[] -- BirthDate RESTORED. v2.4 removed it as an over-permit. It is not one.  
  QW.N any[] -- SexCode ADDED. Metadata QW{Name} defines Any[Age, SexCode]; SexCode has a  
    control on the DL card, Age does not, so leaving SexCode out silently discarded an  
    officer's Sex entry whenever the in-state name+DOB path fired.  
WHAT WENT WRONG, precisely:  
  v2.4's note asserted "EVERY <Any> in this metadata is EMPTY". That was FALSE, and it was  
  my own probe, not the metadata. In this schema <Any> is NESTED INSIDE <Set>:  
    <Set><Field CaRequestPurposeCode/><Field Name/><Any><Choice><Field Age/><Field  
    BirthDate/></Choice></Any></Set>  
  so a PowerShell `$c.Requirements.Any` lookup returns NOTHING for every combination in the  
  file. I read that as "no optionals anywhere" and tightened three any[] pools on it.  
  Dumping OuterXml instead settles each one, and only ONE of the three was wrong:  
    DL  L1{Name}  = Set[PurposeCode, Name, Any[Choice[Age|BirthDate]]]  -> BirthDate IS a  
        legal optional (a Choice inside <Any> makes both branches optional). v2.4 WRONG.  
    DH  L1{Name}  = Set[PurposeCode, Name]  -- no <Any> AT ALL. v2.4 correct: BirthDateDH  
        stays out of L1.N.DH. The DL and DH siblings are NOT symmetric.  
    QV{LicensePlateNumber} = Set[PurposeCode, LicensePlateNumber] -- no <Any>. v2.4 correct:  
        LicensePlateTypeCode/LicensePlateYear stay out of QV.P, and their CAD defaults with them.  
  QW.N itself remains right and remains worth having -- QW{Name} genuinely makes BirthDate  
  MANDATORY, so the in-state name+DOB search has its own combination instead of relying on  
  an optional. Ordering (QW.N ahead of L1.N) is unchanged and still required.  
WHY IT WAS CAUGHT AT ALL, and it was not this provider:  
  the same broken probe was pointed at TN_TIES an hour later and printed ANY=[] for a  
  combination whose registry row (written 08-19) explicitly quoted Any[InquiryTypeIndicator].  
  A gate disagreeing with a registry row is the cheap signal; the probe lost.  
REGISTERED, not re-fixed: audit_requirement_fidelity still reports  
  "built 'L1.N' OVER-PERMITTED: BirthDate" because it enumerates <Any>'s direct <Field>  
  children and does not descend into a nested <Choice>. The raw XML says otherwise, so the  
  BUILD is right and the GATE has a gap. Recorded as rule 'demoted-to-any' scoped to keyRef  
  L1.N. Deliberately NOT registered against the bare metadata keyRef 'L1' -- the prefix  
  bridge would mute L1.N, L1.O, L1.N.DH and L1.O.DH, four branches, to silence one line.  
  Fixing the gate is a shared-tool change owing the 6-provider regression fixture and a  
  20-provider sweep; some of the portfolio's 34 OVER-PERMITTED may be this same false class.  
GATES: validator 73P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 16 examined | layout flow 0 findings | wiring closure 0 breaks | reachability  
  20/20 | prefill shadow 0 (35 pairs) | fidelity 27 branches 0 UNDER / 1 OVER (the gate gap  
  above, registered) | suppression scope 250 rows / 0 over-broad.  
NOT TESTED: never tenant-tested. v2.4 was never imported, so nothing was lost to this bump.  

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

