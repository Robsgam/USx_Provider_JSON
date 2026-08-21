# CA_CLETS_OCATS -- Changelog

Auto-generated from `CA_CLETS_OCATS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.7** | Generated: 2026-08-20

---

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

