# AZ_AZDPS -- Changelog

Auto-generated from `AZ_AZDPS_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v3.7** | Generated: 2026-08-10

---

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

