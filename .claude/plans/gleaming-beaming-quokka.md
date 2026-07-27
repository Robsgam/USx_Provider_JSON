# DEX-1284: NY name-search removal + global OLN relabel convention (NY first)

## Context
DEX-1284 ("NY Data Provider Issues," Leo Hisoire) = one global labeling change + a NY Person
rework. This kicks off the queued revisit of the 6 tested providers (task #43), NY first.

Rob's decisions (2026-07-27):
- **OLN rollout** = fold into the per-provider revisit (NY now; TX/FL/CA_CLETS/HI/NJ on their turns) —
  NOT a one-shot 20-provider sweep.
- **NY purpose code** = leave as-is (the DEX "dropdown like eSUN" note is contradictory — eSUN's is a
  plain text input, not a dropdown — so skip pending clarification with Leo).
- **Scope now** = structural + OLN relabel; **hold the HI-style label trim** for Rob's forthcoming
  specific label/field instructions.

## Part 1 — Global labeling convention (doc only)
Add to the KB label standard (`knowledge-base/BUILD_RULES.txt` Section 11 / FIELD LABEL HINT STANDARD)
and CLAUDE.md's field-config section: **the OperatorLicenseNumber field (DL and DH) is labeled
"OLN"** (was "License Number" / "OL Number" / "Driver License Number"). Applied to each provider on
its revisit turn, not retroactively swept. (Card/query names stay "Driver License"/"Driver History"
— only the field label changes.)

## Part 2 — NY structural changes (rebuild v4.10 → v4.11)
File: `providers/NY_NYSPIN_EJUSTICE/scripts/build_ny_nyspin_ejustice.ps1`

1. **Remove the DGRP "DL NAME SEARCH" card + query** (DEX NY-1: condense Person to 2 cards):
   - Delete the `$dgrpQuery` QIDM (`NyNyspinDriverLicenseNameQuery`, ~lines 259-296) and its entry in
     the `configurations = @(...)` array (~line 560).
   - Delete the `CARD_PER_DGRP` card (~lines 728-755) from `$perLayout` → Person becomes 2 cards
     (CARD_PER_DL + CARD_PER_DH). `MakeLayouts` rebuilds all 3 layout variants from `$perLayout`, so
     the card drops from default/CAD_DISPATCH/FIRST_RESPONDER automatically; ENTITIES order is by
     targetEntity (Person) and is unaffected.
   - **Verified data-safe** (this session, audit C5-F6): every DGRP-suffixed field is confined to
     that one QIDM; the sole `queriesToDeselect` is DH→DL (the "select-one" toggle, already the
     FL pattern DEX calls "same logic as other states"); no RMS attr or other QIDM reads a DGRP field.
   - **Consequence (intended):** DL-by-name now runs via the DL card's `DLICN` combo, which requires
     Name+DOB+Sex; the looser name-ONLY DGRP path is what's being removed (the shadow query). RMS
     person query is untouched (DEX: "still have RMS query option").

2. **OLN relabel** (Part 1, NY's turn): the OLN field on both cards —
   `OperatorLicenseNumber` (DL, ~line 663) and `OperatorLicenseNumberDH` (DH, ~line 689) — label
   `"License Number (or search by Name)"` → **`"OLN"`** (bare, HI-style). [Exact wording confirmable
   at approval — bare "OLN" vs keeping a cross-ref helper; I'm proposing bare per DEX "License
   Number → OLN" + "cut back like Hawaii".]

3. **CAD-layout QA** (DEX NY-3): render the CAD_DISPATCH variant; the CONTEXT_INFO_CARD prepend +
   the 2 Person cards must not bunch fields — widen/`wrap` any crowded row (`templateColumns`) so
   fields drop to a new line. Fix in the layout rows if needed.

4. **Leave purpose code as-is.** **Hold** the HI-style label trim (the verbose "(or search by
   Name)"/"(Name search)"/"(leave blank for NY)" helpers on the remaining fields) for Rob's specifics.

5. Bump `$Version` 4.10 → 4.11; rebuild via `pipeline.ps1 -Provider NY_NYSPIN_EJUSTICE`
   (build → report → reset test package → enforce, now incl. phases 2f/2g). NY re-test-resets to
   PENDING at v4.11 (it was reopened earlier anyway). Update the CLAUDE.md NY row (v4.11; QIDMs 7→6,
   Person cards 3→2, combos 17→16, drop DGRP from notable patterns) + BUILD_NOTES/CHANGELOG; post the
   DEX-1284 changelog comment.

## Verification
- `enforce.ps1 -Provider NY_NYSPIN_EJUSTICE` = 0 FAIL / 0 WARN (incl. reproducibility 2f + lockstep 2g).
- `test_commsys.ps1 -Path <v4.11> -Entity Person` — DL (`DLICN` Name+DOB+Sex, `DLIC` OLN) + DH combos
  still fire; no `DGRP` combo remains.
- Render CAD_DISPATCH Person cards; visually confirm no bunched rows.
- Rendered OLN field label = "OLN".

## Deferred (await Rob's specific label/field instructions)
- HI-style label trim across NY's remaining fields (and each other tested provider on its revisit turn).
- OLN relabel on TX / FL / CA_CLETS / HI / NJ (each on its revisit turn, task #43).
- NY purpose-code dropdown (pending Leo clarification on the eSUN discrepancy).
