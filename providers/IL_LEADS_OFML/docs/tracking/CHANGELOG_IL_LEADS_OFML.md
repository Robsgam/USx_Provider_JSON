# IL_LEADS_OFML -- Changelog

Auto-generated from `IL_LEADS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.2** | Generated: 2026-08-07

---

## v2.2 -- 2026-08-07 -- Cosmetic pass -- Rob's direct review of the rendered v2.1 form (label/order ONLY)

**CHANGED:** Four items, all officer-facing, ZERO wire/routing/QIDM/combo change.
  (1) Vehicle VIN: 'VIN (Plate wins if both entered)' -> 'Vehicle Identification Number'.  
      Helper removed AND the label spelled out. NOTE the portfolio is SPLIT on this label --  
      measured 2026-08-07: 10 providers say 'VIN' (AZ, CA_CLETS_OCATS, CA_SAN_LUIS_OBISPO,  
      CA_VENTURA_COUNTY, CA_eSUN, FL, NY, OR, TX, TX_CCH) and 9 say 'Vehicle Identification  
      Number' (CA_CLETS, CA_CONTRA_COSTA, HI, LA, MD, NJ, NM, OH, TN). It was NEVER made  
      universal, so this is a choice on a split field, not conformance to a convention. Rob  
      asked whether it had been universalized; it had not, and the split is recorded here and  
      in the build script so it is not re-derived.  
  (2) Person: name fields reordered FIRST-then-LAST on the form (was Last then First).  
      Matches NY v4.8, which made the same reorder on all three of its Person cards.  
  (3) Person: 'Last Name (OLN wins if both entered)' -> bare 'Last Name'.  
  (4) Boat: 'Registration Number (Hull ID wins if both entered)' -> bare 'Registration Number'.  
**REASON:** Rob's own rendered-form review of v2.1 in the USx tenant -- the manual gate no tool
  replaces. Every removed string was an identifier-priority HINT; not one guardrail was touched.  
THE DISTINCTION THAT MAKES THIS SAFE, stated because conflating the two would be a real defect:  
  * ROUTING is unchanged. Z2.V still carries 'LicensePlateNumber NOT_EXISTS' (plate beats VIN),  
    Z2.N still carries 'OperatorLicenseNumber NOT_EXISTS' (OLN beats Name), BQ.R still carries  
    'BoatHullIdNumber NOT_EXISTS' (hull beats reg number). Only the on-screen hints are gone.  
  * The Person NAME WIRE FORMAT is unchanged. The composite 'Name' attribute keeps  
    sourceField = @('NameLast','NameFirst') + FormatStringRuleHandler ', ', which is what emits  
    the authoritative ConnectCIC "LAST, FIRST" (FIELD_REFERENCE Section 7). Form control order  
    and QIDM sourceField order are INDEPENDENT; only the former moved. Swapping the sourceField  
    array would silently invert every IL name search, so it was deliberately left alone.  
WHY A VERSION BUMP FOR A LABEL PASS: v2.1 was ALREADY IMPORTED into  
  usx-il-leads-ofml.mark43.com -- proven, not assumed, by the tenant picklist capture, whose  
  rendered labels came back 'NCIC Image', 'Stolen Check', 'Make' and  
  'State (leave blank for IL)' (all v2.1-only strings). An imported version is frozen: editing  
  v2.1 in place would leave one version number describing two different forms, and the wire XML  
  carries no version, so every log captured against it becomes unattributable (the AZ v3.5  
  lesson). Re-import is required before the sweep.  
TENANT PICKLISTS: captured against v2.1 and still valid -- this pass changes no dropdown, no  
  codeTypeCategory and no codeTypeSource. Vehicle still owes a re-scope from the v2.1 capture  
  (3 of 5 fields came back 'field not found in DOM' because the Firearm form was rendered while  
  Vehicle was selected); that is unaffected by this bump.  
SCRIPT : scripts/build_il_leads_ofml.ps1  
OUTPUT : IL_LEADS_OFML_v2.2.json  

## v2.1 -- 2026-08-07 -- DEX-1284 convention pass + card collapse (layout/label only, NO wire change)

**CHANGED:** Brought IL from the pre-DEX-1284 methodology in line with HI/FL/NY/TX/CA/AZ.
  (1) CARD COLLAPSE -- the separate shared "OPTIONS" card is the RETIRED pre-DEX-1284 layout.  
      Vehicle 3 cards -> 1 (was OPTIONS + PLATE SEARCH + VIN SEARCH), Person 3 -> 1  
      (was OPTIONS + OLN SEARCH + NAME SEARCH), Boat 3 -> 1 (was OPTIONS + HULL + REG).  
      Firearm and Article were already 1 card. 11 cards -> 5.  
  (2) CANONICAL LABELS -- OperatorLicenseNumber 'License Number' -> 'OLN'; all four  
      ImageIndicator controls ('Image (optional)' x3, 'Image' x1) -> exactly 'NCIC Image';  
      relatedHitSearchIndicator 'Related Hit Search (Y for NCIC stolen check)' x4 ->  
      bare 'Stolen Check'.  
  (3) CARD TITLES ALL-CAPS AND CARRYING THE QUERY PATHS -- e.g. 'VEHICLE SEARCH BY PLATE,  
      "OR" VIN', 'DRIVER LICENSE SEARCH BY OLN, "OR" NAME'. CARD_VEH_PLATE previously had  
      NO title at all.  
  (4) LEAN LABELS -- stripped '(optional)' helpers from any[] qualifiers (Plate Type, Plate  
      Year, Make, Year, Caliber, Sex, Race, Owner Applied Number) with LABEL-OVERRIDE tags  
      recording each. State KEEPS its mandatory routing hint 'leave blank for IL'  
      (CHECK 15 Rule 1). Identifier-priority hints kept on the losing identifier  
      ('VIN (Plate wins if both entered)', 'Registration Number (Hull ID wins if both  
      entered)', 'Last Name (OLN wins if both entered)').  
  (5) UNIFORM GRID -- every card on a 4/4/4 grid (Person top row 6/3/3 per the BUILD_RULES  
      Section 11 PERSON CARDS pattern: identifier keeps the width, State/Image are short  
      codes). Removed the lone-[4] rows ROW_VEH_OPT_2 / ROW_PER_OPT_2 and the 12-col  
      single-field rows that made each path card a stranded full-width box.  
**REASON:** DEX-1284 portfolio convention pass, applied on IL's revisit turn (the conventions are
  explicitly per-provider-on-revisit, not a retroactive sweep). IL was the last GALV provider  
  still on the 3-card OPTIONS+path layout. Approved by Rob 2026-08-07 (full HI-style collapse  
  over labels-only). ZERO QIDM/combo/routing/fieldId/default change -- every fieldId still  
  appears exactly once per QIF, so there is no duplicate-fieldId (ISE) risk from the collapse.  
NOT CHANGED, and deliberately so -- each verified against THIS provider's own authorities:  
  - Article devdoc combination #2 (OwnerAppliedNumber, ArticleTypeCode) stays UNBUILT. IL  
    metadata defines exactly ONE ArticleSingleQuery combination, QA{ArticleSerialNumber} with  
    Set[ArticleSerialNumber, ArticleTypeCode, Any[OwnerAppliedNumber]]. ArticleSerialNumber is  
    mandatory on every Article query; there is no OwnerAppliedNumber-keyed variant. Metadata is  
    FIELD authority, so building #2 would emit a request no variant accepts. Already registered  
    2026-08-02 (rule devdoc-combo-unbuilt). Re-derived independently this pass and reached the  
    same conclusion.  
  - Boat State2-State5 stay UNBUILT (no multi-state mechanism on the platform; same standing  
    ruling HI_HCJDC_OFML applies to its DL/VehicleReg State2-5). Already registered 2026-08-02.  
  - RegistrationState stays in Boat any[], NOT set[]. The devdoc field table marks State 'M',  
    but metadata BQ{hull} and BQ{RegistrationNumber} both place State inside <Set><Any> --  
    optional. Metadata wins; promoting it would make an in-state hull search impossible (the  
    TN_TIES KQ.N defect class).  
  - attributeTypeId=SEX + codeTypeProvider=NIBRS retained (the documented dual-consumer pattern  
    that satisfies CommSys and RMS simultaneously, FIELD_REFERENCE Section 3).  
SCRIPT : scripts/build_il_leads_ofml.ps1  
OUTPUT : IL_LEADS_OFML_v2.1.json  

## v2.0 -- 2026-08-01 -- v1.1 -> v2.0 methodology galvanization (commit 876200b0)

**CHANGED:** Galvanized to the single-JSON model: canonical build_il_leads_ofml.ps1, native PascalCase
  USx CAD fieldIds, versioned root filename. Dropped the State initialValue=IL.  
**REASON:** A State default breaks the new in/out routing (LIMITATION #30) -- the prefill makes State
  always-present and permanently hides every combo needing its absence, so the hint moved to the  
  label ("leave blank for IL"). Enforce-clean, NOT live-tested. Recovered 2026-08-03 from commit  
  876200b0; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v1.0 -- 2026-05-07 -- MC multi-card layout


## v1.0 -- 2026-05-06 -- /07  Initial standup -- 5 basic queries, 9 combos


## v1.1 -- 2026-05-11 -- LIMITATION elimination pass

