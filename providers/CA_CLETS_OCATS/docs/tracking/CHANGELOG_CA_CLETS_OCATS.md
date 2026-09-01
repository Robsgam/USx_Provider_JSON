# CA_CLETS_OCATS -- Changelog

Auto-generated from `CA_CLETS_OCATS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.11** | Generated: 2026-09-01

---

## v2.11 -- 2026-09-01 -- ARTICLE TYPE DROPDOWN WAS RENDERING EMPTY IN THE TENANT

**CHANGED** (one line, Article form only -- no QIDM, no combination, no wire field):
  ArticleTypeCode control codeTypeSource 'CA_CLETS_OCATS' -> 'CA_CLETS'.  
FOUND BY THE FIRST-EVER PICKLIST CAPTURE OF THIS FORM, minutes after v2.10 was imported:  
  [import-picklists] FAIL Article.ArticleTypeCode: tenant table EMPTY (NCIC_ARTICLE_TYPE/CA_CLETS_OCATS)  
Rob, same moment: "article had an issue with the article type drop down."  
ROOT CAUSE: the codeTypeSource was THIS PROVIDER'S OWN NAME. No such platform code table exists, so  
the control rendered with ZERO options and an officer could not add a type to any article search.  
THE CORRECT VALUE WAS ALREADY DOCUMENTED -- CLAUDE.md's Code Type Pairings table records  
"NCIC_ARTICLE_TYPE | CA_CLETS | NCIC gives empty dropdown". 'CA_CLETS' is a PLATFORM REGISTRY TABLE  
NAME, not a provider-scoped value: nine providers use it, including non-CA ones (HI, IL, MD, NM, OH,  
OR, TN), and it is live-proven on CA_CLETS's own Article logs. OCATS was the sole outlier.  
SEVERITY -- not a blocked search: ArticleTypeCode sits in any[] on both QA.S and QA.O, so serial and  
owner-applied-number searches worked. What was lost was narrowing by type, and the officer saw a  
visibly broken control.  
SCOPE CHECKED IN THE SAME PASS, so one bump covers it: every other OCATS dropdown  
(LicensePlateTypeCode, businessIndicator, firearmMake, GunCaliber, gunTypeCode) correctly uses NCIC.  
Only this one control was wrong.  
*** WHY A BUMP AND NOT AN EDIT: v2.10 IS INSTALLED. *** The picklist capture itself records  
"version": "2.10", which is the proof. Editing v2.10 in place would leave one version number  
describing two different forms, and the wire XML carries no version -- so every log captured against  
it becomes unattributable (audit_log_inflation attack B by construction). I initially applied the fix  
while the script still said 2.10 because a shell escaping error swallowed the version bump; caught it  
before rebuilding and re-bumped properly.  
⚠️ OWED BEFORE THE SWEEP: RE-IMPORT v2.11, then RE-CAPTURE THE ARTICLE PICKLIST. The committed  
TENANT_PICKLISTS.json records this table as EMPTY at v2.10 -- that entry is evidence of the DEFECT,  
not of the fix. Only a fresh capture on v2.11 can show the options populated, and until then this  
fix is REASONED, not verified.  
WHAT THE SAME CAPTURE ALSO SETTLED, and it is worth keeping: businessIndicator renders exactly  
"N - No" / "Y - Yes" on the live tenant, so the 'Y' chosen for TEST_VALUE_OVERRIDES earlier today  
from the code-type table is a REAL option -- that was a reasoned guess and is now evidence.  
RegistrationState renders 57 options and its label already reads "State (leave blank for CA)", i.e.  
the form itself states the in/out convention. VehicleMakeCode is truncated at 300 (the known cap), so  
its test value stays inconclusive against the capture.  
GATES: validator 66P/0F/0W. No QIDM, combination or wire change, so routing, fidelity and  
reachability are untouched by construction and were re-run to confirm.  
COST: a re-import and one re-capture. No logs existed at v2.10 (picklists are not logs), so nothing  
was archived and no sweep work is lost.  

## v2.10 -- 2026-09-01 -- WITHDRAWS v2.9 AND RESTORES THE v2.8 CONFIGURATION EXACTLY

Rob 2026-09-01: "revert to v2.8 shape."  
PROVEN, NOT ASSERTED: the emitted v2.10 JSON diffs to ZERO lines against the committed v2.8 JSON  
once the version string is normalised, and the structural comparison matches on every axis --  
8 Vehicle combos in the original order (AWVEHQ, RQ.P, RQ.V, VC, VP, 4V, 4K, 4), 5 DL combos in the  
original order (OCNAMQ, DQ.N, DQ.O, L1.N, L1.O), and userId VISIBLE with no initialValue on both  
entities. Validator back to 66P/0F/0W (v2.9 read 65P because it removed a combo).  
WHY v2.9 WAS WITHDRAWN -- the authority does not support the mechanism, and Rob caught it:  
"user id at 2 characters is strang  review devdoc and let me know  we may be chasing this in teh  
wrong way." He was right.  
  * The devdoc's Routing and Configuration section (L30-31) says: "The CLETS assigned User ID  
    should be placed in the <Authentication>/<UserName> field in the ConnectCIC header." Build-Auth  
    ALREADY does exactly that -- OCATS's AUTH config emits  
    UserName / sourceField dexStateUserId / rule CommsysGetDexStateUserIdRuleHandler. So the CLETS  
    User ID is already transmitted, in the documented place, by the documented mechanism. v2.9 was  
    duplicating an AUTH-header concern into a per-query field.  
  * The QUERY-level `UserId` is therefore a DIFFERENT field, and it is maxLength 2 in ALL SEVENTEEN  
    transactions that define it (checked per-transaction, so this is NOT the wrong-transaction read  
    that got Authorization wrong at v2.1 -- there the answer genuinely varied 1 vs 2 by transaction;  
    here it is uniformly 2). A 2-character alphanumeric cannot hold the DEX username the handler  
    returns -- AZ's resolves to MK43RS, six characters, and AZ's size-4 field did not truncate it.  
  * SO v2.9's AWVEHQ AND OCNAMQ WOULD HAVE SENT AN INVALID UserId, and because v2.9 had retired '4',  
    AWVEHQ was the ONLY remaining in-state plate combo. Withdrawing is the safe direction: v2.8  
    keeps '4' and leaves userId a visible control an officer can fill correctly.  
WHAT WAS ALSO REVERTED, in the same pass, so nothing is left dangling:  
  * The two ACCEPTED_DIVERGENCES rows added for v2.9 ('4' dead-combo-userid-automated, 'QV'  
    dead-combo-routing-impossible) are COMMENTED OUT with their reasoning kept. This was MANDATORY,  
    not tidiness: an existence-class rule makes audit_requirement_fidelity SKIP that keyRef's entire  
    comparison, so leaving a `dead-combo` row naming the now-BUILT '4' would have silenced a live  
    branch while the finding count still read 0.  
  * verify_build's hidden-field whitelist entry '^userId$' was removed (git checkout). With userId  
    visible again the entry is inert, and an unnecessary whitelist entry is a hazard -- that is the  
    '(?i)state' lesson, where an over-broad entry printed "documented exception, allowed" on the  
    defect it existed to catch for four months.  
WHAT SURVIVES FROM TODAY, because it was never dependent on the userId mechanism:  
  docs/reference/TEST_VALUE_OVERRIDES.txt (created earlier today) still supplies userId and  
  businessIndicator, so AWVEHQ, OCNAMQ and VC still get plan tests. Before that file existed, those  
  THREE BUILT COMBOS HAD NO PLAN TEST AT ALL and would have gone untested through a sweep. Plan is  
  65 tests covering all 21 combos, verified after the revert.  
TO RECOVER v2.9, ONE FACT IS NEEDED: does the agency have a 2-character OCATS User ID, and is it  
per-agency (a fixed hidden value) or per-officer (must stay visible)? Everything else in v2.9 was  
verified sound -- routing 12/12 on the emitted JSON, fidelity 25 branches 0 UNDER / 0 OVER,  
prefill_shadow 0 FAIL, reachability 19/19 -- so it is recoverable wholesale from git commit  
875077f4 once that value is known.  
COST: none. OCATS is NOT IMPORTED and had 0 logs at any version, so neither the v2.9 bump nor this  
withdrawal archived anything and no re-sweep is owed.  

## v2.10 -- 2026-09-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.9 -- 2026-09-01 -- USER ID HIDDEN + AUTOMATED, AND STATE TAKES OVER THE ROUTING IT USED TO DO

DIRECTIVE (Rob 2026-09-01): "we need to hide and automate the user id field  figure out how to use  
state to route and for veh 1 and 2 combos become combined." Those are ONE change, not three, and  
the devdoc is why:  
    Veh #1 (In)  LicensePlateNumber  
    Veh #2 (In)  LicensePlateNumber, UserId, [Authorization, ExactSearchIndicator,  
                 LicensePlateStateCode, PageNumber, VehicleMakeCode, VehicleYear]  
    Veh #6 (Out) LicensePlateNumber, LicensePlateYear, [LicensePlateTypeCode, State]  
    DL  #1 (In)  BirthDate, Name, SexCode, UserId  
    DL  #4 (Out) BirthDate, Name, SexCode, [State]  
#1 and #2 differ ONLY by UserId; DL #1 and #4 differ ONLY by UserId-vs-State. So UserId IS the  
in-state marker and State is the out-of-state marker. Automate UserId and (a) #1 and #2 become the  
same officer fill -- they MERGE -- and (b) UserId can no longer discriminate, so State must.  
**CHANGED:**
  userId -- visible FormInput -> HIDDEN feeder (InpH, initialValue 'X'), on Vehicle and Person.  
    Attribute gains rule=CommsysGetDexStateUserIdRuleHandler args=['true'] (size stays 2 per this  
    XML). Combo defaults[] userId='X' added on AWVEHQ and OCNAMQ because CAD ignores form  
    initialValue. Label -> "OCATS User ID (auto)".  
  VEHICLE -- built '4' (devdoc #1) RETIRED, merged into AWVEHQ. Order now  
    4K, RQ.P, AWVEHQ, RQ.V, VC, VP, 4V.  
  PERSON  -- DQ.N moved AHEAD of OCNAMQ and its RegistrationState promoted any[] -> set[].  
    Order now DQ.N, OCNAMQ, DQ.O, L1.N, L1.O.  
  Registered: '4' (dead-combo-userid-automated) and 'QV' (dead-combo-routing-impossible).  
  verify_build's hidden-field whitelist gained an ANCHORED '^userId$' entry with the directive.  
*** THE HANDLER IS LIVE-PROVEN, NOT ASSUMED. *** AZ_AZDPS uses the same handler on a QUERY  
attribute and its own build comment flagged that as an unverified HYPOTHESIS. Settled from AZ's  
committed logs: across 53 v3.12 logs the FORM sends "dexStateUserId":"X" on 53/53 while the WIRE  
carries <BadgeNumber>MK43RS</BadgeNumber> on 41/41 of the logs containing the element. The handler  
replaces the feeder on a query attribute. Hypothesis retired.  
⚠️ OPEN RISK, RECORDED NOT HIDDEN: the handler resolves to the DEX username. On AZ that is MK43RS  
-- SIX characters into a size-4 field, and it did NOT truncate. OCATS caps UserId at 2, so expect  
a 6-character value on the wire. Whether OCATS accepts it is a LIVE fact this repo cannot settle;  
the sweep will. Rob chose this option with that risk stated. If it is rejected, switch to a fixed  
hidden initialValue carrying the agency's real 2-char operator id -- do NOT conclude the  
combination is unbuildable.  
*** TWO THINGS I GOT WRONG FIRST, BOTH CAUGHT BY GATES RATHER THAN BY READING: ***  
  1. I first gated AWVEHQ and OCNAMQ `RegistrationState NOT_EXISTS`. verify_build FAILED it:  
     "NOT_EXISTS field 'RegistrationState' is also in any[] -- dead config (can never serialize)".  
     It was right. Gating a field the SAME combo also permits is self-contradictory; the "a  
     guardrail routes, it does not decide what the winner transmits" rule applies to a DIFFERENT  
     field's guardrail (plate>VIN gates plate, still sends VIN), never to the gated field itself.  
     It also had a hidden cost: RegistrationState is the ONLY control feeding LicensePlateStateCode,  
     which metadata AWVEHQ DOES define in <Any>, so the gate silently made a devdoc #2 optional  
     untransmittable. Replaced with ORDERING -- which usx-build Step 2 lists first anyway -- so the  
     OOS combos (which REQUIRE State in set[]) sit ahead of the in-state ones and the paths separate  
     themselves. audit_prefill_shadow went 2 FAIL -> 0 FAIL on that change alone.  
  2. Promoting State back into DQ.N's set[] REVERSED A DOCUMENTED v2.8 DECISION, and I walked into  
     it before reading DQ.N's own comment (usx-build 6c: a reversal already written down is the  
     cheapest authority in the repo). v2.8 demoted it because promoting made DQ.N out-of-state-only,  
     so devdoc #4 filled WITHOUT a state fell through to L1.N -- which has no SexCode in its any[],  
     so the sex code was dropped. THE REVERSAL IS LEGITIMATE ONLY BECAUSE THAT CONDITION IS GONE:  
     with userId automated, OCNAMQ (devdoc #1, which carries all three of Name/DOB/Sex) can finally  
     match, so the in-state fill lands on its own combination instead of falling to L1.N. Verified,  
     not argued -- see the routing table below.  
ROUTING VERIFIED ON THE EMITTED v2.9 via _sim_helpers Get-FiringKeyRef (12 fills, 0 mismatches,  
form prefills included so this is what the tenant actually submits):  
  plate only                  -> AWVEHQ    plate+State+Year      -> RQ.P  
  plate+PlateType             -> 4K        VIN only              -> 4V  
  VIN+State                   -> RQ.V      owner name            -> VP  
  owner name+businessInd      -> VC        name+DOB+Sex          -> OCNAMQ  
  name+DOB+Sex+State          -> DQ.N      name only             -> L1.N  
  OLN only                    -> L1.O      OLN+State             -> DQ.O  
GATES: validator 65P/0F/0W. reachability 19/19 all reachable. fidelity 25 branches / 0 UNDER /  
0 OVER -- UNCHANGED across the whole change, including after the two registry rows, so nothing was  
suppressed. query_trace 23 built / 0 PREFILL-DEAD / 0 SHADOW / 0 MISSING. prefill_shadow 0 FAIL  
(42 pairs). wiring closure 0 breaks. verify_build hidden-field whitelist change measured across all  
20 providers: zero others affected.  
COST: none owed. CA_CLETS_OCATS is NOT IMPORTED and had 0 logs at any version, so the bump archived  
nothing and no re-sweep is owed. 20 combos (was 21).  

## v2.9 -- 2026-09-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.8 -- 2026-09-01 -- THE IN-STATE NAME SEARCH STOPS DISCARDING SEX CODE

**CHANGED** (DriverLicenseQuery, DQ.N only -- every other QIDM byte-identical):
  RegistrationState DEMOTED from set[] to any[], and its `RegistrationState EXISTS` condition  
  REMOVED. DQ.N is now set[caRequestPurposeCode, NameLast, NameFirst, BirthDate, SexCode]  
  any[RegistrationState, NameMiddle, NameSuffix], gated only by OperatorLicenseNumber NOT_EXISTS.  
**REASON:** metadata DQ{Name} = Set[CaRequestPurposeCode, Name, BirthDate, SexCode] Any[State] --
  State is OPTIONAL there. Promoting it into set[] and gating on it made DQ.N reachable ONLY out  
  of state, so devdoc #4 "(mand) BirthDate, Name, SexCode  [opt State]" filled WITHOUT a State  
  fell through to L1.N (set[purposeCode, Name] any[BirthDate, NameMiddle, NameSuffix]) and the  
  officer's SEX CODE was silently discarded -- L1.N carries BirthDate in any[] but not SexCode.  
  Never gate on a field the metadata merely permits: same anti-pattern as TN_TIES KQ.N and  
  NM_NMLETS_OFML RQ.P (v2.7, same day).  
SCOPE HELD, and both exclusions are deliberate:  
  L1.N KEEPS its `RegistrationState NOT_EXISTS` gate. Metadata L1{Name} does not define State at  
    all, so without that gate a Name+State fill would match L1.N and drop the State silently --  
    the same class of defect this entry fixes. DQ.N is a strict superset of L1.N and ordered  
    first, so Name+DOB+Sex reaches DQ.N and a name-only search still reaches L1.N.  
  DQ.O KEEPS RegistrationState in set[]. It is the ONLY discriminator against L1.O -- both would  
    otherwise be set[purposeCode, OperatorLicenseNumber], an exact collision no ordering can  
    separate. The gate never flagged the OLN pair; only DQ.N.  
GATES: validator 66P/0F/0W - audit_devdoc_optionals 1 FAIL -> 0 (the MANDATORY-NOT-TRANSMITTED  
  finding that prompted this) - fidelity 25 branches / 0 UNDER / 0 OVER, UNCHANGED, so the demotion  
  bought no coverage and cost none - reachability 20/20 all reachable, L1.N still live -  
  enforce 0 FAIL / 0 WARN.  
COST: NONE beyond the rebuild. CA_CLETS_OCATS has NEVER been tenant-tested (0 logs at any version),  
  so no package is archived, no re-import is owed that was not already owed, and it is on no  
  Foundation or LIVE tenant.  

## v2.8 -- 2026-09-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.7 -- 2026-08-20 -- LAYOUT COLLAPSE 16->5 CARDS + NAME COMPONENTS

**CHANGED:**
  LAYOUT -- 16 cards -> 5, the uniform shape (usx-cosmetic Step 3b). Vehicle 4->1,  
    Person 3->1, Firearm 2->1, Article 3->1, Boat 4->1. Titles ALL-CAPS and path-carrying.  
    'VIN' -> 'Vehicle Identification Number', 'License Number' -> 'OLN' (DEX-1284).  
    State keeps its routing hint -- OCATS forks in-state vs OOS on State presence.  
  PERSON IS ONE CARD AND THAT IS CORRECT: OCATS builds no DriverHistoryQuery (5 basic  
    queries, no DH), so there is no second field pool to isolate. The uniform target's  
    "Person = 2 cards" is a CONSEQUENCE of DH-suffix isolation, not a count to hit.  
  NAME COMPONENTS -- NameMiddle/NameSuffix added to BOTH forms that carry the shared name  
    pool (Vehicle-owner and Person use the SAME ('NameLast','NameFirst') sourceField), both  
    Name composites extended with the separator list grown @(', ') -> @(', ', ' ', ' ')  
    (AP #15), and the components POOLED into the any[] of all FIVE name combinations  
    (VC, VP, OCNAMQ, and the two DL name paths). audit_name_components: 4 C1 -> 0.  
PRESERVED DELIBERATELY -- the two UN-PREFILLED routing discriminators, now carried in a  
  loud comment on the Vehicle card so a future "add the standard defaults" pass cannot undo  
  them: LicensePlateTypeCode has NO initialValue because it is what separates built 4K from  
  4, and businessIndicator has NO initialValue because it is what separates VC from VP. A  
  prefill on either makes it always-present and kills the plainer sibling (BUILD_RULES 24).  
  Those two combos were BUILT at v2.6 specifically to clear an over-permit, and fidelity  
  still reads 25 branches / 0 UNDER / 0 OVER here, so the collapse preserved that work.  
A GATE PAIR THAT CONSTRAINS FROM OPPOSITE DIRECTIONS: my first Firearm row 2 used  
  cols = @('4','4') for two fields. validate.ps1 was happy (columns match children) but  
  audit_layout_flow L6 was not -- "templateColumns [4 4] sums to 8, not 12 (4 column(s) of  
  dead space)". Fixed to @('6','6'). Compare CA_SAN_LUIS_OBISPO v2.5, where the opposite  
  mistake (@('6','6') for ONE field) tripped validate.ps1 instead. The rule that satisfies  
  both: columns must match the child COUNT and sum to 12 -- and L6 does not fire on a  
  single-field row, which is why a lone control legitimately takes @('6').  
GATES: validator 66P/0F/0W | verify_build 17 PASS / 0 WARN / 0 FAIL | name components 0  
  blocking / 8 examined | layout flow 1 finding -> 0 | wiring closure 0 breaks in all ten  
  classes | reachability 20/20 | prefill shadow 0 (49 pairs) | fidelity 25 branches 0 UNDER  
  / 0 OVER.  
NOT TESTED: never tenant-tested. Owes an import and a first-ever sweep.  

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

