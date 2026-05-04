# FL_FCIC v2.2 Test Log

**File**: FL_FCIC_v2.2_test.json
**Built**: 2026-04-21
**Validator**: 65 PASS / 0 FAIL / 0 WARN

## Changes from v2.1

- Vehicle merged (InState+OOS) → single entity, single card, 15 fieldIds
- Firearm +NCICNumber +ProcessControlNumber (9 fieldIds)
- Person 6-card layout (was 2-card):
  1. Search Options (State, ImageIndicator)
  2. DL / Wanted Person — by OLN
  3. DL / Wanted Person — by Name/DOB
  4. Driver History — by OLN
  5. Driver History — by Name/DOB
  6. Driver History — Required (PurposeCode, Attention)
- Vehicle QIDM: keyReference (not keyRef), rule (not ruleHandlers), primaryFieldReference, state, providerType
- All 3 layout variants: default, CAD_DISPATCH, FIRST_RESPONDER

---

## Test 1: Person DLQ — FDQName (FL In-State by Name)

**Date**: 2026-04-21
**Input**: First=Rob, Last=Sgambellone, DOB=1958-01-20, Sex=F, Image=Y, State=blank
**Expected combo**: FDQName (set: BirthDate, NameFirst, NameLast, SexCode)

### CommSys Request
```xml
<MessageType>DriverLicenseQuery</MessageType>
<ImageIndicator>Y</ImageIndicator>
<SexCode>F</SexCode>
<Requestor>SGAMBELLONE R</Requestor>
<BirthDate>19580120</BirthDate>
<Name>SGAMBELLONE, ROB</Name>
```

**Result**: PASS
- SexCode=F → NIBRS reverse-lookup working (codeTypeProvider=NIBRS on QIDM attr)
- BirthDate=19580120 → CommsysParseDateRuleHandler(yyyy-MM-dd, yyyyMMdd) working
- Name=SGAMBELLONE, ROB → FormatStringRuleHandler(", ", " ", " ") working
- Requestor=SGAMBELLONE R → CommsysGetLastNameFirstNameInitialRuleHandler working
- No State element → correct for FL in-state (FDQ, not DQ)
- ImageIndicator=Y → initialValue passed through

### RMS Request
```json
{"lastName":"Sgambellone","firstName":"Rob","sexAttrId":"69509804592","dateOfBirth":"1958-01-20"}
```

**Result**: PASS
- sexAttrId=69509804592 → numeric attribute ID (useAttributeId=true working)
- dateOfBirth=1958-01-20 → ISO format preserved for RMS
- No Returns → expected (test data)

---

## Pending Tests

- [ ] Person DLQ — FDQOperatorLicenseNumber (FL In-State by OLN)
- [ ] Person DLQ — DQName (OOS by Name — needs State filled)
- [ ] Person DLQ — DQOperatorLicenseNumber (OOS by OLN+State)
- [ ] Person DLQ — QWName (Wanted by Name)
- [ ] Person DLQ — QWOperatorLicenseNumber (Wanted by OLN+Name)
- [ ] Person DHQ — KQOperatorLicenseNumber (DH by OLN+State+Purpose+Attention)
- [ ] Person DHQ — KQName (DH by Name+State+Purpose+Attention)
- [ ] Vehicle — FRQ combos (FL in-state)
- [ ] Vehicle — QV combos (NCIC)
- [ ] Vehicle — RQ combos (OOS Nlets)
- [ ] Firearm — QG combos (SerialNumber, NCICNumber, PCN)
- [ ] Article — QA combos
- [ ] Boat — FBQ/QB/BQ combos
- [ ] 6-card layout UI review (card titles rendering, field grouping clear)
