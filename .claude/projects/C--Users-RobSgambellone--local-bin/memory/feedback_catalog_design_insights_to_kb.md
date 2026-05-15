---
name: catalog-design-insights-to-kb
description: Every MC design question and UX insight discovered during builds must be cataloged in KB BUILD_RULES.txt Section 11
metadata:
  type: feedback
---

When building JSONs, every design question the user raises (card structure, label wording, field placement, routing behavior) and the resolution must be added to knowledge-base/BUILD_RULES.txt Section 11 (MC Multi-Card Design Rules).

**Why:** FL_FCIC v4.1 session surfaced multiple design insights (Options card pattern, "leave blank" label rule for MC vs Person, 2-card vs N-card trade-offs, duplicate fieldId ISE constraint) that were discovered through interactive Q&A. These insights apply to ALL providers but were only in conversation context until explicitly cataloged.

**How to apply:** After any build session that produces design decisions: update BUILD_RULES.txt Section 11 with the pattern, the reasoning, and which providers confirmed it. Do not wait for the user to ask — catalog immediately. [[mc-required-for-full-coverage]] [[base-mc-always-sync]]
