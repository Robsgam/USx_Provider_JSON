CA_eSUN -- THE RADIOBUTTON LINE (San Diego Sheriff)
Written 2026-09-03. Every fact below was read out of the JSONs themselves, not from memory.

WHAT THIS LINE IS
  A one-off for San Diego Sheriff, outside the normal provider process (Rob, 2026-09-02).
  v1.0 is a faithful capture of the hand-built configuration that is LIVE in that tenant; every
  later file on this line is derived from it. It is deliberately SEPARATE from the mainline.

  THE MAINLINE IS NOT HERE. It is the root JSON, providers/CA_eSUN/CA_eSUN_v3.0.json -- built
  from scratch from the devdoc + metadata, 23 combos, and it carries NO radio buttons (verified:
  0 radio controls). It cannot carry a "RADIOBUTTON" token in its name even if it wanted to,
  because Get-ProviderRootJson matches ^<PROVIDER>_v[\d.]+\.json$ exactly and any extra word
  makes every gate stop finding the provider.

THE FILES, IN ORDER

  CA_eSUN_v1.0_PRE_RADIOBUTTON_ORIGINAL_LIVE.json
      The captured live SDSO config, unmodified. No radio buttons anywhere.
      PurposeCode is a plain control. ORI appears in 7 QIDM request attributes.
      Combination fingerprint 129A6CFA17.

  CA_eSUN_v1.1_RADIOBUTTON_FIRST_RESPONDER_ONLY.json
      v1.0 + PurposeCode rendered as a radio group, Criminal Justice ordered first.
      *** The radio group renders in the FIRST_RESPONDER layout ONLY. *** The `default` and
      CAD_DISPATCH layouts are byte-identical to v1.0 -- that is asserted by the build script,
      not hoped for. No version bump was taken for the downshift, at Rob's instruction.
      Combinations UNCHANGED from v1.0 (same fingerprint 129A6CFA17) -- this file is layout only.

  CA_eSUN_v2.0_RADIOBUTTON_ALL_CONTEXTS_COMBO_FIXES_ORI_DROPPED.json
      First engineered version. Combination content changed (fingerprint -> 93960B254E) with no
      layout change beyond field labels. OriginatingAgencyORI REMOVED ENTIRELY -- 0 occurrences
      in AUTH, 0 in any QIDM.
      NOTE THE CONTEXT DIFFERENCE: the radio group here renders in ALL THREE layouts
      (default, CAD_DISPATCH, FIRST_RESPONDER). It predates the first-responder-only downshift.

  CA_eSUN_v2.1_RADIOBUTTON_ALL_CONTEXTS_ORI_IN_HEADER.json
      v2.0 with OriginatingAgencyORI restored -- but as an AUTHENTICATION attribute in the
      ConnectCIC header (1 in AUTH, still 0 in any QIDM), per devdoc line 8, rather than back in
      the <Request> where no transaction metadata defines it. Same combinations as v2.0.
      Radio group still renders in ALL THREE layouts.

  CA_eSUN_v2.2_RADIOBUTTON_FIRST_RESPONDER_ONLY_GUARDRAILS.json
      The current engineered file. v2.1 plus:
        - identifier-priority guardrails: 14 NOT_EXISTS gates (Plate > VIN > Name, OLN > Name,
          Hull > Reg, Serial > Name). All 12 were proven on the wire in the 53-log sweep.
        - the radio group downshifted to the FIRST_RESPONDER layout ONLY, matching v1.1.
      ORI stays in the header (1 in AUTH, 0 in QIDM). Same combinations as v2.0/v2.1.

HOW TO TELL THEM APART WITHOUT READING THE JSON
  radio contexts   v1.1 and v2.2 = FIRST_RESPONDER only.  v2.0 and v2.1 = all three.
  ORI              v1.0/v1.1 = in the QIDMs (x7).  v2.0 = gone.  v2.1/v2.2 = in the AUTH header.
  guardrails       v2.2 only (14 NOT_EXISTS gates). Everything earlier has none.
  combinations     v1.0/v1.1 share one fingerprint; v2.0/v2.1/v2.2 share another.

WHY EVERY FILE IS KEPT
  These are not superseded drafts. The whole point of the line is being able to hand over, or
  diff against, any specific one -- v1.0 in particular must stay recoverable exactly as ingested
  (also tagged in git as CA_eSUN-v1.0-baseline, and held at
  source/CA_eSUN_v1.0_PRE_RADIOBUTTON_SDSO_BASELINE_2026-09-02.json).
