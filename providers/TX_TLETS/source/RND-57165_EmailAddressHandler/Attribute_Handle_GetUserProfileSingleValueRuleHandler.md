# Attribute Handle — Item #22: GetUserProfileSingleValueRuleHandler

Source: https://mark43.atlassian.net/wiki/spaces/SEARCH/pages/6708822104/Attribute+Handle#22.-GetUserProfileSingleValueRuleHandler
(Confluence page "Attribute Handle", fetched 2026-07-15, page version 5)

## Purpose
Retrieves properties from `UserProfile` of the user who made the query. Session information is
extracted from the request.

## Parameters
- `rule.arguments[0]`: key of the value to retrieve from `UserProfile`.
- Common values: `firstName`, `lastName`, `badgeNumber`, `email`, `userId`, `departmentId`

## Configuration example
```json
{
  "name": "Email",
  "rule": {
    "function": "GetUserProfileSingleValueRuleHandler",
    "arguments": [ "email" ]
  },
  "sourceField": ["EmailAddress"],
  "targetField": "Email"
}
```

## Output example
```json
{
  "Email": "test.user@mark43.com"
}
```

## Requires external service
UserProfileService (same category as `CommsysGetLastNameFirstNameInitialRuleHandler`, the handler
already used for TX_TLETS's Attention field — both pull from the requesting officer's session/
profile, no `userArguments`/form-value lookup involved beyond the sourceField gate-feeder needed
to get the attribute into the serialization pool).

## Relevant siblings on the same page (for context, not used here)
- #19 `CommsysGetLastNameFirstNameInitialRuleHandler` — formats `"LastName FirstInitial"` from
  the user profile. This is what TX_TLETS's Attention field already uses; #22 is the same family
  of handler (UserProfileService-backed) but returns a single named property instead of a
  formatted name string.
- #18 `CommsysGetDexStateUserIdRuleHandler` — another UserProfileService-backed handler, used
  for badge/DEX state user ID auto-population elsewhere in this repo's providers.
