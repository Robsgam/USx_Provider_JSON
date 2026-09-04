# CA_CONTRA_COSTA — DEX ticket pointer

**DEX-977** — [CA - CONTRA_COSTA] USx Provider Build
https://mark43.atlassian.net/browse/DEX-977

Recorded 2026-09-04. The repo had NO ticket file for this provider; the number was found by JQL
against Jira, not from any repo record — the same way OH_LEADS, MD_METERS, NM, OR, TN and
CA_CLETS_OCATS were found. Verified live at the time of writing: **status `Blocked`, 0 comments.**

## Posted

None. No comment has ever been posted to this ticket.

⚠️ **STATUS IS `Blocked`, and that is not the norm** — CA_CLETS_OCATS (DEX-980) is the only other
provider ticket in that state. The reason is unknown to this repo. **Ask before treating this
provider as importable**, exactly as the JIRA_REFERENCE note says for OCATS.

## Where this provider actually stands

- **Never tenant-tested** (0/5 entities). Blocked at stage 4 (test), like the other four in the
  import queue.
- **It carries the portfolio's only remaining requirement-fidelity findings** — 4 UNDER-REQUIRED /
  3 OVER-PERMITTED on the JAWS/SuperQuery combinations, listed verbatim in its BUILD_NOTES.
  **That is Rob's open ruling.** Hold the SWEEP, not the import.
- **Its devdoc says "Basic Queries Supported: None"**, so `audit_devdoc_combinations` falls back to
  the LINKED BASE's devdoc (CA_CLETS) and says so in a loud NOTE. That substitution is the one
  blessed directed link in `audit_provider_linkage` — it is NOT verification against this
  provider's own document.

## Standing

Jira is HELD (2026-07-31). A release comment is DRAFT-AND-WAIT, every provider, every time, and no
approval carries from one provider to the next. Being behind on Jira is the expected consequence of
the hold, not owed work.
