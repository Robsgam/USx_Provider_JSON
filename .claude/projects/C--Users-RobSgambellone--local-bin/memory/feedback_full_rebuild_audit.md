---
name: Full rebuild audit is standard practice
description: When user says rebuild/audit a provider, it means full build+report+docs+commit+push for both BASE and MC, auditing process as you go, carrying lessons forward
type: feedback
---

When asked to rebuild or audit any provider, the FULL protocol is automatic — do not wait for each step to be spelled out.

**Why:** User had to explicitly describe the full CA_CLETS audit process (rebuild, run build_report, check version consistency, fix docs, commit, push, carry insights forward). This should be the default behavior whenever touching a provider.

**How to apply:**
1. Read build script, check for stale version defaults, doc inconsistencies
2. Rebuild BASE (clean, no flags) + run build_report.ps1
3. Rebuild MC + run build_report.ps1
4. Audit: version sync (BASE=MC), CLAUDE.md accuracy, STATUS.txt currency, SQVR version, BUILD_NOTES entry
5. Fix any issues found
6. Commit JSON + all reports + docs, push
7. Carry forward any warnings/limitations/patterns discovered to the next provider
8. When doing multiple providers sequentially: apply lessons from earlier providers to later ones (e.g., field type fixes, version mismatches, stale docs)
