# IL_LEADS_OFML — DEX-984 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Under the old
one-comment-per-release rule the SAME comment id was rewritten each release, so without a capture the
previous release statement was gone for good. Pattern established on NJ_NJCJIS 2026-08-14; this is
IL's, created 2026-08-17 when `audit_provider_uniformity` found IL among three providers with no
archive file.

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## comment 795242 — NOT CAPTURED. The pre-edit body is UNRECOVERABLE.

**What was lost.** On 2026-08-13, comment `795242` was **edited in place from the v2.2 release line to
v2.7**, recorded in `IMPORT_LEDGER.md` as *"the v2.7 release line (comment 795242, EDITED IN PLACE
from v2.2 → v2.7)."* No capture was taken, because the archive practice did not exist until the
following day (NJ_NJCJIS, 2026-08-14). The v2.2 release statement is therefore gone from the ticket
and from this repo.

**Extra weight on this one.** v2.2 was IL's **first-ever tenant sweep** (41/41 ALL-PASS) and `795242`
was the release line announcing it, on a ticket that had been empty until 2026-08-10. That is the
statement that was overwritten.

**This is recorded rather than quietly left blank on purpose.** An absent archive file is ambiguous:
it reads identically whether nothing was ever overwritten or whether something was overwritten and
not captured. Those are opposite facts. On IL it is the second one.

**What survives, and where to look instead.** Comment `795041` (2026-08-10) is the untouched
**history anchor** — the full v1.0 → v2.2 changelog dump, still on the ticket. Between it,
`IL_LEADS_OFML_BUILD_NOTES.txt`, `CHANGELOG_IL_LEADS_OFML.md` and the archived v2.2 logs, the
substance of the v2.2 release is reconstructible. What is gone is the *comment* — the release
statement as published to the org.

**Why no further loss can occur.** Rob reversed the edit-in-place rule on 2026-08-17: *"post as a new
comment and leave the other comments there. we can't keep erasing the previous posts everytime."*
Releases now post a NEW comment naming the superseded id in Section 1. `795242` is retained in place
as v2.7 history and was NOT edited when v2.8 shipped — v2.8 is comment `800073`, created fresh.

Consequently this file should acquire **no new entries**. If one ever appears, an irreversible edit
was made in violation of the current rule, and the entry itself is the evidence.
