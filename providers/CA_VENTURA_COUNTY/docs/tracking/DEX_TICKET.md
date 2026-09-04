# CA_VENTURA_COUNTY — DEX ticket pointer

**DEX-982** — [CA - VENTURA_COUNTY] USx Provider Build
https://mark43.atlassian.net/browse/DEX-982

Recorded 2026-09-04. The repo had NO ticket file for this provider; the number was found by JQL
against Jira, not from any repo record. Verified live at the time of writing: **status `Backlog`,
0 comments.**

## Posted

None. No comment has ever been posted to this ticket.

## Where this provider actually stands

- **Never tenant-tested** (0/5 entities). Blocked at stage 4 (test).
- Build is clean: validator 82P / 0F / 0W — the largest officer guide in the CA family (36 rows).
- **Blocked on ORDER OF OPERATIONS, not on a defect**: its `LicensePlateTypeCode` toggle test is
  hollow (it toggles to the field's own form default, so it proves nothing). Fixing it needs a
  TEST_VALUE_OVERRIDES entry, and the value can only be CHOSEN after the one-time picklist capture
  — which itself requires the provider to be imported first, because the capture script scrapes the
  RENDERED form. **IMPORT FIRST, THEN PICKLIST CAPTURE** (Rob 2026-08-28).
- ⚠️ Do NOT copy CA_CLETS's combinations here. Both build an `IR.QVC{Name}` DL combo and they
  require OPPOSITE things — CA_CLETS's variant carries `Choice[Age|BirthDate]` in `<Any>`
  (optional), Ventura's carries it in `<Set>` (mandatory, must be split). That is the whole reason
  `audit_provider_linkage` exists.

## Standing

Jira is HELD (2026-07-31). A release comment is DRAFT-AND-WAIT, every provider, every time, and no
approval carries from one provider to the next. Being behind on Jira is the expected consequence of
the hold, not owed work.
