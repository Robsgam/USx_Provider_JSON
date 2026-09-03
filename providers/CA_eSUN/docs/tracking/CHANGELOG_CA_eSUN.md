# CA_eSUN -- Changelog

Auto-generated from `CA_eSUN_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.1** | Generated: 2026-09-03

---

## v2.1 -- 2026-09-02 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-09-02 -- RND-71815 -- PurposeCode RENDERED AS A RADIO GROUP. SAN DIEGO SHERIFF ONLY.

*** THIS IS A DELIBERATE ONE-OFF, OUTSIDE THE NORMAL PROCESS. *** Rob 2026-09-02: "this will be  
considered a one off for San diego sheriif only as it stands" and "recall this is a one off so it  
can be outside the noraml process". It applies to CA_eSUN and to NO other provider; the other 19  
keep PurposeCode exactly as they have it. Do not propagate. Do not treat the gate state below as  
a standard to be met -- v1.0 is a faithful capture with pre-existing live defects, and v1.1  
changes ONE thing on top of it.  
**CHANGED:** PurposeCode type.resolvedName FormSelect -> FormRadioGroup on ALL FIVE entities
  (Vehicle, Person, Firearm, Article, Boat) across all three layout variants = 15 controls.  
  displayName -> 'Radio Group'.  
LAYOUT CORRECTED ON ROB'S EYE, 2026-09-02: "so the example in the jira had the radio boxes across  
  the top   this json lists then on the uper left".  
  props.direction 'column' -> 'row'. I had taken 'column' from Peter's reference node shape in  
  the ticket, but his SCREENSHOTS show the options laid out horizontally -- the snippet and the  
  images disagree, and the images are what SDSO asked for.  
  THE 'UPPER LEFT' WAS A SECOND, SEPARATE CAUSE and direction alone would not have fixed it.  
  PurposeCode was ALREADY in row 1 of every card (i.e. already at the top), but its row was  
  NARROW: templateColumns=[3] on Vehicle -- a quarter width -- and [6] on the other four. Two  
  long labels ("C - Criminal Justice", "I - Immigration Enforcement") cannot lay out horizontally  
  in a quarter-width column, so they stacked at the left. All 15 rows widened to ['12'].  
  SAFE BECAUSE MEASURED: each of those rows contains PurposeCode and NOTHING else (verified per  
  row before widening; the script SKIPS any row with more than one child), so widening displaces  
  no sibling control. This is also the ticket's own last requirement -- "ideally should be able to  
  control width of the radio choice label, and have text wrap if field is narrow".  
DEFAULT 'C' ADDED ON ROB'S INSTRUCTION ("and we need a default of c please"): props.initialValue  
  = 'C' on all 15 controls -- "C - Criminal Justice", confirmed present in the tenant picklist.  
  THIS DIVERGES FROM THE TICKET, DELIBERATELY AND ON THE OPERATOR'S CALL: RND-71815 requirement 2  
  says "default state : none of the options is selected (same as dropdown behavior)".  
  IT IS SAFE HERE, AND THAT IS A MEASURED CLAIM, NOT AN ASSUMPTION. A prefill on a set[] field  
  normally hides every combination that needs the field ABSENT (BUILD_RULES 24, which killed 35  
  combos across 6 providers). PurposeCode is in the set[] of ALL 25 combinations here -- so it  
  cannot shadow one combination over another; it cancels out of every comparison. Exactly the  
  CA_CLETS purposeCode='C' precedent that CLAUDE.md records as harmless for this same reason.  
  Plan regenerated after the prefill was added: still 35 tests, unchanged shape.  
  NOTHING ELSE TOUCHED -- verified by reading the emitted file back: 8 QIDMs / 25 combinations  
  before AND after, 15 of 15 converted, 0 FormSelect PurposeCode remaining.  
VALIDATOR UNCHANGED: 59 PASS / 7 FAIL / 53 WARN / 5 LIMITATION, identical to v1.0. The validator  
  does not whitelist resolvedName, so the new control type passes through it untouched. That is  
  information, not reassurance -- it means the validator can tell us nothing about whether  
  FormRadioGroup actually renders.  
THE DRIVER HAD TO BE FIXED FIRST, and this was measured, not guessed: PurposeCode sits in the  
  set[] of ALL 25 combinations, and the driver had ZERO radio handling (grep 'radio' returned  
  nothing in usx_lib.js or driver.js). Converting without driver support would have left Send  
  disabled on all 35 plan tests -- a total test failure, not a partial one. usx_lib.js gained  
  findRadioGroup + selectRadioGroup at BUILD 2026-09-02a (commit 5ac1a26c) before this bump.  
STILL UNVERIFIED, AND THE FIRST RETEST IS THE TEST OF IT: FormRadioGroup is not confirmed to  
  render at all. RND-71815 is still 'To Do' and the node shape came from a Jira comment, not from  
  a shipped example. If the control does not render, PurposeCode has no input and every query  
  fails -- which is exactly why the driver's [USx-RAD] logging dumps the options it found.  
  ALSO OPEN on that ticket: its requirement "must select a button for search to proceed" is  
  harmless HERE (PurposeCode is mandatory in every eSUN combination anyway) but would be a WIRE  
  change on any provider where the field rides in any[]. Another reason this stays a one-off.  
TENANT PICKLIST CONFIRMS THE FIT: PurposeCode returns exactly TWO options at San Diego --  
  "C - Criminal Justice" and "I - Immigration Enforcement" -- so a radio pair is the right shape,  
  and DEX_INQUIRY_PURPOSE_CODE demonstrably resolves on this tenant (contrast LIMITATION #39,  
  where it returned ZERO options on NY and forced a revert to FormInput at v4.23).  
COST PAID: the v1.0 package -- 25 logs, all PASS -- is archived to logs/<Entity>/_archive_pre_v1.1/.  
  Plan and picklist scope regenerated at v1.1. A full re-drive is owed.  
v1.0 REMAINS RECOVERABLE EXACTLY AS INGESTED: tag CA_eSUN-v1.0-baseline, carrying both the  
  working JSON (SHA CA7F4493...) and the verbatim tenant export (SHA 06C85659...).  
      git checkout CA_eSUN-v1.0-baseline -- providers/CA_eSUN  
IMPORT ARTIFACT: docs/deliverables/CA_eSUN_v1.1_RADIOBUTTON.json -- byte-identical to the root  
  JSON, named so the radio build is identifiable at a glance (Rob's request). The ROOT stays  
  CA_eSUN_v1.1.json because Get-ProviderRootJson matches ^<PROVIDER>_v[\d.]+\.json$ exactly and  
  any extra token makes every gate stop finding the provider.  

## v1.0 -- 2026-09-02 -- HAND BUILT BY ENGINEERING -- captured from the San Diego Sheriff live tenant

ORIGIN: not built by this repo's process. This is the configuration engineering hand-built and  
  that San Diego Sheriff actually runs, exported from the tenant on 2026-09-02 12:55.  
VERBATIM BASELINE ARCHIVE: source/CA_eSUN_v1.0_PRE_RADIOBUTTON_SDSO_BASELINE_2026-09-02.json  
  SHA-verified byte-identical to the download. That file is the archive point and is never edited.  
THE WORKING v1.0 DIFFERS FROM THE ARCHIVE IN EXACTLY TWO WAYS, both mechanical, both required:  
  1. UNWRAPPED. The download is a DEPARTMENT EXPORT: {departmentBundle:{bundles,behaviors},  
     m43Forms}. Our validator rejects that outright -- "[FAIL] Missing top-level 'bundles' array"  
     -- so it can be neither validated nor imported as-is. Taking departmentBundle as the root  
     yields {bundles, behaviors}, which is EXACTLY the root shape of the previous SDSO export, so  
     the unwrap is lossless. m43Forms was null; nothing was discarded. Fidelity re-verified after  
     every write: 2 bundles / 16 configurations / 8 QIDMs / 25 combinations / behaviors present.  
  2. VERSION STAMPED INTO THE BUNDLE DESCRIPTION. Was "Provider configuration for CA eSUN" --  
     carrying no version at all. CLAUDE.md's Versioning Policy requires the version to live in  
     the filename AND the bundle description (enforce CHECK 3i reads it), and without it  
     reset_test_package failed outright with "[ERROR] Could not determine version for CA_eSUN".  
     That tool derives the version from the build script or a versioned description, and a  
     hand-built JSON has neither.  
