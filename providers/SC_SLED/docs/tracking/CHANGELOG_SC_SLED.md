# SC_SLED -- Changelog

Auto-generated from `SC_SLED_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.3** | Generated: 2026-09-16

---

## v1.3 -- 2026-09-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

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
