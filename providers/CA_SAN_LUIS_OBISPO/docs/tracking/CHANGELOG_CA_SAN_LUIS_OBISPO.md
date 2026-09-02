# CA_SAN_LUIS_OBISPO -- Changelog

Auto-generated from `CA_SAN_LUIS_OBISPO_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.8** | Generated: 2026-09-02

---

## v2.8 -- 2026-09-02 -- THE OUT-OF-STATE PLATE SEARCH STOPS OFFERING THE VIN SIBLING'S OPTIONALS

**CHANGED:** RQ.P any[VehicleMakeCode, vehicleYear] REMOVED -- RQ.P now carries NO any[] at all.
  set[] and defaults[] unchanged. RQ.V, QV.V and 4.P untouched.  
**REASON:** metadata RQ{LicensePlateNumber} = Set[LicensePlateNumber, LicensePlateTypeCode,
  LicensePlateYear, State] and declares NO <Any> WHATSOEVER. VehicleMakeCode and VehicleYear are  
  optionals of the VIN sibling RQ{VehicleIdentificationNumber} (Any[VehicleMakeCode,  
  VehicleYear]), which legitimately keeps them. The devdoc agrees independently: "#3 (Out)  
  LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear, State" carries NO BRACKETS, so the  
  out-of-state plate search has no optionals at all. Both authorities, same answer.  
  Impact while live: every out-of-state plate query COULD transmit two fields that transaction  
  does not define (LIMITATION #1 family). Never actually sent -- this provider has never been  
  imported -- so the exposure is zero and the correction is free.  
HOW IT HID, AND IT IS NOT A CA_SAN_LUIS_OBISPO PROBLEM: audit_requirement_fidelity collected the  
  metadata <Any> pool keyed on "transaction|keyRef" rather than the full  
  "transaction|keyRef|primaryFieldReference" triple, so EVERY alternative of a keyRef inherited  
  its SIBLING alternatives' optionals. The plate variant silently inherited the VIN variant's  
  <Any> and the over-permit read as legal. A KEYREF IS NOT A VARIANT -- this repo's most-repeated  
  rule, violated inside the gate itself. Fixed in the same session; _probe.ps1's  
  Get-ProbeMetadataOptionals already keyed on the triple, so the harness had it right and the  
  gate did not.  
FOUND BY THE UNAIMED FUZZ, NOT BY LOOKING: seed 1246792 produced  
  "over-permit @ DriverHistoryQuery[3] SexCodeDH" and it SURVIVED the whole panel. Triaged rather  
  than dismissed -- built B2.O is an exact match to metadata B2{OLN} = Set[OLN]  
  Any[Attention, PurposeCode], so SexCode is genuinely undefined there. THE ASYMMETRY IS WHAT  
  MADE IT DIAGNOSABLE: the identical mutation on sibling KQ.O was CAUGHT, purely because  
  KQ{Name} carries SexCode in <Set> while B2{Name} carries it in <Any>, so only the latter  
  entered the pool. Two identical-set[] combos, same field, opposite verdicts, decided by which  
  grammar slot a THIRD variant used.  
MEASURED ACROSS ALL 20 BEFORE THE TOOL CHANGE WAS COMMITTED:  
  branches compared   420 -> 420   UNCHANGED (no coverage lost -- the check that separates a  
                                   real fix from a silencer)  
  UNDER-REQUIRED        4 ->   4   unchanged (the change touches the over-permit pool only)  
  OVER-PERMITTED        3 ->  11   +8, ALL VERIFIED REAL per-variant against the raw XML  
  regression fixture  116 branches / 0 UNDER / 0 OVER -- INTACT (CA_CLETS, FL_FCIC,  
                      HI_HCJDC_OFML, NJ_NJCJIS, NY_NYSPIN_EJUSTICE, TX_TLETS all still clean)  
  The other 6 of those 8 are NOT this provider's and were NOT fixed here (usx-tooling rule 8c):  
  CA_eSUN 4 and TENANT-VERIFIED CA_CLETS_OCATS 2, both carrying the identical plate/VIN class,  
  both FLAGGED [FLAG:fidelity-sibling-optional-leak] for their own next rebuild.  
LAW 2 -- the gate is now PROVEN able to fail on this class: catalogued mutation  
  'slo-fidelity-sibling-optional-leak' added to audit_gate_efficacy (re-adds VehicleMakeCode to  
  RQ.P; KILLED, findings 0 -> 1). It is aimed at the VEHICLE family rather than the original DH  
  survivor on purpose -- RQ{Plate} declares an EMPTY <Any>, so the mutation cannot be excused by  
  a looser reading, whereas the DH kill depended on which grammar slot a third variant used.  
A SECOND, UNRELATED GATE HOLE CLOSED IN THE SAME PASS: audit_gate_efficacy's  
  'codetype-select-as-input' mutation hunted three hardcoded fieldIds (relatedHitSearchIndicator  
  / ImageIndicator) and reported [INVALID] when none existed -- which is the case on ALL SIX CA  
  providers, none of which builds an ImageIndicator control. MEASURED: 6 of 20 providers, each  
  carrying 5-6 perfectly valid codeTypeCategory FormSelects, so validate.ps1's codeTypeCategory  
  branch had NEVER been efficacy-proven on any CA provider. Now falls back to selecting any  
  codeTypeCategory-driven FormSelect. CA_SAN_LUIS_OBISPO 8/8 + 1 INVALID -> 9/9 / 0 SURVIVED /  
  0 INVALID; CA_CLETS likewise 0 INVALID. ENGINEERING_STANDARD 5 requires 0 INVALID, not just  
  0 SURVIVED -- a step that did not run is not a pass.  
GATES: validator 67P/0F/0W - fidelity 22 branches / 0 UNDER / 0 OVER - query trace 20 built /  
  0 MISSING - reachability all reachable - efficacy 9/9 KILLED / 0 SURVIVED / 0 INVALID -  
  PS-5.1 119 scanned / 0 PARSE-FAIL - portability 280 cells / 0 unportable - enforce 0F / 0W.  
COST: NONE. Never tenant-tested (0 logs at any version), so no package archived, no Foundation  
  and no LIVE tenant. Plan regenerated at v2.8.  

## v2.7 -- 2026-09-02 -- THE IN-STATE PLATE SEARCH IS NOW THE VARIANT THE DEVDOC ACTUALLY LISTS

**CHANGED:** keyRef QV.P -> 4.P. Was set[LicensePlateNumber] any[LicensePlateTypeCode]; is now
  set[LicensePlateNumber, LicensePlateTypeCode] with NO any[] and a new condition  
  RegistrationState NOT_EXISTS. defaults[] (LicensePlateTypeCode=PC) unchanged. The  
  LicensePlateTypeCode form prefill is UNTOUCHED -- v2.6's ruling that devdoc #1 makes it  
  mandatory in-state still stands and this change depends on it rather than reversing it.  
**REASON:** PHASE 1 step [5] reported VehicleRegistrationQuery 5/6 built, MISSING metadata
  4#{LicensePlateNumber} = Set[LicensePlateNumber, LicensePlateTypeCode]. Read from the raw  
  <Requirements> (the sanctioned raw-XML exception), that is devdoc "#1 (In) LicensePlateNumber,  
  LicensePlateTypeCode" EXACTLY -- both unbracketed, i.e. both mandatory. It was not covered by  
  the data-mined declaration (mined tokens are QA/QB/QG/QV/QW), so it was a genuine gap.  
ROB'S RULING (2026-09-02): "4# carries no state so the convention leave state blank will work  
  and the query can be fired with state conditional." That is the resolution. 4# defines no  
  State field, so it IS the in-state variant, and State-blank is this repo's in-state  
  convention (LIMITATION #30). This provider's VIN pair ALREADY routed exactly that way --  
  RQ.V gated RegistrationState EXISTS, QV.V gated NOT_EXISTS -- while the plate pair was the  
  asymmetric one, both halves ungated and relying on specificity alone. Plate now matches VIN.  
I HAD ARGUED AGAINST BUILDING IT AND I WAS WRONG. My analysis treated the  
  LicensePlateTypeCode prefill as the only available discriminator, concluded 4.P and QV.P  
  were an exact collision no ordering could separate, and recommended registering 4# as  
  structurally unbuildable. Both halves of that were mistaken: State is the discriminator, and  
  the out-of-state regression I predicted (RQ.P losing its prefilled type) only arises if the  
  prefill is removed, which this change never does.  
WHY 4.P REPLACES QV.P RATHER THAN JOINING IT: LicensePlateTypeCode is form-prefilled and  
  therefore ALWAYS present, so 4.P's set[] and QV.P's set[] are satisfiable by identical form  
  state -- an exact collision (the AZ_AZDPS DQPN/DQP class, BUILD_RULES 24). One of the two had  
  to go and 4.P is the one the devdoc lists. NOTHING IS LOST: QV{Plate}'s only distinct  
  capability is a plate-only in-state search, which devdoc #1 does not sanction and which the  
  prefill had already made unreachable. THE WIRE IS UNCHANGED -- all six variants are  
  combinations of the SAME <Transaction Name="VehicleRegistrationQuery">, and a keyRef never  
  reaches the wire (only <MessageType> plus the fields do), so 4.P firing and QV.P firing on  
  the same fields emit byte-identical requests.  
MEASURED, NOT ARGUED -- the denominator moved the right way:  
  query trace          19 built / 1 MISSING  ->  20 built / 0 MISSING  
  requirement fidelity 22 branches / 0 UNDER / 0 OVER  ->  UNCHANGED at 22 / 0 / 0  
    (branches did NOT fall, so nothing was suppressed -- the check that catches a "fix" which  
     is really a silencer; TX's RSDWW cost a branch while appearing zero times in the JSON)  
  reachability         all combos reachable, 0 prefill-dead, 0 shadow  
  prefill shadow       0 (23 ordered pairs compared)  
  validator 67P/0F/0W - wiring closure clean - enforce 0 FAIL / 0 WARN  
NO REGISTRY ROW WAS ADDED, and that is deliberate: building the variant is the fix, so there is  
  nothing to accept. No existence-class row was left behind to silence the branch just added.  
COST: NONE. CA_SAN_LUIS_OBISPO has never been tenant-tested (0 logs at any version), so no test  
  package is archived; no Foundation and no LIVE tenant. Plan regenerated to 58 tests at v2.7.  

## v2.6 -- 2026-08-27 -- IN-STATE PLATE SEARCHES STOP ASSERTING THE CURRENT REGISTRATION YEAR

**CHANGED:** LicensePlateYear removed from QV.P's any[] AND from its defaults[]. QV.P is now
  set[LicensePlateNumber] any[LicensePlateTypeCode] with a single default LicensePlateTypeCode=PC.  
  RQ.P (out-of-state) is UNTOUCHED -- it still carries LicensePlateYear in set[] with its default,  
  and it is the ONLY devdoc combination that asks for the field.  
**REASON:** the control is prefilled with the current year because RQ.P needs it in set[], so it was
  ALWAYS in form state and transmitted on EVERY in-state plate search -- an unconditional assertion  
  that the plate's registration year is the current one, which can only narrow a match. The officer  
  never chose it. MEASURED, NOT ARGUED: this devdoc lists LicensePlateYear on exactly ONE  
  combination, "#3 (Out) LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear, State" --  
  RQ.P's shape. The in-state entry "#1 (In) LicensePlateNumber, LicensePlateTypeCode" does not  
  mention it at all.  
LicensePlateTypeCode DELIBERATELY KEPT: devdoc #1 makes it MANDATORY in-state, so prefilling it is  
  required rather than tolerated. TN_TIES v2.6 removed its plate TYPE for the mirror-image reason  
  (its devdoc #1 lists none) and CA_CLETS v2.27 kept type and removed only year, exactly as here.  
  Same-looking fields, opposite answers, and only the provider's own devdoc distinguishes them.  
PROVENANCE: this is the LAST SURVIVING ITEM from the unconditional-assertion sweep (commit  
  82759737, 2026-08-27), which measured 20 providers / 378 combinations / 96 prefilled controls ->  
  280 candidates -> 14 TIER-1 across 6 providers, adjudicated 13 away against each provider's own  
  devdoc, and named CA_SAN_LUIS_OBISPO as the one real residue -- "unregistered anywhere ... keep  
  plate TYPE, drop plate YEAR only ... do it at its own next rebuild". This is that rebuild.  
GATES: validator 67P/0F/0W - audit_devdoc_optionals 0 FAIL / 3 NOTE - fidelity 22 branches /  
  0 UNDER / 0 OVER UNCHANGED - reachability 15/15 all reachable - wiring closure 0 breaks across  
  ten classes (verified specifically: removing the field from one any[] did NOT orphan the control,  
  because RQ.P still requires it) - enforce 0 FAIL / 0 WARN.  
  [FLAG:plan-dedupe-vacuous-tests] RETIRED by this rebuild; plan regenerated to 59 tests.  
COST: NONE. CA_SAN_LUIS_OBISPO has never been tenant-tested (0 logs at any version), so no package  
  is archived; no Foundation and no LIVE tenant.  

## v2.6 -- 2026-08-27 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.5 -- 2026-08-20 -- LAYOUT COLLAPSE 13->6 CARDS + NAME COMPONENTS

**CHANGED:**
  LAYOUT -- 13 cards -> 6, the uniform shape (usx-cosmetic Step 3b). Vehicle 3->1,  
    Person 5->2 (DL + DH), Firearm 1, Article 1, Boat 3->1. Titles ALL-CAPS and  
    path-carrying. 'VIN' -> 'Vehicle Identification Number'. The "(DH)" label suffixes are  
    dropped -- the card title now says DRIVER HISTORY, so repeating it on every control was  
    noise; the fieldIds keep their DH suffix, which is what actually isolates the pool.  
    Boat: Hull now LEADS Registration, matching the Hull > Reg guardrail.  
    State keeps its routing hint -- SLO forks in-state vs OOS on State presence.  
  NAME COMPONENTS -- 4 new controls (NameMiddle/NameSuffix on the DL pool,  
    NameMiddleDH/NameSuffixDH on the DH pool), composed into both Name  
    FormatStringRuleHandlers with the separator list grown @(', ') -> @(', ', ' ', ' ')  
    (AP #15), and POOLED into the any[] of all FIVE name combinations (3 DL, 2 DH).  
    audit_name_components: 4 C1 -> 0, 8 components examined.  
  PRESERVED DELIBERATELY -- the OLN maxLen asymmetry. The DL control caps at 17 and the DH  
    control at 20 because each transaction caps it differently in this provider's own  
    metadata. That difference was itself a real finding once (audit_metadata flagged the DL  
    control at 20 > XML 17 and the gate was RIGHT), so it is called out here to stop a  
    future pass "harmonising" the two and either truncating a valid 20-character DH OLN or  
    re-introducing a request the DL transaction rejects.  
A PROBE NOTE WORTH KEEPING: my first Vehicle card put State alone on a row with  
  cols = @('6','6'), reasoning that L6 wants rows summing to 12. validate.ps1 rejected it --  
  "templateColumns has 2 entries but Row has 1 children -- misaligned columns", 3 WARNs, one  
  per layout variant. templateColumns must MATCH the child count, not the nominal 12. Fixed  
  to @('6'), which is what this provider's own pre-collapse OPTIONS row already used and  
  which audit_layout_flow accepts (L5 would have flagged @('12') for a lone dropdown).  
GATES: validator 67P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 8 examined | layout flow 5 findings -> 0 | wiring closure 0 breaks in all ten  
  classes | reachability 15/15 | prefill shadow 0 (23 pairs) | fidelity 22 branches 0 UNDER  
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

## v2.3 -- 2026-08-02 -- Carry PurposeCode + Attention on DH; cap the DL OLN control at 17 (commit a4e28101)

**CHANGED:** PurposeCode and Attention now transmit on the Driver History query, and the Driver
  License OLN control was capped at maxLength 17.  
**REASON:** The OLN cap is the one to remember: the control accepted 20 characters where THAT
  transaction caps at 17, and the naive "fix" (shrinking the field everywhere) would have  
  truncated a VALID 20-character DH OLN, because that transaction genuinely allows 20. Same field,  
  two transactions, two limits. Recovered 2026-08-03 from commit a4e28101; this entry read  
  "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.2 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-07-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + combo refinement


## v1.0 -- 2026-05-06 -- Initial standup -- 6 basic queries, 14 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

