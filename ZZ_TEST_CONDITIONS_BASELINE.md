# ZZ_TEST_CONDITIONS — Platform Behavior Baseline

TEST-ONLY probe (not a provider). Establishes how a tenant actually evaluates
`QueryInputDataMapping` **conditions** and **defaults** vs the Cringer
"QueryInputDataMapping" / "Attribute Handle" docs. Results are read from the **request XML
markers** — hidden fields that serialize when their combo fires. `*_KEEP` markers always fire
(no-condition keep-alive that keeps the query submittable); ignore them — the signal is which
*other* markers appear.

Build: `build_zz_test_conditions.ps1` → `ZZ_TEST_CONDITIONS.json` (repo root). Import to a tenant,
run the protocol below, read the markers.

---

## BASELINE RESULT — PRACTICE TENANT (`LAPTOPNLHTE6T0`), 2026-06-24

| Group | Query | Operator / behavior | Observed result | Matches doc? |
|---|---|---|---|---|
| A | DriverLicenseQuery | `EQUALS` / `NOT_EQUALS` | **ENFORCED** both directions (CA→only EQ marker; NY→only NE marker) | YES |
| B | DriverHistoryQuery | `EXISTS` / `NOT_EXISTS` | **ENFORCED** both directions (flip on/off with field present/blank) | YES |
| B | DriverHistoryQuery | value-cond beside a `NOT_EXISTS` (poison repro) | **NO poisoning** — NOT_EXISTS still honored next to an EQUALS | YES |
| C | VehicleRegistrationQuery | default on `any[]` | **APPLIES** (blank field filled with default on the wire) | YES |
| C | VehicleRegistrationQuery | default on `set[]` | **NO-OP** — combo can't even submit (default never injects a required field) | YES |
| D | GunQuery | `IN` / `NOT_IN` / `"null"` literal | **ENFORCED**; value match is **case-INsensitive**; `"null"` matches an absent field | YES |
| E | ArticleSingleQuery | `REGEX` | **ENFORCED**; **case-SENSitive** (`Pattern.matches`) | YES |
| F | BoatQuery | `EXCLUSIVE` | **frontend warning only; backend ALWAYS passes** — combo fired with both fields set | YES |

### Conclusion
The platform behaves **exactly as documented** on this build.
- **Supersedes** the 2026-06-12 "poisoned-array / value-conditions inert" finding — that was a
  since-fixed platform bug. Value-comparison conditions and co-resident `NOT_EXISTS` both work.
- **Confirms** `set[]`-defaults are no-ops (only `any[]`-defaults apply) — so the 2026-06-23
  gap-audit defaults placed on `set[]` fields (HI `VehicleTypeCode`; FL/TX plate `LicensePlateYear`/
  `LicensePlateTypeCode`) are dead, and `audit_cad` CHECK 6 (demands defaults on `set[]`) is wrong.
- `EXCLUSIVE` is a UI hint only — never use it for routing.

---

## RUN PROTOCOL (repeat verbatim per tenant; **reload the form between runs**; read markers in request XML)

| # | Form / Query | Enter | Expected if AS DOCUMENTED |
|---|---|---|---|
| A1 | Person · DriverLicense | `A_OLN`=X1, `A_STATE`=**CA** | `MK_AEQ` only (no `MK_ANE`) |
| A2 | Person · DriverLicense | `A_OLN`=X1, `A_STATE`=**NY** | `MK_ANE` only (no `MK_AEQ`) |
| B1 | Person · DriverHistory | `B_OLN`=X2 only | `MK_BNOTEXIST` (no `MK_BEXIST`) |
| B2 | Person · DriverHistory | `B_OLN`=X2, `B_EXIST`=Z, `B_NOTEXIST`=Z | `MK_BEXIST` (no `MK_BNOTEXIST`) |
| B3 | Person · DriverHistory | `B_OLN`=X2, `B_NOTEXIST`=Z, `B_STATE`=CA | `MK_BPOISON` **absent** (no poisoning) |
| C1 | Vehicle · VehReg | `C_VIN`=… only | `<C_ANYDEF>ANYDEF_OK</C_ANYDEF>` + `MK_C1` |
| C2 | Vehicle · VehReg | `C_PLATE`=… only | combo **can't submit** (set[]-default no-op) |
| D1 | Firearm · Gun | `D_SERIAL`=G1, `D_VAL`=CA | `MK_DIN` + `MK_DINNULL` (no `MK_DNOTIN`) |
| D2 | Firearm · Gun | `D_SERIAL`=G1, `D_VAL`=TX | `MK_DNOTIN` only |
| D3 | Firearm · Gun | `D_SERIAL`=G1, `D_VAL`=blank | `MK_DINNULL` present (`"null"` matches absent) |
| E1 | Article | `E_SERIAL`=A1, `E_VAL`=`abc123` | `MK_EREGEX` **absent** (no match) |
| E1b | Article | `E_SERIAL`=A1, `E_VAL`=`AB123` | `MK_EREGEX` present (match) |
| F1 | Boat | `F_HULL`=B1, `F_A`=1, `F_B`=2 | frontend warns; `MK_FEXCL` still fires (backend passes) |

`*_KEEP` markers always appear. Condition fields (`A_STATE`, `D_VAL`, …) do **not** serialize — they only feed conditions.

---

## CROSS-TENANT STATUS

| Tenant | Status | Result |
|---|---|---|
| PRACTICE (`LAPTOPNLHTE6T0`) | ✅ DONE 2026-06-24 | All as documented (table above) |
| **NJ USx test** | ✅ DONE 2026-06-24 | **Matches practice on all groups.** REGEX appeared to diverge in the batch run (`abc123` fired) but a clean re-run (`ZZZZZ`/`ab123`/`AB123`/`abc123` with reload between each) confirmed strict full+case-sensitive matching — the batch "fire" was a **clear-form-bug artifact**, not a platform difference. |
| HI USx test | ▶ NEXT | pending |
| FL USx test | pending | |

> **Testing note:** RELOAD the form between EVERY run. The clear-form bug ([[project_clear_form_bug]]) lets a prior matching run leave its combo selected, which leaks a false-positive marker into the next request. The NJ batch run hit exactly this on E1 (`abc123`) — only the one-at-a-time clean re-run revealed the true (strict) behavior.

If NJ/HI/FL match the practice baseline, the behavior is confirmed across the tenants and we can
plan the real follow-ups: (1) correct `audit_cad` CHECK 6, re-scope the `set[]`-default gap-audit
fixes; (2) re-evaluate the value-condition routing we shelved (FL not-FL gate, etc.) — each with full
re-test, one provider at a time.
