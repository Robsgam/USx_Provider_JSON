# HI_HCJDC_OFML — DEX-1257 pre-edit comment archive

**Why this file exists.** `JIRA_COMMENT_TEMPLATE.txt`: *"there is no delete-comment tool ... any edit
is IRREVERSIBLE — capture the original body before overwriting it."* Under the one-comment-per-release
rule the SAME comment id is rewritten each release. Pattern established on NJ_NJCJIS 2026-08-14;
this is HI's (fourth in the repo).

Newest capture first. Each entry is the VERBATIM body as it stood immediately before an edit.

---

## comment 795241 — captured 2026-08-14, immediately before the v4.18 edit

State at capture: created 2026-08-10 as the v4.15 release line, updated 2026-08-11 in the
consolidation pass. Carrying **v4.15** at 46/46.
Superseded by: the v4.18 release line written into this same comment id on 2026-08-14.

```
🤖 Auto-update from the ConnectCIC provider-JSON repo — generated from the build and gate artifacts (BUILD_NOTES, the four log gates, `audit_log_inflation`, `enforce`).

**HI_HCJDC_OFML v4.15 — TENANT-VERIFIED**

**1. Scope**
Versions covered: v4.15. Configuration changed: yes. Supersedes: comment 791589 (the v4.14 re-verification).

**2. Changed**

* **v4.15 (DEX-1283)** — removed the literal `'X'` from three sites, all for one field: the hidden Driver-History `Attention` control's form `initialValue`, and the `Attention='X'` entry in both the `KQ` and `KQN` combination `defaults[]` (`PurposeCode='C'` retained). The control itself, its `any[]` membership, and the `CommsysGetLastNameFirstNameInitialRuleHandler` attribute are unchanged — only the literal value went. HI was the last provider still prefilling it.

**3. Verified on the wire**
Vehicle 16 / Person 14 / Firearm 6 / Article 3 / Boat 7 = **46**
Every Driver-History query transmits `<Attention>SGAMBELLONE R</Attention>` with **no prefill and no default anywhere in the configuration** — 9 of 9 DH wires. Zero wires carry a literal `X`, so `any[]` membership alone is sufficient to feed the handler.

This needed proving rather than assuming: HI's own v2.9 build note credited the `'X'` as the gate-feeder that made the handler resolve. That conclusion was confounded — v2.9 changed two things in one version (it added `Attention` to the KQ/KQN `any[]` **and** added the `'X'`), and its own text names the missing `any[]` entry as the root cause. It is now settled on HI's own wires rather than inferred from the other four providers.

Control observation: the Driver-License side emits no `<Attention>` element at all, confirming the field is genuinely DH-scoped and does not leak through the shared field pool.

**4. Gates**
validator 65P/0F/0W · four log gates 46/46 (content, metadata, attribution, plan completeness 5/5) · inflation 0/0/0/0 · enforce 43 PASS / 0 provider-scoped FAIL-or-WARN · 12 combos, all reachable

**5. Known limits**
The CAD path is verified by **inspection only**. Removing `Attention='X'` from the `KQ`/`KQN` `defaults[]` is precisely the half that no form-driven query can exercise, and DEX-1283's second symptom — "not present when you do it from a CAD event" — is that path. Treat CAD as addressed by configuration review, not by captured evidence.

**6. Documented skips**
None — all 6 devdoc-Basic queries built.

**RELEASE LINE — v4.15 is verified and ready.**
```

**What this capture preserves that the v4.18 edit necessarily drops:**

1. **The DEX-1283 `Attention` finding in full.** v4.15's whole substance — that `any[]` membership ALONE
   feeds `CommsysGetLastNameFirstNameInitialRuleHandler`, proven on 9 of 9 DH wires with no prefill and
   no default. **And the reason it needed proving:** HI's own v2.9 build note credited the `'X'` prefill
   as the gate-feeder, a conclusion confounded because v2.9 changed two things at once. If anyone later
   reads the v2.9 note and reinstates the prefill, this is the refutation.
2. **The control observation** — the DL side emits no `<Attention>` at all, so the field is genuinely
   DH-scoped and does not leak through the shared field pool.
3. **Sections 5 and 6**, predating the 2026-08-13 four-section ruling: the CAD path is verified by
   INSPECTION ONLY (no form-driven query can exercise the combo `defaults[]` half, which is DEX-1283's
   second reported symptom), and all 6 devdoc-Basic queries are built with no skips.

**Note on the v4.18 edit itself:** v4.16 and v4.18 (the NCIC hit-block response mapping) are
DELIBERATELY NOT detailed in the new body. Rob, 2026-08-14: *"leave hit block out for now. We can
update once we verify."* The sweep proves the request side only — no test query returned a real NCIC
hit — so the 25 hit attributes are config-present and unexercised. The full detail lives in the v4.16
BUILD_NOTES entry and the IMPORT_LEDGER section A row, and goes on the ticket once a live hit is
observed in the RMS UI.
