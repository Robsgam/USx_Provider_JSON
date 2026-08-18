# OH_LEADS -- Changelog

Auto-generated from `OH_LEADS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.5** | Generated: 2026-08-18

---

## v2.5 -- 2026-08-18 -- NCIC Image defaults to Y on ALL entities -- the Rob-held flag closed at zero cost

**CHANGED:** ImageIndicator flipped 'N' -> 'Y' on Article and Boat, in BOTH places the rule requires --
  the form initialValue (ROW_ART_3, ROW_BOA_2) and the combo defaults[] CAD twin on all four  
  carrying combos (Article QA.S/QA.N, Boat QB.H/QB.R). Person was already 'Y'. Emitted JSON now  
  reads 9 of 9 form controls at 'Y' and 5 of 5 combo defaults at 'Y'.  
**REASON:** [FLAG:ncic-image-default-y-everywhere] -- Rob 2026-08-12, "ncic image should default to y
  everywhere". THE DEFAULTS[] TWIN IS NOT OPTIONAL: CAD ignores the form initialValue, so a  
  form-only flip would leave every CAD-originated Article/Boat query still sending 'N'.  

## v2.4 -- 2026-08-10 -- CARD COLLAPSE 14 -> 6 + ImageQuery BUILT (the two items v2.3 left open)

Both were flagged at v2.3 as "Rob's call". His call was: do them. So they are done, in one version.  

## v2.3 -- 2026-08-10 -- DEX-1283 Attention 'X' + DEX-1284 label conformance (OH was the portfolio outlier)

**CHANGED**, all officer-facing or wire-value; ZERO QIDM / combo / routing / fieldId change:
  (1) DEX-1283: the hidden DH feeder loses initialValue='X' and BOTH KQ.N/KQ.O combo defaults[]  
      lose Attention='X'. Control, 'attention' in any[], and the  
      CommsysGetLastNameFirstNameInitialRuleHandler attribute are untouched -- only the literal.  
  (2) 'License Number' -> 'OLN' on BOTH the DL and DH controls. OH was the ONLY provider of nine  
      not using the canonical label (8 of 9 already did).  
  (3) THREE different image labels -- 'Image (optional)', 'Image (in-state blank, optional)',  
      'Image (out-of-state OLN, optional)' -> 'NCIC Image' on all three. Canonical on the six  
      providers that carry the field; OH had three spellings of one field.  
  (4) THREE stolen-check labels -- 'Y for NCIC stolen-gun/article/boat check (optional)' ->  
      'Stolen Check'. Canonical on FL/HI/IL/NY/TX.  
  (5) '(optional)' suffixes stripped from County Code, Purpose Code, Make, Caliber. OH went 18  
      helper labels -> 8; the leanest finished providers (CA/IL/NY) sit at 0 '(optional)'.  
  (6) FOUR '# LABEL-OVERRIDE:' tags added.  
WHY (6) IS PART OF (4)/(5) AND NOT AN AFTERTHOUGHT. Stripping the helpers produced FOUR FRESH  
  verify_build CHECK 15 WARNs (AddressCounty, firearmMake, gunCaliber, relatedHitSearchIndicator  
  -- "any[]-only label has no routing qualifier"). The label and its override tag are ONE change:  
  IL_LEADS_OFML carries 16 such tags, which is exactly how it holds 0 '(optional)' at 0 WARN. I  
  found this by measuring how IL avoids the WARN rather than by adding '(optional)' back, which  
  would have undone the lean pass to satisfy a gate. All four are now [INFO] with a cited reason.  
THE STANDARD WAS MEASURED, NOT REMEMBERED. Across the seven tenant-complete providers:  
  OLN exactly 'OLN' = 8/9 · 'NCIC Image' = 6/6 that have the field · 'Stolen Check' = 5/5 that  
  have it. Those three are settled, so OH was brought to them. **'(optional)' is NOT settled** --  
  CA/IL/NY are at 0 but NJ 18, HI 12, FL 3, TX 3, so that pass is still rolling out and OH moving  
  to 0 puts it ahead of four finished providers rather than "into line" with all of them. Stating  
  that instead of implying uniformity.  
FLAG CLEARED: [FLAG:validate-imgind-20b-l30] asked for exactly "rebuild to re-record scores" and  
  the rebuild did it -- validator records 78 PASS / 0 FAIL / 0 WARN where STATUS.txt had been stuck  
  at 77P since the 08-07 validate.ps1 change. Nothing in the build needed altering for it: State is  
  already in set[] on the OOS combos (LIMITATION #30 satisfied) and OH gates NO combo on  
  ImageIndicator NOT_EXISTS, which is the defect 20b actually names. **The flag did NOT self-clear  
  on rebuild** -- CLAUDE.md claims the build script clears it; OH's has no such logic. Cleared by  
  hand; do not rely on the auto-clear.  
STILL OWED AND NOT DONE HERE -- TWO ITEMS, both stated rather than buried:  
  (a) CARD COLLAPSE. OH has 14 cards and ZERO titles carrying a query path. Every other provider  
      has 5-6 cards with 5-6 path-carrying titles (NJ 3 of 5). Vehicle alone is SIX cards  
      (OPTIONS/PLATE/DEALER PLATE/VIN/NAME/SSN) where IL/HI/FL collapsed theirs to one. This is  
      the IL v2.1 pass and it is a genuine layout redesign, not a label edit -- which paths share  
      a card and what each title says is a design decision that Rob's rendered-form review owns.  
      The 6 remaining helper labels ('Date of Birth (out-of-state)', 'Sex (out-of-state)',  
      'Serial Number (with Article Type)', 'Dealer Plate Type (with Plate Number + Type)',  
      'Vehicle Make/Year (with State, optional)') are COUPLED to it: they say WHICH combo needs  
      the field, which is precisely what a path-carrying card title absorbs. Strip them before the  
      titles exist and the form gets less usable, not more.  
  (b) ImageQuery IS DEVDOC-BASIC AND IS NOT BUILT. audit_supported_queries CHECK 0 reports it as  
      "devdoc-Basic but NOT BUILT -- each must be a documented skip", and it is documented nowhere.  
      It is BUILDABLE, not blocked: OH metadata defines ImageQuery (v9, 1 combination) and the  
      devdoc gives "(In/Out) OperatorLicenseNumber, [ReasonCode, Requestor, UserName]" -- every one  
      of those fields already exists on OH's DL card. So this is a real coverage gap under  
      no-combo-left-behind, and the choice between BUILD IT and a user-approved skip is Rob's, not  
      mine. Not silently skipped and not silently built.  
GATES: validator 78 PASS / 0 FAIL / 0 WARN, verify CLEAN (4 label overrides accepted as INFO).  
COST: none. OH is NEVER-TESTED and NOT imported, so the bump archived 0 logs / 0 SQVR markers.  

## v2.3-superseded -- 2026-08-10 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.2 -- 2026-08-01 -- RQ.P State promoted to set[] (portfolio fidelity sweep, commit c3b76a94)

**CHANGED:** RQ.P -- State PROMOTED into set[] to match metadata RQ{LicensePlateNumber}.
**REASON:** Found by the portfolio fidelity sweep (413 branches / 29 UNDER / 49 OVER across 20
  providers, while the six tenant-verified providers were 0/0). An UNDER-REQUIRED set[] is the  
  severe class: the query can fire WITHOUT the field and the request is invalid, and neither 6c nor  
  2i can see it -- a missing requirement is invisible to content and attribution checks. Recovered  
  2026-08-03 from commit c3b76a94; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.1 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + PlateType/PlateYear defaults


## v1.0 -- 2026-05-06 -- Initial build -- 6 basic queries, 23 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

