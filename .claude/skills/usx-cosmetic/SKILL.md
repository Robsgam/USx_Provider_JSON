---
name: usx-cosmetic
description: Use when doing a COSMETIC / layout pass on a provider JSON — card titles, field labels, field widths, row grouping and field order. Trigger on "cosmetic pass", "this needs work" about a rendered form, "fix the labels", "the form looks wrong", or a rendered-form review that produced changes. Holds the rule set that derives layout from the combination array, the traps that made three earlier hand reviews wrong, and the cost rules (a cosmetic bump archives the whole test package).
---

# Cosmetic / layout pass

## The two things that govern this, in order

**1. THE GOAL IS THAT EVERY PROVIDER LOOKS AND READS THE SAME** (Rob, 2026-08-11: *"the skill
should posintion them all the same in terms of layouts and veriabege"*). An officer who works
two states should not have to relearn the form. So **divergence between providers is a FINDING,
not a preference.** The only legitimate reason for provider A to differ from provider B is that
A's own combinations or metadata force it — a different identifier set, a mandatory field the
other doesn't have, a `maxLength` cap. "That's just how this one was built" is drift, and drift
is what this skill exists to converge. Do not read the per-provider variation in the current
portfolio as a set of deliberate choices; most of it is the order the providers happened to be
built in.

**2. THE OPERATOR HAS FINAL SAY.** Rob — or whoever is running the pass — overrules any rule
here, and that decision stands without needing to be re-argued next time. Every finding is a
RECOMMENDATION. When an override is made, **record it where the tooling will see it** so it
stops being re-flagged: a `# LABEL-OVERRIDE: <field> -- <reason>` tag for labels, a note in
`<P>_BUILD_NOTES.txt` for layout. An unrecorded override gets "rediscovered" and re-litigated,
which is the same waste in the other direction.

**What makes any of this reviewable: a good form is a PROJECTION OF THE COMBINATION ARRAY, not
a matter of taste.** Before this was written down, every cosmetic pass was somebody's eye, so
nothing accumulated and each provider re-litigated it.

Run `tools\audit_layout_flow.ps1 -Provider <NAME>` first. It mechanises seven of the rules
below and prints its denominators. **It is ADVISORY and NOT YET in enforce or pipeline** (Rob,
2026-08-11: *"lets test before we put any of this in the the production pipeline"*) — because
the rules were still being corrected, not because divergence is acceptable. Wire it once the
portfolio has been converged and the remaining findings are all recorded overrides.

## Step 0 — The two costs, before you touch anything

- **A cosmetic bump archives that provider's ENTIRE test package.** Every log, every entity.
- **But re-test cost is NOT a reason to defer a fix** (Rob, 2026-08-11: *"testing is no
  longer a blocker or consideration now that we have honed the driver and capture tools"*).
  Never argue against a change on re-test grounds. Do it, then re-sweep.
- **An imported version is frozen.** If the active version is installed in the tenant, a
  label edit is a BUMP, not an edit — the wire XML carries no version, so one version number
  describing two different forms makes every log unattributable (`audit_log_inflation`
  attack B). Check `IMPORT_LEDGER.md`, and remember that file has been wrong: verify against
  non-archived `logs/` and `docs/reference/TENANT_PICKLISTS.json`, which carries a `version`.

## Step 1 — The rule set

Derived by reverse-engineering the layouts that survived tenant testing, then corrected
against the portfolio (see Step 3 — the first draft was wrong three ways).

| # | Rule | Mechanised |
|---|---|---|
| **L4** | **One card per entity** (Person legitimately TWO: DL + DH, because DH-suffix fieldIds are a separate field pool — that IS the isolation mechanism). Card title is ALL-CAPS and enumerates the query paths. | yes |
| **L1** | One row per identifier path. Row leads with that combo's identifier, then that combo's own qualifiers. | **no — see Step 3** |
| **L2** | `set[]` (mandatory) leads; a combo's own unique optionals follow. | yes |
| **L3** | Hidden / auto-populated rows go LAST. Never between two visible groups. | yes |
| **L5** | Don't give a whole 12-column row to a control that cannot use it (a dropdown, a date, a short field). | yes |
| **L6** | Every visible row's `templateColumns` sums to 12. | yes |
| **L7** | The label must match the field's CAPACITY. `MI` only if `maxLen=1`; otherwise `Middle Name`. | yes |
| **L8** | Name parts: **First then Last**, all four in one row. The wire stays LAST-first via the composite `FormatStringRuleHandler` — form order and `sourceField` order are independent, proven on IL v2.2. | no |
| **L9** | A field that feeds ONLY the RMS QIDM must not share a row with a mandatory CommSys identifier — it reads as though it queries the state, and it does not. | yes |

**Width tracks EXPECTED INPUT, not `maxLength`.** NY deliberately gives a `maxLen=35` middle
name only `[2]`. Nobody types 35 characters of middle name. So narrower-than-capacity is a
choice, not a defect — only wasted width is reported.

**Canonical labels** (BUILD_RULES §11 is authority, don't restate from memory): `OLN`,
`NCIC Image`, `Stolen Check`, spelled-out `Vehicle Identification Number`. Prefilled fields
get a BARE label — no `(auto)`, no `(default X)`; the CHECK 15 WARN that provokes is correct
and is downgraded with a `# LABEL-OVERRIDE:` tag, not by decorating the label.

## Step 2 — Do the officer walk, out loud

The rules catch shape. They do not catch *"would I reach for this?"* Walk the card as the
officer: most common query first (plate, then VIN; OLN, then name+DOB), and ask whether the
first thing your eye lands on is the thing you type most. AZ_AZDPS put `SocialSecurityNumber`
beside `OLN` in row 1 — mechanically fine, but SSN is in **no CommSys combination at all**
(RMS-only), so the most prominent slot on the Person card went to a field that does not
query the state. That is L9, and it was found by walking, then mechanised after.

## Step 3 — THE TRAPS. Three of my first four hand findings were WRONG.

**`hidden` is a NODE-level property (`$node.hidden`), NOT `$node.props.hidden`.** Reading the
props path produced NINE false findings in one run — five "mandatory `dexStateUserId` sits
below optionals", two `RegistrationStateDH`, two width — every one a hidden gate-feeder the
officer never sees. `verify_build` CHECK 6 reads the node level and was right. A row can also
be hidden as a whole, hiding its children regardless of their own flag.

**`render_layout` prints the NODE ID where you expect the card title.** `CARD "CARD_VEH"` is
the id, not an empty title. I concluded "AZ has no card titles" from that; it has all six,
ALL-CAPS and path-carrying. **Read `props.title` from the JSON, or grep the titles.**

**A label on a hidden field is dead text.** `Badge (auto)` / `Requestor (auto)` look like
bare-label violations and are not — those controls never render.

**L1 as "form order should match combo array order" IS WRONG and is withdrawn.** The two
orderings encode different things: the combo array is ordered by SPECIFICITY for first-match
firing (most `set[]` fields first), while form order should follow IDENTIFIER PRIORITY — what
the officer reaches for — which is expressed by the `NOT_EXISTS` guardrails (OLN > Name,
Plate > VIN, Hull > Reg). On AZ, `DQPN` has five `set[]` fields so it sorts ahead of `DQP`,
which carries OLN; OLN still belongs first on the form. The check fired 4 times on AZ and was
wrong 4 times. A real version must read the guardrail conditions.

**Shared context fields are not "optionals in the way".** A field appearing in more than one
combo's `any[]` (`ImageIndicator`, `RegistrationState`, `purposeCode`) is context and belongs
grouped high with the primary identifier — which puts it ABOVE the combo-specific mandatory
fields below. Without excluding those, L2 raised 8 findings against FL_FCIC, one of the two
layouts the rules were derived FROM, and accounted for 71 of 165 portfolio findings. If a
rule fires on the provider you copied it from, the rule is wrong.

**An `any[]` field that is another combo's `set[]` is an ALTERNATIVE IDENTIFIER, not a
qualifier.** Boat `BQH` has hull in `set[]` and registration in `any[]` while `BQ` has
registration in `set[]`. Two identifiers side by side on one row is correct.

## Step 3b — THE UNIFORM TARGET (what "all the same" actually means)

One shape, every provider, every entity. Deviate only where the provider's own authorities
force it, and say which authority when you do.

```
CARD TITLE:  <ENTITY> SEARCH BY <PATH 1>, "OR" <PATH 2>, "OR" <PATH 3>     (ALL-CAPS)
  row 1   primary identifier + its own qualifiers          [6 3 3]
  row 2   second identifier  + its own qualifiers          [6 3 3]
  row 3   shared context: State, NCIC Image, Stolen Check  [4 4 4]
  row N   hidden / auto-populated                          [12]   (always last)
```

Person is the one entity with TWO cards — `DRIVER LICENSE SEARCH BY ...` and
`DRIVER HISTORY SEARCH BY ...` — because the DH-suffix fieldIds are a separate field pool and
that separation IS the isolation mechanism. Both cards take the same shape as above.

**Fixed verbiage** (BUILD_RULES §11 is authority — read it, don't restate from memory):
`OLN` · `NCIC Image` · `Stolen Check` · `Vehicle Identification Number` (spelled out) ·
`Plate Number` · `Plate Type` · `Plate Year` · `First Name` · `Last Name` · `Middle Name` ·
`Suffix` · `Date of Birth` · `Sex` · `Race` · `State`. Prefilled fields take a **bare** label —
never `(auto)` or `(default X)`. Name order on the form is **First then Last** everywhere.

## Step 4 — Reference, and who to copy

**Do NOT copy FL or NY for layout.** They are the most tenant-proven builds and I derived the
first draft from them, but they predate the current convention: FL scores 7 findings, NY 6,
TX 5.

**The current standard is NJ_NJCJIS (0 findings — the only clean provider) and OH_LEADS (2),
the two most recent layout passes.** Copy the shape, never the content: `audit_provider_linkage`
exists because a build script justified by another provider's decisions is the defect, and
CA_CLETS vs CA_VENTURA require **opposite** things on an identically-named combo.

Portfolio baseline 2026-08-11, `audit_layout_flow -All`: 20 compared / 19 with findings / 139
total. `L4` 34 · `L5` 26 · `L2` 11 · `L7` 10 · `L3` 7 · `L9` 3. The `L4` mass is the
un-collapsed-layout split: collapsed providers run 5–6 cards, un-collapsed 11–20
(CA_VENTURA 20, CA_CLETS_OCATS 16, TN 14, MD 13, NM 13, CA_SLO 13, LA 12, OR 11).
**Those providers' LOW scores on the other rules are partly vacuous** — small cards hold few
rows, so there is less to trip. L4 says so in its own message.

## Step 5 — Finish

```
tools\audit_layout_flow.ps1 -Provider <NAME>     # advisory; adjudicate each finding
tools\build_phase1.ps1 -Provider <NAME> -Rebuild # a layout change is still a build
tools\test_phase2.ps1 -Provider <NAME>           # bump archived the package: re-sweep
tools\enforce.ps1 -Provider <NAME>
```

A layout/label change must leave the wire IDENTICAL. Prove it, don't assert it: per-entity
fingerprints unchanged where no field moved between combos, and `audit_layout_flow` findings
strictly reduced. If a fingerprint moved, you changed routing, not cosmetics — go back to
`usx-build`.

**The rendered form review is Rob's OWN manual gate.** PHASE 2k printing `[INFO] not
reviewed` is the steady state. Never prompt for it; be ready to record it:
`tools\audit_form_review.ps1 -Path <json> -Record -Reviewer <name>`.
