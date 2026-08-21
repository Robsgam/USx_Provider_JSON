# NM_NMLETS_OFML — DEX-989 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Pattern established on
NJ_NJCJIS 2026-08-14. Created here 2026-08-21, when `audit_provider_uniformity` reported
`DEX_TICKET_ARCHIVE.md present on 9/10, MISSING on: NM_NMLETS_OFML` — NM joined the
lifecycle-complete cohort that same day and was the only member without the file.

**It was missing because I built NM's `DEX_TICKET.md` from scratch on 2026-08-21 and did not create
the companion.** Worth naming rather than quietly fixing: the artifact set IS the deliverable, and a
provider that reaches lifecycle-complete with an incomplete package is incomplete, not untidy. The
gap survived a green `enforce` because `audit_structure` checks ONE provider against a template in
isolation and this file is not in that template — only the cross-provider comparison could see it.

Newest capture first. Each entry would be the VERBATIM body as it stood immediately before an edit.

---

## NOTHING ARCHIVED — and under the current rule nothing should ever need to be.

DEX-989 has carried exactly one automation comment in its entire history:

| id | shape | state |
|---|---|---|
| `803470` | RELEASE LINE — NM_NMLETS_OFML v2.6 TENANT-VERIFIED, 36/36 (first ever sweep) | current |

It has never been edited, so there is no pre-edit body to capture. **This is an empty archive by
history, not by neglect** — the distinction matters, because an empty file that looks like an
oversight invites someone to go hunting for lost content that never existed.

**The rule this file was invented for no longer applies.** The archive was created for the *old*
convention — one comment per release, **edited in place** — where each release destroyed the previous
release statement unless someone captured it first. Rob reversed that on 2026-08-17: *"post as a new
comment and leave the other comments there. we can't keep erasing the previous posts everytime."*
Under the current rule a new release gets a NEW comment and 803470 stays where it is, so the
irreversible-edit hazard is dormant.

**So why keep the file at all?** Two concrete reasons:
1. `addCommentToJiraIssue` still takes an optional `commentId` and still edits in place. The hazard is
   dormant, not removed — one wrong parameter and a release statement is gone with no undo.
2. The SUPERSEDED STUB flow (`JIRA_COMMENT_TEMPLATE.txt`) is still live for **cleanup passes**, and a
   stub overwrites a body. If a future consolidation stubs 803470, the original body belongs here first.

If either happens, paste the verbatim body above this line with its comment id and date.
