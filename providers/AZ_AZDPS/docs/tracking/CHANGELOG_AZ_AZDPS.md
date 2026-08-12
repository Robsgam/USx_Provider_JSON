# AZ_AZDPS -- Changelog

Auto-generated from `AZ_AZDPS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.10** | Generated: 2026-08-12

---

## v3.10 -- 2026-08-12 -- Cosmetic/layout pass -- 12 layout findings -> 0, AND a hidden State field fixed

WIRE UNCHANGED, PROVEN NOT ASSERTED: all three bundles' QIDM sets are BYTE-IDENTICAL to v3.9  
  (hash-compared). Every change below is form/label only.  
LAYOUT (Rob: "fix all 12 and bring az to the standard layout"), each traced to its rule:  
  - SSN + Race moved to their OWN row. NEITHER appears in any CommSys combination -- both feed  
    only the RMS person search -- yet SSN sat beside OLN, giving the most prominent slot on the  
    Person card to a field that does not query the state.  
  - 'MI' -> 'Middle Name' on nameMiddle and NameMiddleDH: both are maxLen=20, i.e. full middle  
    names. 'MI' means middle INITIAL. FL keeps 'MI' only because its field is maxLen=1.  
  - First BEFORE Last, all four name parts on one row (DL and DH). Wire unaffected: the composite  
    Name attribute keeps its own sourceField order, which is what emits ConnectCIC LAST-first.  
  - NCIC Image and Firearm Serial off their 12-wide rows; a 2-option dropdown cannot use 12 cols.  
  - Hidden badge rows moved to the BOTTOM on Firearm and Article (they were row 2, splitting the  
    serial from make/model/caliber).  
  - DH DOB + Sex given their own row: both mandatory in KQH set[], previously behind two optionals.  
  - Row widths tiled to 12 on every multi-field row.  
THE REAL DEFECT, and it was not cosmetic -- RegistrationStateDH IS NOW VISIBLE.  
  Rob 2026-08-12: "i don't think we should ever hide a state fiedl  why was this done?"  
  He was right and BOTH authorities agree:  
    DEVDOC (query authority), DriverHistoryQuery inside "Basic Queries Supported" (line 97):  
      1. (In/Out) OperatorLicenseNumber, State, [Attention, PurposeCode]  
      2. (In/Out) BirthDate, Name, SexCode, State, [Attention, PurposeCode]  
      Both (In/Out); State UNBRACKETED = required and officer-supplied.  
    METADATA (field authority), raw <Requirements> per <Combination>: both KQ variants put  
      <Field reference="State"/> directly inside <Set>. Mandatory. No <Choice>, no nested <Set>.  
      There is NO separate out-of-state transaction and no in/out keyRef fork, so State is ALWAYS  
      sent and its VALUE selects the destination.  
    CLINCHER, same provider: DriverLicenseQuery's devdoc splits (In) combos #1-#5 (no State at  
      all) from (Out) #6-#8 (State present). AZ's devdoc DOES distinguish in/out where that is the  
      design -- and for DH it deliberately does not.  
  CONSEQUENCE OF THE OLD STATE: hidden SelH pinned to 'AZ' made OUT-OF-STATE DRIVER HISTORY  
    UNREACHABLE -- the (Out) half of both documented combinations was dead. The wire was never  
    wrong; the FORM prevented the officer from using it.  
  WHY IT WAS EVER HIDDEN, from this file at v1.1 (2026-04-20), the FIRST build:  
    "DH hidden state: InpH fieldId='StateDH', initialValue='AZ' (mandatory in KQ/KQH set[])"  
    i.e. "mandatory, so guarantee presence by prefilling and hiding". Same wrong move as the  
    ImageIndicator case (usx-build 6b) -- except here it buys nothing and costs a capability. It  
    then SURVIVED because CLAUDE.md wrote it up as a feature ("RegistrationStateDH hidden SelH"):  
    a record became its own justification.  
  initialValue='AZ' KEPT and safe under BUILD_RULES 24 -- no AZ combination needs State ABSENT and  
    there is no NOT_EXISTS gate on it (verified, 0 occurrences), so the prefill cannot shadow one  
    path over another. In-state stays one-click; the officer changes it for out-of-state.  
    Row shape [6 3 3] (OLN | State | Purpose Code) matches FL/NY's DH row 1 exactly.  
GATE FIXED IN THE SAME PASS, because the gate should have caught this: verify_build CHECK 6's  
  hidden-field whitelist led with a BARE SUBSTRING pattern '(?i)state', written for the narrow RMS  
  dual-field case but approving ANY fieldId containing 'state' -- so it printed "documented  
  exception, allowed" on this defect for four months. Pattern REMOVED. Measured first: with it gone,  
  ZERO of 20 providers raise a new WARN, so it protected nothing. LAW 2 proven with a self-checked  
  probe (mutation confirmed in the parsed object first): re-hiding the field now yields  
  "[WARN] Hidden field RegistrationStateDH not on approved-exception list".  
PORTFOLIO SWEEP: AZ was the ONLY provider hiding a real State field. All 20 checked; the remaining  
  hits are dexStateUserId, which is the badge field and legitimately hidden.  
STATE CONVENTION ADOPTED (Rob 2026-08-12: "we want consistency  make the change").  
  MEASURED FIRST, and the measurement REVERSED my assumption: 17 of 20 providers label State  
  'State (leave blank for <ST>)' with NO initialValue. Only AZ, NJ and TX used bare 'State' + a  
  home default, so the portfolio standard is the OTHER one -- I had been calling AZ's form the norm.  
  Label and default are COUPLED: "leave blank for AZ" is only true if blank really means AZ.  
  APPLIED:  
    Vehicle    'State (leave blank for AZ)', default DROPPED  (State is any[]-only on ACVR/ACVRV)  
    Person DL  'State (leave blank for AZ)', default DROPPED  (any[]-only on ACWL/DQN/DQ)  
    Boat       'State (leave blank for AZ)', already no default -- UNCHANGED  
    Person DH  'State (required)', default DROPPED -- see below  
  DH IS THE ONE EXCEPTION AND IT IS PRINCIPLED: State is set[]-MANDATORY on both KQ combos, so  
    blank means the query CANNOT FIRE and "leave blank for AZ" would be a lie. FL_FCIC is the only  
    other provider with a mandatory DH State and it uses exactly 'State (required)' with no  
    default -- adopted verbatim so the two agree rather than inventing a third spelling.  
  WIRE DELTA, STATED PLAINLY: in-state Vehicle/DL queries no longer auto-send <State>AZ</State>.  
    Metadata places State in <Any> on those variants, so both forms are valid, and it is what the  
    other 17 providers already do. Verified safe: audit_prefill_shadow 18 ordered pairs 0 FAIL,  
    query trace 0 prefill-dead / 0 shadow, requirement fidelity 15 branches 0 under / 0 over.  
  A CAD CONCERN I RAISED AND ROB CLOSED -- recorded so nobody chases it again: I flagged that no  
    combo carries a defaults[] entry for State and CAD ignores form initialValue, so a  
    CAD-originated DH could not satisfy its mandatory State. Rob 2026-08-12: "driver history is not  
    currently supported from cad." So there is NO CAD path to DH and the gap is moot. NOT a defect,  
    NOT owed. Do not re-raise it, and do not add a State combo default to DH to "fix" it.  
ROB'S SECOND LAYOUT ROUND (2026-08-12) + THREE QUESTIONS ANSWERED FROM THE AUTHORITIES.  
  LAYOUT applied: Vehicle -- State moved onto the plate row, widths tightened [6 3 3]->[3 3 3 3]  
    and the VIN row [6 3 3]->[5 4 3] (FL's exact Vehicle rows); ROW_VEH_3 retired.  
    Firearm -- Stolen Check moved to row 1 beside Serial at [8 4]; ROW_GUN_3 retired.  
    Article -- Type + Serial + Stolen Check all on row 1 at [4 5 3]; ROW_ART_2 retired.  
    Boat -- no layout change requested; unchanged. Card rows 26 -> 21.  
  *** Q1 AND Q3 BELOW WERE ANSWERED, THEN Q3 WAS OVERTURNED BY ROB THE SAME DAY. READ THE  
  CORRECTION AT THE END OF THIS BLOCK -- the "blank is right" answer for Stolen Check was WRONG. ***  
  Q1 "can or should we use a default for ncic image?" -- NO, AND THE BLANK IS LOAD-BEARING.  
    ImageIndicator is set[]-MANDATORY on DQPN and DQP (the two licence-PHOTO paths) while both  
    Requestor and dexStateUserId are hidden AND prefilled, i.e. always present. Give ImageIndicator  
    a default and DQPN's VARIABLE requirement collapses to [NameLast, NameFirst] -- IDENTICAL to  
    DQN's set[] -- and DQPN is ordered ahead of DQN, so DQN (the plain name search) dies. That is  
    BUILD_RULES 24, the class that killed 35 combos across 6 providers. Blank is what keeps the  
    photo path OPT-IN: officer selects Y/N -> DQPN/DQP; leaves it alone -> ACWL/DQN/DQ.  
    NOTE the portfolio rule needs this caveat: CLAUDE.md's "ImageIndicator needs initialValue"  
    holds where the field is any[]-only (FL/NY/HI). On AZ it is a set[] DISCRIMINATOR, so the  
    generic rule would break routing here.  
  Q2 "on dh state required is blank. is it required for in state? if not the label is wrong."  
    IT IS REQUIRED FOR IN-STATE TOO, so 'State (required)' is CORRECT. RegistrationStateDH sits in  
    set[] on BOTH KQ combinations and there is no in-state variant that omits it -- metadata defines  
    ONE DriverHistoryQuery transaction with no in/out fork, so State is always sent and its VALUE  
    picks the destination. An in-state DH therefore needs an explicit AZ selection.  
    OPEN, ROB'S CALL: we could instead default it to AZ and label it bare 'State' (safe -- no combo  
    needs State absent, 0 NOT_EXISTS gates), which buys one-click in-state at the cost of diverging  
    from FL, the only other provider with a mandatory DH State. Not done unilaterally.  
  Q3 "firearm stolen check blank? same question as state on dh?" -- NO, DIFFERENT CASE, and blank is  
    right. relatedHitSearchIndicator is any[] OPTIONAL on ACQG / ACQA / all four Boat combos. It is  
    genuinely optional, so it needs no default and must NOT read "required". Same answer for  
    Article and Boat. The distinction that matters: ImageIndicator and StateDH are set[] (mandatory,  
    and blank has consequences); Stolen Check is any[] (blank simply means not asked).  
  VERIFIED after the moves: layout flow 0 findings, prefill-shadow 18 pairs 0 FAIL, combo  
    reachability 13 checked ALL reachable, validator 68P/0F/0W.  

## v3.9 -- 2026-08-10 -- DEX-1284 label conformance -- ONE label, measured not assumed

**CHANGED:** 'NCIC Image (select Y to request a licence photo)' -> 'NCIC Image'. Nothing else.
WHY ONLY ONE: rather than apply a remembered checklist, the conventions were MEASURED across the  
  seven tenant-complete providers first. AZ already conformed on all of them except this label:  
    OLN label exactly 'OLN'          -- 8 of 9 providers; AZ already correct  
    'Stolen Check' bare              -- canonical on FL/HI/IL/NY/TX; AZ already correct  
    zero '(optional)' label suffixes -- AZ already at 0  
    ALL-CAPS card titles carrying the query paths -- AZ already correct (6 cards, 6 path titles)  
  So the honest scope was one label, not a sweep. The helper it carried is exactly what the  
  lean-label convention strips: the CARD TITLE carries the query paths, and verify_build CHECK 15  
  accepts the bare form via $canonicalBareLabels, so no LABEL-OVERRIDE tag is needed for it.  
NOT CHANGED, deliberately: 'State (leave blank for AZ)' and 'State (DH)' keep their routing hints  
  (the convention explicitly exempts State -- the hint tells the officer which combo fires), and  
  'Attention (auto)' / 'Badge (auto)' / 'Requestor (auto)' sit on HIDDEN controls no officer sees.  
GATES: validator 68 PASS / 0 FAIL / 0 WARN, verify 17 PASS / 0 WARN / 0 FAIL.  
COST: none. AZ is NEVER-TESTED and NOT imported, so the bump archived 0 logs.  

## v3.8 -- 2026-08-10 -- DEX-1283 Attention 'X' + four Vehicle over-permits


## v3.8 -- 2026-08-10 -- DEX-1283: remove the Attention 'X' -- AZ was NOT exempt, and I said it was

**CHANGED:** Three sites, one field, identical to the HI_HCJDC_OFML v4.15 fix earlier today.
  (1) The hidden DH feeder InpH 'attention' loses initialValue='X'.  
  (2) KQH combo defaults[] loses Attention='X' (State='AZ' KEPT).  
  (3) KQ combo defaults[] likewise.  
  UNCHANGED: the control itself, 'attention' in KQH/KQ any[], and the Attention attribute's  
  CommsysGetLastNameFirstNameInitialRuleHandler. Only the literal value went.  
  NOT TOUCHED: Requestor='X' on DQPN/DQP. That is a DIFFERENT field, devdoc-mandated on the two  
  photo paths, and automated on Rob's explicit "requester needs to be automated" instruction  
  (see v3.5). DEX-1283 item 2 is about Attention. Whether 'X' is the right feeder value for  
  Requestor is a separate question and is NOT being answered here.  
WHY THIS ENTRY EXISTS AT ALL -- I DECLARED AZ DONE WITH THIS DEFECT IN IT.  
  Earlier today I audited AZ, found PHASE 1 structurally clean, fixed the supported-query  
  extract, ran enforce to 40 PASS / 0 AZ-scoped FAIL, and committed it (98676c95) as complete.  
  The Attention 'X' was sitting in the build script the whole time, three sites, in exactly the  
  shape I had removed from HI_HCJDC_OFML that same morning and written a Jira release line about.  
  It surfaced only when OH_LEADS's random fuzz threw `prefill-field @ Attention_DH_Input` and  
  SURVIVED -- because the field was ALREADY prefilled, so the mutation was a no-op. Chasing that  
  into a portfolio sweep showed EIGHT providers still carrying it, AZ among them.  
THE ROOT CAUSE IS STRUCTURAL, NOT JUST INATTENTION. The DEX-1283 retrofit is tracked by  
  CONVENTION -- CLAUDE.md says such passes are "applied to each provider on its revisit turn,  
  not a retroactive sweep" -- and NO GATE CHECKS IT. So on a provider's revisit turn the only  
  thing standing between the defect and another green board is whether the person remembers.  
  PHASE 1 has seven steps and none of them asks this question; enforce has ~10 phases and none  
  asks either. A convention with no gate is a to-do list that only fires when someone recalls it,  
  which is the same failure mode as the BUILD_NOTES stub problem and the SQVR mirror problem.  
  Recorded here rather than fixed here: building that gate is a shared-tool change and belongs  
  in its own pass, not inside an AZ-only rebuild.  
SAFE TO REMOVE, on evidence and not on symmetry: the same handler with the field in any[], no  
  initialValue and no default, resolves the officer name on 47 of 47 committed Driver-History  
  wires -- FL_FCIC 7/7, TX_TLETS 13/13, CA_CLETS 7/7, NY_NYSPIN_EJUSTICE 11/11 (DH-OOS) and  
  HI_HCJDC_OFML 9/9 captured today at v4.15. AZ has never been tenant-tested, so this provider's  
  own wire proof is owed at its first sweep; the mechanism is not in doubt.  
COST: none. AZ is NEVER-TESTED and NOT imported (IMPORT_LEDGER section A: installed = none), so  
  the version bump archived 0 logs and reset 0 SQVR markers. There was no reason to hesitate.  
ARTIFACT-VERIFIED, not script-verified: emitted v3.8 has 0 "field": "Attention" defaults, no  
  initialValue anywhere near the attention control, and still carries the handler and the  
  Attention targetField.  

## v3.7 -- 2026-08-05 -- / scope-gate pass 2026-08-10 (BadgeNumber wired + discriminators un-prefilled)


## v3.7 -- 2026-08-05 -- BadgeNumber WIRED (it never was) + the four prefill shadows removed

**CHANGED:**
  (1) BadgeNumber now carries rule=CommsysGetDexStateUserIdRuleHandler arguments=['true'] at ALL FIVE  
      attribute sites, plus a hidden feeder initialValue='X' per entity and a combo defaults[] entry  
      on every badge-carrying combo (12 of them, applied by a loop -- see (5)). size stays 4 per AZ  
      metadata, so a 6-char DEX id truncates BY DESIGN (Rob's call).  
  (2) ImageIndicator prefill REMOVED -- it is the DL photo discriminator.  
  (3) Boat RegistrationState prefill REMOVED + in/out gates added: ACQB/ACQBH get State NOT_EXISTS  
      (badge/NCIC in-state), BQ/BQH get State EXISTS (Nlets out-of-state). State also removed from  
      ACQB/ACQBH any[] -- gate-XOR-companion, verify_build CHECK 14: a NOT_EXISTS-gated field in the  
      same combo's any[] is dead config.  
  (4) purposeCode -> purposeCodeDH carried over from v3.6; Stolen Check remains Y/N FormSelect.  
  (5) The badge defaults are applied by a LOOP over combos carrying dexStateUserId, not by hand.  
WHY (1) -- THE DEFECT WAS A COMMENT THAT LIED FOR FOUR VERSIONS. The build script header has asserted  
  since v3.x that "BadgeNumber: hidden field auto-populated via dexStateUserId  
  (CommsysGetDexStateUserIdRuleHandler)" while the attribute carried NO rule in any of the five  
  places. So dexStateUserId was EMPTY at submit and the NINE combos requiring it in set[] could never  
  match. AZ is the ONLY provider in the portfolio that puts the badge in a set[]. Proven by the v3.6  
  wire: the DQP log carried only <State>AZ</State><OperatorLicenseNumber>D999888777</...> -- no  
  <BadgeNumber>, no <ImageIndicator>, no <Requestor> -- so DQ fired, not DQP, and 7 of 16 Person logs  
  FAILED. The platform DID know the id: <UserName>MK43RS</UserName> in the same log, resolved by the  
  same handler in the AUTH config. BadgeNumber was simply reading a form field nothing filled.  
WHY (2) AND (3) -- MY OWN FIX CREATED FOUR DEAD COMBOS AND I ALMOST SHIPPED THAT AS A TRADE-OFF.  
  Prefilling ImageIndicator, Requestor and dexStateUserId (three set[] fields in ONE version) is a  
  straight BUILD_RULES 24 violation -- and 24 is the rule I had CITED myself earlier the same day  
  before reversing under 20b and never re-applying it to the two new prefills. Consequence, exactly  
  as 24 documents: the VARIABLE requirement (set[] minus prefilled) collapsed --  
      DQPN  -> [NameLast, NameFirst]        IDENTICAL to DQN's  
      DQP   -> [OperatorLicenseNumber]      IDENTICAL to DQ's  
      ACQB  -> [RegistrationNumber]         IDENTICAL to BQ's  
      ACQBH -> [BoatHullIdNumber]           IDENTICAL to BQH's  
  Four EXACT collisions, and no ordering can separate identical sets, so DQN/DQ/BQ/BQH went DEAD.  
  audit_combo_reachability caught it immediately and correctly; I read a DEAD verdict as a cost to  
  accept and put up three options that ALL sacrificed queries. Rob: "we do not leave out queries  
  because it is hard. we had these combos worked out before so keep thinking. these options are not  
  acceptable. use ordering and recognize the shadows." The answer was to un-prefill the discriminators  
  that metadata already supplied -- ImageIndicator for the DL pairs, RegistrationState for the Boat  
  in/out pairs. RESULT: 13 of 13 combinations reachable, nothing deleted, nothing registered.  
NEW GATE, so this cannot recur silently: tools/audit_prefill_shadow.ps1 (enforce PHASE 2v, BLOCKING).  
  2h says a combo is DEAD; 2v says WHICH PREFILL KILLED IT. It fires only when the shadow does NOT  
  exist on the raw set[]s -- i.e. only when our prefill created it -- which is what spares a prefill  
  sitting in EVERY combo's set[] (CA_CLETS purposeCode; AZ's own dexStateUserId, which is REQUIRED).  
  Baseline 20/20 clean, 645 ordered pairs; proven to FAIL by re-injecting the ImageIndicator prefill.  
ALL 5 ENTITIES RESET at v3.7. Requires a tenant RE-IMPORT: v3.6 is installed and its Person logs are  
  archived as evidence of a mispredicting plan.  
STILL A HYPOTHESIS until a wire shows it: the registry documents  
  CommsysGetDexStateUserIdRuleHandler only for an AUTHENTICATION attribute. On a QUERY attribute it is  
  undocumented. If it is ignored, the feeder still fires the combo but sends 'X' instead of the  
  officer id -- which looks identical on a green board. READ <BadgeNumber> ON A VEHICLE LOG: ACVR  
  requires badge+plate and has no non-badge sibling, so it is the discriminating test.  

## v3.6 -- 2026-08-04 -- automated Requestor + ACWL ordered first + Y/N Stolen Check


## v3.6 -- 2026-08-04 -- Requestor AUTOMATED, ACWL ordered FIRST, Stolen Check -> Y/N dropdown

WHY A BUMP AND NOT A v3.5 EDIT: v3.5 had ALREADY BEEN IMPORTED to the USx AZ tenant when these three  
changes landed, so the tenant's form and the repo's JSON had silently diverged under one version  
number -- the tenant still showed a VISIBLE Requestor and FREE-TEXT Stolen Check. Rob caught it  
("its still at 3.5"). A version number that describes two different forms is worse than no version:  
every log captured against it is unattributable. Bumped so the re-import is unambiguous.  
**CHANGED:**
  (1) REQUESTOR IS AUTOMATED (Rob, non-negotiable). Hidden InpH feeder (initialValue='X') +  
      CommsysGetLastNameFirstNameInitialRuleHandler on the QIDM attribute, size=5 cap -- the Attention  
      pattern this build already used. Officers must not type an identifier they can get wrong.  
  (2) ACWL ORDERED FIRST ("Option A", Rob's choice of three). Requestor and ImageIndicator are BOTH  
      always-present (handler + a prefill that is mandatory or the field does not serialize at all),  
      so DQPN's VARIABLE requirement is only badge+Name -- a strict subset of ACWL's  
      badge+Name+DOB+Sex. With DQPN first, ACWL is a DEAD combo (measured twice). ACWL first is what  
      BOTH ordering rules already prescribed: most-specific-first (4 variable fields vs 2) and the  
      devdoc tiebreaker (#1 precedes the #2 photo variant). ORDER: ACWL, DQPN, DQP, DQN, DQ.  
      Behaviour to know: badge+Name+DOB+Sex fires ACWL (no photo); badge+Name fires DQPN (photo).  
  (3) STOLEN CHECK IS NOW Y/N. All three controls (Firearm/Article/Boat) were FormInput maxLength 1 --  
      FREE TEXT on a Y/N field, so any character could be typed. Now FormSelect YES_NO_UNKNOWN/NCIC.  
      NO initialValue added: the field is any[]-only and a default would start transmitting Y on every  
      query, a wire change nobody asked for. verify_build hard-gates VehicleMakeCode-must-be-Sel but  
      nothing covers Y/N indicators, which is how three shipped as free text.  
  (4) CAD defaults ImageIndicator=Y + Requestor=X on DQPN/DQP -- CAD ignores form initialValues and  
      both are set[] members, so without them a CAD-injected query cannot satisfy the combo.  
NOT CHANGED, and deliberately so: RelatedHitSearchIndicator keeps its name (AZ's OWN -- 50 hits in  
  source/AZ_AZDPS.xml, listed verbatim in the devdoc; AZ orders it Hit-then-Search where HI/NJ use  
  Search-then-Hit, each per its own metadata). Boat hull combos keep RegistrationNumber in any[] --  
  the queries are already exclusive via the hull NOT_EXISTS gate, and both authorities permit the  
  field on the hull path (audit_optional_scope adjudicated FIX when I removed it).  
ALL 5 ENTITIES RESET at v3.6. Requires a tenant RE-IMPORT before Person or stolen-check testing.  

## v3.5 -- 2026-08-04 -- DL SCOPE CORRECTION -- the devdoc-Basic DriverLicenseQuery, photo paths restored


## v3.5 -- 2026-08-04 -- DL built on the WRONG TRANSACTION since v3.3 -- switched to devdoc-Basic DriverLicenseQuery

**CHANGED:** (1) DL transaction AzAzdpsDriverLicenseQuery -> DriverLicenseQuery. AZ's metadata defines
  BOTH as separate transactions with DIFFERENT <Requirements>; only the unprefixed one is in the  
  devdoc "Basic Queries Supported" list. (2) ADDED the two photo paths that transaction alone  
  supports -- DQPN (devdoc #2, by Name) and DQP (devdoc #5, by OLN), both implementing metadata  
  DQP, with new ImageIndicator + Requestor controls. (3) LOOSENED the name search to DQN =  
  Set[Name] per Basic DQ{Name}: name alone is now sufficient. (4) DELETED DQSS -- an SSN search the  
  Basic devdoc does not list. (5) STRIPPED the over-permits from DQ{OLN} any[] (BirthDate, SexCode,  
  BadgeNumber -- metadata defines only Any[State]). (6) DH queriesToDeselect re-pointed at the new  
  query name; an entry naming a query that no longer exists is silently INERT.  
**REASON:** THREE OFFICER-VISIBLE CAPABILITIES WERE MISSING, not a naming nicety.
  * NO DRIVER-LICENCE PHOTO EXISTED AT ALL. Metadata DQP is defined ONLY under the Basic  
    transaction, so devdoc #2 and #5 were unreachable: `Requestor` appeared ZERO times in the  
    emitted JSON and the single `ImageIndicator` hit was a QRDM *response* mapping, not a control.  
    The devdoc documents the field explicitly ("Y - Request Driver License Photo").  
  * A NAME-ONLY DL SEARCH WAS IMPOSSIBLE. Devdoc #3 is "Name, [SexCode]" and Basic DQ{Name} is  
    Set[Name] Any[BirthDate, SexCode, State]; the prefixed sibling's DQ{Name} = Set[Name, SexCode,  
    BirthDate] made DOB *and* sex mandatory. An officer holding just a name got nothing.  
  * AN UNAUTHORIZED SSN SEARCH WAS BEING OFFERED (DQSS).  
HOW IT SURVIVED: audit_supported_queries compared each combo's queryLabel against a hand-maintained  
  extract and never the transaction name. 'Driver License' is legitimately on that list, so every  
  combo scored [PASS] -- including "[PASS] combo DQSS: 'Driver License | SocialSecurityNumber' is  
  devdoc-supported", a flatly false statement. Three layers had to align: the label comparison, the  
  extract's PROVISIONAL status (which downgraded mismatches to INFO), and a '$'-anchored devdoc  
  parser. Closed by that tool's CHECK 0 (2026-08-04), which gates on the devdoc itself and blocked  
  this build until fixed. The v3.4 build script had FLAGGED the inversion in its own header comment  
  as an open question for Rob -- so it was known and recorded, just never gated.  
ONE REGISTRY ROW WAS NOT A DIVERGENCE BUT A BUG: 'ACWL | Name | devdoc-optional-unreachable' argued  
  "metadata makes SexCode MANDATORY on every name variant ... there is NO looser one". True of the  
  prefixed sibling, FALSE of the Basic transaction, whose DQ{Name} is exactly that looser variant.  
  Retired. A registration whose premise is scoped to the wrong transaction silences a real defect.  
ORDERING: DQPN, DQP, ACWL, DQN, DQ. DQ{OLN} set[] is a STRICT SUBSET of DQP{OLN} set[], so DQP must  
  precede DQ or the photo path is dead on arrival; DQN set[] is a subset of both ACWL and DQPN.  
  OLN>Name guardrail kept (SSN dropped from the cascade), gate-xor-companion (CHECK 14) preserved.  
ImageIndicator and Requestor carry NO initialValue: both are in DQP set[], i.e. ROUTING fields, and  
  a prefill would make DQP always-match and shadow every plainer DL search (BUILD_RULES 24).  
  RegistrationState keeps initialValue='AZ' -- it is any[]-only here, so it routes nothing.  
The SSN control STAYS: consumed by the RMS person QIDM (firstNameLastNameSocialSecurityNumber,  
  -KeepSsn), which audit_wiring_closure counts as reaching the wire. Dropped from the card TITLE  
  though -- it is no longer a CommSys DL path, and advertising it as one would be a lie on the form.  
FINAL DESIGN (Rob's calls, 2026-08-04, after the first cut was wrong twice):  
  * REQUESTOR IS AUTOMATED -- NON-NEGOTIABLE (Rob). Hidden InpH feeder (initialValue='X') +  
    CommsysGetLastNameFirstNameInitialRuleHandler on the QIDM attribute, size=5 cap: the Attention  
    pattern this build already uses. I twice reverted this instead of solving it, which was me  
    overriding a decision that was not mine to make.  
  * ORDER IS WHAT MAKES IT SAFE -- "OPTION A", Rob's choice. Requestor and ImageIndicator are BOTH  
    always-present (handler + mandatory prefill), so DQPN's VARIABLE requirement is only badge+Name  
    -- a strict subset of ACWL's badge+Name+DOB+Sex. With DQPN first, ACWL is a DEAD combo (measured:  
    `[FAIL] DEAD COMBO: DriverLicenseQuery/ACWL`). ACWL is therefore ordered FIRST. That is what both  
    ordering rules already prescribed and I had simply got wrong: most-specific-first (4 variable  
    fields vs 2), and the devdoc tiebreaker (item #1 precedes the #2 photo variant).  
    FINAL ORDER: ACWL, DQPN, DQP, DQN, DQ -- 13 combinations, ALL REACHABLE.  
    Consequence to know: a full-descriptor badge+Name+DOB+Sex search fires ACWL and gets NO photo;  
    badge+Name alone fires DQPN and does. The rejected alternatives were deleting ACWL (always-photo,  
    TX's ruling) and a gate-only "Request Photo" control (no precedent, unverified).  
  * STOLEN CHECK IS NOW Y/N (Rob). All three controls (Firearm/Article/Boat) were FormInput  
    maxLength 1 -- free text, so an officer could type any character into a Y/N field. Now FormSelect  
    YES_NO_UNKNOWN/NCIC. NO initialValue added: the field is any[]-only and adding a default would  
    start transmitting Y on every query, a wire change nobody asked for.  
    NAME PROVENANCE (Rob asked): `RelatedHitSearchIndicator` is AZ's OWN -- 50 occurrences in  
    source/AZ_AZDPS.xml and the devdoc field table lists it verbatim. Note AZ orders it Hit-then-  
    Search while HI/NJ use `relatedSearchHitIndicator` (Search-then-Hit); each matches its own  
    metadata. Nothing invented. Form fieldId stays camelCase (not one of the 22 CAD tokens).  
  * CAD defaults added for ImageIndicator=Y and Requestor=X on DQPN/DQP -- CAD ignores form  
    initialValues, and both are set[] members, so without them a CAD-injected query cannot satisfy  
    the combo at all.  
REJECTED, WITH EVIDENCE: removing RegistrationNumber from the Boat HULL combos' any[] to make "reg or  
  hull fire not both". The queries are ALREADY exclusive -- ACQB/BQ are gated BoatHullIdNumber  
  NOT_EXISTS, so only the hull combo fires. audit_devdoc_optionals raised 4 dropped-optional FAILs and  
  audit_optional_scope adjudicated FIX (put it back): AZ's devdoc brackets [RegistrationNumber] on the  
  hull item and metadata ACQB{Hull} carries it in <Any>. This is the NJ/HI split -- HI strips the  
  loser, NJ and AZ carry it, each per its OWN devdoc. v3.4's notes record making this exact mistake  
  at v3.1 and reversing it; I repeated it. Identifier priority is about ROUTING, never about deleting  
  a permitted field from the payload.  
KNOWN GATE GAPS (not AZ defects -- AZ's build is correct in both cases): fuzz survivors  
  `over-permit SexCode @ DQP` (that variant defines no <Any> at all, yet no gate reacts) and  
  `drop-any RegistrationNumber @ Boat hull`. Both are missing gate coverage, deliberately not chased  
  inside an AZ-only pass. `select-to-input @ raceCode` is a CORRECT survivor (RMS-only, no set[]).  
ALL 5 ENTITIES RESET at v3.5 (block by version). No re-sweep cost: AZ has never been tenant-tested.  

## v3.4 -- 2026-08-01 -- One real wire fix, six registrations, one gate defect (commit 50e4268c)

**CHANGED:** One real wire fix plus six accepted-divergence registrations; a gate defect found in the
  same pass was corrected. AZ reached ENFORCED (0 FAIL / 0 WARN) as the 9th green provider.  
**REASON:** See commit 50e4268c for the per-finding adjudication. Recovered 2026-08-03 -- this entry
  read "Rebuilt via pipeline.ps1 / Scheduled rebuild", hiding a wire change behind a no-op.  

## v3.3 -- 2026-07-28 -- SCOPE CORRECTION -- build only devdoc "Basic Queries Supported" (direct Rob directive)

**CHANGED:** Removed WMPIWantedPersonInquiry + WMPIMissingPersonInquiry -- they are NOT in the AZ
  devdoc "Basic Queries Supported" section (which is exactly 6: Article/Boat/DH/DL/Gun/VehReg);  
  they live in a separate "Wanted Missing Person Inquiries (WMP-I)" section. Both QIDMs deleted +  
  dropped from the provider bundle; the Person WANTED/MISSING card removed -> Person is now 2 cards  
  (DRIVER LICENSE + DRIVER HISTORY), matching the portfolio. raceCode (the only WMPI-card field the  
  RMS person search still needs: race <- raceCode) RELOCATED to the DL card (bare "Race"). Other  
  WMPI-only fields (NCICNumber, ExpandedName/BirthDate, Age/Height/Weight/Eye/Hair/AreaCode/FormORI,  
  Person relatedHitSearchIndicator) removed with the card. Clears the 18 audit_metadata WARNs (they  
  were the metadata-vs-Basic delta for the out-of-scope WMPI paths).  
**REASON:** Rob -- "stick to basic supported queries section only." I had (wrongly) proposed BUILDING
  the unbuilt WMPI paths to clear the WARNs -- the inverse of the devdoc-authority rule (devdoc Basic  
  list = build scope; metadata is field-authority, not a build checklist). Query-set change (removes  
  2 non-Basic queries); the 6 retained queries' wire is unchanged. ALL 5 ENTITIES RESET at v3.3.  

## v3.2 -- 2026-07-28 -- DEX-1284 convention pass (direct Rob feedback, layout/label-only, NO functional change)

**CHANGED:** Brought AZ from the pre-DEX-1284 methodology in line with FL/NJ/HI/NY/TX/CA.
  STRUCTURE: Vehicle 3 cards -> 1; Boat 3 cards -> 1; Person 7 cards -> 3 (DRIVER LICENSE / DRIVER  
    HISTORY / WANTED-MISSING). Hidden badge (dexStateUserId), RegistrationStateDH SelH, Attention  
    feeder all folded onto the consuming card, preserved exactly.  
  CA-LESSON CHECK: verified from the QIDM set[]/any[] that BOTH WMPI queries source the DL card's  
    shared Name/DOB/Sex -> DL name kept VISIBLE (no orphan); Wanted/Missing name search reads it  
    from the DL card (shared-name design, unchanged wire).  
  LABELS: OLN (was "License Number (DL)/(DH)"); "Related Hit (Y)" -> "Stolen Check"; stripped all  
    "(optional)"/"(DH)" helpers -> bare + LABEL-OVERRIDE; State "(default AZ...)" -> bare "State"  
    (initialValue=AZ kept); enumerated card titles; M.I. -> MI.  
**REASON:** Rob -- "move to arizona, use all lessons learned." Layout/label-only, no combo/QIDM/routing/
  fieldId/default/wire change. AZ has no ImageIndicator (NCIC Image N/A). ALL 5 ENTITIES RESET at  
  v3.2. NOT yet USx-tenant-tested.  

## v3.1 -- 2026-07-24 -- Identifier-priority guardrails hardened (demotion-only -> existence-gate)

**CHANGED:** Added existence-only EXISTS/NOT_EXISTS conditions to the CommSys combos.
  - Vehicle Plate>VIN: ACVRV -> LicensePlateNumber NOT_EXISTS (VIN dropped from ACVR any[])  
  - DL OLN>SSN>Name: DQSS -> OLN NOT_EXISTS; ACWL/DQN -> OLN + SSN NOT_EXISTS  
    (Name/SSN dropped from DQ any[]; Name dropped from DQSS any[])  
  - DH OLN>Name: KQH -> OperatorLicenseNumberDH NOT_EXISTS (DH-suffix pool)  
  - Boat Hull>Reg: ACQB/BQ -> BoatHullIdNumber NOT_EXISTS (Hull dropped from their any[])  
  - WMPI NCIC>Name: ACQW/ACQM -> NCICNumber NOT_EXISTS (NCIC dropped from their any[])  
  - Badge combos ACWL/ACQB/ACQBH -> dexStateUserId EXISTS (metadata-faithful badge gate;  
    stops them shadowing the no-badge DQN/BQ/BQH fallbacks -- verify_build CHECK 16)  
**REASON:** v3.0 had ZERO conditions -- "priority" was demotion-only, which does NOT create mutual
  exclusivity (LIMITATION #1: any[] fields still union into the serialized pool). v3.0 over-sent  
  on every multi-identifier input (plate query also serialized VIN, DL name also OLN+SSN, DH name  
  also OLN, boat reg also Hull, WMPI name also NCIC). v3.1 adopts the proven CA_VENTURA/CA_eSUN  
  existence-gate pattern. Guardrail-hardening only -- query set / keyRefs / DH-suffix / badge  
  feeder / Attention handler / -KeepSsn all unchanged. No State gates (AZ has no in/out keyRef  
  split). ACCEPTED_DIVERGENCES corrected (removed the false "serializes ONLY the intended  
  identifier" claim). NOT yet live-tested at v3.1.  

## v3.0 -- 2026-07-22 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.3 -- 2026-05-14 -- LIMITATION elimination pass

