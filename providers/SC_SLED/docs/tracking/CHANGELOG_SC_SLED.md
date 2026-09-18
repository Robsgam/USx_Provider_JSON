# SC_SLED -- Changelog

Auto-generated from `SC_SLED_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.18** | Generated: 2026-09-18

---

## v1.18 -- 2026-09-18 -- WANTED PERSON TAB WAS PUTTING DATABASE ROW NUMBERS ON THE WIRE -- coded controls reverted to codeTypeCategory

**CHANGED:** On ENTITY_WantedPerson (targetEntity='Other') the three coded dropdowns move from
            attributeTypeId back to codeTypeCategory, and their QIDM attributes drop  
            codeTypeProvider to match:  
              SexCode   attributeTypeId=SEX   + provider NIBRS  ->  NIBRS_SEX | NIBRS  
              raceCode  attributeTypeId=RACE  + provider NIBRS  ->  NIBRS_RACE | NIBRS  
              State     attributeTypeId=STATE + provider NCIC   ->  NJ_NIBRS_STATE | NJ_NIBRS  
         VehicleMakeCode on that tab becomes a FormInput (24 chars). Rob 2026-09-18:  
            "leave veh make as a free text  no choice".  
         The Vehicle tab is UNTOUCHED -- its make dropdown still ships PASS_FORD, which is  
            LIMITATION #38 and PARKED portfolio-wide. This is an `Other`-only change.  
**REASON:** MEASURED ON THE WIRE, from the v1.17 sweep captured the same day:
              <SexCode>73046851255</SexCode>                 expected M  
              <RaceCode>73046859570</RaceCode>               expected W  
              <LicensePlateStateCode>73046852196</LicensePlateStateCode>  expected GA  
              <VehicleMakeCode>73046859129</VehicleMakeCode>  
         -- the platform's internal numeric row ids, WITH codeTypeProvider correctly set on all  
         three attributes, so this is NOT AP #1 (a MISSING provider); the provider is present and  
         ignored. v1.17 had converted these to attributeTypeId on the reasoning that `Other`  
         hosts ONE QIF so LIMITATION #28 does not apply. #28 is about TWO QIFs on one entity;  
         this is a different failure that looks identical on the wire.  
THE CONTROLLED COMPARISON IS IN THE SAME CAPTURE, which is why this is measured and not argued:  
         VehicleMakeCode has BYTE-IDENTICAL attribute config on the Vehicle tab and on this one,  
         and sent PASS_FORD there and 73046859129 here. targetEntity is the only variable.  
AND A POSITIVE CONTROL, so "Other breaks everything" is refuted too: ImageIndicator and  
         RelatedHitSearchIndicator are codeTypeCategory controls on this SAME tab and came  
         through correctly as Y/N in the SAME submits. On `Other`: attributeTypeId does NOT  
         resolve, codeTypeCategory DOES.  -> LIMITATION #50.  
THE REPLACEMENT PAIRINGS ARE NOT A GUESS. They are what this tab already rendered, read from the  
         committed capture docs/reference/TENANT_PICKLISTS.json (v1.11): NIBRS_SEX 3 options,  
         NIBRS_RACE 7 options, NJ_NIBRS_STATE 57 options, all with real code-prefixed labels.  
         v1.17 changed away from a working configuration; v1.18 changes back.  
WHY MAKE CANNOT BE A DROPDOWN HERE: it is the only one of the four with NO category to fall back  
         to. A census of every codeTypeCategory on every form control in all 21 providers  
         returns ten and not one is a vehicle make (NCIC_FIREARM_MAKE is firearm-only, AP #24;  
         VEHICLE_TYPE is body type). So the choice on `Other` is a dropdown that ships a row  
         number or a text box that ships what the officer typed, and QWA.VM makes  
         VehicleMakeCode MANDATORY -- a wrong value there is an invalid query, not a weaker one.  
TWO GATES SCOPED, NOT SILENCED -- both now name the entity and the evidence:  
         validate.ps1 SexCode rule already exempted the multi-QIF fallback; it now also exempts  
            targetEntity='Other' and says WHICH reason applied.  
         verify_build's HARD "VehicleMakeCode MUST be FormSelect" rule exempts `Other` as an  
            [INFO], and the walk is now per-QIF so a hit knows its entity. Proven still failable:  
            planting FormInput on the VEHICLE tab of a replica still FAILs.  
⚠️ A CORRECTION MADE MID-BUILD, RECORDED BECAUSE IT WOULD HAVE SHIPPED: a first pass "fixed"  
         the WantedPersonQuery VehicleMakeCode attribute from Size 24 to Size 4, on the strength of a  
         single `maxLen= 4` row in docs/reference/..._METADATA_REFERENCE.txt. THE RAW XML REFUTES IT.  
         `VehicleMakeCode` appears 28 times with TWO caps and the size is PER TRANSACTION:  
             VehicleRegistrationQuery 4 . VehicleStolenQuery 4 . WantedPersonQuery 24  
         So 24 was right all along and the Vehicle QIDMs' 4 is right too. METADATA_REFERENCE  
         FLATTENS -- one row per (keyRef, primaryField) -- and cannot express that, which is exactly  
         why the Source Authority table makes the raw <Field>/<Requirements> the sanctioned read for  
         a size or mandatory question. Reverted to 24.  
⚠️ AND audit_metadata CHECK 5 NEVER LOOKS AT THIS FIELD. Proven by planting 24-vs-4 on an  
         IN-PROVIDER replica (a %TEMP% copy reports "Providers checked: 0" -- no source/ beside it --  
         and my first attempt did exactly that and proved nothing). CHECK 5 emits verdicts for  
         Name, OLN, State, hull, article and more, and none for VehicleMakeCode. Recorded, not  
         fixed here.  
GATES: validator 75 PASS / 0 FAIL / 0 WARN / 2 LIMITATION (P dropped 77->75: two SexCode/RaceCode  
         attribute checks no longer apply on this shape). Portfolio validator sweep: 0 providers  
         with a FAIL. pipeline COMPLETE.  

## v1.17 -- 2026-09-18 -- WANTED PERSON BACK TO ONE CONFIG ON ITS OWN TAB (entity `Other`) -- the v1.15 split shipped a query that never reached the wire

**CHANGED:** WantedPersonQuery is ONE QIDM config again, targetEntity `Other`, carrying all five QWA
            combinations (QWA.NCIC / QWA.OCA / QWA.P / QWA.VM / QWA.N) on a sixth tab of its own.  
            The v1.15/v1.16 two-config split across Person and Vehicle is GONE.  
         SIX forms, SIX DISTINCT entities, one each: Vehicle / Person / Wanted Person / Firearm  
            / Article / Boat. No entity is doubled, so no tab carries a checkbox it cannot  
            satisfy -- the greyed-checkbox problem that cost four versions on the Firearm host.  
         RACE, SEX and STATE are Sel with codeTypeProvider again. On the old two-QIF Firearm host  
            LIMITATION #28 broke reverse-lookup and all three had to be FormInputs or AP #1 would  
            have put the platform's internal numeric row id on the wire instead of the code.  
         OLN control added to the tab -- metadata QWA{Name} <Any> defines OperatorLicenseNumber,  
            and the move surfaced it as an unresolvable any[] reference. Adding the control keeps  
            the value; dropping it from any[] would have discarded what the officer typed.  
         Person and Vehicle lost exactly their wanted-person-only controls (Race, NCIC Number,  
            Case Number, SSN, FBI, Misc, both Expand codes, Related Hit, Vehicle's NCIC Image).  
            Left behind they would be DEAD CONTROLS and audit_wiring_closure would have failed.  
**REASON:** THE SPLIT SILENTLY DROPPED HALF THE QUERY. Two QIDM configs sharing one `query` both
         render a selectable checkbox and ONLY ONE DISPATCHES (LIMITATION #49). Measured on  
         usx-sc-sled 2026-09-18: 21 Person wanted-person fills all reported SENT, the wire  
         carried nine WantedPersonQuery rows and every one was VEHICLE-shaped, and three capture  
         passes over 134 dex-log rows ended "0/18 / NOTHING CAPTURED". Rob confirmed by hand --  
         NCIC Number alone on the Person tab: "it lits up  i hit send but it never shows in the  
         log". SHAREDQ_PROBE had "proven" the shape, but it only proved RENDERING; it never  
         submitted. Renaming one `query` is not available: it is transmitted as <MessageType>.  
         Rob's call from three costed options: its own tab on `Other`, accepting the loss of the  
         co-fire in exchange for certainty.  
TENANT-CONFIRMED THE SAME DAY: the driver ran T20-T52 on the Wanted Person tab, 33 submitted /  
         33 SENT, and the capture paired "WantedPersonQuery 33/33". A QIDM on entity `Other`  
         DISPATCHES -- previously unknown, and the reason this version was treated as a  
         hypothesis until the import rather than assumed.  
WIRE: unchanged per combination. The five QWA combinations carry the same attributes and  
         targetFields; only which FORM feeds them moved. QWA.P's LicensePlateStateCode now  
         sources from this tab's own RegistrationState instead of the Vehicle tab's.  

## v1.16 -- 2026-09-18 -- ONE CARD PER ENTITY -- Related Hit becomes a Y/N dropdown defaulted Y, and no label says "(optional)"

**CHANGED:** CARDS 7 -> 5, ONE PER ENTITY. v1.15's second Vehicle card ("WANTED PERSON -- SENT WITH
            THE PLATE OR VIN SEARCH ABOVE") and second Person card ("... sent with the driver  
            queries") are gone; their controls moved into the single card on each tab.  
            Vehicle  3 rows: plate+type+year / VIN+make+year+state / NCIC Image + Related Hit  
            Person   6 rows: OLN+State+Image / name x4 / DOB+Sex+Race / NCIC Number+Case Number  
                             / SSN+FBI+Misc / Expand Name+Expand DOB+Related Hit  
            Person row 1 follows the documented OLN+State+Image 6/3/3 top-row pattern  
            (BUILD_RULES 11). Every row still sums to 12.  
         RelatedHitSearchIndicator: 1-char FormInput -> FormSelect YES_NO_UNKNOWN|NCIC with  
            initialValue 'Y', i.e. the same control as NCIC Image. Metadata gives it Alphabetic  
            maxLen=1, the same shape as ImageIndicator. Added to combo defaults[] on all five QWA  
            combinations beside the existing ImageIndicator default.  
         LABELS: 10 parenthetical qualifiers removed across all five entities -- "(optional)" x8,  
            "(required)", "(with name)". 11 `# LABEL-OVERRIDE:` tags added so verify_build  
            CHECK 13 Rule 3 records them as accepted rather than warning every rebuild.  
            State keeps its routing hint as "State - leave blank for SC" (a dash, not brackets).  
         CARD TITLES: both co-fire announcements removed. Vehicle is "VEHICLE -- SEARCH BY PLATE,  
            OR BY VIN"; Person is "PERSON -- SEARCH BY OLN, BY NAME + DOB + SEX, BY NCIC NUMBER,  
            OR BY NAME + CASE NUMBER".  
**REASON:** Rob 2026-09-18: "on veh why is it 2 cards?  same with person card  i want to keep it one
         card if possible  and make related hit y by default and use the saem ncic image dropdown  
         remove the both queires sent on the card titles everywhere  nothign extra in ()".  
WHY THE SECOND CARDS WERE SAFE TO REMOVE: they separated nothing. The field pool is per ENTITY  
         (LIMITATION #26), so controls on two cards of one tab were already one pool -- which is  
         exactly WHY the co-fire works. Those cards existed only to ANNOUNCE it, and a card  
         boundary that separates nothing misleads. The co-fire is stated in test_commsys's  
         CO-FIRE SUMMARY, the test plan's coFire map and the officer-guide banner instead.  
WHY THE PREFILLS ARE SAFE, MEASURED NOT ASSUMED: neither ImageIndicator nor  
         RelatedHitSearchIndicator appears in any set[] or any condition anywhere in this  
         provider -- both are any[]-only on the five QWA combos -- so BUILD_RULES 24 does not  
         bite and neither can collapse a combination onto a plainer sibling.  
WHY defaults[] AND NOT JUST THE FORM: CAD ignores form initialValues, so a form-only flip would  
         leave every CAD-originated wanted-person query still sending nothing for Related Hit.  
WIRE: <RelatedHitSearchIndicator>Y</RelatedHitSearchIndicator> now goes out on the QWA paths.  
         Nothing else on the wire moved -- this is otherwise layout and labels.  
GATES: validator 77P/0F/0W/2LIM · enforce 43 PASS / 0 FAIL / 0 WARN · PHASE 1 CLEAN  
         (query trace 16 built / 0 missing, gate efficacy 13/13 killed, fuzz 8/8 caught)  
         audit_layout_flow 5 cards / 0 findings (was 7 cards / 1 finding).  

## v1.15 -- 2026-09-18 -- WANTED PERSON ROLLED ONTO PERSON *AND* VEHICLE -- one transaction, two entities, deliberate CO-FIRE

**CHANGED:** THE WANTED PERSON TAB IS GONE. WantedPersonQuery is now TWO QIDM configs sharing one
            `query`, so it co-fires with the searches already on each tab:  
              SC_SLED_WantedPersonQuery      targetEntity=Person   QWA.NCIC / QWA.OCA / QWA.N  
              SC_SLED_WantedPersonQuery_Veh  targetEntity=Vehicle  QWA.P / QWA.VM  
         CONTROLS MOVED, NOT DUPLICATED. Person gained a second card (NCIC Number, Case Number,  
            Race, SSN, FBI, Misc, both Expand codes, Related Hit); Vehicle gained NCIC Image and  
            Related Hit. Name / DOB / Sex / OLN / plate / VIN / make / state are NOT repeated --  
            the field pool is per ENTITY (LIMITATION #26), so the controls already on those tabs  
            feed the QWA combinations. THAT SHARING IS WHAT PRODUCES THE CO-FIRE.  
         QWA.P's LicensePlateStateCode attribute feeds from the Vehicle tab's existing  
            RegistrationState control instead of a second state box. Attribute name and  
            targetField are unchanged, so the wire still carries <LicensePlateStateCode>.  
         5 tabs, one QIF per entity: Vehicle / Person / Firearm / Article / Boat.  
         9 QIDMs, 17 combinations.  
**REASON:** Rob 2026-09-18: "the wanted person query will need to cofire with person queires and
         vehicle queires were appropriate. so no longer will the wanted person tab exist but we  
         will roll the wanted person query onto to each tab veh on veh and person on person  
         relative to the required and ioptional fields in the combinations."  
WHY TWO CONFIGS AND NOT ONE, and why the same `query`:  
         - a QIDM has ONE targetEntity and CHECKBOXES ARE KEYED BY ENTITY (measured,  
           CHECKBOX_PROBE), so a Vehicle-tab fill can never trigger a Person-entity query;  
         - the wire carries `query` as <MessageType> (read from a real capture), so inventing a  
           second query name would put that string on the wire and SC would reject it;  
         - `name` must differ or the second config is a SILENT OVERWRITE at import.  
         PROVEN BEFORE BUILT: providers\SHAREDQ_PROBE.json put one query on two entities with a  
         control QIDM beside each. Rob: "on person typing in personkey both checkboxes lit up  
         same with veh". The platform keys on (query, entity). Had it keyed on query alone, one  
         config would have died silently with every gate green.  
CO-FIRE IS NOW STATED IN ALL THREE PLACES Rob asked for, not left to be inferred:  
         - test_commsys.ps1 prints a CO-FIRE SUMMARY naming the transactions per entity  
           (Person 4, Vehicle 4 -- including the RMS query, which also rides along);  
         - the TEST PLAN carries a `coFire` map + note: a capture batch legitimately holds MORE  
           wire rows than tests, which is exactly what stranded 14 captures on 2026-09-17;  
         - the OFFICER GUIDE shows a banner per tab: "These 3 searches are sent together."  
TWO VALIDATOR FAILS ON THE FIRST BUILD, BOTH REAL, BOTH FIXED:  
         - LicensePlateStateCode pointed at an attributeTypeId='STATE' control with no  
           codeTypeProvider -> would have sent the internal numeric row id (AP #1). Now NCIC.  
         - raceCode arrived on Person still using the codeTypeCategory fallback from the old  
           two-QIF Wanted Person tab. Person carries the RMS Person QIDM whose race attribute is  
           useAttributeId=true, so that stores the code string where RMS expects the id (AP #11).  
           Now attributeTypeId='RACE' + codeTypeProvider='NIBRS', the portfolio standard.  
ONE SHARED-GATE FIX THIS EXPOSED: audit_devdoc_combinations recovered a query name by stripping  
         the provider prefix off the CONFIG NAME, so _Veh bucketed under a phantom query and  
         three built-and-firing combinations read as UNBUILT. It now reads the `query` PROPERTY  
         (the authority -- it is what the wire carries) and maps a combination's form-control  
         names through to their attribute/targetField, because the devdoc names WIRE fields  
         while combinations name FORM controls. Swept: 21 providers, 0 FAIL.  

## v1.14 -- 2026-09-18 -- The Boat tab still ADVERTISED Administrative Message -- a label outlived its card

**CHANGED:** ENTITY_Boat label 'Boat & Administrative Message' -> 'Boat', and its description
            rewritten to match. NOTHING ELSE. No QIDM, no control, no combination, no wire  
            change -- one caption and one description string.  
**REASON:** Rob, reading the imported v1.13 on usx-sc-sled: "last tab still says boat and admin
         message". v1.13 deleted the AM card from the Boat QIF and I did not change the label  
         with it, so the shipped build rendered a tab promising a form that was not there.  
WHY NO GATE CAUGHT IT, and this is the part worth keeping: a LABEL IS WIRED TO NOTHING. The  
         validator checks fieldIds and types, reachability checks routing, wiring closure checks  
         that controls reach the wire, layout flow checks card/row shape -- NONE of them compares  
         a tab caption to the cards underneath it. v1.13 passed 44 gates with a caption that  
         advertised a removed feature. The rule that follows: WHEN A CARD LEAVES A FORM, CHANGE  
         THE LABEL IN THE SAME EDIT; it is recorded in the build script beside the label itself.  
WHY A BUMP AND NOT A FIX TO v1.13: v1.13 was ALREADY IMPORTED to usx-sc-sled when this was  
         found. usx-build 6d -- an imported version is frozen, and a version number describing  
         two different forms is worse than no version, because the wire carries no version and  
         every log captured against it becomes unattributable.  

## v1.13 -- 2026-09-18 -- SIX TABS, ONE QIF PER ENTITY -- zero stray checkboxes, and AM is the price

**CHANGED:** ADMINISTRATIVE MESSAGE REMOVED. Its QIF and its QIDM are gone from the build; the
            attributes and combinations are KEPT in the script (with the adjudicated  
            devdoc-vs-metadata disagreement over DestinationCode) so restoring is 2 lines.  
            Registered in ACCEPTED_DIVERGENCES as devdoc-combo-unbuilt; SQVR marks it [SKIPPED].  
         WANTED PERSON moved to targetEntity='Other' -- the SIXTH entity, discovered in the  
            shipping client's own enum on 2026-09-18 and CONFIRMED LIVE the same day.  
         BOTH v1.12 MERGES UNDONE: Firearm is its own tab again (targetEntity back to Firearm),  
            Article is its own tab again, Boat is its own tab again. The v1.12 labels  
            "Article & Firearm" and "Boat & Administrative Message" are gone.  
         RESULT: 6 forms on 6 DISTINCT entities -- Vehicle / Person / Other(Wanted Person) /  
            Firearm / Article / Boat. 8 QIDMs, 17 combinations.  
         SexCode on the Wanted Person card stays on the canonical attributeTypeId='SEX' +  
            codeTypeProvider='NIBRS' pattern restored at v1.12.  
**REASON:** Rob 2026-09-18, on the rendered v1.11 form: "wanted person has a firearm button at the
         button that is greyed out ... that is not acceptable", then "boat has admin message on  
         it too and admin has boat on it", then the instruction that produced this shape:  
         "6 tabs  remove admin message and see what the cehckboxes look like".  
WHY ONE QIF PER ENTITY IS THE WHOLE FIX. Query checkboxes are keyed by ENTITY, not by form --  
         MEASURED with providers\CHECKBOX_PROBE.json on usx-sc-sled, where two forms sharing one  
         entity showed ALL FOUR of that entity's QIDMs on BOTH tabs. So any entity carrying two  
         forms strands a permanently-dead checkbox on each of them. With AM dropped there are  
         exactly 6 forms for the 6 available entity slots, so no tab can show another form's  
         query. The stray checkboxes are not merged away -- they are structurally impossible.  
EVERY REMOVAL LEVER WAS TESTED AND FAILED (2026-09-18, measured not argued):  
         enabled:false            -> NOT carried by the importer (checkbox still rendered)  
         order on the form        -> NOT carried (A=2 / B=1 still rendered A first)  
         a second provider bundle -> does NOT scope a tab (appeared on both)  
         autoSelect:false         -> renders anyway, merely unticked ("available but unchecked")  
         admin form<->interface   -> unlinking changed nothing  
         behaviors block          -> not referenced anywhere in the client  
         per-form query list      -> does not exist; the whole frontend bundle was read  
COST, STATED: AdministrativeMessage is devdoc-Basic SUPPORTED and is now unbuilt. That is a  
         USER-APPROVED SKIP, not an oversight. TO RESTORE: AM on targetEntity='Other' and  
         WantedPersonQuery back on 'Firearm' -- buys a 7th tab, costs two dead checkboxes on  
         the Firearm pair.  

## v1.12 -- 2026-09-18 -- First attempt at the greyed-checkbox fix -- SUPERSEDED BY v1.13 THE SAME DAY

**CHANGED:** Merged the Firearm card onto the Article QIF and the Administrative Message card onto
            the Boat QIF, giving 5 tabs on 5 entities. GunQuery targetEntity Firearm -> Article.  
            Restored Wanted Person's SexCode to attributeTypeId='SEX' + codeTypeProvider='NIBRS'  
            once LIMITATION #28 stopped applying (that part SURVIVES into v1.13).  
**REASON:** Same complaint as v1.13. This version removed the dead checkboxes by REDUCING the form
         count to the entity count -- correct, but it cost two tabs Rob wanted.  
WHY IT WAS SUPERSEDED: the sixth entity `Other` was not known when v1.12 was built. Finding it  
         meant the same cleanliness could be had while giving Firearm, Article and Boat their  
         own tabs back -- so only ONE form had to go instead of two being merged.  

## v1.11 -- 2026-09-17 -- THE AM MESSAGE IS A MULTI-LINE BOX -- FormTextarea, and it is LIVE-PROVEN

**CHANGED:** ADMINISTRATIVE MESSAGE -- FreeText control `Inp` -> `Txa`, i.e. resolvedName
            'FormInput' -> 'FormTextarea'. fieldId, label and maxLength='501' all UNCHANGED, so  
            the wire contract and every QIDM reference are untouched. Emitted in all 3 layout  
            variants (default / CAD_DISPATCH / FIRST_RESPONDER).  
         NEW SHARED HELPER `Txa` in tools/_build_layout_helpers.ps1 (exports line updated).  
         THREE GATES TAUGHT THE NEW TYPE: validate.ps1 (fieldId-presence check),  
            audit_cross_provider.ps1 (field-type consistency) and audit_cad.ps1 (x2) all  
            whitelisted control types BY NAME and would have SKIPPED a FormTextarea silently.  
**REASON:** Rob 2026-09-17: "so you now need to make message multiline". The AM carries a
         501-character free-text message to another agency in what was a ONE-LINE box.  
WHY THIS IS NOW BUILDABLE AT ALL -- PLATFORM_CONSTRAINTS CAPABILITY #48. That slot held a  
         LIMITATION reading "THERE IS NO MULTI-LINE / TEXTAREA FORM CONTROL", backed by four  
         sources. It was FALSE, and it was retired the same day by importing a throwaway probe  
         (tools/build_multiline_test.ps1) to this provider's own tenant. Three of the four  
         sources were USAGE CENSUSES -- 0 uses means UNTESTED, never IMPOSSIBLE.  
⚠️ THE NAME IS LOWERCASE-'a' `FormTextarea`. `FormTextArea` renders NOTHING (exact-match  
         resolver) -- which is why this went in as a HELPER rather than a hand-written node:  
         the failure is one keystroke wide and completely silent.  
⚠️ THIS BUYS WRAP-AND-SCROLL, NOT LINE BREAKS, and the label deliberately does not promise them.  
         MEASURED on the round-2 wire test (docs/evidence/2026-09-17_MULTILINE_TEST_round2_*):  
         the control TRANSMITS (3/3 captures), but neither Enter nor Shift+Enter inserts a  
         newline -- BOTH SUBMIT THE FORM -- and a PASTED newline becomes ~124 spaces before it  
         even reaches form state, so three five-letter words cost 262 of the 501 characters.  
         The officer cannot make a break by typing, which is the only reason the budget is safe.  
⚠️ OPEN, AND IT IS A POSSIBLE REGRESSION: maxLength enforcement is UNMEASURED on this control.  
         It is honoured on FormInput and relied on portfolio-wide. The probe tenant was restored  
         to v1.10 before this could be tested, so measure it on the v1.11 import -- paste MORE  
         than 501 characters into the message box and see whether it truncates.  
⚠️ NOT FIXED HERE AND BIGGER THAN THE BOX: pressing Enter SENDS THE AM. On a query that wastes a  
         transaction; on an AM it TRANSMITS A HALF-WRITTEN MESSAGE to the ORI it is addressed to.  
         Standard HTML form behaviour, so it applies to the single-line FormInput too and is NOT  
         a regression introduced here -- no config prop to suppress it appears across 7,414  
         control nodes, so it is a PRODUCT ask. This is the thing to raise about the AM.  
NOT TENANT-TESTED: SC_SLED has never been swept, so no test package was archived by this bump.  

## v1.10 -- 2026-09-17 -- SEX AND RACE ARE DROPDOWNS AGAIN -- the v1.3 "capability given up" was HALF WRONG

**CHANGED:** WANTED -- SexCode Inp -> Sel codeTypeCategory='NIBRS_SEX' + codeTypeSource='NIBRS',
            label 'Sex -- type M, F or U (optional)' -> 'Sex'.  
            raceCode Inp -> Sel NIBRS_RACE + NIBRS, label -> 'Race'.  
            LicensePlateStateCode Inp -> Sel NJ_NIBRS_STATE + NJ_NIBRS, label -> 'State'  
            (**HYPOTHESIS** -- see below; the other two are not).  
            Plate-row widths 3/3/3/3 -> 4/2/3/3 (State's label shrank, VIN displays narrower).  
         VEHICLE -- row 2 widths 5/3/2/2 -> 3/3/2/4: VIN displays narrower and State gets the  
            width, so its label stops being squished. VIN maxLength untouched at 20 (metadata size);  
            only the COLUMN it displays in shrank.  
         VALIDATOR 77P/0F/2W/2LIM -> 77P/0F/0W/2LIM. The two WARNs are GONE because the defect  
            they described was FIXED, not because anything was silenced.  
         REGISTRY -- the SCOPED raceCode and SexCode rows are DELETED; only RegistrationState  
            remains. 8 rows -> 6.  
**REASON:**  Rob 2026-09-17: "on vin  shorten teh field length that displays  the helper for stae is
         getting squished  on wanted person plate state should be state and use the drop down  sex  
         should just say sex and race should just say race".  

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
