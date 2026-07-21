# USx Provider JSON - Consolidated Monorepo

All ConnectCIC provider JSON configurations, knowledge base, and shared tools in a single repo. All new provider projects go here using the same file and build structure as existing providers.

Owner: rob.sgambellone@mark43.com
Consolidated: 2026-05-04

## Repo Structure

```
providers/{PROVIDER}/     -- 20 providers (8 active + 11 new + 1 CCH stub)
knowledge-base/           -- Build rules, anti-patterns, platform limitations
tools/                     -- Shared scripts (validator, renderers, simulators)
```

## Provider Status (updated 2026-07-21)

| Provider | Path | Version | Status | Notable patterns |
|---|---|---|---|---|
| NJ_NJCJIS | providers/NJ_NJCJIS/ | v4.10 | 61P/0F/0W/0LIM -- v4.10 (2026-07-20, Firearm CAD fix): GunQuery serial-number form fieldId + QIDM sourceField + combo set[] GunSerialNumber -> serialNumber (CAD sends camelCase serialNumber, so the USx-query button now populates the Firearm form; attribute name + targetField stay GunSerialNumber, wire unchanged). Firearm reopened + all 5 entities LIVE-RETESTED at v4.10 (35/35 logs content-verified, enforce log-content PASS). Prior -- v4.9 (2026-07-20, direct cosmetic feedback -- relabel pass, NO functional change): State bare "State" on Vehicle+Person (was "State (default NJ - change for out-of-state)"; kept initialValue=NJ, added verify_build LABEL-OVERRIDE tag for RegistrationState); dropped "(required)" from Plate Number, VIN (also spelled out "Vehicle Identification Number"), Gun/Article Serial Number; dropped "(or use X)" cross-reference helpers from Boat Registration Number + Hull ID Number. Label-only, no combo/routing/fieldId/default change. All 5 entities reopened for USx Tenant re-test (also folds in the hollow-toggle fix reopen). Prior -- v4.8 (2026-07-01) metadata-driven keyRef rename (DQ/DQN->FULL/FULLN, RQ/RQN->RANDFULL/RANDFULLN per devdoc); all 5 entities were block_entity-locked at v4.8. Full history: `providers/NJ_NJCJIS/docs/tracking/CHANGELOG_NJ_NJCJIS.md`. | VehicleStolenQuery NOT built (USER-APPROVED skip; state auto-runs QV, response data-mined via QRDM); VehReg 2 combos (RANDFULL/RANDFULLN), poisoned-array RandomRequest=Y conditions removed (RandomRequest user-controlled in any[]); DriverLicense 2 combos (FULL/FULLN); PascalCase USx fieldIds (CAD/OnScene), Mark43/RMS keys stay camelCase; CAD combo defaults; NCIC state; shared RMS module, RMS Vehicle stripped to 3 attrs |
| HI_HCJDC_OFML | providers/HI_HCJDC_OFML/ | v4.11 | 65P/0F/0W/0LIM -- v4.11 (2026-07-20, Firearm CAD fix): GunQuery serial-number form fieldId + QIDM sourceField + combo set[] GunSerialNumber -> serialNumber (CAD sends camelCase serialNumber, so the USx-query button now populates the Firearm form; attribute name + targetField stay GunSerialNumber, wire unchanged). Firearm reopened for retest; other 4 entities preserved. Prior -- v4.10 (2026-07-20, direct cosmetic feedback -- relabel pass, NO functional change): Vehicle Type bare "Vehicle Type" (dropped "- Auto (Hawaii queries)"); Vehicle-page helpers normalized to parenthetical style -- Plate Type/Plate Year "(out-of-state plates only)", NCIC Image "(if available)" (was dash-style); Person Sex (DL+DH) and DH Date of Birth helpers "(required with Name)" (dash -> parens). Label-only, no combo/routing/fieldId/default change. All 5 entities reopened for USx Tenant re-test at v4.10 (also carries the hollow-toggle tooling fix). NOTE: HI's NCIC Image label is now parenthetical, diverging from the other providers' "NCIC Image - if available" dash wording (Rob's HI-scoped call). Prior -- v4.9 USx TENANT TESTING COMPLETE (2026-07-17): all 5 entities (Vehicle/Person/Firearm/Article/Boat) live-tested and block_entity-locked, 46/46 test logs content-verified, SQVR fully CONFIRMED (0 PENDING), enforce 28P/0F/0W, iterate-phase gate CLOSED. This version = the v4.8 labeling pass (dropped "(DH)" qualifier from Driver History labels, Vehicle/Boat Image + Search Hit wording, Person collapsed 3 cards -> 2 with DH getting its own dedicated RegistrationStateDH field) plus a render-driven follow-up (Rob's visual review): Person DL/DH State moved onto the License Number row, First/Last/MI/Suffix consolidated onto one line (MI shortened, Suffix kept full), DOB+Sex paired; Firearm/Article Serial Number and Firearm Make/Caliber/Model simplified; Vehicle's VIN+Year combined onto one row with "(VIN)" dropped from the label. Two tooling bugs found and fixed during this retest: (1) import_captured_tests.ps1 was double-JSON-encoding an already-stringified formState field (broke all 46 logs' content-verification, now fixed with a type check); (2) HI's STATUS.txt used a third legacy header format sync_version_docs.ps1 didn't recognize, silently no-op'ing version updates (normalized + tool hardened with a post-write verification). Full history: `providers/HI_HCJDC_OFML/docs/tracking/CHANGELOG_HI_HCJDC_OFML.md`. | 6 basic queries (Article/Boat/DH/DL/Gun/VehReg), 16 combos all reachable; single JSON; Person 2 cards (Driver License + Driver History, each self-contained w/ own State, DH-suffix, one-directional deselect); Vehicle 3 cards (Search Options/Plate/VIN, OOS-first routing); Boat/Firearm/Article 1 card; Type Code dropdown (VEHICLE_TYPE/HI_NIBRS); ImageIndicator=N combo defaults on all VehReg combos; State in DL/DH any[] + VehReg any[] for OOS; identifier-priority guardrails complete (Plate>VIN, OLN>Name DL+DH, Hull>Reg); Name Last-first (v4.0) |
| NY_NYSPIN_EJUSTICE | providers/NY_NYSPIN_EJUSTICE/ | v4.10 | 80P/0F/3W/0LIM -- v4.9 (2026-07-17, direct feedback, finishes the FL_FCIC-style labeling pass on the 4 entities v4.8 didn't touch, plus a Rob-driven visual-render pass): Vehicle/Firearm/Article/Boat Image labels -> "NCIC Image - if available"; Vehicle Plate Type/Year/DH Transaction Type are fully bare (no parenthetical -- Rob-confirmed accepted CHECK 15 WARN x3, these are merely-defaulted officer-editable fields, not hint-worthy); Vehicle Make/Year get "(with VIN, optional)"; Vehicle card title -> "Vehicle Registration Search by Plate, \"OR\" VIN"; Firearm's Related Hit Search -> "(Y) for NCIC stolen-gun check"; Article's Serial Number drops its "(with Article Type)" cross-reference and Related Hit Search -> "Y for NCIC stolen-article check"; Person's residual "(opt)" abbreviations spelled out (MI/Suffix on DL+DH+DGRP), and DGRP's address-block "State (opt)" renamed to "Address State (optional)" to disambiguate it from the real routing State field on DL/DH. Render pass (label text alone wasn't enough -- several fields wrapped in the actual rendered form and needed column/row layout fixes, not just wording): Vehicle/Boat/Person-DL/Person-DH all had their State field pulled off a crowded row onto its own row shared with Image at 6/6 each; Person DGRP's DOB Range field rebalanced from a 2/12 column to an even 4/4/4 split. Label/title/layout-only, no combo/QIDM/wire change. All 5 entities reopened for USx Tenant re-test (reset_test_package) -- NOT yet tested at v4.9 (prior 73-capture batch was invalidated by the subsequent layout edits). v4.8 (2026-07-16, direct feedback, mirrors FL_FCIC DEX-1278): dropped the "(DH..." qualifier from every CARD_PER_DH field label -- the card's own "DRIVER HISTORY" title already disambiguates it from "DRIVER LICENSE" (verify_build CHECK 15 Rule 2 downgraded FAIL->Info portfolio-wide this session). Each DH label now matches its DL counterpart's phrasing minus the DH tag. Also reordered Name fields to First-before-Last on all 3 Person cards (DL/DH/DGRP), matching FL's now-established convention. v4.7 (2026-07-13): full live pass, all 5 entities block_entity-locked (Vehicle/Article/Boat fresh-tested, Firearm/Person preserved at v4.6). Full history: `providers/NY_NYSPIN_EJUSTICE/docs/tracking/CHANGELOG_NY_NYSPIN_EJUSTICE.md`. | PascalCase, 6 cards (Veh 1, Per 3 [DL+DH+DL-Name-Search], Gun 1, Art 1, Boat 1), 17 combos, 7 QIDMs, DGRP own card (last)+full 10-field metadata set (autoSelect), DH self-contained w/ own StateDH/ImageDH + OOS combos (DALHOUT/DALLOUT) RegistrationStateDH EXISTS/NOT_EXISTS routing, Vehicle plate OOS combo (RVEHOUT), NyNyspinTransactionName visible on DH (default DALL), PurposeCode default C on DH OOS combos, Choice-set OOS pattern (LIMIT #36), DH-suffix+one-directional queriesToDeselect, CAD defaults, State no-default (LIMIT #30), identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg) |
| AZ_AZDPS | providers/AZ_AZDPS/ | v2.3 | 71P/0F/0W/0LIM (BASE) 71P/0F/0W/0LIM (MC) | dexStateUserId, DH-suffix, WMPI queries, hidden badge |
| FL_FCIC | providers/FL_FCIC/ | v7.8 | 92P/0F/0W/0LIM -- 30/30 combos, 6 QIDMs. v7.8 (2026-07-20, Firearm CAD fix): GunQuery serial-number form fieldId + QIDM sourceField + combo set[] GunSerialNumber -> serialNumber (CAD sends camelCase serialNumber, so the USx-query button now populates the Firearm form; attribute name + targetField stay GunSerialNumber, wire unchanged). Firearm reopened for retest; other 4 entities preserved. Prior -- v7.7 (2026-07-16, direct feedback, no ticket) Boat label cleanup: RegistrationState "Destination State (blank for FL, required for name/DOB)" -> "State (leave blank for FL)" (kept the minimal hint verify_build Rule 1 still requires -- confirmed with Rob rather than a bare "State" that would FAIL); RelatedHitSearchIndicator "Stolen Search (Y for NCIC stolen-boat check)" -> "Y for NCIC stolen-boat check"; dropped "Owner" from the owner Name/DOB fields. Label-only. Boat re-opened for live re-test; Person/Vehicle/Article stay blocked at v7.6; Firearm stays open/PENDING at v7.6. Prior -- v7.6: Article card cosmetic pass (DEX-1281) + Boat collapsed from 2 cards to 1 + First/Last owner-name reorder + "NCIC Image - if available"; v7.5: Person DL/DH name-order consistency + Vehicle 1-card collapse; v7.1-v7.4: Boat Hull>Reg guardrail completion (DEX-971 zero-error pass) + DEX-1278/1279/1280 Person/Firearm/Vehicle cosmetic pass (verify_build CHECK 15 Rule 2 DH-label gate FAIL->Info portfolio-wide + Rule 3 Purpose Code exemption; FRQTitleLienInformation combo intentionally removed, approved-skip, 31->30 combos). Full history: `providers/FL_FCIC/docs/tracking/CHANGELOG_FL_FCIC.md`. | 1-card Vehicle + 1-card Boat (both collapsed from 2), Person(DL+DH OOS-only). Devdoc combo order + EXISTENCE-ONLY routing conditions (State NOT_EXISTS / OLN NOT_EXISTS / RelatedHit NOT_EXISTS) for first-match + pool isolation; ALL value-comparison conditions removed (poisoned-array rule, QIDM_REFERENCE Sec 2a); DH KQ out-of-state only; DH+Boat destination state = NCIC dropdown; Boat QB stolen routing via relatedHitSearchIndicator in set[]; identifier-priority guardrails complete (Plate>VIN, OLN>Name, Hull>Reg); Attention auto-populated (handler); RMS Vehicle stripped to 3 attrs |
| TX_TLETS_CCH | providers/TX_TLETS_CCH/ | v1.2 | 113P/0F/0W/0LIM -- STUB: 14 QIDMs (6 base + 8 CCH). v1.2 (2026-07-21, Firearm CAD fix, structural only): GunQuery serial-number form fieldId + QIDM sourceField + combo set[] GunSerialNumber -> serialNumber, ported from TX_TLETS main v4.6 (separate build script -- does not auto-propagate; same class of fix as NJ_NJCJIS v4.10/FL_FCIC v7.8/HI_HCJDC_OFML v4.11). Fix/rebuild only, first-ever live test still deferred (validator can't catch this class of bug -- internally self-consistent, only a live CAD-dispatch test would). Prior -- v1.1 (2026-07-15) base-6 QIDMs rebuilt to be identical to TX_TLETS v4.0 main (design rule: same except CCH addition) -- PascalCase, poisoned-array-free DL/DH, identifier-priority guardrails (Plate>VIN/OLN>Name/Hull>Reg), CAD combo defaults, Attention automation, QV-VIN CHECK-16 fix; Boat keeps main's RegistrationState-in-set[] divergence (TX_TLETS_CCH_ACCEPTED_DIVERGENCES.txt). CCH QH fixed to the real metadata bare Name combo (SSN/MiscNumber optional, not forced). NOT live-tested | Separate CCH-gated provider. Base 6 QIDMs identical to TX_TLETS main. All 8 CCH transactions (AQ/AR/FQ/IQ/QH/QR/QWI/ZR) on Person, autoSelect=false (named-checkbox via queryLabel), every CCH field CCH-suffixed (full isolation, zero collision), 3 CCH cards. Synthetic keyRefs (QR/QWI/ZR) + Choice splits; QH now 4 metadata-exact combos. FreeText capped display. CCH response QRDM out of scope. NOT live-tested |
| TX_TLETS | providers/TX_TLETS/ | v4.6 | 80P/0F/0W/0LIM -- v4.6 (2026-07-21, Firearm CAD fix): GunQuery serial-number form fieldId + QIDM sourceField + combo set[] GunSerialNumber -> serialNumber (CAD sends camelCase serialNumber, so the USx-query button now populates the Firearm form; attribute name + targetField + primaryFieldReference stay GunSerialNumber, wire unchanged). Same class of fix already applied to NJ_NJCJIS v4.10, FL_FCIC v7.8, HI_HCJDC_OFML v4.11. This coincides with the full re-test already owed since the 2026-07-20 hollow-any-field-toggle-fix reopen (commit 27277f37/85ea3348) -- both causes covered by one v4.6 re-test pass. All 5 entities reopened; NOT yet re-tested. Prior -- v4.5 (2026-07-17, direct feedback): Person DL card's Name-search helpers dropped -- First Name/Last Name/Date of Birth go bare (were "(Name search)"), Sex goes bare (was "(required with Name)"); none are any[]-only (all set[]-required on DQName), no CHECK-15 exposure. DH's equivalents mirrored to match (set[]-required on KQName only). Label-only, no combo/routing change. Prior -- v4.4 (2026-07-17, direct feedback): second cosmetic round on top of v4.3, plus a new shared-tool mechanism. Vehicle+Person State went bare ("State", TX default kept via initialValue -- Boat's State untouched, it's a genuine no-default routing toggle, not the same class). Removed remaining "(or search by X)"/"(or use X)" cross-reference helpers -- Vehicle Plate Number, Sticker Number, Firearm/Article/Boat NCIC Number all bare (all set[]-required in their own combo, no CHECK-15 exposure). VIN relabeled "Vehicle Identification Number". FRT dropped "(REG/VIN paths)" (bare "Fin. Resp. Type"). Region ID dropped "(regional query)" (genuinely any[]-only, no default anywhere, unlike reasonCode/State). Bare State would otherwise hard-FAIL CHECK 15's dedicated State-routing-hint rule, and bare Region ID would add a new, not-previously-accepted WARN -- both resolved by a new `# LABEL-OVERRIDE: <fieldId> -- <reason>` comment-tag mechanism added to tools/verify_build.ps1 CHECK 15 (Rob's standing directive: cosmetic label edits he explicitly calls for shouldn't shred the pipeline with FAIL/WARN noise, only real query/routing breakage should); RegistrationState/regionId/reasonCode now all carry override tags in the build script and print as accepted [INFO] instead. 80P/0F/0W/0LIM. Label/layout-only, no combo/routing change. Prior -- v4.3 (2026-07-17, direct feedback, bundles the stacked-up labeling backlog + explicit FRT default): FinancialResponsibilityType now defaults to 'E' (Extended Information, devdoc's own stated default) on both combos that need it (REG plate, VIN) -- combo defaults[] for CAD + form initialValue for the officer UI; field stays a plain visible input (no dropdown, no hiding, Rob's call). Fixed a real Name-order regression (Person DL/DH were Last-before-First, the one outlier vs NJ/CA/HI/NY/FL) to First-before-Last. Dropped the "(DH...)" qualifier from every Driver History label (mirrors FL/NY/HI). Image labels -> "NCIC Image - if available" (Person Options/Gun/Article/Boat); Related Hit Search reworded to name the actual check (Gun/Article/Boat). Cleared remaining bare "(opt)" abbreviations across all 5 entities -- merely-defaulted fields (Plate Type/Year, Purpose Code, Reason Code) went fully bare per the NY_NYSPIN_EJUSTICE precedent; Article's Serial Number dropped its "(with Article Type)" cross-reference, same precedent. Card titles reworded to FL/NY-style descriptive titles (Vehicle/Firearm/Article/Boat); Person's 3 cards/titles unchanged. Person's "SEARCH OPTIONS" card fold-in evaluated and deliberately deferred -- TX's DH QIDM shares 4 unsuffixed fields with DL (email/Image/Reason/State), a materially bigger change than HI's single-field case. Label/layout/default-only, no combo removal or routing change. All 5 entities reopened -- this is also the first live re-test since v4.0 (v4.1/v4.2 both changed the JSON without a subsequent test). Prior -- v4.2 (2026-07-15) removed the QWName combo (Wanted Person, Name+DOB with Sex/Race/RegionId/ExpandedDOB all optional) from DriverLicenseQuery -- platform-auto-sent shadow query, not client-buildable (FL_FCIC v4.2 precedent, portfolio audit also found + fixed on HI_HCJDC_OFML v4.8); DriverLicenseQuery now 3 combos (DQName, CPLName, DQOLN); removed 3 now-orphaned fields (RaceCode, ExpandedBirthDateSearchCode, RegionId) that only ever fed QWName. TX_TLETS_CCH intentionally NOT touched, deferred until this is vetted live -- v4.1 (2026-07-15) EmailAddress converted from manually-typed to the automated-handler pattern (GetUserProfileSingleValueRuleHandler, arguments=['email'] + hidden gate-feeder on the shared Person OPTIONS card, matching Attention's mechanism) -- RND-57165, delivered by the separate eng team; CJIS policy requires the actual signed-in officer's email on TLETS DL-photo requests, not a shared/typed value. ReasonCode="C" default already existed (imgDefs/imgDefsDH), confirmed satisfied -- v4.0 (2026-07-09) REBUILD under current methodology: PascalCase USx fieldIds (+ -PascalCaseUsxFields on RMS); versioned root filename; cleared PENDING_UPDATES flags (VehicleMakeName QRDM RND-62365 + ParseCommsysName args -- shared-module fixes verified present in JSON); condensed FL-style UI + full CHECK-15 label-hint pass (all 5 entities); exposed MessageKey (CPL/DWI/RDL) on DriverLicenseQuery (metadata field-authority; CPL any[]); CHECK-16 reachability fixes -- set[] does NOT gate firing, so added existence-only EXISTS gates to make all metadata combos reachable (VIN FRT EXISTS, QV-VIN RegionId EXISTS with RegionId in any[]/metadata-faithful, DL DQName SexCode EXISTS, Boat BQ RegistrationState EXISTS); DH image-variant split MERGED to 2 combos (set[] never actually gated it -- ImageIndicator=Y default now triggers Reason=C + Email, all in any[]); docs 4-category migration + tests/->logs/ + phases/ retired. Full history: providers/TX_TLETS/docs/tracking/CHANGELOG_TX_TLETS.md. | 7 cards (Veh 1, Per 3 [Options+DL+DH], Gun 1, Art 1, Boat 1), 21 CommSys combos, 6 QIDMs, PascalCase, identifier-priority guardrails (Plate>VIN, OLN>Name DL+DH, Hull>Reg), CHECK-16 reachability EXISTS-gates, MessageKey on DL, DH merged (Image=Y triggers Reason+Email trio, both auto-populated via hidden gate-feeders), CAD plate defaults (PlateYear/PlateType on REG/RQ, FRT=E on REG/VIN), DH-suffix+one-directional queriesToDeselect, TX-specific (DPSI/REG/VIN+FRT), -SkipRace on RMS |
| LA_LEMS | providers/LA_LEMS/ | v2.5 | 63P/0F/0W/0LIM (BASE) 63P/0F/6W/0LIM (MC) | DH-suffix+queriesToDeselect, Attention handler (AP #27), DP/DQ routing toggle, State in set[], State no-default |
| CA_CLETS | providers/CA_CLETS/ | v2.15 | 77P/0F/0W/0LIM -- v2.15 (2026-07-21, metadata correctness fix found by live testing): DriverLicenseQuery IR.QVC.N combo sent APPSRequestIndicator on the wire (default 'N') -- audit_log_metadata.ps1 FAILed 9/9 IR.QVC.N logs during v2.14 USx Tenant Testing ("wire field(s) not defined in metadata"). Checked the real metadata XML (DriverLicenseQuery v36, keyRef IR.QVC, primaryFieldReference=Name): its full field list is CaRequestPurposeCode/Age/BirthDate/CriminalIdNumber/Name/OperatorLicenseNumber/RaceCode/SexCode/SocialSecurityNumber/State/AddressCounty/Height -- APPSRequestIndicator is not a field of this transaction anywhere in the XML. It was a devdoc-inspired invention from an earlier build pass ("triggers APPS prohibited-person check") that violated the field-authority rule (metadata is field-authority, devdoc is query-authority) and was never metadata-verified until this live-test pass caught it. Removed entirely: attribute, combo any[]/defaults, form field, form row (rebalanced 5-field DL row to 4). Functional wire change (IR.QVC.N no longer sends APPSRequestIndicator) -- all 5 entities reopened for full re-test from Test 1 (60 prior v2.14 logs archived). Prior -- v2.14 (2026-07-21, direct cosmetic feedback -- layout + helper pass, NO functional change): Vehicle collapsed from 2 cards (Search Options + Vehicle Search) to 1, matching Firearm/Article/Boat's single-card pattern -- Plate/Type/Year stays row 1, State+Purpose moves to row 2, VIN/Make/Year and Name/City/StreetNumber shift down to rows 3-4. Added "(optional)" helpers to genuinely-optional any[]-only fields that had none: Vehicle Make/Year, City/Street Number ("with Name, optional" -- only relevant to the IN.VP name path); DL Date of Birth/Age/Height/County/Race; Article Type/Brand/Category (Article previously had zero helpers). DL Sex stays bare (set[]-required for IR.QVC.N, not purely optional -- TX_TLETS precedent for dual-role fields). DH card unchanged (Name/DOB/Sex are a required trio, not optional). Boat unchanged (already has helpers). Label/layout-only, no combo/QIDM/routing change. Prior -- v2.13 (2026-07-20, direct cosmetic feedback -- relabel pass, NO functional change): stripped cross-reference helpers from all entities -- Vehicle Plate Number/VIN/Name bare, VIN spelled out "Vehicle Identification Number", Plate Type/Year bare; Person DL License Number/CII/SSN/Sex/APPS bare, DH labels dropped "(DH)" qualifier per portfolio convention; Firearm Serial/Name bare, Purpose Code moved onto Name row; Article Serial/OAN bare; Boat Hull/Reg/OAN bare, Name "(out-of-state only)" kept as minimal hint. Label-only, no combo/routing/fieldId/default change. Prior -- v2.12 (2026-07-01) restored in-state DL combos ID.L1 (OLN) + IN.L1 (name) as gated catchalls; LIVE-TESTED at v2.12. Full history: `providers/CA_CLETS/docs/tracking/CHANGELOG_CA_CLETS.md`. | purposeCode (CAD-aligned fieldId), DH-suffix fieldIds, cross-entity Name on Veh/Gun/Boat, no ImageIndicator, 6 basic queries, yyyyMMdd dates, CAD defaults on IA.QV. DL: 8 combos (NLTS.DQ.N/DQ + IR.QVC.N/O/C/S + in-state ID.L1/IN.L1). RegistrationState EXISTS guards all NLTS combos. OLN cascade: OLN+State->NLTS.DQ, OLN+CII->IR.QVC.O, OLN-only->ID.L1. Name cascade: Name+State->NLTS.DQ.N, Name+Sex->IR.QVC.N, Name-only->IN.L1. CII->IR.QVC.C, SSN->IR.QVC.S. |
| CA_VENTURA_COUNTY | providers/CA_VENTURA_COUNTY/ | v1.4 | 68P/0F/0W (BASE) 72P/0F/0W (MC) | 6 basic queries, CaRequestPurposeCode (visible Inp), DL+DH DH-suffix+queriesToDeselect, MC cross-entity (IN.VP/IG.QGH/NLTS.BQ.N) |
| CA_CONTRA_COSTA | providers/CA_CONTRA_COSTA/ | -- | INCOMPLETE -- metadata has only JAWS person queries, no OLN, no Vehicle/Boat/Gun/Article; CLETSPersonSuperQuery in devdoc but NOT in metadata; waiting for updated docs | 2 transactions (6 combos), Person only, RequestingAgencyId on all combos |
| CA_CLETS_OCATS | providers/CA_CLETS_OCATS/ | v1.2 | 63P/0F/0W/0LIM (BASE) 63P/0F/0W/1LIM (MC) | CLETS_OCATS v21, 5 basic queries (no DH), VP owner search, 19 combos, OCATS-specific queries available (warrants, juvenile, LARS) |
| CA_eSUN | providers/CA_eSUN/ | v1.5 | 71P/0F/0W/0LIM (BASE) 71P/0F/1W/2LIM (MC) | CaRequestPurposeCode (visible Inp), VP owner search, gun-by-name, Attention handler, MC multi-card (14 cards) |
| CA_SAN_LUIS_OBISPO | providers/CA_SAN_LUIS_OBISPO/ | v1.3 | 65P/0F/0W (BASE) 65P/0F/0W (MC) | Regional interface, DL+DH DH-suffix+queriesToDeselect, short keyRefs, MC multi-card (15 cards) |
| IL_LEADS_OFML | providers/IL_LEADS_OFML/ | v1.1 | 61P/0F/0W/0LIM (BASE) 61P/0F/0W/1LIM (MC) | 5 basic queries (no DH), Z2/Z5 keyRefs, MC multi-card (11 cards) |
| MD_METERS | providers/MD_METERS/ | v1.3 | 69P/0F/0W/0LIM (BASE) 69P/0F/0W/1LIM (MC) | 6 basic queries, DH-suffix+queriesToDeselect, ZVEH/ZLRG/ZDRV invented keyRefs, MC multi-card (12 cards), State no-default |
| OH_LEADS | providers/OH_LEADS/ | v1.3 | 77P/0F/0W/0LIM (BASE) 77P/0F/1W/4LIM (MC) | 6 basic queries, 9 VehReg combos, BMVIMS, owner search (RN), MC multi-card (14 cards) |
| NM_NMLETS_OFML | providers/NM_NMLETS_OFML/ | v1.3 | 66P/0F/0W/0LIM (BASE) 66P/0F/0W/1LIM (MC) | 6 basic queries, DH-suffix+queriesToDeselect, GunModel field, MC multi-card (12 cards) |
| OR_LEDS | providers/OR_LEDS/ | v1.3 | 58P/0F/0W/0LIM (BASE) 58P/0F/0W/0LIM (MC) | 5 basic queries (no DH), invented keyRefs, MC multi-card (11 cards) |
| TN_TIES | providers/TN_TIES/ | v1.4 | 80P/0F/0W/0LIM (BASE) 80P/0F/1W/3LIM (MC) | 6 basic queries, 28 combos, no State initialValue, MC multi-card (14 cards), DH-suffix |

## Legacy Repos (READ-ONLY)

Individual repos are preserved for history but are now read-only. All active work happens here.

- [NJ_NJCIS_JSON](https://github.com/LooseConnection/NJ_NJCIS_JSON) (LooseConnection)
- [HI_HCJDC_OFML](https://github.com/Robsgam/HI_HCJDC_OFML) (Robsgam)
- [NY_NYSPIN_EJUSTICE](https://github.com/Robsgam/NY_NYSPIN_EJUSTICE) (Robsgam)
- [AZ_AZDPS](https://github.com/Robsgam/AZ_AZDPS) (Robsgam)
- [CA_CLETS](https://github.com/Robsgam/CA_CLETS) (Robsgam)
- [FL_FCIC_JSON](https://github.com/LooseConnection/FL_FCIC_JSON) (LooseConnection)
- [TX_TLETS_JSON](https://github.com/LooseConnection/TX_TLETS_JSON) (LooseConnection)
- [LA_LEMS (formerly LA_LETTS_OFML)](https://github.com/LooseConnection/LA_LETTS_OFML) (LooseConnection)
- [ConnectCIC-KB](https://github.com/Robsgam/ConnectCIC-KB) (Robsgam)

---

## Build Model — Single JSON, Multi-Card from Start

One build script per provider → one `<PROVIDER>.json`. Always multi-card. No separate BASE/MC variants.

**Step 1 — QIDM Confirmation**: Build all QIDMs and combinations. Every field, every combo. Run `test_commsys.ps1` to verify all combos fire. 100% coverage from the start — no "MC expansion candidate" parking.

**Step 2 — Layout Refinement**: One card per search path for entities with 2+ distinct paths. QIDM does not change. Layout only. Retest affected entities.

**Step 3 — Split Entity**: Only if multi-card reveals a state model conflict that cannot coexist in one QIF. Most providers never need this if NCIC state pattern works.

**Why QIDM-first**: NJ and NY both introduced layout complexity before confirming QIDM paths. When tests failed it was impossible to tell if the failure was the QIDM, the layout, or the state model. Confirm QIDMs first — isolate layout from data path problems.

---

## 3-Bundle Structure

Every provider JSON has exactly 3 bundles in this order:

1. **ENTITIES** (`provider='MARK43'`): All QIFs (entity input forms) + display order
2. **PROVIDER** (`provider=[PROVIDER_NAME]`): AUTH, QMF, QRDM, all QIDMs
3. **RMS** (`provider='RMS'`): Built from KB specs via `_build_rms_bundle.ps1`

**ENTITIES must be first.** Confirmed AZ v2.0: forms do not render when ENTITIES is not first.

**QUERYINPUTFORM belongs ONLY in the ENTITIES bundle.** Adding it to any other bundle causes duplicate entity form cards.

---

## Anti-Patterns and Platform Limitations

Full reference: `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 31 LIMITATIONs with cross-reference index).

---

## Field Configuration Rules

### USx CAD Field Names — PascalCase (authored from the start)

The 22 USx CAD-integration field names (the ones CAD/OnScene auto-populate) are **PascalCase**, matching Cringer's engineering reference JSON. Mark43/RMS-internal keys (firstName, vinNumber, dlNumber, *AttrDetail.id, response JSON paths, …) stay camelCase.

- **Author PascalCase directly** in the build script — layout `Inp`/`Sel`/`Dt` fieldId args, QIDM `sourceField`, and combo `set[]`/`any[]`. The QIDM `targetField`, combo `defaults[].field`, and attribute `name` are already PascalCase.
- RMS form-fed fields: pass `-PascalCaseUsxFields` to `Build-RmsBundle`.
- **NEVER use a whole-tree recase post-transform.** The retired `Convert-UsxCasing` function (NJ ≤ v4.1) recursed the full output object and enumerated each Craft.js `nodes` list, collapsing single-child lists to a bare string and empty lists to `null`. Craft.js requires `nodes` to be an array, so the form body silently failed to render (only tab names showed). Removed 2026-06-18; all casing is now native.
- The 22 tokens: LicensePlateNumber, LicensePlateTypeCode, LicensePlateYear, RandomRequest, RegistrationState, ImageIndicator, VehicleIdentificationNumber, NCICNumber, VehicleMakeCode, NameFirst, NameLast, BirthDate, SexCode, OperatorLicenseNumber, GunSerialNumber, GunMake, GunCaliber, GunModel, ArticleSerialNumber, ArticleTypeCode, RegistrationNumber, BoatHullIdNumber (+ DH-suffix variants where present).
- **Rollout status**: NJ, FL, HI are PascalCase. The remaining providers are still camelCase — convert each on its next scheduled rebuild (author PascalCase + add the RMS switch), not in a mass update.

### Code Type Pairings (confirmed working)

| codeTypeCategory | codeTypeSource | Notes |
|---|---|---|
| NCIC_LICENSE_PLATE_TYPE | NCIC | Baseline |
| NCIC_FIREARM_TYPE | NCIC | Baseline |
| NCIC_FIREARM_MAKE | NCIC | FIREARM makes only. NOT vehicle makes (AP #24) |
| VehicleType | **VEHICLE** | QRDM response **vehicle make** lookup (VehicleMakeName). Vehicle codes live in the `VehicleType` table under the `VEHICLE` source (user-verified vs platform registry 2026-06-24). NOT NCIC_FIREARM_MAKE. |
| NCIC_FIREARM_CALIBER | NCIC | FormInput also valid |
| NCIC_ARTICLE_TYPE | **CA_CLETS** | NCIC gives empty dropdown |
| YES_NO_UNKNOWN | **NCIC** | Y/N only. NIBRS adds Unknown (3 options) |
| NIBRS_SEX | NIBRS | DO NOT use attributeTypeId=SEX (see Sex Code section) |
| NIBRS_RACE | NIBRS | DO NOT use attributeTypeId=RACE. NCIC = empty dropdown |
| NJ_NIBRS_STATE | NJ_NIBRS | For OOS state dropdowns |
| VEHICLE_BODY_STYLE | Provider-specific | NJ=NJ_NIBRS, CA=VEHICLE. NCIC = empty |
| -- | **attributeTypeId** | -- |
| VEHICLE_MAKE | NCIC (via attributeTypeId) | **MUST be FormSelect (Sel) on ALL providers.** Dropdown works. NEVER use FormInput. Confirmed: NJ, FL, CA_CLETS, TX live-tested. |

### State Field

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 5 (NCIC pattern vs dual-field
fallback, RMS wiring, the initialValue-vs-routing decision tree, LIMITATION #30). One-line
summary: prefer the single NCIC-pattern `RegistrationState` field; do NOT set `initialValue`
on it when the provider has separate in-state vs OOS keyRefs (changes which combo fires) —
use a card title hint instead.

### Date Fields
FormDate sends ISO yyyy-MM-dd. QIDM attribute: `rule=CommsysParseDateRuleHandler`, `arguments=['yyyy-MM-dd','MMddyyyy']`.

### Name (composite)

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 7 (FormatStringRuleHandler wiring,
the authoritative ConnectCIC LAST-first / `LAST, FIRST MIDDLE SUFFIX` format rule, the
individual-component-tags recommendation, and per-provider audit history). One-line summary:
`sourceField` order is `@('nameLast','nameFirst','nameMiddle','nameSuffix')`; all 5 in-scope
providers (NJ/CA_CLETS/HI/FL/NY) build Last-first — cross-check this order on every new build.

### LicensePlateNumber
In-state: `fieldId='licensePlateNumber'`. OOS: `fieldId='LicensePlateNumberOut'`.
Generic 'LicensePlateNumber' does NOT trigger RMS plate search.
QIDM `targetField` remains 'LicensePlateNumber'.

### ImageIndicator
Three requirements (all must be met): QIDM attribute `size=1`, FormSelect `initialValue='Y'` (or 'N' for vehicle), field listed in set[] or any[].

---

## Sex Code Configuration

Full reference: `knowledge-base/FIELD_REFERENCE.txt` Section 5 (working pattern, critical rules, fallback).

---

## QIDM Architecture

### queryLabel Standard

Every QIDM must have a `queryLabel` property. Use these standard values:

| Query | queryLabel |
|---|---|
| VehicleRegistrationQuery | Vehicle Registration |
| VehicleStolenQuery | Vehicle Stolen |
| DriverLicenseQuery | Driver License |
| NyNyspinDriverLicenseNameQuery | DL Name Search |
| DriverHistoryQuery | Driver History |
| GunQuery | Firearm |
| ArticleSingleQuery | Article |
| BoatQuery | Boat |
| WMPIPersonWINQQuery | Wanted Person |
| WMPIPersonMINQQuery | Missing Person |
| CAISupervisedReleaseQuery | Supervised Release |
| CCHCriminalHistoryQHQuery | CCH Criminal History (QH) |
| CCHCriminalHistoryIQQuery | CCH Name Inquiry (IQ) |
| CCHCriminalHistoryQWIQuery | CCH Wanted/III (QWI) |
| CCHCriminalHistoryQRQuery | CCH Record Request (QR) |
| CCHCriminalHistoryZRQuery | CCH Record Request (ZR) |
| CCHCriminalHistoryFQQuery | CCH SID Query (FQ) |
| CCHCriminalHistoryAQQuery | CCH Admin Query (AQ) |
| CCHCriminalHistoryARQuery | CCH Admin Response (AR) |
| RMS (all) | RMS |

Label by what the officer is searching for, not by backend system name. Do not use entity names ("Person"), system names ("NCIC", "DMV"), or append "Query".

### Combination Format
```json
{
  "requirements": { "set": [...], "any": [...] },
  "primaryFieldReference": "<attribute name>",
  "keyReference": "<unique key>",
  "state": "In/Out"
}
```

- `keyReference` not `keyRef` — wrong property name causes silent null, then import rejection
- `primaryFieldReference` uses the QIDM attribute name (e.g. 'Name'), not sourceField
- `state` is required on CommSys QIDMs
- No `name` property on combinations

### Merge vs Split Decision

1. Is another QIDM targeting the same (targetEntity, query)? If no → safe to create separate QIDM.
2. Can you merge? All keyRefs distinct across both → merge into one QIDM.
3. Duplicate keyRefs? → (a) Check for separate MetaData transaction. (b) Invent a distinct keyRef (DALL + DALH). Provider routes by field content, not keyRef. (c) DH-suffix fieldIds. (d) Only after a–c fail: declare not implementable.

**keyRef is platform-internal only.** Provider does not validate it. Invented keyRefs work. Confirmed: NY v1.19.

### DL + DH on Same Form (Scenario A — FL pattern)
- autoSelect=true + queriesToDeselect on each QIDM
- DH-suffix fieldIds: NameFirstDH, NameLastDH, BirthDateDH, SexCodeDH, OperatorLicenseNumberDH
- DH QIDM references only DH-suffixed names in set[]/sourceField

### DL + DH on Separate Forms (Scenario B — NY pattern)
- Shared field pool makes queriesToDeselect ineffective
- DH co-fires with DL on OLN entry = correct police workflow
- For true isolation: DH-suffix fieldIds on DH form

### Combination Ordering
Most-specific (most set[] fields) first. Less-specific last.

---

## RMS Bundle — Built from KB Specs

**All builds**: RMS bundle and CommSys QRDM are constructed by `tools/_build_rms_bundle.ps1` from inline KB specifications. No external template dependency (no HIDLE.json). Build scripts dot-source the module and call:
- `Build-RmsBundle` — returns complete RMS bundle (AUTH, QMF, Vehicle QIDM, Person QIDM, QRDM, ResultsLayout)
- `Build-CommsysQrdm -ProviderName <name>` — returns CommSys QRDM for the PROVIDER bundle

**Flags**: `Build-RmsBundle -KeepSsn` (AZ, TN) to include socialSecurityNumber. `Build-RmsBundle -SkipRace` (TX, LA, MD, CA_CONTRA_COSTA) to exclude race attr and raceCode from combo any[]. `Build-RmsBundle -PascalCaseUsxFields` (NJ, FL, HI — the PascalCase providers) to emit the form-fed `sourceField`/`set`/`any` USx references in PascalCase so they match the PascalCase form fieldIds; Mark43-internal targetFields stay camelCase. Default off (camelCase) for the not-yet-converted providers.

**No post-build patches.** If a new issue is found, update the build script or `_build_rms_bundle.ps1` — never add a JSON patch.

---

## Live Test Capture — CommSys + RMS Pairing (standard as of NJ_NJCJIS v4.7, rolling out)

**Background:** `Build-RmsBundle` only emits a Vehicle QIDM and a Person QIDM (see above) — Gun,
Article, Boat, and DriverHistoryQuery have **no RMS mapping at all**. Prior to 2026-07-01, the
capture automation (`automation/extension/`) only scraped the CommSys/ConnectCic wire XML from
dex-log; it never touched the RMS side, so a whole class of RMS-only regressions (e.g. a QRDM
code-source mismatch producing "Mock results processed" — see NJ v4.6→v4.7, and the same class
fixed for FL/HI/CA) was only ever caught by someone manually screenshotting the RMS UI. This is
now closed: dex-log's table carries an RMS-destination row alongside the ConnectCic row for every
query that has an RMS mapping, and its own "View request and return" popup exposes the RMS
elasticQuery request + response text — `automation/extension/capture.js` now captures both and
pairs them by field-map content (order-independent), not by a fragile string/position match.

**Test log section order** (`tools/post_test.ps1`): header stamp (JSON Version/Entity
Fingerprint/Tier) → `QUERY STRING` (the dex-log field-map JSON) → `COMMSYS XML`
(pretty-printed/indented, not the minified wire string) → `COMMSYS XML RESPONSE`
→ `RMS QUERY` (request + response together) → `FIELD ANALYSIS` → `NOTES` → `RESULT`. `RMS QUERY`
reads "Not captured" for Gun/Article/Boat/DH — that's the **correct, expected** state (no RMS
mapping exists for those entities), not evidence of a gap.

**`logs/` — the ONLY test log, self-contained.** The separate narrative `tests/` folder was
eliminated 2026-07-01 (redundant once `logs/<Entity>/` carried the full FIELD ANALYSIS/NOTES/RESULT
content, not just wire evidence). Every test now has exactly one file:
`providers/<PROVIDER>/logs/<Entity>/<PROVIDER>_v<X.Y>_<Combo>.txt` — one folder per entity
(Vehicle, Person, Firearm, Article, Boat), one file per query, containing the full section order
above. The versioned test plan lives at the ROOT of this same folder:
`providers/<PROVIDER>/logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json` — `emit_test_plan.ps1`'s default
output. This makes `logs/` a standalone package (plan + every query's full evidence + narrative)
that doesn't require cross-referencing `docs/` to audit. `logs/.test_state.json` +
`logs/.test_version` (moved from the old `tests/` folder) are the entity fingerprint/version state
that `reset_test_package.ps1`/`block_entity.ps1` read and write.

**Rollout**: NJ_NJCJIS is the pilot/reference implementation (v4.7, 2026-07-01). Other providers
(CA_CLETS, FL_FCIC, NY_NYSPIN_EJUSTICE, TX_TLETS, etc.) pick this up automatically the next time
they go through a full rebuild/re-test cycle — do not backport it to another provider's capture
usage ad hoc before that.

---

## QIF Layout Helpers — Shared Module

**All builds**: All QIF layout construction functions are defined in `tools/_build_layout_helpers.ps1`. Build scripts dot-source it alongside `_build_rms_bundle.ps1`.

**Exports**: `N` (node factory), `Inp` (FormInput), `InpH` (hidden FormInput), `Sel` (FormSelect), `SelH` (hidden FormSelect), `Dt` (FormDate), `BuildMultiCardLayout` (multi-card layout engine with hidden row support), `AddCadNodes` (CAD dispatch context card), `AddFrNodes` (First Responder context card), `MakeLayouts` (builds all 3 layout variants: default, CAD_DISPATCH, FIRST_RESPONDER).

**InpH signature**: `InpH($fid, $lbl, $maxLen, $parentId, $extra)` — same as Inp but `hidden=$true`. Pass `$null` for maxLen when not needed.

---

## Provider Helpers — Shared Module

**All builds**: Provider boilerplate (AUTH, QMF, QRDM, ENTITIES bundle, output+validation) is defined in `tools/_build_provider_helpers.ps1`. Build scripts dot-source it alongside the layout and RMS modules.

**Exports**:
- `Build-Auth -ProviderName <name> [-ExtraAttributes <array>] [-ExtraAny <array>]` — standard 3-attr AUTH config (ORI, Mnemonic, UserName/dexStateUserId). IL_LEADS_OFML uses `-ExtraAttributes` for CDCName.
- `Build-Qmf -ProviderName <name>` — QUERYMESSAGEFORMAT with CommsysWsiOutgoingMessageHandler.
- `Build-ProviderQrdm -ProviderName <name>` — wraps Build-CommsysQrdm, sets name/description/provider.
- `Build-EntitiesBundle -Configurations <array> [-DefaultOrder <array>] [-CadOrder <array>] [-FrOrder <array>]` — ENTITIES bundle with configurable display order. Defaults to Vehicle-first standard.
- `Write-ProviderJson -BundleObject <obj> -OutPath <path> [-PhasePath <path>] [-Label <string>]` — ConvertTo-Json readable output, UTF-8 no BOM, runs validator with exit-on-fail.

---

## Rule Handler Reference

Full reference: `knowledge-base/RULE_HANDLERS.txt` (25 handlers — 7 directly configured, rest platform-defined in RMS).

---

## Entity Display Order

ENTITIES bundle `order` array must use targetEntity values:
```json
{
  "default":         ["Person","Vehicle","Firearm","Article","Boat"],
  "CAD_DISPATCH":    ["Vehicle","Person","Firearm","Article","Boat"],
  "FIRST_RESPONDER": ["Vehicle","Person","Firearm","Article","Boat"]
}
```

Entity names, config names, and labels do NOT work. Check the Entity Display Order section above before any order fix.

---

## Layout Structure (Craft.js Node Tree)

```
ROOT → FORM_ROOT (Form, hidePageItems=true, layout='page')
     → ROOT_PAGE (Page, title='Page 1')
     → CARD_xxx (Card, optional title)
        → ROW_xxx (Row, templateColumns=['6','6'])
           → FIELD_xxx (FormInput / FormSelect / FormDate / FormCheckbox)
```

Three layout variants per QIF: `default`, `CAD_DISPATCH`, `FIRST_RESPONDER`.

**CAD_DISPATCH**: Prepend CONTEXT_INFO_CARD with CadUnit_Input + CadEvent_Input before entity cards. ROW_0.parent MUST point to 'CONTEXT_INFO_CARD' (not ROOT_CARD).

**FIRST_RESPONDER**: Same as CAD_DISPATCH (+ optional LinkToEvent checkbox). Whether platform renders FIRST_RESPONDER distinctly is unconfirmed. Include in all builds.

**templateColumns**: Array of strings. `['12']` = full width. `['6','6']` = two columns. `['4','4','4']` = three columns.

---

## Tools (57 scripts + 10 shared modules in `tools/`, + 1 archived one-time migration tool in `tools/_archive/`)

All tools are provider-agnostic. `banned_patterns.txt` is the only non-script (consumed by verify_build.ps1).

Shared modules (dot-sourced, `_`-prefixed): `_build_rms_bundle.ps1`, `_build_layout_helpers.ps1`, `_build_provider_helpers.ps1`, `_json_canonical.ps1`, `_resolve_provider_json.ps1` (active-JSON resolver `Get-ProviderRootJson` — bare → versioned → `_MC` → `_BASE`).

### Core Build Pipeline (run every build via build_report.ps1)

| # | Tool | Purpose | Key flags |
|---|---|---|---|
| 1 | `validate.ps1` | 6-phase structural validator (encoding, bundles, QIF types, QIDM refs, autoSelect, combos) | `-Path <json>` `-ShowDetail` |
| 2 | `render_layout.ps1` | CLI layout tree renderer (LAYOUT_REPORT). Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 or audit_repo.ps1 Category 10 | `-Path <json>` `-Summary` `-Entity` `-Variant` `-QidmOnly` |
| 3 | `test_commsys.ps1` | CommSys query simulator (combo matching + XML output; QUERY_REPORT). Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 or audit_repo.ps1 Category 10 | `-Path <json>` `-Entity` `-Combo` `-OutFile` |
| 4 | `report_picklists.ps1` | Scans FormSelect dropdowns + QRDM/QIDM code types (PICKLIST_REPORT). Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 or audit_repo.ps1 Category 10 | `-Path <json>` `-OutFile` |
| 5 | `render_html.ps1` | Self-contained HTML layout report with color-coded fields and QIDM tables | `-Path <json>` `-OutFile` |
| 6 | `verify_build.ps1` | Post-build verification (banned patterns, fieldId consistency, reference patterns, Visible-First Mandate / hidden-field check) | `-Path <json>` `-CamelCase` |
| 7 | `audit_metadata.ps1` | Validates QIDM configs against authoritative XML metadata | `-Path <json>` `-OutFile` |
| 8 | `audit_cad.ps1` | CAD dispatch field alignment (camelCase fieldIds, layout variants, Patch 8) | `-Path <json>` `-Variant` `-OutFile` |
| 9 | `generate_test_matrix.ps1` | Auto-generates test matrix from JSON (render + combo + any[] + deselect + negatives) | `-Path <json>` `-OutFile` |
| 10 | `run_test_matrix.ps1` | Automated test conductor — validates all test matrix cases via combo simulation. Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 | `-Path <json>` `-Matrix <file>` `-OutFile` |
| 11 | `simulate_response.ps1` | CJIS response handler simulator: executes all QRDM handler transformations (Height, Name, VehicleYear, truncate, AttributeMapping) against comprehensive synthetic test data per entity. Target: 0 MISSING / 0 UNMAPPED. No live data required. Opt-in (`-IncludeExtended`) — advisory, not read by enforce.ps1 | `-Path <json>` `-Entity` `-RunEdgeCases` `-OutFile` |
| -- | `build_report.ps1` | **Master orchestrator** — always runs 1, 5-9 + saves reports to docs/, then prunes orphaned variant reports (build-owned report files for a JSON variant no longer present — e.g. after consolidating branches). Pass `-IncludeExtended` to also run 2-4 (layout/query/picklist reports) plus 10-11, lint/label-review/officer-guide/test-conductor (8 advisory outputs demoted from the default run 2026-07-06 -- nothing gates on them) | `-Path <json>` `-IncludeExtended` |

### Auditors (repo-wide checks)

| Tool | Purpose | Key flags |
|---|---|---|
| `enforce.ps1` | **MANDATORY FINAL GATE** -- runs ALL checks (build freshness, validator scores, doc sync, cross-provider, repo audit, git status) | `-Provider <name>` `-SkipGit` `-Rebuild` `-Reproducible` `-OutFile` |
| `audit_reproducible.ps1` | Proves committed JSON == a fresh build: runs the build script twice into scratch (via $env:REPRO_OUTPATH hook), checks DETERMINISM + CURRENCY (version/PlateYear normalized). FAIL=non-deterministic; WARN=stale. Opt-in via `enforce -Reproducible` | `-Path <json>` `-OutFile` `-Strict` |
| `_json_canonical.ps1` | Shared canonical JSON serialization + hashing (ConvertTo-Canonical, Get-Sha256Hex, New-NormalizedClone). Reused by get_entity_fingerprints + audit_reproducible | (dot-sourced) |
| `pipeline.ps1` | **ONE-COMMAND PIPELINE** -- build + report + metadata + sync + version docs + cross-provider + repo audit + enforce in 8 steps; stops on first failure | `-Provider <name>` (required) `-SkipBuild` `-SkipEnforce` |
| `doctor.ps1` | **ONE-SHOT HEALTH DASHBOARD** -- read-only snapshot: score_all -Quick + poisoned-array sweep (validate G-31) + git status + reverse-propagation status | `-SkipPoison` `-OutFile` |
| `flag_pending_fix.ps1` | **REVERSE-PROPAGATE** a shared-module/JSON fix as a doc-stub flag: writes `[FLAG:<id>]` into each still-pending provider's PENDING_UPDATES.txt (blocks enforce PHASE 1 until rebuilt; build script clears it) + appends a REVERSE_PROPAGATION_LOG.md row. Idempotent. | `-FixId` `-Description` `-Providers <list\|all>` `-Origin` `-Date` `-DryRun` `-OutFile` |
| `audit_reverse_propagation.ps1` | Portfolio status view: reads every PENDING_UPDATES.txt + REVERSE_PROPAGATION_LOG.md, reports which providers are pending/propagated per fix + gaps. Informational (enforce PHASE 1 is the gate); composed into doctor.ps1 | `-OutFile` |
| `audit_repo.ps1` | Full monorepo audit (18 categories: banned patterns, versions, docs, structure, cross-provider, camelCase) | `-Category <1-18>` |
| `audit_cross_provider.ps1` | Cross-provider consistency (defaults, versions, queryLabels, code types, field types, camelCase) | `-Path <providers-dir>` `-OutFile` |
| `audit_structure.ps1` | Provider folder structure (naming, required dirs/files, reports, freshness) | `-Path <provider-dir>` `-OutFile` |
| `audit_test_coverage.ps1` | Test coverage matrix (QIDM combos vs test logs, SQVR alignment, orphan detection) | `-Path <json>` `-OutFile` |
| `score_all.ps1` | Provider scorecard -- runs validator on all providers, sorted table with rebuild flags | `-Quick` (parse existing reports) `-OutFile` |
| `lint_build_scripts.ps1` | Static analysis of build scripts for anti-patterns (PlateYear, field types, missing patches, AP #21-23) | `-Path <dir>` `-OutFile` |
| `sync_provider_table.ps1` | Auto-updates CLAUDE.md provider table scores from validator reports | `-DryRun` `-OutFile` |
| `sync_version_docs.ps1` | Auto-updates STATUS.txt, SQVR.txt, JSON_INVENTORY.md (versioned filename), REBUILD_TRACKER.md, BUILD_NOTES.txt (date checksum), per-provider CHANGELOG_<PROVIDER>.md, and the repo-root CHANGELOG.md "Current:" line, with current version and scores | `-Provider <name>` `-DryRun` |
| `generate_changelog.ps1` | Renders per-provider `docs/CHANGELOG_<PROVIDER>.md` (Markdown) from `<PROVIDER>_BUILD_NOTES.txt`. Deterministic. Step 16 of build_report; re-run by sync_version_docs | `-Path <json>` `-Provider <name>` `-OutFile <path>` |
| `preflight_rebuild.ps1` | Per-provider rebuild action plan (validator WARNs + linter + flags → checklist) | `-Provider <name>` `-All` `-Quick` `-OutFile` |

### Metadata & Extraction

| Tool | Purpose | Key flags |
|---|---|---|
| `extract_metadata_reference.ps1` | Generates METADATA_REFERENCE.txt from XML + JSON (field definitions, combo requirements, coverage) | `-XmlPath <xml>` `-Path <json>` `-OutFile` `-All` |
| `extract_queries.ps1` | Parses metadata XML into SQVR-ready tracking file | `-XmlPath <xml>` `-OutFile` |
| `diff_docs.ps1` | Diffs updated engineering docs against KB files (NEW/REMOVED/CONFIRMED per category) | `-NewDoc` `-KbFile` `-OutFile` `-Provider` |

### Provider Lifecycle

| Tool | Purpose | Key flags |
|---|---|---|
| `new_provider.ps1` | Scaffolds new provider (canonical structure, build scripts, doc templates, tool registrations) | `-XmlPath <xml>` `-PdfPath` `-Force` |
| `new_test_log.ps1` | Creates stub test log in logs/<Entity>/ (migrated providers) or legacy tests/ (GATE 2 requirement) | `-Provider` `-Variant` `-Version` `-Entity` `-Combo` `-Description` |
| `post_test.ps1` | Instant-save after test (artifacts, STATUS, SQVR, commit, push) | `-Provider` `-Entity` `-Query` `-Combo` `-Result` `-Description` |
| `reset_test_package.ps1` | Rebuild restarts testing: on version change, archives prior logs/<Entity>/ files, resets SQVR→PENDING, clears STATUS rows, stamps logs/.test_version. Auto-run by pipeline after build. | `-Provider` `-Force` |

### Utilities

| Tool | Purpose | Key flags |
|---|---|---|
| `build_codetype_test.ps1` | Generates CODETYPE_TEST.json for dropdown validation | `-OutputPath` |
| `preflight_check.ps1` | Pre-build validation against PROVIDER_CONFIG.txt | (no args) |
| `render_cad_guide.ps1` | HTML/PDF officer reference: which queries CAD can auto-trigger vs need officer input | `-Path <json>` `-OutFile` `-PdfFile` |

Validator must pass clean (0 FAIL) before import. Verify must pass clean (0 FAIL). Fix all failures before proceeding.

---

## Import Error Quick Reference

See `knowledge-base/IMPORT_ERRORS.txt` for error-to-fix mapping.

---

## Versioning Policy

- **NEVER overwrite a tested JSON.** Save every iteration.
- **Root JSON name carries the version: `<PROVIDER>_v<X.Y>.json` (STANDARD).** The build
  script sets `$OUT = "$DIR\<PROVIDER>_v${Version}.json"`. `Write-ProviderJson` removes any
  stale sibling root JSON (bare `<PROVIDER>.json` or an older `<PROVIDER>_v*.json`) before
  writing, so the one-JSON-in-root rule holds on every bump. The bare `<PROVIDER>.json` name
  is still accepted (legacy) but new/rebuilt providers should emit the versioned name.
- **Why the filename — not a top-level `version` field — carries the version:** the platform
  deserializes a top-level `version` as `java.lang.Integer` and rejects dotted strings ("4.6").
  So version lives (a) in the filename and (b) inside the bundle `description`
  ("Provider configuration for <PROVIDER> v<X.Y> ..."), which is what enforce CHECK 3i reads.
  Do NOT re-add a top-level `version` field.
- Phase snapshots are saved to `phases/` as `<PROVIDER>_v<X.Y>_<date>.json` — **legacy pattern,
  being retired provider-by-provider starting with NJ_NJCJIS (2026-07-01).** Every version is
  already fully recoverable from git commit history (`git log`/`git show`), which `phases/` only
  duplicated while accumulating same-version-rebuild noise (NJ had 3 separate v3.6 snapshots, 2x
  v4.1, 2x v4.5 before retirement). Providers not yet migrated still use `phases/` as documented —
  don't touch another provider's build script ad hoc; each one drops it on its own next rebuild.
- **Test plan filename carries the version too: `logs/<PROVIDER>_TEST_PLAN_v<X.Y>.json`** — at the
  ROOT of `logs/` (the self-contained per-query evidence package, see "Live Test Capture" above),
  not `docs/`. Same reasoning as the root JSON above — a rebuild must never silently overwrite the
  prior version's plan with no trace. `emit_test_plan.ps1` computes this by default;
  `reset_test_package.ps1` archives any stale-version copy to `logs/_archive_pre_v<X.Y>/` and
  regenerates the current one on every reset. Rolled out to NJ_NJCJIS first; other providers pick
  it up on their next rebuild.
- Document every JSON in `docs/JSON_INVENTORY.md`. Keep all JSONs in project root.
- **Tools resolve the active JSON via `tools/_resolve_provider_json.ps1`
  (`Get-ProviderRootJson`)** — bare → versioned → `_MC` → `_BASE` — never by hardcoding
  `<PROVIDER>.json`.

---

## Source Authority Lookup Table — MANDATORY ROUTING

When you need information, use ONLY the source listed below. Do NOT substitute raw sources, do NOT guess, do NOT skip to the underlying data. If the tool/file does not exist yet, create it first.

| Question | Authoritative Source | NEVER Use |
|---|---|---|
| **Which queries** does this provider support? | Devdoc "Basic Queries Supported" section (`source/<PROVIDER>_DEVDOC.txt`) | XML metadata transaction names, naming pattern guesses |
| **How are fields defined** (types, sizes, combo requirements)? | `docs/<PROVIDER>_METADATA_REFERENCE.txt` (auto-generated by `extract_metadata_reference.ps1`) | Raw XML metadata files (`source/*.xml`) |
| **What field type** (FormInput/FormSelect/FormDate) should a field use? | `METADATA_REFERENCE.txt` field definitions + `audit_cross_provider.ps1` for consistency | Manual XML inspection, guessing from field name |
| **What combos fire** for a given entity/field set? | `test_commsys.ps1 -Path <json> -Entity <entity>` | Manual build script reading, mental combo matching |
| **What does the layout look like?** | `render_layout.ps1 -Path <json> -Summary` | Reading raw Craft.js node tree in JSON |
| **Are there structural issues?** | `build_report.ps1 -Path <json>` (runs 9 core tools; `-IncludeExtended` for the 2 advisory ones) | Spot-reading JSON sections |
| **Is this field consistent across providers?** | `audit_cross_provider.ps1 -Path providers/` | Manual grep across provider folders |
| **Are all docs/versions in sync?** | `enforce.ps1 -Provider <name>` | Manual file-by-file comparison |
| **What anti-patterns apply?** | `knowledge-base/PLATFORM_CONSTRAINTS.txt` (27 APs + 31 LIMITATIONs) | Memory, training data |
| **What does the RMS bundle contain?** | `tools/_build_rms_bundle.ps1` (all builds) + CLAUDE.md RMS Bundle section | Raw JSON inspection |
| **Current build state** (scores, warnings) | `docs/` report files (generated by `build_report.ps1`). Legacy: `docs/base/` or `docs/mc/` | Re-running validator ad hoc |
| **Test coverage status** | `audit_test_coverage.ps1 -Path <json>` + `docs/<PROVIDER>_SQVR.txt` | Counting test log files manually |
| **Conditional field constraints** ("Must be filled if X = Y") | `docs/<PROVIDER>_METADATA_REFERENCE.txt` FIELD CONSTRAINTS section (per QIDM) + `source/<PROVIDER>_DEVDOC.txt` "Possible Values" column | Training data, memory |

**Rule: If a tool exists for the question, run the tool. If an extracted file exists, read the file. Raw sources are LAST resort only when no extracted reference exists.**

---

## Workflow

Three commands run everything. No manual checklists.

| Action | Command |
|---|---|
| **Build + verify one provider** | `pipeline.ps1 -Provider <NAME>` |
| **Build + verify multiple providers** | `pipeline.ps1 -Providers 'TX_TLETS','HI_HCJDC_OFML'` |
| **Build + verify ALL providers** | `pipeline.ps1 -All` |
| **Final verification (all providers)** | `enforce.ps1` |
| **New provider setup** | `new_provider.ps1 -XmlPath <xml>` |

`pipeline.ps1` chains 8 steps: build JSON → build report (steps 1-9 parallel) → extract metadata → sync CLAUDE.md → sync version docs → cross-provider audit → repo audit → enforce. Stops on first failure. Flags: `-SkipBuild` (reports only), `-SkipEnforce` (mid-work), `-DeferAudit` (skip steps 6-7 for mid-work iterations).

**Rebuild restarts testing.** Step 1 calls `reset_test_package.ps1` after a successful build: when the JSON version changes, prior live test logs no longer line up with the shipped JSON, so they are archived to `logs/<Entity>/_archive_pre_v<ver>/` (legacy: `tests/_archive_pre_v<ver>/`), all SQVR markers reset `[CONFIRMED]→[PENDING]`, STATUS live rows cleared, and `logs/.test_version` stamped. The full test matrix re-runs from Test 1 — never resume mid-matrix across a rebuild. See `knowledge-base/TESTING_REQUIREMENTS.txt` Section 11 GATE 1.

**MANDATORY before presenting any combo test instruction:** Read `docs/<PROVIDER>_METADATA_REFERENCE.txt` for the QIDM being tested. Find the FIELD CONSTRAINTS section (if any) and verify that no combo default triggers a "Must be filled if X = Y" conditional requirement on a field that has no default and no handler. If a violation exists: STOP, fix the build, rebuild, re-import — do not present the test instruction. This gate applies even if the test matrix has been generated and reviewed. (Rule origin: TX_TLETS T6 — DH ImageIndicator=Y default made EmailAddress silently required per devdoc; violation was not caught at metadata extraction.)

**Batch mode** (`-Providers` or `-All`): runs per-provider steps (1-3) sequentially per provider, then ONE sync pass, ONE cross-provider audit, ONE repo audit, ONE enforce. Eliminates redundant global audits when rebuilding multiple providers.

`build_report.ps1` runs 15 steps. Steps 1, 5, 6, 7, 8, 9 always run (read-only on the JSON; core gated outputs). Steps 2 (layout report), 3 (query simulator), and 4 (picklist scanner) — plus 10 (test conductor), 11 (response simulator), 12 (label review), and 13 (officer guide) — are advisory outputs enforce.ps1 (and audit_repo.ps1 Category 10) never require — demoted to opt-in 2026-07-06 (steps 10-13) and 2026-07-06 follow-up (steps 2-4, once Category 10's report-completeness check no longer required them), skipped by default, run via `-IncludeExtended` or the underlying tool standalone. Step 14 (supported-query audit) and 15 (per-provider changelog) always run — both are read by enforce.ps1 (Phase 2e / Phase 3 doc-sync).

`enforce.ps1` runs 5 phases: build freshness, validator scores, doc version sync (8 locations per provider: CLAUDE.md, STATUS, SQVR, JSON_INVENTORY, BUILD_NOTES + date checksum, REBUILD_TRACKER, per-provider CHANGELOG_<PROVIDER>.md, repo-root CHANGELOG.md Current line), cross-provider + repo integrity (phases 4-5 run in parallel), git status. Exit 0 = verified. Exit 1 = blocked.

**Same-date docs:** the FULL `pipeline.ps1` (not `build_report` alone) is what stamps every doc to the same date in one run — build_report regenerates the 16 report/guide/changelog artifacts, then step 5 `sync_version_docs` stamps STATUS/SQVR/JSON_INVENTORY/CHANGELOG and the BUILD_NOTES date checksum. Running pieces by hand can leave docs on mixed dates; run `pipeline.ps1 -Provider <name>` to refresh them together.

**If enforce.ps1 passes, the work is done. If it doesn't, fix what it flags.**

### Design Decisions (applied automatically)

- Phase 1 = single card per entity
- 2+ search paths = multi-card (Phase 2)
- DH on same form as DL = DH-suffix fieldIds
- Duplicate keyRefs = invent distinct keyRef
- Most-specific combination first in array
- Investigate all 4 solution paths (multi-combo, separate transaction, DH-suffix, reference builds) before declaring not implementable
- Test NCIC state pattern (ST-1) on first import of any new provider

---

## Canonical Provider Structure

Every provider under `providers/` MUST have this structure. All new providers follow the same layout.

**NAMING RULE**: `<PROVIDER>` MUST match the metadata XML filename minus `.xml`. Verify before creating the folder. See `BUILD_RULES.txt` Section 0.

**ONE JSON IN ROOT RULE**: Exactly one JSON in the provider root folder at all times.
- New/rebuilt providers: `<PROVIDER>_v<X.Y>.json` (versioned name is the standard). Bare
  `<PROVIDER>.json` is still accepted (legacy).
- Legacy providers may still have `<PROVIDER>_MC.json` or `<PROVIDER>_BASE.json` until rebuild
- NEVER multiple JSONs in root simultaneously. `Write-ProviderJson` deletes stale siblings on
  build; enforce FAILs if more than one versioned JSON is present.

**docs/ 4-CATEGORY STRUCTURE (rollout, NJ_NJCJIS first, 2026-07-01):** `docs/` splits into
`tracking/`, `reports/`, `reference/`, `deliverables/` (see tree below for what goes where). A
provider is "migrated" once ANY of its 4 category folders exists — `tools/_resolve_docs_path.ps1`
(`Get-DocsCategoryDir`/`Get-DocsPath`/`Find-DocsPath`) resolves every tool's docs/ path
accordingly, falling back to the flat legacy `docs/` layout (unchanged) for any provider that
hasn't migrated. Migrate a provider by `git mv`-ing its existing docs/ files into the 4 category
folders on its next full rebuild — no tool code change needed, the resolver already handles both
states. Do not migrate a provider ad hoc outside of its own rebuild cycle.

```
providers/<PROVIDER>/
├── <PROVIDER>_v<X.Y>.json                 # Current JSON (single, version-named output per provider)
├── docs/                                   # 4-category structure [NJ_NJCJIS pilot 2026-07-01, rolling out]
│   │                                       # (legacy providers: same files, still flat in docs/ directly)
│   ├── tracking/                          # Hand-relevant, updated every version
│   │   ├── <PROVIDER>_STATUS.txt          # Live test matrix + current state
│   │   ├── <PROVIDER>_SQVR.txt            # Supported Query Validation Report
│   │   ├── <PROVIDER>_BUILD_NOTES.txt     # Change log with CHANGED/REASON per version (source of truth)
│   │   ├── CHANGELOG_<PROVIDER>.md        # Auto-generated Markdown changelog (from BUILD_NOTES)
│   │   ├── JSON_INVENTORY.md              # Every JSON version ever produced
│   │   ├── DEX_TICKET.md                  # Jira DEX ticket pointer + changelog dump log
│   │   └── BUILD_MANIFEST_<PROVIDER>.json # Hash-gate manifest (enforce.ps1 trust check)
│   ├── reports/                           # Auto-generated by build_report.ps1, fully reproducible
│   │   ├── VALIDATOR_REPORT_*.txt         # 13 report types + TEST_MATRIX (see Tools table)
│   │   └── ...
│   ├── reference/                         # Derived from metadata XML, semi-static
│   │   ├── <PROVIDER>_METADATA_REFERENCE.txt
│   │   └── <PROVIDER>_SUPPORTED_QUERIES.txt
│   └── deliverables/                      # Officer/tester-facing, not read by tooling logic
│       └── OFFICER_GUIDE_<PROVIDER>.html/.pdf
├── logs/                                  # The ONLY test log location [NJ_NJCJIS pilot, rolling out; tests/ eliminated 2026-07-01]
│   ├── .test_state.json                   # Entity fingerprint/version/block-status (authority; moved from tests/)
│   ├── .test_version                      # Legacy scalar global version (moved from tests/)
│   ├── <PROVIDER>_TEST_PLAN_v<X.Y>.json    # Machine-readable plan for the browser driver (versioned filename — see Versioning Policy)
│   └── <Entity>/                          # One folder per entity (Vehicle, Person, Firearm, Article, Boat)
│       └── <PROVIDER>_v<X.Y>_<Combo>.txt   # Full test log: header stamp + QUERY STRING + COMMSYS XML + RMS QUERY + FIELD ANALYSIS + NOTES + RESULT
├── phases/                                # Version snapshots — LEGACY, being retired provider-by-provider (git history is authoritative); NJ_NJCJIS no longer uses this
├── scripts/                               # Provider-specific build scripts
│   └── build_<provider>.ps1               # Single build script per provider
├── source/                                # Input materials
│   ├── <provider>.xml                     # Metadata XML
│   └── <provider>.pdf                     # Devdoc PDF
```

When a repo does not match this structure, fix it before doing any other work.

---

## Quick Start — New Provider

### Step 0: Naming (CRITICAL — do this FIRST)
- Open the metadata XML file and read its filename
- Provider folder name MUST match the XML filename minus `.xml`
- Example: `NM_NMLETS_OFML.xml` → folder `providers/NM_NMLETS_OFML/`
- Do NOT guess from devdoc titles, abbreviations, or user-supplied names
- Mismatched names require renaming 10+ files per provider (see `BUILD_RULES.txt` Section 0)

### Step 1: Setup
1. Read `knowledge-base/README.txt` then this file
2. Create provider folder with canonical structure (see above)
3. Copy metadata XML and devdoc PDF to `source/`
4. RMS bundle built automatically from KB specs (no template copy needed)
5. Convert PDF to text: `pdftotext source/<PROVIDER>.pdf source/<PROVIDER>_DEVDOC.txt`
6. Run `extract_queries.ps1 -XmlPath source/<PROVIDER>.xml` to populate SQVR
7. Read devdoc "Basic Queries Supported" — this is the ONLY authority for WHICH queries to build

### Step 2: Build
8. Create build script in `scripts/` (must include validator call)
9. Build all QIDMs and multi-card layout in one pass. 100% combo coverage from start.
10. GATE 1 after every build (report + commit + push)
11. Update SQVR with [PENDING] markers for every query path

### Step 3: Iterate
12. Refine layout (card splits, field ordering, defaults)
13. Split entity only if needed (NCIC state pattern usually avoids this)
14. GATE 5 before declaring DONE

### Bulk Onboarding (10+ providers)
See `TESTING_REQUIREMENTS.txt` Section 16 for the complete workflow.
Key rule: batch setup (folders, source materials), serial builds (one provider at a time).
