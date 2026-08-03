# TN_TIES -- Changelog

Auto-generated from `TN_TIES_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.1** | Generated: 2026-08-03

---

## v2.1 -- 2026-08-01 -- KQ.N -- an in-state driver-history name search was IMPOSSIBLE (commit e3e40c53)

**CHANGED:** Removed the RegistrationState EXISTS gate from KQ.N, plus four DQ.N registrations.
**REASON:** KQ.N was gated RegistrationState EXISTS while metadata KQ{Name} has State in <Any> --
  optional, not a fork -- and there was no other name combo to fall through to, so an IN-STATE  
  driver-history name search could not be performed at all. THE RULE: a State gate belongs only  
  where the metadata FORKS BY state, never on a variant that merely permits State as an optional.  
  Recovered 2026-08-03 from commit e3e40c53; this entry read "Rebuilt via pipeline.ps1 /  
  Scheduled rebuild".  

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + PlateType/PlateYear defaults


## v1.0 -- 2026-05-06 -- Initial build -- 6 basic queries, 28 combos


## v1.4 -- 2026-05-11 -- LIMITATION elimination pass

