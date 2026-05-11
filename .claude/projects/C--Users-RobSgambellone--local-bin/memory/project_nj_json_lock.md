---
name: NJ_NJCJIS JSON locked at v2.9
description: NJ_NJCJIS BASE JSON is frozen at v2.9 -- do not modify unless user explicitly requests it; learnings from other providers can be stored but must not trigger NJ changes
type: project
---

NJ_NJCJIS_BASE.json v2.9 is LOCKED as of 2026-05-08. 16/16 live tests PASS.

**Why:** The JSON is ready for live deployment testing and must remain stable while being evaluated in production. User explicitly said "do not update this json project unless specifically told to -- lock the json."

**How to apply:** Do NOT modify NJ_NJCJIS_BASE.json, NJ_NJCJIS_BASE_READABLE.json, or run build scripts for NJ. Do NOT propagate fixes from other providers to NJ. Learnings from other provider testing CAN be recorded in memory/KB docs but must NOT trigger any NJ JSON file changes. Only unlock if the user explicitly says to modify NJ.
