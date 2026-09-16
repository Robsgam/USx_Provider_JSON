# SC_SLED -- Changelog

Auto-generated from `SC_SLED_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.2** | Generated: 2026-09-16

---

## v1.2 -- 2026-09-16 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-09-16 -- AdministrativeMessage rehosted onto Vehicle -- the sixth entity does not render

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
