# AZ_AZDPS — DEX-974 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Under the old
one-comment-per-release rule the SAME comment id was rewritten each release, so without a capture the
previous release statement was gone for good. Pattern established on NJ_NJCJIS 2026-08-14; this is
AZ's, created 2026-08-17 when `audit_provider_uniformity` found AZ among three providers with no
archive file.

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## NOTHING TO ARCHIVE — and that is a MEASURED result, not an assumption.

**No automation comment has ever been posted to DEX-974, so nothing has ever been overwritten.**
Verified against the live ticket on 2026-08-17 (`getJiraIssue DEX-974`, fields `comment`):
`"total": 1` — a single comment, `776896` by **Leo Hisoire** (2026-07-10, the FB-6040 roadmap note).
That is a **third party's** comment.

⚠️ **`776896` MUST NEVER BE EDITED, STUBBED OR COUNTED AS OURS.** Only automation-authored comments
may be edited, identified by the 🤖 attribution line — never by `displayName`, since the automation
posts under Rob's own account and every comment it writes reads "Rob Sgambellone". `776896` carries
no attribution line and is not Rob's either; it belongs to someone else entirely.

**This file exists empty rather than not existing, because those are different facts.** A missing
archive is ambiguous — it reads the same whether nothing was ever overwritten (AZ) or something was
overwritten and not captured (FL_FCIC `790815`, IL_LEADS_OFML `795242`, both recorded in their own
archive files on the same day). Present-and-empty says which one AZ is. It also keeps
`DEX_TICKET_ARCHIVE.md` out of `audit_provider_uniformity`'s `$optionalByDesign` allowlist: that
allowlist is token-keyed and all-or-nothing, so exempting the token to accommodate AZ would have
suppressed the finding on FL and IL too — hiding the two cases that mattered. Same trap the tool's
own `.gitkeep` note describes.

**Standing item, unrelated to archiving: AZ owes a Jira release line for its ENTIRE history.**
Nothing has ever been posted here — not the v3.11 tenant verification (ALL-PASS 50/50), not the
v3.9 first-ever full sweep, nothing. That is stage 5 of the lifecycle, still open. Draft and wait.

**Why no loss can occur going forward.** Rob reversed the edit-in-place rule on 2026-08-17: *"post as
a new comment and leave the other comments there."* Releases now post a NEW comment naming the
superseded id in Section 1, so this file should acquire **no entries at all**. If one ever appears,
an irreversible edit was made in violation of the current rule, and the entry itself is the evidence.
