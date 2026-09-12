====================================================================================
  LEDGER PATCH PROPOSAL -- read-only. IMPORT_LEDGER.md is never written by this tool.
====================================================================================
  ledger : IMPORT_LEDGER.md (531 lines)
  repo   : 20 provider build(s) indexed
  tenants: 65 examined / 26 CONTENT-PROVEN against a repo build

  agree 2  |  DISAGREE 0  |  NO LEDGER ROW 16  |  row states no version 8  |  ambiguous 0  |  not content-proven 38

  1 export file(s) SKIPPED -- the filename carries no deptId, so there is no join key:
     CA_eSUN_dept69510509021_20260910-163019.json

====================================================================================
  PROPOSAL 2 -- RUNS OUR BUILD, HAS NO LEDGER ROW
====================================================================================
  A tenant carrying our config that the ledger does not mention is a support exposure:
  nobody is accountable for a version nobody recorded. Suggested Section B rows:

  | usx-az-azdps | usx-az-azdps.mark43.com (dept 69585917479) | AZ_AZDPS v3.12 | content-verified 2026-09-12 |
  | usx-ca-clets | usx-ca-clets.mark43.com (dept 69586234535) | CA_CLETS v2.27 | content-verified 2026-09-12 |
  | usx-ca-clets-ocats | usx-ca-clets-ocats.mark43.com (dept 72322272044) | CA_CLETS_OCATS v2.12 | content-verified 2026-09-12 |
  | usx-hi-hcjdc-ofml | usx-hi-hcjdc-ofml.mark43.com (dept 69510710914) | HI_HCJDC_OFML v4.20 | content-verified 2026-09-12 |
  | qa-amyblair-test | qa-amyblair-test.mark43.com (dept 72270142625) | IL_LEADS_OFML v2.8 | content-verified 2026-09-12 |
  | qa-amyb-test | qa-amyb-test.mark43.com (dept 72362435981) | IL_LEADS_OFML v2.8 | content-verified 2026-09-12 |
  | usx-il-leads-ofml | usx-il-leads-ofml.mark43.com (dept 69510394285) | IL_LEADS_OFML v2.8 | content-verified 2026-09-12 |
  | usx-md-meters | usx-md-meters.mark43.com (dept 69509976793) | MD_METERS v2.4 | content-verified 2026-09-12 |
  | usx-nj-njcjis | usx-nj-njcjis.mark43.com (dept 69509881306) | NJ_NJCJIS v4.17 | content-verified 2026-09-12 |
  | usx-nm-nmlets | usx-nm-nmlets.mark43.com (dept 69586413893) | NM_NMLETS_OFML v2.7 | content-verified 2026-09-12 |
  | usx-ny-nyspin-ejustice | usx-ny-nyspin-ejustice.mark43.com (dept 69509789559) | NY_NYSPIN_EJUSTICE v4.26 | content-verified 2026-09-12 |
  | lakewoodoh-foundation | lakewoodoh-foundation.mark43.com (dept 67753954395) | OH_LEADS v2.11 | content-verified 2026-09-12 |
  | usx-oh-leads | usx-oh-leads.mark43.com (dept 69509682080) | OH_LEADS v2.11 | content-verified 2026-09-12 |
  | usx-or-leds | usx-or-leds.mark43.com (dept 69586491910) | OR_LEDS v2.6 | content-verified 2026-09-12 |
  | usx-tn-ties | usx-tn-ties.mark43.com (dept 69586333849) | TN_TIES v2.6 | content-verified 2026-09-12 |
  | usx-tx-tlets | usx-tx-tlets.mark43.com (dept 69509542782) | TX_TLETS v4.22 | content-verified 2026-09-12 |

  (Rob decides which of these belong in the ledger at all -- several are demo/QA tenants
   he has already said will be excluded. That decision is tenant_scope.json, not this.)

====================================================================================
  PROPOSAL 3 -- THE LEDGER MENTIONS THIS TENANT BUT RECORDS NO VERSION
====================================================================================
  These are NOT contradictions -- the row exists and states nothing about a version.
  Most are Section B.0, the NAME CORRELATION table, whose cells carry a PLATFORM COUNTER
  by design. The ledger itself says the counter is not our version, so this is a gap in
  the versioned sections (A / B), not an error in B.0. Worth recording the proven version
  somewhere a reader would look for it:

  mariposacso                      dept 57528255873   proven CA_CLETS v2.27   (mentioned on line(s) 121)
  mariposacso-foundation           dept 55074106416   proven CA_CLETS v2.27   (mentioned on line(s) 120)
  homesteadpd-fl-foundation        dept 69669966842   proven FL_FCIC v7.24   (mentioned on line(s) 118)
  miamispringspd-foundation        dept 68086125887   proven FL_FCIC v7.24   (mentioned on line(s) 122)
  northmiami-foundation            dept 67633161477   proven FL_FCIC v7.24   (mentioned on line(s) 124)
  aurorapd-il-foundation           dept 66323459475   proven IL_LEADS_OFML v2.8   (mentioned on line(s) 113)
  ny-nycapss-foundation            dept 47169169464   proven NY_NYSPIN_EJUSTICE v4.26   (mentioned on line(s) 134)
  balconesheightspd-foundation     dept 69189298576   proven TX_TLETS v4.22   (mentioned on line(s) 114)

====================================================================================
  NOT PROPOSED -- NO CONTENT PROOF (38 tenant(s))
====================================================================================
  Listed, never silently dropped. "We could not prove it" must not look like "it agrees".
  1836                               FL_FCIC              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  abbey-demo                         LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  amyblair                           FL_FCIC              content does not equal the current repo build -- it is BEHIND or divergent, so its exact version needs audit_tenant_provenance, not a guess
  cbp-demo                           LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  ccpd                               RecordsArchive       NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  ccpd-jms-migration-round-1         RecordsArchive       NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  dark-demo                          LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  dea-demo                           LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  demo                               LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  demo-boston-cad2025                LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  demo-ny-se                         LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  erich-demo1                        LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  fullwooddemo                       CA_eSUN              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  gordo                              HI_HCJDC             NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  hawaii-dle                         HI_HCJDC_OFML        content does not equal the current repo build -- it is BEHIND or divergent, so its exact version needs audit_tenant_provenance, not a guess
  hdle-foundation                    HI_HCJDC_OFML        content does not equal the current repo build -- it is BEHIND or divergent, so its exact version needs audit_tenant_provenance, not a guess
  jeffco-demo                        LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  justin-demo                        LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  kris-demo                          LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  kyle-demo                          LA_LEMS              NOT-OUR-BUILD (no version stamp) -- overwriting or recording it is a human decision
  ... and 18 more

====================================================================================
  This tool did NOT modify IMPORT_LEDGER.md and never will. The ledger is hand-authored;
  its rows carry adjudications a tool cannot reconstruct. Apply what you agree with.
====================================================================================
