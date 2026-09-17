# SC_SLED -- Changelog

Auto-generated from `SC_SLED_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.9** | Generated: 2026-09-17

---

## v1.9 -- 2026-09-17 -- LAYOUT PASS -- name controls go FIRST-LAST-MIDDLE-SUFFIX everywhere, rows resequenced

**CHANGED:** VEHICLE -- now 2 rows. `RegistrationState` moves to the END of row 2 (cols 5/3/2/2) and
            ROW_VEH_3 is deleted.  
         PERSON  -- row 2 carries all four name components in First, Last, Middle, Suffix order  
            (was Last/First/Middle with Suffix orphaned onto the DOB row). Row 3 is now  
            DOB / Sex / NCIC Image.  
         WANTED  -- six rows resequenced to lead with, in order: first name, plate, OLN, NCIC,  
            SSN, expanded name. Name row in First/Last/Middle/Suffix order; OLN promoted to the  
            FIRST field of its row and that row is now 3rd; the plate row (formerly last) is 2nd.  
         BOAT    -- `BoatHullIdNumber` label 'Hull ID (takes priority over registration)' ->  
            'Hull ID'. `RegistrationState` label -> 'State (leave blank for SC)'.  
         AM      -- `DestinationCode` label -> 'Destination ORI (required)'. ROW_AM_3 cols 4/4 ->  
            6/6, which clears the ONLY `audit_layout_flow` advisory on this provider (L6  
            ROW-NOT-12: two fields at 4 sum to 8 and left 4 columns of dead space on the right).  
            Pre-existing since v1.2 and surfaced by enforce PHASE 2w during this pass; fixed here  
            because a layout pass is exactly when it should be, not left for the next reader.  
         Validator 77P/0F/2W/2LIM, UNCHANGED from v1.8.  
**REASON:**  Rob 2026-09-17, after confirming v1.8 rendered correctly: "on veh lets move state to the
         end of the second line  veh will have 2 lines  person  do first last middle suffic on  
         second line  wanted person  do tope line in first last middel suffix format  we need to  
         use that format everythwere  second line put oln as first fiedl then make the oln line  
         3rd row  wanted rows should start with frist name  plate oln ncic ssn and expanded name  
         move the last line with plate  and make that the second line  on boat remove the helper  
         on hull id  i asked for tht previously  clean up state helper to just say leave blank for  
         SC  on admi ... change helper on destiantion ori to just say required".  

## v1.8 -- 2026-09-17 -- ADMINISTRATIVE MESSAGE IS LAST, as asked -- and the tab-order rule is now MEASURED

**CHANGED:** 1. `$amForm` AND `$amQuery` move targetEntity 'Article' -> 'Boat'. Both, not one: see below.
         2. `$entityOrder` last element 'Article' -> 'Boat'.  
         3. Boat's `RegistrationState` control: `Sel` (attributeTypeId='STATE') -> `Inp`, 2 chars,  
            label 'State (2-char code; leave blank for SC)'.  
         4. BoatQuery's `State` attribute: `-CodeTypeProvider 'NCIC'` REMOVED.  
         No combination, keyRef, set[]/any[] or field id changed. Validator 78P -> 77P/0F/2W/2LIM  
         (the lost PASS is the Boat State dropdown check; nothing regressed).  
**REASON:**  Rob 2026-09-17, on the rendered v1.7 tenant: "tab order is still wrong ... put admin at
         the end like i asked". He had asked for this order on 09-16 and v1.7 did not deliver it.  

## v1.7 -- 2026-09-16 -- OLN>NAME GUARDRAIL ON DriverRegistrationQuery -- the co-fire's missed cost

**CHANGED:** `DQ.RN` gains `conditions: [{ field: [OperatorLicenseNumber], operator: NOT_EXISTS }]`.
         One combination, one condition. No field, label, layout, order or attribute change.  
         Validator 78P/0F/2W/2LIM (unchanged). Registry: +1 row.  
**REASON:**  v1.6 SHIPPED COMMITTED WITH THREE BLOCKING FAILS AND I CALLED IT DONE OFF THE VALIDATOR.
         The validator read 78P/0F, the build printed "Validation passed", and the JSON was  
         committed in d538fbac -- but `enforce` had not been read. It reported:  
             [FAIL] verify_build -- DQ.RN missing OperatorLicenseNumber NOT_EXISTS  
                    (OLN>Name guardrail; OLN+Name co-entry will bleed Name into OLN XML)  
             [FAIL] DriverRegistrationQuery #1 +[ImageIndicator]        -> not transmitted  
             [FAIL] DriverRegistrationQuery #1 +[ImageIndicator,State]  -> not transmitted  
         This is the SECOND time on this provider that "the validator passed" was mistaken for  
         "enforce passed" (v1.2 was the first). The validator does not run verify_build, the  
         devdoc-optional gate, or the parity cross-check.  

## v1.6 -- 2026-09-16 -- DRIVER LICENSE + DRIVER REGISTRATION CO-FIRE, plus a label/layout pass

**CHANGED:** 1. CO-FIRE. `CARD_PER_DR` and every DR-suffixed control DELETED. DriverRegistration's
            attributes and combinations now point at the SHARED Driver License controls, and  
            `-QueriesToDeselect @('DriverLicenseQuery')` is GONE -- that deselect was the one  
            thing preventing the co-fire. Person: 2 cards/10 fields -> ONE card. DL card title  
            now says both queries are sent.  
         2. HELPER TEXT REMOVED, per request: Vehicle VIN, Wanted VIN, Wanted Plate Number,  
            Wanted NCIC Number, Article Serial Number.  
         3. WANTED ROW ORDER: Name first, DOB/Sex/Race/OLN second, NCIC + case number third.  
            Sequence only -- same rows, same field ids, no wiring touched.  
         Validator 79P/0F/2W/1LIM -> 78P/0F/2W/2LIM.  
**REASON:**  Rob 2026-09-16: "on person remove help on vin  lets co fire driver reg and driver license
         since they are idnetical combos  remove helper on atricle serial  on eanted lets move the  
         name row to the top  dob line to 2nd  and top row down 2  remove helper on ncic and plat  
         enumber".  

## v1.5 -- 2026-09-16 -- TAB ORDER set to the sequence Rob asked for

**CHANGED:** Nothing but ordering. No field, combination, attribute or QIDM touched.
         `$entityOrder`     : Vehicle, Person, Firearm, Firearm, Article, Boat, Article  
         `-Configurations`  : vehicleForm, personForm, wpForm, firearmForm, articleForm,  
                              boatForm, amForm   (moved wpForm up from 6th to 3rd)  
         79P/0F/2W/1LIM unchanged.  
**REASON:**  Rob 2026-09-16: "we need to reorder the tabs  veh per wanted person firearm articel boat
         admin mesage  in that order please".  

## v1.4 -- 2026-09-16 -- The AM field suffix comes back OFF -- it was never needed and it broke a gate

**CHANGED:** FreeTextAM / DestinationCode1-5AM renamed back to FreeText / DestinationCode1-5, in the
         form controls and the QIDM sourceFields alike. Nothing else. 79P/0F/2W/1LIM unchanged.  
**REASON:**  v1.2 suffixed these ids as belt-and-braces against LIMITATION #26's shared field pool.
         IT PROTECTED AGAINST NOTHING: Article's own controls are ArticleSerialNumber and  
         ArticleTypeCode, so there was never a name in common with FreeText/DestinationCode -- the  
         pool was already disjoint by construction.  
         AND IT COST A BLOCKING GATE. `audit_devdoc_combinations` compares the devdoc's field  
         names against the combination's SOURCEFIELDS, canonicalised by `Get-CanonicalToken`,  
         which strips the established isolation suffixes `dh$` / `cch$` / `dr$` -- not `am$`. So  
         `freetextam` stopped matching the devdoc's `FreeText` and enforce reported  
         "AdministrativeMessage #1 is devdoc-listed but UNBUILT: mandatory field(s) FreeText,  
         DestinationCode wired nowhere" on a provider that builds it.  
         THE OTHER FIX WAS REJECTED ON PURPOSE: adding `am$` to that canonicaliser would widen a  
         shared function feeding a BLOCKING gate across all 21 providers, and `am$` is a much  
         riskier string to strip globally than `dh`/`dr`. Widening a portfolio-wide canonicaliser  
         to accommodate one provider's unnecessary cosmetic choice is the wrong trade. Use a  
         suffix here only if a REAL collision appears, and add `am$` in the same change.  

## v1.3 -- 2026-09-16 -- WANTED PERSON GETS ITS OWN TAB -- and three dropdowns became type-ins to pay for it

**CHANGED:** 1. `CARD_PER_WANTED` REMOVED from the Person QIF. Person: 3 cards/20 fields -> 2/10.
         2. `ENTITY_WantedPerson` added as its own QUERYINPUTFORM, targetEntity='Firearm'.  
            SEVEN TABS now. Ordered before Administrative Message.  
         3. THE NEW TAB IS SELF-CONTAINED: it gained its own Name (Last/First/Middle/Suffix),  
            BirthDate, SexCode, OperatorLicenseNumber and ImageIndicator controls -- 13 fields  
            -> 18.  
         4. THREE CONTROLS CONVERTED Sel -> Inp, and their `-CodeTypeProvider` removed from the  
            `$wpAttrs` attributes ONLY: raceCode (NIBRS), SexCode (NIBRS), LicensePlateStateCode  
            (NCIC). Labels now carry the valid values ("type M, F or U" / "type W, B, I, A or U"  
            / "type the 2-letter code").  
         Validator 79P/0F/0W/1LIM -> 79P/0F/2W/1LIM.  
**REASON:**  Rob: "now move wanted person to its own tab", then after being shown the cost: "start
         with option A  we can work backwards if we have to".  
         Possible at all because of CAPABILITY #47 -- tabs are keyed by QUERYINPUTFORM, not by  
         entity. It also delivers the ORIGINAL request behind all of this: Person is decrowded,  
         halved from 20 fields to 10.  

## v1.2 -- 2026-09-16 -- ADMINISTRATIVE MESSAGE GETS ITS OWN TAB -- tabs are per-FORM, not per-entity

**CHANGED:** 1. The AM card REMOVED from the Vehicle QIF. Vehicle: 2 cards/10 fields -> 1 card/4,
            i.e. back to what it was at v1.0.  
         2. `ENTITY_AdministrativeMessage` RESTORED as its own QUERYINPUTFORM -- but declaring  
            targetEntity='Article' (a RECOGNISED value) rather than 'AdministrativeMessage'.  
            QIFs 5 -> 6, so SIX TABS. It is ordered LAST so the five familiar tabs keep their  
            positions. `Article` appears TWICE in all three order arrays, on purpose.  
         3. All six AM controls RENAMED with an AM suffix: FreeTextAM, DestinationCodeAM,  
            DestinationCode2AM..5AM. The QIDM attributes keep their unsuffixed NAMES and point  
            their sourceFields at the new ids; the combination's set[]/any[] carry the suffixed  
            SOURCEFIELDS while primaryFieldReference keeps the attribute name 'FreeText'.  
         4. QIDM TargetEntity 'Vehicle' -> 'Article'.  
            Validator 78P/0F/0W/1LIM -> 79P/0F/0W/1LIM.  
**REASON:**  CAPABILITY #47, LIVE-PROVEN: TABS ARE KEYED BY QUERYINPUTFORM, NOT BY ENTITY.
         Evidence: docs\evidence\ENTITY_PROBE_RESULT_2026-09-16.txt. Rob refused the v1.1  
         compromise -- "there has to be a way to have more than 5  this is just a card on the veh  
         page.   i want it compeltely seperated" -- and then refused the reasoning behind it too:  
         "are you sure you are testing this correctly  i feel like 5 is arbitraty". He was right  
         both times. A probe declaring 8 forms (three of them sharing targetEntity='Person')  
         rendered EIGHT TABS. So a transaction needs no entity of its own to get a tab.  

## v1.1 -- 2026-09-16 -- AdministrativeMessage rehosted onto Vehicle -- the sixth entity does not render

⚠️ SUPERSEDED BY v1.2 AFTER ~40 MINUTES, AND TWO CLAIMS BELOW ARE REFUTED. Kept verbatim because  
it is the honest record of what was believed, but do not read it as current:  
  - "A CARD LIVES INSIDE AN ENTITY, so the only way to make this transaction reachable is to host  
    it on one of the five" -- FALSE. Tabs are keyed by QUERYINPUTFORM (CAPABILITY #47), so a  
    transaction can have its own TAB while declaring a recognised entity value.  
  - "ALSO REFUSED ... WantedPersonQuery can only be reorganised WITHIN Person's cards" -- FALSE  
    for the same reason. It CAN be moved to a tab of its own.  
What survives from this entry: LIMITATION #46 itself (an UNRECOGNISED targetEntity value renders  
nothing) and the measurement that the v1.0 build was structurally correct.  
**CHANGED:** 1. `ENTITY_AdministrativeMessage` (targetEntity='AdministrativeMessage') DELETED.
            QIFs 6 -> 5; the ENTITIES order arrays are back to the five real entities.  
         2. The ADMINISTRATIVE MESSAGE card (FreeText + DestinationCode1-5, 3 rows, 6 controls)  
            MOVED into the Vehicle QIF as its second card. Vehicle: 1 card/4 fields -> 2/10.  
         3. `SC_SLED_AdministrativeMessage` QIDM TargetEntity 'AdministrativeMessage' -> 'Vehicle'.  
            Attributes, the single `AM` combination and all field wiring are UNCHANGED.  
         4. Every `STATUS: HYPOTHESIS` marker for this transaction removed and replaced with the  
            measured outcome. Validator 80P/0F/0W/1LIM -> 78P/0F/0W/1LIM (two PASS lines were the  
            deleted QIF's).  
**REASON:**  LIMITATION #46, measured on the FIRST AUTOMATED IMPORT. Rob: "i did not see a admin card
         doublecheck your work". It was double-checked and THE v1.0 BUILD WAS CORRECT -- ENTITIES  
         was bundle [0], the QIF existed, ALL THREE order arrays named AdministrativeMessage, and  
         the tenant provably received that payload (read-back byte-exact, bundle table 0 -> 3).  
         A correctly-formed sixth entity is SILENTLY DROPPED. Measured portfolio-wide the same  
         day: all 21 providers use exactly Person/Vehicle/Firearm/Article/Boat, and  
         AdministrativeMessage had exactly one carrier -- the one that vanished.  

## v1.0 -- 2026-09-14

**CHANGED:** Initial standup
**REASON:**  New provider onboarding
