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

Any change to a metadata-parsing tool must be measured against the **regression fixture**: the six
tenant-verified providers (`CA_CLETS`, `FL_FCIC`, `HI_HCJDC_OFML`, `NJ_NJCJIS`,
`NY_NYSPIN_EJUSTICE`, `TX_TLETS`) report **0 UNDER / 0 OVER** on `audit_requirement_fidelity`.
**They must stay 0/0, and branches-compared must not fall.** That fixture has already refuted one
plausible improvement (keyRef-scoped branch matching — see `knowledge-base/FIDELITY_TRIAGE.txt`).
Validate any parser change against **both** TX (flat `Choice/Field`) and NY (nested `Choice/Set`).
