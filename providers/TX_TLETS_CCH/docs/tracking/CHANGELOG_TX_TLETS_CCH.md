# TX_TLETS_CCH -- Changelog

Auto-generated from `TX_TLETS_CCH_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.18** | Generated: 2026-08-27

---

## v1.18 -- 2026-08-27 -- LOCKSTEP with TX_TLETS v4.22 -- QV plate RESTORED, State promoted to set[]

                 (WIRE CHANGE)  
**CHANGED:** Added QVLicensePlateNumber to TX_TLETS_CCH_VehicleInsuranceRegistrationQuery --
  set[LicensePlateNumber, RegistrationState], any[regionId], state='In', ordered LAST of the 6.  
  VehReg 5 -> 6 combos. BASE-SYNC marker v4.21 -> v4.22.  
**REASON:** Mandatory variant rebuild. CCH carried the IDENTICAL defect as the base and lost QV plate
  in the SAME v4.17 / v1.13 lockstep commit, so from then until now a plate+State fill matched NO  
  combination here either: RQ{Plate} wants Year+Type, REG{Plate} wants Year+FRT, and nothing had a  
  plate-only set[]. The devdoc's "(InState) LicensePlateNumber, State [RegionId]" path did not  
  exist in this variant at all.  
  State is PROMOTED any[] -> set[] per Rob 2026-08-27 ("make state a set and the qv of plate  
  number only will shadow properly") and per the devdoc, which marks State REQUIRED where the  
  metadata marks it optional. The promotion is what makes the restore safe: set[Plate,State]  
  cannot match a bare plate, so this QV is GATED and cannot ungate-shadow RQ/REG the way the v4.9  
  version did; ordered LAST so the more specific combos still win first-match.  
  Vehicle RegistrationState (ROW_VEH_1) carries NO initialValue -- VERIFIED before promoting it.  
  Do not add one: a prefill there silently degrades this combo to plate-only and the old shadow  
  returns.  
  QV{VIN} DELIBERATELY STAYS OUT -- RQ{VIN} is already set[VIN], so the VIN input path exists.  
  ALSO CORRECTED: the QIDM description string had been claiming "all 7 metadata combos ...  
  (RQ/REG/QV plate + VIN/QV/RQ VIN + DPSI) ... lockstep w/ TX_TLETS v4.14" while only FIVE combos  
  were actually built -- stale since v1.13, and the same class of documentation drift that let the  
  base defect hide for four versions. Rewritten to match what is built.  
  FULL RATIONALE, including how the regression was introduced and why no gate caught it:  
  TX_TLETS BUILD_NOTES v4.22.  
  NOTE: TX_TLETS_CCH tenant testing remains PARKED (Rob 2026-08-21, proof-of-concept for the  
  base<->variant parallel build; no tenant need yet), so this is a build-and-document change --  
  no sweep is owed for the variant.  

## v1.17 -- 2026-08-18 -- LOCKSTEP with TX_TLETS v4.21 -- layout convergence, NO wire change

**CHANGED:** Mandatory variant rebuild (BASE-SYNC marker v4.20 -> v4.21). The same three
  audit_layout_flow fixes the base took, applied to the shared base-6 half:  
    (1)+(2) L7 LABEL-CAPACITY -- 'nameMiddle' and 'nameMiddleDH' were labelled 'MI', which means  
      middle INITIAL, on maxLen=30 controls that accept a full middle name. Now 'Middle Name' with a  
      LABEL-OVERRIDE comment, matching AZ_AZDPS v3.10 and HI_HCJDC_OFML v4.20.  
    (3) L3 HIDDEN-MID-CARD -- the hidden Attention gate-feeder row (ROW_PER_DHA) was row 1 of  
      CARD_PER_DH, ABOVE all visible content, while this provider's OWN DL card already places its  
      hidden EmailAddress feeder last. Moved to the last row. Row position carries no wire meaning --  
      the handler is fed by any[] membership, not by ordering.  
    (4) NOT CHANGED, recorded as a LAYOUT-OVERRIDE at ROW_PER_L1: L2 SET-BELOW-ANY reports optional  
      'messageKey' above mandatory 'NameLast' for CPLName. DEX-1283 #4 (Rob-approved) asked for  
      "OLN pairs with CPL/DWI/RDL on the top line", and OLN on that row IS mandatory for DQOLN.  
**REASON:** Base+variant are ONE logical provider kept in lockstep (CLAUDE.md "Provider Variants") -- any
  change to the base's shared half must propagate in the same pass, and audit_variant_sync gates the  
  BASE-SYNC marker. Confirms PASS: "TX_TLETS_CCH -- base-6 in lockstep with TX_TLETS v4.21".  
NO WIRE CHANGE. Labels and row order only. Verified: validator 112P/0F/0W unchanged; combination  
  requirements BYTE-IDENTICAL to v1.16 (proven by diffing every combo's sorted set[]/any[] across the  
  two emitted JSONs -- 41 vs 41, no difference), which is what establishes that the CCH transactions  
  were untouched; devdoc combinations 40 compared / 0 unbuilt; requirement fidelity 36 branches with  
  4 OVER-PERMITTED that are PRE-EXISTING, not introduced here (same byte-identical-requirements proof).  
STILL NEVER TENANT-TESTED. TX_TLETS_CCH is on no tenant and has 0 logs at any version, so nothing was  
  archived and nothing re-runs. It carries the last live [FLAG:nameparts-untested-unfrozen] in the  
  portfolio (HI/TX/NY all retired on wire evidence); retire it only once its own Person logs exist.  
THIS ENTRY WAS A STUB UNTIL THE 2026-08-18 LOOSE-END SWEEP. The base got a full v4.21 BUILD_NOTES the  
  same day and the variant got pipeline's "Scheduled rebuild" default -- caught by  
  audit_buildnotes_fidelity, which compares the entry against the actual JSON diff. Worth naming: a  
  lockstep rebuild is exactly where a variant's records get forgotten, because attention is on the base.  

## v1.16 -- 2026-08-14 -- Lockstep w/ TX_TLETS v4.20: NCIC Image defaults to 'Y' on Firearm/Article/Boat

**CHANGED:** identical to the base. ImageIndicator initialValue 'N' -> 'Y' on Firearm (ROW_GUN_2),
  Article (ROW_ART_2) and Boat (ROW_BOA_2), plus the combo defaults[] twin on all 10 carrying  
  base-6 combinations. BASE-SYNC marker bumped TX_TLETS v4.19 -> v4.20.  
*** CORRECTION TO MY OWN FIRST DRAFT OF THIS ENTRY, which said "the 8 CCH transactions carry no  
  ImageIndicator field and are untouched." THAT IS FALSE. QWI carries a CCH-suffixed  
  `imageIndicatorCCH` on 3 combinations (QWI.DOB, QWI.MISC, QWI.SSN), it HAS a real  
  officer-fillable form control (3 emitted, one per layout variant), and it has NO initialValue and  
  NO combo defaults[] entry -- i.e. it is exactly the blank-image-indicator state this flag exists  
  to correct, on a field the flag's wording never contemplated.  
  DELIBERATELY NOT FLIPPED IN THIS PASS, recorded rather than silently skipped: it is a CCH field on  
  a CCH transaction, Rob's rule was scoped to the base-6 NCIC Image control, and CCH is its own  
  adjudication (CCH response QRDM is explicitly out of scope repo-wide). OWED: decide at CCH's own  
  next turn whether `imageIndicatorCCH` should default to 'Y' + gain a defaults[] twin. Cost is  
  near-zero -- TX_TLETS_CCH has never been tenant-tested, so there is no package to archive.  
  HOW I NEARLY MISSED IT, worth the line: my probe searched the raw JSON for  
  `"fieldId":"imageIndicatorCCH"` and found ZERO, which read as an orphan attribute -- but the  
  emitted JSON is PRETTY-PRINTED, so the real text is `"fieldId": "imageIndicatorCCH"` WITH A SPACE.  
  audit_wiring_closure was right (0 orphans) and I was about to report it wrong. Validate the probe  
  before believing a finding that contradicts a gate. ***  
**REASON:** base<->variant LOCKSTEP is mandatory (CLAUDE.md "Provider Variants"): a variant inherits the
  base's QIDMs, so any base change must propagate in the SAME pass or audit_variant_sync flags the  
  drift. Rob 2026-08-12, "ncic image should default to y everywhere". Both halves of the default  
  required because CAD ignores form initialValue.  
WIRE CHANGE, same as the base -- ImageIndicator is in any[] on all 10 combos so the value is  
  transmitted. NO RE-SWEEP OWED: TX_TLETS_CCH has never been USx-tenant-tested (0 logs at any  
  version), so there is no test package to archive. The base owes the 92-log re-sweep.  
T6 GATE: CCH shares TX's devdoc, whose "Must be filled if ImageIndicator = Y" conditional (lines  
  129-130, EmailAddress + ReasonCode) belongs to DriverHistoryQuery -- Person, already 'Y', both  
  fields auto-populated by hidden gate-feeders. Firearm/Article/Boat carry no conditional. Clear.  
MEASURED SAFE: ImageIndicator in 0 set[]s and 0 conditions; no collision in the build script (every  
  'N' site was ImageIndicator's); RelatedHitSearchIndicator still 'Y' afterwards.  

## v1.15 -- 2026-08-06 -- Lockstep w/ TX_TLETS v4.19 (DEX-1283): removed unneeded X default

**CHANGED:** BASE-SYNC marker bumped TX_TLETS v4.18 -> v4.19. Removed initialValue='X' from the
  Attention (DH) and EmailAddress (DL+DH) hidden gate-feeders, and the matching combo  
  defaults[] entries ($imgDefs EmailAddress; $imgDefsDH Attention + EmailAddress) -- identical  
  fix as TX_TLETS v4.19, same day. sourceField stays non-empty and both fields stay in their  
  combos' any[]. Also added this build script's missing PENDING_UPDATES.txt auto-clear (TX_TLETS  
  had it; CCH never did) at the migrated docs/tracking/ path. CCH-only transactions  
  (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) untouched -- neither field is CCH-specific.  
**REASON:** See TX_TLETS v4.19 BUILD_NOTES + knowledge-base/RULE_HANDLERS.txt handler #13 for the
  full DEX-1283 evidence trail (92/92 TX_TLETS captures resolved the real officer  
  Attention/EmailAddress values with nothing in the source field at all).  

## v1.14 -- 2026-07-30 -- Devdoc optionals x routing: dropped optionals wired (commit b95bc364)

**CHANGED:** Devdoc-listed optionals the officer could fill but that were transmitted nowhere were
  added to the any[] of the combos whose metadata variant defines them. Rebuilt in lockstep with  
  TX_TLETS v4.18 (BASE-SYNC).  
**REASON:** Found by the then-new audit_devdoc_optionals gate, which enumerates all 2^k subsets of
  each devdoc item's bracketed optionals -- 252 fills on the TX base, of which 20 were defective  
  at v4.17 while enforce read 36 PASS / 0 FAIL. A green board is not coverage. Recovered  
  2026-08-03 from commit b95bc364; this entry read "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v1.13 -- 2026-07-30 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.12 -- 2026-07-30 -- DH card mirrored to DL + entity-scoped NCIC test values

**CHANGED:** DH rows now match DL exactly -- ROW_PER_DHL1 6/6 (OLN + Purpose Code), ROW_PER_DHN1 6/6
  (First + Last), NEW ROW_PER_DHN1B 6/6 (MI + Suffix). DH had kept OLN on an 8/4 and all four  
  name fields on a 3/3/3/3. Both Person cards now read 6/6 x4 then the 4/4/4 options row.  
**REASON:** Rob -- applying DEX-1283 #4 to DL only was too literal; DH had the same uneven-field
  problem the ticket reported. Layout only, no QIDM/combo/wire change (query_trace unchanged).  
  Paired with entity-scoped test-value overrides ('<Entity>.fieldId=value', new) so NCICNumber  
  sends a valid per-file prefix: Article A123456789 / Firearm G123456789 / Boat B123456789.  
  v4.15 sent X123456789 for all three and the provider errored on every NCIC query -- 'X' is  
  not a valid NCIC file prefix, so those logs proved the field transmits, not that the query  
  resolves. Test-data change only; it does not itself bump the JSON.  

## v1.11 -- 2026-07-30 -- DEX-1283 #4 UI adjustments (lockstep w/ TX_TLETS v4.15) -- layout + labels only

**CHANGED:** Person DL rows restructured to match TX main: ROW_PER_L1 6/6 = OLN + CPL/DWI/RDL,
  ROW_PER_N1 6/6 = First + Last, NEW ROW_PER_N1B 6/6 = MI + Suffix. messageKey relabelled  
  'Message Key' -> 'CPL/DWI/RDL (optional)'. BASE-SYNC -> TX_TLETS v4.15.  
**REASON:** Lockstep. No QIDM/combo/wire change -- validator 114P/0F/0W, verify_build 16P/0F/0W,
  query_trace 34 built / 0 PREFILL-DEAD, variant sync clean. Never tenant-tested; 160 owed.  

## v1.10 -- 2026-07-30 -- Vehicle: all 7 metadata combinations FORM-REACHABLE (lockstep w/ TX_TLETS v4.14)

**CHANGED:** Removed the four routing-affecting Vehicle prefills (LicensePlateTypeCode=PC,
  LicensePlateYear=<year>, financialResponsibilityType=E, RegistrationState=TX) from the form and  
  dropped every combo defaults[] entry. Replaced the 3-combo VehicleInsuranceRegistrationQuery  
  block with all 7 metadata combos, most-specific-first, RESTORING RQLicensePlateNumber +  
  RQVehicleIdentificationNumber (deleted v1.9) and QVLicensePlateNumber +  
  QVVehicleIdentificationNumber (deleted v1.5). RQ{VIN}/QV{VIN} share an identical metadata set[]  
  ({VIN}) and are split on RegionId EXISTS/NOT_EXISTS + FRT NOT_EXISTS; QV{VIN} is ordered BEFORE  
  RQ{VIN} because verify_build CHECK 14 only credits an EXISTS condition on the earlier combo.  
  BASE-SYNC marker -> TX_TLETS v4.14. Stale header/description comments corrected.  
**REASON:** Lockstep with the TX_TLETS v4.14 fix. CCH carried its OWN copy of the vehicle block and
  still had the entire original bug: the prefills satisfied their siblings' set[] on every  
  submission, so RQ/QV could never win first-match. RQ is the devdoc's "(OutofState)" path, so  
  CCH would have shipped with out-of-state plate and VIN search broken. audit_query_trace went  
  4 PREFILL-DEAD -> 0; validator 114P/0F/0W; verify_build 16P/0F/0W; reachability 33/33.  
  CCH has never been tenant-tested, so no test package was reset.  

## v1.9 -- 2026-07-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.8 -- 2026-07-27 -- Person 2-card fold (lockstep w/ TX_TLETS v4.12)

**CHANGED:** Mirrored the base Person 2-card fold from TX_TLETS main v4.12. The base SEARCH OPTIONS
  card was folded away -- State/NCIC Image/Reason Code options duplicated onto the bottom row of  
  BOTH base DL and DH cards (shared fieldIds on DL, DH-suffixed RegistrationStateDH/ImageIndicatorDH/  
  reasonCodeDH on DH; DriverHistoryQuery re-sourced to them, wire targetFields unchanged). The  
  single hidden EmailAddress feeder stays shared on the DL card (RND-57165 handler untouched).  
  Base Person is now 2 cards + the 3 CCH cards (AQ/AR/FQ/IQ/QH/QR/QWI/ZR transactions + CCH-suffixed  
  fields UNTOUCHED). BASE-SYNC -> v4.12.  
**REASON:** Base<->variant lockstep -- TX_TLETS v4.12 Person fold propagates to CCH in the same pass.
  verify_build 16P/0W/0F. Layout + DH-sourcing change (wire-identical). ALL base entities + CCH  
  reset at v1.8. NOT tenant-tested (stub).  

## v1.7 -- 2026-07-27 -- UPPERCASE card titles + QH-description audit fix (lockstep w/ TX_TLETS v4.11)

**CHANGED:** (a) All card titles UPPERCASED, wording unchanged (base-6 titles + the 3 CCH cards).
  New global convention (BUILD_RULES Section 11). (b) AUDIT FIX: the QH QIDM `description` string  
  said "4 combos (BDOB/Name/SID/FBI)" but QH has had 5 combos since the v1.5 Name->SSN/MISC Choice  
  split -- corrected to "5 combos (BDOB/NAME.SSN/NAME.MISC/SID/FBI)". Description text only; the QH  
  combos themselves were already correct. BASE-SYNC -> v4.11.  
**REASON:** Rob "everything needs to be upper case" (titles) + the adversarial audit caught the stale
  QH description count. Title/description-only, no combo/QIDM/routing change. verify_build clean.  
  ALL 5 base entities + CCH RESET at v1.7. NOT tenant-tested (stub).  

## v1.6 -- 2026-07-27 -- Person DL top-row (lockstep w/ TX_TLETS v4.10)

**CHANGED:** Mirrored the base Person DL layout fix -- CARD_PER_DL restructured to the DH card's
  3-line shape: ROW_PER_L1 (12) OLN alone; ROW_PER_N2 (6/6) Date of Birth / Sex moved off the  
  OLN row. Name row unchanged. BASE-SYNC marker bumped v4.9 -> v4.10. The 8 CCH transactions +  
  3 CCH cards + CCH-suffixed fields UNTOUCHED.  
**REASON:** Base<->variant lockstep -- TX_TLETS v4.10 Person DL top-row fix propagates to the CCH
  variant in the same pass (CLAUDE.md "Provider Variants" rule). Layout-only. NOT tenant-tested.  

## v1.5 -- 2026-07-27 -- DEX-1284 shadow correction (lockstep w/ TX_TLETS v4.9) + QH.NAME Choice fix

**CHANGED:** (base-6, mirror of TX_TLETS v4.9) removed QVLicensePlateNumber + QVVehicleIdentificationNumber
  (ungated subset-shadows, platform auto-fired); KEPT regionId (optional combination field) moved  
  to the RQ plate/VIN any[] (never drop a devdoc-optional field); ROW_VEH_3 stays 4/4/4; gated  
  Boat QB in-state combos RegistrationState NOT_EXISTS  
  (were ungated -> co-fired with the State-bearing BQ OOS combos; FL in/out pattern). BASE-SYNC  
  bumped v4.8 -> v4.9.  
  (CCH-only metadata fix) QH.NAME split into QH.NAME.SSN + QH.NAME.MISC to honor the metadata's  
  mandatory Choice{SocialSecurityNumber | MiscellaneousNumber} (XML line 14221). v1.1 had wrongly  
  demoted both to optional any[] and claimed it "matches metadata exactly" -- it did NOT (the Choice  
  is mandatory; the v1.0 SSN/MISC split was actually correct). Restored the split, matching the  
  QWI.SSN/QWI.MISC sibling pattern -- one of SSN/Misc is now required on a QH Name search. QH 4 -> 5 combos.  
**REASON:** DEX-1284 adversarial re-review found (a) the base-6 QV subset-shadow (corrected on TX_TLETS
  v4.9, propagated here in lockstep) and (b) the QH.NAME dropped-Choice metadata error. Root cause of  
  (b): extract_metadata_reference.ps1 is <Choice>-blind, so audit_metadata couldn't catch it. NOT  
  tenant-tested (stub). All entities reset.  

## v1.4 -- 2026-07-27 -- DEX-1284 lockstep with TX_TLETS v4.8 (BASE-SYNC -> v4.8)

**CHANGED:** Re-synced the base-6 QIDM labels/layout to TX_TLETS v4.8's relabel/naming-convention
  pass (separate build script -- does not auto-propagate). Mirrored edits, identical to base:  
  - OLN (OperatorLicenseNumber DL + OperatorLicenseNumberDH -> "OLN")  
  - canonical "NCIC Image" (Person OPTIONS, Gun, Article, Boat)  
  - "Stolen Check" (relatedHitSearchIndicator Gun/Article/Boat)  
  - lean labels (Vehicle Make/Year, VIN, Firearm Serial, Gun Make/Caliber, Article Type, Boat  
    Reg, MI/Suffix DL+DH, Message Key) + LABEL-OVERRIDE tags on bare any[] fields  
  - Person DL/DH card titles carry query paths ("Driver License/History Search by OLN, \"OR\"  
    Name"); Firearm/Article titles "Query by" -> "Search by"  
  - uniform 4/4/4 Vehicle grid (ROW_VEH_1 5/2/2/3 -> 3/3/3/3, ROW_VEH_2 5/4/3 -> 4/4/4)  
  Person OPTIONS card KEPT (not folded) -- same rationale as base (shared State/Image/Reason/  
  EmailAddress fields + email handler owned by separate eng team, RND-57165).  
  The 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) + 3 CCH cards + CCH-suffixed fields UNTOUCHED.  
  BASE-SYNC marker bumped TX_TLETS v4.7 -> v4.8.  
**REASON:** DEX-1284 base<->variant lockstep -- TX_TLETS base v4.8 relabel pass must propagate to the
  CCH variant in the same pass (CLAUDE.md "Provider Variants" rule). Label/layout-only, no combo/  
  QIDM/routing/fieldId change. All 5 base entities + CCH reset for re-test at v1.4. NOT tenant-tested.  

## v1.3 -- 2026-07-24 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.2 -- 2026-07-21 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-07-15 -- Base-6 QIDMs rebuilt to match TX_TLETS main exactly + CCH QH metadata fix

**CHANGED:** Design rule established -- TX_TLETS_CCH must be identical to TX_TLETS main except
         for the CCH addition. Ported the 6 base QIDMs (VehReg/DL/DH/Gun/Article/Boat) and  
         their layout directly from TX_TLETS v4.0: PascalCase field naming (22 USx CAD  
         tokens; -PascalCaseUsxFields on RMS), poisoned-array-free DL/DH combos (dropped  
         inert ImageIndicator EQUALS/ReasonCode EQUALS/EmailAddress REGEX conditions),  
         identifier-priority guardrails (Plate>VIN x3, OLN>Name x7, Hull>Reg x1), QV-VIN  
         CHECK-16 reachability fix (RegionId EXISTS), CAD combo defaults (LicensePlateYear/  
         LicensePlateTypeCode on REG/RQ), DH Attention converted to the automated-handler  
         pattern. Boat keeps the same RegistrationState-in-set[] metadata divergence as  
         TX_TLETS main (documented in new TX_TLETS_CCH_ACCEPTED_DIVERGENCES.txt) with the  
         same EXISTS/NOT_EXISTS routing so both BQ (OOS) and QB (in-state/NCIC) stay  
         reachable. CCH QH: replaced the non-metadata QH.NAME.SSN/QH.NAME.MISC substitute  
         combos with the actual metadata-defined bare QH.NAME combo (SocialSecurityNumber/  
         MiscellaneousNumber now optional any[], not required) -- adds a previously-  
         impossible Name-only search path. Shared AQ/AR vs FQ/IQ NletsDestination form  
         fields resized 9->2 chars (Nlets destinations are 2-char state codes; the shared  
         field was oversized for FQ/IQ's stricter metadata). ParseCommsysNameRuleHandler  
         empty-arguments regression (shared-module fix from 2026-06-17) now picked up.  
         Retired the phases/ snapshot mechanism and legacy docs/base, docs/mc scaffolding  
         to match TX_TLETS main (git history is authoritative). Also fixed two shared-tool  
         bugs surfaced by running this provider through the pipeline for the first time:  
         build_report.ps1's PascalCase/camelCase auto-detect heuristic (now recognizes the  
         22 canonical PascalCase tokens so a deliberately-mixed provider isn't misclassified)  
         and emit_test_plan.ps1's null-handling for combos with no 'any' key (was crashing  
         on CCH's AR combo, which has no any[] fields).  
**REASON:**  TX_TLETS_CCH was scaffolded 2026-06-09 from TX_TLETS v3.3 and never picked up any
         of the fixes TX_TLETS main gained through its own v3.9->v4.0 rebuild cycle. User  
         directive: bring it to full parity with main before this stub can be considered  
         test-ready. CCH fields stay camelCase throughout (no TX_TLETS-main analog exists  
         for them).  
VALIDATOR: 113P/0F/0W/0LIM. VERIFY: 15P/0W/0F. CAD_AUDIT: 0F/0W. METADATA_AUDIT: 0F/0W  
           (Boat divergence recognized as [NOTE], not [FAIL]).  

## v1.0 -- 2026-06-09

**CHANGED:** Initial standup
**REASON:**  New provider onboarding
