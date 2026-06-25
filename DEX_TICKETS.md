# DEX Provider Build Tickets — Board Snapshot

Jira project **DEX** — *CJIS/USx/DEx Implementation* (site `mark43.atlassian.net`,
cloudId `5ba7ec1f-1b3f-4b21-a2f2-5d04d124de2c`).
One "USx Provider Build" ticket per provider. Snapshot captured **2026-06-25**.

**Workflow:** as each provider is rebuilt + re-tested, post the changelog to its DEX ticket
(dump first, then per-version diff, led by the 🤖 auto-update attribution line; release line
after live testing passes). See `providers/<PROVIDER>/docs/DEX_TICKET.md` once linked.

| Provider (repo) | DEX Ticket | Status (2026-06-25) | Linked in repo? |
|---|---|---|---|
| HI_HCJDC_OFML | [DEX-1257](https://mark43.atlassian.net/browse/DEX-1257) | In Progress | ✅ docs/DEX_TICKET.md |
| NJ_NJCJIS | [DEX-988](https://mark43.atlassian.net/browse/DEX-988) | In Progress | ✅ docs/DEX_TICKET.md |
| TX_TLETS | [DEX-967](https://mark43.atlassian.net/browse/DEX-967) | In Progress | (link on rebuild) |
| NY_NYSPIN_EJUSTICE | [DEX-969](https://mark43.atlassian.net/browse/DEX-969) | In Progress | (link on rebuild) |
| AZ_AZDPS | [DEX-974](https://mark43.atlassian.net/browse/DEX-974) | In Progress | (link on rebuild) |
| CA_CLETS | [DEX-976](https://mark43.atlassian.net/browse/DEX-976) | In Progress | (link on rebuild) |
| FL_FCIC | [DEX-971](https://mark43.atlassian.net/browse/DEX-971) | Done | (link on rebuild) |
| CA_eSUN | [DEX-978](https://mark43.atlassian.net/browse/DEX-978) | Done | (link on rebuild) |
| LA_LEMS | [DEX-985](https://mark43.atlassian.net/browse/DEX-985) | Done | (link on rebuild) |
| CA_CONTRA_COSTA | [DEX-977](https://mark43.atlassian.net/browse/DEX-977) | Backlog | (link on rebuild) |
| CA_SAN_LUIS_OBISPO | [DEX-981](https://mark43.atlassian.net/browse/DEX-981) | Backlog | (link on rebuild) |
| CA_VENTURA_COUNTY | [DEX-982](https://mark43.atlassian.net/browse/DEX-982) | Backlog | (link on rebuild) |
| IL_LEADS_OFML | [DEX-984](https://mark43.atlassian.net/browse/DEX-984) | Backlog | (link on rebuild) |
| MD_METERS | [DEX-987](https://mark43.atlassian.net/browse/DEX-987) | Backlog | (link on rebuild) |
| NM_NMLETS_OFML | [DEX-989](https://mark43.atlassian.net/browse/DEX-989) | Backlog | (link on rebuild) |
| OH_LEADS | [DEX-990](https://mark43.atlassian.net/browse/DEX-990) | Backlog | (link on rebuild) |
| OR_LEDS | [DEX-992](https://mark43.atlassian.net/browse/DEX-992) | Backlog | (link on rebuild) |
| TN_TIES | [DEX-994](https://mark43.atlassian.net/browse/DEX-994) | Backlog | (link on rebuild) |
| CA_CLETS_OCATS | [DEX-980](https://mark43.atlassian.net/browse/DEX-980) | Blocked | (link on rebuild) |

### Other DEX build tickets (no active repo / not in current scope)
| Ticket | Provider | Status |
|---|---|---|
| [DEX-983](https://mark43.atlassian.net/browse/DEX-983) | HI – HCJDC-OFML (older **duplicate** of DEX-1257; use 1257) | Done |
| [DEX-975](https://mark43.atlassian.net/browse/DEX-975) | CA – ALEMS | Blocked |
| [DEX-979](https://mark43.atlassian.net/browse/DEX-979) | CA – JDIC | Blocked |
| [DEX-986](https://mark43.atlassian.net/browse/DEX-986) | MA – LEAP | Blocked |
| [DEX-991](https://mark43.atlassian.net/browse/DEX-991) | PA – CLEAN | Blocked |
| [DEX-993](https://mark43.atlassian.net/browse/DEX-993) | SC – SLED | Blocked |

_Statuses are a point-in-time snapshot; check Jira for live state. Re-run the JQL
`project = DEX AND summary ~ "USx Provider Build" ORDER BY key ASC` to refresh._
