# IL_LEADS_OFML -- Changelog

Auto-generated from `IL_LEADS_OFML_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.0** | Generated: 2026-08-07

---

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

