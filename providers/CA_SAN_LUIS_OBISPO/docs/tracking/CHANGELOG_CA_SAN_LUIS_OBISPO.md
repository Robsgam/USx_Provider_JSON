# CA_SAN_LUIS_OBISPO -- Changelog

Auto-generated from `CA_SAN_LUIS_OBISPO_BUILD_NOTES.txt` by `tools/generate_changelog.ps1`. Do not edit by hand.

Current: **v2.4** | Generated: 2026-08-17

---

## v2.4 -- 2026-08-17 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.3 -- 2026-08-02 -- Carry PurposeCode + Attention on DH; cap the DL OLN control at 17 (commit a4e28101)

**CHANGED:** PurposeCode and Attention now transmit on the Driver History query, and the Driver
  License OLN control was capped at maxLength 17.  
**REASON:** The OLN cap is the one to remember: the control accepted 20 characters where THAT
  transaction caps at 17, and the naive "fix" (shrinking the field everywhere) would have  
  truncated a VALID 20-character DH OLN, because that transaction genuinely allows 20. Same field,  
  two transactions, two limits. Recovered 2026-08-03 from commit a4e28101; this entry read  
  "Rebuilt via pipeline.ps1 / Scheduled rebuild".  

## v2.2 -- 2026-08-01 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.1 -- 2026-07-29 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v2.0 -- 2026-07-23 -- Pipeline rebuild

**CHANGED:** Rebuilt via pipeline.ps1
**REASON:** Scheduled rebuild

## v1.1 -- 2026-05-07 -- MC multi-card layout + combo refinement


## v1.0 -- 2026-05-06 -- Initial standup -- 6 basic queries, 14 combos


## v1.3 -- 2026-05-11 -- LIMITATION elimination pass

