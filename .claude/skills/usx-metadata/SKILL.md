---
name: usx-metadata
description: Use when reading, ingesting, or interpreting a provider's metadata XML or devdoc — deciding whether a field is MANDATORY or OPTIONAL, which variant a built combo implements, whether a finding is a real defect or a tool artefact, or why two authorities disagree. Trigger on "is this field required", "which combo does this map to", "why does the gate say X", any FIX-vs-REGISTER call, any new-provider ingestion, or any change to a tool that parses metadata. NOT for running the build gates (use usx-build) or tenant testing (use usx-test-iterate).
---

# Reading the authorities without fooling yourself

Almost every defect this repo has shipped, and almost every FALSE defect it has chased, came from
misreading the metadata grammar or asking the wrong authority. This skill is the accumulated
grammar plus the specific ways it has misled people.

**The single most useful habit: when a gate and your reasoning disagree, open the raw XML.** On
2026-08-01 four confident diagnoses were wrong and only a measurement said so.

## Step 0 — Which authority answers which question

| Question | Authority | Never use |
|---|---|---|
| WHICH queries may we build? | devdoc "Basic Queries Supported" / "Basic Query Transactions" | metadata transaction names |
| Is a field MANDATORY or OPTIONAL **in a specific combination**? | **raw XML `<Requirements>` of that `<Combination>`** | `METADATA_REFERENCE.txt` — it FLATTENS branches |
| What fields exist, what size, what type? | `docs/reference/<P>_METADATA_REFERENCE.txt` | guessing from the name |
| Which metadata variant does a built combo implement? | `(query, keyRef, primaryFieldReference)` | keyRef alone |

**Metadata is FIELD authority. Devdoc is QUERY authority.** That one line resolves most conflicts:
the devdoc says *whether we may build the query at all*; the metadata says *what the fields are and
which are required*. Neither overrides the other in the other's domain.

**The heading is not standardised.** Most devdocs say "Basic Queries Supported"; `CA_CLETS_OCATS`
says **"Basic Query Transactions"**. A grep for the common spelling returned nothing there and
nearly caused a real Basic-scoped gap to be dismissed as out-of-scope. Search for both, and confirm
by reading the section, not by the header matching.

## Step 1 — The grammar. Five shapes, and four of them have burned us.

### 1. `<Choice>` POSITION is load-bearing
```xml
<Set> <Choice><Field A/><Field B/></Choice> ... </Set>   <!-- exactly ONE of A/B is MANDATORY -->
<Set> <Any><Choice><Field A/><Field B/></Choice></Any> </Set>   <!-- both OPTIONAL -->
```
`set[]` has no OR, so a Choice-inside-`<Set>` must become **one combination per branch**. Getting
this wrong shipped `CA_CLETS` `IG.QGH` with neither Age nor BirthDate — a request satisfying no
variant, carried by a committed PASS log.

### 2. A `<Choice>` BRANCH can be a nested `<Set>` — a GROUP, not a field
```xml
<Choice>
  <Field reference="NCICNumber"/>
  <Set><Field reference="ArticleSerialNumber"/><Field reference="ArticleTypeCode"/></Set>
</Choice>
```
Read: "NCICNumber, **OR** serial+type **together**." A Choice is satisfied when **any ONE branch is
satisfied IN FULL**. Enumerating only the direct `<Field>` children reads the branch list as
`{NCICNumber}` and reports the entirely-valid serial+type build as satisfying nothing — that put 4
false findings on `TX_TLETS` (tenant-verified, 89 logs).

### 3. A nested `<Set>` inside `<Set>` is a MANDATORY GROUP, not an `<Any>`
`CA_VENTURA_COUNTY` `NLTS.DQ{Name}` = `Set[purpose, Set[Name, SexCode, BirthDate, State]]` — all
four mandatory. `audit_metadata` reads the inner Set as if optional and reports
`promoted-to-set`. That is a tool artefact; the build is right.

### 4. Optionals are scoped PER VARIANT; the devdoc lists them FLAT
This is the single biggest source of ambiguous findings. The devdoc gives **one optional list per
query**; the metadata spreads those optionals across **separate transactions** (in-state NCIC vs
out-of-state Nlets keyRef) or **Choice branches**. A flat list cannot express *"optional, but only
on the Nlets path."*
> Consequence: `"silently not transmitted"` is a **real dropped value** on some providers and the
> **correct behaviour** on others — 11 times in one day, same wording, opposite answers.
> **Run `tools\audit_optional_scope.ps1` — do not read the wording.** See `usx-build` Step 3a.

### 5. TRANSACTION-ENVELOPE fields are not per-query search fields
CLETS `CaRequestPurposeCode` is mandatory on **every transaction** and appears in **no** devdoc
per-query combination list. So every devdoc-faithful fill omits it and matches nothing. On CA_eSUN
that one missing envelope field produced **55 reported failures**; on OCATS, 4.
Fix is two-part and each half stands alone: a **combo default** (CAD ignores form `initialValue`, so
without it a CAD query is rejected outright) and a **form prefill** (blank = guaranteed rejection).
Such a prefill is **load-bearing, not a BUILD_RULES 24 violation** — a field mandatory in *every*
combination cannot shadow one path over another.

### 6. TRANSACTION-level agreement is not VARIANT-level agreement

The strongest false signal there is, because *both authorities appear to confirm each other*:

> the metadata defines the field **on this transaction**, and the devdoc lists it **on this query**.

That is not enough, and on 2026-08-02 it got a complete fix drafted for `OH_LEADS` —
attributes, controls, an auto-populate handler, combo wiring — before the per-**combination**
`<Requirements>` were read. They killed it:

```
DL{OperatorLicenseNumber}      MAND=[OperatorLicenseNumber]  OPT=[]                                 <-- BUILT
BMVIMS{OperatorLicenseNumber}  MAND=[OperatorLicenseNumber]  OPT=[ReasonCode, Requestor, UserName]  <-- not built
```

The built variant's `<Any>` is **empty**. Wiring the three optionals into it would OVER-PERMIT, and
`BMVIMS` is itself a duplicate-input twin of `DL` (both mandate only `OperatorLicenseNumber`), so
building *that* would create a dead combo. The devdoc listed them because it gives ONE FLAT optional
list per query: item #2 is the `BMVIMS` row, #3 is the `DL` row.

**The only question that decides it: what does the FIRING combination's own `<Requirements>`
define?** Nothing short of reading them answers it. A keyRef is not a variant — and neither is a
transaction.

**Same rule governs FIELD SIZES.** `CA_CLETS_OCATS` carried `Authorization` at size 2 because the
size was read from `OcatsWarrantQueryAWVEHQ` instead of `VehicleRegistrationQuery` (which says 1) —
and the comment directly above that line *already warned* that the keyRef `AWVEHQ` exists under both.
The combo lookup was scoped correctly and the field size was then read from the wrong side of the
very collision it documented. `CA_SAN_LUIS_OBISPO` defines `OperatorLicenseNumber` as 17 under
`DriverLicenseQuery` and 20 under `DriverHistoryQuery`. **Read `maxLength` INSIDE the transaction
you are building**, never by a global field-name lookup.

## Step 2 — A KEYREF IS NOT A VARIANT

This decided **five** separate outcomes in one day. Always scope by
**(query, keyRef, primaryFieldReference)**:

- The same keyRef exists under **two different `<Transaction>` parents** — `CA_CLETS_OCATS` has
  `OCNAMQ` under both `DriverLicenseQuery` (Basic) and `OcatsWarrantQueryOCNAMQ` (not built).
  Resolving by bare keyRef maps a Basic combo onto a warrant transaction and dismisses a real gap.
- One keyRef carries **many PF variants** — `IR.QVC` has Name / OLN / CriminalIdNumber / SSN.
  Comparing a built CII combo against the `{Name}` variant is meaningless and produced 5 false rows.
- Sibling variants share a keyRef with **different optional sets** — `OR_LEDS` `BQ` has both
  `{BoatHullIdNumber}` and `{RegistrationNumber}`; an unnarrowed lookup found a field on the sibling
  and recommended a change that would have OVER-PERMITTED.

## Step 2b — THE KEYREF NEVER REACHES THE WIRE, AND SOME TRANSACTIONS ARE DATA-MINED

**Run `tools\audit_data_mined.ps1 -Provider <NAME>` before adjudicating ANY "unbuilt combination"
finding.** It is wired into `build_phase1` as step **5b**, deliberately printed immediately after
step 5 (query trace) — because step 5's MISSING list is exactly where the wrong conclusion gets
drawn, so the mined list has to be on screen at that moment.

Two mechanical facts. Between them they dissolve a whole class of finding, and BOTH were invisible
to every gate until 2026-08-24.

**(a) A keyRef choice cannot change where a query goes.** The request carries
`<MessageType><QueryName></MessageType>` plus the FIELDS — nothing else identifies the transaction.
Verified against a real capture: the keyRef appears **zero** times. Rob, 2026-08-24: *"we only send
the VehicleRegistrationQuery and not the transaction name."*

> So **"we built keyRef X instead of Y" is never a functional defect on its own.** Only the QUERY
> NAME and the FIELD SET can be wrong. If two metadata combinations have the same `set[]`, picking
> either one emits identical bytes — that is a naming question, and often a routing IMPOSSIBILITY
> (no fill can separate them), never a routing risk.

**(b) A DATA-MINED transaction is run BY THE STATE off our single request.** Its tags come back in
the response; we never send it separately. The devdoc declares them on its own line:

```
Data-Mined Transactions: NCIC (QA, QB, QG, QV, QW) and DMV (Person and Vehicle)
                         Tags returned from Data mining
```

Consequences, all three load-bearing:
- A metadata combination whose keyRef is a mined transaction is **not a gap to fill**.
- Building **no separate stolen/wanted query** for a mined file is **correct**, not an omission
  (NJ's QV skip and TN's absent VehicleStolenQuery are both this).
- `InquiryTypeIndicator` (`1` reg-only / `2` hotfiles-only / **`3` both, default**) is why ONE query
  covers registration *and* hot files.
- **What IS real:** the QRDM must be able to receive those tags. That is class **DM2**, the only
  actionable output of the tool. Class **DM3** (mapping present, never exercised) is a COVERAGE
  STATEMENT about the response mapping, **not** work a sweep can do. ⚠️ **Do not turn DM3 into a
  sweep objective** — I did, and Rob corrected it 2026-08-24: *"we want logs that show the xml
  message and verify that uit matches the metadata specs."* A sweep proves the OUTGOING REQUEST —
  gate 6d validates every `<Request>` field against the metadata for that query and checks the
  field-set satisfies a real metadata combination. Whether a mined tag RENDERS is response-side, it
  needs a real hit record in the tenant we do not control, and no amount of request capture settles it.

**WHY THIS IS A SKILL RULE AND NOT JUST A TOOL.** `audit_supported_queries` used the string
`Data-Mined Transactions` purely as a **parse boundary** to stop reading the Basic list — it read
past the content and threw it away. So the devdoc named the mined transactions and **nothing in the
repo had ever read that sentence.** The cost: TN_TIES carried a note in FOUR places (SESSION_STATE,
FINDINGS_REGISTER twice, its own BUILD_NOTES) saying an unbuilt `RQ01` might mean *"in-state TN plate
searches reach NCIC not TIES/DMV"* — filed as an open functional risk needing Rob's ruling. It was
impossible by (a), already adjudicated in TN's own registry (`RQ01 ... == QV.P -> DROPPED`), and
answered outright by (b). Measured 2026-08-24: **16 of 20 devdocs declare mined transactions and 33
built combinations are named after one** — so this is portfolio-wide, not a TN quirk.

**Parse trap, if you ever touch the parser:** the content is usually on the FOLLOWING line(s), not
after the colon, and HI_HCJDC_OFML puts a **blank line** between them. My first parser stopped at
that blank and reported HI as declaring nothing — a false negative on the exact question the tool
exists to answer, caught only by hand-checking a provider it called empty.

## Step 3 — sourceField vs targetField

A combination's `set[]`/`any[]` hold **sourceFields** (form fieldIds). Metadata `<Requirements>`
hold references matching the QIDM attribute's **targetField**. *The targetField is the wire
contract; the sourceField is just what the control is called on the form.*
Comparing sourceFields to metadata directly needs an ever-growing alias list and still fails on
`VehNameLast`, `OwnerLastName`, `OwnerSocialSecurityNumber`, `firearmMake`. **Resolve through the
attribute map first.** Any whitelist must live in the **same namespace** as the comparison — moving
comparison to targetField space silently broke a sourceField-keyed whitelist on exactly one provider.

## Step 4 — Ingestion checklist for a NEW provider

1. **Name the folder from the XML filename**, before anything else (BUILD_RULES §0).
2. **Resolve the XML with `Get-ProviderMetadataXml`** — never a `*.xml` glob. An alphabetical glob
   read a 6-node JAWS excerpt as if it were the 466-node metadata and reported green.
3. `pdftotext` the devdoc; find the Basic list (**both spellings**).
4. `extract_metadata_reference.ps1` — but remember it flattens Choice branches; it answers *what
   fields exist*, never *what is mandatory here*.
5. **Read `<Field maxLength>` for every field you wire.** Guessing produced `AddressCounty` 30 (it
   is 3 — a county *code*) and SSN 11 (it is 9); both would have been server-rejected.
6. For each Basic query, dump the raw `<Requirements>` per `<Combination>` and classify each shape
   against Step 1 **before** writing any combination.
7. Check whether the field even EXISTS: AZ's devdoc lists `OwnerAppliedNumber` and
   `ConcealedWeaponPermitNumber` combos and its metadata defines **0 of 1896** such fields.
   **Validate the probe against a known-present field first, or a zero means nothing.**

## Step 5 — When the two authorities genuinely conflict

They do, regularly, and the resolution is not always the same:

| Shape | Resolution |
|---|---|
| Devdoc brackets a field optional; metadata puts it in `<Set>` with no looser variant | **Metadata wins.** Building to the bracket emits a request no variant accepts. |
| Devdoc lists a field the metadata never defines | **Not buildable.** Register. |
| Metadata mandates a field the devdoc never mentions, and honouring it changes what the officer must type | **STOP — that is a product decision.** Record it; do not guess. NM's DL `PurposeCode`/`Attention` is exactly this. |
| Metadata combination has no devdoc counterpart | **Out of Basic scope.** Never a gap in either direction. |

### ROB'S RULING, 2026-08-18: "meta data wins over dev doc / built to the spec and ignore the running json"

Two parts, and the second is the one that corrects an actual mistake:

1. **METADATA WINS.** Where the two disagree, build to the metadata. The table above resolves the
   shapes case by case; this is the default when a case is not listed. Do not average them, do not
   split the difference, and do not build to the devdoc because it is easier to read.

2. **A RUNNING/IN-SERVICE JSON IS NOT AN AUTHORITY. BUILD TO THE SPEC.** This is the trap. On
   2026-08-18, adjudicating LA_LEMS's DriverHistoryQuery `Attention` (devdoc says MANDATORY, metadata
   does not define the field at all), I cited `source/Lafayette Parish LA_LEMS 8.13.2026.json` -- the
   hand-built config Lafayette actually runs -- as "decisive corroboration" that Attention is not
   transmitted. **The conclusion happened to be right and the METHOD was wrong.** A shipped config is
   evidence of what somebody built and what a provider tolerates; it is not evidence of what the spec
   requires. It can be wrong and still work: that same file **UNDER-REQUIRES `PurposeCode`** (in
   `any[]` where the metadata puts it in `<Set>`) and carries an **INERT `Attention` mapping with no
   form control to feed it**. Cite it as *context*, never as authority, and never let it outvote the
   XML.
   Corollary: "the running system does X" is the same class of argument as "18 of 20 providers do X"
   (`ENGINEERING_STANDARD` 4.5) -- both describe practice, neither establishes spec.

## Traps that have each cost real time

- **`METADATA_REFERENCE.txt` cannot answer mandatory-vs-optional.** It emits one row per
  (keyRef, primaryField) showing only the common mandatory prefix. Building to that row is how
  CA_CLETS shipped a request no variant accepted.
- **A registration that suppresses nothing is clutter that reads like coverage.** Two attempts were
  reverted the same day. **Always re-measure BRANCHES-COMPARED, not the finding count** — a
  suppression that lowers coverage looks identical to a clean run.
- **The gate may refuse your registration and be right.** `demoted-to-any` grants *"it rides in
  `any[]`"*; if the field is absent from `any[]` too, that is a strictly worse state and the tool
  still reports. A surviving mutation taught it that guard.
- **Verify a version bump landed by listing the emitted filename** — three build scripts use
  different `$Version` spacing and literal-match bumps silently no-op.
- **A plausible mechanism is not evidence.** Four confident diagnoses were wrong on 2026-08-01 and
  only a measurement settled each one.

## Verification

Any change to a metadata-parsing tool must be measured against the **regression fixture**:
`CA_CLETS`, `FL_FCIC`, `HI_HCJDC_OFML`, `NJ_NJCJIS`, `NY_NYSPIN_EJUSTICE`, `TX_TLETS` report
**0 UNDER / 0 OVER** on `audit_requirement_fidelity`, **116 branches** total (2026-08-02).
Five are tenant-verified; **`FL_FCIC` is not — it went un-swept at v7.15–v7.17** and is a structural
baseline only, so never cite it as evidence a parser matches the wire. See `usx-tooling` Step 1.
**They must stay 0/0, and branches-compared must not fall.** That fixture has already refuted one
plausible improvement (keyRef-scoped branch matching — see `knowledge-base/FIDELITY_TRIAGE.txt`).
Validate any parser change against **both** TX (flat `Choice/Field`) and NY (nested `Choice/Set`).
