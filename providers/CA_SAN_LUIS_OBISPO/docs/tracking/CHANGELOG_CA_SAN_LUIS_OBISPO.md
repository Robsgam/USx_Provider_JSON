# CA_SAN_LUIS_OBISPO -- Changelog

Auto-generated from `CA_SAN_LUIS_OBISPO_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.6** | Generated: 2026-08-27

---

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

