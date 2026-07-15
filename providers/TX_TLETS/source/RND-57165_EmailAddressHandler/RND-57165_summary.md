# RND-57165 — Handler to backfill email address based on value of a field (Texas Data Provider)

https://mark43.atlassian.net/browse/RND-57165 (Story, In Testing as of 2026-07-15)

## Description (verbatim)
- Need a way so USx can be configured where it will backfill the email address of the user in a
  field (requestor field for Texas) when another field is set to a value (image is set to Y)
- Confirm that we have the mechanism that using either configuration file or handlers to set
  Reason Code as "C" as default if it's sent as blank. If we don't, build it.

Note:
- The state of Texas requires an email address of the user and also Reason Code be submitted
  when the request a DL photo.
- CAD doesn't pass use either user's email address or Reason Code. As same as OnScene.

## Why (TLETS manual quote, comment 2026-06-30, Leo Hisoire)
> Driver license photos are not available by name only. The minimum information needed to obtain
> the driver photo is NAM and DOB or OLN along with the image request (IMQ), a reason code (RSN)
> and the email (EML) address of the Requestor. Law enforcement agencies have the capability to
> obtain Texas driver license photos. This includes agencies in Texas as well as agencies
> out-of-state requesting DL photos through Nlets.

## CJIS compliance constraint (comment 2026-07-01, Gordon Hallof)
> The use of an agency wide email address that does not specifically identify the REQUESTOR
> specifically is a violation of TLETS CJIS Security Policy.

This is why the field must be auto-populated from the signed-in officer's own UserProfile, not a
shared/agency address and not left as a manually-typed field an officer could get wrong.

## Handler
`GetUserProfileSingleValueRuleHandler` — see `Attribute_Handle_GetUserProfileSingleValueRuleHandler.md`
in this same folder (fetched from Confluence "Attribute Handle" page, item #22).

## sampleConfig.json (this folder)
Attached to the ticket 2026-07-15. It's LA_LEMS's full bundle (used as the other team's
illustrative test vehicle for the handler generally, not a TX-specific config) — confirms the
attribute config shape (`rule.function` = `GetUserProfileSingleValueRuleHandler`,
`rule.arguments` = `["email"]`). Its combo-routing (EQUALS-conditioned ImageIndicator Y/N split)
is NOT something we copied — that's the poisoned-array pattern already proven inert on the
ConnectCIC/CommSys platform (FL_FCIC v4.9); TX_TLETS's implementation uses the same
conditions-free `any[]`+default pattern already proven for its own Attention handling instead.

## External dependencies not solved by our JSON
A 2026-07-15 comment (Daniel Arvizu) says: "Flag added. Requires DepartmentBundle configuration
import. Attached to ticket." This reads as a platform-side feature flag + a separate tenant-level
config import, not something in our provider JSON — confirm with the other team / USx tenant
admin before/at import time.

## Implemented
- `providers/TX_TLETS/scripts/build_tx_tlets.ps1` — see CHANGELOG/BUILD_NOTES for the version
  this landed in.
