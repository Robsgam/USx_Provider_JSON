# LA_LEMS — DEX ticket pointer

**DEX-985** — [LA - LEMS] USx Provider Build
https://mark43.atlassian.net/browse/DEX-985

Recorded 2026-09-04. The repo had NO ticket file for this provider; the number was found by JQL
against Jira, not from any repo record. Verified live at the time of writing: **status `Done`,
0 comments.**

## Posted

None. No comment has ever been posted to this ticket.

## ⚠️ THE TICKET SAYS `Done`. OUR PROVIDER JSON HAS NEVER BEEN TESTED OR INSTALLED ANYWHERE.

Both statements are true, and reconciling them matters before anyone reads `Done` as "LA_LEMS is
finished":

- **Lafayette Parish runs a HAND-BUILT LA_LEMS produced by engineering — not our JSON.**
  `IMPORT_LEDGER.md` §B.1 records it: *"NOT OURS — hand-built by engineering, in service as of
  2026-08-13"*, with the deployed file kept for diagnosis at
  `source/Lafayette Parish LA_LEMS 8.13.2026.json`.
- **`LA_LEMS_v3.2` is installed on NO tenant** and is 0/5 tenant-tested.

So the most likely reading is that DEX-985 was closed against the **deployment**, not against this
repo's provider build. **That is an inference, not a verified fact** — the ticket carries zero
comments, so nothing on it says what was delivered. Confirm with Rob before treating `Done` as
covering our JSON, and do not reopen or comment on the assumption that it is wrong.

Note also the separate **DEX-1209 … DEX-1249 [LA - Lafayette]** deployment epic (tenant config,
Commsys install, foundation/live rollout, incl. DEX-1242 "USx CJIS Query Forms built in
foundation"). That is a different workstream from this provider-build ticket; do not conflate them.

## Where this provider actually stands

- **Never tenant-tested** (0/5). Blocked at stage 4 (test). Build clean: validator 65P / 0F / 0W.
- **Open, not taken**: `BoatQuery QB{reg}` vs `BQ{reg}` — recorded in its own ACCEPTED_DIVERGENCES,
  Rob's call, not mine.
- Carries stale ancillary artifacts; clear via `build_report -IncludeExtended` at its own turn.

## Standing

Jira is HELD (2026-07-31). A release comment is DRAFT-AND-WAIT, every provider, every time, and no
approval carries from one provider to the next. Being behind on Jira is the expected consequence of
the hold, not owed work.
