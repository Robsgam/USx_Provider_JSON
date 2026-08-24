# TN_TIES — DEX-994 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Pattern established on
NJ_NJCJIS 2026-08-14. Created here 2026-08-24 alongside `DEX_TICKET.md`, in the same pass, so that
`audit_provider_uniformity` never reports it missing — NM_NMLETS_OFML was flagged for exactly that
three days earlier because its ticket file was written without the companion.

Newest capture first. Each entry would be the VERBATIM body as it stood immediately before an edit.

---

## NOTHING ARCHIVED — and under the current rule nothing should ever need to be.

DEX-994 carried **zero comments in its entire history** until 2026-08-24. It now has exactly two,
both posted that day as this provider's first:

| id | shape | state |
|---|---|---|
| `804755` | RELEASE LINE — TN_TIES v2.6 TENANT-VERIFIED, 67/67 | current |
| `804754` | HISTORY ANCHOR — v1.0 → v2.6 | current |

Neither has been edited, so there is no pre-edit body to capture. **This is an empty archive by
history, not by neglect** — the distinction matters, because an empty file that looks like an
oversight invites someone to go hunting for lost content that never existed.

**The rule this file was invented for no longer applies.** The archive was created for the *old*
convention — one comment per release, **edited in place** — where each release destroyed the previous
release statement unless someone captured it first. Rob reversed that on 2026-08-17: *"post as a new
comment and leave the other comments there. we can't keep erasing the previous posts everytime."*
Under the current rule a new release gets a NEW comment and 804755 stays where it is.

**So why keep the file at all?** Two concrete reasons:
1. `addCommentToJiraIssue` still takes an optional `commentId` and still edits in place. The hazard is
   dormant, not removed — one wrong parameter and a release statement is gone with no undo.
2. The SUPERSEDED STUB flow (`JIRA_COMMENT_TEMPLATE.txt`) is still live for **cleanup passes**, and a
   stub overwrites a body. If a future consolidation stubs 804754 or 804755, the original belongs here.

If either happens, paste the verbatim body above this line with its comment id and date.
