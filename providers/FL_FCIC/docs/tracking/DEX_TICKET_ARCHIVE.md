# FL_FCIC — DEX-971 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Under the old
one-comment-per-release rule the SAME comment id was rewritten each release, so without a capture the
previous release statement was gone for good. Pattern established on NJ_NJCJIS 2026-08-14; this is
FL's, created 2026-08-17 when `audit_provider_uniformity` found FL among three providers with no
archive file.

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## comment 790815 — NOT CAPTURED. The pre-edit body is UNRECOVERABLE.

**What was lost.** On 2026-08-13, comment `790815` was **edited in place from the v7.18 release line
to v7.23**, recorded in `IMPORT_LEDGER.md` as *"Release line is DEX-971 comment 790815, EDITED IN
PLACE from v7.18 → v7.23 (no sibling comment)."* No capture was taken, because the archive practice
did not exist until the following day (NJ_NJCJIS, 2026-08-14). The v7.18 release statement — its
counts, its wire evidence, its reasoning — is therefore gone from the ticket and from this repo.

**This is recorded rather than quietly left blank on purpose.** An absent archive file is
ambiguous: it reads identically whether nothing was ever overwritten or whether something was
overwritten and not captured. Those are opposite facts. On FL it is the second one.

**What survives, and where to look instead.** The substance of the v7.18 release is not entirely
lost — it is reconstructible from `FL_FCIC_BUILD_NOTES.txt` (the v7.18 entry), `CHANGELOG_FL_FCIC.md`,
the `IMPORT_LEDGER.md` section A row, and the v7.18 logs archived under
`logs/<Entity>/_archive_pre_v7.19/`. What is gone is the *comment* — the human-facing release
statement as it was published to the org.

**Why no further loss can occur.** Rob reversed the edit-in-place rule on 2026-08-17: *"post as a new
comment and leave the other comments there. we can't keep erasing the previous posts everytime."*
Releases now post a NEW comment naming the superseded id in Section 1. `790815` is retained in place
as v7.23 history and was NOT edited when v7.24 shipped — v7.24 is comment `800053`, created fresh.

Consequently this file should acquire **no new entries**. If one ever appears, an irreversible edit
was made in violation of the current rule, and the entry itself is the evidence.
