# NY_NYSPIN_EJUSTICE_SKILLTEST -- Changelog

Auto-generated from `NY_NYSPIN_EJUSTICE_SKILLTEST_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v1.0** | Generated: 2026-07-15

---

## v1.0 -- 2026-07-15

**CHANGED:** Initial standup. 6 QIDMs / 16 combos: VehicleRegistrationQuery (RVEH/RCAR/
  RVEHOUT/RVIN), DriverLicenseQuery (DLIC/DLICN), DriverHistoryQuery (DALH/DALL/  
  DALHOUT/DALLOUT, DH-suffix), GunQuery (GINQ), ArticleSingleQuery (AINQ), BoatQuery  
  (RVEH/RCAR/BVEH/BVIN). Single JSON, multi-card from the start (Vehicle 2 cards,  
  Person 3 cards, Firearm/Article 1 card each, Boat 2 cards). PascalCase for the 22  
  canonical USx CAD fields (+DH-suffix variants); RMS built via Build-RmsBundle  
  -SkipRace -PascalCaseUsxFields. Identifier-priority guardrails (Plate>VIN, OLN>Name,  
  Hull>Reg). Devdoc-order combo arrays + RegistrationState NOT_EXISTS gates on  
  in-state combos so first-match evaluation stays correct.  
**REASON:**  New provider onboarding (skill/procedure validation exercise). Scope
  strictly limited to the devdoc's literal "Basic Queries Supported" section (6 of  
  16 metadata query transactions) per knowledge-base/README.txt SOURCE AUTHORITY  
  RULES -- metadata existence alone does not authorize building a query. CBI, WMPI,  
  and "Expanded Transactions Supported" (10 additional metadata transactions,  
  including NyNyspinDriverLicenseNameQuery/DGRP) are documented out of scope.  
