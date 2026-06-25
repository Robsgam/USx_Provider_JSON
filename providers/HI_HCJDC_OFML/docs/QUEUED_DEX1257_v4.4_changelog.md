DEX-1257 Jira posting log + pending release line.
==================================================

POSTED:
- 2026-06-25  Initial full changelog dump            -> comment 767719 (edited to add 🤖 attribution)
- 2026-06-25  v4.5 changelog update (Make removal)   -> comment 767758

PENDING (post once v4.5 live testing PASSES all entities):
Add a follow-up comment (lead with the 🤖 attribution line) carrying the release line:

  "HI_HCJDC_OFML USx JSON v4.5 imported to USx HI TEST tenant; all entities PASS
   (Article/Boat/Firearm/Person/Vehicle). Handed to @Leo Hisoire for evaluation."

Current test status (v4.5): Article / Boat / Firearm BLOCKED (PASS).
Remaining before release line: Person (all combos) + Vehicle (RQ/RQV/M55L/M55S +
plate-wins guardrails + clear-Vehicle-Type-fires-nothing regression + confirm Make
field gone from VIN card).

Pattern (Rob, 2026-06-25): update the DEX ticket on EVERY version bump (dump first,
then per-version diff), lead with the 🤖 auto-update attribution line; release line
added only after that version's live testing passes. Applies to all providers.
