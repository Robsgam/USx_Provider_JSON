# OH_LEADS — DEX-990 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Pattern established on
NJ_NJCJIS 2026-08-14. Created here 2026-08-19, when `audit_provider_uniformity` reported
`DEX_TICKET_ARCHIVE.md present on 8/9, MISSING on: OH_LEADS` — OH_LEADS joined the tenant-verified
cohort the previous day and was the only member without the file.

Newest capture first. Each entry would be the VERBATIM body as it stood immediately before an edit.

---

## NOTHING ARCHIVED — and under the current rule nothing should ever need to be.

DEX-990 has carried exactly two comments in its entire history, both posted 2026-08-19 as this
provider's first ever:

| id | shape | state |
|---|---|---|
| `801112` | RELEASE LINE — OH_LEADS v2.9 TENANT-VERIFIED, 56/56 | current |
| `801113` | HISTORY ANCHOR — v1.0 → v2.9, points at 801112 | current |

Neither has been edited, so there is no pre-edit body to capture. **This is an empty archive by
history, not by neglect** — the distinction matters, because an empty file that looks like an
oversight invites someone to go hunting for lost content that never existed.

**And the rule changed underneath this file's original purpose.** The archive was invented for the
*old* convention — one comment per release, **edited in place** — where each release destroyed the
previous release statement unless someone remembered to capture it first. Rob reversed that on
2026-08-17: *"post as a new comment and leave the other comments there. we can't keep erasing the
previous posts everytime."* Under the current rule a new release gets a NEW comment and 801112 stays
exactly where it is, so the irreversible-edit hazard this file guards against should not recur.

**So why keep the file at all?** Two reasons, both concrete:
1. `addCommentToJiraIssue` still takes an optional `commentId` and still edits in place. The hazard is
   dormant, not removed — one wrong parameter and a release statement is gone with no undo.
2. The SUPERSEDED STUB flow (`JIRA_COMMENT_TEMPLATE.txt`) is still live for **cleanup passes**, and a
   stub overwrites a body. If a future consolidation stubs 801112 or 801113, the original body belongs
   here first.

If either happens, paste the verbatim body above this line with its comment id and date.
