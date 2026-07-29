# USx Provider JSON

Configuration for **ConnectCIC/CommSys law-enforcement query providers** in the Mark43 USx
platform. Each provider is one US state's query interface — an officer types a plate, a licence
number or a serial number into a form, and this configuration decides which state/NCIC transaction
gets sent and with which fields.

This repo produces **one JSON file per provider**. That JSON is imported into a USx tenant and
*is* the provider: the form the officer sees, the routing rules, and the response mapping.

Owner: rob.sgambellone@mark43.com

---

## Start here

| You want to… | Read |
|---|---|
| Understand the whole system | `CLAUDE.md` — architecture, build model, conventions |
| Know a provider's current state | `CLAUDE.md` Provider Status table (one row each) |
| Know *why* a provider changed | `providers/<P>/docs/tracking/CHANGELOG_<P>.md` |
| Learn the build rules | `knowledge-base/BUILD_RULES.txt` |
| Know what the platform can't do | `knowledge-base/PLATFORM_CONSTRAINTS.txt` |
| Fix a production problem | `knowledge-base/PRODUCTION_TRIAGE.txt` |
| Know where a JSON is installed | `providers/IMPORT_LEDGER.md` |

## The three commands

```powershell
tools\pipeline.ps1 -Provider <NAME>    # build + report + audit + enforce (the normal path)
tools\enforce.ps1                      # the mandatory gate; exit 0 or it isn't done
tools\portfolio_status.ps1             # one-screen truth for all 20 providers
```

`enforce.ps1` is the contract. It runs ~425 checks across ~14 phases. **If it isn't green, the
work isn't finished** — and it is deliberately hard to make green by accident.

## Repo layout

```
providers/<PROVIDER>/
  <PROVIDER>_v<X.Y>.json     the deliverable — exactly ONE JSON per provider root
  scripts/build_*.ps1        the only way that JSON is produced (never hand-edit the JSON)
  source/                    metadata XML (field authority) + devdoc PDF/txt (query authority)
  docs/tracking/             STATUS, SQVR, BUILD_NOTES, CHANGELOG
  docs/reports/              generated audit output
  docs/reference/            METADATA_REFERENCE, SUPPORTED_QUERIES
  docs/deliverables/         OFFICER_GUIDE (the only customer-facing artifact)
  logs/                      tenant test evidence, one folder per entity
knowledge-base/              build rules, platform constraints, testing requirements
tools/                       63 scripts + 14 shared modules, all provider-agnostic
automation/extension/        Chrome extension that drives and captures tenant tests
```

## Two rules that explain most of the design

**1. Metadata is field authority; the devdoc is query authority.**
The XML says which fields a transaction has. The devdoc's "Basic Queries Supported" list says
which queries we're allowed to build. Metadata existence alone does not authorise a query.

**2. Never hand-edit a JSON.**
The build script is the source of truth and every JSON must be reproducible from it —
`enforce` proves this by rebuilding and comparing. A hand-patched JSON is a defect.

## What "tested" means here

Testing runs against a **USx test tenant**, not a live state system. There is no live state
connection anywhere in this project, so **no provider has ever received a real response.**
A passing test proves *the request we sent was correct* — which is the entire, intended scope.
Do not read a green test package as end-to-end validation.

Test evidence is per-query files under `providers/<P>/logs/<Entity>/`. Any version bump resets
a provider's whole test package: the matrix re-runs from test 1.

## Current state

20 providers, all on the single-JSON build model. See the `CLAUDE.md` Provider Status table for
per-provider version, validator score and tenant-test state — or run `portfolio_status.ps1`,
which derives it from the JSONs and logs rather than from any hand-maintained note.
