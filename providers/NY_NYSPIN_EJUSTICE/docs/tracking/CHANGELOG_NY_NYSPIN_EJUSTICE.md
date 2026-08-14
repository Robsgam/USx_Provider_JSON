# NY_NYSPIN_EJUSTICE -- Changelog

Auto-generated from `NY_NYSPIN_EJUSTICE_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v4.24** | Generated: 2026-08-14

---

## v4.24 -- 2026-08-14 -- NCIC Image defaults to 'Y' on Vehicle/Article/Boat (WIRE CHANGE)

**CHANGED:** ImageIndicator initialValue 'N' -> 'Y' on the three entities still at 'N', in BOTH halves
  of the default: the form FormSelect initialValue (Vehicle ROW_VEH_3, Article ROW_ART_2, Boat  
  ROW_BOA_1B -- 3 authored sites, x3 layout variants) AND the combo defaults[] twin on all 9  
  carrying combinations (Vehicle RVIN/RVEHOUT/RVEH/RCAR, Article AINQ, Boat BVEH/BVIN/RVEH/RCAR).  
  Person was already 'Y' on BOTH its controls (ImageIndicator + the DH-suffixed ImageIndicatorDH)  
  and is untouched. Takes [FLAG:ncic-image-default-y-everywhere].  
**REASON:** Rob 2026-08-12, "ncic image should default to y everywhere". BOTH halves are required --
  CAD ignores form initialValue, so a form-only flip leaves CAD-originated queries on 'N'.  
THIS IS A WIRE CHANGE. ImageIndicator rides in any[] on all 9 combos, so the value IS transmitted  
  and N->Y changes what NCIC is asked for. Hence the bump and the full 69-log re-sweep. The gain is  
  response-side: with 'N' NCIC returns no image, so a hit came back without a photo and nothing  
  errored -- a silent under-ask no request-side gate can see.  
MEASURED SAFE BEFORE FLIPPING:  
  * ImageIndicator is in ZERO set[]s and ZERO conditions on NY (counted from the emitted v4.23  
    JSON), so no prefill can shadow a combination (BUILD_RULES 24) and there is no NOT_EXISTS-gated  
    branch to kill (BUILD_RULES 20b). Contrast AZ_AZDPS, where this flip is RULED OUT.  
  * NY's devdoc carries NO "must be filled if ImageIndicator = Y" conditional wording (grepped).  
    TX/TX_CCH do, but theirs is scoped to DriverHistoryQuery, which this change does not touch.  
  * All 9 combos already carried a defaults[] entry, so this edits values and adds no keys.  
  * NO COLLISION on this provider: every initialValue='N' and every defaults value='N' in the build  
    script was already ImageIndicator's, so the replace was unambiguous. Verified after: 0 sites  
    left at 'N', 15 defaults + 4 form controls now 'Y', and RelatedHitSearchIndicator still 'Y' at  
    both sites. (NJ_NJCJIS v4.16 was NOT like this -- there RandomRequest shares both spellings and  
    a careless replace-all would have switched every vehicle query to a random record. Check per  
    provider; do not carry NJ's or NY's conclusion across.)  
DH NOTE, checked because it looks wrong and is not: the four DH combos carry ImageIndicatorDH in  
  any[] while their defaults[] name plain 'ImageIndicator'. That is correct -- any[] holds  
  sourceFields (form fieldIds) and defaults[].field holds the QIDM ATTRIBUTE/targetField name, which  
  is 'ImageIndicator' for both controls. Not an inert default; audit_wiring_closure agrees.  

## v4.23 -- 2026-08-06 -- DEX-1284 CLOSED -- item 3 (home-state strip) LIVE-PROVEN. ALL-PASS 69/69.

(Header carries v4.23's BUILD date per the BUILD_NOTES-vs-JSON date checksum; the tenant  
 capture, reclassification and closure below all happened 2026-08-07. No JSON change.)  
**CHANGED:** No JSON change. Both value-strip tests captured on the tenant and now PASS:
  * RVIN + State=NY  -> wire is <VehicleIdentificationNumber> + <ImageIndicator>, no <State>  
    -- BYTE-IDENTICAL to our own in-state RCAR wire, an exact match for devdoc combination  
    #2 "(In) VehicleIdentificationNumber, [ImageIndicator]". The correct NY DMV lookup.  
  * RVEHOUT + State=NY -> Plate + PlateType + PlateYear + Image, no <State>. Matches devdoc  
    #1 "(In) LicensePlateNumber, [ImageIndicator, LicensePlateTypeCode]" plus ONE extra  
    field, LicensePlateYear, which #1 does not define (it is mandatory only on #3).  
    ACCEPTED (Rob, 2026-08-07): over-permit is the mildest defect class, and the alternative  
    is knowingly routing NY-registered vehicles out-of-state to Nlets. No config-side fix  
    exists -- PlateYear is required by #3 so its default cannot be removed, the handler sits  
    on the shared State attribute so it cannot be scoped per-combination, and conditions  
    cannot value-compare (LIMITATION #37). Deliberately NOT registered as a divergence: no  
    gate flags it, so a registry row would suppress nothing and risk the prefix-bridge  
    over-suppression trap. Full reasoning in UNIVERSAL_SEARCH_HANDLERS.txt Sec 4 "RESOLVED".  
  * Non-NY values unaffected -- State=GA still transmits on all 17 other Vehicle tests.  
  Also fixed the classification bug this exposed: import_captured_tests.ps1's  
  Test-ExpectedComboOnWire scored the deliberate absence as "routing=MISMATCH" and FAILed  
  both tests on their first run. The stripped field's expectation is now INVERTED rather  
  than exempted (presence = failure, because it means the handler did not strip), so the  
  check still fails on a real regression -- proven with a 4-case LAW 2 harness. Taught  
  audit_log_combo_attribution.ps1's suffix parser about _strip_<field>.  
**REASON:** Leo Hisoire, DEX-1284 (2026-07-24) item 3. Settled on the METADATA+DEVDOC standard
  (is the request compliant?), not on observed behaviour -- CommSys responses are never  
  captured by this repo and mock-mode behaviour is not predictable, so "did it return the  
  right data" is unanswerable by design and is NOT the bar.  

## v4.23 -- 2026-08-06 -- PLAN COVERAGE ADDED (same version, no JSON change): item 3's home-state

strip test is now permanent. Built a new 'value-strip' test kind into  
tools/emit_test_plan.ps1 -- any QIDM attribute using IgnoreUserValueRuleHandler  
automatically gets a dedicated test per owning combo, filled with the handler's own  
ignored value (RegistrationState=NY on both RVIN and RVEHOUT). This is what makes  
DEX-1283/1284's item-3 experiment survive every future rebuild instead of being a  
one-off manual test that the import pipeline correctly drops as "matched no plan  
test" and that never becomes a committed log. Wired through _content_match.ps1  
(Get-CmPlanLabel), relabel_batch.ps1 (Get-CmRecordLabel + field propagation), and  
import_captured_tests.ps1 (label branch) so a captured wire XML using these exact  
fill values will be recognized and logged like any other plan test. Regenerated  
NY's committed TEST_PLAN_v4.23.json in place: 67 -> 69 tests, 2 owed (RVIN_strip_  
RegistrationState, RVEHOUT_strip_RegistrationState) -- state correctly reads PARTIAL  
until those two are captured through the normal Vehicle sweep. Verified zero effect  
on all other 19 providers (none use this rule) via a full regeneration sweep before  
committing.  

## v4.23 -- 2026-08-06 -- DEX-1284 item 1: reverted PurposeCode dropdown -- DISPROVEN LIVE

**CHANGED:** purposeCodeDH reverted from FormSelect (attributeTypeId='DEX_INQUIRY_PURPOSE_CODE',
  added at v4.22) back to FormInput with initialValue='C'. Removed the accepted_field_  
  divergences.json entry for purposeCodeDH (no longer applicable). Recorded  
  LIMITATION #39 in PLATFORM_CONSTRAINTS.txt.  
**REASON:** Live-tested on the NY_NYSPIN_EJUSTICE tenant and disproven immediately: the dropdown
  opened with ZERO options on every DALHOUT/DALLOUT attempt (driver console: "purposeCodeDH  
  no options rendered ... FAIL", consistent across every test, not intermittent). Since  
  purposeCodeDH is mandatory in those combos' set[], this under-filled and broke every OOS  
  DriverHistoryQuery request -- a real regression, not cosmetic. DEX_INQUIRY_PURPOSE_CODE is  
  CA_eSUN/CLETS-tenant-scoped (its captured label was literally "CA Purpose Code"), NOT a  
  universal platform code table like STATE/SEX/VEHICLE_MAKE, despite an identical config  
  shape. Item 3 (Vehicle home-state strip, IgnoreUserValueRuleHandler) is untouched by this  
  revert and remains under live test.  

## v4.22 -- 2026-08-06 -- DEX-1284 items 1+3: PurposeCode dropdown + Vehicle home-state strip (experiment)

**CHANGED:** (1) purposeCodeDH converted from FormInput to FormSelect with
  attributeTypeId='DEX_INQUIRY_PURPOSE_CODE' -- confirmed live pattern from the CA_eSUN  
  department export (2026-08-06), same attributeTypeId mechanism as STATE/SEX/VEHICLE_MAKE.  
  Registered accepted_field_divergences.json entry for 'purposeCodeDH' (other DH-suffix  
  providers still use free-text). (2) Added IgnoreUserValueRuleHandler(["NY"]) to the  
  VehicleRegistrationQuery 'State' attribute (sourceField RegistrationState) -- CAD auto-fills  
  the officer's home state on every Vehicle entry, forcing the OOS combo (RVEHOUT) to fire for  
  plates that are actually NY-registered. This handler strips "NY" from the OUTBOUND wire value  
  only; it does NOT change combo selection (confirmed via scratch simulator test, 2026-08-06:  
  RVEHOUT still fires, <State> is omitted from the wire). Whether the live CommSys server treats  
  a State-absent OOS-shaped request as a correct in-state lookup is UNSETTLED and can only be  
  determined by a live capture -- this version exists to observe that. Also fixed validate.ps1's  
  stale AP #4 "IgnoreUserValueRuleHandler is a DEAD END" WARN (corrected 2026-07-29 in the KB for  
  the stripping use case; the validator check had never been updated to match).  
**REASON:** Leo Hisoire, DEX-1284 (2026-07-24) -- Rob approved building both items together
  (2026-08-06) after a scratch-simulator test confirmed the mechanics of item 2 but could not  
  settle the live server behavior. STATUS: HYPOTHESIS pending live capture on item 2; item 1 is  
  a confirmed-buildable, lower-risk change (dropdown values are what remain to verify at import).  

## v4.21 -- 2026-08-06 -- DEX-1283 follow-up: demoted requestorDH set[]->any[] (v4.20's fix was wrong)

**CHANGED:** v4.20's fix (below) was LIVE-TESTED and broke DALHOUT: Send stayed permanently
  disabled, twice, on re-run. Root cause confirmed: this is a CLIENT-SIDE gate, not a  
  server-side one -- the browser checks every set[] field for a value before enabling Send,  
  with no knowledge that a rule handler would fill it server-side. A hidden field with no  
  initialValue has no value for that check to find. Fix: demoted requestorDH from set[] to  
  any[] on both DALHOUT and DALLOUT (left initialValue removed -- did NOT restore 'X').  
  REGISTERED as a divergence (NY_NYSPIN_EJUSTICE_ACCEPTED_DIVERGENCES.txt): the raw metadata  
  XML's DALH/DALHOUT and DALL/DALLOUT Choice branches genuinely place Requestor in the  
  mandatory Set. any[] is still correct because the platform builds an attribute from set[]  
  OR any[] equally, and only set[] imposes the client Send-gate; the rule handler  
  (CommsysGetLastNameFirstNameInitialRuleHandler) populates Requestor unconditionally either  
  way (proven server-side on TX_TLETS v4.19/FL_FCIC v7.18/CA_CLETS v2.24). Routing unaffected:  
  DALHOUT vs DALH is decided by RegistrationStateDH EXISTS/NOT_EXISTS, not by Requestor.  
**REASON:** Rob caught it live during the v4.20 tenant sweep ("problems standby" / "it looks like
  the dh queries") before it went further. Cost: 17 v4.20 logs archived (Vehicle + partial  
  Person only -- the sweep hadn't reached DH yet when the failure surfaced). Full re-sweep  
  from T1 owed at v4.21; DALHOUT/DALLOUT remain THE discriminating test to run first.  

## v4.20 -- 2026-08-06 -- SUPERSEDED same-day by v4.21 -- DEX-1283 fix broke DALHOUT, see above

**CHANGED:** Removed initialValue='X' from the requestorDH hidden gate-feeder, and the matching
  combo defaults[] entries on DALHOUT/DALLOUT. requestorDH stayed UNCHANGED in set[] on both  
  combos (metadata-mandatory for OOS DH per the devdoc/metadata OOS Set).  
**REASON:** Same finding as TX_TLETS v4.19/FL_FCIC v7.18/CA_CLETS v2.24, BUT NY is structurally
  different: on those three providers the equivalent field is any[]-only, so removing the  
  default never affected combo MATCHING, only attribute VALUE resolution (which the rule  
  handler overrides unconditionally regardless). Here requestorDH is in set[], so its  
  PRESENCE gates whether DALHOUT/DALLOUT match at all -- and a hidden field with no  
  initialValue submits no key whatsoever (confirmed empirically on all three prior providers:  
  the captured form snapshot omits the field entirely). If the platform's set[] check requires  
  a submitted key (not just a non-empty value) to be satisfied, these two combos could stop  
  firing entirely, with no sibling OOS DH combo to fall back to. Rob's call (2026-08-06): apply  
  it and verify live rather than leave it unproven. THE DISCRIMINATING TEST, before anything  
  else in this sweep: does DALHOUT (Name+State) and DALLOUT (OLN+State) still fire, and does  
  <Requestor> carry the real officer name on the wire? If either fails, revert this diff on  
  requestorDH specifically (restore initialValue='X' + the two combo defaults[] entries) --  
  do not touch the TX/FL/CA_CLETS fix, which is unrelated and already wire-proven.  
  OUTCOME: it failed live (see v4.21) -- reverting to 'X' was NOT the chosen fix; demoting to  
  any[] was, since it fixes the client-side gate without reintroducing the placeholder.  
**CHANGED:** Removed initialValue='X' from the requestorDH hidden gate-feeder, and the matching
  combo defaults[] entries on DALHOUT/DALLOUT. requestorDH stays UNCHANGED in set[] on both  
  combos (metadata-mandatory for OOS DH per the devdoc/metadata OOS Set -- this is not being  
  relaxed).  
**REASON:** Same finding as TX_TLETS v4.19/FL_FCIC v7.18/CA_CLETS v2.24, BUT NY is structurally
  different: on those three providers the equivalent field is any[]-only, so removing the  
  default never affected combo MATCHING, only attribute VALUE resolution (which the rule  
  handler overrides unconditionally regardless). Here requestorDH is in set[], so its  
  PRESENCE gates whether DALHOUT/DALLOUT match at all -- and a hidden field with no  
  initialValue submits no key whatsoever (confirmed empirically on all three prior providers:  
  the captured form snapshot omits the field entirely). If the platform's set[] check requires  
  a submitted key (not just a non-empty value) to be satisfied, these two combos could stop  
  firing entirely, with no sibling OOS DH combo to fall back to. Rob's call (2026-08-06): apply  
  it and verify live rather than leave it unproven. THE DISCRIMINATING TEST, before anything  
  else in this sweep: does DALHOUT (Name+State) and DALLOUT (OLN+State) still fire, and does  
  <Requestor> carry the real officer name on the wire? If either fails, revert this diff on  
  requestorDH specifically (restore initialValue='X' + the two combo defaults[] entries) --  
  do not touch the TX/FL/CA_CLETS fix, which is unrelated and already wire-proven.  

## v4.19 -- 2026-07-30 -- Label the orphaned Plate Year field; record the requestorDH gap (commit 22b1695b)

**CHANGED:** Labelled the orphaned Plate Year control and recorded the requestorDH verification gap.
**REASON:** See commit 22b1695b. Recovered 2026-08-03 -- this entry read "Rebuilt via pipeline.ps1 /
  Scheduled rebuild", as did v4.18 below.  

## v4.18 -- 2026-07-30 -- OOS plate path made spec-correct -- Rob ruling OPTION A (commit 226ec672)

**CHANGED:** The out-of-state plate path was made spec-correct per Rob's OPTION A ruling.
**REASON:** See commit 226ec672. Recovered 2026-08-03 from the same generic-stub class as v4.19.
  TENANT-VERIFIED at the v4.19 re-sweep: RVEHOUT fires with State + LicensePlateTypeCode and  
  carries State on the wire, while in-state RVEH carries none -- the path this version fixed.  

## v4.17 -- 2026-07-29 -- Split the compacted Driver History row -- DEX-1284, Leo CAD review (85a694cf)

**CHANGED:** The compacted DH row was split across lines. Layout only -- no combo, QIDM, routing,
  fieldId or wire change.  
**REASON:** DEX-1284, Leo's CAD review. Recovered 2026-08-03 -- this entry read "Rebuilt via
  pipeline.ps1 / Scheduled rebuild", the tenth instance of that class found today and the third on  
  this provider (v4.17/v4.18/v4.19). Found while writing the Jira changelog FROM these entries,  
  which is exactly the downstream cost the new audit_buildnotes_fidelity gate exists to stop.  

## v4.16 -- 2026-07-27 -- UPPERCASE card titles (Rob global decision, NO functional change)

**CHANGED:** All card titles UPPERCASED, wording unchanged (e.g. "Driver License Search by OLN,
  \"OR\" Name" -> "DRIVER LICENSE SEARCH BY OLN, \"OR\" NAME"). Mechanical uppercase transform;  
  no wording/field/combo/QIDM change. New global convention (BUILD_RULES Section 11).  
**REASON:** Rob -- "everything needs to be upper case." Title-only. NOTE: this bump RESETS NY's
  v4.15 tenant-complete state (block by version) -- the v4.15 66-log tenant pass is superseded;  
  re-test owed. verify_build clean. ALL 5 ENTITIES RESET at v4.16. NOT yet re-tested.  

## v4.15 -- 2026-07-27 -- DEX-1284 shadow-review follow-up -- in/out routing gates (FUNCTIONAL)

**CHANGED:** Gated the 4 previously-ungated in/out combos so an out-of-state (State-bearing) query
         no longer co-fires with its NY in-state sibling. Existence-only RegistrationState gates  
         (poisoned-array-safe):  
           VehicleRegistrationQuery  
             - RVEHOUT (OOS plate)  += RegistrationState EXISTS  
             - RVEH    (NY plate)   += RegistrationState NOT_EXISTS  
             - RCAR    (NY VIN)     += RegistrationState NOT_EXISTS  (alongside existing LPN NOT_EXISTS)  
           BoatQuery  
             - BVIN    (OOS hull)   += RegistrationState EXISTS  
             - RVEH    (NY reg)     += RegistrationState NOT_EXISTS  (alongside existing Hull NOT_EXISTS)  
             - RCAR    (NY hull)    += RegistrationState NOT_EXISTS  
         (RVIN and BVEH were already State-gated; DriverHistory in/out already gated at v4.0.)  
         Header comment corrected 7 QIDMs/17 combos -> 6/16 (DGRP was removed at v4.11) and the  
         stale DGRP QIDM/DL+DGRP lines dropped.  
**REASON:** DEX-1284 portfolio shadow-query review. Rob's rule: in-state vs out-of-state are ALWAYS
         distinct queries (the FL_FCIC pattern) -- both siblings must stay reachable but must NOT  
         co-fire. Adversarial re-review confirmed NY has NO shadow-subset combos to remove (unlike  
         TX_TLETS QV). Functional routing change: Vehicle + Boat reset for re-test from T1;  
         Person/Firearm/Article fingerprints unchanged (preserved-blocked). NOT yet tenant-tested  
         at v4.15 (Rob re-runs the NY sweep).  

## v4.14 -- 2026-07-27 -- DEX-1284: Person cards -- OLN + State + NCIC Image on the top line

**CHANGED:** Both Person cards (DRIVER LICENSE + DRIVER HISTORY) now place the primary identifier
         and the two routing/option fields together on the TOP row (6/3/3):  
           - OLN [6] | State [3] | NCIC Image [3]  
         Merged the old two-row arrangement (row 1 = OLN full-width [12]; row 1B = State/Image  
         [6/6]) into one top row per card. OLN keeps the width (long identifier); State and  
         NCIC Image are short codes at 3 each. Name row (First/Last/MI/Suffix) and DOB/Sex row  
         follow unchanged. Applies to CARD_PER_DL and CARD_PER_DH identically.  
         No label/fieldId/combo/default change -- pure row/column regrouping.  
**REASON:** DEX-1284 (Rob) -- "on the person put OLN, State and NCIC Image on the top line for each
         card." Recorded as the global Person top-row pattern in BUILD_RULES Section 11 (future  
         retrofit per provider on revisit -- Rob: "expect this level of cleanup on all providers").  
         Layout-only -- no combo/QIDM/routing/fieldId change. All 5 entities reset for re-test at  
         v4.14 (block-by-version; Vehicle force-reopened so its v4.13 logs don't carry over).  

## v4.13 -- 2026-07-27 -- DEX-1284: Vehicle card 4/4/4 balance + global field-size/placement standard

**CHANGED:** Rebalanced the Vehicle card to a uniform 4/4/4 column grid so fields align
         left-to-right AND top-to-bottom:  
           - ROW_VEH_1 (Plate Number / Plate Type / Plate Year): 4/2/2 -> 4/4/4  
             (was filling only 8 of 12 cols; Plate Type/Year were cramped at width 2)  
           - ROW_VEH_2 (VIN / Vehicle Make / Vehicle Year): 6/3/3 -> 4/4/4  (VIN 6 -> 4)  
           - ROW_VEH_3 (State / NCIC Image): 6/6 -> 4/4  (State 6 -> 4; a 2-char code no  
             longer sits in a half-row box; State/Image align under the columns above)  
         No label/fieldId/combo/default change on the Vehicle card.  
TOOLING/DOCS (this session, no NY JSON impact beyond the layout above): (1) corrected  
         docs/reference/NY_NYSPIN_EJUSTICE_SUPPORTED_QUERIES.txt -- removed the false  
         "DL Name Search | Name" CONFIRMED line (NyNyspinDriverLicenseNameQuery is an  
         "Expanded Transactions Supported" transaction @844, NOT Basic; removed from the build  
         at v4.11) and embedded the devdoc ground-truth Basic list. (2) hardened  
         tools/audit_supported_queries.ps1 (Get-DevdocBasic) to extract + embed each devdoc's  
         real "Basic Queries Supported" list into the seeded template and print it every run  
         (closes the rubber-stamp hole that let the DGRP shadow pass a CONFIRMED gate).  
**REASON:** DEX-1284 (Leo/Rob) -- "shorten VIN and State so everything looks balanced left-to-right
         and top-to-bottom; do better at field size and placement globally." New GLOBAL  
         field-size/placement standard recorded in BUILD_RULES Section 11 (uniform grid, size to  
         the grid, no lopsided <12 rows, no half-row box for a short code field), FUTURE-RETROFIT  
         per-provider on revisit. Layout-only -- no combo/QIDM/routing/fieldId change. All 5  
         entities reset for re-test at v4.13.  

## v4.12 -- 2026-07-27 -- DEX-1284: HI-style lean label pass (all 5 entities) + global "NCIC Image" convention

**CHANGED:** Stripped every inline field helper EXCEPT the State routing hint, across all 5 entities.
         The card TITLE now carries each entity's query paths (the NY Vehicle model extended to  
         the rest):  
           - Person DL card title -> 'Driver License Search by OLN, "OR" Name'  
           - Person DH card title -> 'Driver History Search by OLN, "OR" Name'  
           - Firearm card title    -> 'Firearm Search by Serial Number'  
           - Article card title    -> 'Article Search by Serial Number'  
           - Boat card title       -> 'Boat Search by Registration, "OR" Hull ID'  
           - Vehicle title unchanged ('Vehicle Registration Search by Plate, "OR" VIN' -- the model)  
         Field label strips: Plate Number / VIN / Vehicle Make / Vehicle Year (Vehicle);  
         First/Last/MI/Suffix/DOB/Sex/Purpose Code (Person DL+DH); Gun Make / Caliber (Firearm);  
         Article Type (Article); Registration Number (Boat). State keeps 'State (leave blank for NY)'.  
         Image fields (ImageIndicator + DH) -> canonical bare "NCIC Image".  
         Firearm + Article stolen-hit toggle (relatedHitSearchIndicator) -> "Stolen Check".  
TOOLING: verify_build.ps1 CHECK 15 Rule 3 gained a $canonicalBareLabels allowlist that accepts the  
         bare "NCIC Image" label (global convention -- purely permissive, cannot regress any  
         provider). LABEL-OVERRIDE tags added for the deliberately-bare any[] fields  
         (VehicleMakeCode, vehicleYear, nameMiddle, nameSuffix, nameMiddleDH, nameSuffixDH, GunMake,  
         GunCaliber, relatedHitSearchIndicator).  
**REASON:** DEX-1284 (Leo) direct feedback -- lean/HI-style labels, card title guides the query. Two
         NEW GLOBAL conventions recorded in BUILD_RULES Section 11 + CLAUDE.md field-config, both  
         FUTURE-RETROFIT (applied per-provider on its revisit turn, NY first): (1) canonical  
         "NCIC Image" image-field label; (2) lean-label / card-title-carries-the-path style.  
         Label/title-only -- NO combo/QIDM/routing/fieldId/default change. All 5 entities reset for  
         re-test at v4.12. DEFERRED: none for this pass (purpose-code dropdown still pending Leo).  

## v4.11 -- 2026-07-27 -- DEX-1284: remove DGRP name-search card + OLN relabel (2-card Person)

**CHANGED:** Removed the NyNyspinDriverLicenseNameQuery (DGRP) "DL NAME SEARCH" QIDM + card ->
         Person condensed to 2 cards (DRIVER LICENSE + DRIVER HISTORY). Relabeled the OLN field  
         on both cards (OperatorLicenseNumber / OperatorLicenseNumberDH) "License Number (or  
         search by Name)" -> "OLN" (global OLN labeling convention, NY's revisit turn).  
         QIDMs 7->6, Person cards 3->2, combos 17->16.  
**REASON:** DEX-1284 (Leo) -- the DGRP card was a name-only shadow of DriverLicenseQuery's DLICN
         (Name+DOB+Sex) combo, an Expanded/non-Basic transaction. Data-safe removal (DGRP fields  
         self-contained). DL-by-name now runs via DLICN (requires Name+DOB+Sex). RMS person query  
         unchanged. DEFERRED to Rob's specifics: HI-style label trim, CAD-render QA; purpose code  
         left as-is. ALL 5 entities reset for re-test at v4.11.  

## v4.10 -- 2026-07-20 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.9 -- 2026-07-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.8 -- 2026-07-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.7 -- 2026-07-13 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.6 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.5 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.4 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.3 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.2 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.1 -- 2026-07-07 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v4.0 -- 2026-07-06 -- Cross-provider hardening rollout (rebuild, not a routine pipeline pass)

**CHANGED:**
  - PascalCase conversion: the 22 USx CAD-integration field names authored natively  
    PascalCase (sourceField/set/any/layout fieldId); RMS bundle built with  
    -PascalCaseUsxFields. Fields not on the 22-token list (vehicleYear, nameMiddle(DH),  
    nameSuffix(DH), relatedHitSearchIndicator, purposeCodeDH, requestorDH,  
    nyNyspinTransactionNameDH) intentionally stayed camelCase.  
  - Poisoned-array fix (DriverHistoryQuery): the old State-value-comparison conditions  
    (In=IN('NY','null'), Out=NOT_EQUALS 'NY') keyed on the attribute NAME instead of  
    sourceField AND used value-comparison operators -- per the live-proven  
    POISONED-ARRAY RULE these were wholly inert, so DALHOUT/DALH/DALLOUT/DALL had zero  
    real in-state/OOS routing. Replaced with existence-only conditions on  
    RegistrationState (EXISTS on the OOS combos, NOT_EXISTS on the in-state combos).  
  - Identifier-priority guardrail rollout (3 pairs): Vehicle Plate>VIN (LicensePlateNumber  
    NOT_EXISTS on RVIN/RCAR), Person OLN>Name on both DriverLicenseQuery (DLICN) and  
    DriverHistoryQuery (DALHOUT/DALH), and Boat Hull>Reg (BoatHullIdNumber NOT_EXISTS on  
    BVEH/RVEH).  
  - OOS-gate symmetry hardening: added RegistrationState EXISTS to RVIN (Vehicle) and  
    BVEH (Boat) -- set[] is not a firing gate, so these OOS combos were previously  
    shadowing their in-state counterparts (RCAR / Boat RVEH) on a bare-identifier  
    payload regardless of State (verify_build CHECK 16, a genuine pre-existing latent  
    bug exposed once the new NOT_EXISTS guardrails made those combos checkable).  
  - CAD default gap fix: added PurposeCode='C' to DALHOUT/DALLOUT's defaults[] (form  
    initialValue existed but had no matching combo default; CAD ignores initialValues).  
  - Adopted the versioned root JSON filename (NY_NYSPIN_EJUSTICE_v4.0.json), replacing  
    the bare NY_NYSPIN_EJUSTICE.json, matching NJ/HI/FL/CA_CLETS.  
  - Cleared 2 shared-module PENDING_UPDATES.txt flags (RND-62365 VehicleMakeName QRDM,  
    PARSECOMMSYS-ARGS ParseCommsysName empty-args bug) -- both fixes already live in  
    shared tooling, picked up automatically by this rebuild.  
**REASON:** NY had never received the identifier-priority/poisoned-array/PascalCase rollouts
  already live-proven on HI_HCJDC_OFML/FL_FCIC/TX_TLETS/CA_CLETS. Full re-test mandate --  
  Vehicle/Person/Boat entities reset to PENDING (Firearm/Article structurally unchanged  
  besides PascalCase renames, which do not change wire XML).  

## v3.0 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.9 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.8 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.7 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.6 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.5 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.4 -- 2026-06-09 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.3 -- 2026-06-08 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.2 -- 2026-06-08 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-06-03 -- Layout tightening + DGRP QIDM


## v2.0 -- 2026-05-22 -- Single JSON rebuild (BASE/MC merge, 7 fixes)


## v1.6 -- 2026-05-18 -- Single JSON output + shared tooling rebuild

**CHANGED**
  - Single pretty-printed JSON output (READABLE files eliminated)  
  - Rebuilt with current shared tooling improvements  
  - No functional QIDM or layout changes  
**REASON**
  - Repo-wide elimination of dual JSON output (minified + readable)  
  - Shared module updates (_build_provider_helpers.ps1, _build_rms_bundle.ps1)  
VALIDATOR  
  - BASE: 74 PASS / 0 FAIL / 0 WARN  
  - MC:   74 PASS / 0 FAIL / 0 WARN  

## v1.5 -- 2026-05-11 -- LIMITATION elimination pass

**CHANGED**
  - DH-suffix fieldIds, queriesToDeselect, combo ordering  
  - DGRP removed, DLICN restored in DL QIDM for single checkbox  
VALIDATOR  
  - BASE: 74 PASS / 0 FAIL / 0 WARN / 0 LIMITATION  
  - MC:   74 PASS / 0 FAIL / 0 WARN / 0 LIMITATION  

## v1.2 -- 2026-05-07 -- Monorepo rebuild + Patch 8

**CHANGED**
  - Patch 8: LicensePlateNumberIn -> licensePlateNumber (CAD auto-populate)  
  - Rebuilt with current validate.ps1/build_report.ps1 toolchain  
  - Reports regenerated at docs/base/ and docs/mc/  
**REASON**
  - CAD auto-populate standardization (Patch 8, all providers)  
  - Monorepo migration standardization  
VALIDATOR  
  - BASE: 72 PASS / 0 FAIL / 0 WARN / 5 LIMITATION  
  - MC:   72 PASS / 0 FAIL / 0 WARN / 5 LIMITATION  

## v1.1 -- 2026-04-30 -- NJ cross-reference rebuild (GATE 7)

**CHANGED**
  - ImageIndicator FormSelect added to ALL entities (Vehicle, Firearm, Article, Boat forms)  
    Person already had ImageIndicator; changed from FormInput to FormSelect (NIBRS/YES_NO_UNKNOWN)  
  - ImageIndicator QIDM attribute + combo any[] added to ALL QIDMs that support it  
    Vehicle (RVIN/RVEH/RCAR), Gun (GINQ), Article (AINQ), Boat (BVEH/BVIN/RVEH/RCAR)  
  - AUTH keyReference='AUTH' added to authentication combination  
  - RMS autoSelect=true added to both Vehicle and Person RMS QIDMs (Patch 7)  
  - MC build script: same fixes mirrored in multi-card layout (OPTIONS cards + entity cards)  
**REASON**
  - Cross-reference against NJ_NJCJIS baseline (GATE 7) revealed 11 warnings:  
    ImageIndicator missing from 4 entities, Person Image was FormInput not FormSelect,  
    AUTH had no keyReference, RMS QIDMs missing autoSelect  
  - Validator updated same session: WARN/LIMITATION taxonomy, Write-Limitation function  
  - v1.0 was declared DONE without NJ cross-reference — this rebuild corrects that  
VALIDATOR  
  - BASE: 71 PASS / 0 FAIL / 0 WARN / 5 LIMITATION / 13 FIRE / 0 SKIP  
  - MC:   71 PASS / 0 FAIL / 0 WARN / 5 LIMITATION / 13 FIRE / 0 SKIP  

## v1.0 -- 2026-04-24 -- Phase 1 + MC confirmed build

**CHANGED**
  - Both BASE and MC variants live-tested: BASE 15/15 PASS, MC 19/19 PASS  
  - Patch 6 (RMS cleanup) applied  
  - DGRP removed, DLICN handles Name path within DriverLicenseQuery  
  - queryLabel standard applied  
  - NCIC state pattern and NIBRS sex reverse-lookup confirmed  
  - PlateType=PC, PlateYear=2026 defaults (retested 2026-04-28)  

## v1.1-old -- 2026-04-20 -- Fix RMS import error: sexcodeoos missing attribute

**CHANGED**
  - build_ny_nyspin_ejustice.ps1: RMS sex removal patch now strips 'SexCodeOOS'  
    from combination any[] in addition to 'SexCode'.  
  - Filter condition changed from name-based to targetField-based (targetField -ne 'sexAttrId')  
    so both 'sex' (sourceField=SexCode) and 'sexOOS' (sourceField=SexCodeOOS) attrs are removed.  
**REASON**
  - Import failed: "Missing attributes found in query input data mapping: [sexcodeoos]"  
  - HIDLE RMS Person QIDM has 4 OOS combinations (driversLicenseNumberOOS etc.) that include  
    'SexCodeOOS' in any[]. When we removed the sexOOS attribute but not the combination  
    reference, the platform rejected the bundle (unresolved sourceField reference).  
  - Fix: filter both SexCode and SexCodeOOS from combination any[]/set[].  

## v1.0 -- 2026-04-20 -- Phase 1 reboot -- single-card single-entity build from XML metadata

**CHANGED**
  - Complete rewrite of build_ny_nyspin_ejustice.ps1 (Phase 1 architecture).  
  - 5 QIFs (single card each): Vehicle, Person, Firearm, Article, Boat.  
  - 7 QIDMs: VehicleRegistrationQuery (RVEH/RVIN/RCAR), BoatQuery (BVEH/BVIN/RVEH/RCAR),  
    DriverLicenseQuery (DLIC), NyNyspinDriverLicenseNameQuery (DGRP),  
    DriverHistoryQuery (DALL+DALH), GunQuery (GINQ), ArticleSingleQuery (AINQ).  
  - WINQ/MINQ excluded (no Transaction XML in metadata).  
  - State: blank-default NJ_NIBRS_STATE + hidden SelH RegistrationState (RMS).  
  - Sex: NIBRS_SEX CommSys-only, removed from RMS Person QIDM.  
  - DH-suffix fieldIds on all DH fields.  
**REASON**
  - Prior builds (v1.0-v1.21) built multi-card/split-entity before QIDMs were confirmed.  
    Phase 1 single-card isolates QIDM problems from layout problems (NJ lesson).  

## v1.5 -- 2026-05-11 -- LIMITATION elimination pass

