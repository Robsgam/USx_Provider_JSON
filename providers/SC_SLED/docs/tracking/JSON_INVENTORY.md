# JSON Inventory: SC_SLED

Every JSON version ever produced for this provider. One JSON in the provider root
at all times; prior versions are recoverable byte-exact from git via
`get_provider_version.ps1 -Provider SC_SLED -Version <X.Y>` (RETRIEVAL, not rebuild --
re-running the build script does not reproduce an earlier version once shared
modules have moved).

## Current

| File | Version | Status | Notes |
|------|---------|--------|-------|
| SC_SLED_v1.4.json | v1.4 | Current | 79P/0F/2W/1LIM. |
## History

| Version | File | Date | Notes |
|---|---|---|---|
| v1.0 | SC_SLED_v1.0.json | 2026-09-14 | **Initial build — first ground-up provider since the toolchain changed**, and the first authored with the `Build-Qidm` / `Build-QidmAttribute` / `Build-QidmCombo` helpers instead of hand-written literals. All 9 devdoc-Basic transactions built, 100% of the metadata alternatives. Includes `AdministrativeMessage` as its own card (Rob: *"make it its card at the end. we can alwasy remove it later."*) — STATUS: HYPOTHESIS until the first import confirms the five real entities still render. Carries a MEASURED, UNRESOLVED Vehicle co-fire (QVRQ + QV on one plate) and Person co-fire (QWDQ + QWA.N on one name) that the first import is meant to settle. 5 registered divergences, all reasoned. |




## v1.4 (2026-09-16)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| SC_SLED_v1.4.json | v1.4 | Current | 79P/0F/2W/1LIM. |
## v1.3 (2026-09-16)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| SC_SLED_v1.3.json | v1.3 | Superseded | 79P/0F/2W/1LIM. |
## v1.2 (2026-09-16)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| SC_SLED_v1.2.json | v1.2 | Superseded | 79P/0F/0W/1LIM. |
## v1.1 (2026-09-16)

| File | Version | Status | Notes |
|------|---------|--------|-------|
| SC_SLED_v1.1.json | v1.1 | Superseded | 78P/0F/0W/1LIM. |
