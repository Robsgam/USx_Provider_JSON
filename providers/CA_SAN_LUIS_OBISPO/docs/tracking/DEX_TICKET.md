# CA_SAN_LUIS_OBISPO — DEX ticket pointer

**DEX-981** — [CA - SAN_LUIS_OBISPO] USx Provider Build
https://mark43.atlassian.net/browse/DEX-981

Recorded 2026-09-04. The repo had NO ticket file for this provider; the number was found by JQL
against Jira, not from any repo record. Verified live at the time of writing: **status `Backlog`,
0 comments.**

## Posted

None. No comment has ever been posted to this ticket.

## Where this provider actually stands

- **Never tenant-tested** (0/5 entities). Blocked at stage 4 (test).
- Build is clean: validator 67P / 0F / 0W.
- **One open attribution item**: its Vehicle `QV.V` combo is named after a DATA-MINED transaction
  while the identical-requirement non-mined sibling `4V` is unbuilt
  (`tools/_probes/sweep_mined_keyref_shadow.ps1`). A keyRef never reaches the wire, so this is a
  RENAME with no wire effect — take it at this provider's own rebuild, not as a portfolio sweep.
- Regional interface, NOT direct CLETS: short keyRefs, no `ImageIndicator`, no State initialValue
  (LIMITATION #30 in/out split).

## Standing

Jira is HELD (2026-07-31). A release comment is DRAFT-AND-WAIT, every provider, every time, and no
approval carries from one provider to the next. Being behind on Jira is the expected consequence of
the hold, not owed work.
